/**
// ====================================================================================================
Change Log:
1.0.3 (20-9-2022)
    - Add Map on filter option (data/mapinfo.txt support)
    - L4D1 only

1.0.2 (29-May-2022)
    - Original Plugin by Mart: https://forums.alliedmods.net/showthread.php?t=334470

// ====================================================================================================
*/

// ====================================================================================================
// Plugin Info - define
// ====================================================================================================
#define PLUGIN_NAME                   "[L4D1 & L4D2] Random Entity Color"
#define PLUGIN_AUTHOR                 "Mart, Harry"
#define PLUGIN_DESCRIPTION            "Gives a random color to entities on the map"
#define PLUGIN_VERSION                "1.0.3"
#define PLUGIN_URL                    "https://forums.alliedmods.net/showthread.php?t=334470"

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
#define CONFIG_FILENAME               "l4d_random_entity_color"
#define DATA_FILENAME                 "l4d_random_entity_color"

// ====================================================================================================
// Defines
#define MODEL_GASCAN                  "models/props_junk/gascan001a.mdl"
#define MODEL_PROPANECANISTER         "models/props_junk/propanecanister001a.mdl"
#define MODEL_OXYGENTANK              "models/props_equipment/oxygentank01.mdl"
#define MODEL_FIREWORKS_CRATE         "models/props_junk/explosive_box001.mdl"

#define CONFIG_ENABLE                 0
#define CONFIG_RANDOM                 1
#define CONFIG_R                      2
#define CONFIG_G                      3
#define CONFIG_B                      4
#define CONFIG_ARRAYSIZE              5

#define MAXENTITIES                   2048

#define NOCOLOR                       -2 // -2 cause some entities has m_clrRender = -1

// ====================================================================================================
// Plugin Cvars
// ====================================================================================================
ConVar g_hCvar_Enabled;

// ====================================================================================================
// bool - Plugin Variables
// ====================================================================================================
bool g_bCvar_Enabled;
bool g_bValidMap;

// ====================================================================================================
// int - Plugin Variables
// ====================================================================================================
int g_iDefaultConfig[CONFIG_ARRAYSIZE];

// ====================================================================================================
// entity - Plugin Variables
// ====================================================================================================
int ge_iRGBA[MAXENTITIES+1] = { NOCOLOR, ... };

// ====================================================================================================
// ArrayList - Plugin Variables
// ====================================================================================================
ArrayList g_alPluginEntities;

// ====================================================================================================
// StringMap - Plugin Variables
// ====================================================================================================
StringMap g_smWeaponIdToClassname;
StringMap g_smMeleeModelToName;
StringMap g_smPropModelToClassname;
StringMap g_smClassnameConfig;
StringMap g_smMeleeConfig;

// ====================================================================================================
// Plugin Start
// ====================================================================================================
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    EngineVersion engine = GetEngineVersion();

    if (engine != Engine_Left4Dead )
    {
        strcopy(error, err_max, "This plugin only runs in \"Left 4 Dead\" game");
        return APLRes_SilentFailure;
    }

    return APLRes_Success;
}

/****************************************************************************************************/

static KeyValues g_hMIData = null;

public void OnPluginStart()
{
    g_alPluginEntities = new ArrayList();
    g_smWeaponIdToClassname = new StringMap();
    g_smMeleeModelToName = new StringMap();
    g_smPropModelToClassname = new StringMap();
    g_smClassnameConfig = new StringMap();
    g_smMeleeConfig = new StringMap();

    BuildMaps();

    LoadConfigs();

    CreateConVar("l4d_random_entity_color_version", PLUGIN_VERSION, PLUGIN_DESCRIPTION, CVAR_FLAGS_PLUGIN_VERSION);
    g_hCvar_Enabled        = CreateConVar("l4d_random_entity_color_enable", "1", "Enable/Disable the plugin.\n0 = Disable, 1 = Enable.", CVAR_FLAGS, true, 0.0, true, 1.0);
    // Hook plugin ConVars change
    g_hCvar_Enabled.AddChangeHook(Event_ConVarChanged);

    // Load plugin configs from .cfg
    //AutoExecConfig(true, CONFIG_FILENAME);

    // Admin Commands
    RegAdminCmd("sm_colorinfo", CmdInfo, ADMFLAG_ROOT, "Outputs to the chat the color info about the entity at your crosshair.");
    RegAdminCmd("sm_colorreload", CmdReload, ADMFLAG_ROOT, "Reload the color configs.");
    RegAdminCmd("sm_colorremove", CmdRemove, ADMFLAG_ROOT, "Remove plugin color from entity at crosshair.");
    RegAdminCmd("sm_colorremoveall", CmdRemoveAll, ADMFLAG_ROOT, "Remove all colors created by the plugin.");
    RegAdminCmd("sm_coloradd", CmdAdd, ADMFLAG_ROOT, "Add color (with default config) to entity at crosshair.");
    RegAdminCmd("sm_colorall", CmdAll, ADMFLAG_ROOT, "Add color (with default config) to everything possible.");
    RegAdminCmd("sm_print_cvars_l4d_random_entity_color", CmdPrintCvars, ADMFLAG_ROOT, "Print the plugin related cvars and their respective values to the console.");

    MI_KV_Load();
}

