/*
 * ============================================================================
 *
 *  Original modified Rotoblin module
 *
 *  File:			rotoblin.ItemControl.sp
 *  Type:			Module
 *  Description:	...
 *
 *  Copyright (C) 2012-2015  raziEiL <war4291@mail.ru>
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

#define			IC_TAG		"[IteamControl]"

#define GASCAN_MODEL			"models/props_junk/gascan001a.mdl"
#define PROPANE_MODEL		"models/props_junk/propanecanister001a.mdl"
#define OXYGEN_MODEL			"models/props_equipment/oxygentank01.mdl"

#define WEAPINDEX_MOLOTOV		0
#define WEAPINDEX_PIPEBOMB		1
#define WEAPINDEX_PILLS			2

#define MAX_ITEMS					3

#define WEAPINDEX_HUNTINGRIFLE	4
#define WEAPINDEX_PISTOL			5

static const String:g_sSpawnName[MAX_ITEMS][] =
{
	"weapon_molotov_spawn",
	"weapon_pipe_bomb_spawn",
	"weapon_pain_pills_spawn"
};

static const String:g_sName[MAX_ITEMS][] =
{
	"molotov",
	"pipe bomb",
	"pain pills"
};

static	Handle:g_hItemArray[MAX_ITEMS], Handle:g_hItem[MAX_ITEMS], Handle:g_hDensiny[MAX_ITEMS], g_iCvarItem[MAX_ITEMS], Handle:g_hRemoveCannisters, Handle:g_hRemoveBarrels,
		Handle:g_hRemoveHuntingRiffle, Handle:g_hAlterSpawningLogic, bool:g_bCvarRemoveCannisters, bool:g_bCvarRemoveBarrels, g_iCvarHuntingRiffle, Handle:g_hRemoveDualPistols,
		bool:g_bCvarRemoveDualPistols, g_iLimit[MAX_ITEMS], g_iPickUp[MAX_ITEMS], bool:g_bAlterSpawningLogic, Handle:g_hClusterCount, Handle:g_hItemsSpawns, g_iCvarItemsSpawns,
		Handle:g_hMolotovFlowSpawn, bool:g_bCvarMolotovFlowSpawn, Handle:g_hVSBossBuffer, Float:g_fCvarVSBossBuffer;

_ItemControl_OnPluginStart()
{
	g_hDensiny[WEAPINDEX_MOLOTOV]	= 	FindConVar("director_molotov_density");
	g_hDensiny[WEAPINDEX_PIPEBOMB]	= 	FindConVar("director_pipe_bomb_density");
	g_hDensiny[WEAPINDEX_PILLS]		= 	FindConVar("director_pain_pill_density");
	g_hClusterCount						=	FindConVar("director_finale_item_cluster_count");
	g_hVSBossBuffer						=	FindConVar("versus_boss_buffer");

	g_hItem[WEAPINDEX_MOLOTOV] 		=	CreateConVarEx("molotov_limit",				"0",	"Limits the number of molotovs on each map outside of the safe room. (-1: remove all, 0: director settings, > 0: limit to cvar value)", _, true, -1.0);
	g_hItem[WEAPINDEX_PIPEBOMB] 		=	CreateConVarEx("pipebomb_limit",			"0",	"Limits the number of pipe-bombs on each map outside of the safe room. (-1: remove all, 0: director settings, > 0: limit to cvar value)", _, true, -1.0);
	g_hItem[WEAPINDEX_PILLS]			=	CreateConVarEx("pills_limit",				"0",	"Limits the number of pills on each map outside of the safe room. (-1: remove all, 0: director settings, > 0: limit to cvar value)", _, true, -1.0);
	g_hRemoveCannisters 				=	CreateConVarEx("remove_cannisters",			"0",	"Removes all cannisters (gascan, propane and oxygen)", _, true, 0.0, true, 1.0);
	g_hRemoveBarrels 					=	CreateConVarEx("remove_explosive_barrels",	"0", 	"Removes all explosive barrels.", _, true, 0.0, true, 1.0);
	g_hRemoveHuntingRiffle			=	CreateConVarEx("remove_huntingrifle", 		"0", 	"Removes all hunting rifles from start saferooms. (-1: on each map, 0: director settings, 1: only on final)", _, true, -1.0, true, 1.0);
	g_hRemoveDualPistols				=	CreateConVarEx("remove_pistols",			"0", 	"Removes all pistols on each map, prevents the use of double pistols. (0: disable, 1: enable)", _, true, 0.0, true, 1.0);
	g_hAlterSpawningLogic				=	CreateConVarEx("spawning_logic",			"0", 	"Enables alternative spawning logic for items. More items on a map, but only a limited number of them can be picked up", _, true, 0.0, true, 1.0);
	g_hItemsSpawns						=	CreateConVarEx("item_spawns",				"14", 	"Forces items to spawn consistently for both teams. Flag (add together): 0=disable, 2=molotov, 4=pipe-bomb, 8=pills, 14=all", _, true, 0.0);
	g_hMolotovFlowSpawn				=	CreateConVarEx("molotov_before_tank",		"0", 	"Sets whether (If possible) a molotov will spawn on the map before the Tank spawns.", _, true, 0.0, true, 1.0);

	IC_WipeArray(false);
}

_IC_OnPluginEnabled()
{
	HookEvent("round_start", IC_ev_RoundStart, EventHookMode_PostNoCopy);

	HookConVarChange(g_hItem[WEAPINDEX_MOLOTOV],		IC_OnCvarChange_MolotovLimit);
	HookConVarChange(g_hItem[WEAPINDEX_PIPEBOMB],	IC_OnCvarChange_PipeBombLimit);
	HookConVarChange(g_hItem[WEAPINDEX_PILLS],		IC_OnCvarChange_PainPillsLimit);
	HookConVarChange(g_hRemoveCannisters,				IC_OnCvarChange_RemoveCannisters);
	HookConVarChange(g_hRemoveBarrels,					IC_OnCvarChange_RemoveBarrels);
	HookConVarChange(g_hRemoveHuntingRiffle,			IC_OnCvarChange_RemoveHuntingRiffle);
	HookConVarChange(g_hRemoveDualPistols,			IC_OnCvarChange_RemoveDualPistols);
	HookConVarChange(g_hAlterSpawningLogic,			IC_OnCvarChange_AlterSpawningLogic);
	HookConVarChange(g_hItemsSpawns,					IC_OnCvarChange_ItemsSpawns);
	HookConVarChange(g_hMolotovFlowSpawn,				IC_OnCvarChange_MolotovFlowSpawn);
	HookConVarChange(g_hVSBossBuffer,					IC_OnCvarChange_VSBossBuffer);

	GetCvars();
}

_IC_OnPluginDisabled()
{
	UnhookEvent("round_start", IC_ev_RoundStart, EventHookMode_PostNoCopy);

	UnhookConVarChange(g_hItem[WEAPINDEX_MOLOTOV],	IC_OnCvarChange_MolotovLimit);
	UnhookConVarChange(g_hItem[WEAPINDEX_PIPEBOMB],	IC_OnCvarChange_PipeBombLimit);
	UnhookConVarChange(g_hItem[WEAPINDEX_PILLS],		IC_OnCvarChange_PainPillsLimit);
	UnhookConVarChange(g_hRemoveCannisters,			IC_OnCvarChange_RemoveCannisters);
	UnhookConVarChange(g_hRemoveBarrels,				IC_OnCvarChange_RemoveBarrels);
	UnhookConVarChange(g_hRemoveHuntingRiffle,		IC_OnCvarChange_RemoveHuntingRiffle);
	UnhookConVarChange(g_hRemoveDualPistols,			IC_OnCvarChange_RemoveDualPistols);
	UnhookConVarChange(g_hAlterSpawningLogic,		IC_OnCvarChange_AlterSpawningLogic);
	UnhookConVarChange(g_hItemsSpawns,					IC_OnCvarChange_ItemsSpawns);
	UnhookConVarChange(g_hMolotovFlowSpawn,			IC_OnCvarChange_MolotovFlowSpawn);
	UnhookConVarChange(g_hVSBossBuffer,				IC_OnCvarChange_VSBossBuffer);

	SetDirectorSettings(g_hDensiny[WEAPINDEX_MOLOTOV],		0);
	SetDirectorSettings(g_hDensiny[WEAPINDEX_PIPEBOMB],	0);
	SetDirectorSettings(g_hDensiny[WEAPINDEX_PILLS],		0);
	AddMoreClusters(0);

	IC_WipeArray(true);
}

_IC_OnMapEnd()
{
	IC_WipeArray(true);
}

static IC_WipeArray(bool:bWipe)
{
	for (new INDEX; INDEX < MAX_ITEMS; INDEX++){

		if (bWipe)
			ClearArray(g_hItemArray[INDEX]);
		else
			g_hItemArray[INDEX] = CreateArray(3);

		g_iPickUp[INDEX] = 0;
	}
}

public IC_ev_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	CreateTimer(0.6, IC_t_RoundStartDelay);
}

public Action:IC_t_RoundStartDelay(Handle:timer)
{
	DebugLog("%s All exploves props %s removed", IC_TAG, g_bCvarRemoveCannisters ? "were" : "will not be");
	IC_PushAndRandomizeItems();
}

static IC_PushAndRandomizeItems()
{
	decl String:sClass[64], iWeapIndex, Float:vOrg[3];

	new bool:bFirstRound = FirstRound(), iMaxEnt = GetMaxEntities(), iCount[MAX_ITEMS];

	DebugLog("%s STEP #1 (%s)", IC_TAG, bFirstRound ? "Trying to push items in array" : "Keep item spawns the same on both rounds if we need");

	for (new iEnt = MaxClients; iEnt < iMaxEnt; iEnt++){

		if (!IsValidEntity(iEnt)) continue;

		GetEntityClassname(iEnt, sClass, 64);

		if (IsWeaponSpawn(sClass)){

			if (ItemCountFix(iEnt, (iWeapIndex = WeapIDtoIndex(iEnt))) == NULL) continue;

			switch (iWeapIndex){

				case WEAPINDEX_PILLS:{

					if (!IsEntOutSideSafeRoomEx(iEnt)){

						DebugLog("%s class %s, ent = %d - skipped (item in safe room)", IC_TAG, sClass, iEnt);
						continue;
					}
				}
				case WEAPINDEX_HUNTINGRIFLE:{

					if (IsHuntingRiffle(iEnt)){

						DebugLog("%s class %s, ent = %d - killed!", IC_TAG, sClass, iEnt);
						SafelyRemoveEdict(iEnt);
					}
					continue;
				}
				case WEAPINDEX_PISTOL:{

					if (g_bCvarRemoveDualPistols){

						DebugLog("%s class %s, ent = %d - killed!", IC_TAG, sClass, iEnt);
						SafelyRemoveEdict(iEnt);
					}
					continue;
				}
			}

			if (g_iCvarItem[iWeapIndex] > 0){

				GetEntityOrg(iEnt, vOrg);

				DebugLog("%s class %s, ent = %d, vec = %.1f %.1f %.1f", IC_TAG, sClass, iEnt, vOrg[0], vOrg[1], vOrg[2]);

				if (bFirstRound || !(g_iCvarItemsSpawns & (2 << iWeapIndex))){

					if (IsVectorNull(vOrg)){

						DebugLog("%s  - skipped: vector is null", IC_TAG);
						continue;
					}

					DebugLog("%s  - successfully pushed!", IC_TAG);
					PushArrayArray(g_hItemArray[iWeapIndex], vOrg);
					iCount[iWeapIndex]++;
				}
				else {

					DebugLog("%s  - removed: because we need", IC_TAG);
					SafelyRemoveEdict(iEnt);
					continue;
				}
			}
			else if (g_iCvarItem[iWeapIndex]){

				DebugLog("%s class %s, ent = %d - killed!", IC_TAG, sClass, iEnt);
				SafelyRemoveEdict(iEnt);
			}
		}
		else if (IsExplovesProps(iEnt, sClass) || IsExplovesBarrel(sClass)){

			DebugLog("%s class %s, ent = %d - killed!", IC_TAG, sClass, iEnt);
			SafelyRemoveEdict(iEnt);
		}
	}

	DebugLog("%s STEP #2", IC_TAG);

	for (new INDEX = 0; INDEX < MAX_ITEMS; INDEX++){

		// Is same coordinates enabled for this item?
		iWeapIndex = g_iCvarItemsSpawns & (2 << INDEX);

		if (!bFirstRound && iWeapIndex){

			DebugLog("%s item to restore: %s (%d) %s", IC_TAG, g_sName[INDEX], GetArraySize(g_hItemArray[INDEX]), iWeapIndex ? "keep in both round" : "");
			IC_CreateMissingItem(g_hItemArray[INDEX],	 GetArraySize(g_hItemArray[INDEX]), g_sSpawnName[INDEX]);
			continue;
		}

		DebugLog("%s radomize this item: %s", IC_TAG, g_sName[INDEX]);
		IC_RadomizeItems(g_hItemArray[INDEX], g_iCvarItem[INDEX], g_sSpawnName[INDEX], INDEX == WEAPINDEX_PILLS ? true : false, bool:iWeapIndex, INDEX == WEAPINDEX_MOLOTOV);
	}

	DebugLog("%s Completed!", IC_TAG);
}

static WeapIDtoIndex(iEnt)
{
	switch (GetEntProp(iEnt, Prop_Send, "m_weaponID")){

		case WEAPID_MOLOTOV:
			return WEAPINDEX_MOLOTOV;
		case WEAPID_PIPEBOMB:
			return WEAPINDEX_PIPEBOMB;
		case WEAPID_PAINPILLS:
			return WEAPINDEX_PILLS;
		case WEAPID_HUNTINGRIFLE:
			return WEAPINDEX_HUNTINGRIFLE;
		case WEAPID_PISTOL:
			return WEAPINDEX_PISTOL;
	}

	return NULL;
}

static ItemCountFix(iEnt, iWeapIndex)
{
	if (iWeapIndex != NULL && iWeapIndex <= WEAPINDEX_PILLS)
		DispatchKeyValue(iEnt, "count", "1");

	return iWeapIndex;
}

static IC_RadomizeItems(&Handle:hArray, iCvar, const String:sClassName[], bool:bPills, bool:bClone, bool:bFlowSpawn=false)
{
	if (!iCvar) return;

	decl iArraySize;

	if ((iArraySize = GetArraySize(hArray)) <= 1){

		if (iArraySize == 1)
			DebugLog("%s  - 1/%d %s saved!", IC_TAG, iCvar, sClassName);
		else
			DebugLog("%s  - array is empty", IC_TAG);
		return;
	}

	if (iArraySize < iCvar)
		iCvar = iArraySize;

	decl iVal, Float:vOrg[3];
	new iCount, Handle:hRandomItemArray = CreateArray(3);

	// l4d direct feature
	if (bFlowSpawn && iCvar == 1 && g_bCvarMolotovFlowSpawn){

		bFlowSpawn = false;

		if (L4DDirect_GetVSTankToSpawnThisRound(!FirstRound())){

			new Float:fHighestFlow = (L4DDirect_GetVSTankFlowPercent(!FirstRound()) * L4DDirect_GetMapMaxFlowDistance()) - (g_fCvarVSBossBuffer / 2);
			DebugLog("%s  - @L4DDirect: trying to keep molotov before tank spawn. tank flow %f (units)", IC_TAG, fHighestFlow);

			if (fHighestFlow > 0){

				decl Float:fItemFlow;
				new Handle:hMoloArray = CloneArray(hArray), iMoloArraySize = iArraySize;

				while (iCount < iArraySize){

					iVal = GetRandomInt(0, iMoloArraySize - 1);
					GetArrayArray(hMoloArray, iVal, vOrg);

					fItemFlow = L4DDirect_GetTerrorNavAreaFlow(L4DDirect_GetTerrorNavArea(vOrg));
					if (!fItemFlow)
						fItemFlow = L4DDirect_GetTerrorNavAreaFlow(L4DDirect_GetNearestNavArea(vOrg));

					if (fItemFlow && fItemFlow < fHighestFlow){

						bFlowSpawn = true;
						PushArrayArray(hRandomItemArray, vOrg);
						DebugLog("%s  - @L4DDirect: keep this item! molotov flow location %f (units)", IC_TAG, fItemFlow);
					}
					else
						DebugLog("%s  - @L4DDirect: molotov flow location %f (units)", IC_TAG, fItemFlow);

					RemoveFromArray(hMoloArray, iVal);
					iMoloArraySize--;
					iCount++;
				}
				if (bFlowSpawn){

					ClearArray(hArray);
					hArray = CloneArray(hRandomItemArray);
					iArraySize = GetArraySize(hRandomItemArray);
					ClearArray(hRandomItemArray);
				}
				iCount = 0;
				CloseHandle(hMoloArray);
			}
			DebugLog("%s  - @L4DDirect: done", IC_TAG);
		}
	}

	while (iCount != iCvar){

		iVal = GetRandomInt(0, iArraySize - 1);

		GetArrayArray(hArray, iVal, vOrg);
		PushArrayArray(hRandomItemArray, vOrg);
		RemoveFromArray(hArray, iVal);

		iArraySize--;
		iCount++;
	}

	iCount = 0;
	iArraySize = GetArraySize(hRandomItemArray);

	new iEnt = -1, bool:bSaveMe;
	while ((iEnt = FindEntityByClassname(iEnt, sClassName)) != INVALID_ENT_REFERENCE){

		GetEntityOrg(iEnt, vOrg);

		if (bPills && !IsEntOutSideSafeRoom(vOrg)) continue;

		bSaveMe = false;

		if (ComapreVectors(vOrg, iArraySize, hRandomItemArray)){

			bSaveMe = true;
			iCount++;
		}

		DebugLog("%s  - %s ent = %d, vec = %.1f %.1f %.1f - %s", IC_TAG, sClassName, iEnt, vOrg[0], vOrg[1], vOrg[2], bSaveMe ? "saved" : "killed");

		if (!bSaveMe)
			SafelyRemoveEdict(iEnt);
	}

	ClearArray(hArray);
	if (bClone) hArray = CloneArray(hRandomItemArray);
	CloseHandle(hRandomItemArray);

	DebugLog("%s    - %d/%d %s saved!", IC_TAG, iCount, iCvar, sClassName);
}

static IC_CreateMissingItem(Handle:hArray, iCount, const String:sClassName[])
{
	if (!iCount) return;

	static Float:vOrg[3], iEnt;

	while (iCount != 0){

		GetArrayArray(hArray, 0, vOrg);
		RemoveFromArray(hArray, 0);

		iEnt = CreateEntityByName(sClassName);
		DispatchKeyValue(iEnt, "spawnflags", "0");
		DispatchKeyValue(iEnt, "solid", "6");
		DispatchKeyValue(iEnt, "disableshadows", "1");
		DispatchKeyValue(iEnt, "count", "1");
		TeleportEntity(iEnt, vOrg, NULL_VECTOR, NULL_VECTOR);
		DispatchSpawn(iEnt);

		DebugLog("%s  - done (%d lost)! class %s, ent = %d, vec = %.1f %.1f %.1f", IC_TAG, iCount - 1, sClassName, iEnt, vOrg[0], vOrg[1], vOrg[2]);
		iCount--;
	}
}

public Action:IC_ev_SpawnerGiveItem(Handle:event, const String:name[], bool:dontBroadcast)
{
	new iItem = GetEventInt(event, "spawner");

	decl iWeapIndex;
	if ((iWeapIndex = WeapIDtoIndex(iItem)) == NULL || iWeapIndex > MAX_ITEMS || (iWeapIndex == WEAPINDEX_PILLS && !IsEntOutSideSafeRoomEx(iItem))) return;

	if (++g_iPickUp[iWeapIndex] == g_iLimit[iWeapIndex]){

		DebugLog("%s %s picked up %d/%d", IC_TAG, g_sSpawnName[iWeapIndex], g_iPickUp[iWeapIndex], g_iLimit[iWeapIndex]);
		PrintToChatAll("%s Survivor team has the reached %s limit", MAIN_TAG, g_sName[iWeapIndex]);

		new iEnt = -1;
		while ((iEnt = FindEntityByClassname(iEnt, g_sSpawnName[iWeapIndex])) != INVALID_ENT_REFERENCE)
			if (/* удаляем все бомбы или молотовы */iWeapIndex < 2 || /* не трогаем таблетки в убежищах */IsEntOutSideSafeRoomEx(iEnt))
				SafelyRemoveEdict(iEnt);
	}
}

