/*
 * ============================================================================
 *
 *  Rotoblin
 *
 *  File:			rotoblin.weaponcontrol.sp
 *  Type:			Module
 *  Description:	Replaces tier 2 weapons with tier 1
 *
 *  Copyright (C) 2010  Mr. Zero <mrzerodk@gmail.com>
 *  Copyright (C) 2017-2023  Harry <fbef0102@gmail.com>
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
//       Public
// --------------------

enum WEAPON_STYLE
{
	REPLACE_NO_WEAPONS = 0, // Don't replace any tier 2 weapons
	REPLACE_ALL_WEAPONS = 1 // Replace all tier 2 weapons
}

enum WEAPON_REPLACEMENT_ATTRIBUTES
{
	WEAPON_CLASSNAME,
	WEAPON_MODEL,
	WEAPON_REPLACECLASSNAME,
	WEAPON_REPLACEMODEL
}

#define WEAPON_REPLACEMENT_TOTAL 2 // Total amount of weapons to replace

// --------------------
//       Private
// --------------------

static	const	String:	WEAPON_REPLACEMENT_ARRAY[WEAPON_REPLACEMENT_TOTAL][WEAPON_REPLACEMENT_ATTRIBUTES][] = 
{
	// Assult rifle
	{
		"weapon_rifle_spawn",							// Classname
		"models/w_models/weapons/w_rifle_m16a2.mdl",	// Model
		"weapon_smg_spawn",								// Replacement classname
		"models/w_models/weapons/w_smg_uzi.mdl"			// Replacement model
	},

	// Auto shotgun
	{
		"weapon_autoshotgun_spawn",							// Classname
		"models/w_models/weapons/w_autoshot_m4super.mdl",	// Model
		"weapon_pumpshotgun_spawn",							// Replacement classname
		"models/w_models/weapons/w_shotgun.mdl"				// Replacement model
	}
};

static	const			DEFAULT_WEAPON_COUNT			= 5;
static	const	Float:	REPLACE_DELAY					= 0.1; /* This is for OnEntityCreated, it needs a small delay before being 
															    * able to replace the tier 2 weapon. */

static	WEAPON_STYLE:	g_iWeaponStyle					= REPLACE_ALL_WEAPONS;
static			Handle:	g_hWeaponStyle_Cvar				= INVALID_HANDLE;

static			Handle:	g_hWeaponsArray					= INVALID_HANDLE;
static	const			ARRAY_WEAPON_CELL_SIZE			= 64;
static	const			ARRAY_WEAPON_BLOCK				= 4; /* How many indexes a single weapon takes. Example a weapon takes 4 slots 
															  * because first index is classname, then model, origin and rotation. So
															  * thats index 4, 5, 6 and 7 in the array. */

static					g_iDebugChannel					= 0;
static	const	String:	DEBUG_CHANNEL_NAME[]			= "WeaponControl";
static bool:InSecondHalfOfRound;

// **********************************************
//                   Forwards
// **********************************************

/**
 * Plugin is starting.
 *
 * @noreturn
 */
public _WeaponControl_OnPluginStart()
{
	HookPublicEvent(EVENT_ONPLUGINENABLE, _WC_OnPluginEnabled);
	HookPublicEvent(EVENT_ONPLUGINDISABLE, _WC_OnPluginDisabled);

	decl String:buffer[10];
	IntToString(view_as<int>(g_iWeaponStyle), buffer, sizeof(buffer)); // Get default value for replacement style
	g_hWeaponStyle_Cvar = CreateConVarEx("weapon_style", buffer, 
		"How weapons will be replaced. 0 - Don't replace any weapons, 1 - Replace all tier 2 weapons", 
		FCVAR_NOTIFY);

	if (g_hWeaponStyle_Cvar == INVALID_HANDLE) ThrowError("Unable to create weapon style cvar!");
	AddConVarToReport(g_hWeaponStyle_Cvar); // Add to report status module
	UpdateWeaponStyle();

	g_iDebugChannel = DebugAddChannel(DEBUG_CHANNEL_NAME);
	DebugPrintToAllEx("Module is now setup");
}

/**
 * Plugin is now enabled.
 *
 * @noreturn
 */
public _WC_OnPluginEnabled()
{
	g_hWeaponsArray = CreateArray(128);
	if (g_hWeaponsArray == INVALID_HANDLE)
	{
		ThrowError("Failed to create weapons array");
	}

	HookEvent("round_start", _WC_RoundStart_Event, EventHookMode_PostNoCopy);
	HookEvent("round_end", _WC_RoundEnd_Event, EventHookMode_PostNoCopy);
	HookPublicEvent(EVENT_ONMAPEND, _WC_OnMapEnd);
	HookPublicEvent(EVENT_ONMAPSTART, _WC_OnMapStart);

	UpdateWeaponStyle();
	HookConVarChange(g_hWeaponStyle_Cvar, _WC_WeaponStyle_CvarChange);
	DebugPrintToAllEx("Module is now loaded");
}

