/*
 * ============================================================================
 *
 *  Original fixed Rotoblin module
 *
 *  File:			rotoblin.finalespawn.sp
 *  Type:			Module
 *  Description:	Reduces the spawn range on finales to normal spawning
 *					range.
 *	Credits:		Confogl Team, <confogl.googlecode.com>
 *
 *  Copyright (C) 2010  Mr. Zero <mrzerodk@gmail.com>
 *  Copyright (C) 2017-2022  Harry <fbef0102@gmail.com>
 *  This file is part of Rotoblin.
 *
 *  Rotoblin is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  Rotoblin is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with Rotoblin.  If not, see <http://www.gnu.org/licenses/>.
 *
 * ============================================================================
 */

// Same as convar "z_finale_spawn_safety_range"
// Convar "z_finale_spawn_safety_range" affects common zombie spawn and tank spawn, which causes nav issue on final map such as horde unable to spawn
// So we use plugin only for special infected

/*
 * ==================================================
 *                     Variables
 * ==================================================
 */

/*
 * --------------------
 *       Private
 * --------------------
 */

static	const			GHOST_SPAWN_STATE_TOO_CLOSE = 256;
static	const			GHOST_SPAWN_STATE_SPAWN_READY = 0;

static	const			MIN_SPAWN_RANGE = 200; //same as l4d2

static			bool:	g_bIsFinaleActive = false;
static			Handle:g_hFnalSpawn, bool:g_bCvarFinalSpawn;

/*
 * ==================================================
 *                     Forwards
 * ==================================================
 */

/**
 * Called on plugin start.
 *
 * @noreturn
 */
_FinaleSpawn_OnPluginStart()
{
	g_hFnalSpawn = CreateConVarEx("finalspawn_range",	"1", "Reduces the SI spawning range on finales to normal spawning range", _, true, 0.0, true, 1.0);

	Get_FS_Cvars();
	HookConVarChange(g_hFnalSpawn, _FS_FinalSpawn_CvarChange);

	HookPublicEvent(EVENT_ONPLUGINENABLE, _FS_OnPluginEnabled);
	HookPublicEvent(EVENT_ONPLUGINDISABLE, _FS_OnPluginDisabled);

}

/**
 * Called on plugin enabled.
 *
 * @noreturn
 */
public _FS_OnPluginEnabled()
{
	HookEvent("round_end", _FS_OnRoundChange_Event, EventHookMode_PostNoCopy);
	HookEvent("round_start", _FS_OnRoundChange_Event, EventHookMode_PostNoCopy);
	HookEvent("finale_start", _FS_OnFinaleStart_Event, EventHookMode_PostNoCopy);

	HookPublicEvent(EVENT_ONCLIENTPUTINSERVER, _FS_OnClientPutInServer);
}

/**
 * Called on plugin disabled.
 *
 * @noreturn
 */
public _FS_OnPluginDisabled()
{
	g_bIsFinaleActive = false;
	UnhookEvent("round_end", _FS_OnRoundChange_Event, EventHookMode_PostNoCopy);
	UnhookEvent("round_start", _FS_OnRoundChange_Event, EventHookMode_PostNoCopy);
	UnhookEvent("finale_start", _FS_OnFinaleStart_Event, EventHookMode_PostNoCopy);

	UnhookPublicEvent(EVENT_ONPLUGINENABLE, _FS_OnPluginEnabled);
	UnhookPublicEvent(EVENT_ONPLUGINDISABLE, _FS_OnPluginDisabled);
	UnhookPublicEvent(EVENT_ONCLIENTPUTINSERVER, _FS_OnClientPutInServer);

	UnhookConVarChange(g_hFnalSpawn, _FS_FinalSpawn_CvarChange);
}

public _FS_FinalSpawn_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (StrEqual(oldValue, newValue)) return;

	if (g_bIsFinaleActive){

		if (g_bCvarFinalSpawn)
			HookOrUnhookPreThinkPost(false);
		else
			HookOrUnhookPreThinkPost(true);
	}

	Get_FS_Cvars();
}

