#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

#define TANK_ZOMBIE_CLASS   5

ConVar g_hCvar_tankProps, g_hCvar_tankPropsGlow, g_hCvar_tankPropsGlowSpec, g_hCvarColor;
Handle hTankProps       = INVALID_HANDLE;
Handle hTankPropsHit    = INVALID_HANDLE;
int i_Ent[5000] = -1;
int i_EntSpec[5000]= -1;
int g_iCvarColor[3];
bool tankSpawned;
int iTankClient = -1;

public Plugin:myinfo = {
	name        = "L4D2 Tank Props,l4d1 modify by Harry",
	author      = "Jahze & Harry Potter",
	version     = "1.7",
	description = "Stop tank props from fading whilst the tank is alive + add Hittable Glow",
	url = "https://steamcommunity.com/id/fbef0102/"
};

public void OnPluginStart() {
	g_hCvar_tankProps = CreateConVar("l4d_tank_props", "1", "Prevent tank props from fading whilst the tank is alive", FCVAR_NOTIFY);
	g_hCvar_tankPropsGlow = CreateConVar("l4d_tank_props_glow", "1", "Show Hittable Glow for inf team whilst the tank is alive", FCVAR_NOTIFY);
	g_hCvar_tankPropsGlowSpec = CreateConVar( "l4d2_tank_prop_glow_spectators", "1", "Spectators can see the glow too", FCVAR_NOTIFY);
	g_hCvarColor =	CreateConVar("l4d2_tank_prop_glow_color", "255 0 0", "Three values between 0-255 separated by spaces. RGB Color255 - Red Green Blue.", FCVAR_NOTIFY);
	
	g_hCvar_tankProps.AddChangeHook(TankPropsChange);
	g_hCvar_tankPropsGlow.AddChangeHook(TankPropsGlowChange);
	g_hCvar_tankPropsGlowSpec.AddChangeHook(TankPropsGlowSpecChange);
	g_hCvarColor.AddChangeHook(ConVarChanged_Glow);
	
	PluginEnable();
}

public void OnPluginEnd()//Called when the plugin is about to be unloaded.
{
	PluginDisable();
}

void PluginEnable() {
	SetConVarBool(FindConVar("sv_tankpropfade"), false);
	
	hTankProps = CreateArray();
	hTankPropsHit = CreateArray();
	char sColor[16];
	g_hCvarColor.GetString(sColor, sizeof(sColor));
	GetColor(sColor);
	
	HookEvent("round_start", TankPropRoundReset);
	HookEvent("tank_spawn", TankPropTankSpawn);
	HookEvent("entity_killed", PD_ev_EntityKilled);
	
	if ( GetTankClient()) {
		UnhookTankProps();
		ClearArray(hTankPropsHit);
		
		HookTankProps();
		
		tankSpawned = true;
	}
}

void PluginDisable() {
	SetConVarBool(FindConVar("sv_tankpropfade"), true);
	
	UnhookEvent("round_start", TankPropRoundReset);
	UnhookEvent("tank_spawn", TankPropTankSpawn);
	UnhookEvent("entity_killed",		PD_ev_EntityKilled);
	
	
	int entity;
	
	for ( int i = 0; i < GetArraySize(hTankPropsHit); i++ ) {
		if ( IsValidEdict(GetArrayCell(hTankPropsHit, i)) ) {
			entity = i_Ent[GetArrayCell(hTankPropsHit, i)];
			if(IsValidEntRef(entity))
				RemoveEdict(entity);
			entity = i_EntSpec[GetArrayCell(hTankPropsHit, i)];
			if(IsValidEntRef(entity))
				RemoveEdict(entity);
		}
	}
	UnhookTankProps();
	ClearArray(hTankPropsHit);
	
	CloseHandle(hTankProps);
	CloseHandle(hTankPropsHit);
	tankSpawned = false;
}

public void ConVarChanged_Glow( Handle cvar, const char[] oldValue, const char[] newValue )  {
	char sColor[16];
	g_hCvarColor.GetString(sColor, sizeof(sColor));
	GetColor(sColor);

	if(!tankSpawned) return;

	int entity;

	for ( int i = 0; i < GetArraySize(hTankPropsHit); i++ ) {
		if ( IsValidEdict(GetArrayCell(hTankPropsHit, i)) ) {
			entity = i_Ent[GetArrayCell(hTankPropsHit, i)];
			if( IsValidEntRef(entity) )
			{
				SetEntityRenderColor (entity, g_iCvarColor[0],g_iCvarColor[1],g_iCvarColor[2],200 );
			}
			entity = i_EntSpec[GetArrayCell(hTankPropsHit, i)];
			if( IsValidEntRef(entity) )
			{
				SetEntityRenderColor (entity, g_iCvarColor[0],g_iCvarColor[1],g_iCvarColor[2],200 );
			}
		}
	}
}

