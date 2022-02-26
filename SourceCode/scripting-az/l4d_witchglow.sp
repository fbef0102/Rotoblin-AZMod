#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define MAX_ENTITY 2048

int g_iModelIndex[MAX_ENTITY +1];
int g_iModelIndex2[MAX_ENTITY +1];
float WitchvPos[MAX_ENTITY +1][3];
float WitchvAvg[MAX_ENTITY +1][3];
bool WitchWokeup[MAX_ENTITY +1];

#define InfoPlugin "\x04L4D1 WitchGlow creado por\x03:\nIDgarena: thejuaneco | IDsteam: thejuaneco, assist: Harry Potter"

public Plugin myinfo =
{
	name = "L4D1 Witch Glow + fixed being pushing away!",
	author = "JNC & Harry Potter",
	description = "Set glow on witch only infected + Prevent common infected from pushing witch away when witch not startled yet",
	version = "1.6",
	url = "https://forums.alliedmods.net/showthread.php?p=2656161"
};

public void OnPluginStart()
{
	HookEvent("witch_spawn", WitchSpawn_Event);
	HookEvent("witch_killed", Event_WitchKilled);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("map_transition", Event_RoundEnd, EventHookMode_PostNoCopy); //戰役過關到下一關的時候 (之後沒有觸發round_end)
	HookEvent("mission_lost", Event_RoundEnd, EventHookMode_PostNoCopy); //戰役滅團重來該關卡的時候 (之後有觸發round_end)
	HookEvent("finale_vehicle_leaving", Event_RoundEnd, EventHookMode_PostNoCopy); //救援載具離開之時  (之後沒有觸發round_end)
	HookEvent("witch_harasser_set", OnWitchWokeup);
}

public void OnPluginEnd()
{
	RemoveAllWitchGlow();
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	RemoveAllWitchGlow();
}

public void WitchSpawn_Event(Event event, const char[] name, bool dontBroadcast)
{	
	int witch = GetEventInt(event, "witchid");

	CreateWitchGlow(witch);
	CreateWitchGlowForSpectator(witch);

	WitchWokeup[witch] = false;
}

public void Event_WitchKilled(Event event, const char[] name, bool dontBroadcast)
{
	int witch = GetEventInt(event, "witchid");
	RemoveWitchGlow(witch);
	RemoveWitchSpecGlow(witch);
	SDKUnhook(witch, SDKHook_ThinkPost, WitchThink);
	SDKUnhook(witch, SDKHook_ThinkPost, WitchSpecThink);
}

public void OnWitchWokeup(Event event, const char[] name, bool dontBroadcast)
{
	int witch = GetEventInt(event, "witchid");

	WitchWokeup[witch] = true;
}

void CreateWitchGlow(int witch)
{
	if (!IsValidEntity(witch)) return;

	GetEntPropVector(witch, Prop_Data, "m_vecOrigin", WitchvPos[witch]);
	GetEntPropVector(witch, Prop_Send, "m_angRotation", WitchvAvg[witch]);
	
	int entity = CreateEntityByName("prop_glowing_object");
	
	if (entity <= 0)  return;

	//just in case
	RemoveWitchGlow(witch);

	static char sModelName[64];
	GetEntPropString(witch, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName));
	DispatchKeyValue(entity, "model", sModelName);
	DispatchKeyValue(entity, "StartGlowing", "1");

	DispatchKeyValue(entity, "fadescale", "1");
	DispatchKeyValue(entity, "fademindist", "3000");
	DispatchKeyValue(entity, "fademaxdist", "3200");
	
	DispatchKeyValue(entity, "GlowForTeam", "3");

	/* GlowForTeam =  -1:ALL  , 0:NONE , 1:SPECTATOR  , 2:SURVIVOR , 3:INFECTED */
	
	TeleportEntity(entity, WitchvPos[witch], WitchvAvg[witch], NULL_VECTOR);
	DispatchSpawn(entity);
	SetEntityRenderMode( entity, RENDER_TRANSCOLOR );
	SetEntityRenderColor (entity, 0, 0, 0, 0 );
	
	SetVariantString("!activator");
	AcceptEntityInput(entity, "SetParent", witch);
	SetEntPropFloat(entity, Prop_Send, "m_flPlaybackRate" ,1.0); 

	g_iModelIndex[witch] = EntIndexToEntRef(entity);

	SDKHook(witch, SDKHook_ThinkPost, WitchThink);
	SDKHook(entity, SDKHook_SetTransmit, Hook_SetTransmit);
}

