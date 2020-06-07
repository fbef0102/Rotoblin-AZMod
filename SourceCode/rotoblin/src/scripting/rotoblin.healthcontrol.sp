/*
 * ============================================================================
 *
 *  Rotoblin
 *
 *  File:			rotoblin.healthcontrol.sp
 *  Type:			Module
 *  Description:	Removes/replaces health items depending on settings
 *
 *  Copyright (C) 2010  Mr. Zero <mrzerodk@gmail.com>
 *  Copyright (C) 2017-2020  Harry <fbef0102@gmail.com>
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

// This used to pertain solely to replacing kits, but it now pertains to health kits and pills
enum HEALTH_STYLE
{
	REPLACE_NO_KITS = 0, // Don't replace any medkits with pills
	REPLACE_ALL_KITS = 1, // Replace all medkits with pills
	REPLACE_ALL_BUT_FINALE_KITS = 2, // Replace all medkits besides finale medkits
	SAFEROOM_AND_FINALE_PILLS_ONLY = 3, // Replace the saferoom and finale kits with pills and remove all other pills/kits
	ZONEMOD_PILLS = 4 // Replace all medkits with pills, only remove saferoom kits
}
// --------------------
//       Private
// --------------------

static	const	String:	CONVERT_PILLS_CVAR[]			= "director_convert_pills";
static	const	String:	CONVERT_PILLS_VS_CVAR[]		= "director_vs_convert_pills"; // setting this var to 0 will convert no pills to health kits

static	const	String:	FIRST_AID_KIT_CLASSNAME[]		= "weapon_first_aid_kit_spawn";
static	const	String:	PAIN_PILLS_CLASSNAME[]			= "weapon_pain_pills_spawn";
static	const	String:	MODEL_PAIN_PILLS[]				= "w_models/weapons/w_eq_painpills.mdl";
static 	const 	String: MODEL_FIRST_AID_KIT[]			= "w_models/weapons/w_eq_medkit.mdl";

static	const	Float:	REPLACE_DELAY					= 0.1; // Short delay on OnEntityCreated before replacing

static	const	Float:	KIT_FINALE_AREA					= 400.0;

static			bool:	g_bIsFinale						= false;
static			Float:	g_vFinaleOrigin[3]				= {0.0};

static HEALTH_STYLE: g_iHealthStyle					= REPLACE_ALL_KITS; // How we replace kits
static			Handle:	g_hHealthStyle_Cvar			= INVALID_HANDLE;

static					g_iDebugChannel					= 0;
static	const	String:	DEBUG_CHANNEL_NAME[]		= "HealthControl";

static          bool:   g_bHasMapStarted            = false;
static          bool:   g_bHaveRunRoundStart        = false;

new Float:SurvivorStart[3];
// **********************************************
//                   Forwards
// **********************************************

/**
 * Plugin is starting.
 *
 * @noreturn
 */

public _HealthControl_OnPluginStart()
{
	HookPublicEvent(EVENT_ONPLUGINENABLE, _HC_OnPluginEnable);
	HookPublicEvent(EVENT_ONPLUGINDISABLE, _HC_OnPluginDisable);

	decl String:buffer[10];
	IntToString(int:g_iHealthStyle, buffer, sizeof(buffer)); // Get default value for replacement style
	g_hHealthStyle_Cvar = CreateConVarEx("health_style", 
		buffer, 
		"How medkits and pills will be configured. 0 - Don't replace any medkits, 1 - Replace all medkits with pills, 2 - Replace all but finale medkits with pills, 3 - Replace safe room and finale kits with pills; remove all other health sources", 
		FCVAR_NOTIFY | FCVAR_PLUGIN);

	if (g_hHealthStyle_Cvar == INVALID_HANDLE) 
	{
		ThrowError("Unable to create health style cvar!");
	}
	
	AddConVarToReport(g_hHealthStyle_Cvar); // Add to report status module
	UpdateHealthStyle();

	g_iDebugChannel = DebugAddChannel(DEBUG_CHANNEL_NAME);
	DebugPrintToAllEx("Module is now setup");
}

/**
 * Plugin is now enabled.
 *
 * @noreturn
 */
