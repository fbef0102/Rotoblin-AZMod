/**
 * vim: set ts=4 :
 * =============================================================================
 * Left 4 Downtown SourceMod Extension
 * Copyright (C) 2009 Igor "Downtown1" Smirnov.
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
#if defined _l4do_included
 #endinput
#endif
#define _l4do_included

/**
 * @brief Called whenever ZombieManager::SpawnTank(Vector&,QAngle&) is invoked
 * @remarks Not invoked if z_spawn tank is used and it gives a ghosted/dead player tank
 *
 * @param vector	Vector coordinate where tank is spawned
 * @param qangle	QAngle where tank will be facing
 * @return 		Pl_Handled to block tank from spawning, Pl_Continue otherwise.
 */
forward Action:L4D_OnSpawnTank(const Float:vector[3], const Float:qangle[3]);

/**
 * @brief Called whenever ZombieManager::SpawnWitch(Vector&,QAngle&) is invoked
 *
 * @param vector	Vector coordinate where witch is spawned
 * @param qangle	QAngle where witch will be facing
 * @return 		Pl_Handled to block witch from spawning, Pl_Continue otherwise.
 */
forward Action:L4D_OnSpawnWitch(const Float:vector[3], const Float:qangle[3]);

/**
 * @brief Called whenever CTerrorGameRules::ClearTeamScores() is invoked
 * @remarks 	This resets the map score at the beginning of a map, and by checking
 *                the campaign scores on a small timer you can see if they were reset as well.
 *
 * @return 		Pl_Handled to block scores from being cleared, Pl_Continue otherwise.
 */
forward Action:L4D_OnClearTeamScores();

/**
 * @brief Called whenever CTerrorGameRules::SetCampaignScores(int,int) is invoked
 * @remarks The campaign scores are updated after the 2nd round is completed
 *
 * @param scoreA  score of logical team A
 * @param scoreB  score of logical team B
 * @return 		Pl_Handled to block campaign scores from being set, Pl_Continue otherwise.
 */
forward Action:L4D_OnSetCampaignScores(&scoreA, &scoreB);

/**
 * @brief Called whenever CTerrorPlayer::RecalculateVersusScore(void) is invoked
 * @remarks Calculates an individual survivors health bonus from their current health and status.
 *
 * @return		Pl_Handled to block health bonus from being calculated.
*/
forward Action:L4D_OnRecalculateVersusScore(client);

/**
 * @brief Called whenever CDirector::TryOfferingTankBot is invoked
 * @remarks Is used for displaying the "X gets Tank" window and transferring Tank control
 *
 * @return 		Pl_Handled to block window from showing and to keep Tank Bot, Pl_Continue otherwise
 */
forward Action:L4D_OnTryOfferingTankBot(tank_index, &bool:enterStasis);

/**
 * @brief Called when CBaseAnimating::SelectWeightedSequence(int Activity) is invoked with tank attack activity
 * @remarks Called whenever a tank uses his primary (punch) or secondary (throw) attack
 *
 * @param client   the client that is playing as tank
 * @param sequence  current selected sequence for attack, option to override the return value with it
 * @remarks	sequences(punches): 38(uppercut), 41(right hook), 43(left hook), 44 and 45 (pounding the ground)
 * @remarks	sequences(throws): 46(undercut), 47(1handed overhand), 48(throw from the hip), 49(2handed overhand)
 *
 * @return 		Pl_Handled to override return value, Pl_Continue otherwise.
 */
forward Action:L4D_OnSelectTankAttack(client, &sequence);

/**
 * @brief Called whenever Director::SendInRescueVehicle(void) is invoked
 * @remarks Called when the last Finale stage is reached and the Rescue Means becomes 'available'.
 *			Take note this forward WILL fire upon using the native of the same function.
 *
 * @return 		Pl_Handled to block, Pl_Continue otherwise
 */
forward Action:L4D_OnSendInRescueVehicle();

