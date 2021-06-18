#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define TEAM_SURVIVOR           2
#define TEAM_INFECTED           3

#define ZC_SMOKER               1
#define ZC_BOOMER               2
#define ZC_HUNTER               3
#define ZC_TANK   				5

#define POUNCE_TIMER            0.1


// CVars
new     bool:           bLateLoad                                               = false;
new     Handle:         hCvarPounceInterrupt                                    = INVALID_HANDLE;

new                     iHunterSkeetDamage[MAXPLAYERS+1];                                               // how much damage done in a single hunter leap so far
new     bool:           bIsPouncing[MAXPLAYERS+1];                                                      // whether hunter player is currently pouncing/lunging
new Handle:hCvarHunterStaggerDamageDisable;
new CvarHunterStaggerDamageDisable;
/*
    
    Notes
    -----
        For some reason, m_isLunging cannot be trusted. Some hunters that are obviously lunging have
        it set to 0 and thus stay unskeetable. Have to go with the clunky tracking for now.
        
                abilityEnt = GetEntPropEnt(victim, Prop_Send, "m_customAbility");
                new bool:isLunging = false;
                if (abilityEnt > 0) {
                    isLunging = bool:GetEntProp(abilityEnt, Prop_Send, "m_isLunging");
                }
                
    Changelog
    ---------
        
        1.0.1
            - Fixed incorrect bracketing that caused error spam.
        
        1.0.0
            - Blocked AI scratches-while-stumbling from doing any damage.
            - Replaced clunky charger tracking with simple netprop check.
        
        0.0.5 and older
            - Small fix for chargers getting 1 damage for 0-damage events.
            - simulates human-charger damage behavior while charging for AI chargers.
            - simulates human-hunter skeet behavior for AI hunters.

    -----------------------------------------------------------------------------------------------------------------------------------------------------
 */
#define MAX_STAGGER_DURATION 2.5
#define GAMEDATA_FILE "staggersolver"
new Handle:g_hGameMode;
new String:CvarGameMode[20];
static			bool:	g_bProhibitMelee[MAXPLAYERS+1]			= {false};
static			Handle:	g_hProhibitMelee_Timer[MAXPLAYERS+1]	= {INVALID_HANDLE};
new Handle:g_hGameConf;
new Handle:g_hIsStaggering;

public Plugin:myinfo =
{
    name = "Bot SI skeet damage fix",
    author = "Tabun,L4D1 modify by Harry",
    description = "Makes AI SI take (and do) damage like human SI.",
    version = "1.4",
    url = "nope"
}

public APLRes:AskPluginLoad2( Handle:plugin, bool:late, String:error[], errMax)
{
    bLateLoad = late;
    return APLRes_Success;
}


public OnPluginStart()
{
    // cvars
    hCvarPounceInterrupt = FindConVar("z_pounce_damage_interrupt");
    hCvarHunterStaggerDamageDisable = CreateConVar("sm_Hunter_stagger_dmg_disable", "1", "Disable Hunter Damage when stagger.", FCVAR_PLUGIN, true, 0.0);
   
    // events
    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
    HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
    HookEvent("player_shoved", Event_PlayerShoved, EventHookMode_Post);
    HookEvent("ability_use", Event_AbilityUse, EventHookMode_Post);
	
    // hook when loading late
    if (bLateLoad) {
        for (new i = 1; i < MaxClients + 1; i++) {
            if (IsClientAndInGame(i)) {
                SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
            }
        }
    }
	
    CvarHunterStaggerDamageDisable = GetConVarInt(hCvarHunterStaggerDamageDisable);
    HookConVarChange(hCvarHunterStaggerDamageDisable, ConVarChange_hHunterStaggerDamageDisable);
	
    g_hGameMode = FindConVar("mp_gamemode");
    GetConVarString(g_hGameMode,CvarGameMode,sizeof(CvarGameMode));
	
    g_hGameConf = LoadGameConfigFile(GAMEDATA_FILE);
    if (g_hGameConf == INVALID_HANDLE)
        SetFailState("[Stagger Solver] Could not load game config file.");

    StartPrepSDKCall(SDKCall_Player);

    if (!PrepSDKCall_SetFromConf(g_hGameConf, SDKConf_Signature, "IsStaggering"))
        SetFailState("[Stagger Solver] Could not find signature IsStaggering.");
    PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
    g_hIsStaggering = EndPrepSDKCall();
    if (g_hIsStaggering == INVALID_HANDLE)
        SetFailState("[Stagger Solver] Failed to load signature IsStaggering");

    CloseHandle(g_hGameConf);
}