public _HC_OnPluginEnable()
{
	if (g_iHealthStyle == REPLACE_NO_KITS) // If we do not want to replace any medkits
	{
		ResetConVar(FindConVar(CONVERT_PILLS_CVAR)); // Reset medkit conversion of pain pills cvar
		ResetConVar(FindConVar(CONVERT_PILLS_VS_CVAR));
	}
	else
	{
		SetConVarFloat(FindConVar(CONVERT_PILLS_CVAR), 0.0); // Otherwise set it 0 to disable director from spawning medkits
		SetConVarFloat(FindConVar(CONVERT_PILLS_VS_CVAR), 0.0);
	}

	HookEvent("round_start", _HC_RoundStart_Event, EventHookMode_PostNoCopy);
	HookEvent("player_left_start_area", _HC_player_left_start_area, EventHookMode_PostNoCopy);
	HookEvent("round_end", _HC_RoundEnd_Event, EventHookMode_PostNoCopy);
	HookPublicEvent(EVENT_ONMAPSTART, _HC_OnMapStart);
	HookPublicEvent(EVENT_ONMAPEND, _HC_OnMapEnd);

	UpdateHealthStyle();
	HookConVarChange(g_hHealthStyle_Cvar, _HC_HealthStyle_CvarChange);
	DebugPrintToAllEx("Module is now loaded");
}

/**
 * Plugin is now disabled.
 *
 * @noreturn
 */
public _HC_OnPluginDisable()
{
	ResetConVar(FindConVar(CONVERT_PILLS_CVAR));
	ResetConVar(FindConVar(CONVERT_PILLS_VS_CVAR));

	UnhookEvent("round_start", _HC_RoundStart_Event, EventHookMode_Post);
	UnhookEvent("player_left_start_area", _HC_player_left_start_area, EventHookMode_PostNoCopy);
	UnhookEvent("round_end", _HC_RoundEnd_Event, EventHookMode_PostNoCopy);
	UnhookPublicEvent(EVENT_ONMAPEND, _HC_OnMapEnd);
	UnhookPublicEvent(EVENT_ONENTITYCREATED, _HC_OnEntityCreated);
	UnhookConVarChange(g_hHealthStyle_Cvar, _HC_HealthStyle_CvarChange);

	DebugPrintToAllEx("Module is now unloaded");
}

public _HC_OnMapStart()
{
    g_bHasMapStarted = true;

    if (!g_bHaveRunRoundStart)
    {
        _HC_RoundStart_Event(INVALID_HANDLE, "", false);
    }
}

/**
 * Map is ending.
 *
 * @noreturn
 */
public _HC_OnMapEnd()
{
	g_bHaveRunRoundStart = false;
	g_bHasMapStarted = false;

	UnhookPublicEvent(EVENT_ONENTITYCREATED, _HC_OnEntityCreated);

	DebugPrintToAllEx("Map is ending, unhook OnEntityCreated");
}

/**
 * Health style cvar changed.
 *
 * @param convar		Handle to the convar that was changed.
 * @param oldValue		String containing the value of the convar before it was changed.
 * @param newValue		String containing the new value of the convar.
 * @noreturn
 */
public _HC_HealthStyle_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	DebugPrintToAllEx("Health style cvar was changed, update style var. Old value %s, new value %s", oldValue, newValue);
	UpdateHealthStyle();
}

public _HC_player_left_start_area(Handle:event, const String:name[], bool:dontBroadcast)
{
	new Handle:cvarEnforceReady = FindConVar("l4d_ready_enabled");
	if(cvarEnforceReady != INVALID_HANDLE)
	{
		if(GetConVarInt(cvarEnforceReady) == 1)
		{
			return;
		}
	}
	
	if(g_iHealthStyle == SAFEROOM_AND_FINALE_PILLS_ONLY||g_iHealthStyle == ZONEMOD_PILLS)
	{				
		// Finally: Now we either have 0 (standard) or 4 (finale) sets of pills remaining.
		// Give the survivors the pills that we've removed from the saferoom.
			GivePillsToSurvivors();
	}
}
public Native_GiveSurAllPills(Handle:plugin, numParams)
{
	if(g_iHealthStyle == SAFEROOM_AND_FINALE_PILLS_ONLY||g_iHealthStyle == ZONEMOD_PILLS)
	{				
		// Finally: Now we either have 0 (standard) or 4 (finale) sets of pills remaining.
		// Give the survivors the pills that we've removed from the saferoom.
			GivePillsToSurvivors();
	}
}

