#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <multicolors>
#include <left4dhooks>


#define TEAM_SPECTATOR      1
#define TEAM_SURVIVOR       2
#define TEAM_INFECTED       3

#define IS_VALID_CLIENT(%1)     (%1 > 0 && %1 <= MaxClients)
#define IS_SURVIVOR(%1)         (GetClientTeam(%1) == 2)
#define IS_INFECTED(%1)         (GetClientTeam(%1) == 3)
#define IS_VALID_INGAME(%1)     (IS_VALID_CLIENT(%1) && IsClientInGame(%1))
#define IS_VALID_SURVIVOR(%1)   (IS_VALID_INGAME(%1) && IS_SURVIVOR(%1))
#define IS_VALID_INFECTED(%1)   (IS_VALID_INGAME(%1) && IS_INFECTED(%1))
#define IS_SURVIVOR_ALIVE(%1)   (IS_VALID_SURVIVOR(%1) && IsPlayerAlive(%1))
#define IS_INFECTED_ALIVE(%1)   (IS_VALID_INFECTED(%1) && IsPlayerAlive(%1))

#define TIMEOUT_TIME    30


// globals

// voting
new     bool:   g_bSrvVoted = false;                // whether anyone in survivor team voted using the command
new     bool:   g_bInfVoted = false;
new             g_iTimeout = 0;                     // how long to wait until a 'time out' is assumed, seconds
#define L4D_TEAM_SURVIVORS 2
#define L4D_TEAM_INFECTED 3
#define L4D_TEAM_SPECTATE 1
new bool:g_shuffle = false;
native IsInReady();
native Is_Ready_Plugin_On();

public Plugin:myinfo = {
    name = "Team Shuffle",
    author = "Tabun (L4D1 port by Harry)",
    description = "Allows teamshuffles by voting or admin-forced during readyup.",
    version = "1.2",
    url = "https://steamcommunity.com/profiles/76561198026784913/"
};

public OnPluginStart ()
{
    LoadTranslations("Roto2-AZ_mod.phrases");
    // events    
    HookEvent("round_start",Event_RoundStart,EventHookMode_PostNoCopy);
    
    // commands:
    RegConsoleCmd( "sm_teamshuffle", Cmd_TeamShuffle, "Vote for a team shuffle.");
    RegConsoleCmd( "sm_shuffle", Cmd_TeamShuffle, "Vote for a team shuffle." );
    RegAdminCmd("sm_forceteamshuffle", Cmd_ForceTeamShuffle,ADMFLAG_BAN,"Shuffle the teams. Only works during readyup. Admins only.");
    RegAdminCmd("sm_forceshuffle", Cmd_ForceTeamShuffle,ADMFLAG_BAN,"Shuffle the teams. Only works during readyup. Admins only.");
}

public Action: Cmd_TeamShuffle ( client, args )
{
    if ( !Is_Ready_Plugin_On() || !IsInReady() )
    {
        if ( client == 0 ) {
            PrintToServer( "[Shuffle] Teams can only be shuffled during ready-up" );
        } else {
            CPrintToChat( client, "[{olive}TS{default}] %T","l4d_teamshuffle1",client,"Team shuffle");
        }
        return Plugin_Handled;
    }
	
    if ( g_iTimeout != 0 && GetTime() < g_iTimeout )
    {
        if ( client == 0 ) 
        {
            PrintToServer( "[Shuffle] Too soon after previous teamshuffle. (Wait %is).", (g_iTimeout - GetTime()) );
	}
	else 
	{
            CPrintToChat( client, "[{olive}TS{default}] %T","l4d_teamshuffle2",client, (g_iTimeout - GetTime()),"Team shuffle");
        }
        return Plugin_Handled;
    }
    if(GetClientTeam(client)==1)
    {
        CPrintToChat(client,"[{olive}TS{default}] %T","You are not in-game!",client);
        return Plugin_Handled;
    }
	
    new freeslots = GetTeamMaxHumans(2)+GetTeamMaxHumans(3);
    new UsedSlots = GetTeamHumanCount(2)+GetTeamHumanCount(3);
    if(freeslots != UsedSlots)
    {
        CPrintToChat(client,"[{olive}TS{default}] %T","l4d_teamshuffle3",client,"Team shuffle");
        return Plugin_Handled;
    }

    g_shuffle = false;
    TeamShuffleVote( client );
    return Plugin_Handled;
}