/****************************************************************************************************/

void BuildMaps()
{
    g_smPropModelToClassname.SetString(MODEL_GASCAN, "weapon_gascan");
    g_smPropModelToClassname.SetString(MODEL_PROPANECANISTER, "weapon_propanetank");
    g_smPropModelToClassname.SetString(MODEL_OXYGENTANK, "weapon_oxygentank");
}

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
        if (g_hMIData.GetNum("GasCan_map", 0) == 1)
        {
            g_bValidMap = true;
        }
    }
    KvRewind(g_hMIData);
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
}

/****************************************************************************************************/

void LoadConfigs()
{
    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "data/%s.cfg", DATA_FILENAME);

    if (!FileExists(path))
    {
        SetFailState("Missing required data file on \"data/%s.cfg\", please re-download.", DATA_FILENAME);
        return;
    }

    KeyValues kv = new KeyValues(DATA_FILENAME);
    kv.ImportFromFile(path);

    delete g_smClassnameConfig;
    delete g_smMeleeConfig;
    g_smClassnameConfig = new StringMap();
    g_smMeleeConfig = new StringMap();

    int default_enable;
    int default_random;
    char default_color[12];

    int iColor[3];

    if (kv.JumpToKey("default"))
    {
        default_enable = kv.GetNum("enable", 0);
        default_random = kv.GetNum("random", 0);
        kv.GetString("color", default_color, sizeof(default_color), "255 255 255");

        iColor = ConvertRGBToIntArray(default_color);

        g_iDefaultConfig[CONFIG_ENABLE] = default_enable;
        g_iDefaultConfig[CONFIG_RANDOM] = default_random;
        g_iDefaultConfig[CONFIG_R] = iColor[0];
        g_iDefaultConfig[CONFIG_G] = iColor[1];
        g_iDefaultConfig[CONFIG_B] = iColor[2];
    }

    kv.Rewind();

    char section[64];
    int enable;
    int random;
    char color[12];

    int config[CONFIG_ARRAYSIZE];

    if (kv.JumpToKey("classnames"))
    {
        if (kv.GotoFirstSubKey())
        {
            do
            {
                enable = kv.GetNum("enable", default_enable);
                if (enable == 0)
                    continue;

                random = kv.GetNum("random", default_random);
                kv.GetString("color", color, sizeof(color), default_color);

                iColor = ConvertRGBToIntArray(color);

                config[CONFIG_ENABLE] = enable;
                config[CONFIG_RANDOM] = random;
                config[CONFIG_R] = iColor[0];
                config[CONFIG_G] = iColor[1];
                config[CONFIG_B] = iColor[2];

                kv.GetSectionName(section, sizeof(section));
                TrimString(section);
                StringToLowerCase(section);

                g_smClassnameConfig.SetArray(section, config, sizeof(config));
            } while (kv.GotoNextKey());
        }
    }

    kv.Rewind();

    if (kv.JumpToKey("melees"))
    {
        if (kv.GotoFirstSubKey())
        {
            do
            {
                enable = kv.GetNum("enable", default_enable);
                if (enable == 0)
                    continue;

                random = kv.GetNum("random", default_random);
                kv.GetString("color", color, sizeof(color), default_color);

                iColor = ConvertRGBToIntArray(color);

                config[CONFIG_ENABLE] = enable;
                config[CONFIG_RANDOM] = random;
                config[CONFIG_R] = iColor[0];
                config[CONFIG_G] = iColor[1];
                config[CONFIG_B] = iColor[2];

                kv.GetSectionName(section, sizeof(section));
                TrimString(section);
                StringToLowerCase(section);

                g_smMeleeConfig.SetArray(section, config, sizeof(config));
            } while (kv.GotoNextKey());
        }
    }

    kv.Rewind();

    delete kv;
}

/****************************************************************************************************/

