/**
// ====================================================================================================
Change Log:

1.0.4 (18-February-2021)
    - Added cvar to multiply the laser beam alpha based on client render alpha. (thanks "3aljiyavslgazana" for requesting)

1.0.3 (16-February-2021)
    - Added attack delay visibility cvar for survivors.

1.0.2 (12-February-2021)
    - Fixed L4D1 compatibility. (thanks "HarryPotter" for reporting)
    - Added cvar to run by frame instead by timer. (thanks "RA" for requesting)
    - Added cvar to set white laser beam color for black and white survivors.

1.0.1 (12-February-2021)
    - Fixed laser beam showing on infecteds while in ghost mode. (thanks "R.A" for reporting)
    - Fixed temporary health.
    - Added cvars to control the laser beam visibility by team.

1.0.0 (11-February-2021)
    - Initial release.

// ====================================================================================================
*/

// ====================================================================================================
// Plugin Info - define
// ====================================================================================================
#define PLUGIN_NAME                   "[L4D1 & L4D2] HP Laser"
#define PLUGIN_AUTHOR                 "Mart"
#define PLUGIN_DESCRIPTION            "Shows a laser beam at the client head based on its HP"
#define PLUGIN_VERSION                "1.0.4"
#define PLUGIN_URL                    "https://forums.alliedmods.net/showthread.php?t=330590"

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
#define CONFIG_FILENAME               "l4d_hp_laser"

// ====================================================================================================
// Defines
// ====================================================================================================
#define CLASSNAME_TANK_ROCK           "tank_rock"

#define TEAM_SPECTATOR                1
#define TEAM_SURVIVOR                 2
#define TEAM_INFECTED                 3
#define TEAM_HOLDOUT                  4

#define FLAG_TEAM_NONE                (0 << 0) // 0 | 0000
#define FLAG_TEAM_SURVIVOR            (1 << 0) // 1 | 0001
#define FLAG_TEAM_INFECTED            (1 << 1) // 2 | 0010
#define FLAG_TEAM_SPECTATOR           (1 << 2) // 4 | 0100
#define FLAG_TEAM_HOLDOUT             (1 << 3) // 8 | 1000

#define L4D2_ZOMBIECLASS_SMOKER       1
#define L4D2_ZOMBIECLASS_BOOMER       2
#define L4D2_ZOMBIECLASS_HUNTER       3
#define L4D2_ZOMBIECLASS_SPITTER      4
#define L4D2_ZOMBIECLASS_JOCKEY       5
#define L4D2_ZOMBIECLASS_CHARGER      6
#define L4D2_ZOMBIECLASS_TANK         8

#define L4D1_ZOMBIECLASS_SMOKER       1
#define L4D1_ZOMBIECLASS_BOOMER       2
#define L4D1_ZOMBIECLASS_HUNTER       3
#define L4D1_ZOMBIECLASS_TANK         5

#define L4D2_FLAG_ZOMBIECLASS_NONE    0
#define L4D2_FLAG_ZOMBIECLASS_SMOKER  1
#define L4D2_FLAG_ZOMBIECLASS_BOOMER  2
#define L4D2_FLAG_ZOMBIECLASS_HUNTER  4
#define L4D2_FLAG_ZOMBIECLASS_SPITTER 8
#define L4D2_FLAG_ZOMBIECLASS_JOCKEY  16
#define L4D2_FLAG_ZOMBIECLASS_CHARGER 32
#define L4D2_FLAG_ZOMBIECLASS_TANK    64

#define L4D1_FLAG_ZOMBIECLASS_NONE    0
#define L4D1_FLAG_ZOMBIECLASS_SMOKER  1
#define L4D1_FLAG_ZOMBIECLASS_BOOMER  2
#define L4D1_FLAG_ZOMBIECLASS_HUNTER  4
#define L4D1_FLAG_ZOMBIECLASS_TANK    8

#define MAXENTITIES                   2048

// ====================================================================================================
// Native Cvars
// ====================================================================================================
static ConVar g_hCvar_survivor_incap_health;
static ConVar g_hCvar_survivor_max_incapacitated_count;
static ConVar g_hCvar_pain_pills_decay_rate;

// ====================================================================================================
// Plugin Cvars
// ====================================================================================================
static ConVar g_hCvar_Enabled;
static ConVar g_hCvar_ZAxis;
static ConVar g_hCvar_FadeDistance;
static ConVar g_hCvar_Sight;
static ConVar g_hCvar_AttackDelay;
static ConVar g_hCvar_Model;
static ConVar g_hCvar_Alpha;
static ConVar g_hCvar_Height;
static ConVar g_hCvar_Fill;
static ConVar g_hCvar_FillAlpha;
static ConVar g_hCvar_Outline;
static ConVar g_hCvar_OutlineHeight;
static ConVar g_hCvar_RenderFrame;
static ConVar g_hCvar_SkipFrame;
static ConVar g_hCvar_BlackAndWhite;
static ConVar g_hCvar_Team;
static ConVar g_hCvar_SurvivorTeam;
static ConVar g_hCvar_InfectedTeam;
static ConVar g_hCvar_SpectatorTeam;
static ConVar g_hCvar_MultiplyAlphaTeam;
static ConVar g_hCvar_SurvivorWidth;
static ConVar g_hCvar_InfectedWidth;
static ConVar g_hCvar_SI;

