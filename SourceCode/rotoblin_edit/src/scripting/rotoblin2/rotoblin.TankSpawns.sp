/*
 * ============================================================================
 *
 * This file is part of the Rotoblin 2 project.
 *
 *  File:			rotoblin.TankSpawns.sp
 *  Type:			Module
 *  Description:	Forces Tank to spawn consistently for both teams. (experimental)
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

#define		TS_TAG					"[TankSpawns]"

static	Handle:g_hTankSpawns, bool:g_bCvarTankSpawns, bool:g_bTankFix, bool:g_bFixed, Float:g_fTankData[2][3], g_iDebugChannel;

_TankSpawns_OnPluginStart()
{
	g_hTankSpawns = CreateConVarEx("tank_spawns", "0", "Forces Tank to spawn consistently for both teams.", _, true, 0.0, true, 1.0);
	g_iDebugChannel = DebugAddChannel(TS_TAG);
}

_TS_OnPluginEnabled()
{
	Update_TS_TankSpawns();
	HookConVarChange(g_hTankSpawns, _TS_TankSpawns_CvarChange);
}

_TS_OnPluginDisabled()
{
	UnhookConVarChange(g_hTankSpawns, _TS_TankSpawns_CvarChange);
}

_TS_OnMapEnd()
{
	g_bTankFix = false;
	g_bFixed = false;
	ClearVec();
}

bool:_TS_L4D_OnSpawnTank(const Float:vector[3], const Float:qangle[3])
{
	if (g_bCvarTankSpawns && !g_bTankFix && !IsFinalMap()){

		if (FirstRound()){

			if (IsVectorNull(g_fTankData[0]))
				CopyVec(vector, qangle);

			DebugPrintToAll(g_iDebugChannel, "round1 tank pos: %.1f %.1f %.1f", vector[0], vector[1], vector[2]);
		}
		else if (!IsVectorNull(g_fTankData[0]) && !IsTankSpawnsMatch(vector)){

			g_bTankFix = true;
			DebugPrintToAll(g_iDebugChannel, "round2 tank pos not matches: %.1f %.1f %.1f", vector[0], vector[1], vector[2]);
		}
	}

	return false;
}

_TS_ev_OnTankSpawn()
{
	if (g_bFixed || !g_bTankFix || !g_bCvarTankSpawns) return;

	g_bFixed = true;

	new iTank = GetTankClient();
	if (iTank){

		TeleportEntity(iTank, g_fTankData[0], g_fTankData[1], NULL_VECTOR);
		DebugPrintToAll(g_iDebugChannel, "teleport '%N' to round1 pos.", iTank);
	}
}

static CopyVec(const Float:vector[3], const Float:qangle[3])
{
	for (new index; index < 3; index++){

		g_fTankData[0][index] = vector[index];
		g_fTankData[1][index] = qangle[index];
	}
}

static ClearVec()
{
	for (new index; index < 3; index++){

		g_fTankData[0][index] = 0.0;
		g_fTankData[1][index] = 0.0;
	}
}

static bool:IsTankSpawnsMatch(const Float:vector[3])
{
	return g_fTankData[0][0] == vector[0] && g_fTankData[0][1] == vector[1] && g_fTankData[0][2] == vector[2];
}

public _TS_TankSpawns_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (!StrEqual(oldValue, newValue))
		Update_TS_TankSpawns();
}

static Update_TS_TankSpawns()
{
	g_bCvarTankSpawns = GetConVarBool(g_hTankSpawns);
}

stock _TS_CvarDump()
{
	decl iVal;
	if (bool:(iVal = GetConVarInt(g_hTankSpawns)) != g_bCvarTankSpawns)
		DebugLog("%d		|	%d		|	rotoblin_tank_spawns", iVal, g_bCvarTankSpawns);
}
