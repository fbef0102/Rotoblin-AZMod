#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#pragma semicolon 1

new bool:g_bIsWeaponEmpty[2048];
new bool:g_bIgnoreWeaponSwitch[MAXPLAYERS+1];


new Handle:ConVar_Huntrifle_EReloadLayer = INVALID_HANDLE;
new Handle:ConVar_Huntrifle_EReloadTime = INVALID_HANDLE;
new Handle:ConVar_Huntrifle_ReloadLayer = INVALID_HANDLE;
new Handle:ConVar_Huntrifle_ReloadTime = INVALID_HANDLE;
new Handle:ConVar_Huntrifle_PickupLayer = INVALID_HANDLE;
new Handle:ConVar_Huntrifle_SwtichLayer = INVALID_HANDLE;
new Handle:ConVar_Huntrifle_FireLayer = INVALID_HANDLE;
new Handle:ConVar_Huntrifle_SwtichTime = INVALID_HANDLE;
new Handle:hRateOfFireCvar;
static			Float:  g_fNextPrimaryAttack[MAXPLAYERS + 1]	=	{0.0};		//next gametime client's sniper is allowed to fire;
static			Float:	g_fFireSpeed							= 	0.27;		//min low input values are 0.05 - 1.5 if you prefer stock speed * modifier, 
static			bool:	g_bIsSniperActive[MAXPLAYERS + 1]		= 	{true};	//is client holding a sniper atm
static			bool:	g_bFiredSniper[MAXPLAYERS + 1]			=	{false};	//did client just fire his sniper
static			bool:	g_Animation[MAXPLAYERS + 1]				=	{true};
public Plugin:myinfo = 
{
	name = "Nerf Huntingrifle",
	author = "Tester:Xeno, Coder:Timocop, archer, L4D1 Huntingrifle modify by Harry",
	description = "Beta Reloading Animations",
	version = "1.4",
	url = "Harry Potter myself,bitch"
};

public OnPluginStart()
{
	ConVar_Huntrifle_EReloadLayer = CreateConVar( "l4dbeta_huntingrifle_empty_reloadlayer", "15", "[-1 = DISABLED] <The Empty Reload Layer Sequence>",  FCVAR_NOTIFY );
	ConVar_Huntrifle_EReloadTime = CreateConVar( "l4dbeta_huntingrifle_empty_reloadtime", "1.2", "[1.0 = DISABLED] <Time to Block the Empty Reload Sequence>",  FCVAR_NOTIFY );
	ConVar_Huntrifle_ReloadLayer = CreateConVar( "l4dbeta_huntingrifle_normal_reloadlayer", "-1", "[-1 = DISABLED | 7 = OTHER] <The Normal Reload Layer Sequence>", FCVAR_NOTIFY );
	ConVar_Huntrifle_ReloadTime = CreateConVar( "l4dbeta_huntingrifle_normal_reloadtime", "0.9", "[1.0 = DISABLED] <Time to Block the Normal Reload Sequence>", FCVAR_NOTIFY );
	ConVar_Huntrifle_PickupLayer = CreateConVar( "l4dbeta_huntingrifle_pickuplayer", "-1", "[-1 = DISABLED] <The Pickup Layer Sequence>", FCVAR_NOTIFY );
	ConVar_Huntrifle_SwtichLayer = CreateConVar( "l4dbeta_huntingrifle_swtichlayer", "7", "[-1 = DISABLED] <The Swtich Layer Sequence>", FCVAR_NOTIFY );
	ConVar_Huntrifle_SwtichTime = CreateConVar( "l4dbeta_huntingrifle_swtichtime", "1.8", "[-1 = DISABLED] <Time to Block the Swtich Layer Sequence>",  FCVAR_NOTIFY );
	ConVar_Huntrifle_FireLayer = CreateConVar( "l4d_huntingrifle_firelayer", "19", "[-1 = DISABLED | 7 = OTHER] <The Fire Layer Sequence>", FCVAR_NOTIFY );
	
	hRateOfFireCvar	= CreateConVar("l4d_huntingrifle_firespeedtime", "0.19", "In percentage, rate of fire (min 0.05; max 1.50).",  FCVAR_NOTIFY);
	HookConVarChange(hRateOfFireCvar, ConVarChange_Slow);
	HookEvent("weapon_fire", eWeaponFire);
	HookEvent("weapon_reload", eReloadWeapon);
	HookEvent("spawner_give_item", ePlayerUse);
	HookEvent("item_pickup", ePlayerUse);
	
	for (new client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client)) continue;
		SDKHook(client, SDKHook_WeaponEquip, OnWeaponEquip);
		SDKHook(client, SDKHook_WeaponSwitch, OnWeaponSwitch);
	}
	
	SetFireSpeed();
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


