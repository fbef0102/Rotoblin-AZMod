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
 *  Copyright (C) 2017-2025  Harry <fbef0102@gmail.com>
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

static	const	String:	CLASSNAME_CHANGELEVEL[]		= "info_changelevel";

// **********************************************
//                 Public API
// **********************************************

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