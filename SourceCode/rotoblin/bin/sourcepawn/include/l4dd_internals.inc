/**
 * vim: set ts=4 :
 * =============================================================================
 * L4D_Direct Internals
 * Copyright (C) 2012-2015  raziEiL <war4291@mail.ru>
 * Copyright (C) 2012 Michael "ProdigySim" Busby
 * =============================================================================
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * As a special exception, AlliedModders LLC gives you permission to link the
 * code of this program (as well as its derivative works) to "Half-Life 2," the
 * "Source Engine," the "SourcePawn JIT," and any Game MODs that run on software
 * by the Valve Corporation.  You must obey the GNU General Public License in
 * all respects for all other code used.  Additionally, AlliedModders LLC grants
 * this exception to all derivative works.  AlliedModders LLC defines further
 * exceptions, found in LICENSE.txt (as of this writing, version JULY-31-2007),
 * or <http://www.sourcemod.net/license.php>.
 *
 * Version: $Id$
 */
#if defined _l4dd_internals_included
 #endinput
#endif
#define _l4dd_internals_included

#include <sourcemod>
#include <sdktools>

/* L4D_Direct internals */

/**
 * Get a handle to the L4DDirect GameConfig (gamedata)
 *
 * @return				Handle to the l4d_direct game config, or INVALID_HANDLE if not found.
 */
stock Handle:L4DDirect_GetGameConf()
{
	static Handle:g_hGameConf_l4ddir = INVALID_HANDLE;
	if(g_hGameConf_l4ddir == INVALID_HANDLE)
	{
		g_hGameConf_l4ddir = LoadGameConfigFile("l4d_direct");
	}
	return g_hGameConf_l4ddir;
}

/**
 * Get the address of the global CDirector instance (TheDirector)
 *
 * @return				Address of the global CDirector, or Address_Null on failure.
 */
stock Address:L4DDirect_GetCDirector()
{
	static Address:TheDirector = Address_Null;
	if(TheDirector == Address_Null)
	{
		TheDirector = GameConfGetAddress(L4DDirect_GetGameConf(), "CDirector");
	}
	return TheDirector;
}

/**
 * Get the address of the global ZombieManager instance (TheZombieManager)
 *
 * @return				Address of the global TheZombieManager, or Address_Null on failure.
 */
stock Address:L4DDirect_GetZombieManager()
{
	static Address:TheZombieManager = Address_Null;

	if (TheZombieManager == Address_Null)
		TheZombieManager = GameConfGetAddress(L4DDirect_GetGameConf(), "ZombieManager");

	return TheZombieManager;
}

/**
 * Get the address of the global TerrorNavMesh instance (TheNavMesh)
 *
 * @return				Address of the global TheNavMesh, or Address_Null on failure.
 */
stock Address:L4DDirect_GetTerrorNavMesh()
{
	static Address:TheNavMesh = Address_Null;
	if(TheNavMesh == Address_Null)
	{
		TheNavMesh = GameConfGetAddress(L4DDirect_GetGameConf(), "TerrorNavMesh");
	}
	return TheNavMesh;
}

/**
 * Get the address of CDirector::m_iTankPassedCount in the global CDirector instance.
 *
 * @return				Address of m_iTankPassedCount variable, or Address_Null on failure.
 */
stock Address:L4DDirect_GetTankPassedCountAddr()
{
	static Address:pTankPassedCount = Address_Null;
	if (pTankPassedCount == Address_Null)
	{
		new offs = GameConfGetOffset(L4DDirect_GetGameConf(), "CDirector::m_iTankPassedCount");
		if (offs == -1) return Address_Null;
		pTankPassedCount = L4DDirect_GetCDirector() + Address:offs;
	}
	return pTankPassedCount;
}

/**
 * Get the address of CDirector::m_iCampaignScores in the global CDirector instance
 *
 * @return				Address of the CampaignScores array, or Address_Null on failure.
 */
stock Address:L4DDirect_GetVSCampaignScoresAddr()
{
	static Address:pCampaignScores = Address_Null;
	if(pCampaignScores == Address_Null)
	{
		new offs = GameConfGetOffset(L4DDirect_GetGameConf(), "CDirector::m_iCampaignScores");
		if(offs == -1) return Address_Null;
		pCampaignScores = L4DDirect_GetCDirector() + Address:offs;
	}
	return pCampaignScores;
}

/**
 * Get the address of CDirector::m_fTankSpawnFlowPercent in the global CDirector instance
 *
 * @return				Address of the TankFlow array, or Address_Null on failure.
 */
stock Address:L4DDirect_GetVSTankFlowAddr()
{
	static Address:pTankFlowPercent = Address_Null;
	if(pTankFlowPercent == Address_Null)
	{
		new offs = GameConfGetOffset(L4DDirect_GetGameConf(), "CDirector::m_fTankSpawnFlowPercent");
		if(offs == -1) return Address_Null;
		pTankFlowPercent = L4DDirect_GetCDirector() + Address:offs;
	}
	return pTankFlowPercent;
}

