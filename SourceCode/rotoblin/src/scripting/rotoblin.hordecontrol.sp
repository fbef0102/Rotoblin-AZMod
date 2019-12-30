/*
 * ============================================================================
 *
 *  Rotoblin
 *
 *  File:			rotoblin.hordecontrol.sp
 *  Type:			Module
 *  Description:	Removes random horde.
 *
 *  Copyright (C) 2010  Mr. Zero <mrzerodk@gmail.com>
 *  Copyright (C) 2017-2019  Harry <fbef0102@gmail.com>
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

static	const	String:	NO_MOBS_CVAR[]	= "director_no_mobs";
static			Handle:	g_hNoMobsCvar	= INVALID_HANDLE;

// **********************************************
//                   Forwards
// **********************************************

/**
 * Plugin is starting.
 *
 * @noreturn
 */
public _HordeControl_OnPluginStart()
{
	HookPublicEvent(EVENT_ONPLUGINENABLE, _HoC_OnPluginEnabled);
	HookPublicEvent(EVENT_ONPLUGINDISABLE, _HoC_OnPluginDisabled);
}

/**
 * Plugin is now enabled.
 *
 * @noreturn
 */
public _HoC_OnPluginEnabled()
{
	g_hNoMobsCvar = FindConVar(NO_MOBS_CVAR);
	SetConVarBool(g_hNoMobsCvar, true);
	HookConVarChange(g_hNoMobsCvar, _HoC_NoMobs_CvarChange);
}

/**
 * Plugin is now disabled.
 *
 * @noreturn
 */
public _HoC_OnPluginDisabled()
{
	UnhookConVarChange(g_hNoMobsCvar, _HoC_NoMobs_CvarChange);
	SetConVarBool(g_hNoMobsCvar, false);
	g_hNoMobsCvar = INVALID_HANDLE;
}

/**
 * No mobs cvar changed.
 *
 * @param convar		Handle to the convar that was changed.
 * @param oldValue		String containing the value of the convar before it was changed.
 * @param newValue		String containing the new value of the convar.
 * @noreturn
 */
public _HoC_NoMobs_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	SetConVarBool(g_hNoMobsCvar, true);
}