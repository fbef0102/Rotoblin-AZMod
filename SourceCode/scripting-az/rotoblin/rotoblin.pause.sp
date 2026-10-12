/*
 * ============================================================================
 *
 *  Rotoblin
 *
 *  File:			rotoblin.pause.sp
 *  Type:			Module
 *  Description:	Allows players to pause the game, or admins force pause.
 *	Credits:		pvtschlag at alliedmodders for [L4D2] Pause plugin. 
 *					"Loosely" stolen.
 *
 *  Copyright (C) 2010  Mr. Zero <mrzerodk@gmail.com>
 *  Copyright (C) 2017-2026  Harry <fbef0102@gmail.com>
 *  This file is part of Rotoblin.
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * ============================================================================
 */

// --------------------
//       Private
// --------------------

static	const	String:	PLUGIN_FORCEPAUSE_COMMAND[]		= "forcepause";
static	const	String:	PLUGIN_FORCEUNPAUSE_COMMAND[]	= "forceunpause";
static	const	String:	PLUGIN_ready_COMMAND[]			= "!ready";

static			Handle:	g_hPauseEnable_Cvar			= INVALID_HANDLE;
static			bool:	g_bIsPauseEnable			= true;

ConVar sv_pausable, sv_noclipduringpause;
static			bool:	g_bIsPaused					= false;
static			bool:	g_bIsUnpausing				= false;
static			bool:	g_bWasForced				= false;
new Handle:pauseDelayCvar;
new pauseDelay;
new Handle:deferredPauseTimer;
bool hiddenPanel[MAXPLAYERS+1];
char g_sAdminName[64];

enum 
{
	L4D1Team_None = 0,
	L4D1Team_Spectator,
	L4D1Team_Survivor,
	L4D1Team_Infected
}

new Handle:menuPanel;
new bool:teamReady[4];

native IsInReady();
new TimeCount;


bool 
	RoundEnd,
	listened;

public _Pause_OnPluginStart()
{
	HookPublicEvent(EVENT_ONPLUGINENABLE, _P_OnPluginEnabled);
	HookPublicEvent(EVENT_ONPLUGINDISABLE, _P_OnPluginDisabled);

	g_hPauseEnable_Cvar = CreateConVarEx("pause", "1", "Sets whether the game can be paused", FCVAR_NOTIFY);
	
	AddConVarToReport(g_hPauseEnable_Cvar); // Add to report status module
	
	pauseDelayCvar = CreateConVarEx("pausedelay", "0", "Delay to apply before a pause happens.  Could be used to prevent Tactical Pauses", FCVAR_NOTIFY, true, 0.0);
}

/**
 * Plugin is now enabled.
 *
 * @noreturn
 */
public _P_OnPluginEnabled()
{
	HookPublicEvent(EVENT_ONMAPEND, _P_OnMapEnd);
	HookPublicEvent(EVENT_ONCLIENTDISCONNECT_POST, _P_OnClientDisconnect);

	sv_pausable = FindConVar("sv_pausable");
	sv_noclipduringpause = FindConVar("sv_noclipduringpause");
	
	g_bIsPaused = false;
	g_bIsUnpausing = false;
	g_bWasForced = false;

	g_bIsPauseEnable = GetConVarBool(g_hPauseEnable_Cvar);
	HookConVarChange(g_hPauseEnable_Cvar, _P_PauseEnable_CvarChange);

	AddCommandListenerEx(_P_RotoblinForcePause_Command, PLUGIN_FORCEPAUSE_COMMAND);
	AddCommandListenerEx(_P_RotoblinForceUnPause_Command, PLUGIN_FORCEUNPAUSE_COMMAND);
	//AddCommandListener(_P_Say_Command, "say");
	//AddCommandListener(_P_SayTeam_Command, "say_team");
	
	RegConsoleCmd("sm_pause", Pause_Cmd, "Pauses the game");
	RegConsoleCmd("sm_unpause", Unpause_Cmd, "Marks your team as ready for an unpause");
	RegConsoleCmd("sm_r", Unpause_Cmd, "Marks your team as ready for an unpause");
	RegConsoleCmd("sm_ready", Unpause_Cmd, "Marks your team as ready for an unpause");
	
	RegConsoleCmd("sm_unready", Unready_Cmd, "Marks your team as not ready for an unpause");
	RegConsoleCmd("sm_nr", Unready_Cmd, "Marks your team as not ready for an unpause");
	
	RegConsoleCmd("sm_hide",			Hide_Cmd, "Hides the pause panel so other menus can be seen");
	RegConsoleCmd("sm_show",			Show_Cmd, "Shows a hidden pause panel");
	

	HookEvent("round_end", _PC_RoundEnd_Event, EventHookMode_PostNoCopy);
	HookEvent("round_start", _PC_RoundStart_Event, EventHookMode_PostNoCopy);

	HookPublicEvent(EVENT_ONCLIENTPUTINSERVER, _P_OnClientPutInServer);
}

