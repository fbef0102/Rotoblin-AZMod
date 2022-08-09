/**
// ====================================================================================================
Change Log:

1.0.4 (19-June-2022)
    - Fixed an error while trying to retrieve the glow parent entity. (thanks "CrazMan" for reporting)

1.0.3 (25-September-2021)
    - Added blink color/alpha option.
    - Fixed some weapons blinking while equipped.
    - Fixed minigun glow position.

1.0.2 (15-September-2021)
    - Added fade option (team based).
    - Added cvar timer to detect when should toggle the glow.
    - Fixed sprite console errors.

1.0.1 (12-September-2021)
    - Removed minigun outline glow while in use.
    - Added new commands to manually add/remove glow.
    - Added support to model-based config in the data file. (thanks "KadabraZz" for requesting)
    - Added blink effect. (thanks "KadabraZz" for sharing)

1.0.0 (07-September-2021)
    - Initial release.

// ====================================================================================================
*/

// ====================================================================================================
// Plugin Info - define
// ====================================================================================================
#define PLUGIN_NAME                   "[L4D1] Glow Item (White)"
#define PLUGIN_AUTHOR                 "Mart"
#define PLUGIN_DESCRIPTION            "Add a white outline glow effect to items on the map"
#define PLUGIN_VERSION                "1.0.4"
#define PLUGIN_URL                    "https://forums.alliedmods.net/showthread.php?t=334222"

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
#define CONFIG_FILENAME               "l4d1_glow_item"
#define DATA_FILENAME                 "l4d1_glow_item"

// ====================================================================================================
// Defines
// ====================================================================================================
#define MODEL_PAINPILLS               "models/w_models/weapons/w_eq_painpills.mdl"

#define MODEL_GASCAN                  "models/props_junk/gascan001a.mdl"
#define MODEL_PROPANECANISTER         "models/props_junk/propanecanister001a.mdl"
#define MODEL_OXYGENTANK              "models/props_equipment/oxygentank01.mdl"

#define L4D1_GLOW_TEAM_EVERYONE       -1
#define L4D1_GLOW_TEAM_SURVIVOR       2
#define L4D1_GLOW_TEAM_INFECTED       3

#define CONFIG_ENABLE                 0
#define CONFIG_TEAM                   1
#define CONFIG_BLINK                  2
#define CONFIG_BLINK_RANDOM           3
#define CONFIG_BLINK_R                4
#define CONFIG_BLINK_G                5
#define CONFIG_BLINK_B                6
#define CONFIG_BLINK_A                7
#define CONFIG_FADEMAX                8
#define CONFIG_ARRAYSIZE              9

#define MAXENTITIES                   2048

// ====================================================================================================
// Plugin Cvars
// ====================================================================================================
ConVar g_hCvar_Enabled;
ConVar g_hCvar_RemoveSpawner;
ConVar g_hCvar_HealthCabinet;
ConVar g_hCvar_Interval;

// ====================================================================================================
// bool - Plugin Variables
// ====================================================================================================
bool g_bCvar_Enabled;
bool g_bCvar_RemoveSpawner;
bool g_bCvar_HealthCabinet;

// ====================================================================================================
// int - Plugin Variables
// ====================================================================================================
int g_iDefaultConfig[CONFIG_ARRAYSIZE];

// ====================================================================================================
// float - Plugin Variables
// ====================================================================================================
float g_fCvar_Interval;

// ====================================================================================================
// entity - Plugin Variables
// ====================================================================================================
bool ge_bIsMinigun[MAXENTITIES+1];
bool ge_bMinigunInUse[MAXENTITIES+1];
bool ge_bUsePostHooked[MAXENTITIES+1];
bool ge_bViewModel[MAXENTITIES+1];
int ge_iParentEntRef[MAXENTITIES+1] = { INVALID_ENT_REFERENCE, ... };
int ge_iConfig[MAXENTITIES+1][CONFIG_ARRAYSIZE];

// ====================================================================================================
// ArrayList - Plugin Variables
// ====================================================================================================
ArrayList g_alPluginEntities;

// ====================================================================================================
// StringMap - Plugin Variables
// ====================================================================================================
StringMap g_smPropModelToClassname;
StringMap g_smClassnameConfig;
StringMap g_smModelConfig;

// ====================================================================================================
// Timer - Plugin Variables
// ====================================================================================================
Handle g_tToggleGlow;

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

    g_smPropModelToClassname = new StringMap();
    g_smClassnameConfig = new StringMap();
    g_smModelConfig = new StringMap();
    g_alPluginEntities = new ArrayList();

    return APLRes_Success;
}

