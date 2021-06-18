#pragma semicolon 1
#pragma newdecls required

#include <sdktools>
#include <sdkhooks>

#define ROCKET "models/props_debris/concrete_chunk01a.mdl"

public Plugin myinfo = 
{
	name = "[L4D] Rock Glow",
	author = "Joshe Gatito, l4d1 modify by Harry",
	description = "tank rock glow for spectator and infected",
	version = "1.2",
	url = "https://github.com/JosheGatitoSpartankii09"
};

public void OnEntityCreated (int entity, const char[] classname)
{	
	if (strcmp(classname, "tank_rock") == 0)
		SDKHook(entity, SDKHook_Spawn, SpawnThink);
}

public void SpawnThink(int entity)
{
	RequestFrame(OnNextFrame, EntIndexToEntRef(entity));
	RequestFrame(OnNextFrameSpec, EntIndexToEntRef(entity));
}

public void OnNextFrame(int entity)
{
	int GlowRock = -1;
	float vPos[3];
	float vAng[3];
		
	GetEntPropVector(entity, Prop_Data, "m_vecOrigin", vPos);
	GetEntPropVector(entity, Prop_Send, "m_angRotation", vAng);
	
	GlowRock = CreateEntityByName("prop_glowing_object"); 
	if( GlowRock == -1)
	{
		LogError("Failed to create 'prop_glowing_object'");
		return;
	}
	
	DispatchKeyValue(GlowRock, "model", ROCKET);
	SetEntityRenderFx(GlowRock, RENDERFX_FADE_FAST);
	DispatchKeyValue(GlowRock, "GlowForTeam", "3");
	
	SetVariantString("!activator");
	AcceptEntityInput(GlowRock, "SetParent", entity);
	DispatchSpawn(GlowRock);
	AcceptEntityInput(GlowRock, "StartGlowing");
		
	TeleportEntity(GlowRock, vPos, vAng, NULL_VECTOR);
}

public void OnNextFrameSpec(int entity)
{
	int GlowRock = -1;
	float vPos[3];
	float vAng[3];
		
	GetEntPropVector(entity, Prop_Data, "m_vecOrigin", vPos);
	GetEntPropVector(entity, Prop_Send, "m_angRotation", vAng);
	
	GlowRock = CreateEntityByName("prop_glowing_object"); 
	if( GlowRock == -1)
	{
		LogError("Failed to create 'prop_glowing_object'");
		return;
	}
	
	DispatchKeyValue(GlowRock, "model", ROCKET);
	SetEntityRenderFx(GlowRock, RENDERFX_FADE_FAST);
	DispatchKeyValue(GlowRock, "GlowForTeam", "1");
	/* GlowForTeam =  -1:ALL  , 0:NONE , 1:SPECTATOR  , 2:SURVIVOR , 3:INFECTED */
	
	SetVariantString("!activator");
	AcceptEntityInput(GlowRock, "SetParent", entity);
	DispatchSpawn(GlowRock);
	AcceptEntityInput(GlowRock, "StartGlowing");
		
	TeleportEntity(GlowRock, vPos, vAng, NULL_VECTOR);
}