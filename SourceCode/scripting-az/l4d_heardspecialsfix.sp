#pragma semicolon 1                 // Force strict semicolon mode.

#include <sourcemod>
#include <sceneprocessor> 

#define PLUGIN_VERSION		"1.0"
#define CVAR_FLAGS FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_DONTRECORD

#define TEAM_SPECTATOR	1
#define TEAM_SURVIVOR	2
#define TEAM_INFECTED	3
#define TEAM_NEUTRAL	4

#define ZOMBIE_SMOKER	1
#define ZOMBIE_BOOMER	2
#define ZOMBIE_HUNTER	3

#define MODEL_BILL "models/survivors/survivor_namvet.mdl"
#define MODEL_FRANCIS "models/survivors/survivor_biker.mdl"
#define MODEL_LOUIS "models/survivors/survivor_manager.mdl"
#define MODEL_ZOEY "models/survivors/survivor_teenangst.mdl"

new bSmokerAlive;
new bBoomerAlive;
new Handle:VocalizerTimer[3]		= {INVALID_HANDLE};

public Plugin:myinfo =
{
	name        = "Valve Heard Specials Fix",
	author      = "Marcus101RR",
	description = "Fixes the missing Heard Boomer/Smoker Vocals",
	version     = PLUGIN_VERSION,
	url         = ""
};

public OnPluginStart()
{
	CreateConVar("sm_heard_specials_version", PLUGIN_VERSION, "Heard Special Fix Version", CVAR_FLAGS);

	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_Pre);
}

public Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	ActivateVocalization(client);
}

public Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	decl String:VictimName[64];
	GetEventString(event, "victimname", VictimName, sizeof(VictimName));

	if(StrEqual(VictimName, "Smoker", false))
	{
		if(VocalizerTimer[ZOMBIE_SMOKER] != INVALID_HANDLE && bSmokerAlive == 0)
		{
			VocalizerTimer[ZOMBIE_SMOKER] = INVALID_HANDLE;
			bSmokerAlive = CountSpecialInfected(ZOMBIE_SMOKER);
		}
	}
	else if(StrEqual(VictimName, "Boomer", false))
	{
		if(VocalizerTimer[ZOMBIE_BOOMER] != INVALID_HANDLE && bBoomerAlive == 0)
		{
			VocalizerTimer[ZOMBIE_BOOMER] = INVALID_HANDLE;
			bBoomerAlive = CountSpecialInfected(ZOMBIE_BOOMER);
		}
	}
}

public OnMapEnd()
{
	for(new i=0;i<=2;i++)
	{
		if(VocalizerTimer[i] != INVALID_HANDLE)
		{
			//KillTimer(VocalizerTimer[i], false);
			VocalizerTimer[i] = INVALID_HANDLE;
		}
	}
	bSmokerAlive = 0;
	bBoomerAlive = 0;
}

public Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	for(new i=0;i<=2;i++)
	{
		if(VocalizerTimer[i] != INVALID_HANDLE)
		{
			//KillTimer(VocalizerTimer[i], false);
			VocalizerTimer[i] = INVALID_HANDLE;
		}
	}
	bSmokerAlive = 0;
	bBoomerAlive = 0;
}

public ActivateVocalization(client)
{
	if(GetClientTeam(client) == TEAM_INFECTED)
	{
		new infected = GetEntProp(client, Prop_Send, "m_zombieClass");
		new TimerValue = GetRandomInt(2, 5);
					
		if(infected == ZOMBIE_SMOKER && bSmokerAlive == 0)
		{
			VocalizerTimer[ZOMBIE_SMOKER] = CreateTimer(float(TimerValue), timer_PrepareHeardSmoker,TIMER_FLAG_NO_MAPCHANGE);
			bSmokerAlive = CountSpecialInfected(ZOMBIE_SMOKER);
		}

		if(infected == ZOMBIE_BOOMER && bBoomerAlive == 0)
		{
			VocalizerTimer[ZOMBIE_BOOMER] = CreateTimer(float(TimerValue), timer_PrepareHeardBoomer,TIMER_FLAG_NO_MAPCHANGE);
			bBoomerAlive = CountSpecialInfected(ZOMBIE_BOOMER);
		}
	}
}

