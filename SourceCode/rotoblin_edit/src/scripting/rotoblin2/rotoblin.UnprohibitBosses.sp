/*
 * ============================================================================
 *
 * This file is part of the Rotoblin 2 project.
 *
 *  File:			rotoblin.UnprohibitBosses.sp
 *  Type:			Module
 *  Description:	Enable bosses spawning on all maps. (experimental)
 *
 *  Copyright (C) 2012-2015 raziEiL <war4291@mail.ru>
 *  Copyright (C) 2017-2021 Harry <fbef0102@gmail.com>
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

#define INTRO		0
#define REGULAR	1
#define FINAL		2
#define TANK		0
#define WITCH		1
#define MIN		0
#define MAX		1

static Handle:g_hBossUnprohibit, bool:g_bCvarBossUnprohibit, Handle:g_hCvarVsBossChance[3][2], Handle:g_hCvarVsBossFlow[3][2], Float:g_fCvarVsBossChance[3][2], Float:g_fCvarVsBossFlow[3][2];

public _UnprohibitBosses_OnPluginStart()
{
	g_hBossUnprohibit = CreateConVarEx("boss_unprohibit", "0", "Enable bosses spawning on all maps, even through they normally aren't allowed.", _, true, 0.0, true, 1.0);

	g_hCvarVsBossChance[INTRO][TANK] = FindConVar("versus_tank_chance_intro");
	g_hCvarVsBossChance[REGULAR][TANK] = FindConVar("versus_tank_chance");
	g_hCvarVsBossChance[FINAL][TANK] = FindConVar("versus_tank_chance_finale");
	g_hCvarVsBossChance[INTRO][WITCH] = FindConVar("versus_witch_chance_intro");
	g_hCvarVsBossChance[REGULAR][WITCH] = FindConVar("versus_witch_chance");
	g_hCvarVsBossChance[FINAL][WITCH] = FindConVar("versus_witch_chance_finale");
	g_hCvarVsBossFlow[INTRO][MIN]  = FindConVar("versus_boss_flow_min_intro");
	g_hCvarVsBossFlow[INTRO][MAX] = FindConVar("versus_boss_flow_max_intro");
	g_hCvarVsBossFlow[REGULAR][MIN] = FindConVar("versus_boss_flow_min");
	g_hCvarVsBossFlow[REGULAR][MAX] = FindConVar("versus_boss_flow_max");
	g_hCvarVsBossFlow[FINAL][MIN] = FindConVar("versus_boss_flow_min_finale");
	g_hCvarVsBossFlow[FINAL][MAX] = FindConVar("versus_boss_flow_max_finale");
}

_UB_OnPluginEnabled()
{
	Update_UB_BossUnprohibitConVar();
	HookConVarChange(g_hBossUnprohibit, _UB_BossUnprohibit_CvarChange);

	for (new campaign; campaign < 3; campaign++){

		for (new index; index < 2; index++){

			g_fCvarVsBossChance[campaign][index] = GetConVarFloat(g_hCvarVsBossChance[campaign][index]);
			g_fCvarVsBossFlow[campaign][index] = GetConVarFloat(g_hCvarVsBossFlow[campaign][index]);

			HookConVarChange(g_hCvarVsBossChance[campaign][index], _UB_Common_CvarChange);
			HookConVarChange(g_hCvarVsBossFlow[campaign][index], _UB_Common_CvarChange);
		}
	}
}

_UB_OnPluginDisabled()
{
	UnhookConVarChange(g_hBossUnprohibit, _UB_BossUnprohibit_CvarChange);

	for (new campaign; campaign < 3; campaign++){

		for (new index; index < 2; index++){

			UnhookConVarChange(g_hCvarVsBossChance[campaign][index], _UB_Common_CvarChange);
			UnhookConVarChange(g_hCvarVsBossFlow[campaign][index], _UB_Common_CvarChange);
		}
	}
}

_UB_OnMapStart()
{
	if (!g_bCvarBossUnprohibit) return;
	new iCampaign = IsFinalMap() ? FINAL : IsNewMission() ? INTRO : REGULAR;

	if (!IsTankProhibit()){

		new bool:bSpawnTank = IsBossSpawn(iCampaign, true);
		new Float:fTankFlow =  GetRandomBossFlow(iCampaign);
		L4DDirect_SetVSTankToSpawnThisRound(0, bSpawnTank);
		L4DDirect_SetVSTankToSpawnThisRound(1, bSpawnTank);
		L4DDirect_SetVSTankFlowPercent(0, fTankFlow);
		L4DDirect_SetVSTankFlowPercent(1, fTankFlow);
	}

	new bool:bSpawnWitch = IsBossSpawn(iCampaign, false);
	new Float:fWitchFlow = GetRandomBossFlow(iCampaign);
	L4DDirect_SetVSWitchToSpawnThisRound(0, bSpawnWitch);
	L4DDirect_SetVSWitchToSpawnThisRound(1, bSpawnWitch);
	L4DDirect_SetVWitchFlowPercent(0, fWitchFlow);
	L4DDirect_SetVWitchFlowPercent(1, fWitchFlow);
}

static Float:GetRandomBossFlow(iCampaign)
{
	return GetRandomFloat(g_fCvarVsBossFlow[iCampaign][MIN], g_fCvarVsBossFlow[iCampaign][MAX]);
}

static bool:IsBossSpawn(iCampaign, bool:bTank)
{
	return g_fCvarVsBossChance[iCampaign][bTank ? TANK : WITCH] == 1.0;
}

static bool:IsTankProhibit()
{
	decl String:sMap[64];
	GetCurrentMap(sMap, 64);
	return StrEqual(sMap, "l4d_river01_docks") || StrEqual(sMap, "l4d_river03_port");
}

public _UB_Common_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (StrEqual(oldValue, newValue)) return;

	for (new campaign; campaign < 3; campaign++){

		for (new index; index < 2; index++){

			if (g_hCvarVsBossChance[campaign][index] == convar)
				g_fCvarVsBossChance[campaign][index] = GetConVarFloat(convar);
			else if (g_hCvarVsBossFlow[campaign][index] == convar)
				g_fCvarVsBossFlow[campaign][index] = GetConVarFloat(convar);
		}
	}
}

public _UB_BossUnprohibit_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (!StrEqual(oldValue, newValue))
		Update_UB_BossUnprohibitConVar();
}

static Update_UB_BossUnprohibitConVar()
{
	g_bCvarBossUnprohibit = GetConVarBool(g_hBossUnprohibit);
}

stock _UB_CvarDump()
{
	decl iVal;
	if ((iVal = GetConVarInt(g_hBossUnprohibit)) != g_bCvarBossUnprohibit)
		DebugLog("%d		|	%d		|	rotoblin_boss_unprohibit", iVal, g_bCvarBossUnprohibit);
}
