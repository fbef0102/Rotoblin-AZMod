/**
 * vim: set ts=4 :
 * =============================================================================
 * L4D_Direct
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
#if defined _l4d_direct_included
 #endinput
#endif
#define _l4d_direct_included

#include <sourcemod>
#include <l4dd_internals>
#include <l4dd_timers>

/* --- CDirector Variable access --- */

/**
 * Gets the number of times the tank has passed to a player.
 *
 * @note When this variable is >1 the tank will be replaced with a bot when the his frustration reaches 0.
 * @note The initial pass from AI to a player counts as a pass.
 * @note As this is global on the director weird things could potentially happen if more than one tank is alive at a time with z_frustration 1.
 *
 * @return          The number of passes.
 */
stock L4DDirect_GetTankPassedCount()
{
	return LoadFromAddress(L4DDirect_GetTankPassedCountAddr(), NumberType_Int32);
}

/**
 * Get a reference to the CDirector natural mob spawn CountdownTimer
 *
 * @note This timer is used to control the spawning of natural hordes.
 * @note This timer gets reset during unnatural hordes as well (boomer/car alarm hordes)
 * @note Some scripted events will effectively "take over", by reducing the mob spawn time.
 *
 * @return				CountdownTimer reference to the timer, or CTimer_Null on lookup failure.
 */
stock CountdownTimer:L4DDirect_GetMobSpawnTimer()
{
	static Address:pMobSpawnTimer = Address_Null;
	if(pMobSpawnTimer == Address_Null)
	{
		new offs = GameConfGetOffset(L4DDirect_GetGameConf(), "CDirector::MobSpawnTimer");
		if(offs == -1) return CTimer_Null;
		pMobSpawnTimer = L4DDirect_GetCDirector() + Address:offs;
	}
	return CountdownTimer:pMobSpawnTimer;
}

/**
 * Sets the number of times the tank has passed to a player.
 *
 * @note When this variable is >1 the tank will be replaced with a bot when the his frustration reaches 0.
 * @note The initial pass from AI to a player counts as a pass.
 * @note As this is global on the director weird things could potentially happen if more than one tank is alive at a time with z_frustration 1.
 *
 * @param           New number of passes value
 * @noreturn
 */
stock L4DDirect_SetTankPassedCount(passes)
{
	StoreToAddress(L4DDirect_GetTankPassedCountAddr(), passes, NumberType_Int32);
}

/**
 * Reads the director's stored campaign score for a given team.
 *
 * @note You can use the gamerules m_bAreTeamsFlipped property to figure out team numbers
 * @note The campaign scores value is also stored in gamerules, however this is the "master" version.
 * @note Campaign scores are only updated on round end (after L4D_OnSetCampaignScores), so this will not reflect current survivor distance score
 *
 *
 * @param teamNumber	Team number to read campaign score of, 0 or 1.
 * @return				Campaign score for the given team.
 * @error				Director or Versus Director address not found.
 */
stock L4DDirect_GetVSCampaignScore( teamNumber )
{
	if(teamNumber < 0 || teamNumber > 1) return -1;

	return LoadFromAddress( L4DDirect_GetVSCampaignScoresAddr() + Address:(teamNumber * 4), NumberType_Int32 );
}

/**
 * Set the director's stored campaign score for a given team.
 *
 * @note You can use the gamerules m_bAreTeamsFlipped property to figure out team numbers
 * @note The campaign scores value is also stored in gamerules, however this is the "master" version.
 * @note Keep in mind the current survivor team's distance/bonus score will be added at the end of a round
 *
 *
 * @param teamNumber	Team number to set campaign score of, 0 or 1.
 * @param score			Score to set for the team
 * @error				Director or Versus Director address not found.
 * @noreturn
 */
stock L4DDirect_SetVSCampaignScore( teamNumber , score )
{
	if(teamNumber < 0 || teamNumber > 1) return;

	StoreToAddress( L4DDirect_GetVSCampaignScoresAddr() + Address:(teamNumber * 4), score, NumberType_Int32 );
}

