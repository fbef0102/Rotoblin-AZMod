/*
 * ============================================================================
 *
 * This file is part of the Rotoblin 2 project.
 *
 *  File:			rotoblin.WitchesTracking.sp
 *  Type:			Module
 *  Description:	Forces the Witch to spawn consistently for both teams.
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

#define		WT_TAG					"[WitchesTracking]"

#define WITCH_TO_CLOSE				300

static	Handle:g_hWitchArray, Handle:g_hMaxWitches, Handle:g_hWitchDistance, Handle:g_hWitchSpawns, bool:g_bCvarWitchSpawns, g_iCvarMaxWithes,
		bool:g_bFirstRound, g_iWitchCount, g_iSpawnedWitches, bool:g_bWipeStage, Handle:g_hWitchFlowArray;

public _WitchTracking_OnPluginStart()
{
	g_hWitchSpawns = CreateConVarEx("witch_spawns", "1", "Forces the Witch to spawn consistently for both teams.", _, true, 0.0, true, 1.0);
	g_hMaxWitches = CreateConVarEx("max_witches", "0", "Maximum number of Witches are allowed to spawn. (0: director settings, > 0: maximum limit to cvar value)", _, true, 0.0);
	g_hWitchDistance = CreateConVarEx("witch_distance", "0", "Allows the director to spawn a witch close to another witch.", _, true, 0.0, true, 1.0);

	g_hWitchArray = CreateArray(3);
	g_hWitchFlowArray = CreateArray();
}

_WT_OnPluginEnabled()
{
	HookConVarChange(g_hMaxWitches,		_WT_MaxWitches_CvarChange);
	HookConVarChange(g_hWitchSpawns,	_WT_WitchSpawns_CvarChange);

	HookEvent("round_start", WT_ev_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("witch_spawn", WT_ev_WitchSpawn);

	HookPublicEvent(EVENT_ONSURVIVORMOVES, WT_OnSurvivorMoves);

	Update_WT_MaxWithesConVar();
	Update_WT_WitchSpawnsConVar();
}

_WT_OnPluginDisabled()
{
	UnhookConVarChange(g_hMaxWitches,	_WT_MaxWitches_CvarChange);
	UnhookConVarChange(g_hWitchSpawns,	_WT_WitchSpawns_CvarChange);

	UnhookEvent("round_start", WT_ev_RoundStart, EventHookMode_PostNoCopy);
	UnhookEvent("witch_spawn", WT_ev_WitchSpawn);

	UnhookPublicEvent(EVENT_ONSURVIVORMOVES, WT_OnSurvivorMoves);

	_WT_OnMapEnd();
}

_WT_OnMapEnd()
{
	g_bFirstRound = false;
	_WT_ClearVars();
}

public WT_ev_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_bFirstRound = !g_bFirstRound;
	g_iWitchCount = 0;

	//DebugLog("%s ==== ROUND %d FIRED ====", WT_TAG, g_bFirstRound);

	if (!g_bFirstRound){

		if (g_bCvarWitchSpawns){

			if (!IsDIModuleEnabled())
				CreateTimer(3.0, WT_t_SpawnWitch);
			else {
				g_bWipeStage = true;
				g_iSpawnedWitches = 0;
			}
		}
		else if (g_iCvarMaxWithes)
			_WT_ClearVars();
	}
}

public WT_OnSurvivorMoves(Float:LowestFlow, Float:HighestFlow)
{
	if (g_bFirstRound || !g_bCvarWitchSpawns || !GetArraySize(g_hWitchFlowArray)) return;

	if (RoundToNearest(HighestFlow) >= GetArrayCell(g_hWitchFlowArray, 0)){

		decl Float:fWitchData[2][3];
		GetArrayArray(g_hWitchArray, 0, fWitchData[0]);
		GetArrayArray(g_hWitchArray, 1, fWitchData[1]);

		UnhookEvent("witch_spawn", WT_ev_WitchSpawn);

		new iEnt = CreateEntityByName("witch");
		TeleportEntity(iEnt, fWitchData[0], fWitchData[1], NULL_VECTOR);
		DispatchSpawn(iEnt);

		HookEvent("witch_spawn", WT_ev_WitchSpawn);

		g_iWitchCount++;
		//DebugLog("%s Restore Witch %d at %f %f %f ", WT_TAG, iEnt, fWitchData[0][0], fWitchData[0][1], fWitchData[0][2]);

		RemoveFromArray(g_hWitchFlowArray, 0);
		RemoveFromArray(g_hWitchArray, 0);
		RemoveFromArray(g_hWitchArray, 0);

		if (!GetArraySize(g_hWitchFlowArray))
			g_bWipeStage = false;
	}
}

public Action:WT_t_SpawnWitch(Handle:timer)
{
	new iArrayLimit = GetArraySize(g_hWitchArray);
	if (!iArrayLimit) return;

	new iEnt = -1;
	while ((iEnt = FindEntityByClassname(iEnt , "witch")) != INVALID_ENT_REFERENCE)
		AcceptEntityInput(iEnt, "Kill");

	g_bWipeStage = true;
	g_iWitchCount = g_iSpawnedWitches = iArrayLimit / 2;

	UnhookEvent("witch_spawn", WT_ev_WitchSpawn);

	decl Float:fWitchData[2][3];
	iEnt = -1;

	for (new i = 0; i < iArrayLimit; i += 2){

		GetArrayArray(g_hWitchArray, i, fWitchData[0]);
		GetArrayArray(g_hWitchArray, i + 1, fWitchData[1]);

		iEnt = CreateEntityByName("witch");
		TeleportEntity(iEnt, fWitchData[0], fWitchData[1], NULL_VECTOR);
		DispatchSpawn(iEnt);

		//DebugLog("%s Restore Witch %d at %f %f %f ", WT_TAG, iEnt, fWitchData[0][0], fWitchData[0][1], fWitchData[0][2]);
	}

	HookEvent("witch_spawn", WT_ev_WitchSpawn);
}

public WT_ev_WitchSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!g_bCvarWitchSpawns && !g_iCvarMaxWithes) return;
	new iEnt = GetEventInt(event, "witchid");

	if (!g_bFirstRound && IsDIModuleEnabled() && g_bWipeStage && g_bCvarWitchSpawns){

		//DebugLog("%s Round 2 Valve Witch %d was removed", WT_TAG, iEnt);
		AcceptEntityInput(iEnt, "Kill");
		return;
	}

	decl Float:fWitchData[2][3];
	GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", fWitchData[0]);

	if (!g_bWipeStage && (IsWitchesTooClose(fWitchData[0]) || (g_iCvarMaxWithes && ++g_iWitchCount > g_iCvarMaxWithes))){

		//DebugLog("%s Round %s Witch %d was removed. Limit is exceeded, or too close! (Limit %d/%d)", WT_TAG, g_bFirstRound ? "1" : "2", iEnt, g_iWitchCount, g_iCvarMaxWithes);
		AcceptEntityInput(iEnt, "Kill");
		return;
	}

	if (!g_bFirstRound){

		if (g_iSpawnedWitches){

			if (--g_iSpawnedWitches <= 0)
				g_bWipeStage = false;

			//DebugLog("%s Round 2 Valve Witch %d was removed %.2f %.2f %.2f (Should be removed: %d)", WT_TAG, iEnt, fWitchData[0][0], fWitchData[0][1], fWitchData[0][2], g_iSpawnedWitches);
			AcceptEntityInput(iEnt, "Kill");
			return;
		}

		//DebugLog("%s Round 2 Dont remove this Witch %d (First team died before this witch was spawn in round1)", WT_TAG, iEnt);
	}
	else {

		GetEntPropVector(iEnt, Prop_Send, "m_angRotation", fWitchData[1]);
		PushArrayArray(g_hWitchArray, fWitchData[0]);
		PushArrayArray(g_hWitchArray, fWitchData[1]);
		PushArrayCell(g_hWitchFlowArray, RoundToNearest(GetHighestSurvFlow(true)));

		//DebugLog("%s Round %s Push Witch %d in array %.2f %.2f %.2f (Total: %d)", WT_TAG, g_bFirstRound ? "1" : "2", iEnt, fWitchData[0][0], fWitchData[0][1], fWitchData[0][2], g_iWitchCount);
	}
}

static bool:IsWitchesTooClose(Float:vOrg[3])
{
	decl iArrayLimit;
	if (!(iArrayLimit = GetArraySize(g_hWitchArray)) || GetConVarBool(g_hWitchDistance))
		return false;

	decl Float:fDataOrg[3];

	for (new i = 0; i < iArrayLimit; i += 2){

		GetArrayArray(g_hWitchArray, i, fDataOrg);

		if ((fDataOrg[0] = GetVectorDistance(vOrg, fDataOrg)) < WITCH_TO_CLOSE){

			//DebugLog("%s Withes to close %.0f!", WT_TAG, fDataOrg[0]);
			return true;
		}
	}

	return false;
}

bool:FirstRound()
{
	return g_bFirstRound;
}

static _WT_ClearVars()
{
	g_bWipeStage = false;
	g_iSpawnedWitches = 0;
	ClearArray(g_hWitchArray);
	ClearArray(g_hWitchFlowArray);
}

public _WT_MaxWitches_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (!StrEqual(oldValue, newValue))
		Update_WT_MaxWithesConVar();
}

public _WT_WitchSpawns_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (!StrEqual(oldValue, newValue))
		Update_WT_WitchSpawnsConVar();
}

static Update_WT_MaxWithesConVar()
{
	g_iCvarMaxWithes = GetConVarInt(g_hMaxWitches);
}

static Update_WT_WitchSpawnsConVar()
{
	g_bCvarWitchSpawns = GetConVarBool(g_hWitchSpawns);
}

stock _WT_CvarDump()
{
	decl iVal;
	if ((iVal = GetConVarInt(g_hMaxWitches)) != g_iCvarMaxWithes)
		//DebugLog("%d		|	%d		|	rotoblin_max_witches", iVal, g_iCvarMaxWithes);
}
