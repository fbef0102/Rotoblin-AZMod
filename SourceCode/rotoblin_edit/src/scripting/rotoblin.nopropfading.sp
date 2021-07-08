/*
 * ============================================================================
 *
 *  Rotoblin
 *
 *  File:			rotoblin.nopropfading.sp
 *  Type:			Module
 *  Description:	Disables propfading while tank is active, and renabled
 *					once the tank is dead.
 *
 *  Copyright (C) 2010  Mr. Zero <mrzerodk@gmail.com>
 *  Copyright (C) 2017-2021  Harry <fbef0102@gmail.com>
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

static	const	String:	TANK_PROP_FADE_CVAR[]		= "sv_tankpropfade";

static	const	String:	PROP_PHYSICS[]				= "prop_physics";
static	const	String:	PROP_CAR_ALARM[]			= "prop_car_alarm";
static	const	String:	NETPROP_HASTANKGLOW[]		= "m_hasTankGlow";

static			Handle:	g_hPropArray				= INVALID_HANDLE;
static			Handle:	g_hTankHitPropArray			= INVALID_HANDLE;

static					g_iCachedTankClient			= 0;

static	const	Float:	FADE_PROCESS_ENTITY_TIME	= 0.1; // How often we process a single entity's alpha value when entity needs to fade away
static	const	Float:	FADE_TIME					= 4.0; // Max time it takes for a prop to fade away
static	const	Float:	FADE_AFTER_TANK_DEATH_TIME	= 20.0; // Time for props to fade away after tanks death
static	const	Float:	FADE_MAX_ALPHA				= 255.0; // Max alpha for entites

static					g_iFadePerStep				= 0;
static					g_iMaxFadeLoop				= 0;

static					g_iDebugChannel				= 0;
static	const	String:	DEBUG_CHANNEL_NAME[]		= "NoPropFading";

// **********************************************
//                   Forwards
// **********************************************

/**
 * Plugin is starting.
 *
 * @noreturn
 */
public _NoPropFading_OnPluginStart()
{
	HookPublicEvent(EVENT_ONPLUGINENABLE, _NPF_OnPluginEnabled);
	HookPublicEvent(EVENT_ONPLUGINDISABLE, _NPF_OnPluginDisabled);

	g_iFadePerStep = RoundToCeil(FADE_MAX_ALPHA / (FADE_TIME / FADE_PROCESS_ENTITY_TIME));
	g_iMaxFadeLoop = RoundToCeil(FADE_TIME / FADE_PROCESS_ENTITY_TIME);

	g_iDebugChannel = DebugAddChannel(DEBUG_CHANNEL_NAME);
	DebugPrintToAllEx("Module is now setup");
}

/**
 * Plugin is now enabled.
 *
 * @noreturn
 */
public _NPF_OnPluginEnabled()
{
	SetConVarBool(FindConVar(TANK_PROP_FADE_CVAR), false); // Disable valves inbuild prop fading

	g_hPropArray = CreateArray();
	g_hTankHitPropArray = CreateArray();

	HookTankEvent(TANK_SPAWNED, _NPF_TankSpawned_Event);
	HookTankEvent(TANK_KILLED, _NPF_TankKilled_Event);
	HookTankEvent(TANK_PASSED, _NPF_TankPassed_Event);

	HookEvent("round_start", _NPF_RoundStart_Event, EventHookMode_PostNoCopy);
	HookEvent("round_end", _NPF_RoundEnd_Event, EventHookMode_PostNoCopy);

	DebugPrintToAllEx("Module is now loaded");
}

/**
 * Plugin is now disabled.
 *
 * @noreturn
 */
public _NPF_OnPluginDisabled()
{
	SetConVarBool(FindConVar(TANK_PROP_FADE_CVAR), true);

	CloseHandle(g_hPropArray);
	CloseHandle(g_hTankHitPropArray);

	UnhookEvent("round_start", _NPF_RoundStart_Event, EventHookMode_PostNoCopy);
	UnhookEvent("round_end", _NPF_RoundEnd_Event, EventHookMode_PostNoCopy);

	DebugPrintToAllEx("Module is now unloaded");
}

