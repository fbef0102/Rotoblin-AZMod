#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>

#define PLUGIN_VERSION			"1.1-2025/10/6"
#define PLUGIN_NAME			    "l4d_witch_spawn_no_door"
#define DEBUG 0

public Plugin myinfo =
{
	name = "[L4D1] witch spawn no door",
	author = "HarryPotter",
	description = "Remove Door around when witch spawn",
	version = PLUGIN_VERSION,
	url = "https://steamcommunity.com/profiles/76561198026784913/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    EngineVersion test = GetEngineVersion();

    if( test != Engine_Left4Dead )
    {
        strcopy(error, err_max, "Plugin only supports Left 4 Dead 1.");
        return APLRes_SilentFailure;
    }

    return APLRes_Success;
}

#define CVAR_FLAGS                    FCVAR_NOTIFY
#define CVAR_FLAGS_PLUGIN_VERSION     FCVAR_NOTIFY|FCVAR_DONTRECORD|FCVAR_SPONLY


ConVar g_hCvarEnable;
bool g_bCvarEnable;

public void OnPluginStart()
{
    g_hCvarEnable 		= CreateConVar( PLUGIN_NAME ... "_enable",        "1",   "0=Plugin off, 1=Plugin on.", CVAR_FLAGS, true, 0.0, true, 1.0);
    CreateConVar(                       PLUGIN_NAME ... "_version",       PLUGIN_VERSION, PLUGIN_NAME ... " Plugin Version", CVAR_FLAGS_PLUGIN_VERSION);
    //AutoExecConfig(true,                PLUGIN_NAME);

    GetCvars();
    g_hCvarEnable.AddChangeHook(ConVarChanged_Cvars);

    HookEvent("witch_spawn",		WitchSpawn_Event);
}

// Cvars-------------------------------

void ConVarChanged_Cvars(ConVar hCvar, const char[] sOldVal, const char[] sNewVal)
{
	GetCvars();
}

void GetCvars()
{
    g_bCvarEnable = g_hCvarEnable.BoolValue;
}

// Event-------------------------------

public void WitchSpawn_Event(Event event, const char[] name, bool dontBroadcast)
{
	if(!g_bCvarEnable) return;

	CreateTimer(0.1 , WitchSpawn_Timer, EntIndexToEntRef(event.GetInt("witchid")), TIMER_FLAG_NO_MAPCHANGE);
}

// Timer-------------------------------

Action WitchSpawn_Timer(Handle timer, int witch)
{
    witch = EntRefToEntIndex(witch);
    if(witch == INVALID_ENT_REFERENCE) return Plugin_Continue;

    int door;
    float vWitchPos[3], vDoorPos[3], fVector[3];
    GetEntPropVector(witch, Prop_Send, "m_vecOrigin", vWitchPos);
    while( (door = FindEntityByClassname(door, "prop_door_rotating")) != -1 )
    {
        char sTargetName[64];
        Entity_GetTargetName(door, sTargetName, sizeof sTargetName);
        if(strlen(sTargetName) > 0) continue;

        GetEntPropVector(door, Prop_Send, "m_vecOrigin", vDoorPos);
        MakeVectorFromPoints(vWitchPos, vDoorPos, fVector);
        if (GetVectorLength(fVector, true) <= 150 * 150)
        {
            AcceptEntityInput(door, "Break");
        }
    }

    return Plugin_Continue;
}

// function

int Entity_GetTargetName(int entity, char[] buffer, int size)
{
	return GetEntPropString(entity, Prop_Data, "m_iName", buffer, size);
}