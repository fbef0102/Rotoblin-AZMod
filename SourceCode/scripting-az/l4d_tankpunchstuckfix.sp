#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
#include <multicolors>
#include <l4d_lib>

#define DEBUG_MODE              0

#define TEAM_SPECTATOR          1
#define TEAM_SURVIVOR           2
#define TEAM_INFECTED           3

#define SEQ_FLIGHT_BILL_LOUIS   544
#define SEQ_FLIGHT_FRANCIS      545
#define SEQ_FLIGHT_ZOEY         526

#define TIMER_CHECKPUNCH        0.025   // interval for checking 'flight' of punched survivors
#define TIME_CHECK_UNTIL        0.5     // try this long to find a stuck-position, then assume it's OK

enum eTankWeapon
{
    TANKWEAPON
}

new     bool:       g_bLateLoad                                 = false;

new     Float:      g_fPlayerPunch          [MAXPLAYERS + 1];                           // when was the last tank punch on this player?
new     bool:       g_bPlayerFlight         [MAXPLAYERS + 1];                           // is a player in (potentially stuckable) punched flight?
new     Float:      g_fPlayerStuck          [MAXPLAYERS + 1];                           // when did the (potential) 'stuckness' occur?
new     Float:      g_fPlayerLocation       [MAXPLAYERS + 1][3];                        // where was the survivor last during the flight?

new     Handle:     g_hCvarDeStuckTime                          = INVALID_HANDLE;       // convar: how long to wait and de-stuckify a punched player
new 	Handle: 	tpsf_debug_print;
new modelnum[MAXPLAYERS + 1];
static bool:TankPounchClient[MAXPLAYERS + 1];

public Plugin:myinfo = 
{
    name =          "Tank Punch Ceiling Stuck Fix",
    author =        "Tabun, Visor, HarryPotter",
    description =   "Fixes the problem where tank-punches get a survivor stuck in the roof,L4D1 windows signature by Harry",
    version =       "0.5",
    url =           "nope"
}

public APLRes:AskPluginLoad2( Handle:plugin, bool:late, String:error[], errMax)
{
	CreateNative("IsTankPounchClient", Native_IsTankPounchClient);
	g_bLateLoad = late;
	return APLRes_Success;
}

public Native_IsTankPounchClient(Handle:plugin, numParams)
{
   new num1 = GetNativeCell(1);
   return TankPounchClient[num1];
}

