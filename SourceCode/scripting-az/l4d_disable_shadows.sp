/**
// ====================================================================================================
Change Log:

1.0.1 (08-September-2021)
    - Fixed an error while changing sv_cheats before map load. (thanks "VladimirTk" for reporting)
    - Fixed shadows restoring while changing sv_cheats cvar. (thanks "kadabra" for reporting)

1.0.0 (03-Janurary-2021)
    - Initial release.

// ====================================================================================================
*/

// ====================================================================================================
// Plugin Info - define
// ====================================================================================================
#define PLUGIN_NAME                   "[L4D1 & L4D2] Disable Shadows"
#define PLUGIN_AUTHOR                 "Mart"
#define PLUGIN_DESCRIPTION            "Disables all shadows from the map"
#define PLUGIN_VERSION                "1.0.1"
#define PLUGIN_URL                    "https://forums.alliedmods.net/showthread.php?t=329694"

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
#define CONFIG_FILENAME               "l4d_disable_shadows"

// ====================================================================================================
// Defines
// ====================================================================================================
#define CLASSNAME_SHADOW_CONTROL      "shadow_control"

// ====================================================================================================
// Plugin Cvars
// ====================================================================================================
static ConVar g_hCvar_Enabled;

// ====================================================================================================
// bool - Plugin Variables
// ====================================================================================================
static bool   g_bMapStarted;
static bool   g_bConfigLoaded;
static bool   g_bCvar_Enabled;
static bool   g_bShadowsDisabled;

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
    CreateConVar("l4d_disable_shadows_version", PLUGIN_VERSION, PLUGIN_DESCRIPTION, CVAR_FLAGS_PLUGIN_VERSION);
    g_hCvar_Enabled = CreateConVar("l4d_disable_shadows_enable", "1", "Enable/Disable the plugin.\n0 = Disable, 1 = Enable.", CVAR_FLAGS, true, 0.0, true, 1.0);

    // Hook plugin ConVars change
    FindConVar("sv_cheats").AddChangeHook(SvCheats_ConVarChanged); // sv_cheats changes rollback shadow settings
    g_hCvar_Enabled.AddChangeHook(Event_ConVarChanged);

    // Load plugin configs from .cfg
    AutoExecConfig(true, CONFIG_FILENAME);

    // Admin Commands
    RegAdminCmd("sm_shadowstoggle", CmdToggle, ADMFLAG_ROOT, "Toggle shadows.");
    RegAdminCmd("sm_shadowsenable", CmdEnable, ADMFLAG_ROOT, "Enable shadows.");
    RegAdminCmd("sm_shadowsdisable", CmdDisable, ADMFLAG_ROOT, "Disable shadows.");
    RegAdminCmd("sm_print_cvars_l4d_disable_shadows", CmdPrintCvars, ADMFLAG_ROOT, "Print the plugin related cvars and their respective values to the console.");
}

/****************************************************************************************************/

public void OnMapStart()
{
    g_bMapStarted = true;
}

/****************************************************************************************************/

public void OnMapEnd()
{
    g_bMapStarted = false;
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

    LateLoad();
}

/****************************************************************************************************/

public void SvCheats_ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    RequestFrame(OnNextFrameSvCheats, 4); // Fix sv_cheats restoring the shadows
}

/****************************************************************************************************/

void OnNextFrameSvCheats(int remaining)
{
    if (remaining == 0)
        return;

    g_bShadowsDisabled = !g_bShadowsDisabled;

    LateLoad();

    RequestFrame(OnNextFrameSvCheats, --remaining);
}

/****************************************************************************************************/

public void GetCvars()
{
    g_bCvar_Enabled = g_hCvar_Enabled.BoolValue;
    g_bShadowsDisabled = g_bCvar_Enabled;
}

/****************************************************************************************************/