public void TankPropsChange( Handle cvar, const char[] oldValue, const char[] newValue ) {
    if ( StringToInt(newValue) == 0 ) {
        PluginDisable();
    }
    else {
        PluginEnable();
    }
}

public void TankPropsGlowChange( Handle cvar, const char[] oldValue, const char[] newValue ) {
	if(StrEqual(newValue,oldValue)) return;
	
	if ( StringToInt(newValue) == 0 ) {
		int entity;
		for ( int i = 0; i < GetArraySize(hTankPropsHit); i++ ) {
			if ( IsValidEdict(GetArrayCell(hTankPropsHit, i)) ) {
				entity = i_Ent[GetArrayCell(hTankPropsHit, i)];
				if(IsValidEntRef(entity))
					RemoveEdict(entity);
			}
		}
    }
	else
	{
		for ( int i = 0; i < GetArraySize(hTankPropsHit); i++ ) {
			if ( IsValidEdict(GetArrayCell(hTankPropsHit, i)) ) {
				CreateTankPropGlow(GetArrayCell(hTankPropsHit, i));
			}
		}
	}
}

public void TankPropsGlowSpecChange( Handle cvar, const char[] oldValue, const char[] newValue ) {
	if(StrEqual(newValue,oldValue)) return;
	
	if ( StringToInt(newValue) == 0) {
		int entity;
		for ( int i = 0; i < GetArraySize(hTankPropsHit); i++ ) {
			if ( IsValidEdict(GetArrayCell(hTankPropsHit, i)) ) {
				entity = i_EntSpec[GetArrayCell(hTankPropsHit, i)];
				if(IsValidEntRef(entity))
					RemoveEdict(entity);
			}
		}
    }
	else
	{
		for ( int i = 0; i < GetArraySize(hTankPropsHit); i++ ) {
			if ( IsValidEdict(GetArrayCell(hTankPropsHit, i)) ) {
				CreateTankPropGlowSpectator(GetArrayCell(hTankPropsHit, i));
			}
		}
	}
}

public Action TankPropRoundReset( Handle event, const char[] name, bool dontBroadcast ) {
    tankSpawned = false;
    
    UnhookTankProps();
    ClearArray(hTankPropsHit);
}

public Action TankPropTankSpawn( Handle event, const char[] name, bool dontBroadcast ) {
    if ( !tankSpawned ) {
        UnhookTankProps();
        ClearArray(hTankPropsHit);
        
        HookTankProps();
        
        tankSpawned = true;
    }    
}

public Action PD_ev_EntityKilled( Handle event, const char[] name, bool dontBroadcast )
{
	if (tankSpawned && GetEntProp((GetEventInt(event, "entindex_killed")), Prop_Send, "m_zombieClass") == 5)
	{
		CreateTimer(1.5, TankDeadCheck,_,TIMER_FLAG_NO_MAPCHANGE);
	}
}
public Action TankDeadCheck( Handle timer ) {

	if ( GetTankClient() == -1 ) {
		UnhookTankProps();
		CreateTimer(1.0, FadeTankProps);
		tankSpawned = false;
	}
}

public void PropDamaged(int victim, int attacker, int inflictor, float damage, int damageType) {
	if ( attacker == GetTankClient() || FindValueInArray(hTankPropsHit, inflictor) != -1 ) {
		if ( FindValueInArray(hTankPropsHit, victim) == -1 ) {
			PushArrayCell(hTankPropsHit, victim);

			if(GetConVarInt(g_hCvar_tankPropsGlow) == 1)
				CreateTankPropGlow(victim);
			if(GetConVarInt(g_hCvar_tankPropsGlowSpec) == 1)
				CreateTankPropGlowSpectator(victim);
		}
	}
}

