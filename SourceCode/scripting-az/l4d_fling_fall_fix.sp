/*
 * l4d_fling_fall_fix: no fatal "falls" from a few units after a tank punch.
 *
 * Fall damage only looks at how fast the survivor is moving down when they
 * land: ((speed - fall_speed_safe) / (fall_speed_fatal - fall_speed_safe))^2
 * * 100, and past survivor_incap_max_fall_damage (200) the survivor dies
 * instead of being incapped ("is dying instead of incapping because they fell
 * too far"). A punched survivor flies sideways at about 1200 u/s. When the
 * fling clips an overhang or a sloped edge, the movement code redirects that
 * speed along the surface, and part of it becomes downward speed in a single
 * tick (farm03 bridge: -510 to -727 u/s, smalltown02 ditch: -88 to -856 u/s).
 * The landing then counts as a fall of 400+ units and kills a survivor who
 * dropped 130.
 *
 * This plugin follows each airborne survivor's vertical speed tick by tick,
 * but never lets it grow faster than gravity allows: the tracked value is the
 * slower of the real speed and last tick's tracked speed plus one tick of
 * gravity. On a fall damage hit it turns the game's damage back into a
 * landing speed, and when that is more than l4d_fling_fall_fix_margin above
 * the gravity-only speed, the damage is recomputed from the gravity-only
 * speed. Ordinary falls (gravity is the only thing speeding them up) never
 * change.
 */
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PLUGIN_VERSION	"1.1"
#define TEAM_SURVIVOR	2

ConVar g_cvMode, g_cvLog, g_cvMargin, g_cvSafe, g_cvFatal, g_cvGravity;
bool g_bAir[MAXPLAYERS + 1];
float g_fVz[MAXPLAYERS + 1];		// gravity-consistent vertical speed, u/s (negative = down)
float g_fTop[MAXPLAYERS + 1];		// highest z of this airborne stretch, for the log
char g_sLogPath[PLATFORM_MAX_PATH];

public Plugin myinfo =
{
	name = "l4d_fling_fall_fix",
	author = "Riverside",
	description = "Fall damage from the speed gravity could give, not from flings redirected into the ground",
	version = PLUGIN_VERSION,
	url = "https://github.com/Volence/riverside-l4d-plugins"
};

public void OnPluginStart()
{
	g_cvMode = CreateConVar("l4d_fling_fall_fix_enable", "1", "0 = off, 1 = fix fall damage, 2 = log only (never change damage)", FCVAR_NOTIFY, true, 0.0, true, 2.0);
	g_cvLog = CreateConVar("l4d_fling_fall_fix_log", "1", "1 = write every judged fall to logs/fling_fall_fix.log", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvMargin = CreateConVar("l4d_fling_fall_fix_margin", "50", "Landing speed (u/s) allowed above the gravity-only speed before the damage is recomputed", FCVAR_NONE, true, 0.0);
	CreateConVar("l4d_fling_fall_fix_version", PLUGIN_VERSION, "l4d_fling_fall_fix version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	g_cvSafe = FindConVar("fall_speed_safe");
	g_cvFatal = FindConVar("fall_speed_fatal");
	g_cvGravity = FindConVar("sv_gravity");
	BuildPath(Path_SM, g_sLogPath, sizeof(g_sLogPath), "logs/fling_fall_fix.log");

	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i)) OnClientPutInServer(i);
}

public void OnClientPutInServer(int client)
{
	g_bAir[client] = false;
	SDKHook(client, SDKHook_PostThinkPost, OnPostThinkPost);
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

float Gravity(int client)
{
	float scale = GetEntPropFloat(client, Prop_Data, "m_flGravity");
	return g_cvGravity.FloatValue * (scale > 0.0 ? scale : 1.0);
}

// Runs after the tick's movement. Anything but free flight (ground, ladder,
// noclip, water, incap, ledge hang) ends the airborne stretch. So does a
// smoker's tongue or a hunter's pounce: a tongue can pull a survivor down
// faster than gravity, and that speed is real, so the stretch starts over
// from the survivor's actual speed once they are released.
public void OnPostThinkPost(int client)
{
	if (!IsPlayerAlive(client) || GetClientTeam(client) != TEAM_SURVIVOR
		|| GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") != -1
		|| GetEntityMoveType(client) != MOVETYPE_WALK
		|| GetEntProp(client, Prop_Send, "m_nWaterLevel") > 1
		|| GetEntProp(client, Prop_Send, "m_isIncapacitated")
		|| GetEntProp(client, Prop_Send, "m_isHangingFromLedge")
		|| GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0
		|| GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0)
	{
		g_bAir[client] = false;
		return;
	}

	float vel[3], pos[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel);
	GetClientAbsOrigin(client, pos);
	if (!g_bAir[client])
	{
		g_bAir[client] = true;
		g_fVz[client] = vel[2];
		g_fTop[client] = pos[2];
		return;
	}
	float gravityOnly = g_fVz[client] - Gravity(client) * GetTickInterval();
	g_fVz[client] = vel[2] > gravityOnly ? vel[2] : gravityOnly;
	if (pos[2] > g_fTop[client]) g_fTop[client] = pos[2];
}

float DamageForSpeed(float speed)
{
	float safe = g_cvSafe.FloatValue, fatal = g_cvFatal.FloatValue;
	if (speed <= safe || fatal <= safe) return 0.0;
	float x = (speed - safe) / (fatal - safe);
	return x * x * 100.0;
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	int mode = g_cvMode.IntValue;
	if (mode == 0 || !(damagetype & DMG_FALL) || !g_bAir[victim] || damage <= 0.0
		|| GetClientTeam(victim) != TEAM_SURVIVOR)
		return Plugin_Continue;

	// The landing happens inside this tick's movement, before PostThink, so the
	// tracked speed is last tick's: add the one tick of gravity it is missing.
	float safe = g_cvSafe.FloatValue, fatal = g_cvFatal.FloatValue;
	float gameSpeed = safe + (fatal - safe) * SquareRoot(damage / 100.0);
	float gravitySpeed = -(g_fVz[victim] - Gravity(victim) * GetTickInterval());
	if (gameSpeed <= gravitySpeed + g_cvMargin.FloatValue)
		return Plugin_Continue;

	float fixed = DamageForSpeed(gravitySpeed);
	if (g_cvLog.BoolValue)
	{
		float pos[3];
		GetClientAbsOrigin(victim, pos);
		char map[64];
		GetCurrentMap(map, sizeof(map));
		LogToFileEx(g_sLogPath, "%s %N hp %d+%.0f fell %.0f: game %.0f u/s = %.1f dmg, gravity %.0f u/s = %.1f dmg%s at %.0f %.0f %.0f",
			map, victim, GetClientHealth(victim), GetEntPropFloat(victim, Prop_Send, "m_healthBuffer"),
			g_fTop[victim] - pos[2], gameSpeed, damage, gravitySpeed, fixed,
			mode == 2 ? " (log only)" : "", pos[0], pos[1], pos[2]);
	}
	if (mode == 2)
		return Plugin_Continue;
	if (fixed <= 0.0)
		return Plugin_Handled;
	damage = fixed;
	return Plugin_Changed;
}