static bool:ComapreVectors(Float:vVectorA[3], iArraySize, Handle:hArray)
{
	static Float:vVectorB[3];

	for (new i; i < iArraySize; i++){

		GetArrayArray(hArray, i, vVectorB);

		if (IsVectorsMatch(vVectorA, vVectorB))
			return true;
	}
	return false;
}

static bool:IsExplovesProps(iEnt, const String:sClass[])
{
	if (g_bCvarRemoveCannisters && StrEqual(sClass, "prop_physics")){

		static String:sModelName[64];
		GetEntPropString(iEnt, Prop_Data, "m_ModelName", sModelName, 64);

		return	strcmp(sModelName, GASCAN_MODEL) == 0 || strcmp(sModelName, PROPANE_MODEL) == 0 ||
				strcmp(sModelName, OXYGEN_MODEL) == 0;
	}

	return false;
}

static bool:IsExplovesBarrel(const String:sClass[])
{
	return g_bCvarRemoveBarrels && StrEqual(sClass, "prop_fuel_barrel");
}

static bool:IsHuntingRiffle(iEnt)
{
	if (!g_iCvarHuntingRiffle) return false;

	if (g_iCvarHuntingRiffle == -1)
		return IsEntInStartSafeRoomEx(iEnt);
	else
		return g_Public_bIsFinalMap && IsEntInStartSafeRoomEx(iEnt);
}

