/********************************************************************************************
* Plugin	: L4D/L4D2 InfectedBots (Versus Coop/Coop Versus)
* Game		: Left 4 Dead 1
* Author	: djromero (SkyDavid, David) and MI 5 & l4d1 port by Harry
*********************************************************************************************/

#include <sourcemod>
#include <sdktools>
#include <multicolors>

#pragma semicolon 1

#define PLUGIN_VERSION "1.0h-2026/1/17"

native bool IsClientTankHud(int client);
native bool IsClientSpecHud(int client);

#define DEBUGSERVER 0
#define DEBUGCLIENTS 0
#define DEBUGTANK 0
#define DEBUGHUD 0
#define DEVELOPER 0

#define TEAM_SPECTATOR		1
#define TEAM_SURVIVORS 		2
#define TEAM_INFECTED 		3

#define ZOMBIECLASS_SMOKER	1
#define ZOMBIECLASS_BOOMER	2
#define ZOMBIECLASS_HUNTER	3

// Variables
static InfectedRealCount; // Holds the amount of real infected players
static InfectedBotCount; // Holds the amount of infected bots in any gamemode
static InfectedBotQueue; // Holds the amount of bots that are going to spawn

static GameMode; // Holds the GameMode, 1 for coop and realism, 2 for versus, teamversus, scavenge and teamscavenge, 3 for survival

static TanksPlaying; // Holds the amount of tanks on the playing field
static BoomerLimit; // Sets the Boomer Limit, related to the boomer limit cvar
static SmokerLimit; // Sets the Smoker Limit, related to the smoker limit cvar
static HunterLimit; // Sets the Hunter Limit, related to the hunter limit cvar

static MaxPlayerZombies; // Holds the amount of the maximum amount of special zombies on the field
static MaxPlayerTank; // Used for setting an additional slot for each tank that spawns
static BotReady; // Used to determine how many bots are ready, used only for the coordination feature
static ZOMBIECLASS_TANK; // This value varies depending on which L4D game it is, holds the the tank class value
static GetSpawnTime[MAXPLAYERS+1]; // Used for the HUD on getting spawn times of players
static PlayersInServer;

#define NUM_TYPES_INFECTED_MAX 3 // for spawning
int SI_SMOKER = 0;
int SI_BOOMER = 1;
int SI_HUNTER = 2;
Handle g_hSpawnColdDownTimer[NUM_TYPES_INFECTED_MAX];


// Booleans
static bool:b_HasRoundStarted; // Used to state if the round started or not
static bool:b_HasRoundEnded; // States if the round has ended or not
static bool:b_LeftSaveRoom; // States if the survivors have left the safe room
static bool:DirectorSpawn; // Can allow either the director to spawn the infected (normal l4d behavior), or allow the plugin to spawn them
static bool:SpecialHalt; // Loop Breaker, prevents specials spawning, while Director is spawning, from spawning again
static bool:TankFrustStop; // Prevents the tank frustration event from firing as it counts as a tank spawn
static bool:FinaleStarted; // States whether the finale has started or not
static bool:WillBeTank[MAXPLAYERS+1]; // States whether that player will be the tank
//new bool:TankHalt; // Loop Breaker, prevents player tanks from spawning over and over
static bool:TankWasSeen[MAXPLAYERS+1]; // Used only in coop, prevents the Sound hook event from triggering over and over again
static bool:PlayerLifeState[MAXPLAYERS+1]; // States whether that player has the lifestate changed from switching the gamemode
static bool:InitialSpawn; // Related to the coordination feature, tells the plugin to let the infected spawn when the survivors leave the safe room
static bool:TempBotSpawned; // Tells the plugin that the tempbot has spawned
static bool:AlreadyGhosted[MAXPLAYERS+1]; // Loop Breaker, prevents a player from spawning into a ghost over and over again
static bool:AlreadyGhostedBot[MAXPLAYERS+1]; // Prevents bots taking over a player from ghosting
static bool:SurvivalVersus;
static bool:DirectorCvarsModified; // Prevents reseting the director class limit cvars if the server or admin modifed them
static bool:PlayerHasEnteredStart[MAXPLAYERS+1];
static bool:AfterInitialRound;


// Handles
static Handle:h_BoomerLimit; // Related to the Boomer limit cvar
static Handle:h_SmokerLimit; // Related to the Smoker limit cvar
static Handle:h_HunterLimit; // Related to the Hunter limit cvar
static Handle:h_MaxPlayerZombies; // Related to the max specials cvar
static Handle:h_InfectedSpawnTimeMax; // Related to the spawn time cvar
static Handle:h_InfectedSpawnTimeMin; // Related to the spawn time cvar
static Handle:h_DirectorSpawn; // yeah you're getting the idea
static Handle:h_CoopPlayableTank; // yup, same thing again
static Handle:h_GameMode; // uh huh
static Handle:h_JoinableTeams; // Can you guess this one?
static Handle:h_StatsBoard; // Oops, now we are
static Handle:h_Difficulty; // Ok, maybe not
static Handle:h_JoinableTeamsAnnounce;
static Handle:h_Coordination;
static Handle:h_idletime_b4slay;
static Handle:h_InitialSpawn;
static Handle:h_HumanCoopLimit;
static Handle:h_AdminJoinInfected;
static Handle:FightOrDieTimer[MAXPLAYERS+1]; // kill idle bots
static Handle:h_DisableSpawnsTank;
static Handle:h_TankLimit;
static Handle:h_WitchLimit;
static Handle:h_VersusCoop;
static Handle:h_AdjustSpawnTimes;

// Stuff related to Durzel's HUD (Panel was redone)
static respawnDelay[MAXPLAYERS+1]; 			// Used to store individual player respawn delays after death
bool hudDisabled[MAXPLAYERS+1];				// Stores the client preference for whether HUD is shown
static clientGreeted[MAXPLAYERS+1]; 			// Stores whether or not client has been shown the mod commands/announce
static zombieHP[7];					// Stores special infected max HP
static Handle:cvarZombieHP[7];				// Array of handles to the 4 cvars we have to hook to monitor HP changes
static bool:isTankOnFire[MAXPLAYERS+1]		= {false}; 		// Used to store whether tank is on fire
static burningTankTimeLeft[MAXPLAYERS+1]		= {0}; 			// Stores number of seconds Tank has left before he dies
static bool:roundInProgress 		= false;		// Flag that marks whether or not a round is currently in progress
static Handle:infHUDTimer 		= INVALID_HANDLE;	// The main HUD refresh timer
static Handle:respawnTimer 	= INVALID_HANDLE;	// Respawn countdown timer
static Handle:doomedTankTimer 	= INVALID_HANDLE;	// "Tank on Fire" countdown timer
static Handle:delayedDmgTimer 	= INVALID_HANDLE;	// Delayed damage update timer
static Handle:pInfHUD 		= INVALID_HANDLE;	// The panel shown to all infected users
static Handle:usrHUDPref 		= INVALID_HANDLE;	// Stores the client HUD preferences persistently

static Handle:h_InfHUD		= INVALID_HANDLE;
static Handle:h_Announce 	= INVALID_HANDLE;

public Plugin:myinfo = 
{
	name = "[L4D] Infected Bots (Versus Coop/Coop Versus)",
	author = "djromero (SkyDavid), MI 5, HarryPotter",
	description = "Spawns infected bots in versus, allows playable special infected in coop/survival, and changable z_max_player_zombies limit",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?p=893938#post893938"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();

	if( test != Engine_Left4Dead )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1.");
		return APLRes_SilentFailure;
	}

	MarkNativeAsOptional("IsClientTankHud");
	return APLRes_Success;
}