/**
 * Reads the tank flow percent for a given round for versus mode
 *
 * @note You should check GetVSTankToSpawnThisRound to find out if there is still a tank to spawn this round.
 * @note When the survivors reach this flow percent minus versus_boss_buffer converted to flow percent, a tank will spawn.
 *
 * @param roundNumber	Round number to read tank spawn flow percent of
 * @return				Tank spawn flow percent for the given round
 * @error				Director address not found.
 */
stock Float:L4DDirect_GetVSTankFlowPercent(roundNumber)
{
	if (roundNumber < 0 || roundNumber > 1) return -1.0;

	return Float:LoadFromAddress(L4DDirect_GetVSTankFlowAddr() + Address:(roundNumber * 4), NumberType_Int32);
}

/**
 * Sets the tank flow percent for a given round for versus mode
 *
 * @note When the survivors reach this flow percent minus versus_boss_buffer converted to flow percent, a tank will spawn.
 *
 * @param roundNumber	Round number to set tank spawn flow percent of
 * @param flow			Floating point percent of flow distance.
 * @noreturn
 * @error				Director address not found.
 */
stock L4DDirect_SetVSTankFlowPercent(roundNumber, Float:flow)
{
	if (roundNumber < 0 || roundNumber > 1) return;

	StoreToAddress(L4DDirect_GetVSTankFlowAddr() + Address:(roundNumber * 4), _:flow, NumberType_Int32);
}

/**
 * Is there going to be a tank spawned during the given round
 *
 * @param roundNumber	Round number to check for tank spawn on
 * @return				True if there is still a tank to spawn for the given round, false if it has already been spawned or will not spawn.
 * @error				Director or Versus Director address not found.
 */
stock bool:L4DDirect_GetVSTankToSpawnThisRound( roundNumber )
{
	if(roundNumber < 0 || roundNumber > 1) return false;

	return bool:LoadFromAddress( L4DDirect_GeVSTankToSpawnAddr() + Address:roundNumber, NumberType_Int8);
}

/**
 * Tell the director whether or not to spawn a(nother) flow distance-based tank for this round.
 *
 * @note If you set this to true after a flow-distance-based tank has been spawned, this can trigger another tank to be spawned based on flow distance
 *
 * @param roundNumber	Round number to set a tank spawn on
 * @param spawn			Whether or not to spawn a flow-distance-based tank for this round.
 * @noreturn
 * @error				Director or Versus Director address not found.
 */
stock L4DDirect_SetVSTankToSpawnThisRound( roundNumber , bool:spawn )
{
	if(roundNumber < 0 || roundNumber > 1) return;

	StoreToAddress( L4DDirect_GeVSTankToSpawnAddr() + Address:roundNumber, _:spawn, NumberType_Int8);
}

/**
 * Reads the witch flow percent for a given round for versus mode
 *
 * @note You should check GetVSWitchToSpawnThisRound to find out if a witch is going to be spawned for this round.
 * @note When the survivors reach this flow percent minus versus_boss_buffer converted to flow percent, a witch will spawn.
 *
 *
 * @param roundNumber	Round number to read witch spawn flow percent of
 * @return				Witch spawn flow percent for the given round
 * @error				Director or Versus Director address not found.
 */
stock Float:L4DDirect_GetVSWitchFlowPercent(roundNumber)
{
	if (roundNumber < 0 || roundNumber > 1) return -1.0;

	return Float:LoadFromAddress(L4DDirect_GetVSWitchFlowAddr() + Address:(roundNumber * 4), NumberType_Int32);
}

/**
 * Sets the witch flow percent for a given round for versus mode
 *
 * @note You should check GetVSWitchToSpawnThisRound to find out if there is still a witch to spawn this round.
 * @note When the survivors reach this flow percent minus versus_boss_buffer converted to flow percent, a witch will spawn.
 *
 *
 * @param roundNumber	Round number to set witch spawn flow percent of
 * @param flow			Floating point percent of flow distance.
 * @noreturn
 * @error				Director or Versus Director address not found.
 */
