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
 *  Copyright (C) 2017-2022 Harry <fbef0102@gmail.com>
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
	REPLACE_ALL_BUT_FINALE_KITS = 2, // Replace saferoom medkits with pills + allow few kits on the map and final
	SAFEROOM_AND_FINALE_PILLS_ONLY = 3, // Replace the finale kits with pills and remove all other pills/kits + give pills when round starts
	ZONEMOD_PILLS = 4 // Replace all medkits with pills (use data/mapinfo to control pill limit) + remove saferoom kits + give pills when round starts
}
// --------------------
//       Private
// --------------------

static	const	String:	CONVERT_PILLS_CVAR[]			= "director_convert_pills";
static	const	String:	CONVERT_PILLS_VS_CVAR[]		= "director_vs_convert_pills"; // setting this var to 0 will convert no pills to health kits

static	const	String:	FIRST_AID_KIT_CLASSNAME[]		= "weapon_first_aid_kit_spawn";
static	const	String:	PAIN_PILLS_CLASSNAME[]			= "weapon_pain_pills_spawn";
static	const	String:	MODEL_PAIN_PILLS[]				= "w_models/weapons/w_eq_painpills.mdl";
//static 	const 	String: MODEL_FIRST_AID_KIT[]			= "w_models/weapons/w_eq_medkit.mdl";

static	const	Float:	REPLACE_DELAY					= 0.1; // Short delay on OnEntityCreated before replacing

static			bool:	g_bIsFinale						= false;
static			bool:	g_bHaveRunRoundStart			= false;

static HEALTH_STYLE: g_iHealthStyle					= REPLACE_ALL_KITS; // How we replace kits
static ConVar	g_hHealthStyle_Cvar, 
				g_hCvarPillFlowVisualize;

static					g_iDebugChannel					= 0;
static	const	String:	DEBUG_CHANNEL_NAME[]		= "HealthControl";


static Float:SurvivorStart[3];
static g_iPlayerSpawn, g_iRoundStart;
static bool g_bIsRound1Over;
int g_iFinalPills[16];
int g_iSaferoomKits[4];

// Item lists for tracking/decoding/etc
enum /*ItemList*/ 
{
	IL_None = -1,
	IL_PainPills = 0,

	ItemList_Size
};

// Names for cvars, kv, descriptions
// [ItemIndex][shortname=0,fullname=1,spawnname=2]
enum /*ItemNames*/ {	
	IN_shortname,	
	IN_longname, 	
	IN_officialname, 	
	IN_modelname,
	IN_Max
};

static const String:g_sItemNames[ItemList_Size][IN_Max][] =
{
	{ "pills", "pain pills", "pain_pills", "painpills" },
};

// For spawn entires adt_array
enum struct ItemTracking {
	int IT_entity;
	float IT_origins;
	float IT_origins1;
	float IT_origins2;
	float IT_angles;
	float IT_angles1;
	float IT_angles2;
}

// ADT Array Handle for actual item spawns
ArrayList g_hItemSpawns[ItemList_Size];

#define PF_KEEP        0
#define PF_CULL_WINDOW 1
#define PF_CULL_SEP    2
#define PF_CULL_LIMIT  3
#define PF_NO_FLOW     -1   // no nav/flow data: always kept, excluded from spacing

static const char PF_GLOW_KEEP[12] = "255 255 255";   // white
static const char PF_GLOW_CULL[4][12] = {
    "0 0 0",          // PF_KEEP (unused)
    "255 0 0",        // PF_CULL_WINDOW: red
    "255 165 0",      // PF_CULL_SEP: orange
    "0 255 255"       // PF_CULL_LIMIT: cyan
};

// **********************************************
//                   Forwards
// **********************************************

