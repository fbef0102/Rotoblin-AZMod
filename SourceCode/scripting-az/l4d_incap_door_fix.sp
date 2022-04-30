/**
// ====================================================================================================
Change Log:

1.0.2 (21-April-2022)
    - Added infected attacker exploit check for L4D1. (thanks "HarryPotter" for reporting)

1.0.1 (21-April-2022)
    - Fixed hook loading order.

1.0.0 (16-April-2022)
    - Initial release.

// ====================================================================================================
*/

// ====================================================================================================
// Plugin Info - define
// ====================================================================================================
#define PLUGIN_NAME                   "[L4D1 & L4D2] Choose Door Fix for Incapacitated Survivors"
#define PLUGIN_AUTHOR                 "Mart"
#define PLUGIN_DESCRIPTION            "Fixes an exploit that allows incapacitated survivors to open/close doors with 'choose_opendoor' / 'choose_closedoor' console commands"
#define PLUGIN_VERSION                "1.0.2"
#define PLUGIN_URL                    "https://forums.alliedmods.net/showthread.php?t=337376"

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
#define CONFIG_FILENAME               "l4d_incap_door_fix"

// ====================================================================================================
// Plugin Cvars
// ====================================================================================================
static ConVar g_hCvar_Enabled;

// ====================================================================================================
// bool - Plugin Variables
// ====================================================================================================
static bool   g_bL4D2;
static bool   g_bEventsHooked;
static bool   g_bCvar_Enabled;

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
    CreateConVar("l4d_incap_door_fix_version", PLUGIN_VERSION, PLUGIN_DESCRIPTION, CVAR_FLAGS_PLUGIN_VERSION);
    g_hCvar_Enabled = CreateConVar("l4d_incap_door_fix_enable", "1", "Enable/Disable the plugin.\n0 = Disable, 1 = Enable.", CVAR_FLAGS, true, 0.0, true, 1.0);

    // Hook plugin ConVars change
    g_hCvar_Enabled.AddChangeHook(Event_ConVarChanged);

    // Load plugin configs from .cfg
    AutoExecConfig(true, CONFIG_FILENAME);

    // Admin Commands
    RegAdminCmd("sm_print_cvars_l4d_incap_door_fix", CmdPrintCvars, ADMFLAG_ROOT, "Print the plugin related cvars and their respective values to the console.");
}

/****************************************************************************************************/

public void OnConfigsExecuted()
{
    GetCvars();

    HookEvents();
}

/****************************************************************************************************/

public void Event_ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    GetCvars();

    HookEvents();
}

/****************************************************************************************************/

public void GetCvars()
{
    g_bCvar_Enabled = g_hCvar_Enabled.BoolValue;
}

/****************************************************************************************************/

public void HookEvents()
{
    if (g_bCvar_Enabled && !g_bEventsHooked)
    {
        g_bEventsHooked = true;

        if (g_bL4D2)
        {
            AddCommandListener(Command_ChooseDoorL4D2, "choose_opendoor");
            AddCommandListener(Command_ChooseDoorL4D2, "choose_closedoor");
        }
        else
        {
            AddCommandListener(Command_ChooseDoorL4D1, "choose_opendoor");
            AddCommandListener(Command_ChooseDoorL4D1, "choose_closedoor");
        }

        return;
    }

    if (!g_bCvar_Enabled && g_bEventsHooked)
    {
        g_bEventsHooked = false;

        if (g_bL4D2)
        {
            RemoveCommandListener(Command_ChooseDoorL4D2, "choose_opendoor");
            RemoveCommandListener(Command_ChooseDoorL4D2, "choose_closedoor");
        }
        else
        {
            RemoveCommandListener(Command_ChooseDoorL4D1, "choose_opendoor");
            RemoveCommandListener(Command_ChooseDoorL4D1, "choose_closedoor");
        }

        return;
    }
}

/****************************************************************************************************/

public Action Command_ChooseDoorL4D2(int client, const char[] command, int argc)
{
    if (IsPlayerIncapacitated(client))
        return Plugin_Handled;

    return Plugin_Continue;
}

/****************************************************************************************************/

public Action Command_ChooseDoorL4D1(int client, const char[] command, int argc)
{
    if (IsPlayerIncapacitated(client))
        return Plugin_Handled;

    if (IsPlayerImmobilized(client))
        return Plugin_Handled;

    return Plugin_Continue;
}

// ====================================================================================================
// Admin Commands
// ====================================================================================================
public Action CmdPrintCvars(int client, int args)
{
    PrintToConsole(client, "");
    PrintToConsole(client, "======================================================================");
    PrintToConsole(client, "");
    PrintToConsole(client, "----------------- Plugin Cvars (l4d_incap_door_fix) ------------------");
    PrintToConsole(client, "");
    PrintToConsole(client, "l4d_incap_door_fix_version : %s", PLUGIN_VERSION);
    PrintToConsole(client, "l4d_incap_door_fix_enable : %b (%s)", g_bCvar_Enabled, g_bCvar_Enabled ? "true" : "false");
    PrintToConsole(client, "");
    PrintToConsole(client, "----------------------------------------------------------------------");
    PrintToConsole(client, "");
    PrintToConsole(client, "Game: %s", g_bL4D2 ? "L4D2" : "L4D1");
    PrintToConsole(client, "");
    PrintToConsole(client, "======================================================================");
    PrintToConsole(client, "");

    return Plugin_Handled;
}

// ====================================================================================================
// Helpers
// ====================================================================================================
/**
 * Validates if the client is incapacitated.
 *
 * @param client        Client index.
 * @return              True if the client is incapacitated, false otherwise.
 */
bool IsPlayerIncapacitated(int client)
{
    return (GetEntProp(client, Prop_Send, "m_isIncapacitated") == 1);
}

/****************************************************************************************************/

/**
 * Validates if the client is immobilized by a special infected.
 *
 * @param client        Client index.
 * @return              True if the client is immobilized by a special infected, false otherwise.
 */
bool IsPlayerImmobilized(int client)
{
    if (GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") != -1) // Hunter
        return true;

    if (GetEntPropEnt(client, Prop_Send, "m_tongueOwner") != -1) // Smoker
        return true;

    if (g_bL4D2)
    {
        if (GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") != -1) // Jockey
            return true;

        if (GetEntPropEnt(client, Prop_Send, "m_carryAttacker") != -1) // Charger
            return true;

        if (GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") != -1) // Charger
            return true;
    }

    return false;
}