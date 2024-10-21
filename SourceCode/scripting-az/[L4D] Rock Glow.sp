#pragma semicolon 1
#pragma newdecls required

#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>

public Plugin myinfo = 
{
	name = "[L4D] Rock Glow",
	author = "Joshe Gatito, l4d1 modify by Harry",
	description = "tank rock glow for spectator and infected",
	version = "1.3-2024/10/19",
	url = "https://github.com/JosheGatitoSpartankii09"
};

public void L4D_TankRock_OnRelease_Post(int tank, int rock, const float vecPos[3], const float vecAng[3], const float vecVel[3], const float vecRot[3])
{
	if(tank < 0 || !IsValidEntity(rock))
	{
		return;
	}

	RequestFrame(OnNextFrame, EntIndexToEntRef(rock));
}

void OnNextFrame(int entity)
{
	entity = EntRefToEntIndex(entity);
	if(entity == INVALID_ENT_REFERENCE) return;

	GlowForInfected(entity);
	GlowForSpectator(entity);
}

void GlowForInfected(int entity)
{
	int GlowRock = -1;
	float vPos[3];
	float vAng[3];
		
	GetEntPropVector(entity, Prop_Data, "m_vecOrigin", vPos);
	GetEntPropVector(entity, Prop_Send, "m_angRotation", vAng);
	
	GlowRock = CreateEntityByName("prop_glowing_object"); 
	if( GlowRock == -1)
	{
		return;
	}

	char sModel[64];
	GetEntPropString(entity, Prop_Data, "m_ModelName", sModel, sizeof(sModel));
	DispatchKeyValue(GlowRock, "model", sModel);

	SetEntityRenderFx(GlowRock, RENDERFX_FADE_FAST);
	DispatchKeyValue(GlowRock, "GlowForTeam", "3");
	DispatchSpawn(GlowRock);

	TeleportEntity(GlowRock, vPos, vAng, NULL_VECTOR);

	SetVariantString("!activator");
	AcceptEntityInput(GlowRock, "SetParent", entity);
	AcceptEntityInput(GlowRock, "StartGlowing");
}

void GlowForSpectator(int entity)
{
	int GlowRock = -1;
	float vPos[3];
	float vAng[3];
		
	GetEntPropVector(entity, Prop_Data, "m_vecOrigin", vPos);
	GetEntPropVector(entity, Prop_Send, "m_angRotation", vAng);
	
	GlowRock = CreateEntityByName("prop_glowing_object"); 
	if( GlowRock == -1)
	{
		return;
	}
	
	char sModel[64];
	GetEntPropString(entity, Prop_Data, "m_ModelName", sModel, sizeof(sModel));
	DispatchKeyValue(GlowRock, "model", sModel);

	SetEntityRenderFx(GlowRock, RENDERFX_FADE_FAST);
	DispatchKeyValue(GlowRock, "GlowForTeam", "1");
	DispatchSpawn(GlowRock);

	TeleportEntity(GlowRock, vPos, vAng, NULL_VECTOR);
	
	SetVariantString("!activator");
	AcceptEntityInput(GlowRock, "SetParent", entity);
	AcceptEntityInput(GlowRock, "StartGlowing");
}