public _WC_OnMapStart()
{
	InSecondHalfOfRound = false;
}

/**
 * Plugin is now disabled.
 *
 * @noreturn
 */
public _WC_OnPluginDisabled()
{
	UnhookEvent("round_start", _WC_RoundStart_Event, EventHookMode_PostNoCopy);
	UnhookEvent("round_end", _WC_RoundEnd_Event, EventHookMode_PostNoCopy);
	UnhookPublicEvent(EVENT_ONMAPEND, _WC_OnMapEnd);
	UnhookPublicEvent(EVENT_ONMAPSTART, _WC_OnMapStart);
	UnhookPublicEvent(EVENT_ONENTITYCREATED, _WC_OnEntityCreated);

	UnhookConVarChange(g_hWeaponStyle_Cvar, _WC_WeaponStyle_CvarChange);

	CloseHandle(g_hWeaponsArray);
	DebugPrintToAllEx("Module is now unloaded");
}

/**
 * Map is ending.
 *
 * @noreturn
 */
public _WC_OnMapEnd()
{
	UnhookPublicEvent(EVENT_ONENTITYCREATED, _WC_OnEntityCreated); // To prevent mass processing while changing map
	DebugPrintToAllEx("Map end");
}

/**
 * Weapon style cvar changed.
 *
 * @param convar		Handle to the convar that was changed.
 * @param oldValue		String containing the value of the convar before it was changed.
 * @param newValue		String containing the new value of the convar.
 * @noreturn
 */
public _WC_WeaponStyle_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	DebugPrintToAllEx("Weapon style cvar was changed. Old value %s, new value %s", oldValue, newValue);
	UpdateWeaponStyle();
}

/**
 * Called when round start event is fired.
 *
 * @param event			INVALID_HANDLE (post no copy data hook).
 * @param name			String containing the name of the event.
 * @param dontBroadcast	True if event was not broadcast to clients, false otherwise.
 * @noreturn
 */
public _WC_RoundStart_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (g_iWeaponStyle == REPLACE_NO_WEAPONS)
	{
		DebugPrintToAll(g_iDebugChannel, "Round start - Will not replace weapons");
		return; // Don't wish to replace any weapons, return
	}
	DebugPrintToAllEx("Round start - Will replace weapons");
	//ClearArray(g_hWeaponsArray); // Clear weapons array from last round
	CreateTimer(0.6, _WC_t_RoundStartDelay);

}


public Action:_WC_t_RoundStartDelay(Handle:timer)
{
	if(InSecondHalfOfRound && GetArraySize(g_hWeaponsArray) > 0) // If weapons array is not empty
	{
		RestoreAllTier2(); // Restore all tier 2 weapons from array
	}
	ClearArray(g_hWeaponsArray); // Clear array
	// Replace all tier 2 weapons that are already spawned
	for (new i = 0; i < WEAPON_REPLACEMENT_TOTAL; i++)
	{
		ReplaceAllTier2(WEAPON_REPLACEMENT_ARRAY[i][WEAPON_CLASSNAME], 
			WEAPON_REPLACEMENT_ARRAY[i][WEAPON_MODEL], 
			WEAPON_REPLACEMENT_ARRAY[i][WEAPON_REPLACECLASSNAME], 
			WEAPON_REPLACEMENT_ARRAY[i][WEAPON_REPLACEMODEL], 
			DEFAULT_WEAPON_COUNT);
	}
	HookPublicEvent(EVENT_ONENTITYCREATED, _WC_OnEntityCreated); // Hook OnEntityCreated for "late" spawn weapons,
}


/**
 * Called when round end event is fired.
 *
 * @param event			INVALID_HANDLE (post no copy data hook).
 * @param name			String containing the name of the event.
 * @param dontBroadcast	True if event was not broadcast to clients, false otherwise.
 * @noreturn
 */
public _WC_RoundEnd_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	InSecondHalfOfRound = true;
	DebugPrintToAllEx("Round end");
	UnhookPublicEvent(EVENT_ONENTITYCREATED, _WC_OnEntityCreated); // Unhook OnEntityCreated to avoid processing while the game "resets" all entities and capture our restoring of tier 2 weapons
/*
	if (GetArraySize(g_hWeaponsArray) > 0) // If weapons array is not empty
	{
		RestoreAllTier2(); // Restore all tier 2 weapons from array
		ClearArray(g_hWeaponsArray); // Clear array
	}
*/
}

