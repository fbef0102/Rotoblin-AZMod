#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.0"
#define GAMEDATA "l4d_pounce_land_fix"

#define TEAM_SURVIVOR	2
#define TEAM_INFECTED	3
#define ZC_HUNTER		3
#define STALE_AFTER		0.5	// a pending pounce older than this is never waited on

// A pounce that lands on a survivor's head keeps its damage.
//
// Cause (match 742, Death Toll 1, 2026-10-19; traced in server.so and reproduced on the head rig the
// same day): a pounce never pins on contact. CLunge::HandleCustomCollision (touch) and
// CTerrorGameMovement::SetGroundEntity (landing ON a survivor) both call CTerrorPlayer::OnLungedInto,
// which only queues the pin on the survivor: m_hPendingPounceAttacker = hunter, m_pendingPounceTime =
// now + z_pounce_delay. CTerrorPlayer::UpdatePounce, in the SURVIVOR's PostThink, pins once that time
// has passed, and OnPouncedOnSurvivor then works the damage out from the hunter's
// m_pounceStartPosition AT THAT MOMENT. A touch mid-air keeps the hunter lunging until the pin, but
// standing on a head is "ground": CLunge::UpdateAbility ends the lunge on the same tick ("ending a
// pounce"), and z_lunge_interval (0.1 s) later the hunter may pounce again. The pin comes due on the
// survivor's clock, not the hunter's, so with real clients it can come later than that (match 742:
// about 0.1 s). A hunter spamming attack then starts a fresh pounce from the head, which resets
// m_pounceStartPosition, and the queued pin lands with the new, zero distance. Fallen's ~1500 unit
// dive on majestic did 1 damage instead of the full 25. To the hunter it feels like bouncing off the
// head into a second pounce.
//
// Fix: while a survivor has a pin queued from this hunter, drop the hunter's attack button. The
// queued pin then lands with the original pounce's start position and damage. Nothing else changes:
// the pin itself is still the game's, at the game's time; the button only matters in that window.
// A queue older than STALE_AFTER is ignored so a pin the game never resolves cannot lock a hunter.
//
// l4d_pounce_land_fix_enable: 0 off, 1 on.
// l4d_pounce_land_fix_log 1: logs/pounce_land_fix.log, one line per window in which a press was dropped.

ConVar g_cvEnable, g_cvLog;
char g_sLog[PLATFORM_MAX_PATH];
int g_iOffAttacker, g_iOffTime;		// CTerrorPlayer::m_hPendingPounceAttacker / m_pendingPounceTime
int g_iDropped[MAXPLAYERS + 1];		// presses dropped in the current window
int g_iWindowVictim[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name = "[L4D1] Pounce Land Fix",
	author = "Malevolence",
	description = "A hunter landing a pounce on a survivor's head can no longer restart the pounce (and lose its damage) before the pin goes through.",
	version = PLUGIN_VERSION,
	url = ""
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if( GetEngineVersion() != Engine_Left4Dead )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	GameData gd = new GameData(GAMEDATA);
	if( !gd ) SetFailState("Missing gamedata %s", GAMEDATA);
	g_iOffAttacker = gd.GetOffset("CTerrorPlayer::m_hPendingPounceAttacker");
	g_iOffTime = gd.GetOffset("CTerrorPlayer::m_pendingPounceTime");
	delete gd;
	if( g_iOffAttacker == -1 || g_iOffTime == -1 ) SetFailState("Missing pending pounce offsets in gamedata %s", GAMEDATA);

	CreateConVar("l4d_pounce_land_fix_version", PLUGIN_VERSION, "Pounce Land Fix version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	g_cvEnable = CreateConVar("l4d_pounce_land_fix_enable", "1", "0 = off, 1 = a hunter cannot pounce again while his landed pounce is still queued on a survivor.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvLog = CreateConVar("l4d_pounce_land_fix_log", "1", "Log each window in which a hunter's attack was dropped to logs/pounce_land_fix.log.", FCVAR_NONE, true, 0.0, true, 1.0);
	BuildPath(Path_SM, g_sLog, sizeof(g_sLog), "logs/pounce_land_fix.log");
}

public void OnClientDisconnect(int client)
{
	g_iDropped[client] = 0;
	g_iWindowVictim[client] = 0;
}

// The survivor with a pin queued from this hunter, 0 if none.
int PendingVictim(int hunter)
{
	float now = GetGameTime();
	for( int i = 1; i <= MaxClients; i++ )
	{
		if( !IsClientInGame(i) || GetClientTeam(i) != TEAM_SURVIVOR ) continue;
		float due = GetEntDataFloat(i, g_iOffTime);
		if( due <= 0.0 || due < now - STALE_AFTER ) continue;
		if( GetEntDataEnt2(i, g_iOffAttacker) == hunter ) return i;
	}
	return 0;
}

void CloseWindow(int client)
{
	int victim = g_iWindowVictim[client];
	if( g_iDropped[client] > 0 && g_cvLog.BoolValue && IsClientInGame(client) )
	{
		char map[64], id[32], vname[MAX_NAME_LENGTH] = "?";
		GetCurrentMap(map, sizeof(map));
		if( !GetClientAuthId(client, AuthId_Steam2, id, sizeof(id)) ) strcopy(id, sizeof(id), "?");
		if( victim > 0 && IsClientInGame(victim) ) GetClientName(victim, vname, sizeof(vname));
		float pos[3];
		GetClientAbsOrigin(client, pos);
		LogToFileEx(g_sLog, "held \"%N\" <%s> on %s at %.0f %.0f %.0f: %d attack presses dropped while the pin on \"%s\" was queued",
			client, id, map, pos[0], pos[1], pos[2], g_iDropped[client], vname);
	}
	g_iDropped[client] = 0;
	g_iWindowVictim[client] = 0;
}

public Action OnPlayerRunCmd(int client, int &buttons)
{
	if( !(buttons & IN_ATTACK) )
	{
		if( g_iDropped[client] > 0 && PendingVictimCheap(client) == 0 ) CloseWindow(client);
		return Plugin_Continue;
	}
	if( !g_cvEnable.BoolValue || GetClientTeam(client) != TEAM_INFECTED || !IsPlayerAlive(client)
		|| GetEntProp(client, Prop_Send, "m_zombieClass") != ZC_HUNTER || GetEntProp(client, Prop_Send, "m_isGhost") )
	{
		if( g_iDropped[client] > 0 ) CloseWindow(client);
		return Plugin_Continue;
	}
	int victim = PendingVictim(client);
	if( victim == 0 )
	{
		if( g_iDropped[client] > 0 ) CloseWindow(client);
		return Plugin_Continue;
	}
	g_iWindowVictim[client] = victim;
	g_iDropped[client]++;
	buttons &= ~IN_ATTACK;
	return Plugin_Changed;
}

// Only reached for a client that had a press dropped, so the survivor scan stays off the hot path.
int PendingVictimCheap(int client)
{
	return IsClientInGame(client) && IsPlayerAlive(client) ? PendingVictim(client) : 0;
}
