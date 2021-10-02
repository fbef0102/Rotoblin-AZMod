#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

new i_Ent[2048] = -1;
new i_EntSpec[2048]= -1;
new Float:WitchvPos[2048][3];
new Float:WitchvAvg[2048][3];
new bool:WitchWokeup[2048];
new bool:WitchKilled[2048];

#define InfoPlugin "\x04L4D1 WitchGlow creado por\x03:\nIDgarena: thejuaneco | IDsteam: thejuaneco, assist: Harry Potter"

new bool:g_EndMap;
#define NULL					-1

public Plugin:myinfo =
{
	name = "L4D1 Witch Glow + fixed being pushing away!",
	author = "JNC & Harry Potter",
	description = "Set glow on witch only infected + Prevent common infected from pushing witch away when witch not startled yet",
	version = "1.5",
	url = "https://github.com/fbef0102/L4D1-Competitive-Plugins/tree/master/l4d_witchglow"
};

public OnPluginStart()
{
	HookEvent("witch_spawn", WitchSpawn_Event);
	HookEvent("witch_killed", Event_WitchKilled);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("witch_harasser_set", OnWitchWokeup);
} 


public Action:Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_EndMap = true;
}


public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_EndMap = false;
}

public WitchSpawn_Event(Handle:event, const String:name[], bool:dontBroadcast)
{	
	g_EndMap = false;
	new WitchID = GetEventInt(event, "witchid");
	CreateTimer(1.0,coldDown,WitchID,TIMER_FLAG_NO_MAPCHANGE);
}

public Action:coldDown(Handle:timer, any:WitchID)
{
	if (WitchID == NULL || !IsValidEntity(WitchID)) return;
	
	WitchWokeup[WitchID] = false;
	WitchKilled[WitchID] = false;
	CreateWitchPropSpawner(WitchID);
	
	for( new i = 1; i <= MaxClients; i++ )
	{
		if (IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i) &&GetClientTeam(i)==1)
		{
			CreateWitchPropSpawnerSpectator(WitchID);
			break;
		}
	}
}

CreateWitchPropSpawner(WitchID)
{
	GetEntPropVector(WitchID, Prop_Data, "m_vecOrigin", WitchvPos[WitchID]);
	GetEntPropVector(WitchID, Prop_Send, "m_angRotation", WitchvAvg[WitchID]);
	
	i_Ent[WitchID] = CreateEntityByName("prop_glowing_object");
	
	if (i_Ent[WitchID] != 1) {
	
		DispatchKeyValue(i_Ent[WitchID], "model", "models/infected/witch.mdl");
		DispatchKeyValue(i_Ent[WitchID], "StartGlowing", "1");
		
		DispatchKeyValue(i_Ent[WitchID], "DefaultAnim", "Idle_Sitting");
		DispatchKeyValue(i_Ent[WitchID], "fadescale", "1");
		DispatchKeyValue(i_Ent[WitchID], "fademindist", "3000");
		DispatchKeyValue(i_Ent[WitchID], "fademaxdist", "3200");
		
		DispatchKeyValue(i_Ent[WitchID], "GlowForTeam", "3");

		/* GlowForTeam =  -1:ALL  , 0:NONE , 1:SPECTATOR  , 2:SURVIVOR , 3:INFECTED */
		
		TeleportEntity(i_Ent[WitchID], WitchvPos[WitchID], WitchvAvg[WitchID], NULL_VECTOR);
		DispatchSpawn(i_Ent[WitchID]);
		SetEntityRenderFx(i_Ent[WitchID], RENDERFX_FADE_FAST);
		
		ActivateEntity(i_Ent[WitchID]);
		SetVariantString("!activator");
		AcceptEntityInput(i_Ent[WitchID], "SetParent", WitchID);
		SetVariantString("!activator");
		AcceptEntityInput(i_Ent[WitchID], "SetAttached", WitchID);

		SetEntPropFloat(i_Ent[WitchID], Prop_Send, "m_flPlaybackRate", 1.0); 
		SDKHook(WitchID, SDKHook_ThinkPost, WitchThink);
	}
}

