#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PLUGIN_VERSION			"1.0"
#define PLUGIN_NAME			    "l4d_boomer_alarm_witch"
#define DEBUG 0

public Plugin myinfo =
{
	name = "[L4D1] Boomer alarm Witch",
	author = "HarryPotter",
	description = "Survivor will startle witch if shoot boomer nearby",
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

#define TEAM_SPECTATOR		1
#define TEAM_SURVIVOR		2
#define TEAM_INFECTED		3

#define ZOMBIECLASS_BOOMER 2

float TRACE_TOLERANCE = 25.0;

ConVar z_exploding_splat_radius;
float g_fCvar_z_exploding_splat_radius;

ConVar g_hCvarEnable;
bool g_bCvarEnable;

public void OnPluginStart()
{
    z_exploding_splat_radius = FindConVar("z_exploding_splat_radius");

    g_hCvarEnable 		= CreateConVar( PLUGIN_NAME ... "_enable",        "1",   "0=Plugin off, 1=Plugin on.", CVAR_FLAGS, true, 0.0, true, 1.0);
    CreateConVar(                       PLUGIN_NAME ... "_version",       PLUGIN_VERSION, PLUGIN_NAME ... " Plugin Version", CVAR_FLAGS_PLUGIN_VERSION);

    GetCvars();
    z_exploding_splat_radius.AddChangeHook(ConVarChanged_Cvars);
    g_hCvarEnable.AddChangeHook(ConVarChanged_Cvars);

}

// Cvars-------------------------------

void ConVarChanged_Cvars(ConVar hCvar, const char[] sOldVal, const char[] sNewVal)
{
	GetCvars();
}

void GetCvars()
{
    g_bCvarEnable = g_hCvarEnable.BoolValue;
    g_fCvar_z_exploding_splat_radius = z_exploding_splat_radius.FloatValue;

    HookEvent("player_death", event_PlayerDeath);
}

// Event-------------------------------

void event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    if (g_bCvarEnable == false) return;

    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    int vicitm = GetClientOfUserId(event.GetInt("userid"));
    if (!vicitm || !IsClientInGame(vicitm) || GetClientTeam(vicitm) != TEAM_INFECTED || GetEntProp(vicitm, Prop_Send, "m_zombieClass") != ZOMBIECLASS_BOOMER) return;
    if (!attacker || !IsClientInGame(attacker) || GetClientTeam(attacker) != TEAM_SURVIVOR || !IsPlayerAlive(attacker)) return;


    float witchpos[3], Boomerpos[3];
    GetClientEyePosition(vicitm, Boomerpos);

    int witch = -1;
    while((witch = FindEntityByClassname(witch, "witch")) != -1)
    {
        if (!IsValidEntity(witch))
            continue;	
        
        GetEntPropVector(witch, Prop_Data, "m_vecAbsOrigin", witchpos);
        if (GetVectorDistance(Boomerpos, witchpos) > g_fCvar_z_exploding_splat_radius || !IsVisibleTo(Boomerpos, witchpos))
        {
            continue;
        }
        
        HurtEntity(witch, attacker, 0.0, DMG_GENERIC);
    }
}

// Function-------------------------------

void HurtEntity(int victim, int client, float damage, int damagetype)
{
	SDKHooks_TakeDamage(victim, client, client, damage, damagetype);
}

bool IsVisibleTo(float position[3], float targetposition[3])
{
	float vAngles[3], vLookAt[3];
	
	MakeVectorFromPoints(position, targetposition, vLookAt); // compute vector from start to target
	GetVectorAngles(vLookAt, vAngles); // get angles from vector for trace
	
	// execute Trace
	Handle trace = TR_TraceRayFilterEx(position, vAngles, MASK_SHOT, RayType_Infinite, _TraceFilter);
	bool isVisible = false;
	if (TR_DidHit(trace))
	{
		float vStart[3];
		TR_GetEndPosition(vStart, trace); // retrieve our trace endpoint
		
		if ((GetVectorDistance(position, vStart, false) + TRACE_TOLERANCE) >= GetVectorDistance(position, targetposition))
		{
			isVisible = true; // if trace ray lenght plus tolerance equal or bigger absolute distance, you hit the target
		}
	}
	else
	{
		LogError("Tracer Bug: Player-Zombie Trace did not hit anything, WTF");
		isVisible = true;
	}
	delete trace;
	return isVisible;
}

bool _TraceFilter(int entity, int contentsMask)
{
	if (!entity || !IsValidEntity(entity)) // dont let WORLD, or invalid entities be hit
	{
		return false;
	}
	
	return true;
}