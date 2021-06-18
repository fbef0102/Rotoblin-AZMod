#pragma semicolon 1

#include <sourcemod>
#include <left4downtown>

static const deadstopSequences[] = {60, 64, 67};
static const deadstopSequences2[] = {68,59};
//踢牆:68,59
//飛著:67,60,64
//蹲著:8,14
//站著:3,4,5
//跳著:51
static Handle:hCvarFlags;
static Handle:hCvarFlags2;
static g_bCvarcontrolvalue;
static g_bCvarcontrolvalue2;
#define DEBUG 0
#define POUNCE_TIMER            0.1

#if DEBUG
static					g_iOffsetFallVelocity					= -1;
static	const	String:	CLASSNAME_TERRORPLAYER[] 				= "CTerrorPlayer";
static	const	String:	NETPROP_FALLVELOCITY[]					= "m_flFallVelocity";
#endif

new     bool:           bIsPouncing[MAXPLAYERS+1]; 
static bool:PluginDisable = false;

public Plugin:myinfo = 
{
	name = "L4D No Hunter Deadstops",
	author = "Visor, l4d1 port by Harry",
	description = "Self-descriptive",
	version = "3.9",
	url = "https://github.com/Attano/Equilibrium"
};

public OnPluginStart()
{
	hCvarFlags = FindConVar("versus_shove_hunter_fov_pouncing");
	hCvarFlags2 = FindConVar("versus_shove_hunter_fov");
	HookConVarChange(hCvarFlags, OnCvarChange_control);
	HookConVarChange(hCvarFlags2, OnCvarChange_control);
	g_bCvarcontrolvalue = GetConVarInt(hCvarFlags);
	g_bCvarcontrolvalue2 = GetConVarInt(hCvarFlags2);
	
	#if DEBUG
		g_iOffsetFallVelocity = FindSendPropInfo(CLASSNAME_TERRORPLAYER, NETPROP_FALLVELOCITY);
		if (g_iOffsetFallVelocity <= 0) ThrowError("Unable to find fall velocity offset!");
	#endif
	
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
	HookEvent("player_shoved", Event_PlayerShoved, EventHookMode_Post);
	HookEvent("ability_use", Event_AbilityUse, EventHookMode_Post);
}