public OnPluginStart()
{
	// Tank Class value is different in L4D2
	ZOMBIECLASS_TANK = 5;
	
	// Notes on the offsets: altough m_isGhost is used to check or set a player's ghost status, for some weird reason this disallowed the player from spawning.
	// So I found and used m_isCulling to allow the player to press use and spawn as a ghost (which in this case, I forced the client to press use)
	
	// m_lifeState is an alternative to the "switching to spectator and back" method when a bot spawns. This was used to prevent players from taking over those bots, but
	// this provided weird movements when a player was spectating on the infected team.
	
	// ScrimmageType is interesting as it was used in the beta. The scrimmage code was abanonded and replaced with versus, but some of it is still left over in the final.
	// In the previous versions of this plugin (or not using this plugin at all), you might have seen giant bubbles or spheres around the map. Those are scrimmage spawn
	// spheres that were used to prevent infected from spawning within there. It was bothering me, and a whole lot of people who saw them. Thanks to AtomicStryker who
	// URGED me to remove the spheres, I began looking for a solution. He told me to use various source handles like m_scrimmageType and others. I experimented with it,
	// and found out that it removed the spheres, and implemented it into the plugin. The spheres are no longer shown, and they were useless anyway as infected still spawn 
	// within it.
	
	
	// Notes on the sourcemod commands:
	// JoinSpectator is actually a developer command I used to see if the bots spawn correctly with and without a player. It was incredibly useful for this purpose, but it
	// will not be in the final versions.
	
	// Add a sourcemod command so players can easily join infected in coop/survival
	RegConsoleCmd("sm_ji", JoinInfected);
	RegConsoleCmd("sm_js", JoinSurvivors);
	RegConsoleCmd("sm_zs", ForceInfectedSuicide);
	#if DEVELOPER
	RegConsoleCmd("sm_sp", JoinSpectator);
	RegConsoleCmd("sm_gamemode", CheckGameMode);
	RegConsoleCmd("sm_count", CheckQueue);
	#endif
	
	// Hook "say" so clients can toggle HUD on/off for themselves
	RegConsoleCmd("sm_infhud", Command_Say);
	
	// We register the version cvar
	CreateConVar("l4d_infectedbots_version", PLUGIN_VERSION, "Version of L4D Infected Bots", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	h_GameMode = FindConVar("mp_gamemode");
	h_Difficulty = FindConVar("z_difficulty");
	
	// console variables
	h_BoomerLimit = CreateConVar("l4d_infectedbots_boomer_limit", "1", "Sets the limit for boomers spawned by the plugin", FCVAR_SPONLY);
	h_SmokerLimit = CreateConVar("l4d_infectedbots_smoker_limit", "1", "Sets the limit for smokers spawned by the plugin", FCVAR_SPONLY);
	h_TankLimit = CreateConVar("l4d_infectedbots_tank_limit", "0", "Sets the limit for tanks spawned by the plugin (does not affect director tanks)", FCVAR_SPONLY);
	h_WitchLimit = CreateConVar("l4d_infectedbots_witch_limit", "0", "Sets the limit for witches spawned by the plugin (does not affect director witches)", FCVAR_SPONLY);
	h_HunterLimit = CreateConVar("l4d_infectedbots_hunter_limit", "2", "Sets the limit for hunters spawned by the plugin", FCVAR_SPONLY);
	h_MaxPlayerZombies = CreateConVar("l4d_infectedbots_max_specials", "4", "Defines how many special infected can be on the map on all gamemodes", FCVAR_SPONLY); 
	h_InfectedSpawnTimeMax = CreateConVar("l4d_infectedbots_spawn_time_max", "22", "Sets the max spawn time for special infected spawned by the plugin in seconds", FCVAR_SPONLY);
	h_InfectedSpawnTimeMin = CreateConVar("l4d_infectedbots_spawn_time_min", "22", "Sets the minimum spawn time for special infected spawned by the plugin in seconds", FCVAR_SPONLY);
	h_DirectorSpawn = CreateConVar("l4d_infectedbots_director_spawn", "0", "If 1, the plugin will use the director's timing of the spawns, if the game is L4D2 and versus, it will activate Valve's bots", FCVAR_SPONLY, true, 0.0, true, 1.0);
	h_CoopPlayableTank = CreateConVar("l4d_infectedbots_coop_versus_tank_playable", "0", "If 1, tank will be playable in coop/survival", FCVAR_NOTIFY|FCVAR_SPONLY, true, 0.0, true, 1.0);
	h_JoinableTeams = CreateConVar("l4d_infectedbots_coop_versus", "0", "If 1, players can join the infected team in coop/survival (!ji in chat to join infected, !js to join survivors)", FCVAR_SPONLY, true, 0.0, true, 1.0);
	h_StatsBoard = CreateConVar("l4d_infectedbots_stats_board", "0", "If 1, the stats board will show up after an infected player dies (L4D1 ONLY)", FCVAR_SPONLY, true, 0.0, true, 1.0);
	h_JoinableTeamsAnnounce = CreateConVar("l4d_infectedbots_coop_versus_announce", "0", "If 1, clients will be announced to on how to join the infected team", FCVAR_SPONLY, true, 0.0, true, 1.0);
	h_Coordination = CreateConVar("l4d_infectedbots_coordination", "0", "If 1, bots will only spawn when all other bot spawn timers are at zero", FCVAR_SPONLY, true, 0.0, true, 1.0);
	h_InfHUD = CreateConVar("l4d_infectedbots_infhud_enable", "1", "Toggle whether Infected HUD is active or not.", FCVAR_SPONLY, true, 0.0, true, 1.0);
	h_Announce = CreateConVar("l4d_infectedbots_infhud_announce", "1", "Toggle whether Infected HUD announces itself to clients.", FCVAR_SPONLY, true, 0.0, true, 1.0);
	h_idletime_b4slay = CreateConVar("l4d_infectedbots_lifespan", "30", "Amount of seconds before a special infected bot is kicked", FCVAR_SPONLY);
	h_InitialSpawn = CreateConVar("l4d_infectedbots_initial_spawn_timer", "10", "The spawn timer in seconds used when infected bots are spawned for the first time in a map", FCVAR_SPONLY);
	h_HumanCoopLimit = CreateConVar("l4d_infectedbots_coop_versus_human_limit", "2", "Sets the limit for the amount of humans that can join the infected team in coop/survival", FCVAR_SPONLY);
	h_AdminJoinInfected = CreateConVar("l4d_infectedbots_admin_coop_versus", "0", "If 1, only admins can join the infected team in coop/survival", FCVAR_SPONLY, true, 0.0, true, 1.0);
	h_DisableSpawnsTank = CreateConVar("l4d_infectedbots_spawns_disabled_tank", "0", "If 1, Plugin will disable spawning when a tank is on the field", FCVAR_SPONLY, true, 0.0, true, 1.0);
	h_VersusCoop = CreateConVar("l4d_infectedbots_versus_coop", "0", "If 1, The plugin will force all players to the infected side against the survivor AI for every round and map in versus/scavenge", FCVAR_SPONLY, true, 0.0, true, 1.0);
	h_AdjustSpawnTimes = CreateConVar("l4d_infectedbots_adjust_spawn_times", "0", "If 1, The plugin will adjust spawn timers depending on the gamemode, adjusts spawn timers based on number of survivor players in coop and based on amount of infected players in versus/scavenge", FCVAR_SPONLY, true, 0.0, true, 1.0);
	
	HookConVarChange(h_BoomerLimit, ConVarBoomerLimit);
	BoomerLimit = GetConVarInt(h_BoomerLimit);
	HookConVarChange(h_SmokerLimit, ConVarSmokerLimit);
	SmokerLimit = GetConVarInt(h_SmokerLimit);
	HookConVarChange(h_HunterLimit, ConVarHunterLimit);
	HunterLimit = GetConVarInt(h_HunterLimit);
	HookConVarChange(h_MaxPlayerZombies, ConVarMaxPlayerZombies);
	MaxPlayerZombies = GetConVarInt(h_MaxPlayerZombies);
	HookConVarChange(h_DirectorSpawn, ConVarDirectorSpawn);
	DirectorSpawn = GetConVarBool(h_DirectorSpawn);
	HookConVarChange(h_GameMode, ConVarGameMode);
	HookConVarChange(h_Difficulty, ConVarDifficulty);
	HookConVarChange(h_VersusCoop, ConVarVersusCoop);
	HookConVarChange(h_JoinableTeams, ConVarCoopVersus);
	
	// If the admin wanted to change the director class limits with director spawning on, the plugin will not reset those cvars to their defaults upon startup.
	
	HookConVarChange(FindConVar("z_hunter_limit"), ConVarDirectorCvarChanged);
	HookConVarChange(FindConVar("z_gas_limit"), ConVarDirectorCvarChanged);
	HookConVarChange(FindConVar("z_exploding_limit"), ConVarDirectorCvarChanged);
	HookConVarChange(FindConVar("holdout_max_boomers"), ConVarDirectorCvarChanged);
	HookConVarChange(FindConVar("holdout_max_smokers"), ConVarDirectorCvarChanged);
	HookConVarChange(FindConVar("holdout_max_hunters"), ConVarDirectorCvarChanged);
	HookConVarChange(FindConVar("holdout_max_specials"), ConVarDirectorCvarChanged);
	
	// Some of these events are being used multiple times. Although I copied Durzel's code, I felt this would make it more organized as there is a ton of code in events 
	// Such as PlayerDeath, PlayerSpawn and others.
	
	HookEvent("round_start", evtRoundStart);
	HookEvent("round_end",				evtRoundEnd,		EventHookMode_PostNoCopy); //trigger twice in versus mode, one when all survivors wipe out or make it to saferom, one when first round ends (second round_start begins).
	HookEvent("map_transition", 		evtRoundEnd,		EventHookMode_PostNoCopy); //all survivors make it to saferoom, and server is about to change next level in coop mode (does not trigger round_end) 
	HookEvent("mission_lost", 			evtRoundEnd,		EventHookMode_PostNoCopy); //all survivors wipe out in coop mode (also triggers round_end)
	HookEvent("finale_vehicle_leaving", evtRoundEnd,		EventHookMode_PostNoCopy); //final map final rescue vehicle leaving  (does not trigger round_end)
	
	// We hook some events ...
	HookEvent("player_death", evtPlayerDeath);
	HookEvent("player_team", evtPlayerTeam);
	HookEvent("player_spawn", evtPlayerSpawn);
	HookEvent("create_panic_event", evtSurvivalStart);
	HookEvent("tank_frustrated", evtTankFrustrated);
	HookEvent("finale_start", evtFinaleStart);
	HookEvent("finale_radio_start", evtFinaleStart);
	HookEvent("mission_lost", evtMissionLost);
	HookEvent("player_death", evtInfectedDeath);
	HookEvent("player_spawn", evtInfectedSpawn);
	HookEvent("player_hurt", evtInfectedHurt);
	HookEvent("player_team", evtTeamSwitch);
	HookEvent("player_death", evtInfectedWaitSpawn);
	HookEvent("ghost_spawn_time", evtInfectedWaitSpawn);
	HookEvent("spawner_give_item", evtUnlockVersusDoor);
	HookEvent("player_bot_replace", evtBotReplacedPlayer);
	HookEvent("player_first_spawn", evtPlayerFirstSpawned);
	HookEvent("player_entered_start_area", evtPlayerFirstSpawned);
	HookEvent("player_entered_checkpoint", evtPlayerFirstSpawned);
	HookEvent("player_transitioned", evtPlayerFirstSpawned);
	HookEvent("player_left_start_area", evtPlayerFirstSpawned);
	HookEvent("player_left_checkpoint", evtPlayerFirstSpawned);
	
	
	
	
	// Hook a sound
	AddNormalSoundHook(HookSound_Callback);
	
	// We set some variables
	b_HasRoundStarted = false;
	b_HasRoundEnded = false;
	
	//Autoconfig for plugin
	//AutoExecConfig(true, "l4dinfectedbots");
	
	//----- Zombie HP hooks ---------------------	
	//We store the special infected max HP values in an array and then hook the cvars used to modify them
	//just in case another plugin (or an admin) decides to modify them.  Whilst unlikely if we don't do
	//this then the HP percentages on the HUD will end up screwy, and since it's a one-time initialisation
	//when the plugin loads there's a trivial overhead.
	cvarZombieHP[0] = FindConVar("z_hunter_health");
	cvarZombieHP[1] = FindConVar("z_gas_health");
	cvarZombieHP[2] = FindConVar("z_exploding_health");
	cvarZombieHP[6] = FindConVar("z_tank_health");
	zombieHP[0] = 250;	// Hunter default HP
	if (cvarZombieHP[0] != INVALID_HANDLE)
	{
		zombieHP[0] = GetConVarInt(cvarZombieHP[0]); 
		HookConVarChange(cvarZombieHP[0], cvarZombieHPChanged);
	}
	zombieHP[1] = 250;	// Smoker default HP
	if (cvarZombieHP[1] != INVALID_HANDLE)
	{
		zombieHP[1] = GetConVarInt(cvarZombieHP[1]); 
		HookConVarChange(cvarZombieHP[1], cvarZombieHPChanged);
	}
	zombieHP[2] = 50;	// Boomer default HP
	if (cvarZombieHP[2] != INVALID_HANDLE)
	{
		zombieHP[2] = GetConVarInt(cvarZombieHP[2]);
		HookConVarChange(cvarZombieHP[2], cvarZombieHPChanged);
	}
	
	// Create persistent storage for client HUD preferences 
	usrHUDPref = CreateTrie();
	
	
	RegConsoleCmd("sm_ht", Console_Ht);
	RegConsoleCmd("sm_timer", Console_Timer);
}

public Action:Console_Ht(client, args)
{
	if (client == 0)
	{
		PrintToServer("[TS] sm_ht cannot be used by server.");
		return Plugin_Handled;
	}
	if(args > 1)
	{
		ReplyToCommand(client, "[TS] Usage: sm_ht <Integer> - Hunter Infected Bot Limit.");		
		return Plugin_Handled;
	}
	if(args < 1) 
	{
		ReplyToCommand(client, "[TS] Current Hunter Bot Limit is %d\nUsage: sm_ht <Integer> - Hunter Infected Bot Limit.",HunterLimit);	
		return Plugin_Handled;
	}
	
	if(IsClientInGame(client))
	{
		if(GetClientTeam(client) == 1)
		{
			ReplyToCommand(client, "[TS] You are not in-game");
			return Plugin_Handled;
		}
		else if(GetClientTeam(client) == 3)
		{
			ReplyToCommand(client, "[TS] You are not survivor, dumbass!");
			return Plugin_Handled;
		}
	}
	
	new String:arg1[64];
	GetCmdArg(1, arg1, 64);
	if(IsInteger(arg1))
	{
		new newlimit = StringToInt(arg1);
		if(newlimit>20)
		{
			ReplyToCommand(client, "[TS] why you need so many hunter bots?");
		}
		else if (newlimit<0)
		{
			ReplyToCommand(client, "[TS] Wrong number?");
		}
		else if(newlimit!=HunterLimit)
		{
			SetConVarInt(FindConVar("l4d_infectedbots_hunter_limit"), newlimit);
			if(MaxPlayerZombies < newlimit)
				SetConVarInt(FindConVar("l4d_infectedbots_max_specials"), newlimit);
			CPrintToChatAll("[{olive}TS{default}] {blue}%N{default}: Hunter Bot Limit has been changed to {green}%d",client,newlimit);	
		}
		else
		{
			ReplyToCommand(client, "[TS] Hunter Bot Limit is already %d",HunterLimit);	
		}
		return Plugin_Handled;
	}
	else
	{
		ReplyToCommand(client, "[TS] Usage: sm_ht <Integer> - Hunter Infected Bot Limit.");		
		return Plugin_Handled;
	}	
}

public Action:Console_Timer(client, args)
{
	if (client == 0)
	{
		PrintToServer("[TS] sm_timer cannot be used by server.");
		return Plugin_Handled;
	}
	
	if(args > 2)
	{
		ReplyToCommand(client, "[TS] Usage: sm_timer <Integer> |  sm_timer <MAX> <MIN> - Infected Bot Spawn Timer.");		
		return Plugin_Handled;
	}
	if(args < 1) 
	{
		ReplyToCommand(client, "[TS] Current Spawn Timer %d-%d\nUsage: sm_timer <Integer> |  sm_timer <MAX> <MIN> - Infected Bot Spawn Timer.",GetConVarInt(h_InfectedSpawnTimeMax),GetConVarInt(h_InfectedSpawnTimeMin) );	
		return Plugin_Handled;
	}
	
	if(IsClientInGame(client))
	{
		if(GetClientTeam(client) == 1)
		{
			ReplyToCommand(client, "[TS] You are not in-game");
			return Plugin_Handled;
		}
		else if(GetClientTeam(client) == 3)
		{
			ReplyToCommand(client, "[TS] You are not survivor, dumbass!");
			return Plugin_Handled;
		}
	}
	
	if(args == 1)
	{
		new String:arg1[64];
		GetCmdArg(1, arg1, 64);
		if(IsInteger(arg1))
		{
			new DD = StringToInt(arg1);
			
			if(DD>120)
			{
				ReplyToCommand(client, "[TS] why so long?");
			}
			if(DD<=0)
			{
				ReplyToCommand(client, "[TS] Failed to set timer! minimum value is 1.");
			}
			else
			{
				SetConVarInt(FindConVar("l4d_infectedbots_adjust_spawn_times"), 0);
				SetConVarInt(FindConVar("l4d_infectedbots_spawn_time_max"), DD);
				SetConVarInt(FindConVar("l4d_infectedbots_spawn_time_min"), DD);
				CPrintToChatAll("[{olive}TS{default}] {blue}%N{default}: Bot Spawn Timer has been changed to {green}%d {default}- {green}%d",client,DD,DD);	
			}
			return Plugin_Handled;
		}
		else
		{
			ReplyToCommand(client, "[TS] Usage: sm_timer <Integer> |  sm_timer <MAX> <MIN> - Infected Bot Spawn Timer.");		
			return Plugin_Handled;
		}	
	}
	else
	{
		new String:arg1[64];
		GetCmdArg(1, arg1, 64);
		new String:arg2[64];
		GetCmdArg(2, arg2, 64);
		if(IsInteger(arg1) && IsInteger(arg2))
		{
			new Max = StringToInt(arg1);
			new Min = StringToInt(arg2);
			if(Min>Max)
			{
				new temp = Max;
				Max = Min;
				Min = temp;
			}
			
			if(Max>120)
			{
				ReplyToCommand(client, "[TS] why so long?");
			}
			else
			{
				SetConVarInt(FindConVar("l4d_infectedbots_adjust_spawn_times"), 0);
				SetConVarInt(FindConVar("l4d_infectedbots_spawn_time_max"), Max);
				SetConVarInt(FindConVar("l4d_infectedbots_spawn_time_min"), Min);
				CPrintToChatAll("[{olive}TS{default}] {blue}%N{default}: Bot Spawn Timer has been changed to {green}%d {default}- {green}%d",client,Max,Min);	
			}
			return Plugin_Handled;
		}
		else
		{
			ReplyToCommand(client, "[TS] Usage: sm_timer <Integer> |  sm_timer <MAX> <MIN> - Infected Bot Spawn Timer.");		
			return Plugin_Handled;
		}
	}
}

public ConVarBoomerLimit(Handle:convar, const String:oldValue[], const String:newValue[])
{
	BoomerLimit = GetConVarInt(h_BoomerLimit);
}
public ConVarSmokerLimit(Handle:convar, const String:oldValue[], const String:newValue[])
{
	SmokerLimit = GetConVarInt(h_SmokerLimit);
}

public ConVarHunterLimit(Handle:convar, const String:oldValue[], const String:newValue[])
{
	HunterLimit = GetConVarInt(h_HunterLimit);
}

public ConVarDirectorCvarChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	DirectorCvarsModified = true;
}

public ConVarMaxPlayerZombies(Handle:convar, const String:oldValue[], const String:newValue[])
{
	MaxPlayerZombies = GetConVarInt(h_MaxPlayerZombies);
	CreateTimer(0.1, MaxSpecialsSet);
}

public ConVarDirectorSpawn(Handle:convar, const String:oldValue[], const String:newValue[])
{
	DirectorSpawn = GetConVarBool(h_DirectorSpawn);
	if (!DirectorSpawn)
	{
		//ResetCvars();
		TweakSettings();
		CheckIfBotsNeeded(true, false);
	}
	else
	{
		//ResetCvarsDirector();
		DirectorStuff();
	}
}

public ConVarGameMode(Handle:convar, const String:oldValue[], const String:newValue[])
{
	GameModeCheck();
	
	if (!DirectorSpawn)
	{
		//ResetCvars();
		TweakSettings();
	}
	else
	{
		//ResetCvarsDirector();
		DirectorStuff();
	}
}

public ConVarDifficulty(Handle:convar, const String:oldValue[], const String:newValue[])
{
	TankHealthCheck();
}

public ConVarVersusCoop(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (GetConVarBool(h_VersusCoop))
	{
		SetConVarInt(FindConVar("vs_max_team_switches"), 0);
		SetConVarInt(FindConVar("sb_all_bot_team"), 1);
	}
	else
	{
		SetConVarInt(FindConVar("vs_max_team_switches"), 1);
		//SetConVarInt(FindConVar("sb_all_bot_team"), 0);
	}
}

public ConVarCoopVersus(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (GetConVarBool(h_JoinableTeams))
	{
		SetConVarInt(FindConVar("sb_all_bot_team"), 1);
	}
	// else
	// {
	// 	SetConVarInt(FindConVar("sb_all_bot_team"), 0);
	// }
}

TweakSettings()
{
	// We tweak some settings ...
	
	// Some interesting things about this. There was a bug I discovered that in versions 1.7.8 and below, infected players would not spawn as ghosts in VERSUS. This was
	// due to the fact that the coop class limits were not being reset (I didn't think they were linked at all, but I should have known better). This bug has been fixed
	// with the coop class limits being reset on every gamemode except coop of course.
	
	// Reset the cvars
	ResetCvars();
	
	switch (GameMode)
	{
		case 1: // Coop, We turn off the ability for the director to spawn the bots, and have the plugin do it while allowing the director to spawn tanks and witches, 
		// MI 5
		{
			SetConVarInt(FindConVar("z_gas_limit"), 0);
			SetConVarInt(FindConVar("z_exploding_limit"), 0);
			SetConVarInt(FindConVar("z_hunter_limit"), 0);
		}
		case 2: // Versus, Better Versus Infected AI
		{
			SetConVarInt(FindConVar("z_gas_limit"), 999);
			SetConVarInt(FindConVar("z_exploding_limit"), 999);
			SetConVarInt(FindConVar("z_hunter_limit"), 999);

			// Enhance Special Infected AI
			if (GetConVarBool(h_VersusCoop))
				SetConVarInt(FindConVar("vs_max_team_switches"), 0);
		}
		case 3: // Survival, Turns off the ability for the director to spawn infected bots in survival, MI 5
		{
			SetConVarInt(FindConVar("holdout_max_smokers"), 0);
			SetConVarInt(FindConVar("holdout_max_boomers"), 0);
			SetConVarInt(FindConVar("holdout_max_hunters"), 0);
			SetConVarInt(FindConVar("holdout_max_specials"), MaxPlayerZombies);
			SetConVarInt(FindConVar("z_gas_limit"), 0);
			SetConVarInt(FindConVar("z_exploding_limit"), 0);
			SetConVarInt(FindConVar("z_hunter_limit"), 0);
		}
	}
	
	DirectorCvarsModified = false;

	#if DEBUGSERVER
	LogMessage("Tweaking Settings");
	#endif
	
}

ResetCvars()
{
	#if DEBUGSERVER
	LogMessage("Plugin Cvars Reset");
	#endif
	if (GameMode == 1)
	{
		ResetConVar(FindConVar("director_no_specials"), true, true);
		ResetConVar(FindConVar("holdout_max_smokers"), true, true);
		ResetConVar(FindConVar("holdout_max_boomers"), true, true);
		ResetConVar(FindConVar("holdout_max_hunters"), true, true);
		ResetConVar(FindConVar("holdout_max_specials"), true, true);
	}
	else if (GameMode == 2)
	{
		ResetConVar(FindConVar("holdout_max_smokers"), true, true);
		ResetConVar(FindConVar("holdout_max_boomers"), true, true);
		ResetConVar(FindConVar("holdout_max_hunters"), true, true);
		ResetConVar(FindConVar("holdout_max_specials"), true, true);
	}
	else if (GameMode == 3)
	{
		ResetConVar(FindConVar("z_hunter_limit"), true, true);
		ResetConVar(FindConVar("z_gas_limit"), true, true);
		ResetConVar(FindConVar("z_exploding_limit"), true, true);
		ResetConVar(FindConVar("director_no_specials"), true, true);
	}
}


ResetCvarsDirector()
{
	#if DEBUGSERVER
	LogMessage("Director Cvars Reset");
	#endif
	if (GameMode != 2)
	{
		ResetConVar(FindConVar("z_hunter_limit"), true, true);
		ResetConVar(FindConVar("z_exploding_limit"), true, true);
		ResetConVar(FindConVar("z_gas_limit"), true, true);
		ResetConVar(FindConVar("holdout_max_smokers"), true, true);
		ResetConVar(FindConVar("holdout_max_boomers"), true, true);
		ResetConVar(FindConVar("holdout_max_hunters"), true, true);
		ResetConVar(FindConVar("holdout_max_specials"), true, true);
	}
	else
	{
		ResetConVar(FindConVar("z_hunter_limit"), true, true);
		ResetConVar(FindConVar("z_exploding_limit"), true, true);
		ResetConVar(FindConVar("z_gas_limit"), true, true);
		
	}
}


