#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
#include <multicolors>

public Plugin myinfo =
{
	name = "l4d_tank_stumble_door_break",
	author = "Harry Potter",
	description = "Door would break if survivors use it to stumble the tank in l4d1",
	version = "1.0-2026/8/21",
	url = "http://steamcommunity.com/profiles/76561198026784913"
}

int ZC_TANK;
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    EngineVersion test = GetEngineVersion();

    if( test != Engine_Left4Dead )
    {
        strcopy(error, err_max, "Plugin only supports Left 4 Dead 1.");
        return APLRes_SilentFailure;
    }

    ZC_TANK = 5;
    return APLRes_Success;
}

#define MAXENTITIES                   2048

bool 
    g_bIsDoor[MAXENTITIES+1];

float 
    g_fNotifyEngimeTime;

public void OnPluginStart()
{
    LoadTranslations("Roto2-AZ_mod.phrases");
}

// 部分實體會在OnMapStart之前就生成, 需等待下一偵
public void OnEntityCreated(int entity, const char[] classname)
{
    if (!IsValidEntityIndex(entity))
        return;
        
    g_bIsDoor[entity] = false;

    switch (classname[0])
    {
        case 'p':
        {
            if (strcmp(classname, "prop_door_rotating", false) == 0)
            {
                g_bIsDoor[entity] = true;
            }
        }
    }
}

public Action L4D2_OnStagger(int client, int source)
{
    //PrintToChatAll("L4D2_OnStagger: %d %d", client, source);
    if( 0 < client <= MaxClients && IsClientInGame(client)&& GetClientTeam(client) == L4D_TEAM_INFECTED
        && IsPlayerAlive(client)
        && GetEntProp(client, Prop_Send, "m_zombieClass") == ZC_TANK
        && g_bIsDoor[source])
    {
        float now = GetEngineTime();
        if(now > g_fNotifyEngimeTime)
        {
            CPrintToChatAll("%t","l4d_tank_stumble_door_break_1");
            g_fNotifyEngimeTime = now + 0.2;
        }
        CreateTimer(0.0, Timer_RemoveDoor, EntIndexToEntRef(source), TIMER_FLAG_NO_MAPCHANGE);
    }
}

Action Timer_RemoveDoor(Handle timer, int door)
{
	door = EntRefToEntIndex(door);
	if(door == INVALID_ENT_REFERENCE) return Plugin_Continue;

	AcceptEntityInput(door, "Unlock");
	AcceptEntityInput(door, "ForceOpen");
	AcceptEntityInput(door, "SetBreakable");
	AcceptEntityInput(door, "Break");

	return Plugin_Continue;
}

bool IsValidEntityIndex(int entity)
{
	return (MaxClients+1 <= entity <= GetMaxEntities());
}