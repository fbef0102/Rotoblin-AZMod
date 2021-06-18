#pragma semicolon 1
#include <sourcemod.inc>
#include <sdktools.inc>
#include <sdkhooks.inc>

#define DEBUG 0

//cvars
new Handle:hEnabledCvar;
new Handle:hClipSizeCvar;
new Handle:hAmmoCountCvar;
new Handle:hRateOfFireCvar;

//bools
static 			bool:	bEnabled 								= 	false;
static			bool:	g_bIsSniperActive[MAXPLAYERS + 1]		= 	{false};	//is client holding a sniper atm
static			bool:	g_bFiredSniper[MAXPLAYERS + 1]			=	{false};	//did client just fire his sniper

//integers
static			g_iClipSize										=	10;
static			g_iAmmoCount									=	90;

//floats
static			Float:  g_fNextPrimaryAttack[MAXPLAYERS + 1]	=	{0.0};		//next gametime client's sniper is allowed to fire;
static			Float:	g_fFireSpeed							= 	0.27;		//min low input values are 0.05 - 1.5 if you prefer stock speed * modifier, otherwise
																				//min high input values are 5.0 - 150.0 if you prefer to set percentage of stock speed
																				
public Plugin:myinfo = 
{
	name = "HuntingRifle",
	author = "archer",
	description = "Nerfs the hunting rifle (less ammo, smaller clip size)",
	version = "1.1"
};


public OnPluginStart()
{
	hEnabledCvar	= CreateConVar("huntingrifle", "0", "Enabled = 1, Disabled = 0.", FCVAR_PLUGIN | FCVAR_NOTIFY);
	hClipSizeCvar	= CreateConVar("huntingrifle_clip", "10", "Number of bullets per clip.", FCVAR_PLUGIN | FCVAR_NOTIFY);
	hAmmoCountCvar	= CreateConVar("huntingrifle_ammo", "90", "Number of bullets in the ammo pool.", FCVAR_PLUGIN | FCVAR_NOTIFY);
	hRateOfFireCvar	= CreateConVar("huntingrifle_speed", "1.0", "In percentage, rate of fire (min 0.05; max 1.50).", FCVAR_PLUGIN | FCVAR_NOTIFY);
	
	HookConVarChange(hClipSizeCvar, ConVarChange_ClipSize);
	HookConVarChange(hEnabledCvar, ConVarChange_Enabled);
	HookConVarChange(hAmmoCountCvar, ConVarChange_AmmoCount);
	HookConVarChange(hRateOfFireCvar, ConVarChange_Slow);
	
	#if DEBUG
	RegConsoleCmd("sm_sniper", Debug, "debug.");
	#endif
	HookEvent("weapon_fire", OnWeaponFire_Event, EventHookMode_Post);
	HookEvent("weapon_reload", OnWeaponReload_Event, EventHookMode_Post);
	
	for (new client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client)) continue;
		SDKHook(client, SDKHook_WeaponEquip, OnWeaponEquip);
		SDKHook(client, SDKHook_WeaponSwitch, OnWeaponSwitch);
	}
	
	CheckEnabled();
}

#if DEBUG
public Action:Debug(client, args)
{
	new sniper = GetPlayerWeaponSlot(client, 0);
	new Float:fVal;
	new iVal;
	fVal = GetEntPropFloat(sniper, Prop_Send, "m_flCycle");		
	PrintToChatAll("m_flCycle: %f", fVal);
	iVal = GetEntProp(sniper, Prop_Send, "m_nNextThinkTick");
	PrintToChatAll("m_nNextThinkTick: %i", iVal);
	fVal = GetEntPropFloat(sniper, Prop_Send, "m_flTimeWeaponIdle");
	PrintToChatAll("m_flTimeWeaponIdle: %f", fVal);
	iVal = GetEntProp(sniper, Prop_Send, "m_nQueuedAttack");
	PrintToChatAll("m_nQueuedAttack: %i", iVal);
	fVal = GetEntPropFloat(sniper, Prop_Send, "m_flTimeAttackQueued");
	PrintToChatAll("m_flTimeAttackQueued: %f", fVal);
	fVal = GetEntPropFloat(sniper, Prop_Send, "m_flNextPrimaryAttack");
	PrintToChatAll("m_flNextPrimaryAttack: %f", fVal);
	new Float:fNextPrimaryAttackVal = FloatAdd(fVal, 0.25);
	SetEntPropFloat(sniper, Prop_Send, "m_flNextPrimaryAttack", fNextPrimaryAttackVal);
}
#endif