/**
 * Called when round start event is fired.
 *
 * @param event			INVALID_HANDLE, post no copy data.
 * @param name			String containing the name of the event.
 * @param dontBroadcast	True if event was not broadcast to clients, false otherwise.
 * @noreturn
 */
public _NPF_RoundStart_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	UnhookAllPropPhysics();
	ClearTankHitProps();
	g_iCachedTankClient = 0;
	DebugPrintToAllEx("Round start");
}

/**
 * Called when round end event is fired.
 *
 * @param event			INVALID_HANDLE, post no copy data.
 * @param name			String containing the name of the event.
 * @param dontBroadcast	True if event was not broadcast to clients, false otherwise.
 * @noreturn
 */
public _NPF_RoundEnd_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	UnhookAllPropPhysics();
	ClearTankHitProps();
	g_iCachedTankClient = 0;
	DebugPrintToAllEx("Round end");
}

/**
 * On tank spawned event.
 *
 * @noreturn
 */
public _NPF_TankSpawned_Event()
{
	g_iCachedTankClient = GetTankClient();
	ClearTankHitProps();
	HookAllPropPhysics();
	DebugPrintToAllEx("Tank spawned");
}

/**
 * On tank killed event.
 *
 * @noreturn
 */
public _NPF_TankKilled_Event()
{
	g_iCachedTankClient = 0;
	UnhookAllPropPhysics();
	CreateTimer(FADE_AFTER_TANK_DEATH_TIME, _NPF_PropFade_Timer, _, TIMER_FLAG_NO_MAPCHANGE);
	DebugPrintToAllEx("Tank killed, props will fade in %f secs", FADE_AFTER_TANK_DEATH_TIME);
}

/**
 * On tank passed event.
 *
 * @noreturn
 */
public _NPF_TankPassed_Event()
{
	g_iCachedTankClient = GetTankClient();
	DebugPrintToAllEx("Tank passed");
}

/**
 * On prop takes damage post event.
 *
 * @param victim		Index that took damage.
 * @param attacker		Index that was cause of damage.
 * @param inflictor		Index that dealt damage.
 * @param damage		Damage dealt.
 * @param damagetype	Damage type.
 * @noreturn
 */
public _NPF_PropTakeDamage_Event(victim, attacker, inflictor, Float:damage, damagetype)
{
	if ((attacker == g_iCachedTankClient || // If attacker is tank
		FindValueInArray(g_hTankHitPropArray, inflictor) != -1) && // Or the inflictor is a prop the tank have hit (chain reaction)
		FindValueInArray(g_hTankHitPropArray, victim) == -1) // And the prop isn't already added to the array
	{
		PushArrayCell(g_hTankHitPropArray, victim);
		DebugPrintToAllEx("Tank hit prop %i, added to hit array", victim);
	}
}

/**
 * Called when the fade props timer interval has elapsed.
 * 
 * @param timer			Handle to the timer object.
 * @noreturn
 */
public Action:_NPF_PropFade_Timer(Handle:timer)
{
	if (!IsPluginEnabled() || IsTankInPlay()) return; // If plugin is disabled or tank is in play again, return
	DebugPrintToAllEx("Props will now fade");
	FadeTankHitProps();
}

/**
 * Called when the fade prop single timer interval has elapsed.
 * 
 * @param timer			Handle to the timer object.
 * @param pack			Handle to datapack.
 * @return				Plugin_Stop to stop the timer, any other value for
 *						default behavior.
 */