public Action:evtRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	// If round has started ...
	if (b_HasRoundStarted)
		return;
	
	b_LeftSaveRoom = false;
	b_HasRoundEnded = false;
	b_HasRoundStarted = true;
	
	//Check the GameMode
	GameModeCheck();
	
	if (GameMode == 0)
		return;
	
	#if DEBUGCLIENTS
	PrintToChatAll("Round Started");
	#endif
	#if DEBUGSERVER
	LogMessage("Round Started");
	#endif
	
	// Removes the boundaries for z_max_player_zombies and notify flag
	new flags = GetConVarFlags(FindConVar("z_max_player_zombies"));
	SetConVarBounds(FindConVar("z_max_player_zombies"), ConVarBound_Upper, false);
	SetConVarFlags(FindConVar("z_max_player_zombies"), flags & ~FCVAR_NOTIFY);
	
	// When the game starts, stop the bots till a player joins
	//if (!b_LeftSaveRoom)
	//	SetConVarInt(FindConVar("sb_stop"), 1);
	
	// Added a delay to setting MaxSpecials so that it would set correctly when the server first starts up
	CreateTimer(0.4, MaxSpecialsSet);
	
	if (AfterInitialRound)
	{
		#if DEBUGCLIENTS
		PrintToChatAll("Another Round has started");
		#endif
		
		// This little part is needed because some events just can't execute when another round starts.
		
		//SetConVarInt(FindConVar("sb_stop"), 0);
		
		if (GameMode == 2 && GetConVarBool(h_VersusCoop))
		{
			for (new i=1; i<=MaxClients; i++)
			{
				// We check if player is in game
				if (!IsClientInGame(i)) continue;
				// Check if client is survivor ...
				if (GetClientTeam(i)==TEAM_SURVIVORS)
				{
					// If player is a real player ... 
					if (!IsFakeClient(i))
					{
						ChangeClientTeam(i, TEAM_INFECTED);
					}
				}
			}
			
		}
		// Kill the player if they are infected and its not versus (prevents survival finale bug and player ghosts when there shouldn't be)
		if (GameMode != 2)
		{
			for (new i=1; i<=MaxClients; i++)
			{
				// We check if player is in game
				if (!IsClientInGame(i)) continue;
				// Check if client is infected ...
				if (GetClientTeam(i)==TEAM_INFECTED)
				{
					// If player is a real player ... 
					if (!IsFakeClient(i))
					{
						if (GameMode != 2 && GetConVarBool(h_JoinableTeams) && !GetConVarBool(h_AdminJoinInfected))
						{
							CreateTimer(30.0, AnnounceJoinInfected, i, TIMER_FLAG_NO_MAPCHANGE);
							CreateTimer(10.0, InfectedPlayerJoiner, i, TIMER_FLAG_NO_MAPCHANGE);
						}
						if (IsPlayerGhost(i))
						{
							CreateTimer(0.1, Timer_InfectedKillSelf, i, TIMER_FLAG_NO_MAPCHANGE);
						}
					}
				}
			}
		}
		
		for (new i = 1; i <= MaxClients; i++)
		{
			respawnDelay[i] = 0;
			PlayerLifeState[i] = false;
			isTankOnFire[i] = false;
			burningTankTimeLeft[i] = 0;
			TankWasSeen[i] = false;
			AlreadyGhosted[i] = false;
		}
		
		
	}
	
	//reset some variables
	InfectedBotQueue = 0;
	TanksPlaying = 0;
	BotReady = 0;
	TankFrustStop = false;
	FinaleStarted = false;
	SpecialHalt = false;
	InitialSpawn = false;
	TempBotSpawned = false;
	SurvivalVersus = false;
	
	// Show the HUD to the connected clients.
	roundInProgress = true;
	if (infHUDTimer == INVALID_HANDLE)
	{
		infHUDTimer = CreateTimer(5.0, showInfHUD, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}
	
	// Check the Tank's health to properly display it in the HUD
	TankHealthCheck();
	// Start up TweakSettings or Director Stuff
	if (!DirectorSpawn)
		TweakSettings();
	else
	DirectorStuff();
	
	if (GameMode != 3)
	{
		#if DEBUGSERVER
		LogMessage("Starting the Coop/Versus PlayerLeft Start Timer");
		#endif
		CreateTimer(1.0, PlayerLeftStart, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action:evtPlayerFirstSpawned(Handle:event, const String:name[], bool:dontBroadcast)
{
	// This event's purpose is to execute when a player first enters the server. This eliminates a lot of problems when changing variables setting timers on clients, among fixing many sb_all_bot_team
	// issues.
	
	if (b_HasRoundEnded)
		return;
	
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (!client)
		return;
	
	if (IsFakeClient(client))
		return;
	
	// If player has already entered the start area, don't go into this
	if (PlayerHasEnteredStart[client])
		return;
	
	if (!b_LeftSaveRoom)
	{
		if (GetConVarBool(h_JoinableTeams) && GameMode != 2 || GetConVarBool(h_VersusCoop) && GameMode == 2)
		{
			SetConVarInt(FindConVar("sb_all_bot_team"), 1);
		}
		
		//SetConVarInt(FindConVar("sb_stop"), 0);
	}
	
	#if DEBUGCLIENTS
	PrintToChatAll("Player has spawned for the first time");
	#endif
	
	// Versus Coop code, puts all players on infected at start, delay is added to prevent a weird glitch
	
	if (GameMode == 2 && GetConVarBool(h_VersusCoop))
		CreateTimer(0.1, Timer_VersusCoopTeamChanger, client, TIMER_FLAG_NO_MAPCHANGE);
	
	// Kill the player if they are infected and its not versus (prevents survival finale bug and player ghosts when there shouldn't be)
	if (GameMode != 2)
	{
		if (GetClientTeam(client)==TEAM_INFECTED)
		{
			if (IsPlayerGhost(client))
			{
				CreateTimer(0.1, Timer_InfectedKillSelf, client, TIMER_FLAG_NO_MAPCHANGE);
			}
		}
	}
	
	respawnDelay[client] = 0;
	PlayerLifeState[client] = false;
	isTankOnFire[client] = false;
	burningTankTimeLeft[client] = 0;
	TankWasSeen[client] = false;
	AlreadyGhosted[client] = false;
	PlayerHasEnteredStart[client] = true;
	
	if (GameMode != 2 && GetConVarBool(h_JoinableTeams) && !GetConVarBool(h_AdminJoinInfected))
	{
		CreateTimer(30.0, AnnounceJoinInfected, client, TIMER_FLAG_NO_MAPCHANGE);
		CreateTimer(10.0, InfectedPlayerJoiner, client, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action:Timer_VersusCoopTeamChanger(Handle:Timer, any:client)
{
	ChangeClientTeam(client, TEAM_INFECTED);
}

public Action:Timer_InfectedKillSelf(Handle:Timer, any:client)
{
	ForcePlayerSuicide(client);
}

GameModeCheck()
{
	#if DEBUGSERVER
	LogMessage("Checking Gamemode");
	#endif
	// We determine what the gamemode is
	decl String:GameName[16];
	GetConVarString(h_GameMode, GameName, sizeof(GameName));
	if (StrEqual(GameName, "survival", false))
		GameMode = 3;
	else if (StrEqual(GameName, "versus", false) || StrEqual(GameName, "teamversus", false) || StrEqual(GameName, "scavenge", false) || StrEqual(GameName, "teamscavenge", false) || StrEqual(GameName, "mutation12", false) || StrEqual(GameName, "mutation13", false) || StrEqual(GameName, "mutation15", false) || StrEqual(GameName, "mutation11", false))
		GameMode = 2;
	else if (StrEqual(GameName, "coop", false) || StrEqual(GameName, "realism", false) || StrEqual(GameName, "mutation3", false) || StrEqual(GameName, "mutation9", false) || StrEqual(GameName, "mutation1", false) || StrEqual(GameName, "mutation7", false) || StrEqual(GameName, "mutation10", false) || StrEqual(GameName, "mutation2", false) || StrEqual(GameName, "mutation4", false) || StrEqual(GameName, "mutation5", false) || StrEqual(GameName, "mutation14", false))
		GameMode = 1;
	else
	GameMode = 1;
	
	TankHealthCheck();
}

TankHealthCheck()
{
	decl String:difficulty[100];
	GetConVarString(h_Difficulty, difficulty, sizeof(difficulty));
	
	if (GameMode == 2)
	{
		zombieHP[6] = 4000;	// Tank default HP
		if (cvarZombieHP[6] != INVALID_HANDLE)
		{
			zombieHP[6] = RoundToFloor(GetConVarInt(cvarZombieHP[6]) * 1.5);	// Tank health is multiplied by 1.5x in VS	
			HookConVarChange(cvarZombieHP[6], cvarZombieHPChanged);
		}
	}
	else if (StrContains(difficulty, "Easy", false) != -1)  
	{
		zombieHP[6] = 4000;	// Tank default HP
		if (cvarZombieHP[6] != INVALID_HANDLE)
		{
			zombieHP[6] = RoundToFloor(GetConVarInt(cvarZombieHP[6]) * 0.75);
			HookConVarChange(cvarZombieHP[6], cvarZombieHPChanged);
		}
	}
	else if (StrContains(difficulty, "Normal", false) != -1)
	{
		zombieHP[6] = 4000;	// Tank default HP
		if (cvarZombieHP[6] != INVALID_HANDLE)
		{
			zombieHP[6] = GetConVarInt(cvarZombieHP[6]);
			HookConVarChange(cvarZombieHP[6], cvarZombieHPChanged);
		}
	}
	else if (StrContains(difficulty, "Hard", false) != -1 || StrContains(difficulty, "Impossible", false) != -1)
	{
		zombieHP[6] = 4000;	// Tank default HP
		if (cvarZombieHP[6] != INVALID_HANDLE)
		{
			zombieHP[6] = RoundToFloor(GetConVarInt(cvarZombieHP[6]) * 2.0);
			HookConVarChange(cvarZombieHP[6], cvarZombieHPChanged);
		}
	}
}

public Action:MaxSpecialsSet(Handle:Timer)
{
	SetConVarInt(FindConVar("z_max_player_zombies"), MaxPlayerZombies);
	#if DEBUGSERVER
	LogMessage("Max Player Zombies Set");
	#endif
}

DirectorStuff()
{	
	SpecialHalt = false;
	
	// if the server changes the director spawn limits in any way, don't reset the cvars
	if (!DirectorCvarsModified)
		ResetCvarsDirector();
	
	#if DEBUGSERVER
	LogMessage("Director Stuff has been executed");
	#endif
	
}

public Action:evtRoundEnd (Handle:event, const String:name[], bool:dontBroadcast)
{
	// If round has not been reported as ended ..
	if (!b_HasRoundEnded)
	{
		// we mark the round as ended
		b_HasRoundEnded = true;
		b_HasRoundStarted = false;
		b_LeftSaveRoom = false;
		roundInProgress = false;
		AfterInitialRound = true;
		
		// This I set in because the panel was never originally designed for multiple gamemodes.
		CreateTimer(5.0, HUDReset);
		
		// This spawns a Survivor Bot so that the health bonus for the bots count (L4D only)
		if (GameMode == 2 && !RealPlayersOnSurvivors() && !AllSurvivorsDeadOrIncapacitated())
		{
			new bot = CreateFakeClient("Fake Survivor");
			ChangeClientTeam(bot,2);
			DispatchKeyValue(bot,"classname","SurvivorBot");
			DispatchSpawn(bot);
			
			CreateTimer(0.1,kickbot,bot);
		}
		
		for (new i = 1; i <= MaxClients; i++)
		{
			PlayerHasEnteredStart[i] = false;
		}
	
		ResetTimer();
	}
}

public OnMapEnd()
{
	b_HasRoundStarted = false;
	b_HasRoundEnded = true;
	b_LeftSaveRoom = false;
	roundInProgress = false;

	ResetTimer();
}

public Action:PlayerLeftStart(Handle:Timer)
{
	if (LeftStartArea())
	{	
		// We don't care who left, just that at least one did
		if (!b_LeftSaveRoom)
		{
			decl String:GameName[16];
			GetConVarString(h_GameMode, GameName, sizeof(GameName));
			if (StrEqual(GameName, "mutation15", false))
			{
				SurvivalVersus = true;
				SetConVarInt(FindConVar("survival_max_smokers"), 0);
				SetConVarInt(FindConVar("survival_max_boomers"), 0);
				SetConVarInt(FindConVar("survival_max_hunters"), 0);
				return Plugin_Continue; 
			}
			
			#if DEBUGSERVER
			LogMessage("A player left the start area, spawning bots");
			#endif
			#if DEBUGCLIENTS
			PrintToChatAll("A player left the start area, spawning bots");
			#endif
			b_LeftSaveRoom = true;
			
			
			
			
			// We reset some settings
			InitialSpawn = true;
			
			// We check if we need to spawn bots
			CheckIfBotsNeeded(false, true);
			#if DEBUGSERVER
			LogMessage("Checking to see if we need bots");
			#endif
			CreateTimer(3.0, InitialSpawnReset, _, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	else
	{
		CreateTimer(1.0, PlayerLeftStart, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	return Plugin_Continue;
}



// This is hooked to the panic event, but only starts if its survival. This is what starts up the bots in survival.

public Action:evtSurvivalStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (GameMode == 3 || SurvivalVersus)
	{  
		// We don't care who left, just that at least one did
		if (!b_LeftSaveRoom)
		{
			#if DEBUGSERVER
			LogMessage("A player triggered the survival event, spawning bots");
			#endif
			#if DEBUGCLIENTS
			PrintToChatAll("A player triggered the survival event, spawning bots");
			#endif
			b_LeftSaveRoom = true;
			
			// We reset some settings
			InitialSpawn = true;
			
			// We check if we need to spawn bots
			CheckIfBotsNeeded(false, true);
			#if DEBUGSERVER
			LogMessage("Checking to see if we need bots");
			#endif
			CreateTimer(3.0, InitialSpawnReset, _, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	return Plugin_Continue;
}

public Action:InitialSpawnReset(Handle:Timer)
{
	InitialSpawn = false;
}

public Action:BotReadyReset(Handle:Timer)
{
	BotReady = 0;
}

public Action:InfectedPlayerJoiner(Handle:Timer, any:client)
{
	// This code puts players on the infected after the survivor team has been filled.
	// set variables
	new SurvivorRealCount;
	new SurvivorLimit = GetConVarInt(FindConVar("survivor_limit"));
	
	// reset counters
	SurvivorRealCount = 0;
	
	// First we count the ammount of survivor real players
	for (new i=1; i<=MaxClients; i++)
	{
		// We check if player is in game
		if (!IsClientInGame(i)) continue;
		// Check if client is survivor ...
		if (GetClientTeam(i)==TEAM_SURVIVORS)
		{
			// If player is a real player ... 
			if (!IsFakeClient(i))
			{
				SurvivorRealCount++;
				#if DEBUGSERVER
				LogMessage("Found a survivor player");
				#endif
			}
		}
	}
	
	if (IsClientInGame(client) && GetClientTeam(client) == TEAM_SPECTATOR && !IsFakeClient(client))
	{
		// If the survivor team is full
		if  (SurvivorRealCount >= SurvivorLimit)
		{
			ChangeClientTeam(client, TEAM_INFECTED);
			PrintHintText(client, "IBP: Placing you on the Infected team due to survivor team being full");
		}
		else
		{
			SwitchToSurvivors(client);
			PrintHintText(client, "IBP: Placing you on the Survivor team");
		}
	}
}

public Action:evtUnlockVersusDoor(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (b_LeftSaveRoom || GameMode != 2 || RealPlayersOnInfected() || TempBotSpawned)
		return Plugin_Continue;
	
	//PrintToChatAll("Attempting to spawn tempbot");
	
	new bot = CreateFakeClient("tempbot");
	if (bot != 0)
	{
		ChangeClientTeam(bot,TEAM_INFECTED);
		CreateTimer(0.1,kickbot,bot);
		TempBotSpawned = true;
	}
	else
	{
		LogError("Temperory Infected Bot was not spawned for the Versus Door Unlocker!");
	}
	
	return Plugin_Continue;
}

public Action:InfectedBotBooterVersus(Handle:Timer)
{
	//This is to check if there are any extra bots and boot them if necessary, excluding tanks, versus only
	if (GameMode == 2)
	{
		// current count ...
		new total;
		
		for (new i=1; i<=MaxClients; i++)
		{
			// if player is ingame ...
			if (IsClientInGame(i))
			{
				// if player is on infected's team
				if (GetClientTeam(i) == TEAM_INFECTED)
				{
					// We count depending on class ...
					if (!IsPlayerTank(i) || (IsPlayerTank(i) && !PlayerIsAlive(i)))
					{
						total++;
					}
				}
			}
		}
		if (total + InfectedBotQueue > MaxPlayerZombies)
		{
			new kick = total + InfectedBotQueue - MaxPlayerZombies; 
			new kicked = 0;
			
			// We kick any extra bots ....
			for (new i=1;(i<=MaxClients)&&(kicked < kick);i++)
			{
				// If player is infected and is a bot ...
				if (IsClientInGame(i) && IsFakeClient(i))
				{
					//  If bot is on infected ...
					if (GetClientTeam(i) == TEAM_INFECTED)
					{
						// If player is not a tank
						if (!IsPlayerTank(i) || ((IsPlayerTank(i) && !PlayerIsAlive(i))))
						{
							// timer to kick bot
							CreateTimer(0.1,kickbot,i);
							
							// increment kicked count ..
							kicked++;
							#if DEBUGSERVER
							LogMessage("Kicked a Bot");
							#endif
						}
					}
				}
			}
		}
	}
}

// This code, combined with Durzel's code, announce certain messages to clients when they first enter the server

public OnClientPutInServer(client)
{
	// If is a bot, skip this function
	if (IsFakeClient(client))
		return;
	
	// Durzel's code ***********************************************************************************
	decl String:clientSteamID[32];
	new doHideHUD;
	
//	GetClientAuthString(client, clientSteamID, 32);
	
	// Try and find their HUD visibility preference
	new foundKey = GetTrieValue(Handle:usrHUDPref, clientSteamID, doHideHUD);
	if (foundKey)
	{
		if (doHideHUD)
		{
			// This user chose not to view the HUD at some point in the game
			hudDisabled[client] = true;
		}
	}
	//else hudDisabled[client] = true;
	// End Durzel's code **********************************************************************************
	
	PlayersInServer++;
	
	#if DEBUGSERVER
	LogMessage("OnClientPutInServer has started");
	#endif
}

public Action:CheckGameMode(client, args)
{
	if (client)
	{
		PrintToChat(client, "GameMode = %i", GameMode);
	}
}

public Action:CheckQueue(client, args)
{
	if (client)
	{
		if (GameMode == 2)
			CountInfected();
		else
		CountInfected_Coop();
		
		PrintToChat(client, "InfectedBotQueue = %i, InfectedBotCount = %i, InfectedRealCount = %i", InfectedBotQueue, InfectedBotCount, InfectedRealCount);
	}
}

public Action:JoinInfected(client, args)
{
	if (client && (GameMode == 1 || GameMode == 3) && GetConVarBool(h_JoinableTeams))
	{
		if (GetConVarBool(h_AdminJoinInfected))
		{
			if (GetUserFlagBits(client) > 0)
				ChangeClientTeam(client, TEAM_INFECTED);
			else
			{
				PrintHintText(client, "Only admins can join the infected.");
			}
		}
		else
		{
			if (HumansOnInfected() < GetConVarInt(h_HumanCoopLimit))
				ChangeClientTeam(client, TEAM_INFECTED);
			else
			PrintHintText(client, "The Infected Team is full.");
		}
	}
}

public Action:JoinSurvivors(client, args)
{
	if (client && (GameMode == 1 || GameMode == 3))
	{
		SwitchToSurvivors(client);
	}
}

public Action:ForceInfectedSuicide(client, args)
{
	if (client && GetClientTeam(client) == 3 && IsPlayerAlive(client))
	{
		ForcePlayerSuicide(client);
	}
}

// Joining spectators is for developers only, commented in the final
public Action:JoinSpectator(client, args)
{
	if ((client) && (GetConVarBool(h_JoinableTeams)))
	{
		ChangeClientTeam(client, TEAM_SPECTATOR);
	}
}

public Action:AnnounceJoinInfected(Handle:timer, any:client)
{
	if (IsClientInGame(client) && (!IsFakeClient(client)))
	{
		if ((GetConVarBool(h_JoinableTeamsAnnounce)) && (GetConVarBool(h_JoinableTeams)) && ((GameMode == 1) || (GameMode == 3)))
		{
			PrintHintText(client, "IBP: Type !ji in chat to join the infected team or type !js to join the survivors!");
		}
	}
}

public Action:evtPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	// We get the client id and time
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	// If client is valid
	if (!client || !IsClientInGame(client)) return Plugin_Continue;
	
	if (GetClientTeam(client) != TEAM_INFECTED)
		return Plugin_Continue;
	
	if (DirectorSpawn && GameMode != 2)
	{
		if (IsPlayerSmoker(client))
		{
			if (IsFakeClient(client))
			{
				if (!SpecialHalt)
				{
					CreateTimer(0.1, kickbot, client);
					
					#if DEBUGSERVER
					LogMessage("Smoker kicked");
					#endif
					
					new BotNeeded = 1;
					
					CreateTimer(0.2, Spawn_InfectedBot_Director, BotNeeded);
					
					
					#if DEBUGSERVER
					LogMessage("Spawned Smoker");
					#endif
				}
			}
		}
		else if (IsPlayerBoomer(client))
		{
			if (IsFakeClient(client))
			{
				if (!SpecialHalt)
				{
					CreateTimer(0.1, kickbot, client);
					
					#if DEBUGSERVER
					LogMessage("Boomer kicked");
					#endif
					
					new BotNeeded = 2;
					CreateTimer(0.2, Spawn_InfectedBot_Director, BotNeeded);
					
					
					#if DEBUGSERVER
					LogMessage("Spawned Booomer");
					#endif
				}
			}
		}
		else if (IsPlayerHunter(client))
		{
			if (IsFakeClient(client))
			{
				if (!SpecialHalt)
				{
					CreateTimer(0.1, kickbot, client);
					
					#if DEBUGSERVER
					LogMessage("Hunter Kicked");
					#endif
					
					new BotNeeded = 3;
					
					CreateTimer(0.2, Spawn_InfectedBot_Director, BotNeeded);
					
					
					#if DEBUGSERVER
					LogMessage("Hunter Spawned");
					#endif
				}
			}
		}
	}
	
	if (IsPlayerTank(client))
	{
		if (b_LeftSaveRoom)
		{	
			#if DEBUGSERVER
			LogMessage("Tank Event Triggered");
			#endif
			if (!TankFrustStop)
			{
				TanksPlaying = 0;
				MaxPlayerTank = 0;
				for (new i=1;i<=MaxClients;i++)
				{
					// We check if player is in game
					if (!IsClientInGame(i)) continue;
					
					// Check if client is infected ...
					if (GetClientTeam(i)==TEAM_INFECTED)
					{
						// If player is a tank
						if (IsPlayerTank(i) && PlayerIsAlive(i))
						{
							TanksPlaying++;
							MaxPlayerTank++;
						}
					}
				}
				
				MaxPlayerTank = MaxPlayerTank + MaxPlayerZombies;
				SetConVarInt(FindConVar("z_max_player_zombies"), MaxPlayerTank);
				#if DEBUGSERVER
				LogMessage("Incremented Max Zombies from Tank Spawn EVENT");
				#endif
				
				if (GameMode == 3)
				{
					if (IsFakeClient(client) && RealPlayersOnInfected())
					{
						if (GetConVarBool(h_CoopPlayableTank) && AreTherePlayersWhoAreNotTanks())
						{
							CreateTimer(0.5, TankSpawner, client);
							CreateTimer(0.6, kickbot, client);
						}
					}
				}
				else
				{
					MaxPlayerTank = MaxPlayerZombies;
					SetConVarInt(FindConVar("z_max_player_zombies"), MaxPlayerZombies);
				}
				
				
			}
		}
	}
	else if (IsFakeClient(client))
	{
		if (FightOrDieTimer[client] != INVALID_HANDLE)
		{
			KillTimer(FightOrDieTimer[client]);
			FightOrDieTimer[client] = INVALID_HANDLE;
		}
		FightOrDieTimer[client] = CreateTimer(GetConVarFloat(h_idletime_b4slay), DisposeOfCowards, client, TIMER_FLAG_NO_MAPCHANGE);
	}
	
	// Turn on Flashlight for Infected player
	TurnNightVisionOn(client);
	
	return Plugin_Continue;
}

public Action:evtBotReplacedPlayer(Handle:event, const String:name[], bool:dontBroadcast)
{
	// The purpose of using this event, is to prevent a bot from ghosting after the player leaves or joins another team
	
	new bot = GetClientOfUserId(GetEventInt(event, "bot"));
	AlreadyGhostedBot[bot] = true;
}

public Action:DisposeOfCowards(Handle:timer, any:coward)
{
	if (IsClientInGame(coward) && IsFakeClient(coward) && GetClientTeam(coward) == TEAM_INFECTED && !IsPlayerTank(coward) && PlayerIsAlive(coward))
	{
		// Check to see if the infected can be seen by the survivors. If so, kill the timer and make a new one.
		if (CanBeSeenBySurvivors(coward) || IsTooClose(coward, 550.0) || L4D_GetSurvivorVictim(coward) != -1)
		{
			FightOrDieTimer[coward] = INVALID_HANDLE;
			FightOrDieTimer[coward] = CreateTimer(GetConVarFloat(h_idletime_b4slay), DisposeOfCowards, coward);
			return;
		}
		else
		{
			CreateTimer(0.1, kickbot, coward);
			if (!DirectorSpawn)
			{
				new SpawnTime = GetURandomIntRange(GetConVarInt(h_InfectedSpawnTimeMin), GetConVarInt(h_InfectedSpawnTimeMax));
				
				if (GameMode == 2 && GetConVarBool(h_AdjustSpawnTimes) && MaxPlayerZombies != HumansOnInfected())
					SpawnTime = SpawnTime / (MaxPlayerZombies - HumansOnInfected());
				else if (GameMode == 1 && GetConVarBool(h_AdjustSpawnTimes))
					SpawnTime = SpawnTime - TrueNumberOfSurvivors();
				
				CreateTimer(float(SpawnTime), Spawn_InfectedBot, _, 0);
				InfectedBotQueue++;
				
				#if DEBUGCLIENTS
				PrintToChatAll("Kicked bot %N for not attacking", coward);
				PrintToChatAll("An infected bot has been added to the spawn queue due to lifespan timer expiring");
				#endif
			}
		}
	}
	FightOrDieTimer[coward] = INVALID_HANDLE;
}

public void evtPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	// If round has ended .. we ignore this
	if (b_HasRoundEnded || !b_LeftSaveRoom) return;
	
	// We get the client id and time
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (FightOrDieTimer[client] != INVALID_HANDLE)
	{
		KillTimer(FightOrDieTimer[client]);
		FightOrDieTimer[client] = INVALID_HANDLE;
	}
	
	
	if (!client || !IsClientInGame(client)) return;
	
	if (GetClientTeam(client) !=TEAM_INFECTED) return;
	
	if (IsPlayerTank(client))
	{
		TankWasSeen[client] = false;
	}
	
	int SpawnTime;
	if (IsFakeClient(client) && (GameMode == 2) && (!DirectorSpawn))
	{
		if (!IsPlayerTank(client))
		{
			SpawnTime = GetURandomIntRange(GetConVarInt(h_InfectedSpawnTimeMin), GetConVarInt(h_InfectedSpawnTimeMax));
			if (GetConVarBool(h_AdjustSpawnTimes) && MaxPlayerZombies != HumansOnInfected())
				SpawnTime = SpawnTime / (MaxPlayerZombies - HumansOnInfected());
			CreateTimer(float(SpawnTime), Spawn_InfectedBot, _, 0);
			InfectedBotQueue++;
		}
	}
	// This spawns a bot in coop/survival regardless if the special that died was controlled by a player, MI 5
	else if ((GameMode != 2) && (!DirectorSpawn))
	{
		if (!GetConVarBool(h_CoopPlayableTank) && !IsPlayerTank(client) || GetConVarBool(h_CoopPlayableTank))
		{
			SpawnTime = GetURandomIntRange(GetConVarInt(h_InfectedSpawnTimeMin), GetConVarInt(h_InfectedSpawnTimeMax));
			if (GameMode == 1 && GetConVarBool(h_AdjustSpawnTimes))
				SpawnTime = SpawnTime - TrueNumberOfSurvivors();
			CreateTimer(float(SpawnTime), Spawn_InfectedBot, _, 0);
			GetSpawnTime[client] = SpawnTime;
			InfectedBotQueue++;
		}
		
		if (IsPlayerTank(client))
			CheckIfBotsNeeded(false, false);
	}
	else if (GameMode != 2 && DirectorSpawn)
	{
		SpawnTime = GetURandomIntRange(GetConVarInt(h_InfectedSpawnTimeMin), GetConVarInt(h_InfectedSpawnTimeMax));
		GetSpawnTime[client] = SpawnTime;
	}
	
	//This will prevent the stats board from coming up if the cvar was set to 1 (L4D 1 only)
	if (!IsFakeClient(client) && !GetConVarBool(h_StatsBoard) && GameMode != 2)
	{
		CreateTimer(1.0, ZombieClassTimer, client, TIMER_FLAG_NO_MAPCHANGE);
	}
	
	// Removes Sphere bubbles in the map when a player dies
	if (GameMode != 2)
	{
		CreateTimer(0.1, ScrimmageTimer, client, TIMER_FLAG_NO_MAPCHANGE);
	}
	
	// This fixes the spawns when the spawn timer is set to 5 or below and fixes the spitter spit glitch
	if (IsFakeClient(client))
		CreateTimer(0.1, kickbot, client);

	int zClass = GetEntProp(client, Prop_Send, "m_zombieClass");
	int iLeftAliveCounts;
	switch(zClass)
	{
		case ZOMBIECLASS_SMOKER:
		{
			if(SmokerLimit == 0) return;
			else if(SmokerLimit == 1)
			{
				delete g_hSpawnColdDownTimer[SI_SMOKER];
				g_hSpawnColdDownTimer[SI_SMOKER] = CreateTimer(float(SpawnTime)-0.1, Timer_SpawnColdDown, SI_SMOKER);
			}
			else if(SmokerLimit > 1)
			{
				for (int i=1;i<=MaxClients;i++)
				{
					if (IsClientInGame(i) && GetClientTeam(i) == TEAM_INFECTED && IsPlayerAlive(i) && IsPlayerSmoker(i))
					{
						iLeftAliveCounts++;
					}
				}

				if(iLeftAliveCounts != SmokerLimit - 1) return;

				delete g_hSpawnColdDownTimer[SI_SMOKER];
				g_hSpawnColdDownTimer[SI_SMOKER] = CreateTimer(float(SpawnTime)-0.1, Timer_SpawnColdDown, SI_SMOKER);
			}
		}
		case ZOMBIECLASS_BOOMER:
		{
			if(BoomerLimit == 0) return;
			else if(BoomerLimit == 1)
			{
				delete g_hSpawnColdDownTimer[SI_BOOMER];
				g_hSpawnColdDownTimer[SI_BOOMER] = CreateTimer(float(SpawnTime)-0.1, Timer_SpawnColdDown, SI_BOOMER);
			}
			else if(BoomerLimit > 1)
			{
				for (int i=1;i<=MaxClients;i++)
				{
					if (IsClientInGame(i) && GetClientTeam(i) == TEAM_INFECTED && IsPlayerAlive(i) && IsPlayerBoomer(i))
					{
						iLeftAliveCounts++;
					}
				}

				if(iLeftAliveCounts != BoomerLimit - 1) return;

				delete g_hSpawnColdDownTimer[SI_BOOMER];
				g_hSpawnColdDownTimer[SI_BOOMER] = CreateTimer(float(SpawnTime)-0.1, Timer_SpawnColdDown, SI_BOOMER);
			}
		}
		case ZOMBIECLASS_HUNTER:
		{
			if(HunterLimit == 0) return;
			else if(HunterLimit == 1)
			{
				delete g_hSpawnColdDownTimer[SI_HUNTER];
				g_hSpawnColdDownTimer[SI_HUNTER] = CreateTimer(float(SpawnTime)-0.1, Timer_SpawnColdDown, SI_HUNTER);
			}
			else if(HunterLimit > 1)
			{
				for (int i=1;i<=MaxClients;i++)
				{
					if (IsClientInGame(i) && GetClientTeam(i) == TEAM_INFECTED && IsPlayerAlive(i) && IsPlayerHunter(i))
					{
						iLeftAliveCounts++;
					}
				}

				if(iLeftAliveCounts != HunterLimit - 1) return;

				delete g_hSpawnColdDownTimer[SI_HUNTER];
				g_hSpawnColdDownTimer[SI_HUNTER] = CreateTimer(float(SpawnTime)-0.1, Timer_SpawnColdDown, SI_HUNTER);
			}
		}
	}
}

public Action:Spawn_InfectedBot_Director(Handle:timer, any:BotNeeded)
{
	
	new bool:resetGhost[MAXPLAYERS+1];
	new bool:resetLife[MAXPLAYERS+1];
	
	for (new i=1;i<=MaxClients;i++)
	{
		if (IsClientInGame(i) && (!IsFakeClient(i))) // player is connected and is not fake and it's in game ...
		{
			// If player is on infected's team and is dead ..
			if (GetClientTeam(i)==TEAM_INFECTED)
			{
				// If player is a ghost ....
				if (IsPlayerGhost(i))
				{
					resetGhost[i] = true;
					SetGhostStatus(i, false);
				}
				else if (!PlayerIsAlive(i) && respawnDelay[i] > 0 && GameMode != 2)
				{
					resetLife[i] = true;
					SetLifeState(i, false);
					#if DEBUGSERVER
					LogMessage("Detected a dead player with a respawn timer, setting restrictions to prevent player from taking a bot");
					#endif
				}
				else if (!PlayerIsAlive(i) && respawnDelay[i] <= 0)
				{
					AlreadyGhosted[i] = false;
					SetLifeState(i, true);
				}
			}
		}
	}
	
	new anyclient = GetAnyClient();
	new bool:temp = false;
	if (anyclient == -1)
	{
		#if DEBUGSERVER
		LogMessage("[Infected bots] Creating temp client to fake command");
		#endif
		
		// we create a fake client
		anyclient = CreateFakeClient("Bot");
		if (anyclient == 0)
		{
			LogError("[L4D] Infected Bots: CreateFakeClient returned 0 -- Infected bot was not spawned");
		}
		temp = true;
	}
	
	SpecialHalt = true;
	
	switch (BotNeeded)
	{
		case 1: // Smoker
		CheatCommand(anyclient, "z_spawn", "smoker auto");
		case 2: // Boomer
		CheatCommand(anyclient, "z_spawn", "boomer auto");
		case 3: // Hunter
		CheatCommand(anyclient, "z_spawn", "hunter auto");
	}
	
	SpecialHalt = false;
	
	// We restore the player's status
	for (new i=1;i<=MaxClients;i++)
	{
		if (resetGhost[i])
			SetGhostStatus(i, true);
		if (resetLife[i])
			SetLifeState(i, true);
	}
	// If client was temp, we setup a timer to kick the fake player
	if (temp) CreateTimer(0.1, kickbot, anyclient);
}

public Action:ZombieClassTimer(Handle:timer, any:client)
{
	if (client)
	{
		SetEntProp(client, Prop_Send, "m_zombieClass", 0);
	}
}

public Action:evtPlayerTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	// If player is a bot, we ignore this ...
	if (GetEventBool(event, "isbot")) return Plugin_Continue;
	
	// We get some data needed ...
	new newteam = GetEventInt(event, "team");
	new oldteam = GetEventInt(event, "oldteam");
	
	// We get the client id and time
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	// If player's new/old team is infected, we recount the infected and add bots if needed ...
	if (!b_HasRoundEnded && b_LeftSaveRoom && GameMode == 2)
	{
		if (oldteam == 3||newteam == 3)
		{
			CheckIfBotsNeeded(false, false);
		}
		if (newteam == 3)
		{
			//Kick Timer
			CreateTimer(1.0, InfectedBotBooterVersus, _, TIMER_FLAG_NO_MAPCHANGE);
			#if DEBUGSERVER
			LogMessage("A player switched to infected, attempting to boot a bot");
			#endif
		}
	}
	else if ((newteam == 3 || newteam == 1) && GameMode != 2)
	{
		// Removes Sphere bubbles in the map when a player joins the infected team, or spectator team
		
		CreateTimer(0.1, ScrimmageTimer, client, TIMER_FLAG_NO_MAPCHANGE);
	}
	return Plugin_Continue;
}

public OnClientDisconnect(client)
{
	// If is a bot, skip this function
	if (IsFakeClient(client))
		return;
	
	// When a client disconnects we need to restore their HUD preferences to default for when 
	// a new client joins and fill the space.
	hudDisabled[client] = false;
	clientGreeted[client] = 0;
	
	// Reset all other arrays
	respawnDelay[client] = 0;
	WillBeTank[client] = false;
	PlayerLifeState[client] = false;
	GetSpawnTime[client] = 0;
	isTankOnFire[client] = false;
	burningTankTimeLeft[client] = 0;
	TankWasSeen[client] = false;
	AlreadyGhosted[client] = false;
	PlayerHasEnteredStart[client] = false;
	PlayersInServer--;
	
	// If no real players are left in game ... MI 5
	if (PlayersInServer == 0)
	{
		#if DEBUGSERVER
		LogMessage("All Players have left the Server");
		#endif
		
		b_LeftSaveRoom = false;
		b_HasRoundEnded = true;
		b_HasRoundStarted = false;
		roundInProgress = false;
		DirectorCvarsModified = false;
		AfterInitialRound = false;
		
		
		// Zero all respawn times ready for the next round
		for (new i = 1; i <= MaxClients; i++)
		{
			respawnDelay[i] = 0;
			isTankOnFire[i] = false;
			burningTankTimeLeft[i] = 0;
			TankWasSeen[i] = false;
			AlreadyGhosted[i] = false;
			PlayerHasEnteredStart[i] = false;
			WillBeTank[i] = false;
		}
		
		for (new i = 1; i <= MaxClients; i++)
		{
			if (FightOrDieTimer[i] != INVALID_HANDLE)
			{
				KillTimer(FightOrDieTimer[i]);
				FightOrDieTimer[i] = INVALID_HANDLE;
			}
		}
		// Set sb_all_bot_team to 0
		
		//SetConVarInt(FindConVar("sb_all_bot_team"), 0);
		
		// This I set in because the panel was never originally designed for multiple gamemodes.
		CreateTimer(5.0, HUDReset);
	}
	
}

public Action:ScrimmageTimer (Handle:timer, any:client)
{
	if (client && IsValidEntity(client))
	{
		SetEntProp(client, Prop_Send, "m_scrimmageType", 0);
	}
}

public Action:CheckIfBotsNeededLater (Handle:timer, any:spawn_immediately)
{
	CheckIfBotsNeeded(spawn_immediately, false);
}

CheckIfBotsNeeded(bool:spawn_immediately, bool:initial_spawn)
{
	if (!DirectorSpawn)
	{
		#if DEBUGSERVER
		LogMessage("Checking bots");
		#endif
		#if DEBUGCLIENTS
		PrintToChatAll("Checking bots");
		#endif
		
		if (b_HasRoundEnded || !b_LeftSaveRoom) return;
		
		// First, we count the infected
		if (GameMode == 2)
		{
			CountInfected();
		}
		else
		{
			CountInfected_Coop();
		}
		
		new diff = MaxPlayerZombies - (InfectedBotCount + InfectedRealCount + InfectedBotQueue);
		
		// If we need more infected bots
		if (diff > 0)
		{
			for (new i;i<diff;i++)
			{
				// If we need them right away ...
				if (spawn_immediately)
				{
					InfectedBotQueue++;
					CreateTimer(0.5, Spawn_InfectedBot, _, 0);
					#if DEBUGSERVER
					LogMessage("Setting up the bot now");
					#endif
				}
				else if (initial_spawn)
				{
					InfectedBotQueue++;
					CreateTimer(float(GetConVarInt(h_InitialSpawn)), Spawn_InfectedBot, _, 0);
					#if DEBUGSERVER
					LogMessage("Setting up the initial bot now");
					#endif
				}
				else // We use the normal time ..
				{
					InfectedBotQueue++;
					if (GameMode == 2 && GetConVarBool(h_AdjustSpawnTimes) && MaxPlayerZombies != HumansOnInfected())
						CreateTimer(float(GetConVarInt(h_InfectedSpawnTimeMax)) / (MaxPlayerZombies - HumansOnInfected()), Spawn_InfectedBot, _, 0);
					else if (GameMode == 1 && GetConVarBool(h_AdjustSpawnTimes))
						CreateTimer(float(GetConVarInt(h_InfectedSpawnTimeMax) - TrueNumberOfSurvivors()), Spawn_InfectedBot, _, 0);
					else
					CreateTimer(float(GetConVarInt(h_InfectedSpawnTimeMax)), Spawn_InfectedBot, _, 0);
				}
			}
		}
		
		if (GameMode == 2)
		{
			CountInfected();
		}
	}
}

CountInfected()
{
	// reset counters
	InfectedBotCount = 0;
	InfectedRealCount = 0;
	
	// First we count the ammount of infected real players and bots
	for (new i=1;i<=MaxClients;i++)
	{
		// We check if player is in game
		if (!IsClientInGame(i)) continue;
		
		// Check if client is infected ...
		if (GetClientTeam(i) == TEAM_INFECTED)
		{
			// If player is a bot ...
			if (IsFakeClient(i))
				InfectedBotCount++;
			else
			InfectedRealCount++;
		}
	}
	
}

// Note: This function is also used for survival.
CountInfected_Coop()
{
	#if DEBUGSERVER
	LogMessage("Counting Bots for Coop");
	#endif
	
	// reset counters
	InfectedBotCount = 0;
	InfectedRealCount = 0;
	
	// First we count the ammount of infected real players and bots
	
	for (new i=1;i<=MaxClients;i++)
	{
		// We check if player is in game
		if (!IsClientInGame(i)) continue;
		
		// Check if client is infected ...
		if (GetClientTeam(i) == TEAM_INFECTED)
		{
			new String:name[MAX_NAME_LENGTH];
			
			GetClientName(i, name, sizeof(name));
			
			if (StrEqual(name, "Infected Bot", true) && IsFakeClient(i))
				continue;
			
			// If someone is a tank and the tank is playable...count him in play
			if (IsPlayerTank(i) && PlayerIsAlive(i) && GetConVarBool(h_CoopPlayableTank) && !IsFakeClient(i))
			{
				InfectedRealCount++;
			}
			
			// If player is not a tank or a dead one
			if (!IsPlayerTank(i) || (IsPlayerTank(i) && !PlayerIsAlive(i)))
			{
				// If player is a bot ...
				if (IsFakeClient(i))
				{
					InfectedBotCount++;
					#if DEBUGSERVER
					LogMessage("Found a bot");
					#endif
				}
				else if (PlayerIsAlive(i) || (IsPlayerGhost(i)))
				{
					InfectedRealCount++;
					#if DEBUGSERVER
					LogMessage("Found a player");
					#endif
				}
			}
		}
	}
}

public Action:TankFrustratedTimer(Handle:timer)
{
	TankFrustStop = false;
}

/*public Action:TankHaltTimer(Handle:timer)
{
TankHalt = false;
}*/

// This code here is to prevent a loop when the tank gets frustrated. Apparently the game counts a tank being frustrated as a spawned tank, and triggers the tank spawn
// event. That may be why the rescue vehicle sometimes arrives earlier than expected

public Action:evtTankFrustrated(Handle:event, const String:name[], bool:dontBroadcast)
{
	TankFrustStop = true;
	#if DEBUGSERVER
	LogMessage("Tank is frustrated!");
	#endif
	CreateTimer(2.0, TankFrustratedTimer, _, TIMER_FLAG_NO_MAPCHANGE);
}

// The main Tank code, it allows a player to take over the tank when if allowed, and adds additional tanks if the tanks per spawn cvar was set.
public Action:TankSpawner(Handle:timer, any:client)
{
	#if DEBUGTANK
	LogMessage("Tank Spawner Triggred");
	#endif
	new Index[8];
	new IndexCount = 0;
	decl Float:position[3];
	new tankhealth;
	new bool:tankonfire;
	
	if (client && IsClientInGame(client))
	{
		tankhealth = GetClientHealth(client);
		GetClientAbsOrigin(client, position);
		if (GetEntProp(client, Prop_Data, "m_fFlags") & FL_ONFIRE && PlayerIsAlive(client))
			tankonfire = true;
	}
	
	if (GetConVarBool(h_CoopPlayableTank))
	{
		for (new t=1;t<=MaxClients;t++)
		{
			// We check if player is in game
			if (!IsClientInGame(t)) continue;
			
			// Check if client is infected ...
			if (GetClientTeam(t)!=TEAM_INFECTED) continue;
			
			if (!IsFakeClient(t))
			{
				// If player is not a tank, or a dead one
				if (!IsPlayerTank(t) || (IsPlayerTank(t) && !PlayerIsAlive(t)))
				{
					IndexCount++; // increase count of valid targets
					Index[IndexCount] = t; //save target to index
					#if DEBUGTANK
					PrintToChatAll("Client %i found to be valid Tank Choice", Index[IndexCount]);
					#endif
				}
			}	
		}
	}
	
	#if DEBUGTANK
	if (GetConVarBool(h_CoopPlayableTank))
	{
		
		PrintToChatAll("Valid Tank Candidates found: %i", IndexCount);
		
	}
	#endif
	
	if (GetConVarBool(h_CoopPlayableTank) && IndexCount != 0 )
	{
		MaxPlayerTank--;
		#if DEBUGTANK
		PrintToChatAll("Tank Kicked");
		#endif
		
		new tank = GetURandomIntRange(1, IndexCount);  // pick someone from the valid targets
		WillBeTank[Index[tank]] = true;
		
		#if DEBUGTANK
		PrintToChatAll("Random Number pulled: %i, from %i", tank, IndexCount);
		PrintToChatAll("Client chosen to be Tank: %i", Index[tank]);
		#endif
		
		ChangeClientTeam(Index[tank], TEAM_SPECTATOR);
		ChangeClientTeam(Index[tank], TEAM_INFECTED);
	}
	
	new bool:resetGhost[MAXPLAYERS+1];
	new bool:resetLife[MAXPLAYERS+1];
	
	if (GetConVarBool(h_CoopPlayableTank) && IndexCount != 0)
	{
		for (new i=1;i<=MaxClients;i++)
		{
			if ( IsClientInGame(i) && !IsFakeClient(i)) // player is connected and is not fake and it's in game ...
			{
				// If player is on infected's team and is dead ..
				if ((GetClientTeam(i)==TEAM_INFECTED) && WillBeTank[i] == false)
				{
					// If player is a ghost ....
					if (IsPlayerGhost(i))
					{
						resetGhost[i] = true;
						SetGhostStatus(i, false);
						#if DEBUGSERVER
						LogMessage("Player is a ghost, taking preventive measures to prevent the player from taking over the tank");
						#endif
					}
					else if (!PlayerIsAlive(i))
					{
						resetLife[i] = true;
						SetLifeState(i, false);
						#if DEBUGSERVER
						LogMessage("Dead player found, setting restrictions to prevent the player from taking over the tank");
						#endif
					}
				}
			}
		}
		
		// Find any human client and give client admin rights
		new anyclient = GetAnyClient();
		new bool:temp = false;
		if (anyclient == -1)
		{
			#if DEBUGSERVER
			LogMessage("[Infected bots] Creating temp client to fake command");
			#endif
			// we create a fake client
			anyclient = CreateFakeClient("Bot");
			if (!anyclient)
			{
				LogError("[L4D] Infected Bots: CreateFakeClient returned 0 -- Infected Tank was not spawned");
			}
			temp = true;
		}
		
		CheatCommand(anyclient, "z_spawn", "tank auto");
		
		
		/*if (GetConVarBool(h_CoopPlayableTank))
		{
		TankHalt = true;
		}
		
		// Start the Tank Halt Timer
		CreateTimer(2.0, TankHaltTimer, _, TIMER_FLAG_NO_MAPCHANGE);*/
		
		// We restore the player's status
		for (new i=1;i<=MaxClients;i++)
		{
			if (resetGhost[i] == true)
				SetGhostStatus(i, true);
			if (resetLife[i] == true)
				SetLifeState(i, true);
			if (WillBeTank[i] == true)
			{
				if (client)
				{
					TeleportEntity(i, position, NULL_VECTOR, NULL_VECTOR);
					SetEntityHealth(i, tankhealth);
					if (tankonfire)
						CreateTimer(0.1, PutTankOnFireTimer, i, TIMER_FLAG_NO_MAPCHANGE);
					if (GetConVarBool(h_CoopPlayableTank))
						TankWasSeen[i] = true;
				}
				WillBeTank[i] = false;
				DataPack datapack;
				CreateDataTimer(1.0, TankRespawner, datapack);
				WritePackCell(datapack, tankhealth);
				WritePackCell(datapack, tankonfire);
				WritePackCell(datapack, i);
			}
		}
		
		// If client was temp, we setup a timer to kick the fake player
		if (temp) CreateTimer(0.1,kickbot,anyclient);
		
		#if DEBUGTANK
		if (IsPlayerTank(client) && IsFakeClient(client))
		{
			PrintToChatAll("Bot Tank Spawn Event Triggered");
		}
		else if (IsPlayerTank(client) && !IsFakeClient(client))
		{
			PrintToChatAll("Human Tank Spawn Event Triggered");
		}
		#endif
	}
	
	MaxPlayerTank = MaxPlayerZombies;
	SetConVarInt(FindConVar("z_max_player_zombies"), MaxPlayerZombies);
}


Action TankRespawner(Handle timer, DataPack datapack)
{
	// This function is used to check if the tank successfully spawned, and if not, respawn him
	
	// Reset the data pack
	ResetPack(datapack);
	
	new tankhealth = ReadPackCell(datapack);
	new tankonfire = ReadPackCell(datapack);
	new client = ReadPackCell(datapack);
	
	if (IsClientInGame(client) && IsFakeClient(client) && IsPlayerTank(client) && PlayerIsAlive(client))
	{
		CreateTimer(0.1, kickbot, client);
		return Plugin_Continue;
	}
	
	if (IsPlayerTank(client) && PlayerIsAlive(client))
		return Plugin_Continue;
	
	WillBeTank[client] = true;
	
	new bool:resetGhost[MAXPLAYERS+1];
	new bool:resetLife[MAXPLAYERS+1];
	
	for (new i=1;i<=MaxClients;i++)
	{
		if ( IsClientInGame(i) && !IsFakeClient(i)) // player is connected and is not fake and it's in game ...
		{
			// If player is on infected's team and is dead ..
			if ((GetClientTeam(i)==TEAM_INFECTED) && WillBeTank[i] == false)
			{
				// If player is a ghost ....
				if (IsPlayerGhost(i))
				{
					resetGhost[i] = true;
					SetGhostStatus(i, false);
					#if DEBUGSERVER
					LogMessage("Player is a ghost, taking preventive measures to prevent the player from taking over the tank");
					#endif
				}
				else if (!PlayerIsAlive(i))
				{
					resetLife[i] = true;
					SetLifeState(i, false);
					#if DEBUGSERVER
					LogMessage("Dead player found, setting restrictions to prevent the player from taking over the tank");
					#endif
				}
			}
		}
	}
	
	// Find any human client and give client admin rights
	new anyclient = GetAnyClient();
	new bool:temp = false;
	if (anyclient == -1)
	{
		#if DEBUGSERVER
		LogMessage("[Infected bots] Creating temp client to fake command");
		#endif
		// we create a fake client
		anyclient = CreateFakeClient("Bot");
		if (!anyclient)
		{
			LogError("[L4D] Infected Bots: CreateFakeClient returned 0 -- Infected Tank was not spawned");
		}
		temp = true;
	}
	
	CheatCommand(anyclient, "z_spawn", "tank auto");
	
	
	/*if (GetConVarBool(h_CoopPlayableTank))
	{
	TankHalt = true;
	}
	
	// Start the Tank Halt Timer
	CreateTimer(2.0, TankHaltTimer, _, TIMER_FLAG_NO_MAPCHANGE);*/
	
	// We restore the player's status
	for (new i=1;i<=MaxClients;i++)
	{
		if (resetGhost[i] == true)
			SetGhostStatus(i, true);
		if (resetLife[i] == true)
			SetLifeState(i, true);
		if (WillBeTank[i] == true)
		{
			if (client)
			{
				SetEntityHealth(i, tankhealth);
				if (tankonfire)
					CreateTimer(0.1, PutTankOnFireTimer, i, TIMER_FLAG_NO_MAPCHANGE);
				if (GetConVarBool(h_CoopPlayableTank))
					TankWasSeen[i] = true;
			}
			WillBeTank[i] = false;
			DataPack datapack2;
			CreateDataTimer(1.0, TankRespawner, datapack2);
			WritePackCell(datapack2, tankhealth);
			WritePackCell(datapack2, tankonfire);
			WritePackCell(datapack2, i);
		}
	}
	
	// If client was temp, we setup a timer to kick the fake player
	if (temp) CreateTimer(0.1,kickbot,anyclient);

	return Plugin_Continue;
}

public Action:TankBugFix(Handle:timer, any:client)
{
	#if DEBUGTANK
	LogMessage("Tank BugFix Triggred");
	#endif
	decl Float:position[3];
	new tankhealth;
	new bool:tankonfire;
	
	if (client && IsClientInGame(client))
	{
		tankhealth = GetClientHealth(client);
		GetClientAbsOrigin(client, position);
		if (GetEntProp(client, Prop_Data, "m_fFlags") & FL_ONFIRE && PlayerIsAlive(client))
			tankonfire = true;
	}
	
	
	new bool:resetGhost[MAXPLAYERS+1];
	new bool:resetLife[MAXPLAYERS+1];
	
	
	for (new i=1;i<=MaxClients;i++)
	{
		if ( IsClientInGame(i) && !IsFakeClient(i)) // player is connected and is not fake and it's in game ...
		{
			// If player is on infected's team and is dead ..
			if (GetClientTeam(i)==TEAM_INFECTED)
			{
				// If player is a ghost ....
				if (IsPlayerGhost(i))
				{
					resetGhost[i] = true;
					SetGhostStatus(i, false);
					#if DEBUGSERVER
					LogMessage("Player is a ghost, taking preventive measures to prevent the player from taking over the tank");
					#endif
				}
				else if (!PlayerIsAlive(i))
				{
					resetLife[i] = true;
					SetLifeState(i, false);
					#if DEBUGSERVER
					LogMessage("Dead player found, setting restrictions to prevent the player from taking over the tank");
					#endif
				}
			}
		}
	}
	
	// Find any human client and give client admin rights
	new anyclient = GetAnyClient();
	new bool:temp = false;
	if (anyclient == -1)
	{
		#if DEBUGSERVER
		LogMessage("[Infected bots] Creating temp client to fake command");
		#endif
		// we create a fake client
		anyclient = CreateFakeClient("Bot");
		if (!anyclient)
		{
			LogError("[L4D] Infected Bots: CreateFakeClient returned 0 -- Infected Tank was not spawned");
		}
		temp = true;
	}
	
	new bot = CreateFakeClient("Infected Bot");
	if (bot != 0)
		ChangeClientTeam(bot,TEAM_INFECTED);
	
	CheatCommand(anyclient, "z_spawn", "tank auto");
	
	// We restore the player's status
	for (new i=1;i<=MaxClients;i++)
	{
		if (resetGhost[i] == true)
			SetGhostStatus(i, true);
		if (resetLife[i] == true)
			SetLifeState(i, true);
	}
	
	
	TeleportEntity(bot, position, NULL_VECTOR, NULL_VECTOR);
	SetEntityHealth(bot, tankhealth);
	if (tankonfire)
		CreateTimer(0.1, PutTankOnFireTimer, bot, TIMER_FLAG_NO_MAPCHANGE);
	
	DataPack datapack;
	CreateDataTimer(1.0, TankRespawner, datapack);
	WritePackCell(datapack, tankhealth);
	WritePackCell(datapack, tankonfire);
	WritePackCell(datapack, bot);
	
	// If client was temp, we setup a timer to kick the fake player
	if (temp) CreateTimer(0.1,kickbot,anyclient);
	
	#if DEBUGTANK
	if (IsPlayerTank(client) && IsFakeClient(client))
	{
		PrintToChatAll("Bot Tank Spawn Event Triggered");
	}
	else if (IsPlayerTank(client) && !IsFakeClient(client))
	{
		PrintToChatAll("Human Tank Spawn Event Triggered");
	}
	#endif
	
	
	MaxPlayerTank = MaxPlayerZombies;
	SetConVarInt(FindConVar("z_max_player_zombies"), MaxPlayerZombies);
}

public Action:PutTankOnFireTimer(Handle:Timer, any:client)
{
	IgniteEntity(client, 9999.0);
}

public Action:HookSound_Callback(Clients[64], &NumClients, String:StrSample[PLATFORM_MAX_PATH], &Entity, &channel, &Float:volume, &level, &pitch, &flags)
{
	if (GameMode != 1 || !GetConVarBool(h_CoopPlayableTank))
		return Plugin_Continue;
	
	//to work only on tank steps, its Tank_walk
	if (StrContains(StrSample, "Tank_walk", false) == -1) return Plugin_Continue;
	
	for (new i=1;i<=MaxClients;i++)
	{
		// We check if player is in game
		if (!IsClientInGame(i)) continue;
		
		// Check if client is infected ...
		if (GetClientTeam(i)==TEAM_INFECTED)
		{
			// If player is a tank
			if (IsPlayerTank(i) && PlayerIsAlive(i) && TankWasSeen[i] == false)
			{
				if (RealPlayersOnInfected() && AreTherePlayersWhoAreNotTanks())
				{
					CreateTimer(0.2, kickbot, i);
					CreateTimer(0.1, TankSpawner, i);
				}
			}
		}
	}
	return Plugin_Continue;
}


// This event serves to make sure the bots spawn at the start of the finale event. The director disallows spawning until the survivors have started the event, so this was
// definitely needed.
public void evtFinaleStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(FinaleStarted) return;

 	FinaleStarted = true;
	CreateTimer(1.0, CheckIfBotsNeededLater, true);
}

// This code was to fix an unintentional bug in Left 4 Dead. If it is coop, and the finale started with the survivors lost, the screen will stay stuck looking at the 
// finale and would not move at all. The only way to fix this is to either change the map, or spawn the infected as ghosts...which I have done here. However, if free 
// spawning is off, it will make the infected spawn normal again after the first spawn. (L4D 1 only)

// L4D2 Notes: This bug has been fixed.
public Action:evtMissionLost(Handle:event, const String:name[], bool:dontBroadcast)
{
	for (new i=1;i<=MaxClients;i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i)) // player is connected and is not fake and it's in game ...
		{
			// If player is on infected's team
			if (GetClientTeam(i)==TEAM_INFECTED)
			{
				if (FinaleStarted)
				{
					#if DEBUGSERVER
					LogMessage("Mission lost on the finale");
					#endif
				}
				respawnDelay[i] = 0;
			}
		}
	}
}

BotTypeNeeded()
{
	#if DEBUGSERVER
	LogMessage("Determining Bot type now");
	#endif
	#if DEBUGCLIENTS
	PrintToChatAll("Determining Bot type now");
	#endif
	
	// current count ...
	new boomers=0;
	new smokers=0;
	new hunters=0;
	new tanks=0;
	new witches=0;
	new entity = -1;
	
	while ( ((entity = FindEntityByClassname(entity, "witch")) != -1) )
	{
		witches++;
	}
	
	for (new i=1;i<=MaxClients;i++)
	{
		// if player is connected and ingame ...
		if (IsClientInGame(i))
		{
			// if player is on infected's team
			if (GetClientTeam(i) == TEAM_INFECTED && PlayerIsAlive(i))
			{
				// We count depending on class ...
				if (IsPlayerSmoker(i))
					smokers++;
				else if (IsPlayerBoomer(i))
					boomers++;	
				else if (IsPlayerHunter(i))
					hunters++;	
				else if (IsPlayerTank(i))
					tanks++;
			}
		}
	}
	

	new random = GetURandomIntRange(1, 5);
	
	new i=0;
	while(i++<5)
	{
		if (random == 1)
		{
			if (hunters < HunterLimit && g_hSpawnColdDownTimer[SI_HUNTER] == null)
			{
				return 1;
			}
			random++;
		}
		if (random == 2)
		{
			if ((smokers < SmokerLimit) && g_hSpawnColdDownTimer[SI_SMOKER] == null) // we need a smoker ???? can we spawn a smoker ??? is smoker bot allowed ??
			{
				return 2;
			}
			random++;
		}
		if (random == 3)
		{
			if ((boomers < BoomerLimit) && g_hSpawnColdDownTimer[SI_BOOMER] == null)
			{
				return 3;
			}
			random=1;
		}
		if (random == 4)
		{
			new random2 = GetURandomIntRange(1, 3);
			
			if (tanks < GetConVarInt(h_TankLimit) && random2 == 1)
			{
				return 7;
			}
			else if(random2 == 2)
				random++;
			else
				random = GetURandomIntRange(1, 3);
		}
		if (random == 5)
		{
			if (witches < GetConVarInt(h_WitchLimit))
			{
				return 8;
			}
		}
	}
	return 0;
}


public Action:Spawn_InfectedBot(Handle:timer)
{
	// If round has ended, we ignore this request ...
	if (b_HasRoundEnded || !b_HasRoundStarted || !b_LeftSaveRoom) return;
	
	new Infected = MaxPlayerZombies;
	
	if (GetConVarBool(h_Coordination) && !DirectorSpawn && !InitialSpawn && !PlayerReady())
	{
		BotReady++;
		
		for (new i=1;i<=MaxClients;i++)
		{
			// We check if player is in game
			if (!IsClientInGame(i)) continue;
			
			// Check if client is infected ...
			if (GetClientTeam(i)==TEAM_INFECTED)
			{
				// If player is a real player 
				if (!IsFakeClient(i))
					Infected--;
			}
		}
		
		if (BotReady >= Infected)
		{
			CreateTimer(3.0, BotReadyReset, _, TIMER_FLAG_NO_MAPCHANGE);
		}
		else
		{
			InfectedBotQueue--;
			return;
		}
	}
	
	// First we get the infected count
	if (GameMode == 2)
	{
		CountInfected();
	}
	else
	{
		CountInfected_Coop();
	}
	// If infected's team is already full ... we ignore this request (a real player connected after timer started ) ..
	if ((InfectedRealCount + InfectedBotCount) >= MaxPlayerZombies || (InfectedRealCount + InfectedBotCount + InfectedBotQueue) > MaxPlayerZombies) 	
	{
		#if DEBUGSERVER
		LogMessage("We found a player, don't spawn a bot");
		#endif
		InfectedBotQueue--;
		return;
	}
	
	// If there is a tank on the field and l4d_infectedbots_spawns_disable_tank is set to 1, the plugin will check for
	// any tanks on the field
	
	if (GetConVarBool(h_DisableSpawnsTank))
	{
		for (new i=1;i<=MaxClients;i++)
		{
			// We check if player is in game
			if (!IsClientInGame(i)) continue;
			
			// Check if client is infected ...
			if (GetClientTeam(i)==TEAM_INFECTED)
			{
				// If player is a tank
				if (IsPlayerTank(i) && IsPlayerAlive(i))
				{
					InfectedBotQueue--;
					return;
				}
			}
		}
		
	}
	
	// Before spawning the bot, we determine if an real infected player is dead, since the new infected bot will be controlled by this player
	new bool:resetGhost[MAXPLAYERS+1];
	new bool:resetLife[MAXPLAYERS+1];
	
	for (new i=1;i<=MaxClients;i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i)) // player is connected and is not fake and it's in game ...
		{
			// If player is on infected's team and is dead ..
			if (GetClientTeam(i) == TEAM_INFECTED)
			{
				// If player is a ghost ....
				if (IsPlayerGhost(i))
				{
					resetGhost[i] = true;
					SetGhostStatus(i, false);
					#if DEBUGSERVER
					LogMessage("Player is a ghost, taking preventive measures for spawning an infected bot");
					#endif
				}
				else if (!PlayerIsAlive(i) && GameMode == 2) // if player is just dead
				{
					resetLife[i] = true;
					SetLifeState(i, false);
				}
				else if (!PlayerIsAlive(i) && respawnDelay[i] > 0)
				{
					//resetLife[i] = true;
					//SetLifeState(i, false);
					#if DEBUGSERVER
					LogMessage("Found a dead player, spawn time has not reached zero, delaying player to Spawn an infected bot");
					#endif
				}
				else if (!PlayerIsAlive(i) && respawnDelay[i] <= 0)
				{
					AlreadyGhosted[i] = false;
					SetLifeState(i, true);
				}
			}
		}
	}
	
	// We get any client ....
	new anyclient = GetAnyClient();
	new bool:temp = false;
	if (anyclient == -1)
	{
		#if DEBUGSERVER
		LogMessage("[Infected bots] Creating temp client to fake command");
		#endif
		// we create a fake client
		anyclient = CreateFakeClient("Bot");
		if (!anyclient)
		{
			LogError("[L4D] Infected Bots: CreateFakeClient returned 0 -- Infected bot was not spawned");
			return;
		}
		temp = true;
	}
	
	// Determine the bot class needed ...
	new bot_type = BotTypeNeeded();
	
 	// We spawn the bot ...
	switch (bot_type)
	{
		case 0: // Nothing
		{
			#if DEBUGSERVER
			LogMessage("Bot_type returned NOTHING!");
			#endif
		}
		case 1: // Hunter
		{
			#if DEBUGSERVER
			LogMessage("Spawning Hunter");
			#endif
			#if DEBUGCLIENTS
			PrintToChatAll("Spawning Hunter");
			#endif
			CheatCommand(anyclient, "z_spawn", "hunter auto");
		}
		case 2: // Smoker
		{	
			#if DEBUGSERVER
			LogMessage("Spawning Smoker");
			#endif
			#if DEBUGCLIENTS
			PrintToChatAll("Spawning Smoker");
			#endif
			CheatCommand(anyclient, "z_spawn", "smoker auto");
		}
		case 3: // Boomer
		{
			#if DEBUGSERVER
			LogMessage("Spawning Boomer");
			#endif
			#if DEBUGCLIENTS
			PrintToChatAll("Spawning Boomer");
			#endif
			CheatCommand(anyclient, "z_spawn", "boomer auto");
		}
		case 7: // Tank
		{
			#if DEBUGSERVER
			LogMessage("Spawning Tank");
			#endif
			#if DEBUGCLIENTS
			PrintToChatAll("Spawning Tank");
			#endif
			CheatCommand(anyclient, "z_spawn", "tank auto");
		}
	}
	
	// We restore the player's status
	for (new i=1;i<=MaxClients;i++)
	{
		if (resetGhost[i] == true)
			SetGhostStatus(i, true);
		if (resetLife[i] == true)
			SetLifeState(i, true);
	}
	
	// If client was temp, we setup a timer to kick the fake player
	if (temp) CreateTimer(0.1,kickbot,anyclient);
	
	// Debug print
	#if DEBUGCLIENTS
	PrintToChatAll("Spawning an infected bot. Type = %i ", bot_type);
	#endif
	
	// We decrement the infected queue
	InfectedBotQueue--;
	
	CreateTimer(1.0, CheckIfBotsNeededLater, true);
}

stock GetAnyClient() 
{ 
	for (new target = 1; target <= MaxClients; target++) 
	{ 
		if (IsClientInGame(target)) return target; 
	} 
	return -1; 
} 

public Action:kickbot(Handle:timer, any:client)
{
	if (IsClientInGame(client) && (!IsClientInKickQueue(client)))
	{
		if (IsFakeClient(client)) KickClient(client);
	}
}

bool:IsPlayerGhost (client)
{
	if (GetEntProp(client, Prop_Send, "m_isGhost"))
		return true;
	return false;
}

bool:PlayerIsAlive (client)
{
	if (!GetEntProp(client,Prop_Send, "m_lifeState"))
		return true;
	return false;
}

bool:IsPlayerSmoker (client)
{
	if(GetEntProp(client,Prop_Send,"m_zombieClass") == ZOMBIECLASS_SMOKER)
		return true;
	return false;
}

bool:IsPlayerBoomer (client)
{
	if(GetEntProp(client,Prop_Send,"m_zombieClass") == ZOMBIECLASS_BOOMER)
		return true;
	return false;
}

bool:IsPlayerHunter (client)
{
	if(GetEntProp(client,Prop_Send,"m_zombieClass") == ZOMBIECLASS_HUNTER)
		return true;
	return false;
}

bool:IsPlayerTank (client)
{
	if(GetEntProp(client,Prop_Send,"m_zombieClass") == ZOMBIECLASS_TANK)
		return true;
	return false;
}

SetGhostStatus (client, bool:ghost)
{
	if (ghost)
		SetEntProp(client, Prop_Send, "m_isGhost", 1);
	else
	SetEntProp(client, Prop_Send, "m_isGhost", 0);
}

SetLifeState (client, bool:ready)
{
	if (ready)
		SetEntProp(client, Prop_Send,  "m_lifeState", 1);
	else
	SetEntProp(client, Prop_Send, "m_lifeState", 0);
}

bool:RealPlayersOnSurvivors ()
{
	for (new i=1;i<=MaxClients;i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
			if (GetClientTeam(i) == TEAM_SURVIVORS)
				return true;
		}
	return false;
}

TrueNumberOfSurvivors ()
{
	new TotalSurvivors;
	for (new i=1;i<=MaxClients;i++)
	{
		if (IsClientInGame(i))
			if (GetClientTeam(i) == TEAM_SURVIVORS)
				TotalSurvivors++;
		}
	return TotalSurvivors;
}

HumansOnInfected ()
{
	new TotalHumans;
	for (new i=1;i<=MaxClients;i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == TEAM_INFECTED && !IsFakeClient(i))
			TotalHumans++;
	}
	return TotalHumans;
}

bool:AllSurvivorsDeadOrIncapacitated ()
{
	new PlayerIncap;
	new PlayerDead;
	
	for (new i=1;i<=MaxClients;i++)
	{
		if (IsClientInGame(i) && IsFakeClient(i))
			if (GetClientTeam(i) == TEAM_SURVIVORS)
		{
			if (GetEntProp(i, Prop_Send, "m_isIncapacitated"))
			{
				PlayerIncap++;
			}
			else if (!PlayerIsAlive(i))
			{
				PlayerDead++;
			}
		}
	}
	
	if (PlayerIncap + PlayerDead == TrueNumberOfSurvivors())
	{
		return true;
	}
	return false;
}

bool:RealPlayersOnInfected ()
{
	for (new i=1;i<=MaxClients;i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
			if (GetClientTeam(i) == TEAM_INFECTED)
				return true;
		}
	return false;
}

bool:AreTherePlayersWhoAreNotTanks ()
{
	for (new i=1;i<=MaxClients;i++)
	{	
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			if (GetClientTeam(i) == TEAM_INFECTED)
			{
				if (!IsPlayerTank(i) || IsPlayerTank(i) && !PlayerIsAlive(i))
					return true;
			}
		}
	}
	return false;
}

bool:BotsAlive ()
{
	for (new i=1;i<=MaxClients;i++)
	{
		if (IsClientInGame(i) && IsFakeClient(i))
			if (GetClientTeam(i) == TEAM_INFECTED)
				return true;
		}
	return false;
}

PlayerReady()
{
	// First we count the ammount of infected real players
	for (new i=1;i<=MaxClients;i++)
	{
		// We check if player is in game
		if (!IsClientInGame(i)) continue;
		
		// Check if client is infected ...
		if (GetClientTeam(i) == TEAM_INFECTED)
		{
			// If player is a real player and is dead...
			if (!IsFakeClient(i) && !PlayerIsAlive(i))
			{
				if (!respawnDelay[i])
				{
					return true;
				}
			}
		}
	}
	return false;
}

FindBotToTakeOver()
{
	// First we find a survivor bot
	for (new i=1;i<=MaxClients;i++)
	{
		// We check if player is in game
		if (!IsClientInGame(i)) continue;
		
		// Check if client is survivor ...
		if (GetClientTeam(i) == TEAM_SURVIVORS)
		{
			// If player is a bot and is alive...
			if (IsFakeClient(i) && PlayerIsAlive(i))
			{
				return i;
			}
		}
	}
	return 0;
}

bool:LeftStartArea()
{
	
	new ent = -1, maxents = GetMaxEntities();
	for (new i = MaxClients+1; i <= maxents; i++)
	{
		if (IsValidEntity(i))
		{
			decl String:netclass[64];
			GetEntityNetClass(i, netclass, sizeof(netclass));
			
			if (StrEqual(netclass, "CTerrorPlayerResource"))
			{
				ent = i;
				break;
			}
		}
	}
	
	if (ent > -1)
	{
		if (GetEntProp(ent, Prop_Send, "m_hasAnySurvivorLeftSafeArea"))
		{
			return true;
		}
	}
	return false;
}

//---------------------------------------------Durzel's HUD------------------------------------------

public OnPluginEnd()
{
	ResetConVar(FindConVar("holdout_max_smokers"), true, true);
	ResetConVar(FindConVar("holdout_max_boomers"), true, true);
	ResetConVar(FindConVar("holdout_max_hunters"), true, true);
	ResetConVar(FindConVar("holdout_max_specials"), true, true);
	ResetConVar(FindConVar("z_gas_limit"), true, true);
	ResetConVar(FindConVar("z_exploding_limit"), true, true);
	ResetConVar(FindConVar("z_hunter_limit"), true, true);

	ResetConVar(FindConVar("director_no_specials"), true, true);
	ResetConVar(h_MaxPlayerZombies, true, true);
	ResetConVar(FindConVar("z_tank_health"), true, true);
	ResetConVar(FindConVar("vs_max_team_switches"), true, true);
		
	//ResetConVar(FindConVar("z_max_player_zombies"), true, true);
	
	ResetConVar(FindConVar("sb_all_bot_team"), true, true);
	
	// Destroy the persistent storage for client HUD preferences
	if (usrHUDPref != INVALID_HANDLE)
	{
		CloseHandle(usrHUDPref);
	}
	
	SetConVarInt(h_HunterLimit, 0);
	SetConVarInt(h_SmokerLimit, 0);
	SetConVarInt(h_BoomerLimit, 0);
	
	#if DEBUGHUD
	PrintToChatAll("\x01\x04[infhud]\x01 [%f] \x03Infected HUD\x01 stopped.", GetGameTime());
	#endif
}

public Menu_InfHUDPanel(Handle:menu, MenuAction:action, param1, param2) { return; }

public Action:TimerAnnounce(Handle:timer, any:client)
{
	if (IsClientInGame(client))
	{
		if (GetClientTeam(client) == TEAM_INFECTED)
		{
			// Show welcoming instruction message to client
			PrintHintText(client, "This server runs \x03Infected Bots v%s\x01 - say !infhud to toggle HUD on/off", PLUGIN_VERSION);
			
			// This client now knows about the mod, don't tell them again for the rest of the game.
			clientGreeted[client] = 1;
		}
	}
}

public cvarZombieHPChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	// Handle a sysadmin modifying the special infected max HP cvars
	decl String:cvarStr[255], String:difficulty[100];
	GetConVarName(convar, cvarStr, sizeof(cvarStr));
	GetConVarString(h_Difficulty, difficulty, sizeof(difficulty));
	
	#if DEBUGHUD
	PrintToChatAll("\x01\x04[infhud]\x01 [%f] cvarZombieHPChanged(): Infected HP cvar '%s' changed from '%s' to '%s'", GetGameTime(), cvarStr, oldValue, newValue);
	#endif
	
	if (StrEqual(cvarStr, "z_hunter_health", false))
	{
		zombieHP[0] = StringToInt(newValue);
	}
	else if (StrEqual(cvarStr, "z_smoker_health", false))
	{
		zombieHP[1] = StringToInt(newValue);
	}
	else if (StrEqual(cvarStr, "z_boomer_health", false))
	{
		zombieHP[2] = StringToInt(newValue);
	}
	else if (StrEqual(cvarStr, "z_tank_health", false) && GameMode == 2)
	{
		zombieHP[6] = RoundToFloor(StringToInt(newValue) * 1.5);	// Tank health is multiplied by 1.5x in VS
	}
	else if (StrEqual(cvarStr, "z_tank_health", false) && GameMode != 2 && StrContains(difficulty, "Easy", false) != -1)
	{
		zombieHP[6] = RoundToFloor(StringToInt(newValue) * 0.75);
	}
	else if (StrEqual(cvarStr, "z_tank_health", false) && GameMode != 2 && StrContains(difficulty, "Normal", false) != -1)
	{
		zombieHP[6] = RoundToFloor(StringToInt(newValue) * 1.0);
	}
	else if (StrEqual(cvarStr, "z_tank_health", false) && GameMode != 2 && StrContains(difficulty, "Hard", false) != -1)
	{
		zombieHP[6] = RoundToFloor(StringToInt(newValue) * 2.0);
	}
	else if (StrEqual(cvarStr, "z_tank_health", false) && GameMode != 2 && StrContains(difficulty, "Impossible", false) != -1)
	{
		zombieHP[6] = RoundToFloor(StringToInt(newValue) * 2.0);
	}
}

public Action:monitorRespawn(Handle:timer)
{
	// Counts down any active respawn timers
	new foundActiveRTmr = false;
	
	// If round has ended then end timer gracefully
	if (!roundInProgress)
	{
		respawnTimer = INVALID_HANDLE;
		return Plugin_Stop;
	}
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (respawnDelay[i] > 0)
		{
			respawnDelay[i]--;
			foundActiveRTmr = true;
		}
	}
	
	if (!foundActiveRTmr && (respawnTimer != INVALID_HANDLE))
	{
		// Being a ghost doesn't trigger an event which we can hook (player_spawn fires when player actually spawns),
		// so as a nasty kludge after the respawn timer expires for at least one player we set a timer for 1 second 
		// to update the HUD so it says "SPAWNING"
		if (delayedDmgTimer == INVALID_HANDLE)
		{
			delayedDmgTimer = CreateTimer(1.0, delayedDmgUpdate, _, TIMER_FLAG_NO_MAPCHANGE);
		}
		
		// We didn't decrement any of the player respawn times, therefore we don't 
		// need to run this timer anymore.
		respawnTimer = INVALID_HANDLE;
		return Plugin_Stop;
	}
	else
	{
		if (doomedTankTimer == INVALID_HANDLE) ShowInfectedHUD(2);
	}
	return Plugin_Continue;
}

public Action:doomedTankCountdown(Handle:timer)
{
	// If round has ended then end timer gracefully
	if (!roundInProgress)
	{
		doomedTankTimer = INVALID_HANDLE;
		return Plugin_Stop;
	}
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || GetClientTeam(i)!=3 || !IsPlayerTank(i))
			continue;
		
		// Counts down the number of seconds before the Tank will die automatically
		// from fire damage (if not before from gun damage)
		if (isTankOnFire[i] == true)
		{
			if (--burningTankTimeLeft[i] < 1)
			{
				// Tank is dead :(
				#if DEBUGHUD
				PrintToChatAll("\x01\x04[infhud]\x01 [%f] Tank died automatically from fire timer expiry.", GetGameTime());
				#endif
				isTankOnFire[i] = false;
				if (!CheckForTanksOnFire())
				{
					doomedTankTimer = INVALID_HANDLE;
					return Plugin_Stop;
				}
			}
			else
			{
				// This is almost the same as the respawnTimer code (which only updates the HUD in one of the two 1-second update
				// timer functions, however there may well be an instance in the game where both the Tank is on fire, and people are
				// respawning - therefore we need to make sure *at least one* of the 1-second timers updates the HUD, so we choose this
				// one (as it's rarer in game and therefore more optimal to do two extra code checks to achieve the same result).
				if (respawnTimer == INVALID_HANDLE || (doomedTankTimer != INVALID_HANDLE && respawnTimer != INVALID_HANDLE))
				{
					ShowInfectedHUD(4);
				}
			}
		}
	}
	
	return Plugin_Continue;
}