/**
 * @brief Called whenever CTerrorPlayer::OnShovedBySurvivor(CTerrorPlayer, Vector&) is invoked
 * @remarks L4D only uses this on Special Infected
 *
 * @param client	the client that did the shoving
 * @param victim	the client that was shoved (CAUTION: retrieved from function pointer, dont meddle with it)
 * @param vector	Vector Angle of Shoveforce
 *
 * @return 		Pl_Handled to block melee effect (didn't block higher pounce), Pl_Continue otherwise.
 */
forward Action:L4D_OnShovedBySurvivor(client, victim, const Float:vector[3]);

/**
 * @brief Called whenever CTerrorWeapon::OnHit(CGameTrace &, Vector  const&, bool) is invoked
 * @remarks Called for every single shovable and even some of the unshovable entities in the game
 *
 * @param client	survivor who did the shoving
 * @param entity	entity that is about to get shoved
 * @param weapon	weapon that has been held while shoving
 * @param vector	not sure what are these coordinates, probably some kind of shove distance
 *
 * @return 		Pl_Handled to block, Pl_Continue otherwise
 */
forward Action:L4D_OnEntityShoved(client, entity, weapon, const Float:vector[3]);

/**
 * @brief Called whenever Director::OnMobRushStart(void) is invoked
 * @remarks called on random hordes, mini- and finale hordes, and boomer hordes, causes Zombies to attack
 *           Not called on "z_spawn mob", hook the console command and check arguments to catch plugin mobs
 *           This function is used to reset the Director's natural horde timer
 *
 * @return 		Pl_Handled to block, Pl_Continue otherwise
 */
forward Action:L4D_OnMobRushStart();

/**
 * @brief Called whenever Director::OnFirstSurvivorLeftSafeArea is invoked
 * @remarks A versus round is started when survivors leave the safe room, or force started
 *           after 90 seconds regardless.
 *
 * @param client  the survivor that left the safe area first
 *
 * @return 		Pl_Handled to block round from being started, Pl_Continue otherwise.
 */
forward Action:L4D_OnFirstSurvivorLeftSafeArea(client);

/**
 * @brief Called whenever CTerrorPlayer::OnEnterGhostState(CTerrorPlayer*) is invoked
 * @remarks This happens when a player enters ghost mode (or in finales auto-materialized)
 *
 * @param client  the client that has entered ghost mode
 */
forward L4D_OnEnterGhostState(client);

/**
 * @brief Get the team scores for the current map
 * @remarks The campaign scores are not set until the end of round 2,
 *           use L4D_GetCampaignScores to get them earlier.
 *
 * @deprecated This function can be called through SDKTools using CTerrorGameRules,
 *          and so you should switch off to using SDKTools instead of this native.
 *
 * @param logical_team  0 for A, 1 for B
 * @param campaign_score  true to get campaign score instead of map score
 * @return 		the logical team's map score
 *                      or -1 if the team hasn't played the round yet,
 *                or the team's campaign score if campaign_score = true
 */
native L4D_GetTeamScore(logical_team, campaign_score=false);

/**
 * @brief Restarts the round, switching the map if necessary
 * @remarks Set the map to the current map to restart the round
 *
 * @param map  the mapname it should go to after the round restarts
 * @return     1 always
 */
native L4D_RestartScenarioFromVote(const String:map[]);

/**
 * @brief Removes lobby reservation from a server
 * @remarks Sets the reservation cookie to 0,
 *           it is safe to call this even if it's unreserved.
 */
native L4D_LobbyUnreserve();

/**
 * @brief Checks if the server is currently reserved for a lobby
 * @remarks Server is automatically unreserved if it hibernates or
 *          if all players leave.
 *
 * @deprecated This will always return false on L4D2 or on Linux.
 *
 * @return     true if reserved, false if not reserved
 */
native bool:L4D_LobbyIsReserved();

/*
Makes the extension required by the plugins, undefine REQUIRE_EXTENSIONS
if you want to use it optionally before including this .inc file
*/
public Extension:__ext_geoip =
{
	name = "Left 4 Downtown",
	file = "left4downtown.ext",
#if defined AUTOLOAD_EXTENSIONS
	autoload = 1,
#else
	autoload = 0,
#endif
#if defined REQUIRE_EXTENSIONS
	required = 1,
#else
	required = 0,
#endif
};
