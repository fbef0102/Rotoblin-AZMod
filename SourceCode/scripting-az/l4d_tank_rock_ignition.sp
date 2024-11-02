//移除AutoExecConfig

/**
// ====================================================================================================
Change Log:

1.1.0 (17-April-2021)
    - New version released.
    - Fixed some hook errors. (thanks "Shadowart" for reporting)

1.0.0 (26-April-2019)
    - Initial release.

// ====================================================================================================
*/

// ====================================================================================================
// Plugin Info - define
// ====================================================================================================
#define PLUGIN_NAME                   "[L4D1 & L4D2] Tank Rock Ignition"
#define PLUGIN_AUTHOR                 "Mart"
#define PLUGIN_DESCRIPTION            "Ignites the rock thrown by the Tank when he is on fire"
#define PLUGIN_VERSION                "1.1.0"
#define PLUGIN_URL                    "https://forums.alliedmods.net/showthread.php?t=315822"

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
#define CONFIG_FILENAME               "l4d_tank_rock_ignition"

// ====================================================================================================
// Defines
// ====================================================================================================
#define MODEL_CONCRETE_CHUNK          "models/props_debris/concrete_chunk01a.mdl"
#define MODEL_TREE_TRUNK              "models/props_foliage/tree_trunk.mdl"

#define TYPE_CONCRETE_CHUNK           (1 << 0) // 1 | 001
#define TYPE_TREE_TRUNK               (1 << 1) // 2 | 010
#define TYPE_UNKNOWN                  (0 << 2) // 4 | 100

#define MAXENTITIES                   2048

// ====================================================================================================
// Plugin Cvars
// ====================================================================================================
ConVar g_hCvar_Enabled;
ConVar g_hCvar_Always;
ConVar g_hCvar_IgnoreFireDamage;
ConVar g_hCvar_BurnOnAir;
ConVar g_hCvar_ModelType;
ConVar g_hCvar_DmgMultiplier;
ConVar g_hCvar_FireDuration;
ConVar g_hCvar_VictimFireDuration;

// ====================================================================================================
// bool - Plugin Cvar Variables
// ====================================================================================================
bool g_bCvar_Enabled;
bool g_bCvar_Always;
bool g_bCvar_IgnoreFireDamage;
bool g_bCvar_BurnOnAir;
bool g_bCvar_DmgMultiplier;
bool g_bCvar_FireDuration;
bool g_bCvar_VictimFireDuration;

// ====================================================================================================
// int - Plugin Cvar Variables
// ====================================================================================================
int g_iCvar_ModelType;

// ====================================================================================================
// float - Plugin Cvar Variables
// ====================================================================================================
float g_fCvar_DmgMultiplier;
float g_fCvar_FireDuration;
float g_fCvar_VictimFireDuration;

// ====================================================================================================
// client - Plugin Variables
// ====================================================================================================
bool gc_bTakeDamageHooked[MAXPLAYERS+1];

