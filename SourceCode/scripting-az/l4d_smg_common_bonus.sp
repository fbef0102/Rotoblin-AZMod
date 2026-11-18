// l4d_smg_common_bonus: Uzi bullets do extra damage to common infected only.
//
// Why (owner, 2026-11-16): the Uzi is picked in ~2.5% of survivor rounds and the
// same players clear ~9% fewer commons with it than with the pump, while their SI
// damage is even and their tank damage is ~7% higher (prod match_round_stats,
// matches 150-1203). A flat "Damage" raise (Roto-AZ's 24, reverted 2026-08-25)
// buffed the SI and tank fights too, which is what felt bad. This scales only hits
// on "infected" entities (commons); SI, tanks and witches ("witch" is its own
// classname) are untouched.
//
// Numbers: commons have z_health 50, Normal difficulty body factor 1.0, headshots
// kill outright. The Uzi's damage reaching OnTakeDamage already carries range
// falloff (RangeModifier 0.78 per 500u). At x1.25 the Uzi stays 3 body shots up
// close (25 x falloff < 25 past point blank) and keeps that out to ~815u instead
// of ~370u. x1.4 would be the first value giving 2-shot kills (inside ~230u).
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PLUGIN_VERSION "1.0"
#define TEAM_SURVIVOR 2

public Plugin myinfo =
{
	name = "Uzi common infected bonus",
	author = "Malevolence",
	description = "Uzi bullets do extra damage to common infected only",
	version = PLUGIN_VERSION,
	url = ""
};

ConVar g_cvScale, g_cvDebug;
float g_fScale;
bool g_bDebug;

public void OnPluginStart()
{
	g_cvScale = CreateConVar("l4d_smg_common_bonus", "1.25",
		"Uzi damage multiplier against common infected only (1.0 = stock). SI, tank and witch are never changed.",
		FCVAR_NONE, true, 1.0, true, 3.0);
	g_cvDebug = CreateConVar("l4d_smg_common_bonus_debug", "0",
		"1 = print each scaled Uzi hit on a common (damage before/after, distance) to the server console.",
		FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvScale.AddChangeHook(OnCvarChanged);
	g_cvDebug.AddChangeHook(OnCvarChanged);
	ReadCvars();

	// Late load: hook the commons already alive.
	int ent = -1;
	while ((ent = FindEntityByClassname(ent, "infected")) != -1)
		SDKHook(ent, SDKHook_OnTakeDamage, OnCommonTakeDamage);
}

void OnCvarChanged(ConVar cv, const char[] o, const char[] n) { ReadCvars(); }

void ReadCvars()
{
	g_fScale = g_cvScale.FloatValue;
	g_bDebug = g_cvDebug.BoolValue;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (entity > MaxClients && StrEqual(classname, "infected"))
		SDKHook(entity, SDKHook_OnTakeDamage, OnCommonTakeDamage);
}

Action OnCommonTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (g_fScale == 1.0 || damage <= 0.0 || !(damagetype & DMG_BULLET))
		return Plugin_Continue;
	if (attacker < 1 || attacker > MaxClients || !IsClientInGame(attacker) || GetClientTeam(attacker) != TEAM_SURVIVOR)
		return Plugin_Continue;

	// Bullet damage is dealt from the shooter's active weapon; L4D1 passes no weapon
	// entity to this hook, so read it off the client.
	int weapon = GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon");
	if (weapon <= MaxClients || !IsValidEdict(weapon))
		return Plugin_Continue;
	char cls[32];
	GetEdictClassname(weapon, cls, sizeof(cls));
	if (!StrEqual(cls, "weapon_smg"))
		return Plugin_Continue;

	float before = damage;
	damage *= g_fScale;
	if (g_bDebug)
	{
		float a[3], v[3];
		GetClientEyePosition(attacker, a);
		GetEntPropVector(victim, Prop_Send, "m_vecOrigin", v);
		PrintToServer("[smg_common_bonus] %N -> common %d: %.2f -> %.2f at %.0fu", attacker, victim, before, damage, GetVectorDistance(a, v));
	}
	return Plugin_Changed;
}
