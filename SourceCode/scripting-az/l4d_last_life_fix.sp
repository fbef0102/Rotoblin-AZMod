/*
 * l4d_last_life_fix: a revived survivor with incaps left is incapped, not killed outright,
 * when a hit lands on the one tick where his temporary health is a whole number.
 *
 * Found on match 1230 (2026-11-18, Dead Air 4): VI, revived once (limit 2), standing at
 * 1 health + 2 temp, was hit by a common for 2 and died. No incap, and no
 * "is dying instead of incapping" line in the server log.
 *
 * Cause (Valve's code, both the stock server.so and our rebuild):
 *  - CTerrorPlayer::AllowDamage decides whether a hit is survivable from whole numbers:
 *    health + int(temp) - damage > 0. With 1 health, 2.0 temp and a hit for 2 it says yes
 *    and skips the incap decision.
 *  - CTerrorPlayer::OnTakeDamage_Alive then applies the hit, and takes ONE EXTRA point of
 *    temp health from a survivor marked m_isGoingToDie (set by every revive) who is still
 *    standing. He stays up only if temp - (damage - health) - 1 > 0. With the numbers
 *    above that is 2.0 - 1 - 1 = 0, not above 0, so nothing rescues him and he dies with
 *    health below 1.
 *  - The two only disagree when temp == damage - health + 1 exactly. Just above, he stays
 *    up with a sliver of temp health; just below, AllowDamage sends him to the incap code.
 *  - At 128 tick with pain_pills_decay_rate 0.25, temp health decays 1/512 per tick, so it
 *    is exactly a whole number on one tick in every 512 (4 seconds). Any hit on that tick
 *    whose damage matches kills.
 *
 * Reproduced on a stock server with deploy/tools/lastliferig (temp 2.5: stays up, 1.998:
 * incap, 2.002: stays up, 2.0: dies; same with 0 revives used).
 *
 * Fix: before the game looks at a hit on a standing, going-to-die survivor, if his temp
 * health is within l4d_last_life_fix_window of a whole number, take
 * l4d_last_life_fix_nudge off it. If the hit is the matching one, AllowDamage now sees him
 * out of health and runs the normal incap decision: he goes down if he has incaps left and
 * dies if he has none. That is what the hit really does to him (with the extra point his
 * health and temp health reach exactly 0), and it is what happens one tick later anyway.
 * Owner's call 2026-11-18: reaching 0 should be an incap, not a free stand.
 *
 * Every nudge is logged to logs/last_life_fix.log, so the log counts how often the hole
 * would have opened. Note a nudge is logged for any hit on that tick, whether or not its
 * damage would have matched.
 */
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PLUGIN_VERSION	"1.0"
#define TEAM_SURVIVOR	2

ConVar g_cvEnable, g_cvLog, g_cvWindow, g_cvNudge, g_cvDecay;
char g_sLogPath[PLATFORM_MAX_PATH];

public Plugin myinfo =
{
	name = "l4d_last_life_fix",
	author = "Malevolence",
	description = "A revived survivor with incaps left goes down, not dies, when a hit takes exactly all his temp health",
	version = PLUGIN_VERSION,
	url = ""
};

public void OnPluginStart()
{
	g_cvEnable = CreateConVar("l4d_last_life_fix", "1", "0 = off, 1 = on", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvLog = CreateConVar("l4d_last_life_fix_log", "1", "1 = log every nudge to logs/last_life_fix.log", _, true, 0.0, true, 1.0);
	g_cvWindow = CreateConVar("l4d_last_life_fix_window", "0.0005", "Temp health this close to a whole number counts as on it", _, true, 0.0, true, 0.01);
	g_cvNudge = CreateConVar("l4d_last_life_fix_nudge", "0.002", "Temp health taken off when it sits on a whole number", _, true, 0.001, true, 0.05);
	g_cvDecay = FindConVar("pain_pills_decay_rate");
	BuildPath(Path_SM, g_sLogPath, sizeof g_sLogPath, "logs/last_life_fix.log");

	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i)) OnClientPutInServer(i);
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

// Runs at the top of CTerrorPlayer::OnTakeDamage, before AllowDamage reads the temp health.
Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (!g_cvEnable.BoolValue || damage <= 0.0)
		return Plugin_Continue;
	if (victim < 1 || victim > MaxClients || GetClientTeam(victim) != TEAM_SURVIVOR || !IsPlayerAlive(victim))
		return Plugin_Continue;
	if (!GetEntProp(victim, Prop_Send, "m_isGoingToDie") || GetEntProp(victim, Prop_Send, "m_isIncapacitated")
		|| GetEntProp(victim, Prop_Send, "m_isHangingFromLedge"))
		return Plugin_Continue;

	// Temp health as CTerrorPlayer::GetHealthBuffer reads it: the stored value less its decay.
	float raw = GetEntPropFloat(victim, Prop_Send, "m_healthBuffer");
	float temp = raw - (GetGameTime() - GetEntPropFloat(victim, Prop_Send, "m_healthBufferTime")) * g_cvDecay.FloatValue;
	if (temp < 0.5)
		return Plugin_Continue;
	float off = temp - float(RoundToNearest(temp));
	if (off < 0.0) off = -off;
	if (off > g_cvWindow.FloatValue)
		return Plugin_Continue;

	// Lower the stored value and keep its timestamp, so the decay carries on unchanged.
	SetEntPropFloat(victim, Prop_Send, "m_healthBuffer", raw - g_cvNudge.FloatValue);
	if (g_cvLog.BoolValue)
	{
		char map[64], cls[64] = "?";
		GetCurrentMap(map, sizeof map);
		if (inflictor >= 0 && IsValidEdict(inflictor)) GetEdictClassname(inflictor, cls, sizeof cls);
		LogToFileEx(g_sLogPath, "%s: %L health %d temp %.6f revives %d, hit %.2f type 0x%x by %s: nudged",
			map, victim, GetClientHealth(victim), temp, GetEntProp(victim, Prop_Send, "m_currentReviveCount"), damage, damagetype, cls);
	}
	return Plugin_Continue;
}