/**
 * Called when round start event is fired.
 *
 * @param event			INVALID_HANDLE, post no copy data.
 * @param name			String containing the name of the event.
 * @param dontBroadcast	True if event was not broadcast to clients, false otherwise.
 * @noreturn
 */
public _HC_RoundStart_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!g_bHasMapStarted)
	{
		return; // Map have not started yet, do not replace anything until - fix for SourceMod 1.4
	}
	g_bHaveRunRoundStart = true;

	if (g_iHealthStyle == REPLACE_NO_KITS)
	{
		DebugPrintToAllEx("Round start - Will not replace medkits");
		return; // Not replacing any medkits, return
	}
	
	DebugPrintToAllEx("Round start - Running health control");

	DetermineIfMapIsFinale();
	UpdateStartingHealthItems();
	
	// Hook on entity created for late spawned medkits
	HookPublicEvent(EVENT_ONENTITYCREATED, _HC_OnEntityCreated);
}

/**
 * Called when round end event is fired.
 *
 * @param event			INVALID_HANDLE, post no copy data.
 * @param name			String containing the name of the event.
 * @param dontBroadcast	True if event was not broadcast to clients, false otherwise.
 * @noreturn
 */
public _HC_RoundEnd_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	UnhookPublicEvent(EVENT_ONENTITYCREATED, _HC_OnEntityCreated);
	DebugPrintToAllEx("Round end");
}

/**
 * When an entity is created.
 *
 * @param entity		Entity index.
 * @param classname		Classname.
 * @noreturn
 */
public _HC_OnEntityCreated(entity, const String:classname[])
{
	// If we're running the mode where all extra pills and kits are removed, we need to jump in first
	if (( g_iHealthStyle == SAFEROOM_AND_FINALE_PILLS_ONLY)&& 
		StrEqual(classname, PAIN_PILLS_CLASSNAME))
	{						
		new entRef = EntIndexToEntRef(entity);
		CreateTimer(REPLACE_DELAY, _HC_RemoveItem_Delayed_Timer, entRef);
	} 	
	else if(( g_iHealthStyle == ZONEMOD_PILLS)&& 
		StrEqual(classname, PAIN_PILLS_CLASSNAME) && g_bIsFinale)
	{
		new entRef = EntIndexToEntRef(entity);
		CreateTimer(REPLACE_DELAY, _HC_RemoveItem_Delayed_Timer, entRef);
	}
	else if(StrEqual(classname, FIRST_AID_KIT_CLASSNAME) && ShouldReplaceKitWithPills(entity)) 
	{		
		new entRef = EntIndexToEntRef(entity);
		CreateTimer(REPLACE_DELAY, _HC_ReplaceKit_Delayed_Timer, entRef); // Replace medkit
		DebugPrintToAllEx("Late spawned medkit, timer created. Entity %i", entity);
	}
}

public Action:_HC_RemoveItem_Delayed_Timer(Handle:timer, any:entRef)
{
	new entity = EntRefToEntIndex(entRef);		
	SafelyRemoveEdict(entity);
	DebugPrintToAllEx("Removed item");
}

/**
 * Called when the replace kit timer interval has elapsed.
 * 
 * @param timer			Handle to the timer object.
 * @param medkitEntRef	Entity reference to the medkit to be removed
 * @noreturn
 */
public Action:_HC_ReplaceKit_Delayed_Timer(Handle:timer, any:medkitEntRef)
{
	new entity = EntRefToEntIndex(medkitEntRef);
	
	if (entity < 0 || entity > MAX_ENTITIES || !IsValidEntity(entity)) 
	{
		DebugPrintToAllEx("ERROR: When replacing medkit or pills, entity (index: %i) invalidated!", entity);
		return;
	}

	// check just in case, by some miracle (or our own incompetence), the kit has swapped to some other entity type
	decl String:classname[64];
	GetEdictClassname(entity, classname, 64);
	if (!StrEqual(classname, FIRST_AID_KIT_CLASSNAME)) 
	{
		DebugPrintToAllEx("ERROR: was trying to replace medkit, but ent %i 's classname is now %s", entity, classname);
		return;
	}
	ReplaceKitWithPills(entity);	
}

// **********************************************
//                 Public API
// **********************************************

/**
 * Return current health style.
 *
 * @return				Health style.
 */
