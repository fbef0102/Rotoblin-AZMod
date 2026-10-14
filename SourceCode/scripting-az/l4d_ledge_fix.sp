/*
 * l4d_ledge_fix: no ledge hangs over drops that could not hurt.
 *
 * The game only lets a survivor grab a ledge when it predicts that the fall
 * would do at least 1 damage (CTerrorGameMovement::CheckForLedges calls
 * CTerrorPlayer::EstimateFallingDamage first). That estimate simulates the
 * fall in 0.1 s steps, at most 30 of them, and only counts a step as landing
 * on a plane with normal.z > 0.7. On a steep rock face or rough terrain it
 * slides along the surface instead, can run out of steps still "falling", and
 * reports a painful fall for a drop of a few units. The survivor then hangs
 * off a rock that is barely above the floor.
 *
 * This plugin re-checks every grab with a plain hull trace straight down:
 * the speed the survivor would land at is sqrt(vz^2 + 2 * g * drop), and when
 * that is at or below fall_speed_safe the fall is harmless, so the grab is
 * blocked and the survivor simply drops. A grab over a real drop passes. If a
 * blocked survivor slides off the rock over a real cliff, the game tries the
 * grab again on a later tick and it goes through. A floor too steep to stand
 * on is followed downhill to where the survivor would come to rest, so a
 * slope that leads into a real pit still counts as the full drop.
 */
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define PLUGIN_VERSION	"1.0"
#define TEAM_SURVIVOR	2
// Past this we treat the drop as bottomless and leave the game's call alone.
#define TRACE_DEPTH		4096.0
// How many 16-unit steps down a steep face before giving up on finding a floor.
#define SLIDE_STEPS		16

ConVar g_cvMode, g_cvLog, g_cvSafe, g_cvGravity;
float g_fLastLog[MAXPLAYERS + 1];
char g_sLogPath[PLATFORM_MAX_PATH];

public Plugin myinfo =
{
	name = "l4d_ledge_fix",
	author = "Riverside",
	description = "Blocks ledge hangs over drops that would not hurt",
	version = PLUGIN_VERSION,
	url = "https://github.com/Volence/riverside-l4d-plugins"
};

public void OnPluginStart()
{
	g_cvMode = CreateConVar("l4d_ledge_fix_enable", "1", "0 = off, 1 = block harmless ledge grabs, 2 = log only (never block)", FCVAR_NOTIFY, true, 0.0, true, 2.0);
	g_cvLog = CreateConVar("l4d_ledge_fix_log", "1", "1 = write every judged grab to logs/ledge_fix.log", FCVAR_NONE, true, 0.0, true, 1.0);
	CreateConVar("l4d_ledge_fix_version", PLUGIN_VERSION, "l4d_ledge_fix version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	g_cvSafe = FindConVar("fall_speed_safe");
	g_cvGravity = FindConVar("sv_gravity");
	BuildPath(Path_SM, g_sLogPath, sizeof(g_sLogPath), "logs/ledge_fix.log");
}

public void OnClientPutInServer(int client)
{
	g_fLastLog[client] = 0.0;
}

public bool TraceFilter_World(int entity, int contentsMask)
{
	// Players and their carried props never count as the floor.
	return entity > MaxClients || entity == 0;
}

// Height from the survivor's feet down to the first floor they could stand
// on. The hull is a thin slab a little narrower than the player, so it cannot
// start inside the wall the survivor is sliding down. A face too steep to
// stand on (normal.z < 0.7) is followed downhill, 16 units at a time, the way
// the survivor would slide down it: a tank punch into rocks usually lands on
// one. Sliding never lands faster than falling the same height, so the total
// height is a safe bound. Returns false when no standable floor turns up.
bool DropBelow(const float origin[3], float &drop)
{
	float start[3], end[3], hit[3], normal[3];
	float mins[3] = { -13.0, -13.0, 0.0 };
	float maxs[3] = { 13.0, 13.0, 1.0 };
	start = origin;
	for( int step = 0; step < SLIDE_STEPS; step++ )
	{
		end = start;
		end[2] = origin[2] - TRACE_DEPTH;
		Handle tr = TR_TraceHullFilterEx(start, end, mins, maxs, MASK_PLAYERSOLID, TraceFilter_World);
		bool found = TR_DidHit(tr) && !TR_StartSolid(tr);
		if( found )
		{
			TR_GetEndPosition(hit, tr);
			TR_GetPlaneNormal(tr, normal);
		}
		delete tr;
		if( !found ) return false;
		if( normal[2] >= 0.7 )
		{
			drop = origin[2] - hit[2];
			return true;
		}
		float len = SquareRoot(normal[0] * normal[0] + normal[1] * normal[1]);
		if( len < 0.01 ) return false;
		start[0] = hit[0] + normal[0] / len * 16.0;
		start[1] = hit[1] + normal[1] / len * 16.0;
		start[2] = hit[2] + 1.0;
	}
	return false;
}

public Action L4D_OnLedgeGrabbed(int client)
{
	int mode = g_cvMode.IntValue;
	if( mode == 0 || client < 1 || client > MaxClients || !IsClientInGame(client) || GetClientTeam(client) != TEAM_SURVIVOR )
		return Plugin_Continue;

	float origin[3], vel[3], drop;
	GetClientAbsOrigin(client, origin);
	if( !DropBelow(origin, drop) )
		return Plugin_Continue;

	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vel);
	float gravity = g_cvGravity.FloatValue;
	float scale = GetEntPropFloat(client, Prop_Data, "m_flGravity");
	if( scale > 0.0 ) gravity *= scale;
	float landing = SquareRoot(vel[2] * vel[2] + 2.0 * gravity * drop);
	float safe = g_cvSafe != null ? g_cvSafe.FloatValue : 560.0;
	bool harmless = landing <= safe;

	if( g_cvLog.BoolValue )
	{
		// A blocked grab is offered again every tick while the survivor is
		// still airborne, so log each survivor at most once a second.
		float now = GetEngineTime();
		if( now - g_fLastLog[client] >= 1.0 )
		{
			g_fLastLog[client] = now;
			char map[64];
			GetCurrentMap(map, sizeof(map));
			LogToFileEx(g_sLogPath, "%s %N at %.0f %.0f %.0f drop %.1f vz %.0f landing %.0f safe %.0f -> %s",
				map, client, origin[0], origin[1], origin[2], drop, vel[2], landing, safe,
				!harmless ? "hang" : (mode == 1 ? "BLOCKED" : "would block"));
		}
	}

	return (harmless && mode == 1) ? Plugin_Handled : Plugin_Continue;
}