stock L4DDirect_SetVWitchFlowPercent(roundNumber, Float:flow)
{
	if (roundNumber < 0 || roundNumber > 1) return;

	StoreToAddress(L4DDirect_GetVSWitchFlowAddr() + Address:(roundNumber * 4), _:flow, NumberType_Int32);
}

/**
 * Is there going to be a witch spawned during the given round
 *
 * @param roundNumber	Round number to check for witch spawn on
 * @return				True if there is still a witch to spawn for the given round, false if it has already been spawned or will not spawn.
 * @error				Director or Versus Director address not found.
 */
stock bool:L4DDirect_GetVSWitchToSpawnThisRound( roundNumber )
{
	if(roundNumber < 0 || roundNumber > 1) return false;

	return bool:LoadFromAddress( L4DDirect_GetVSWitchToSpawnAddr() + Address:roundNumber, NumberType_Int8);
}

/**
 * Tell the director whether or not to spawn a(nother) flow distance-based witch for this round.
 *
 * @note If you set this to true after a flow-distance-based witch has been spawned, this can trigger another witch to be spawned based on flow distance
 *
 * @param roundNumber	Round number to set a witch spawn on
 * @param spawn			Whether or not to spawn a flow-distance-based witch for this round.
 * @noreturn
 * @error				Director or Versus Director address not found.
 */
stock L4DDirect_SetVSWitchToSpawnThisRound( roundNumber , bool:spawn )
{
	if(roundNumber < 0 || roundNumber > 1) return;

	StoreToAddress( L4DDirect_GetVSWitchToSpawnAddr() + Address:roundNumber, _:spawn , NumberType_Int8);
}

/* --- TerrorNavMesh Variable access --- */

/**
 * Get the max flow distance (in flow units) for the current map.
 *
 * @note The flow distance for each map is generated as it is loaded, and it can change slightly (a few hundred units) with each load.
 * @note You can use this value to convert a flow distance to a flow percent, and vice versa.
 *
 * @return				Max flow distance for the current loaded map.
 * @error				TerrorNavMesh address not found.
 */
stock Float:L4DDirect_GetMapMaxFlowDistance()
{
	return Float:LoadFromAddress(L4DDirect_GetMapMaxFlowDistanceAddr(), NumberType_Int32);
}

/* --- CTerrorPlayer Variable access --- */

/**
 * Get the clients health bonus.
 *
 * @note Survivors health bonuses are 0 until CTerrorPlayer:RecalculateVersusScore(void) calculates it.
 *
 * @param client		Client id whose health bonus is to be returned.
 * @return				Int value of the survivors health bonus.
*/
/*
stock L4DDirect_GetSurvivorHealthBonus(client)
{
	if (!IsClient(client))
		return -1;

	decl value;
	if (GetEntityValueFromOffset(client, "CTerrorPlayer::m_iSurvivorHealthBonus", NumberType_Int32, value))
		return value;

	return -1;
}
*/
/**
 * Sets the clients health bonus.
 *
 * @note Keep in mind the individual survivors health bonus will be recalculate again when CTerrorPlayer:RecalculateVersusScore(void) is invoked.
 * @note L4D_OnRecalculateVersusScore(client) forward (left4downtown exts) can block health bonus from being calculated to store your own value with this function.
 *
 * @param client		Client id to set the health bonus for
 * @param health		Number of health bonus
 * @param recompute		If true, L4DDirect_RecomputeTeamScores() is called after the health bonus has been set
 * @noreturn
 * @error				Invalid client.
*/

stock L4DDirect_SetSurvivorHealthBonus(client, health, bool:recompute = true)
{
	if (!IsClient(client))
		return;

	SetEntityValueFromOffset(client, "CTerrorPlayer::m_iSurvivorHealthBonus", NumberType_Int32, health);

	if (recompute)
		L4DDirect_RecomputeTeamScores();
}

