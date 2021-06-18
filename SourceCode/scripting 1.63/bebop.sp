/**********************************************************
 * 
 * 	+-----------------------+
 * 	|						|
 * 	|     bebop 0.2 beta    |
 * 	|       by frool		|
 * 	|						|
 *  +-----------------------+
 * 	|    VERSION HISTORY    |
 * 	+-----------------------+
 * 
 * 	-> 0.1 beta
 * 	-----------
 * 		- initial release
 * 
 * 	-> 0.2 beta
 * 	-----------
 * 		- FIXED BUG: where bebop unnhooks events twice when changing
 * 					 from non coop gamemode to another non coop gamemode
 * 		- FIXED BUG: in l4d1 mp_gamemode cvar flag got set to protected
 * 					 because it is not protected by default like in l4d1
 * 
 * *******************************************************/

#pragma semicolon 1

#define LOG_ENABLED true // enable logging?

#include <sourcemod>
#include <sdktools>


#define BEBOP_VERSION						"0.2 beta"
#define BEBOP_LOG_PATH						"logs\\bebop.log"
#define DELAY_KICK_BEBOP_FAKE_CLIENT		1.0
#define DELAY_KICK_NO_MORE_NEEDED_BOTS		0.125
#define DELAY_AFK_PUT_CLIENT_SURVIVOR_TEAM	1.0
#define DELAY_NEW_PUT_CLIENT_SURVIVOR_TEAM	10.0
#define DELAY_KILL_MORE_SURVIVOR 1.25
#define ID_TEAM_SURVIVOR					2

static Handle:	gamemode;

#if LOG_ENABLED
static String:	logfilepath[256];
#endif
static String:	clientname[256];
static			newMapActivatedPlayers;
static bool:	coopEnabled;
static bool: round_begin;


