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
 *  Copyright (C) 2017-2021  Harry <fbef0102@gmail.com>
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
static	const			FIRE_DAMAGE_TYPE					= 8;			/* "Pre" fire damage type. This damage type is applied to the tank before he gets lit
																			 * on fire. By detecting this damage type instead of using GetEntityFlags on tank, we
																			 * can prevent the rage meter from disappear from the tank. */
static	const			INCAP_HEALTH						= 300;			// Punch fix, incap health
static	const	Float:	INCAP_DELAY							= 0.4;			// Punch fix, how long before incaping the survivor again
static	const	String:	INCAP_WEAPON[]						= "tank_claw";	// Punch fix, which weapon used to incap the survivor before applying punch fix

static			Handle:	g_hSelectionTimeCvar				= INVALID_HANDLE;

static	const	String:	WEAPON_TANK_ROCK[]					= "tank_rock";	// Tank rock weapon name
static	const	Float:	BLOCK_USE_TIME						= 1.5;			// After a survivor have been "rock'd", how long is use blocked
static			bool:	g_bBlockUse[MAXPLAYERS +1]			= {false};
static			Handle:	g_hBlockUse_Timer[MAXPLAYERS +1]	= {INVALID_HANDLE};

static					g_iBlockClientThrow					= 0;			// Client index to block rock throws from

static			bool:	g_bIsTankFireImmune					= true;			// Boolean for fire immunity

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
	HookEvent("player_incapacitated", _GT_PlayerIncap_Event);
	HookTankEvent(TANK_SPAWNED	, _GT_TankSpawn_Event);
	HookTankEvent(TANK_KILLED	, _GT_TankKilled_Event);
	HookTankEvent(TANK_PASSED	, _GT_TankPassed_Event);
	HookPublicEvent(EVENT_ONPLAYERRUNCMD, _GT_OnPlayerRunCmd);
	
	g_bIsTankFireImmune = true;

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
	UnhookEvent("player_incapacitated", _GT_PlayerIncap_Event);
	UnhookPublicEvent(EVENT_ONPLAYERRUNCMD, _GT_OnPlayerRunCmd);

	DebugPrintToAllEx("Module is now unloaded");
}

/**
 * Called when round start event is fired.
 *
 * @param event			INVALID_HANDLE, post no copy data.
 * @param name			String containing the name of the event.
 * @param dontBroadcast	True if event was not broadcast to clients, false otherwise.
 * @noreturn
 */
public _GT_RoundStart_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	DebugPrintToAllEx("Round start");
	g_bIsTankFireImmune = true;
}

/**
 * Called when tank is spawned.
 *
 * @noreturn
 */
public _GT_TankSpawn_Event()
{
	new client = GetTankClient(); // Get current tank client
	new Float:fFireImmunityTime = FIRE_IMMUNITY_TIME;

	if (IsFakeClient(client)) // if AI tank
	{
		new Float:fSelectionTime = GetConVarFloat(g_hSelectionTimeCvar); // Get selection time

		g_iBlockClientThrow = client;
		SetEntityMoveType(client, MOVETYPE_NONE);			// Freeze ai tank
		SetPlayerGhostState(client, true);					// Ghost ai tank

		CreateTimer(fSelectionTime, _GT_ResumeTank_Timer,client);	// Create timer for restoring ai tank
		fFireImmunityTime += fSelectionTime;				// Add some more time to fire immunity
	}

	CreateTimer(0.1, _GT_TankOnFire_Timer, client, TIMER_REPEAT);
	CreateTimer(fFireImmunityTime, _GT_FireImmunity_Timer); // Create fire immunity timer
	DebugPrintToAllEx("Tank spawned, created fire immunity timer. Immunity time %f", fFireImmunityTime);
}

/**
 * Called when tank is killed.
 *
 * @noreturn
 */
public _GT_TankKilled_Event()
{
	g_bIsTankFireImmune = true;
	DebugPrintToAllEx("Tank killed");
}

/**
 * Called when tank is passed.
 *
 * @noreturn
 */
public _GT_TankPassed_Event()
{
	g_iBlockClientThrow = 0;
	DebugPrintToAllEx("Tank passed");
}

/**
 * Called when a player is hurt.
 *
 * @param event			Handle to event.
 * @param name			String containing the name of the event.
 * @param dontBroadcast	True if event was not broadcast to clients, false otherwise.
 * @noreturn
 */
public _GT_PlayerHurt_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!IsTankInPlay()) return; // If the tank isn't in play, return

	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!client) return;

	if (g_bIsTankFireImmune && GetTankClient() == client)
	{
		new dmgtype = GetEventInt(event, "type");
		if (dmgtype != FIRE_DAMAGE_TYPE) return; // If it wasn't fire that hurt the tank, return

		ExtinguishEntity(client);
		new CurHealth = GetClientHealth(client);
		new DmgDone = GetEventInt(event, "dmg_health");
		SetEntityHealth(client, (CurHealth + DmgDone));
		DebugPrintToAllEx("Tank was burned while being fire immune, health restored and fire put out");
	}
	else if (GetClientTeam(client) == TEAM_SURVIVOR)
	{
		decl String:weapon[32];
		GetEventString(event, "weapon", weapon, sizeof(weapon));
		if (!StrEqual(weapon, WEAPON_TANK_ROCK)) return; // If the weapon that hurt the survivor isn't a rock from tank, return

		if (g_hBlockUse_Timer[client] != INVALID_HANDLE)
		{
			CloseHandle(g_hBlockUse_Timer[client]);
		}
		g_hBlockUse_Timer[client] = CreateTimer(BLOCK_USE_TIME, _GT_BlockUse_Timer, client);
		g_bBlockUse[client] = true;
		DebugPrintToAllEx("Survivor client %i: \"%N\" took a rock and can't use for %f", client, client, BLOCK_USE_TIME);
	}
}