public Action:delayedDmgUpdate(Handle:timer) 
{
	delayedDmgTimer = INVALID_HANDLE;
	ShowInfectedHUD(3);
	return Plugin_Handled;
}

public queueHUDUpdate(src)
{
	// queueHUDUpdate basically ensures that we're not constantly refreshing the HUD when there are one or more
	// timers active.  For example, if we have a respawn countdown timer (which is likely at any given time) then
	// there is no need to refresh 
	
	// Don't bother with infected HUD updates if the round has ended.
	if (!roundInProgress) return;
	
	if (respawnTimer == INVALID_HANDLE && doomedTankTimer == INVALID_HANDLE)
	{
		ShowInfectedHUD(src);
		#if DEBUGHUD
	}
	else
	{
		PrintToChatAll("\x01\x04[infhud]\x01 [%f] queueHUDUpdate(): Instant HUD update ignored, 1-sec timer active.", GetGameTime());
		#endif
	}	
}

public Action:showInfHUD(Handle:timer) 
{
	if (roundInProgress)
	{
		ShowInfectedHUD(1);
		return Plugin_Continue;
	}
	else
	{
		infHUDTimer = INVALID_HANDLE;
		return Plugin_Continue;
	}		
}

public Action:Command_Say(client, args)
{
	decl String:clientSteamID[32];
//	GetClientAuthString(client, clientSteamID, 32);
	
	if (GetConVarBool(h_InfHUD))
	{
		if (!hudDisabled[client])
		{
			PrintToChat(client, "\x01\x04[infhud]\x01 Infected HUD DISABLED - say !infhud to re-enable.");
			SetTrieValue(usrHUDPref, clientSteamID, 1);
			hudDisabled[client] = true;
		}
		else
		{
			PrintToChat(client, "\x01\x04[infhud]\x01 Infected HUD ENABLED - say !infhud to disable.");
			RemoveFromTrie(usrHUDPref, clientSteamID);
			hudDisabled[client] = false;
		}
	}
	else
	{
		// Server admin has disabled Infected HUD server-wide
		PrintToChat(client, "\x01\x04[infhud]\x01 Infected HUD is currently DISABLED on this server for all players.");
	}	
	return Plugin_Handled;
}