public Action: Cmd_ForceTeamShuffle ( client, args )
{
    new freeslots = GetTeamMaxHumans(2)+GetTeamMaxHumans(3);
    new UsedSlots = GetTeamHumanCount(2)+GetTeamHumanCount(3);
    if(freeslots != UsedSlots)
    {
        CPrintToChat(client,"[{olive}TS{default}] %T","l4d_teamshuffle3",client,"Team shuffle");
        return Plugin_Handled;
    }
    ShuffleTeams(client,true);
    return Plugin_Handled;
}

public Event_RoundStart (Handle:hEvent, const String:name[], bool:dontBroadcast)
{
    g_bSrvVoted = false;
    g_bInfVoted = false;
    g_iTimeout = GetTime() + 5;
    g_shuffle = false;
}

TeamShuffleVote ( client )
{
    if ( !IS_VALID_SURVIVOR(client) && !IS_VALID_INFECTED(client) ) { return; }
    
    if ( g_bSrvVoted && g_bInfVoted)
    {
        CPrintToChat(client, "[{olive}TS{default}] %T","Shuffle is already in progress!",client,"Team shuffle");
        return;
    }
	
    // status?
    if ( GetClientTeam(client) == TEAM_SURVIVOR )
    {
        if ( g_bInfVoted)
        {
            // survivors respond
            if ( !g_bSrvVoted)
            {
                g_bSrvVoted = true;
                CPrintToChatAll("[{olive}TS{default}] %t","l4d_teamshuffle4","Team shuffle");
                CreateTimer( 3.0, Timer_ShuffleTeams, _, TIMER_FLAG_NO_MAPCHANGE );
            }
        }
        else
        {
            // survivors first
            if ( !g_bSrvVoted )
            {
                g_bSrvVoted = true;
                CPrintToChatAll("[{olive}TS{default}] %t","l4d_teamshuffle5","Team shuffle");
                CPrintToChatAll("%t","The Infected must agree by typing command","!shuffle");
                CreateTimer( 10.0, Timer_ShuffleTeamsRequest, _, TIMER_FLAG_NO_MAPCHANGE );
            }
        }
    }
    else
    {
        if ( g_bSrvVoted )
        {
            // infected respond
            if ( !g_bInfVoted )
            {
                g_bInfVoted = true;
                CPrintToChatAll("[{olive}TS{default}] %t","l4d_teamshuffle6","Team shuffle");
                CreateTimer( 3.0, Timer_ShuffleTeams, _, TIMER_FLAG_NO_MAPCHANGE );
            }
        } else {
            // Infected first
            if ( !g_bInfVoted )
            {
                g_bInfVoted = true;
                CPrintToChatAll("[{olive}TS{default}] %t","l4d_teamshuffle7","Team shuffle");
                CPrintToChatAll("%t","The Survivors must agree by typing command","!shuffle");
                CreateTimer( 10.0, Timer_ShuffleTeamsRequest, _, TIMER_FLAG_NO_MAPCHANGE );
            }
        }
    }
}

public Action: Timer_ShuffleTeams ( Handle:timer )
{
    ShuffleTeams();
}
public Action: Timer_ShuffleTeamsRequest ( Handle:timer )
{
   if( (g_bSrvVoted == false || g_bInfVoted == false) && !g_shuffle)
   {
		CPrintToChatAll("[{olive}TS{default}]%t %t","Team shuffle","request timed out.");
   }
   g_bSrvVoted = false;
   g_bInfVoted = false;
}

