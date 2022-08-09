/*
 * ============================================================================
 *
 *  Rotoblin
 *
 *  File:			rotoblin.meleefatigue.sp
 *  Type:			Module
 *  Description:	Allows users to mess with how quickly melee fatigue kicks in.
 *
 *					The way this works is kinda finicky.  Instead of being able to control the 
 *					number of melees performed before fatigue kicks in, all you can really do
 *					is add (or .. not add!) to the shove penalty count for the particular client who 
 *					is meleeing.
 *					
 *					The penalty count is an integer that is usually in the range of 0 to 6 (inclusive).
 *					
 *					Each 'standard' (as in, unmodded) melee adds one to the penalty count when   
 *					cooloff period has not been obeyed.  The cooloff period exists to stop people 
 *					melee spamming; if you wait ages between melees, then your penalty count will
 *					never climb above 1.  
 *
 *					When the penalty reaches 4, the melee succeeds, but fatigue begins, causing the 
 * 					time between each successive melee to increase.  Meleeing when already fatigued 
 *					(possible when penalty is 4 and 5) will increase penalty up to a maximum of 6.  
 * 					The cooldown period markedly increases with each melee when fatigued.
 *			
 *					While we could do more fancy stuff to have our own non-standard cooldown stuff, 
 *					it would probably involve the client being unable to predict/sync properly
 *
 *	Credits/Based on:	http://forums.alliedmods.net/showthread.php?t=138496 (AtomicStryker)
 *
 *  Copyright (C) 2010  Defrag <mjsimpson@gmail.com> 
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

/**
 * How much of a shove penalty will be added if a client melees when not fatigued. 
 * If you _are_ fatigued (you can tell when you're fatigued, as meleeing causes the 
 * "I'm bloody knackered, mate" icon to appear), then the game will just add the 
 * standard count of 1 to your shove penalty, capped at a maximum of maximum of 6.
 *
 * I.e. this setting only has an effect until you're fatigued, at which point the
 * standard code takes over.
 */
static g_nonFatiguedMeleePenalty					= 1;  
static Handle:g_hNonFatiguedMeleePenalty_CVAR	= INVALID_HANDLE;

// shove penalty on a client before we stop adding to it and just let the game take over.
static const MAX_EXISTING_FATIGUE					= 3; 

static const Float:MELEE_DURATION					= 0.6;

static bool:soundHookDelay[MAXPLAYERS+1] 			= {false};

static			g_iDebugChannel						= 0;
static	const	String:	DEBUG_CHANNEL_NAME[]	= "MeleeFatigue";

static const String: MELEE_SOUND_NAME_SEARCH[]	= "Swish"; 

// **********************************************
//                   Forwards
// **********************************************

/**
 * Plugin is starting.
 *
 * @noreturn
 */
public _MeleeFatigue_OnPluginStart()
{
	HookPublicEvent(EVENT_ONPLUGINENABLE, _MF_OnPluginEnabled);
	HookPublicEvent(EVENT_ONPLUGINDISABLE, _MF_OnPluginDisabled);

	// Create convar
	CreateIntConVar(
		g_hNonFatiguedMeleePenalty_CVAR, 
		"melee_penalty", 
		"Sets the value to be added to a survivor's shove penalty.  This _only_ gets added when that survivor is not already fatigued (so basically, setting this to a large value will make the survivors become fatigued more quickly, but the cooldown effect won't change once fatigue has set in)", 
		g_nonFatiguedMeleePenalty);
		
	UpdateNonFatiguedMeleePenalty();
	
	g_iDebugChannel = DebugAddChannel(DEBUG_CHANNEL_NAME);
	DebugPrintToAllEx("Module is now setup.", g_iDebugChannel);
}

static CreateIntConVar(&Handle:conVar, const String:cvarName[], const String:cvarDescription[], int initialValue)
{
	// Create convar
	decl String:buffer[10];
	IntToString(initialValue, buffer, sizeof(buffer)); // Get default value for replacement style
	
	conVar = CreateConVarEx(cvarName, buffer, 
		cvarDescription, 
		FCVAR_NOTIFY);
	
	if (conVar == INVALID_HANDLE) 
	{
		ThrowError("Unable to create enable cvar named %s!", cvarName);
	}
	
	AddConVarToReport(conVar); // Add to report status module
}

/**
 * Plugin is now enabled.
 *
 * @noreturn
 */
