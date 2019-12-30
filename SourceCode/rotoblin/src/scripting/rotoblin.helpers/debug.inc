/*
 * ============================================================================
 *
 *  Rotoblin
 *
 *  File:			debug.inc
 *  Type:			Helper
 *  Description:	Provides debug functions for modules
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
#if defined _helper_debug
  #endinput
#endif
#define _helper_debug

// --------------------
//       Public
// --------------------

#define					DEBUG_MESSAGE_LENGTH			1024
#define					DEBUG_CHANNEL_NAME_LENGTH		64
#define					DEBUG_STATUS_MESSAGE_LENGTH		2048
#define					DEBUG_CHANNEL_GENERAL			0

// --------------------
//       Private
// --------------------

static	const			OUT_SERVER						= 1;
static	const			OUT_CHAT						= 2;
static	const			OUT_LOG							= 4;
static	const			CHANNEL_ALL						= -1;
static	const	String:	CHANNEL_GENERAL_NAME[]			= "General";
static	const	String:	SETTINGS_NAME_KEY[]				= "_name";
static	const	String:	SETTINGS_FLAG_KEY[]				= "_flag";

static			bool:	g_bIsModuleSetup				= false;
static			Handle:	g_hChannelsTrie					= INVALID_HANDLE;
static					g_iNextChannel_Flag				= 1;
static					g_iNextChannel_Index			= 1;

static					g_iOutputFlags					= 0;
static					g_iChannelFlags					= 0;

// **********************************************
//                   Forwards
// **********************************************

/**
 * Channel cvar changed.
 *
 * @param convar		Handle to the convar that was changed.
 * @param oldValue		String containing the value of the convar before it was changed.
 * @param newValue		String containing the new value of the convar.
 * @noreturn
 */
public _H_D_Channel_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	g_iChannelFlags = StringToInt(newValue);
}

/**
 * Output cvar changed.
 *
 * @param convar		Handle to the convar that was changed.
 * @param oldValue		String containing the value of the convar before it was changed.
 * @param newValue		String containing the new value of the convar.
 * @noreturn
 */
public _H_D_Output_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	g_iOutputFlags = StringToInt(newValue);
}

/**
 * Called when debug status command is invoked.
 *
 * @param client		Index of the client, or 0 from the server.
 * @param args			Number of arguments that were in the argument string.
 * @return				An Action value.  Not handling the command
 *						means that Source will report it as "not found."
 */
public Action:_H_D_Status_Command(client, args)
{
	decl channelFlag, String:channelName[DEBUG_CHANNEL_NAME_LENGTH], String:buffer[DEBUG_CHANNEL_NAME_LENGTH], String:result[DEBUG_STATUS_MESSAGE_LENGTH];
	new channelCounter = 0;

	Format(result, sizeof(result), "\n==================================================\n");
	Format(result, sizeof(result), "%s%s\n\n  Debug status:\n    Current channel flag: %i\n    Current output flag: %i\n\n", result, PLUGIN_FULLNAME, g_iChannelFlags, g_iOutputFlags);
	Format(result, sizeof(result), "%s  Channel Listing:\n    Index. Name - Flag \n    -----\n", result);

	for (new i = 0; i < g_iNextChannel_Index; i++)
	{
		Format(buffer, sizeof(buffer), "%s%s", i, SETTINGS_FLAG_KEY);
		if (!GetTrieValue(g_hChannelsTrie, buffer, channelFlag)) continue;

		Format(buffer, sizeof(buffer), "%s%s", i, SETTINGS_NAME_KEY);
		if (!GetTrieString(g_hChannelsTrie, buffer, channelName, sizeof(channelName))) continue;

		Format(result, sizeof(result), "%s    %i. \"%s\" - %i\n", result, i, channelName, channelFlag);
		channelCounter++;
	}

	Format(result, sizeof(result), "%s    -----\n    Total channels: %i\n\n", result, channelCounter);
	Format(result, sizeof(result), "%s==================================================\n", result);

	if (client == SERVER_INDEX)
	{
		PrintToServer(result);
	}
	else
	{
		ReplyToCommand(client, "[%s] Debug status printed to console", PLUGIN_TAG);
		PrintToConsole(client, result);
	}

	return Plugin_Handled;
}

// **********************************************
//                 Public API
// **********************************************

/**
 * Adds a debug channel.
 *
 * @param channelName	Name of the channel.
 * @return				Channel index.
 */
