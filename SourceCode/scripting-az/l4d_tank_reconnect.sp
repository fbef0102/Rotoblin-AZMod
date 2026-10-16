#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>

#define PLUGIN_VERSION "0.1-riverside1"

/**
 * l4d_tank_reconnect - a tank whose player drops gets the tank back on rejoin.
 *
 * When a human tank disconnects (a crash, a timeout, or on purpose) the game
 * hands the body to an AI bot, and nothing ever gives it back: match 539
 * (2026-10-06) lost its tank to the AI for good when evanesce's internet died,
 * although they were back 70 s later while the game was still paused.
 *
 * This plugin remembers whose tank the bot took, and when that player joins
 * the infected team again while the bot tank is still alive, ReplaceTank puts
 * them back in it. The body keeps its health and position.
 *
 * Leaving must not refresh anything (owner, 2026-10-06), so the tank's rage
 * (m_frustration) and the director's pass count are saved at the moment of
 * the disconnect and written back after the swap. A tank that already passed
 * once still goes to the AI on its next frustration, and a tank one second
 * from losing control is still one second from losing control.
 *
 * Two ways back. The PUG team lock (sm_inf, l4dready) uses ChangeClientTeam,
 * which takes over no bot, so this plugin calls ReplaceTank. A raw
 * "jointeam 3" makes the game itself hand the player an infected bot, the
 * tank included, but with the rage reset to zero; bot_player_replace catches
 * that and writes the saved rage and pass count back. They are written back
 * whoever takes the bot tank that way, so nobody gets a fresh bar from it.
 *
 * Only disconnects count. A tank that goes to the AI through frustration also
 * fires player_bot_replace, but its player never disconnects, so nothing is
 * saved. If the bot tank dies before the player is back, the save is dropped.
 *
 * Every save, return and drop is logged to logs/tank_reconnect.log.
 * l4d_tank_reconnect 0 turns the give-back off (saves are still logged).
 */

#define ZC_TANK 5
#define MAX_SAVES 4

#define VIA_REPLACE_TANK 0   // this plugin's ReplaceTank (sm_inf / team lock)
#define VIA_TAKEOVER 1       // the game's own takeover on a raw jointeam
#define VIA_BOT_REPLACE 2    // bot_player_replace
char VIA_NAMES[][] = { "ReplaceTank", "game takeover", "bot_player_replace" };

ConVar g_cvEnabled;
char g_sLog[PLATFORM_MAX_PATH];

// Pending: filled during the disconnect frame, keyed by the leaving client.
int g_iPendBot[MAXPLAYERS + 1];      // userid of the bot that took the body, 0 = none
int g_iPendFrus[MAXPLAYERS + 1];
int g_iPendPass[MAXPLAYERS + 1];
bool g_bPendLeaving[MAXPLAYERS + 1];
char g_sPendAuth[MAXPLAYERS + 1][32];
char g_sPendName[MAXPLAYERS + 1][MAX_NAME_LENGTH];
float g_fPutInAt[MAXPLAYERS + 1];    // engine time each client was put in server

// Saves: a tank waiting for its player.
bool g_bSaveUsed[MAX_SAVES];
char g_sSaveAuth[MAX_SAVES][32];
char g_sSaveName[MAX_SAVES][MAX_NAME_LENGTH];
int g_iSaveBot[MAX_SAVES];
int g_iSaveFrus[MAX_SAVES];
int g_iSavePass[MAX_SAVES];
float g_fSaveAt[MAX_SAVES];
bool g_bSaveReplacing[MAX_SAVES];   // our ReplaceTank is in flight; its bot death is not a takeover

public Plugin myinfo =
{
	name = "Tank Reconnect",
	author = "Malevolence",
	description = "Gives a tank back to its player when they rejoin after a disconnect, with the same rage and pass count",
	version = PLUGIN_VERSION,
	url = "https://riversidepug.com"
};

