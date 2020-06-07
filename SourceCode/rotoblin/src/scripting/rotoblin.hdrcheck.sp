/*
 * ============================================================================
 *
 *  Rotoblin
 *
 *  File:			rotoblin.hdrcheck.sp
 *  Type:			Module
 *  Description:	Kick clients who uses low hdr values to remove the dark
 *					lightning from the maps.
 *
 *  Copyright (C) 2010  suprep <sof2er@gmail.com>
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

static	const	String:	HDR_CVAR[]				= "mat_hdr_level";
static	const			HDR_CVAR_MAX			= 5;
static	const			HDR_CVAR_MIN			= 2;
static	const	Float:	CHECK_INTERVAL			= 1.0; // How often we check the HDR value of clients

static					g_iHdrMax				= 5;
static					g_iHdrMin				= 2;
static			Handle:	g_hMaxHdr_Cvar			= INVALID_HANDLE;
static			Handle:	g_hMinHdr_Cvar			= INVALID_HANDLE;
static			Handle:	g_hHdrTimer				= INVALID_HANDLE;

static					g_iDebugChannel			= 0;
static	const	String:	DEBUG_CHANNEL_NAME[]	= "HDR";

// **********************************************
//                   Forwards
// **********************************************

/**
 * Plugin is starting.
 *
 * @noreturn
 */
public _HDRCheck_OnPluginStart()
{
	HookPublicEvent(EVENT_ONPLUGINENABLE, _HDRC_OnPluginEnabled);
	HookPublicEvent(EVENT_ONPLUGINDISABLE, _HDRC_OnPluginDisabled);

	decl String:buffer[10];

	IntToString(g_iHdrMin, buffer, sizeof(buffer));
	g_hMinHdr_Cvar = CreateConVarEx("hdr_min", buffer, 
		"Defines minimum hdr value a player is allowed to play with. Players with lower hdr value than this will be kicked.", 
		FCVAR_PLUGIN | FCVAR_NOTIFY, true, float(HDR_CVAR_MIN), true, float(HDR_CVAR_MAX));
	AddConVarToReport(g_hMinHdr_Cvar); // Add to report status module

	IntToString(g_iHdrMax, buffer, sizeof(buffer));
	g_hMaxHdr_Cvar = CreateConVarEx("hdr_max", buffer, 
		"Defines maximum hdr value a player is allowed to play with. Players with higher hdr value than this will be kicked.", 
		FCVAR_PLUGIN | FCVAR_NOTIFY, true, float(HDR_CVAR_MIN), true, float(HDR_CVAR_MAX));
	AddConVarToReport(g_hMaxHdr_Cvar); // Add to report status module

	g_iDebugChannel = DebugAddChannel(DEBUG_CHANNEL_NAME);
	DebugPrintToAllEx("Module is now setup");
}

/**
 * Plugin is now enabled.
 *
 * @noreturn
 */
public _HDRC_OnPluginEnabled()
{
	UpdateHdrValues();
	HookConVarChange(g_hMinHdr_Cvar, _HDRC_Values_CvarChange);
	HookConVarChange(g_hMaxHdr_Cvar, _HDRC_Values_CvarChange);
	g_hHdrTimer = CreateTimer(CHECK_INTERVAL, _HDRC_CheckPlayers_Timer, _, TIMER_REPEAT);
	DebugPrintToAllEx("Module is now loaded");
}

/**
 * Plugin is now disabled.
 *
 * @noreturn
 */
public _HDRC_OnPluginDisabled()
{
	CloseHandle(g_hHdrTimer);
	UnhookConVarChange(g_hMinHdr_Cvar, _HDRC_Values_CvarChange);
	UnhookConVarChange(g_hMaxHdr_Cvar, _HDRC_Values_CvarChange);
	DebugPrintToAllEx("Module is now unloaded");
}

/**
 * Called when hdr values is changed.
 *
 * @param convar		Handle to the convar that was changed.
 * @param oldValue		String containing the value of the convar before it was changed.
 * @param newValue		String containing the new value of the convar.
 * @noreturn
 */
public _HDRC_Values_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	UpdateHdrValues();
}

/**
 * Called when timer interval has elapsed.
 * 
 * @param timer			Handle to the timer object.
 * @return				Plugin_Stop to stop the timer, any other value for
 *						default behavior.
 */
