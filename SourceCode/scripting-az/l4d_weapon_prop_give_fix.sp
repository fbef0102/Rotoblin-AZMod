/**
// ====================================================================================================
Change Log:

1.0.3 (23-May-2022)
    - Added delay cvar. (thanks "KadabraZz" for requesting)

1.0.2 (25-January-2022)
    - Fixed plugin not working in some situations. (thanks "HarryPotter" for reporting)

1.0.1 (06-March-2021)
    - Fixed weapon_gascan on L4D1.

1.0.0 (03-March-2021)
    - Initial release.

// ====================================================================================================
*/

// ====================================================================================================
// Plugin Info - define
// ====================================================================================================
#define PLUGIN_NAME                   "[L4D1 & L4D2] Weapon Prop Give Fix"
#define PLUGIN_AUTHOR                 "Mart"
#define PLUGIN_DESCRIPTION            "Fix props not spawning as prop_physics when using 'give' command"
#define PLUGIN_VERSION                "1.0.3"
#define PLUGIN_URL                    "https://forums.alliedmods.net/showthread.php?t=331053"

// ====================================================================================================
// Plugin Info
// ====================================================================================================
public Plugin myinfo =
{
    name        = PLUGIN_NAME,
    author      = PLUGIN_AUTHOR,
    description = PLUGIN_DESCRIPTION,
    version     = PLUGIN_VERSION,
    url         = PLUGIN_URL
}

// ====================================================================================================
// Includes
// ====================================================================================================
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

// ====================================================================================================
// Pragmas
// ====================================================================================================
#pragma semicolon 1
#pragma newdecls required

// ====================================================================================================
// Cvar Flags
// ====================================================================================================
#define CVAR_FLAGS                    FCVAR_NOTIFY
#define CVAR_FLAGS_PLUGIN_VERSION     FCVAR_NOTIFY|FCVAR_DONTRECORD|FCVAR_SPONLY

// ====================================================================================================
// Filenames
// ====================================================================================================
#define CONFIG_FILENAME               "l4d_weapon_prop_give_fix"

// ====================================================================================================
// Defines
// ====================================================================================================
#define MODEL_PROPANECANISTER         "models/props_junk/propanecanister001a.mdl"
#define MODEL_OXYGENTANK              "models/props_equipment/oxygentank01.mdl"
#define MODEL_FIREWORKS_CRATE         "models/props_junk/explosive_box001.mdl"
#define MODEL_GASCAN                  "models/props_junk/gascan001a.mdl"

#define TYPE_NONE                     0
#define TYPE_PROPANECANISTER          1
#define TYPE_OXYGENTANK               2
#define TYPE_FIREWORKS_CRATE          3
#define TYPE_GASCAN                   4

#define MAXENTITIES                   2048

// ====================================================================================================
// Plugin Cvars
// ====================================================================================================
ConVar g_hCvar_Enabled;
ConVar g_hCvar_Delay;
ConVar g_hCvar_PropaneCanister;
ConVar g_hCvar_OxygenTank;
ConVar g_hCvar_FireworksCrate;
ConVar g_hCvar_Gascan;

// ====================================================================================================
// bool - Plugin Variables
// ====================================================================================================
bool g_bL4D2;
bool g_bCvar_Enabled;
bool g_bCvar_PropaneCanister;
bool g_bCvar_OxygenTank;
bool g_bCvar_FireworksCrate;
bool g_bCvar_Gascan;

// ====================================================================================================
// entity - Plugin Variables
// ====================================================================================================
float g_fCvar_Delay;

// ====================================================================================================
// entity - Plugin Variables
// ====================================================================================================
int ge_iType[MAXENTITIES+1];

// ====================================================================================================
// Plugin Start
// ====================================================================================================
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    EngineVersion engine = GetEngineVersion();

    if (engine != Engine_Left4Dead && engine != Engine_Left4Dead2)
    {
        strcopy(error, err_max, "This plugin only runs in \"Left 4 Dead\" and \"Left 4 Dead 2\" game");
        return APLRes_SilentFailure;
    }

    g_bL4D2 = (engine == Engine_Left4Dead2);

    return APLRes_Success;
}

/****************************************************************************************************/