/****************************************************************************************************/

public void OnPluginStart()
{
    BuildMaps();

    LoadConfigs();

    CreateConVar("l4d1_glow_item_version", PLUGIN_VERSION, PLUGIN_DESCRIPTION, CVAR_FLAGS_PLUGIN_VERSION);
    g_hCvar_Enabled       = CreateConVar("l4d1_glow_item_enable", "1", "Enable/Disable the plugin.\n0 = Disable, 1 = Enable.", CVAR_FLAGS, true, 0.0, true, 1.0);
    g_hCvar_RemoveSpawner = CreateConVar("l4d1_glow_item_remove_spawner", "1", "Delete *_spawn entities when its count reaches 0.\n0 = OFF, 1 = ON.", CVAR_FLAGS, true, 0.0, true, 1.0);
    g_hCvar_HealthCabinet = CreateConVar("l4d1_glow_item_health_cabinet", "1", "Remove glow from health cabinet after being opened.\n0 = OFF, 1 = ON.", CVAR_FLAGS, true, 0.0, true, 1.0);
    g_hCvar_Interval      = CreateConVar("l4d1_glow_item_interval", "0.3", "Interval in seconds to toggle (start/stop) the glow.", CVAR_FLAGS, true, 0.1);

    // Hook plugin ConVars change
    g_hCvar_Enabled.AddChangeHook(Event_ConVarChanged);
    g_hCvar_RemoveSpawner.AddChangeHook(Event_ConVarChanged);
    g_hCvar_HealthCabinet.AddChangeHook(Event_ConVarChanged);
    g_hCvar_Interval.AddChangeHook(Event_ConVarChanged);

    // Load plugin configs from .cfg
    AutoExecConfig(true, CONFIG_FILENAME);

    // Admin Commands
    RegAdminCmd("sm_glowinfo", CmdInfo, ADMFLAG_ROOT, "Outputs to the chat the glow info about the entity at your crosshair.");
    RegAdminCmd("sm_glowreload", CmdReload, ADMFLAG_ROOT, "Reload the glow configs.");
    RegAdminCmd("sm_glowremove", CmdRemove, ADMFLAG_ROOT, "Remove plugin glow from entity at crosshair.");
    RegAdminCmd("sm_glowremoveall", CmdRemoveAll, ADMFLAG_ROOT, "Remove all glows created by the plugin.");
    RegAdminCmd("sm_glowadd", CmdAdd, ADMFLAG_ROOT, "Add glow to entity at crosshair.");
    RegAdminCmd("sm_glowall", CmdAll, ADMFLAG_ROOT, "Add glow to everything possible.");
    RegAdminCmd("sm_print_cvars_l4d1_glow_item", CmdPrintCvars, ADMFLAG_ROOT, "Print the plugin related cvars and their respective values to the console.");
}

/****************************************************************************************************/

void BuildMaps()
{
    g_smPropModelToClassname.Clear();
    g_smPropModelToClassname.SetString(MODEL_GASCAN, "weapon_gascan");
    g_smPropModelToClassname.SetString(MODEL_PROPANECANISTER, "weapon_propanetank");
    g_smPropModelToClassname.SetString(MODEL_OXYGENTANK, "weapon_oxygentank");
}

/****************************************************************************************************/

public void OnConfigsExecuted()
{
    GetCvars();

    LateLoad();

    delete g_tToggleGlow;
    if (g_bCvar_Enabled)
        g_tToggleGlow = CreateTimer(g_fCvar_Interval, TimerGlow, _, TIMER_REPEAT);
}

/****************************************************************************************************/

void Event_ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    GetCvars();

    RemoveAll();

    LateLoad();

    delete g_tToggleGlow;
    if (g_bCvar_Enabled)
        g_tToggleGlow = CreateTimer(g_fCvar_Interval, TimerGlow, _, TIMER_REPEAT);
}

/****************************************************************************************************/

