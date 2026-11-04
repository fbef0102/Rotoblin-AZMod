#define PLUGIN_VERSION "1.9-2026/11/15"

#pragma semicolon 1

#include <sourcemod>
#include <left4dhooks>
#include <l4d_lib>
#include <multicolors>

public Plugin myinfo =
{
	name = "[L4D] Tank Attack Control",
	author = "vintik, raziEiL [disawar1],CanadaRox, Jacob, Visor, Forgetest, Harry Potter",
	description = "change tank punch or throw rock animation",
	version = PLUGIN_VERSION,
	url = "http://steamcommunity.com/profiles/76561198026784913"
}

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

enum
{
	NullHook = 0,
	UpperHook = 38,
	RightHook = 41,
	LeftHook = 43,
	Throw = 46,
	OneOverhand, //47 - 1handed overhand (MOUSE2)
	Underhand, //48 - underhand (E)
	TwoOverhand //49 - 2handed overhand (R)
}

ConVar hCvarPunchControl;
int g_iCvarPunchControl;

int 
	g_iQueuedThrow[MAXPLAYERS + 1],
	g_iQueuedPunch[MAXPLAYERS + 1];

bool 
	g_bQueuedCommandThrow[MAXPLAYERS+1],
	g_bIgnorePlayer[MAXPLAYERS+1];

StringMap 
	g_smWhitelist;

public OnPluginStart()
{
	LoadTranslations("Roto2-AZ_mod.phrases");

	hCvarPunchControl = CreateConVar("tank_attack_punch_control", "1", "0: Valve random punch animation, 1: Force right hook punch animation and bind them to MOUSE1+E/R buttons, 2: Force right hook punch animation but dont bind buttons.", _, true, 0.0, true, 2.0);

	GetCvars();
	hCvarPunchControl.AddChangeHook(ConVarChanged_Cvars);
	
	HookEvent("tank_spawn", TankSpawn_Event, EventHookMode_Post);

	RegConsoleCmd("sm_underhand", Cmd_sm_underhand);
	RegConsoleCmd("sm_overhand", Cmd_sm_overhand);
	RegConsoleCmd("sm_overonehand", Cmd_sm_overonehand);

	delete g_smWhitelist;
	g_smWhitelist = new StringMap();
}

void ConVarChanged_Cvars(ConVar hCvar, const char[] sOldVal, const char[] sNewVal)
{
	GetCvars();
}

void GetCvars()
{
    g_iCvarPunchControl = hCvarPunchControl.IntValue;
}

public void OnConfigsExecuted()
{
	delete g_smWhitelist;
	g_smWhitelist = new StringMap();

	char sWhitelist[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sWhitelist, sizeof(sWhitelist), "data/l4d_tank_attack_control.cfg");

	File hFile = OpenFile(sWhitelist, "r");

	if(hFile == null)
	{
		SetFailState("data/l4d_tank_attack_control.cfg does not exist");
		delete hFile;
		return;
	}

	char auth[64];
	while(!hFile.EndOfFile() && hFile.ReadLine(auth, sizeof(auth)))
	{
		TrimString(auth);
		StripQuotes(auth);

		if(strlen(auth) < 1) continue;
		if(strncmp(auth, "//", 2, false) == 0) continue;

		g_smWhitelist.SetValue(auth, true, true);
	}

	delete hFile;
}

public void OnClientPostAdminCheck(int client)
{
	if(IsFakeClient(client)) return;

	static char authId[64];
	if (!GetClientAuthId(client, AuthId_SteamID64, authId, sizeof(authId)))
		return;

	g_bIgnorePlayer[client] = false;
	if(g_smWhitelist.ContainsKey(authId))
	{
		g_bIgnorePlayer[client] = true;
	}
}

public void OnClientDisconnect(int client)
{
	g_bIgnorePlayer[client] = false;
	g_bQueuedCommandThrow[client] = false;
	g_iQueuedThrow[client] = NullHook;
}