public void OnPluginStart()
{
    CreateConVar("l4d_weapon_prop_give_fix_version", PLUGIN_VERSION, PLUGIN_DESCRIPTION, CVAR_FLAGS_PLUGIN_VERSION);
    g_hCvar_Enabled            = CreateConVar("l4d_weapon_prop_give_fix_enable", "1", "Enable/Disable the plugin.\n0 = Disable, 1 = Enable.", CVAR_FLAGS, true, 0.0, true, 1.0);
    g_hCvar_Delay              = CreateConVar("l4d_weapon_prop_give_fix_delay", "0.0", "How long (in seconds) should the plugin wait to fix the prop.\n0.0 = No delay (immediately).", CVAR_FLAGS, true, 0.0);
    g_hCvar_PropaneCanister    = CreateConVar("l4d_weapon_prop_give_fix_propanecanister", "1", "Spawn weapon_propanetank as prop_physics.\n0 = OFF, 1 = ON.", CVAR_FLAGS, true, 0.0, true, 1.0);
    g_hCvar_OxygenTank         = CreateConVar("l4d_weapon_prop_give_fix_oxygentank", "1", "Spawn weapon_oxygentank as prop_physics.\n0 = OFF, 1 = ON.", CVAR_FLAGS, true, 0.0, true, 1.0);
    if (g_bL4D2)
        g_hCvar_FireworksCrate = CreateConVar("l4d_weapon_prop_give_fix_fireworkscrate", "1", "Spawn weapon_fireworkcrate as prop_physics.\nL4D2 only.\n0 = OFF, 1 = ON.", CVAR_FLAGS, true, 0.0, true, 1.0);
    g_hCvar_Gascan             = CreateConVar("l4d_weapon_prop_give_fix_gascan", "1", "Spawn weapon_gascan as prop_physics.\nL4D1 only.\n0 = OFF, 1 = ON.", CVAR_FLAGS, true, 0.0, true, 1.0);

    // Hook plugin ConVars change
    g_hCvar_Enabled.AddChangeHook(Event_ConVarChanged);
    g_hCvar_Delay.AddChangeHook(Event_ConVarChanged);
    g_hCvar_PropaneCanister.AddChangeHook(Event_ConVarChanged);
    g_hCvar_OxygenTank.AddChangeHook(Event_ConVarChanged);
    if (g_bL4D2)
        g_hCvar_FireworksCrate.AddChangeHook(Event_ConVarChanged);
    else
        g_hCvar_Gascan.AddChangeHook(Event_ConVarChanged);

    // Load plugin configs from .cfg
    AutoExecConfig(true, CONFIG_FILENAME);

    // Admin Commands
    RegAdminCmd("sm_print_cvars_l4d_weapon_prop_give_fix", CmdPrintCvars, ADMFLAG_ROOT, "Prints the plugin related cvars and their respective values to the console.");
}

/****************************************************************************************************/

public void OnConfigsExecuted()
{
    GetCvars();

    LateLoad();
}

/****************************************************************************************************/

void Event_ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    GetCvars();

    LateLoad();
}

/****************************************************************************************************/

void GetCvars()
{
    g_bCvar_Enabled = g_hCvar_Enabled.BoolValue;
    g_fCvar_Delay = g_hCvar_Delay.FloatValue;
    g_bCvar_PropaneCanister = g_hCvar_PropaneCanister.BoolValue;
    g_bCvar_OxygenTank = g_hCvar_OxygenTank.BoolValue;
    if (g_bL4D2)
        g_bCvar_FireworksCrate = g_hCvar_FireworksCrate.BoolValue;
    else
        g_bCvar_Gascan = g_hCvar_Gascan.BoolValue;
}

/****************************************************************************************************/

void LateLoad()
{
    char classname[21];
    int entity;

    classname = "weapon_propanetank";
    entity = INVALID_ENT_REFERENCE;
    while ((entity = FindEntityByClassname(entity, classname)) != INVALID_ENT_REFERENCE)
    {
        OnEntityCreated(entity, classname);
    }

    classname = "weapon_oxygentank";
    entity = INVALID_ENT_REFERENCE;
    while ((entity = FindEntityByClassname(entity, classname)) != INVALID_ENT_REFERENCE)
    {
        OnEntityCreated(entity, classname);
    }

    if (g_bL4D2)
    {
        classname = "weapon_fireworkcrate";
        entity = INVALID_ENT_REFERENCE;
        while ((entity = FindEntityByClassname(entity, classname)) != INVALID_ENT_REFERENCE)
        {
            OnEntityCreated(entity, classname);
        }
    }
    else
    {
        classname = "weapon_gascan";
        entity = INVALID_ENT_REFERENCE;
        while ((entity = FindEntityByClassname(entity, classname)) != INVALID_ENT_REFERENCE)
        {
            OnEntityCreated(entity, classname);
        }
    }
}

/****************************************************************************************************/

public void OnEntityDestroyed(int entity)
{
    if (entity < 0)
        return;

    ge_iType[entity] = TYPE_NONE;
}

/****************************************************************************************************/

public void OnEntityCreated(int entity, const char[] classname)
{
    if (entity < 0)
        return;

    if (ge_iType[entity] != TYPE_NONE)
        return;

    if (StrEqual(classname, "weapon_propanetank"))
    {
        ge_iType[entity] = TYPE_PROPANECANISTER;
        SDKHook(entity, SDKHook_ThinkPost, OnThinkPost);
        return;
    }

    if (StrEqual(classname, "weapon_oxygentank"))
    {
        ge_iType[entity] = TYPE_OXYGENTANK;
        SDKHook(entity, SDKHook_ThinkPost, OnThinkPost);
        return;
    }

    if (g_bL4D2)
    {
        if (StrEqual(classname, "weapon_fireworkcrate"))
        {
            ge_iType[entity] = TYPE_FIREWORKS_CRATE;
            SDKHook(entity, SDKHook_ThinkPost, OnThinkPost);
            return;
        }
    }
    else
    {
        if (StrEqual(classname, "weapon_gascan"))
        {
            ge_iType[entity] = TYPE_GASCAN;
            SDKHook(entity, SDKHook_ThinkPost, OnThinkPost);
            return;
        }
    }
}

