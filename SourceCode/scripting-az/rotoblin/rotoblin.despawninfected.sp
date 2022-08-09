/*
 * ============================================================================
 *
 *  Rotoblin
 *
 *  File:			rotoblin.despawninfected.sp
 *  Type:			Module
 *  Description:	Despawn infected commons who is too far behind the 
 *					survivors.
 * 	Credits:		SRSMod team for the original source for L4D2
 *					(http://code.google.com/p/srsmod/).
 *
 *  Copyright (C) 2010  Mr. Zero <mrzerodk@gmail.com>
 *  Copyright (C) 2017-2022  Harry <fbef0102@gmail.com>
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

// --------------------
//       Private
// --------------------

static	const	String:	CLASSNAME_INFECTED[]				= "infected";
static	const	String:	CLASSNAME_WITCH[]					= "witch";
static	const	String:	CLASSNAME_PHYSPROPS[]				= "prop_physics";

static	const	Float:	TRACE_TOLERANCE 					= 75.0;
static	const	Float:	COMMON_CHECK_INTERVAL 				= 1.0;
static	const	Float:	COMMON_RESPAWN_INTERVAL 			= 0.5;

static	const	Float:	DESPAWN_DISTANCE					= 700.0;
static	const	Float:	MIN_ADVANCE_DISTANCE				= 33.0;
static	const	Float:	MIN_COMMON_LIFETIME					= 15.0;
static 	const	Float:	NEAR_SAFEROOM_DISTANCE				= 1000.0;

static			Handle:	g_hCommonTimer						= INVALID_HANDLE;
static			Float:	g_fCommonLifetime[MAX_EDICTS+1]		= {0.0};
static					g_iCommonSpawnQueue					= 0;
static			Float:	g_fLastLowestSurvivorFlow			= 0.0;

static					g_iDebugChannel						= 0;
static	const	String:	DEBUG_CHANNEL_NAME[]				= "DespawnInfected";

// **********************************************
//                   Forwards
// **********************************************

/**
 * Plugin is starting.
 *
 * @noreturn
 */
public _DespawnInfected_OnPluginStart()
{
	HookPublicEvent(EVENT_ONPLUGINENABLE, _DI_OnPluginEnabled);
	HookPublicEvent(EVENT_ONPLUGINDISABLE, _DI_OnPluginDisabled);

	g_iDebugChannel = DebugAddChannel(DEBUG_CHANNEL_NAME);
	DebugPrintToAllEx("Module is now setup");
}

/**
 * Plugin is now enabled.
 *
 * @noreturn
 */
public _DI_OnPluginEnabled()
{
	for (new i = 1; i <= MAX_EDICTS; i++) g_fCommonLifetime[i] = 0.0;

	g_hCommonTimer = CreateTimer(COMMON_CHECK_INTERVAL, _DI_Check_Timer, _, TIMER_REPEAT);

	HookEvent("round_start", _DI_RoundStart_Event, EventHookMode_PostNoCopy);
	HookPublicEvent(EVENT_ONENTITYCREATED, _DI_OnEntityCreated);
	HookPublicEvent(EVENT_ONENTITYDESTROYED, _DI_OnEntityDestroyed);
	DebugPrintToAllEx("Module is now loaded");
}

/**
 * Plugin is now disabled.
 *
 * @noreturn
 */
public _DI_OnPluginDisabled()
{
	CloseHandle(g_hCommonTimer);

	UnhookEvent("round_start", _DI_RoundStart_Event, EventHookMode_PostNoCopy);
	UnhookPublicEvent(EVENT_ONENTITYCREATED, _DI_OnEntityCreated);
	UnhookPublicEvent(EVENT_ONENTITYDESTROYED, _DI_OnEntityDestroyed);
	DebugPrintToAllEx("Module is now unloaded");
}

/**
 * When an entity is created.
 *
 * @param entity		Entity index.
 * @param classname		Classname.
 * @noreturn
 */
public _DI_OnEntityCreated(entity, const String:classname[])
{
	if (!StrEqual(classname, CLASSNAME_INFECTED, false)) return;
	g_fCommonLifetime[entity] = GetGameTime();
}

/**
 * When an entity is destroyed.
 *
 * @param entity		Entity index.
 * @noreturn
 */
public _DI_OnEntityDestroyed(entity)
{
	g_fCommonLifetime[entity] = 0.0;
}