public void WitchThink(int witch)
{
	int entity = g_iModelIndex[witch];
	int nSequence = GetEntProp(witch, Prop_Send, "m_nSequence");
	if(IsValidEntRef(entity))
	{
		SetEntProp(entity, Prop_Send, "m_nSequence", nSequence);
	}

	if(!WitchWokeup[witch])
	{
		if(nSequence == 3 || nSequence == 6  //witch lost target
			|| nSequence == 31) //witch on fire
		{
			WitchWokeup[witch] = true;
			return;
		}

		TeleportEntity(witch, WitchvPos[witch], WitchvAvg[witch], NULL_VECTOR);
	}
}

void CreateWitchGlowForSpectator(int witch)
{
	if (!IsValidEntity(witch)) return;

	int entity = CreateEntityByName("prop_glowing_object");

	if (entity <= 0)  return;
	
	//just in case
	RemoveWitchSpecGlow(witch);

	static char sModelName[64];
	GetEntPropString(witch, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName));
	DispatchKeyValue(entity, "model", sModelName);
	DispatchKeyValue(entity, "StartGlowing", "1");

	DispatchKeyValue(entity, "fadescale", "1");
	DispatchKeyValue(entity, "fademindist", "3000");
	DispatchKeyValue(entity, "fademaxdist", "3200");
	
	DispatchKeyValue(entity, "GlowForTeam", "1");

	/* GlowForTeam =  -1:ALL  , 0:NONE , 1:SPECTATOR  , 2:SURVIVOR , 3:INFECTED */
	
	TeleportEntity(entity, WitchvPos[witch], WitchvAvg[witch], NULL_VECTOR);
	DispatchSpawn(entity);
	SetEntityRenderMode( entity, RENDER_TRANSCOLOR );
	SetEntityRenderColor (entity, 0, 0, 0, 0 );
	
	SetVariantString("!activator");
	AcceptEntityInput(entity, "SetParent", witch);
	SetEntPropFloat(entity, Prop_Send, "m_flPlaybackRate", 1.0); 

	g_iModelIndex2[witch] = EntIndexToEntRef(entity);

	SDKHook(witch, SDKHook_ThinkPost, WitchSpecThink);
	SDKHook(entity, SDKHook_SetTransmit, Hook_SetTransmit);
}

public void WitchSpecThink(int witch)
{
	int entity = g_iModelIndex2[witch];
	int nSequence = GetEntProp(witch, Prop_Send, "m_nSequence");
	if(IsValidEntRef(entity))
	{
		SetEntProp(entity, Prop_Send, "m_nSequence", nSequence);
	}
	else
	{
		SDKUnhook(witch, SDKHook_ThinkPost, WitchSpecThink);
	}
}


public Action Hook_SetTransmit(int entity, int client)
{
	return Plugin_Handled;
}

void RemoveAllWitchGlow()
{
	int witch = -1;
	while ( ((witch = FindEntityByClassname(witch, "witch")) != -1) )
	{
		if(!IsValidEntity(witch)) continue;

		RemoveWitchGlow(witch);
		RemoveWitchSpecGlow(witch);
		SDKUnhook(witch, SDKHook_ThinkPost, WitchThink);
		SDKUnhook(witch, SDKHook_ThinkPost, WitchSpecThink);
	}
}

void RemoveWitchGlow(int witch)
{
	int entity = g_iModelIndex[witch];
	g_iModelIndex[witch] = 0;

	if( IsValidEntRef(entity) )
		AcceptEntityInput(entity, "kill");
}

void RemoveWitchSpecGlow(int witch)
{
	int entity = g_iModelIndex2[witch];
	g_iModelIndex2[witch] = 0;

	if( IsValidEntRef(entity) )
		AcceptEntityInput(entity, "kill");
}

bool IsValidEntRef(int entity)
{
	if( entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE)
		return true;
	return false;
}

public void OnEntityDestroyed(int entity)
{
	if (!IsValidEntityIndex(entity))
		return;

	RemoveWitchGlow(entity);
	RemoveWitchSpecGlow(entity);
}

bool IsValidEntityIndex(int entity)
{
	return (MaxClients + 1 <= entity <= GetMaxEntities());
}