ShuffleTeams ( client = -1 , bool: adm = false)
{
    if ( !Is_Ready_Plugin_On() || !IsInReady() )
    {
        if (client == -1) {
            CPrintToChatAll("[{olive}TS{default}] %t","l4d_teamshuffle1","Team shuffle");
        } else {
            CPrintToChat(client, "[{olive}TS{default}] %T","l4d_teamshuffle1",client,"Team shuffle");
        }
        return;
    }
    
    if(adm)
    {
        CPrintToChatAll("[{olive}TS{default}] {lightgreen}%N {default}%t",client,"has forced the team shuffle","Team shuffle");
    }
	
    g_shuffle = true;
	
    int iClientCount, iClients[MAXPLAYERS+1];

    for(int i = 1; i <= MaxClients; i++)
    {
        if(!IsClientInGame(i)) continue;
        if(IsFakeClient(i)) continue;
        if(GetClientTeam(i) <= 1) continue;

        iClients[iClientCount++] = i;
    }

    //打亂陣列
    ShuffleArray(iClients, iClientCount);

    // set all players to spec
    for ( int i = 1; i <= MaxClients; i++ )
    {
        if ( !IS_VALID_INGAME(i) || IsFakeClient(i) ) { continue; }
        ChangeClientTeam( i, TEAM_SPECTATOR );
    }

    int target;
    for ( int i = 0; i < iClientCount; i++ )
    {
        target = iClients[i];
        if(i%2 == 0) CreateTimer(i*0.1, MoveToSurvivor, GetClientUserId(target), TIMER_FLAG_NO_MAPCHANGE);
        else if(i%2 == 1) CreateTimer(i*0.1, MoveToInfected, GetClientUserId(target), TIMER_FLAG_NO_MAPCHANGE);
    }


    CPrintToChatAll("[{olive}TS{default}] %t","Teams were shuffled.");
    g_bSrvVoted = false;
    g_bInfVoted = false;
    g_shuffle = false;
	
    // set timeout
    g_iTimeout = GetTime() + TIMEOUT_TIME;
    
}

GetTeamMaxHumans(team)
{
	if(team == 2)
	{
		return GetConVarInt(FindConVar("survivor_limit"));
	}
	else if(team == 3)
	{
		return GetConVarInt(FindConVar("z_max_player_zombies"));
	}
	
	return -1;
}

GetTeamHumanCount(team)
{
	new humans = 0;
	
	new i;
	for(i = 1; i < (MaxClients + 1); i++)
	{
		if(IsClientInGameHuman(i) && GetClientTeam(i) == team)
		{
			humans++;
		}
	}
	
	return humans;
}

bool:IsClientInGameHuman(client)
{
	return IsClientInGame(client) && !IsFakeClient(client) && ((GetClientTeam(client) == L4D_TEAM_SURVIVORS || GetClientTeam(client) == L4D_TEAM_INFECTED));
}

Action MoveToSurvivor(Handle timer, any targetplayer)
{
    targetplayer = GetClientOfUserId(targetplayer);
    if(!targetplayer || !IsClientInGame(targetplayer)) return Plugin_Continue;

    int bot = FindBotToTakeOver(true);
    if (bot==0)
    {
        bot = FindBotToTakeOver(false);
    }
    if (bot>0)
    {
        L4D_SetHumanSpec(bot, targetplayer);
        L4D_TakeOverBot(targetplayer);
    }

    return Plugin_Continue;
}

Action MoveToInfected(Handle timer, any targetplayer)
{
    targetplayer = GetClientOfUserId(targetplayer);
    if(!targetplayer || !IsClientInGame(targetplayer)) return Plugin_Continue;

    ChangeClientTeam(targetplayer, 3);

    return Plugin_Continue;
}

int FindBotToTakeOver(bool alive)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i)==TEAM_SURVIVOR && !HasIdlePlayer(i) && IsPlayerAlive(i) == alive)
		{
			return i;
		}
	}
	return 0;
}

bool HasIdlePlayer(int bot)
{
	if(HasEntProp(bot, Prop_Send, "m_humanSpectatorUserID"))
	{
		if(GetEntProp(bot, Prop_Send, "m_humanSpectatorUserID") > 0)
		{
			return true;
		}
	}
	
	return false;
}

void ShuffleArray(int[] iClients, int iClientCount)
{
	int temp, random;
	for(int i = 0; i < iClientCount; i++)
	{
		random = GetRandomInt(0, iClientCount-1);
		temp = iClients[i];
		iClients[i] = iClients[random];
		iClients[random] = temp;
	}
}