/**
 * Called when round start is fired.
 *
 * @param event			INVALID_HANDLE due to EventHookMode_PostNoCopy.
 * @param name			String containing the name of the event.
 * @param dontBroadcast	True if event was not broadcast to clients, false otherwise.
 * @noreturn
 */
public _DI_RoundStart_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	for (new i = 1; i <= MAX_EDICTS; i++) g_fCommonLifetime[i] = 0.0;
	DebugPrintToAllEx("Round start, resetting common life time");
}

/**
 * Called when check commons interval has elapsed.
 * 
 * @param timer			Handle to the timer object.
 * @return				Plugin_Stop to stop repeating, any other value for
 *						default behavior.
 */
public Action:_DI_Check_Timer(Handle:timer)
{
	if (!IsServerProcessing()) return Plugin_Continue; // If no survivors or server is empty, return plugin_continue

	new Float:lastSurvivorFlow = 0.0;
	new Float:firstSurvivorFlow = 0.0;
	new Float:checkAgainst = 0.0;
	new bool:foundOne = false;
	new firstSurvivor = 0;

	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
		{
			checkAgainst = L4D2Direct_GetFlowDistance(i);

			if (checkAgainst < lastSurvivorFlow || lastSurvivorFlow == 0.0)
			{
				lastSurvivorFlow = checkAgainst;
				foundOne = true;
			}

			if (checkAgainst > firstSurvivorFlow || firstSurvivorFlow == 0.0)
			{
				firstSurvivorFlow = checkAgainst;
				firstSurvivor = i;
			}
		}
	}

	if (!foundOne) return Plugin_Continue; // No valid survivors, return plugin_continue

	DebugPrintToAllEx("Found valid survivors, lowest flow %f, highest flow %f", lastSurvivorFlow, firstSurvivorFlow);

	DespawningCommons(lastSurvivorFlow, firstSurvivor);
	g_fLastLowestSurvivorFlow = lastSurvivorFlow;

	return Plugin_Continue;
}

/**
 * Called when respawn commons interval has elapsed.
 * 
 * @param timer			Handle to the timer object.
 * @return				Plugin_Stop to stop repeating, any other value for
 *						default behavior.
 */
public Action:_DI_RespawnInfected_Timer(Handle:timer)
{
	if (g_iCommonSpawnQueue < 1) return Plugin_Stop; // only work if there is a respawn needed, kill timer if not

	CheatCommand(_, "z_spawn", "infected auto");
	g_iCommonSpawnQueue--;

	DebugPrintToAllEx("Respawned common. Commons left in queue %i", g_iCommonSpawnQueue);

	return Plugin_Continue;
}

/**
 * Called on entity filtering.
 *
 * @param entity		Entity index.
 * @param contentsMask	Contents Mask.
 * @return				True to allow the current entity to be hit, otherwise false.
 */
public bool:_DI_TraceFilter(entity, contentsMask)
{
	if (entity <= MaxClients || !IsValidEntity(entity)) return false;

	decl String:classname[128];
	GetEdictClassname(entity, classname, sizeof(classname)); // also not zombies or witches, as unlikely that may be, or physobjects (= windows)
	if (StrEqual(classname, CLASSNAME_INFECTED, false) ||
		StrEqual(classname, CLASSNAME_WITCH, false) ||
		StrEqual(classname, CLASSNAME_PHYSPROPS, false))
	{
		return false;
	}

	return true;
}

// **********************************************
//                 Private API
// **********************************************

/**
 * Try despawn commons.
 *
 * @param lastSurvivorFlow	The survivor with lowest flow.
 * @param firstSurvivor	The survivor futherest ahead in the flow.
 * @noreturn
 */