public void OnPluginStart()
{
	g_cvEnabled = CreateConVar("l4d_tank_reconnect", "1", "1 = give a tank back to its player when they rejoin, 0 = log only.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	BuildPath(Path_SM, g_sLog, sizeof(g_sLog), "logs/tank_reconnect.log");

	HookEvent("player_bot_replace", Event_PlayerBotReplace);
	HookEvent("bot_player_replace", Event_BotPlayerReplace);
	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
	HookEvent("player_team", Event_PlayerTeam);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("round_start", Event_Reset, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_Reset, EventHookMode_PostNoCopy);

	RegAdminCmd("sm_tank_reconnect_status", Cmd_Status, ADMFLAG_ROOT, "Alive tanks (rage, health, pass count) and saved tanks waiting for their player.");
}

public Action Cmd_Status(int client, int args)
{
	ReplyToCommand(client, "[tank_reconnect] passes=%d enabled=%d", L4D2Direct_GetTankPassedCount(), g_cvEnabled.IntValue);
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsAliveTank(i)) continue;
		ReplyToCommand(client, "  tank %d \"%N\" %s hp=%d frustration=%d", i, i, IsFakeClient(i) ? "AI" : "human", GetClientHealth(i), Frustration(i));
	}
	for (int i = 0; i < MAX_SAVES; i++)
	{
		if (!g_bSaveUsed[i]) continue;
		ReplyToCommand(client, "  save \"%s\" %s bot=%d frustration=%d passes=%d age=%.0f s", g_sSaveName[i], g_sSaveAuth[i],
			GetClientOfUserId(g_iSaveBot[i]), g_iSaveFrus[i], g_iSavePass[i], GetGameTime() - g_fSaveAt[i]);
	}
	return Plugin_Handled;
}

public void OnMapStart()
{
	ClearSaves("map start");
}

public void Event_Reset(Event event, const char[] name, bool dontBroadcast)
{
	ClearSaves(name);
}

void ClearSaves(const char[] why)
{
	for (int i = 0; i < MAX_SAVES; i++)
	{
		if (g_bSaveUsed[i])
			LogToFileEx(g_sLog, "drop \"%s\" %s: %s", g_sSaveName[i], g_sSaveAuth[i], why);
		g_bSaveUsed[i] = false;
	}
}

bool IsAliveTank(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client)
		&& GetClientTeam(client) == 3 && IsPlayerAlive(client)
		&& GetEntProp(client, Prop_Send, "m_zombieClass") == ZC_TANK;
}

/**
 * Fallback when player_bot_replace was not seen: the userid of the only alive
 * AI tank that connected in the last two seconds (the bot the game just made
 * for the leaver), or 0. An older AI tank is never taken for the leaver's.
 */
int LoneBotTank()
{
	int found = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsAliveTank(i) || !IsFakeClient(i) || GetEngineTime() - g_fPutInAt[i] > 2.0) continue;
		if (found != 0) return 0;
		found = GetClientUserId(i);
	}
	return found;
}

int Frustration(int client)
{
	return GetEntProp(client, Prop_Send, "m_frustration");
}

void ClearPending(int client)
{
	g_iPendBot[client] = 0;
	g_bPendLeaving[client] = false;
	g_sPendAuth[client][0] = '\0';
}

public void OnClientPutInServer(int client)
{
	g_fPutInAt[client] = GetEngineTime();
	ClearPending(client);
}

/**
 * The two events of one disconnect can come in either order, so each stores
 * what it knows and the commit runs a frame later, once both have fired.
 */
public void Event_PlayerBotReplace(Event event, const char[] name, bool dontBroadcast)
{
	int player = GetClientOfUserId(event.GetInt("player"));
	int bot = GetClientOfUserId(event.GetInt("bot"));
	if (player <= 0 || !IsClientInGame(player) || IsFakeClient(player)) return;
	if (!IsAliveTank(bot)) return;

	g_iPendBot[player] = GetClientUserId(bot);
	// Before the disconnect handler saw a tank the player's own entity still
	// carries the rage; afterwards it may not, so keep the larger reading.
	int frus = Frustration(bot);
	int own = Frustration(player);
	if (own > frus) frus = own;
	if (!g_bPendLeaving[player] || frus > g_iPendFrus[player])
		g_iPendFrus[player] = frus;
	if (!g_bPendLeaving[player])
	{
		g_iPendPass[player] = L4D2Direct_GetTankPassedCount();
		GetClientAuthId(player, AuthId_Engine, g_sPendAuth[player], sizeof(g_sPendAuth[]), false);
		GetClientName(player, g_sPendName[player], sizeof(g_sPendName[]));
	}
	RequestFrame(Frame_Commit, GetClientUserId(player));
}