void CreateTankPropGlow(int entity)
{
	char sModelName[64];
	GetEntPropString(entity, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName));
	//PrintToChatAll("m_ModelName: %s", sModelName);
		
	float vPos[3];
	float vAng[3];
		
	GetEntPropVector(entity, Prop_Data, "m_vecOrigin", vPos);
	GetEntPropVector(entity, Prop_Send, "m_angRotation", vAng);
	
	if (StrEqual(sModelName, "models/props_vehicles/generatortrailer01.mdl"))
	{
		i_Ent[entity] = CreateEntityByName("prop_dynamic_override");
		DispatchKeyValue(i_Ent[entity], "model", sModelName);
		DispatchKeyValue(i_Ent[entity], "targetname", "propglow");
	}
	else
	{
		i_Ent[entity] = CreateEntityByName("prop_glowing_object");
		DispatchKeyValue(i_Ent[entity], "model", sModelName);
		DispatchKeyValue(i_Ent[entity], "StartGlowing", "1");
		DispatchKeyValue(i_Ent[entity], "targetname", "propglow");
		
		DispatchKeyValue(i_Ent[entity], "GlowForTeam", "3");
	}


	/* GlowForTeam =  -1:ALL  , 0:NONE , 1:SPECTATOR  , 2:SURVIVOR , 3:INFECTED */
	
	DispatchKeyValue(i_Ent[entity], "fadescale", "1");
	DispatchKeyValue(i_Ent[entity], "fademindist", "3000");
	DispatchKeyValue(i_Ent[entity], "fademaxdist", "3200");
	
	TeleportEntity(i_Ent[entity], vPos, vAng, NULL_VECTOR);
	DispatchSpawn(i_Ent[entity]);
	SetEntityRenderMode( i_Ent[entity], RENDER_GLOW );
	SetEntityRenderColor (i_Ent[entity], g_iCvarColor[0],g_iCvarColor[1],g_iCvarColor[2],200 );
	
	SDKHook(entity, SDKHook_VPhysicsUpdatePost, TankThink);
}

public void TankThink(int entity)
{
	if (!IsValidEntity(entity) || !tankSpawned)
	{
		if (IsValidEdict(i_Ent[entity]))
		{
			RemoveEdict(i_Ent[entity]);
		}
		SDKUnhook(entity, SDKHook_VPhysicsUpdatePost, TankThink);
		return;
	}
	
	if (IsValidEdict(i_Ent[entity]))
	{
		float vPos[3];
		float vAng[3];
		GetEntPropVector(entity, Prop_Data, "m_vecOrigin", vPos);
		GetEntPropVector(entity, Prop_Send, "m_angRotation", vAng);
		TeleportEntity(i_Ent[entity], vPos, vAng, NULL_VECTOR);
	}
}

void CreateTankPropGlowSpectator(int entity)
{
	char sModelName[64];
	GetEntPropString(entity, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName));
	
	float vPos[3];
	float vAng[3];
		
	GetEntPropVector(entity, Prop_Data, "m_vecOrigin", vPos);
	GetEntPropVector(entity, Prop_Send, "m_angRotation", vAng);
	
	if (StrEqual(sModelName, "models/props_vehicles/generatortrailer01.mdl"))
	{
		i_EntSpec[entity] = CreateEntityByName("prop_dynamic_override");
		DispatchKeyValue(i_EntSpec[entity], "model", sModelName);
		DispatchKeyValue(i_EntSpec[entity], "targetname", "propglow");
	}
	else
	{
		i_EntSpec[entity] = CreateEntityByName("prop_glowing_object");
		DispatchKeyValue(i_EntSpec[entity], "model", sModelName);
		DispatchKeyValue(i_EntSpec[entity], "StartGlowing", "1");
		DispatchKeyValue(i_EntSpec[entity], "StartDisabled", "1");
		DispatchKeyValue(i_EntSpec[entity], "targetname", "propglow");
		
		DispatchKeyValue(i_EntSpec[entity], "GlowForTeam", "1");
	}
	
	DispatchKeyValue(i_EntSpec[entity], "fadescale", "1");
	DispatchKeyValue(i_EntSpec[entity], "fademindist", "3000");
	DispatchKeyValue(i_EntSpec[entity], "fademaxdist", "3200");
	
	TeleportEntity(i_EntSpec[entity], vPos, vAng, NULL_VECTOR);
	DispatchSpawn(i_EntSpec[entity]);
	SetEntityRenderFx(i_EntSpec[entity], RENDERFX_FADE_FAST);

	SDKHook(entity, SDKHook_VPhysicsUpdatePost, SpecTankThink);
}

