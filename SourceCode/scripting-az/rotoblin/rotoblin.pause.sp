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
 *  Copyright (C) 2017-2024  Harry <fbef0102@gmail.com>
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

static	const	String:	PAUSABLE_CVAR[]				= "sv_pausable";

//static	const	String:	PLUGIN_PAUSE_COMMAND[]		= "fpause";
//static	const	String:	PLUGIN_UNPAUSE_COMMAND[]= "funpause";
static	const	String:	PLUGIN_FORCEPAUSE_COMMAND[]	= "forcepause";
static	const	String:	PLUGIN_FORCEUNPAUSE_COMMAND[]	= "forceunpause";
static	const	String:	PLUGIN_ready_COMMAND[]		= "!ready";
static	const	String:	PAUSE_COMMAND[]				= "!pause";
static	const	String:	SETPAUSE_COMMAND[]			= "setpause";
static	const	String:	UNPAUSE_COMMAND[]			= "unpause";

//static	const	Float:	RESET_PAUSE_REQUESTS_TIME	= 30.0;

static			Handle:	g_hPauseEnable_Cvar			= INVALID_HANDLE;
static			bool:	g_bIsPauseEnable			= true;

static			Handle: g_hPausable					= INVALID_HANDLE;
static			bool:	g_bIsPaused					= false;
static			bool:	g_bIsUnpausing				= false;
static			bool:	g_bWasForced				= false;
static			bool:	g_bIsPausable				= false;
static			bool:	g_bIsUnpausable				= false;
new Handle:pauseDelayCvar;
new pauseDelay;
new Handle:deferredPauseTimer;
bool hiddenPanel[MAXPLAYERS+1];
char g_sAdminName[64];

enum L4D2Team
{
	L4D2Team_None = 0,
	L4D2Team_Spectator,
	L4D2Team_Survivor,
	L4D2Team_Infected
}

new Handle:menuPanel;
new bool:teamReady[4];

native IsInReady();
native bool:IsClientVoteMenu(client);//From Votes3
native bool:IsClientInfoMenu(client);//From l4d_Harry_Roto2-AZ_mod_info
new TimeCount;

// **********************************************
//                   Forwards
// **********************************************

/**
 * Plugin is loading.
 *
 * @noreturn
 */
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

	g_hPausable = FindConVar(PAUSABLE_CVAR);
	
	g_bIsUnpausable = false;
	g_bIsPausable = false;
	g_bIsPaused = false;
	g_bIsUnpausing = false;
	g_bWasForced = false;

	SetConVarBool(g_hPausable, false); // Disable pausing

	g_bIsPauseEnable = GetConVarBool(g_hPauseEnable_Cvar);
	HookConVarChange(g_hPauseEnable_Cvar, _P_PauseEnable_CvarChange);

	AddCommandListenerEx(_P_RotoblinForcePause_Command, PLUGIN_FORCEPAUSE_COMMAND);
	AddCommandListenerEx(_P_RotoblinForceUnPause_Command, PLUGIN_FORCEUNPAUSE_COMMAND);
	AddCommandListener(_P_RotoblinPause_Command, PAUSE_COMMAND);
	AddCommandListener(_P_Setpause_Command, SETPAUSE_COMMAND);
	AddCommandListener(_P_RotoblinUnpause_Command, UNPAUSE_COMMAND);
	AddCommandListener(_P_Say_Command, "say");
	AddCommandListener(_P_SayTeam_Command, "say_team");
	
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
	RemoveCommandListener(_P_RotoblinPause_Command, PAUSE_COMMAND);
	RemoveCommandListener(_P_Setpause_Command, SETPAUSE_COMMAND);
	RemoveCommandListener(_P_RotoblinUnpause_Command, UNPAUSE_COMMAND);
	RemoveCommandListener(_P_Say_Command, "say");
	RemoveCommandListener(_P_SayTeam_Command, "say_team");

	g_bIsPaused = false;
	g_bIsUnpausing = false;
	g_bWasForced = false;
	g_bIsPausable = false;
	g_bIsUnpausable = false;

	g_hPausable = INVALID_HANDLE;

	UnhookConVarChange(g_hPauseEnable_Cvar, _P_PauseEnable_CvarChange);

	UnhookPublicEvent(EVENT_ONMAPEND, _P_OnMapEnd);
	UnhookPublicEvent(EVENT_ONCLIENTDISCONNECT_POST, _P_OnClientDisconnect);
	
	UnhookEvent("round_end", _PC_RoundEnd_Event, EventHookMode_PostNoCopy);
	UnhookEvent("round_start", _PC_RoundStart_Event, EventHookMode_PostNoCopy);
}