/**
 * Plugin is now disabled.
 *
 * @noreturn
 */
public _P_OnPluginDisabled()
{
	RemoveCommandListenerEx(_P_RotoblinForcePause_Command, PLUGIN_FORCEPAUSE_COMMAND);
	RemoveCommandListenerEx(_P_RotoblinForceUnPause_Command, PLUGIN_FORCEUNPAUSE_COMMAND);
	//RemoveCommandListener(_P_Say_Command, "say");
	//RemoveCommandListener(_P_SayTeam_Command, "say_team");
	
	g_bIsPaused = false;
	g_bIsUnpausing = false;
	g_bWasForced = false;

	UnhookConVarChange(g_hPauseEnable_Cvar, _P_PauseEnable_CvarChange);

	UnhookPublicEvent(EVENT_ONMAPEND, _P_OnMapEnd);
	UnhookPublicEvent(EVENT_ONCLIENTDISCONNECT_POST, _P_OnClientDisconnect);
	
	UnhookEvent("round_end", _PC_RoundEnd_Event, EventHookMode_PostNoCopy);
	UnhookEvent("round_start", _PC_RoundStart_Event, EventHookMode_PostNoCopy);

	UnhookPublicEvent(EVENT_ONCLIENTPUTINSERVER, _P_OnClientPutInServer);
}

public void _P_OnClientPutInServer(int client)
{
	if (g_bIsPaused)
	{
		if (!IsFakeClient(client))
		{
			CPrintToChatAll("%t", "Pause_1", client);
			SetEntPropFloat(client, Prop_Data, "m_fLastPlayerTalkTime", 0.0);
		}
	}
}

public _P_OnClientDisconnect(client)
{
	hiddenPanel[client] = false;
}

void _PC_RoundStart_Event(Event event, const char[] name, bool dontBroadcast)
{
    RoundEnd = false;
    TimeCount = 0;
}

void _PC_RoundEnd_Event(Event event, const char[] name, bool dontBroadcast)
{
    delete deferredPauseTimer;
    RoundEnd = true;
    Unpause(false);
}

/**
 * On map end.
 *
 * @noreturn
 */
public _P_OnMapEnd()
{
	delete deferredPauseTimer;
	RoundEnd = true;
	Unpause(false);

	g_bIsPaused = false;
	g_bIsUnpausing = false;
	g_bWasForced = false;
}

/**
 * Pause enable cvar changed.
 *
 * @param convar		Handle to the convar that was changed.
 * @param oldValue		String containing the value of the convar before it was changed.
 * @param newValue		String containing the new value of the convar.
 * @noreturn
 */
public _P_PauseEnable_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	g_bIsPauseEnable = GetConVarBool(g_hPauseEnable_Cvar);
}


void Event_PlayerSay(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
    int iUserId = hEvent.GetInt("userid");
    RequestFrame(FrameDelay_PlayerSay, iUserId);
}

void FrameDelay_PlayerSay(int iUserId)
{
	int iClient = GetClientOfUserId(iUserId);
	if (iClient < 1 || !g_bIsPaused) {
		return;
	}

	// During a pause the time (gpGlobals->curtime) does not change.
	// Let's reset this property for the chat to work.
	SetEntPropFloat(iClient, Prop_Data, "m_fLastPlayerTalkTime", 0.0);
}

