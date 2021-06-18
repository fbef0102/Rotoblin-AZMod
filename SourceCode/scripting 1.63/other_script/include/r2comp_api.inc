/*
 * ============================================================================
 *
 * This file is a part of the Rotoblin 2 project.
 *
 *  Required Plugins: r2compmod v1.2+, optional: l4dscores v1.1.3, l4dready v1.0.
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

#if defined _r2comp_api_
  #endinput
#endif
#define _r2comp_api_


enum CompNatives
{
	IsStartEntity,
	IsEndEntity,
	GetSafeRoomOrigin,
	GetMobTimer,
	GetMatchName,
	GetScore,
	GetHighestSurvivorFlow,
	GetHighestSurvivorFlowEx,
	IsUnscrambled,
	IsGamePaused,
	IsReadyMode,
	GetCampaingScore
};

new stock const String:g_sR2API_NativeName[][] =
{
	"R2comp_IsStartEntity",
	"R2comp_IsEndEntity",
	"R2comp_GetSafeRoomOrigin",
	"R2comp_GetMobTimer",
	"R2comp_GetMatchName",
	"R2comp_GetScore",
	"R2comp_GetHighestSurvivorFlow",
	"R2comp_GetHighestSurvivorFlowEx",
	"R2comp_IsUnscrambled",
	"L4DReady_IsGamePaused",
	"L4DReady_IsReadyMode",
	"L4DScores_GetCampaingScore"
};

/**
 * Returns whether a r2comp api native is available to use.
 *
 * For example "new bool:blah = IsNativeAvailable(GetCampaingScore)"
 * If checks were successful L4DScores_GetCampaingScore() native can be called.
 *
 * @param elem			One of the enumerations element from CompNatives case to check (this is a short native name).
 * @return				True if native will work, false otherwise.
 */
stock bool:IsNativeAvailable(CompNatives:elem)
{
	if (elem >= CompNatives)
		return false;

	if (!CanTestFeatures()){

		LogError("'GetFeatureStatus' will not work as 'CanTestFeatures' function returns false.");
		return false;
	}

	return GetFeatureStatus(FeatureType_Native, g_sR2API_NativeName[elem]) == FeatureStatus_Available;
}

/**
 * Returns whether or not an entity located in start safe room.
 *
 * @param entity	Index of the entity.
 * @return			True if located, false otherwise.
 * @error			Invalid entity.
 */
native bool:R2comp_IsStartEntity(entity);

/**
 * Returns whether or not an entity is located in the end safe room.
 *
 * @param entity	Index of the entity.
 * @return			True if located, false otherwise.
 * @error			Invalid entity.
 */
native bool:R2comp_IsEndEntity(entity);

/**
 * Returns the start/end safe room origin vector.
 *
 * @param vec			Destination vector to store the safe room origin vector.
 * @param startroom		If false the end saferoom vector will be stored.
 * @noreturn
 */
native R2comp_GetSafeRoomOrigin(Float:vec[3], bool:startroom = true);

/**
 * Returns a natural mob spawn countdown time.
 *
 * This timer is used to control the spawning of natural hordes by r2compmod plugin.
 * Hordes can be allowed/disallowed by 'rotoblin_allow_natural_hordes' convar.
 *
 * @return			-1 - it means that the tank is in game or timer does not tick yet.
 *					If zero the hordes are disabled, time to spawn otherwise.
 */
native R2comp_GetMobTimer();

/**
 * Returns the current match name.
 *
 * @param buffer		Buffer to store match name.
 * @param maxlength		Maximum length of buffer.
 * @noreturn
 */
native R2comp_GetMatchName(String:buffer[], maxlength);

/**
 * Returns the current campaign scores.
 *
 * @param logical_team		0 for A, 1 for B.
 * @return					The score.
 */
native R2comp_GetScore(logical_team);

/**
 * Returns the highest survivors flow distance.
 *
 * First, flow distance will be calculated, then returned.
 *
 * @return			-1 - No survivors found, flow otherwise.
 */
native Float:R2comp_GetHighestSurvivorFlow();

/**
 * Returns the highest survivors flow distance.
 *
 * More optimized way to get a flow. Despawn infected module should be enabled.
 *
 * @return			-1 - Func not available, use 'R2comp_GetHighestSurvivorFlow' instead,
					flow otherwise.
 */
native Float:R2comp_GetHighestSurvivorFlowEx();

/**
 * Returns whether or not unscramble completed.
 *
 * @return			True if completed, false means unscramble is processing and team changes is locked.
 */
native bool:R2comp_IsUnscrambled();

/**
 * Called when server becomes empty.
 *
 * @noreturn
 */
forward R2comp_OnServerEmpty();

/**
 * Called before a new match loads. Previous match has not been unloaded yet.
 *
 * @return			Name of a loaded match.
 */
forward R2comp_OnMatchStarts_Pre(const String:match[]);

/**
 *  Called when a new match has fully loaded.
 *
 * @return			Name of a loaded match.
 */
forward R2comp_OnMatchStarts(const String:match[]);

/**
 * Called when unscramble completed.
 *
 * @noreturn
 */
forward R2comp_OnUnscrambleEnd();

/**
 * Returns if a game paused by readyup plugin.
 *
 * @return			True if game paused, false otherwise.
 */
native bool:L4DReady_IsGamePaused();

/**
 * Returns if a players were frozen by readyup plugin.
 *
 * @return			True if readyup mode is active and players freezed, false otherwise.
 */
native bool:L4DReady_IsReadyMode();

/**
 * Called when a players are unfrozen by readyup plugin and the match is live.
 *
 * @noreturn
 */
forward L4DReady_OnRoundIsLive();

/**
 * Scavenge warm up during ready up.
 *
 * Not supported in left 4 dead.
 *
 * @noreturn
 */
forward L4DReady_OnReadyRoundRestarted();

/**
 * Returns the current campaign scores.
 *
 * @param team		Survivors or Infected team index.
 * @return			The score.
 */
native L4DScores_GetCampaingScore(team);


stock MarkCompNatives()
{
	MarkNativeAsOptional("R2comp_IsStartEntity");
	MarkNativeAsOptional("R2comp_IsEndEntity");
	MarkNativeAsOptional("R2comp_GetSafeRoomOrigin");
	MarkNativeAsOptional("R2comp_GetMobTimer");
	MarkNativeAsOptional("R2comp_GetMatchName");
	MarkNativeAsOptional("R2comp_GetScore");
	MarkNativeAsOptional("R2comp_GetHighestSurvivorFlow");
	MarkNativeAsOptional("R2comp_GetHighestSurvivorFlowEx");
	MarkNativeAsOptional("R2comp_IsUnscrambled");
	MarkNativeAsOptional("L4DReady_IsGamePaused");
	MarkNativeAsOptional("L4DReady_IsReadyMode");
	MarkNativeAsOptional("L4DScores_GetCampaingScore");
}

#if !defined REQUIRE_PLUGIN
public __pl_r2comp_api_SetNTVOptional()
{
	MarkCompNatives();
}
#endif
