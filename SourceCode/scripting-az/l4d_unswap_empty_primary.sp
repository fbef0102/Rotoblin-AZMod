/**
// ====================================================================================================
Change Log:

1.0.0 (29-October-2020)
    - Initial release.

// ====================================================================================================
*/

// ====================================================================================================
// Plugin Info - define
// ====================================================================================================
#define PLUGIN_NAME                   "[L4D1 & L4D2] Unswap Empty Primary Weapon"
#define PLUGIN_AUTHOR                 "Mart"
#define PLUGIN_DESCRIPTION            "Prevents swapping to secondary weapon on primary weapon pick up when its clip is empty"
#define PLUGIN_VERSION                "1.0.0"
#define PLUGIN_URL                    "https://forums.alliedmods.net/showthread.php?t=328179"

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
#define CONFIG_FILENAME               "l4d_unswap_empty_primary"

// ====================================================================================================
// Defines
// ====================================================================================================
#define TEAM_SURVIVOR                 2
#define TEAM_HOLDOUT                  4

// ====================================================================================================
// Plugin Cvars
// ====================================================================================================
static ConVar g_hCvar_Enabled;
static ConVar g_hCvar_IgnoreWithoutAmmo;

// ====================================================================================================
// bool - Plugin Variables
// ====================================================================================================
static bool   g_bConfigLoaded;
static bool   g_bCvar_Enabled;
static bool   g_bCvar_IgnoreWithoutAmmo;

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

    return APLRes_Success;
}

/****************************************************************************************************/

public void OnPluginStart()
{
    CreateConVar("l4d_unswap_empty_primary_version", PLUGIN_VERSION, PLUGIN_DESCRIPTION, CVAR_FLAGS_PLUGIN_VERSION);
    g_hCvar_Enabled           = CreateConVar("l4d_unswap_empty_primary_enable", "1", "Enable/Disable the plugin.\n0 = Disable, 1 = Enable.", CVAR_FLAGS, true, 0.0, true, 1.0);
    g_hCvar_IgnoreWithoutAmmo = CreateConVar("l4d_unswap_empty_primary_ignore_without_ammo", "1", "Ignore weapons without ammo.\n0 = OFF, 1 = ON.", CVAR_FLAGS, true, 0.0, true, 1.0);

    // Hook plugin ConVars change
    g_hCvar_Enabled.AddChangeHook(Event_ConVarChanged);
    g_hCvar_IgnoreWithoutAmmo.AddChangeHook(Event_ConVarChanged);

    // Load plugin configs from .cfg
    AutoExecConfig(true, CONFIG_FILENAME);

    // Admin Commands
    RegAdminCmd("sm_print_cvars_l4d_unswap_empty_primary", CmdPrintCvars, ADMFLAG_ROOT, "Print the plugin related cvars and their respective values to the console.");
}

/****************************************************************************************************/

public void OnMapEnd()
{
    g_bConfigLoaded = false;
}

/****************************************************************************************************/

public void OnConfigsExecuted()
{
    GetCvars();

    g_bConfigLoaded = true;

    LateLoad();
}

/****************************************************************************************************/

public void Event_ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    GetCvars();
}

/****************************************************************************************************/

public void GetCvars()
{
    g_bCvar_Enabled = g_hCvar_Enabled.BoolValue;
    g_bCvar_IgnoreWithoutAmmo = g_hCvar_IgnoreWithoutAmmo.BoolValue;
}

/****************************************************************************************************/

public void LateLoad()
{
    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsClientInGame(client))
            continue;

        OnClientPutInServer(client);
    }
}

/****************************************************************************************************/

public void OnClientPutInServer(int client)
{
    if (!g_bConfigLoaded)
        return;

    if (IsFakeClient(client))
        return;

    SDKHook(client, SDKHook_WeaponEquipPost, OnWeaponEquipPost);
}

/****************************************************************************************************/

public void OnWeaponEquipPost(int client, int weapon)
{
    if (!g_bCvar_Enabled)
        return;

    if (!IsValidEntity(weapon))
        return;

    int team = GetClientTeam(client);

    if (team != TEAM_SURVIVOR && team != TEAM_HOLDOUT)
        return;

    int primaryWeapon = GetPlayerWeaponSlot(client, 0);

    if (weapon != primaryWeapon)
        return;

    int currentAmmo = GetEntProp(weapon, Prop_Send, "m_iClip1", 1);

    if (currentAmmo > 0)
        return;

    int extraAmmo = GetEntProp(weapon, Prop_Send, "m_iExtraPrimaryAmmo");

    if (g_bCvar_IgnoreWithoutAmmo && extraAmmo == 0)
        return;

    SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", weapon);
}

// ====================================================================================================
// Admin Commands
// ====================================================================================================
public Action CmdPrintCvars(int client, int args)
{
    PrintToConsole(client, "");
    PrintToConsole(client, "======================================================================");
    PrintToConsole(client, "");
    PrintToConsole(client, "--------------- Plugin Cvars (l4d_unswap_empty_primary) --------------");
    PrintToConsole(client, "");
    PrintToConsole(client, "l4d_unswap_empty_primary_version : %s", PLUGIN_VERSION);
    PrintToConsole(client, "l4d_unswap_empty_primary_enable : %b (%s)", g_bCvar_Enabled, g_bCvar_Enabled ? "true" : "false");
    PrintToConsole(client, "l4d_unswap_empty_primary_ignore_without_ammo : %b (%s)", g_bCvar_IgnoreWithoutAmmo, g_bCvar_IgnoreWithoutAmmo ? "true" : "false");
    PrintToConsole(client, "");
    PrintToConsole(client, "======================================================================");
    PrintToConsole(client, "");

    return Plugin_Handled;
}