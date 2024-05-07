/**
// ====================================================================================================
Change Log:

Change Log:
1.0.3 (20-9-2022)
    - Add Map on filter option (data/mapinfo.txt support)
    - Witch only
    - L4D1 only

1.0.5 (10-March-2022)
    - Original Plugin by Mart: https://forums.alliedmods.net/showthread.php?t=328929

// ====================================================================================================
*/

// ====================================================================================================
// Plugin Info - define
// ====================================================================================================
#define PLUGIN_NAME                   "[L4D2] Random Witch Models"
#define PLUGIN_AUTHOR                 "Mart, Harry"
#define PLUGIN_DESCRIPTION            "Turn the special infected models more random"
#define PLUGIN_VERSION                "1.0.7"
#define PLUGIN_URL                    "https://forums.alliedmods.net/showthread.php?t=328929"

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
#define CONFIG_FILENAME               "l4d1_random_witch_model"

// ====================================================================================================
// Defines
// ====================================================================================================
#define L4D1_ZOMBIECLASS_WITCH        7

#define TEAM_INFECTED                 3

#define MODEL_WITCH                   "models/infected/witch.mdl"
#define MODEL_WITCH_BRIDE             "models/infected/witch_bride.mdl"

#define TYPE_WITCH                    1
#define TYPE_WITCH_BRIDE              2

// ====================================================================================================
// Plugin Cvars
// ====================================================================================================
ConVar g_hCvar_Enabled;
ConVar g_hCvar_Witch;
ConVar g_hCvar_WitchChance;

// ====================================================================================================
// bool - Plugin Variables
// ====================================================================================================
bool g_bEventsHooked;
bool g_bCvar_Enabled;
bool g_bValidMap;

// ====================================================================================================
// int - Plugin Variables
// ====================================================================================================
static int    g_iCvar_Witch;
static int    g_iCvar_WitchChance;

// ====================================================================================================
// ArrayList - Plugin Variables
// ====================================================================================================
static ArrayList g_alWitch;

// ====================================================================================================
// Plugin Start
// ====================================================================================================
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    EngineVersion engine = GetEngineVersion();

    if (engine != Engine_Left4Dead)
    {
        strcopy(error, err_max, "This plugin only runs in \"Left 4 Dead 1\" game");
        return APLRes_SilentFailure;
    }

    g_alWitch = new ArrayList();

    return APLRes_Success;
}

/****************************************************************************************************/

static KeyValues g_hMIData = null;

public void OnPluginStart()
{
    CreateConVar("l4d1_random_witch_model_version", PLUGIN_VERSION, PLUGIN_DESCRIPTION, CVAR_FLAGS_PLUGIN_VERSION);
    g_hCvar_Enabled       = CreateConVar("l4d1_random_witch_model_enable", "1", "Enable/Disable the plugin.\n0 = Disable, 1 = Enable.", CVAR_FLAGS, true, 0.0, true, 1.0);
    g_hCvar_Witch         = CreateConVar("l4d1_random_witch_model_witch", "2", "Random model for Witch.\n0 = Disable. 1 = Enable Witch model. 2 = Enable Witch Bride model.\nAdd numbers greater than 0 for multiple options.\nExample: \"3\", enables the Witch and Witch Bride model.", CVAR_FLAGS, true, 0.0, true, 3.0);
    g_hCvar_WitchChance   = CreateConVar("l4d1_random_witch_model_witch_chance", "100", "Chance to apply a random model for Witch.\n0 = OFF.", CVAR_FLAGS, true, 0.0, true, 100.0);
 
    // Hook plugin ConVars change
    g_hCvar_Witch.AddChangeHook(Event_ConVarChanged);
    g_hCvar_WitchChance.AddChangeHook(Event_ConVarChanged);

    // Load plugin configs from .cfg
    //AutoExecConfig(true, CONFIG_FILENAME);

    // Admin Commands
    RegAdminCmd("sm_print_cvars_l4d1_random_witch_model", CmdPrintCvars, ADMFLAG_ROOT, "Print the plugin related cvars and their respective values to the console.");

    MI_KV_Load();
}

/****************************************************************************************************/

public void OnMapStart()
{
    g_bValidMap = false;
    char sMap[64];
    GetCurrentMap(sMap, sizeof(sMap));

    MI_KV_Close();
    MI_KV_Load();
    if (!KvJumpToKey(g_hMIData, sMap)) {
        //LogError("[MI] MapInfo for %s is missing.", g_sCurMap);
    } else
    {
        if (g_hMIData.GetNum("BridgeWitch_map", 0) == 1)
        {
            g_bValidMap = true;
        }
    }
    KvRewind(g_hMIData);

    if(g_bValidMap)
    {
        PrecacheModel(MODEL_WITCH, true);
        PrecacheModel(MODEL_WITCH_BRIDE, true);
    }
}