public _P_OnClientDisconnect(client)
{
	hiddenPanel[client] = false;
}

public _PC_RoundStart_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	TimeCount = 0;
}

public _PC_RoundEnd_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (deferredPauseTimer != INVALID_HANDLE)
	{
		CloseHandle(deferredPauseTimer);
		deferredPauseTimer = INVALID_HANDLE;
	}
}

/**
 * On map end.
 *
 * @noreturn
 */
public _P_OnMapEnd()
{
	g_bIsPaused = false;
	g_bIsUnpausing = false;
	g_bWasForced = false;
	g_bIsPausable = false;
	g_bIsUnpausable = false;
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

/**
 * On client use say command.
 *
 * @param client		Client id that performed the command.
 * @param command		The command performed.
 * @param args			Number of arguments.
 * @return				Plugin_Handled to stop command from being performed, 
 *						Plugin_Continue to allow the command to pass.
 */
public Action:_P_Say_Command(client, const String:command[], args)
{
	if(client == SERVER_INDEX) 
	{
		return Plugin_Handled;
	}

	if (!g_bIsPaused) return Plugin_Continue;

	decl String:buffer[128];
	GetCmdArg(1, buffer, sizeof(buffer));
	if (IsSayCommandPrivate(buffer)) return Plugin_Continue; // If its a private chat trigger, return continue

	decl String:sayWord[MAX_NAME_LENGTH];
	GetCmdArg(1, sayWord, sizeof(sayWord));
	
	if(StrEqual(sayWord, "!R", true))
	{
		FakeClientCommand(client, "say /r");
		return Plugin_Handled;
	}
	else if(StrEqual(sayWord, "/R", true))
	{
		FakeClientCommand(client, "say /ready");
		return Plugin_Handled;
	}
	else if(StrEqual(sayWord, "!Ready", true))
	{
		FakeClientCommand(client, "say /ready");
		return Plugin_Handled;
	}
	else if(StrEqual(sayWord, "/Ready", true))
	{
		FakeClientCommand(client, "say /ready");
		return Plugin_Handled;
	}
	else if(StrEqual(sayWord, "!NR", true))
	{
		FakeClientCommand(client, "say /unready");
		return Plugin_Handled;
	}
	else if(StrEqual(sayWord, "/NR", true))
	{
		FakeClientCommand(client, "say /unready");
		return Plugin_Handled;
	}

	if(BaseComm_IsClientGagged(client)) return Plugin_Continue;
	
	new team = GetClientTeam(client);
	if(team == 1)
		CPrintToChatAll("(Spec) {lightgreen}%N{default} : %s", client, buffer);
	else if(team == 2)
		CPrintToChatAll("(Sur) {lightgreen}%N{default} : %s", client, buffer);
	else if(team == 3)
		CPrintToChatAll("(Inf) {lightgreen}%N{default} : %s", client, buffer);
		
	return Plugin_Handled;
}

/**
 * On client use say team command
 *
 * @param client		Client id that performed the command.
 * @param command		The command performed.
 * @param args			Number of arguments.
 * @return				Plugin_Handled to stop command from being performed, 
 *						Plugin_Continue to allow the command to pass.
 */
public Action:_P_SayTeam_Command(client, const String:command[], args)
{
	if(client == SERVER_INDEX) 
	{
		return Plugin_Handled;
	}

	if (!g_bIsPaused) return Plugin_Continue;

	decl String:buffer[128];
	GetCmdArg(1, buffer, sizeof(buffer));
	if (IsSayCommandPrivate(buffer)) return Plugin_Continue; // If its a private chat trigger, return continue


	new teamIndex = GetClientTeam(client);
	decl String:teamName[16];
	GetTeamNameEx(teamIndex, false, teamName, sizeof(teamName));

	
	decl String:sayWord[MAX_NAME_LENGTH];
	GetCmdArg(1, sayWord, sizeof(sayWord));
	
	if(StrEqual(sayWord, "!R", true))
	{
		FakeClientCommand(client, "say /r");
		return Plugin_Handled;
	}
	else if(StrEqual(sayWord, "/R", true))
	{
		FakeClientCommand(client, "say /ready");
		return Plugin_Handled;
	}
	else if(StrEqual(sayWord, "!Ready", true))
	{
		FakeClientCommand(client, "say /ready");
		return Plugin_Handled;
	}
	else if(StrEqual(sayWord, "/Ready", true))
	{
		FakeClientCommand(client, "say /ready");
		return Plugin_Handled;
	}
	else if(StrEqual(sayWord, "!NR", true))
	{
		FakeClientCommand(client, "say /unready");
		return Plugin_Handled;
	}
	else if(StrEqual(sayWord, "/NR", true))
	{
		FakeClientCommand(client, "say /unready");
		return Plugin_Handled;
	}
	
	if(BaseComm_IsClientGagged(client)) return Plugin_Continue;

	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || GetClientTeam(i) != teamIndex) continue;
		if(teamIndex == 1)
			CPrintToChat(i, "{default}(%s) {default}%N{default} : %s", teamName, client, buffer);
		else if(teamIndex == 2)
			CPrintToChat(i, "{default}(%s) {blue}%N{default} : %s", teamName, client, buffer);
		else if(teamIndex == 3)
			CPrintToChat(i, "{default}(%s) {red}%N{default} : %s", teamName, client, buffer);
	}
		
	return Plugin_Handled;

}