void GetCvars()
{
    g_bCvar_Enabled = g_hCvar_Enabled.BoolValue;
    g_bCvar_RemoveSpawner = g_hCvar_RemoveSpawner.BoolValue;
    g_bCvar_HealthCabinet = g_hCvar_HealthCabinet.BoolValue;
    g_fCvar_Interval = g_hCvar_Interval.FloatValue;
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

    g_smClassnameConfig.Clear();
    g_smModelConfig.Clear();

    int default_enable;
    int default_team;
    int default_blink;
    int default_blink_random;
    char default_blink_color[12];
    int default_blink_alpha;
    int default_fademax;

    int iColor[3];

    if (kv.JumpToKey("default"))
    {
        default_enable = kv.GetNum("enable", 0);
        default_team = kv.GetNum("team", 0);
        default_blink = kv.GetNum("blink", 0);
        default_blink_random = kv.GetNum("blink_random", 0);
        kv.GetString("blink_color", default_blink_color, sizeof(default_blink_color), "0 0 0");
        default_blink_alpha = kv.GetNum("blink_alpha", 0);
        default_fademax = kv.GetNum("fademax", 0);

        iColor = ConvertRGBToIntArray(default_blink_color);

        g_iDefaultConfig[CONFIG_ENABLE] = default_enable;
        g_iDefaultConfig[CONFIG_TEAM] = default_team;
        g_iDefaultConfig[CONFIG_BLINK] = default_blink;
        g_iDefaultConfig[CONFIG_BLINK_RANDOM] = default_blink_random;
        g_iDefaultConfig[CONFIG_BLINK_R] = iColor[0];
        g_iDefaultConfig[CONFIG_BLINK_G] = iColor[1];
        g_iDefaultConfig[CONFIG_BLINK_B] = iColor[2];
        g_iDefaultConfig[CONFIG_BLINK_A] = default_blink_alpha;
        g_iDefaultConfig[CONFIG_FADEMAX] = default_fademax;
    }

    kv.Rewind();

    char section[64];
    int enable;
    int team;
    int blink;
    int blink_random;
    char blink_color[12];
    int blink_alpha;
    int fademax;

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

                team = kv.GetNum("team", default_team);
                blink = kv.GetNum("blink", default_blink);
                blink_random = kv.GetNum("blink_random", default_blink_random);
                kv.GetString("blink_color", blink_color, sizeof(blink_color), default_blink_color);
                blink_alpha = kv.GetNum("blink_alpha", default_blink_alpha);
                fademax = kv.GetNum("fademax", default_fademax);

                iColor = ConvertRGBToIntArray(blink_color);

                config[CONFIG_ENABLE] = enable;
                config[CONFIG_TEAM] = team;
                config[CONFIG_BLINK] = blink;
                config[CONFIG_BLINK_RANDOM] = blink_random;
                config[CONFIG_BLINK_R] = iColor[0];
                config[CONFIG_BLINK_G] = iColor[1];
                config[CONFIG_BLINK_B] = iColor[2];
                config[CONFIG_BLINK_A] = blink_alpha;
                config[CONFIG_FADEMAX] = fademax;

                kv.GetSectionName(section, sizeof(section));
                TrimString(section);
                StringToLowerCase(section);

                g_smClassnameConfig.SetArray(section, config, sizeof(config));
            } while (kv.GotoNextKey());
        }
    }

    kv.Rewind();

    char modelname[PLATFORM_MAX_PATH];
    if (kv.JumpToKey("models"))
    {
        if (kv.GotoFirstSubKey())
        {
            do
            {
                enable = kv.GetNum("enable", default_enable);
                if (enable == 0)
                    continue;

                enable = kv.GetNum("enable", default_enable);
                team = kv.GetNum("team", default_team);
                blink = kv.GetNum("blink", default_blink);
                blink_random = kv.GetNum("blink_random", default_blink_random);
                kv.GetString("blink_color", blink_color, sizeof(blink_color), default_blink_color);
                blink_alpha = kv.GetNum("blink_alpha", default_blink_alpha);
                fademax = kv.GetNum("fademax", default_fademax);

                iColor = ConvertRGBToIntArray(blink_color);

                config[CONFIG_ENABLE] = enable;
                config[CONFIG_TEAM] = team;
                config[CONFIG_BLINK] = blink;
                config[CONFIG_BLINK_RANDOM] = blink_random;
                config[CONFIG_BLINK_R] = iColor[0];
                config[CONFIG_BLINK_G] = iColor[1];
                config[CONFIG_BLINK_B] = iColor[2];
                config[CONFIG_BLINK_A] = blink_alpha;
                config[CONFIG_FADEMAX] = fademax;

                kv.GetSectionName(modelname, sizeof(modelname));
                TrimString(modelname);
                StringToLowerCase(modelname);

                g_smModelConfig.SetArray(modelname, config, sizeof(config));
            } while (kv.GotoNextKey());
        }
    }

    kv.Rewind();

    delete kv;
}

/****************************************************************************************************/