public Action Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client <= 0 || !IsClientInGame(client) || IsFakeClient(client)) return Plugin_Continue;

	bool tank = IsAliveTank(client);
	if (!tank && g_iPendBot[client] == 0) return Plugin_Continue;

	g_bPendLeaving[client] = true;
	if (tank)
	{
		g_iPendFrus[client] = Frustration(client);
		g_iPendPass[client] = L4D2Direct_GetTankPassedCount();
	}
	if (g_sPendAuth[client][0] == '\0')
	{
		GetClientAuthId(client, AuthId_Engine, g_sPendAuth[client], sizeof(g_sPendAuth[]), false);
		GetClientName(client, g_sPendName[client], sizeof(g_sPendName[]));
	}
	// The userid dies with the client, so pass the index; the commit only
	// trusts it through the leaving flag and the stored auth.
	RequestFrame(Frame_CommitIndex, client);
	return Plugin_Continue;
}

public void Frame_Commit(int userid)
{
	// Still connected a frame after a bot replaced them: that was a
	// frustration loss or a team move, not a disconnect.
	int client = GetClientOfUserId(userid);
	if (client > 0 && !g_bPendLeaving[client])
		ClearPending(client);
}

public void Frame_CommitIndex(int client)
{
	if (!g_bPendLeaving[client]) return;

	if (g_iPendBot[client] == 0)
		g_iPendBot[client] = LoneBotTank();
	if (g_iPendBot[client] == 0 || !IsAliveTank(GetClientOfUserId(g_iPendBot[client])))
	{
		LogToFileEx(g_sLog, "left \"%s\" %s as tank, but no bot tank took the body; nothing saved",
			g_sPendName[client], g_sPendAuth[client]);
		ClearPending(client);
		return;
	}

	int slot = -1;
	for (int i = 0; i < MAX_SAVES; i++)
	{
		if (g_bSaveUsed[i] && StrEqual(g_sSaveAuth[i], g_sPendAuth[client])) { slot = i; break; }
	}
	for (int i = 0; slot < 0 && i < MAX_SAVES; i++)
	{
		if (!g_bSaveUsed[i]) slot = i;
	}
	if (slot < 0)
	{
		LogToFileEx(g_sLog, "left \"%s\" %s as tank, no free save slot", g_sPendName[client], g_sPendAuth[client]);
		ClearPending(client);
		return;
	}

	g_bSaveUsed[slot] = true;
	g_bSaveReplacing[slot] = false;
	strcopy(g_sSaveAuth[slot], sizeof(g_sSaveAuth[]), g_sPendAuth[client]);
	strcopy(g_sSaveName[slot], sizeof(g_sSaveName[]), g_sPendName[client]);
	g_iSaveBot[slot] = g_iPendBot[client];
	g_iSaveFrus[slot] = g_iPendFrus[client];
	g_iSavePass[slot] = g_iPendPass[client];
	g_fSaveAt[slot] = GetGameTime();

	int bot = GetClientOfUserId(g_iSaveBot[slot]);
	LogToFileEx(g_sLog, "save \"%s\" %s: bot %d hp=%d frustration=%d passes=%d",
		g_sSaveName[slot], g_sSaveAuth[slot], bot, GetClientHealth(bot), g_iSaveFrus[slot], g_iSavePass[slot]);
	PrintToChatAll("\x04[Tank]\x01 %s dropped. The AI holds their tank; it goes back to them if they rejoin.", g_sSaveName[slot]);
	ClearPending(client);
}