public ShowInfectedHUD(src)
{
	if ((!GetConVarBool(h_InfHUD)) || IsVoteInProgress())
	{
		return;
	}
	
	// If no bots are alive, no point in showing the HUD
	if (!BotsAlive())
	{
		return;
	}
	
	#if DEBUGHUD
	decl String:calledFunc[255];
	switch (src)
	{
		case 1: strcopy(calledFunc, sizeof(calledFunc), "showInfHUD");
		case 2: strcopy(calledFunc, sizeof(calledFunc), "monitorRespawn");
		case 3: strcopy(calledFunc, sizeof(calledFunc), "delayedDmgUpdate");
		case 4: strcopy(calledFunc, sizeof(calledFunc), "doomedTankCountdown");
		case 10: strcopy(calledFunc, sizeof(calledFunc), "queueHUDUpdate - client join");
		case 11: strcopy(calledFunc, sizeof(calledFunc), "queueHUDUpdate - team switch");
		case 12: strcopy(calledFunc, sizeof(calledFunc), "queueHUDUpdate - spawn");
		case 13: strcopy(calledFunc, sizeof(calledFunc), "queueHUDUpdate - death");
		case 14: strcopy(calledFunc, sizeof(calledFunc), "queueHUDUpdate - menu closed");
		case 15: strcopy(calledFunc, sizeof(calledFunc), "queueHUDUpdate - player kicked");
		case 16: strcopy(calledFunc, sizeof(calledFunc), "evtRoundEnd");
		default: strcopy(calledFunc, sizeof(calledFunc), "UNKNOWN");
	}
	
	PrintToChatAll("\x01\x04[infhud]\x01 [%f] ShowInfectedHUD() called by [\x04%i\x01] '\x03%s\x01'", GetGameTime(), src, calledFunc);
	#endif 
	
	new i, iHP;
	decl String:iClass[100], String:lineBuf[100], String:iStatus[15];
	
	// Display information panel to infected clients
	pInfHUD = CreatePanel(GetMenuStyleHandle(MenuStyle_Radio));
	if (GameMode == 2)
		SetPanelTitle(pInfHUD, "INFECTED BOTS:");
	else
	SetPanelTitle(pInfHUD, "INFECTED TEAM:");
	DrawPanelItem(pInfHUD, " ", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);
	
	if (roundInProgress)
	{
		// Loop through infected players and show their status
		for (i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i)) continue;
			if (IsFakeClient(i) || (GameMode != 2 && !IsFakeClient(i)))
			{
				if (GetClientTeam(i) == TEAM_INFECTED)
				{
					// Work out what they're playing as
					if (IsPlayerHunter(i))
					{
						strcopy(iClass, sizeof(iClass), "Hunter");
						iHP = RoundFloat((float(GetClientHealth(i)) / zombieHP[0]) * 100);
					}
					else if (IsPlayerSmoker(i))
					{
						strcopy(iClass, sizeof(iClass), "Smoker");
						iHP = RoundFloat((float(GetClientHealth(i)) / zombieHP[1]) * 100);
					}
					else if (IsPlayerBoomer(i))
					{
						strcopy(iClass, sizeof(iClass), "Boomer");
						iHP = RoundFloat((float(GetClientHealth(i)) / zombieHP[2]) * 100);
					}
					else if (IsPlayerTank(i))
					{
						strcopy(iClass, sizeof(iClass), "Tank");
						iHP = RoundFloat((float(GetClientHealth(i)) / GetEntProp(i, Prop_Data, "m_iMaxHealth")) * 100);	
					}
					
					if (PlayerIsAlive(i))
					{
						// Check to see if they are a ghost or not
						if (IsPlayerGhost(i))
						{
							strcopy(iStatus, sizeof(iStatus), "GHOST");
						}
						else Format(iStatus, sizeof(iStatus), "%i%%", iHP);
					}
					else
					{
						if (respawnDelay[i] > 0 && !DirectorSpawn)
						{
							Format(iStatus, sizeof(iStatus), "DEAD (%i)", respawnDelay[i]);
							strcopy(iClass, sizeof(iClass), "");
							// As a failsafe if they're dead/waiting set HP to 0
							iHP = 0;
						} 
						else if (respawnDelay[i] == 0 && GameMode != 2 && !DirectorSpawn)
						{
							Format(iStatus, sizeof(iStatus), "READY");
							strcopy(iClass, sizeof(iClass), "");
							// As a failsafe if they're dead/waiting set HP to 0
							iHP = 0;
						}
						else if (respawnDelay[i] > 0 && DirectorSpawn && GameMode != 2)
						{
							Format(iStatus, sizeof(iStatus), "DELAY (%i)", respawnDelay[i]);
							strcopy(iClass, sizeof(iClass), "");
							// As a failsafe if they're dead/waiting set HP to 0
							iHP = 0;
						} 
						else if (respawnDelay[i] == 0 && DirectorSpawn && GameMode != 2)
						{
							Format(iStatus, sizeof(iStatus), "WAITING");
							strcopy(iClass, sizeof(iClass), "");
							// As a failsafe if they're dead/waiting set HP to 0
							iHP = 0;
						}
						else
						{
							Format(iStatus, sizeof(iStatus), "DEAD");
							strcopy(iClass, sizeof(iClass), "");
							// As a failsafe if they're dead/waiting set HP to 0
							iHP = 0;
						}
					}
					
					// Special case - if player is Tank and on fire, show the countdown
					if (StrContains(iClass, "Tank", false) != -1 && isTankOnFire[i] && PlayerIsAlive(i))
					{
						Format(iStatus, sizeof(iStatus), "%s-FIRE(%i)", iStatus, burningTankTimeLeft[i]);
					}
					
					if (IsFakeClient(i))
					{
						Format(lineBuf, sizeof(lineBuf), "%N-%s", i, iStatus);
						DrawPanelItem(pInfHUD, lineBuf);
					}
					else
					{
						Format(lineBuf, sizeof(lineBuf), "%N-%s-%s", i, iClass, iStatus);
						DrawPanelItem(pInfHUD, lineBuf);
					}
				}
			}
		}
	}
	
	// Output the current team status to all infected clients
	// Technically the below is a bit of a kludge but we can't be 100% sure that a client status doesn't change
	// between building the panel and displaying it.
	for (i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			if (hudDisabled[i])
				continue;
				
			switch (GetClientMenu(i))
			{
				case MenuSource_External, MenuSource_Normal:
				{ 
					continue;
				}
			}

			switch (GetClientTeam(i))
			{
				case TEAM_INFECTED:
				{ 
					if(IsClientTankHud(i)) continue;
				}
				case TEAM_SPECTATOR:
				{ 
					if(IsClientSpecHud(i)) continue;
					if(IsClientTankHud(i)) continue;
				}
				default:
				{
					continue;
				}
			}

			SendPanelToClient(pInfHUD, i, Menu_InfHUDPanel, 5);
		}
	}
	CloseHandle(pInfHUD);
}