void LateLoad()
{
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
    if (entity < 0)
        return;

    if (StrEqual(classname, "prop_glowing_object")) // prevent loops
        return;

    if (HasEntProp(entity, Prop_Send, "m_bWorldSpaceScale")) // CSprite
        return;

    RequestFrame(OnNextFrame, EntIndexToEntRef(entity));
}

/****************************************************************************************************/

public void OnEntityDestroyed(int entity)
{
    if (entity < 0)
        return;

    ge_bIsMinigun[entity] = false;
    ge_bMinigunInUse[entity] = false;
    ge_bUsePostHooked[entity] = false;
    ge_bViewModel[entity] = false;
    ge_iParentEntRef[entity] = INVALID_ENT_REFERENCE;
    ge_iConfig[entity] = g_iDefaultConfig;

    int find = g_alPluginEntities.FindValue(EntIndexToEntRef(entity));
    if (find != -1)
        g_alPluginEntities.Erase(find);
}

/****************************************************************************************************/

void OnNextFrame(int entityRef)
{
    if (!g_bCvar_Enabled)
        return;

    int entity = EntRefToEntIndex(entityRef);

    if (entity == INVALID_ENT_REFERENCE)
        return;

    char modelname[PLATFORM_MAX_PATH];
    GetEntPropString(entity, Prop_Data, "m_ModelName", modelname, sizeof(modelname));
    StringToLowerCase(modelname);

    if (modelname[0] != 'm') // invalid model
        return;

    char classname[36];
    GetEntityClassname(entity, classname, sizeof(classname));

    if (HasEntProp(entity, Prop_Send, "m_isCarryable")) // CPhysicsProp
        g_smPropModelToClassname.GetString(modelname, classname, sizeof(classname));

    if (classname[0] == 'w')
        ReplaceString(classname, sizeof(classname), "_spawn", "");

    int config[CONFIG_ARRAYSIZE];

    if (config[CONFIG_ENABLE] == 0)
        g_smModelConfig.GetArray(modelname, config, sizeof(config));

    if (config[CONFIG_ENABLE] == 0)
        g_smClassnameConfig.GetArray(classname, config, sizeof(config));

    if (config[CONFIG_ENABLE] == 0)
        return;

    if (HasEntProp(entity, Prop_Data, "m_itemCount")) // *_spawn entities
    {
        if (!ge_bUsePostHooked[entity])
        {
            ge_bUsePostHooked[entity] = true;
            SDKHook(entity, SDKHook_UsePost, OnUsePostSpawner);
        }
    }

    if (HasEntProp(entity, Prop_Send, "m_isUsed")) // CPropHealthCabinet
    {
        if (g_bCvar_HealthCabinet && GetEntProp(entity, Prop_Send, "m_isUsed") == 1)
            return;

        if (!ge_bUsePostHooked[entity])
        {
            ge_bUsePostHooked[entity] = true;
            SDKHook(entity, SDKHook_UsePost, OnUsePostHealthCabinet);
        }
    }

    if (HasEntProp(entity, Prop_Send, "m_heat")) // CPropMinigun / CPropMachineGun
    {
        ge_bIsMinigun[entity] = true;

        if (!ge_bUsePostHooked[entity])
        {
            ge_bUsePostHooked[entity] = true;
            SDKHook(entity, SDKHook_UsePost, OnUsePostMinigun);
        }
    }

    int glow = CreatePropGlow(entity, config);
    ge_iConfig[glow] = config;
}

/****************************************************************************************************/

