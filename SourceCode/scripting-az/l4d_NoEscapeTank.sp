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


#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define		NET_TAG					"[NoEscTank]"

static 		Handle:g_hEnableNoEscTank, bool:g_bEnableNoEscTank;

new			bool:g_bVehicleIncoming;

public Plugin:myinfo = 
{
	name = "L4D Score/Team Manager",
	author = "Harry Potter",
	description = "No Tank Spawn as the rescue vehicle is coming",
	version = "1.0",
	url = "http://forums.alliedmods.net/showthread.php?t=87759"
}

public OnPluginStart()
{
	g_hEnableNoEscTank	= CreateConVar("no_escape_tank", "1", "Removes tanks which spawn as the rescue vehicle arrives on finales.", _, true, 0.0, true, 1.0);
	HookEvent("finale_escape_start", NET_ev_FinaleEscStart, EventHookMode_PostNoCopy);
	HookEvent("round_start", 	NET_ev_RoundStart, EventHookMode_PostNoCopy);
	
	HookConVarChange(g_hEnableNoEscTank, _NET_Enable_CvarChange);
	Update_NET_EnableConVar();
}

public NET_ev_FinaleEscStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	//if(IsTankProhibit()) return;
	if (!g_bEnableNoEscTank) return;

	g_bVehicleIncoming = true;
}

public NET_ev_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_bVehicleIncoming = false;
}

// left4downtown
public Action:L4D_OnSpawnTank(const Float:vector[3], const Float:qangle[3])
{
	if(g_bEnableNoEscTank && g_bVehicleIncoming)
	{
		//PrintToChatAll("Blocking tank spawn...");
		return Plugin_Handled;
	}
	return Plugin_Continue;
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
/*
static bool:IsTankProhibit()//犧牲最後一關
{
	decl String:sMap[64];
	GetCurrentMap(sMap, 64);
	return StrEqual(sMap, "l4d_river03_port");
}*/