public void Event_BotPlayerReplace(Event event, const char[] name, bool dontBroadcast)
{
	int botUserId = event.GetInt("bot");
	int player = GetClientOfUserId(event.GetInt("player"));
	if (player <= 0 || !IsClientInGame(player) || IsFakeClient(player)) return;
	for (int i = 0; i < MAX_SAVES; i++)
	{
		if (!g_bSaveUsed[i] || g_iSaveBot[i] != botUserId) continue;
		int hp = GetClientHealth(player);
		DataPack dp = new DataPack();
		dp.WriteCell(GetClientUserId(player));
		dp.WriteCell(i);
		dp.WriteCell(hp);
		dp.WriteCell(VIA_BOT_REPLACE);
		RequestFrame(Frame_Restore, dp);
		return;
	}
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("userid");
	if (userid == 0) return;
	for (int i = 0; i < MAX_SAVES; i++)
	{
		if (!g_bSaveUsed[i] || g_iSaveBot[i] != userid) continue;
		// A raw "jointeam 3" takes the AI tank over this way too: the game logs
		// the bot as dead and puts the player in the tank where it stood, with
		// no bot_player_replace. Look a frame later for a human tank on that spot.
		float pos[3];
		int bot = GetClientOfUserId(userid);
		if (bot > 0 && IsClientInGame(bot)) GetClientAbsOrigin(bot, pos);
		DataPack dp = new DataPack();
		dp.WriteCell(i);
		dp.WriteFloat(pos[0]);
		dp.WriteFloat(pos[1]);
		dp.WriteFloat(pos[2]);
		RequestFrame(Frame_BotDied, dp);
	}
}

public void Frame_BotDied(DataPack dp)
{
	dp.Reset();
	int slot = dp.ReadCell();
	float pos[3];
	pos[0] = dp.ReadFloat();
	pos[1] = dp.ReadFloat();
	pos[2] = dp.ReadFloat();
	delete dp;
	if (!g_bSaveUsed[slot] || g_bSaveReplacing[slot]) return;

	for (int c = 1; c <= MaxClients; c++)
	{
		if (!IsAliveTank(c) || IsFakeClient(c)) continue;
		float at[3];
		GetClientAbsOrigin(c, at);
		if (GetVectorDistance(at, pos) > 64.0) continue;
		DataPack r = new DataPack();
		r.WriteCell(GetClientUserId(c));
		r.WriteCell(slot);
		r.WriteCell(GetClientHealth(c));
		r.WriteCell(VIA_TAKEOVER);
		RequestFrame(Frame_Restore, r);
		return;
	}
	LogToFileEx(g_sLog, "drop \"%s\" %s: the bot tank died first", g_sSaveName[slot], g_sSaveAuth[slot]);
	g_bSaveUsed[slot] = false;
}

public void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	if (event.GetInt("team") != 3 || event.GetBool("disconnect")) return;
	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);
	if (client <= 0 || IsFakeClient(client)) return;
	// player_team fires before the move lands. Poll by frames, not a timer:
	// the leave pause is a real engine pause and SourceMod timers do not run
	// while the server is paused, but game frames (and RequestFrame) do.
	DataPack dp = new DataPack();
	dp.WriteCell(userid);
	dp.WriteCell(0);
	RequestFrame(Frame_TryReturn, dp);
}

public void Frame_TryReturn(DataPack dp)
{
	dp.Reset();
	int userid = dp.ReadCell();
	int tries = dp.ReadCell();
	delete dp;
	int client = GetClientOfUserId(userid);
	if (client <= 0 || !IsClientInGame(client)) return;
	if (GetClientTeam(client) != 3)
	{
		if (tries < 200)
		{
			DataPack again = new DataPack();
			again.WriteCell(userid);
			again.WriteCell(tries + 1);
			RequestFrame(Frame_TryReturn, again);
		}
		return;
	}
	TryReturn(client, userid);
}