int CreatePropGlow(int parent, int[] config)
{
    char sTeam[3];
    FormatEx(sTeam, sizeof(sTeam), "%i", config[CONFIG_TEAM]);

    float vPos[3];
    GetEntPropVector(parent, Prop_Data, "m_vecAbsOrigin", vPos);

    float vAngles[3];
    GetEntPropVector(parent, Prop_Data, "m_angAbsRotation", vAngles);

    int entity = CreateEntityByName("prop_glowing_object");
    DispatchKeyValue(entity, "targetname", "l4d1_glow_item");
    DispatchKeyValue(entity, "disableshadows", "1");
    DispatchKeyValue(entity, "StartGlowing", "0");
    DispatchKeyValue(entity, "model", MODEL_PAINPILLS); // Hack to make glow work with any model
    DispatchKeyValue(entity, "GlowForTeam", sTeam);
    DispatchKeyValueVector(entity, "origin", vPos);
    DispatchKeyValueVector(entity, "angles", vAngles);
    DispatchSpawn(entity);

    if (config[CONFIG_BLINK_RANDOM] == 1)
        SetEntityRenderColor(entity, GetRandomInt(0, 255), GetRandomInt(0, 255), GetRandomInt(0, 255), config[CONFIG_BLINK_A]);
    else
        SetEntityRenderColor(entity, config[CONFIG_BLINK_R], config[CONFIG_BLINK_G], config[CONFIG_BLINK_B], config[CONFIG_BLINK_A]);

    bool render = true;

    if (HasEntProp(parent, Prop_Send, "m_iWorldModelIndex") && GetEntProp(parent, Prop_Send, "m_iWorldModelIndex") != GetEntProp(parent, Prop_Send, "m_nModelIndex"))
    {
        render = false;
        ge_bViewModel[entity] = true;
        SDKHook(entity, SDKHook_Use, OnUseBlock); // Fix a bug allowing to "stole" the weapon
        SetEntProp(entity, Prop_Send, "m_nModelIndex", GetEntProp(parent, Prop_Send, "m_iWorldModelIndex"));
    }
    else
    {
        SetEntProp(entity, Prop_Send, "m_nModelIndex", GetEntProp(parent, Prop_Send, "m_nModelIndex"));
    }

    if (render && HasEntProp(parent, Prop_Send, "m_hOwnerEntity") && GetEntPropEnt(parent, Prop_Send, "m_hOwnerEntity") != -1)
        render = false;

    if (render)
    {
        SetEntityRenderMode(entity, RENDER_TRANSCOLOR);
        switch (config[CONFIG_BLINK])
        {
            case 1:  SetEntityRenderFx(entity, RENDERFX_PULSE_FAST); // Soft Blink
            case 2:  SetEntityRenderFx(entity, RENDERFX_PULSE_FAST_WIDE); // Medium Blink
            case 3:  SetEntityRenderFx(entity, RENDERFX_EXPLODE); // Hard Blink
            default: SetEntityRenderFx(entity, RENDERFX_NONE); // No Blink
        }
    }
    else
    {
        SetEntityRenderMode(entity, RENDER_NONE);
        SetEntityRenderFx(entity, RENDERFX_NONE);
    }

    if (HasEntProp(parent, Prop_Send, "m_nSequence"))
        SetEntProp(entity, Prop_Send, "m_nSequence", GetEntProp(parent, Prop_Send, "m_nSequence"));

    if (ge_bIsMinigun[parent])
    {
        // Fixes minigun client side glow
        SetEntPropFloat(entity, Prop_Data, "m_flPoseParameter", 0.5, 0);
        SetEntPropFloat(entity, Prop_Data, "m_flPoseParameter", 0.5, 1);
    }

    SetVariantString("!activator");
    AcceptEntityInput(entity, "SetParent", parent);

    if (g_alPluginEntities.FindValue(EntIndexToEntRef(entity)) == -1)
        g_alPluginEntities.Push(EntIndexToEntRef(entity));

    ge_iParentEntRef[entity] = EntIndexToEntRef(parent);

    return entity;
}

/****************************************************************************************************/

void OnUsePostSpawner(int entity, int activator, int caller, UseType type, float value)
{
    if (!g_bCvar_Enabled)
        return;

    if (!g_bCvar_RemoveSpawner)
        return;

    if (GetEntProp(entity, Prop_Data, "m_itemCount") == 0)
        AcceptEntityInput(entity, "Kill");
}

/****************************************************************************************************/

void OnUsePostHealthCabinet(int entity, int activator, int caller, UseType type, float value)
{
    if (!g_bCvar_Enabled)
        return;

    if (!g_bCvar_HealthCabinet)
        return;

    if (GetEntProp(entity, Prop_Send, "m_isUsed") == 0)
        return;

    int parentRef = EntIndexToEntRef(entity);

    for (int i = 0; i < g_alPluginEntities.Length; i++)
    {
        entity = EntRefToEntIndex(g_alPluginEntities.Get(i));

        if (entity == INVALID_ENT_REFERENCE)
            continue;

        if (ge_iParentEntRef[entity] == parentRef)
        {
            AcceptEntityInput(entity, "Kill");
            break;
        }
    }

    ge_bUsePostHooked[entity] = false;
    SDKUnhook(entity, SDKHook_UsePost, OnUsePostHealthCabinet);
}

/****************************************************************************************************/

