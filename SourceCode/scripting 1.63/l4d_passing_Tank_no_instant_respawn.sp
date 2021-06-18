#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <colors>

new lastHumanTank = -1;

public Plugin:myinfo =
{
	name = "L4D passing Tank no instant respawn",
	author = "Visor, L4D1 port by Harry",
	description = "Passing control to AI tank will no longer be rewarded with an instant respawn",
	version = "0.3",
	url = "https://github.com/Attano/Equilibrium"
};

public OnPluginStart()
{
	LoadTranslations("Roto2-AZ_mod.phrases");
	HookEvent("tank_frustrated", OnTankFrustrated, EventHookMode_Post);
}

public OnTankFrustrated(Handle:event, const String:name[], bool:dontBroadcast)
{
	new tank = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsFakeClient(tank))
	{
		lastHumanTank = tank;
		CreateTimer(0.1, CheckForAITank, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action:CheckForAITank(Handle:timer)
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsTank(i))
		{
			if (IsInfected(lastHumanTank)&&IsFakeClient(i))//Tank is AI
			{
				TeleportEntity(lastHumanTank,
				Float:{0.0, 0.0, 0.0}, // Teleport to map center
				NULL_VECTOR, 
				NULL_VECTOR);
				ForcePlayerSuicide(lastHumanTank);
				CPrintToChat(lastHumanTank,"{default}[{olive}TS{default}] %T","No Instant Spawn",lastHumanTank);
				decl String:lastHumanTank_Name[128];
				GetClientName(lastHumanTank,lastHumanTank_Name,128);	
				for (new j = 1; j < MaxClients; j++)
					if (IsClientInGame(j) && IsClientConnected(j) && !IsFakeClient(j) && (GetClientTeam(j) == 1 || GetClientTeam(j) == 3))
						CPrintToChat(j,"{default}[{olive}TS{default}] %T","Give Tank To AI",j,lastHumanTank_Name);
			}
			return Plugin_Handled;
		}
	}
	return Plugin_Handled;
}

bool:IsTank(client)
{
	return (IsInfected(client) && GetEntProp(client, Prop_Send, "m_zombieClass") == 5);
}

bool:IsInfected(client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3);
}