#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "0.1"

#define TEAM_INFECTED		3
#define ZC_HUNTER			3
#define SWAP_MODEL			"models/infected/smoker.mdl"

// Why this exists: a Hunter killed while it shreds a pinned survivor sometimes keeps
// shredding on clients. The pounce sound (zombie_slice_*) and claw blood keep coming from
// the pin spot for the rest of the 10 s Melee_Pounce clip, and survivors think their
// teammate is still capped.
//
// Both effects are client-side animation events (AE_CL) in anim_hunter.mdl's Melee_Pounce.
// Players animate client-side and the client stops updating a dead player's animation
// state, so whatever sequence the client had at death keeps cycling and firing its
// events. Normally the client sees the pin end while the Hunter is still alive and leaves
// Melee_Pounce first; when packets are lost or reordered it can see the pin end and the
// death in one update, and the dead Hunter's player entity plays the clip out.
//
// Measured 2026-09-28 with an automated client (snd_dumpclientsounds after each death):
// 20 of 181 mid-shred deaths (11%) with 50 ms +-10 lag and 2% loss, 0 of 21 on a
// loss-free SourceTV demo.
//
// Fix: change the dead Hunter's model for a moment. A model change makes every client
// rebuild the entity's animation, which drops the frozen Melee_Pounce, and the model is
// put back before the player respawns. A dead player is not drawn (the ragdoll is a
// separate entity), so the swap is invisible. The swap waits 0.2 s: a client builds the
// ragdoll from the player's model when the ragdoll arrives, and a lost death packet would
// otherwise deliver both in one update and give a smoker corpse. Phantom shreds start 0.8 s
// or more after death, so the delay costs nothing.
//
// A/B in one session (alternate deaths, 2026-09-28): no swap 9 phantoms in 85 mid-shred
// deaths, swap (0.3 s hold) 0 in 80.
//
// Only Hunters that landed a pounce in the last few seconds are touched.

ConVar g_hCvarEnable, g_hCvarDelay, g_hCvarHold;
float g_fPounceAt[MAXPLAYERS + 1];
int g_iLife[MAXPLAYERS + 1];
char g_sModel[MAXPLAYERS + 1][PLATFORM_MAX_PATH];
int g_iSwaps;

public Plugin myinfo =
{
	name = "[L4D1] Hunter Phantom Shred Fix",
	author = "Riverside",
	description = "Stops a Hunter killed mid-pounce from shredding on clients after death.",
	version = PLUGIN_VERSION,
	url = ""
};

public void OnPluginStart()
{
	g_hCvarEnable = CreateConVar("l4d_hunter_phantom_fix_enable", "1", "Swap a dead pouncing Hunter's model so clients drop its pounce animation.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hCvarDelay = CreateConVar("l4d_hunter_phantom_fix_delay", "0.2", "Seconds after death before the swap. Clients copy the player's model into its ragdoll when the ragdoll arrives, so the swap must land after that.", FCVAR_NOTIFY, true, 0.0, true, 0.6);
	g_hCvarHold = CreateConVar("l4d_hunter_phantom_fix_hold", "1.0", "Seconds the swapped model is held before the Hunter model is put back.", FCVAR_NOTIFY, true, 0.1, true, 5.0);
	CreateConVar("l4d_hunter_phantom_fix_version", PLUGIN_VERSION, "Plugin version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	HookEvent("lunge_pounce", Ev_Pounce);
	HookEvent("player_death", Ev_Death);
	HookEvent("player_spawn", Ev_Spawn);
	RegAdminCmd("sm_phantomfix_stats", Cmd_Stats, ADMFLAG_ROOT, "Model swaps done since load");
}

public void OnMapStart()
{
	PrecacheModel(SWAP_MODEL, true);
	for (int i = 1; i <= MaxClients; i++) g_fPounceAt[i] = 0.0;
}

void Ev_Pounce(Event e, const char[] name, bool dontBroadcast)
{
	int c = GetClientOfUserId(e.GetInt("userid"));
	if (c > 0) g_fPounceAt[c] = GetGameTime();
}

void Ev_Spawn(Event e, const char[] name, bool dontBroadcast)
{
	int c = GetClientOfUserId(e.GetInt("userid"));
	if (c > 0) g_iLife[c]++;
}

void Ev_Death(Event e, const char[] name, bool dontBroadcast)
{
	if (!g_hCvarEnable.BoolValue) return;
	int c = GetClientOfUserId(e.GetInt("userid"));
	if (c < 1 || !IsClientInGame(c) || GetClientTeam(c) != TEAM_INFECTED) return;
	if (GetEntProp(c, Prop_Send, "m_zombieClass") != ZC_HUNTER) return;
	// Melee_Pounce is a 10 s clip; a Hunter that has not pounced within it cannot be in it.
	if (g_fPounceAt[c] <= 0.0 || GetGameTime() - g_fPounceAt[c] > 11.0) return;
	CreateTimer(g_hCvarDelay.FloatValue, T_Swap, GetClientUserId(c), TIMER_FLAG_NO_MAPCHANGE);
}

Action T_Swap(Handle t, int userid)
{
	Frame_Swap(userid);
	return Plugin_Stop;
}

void Frame_Swap(int userid)
{
	int c = GetClientOfUserId(userid);
	if (c < 1 || !IsClientInGame(c) || IsPlayerAlive(c)) return;
	GetEntPropString(c, Prop_Data, "m_ModelName", g_sModel[c], sizeof(g_sModel[]));
	if (!g_sModel[c][0]) return;
	SetEntityModel(c, SWAP_MODEL);
	g_iSwaps++;
	DataPack dp;
	CreateDataTimer(g_hCvarHold.FloatValue, T_Restore, dp, TIMER_FLAG_NO_MAPCHANGE);
	dp.WriteCell(userid);
	dp.WriteCell(g_iLife[c]);
}

Action T_Restore(Handle t, DataPack dp)
{
	dp.Reset();
	int c = GetClientOfUserId(dp.ReadCell());
	int life = dp.ReadCell();
	// A respawn sets the model itself; only put ours back on the same, still dead, life.
	if (c > 0 && IsClientInGame(c) && !IsPlayerAlive(c) && g_iLife[c] == life && g_sModel[c][0])
		SetEntityModel(c, g_sModel[c]);
	return Plugin_Stop;
}

Action Cmd_Stats(int client, int args)
{
	ReplyToCommand(client, "[phantomfix] %d model swaps since load", g_iSwaps);
	return Plugin_Handled;
}