public OnClientPostAdminCheck(client)
{
    // hook bots spawning
    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public OnClientDisconnect(client)
{
    SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
    if (!IsClientAndInGame(victim) || !IsClientAndInGame(attacker) || damage == 0.0) { return Plugin_Continue; }
	
    // AI taking damage
    if (GetClientTeam(victim) == TEAM_INFECTED && IsFakeClient(victim))
    {
        // check if AI is hit while in lunge/charge
        new zombieClass = GetEntProp(victim, Prop_Send, "m_zombieClass");
        switch (zombieClass) {
            
            case ZC_HUNTER: {
                // skeeting mechanic is completely disabled for AI,
                // so we have to replicate it.
                
                iHunterSkeetDamage[victim] += RoundToFloor(damage);
                
                // have we skeeted it?
                if (bIsPouncing[victim] && iHunterSkeetDamage[victim] >= GetConVarInt(hCvarPounceInterrupt))
                {
                    bIsPouncing[victim] = false; 
                    iHunterSkeetDamage[victim] = 0;
                    
                    // this should be a skeet
                    damage = float(GetClientHealth(victim));
                    return Plugin_Changed;
                }
            }
            
        }
    }

    // AI doing damage
    new attackerzombieClass = GetEntProp(attacker, Prop_Send, "m_zombieClass");
    if (CvarHunterStaggerDamageDisable == 1 && GetClientTeam(attacker) == TEAM_INFECTED && IsFakeClient(attacker) && attackerzombieClass!= ZC_TANK)
    {
        if(StrEqual(CvarGameMode,"coop")||StrEqual(CvarGameMode,"survival"))//coop no damage fix
        {
            if(IsInfectedBussy(attacker))
                return Plugin_Continue;
				
            if(IsInfectedBashed(attacker))
            {
                damage = 0.0;
                return Plugin_Changed;
            }
        }
        else if(StrEqual(CvarGameMode,"versus"))
        {
            // check if AI is stumbling, set to 0.0
            if( SDKCall(g_hIsStaggering, attacker) )
            {
                damage = 0.0;
                return Plugin_Changed;
            }
        }
    }
    
    return Plugin_Continue;
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
    // clear SI tracking stats
    for (new i=1; i <= MaxClients; i++)
    {
        iHunterSkeetDamage[i] = 0;
        bIsPouncing[i] = false;
        g_bProhibitMelee[i] = false;
    }
}

public Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
    new victim = GetClientOfUserId(GetEventInt(event, "userId"));
    
    if (!IsClientAndInGame(victim)|| !IsFakeClient(victim)) { return; }
    
    bIsPouncing[victim] = false;
    g_bProhibitMelee[victim] = false;
}

public Event_PlayerShoved(Handle:event, const String:name[], bool:dontBroadcast)
{
    new victim = GetClientOfUserId(GetEventInt(event, "userId"));
    
    if (!IsClientAndInGame(victim)|| !IsFakeClient(victim) || GetClientTeam(victim) != TEAM_INFECTED ) { return; }
    
    bIsPouncing[victim] = false;
	
    if(!g_bProhibitMelee[victim])
	{
        g_bProhibitMelee[victim] = true;
    }
    else
    {
        KillTimer(g_hProhibitMelee_Timer[victim]);
    }
    g_hProhibitMelee_Timer[victim] = CreateTimer(MAX_STAGGER_DURATION, PlayerShoved_Timer, victim);
}
public Action:PlayerShoved_Timer(Handle:timer, any:client)
{
	if (IsClientAndInGame(client))
		g_bProhibitMelee[client] = false;
	else
		g_bProhibitMelee[client] = false;
}

// hunters pouncing / tracking
public Event_AbilityUse(Handle:event, const String:name[], bool:dontBroadcast)
{
    // track hunters pouncing
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    new String:abilityName[64];
    
    if (!IsClientAndInGame(client) || GetClientTeam(client) != TEAM_INFECTED || !IsFakeClient(client)) { return; }
    
    GetEventString(event, "ability", abilityName, sizeof(abilityName));
    
    if (!bIsPouncing[client] && strcmp(abilityName, "ability_lunge", false) == 0)
    {
        // Hunter pounce
        bIsPouncing[client] = true;
        iHunterSkeetDamage[client] = 0;                                     // use this to track skeet-damage
        
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
    if (IsClientAndInGame(client) && ((IsGrounded(client)) || !IsPlayerAlive(client)|| !IsFakeClient(client) || IsOnLadder(client)) )
    {
        // Reached the ground or died in mid-air or on ladder
        bIsPouncing[client] = false;
        return Plugin_Stop;
    }
    
    return Plugin_Continue;
}

public bool:IsGrounded(client)
{
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

public ConVarChange_hHunterStaggerDamageDisable(Handle:convar, const String:oldValue[], const String:newValue[])
{	
	if (!StrEqual(oldValue, newValue))
		CvarHunterStaggerDamageDisable = StringToInt(newValue);
}

stock bool:IsInfectedBussy(client)
{
	return GetEntProp(client, Prop_Send, "m_tongueVictim") > 0 || GetEntProp(client, Prop_Send, "m_pounceVictim") > 0;
}
bool:IsInfectedBashed(client)
{
	return g_bProhibitMelee[client];
}