public Action:eWeaponFire(Handle:event, const String:name[], bool:dontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!IsValidClient(iClient) 	
			|| !IsPlayerAlive(iClient) 
			/*|| IsFakeClient(iClient)*/
			|| GetClientTeam(iClient) != 2||!g_bIsSniperActive[iClient])
	return Plugin_Continue;
	
	ChangeWeaponSize(iClient, 1);
	
	new iCurrentWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if(!IsValidEntity(iCurrentWeapon))
		return Plugin_Continue;	
	
	decl String:sWeaponName[32];
	GetClientWeapon(iClient, sWeaponName, sizeof(sWeaponName));
	if (StrContains(sWeaponName, "hunting_rifle", false) == -1)
		return Plugin_Continue;
		
	if(GetEntProp(GetPlayerWeaponSlot(iClient, 0), Prop_Data, "m_iClip1") == 1)//最後一發射出去不使用拉勾動畫
		return Plugin_Continue;
	else
	{
		g_fNextPrimaryAttack[iClient] = FloatAdd(GetGameTime(), Float:g_fFireSpeed);//射速
		g_bFiredSniper[iClient] = true;
		g_Animation[iClient] = true;
		CreateTimer(0.1,COLD_DOWN,iClient);//拉勾動畫
	}
	return Plugin_Continue;
}
public Action:COLD_DOWN(Handle:timer,any:iClient)//拉勾動畫
{
	if(!g_Animation[iClient]||!IsValidClient(iClient))
		return;
		
	new iViewModel = GetEntPropEnt(iClient, Prop_Send, "m_hViewModel");
	if(!IsValidEntity(iViewModel))
		return; 
		
	SetEntProp(iViewModel, Prop_Send, "m_nLayerSequence", GetConVarInt(ConVar_Huntrifle_FireLayer)); //16
	SetEntPropFloat(iViewModel, Prop_Send, "m_flLayerStartTime", GetGameTime()); //Some Animation Glich Fixes
	ChangeEdictState(iViewModel, FindDataMapOffs(iViewModel, "m_nLayerSequence"));
	//Weapon_Speed(iClient, GetConVarFloat(ConVar_Huntrifle_EReloadTime));
	
	return;
}
bool:ChangeWeaponSize(iClient, iClip)
{
	new iCurrentWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	
	if(!IsValidEntity(iCurrentWeapon))
	return false;

	g_bIsWeaponEmpty[iCurrentWeapon] = (GetEntProp(iCurrentWeapon, Prop_Data, "m_iClip1") <= iClip);
	
	return true;
}

public Action:OnPlayerRunCmd(iClient, &iButtons, &iImpulse, Float:fVelocity[3], Float:fAngles[3], &iWeapon)
{ 
	if(!IsClientInGame(iClient)) return Plugin_Continue;
	if(GetClientTeam(iClient) != 2) return Plugin_Continue;
	//if(IsFakeClient(iClient)) return Plugin_Continue;
	if(!IsPlayerAlive(iClient)) return Plugin_Continue;
	
	static OLD_WEAPON[MAXPLAYERS+1];
	static NEW_WEAPON[MAXPLAYERS+1];

	NEW_WEAPON[iClient] = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if(NEW_WEAPON[iClient] != OLD_WEAPON[iClient])
	{
		if(!g_bIgnoreWeaponSwitch[iClient])
		WeaponChangeAnimation(iClient);
		else
		g_bIgnoreWeaponSwitch[iClient] = false;
		
		ChangeWeaponSize(iClient, 0);
	}
	OLD_WEAPON[iClient] = NEW_WEAPON[iClient];
	
	decl String:sWeaponName[64];
	GetClientWeapon(iClient, sWeaponName, sizeof(sWeaponName));
	if (StrContains(sWeaponName, "hunting_rifle", false) == -1)
		return Plugin_Continue;
		
	if (g_bIsSniperActive[iClient] && g_bFiredSniper[iClient] && iButtons & IN_ATTACK)	//If player is holding sniper, and he just fired a shot, and he uses +attack
	{
		new sniper = GetPlayerWeaponSlot(iClient, 0);
		SetEntPropFloat(sniper, Prop_Send, "m_flNextPrimaryAttack", g_fNextPrimaryAttack[iClient]);
		g_bFiredSniper[iClient] = false;
	}
	else if(g_Animation[iClient] && iButtons & IN_ATTACK2)//拉槍動畫前右鍵推
	{
		//PrintToChatAll("This is IN_ATTACK2 event");
		g_Animation[iClient] = false;
	}
	return Plugin_Continue;
}