// ====================================================================================================
// bool - Plugin Variables
// ====================================================================================================
static bool   g_bL4D2;
static bool   g_bConfigLoaded;
static bool   g_bEventsHooked;
static bool   g_bCvar_survivor_max_incapacitated_count;
static bool   g_bCvar_Enabled;
static bool   g_bCvar_FadeDistance;
static bool   g_bCvar_Sight;
static bool   g_bCvar_AttackDelay;
static bool   g_bCvar_Fill;
static bool   g_bCvar_Outline;
static bool   g_bCvar_RenderFrame;
static bool   g_bCvar_SkipFrame;
static bool   g_bCvar_BlackAndWhite;

// ====================================================================================================
// int - Plugin Variables
// ====================================================================================================
static int    g_iModelBeam;
static int    g_iFrameCount;
static int    g_iCvar_survivor_incap_health;
static int    g_iCvar_survivor_max_incapacitated_count;
static int    g_iCvar_Alpha;
static int    g_iCvar_FillAlpha;
static int    g_iCvar_SkipFrame;
static int    g_iCvar_Team;
static int    g_iCvar_SurvivorTeam;
static int    g_iCvar_InfectedTeam;
static int    g_iCvar_SpectatorTeam;
static int    g_iCvar_MultiplyAlphaTeam;
static int    g_iCvar_SI;

// ====================================================================================================
// float - Plugin Variables
// ====================================================================================================
static float  g_fvPlayerMins[3] = {-16.0, -16.0,  0.0};
static float  g_fvPlayerMaxs[3] = { 16.0,  16.0, 71.0};
static float  g_fBeamLife;
static float  g_fCvar_pain_pills_decay_rate;
static float  g_fCvar_ZAxis;
static float  g_fCvar_FadeDistance;
static float  g_fCvar_AttackDelay;
static float  g_fCvar_Height;
static float  g_fCvar_OutlineHeight;
static float  g_fCvar_SurvivorWidth;
static float  g_fCvar_InfectedWidth;

// ====================================================================================================
// string - Plugin Variables
// ====================================================================================================
static char   g_sCvar_Model[100];

// ====================================================================================================
// client - Plugin Variables
// ====================================================================================================
static bool   gc_bVisible[MAXPLAYERS+1][MAXPLAYERS+1];
static float  gc_fLastAttack[MAXPLAYERS+1][MAXPLAYERS+1];

// ====================================================================================================
// entity - Plugin Variables
// ====================================================================================================
static bool   ge_bInvalidTrace[MAXENTITIES+1];

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
    g_fBeamLife = (g_bL4D2 ? 0.1 : 0.11); // less than 0.11 reads as 0 in L4D1

    return APLRes_Success;
}

/****************************************************************************************************/