SetDirectorSettings(Handle:hCvar, iVal)
{
	switch (iVal){

		case -1:
			SetConVarInt(hCvar, 0);
		case 0:
			ResetConVar(hCvar);
		default:
			SetConVarInt(hCvar, 10);
	}
}

static AddMoreClusters(iVal)
{
	if (iVal > 0)
		SetConVarInt(g_hClusterCount, 20);
	else
		ResetConVar(g_hClusterCount);
}

CheckSpawningLogic(&iVal, iWeapIndex)
{
	if (g_bAlterSpawningLogic && iVal > 0){

		g_iLimit[iWeapIndex] = iVal;

		new x = 6 - iVal;
		if (x > 0)
			iVal += x;
	}
}

public IC_OnCvarChange_MolotovLimit(Handle:convar, const String:oldValue[], const String:newValue[])
{
	GetConVarMolotovLimit();
}

public IC_OnCvarChange_PipeBombLimit(Handle:convar, const String:oldValue[], const String:newValue[])
{
	GetConVarPipeBombLimit();
}

public IC_OnCvarChange_PainPillsLimit(Handle:convar, const String:oldValue[], const String:newValue[])
{
	GetConVarPainPillsbLimit();
}

public IC_OnCvarChange_RemoveCannisters(Handle:convar, const String:oldValue[], const String:newValue[])
{
	GetConVarEnableCannisters();
}