public _MF_OnPluginEnabled()
{
	UpdateNonFatiguedMeleePenalty();
	
	AddNormalSoundHook(HookSound_Callback);
	HookConVarChange(g_hNonFatiguedMeleePenalty_CVAR, _MF_MeleePenalty_CvarChange);	
	DebugPrintToAllEx("Module is now loaded");
}

/**
 * Plugin is now disabled.
 *
 * @noreturn
 */
public _MF_OnPluginDisabled()
{	
	RemoveNormalSoundHook(HookSound_Callback);
	UnhookConVarChange(g_hNonFatiguedMeleePenalty_CVAR, _MF_MeleePenalty_CvarChange);	
	
	DebugPrintToAllEx("Module is now unloaded");
}

/**
 * cvar changed.
 *
 * @param convar		Handle to the convar that was changed.
 * @param oldValue		String containing the value of the convar before it was changed.
 * @param newValue		String containing the new value of the convar.
 * @noreturn
 */
 public _MF_MeleePenalty_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	DebugPrintToAllEx("melee penalty changed. Old value %s, new value %s", oldValue, newValue);
	UpdateNonFatiguedMeleePenalty();
}

/**
 * callback function for a sound being played.  Used to determine whether a survivor 
 * is meleeing, then to modify the shove penalty (if applicable).
 *
 * @param Clients		unused
 * @param NumClients	unused
 * @param StrSample		A string containing the name of the played sound sample
 * @param Entity		The entity that triggered the sound.  
 * @returns				event status
 */
public Action:HookSound_Callback(int Clients[64], int &iNumClients, char StrSample[PLATFORM_MAX_PATH], int &Entity, int &iChannel, float &fVolume, int &fLevel, int &iPitch, int &iFlags)
{
	// Only execute if appropriate.  
	
	// Note: This is potentially wasteful, as the callback will be getting fired for each sound 
	// even if the melee penalty is set to 1 (the default).  It may be better to hook/unhook the 
	// callback when the feature is enabled/disabled, but let's keep it simple for now.
	if(!ShouldPerformCustomFatigueLogic(StrSample, Entity))
	{
		return Plugin_Continue;
	}

	// the player just started to shove
	soundHookDelay[Entity] = true;
	CreateTimer(MELEE_DURATION, ResetsoundHookDelay, Entity);
		
	// we need to subtract 1 from the current shove penalty prior to applying 
	// our own as the game has already incremented the shove penalty before we got hold of it.
	new shovePenalty = L4D_GetMeleeFatigue(Entity) - 1;
	if(shovePenalty < 0)	
		shovePenalty = 0;	
		
	DebugPrintToAllEx("Current shove penalty: %i", shovePenalty);		
		
	if (shovePenalty >= MAX_EXISTING_FATIGUE)
	{
		DebugPrintToAllEx("Current shove penalty is %i, aborting", shovePenalty);
		return Plugin_Continue;
	}
			
	new newFatigue = shovePenalty + g_nonFatiguedMeleePenalty;
	L4D_SetMeleeFatigue(Entity, newFatigue);
	DebugPrintToAllEx("Set shove penalty to %i", newFatigue);	

	return Plugin_Continue;
}

// **********************************************
//                 Private API
// **********************************************

stock L4D_GetMeleeFatigue(client)
{
    return GetEntProp(client, Prop_Send, "m_iShovePenalty", 4);
}
    
stock L4D_SetMeleeFatigue(client, value)
{
    SetEntProp(client, Prop_Send, "m_iShovePenalty", value);
}

public Action:ResetsoundHookDelay(Handle:timer, any:client)
{
    soundHookDelay[client] = false;
}

static bool:ShouldPerformCustomFatigueLogic(const String:StrSample[PLATFORM_MAX_PATH], entity)
{
	// 1 is the standard setting, so just let the game handle it as normal.  
	if (g_nonFatiguedMeleePenalty <= 1) 
		return false;	
	
	// bugfix for some people on L4D2
	if (entity > MAXPLAYERS) 
		return false; 
	
	// note 'entity' means 'client' here
	if (soundHookDelay[entity]) 
		return false; 
	
	// Do the string contains last, as it's the most expensive check.	
	if (StrContains(StrSample, MELEE_SOUND_NAME_SEARCH, false) == -1) 
		return false;
		
	return true;
}

static UpdateNonFatiguedMeleePenalty()
{
	g_nonFatiguedMeleePenalty = GetConVarInt(g_hNonFatiguedMeleePenalty_CVAR);
		
	DebugPrintToAllEx("Updated non fatigued melee penalty global var; %b", g_nonFatiguedMeleePenalty);
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