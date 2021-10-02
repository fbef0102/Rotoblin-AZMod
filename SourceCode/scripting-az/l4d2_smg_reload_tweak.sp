#pragma semicolon 1
#pragma newdecls required;

#include <sourcemod>
#include <sdktools>
#include <l4d_weapon_stocks>

#define TEAM_SURVIVOR 2

ConVar hCvarReloadSpeedUzi;

public Plugin myinfo =
{
	name = "L4D2 SMG Reload Speed Tweaker",
	description = "Allows cvar'd control over the reload durations for both types of SMG",
	author = "Visor, A1m`, l4d1 port by HarryPotter",
	version = "1.1.2",
	url = "https://github.com/SirPlease/L4D2-Competitive-Rework/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();

	if( test != Engine_Left4Dead )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1.");
		return APLRes_SilentFailure;
	}

	return APLRes_Success;
}

public void OnPluginStart()
{
	hCvarReloadSpeedUzi = CreateConVar("l4d2_reload_speed_uzi", "0", "Reload duration of Uzi(normal SMG)", FCVAR_CHEAT|FCVAR_NOTIFY, true, 0.0, true, 10.0);

	HookEvent("weapon_reload", OnWeaponReload, EventHookMode_Post);
}

public void OnWeaponReload(Event hEvent, const char[] eName, bool dontBroadcast)
{
	int client = GetClientOfUserId(hEvent.GetInt("userid"));

	if (!client || !IsClientInGame(client) || GetClientTeam(client) != TEAM_SURVIVOR || !IsPlayerAlive(client)) {
		return;
	}
	
	float originalReloadDuration = 0.0, alteredReloadDuration = 0.0;

	int weapon = GetPlayerWeaponSlot(client, 0);
	L4D2WeaponId weaponId = L4D2_GetWeaponId(weapon);

	switch (weaponId) {
		case L4D2WeaponId_Smg: {
			originalReloadDuration = 2.235352;
			alteredReloadDuration = hCvarReloadSpeedUzi.FloatValue;
		}
		default: {
			return;
		}
	}
	
	if (alteredReloadDuration <= 0.0) {
		return;
	}

	float oldNextAttack = GetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", 0);
	float newNextAttack = oldNextAttack - originalReloadDuration + alteredReloadDuration;
	float playbackRate = originalReloadDuration / alteredReloadDuration;
	
	SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", newNextAttack);
	SetEntPropFloat(client, Prop_Send, "m_flNextAttack", newNextAttack);
	SetEntPropFloat(weapon, Prop_Send, "m_flPlaybackRate", playbackRate);
}

public Action OnPlayerRunCmd(int client, int &buttons)
{
	if (!(buttons & IN_ATTACK2)) {
		return Plugin_Continue;
	}
	
	if (!client || !IsClientInGame(client) || GetClientTeam(client) != TEAM_SURVIVOR || !IsPlayerAlive(client)) {
		return Plugin_Continue;
	}
	
	float originalReloadDuration = 0.0, alteredReloadDuration = 0.0;
	
	int weapon = GetPlayerWeaponSlot(client, 0);
	L4D2WeaponId weaponId = L4D2_GetWeaponId(weapon);

	switch (weaponId) {
		case L4D2WeaponId_Smg: {
			originalReloadDuration = 2.235352;
			alteredReloadDuration = hCvarReloadSpeedUzi.FloatValue;
		}
		default: {
			return Plugin_Continue;
		}
	}

	if (alteredReloadDuration <= 0.0) {
		return Plugin_Continue;
	}

	float playbackRate = originalReloadDuration / alteredReloadDuration;
	SetEntPropFloat(weapon, Prop_Send, "m_flPlaybackRate", playbackRate);
	
	return Plugin_Continue;
}