public void OnPluginStart()
{
    g_hCvar_survivor_incap_health = FindConVar("survivor_incap_health");
    g_hCvar_survivor_max_incapacitated_count = FindConVar("survivor_max_incapacitated_count");
    g_hCvar_pain_pills_decay_rate = FindConVar("pain_pills_decay_rate");

    CreateConVar("l4d_hp_laser_version", PLUGIN_VERSION, PLUGIN_DESCRIPTION, CVAR_FLAGS_PLUGIN_VERSION);
    g_hCvar_Enabled           = CreateConVar("l4d_hp_laser_enable", "1", "Enable/Disable the plugin.\n0 = Disable, 1 = Enable.", CVAR_FLAGS, true, 0.0, true, 1.0);
    g_hCvar_ZAxis             = CreateConVar("l4d_hp_laser_z_axis", "85", "Additional Z distance based on client position.", CVAR_FLAGS, true, 0.0);
    g_hCvar_FadeDistance      = CreateConVar("l4d_hp_laser_fade_distance", "0", "Minimum distance that a client must be from another client to see the laser beam HP.\n0 = Always visible.", CVAR_FLAGS, true, 0.0);
    g_hCvar_Sight             = CreateConVar("l4d_hp_laser_sight", "1", "Show a laser beam HP to the survivor only if the special infected is on sight.\n0 = OFF, 1 = ON.", CVAR_FLAGS, true, 0.0, true, 1.0);
    g_hCvar_AttackDelay       = CreateConVar("l4d_hp_laser_attack_delay", "0.0", "Show the laser beam to the survivor attacker, by this amount of time in seconds, after hitting a special infected.\n0 = OFF.", CVAR_FLAGS, true, 0.0);
    g_hCvar_Model             = CreateConVar("l4d_hp_laser_model", "materials/vgui/white_additive.vmt", "Model of the laser beam HP.");
    g_hCvar_Alpha             = CreateConVar("l4d_hp_laser_alpha", "240", "Alpha of the laser beam HP.\n0 = Invisible, 255 = Fully Visible", CVAR_FLAGS, true, 0.0, true, 255.0);
    g_hCvar_Height            = CreateConVar("l4d_hp_laser_height", "1.0", "Height of the laser beam HP.", CVAR_FLAGS, true, 0.0);
    g_hCvar_Fill              = CreateConVar("l4d_hp_laser_fill", "1", "Display a laser beam HP to fill the bar.\nNote: Disable this if you intend to show a lot of laser beams HP. The game limits the number of beams rendered at the same time when limit exceeds it may not draw then all.\n0 = OFF, 1 = ON.", CVAR_FLAGS, true, 0.0, true, 1.0);
    g_hCvar_FillAlpha         = CreateConVar("l4d_hp_laser_fill_alpha", "40", "Alpha of the laser beam HP that fills the bar.\n0 = Invisible, 255 = Fully Visible", CVAR_FLAGS, true, 0.0, true, 255.0);
    g_hCvar_Outline           = CreateConVar("l4d_hp_laser_outline", "0", "Show an outline (add 4 lasers) around the laser beam HP.\nNote: Disable this if you intend to show a lot of laser beams HP. The game limits the number of beams rendered at the same time when limit exceeds it may not draw then al.\n0 = OFF, 1 = ON.", CVAR_FLAGS, true, 0.0, true, 1.0);
    g_hCvar_OutlineHeight     = CreateConVar("l4d_hp_laser_outline_height", g_bL4D2 ? "0.07" : "0.13", "Outline height of the laser beam.\nNote: Less than 0.07 may no render in L4D2 and less than 0.13 may no render in L4D1.", CVAR_FLAGS, true, 0.0);
    g_hCvar_RenderFrame       = CreateConVar("l4d_hp_laser_render_frame", "0", "Render type used to draw the laser beams.\n0 = Timer (0.1 seconds - less expensive), 1 = OnGameFrame (by frame - more expensive).", CVAR_FLAGS, true, 0.0, true, 1.0);
    g_hCvar_SkipFrame         = CreateConVar("l4d_hp_laser_skip_frame", "1", "How many frames should skip while using l4d_hp_laser_render_type = \"1\" (OnGameFrame). Frames may vary depending on your tickrate. Using a higher value than 2 becomes slower than with the timer on default tick rate (30)", CVAR_FLAGS, true, 0.0);
    g_hCvar_BlackAndWhite     = CreateConVar("l4d_hp_laser_black_and_white", "1", "Show a laser beam HP in white on \"black and white\" survivors.\n0 = OFF, 1 = ON.", CVAR_FLAGS, true, 0.0, true, 1.0);
    g_hCvar_Team              = CreateConVar("l4d_hp_laser_team", "3", "Which teams should have a laser beam HP.\n0 = NONE, 1 = SURVIVOR, 2 = INFECTED, 4 = SPECTATOR, 8 = HOLDOUT.\nAdd numbers greater than 0 for multiple options.\nExample: \"3\", enables for SURVIVOR and INFECTED.", CVAR_FLAGS, true, 0.0, true, 15.0);
    g_hCvar_SurvivorTeam      = CreateConVar("l4d_hp_laser_survivor_team", "3", "Which teams survivors can see a laser beam HP.\n0 = NONE, 1 = SURVIVOR, 2 = INFECTED, 4 = SPECTATOR, 8 = HOLDOUT.\nAdd numbers greater than 0 for multiple options.\nExample: \"3\", enables for SURVIVOR and INFECTED.", CVAR_FLAGS, true, 0.0, true, 15.0);
    g_hCvar_InfectedTeam      = CreateConVar("l4d_hp_laser_infected_team", "3", "Which teams infected can see a laser beam HP.\n0 = NONE, 1 = SURVIVOR, 2 = INFECTED, 4 = SPECTATOR, 8 = HOLDOUT.\nAdd numbers greater than 0 for multiple options.\nExample: \"3\", enables for SURVIVOR and INFECTED.", CVAR_FLAGS, true, 0.0, true, 15.0);
    g_hCvar_SpectatorTeam     = CreateConVar("l4d_hp_laser_spectator_team", "3", "Which teams spectators can see a laser beam HP.\n0 = NONE, 1 = SURVIVOR, 2 = INFECTED, 4 = SPECTATOR, 8 = HOLDOUT.\nAdd numbers greater than 0 for multiple options.\nExample: \"3\", enables for SURVIVOR and INFECTED.", CVAR_FLAGS, true, 0.0, true, 15.0);
    g_hCvar_MultiplyAlphaTeam = CreateConVar("l4d_hp_laser_multiply_alpha_team", "2", "Which teams should multiply the laser beam HP alpha based on the client render alpha.\n0 = NONE, 1 = SURVIVOR, 2 = INFECTED, 4 = SPECTATOR, 8 = HOLDOUT.\nAdd numbers greater than 0 for multiple options.\nExample: \"3\", enables for SURVIVOR and INFECTED.", CVAR_FLAGS, true, 0.0, true, 15.0);
    g_hCvar_SurvivorWidth     = CreateConVar("l4d_hp_laser_survivor_width", "15.0", "Width of the survivor laser beam HP.", CVAR_FLAGS, true, 0.0);
    g_hCvar_InfectedWidth     = CreateConVar("l4d_hp_laser_infected_width", "30.0", "Width of the infected laser beam HP.", CVAR_FLAGS, true, 0.0);

    if (g_bL4D2)
        g_hCvar_SI        = CreateConVar("l4d_hp_laser_si", "64", "Which special infected should have a laser beam HP.\n1=SMOKER, 2 = BOOMER, 4 = HUNTER, 8 = SPITTER, 16 = JOCKEY, 32 = CHARGER, 64 = TANK.\nAdd numbers greater than 0 for multiple options.\nExample: \"127\", enables laser beam HP for all SI.", CVAR_FLAGS, true, 0.0, true, 127.0);
    else
        g_hCvar_SI        = CreateConVar("l4d_hp_laser_si", "8", "Which special infected should have a laser beam HP.\n1 = SMOKER, 2  =  BOOMER, 4 = HUNTER, 8 = TANK.\nAdd numbers greater than 0 for multiple options.\nExample: \"15\", enables laser beam HP for all SI.", CVAR_FLAGS, true, 0.0, true, 15.0);

    g_hCvar_survivor_incap_health.AddChangeHook(Event_ConVarChanged);
    g_hCvar_survivor_max_incapacitated_count.AddChangeHook(Event_ConVarChanged);
    g_hCvar_pain_pills_decay_rate.AddChangeHook(Event_ConVarChanged);
    g_hCvar_Enabled.AddChangeHook(Event_ConVarChanged);
    g_hCvar_ZAxis.AddChangeHook(Event_ConVarChanged);
    g_hCvar_FadeDistance.AddChangeHook(Event_ConVarChanged);
    g_hCvar_Sight.AddChangeHook(Event_ConVarChanged);
    g_hCvar_AttackDelay.AddChangeHook(Event_ConVarChanged);
    g_hCvar_Model.AddChangeHook(Event_ConVarChanged);
    g_hCvar_Alpha.AddChangeHook(Event_ConVarChanged);
    g_hCvar_Height.AddChangeHook(Event_ConVarChanged);
    g_hCvar_Fill.AddChangeHook(Event_ConVarChanged);
    g_hCvar_FillAlpha.AddChangeHook(Event_ConVarChanged);
    g_hCvar_Outline.AddChangeHook(Event_ConVarChanged);
    g_hCvar_OutlineHeight.AddChangeHook(Event_ConVarChanged);
    g_hCvar_RenderFrame.AddChangeHook(Event_ConVarChanged);
    g_hCvar_SkipFrame.AddChangeHook(Event_ConVarChanged);
    g_hCvar_BlackAndWhite.AddChangeHook(Event_ConVarChanged);
    g_hCvar_Team.AddChangeHook(Event_ConVarChanged);
    g_hCvar_SurvivorTeam.AddChangeHook(Event_ConVarChanged);
    g_hCvar_InfectedTeam.AddChangeHook(Event_ConVarChanged);
    g_hCvar_SpectatorTeam.AddChangeHook(Event_ConVarChanged);
    g_hCvar_MultiplyAlphaTeam.AddChangeHook(Event_ConVarChanged);
    g_hCvar_SurvivorWidth.AddChangeHook(Event_ConVarChanged);
    g_hCvar_InfectedWidth.AddChangeHook(Event_ConVarChanged);
    g_hCvar_SI.AddChangeHook(Event_ConVarChanged);

    // Load plugin configs from .cfg
    AutoExecConfig(true, CONFIG_FILENAME);

    // Admin Commands
    RegAdminCmd("sm_print_cvars_l4d_hp_laser", CmdPrintCvars, ADMFLAG_ROOT, "Print the plugin related cvars and their respective values to the console.");

    CreateTimer(0.1, TimerVisible, _, TIMER_REPEAT);
    CreateTimer(0.1, TimerRender, _, TIMER_REPEAT);
}