// ====================================================================================================
// entity - Plugin Variables
// ====================================================================================================
bool ge_bIsValidTankRock[MAXENTITIES+1];

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
    CreateConVar("l4d_tank_rock_ignition_version", PLUGIN_VERSION, PLUGIN_DESCRIPTION, CVAR_FLAGS_PLUGIN_VERSION);
    g_hCvar_Enabled            = CreateConVar("l4d_tank_rock_ignition_enable", "1", "Enable/Disable the plugin.\n0 = Disable, 1 = Enable.", CVAR_FLAGS, true, 0.0, true, 1.0);
    g_hCvar_Always             = CreateConVar("l4d_tank_rock_ignition_always", "0", "Should the Tank rock always start on fire?\n0 = Ignite the rock only if the Tank is set on fire, 1 = Always ignite the rocks.", CVAR_FLAGS, true, 0.0, true, 1.0);
    g_hCvar_IgnoreFireDamage   = CreateConVar("l4d_tank_rock_ignore_fire_damage", "1", "Rocks ignore fire damage, otherwise, it loses HP over time when on fire.\n0 = OFF, 1 = ON.", CVAR_FLAGS, true, 0.0, true, 1.0);
    g_hCvar_BurnOnAir          = CreateConVar("l4d_tank_rock_ignition_burn_on_air", "1", "Allow igniting the rock in the air after it has been thrown.\nThis option will ignite the rock if it is hit by incendiary ammunition or if it go through the fire.\n0 = OFF, 1 = ON.", CVAR_FLAGS, true, 0.0, true, 1.0);
    g_hCvar_ModelType          = CreateConVar("l4d_tank_rock_ignition_model_type", "3", "Which models can be ignited.\n0 = NONE, 1 = ROCK, 2 = TRUNK, 4 = UNKNOWN.\nAdd numbers greater than 0 for multiple options.\nExample: \"3\", enables for \"ROCK\" (1) and \"TRUNK\" (2).", CVAR_FLAGS, true, 1.0, true, 7.0);
    g_hCvar_DmgMultiplier      = CreateConVar("l4d_tank_rock_ignition_dmg_multiplier", "0.0", "Damage bonus % multiplier for Tank rocks on fire.\nExample: \"10\" gives +10% damage from an ignited rock.\n0 = OFF.", CVAR_FLAGS, true, -100.0);
    g_hCvar_FireDuration       = CreateConVar("l4d_tank_rock_ignition_fire_duration", "60.0", "How long (in seconds) the rock will be set on fire.\n0 = OFF.", CVAR_FLAGS, true, 0.0);
    g_hCvar_VictimFireDuration = CreateConVar("l4d_tank_rock_ignition_victim_fire_duration", "0.0", "How long (in seconds) the victim will be set on fire after being hit by a rock.\n0 = OFF.", CVAR_FLAGS, true, 0.0);

    // Hook plugin ConVars change
    g_hCvar_Enabled.AddChangeHook(Event_ConVarChanged);
    g_hCvar_Always.AddChangeHook(Event_ConVarChanged);
    g_hCvar_IgnoreFireDamage.AddChangeHook(Event_ConVarChanged);
    g_hCvar_BurnOnAir.AddChangeHook(Event_ConVarChanged);
    g_hCvar_ModelType.AddChangeHook(Event_ConVarChanged);
    g_hCvar_DmgMultiplier.AddChangeHook(Event_ConVarChanged);
    g_hCvar_FireDuration.AddChangeHook(Event_ConVarChanged);
    g_hCvar_VictimFireDuration.AddChangeHook(Event_ConVarChanged);

    // Load plugin configs from .cfg
    //AutoExecConfig(true, CONFIG_FILENAME);

    // Admin Commands
    RegAdminCmd("sm_print_cvars_l4d_tank_rock_ignition", CmdPrintCvars, ADMFLAG_ROOT, "Prints the plugin related cvars and their respective values to the console.");
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
}

/****************************************************************************************************/

void GetCvars()
{
    g_bCvar_Enabled = g_hCvar_Enabled.BoolValue;
    g_bCvar_Always = g_hCvar_Always.BoolValue;
    g_bCvar_IgnoreFireDamage = g_hCvar_IgnoreFireDamage.BoolValue;
    g_bCvar_BurnOnAir = g_hCvar_BurnOnAir.BoolValue;
    g_iCvar_ModelType = g_hCvar_ModelType.IntValue;
    g_fCvar_DmgMultiplier = g_hCvar_DmgMultiplier.FloatValue;
    g_bCvar_DmgMultiplier = g_fCvar_DmgMultiplier != 0.0;
    g_fCvar_FireDuration = g_hCvar_FireDuration.FloatValue;
    g_bCvar_FireDuration = (g_fCvar_FireDuration > 0.0);
    g_fCvar_VictimFireDuration = g_hCvar_VictimFireDuration.FloatValue;
    g_bCvar_VictimFireDuration = (g_fCvar_VictimFireDuration > 0.0);
}

/****************************************************************************************************/