static SetCurrentSnipers()
{
	decl String:classname[128];
	new sniper;
	
	for (new client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client) || GetClientTeam(client) != 2 || !IsPlayerAlive(client)) continue;
		
		sniper = GetPlayerWeaponSlot(client, 0);
		
		if (sniper == -1 || !IsValidEntity(sniper)) continue;
	
		GetEdictClassname(sniper, classname, sizeof(classname));
		if (!StrEqual(classname, "weapon_hunting_rifle")) continue;
		
		new Handle:pack;
		CreateDataTimer(0.1, __SetInitialSnipers, pack, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
		WritePackCell(pack, client);
	}
}

public OnWeaponFire_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!bEnabled) return;
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
		
	if (client < 1 || 
		client > MaxClients ||
		IsFakeClient(client) ||
		GetClientTeam(client) != 2 || 
		!g_bIsSniperActive[client])
		return;
	
	new sniper = GetPlayerWeaponSlot(client, 0);
	if (sniper == -1) return;
	
	g_fNextPrimaryAttack[client] = FloatAdd(GetGameTime(), Float:g_fFireSpeed);
	g_bFiredSniper[client] = true;
}


public OnPluginEnd()
{
	for (new client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client)) continue;
		SDKUnhook(client, SDKHook_WeaponEquip, OnWeaponEquip);
		SDKUnhook(client, SDKHook_WeaponSwitch, OnWeaponSwitch);
	}
}

public ConVarChange_Enabled(Handle:convar, const String:oldValue[], const String:newValue[])
{
	CheckEnabled();
}

public ConVarChange_ClipSize(Handle:convar, const String:oldValue[], const String:newValue[])
{	
	SetClipSize();
}

public ConVarChange_AmmoCount(Handle:convar, const String:oldValue[], const String:newValue[])
{	
	SetAmmoCount();
}

public ConVarChange_Slow(Handle:convar, const String:oldValue[], const String:newValue[])
{	
	SetFireSpeed();
}

static CheckEnabled()
{
	bEnabled = GetConVarBool(hEnabledCvar);
	if(bEnabled) 
	{
		SetClipSize();		//getting and setting the clip size based on the cvar
		SetAmmoCount();		//getting and setting the total ammo count based on the cvar
		SetFireSpeed();		//getting and setting the firespeed
		SetCurrentSnipers();
	}
	else ResetAmmoCount();
}

static ResetAmmoCount()
{
	SetConVarInt(FindConVar("ammo_huntingrifle_max"), 150);		//reset the total ammo count back to its stock settings
}

static SetClipSize()
{
	g_iClipSize = GetConVarInt(hClipSizeCvar);
}

static SetAmmoCount()
{
	g_iAmmoCount = GetConVarInt(hAmmoCountCvar);
	SetConVarInt(FindConVar("ammo_huntingrifle_max"), g_iAmmoCount);
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

static ResetClientSniperData(client)
{
	g_bFiredSniper[client] = false;
	g_fNextPrimaryAttack[client] = 0.0;
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if (!bEnabled) return Plugin_Continue;	//If plugin isn't enabled, skip
	
	if (g_bIsSniperActive[client] && g_bFiredSniper[client] && buttons & IN_ATTACK)	//If player is holding sniper, and he just fired a shot, and he uses +attack
	{
		new sniper = GetPlayerWeaponSlot(client, 0);
		SetEntPropFloat(sniper, Prop_Send, "m_flNextPrimaryAttack", g_fNextPrimaryAttack[client]);
		g_bFiredSniper[client] = false;
	}
	if (g_bIsSniperActive[client] && buttons & IN_RELOAD) //If player is holding sniper and wants to reload
	{
		new sniper = GetPlayerWeaponSlot(client, 0);
		if (GetEntProp(sniper, Prop_Send, "m_iClip1") == g_iClipSize)	//If the his current mag equals the maximum allowed, remove reload from buttons
		{
			buttons ^= IN_RELOAD;
		}		
	}
	return Plugin_Continue;
}

public OnWeaponReload_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!bEnabled) return;
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
		
	if (client < 1 || 
		client > MaxClients ||
		IsFakeClient(client) ||
		GetClientTeam(client) != 2 || 
		!g_bIsSniperActive[client])
		return;
	
	new sniper = GetPlayerWeaponSlot(client, 0);
	new ammo = GetEntData(client, (FindSendPropInfo("CCSPlayer", "m_iAmmo")) + 8);
	
	new Handle:pack;
	CreateDataTimer(0.01, __CheckSniperReload, pack, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	WritePackCell(pack, client);
	WritePackCell(pack, sniper);
	WritePackCell(pack, ammo);	
}

