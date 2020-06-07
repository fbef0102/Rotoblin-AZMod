/*
 * ============================================================================
 *
 *  Rotoblin
 *
 *  File:			rotoblin.ratehack.sp
 *  Type:			Module
 *  Description:	Kick clients who uses incorrect interp values to perform
 *					"rate hacking".
 *
 *  Copyright (C) 2010  Mr. Zero <mrzerodk@gmail.com>
 *  Copyright (C) 2017-2020  Harry <fbef0102@gmail.com>
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

static	const	String:	INTERP_CVAR[]			= "cl_interp";
static	const	Float:	INTERP_CVAR_MAX			= 0.5;
static	const	Float:	INTERP_CVAR_MIN			= 0.0;
static	const	Float:	CHECK_INTERVAL			= 1.0; // How often we check the interp value of clients

static			Float:	g_fMaxInterp			= 0.1;
static			Float:	g_fMinInterp			= 0.0;
static			Handle:	g_hMaxInterp_Cvar		= INVALID_HANDLE;
static			Handle:	g_hMinInterp_Cvar		= INVALID_HANDLE;
static			Handle:	g_hTimer				= INVALID_HANDLE;

static					g_iDebugChannel			= 0;
static	const	String:	DEBUG_CHANNEL_NAME[]	= "RateHack";

// **********************************************
//                   Forwards
// **********************************************

/**
 * Plugin is starting.
 *
 * @noreturn
 */
public _RateHack_OnPluginStart()
{
	HookPublicEvent(EVENT_ONPLUGINENABLE, _RH_OnPluginEnabled);
	HookPublicEvent(EVENT_ONPLUGINDISABLE, _RH_OnPluginDisabled);

	decl String:buffer[10];

	FloatToString(g_fMinInterp, buffer, sizeof(buffer));
	g_hMinInterp_Cvar = CreateConVarEx("interp_min", buffer, 
		"Defines minimum interp value a player is allowed to play with. Players with lower interp value than this will be kicked.", 
		FCVAR_PLUGIN | FCVAR_NOTIFY, true, INTERP_CVAR_MIN, true, INTERP_CVAR_MAX);
	AddConVarToReport(g_hMinInterp_Cvar); // Add to report status module

	FloatToString(g_fMaxInterp, buffer, sizeof(buffer));
	g_hMaxInterp_Cvar = CreateConVarEx("interp_max", buffer, 
		"Defines maximum interp value a player is allowed to play with. Players with higher interp value than this will be kicked.", 
		FCVAR_PLUGIN | FCVAR_NOTIFY, true, INTERP_CVAR_MIN, true, INTERP_CVAR_MAX);
	AddConVarToReport(g_hMaxInterp_Cvar); // Add to report status module

	g_iDebugChannel = DebugAddChannel(DEBUG_CHANNEL_NAME);
	DebugPrintToAllEx("Module is now setup");
}

/**
 * Plugin is now enabled.
 *
 * @noreturn
 */
public _RH_OnPluginEnabled()
{
	UpdateInterpValues();
	HookConVarChange(g_hMinInterp_Cvar, _RH_InterpValues_CvarChange);
	HookConVarChange(g_hMaxInterp_Cvar, _RH_InterpValues_CvarChange);
	g_hTimer = CreateTimer(CHECK_INTERVAL, _RH_CheckPlayers_Timer, _, TIMER_REPEAT);
	DebugPrintToAllEx("Module is now loaded");
}

/**
 * Plugin is now disabled.
 *
 * @noreturn
 */
public _RH_OnPluginDisabled()
{
	CloseHandle(g_hTimer);
	UnhookConVarChange(g_hMinInterp_Cvar, _RH_InterpValues_CvarChange);
	UnhookConVarChange(g_hMaxInterp_Cvar, _RH_InterpValues_CvarChange);
	DebugPrintToAllEx("Module is now unloaded");
}

/**
 * Called when interp values is changed.
 *
 * @param convar		Handle to the convar that was changed.
 * @param oldValue		String containing the value of the convar before it was changed.
 * @param newValue		String containing the new value of the convar.
 * @noreturn
 */
public _RH_InterpValues_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	UpdateInterpValues();
}