stock HEALTH_STYLE:GetHealthStyle()
{
	return g_iHealthStyle;
}

// **********************************************
//                 Private API
// **********************************************

/**
 * Updates the global health style variable with the cvar.
 *
 * @noreturn
 */
static UpdateHealthStyle()
{
	g_iHealthStyle = HEALTH_STYLE:GetConVarInt(g_hHealthStyle_Cvar);
	DebugPrintToAllEx("Updated global style variable; %i", int:g_iHealthStyle);
}


static bool:Is_Final_Stage()//非官方圖最後一關
{
	decl String:mapbuf[32];
	GetCurrentMap(mapbuf, sizeof(mapbuf));
	if(StrEqual(mapbuf, "l4d_vs_city17_05")||
	StrEqual(mapbuf, "l4d_vs_deadflagblues05_station")||
	StrEqual(mapbuf, "l4d_ihm05_lakeside")||
	StrEqual(mapbuf, "l4d_vs_stadium5_stadium")||
	StrEqual(mapbuf, "l4d_dbd_new_dawn")||
	StrEqual(mapbuf, "l4d_jsarena04_arena")
	)
	{
		g_bIsFinale = true;
		return true;
	}
	return false;
}
/**
 * Replaces or removes items present at the start of the round.  Logic run is based on the chosen health style.
 * 
 */
static UpdateStartingHealthItems()
{	
	new entity = -1;
	/*
	//尋找地圖中的藥丸與治療包
	while ( ((entity = FindEntityByClassnameEx(entity, PAIN_PILLS_CLASSNAME)) != -1) )
	{
		if(!IsValidEntity(entity))
			continue;
			
		decl Float:entityPos[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", entityPos);	
		LogMessage("PILLS here1 %d: %f %f %f",entity,entityPos[0],entityPos[1],entityPos[2]);	
	}
	entity = -1;
	while ( ((entity = FindEntityByClassnameEx(entity, FIRST_AID_KIT_CLASSNAME)) != -1) )
	{
		if(!IsValidEntity(entity))
			continue;
			
		decl Float:entityPos[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", entityPos);	
		LogMessage("KITS here1 %d: %f %f %f",entity,entityPos[0],entityPos[1],entityPos[2]);	
	}
	*/
	
	decl SaferoomKits[4];
	DebugPrintToAllEx("Updating starting health items.");
	if (g_iHealthStyle == ZONEMOD_PILLS||g_iHealthStyle == SAFEROOM_AND_FINALE_PILLS_ONLY)//only remove saferoom medkits
	{
		//find where the survivors start so we know which medkits to replace,
		FindSurvivorStart();
		//and remove the medkits
		RemoveMedkits(SaferoomKits);
	}
	
	if(g_iHealthStyle == REPLACE_ALL_BUT_FINALE_KITS || g_iHealthStyle == REPLACE_ALL_KITS) 
	{
		FindSurvivorStart();
		ReplaceSafeRoomMedkits(SaferoomKits);
	}
	
	//非官方圖最後一關
	new k =0;
	entity = -1;
	decl String:mapbuf[32];
	GetCurrentMap(mapbuf, sizeof(mapbuf));
	new pillsleft = GetConVarInt(FindConVar("survivor_limit"));
	if(Is_Final_Stage())//非官方圖救援關四顆藥丸符合當前人類數量
	{
		if(g_iHealthStyle == SAFEROOM_AND_FINALE_PILLS_ONLY||g_iHealthStyle == ZONEMOD_PILLS)
			RemoveAllPills();

		while ((entity = FindEntityByClassnameEx(entity, FIRST_AID_KIT_CLASSNAME)) != -1)
		{
			if(!(entity==SaferoomKits[0]||entity==SaferoomKits[1]||entity==SaferoomKits[2]||entity==SaferoomKits[3]))//全部醫療包變成藥丸
			{
				if(k==1&&g_iHealthStyle == REPLACE_ALL_BUT_FINALE_KITS) {ReplaceEntity(entity, FIRST_AID_KIT_CLASSNAME, MODEL_FIRST_AID_KIT, 1);return;}
				if(pillsleft<=0)
					RemoveEdict(entity);
				else if(pillsleft>=5)
					{ReplaceKitWithPills(entity);ReplaceKitWithPills(entity);}
				else
					ReplaceKitWithPills(entity);
				pillsleft--;
				k++;
			}
		}
		
		return;
	}
	
	
	//救援關醫療包變成藥丸,非救援關 移除所有kits
	while ((entity = FindEntityByClassnameEx(entity, FIRST_AID_KIT_CLASSNAME)) != -1)
	{
		//decl Float:entityPos[3];
		//GetEntPropVector(entity, Prop_Send, "m_vecOrigin", entityPos);	
		//LogMessage("KITS here2 %d: %f %f %f: %d,%d,%d,%d",entity,entityPos[0],entityPos[1],entityPos[2],SaferoomKits[0],SaferoomKits[1],SaferoomKits[2],SaferoomKits[3]);
		if(!(entity==SaferoomKits[0]||entity==SaferoomKits[1]||entity==SaferoomKits[2]||entity==SaferoomKits[3]))//全部醫療包變成藥丸
		{
			if(g_bIsFinale)
			{
				if(k==1&&g_iHealthStyle == REPLACE_ALL_BUT_FINALE_KITS) {ReplaceEntity(entity, FIRST_AID_KIT_CLASSNAME, MODEL_FIRST_AID_KIT, 1);return;}
				ReplaceKitWithPills(entity);
				k++;
			}
			else if(g_iHealthStyle != REPLACE_ALL_BUT_FINALE_KITS)
				SafelyRemoveEdict(entity);
		}
	}
				
	if(g_iHealthStyle == REPLACE_ALL_KITS || g_iHealthStyle == REPLACE_ALL_BUT_FINALE_KITS) return;
	
	// Then, if we're using the hardcore setting, remove all pills from the map excluding the finale sets
	if(g_iHealthStyle == SAFEROOM_AND_FINALE_PILLS_ONLY)
	{		
		if(g_bIsFinale)
		{
			// We want to remove all the pills excluding the finale pills
			decl finale_pills[4];
			if(TryGetFinalePillEntities(finale_pills))
			{
				RemoveAllPillsExcluding(finale_pills);//把救援關的四顆藥丸符合當前人類數量
			}
		}		
		else
		{
			RemoveAllPills();
		}
		DebugPrintToAllEx("Finished removing pills.");
	}
	
	decl finale_kits[4];
	if(g_iHealthStyle == ZONEMOD_PILLS&&TryGetFinalePillEntities(finale_kits))//把救援關的四顆藥丸符合當前人類數量
	{
		RemoveAllPillsExcluding(finale_kits);
	}
}