/**
 * When an entity is created.
 *
 * @param entity		Entity index.
 * @param classname		Classname.
 * @noreturn
 */
public _WC_OnEntityCreated(entity, const String:classname[])
{
	for (new i = 0; i < WEAPON_REPLACEMENT_TOTAL; i++)
	{
		if (!StrEqual(classname, WEAPON_REPLACEMENT_ARRAY[i][WEAPON_CLASSNAME])) continue;

		new ref = EntIndexToEntRef(entity);

		DebugPrintToAllEx("OnEntityCreated - Late spawned tier 2. Entity %i (ref %i), classname \"%s\", new classname \"%s\"", 
			entity,
			ref,
			classname, 
			WEAPON_REPLACEMENT_ARRAY[i][WEAPON_REPLACECLASSNAME]);

		ReplaceTier2_Delayed(ref, 
			classname, 
			WEAPON_REPLACEMENT_ARRAY[i][WEAPON_MODEL], 
			WEAPON_REPLACEMENT_ARRAY[i][WEAPON_REPLACECLASSNAME], 
			WEAPON_REPLACEMENT_ARRAY[i][WEAPON_REPLACEMODEL], 
			DEFAULT_WEAPON_COUNT, 
			REPLACE_DELAY);
	}
}

/**
 * Called when the replace tier 2 timer interval has elapsed.
 * 
 * @param timer			Handle to the timer object.
 * @param data			Data passed to CreateTimer() when timer was created.
 * @noreturn
 */
public Action:_WC_ReplaceTier2_Delayed_Timer(Handle:timer, Handle:pack)
{
	decl String:classname[256], String:model[256], String:newClassname[256], String:newModel[256];

	// Read data pack
	ResetPack(pack);
	new entity = EntRefToEntIndex(ReadPackCell(pack));
	ReadPackString(pack, classname, sizeof(classname));
	ReadPackString(pack, model, sizeof(model));
	ReadPackString(pack, newClassname, sizeof(newClassname));
	ReadPackString(pack, newModel, sizeof(newModel));
	new count = ReadPackCell(pack);
	CloseHandle(pack);

	/* Check for entity invalidation */
	new bool:entInvalid = false;
	if (entity < 0 || entity > MAX_EDICTS || !IsValidEntity(entity))
	{
		DebugPrintToAllEx("ERROR: Replaced delayed tier 2 weapon; Entity index invalided! Entity %i, classname \"%s\", new classname \"%s\", count %i", entity, classname, newClassname, count);
		entInvalid = true;
	}
	else
	{
		decl String:buffer[256];
		GetEdictClassname(entity, buffer, sizeof(buffer));
		if (StrEqual(classname, buffer))
		{
			DebugPrintToAllEx("ERROR: Replaced delayed tier 2 weapon; Entity classname invalided! Entity %i, classname \"%s\", new classname \"%s\", count %i", entity, buffer, newClassname, count);
			entInvalid = true;
		}
	}

	if (entInvalid) // Oh no, we lost a tier 2
	{
		DebugPrintToAllEx("ERROR: Replaced delayed tier 2 weapon; Lost a tier 2 weapon! Time to panic, search for all tier 2 weapons of that classname!");
		ReplaceAllTier2(classname, model, newClassname, newModel, count); // Time to panic
		return;
	}

	StoreTier2(entity, model); // Store the tier 2 in the array
	ReplaceEntity(entity, newClassname, newModel, count); // Replace with tier 1
	DebugPrintToAllEx("Replaced delayed tier 2 weapon; entity %i, classname \"%s\", new classname \"%s\", count %i", entity, classname, newClassname, count);
}

// **********************************************
//                 Private API
// **********************************************

/**
 * Updates the global weapon style var with the cvar.
 *
 * @noreturn
 */
static UpdateWeaponStyle()
{
	g_iWeaponStyle = WEAPON_STYLE:GetConVarInt(g_hWeaponStyle_Cvar);
	DebugPrintToAllEx("Updated weapon style global var; %i", view_as<int>(g_iWeaponStyle));
}

/**
 * Replaces entity index with provided entity classname, with same origin and
 * rotation.
 *
 * @param entityRef		Entity reference to replace.
 * @param classname		Entity's classname.
 * @param model			Entity model path.
 * @param newClassname	Entity replacement classname.
 * @param newModel		Entity replacement model path.
 * @param count			Item count.
 * @param time			How much time before replacing the entity.
 * @noreturn
 */