Action Cmd_sm_underhand(int client, int args)
{
	if (!client || !IsClientInGame(client) || GetClientTeam(client) != 3 || !IsPlayerTank(client) || !IsPlayerAlive(client))
		return Plugin_Continue;

	g_bQueuedCommandThrow[client] = true;
	g_iQueuedThrow[client] = Underhand; //underhand
	return Plugin_Handled;
}

Action Cmd_sm_overhand(int client, int args)
{
	if (!client || !IsClientInGame(client) || GetClientTeam(client) != 3 || !IsPlayerTank(client) || !IsPlayerAlive(client))
		return Plugin_Continue;
	
	g_bQueuedCommandThrow[client] = true;
	g_iQueuedThrow[client] = TwoOverhand; //two hand overhand
	return Plugin_Handled;
}

Action Cmd_sm_overonehand(int client, int args)
{
	if (!client || !IsClientInGame(client) || GetClientTeam(client) != 3 || !IsPlayerTank(client) || !IsPlayerAlive(client))
		return Plugin_Continue;
	
	g_bQueuedCommandThrow[client] = true;
	g_iQueuedThrow[client] = OneOverhand; //one hand overhand
	return Plugin_Handled;
}

void TankSpawn_Event(Event event, const char[] name, bool dontBroadcast)
{
	int tank = GetClientOfUserId(event.GetInt("userid"));
	if (!tank || !IsClientInGame(tank) || IsFakeClient(tank) || g_bIgnorePlayer[tank]) return;

	CPrintToChat(tank, "%T","l4d_tank_attack_control_Rock", tank);
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (!IsClientInGame(client) || GetClientTeam(client) != 3 || !IsPlayerTank(client) || !IsPlayerAlive(client)
		|| IsFakeClient(client) )
		return Plugin_Continue;

	bool bCommandThrow = g_bQueuedCommandThrow[client];
	g_bQueuedCommandThrow[client] = false;

	if (bCommandThrow)
	{
		buttons |= IN_ATTACK2;
	}
	else
	{
		if(g_bIgnorePlayer[client]) return Plugin_Continue;

		if(buttons & IN_ATTACK2)
		{
			g_iQueuedThrow[client] = OneOverhand;
		}
		else if (buttons & IN_USE)
		{
			g_iQueuedThrow[client] = Underhand;
			buttons |= IN_ATTACK2;
		}
		else if (buttons & IN_RELOAD)
		{
			g_iQueuedThrow[client] = TwoOverhand;
			buttons |= IN_ATTACK2;
		}
	}

	if(g_bIgnorePlayer[client]) return Plugin_Continue;

	if (g_iCvarPunchControl > 0 && (buttons & IN_ATTACK))
	{
		if (g_iCvarPunchControl == 1)
		{
			if (buttons & IN_USE)
				g_iQueuedPunch[client] = LeftHook;
			else if (buttons & IN_RELOAD)
				g_iQueuedPunch[client] = UpperHook;
			else
				g_iQueuedPunch[client] = RightHook;
		}
		else if (g_iCvarPunchControl == 2)
		{
			g_iQueuedPunch[client] = RightHook;
		}
	}
	
	return Plugin_Continue;
}

public Action L4D2_OnSelectTankAttack(int client, int &sequence)
{
	if(IsFakeClient(client)) return Plugin_Continue;

	if (sequence > Throw && g_iQueuedThrow[client] > NullHook) // throw
	{
		//rock throw
		sequence = g_iQueuedThrow[client];
		RequestFrame(OnNextFrame_OnSelectTankAttack, client);
		return Plugin_Handled;
	}
	
	
	if (g_iCvarPunchControl > 0 && sequence < Throw && NullHook < g_iQueuedPunch[client] < Throw) // punch
	{ 
		sequence = g_iQueuedPunch[client];
		RequestFrame(OnNextFrame_OnSelectTankAttack, client);
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

void OnNextFrame_OnSelectTankAttack(int client)
{
	g_iQueuedThrow[client] = NullHook;
	g_iQueuedPunch[client] = NullHook;
}