static DespawningCommons(Float:lastSurvivorFlow, firstSurvivor)
{
	if (lastSurvivorFlow < DESPAWN_DISTANCE) return;

	new Float:flowDifference = (lastSurvivorFlow - g_fLastLowestSurvivorFlow);
	if (flowDifference < MIN_ADVANCE_DISTANCE)
	{
		DebugPrintToAllEx("Survivors haven't advanced enough, stop despawning. Difference from last check %f (min %f)", flowDifference, MIN_ADVANCE_DISTANCE);
		return;
	}

	if (IsNearEndSafeRoom(firstSurvivor))
	{
		DebugPrintToAllEx("Survivors are too close to the end saferoom, stop despawning");
		return;
	}

	decl Float:commonFlow, Float:vOrigin[3];
	
	new entity = MaxClients + 1;
	while ((entity = FindEntityByClassname(entity, CLASSNAME_INFECTED)) != INVALID_ENT_REFERENCE)
	{
		if(!IsValidEntity(entity)) continue;

		if (g_fCommonLifetime[entity] == 0.0) continue;

		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vOrigin);
		commonFlow = L4D2Direct_GetTerrorNavAreaFlow(L4D2Direct_GetTerrorNavArea(vOrigin));

		if (commonFlow <= 0)
			commonFlow = L4D2Direct_GetTerrorNavAreaFlow(Address:L4D_GetNearestNavArea(vOrigin));
		
		if (commonFlow <= 0) continue; // common is in a infected-only areas, continue

		if ((lastSurvivorFlow - DESPAWN_DISTANCE) <= commonFlow) continue; // common is close to the survivors, continue

		if ((GetGameTime() - g_fCommonLifetime[entity]) < MIN_COMMON_LIFETIME) continue; // common haven't been alive for enough time, continue

		if (IsVisibleToSurvivors(entity)) continue; // Common is visible to the survivors, continue

		// Remove common and add to respawn queue
		RemoveEntity(entity);

		if (g_iCommonSpawnQueue < 1)
		{
			CreateTimer(COMMON_RESPAWN_INTERVAL, _DI_RespawnInfected_Timer, _, TIMER_REPEAT);
		}
		g_iCommonSpawnQueue++;

		//PrintToChatAll("Despawned common %i and added to the respawn queue", entity);
	}
}

/**
 * Check to see if survivor is near end safe room.
 *
 * @param client		Client to check to be near saferoom.
 * @return				True if the client is close to the end saferoom.
 */
static bool:IsNearEndSafeRoom(client)
{
	decl Float:vSafeRoomOrigin[3];
	if (!GetEndSafeRoomOrigin(vSafeRoomOrigin)) return false;

	decl Float:vOrigin[3];
	GetClientAbsOrigin(client, vOrigin);

	if (GetVectorDistance(vOrigin, vSafeRoomOrigin) > NEAR_SAFEROOM_DISTANCE) return false;

	return true;
}

/**
 * Check if common is visible to the survivors.
 *
 * @param entity		Common entity index.
 * @return				True if survivors can see this common, false otherwise.
 */
static bool:IsVisibleToSurvivors(entity) // loops alive Survivors and checks entity for being visible
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
		{
			if (IsVisibleTo(i, entity)) return true;
		}
	}

	return false;
}

/**
 * Check if common is visible to the survivor.
 *
 * @param client		Survivor client index.
 * @param entity		Common entity index.
 * @return				True if survivors can see this common, false otherwise.
 */
static bool:IsVisibleTo(client, entity) // check an entity for being visible to a client
{
	decl Float:vAngles[3], Float:vOrigin[3], Float:vEnt[3], Float:vLookAt[3];

	GetClientEyePosition(client,vOrigin); // get both player and zombie position
	GetEntityAbsOrigin(entity, vEnt);

	MakeVectorFromPoints(vOrigin, vEnt, vLookAt); // compute vector from player to zombie
	GetVectorAngles(vLookAt, vAngles); // get angles from vector for trace

	// execute Trace
	new Handle:trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, _DI_TraceFilter);
	
	new bool:isVisible = false;
	if (TR_DidHit(trace))
	{
		decl Float:vStart[3];
		TR_GetEndPosition(vStart, trace); // retrieve our trace endpoint

		if ((GetVectorDistance(vOrigin, vStart, false) + TRACE_TOLERANCE) >= GetVectorDistance(vOrigin, vEnt))
		{
			isVisible = true; // if trace ray lenght plus tolerance equal or bigger absolute distance, you hit the targeted zombie
		}
	}
	else
	{
		isVisible = true;
	}

	CloseHandle(trace);
	return isVisible;
}

/**
 * Wrapper for printing a debug message without having to define channel index
 * everytime.
 *
 * @param format		Formatting rules.
 * @param ...			Variable number of format parameters.
 * @noreturn
 */
static DebugPrintToAllEx(const String:format[], any:...)
{
	decl String:buffer[DEBUG_MESSAGE_LENGTH];
	VFormat(buffer, sizeof(buffer), format, 2);
	DebugPrintToAll(g_iDebugChannel, buffer);
}