static ReplaceTier2_Delayed(entityRef, const String:classname[], const String:model[], const String:newClassname[], const String:newModel[], count, const Float:time)
{
	new Handle:pack = CreateDataPack();
	WritePackCell(pack, entityRef);
	WritePackString(pack, classname);
	WritePackString(pack, model);
	WritePackString(pack, newClassname);
	WritePackString(pack, newModel);
	WritePackCell(pack, count);
	CreateTimer(time, _WC_ReplaceTier2_Delayed_Timer, pack);
}

/**
 * Stores the entity's classname, model, origin and rotation in the weapons array.
 *
 * @param entity		Entity to store.
 * @param classname		Entity's classname.
 * @param model			Entity's model path.
 * @noreturn
 */
static StoreTier2(entity, const String:model[])
{
	decl Float:origin[3], Float:rotation[3], String:classname[ARRAY_WEAPON_CELL_SIZE];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", origin);
	GetEntPropVector(entity, Prop_Send, "m_angRotation", rotation);
	GetEdictClassname(entity, classname, ARRAY_WEAPON_CELL_SIZE);

	PushArrayString(g_hWeaponsArray, classname);
	PushArrayString(g_hWeaponsArray, model);
	PushArrayArray(g_hWeaponsArray, origin, 3);
	PushArrayArray(g_hWeaponsArray, rotation, 3);

	DebugPrintToAllEx("Stored tier 2 info; classname \"%s\", model \"%s\", origin %f %f %f, rotation %f %f %f", classname, model, origin[0], origin[1], origin[2], rotation[0], rotation[1], rotation[2]);
}

/**
 * Stores and replaces all entities with same classname with another provided classname, model and item count
 *
 * @param classname		Entity classname to replace.
 * @param model			Entity's model path.
 * @param newClassname	Entity replacement classname.
 * @param newModel		Entity's new model path.
 * @param count			Item count.
 * @noreturn
 */
static ReplaceAllTier2(const String:classname[], const String:model[], const String:newClassname[], const String:newModel[], count)
{
	DebugPrintToAllEx("Replacing all tier 2 weapons; classname \"%s\", new classname \"%s\", count %i", classname, newClassname, count);
	new entity = -1, result;
	while ((entity = FindEntityByClassnameEx(entity, classname)) != -1)
	{
		StoreTier2(entity, model); // Store tier 2 info in array
		if (!(result = ReplaceEntity(entity, newClassname, newModel, count))) // If failed to replace
		{
			DebugPrintToAllEx("ERROR: Failed to replace tier 2 weapon! Entity %i, classname \"%s\", new classname \"%s\", model \"%s\"", entity, classname, newClassname, newModel);
			ThrowError("Failed to replace tier 2 weapon! Entity %i, classname \"%s\", new classname \"%s\", model \"%s\"", entity, classname, newClassname, newModel);
		}
		DebugPrintToAllEx("Replaced tier 2 weapon; entity %i, classname \"%s\", new entity %i, new classname \"%s\", count %i", entity, classname, result, newClassname, count);
	}
}

/**
 * Restores all tier 2 weapons from array.
 *
 * @noreturn
 */
static RestoreAllTier2()
{
	DebugPrintToAllEx("Restoring tier 2 weapons...");
	decl entity, String:classname[ARRAY_WEAPON_CELL_SIZE], String:model[ARRAY_WEAPON_CELL_SIZE], Float:origin[3], Float:rotation[3];

	new MaxTier2Weapons = GetArraySize(g_hWeaponsArray);
	for (new index = 0; index < MaxTier2Weapons; index += ARRAY_WEAPON_BLOCK)
	{
		GetArrayString(g_hWeaponsArray, index, classname, ARRAY_WEAPON_CELL_SIZE);
		GetArrayString(g_hWeaponsArray, index + 1, model, ARRAY_WEAPON_CELL_SIZE);
		GetArrayArray(g_hWeaponsArray, index + 2, origin, 3);
		GetArrayArray(g_hWeaponsArray, index + 3, rotation, 3);

		if (!(entity = CreateEntityByNameEx(classname, model, origin, rotation, DEFAULT_WEAPON_COUNT)))
		{
			ThrowError("Failed to restore tier 2 weapon! Classname \"%s\", model \"%s\", origin %f %f %f, rotation %f %f %f, count %i", classname, model, origin[0], origin[1], origin[2], rotation[0], rotation[1], rotation[2], DEFAULT_WEAPON_COUNT);
		}
		SetEntityRenderMode(entity, RENDER_NONE); // Hide the weapon
		DebugPrintToAllEx("Restored a tier 2 weapon; entity %i, classname \"%s\", model \"%s\", origin %f %f %f, rotation %f %f %f, count %i", entity, classname, model, origin[0], origin[1], origin[2], rotation[0], rotation[1], rotation[2], DEFAULT_WEAPON_COUNT);
	}
	DebugPrintToAllEx("Done restoring tier 2 weapons!");
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