public void LateLoad()
{
    if (!g_bMapStarted)
        return;

    if (!g_bCvar_Enabled)
        return;

    int entity;

    entity = INVALID_ENT_REFERENCE;
    if (FindEntityByClassname(entity, CLASSNAME_SHADOW_CONTROL) == INVALID_ENT_REFERENCE)
    {
        entity = CreateEntityByName(CLASSNAME_SHADOW_CONTROL); // Fix for maps that doesn't have a "shadow_control" entity
        DispatchKeyValue(entity, "targetname", "l4d_disable_shadows");

        DispatchSpawn(entity);
        ActivateEntity(entity);
    }

    entity = INVALID_ENT_REFERENCE;
    while ((entity = FindEntityByClassname(entity, CLASSNAME_SHADOW_CONTROL)) != INVALID_ENT_REFERENCE)
    {
        SetEntProp(entity, Prop_Send, "m_bDisableShadows", g_bShadowsDisabled);
    }
}

/****************************************************************************************************/

public void OnEntityCreated(int entity, const char[] classname)
{
    if (!g_bConfigLoaded)
        return;

    if (!g_bCvar_Enabled)
        return;

    if (!IsValidEntityIndex(entity))
        return;

    if (classname[0] != 's' && classname[1] != 'h') // shadow_control
       return;

    if (StrEqual(classname, CLASSNAME_SHADOW_CONTROL))
    {
        SetEntProp(entity, Prop_Send, "m_bDisableShadows", g_bShadowsDisabled);
    }
}

// ====================================================================================================
// Admin Commands
// ====================================================================================================
public Action CmdToggle(int client, int args)
{
    g_bShadowsDisabled = !g_bShadowsDisabled;

    LateLoad();

    if (IsValidClient(client))
        PrintToChat(client, "Shadows %s", g_bShadowsDisabled ? "Disabled" : "Enabled");

    return Plugin_Handled;
}

/****************************************************************************************************/

public Action CmdEnable(int client, int args)
{
    g_bShadowsDisabled = false;

    LateLoad();

    if (IsValidClient(client))
        PrintToChat(client, "Shadows %s", g_bShadowsDisabled ? "Disabled" : "Enabled");

    return Plugin_Handled;
}

/****************************************************************************************************/

public Action CmdDisable(int client, int args)
{
    g_bShadowsDisabled = true;

    LateLoad();

    if (IsValidClient(client))
        PrintToChat(client, "Shadows %s", g_bShadowsDisabled ? "Disabled" : "Enabled");

    return Plugin_Handled;
}

/****************************************************************************************************/

public Action CmdPrintCvars(int client, int args)
{
    PrintToConsole(client, "");
    PrintToConsole(client, "======================================================================");
    PrintToConsole(client, "");
    PrintToConsole(client, "----------------- Plugin Cvars (l4d_disable_shadows) -----------------");
    PrintToConsole(client, "");
    PrintToConsole(client, "l4d_disable_shadows_version : %s", PLUGIN_VERSION);
    PrintToConsole(client, "l4d_disable_shadows_enable : %b (%s)", g_bCvar_Enabled, g_bCvar_Enabled ? "true" : "false");
    PrintToConsole(client, "----------------------------------------------------------------------");
    PrintToConsole(client, "");
    PrintToConsole(client, "Current Shadow Status : %s", g_bShadowsDisabled ? "Disabled" : "Enabled");
    PrintToConsole(client, "");
    PrintToConsole(client, "======================================================================");
    PrintToConsole(client, "");

    return Plugin_Handled;
}

// ====================================================================================================
// Helpers
// ====================================================================================================
/**
 * Validates if is a valid client index.
 *
 * @param client        Client index.
 * @return              True if client index is valid, false otherwise.
 */
bool IsValidClientIndex(int client)
{
    return (1 <= client <= MaxClients);
}

/****************************************************************************************************/

/**
 * Validates if is a valid client.
 *
 * @param client        Client index.
 * @return              True if client index is valid and client is in game, false otherwise.
 */
bool IsValidClient(int client)
{
    return (IsValidClientIndex(client) && IsClientInGame(client));
}

/****************************************************************************************************/

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