void TryReturn(int client, int userid)
{
	char auth[32];
	if (!GetClientAuthId(client, AuthId_Engine, auth, sizeof(auth), false)) return;

	for (int i = 0; i < MAX_SAVES; i++)
	{
		if (!g_bSaveUsed[i] || !StrEqual(g_sSaveAuth[i], auth)) continue;

		// The game's own takeover can land in the same frame as this team move:
		// then the bot is already dead or the player already the tank, and the
		// takeover path (Frame_BotDied) restores the rage. Leave the save to it;
		// a bot that really died is dropped there.
		int bot = GetClientOfUserId(g_iSaveBot[i]);
		if (!IsAliveTank(bot) || !IsFakeClient(bot) || IsAliveTank(client))
			return;
		if (!g_cvEnabled.BoolValue)
		{
			LogToFileEx(g_sLog, "back \"%N\" %s after %.0f s: give-back off, the AI keeps the tank", client, auth, GetGameTime() - g_fSaveAt[i]);
			g_bSaveUsed[i] = false;
			return;
		}

		int hp = GetClientHealth(bot);
		int botUserId = g_iSaveBot[i];
		g_bSaveReplacing[i] = true;
		L4D_ReplaceTank(bot, client);
		// ReplaceTank was written for a pass between two players. When the old
		// tank is a bot, the bot comes straight back as a SECOND tank (seen on
		// the rig 2026-10-06, during a pause). Kick it once the swap has landed.
		DataPack kick = new DataPack();
		kick.WriteCell(botUserId);
		kick.WriteCell(userid);
		RequestFrame(Frame_KickOldBot, kick);
		DataPack dp = new DataPack();
		dp.WriteCell(userid);
		dp.WriteCell(i);
		dp.WriteCell(hp);
		dp.WriteCell(VIA_REPLACE_TANK);
		RequestFrame(Frame_Restore, dp);
		return;
	}
}

public void Frame_KickOldBot(DataPack kick)
{
	kick.Reset();
	int bot = GetClientOfUserId(kick.ReadCell());
	int client = GetClientOfUserId(kick.ReadCell());
	delete kick;
	if (bot <= 0 || !IsClientInGame(bot) || !IsFakeClient(bot)) return;
	// riverside1 (audit A1): L4D_ReplaceTank is void, so a refused swap is only visible
	// here. Kick the bot only when the returning player really holds the tank now;
	// otherwise the AI keeps it (Frame_Restore logs the FAILED line).
	if (client <= 0 || !IsClientInGame(client) || IsFakeClient(client) || !IsAliveTank(client))
	{
		LogToFileEx(g_sLog, "keep the tank bot %d: the swap did not land (player %d)", bot, client);
		return;
	}
	LogToFileEx(g_sLog, "kick the old tank bot %d (alive=%d tank=%d)", bot, IsPlayerAlive(bot),
		GetClientTeam(bot) == 3 && GetEntProp(bot, Prop_Send, "m_zombieClass") == ZC_TANK);
	KickClient(bot, "tank went back to its player");
}

public void Frame_Restore(DataPack dp)
{
	dp.Reset();
	int client = GetClientOfUserId(dp.ReadCell());
	int slot = dp.ReadCell();
	int hp = dp.ReadCell();
	int via = dp.ReadCell();
	delete dp;
	if (!g_bSaveUsed[slot]) return;
	g_bSaveUsed[slot] = false;

	if (!IsAliveTank(client))
	{
		LogToFileEx(g_sLog, "FAILED \"%s\" %s: ReplaceTank did not make them the tank", g_sSaveName[slot], g_sSaveAuth[slot]);
		return;
	}

	int passesNow = L4D2Direct_GetTankPassedCount();
	int frusNow = Frustration(client);
	SetEntProp(client, Prop_Send, "m_frustration", g_iSaveFrus[slot]);
	L4D2Direct_SetTankPassedCount(g_iSavePass[slot]);

	char auth[32];
	GetClientAuthId(client, AuthId_Engine, auth, sizeof(auth), false);
	bool owner = StrEqual(auth, g_sSaveAuth[slot]);
	LogToFileEx(g_sLog, "%s \"%N\" %s after %.0f s via %s (tank of \"%s\"): hp %d -> %d, frustration %d -> %d, passes %d (was %d after the takeover)",
		owner ? "return" : "taken", client, auth, GetGameTime() - g_fSaveAt[slot], VIA_NAMES[via], g_sSaveName[slot], hp, GetClientHealth(client),
		frusNow, g_iSaveFrus[slot], g_iSavePass[slot], passesNow);
	if (owner)
		PrintToChatAll("\x04[Tank]\x01 %N is back in their tank (rage %d%% left%s).", client,
			100 - g_iSaveFrus[slot], g_iSavePass[slot] > 1 ? ", already passed once" : "");
	else
		PrintToChatAll("\x04[Tank]\x01 %N took %s's tank with its rage as it was (%d%% left).", client,
			g_sSaveName[slot], 100 - g_iSaveFrus[slot]);
}