/****************************************************************************************************/

public void OnConfigsExecuted()
{
    GetCvars();

    g_bConfigLoaded = true;

    HookEvents(g_bCvar_Enabled);
}

/****************************************************************************************************/

public void Event_ConVarChanged(Handle convar, const char[] sOldValue, const char[] sNewValue)
{
    GetCvars();

    HookEvents(g_bCvar_Enabled);
}

/****************************************************************************************************/

public void GetCvars()
{
    g_iCvar_survivor_incap_health = g_hCvar_survivor_incap_health.IntValue;
    g_iCvar_survivor_max_incapacitated_count = g_hCvar_survivor_max_incapacitated_count.IntValue;
    g_bCvar_survivor_max_incapacitated_count = (g_iCvar_survivor_max_incapacitated_count > 0);
    g_fCvar_pain_pills_decay_rate = g_hCvar_pain_pills_decay_rate.FloatValue;
    g_bCvar_Enabled = g_hCvar_Enabled.BoolValue;
    g_fCvar_ZAxis = g_hCvar_ZAxis.FloatValue;
    g_fCvar_FadeDistance = g_hCvar_FadeDistance.FloatValue;
    g_bCvar_FadeDistance = (g_fCvar_FadeDistance > 0.0);
    g_bCvar_Sight = g_hCvar_Sight.BoolValue;
    g_fCvar_AttackDelay = g_hCvar_AttackDelay.FloatValue;
    g_bCvar_AttackDelay = (g_fCvar_AttackDelay > 0.0);
    g_hCvar_Model.GetString(g_sCvar_Model, sizeof(g_sCvar_Model));
    TrimString(g_sCvar_Model);
    g_iModelBeam = PrecacheModel(g_sCvar_Model, true);
    g_iCvar_Alpha = g_hCvar_Alpha.IntValue;
    g_fCvar_Height = g_hCvar_Height.FloatValue;
    g_bCvar_Fill = g_hCvar_Fill.BoolValue;
    g_iCvar_FillAlpha = g_hCvar_FillAlpha.IntValue;
    g_bCvar_Outline = g_hCvar_Outline.BoolValue;
    g_fCvar_OutlineHeight = g_hCvar_OutlineHeight.FloatValue;
    g_bCvar_RenderFrame = g_hCvar_RenderFrame.BoolValue;
    g_iFrameCount = 0;
    g_iCvar_SkipFrame = g_hCvar_SkipFrame.IntValue;
    g_bCvar_SkipFrame = (g_iCvar_SkipFrame > 0);
    g_bCvar_BlackAndWhite = g_hCvar_BlackAndWhite.BoolValue;
    g_iCvar_Team = g_hCvar_Team.IntValue;
    g_iCvar_SurvivorTeam = g_hCvar_SurvivorTeam.IntValue;
    g_iCvar_InfectedTeam = g_hCvar_InfectedTeam.IntValue;
    g_iCvar_SpectatorTeam = g_hCvar_SpectatorTeam.IntValue;
    g_iCvar_MultiplyAlphaTeam = g_hCvar_MultiplyAlphaTeam.IntValue;
    g_fCvar_SurvivorWidth = g_hCvar_SurvivorWidth.FloatValue;
    g_fCvar_InfectedWidth = g_hCvar_InfectedWidth.FloatValue;
    g_iCvar_SI = g_hCvar_SI.IntValue;
}

/****************************************************************************************************/