public Action:Pause_Cmd(client, args)
{
	if (client == SERVER_INDEX)
	{
		PrintToServer("[TS] Pause cannot be used by server.");
		return Plugin_Handled;
	}

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

public Action:_P_RotoblinPause_Command(client, const String:command[], args)
{
	return Plugin_Handled;
}

public Action:_P_Setpause_Command(client, const String:command[], args)
{
	if (!g_bIsPausable) return Plugin_Handled;

	g_bIsPausable = false;
	return Plugin_Continue;
}

public Action:_P_RotoblinUnpause_Command(client, const String:command[], args)
{
	if (!g_bIsUnpausable) return Plugin_Handled;
	
	g_bIsUnpausable = false;
	
	return Plugin_Continue;
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

/**
 * Pauses the game.
 *
 * @param client		Client that will be selected to pause the game, if not provided
 *							a random client will be used.
 * @noreturn
 */
static Pause()
{
	g_bIsPaused = true;
	g_bIsUnpausing = false;
	
	for (new team = 2; team <= 3; team++)
	{
		teamReady[team] = false;
	}
	
	g_bIsPausable = true; // Allow the next setpause command to go through
	
	for (new client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			SetConVarBool(g_hPausable, true);
			FakeClientCommand(client, SETPAUSE_COMMAND);
			SetConVarBool(g_hPausable, false);
			break;
		}
	}

	//Freeze player who is pulled by smoker when game pauses. (Fixed player teleport when game unpauses)
	for (new client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client)) continue;

		hiddenPanel[client] = false;
		
		if(GetClientTeam(client) == TEAM_SURVIVOR && IsPlayerAlive(client) && !IsplayerHangingFromLedge(client) && IsPlayerAttackedBySmoker(client))
		{
			ToggleFreezePlayer(client, true);
		}
	}
	
	CreateTimer(1.0, MenuRefresh_Timer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action:MenuRefresh_Timer(Handle:timer)
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

/**
 * Unpauses the game.
 *
 * @param client		Client that will be selected to unpause the game, if not provided
 *							a random client will be used.
 * @noreturn
 */
static Unpause()
{
	g_bIsUnpausable = true; // Allow the next unpause command to go through
	for (new client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			SetConVarBool(g_hPausable, true);
			FakeClientCommand(client, "unpause");
			SetConVarBool(g_hPausable, false);
			break;
		}
	}

	for (new client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVOR && IsPlayerAlive(client))
		{
			ToggleFreezePlayer(client, false);
		}
	}
	
	g_bIsUnpausing = false;
	g_bIsPaused = false;
	g_bWasForced = false;
}

