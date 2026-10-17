/*
 * l4d_ledge_fix: no ledge hangs over drops that could not hurt.
 *
 * How the game decides (server.so decompile, l4d-source docs/annotated/ledge-hang/):
 * CTerrorGameMovement::CheckForLedges lets a survivor start a grab only when
 * CTerrorPlayer::EstimateFallingDamage() is at least 95 (0x6a7e4b), about a 320 to 353
 * unit fall from rest. CheckForLedge then needs vz <= -400, 40 units of air and no
 * standable floor within 90 units under the hanging feet, tested with an 8x8 box. The
 * estimate simulates the fall in 0.1 s steps; on a face steeper than normal.z 0.7 it
 * REFLECTS the velocity (overbounce 2.0, real movement uses 1.0), which can throw the
 * simulated body off somewhere deep. So a short drop hangs when the simulation bounces
 * off steep rock into a deep spot AND the 8x8 floor check misses the real floor.
 * (Not because the estimate "runs out of steps": after 30 steps it returns the damage for
 * its current simulated speed.)
 *
 * This plugin re-checks every grab with plain hull traces down, at the survivor and along
 * where their horizontal speed carries them in the next half second, and takes the deepest
 * floor: the speed they would land at is sqrt(vz^2 + 2 * g * drop). The grab is blocked
 * when that fall is harmless (l4d_ledge_fix_min_damage 0, the default) or does less than
 * l4d_ledge_fix_min_damage damage (95 would match the game's own rule). If a blocked
 * survivor slides over a real cliff, the game tries the grab again on a later tick and it
 * goes through. A floor too steep to stand on is followed downhill to where the survivor
 * would come to rest, so a slope into a real pit still counts as the full drop.
 *
 * 1.1: game's trace rules (survivor movement mask 0x2014a0b; commons, the witch, players
 * and debris are never the floor), the horizontal look-ahead (1.0 traced straight down
 * only and could block a fast survivor over a real pit's lip), the min_damage cvar, and
 * the game's own estimate in the log next to ours.
 */
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define PLUGIN_VERSION	"1.1"
#define TEAM_SURVIVOR	2
// Past this we treat the drop as bottomless and leave the game's call alone.
#define TRACE_DEPTH		4096.0
// How many 16-unit steps down a steep face before giving up on finding a floor.
#define SLIDE_STEPS		16
// CTerrorGameMovement::PlayerSolidMask for a survivor: MASK_PLAYERSOLID | CONTENTS_TEAM1 | 0x200
#define MASK_SURVIVOR_MOVE	0x2014a0b

ConVar g_cvMode, g_cvLog, g_cvSafe, g_cvFatal, g_cvGravity, g_cvMinDamage;
Handle g_hEstimate;		// CTerrorPlayer::EstimateFallingDamage, for the log only
float g_fLastLog[MAXPLAYERS + 1];
char g_sLogPath[PLATFORM_MAX_PATH];

public Plugin myinfo =
{
	name = "l4d_ledge_fix",
	author = "Malevolence",
	description = "Blocks ledge hangs over drops that would not hurt",
	version = PLUGIN_VERSION,
	url = "https://github.com/Volence/riverside-l4d-plugins"
};

public void OnPluginStart()
{
	g_cvMode = CreateConVar("l4d_ledge_fix_enable", "1", "0 = off, 1 = block harmless ledge grabs, 2 = log only (never block)", FCVAR_NOTIFY, true, 0.0, true, 2.0);
	g_cvLog = CreateConVar("l4d_ledge_fix_log", "1", "1 = write every judged grab to logs/ledge_fix.log", FCVAR_NONE, true, 0.0, true, 1.0);
	CreateConVar("l4d_ledge_fix_version", PLUGIN_VERSION, "l4d_ledge_fix version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	g_cvMinDamage = CreateConVar("l4d_ledge_fix_min_damage", "0", "Block a grab when the fall would do less than this much damage. 0 = only harmless falls (1.0 behaviour); 95 = the game's own rule, judged on our traces.", FCVAR_NOTIFY, true, 0.0, true, 250.0);
	g_cvSafe = FindConVar("fall_speed_safe");
	g_cvFatal = FindConVar("fall_speed_fatal");
	GameData gd = new GameData("l4d_ledge_fix");
	if( gd != null )
	{
		StartPrepSDKCall(SDKCall_Player);
		if( PrepSDKCall_SetFromConf(gd, SDKConf_Signature, "CTerrorPlayer::EstimateFallingDamage") )
		{
			PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_Plain);
			g_hEstimate = EndPrepSDKCall();
		}
		delete gd;
	}
	g_cvGravity = FindConVar("sv_gravity");
	BuildPath(Path_SM, g_sLogPath, sizeof(g_sLogPath), "logs/ledge_fix.log");
	RegAdminCmd("sm_ledgefix_est", Cmd_Est, ADMFLAG_ROOT, "sm_ledgefix_est <#userid|name>: the game's own fall damage estimate (ledge grabs need 95)");
}

public void OnClientPutInServer(int client)
{
	g_fLastLog[client] = 0.0;
}

