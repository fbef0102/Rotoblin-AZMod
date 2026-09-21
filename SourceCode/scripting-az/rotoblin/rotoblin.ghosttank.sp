/*
 * ============================================================================
 *
 *  Rotoblin
 *
 *  File:			rotoblin.ghosttank.sp
 *  Type:			Module
 *  Description:	Handles the tank. Prevents prelights with more.
 *	Credits:		DrThunder on AlliedModders.com, for punch fix
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

static 	const	String:	SELECTION_TIME_CVAR[]				= "director_tank_lottery_selection_time";

static	const	Float:	FIRE_IMMUNITY_TIME					= 5.0;			// How long the tank is fire immune after a player gains control.
static			Handle:	g_hSelectionTimeCvar				= INVALID_HANDLE;

bool g_bBlockGhostTank_Attack[MAXPLAYERS+1]	= {false, ...};			// block rock throws and attack during ghost ai tank

float g_fTankFireImmuneEngineTime[MAXPLAYERS+1]		= {0.0, ...};			// tank fire immunity

static					g_iDebugChannel							= 0;
static	const	String:	DEBUG_CHANNEL_NAME[]					= "GhostTank";

// **********************************************
//                   Forwards
// **********************************************

/**
 * Plugin is starting.
 *
 * @noreturn
 */
public _GhostTank_OnPluginStart()
{
	HookPublicEvent(EVENT_ONPLUGINENABLE, _GT_OnPluginEnable);
	HookPublicEvent(EVENT_ONPLUGINDISABLE, _GT_OnPluginDisable);

	g_iDebugChannel = DebugAddChannel(DEBUG_CHANNEL_NAME);
	DebugPrintToAllEx("Module is now setup");
}

/**
 * Plugin is now enabled.
 *
 * @noreturn
 */
public _GT_OnPluginEnable()
{
	g_hSelectionTimeCvar	= FindConVar(SELECTION_TIME_CVAR);

	HookEvent("round_start"			, _GT_RoundStart_Event, EventHookMode_PostNoCopy);
	HookEvent("player_hurt"			, _GT_PlayerHurt_Event);
	HookEvent("bot_player_replace", _GT_PlayerReplaceBot);
	HookEvent("player_bot_replace", _GT_BotReplacePlayer);
	HookTankEvent(TANK_SPAWNED	, _GT_TankSpawn_Event);
	HookTankEvent(TANK_KILLED	, _GT_TankKilled_Event);
	HookPublicEvent(EVENT_ONPLAYERRUNCMD, _GT_OnPlayerRunCmd);

	DebugPrintToAllEx("Module is now loaded");
}

/**
 * Plugin is now disabled.
 *
 * @noreturn
 */
public _GT_OnPluginDisable()
{
	g_hSelectionTimeCvar	= INVALID_HANDLE;

	UnhookEvent("round_start",			_GT_RoundStart_Event, EventHookMode_PostNoCopy);
	UnhookEvent("player_hurt",			_GT_PlayerHurt_Event);
	UnhookEvent("bot_player_replace", _GT_PlayerReplaceBot);
	UnhookEvent("player_bot_replace",  _GT_BotReplacePlayer);
	UnhookPublicEvent(EVENT_ONPLAYERRUNCMD, _GT_OnPlayerRunCmd);

	DebugPrintToAllEx("Module is now unloaded");
}

/**
 * Called when round start event is fired.
 */
void _GT_RoundStart_Event(Event event, const char[] name, bool dontBroadcast)
{
	DebugPrintToAllEx("Round start");

	for(int i = 1; i <= MaxClients; i++)
	{
		g_bBlockGhostTank_Attack[i] = false;
		g_fTankFireImmuneEngineTime[i] = 0.0;
	}
}

/**
 * Called when tank is spawned if no tank in play
 */
public void _GT_TankSpawn_Event(int client)
{
	if (!IsFakeClient(client)) return;

	new Float:fSelectionTime = GetConVarFloat(g_hSelectionTimeCvar); // Get selection time

	g_bBlockGhostTank_Attack[client] = true;
	CreateTimer(fSelectionTime, _GT_ResumeThrow_Timer, client);	// Create timer for restoring ai tank

	SetEntityMoveType(client, MOVETYPE_NONE);			// Freeze ai tank
	SetPlayerGhostState(client, true);					// Ghost ai tank
	CreateTimer(fSelectionTime, _GT_ResumeTank_Timer, GetClientUserId(client));	// Create timer for restoring ai tank
	float fFireImmunityTime = fSelectionTime + FIRE_IMMUNITY_TIME;				// Add some more time to fire immunity

	g_fTankFireImmuneEngineTime[client] = GetEngineTime() + fFireImmunityTime;
	//PrintToChatAll("Tank spawned, created fire immunity timer. Immunity time %.2f", fFireImmunityTime);
}

