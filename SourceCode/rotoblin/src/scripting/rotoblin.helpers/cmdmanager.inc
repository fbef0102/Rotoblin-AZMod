/*
 * ============================================================================
 *
 *  Rotoblin
 *
 *  File:			cmdmanager.inc
 *  Type:			Helper
 *  Description:	Wrappes command listener functions and hooks say command
 *
 *  Copyright (C) 2010  Mr. Zero <mrzerodk@gmail.com>
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

// Don't let the script be included more than once.
#if defined _helper_cmdmgr
  #endinput
#endif
#define _helper_cmdmgr

// --------------------
//       Private
// --------------------

static	const	String:	PUBLIC_TRIGGER[]		= "!";
static	const	String:	PRIVAT_TRIGGER[]		= "/";

static	const			MAX_COMMAND_LENGTH		= 64;
static			Handle:	g_aSayCommands			= INVALID_HANDLE;

// **********************************************
//                 Forwards
// **********************************************

/**
 * On plugin start.
 *
 * @noreturn
 */
public _H_CommandManager_OnPluginStart()
{
	g_aSayCommands = CreateArray(MAX_COMMAND_LENGTH);
	AddCommandListener(H_CM_Say_Command, "say");
	AddCommandListener(H_CM_Say_Command, "say_team");
}

/**
 * Say command listener.
 *
 * @param client        Client, or 0 for server. Client will be connected but
 *                      not necessarily in game.
 * @param command       Command name, lower case. To get name as typed, use
 *                      GetCmdArg() and specify argument 0.
 * @param argc          Argument count.
 * @return				Returning Plugin_Handled or Plugin_Stop will prevent the original,
 *							baseline code from running.
 */ 
public Action:H_CM_Say_Command(client, const String:command[], argc)
{
	if (argc != 1 || client == SERVER_INDEX) return Plugin_Continue; // Too few or too many arguments or client is server, return

	decl String:buffer[128], bool:bHide;
	GetCmdArg(1, buffer, sizeof(buffer));

	decl pos;
	if ((pos = StrContains(buffer, PRIVAT_TRIGGER)) == 0) 
	{
		bHide = true;
	}
	else if ((pos = StrContains(buffer, PUBLIC_TRIGGER)) == 0) 
	{
		bHide = false;
	}
	else
	{
		return Plugin_Continue;
	}

	strcopy(buffer, sizeof(buffer), buffer[pos + 1]); // Strip trigger from left side

	if (FindStringInArray(g_aSayCommands, buffer) != -1)
	{
		if (StrContains(buffer, PLUGIN_CMD_PREFIX, false) == -1)
		{
			Format(buffer, sizeof(buffer), "%s_%s", PLUGIN_CMD_PREFIX, buffer);
		}

		FakeClientCommandEx(client, buffer);
		if (bHide) return Plugin_Handled;
	}

	return Plugin_Continue;
}

// **********************************************
//                 Public API
// **********************************************

/**
 * Adds a command listener to the provided command and hooks say command as
 * well. The command will be prefixed by the plugins cmd prefix.
 * 
 * @param callback		Callback.
 * @param command		Command, or if not specified, a global listener. The command is case insensitive.
 * @return				True upon hooked, false otherwise
 */
stock bool:AddCommandListenerEx(CommandListener:callback, const String:command[])
{
	decl String:buffer[128];
	Format(buffer, sizeof(buffer), "%s_%s", PLUGIN_CMD_PREFIX, command);

	if (!AddCommandListener(callback, buffer)) return false; // If unable to hook, return false

	if (FindStringInArray(g_aSayCommands, command) == -1)
	{
		PushArrayString(g_aSayCommands, command);
	}

	if (FindStringInArray(g_aSayCommands, buffer) == -1)
	{
		PushArrayString(g_aSayCommands, buffer);
	}

	return true;
}

/**
 * Removes a command listener to the provided command and remove hooks for say 
 * command as well. The command will be prefixed by the plugins cmd prefix.
 * 
 * @param callback		Callback.
 * @param command		Command, or if not specified, a global listener. The command is case insensitive.
 * @noreturn
 */
stock RemoveCommandListenerEx(CommandListener:callback, const String:command[])
{
	decl String:buffer[128];
	Format(buffer, sizeof(buffer), "%s_%s", PLUGIN_CMD_PREFIX, command);
	RemoveCommandListener(callback, buffer);

	decl index;
	if ((index = FindStringInArray(g_aSayCommands, command)) != -1)
	{
		RemoveFromArray(g_aSayCommands, index);
	}

	if ((index = FindStringInArray(g_aSayCommands, buffer)) != -1)
	{
		RemoveFromArray(g_aSayCommands, index);
	}
}

/**
 * Checks if the say command was private.
 * 
 * @param command		Command to check.
 * @return				True if private, false otherwise.
 */
stock IsSayCommandPrivate(const String:command[])
{
	if (StrContains(command, PRIVAT_TRIGGER) == 0) return true;
	return false;
}