// CTraceFilterNoNPCsOrPlayer with COLLISION_GROUP_PLAYER_MOVEMENT, as CheckForLedge uses:
// players, commons, the witch and debris are never the floor.
public bool TraceFilter_World(int entity, int contentsMask)
{
	if( entity == 0 ) return true;
	if( entity <= MaxClients ) return false;
	char cls[16];
	GetEntityClassname(entity, cls, sizeof(cls));
	if( StrEqual(cls, "infected") || StrEqual(cls, "witch") ) return false;
	int group = GetEntProp(entity, Prop_Send, "m_CollisionGroup");
	return group != 1 && group != 2 && group != 3;	// DEBRIS, DEBRIS_TRIGGER, INTERACTIVE_DEBRIS
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
		Handle tr = TR_TraceHullFilterEx(start, end, mins, maxs, MASK_SURVIVOR_MOVE, TraceFilter_World);
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

bool DeepestDrop(int client, const float origin[3], const float vel[3], float &drop)
{
	if( !DropBelow(origin, drop) ) return false;
	float speed = SquareRoot(vel[0] * vel[0] + vel[1] * vel[1]);
	if( speed < 1.0 ) return true;
	float mins[3], maxs[3];
	GetClientMins(client, mins);
	GetClientMaxs(client, maxs);
	for( int k = 1; k <= 5; k++ )
	{
		float t = 0.1 * k, want[3], at[3], d;
		want[0] = origin[0] + vel[0] * t;
		want[1] = origin[1] + vel[1] * t;
		want[2] = origin[2];
		Handle tr = TR_TraceHullFilterEx(origin, want, mins, maxs, MASK_SURVIVOR_MOVE, TraceFilter_World);
		TR_GetEndPosition(at, tr);
		bool wall = TR_DidHit(tr);
		delete tr;
		if( !DropBelow(at, d) ) return false;
		if( d > drop ) drop = d;
		if( wall ) break;
	}
	return true;
}

public Action L4D_OnLedgeGrabbed(int client)
{
	int mode = g_cvMode.IntValue;
	if( mode == 0 || client < 1 || client > MaxClients || !IsClientInGame(client) || GetClientTeam(client) != TEAM_SURVIVOR )
		return Plugin_Continue;

	float origin[3], vel[3], drop;
	GetClientAbsOrigin(client, origin);
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vel);
	// The deepest floor at the survivor and along where their horizontal speed carries them
	// in the next half second (stopping at walls). Any bottomless sample leaves the grab alone.
	if( !DeepestDrop(client, origin, vel, drop) )
		return Plugin_Continue;

	float gravity = g_cvGravity.FloatValue;
	float scale = GetEntPropFloat(client, Prop_Data, "m_flGravity");
	if( scale > 0.0 ) gravity *= scale;
	float landing = SquareRoot(vel[2] * vel[2] + 2.0 * gravity * drop);
	float safe = g_cvSafe != null ? g_cvSafe.FloatValue : 560.0;
	float fatal = g_cvFatal != null ? g_cvFatal.FloatValue : 720.0;
	float damage = 0.0;
	if( landing > safe && fatal > safe )
	{
		float x = (landing - safe) / (fatal - safe);
		damage = x * x * 100.0;
	}
	float minDamage = g_cvMinDamage.FloatValue;
	bool harmless = minDamage > 0.0 ? damage < minDamage : landing <= safe;

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
			float est = g_hEstimate != null ? SDKCall(g_hEstimate, client) : -1.0;
			LogToFileEx(g_sLogPath, "%s %N at %.0f %.0f %.0f drop %.1f vz %.0f vxy %.0f landing %.0f safe %.0f dmg %.1f game_est %.1f -> %s",
				map, client, origin[0], origin[1], origin[2], drop, vel[2], SquareRoot(vel[0] * vel[0] + vel[1] * vel[1]), landing, safe, damage, est,
				!harmless ? "hang" : (mode == 1 ? "BLOCKED" : "would block"));
		}
	}

	return (harmless && mode == 1) ? Plugin_Handled : Plugin_Continue;
}

Action Cmd_Est(int client, int args)
{
	char arg[64];
	GetCmdArg(1, arg, sizeof(arg));
	int target = args > 0 ? FindTarget(client, arg, false, false) : client;
	if( target < 1 ) return Plugin_Handled;
	if( g_hEstimate == null ) { ReplyToCommand(client, "[ledge_fix] EstimateFallingDamage not found in gamedata"); return Plugin_Handled; }
	float vel[3], drop;
	float origin[3];
	GetClientAbsOrigin(target, origin);
	GetEntPropVector(target, Prop_Data, "m_vecAbsVelocity", vel);
	bool found = DeepestDrop(target, origin, vel, drop);
	ReplyToCommand(client, "[ledge_fix] %N: game estimate %.1f, our drop %s%.1f, vz %.0f", target, SDKCall(g_hEstimate, target), found ? "" : "(bottomless) ", found ? drop : 0.0, vel[2]);
	return Plugin_Handled;
}