#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <l4d_weapon_stocks>
#include <multicolors>
#include <dhooks>
#include <sourcescramble>


#define FLAGS_SWITCH_PISTOL               1
#define FLAGS_SWITCH_PILLS                2

#define TEAM_SURVIVOR                     2
#define TEAM_INFECTED                     3

#define GAMEDATA_FILE "l4d_pickup"
#define KEY_CTERRORGUN_USE "CTerrorGun_Use"
#define KEY_CTERRORGUN_USE_WINDOWS "CTerrorGun_Use_Windows"
#define KEY_CWEAPONSPAWN_USE "CWeaponSpawn::Use"
#define PATCH_STOPHOLSTER "EquipSecondWeapon_StopHolster"
#define PATCH_SETACTIVEWEAPON "EquipSecondWeapon_SetActiveWeapon"
#define PATCH_DEPLOY "EquipSecondWeapon_Deploy"

bool
	bLateLoad,
	bCantSwitchHealth[MAXPLAYERS + 1],
	bSwitchFlags[MAXPLAYERS + 1];
	
Handle
	hHealth[MAXPLAYERS + 1];

ConVar
	hSwitchFlags;

int
	SwitchFlags;

bool
	g_bLinux;

MemoryPatch
	g_hPatch_StopHolster,
	g_hPatch_SetActiveWeapon,
	g_hPatch_Deploy;

public Plugin myinfo = 
{
	name = "L4D Pick-up Changes",
	author = "Sir, Forgetest, l4d1 port by Harry", //Update syntax A1m`
	description = "Alters a few things regarding picking up/giving items and incapped Players.",
	version = "1.2.3",
	url = "https://github.com/SirPlease/L4D2-Competitive-Rework/"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	
	if( test != Engine_Left4Dead )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1.");
		return APLRes_SilentFailure;
	}
	
	bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadSDK();

	hSwitchFlags = CreateConVar("pickup_switch_flags", "3", "Flags for Switching from current item (1:Pistol, 2: Passed Pills)", _, true, 0.0, true, 3.0);

	SwitchFlags = hSwitchFlags.IntValue;
	
	HookConVarChange(hSwitchFlags, CVarChanged);

	RegConsoleCmd("sm_secondary", ChangeSecondaryFlags);

	if (bLateLoad) {
		for (int i = 1; i <= MaxClients; i++) {
			HookValidClient(i, true);
			bSwitchFlags[i] = true;
		}
	}
}

void LoadSDK()
{
	Handle conf = LoadGameConfigFile(GAMEDATA_FILE);
	if (conf == null)
		SetFailState("Missing gamedata \"" ... GAMEDATA_FILE ..."\"");
	
	int offset = GameConfGetOffset(conf, "OS");
	if (offset == -1)
		SetFailState("Failed to find offset \"OS\"");
	
	g_bLinux = (offset == 1);
	
	SetupDetours(conf);
	
	g_hPatch_StopHolster = MemoryPatch.CreateFromConf(conf, PATCH_STOPHOLSTER);
	if (!g_hPatch_StopHolster || !g_hPatch_StopHolster.Validate())
		SetFailState("Failed to validate memory patch \"" ... PATCH_STOPHOLSTER ... "\"");
	
	g_hPatch_SetActiveWeapon = MemoryPatch.CreateFromConf(conf, PATCH_SETACTIVEWEAPON);
	if (!g_hPatch_SetActiveWeapon || !g_hPatch_SetActiveWeapon.Validate())
		SetFailState("Failed to validate memory patch \"" ... PATCH_SETACTIVEWEAPON ... "\"");
	
	g_hPatch_Deploy = MemoryPatch.CreateFromConf(conf, PATCH_DEPLOY);
	if (!g_hPatch_Deploy || !g_hPatch_Deploy.Validate())
		SetFailState("Failed to validate memory patch \"" ... PATCH_DEPLOY ... "\"");
	
	delete conf;
}