public OnPluginStart()
{
    LoadTranslations("Roto2-AZ_mod.phrases");
    // hook already existing clients if loading late
    if (g_bLateLoad) {
        for (new i = 1; i < MaxClients+1; i++) {
            if (IsClientInGame(i)) {
                SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
            }
        }
    }
    
    // cvars
    g_hCvarDeStuckTime = CreateConVar(      "sm_punchstuckfix_unstucktime",     "1.0",      "How many seconds to wait before detecting and unstucking a punched motionless player.", FCVAR_NOTIFY, true, 0.05, false);
    tpsf_debug_print = CreateConVar("tpsf_debug_print", "1","Enable the Debug Print?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	
    // hooks
    HookEvent("round_start", RoundStart_Event, EventHookMode_PostNoCopy);
    HookEvent("player_bot_replace", OnBotSwap);
    HookEvent("bot_player_replace", OnBotSwap);
    HookEvent("player_spawn", OnPlayerSpawn);
}


/* --------------------------------------
 *      General hooks / events
 * -------------------------------------- */

public OnClientPutInServer(client)
{
    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public OnMapStart()
{
    setCleanSlate();
}

public Action: RoundStart_Event (Handle:event, const String:name[], bool:dontBroadcast)
{
    setCleanSlate();
    for(new i = 1; i <= MaxClients; i++) 
    {
        TankPounchClient[i] = false;
    }
}


/* --------------------------------------
 *     GOT MY EYES ON YOU, PUNCH
 * -------------------------------------- */

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
    if (damagetype != DMG_CLUB || !IsTankWeapon(inflictor)) {
        return Plugin_Continue;
    }

    if (!IsClientAndInGame(victim) || GetClientTeam(victim) != TEAM_SURVIVOR ) {
        return Plugin_Continue;
    }

    PrintDebug("IsTankWeapon - victim: (%N) %d, attacker: (%N) %d, inflictor: %d, damage: %f, damagetype: %d", victim, victim, attacker, attacker, inflictor, damage, damagetype);

    // tank punched survivor, check the result
    g_fPlayerPunch[victim] = GetTickedTime();
    g_bPlayerFlight[victim] = false;
    g_fPlayerStuck[victim] = 0.0;
    g_fPlayerLocation[victim][0] = 0.0;
    g_fPlayerLocation[victim][1] = 0.0;
    g_fPlayerLocation[victim][2] = 0.0;

    static char sModel[31];
    GetEntPropString(victim, Prop_Data, "m_ModelName", sModel, sizeof(sModel));

    switch(sModel[29])
    {
        case 'v'://bill (survivor_namvet)
        {
            modelnum[victim] = 1;
        }
        case 'n'://zoey (survivor_teenangst)
        {
            modelnum[victim] = 2;
        }
        case 'e'://francis (survivor_biker)
        {
            modelnum[victim] = 3;
        }
        case 'a'://louis (survivor_manager)
        {
            modelnum[victim] = 4;
        }
    }
        
    CreateTimer(TIMER_CHECKPUNCH, Timer_CheckPunch, GetClientUserId(victim), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
    return Plugin_Continue;
}

public Action Timer_CheckPunch(Handle hTimer, int userid)
{
    int client = GetClientOfUserId(userid);
    // stop the timer when we no longer have a proper client
    if (!IsclientAndInGame(client) || GetClientTeam(client) != TEAM_SURVIVOR) { return Plugin_Stop; }

    // stop the time if we're passed the time for checking
    if (GetTickedTime() - g_fPlayerPunch[client] > TIME_CHECK_UNTIL && g_fPlayerStuck[client])
    {
        g_fPlayerPunch[client] = 0.0;
        g_bPlayerFlight[client] = false;
        g_fPlayerStuck[client] = 0.0;
        
        return Plugin_Stop;
    }

    // get current animation frame and location of survivor
    new iSeq = GetEntProp(client, Prop_Send, "m_nSequence");
    PrintDebug("[test] %N - %d", client, iSeq);

    // if the player is not in flight, check if they are
    if ( IsPlayerAlive(client) && (( iSeq == SEQ_FLIGHT_BILL_LOUIS && (modelnum[client] == 1 || modelnum[client] == 4) 
    || (iSeq == SEQ_FLIGHT_FRANCIS && modelnum[client] == 3 ) 
    || (iSeq == SEQ_FLIGHT_ZOEY && modelnum[client] == 2) ) ) )
    {
        
        new Float: vOrigin[3];
        GetEntPropVector(client, Prop_Send, "m_vecOrigin", vOrigin);
        
        if (!g_bPlayerFlight[client])
        {
            // if the player is not detected as in punch-flight, they are now
            g_bPlayerFlight[client] = true;
            g_fPlayerLocation[client] = vOrigin;

            PrintDebug("[test] %i - flight start [seq:%4i][loc:%.f %.f %.f]", client, iSeq, vOrigin[0], vOrigin[1], vOrigin[2]);
        }
        else
        {
            // if the player is in punch-flight, check location / difference to detect stuckness
            if (GetVectorDistance(g_fPlayerLocation[client], vOrigin) == 0.0) {
                
                // are we /still/ in the same position? (ie. if stucktime is recorded)
                if (g_fPlayerStuck[client])
                {
                    g_fPlayerStuck[client] = GetTickedTime();    
                }
                else
                {
                    if (GetTickedTime() - g_fPlayerStuck[client] > GetConVarFloat(g_hCvarDeStuckTime))
                    {
                        // time passed, player is stuck! fix.
                        //LogMessage("<TankPunchStuck> %N - stuckness FIX triggered!", client);
                        
                        g_fPlayerPunch[client] = 0.0;
                        g_bPlayerFlight[client] = false;
                        g_fPlayerStuck[client] = 0.0;

                        CTerrorPlayer_WarpToValidPositionIfStuck(client);
                        if(GetConVarBool(tpsf_debug_print)) 
                        {
                            decl String:clientName[128];
                            GetClientName(client,clientName,128);
                            CPrintToChatAll("%t","l4d_tankpunchstuckfix", clientName);
                        }
                        return Plugin_Stop;
                    }
                }
            }
            else
            {
                // if we were detected as stuck, undetect
                if (g_fPlayerStuck[client])
                {
                    g_fPlayerStuck[client] = 0.0;
                }
            }
        }
    }
    else if (!IsPlayerAlive(client))
    {
        TankPounchClient[client] = true;
        return Plugin_Stop;
    }
    else if ( IsIncapacitated(client) || GetEntProp(client, Prop_Send, "m_isHangingFromLedge") ||
        ( iSeq == SEQ_FLIGHT_BILL_LOUIS+1 && (modelnum[client] == 1 || modelnum[client] == 4) ) 
        || (iSeq == SEQ_FLIGHT_FRANCIS+1 && modelnum[client] == 3)  
        || (iSeq == SEQ_FLIGHT_ZOEY+1 && modelnum[client] == 2) )
    {
        if (g_bPlayerFlight[client])
        {
            // landing frame, so not stuck
            g_fPlayerPunch[client] = 0.0;
            g_bPlayerFlight[client] = false;
            g_fPlayerStuck[client] = 0.0;

            PrintDebug("[test] %i - flight end (natural)", client);
        }
        
        return Plugin_Stop;
    }

    return Plugin_Continue;
}

/* --------------------------------------
 *     Shared function(s)
 * -------------------------------------- */

stock bool:IsclientAndInGame(index)
{
    return (index > 0 && index <= MaxClients && IsClientInGame(index));
}


stock setCleanSlate()
{
    new i, maxplayers = MaxClients;
    for (i = 1; i <= maxplayers; i++)
    {
        g_fPlayerPunch[i] = 0.0;
        g_bPlayerFlight[i] = false;
        g_fPlayerStuck[i] = 0.0;
        g_fPlayerLocation[i][0] = 0.0;
        g_fPlayerLocation[i][1] = 0.0;
        g_fPlayerLocation[i][2] = 0.0;
    }
}

public PrintDebug(const String:Message[], any:...)
{
    #if DEBUG_MODE
        decl String:DebugBuff[256];
        VFormat(DebugBuff, sizeof(DebugBuff), Message, 2);
        PrintToChatAll(DebugBuff);
    #endif
}

stock void CTerrorPlayer_WarpToValidPositionIfStuck(int client)
{
	L4D_WarpToValidPositionIfStuck(client);
}

public Action:OnBotSwap(Handle:event, const String:name[], bool:dontBroadcast) 
{
	new bot = GetClientOfUserId(GetEventInt(event, "bot"));
	new player = GetClientOfUserId(GetEventInt(event, "player"));
	if (IsClientIndex(bot) && IsClientIndex(player)) 
	{
		if (StrEqual(name, "player_bot_replace")) 
		{
			TankPounchClient[bot] = TankPounchClient[player];
			TankPounchClient[player] = false;
			
		}
		else 
		{
			TankPounchClient[player] = TankPounchClient[bot];
			TankPounchClient[bot] = false;
		}
	}
	return Plugin_Continue;
}

public Action:OnPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(client && IsClientInGame(client))
	{
		TankPounchClient[client] = false;
	}
}

bool:IsClientIndex(client)
{
	return (client > 0 && client <= MaxClients);
}

bool IsTankWeapon(int entity)
{
	if (entity >= MaxClients + 1 && IsValidEntity(entity)) {
		char eName[32];
		GetEntityClassname(entity, eName, sizeof(eName));
		return (strcmp("weapon_tank_claw", eName) == 0/* || strcmp("tank_rock", eName) == 0*/);
	}

	return false;
}