void OnUsePostMinigun(int entity, int activator, int caller, UseType type, float value)
{
    if (!g_bCvar_Enabled)
        return;

    SDKUnhook(entity, SDKHook_UsePost, OnUsePostMinigun);

    ge_bMinigunInUse[entity] = true;

    RequestFrame(OnNextFrameMinigun, EntIndexToEntRef(entity));

    int parentRef = EntIndexToEntRef(entity);

    for (int i = 0; i < g_alPluginEntities.Length; i++)
    {
        entity = EntRefToEntIndex(g_alPluginEntities.Get(i));

        if (entity == INVALID_ENT_REFERENCE)
            continue;

        if (ge_iParentEntRef[entity] == parentRef)
        {
            if (GetEntProp(entity, Prop_Data, "m_bIsGlowing") == 1)
            {
                SetEntityRenderFx(entity, RENDERFX_NONE);
                AcceptEntityInput(entity, "StopGlowing");
            }
            break;
        }
    }
}

/****************************************************************************************************/

void OnNextFrameMinigun(int entityRef)
{
    int entity = EntRefToEntIndex(entityRef);

    if (entity == INVALID_ENT_REFERENCE)
        return;

    if (GetEntPropEnt(entity, Prop_Send, "m_owner") == -1)
    {
        ge_bMinigunInUse[entity] = false;
        SDKHook(entity, SDKHook_UsePost, OnUsePostMinigun);
    }
    else
    {
        RequestFrame(OnNextFrameMinigun, entityRef);
    }
}

/****************************************************************************************************/

Action TimerGlow(Handle timer)
{
    bool valid;
    bool glowing;
    int i;
    int client;
    int entity;
    int parent;
    int owner;
    float targetPos[3];
    bool clientValid[MAXPLAYERS+1];
    int clientTeam[MAXPLAYERS+1];
    float clientPos[MAXPLAYERS+1][3];
    float vPos[3];
    float vAngles[3];

    for (client = 1; client <= MaxClients; client++)
    {
        clientValid[client] = false;
        clientTeam[client] = 0;

        if (!IsClientInGame(client))
            continue;

        clientValid[client] = true;
        clientTeam[client] = GetClientTeam(client);
        GetClientAbsOrigin(client, clientPos[client]);
    }

    for (i = 0; i < g_alPluginEntities.Length; i++)
    {
        entity = EntRefToEntIndex(g_alPluginEntities.Get(i));

        if (entity == INVALID_ENT_REFERENCE)
            continue;

        parent = EntRefToEntIndex(ge_iParentEntRef[entity]);

        if (parent == INVALID_ENT_REFERENCE)
            continue;

        if (ge_bMinigunInUse[parent])
            continue;

        glowing = (GetEntProp(entity, Prop_Data, "m_bIsGlowing") == 1);
        owner = INVALID_ENT_REFERENCE;

        if (HasEntProp(parent, Prop_Send, "m_hOwnerEntity"))
            owner = GetEntPropEnt(parent, Prop_Send, "m_hOwnerEntity");

        if (owner != -1)
        {
            if (glowing)
            {
                SetEntityRenderMode(entity, RENDER_NONE);
                SetEntityRenderFx(entity, RENDERFX_NONE);
                AcceptEntityInput(entity, "StopGlowing");
            }
            continue;
        }

        if (ge_bViewModel[entity] && !glowing && owner == -1)
        {
            ge_bViewModel[entity] = false;
            SDKUnhook(entity, SDKHook_Use, OnUseBlock);

            AcceptEntityInput(entity, "ClearParent");
            AcceptEntityInput(entity, "StartGlowing");

            GetEntPropVector(parent, Prop_Data, "m_vecAbsOrigin", vPos);
            GetEntPropVector(parent, Prop_Data, "m_angAbsRotation", vAngles);

            TeleportEntity(entity, vPos, vAngles, NULL_VECTOR);

            SetEntityRenderMode(entity, RENDER_TRANSCOLOR);
            switch (ge_iConfig[entity][CONFIG_BLINK])
            {
                case 1:  SetEntityRenderFx(entity, RENDERFX_PULSE_FAST); // Soft Blink
                case 2:  SetEntityRenderFx(entity, RENDERFX_PULSE_FAST_WIDE); // Medium Blink
                case 3:  SetEntityRenderFx(entity, RENDERFX_EXPLODE); // Hard Blink
                default: SetEntityRenderFx(entity, RENDERFX_NONE); // No Blink
            }

            SetVariantString("!activator");
            AcceptEntityInput(entity, "SetParent", parent);
            continue;
        }

        if (ge_iConfig[entity][CONFIG_FADEMAX] == 0)
        {
            valid = true;
        }
        else
        {
            valid = false;

            GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", targetPos);

            for (client = 1; client <= MaxClients; client++)
            {
                if (!clientValid[client])
                    continue;

                if (ge_iConfig[entity][CONFIG_TEAM] != L4D1_GLOW_TEAM_EVERYONE && clientTeam[client] != ge_iConfig[entity][CONFIG_TEAM])
                    continue;

                if (GetVectorDistance(targetPos, clientPos[client]) < ge_iConfig[entity][CONFIG_FADEMAX])
                {
                    valid = true;
                    break;
                }
            }
        }

        if (valid && !glowing)
        {
            AcceptEntityInput(entity, "StartGlowing");
            continue;
        }

        if (!valid && glowing)
        {
            AcceptEntityInput(entity, "StopGlowing");
            continue;
        }
    }

    return Plugin_Continue;
}

