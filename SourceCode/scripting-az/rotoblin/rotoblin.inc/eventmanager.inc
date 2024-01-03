/*
 * ============================================================================
 *
 *  Rotoblin
 *
 *	File:			eventmanager.inc
 *	Type:			Helper
 *	Description:	Handles public events for all the modules.
 *
 *	Copyright (C) 2010  Mr. Zero <mrzerodk@gmail.com>
 *  Copyright (C) 2017-2024  Harry <fbef0102@gmail.com>
 *	This program is free software: you can redistribute it and/or modify
 *	it under the terms of the GNU General Public License as published by
 *	the Free Software Foundation, either version 3 of the License, or
 *	(at your option) any later version.
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
#if defined _helper_eventmgr
  #endinput
#endif
#define _helper_eventmgr

// --------------------
//       Public
// --------------------

/*
 * Event types
 * This defines which events is availble for modules to hook.
 */
enum EVENT_TYPE
{
	EVENT_ONPLUGINEND = 0,
	EVENT_ONPLUGINENABLE,
	EVENT_ONPLUGINDISABLE,
	EVENT_ONMAPSTART,
	EVENT_ONMAPEND,
	EVENT_ONCLIENTCONNECTED,
	EVENT_ONCLIENTPUTINSERVER,
	EVENT_ONCLIENTDISCONNECT_POST,
	EVENT_ONCLIENTPOSTADMINCHECK,
	EVENT_ONENTITYCREATED,
	EVENT_ONENTITYDESTROYED,
	EVENT_ONPLAYERRUNCMD
}

#define TOTAL_EVENTS 12

// --------------------
//       Private
// --------------------

static	const	String:	CALL_ON_START[]					= "OnPluginStartEx"; // Function name to look for on plugin start to call, after we are done setting up
new			Handle:	g_hEventForwards[TOTAL_EVENTS];
static			bool:	g_bIsPluginEnabled				= false;


// **********************************************
//					  Forwards
// **********************************************

/**
 * Plugin is starting.
 *
 * @noreturn
 */
public OnPluginStart()
{
	// Create private forwards.
	g_hEventForwards[0]		= CreateForward(ET_Ignore);
	g_hEventForwards[1]		= CreateForward(ET_Ignore);
	g_hEventForwards[2]		= CreateForward(ET_Ignore);
	g_hEventForwards[3]		= CreateForward(ET_Ignore);
	g_hEventForwards[4]		= CreateForward(ET_Ignore);
	g_hEventForwards[5]		= CreateForward(ET_Ignore, Param_Cell);
	g_hEventForwards[6]		= CreateForward(ET_Ignore, Param_Cell);
	g_hEventForwards[7]		= CreateForward(ET_Ignore, Param_Cell);
	g_hEventForwards[8]		= CreateForward(ET_Ignore, Param_Cell);
	g_hEventForwards[9]		= CreateForward(ET_Ignore, Param_Cell, Param_String);
	g_hEventForwards[10]	= CreateForward(ET_Ignore, Param_Cell);
	g_hEventForwards[11]	= CreateForward(ET_Ignore, Param_Cell, Param_CellByRef, Param_CellByRef, Param_Array, Param_Array, Param_CellByRef);

	// Call on plugin start extended if found
	new Function:func = GetFunctionByName(INVALID_HANDLE, CALL_ON_START);
	if (func != INVALID_FUNCTION)
	{
		Call_StartFunction(INVALID_HANDLE, func);
		Call_Finish();
	}
	//g_hEventForwards[0] = CreateForward(ET_Ignore, Param_Float, Param_Float); // args: Float:LowestFlow, Float:HighestFlow
}

/**
 * Plugin is ending.
 *
 * @noreturn
 */
public OnPluginEnd()
{
	Call_StartForward(g_hEventForwards[0]);
	Call_Finish();
}

/**
 * On Map Start.
 *
 * @noreturn
 */
public OnMapStart()
{
	Call_StartForward(g_hEventForwards[3]);
	Call_Finish();
}

/**
 * On Map End.
 *
 * @noreturn
 */
public OnMapEnd()
{
	Call_StartForward(g_hEventForwards[4]);
	Call_Finish();
}

/**
 * A client is connected.
 *
 * @noreturn
 */
public OnClientConnected(client)
{
	Call_StartForward(g_hEventForwards[5]);
	Call_PushCell(client);
	Call_Finish();
}

/**
 * A client is put in server.
 *
 * @noreturn
 */
