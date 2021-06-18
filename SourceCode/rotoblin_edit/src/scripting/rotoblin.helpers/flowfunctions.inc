/*
 * ============================================================================
 *
 *  Rotoblin
 *
 *  File:			flowfunctions.inc
 *  Type:			Helper
 *  Description:	Provides native functions to find flow of current player or
 *					of common infected.
 *	Credits:		Atomic for original source.
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
#if defined _helper_flowfunctions
  #endinput
#endif
#define _helper_flowfunctions

// --------------------
//       Private
// --------------------

static	const	String:	GAMECONFIG_INFECTED_FLOW[]			= "Infected_GetFlowDistance";
static	const	String:	GAMECONFIG_PLAYER_FLOW[]			= "CTerrorPlayer_GetFlowDistance";

static	const 			FLOWTYPE_DEFAULT 					= 0;

static			Handle:	g_hGetInfectedFlowDistance			= INVALID_HANDLE;
static			Handle:	g_hGetPlayerFlowDistance			= INVALID_HANDLE;

static			bool:	g_bIsModuleSetup					= false;

// **********************************************
//                 Public API
// **********************************************

/**
 * Returns Infected::GetFlowDistance with provided entity.
 * 
 * @param entity		Entity to get flow distance off.
 * @return				Flow distance of entity.
 */
stock Float:GetInfectedFlowDistance(entity)
{
	SetupModule();
	return SDKCall(g_hGetInfectedFlowDistance, entity);
}

/**
 * Returns CTerrorPlayer::GetFlowDistance with provided client.
 * 
 * @param client		Client to get flow distance off.
 * @return				Flow distance of client.
 */
stock Float:GetPlayerFlowDistance(client)
{
	SetupModule();
	return SDKCall(g_hGetPlayerFlowDistance, client, FLOWTYPE_DEFAULT); // integer flowtype does not actually have an effect, 0 or 1 or anything work fine
}

// **********************************************
//                 Private API
// **********************************************

static SetupModule()
{
	if (g_bIsModuleSetup) return;

	new Handle:conf = LoadGameConfigFile(PLUGIN_GAMECONFIG_FILE);

	if (conf == INVALID_HANDLE) 
	{
		ThrowError("Failed to load %s.txt in gamedata folder", PLUGIN_GAMECONFIG_FILE);
	}

	StartPrepSDKCall(SDKCall_Entity);
	if (!PrepSDKCall_SetFromConf(conf, SDKConf_Signature, GAMECONFIG_INFECTED_FLOW))
	{
		ThrowError("Could not load the GetInfectedFlowDistance signature");
	}

	PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_Plain);
	g_hGetInfectedFlowDistance = EndPrepSDKCall();
	if (g_hGetInfectedFlowDistance == INVALID_HANDLE)
	{
		ThrowError("Could not prep the GetInfectedFlowDistance function");	
	}

	StartPrepSDKCall(SDKCall_Player);
	if (!PrepSDKCall_SetFromConf(conf, SDKConf_Signature, GAMECONFIG_PLAYER_FLOW))
	{
		ThrowError("Could not load the PlayerGetFlowDistance signature");
	}

	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_Plain);
	g_hGetPlayerFlowDistance = EndPrepSDKCall();
	if (g_hGetPlayerFlowDistance == INVALID_HANDLE)
	{
		ThrowError("Could not prep the PlayerGetFlowDistance function");
	}

	g_bIsModuleSetup = true;
}