public Action:Pause_Cmd(client, args)
{
	if (client == SERVER_INDEX)
	{
		PrintToServer("[TS] Pause cannot be used by server.");
		return Plugin_Handled;
	}

	if (RoundEnd)
		return Plugin_Handled;

	if(!g_bIsPauseEnable)
	{
		CPrintToChat(client, "[{olive}TS{default}] %T","rotoblin1",client);
		return Plugin_Handled;
	}
	
	if(IsInReady())
	{
		CPrintToChat(client, "[{olive}TS{default}] %T","rotoblin2",client);
		return Plugin_Handled;
	}

	if(g_bIsUnpausing) 
	{
		CPrintToChat(client, "[{olive}TS{default}] %T","rotoblin3",client);
		return Plugin_Handled;
	}
	
	if (g_bWasForced) // An admin forced the game to pause so only an admin can unpause it
	{
		CPrintToChat(client, "[{olive}TS{default}] %T","rotoblin4",client);
		return Plugin_Handled;
	}
	
	if (g_bIsPaused) // Already paused, tell them how to unpause
	{
		CPrintToChat(client, "[{olive}TS{default}] %T","rotoblin4_2",client, PLUGIN_ready_COMMAND);
		return Plugin_Handled;
	}
	new teamIndex = GetClientTeam(client);
	if (teamIndex != TEAM_SURVIVOR && teamIndex != TEAM_INFECTED)
	{
		CPrintToChat(client, "[{olive}TS{default}] %T","rotoblin5",client);
		return Plugin_Handled;
	}

	pauseDelay = GetConVarInt(pauseDelayCvar);
	if (pauseDelay == 0)
		AttemptPause();
	else
		CreateTimer(1.0, PauseDelay_Timer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		
	decl String:clientName[128];
	GetClientName(client,clientName,128);

	if(teamIndex == 2)
		CPrintToChatAll("[{olive}TS{default}] {blue}%t","rotoblin6", clientName);
	else if(teamIndex == 3)
		CPrintToChatAll("[{olive}TS{default}] {red}%t","rotoblin6", clientName);
	
	return Plugin_Handled;
}

public Action:PauseDelay_Timer(Handle:timer)
{
	if (pauseDelay == 0)
	{
		AttemptPause();
		return Plugin_Stop;
	}
	else
	{
		PrintToChatAll("%t","rotoblin7", pauseDelay);
		pauseDelay--;
	}
	return Plugin_Continue;
}

/**
 * On client use rotoblins unpause command
 *
 * @param client		Client id that performed the command.
 * @param command		The command performed.
 * @param args			Number of arguments.
 * @return				Plugin_Handled to stop command from being performed, 
 *						Plugin_Continue to allow the command to pass.
 */
public Action:Unpause_Cmd(client, args)
{
	if (client == SERVER_INDEX)
	{
		return Plugin_Handled;
	}
	
	if(!g_bIsPaused)
	{
		return Plugin_Handled;
	}

	if(!g_bIsPauseEnable)
	{
		return Plugin_Handled;
	}
	
	if(g_bIsUnpausing) 
	{
		CPrintToChat(client, "[{olive}TS{default}] %T","rotoblin3",client);
		return Plugin_Handled;
	}

	if (g_bWasForced) // An admin forced the game to pause so only an admin can unpause it
	{
		CPrintToChat(client, "[{olive}TS{default}] %T","rotoblin4",client);
		return Plugin_Handled;
	}
		
	new teamIndex = GetClientTeam(client);

	if (teamIndex != TEAM_SURVIVOR && teamIndex != TEAM_INFECTED)
	{
		CPrintToChat(client, "[{olive}TS{default}] %T","rotoblin8",client);
		return Plugin_Handled;
	}

	decl String:teamName[16];
	GetTeamNameEx(teamIndex, true, teamName, sizeof(teamName));
	
	if (!teamReady[teamIndex])
	{
		if(teamIndex == 2)
			CPrintToChatAll("[{olive}TS{default}] {blue}%N {default}%t", client,"rotoblin9");
		else if(teamIndex == 3)
			CPrintToChatAll("[{olive}TS{default}] {red}%N {default}%t", client,"rotoblin10");
		UpdatePanel();
	}
	teamReady[teamIndex] = true;
	if(CheckFullReady())
	{
		g_bIsUnpausing = true;
		CreateTimer(1.0, _P_Unpause_Timer, client, TIMER_REPEAT); // Start unpause countdown
	}
	return Plugin_Handled;
}

public Action:Unready_Cmd(client, args)
{
	if(client == SERVER_INDEX) 
	{
		return Plugin_Handled;
	}

	if(g_bIsUnpausing) 
	{
		CPrintToChat(client, "[{olive}TS{default}] %T","rotoblin3",client);
		return Plugin_Handled;
	}
	
	if (g_bIsPaused && IsPlayer(client) && !g_bIsUnpausing)
	{
		new teamIndex = GetClientTeam(client);
		if (teamReady[teamIndex])
		{
			if(teamIndex == 2)
				CPrintToChatAll("[{olive}TS{default}] {blue}%N {default}%t", client,"rotoblin11");
			else if(teamIndex == 3)
				CPrintToChatAll("[{olive}TS{default}] {red}%N {default}%t", client,"rotoblin12");
			UpdatePanel();
		}
		teamReady[teamIndex] = false;
	}
	return Plugin_Handled;
}

Action Unpause_Callback(int client, char[] command, int argc)
{
	return (g_bIsPaused) ? Plugin_Handled : Plugin_Continue;
}

/**
 * On client use rotoblins forcepause command
 *
 * @param client		Client id that performed the command.
 * @param command		The command performed.
 * @param args			Number of arguments.
 * @return				Plugin_Handled to stop command from being performed, 
 *						Plugin_Continue to allow the command to pass.
 */
public Action:_P_RotoblinForcePause_Command(client, const String:command[], args)
{
	if (client == SERVER_INDEX || !g_bIsPauseEnable||IsInReady()||g_bIsUnpausing) return Plugin_Handled;

	new flags = GetUserFlagBits(client);
	if (!(flags & ADMFLAG_ROOT || flags & ADMFLAG_GENERIC))
	{
		CPrintToChat(client, "[{olive}TS{default}] %T","rotoblin13", client);
		return Plugin_Handled;
	}

	else if (!g_bIsPaused) // Is not paused
	{
		g_bWasForced = true; // Pause was forced so only allow admins to unpause
		GetClientName(client, g_sAdminName, 64);
		CPrintToChatAll("[{olive}TS{default}] %t","rotoblin14", g_sAdminName, "!forceunpause");
		Pause();
	}
	return Plugin_Handled;
}

public Action:_P_RotoblinForceUnPause_Command(client, const String:command[], args)
{
	if (client == SERVER_INDEX || !g_bIsPauseEnable) return Plugin_Handled;

	new flags = GetUserFlagBits(client);
	if (!(flags & ADMFLAG_ROOT || flags & ADMFLAG_GENERIC))
	{
		CPrintToChat(client, "[{olive}TS{default}] %T","rotoblin15",client);
		return Plugin_Handled;
	}
	
	if (g_bIsPaused && !g_bIsUnpausing) // Is paused and not currently unpausing
	{
		GetClientName(client, g_sAdminName, 64);
		CPrintToChatAll("[{olive}TS{default}] %t", "rotoblin16", g_sAdminName);
		g_bIsUnpausing = true; // Set unpausing state
		CreateTimer(1.0, _P_Unpause_Timer, client, TIMER_REPEAT); // Start unpause countdown
	}
	UpdatePanel();
	return Plugin_Handled;
}

/**
 * Called when the timer interval has elapsed.
 * 
 * @param timer			Handle to the timer object.
 * @return				Plugin_Stop to stop repeating, any other value for
 *						default behavior.
 */
public Action:_P_Unpause_Timer(Handle:timer, any:client)
{
	if (!g_bIsUnpausing||!g_bIsPaused) return Plugin_Stop; // Server was repaused/unpaused before the countdown finished

	
	static iCountdown = 3;

	if (iCountdown == 3)
	{
		PrintToChatAll("%t","rotoblin17", iCountdown);
		iCountdown--;
		return Plugin_Continue;
	}
	else if (iCountdown == 0)
	{
		PrintToChatAll("-----%t-----","rotoblin18");
		Unpause();
		iCountdown = 3;
		return Plugin_Stop;
	}

	PrintToChatAll("%d...", iCountdown);
	iCountdown--;
	return Plugin_Continue;
}

// **********************************************
//                 Private API
// **********************************************

static void Pause()
{
	g_bIsPaused = true;
	g_bIsUnpausing = false;
	
	for (new team = 2; team <= 3; team++)
	{
		teamReady[team] = false;
	}
	
	ToggleCommandListeners(true);

	CreateTimer(1.0, MenuRefresh_Timer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);

	bool pauseProcessed = false;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client) || IsFakeClient(client)) continue;

		hiddenPanel[client] = false;

		int team = GetClientTeam(client);
		
		if (team == L4D1Team_Infected && IsPlayerGhost(client))
		{
			SetEntProp(client, Prop_Send, "m_hasVisibleThreats", 1);
			int buttons = GetClientButtons(client);
			if (buttons & IN_ATTACK)
			{
				buttons &= ~IN_ATTACK;
				SetClientButtons(client, buttons);
				CPrintToChat(client, "%T", "PausePreventSpawn", client);
			}
		}

		SetEntPropFloat(client, Prop_Data, "m_fLastPlayerTalkTime", 0.0);

		if (!pauseProcessed)
		{
			sv_pausable.BoolValue = true;
			FakeClientCommand(client, "pause");
			sv_pausable.BoolValue = false;
			pauseProcessed = true;
		}

		if (team == L4D1Team_Spectator)
		{
			sv_noclipduringpause.ReplicateToClient(client, "1");
		}
		
		//Freeze player who is pulled by smoker when game pauses. (Fixed player teleport when game unpauses)
		if(GetClientTeam(client) == L4D1Team_Survivor && IsPlayerAlive(client) && !IsplayerHangingFromLedge(client) && IsPlayerAttackedBySmoker(client))
		{
			ToggleFreezePlayer(client, true);
		}
	}
}

