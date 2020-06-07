/*
 * ============================================================================
 *
 *  Rotoblin
 *
 *  File:			rotoblin.reportstatus.sp
 *  Type:			Module
 *  Description:	Allow clients to get a status report on the rotoblin
 *					installment on the server.
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
//       Public
// --------------------

#define					REPORT_STATUS_MAX_MSG_LENGTH	1024

// --------------------
//       Private
// --------------------

static	const			MAX_CONVAR_NAME_LENGTH							= 64;
static	const			CVAR_ARRAY_BLOCK								= 2;
static	const			FIRST_CVAR_IN_ARRAY								= 0;
static			Handle:	g_aConVarArray									= INVALID_HANDLE;
static			bool:	g_bIsArraySetup									= false;

static	const	Float:	CACHE_RESULT_TIME								= 5.0;
static			bool:	g_bIsResultCached								= false;
static			String:	g_sResultCache[REPORT_STATUS_MAX_MSG_LENGTH]	= "";

static	const	String:	REPORT_STATUS_COMMAND[]							= "version";

// **********************************************
//                   Forwards
// **********************************************

/**
 * Plugin is starting.
 *
 * @noreturn
 */
public _ReportStatus_OnPluginStart()
{
	SetupConVarArray(); // Setup array if needed

	decl String:buffer[128];
	Format(buffer, sizeof(buffer), "%s_%s", PLUGIN_CMD_PREFIX, REPORT_STATUS_COMMAND);
	AddCommandListener(_RS_ReportStatus_Command, buffer);
}

/**
 * On report status client command.
 *
 * @param client		Client id that performed the command.
 * @param command		The command performed.
 * @param args			Number of arguments.
 * @return				Plugin_Handled to stop command from being performed, 
 *						Plugin_Continue to allow the command to pass.
 */
public Action:_RS_ReportStatus_Command(client, const String:command[], argc)
{
	if (client == SERVER_INDEX) return Plugin_Continue; // Server already have a cvar named this, return continue

	if (g_bIsResultCached) // If we have a cached result
	{
		PrintToConsole(client, g_sResultCache); // Print cached result
		return Plugin_Handled; // Handled
	}

	decl String:result[REPORT_STATUS_MAX_MSG_LENGTH];

	Format(result, sizeof(result), "version: %s\n", PLUGIN_VERSION);
	//Format(result, sizeof(result), "%supdated: %s%s\n", result, (IsPluginUpdated() ? "yes" : "no"));
	Format(result, sizeof(result), "%senabled: %s\n", result, (IsPluginEnabled() ? "yes" : "no"));
	Format(result, sizeof(result), "%slisting %i cvars:", result, (GetArraySize(g_aConVarArray) / CVAR_ARRAY_BLOCK));

	decl String:name[MAX_CONVAR_NAME_LENGTH];
	decl String:value[MAX_CONVAR_NAME_LENGTH];
	decl String:defaultValue[MAX_CONVAR_NAME_LENGTH];
	decl Handle:cvar;

	for (new i = FIRST_CVAR_IN_ARRAY; i < GetArraySize(g_aConVarArray); i += CVAR_ARRAY_BLOCK)
	{
		GetArrayString(g_aConVarArray, i, name, MAX_CONVAR_NAME_LENGTH);
		cvar = FindConVar(name);
		if (cvar == INVALID_HANDLE) continue;
		GetConVarString(cvar, value, MAX_CONVAR_NAME_LENGTH);

		GetArrayString(g_aConVarArray, i + 1, defaultValue, MAX_CONVAR_NAME_LENGTH);
		Format(defaultValue, MAX_CONVAR_NAME_LENGTH, "( def. \"%s\" )", defaultValue);

		Format(result, sizeof(result), "%s\n \"%s\" = \"%s\" %s", result, name, value, defaultValue);
	}

	PrintToConsole(client, result);

	// Cache result to prevent clients spamming this command to lag the server
	g_sResultCache = result;
	g_bIsResultCached = true;
	CreateTimer(CACHE_RESULT_TIME, _RS_Cache_Timer);

	return Plugin_Handled;
}

/**
 * Called when the cached timer interval has elapsed.
 * 
 * @param timer			Handle to the timer object.
 * @noreturn
 */
public Action:_RS_Cache_Timer(Handle:timer)
{
	g_bIsResultCached = false;
}

// **********************************************
//                 Public API
// **********************************************

/**
 * Adds convar to the report status array.
 * 
 * @param convar		Handle to convar.
 * @noreturn
 */
stock AddConVarToReport(Handle:convar)
{
	SetupConVarArray(); // Setup array if needed

	/*
	 * Get name of convar
	 */
	decl String:name[MAX_CONVAR_NAME_LENGTH];
	GetConVarName(convar, name, MAX_CONVAR_NAME_LENGTH);

	if (FindStringInArray(g_aConVarArray, name) != -1) return; // Already in array

	/*
	 * Get default value of convar
	 */
	decl String:value[MAX_CONVAR_NAME_LENGTH], String:defaultvalue[MAX_CONVAR_NAME_LENGTH];
	GetConVarString(convar, value, MAX_CONVAR_NAME_LENGTH);

	new flags = GetConVarFlags(convar);
	if (flags & FCVAR_NOTIFY)
	{
		SetConVarFlags(convar, flags ^ FCVAR_NOTIFY);
	}

	ResetConVar(convar);
	GetConVarString(convar, defaultvalue, MAX_CONVAR_NAME_LENGTH);
	SetConVarString(convar, value);
	SetConVarFlags(convar, flags);

	/*
	 * Push to array
	 */
	PushArrayString(g_aConVarArray, name);
	PushArrayString(g_aConVarArray, defaultvalue);
}

// **********************************************
//                 Private API
// **********************************************

/**
 * Adds convar to the report status array.
 * 
 * @param convar		Handle to convar.
 * @noreturn
 */
static SetupConVarArray()
{
	if (g_bIsArraySetup) return;
	g_aConVarArray = CreateArray(MAX_CONVAR_NAME_LENGTH);

	g_bIsArraySetup = true;
}