stock DebugAddChannel(const String:channelName[])
{
	if (!SetupModule()) ThrowError("Unable to set up debug trie!");

	new channelIndex = g_iNextChannel_Index;
	new channelFlag = g_iNextChannel_Flag;

	decl String:buffer[DEBUG_CHANNEL_NAME_LENGTH];

	// Store flag
	Format(buffer, sizeof(buffer), "%s%s", channelIndex, SETTINGS_FLAG_KEY);
	SetTrieValue(g_hChannelsTrie, buffer, channelFlag);

	// Store channel name
	Format(buffer, sizeof(buffer), "%s%s", channelIndex, SETTINGS_NAME_KEY);
	SetTrieString(g_hChannelsTrie, buffer, channelName);

	g_iNextChannel_Index++;
	g_iNextChannel_Flag *= 2;
	return channelIndex;
}

/**
 * Prints a debug message.
 *
 * @param channelIndex	Index of channel.
 * @param format		Formatting rules.
 * @param ...			Variable number of format parameters.
 * @noreturn
 */
stock DebugPrintToAll(channelIndex, const String:format[], any:...)
{
	if (!g_iOutputFlags || !SetupModule()) return;

	decl String:buffer[DEBUG_MESSAGE_LENGTH];

	decl channelFlag;
	Format(buffer, sizeof(buffer), "%s%s", channelIndex, SETTINGS_FLAG_KEY);
	if (!GetTrieValue(g_hChannelsTrie, buffer, channelFlag)) return; // Unable to get channel flag, return

	if (!(g_iChannelFlags & channelFlag) && g_iChannelFlags != CHANNEL_ALL) return; // Channel flags does not contain this channel and we arent logging all channels, return

	decl String:channelName[DEBUG_CHANNEL_NAME_LENGTH];
	Format(buffer, sizeof(buffer), "%s%s", channelIndex, SETTINGS_NAME_KEY);
	GetTrieString(g_hChannelsTrie, buffer, channelName, sizeof(channelName));

	VFormat(buffer, sizeof(buffer), format, 3);

	if (g_iOutputFlags & OUT_SERVER)
	{
		PrintToServer("[%s][%s] %s", PLUGIN_TAG, channelName, buffer);
	}
	if (g_iOutputFlags & OUT_CHAT)
	{
		PrintToChatAll("[%s][%s] %s", PLUGIN_TAG, channelName, buffer);
	}
	if (g_iOutputFlags & OUT_LOG)
	{
		LogMessage("[%s] %s", channelName, buffer);
	}
}

// **********************************************
//                 Private API
// **********************************************

/**
 * Sets up module cvars and trie to store channel flags and names.
 *
 * @return				True if setup, false otherwise
 */
static bool:SetupModule()
{
	if (g_bIsModuleSetup) return true;

	g_hChannelsTrie = CreateTrie();
	if (g_hChannelsTrie == INVALID_HANDLE) return false;

	// Setup the general channel
	decl String:buffer[DEBUG_CHANNEL_NAME_LENGTH];
	Format(buffer, sizeof(buffer), "%s%s", DEBUG_CHANNEL_GENERAL, SETTINGS_FLAG_KEY);
	SetTrieValue(g_hChannelsTrie, buffer, DEBUG_CHANNEL_GENERAL);
	Format(buffer, sizeof(buffer), "%s%s", DEBUG_CHANNEL_GENERAL, SETTINGS_NAME_KEY);
	SetTrieString(g_hChannelsTrie, buffer, CHANNEL_GENERAL_NAME);

	decl Handle:cvar;
	cvar = CreateConVarEx("debug_channel",
		"0",
		"Sum of debug channel flags. -1 - Log all channels, 0 - General channel only, 0+ - Log channel of flag",
		FCVAR_PLUGIN);
	g_iChannelFlags = GetConVarInt(cvar);
	HookConVarChange(cvar, _H_D_Channel_CvarChange);

	cvar = CreateConVarEx("debug_output",
		"0",
		"Sum of debug output flags. 0 - No logging, 1 - Print to server, 2 - Print to chat, 4 - Log to SM logs",
		FCVAR_PLUGIN);
	g_iOutputFlags = GetConVarInt(cvar);
	HookConVarChange(cvar, _H_D_Output_CvarChange);

	RegAdminCmdEx("debug_status", _H_D_Status_Command, ADMFLAG_ROOT, "Writes report of channels and what is current listen to", _, FCVAR_PLUGIN);

	g_bIsModuleSetup = true;
	return true;
}