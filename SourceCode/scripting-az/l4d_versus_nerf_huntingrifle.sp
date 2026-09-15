#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

bool g_bIsWeaponEmpty[2048];
bool g_bIgnoreWeaponSwitch[MAXPLAYERS+1];


ConVar ConVar_Huntrifle_EReloadLayer = null;
ConVar ConVar_Huntrifle_EReloadTime = null;
ConVar ConVar_Huntrifle_ReloadLayer = null;
ConVar ConVar_Huntrifle_ReloadTime = null;
ConVar ConVar_Huntrifle_PickupLayer = null;
ConVar ConVar_Huntrifle_PickupTime = null;
ConVar ConVar_Huntrifle_SwtichLayer = null;
ConVar ConVar_Huntrifle_FireLayer = null;
ConVar ConVar_Huntrifle_SwtichTime = null;
ConVar ConVar_Huntrifle_FireCycle;

int iConVar_Huntrifle_EReloadLayer;
float fConVar_Huntrifle_EReloadTime;
int iConVar_Huntrifle_ReloadLayer;
float fConVar_Huntrifle_ReloadTime;
int iConVar_Huntrifle_PickupLayer;
float fConVar_Huntrifle_PickupTime;
int iConVar_Huntrifle_SwtichLayer;
float fConVar_Huntrifle_SwtichTime;
int iConVar_Huntrifle_FireLayer;
float fConVar_Huntrifle_FireCycle;

float g_fNextPrimaryAttack[MAXPLAYERS + 1]	=	{0.0};		//next gametime client's sniper is allowed to fire;
Handle g_hTimerFireAnimation[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "Nerf Huntingrifle",
	author = "Tester:Xeno, Coder:Timocop, archer, L4D1 Huntingrifle modify by Harry",
	description = "Hunting rifle Beta Reloading Animations",
	version = "1.7-2026/9/15",
	url = "Harry Potter myself,bitch"
};

bool bLate;
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    EngineVersion test = GetEngineVersion();

    if( test != Engine_Left4Dead )
    {
        strcopy(error, err_max, "Plugin only supports Left 4 Dead 1.");
        return APLRes_SilentFailure;
    }

    bLate = late;
    return APLRes_Success;
}

public void OnPluginStart()
{
	ConVar_Huntrifle_EReloadLayer 	= CreateConVar( "l4dbeta_huntingrifle_empty_reloadlayer", 	"17", 	"[-1 = DISABLED] Empty Reload Layer Sequence",  FCVAR_NOTIFY );
	ConVar_Huntrifle_EReloadTime 	= CreateConVar( "l4dbeta_huntingrifle_empty_reloadtime", 	"2.65", "[-1 = DISABLED] Empty Reload Time",  FCVAR_NOTIFY );
	ConVar_Huntrifle_ReloadLayer 	= CreateConVar( "l4dbeta_huntingrifle_normal_reloadlayer", 	"13", 	"[-1 = DISABLED] Normal Reload Layer Sequence", FCVAR_NOTIFY );
	ConVar_Huntrifle_ReloadTime 	= CreateConVar( "l4dbeta_huntingrifle_normal_reloadtime", 	"1.85", "[-1 = DISABLED] Normal Reload Time", FCVAR_NOTIFY );
	ConVar_Huntrifle_PickupLayer 	= CreateConVar( "l4dbeta_huntingrifle_pickuplayer", 		"-1", 	"[-1 = DISABLED] Pickup Layer Sequence", FCVAR_NOTIFY );
	ConVar_Huntrifle_PickupTime 	= CreateConVar( "l4dbeta_huntingrifle_pickuptime", 			"-1", 	"[-1 = DISABLED] Pickup Time", FCVAR_NOTIFY );
	ConVar_Huntrifle_SwtichLayer 	= CreateConVar( "l4dbeta_huntingrifle_swtichlayer", 		"7", 	"[-1 = DISABLED] Swtich Layer Sequence", FCVAR_NOTIFY );
	ConVar_Huntrifle_SwtichTime 	= CreateConVar( "l4dbeta_huntingrifle_swtichtime", 			"1.8", 	"[-1 = DISABLED] Swtich Time",  FCVAR_NOTIFY );
	ConVar_Huntrifle_FireLayer 		= CreateConVar( "l4dbeta_huntingrifle_firelayer", 			"19", 	"[-1 = DISABLED] Fire Layer Sequence", FCVAR_NOTIFY );
	ConVar_Huntrifle_FireCycle		= CreateConVar( "l4dbeta_huntingrifle_fire_cycle",			"1.2", 	"[-1 = DISABLED] Fire Cycle",  FCVAR_NOTIFY);

	GetCvars();
	ConVar_Huntrifle_EReloadLayer.AddChangeHook(ConVarChanged_Cvars);
	ConVar_Huntrifle_EReloadTime.AddChangeHook(ConVarChanged_Cvars);
	ConVar_Huntrifle_ReloadLayer.AddChangeHook(ConVarChanged_Cvars);
	ConVar_Huntrifle_ReloadTime.AddChangeHook(ConVarChanged_Cvars);
	ConVar_Huntrifle_PickupLayer.AddChangeHook(ConVarChanged_Cvars);
	ConVar_Huntrifle_PickupTime.AddChangeHook(ConVarChanged_Cvars);
	ConVar_Huntrifle_SwtichLayer.AddChangeHook(ConVarChanged_Cvars);
	ConVar_Huntrifle_SwtichTime.AddChangeHook(ConVarChanged_Cvars);
	ConVar_Huntrifle_FireLayer.AddChangeHook(ConVarChanged_Cvars);
	ConVar_Huntrifle_FireCycle.AddChangeHook(ConVarChange_Slow);

	HookEvent("weapon_fire", eWeaponFire, EventHookMode_Pre);
	HookEvent("weapon_reload", eReloadWeapon);
	HookEvent("item_pickup", ePlayerItemPickup);

	if(bLate)
	{
		for (int client = 1; client <= MaxClients; client++)
		{
			if (!IsClientInGame(client)) continue;

			OnClientPutInServer(client);
		}
	}
}

