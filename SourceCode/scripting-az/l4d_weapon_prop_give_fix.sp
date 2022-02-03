/**
// ====================================================================================================
Change Log:

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
#define PLUGIN_VERSION                "1.0.2"
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
static ConVar g_hCvar_Enabled;
static ConVar g_hCvar_PropaneCanister;
static ConVar g_hCvar_OxygenTank;
static ConVar g_hCvar_FireworksCrate;
static ConVar g_hCvar_Gascan;

// ====================================================================================================
// bool - Plugin Variables
// ====================================================================================================
static bool   g_bL4D2;
static bool   g_bCvar_Enabled;
static bool   g_bCvar_PropaneCanister;
static bool   g_bCvar_OxygenTank;
static bool   g_bCvar_FireworksCrate;
static bool   g_bCvar_Gascan;

// ====================================================================================================
// entity - Plugin Variables
// ====================================================================================================
static bool   ge_bOnThinkPostHooked[MAXENTITIES+1];
static int    ge_iType[MAXENTITIES+1];

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
    g_hCvar_PropaneCanister    = CreateConVar("l4d_weapon_prop_give_fix_propanecanister", "1", "Spawn weapon_propanetank as prop_physics.\n0 = OFF, 1 = ON.", CVAR_FLAGS, true, 0.0, true, 1.0);
    g_hCvar_OxygenTank         = CreateConVar("l4d_weapon_prop_give_fix_oxygentank", "1", "Spawn weapon_oxygentank as prop_physics.\n0 = OFF, 1 = ON.", CVAR_FLAGS, true, 0.0, true, 1.0);
    if (g_bL4D2)
        g_hCvar_FireworksCrate = CreateConVar("l4d_weapon_prop_give_fix_fireworkscrate", "1", "Spawn weapon_fireworkcrate as prop_physics.\nL4D2 only.\n0 = OFF, 1 = ON.", CVAR_FLAGS, true, 0.0, true, 1.0);
    g_hCvar_Gascan             = CreateConVar("l4d_weapon_prop_give_fix_gascan", "1", "Spawn weapon_gascan as prop_physics.\nL4D1 only.\n0 = OFF, 1 = ON.", CVAR_FLAGS, true, 0.0, true, 1.0);

    // Hook plugin ConVars change
    g_hCvar_Enabled.AddChangeHook(Event_ConVarChanged);
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

public void Event_ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    GetCvars();

    LateLoad();
}

/****************************************************************************************************/

public void GetCvars()
{
    g_bCvar_Enabled = g_hCvar_Enabled.BoolValue;
    g_bCvar_PropaneCanister = g_hCvar_PropaneCanister.BoolValue;
    g_bCvar_OxygenTank = g_hCvar_OxygenTank.BoolValue;
    if (g_bL4D2)
        g_bCvar_FireworksCrate = g_hCvar_FireworksCrate.BoolValue;
    else
        g_bCvar_Gascan = g_hCvar_Gascan.BoolValue;
}

/****************************************************************************************************/

public void LateLoad()
{
    char classname[21];
    int entity;

    classname = "weapon_propanetank";
    entity = INVALID_ENT_REFERENCE;
    while ((entity = FindEntityByClassname(entity, classname)) != INVALID_ENT_REFERENCE)
    {
        OnEntityCreated(entity, classname);
        OnThinkPost(entity);
    }

    classname = "weapon_oxygentank";
    entity = INVALID_ENT_REFERENCE;
    while ((entity = FindEntityByClassname(entity, classname)) != INVALID_ENT_REFERENCE)
    {
        OnEntityCreated(entity, classname);
        OnThinkPost(entity);
    }

    if (g_bL4D2)
    {
        classname = "weapon_fireworkcrate";
        entity = INVALID_ENT_REFERENCE;
        while ((entity = FindEntityByClassname(entity, classname)) != INVALID_ENT_REFERENCE)
        {
            OnEntityCreated(entity, classname);
            OnThinkPost(entity);
        }
    }
    else
    {
        classname = "weapon_gascan";
        entity = INVALID_ENT_REFERENCE;
        while ((entity = FindEntityByClassname(entity, classname)) != INVALID_ENT_REFERENCE)
        {
            OnEntityCreated(entity, classname);
            OnThinkPost(entity);
        }
    }
}

/****************************************************************************************************/

public void OnEntityDestroyed(int entity)
{
    if (!IsValidEntityIndex(entity))
        return;

    ge_bOnThinkPostHooked[entity] = false;
    ge_iType[entity] = TYPE_NONE;
}