/**
 * Called when timer interval has elapsed.
 * 
 * @param timer			Handle to the timer object.
 * @return				Plugin_Stop to stop the timer, any other value for
 *						default behavior.
 */
public Action:_RH_CheckPlayers_Timer(Handle:timer)
{
	if(!IsServerProcessing() || IsZACKLoaded()) return Plugin_Continue;

	decl client;
	if (SurvivorCount) // If any survivors
	{
		for (new i = 0; i < SurvivorCount; i++)
		{
			client = SurvivorIndex[i];
			if (IsFakeClient(client)) continue;
			QueryClientConVar(client, INTERP_CVAR, _RH_CheckCvar);
			DebugPrintToAllEx("Checking client %i: \"%N\"", client, client);
		}
	}

	if (InfectedCount) // If any infected
	{
		for (new i = 0; i < InfectedCount; i++)
		{
			client = InfectedIndex[i];
			if (IsFakeClient(client)) continue;
			QueryClientConVar(client, INTERP_CVAR, _RH_CheckCvar);
			DebugPrintToAllEx("Checking client %i: \"%N\"", client, client);
		}
	}

	return Plugin_Continue;
}

/**
 * Called when query to retrieve a client's interp cvar has finished.
 *
 * @param cookie		Unique identifier of query.
 * @param client		Player index.
 * @param result		Result of query that tells one whether or not query was successful.
 *							See ConVarQueryResult enum for more details.
 * @param convarName	Name of client convar that was queried.
 * @param convarValue	Value of client convar that was queried if successful. This will be "" if it was not.
 * @noreturn
 */
public _RH_CheckCvar(QueryCookie:cookie, client, ConVarQueryResult:result, const String:cvarName[], const String:cvarValue[])
{
	if (!client || !IsClientInGame(client) || IsFakeClient(client)) return;

	if (result != ConVarQuery_Okay)
	{
		/* If the cvar was somehow not found, not valid or protected, kick client anyway.
		 * They might try to prevent the plugin to look at the cvar. For any normal reasons the cvar should not be unreadable. */
		decl String:name[MAX_NAME_LENGTH], String:auth[32];
		GetClientName(client, name, sizeof(name));
		GetClientAuthString(client, auth, sizeof(auth));
		KickClient(client, "Could not retrive value for %s cvar", INTERP_CVAR);
		PrintToChatAll("[%s] Kicked %s. Could not retrive value for %s cvar", PLUGIN_TAG, name, INTERP_CVAR);
		LogAction(0, client, "[%s] Kicked %s as rate hack module could not retrive value for %s cvar", PLUGIN_TAG, name, INTERP_CVAR);
		DebugPrintToAllEx("Kicked client %i: \"%N\". Couldn't retrive value", client, client);

		return;
	}

	new Float:value = StringToFloat(cvarValue);
	if (value <= g_fMaxInterp && value >= g_fMinInterp)
	{
		DebugPrintToAllEx("Client %i: \"%N\" is ok. Using a value of %f", client, client, value);
		return; // Interp value is alright, return
	}

	decl String:name[MAX_NAME_LENGTH], String:auth[32];
	GetClientName(client, name, sizeof(name));
	GetClientAuthString(client, auth, sizeof(auth));
	KickClient(client, "Kicked for using an interp value of %f (max. %f, min. %f)", value, g_fMaxInterp, g_fMinInterp);
	PrintToChatAll("[%s] Kicked %s. Was using an interp value of %f (max. %f, min. %f)", PLUGIN_TAG, name, value, g_fMaxInterp, g_fMinInterp);
	LogAction(0, client, "[%s] Kicked %s for using an interp value of %f (max. %f, min. %f)", PLUGIN_TAG, name, value, g_fMaxInterp, g_fMinInterp);
	DebugPrintToAllEx("Kicked client %i: \"%N\". Was using an interp value of %f", client, client, value);
}

// **********************************************
//                 Private API
// **********************************************

/**
 * Updates the global interp values with the cvars.
 *
 * @noreturn
 */
static UpdateInterpValues()
{
	DebugPrintToAllEx("Updating global interp values");
	g_fMinInterp = GetConVarFloat(g_hMinInterp_Cvar);
	g_fMaxInterp = GetConVarFloat(g_hMaxInterp_Cvar);
}

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