stock bool:WeaponChangeAnimation(iClient)
{
	new iWeaponNum = 0;
	if (GetPlayerWeaponSlot(iClient, 0) > 0 && GetEntProp(GetPlayerWeaponSlot(iClient, 0), Prop_Data, "m_iClip1") > 0) iWeaponNum +=1;
	if (GetPlayerWeaponSlot(iClient, 1) > 0) iWeaponNum += 1;
	if (GetPlayerWeaponSlot(iClient, 2) > 0) iWeaponNum += 1;
	if (GetPlayerWeaponSlot(iClient, 3) > 0) iWeaponNum += 1;
	if (GetPlayerWeaponSlot(iClient, 4) > 0) iWeaponNum += 1;
	
	new iViewModel = GetEntPropEnt(iClient, Prop_Send, "m_hViewModel");
	
	if(!IsValidEntity(iViewModel))
	return false;
	
	new iCurrentWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	
	if(!IsValidEntity(iCurrentWeapon))
	return false;

	if(iWeaponNum > 1)
	{
		decl String:sWeaponName[64];
		GetClientWeapon(iClient, sWeaponName, sizeof(sWeaponName));

		if (StrContains(sWeaponName, "hunting_rifle", false) != -1)
		{
			if(GetConVarInt(ConVar_Huntrifle_SwtichLayer) == -1)
			return false;
			if(GetEntProp(GetPlayerWeaponSlot(iClient, 0), Prop_Data, "m_iClip1") == 0)//沒有子彈不使用拉勾動畫
				return false;
				
			SetEntProp(iViewModel, Prop_Send, "m_nLayerSequence", GetConVarInt(ConVar_Huntrifle_SwtichLayer)); 
			SetEntPropFloat(iViewModel, Prop_Send, "m_flLayerStartTime", GetGameTime());
			ChangeEdictState(iViewModel, FindDataMapOffs(iViewModel, "m_nLayerSequence"));
			Weapon_Speed(iClient, GetConVarFloat(ConVar_Huntrifle_SwtichTime));
		}
	}
	return true;
}



public Action:eReloadWeapon(Handle:event, const String:name[], bool:dontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!IsValidClient(iClient) 	
			|| !IsPlayerAlive(iClient) 
			/*|| IsFakeClient(iClient)*/
			|| GetClientTeam(iClient) != 2)
	return Plugin_Continue;

	new iCurrentWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	
	if(!IsValidEntity(iCurrentWeapon))
	return Plugin_Continue;

	new iViewModel = GetEntPropEnt(iClient, Prop_Send, "m_hViewModel");
	
	if(!IsValidEntity(iViewModel))
	return Plugin_Continue;
	
	decl String:sWeaponName[32];
	GetClientWeapon(iClient, sWeaponName, sizeof(sWeaponName));

	if (StrContains(sWeaponName, "hunting_rifle", false) != -1)
	{
		if(g_bIsWeaponEmpty[iCurrentWeapon] && GetConVarInt(ConVar_Huntrifle_EReloadLayer) > -1)
		{
			SetEntProp(iViewModel, Prop_Send, "m_nLayerSequence", GetConVarInt(ConVar_Huntrifle_EReloadLayer)); //16
			SetEntPropFloat(iViewModel, Prop_Send, "m_flLayerStartTime", GetGameTime()); //Some Animation Glich Fixes
			ChangeEdictState(iViewModel, FindDataMapOffs(iViewModel, "m_nLayerSequence"));
			Weapon_Speed(iClient, GetConVarFloat(ConVar_Huntrifle_EReloadTime));
		}
		else if(GetConVarInt(ConVar_Huntrifle_ReloadLayer) > -1)
		{
			SetEntProp(iViewModel, Prop_Send, "m_nLayerSequence", GetConVarInt(ConVar_Huntrifle_ReloadLayer));
			SetEntPropFloat(iViewModel, Prop_Send, "m_flLayerStartTime", GetGameTime());
			ChangeEdictState(iViewModel, FindDataMapOffs(iViewModel, "m_nLayerSequence"));
			Weapon_Speed(iClient, GetConVarFloat(ConVar_Huntrifle_ReloadTime));
		}
	}
	return Plugin_Continue;
}
public Action:ePlayerUse(Handle:event, const String:name[], bool:dontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(!IsValidClient(iClient) 	
			|| !IsPlayerAlive(iClient) 
			/*|| IsFakeClient(iClient)*/
			|| GetClientTeam(iClient) != 2)
	return Plugin_Continue;
	
	decl String:sPickupName[64];
	GetEventString(event, "item", sPickupName, sizeof(sPickupName)); 
	
	g_bIgnoreWeaponSwitch[iClient] = true;

	new iCurrentWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	
	if(!IsValidEntity(iCurrentWeapon))
	return Plugin_Continue;
	
	new iViewModel = GetEntPropEnt(iClient, Prop_Send, "m_hViewModel");
	
	if(!IsValidEntity(iViewModel))
	return Plugin_Continue;
	
	
	decl String:sWeaponName[32];
	GetClientWeapon(iClient, sWeaponName, sizeof(sWeaponName));
	
	if(!StrEqual(sPickupName, sWeaponName, false))
	return Plugin_Continue;
	
	if (StrContains(sPickupName, "hunting_rifle", false) != -1)
	{
		if(GetConVarInt(ConVar_Huntrifle_PickupLayer) < 0)
		return Plugin_Continue;
		
		SetEntProp(iViewModel, Prop_Send, "m_nLayerSequence", GetConVarInt(ConVar_Huntrifle_PickupLayer));
		ChangeEdictState(iViewModel, FindDataMapOffs(iViewModel, "m_nLayerSequence"));
	}
	return Plugin_Continue;
}

