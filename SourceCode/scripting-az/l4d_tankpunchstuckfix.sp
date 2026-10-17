/**
 * use sv_lagcompensationforcerestore to fix stuck instead of using a repeated timer to check.
 * https://github.com/SirPlease/L4D2-Competitive-Rework/pull/727
 */

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
#include <multicolors>
#include <l4d_lib>

public Plugin myinfo = 
{
    name =          "Tank Punch Ceiling Stuck Fix",
    author =        "Tabun, Visor, HarryPotter, Malevolence",
    description =   "Fixes the problem where tank-punches get a survivor stuck in the roof.",
    version =       "2.0-2026/10/6-riverside6",
    url =           "https://github.com/SirPlease/L4D2-Competitive-Rework"
}

#define TEAM_SURVIVOR           2


// riverside2: a punch that leaves its victim inside the world puts him back where he really was (match 505, 2026-10-05)
#define WATCH_TIME              1.0     // keep checking a punched survivor this long after the hit
ConVar  g_hCvarSolidFix, g_hCvarLog;
float   g_vPreSwing             [MAXPLAYERS + 1][3];                                       // real origin before the swing's lag compensation
float   g_vLastClear            [MAXPLAYERS + 1][3];                                       // last origin his hull fit at, since the hit
bool    g_bHitThisSwing         [MAXPLAYERS + 1];
float   g_fWatchUntil           [MAXPLAYERS + 1];
// riverside4: one move of each kind per punch. The game's own movement never carries a survivor
// into something that really blocks him, so a second "stuck" in the same flight is a false alarm;
// looping the move every tick froze him in mid air while gravity built up (match 614, p4rty took
// 30 fall damage after 87 moves through a hanging plant)
#define COLLISION_GROUP_DEBRIS              1   // Source SDK values, not in the SourceMod includes
#define COLLISION_GROUP_DEBRIS_TRIGGER      2
#define COLLISION_GROUP_INTERACTIVE_DEBRIS  3
#define COLLISION_GROUP_WEAPON              11
#define COLLISION_GROUP_PUSHAWAY            17
bool    g_bFixed                [MAXPLAYERS + 1];
bool    g_bWarped               [MAXPLAYERS + 1];
char    g_sFixLog               [PLATFORM_MAX_PATH];

ConVar sv_lagcompensationforcerestore;

public OnPluginStart()
{
    LoadTranslations("Roto2-AZ_mod.phrases");

    sv_lagcompensationforcerestore = FindConVar("sv_lagcompensationforcerestore");
    
    g_hCvarSolidFix = CreateConVar("sm_punchstuckfix_solid", "1", "1: a survivor a tank punch leaves inside the world is moved back to his last clear position. 0: off.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hCvarLog = CreateConVar("l4d_tankpunchstuckfix_log", "1", "Log tank punch stuck to logs/tank_fair_punch.log.", FCVAR_NONE, true, 0.0, true, 1.0);
    BuildPath(Path_SM, g_sFixLog, sizeof(g_sFixLog), "logs/tank_punch_stuck.log");

    HookEvent("round_start", RoundStart_Event, EventHookMode_PostNoCopy);
}

public void OnClientDisconnect(int client)
{
    // riverside3 (audit B2): the next player in this slot must not inherit a watch
    g_fWatchUntil[client] = 0.0;
    g_bHitThisSwing[client] = false;
    g_bFixed[client] = false;
    g_bWarped[client] = false;
}

public void OnMapStart()
{
    setCleanSlate();
}

void RoundStart_Event(Event event, const char[] name, bool dontBroadcast)
{
    setCleanSlate();
}

void setCleanSlate()
{
    for (int i = 1; i <= MaxClients; i++)
    {
        // riverside3 (audit B2): game time restarts with the map, so a deadline from the last
        // map would keep this slot watched against the old map's coordinates
        g_fWatchUntil[i] = 0.0;
        g_bHitThisSwing[i] = false;
        g_bFixed[i] = false;
        g_bWarped[i] = false;
    }
}

public void L4D_TankClaw_DoSwing_Pre(int tank, int claw)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		g_bHitThisSwing[i] = false;
		if (IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVOR && IsPlayerAlive(i))
			GetClientAbsOrigin(i, g_vPreSwing[i]);
	}
}

