/*
 * ============================================================================
 *
 *  Rotoblin
 *
 *  File:			rotoblin-az.sp
 *  Type:			Main
 *  Description:	Contains defines, enums, etc available to anywhere in the 
 *					plugin.
 *	Credits:		Greyscale & rhelgeby for their template "project base"
 *					(http://forums.alliedmods.net/showthread.php?t=117191).
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

// **********************************************
//                 Preprocessor
// **********************************************

#pragma semicolon 1
#define DEBUG_COMMANDS				0
#define R2COMP_LOG					0

// **********************************************
//                   Reference
// **********************************************
#define SERVER_INDEX				0 // The client index of the server
#define FIRST_CLIENT				1 // First valid client index
#define TEAM_SPECTATOR				1
#define TEAM_SURVIVOR				2
#define TEAM_INFECTED				3
#define ZOMBIECLASS_TANK 			5
#define MAX_EDICTS					2048

// Plugin info
#define PLUGIN_FULLNAME			"Rotoblin-AZ"							// Used when printing the plugin name anywhere
#define PLUGIN_SHORTNAME		"rotoblin"							// Shorter version of the full name, used in file paths, and other things
#define PLUGIN_AUTHOR			"Rotoblin Team, HarryPotter"						// Author of the plugin
#define PLUGIN_DESCRIPTION		"A competitive mod for L4D1"			// Description of the plugin
#define PLUGIN_VERSION			"8.4.1"								// Version
#define PLUGIN_URL				"https://github.com/fbef0102/Rotoblin-AZMod"	// URL associated with the project
#define PLUGIN_CVAR_PREFIX		PLUGIN_SHORTNAME				// Prefix for cvars
#define PLUGIN_CMD_PREFIX		PLUGIN_SHORTNAME				// Prefix for cmds
#define PLUGIN_TAG				"Rotoblin"							// Tag for prints and commands
#define	PLUGIN_GAMECONFIG_FILE	PLUGIN_SHORTNAME				// Name of gameconfig file

// **********************************************
//                    Includes
// **********************************************

// Globals
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <l4d_lib>
#include <left4dhooks>
#include <multicolors>
#include <basecomm>

// Helpers
#include "rotoblin/rotoblin.inc/mapinfo.inc"
#include "rotoblin/rotoblin.inc/debug.inc"
#include "rotoblin/rotoblin.inc/eventmanager.inc"
#include "rotoblin/rotoblin.inc/cmdmanager.inc"
#include "rotoblin/rotoblin.inc/tankmanager.inc"
#include "rotoblin/rotoblin.inc/wrappers.inc"
#include "rotoblin/rotoblin.inc/weapon_attributes.inc"

// Modules
#include "rotoblin/rotoblin.2vs2mod.sp"
#include "rotoblin/rotoblin.despawninfected.sp"
#include "rotoblin/rotoblin.ghosttank.sp"
#include "rotoblin/rotoblin.hordecontrol.sp"
#include "rotoblin/rotoblin.exploitfixes.sp"
#include "rotoblin/rotoblin.meleefatigue.sp"
#include "rotoblin/rotoblin.pause.sp"
#include "rotoblin/rotoblin.reportstatus.sp"
#include "rotoblin/rotoblin.pumpswap.sp"
#include "rotoblin/rotoblin.unreservelobby.sp"
#include "rotoblin/rotoblin.limitweapon.sp"
#include "rotoblin/rotoblin.weaponcontrol.sp"
#include "rotoblin/rotoblin.itemcontrol.sp"
#include "rotoblin/rotoblin.healthcontrol.sp"
#include "rotoblin/rotoblin.finalespawn.sp"

// **********************************************
//					  Forwards
// **********************************************

public Plugin:myinfo = 
{
	name = PLUGIN_FULLNAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
}

/**
 * Called on pre plugin start.
 *
 * @param myself		Handle to the plugin.
 * @param late			Whether or not the plugin was loaded "late" (after map load).
 * @param error			Error message buffer in case load failed.
 * @param err_max		Maximum number of characters for error message buffer.
 * @return				APLRes_Success for load success, APLRes_Failure or APLRes_SilentFailure otherwise.
 */