public IC_OnCvarChange_RemoveBarrels(Handle:convar, const String:oldValue[], const String:newValue[])
{
	GetConVarEnableBarrrels();
}

public IC_OnCvarChange_RemoveHuntingRiffle(Handle:convar, const String:oldValue[], const String:newValue[])
{
	GetConVarRemoveHuntingRiffle();
}

public IC_OnCvarChange_RemoveDualPistols(Handle:convar, const String:oldValue[], const String:newValue[])
{
	GetConVarRemoveDualPistols();
}

public IC_OnCvarChange_ItemsSpawns(Handle:convar, const String:oldValue[], const String:newValue[])
{
	GetConVarItemsSpawns();
}

public IC_OnCvarChange_MolotovFlowSpawn(Handle:convar, const String:oldValue[], const String:newValue[])
{
	GetConVarMolotovFlowSpawn();
}

public IC_OnCvarChange_VSBossBuffer(Handle:convar, const String:oldValue[], const String:newValue[])
{
	GetConVarVSBossBuffer();
}

static bool:g_bHook;

public IC_OnCvarChange_AlterSpawningLogic(Handle:convar, const String:oldValue[], const String:newValue[])
{
	GetConVarAlterSpawningLogic();

	if (StrEqual(oldValue, newValue)) return;

	if (StringToInt(newValue) && !g_bHook){

		g_bHook = true;
		DebugLog("%s Alternative spawning logic enabled", IC_TAG);
		HookEvent("spawner_give_item", IC_ev_SpawnerGiveItem);
	}
	else if (g_bHook){

		g_bHook = false;
		DebugLog("%s Alternative spawning logic disabled", IC_TAG);
		UnhookEvent("spawner_give_item", IC_ev_SpawnerGiveItem);
	}
}