public void L4D_TankClaw_OnPlayerHit_Post(int tank, int claw, int player)
{
	sv_lagcompensationforcerestore.BoolValue = false;
	if (player > 0 && player <= MaxClients) g_bHitThisSwing[player] = true;
}

public void L4D_TankClaw_DoSwing_Post(int tank, int claw)
{
	if (!sv_lagcompensationforcerestore.BoolValue)
		sv_lagcompensationforcerestore.BoolValue = true;

	// lag compensation has restored everyone by now: anyone this swing hit must fit where he is
	if (!g_hCvarSolidFix.BoolValue) return;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!g_bHitThisSwing[i]) continue;
		g_bHitThisSwing[i] = false;
		if (!IsClientInGame(i) || GetClientTeam(i) != TEAM_SURVIVOR || !IsPlayerAlive(i)) continue;
		g_vLastClear[i] = g_vPreSwing[i];
		g_fWatchUntil[i] = GetGameTime() + WATCH_TIME;
		g_bFixed[i] = false;
		g_bWarped[i] = false;
		CheckPunchedSolid(i, "swing");
	}
}

public void OnGameFrame()
{
	float now = GetGameTime();
	for (int i = 1; i <= MaxClients; i++)
	{
		if (g_fWatchUntil[i] == 0.0) continue;
		// riverside3 (audit B1): a pinned survivor is held by the infected, not flying; stop
		// watching him so a pounce or pull inside the window is never snapped back
		if (now > g_fWatchUntil[i] || !IsClientInGame(i) || GetClientTeam(i) != TEAM_SURVIVOR || !IsPlayerAlive(i)
			|| GetEntPropEnt(i, Prop_Send, "m_pounceAttacker") > 0 || GetEntPropEnt(i, Prop_Send, "m_tongueOwner") > 0)
		{
			g_fWatchUntil[i] = 0.0;
			continue;
		}
		CheckPunchedSolid(i, "flight");
	}
}

void CheckPunchedSolid(int client, const char[] when)
{
	if (GetEntProp(client, Prop_Send, "m_isHangingFromLedge")) return;
	float pos[3];
	GetClientAbsOrigin(client, pos);
	int hit;
	if (!HullInWorld(client, pos, hit))
	{
		g_vLastClear[client] = pos;
		return;
	}
	char map[64], what[160];
	GetCurrentMap(map, sizeof(map));
	DescribeHit(hit, what, sizeof(what));
	int lastHit;
	if (g_bFixed[client] || g_bWarped[client])
	{
		// riverside4: he was already moved once this punch and is "stuck" again, so whatever the
		// trace hits is not stopping his movement; stop watching instead of pinning him every tick
		g_fWatchUntil[client] = 0.0;
		if(g_hCvarLog.BoolValue) LogToFileEx(g_sFixLog, "GIVEUP map=%s survivor=\"%N\" when=%s at=%.1f %.1f %.1f hit=%s",
			map, client, when, pos[0], pos[1], pos[2], what);
	}
	else if (!HullInWorld(client, g_vLastClear[client], lastHit))
	{
		g_bFixed[client] = true;
		TeleportEntity(client, g_vLastClear[client], NULL_VECTOR, NULL_VECTOR);   // velocity kept, the fling carries on
		if(g_hCvarLog.BoolValue) LogToFileEx(g_sFixLog, "FIX map=%s survivor=\"%N\" when=%s stuck=%.1f %.1f %.1f moved_to=%.1f %.1f %.1f ducked=%d hit=%s",
			map, client, when, pos[0], pos[1], pos[2], g_vLastClear[client][0], g_vLastClear[client][1], g_vLastClear[client][2],
			GetEntProp(client, Prop_Send, "m_bDucked"), what);
	}
	else
	{
		g_bWarped[client] = true;
		L4D_WarpToValidPositionIfStuck(client);
		GetClientAbsOrigin(client, g_vLastClear[client]);
		if(g_hCvarLog.BoolValue) LogToFileEx(g_sFixLog, "WARP map=%s survivor=\"%N\" when=%s stuck=%.1f %.1f %.1f warped_to=%.1f %.1f %.1f moved=%d hit=%s",
			map, client, when, pos[0], pos[1], pos[2], g_vLastClear[client][0], g_vLastClear[client][1], g_vLastClear[client][2],
			GetVectorDistance(pos, g_vLastClear[client]) > 0.1, what);
	}
}