void SetupDetours(Handle conf)
{
	Handle hDetour = DHookCreateFromConf(
							conf,
							(g_bLinux ? KEY_CTERRORGUN_USE : KEY_CTERRORGUN_USE_WINDOWS)
					);
	
	if (!hDetour)
		SetFailState("Failed to create setup detour for \"%s\"", (g_bLinux ? KEY_CTERRORGUN_USE : KEY_CTERRORGUN_USE_WINDOWS));
	
	if (!DHookEnableDetour(hDetour, false, CTerrorGun_OnUse)
		|| !DHookEnableDetour(hDetour, true, CTerrorGun_OnUsePost)
	) {
		SetFailState("Failed to enable detour \"%s\"", (g_bLinux ? KEY_CTERRORGUN_USE : KEY_CTERRORGUN_USE_WINDOWS));
	}
	
	hDetour = DHookCreateFromConf(conf, KEY_CWEAPONSPAWN_USE);
	
	if (!hDetour)
		SetFailState("Failed to create setup detour for \"" ... KEY_CWEAPONSPAWN_USE ... "\"");
	
	if (!DHookEnableDetour(hDetour, false, CWeaponSpawn_OnUse)
		|| !DHookEnableDetour(hDetour, true, CWeaponSpawn_OnUsePost)
	) {
		SetFailState("Failed to enable detour \"" ... KEY_CWEAPONSPAWN_USE ... "\"");
	}
}

void ApplyPatch(bool patch)
{
	static bool patched = false;
	if (patch && !patched)
	{
		if (!g_hPatch_StopHolster.Enable())
			SetFailState("Failed to enable memory patch \"" ... PATCH_STOPHOLSTER ... "\"");
		
		if (!g_hPatch_SetActiveWeapon.Enable())
			SetFailState("Failed to enable memory patch \"" ... PATCH_SETACTIVEWEAPON ... "\"");
		
		if (!g_hPatch_Deploy.Enable())
			SetFailState("Failed to enable memory patch \"" ... PATCH_DEPLOY ... "\"");
		
		patched = true;
	}
	else if (!patch && patched)
	{
		g_hPatch_StopHolster.Disable();
		g_hPatch_SetActiveWeapon.Disable();
		g_hPatch_Deploy.Disable();
		
		patched = false;
	}
}

/* ---------------------------------
//                                 |
//       Standard Client Stuff     |
//                                 |
// -------------------------------*/
public void OnClientPutInServer(int client)
{
	HookValidClient(client, true);
	bSwitchFlags[client] = true;
}

public void OnClientDisconnect_Post(int client)
{
	KillActiveTimers(client);
	HookValidClient(client, false);
}


public Action ChangeSecondaryFlags(int client, int args)
{
	if (IsValidClient(client)) {
		if (bSwitchFlags[client] == false) {
			bSwitchFlags[client] = true;
			CPrintToChat(client, "{blue}[{default}ItemSwitch{blue}] {default}Auto Switch to Pistol/Pills on pick-up/given: {blue}OFF");
		} else {
			bSwitchFlags[client] = false;
			CPrintToChat(client, "{blue}[{default}ItemSwitch{blue}] {default}Auto Switch to Pistol/Pills on pick-up/given: {blue}ON");
		}
	}
	return Plugin_Handled;
}


/* ---------------------------------
//                                 |
//       Yucky Timer Method~       |
//                                 |
// -------------------------------*/

public Action DelaySwitchHealth(Handle hTimer, any client)
{
	bCantSwitchHealth[client] = false;
	hHealth[client] = null;
}