public void OnClientDisconnect(int client)
{
    if (!g_bConfigLoaded)
        return;

    for (int target = 1; target <= MaxClients; target++)
    {
        gc_bVisible[target][client] = false;
        gc_fLastAttack[target][client] = 0.0;
    }
}

/****************************************************************************************************/

public void OnEntityDestroyed(int entity)
{
    if (!g_bConfigLoaded)
        return;

    if (!IsValidEntityIndex(entity))
        return;

    ge_bInvalidTrace[entity] = false;
}

/****************************************************************************************************/

public void OnEntityCreated(int entity, const char[] classname)
{
    if (!g_bConfigLoaded)
        return;

    if (!IsValidEntityIndex(entity))
        return;

    switch (classname[0])
    {
        case 't':
        {
            if (StrEqual(classname, CLASSNAME_TANK_ROCK))
                ge_bInvalidTrace[entity] = true;
        }
    }
}

/****************************************************************************************************/

public void HookEvents(bool hook)
{
    if (hook && !g_bEventsHooked)
    {
        g_bEventsHooked = true;

        HookEvent("player_hurt", Event_PlayerHurt);

        return;
    }

    if (!hook && g_bEventsHooked)
    {
        g_bEventsHooked = false;

        UnhookEvent("player_hurt", Event_PlayerHurt);

        return;
    }
}

/****************************************************************************************************/

public void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_bCvar_AttackDelay)
        return;

    int target = GetClientOfUserId(event.GetInt("userid"));

    if (!IsValidClientIndex(target))
        return;

    int attacker = GetClientOfUserId(event.GetInt("attacker"));

    if (!IsValidClientIndex(attacker))
        return;

    gc_fLastAttack[target][attacker] = GetGameTime();
}

/****************************************************************************************************/

public Action TimerVisible(Handle timer)
{
    if (!g_bConfigLoaded)
        return Plugin_Continue;

    for (int target = 1; target <= MaxClients; target++)
    {
        if (!ShouldRenderHP(target))
            continue;

        int targetTeamFlag = GetTeamFlag(GetClientTeam(target));

        for (int client = 1; client <= MaxClients; client++)
        {
            gc_bVisible[target][client] = false;

            if (!IsClientInGame(client))
                continue;

            if (IsFakeClient(client))
                continue;

            int clientTeamFlag = GetTeamFlag(GetClientTeam(client));

            switch (clientTeamFlag)
            {
                case FLAG_TEAM_SURVIVOR, FLAG_TEAM_HOLDOUT:
                {
                    if (!(targetTeamFlag & g_iCvar_SurvivorTeam))
                        continue;
                }
                case FLAG_TEAM_INFECTED:
                {
                    if (!(targetTeamFlag & g_iCvar_InfectedTeam))
                        continue;
                }
                case FLAG_TEAM_SPECTATOR:
                {
                    if (!(targetTeamFlag & g_iCvar_SpectatorTeam))
                        continue;
                }
            }

            if (g_bCvar_FadeDistance)
            {
                float targetPos[3];
                GetClientAbsOrigin(target, targetPos);

                float clientPos[3];
                GetClientAbsOrigin(client, clientPos);

                if (GetVectorDistance(targetPos, clientPos) > g_fCvar_FadeDistance)
                    continue;
            }

            if (targetTeamFlag == FLAG_TEAM_INFECTED && clientTeamFlag == FLAG_TEAM_SURVIVOR)
            {
                if (g_bCvar_AttackDelay && (GetGameTime() - gc_fLastAttack[target][client] > g_fCvar_AttackDelay))
                    continue;

                if (g_bCvar_Sight && !IsVisibleTo(client, target))
                    continue;
            }

            gc_bVisible[target][client] = true;
        }
    }

    return Plugin_Continue;
}

/****************************************************************************************************/

public Action TimerRender(Handle timer)
{
    if (!g_bConfigLoaded)
        return Plugin_Continue;

    if (!g_bCvar_Enabled)
        return Plugin_Continue;

    if (g_bCvar_RenderFrame)
        return Plugin_Continue;

    RenderHealthBar();

    return Plugin_Continue;
}

/****************************************************************************************************/

public void OnGameFrame()
{
    if (!g_bConfigLoaded)
        return;

    if (!g_bCvar_Enabled)
        return;

    if (!g_bCvar_RenderFrame)
        return;

    if (g_bCvar_SkipFrame)
    {
        if (++g_iFrameCount <= g_iCvar_SkipFrame)
            return;

        g_iFrameCount = 0;
    }

    RenderHealthBar();
}

/****************************************************************************************************/