/**
 * Looks up the number of tickets a client has for entry into the tank lottery.
 *
 * @note The number of tickets you have is equal to your damage done as an SI and will still increase as you do damage with the Tank.
 * @note When the tank is passed away from you your tickets are set back to zero.
 *
 * @param client		Client id to get the tickets for
 * @return				Number of tickets.
 * @error				Invalid client.
 */
 
stock L4DDirect_GetTankTickets(client)
{
	if (!IsClient(client))
		return -1;

	decl value;
	if (GetEntityValueFromOffset(client, "CTerrorPlayer::m_iTankTickets", NumberType_Int32, value))
		return value;

	return -1;
}

/**
 * Sets the number of tickets a player has for entry into the tank lottery.
 *
 * @param client		Client id to set the tickets for
 * @param tickets		New value for the client's tank lottery tickets
 * @noreturn
 * @error				Invalid client.
 */

stock L4DDirect_SetTankTickets(client, tickets)
{
	if (!IsClient(client))
		return;

	SetEntityValueFromOffset(client, "CTerrorPlayer::m_iTankTickets", NumberType_Int32, tickets);
}

/* --- ZombieManager Variable access --- */

stock L4DDirect_GetPendingMobCount()
{
	return LoadFromAddress(L4DDirect_GetPendingMobCountAddr(), NumberType_Int32);
}

stock L4DDirect_SetPendingMobCount(count)
{
	StoreToAddress(L4DDirect_GetPendingMobCountAddr(), count, NumberType_Int32);
}


/* --- Timers Variable access --- */

/**
 * Get a reference to the CountdownTimer
 *
 * @note This timer controls when the saferoom door will open and PZ spawning is enabled
 * @note The default duration for this timer is controlled by cvar: versus_force_start_time
 *
 * @param timer			CountdownTimer name (defined in TimerRef enums).
 * @param client		Client id to get the timer for (only for CTerrorPlayer timers instance)
 * @return				CountdownTimer reference to the timer, or CTimer_Null on lookup failure.
 * @error				Director address not found.
 */
 
stock CountdownTimer:L4DDirect_GetTimerRef(TimerRef:timer, client = 0)
{
	if (timer >= SpawnTimer ){
	
		static Offset[TimerRef];
		if (!IsClient(client))
			return CTimer_Null;

		new Address:pEntity = GetEntityAddress(client);
		if (pEntity == Address_Null)
			return CTimer_Null;

		if (Offset[timer] <= 0){

			Offset[timer] = GameConfGetOffset(L4DDirect_GetGameConf(), g_sOffsets[timer]);
			if (Offset[timer] == -1)
				return CTimer_Null;
		}

		return CountdownTimer:(pEntity + Address:Offset[timer]);
	}
	else {

		static Address:pTimer[TimerRef];
		if(pTimer[timer] == Address_Null)
		{
			new offs = GameConfGetOffset(L4DDirect_GetGameConf(), g_sOffsets[timer]);
			if(offs == -1) return CTimer_Null;
			pTimer[timer] = L4DDirect_GetCDirector() + Address:offs;
		}
		return CountdownTimer:pTimer[timer];
	}
}

/* --- Functions Calls --- */

/**
 * @brief Trigger's a target player's stagger behavior
 * @remarks Works on any CTerrorPlayer--survivor or infected.
 *
 * @param target 		Player to stagger
 * @param source_ent	Source of the stagger (another player, etc)
 * @param source_vector Source location of the stagger. If NULL_VECTOR, origins of source_ent is used.
 * @noreturn
 */
stock bool:L4DDirect_StaggerPlayer(target, source_ent, Float:source_vector[3] = {0.0, 0.0, 0.0})
{
	static Handle:hSDKCallStagger;

	if (hSDKCallStagger == INVALID_HANDLE){

		StartPrepSDKCall(SDKCall_Player);

		if (!PrepSDKCall_SetFromConf(L4DDirect_GetGameConf(), SDKConf_Signature, "CTerrorPlayer::OnStaggered"))
			return false;

		PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
		PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Pointer);
		hSDKCallStagger = EndPrepSDKCall();

		if (hSDKCallStagger == INVALID_HANDLE)
			return false;
	}

	if (!source_vector[0] && !source_vector[1] && !source_vector[2])
		GetClientAbsOrigin(source_ent, source_vector);

	SDKCall(hSDKCallStagger, target, source_ent, source_vector);
	return true;
}