/**
 * Get the address of CDirector::m_bTankThisRound in the global CDirector instance
 *
 * @return				Address of the TankToSpawn array, or Address_Null on failure.
 */
stock Address:L4DDirect_GeVSTankToSpawnAddr()
{
	static Address:pTankSpawnThisRound = Address_Null;
	if(pTankSpawnThisRound == Address_Null)
	{
		new offs = GameConfGetOffset(L4DDirect_GetGameConf(), "CDirector::m_bTankThisRound");
		if(offs == -1) return Address_Null;
		pTankSpawnThisRound = L4DDirect_GetCDirector() + Address:offs;
	}
	return pTankSpawnThisRound;
}

/**
 * Get the address of CDirector::m_fWitchSpawnFlowPercent in the global CDirector instance
 *
 * @return				Address of the TankFlow array, or Address_Null on failure.
 */
stock Address:L4DDirect_GetVSWitchFlowAddr()
{
	static Address:pTankFlowPercent = Address_Null;
	if(pTankFlowPercent == Address_Null)
	{
		new offs = GameConfGetOffset(L4DDirect_GetGameConf(), "CDirector::m_fWitchSpawnFlowPercent");
		if(offs == -1) return Address_Null;
		pTankFlowPercent = L4DDirect_GetCDirector() + Address:offs;
	}
	return pTankFlowPercent;
}

/**
 * Get the address of CDirector::m_bWitchThisRound in the global CDirector instance
 *
 * @return				Address of the WitchToSpawn array, or Address_Null on failure.
 */
stock Address:L4DDirect_GetVSWitchToSpawnAddr()
{
	static Address:pWitchSpawnThisRound = Address_Null;
	if(pWitchSpawnThisRound == Address_Null)
	{
		new offs = GameConfGetOffset(L4DDirect_GetGameConf(), "CDirector::m_bWitchThisRound");
		if(offs == -1) return Address_Null;
		pWitchSpawnThisRound = L4DDirect_GetCDirector() + Address:offs;
	}
	return pWitchSpawnThisRound;
}

/**
 * Get the address of TerrorNavMesh::m_fMapMaxFlowDistance in the global TerrorNavMesh instance
 *
 * @return				Address of the MapMaxFlowDistance variable, or Address_Null on failure.
 */
stock Address:L4DDirect_GetMapMaxFlowDistanceAddr()
{
	static Address:pMapMaxFlowDistance = Address_Null;
	if(pMapMaxFlowDistance == Address_Null)
	{
		new offs = GameConfGetOffset(L4DDirect_GetGameConf(), "TerrorNavMesh::m_fMapMaxFlowDistance");
		if(offs == -1) return Address_Null;
		pMapMaxFlowDistance = L4DDirect_GetTerrorNavMesh() + Address:offs;
	}
	return pMapMaxFlowDistance;
}
/**
 * Get the address of ZombieManager:m_MobSpawnCount in the global ZombieManager instance
 *
 * @return				Address of the MobSpawnCount variable, or Address_Null on failure.
 */
stock Address:L4DDirect_GetPendingMobCountAddr()
{
	static Address:pPendingMobCount = Address_Null;
	if(pPendingMobCount == Address_Null)
	{
		new offs = GameConfGetOffset(L4DDirect_GetGameConf(), "ZombieManager::m_PendingMobCount");
		if(offs == -1) return Address_Null;
		pPendingMobCount = L4DDirect_GetZombieManager() + Address:offs;
	}
	return pPendingMobCount;
}

/**
 * Gets entity data at a given offset
 *
 * @param entity
 * @param offset name of the offset in gamedata
 * @param size size of the value to retrieve
 * @param value output parameter for the retrieved value
 * @return bool
 */
 
stock GetEntityValueFromOffset(entity, const String:offset[], NumberType:size, &value)
{
	new Address:pEntity = GetEntityAddress(entity);
	if (pEntity == Address_Null)
		return false;

	new offs = GameConfGetOffset(L4DDirect_GetGameConf(), offset);
	if (offs == -1)
		return false;

	value = LoadFromAddress(pEntity + Address:offs, size);
	return true;
}

/**
 * Sets data entity data at a given offset
 *
 * @param entity
 * @param offset name of the offset in gamedata
 * @param size size of the value to set
 * @param value value to store at the offset
 * @return bool
 */
 
stock SetEntityValueFromOffset(entity, const String:offset[], NumberType:size, value)
{
	new Address:pEntity = GetEntityAddress(entity);
	if (pEntity == Address_Null)
		return false;

	new offs = GameConfGetOffset(L4DDirect_GetGameConf(), offset);
	if (offs == -1)
		return false;

	StoreToAddress(pEntity + Address:offs, value, size);
	return true;
}