static HookOrUnhookPreThinkPost(bool:bHook)
{
	if (!g_bCvarFinalSpawn) return;

	for (new client = 1; client <= MaxClients; client++){

		if (!IsClientInGame(client) || IsFakeClient(client)) continue;

		if (bHook)
			SDKHook(client, SDKHook_PreThinkPost, _FS_SDKh_OnPreThinkPost);
		else
			SDKUnhook(client, SDKHook_PreThinkPost, _FS_SDKh_OnPreThinkPost);
	}
}

static Get_FS_Cvars()
{
	g_bCvarFinalSpawn = GetConVarBool(g_hFnalSpawn);
}

/**
 * Called when round start / end event is fired.
 *
 * @param event			Handle to event.
 * @param name			String containing the name of the event.
 * @param dontBroadcast	True if event was not broadcast to clients, false
 *						otherwise.
 * @noreturn
 */
public _FS_OnRoundChange_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (g_bIsFinaleActive)
		HookOrUnhookPreThinkPost(false);

	g_bIsFinaleActive = false;
}

/**
 * Called when finale start event is fired.
 *
 * @param event			Handle to event.
 * @param name			String containing the name of the event.
 * @param dontBroadcast	True if event was not broadcast to clients, false
 *						otherwise.
 * @noreturn
 */
public _FS_OnFinaleStart_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!g_bIsFinaleActive)
		HookOrUnhookPreThinkPost(true);

	g_bIsFinaleActive = true;
}

/**
 * Called on client put in server.
 *
 * @param client		Client index.
 * @noreturn
 */
public _FS_OnClientPutInServer(client)
{
	if (g_bIsFinaleActive && g_bCvarFinalSpawn && !IsFakeClient(client))
		SDKHook(client, SDKHook_PreThinkPost, _FS_SDKh_OnPreThinkPost);
}

/**
 * Called on client pre think.
 *
 * @param client		Client index.
 * @noreturn
 */
public _FS_SDKh_OnPreThinkPost(client)
{
	if (!IsClientInGame(client) ||
		GetClientTeam(client) != TEAM_INFECTED ||
		!IsPlayerGhost(client))
		return;

	//PrintToChatAll("%N - %d", client, GetGhostSpawnState(client));
	if (GetGhostSpawnState(client) == GHOST_SPAWN_STATE_TOO_CLOSE)
	{
		if (!IsGhostTooCloseToSurvivors(client))
		{
			SetPlayerGhostSpawnState(client, GHOST_SPAWN_STATE_SPAWN_READY);
		}
	}
}

/*
 * ==================================================
 *                    Private API
 * ==================================================
 */

/**
 * Returns whether ghost is too close to any survivors.
 *
 * @param client		Client index of ghost.
 * @return				True if too close to any survivor, false otherwise.
 */
static bool:IsGhostTooCloseToSurvivors(client)
{
	decl Float:survivorOrigin[3];
	decl Float:ghostOrigin[3];
	decl Float:fVector[3];
	GetClientAbsOrigin(client, ghostOrigin);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || GetClientTeam(i) != 2 || !IsPlayerAlive(i)) continue;
		
		GetClientAbsOrigin(i, survivorOrigin);

		MakeVectorFromPoints(ghostOrigin, survivorOrigin, fVector);

		if (GetVectorLength(fVector) <= MIN_SPAWN_RANGE) return true;
	}
	return false;
}

/**
 * Sets player ghost spawn state.
 *
 * @param client		Client index.
 * @param spawnState	Spawn state to set.
 * @noreturn
 */
static SetPlayerGhostSpawnState(client, spawnState)
{
	SetEntProp(client, Prop_Send, "m_ghostSpawnState", spawnState);
}

stock _FS_CvarDebug()
{
	decl bool:iVal;
	if ((iVal = GetConVarBool(g_hFnalSpawn)) != g_bCvarFinalSpawn)
		DebugLog("%d		|	%d		|	rotoblin_finalspawn_range", iVal, g_bCvarFinalSpawn);
}