/* CTerrorPlayer Variable access */

/**
 * Get a reference to a CountdownTimer that tracks when an SI player can next spawn.
 *
 * @note The duration of this timer is controlled by the cvars z_ghost_delay_min and z_ghost_delay_max.
 * @param client		Client id to get the spawn timer for
 * @return				CountdownTimer reference to the timer, or CTimer_Null on lookup failure.
 * @error				Invalid client.
 */
stock CountdownTimer:L4DDirect_GetSpawnTimer(client)
{
	if (client < 1 || client > MaxClients)
		return CTimer_Null;

	new Address:pEntity = GetEntityAddress(client);
	if (pEntity == Address_Null)
		return CTimer_Null;

	new offs = GameConfGetOffset(L4DDirect_GetGameConf(), "CTerrorPlayer::SpawnTimer");
	if (offs == -1)
		return CTimer_Null;

	return CountdownTimer:(pEntity + Address:offs);
}

/**
 * Force the director to pass the tank.
 *
 * @param entity			Entity index of the tank
 * @param bEnterStasis		Should the tank be put in statis
 * @return					False on error otherwise true
 * @error					SDK call preparation failed
 */
stock bool:L4DDirect_TryOfferingTankBot(entity, bEnterStasis)
{
	static Handle:TryOfferingTankBotSDKCall = INVALID_HANDLE;

	if (TryOfferingTankBotSDKCall == INVALID_HANDLE)
	{
		StartPrepSDKCall(SDKCall_Raw);

		if (!PrepSDKCall_SetFromConf(L4DDirect_GetGameConf(), SDKConf_Signature, "CDirector::TryOfferingTankBot"))
		{
			return false;
		}

		PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
		PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
		TryOfferingTankBotSDKCall = EndPrepSDKCall();

		if (TryOfferingTankBotSDKCall == INVALID_HANDLE)
		{
			return false;
		}
	}

	SDKCall(TryOfferingTankBotSDKCall, L4DDirect_GetCDirector(), entity, bEnterStasis);
	return true;
}

/**
 * Force to replace the tank. (pass count will not be changed)
 *
 * @param entity			Entity index of the tank
 * @param target			Entity index of infected player
 * @return					False on error otherwise true
 * @error					SDK call preparation failed
 */
stock bool:L4DDirect_ReplaceTank(entity, target)
{
	static Handle:hReplaceTank;

	if (hReplaceTank == INVALID_HANDLE){

		StartPrepSDKCall(SDKCall_Raw);

		if (PrepSDKCall_SetFromConf(L4DDirect_GetGameConf(), SDKConf_Signature, "ZombieManager::ReplaceTank")){

			PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
			PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
			hReplaceTank = EndPrepSDKCall();
		}

		if (hReplaceTank == INVALID_HANDLE)
			return false;
	}

	SDKCall(hReplaceTank, L4DDirect_GetZombieManager(), entity, target);
	return true;
}

/**
 * Take control of a special infected or tank bot
 *
 * @param entity			Entity index of bot
 * @param target			Entity index of player who takes control
 * @return					False on error otherwise true
 * @error					SDK call preparation failed
 */
stock bool:L4DDirect_TakeOverZombieBot(entity, target)
{
	static Handle:hTakeOverZombieBot;

	if (hTakeOverZombieBot == INVALID_HANDLE){

		StartPrepSDKCall(SDKCall_Player);

		if (PrepSDKCall_SetFromConf(L4DDirect_GetGameConf(), SDKConf_Signature, "CTerrorPlayer::TakeOverZombieBot")){

			PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
			hTakeOverZombieBot = EndPrepSDKCall();
		}

		if (hTakeOverZombieBot == INVALID_HANDLE)
			return false;
	}

	SDKCall(hTakeOverZombieBot, target, entity);
	return true;
}