public Action:__CheckSniperReload(Handle:timer, Handle:pack)
{
	ResetPack(pack);
	new client = ReadPackCell(pack);
	new sniper = ReadPackCell(pack);
	new ammo = ReadPackCell(pack);
	new clip = g_iClipSize;
	new clipMinOne = (g_iClipSize - 1);
	
	if (sniper == -1 || !IsValidEntity(sniper))
	{
		//PrintToChatAll("sniper dropped");
		return Plugin_Stop;
	}
	
	if(client == 0 || !IsClientInGame(client) || !IsPlayerAlive(client))
	{
		//PrintToChatAll("client disconnected");
		return Plugin_Stop;
	}
		
	if (GetEntProp(sniper, Prop_Send, "m_bInReload") == 0 && GetEntProp(sniper, Prop_Send, "m_iClip1") == 0)
	{
		//PrintToChatAll("reload interrupted");
		return Plugin_Stop;
	}
	if (GetEntProp(sniper, Prop_Send, "m_iClip1") == 15)
	{
		ammo -= clip;
		//PrintToChatAll("reload completed");
		SetEntData(client, (FindSendPropInfo("CCSPlayer", "m_iAmmo") + 8), ammo);
		SetEntProp(sniper, Prop_Send, "m_iClip1", clip);
		return Plugin_Stop;
	}
	if (GetEntProp(sniper, Prop_Send, "m_iClip1") < 15 && GetEntProp(sniper, Prop_Send, "m_iClip1") > clip)
	{
		ammo -= clip;
		//PrintToChatAll("reload completed");
		SetEntData(client, (FindSendPropInfo("CCSPlayer", "m_iAmmo") + 8), ammo);
		SetEntProp(sniper, Prop_Send, "m_iClip1", clipMinOne);
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

public Action:OnWeaponSwitch(client, weapon)
{
	if (!bEnabled || weapon < 1 ||
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
	if (GetClientTeam(client) != 2 || !bEnabled) return Plugin_Continue;

	decl String:classname[128];
	GetEdictClassname(weapon, classname, sizeof(classname));
	if (!StrEqual(classname, "weapon_hunting_rifle")) return Plugin_Continue;
	
	g_bIsSniperActive[client] = true;	//client is carrying sniper now (OnWeaponSwitch actually takes care of this)
	
	new Handle:pack;
	CreateDataTimer(0.1, __CheckPrimaryAmmo, pack, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	WritePackCell(pack, client);
	
	return Plugin_Continue;
}

public Action:__CheckPrimaryAmmo(Handle:timer, Handle:pack)
{
	ResetPack(pack);
	new client = ReadPackCell(pack);
	new clip = g_iClipSize;
		
	if(client == 0 || !IsClientInGame(client) || !IsPlayerAlive(client))
	{
		return Plugin_Stop;
	}
	
	new sniper = GetPlayerWeaponSlot(client, 0);
	
	if(sniper != -1)
	{
		if(GetEntProp(sniper, Prop_Send, "m_iClip1") > clip)
		{
			SetEntProp(sniper, Prop_Send, "m_iClip1", clip);
		}
		g_bIsSniperActive[client] = true;
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

public Action:__SetInitialSnipers(Handle:timer, Handle:pack)
{
	ResetPack(pack);
	new client = ReadPackCell(pack);
	new clip = g_iClipSize;
		
	if(client == 0 || !IsClientInGame(client) || !IsPlayerAlive(client))
	{
		return Plugin_Stop;
	}
	
	new sniper = GetPlayerWeaponSlot(client, 0);
	
	if(sniper != -1)
	{
		if(GetEntProp(sniper, Prop_Send, "m_iClip1") > clip)
		{
			SetEntProp(sniper, Prop_Send, "m_iClip1", clip);
		}
		new ammo = GetEntData(client, (FindSendPropInfo("CCSPlayer", "m_iAmmo")) + 8);
		if (ammo > g_iAmmoCount)
		{
			SetEntData(client, (FindSendPropInfo("CCSPlayer", "m_iAmmo") + 8), g_iAmmoCount);
		}
		g_bIsSniperActive[client] = true;
		return Plugin_Stop;
	}
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