bool HullInWorld(int client, const float pos[3], int &hit)
{
	float mins[3], maxs[3];
	GetEntPropVector(client, Prop_Send, "m_vecMins", mins);
	GetEntPropVector(client, Prop_Send, "m_vecMaxs", maxs);
	// riverside3 (audit B1): without CONTENTS_MONSTER, so commons or a witch standing in his
	// hull do not count as "inside the world" (the collision ports let commons walk into a
	// pinned survivor on purpose)
	// riverside6: a survivor's MOVEMENT mask (CTerrorGameMovement::PlayerSolidMask, brush-only
	// survivor value 0x14a0b) also has 0x800 (survivor-only env_player_blocker) and 0x200; with
	// MASK_PLAYERSOLID & ~CONTENTS_MONSTER (0x1400b) a survivor stuck inside a survivor-only
	// blocker read as clear. l4d-source docs/annotated/player-hull/.
	Handle tr = TR_TraceHullFilterEx(pos, pos, mins, maxs, (MASK_PLAYERSOLID & ~CONTENTS_MONSTER), TraceFilter_PlayerBlockers);
	bool solid = TR_StartSolid(tr);
	hit = TR_GetEntityIndex(tr);
	delete tr;
	return solid;
}

// riverside4: only what a survivor's movement collides with. Debris (hanging plants, small physics
// junk), interactive debris, dropped weapons and pushaway props let a player walk through them, and
// counting them as world is what kept p4rty pinned in airport01's greenhouse (match 614)
bool TraceFilter_PlayerBlockers(int entity, int contentsMask)
{
	if (entity <= MaxClients) return entity == 0;
	// riverside5: dropping CONTENTS_MONSTER does not drop commons in L4D1 (they trace as solid,
	// collision group 5), so a common overlapping a flung survivor read as "inside the world":
	// 119 of 138 logged moves 10-11..10-12 were hit=infected (up to 32 units)
	char cls[16];
	GetEntityClassname(entity, cls, sizeof(cls));
	if (StrEqual(cls, "infected") || StrEqual(cls, "witch")) return false;
	if (!HasEntProp(entity, Prop_Send, "m_CollisionGroup")) return true;
	switch (GetEntProp(entity, Prop_Send, "m_CollisionGroup"))
	{
		case COLLISION_GROUP_DEBRIS, COLLISION_GROUP_DEBRIS_TRIGGER, COLLISION_GROUP_INTERACTIVE_DEBRIS,
			COLLISION_GROUP_WEAPON, COLLISION_GROUP_PUSHAWAY:
			return false;
	}
	return true;
}

void DescribeHit(int ent, char[] buf, int len)
{
	if (ent == 0) { strcopy(buf, len, "world"); return; }
	if (ent < 0 || !IsValidEntity(ent)) { strcopy(buf, len, "?"); return; }
	char cls[64], model[96];
	GetEntityClassname(ent, cls, sizeof(cls));
	if (HasEntProp(ent, Prop_Data, "m_ModelName")) GetEntPropString(ent, Prop_Data, "m_ModelName", model, sizeof(model));
	int cg = HasEntProp(ent, Prop_Send, "m_CollisionGroup") ? GetEntProp(ent, Prop_Send, "m_CollisionGroup") : -1;
	FormatEx(buf, len, "%s:%s:cg%d", cls, model, cg);
}