public Plugin:MyInfo = 
{
	name = "bebop",
	author = "frool",
	description = "allows \"unlimited\" additional players playing in coop mode",
	version = BEBOP_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=110210"
}
public OnPluginStart()
{
	CreateConVar("bebop_version", BEBOP_VERSION, "tells the running version number of bebop", FCVAR_PLUGIN|FCVAR_REPLICATED|FCVAR_NOTIFY);
	
	// enable log
	#if LOG_ENABLED
	BuildPath(Path_SM, logfilepath, sizeof(logfilepath), BEBOP_LOG_PATH);
	LogToFile(logfilepath, "+-------------------------------------------+");
	LogToFile(logfilepath, "|               PLUGIN START                |");
	LogToFile(logfilepath, "+-------------------------------------------+");
	LogToFile(logfilepath, "|               Version: %s           |", BEBOP_VERSION);
	LogToFile(logfilepath, "+-------------------------------------------+");
	#endif
	
	// hook stuff
	
	// set gamemode flags to non protected to gain access
	gamemode = FindConVar("mp_gamemode");
	
	
	//detect if l4d1 or l4d2 is running
	new String:gameDir[64];
	new bool:isL4D2 = false;
	new flags;
	
	GetGameFolderName(gameDir, sizeof(gameDir));
	
	if (StrEqual(gameDir, "left4dead2"))
	{
		#if LOG_ENABLED
		LogToFile(logfilepath, "PLUGIN_LOAD -> NOTICE: gamedir is \\left4dead2. setting mp_gamemode convar flags to unprotected");
		#endif
		isL4D2 = true;
		flags = GetConVarFlags(gamemode);
		SetConVarFlags(gamemode, flags & ~FCVAR_PROTECTED);
	}
	
	new String:currentGameMode[64];
	GetConVarString(gamemode, currentGameMode, sizeof(currentGameMode));
	
	if (StrEqual(currentGameMode, "coop") == true)
	{
		#if LOG_ENABLED
		LogToFile(logfilepath, "PLUGIN_LOAD -> NOTICE: gamemode is COOP. hooking events...");
		#endif
		coopEnabled = true;
		HookUnhookEvents(true);
	}

	HookConVarChange(gamemode, Event_GameModeChanges);
	
	
	if (isL4D2 == true)
	{
		LogToFile(logfilepath, "PLUGIN_LOAD -> NOTICE: gamedir is \\left4dead2. restoring original mp_gamemode convar flags");
		SetConVarFlags(gamemode, flags);	
	}
	
	HookEvent("round_start", Event_RoundStart);
}

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{	
	round_begin = true;
	CreateTimer(30.0, Timer_round_begin_false, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Timer_round_begin_false(Handle:timer)
{
	round_begin = false;
}

public Event_GameModeChanges(Handle:convar, const String:oldGameMode[], const String:newGameMode[])
{
	if (StrEqual(newGameMode, "coop") == true)
	{
		coopEnabled = true;

		#if LOG_ENABLED
		LogToFile(logfilepath, "GAMEMODE_CHANGE -> NOTICE: gamemode changed to COOP NOW");
		#endif
		HookUnhookEvents(true);
		
	}
	else if (StrEqual(oldGameMode, "coop") == true || StrEqual(newGameMode, "coop") == false)
	{
		coopEnabled = false;
	
		#if LOG_ENABLED
		LogToFile(logfilepath, "GAMEMODE_CHANGE -> NOTICE: gamemode changed to NON COOP");
		#endif
		HookUnhookEvents(false);
	}
}

HookUnhookEvents(bool:HookUnhook)
{
	if (HookUnhook == true)
	{
		HookEvent("player_activate", Event_PlayerActivate, EventHookMode_Post);
		HookEvent("player_team", Event_PlayerChangeTeam, EventHookMode_Post);
		
		#if LOG_ENABLED
		LogToFile(logfilepath, "HOOKED_EVENTS -> NOTICE: hooked events");
		#endif	
	}
	else
	{
		UnhookEvent("player_activate", Event_PlayerActivate, EventHookMode_Post);
		UnhookEvent("player_team", Event_PlayerChangeTeam, EventHookMode_Post);
		#if LOG_ENABLED
		LogToFile(logfilepath, "UNHOOKED_EVENTS -> NOTICE: unhooked events");
		#endif	
	}
}

public OnMapStart()
{
	round_begin = true;
}

public OnMapEnd()
{
	#if LOG_ENABLED
	LogToFile(logfilepath, "+-------------------------------------------+");
	LogToFile(logfilepath, "|                  MAP END                  |");
	LogToFile(logfilepath, "+-------------------------------------------+");
	#endif
	
	newMapActivatedPlayers = 0;
}

public OnClientDisconnect(client)
{
	if(coopEnabled == false){return;}
	
	if(newMapActivatedPlayers <= 4){return;}
	
	if (!IsFakeClient(client))
	{
		#if LOG_ENABLED
		clientname = "GetClientName() Failed";
		GetClientName(client, clientname, sizeof(clientname));
		LogToFile(logfilepath, "DISCONNECT:	--> %s <-- just disconnected from the server", clientname);
		#endif
		
		new count = GetHumanInGamePlayerCount() - 1; // -1 cuz the disconnected player does not count
		if ( count >= 4)
		{
			#if LOG_ENABLED
			LogToFile(logfilepath, "DISCONNECT -> KICK_BOT: HumamInGamePlayerCount is bigger or equals 4 --> Reported: %i <-- ", count);
			#endif
			
			//Generate Timer to Kick the Bot that takes over the disconnected client
			CreateTimer(DELAY_KICK_NO_MORE_NEEDED_BOTS, Timer_KickNoMoreNeededBot, 0, TIMER_REPEAT);
		}
	}
}

public Event_PlayerChangeTeam(Handle: event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (client != 0)
	{
		if (!IsFakeClient(client))
		{
			if(GetClientTeam(client) == ID_TEAM_SURVIVOR)
			{
				#if LOG_ENABLED
				clientname = "GetClientName() Failed";
				GetClientName(client, clientname, sizeof(clientname));
				LogToFile(logfilepath, "PLAYER_CHANGE_TEAM:	--> %s <-- may pressed the afk button", clientname);
				#endif
				
				CreateTimer(DELAY_AFK_PUT_CLIENT_SURVIVOR_TEAM, Timer_PutClientToSurvivorTeam2, client, TIMER_REPEAT);
			}
		}
	}
}

public Action:Timer_PutClientToSurvivorTeam2(Handle:timer, any:client)
{
	if (IsClientConnected(client))
	{
		if (IsClientInGame(client) && !IsFakeClient(client))
		{
			#if LOG_ENABLED
			LogToFile(logfilepath, "PLAYER_ACTIVATE -> PUT_CLIENT_SURVIVORTEAM: --> %s <-- has been put into the survivor team", clientname);
			#endif
			
			FakeClientCommand(client, "jointeam %i", ID_TEAM_SURVIVOR);
		}
	}	
	
	return Plugin_Stop;
}

public Event_PlayerActivate(Handle: event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (!IsFakeClient(client))
	{	
		#if LOG_ENABLED
		clientname = "GetClientName() Failed";
		GetClientName(client, clientname, sizeof(clientname));
		LogToFile(logfilepath, "PLAYER_ACTIVATE: --> %s <-- just activated in the game", clientname);
		#endif
		
		newMapActivatedPlayers++;
		
		new count;
		count = GetHumanInGamePlayerCount();
		
		if (count > 4 && newMapActivatedPlayers > 4 && (GetClientTeam(client) != 2 || GetClientTeam(client) == 1)) // clientteam is fix for spawning too many bouts after map_transition
		{
			#if LOG_ENABLED
			LogToFile(logfilepath, "PLAYER_ACTIVATE: HumamInGamePlayerCount is bigger than 4 --> Reported: %i <--  TEAMID: %i", count, GetClientTeam(client));
			#endif
			
			SpawnBebopFakeClient();
			CreateTimer(DELAY_NEW_PUT_CLIENT_SURVIVOR_TEAM, Timer_PutClientToSurvivorTeam, client, TIMER_REPEAT);	
		}
	}
}

public Action:Timer_PutClientToSurvivorTeam(Handle:timer, any:client)
{
	if (IsClientConnected(client))
	{
		if (IsClientInGame(client) && !IsFakeClient(client))
		{
			#if LOG_ENABLED
			LogToFile(logfilepath, "PLAYER_ACTIVATE -> PUT_CLIENT_SURVIVORTEAM: --> %s <-- has been put into the survivor team", clientname);
			#endif
			
			FakeClientCommand(client, "jointeam %i", ID_TEAM_SURVIVOR);
			
			CreateTimer(DELAY_KILL_MORE_SURVIVOR, Timer_KillMoreSurvivor, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);	
		}
	}	
	
	return Plugin_Stop;
}

public Action:Timer_KillMoreSurvivor(Handle:timer, any:client)
{
	if(round_begin) return Plugin_Stop;
	
	if (IsClientConnected(client)&&IsClientInGame(client)&&!IsFakeClient(client))
	{
		new team = GetClientTeam(client);
		if(team == 1)
		{
			new BotClient = BotClientIdle(client);
			if(BotClient >= 1)
				ForcePlayerSuicide(BotClient);
			else
				return Plugin_Continue;
		}
		else if (team == ID_TEAM_SURVIVOR && IsPlayerAlive(client))
			ForcePlayerSuicide(client);
	}	
	return Plugin_Stop;
}

public Action:Timer_KickNoMoreNeededBot(Handle:timer, any:data)
{
	#if LOG_ENABLED
	LogToFile(logfilepath, "DISCONNECT -> KICK_BOT -> TIMER: searching for a bot to kick now");
	#endif
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i))
		{
			if (IsFakeClient(i) && (GetClientTeam(i) == ID_TEAM_SURVIVOR))
			{
				#if LOG_ENABLED
				clientname = "GetClientName() failed";
				#endif
				
				GetClientName(i, clientname, sizeof(clientname));
				
				if (StrEqual(clientname, "bebop_bot_fakeclient", true))
				{
					continue;
				}

				KickClient(i, "client_is_bebop_fakeclient");
				
				#if LOG_ENABLED
				LogToFile(logfilepath, "DISCONNECT -> KICK_BOT -> TIMER: --> %s <-- has been kicked ", clientname);
				#endif
				
				break;		
			}
		}
	}
	
	return Plugin_Stop;
}