public _HealthControl_OnPluginStart()
{
	HookPublicEvent(EVENT_ONPLUGINENABLE, _HC_OnPluginEnable);
	HookPublicEvent(EVENT_ONPLUGINDISABLE, _HC_OnPluginDisable);

	g_hHealthStyle_Cvar = CreateConVarEx("health_style", 
		"1", 
		"medkits and pills configuration. 0=Don't replace any medkits, 1=Replace all medkits with pills, 2=Replace all medkits with pills except the finale medkits, 3=Replace the finale kits with pills and remove all other pills/kits, 4=Replace all medkits with pills, only remove saferoom kits (use data/mapinfo to control pill limit)", 
		FCVAR_NOTIFY);
	AddConVarToReport(g_hHealthStyle_Cvar); // Add to report status module
	UpdateHealthStyle();

	g_iDebugChannel = DebugAddChannel(DEBUG_CHANNEL_NAME);
	DebugPrintToAllEx("Module is now setup");

	// Pill flow window. Per-map override keys in mapinfo.txt (map section):
	// "pillflow_min", "pillflow_max", "pillflow_separation" (floats, same meaning as the cvars).
	g_hCvarPillFlowVisualize = CreateConVarEx("pills_flow_visualize", "0", "Debug: 1 = don't remove pills, glow instead: white = kept, red = outside flow window, orange = too close to previous pill, cyan = over the pills limit. 2 = remove as normal, then glow the surviving pills white.", _, true, 0.0, true, 2.0);

	// Create item spawns array;
	for (new i = 0; i < ItemList_Size; i++)
	{
		g_hItemSpawns[i] = new ArrayList(sizeof(ItemTracking)); 
	}
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
	HookEvent("player_spawn", _HC_PlayerSpawn_Event,	EventHookMode_PostNoCopy);
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
	ResetPlugin();
	ResetConVar(FindConVar(CONVERT_PILLS_CVAR));
	ResetConVar(FindConVar(CONVERT_PILLS_VS_CVAR));

	UnhookEvent("round_start", _HC_RoundStart_Event, EventHookMode_Post);
	UnhookEvent("player_spawn", _HC_PlayerSpawn_Event,	EventHookMode_PostNoCopy);
	UnhookEvent("player_left_start_area", _HC_player_left_start_area, EventHookMode_PostNoCopy);
	UnhookEvent("round_end", _HC_RoundEnd_Event, EventHookMode_PostNoCopy);
	UnhookPublicEvent(EVENT_ONMAPSTART, _HC_OnMapStart);
	UnhookPublicEvent(EVENT_ONMAPEND, _HC_OnMapEnd);
	UnhookPublicEvent(EVENT_ONENTITYCREATED, _HC_OnEntityCreated);
	UnhookConVarChange(g_hHealthStyle_Cvar, _HC_HealthStyle_CvarChange);

	DebugPrintToAllEx("Module is now unloaded");
}

public _HC_OnMapStart()
{
	PrecacheModel("materials/vgui/icon_arrow_down.vmt", true);

	g_bIsRound1Over = false;

	for (new i = 0; i < ItemList_Size; i++)
	{
		delete g_hItemSpawns[i];
		g_hItemSpawns[i] = new ArrayList(sizeof(ItemTracking)); 
	}
}

public _HC_OnMapEnd()
{
	ResetPlugin();
	g_bHaveRunRoundStart = false;
	UnhookPublicEvent(EVENT_ONENTITYCREATED, _HC_OnEntityCreated);
	DebugPrintToAllEx("Map is ending, unhook OnEntityCreated");
}

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