public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	CreateNative("GiveSurAllPills", Native_GiveSurAllPills);
	CreateNative("IsInPause", Native_IsPauseing);
	CreateNative("IsPauseEnable", Native_IsPauseEnable);
	
	/* Check plugin dependencies */
	if (!IsDedicatedServer())
	{
		strcopy(error, err_max, "Plugin only support dedicated servers");
		return APLRes_Failure; // Plugin does not support client listen servers, return
	}

	EngineVersion test = GetEngineVersion();

	if( test != Engine_Left4Dead )
	{
		strcopy(error, err_max, "Plugin only support Left 4 Dead");
		return APLRes_Failure; // Plugin does not support this game, return
	}
	
	return APLRes_Success; // Allow load
}

/**
 * On plugin start extended. Called by the event manager once its done setting up.
 *
 * @noreturn
 */
public OnPluginStartEx()
{
	LoadTranslations("Roto2-AZ_mod.phrases");
	DebugPrintToAll(DEBUG_CHANNEL_GENERAL, "[Main] Setting up...");

	decl String:buffer[128];
	Format(buffer, sizeof(buffer), "%s version", PLUGIN_FULLNAME);
	new Handle:convar = CreateConVarEx("version", PLUGIN_VERSION, buffer, FCVAR_NOTIFY);
	SetConVarString(convar, PLUGIN_VERSION);

	if (GetMaxEntities() > MAX_EDICTS) // Ensure that our MAX_EDICTS const is updated
	{
		ThrowError("Max entities exceeded, %d. Plugin needs a recompile with a updated max entity const, current value %d.", GetMaxEntities(), MAX_EDICTS);
	}

	/* Initial setup of modules after event manager is done setting up.
	 * To disable certain module, simply comment out the line. */

	_H_TankManager_OnPluginStart();
	_H_CommandManager_OnPluginStart();
	
	_HealthControl_OnPluginStart();
	_WeaponControl_OnPluginStart();
	_GhostTank_OnPluginStart();
	_Pause_OnPluginStart();
	_InfExloitFixes_OnPluginStart();
	_DespawnInfected_OnPluginStart();
	_HordeControl_OnPluginStart();
	_2vs2Mod_OnPluginStart();
	_ReportStatus_OnPluginStart();
	_UnreserveLobby_OnPluginStart();
	_PumpSwap_OnPluginStart();
	_LimitHuntingRifl_OnPluginStart();
	_ItemControl_OnPluginStart();
	_MeleeFatigue_OnPluginStart();
	_Weapon_Attributes_OnPluginStart();
	_FinaleSpawn_OnPluginStart();
	// Create cvar for control plugin state
	Format(buffer, sizeof(buffer), "Sets whether %s is enabled", PLUGIN_FULLNAME);
	convar = CreateConVarEx("enable", "0", buffer, FCVAR_NOTIFY);

	if (convar == INVALID_HANDLE) ThrowError("Unable to create main enable cvar!");
	if (GetConVarBool(convar) && !IsDedicatedServer())
	{
		SetConVarBool(convar, false);
		DebugPrintToAll(DEBUG_CHANNEL_GENERAL, "[Main] Unable to enable rotoblin, running on a listen server!");
	}
	else
	{
		SetPluginState(GetConVarBool(convar));
	}

	HookConVarChange(convar, _Main_Enable_CvarChange);
	DebugPrintToAll(DEBUG_CHANNEL_GENERAL, "[Main] Done setting up!");
}

/**
 * Enable cvar changed.
 *
 * @param convar		Handle to the convar that was changed.
 * @param oldValue		String containing the value of the convar before it was changed.
 * @param newValue		String containing the new value of the convar.
 * @noreturn
 */
public _Main_Enable_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	DebugPrintToAll(DEBUG_CHANNEL_GENERAL, "[Main] Enable cvar was changed. Old value %s, new value %s", oldValue, newValue);

	if (GetConVarBool(convar) && !IsDedicatedServer())
	{
		SetConVarBool(convar, false);
		DebugPrintToAll(DEBUG_CHANNEL_GENERAL, "[Main] Unable to enable rotoblin, running on a listen server!");
		PrintToChatAll("[%s] Unable to enable %s! %s only support dedicated servers", PLUGIN_TAG, PLUGIN_FULLNAME, PLUGIN_FULLNAME);
		return;
	}

	SetPluginState(bool:StringToInt(newValue));
}

public OnConfigsExecuted()
{
	_WA_OnConfigsExecuted();
}