public void OnMapEnd()
{
    g_bValidMap = false;
}

/****************************************************************************************************/

public void OnConfigsExecuted()
{
    GetCvars();

    LateLoad();

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
    g_iCvar_Witch = g_hCvar_Witch.IntValue;
    g_iCvar_WitchChance = g_hCvar_WitchChance.IntValue;

    BuildStringMaps();
}

/****************************************************************************************************/

public void BuildStringMaps()
{
    delete g_alWitch;
    g_alWitch = new ArrayList();

    if (g_iCvar_Witch & TYPE_WITCH)
        g_alWitch.Push(TYPE_WITCH);
    if (g_iCvar_Witch & TYPE_WITCH_BRIDE)
        g_alWitch.Push(TYPE_WITCH_BRIDE);
}

/****************************************************************************************************/

public void LateLoad()
{
    if(!g_bValidMap) 
        return;

    int entity;

    entity = INVALID_ENT_REFERENCE;
    while ((entity = FindEntityByClassname(entity, "witch")) != INVALID_ENT_REFERENCE)
    {
       SetSpecialInfectedModel(entity, L4D1_ZOMBIECLASS_WITCH);
    }
}

/****************************************************************************************************/

public void HookEvents()
{
    if (g_bCvar_Enabled && !g_bEventsHooked)
    {
        g_bEventsHooked = true;

        HookEvent("witch_spawn", Event_WitchSpawn);

        return;
    }

    if (!g_bCvar_Enabled && g_bEventsHooked)
    {
        g_bEventsHooked = false;

        UnhookEvent("witch_spawn", Event_WitchSpawn);

        return;
    }
}

/****************************************************************************************************/

public void Event_WitchSpawn(Event event, const char[] name, bool dontBroadcast)
{
    if(!g_bValidMap) 
        return;

    int entity = event.GetInt("witchid");
    SetSpecialInfectedModel(entity, L4D1_ZOMBIECLASS_WITCH);
}

/****************************************************************************************************/

public void SetSpecialInfectedModel(int entity, int zombieclass)
{
    switch (zombieclass)
    {
        case L4D1_ZOMBIECLASS_WITCH:
        {
            if (g_iCvar_WitchChance < GetRandomInt(1, 100))
                return;

            if (g_alWitch.Length == 0)
                return;

            switch (g_alWitch.Get(GetRandomInt(0, g_alWitch.Length-1)))
            {
                case 1: SetEntityModel(entity, MODEL_WITCH);
                case 2: SetEntityModel(entity, MODEL_WITCH_BRIDE);
            }
        }
    }
}

// ====================================================================================================
// Admin Commands
// ====================================================================================================
public Action CmdPrintCvars(int client, int args)
{
    PrintToConsole(client, "");
    PrintToConsole(client, "======================================================================");
    PrintToConsole(client, "");
    PrintToConsole(client, "---------------- Plugin Cvars (l4d1_random_witch_model) -----------------");
    PrintToConsole(client, "");
    PrintToConsole(client, "l4d1_random_witch_model_version : %s", PLUGIN_VERSION);
    PrintToConsole(client, "l4d1_random_witch_model_enable : %b (%s)", g_bCvar_Enabled, g_bCvar_Enabled ? "true" : "false");
    PrintToConsole(client, "l4d1_random_witch_model_witch : %i (WITCH = %s | WITCH_BRIDE = %s)", g_iCvar_Witch, g_iCvar_Witch & TYPE_WITCH ? "true" : "false", g_iCvar_Witch & TYPE_WITCH_BRIDE ? "true" : "false");
    PrintToConsole(client, "l4d1_random_witch_model_witch_chance : %i%%", g_iCvar_WitchChance);
    PrintToConsole(client, "");
    PrintToConsole(client, "======================================================================");
    PrintToConsole(client, "");

    return Plugin_Handled;
}

void MI_KV_Load()
{
	char sNameBuff[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sNameBuff, 256, "data/%s", "mapinfo.txt");

	g_hMIData = CreateKeyValues("MapInfo");
	if (!FileToKeyValues(g_hMIData, sNameBuff)) {
		//LogError("[MI] Couldn't load MapInfo data!");
		MI_KV_Close();
	}
}

void MI_KV_Close()
{
	if (g_hMIData != null) {
		CloseHandle(g_hMIData);
		g_hMIData = null;
	}
}