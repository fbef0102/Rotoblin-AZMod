#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <dhooks>
#include <collisionhook>
#include <sdktools>
#include <@Forgetest/gamedatawrapper>

public Plugin myinfo = 
{
	name = "[L4D1/L4D2] ZombieBotCollisionTraceFilter ignore pinned survivor",
	author = "Forgetest",
	description = "Common infected can phase through pulled or pounced survivors, while witches can't",
	version = "1.1-2026/10/7",
	url = "https://github.com/jensewe"
}

#define MAXENTITIES                   2048

Handle g_call_GetRefEHandle,
	g_call_ILocomotion_GetBot,
	g_call_INextBot_GetEntity;
int m_pounceAttacker,
	m_tongueOwner;

bool 
	g_bIsCommonInfected[MAXENTITIES+1];

public void OnPluginStart()
{
	GameDataWrapper gd = new GameDataWrapper("l4d_infected_collisions");

	SDKCallParamsWrapper params[] = {
		{SDKType_PlainOldData, SDKPass_Plain},
		{SDKType_CBaseEntity, SDKPass_Pointer},
	};
	g_call_GetRefEHandle = gd.CreateSDKCallOrFail(SDKCall_Raw, SDKConf_Virtual, "IHandleEntity::GetRefEHandle", _, 0, true, params[0]);
	g_call_ILocomotion_GetBot = gd.CreateSDKCallOrFail(SDKCall_Raw, SDKConf_Virtual, "INextBotComponent::GetBot", _, 0, true, params[0]);
	g_call_INextBot_GetEntity = gd.CreateSDKCallOrFail(SDKCall_Raw, SDKConf_Virtual, "INextBot::GetEntity", _, 0, true, params[1]);

	delete gd.CreateDetourOrFail("l4d_infected_collisions::ZombieBotCollisionTraceFilter::ShouldHitEntity", DTR_ShouldHitEntity);
	delete gd.CreateDetourOrFail("l4d_infected_collisions::ZombieBotLocomotion::DetectCollision", DTR_DetectCollision, DTR_DetectCollision_Post);
	delete gd;

	m_pounceAttacker = FindSendPropInfo("CTerrorPlayer", "m_pounceAttacker");
	m_tongueOwner = FindSendPropInfo("CTerrorPlayer", "m_tongueOwner");
}

int g_iCollideInfected = -1;

MRESReturn DTR_DetectCollision(Address pLocomotion, DHookReturn hReturn, DHookParam hParams)
{
    Address pBot = SDKCall(g_call_ILocomotion_GetBot, pLocomotion);
    g_iCollideInfected = SDKCall(g_call_INextBot_GetEntity, pBot);
    return MRES_Ignored;
}

MRESReturn DTR_DetectCollision_Post(Address pThis, DHookReturn hReturn, DHookParam hParams)
{
    g_iCollideInfected = -1;
    return MRES_Ignored;
}

MRESReturn DTR_ShouldHitEntity(Address pThis, DHookReturn hReturn, DHookParam hParams)
{	
	if (g_iCollideInfected == -1 || g_bIsCommonInfected[g_iCollideInfected] == false)
		return MRES_Ignored;

	int touch = EntityFromEntityHandle(hParams.Get(1));

	if (touch == -1)
		return MRES_Ignored;

	if (g_iCollideInfected == touch)
		return MRES_Ignored;

	if (touch > 0 && touch <= MaxClients && IsClientInGame(touch) && GetClientTeam(touch) == 2)
	{
		if (GetEntDataEnt2(touch, m_pounceAttacker) != -1
			|| GetEntDataEnt2(touch, m_tongueOwner) != -1)
		{
			//PrintToChatAll("ignore: %d", touch);
			hReturn.Value = false;
			return MRES_Override;
		}
	}
	
	return MRES_Ignored;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (!IsValidEntityIndex(entity))
		return;

	g_bIsCommonInfected[entity] = false;
	if (classname[0] == 'i' && !strcmp(classname, "infected", false))
	{
		g_bIsCommonInfected[entity] = true;
	}
}


int EntityFromEntityHandle(Address pHandleEntity)
{
	if (pHandleEntity == Address_Null)
		return -1;

	Address ehandle = SDKCall(g_call_GetRefEHandle, pHandleEntity);
	//int ref = LoadFromAddress(ehandle, NumberType_Int32) | 0x80000000;
	//return EntRefToEntIndex(ref);
	return LoadEntityFromHandleAddress(ehandle);
}

bool IsValidEntityIndex(int entity)
{
	return (MaxClients+1 <= entity <= GetMaxEntities());
}