public Action:evtTeamSwitch(Handle:event, const String:name[], bool:dontBroadcast)
{
	// Check to see if player joined infected team and if so refresh the HUD
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client)
	{
		if (GetClientTeam(client) == TEAM_INFECTED)
		{
			queueHUDUpdate(11);
		}
		else
		{
			// If player teamswitched to survivor, remove the HUD from their screen
			// immediately to stop them getting an advantage
			if (GetClientMenu(client) == MenuSource_RawPanel)
			{
				CancelClientMenu(client);
			}
		} 
	}
}

public Action:evtInfectedSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	// Infected player spawned, so refresh the HUD
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client)
	{
		if (GetClientTeam(client) == TEAM_INFECTED)
		{
			queueHUDUpdate(12); 
			// If player joins server and doesn't have to wait to spawn they might not see the announce
			// until they next die (and have to wait).  As a fallback we check when they spawn if they've 
			// already seen it or not.
			if (!clientGreeted[client] && (GetConVarBool(h_Announce)))
			{		
				CreateTimer(3.0, TimerAnnounce, client);	
			}
		}
	}
}

public Action:evtInfectedDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	// Infected player died, so refresh the HUD
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client && IsClientInGame(client))
	{
		if (GetClientTeam(client) == TEAM_INFECTED)
		{
			// If player is tank and dies before the fire would've killed them, kill the fire timer
			if (IsPlayerTank(client) && isTankOnFire[client] && (doomedTankTimer != INVALID_HANDLE))
			{
				#if DEBUGHUD
				PrintToChatAll("\x01\x04[infhud]\x01 [%f] Tank died naturally before fire timer expired.", GetGameTime());
				#endif
				isTankOnFire[client] = false;
				if (!CheckForTanksOnFire())
				{
					KillTimer(doomedTankTimer);
					doomedTankTimer = INVALID_HANDLE;  
				}
			}
			queueHUDUpdate(13);
		}
	}
}

