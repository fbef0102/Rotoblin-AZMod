#define PLUGIN_VERSION "1.7-2025/11/4"

#pragma semicolon 1

#include <sourcemod>
#include <left4dhooks>
#include <l4d_lib>
#include <multicolors>

public Plugin:myinfo =
{
	name = "[L4D] Tank Attack Control",
	author = "vintik, raziEiL [disawar1], Harry Potter",
	description = "change tank punch or throw rock animation",
	version = PLUGIN_VERSION,
	url = "http://steamcommunity.com/profiles/76561198026784913"
}

enum Seq
{
	Null = 0,
	UpperHook = 38,
	RightHook = 41,
	LeftHook = 43,
	Throw = 46,
	OneOverhand, //47 - 1handed overhand (MOUSE2)
	Underhand, //48 - underhand (E)
	TwoOverhand //49 - 2handed overhand (R)
}

static		g_iCvarPunchControl, Float:g_fCvarPunchDelay, Float:g_fCvarThrowDelay, bool:g_bTankInGame, Seq:g_seqQueuedThrow[MAXPLAYERS+1],
			bool:g_bPunchBlock[MAXPLAYERS+1], bool:g_bThrowBlock[MAXPLAYERS+1];
static		bool:g_bCvar1v1Mode;

bool 
	g_bBrokenPlayer[MAXPLAYERS+1];

public OnPluginStart()
{
	LoadTranslations("Roto2-AZ_mod.phrases");
	new Handle:hCvarSurvLimit			= FindConVar("survivor_limit");
	new Handle:hCvarPunchDelay = FindConVar("z_tank_attack_interval");
	new Handle:hCvarThrowDelay = FindConVar("z_tank_throw_interval");

	new Handle:hCvarPunchControl = CreateConVar("tank_attack_punch_control", "0", "0: Valve random punch animation, 1: Force right hook punch animation and bind them to MOUSE1+E/R buttons, 2: Force right hook punch animation but dont bind buttons.", _, true, 0.0, true, 2.0);

	g_iCvarPunchControl = GetConVarInt(hCvarPunchControl);
	g_fCvarPunchDelay = GetConVarFloat(hCvarPunchDelay);
	g_fCvarThrowDelay = GetConVarFloat(hCvarThrowDelay);
	g_bCvar1v1Mode	= GetConVarInt(hCvarSurvLimit) == 1 ? true : false;	
	
	HookConVarChange(hCvarPunchControl, TAC_OnPunchCvarChange);
	HookConVarChange(hCvarPunchDelay, TAC_OnPunchDelayCvarChange);
	HookConVarChange(hCvarThrowDelay, TAC_OnThrowDealyCvarChange);

	HookEvent("tank_spawn", TAC_ev_TankSpawn, EventHookMode_PostNoCopy);
	HookEvent("round_start", TAC_ev_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("entity_killed", TAC_ev_EntityKilled);
	HookEvent("tank_frustrated",		PD_ev_TankFrustrated);
}

public TAC_OnPunchCvarChange(Handle:convar_hndl, const String:oldValue[], const String:newValue[])
{
	g_iCvarPunchControl = GetConVarInt(convar_hndl);
}

public TAC_OnPunchDelayCvarChange(Handle:convar_hndl, const String:oldValue[], const String:newValue[])
{
	g_fCvarPunchDelay = GetConVarFloat(convar_hndl);
}

public TAC_OnThrowDealyCvarChange(Handle:convar_hndl, const String:oldValue[], const String:newValue[])
{
	g_fCvarThrowDelay = GetConVarFloat(convar_hndl);
}

public void OnClientPostAdminCheck(int client)
{
	g_bBrokenPlayer[client] = false;
	
	static char cmpSteamId[32];
	GetClientAuthId(client, AuthId_SteamID64, cmpSteamId, sizeof(cmpSteamId));
	if (StrEqual(cmpSteamId, "76561198020896967") //for JJ,小文 who has problem with keyboard
		|| StrEqual(cmpSteamId, "76561198308064273")) 
		g_bBrokenPlayer[client] = true;
}

public void OnClientDisconnect(int client)
{
	g_bBrokenPlayer[client] = false;
}

public Action:TAC_ev_TankSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!g_bTankInGame)
		CreateTimer(10.0, TAC_t_Instruction);

	g_bTankInGame = true;
}

public Action:TAC_ev_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_bTankInGame = false;
}

