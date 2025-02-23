/**
 * 沒有設置 "效果細節" -> "中"或"高"以上 的玩家會被旁觀
 */

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <multicolors>      // https://github.com/fbef0102/L4D1_2-Plugins/releases

#define PLUGIN_VERSION			"1.0-2025/2/18"
#define PLUGIN_NAME			    "l4d_cpu_level"
#define DEBUG 0

public Plugin myinfo =
{
	name = "[L4D1] CPU LEVEL",
	author = "HarryPotter",
	description = "Spectate player if cpu_level is low",
	version = PLUGIN_VERSION,
	url = "https://steamcommunity.com/profiles/76561198026784913/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    EngineVersion test = GetEngineVersion();

    if( test != Engine_Left4Dead )
    {
        strcopy(error, err_max, "Plugin only supports Left 4 Dead 1.");
        return APLRes_SilentFailure;
    }

    return APLRes_Success;
}

#define TRANSLATION_FILE		PLUGIN_NAME ... ".phrases"

#define CVAR_FLAGS                    FCVAR_NOTIFY
#define CVAR_FLAGS_PLUGIN_VERSION     FCVAR_NOTIFY|FCVAR_DONTRECORD|FCVAR_SPONLY

#define TEAM_SPECTATOR		1
#define TEAM_SURVIVOR		2
#define TEAM_INFECTED		3

ConVar g_hCvarEnable, g_hCvarEffectDetail;
bool g_bCvarEnable, g_bCvarEffectDetail;

Handle ClientSettingsCheckTimer;

public void OnPluginStart()
{
	LoadTranslations(TRANSLATION_FILE);

	g_hCvarEnable 				= CreateConVar( PLUGIN_NAME ... "_enable",        			"1",   "0=Plugin off, 1=Plugin on.", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_hCvarEffectDetail			= CreateConVar( PLUGIN_NAME ... "_effect_detail", 			"1",   "If 1, Spectate players if effect detail is low", CVAR_FLAGS, true, 0.0, true, 1.0);
	CreateConVar(                       		PLUGIN_NAME ... "_version",      			PLUGIN_VERSION, PLUGIN_NAME ... " Plugin Version", CVAR_FLAGS_PLUGIN_VERSION);

	GetCvars();
	g_hCvarEnable.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarEffectDetail.AddChangeHook(ConVarChanged_Cvars);
}

// Cvars-------------------------------

void ConVarChanged_Cvars(ConVar hCvar, const char[] sOldVal, const char[] sNewVal)
{
	GetCvars();
}

void GetCvars()
{
	g_bCvarEnable = g_hCvarEnable.BoolValue;
	g_bCvarEffectDetail = g_hCvarEffectDetail.BoolValue;
}

// Sourcemod API Forward-------------------------------

public void OnConfigsExecuted()
{
	delete ClientSettingsCheckTimer;
	ClientSettingsCheckTimer = CreateTimer(2.5, Timer_CheckClients, _, TIMER_REPEAT);
}

// Timer & Frame-------------------------------

Action Timer_CheckClients(Handle timer)
{
	if(!g_bCvarEnable) return Plugin_Continue;

	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && !IsFakeClient(client))
		{
			if(g_bCvarEffectDetail) QueryClientConVar(client, "cpu_level", Query_cpu_level, 0);
		}
	}	

	return Plugin_Continue;
}

// Function-------------------------------

void Query_cpu_level(QueryCookie cookie, int client, ConVarQueryResult result, \
												const char[] cvarName, const char[] cvarValue, any value)
{
	if (!IsClientInGame(client) || IsClientInKickQueue(client)) 
	{
		// Client disconnected or got kicked already
		return;
	}

	if (result) // not found
	{
		return;
	}

	int iVal = StringToInt(cvarValue);

	if(iVal <= 0)
	{
		if(GetClientTeam(client) > TEAM_SPECTATOR )
		{
			PrintHintText(client, "%T", "Message", client);
			CPrintToChatAll("%t", "Reason", client);
			ChangeClientTeam(client, TEAM_SPECTATOR);
		}
	}
}