static GetConVarMolotovLimit()
{
	g_iCvarItem[WEAPINDEX_MOLOTOV] = GetConVarInt(g_hItem[WEAPINDEX_MOLOTOV]);
	SetDirectorSettings(g_hDensiny[WEAPINDEX_MOLOTOV], g_iCvarItem[WEAPINDEX_MOLOTOV]);

	CheckSpawningLogic(g_iCvarItem[WEAPINDEX_MOLOTOV], WEAPINDEX_MOLOTOV);
	AddMoreClusters(g_iCvarItem[WEAPINDEX_MOLOTOV]);
}

static GetConVarPipeBombLimit()
{
	g_iCvarItem[WEAPINDEX_PIPEBOMB] = GetConVarInt(g_hItem[WEAPINDEX_PIPEBOMB]);
	SetDirectorSettings(g_hDensiny[WEAPINDEX_PIPEBOMB], g_iCvarItem[WEAPINDEX_PIPEBOMB]);

	CheckSpawningLogic(g_iCvarItem[WEAPINDEX_PIPEBOMB], WEAPINDEX_PIPEBOMB);
	AddMoreClusters(g_iCvarItem[WEAPINDEX_PIPEBOMB]);
}

static GetConVarPainPillsbLimit()
{
	g_iCvarItem[WEAPINDEX_PILLS] = GetConVarInt(g_hItem[WEAPINDEX_PILLS]);
	SetDirectorSettings(g_hDensiny[WEAPINDEX_PILLS], g_iCvarItem[WEAPINDEX_PILLS]);

	CheckSpawningLogic(g_iCvarItem[WEAPINDEX_PILLS], WEAPINDEX_PILLS);
}