/**
 * Removes all sets of pills from the map
 *
 * @noreturn
 */
static RemoveAllPills()
{
	DebugPrintToAllEx("Removing all pills");
	new removedCount = 0;
	new entity = -1;
	while ((entity = FindEntityByClassnameEx(entity, PAIN_PILLS_CLASSNAME)) != -1)
	{		
		if(SafelyRemoveEdict(entity))
		{			
			removedCount++;
			DebugPrintToAllEx("Removed pills (ent: %i)", entity);
		}
		else
		{
			DebugPrintToAllEx("Failed to remove pills (ent: %i)", entity);
		}
	}
	
	DebugPrintToAllEx("Removed %i sets of pills", removedCount);
}

/**
 * Removes all sets of pills from the map, excluding the 4 sets contained in the supplied array
 *
 * @param pills the pills to exclude from removal
 * @noreturn
 */
static RemoveAllPillsExcluding(pills[4])
{	
	DebugPrintToAllEx("Removing all pills excluding finale pills.");
		
	new removedCount = 0;
	new entity = -1;
	new pillsleft = GetConVarInt(FindConVar("survivor_limit"));
	while ((entity = FindEntityByClassnameEx(entity, PAIN_PILLS_CLASSNAME)) != -1)
	{		
		if(!IsValidEntity(entity))
		{
			DebugPrintToAllEx("Invalid entity.  Skipping.  Entity: %i", entity);
			continue;
		}
			
		new bool:shouldRemove = true;
		DebugPrintToAllEx("Testing ent %i (pills) to see whether we should remove it.", entity);
				
		for(new j = 0; j < 4; j++)
		{			
			if(entity == pills[j])//rescue pills
			{
				DebugPrintToAllEx("Pills (ent: %i) won't be removed.", entity);
				shouldRemove = false;
				if(pillsleft<=0)
					shouldRemove = true;
				pillsleft--;
				//LogMessage("%d %d",pillsleft,shouldRemove);
			}				
		}		
		
		if(shouldRemove)
		{
			//LogMessage("remove");
			if(SafelyRemoveEdict(entity))
			{
				removedCount++;
				DebugPrintToAllEx("Removed (non-finale) pills (ent: %i)", entity);
			}
			else
			{
				DebugPrintToAllEx("Failed to remove (non-finale) pills (ent: %i)", entity);
			}
		}
	}
	for(new i=0;pillsleft>=1;i++,pillsleft--)
	{
		ReplaceKitWithPills(pills[i]);
		ReplaceKitWithPills(pills[i]);
		//ReplaceEntity(pills[i], FIRST_AID_KIT_CLASSNAME, MODEL_FIRST_AID_KIT, 1);
		if(i==3) i=0;
	}

	DebugPrintToAllEx("Removed %i sets of pills", removedCount);
}

