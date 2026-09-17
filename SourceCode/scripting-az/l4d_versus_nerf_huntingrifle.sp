#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

public Plugin myinfo = 
{
	name = "Nerf Huntingrifle",
	author = "Tester:Xeno, Coder:Timocop, archer, L4D1 Huntingrifle modify by Harry",
	description = "Hunting rifle Beta Reloading Animations",
	version = "1.8-2026/9/17",
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

#define MAXENTITIES                   2048

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

bool g_bIsWeaponEmpty[MAXENTITIES+1],
	g_bIsWeaponHT[MAXENTITIES+1],
	g_bIsWeaponOnEquip[MAXENTITIES+1];


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
	//HookEvent("item_pickup", ePlayerItemPickup);
	//HookEvent("spawner_give_item", Event_Spawner_give_item);

	if(bLate)
	{
		LateLoad();
		for (int client = 1; client <= MaxClients; client++)
		{
			if (!IsClientInGame(client)) continue;

			OnClientPutInServer(client);
		}
	}
}

void LateLoad()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client))
			continue;

		OnClientPutInServer(client);
	}

	int entity;
	char classname[64];

	entity = INVALID_ENT_REFERENCE;
	while ((entity = FindEntityByClassname(entity, "weapon_hunting_rifle*")) != INVALID_ENT_REFERENCE)
	{
		if (!IsValidEntity(entity))
			continue;

		GetEntityClassname(entity, classname, sizeof(classname));
		OnEntityCreated(entity, classname);
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

public void OnClientDisconnect(int client)
{
	if(!IsClientInGame(client)) return;

	delete g_hTimerFireAnimation[client];
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_WeaponEquip, OnWeaponEquip);
	SDKHook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitchPost);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (!IsValidEntityIndex(entity))
		return;

	switch (classname[0])
	{
		case 'w':
		{
			if (StrEqual(classname, "weapon_hunting_rifle"))
			{
				g_bIsWeaponHT[entity] = true;
			}
		}
	}
}

public void OnEntityDestroyed(int entity)
{
	if (!IsValidEntityIndex(entity))
		return;

	g_bIsWeaponHT[entity] = false;
}

void eWeaponFire(Event event, const char[] name, bool dontBroadcast) 
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!IsValidClient(client) 	
			|| !IsPlayerAlive(client) 
			|| GetClientTeam(client) != 2
			|| iConVar_Huntrifle_FireLayer <= 0)
		return;

	int weaponid = event.GetInt("weaponid");
	if(weaponid != 6) return;
	
	int iCurrentWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (iCurrentWeapon <= MaxClients || g_bIsWeaponHT[iCurrentWeapon] == false)
		return;	
		
	if (GetEntProp(iCurrentWeapon, Prop_Data, "m_iClip1") == 1)//最後一發射出去不使用拉勾動畫
	{
		g_bIsWeaponEmpty[iCurrentWeapon] = true;
		return;
	}
	else
	{
		g_bIsWeaponEmpty[iCurrentWeapon] = false;
		g_fNextPrimaryAttack[client] = GetGameTime() + fConVar_Huntrifle_FireCycle; //射速
		SetEntPropFloat(iCurrentWeapon, Prop_Send, "m_flNextPrimaryAttack", g_fNextPrimaryAttack[client]);

		delete g_hTimerFireAnimation[client];
		DataPack hPack;
		g_hTimerFireAnimation[client] = CreateDataTimer(0.1, COLD_DOWN, hPack); //拉勾動畫
		hPack.WriteCell(client);
		hPack.WriteCell(GetClientUserId(client));
		hPack.WriteCell(EntIndexToEntRef(iCurrentWeapon));
	}
}

Action COLD_DOWN(Handle timer, DataPack hPack) //拉勾動畫
{
	hPack.Reset();
	int index = hPack.ReadCell();
	g_hTimerFireAnimation[index] = null;

	int client = GetClientOfUserId(hPack.ReadCell());
	if(!client || !IsClientInGame(client))
		return Plugin_Continue;
	
	if(GetClientTeam(client) != 2 || !IsPlayerAlive(client))
		return Plugin_Continue;

	int weapon = EntRefToEntIndex(hPack.ReadCell());
	if(weapon == INVALID_ENT_REFERENCE)
		return Plugin_Continue;
		
	int iViewModel = GetEntPropEnt(client, Prop_Send, "m_hViewModel");
	if(!IsValidEntity(iViewModel))
		return Plugin_Continue;

	int iActiveWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if(iActiveWeapon <= MaxClients || iActiveWeapon != weapon)
		return Plugin_Continue;
		
	SetEntPropFloat(iActiveWeapon, Prop_Send, "m_flNextPrimaryAttack", g_fNextPrimaryAttack[client]);
	SetEntProp(iViewModel, Prop_Send, "m_nLayerSequence", iConVar_Huntrifle_FireLayer); //16
	SetEntPropFloat(iViewModel, Prop_Send, "m_flLayerStartTime", GetGameTime()); //Some Animation Glich Fixes
	
	return Plugin_Continue;
}

public void L4D_OnSwingStart(int client, int weapon)
{
	delete g_hTimerFireAnimation[client];
}