public void SpecTankThink(int entity)
{
	if (!IsValidEntity(entity) || !tankSpawned)
	{
		if (IsValidEdict(i_EntSpec[entity]))
		{
			RemoveEdict(i_EntSpec[entity]);
		}
		SDKUnhook(entity, SDKHook_VPhysicsUpdatePost, SpecTankThink);
		return;
	}
	
	if (IsValidEdict(i_EntSpec[entity]))
	{
		float vPos[3];
		float vAng[3];
		GetEntPropVector(entity, Prop_Data, "m_vecOrigin", vPos);
		GetEntPropVector(entity, Prop_Send, "m_angRotation", vAng);
		TeleportEntity(i_EntSpec[entity], vPos, vAng, NULL_VECTOR);
	}
}

public Action FadeTankProps( Handle timer ) {
    int entity;
    for ( int i = 0; i < GetArraySize(hTankPropsHit); i++ ) {
		entity = GetArrayCell(hTankPropsHit, i);
		if(IsValidEdict(entity))
		{
            RemoveEdict(entity);
            if (IsValidEdict(i_Ent[entity]))
				RemoveEdict(i_Ent[entity]);
				
            if (IsValidEdict(i_EntSpec[entity]))
				RemoveEdict(i_EntSpec[entity]);
        }
    }
    
    ClearArray(hTankPropsHit);
}

bool IsTankProp( int iEntity ) {
	if ( !IsValidEdict(iEntity) ) {
		return false;
	}
	
	char className[64];
	GetEdictClassname(iEntity, className, sizeof(className));
	if ( StrEqual(className, "prop_physics") || StrEqual(className, "prop_physics_multiplayer")) {
		if ( GetEntProp(iEntity, Prop_Send, "m_hasTankGlow", 1) ) {
			return true;
		}
	}
	else if ( StrEqual(className, "prop_car_alarm") ) {
		return true;
	}
	
	return false;
}

void HookTankProps() {
    int iEntCount = GetMaxEntities();
    
    for ( int i = 1; i <= iEntCount; i++ ) {
        if ( IsTankProp(i) ) {
			SDKHook(i, SDKHook_OnTakeDamagePost, PropDamaged);
			PushArrayCell(hTankProps, i);
		}
    }
}

void UnhookTankProps() {
    for ( int i = 0; i < GetArraySize(hTankProps); i++ ) {
        SDKUnhook(GetArrayCell(hTankProps, i), SDKHook_OnTakeDamagePost, PropDamaged);
    }
    
    ClearArray(hTankProps);
}

int GetTankClient() {
    if ( iTankClient == -1 || !IsTank(iTankClient) ) {
        iTankClient = FindTank();
    }
    
    return iTankClient;
}

int FindTank() {
    for ( int i = 1; i <= MaxClients; i++ ) {
        if ( IsTank(i) ) {
            return i;
        }
    }
    
    return -1;
}

bool IsTank( int client ) {
    if ( client < 0
    || !IsClientConnected(client)
    || !IsClientInGame(client)
    || GetClientTeam(client) != 3
    || !IsPlayerAlive(client) ) {
        return false;
    }
    
    int playerClass = GetEntProp(client, Prop_Send, "m_zombieClass");
    
    if ( playerClass == TANK_ZOMBIE_CLASS ) {
        return true;
    }
    
    return false;
}

bool IsValidEntRef(int entity)
{
	if( entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE && entity!= -1 && IsValidEntity(entity) && IsValidEdict(entity))
		return true;
	return false;
}

int GetColor(char[] sTemp)
{
	if( StrEqual(sTemp, "") )
	{
		g_iCvarColor[0] = 0;
		g_iCvarColor[1] = 0;
		g_iCvarColor[2] = 0;
	}

	char sColors[3][4];
	int color = ExplodeString(sTemp, " ", sColors, 3, 4);

	if( color != 3 )
	{
		g_iCvarColor[0] = 0;
		g_iCvarColor[1] = 0;
		g_iCvarColor[2] = 0;
	}

	g_iCvarColor[0] = StringToInt(sColors[0]);
	g_iCvarColor[1] = StringToInt(sColors[1]);
	g_iCvarColor[2] = StringToInt(sColors[2]);
}