public void RenderHealthBar()
{
    for (int target = 1; target <= MaxClients; target++)
    {
        if (!ShouldRenderHP(target))
            continue;

        bool isSurvivor;
        bool isIncapacitated = IsPlayerIncapacitated(target);

        int maxHealth = GetEntProp(target, Prop_Data, "m_iMaxHealth");
        int currentHealth = GetClientHealth(target);
        int targetTeam = GetClientTeam(target);
        int targetTeamFlag = GetTeamFlag(targetTeam);

        float radius;

        switch (targetTeam)
        {
            case TEAM_SURVIVOR, TEAM_HOLDOUT:
            {
                isSurvivor = true;

                radius = g_fCvar_SurvivorWidth;

                if (isIncapacitated)
                    maxHealth = g_iCvar_survivor_incap_health;
                else
                    currentHealth += RoundToCeil(GetClientTempHealth(target));
            }
            case TEAM_INFECTED:
            {
                radius = g_fCvar_InfectedWidth;

                if (isIncapacitated)
                    maxHealth = 0;
            }
        }

        float percentageHealth;

        if (maxHealth > 0)
            percentageHealth = (float(currentHealth) / float(maxHealth));

        bool halfHealth = (percentageHealth <= 0.5);

        int alpha;
        int colorAlpha[4];

        if (targetTeamFlag & g_iCvar_MultiplyAlphaTeam)
        {
            GetEntityRenderColor(target, colorAlpha[0], colorAlpha[1], colorAlpha[2], colorAlpha[3]);
            alpha = RoundFloat(g_iCvar_Alpha * colorAlpha[3] / 255.0);
        }
        else
        {
            alpha = g_iCvar_Alpha;
        }

        int color[4];
        if (isIncapacitated)
        {
            color[0] = 255;
            color[1] = 0;
            color[2] = 0;
            color[3] = alpha;
        }
        else if (g_bCvar_BlackAndWhite && isSurvivor && g_bCvar_survivor_max_incapacitated_count && IsPlayerBlackAndWhite(target))
        {
            color[0] = 255;
            color[1] = 255;
            color[2] = 255;
            color[3] = alpha;
        }
        else
        {
            color[0] = halfHealth ? 255 : RoundFloat(255.0 * ((1.0 - percentageHealth) * 2));
            color[1] = halfHealth ? RoundFloat(255.0 * (percentageHealth) * 2) : 255;
            color[2] = 0;
            color[3] = alpha;
        }

        float targetPos[3];
        GetClientAbsOrigin(target, targetPos);
        targetPos[2] += g_fCvar_ZAxis;

        for (int client = 1; client <= MaxClients; client++)
        {
            if (client == target)
                continue;

            if (!gc_bVisible[target][client])
                continue;

            if (!IsClientInGame(client))
                continue;

            float clientPos[3];
            GetClientAbsOrigin(client, clientPos);
            clientPos[2] += g_fCvar_ZAxis;

            float vecPos[3];
            MakeVectorFromPoints(targetPos, clientPos, vecPos);

            float clientAng[3];
            GetVectorAngles(vecPos, clientAng);

            // left
            float targetMin[3];
            targetMin = targetPos;
            targetMin[0] += radius * Cosine(DegToRad(clientAng[1] - 90.0));
            targetMin[1] += radius * Sine(DegToRad(clientAng[1] - 90.0));

            // right
            float targetMax[3];
            targetMax = targetPos;
            targetMax[0] += radius * Cosine(DegToRad(clientAng[1] + 90.0));
            targetMax[1] += radius * Sine(DegToRad(clientAng[1] + 90.0));

            // current
            float targetCurrent[3];
            targetCurrent = targetPos;
            targetCurrent[0] = (percentageHealth * (targetMax[0] - targetMin[0])) + targetMin[0];
            targetCurrent[1] = (percentageHealth * (targetMax[1] - targetMin[1])) + targetMin[1];

            float vPoint1[3];
            float vPoint2[3];

            // inside bar
            vPoint1 = targetMin;
            vPoint2 = targetCurrent;
            TE_SetupBeamPoints(vPoint1, vPoint2, g_iModelBeam, 0, 0, 0, g_fBeamLife, g_fCvar_Height, g_fCvar_Height, 0, 0.0, color, 0);
            TE_SendToClient(client);

            if (g_bCvar_Fill)
            {
                int alphaFill;

                if (targetTeamFlag & g_iCvar_MultiplyAlphaTeam)
                    alphaFill = RoundFloat(g_iCvar_FillAlpha * colorAlpha[3] / 255.0);
                else
                    alphaFill = g_iCvar_FillAlpha;

                int colorFill[4];
                colorFill = color;
                colorFill[3] = alphaFill;
                vPoint1 = targetCurrent;
                vPoint2 = targetMax;
                TE_SetupBeamPoints(vPoint1, vPoint2, g_iModelBeam, 0, 0, 0, g_fBeamLife, g_fCvar_Height, g_fCvar_Height, 0, 0.0, colorFill, 0);
                TE_SendToClient(client);
            }

            if (g_bCvar_Outline)
            {
                // top outline bar
                vPoint1 = targetMin;
                vPoint2 = targetMax;
                vPoint1[2] += g_fCvar_Height + g_fCvar_OutlineHeight;
                vPoint2[2] += g_fCvar_Height + g_fCvar_OutlineHeight;
                TE_SetupBeamPoints(vPoint1, vPoint2, g_iModelBeam, 0, 0, 0, g_fBeamLife, g_fCvar_OutlineHeight, g_fCvar_OutlineHeight, 0, 0.0, color, 0);
                TE_SendToClient(client);

                // bottom outline bar
                vPoint1 = targetMin;
                vPoint2 = targetMax;
                vPoint1[2] -= g_fCvar_Height + g_fCvar_OutlineHeight;
                vPoint2[2] -= g_fCvar_Height + g_fCvar_OutlineHeight;
                TE_SetupBeamPoints(vPoint1, vPoint2, g_iModelBeam, 0, 0, 0, g_fBeamLife, g_fCvar_OutlineHeight, g_fCvar_OutlineHeight, 0, 0.0, color, 0);
                TE_SendToClient(client);

                // left outline bar
                vPoint1 = targetMin;
                vPoint2 = targetMin;
                vPoint1[2] += g_fCvar_Height + g_fCvar_OutlineHeight;
                vPoint2[2] -= g_fCvar_Height + g_fCvar_OutlineHeight;
                TE_SetupBeamPoints(vPoint1, vPoint2, g_iModelBeam, 0, 0, 0, g_fBeamLife, g_fCvar_OutlineHeight, g_fCvar_OutlineHeight, 0, 0.0, color, 0);
                TE_SendToClient(client);

                // right outline bar
                vPoint1 = targetMax;
                vPoint2 = targetMax;
                vPoint1[2] += g_fCvar_Height + g_fCvar_OutlineHeight;
                vPoint2[2] -= g_fCvar_Height + g_fCvar_OutlineHeight;
                TE_SetupBeamPoints(vPoint1, vPoint2, g_iModelBeam, 0, 0, 0, g_fBeamLife, g_fCvar_OutlineHeight, g_fCvar_OutlineHeight, 0, 0.0, color, 0);
                TE_SendToClient(client);
            }
        }
    }
}