/**
 * Special infected force ghost
 *
 * @param entity			Entity index of SI
 * @param delay				Time delay before force ghost
 * @param culling			If true, sets m_isCulling to 1
 * @return					False on error otherwise true
 * @error					SDK call preparation failed
 */
stock bool:L4DDirect_PlayerZombieAbortControl(entity, Float:delay, bool:culling = true)
{
	static Handle:hPlayerZombieAbortControl;

	if (hPlayerZombieAbortControl == INVALID_HANDLE){

		StartPrepSDKCall(SDKCall_Player);

		if (PrepSDKCall_SetFromConf(L4DDirect_GetGameConf(), SDKConf_Signature, "CTerrorPlayer::PlayerZombieAbortControl")){

			PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
			hPlayerZombieAbortControl = EndPrepSDKCall();
		}

		if (hPlayerZombieAbortControl == INVALID_HANDLE)
			return false;
	}

	if (culling)
		SetEntProp(entity, Prop_Send, "m_isCulling", 1);

	SDKCall(hPlayerZombieAbortControl, entity, delay)
	return true;
}

/**
 * Compute the scores on the scoreboard
 *
 * @noparam
 * @return					False on error otherwise true
 * @error					SDK call preparation failed
 */
stock bool:L4DDirect_RecomputeTeamScores()
{
	static Handle:hRecomputeTeamScores;

	if (hRecomputeTeamScores == INVALID_HANDLE){

		StartPrepSDKCall(SDKCall_GameRules);

		if (PrepSDKCall_SetFromConf(L4DDirect_GetGameConf(), SDKConf_Signature, "CTerrorGameRules::RecomputeTeamScores")){

			hRecomputeTeamScores = EndPrepSDKCall();

			if (hRecomputeTeamScores == INVALID_HANDLE)
				return false;
		}
	}

	SDKCall(hRecomputeTeamScores);
	return true;
}

/**
 * Plays the specified animation for a player
 *
 * @note The event argument is NOT the same as the sequence numbers found in the model viewer
 * @note You can get the number for your animation by looking at the disasm for virtual calls to DoAnimationEvent
 * @param client
 * @param event PlayerAnimEvent_t
 * @noreturn
 */
stock L4DDirect_DoAnimationEvent(client, event)
{
	if(!IsClient(client))
	{
		return;
	}
	static Handle:DoAnimationEventSDKCall = INVALID_HANDLE;
	if(DoAnimationEventSDKCall == INVALID_HANDLE)
	{
		StartPrepSDKCall(SDKCall_Player);
		if(!PrepSDKCall_SetFromConf(L4DDirect_GetGameConf(), SDKConf_Virtual, "CTerrorPlayer::DoAnimationEvent"))
		{
			return;
		}
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		DoAnimationEventSDKCall = EndPrepSDKCall();

		if(DoAnimationEventSDKCall == INVALID_HANDLE)
		{
			return;
		}
	}
	SDKCall(DoAnimationEventSDKCall, client, event, 0);
}

/**
 * Gets a player's distance in flow units.
 *
 * @param client			Client ID
 * @param infected			Sets true, if target an infected (SI, Common, Boss)
 * @return					0.0 on error otherwise flow distance
 * @error					SDK call preparation failed
 */
