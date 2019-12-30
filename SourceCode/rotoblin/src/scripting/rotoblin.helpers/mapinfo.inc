/*
 * ============================================================================
 *
 *  Rotoblin
 *
 *  File:			mapinfo.inc
 *  Type:			Helper
 *  Description:	Provides map functions for modules
 *
 *  Copyright (C) 2010  Mr. Zero <mrzerodk@gmail.com>
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

// Don't let the script be included more than once.
#if defined _helper_mapinfo
  #endinput
#endif
#define _helper_mapinfo

// --------------------
//       Private
// --------------------

static	const	String:	CLASSNAME_FINALETRIGGER[]	= "trigger_finale";
static	const	String:	CLASSNAME_CHANGELEVEL[]		= "info_changelevel";

// **********************************************
//                 Public API
// **********************************************

/**
 * Stores finale trigger origin in provided vector buffer.
 *
 * @prama vec			Vector buffer to store origin in.
 * @return				True if got coordinates for finale, false otherwise.
 */
stock bool:GetFinaleOrigin(Float:vec[3])
{
	if (FinaleFix_Check(vec)) return true; // Found a finale fix origin, return true

	new ent = FindEntityByClassname(-1, CLASSNAME_FINALETRIGGER);
	if (ent == -1) return false; // No finale trigger, return false

	GetEntityAbsOrigin(ent, vec); // Get the origin of the finale trigger
	return true; // Found finale trigger, return true
}

/**
 * Stores end safe room origin in provided vector buffer.
 *
 * @prama vec			Vector buffer to store origin in.
 * @return				True if got coordinates for saferoom, false otherwise.
 */
stock bool:GetEndSafeRoomOrigin(Float:vec[3])
{
	new ent = FindEntityByClassname(-1, CLASSNAME_CHANGELEVEL);
	if (ent == -1) return false; // No change level entity, return false (finale map)

	GetEntityAbsOrigin(ent, vec);
	return true;
}

// **********************************************
//                 Private API
// **********************************************

/**
 * Checks all finale fixes, if we need to apply a fix for the current map.
 *
 * @prama vec			Vector buffer to store origin in.
 * @return				True if got coordinates for finale, false otherwise.
 */
static bool:FinaleFix_Check(Float:vec[3])
{
	decl String:map[64];
	GetCurrentMap(map, sizeof(map));

	if (FinaleFix_NoMercy(map, vec)) return true; // No Mercy finale fix applied, return true
	if (FinaleFix_DeathToll(map, vec)) return true; // Death Toll finale fix applied, return true
	if (FinaleFix_BloodHarvest(map, vec)) return true; // Blood Harvest finale fix applied, return true
	if (FinaleFix_CrashCourse(map, vec)) return true; // Crash Course finale fix applied, return true
	if (FinaleFix_SuicideBiltz(map, vec)) return true; // Suicide Biltz finale fix applied, return true

	return false;
}

/**
 * Finale fix for No Mercy.
 *
 * @prama map			Current map string.
 * @prama vec			Vector buffer to store origin in.
 * @return				True if got coordinates for finale, false otherwise.
 */
static bool:FinaleFix_NoMercy(const String:map[], Float:vec[3])
{
	if (!StrEqual(map, "l4d_vs_hospital05_rooftop")) return false;

	vec[0] = 5711.0;
	vec[1] = 8487.0;
	vec[2] = 6142.0;

	return true;
}

/**
 * Finale fix for Death Toll.
 *
 * @prama map			Current map string.
 * @prama vec			Vector buffer to store origin in.
 * @return				True if got coordinates for finale, false otherwise.
 */
static bool:FinaleFix_DeathToll(const String:map[], Float:vec[3])
{
	if (!StrEqual(map, "l4d_vs_smalltown05_houseboat")) return false;

	vec[0] = 3866.0;
	vec[1] = -4647.0;
	vec[2] = -89.0;

	return true;
}

/**
 * Finale fix for Blood Harvest.
 *
 * @prama map			Current map string.
 * @prama vec			Vector buffer to store origin in.
 * @return				True if got coordinates for finale, false otherwise.
 */
static bool:FinaleFix_BloodHarvest(const String:map[], Float:vec[3])
{
	if (!StrEqual(map, "l4d_vs_farm05_cornfield")) return false;

	vec[0] = 6978.0;
	vec[1] = 1315.0;
	vec[2] = 336.0;

	return true;
}

/**
 * Finale fix for Crash Course.
 *
 * @prama map			Current map string.
 * @prama vec			Vector buffer to store origin in.
 * @return				True if got coordinates for finale, false otherwise.
 */
static bool:FinaleFix_CrashCourse(const String:map[], Float:vec[3])
{
	if (!StrEqual(map, "l4d_garage02_lots")) return false;

	vec[0] = 7132.0;
	vec[1] = 6474.0;
	vec[2] = 107.0;

	return true;
}

/**
 * Finale fix for Suicide Biltz.
 *
 * @prama map			Current map string.
 * @prama vec			Vector buffer to store origin in.
 * @return				True if got coordinates for finale, false otherwise.
 */
static bool:FinaleFix_SuicideBiltz(const String:map[], Float:vec[3])
{
	if (!StrEqual(map, "l4d_vs_stadium5_stadium")) return false;

	vec[0] = 795.0;
	vec[1] = 3625.0;
	vec[2] = 167.0;

	return true;
}