public Action:evtInfectedHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	// The life of a regular special infected is pretty transient, they won't take many shots before they 
	// are dead (unlike the survivors) so we can afford to refresh the HUD reasonably quickly when they take damage.
	// The exception to this is the Tank - with 5000 health the survivors could be shooting constantly at it 
	// resulting in constant HUD refreshes which is not efficient.  So, we check to see if the entity being 
	// shot is a Tank or not and adjust the non-repeating timer accordingly.
	
	// Don't bother with infected HUD update if the round has ended
	if (!roundInProgress) return;
	
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	if (FightOrDieTimer[client] != INVALID_HANDLE)
	{
		KillTimer(FightOrDieTimer[client]);
		FightOrDieTimer[client] = INVALID_HANDLE;
		FightOrDieTimer[client] = CreateTimer(GetConVarFloat(h_idletime_b4slay), DisposeOfCowards, client);
	}
	
	if (FightOrDieTimer[attacker] != INVALID_HANDLE)
	{
		KillTimer(FightOrDieTimer[attacker]);
		FightOrDieTimer[attacker] = INVALID_HANDLE;
		FightOrDieTimer[attacker] = CreateTimer(GetConVarFloat(h_idletime_b4slay), DisposeOfCowards, attacker);
	}
	
	if (client)
	{
		decl Handle:fireTankExpiry, String:difficulty[100];
		GetConVarString(h_Difficulty, difficulty, sizeof(difficulty));
		
		if (GetClientTeam(client) == TEAM_INFECTED)
		{
			if (IsPlayerTank(client) && isTankOnFire[client] == false)
			{
				// If player is a tank and is on fire, we start the 
				// 30-second guaranteed death timer and let his fellow Infected guys know.
				
				if ((GetEntProp(client, Prop_Data, "m_fFlags") & FL_ONFIRE) && PlayerIsAlive(client))
				{
					isTankOnFire[client] = true;
					if ((StrContains(difficulty, "Easy", false) != -1) && (GameMode == 1))
					{
						
						fireTankExpiry = FindConVar("tank_burn_duration_normal");
					}
					else if ((StrContains(difficulty, "Normal", false) != -1) && (GameMode == 1))
					{
						fireTankExpiry = FindConVar("tank_burn_duration_normal");
					}
					else if ((StrContains(difficulty, "Hard", false) != -1) && (GameMode == 1))
					{
						fireTankExpiry = FindConVar("tank_burn_duration_hard");
					}
					else if ((StrContains(difficulty, "Impossible", false) != -1) && (GameMode == 1))
					{
						fireTankExpiry = FindConVar("tank_burn_duration_expert");
					}
					else if (GameMode == 2 || GameMode == 3)
					{
						fireTankExpiry = FindConVar("tank_burn_duration_normal");
					}
					burningTankTimeLeft[client] = (fireTankExpiry != INVALID_HANDLE) ? GetConVarInt(fireTankExpiry) : 30;
					if (doomedTankTimer == INVALID_HANDLE)
						doomedTankTimer = CreateTimer(1.0, doomedTankCountdown, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);										
				}		
			}
			// If we only have the 5 second timer running then we do a delayed damage update
			// (in reality with 4 players playing it's unlikely all of them will be alive at the same time
			// so we will probably have at least one faster timer running)
			if (delayedDmgTimer == INVALID_HANDLE && respawnTimer == INVALID_HANDLE && doomedTankTimer == INVALID_HANDLE)
			{
				delayedDmgTimer = CreateTimer(2.0, delayedDmgUpdate, _, TIMER_FLAG_NO_MAPCHANGE);
			} 
		}
	}
}

