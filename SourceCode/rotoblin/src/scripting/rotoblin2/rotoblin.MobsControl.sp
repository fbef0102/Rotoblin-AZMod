/*
 * ============================================================================
 *
 * This file is part of the Rotoblin 2 project.
 *
 *  File:			rotoblin.MobsControl.sp
 *  Type:			Module
 *  Description:	Remove natural hordes while tank in game...
 *
 *  Copyright (C) 2012-2015 raziEiL <war4291@mail.ru>
 *  Copyright (C) 2017-2020 Harry <fbef0102@gmail.com>
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

#define		MC_TAG	 "[MobsControl]"

static		Handle:g_hMobTimer, Handle:g_hAllowHordes, Handle:g_hTankHordes, Handle:g_hCvarNoStartsCI, Handle:g_hCvarResetVomit, Handle:g_hCvarHordeSize, Handle:g_hCvarDisableOnFinal, bool:g_bIsFinalStage,
			g_iCvarMobTime, bool:g_bCvarTankHordes, bool:g_bCvarDisableOnFinal, bool:g_bCvarNoStartsCI, bool:g_bCvarResetVomit, g_iCvarHordeSize, bool:g_bEvents, bool:g_bLeftStartArea, g_iTick;

_MobsControl_OnPluginStart()
{
	g_hCvarHordeSize = FindConVar("z_mob_spawn_max_size");
	g_hAllowHordes			= CreateConVarEx("allow_natural_hordes",		"-1", "Sets whether natural hordes will spawn. (-1: director settings, 0: disable, > 0: spawn interval to cvar value)", _, true, -1.0);
	g_hTankHordes				= CreateConVarEx("disable_tank_hordes",		"0", "If set, natural hordes will not spawn while tank is in play. (0: enable, 1: disable).", _, true, 0.0, true, 1.0);
	g_hCvarNoStartsCI			= CreateConVarEx("remove_start_commons",		"0", "Removes all common infected near the saferoom and respawns them when one of survivors leaves the saferoom.", _, true, 0.0, true, 1.0);
	g_hCvarResetVomit			= CreateConVarEx("reset_natural_hordes",		"0", "If the survivors were vomited/panic event starts, natural hordes timer will be reseted to begin counting down again.", _, true, 0.0, true, 1.0);
	g_hCvarDisableOnFinal	= CreateConVarEx("disable_final_hordes",		"0", "If set, natural hordes will not spawn while final starts (radio button pressed). (0: enable, 1: disable).", _, true, 0.0, true, 1.0);

	#if DEBUG_COMMANDS
		RegAdminCmd("sm_mobtimer", Command_GetMobTimer, ADMFLAG_ROOT);
	#endif
}

_MC_OnPluginEnabled()
{
	g_bLeftStartArea = false;

	HookEvent("round_start",					_MC_ev_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_left_start_area",		_MC_ev_PlayerLeftStartArea, EventHookMode_PostNoCopy);
	HookEvent("create_panic_event",			_MC_ev_CreatePanicEvent, EventHookMode_PostNoCopy);
	HookEvent("player_now_it",					_MC_ev_CreatePanicEvent, EventHookMode_PostNoCopy);
	HookEvent("finale_radio_start", 			_MC_ev_RadioStart, EventHookMode_PostNoCopy);

	HookConVarChange(g_hAllowHordes,			_MC_Enable_CvarChange);
	HookConVarChange(g_hTankHordes,				_MC_TankHordes_CvarChange);
	HookConVarChange(g_hCvarNoStartsCI,		_MC_NoStartsCI_CvarChange);
	HookConVarChange(g_hCvarResetVomit,		_MC_ResetVomit_CvarChange);
	HookConVarChange(g_hCvarHordeSize,			_MC_HordeSize_CvarChange);
	HookConVarChange(g_hCvarDisableOnFinal,	_MC_DisableOnFinal_CvarChange);

	Update_MC_EnableConVar();
	Update_MC_TankHordesConVar();
	Update_MC_NoStartsCIConVar();
	Update_MC_ResetVomitConVar();
	Update_MC_HordeSizeConVar();
	Update_MC_DisableOnFinalConVar();
}

_MC_OnPluginDisabled()
{
	g_bLeftStartArea = true;

	UnhookEvent("round_start",				_MC_ev_RoundStart, EventHookMode_PostNoCopy);
	UnhookEvent("player_left_start_area",	_MC_ev_PlayerLeftStartArea, EventHookMode_PostNoCopy);
	UnhookEvent("create_panic_event",		_MC_ev_CreatePanicEvent, EventHookMode_PostNoCopy);
	UnhookEvent("player_now_it",			_MC_ev_CreatePanicEvent, EventHookMode_PostNoCopy);
	UnhookEvent("finale_radio_start", 		_MC_ev_RadioStart, EventHookMode_PostNoCopy);

	UnhookConVarChange(g_hAllowHordes,			_MC_Enable_CvarChange);
	UnhookConVarChange(g_hTankHordes,			_MC_TankHordes_CvarChange);
	UnhookConVarChange(g_hCvarNoStartsCI,		_MC_NoStartsCI_CvarChange);
	UnhookConVarChange(g_hCvarResetVomit,		_MC_ResetVomit_CvarChange);
	UnhookConVarChange(g_hCvarHordeSize,		_MC_HordeSize_CvarChange);
	UnhookConVarChange(g_hCvarDisableOnFinal,	_MC_DisableOnFinal_CvarChange);

	_MC_ToggleEvents(false);
}

_MC_OnMapEnd()
{
	g_hMobTimer = INVALID_HANDLE;
}

public _MC_ev_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_bLeftStartArea = false;
	g_bIsFinalStage = false;
	_MC_TogggleBotBehavior(true);

	if (g_bCvarNoStartsCI)
		CreateTimer(0.5, _MC_t_SlayCI, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);

	if (g_iCvarMobTime > 0)
		_MC_KillMobTimer();
}

public _MC_ev_PlayerLeftStartArea(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_bLeftStartArea = true;
	_MC_TogggleBotBehavior(false);

	DebugLog("%s Surv left start area. Timer _MC_t_SlayCI killed", MC_TAG);

	if (g_iCvarMobTime > 0){

		DebugLog("%s Mobs every %d sec", MC_TAG, g_iCvarMobTime);
		_MC_StartMobTimer();
	}
}

public _MC_ev_CreatePanicEvent(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (g_bCvarResetVomit && !g_bIsFinalStage){

		_MC_ResetMobTimer();
		DebugLog("%s Reset hordes timer (survivors were vomited/panic event starts).", MC_TAG);
	}
}

public _MC_ev_RadioStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (g_bCvarDisableOnFinal && IsFinalMap()){

		g_bIsFinalStage = true;
		_MC_KillMobTimer();
	}
}

// slay CI
public Action:_MC_t_SlayCI(Handle:timer)
{
	if (g_bLeftStartArea) return Plugin_Stop;

	new iEnt = -1, iCount;
	while ((iEnt = FindEntityByClassname(iEnt , "infected")) != INVALID_ENT_REFERENCE){

		AcceptEntityInput(iEnt, "Kill");
		iCount++;
	}

	if (iCount)
		DebugLog("%s Slayed %d common infected", MC_TAG, iCount);

	return Plugin_Continue;
}
// ---

// left4downtown
_MC_L4D_OnSpawnTank()
{
	if (g_iCvarMobTime > 0 && g_bCvarTankHordes && !g_bVehicleIncoming){

		if (_MC_KillMobTimer())
			DebugLog("%s Tank spawn. Hordes are turned OFF!", MC_TAG);
	}
}

public _MC_ev_EntityKilled(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (g_bCvarTankHordes && !g_bIsFinalStage && IsPlayerTank(GetEventInt(event, "entindex_killed")))
		CreateTimer(1.0, _MC_t_FindAnyTank, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:_MC_t_FindAnyTank(Handle:timer)
{
	if (FindTankClient()) return;

	_MC_StartMobTimer();
	DebugLog("%s Tank killed. Hordes are turned ON!", MC_TAG);
}

static _MC_ResetMobTimer()
{
	_MC_KillMobTimer();
	_MC_StartMobTimer();
}

static _MC_StartMobTimer()
{
	SetStartTime();
	g_hMobTimer = CreateTimer(float(g_iCvarMobTime), _MC_t_SpawnMob, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action:_MC_t_SpawnMob(Handle:timer)
{
	SetStartTime();
	L4DDirect_SetPendingMobCount(L4DDirect_GetPendingMobCount() + g_iCvarHordeSize);
}

static SetStartTime()
{
	g_iTick = RoundToNearest(GetEngineTime());
}

static bool:_MC_KillMobTimer()
{
	if (g_hMobTimer != INVALID_HANDLE){

		KillTimer(g_hMobTimer);
		g_hMobTimer = INVALID_HANDLE;
		return true;
	}
	return false;
}

static _MC_ToggleHordes(bool:bVal)
{
	if (bVal)
		AddConVarToTrack("director_no_mobs", "1");
	else
		ReleaseTrackedConVar("director_no_mobs");
}

static _MC_TogggleBotBehavior(bool:bStopRushing)
{
	DebugLog("%s Toggle bot behavior: %s", MC_TAG, bStopRushing ? "don't rush" : "default");

	if (bStopRushing){

		AddConVarToTrack("sb_separation_danger_min_range", "120");
		AddConVarToTrack("sb_separation_danger_max_range", "0");
	}
	else {

		ReleaseTrackedConVar("sb_separation_danger_min_range");
		ReleaseTrackedConVar("sb_separation_danger_max_range");
	}
}

public Native_R2comp_GetMobTimer(Handle:plugin, numParams)
{
	return MC_GetMobTimer();
}

MC_GetMobTimer()
{
	return g_iCvarMobTime < 1 ? -1 : g_hMobTimer == INVALID_HANDLE ? -1 : RoundToNearest(GetEngineTime()) - g_iTick;
}

public _MC_Enable_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (StrEqual(oldValue, newValue)) return;

	Update_MC_EnableConVar();
}

static Update_MC_EnableConVar()
{
	g_iCvarMobTime = GetConVarInt(g_hAllowHordes);

	_MC_ToggleEvents(bool:(g_iCvarMobTime > 0));
	_MC_ToggleHordes(bool:(g_iCvarMobTime >= 0));
}

public _MC_TankHordes_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (StrEqual(oldValue, newValue)) return;

	Update_MC_TankHordesConVar();
}

static Update_MC_TankHordesConVar()
{
	g_bCvarTankHordes = GetConVarBool(g_hTankHordes);
}

static _MC_ToggleEvents(bool:bHook)
{
	if (!g_bEvents && bHook){

		HookEvent("entity_killed",				_MC_ev_EntityKilled);
		g_bEvents = true;
	}
	else if (g_bEvents && !bHook){

		UnhookEvent("entity_killed",				_MC_ev_EntityKilled);
		g_bEvents = false;

		_MC_KillMobTimer();
	}
}

public _MC_NoStartsCI_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (StrEqual(oldValue, newValue)) return;

	Update_MC_NoStartsCIConVar();
}

Update_MC_NoStartsCIConVar()
{
	g_bCvarNoStartsCI = GetConVarBool(g_hCvarNoStartsCI);
}

public _MC_ResetVomit_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (StrEqual(oldValue, newValue)) return;

	Update_MC_ResetVomitConVar();
}

Update_MC_ResetVomitConVar()
{
	g_bCvarResetVomit = GetConVarBool(g_hCvarResetVomit);
}

public _MC_HordeSize_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (StrEqual(oldValue, newValue)) return;

	Update_MC_HordeSizeConVar();
}

Update_MC_HordeSizeConVar()
{
	g_iCvarHordeSize = GetConVarInt(g_hCvarHordeSize);
}

public _MC_DisableOnFinal_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (StrEqual(oldValue, newValue)) return;

	Update_MC_DisableOnFinalConVar();
}

Update_MC_DisableOnFinalConVar()
{
	g_bCvarDisableOnFinal = GetConVarBool(g_hCvarDisableOnFinal);
}

#if DEBUG_COMMANDS
public Action:Command_GetMobTimer(client, args)
{
	ReplyToCommand(client, "Mob timer: %d (-1 = Disabled)", MC_GetMobTimer());
	return Plugin_Handled;
}
#endif

stock _MC_CvarDump()
{
	decl iVal;
	if ((iVal = GetConVarInt(g_hAllowHordes)) != g_iCvarMobTime)
		DebugLog("%d		|	%d		|	rotoblin_allow_natural_hordes", iVal, g_iCvarMobTime);
	if (bool:(iVal = GetConVarBool(g_hTankHordes)) != g_bCvarTankHordes)
		DebugLog("%d		|	%d		|	rotoblin_disable_tank_hordes", iVal, g_bCvarTankHordes);
}
