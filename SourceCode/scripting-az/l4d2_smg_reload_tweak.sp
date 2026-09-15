#pragma semicolon 1
#pragma newdecls required;

#include <sourcemod>
#include <sdktools>
#include <l4d_weapon_stocks>
#include <left4dhooks>


public Plugin myinfo =
{
	name = "L4D2 SMG Reload Speed Tweaker",
	description = "Allows cvar'd control over the reload durations for both types of SMG",
	author = "Visor, A1m`, l4d1 port by HarryPotter",
	version = "1.0h-2026/9/15",
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

#define TEAM_SURVIVOR 2
#define L4D1_SMG_ORIGINAL_RELOAD 2.235352

ConVar g_hCvarReloadSpeedUzi;
float g_fCvarReloadSpeedUzi;

int 
	g_iOffsetInReload,
	g_iNextPAttO,
	g_iNextAttO,
	g_iOffsetPlaybackRate;

public void OnPluginStart()
{
	g_iOffsetInReload 				= 	FindSendPropInfo("CBaseCombatWeapon", "m_bInReload");
	g_iNextPAttO					=	FindSendPropInfo("CBaseCombatWeapon","m_flNextPrimaryAttack");
	g_iNextAttO						=	FindSendPropInfo("CTerrorPlayer","m_flNextAttack");
	g_iOffsetPlaybackRate			= 	FindSendPropInfo("CBaseCombatWeapon","m_flPlaybackRate");

	g_hCvarReloadSpeedUzi 			= CreateConVar("l4d2_reload_speed_uzi", 			"0", "Reload duration of Uzi (0=Unchanged)", FCVAR_CHEAT|FCVAR_NOTIFY, true, 0.0, true, 10.0);

	GetCvars();
	g_hCvarReloadSpeedUzi.AddChangeHook(ConVarChanged_Cvars);

	HookEvent("weapon_reload", OnWeaponReload, EventHookMode_Post);
}

// Cvars-------------------------------

void ConVarChanged_Cvars(ConVar hCvar, const char[] sOldVal, const char[] sNewVal)
{
	GetCvars();
}

void GetCvars()
{
	g_fCvarReloadSpeedUzi = g_hCvarReloadSpeedUzi.FloatValue;
}

// Event

void OnWeaponReload(Event hEvent, const char[] eName, bool dontBroadcast)
{
	int userid = hEvent.GetInt("userid");
	int client = GetClientOfUserId(userid);

	if (!client || !IsClientInGame(client) || GetClientTeam(client) != TEAM_SURVIVOR || !IsPlayerAlive(client)) {
		return;
	}
	
	float originalReloadDuration = 0.0, alteredReloadDuration = 0.0;

	int weapon = GetPlayerWeaponSlot(client, 0);
	L4D2WeaponId weaponId = L4D2_GetWeaponId(weapon);

	switch (weaponId) {
		case L4D2WeaponId_Smg: {
			originalReloadDuration = L4D1_SMG_ORIGINAL_RELOAD;
			alteredReloadDuration = g_fCvarReloadSpeedUzi;
		}
		default: {
			return;
		}
	}
	
	if (alteredReloadDuration <= 0.0) {
		return;
	}

	float oldNextAttack = GetEntDataFloat(client, g_iNextAttO);
	float newNextAttack = oldNextAttack - originalReloadDuration + alteredReloadDuration;
	float playbackRate = originalReloadDuration / alteredReloadDuration;
	
	SetEntDataFloat(weapon, g_iNextPAttO, newNextAttack);
	SetEntDataFloat(client, g_iNextAttO, newNextAttack);
	SetEntDataFloat(weapon, g_iOffsetPlaybackRate, playbackRate);

	//CreateTimer(alteredReloadDuration, Timer_MagEnd, client, TIMER_FLAG_NO_MAPCHANGE);
}

/*Action Timer_MagEnd(Handle timer, int client)
{
	int iViewModel = GetEntPropEnt(client, Prop_Send, "m_hViewModel");
	SetEntPropFloat(iViewModel, Prop_Send, "m_flLayerStartTime", GetGameTime()-g_fCvarReloadSpeedHuntingRifle);

	PrintToChatAll("try to fix");

    return Plugin_Continue;
}*/

// API

// Left4dhooks

public void L4D_OnSwingStart(int client, int weapon)
{
	if (GetClientTeam(client) != TEAM_SURVIVOR || !IsPlayerAlive(client))  return;
	if (weapon <= MaxClients || !IsValidEntity(weapon)) return;
	if (GetEntData(weapon, g_iOffsetInReload, 1) == 0) return;

	char classname[64];
	GetEntityClassname(weapon, classname, sizeof(classname));
	L4D2WeaponId weaponId = L4D2_GetWeaponIdByWeaponName(classname);

	float originalReloadDuration = 0.0, alteredReloadDuration = 0.0;
	
	switch (weaponId) {
		case L4D2WeaponId_Smg: {
			originalReloadDuration = L4D1_SMG_ORIGINAL_RELOAD;
			alteredReloadDuration = g_fCvarReloadSpeedUzi;
		}
		default: {
			return;
		}
	}

	if (alteredReloadDuration <= 0.0) {
		return;
	}
	float playbackRate = originalReloadDuration / alteredReloadDuration;
	SetEntDataFloat(weapon, g_iOffsetPlaybackRate, playbackRate, true);

	DataPack hPack = new DataPack();
	hPack.WriteCell(EntIndexToEntRef(weapon));
	hPack.WriteFloat(playbackRate);
	RequestFrame(OnNextFrame, hPack);
}

// ====================================================================================================
// KEYBINDS
// ====================================================================================================
/*public Action OnPlayerRunCmd(int client, int &buttons)
{
	if (!(buttons & IN_ATTACK2)) {
		return Plugin_Continue;
	}
	
	if (!client || !IsClientInGame(client) || GetClientTeam(client) != TEAM_SURVIVOR || !IsPlayerAlive(client)) {
		return Plugin_Continue;
	}
	
	float originalReloadDuration = 0.0, alteredReloadDuration = 0.0;
	
	int weapon = GetPlayerWeaponSlot(client, 0);
	if (weapon <= MaxClients || !IsValidEntity(weapon)) return Plugin_Continue;
	if (GetEntData(weapon, g_iOffsetInReload, 1) == 0) return Plugin_Continue;

	static char classname[64];
	GetEntityClassname(weapon, classname, sizeof(classname));
	L4D2WeaponId weaponId = L4D2_GetWeaponIdByWeaponName(classname);

	switch (weaponId) {
		case L4D2WeaponId_Smg: {
			originalReloadDuration = L4D1_SMG_ORIGINAL_RELOAD;
			alteredReloadDuration = g_fCvarReloadSpeedUzi;
		}
		case L4D2WeaponId_HuntingRifle: {
			originalReloadDuration = L4D1_HT_ORIGINAL_RELOAD;
			alteredReloadDuration = g_fCvarReloadSpeedHuntingRifle;
		}
		default: {
			return Plugin_Continue;
		}
	}

	if (alteredReloadDuration <= 0.0) {
		return Plugin_Continue;
	}

	float playbackRate = originalReloadDuration / alteredReloadDuration;
	SetEntDataFloat(weapon, g_iOffsetPlaybackRate, playbackRate, true);
	
	return Plugin_Continue;
}*/

// Timer & Frame

void OnNextFrame(DataPack hPack)
{
	hPack.Reset();
	int weapon = EntRefToEntIndex(hPack.ReadCell());
	float playbackRate = hPack.ReadFloat();
	delete hPack;

	if(weapon == INVALID_ENT_REFERENCE) return;

	SetEntDataFloat(weapon, g_iOffsetPlaybackRate, playbackRate, true);
}
