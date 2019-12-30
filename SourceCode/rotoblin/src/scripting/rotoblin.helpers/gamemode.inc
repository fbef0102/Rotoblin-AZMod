/*
 * ============================================================================
 *
 *  Rotoblin
 *
 *  File:			gamemode.inc
 *  Type:			Helper
 *  Description:	Provides functions to figure out which gamemode is active
 *
 *  Copyright (C) 2010  Mr. Zero
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
#if defined _helper_gamemode
  #endinput
#endif
#define _helper_gamemode

// --------------------
//       Private
// --------------------

// List of gamemodes
static	const			GAMEMODE_VERSUS					= 0;
static	const			GAMEMODE_TEAMVERSUS				= 1;
static	const	String:	GAMEMODES[][]					= {"versus", "teamversus"};

//The cvar handle for mp_gamemode
static	const	String:	GAMEMODE_CVAR[]					= "mp_gamemode";
static			Handle:	g_hGamemode						= INVALID_HANDLE;

// Boolean for keep track of current gamemode
static			bool:	g_bGameMode[sizeof(GAMEMODES)]	= {false};

// **********************************************
//                 Forwards
// **********************************************

/**
 * Module is loading.
 */
public H_GM_OnModuleStart()
{
	g_hGamemode = FindConVar(GAMEMODE_CVAR);
	HookConVarChange(g_hGamemode,H_GM_ConVarChange);

	H_GM_GetGamemode();
}

/**
 * Gamemode cvar was changed
 */
public H_GM_ConVarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	H_GM_GetGamemode();
}

// **********************************************
//                 Public API
// **********************************************

/**
 * Returns whether the gamemode is versus.
 * 
 * @return		True upon the gamemode is versus or team versus, false if not.
 */
stock bool:IsVersus()
{
	if (g_bGameMode[GAMEMODE_TEAMVERSUS]) return true; // If team versus, return true
	return g_bGameMode[GAMEMODE_VERSUS];
}

/**
 * Returns whether the gamemode is team versus.
 * 
 * @return		True upon the gamemode is team versus, false if not.
 */
stock bool:IsTeamVersus()
{
	return g_bGameMode[GAMEMODE_TEAMVERSUS];
}

// **********************************************
//                 Private API
// **********************************************

/**
 * Gets the active gamemode and sets the boolean accordingly.
 * 
 * @noreturn
 */
static H_GM_GetGamemode()
{
	for (new i = 0; i < sizeof(GAMEMODES); i++)
	{
		g_bGameMode[i] = false;
	}

	decl String:sGamemode[32];
	GetConVarString(g_hGamemode,sGamemode,sizeof(sGamemode));

	for (new i = 0; i < sizeof(GAMEMODES); i++)
	{
		if (!StrEqual(GAMEMODES[i],sGamemode)) continue;
		
		g_bGameMode[i] = true;
		return;
	}
}