#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>
#include <multicolors>

#define PLUGIN_VERSION "2.2"

public Plugin myinfo =
{
	name = "Death Cam Skip Fix",
	author = "Jacob, Sir, Forgetest, Harry",
	description = "Blocks players skipping their death time by going spec",
	version = PLUGIN_VERSION,
	url = "https://github.com/SirPlease/L4D2-Competitive-Rework"
}

float g_flSavedTime[MAXPLAYERS + 1] = {0.0, ...};
bool g_bSkipPrint[MAXPLAYERS + 1], 
	g_bBlockButtons[MAXPLAYERS + 1];
ConVar g_cvExploitAnnounce;

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

public void OnPluginStart()
{
	HookEvent("round_start", Event_RoundStart);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_team", Event_PlayerTeam);
	
	g_cvExploitAnnounce = CreateConVar("deathcam_skip_announce", "1", "Print a message when someone exploits.", FCVAR_SPONLY, true, 0.0, true, 1.0);
}

public void OnClientPutInServer(int client)
{
	g_bBlockButtons[client] = false;
	g_flSavedTime[client] = 0.0;
	g_bSkipPrint[client] = false;
}

void Event_RoundStart(Event event, char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; ++i)
	{
		g_bBlockButtons[i] = false;
		g_flSavedTime[i] = 0.0;
		g_bSkipPrint[i] = false;
	}
}

void Event_PlayerDeath(Event event, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!IsValidInfected(client))
		return;
	
	SetExploiter(client);

	SDKUnhook(client, SDKHook_PreThink, Player_OnPreThink);
	SDKHook(client, SDKHook_PreThink, Player_OnPreThink);
}

void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int team = event.GetInt("team");
	int oldteam = event.GetInt("oldteam");
	if (team == oldteam)
		return;
	
	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);
	if (!client || !IsClientInGame(client))
		return;
	
	if (oldteam == 3)
	{
		if (IsPlayerAlive(client) && !GetEntProp(client, Prop_Send, "m_isGhost"))
		{
			SetExploiter(client);
		}
	}
	else if (team == 3)
	{
		RequestFrame(OnNextFrame_PlayerTeam, userid);
	}
}

void OnNextFrame_PlayerTeam(int userid)
{
	int client = GetClientOfUserId(userid);
	if (!IsValidInfected(client))
		return;
	
	if (g_flSavedTime[client] == 0.0)
		return;
	
	if (GetGameTime() - g_flSavedTime[client] >= 6.0)
		return;
	
	L4D_State_Transition(client, STATE_DEATH_ANIM);
	SetEntPropFloat(client, Prop_Send, "m_flDeathTime", g_flSavedTime[client]);
	SDKUnhook(client, SDKHook_PreThink, Player_OnPreThink);
	SDKHook(client, SDKHook_PreThink, Player_OnPreThink);

	WarnExploiting(client);
}

void WarnExploiting(int client)
{
	if (!g_cvExploitAnnounce.BoolValue)
		return;
	
	if (g_bSkipPrint[client])
		return;
	
	//CPrintToChatAll("{red}[{default}Exploit{red}] {olive}%N {default}tried skipping the Death Timer.", client);
	g_bSkipPrint[client] = true;
}

void SetExploiter(int client)
{
	g_flSavedTime[client] = GetGameTime();
	g_bSkipPrint[client] = false;
}

bool IsValidInfected(int client)
{ 
	if (client <= 0 || client > MaxClients)
		return false; 

	return IsClientInGame(client) && GetClientTeam(client) == 3 && !IsFakeClient(client); 
}

Action Player_OnPreThink(int client)
{
	if (NotInPlayerDeathCam(client))
	{
		g_bBlockButtons[client] = false;
		SDKUnhook(client, SDKHook_PreThink, Player_OnPreThink);
	}

	return Plugin_Continue;
}

bool NotInPlayerDeathCam(int client)
{
	int state = GetEntProp(client, Prop_Send, "m_iPlayerState");
	if (state == STATE_DEATH_ANIM || state == STATE_DEATH_WAIT_FOR_KEY)
	{
		g_bBlockButtons[client] = true;
	}

	//if (state == STATE_DEATH_WAIT_FOR_KEY)
	//{
	//	SetEntPropFloat(client, Prop_Send, "m_flDeathTime", 0.0);
	//	return true;
	//}

	return false;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if(IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == 3 && !IsPlayerAlive(client) && g_bBlockButtons[client])
	{
		buttons = 0;
		return Plugin_Changed;
	}

	return Plugin_Continue;	
}