void ConVarChanged_Cvars(ConVar hCvar, const char[] sOldVal, const char[] sNewVal)
{
	GetCvars();
}

void ConVarChange_Slow(ConVar hCvar, const char[] sOldVal, const char[] sNewVal)
{	
	GetCvars();
}

void GetCvars()
{
	iConVar_Huntrifle_EReloadLayer = ConVar_Huntrifle_EReloadLayer.IntValue;
	fConVar_Huntrifle_EReloadTime = ConVar_Huntrifle_EReloadTime.FloatValue;
	iConVar_Huntrifle_ReloadLayer = ConVar_Huntrifle_ReloadLayer.IntValue;
	fConVar_Huntrifle_ReloadTime = ConVar_Huntrifle_ReloadTime.FloatValue;
	iConVar_Huntrifle_PickupLayer = ConVar_Huntrifle_PickupLayer.IntValue;
	fConVar_Huntrifle_PickupTime = ConVar_Huntrifle_PickupTime.FloatValue;
	iConVar_Huntrifle_SwtichLayer = ConVar_Huntrifle_SwtichLayer.IntValue;
	fConVar_Huntrifle_SwtichTime = ConVar_Huntrifle_SwtichTime.FloatValue;
	iConVar_Huntrifle_FireLayer = ConVar_Huntrifle_FireLayer.IntValue;
	fConVar_Huntrifle_FireCycle = ConVar_Huntrifle_FireCycle.FloatValue;
}

/****************************************************************************************************************************
	*****************************************************************************************************************************
	*****************************************************************************************************************************
	WARNING!
		If you're using your own animations, make sure its a LAYER(!!!!!) (ModelViewer > "v_models" and select "_LAYERS" only!) or your animation will mess up!
		Good Luck...
	*****************************************************************************************************************************
	*****************************************************************************************************************************
	*****************************************************************************************************************************/


