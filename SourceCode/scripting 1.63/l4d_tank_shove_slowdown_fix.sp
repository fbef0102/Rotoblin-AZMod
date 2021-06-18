#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4downtown>

public Plugin:myinfo =
{
	name = "L4D shove Tank slowdown Fix",
	description = "Stops Shoves slowing the Tank Down",
	author = "Sir, Visor,L4D1 port by Harry",
	version = "1.0",
	url = "https://github.com/Attano/Equilibrium"
};

public Action:L4D_OnShovedBySurvivor(shover, shovee, const Float:vector[3])
{
	if (!IsSurvivor(shover) || !IsInfected(shovee))
	{
		return Plugin_Continue;
	}
	if (IsTank(shovee))
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action:L4D_OnEntityShoved(client, entity, weapon, const Float:vector[3])
{
	if (!IsSurvivor(client) || !IsInfected(entity))
	{
		return Plugin_Continue;
	}
	if (IsTank(entity))
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

bool:IsTank(client)
{
	if (!IsPlayerAlive(client))
	{
		return false;
	}
	
	new zombieclass = GetEntProp(client, Prop_Send, "m_zombieClass");
	return (zombieclass == 5);
}

bool:IsSurvivor(client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2);
}

bool:IsInfected(client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3);
}