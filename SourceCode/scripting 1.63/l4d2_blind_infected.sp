#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#undef REQUIRE_PLUGIN
#include <l4d_lib>

#define SURVIVOR_TEAM 2
#define INFECTED_TEAM 3
#define ENT_CHECK_INTERVAL 2.0
#define TRACE_TOLERANCE 75.0

public Plugin:myinfo =
{
	name = "[L4D & L4D2] Blind Infected",
	author = "CanadaRox, ProdigySim, raziEiL [disawar1],L4D1 port by Harry",
	description = "Hides all weapons and iteams from the infected team or dead survivor until they are (possibly) visible to one of the alive survivors to prevent SI scouting the map",
	version = "1.0",
	url = "https://github.com/CanadaRox/sourcemod-plugins/tree/master/blind_infected_l4d2"
};

enum EntInfo
{
	iEntity,
	bool:hasBeenSeen
}

new Handle:hBlockedEntities;

public OnPluginStart()
{
	HookEvent("round_start", RoundStart_Event, EventHookMode_PostNoCopy);

	hBlockedEntities = CreateArray(_:EntInfo);

	CreateTimer(ENT_CHECK_INTERVAL, EntCheck_Timer, _, TIMER_REPEAT);
}

public Action:EntCheck_Timer(Handle:timer)
{
	new size = GetArraySize(hBlockedEntities);
	decl currentEnt[EntInfo], String:sWeapClass[64];

	for (new i; i < size; i++)
	{
		GetArrayArray(hBlockedEntities, i, currentEnt[0]);
		if (currentEnt[iEntity] != INVALID_ENT_REFERENCE && IsValidEntity(currentEnt[iEntity])){

			GetEntityClassname(currentEnt[iEntity], sWeapClass, 64);
			if (IsWeaponClass(sWeapClass)){

				if (!currentEnt[hasBeenSeen] && IsVisibleToSurvivors(currentEnt[iEntity]))
				{
					currentEnt[hasBeenSeen] = true;
					SetArrayArray(hBlockedEntities, i, currentEnt[0]);
				}
			}
			else {

				currentEnt[iEntity] = -1;
				SetArrayArray(hBlockedEntities, i, currentEnt[0]);
			}
		}
	}
}

public RoundStart_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	ClearArray(hBlockedEntities);
	CreateTimer(1.2, RoundStartDelay_Timer);
}

public Action:RoundStartDelay_Timer(Handle:timer)
{
	decl bhTemp[EntInfo], String:sWeapClass[64];
	new psychonic = GetEntityCount();

	for (new i = MaxClients; i < psychonic; i++)
	{
		if (i == INVALID_ENT_REFERENCE || !IsValidEntity(i)) continue;

		GetEntityClassname(i, sWeapClass, 64);
		if (IsWeaponClass(sWeapClass)||IsItem(sWeapClass)){

			SDKHook(i, SDKHook_SetTransmit, OnTransmit);
			bhTemp[iEntity] = i;
			bhTemp[hasBeenSeen] = false;
			PushArrayArray(hBlockedEntities, bhTemp[0]);
		}
	}
}

public Action:OnTransmit(entity, client)
{
	//特感隊伍或是死掉的人類就隱藏物品
	if ((GetClientTeam(client) != INFECTED_TEAM)&&(GetClientTeam(client) !=SURVIVOR_TEAM || IsPlayerAlive(client)) ) return Plugin_Continue;

	new size = GetArraySize(hBlockedEntities);
	decl currentEnt[EntInfo];

	for (new i; i < size; i++)
	{
		GetArrayArray(hBlockedEntities, i, currentEnt[0]);
		if (currentEnt[iEntity] == INVALID_ENT_REFERENCE || !IsValidEntity(currentEnt[iEntity])) continue;

		if (entity == currentEnt[iEntity])
		{
			if (currentEnt[hasBeenSeen]) return Plugin_Continue;
			else return Plugin_Handled;
		}
	}

	return Plugin_Continue;
}

// from http://code.google.com/p/srsmod/source/browse/src/scripting/srs.despawninfected.sp
stock bool:IsVisibleToSurvivors(entity)
{
	new iSurv;

	for (new i = 1; i < MaxClients && iSurv < 4; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == SURVIVOR_TEAM)
		{
			iSurv++
			if (IsPlayerAlive(i) && IsVisibleTo(i, entity))
			{
				return true;
			}
		}
	}

	return false;
}

stock bool:IsVisibleTo(client, entity) // check an entity for being visible to a client
{
	decl Float:vAngles[3], Float:vOrigin[3], Float:vEnt[3], Float:vLookAt[3];

	GetClientEyePosition(client,vOrigin); // get both player and zombie position

	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vEnt);

	MakeVectorFromPoints(vOrigin, vEnt, vLookAt); // compute vector from player to zombie

	GetVectorAngles(vLookAt, vAngles); // get angles from vector for trace

	// execute Trace
	new Handle:trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceFilter);

	new bool:isVisible = false;
	if (TR_DidHit(trace))
	{
		decl Float:vStart[3];
		TR_GetEndPosition(vStart, trace); // retrieve our trace endpoint

		if ((GetVectorDistance(vOrigin, vStart, false) + TRACE_TOLERANCE) >= GetVectorDistance(vOrigin, vEnt))
		{
			isVisible = true; // if trace ray lenght plus tolerance equal or bigger absolute distance, you hit the targeted zombie
		}
	}
	else
	{
		//Debug_Print("Zombie Despawner Bug: Player-Zombie Trace did not hit anything, WTF");
		isVisible = true;
	}
	CloseHandle(trace);
	return isVisible;
}

public bool:TraceFilter(entity, contentsMask)
{
	if (entity <= MaxClients || !IsValidEntity(entity)) // dont let WORLD, players, or invalid entities be hit
	{
		return false;
	}

	decl String:class[128];
	GetEdictClassname(entity, class, sizeof(class)); // Ignore prop_physics since some can be seen through

	return !StrEqual(class, "prop_physics", false);
}

public IsItem(const String:entityname[])
{
	if(StrEqual(entityname, "models/props_junk/gascan001a.mdl")||
	StrEqual(entityname, "models/props_junk/propanecanister001a.mdl")||
	StrEqual(entityname, "models/props_equipment/oxygentank01.mdl")
	)
		return true;
	return false;
	
}