/****************************************************************************************************/

Action OnUseBlock(int entity, int activator, int caller, UseType type, float value)
{
    return Plugin_Stop;
}

/****************************************************************************************************/

public void OnPluginEnd()
{
    RemoveAll();
}

/****************************************************************************************************/

void RemoveAll()
{
    int entity;
    char targetname[15];

    entity = INVALID_ENT_REFERENCE;
    while ((entity = FindEntityByClassname(entity, "prop_glowing_object")) != INVALID_ENT_REFERENCE)
    {
        GetEntPropString(entity, Prop_Data, "m_iName", targetname, sizeof(targetname));
        if (StrEqual(targetname, "l4d1_glow_item"))
            AcceptEntityInput(entity, "Kill");
    }

    g_alPluginEntities.Clear();
}

// ====================================================================================================
// Admin Commands
// ====================================================================================================
Action CmdInfo(int client, int args)
{
    if (!IsValidClient(client))
        return Plugin_Handled;

    int parent = GetClientAimTarget(client, false);

    if (parent == -1)
    {
        PrintToChat(client, "\x04Invalid target.");
        return Plugin_Handled;
    }

    bool find;
    int entity;
    int parentRef = EntIndexToEntRef(parent);

    for (int i = 0; i < g_alPluginEntities.Length; i++)
    {
        entity = EntRefToEntIndex(g_alPluginEntities.Get(i));

        if (entity == INVALID_ENT_REFERENCE)
            continue;

        if (ge_iParentEntRef[entity] == parentRef)
        {
            find = true;
            break;
        }
    }

    if (!find)
    {
        PrintToChat(client, "\x04Target entity has no glow.");
        return Plugin_Handled;
    }

    char classname[36];
    GetEntityClassname(parent, classname, sizeof(classname));

    char modelname[PLATFORM_MAX_PATH];
    GetEntPropString(parent, Prop_Data, "m_ModelName", modelname, sizeof(modelname));

    PrintToChat(client, "\x05Glow Index: \x03%i \x05Parent Index: \x03%i \x05Classname: \x03%s \x05Model: \x03%s", entity, parent, classname, modelname);

    return Plugin_Handled;
}

/****************************************************************************************************/

Action CmdReload(int client, int args)
{
    LoadConfigs();

    RemoveAll();

    LateLoad();

    if (IsValidClient(client))
        PrintToChat(client, "\x04Glow configs reloaded.");

    return Plugin_Handled;
}

/****************************************************************************************************/

Action CmdRemove(int client, int args)
{
    if (!IsValidClient(client))
        return Plugin_Handled;

    int parent = GetClientAimTarget(client, false);

    if (parent == -1)
    {
        PrintToChat(client, "\x04Invalid target.");
        return Plugin_Handled;
    }

    bool find;
    int entity;
    int parentRef = EntIndexToEntRef(parent);

    for (int i = 0; i < g_alPluginEntities.Length; i++)
    {
        entity = EntRefToEntIndex(g_alPluginEntities.Get(i));

        if (entity == INVALID_ENT_REFERENCE)
            continue;

        if (ge_iParentEntRef[entity] == parentRef)
        {
            find = true;
            break;
        }
    }

    if (find)
    {
        AcceptEntityInput(entity, "Kill");
        PrintToChat(client, "\x04Removed target entity plugin glow.");
    }
    else
    {
        PrintToChat(client, "\x04Target entity has no glow.");
    }

    return Plugin_Handled;
}

/****************************************************************************************************/

Action CmdRemoveAll(int client, int args)
{
    RemoveAll();

    if (IsValidClient(client))
        PrintToChat(client, "\x04Removed all glows created by the plugin.");

    return Plugin_Handled;
}

/****************************************************************************************************/

