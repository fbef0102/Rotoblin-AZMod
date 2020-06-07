/*
 * ============================================================================
 *
 * This file is part of the Rotoblin 2 project.
 *
 *  File:			rotoblin.NoEscapeTank.sp
 *  Type:			Module
 *  Description:	Remove escape tanks on final when vehicle incoming.
 *
 *  Copyright (C) 2012-2015 raziEiL <war4291@mail.ru>
 *  Copyright (C) 2017-2020 Harry <fbef0102@gmail.com>
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

// director_finale_stage_delay работает ли это?!

#define		NET_TAG					"[NoEscTank]"

static 		Handle:g_hEnableNoEscTank, bool:g_bEnableNoEscTank;

new			bool:g_bVehicleIncoming;

_NoEscapeTank_OnPluginStart()
{
	g_hEnableNoEscTank	= CreateConVarEx("no_escape_tank", "1", "Removes tanks which spawn as the rescue vehicle arrives on finales.", _, true, 0.0, true, 1.0);
}

_NET_OnPluginEnabled()
{
	HookEvent("finale_escape_start", NET_ev_FinaleEscStart, EventHookMode_PostNoCopy);
	HookEvent("round_start", 	NET_ev_RoundStart, EventHookMode_PostNoCopy);
	
	HookConVarChange(g_hEnableNoEscTank, _NET_Enable_CvarChange);
	Update_NET_EnableConVar();
}

_NET_OnPluginDisable()
{
	UnhookEvent("finale_escape_start", NET_ev_FinaleEscStart, EventHookMode_PostNoCopy);
	UnhookEvent("round_start", NET_ev_RoundStart, EventHookMode_PostNoCopy);

	UnhookConVarChange(g_hEnableNoEscTank, _NET_Enable_CvarChange);
}

public NET_ev_FinaleEscStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!g_bEnableNoEscTank) return;

	g_bVehicleIncoming = true;
	DebugLog("%s Vehicle incoming but tank spawn is blocked", NET_TAG);
}

public NET_ev_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_bVehicleIncoming = false;
}

// left4downtown
bool:_NET_L4D_OnSpawnTank()
{
	return g_bEnableNoEscTank && g_bVehicleIncoming;
}

public _NET_Enable_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (StrEqual(oldValue, newValue)) return;

	Update_NET_EnableConVar();
}

static Update_NET_EnableConVar()
{
	g_bEnableNoEscTank = GetConVarBool(g_hEnableNoEscTank);
}

stock _NET_CvarDump()
{
	decl bool:iVal;
	if ((iVal = GetConVarBool(g_hEnableNoEscTank)) != g_bEnableNoEscTank)
		DebugLog("%d		|	%d		|	rotoblin_no_escape_tank", iVal, g_bEnableNoEscTank);
}
