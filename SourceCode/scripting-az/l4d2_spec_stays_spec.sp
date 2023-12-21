#include <sourcemod>

#pragma semicolon 1
#pragma newdecls required

#define ACTIVE_SECONDS 	120
/*
* Debug modes:
* 0 = disabled
* 1 = server console
* 2 = fileoutput "l4d2_spec_stays_spec.txt"
*/
#define DEBUG_MODE 0
#define MAX_SPECTATORS 	24
#define PLUGIN_VERSION 	"1.2"
#define STEAMID_LENGTH 	32

ConVar g_hMaxSurvivors;
ConVar g_hMaxInfected;

/*
* plugin info
* #######################
*/
public Plugin myinfo =
{
    name = "Spectator stays spectator",
    author = "Die Teetasse",
    description = "Spectator will stay as spectators on mapchange.",
    version = PLUGIN_VERSION,
    url = ""
};

/*
* global variables
* #######################
*/
int lastTimestamp = 0;
int spectatorCount = 0;
Handle spectatorTimer[MAXPLAYERS+1],
    Check4SpecTimer;

/*
* ask plugin load - check game
* #######################
*/
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if (test != Engine_Left4Dead && test != Engine_Left4Dead2 )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}
	
	return APLRes_Success;
}

/*
* plugin start - check game
* #######################
*/
public void OnPluginStart() {
    HookEvent("round_start", Event_Round_Start);
    HookEvent("round_end", Event_Round_End);
    
    g_hMaxSurvivors = FindConVar("survivor_limit");
    g_hMaxInfected = FindConVar("z_max_player_zombies");
}

/*
* map start - hook event
* #######################
*/

public void OnMapEnd()
{
    spectatorCount = 0;
    
    delete Check4SpecTimer;
    // clear arrays and kill timers
    for (int i = 0; i <= MaxClients; i++) {
        delete spectatorTimer[i];
    }
    
    // get steamids
    for (int i = 1; i <= MaxClients; i++) 
    {
        if (!IsClientInGame(i)) continue;
        if (IsFakeClient(i)) continue;
        if (GetClientTeam(i) != 1) continue;
        if (IsClientSourceTV(i)) continue;
        
        spectatorCount++;
    }	
    
    // set timestamp
    lastTimestamp = GetTime();
}

void Event_Round_Start(Event event, const char[] name, bool dontBroadcast)
{
    delete Check4SpecTimer;
    Check4SpecTimer = CreateTimer(15.0, Check4Spec, _, TIMER_REPEAT);
}

Action Check4Spec(Handle timer)
{
    if (GetRealClientCount() != (GetConVarInt(g_hMaxSurvivors) + GetConVarInt(g_hMaxInfected))) return Plugin_Continue;
    
    for (int i = 1; i <= MaxClients; i++) 
    {
        if(IsClientInGame(i) && IsClientConnected(i) && GetClientTeam(i) == 1 && !IsClientSourceTV(i)) FakeClientCommand(i, "say /spectate");   
    }

    Check4SpecTimer = null;
    return Plugin_Stop;
}


/*
* round end event - save spec steamids
* #######################
*/
public void Event_Round_End(Event event, const char[] name, bool dontBroadcast) {
    spectatorCount = 0;
    
    delete Check4SpecTimer;
    // clear arrays and kill timers
    for (int i = 0; i <= MaxClients; i++) {
        delete spectatorTimer[i];
    }
    
    // get steamids
    for (int i = 1; i <= MaxClients; i++) 
    {
        if (!IsClientInGame(i)) continue;
        if (IsFakeClient(i)) continue;
        if (GetClientTeam(i) != 1) continue;
        if (IsClientSourceTV(i)) continue;
        
        spectatorCount++;
    }	
    
    // set timestamp
    lastTimestamp = GetTime();
}

/*
* client authorisation - check and create timer if neccessary
* #######################
*/
public void OnClientAuthorized(int client, const char[] auth) 
{
    if ((GetTime() - lastTimestamp) > ACTIVE_SECONDS) return;
    
    // check fake client
    if (strcmp(auth, "BOT") == 0) return;
    
    // create move timer
    delete spectatorTimer[client];
    spectatorTimer[client] = CreateTimer(1.0, Timer_MoveToSpec, client, TIMER_REPEAT);
}

/*
* move to spec timer - checks for ingame and move the client
* #######################
*/
Action Timer_MoveToSpec(Handle timer, int client) {
    // check ingame - if not => repeat
    if (!IsClientInGame(client))
    {
        spectatorTimer[client] = null;
        return Plugin_Stop;
    }
    
    // get steamid
    char auth[STEAMID_LENGTH];
    GetClientAuthId(client, AuthId_Steam2, auth, STEAMID_LENGTH);
    
    spectatorTimer[client] = null;
    
    // check team - if already spec => stop
    int team = GetClientTeam(client);
    if (team == 1)
    {
        CreateTimer(2.0, ReSpec, GetClientUserId(client));
        return Plugin_Stop;
    }
    
    // get client name
    char name[MAX_NAME_LENGTH];
    GetClientName(client, name, sizeof(name));
    
    // change team and stop
    ChangeClientTeam(client, 1);
    CreateTimer(2.0, ReSpec, GetClientUserId(client));
    //PrintToChatAll("[SM] Found %s in %s team. Moved him back to spec team.", name, (team == 2) ? "survivor" : "infected");
    
    return Plugin_Stop;
}

Action ReSpec(Handle timer, int client)
{   
    client = GetClientOfUserId(client);
    if (IsClientInGame(client) && GetClientTeam(client) == 1) {
        FakeClientCommand(client, "say /spectate");
    }

    return Plugin_Stop;
}

/*
* client disconnect - stop timer
* #######################
*/
public void OnClientDisconnect(int client) 
{
    delete spectatorTimer[client];
}

int GetRealClientCount() 
{
    int clients = 0;
    for (int i = 1; i <= MaxClients; i++) 
    {
        if(IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i) && GetClientTeam(i) != 1) clients++;
    }
    return clients;
}