Action CmdAdd(int client, int args)
{
    if (!IsValidClient(client))
        return Plugin_Handled;

    int parent = GetClientAimTarget(client, false);

    if (parent == -1)
    {
        PrintToChat(client, "\x04Invalid target.");
        return Plugin_Handled;
    }

    if (parent == -1)
    {
        PrintToChat(client, "\x04Invalid target index to add glow.");
        return Plugin_Handled;
    }

    char classname[36];
    char modelname[PLATFORM_MAX_PATH];

    GetEntityClassname(parent, classname, sizeof(classname));

    if (classname[0] == 'p' && StrEqual(classname, "prop_glowing_object")) // prevent loops
    {
        PrintToChat(client, "\x04Invalid target classname to add glow.");
        return Plugin_Handled;
    }

    if (HasEntProp(parent, Prop_Send, "m_bWorldSpaceScale")) // CSprite
    {
        PrintToChat(client, "\x04Invalid target classname to add glow.");
        return Plugin_Handled;
    }

    GetEntPropString(parent, Prop_Data, "m_ModelName", modelname, sizeof(modelname));
    StringToLowerCase(modelname);

    if (modelname[0] != 'm') // invalid model
    {
        PrintToChat(client, "\x04Invalid target model to add glow.");
        return Plugin_Handled;
    }

    bool find;
    int entity;
    int parentRef = EntIndexToEntRef(parent);

    for (int i = 0; i < g_alPluginEntities.Length; i++)
    {
        entity = EntRefToEntIndex(g_alPluginEntities.Get(i));

        if (entity == INVALID_ENT_REFERENCE)
            continue;

        if (ge_iParentEntRef[entity] == parentRef)
        {
            find = true;
            break;
        }
    }

    if (find)
        AcceptEntityInput(entity, "Kill");

    int glow = CreatePropGlow(parent, g_iDefaultConfig);
    ge_iConfig[glow] = g_iDefaultConfig;
    ge_iConfig[glow][CONFIG_TEAM] = 0;
    ge_iConfig[glow][CONFIG_FADEMAX] = 0;

    PrintToChat(client, "\x04Glow added to target entity.");

    return Plugin_Handled;
}

/****************************************************************************************************/

Action CmdAll(int client, int args)
{
    RemoveAll();

    int entity;
    char classname[36];
    char modelname[2];

    entity = INVALID_ENT_REFERENCE;
    while ((entity = FindEntityByClassname(entity, "*")) != INVALID_ENT_REFERENCE)
    {
        if (entity < 0)
            continue;

        GetEntityClassname(entity, classname, sizeof(classname));

        if (classname[0] == 'p' && StrEqual(classname, "prop_glowing_object")) // prevent loops
            continue;

        if (HasEntProp(entity, Prop_Send, "m_bWorldSpaceScale")) // CSprite
            continue;

        GetEntPropString(entity, Prop_Data, "m_ModelName", modelname, sizeof(modelname));
        StringToLowerCase(modelname);

        if (modelname[0] != 'm') // invalid model
            continue;

        int glow = CreatePropGlow(entity, g_iDefaultConfig);
        ge_iConfig[glow] = g_iDefaultConfig;
        ge_iConfig[glow][CONFIG_TEAM] = 0;
        ge_iConfig[glow][CONFIG_FADEMAX] = 0;
    }

    if (IsValidClient(client))
        PrintToChat(client, "\x04Glow added to all valid entities.");

    return Plugin_Handled;
}

/****************************************************************************************************/

Action CmdPrintCvars(int client, int args)
{
    PrintToConsole(client, "");
    PrintToConsole(client, "======================================================================");
    PrintToConsole(client, "");
    PrintToConsole(client, "------------------- Plugin Cvars (l4d1_glow_item) --------------------");
    PrintToConsole(client, "");
    PrintToConsole(client, "l4d1_glow_item_version : %s", PLUGIN_VERSION);
    PrintToConsole(client, "l4d1_glow_item_enable : %b (%s)", g_bCvar_Enabled, g_bCvar_Enabled ? "true" : "false");
    PrintToConsole(client, "l4d1_glow_item_remove_spawner : %b (%s)", g_bCvar_RemoveSpawner, g_bCvar_RemoveSpawner ? "true" : "false");
    PrintToConsole(client, "l4d1_glow_item_health_cabinet : %b (%s)", g_bCvar_HealthCabinet, g_bCvar_HealthCabinet ? "true" : "false");
    PrintToConsole(client, "l4d1_glow_item_interval : %.1f", g_fCvar_Interval);
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