/****************************************************************************************************/

void OnThinkPost(int entity)
{
    if (!g_bCvar_Enabled)
        return;

    int type = ge_iType[entity];

    switch (type)
    {
        case TYPE_PROPANECANISTER: if (!g_bCvar_PropaneCanister) return;
        case TYPE_OXYGENTANK: if (!g_bCvar_OxygenTank) return;
        case TYPE_FIREWORKS_CRATE: if (!g_bCvar_FireworksCrate) return;
        case TYPE_GASCAN: if (!g_bCvar_Gascan) return;
    }

    if (GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity") != -1)
        return;

    SDKUnhook(entity, SDKHook_ThinkPost, OnThinkPost);

    if (g_fCvar_Delay == 0.0)
        GetPropAttributes(entity);
    else
        CreateTimer(g_fCvar_Delay, TimerDelayCreateProp, EntIndexToEntRef(entity), TIMER_FLAG_NO_MAPCHANGE);
}

/****************************************************************************************************/

Action TimerDelayCreateProp(Handle timer, int entityRef)
{
    int entity = EntRefToEntIndex(entityRef);

    if (entity == INVALID_ENT_REFERENCE)
        return Plugin_Stop;

    if (GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity") != -1)
    {
        SDKHook(entity, SDKHook_ThinkPost, OnThinkPost);
        return Plugin_Stop;
    }

    GetPropAttributes(entity);

    return Plugin_Handled;
}

/****************************************************************************************************/

void GetPropAttributes(int entity)
{
    int type = ge_iType[entity];

    float vPos[3];
    GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vPos);

    float vAng[3];
    GetEntPropVector(entity, Prop_Data, "m_angAbsRotation", vAng);

    AcceptEntityInput(entity, "Kill");

    CreateProp(type, vPos, vAng);
}

/****************************************************************************************************/

void CreateProp(int type, float vPos[3], float vAng[3])
{
    char modelname[PLATFORM_MAX_PATH];

    switch (type)
    {
        case TYPE_PROPANECANISTER: modelname = MODEL_PROPANECANISTER;
        case TYPE_OXYGENTANK: modelname = MODEL_OXYGENTANK;
        case TYPE_FIREWORKS_CRATE: modelname = MODEL_FIREWORKS_CRATE;
        case TYPE_GASCAN: modelname = MODEL_GASCAN;
    }

    int entity = CreateEntityByName("prop_physics");
    DispatchKeyValue(entity, "model", modelname);
    DispatchKeyValueVector(entity, "origin", vPos);
    DispatchKeyValueVector(entity, "angles", vAng);
    DispatchSpawn(entity);
}

// ====================================================================================================
// Admin Commands
// ====================================================================================================
Action CmdPrintCvars(int client, int args)
{
    PrintToConsole(client, "");
    PrintToConsole(client, "======================================================================");
    PrintToConsole(client, "");
    PrintToConsole(client, "----------------- Plugin Cvars (l4d_weapon_prop_give_fix) -----------------");
    PrintToConsole(client, "");
    PrintToConsole(client, "l4d_weapon_prop_give_fix_version : %s", PLUGIN_VERSION);
    PrintToConsole(client, "l4d_weapon_prop_give_fix_enable : %b (%s)", g_bCvar_Enabled, g_bCvar_Enabled ? "true" : "false");
    PrintToConsole(client, "l4d_weapon_prop_give_fix_delay : %.1f", g_fCvar_Delay);
    PrintToConsole(client, "l4d_weapon_prop_give_fix_propanecanister : %b (%s)", g_bCvar_PropaneCanister, g_bCvar_PropaneCanister ? "true" : "false");
    PrintToConsole(client, "l4d_weapon_prop_give_fix_oxygentank : %b (%s)", g_bCvar_OxygenTank, g_bCvar_OxygenTank ? "true" : "false");
    if (g_bL4D2) PrintToConsole(client, "l4d_weapon_prop_give_fix_fireworkscrate : %b (%s)", g_bCvar_FireworksCrate, g_bCvar_FireworksCrate ? "true" : "false");
    if (!g_bL4D2) PrintToConsole(client, "l4d_weapon_prop_give_fix_gascan : %b (%s)", g_bCvar_Gascan, g_bCvar_Gascan ? "true" : "false");
    PrintToConsole(client, "");
    PrintToConsole(client, "======================================================================");
    PrintToConsole(client, "");

    return Plugin_Handled;
}