/****************************************************************************************************/

bool ShouldRenderHP(int target)
{
    if (!g_bCvar_Enabled)
        return false;

    if (!IsClientInGame(target))
        return false;

    if (!IsPlayerAlive(target))
        return false;

    int targetTeam = GetClientTeam(target);
    int targetTeamFlag = GetTeamFlag(targetTeam);

    if (!(targetTeamFlag & g_iCvar_Team))
        return false;

    if (targetTeam == TEAM_INFECTED)
    {
        if (IsPlayerGhost(target))
            return false;

        if (!(GetZombieClassFlag(target) & g_iCvar_SI))
            return false;
    }

    return true;
}

/****************************************************************************************************/

bool IsVisibleTo(int client, int target)
{
    float vClientPos[3];
    float vEntityPos[3];
    float vLookAt[3];
    float vAng[3];

    GetClientEyePosition(client, vClientPos);
    GetClientEyePosition(target, vEntityPos);
    MakeVectorFromPoints(vClientPos, vEntityPos, vLookAt);
    GetVectorAngles(vLookAt, vAng);

    Handle trace = TR_TraceRayFilterEx(vClientPos, vAng, MASK_PLAYERSOLID, RayType_Infinite, TraceFilter, target);

    bool isVisible;

    if (TR_DidHit(trace))
    {
        isVisible = (TR_GetEntityIndex(trace) == target);

        if (!isVisible)
        {
            vEntityPos[2] -= 62.0; // results the same as GetClientAbsOrigin

            delete trace;
            trace = TR_TraceHullFilterEx(vClientPos, vEntityPos, g_fvPlayerMins, g_fvPlayerMaxs, MASK_PLAYERSOLID, TraceFilter, target);

            if (TR_DidHit(trace))
                isVisible = (TR_GetEntityIndex(trace) == target);
        }
    }

    delete trace;

    return isVisible;
}

/****************************************************************************************************/

public bool TraceFilter(int entity, int contentsMask, int client)
{
    if (entity == client)
        return true;

    if (IsValidClientIndex(entity))
        return false;

    return ge_bInvalidTrace[entity] ? false : true;
}

/****************************************************************************************************/

