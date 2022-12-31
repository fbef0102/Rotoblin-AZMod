#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define PLUGIN_VERSION "1.0"

public Plugin myinfo = 
{
    name = "[L4D] Ghost Tank Glow",
    author = "HarryPotter",
    description = "Detect ghost tank and create fakes models with glow.",
    version = PLUGIN_VERSION,
    url = "http://steamcommunity.com/profiles/76561198026784913"
};

//=========================================================================================================
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

#define TEAM_INFECTED		3

#define ZC_TANK		5

ConVar g_cvEnable;

int g_iModelIndex[MAXPLAYERS+1];			// Player Glow Model entity reference

bool g_bFinalStarted;

public void OnPluginStart()
{
    g_cvEnable = CreateConVar("l4d_ghost_tank_glow_enable",
                                "1",
                                "If 1, Enable ghost tank glow.\n"
                            ...	"0 = Disable, 1 = Enable",
                                FCVAR_NOTIFY,
                                true, 0.0, true, 1.0);

    HookEvent("round_start", Event_RoundStart);
    HookEvent("finale_start", 			OnFinaleStart_Event, EventHookMode_PostNoCopy); //final starts, some of final maps won't trigger
    HookEvent("finale_radio_start", 	OnFinaleStart_Event, EventHookMode_PostNoCopy); //final starts, all final maps trigger
    HookEvent("tank_spawn", Event_TankSpawn);
}

//=========================================================================================================

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) 
{
	g_bFinalStarted = false;
}

public void OnFinaleStart_Event(Event event, const char[] name, bool dontBroadcast) 
{
	g_bFinalStarted = true;
}

void Event_TankSpawn(Event event, const char[] name, bool dontBroadcast)
{
    if(!g_cvEnable.BoolValue || g_bFinalStarted) return;

    CreateTimer(0.1, Timer_Event_TankSpawn, event.GetInt("userid"), TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_Event_TankSpawn(Handle Timer, int userid)
{
    int tank = GetClientOfUserId(userid);
    if (!tank || !IsClientInGame(tank))
        return Plugin_Continue;

    //PrintToChatAll("%d - %d - %d - %d", GetClientTeam(tank), GetZombieClass(tank), IsPlayerAlive(tank), L4D_IsPlayerGhost(tank));
	
    if (GetClientTeam(tank) == TEAM_INFECTED && 
        GetZombieClass(tank) == ZC_TANK && 
        IsPlayerAlive(tank) && 
        L4D_IsPlayerGhost(tank))
    {
        CreateTankGlowModel(tank);
    }

    return Plugin_Continue;
}

//=========================================================================================================

void CreateTankGlowModel(int tank)
{
    // Delete previous glow first just in case
    RemoveTankGlowModel(tank);

    static char sModelName[64];
    GetEntPropString(tank, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName));
    //PrintToChatAll("m_ModelName: %s", sModelName);
        
    float vPos[3];
    float vAng[3];

    GetClientAbsOrigin(tank, vPos);
    GetClientAbsAngles(tank, vAng);

    int entity = CreateEntityByName("prop_glowing_object");
    if(entity <= 0 ) return;

    DispatchKeyValue(entity, "model", sModelName);
    DispatchKeyValue(entity, "disableshadows", "1");
    DispatchKeyValue(entity, "targetname", "l4d_ghost_tank_glow");
    
    DispatchKeyValue(entity, "StartGlowing", "1");
    DispatchKeyValue(entity, "DefaultAnim", "idle");
    DispatchKeyValue(entity, "GlowForTeam", "-1");

    /* GlowForTeam =  -1:ALL  , 0:NONE , 1:SPECTATOR  , 2:SURVIVOR , 3:INFECTED */
    
    TeleportEntity(entity, vPos, vAng, NULL_VECTOR);
    DispatchSpawn(entity);
    SetEntityRenderFx(entity, RENDERFX_FADE_FAST);
    SetEntProp(entity, Prop_Send, "m_CollisionGroup", 0);
    SetEntProp(entity, Prop_Send, "m_nSolidType", 0);
    SetVariantString("!activator");
    AcceptEntityInput(entity, "SetParent", tank); 

    g_iModelIndex[tank] = EntIndexToEntRef(entity);
    
    CreateTimer(0.1, Timer_CheckGhostTank, tank, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
}

void RemoveTankGlowModel(int client)
{
	int glow = g_iModelIndex[client];
	g_iModelIndex[client] = 0;

	if( IsValidEntRef(glow) )
		AcceptEntityInput(glow, "kill");
}

Action Timer_CheckGhostTank(Handle timer, int tank)
{
    if (!IsClientInGame(tank) ||
        GetClientTeam(tank) != TEAM_INFECTED ||
        !IsPlayerAlive(tank) || 
        !L4D_IsPlayerGhost(tank))
    {
        RemoveTankGlowModel(tank);
    }
	
    return Plugin_Continue;
}

bool IsValidEntRef(int entity)
{
	if( entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE)
		return true;
	return false;
}

int GetZombieClass(int client)
{
    return GetEntProp(client, Prop_Send, "m_zombieClass");
}
