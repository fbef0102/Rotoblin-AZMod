#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <dhooks>

#define PLUGIN_VERSION "1.1"
#define GAMEDATA "l4d_tank_punch_wall_fix"

#define TEAM_SURVIVOR	2
#define PUNCH_MASK		0x0600400B	// the mask of every trace in CTankClaw::SweepFist (MASK_SOLID | CONTENTS_DEBRIS)

// Stops tank punches landing through walls.
//
// Cause (match 723, farm01, 2026-10-18; reproduced on the punch rig the same night): in versus
// CTankClaw::SweepFist (server.so 0x30acbe) only lets a punch hit a survivor if a line from the
// tank's eye to the fist at contact does not hit the world: the trace runs with PUNCH_MASK and
// the test is CGameTrace::DidHitWorld(), i.e. "the FIRST thing the line touched is the world".
// When anything else sits between the eye and the wall, the line stops on that entity first,
// DidHitWorld() is false and the punch goes through the wall behind it. In match 723 it was the
// infected ladder on the outside of the farmhouse's west wall (func_simpleladder, brush contents
// 0x30000008: GRATE is in PUNCH_MASK). A tank climbing it punched mado, standing inside, through
// 8 units of solid wall; with the fist past the wall (the scan's seed is eye + forward * 56, and
// the arm reaches through) the sweep itself never touches the wall. Any ladder, door, prop,
// func_brush or common in front of a wall does the same. Rig: tank behind the ladder, the stock
// check stopped on the ladder and the survivor took 24; the same spacing beside the ladder
// stopped on the wall, no hit.
//
// Fix: CTankClaw::OnHit (pre) on a survivor, during a SweepFist: redo the game's line from the
// tank's eye to the trace's endpos (the fist cube's centre at contact, the point the game used)
// against the world only (brushes and static props, every entity ignored). If the world is in
// the way the hit is dropped. That is the rule Valve wrote, with the entity in front no longer
// hiding the wall. Hits the stock check already allowed with a clear world line are untouched,
// and so are ground pounds (GroundPound calls OnHit itself, no line of sight by design).
//
// 1.1 (2026-10-20 log review): 53 of the first 54 BLOCK lines were repeat touches of a survivor
// the same swing had already hit (bFirstHit false, no damage), and the "wall" was 13 to 33 units
// BEHIND the survivor, because the line runs on to the fist cube's centre past him. Only a first
// hit is judged now, and a hit is left alone when the stock line, entities included, reaches the
// victim before anything else: nothing stands between the eye and him, so no wall can either.
// Without that, a survivor with his back to a wall could lose a real first hit.
//
// l4d_tank_punch_wall_fix_enable: 0 off, 1 drop the hit, 2 log only.
// l4d_tank_punch_wall_fix_log 1: logs/tank_punch_wall_fix.log, one line per dropped hit with the
// entity that fooled the stock check.

ConVar g_cvEnable, g_cvLog;
char g_sLog[PLATFORM_MAX_PATH];
int g_iInSweep;		// tank client whose SweepFist is running, 0 if none
int g_iOffEndPos = 12, g_iOffEnt = 76;	// CGameTrace endpos / m_pEnt, from gamedata