void LateLoad()
{
    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsClientInGame(client))
            continue;

        OnClientPutInServer(client);
    }

    int entity;

    entity = INVALID_ENT_REFERENCE;
    while ((entity = FindEntityByClassname(entity, "tank_rock")) != INVALID_ENT_REFERENCE)
    {
        RequestFrame(OnTankRockNextFrame, EntIndexToEntRef(entity));
    }
}

/****************************************************************************************************/

public void OnClientPutInServer(int client)
{
    if (gc_bTakeDamageHooked[client])
        return;

    gc_bTakeDamageHooked[client] = true;
    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamageFromRock);
}

/****************************************************************************************************/

public void OnClientDisconnect(int client)
{
    gc_bTakeDamageHooked[client] = false;
}

/****************************************************************************************************/

public void OnEntityCreated(int entity, const char[] classname)
{
    if (entity < 0)
        return;

    if (StrEqual(classname, "tank_rock"))
        RequestFrame(OnTankRockNextFrame, EntIndexToEntRef(entity));
}

/****************************************************************************************************/

public void OnEntityDestroyed(int entity)
{
    if (entity < 0)
        return;

    ge_bIsValidTankRock[entity] = false;
}

/****************************************************************************************************/

void OnTankRockNextFrame(int entityRef)
{
    if (!g_bCvar_Enabled)
        return;

    if (!g_bCvar_FireDuration)
        return;

    int entity = EntRefToEntIndex(entityRef);

    if (entity == INVALID_ENT_REFERENCE)
        return;

    if (!(GetRockType(entity) & g_iCvar_ModelType))
        return;

    ge_bIsValidTankRock[entity] = true;

    SDKHook(entity, SDKHook_OnTakeDamage, OnTakeDamage);
    SDKHook(entity, SDKHook_OnTakeDamageAlivePost, OnTakeDamageAlivePost);

    if (g_bCvar_Always)
        IgniteEntity(entity, g_fCvar_FireDuration);
    else
        RequestFrame(OnNextFrame, EntIndexToEntRef(entity));
}

/****************************************************************************************************/

void OnNextFrame(int entityRef)
{
    if (!g_bCvar_Enabled)
        return;

    if (!g_bCvar_FireDuration)
        return;

    int entity = EntRefToEntIndex(entityRef);

    if (entity == INVALID_ENT_REFERENCE)
        return;

    int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");

    if (!IsValidClientIndex(client))
        return;

    if (IsEntityOnFire(client))
        IgniteEntity(entity, g_fCvar_FireDuration);

    if (GetEntProp(entity, Prop_Send, "movecollide") != 0)
        return;

    RequestFrame(OnNextFrame, EntIndexToEntRef(entity));
}

/****************************************************************************************************/

Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
    if (!g_bCvar_Enabled)
        return Plugin_Continue;

    if (!g_bCvar_IgnoreFireDamage)
        return Plugin_Continue;

    if (attacker != inflictor)
        return Plugin_Continue;

    if (!IsValidEntity(attacker))
        return Plugin_Continue;

    if (!HasEntProp(attacker, Prop_Send, "m_bCheapEffect")) // CEntityFlame
        return Plugin_Continue;

    if (!(damagetype & DMG_BURN))
        return Plugin_Continue;

    damage = 0.0;
    return Plugin_Changed;
}

/****************************************************************************************************/

void OnTakeDamageAlivePost(int victim, int attacker, int inflictor, float damage, int damagetype, int weapon, const float damageForce[3], const float damagePosition[3])
{
    if (!g_bCvar_Enabled)
        return;

    if (!g_bCvar_BurnOnAir)
        return;

    if (!g_bCvar_FireDuration)
        return;

    if (damagetype & DMG_BURN)
        IgniteEntity(victim, g_fCvar_FireDuration);
}

/****************************************************************************************************/