public Action:timer_PrepareHeardSmoker(Handle:timer, any:client)
{
	bSmokerAlive = CountSpecialInfected(ZOMBIE_SMOKER);
	new vocalizer = GetRandomPlayer(TEAM_SURVIVOR);
	if(vocalizer == -1) return;
	
	decl String:iModel[16], String:model[PLATFORM_MAX_PATH];
	new String:s_Vocalize[PLATFORM_MAX_PATH] = "";
	new iRandom;
	GetClientModel(vocalizer, model, sizeof(model));
	
	if (StrEqual(model, MODEL_BILL))
	{
		iModel = "namvet";
		iRandom = GetRandomInt(1, 7);
	}
	else if (StrEqual(model, MODEL_ZOEY))
	{
		iModel = "teengirl";
		iRandom = GetRandomInt(6, 16);
	}
	else if (StrEqual(model, MODEL_FRANCIS))
	{
		iModel = "biker";
		iRandom = GetRandomInt(1, 7);
		
	}
	else if (StrEqual(model, MODEL_LOUIS))
	{
		iModel = "manager";
		iRandom = GetRandomInt(1, 8);
	}
	
	if(vocalizer > 0 && bSmokerAlive > 0)
	{
		if(iRandom <= 9)
		{
			Format(s_Vocalize, sizeof(s_Vocalize),"scenes/%s/HeardSmoker0%i.vcd", iModel, iRandom);			
		}
		else
		{
			Format(s_Vocalize, sizeof(s_Vocalize),"scenes/%s/HeardSmoker%i.vcd", iModel, iRandom);
		}
		PerformSceneEx(vocalizer, "", s_Vocalize, 2.0, 1.0);
		//PrintToChatAll("scenes/%s/HeardSmoker%i.vcd", iModel, iRandom);
	}

	VocalizerTimer[ZOMBIE_SMOKER] = INVALID_HANDLE;

	if(bSmokerAlive > 0)
		VocalizerTimer[ZOMBIE_SMOKER] = CreateTimer(20.0, timer_PrepareHeardSmoker,TIMER_FLAG_NO_MAPCHANGE);
}

public Action:timer_PrepareHeardBoomer(Handle:timer, any:client)
{
	bBoomerAlive = CountSpecialInfected(ZOMBIE_BOOMER);
	new vocalizer = GetRandomPlayer(TEAM_SURVIVOR);
	if(vocalizer == -1) return;
	
	decl String:iModel[16], String:model[PLATFORM_MAX_PATH];
	new String:s_Vocalize[PLATFORM_MAX_PATH] = "";
	new iRandom;
	GetClientModel(vocalizer, model, sizeof(model));
	
	if (StrEqual(model, MODEL_BILL))
	{
		iModel = "namvet";
		iRandom = GetRandomInt(1, 11);
	}
	else if (StrEqual(model, MODEL_ZOEY))
	{
		iModel = "teengirl";
		iRandom = GetRandomInt(1, 19);
	}
	else if (StrEqual(model, MODEL_FRANCIS))
	{
		iModel = "biker";
		iRandom = GetRandomInt(1, 6);
		
	}
	else if (StrEqual(model, MODEL_LOUIS))
	{
		iModel = "manager";
		iRandom = GetRandomInt(1, 19);
	}
	
	if(vocalizer > 0 && bBoomerAlive > 0)
	{
		if(iRandom <= 9)
		{
			Format(s_Vocalize, sizeof(s_Vocalize),"scenes/%s/HeardBoomer0%i.vcd", iModel, iRandom);			
		}
		else
		{
			Format(s_Vocalize, sizeof(s_Vocalize),"scenes/%s/HeardBoomer%i.vcd", iModel, iRandom);
		}
		PerformSceneEx(vocalizer, "", s_Vocalize, 2.0, 1.0);
		//PrintToChatAll("scenes/%s/HeardBoomer%i.vcd", iModel, iRandom);
	}

	VocalizerTimer[ZOMBIE_BOOMER] = INVALID_HANDLE;

	if(bBoomerAlive > 0)
		VocalizerTimer[ZOMBIE_BOOMER] = CreateTimer(20.0, timer_PrepareHeardBoomer,TIMER_FLAG_NO_MAPCHANGE);
}

stock int CountSpecialInfected(int type)
{
	int k=0;
	for(int i=1; i<=MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == TEAM_INFECTED && IsPlayerAlive(i) && !GetEntProp(i, Prop_Send, "m_isGhost") && GetEntProp(i, Prop_Send, "m_zombieClass") == type)
			k++;
	}
	return k;
}

stock GetRandomPlayer(team)
{
	new clients[MaxClients+1], clientCount;

	for(new i = 1; i <= MaxClients; i++)
		if(IsClientInGame(i) && (GetClientTeam(i) == team) && IsPlayerAlive(i))
			clients[clientCount++] = i;

	return (clientCount == 0) ? -1 : clients[GetRandomInt(0, clientCount-1)];
}