public Action:TAC_ev_EntityKilled(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (g_bTankInGame && IsPlayerTank(GetEventInt(event, "entindex_killed")))
		CreateTimer(4.0, TAC_t_FindAnyTank, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:TAC_t_FindAnyTank(Handle:timer)
{
	for (new i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i) && IsPlayerTank(i) && !IsIncapacitated(i))
			return;

	g_bTankInGame = false;
}

public Action:PD_ev_TankFrustrated(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (g_bCvar1v1Mode){		
		CreateTimer(1.0,COLD_DOWN);
	}
}

public Action:COLD_DOWN(Handle:timer)
{
	g_bTankInGame = false;
}

FindTank() 
{
	for (new i = 1; i <= MaxClients; i++) 
	{
		if (IsClientInGame(i)&&IsInfected(i) && GetEntProp(i, Prop_Send, "m_zombieClass") == 5 && IsPlayerAlive(i))
			return i;
	}

	return -1;
}

public Action:TAC_t_Instruction(Handle:timer)
{
	new i = FindTank();
	if(i == -1)
		return;

	CPrintToChat(i,"%T","l4d_tank_attack_control_Rock",i);
}

public Action:OnPlayerRunCmd(client, &buttons)
{
	if (!g_bTankInGame || !buttons || GetClientTeam(client) != 3 || IsFakeClient(client) || !IsPlayerTank(client) || !IsPlayerAlive(client))
		return Plugin_Continue;

	if(buttons & IN_ATTACK2)
	{
		if(g_bBrokenPlayer[client]) return Plugin_Continue;

		g_seqQueuedThrow[client] = OneOverhand;
	}
	else if (buttons & IN_USE)
	{
		if(g_bBrokenPlayer[client]) return Plugin_Continue;
		
		g_seqQueuedThrow[client] = Underhand;
		buttons |= IN_ATTACK2;
	}
	else if (buttons & IN_RELOAD)
	{
		if(g_bBrokenPlayer[client]) return Plugin_Continue;

		g_seqQueuedThrow[client] = TwoOverhand;
		buttons |= IN_ATTACK2;
	}
	
	if (g_iCvarPunchControl > 0 && (buttons & IN_ATTACK))
	{
		if (g_iCvarPunchControl == 1)
		{
			if (buttons & IN_USE)
				g_seqQueuedThrow[client] = LeftHook;
			else if (buttons & IN_RELOAD)
				g_seqQueuedThrow[client] = UpperHook;
			else
				g_seqQueuedThrow[client] = RightHook;
		}
		else if (g_iCvarPunchControl == 2)
		{
			g_seqQueuedThrow[client] = RightHook;
		}
	}
	
	return Plugin_Continue;
}

public Action L4D2_OnSelectTankAttack(int client, int &sequence)
{
	if (g_seqQueuedThrow[client] != Null)
	{
		if (sequence > _:Throw) // throw
		{ 
			if(unlock_play_list(client)) return Plugin_Continue;

			if (g_seqQueuedThrow[client] > Throw)
			{
				if (!g_bThrowBlock[client])
				{
					g_bThrowBlock[client] = true;
					CreateTimer(g_fCvarThrowDelay, TAC_t_UnlockThrowControl, client);
				}

				sequence = _:g_seqQueuedThrow[client];
				return Plugin_Handled;
			}
		}
		else if (g_iCvarPunchControl && g_seqQueuedThrow[client] < Throw) // punch
		{ 
			if (!g_bPunchBlock[client])
			{
				g_bPunchBlock[client] = true;
				CreateTimer(g_fCvarPunchDelay, TAC_t_UnlockPunchControl, client);
			}

			sequence = _:g_seqQueuedThrow[client];
			return Plugin_Handled;
		}
	}

	return Plugin_Continue;
}

public Action:TAC_t_UnlockThrowControl(Handle:timer, any:client)
{
	g_bThrowBlock[client] = false;
}

public Action:TAC_t_UnlockPunchControl(Handle:timer, any:client)
{
	g_bPunchBlock[client] = false;
}

stock unlock_play_list(client)
{
	static char cmpSteamId[32];
	GetClientAuthId(client, AuthId_Steam2, cmpSteamId, sizeof(cmpSteamId));
	if (StrEqual("STEAM_1:1:30315619", cmpSteamId)||StrEqual("STEAM_1:1:173899272", cmpSteamId)) //for JJ,小文 who has problem with keyboard
		return true;
		
	return false;
}