/*
 * ============================================================================
 *
 *  Rotoblin
 *
 *  File:			rotoblin.unreservelobby.sp
 *  Type:			Module
 *  Description:	Unreserves the lobby so more than 8 players can join.
 *	Credits:		Downtown1 for original source,
 *					http://forums.alliedmods.net/showthread.php?p=846083
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

static					g_iDebugChannel					= 0;
static	const	String:	DEBUG_CHANNEL_NAME[]			= "UnreserveLobby";

// **********************************************
//                   Forwards
// **********************************************

/**
 * Plugin is starting.
 *
 * @noreturn
 */
public _UnreserveLobby_OnPluginStart()
{
	HookPublicEvent(EVENT_ONPLUGINENABLE, _UL_OnPluginEnabled);
	HookPublicEvent(EVENT_ONPLUGINDISABLE, _UL_OnPluginDisabled);

	g_iDebugChannel = DebugAddChannel(DEBUG_CHANNEL_NAME);
	DebugPrintToAllEx("Module is now setup");
}

/**
 * Plugin is now enabled.
 *
 * @noreturn
 */
public _UL_OnPluginEnabled()
{
	HookPublicEvent(EVENT_ONCLIENTPUTINSERVER, _UL_OnClientPutInServer);

	DebugPrintToAllEx("Module is now loaded");
}

/**
 * Plugin is now disabled.
 *
 * @noreturn
 */
public _UL_OnPluginDisabled()
{
	UnhookPublicEvent(EVENT_ONCLIENTPUTINSERVER, _UL_OnClientPutInServer);

	DebugPrintToAllEx("Module is now unloaded");
}

/**
 * A client is put in server.
 *
 * @noreturn
 */
public _UL_OnClientPutInServer(client)
{
	if (!client || IsFakeClient(client)) return;
	L4D_LobbyUnreserve();
	DebugPrintToAllEx("Lobby reservation was removed");
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