#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

public Plugin myinfo =
{
	name = "Re3 Door Sucks",
	author = "Harry Potter",
	description = "Tank and witch can break door in resident evil 3",
	version = "1.0-2026/1/15",
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

public void OnPluginStart()
{

}

bool g_bIsRe3Map;
public void OnMapStart()
{
    g_bIsRe3Map = false;
    char currentMap[64];
    GetCurrentMap(currentMap, sizeof currentMap);
    if(strncmp(currentMap, "re3short_m", 10, false) == 0)
    {
        g_bIsRe3Map = true;
    }
}

// 部分實體會在OnMapStart之前就生成, 需等待下一偵
public void OnEntityCreated(int entity, const char[] classname)
{
    switch (classname[0])
    {
        case 'p':
        {
            if (strcmp(classname, "prop_door_rotating", false) == 0)
            {
                RequestFrame(OnNextFrame_Door, EntIndexToEntRef(entity));
            }
        }
    }
}

void OnNextFrame_Door(int door)
{
    if(!g_bIsRe3Map) return;

    door = EntRefToEntIndex(door);
    if(door == INVALID_ENT_REFERENCE) return;

    SDKHook(door, SDKHook_OnTakeDamagePost, DoorOnTakeDamagePost);
}

void DoorOnTakeDamagePost(int door, int attacker, int inflictor, float damage, int damagetype)
{
    if(attacker > MaxClients && IsValidEntity(attacker))
    {
        static char sClassName[64];
        GetEntityClassname(attacker, sClassName, sizeof sClassName);
        if(strncmp(sClassName, "witch", 5, false) == 0)
        {
            CreateTimer(0.1, Timer_RemoveDoor, EntIndexToEntRef(door), TIMER_FLAG_NO_MAPCHANGE);
        }
    }
    else if( 0 < attacker <= MaxClients && IsClientInGame(attacker) && GetClientTeam(attacker) == 3
        && GetEntProp(attacker, Prop_Send, "m_zombieClass") == ZC_TANK)
    {
        CreateTimer(0.1, Timer_RemoveDoor, EntIndexToEntRef(door), TIMER_FLAG_NO_MAPCHANGE);
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