static Action MenuRefresh_Timer(Handle timer)
{
	if (g_bIsPaused)
	{
		TimeCount++;
		UpdatePanel();
		return Plugin_Continue;
	}
	TimeCount = 0;
	return Plugin_Stop;
}

static void Unpause(bool real = true)
{
	g_bIsPaused = false;
	g_bIsUnpausing = false;
	g_bWasForced = false;

	ToggleCommandListeners(false);

	if (real)
	{
		bool unpauseProcessed = false;
		for (int client = 1; client <= MaxClients; client++)
		{
			if (!IsClientInGame(client) || IsFakeClient(client)) continue;
		
			SetEntPropFloat(client, Prop_Data, "m_fLastPlayerTalkTime", 0.0);

			if(!unpauseProcessed)
			{
				sv_pausable.BoolValue = true;
				FakeClientCommand(client, "unpause");
				sv_pausable.BoolValue = false;
				unpauseProcessed = true;
			}
			
			int team = GetClientTeam(client);
			if (team == L4D1Team_Spectator)
			{
				sv_noclipduringpause.ReplicateToClient(client, "0");
			}

			if (team == L4D1Team_Survivor && IsPlayerAlive(client)
				&& GetEntityMoveType(client) == MOVETYPE_NONE )
			{
				ToggleFreezePlayer(client, false);
			}
		}
	}
}

