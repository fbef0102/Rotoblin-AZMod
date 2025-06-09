#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <left4dhooks>

#define PLUGIN_VERSION "1.1-2025/6/10"

public Plugin myinfo = 
{
	name = "[L4D & 2] Freely Round End",
	author = "Forgetest, Harry",
	description = "Free movement after round ends.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

public void OnPluginStart()
{
	HookEvent("round_start",            Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_Post);
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

// @param countSurvivors		False = Survivors didn't make it to saferoom. True = Survivors made to the saferoom
public Action L4D2_OnEndVersusModeRound(bool countSurvivors)
{
	if(countSurvivors)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				SDKHook(i, SDKHook_OnTakeDamage, SurvivorOnTakeDamage);
			}
		}
	}

	return Plugin_Continue;
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	/**
	 * typeof (event["reason"]) == "ScenarioRestartReason"
	 *
	 * Get an incomplete list here:
	 * https://github.com/Attano/Left4Downtown2/blob/944994f916617201680c100d372c1074c5f6ae42/l4d2sdk/director.h#L121
	 */
	switch (event.GetInt("reason")) 
	{
		case 5: // versus round end
		{
			RequestFrame(OnFrame_RoundEnd);
		}
	}
}

void OnFrame_RoundEnd()
{
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (IsClientInGame(i))
		{
			SetEntityFlags(i, GetEntityFlags(i) & ~(FL_FROZEN|FL_GODMODE));
		}
	}
}

Action SurvivorOnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
    if (!IsClientInGame(victim) || GetClientTeam(victim) != 2) return Plugin_Continue;

    return Plugin_Handled;
}