/**
 * Called when a player gets incapacitated.
 *
 * @param event			Handle to event.
 * @param name			String containing the name of the event.
 * @param dontBroadcast	True if event was not broadcast to clients, false otherwise.
 * @noreturn
 */
public _GT_PlayerIncap_Event(Handle:event, String:event_name[], bool:dontBroadcast)
{
	if (!IsTankInPlay()) return; // If the tank isn't in play, return

	decl String:weapon[16];
	GetEventString(event, "weapon", weapon, 16); // Get the weapon used to incap the survivor
	if (!StrEqual(weapon, INCAP_WEAPON)) return; // If tank incap'd the survivor

	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	SetEntProp(client, Prop_Send, "m_isIncapacitated", 0);			// Unincap the survivor
	SetEntityHealth(client, 1);										// Set his health to 1
	CreateTimer(INCAP_DELAY, _GT_PlayerIncap_Timer, client);		// Create timer to reincap him
	DebugPrintToAllEx("Client %i: \"%N\" have been tank punch upon being incap'd", client, client);
}

/**
 * Called when a clients movement buttons are being processed.
 *
 * @param client		Index of the client.
 * @param buttons		Copyback buffer containing the current commands (as bitflags - see entity_prop_stocks.inc).
 * @param impulse		Copyback buffer containing the current impulse command.
 * @param vel			Players desired velocity.
 * @param angles		Players desired view angles.
 * @param weapon		Entity index of the new weapon if player switches weapon, 0 otherwise.
 * @noreturn
 */
public _GT_OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if (g_bBlockUse[client] && buttons & IN_USE)
	{
		buttons ^= IN_USE; // remove use from pressed buttons
		DebugPrintToAllEx("Client %i: \"%N\" tried to use while being prohibit", client, client);
	}

	if (g_iBlockClientThrow == client)
	{
		if(buttons & IN_ATTACK2)
			buttons ^= IN_ATTACK2; // remove attack 2 from pressed buttons
		if(buttons & IN_ATTACK)
			buttons ^= IN_ATTACK; // remove attack 2 from pressed buttons
		DebugPrintToAllEx("Tank AI tried to throw rock while being prohibit");
	}
}

/**
 * Called when the resume tank timer interval has elapsed.
 * 
 * @param timer			Handle to the timer object.
 * @noreturn
 */
public Action:_GT_ResumeTank_Timer(Handle:timer,any:client)
{
	g_iBlockClientThrow = 0; // Reset throw block

	if(!client || !IsClientInGame(client) || !IsFakeClient(client) || GetClientTeam(client) !=3 || GetEntProp(client, Prop_Send, "m_zombieClass") != 5) return;

	SetEntityMoveType(client, MOVETYPE_CUSTOM);			// Reset movetype
	SetPlayerGhostState(client, false);					// And unghost
	DebugPrintToAllEx("Restored AI Tank");
}

/**
 * Called when the fire immunity timer interval has elapsed.
 * 
 * @param timer			Handle to the timer object.
 * @noreturn
 */
public Action:_GT_FireImmunity_Timer(Handle:timer)
{
	g_bIsTankFireImmune = false; // Tank is no longer fire immune
	DebugPrintToAllEx("Tank is no longer fire immune");
}

/**
 * Called when the fire timer interval has elapsed.
 * 
 * @param timer			Handle to the timer object.
 * @noreturn
 */
public Action:_GT_TankOnFire_Timer(Handle:timer,any:client)
{
	if (!g_bIsTankFireImmune || !client || !IsClientInGame(client) || GetClientTeam(client) !=3 || GetEntProp(client, Prop_Send, "m_zombieClass") != 5) return Plugin_Stop;

	if(GetEntityFlags(client) & FL_ONFIRE)
	{
		ExtinguishEntity(client);
		DebugPrintToAllEx("Fire was put out");
	}
	return Plugin_Continue;
}

/**
 * Called when the block use timer interval has elapsed.
 * 
 * @param timer			Handle to the timer object.
 * @param client		Client index.
 * @noreturn
 */
public Action:_GT_BlockUse_Timer(Handle:timer, any:client)
{
	g_bBlockUse[client] = false;
	g_hBlockUse_Timer[client] = INVALID_HANDLE;
}

/**
 * Called when the player incap timer interval has elapsed.
 * 
 * @param timer			Handle to the timer object.
 * @noreturn
 */
public Action:_GT_PlayerIncap_Timer(Handle:timer, any:client)
{
	if(IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVOR)
	{
		SetEntProp(client, Prop_Send, "m_isIncapacitated", 1);	// Incap survivor
		SetEntityHealth(client, INCAP_HEALTH);					// Reset health
	}
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