UpdatePanel()
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
		FormatEx(Notice, 64, "Pause by Admin: %s", g_sAdminName);
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
		
		DrawPanelText(menuPanel, GetTeamHumanCount(L4D2Team_Survivor) ? 
		(teamReady[L4D2Team_Survivor] ? 
		"->1. ★Survivors" : "->1. ☆Survivors") 
		: "->1. Survivors [No One]");
		
		DrawPanelText(menuPanel, GetTeamHumanCount(L4D2Team_Infected) ? 
		(teamReady[L4D2Team_Infected] ? 
		"->2. ★Infected" : "->2. ☆Infected") : 
		"->2. Infected [No One]");
	}
	for (new client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && !IsFakeClient(client) && !IsClientVoteMenu(client) && !IsClientInfoMenu(client))
		{
			if(!hiddenPanel[client])
				SendPanelToClient(menuPanel, client, DummyHandler, 1);
		}
	}
}

public DummyHandler(Handle:menu, MenuAction:action, param1, param2) { }

bool:CheckFullReady()//雙方隊伍都ready 或是 發生有一邊隊伍根本沒人的情況下 
{
	return (teamReady[L4D2Team_Survivor] || GetTeamHumanCount(L4D2Team_Survivor) == 0)
		&& (teamReady[L4D2Team_Infected] || GetTeamHumanCount(L4D2Team_Infected) == 0);
}

stock GetTeamHumanCount(L4D2Team:team)
{
	new humans = 0;
	
	for (new client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && !IsFakeClient(client) && L4D2Team:GetClientTeam(client) == team)
		{
			humans++;
		}
	}
	
	return humans;
}

stock IsPlayer(client)
{
	new team = GetClientTeam(client);
	return (client && (team == 2 || team == 3));
}

public Native_IsPauseing(Handle:plugin, numParams)
{
	return (g_bWasForced||g_bIsPaused||g_bIsUnpausing);
}

public Native_IsPauseEnable(Handle:plugin, numParams)
{
	return g_bIsPausable;
}

AttemptPause()
{
	if (deferredPauseTimer == INVALID_HANDLE)
	{
		if (CanPause())
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
	if (CanPause())
	{
		deferredPauseTimer = INVALID_HANDLE;
		PrintToChatAll("%t","Paused!");
		Pause();
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

bool IsPlayerIncap(client)
{
	return view_as<bool>(GetEntProp(client, Prop_Send, "m_isIncapacitated"));
}

bool:CanPause()
{
	for (new client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == 2)
		{
			if (IsPlayerIncap(client))
			{
				if (GetEntProp(client, Prop_Send, "m_reviveOwner") > 0)
				{
					return false;
				}
			}
			else
			{
				if (GetEntProp(client, Prop_Send, "m_reviveTarget") > 0)
				{
					return false;
				}
			}
		}
	}
	return true;
}

bool IsplayerHangingFromLedge(int client)
{
	if(GetEntProp(client, Prop_Send, "m_isHangingFromLedge"))
		return true;

	return false;
}

bool IsPlayerAttackedBySmoker(int client)
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