CreateWitchPropSpawnerSpectator(WitchID)
{
	i_EntSpec[WitchID] = CreateEntityByName("prop_glowing_object");
	
	DispatchKeyValue(i_EntSpec[WitchID], "model", "models/infected/witch.mdl");
	DispatchKeyValue(i_EntSpec[WitchID], "StartGlowing", "1");
	DispatchKeyValue(i_EntSpec[WitchID], "StartDisabled", "1");
	DispatchKeyValue(i_EntSpec[WitchID], "targetname", "witchglow");
	
	DispatchKeyValue(i_EntSpec[WitchID], "GlowForTeam", "1");

	// GlowForTeam =  -1:ALL  , 0:NONE , 1:SPECTATOR  , 2:SURVIVOR , 3:INFECTED 
	
	DispatchKeyValue(i_EntSpec[WitchID], "fadescale", "1");
	DispatchKeyValue(i_EntSpec[WitchID], "fademindist", "3000");
	DispatchKeyValue(i_EntSpec[WitchID], "fademaxdist", "3200");
	
	TeleportEntity(i_EntSpec[WitchID], WitchvPos[WitchID], WitchvAvg[WitchID], NULL_VECTOR);
	DispatchSpawn(i_EntSpec[WitchID]);
	SetEntityRenderFx(i_EntSpec[WitchID], RENDERFX_FADE_FAST);
	
	DispatchKeyValueVector(i_EntSpec[WitchID], "origin", WitchvPos[WitchID]);
	DispatchKeyValueVector(i_EntSpec[WitchID], "angles", WitchvAvg[WitchID]);
	
	SetVariantString("!activator");
	AcceptEntityInput(i_EntSpec[WitchID], "SetParent", WitchID);
	
	SetEntPropFloat(i_EntSpec[WitchID], Prop_Send, "m_flPlaybackRate", 1.0); 
	SDKHook(WitchID, SDKHook_ThinkPost, SpecWitchThink);
}

public WitchThink(entity)
{
	if (!IsValidEntity(entity)||g_EndMap || WitchKilled[entity])
	{
		if (IsValidEdict(i_Ent[entity]))
		{
			AcceptEntityInput(i_Ent[entity],"Kill");
		}
		i_Ent[entity] = -1;
		SDKUnhook(entity, SDKHook_ThinkPost, WitchThink);
		return;
	}

	if (IsValidEdict(i_Ent[entity]))
	{
		decl String:ModelName[128];
		GetEntPropString(entity, Prop_Data, "m_ModelName", ModelName, sizeof(ModelName));
		if(!StrEqual(ModelName, "models/infected/witch.mdl", false))
		{
			AcceptEntityInput(i_Ent[entity],"Kill");
			i_Ent[entity] = -1;
			SDKUnhook(entity, SDKHook_ThinkPost, WitchThink);
			return;
		}
		new nSequence = GetEntProp(entity, Prop_Send, "m_nSequence");
		SetEntProp(i_Ent[entity], Prop_Send, "m_nSequence", nSequence);
		
		if(nSequence == 3 || nSequence == 6) //witch lost target
			WitchWokeup[entity] = true;
			
		if(!WitchWokeup[entity])
			TeleportEntity(entity, WitchvPos[entity], WitchvAvg[entity], NULL_VECTOR);
	}
}

public SpecWitchThink(entity)
{
	if (!IsValidEntity(entity)||g_EndMap||WitchKilled[entity])
	{
		if (IsValidEdict(i_EntSpec[entity]))
		{
			AcceptEntityInput(i_EntSpec[entity],"Kill");
		}
		i_EntSpec[entity] = -1;
		SDKUnhook(entity, SDKHook_ThinkPost, SpecWitchThink);
		return;
	}
	
	if (IsValidEdict(i_EntSpec[entity]))
	{
		decl String:ModelName[128];
		GetEntPropString(entity, Prop_Data, "m_ModelName", ModelName, sizeof(ModelName));
		if(!StrEqual(ModelName, "models/infected/witch.mdl", false))
		{
			AcceptEntityInput(i_EntSpec[entity],"Kill");
			i_EntSpec[entity] = -1;
			SDKUnhook(entity, SDKHook_ThinkPost, SpecWitchThink);
			return;
		}

		SetEntProp(i_EntSpec[entity], Prop_Send, "m_nSequence", GetEntProp(entity, Prop_Send, "m_nSequence"));
	}
}

public Event_WitchKilled(Handle:event, const String:name[], bool:dontBroadcast)
{
	new WitchID = GetEventInt(event, "witchid");
	if(WitchID != NULL)
	{
		WitchKilled[WitchID] = true;
	}
}

public OnMapEnd()
{
	g_EndMap = true;
}

public OnMapStart()
{
	g_EndMap = false;
}


public Action:OnWitchWokeup(Handle:event, const String:name[], bool:dontBroadcast)
{
	new WitchID = GetEventInt(event, "witchid");
	if(WitchID != NULL)
	{
		/*
		WitchKilled[WitchID] = true;
		*/
		WitchWokeup[WitchID] = true;
	}
}
