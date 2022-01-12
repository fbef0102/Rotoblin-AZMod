/*
 * ============================================================================
 *
 *  Rotoblin
 *
 *  File:			rotoblin.autoupdate.sp
 *  Type:			Module
 *  Description:	Automatic download of new updates for Rotoblin
 *
 *  Copyright (C) 2010  Mr. Zero <mrzerodk@gmail.com>
 *  Copyright (C) 2017-2022  Harry <fbef0102@gmail.com>
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
//       Public
// --------------------

#define UMIN(%1,%2) (%1 < %2 ? %2 : %1)

// --------------------
//       Private
// --------------------

static 	const 	String:	SITE[] 				= "dpi-clan.org";
static	const	String: FILE[]				= "uploads/rotoblin/rotoblin.xml";

static 	const 			MAX_CONNECT_TRIES 	= 25; // How many times can we try to connect before giving up
static	const	Float:	RETRY_TIME 			= 2.0; // If connection failed, wait this time before trying again
static	const	Float:	RECHECK_TIME		= 604800.0; // Check again in week

static 	const 	String:	HEADER_SEPARATOR[] 	= "\r\n\r\n";
static	const	String:	XML_VERSION_TAG[]	= "version";

static 					g_iConnectTries		= 0;
static			bool:	g_bIsTimerRunning	= false;
static			Handle:	g_hRecheckTimer		= INVALID_HANDLE;

// **********************************************
//                 Forwards
// **********************************************

/**
 * Plugin is starting.
 *
 * @noreturn
 */
public _AutoUpdate_OnPluginStart()
{
	HookPublicEvent(EVENT_ONPLUGINENABLE, _AU_OnPluginEnabled);
	HookPublicEvent(EVENT_ONPLUGINDISABLE, _AU_OnPluginDisabled);
}

/**
 * Plugin is now enabled.
 *
 * @noreturn
 */
public _AU_OnPluginEnabled()
{
	if (g_hRecheckTimer != INVALID_HANDLE) return; // Plugin have already check and recheck timer have started.
	_AU_CreateSocket(); // Create socket to check for updates
}

/**
 * Plugin is now disabled.
 *
 * @noreturn
 */
public _AU_OnPluginDisabled()
{
	//CloseHandle(g_hRecheckTimer); // Close recheck timer
}

public _AU_OnSocketConnected(Handle:socket, any:arg)
{
	decl String:requestStr[500];
	Format(requestStr, sizeof(requestStr), "GET /%s HTTP/1.0\r\nHost: %s\r\nConnection: close\r\n\r\n", FILE, SITE);
	SocketSend(socket, requestStr);
}

public _AU_OnSocketReceive(Handle:socket, String:receiveData[], const dataSize, any:junk)
{
	CloseHandle(socket);
	
	decl String:data[500];
	new pos = StrContains(receiveData, HEADER_SEPARATOR) + sizeof(HEADER_SEPARATOR) - 1; // Cut off the header
	strcopy(data, sizeof(data), receiveData[pos]);
	_AU_CheckVersion(data); // Check version

	g_hRecheckTimer = CreateTimer(RECHECK_TIME, _AU_CheckVersion_Timer);
}

public _AU_OnSocketDisconnected(Handle:socket, any:junk)
{
	CloseHandle(socket);
	_AU_RecreateSocket();
}

public _AU_OnSocketError(Handle:socket, const errorType, const errorNum, any:junk)
{
	CloseHandle(socket);
	_AU_RecreateSocket();
}

public Action:_AU_RecreateSocket_Timer(Handle:timer)
{
	_AU_CreateSocket();
	g_bIsTimerRunning = false;
}

public Action:_AU_CheckVersion_Timer(Handle:timer)
{
	g_iConnectTries = 0;
	_AU_CreateSocket();
}

// **********************************************
//                 Private API
// **********************************************

static _AU_CreateSocket()
{
	if (g_hRecheckTimer != INVALID_HANDLE)
	{
		CloseHandle(g_hRecheckTimer);
		g_hRecheckTimer = INVALID_HANDLE;
	}

	if (g_iConnectTries > MAX_CONNECT_TRIES)
	{
		g_iConnectTries = 0;
		LogMessage("Unable to contact %s for update information!", SITE);
		return;
	}

	g_iConnectTries++;
	new Handle:socket = SocketCreate(SOCKET_TCP, _AU_OnSocketError);
	SocketConnect(socket, _AU_OnSocketConnected, _AU_OnSocketReceive, _AU_OnSocketDisconnected, SITE, 80);
}

static _AU_RecreateSocket()
{
	if (g_bIsTimerRunning) return;
	g_bIsTimerRunning = true;
	CreateTimer(RETRY_TIME, _AU_RecreateSocket_Timer);
}

static _AU_CheckVersion(const String:data[])
{
	decl String:version[32];
	_AU_ReadXMLTag(version, sizeof(version), data, XML_VERSION_TAG);
	if (StrEqual(PLUGIN_VERSION, version)) return;

	LogMessage("Your Rotoblin installation is outdated! Please update at %s!", PLUGIN_URL);
}

static _AU_ReadXMLTag(String:dest[], destLen, const String:source[], const String:tag[])
{
	decl String:startTag[128], String:endTag[128];
	Format(startTag, sizeof(startTag), "<%s>", tag);
	Format(endTag, sizeof(endTag), "</%s>", tag);

	new pos = StrContains(source, startTag) + strlen(startTag);
	strcopy(dest, UMIN(destLen, (StrContains(source, endTag) - pos) + 1), source[pos]);
}