public Action:_HDRC_CheckPlayers_Timer(Handle:timer)
{
	if(!IsServerProcessing() || IsZACKLoaded()) return Plugin_Continue;

	decl client;
	if (SurvivorCount) // If any survivors
	{
		for (new i = 0; i < SurvivorCount; i++)
		{
			client = SurvivorIndex[i];
			if (IsFakeClient(client)) continue;
			QueryClientConVar(client, HDR_CVAR, _HDRC_CheckCvar);
			DebugPrintToAllEx("Checking client %i: \"%N\"", client, client);
		}
	}

	if (InfectedCount) // If any infected
	{
		for (new i = 0; i < InfectedCount; i++)
		{
			client = InfectedIndex[i];
			if (IsFakeClient(client)) continue;
			QueryClientConVar(client, HDR_CVAR, _HDRC_CheckCvar);
			DebugPrintToAllEx("Checking client %i: \"%N\"", client, client);
		}
	}

	return Plugin_Continue;
}

/**
 * Called when query to retrieve a client's mat_hdr_level cvar has finished.
 *
 * @param cookie		Unique identifier of query.
 * @param client		Player index.
 * @param result		Result of query that tells one whether or not query was successful.
 *							See ConVarQueryResult enum for more details.
 * @param convarName	Name of client convar that was queried.
 * @param convarValue	Value of client convar that was queried if successful. This will be "" if it was not.
 * @noreturn
 */
public _HDRC_CheckCvar(QueryCookie:cookie, client, ConVarQueryResult:result, const String:cvarName[], const String:cvarValue[])
{
	if (!client || !IsClientInGame(client) || IsFakeClient(client)) return;

	if (result != ConVarQuery_Okay)
	{
		/* If the cvar was somehow not found, not valid or protected, kick client anyway.
		 * They might try to prevent the plugin to look at the cvar. For any normal reasons the cvar should not be unreadable. */
		decl String:name[MAX_NAME_LENGTH], String:auth[32];
		GetClientName(client, name, sizeof(name));
		GetClientAuthString(client, auth, sizeof(auth));
		KickClient(client, "Could not retrive value for %s cvar", HDR_CVAR);
		PrintToChatAll("[%s] Kicked %s. Could not retrive value for %s cvar", PLUGIN_TAG, name, HDR_CVAR);
		LogAction(0, client, "[%s] Kicked %s as rate hack module could not retrive value for %s cvar", PLUGIN_TAG, name, HDR_CVAR);
		DebugPrintToAllEx("Kicked client %i: \"%N\". Couldn't retrive value", client, client);

		return;
	}

	new value = StringToInt(cvarValue);
	if (value <= g_iHdrMax && value >= g_iHdrMin)
	{
		DebugPrintToAllEx("Client %i: \"%N\" is ok. Using a value of %i", client, client, value);
		return; // HDR value is alright, return
	}

	decl String:name[MAX_NAME_LENGTH], String:auth[32];
	GetClientName(client, name, sizeof(name));
	GetClientAuthString(client, auth, sizeof(auth));
	KickClient(client, "Kicked for using a mat_hdr_level value of %i (max. %i, min. %i)", value, g_iHdrMax, g_iHdrMin);
	PrintToChatAll("[%s] Kicked %s. Was using a mat_hdr_level value of %i (max. %i, min. %i)", PLUGIN_TAG, name, value, g_iHdrMax, g_iHdrMin);
	LogAction(0, client, "[%s] Kicked %s for using a mat_hdr_level value of %i (max. %i, min. %i)", PLUGIN_TAG, name, value, g_iHdrMax, g_iHdrMin);
	DebugPrintToAllEx("Kicked client %i: \"%N\". Was using a mat_hdr_level value of %i", client, client, value);
}

// **********************************************
//                 Private API
// **********************************************

/**
 * Updates the global mat_hdr_level values with the cvars.
 *
 * @noreturn
 */
static UpdateHdrValues()
{
	DebugPrintToAllEx("Updating global hdr values");
	g_iHdrMin = GetConVarInt(g_hMinHdr_Cvar);
	g_iHdrMax = GetConVarInt(g_hMaxHdr_Cvar);
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