/****************************************************************************************************/

public void OnEntityCreated(int entity, const char[] classname)
{
    if (classname[0] != 'w' || classname[1] != 'e') // weapon_*
        return;

    if (ge_bOnThinkPostHooked[entity])
        return;

    if (StrEqual(classname, "weapon_propanetank"))
    {
        ge_iType[entity] = TYPE_PROPANECANISTER;
        ge_bOnThinkPostHooked[entity] = true;
        SDKHook(entity, SDKHook_ThinkPost, OnThinkPost);
        return;
    }

    if (StrEqual(classname, "weapon_oxygentank"))
    {
        ge_iType[entity] = TYPE_OXYGENTANK;
        ge_bOnThinkPostHooked[entity] = true;
        SDKHook(entity, SDKHook_ThinkPost, OnThinkPost);
        return;
    }

    if (g_bL4D2)
    {
        if (StrEqual(classname, "weapon_fireworkcrate"))
        {
            ge_iType[entity] = TYPE_FIREWORKS_CRATE;
            ge_bOnThinkPostHooked[entity] = true;
            SDKHook(entity, SDKHook_ThinkPost, OnThinkPost);
            return;
        }
    }
    else
    {
        if (StrEqual(classname, "weapon_gascan"))
        {
            ge_iType[entity] = TYPE_GASCAN;
            ge_bOnThinkPostHooked[entity] = true;
            SDKHook(entity, SDKHook_ThinkPost, OnThinkPost);
            return;
        }
    }
}

/****************************************************************************************************/

public void OnThinkPost(int entity)
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
        default: return;
    }

    if (GetEntProp(entity, Prop_Send, "m_hOwner") != -1)
        return;

    float vPos[3];
    GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vPos);

    float vAng[3];
    GetEntPropVector(entity, Prop_Send, "m_angRotation", vAng);

    AcceptEntityInput(entity, "Kill");

    CreateProp(type, vPos, vAng);
}

/****************************************************************************************************/

public void CreateProp(int type, float vPos[3], float vAng[3])
{
    char modelname[PLATFORM_MAX_PATH];

    switch (type)
    {
        case TYPE_PROPANECANISTER: modelname = MODEL_PROPANECANISTER;
        case TYPE_OXYGENTANK: modelname = MODEL_OXYGENTANK;
        case TYPE_FIREWORKS_CRATE: modelname = MODEL_FIREWORKS_CRATE;
        case TYPE_GASCAN: modelname = MODEL_GASCAN;
        default: return;
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
public Action CmdPrintCvars(int client, int args)
{
    PrintToConsole(client, "");
    PrintToConsole(client, "======================================================================");
    PrintToConsole(client, "");
    PrintToConsole(client, "----------------- Plugin Cvars (l4d_weapon_prop_give_fix) -----------------");
    PrintToConsole(client, "");
    PrintToConsole(client, "l4d_weapon_prop_give_fix_version : %s", PLUGIN_VERSION);
    PrintToConsole(client, "l4d_weapon_prop_give_fix_enable : %b (%s)", g_bCvar_Enabled, g_bCvar_Enabled ? "true" : "false");
    PrintToConsole(client, "l4d_weapon_prop_give_fix_propanecanister : %b (%s)", g_bCvar_PropaneCanister, g_bCvar_PropaneCanister ? "true" : "false");
    PrintToConsole(client, "l4d_weapon_prop_give_fix_oxygentank : %b (%s)", g_bCvar_OxygenTank, g_bCvar_OxygenTank ? "true" : "false");
    if (g_bL4D2) PrintToConsole(client, "l4d_weapon_prop_give_fix_fireworkscrate : %b (%s)", g_bCvar_FireworksCrate, g_bCvar_FireworksCrate ? "true" : "false");
    if (!g_bL4D2) PrintToConsole(client, "l4d_weapon_prop_give_fix_gascan : %b (%s)", g_bCvar_Gascan, g_bCvar_Gascan ? "true" : "false");
    PrintToConsole(client, "");
    PrintToConsole(client, "======================================================================");
    PrintToConsole(client, "");

    return Plugin_Handled;
}

// ====================================================================================================
// Helpers
// ====================================================================================================
/**
 * Validates if is a valid entity index (between MaxClients+1 and 2048).
 *
 * @param entity        Entity index.
 * @return              True if entity index is valid, false otherwise.
 */
bool IsValidEntityIndex(int entity)
{
    return (MaxClients+1 <= entity <= GetMaxEntities());
}