void LateLoad()
{
    OnMapStart();
    
    int entity;
    char classname[36];

    entity = INVALID_ENT_REFERENCE;
    while ((entity = FindEntityByClassname(entity, "*")) != INVALID_ENT_REFERENCE)
    {
        if (entity < 0)
            continue;

        GetEntityClassname(entity, classname, sizeof(classname));
        OnEntityCreated(entity, classname);
    }
}

/****************************************************************************************************/

public void OnEntityCreated(int entity, const char[] classname)
{
    if (!g_bValidMap)
        return;

    if (!g_bCvar_Enabled)
        return;

    if (entity < 0)
        return;

    if (!HasEntProp(entity, Prop_Send, "m_clrRender"))
        return;

    RequestFrame(OnNextFrame, EntIndexToEntRef(entity));
}

/****************************************************************************************************/

public void OnEntityDestroyed(int entity)
{
    if (entity < 0)
        return;

    ge_iRGBA[entity] = NOCOLOR;

    int find = g_alPluginEntities.FindValue(EntIndexToEntRef(entity));
    if (find != -1)
        g_alPluginEntities.Erase(find);
}

/****************************************************************************************************/

void OnNextFrame(int entityRef)
{
    int entity = EntRefToEntIndex(entityRef);

    if (entity == INVALID_ENT_REFERENCE)
        return;

    int find = g_alPluginEntities.FindValue(EntIndexToEntRef(entity));
    if (find != -1)
        return;

    char targetname[21];
    GetEntPropString(entity, Prop_Data, "m_iName", targetname, sizeof(targetname));
    if (StrEqual(targetname, "l4d_random_beam_item")) // l4d_random_beam_item plugin compatibility
        return;

    char modelname[PLATFORM_MAX_PATH];
    GetEntPropString(entity, Prop_Data, "m_ModelName", modelname, sizeof(modelname));
    StringToLowerCase(modelname);

    char classname[36];
    GetEntityClassname(entity, classname, sizeof(classname));

    if (HasEntProp(entity, Prop_Send, "m_isCarryable")) // CPhysicsProp
        g_smPropModelToClassname.GetString(modelname, classname, sizeof(classname));

    bool isMelee;
    char melee[16];

    if (StrContains(classname, "weapon_melee") == 0)
    {
        isMelee = true;

        if (StrEqual(classname, "weapon_melee"))
            GetEntPropString(entity, Prop_Data, "m_strMapSetScriptName", melee, sizeof(melee));
        else //weapon_melee_spawn
            g_smMeleeModelToName.GetString(modelname, melee, sizeof(melee));
    }

    if (StrEqual(classname, "weapon_spawn"))
    {
        int weaponId = GetEntProp(entity, Prop_Data, "m_weaponID");
        char sWeaponId[3];
        IntToString(weaponId, sWeaponId, sizeof(sWeaponId));

        if (!g_smWeaponIdToClassname.GetString(sWeaponId, classname, sizeof(classname)))
            return;
    }

    if (classname[0] == 'w')
        ReplaceString(classname, sizeof(classname), "_spawn", "");

    int config[CONFIG_ARRAYSIZE];

    if (isMelee && config[CONFIG_ENABLE] == 0)
        g_smMeleeConfig.GetArray(melee, config, sizeof(config));

    if (config[CONFIG_ENABLE] == 0)
        g_smClassnameConfig.GetArray(classname, config, sizeof(config));

    if (config[CONFIG_ENABLE] == 0)
        return;

    if (ge_iRGBA[entity] == NOCOLOR)
        ge_iRGBA[entity] = GetEntProp(entity, Prop_Send, "m_clrRender");

    int renderColor[4];
    GetEntityRenderColor(entity, renderColor[0], renderColor[1], renderColor[2], renderColor[3]);

    if (config[CONFIG_RANDOM] == 1)
    {
        renderColor[0] = GetRandomInt(0, 255);
        renderColor[1] = GetRandomInt(0, 255);
        renderColor[2] = GetRandomInt(0, 255);
    }
    else
    {
        renderColor[0] = config[CONFIG_R];
        renderColor[1] = config[CONFIG_G];
        renderColor[2] = config[CONFIG_B];
    }

    SetEntityRenderColor(entity, renderColor[0], renderColor[1], renderColor[2], renderColor[3]);

    g_alPluginEntities.Push(EntIndexToEntRef(entity));
}

/****************************************************************************************************/

public void OnPluginEnd()
{
    RemoveAll();
    MI_KV_Close();
}

/****************************************************************************************************/