public _HC_PlayerSpawn_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	if( g_iPlayerSpawn == 0 && g_iRoundStart == 1) 
	{
		DetermineIfMapIsFinale();
		CreateTimer(0.25, TimerStart, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	g_iPlayerSpawn = 1;
}

public _HC_RoundStart_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	
	if( g_iPlayerSpawn == 1 && g_iRoundStart == 0)
	{
		DetermineIfMapIsFinale();
		CreateTimer(0.25, TimerStart, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	g_iRoundStart = 1;
}

static Action:TimerStart(Handle:timer)
{
	ResetPlugin();
	if (g_iHealthStyle == REPLACE_NO_KITS)
	{
		DebugPrintToAllEx("Round start - Will not replace medkits");
		return; // Not replacing any medkits, return
	}
	
	//LogMessage("Round start - Running health control - Final map: %d", g_bIsFinale);
	UpdateStartingHealthItems();

	if(g_iHealthStyle == ZONEMOD_PILLS)
	{
		if(!g_bIsRound1Over)
		{
			// Round1
			EnumAndElimSpawns();
		}
		else
		{
			// Round2
			GenerateStoredPillSpawns();
		}
	}

	UnhookPublicEvent(EVENT_ONENTITYCREATED, _HC_OnEntityCreated);
	HookPublicEvent(EVENT_ONENTITYCREATED, _HC_OnEntityCreated);
	g_bHaveRunRoundStart = true;
}

public _HC_RoundEnd_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	ResetPlugin();
	g_bHaveRunRoundStart = false;
	UnhookPublicEvent(EVENT_ONENTITYCREATED, _HC_OnEntityCreated);
	DebugPrintToAllEx("Round end");
	g_bIsRound1Over = true;
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
	if(g_bHaveRunRoundStart == false) return;
		
	if (( g_iHealthStyle == SAFEROOM_AND_FINALE_PILLS_ONLY)&& 
		StrEqual(classname, PAIN_PILLS_CLASSNAME))
	{						
		new entRef = EntIndexToEntRef(entity);
		CreateTimer(REPLACE_DELAY, _HC_RemoveItem_Delayed_Timer, entRef);
	}
	else if(StrEqual(classname, FIRST_AID_KIT_CLASSNAME) && ShouldReplaceKitWithPills()) 
	{		
		new entRef = EntIndexToEntRef(entity);
		CreateTimer(REPLACE_DELAY, _HC_ReplaceKit_Delayed_Timer, entRef); // Replace medkit
		DebugPrintToAllEx("Late spawned medkit, timer created. Entity %i", entity);
	}
}

public Action:_HC_RemoveItem_Delayed_Timer(Handle:timer, any:entRef)
{
	new entity = EntRefToEntIndex(entRef);	
	if (entity == INVALID_ENT_REFERENCE)
		return;
	
	//decl Float:entityPos[3];
	//GetEntPropVector(entity, Prop_Send, "m_vecOrigin", entityPos);	
	//LogMessage("KITS here4 %d: %f %f %f",entity,entityPos[0],entityPos[1],entityPos[2]);
	SafelyRemoveEntity(entity);
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
	if (entity == INVALID_ENT_REFERENCE)
	{
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
	g_iHealthStyle = view_as<HEALTH_STYLE>(GetConVarInt(g_hHealthStyle_Cvar));
	DebugPrintToAllEx("Updated global style variable; %i", GetConVarInt(g_hHealthStyle_Cvar));
}

/**
 * Replaces or removes items present at the start of the round.  Logic run is based on the chosen health style.
 * 
 */
static UpdateStartingHealthItems()
{	
	new entity = -1;
	
	DebugPrintToAllEx("Updating starting health items.");
	if (g_iHealthStyle == ZONEMOD_PILLS||g_iHealthStyle == SAFEROOM_AND_FINALE_PILLS_ONLY)//remove saferoom medkits
	{
		//find where the survivors start so we know which medkits to replace,
		FindSurvivorStart();
		//and remove the medkits
		RemoveMedkits();
	}
	
	if(g_iHealthStyle == REPLACE_ALL_BUT_FINALE_KITS || g_iHealthStyle == REPLACE_ALL_KITS) 
	{
		FindSurvivorStart();
		ReplaceSafeRoomMedkits();
	}
	
	new k =0;
	entity = -1;
	new pillsleft = GetConVarInt(FindConVar("survivor_limit"));
	int number;
	if(g_bIsFinale && !g_bGauntletFinaleMap)//非衝刺型救援關卡四顆藥丸符合當前人類數量
	{
		if(g_iHealthStyle == SAFEROOM_AND_FINALE_PILLS_ONLY)
		{
			RemoveAllPills();
		}

		for(int i = 0; i < 16; i++)
		{
			g_iFinalPills[i] = 0;
		}

		while ((entity = FindEntityByClassnameEx(entity, FIRST_AID_KIT_CLASSNAME)) != -1)
		{
			if(!IsValidEntity(entity))
				continue;	
			
			if(IsInSafeRoom(entity))
				continue;

			if(g_iHealthStyle == REPLACE_ALL_BUT_FINALE_KITS) 
			{
				ReplaceKitWithPills(entity);
				number++;
				if(number >= 3) break;
				continue;
			}

			//decl Float:entityPos[3];
			//GetEntPropVector(entity, Prop_Send, "m_vecOrigin", entityPos);	
			//LogMessage("KITS here3 %d: %f %f %f",entity,entityPos[0],entityPos[1],entityPos[2]);
			//醫療包變成藥丸
			if(pillsleft<=0)
			{
				RemoveEntity(entity);
			}
			else if(pillsleft>=5)
			{
				g_iFinalPills[k++] = ReplaceKitWithPills(entity);
				g_iFinalPills[k++] = ReplaceKitWithPills(entity);
			}
			else
			{
				g_iFinalPills[k++] = ReplaceKitWithPills(entity);
			}

			pillsleft--;
			g_iFinalPills[k++] = entity;
		}
	}
	else //非救援關或衝刺型關卡
	{
		if(g_iHealthStyle == REPLACE_ALL_BUT_FINALE_KITS) 
		{
			return;
		}

		// Then, if we're using the hardcore setting, remove all pills from the map
		if(g_iHealthStyle == SAFEROOM_AND_FINALE_PILLS_ONLY)
		{		
			RemoveAllPills();
		}

		while ((entity = FindEntityByClassnameEx(entity, FIRST_AID_KIT_CLASSNAME)) != -1)
		{
			if(!IsValidEntity(entity))
				continue;

			if(IsInSafeRoom(entity))
				continue;
			
			//decl Float:entityPos[3];
			//GetEntPropVector(entity, Prop_Send, "m_vecOrigin", entityPos);	
			//LogMessage("KITS here2 %d: %f %f %f: %d,%d,%d,%d",entity,entityPos[0],entityPos[1],entityPos[2],g_iSaferoomKits[0],g_iSaferoomKits[1],g_iSaferoomKits[2],g_iSaferoomKits[3]);

			if(g_iHealthStyle == SAFEROOM_AND_FINALE_PILLS_ONLY) SafelyRemoveEntity(entity);
			else ReplaceKitWithPills(entity);
		}
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
		if(!IsValidEntity(entity))
			continue;
		
		if(SafelyRemoveEntity(entity))
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
	if (L4D_IsMissionFinalMap())
	{
		g_bIsFinale = true;
	}
	else
	{
		g_bIsFinale = false;
	}
}

/**
 * Predicate used to determine whether we should replace kits with pills
 * @param entity 	medkit entity to be considered for replacement
 * @return			whether the kit should be replaced with pills
 */
bool ShouldReplaceKitWithPills()
{
	if ((g_bIsFinale && 
		g_iHealthStyle == REPLACE_ALL_BUT_FINALE_KITS)||
		g_iHealthStyle == REPLACE_NO_KITS)
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
static int ReplaceKitWithPills(entity)
{	
	new result = ReplaceEntity(entity, PAIN_PILLS_CLASSNAME, MODEL_PAIN_PILLS, 1);
	if (!result)
	{
		ThrowError("Failed to replace medkit with pills! Entity %i", entity);
	}
	
	DebugPrintToAllEx("Medkit (entity %i) replaced with pills (entity %i)", entity, result);
	return result;	
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

public FindSurvivorStart()
{
	//Search entities for either a locked saferoom door,
	int ent_safedoor_check = L4D_GetCheckpointFirst();
	if (ent_safedoor_check != -1)
	{
		GetEntPropVector(ent_safedoor_check, Prop_Send, "m_vecOrigin", SurvivorStart);
		return;
	}
	//or a survivor start point.
	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "info_survivor_position")) != -1)
	{
		if (!IsValidEntity(entity))
			continue;	

		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", SurvivorStart);
		break;
	}
}

public RemoveMedkits()
{
	g_iSaferoomKits[0] = -1;
	g_iSaferoomKits[1] = -1;
	g_iSaferoomKits[2] = -1;
	g_iSaferoomKits[3] = -1;
	
	new k = 0;
	new Float:NearestMedkit[3];
	new Float:Location[3];
	//Look for the nearest medkit from where the survivors start,
	int entity = -1;
	while ((entity = FindEntityByClassname(entity, FIRST_AID_KIT_CLASSNAME)) != -1)
	{
		if (!IsValidEntity(entity))
			continue;	

		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", Location);
		//LogMessage("SurvivorStart: %.1f %.1f %.1f, Location: %.1f %.1f %.1f: distance: %.1f", SurvivorStart[0], SurvivorStart[1], SurvivorStart[2], Location[0], Location[1], Location[2], GetVectorDistance(SurvivorStart, Location, false));
		//If NearestMedkit is zero, then this must be the first medkit we found.
		if ((NearestMedkit[0] + NearestMedkit[1] + NearestMedkit[2]) == 0.0)
		{
			NearestMedkit = Location;
			continue;
		}
		//If this medkit is closer than the last medkit, record its location.
		if (GetVectorDistance(SurvivorStart, Location, true) < GetVectorDistance(SurvivorStart, NearestMedkit, true)) NearestMedkit = Location;
	}
	//then remove the kits
	entity = -1;
	while ((entity = FindEntityByClassname(entity, FIRST_AID_KIT_CLASSNAME)) != -1)
	{
		if (!IsValidEntity(entity))
			continue;	

		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", Location);
		if (GetVectorDistance(NearestMedkit, Location, false) < 600)
		{			
			AcceptEntityInput(entity, "Kill");

			if(k == 4) continue;

			g_iSaferoomKits[k++] = entity;
		}
	}
}

public void ReplaceSafeRoomMedkits()
{
	g_iSaferoomKits[0] = -1;
	g_iSaferoomKits[1] = -1;
	g_iSaferoomKits[2] = -1;
	g_iSaferoomKits[3] = -1;
	
	new k = 0;
	new Float:NearestMedkit[3];
	new Float:Location[3];
	//Look for the nearest medkit from where the survivors start,
	int entity = -1;
	while ((entity = FindEntityByClassname(entity, FIRST_AID_KIT_CLASSNAME)) != -1)
	{
		if (!IsValidEntity(entity))
			continue;	

		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", Location);
		//If NearestMedkit is zero, then this must be the first medkit we found.
		if ((NearestMedkit[0] + NearestMedkit[1] + NearestMedkit[2]) == 0.0)
		{
			NearestMedkit = Location;
			continue;
		}
		//If this medkit is closer than the last medkit, record its location.
		if (GetVectorDistance(SurvivorStart, Location, false) < GetVectorDistance(SurvivorStart, NearestMedkit, false)) NearestMedkit = Location;
	}

	//then replace the kits
	entity = -1;
	while ((entity = FindEntityByClassname(entity, FIRST_AID_KIT_CLASSNAME)) != -1)
	{
		if (!IsValidEntity(entity))
			continue;	

		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", Location);
		if (GetVectorDistance(NearestMedkit, Location, false) < 400)
		{
			//decl Float:entityPos[3];
			//GetEntPropVector(entity, Prop_Send, "m_vecOrigin", entityPos);	
			//LogMessage("saferoom KIT here %d: %f %f %f",entity,entityPos[0],entityPos[1],entityPos[2]);	
			ReplaceKitWithPills(entity);	
			g_iSaferoomKits[k++] = entity;
		}

		if(k == 4)
		{
			break;
		}
	}
}

void ResetPlugin()
{
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
}

void EnumAndElimSpawns()
{
	EnumerateSpawns();
	if(ApplyPillFlowFilter() == false)
	{
		RemoveToLimits();
	}
}

static EnumerateSpawns()
{
	//LogMessage("EnumerateSpawns()");

    /*
        Start every enumeration from a clean slate.
        Without this, configs running savespawns 0 stack round-2 entries on round-1 leftovers
        and mapspecific 0 leaks spawns across maps (OnMapStart only clears when mapspecific != 0)
    */
    for (int i = 0; i < ItemList_Size; i++) {
        g_hItemSpawns[i].Clear();
    }

	ItemTracking curitem;
	int itemindex;
	float origins[3], angles[3];
	new psychonic = GetMaxEntities();

	int iCustomPill_limit = 2;
	if(g_hMIData.JumpToKey("default"))
	{
		iCustomPill_limit = g_hMIData.GetNum("pill_limit", iCustomPill_limit);

		g_hMIData.GoBack();
	}

	if (g_hMIData.JumpToKey(g_sCurMap)) 
	{
		iCustomPill_limit = g_hMIData.GetNum("pill_limit", iCustomPill_limit);
	}
	g_hMIData.Rewind();

	for(new i = MaxClients + 1; i <= psychonic; i++)
	{
		if(IsValidEntity(i))
		{
			itemindex = GetItemIndexFromEntity(i);
			if(itemindex == IL_PainPills /* && !IsEntityInSaferoom(i) */ )
			{
				//if(IsInCabinet(i)) continue;
				if(IsInFinalArea(i)) continue;

				if(iCustomPill_limit == 0)
				{
					//LogMessage("[IT] Killing spawn");

					RemoveEntity(i);
				}
				else 
				{
					//LogMessage("[IT] Found an instance of item %s (%d)", g_sItemNames[itemindex][IN_longname], itemindex);
				
					// Store entity, angles, origin
					curitem.IT_entity=i;
					GetEntPropVector(i, Prop_Send, "m_vecOrigin", origins);
					GetEntPropVector(i, Prop_Send, "m_angRotation", angles);

					//LogMessage("[IT] Saving spawn #%d at %.02f %.02f %.02f", GetArraySize(g_hItemSpawns[itemindex]), origins[0], origins[1], origins[2]);

					curitem.IT_origins=origins[0];
					curitem.IT_origins1=origins[1];
					curitem.IT_origins2=origins[2];
					curitem.IT_angles=angles[0];
					curitem.IT_angles1=angles[1];
					curitem.IT_angles2=angles[2];
					
					// Push this instance onto our array for that item
					g_hItemSpawns[itemindex].PushArray(curitem);
				}
			}
		}
	}
}

static RemoveToLimits()
{
	ItemTracking curitem;

	int curlimit = 2;
	if(g_hMIData.JumpToKey("default"))
	{
		curlimit = KvGetNum(g_hMIData, "pill_limit", 2);

		g_hMIData.GoBack();
	}

	if (g_hMIData.JumpToKey(g_sCurMap)) 
	{
		curlimit = KvGetNum(g_hMIData, "pill_limit", 2);
		KvRewind(g_hMIData);
	}

	for(new itemidx = 0; itemidx < ItemList_Size; itemidx++)
	{
		if (curlimit > 0)
		{
			// Kill off item spawns until we've reduced the item to the limit
			while(g_hItemSpawns[itemidx].Length > curlimit)
			{
				// Pick a random
				new killidx = GetURandomIntRange(0, g_hItemSpawns[itemidx].Length-1);
				
				//LogMessage("[IT] Killing randomly chosen %s #%d", g_sItemNames[itemidx][IN_longname], killidx);

				g_hItemSpawns[itemidx].GetArray(killidx, curitem);
				if(IsValidEntity(curitem.IT_entity))
				{
					RemoveEntity(curitem.IT_entity);
					//LogMessage("[IT] Error killing instance of item %s", g_sItemNames[itemidx][IN_longname]);
				}
				g_hItemSpawns[itemidx].Erase(killidx);
			}
		}
		// If limit is 0, they're already dead. If it's negative, we kill nothing.
	}
}

static GenerateStoredPillSpawns()
{
	KillRegisteredItems();
	SpawnItems();

    // Repaint glows on the respawned entities.
    if (g_hCvarPillFlowVisualize.IntValue > 0) {
        ApplyPillFlowFilter();
    }
}

static KillRegisteredItems()
{
	//LogMessage("KillRegisteredItems()");

	int itemindex;
	new psychonic = GetMaxEntities();
	for(new i = MaxClients + 1; i <= psychonic; i++)
	{
		if(IsValidEntity(i))
		{
			itemindex = GetItemIndexFromEntity(i);
			if(itemindex == IL_PainPills /* && !IsEntityInSaferoom(i) */ )
			{
				//if(IsInCabinet(i)) continue;
				if(IsInFinalArea(i)) continue;

				// Kill items we're tracking;
				RemoveEntity(i);
			}
		}
	}
}

static SpawnItems()
{
	ItemTracking curitem;
	decl Float:origins[3], Float:angles[3];
	new arrsize;
	new itement;
	decl String:sModelname[PLATFORM_MAX_PATH];
	int wepid;
	for(new itemidx = 0; itemidx < ItemList_Size; itemidx++)
	{
		Format(sModelname, sizeof(sModelname), "models/w_models/weapons/w_eq_%s.mdl", g_sItemNames[itemidx][IN_modelname]);
		arrsize = g_hItemSpawns[itemidx].Length;
		for(new idx = 0; idx < arrsize; idx++)
		{
			g_hItemSpawns[itemidx].GetArray(idx, curitem);

			origins[0]=curitem.IT_origins;
			origins[1]=curitem.IT_origins1;
			origins[2]=curitem.IT_origins2;

			angles[0]=curitem.IT_angles;
			angles[1]=curitem.IT_angles1;
			angles[2]=curitem.IT_angles2;

			wepid = GetWeaponIDFromItemList(itemidx);
			
			//LogMessage("[IT] Spawning an instance of item %s (%d, wepid %d), number %d, at %.02f %.02f %.02f", g_sItemNames[itemidx][IN_officialname], itemidx, wepid, idx, origins[0], origins[1], origins[2]);
			
			itement = CreateEntityByName("weapon_pain_pills_spawn");
			SetEntProp(itement, Prop_Send, "m_weaponID", wepid);
			SetEntityModel(itement, sModelname);
			DispatchKeyValue(itement, "count", "1");
			TeleportEntity(itement, origins, angles, NULL_VECTOR);
			DispatchSpawn(itement);
			SetEntityMoveType(itement,MOVETYPE_NONE);

            /*
                Keep the stored entry pointing at the live entity so passes that
                run after the respawn (e.g. the pill flow filter) address the
                round-2 entity, not the killed round-1 one.
            */
            curitem.IT_entity = itement;
            g_hItemSpawns[itemidx].SetArray(idx, curitem, sizeof(curitem));
		}
	}
}

static int GetItemIndexFromEntity(int entity)
{
	static char classname[128];
	GetEdictClassname(entity, classname, sizeof(classname));
	
	if(StrEqual(classname, PAIN_PILLS_CLASSNAME))
	{
		return IL_PainPills;
	}
	
	return IL_None;
}

static int GetURandomIntRange(int min, int max)
{
	return (GetURandomInt() % (max-min+1)) + min;
}

static int GetWeaponIDFromItemList(int id)
{
	switch(id)
	{
		case IL_PainPills:
		{
			return WEAPID_PAINPILLS;
		}
	}
	return -1;
}

stock bool IsInCabinet(int pill)
{
	//LogMessage("%d - spawnflags: %d", pill, GetEntProp(pill, Prop_Data, "m_spawnflags"));

	if(GetEntProp(pill, Prop_Data, "m_spawnflags") == 32770)
		return true;

	return false;
}

bool IsInFinalArea(int pill)
{
	if(!g_bIsFinale) return false;
	if(g_bGauntletFinaleMap) return false;

	for(int i = 0; i < 16; i++)
	{
		if(g_iFinalPills[i] == pill)
			return true;
	}

	return false;
}

bool IsInSafeRoom(int kit)
{
	if(kit==g_iSaferoomKits[0] ||
	kit==g_iSaferoomKits[1] ||
	kit==g_iSaferoomKits[2] ||
	kit==g_iSaferoomKits[3])
	{
		return true;
	}

	return false;
}

// Returns true when the filter is active (= it owns the pills limit this round).
static bool ApplyPillFlowFilter()
{
	int iCustomPill_limit = 2;
	float fFlowMin = 0.0, fFlowMax = 1.0, fSep = 0.0;
	bool pillflow_finale = false;
	if(g_hMIData.JumpToKey("default"))
	{
		iCustomPill_limit = g_hMIData.GetNum("pill_limit", iCustomPill_limit);
		fFlowMin = g_hMIData.GetFloat("pillflow_min", fFlowMin);
		fFlowMax = g_hMIData.GetFloat("pillflow_max", fFlowMax);
		fSep = g_hMIData.GetFloat("pillflow_separation", fSep);
		pillflow_finale = view_as<bool>(g_hMIData.GetNum("pillflow_finale", pillflow_finale));

		g_hMIData.GoBack();
	}

	if (g_hMIData.JumpToKey(g_sCurMap)) 
	{
		iCustomPill_limit = g_hMIData.GetNum("pill_limit", iCustomPill_limit);
		fFlowMin = g_hMIData.GetFloat("pillflow_min", fFlowMin);
		fFlowMax = g_hMIData.GetFloat("pillflow_max", fFlowMax);
		fSep = g_hMIData.GetFloat("pillflow_separation", fSep);
		pillflow_finale = view_as<bool>(g_hMIData.GetNum("pillflow_finale", pillflow_finale));
	}

	g_hMIData.Rewind();

    if (fFlowMin <= 0.0 && fFlowMax >= 1.0 && fSep <= 0.0) {
        return false;
    }

    if (fFlowMax < fFlowMin) {
        LogError("[%s] pillflow_max (%.2f) < pillflow_min (%.2f); pill flow filter disabled.", "rotoblin.healthcontrol", fFlowMax, fFlowMin);
        return false;
    }

    if (!pillflow_finale && g_bIsFinale) {
        if (IsDebugEnabled()) {
            LogMessage("[%s] Finale map, pill flow filter skipped.", "rotoblin.healthcontrol");
        }
        return false;
    }

    float fMaxFlowDist = L4D2Direct_GetMapMaxFlowDistance();
    if (fMaxFlowDist <= 0.0) {
        return false;
    }

    ArrayList hSpawns = g_hItemSpawns[IL_PainPills];
    int iCount = hSpawns.Length;
    if (!iCount) {
        return true;
    }

    int iVisualize = g_hCvarPillFlowVisualize.IntValue;
    bool bVisualize = (iVisualize == 1);   // mode 1 glows instead of removing; mode 2 removes and glows survivors
    ItemTracking curitem;
    float fOrigins[3];

    // Resolve each stored pill spawn to a flow fraction and apply the window.
    float[] fPct = new float[iCount];
    int[] iReason = new int[iCount];

    for (int i = 0; i < iCount; i++) {
        hSpawns.GetArray(i, curitem, sizeof(curitem));
        GetSpawnOrigins(fOrigins, curitem);

        Address pNav = L4D_GetNearestNavArea(fOrigins, 120.0, true, false, false, 2);
        if (pNav == Address_Null) {
            pNav = L4D2Direct_GetTerrorNavArea(fOrigins);
        }

        float fFlow = (pNav != Address_Null) ? L4D2Direct_GetTerrorNavAreaFlow(pNav) : -1.0;
        if (fFlow < 0.0) {
            fPct[i] = -1.0;
            iReason[i] = PF_NO_FLOW;
            continue;
        }

        fPct[i] = fFlow / fMaxFlowDist;
        if (fPct[i] > 1.0) {
            fPct[i] = 1.0;
        }

        if (fPct[i] < fFlowMin || fPct[i] > fFlowMax) {
            iReason[i] = PF_CULL_WINDOW;
        }
    }

    // Index order sorted by ascending flow (spacing passes walk the map start->end).
    int[] iOrder = new int[iCount];
    for (int i = 0; i < iCount; i++) {
        iOrder[i] = i;
    }
    for (int i = 1; i < iCount; i++) {
        int tmp = iOrder[i];
        int j = i - 1;
        while (j >= 0 && fPct[iOrder[j]] > fPct[tmp]) {
            iOrder[j + 1] = iOrder[j];
            j--;
        }
        iOrder[j + 1] = tmp;
    }

    // Minimum flow separation; of a too-close cluster the earliest spawn wins.
    if (fSep > 0.0) {
        float fLastKept = -1.0;
        for (int k = 0; k < iCount; k++) {
            int i = iOrder[k];
            if (iReason[i] != PF_KEEP) {
                continue;
            }
            if (fLastKept >= 0.0 && fPct[i] - fLastKept < fSep) {
                iReason[i] = PF_CULL_SEP;
            } else {
                fLastKept = fPct[i];
            }
        }
    }

    /*
        Enforce the pills limit here, evenly spaced by flow.
        Spawns without flow data can't be spaced, so they occupy limit slots off the top.
    */
    if (iCustomPill_limit >= 0) {
        int iKept = 0, iNoFlow = 0;
        for (int i = 0; i < iCount; i++) {
            if (iReason[i] == PF_KEEP) {
                iKept++;
            } else if (iReason[i] == PF_NO_FLOW) {
                iNoFlow++;
            }
        }

        int iSlots = iCustomPill_limit - iNoFlow;
        if (iSlots < 0) {
            /*
                More flowless spawns than the limit alone allows: remove the extra.
                No flow data means there is nothing to space them by, so array order decides
            */
            int iExcess = -iSlots;
            for (int i = iCount - 1; i >= 0 && iExcess > 0; i--) {
                if (iReason[i] == PF_NO_FLOW) {
                    iReason[i] = PF_CULL_LIMIT;
                    iExcess--;
                }
            }
            iSlots = 0;
        }

        if (iSlots < iKept) {
            bool[] bSelected = new bool[iCount];
            for (int slot = 0; slot < iSlots; slot++) {
                // Ideal flow for this slot
                float fWant = fFlowMin + (fFlowMax - fFlowMin) * (float(slot) + 0.5) / float(iSlots);

                int best = -1;
                float fBestDist = 0.0;
                for (int i = 0; i < iCount; i++) {
                    if (iReason[i] != PF_KEEP || bSelected[i]) {
                        continue;
                    }
                    float d = fPct[i] - fWant;
                    if (d < 0.0) {
                        d = -d;
                    }
                    if (best == -1 || d < fBestDist) {
                        best = i;
                        fBestDist = d;
                    }
                }
                if (best != -1) {
                    bSelected[best] = true;
                }
            }

            for (int i = 0; i < iCount; i++) {
                if (iReason[i] == PF_KEEP && !bSelected[i]) {
                    iReason[i] = PF_CULL_LIMIT;
                }
            }
        }
    }

    // Apply: kill+erase culled spawns (descending so indices stay valid), or
    // just glow everything in visualize mode.
    int iRemoved[4] = {0, ...};   // indexed by PF_CULL_* reason

    for (int i = iCount - 1; i >= 0; i--) {
        hSpawns.GetArray(i, curitem, sizeof(curitem));

        if (iReason[i] <= PF_KEEP) {
            if (IsDebugEnabled()) {
                LogMessage("[%s] Pill spawn %d flow=%.1f%% KEPT%s", "rotoblin.healthcontrol", curitem.IT_entity,
                    fPct[i] * 100.0, iReason[i] == PF_NO_FLOW ? " (no flow data)" : "");
            }
            if (iVisualize > 0) {
                //L4D2_SetEntityGlow(curitem.IT_entity, L4D2Glow_Constant, 0, 0, PF_GLOW_KEEP, false);
                CreateGlowAndSprite(curitem.IT_entity, PF_GLOW_KEEP);
            }
            continue;
        }

        if (IsDebugEnabled()) {
            static const char sReasons[4][] = {"", "outside window", "separation", "limit spacing"};
            LogMessage("[%s] Pill spawn %d flow=%.1f%% %s (%s)", "rotoblin.healthcontrol", curitem.IT_entity,
                fPct[i] * 100.0, bVisualize ? "WOULD REMOVE" : "REMOVED", sReasons[iReason[i]]);
        }
        iRemoved[iReason[i]]++;

        if (bVisualize) {
            //L4D2_SetEntityGlow(curitem.IT_entity, L4D2Glow_Constant, 0, 0, PF_GLOW_CULL[iReason[i]], false);
			CreateGlowAndSprite(curitem.IT_entity, PF_GLOW_CULL[iReason[i]]);
	    } else {
            if (IsValidEntity(curitem.IT_entity)) {
                RemoveEntity(curitem.IT_entity);
            }
            hSpawns.Erase(i);
        }
    }

    if (IsDebugEnabled()) {
        LogMessage("[%s] Pill flow window %.0f%%-%.0f%% sep %.1f%%: %d kept, %d %s (window), %d (separation), %d (limit spacing).%s",
            "rotoblin.healthcontrol", fFlowMin * 100.0, fFlowMax * 100.0, fSep * 100.0,
            iCount - iRemoved[PF_CULL_WINDOW] - iRemoved[PF_CULL_SEP] - iRemoved[PF_CULL_LIMIT],
            iRemoved[PF_CULL_WINDOW], bVisualize ? "flagged" : "removed",
            iRemoved[PF_CULL_SEP], iRemoved[PF_CULL_LIMIT],
            bVisualize ? " (visualize: nothing deleted; white = kept, red = window, orange = separation, cyan = limit)" : "");
    }

    return true;
}

static void CreateGlowAndSprite(int pill, const char[] sColor)
{
    int glow = CreateEntityByName("prop_glowing_object");
    if( CheckIfEntitySafe(glow) )
	{
		static char sModelName[64];
		GetEntPropString(pill, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName));
    
		DispatchKeyValue(glow, "model", sModelName);
		DispatchKeyValue(glow, "disableshadows", "1");
		DispatchKeyValue(glow, "targetname", "rotoblin.healthcontrol");
		
		DispatchKeyValue(glow, "StartGlowing", "1");
		DispatchKeyValue(glow, "GlowForTeam", "-1");

		/* GlowForTeam =  -1:ALL  , 0:NONE , 1:SPECTATOR  , 2:SURVIVOR , 3:INFECTED */
		
		float vPos[3], vAng[3];
		GetEntPropVector(pill, Prop_Send, "m_vecOrigin", vPos);
		GetEntPropVector(pill, Prop_Send, "m_angRotation", vAng);
		TeleportEntity(glow, vPos, vAng, NULL_VECTOR);
		DispatchSpawn(glow);
		SetEntityRenderFx(glow, RENDERFX_FADE_FAST);
		SetEntProp(glow, Prop_Send, "m_CollisionGroup", 0);
		SetEntProp(glow, Prop_Send, "m_nSolidType", 0);
		SetVariantString("!activator");
		AcceptEntityInput(glow, "SetParent", pill); 
	}

	int sprite       = CreateEntityByName("env_sprite");
	if( CheckIfEntitySafe(sprite) )
	{
		DispatchKeyValue(sprite, "spawnflags", "1");

		DispatchKeyValue(sprite, "model", "materials/vgui/icon_arrow_down.vmt");
		DispatchKeyValue(sprite, "rendercolor", sColor);
		DispatchKeyValue(sprite, "renderamt", "255"); // If renderamt goes before rendercolor, it doesn't render
		DispatchKeyValueFloat(sprite, "scale", 1.0);
		DispatchKeyValue(sprite, "fademindist", "-1");

		DispatchSpawn(sprite);
		ActivateEntity(sprite);

		float vSpritePos[3];
		GetEntPropVector(pill, Prop_Send, "m_vecOrigin", vSpritePos);

		vSpritePos[2] += 30.0;
		TeleportEntity(sprite, vSpritePos, NULL_VECTOR, NULL_VECTOR);

		AcceptEntityInput(sprite, "ShowSprite");
	}
}

#define ENTITY_SAFE_LIMIT 2000
static bool CheckIfEntitySafe(int entity)
{
	if(entity == -1) return false;

	if(	entity > ENTITY_SAFE_LIMIT)
	{
		AcceptEntityInput(entity, "Kill");
		return false;
	}
	return true;
}

static void GetSpawnOrigins(float buf[3], const ItemTracking spawn)
{
    buf[0] = spawn.IT_origins;
    buf[1] = spawn.IT_origins1;
    buf[2] = spawn.IT_origins2;
}