static GetConVarEnableCannisters()
{
	g_bCvarRemoveCannisters = GetConVarBool(g_hRemoveCannisters);
}

static GetConVarEnableBarrrels()
{
	g_bCvarRemoveBarrels = GetConVarBool(g_hRemoveBarrels);
}

static GetConVarRemoveHuntingRiffle()
{
	g_iCvarHuntingRiffle = GetConVarInt(g_hRemoveHuntingRiffle);
}

static GetConVarRemoveDualPistols()
{
	g_bCvarRemoveDualPistols = GetConVarBool(g_hRemoveDualPistols);
}

static GetConVarAlterSpawningLogic()
{
	g_bAlterSpawningLogic = GetConVarBool(g_hAlterSpawningLogic);
}

static GetConVarItemsSpawns()
{
	g_iCvarItemsSpawns = GetConVarInt(g_hItemsSpawns);
}

static GetConVarMolotovFlowSpawn()
{
	g_bCvarMolotovFlowSpawn = GetConVarBool(g_hMolotovFlowSpawn);
}

static GetConVarVSBossBuffer()
{
	g_fCvarVSBossBuffer = GetConVarFloat(g_hVSBossBuffer);
}

static GetCvars()
{
	GetConVarMolotovLimit();
	GetConVarPipeBombLimit();
	GetConVarPainPillsbLimit();
	GetConVarEnableCannisters();
	GetConVarEnableBarrrels();
	GetConVarRemoveHuntingRiffle();
	GetConVarRemoveDualPistols();
	GetConVarAlterSpawningLogic();
	GetConVarItemsSpawns();
	GetConVarMolotovFlowSpawn();
	GetConVarVSBossBuffer();
}

