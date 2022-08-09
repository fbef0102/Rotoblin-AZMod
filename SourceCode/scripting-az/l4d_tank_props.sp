#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <dhooks>

#define TANK_ZOMBIE_CLASS   5

ConVar g_hCvar_tankProps, g_hCvar_tankPropsGlow, g_hCvar_tankPropsGlowSpec, g_hCvarColor;
ConVar sv_tankpropfade;
bool g_bCvar_tankProps, g_bCvar_tankPropsGlow, g_bCvar_tankPropsGlowSpec;

Handle hTankProps       = INVALID_HANDLE;
Handle hTankPropsHit    = INVALID_HANDLE;
int i_Ent[2048+1] = {-1};
int i_EntSpec[2048+1]= {-1};
int g_iCvarColor[3];
bool tankSpawned;
int iTankClient = -1;

public Plugin:myinfo = {
	name        = "L4D2 Tank Props,l4d1 modify by Harry",
	author      = "Jahze & Harry Potter",
	version     = "2.6",
	description = "Stop tank props from fading whilst the tank is alive + add Hittable Glow",
	url = "http://steamcommunity.com/profiles/76561198026784913"
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

public void OnPluginStart() {
	sv_tankpropfade = FindConVar("sv_tankpropfade");
	
	g_hCvar_tankProps = CreateConVar("l4d_tank_props", "1", "Prevent tank props from fading whilst the tank is alive", FCVAR_NOTIFY);
	g_hCvar_tankPropsGlow = CreateConVar("l4d_tank_props_glow", "1", "Show Hittable Glow for inf team whilst the tank is alive", FCVAR_NOTIFY);
	g_hCvar_tankPropsGlowSpec = CreateConVar( "l4d_tank_prop_glow_spectators", "1", "Spectators can see the glow too", FCVAR_NOTIFY);
	g_hCvarColor =	CreateConVar("l4d_tank_prop_render_color", "255 0 0", "Three values between 0-255 separated by spaces. RGB Color255 - Red Green Blue. (-1 -1 -1: disable)", FCVAR_NOTIFY);
	
	GetCvars();
	g_hCvar_tankProps.AddChangeHook(TankPropsChange);
	g_hCvar_tankPropsGlow.AddChangeHook(TankPropsGlowChange);
	g_hCvar_tankPropsGlowSpec.AddChangeHook(TankPropsGlowSpecChange);
	g_hCvarColor.AddChangeHook(ConVarChanged_Glow);
	
	PluginEnable();
}

public void OnPluginEnd()
{
	PluginDisable();
}

public void OnMapEnd()
{
	ClearArray(hTankProps);
	ClearArray(hTankPropsHit);
}

void PluginEnable() {
	sv_tankpropfade.SetBool(false);
	
	hTankProps = CreateArray();
	hTankPropsHit = CreateArray();
	
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
	sv_tankpropfade.SetBool(true);
	
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
	
	delete hTankProps;
	delete hTankPropsHit;
	tankSpawned = false;
}

public void ConVarChanged_Glow( Handle cvar, const char[] oldValue, const char[] newValue )  {
	
	GetCvars();

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
	GetCvars();

	if ( g_bCvar_tankProps == false ) {
		PluginDisable();
	}
	else {
		PluginEnable();
	}
}

public void TankPropsGlowChange( Handle cvar, const char[] oldValue, const char[] newValue ) {
	GetCvars();

	if ( !g_bCvar_tankPropsGlow ) {
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
	GetCvars();
	
	if ( g_bCvar_tankPropsGlowSpec == false) {
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

void GetCvars()
{
	g_bCvar_tankProps = g_hCvar_tankProps.BoolValue;
	g_bCvar_tankPropsGlow = g_hCvar_tankPropsGlow.BoolValue;
	g_bCvar_tankPropsGlowSpec = g_hCvar_tankPropsGlowSpec.BoolValue;

	char sColor[16];
	g_hCvarColor.GetString(sColor, sizeof(sColor));
	GetColor(sColor, g_iCvarColor);
}

public void TankPropRoundReset( Handle event, const char[] name, bool dontBroadcast ) {
    tankSpawned = false;
    
    UnhookTankProps();
    ClearArray(hTankPropsHit);
}

public void TankPropTankSpawn( Handle event, const char[] name, bool dontBroadcast ) {
	if ( !tankSpawned ) {
		UnhookTankProps();
		ClearArray(hTankPropsHit);
		
		HookTankProps();

		DHookAddEntityListener(ListenType_Created, PossibleTankPropCreated);
		
		tankSpawned = true;
    }    
}

public void PD_ev_EntityKilled( Handle event, const char[] name, bool dontBroadcast )
{
	if (tankSpawned && GetEntProp((GetEventInt(event, "entindex_killed")), Prop_Send, "m_zombieClass") == 5)
	{
		CreateTimer(1.5, TankDeadCheck,_,TIMER_FLAG_NO_MAPCHANGE);
	}
}
public Action TankDeadCheck( Handle timer ) {

	if ( GetTankClient() == -1 ) {
		UnhookTankProps();

		DHookRemoveEntityListener(ListenType_Created, PossibleTankPropCreated);

		CreateTimer(3.5, FadeTankProps,_ ,TIMER_FLAG_NO_MAPCHANGE);

		tankSpawned = false;
	}

	return Plugin_Continue;
}

public void PropDamaged(int victim, int attacker, int inflictor, float damage, int damageType) {
	if ( attacker == GetTankClient() || FindValueInArray(hTankPropsHit, inflictor) != -1 ) {
		if ( FindValueInArray(hTankPropsHit, victim) == -1 ) {
			PushArrayCell(hTankPropsHit, victim);

			if(g_bCvar_tankPropsGlow)
				CreateTankPropGlow(victim);
			if(g_bCvar_tankPropsGlowSpec)
				CreateTankPropGlowSpectator(victim);
		}
	}
}

void CreateTankPropGlow(int car)
{
	static char sModelName[64];
	GetEntPropString(car, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName));
	//PrintToChatAll("m_ModelName: %s", sModelName);
		
	float vPos[3];
	float vAng[3];
		
	GetEntPropVector(car, Prop_Data, "m_vecOrigin", vPos);
	GetEntPropVector(car, Prop_Send, "m_angRotation", vAng);

	int entity;
	if (strcmp(sModelName, "models/props_vehicles/generatortrailer01.mdl", false) == 0)
	{
		entity = CreateEntityByName("prop_dynamic_override");
		if(entity < 0 ) return;
		DispatchKeyValue(entity, "model", sModelName);
		DispatchKeyValue(entity, "targetname", "propglow");
	}
	else
	{
		entity = CreateEntityByName("prop_glowing_object");
		if(entity < 0 ) return;
		DispatchKeyValue(entity, "model", sModelName);
		DispatchKeyValue(entity, "StartGlowing", "1");
		DispatchKeyValue(entity, "targetname", "propglow");
		
		DispatchKeyValue(entity, "GlowForTeam", "3");
	}


	/* GlowForTeam =  -1:ALL  , 0:NONE , 1:SPECTATOR  , 2:SURVIVOR , 3:INFECTED */
	
	DispatchKeyValue(entity, "fadescale", "1");
	DispatchKeyValue(entity, "fademindist", "3000");
	DispatchKeyValue(entity, "fademaxdist", "3200");
	
	TeleportEntity(entity, vPos, vAng, NULL_VECTOR);
	DispatchSpawn(entity);
	SetEntityRenderFx(entity, RENDERFX_FADE_FAST);
	SetVariantString("!activator");
	AcceptEntityInput(entity, "SetParent", car); 

	i_Ent[car] = EntIndexToEntRef(entity);
	//SDKHook(car, SDKHook_VPhysicsUpdatePost, TankThink);

	SetEntityRenderMode(car, RENDER_TRANSCOLOR);
	if(g_iCvarColor[0] == -1 && g_iCvarColor[1] == -1 && g_iCvarColor[2] == -1) return;
	SetEntityRenderColor (car, g_iCvarColor[0],g_iCvarColor[1],g_iCvarColor[2], 255);
}

/*
void TankThink(int car)
{
	int entity = i_Ent[car];
	if (IsValidEntRef(entity))
	{
		float vPos[3];
		float vAng[3];
		GetEntPropVector(car, Prop_Data, "m_vecOrigin", vPos);
		GetEntPropVector(car, Prop_Send, "m_angRotation", vAng);
		TeleportEntity(entity, vPos, vAng, NULL_VECTOR);
	}
	else
	{
		SDKUnhook(car, SDKHook_VPhysicsUpdatePost, TankThink);
	}
}
*/

void CreateTankPropGlowSpectator(int car)
{
	static char sModelName[64];
	GetEntPropString(car, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName));
	
	float vPos[3];
	float vAng[3];
		
	GetEntPropVector(car, Prop_Data, "m_vecOrigin", vPos);
	GetEntPropVector(car, Prop_Send, "m_angRotation", vAng);

	int entity;
	if (strcmp(sModelName, "models/props_vehicles/generatortrailer01.mdl", false) == 0)
	{
		entity = CreateEntityByName("prop_dynamic_override");
		DispatchKeyValue(entity, "model", sModelName);
		DispatchKeyValue(entity, "targetname", "propglow");
	}
	else
	{
		entity = CreateEntityByName("prop_glowing_object");
		DispatchKeyValue(entity, "model", sModelName);
		DispatchKeyValue(entity, "StartGlowing", "1");
		DispatchKeyValue(entity, "StartDisabled", "1");
		DispatchKeyValue(entity, "targetname", "propglow");
		
		DispatchKeyValue(entity, "GlowForTeam", "1");
	}
	
	DispatchKeyValue(entity, "fadescale", "1");
	DispatchKeyValue(entity, "fademindist", "3000");
	DispatchKeyValue(entity, "fademaxdist", "3200");
	
	TeleportEntity(entity, vPos, vAng, NULL_VECTOR);
	DispatchSpawn(entity);
	SetEntityRenderFx(entity, RENDERFX_FADE_FAST);
	SetVariantString("!activator");
	AcceptEntityInput(entity, "SetParent", car); 

	i_EntSpec[car] = EntIndexToEntRef(entity);

	//SDKHook(car, SDKHook_VPhysicsUpdatePost, SpecTankThink);
}
/*
void SpecTankThink(int car)
{
	int entity = i_EntSpec[car];
	if (IsValidEntRef(entity))
	{
		float vPos[3];
		float vAng[3];
		GetEntPropVector(car, Prop_Data, "m_vecOrigin", vPos);
		GetEntPropVector(car, Prop_Send, "m_angRotation", vAng);
		TeleportEntity(entity, vPos, vAng, NULL_VECTOR);
	}
	else
	{
		SDKUnhook(car, SDKHook_VPhysicsUpdatePost, TankThink);
	}
}
*/
public Action FadeTankProps( Handle timer ) {
	int entity;
	for ( int i = 0; i < GetArraySize(hTankPropsHit); i++ ) {
		entity = GetArrayCell(hTankPropsHit, i);
		if(IsValidEdict(entity))
		{
			RemoveEdict(entity);
			if (IsValidEntRef(i_Ent[entity]))
				RemoveEdict(i_Ent[entity]);
				
			if (IsValidEntRef(i_EntSpec[entity]))
				RemoveEdict(i_EntSpec[entity]);
		}
	}

	ClearArray(hTankPropsHit);

	return Plugin_Continue;
}

bool IsTankProp( int iEntity ) {
	if (!IsValidEdict(iEntity)) {
		return false;
	}
	
	// CPhysicsProp only
	if (!HasEntProp(iEntity, Prop_Send, "m_hasTankGlow")) {
		return false;
	}
	
	bool bHasTankGlow = (GetEntProp(iEntity, Prop_Send, "m_hasTankGlow", 1) == 1);
	if (!bHasTankGlow) {
		return false;
	}

	static char sModel[PLATFORM_MAX_PATH];
	GetEntPropString(iEntity, Prop_Data, "m_ModelName", sModel, sizeof(sModel));
	if (strcmp("models/props_industrial/brickpallets.mdl", sModel) == 0) {
		return false;
	}
	
	return true;
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

//analogue public void OnEntityCreated(int iEntity, const char[] sClassName)
public void PossibleTankPropCreated(int iEntity, const char[] sClassName)
{
	if (sClassName[0] != 'p') {
		return;
	}
	
	if (strcmp(sClassName, "prop_physics") != 0) { // Hooks c11m4_terminal World Sphere
		return;
	}

	// Use SpawnPost to just push it into the Array right away.
	// These entities get spawned after the Tank has punched them, so doing anything here will not work smoothly.
	SDKHook(iEntity, SDKHook_SpawnPost, Hook_PropSpawned);
}

public void Hook_PropSpawned(int iEntity)
{
	if (iEntity < MaxClients || !IsValidEntity(iEntity)) {
		return;
	}

	if (FindValueInArray(hTankProps, iEntity) == -1) {
		char sModelName[PLATFORM_MAX_PATH];
		GetEntPropString(iEntity, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName));

		if (StrContains(sModelName, "atlas_break_ball") != -1 || StrContains(sModelName, "forklift_brokenlift.mdl") != -1) {
			PushArrayCell(hTankProps, iEntity);
			PushArrayCell(hTankPropsHit, iEntity);

			if(g_bCvar_tankPropsGlow)
				CreateTankPropGlow(iEntity);
			if(g_bCvar_tankPropsGlowSpec)
				CreateTankPropGlowSpectator(iEntity);

		} else if (StrContains(sModelName, "forklift_brokenfork.mdl") != -1) {
			AcceptEntityInput(iEntity, "Kill");
		}
	}
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
	if( entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE)
		return true;
	return false;
}

void GetColor(char[] sTemp, int[] iColor)
{
	if( StrEqual(sTemp, "") )
	{
		iColor[0] = 0;
		iColor[1] = 0;
		iColor[2] = 0;
	}

	char sColors[3][4];
	int color = ExplodeString(sTemp, " ", sColors, 3, 4);

	if( color != 3 )
	{
		iColor[0] = 0;
		iColor[1] = 0;
		iColor[2] = 0;
	}

	iColor[0] = StringToInt(sColors[0]);
	iColor[1] = StringToInt(sColors[1]);
	iColor[2] = StringToInt(sColors[2]);
}