/*
 * ============================================================================
 *
 * This file is part of the Rotoblin 2 project.
 *
 *  File:			rotoblin.MapInfo.sp
 *  Type:			Module
 *  Description:	...
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

#define		MODULE_TAG	"[MapInfo]"

#define		KV_NAME		"Rotoblin MapInfo"
#define		START_ROOM_RADIUS		150
/*
#if DEBUG_COMMANDS
	static	Handle:g_hMarker, g_iLaserCache;
#endif
*/
static 		Handle:g_hKv, String:g_sPatch[PLATFORM_MAX_PATH], Float:g_vStartSafeRoom[3], Float:g_vEndSafeRoom[3], String:g_sMap[64];

_MapInfo_OnPluginStart()
{
	g_hKv = CreateKeyValues(KV_NAME);

	BuildPath(Path_SM, g_sPatch, PLATFORM_MAX_PATH, "configs/R2/MapInfo.cfg");

	if (!FileToKeyValues(g_hKv, g_sPatch))
		SetFailState("Couldn't load Rotoblin MapInfo file! Patch <configs/R2/MapInfo.cfg>");

	RegAdminCmd("sm_mapinfo", Command_MapInfo, ADMFLAG_ROOT, "Adds start/end saferoom position to MapInfo");
	RegAdminCmd("sm_getmapinfo", Command_GetMapInfo, ADMFLAG_ROOT, "Prints start/end saferoom position from MapInfo");
/*
	#if DEBUG_COMMANDS
		RegAdminCmd("r2comp_tp",		Command_TeleportToSafeRoom, ADMFLAG_ROOT);
		RegAdminCmd("r2comp_dis",	Command_Distance, ADMFLAG_ROOT);
		RegAdminCmd("r2comp_entdis",	Command_EntityDistance, ADMFLAG_ROOT);
	#endif
*/
}

public Action:Command_MapInfo(client, args)
{
	if (!args || (args != 1 && args != 5)){

		ReplyToCommand(client, "!mapinfo <map name> <coordinates x y z> <start_pos 1|0>");
		ReplyToCommand(client, "!mapinfo <start_pos 1|0>");
		return Plugin_Handled;
	}
	if (args == 1 && !client){

		ReplyToCommand(client, "Usages from Console: mapinfo <map name> <coordinates x y z> <start_pos 1|0>");
		return Plugin_Handled;
	}

	decl String:sMap[64];

	if (args == 5)
		GetCmdArg(1, sMap, 64);
	else
		GetCurrentMap(sMap, 64);

	if (!IsMapValid(sMap)){

		ReplyToCommand(client, "Invalid map \"%s\"", sMap);
		return Plugin_Handled;
	}

	decl Float:vPos[3], String:sInput[64], bool:bStartRoom;

	if (args == 5){

		GetCmdArg(2, sInput, sizeof(sInput));
		vPos[0] = StringToFloat(sInput);
		GetCmdArg(3, sInput, sizeof(sInput));
		vPos[1] = StringToFloat(sInput);
		GetCmdArg(4, sInput, sizeof(sInput));
		vPos[2] = StringToFloat(sInput);
	}
	else
		GetClientAbsOrigin(client, vPos);

	GetCmdArg(args == 1 ? 1 : 5, sInput, sizeof(sInput));
	bStartRoom = bool:StringToInt(sInput);

	KvJumpToKey(g_hKv, sMap, true);

	if (bStartRoom)
		KvSetVector(g_hKv, "start_pos", vPos);
	else
		KvSetVector(g_hKv, "end_pos", vPos);

	KvRewind(g_hKv);
	KeyValuesToFile(g_hKv, g_sPatch);

	ReplyToCommand(client, "Added a new map data <%s> <%.1f %.1f %.1f> <%s>", sMap, vPos[0], vPos[1], vPos[2], bStartRoom ? "start_pos" : "end_pos");

	MI_RewriteGlobalVar(vPos, bStartRoom);
	return Plugin_Handled;
}

public Action:Command_GetMapInfo(client, args)
{
	ReplyToCommand(client, "SFR %.1f %.1f %.1f \nESR %.1f %.1f %.1f", g_vStartSafeRoom[0], g_vStartSafeRoom[1], g_vStartSafeRoom[2], g_vEndSafeRoom[0], g_vEndSafeRoom[1], g_vEndSafeRoom[2]);
	return Plugin_Handled;
}

_MI_OnMapStart()
{
	GetCurrentMap(g_sMap, 64);

	MI_WipeCoordinates();

	if (KvJumpToKey(g_hKv, g_sMap)){

		KvGetVector(g_hKv, "start_pos", g_vStartSafeRoom);
		KvGetVector(g_hKv, "end_pos", g_vEndSafeRoom);
	}
	else
		DebugLogEx("%s Couldn't load Rotoblin map data for \"%s\"", MODULE_TAG, g_sMap);

	KvGoBack(g_hKv);
/*
	#if DEBUG_COMMANDS
		g_iLaserCache = PrecacheModel("materials/sprites/laserbeam.vmt");

		if (g_hMarker != INVALID_HANDLE){
			KillTimer(g_hMarker);
			g_hMarker = INVALID_HANDLE;
		}
		g_hMarker = CreateTimer(1.0, MI_t_DrawMarker, _, TIMER_REPEAT);
	#endif
*/
}

static MI_WipeCoordinates()
{
	g_vStartSafeRoom[0] = 0.0;
	g_vStartSafeRoom[1] = 0.0;
	g_vStartSafeRoom[2] = 0.0;
	g_vEndSafeRoom[0] = 0.0;
	g_vEndSafeRoom[1] = 0.0;
	g_vEndSafeRoom[2] = 0.0;
}