static void UpdatePanel()
{
	if (menuPanel != INVALID_HANDLE)
	{
		CloseHandle(menuPanel);
		menuPanel = INVALID_HANDLE;
	}

	menuPanel = CreatePanel();

	if(g_bWasForced)
	{	
		new String:Info[35];
		if(g_bIsUnpausing)
			Format(Info, 35, "->1. ★Admin: !%s", PLUGIN_FORCEUNPAUSE_COMMAND);
		else
			Format(Info, 35, "->1. ☆Admin: !%s", PLUGIN_FORCEUNPAUSE_COMMAND);
		
		decl String:Notice[64];
		FormatEx(Notice, 64, "Paused by admin: %s", g_sAdminName);
		DrawPanelText(menuPanel, Notice);	
		
		Format(Notice, 64, "%s%d:%s%d", (TimeCount/60 < 10) ? "0" : "",TimeCount/60, (TimeCount%60 < 10) ? "0" : "", TimeCount%60);
		DrawPanelText(menuPanel, Notice);
		
		DrawPanelText(menuPanel, Info);
	}
	else
	{
		DrawPanelText(menuPanel, "Team Pause Status");
		
		decl String:Notice[64];
		Format(Notice, 64, "%s%d:%s%d", (TimeCount/60 < 10) ? "0" : "",TimeCount/60, (TimeCount%60 < 10) ? "0" : "", TimeCount%60);
		DrawPanelText(menuPanel, Notice);
		
		DrawPanelText(menuPanel, GetTeamHumanCount(L4D1Team_Survivor) ? 
		(teamReady[L4D1Team_Survivor] ? 
		"->1. ★Survivors" : "->1. ☆Survivors") 
		: "->1. Survivors [No One]");
		
		DrawPanelText(menuPanel, GetTeamHumanCount(L4D1Team_Infected) ? 
		(teamReady[L4D1Team_Infected] ? 
		"->2. ★Infected" : "->2. ☆Infected") : 
		"->2. Infected [No One]");
	}
	for (new client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && !IsFakeClient(client))
		{
			if(hiddenPanel[client]) continue;

			switch (GetClientMenu(client))
			{
				case MenuSource_External, MenuSource_Normal:
				{ 
					continue;
				}
			}

			SendPanelToClient(menuPanel, client, DummyHandler, 1);
		}
	}
}

