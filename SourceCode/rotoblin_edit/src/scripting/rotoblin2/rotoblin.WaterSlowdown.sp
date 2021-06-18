/*
 * ============================================================================
 *
 * This file is part of the Rotoblin 2 project.
 *
 *  File:			rotoblin.WaterSlowdown.sp
 *  Type:			Module
 *  Description:	Slow down Survivors in water.
 *
 *  Copyright (C) 2012-2015 raziEiL <war4291@mail.ru>
 *  Copyright (C) 2017-2019 Harry <fbef0102@gmail.com>
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
#define		WSD_TAG	"[WaterSlowdown]"
#define		FACTOR		145.0 // 170 mean ~187 in game it's 15% of slowdown, l4d2 coop 115

static  	Handle:g_hWSDEnable, bool:g_bCvarWSDEnable, g_bBarge;

_WaterSlowdown_OnPluginStart()
{
	g_hWSDEnable = CreateConVarEx("water_slowdown", "0", "If set, survivors will walk slower in water.", _, true, 0.0, true, 1.0);
	g_bCvarWSDEnable = GetConVarBool(g_hWSDEnable);
}

_WSD_OnPluginEnabled()
{
	HookConVarChange(g_hWSDEnable, WSD_OnCvarChange_Factor);

	if (g_bLoadLater && g_bCvarWSDEnable)
		_WSD_ToogleHook(true);
}

_WSD_OnPluginDisabled()
{
	UnhookConVarChange(g_hWSDEnable, WSD_OnCvarChange_Factor);

	if (g_bCvarWSDEnable)
		_WSD_ToogleHook(false);
}

_WSD_OnMapStart()
{
	decl String:sMap[32];
	GetCurrentMap(sMap, 32);
	g_bBarge = StrEqual(sMap, "l4d_river02_barge");
}

public WS_ev_PlayerTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (g_bBarge) return;

	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!client) return;

	if (GetEventInt(event, "team") == 2)
		SDKHook(client, SDKHook_PreThinkPost, _WSD_SDKh_PreThinkPost);
	else if (GetEventInt(event, "oldteam") == 2)
		SDKUnhook(client, SDKHook_PreThinkPost, _WSD_SDKh_PreThinkPost);
}

public _WSD_SDKh_PreThinkPost(client)
{
	if (GetEntityFlags(client) & FL_INWATER)
		SetEntPropFloat(client, Prop_Data, "m_flMaxspeed", FACTOR);
}

_WSD_ToogleHook(bool:bHook)
{
	DebugLog("%s %s", WSD_TAG, bHook ? "ENABLED" : "DISABLED");

	for (new client = 1; client <= MaxClients; client++){

		if (!IsClientInGame(client) || GetClientTeam(client) != 2) continue;

		if (bHook)
			SDKHook(client, SDKHook_PreThinkPost, _WSD_SDKh_PreThinkPost);
		else
			SDKUnhook(client, SDKHook_PreThinkPost, _WSD_SDKh_PreThinkPost);
	}

	if (bHook)
		HookEvent("player_team", WS_ev_PlayerTeam);
	else
		UnhookEvent("player_team", WS_ev_PlayerTeam);
}

public WSD_OnCvarChange_Factor(Handle:hHandle, const String:sOldVal[], const String:sNewVal[])
{
	if (StrEqual(sOldVal, sNewVal)) return;
	g_bCvarWSDEnable = GetConVarBool(g_hWSDEnable);

	_WSD_ToogleHook(g_bCvarWSDEnable);
}

stock _WSD_CvarDump()
{
	decl bool:iVal;
	if ((iVal = GetConVarBool(g_hWSDEnable)) != g_bCvarWSDEnable)
		DebugLog("%d		|	%d		|	rotoblin_water_slowdown", iVal, g_bCvarWSDEnable);
}