public Plugin myinfo =
{
	name = "[L4D1] Tank Punch Wall Fix",
	author = "Malevolence",
	description = "A tank punch can no longer hit a survivor through a wall when an entity stands in front of the wall.",
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
	int off = gd.GetOffset("CGameTrace::endpos");
	if( off != -1 ) g_iOffEndPos = off;
	off = gd.GetOffset("CGameTrace::m_pEnt");
	if( off != -1 ) g_iOffEnt = off;
	DynamicDetour dSweep = DynamicDetour.FromConf(gd, "CTankClaw::SweepFist");
	DynamicDetour dHit = DynamicDetour.FromConf(gd, "CTankClaw::OnHit");
	if( !dSweep || !dSweep.Enable(Hook_Pre, Detour_SweepPre) || !dSweep.Enable(Hook_Post, Detour_SweepPost) )
		SetFailState("Failed to detour CTankClaw::SweepFist");
	if( !dHit || !dHit.Enable(Hook_Pre, Detour_OnHitPre) )
		SetFailState("Failed to detour CTankClaw::OnHit");
	delete gd;

	CreateConVar("l4d_tank_punch_wall_fix_version", PLUGIN_VERSION, "Tank Punch Wall Fix version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	g_cvEnable = CreateConVar("l4d_tank_punch_wall_fix_enable", "1", "0 = off, 1 = drop punch hits the world blocks from the tank's eye, 2 = log only.", FCVAR_NOTIFY, true, 0.0, true, 2.0);
	g_cvLog = CreateConVar("l4d_tank_punch_wall_fix_log", "1", "Log every dropped (or, in mode 2, would-be dropped) hit to logs/tank_punch_wall_fix.log.", FCVAR_NONE, true, 0.0, true, 1.0);
	BuildPath(Path_SM, g_sLog, sizeof(g_sLog), "logs/tank_punch_wall_fix.log");
}

int OwnerTank(int claw)
{
	if( claw <= MaxClients || !IsValidEntity(claw) ) return 0;
	int owner = GetEntPropEnt(claw, Prop_Data, "m_hOwnerEntity");
	return (owner > 0 && owner <= MaxClients && IsClientInGame(owner)) ? owner : 0;
}

MRESReturn Detour_SweepPre(int claw, DHookParam hParams)
{
	g_iInSweep = OwnerTank(claw);
	return MRES_Ignored;
}

MRESReturn Detour_SweepPost(int claw, DHookParam hParams)
{
	g_iInSweep = 0;
	return MRES_Ignored;
}

bool Filter_WorldOnly(int entity, int contentsMask)
{
	return entity <= 0;	// the world (static props report as the world too)
}

bool Filter_NotTank(int entity, int contentsMask, int tank)
{
	return entity != tank;
}

// void CTankClaw::OnHit(CGameTrace &tr, const Vector &dir, bool bFirstHit)
MRESReturn Detour_OnHitPre(int claw, DHookParam hParams)
{
	int mode = g_cvEnable.IntValue;
	if( mode == 0 ) return MRES_Ignored;
	int tank = g_iInSweep;
	if( tank == 0 || OwnerTank(claw) != tank ) return MRES_Ignored;	// not a fist sweep (ground pound, other weapon)
	if( !hParams.Get(3) ) return MRES_Ignored;	// a repeat touch this swing: no damage, nothing to judge

	Address tr = view_as<Address>(hParams.Get(1));
	if( tr == Address_Null ) return MRES_Ignored;
	Address pEnt = view_as<Address>(LoadFromAddress(tr + view_as<Address>(g_iOffEnt), NumberType_Int32));
	if( pEnt == Address_Null ) return MRES_Ignored;
	int victim = 0;
	for( int i = 1; i <= MaxClients; i++ )
		if( IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVOR && GetEntityAddress(i) == pEnt ) { victim = i; break; }
	if( victim == 0 ) return MRES_Ignored;	// not a survivor (common, prop, door, SI...)

	float eye[3], end[3];
	GetClientEyePosition(tank, eye);
	for( int k = 0; k < 3; k++ )
		end[k] = view_as<float>(LoadFromAddress(tr + view_as<Address>(g_iOffEndPos + k * 4), NumberType_Int32));

	Handle wt = TR_TraceRayFilterEx(eye, end, PUNCH_MASK, RayType_EndPoint, Filter_WorldOnly);
	bool blocked = TR_DidHit(wt);
	float wall[3];
	TR_GetEndPosition(wall, wt);
	delete wt;
	if( !blocked ) return MRES_Ignored;

	// what the stock line stops on first; the victim himself means the way to him is clear
	Handle st = TR_TraceRayFilterEx(eye, end, PUNCH_MASK, RayType_EndPoint, Filter_NotTank, tank);
	int by = TR_GetEntityIndex(st);
	delete st;
	if( by == victim ) return MRES_Ignored;

	if( g_cvLog.BoolValue )
	{
		char cls[64] = "world", map[64];
		if( by > 0 && IsValidEntity(by) ) GetEntityClassname(by, cls, sizeof(cls));
		GetCurrentMap(map, sizeof(map));
		float to[3], vo[3];
		GetClientAbsOrigin(tank, to);
		GetClientAbsOrigin(victim, vo);
		LogToFileEx(g_sLog, "%s map=%s tank=\"%N\" victim=\"%N\" tank_pos=%.1f %.1f %.1f victim_pos=%.1f %.1f %.1f eye=%.1f %.1f %.1f hit=%.1f %.1f %.1f wall=%.1f %.1f %.1f stock_saw=%s(%d)",
			mode == 1 ? "BLOCK" : "WOULD", map, tank, victim, to[0], to[1], to[2], vo[0], vo[1], vo[2],
			eye[0], eye[1], eye[2], end[0], end[1], end[2], wall[0], wall[1], wall[2], cls, by);
	}
	return mode == 1 ? MRES_Supercede : MRES_Ignored;
}