Action OnTakeDamageFromRock(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
    if (!g_bCvar_Enabled)
        return Plugin_Continue;

    if (!g_bCvar_DmgMultiplier)
        return Plugin_Continue;

    if (IsValidClientIndex(inflictor))
        return Plugin_Continue;

    if (!ge_bIsValidTankRock[inflictor])
        return Plugin_Continue;

    if (!IsEntityOnFire(inflictor))
        return Plugin_Continue;

    if (!IsValidClient(victim))
        return Plugin_Continue;

    if (g_bCvar_VictimFireDuration)
        IgniteEntity(victim, g_fCvar_VictimFireDuration);

    if (g_bCvar_DmgMultiplier)
    {
        damage += (damage * g_fCvar_DmgMultiplier / 100.0);
        return Plugin_Changed;
    }

    return Plugin_Continue;
}

/****************************************************************************************************/

int GetRockType(int entity)
{
    char modelname[PLATFORM_MAX_PATH];
    GetEntPropString(entity, Prop_Data, "m_ModelName", modelname, sizeof(modelname));
    StringToLowerCase(modelname);

    if (StrEqual(modelname, MODEL_CONCRETE_CHUNK))
        return TYPE_CONCRETE_CHUNK;

    if (StrEqual(modelname, MODEL_TREE_TRUNK))
        return TYPE_TREE_TRUNK;

    return TYPE_UNKNOWN;
}

// ====================================================================================================
// Admin Commands
// ====================================================================================================
Action CmdPrintCvars(int client, int args)
{
    PrintToConsole(client, "");
    PrintToConsole(client, "======================================================================");
    PrintToConsole(client, "");
    PrintToConsole(client, "---------------- Plugin Cvars (l4d_tank_rock_ignition) ---------------");
    PrintToConsole(client, "");
    PrintToConsole(client, "l4d_tank_rock_ignition_version : %s", PLUGIN_VERSION);
    PrintToConsole(client, "l4d_tank_rock_ignition_enabled : %b (%s)", g_bCvar_Enabled, g_bCvar_Enabled ? "true" : "false");
    PrintToConsole(client, "l4d_tank_rock_ignition_always : %b (%s)", g_bCvar_Always, g_bCvar_Always ? "true" : "false");
    PrintToConsole(client, "l4d_tank_rock_ignore_fire_damage : %b (%s)", g_bCvar_IgnoreFireDamage, g_bCvar_IgnoreFireDamage ? "true" : "false");
    PrintToConsole(client, "l4d_tank_rock_ignition_burn_on_air : %b", g_bCvar_BurnOnAir, g_bCvar_BurnOnAir ? "true" : "false");
    PrintToConsole(client, "l4d_tank_rock_ignition_model_type : %i", g_iCvar_ModelType);
    PrintToConsole(client, "l4d_tank_rock_ignition_dmg_multiplier : %.1f%%", g_fCvar_DmgMultiplier);
    PrintToConsole(client, "l4d_tank_rock_ignition_fire_duration : %.1f", g_fCvar_FireDuration);
    PrintToConsole(client, "l4d_tank_rock_ignition_victim_fire_duration : %.1f", g_fCvar_VictimFireDuration);
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
 * @param client          Client index.
 * @return                True if client index is valid, false otherwise.
 */
bool IsValidClientIndex(int client)
{
    return (1 <= client <= MaxClients);
}

/****************************************************************************************************/

/**
 * Validates if is a valid client.
 *
 * @param client          Client index.
 * @return                True if client index is valid and client is in game, false otherwise.
 */
bool IsValidClient(int client)
{
    return (IsValidClientIndex(client) && IsClientInGame(client));
}

/****************************************************************************************************/

/**
 * Validates if the entity is on fire.
 *
 * @param entity        Entity index.
 * @return              True if entity is on fire, false otherwise.
 */
bool IsEntityOnFire(int entity)
{
    return (GetEntityFlags(entity) & FL_ONFIRE ? true : false);
}

/****************************************************************************************************/

/**
 * Converts the string to lower case.
 *
 * @param input         Input string.
 */
void StringToLowerCase(char[] input)
{
    for (int i = 0; i < strlen(input); i++)
    {
        input[i] = CharToLower(input[i]);
    }
}