#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <dhooks>

public Plugin myinfo = {
	name        = "L4D2 Tank Props,l4d1 modify by Harry",
	author      = "Jahze & Harry Potter",
	version     = "2.8-2026/1/13",
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

#define ZC_TANK   5

ConVar g_hCvarEnable, g_hCvar_tankPropsGlow, g_hCvar_tankPropsGlowSpec, g_hCvarColor;
ConVar sv_tankpropfade;
bool g_bCvarEnable, g_bCvar_tankPropsGlow, g_bCvar_tankPropsGlowSpec;

ArrayList g_hTankPropsList;
ArrayList g_hTankPropsHitList;
StringMap g_smTankPropToRenderColor;
int g_iInfGlowRef[2048+1] = {-1};
int g_iSpecGlowRef[2048+1]= {-1};
int g_iCvarColor[3];
bool g_bTankSpawned, g_bKillTankProp, g_bRoundEnd;
int iTankClient = -1;

public void OnPluginStart() {
	sv_tankpropfade = FindConVar("sv_tankpropfade");
	
	g_hCvarEnable 				= CreateConVar("l4d_tank_prop_enable", 				"1", 		"0=Plugin off, 1=Plugin on.", FCVAR_NOTIFY);
	g_hCvar_tankPropsGlow 		= CreateConVar("l4d_tank_prop_glow_inf", 			"1", 		"Show Hittable Glow for inf team while tank is alive", FCVAR_NOTIFY);
	g_hCvar_tankPropsGlowSpec	= CreateConVar("l4d_tank_prop_glow_spectators", 	"1", 		"Spectators can see the glow too", FCVAR_NOTIFY);
	g_hCvarColor 				= CreateConVar("l4d_tank_prop_render_color", 		"200 0 0", 	"Three values between 0-255 separated by spaces. RGB Color255 - Red Green Blue. (-1 -1 -1: disable)", FCVAR_NOTIFY);
	
	GetCvars();
	g_hCvarEnable.AddChangeHook(TankPropsChange);
	g_hCvar_tankPropsGlow.AddChangeHook(TankPropsGlowChange);
	g_hCvar_tankPropsGlowSpec.AddChangeHook(TankPropsGlowSpecChange);
	g_hCvarColor.AddChangeHook(ConVarChanged_Glow);
	
	HookEvent("round_start", TankPropRoundStart, EventHookMode_PostNoCopy);
	HookEvent("round_end", TankPropRoundEnd, EventHookMode_PostNoCopy);
	HookEvent("player_spawn", TankPropTankSpawn);
	HookEvent("player_death", TankPropTankKilled);

	//有插件會在此事件時把Tank變成靈魂克，這之後不會觸發後續的player_spawn事件，譬如使用confoglcompmod
	// ai tank生成時觸發
	// ai tank靈魂狀態時觸發
	// 玩家接管靈魂狀態的ai tank時觸發
	// 玩家失去控制權變成ai tank時觸發
	HookEvent("tank_spawn", TankPropTankSpawn);

	PluginEnable();
}

public void OnPluginEnd()
{
	PluginDisable();
}

public void OnMapEnd()
{
	DHookRemoveEntityListener(ListenType_Created, PossibleTankPropCreated);

	delete g_hTankPropsList;
	delete g_hTankPropsHitList;
	delete g_smTankPropToRenderColor;

	g_hTankPropsList = new ArrayList();
	g_hTankPropsHitList = new ArrayList();
	g_smTankPropToRenderColor = new StringMap();
}

public void OnClientDisconnect(int client)
{
	if(IsTank(client))
	{
		CreateTimer(1.0, TankDeadCheck, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

void PluginEnable() 
{
	sv_tankpropfade.SetBool(false);
	
	delete g_hTankPropsList;
	delete g_hTankPropsHitList;
	delete g_smTankPropToRenderColor;

	g_hTankPropsList = new ArrayList();
	g_hTankPropsHitList = new ArrayList();
	g_smTankPropToRenderColor = new StringMap();
	
	if ( GetTankClient() > 0 ) 
	{
		UnhookTankProps();
		
		HookTankProps();
		
		g_bTankSpawned = true;
	}
}

void PluginDisable() 
{
	sv_tankpropfade.SetBool(true);
	
	UnhookTankProps();
	
	g_bTankSpawned = false;
}

public void OnEntityDestroyed(int entity)
{
	if (g_bKillTankProp) 
		return;
		
	if (!IsValidEntityIndex(entity))
		return;

	int iRef = EntIndexToEntRef(entity);
	int index = g_hTankPropsList.FindValue(iRef);
	if (index != -1) {
		g_hTankPropsList.Erase(index);
	}

	index = g_hTankPropsHitList.FindValue(iRef);
	if (index != -1) {
		g_hTankPropsHitList.Erase(index);
	}

	static char sNumber[4];
	IntToString(entity, sNumber, sizeof(sNumber));
	g_smTankPropToRenderColor.Remove(sNumber);
}

void ConVarChanged_Glow( Handle cvar, const char[] oldValue, const char[] newValue )  {
	
	GetCvars();

	int iIndex, entity;
	
	for ( int i = 0; i < GetArraySize(g_hTankPropsHitList); i++ ) 
	{
		iIndex = EntRefToEntIndex(g_hTankPropsHitList.Get(i));
		if ( iIndex != INVALID_ENT_REFERENCE ) 
		{
			entity = g_iInfGlowRef[iIndex];
			if( IsValidEntRef(entity) )
			{
				SetEntityRenderColor (entity, g_iCvarColor[0],g_iCvarColor[1],g_iCvarColor[2],200 );
			}

			entity = g_iSpecGlowRef[iIndex];
			if( IsValidEntRef(entity) )
			{
				SetEntityRenderColor (entity, g_iCvarColor[0],g_iCvarColor[1],g_iCvarColor[2],200 );
			}
		}
	}
}

void TankPropsChange( Handle cvar, const char[] oldValue, const char[] newValue ) {
	GetCvars();

	if ( g_bCvarEnable == false ) {
		PluginDisable();
	}
	else {
		PluginEnable();
	}
}

void TankPropsGlowChange( Handle cvar, const char[] oldValue, const char[] newValue ) {
	GetCvars();

	int glow, entity;
	if ( !g_bCvar_tankPropsGlow ) 
	{
		for ( int i = 0; i < GetArraySize(g_hTankPropsHitList); i++ ) 
		{
			entity = EntRefToEntIndex(g_hTankPropsHitList.Get(i));
			if ( entity != INVALID_ENT_REFERENCE ) 
			{
				glow = g_iInfGlowRef[entity];
				g_iInfGlowRef[entity] = 0;
				if(IsValidEntRef(glow))
					RemoveEntity(glow);
			}
		}
	}
	else
	{
		for ( int i = 0; i < GetArraySize(g_hTankPropsHitList); i++ ) 
		{
			entity = EntRefToEntIndex(g_hTankPropsHitList.Get(i));
			if ( entity != INVALID_ENT_REFERENCE ) 
			{
				CreateTankPropGlow(entity);
			}
		}
	}
}

void TankPropsGlowSpecChange( Handle cvar, const char[] oldValue, const char[] newValue ) {
	GetCvars();
	
	int glow, entity;
	if ( g_bCvar_tankPropsGlowSpec == false) 
	{
		for ( int i = 0; i < GetArraySize(g_hTankPropsHitList); i++ ) 
		{
			entity = EntRefToEntIndex(g_hTankPropsHitList.Get(i));
			if ( entity != INVALID_ENT_REFERENCE ) 
			{
				glow = g_iSpecGlowRef[entity];
				g_iSpecGlowRef[entity] = 0;
				if(IsValidEntRef(glow))
					RemoveEntity(glow);
			}
		}
    }
	else
	{
		for ( int i = 0; i < GetArraySize(g_hTankPropsHitList); i++ ) 
		{
			entity = EntRefToEntIndex(g_hTankPropsHitList.Get(i));
			if ( entity != INVALID_ENT_REFERENCE ) 
			{
				CreateTankPropGlowSpectator(entity);
			}
		}
	}
}

void GetCvars()
{
	g_bCvarEnable = g_hCvarEnable.BoolValue;
	g_bCvar_tankPropsGlow = g_hCvar_tankPropsGlow.BoolValue;
	g_bCvar_tankPropsGlowSpec = g_hCvar_tankPropsGlowSpec.BoolValue;

	char sColor[16];
	g_hCvarColor.GetString(sColor, sizeof(sColor));
	GetColor(sColor, g_iCvarColor);
}

void TankPropRoundStart(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	if(!g_bCvarEnable) return;

	g_bTankSpawned = false;
	g_bRoundEnd = false;

	UnhookTankProps();
	DHookRemoveEntityListener(ListenType_Created, PossibleTankPropCreated);
}

void TankPropRoundEnd(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	if(!g_bCvarEnable) return;
	if(g_bRoundEnd) return;

	g_bTankSpawned = false;
	g_bRoundEnd = true;

	CreateTimer(10.0, Timer_RoundEnd, _, TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_RoundEnd(Handle timer)
{
	UnhookTankProps();
	DHookRemoveEntityListener(ListenType_Created, PossibleTankPropCreated);

	return Plugin_Continue;
}

void TankPropTankSpawn(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	if (!g_bCvarEnable || g_bTankSpawned) {
		return;
	}

	int client = GetClientOfUserId(hEvent.GetInt("userid"));
	if(client && IsAliveTank(client))
	{
		UnhookTankProps(false, false);
		
		HookTankProps();

		DHookRemoveEntityListener(ListenType_Created, PossibleTankPropCreated);
		DHookAddEntityListener(ListenType_Created, PossibleTankPropCreated);
		
		g_bTankSpawned = true;
	} 
}

void TankPropTankKilled(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	if (!g_bCvarEnable || !g_bTankSpawned) {
		return;
	}

	int victim = GetClientOfUserId(hEvent.GetInt("userid"));
	if(victim && IsClientInGame(victim) && GetClientTeam(victim) == 3 && GetEntProp(victim, Prop_Send, "m_zombieClass") == ZC_TANK)
	{
		CreateTimer(1.5, TankDeadCheck, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

Action TankDeadCheck( Handle timer ) 
{
	if ( GetTankClient() <= 0 ) 
	{
		CreateTimer(3.5, TankPropsBeGone,_ ,TIMER_FLAG_NO_MAPCHANGE);

		g_bTankSpawned = false;
	}

	return Plugin_Continue;
}

void PropDamagedPost(int iEntity, int iAttacker, int iInflictor, float fDamage, int iDamageType)
{
	if (!IsValidAliveTank(iAttacker)) return;
	if (iEntity <= MaxClients || !IsValidEntity(iEntity) || !IsValidEntity(iInflictor)) return;
	if (!GetEntProp(iEntity, Prop_Send, "m_hasTankGlow")) return;

	//PrintToChatAll("tank hit %d", iEntity);

	int entRef = EntIndexToEntRef(iEntity);
	if (g_hTankPropsHitList.FindValue(entRef) == -1) 
	{
		g_hTankPropsHitList.Push(entRef);

		if(g_bCvar_tankPropsGlow)
			CreateTankPropGlow(iEntity);
		if(g_bCvar_tankPropsGlowSpec)
			CreateTankPropGlowSpectator(iEntity);
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
		DispatchKeyValue(entity, "disableshadows", "1");
		DispatchKeyValue(entity, "targetname", "propglow");
	}
	else
	{
		entity = CreateEntityByName("prop_glowing_object");
		if(entity < 0 ) return;
		DispatchKeyValue(entity, "model", sModelName);
		DispatchKeyValue(entity, "disableshadows", "1");
		DispatchKeyValue(entity, "targetname", "propglow");
		
		DispatchKeyValue(entity, "StartGlowing", "1");
		DispatchKeyValue(entity, "GlowForTeam", "3");
	}


	/* GlowForTeam =  -1:ALL  , 0:NONE , 1:SPECTATOR  , 2:SURVIVOR , 3:INFECTED */
	
	TeleportEntity(entity, vPos, vAng, NULL_VECTOR);
	DispatchSpawn(entity);
	SetEntProp(entity, Prop_Send, "m_CollisionGroup", 0);
	SetEntProp(entity, Prop_Send, "m_nSolidType", 0);

	g_iInfGlowRef[car] = EntIndexToEntRef(entity);

	//暴力法
	SDKHook(car, SDKHook_VPhysicsUpdatePost, TankThink);

	SetEntityRenderMode(car, RENDER_TRANSCOLOR);
	SetEntityRenderColor(car, 255, 0, 0, 50);

	if(g_iCvarColor[0] == -1 && g_iCvarColor[1] == -1 && g_iCvarColor[2] == -1) return;
	SetEntityRenderMode(entity, RENDER_TRANSCOLOR);
	SetEntityRenderColor (entity, g_iCvarColor[0], g_iCvarColor[1], g_iCvarColor[2], 255);

	/*
	//沒暴力法
	SetVariantString("!activator");
	AcceptEntityInput(entity, "SetParent", car); 

	SetEntityRenderFx(entity, RENDERFX_FADE_FAST);

	if(g_iCvarColor[0] == -1 && g_iCvarColor[1] == -1 && g_iCvarColor[2] == -1) return;
	SetEntityRenderMode(car, RENDER_TRANSCOLOR);
	SetEntityRenderColor (car, g_iCvarColor[0], g_iCvarColor[1], g_iCvarColor[2], 255);
	*/
}


void TankThink(int car)
{
	if (IsValidEntRef(g_iInfGlowRef[car]))
	{
		static float vPos[3];
		static float vAng[3];
		GetEntPropVector(car, Prop_Data, "m_vecOrigin", vPos);
		GetEntPropVector(car, Prop_Send, "m_angRotation", vAng);
		TeleportEntity(g_iInfGlowRef[car], vPos, vAng, NULL_VECTOR);
	}
	else
	{
		SDKUnhook(car, SDKHook_VPhysicsUpdatePost, TankThink);
	}
}

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
		DispatchKeyValue(entity, "disableshadows", "1");
		DispatchKeyValue(entity, "targetname", "propglow");
	}
	else
	{
		entity = CreateEntityByName("prop_glowing_object");
		DispatchKeyValue(entity, "model", sModelName);
		DispatchKeyValue(entity, "disableshadows", "1");
		DispatchKeyValue(entity, "targetname", "propglow");
		
		DispatchKeyValue(entity, "StartGlowing", "1");
		DispatchKeyValue(entity, "GlowForTeam", "1");
	}
	
	TeleportEntity(entity, vPos, vAng, NULL_VECTOR);
	DispatchSpawn(entity);
	
	SetEntProp(entity, Prop_Send, "m_CollisionGroup", 0);
	SetEntProp(entity, Prop_Send, "m_nSolidType", 0);

	g_iSpecGlowRef[car] = EntIndexToEntRef(entity);

	//暴力法
	SetEntityRenderFx(entity, RENDERFX_FADE_FAST);
	SDKHook(car, SDKHook_VPhysicsUpdatePost, SpecTankThink);

	/*
	//沒暴力法
	SetVariantString("!activator");
	AcceptEntityInput(entity, "SetParent", car); 
	SetEntityRenderFx(entity, RENDERFX_FADE_FAST);
	 */
}

void SpecTankThink(int car)
{
	if (IsValidEntRef(g_iSpecGlowRef[car]))
	{
		static float vPos[3];
		static float vAng[3];
		GetEntPropVector(car, Prop_Data, "m_vecOrigin", vPos);
		GetEntPropVector(car, Prop_Send, "m_angRotation", vAng);
		TeleportEntity(g_iSpecGlowRef[car], vPos, vAng, NULL_VECTOR);
	}
	else
	{
		SDKUnhook(car, SDKHook_VPhysicsUpdatePost, TankThink);
	}
}

Action TankPropsBeGone( Handle timer ) 
{
	if(g_bTankSpawned) return Plugin_Continue;

	UnhookTankProps();
	DHookRemoveEntityListener(ListenType_Created, PossibleTankPropCreated);

	return Plugin_Continue;
}

bool IsTankProp( int iEntity ) 
{
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

void HookTankProps() 
{
	int iEntity = MaxClients+1;
	int renderColor[4];
	static char sNumber[4];
	
	while ((iEntity = FindEntityByClassname(iEntity, "prop_physics*")) != -1) 
	{
		if (!IsValidEntity(iEntity)) continue;
		
		if (!IsTankProp(iEntity)) continue;
		
		SDKHook(iEntity, SDKHook_OnTakeDamagePost, PropDamagedPost);
		g_hTankPropsList.Push(EntIndexToEntRef(iEntity));

		GetEntityRenderColor(iEntity, renderColor[0], renderColor[1], renderColor[2], renderColor[3]);
		IntToString(iEntity, sNumber, sizeof(sNumber));
		g_smTankPropToRenderColor.SetArray(sNumber, renderColor, 4);

		SetEntityRenderMode(iEntity, RENDER_TRANSCOLOR);
		SetEntityRenderColor(iEntity, 255, 0, 0);
	}
	
	iEntity = MaxClients+1;

	while ((iEntity = FindEntityByClassname(iEntity, "prop_car_alarm*")) != -1) 
	{
		if (!IsValidEntity(iEntity)) continue;
		
		if (!IsTankProp(iEntity)) continue;

		SDKHook(iEntity, SDKHook_OnTakeDamagePost, PropDamagedPost);
		g_hTankPropsList.Push(EntIndexToEntRef(iEntity));
		
		GetEntityRenderColor(iEntity, renderColor[0], renderColor[1], renderColor[2], renderColor[3]);
		IntToString(iEntity, sNumber, sizeof(sNumber));
		g_smTankPropToRenderColor.SetArray(sNumber, renderColor, 4);

		SetEntityRenderMode(iEntity, RENDER_TRANSCOLOR);
		SetEntityRenderColor(iEntity, 255, 0, 0);
	}
}

void UnhookTankProps(bool bKillGlow = true, bool bRenderColor = true) 
{
	int entity, glow;
	int renderColor[4];
	static char sNumber[4];
	for ( int i = 0; i < GetArraySize(g_hTankPropsList); i++ ) 
	{
		entity = EntRefToEntIndex(g_hTankPropsList.Get(i));
		if(entity != INVALID_ENT_REFERENCE)
		{
			SDKUnhook(entity, SDKHook_OnTakeDamagePost, PropDamagedPost);
			IntToString(entity, sNumber, sizeof(sNumber));
			if(bRenderColor && g_smTankPropToRenderColor.GetArray(sNumber, renderColor, 4))
			{
				SetEntityRenderMode(entity, RENDER_TRANSCOLOR);
				SetEntityRenderColor(entity, renderColor[0], renderColor[1], renderColor[2], renderColor[3]);
			}
		}
	}

	if(bKillGlow)
	{
		g_bKillTankProp = true;
		for ( int i = 0; i < GetArraySize(g_hTankPropsHitList); i++ ) 
		{
			entity = EntRefToEntIndex(g_hTankPropsHitList.Get(i));
			if ( entity != INVALID_ENT_REFERENCE ) 
			{
				RemoveEntity(entity);
				glow = g_iInfGlowRef[entity];
				g_iInfGlowRef[entity] = 0;
				if(IsValidEntRef(glow))
					RemoveEntity(glow);

				glow = g_iSpecGlowRef[entity];
				g_iSpecGlowRef[entity] = 0;
				if(IsValidEntRef(glow))
					RemoveEntity(glow);
			}
		}
		g_bKillTankProp = false;
	}

	delete g_hTankPropsList;
	delete g_hTankPropsHitList;
	delete g_smTankPropToRenderColor;

	g_hTankPropsList = new ArrayList();
	g_hTankPropsHitList = new ArrayList();
	g_smTankPropToRenderColor = new StringMap();
}

//analogue public void OnEntityCreated(int iEntity, const char[] sClassName)
void PossibleTankPropCreated(int iEntity, const char[] sClassName)
{
	if (sClassName[0] != 'p') {
		return;
	}
	
	if (strncmp(sClassName, "prop_physics", 12, false) != 0) { // Hooks c11m4_terminal World Sphere
		return;
	}

	// Use SpawnPost to just push it into the Array right away.
	// These entities get spawned after the Tank has punched them, so doing anything here will not work smoothly.
	SDKHook(iEntity, SDKHook_SpawnPost, Hook_PropSpawned);
}

void Hook_PropSpawned(int iEntity)
{
	if (iEntity <= MaxClients || !IsValidEntity(iEntity)) {
		return;
	}

	int iRef = EntIndexToEntRef(iEntity);
	int renderColor[4];
	if (g_hTankPropsList.FindValue(iRef) == -1) 
	{
		char sModelName[PLATFORM_MAX_PATH];
		GetEntPropString(iEntity, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName));

		if (StrContains(sModelName, "atlas_break_ball") != -1 || StrContains(sModelName, "forklift_brokenlift.mdl") != -1) {
			PushArrayCell(g_hTankPropsList, iRef);
			PushArrayCell(g_hTankPropsHitList, iRef);

			GetEntityRenderColor(iEntity, renderColor[0], renderColor[1], renderColor[2], renderColor[3]);
			static char sNumber[4];
			IntToString(iEntity, sNumber, sizeof(sNumber));
			g_smTankPropToRenderColor.SetArray(sNumber, renderColor, 4);

			SetEntityRenderMode(iEntity, RENDER_TRANSCOLOR);
			SetEntityRenderColor(iEntity, 255, 0, 0);

			if(g_bCvar_tankPropsGlow)
				CreateTankPropGlow(iEntity);
			if(g_bCvar_tankPropsGlowSpec)
				CreateTankPropGlowSpectator(iEntity);
		} 
		else if (StrContains(sModelName, "forklift_brokenfork.mdl") != -1) 
		{
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
    || !IsClientInGame(client)
    || GetClientTeam(client) != 3
    || !IsPlayerAlive(client) ) {
        return false;
    }
    
    if ( GetEntProp(client, Prop_Send, "m_zombieClass") == ZC_TANK ) {
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

bool IsAliveTank(int iClient)
{
	return (IsClientInGame(iClient) && GetClientTeam(iClient) == 3 && IsPlayerAlive(iClient) && GetEntProp(iClient, Prop_Send, "m_zombieClass") == ZC_TANK);
}

bool IsValidAliveTank(int iClient)
{
	return (iClient > 0 && iClient <= MaxClients && IsAliveTank(iClient));
}

bool IsValidEntityIndex(int entity)
{
    return (MaxClients+1 <= entity <= GetMaxEntities());
}