void _GT_PlayerReplaceBot(Event event, const char[] name, bool dontBroadcast)
{
	int bot = GetClientOfUserId(GetEventInt(event, "bot"));
	int player = GetClientOfUserId(GetEventInt(event, "player"));
	if(bot > 0 && IsClientInGame(bot) && player > 0 && IsClientInGame(player))
	{
		g_fTankFireImmuneEngineTime[player] = g_fTankFireImmuneEngineTime[bot];
		g_fTankFireImmuneEngineTime[bot] = 0.0;
	}
}

void _GT_BotReplacePlayer(Event event, const char[] name, bool dontBroadcast)
{
	int bot = GetClientOfUserId(GetEventInt(event, "bot"));
	int player = GetClientOfUserId(GetEventInt(event, "player"));
	if(bot > 0 && IsClientInGame(bot) && player > 0 && IsClientInGame(player))
	{
		g_fTankFireImmuneEngineTime[bot] = g_fTankFireImmuneEngineTime[player];
		g_fTankFireImmuneEngineTime[player] = 0.0;
	}
}

/**
 * Called when tank was killed and is no longer in play
 *
 * @noreturn
 */
public void _GT_TankKilled_Event(int client)
{
	g_fTankFireImmuneEngineTime[client] = 0.0;
}

/**
 * Called when a player is hurt.
 *
 * @param event			Handle to event.
 * @param name			String containing the name of the event.
 * @param dontBroadcast	True if event was not broadcast to clients, false otherwise.
 * @noreturn
 */
void _GT_PlayerHurt_Event(Event event, const char[] name, bool dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!client || !IsClientInGame(client)) return;

	int dmgtype = GetEventInt(event, "type");
	if ( (dmgtype | DMG_BURN) == 0 ) return; // If it wasn't fire that hurt the tank, return

	if (g_fTankFireImmuneEngineTime[client] > GetEngineTime() && GetClientTeam(client) == TEAM_INFECTED && IsPlayerAlive(client) && GetEntProp(client,Prop_Send,"m_zombieClass") == ZOMBIECLASS_TANK)
	{
		if(GetEntityFlags(client) & FL_ONFIRE) ExtinguishEntity(client);
		new CurHealth = GetClientHealth(client);
		new DmgDone = GetEventInt(event, "dmg_health");
		SetEntityHealth(client, (CurHealth + DmgDone));
		DebugPrintToAllEx("Tank was burned while being fire immune, health restored and fire put out");
	}
}

public _GT_OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if (g_bBlockGhostTank_Attack[client])
	{
		if(buttons & IN_ATTACK2)
			buttons ^= IN_ATTACK2; // remove attack 2 from pressed buttons
		if(buttons & IN_ATTACK)
			buttons ^= IN_ATTACK; // remove attack 2 from pressed buttons
		DebugPrintToAllEx("Tank AI tried to throw rock while being prohibit");
	}
}

Action _GT_ResumeThrow_Timer(Handle timer, int client)
{
	g_bBlockGhostTank_Attack[client] = false; // Reset throw block

	return Plugin_Continue;
}

Action _GT_ResumeTank_Timer(Handle timer, int client)
{
	client = GetClientOfUserId(client);
	if(!client || !IsClientInGame(client) || !IsFakeClient(client) || GetClientTeam(client) !=3 || GetEntProp(client, Prop_Send, "m_zombieClass") != 5) 
		return Plugin_Continue;

	SetEntityMoveType(client, MOVETYPE_CUSTOM);			// Reset movetype
	SetPlayerGhostState(client, false);					// And unghost
	DebugPrintToAllEx("Restored AI Tank");

	return Plugin_Continue;
}

// **********************************************
//                 Private API
// **********************************************

/**
 * Wrapper for printing a debug message without having to define channel index
 * everytime.
 *
 * @param format		Formatting rules.
 * @param ...			Variable number of format parameters.
 * @noreturn
 */
static DebugPrintToAllEx(const String:format[], any:...)
{
	decl String:buffer[DEBUG_MESSAGE_LENGTH];
	VFormat(buffer, sizeof(buffer), format, 2);
	DebugPrintToAll(g_iDebugChannel, buffer);
}