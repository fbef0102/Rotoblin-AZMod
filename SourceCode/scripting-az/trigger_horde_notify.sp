#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <dhooks>
#include <multicolors>
#include <left4dhooks>
#define PLUGIN_VERSION			"1.1-2026/10/1"
#define PLUGIN_NAME			    "trigger_horde_notify"
#define DEBUG 0

public Plugin myinfo =
{
    name = "[L4D] trigger horde notify",
    author = "HarryPotter",
    description = "As the name says, you dumb as fuck",
    version = PLUGIN_VERSION,
    url = "https://steamcommunity.com/profiles/76561198026784913/"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    EngineVersion test = GetEngineVersion();

    if( test != Engine_Left4Dead )
    {
        strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
        return APLRes_SilentFailure;
    }

    return APLRes_Success;
}

#define CVAR_FLAGS                    FCVAR_NOTIFY
#define CVAR_FLAGS_PLUGIN_VERSION     FCVAR_NOTIFY|FCVAR_DONTRECORD|FCVAR_SPONLY

ConVar g_hNotifyHordEnable, g_hNotifyFinalEnable, g_hColdDown;
float g_fColdDown;
bool g_bNotifyHordEnable, g_bNotifyFinalEnable;

float g_fTriggerHordeTime;
bool g_bFinalMap, g_bRescueStart;

#define TEAM_SPECTATOR                1
#define TEAM_SURVIVOR                 2
#define TEAM_INFECTED                 3

#define FLAG_TEAM_NONE                (0 << 0) // 0 | 0000
#define FLAG_TEAM_SURVIVOR            (1 << 0) // 1 | 0001
#define FLAG_TEAM_INFECTED            (1 << 1) // 2 | 0010
#define FLAG_TEAM_SPECTATOR           (1 << 2) // 4 | 0100

public void OnPluginStart()
{
    LoadTranslations("Roto2-AZ_mod.phrases");

    g_hNotifyHordEnable =       CreateConVar(       PLUGIN_NAME ... "_event_enable",    "1",  "If 1, notify who triggered the horde", CVAR_FLAGS, true, 0.0);
    g_hNotifyFinalEnable =       CreateConVar(      PLUGIN_NAME ... "_final_enable",    "1",  "If 1, notify who triggered the final", CVAR_FLAGS, true, 0.0);
    g_hColdDown         =       CreateConVar(       PLUGIN_NAME ... "_cool_down_time",  "3.0",  "Cold down time to notify again.", CVAR_FLAGS, true, 0.0);
    CreateConVar(                                   PLUGIN_NAME ... "_version",         PLUGIN_VERSION, PLUGIN_NAME ... " Plugin Version", CVAR_FLAGS_PLUGIN_VERSION);

    GetCvars();
    g_hColdDown.AddChangeHook(ConVarChanged_Cvars);
    g_hNotifyHordEnable.AddChangeHook(ConVarChanged_Cvars);
    g_hNotifyFinalEnable.AddChangeHook(ConVarChanged_Cvars);

    HookEvent("round_start",            Event_RoundStart,		EventHookMode_PostNoCopy);
    HookEvent("finale_start", Event_Finale_Start, EventHookMode_PostNoCopy); //final starts, some of final maps won't trigger
    HookEvent("finale_radio_start", Event_Finale_Start, EventHookMode_PostNoCopy); //final starts, all final maps trigger
    HookEvent("create_panic_event", Event_create_panic_event);
}

void ConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
    g_bNotifyHordEnable = g_hNotifyHordEnable.BoolValue;
    g_bNotifyFinalEnable =  g_hNotifyFinalEnable.BoolValue;
    g_fColdDown = g_hColdDown.FloatValue;
}

public void OnMapStart()
{
    g_bFinalMap = false;

    if(L4D_IsMissionFinalMap(true))
    {
        g_bFinalMap = true;

        int entity = -1;
        if ((entity = FindEntityByClassname(entity, "trigger_finale")) != -1)
        {
            HookSingleEntityOutput(entity, "UseStart", OnFinalTriggered);
        }
    }
}

public void OnEntityCreated(int entity, const char[] classname) //late spawn
{
    if (!IsValidEntityIndex(entity))
        return;

    if(!g_bFinalMap)
        return;

    switch (classname[0])
    {
        case 't':
        {
            if (strncmp(classname, "trigger_finale", 14) == 0)
            {
                HookSingleEntityOutput(entity, "UseStart", OnFinalTriggered);
            }
        }
    }
}

void Event_create_panic_event(Event event, const char[] name, bool dontBroadcast)
{
    if(g_bRescueStart || !g_bNotifyHordEnable) return;

    int client = GetClientOfUserId(event.GetInt("userid"));
    if(client && IsClientInGame(client) && GetClientTeam(client) == L4D_TEAM_SURVIVOR)
    {
        if(g_fTriggerHordeTime < GetEngineTime())
        {
            PrintToTeam(FLAG_TEAM_SPECTATOR | FLAG_TEAM_SURVIVOR, "[{olive}TS{default}] %t", "trigger_horde_notify_Horde", client);
            g_fTriggerHordeTime = GetEngineTime() + g_fColdDown;
        }
    }
} 

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    g_fTriggerHordeTime = 0.0;
    g_bRescueStart = false;
} 

void Event_Finale_Start(Event event, const char[] name, bool dontBroadcast)
{
    if(g_bRescueStart || !g_bNotifyFinalEnable) return;
    
    PrintToTeam(FLAG_TEAM_SPECTATOR | FLAG_TEAM_SURVIVOR, "[{olive}TS{default}] %t", "trigger_horde_notify_Final Rescue Start");
    
    g_bRescueStart = true;
}

void OnFinalTriggered(const char[] output, int caller, int activator, float delay)
{
    if(g_bNotifyFinalEnable && activator > 0 && activator < MaxClients+1 && IsClientInGame(activator))
    {
        PrintToTeam(FLAG_TEAM_SPECTATOR | FLAG_TEAM_SURVIVOR, "[{olive}TS{default}] %t", "trigger_horde_notify_Final Rescue", activator);
    }

    UnhookSingleEntityOutput(caller, "UseStart", OnFinalTriggered);
}

bool IsValidEntityIndex(int entity)
{
    return (MaxClients+1 <= entity <= GetMaxEntities());
}

void PrintToTeam(int teamflag, const char[] text, any ...)
{
	bool bTrans = StrContains(text, "%t") != -1;

	char sTemp[256];
	for (int i = 1; i <= MaxClients; i++){

		if (IsClientInGame(i) && (teamflag & GetTeamFlag(GetClientTeam(i))) && !IsFakeClient(i)){

			if (bTrans)
				SetGlobalTransTarget(i);

			VFormat(sTemp, sizeof(sTemp), text, 3);

			CPrintToChat(i, sTemp);
		}
	}
}

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
        default:
            return FLAG_TEAM_NONE;
    }
}