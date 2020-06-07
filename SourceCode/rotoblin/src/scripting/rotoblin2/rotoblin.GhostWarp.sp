/*
 * ============================================================================
 *
 * This file is part of the Rotoblin 2 project.
 *
 *  File:			rotoblin.GhostWarp.sp
 *  Type:			Module
 *  Description:	...
 *  Credits:		Most of credits goes to Confogl (http://code.google.com/p/confogl/)
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

static 	Handle:g_hWarpEnable, bool:g_bWarpEnable, bool:g_bDelay[MAXPLAYERS+1], g_iLastTarget[MAXPLAYERS+1];

_GhostWarp_OnPluginStart()
{
	g_hWarpEnable = CreateConVarEx("ghost_warp", "0", "Sets whether infected ghosts can warp to survivors (mouse 2)", _, true, 0.0, true, 1.0);
}

_GW_OnPluginEnabled()
{
	HookEvent("player_death", GW_ev_PlayeDeath);

	HookConVarChange(g_hWarpEnable, _GW_EnableConVarChange);
	Update_GW_EnableConVars();
}

_GW_OnPluginDisabled()
{
	UnhookEvent("player_death", GW_ev_PlayeDeath);
	UnhookConVarChange(g_hWarpEnable, _GW_EnableConVarChange);
}

public GW_ev_PlayeDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	g_iLastTarget[client] = 0;
}

public _GW_OnPlayerRunCmd(client, &buttons)
{
	if (g_bBlackSpot || !(buttons & IN_ATTACK2) || !g_bWarpEnable || !SurvivorCount || g_bDelay[client] ||
		!IsPlayerAlive(client) || IsFakeClient(client) || GetClientTeam(client) != 3 || !IsPlayerGhost(client)) return false;

	g_bDelay[client] = true;
	CreateTimer(0.35, GW_t_ResetDelay, client);

	GW_WarpToSurvivor(client);
	return true;
}

GW_WarpToSurvivor(client)
{
	if (!SurvivorCount || g_bBlackSpot) return;

	new target = SurvivorIndex[g_iLastTarget[client]];

	if (!target){

		g_iLastTarget[client] = 0;
		GW_WarpToSurvivor(client);
		return;
	}
	if (!IsClientInGame(target)) return;

	// Prevent people from spawning and then warp to survivor
	SetEntProp(client, Prop_Send, "m_ghostSpawnState", 256);

	decl Float:position[3], Float:anglestarget[3];

	GetClientAbsOrigin(target, position);
	GetClientAbsAngles(target, anglestarget);

	TeleportEntity(client, position, anglestarget, NULL_VECTOR);

	if (++g_iLastTarget[client] == SurvivorCount)
		g_iLastTarget[client] = 0;
}

public Action:GW_t_ResetDelay(Handle:timer, any:client)
{
	g_bDelay[client] = false;
}

public _GW_EnableConVarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (StrEqual(oldValue, newValue)) return;

	Update_GW_EnableConVars();
}

static Update_GW_EnableConVars()
{
	g_bWarpEnable = GetConVarBool(g_hWarpEnable);
}

stock _GW_CvarDump()
{
	decl bool:iVal;
	if ((iVal = GetConVarBool(g_hWarpEnable)) != g_bWarpEnable)
		DebugLog("%d		|	%d		|	rotoblin_ghost_warp", iVal, g_bWarpEnable);
}