stock Weapon_Speed(iClient, Float:fValue) //WITHOUT ANIMATION SPEED CHANGE!
{
	new iCurrentWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	
	if(IsValidEntity(iCurrentWeapon))
	{
		new Float:fNextPrimaryAttack  = GetEntPropFloat(iCurrentWeapon, Prop_Send, "m_flNextPrimaryAttack");
		new Float:fGameTime = GetGameTime();
		new Float:fNextPrimaryAttack_Mod = (fNextPrimaryAttack - fGameTime ) * fValue;

		fNextPrimaryAttack_Mod += fGameTime;
		
		SetEntPropFloat(iCurrentWeapon, Prop_Send, "m_flNextPrimaryAttack", fNextPrimaryAttack_Mod);
		SetEntPropFloat(iCurrentWeapon, Prop_Send, "m_flTimeWeaponIdle", fNextPrimaryAttack_Mod);
		SetEntPropFloat(iClient, Prop_Send, "m_flNextAttack", fNextPrimaryAttack_Mod);
	}
}

stock bool:IsValidClient(iClient)
{
	if(iClient < 1 || iClient > MaxClients)
	return false;

	return IsClientInGame(iClient);
}
public ConVarChange_Slow(Handle:convar, const String:oldValue[], const String:newValue[])
{	
	SetFireSpeed();
}
static SetFireSpeed()
{
	new Float:fPercentage = GetConVarFloat(hRateOfFireCvar);
	if (FloatAbs(fPercentage) <= 1.5)
	{
		fPercentage = FloatMul(fPercentage, 100.0);
	}
	if (fPercentage < 5.0) fPercentage = 5.0;
	if (fPercentage > 150.0) fPercentage = 150.0;
	fPercentage = FloatDiv(100.0, fPercentage);
	g_fFireSpeed = FloatMul(0.25, fPercentage);	
}

public Action:OnWeaponSwitch(client, weapon)
{
	if (weapon < 1 ||
		weapon > 2048 ||
		!IsValidEntity(weapon))
		return Plugin_Continue;
	
	decl String:classname[32];
	GetEdictClassname(weapon, classname, 32);
	if (StrEqual(classname, "weapon_hunting_rifle"))
	{
		g_bIsSniperActive[client] = true;
	}
	else
	{
		g_bIsSniperActive[client] = false;
	}
	return Plugin_Continue;
}

public Action:OnWeaponEquip(client, weapon)
{
	if (GetClientTeam(client) != 2) return Plugin_Continue;

	decl String:classname[128];
	GetEdictClassname(weapon, classname, sizeof(classname));
	if (!StrEqual(classname, "weapon_hunting_rifle")) return Plugin_Continue;
	
	g_bIsSniperActive[client] = true;	//client is carrying sniper now (OnWeaponSwitch actually takes care of this)
	
	return Plugin_Continue;
}

public OnClientDisconnect_Post(client)
{
	SDKUnhook(client, SDKHook_WeaponEquip, OnWeaponEquip);
	SDKUnhook(client, SDKHook_WeaponSwitch, OnWeaponSwitch);
	ResetClientSniperData(client);
}

public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_WeaponEquip, OnWeaponEquip);
	SDKHook(client, SDKHook_WeaponSwitch, OnWeaponSwitch);
	ResetClientSniperData(client);
}
static ResetClientSniperData(client)
{
	g_bFiredSniper[client] = false;
	g_Animation[client] = true;
	g_fNextPrimaryAttack[client] = 0.0;
}