/**
 * Dishes out pills to the survivors
 * 
 * @noreturn
 */
static GivePillsToSurvivors()
{
	DebugPrintToAllEx("Giving pills to survivors.");
	new String:cmdGive[] = "give";
	new originalCmdFlags = GetCommandFlags(cmdGive);
	
	// Basically, make the command a non-cheat, execute it and then reset its flags.
	SetCommandFlags(cmdGive, originalCmdFlags & ~FCVAR_CHEAT);
	
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i) && IsClientInGame(i) && GetClientTeam(i) == 2)
		{			
			FakeClientCommand(i, "give pain_pills");
		}				
	}
	
	SetCommandFlags(cmdGive, originalCmdFlags);
}

/**
 * Determines whether the map is the finale and sets the global flag to identify it
 * 
 * @noreturn
 */
static DetermineIfMapIsFinale()
{	
	decl String:mapbuf[32];
	GetCurrentMap(mapbuf, sizeof(mapbuf));
	if (GetFinaleOrigin(g_vFinaleOrigin))
	{
		g_bIsFinale = true;
		DebugPrintToAllEx("Map is finale. Finale origin %f %f %f", g_vFinaleOrigin[0], g_vFinaleOrigin[1], g_vFinaleOrigin[2]);
	}
	else
	{
		g_bIsFinale = false;
		DebugPrintToAllEx("Map is not the finale");
	}
}

/**
 * Predicate used to determine whether we should replace kits with pills
 * @param entity 	medkit entity to be considered for replacement
 * @return			whether the kit should be replaced with pills
 */
static bool:ShouldReplaceKitWithPills(entity)
{
	if ((g_bIsFinale && 
		g_iHealthStyle == REPLACE_ALL_BUT_FINALE_KITS && 
		EntityIsInsideFinaleArea(entity))||
		g_iHealthStyle == REPLACE_NO_KITS||
		g_iHealthStyle == REPLACE_ALL_BUT_FINALE_KITS)
	{
		// Finale medkit and we're not replacing them; can't touch this!
		//or REPLACE_NO_KITS
		return false;					
	}			
	
	return true;
}

/**
 * Replaces medkit with pills unless the health style precludes it
 * @param entity the medkit entity to be considered for replacement
 * @noreturn				
 */
static ReplaceKitWithPills(entity)
{	
	new result = ReplaceEntity(entity, PAIN_PILLS_CLASSNAME, MODEL_PAIN_PILLS, 1);
	if (!result)
	{
		ThrowError("Failed to replace medkit with pills! Entity %i", entity);
	}
	DebugPrintToAllEx("Medkit (entity %i) replaced with pills (entity %i)", entity, result);	
}

/**
 * Determines whether an entity is within a given radius of the finale trigger
  *
 * @param entity the entity
 * @return whether the entity is inside the finale radius.
 */