public Action WeaponCanSwitchTo(int client, int weapon)
{
	if (!IsValidEntity(weapon)) {
		return Plugin_Continue;
	}

	char sWeapon[64];
	GetEntityClassname(weapon, sWeapon, sizeof(sWeapon)); 
	L4D2WeaponId wep = L4D2_GetWeaponIdByWeaponName(sWeapon);

	// Health Items.
	if (bSwitchFlags[client] && SwitchFlags & FLAGS_SWITCH_PILLS && wep == L4D2WeaponId_PainPills && bCantSwitchHealth[client]) {
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}

public Action WeaponEquip(int client, int weapon)
{
	if (!IsValidEntity(weapon)) {
		return Plugin_Continue;
	}

	// New Weapon
	char sWeapon[64]; 
	GetEntityClassname(weapon, sWeapon, sizeof(sWeapon)); 
	L4D2WeaponId wep = L4D2_GetWeaponIdByWeaponName(sWeapon);

	// Health Items.
	if (wep == L4D2WeaponId_PainPills) {
		bCantSwitchHealth[client] = true;
		hHealth[client] = CreateTimer(0.1, DelaySwitchHealth, client);
	}

	return Plugin_Continue;
}


/* ---------------------------------
//                                 |
//        Stocks, Functions        |
//                                 |
// -------------------------------*/
bool IsValidClient(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client));
}

void KillActiveTimers(int client)
{
	delete hHealth[client];
	
	hHealth[client] = null;
	bCantSwitchHealth[client] = false;
	bSwitchFlags[client] = false;
}

void HookValidClient(int client, bool Hook)
{
	if (IsValidClient(client)) {
		if (Hook) {
			SDKHook(client, SDKHook_WeaponCanSwitchTo, WeaponCanSwitchTo);
			SDKHook(client, SDKHook_WeaponEquip, WeaponEquip);
		} else {
			SDKUnhook(client, SDKHook_WeaponCanSwitchTo, WeaponCanSwitchTo);
			SDKUnhook(client, SDKHook_WeaponEquip, WeaponEquip);
		}
	}
}

/* ---------------------------------
//                                 |
//          Cvar Changes!          |
//                                 |
// -------------------------------*/
public void CVarChanged(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	SwitchFlags = hSwitchFlags.IntValue;
}

/* ---------------------------------
//                                 |
//       Dualies Workaround        |
//                                 |
// -------------------------------*/
stock bool IsSwitchingToDualCase(int client, int weapon)
{
	if (!IsValidEdict(weapon))
		return false;
	
	static char clsname[64];
	if (!GetEdictClassname(weapon, clsname, sizeof clsname))
		return false;
	
	if (clsname[0] != 'w')
		return false;
	
	if (strncmp(clsname[7], "pistol", 6) != 0)
	{
		return false;
	}
	
	int secondary = GetPlayerWeaponSlot(client, 1);
	if (secondary == -1)
		return false;
	
	if (!GetEdictClassname(secondary, clsname, sizeof clsname))
		return false;
	
	return strcmp(clsname, "weapon_pistol") == 0 && !GetEntProp(secondary, Prop_Send, "m_hasDualWeapons");
}

public MRESReturn CTerrorGun_OnUse(int pThis, Handle hParams)
{
	int client = DHookGetParam(hParams, ( g_bLinux ? 1 : 2));
	
	if (bSwitchFlags[client] && SwitchFlags & FLAGS_SWITCH_PISTOL && IsSwitchingToDualCase(client, pThis))
	{
		ApplyPatch(true);
	}
	
	return MRES_Ignored;
}

public MRESReturn CWeaponSpawn_OnUse(int pThis, Handle hParams)
{
	int client = DHookGetParam(hParams, 1);

	if (bSwitchFlags[client] && SwitchFlags & FLAGS_SWITCH_PISTOL && IsSwitchingToDualCase(client, pThis))
	{
		ApplyPatch(true);
	}
	
	return MRES_Ignored;
}

public MRESReturn CTerrorGun_OnUsePost(Handle hParams)
{
	ApplyPatch(false);
}

public MRESReturn CWeaponSpawn_OnUsePost(Handle hParams)
{
	ApplyPatch(false);
}