stock _IC_CvarDump()
{
	decl iVal;
	if ((iVal = GetConVarInt(g_hItem[WEAPINDEX_MOLOTOV])) != g_iCvarItem[WEAPINDEX_MOLOTOV] && !g_bAlterSpawningLogic)
		DebugLog("%d		|	%d		|	rotoblin_molotov_limit", iVal, g_iCvarItem[WEAPINDEX_MOLOTOV]);
	if ((iVal = GetConVarInt(g_hItem[WEAPINDEX_PIPEBOMB])) != g_iCvarItem[WEAPINDEX_PIPEBOMB] && !g_bAlterSpawningLogic)
		DebugLog("%d		|	%d		|	rotoblin_pipebomb_limit", iVal, g_iCvarItem[WEAPINDEX_PIPEBOMB]);
	if ((iVal = GetConVarInt(g_hItem[WEAPINDEX_PILLS])) != g_iCvarItem[WEAPINDEX_PILLS] && !g_bAlterSpawningLogic)
		DebugLog("%d		|	%d		|	rotoblin_pills_limit", iVal, g_iCvarItem[WEAPINDEX_PILLS]);
	if (bool:(iVal = GetConVarBool(g_hRemoveCannisters)) != g_bCvarRemoveCannisters)
		DebugLog("%d		|	%d		|	rotoblin_remove_cannisters", iVal, g_bCvarRemoveCannisters);
	if (bool:(iVal = GetConVarBool(g_hRemoveBarrels)) != g_bCvarRemoveBarrels)
		DebugLog("%d		|	%d		|	rotoblin_remove_explosive_barrels", iVal, g_bCvarRemoveBarrels);
	if ((iVal = GetConVarInt(g_hRemoveHuntingRiffle)) != g_iCvarHuntingRiffle)
		DebugLog("%d		|	%d		|	rotoblin_remove_huntingrifle", iVal, g_iCvarHuntingRiffle);
	if (bool:(iVal = GetConVarBool(g_hRemoveDualPistols)) != g_bCvarRemoveDualPistols)
		DebugLog("%d		|	%d		|	rotoblin_remove_pistols", iVal, g_bCvarRemoveDualPistols);
	if (bool:(iVal = GetConVarBool(g_hAlterSpawningLogic)) != g_bAlterSpawningLogic)
		DebugLog("%d		|	%d		|	rotoblin_spawning_logic", iVal, g_bAlterSpawningLogic);
	if ((iVal = GetConVarInt(g_hItemsSpawns)) != g_iCvarItemsSpawns)
		DebugLog("%d		|	%d		|	rotoblin_item_spawns", iVal, g_iCvarItemsSpawns);
}
