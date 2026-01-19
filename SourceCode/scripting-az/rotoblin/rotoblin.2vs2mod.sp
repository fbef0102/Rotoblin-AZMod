/*
 * ============================================================================
 *
 *  Rotoblin
 *
 *  File:			rotoblin.2vs2mod.sp
 *  Type:			Module
 *  Description:	Provides a few modifications to rotoblin to support 2vs2.
 *
 *  Copyright (C) 2010  Mr. Zero <mrzerodk@gmail.com>
 *  Copyright (C) 2017-2026  Harry <fbef0102@gmail.com>
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

static					g_iDebugChannel			= 0;
static	const	String:	DEBUG_CHANNEL_NAME[]	= "2vs2mod";

static			Handle:	g_bIsModEnabled_Cvar	= INVALID_HANDLE;
static			bool:	g_bIsModEnabled			= false;

// **********************************************
//                   Forwards
// **********************************************

/**
 * Plugin is starting.
 *
 * @noreturn
 */
public _2vs2Mod_OnPluginStart()
{
	HookPublicEvent(EVENT_ONPLUGINENABLE, _2V2_OnPluginEnabled);
	HookPublicEvent(EVENT_ONPLUGINDISABLE, _2V2_OnPluginDisabled);

	g_bIsModEnabled_Cvar = CreateConVarEx("enable_2v2", "0", "If 1, Slay AI Tank after human tank player loses control", FCVAR_NOTIFY);
	if (g_bIsModEnabled_Cvar == INVALID_HANDLE) ThrowError("Unable to create 2vs2mod cvar!");
	g_bIsModEnabled = GetConVarBool(g_bIsModEnabled_Cvar);
	AddConVarToReport(g_bIsModEnabled_Cvar); // Add to report status module

	g_iDebugChannel = DebugAddChannel(DEBUG_CHANNEL_NAME);
	DebugPrintToAllEx("Module is now setup");
}

/**
 * Plugin is now enabled.
 *
 * @noreturn
 */
public _2V2_OnPluginEnabled()
{
	g_bIsModEnabled = GetConVarBool(g_bIsModEnabled_Cvar);
	HookConVarChange(g_bIsModEnabled_Cvar, _2V2_Enable_CvarChange);
	//HookPublicEvent(EVENT_ONCLIENTPUTINSERVER, _2V2_OnClientPutInServer);

	HookEvent("tank_frustrated", OnTankFrustrated, EventHookMode_Post);
	
	DebugPrintToAllEx("Module is now loaded");
}

/**
 * Plugin is now disabled.
 *
 * @noreturn
 */
public _2V2_OnPluginDisabled()
{
	UnhookConVarChange(g_bIsModEnabled_Cvar, _2V2_Enable_CvarChange);

	//UnhookPublicEvent(EVENT_ONCLIENTPUTINSERVER, _2V2_OnClientPutInServer);

	DebugPrintToAllEx("Module is now unloaded");
}

/**
 * Tank was passed.
 *
 * @noreturn
 */
public OnTankFrustrated(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!g_bIsModEnabled) return;
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (!client || !IsClientInGame(client) || IsFakeClient(client)) return;
	
	CreateTimer(0.1, _2V2_TankPassedCheckDelay);	
}

public Action:_2V2_TankPassedCheckDelay(Handle:timer)
{
	if (!g_bIsModEnabled) return;
	
	new i;
	for (i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i)&&IsFakeClient(i) && GetClientTeam(i) == 3 && GetEntProp(i, Prop_Send, "m_zombieClass") == 5 && IsPlayerAlive(i))
		{
			//PrintToChatAll("Forced client %i: \"%N\" to suicide", i, i);
			ForcePlayerSuicide(i);
			CreateTimer(5.0, _2V2_KickInfectedBot, i);
			break;
		}
	}
}

/**
 * A client is put in the server
 *
 * @param client		Client index.
 * @noreturn
 */
/*
public _2V2_OnClientPutInServer(client)
{
	if (!g_bIsModEnabled || !client || !IsFakeClient(client)) return; // Only deal with bots

	DebugPrintToAllEx("Client %i was put in server", client);
	CreateTimer(0.1, _2V2_SlayInfectedBot, client, TIMER_FLAG_NO_MAPCHANGE);
}
*/
/**
 * Called when the slay bot timer interval has elapsed.
 * 
 * @param timer			Handle to the timer object.
 * @param client		Client index to slay.
 * @noreturn
 */
/*
public Action:_2V2_SlayInfectedBot(Handle:timer, any:client)
{
	if (!g_bIsModEnabled || !client || !IsClientInGame(client) || !IsFakeClient(client) || GetClientTeam(client) != 3) return Plugin_Continue;

	if (IsPlayerAlive(client))
	{
		new zombieclass = GetEntProp(client, Prop_Send, "m_zombieClass");
		if(zombieclass == 5) //if is Tank
			return Plugin_Continue;
		
		new hasvictim ;
		if(zombieclass == 1) //if is Smoker
		{
			hasvictim = GetEntPropEnt(client, Prop_Send, "m_tongueVictim");
			if(hasvictim>0) return Plugin_Continue;
		}
		if(zombieclass == 3) //if is Hunter
		{
			hasvictim = GetEntPropEnt(client, Prop_Send, "m_pounceVictim");
			if(hasvictim>0) return Plugin_Continue;
		}
		
		ForcePlayerSuicide(client);
		CreateTimer(1.0, _2V2_KickInfectedBot, client);
	}
	return Plugin_Continue;
}
*/
/**
 * Called when the kick bot timer interval has elapsed.
 * 
 * @param timer			Handle to the timer object.
 * @param client		Client index to kick.
 * @noreturn
 */
public Action:_2V2_KickInfectedBot(Handle:timer, any:client)
{
	if (!client || !IsClientInGame(client) || !IsFakeClient(client)) return;
	DebugPrintToAllEx("Kicked client %i: \"%N\"", client, client);
	KickClient(client, "[%s] Kicked infected bot", PLUGIN_TAG);
}

/**
 * Enable cvar changed.
 *
 * @param convar		Handle to the convar that was changed.
 * @param oldValue		String containing the value of the convar before it was changed.
 * @param newValue		String containing the new value of the convar.
 * @noreturn
 */
public _2V2_Enable_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	DebugPrintToAllEx("Enable cvar was changed. Old value %s, new value %s", oldValue, newValue);
	g_bIsModEnabled = GetConVarBool(g_bIsModEnabled_Cvar);
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