public Action CmdPrintCvars(int client, int args)
{
    PrintToConsole(client, "");
    PrintToConsole(client, "======================================================================");
    PrintToConsole(client, "");
    PrintToConsole(client, "-------------------- Plugin Cvars (l4d_hp_laser) ---------------------");
    PrintToConsole(client, "");
    PrintToConsole(client, "l4d_hp_laser_version : %s", PLUGIN_VERSION);
    PrintToConsole(client, "l4d_hp_laser_enable : %b (%s)", g_bCvar_Enabled, g_bCvar_Enabled ? "true" : "false");
    PrintToConsole(client, "l4d_hp_laser_z_axis : %.2f", g_fCvar_ZAxis);
    PrintToConsole(client, "l4d_hp_laser_fade_distance : %i (%s)", g_fCvar_FadeDistance, g_bCvar_FadeDistance ? "true" : "false");
    PrintToConsole(client, "l4d_hp_laser_sight : %b (%s)", g_bCvar_Sight, g_bCvar_Sight ? "true" : "false");
    PrintToConsole(client, "l4d_hp_laser_model : \"%s\"", g_sCvar_Model);
    PrintToConsole(client, "l4d_hp_laser_alpha : %i", g_iCvar_Alpha);
    PrintToConsole(client, "l4d_hp_laser_height : %.2f", g_fCvar_Height);
    PrintToConsole(client, "l4d_hp_laser_fill : %b (%s)", g_bCvar_Fill, g_bCvar_Fill ? "true" : "false");
    PrintToConsole(client, "l4d_hp_laser_fill_alpha : %i", g_iCvar_FillAlpha);
    PrintToConsole(client, "l4d_hp_laser_outline : %b (%s)", g_bCvar_Outline, g_bCvar_Outline ? "true" : "false");
    PrintToConsole(client, "l4d_hp_laser_outline_height : %.3f", g_fCvar_OutlineHeight);
    PrintToConsole(client, "l4d_hp_laser_render_frame : %b (%s)", g_bCvar_RenderFrame, g_bCvar_RenderFrame ? "true" : "false");
    PrintToConsole(client, "l4d_hp_laser_skip_frame : %i (%s)", g_iCvar_SkipFrame, g_bCvar_SkipFrame ? "true" : "false");
    PrintToConsole(client, "l4d_hp_laser_black_and_white : %b (%s)", g_bCvar_BlackAndWhite, g_bCvar_BlackAndWhite ? "true" : "false");
    PrintToConsole(client, "l4d_hp_laser_team : %i", g_iCvar_Team);
    PrintToConsole(client, "l4d_hp_laser_survivor_team : %i", g_iCvar_SurvivorTeam);
    PrintToConsole(client, "l4d_hp_laser_infected_team : %i", g_iCvar_InfectedTeam);
    PrintToConsole(client, "l4d_hp_laser_spectator_team : %i", g_iCvar_SpectatorTeam);
    PrintToConsole(client, "l4d_hp_laser_multiply_alpha_team : %i", g_iCvar_MultiplyAlphaTeam);
    PrintToConsole(client, "l4d_hp_laser_survivor_width : %.2f", g_fCvar_SurvivorWidth);
    PrintToConsole(client, "l4d_hp_laser_infected_width : %.2f", g_fCvar_InfectedWidth);
    PrintToConsole(client, "l4d_hp_laser_si : %i", g_iCvar_SI);
    PrintToConsole(client, "");
    PrintToConsole(client, "---------------------------- Game Cvars  -----------------------------");
    PrintToConsole(client, "");
    PrintToConsole(client, "survivor_incap_health : %i", g_iCvar_survivor_incap_health);
    PrintToConsole(client, "survivor_max_incapacitated_count : %i", g_iCvar_survivor_max_incapacitated_count);
    PrintToConsole(client, "pain_pills_decay_rate : %.2f", g_fCvar_pain_pills_decay_rate);
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
 * Validates if is a valid entity index (between MaxClients+1 and 2048).
 *
 * @param entity        Entity index.
 * @return              True if entity index is valid, false otherwise.
 */
bool IsValidEntityIndex(int entity)
{
    return (MaxClients+1 <= entity <= GetMaxEntities());
}

/****************************************************************************************************/

/**
 * Gets the client L4D1/L4D2 zombie class id.
 *
 * @param client        Client index.
 * @return L4D1         1=SMOKER, 2=BOOMER, 3=HUNTER, 4=WITCH, 5=TANK, 6=NOT INFECTED
 * @return L4D2         1=SMOKER, 2=BOOMER, 3=HUNTER, 4=SPITTER, 5=JOCKEY, 6=CHARGER, 7=WITCH, 8=TANK, 9=NOT INFECTED
 */
int GetZombieClass(int client)
{
    return (GetEntProp(client, Prop_Send, "m_zombieClass"));
}

/****************************************************************************************************/

/**
 * Returns the zombie class flag from a zombie class.
 *
 * @param client        Client index.
 * @return              Client zombie class flag.
 */
int GetZombieClassFlag(int client)
{
    int zombieClass = GetZombieClass(client);

    if (g_bL4D2)
    {
        switch (zombieClass)
        {
            case L4D2_ZOMBIECLASS_SMOKER:
                return L4D2_FLAG_ZOMBIECLASS_SMOKER;
            case L4D2_ZOMBIECLASS_BOOMER:
                return L4D2_FLAG_ZOMBIECLASS_BOOMER;
            case L4D2_ZOMBIECLASS_HUNTER:
                return L4D2_FLAG_ZOMBIECLASS_HUNTER;
            case L4D2_ZOMBIECLASS_SPITTER:
                return L4D2_FLAG_ZOMBIECLASS_SPITTER;
            case L4D2_ZOMBIECLASS_JOCKEY:
                return L4D2_FLAG_ZOMBIECLASS_JOCKEY;
            case L4D2_ZOMBIECLASS_CHARGER:
                return L4D2_FLAG_ZOMBIECLASS_CHARGER;
            case L4D2_ZOMBIECLASS_TANK:
                return L4D2_FLAG_ZOMBIECLASS_TANK;
            default:
                return L4D2_FLAG_ZOMBIECLASS_NONE;
        }
    }
    else
    {
        switch (zombieClass)
        {
            case L4D1_ZOMBIECLASS_SMOKER:
                return L4D1_FLAG_ZOMBIECLASS_SMOKER;
            case L4D1_ZOMBIECLASS_BOOMER:
                return L4D1_FLAG_ZOMBIECLASS_BOOMER;
            case L4D1_ZOMBIECLASS_HUNTER:
                return L4D1_FLAG_ZOMBIECLASS_HUNTER;
            case L4D1_ZOMBIECLASS_TANK:
                return L4D1_FLAG_ZOMBIECLASS_TANK;
            default:
                return L4D1_FLAG_ZOMBIECLASS_NONE;
        }
    }
}

/****************************************************************************************************/

/**
 * Returns is a player is in ghost state.
 *
 * @param client        Client index.
 * @return              True if client is in ghost state, false otherwise.
 */
bool IsPlayerGhost(int client)
{
    return (GetEntProp(client, Prop_Send, "m_isGhost") == 1);
}

/****************************************************************************************************/

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
 * Validates if the client is in black and white.
 *
 * @param client        Client index.
 * @return              True if the client is in black and white, false otherwise.
 */
bool IsPlayerBlackAndWhite(int client)
{
    return (GetEntProp(client, Prop_Send, "m_currentReviveCount") >= g_iCvar_survivor_max_incapacitated_count);
}

/****************************************************************************************************/

/**
 * Returns the team flag from a team.
 *
 * @param team          Team index.
 * @return              Team flag.
 */
int GetTeamFlag(int team)
{
    switch (team)
    {
        case TEAM_SURVIVOR:
            return FLAG_TEAM_SURVIVOR;
        case TEAM_INFECTED:
            return FLAG_TEAM_INFECTED;
        case TEAM_SPECTATOR:
            return FLAG_TEAM_SPECTATOR;
        case TEAM_HOLDOUT:
            return FLAG_TEAM_HOLDOUT;
        default:
            return FLAG_TEAM_NONE;
    }
}

/****************************************************************************************************/

// ====================================================================================================
// Thanks to Silvers
// ====================================================================================================
/**
 * Returns the client temporary health.
 *
 * @param client        Client index.
 * @return              Client temporary health.
 */
float GetClientTempHealth(int client)
{
    float fHealth = GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
    fHealth -= (GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * g_fCvar_pain_pills_decay_rate;
    return fHealth < 0.0 ? 0.0 : fHealth;
}