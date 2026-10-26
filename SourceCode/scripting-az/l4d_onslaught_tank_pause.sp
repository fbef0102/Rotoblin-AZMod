/*
 * l4d_onslaught_tank_pause: no endless horde while a tank is up.
 *
 * The converted L4D2 maps rebuild their onslaughts (hordes that keep coming
 * until a button) with director_panic_forever: the stripper relay
 * l4d1_onslaught_on sets it to 1 and fires a PanicEvent, l4d1_onslaught_off
 * sets it back to 0 (l4d2to1/onslaught.py). With a tank in play the horde
 * never lets up, so the survivors cannot fight the tank.
 *
 * While an onslaught runs and any tank is alive, director_panic_forever is
 * held at 0, so the running panic winds down. When the last tank dies and the
 * onslaught has not been ended by its button meanwhile, it is turned back on
 * with a fresh PanicEvent. An onslaught that starts with a tank already up
 * waits for the tank the same way.
 */
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION	"1.0"
#define TEAM_INFECTED	3
#define ZC_TANK			5

ConVar g_cvEnable;
ConVar g_cvPanicForever;
bool g_bOnslaught;	// l4d1_onslaught_on fired and _off has not
bool g_bPaused;		// we are holding director_panic_forever at 0 for a tank

public Plugin myinfo =
{
	name = "l4d_onslaught_tank_pause",
	author = "Malevolence",
	description = "Pauses converted L4D2 onslaught hordes while a tank is alive",
	version = PLUGIN_VERSION,
	url = "https://github.com/Volence/riverside-l4d-plugins"
};

public void OnPluginStart()
{
	g_cvEnable = CreateConVar("l4d_onslaught_tank_pause_enable", "1", "1 = stop onslaught hordes while a tank is alive", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	CreateConVar("l4d_onslaught_tank_pause_version", PLUGIN_VERSION, "l4d_onslaught_tank_pause version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	g_cvPanicForever = FindConVar("director_panic_forever");
	g_cvPanicForever.AddChangeHook(OnPanicForeverChanged);

	HookEntityOutput("logic_relay", "OnTrigger", OnRelayTrigger);
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("tank_spawn", Event_TankSpawn, EventHookMode_PostNoCopy);
	HookEvent("player_death", Event_PlayerDeath);
}

public void OnMapStart()
{
	g_bOnslaught = false;
	g_bPaused = false;
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_bOnslaught = false;
	g_bPaused = false;
}

void OnRelayTrigger(const char[] output, int caller, int activator, float delay)
{
	if (!IsValidEntity(caller))
		return;

	char relay[64];
	GetEntPropString(caller, Prop_Data, "m_iName", relay, sizeof(relay));
	if (StrEqual(relay, "l4d1_onslaught_on"))
	{
		g_bOnslaught = true;
		// The relay's sm_cvar runs after this hook; OnPanicForeverChanged puts it back to 0 if a tank is up
		if (g_cvEnable.BoolValue && CountLiveTanks() > 0)
			g_bPaused = true;
	}
	else if (StrEqual(relay, "l4d1_onslaught_off"))
	{
		g_bOnslaught = false;
		g_bPaused = false;
	}
}

void OnPanicForeverChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (g_bPaused && convar.IntValue != 0)
		convar.IntValue = 0;
}

void Event_TankSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_cvEnable.BoolValue || !g_bOnslaught || g_bPaused)
		return;

	g_bPaused = true;
	g_cvPanicForever.IntValue = 0;
	PrintToChatAll("\x04[Horde]\x01 Tank! The endless horde stops until the tank is dead.");
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bPaused)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client > 0 && IsClientInGame(client) && GetClientTeam(client) == TEAM_INFECTED
		&& GetEntProp(client, Prop_Send, "m_zombieClass") == ZC_TANK)
		CreateTimer(0.5, Timer_CheckResume, _, TIMER_FLAG_NO_MAPCHANGE);
}

public void OnClientDisconnect(int client)
{
	// A tank kicked or dropped without a death event (a bot taking over fires tank_spawn again)
	if (g_bPaused)
		CreateTimer(0.5, Timer_CheckResume, _, TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_CheckResume(Handle timer)
{
	if (!g_bPaused || CountLiveTanks() > 0)
		return Plugin_Stop;

	g_bPaused = false;
	if (!g_bOnslaught)
		return Plugin_Stop;

	g_cvPanicForever.IntValue = 1;
	int director = FindEntityByClassname(-1, "info_director");
	if (director != -1)
		AcceptEntityInput(director, "PanicEvent");
	PrintToChatAll("\x04[Horde]\x01 The tank is dead. The endless horde is back.");
	return Plugin_Stop;
}

int CountLiveTanks()
{
	int count;
	for (int i = 1; i <= MaxClients; i++)
	{
		// A dying tank stays alive and incapacitated through its death animation
		if (IsClientInGame(i) && GetClientTeam(i) == TEAM_INFECTED && IsPlayerAlive(i)
			&& GetEntProp(i, Prop_Send, "m_zombieClass") == ZC_TANK
			&& !GetEntProp(i, Prop_Send, "m_isIncapacitated"))
			count++;
	}
	return count;
}