void RemoveAll()
{
    if (g_alPluginEntities.Length > 0)
    {
        int entity;

        ArrayList g_alPluginEntitiesClone = g_alPluginEntities.Clone();

        for (int i = 0; i < g_alPluginEntitiesClone.Length; i++)
        {
            entity = EntRefToEntIndex(g_alPluginEntitiesClone.Get(i));

            if (entity == INVALID_ENT_REFERENCE)
                continue;

            SetEntProp(entity, Prop_Send, "m_clrRender", ge_iRGBA[entity]);
            ge_iRGBA[entity] = NOCOLOR;
        }

        delete g_alPluginEntitiesClone;

        delete g_alPluginEntities;
        g_alPluginEntities = new ArrayList();
    }
}

// ====================================================================================================
// Admin Commands
// ====================================================================================================
Action CmdInfo(int client, int args)
{
    if (!IsValidClient(client))
        return Plugin_Handled;

    int entity = GetClientAimTarget(client, false);

    if (!IsValidEntity(entity))
    {
        PrintToChat(client, "\x04Invalid target.");
        return Plugin_Handled;
    }

    if (!HasEntProp(entity, Prop_Send, "m_clrRender"))
    {
        PrintToChat(client, "\x04Target entity has no color property.");
        return Plugin_Handled;
    }

    int color = GetEntProp(entity, Prop_Send, "m_clrRender");
    int rgba[4];
    rgba[0] = ((color >> 00) & 0xFF);
    rgba[1] = ((color >> 08) & 0xFF);
    rgba[2] = ((color >> 16) & 0xFF);
    rgba[3] = ((color >> 24) & 0xFF);

    char classname[36];
    GetEntityClassname(entity, classname, sizeof(classname));

    char modelname[PLATFORM_MAX_PATH];
    GetEntPropString(entity, Prop_Data, "m_ModelName", modelname, sizeof(modelname));

    PrintToChat(client, "\x05Index: \x03%i \x05Classname: \x03%s \x05Model: \x03%s \x05Color (RGBA|Integer): \x03%i %i %i %i|%i", entity, classname, modelname, rgba[0], rgba[1], rgba[2], rgba[3], color);

    return Plugin_Handled;
}

/****************************************************************************************************/

Action CmdReload(int client, int args)
{
    LoadConfigs();

    RemoveAll();

    LateLoad();

    if (IsValidClient(client))
        PrintToChat(client, "\x04Color configs reloaded.");

    return Plugin_Handled;
}

/****************************************************************************************************/

Action CmdRemove(int client, int args)
{
    if (!IsValidClient(client))
        return Plugin_Handled;

    int entity = GetClientAimTarget(client, false);

    if (!IsValidEntity(entity))
    {
        PrintToChat(client, "\x04Invalid target.");
        return Plugin_Handled;
    }

    if (!HasEntProp(entity, Prop_Send, "m_clrRender"))
    {
        PrintToChat(client, "\x04Target entity has no color property.");
        return Plugin_Handled;
    }

    if (ge_iRGBA[entity] == NOCOLOR)
    {
        PrintToChat(client, "\x04Target entity color hasn't been overrided.");
        return Plugin_Handled;
    }

    SetEntProp(entity, Prop_Send, "m_clrRender", ge_iRGBA[entity]);
    ge_iRGBA[entity] = NOCOLOR;

    int find = g_alPluginEntities.FindValue(EntIndexToEntRef(entity));
    if (find != -1)
        g_alPluginEntities.Push(EntIndexToEntRef(entity));

    PrintToChat(client, "\x04Removed target entity plugin color.");

    return Plugin_Handled;
}

/****************************************************************************************************/

Action CmdRemoveAll(int client, int args)
{
    RemoveAll();

    if (IsValidClient(client))
        PrintToChat(client, "\x04Removed all colors override made by the plugin.");

    return Plugin_Handled;
}

/****************************************************************************************************/