public Action:L4D_OnShovedBySurvivor(shover, shovee, const Float:vector[3])
{
	if (!IsSurvivor(shover) || !IsHunter(shovee))
		return Plugin_Continue;
		
	if(IsPluginDisable()) return Plugin_Continue;

		
	#if DEBUG 
		PrintToChatAll("\x01Invoked \x04L4D_OnShovedBySurvivor\x01 on \x03%N\x01", shovee);
		if(IsPlayerOnPlayer(shovee))
			PrintToChatAll("hunter is on my head");
		if(GetEntDataFloat(shovee, g_iOffsetFallVelocity) == 0.0) PrintToChatAll("FALL:0");	
		if(GetEntProp(shovee, Prop_Data, "m_fFlags") & FL_ONGROUND) PrintToChatAll("On The Ground");
	#endif
	
	// 一代hunter高撲撲到人的時候有時會變成先"落地"在人類頭上在判定高撲傷害 導致因為有"落地"所以可以被推到
	if (IsPlayingDeadstopAnimation(shovee)&&IsPlayerOnPlayer(shovee))//如果高撲被推的時候判定hunter"落地"在人類頭上, 則推不算
	{
		return Plugin_Handled;
	}
	
	if (IsPlayingDeadstopAnimation2(shovee))//踢牆高處飛被推
	{
		return Plugin_Handled;
	}
	
	if(bIsPouncing[shovee])
	{
	#if DEBUG 
		PrintToChatAll("Hunter:%N is still pouncing!",shovee);
	#endif
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public Action:L4D_OnEntityShoved(client, entity, weapon, const Float:vector[3])
{
	if (!IsSurvivor(client) || !IsHunter(entity))
		return Plugin_Continue;
	
	if(IsPluginDisable()) return Plugin_Continue;
		
	#if DEBUG
		PrintToChatAll("\x01Invoked \x04L4D_OnEntityShoved\x01 on \x03%N\x01", entity);
		if(IsPlayerOnPlayer(entity))
			PrintToChatAll("hunter is on my head");
		if(GetEntDataFloat(entity, g_iOffsetFallVelocity) == 0.0) PrintToChatAll("FALL:0");	
		if(GetEntProp(entity, Prop_Data, "m_fFlags") & FL_ONGROUND) PrintToChatAll("On The Ground");
	#endif
	
	if (IsPlayingDeadstopAnimation(entity)&&IsPlayerOnPlayer(entity))
	{
		return Plugin_Handled;
	}
	
	if (IsPlayingDeadstopAnimation2(entity))//踢牆高處飛被推
	{
		return Plugin_Handled;
	}
	
	if(bIsPouncing[entity])
	{
	#if DEBUG 
		PrintToChatAll("Hunter:%N is still pouncing!",entity);
	#endif
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

stock bool:IsSurvivor(client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2;
}

stock bool:IsInfected(client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3;
}

stock bool:IsHunter(client)  
{
	if (!IsInfected(client))
		return false;
		
	if (!IsPlayerAlive(client))
		return false;

	if (GetEntProp(client, Prop_Send, "m_zombieClass") != 3)
		return false;

	return true;
}

bool:IsPlayingDeadstopAnimation(hunter)  
{
	new sequence = GetEntProp(hunter, Prop_Send, "m_nSequence");
	
	#if DEBUG
		PrintToChatAll("\x04%N\x01 playing sequence \x04%d\x01", hunter, sequence);
	#endif
	
	for (new i = 0; i < sizeof(deadstopSequences); i++)
	{
		if (deadstopSequences[i] == sequence) return true;
	}
	return false;
}

bool:IsPlayingDeadstopAnimation2(hunter)  
{
	new sequence = GetEntProp(hunter, Prop_Send, "m_nSequence");
	
	#if DEBUG
		PrintToChatAll("\x04%N\x01 playing sequence \x04%d\x01", hunter, sequence);
	#endif
	
	for (new i = 0; i < sizeof(deadstopSequences2); i++)
	{
		if (deadstopSequences2[i] == sequence) return true;
	}
	return false;
}

bool:IsPlayerOnPlayer(client)
{
	new entity = GetEntPropEnt(client, Prop_Send, "m_hGroundEntity");
	if ( !IsSurvivor(entity)){ return false; }
	return ( (GetEntProp(client, Prop_Data, "m_fFlags") & FL_ONGROUND) && IsPlayerAlive( entity ) ) ;
}

public OnCvarChange_control(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (!StrEqual(oldValue, newValue))
	{
		g_bCvarcontrolvalue = GetConVarInt(hCvarFlags);
		g_bCvarcontrolvalue2 = GetConVarInt(hCvarFlags2);
		
		if( (g_bCvarcontrolvalue == 0 && g_bCvarcontrolvalue2 ==0) || g_bCvarcontrolvalue!=0 )
		{
			PluginDisable = true;
		}
		else
			PluginDisable = false;
	}
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
    for (new i=1; i <= MaxClients; i++)
    {
        bIsPouncing[i] = false;
    }
}

public Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
    new victim = GetClientOfUserId(GetEventInt(event, "userId"));
    
    if (!IsClientAndInGame(victim)) { return; }
    
    bIsPouncing[victim] = false;
}

public Event_PlayerShoved(Handle:event, const String:name[], bool:dontBroadcast)
{
    new victim = GetClientOfUserId(GetEventInt(event, "userId"));
    
    if (!IsClientAndInGame(victim)|| GetClientTeam(victim) != 3 ) { return; }
    
    bIsPouncing[victim] = false;
}

public Event_AbilityUse(Handle:event, const String:name[], bool:dontBroadcast)
{
    // track hunters pouncing
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    new String:abilityName[64];
    
    if (!IsClientAndInGame(client) || GetClientTeam(client) != 3 ) { return; }
    
    GetEventString(event, "ability", abilityName, sizeof(abilityName));
    
    if (!bIsPouncing[client] && strcmp(abilityName, "ability_lunge", false) == 0)
    {
        // Hunter pounce
        bIsPouncing[client] = true;                                // use this to track pouncing
        
        CreateTimer(POUNCE_TIMER, Timer_GroundTouch, client, TIMER_REPEAT); // check every TIMER whether the pounce has ended
                                                                            // If the hunter lands on another player's head, they're technically grounded.
                                                                            // Instead of using isGrounded, this uses the bIsPouncing[] array with less precise timer
    }
}

bool:IsOnLadder(entity)
{
    return GetEntityMoveType(entity) == MOVETYPE_LADDER;
}

public Action: Timer_GroundTouch(Handle:timer, any:client)
{
    if (IsClientAndInGame(client) && ((IsGrounded(client)) || !IsPlayerAlive(client) || IsOnLadder(client) || !bIsPouncing[client]) )
    {
        // Reached the ground (not human head) or died in mid-air or on ladder
        bIsPouncing[client] = false;
        return Plugin_Stop;
    }
    
    return Plugin_Continue;
}

public bool:IsGrounded(client)
{
	new entity = GetEntPropEnt(client, Prop_Send, "m_hGroundEntity");
	if ( IsSurvivor(entity) && IsPlayerAlive(entity)){ return false; } //落的地方是人類頭上
	return (GetEntProp(client,Prop_Data,"m_fFlags") & FL_ONGROUND) > 0;
}

bool:IsClientAndInGame(index)
{
    if (index > 0 && index < MaxClients)
    {
        return IsClientInGame(index);
    }
    return false;
}

bool:IsPluginDisable()
{
	return PluginDisable;
}