static MI_RewriteGlobalVar(const Float:vOrg[3], bool:bStartRoom)
{
	if (bStartRoom){

		g_vStartSafeRoom[0] = vOrg[0];
		g_vStartSafeRoom[1] = vOrg[1];
		g_vStartSafeRoom[2] = vOrg[2];
	}
	else {

		g_vEndSafeRoom[0] = vOrg[0];
		g_vEndSafeRoom[1] = vOrg[1];
		g_vEndSafeRoom[2] = vOrg[2];
	}
}

bool:IsEntInStartSafeRoom(const Float:vOrg[3])
{
	return false;
	//return GetVectorDistance(g_vStartSafeRoom, vOrg) < START_ROOM_RADIUS;
}

bool:IsEntInEndSafeRoom(const Float:vOrg[3])
{
	return true;
	//return GetVectorDistance(g_vEndSafeRoom, vOrg) < START_ROOM_RADIUS;
}

bool:IsEntOutSideSafeRoom(const Float:vOrg[3])
{
	return false;
	//return !IsEntInStartSafeRoom(vOrg) && !IsEntInEndSafeRoom(vOrg);
}

bool:IsEntInStartSafeRoomEx(iEnt)
{
	decl Float:vOrg[3];
	GetEntityOrg(iEnt, vOrg);

	return IsEntInStartSafeRoom(vOrg);
}

bool:IsEntInEndSafeRoomEx(iEnt)
{
	decl Float:vOrg[3];
	GetEntityOrg(iEnt, vOrg);

	return IsEntInEndSafeRoom(vOrg);
}

stock bool:IsEntOutSideSafeRoomEx(iEnt)
{
	decl Float:vOrg[3];
	GetEntityOrg(iEnt, vOrg);

	return !IsEntInStartSafeRoom(vOrg) && !IsEntInEndSafeRoom(vOrg);
}

GetSafeRoomOrg(Float:vOrg[3], bool:bStartRoom)
{
	if (bStartRoom){

		vOrg[0] = g_vStartSafeRoom[0];
		vOrg[1] = g_vStartSafeRoom[1];
		vOrg[2] = g_vStartSafeRoom[2];
	}
	else {

		vOrg[0] = g_vEndSafeRoom[0];
		vOrg[1] = g_vEndSafeRoom[1];
		vOrg[2] = g_vEndSafeRoom[2];
	}
}

public Native_R2comp_IsStartEntity(Handle:plugin, numParams)
{
	new iEnt = GetNativeCell(1);

	if (!IsValidEntity(iEnt))
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid entity index %d", iEnt);

	return IsEntInStartSafeRoomEx(iEnt);
}

public Native_R2comp_IsEndEntity(Handle:plugin, numParams)
{
	new iEnt = GetNativeCell(1);

	if (!IsValidEntity(iEnt))
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid entity index %d", iEnt);

	return IsEntInEndSafeRoomEx(iEnt);
}

public Native_R2comp_GetSafeRoomOrigin(Handle:plugin, numParams)
{
	decl Float:vOrg[3];
	GetSafeRoomOrg(vOrg, GetNativeCell(2));
	SetNativeArray(1, vOrg, 3);
}
/*
#if DEBUG_COMMANDS
public Action:Command_Distance(client, agrs)
{
	decl Float:vOrg[3];
	GetClientAbsOrigin(client, vOrg);
	ReplyToCommand(client, "(Distance) SSR %.1f, ESR %.1f", GetVectorDistance(g_vStartSafeRoom, vOrg), GetVectorDistance(g_vEndSafeRoom, vOrg));
	return Plugin_Handled;
}

public Action:Command_EntityDistance(client, agrs)
{
	new ent = GetClientAimTarget(client, false);

	if (ent == INVALID_ENT_REFERENCE || !IsValidEntity(ent))
		return Plugin_Handled;

	decl Float:vOrg[3];
	GetEntityOrg(ent, vOrg);

	PrintToChat(client, "Ent %d %s %s", ent, IsEntInStartSafeRoom(vOrg) ? "(IN SSR)" : "(OutSide SSR)", IsEntInEndSafeRoom(vOrg) ? "(IN ESR)" : "(OutSide ESR)");
	return Plugin_Handled;
}

public Action:Command_TeleportToSafeRoom(client, agrs)
{
	TeleportEntity(client, !agrs ? g_vStartSafeRoom : g_vEndSafeRoom, NULL_VECTOR, NULL_VECTOR);
	return Plugin_Handled;
}

public Action:MI_t_DrawMarker(Handle:timer)
{
	// start save room
	new greenColor[4]	= {75, 255, 75, 255};
	TE_SetupBeamRingPoint(g_vStartSafeRoom, START_ROOM_RADIUS * 2.0, START_ROOM_RADIUS * 2.0 + 1.0, g_iLaserCache, 0, 0, 1, 1.0, 1.0, 1.0, greenColor, 0, 0);
	TE_SendToAll();

	// end save room
	TE_SetupBeamRingPoint(g_vEndSafeRoom, START_ROOM_RADIUS * 2.0, START_ROOM_RADIUS * 2.0 + 1.0, g_iLaserCache, 0, 0, 1, 1.0, 1.0, 1.0, greenColor, 0, 0);
	TE_SendToAll();

	// debug ring
	new purpleColor[4]	= {139, 0, 255, 255};
	TE_SetupBeamRingPoint(g_vStartSafeRoom, 1.0, 3.0, g_iLaserCache, 0, 0, 1, 1.0, 1.0, 1.0, purpleColor, 0, 0);
	TE_SendToAll();
}

GetLaserCaheIndex()
{
	return g_iLaserCache;
}
#endif
*/