public DummyHandler(Handle:menu, MenuAction:action, param1, param2) { }

bool:CheckFullReady()//雙方隊伍都ready 或是 發生有一邊隊伍根本沒人的情況下 
{
	return (teamReady[L4D1Team_Survivor] || GetTeamHumanCount(L4D1Team_Survivor) == 0)
		&& (teamReady[L4D1Team_Infected] || GetTeamHumanCount(L4D1Team_Infected) == 0);
}

static int GetTeamHumanCount(int team)
{
    int humans = 0;
	
    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == team)
        {
            humans++;
        }
    }
	
    return humans;
}

static IsPlayer(client)
{
	new team = GetClientTeam(client);
	return (client && (team == 2 || team == 3));
}

public Native_IsPauseing(Handle:plugin, numParams)
{
	return (g_bWasForced||g_bIsPaused||g_bIsUnpausing);
}

static void AttemptPause()
{
	if (deferredPauseTimer == null)
	{
		if (IsSurvivorReviving() == false)
		{
			Pause();
		}
		else
		{
			CPrintToChatAll("[{olive}TS{default}] %t","rotoblin19");
			deferredPauseTimer = CreateTimer(0.1, DeferredPause_Timer, _, TIMER_REPEAT);
		}
	}
}

public Action:DeferredPause_Timer(Handle:timer)
{
	if (IsSurvivorReviving() == false)
	{
		deferredPauseTimer = null;
		PrintToChatAll("%t","Paused!");
		Pause();
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

static bool IsSurvivorReviving()
{
    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsClientInGame(client) && GetClientTeam(client) == L4D1Team_Survivor && IsPlayerAlive(client))
        {
            if (GetEntProp(client, Prop_Send, "m_reviveTarget") > 0)
            {
                return true;
            }
        }
    }
    return false;
}

static bool IsplayerHangingFromLedge(int client)
{
	if(GetEntProp(client, Prop_Send, "m_isHangingFromLedge"))
		return true;

	return false;
}

static bool IsPlayerAttackedBySmoker(int client)
{
	int attacker = GetEntPropEnt(client, Prop_Send, "m_tongueOwner");
	if (attacker > 0)
	{
		return true;
	}

	return false;
}

ToggleFreezePlayer(client, freeze)
{
	SetEntityMoveType(client, freeze ? MOVETYPE_NONE : MOVETYPE_WALK);
}

public Action Hide_Cmd(int client, int args)
{
	if(client == SERVER_INDEX) 
	{
		return Plugin_Handled;
	}

	if (g_bIsPaused)
	{
		hiddenPanel[client] = true;
		CPrintToChat(client, "%T", "PausePanelHide", client);
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public Action Show_Cmd(int client, int args)
{
	if(client == SERVER_INDEX) 
	{
		return Plugin_Handled;
	}

	if (g_bIsPaused)
	{
		hiddenPanel[client] = false;
		CPrintToChat(client, "%T", "PausePanelShow", client);
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

static void ToggleCommandListeners(bool enable)
{
    if (enable && !listened)
    {
        AddCommandListener(Unpause_Callback, "unpause");

        HookEvent("player_say", Event_PlayerSay, EventHookMode_Post);

        listened = true;
    }
    else if (!enable && listened)
    {
        RemoveCommandListener(Unpause_Callback, "unpause");

        UnhookEvent("player_say", Event_PlayerSay, EventHookMode_Post);

        listened = false;
    }
}

static void SetClientButtons(int client, int buttons)
{
    if (IsClientInGame(client))
    {
        SetEntProp(client, Prop_Data, "m_nButtons", buttons);
    }
}