static bool:EntityIsInsideFinaleArea(entity)
{	
	decl Float:origin[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", origin);
	if (GetVectorDistance(g_vFinaleOrigin, origin) <= KIT_FINALE_AREA) 
	{
		DebugPrintToAllEx("Entity (entity %i) is within finale area", entity);
		return true; 
	}
	
	return false;	
}

/**
 * Attempts to find the 4 sets of pills closest to the finale trigger.  
 *
 * Note: We can't just check for the pills being inside a radius around the finale trigger
 * like for the medkits as, unlike medkits, extra pills can be spawned within the finale radius.
 *
 * @param outFinalePills the array into which, if found, the finale pill entities will be placed.  If the pills could not be found, the array members will be set to -1
 * @return whether the pills were found or not.  Check the return value before doing anything with the results.
 */
static bool:TryGetFinalePillEntities(outFinalePills[4])
{	
	if(!g_bIsFinale)	
	{
		return false;			
	}
	
	// run through all the pill spawns and find the 4 pill spawns that are closest to the survivors	
	new Float:closestDistances[4] = { 9999999999.0, 9999999999.0, 9999999999.0, 9999999999.0 };	
	outFinalePills[0] = -1;
	outFinalePills[1] = -1;
	outFinalePills[2] = -1;
	outFinalePills[3] = -1;
	
	new entity = -1;	
	decl Float:entityPos[3];
	
	while ((entity = FindEntityByClassnameEx(entity, PAIN_PILLS_CLASSNAME)) != -1)
	{		
		if(!IsValidEntity(entity))
			continue;
			
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", entityPos);
		
		new Float:distance = GetVectorDistance(entityPos, g_vFinaleOrigin);
		
		// basically, what we want to do is move left, shifting the elements we encounter
		// until we encounter one that is smaller than our inserted distance, then insert the new element		
		if(closestDistances[3] > distance)
		{
			new i = 3;
			while(i > 0 && closestDistances[i] > distance)
			{	
				closestDistances[i] = closestDistances[i - 1];
				outFinalePills[i] = outFinalePills[i - 1];				
				
				i--;
			}	
			
			// we have the index and the rest of the array has been bumped down by now; insert our new data
			closestDistances[i] = distance;	
			outFinalePills[i] = entity;
		}		
	}	
	
	DebugPrintToAllEx("Distances of pills from finale (we're keeping these ones):");
	for(new j = 0; j < 4; j++)
	{
		DebugPrintToAllEx("ent id: %i, distance: %f", outFinalePills[j], closestDistances[j] );
	}
	
	return true;
}
/*
static bool:TryGetFinaleKitsEntities(outFinalePills[4])
{	
	if(!g_bIsFinale)	
	{
		return false;			
	}
	
	// run through all the pill spawns and find the 4 pill spawns that are closest to the survivors	
	new Float:closestDistances[4] = { 9999999999.0, 9999999999.0, 9999999999.0, 9999999999.0 };	
	outFinalePills[0] = -1;
	outFinalePills[1] = -1;
	outFinalePills[2] = -1;
	outFinalePills[3] = -1;
	
	new entity = -1;	
	decl Float:entityPos[3];
	
	while ((entity = FindEntityByClassnameEx(entity, FIRST_AID_KIT_CLASSNAME)) != -1)
	{		
		if(!IsValidEntity(entity))
			continue;
			
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", entityPos);
		
		new Float:distance = GetVectorDistance(entityPos, g_vFinaleOrigin);
		
		// basically, what we want to do is move left, shifting the elements we encounter
		// until we encounter one that is smaller than our inserted distance, then insert the new element		
		if(closestDistances[3] > distance)
		{
			new i = 3;
			while(i > 0 && closestDistances[i] > distance)
			{	
				closestDistances[i] = closestDistances[i - 1];
				outFinalePills[i] = outFinalePills[i - 1];				
				
				i--;
			}	
			
			// we have the index and the rest of the array has been bumped down by now; insert our new data
			closestDistances[i] = distance;	
			outFinalePills[i] = entity;
		}		
	}	
	
	DebugPrintToAllEx("Distances of pills from finale (we're keeping these ones):");
	for(new j = 0; j < 4; j++)
	{
		DebugPrintToAllEx("ent id: %i, distance: %f", outFinalePills[j], closestDistances[j] );
	}
	
	return true;
}
*/
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

public FindSurvivorStart()
{
	new EntityCount = GetEntityCount();
	new String:EdictClassName[128];
	new Float:Location[3];
	//Search entities for either a locked saferoom door,
	for (new i = 0; i <= EntityCount; i++)
	{
		if (IsValidEntity(i))
		{
			GetEdictClassname(i, EdictClassName, sizeof(EdictClassName));
			if ((StrContains(EdictClassName, "prop_door_rotating_checkpoint", false) != -1) && (GetEntProp(i, Prop_Send, "m_bLocked")==1))
			{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", Location);
				SurvivorStart = Location;
				return;
			}
		}
	}
	//or a survivor start point.
	for (new i = 0; i <= EntityCount; i++)
	{
		if (IsValidEntity(i))
		{
			GetEdictClassname(i, EdictClassName, sizeof(EdictClassName));
			if (StrContains(EdictClassName, "info_survivor_position", false) != -1)
			{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", Location);
				SurvivorStart = Location;
				return;
			}
		}
	}
}

public RemoveMedkits(SaferoomKits[4])
{
	SaferoomKits[0] = -1;
	SaferoomKits[1] = -1;
	SaferoomKits[2] = -1;
	SaferoomKits[3] = -1;
	
	new k = 0;
	new EntityCount = GetEntityCount();
	new String:EdictClassName[128];
	new Float:NearestMedkit[3];
	new Float:Location[3];
	//Look for the nearest medkit from where the survivors start,
	for (new i = 0; i <= EntityCount; i++)
	{
		if (IsValidEntity(i))
		{
			GetEdictClassname(i, EdictClassName, sizeof(EdictClassName));
			if (StrContains(EdictClassName, "weapon_first_aid_kit", false) != -1)
			{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", Location);
				//If NearestMedkit is zero, then this must be the first medkit we found.
				if ((NearestMedkit[0] + NearestMedkit[1] + NearestMedkit[2]) == 0.0)
				{
					NearestMedkit = Location;
					continue;
				}
				//If this medkit is closer than the last medkit, record its location.
				if (GetVectorDistance(SurvivorStart, Location, false) < GetVectorDistance(SurvivorStart, NearestMedkit, false)) NearestMedkit = Location;
			}
		}
	}
	//then remove the kits
	for (new i = 0; i <= EntityCount; i++)
	{
		if (IsValidEntity(i))
		{
			GetEdictClassname(i, EdictClassName, sizeof(EdictClassName));
			if (StrContains(EdictClassName, "weapon_first_aid_kit", false) != -1)
			{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", Location);
				if (GetVectorDistance(NearestMedkit, Location, false) < 400)
				{			
					AcceptEntityInput(i, "Kill");
					SaferoomKits[k++] = i;
				}
			}
		}
	}
}

public ReplaceSafeRoomMedkits(SaferoomKits[4])
{
	SaferoomKits[0] = -1;
	SaferoomKits[1] = -1;
	SaferoomKits[2] = -1;
	SaferoomKits[3] = -1;
	
	new k = 0;
	new EntityCount = GetEntityCount();
	new String:EdictClassName[128];
	new Float:NearestMedkit[3];
	new Float:Location[3];
	//Look for the nearest medkit from where the survivors start,
	for (new i = 0; i <= EntityCount; i++)
	{
		if (IsValidEntity(i))
		{
			GetEdictClassname(i, EdictClassName, sizeof(EdictClassName));
			if (StrContains(EdictClassName, "weapon_first_aid_kit", false) != -1)
			{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", Location);
				//If NearestMedkit is zero, then this must be the first medkit we found.
				if ((NearestMedkit[0] + NearestMedkit[1] + NearestMedkit[2]) == 0.0)
				{
					NearestMedkit = Location;
					continue;
				}
				//If this medkit is closer than the last medkit, record its location.
				if (GetVectorDistance(SurvivorStart, Location, false) < GetVectorDistance(SurvivorStart, NearestMedkit, false)) NearestMedkit = Location;
			}
		}
	}
	//then replace the kits
	for (new i = 0; i <= EntityCount; i++)
	{
		if (IsValidEntity(i))
		{
			GetEdictClassname(i, EdictClassName, sizeof(EdictClassName));
			if (StrContains(EdictClassName, "weapon_first_aid_kit", false) != -1)
			{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", Location);
				if (GetVectorDistance(NearestMedkit, Location, false) < 400)
				{
					//decl Float:entityPos[3];
					//GetEntPropVector(i, Prop_Send, "m_vecOrigin", entityPos);	
					//LogMessage("saferoom KIT here %d: %f %f %f",i,entityPos[0],entityPos[1],entityPos[2]);	
					if(!(k==3 && g_iHealthStyle == REPLACE_ALL_BUT_FINALE_KITS))
						ReplaceKitWithPills(i);
					SaferoomKits[k++] = i;
					
				}
			}
		}
	}
}