void eWeaponFire(Event event, const char[] name, bool dontBroadcast) 
{
	int iClient = GetClientOfUserId(event.GetInt("userid"));
	if (!IsValidClient(iClient) 	
			|| !IsPlayerAlive(iClient) 
			|| GetClientTeam(iClient) != 2
			|| iConVar_Huntrifle_FireLayer <= 0)
		return;

	int weaponid = event.GetInt("weaponid");
	if(weaponid != 6) return;
	
	int iCurrentWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (iCurrentWeapon <= MaxClients)
		return;	
		
	if (GetEntProp(iCurrentWeapon, Prop_Data, "m_iClip1") == 1)//最後一發射出去不使用拉勾動畫
	{
		g_bIsWeaponEmpty[iCurrentWeapon] = true;
		return;
	}
	else
	{
		g_bIsWeaponEmpty[iCurrentWeapon] = false;
		g_fNextPrimaryAttack[iClient] = GetGameTime() + fConVar_Huntrifle_FireCycle; //射速
		SetEntPropFloat(iCurrentWeapon, Prop_Send, "m_flNextPrimaryAttack", g_fNextPrimaryAttack[iClient]);

		delete g_hTimerFireAnimation[iClient];
		DataPack hPack;
		g_hTimerFireAnimation[iClient] = CreateDataTimer(0.1, COLD_DOWN, hPack); //拉勾動畫
		hPack.WriteCell(iClient);
		hPack.WriteCell(GetClientUserId(iClient));
		hPack.WriteCell(EntIndexToEntRef(iCurrentWeapon));
	}
}

Action COLD_DOWN(Handle timer, DataPack hPack) //拉勾動畫
{
	hPack.Reset();
	int index = hPack.ReadCell();
	g_hTimerFireAnimation[index] = null;

	int iClient = GetClientOfUserId(hPack.ReadCell());
	if(!iClient || !IsClientInGame(iClient))
		return Plugin_Continue;
	
	if(GetClientTeam(iClient) != 2 || !IsPlayerAlive(iClient))
		return Plugin_Continue;

	int weapon = EntRefToEntIndex(hPack.ReadCell());
	if(weapon == INVALID_ENT_REFERENCE)
		return Plugin_Continue;
		
	int iViewModel = GetEntPropEnt(iClient, Prop_Send, "m_hViewModel");
	if(!IsValidEntity(iViewModel))
		return Plugin_Continue;

	int iActiveWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if(iActiveWeapon <= MaxClients || iActiveWeapon != weapon)
		return Plugin_Continue;
		
	SetEntPropFloat(iActiveWeapon, Prop_Send, "m_flNextPrimaryAttack", g_fNextPrimaryAttack[iClient]);
	SetEntProp(iViewModel, Prop_Send, "m_nLayerSequence", iConVar_Huntrifle_FireLayer); //16
	SetEntPropFloat(iViewModel, Prop_Send, "m_flLayerStartTime", GetGameTime()); //Some Animation Glich Fixes
	
	return Plugin_Continue;
}

public void L4D_OnSwingStart(int client, int weapon)
{
	delete g_hTimerFireAnimation[client];
}

void OnWeaponSwitchPost(int client, int weapon)
{
	if(iConVar_Huntrifle_SwtichLayer <= 0) return;

	if (client <= 0) return;
	if(GetClientTeam(client) != 2) return;
	if(!IsPlayerAlive(client)) return;
	if(weapon <= MaxClients || !IsValidEntity(weapon)) return;

	static char sCurrentWeaponName[32];
	GetEntityClassname(weapon, sCurrentWeaponName, sizeof(sCurrentWeaponName));
	if(strcmp(sCurrentWeaponName, "weapon_hunting_rifle", false) == 0)
	{
		WeaponChangeAnimation(client, weapon);
	}
}

void WeaponChangeAnimation(int iClient, int hActiveWeapon)
{
	if (GetEntProp(hActiveWeapon, Prop_Data, "m_iClip1") > 0)
	{
		int iViewModel = GetEntPropEnt(iClient, Prop_Send, "m_hViewModel");
		if(!IsValidEntity(iViewModel)) return;
	
		SetEntProp(iViewModel, Prop_Send, "m_nLayerSequence", iConVar_Huntrifle_SwtichLayer); 
		SetEntPropFloat(iViewModel, Prop_Send, "m_flLayerStartTime", GetGameTime());

		if(fConVar_Huntrifle_SwtichTime > 0)
		{
			Weapon_Speed(iClient, fConVar_Huntrifle_SwtichTime);
		}
	}
}