stock Float:L4DDirect_GetFlowDistance(client, bool:infected = false)
{
	if (infected){

		static Handle:hGetInfectedFlowDistance;

		if (hGetInfectedFlowDistance == INVALID_HANDLE)
		{
			StartPrepSDKCall(SDKCall_Entity);

			if (!PrepSDKCall_SetFromConf(L4DDirect_GetGameConf(), SDKConf_Signature, "Infected::GetFlowDistance"))
				return 0.0;

			PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_Plain);
			hGetInfectedFlowDistance = EndPrepSDKCall();

			if (hGetInfectedFlowDistance == INVALID_HANDLE)
			{
				return 0.0;
			}
		}

		return Float:SDKCall(hGetInfectedFlowDistance, client, 0);
	}

	static Handle:hGetSurvivorFlowDistance = INVALID_HANDLE;

	if (hGetSurvivorFlowDistance == INVALID_HANDLE)
	{
		StartPrepSDKCall(SDKCall_Player);

		if (!PrepSDKCall_SetFromConf(L4DDirect_GetGameConf(), SDKConf_Signature, "CTerrorPlayer::GetFlowDistance"))
			return 0.0;

		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_Plain);
		hGetSurvivorFlowDistance = EndPrepSDKCall();

		if (hGetSurvivorFlowDistance == INVALID_HANDLE)
			return 0.0;
	}

	return Float:SDKCall(hGetSurvivorFlowDistance, client, 0);
}

/**
 * Get the TerrorNavArea which holds a specific position.
 *
 * @note Some positions will not return a nav area (Address_Null). Notable examples are saferooms and small ledges like the guard rail at the start of c2m1_highway.
 * @param pos           The position to find the containing nav area of
 * @param beneathLimit
 * @return              Address to a TerrorNavArea or Address_Null
 * @error               Unable to prepare SDK call
 */
stock Address:L4DDirect_GetTerrorNavArea(Float:pos[3], Float:beneathLimit = 120.0)
{
	static Handle:GetNavAreaSDKCall = INVALID_HANDLE;

	if (GetNavAreaSDKCall == INVALID_HANDLE)
	{
		StartPrepSDKCall(SDKCall_Raw);

		if (!PrepSDKCall_SetFromConf(L4DDirect_GetGameConf(), SDKConf_Signature, "CNavMesh::GetNavArea"))
		{
			return Address_Null;
		}

		PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
		PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
		PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
		GetNavAreaSDKCall = EndPrepSDKCall();

		if (GetNavAreaSDKCall == INVALID_HANDLE)
		{
			return Address_Null;
		}
	}

	return Address:SDKCall(GetNavAreaSDKCall, L4DDirect_GetTerrorNavMesh(), pos, beneathLimit);
}

stock Address:L4DDirect_GetNearestNavArea(Float:pos[3], bool:anyZ = false, Float:maxDist = 100.0, bool:checkLOS = false, bool:checkGround = true)
{
	static Handle:GetNavAreaSDKCall = INVALID_HANDLE;

	if (GetNavAreaSDKCall == INVALID_HANDLE)
	{
		StartPrepSDKCall(SDKCall_Raw);

		if (!PrepSDKCall_SetFromConf(L4DDirect_GetGameConf(), SDKConf_Signature, "CNavMesh::GetNearestNavArea"))
		{
			return Address_Null;
		}

		PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
		PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
		PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
		PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
		PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
		PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
		GetNavAreaSDKCall = EndPrepSDKCall();

		if (GetNavAreaSDKCall == INVALID_HANDLE)
		{
			return Address_Null;
		}
	}

	return Address:SDKCall(GetNavAreaSDKCall, L4DDirect_GetTerrorNavMesh(), pos, anyZ, maxDist, checkLOS, checkGround);
}

/**
 * Find the distance through the map (in flow units) that a TerrorNavArea is located.
 *
 * @param  pTerrorNavArea   Pointer to a TerrorNavArea
 * @return                  The flow units through the map that the TerrorNavArea is located at.
 * @error                   When passed an Address_Null
 */
stock Float:L4DDirect_GetTerrorNavAreaFlow(Address:pTerrorNavArea)
{
	if (pTerrorNavArea == Address_Null)
		return 0.0;

	static offs = -1;
	if (offs == -1){

		if ((offs = GameConfGetOffset(L4DDirect_GetGameConf(), "TerrorNavArea::m_flow")) == -1)
			return 0.0;
	}

	return Float:LoadFromAddress(pTerrorNavArea + Address:offs, NumberType_Int32);
}

static stock bool:IsClient(index)
{
	return index > 0 && index <= MaxClients;
}