public Action:_NPF_PropFadeSingle_Timer(Handle:timer, Handle:pack)
{
	ResetPack(pack);
	new entity = ReadPackCell(pack);

	if (!IsPluginEnabled() || !IsValidTankProp(entity)) return Plugin_Stop;

	new bool:isInvisible = bool:ReadPackCell(pack);
	new curLoop = ReadPackCell(pack);

	curLoop++;

	if (curLoop > g_iMaxFadeLoop || isInvisible)
	{
		RemoveEdict(entity);
		DebugPrintToAllEx("Prop faded %i", entity);
		return Plugin_Stop;
	}

	new nextAlphaStep = RoundFloat(FADE_MAX_ALPHA) - (curLoop * g_iFadePerStep);
	if (nextAlphaStep < 0)
	{
		nextAlphaStep = 0;
		isInvisible = true;
	}
	DebugPrintToAllEx("Next alpha for prop %i: %i", entity, nextAlphaStep);
	SetEntityRenderColor(entity, _, _, _, nextAlphaStep);

	ResetPack(pack, true);
	WritePackCell(pack, entity);
	WritePackCell(pack, int:isInvisible);
	WritePackCell(pack, curLoop);

	return Plugin_Continue;
}

// **********************************************
//                 Private API
// **********************************************

/**
 * Makes all hit props by tank start fading.
 *
 * @noreturn
 */
static FadeTankHitProps()
{
	if (GetArraySize(g_hTankHitPropArray) == 0) return;

	decl entity, Handle:pack;
	for (new i = 0; i < GetArraySize(g_hTankHitPropArray); i++)
	{
		entity = GetArrayCell(g_hTankHitPropArray, i);
		if (!IsValidTankProp(entity)) continue;

		// Create package
		pack = CreateDataPack();
		WritePackCell(pack, entity);
		WritePackCell(pack, 0); // Is the prop already at 0 alpha
		WritePackCell(pack, 0); // How many times the timer have already processed the entity

		DebugPrintToAllEx("Prop %i will now fade", entity);

		SetEntityRenderMode(entity, RENDER_TRANSCOLOR); // Set render mode
		CreateTimer(FADE_PROCESS_ENTITY_TIME, _NPF_PropFadeSingle_Timer, pack, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE | TIMER_DATA_HNDL_CLOSE);
	}
	ClearTankHitProps();
}

/**
 * Clear array with all props tank have hit.
 *
 * @noreturn
 */
static ClearTankHitProps()
{
	ClearArray(g_hTankHitPropArray);
}

/**
 * Unhooks all prop physics that have been hooked.
 *
 * @noreturn
 */
static UnhookAllPropPhysics()
{
	if (GetArraySize(g_hPropArray) == 0) return;
	for (new i = 0; i < GetArraySize(g_hPropArray); i++)
	{
		SDKUnhook(GetArrayCell(g_hPropArray, i), SDKHook_OnTakeDamagePost, _NPF_PropTakeDamage_Event);
	}
	ClearArray(g_hPropArray);
}

/**
 * Hooks all prop physics that is valid tank props.
 *
 * @noreturn
 */
static HookAllPropPhysics()
{
	UnhookAllPropPhysics();

	for (new entity = FIRST_CLIENT; entity <= MAX_ENTITIES; entity++)
	{
		if (!IsValidTankProp(entity)) continue;

		SDKHook(entity, SDKHook_OnTakeDamagePost, _NPF_PropTakeDamage_Event);
		PushArrayCell(g_hPropArray, entity);
	}
}

/**
 * Wrapper for validation of entity as a tank prop.
 *
 * @param entity		Entity index.
 * @return				True if tank prop, false otherwise.
 */
static bool:IsValidTankProp(entity)
{
	if (entity < 1 || entity > MAX_ENTITIES || !IsValidEntity(entity)) return false;
	decl String:classname[32];
	GetEdictClassname(entity, classname, sizeof(classname));
	if (StrEqual(classname, PROP_PHYSICS))
	{
		return bool:GetEntProp(entity, Prop_Send, NETPROP_HASTANKGLOW, 1); // Only prop physics that has tank glow
	}
	return bool:StrEqual(classname, PROP_CAR_ALARM);
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