//從weapon_xxx_spawner撿起不同武器或是相同武器時也會觸發: OnWeaponEquip -> OnWeaponSwitchPost -> "item_pickup" -> "spawner_give_item"
//撿起地上的武器會觸發
//滾輪會觸發
void OnWeaponSwitchPost(int client, int weapon)
{
	if (client <= 0) return;
	if(GetClientTeam(client) != 2) return;
	if(!IsPlayerAlive(client)) return;
	if(weapon <= MaxClients) return;
	if(g_bIsWeaponHT[weapon] == false) return;

	if(g_bIsWeaponOnEquip[weapon]) return;

	//PrintToChatAll("OnWeaponSwitchPost - client: %N, weapon: %d", client, weapon);

	if(iConVar_Huntrifle_SwtichLayer <= 0) return;
	Weapon_ChangeAnimation(client, weapon, iConVar_Huntrifle_SwtichLayer, fConVar_Huntrifle_SwtichTime);
}

//撿起地上的武器會觸發
//滾輪不觸發
Action OnWeaponEquip(int client, int weapon)
{
	if (client <= 0) return Plugin_Continue;
	if(GetClientTeam(client) != 2) return Plugin_Continue;
	if(!IsPlayerAlive(client)) return Plugin_Continue;
	if(weapon <= MaxClients) return Plugin_Continue;
	if(g_bIsWeaponHT[weapon] == false) return Plugin_Continue;

	//PrintToChatAll("OnWeaponEquip - client: %N, weapon: %d", client, weapon);
	g_bIsWeaponOnEquip[weapon] = true;
	RequestFrame(OnNextFrame_OnWeaponEquip, weapon);

	if(iConVar_Huntrifle_PickupLayer <= 0) return Plugin_Continue;
	Weapon_ChangeAnimation(client, weapon, iConVar_Huntrifle_PickupLayer, fConVar_Huntrifle_PickupTime);

	return Plugin_Continue;
}

void eReloadWeapon(Event event, const char[] name, bool dontBroadcast) 
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client) 	
			|| !IsPlayerAlive(client) 
			|| GetClientTeam(client) != 2)
		return;

	int iCurrentWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if(iCurrentWeapon <= 0)
		return;
	
	if (g_bIsWeaponHT[iCurrentWeapon] == false)
		return;

	if(g_bIsWeaponEmpty[iCurrentWeapon])
	{
		if(iConVar_Huntrifle_EReloadLayer <= 0) return;
		Weapon_ChangeAnimation(client, iCurrentWeapon, iConVar_Huntrifle_EReloadLayer, fConVar_Huntrifle_EReloadTime);
	}
	else
	{
		if(iConVar_Huntrifle_ReloadLayer <= 0) return;
		Weapon_ChangeAnimation(client, iCurrentWeapon, iConVar_Huntrifle_ReloadLayer, fConVar_Huntrifle_ReloadTime);
	}
}

/*void ePlayerItemPickup(Event event, const char[] name, bool dontBroadcast) 
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if(!IsValidClient(client) 	
			|| !IsPlayerAlive(client) 
			|| GetClientTeam(client) != 2)
		return;

	PrintToChatAll("item_pickup");
	
	static char sPickupName[64];
	event.GetString("item", sPickupName, sizeof(sPickupName)); 
	if (strcmp(sPickupName, "hunting_rifle", false) != 0)
		return;

	int iCurrentWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if(iCurrentWeapon <= 0)
		return;

	if(iConVar_Huntrifle_PickupLayer <= 0) return;
	Weapon_ChangeAnimation(client, iCurrentWeapon, iConVar_Huntrifle_PickupLayer, fConVar_Huntrifle_PickupTime);
}*/

/*void Event_Spawner_give_item(Event event, const char[] name, bool dontBroadcast) 
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if(!IsValidClient(client) 	
			|| !IsPlayerAlive(client) 
			|| GetClientTeam(client) != 2)
		return;

	PrintToChatAll("spawner_give_item");
}*/

void OnNextFrame_OnWeaponEquip(int weapon)
{
	g_bIsWeaponOnEquip[weapon] = false;
}

void Weapon_ChangeAnimation(int client, int iCurrentWeapon, int iViewModelLayer, float fAttackTime)
{
	int iViewModel = GetEntPropEnt(client, Prop_Send, "m_hViewModel");
	if(iViewModel <= MaxClients) return;

	SetEntProp(iViewModel, Prop_Send, "m_nLayerSequence", iViewModelLayer); 
	SetEntPropFloat(iViewModel, Prop_Send, "m_flLayerStartTime", GetGameTime());

	if(fAttackTime > 0)
	{
		float fGameTime = GetGameTime();
		float fNextPrimaryAttack_New = fGameTime + fAttackTime;
		
		SetEntPropFloat(iCurrentWeapon, Prop_Send, "m_flNextPrimaryAttack", fNextPrimaryAttack_New);
		SetEntPropFloat(iCurrentWeapon, Prop_Send, "m_flTimeWeaponIdle", fNextPrimaryAttack_New);
		SetEntPropFloat(client, Prop_Send, "m_flNextAttack", fNextPrimaryAttack_New);
	}
}

bool IsValidClient(int client)
{
	if(client < 1 || client > MaxClients)
	return false;

	return IsClientInGame(client);
}

bool IsValidEntityIndex(int entity)
{
	return (MaxClients+1 <= entity <= GetMaxEntities());
}