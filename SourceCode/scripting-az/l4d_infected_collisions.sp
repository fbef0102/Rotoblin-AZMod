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
	description = "Common infected and witch can phase through pulled or pounced survivors",
	version = "1.0-2026/10/6",
	url = "https://github.com/jensewe"
}

Handle g_call_GetRefEHandle;
int m_pounceAttacker,
	m_tongueOwner;

public void OnPluginStart()
{
	GameDataWrapper gd = new GameDataWrapper("l4d_infected_collisions");

	SDKCallParamsWrapper params[] = {
		{SDKType_PlainOldData, SDKPass_Plain},
	};
	g_call_GetRefEHandle = gd.CreateSDKCallOrFail(SDKCall_Raw, SDKConf_Virtual, "IHandleEntity::GetRefEHandle", _, 0, true, params[0]);

	delete gd.CreateDetourOrFail("l4d_infected_collisions::ZombieBotCollisionTraceFilter::ShouldHitEntity", DTR_ShouldHitEntity);
	delete gd;

	m_pounceAttacker = FindSendPropInfo("CTerrorPlayer", "m_pounceAttacker");
	m_tongueOwner = FindSendPropInfo("CTerrorPlayer", "m_tongueOwner");
}

MRESReturn DTR_ShouldHitEntity(Address pThis, DHookReturn hReturn, DHookParam hParams)
{	
	int touch = EntityFromEntityHandle(hParams.Get(1));

	// PrintToChatAll("ref %08X touch %d", ref, touch);
	if (touch == -1)
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

int EntityFromEntityHandle(Address pHandleEntity)
{
	if (pHandleEntity == Address_Null)
		return -1;

	Address ehandle = SDKCall(g_call_GetRefEHandle, pHandleEntity);
	//int ref = LoadFromAddress(ehandle, NumberType_Int32) | 0x80000000;
	//return EntRefToEntIndex(ref);
	return LoadEntityFromHandleAddress(ehandle);
}