bool:CheckForTanksOnFire ()
{
	for (new i=1;i<=MaxClients;i++)
	{
		if (!IsClientInGame(i) || GetClientTeam(i)!=3 || !IsPlayerTank(i))
			continue;
		
		if (isTankOnFire[i] == true)
			return true;
	}
	return false;
}

public Action:evtInfectedWaitSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	// Don't bother with infected HUD update if the round has ended
	if (!roundInProgress) return;
	
	// Store this players respawn time in an array so we can present it to other clients
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client)
	{
		decl timetowait;
		if (GameMode == 2 && !IsFakeClient(client))
		{	
			timetowait = GetEventInt(event, "spawntime");
		}
		else if (GameMode != 2 && !IsFakeClient(client))
		{	
			timetowait = GetSpawnTime[client];
		}
		else
		{	
			timetowait = GetSpawnTime[client];
		}
		
		respawnDelay[client] = timetowait;
		// Only start timer if we don't have one already going.
		if (respawnTimer == INVALID_HANDLE) {
			// Note: If we have to start a new timer then there will be a 1 second delay before it starts, so 
			// subtract 1 from the pending spawn time
			respawnDelay[client] = (timetowait-1);
			respawnTimer = CreateTimer(1.0, monitorRespawn, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
		}
		// Send mod details/commands to the client, unless they have seen the announce already.
		// Note: We can't do this in OnClientPutInGame because the client may not be on the infected team
		// when they connect, and we can't put it in evtTeamSwitch because it won't register if the client
		// joins the server already on the Infected team.
		if (!clientGreeted[client] && (GetConVarBool(h_Announce)))
		{
			CreateTimer(8.0, TimerAnnounce, client);	
		}
	}
}

public Action:HUDReset(Handle:timer)
{
	infHUDTimer 		= INVALID_HANDLE;	// The main HUD refresh timer
	respawnTimer 	= INVALID_HANDLE;	// Respawn countdown timer
	doomedTankTimer 	= INVALID_HANDLE;	// "Tank on Fire" countdown timer
	delayedDmgTimer 	= INVALID_HANDLE;	// Delayed damage update timer
	pInfHUD 		= INVALID_HANDLE;	// The panel shown to all infected users
}

stock GetURandomIntRange(min, max)
{
	return (GetURandomInt() % (max-min+1)) + min;
}

stock CheatCommand(client, String:command[], String:arguments[] = "")
{
	new userFlags = GetUserFlagBits(client);
	SetUserFlagBits(client, ADMFLAG_ROOT);
	new flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", command, arguments);
	SetCommandFlags(command, flags);
	SetUserFlagBits(client, userFlags);
}

stock TurnNightVisionOn(client)
{
	if (GameMode == 2) return;
	if (!IsClientInGame(client)) return;
	if (GetClientTeam(client) != 3) return;
	if (!PlayerIsAlive(client)) return;
	if (IsFakeClient(client)) return;

	new d=GetEntProp(client, Prop_Send, "m_bNightVisionOn");
	if(d==0)
	{
		SetEntProp(client, Prop_Send, "m_bNightVisionOn",1); 
		//PrintHintText(client, "Night Vision On");
	}
	return;
}

stock SwitchToSurvivors(client)
{
	if (GameMode == 2) return;
	if (!IsClientInGame(client)) return;
	if (GetClientTeam(client) == 2) return;
	if (IsFakeClient(client)) return;
	
	new bot = FindBotToTakeOver();
	
	if (bot == 0)
	{
		PrintHintText(client, "No survivor bots to take over.");
		return;
	}
	
	static Handle:hSpec;
	if (hSpec == INVALID_HANDLE)
	{
		new Handle:hGameConf;
		
		hGameConf = LoadGameConfigFile("l4dinfectedbots");
		
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "SetHumanSpec");
		PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
		hSpec = EndPrepSDKCall();
	}
	
	static Handle:hSwitch;
	if (hSwitch == INVALID_HANDLE)
	{
		new Handle:hGameConf;
		
		hGameConf = LoadGameConfigFile("l4dinfectedbots");
		
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "TakeOverBot");
		PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
		hSwitch = EndPrepSDKCall();
	}
	
	SDKCall(hSpec, bot, client);
	SDKCall(hSwitch, client, true);
	return;
}

public bool:IsInteger(String:buffer[])
{
    new len = strlen(buffer);
    for (new i = 0; i < len; i++)
    {
        if ( !IsCharNumeric(buffer[i]) )
            return false;
    }

    return true;    
}

int L4D_GetSurvivorVictim(int client)
{
	int victim;

    /* Hunter */
	victim = GetEntPropEnt(client, Prop_Send, "m_pounceVictim");
	if (victim > 0)
	{
		return victim;
 	}

    /* Smoker */
 	victim = GetEntPropEnt(client, Prop_Send, "m_tongueVictim");
	if (victim > 0)
	{
		return victim;	
	}

	return -1;
}

static bool IsVisibleTo(int player1, int player2)
{
	// check FOV first
	// if his origin is not within a 60 degree cone in front of us, no need to raytracing.
	float pos1_eye[3], pos2_eye[3], eye_angle[3], vec_diff[3], vec_forward[3];
	GetClientEyePosition(player1, pos1_eye);
	GetClientEyeAngles(player1, eye_angle);
	GetClientEyePosition(player2, pos2_eye);
	MakeVectorFromPoints(pos1_eye, pos2_eye, vec_diff);
	NormalizeVector(vec_diff, vec_diff);
	GetAngleVectors(eye_angle, vec_forward, NULL_VECTOR, NULL_VECTOR);
	if (GetVectorDotProduct(vec_forward, vec_diff) < 0.5) // cos 60
	{
		return false;
	}

	// in FOV
	Handle hTrace;
	bool ret = false;
	float pos2_feet[3], pos2_chest[3];
	GetClientAbsOrigin(player2, pos2_feet);
	pos2_chest[0] = pos2_feet[0];
	pos2_chest[1] = pos2_feet[1];
	pos2_chest[2] = pos2_feet[2] + 45.0;

	hTrace = TR_TraceRayFilterEx(pos1_eye, pos2_eye, MASK_VISIBLE, RayType_EndPoint, TraceFilter, player1);
	if (!TR_DidHit(hTrace) || TR_GetEntityIndex(hTrace) == player2)
	{
		CloseHandle(hTrace);
		return true;
	}
	CloseHandle(hTrace);

	hTrace = TR_TraceRayFilterEx(pos1_eye, pos2_feet, MASK_VISIBLE, RayType_EndPoint, TraceFilter, player1);
	if (!TR_DidHit(hTrace) || TR_GetEntityIndex(hTrace) == player2)
	{
		CloseHandle(hTrace);
		return true;
	}
	CloseHandle(hTrace);

	hTrace = TR_TraceRayFilterEx(pos1_eye, pos2_chest, MASK_VISIBLE, RayType_EndPoint, TraceFilter, player1);
	if (!TR_DidHit(hTrace) || TR_GetEntityIndex(hTrace) == player2)
	{
		CloseHandle(hTrace);
		return true;
	}
	CloseHandle(hTrace);

	return ret;
}

static bool TraceFilter(int entity, int mask, int self)
{
	return entity != self;
}

bool CanBeSeenBySurvivors(int infected)
{
	for (int client = 1; client <= MaxClients; ++client)
	{
		if (IsAliveSurvivor(client) && IsVisibleTo(client, infected))
		{
			return true;
		}
	}
	return false;
}

bool IsAliveSurvivor(int client)
{
    return IsClientInGame(client)
        && GetClientTeam(client) == TEAM_SURVIVORS
        && IsPlayerAlive(client);
}

bool IsTooClose(int client, float distance)
{
	float fInfLocation[3], fSurvLocation[3], fVector[3];
	GetClientAbsOrigin(client, fInfLocation);

	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i)==2 && IsPlayerAlive(i))
		{
			GetClientAbsOrigin(i, fSurvLocation);
			MakeVectorFromPoints(fInfLocation, fSurvLocation, fVector);
			if (GetVectorLength(fVector, true) < Pow(distance, 2.0)) return true;
		}
	}
	return false;
}

void ResetTimer()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		delete FightOrDieTimer[i];
	}

	for(int i = 0; i < NUM_TYPES_INFECTED_MAX; i++)
	{
		delete g_hSpawnColdDownTimer[i];
	}
}

Action Timer_SpawnColdDown(Handle timer, int SI_TYPE)
{
	g_hSpawnColdDownTimer[SI_TYPE] = null;
	return Plugin_Continue;
}

///////////////////////////////////////////////////////////////////////////