Action CmdAdd(int client, int args)
{
    if (!IsValidClient(client))
        return Plugin_Handled;

    int entity = GetClientAimTarget(client, false);

    if (entity == -1)
    {
        PrintToChat(client, "\x04Invalid target.");
        return Plugin_Handled;
    }

    if (!HasEntProp(entity, Prop_Send, "m_clrRender"))
    {
        PrintToChat(client, "\x04Target entity has no color property.");
        return Plugin_Handled;
    }

    if (ge_iRGBA[entity] == NOCOLOR)
        ge_iRGBA[entity] = GetEntProp(entity, Prop_Send, "m_clrRender");

    int renderColor[4];
    GetEntityRenderColor(entity, renderColor[0], renderColor[1], renderColor[2], renderColor[3]);

    if (g_iDefaultConfig[CONFIG_RANDOM] == 1)
    {
        renderColor[0] = GetRandomInt(0, 255);
        renderColor[1] = GetRandomInt(0, 255);
        renderColor[2] = GetRandomInt(0, 255);
    }
    else
    {
        renderColor[0] = g_iDefaultConfig[CONFIG_R];
        renderColor[1] = g_iDefaultConfig[CONFIG_G];
        renderColor[2] = g_iDefaultConfig[CONFIG_B];
    }

    SetEntityRenderColor(entity, renderColor[0], renderColor[1], renderColor[2], renderColor[3]);

    int find = g_alPluginEntities.FindValue(EntIndexToEntRef(entity));
    if (find != -1)
        g_alPluginEntities.Push(EntIndexToEntRef(entity));

    PrintToChat(client, "\x04Color added to target entity.");

    return Plugin_Handled;
}

/****************************************************************************************************/

Action CmdAll(int client, int args)
{
    RemoveAll();

    int entity;
    int renderColor[4];

    entity = INVALID_ENT_REFERENCE;
    while ((entity = FindEntityByClassname(entity, "*")) != INVALID_ENT_REFERENCE)
    {
        if (entity < 0)
            continue;

        if (!HasEntProp(entity, Prop_Send, "m_clrRender"))
            continue;

        if (ge_iRGBA[entity] == NOCOLOR)
            ge_iRGBA[entity] = GetEntProp(entity, Prop_Send, "m_clrRender");

        GetEntityRenderColor(entity, renderColor[0], renderColor[1], renderColor[2], renderColor[3]);

        if (g_iDefaultConfig[CONFIG_RANDOM] == 1)
        {
            renderColor[0] = GetRandomInt(0, 255);
            renderColor[1] = GetRandomInt(0, 255);
            renderColor[2] = GetRandomInt(0, 255);
        }
        else
        {
            renderColor[0] = g_iDefaultConfig[CONFIG_R];
            renderColor[1] = g_iDefaultConfig[CONFIG_G];
            renderColor[2] = g_iDefaultConfig[CONFIG_B];
        }

        SetEntityRenderColor(entity, renderColor[0], renderColor[1], renderColor[2], renderColor[3]);

        g_alPluginEntities.Push(EntIndexToEntRef(entity));
    }

    if (IsValidClient(client))
        PrintToChat(client, "\x04Color added to all valid entities.");

    return Plugin_Handled;
}

/****************************************************************************************************/

Action CmdPrintCvars(int client, int args)
{
    PrintToConsole(client, "");
    PrintToConsole(client, "======================================================================");
    PrintToConsole(client, "");
    PrintToConsole(client, "--------------- Plugin Cvars (l4d_random_entity_color) ---------------");
    PrintToConsole(client, "");
    PrintToConsole(client, "l4d_random_entity_color_version : %s", PLUGIN_VERSION);
    PrintToConsole(client, "l4d_random_entity_color_enable : %b (%s)", g_bCvar_Enabled, g_bCvar_Enabled ? "true" : "false");
    PrintToConsole(client, "");
    PrintToConsole(client, "----------------------------- Array List -----------------------------");
    PrintToConsole(client, "");
    PrintToConsole(client, "g_alPluginEntities count : %i", g_alPluginEntities.Length);
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

/****************************************************************************************************/

/**
 * Returns the integer array value of a RGB string.
 * Format: Three values between 0-255 separated by spaces. "<0-255> <0-255> <0-255>"
 * Example: "255 255 255"
 *
 * @param sColor        RGB color string.
 * @return              Integer array (int[3]) value of the RGB string or {0,0,0} if not in specified format.
 */
int[] ConvertRGBToIntArray(char[] sColor)
{
    int color[3];

    if (sColor[0] == 0)
        return color;

    char sColors[3][4];
    int count = ExplodeString(sColor, " ", sColors, sizeof(sColors), sizeof(sColors[]));

    switch (count)
    {
        case 1:
        {
            color[0] = StringToInt(sColors[0]);
        }
        case 2:
        {
            color[0] = StringToInt(sColors[0]);
            color[1] = StringToInt(sColors[1]);
        }
        case 3:
        {
            color[0] = StringToInt(sColors[0]);
            color[1] = StringToInt(sColors[1]);
            color[2] = StringToInt(sColors[2]);
        }
    }

    return color;
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