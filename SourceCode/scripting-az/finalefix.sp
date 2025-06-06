#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

public Plugin myinfo =
{
	name = "L4D2 Finale Incap Distance Fix",
	author = "CanadaRox",
	description = "Kills incap or haning from ledge survivors before the score is calculated and make alive player god mode as the rescue vehicle leaves.",
	version = "1.2-2025/6/6",
	url = "https://bitbucket.org/CanadaRox/random-sourcemod-stuff"
};

public void OnPluginStart()
{
	HookEvent("round_start",            Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("finale_vehicle_leaving", FinaleEnd_Event, EventHookMode_PostNoCopy);
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) 
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i))
			continue;
			
		SDKUnhook(i, SDKHook_OnTakeDamage, SurvivorOnTakeDamage);
	}
}

void FinaleEnd_Event(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i)) 
		{
			SDKHook(i, SDKHook_OnTakeDamage, SurvivorOnTakeDamage);

			if(GetClientTeam(i) == 2 && IsPlayerAlive(i) && IsPlayerIncap(i))
			{
				ForcePlayerSuicide(i);
			}
		}
	}
}

Action SurvivorOnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
    if (!IsClientInGame(victim) || GetClientTeam(victim) != 2) return Plugin_Continue;

    return Plugin_Handled;
}

bool IsPlayerIncap(int client)
{
	return view_as<bool>(GetEntProp(client, Prop_Send, "m_isIncapacitated"));
}