void eReloadWeapon(Event event, const char[] name, bool dontBroadcast) 
{
	int iClient = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(iClient) 	
			|| !IsPlayerAlive(iClient) 
			|| GetClientTeam(iClient) != 2)
		return;

	int iCurrentWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	
	if(iCurrentWeapon <= 0)
		return;

	int iViewModel = GetEntPropEnt(iClient, Prop_Send, "m_hViewModel");
	
	if(!IsValidEntity(iViewModel))
		return;
	
	static char sWeaponName[64];
	GetEntityClassname(iCurrentWeapon, sWeaponName, sizeof(sWeaponName));
	if (strcmp(sWeaponName, "weapon_hunting_rifle", false) != 0)
		return;

	if(g_bIsWeaponEmpty[iCurrentWeapon])
	{
		if(iConVar_Huntrifle_EReloadLayer <= 0) return;

		SetEntProp(iViewModel, Prop_Send, "m_nLayerSequence", ConVar_Huntrifle_EReloadLayer.IntValue); //16
		SetEntPropFloat(iViewModel, Prop_Send, "m_flLayerStartTime", GetGameTime()); //Some Animation Glich Fixes
		if(fConVar_Huntrifle_EReloadTime > 0)
		{
			Weapon_Speed(iClient, fConVar_Huntrifle_EReloadTime);
		}
	}
	else
	{
		if(iConVar_Huntrifle_ReloadLayer <= 0) return;
		
		SetEntProp(iViewModel, Prop_Send, "m_nLayerSequence", iConVar_Huntrifle_ReloadLayer);
		SetEntPropFloat(iViewModel, Prop_Send, "m_flLayerStartTime", GetGameTime());

		if(fConVar_Huntrifle_ReloadTime > 0)
		{
			Weapon_Speed(iClient, fConVar_Huntrifle_ReloadTime);
		}
	}
}

void ePlayerItemPickup(Event event, const char[] name, bool dontBroadcast) 
{
	int iClient = GetClientOfUserId(event.GetInt("userid"));
	
	if(!IsValidClient(iClient) 	
			|| !IsPlayerAlive(iClient) 
			/*|| IsFakeClient(iClient)*/
			|| GetClientTeam(iClient) != 2)
		return;
	
	static char sPickupName[64];
	event.GetString("item", sPickupName, sizeof(sPickupName)); 
	if (strcmp(sPickupName, "hunting_rifle", false) != 0)
		return;

	int iViewModel = GetEntPropEnt(iClient, Prop_Send, "m_hViewModel");
	if (!IsValidEntity(iViewModel))
		return;
	
	g_bIgnoreWeaponSwitch[iClient] = true;

	if(iConVar_Huntrifle_PickupLayer <= 0) return;
	
	SetEntProp(iViewModel, Prop_Send, "m_nLayerSequence", iConVar_Huntrifle_PickupLayer);
	SetEntPropFloat(iViewModel, Prop_Send, "m_flLayerStartTime", GetGameTime());

	if(fConVar_Huntrifle_PickupTime > 0)
	{
		Weapon_Speed(iClient, fConVar_Huntrifle_PickupTime);
	}

}

void Weapon_Speed(int iClient, float fValue) //WITHOUT ANIMATION SPEED CHANGE!
{
	if(fValue < 0) return;

	int iCurrentWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	
	if(IsValidEntity(iCurrentWeapon))
	{
		//float fNextPrimaryAttack  = GetEntPropFloat(iCurrentWeapon, Prop_Send, "m_flNextPrimaryAttack");
		float fGameTime = GetGameTime();
		float fNextPrimaryAttack_New = fGameTime + fValue;
		
		SetEntPropFloat(iCurrentWeapon, Prop_Send, "m_flNextPrimaryAttack", fNextPrimaryAttack_New);
		SetEntPropFloat(iCurrentWeapon, Prop_Send, "m_flTimeWeaponIdle", fNextPrimaryAttack_New);
		SetEntPropFloat(iClient, Prop_Send, "m_flNextAttack", fNextPrimaryAttack_New);
	}
}

bool IsValidClient(int iClient)
{
	if(iClient < 1 || iClient > MaxClients)
	return false;

	return IsClientInGame(iClient);
}

public void OnClientDisconnect(int client)
{
	if(!IsClientInGame(client)) return;

	ResetClientSniperData(client);
}

public void OnClientPutInServer(int client)
{
	ResetClientSniperData(client);

	SDKHook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitchPost);
}

void ResetClientSniperData(int client)
{
	g_fNextPrimaryAttack[client] = 0.0;
}