public OnClientPutInServer(client)
{
	Call_StartForward(g_hEventForwards[6]);
	Call_PushCell(client);
	Call_Finish();
}

/**
 * A client have disconncted.
 *
 * @noreturn
 */
public OnClientDisconnect_Post(client)
{
	Call_StartForward(g_hEventForwards[7]);
	Call_PushCell(client);
	Call_Finish();
}

/**
 * Client have been admin checked.
 *
 * @noreturn
 */
public OnClientPostAdminCheck(client)
{
	Call_StartForward(g_hEventForwards[8]);
	Call_PushCell(client);
	Call_Finish();
}

/**
 * When an entity is created.
 *
 * @param entity		Entity index.
 * @param classname		Classname.
 * @noreturn
 */
public OnEntityCreated(entity, const String:classname[])
{
	if (entity <= MAX_EDICTS && entity > 0 && IsValidEntity(entity)) // thanks atomic >:3
	{
		Call_StartForward(g_hEventForwards[9]);
		Call_PushCell(entity);
		Call_PushString(classname);
		Call_Finish();
	}
}

/**
 * When an entity is destroyed.
 *
 * @param entity		Entity index.
 * @noreturn
 */
public OnEntityDestroyed(entity)
{
	if (entity <= MAX_EDICTS && entity > 0 && IsValidEntity(entity))
	{
		Call_StartForward(g_hEventForwards[10]);
		Call_PushCell(entity);
		Call_Finish();
	}
}

/**
 * Called when a clients movement buttons are being processed.
 *
 * @param client		Index of the client.
 * @param buttons		Copyback buffer containing the current commands (as bitflags - see entity_prop_stocks.inc).
 * @param impulse		Copyback buffer containing the current impulse command.
 * @param vel			Players desired velocity.
 * @param angles		Players desired view angles.
 * @param weapon		Entity index of the new weapon if player switches weapon, 0 otherwise.
 * @return				Plugin_Handled to block the commands from being processed, Plugin_Continue otherwise.
 */
public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	Call_StartForward(g_hEventForwards[11]);
	Call_PushCell(client);
	Call_PushCellRef(buttons);
	Call_PushCellRef(impulse);
	Call_PushArray(vel, 3);
	Call_PushArray(angles, 3);
	Call_PushCellRef(weapon);
	Call_Finish();
	return Plugin_Continue;
}

// **********************************************
//                 Public API
// **********************************************

/**
 * Adds a function to the forward of selected event type.
 * 
 * @param type			The type of event to forward.
 * @param func			The function to add.
 * @return				True on success, false otherwise.
 */
stock bool:HookPublicEvent(const EVENT_TYPE:type, Function:func)
{
	new Handle:fwd = GetEventForward(type);
	if (fwd == INVALID_HANDLE) return false; // Invalid selection

	return AddToForward(fwd, INVALID_HANDLE, func);
}

/**
 * Removes a function from the forward of selected event type.
 * 
 * @param type			The type of event to forward.
 * @param func			The function to remove.
 * @return				True on success, false otherwise.
 */
stock bool:UnhookPublicEvent(const EVENT_TYPE:type, Function:func)
{
	new Handle:fwd = GetEventForward(type);
	if (fwd == INVALID_HANDLE) return false; // Invalid selection

	return RemoveFromForward(fwd, INVALID_HANDLE, func);
}

/**
 * Sets current plugin state.
 * 
 * @param enabled		Whether the plugin is enabled or not.
 * @noreturn
 */
stock SetPluginState(bool:enabled)
{
	if (g_bIsPluginEnabled == enabled) return; // No change in plugin state, return
	g_bIsPluginEnabled = enabled;

	if (enabled)
	{
		Call_StartForward(g_hEventForwards[1]);
		Call_Finish();
	}
	else
	{
		Call_StartForward(g_hEventForwards[2]);
		Call_Finish();
	}
}

/**
 * Returns plugin state.
 * 
 * @return				If plugin is enabled, false otherwise
 */
stock bool:IsPluginEnabled()
{
	return g_bIsPluginEnabled;
}

// **********************************************
//                 Private API
// **********************************************

/**
 * Gets the right forward with matching event.
 * 
 * @param type		    The type of event.
 * @return				Handle of the forward, otherwise invalid handle.
 */
static Handle:GetEventForward(const EVENT_TYPE:type)
{
	for (new i = 0; i < TOTAL_EVENTS; i++)
	{
		if (EVENT_TYPE:i == type) return g_hEventForwards[i];
	}
	return INVALID_HANDLE;
}