public Action:Timer_KickBebopFakeClient(Handle:timer, any:client)
{
	if (IsClientConnected(client))
	{
		KickClient(client, "client_is_bebop_fakeclient");
		
		#if LOG_ENABLED
		LogToFile(logfilepath, "PLAYER_ACTIVATE -> ADD_BOT -> KICK_BEBOP_FAKE_CLIENT_TIMER: kicked the bebop_fake_client from the server. bot should take over now");
		#endif
	}
	
	return Plugin_Stop;
}

GetHumanInGamePlayerCount()
{
	new count = 0;
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i))
		{
			if (!IsFakeClient(i))
			{
				if (IsClientInGame(i))
				{
					count++;
				}
			}
		}
	}
	
	return count;
}

bool:SpawnBebopFakeClient()
{
	// init ret value
	new bool:ret = false;
	
	// create fake client
	new client = 0;
	client = CreateFakeClient("bebop_bot_fakeclient");
	
	// if entity is valid
	if (client != 0)
	{
		// move into survivor team
		ChangeClientTeam(client, ID_TEAM_SURVIVOR);
		//FakeClientCommand(client, "jointeam %i", ID_TEAM_SURVIVOR);
		
		// set entity classname to survivorbot
		if (DispatchKeyValue(client, "classname", "survivorbot") == true)
		{
			// spawn the client
			if (DispatchSpawn(client) == true)
			{
				// kick the fake client to make the bot take over
				#if LOG_ENABLED
				LogToFile(logfilepath, "PLAYER_ACTIVATE -> ADD_BOT: bebop_fake_client created. kicking bebop_fake client now to make bot take over");
				#endif
				
				CreateTimer(DELAY_KICK_BEBOP_FAKE_CLIENT, Timer_KickBebopFakeClient, client, TIMER_REPEAT);
				ret = true;
			}
			else
			{
				#if LOG_ENABLED
				LogToFile(logfilepath, "ERROR: DispatchSpawn() in SpawnBebopFakeClient() failed");
				#endif
			}
		}
		else
		{
			#if LOG_ENABLED
			LogToFile(logfilepath, "ERROR: DispatchKeyValue() in SpawnBebopFakeClient() failed");
			#endif
		}
		
		// if something went wrong kick the created fake client
		if (ret == false)
		{
			KickClient(client, "");
		}
	}
	else
	{
		#if LOG_ENABLED
		LogToFile(logfilepath, "ERROR: CreateFakeClient() in SpawnBebopFakeClient() failed");
		#endif
	}
	
	return ret;
}

BotClientIdle(client)
{
	if(GetClientTeam(client) != 1)
		return false;
	
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i) && IsClientInGame(i))
		{
			if((GetClientTeam(i) == 2) && IsPlayerAlive(i))
			{
				if(IsFakeClient(i))
				{
					if(GetClientOfUserId(GetEntProp(i, Prop_Send, "m_humanSpectatorUserID")) == client)
						return i;
				}
			}
		}
	}
	return -1;
}