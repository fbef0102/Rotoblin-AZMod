#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

public Plugin myinfo =
{
	name = "L4D2 Finale Incap Distance Fixifier",
	author = "CanadaRox",
	description = "Kills survivors before the score is calculated so you don't get full distance if you are incapped or pinned as the rescue vehicle leaves.",
	version = "1.1",
	url = "https://bitbucket.org/CanadaRox/random-sourcemod-stuff"
};

public void OnPluginStart()
{
	HookEvent("finale_vehicle_leaving", FinaleEnd_Event, EventHookMode_PostNoCopy);
}

public void FinaleEnd_Event(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2)
		{
			if(IsPlayerIncap(i)) ForcePlayerSuicide(i);
			if(IsSurvivorPinned(i)) ForcePlayerSuicide(i);
		}
	}
}

bool IsPlayerIncap(int client)
{
	return view_as<bool>(GetEntProp(client, Prop_Send, "m_isIncapacitated"));
}

bool IsSurvivorPinned(int client)
{
	/* Hunter */
	int victim = GetEntPropEnt(client, Prop_Send, "m_pounceAttacker");
	if (victim > 0)
	{
		return true;
	}

	/* Smoker */
	victim = GetEntPropEnt(client, Prop_Send, "m_tongueOwner");
	if (victim > 0)
	{
		return true;
	}

	return false;
}