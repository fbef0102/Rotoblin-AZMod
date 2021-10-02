#include <sourcemod>
#include <sdktools>
//#include <builtinvotes>
#include <multicolors>

//compile configuration
#define CUSTOM_CONFIGS 1		//enable or disable suicide blitz and c17
#define FULL_VERSION 1			//8 or just 4 configs
#define NO_BOOMER_CFG 1			//enable or disable no boomer configs and convars

//plugin version
#if FULL_VERSION
#define PLUGIN_VERSION "2.1"
#else
#define PLUGIN_VERSION "2.1"
#endif

#define L4D_MAXCLIENTS MaxClients
#define L4D_MAXCLIENTS_PLUS1 (L4D_MAXCLIENTS + 1)

new Handle:MapCountdownTimer;
#define CAMPAIGN_CHANGE_DELAY 4
new bool:isMapRestartPending;
new CampaingChangeDelay;
static bool: hasprepareloaded = false;

//plugin info
public Plugin:myinfo = 
{
	name		= "Comp Loader",
	author		= "archer,l4d1 modify by Harry",
	description	= "Player Swapper, Config Loader. Add Match Vote",
	version		= PLUGIN_VERSION,
}

//plugin setup
new Handle:CompLoaderEnabled			= INVALID_HANDLE;
new Handle:CompLoaderAllowLoad			= INVALID_HANDLE;
#if FULL_VERSION
new Handle:CompLoaderAllowHuntersOnly	= INVALID_HANDLE;
#endif
new Handle:CompLoaderAllowMap			= INVALID_HANDLE;
new Handle:CompLoader4v4ClassicConfig			= INVALID_HANDLE;
new Handle:CompLoader5v5Config			= INVALID_HANDLE;
new Handle:CompLoader4v4Config			= INVALID_HANDLE;
new Handle:CompLoader3v3Config			= INVALID_HANDLE;
new Handle:CompLoader2v2Config			= INVALID_HANDLE;
#if FULL_VERSION
new Handle:CompLoader5v5HuntersConfig	= INVALID_HANDLE;
new Handle:CompLoader4v4HuntersConfig	= INVALID_HANDLE;
new Handle:CompLoader3v3HuntersConfig	= INVALID_HANDLE;
new Handle:CompLoader2v2HuntersConfig	= INVALID_HANDLE;
#if NO_BOOMER_CFG
new Handle:CompLoader5v5NobConfig	= INVALID_HANDLE;
new Handle:CompLoader4v4NobConfig		= INVALID_HANDLE;
new Handle:CompLoader3v3NobConfig		= INVALID_HANDLE;
new Handle:CompLoader2v2NobConfig		= INVALID_HANDLE;
#endif
new Handle:CompLoader1v1HuntersConfig	= INVALID_HANDLE;

new Handle:CompLoader1v2HuntersConfig	= INVALID_HANDLE;
new Handle:CompLoader1v3HuntersConfig	= INVALID_HANDLE;
new Handle:CompLoader1v4HuntersConfig	= INVALID_HANDLE;
new Handle:CompLoader1v5HuntersConfig	= INVALID_HANDLE;
new Handle:CompLoader2v3HuntersConfig	= INVALID_HANDLE;
new Handle:CompLoader2v4HuntersConfig	= INVALID_HANDLE;
new Handle:CompLoader2v5HuntersConfig	= INVALID_HANDLE;
new Handle:CompLoader3v4HuntersConfig	= INVALID_HANDLE;
new Handle:CompLoader3v5HuntersConfig	= INVALID_HANDLE;
new Handle:CompLoader4v5HuntersConfig	= INVALID_HANDLE;
new Handle:CompLoaderWitchPartyConfig   = INVALID_HANDLE;
new Handle:CompLoaderDarkCoopConfig		= INVALID_HANDLE;

#else
new Handle:CompLoader1v1Config			= INVALID_HANDLE;
#endif
new Handle:CompLoaderLoadActive			= INVALID_HANDLE;
new Handle:CompLoaderMapActive			= INVALID_HANDLE;

//global integers and strings used on map start
new FirstMapVersus;
new String:ConfigToExecuteFirstMap[128];
new String:LoadCommandConfigToExecuteName[128];			//string that will be set to the value of the xvx config value specified in the convar, global to use with timed load command
new String:AdminLoadCommandConfigToExecuteName[128];	//string that will be set to the value of the xvx config value specified in the convar, global to use with timed load command
new String:MapToExecuteName[128];
new String:AdminMapToExecuteName[128];
new CompLoaderConfigExecuted;
new CompLoaderEnabledValue;

static bool: bIsL4DscoresLoaded = false;		//controls the printing of the team order
static bool: bIsRotoblinLoaded = false;			//controls the printing of the rotoblin controlled cvars
static g_votedelay;
#define VOTEDELAY_TIME 60
new Handle:g_hCvarPlayerLimit;
//new Handle:g_hVote;
#define MATCHMODES_PATH		"configs/matchmodes.txt"
new String:g_sCfg[32];
Menu g_hMatchVote = null;
new Handle:g_hModesKV = INVALID_HANDLE;
native ClientVoteMenuSet(client,trueorfalse);//from votes3
new Votey = 0;
new Voten = 0;
#define VOTE_NO "no"
#define VOTE_YES "yes"
new Handle:g_Cvar_Limits;
new String:PlayerCfg[128];			//Initial string after !load

public OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("Roto2-AZ_mod.phrases");
	
	//require Left 4 Dead
	decl String:Game[64];
	GetGameFolderName(Game, sizeof(Game));
	if(!StrEqual(Game, "left4dead", false))
		SetFailState("Plugin supports Left 4 Dead only.");
	CompLoaderEnabled				= CreateConVar("comp_loader_enabled", "0", "Enable comp_loader to exec config on first maps.", FCVAR_NOTIFY);
	#if FULL_VERSION	
	CompLoaderAllowLoad				= CreateConVar("comp_loader_allow_load", "1", "Allow players to use the !load command.", FCVAR_NOTIFY);
	CompLoaderAllowHuntersOnly		= CreateConVar("comp_loader_allow_hunters_only", "1", "Allow players to load 1v1, and hunter only 4v4 3v3 2v2.", FCVAR_NOTIFY);
	CompLoaderAllowMap				= CreateConVar("comp_loader_allow_map", "1", "Allow players to use the !changemap(!cm) command.", FCVAR_NOTIFY);
	#else
	CompLoaderAllowMap				= CreateConVar("comp_loader_allow_map", "1", "Allow players to use the !changemap(!cm) command.", FCVAR_NOTIFY);
	CompLoaderAllowLoad				= CreateConVar("comp_loader_allow_load", "1", "Allow players to use the !load command.", FCVAR_NOTIFY);
	#endif
	//CompLoaderConfig				= CreateConVar("comp_loader_config", "4v4", "Type of config to be loaded, 4v4 / 3v3 / 2v2 / 1v1.");	//needs to be removed
	//CompLoaderConfigHuntersOnly		= CreateConVar("comp_loader_config_hunters_only", "0", "1 = Hunters only, 0 = Normal .");	//needs to be removed
	CompLoader5v5Config				= CreateConVar("comp_loader_5v5_config", "rotoblin_hardcore_5v5.cfg", "Name of the 5v5 config.");
	CompLoader4v4Config				= CreateConVar("comp_loader_4v4_config", "rotoblin_hardcore_4v4.cfg", "Name of the 4v4 config.");
	CompLoader4v4ClassicConfig		= CreateConVar("comp_loader_4v4_classic_config", "rotoblin_hardcore_4v4_classic.cfg", "Name of the 4v4 classic config.");
	CompLoader3v3Config				= CreateConVar("comp_loader_3v3_config", "rotoblin_hardcore_3v3.cfg", "Name of the 3v3 config.");
	CompLoader2v2Config				= CreateConVar("comp_loader_2v2_config", "rotoblin_hardcore_2v2.cfg", "Name of the 2v2 config.");
	#if FULL_VERSION
	CompLoader5v5HuntersConfig		= CreateConVar("comp_loader_5v5_hunters_only", "rotoblin_hunters_5v5.cfg", "Name of the 5v5 Hunters only config.");
	CompLoader4v4HuntersConfig		= CreateConVar("comp_loader_4v4_hunters_only", "rotoblin_hunters_4v4.cfg", "Name of the 4v4 Hunters only config.");
	CompLoader3v3HuntersConfig		= CreateConVar("comp_loader_3v3_hunters_only", "rotoblin_hunters_3v3.cfg", "Name of the 3v3 Hunters only config.");
	CompLoader2v2HuntersConfig		= CreateConVar("comp_loader_2v2_hunters_only", "rotoblin_hunters_2v2.cfg", "Name of the 2v2 Hunters only config.");
	#if NO_BOOMER_CFG
	CompLoader5v5NobConfig			= CreateConVar("comp_loader_5v5_no_boomer", "rotoblin_nob_5v5.cfg", "Name of the 4v4 No Boomer config.");
	CompLoader4v4NobConfig			= CreateConVar("comp_loader_4v4_no_boomer", "rotoblin_nob_4v4.cfg", "Name of the 4v4 No Boomer config.");
	CompLoader3v3NobConfig			= CreateConVar("comp_loader_3v3_no_boomer", "rotoblin_nob_3v3.cfg", "Name of the 3v3 No Boomer config.");
	CompLoader2v2NobConfig			= CreateConVar("comp_loader_2v2_no_boomer", "rotoblin_nob_2v2.cfg", "Name of the 2v2 No Boomer config.");
	#endif
	CompLoader1v1HuntersConfig		= CreateConVar("comp_loader_1v1_hunters_only", "rotoblin_hunters_1v1.cfg", "Name of the 1v1 Hunters only config.");
	
	CompLoader1v2HuntersConfig		= CreateConVar("comp_loader_1v2_hunters_only", "rotoblin_hunters_1v2.cfg", "Name of the 1v2 Hunters only config.");
	CompLoader1v3HuntersConfig	= CreateConVar("comp_loader_1v3_hunters_only", "rotoblin_hunters_1v3.cfg", "Name of the 1v3 Hunters only config.");
	CompLoader1v4HuntersConfig	= CreateConVar("comp_loader_1v4_hunters_only", "rotoblin_hunters_1v4.cfg", "Name of the 1v4 Hunters only config.");
	CompLoader1v5HuntersConfig	= CreateConVar("comp_loader_1v5_hunters_only", "rotoblin_hunters_1v5.cfg", "Name of the 1v5 Hunters only config.");
	CompLoader2v3HuntersConfig	= CreateConVar("comp_loader_2v3_hunters_only", "rotoblin_hunters_2v3.cfg", "Name of the 2v3 Hunters only config.");
	CompLoader2v4HuntersConfig	= CreateConVar("comp_loader_2v4_hunters_only", "rotoblin_hunters_2v4.cfg", "Name of the 2v4 Hunters only config.");
	CompLoader2v5HuntersConfig	= CreateConVar("comp_loader_2v5_hunters_only", "rotoblin_hunters_2v5.cfg", "Name of the 2v5 Hunters only config.");
	CompLoader3v4HuntersConfig	= CreateConVar("comp_loader_3v4_hunters_only", "rotoblin_hunters_3v4.cfg", "Name of the 3v4 Hunters only config.");
	CompLoader3v5HuntersConfig	= CreateConVar("comp_loader_3v5_hunters_only", "rotoblin_hunters_3v5.cfg", "Name of the 3v5 Hunters only config.");
	CompLoader4v5HuntersConfig	= CreateConVar("comp_loader_4v5_hunters_only", "rotoblin_hunters_4v5.cfg", "Name of the 4v5 Hunters only config.");
	CompLoaderWitchPartyConfig	= CreateConVar("comp_loader_witch_Party_config", "rotoblin_witch_party.cfg", "Name of the Witch Party config.");
	CompLoaderDarkCoopConfig	= CreateConVar("comp_loader_Dark_Coop_config", "rotoblin_Dark_Coop.cfg", "Name of the Witch Party config.");

	#else
	CompLoader1v1Config				= CreateConVar("comp_loader_1v1_config", "rotoblin_hardcore_1v1.cfg", "Name of the 1v1 config.");
	#endif
	CompLoaderLoadActive			= CreateConVar("comp_loader_load_active", "0", "");
	CompLoaderMapActive				= CreateConVar("comp_loader_map_active", "0", "");
	/*
	//to get !cinfo or !info working
	RegConsoleCmd("say", Command_Say);
	RegConsoleCmd("say_team", Command_Say);
	*/
		
	HookConVarChange(CompLoaderLoadActive, ConVarChange_CompLoaderLoadActive);
	HookConVarChange(CompLoaderMapActive, ConVarChange_CompLoaderMapActive);
	
	//register cmds
	RegConsoleCmd("sm_load", Config_Changer, "Request to load or forceload a config.");
	RegConsoleCmd("sm_match", Config_Changer, "Request to match or forcematch a config.");
	RegConsoleCmd("sm_mode", Config_Changer, "Request to match or forcematch a config.");
	RegConsoleCmd("sm_changemap", Map_Changer, "Request to change or forcechange campaign.");
	RegConsoleCmd("sm_cm", Map_Changer, "Request to change or forcechange campaign.");
	RegAdminCmd("sm_reload", Reload_Config, ADMFLAG_GENERIC, "Reload the current _map.cfg config.");	//needs to be implemented later, should get value of l4d_ready_server_cfg, and execute that on !reload
	RegConsoleCmd("config_info", Config_Info, "Prints info about the current config.");
	CompLoaderConfigExecuted = 0;	//sets to 0 so map gets restarted twice (first time by loader, second time by comploader)
	
	g_hCvarPlayerLimit = CreateConVar("sm_match_player_limit", "1", "Minimum # of players in game to start the vote", FCVAR_NOTIFY);
	g_Cvar_Limits = CreateConVar("sm_matchvotes_s", "0.60", "百分比.", 0, true, 0.05, true, 1.0);
	
	decl String:sBuffer[128];
	GetGameFolderName(sBuffer, sizeof(sBuffer));
	g_hModesKV = CreateKeyValues("MatchModes");
	BuildPath(Path_SM, sBuffer, sizeof(sBuffer), MATCHMODES_PATH);
	if (!FileToKeyValues(g_hModesKV, sBuffer))
	{
		SetFailState("Couldn't load matchmodes.txt!");
	}	
}

//Config_changer & Map_Changer
//if client team is 2, then client is survivor, ...
#define TEAM_SPECTATOR	1
#define TEAM_SURVIVOR	2
#define TEAM_INFECTED	3

new String:Team_Names[TEAM_INFECTED + 1][64] = {"", "Spectator", "Survivors", "Infected"}; //array containing teamnames, used in Map_Changer and Config_Changer

new bool:Config_Requests[TEAM_INFECTED + 1] = {false, false};	//creating Config_Requests[Client_Team] and Config_Requests[Opposite_Team] and set them to false
new bool:Map_Requests[TEAM_INFECTED + 1] = {false, false};		//creating Map_Requests[Client_Team] and Map_Requests[Opposite_Team] and set them to false

//variables and bools controlling the !load and !map timeout and admin cancellation
new numberOfLoadTimers = 0;
new numberOfMapTimers = 0;

new bool:adminCancel = false;			//reset to false after client requests to load a config, controls Config_Requests[TEAM_INFECTED] and Config_Requests[TEAM_SURVIVOR] needs to be defined for use with the stop timer creation
new bool:adminMapActive = false;		//this command is set to true when admin forces map or config change, that way players cant use !load or !changemap when the admin has already force executed (3second timeframe)
new bool:adminLoadActive = false;

//for config info
static	bool:	bCooldown[MAXPLAYERS + 1];

stock bool:Roto_CheckIfLoaded()
{
new Handle:hPlugins = GetPluginIterator();
new Handle:hPlugin;
decl String:strPlugin[64];

// Loop through all the plugins in the plugins/ directory.
while (MorePlugins(hPlugins))
{
// Read the next plugin.
hPlugin = ReadPlugin(hPlugins);

GetPluginFilename(hPlugin, strPlugin, sizeof(strPlugin));
if (StrEqual(strPlugin, "rotoblin.smx", false))
{
CloseHandle(hPlugins);
return (GetPluginStatus(hPlugin) == Plugin_Running);
}
}

CloseHandle(hPlugins);
return false;
}

stock bool:Scores_CheckIfLoaded()
{
new Handle:hPlugins = GetPluginIterator();
new Handle:hPlugin;
decl String:strPlugin[64];

// Loop through all the plugins in the plugins/ directory.
while (MorePlugins(hPlugins))
{
// Read the next plugin.
hPlugin = ReadPlugin(hPlugins);

GetPluginFilename(hPlugin, strPlugin, sizeof(strPlugin));
if (StrEqual(strPlugin, "l4dscores.smx", false))
{
CloseHandle(hPlugins);
return (GetPluginStatus(hPlugin) == Plugin_Running);
}
}

CloseHandle(hPlugins);
return false;
}

public Action:Config_Info(client, args)
{
	//prevent spammage cuz checking for plugin is intensive?
	if (bCooldown[client] == true) return Plugin_Handled;
	configInfo(client);
	return Plugin_Handled;
}

public Action:Cooldown_Timer(Handle:timer, any:client)
{
	bCooldown[client] = false;
	return Plugin_Stop;
}

configInfo(client)
{
	//this checks if rotoblin is loaded and if scores is loaded
	//if they arent, they shouldnt be printed in the console (wont cause unknown command config_info if scores/roto isnt loaded, and also wont cause error if 
	bIsL4DscoresLoaded = Scores_CheckIfLoaded()
	bIsRotoblinLoaded = Roto_CheckIfLoaded()

	new Float:g_z_tank_health 					= GetConVarFloat(FindConVar("z_tank_health"));
	new Float:g_versus_tank_bonus_health 		= GetConVarFloat(FindConVar("versus_tank_bonus_health"));
	new Float:g_tank_health 					= g_z_tank_health * g_versus_tank_bonus_health;
	new frustrationLifeTime						= GetConVarInt(FindConVar("z_frustration_lifetime"));
	new frustrationEnabled						= GetConVarInt(FindConVar("z_frustration"));
	new survivorLimit							= GetConVarInt(FindConVar("survivor_limit"));
	new infectedLimit							= GetConVarInt(FindConVar("z_max_player_zombies"));
	new smokerLimit								= GetConVarInt(FindConVar("z_versus_smoker_limit"));
	new boomerLimit								= GetConVarInt(FindConVar("z_versus_boomer_limit"));
	new huntersOnly								= smokerLimit + boomerLimit;
	//tankchance
	new Float:g_versus_tank_chance				= GetConVarFloat(FindConVar("versus_tank_chance"));
	new Float:g_versus_tank_chance_intro		= GetConVarFloat(FindConVar("versus_tank_chance_intro"));
	new Float:g_versus_tank_chance_finale		= GetConVarFloat(FindConVar("versus_tank_chance_finale"));
	//spawners
	new humanInfected							= GetTeamHumanCount(3);
	if (humanInfected <= 0) (humanInfected = 1);
	new Float:g_modifier						= (humanInfected/4.0);
	new Float:g_z_ghost_delay_min				= GetConVarFloat(FindConVar("z_ghost_delay_min"));
	new Float:g_z_ghost_delay_max				= GetConVarFloat(FindConVar("z_ghost_delay_max"));
	new Float:g_realDelayMin					= g_z_ghost_delay_min * g_modifier;
	new Float:g_realDelayMax					= g_z_ghost_delay_max * g_modifier;
	new realDelayMin							= RoundFloat(g_realDelayMin);
	new realDelayMax							= RoundFloat(g_realDelayMax);
	new meleeSwings;
	//common
	new zCommonLimit							= GetConVarInt(FindConVar("z_common_limit"));
	
	new meleelimit								= 5;
	new healthStyle								= 0;
	new rotoblin2v2Int							= 0;
	new weaponStyle								= 0;
	new throwablesAllow							= 1;
	new cannistersAllow							= 1;
	new huntingRifleLimit						= 4;
	if(bIsRotoblinLoaded)
	{
		//roto *should be disable-able
		meleelimit								= GetConVarInt(FindConVar("rotoblin_melee_penalty"));
		healthStyle								= GetConVarInt(FindConVar("rotoblin_health_style"));
		rotoblin2v2Int							= GetConVarInt(FindConVar("rotoblin_enable_2v2"));
		weaponStyle								= GetConVarInt(FindConVar("rotoblin_weapon_style"));
		throwablesAllow							= GetConVarInt(FindConVar("rotoblin_enable_throwables"));
		cannistersAllow							= GetConVarInt(FindConVar("rotoblin_enable_cannisters"));
		huntingRifleLimit						= GetConVarInt(FindConVar("rotoblin_limit_huntingrifle"));
	}
	
	new teamOrderInt							= 0;
	if(bIsL4DscoresLoaded)
	{
		//l4dscores *should be disable-able
		teamOrderInt							= GetConVarInt(FindConVar("l4d_team_order"));
	}
	
	decl String:tankMapChance[32];
	if(g_versus_tank_chance >= 1.0)
	{
		if(g_versus_tank_chance_intro < 1 && g_versus_tank_chance_finale < 1) Format(tankMapChance, 32, "only maps 2, 3, 4");
		if(g_versus_tank_chance_intro >= 1 && g_versus_tank_chance_finale < 1) Format(tankMapChance, 32, "only maps 1, 2, 3, 4");
		if(g_versus_tank_chance_intro < 1 && g_versus_tank_chance_finale >= 1) Format(tankMapChance, 32, "only maps 2, 3, 4, 5");
		if(g_versus_tank_chance_intro >= 1 && g_versus_tank_chance_finale >= 1) Format(tankMapChance, 32, "yes");
	}
	if(g_versus_tank_chance < 1.0) Format(tankMapChance, 32, "no");
	
	//rotoblin config
	if(bIsRotoblinLoaded)
	{
		if (meleelimit == 1) meleeSwings = 5;
		if (meleelimit == 2) meleeSwings = 2;
		if (meleelimit == 3) meleeSwings = 2;
		if (meleelimit >= 4) meleeSwings = 1;
	}
	else meleeSwings = 5;
	
	//roto canisters and throwables
	decl String:cannistersAllowed[32];
	if(bIsRotoblinLoaded)
	{
		if (cannistersAllow == 1) Format(cannistersAllowed, 32, "yes");
		if (cannistersAllow == 0) Format(cannistersAllowed, 32, "no");
	}
	else Format(cannistersAllowed, 32, "yes");
	
	decl String:throwablesAllowed[32];
	if(bIsRotoblinLoaded)
	{
		if (throwablesAllow == 1) Format(throwablesAllowed, 32, "yes");
		if (throwablesAllow == 0) Format(throwablesAllowed, 32, "no");
	}
	else Format(throwablesAllowed, 32, "yes");
	
	//roto weapon mode
	decl String:weaponsAllowed[32];
	if(bIsRotoblinLoaded)
	{
		if(weaponStyle == 0)
		{
			if (huntingRifleLimit == 4) Format(weaponsAllowed, 32, "All Weapons");
			if (huntingRifleLimit == 3) Format(weaponsAllowed, 32, "Tier 1, Tier 2 (3 Snipers)");
			if (huntingRifleLimit == 2) Format(weaponsAllowed, 32, "Tier 1, Tier 2 (2 Snipers)");
			if (huntingRifleLimit == 1) Format(weaponsAllowed, 32, "Tier 1, Tier 2 (1 Sniper)");
			if (huntingRifleLimit == 0) Format(weaponsAllowed, 32, "Tier 1, Tier 2 (No Sniper)");
		}
		else
		{
			if (huntingRifleLimit == 4) Format(weaponsAllowed, 32, "Tier 1");
			if (huntingRifleLimit == 3) Format(weaponsAllowed, 32, "Tier 1 (3 Snipers)");
			if (huntingRifleLimit == 2) Format(weaponsAllowed, 32, "Tier 1 (2 Snipers)");
			if (huntingRifleLimit == 1) Format(weaponsAllowed, 32, "Tier 1 (1 Sniper)");
			if (huntingRifleLimit == 0) Format(weaponsAllowed, 32, "Tier 1 (No Sniper)");
			
		}
		//Weapons Available: "All Weapons" "Pump Shotguns, Uzis, Snipers" "Pump Shotguns, Uzi, %i Snipers "Pump Shotguns, Uzis, 1 Sniper" "Pump Shotguns, Uzis"
	}
	else Format(weaponsAllowed, 32, "All Weapons");
	//roto health mode
	decl String:healthMode[32];
	if(bIsRotoblinLoaded)
	{
		if (healthStyle == 0) Format(healthMode, 32, "Medkits");
		if (healthStyle == 1) Format(healthMode, 32, "Rotoblin");		//	rotoblin_health_style 3 - 1 - Replace all medkits with pills, 2 - Replace all but finale medkits with pills, 3 - Replace safe room and finale kits with pills; remove all other health sources
		if (healthStyle == 2) Format(healthMode, 32, "Frust + Finale Medkits");
		if (healthStyle >= 3) Format(healthMode, 32, "Rotoblin Hardcore");
	}
	else Format(healthMode, 32, "Medkits");
	
	decl String:rotoblin2v2[32];
	if (rotoblin2v2Int >= 1) Format(rotoblin2v2, 32, "yes");
	else Format(rotoblin2v2, 32, "no");

	//game mode calculation
	decl String:configXvx[32];
	if (survivorLimit == infectedLimit)
	{
		if (survivorLimit == 4)
		{
			if(huntersOnly != 0) Format(configXvx, 32, "4v4");
			else Format(configXvx, 32, "4v4, Hunters Only");
		}
		if (survivorLimit == 3)
		{
			if(huntersOnly != 0) Format(configXvx, 32, "3v3");
			else Format(configXvx, 32, "3v3, Hunters Only");
		}
		if (survivorLimit == 2)
		{
			if(huntersOnly != 0) Format(configXvx, 32, "2v2");
			else Format(configXvx, 32, "2v2, Hunters Only");
		}
		if (survivorLimit == 1)
		{
			if(huntersOnly != 0) Format(configXvx, 32, "1v1");
			else Format(configXvx, 32, "1v1, Hunters Only");
		}
	}
	else Format(configXvx, 32, "unavailable");
	
	decl String:teamOrder[64];
	if (teamOrderInt >= 0 && teamOrderInt < 4)
	{
		if (teamOrderInt == 0) Format(teamOrder, 64, "highest score goes survivor first");
		if (teamOrderInt == 1) Format(teamOrder, 64, "highest score goes infected first");
		if (teamOrderInt == 2) Format(teamOrder, 64, "teams never get swapped");
		if (teamOrderInt == 3) Format(teamOrder, 64, "teams get swapped every map");
	}
	else Format(teamOrder, 32, "unavailable");
	
	//tank frustration calculation
	decl String:tank_frustration_string[64];
	if (frustrationEnabled == 0) Format(tank_frustration_string, 64, "none");
	else if (frustrationLifeTime == 20 ) Format(tank_frustration_string, 64, "default, (%i seconds)", frustrationLifeTime);
	else if (frustrationLifeTime != 20 ) Format(tank_frustration_string, 64, "custom, (%i seconds)", frustrationLifeTime);
	
	
	decl String:infoStart[256];
	Format(infoStart, 256, "___________________________________________________________________\n");
	
	decl String:infoEnd[256];
	Format(infoEnd, 256, "___________________________________________________________________");
	
	decl String:infoMid[128];
	Format(infoMid, 128, " ");
		
	decl String:infoTank[1024];
	Format(infoTank, 1024, "  Tank Health:            %4.0f\n", g_tank_health);
	Format(infoTank, 1024, "%s  Tank Frustration:       %s\n", infoTank, tank_frustration_string);
	Format(infoTank, 1024, "%s  Tank Every Map:         %s", infoTank, tankMapChance);
	
	decl String:infoGame[1024];
	Format(infoGame, 1024, "  Game Mode:              %s\n", configXvx);
	Format(infoGame, 1024, "%s  Team Order:             %s", infoGame, teamOrder);
	
	decl String:infoSpawn[1024];
	Format(infoSpawn, 1024, "  Spawn Delay Min:        %i\n", realDelayMin);
	Format(infoSpawn, 1024, "%s  Spawn Delay Max:        %i", infoSpawn, realDelayMax);
	
	decl String:infoCommon[1024];
	Format(infoCommon, 1024, "  Common Limit:           %i", zCommonLimit);
	
	decl String:infoRoto[1024];
	Format(infoRoto, 1024, "  Health Mode:            %s\n", healthMode);
	Format(infoRoto, 1024, "%s  Weapons Allowed:        %s\n", infoRoto, weaponsAllowed);
	Format(infoRoto, 1024, "%s  Throwables Allowed:     %s\n", infoRoto, throwablesAllowed);
	Format(infoRoto, 1024, "%s  Cannisters Allowed:     %s\n", infoRoto, cannistersAllowed);
	Format(infoRoto, 1024, "%s  Melee #Available:       %i\n", infoRoto, meleeSwings);
	Format(infoRoto, 1024, "%s  Auto Bot Slay (2v2):    %s", infoRoto, rotoblin2v2);

	PrintToConsole(client, infoStart);
	PrintToConsole(client, infoGame);
	PrintToConsole(client, infoMid);
	PrintToConsole(client, infoSpawn);
	PrintToConsole(client, infoMid);
	PrintToConsole(client, infoTank);
	PrintToConsole(client, infoMid);
	PrintToConsole(client, infoCommon);
	PrintToConsole(client, infoMid);
	PrintToConsole(client, infoRoto);
	PrintToConsole(client, infoMid);
	PrintToConsole(client, infoEnd);
	bCooldown[client] = true;
	
	CreateTimer(1.0, Cooldown_Timer, client);
	//return Plugin_Handled;
}

public ConVarChange_CompLoaderLoadActive(Handle:convar, const String:oldValue[], const String:newValue[])
{	
	if(oldValue[0] == newValue[0])
	{
		return;
	}
	else
	{
		new value = StringToInt(newValue);
			
		if(value == 1)
		{
			numberOfLoadTimers++;
			//PrintToChatAll("number of timers active: %d", numberOfLoadTimers);
			CreateTimer(20.0, Timer_Load_Requests_Timeout, TIMER_FLAG_NO_MAPCHANGE);
			return;
		}
	}
}

public ConVarChange_CompLoaderMapActive(Handle:convar, const String:oldValue[], const String:newValue[])
{	
	if(oldValue[0] == newValue[0])
	{
		return;
	}
	else
	{
		new value = StringToInt(newValue);
			
		if(value == 1)
		{
			numberOfMapTimers++;
			//PrintToChatAll("number of map timers active: %d", numberOfMapTimers);
			CreateTimer(20.0, Timer_Map_Requests_Timeout, TIMER_FLAG_NO_MAPCHANGE);
			return;
		}
	}
}

public Action:Timer_Load_Requests_Timeout(Handle:timer)
{
	if(numberOfLoadTimers == 1)
	{
		new status;
		status = GetConVarInt(CompLoaderLoadActive);
		
		if(status == 1 && adminCancel == false && adminLoadActive == false)
		{
			Config_Requests[TEAM_SURVIVOR] = false;
			Config_Requests[TEAM_INFECTED] = false;
			CPrintToChatAll("[{olive}TS{default}] !load %t","request timed out.");
			numberOfLoadTimers = 0;
			SetConVarInt(FindConVar("comp_loader_load_active"), 0);
		}
		else 
		{
			numberOfLoadTimers = 0;
		}
	}
	else
	{
		if(numberOfLoadTimers > 1)
		{
			numberOfLoadTimers--;
		}
		
	}
}

public Action:Timer_Map_Requests_Timeout(Handle:timer)
{
	
	if(numberOfMapTimers == 1)
	{
		new status;
		status = GetConVarInt(CompLoaderMapActive);
		
		if(status == 1 && adminCancel == false && adminMapActive == false)
		{
			Map_Requests[TEAM_SURVIVOR] = false;
			Map_Requests[TEAM_INFECTED] = false;
			CPrintToChatAll("[{olive}TS{default}] !changemap(!cm) %t","request timed out.");
			numberOfMapTimers = 0;
			SetConVarInt(FindConVar("comp_loader_map_active"), 0);
		}
		else 
		{
			numberOfMapTimers = 0;
		}
	}
	else
	{
		if(numberOfMapTimers > 1)
		{
			numberOfMapTimers--;
		}	
	}
}

Admin_Cancel_Lite()
{
	Config_Requests[TEAM_SURVIVOR] = false;
	Config_Requests[TEAM_INFECTED] = false;
	Map_Requests[TEAM_SURVIVOR] = false;
	Map_Requests[TEAM_INFECTED] = false;
	adminCancel = true;
	adminMapActive = true;
	adminLoadActive = true;
}

Admin_Cancel(client)
{
	decl String:localAdminName[32];
	GetClientName(client, localAdminName, sizeof(localAdminName));
	
	
	//implement if both teams agree on config or map, still cancel the load by changing a integer value to 1, that is loaded in the delayed map/config execute command
	
	if ((Config_Requests[TEAM_SURVIVOR] || Config_Requests[TEAM_INFECTED]) && (!Map_Requests[TEAM_SURVIVOR] && !Map_Requests[TEAM_INFECTED]))
	{
			Config_Requests[TEAM_SURVIVOR] = false;
			Config_Requests[TEAM_INFECTED] = false;
			adminCancel = true;
			adminMapActive = false;
			adminLoadActive = false;
			CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t", localAdminName,"canceled the command request.","!load");
			SetConVarInt(FindConVar("comp_loader_load_active"), 0);
			CreateTimer(10.0, Timer_Admin_Cancel_Cooldown, TIMER_FLAG_NO_MAPCHANGE);
			SetConVarInt(FindConVar("comp_loader_load_active"), 0);
			return;
	}
	if ((!Config_Requests[TEAM_SURVIVOR] && !Config_Requests[TEAM_INFECTED]) && (Map_Requests[TEAM_SURVIVOR] || Map_Requests[TEAM_INFECTED]))
	{
			Map_Requests[TEAM_SURVIVOR] = false;
			Map_Requests[TEAM_INFECTED] = false;
			adminCancel = true;
			adminMapActive = false;
			adminLoadActive = false;
			CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %s", localAdminName,"canceled the command request.","!map");
			SetConVarInt(FindConVar("comp_loader_map_active"), 0);
			CreateTimer(10.0, Timer_Admin_Cancel_Cooldown, TIMER_FLAG_NO_MAPCHANGE);
			return;
	}
	else
	{
			Config_Requests[TEAM_SURVIVOR] = false;
			Config_Requests[TEAM_INFECTED] = false;
			Map_Requests[TEAM_SURVIVOR] = false;
			Map_Requests[TEAM_INFECTED] = false;
			adminCancel = true;
			adminMapActive = false;
			adminLoadActive = false;
			CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s %t", localAdminName,"canceled all requests.");
			SetConVarInt(FindConVar("comp_loader_map_active"), 0);
			SetConVarInt(FindConVar("comp_loader_load_active"), 0);
			CreateTimer(10.0, Timer_Admin_Cancel_Cooldown, TIMER_FLAG_NO_MAPCHANGE);
	}
	return;
}

public Action:Timer_Admin_Cancel_Cooldown(Handle:timer)
{
	adminCancel = false;
}

public Action:Timer_Load_Config(Handle:timer)
{
	if (!adminCancel)
	{
		if(!adminLoadActive)
		ServerCommand("exec %s", LoadCommandConfigToExecuteName);
		else return;
	}
}

public Action:Timer_Admin_Load_Config(Handle:timer)
{
	adminLoadActive = false;
	ServerCommand("exec %s", AdminLoadCommandConfigToExecuteName);
}
Timer_Map_Change()
{
	if (!adminCancel)
	{
		if(!adminMapActive)
			CampaignchangeDelayed();
		else return;
	}
}

stock GetTeamMaxHumans(team)
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

stock bool:IsClientInGameHuman(client)
{
	return IsClientInGame(client) && !IsFakeClient(client);
}

stock GetTeamHumanCount(team)
{
	new humans = 0;
	
	new i;
	for(i = 1; i < L4D_MAXCLIENTS_PLUS1; i++)
	{
		if(IsClientInGameHuman(i) && GetClientTeam(i) == team)
		{
			humans++;
		}
	}
	
	return humans;
}


public Action:Config_Changer(client, args)
{
	if (client == 0)
	{
		return Plugin_Handled;
	}
	if(hasprepareloaded||isMapRestartPending) return Plugin_Handled;
	new bool:id = IsPlayerGenericAdmin(client);
	if (args < 1)
	{
		new bool:isAdmin = false;
		new bool:isLoadAllowed = false;
		
		#if FULL_VERSION
		new bool:isHunterAllowed = false;
		#endif
		
		new allowLoadInt = GetConVarInt(CompLoaderAllowLoad);
		#if FULL_VERSION
		new allowHunterInt = GetConVarInt(CompLoaderAllowHuntersOnly);
		#endif
		
		if (id == true) isAdmin = true;
		
		if (allowLoadInt == 1) isLoadAllowed = true;
		#if FULL_VERSION
		if (allowHunterInt == 1) isHunterAllowed = true;
		#endif
		
		if (isAdmin == false && isLoadAllowed == false)
		{
			ReplyToCommand(client, "[TS] %T","command is disabled.",client,"!load");
			return Plugin_Handled;
		}
		decl String:cfg5v5[128];
		decl String:cfg4v4classic[128];
		decl String:cfg4v4[128];
		decl String:cfg3v3[128];
		decl String:cfg2v2[128];
		#if FULL_VERSION
		decl String:cfg5v5hunters[128];
		decl String:cfg4v4hunters[128];
		decl String:cfg3v3hunters[128];
		decl String:cfg2v2hunters[128];
		decl String:cfg1v1hunters[128];
		
		decl String:cfg1v2hunters[128];
		decl String:cfg1v3hunters[128];
		decl String:cfg1v4hunters[128];
		decl String:cfg1v5hunters[128];
		decl String:cfg2v3hunters[128];
		decl String:cfg2v4hunters[128];
		decl String:cfg2v5hunters[128];
		decl String:cfg3v4hunters[128];
		decl String:cfg3v5hunters[128];
		decl String:cfg4v5hunters[128];
		decl String:cfgwitchparty[128];
		decl String:cfgdarkcoop[128];
		#else
		decl String:cfg1v1[128];
		#endif
		
		GetConVarString(CompLoader4v4ClassicConfig, cfg4v4classic, 128);
		GetConVarString(CompLoader5v5Config, cfg5v5, 128);
		GetConVarString(CompLoader4v4Config, cfg4v4, 128);
		GetConVarString(CompLoader3v3Config, cfg3v3, 128);
		GetConVarString(CompLoader2v2Config, cfg2v2, 128);
		#if FULL_VERSION
		GetConVarString(CompLoader5v5HuntersConfig, cfg5v5hunters, 128);
		GetConVarString(CompLoader4v4HuntersConfig, cfg4v4hunters, 128);
		GetConVarString(CompLoader3v3HuntersConfig, cfg3v3hunters, 128);
		GetConVarString(CompLoader2v2HuntersConfig, cfg2v2hunters, 128);
		GetConVarString(CompLoader1v1HuntersConfig, cfg1v1hunters, 128);
		
		GetConVarString(CompLoader1v2HuntersConfig, cfg1v2hunters, 128);
		GetConVarString(CompLoader1v3HuntersConfig, cfg1v3hunters, 128);
		GetConVarString(CompLoader1v4HuntersConfig, cfg1v4hunters, 128);
		GetConVarString(CompLoader1v5HuntersConfig, cfg1v5hunters, 128);
		GetConVarString(CompLoader2v3HuntersConfig, cfg2v3hunters, 128);
		GetConVarString(CompLoader2v4HuntersConfig, cfg2v4hunters, 128);
		GetConVarString(CompLoader2v5HuntersConfig, cfg2v5hunters, 128);
		GetConVarString(CompLoader3v4HuntersConfig, cfg3v4hunters, 128);
		GetConVarString(CompLoader3v5HuntersConfig, cfg3v5hunters, 128);
		GetConVarString(CompLoader4v5HuntersConfig, cfg4v5hunters, 128);
		GetConVarString(CompLoaderWitchPartyConfig, cfgwitchparty, 128);
		GetConVarString(CompLoaderDarkCoopConfig  , cfgdarkcoop  , 128);
		#else
		GetConVarString(CompLoader1v1Config, cfg1v1, 128);
		#endif
		
		decl String:loadInfo[1024];
		if(isAdmin == true) Format(loadInfo, 1024, "| command          | force load               | config that gets loaded       |\n");
		else Format(loadInfo, 1024, "| command          | request to load          | config that gets loaded       |\n");
		Format(loadInfo, 1024, "%s|------------------|--------------------------|-------------------------------|\n",loadInfo);
		Format(loadInfo, 1024, "%s| !load 5v5        | 5v5 hardcore config      | %30s|\n", loadInfo, cfg5v5);
		Format(loadInfo, 1024, "%s| !load 4v4        | 4v4 hardcore config      | %30s|\n", loadInfo, cfg4v4);
		Format(loadInfo, 1024, "%s| !load 4v4 classic| 4v4 classic config       | %30s|\n", loadInfo, cfg4v4classic);
		Format(loadInfo, 1024, "%s| !load 3v3        | 3v3 hardcore config      | %30s|\n", loadInfo, cfg3v3);
		Format(loadInfo, 1024, "%s| !load 2v2        | 2v2 hardcore config      | %30s|\n", loadInfo, cfg2v2);
		PrintToConsole(client, loadInfo);
		#if FULL_VERSION
		if(isHunterAllowed == true)
		{
			Format(loadInfo, 1024, "| !load 5v5 hu     | 5v5 hunters only config  | %30s|\n", cfg5v5hunters);
			Format(loadInfo, 1024, "%s| !load 4v4 hu     | 4v4 hunters only config  | %30s|\n", loadInfo, cfg4v4hunters);
			Format(loadInfo, 1024, "%s| !load 3v3 hu     | 3v3 hunters only config  | %30s|\n", loadInfo, cfg3v3hunters);
			Format(loadInfo, 1024, "%s| !load 2v2 hu     | 2v2 hunters only config  | %30s|\n", loadInfo, cfg2v2hunters);
			Format(loadInfo, 1024, "%s| !load 1v1        | 1v1 hunters only config  | %30s|\n", loadInfo, cfg1v1hunters);
			PrintToConsole(client, loadInfo);
			
			Format(loadInfo, 1024, "| !load dc         | Dark Coop config         | %30s|\n", cfgdarkcoop);
			Format(loadInfo, 1024, "%s| !load wp         | Witch Party config       | %30s|\n", loadInfo, cfgwitchparty);
			Format(loadInfo, 1024, "%s| !load 1v2        | 1v2 hunters only config  | %30s|\n", loadInfo, cfg1v2hunters);
			Format(loadInfo, 1024, "%s| !load 1v3        | 1v3 hunters only config  | %30s|\n", loadInfo, cfg1v3hunters);
			Format(loadInfo, 1024, "%s| !load 1v4        | 1v4 hunters only config  | %30s|\n", loadInfo, cfg1v4hunters);
			Format(loadInfo, 1024, "%s| !load 1v5        | 1v5 hunters only config  | %30s|\n", loadInfo, cfg1v5hunters);
			Format(loadInfo, 1024, "%s| !load 2v3        | 2v3 hunters only config  | %30s|\n", loadInfo, cfg2v3hunters);
			Format(loadInfo, 1024, "%s| !load 2v4        | 2v4 hunters only config  | %30s|\n", loadInfo, cfg2v4hunters);
			Format(loadInfo, 1024, "%s| !load 2v5        | 2v5 hunters only config  | %30s|\n", loadInfo, cfg2v5hunters);
			Format(loadInfo, 1024, "%s| !load 3v4        | 3v4 hunters only config  | %30s|\n", loadInfo, cfg3v4hunters);
			Format(loadInfo, 1024, "%s| !load 3v5        | 3v5 hunters only config  | %30s|\n", loadInfo, cfg3v5hunters);
			Format(loadInfo, 1024, "%s| !load 4v5        | 4v5 hunters only config  | %30s|\n", loadInfo, cfg4v5hunters);
		}
		#else
		Format(loadInfo, 1024, "| !load 1v1        | 1v1 default config       | %30s|\n", cfg1v1);
		#endif
		PrintToConsole(client, loadInfo);
		if(isAdmin == true) Format(loadInfo, 1024, "| !load cancel     | cancel all requests      |                               |\n");
		else Format(loadInfo, 1024, "| !load cancel     | cancel the request       |                               |\n");
		Format(loadInfo, 1024, "%s|------------------|--------------------------|-------------------------------|", loadInfo);		
		
		ReplyToCommand(client, "[TS] %T","Check the console for available commands.",client);
		PrintToConsole(client, loadInfo);
		
		if(GetClientTeam(client)==1)
		{
			CPrintToChat(client, "[{olive}TS{default}] %T","Spectators cannot use command.",client,"!load");
			return Plugin_Handled;
		}
		if (!TestMatchDelay(client))
		{
			return Plugin_Handled;
		}
		ClientVoteMenuSet(client,1);
		MatchModeMenu(client);
		
		return Plugin_Handled;
	}
	if (id == true)		//if client is admin then
	{
		decl String:Admin_Cfg[128];			//Admin config is the string contents after "!load ", if sm_load was invoked by an admin
		decl String:AdminName[32];			//Admin name is the name of the admin that invoked sm_load
		
		GetClientName(client, AdminName, sizeof(AdminName));	//getting admin name
		GetCmdArgString(Admin_Cfg, sizeof(Admin_Cfg));			//getting the string value
		
		new AdminValueIsConfig5v5 = 0;		//is config 4v4 integer, on function start set to 0
		new AdminValueIsConfigClassic = 0;
		new AdminValueIsConfig4v4 = 0;		//is config 4v4 integer, on function start set to 0
		new AdminValueIsConfig3v3 = 0;		//is config 3v3 integer, on function start set to 0
		new AdminValueIsConfig2v2 = 0;		//is config 2v2 integer, on function start set to 0
		new AdminValueIsConfig1v1 = 0;		//is config 1v1 integer, on function start set to 0
	
		new AdminValueIsConfig1v2 = 0;		//is config 1v2 integer, on function start set to 0
		new AdminValueIsConfig1v3 = 0;		//is config 1v3 integer, on function start set to 0
		new AdminValueIsConfig1v4 = 0;		//is config 1v4 integer, on function start set to 0
		new AdminValueIsConfig1v5 = 0;		//is config 1v5 integer, on function start set to 0
		new AdminValueIsConfig2v3 = 0;		//is config 2v3 integer, on function start set to 0
		new AdminValueIsConfig2v4 = 0;		//is config 2v4 integer, on function start set to 0
		new AdminValueIsConfig2v5 = 0;		//is config 2v5 integer, on function start set to 0
		new AdminValueIsConfig3v4 = 0;		//is config 3v4 integer, on function start set to 0
		new AdminValueIsConfig3v5 = 0;		//is config 3v5 integer, on function start set to 0
		new AdminValueIsConfig4v5 = 0;		//is config 4v5 integer, on function start set to 0
		new AdminValueIsConfigwp = 0 ; 		//is config witchparty integer, on function start set to 0
		new AdminValueIsConfigdc = 0 ;
		#if FULL_VERSION
		new AdminValueIsConfigHunters = 0;	//is config hunters integer, on function start set to 0
		#endif
		#if NO_BOOMER_CFG
		new AdminValueIsConfigNoBoomer = 0;
		#endif
		new AdminValueSumOfConfigs = 0;		//is the sum of the configs more than 1, then config is invalid, on function start set to 0
		
		//IsConfigXvX Variables are declared below OnMapStart
		if((StrContains(Admin_Cfg, "5v5", false) != -1)) AdminValueIsConfig5v5 = 1;		//if string contains 5v5, set value to 1
		if((StrContains(Admin_Cfg, "4v4", false) != -1)) AdminValueIsConfig4v4 = 1;		//if string contains 4v4, set value to 1
		if((StrContains(Admin_Cfg, "3v3", false) != -1)) AdminValueIsConfig3v3 = 1;		//if string contains 3v3, set value to 1
		if((StrContains(Admin_Cfg, "2v2", false) != -1)) AdminValueIsConfig2v2 = 1;		//if string contains 2v2, set value to 1
		if((StrContains(Admin_Cfg, "1v1", false) != -1)) AdminValueIsConfig1v1 = 1;		//if string contains 1v1, set value to 1
		
		if((StrContains(Admin_Cfg, "1v2", false) != -1)) AdminValueIsConfig1v2 = 1;		//if string contains 1v2, set value to 1
		if((StrContains(Admin_Cfg, "1v3", false) != -1)) AdminValueIsConfig1v3 = 1;		//if string contains 1v3, set value to 1
		if((StrContains(Admin_Cfg, "1v4", false) != -1)) AdminValueIsConfig1v4 = 1;		//if string contains 1v4, set value to 1
		if((StrContains(Admin_Cfg, "1v5", false) != -1)) AdminValueIsConfig1v5 = 1;		//if string contains 1v5, set value to 1
		if((StrContains(Admin_Cfg, "2v3", false) != -1)) AdminValueIsConfig2v3 = 1;		//if string contains 2v3, set value to 1
		if((StrContains(Admin_Cfg, "2v4", false) != -1)) AdminValueIsConfig2v4 = 1;		//if string contains 2v4, set value to 1
		if((StrContains(Admin_Cfg, "2v5", false) != -1)) AdminValueIsConfig2v5 = 1;		//if string contains 2v5, set value to 1
		if((StrContains(Admin_Cfg, "3v4", false) != -1)) AdminValueIsConfig3v4 = 1;		//if string contains 3v4, set value to 1
		if((StrContains(Admin_Cfg, "3v5", false) != -1)) AdminValueIsConfig3v5 = 1;		//if string contains 3v5, set value to 1
		if((StrContains(Admin_Cfg, "4v5", false) != -1)) AdminValueIsConfig4v5 = 1;		//if string contains 4v5, set value to 1
		if((StrContains(Admin_Cfg, "wp", false) != -1)) AdminValueIsConfigwp = 1;		//if string contains witch party, set value to 1
		if((StrContains(Admin_Cfg, "witchparty", false) != -1)) AdminValueIsConfigwp = 1;		//if string contains witch party, set value to 1
		if((StrContains(Admin_Cfg, "WP", false) != -1)) AdminValueIsConfigwp = 1;		//if string contains witch party, set value to 1
		if((StrContains(Admin_Cfg, "WitchParty", false) != -1)) AdminValueIsConfigwp = 1;		//if string contains witch party, set value to 1
		
		if((StrContains(Admin_Cfg, "DC", false) != -1)) AdminValueIsConfigdc = 1;
		if((StrContains(Admin_Cfg, "dc", false) != -1)) AdminValueIsConfigdc = 1;
		if((StrContains(Admin_Cfg, "dark coop", false) != -1)) AdminValueIsConfigdc = 1;
		if((StrContains(Admin_Cfg, "Dark Coop", false) != -1)) AdminValueIsConfigdc = 1;
		
		if((StrContains(Admin_Cfg, "classic", false) != -1)) AdminValueIsConfigClassic = 1;	//if string contains hu, set value to 1
		if((StrContains(Admin_Cfg, "cl", false) != -1)) AdminValueIsConfigClassic = 1;	//if string contains hu, set value to 1	
		#if FULL_VERSION
		if((StrContains(Admin_Cfg, "hu", false) != -1)) AdminValueIsConfigHunters = 1;	//if string contains hu, set value to 1	
		#endif
		#if NO_BOOMER_CFG
		if((StrContains(Admin_Cfg, "nob", false) != -1)) AdminValueIsConfigNoBoomer = 1;	//if string contains hu, set value to 1
		if((StrContains(Admin_Cfg, "no", false) != -1)) AdminValueIsConfigNoBoomer = 1;	//if string contains hu, set value to 1	
		if((StrContains(Admin_Cfg, "nb", false) != -1)) AdminValueIsConfigNoBoomer = 1;	//if string contains hu, set value to 1	
		#endif
		
		AdminValueSumOfConfigs = AdminValueIsConfig5v5 + AdminValueIsConfig4v4 + AdminValueIsConfig3v3 + AdminValueIsConfig2v2 + AdminValueIsConfig1v1
		+ AdminValueIsConfig1v2 + AdminValueIsConfig1v3 + AdminValueIsConfig1v4 + AdminValueIsConfig1v5
		+ AdminValueIsConfig2v3 + AdminValueIsConfig2v4 + AdminValueIsConfig2v5
		+ AdminValueIsConfig3v4 + AdminValueIsConfig3v5 + AdminValueIsConfig4v5 + AdminValueIsConfigwp + AdminValueIsConfigdc;//calculate the sum of all the config value integers
		
		if(StrEqual(Admin_Cfg, "cancel", false))//checking if config is cancel, if it is, cancel this plugin, and jump to the admin config, stop this plugin
		{
			Admin_Cancel(client);
			return Plugin_Handled;
		}
	
				
		if(AdminValueSumOfConfigs == 1)//if the sum of the config value integers = 1 then...
		{	
			hasprepareloaded = true;
			adminLoadActive = true;
			if(AdminValueIsConfig5v5 == 1)	//if the config is 5v5
			{
				#if NO_BOOMER_CFG
				if(AdminValueIsConfigNoBoomer == 1)
				{
					SetConVarInt(FindConVar("comp_loader_load_active"), 0);
					SetConVarInt(FindConVar("comp_loader_map_active"), 0);
					GetConVarString(CompLoader5v5NobConfig, AdminLoadCommandConfigToExecuteName, 128);
					CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t", AdminName,"comp_loader2","5v5 No Boomer");
					
					Admin_Cancel_Lite();
					
					CreateTimer(3.0, Timer_Admin_Load_Config, TIMER_FLAG_NO_MAPCHANGE);
					return Plugin_Handled;					
				}
				#endif
				#if FULL_VERSION
				if(AdminValueIsConfigHunters == 0)
				{
					SetConVarInt(FindConVar("comp_loader_load_active"), 0);
					SetConVarInt(FindConVar("comp_loader_map_active"), 0);
					GetConVarString(CompLoader5v5Config, AdminLoadCommandConfigToExecuteName, 128);
					CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader2","5v5 hardcore");
					
					Admin_Cancel_Lite();
					
					CreateTimer(3.0, Timer_Admin_Load_Config, TIMER_FLAG_NO_MAPCHANGE);
					return Plugin_Handled;					
				}
				else 
				{
					SetConVarInt(FindConVar("comp_loader_load_active"), 0);
					SetConVarInt(FindConVar("comp_loader_map_active"), 0);
					GetConVarString(CompLoader5v5HuntersConfig, AdminLoadCommandConfigToExecuteName, 128);
					CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t", AdminName,"comp_loader2","5v5 Hunters Only");	//if hunters allowed 0
					
					Admin_Cancel_Lite();
					
					CreateTimer(3.0, Timer_Admin_Load_Config, TIMER_FLAG_NO_MAPCHANGE);
					return Plugin_Handled;
				}
				#else
				SetConVarInt(FindConVar("comp_loader_load_active"), 0);
				SetConVarInt(FindConVar("comp_loader_map_active"), 0);
				GetConVarString(CompLoader5v5Config, AdminLoadCommandConfigToExecuteName, 128);
				CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader2","5v5 hardcore");
				
				Admin_Cancel_Lite();
				
				CreateTimer(3.0, Timer_Admin_Load_Config, TIMER_FLAG_NO_MAPCHANGE);
				return Plugin_Handled;
				#endif
			}
			if(AdminValueIsConfig4v4 == 1)	//if the config is 4v4
			{
				#if NO_BOOMER_CFG
				if(AdminValueIsConfigNoBoomer == 1)
				{
					SetConVarInt(FindConVar("comp_loader_load_active"), 0);
					SetConVarInt(FindConVar("comp_loader_map_active"), 0);
					GetConVarString(CompLoader4v4NobConfig, AdminLoadCommandConfigToExecuteName, 128);
					CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader2","4v4 No Boomer");
				
					Admin_Cancel_Lite();
				
					CreateTimer(3.0, Timer_Admin_Load_Config, TIMER_FLAG_NO_MAPCHANGE);
					return Plugin_Handled;					
				}
				#endif
				#if FULL_VERSION
				if(AdminValueIsConfigHunters == 1)
				{
					SetConVarInt(FindConVar("comp_loader_load_active"), 0);
					SetConVarInt(FindConVar("comp_loader_map_active"), 0);
					GetConVarString(CompLoader4v4HuntersConfig, AdminLoadCommandConfigToExecuteName, 128);
					CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader2","4v4 Hunters Only");	//if hunters allowed 0
					
					Admin_Cancel_Lite();
					
					CreateTimer(3.0, Timer_Admin_Load_Config, TIMER_FLAG_NO_MAPCHANGE);
					return Plugin_Handled;				
				}
				#endif
				if(AdminValueIsConfigClassic == 1)
				{
					SetConVarInt(FindConVar("comp_loader_load_active"), 0);
					SetConVarInt(FindConVar("comp_loader_map_active"), 0);
					GetConVarString(CompLoader4v4ClassicConfig, AdminLoadCommandConfigToExecuteName, 128);
					CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader2","4v4 Classic");
					
					Admin_Cancel_Lite();
					
					CreateTimer(3.0, Timer_Admin_Load_Config, TIMER_FLAG_NO_MAPCHANGE);
					return Plugin_Handled;
				}
				else
				{
					SetConVarInt(FindConVar("comp_loader_load_active"), 0);
					SetConVarInt(FindConVar("comp_loader_map_active"), 0);
					GetConVarString(CompLoader4v4Config, AdminLoadCommandConfigToExecuteName, 128);
					CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader2","4v4 Hardcore");
					
					Admin_Cancel_Lite();
					
					CreateTimer(3.0, Timer_Admin_Load_Config, TIMER_FLAG_NO_MAPCHANGE);
					return Plugin_Handled;
				}
			}
			if(AdminValueIsConfig3v3 == 1)	//if the config is 3v3
			{
				#if NO_BOOMER_CFG
				if(AdminValueIsConfigNoBoomer == 1)
				{
					SetConVarInt(FindConVar("comp_loader_load_active"), 0);
					SetConVarInt(FindConVar("comp_loader_map_active"), 0);
					GetConVarString(CompLoader3v3NobConfig, AdminLoadCommandConfigToExecuteName, 128);
					CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader2","3v3 No Boomer");
					
					Admin_Cancel_Lite();
					
					CreateTimer(3.0, Timer_Admin_Load_Config, TIMER_FLAG_NO_MAPCHANGE);
					return Plugin_Handled;					
				}
				#endif
				#if FULL_VERSION
				if(AdminValueIsConfigHunters == 0)	//if hunters allowed 1
				{
					SetConVarInt(FindConVar("comp_loader_load_active"), 0);
					SetConVarInt(FindConVar("comp_loader_map_active"), 0);
					GetConVarString(CompLoader3v3Config, AdminLoadCommandConfigToExecuteName, 128);
					CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader2","3v3 hardcore");
					
					Admin_Cancel_Lite();
					
					CreateTimer(3.0, Timer_Admin_Load_Config, TIMER_FLAG_NO_MAPCHANGE);
					return Plugin_Handled;
				}
				else 
				{
					SetConVarInt(FindConVar("comp_loader_load_active"), 0);
					SetConVarInt(FindConVar("comp_loader_map_active"), 0);
					GetConVarString(CompLoader3v3HuntersConfig, AdminLoadCommandConfigToExecuteName, 128);
					CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader2","3v3 Hunters Only");	//if hunters allowed 0
					
					Admin_Cancel_Lite();
					
					CreateTimer(3.0, Timer_Admin_Load_Config, TIMER_FLAG_NO_MAPCHANGE);
					return Plugin_Handled;
				}
				#else
				SetConVarInt(FindConVar("comp_loader_load_active"), 0);
				SetConVarInt(FindConVar("comp_loader_map_active"), 0);
				GetConVarString(CompLoader3v3Config, AdminLoadCommandConfigToExecuteName, 128);
				CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader2","3v3 hardcore");
				
				Admin_Cancel_Lite();
				
				CreateTimer(3.0, Timer_Admin_Load_Config, TIMER_FLAG_NO_MAPCHANGE);
				return Plugin_Handled;
				#endif
			}
			if(AdminValueIsConfig2v2 == 1)	//if the config is 2v2
			{
				#if NO_BOOMER_CFG
				if(AdminValueIsConfigNoBoomer == 1)
				{
					SetConVarInt(FindConVar("comp_loader_load_active"), 0);
					SetConVarInt(FindConVar("comp_loader_map_active"), 0);
					GetConVarString(CompLoader2v2NobConfig, AdminLoadCommandConfigToExecuteName, 128);
					CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader2","2v2 No Boomer");
					
					Admin_Cancel_Lite();
					
					CreateTimer(3.0, Timer_Admin_Load_Config, TIMER_FLAG_NO_MAPCHANGE);
					return Plugin_Handled;					
				}
				#endif
				#if FULL_VERSION
				if(AdminValueIsConfigHunters == 0)	//if hunters allowed 1
				{
					SetConVarInt(FindConVar("comp_loader_load_active"), 0);
					SetConVarInt(FindConVar("comp_loader_map_active"), 0);
					GetConVarString(CompLoader2v2Config, AdminLoadCommandConfigToExecuteName, 128);
					CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader2","2v2 hardcore");
					
					Admin_Cancel_Lite();
					
					CreateTimer(3.0, Timer_Admin_Load_Config, TIMER_FLAG_NO_MAPCHANGE);
					return Plugin_Handled;
				}
				else 
				{
					SetConVarInt(FindConVar("comp_loader_load_active"), 0);
					SetConVarInt(FindConVar("comp_loader_map_active"), 0);
					GetConVarString(CompLoader2v2HuntersConfig, AdminLoadCommandConfigToExecuteName, 128);
					CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader2","2v2 Hunters Only");	//if hunters allowed 0
					
					Admin_Cancel_Lite();
					
					CreateTimer(3.0, Timer_Admin_Load_Config, TIMER_FLAG_NO_MAPCHANGE);
					return Plugin_Handled;
				}
				#else
				SetConVarInt(FindConVar("comp_loader_load_active"), 0);
				SetConVarInt(FindConVar("comp_loader_map_active"), 0);
				GetConVarString(CompLoader2v2Config, AdminLoadCommandConfigToExecuteName, 128);
				CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader2","2v2 hardcore");
				
				Admin_Cancel_Lite();
				
				CreateTimer(3.0, Timer_Admin_Load_Config, TIMER_FLAG_NO_MAPCHANGE);
				return Plugin_Handled;
				#endif
			}
			if(AdminValueIsConfig1v1 == 1)	//if the config is 1v1
			{
				#if FULL_VERSION
				SetConVarInt(FindConVar("comp_loader_load_active"), 0);
				SetConVarInt(FindConVar("comp_loader_map_active"), 0);
				GetConVarString(CompLoader1v1HuntersConfig, AdminLoadCommandConfigToExecuteName, 128);
				CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader2","1v1 Hunters Only");
				CreateTimer(3.0, Timer_Admin_Load_Config, TIMER_FLAG_NO_MAPCHANGE);
				return Plugin_Handled;
				#else
	
				#endif
			}
			
			if(AdminValueIsConfig1v2 == 1)	//if the config is 1v2
			{
				#if FULL_VERSION
				SetConVarInt(FindConVar("comp_loader_load_active"), 0);
				SetConVarInt(FindConVar("comp_loader_map_active"), 0);
				GetConVarString(CompLoader1v2HuntersConfig, AdminLoadCommandConfigToExecuteName, 128);
				CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader2","1v2 Hunters Only");
				CreateTimer(3.0, Timer_Admin_Load_Config, TIMER_FLAG_NO_MAPCHANGE);
				return Plugin_Handled;
				#else

				#endif
			}
			if(AdminValueIsConfig1v3 == 1)	//if the config is 1v3
			{
				#if FULL_VERSION
				SetConVarInt(FindConVar("comp_loader_load_active"), 0);
				SetConVarInt(FindConVar("comp_loader_map_active"), 0);
				GetConVarString(CompLoader1v3HuntersConfig, AdminLoadCommandConfigToExecuteName, 128);
				CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader2","1v3 Hunters Only");
				CreateTimer(3.0, Timer_Admin_Load_Config, TIMER_FLAG_NO_MAPCHANGE);
				return Plugin_Handled;
				#else

				#endif
			}
			if(AdminValueIsConfig1v4 == 1)	//if the config is 1v4
			{
				#if FULL_VERSION
				SetConVarInt(FindConVar("comp_loader_load_active"), 0);
				SetConVarInt(FindConVar("comp_loader_map_active"), 0);
				GetConVarString(CompLoader1v4HuntersConfig, AdminLoadCommandConfigToExecuteName, 128);
				CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader2","1v4 Hunters Only");
				CreateTimer(3.0, Timer_Admin_Load_Config, TIMER_FLAG_NO_MAPCHANGE);
				return Plugin_Handled;
				#else

				#endif
			}			
			if(AdminValueIsConfig1v5 == 1)	//if the config is 1v5
			{
				#if FULL_VERSION
				SetConVarInt(FindConVar("comp_loader_load_active"), 0);
				SetConVarInt(FindConVar("comp_loader_map_active"), 0);
				GetConVarString(CompLoader1v5HuntersConfig, AdminLoadCommandConfigToExecuteName, 128);
				CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader2","1v5 Hunters Only");
				CreateTimer(3.0, Timer_Admin_Load_Config, TIMER_FLAG_NO_MAPCHANGE);
				return Plugin_Handled;
				#else

				#endif
			}			
			if(AdminValueIsConfig2v3 == 1)	//if the config is 2v3
			{
				#if FULL_VERSION
				SetConVarInt(FindConVar("comp_loader_load_active"), 0);
				SetConVarInt(FindConVar("comp_loader_map_active"), 0);
				GetConVarString(CompLoader2v3HuntersConfig, AdminLoadCommandConfigToExecuteName, 128);
				CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader2","2v3 Hunters Only");
				CreateTimer(3.0, Timer_Admin_Load_Config, TIMER_FLAG_NO_MAPCHANGE);
				return Plugin_Handled;
				#else

				#endif
			}
			if(AdminValueIsConfig2v4 == 1)	//if the config is 2v4
			{
				#if FULL_VERSION
				SetConVarInt(FindConVar("comp_loader_load_active"), 0);
				SetConVarInt(FindConVar("comp_loader_map_active"), 0);
				GetConVarString(CompLoader2v4HuntersConfig, AdminLoadCommandConfigToExecuteName, 128);
				CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader2","2v4 Hunters Only");
				CreateTimer(3.0, Timer_Admin_Load_Config, TIMER_FLAG_NO_MAPCHANGE);
				return Plugin_Handled;
				#else

				#endif
			}
			if(AdminValueIsConfig2v5 == 1)	//if the config is 2v5
			{
				#if FULL_VERSION
				SetConVarInt(FindConVar("comp_loader_load_active"), 0);
				SetConVarInt(FindConVar("comp_loader_map_active"), 0);
				GetConVarString(CompLoader2v5HuntersConfig, AdminLoadCommandConfigToExecuteName, 128);
				CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader2","2v5 Hunters Only");
				CreateTimer(3.0, Timer_Admin_Load_Config, TIMER_FLAG_NO_MAPCHANGE);
				return Plugin_Handled;
				#else

				#endif
			}
			if(AdminValueIsConfig3v4 == 1)	//if the config is 3v4
			{
				#if FULL_VERSION
				SetConVarInt(FindConVar("comp_loader_load_active"), 0);
				SetConVarInt(FindConVar("comp_loader_map_active"), 0);
				GetConVarString(CompLoader3v4HuntersConfig, AdminLoadCommandConfigToExecuteName, 128);
				CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader2","3v4 Hunters Only");
				CreateTimer(3.0, Timer_Admin_Load_Config, TIMER_FLAG_NO_MAPCHANGE);
				return Plugin_Handled;
				#else

				#endif
			}
			if(AdminValueIsConfig3v5 == 1)	//if the config is 3v5
			{
				#if FULL_VERSION
				SetConVarInt(FindConVar("comp_loader_load_active"), 0);
				SetConVarInt(FindConVar("comp_loader_map_active"), 0);
				GetConVarString(CompLoader3v5HuntersConfig, AdminLoadCommandConfigToExecuteName, 128);
				CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader2","3v5 Hunters Only");
				CreateTimer(3.0, Timer_Admin_Load_Config, TIMER_FLAG_NO_MAPCHANGE);
				return Plugin_Handled;
				#else

				#endif
			}
			if(AdminValueIsConfig4v5 == 1)	//if the config is 4v5
			{
				#if FULL_VERSION
				SetConVarInt(FindConVar("comp_loader_load_active"), 0);
				SetConVarInt(FindConVar("comp_loader_map_active"), 0);
				GetConVarString(CompLoader4v5HuntersConfig, AdminLoadCommandConfigToExecuteName, 128);
				CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader2","4v5 Hunters Only");
				CreateTimer(3.0, Timer_Admin_Load_Config, TIMER_FLAG_NO_MAPCHANGE);
				return Plugin_Handled;
				#else

				#endif
			}
			if(AdminValueIsConfigwp == 1)	//if the config is witch party
			{
				#if FULL_VERSION
				SetConVarInt(FindConVar("comp_loader_load_active"), 0);
				SetConVarInt(FindConVar("comp_loader_map_active"), 0);
				GetConVarString(CompLoaderWitchPartyConfig, AdminLoadCommandConfigToExecuteName, 128);
				CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader2","Witch Party");
				CreateTimer(3.0, Timer_Admin_Load_Config, TIMER_FLAG_NO_MAPCHANGE);
				return Plugin_Handled;
				#else

				#endif
			}
			if(AdminValueIsConfigdc == 1)	//if the config is witch party
			{
				#if FULL_VERSION
				SetConVarInt(FindConVar("comp_loader_load_active"), 0);
				SetConVarInt(FindConVar("comp_loader_map_active"), 0);
				GetConVarString(CompLoaderDarkCoopConfig, AdminLoadCommandConfigToExecuteName, 128);
				CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader2","Dark Coop");
				CreateTimer(3.0, Timer_Admin_Load_Config, TIMER_FLAG_NO_MAPCHANGE);
				return Plugin_Handled;
				#else

				#endif
			}
		}
		else
		{
			CPrintToChat(client, "[{olive}TS{default}] %T","Invalid Config.",client);	//debug, prints admin name, and the config entered *now prints to admin invalid config
		}
	}
	if (id == false)	//if client is non admin then...
	{
		new Client_Team		= GetClientTeam(client),
		Opposite_Team	= (Client_Team == TEAM_SURVIVOR) ? TEAM_INFECTED : TEAM_SURVIVOR;	//getting dem client teamz. If client team is survivor, then opposite team is infected, else opposite team is survivorzor
		
		decl String:SurvivorCfg[128];		//gets string value of PlayerCfg when Team A requests !load
		decl String:InfectedCfg[128];		//gets string value of PlayerCfg when Team B requests !load

		decl String:LoadIsAllowed[2];		//Temp string to get the convar value of comp_loader_allow_load 1 / 0
		#if FULL_VERSION
		decl String:HunterIsAllowed[2];		//Temp string to get the convar value of comp_loader_allow_hunters 1 / 0
		#endif
		GetConVarString(CompLoaderAllowLoad, LoadIsAllowed, 2);				//setting the value of the convar to the string
		#if FULL_VERSION
		GetConVarString(CompLoaderAllowHuntersOnly, HunterIsAllowed, 2);	//setting the value of the convar to the string
		#endif
		new LoadAllowed = StringToInt(LoadIsAllowed);		//converting the string value to integer
		#if FULL_VERSION
		new HunterAllowed = StringToInt(HunterIsAllowed);	//converting the string value to integer
		#endif
		if(LoadAllowed != 0)		//if comp_loader_load_allowed = 1
		{
			//LogMessage("LoadAllowed returned 1");	//debug, log to file that comp_loader_load_allowed = 1
			if(Client_Team == TEAM_SURVIVOR || Client_Team == TEAM_INFECTED)	//if the client using !load is either survivor or infected
			{
				if(adminLoadActive == true) return Plugin_Handled;
				if(adminCancel == true)
				{
					CPrintToChat(client, "[{olive}TS{default}] %T","command is not available.",client,"!load");
					return Plugin_Handled;
				}
				GetCmdArgString(PlayerCfg, sizeof(PlayerCfg));			//getting the !load arguments to PlayerCfg string
				new ValueIsConfig5v5 = 0;		//is config 5v5 integer, on function start set to 0
				new ValueIsConfigClassic = 0;
				new ValueIsConfig4v4 = 0;		//is config 4v4 integer, on function start set to 0
				new ValueIsConfig3v3 = 0;		//is config 3v3 integer, on function start set to 0
				new ValueIsConfig2v2 = 0;		//is config 2v2 integer, on function start set to 0
				new ValueIsConfig1v1 = 0;		//is config 1v1 integer, on function start set to 0
				
				new ValueIsConfig1v2 = 0;		//is config 1v2 integer, on function start set to 0
				new ValueIsConfig1v3 = 0;		//is config 1v3 integer, on function start set to 0
				new ValueIsConfig1v4 = 0;		//is config 1v4 integer, on function start set to 0
				new ValueIsConfig1v5 = 0;		//is config 1v5 integer, on function start set to 0
				new ValueIsConfig2v3 = 0;		//is config 2v3 integer, on function start set to 0
				new ValueIsConfig2v4 = 0;		//is config 2v4 integer, on function start set to 0
				new ValueIsConfig2v5 = 0;		//is config 2v5 integer, on function start set to 0
				new ValueIsConfig3v4 = 0;		//is config 3v4 integer, on function start set to 0
				new ValueIsConfig3v5 = 0;		//is config 3v5 integer, on function start set to 0
				new ValueIsConfig4v5 = 0;		//is config 4v5 integer, on function start set to 0
				new ValueIsConfigwp = 0; //is config witch party integer, on function start set to 0
				new ValueIsConfigdc = 0;
				
				#if FULL_VERSION
				new ValueIsConfigHunters = 0;	//is config hunters integer, on function start set to 0
				#endif
				#if NO_BOOMER_CFG
				new ValueIsConfigNoBoomer = 0;
				#endif
				new ValueSumOfConfigs = 0;		//is the sum of the configs more than 1, then config is invalid, on function start set to 0
						
				if((StrContains(PlayerCfg, "5v5", false) != -1)) ValueIsConfig5v5 = 1;		//if string contains 4v4, set value to 1
				if((StrContains(PlayerCfg, "4v4", false) != -1)) ValueIsConfig4v4 = 1;		//if string contains 4v4, set value to 1
				if((StrContains(PlayerCfg, "3v3", false) != -1)) ValueIsConfig3v3 = 1;		//if string contains 3v3, set value to 1
				if((StrContains(PlayerCfg, "2v2", false) != -1)) ValueIsConfig2v2 = 1;		//if string contains 2v2, set value to 1
				if((StrContains(PlayerCfg, "1v1", false) != -1)) ValueIsConfig1v1 = 1;		//if string contains 1v1, set value to 1
				
				if((StrContains(PlayerCfg, "1v2", false) != -1)) ValueIsConfig1v2 = 1;		//if string contains 1v2, set value to 1
				if((StrContains(PlayerCfg, "1v3", false) != -1)) ValueIsConfig1v3 = 1;		//if string contains 1v3, set value to 1
				if((StrContains(PlayerCfg, "1v4", false) != -1)) ValueIsConfig1v4 = 1;		//if string contains 1v4, set value to 1
				if((StrContains(PlayerCfg, "1v5", false) != -1)) ValueIsConfig1v5 = 1;		//if string contains 1v5, set value to 1
				if((StrContains(PlayerCfg, "2v3", false) != -1)) ValueIsConfig2v3 = 1;		//if string contains 2v3, set value to 1
				if((StrContains(PlayerCfg, "2v4", false) != -1)) ValueIsConfig2v4 = 1;		//if string contains 2v4, set value to 1
				if((StrContains(PlayerCfg, "2v5", false) != -1)) ValueIsConfig2v5 = 1;		//if string contains 2v5, set value to 1
				if((StrContains(PlayerCfg, "3v4", false) != -1)) ValueIsConfig3v4 = 1;		//if string contains 3v4, set value to 1
				if((StrContains(PlayerCfg, "3v5", false) != -1)) ValueIsConfig3v5 = 1;		//if string contains 3v5, set value to 1
				if((StrContains(PlayerCfg, "4v5", false) != -1)) ValueIsConfig4v5 = 1;		//if string contains 4v5, set value to 1
				if((StrContains(PlayerCfg, "wp", false) != -1)) ValueIsConfigwp = 1;		//if string contains 4v5, set value to 1
				if((StrContains(PlayerCfg, "witchparty", false) != -1))ValueIsConfigwp = 1;		//if string contains witch party, set value to 1
				if((StrContains(PlayerCfg, "WP", false) != -1)) ValueIsConfigwp = 1;		//if string contains witch party, set value to 1
				if((StrContains(PlayerCfg, "WitchParty", false) != -1)) ValueIsConfigwp = 1;		//if string contains witch party, set value to 1
				
				if((StrContains(PlayerCfg, "DC", false) != -1)) ValueIsConfigdc = 1;
				if((StrContains(PlayerCfg, "dc", false) != -1)) ValueIsConfigdc = 1;
				if((StrContains(PlayerCfg, "dark coop", false) != -1)) ValueIsConfigdc = 1;
				if((StrContains(PlayerCfg, "Dark Coop", false) != -1)) ValueIsConfigdc = 1;
				
				if((StrContains(PlayerCfg, "classic", false) != -1)) ValueIsConfigClassic = 1;	//if string contains hu, set value to 1
				if((StrContains(PlayerCfg, "cl", false) != -1)) ValueIsConfigClassic = 1;	//if string contains hu, set value to 1	
				#if FULL_VERSION
				if((StrContains(PlayerCfg, "hu", false) != -1)) ValueIsConfigHunters = 1;	//if string contains hu, set value to 1
				#endif
				#if NO_BOOMER_CFG
				if((StrContains(PlayerCfg, "nob", false) != -1)) ValueIsConfigNoBoomer = 1;	//if string contains hu, set value to 1
				if((StrContains(PlayerCfg, "no", false) != -1)) ValueIsConfigNoBoomer = 1;	//if string contains hu, set value to 1	
				if((StrContains(PlayerCfg, "nb", false) != -1)) ValueIsConfigNoBoomer = 1;	//if string contains hu, set value to 1	
				#endif
				ValueSumOfConfigs = ValueIsConfig5v5 + ValueIsConfig4v4 + ValueIsConfig3v3 + ValueIsConfig2v2 + ValueIsConfig1v1
				+ ValueIsConfig1v2 + ValueIsConfig1v3+ ValueIsConfig1v4 + ValueIsConfig1v5 
				+ ValueIsConfig2v3 + ValueIsConfig2v4 + ValueIsConfig2v5 
				+ ValueIsConfig3v4 + ValueIsConfig3v5 + ValueIsConfig4v5 + ValueIsConfigwp + ValueIsConfigdc;//calculate the sum of all the config value integers
				
				if(StrEqual(PlayerCfg, "cancel", false))//cancel configs before validating config, if the args are "cancel"
				{
					if(Config_Requests[Client_Team])
					{
						CPrintToChatAll("[{olive}TS{default}] %t","The team have canceled the command request.", Team_Names[Client_Team],"!load");
						Config_Requests[TEAM_SURVIVOR] = false;
						Config_Requests[TEAM_INFECTED] = false;
						SetConVarInt(FindConVar("comp_loader_load_active"), 0);
						return Plugin_Handled;						
					}
					if(Config_Requests[Opposite_Team] && !Config_Requests[Client_Team])
					{
						CPrintToChatAll("[{olive}TS{default}] %t","The team have canceled the command request.", Team_Names[Client_Team],"!load");
						Config_Requests[TEAM_SURVIVOR] = false;
						Config_Requests[TEAM_INFECTED] = false;
						SetConVarInt(FindConVar("comp_loader_load_active"), 0);
						return Plugin_Handled;
					}
					if(!Config_Requests[Opposite_Team])
					{
						CPrintToChat(client, "[{olive}TS{default}] %T","Nothing to cancel.",client);
						return Plugin_Handled;
					}
					return Plugin_Handled;
				}
				
				if(ValueSumOfConfigs == 1)	//if the sum of the config value integers = 1 then...
				{	
					if(ValueIsConfig5v5 == 1)	//if the config is 5v5
					{
						#if FULL_VERSION
						if(ValueIsConfigHunters != 1)	//if config is hunters 0
						{
							PlayerCfg = "5v5";
						}
						else PlayerCfg = "5v5 Hunter";	//if config is hunters 1
						#else
						PlayerCfg = "5v5";
						#endif
						#if NO_BOOMER_CFG
						if(ValueIsConfigNoBoomer == 1)	PlayerCfg = "5v5 No Boomer"; //if config is no boomer						
						#endif
					}
					if(ValueIsConfig4v4 == 1)	//if the config is 4v4
					{
						#if FULL_VERSION
						if(ValueIsConfigHunters != 1)	//if config is hunters 0
						{
							if(ValueIsConfigClassic == 1)
								PlayerCfg = "4v4 Classic";
							else
								PlayerCfg = "4v4";
						}
						else PlayerCfg = "4v4 Hunter";	//if config is hunters 1
						#else
						PlayerCfg = "4v4";
						#endif
						#if NO_BOOMER_CFG
						if(ValueIsConfigNoBoomer == 1)	PlayerCfg = "4v4 No Boomer"; //if config is no boomer						
						#endif
					}
					if(ValueIsConfig3v3 == 1)	//if the config is 3v3
					{
						#if FULL_VERSION
						if(ValueIsConfigHunters != 1)	//if config is hunters 0
						{
							PlayerCfg = "3v3";
						}
						else PlayerCfg = "3v3 Hunter";	//if config is hunters 1
						#else
						PlayerCfg = "3v3";
						#endif
						#if NO_BOOMER_CFG
						if(ValueIsConfigNoBoomer == 1)	PlayerCfg = "3v3 No Boomer"; //if config is no boomer						
						#endif
					}
					if(ValueIsConfig2v2 == 1)	//if the config is 2v2
					{
						#if FULL_VERSION
						if(ValueIsConfigHunters != 1)	//if config is hunters 0
						{
							PlayerCfg = "2v2";
						}
						else PlayerCfg = "2v2 Hunter";	//if config is hunters 1
						#else
						PlayerCfg = "2v2";
						#endif
						#if NO_BOOMER_CFG
						if(ValueIsConfigNoBoomer == 1)	PlayerCfg = "2v2 No Boomer"; //if config is no boomer						
						#endif
					}
					if(ValueIsConfig1v1 == 1)	//if the config is 1v1, defaults to hunter only because 1v1 is always hunter only
					{
						PlayerCfg = "1v1";
					}
					
					if(ValueIsConfig1v2 == 1)	//if the config is 1v2, defaults to hunter only because 1v2 is always hunter only
					{
						PlayerCfg = "1v2";
					}
					if(ValueIsConfig1v3 == 1)	//if the config is 1v3, defaults to hunter only because 1v3 is always hunter only
					{
						PlayerCfg = "1v3";
					}
					if(ValueIsConfig1v4 == 1)	//if the config is 1v4, defaults to hunter only because 1v4 is always hunter only
					{
						PlayerCfg = "1v4";
					}
					if(ValueIsConfig1v5 == 1)	//if the config is 1v5, defaults to hunter only because 1v5 is always hunter only
					{
						PlayerCfg = "1v5";
					}
					if(ValueIsConfig2v3 == 1)	//if the config is 2v3, defaults to hunter only because 2v3 is always hunter only
					{
						PlayerCfg = "2v3";
					}
					if(ValueIsConfig2v4 == 1)	//if the config is 2v4, defaults to hunter only because 2v4 is always hunter only
					{
						PlayerCfg = "2v4";
					}
					if(ValueIsConfig2v5 == 1)	//if the config is 2v5, defaults to hunter only because 2v5 is always hunter only
					{
						PlayerCfg = "2v5";
					}
					if(ValueIsConfig3v4 == 1)	//if the config is 3v4, defaults to hunter only because 3v4 is always hunter only
					{
						PlayerCfg = "3v4";
					}
					if(ValueIsConfig3v5 == 1)	//if the config is 3v5, defaults to hunter only because 3v5 is always hunter only
					{
						PlayerCfg = "3v5";
					}
					if(ValueIsConfig4v5 == 1)	//if the config is 4v5, defaults to hunter only because 4v5 is always hunter only
					{
						PlayerCfg = "4v5";
					}
					if(ValueIsConfigwp == 1)
					{
						PlayerCfg = "wp";
					}
					if(ValueIsConfigdc == 1)
					{
						PlayerCfg = "dc";
					}
				}
				else
				{
					CPrintToChatAll("[{olive}TS{default}] %t","Invalid Config."); //if sum of configs is less than 1 or more than 2, print invalid config
					return Plugin_Handled;
				}								
				if(!Config_Requests[Opposite_Team] == false)
				{
					SurvivorCfg = PlayerCfg;	//OppositeTeam argument string gets saved to SurvivorCfg
				}			
				else if(!Config_Requests[Client_Team] == true)
				{
					InfectedCfg = PlayerCfg;	//ClientTeam argument string gets saved to InfectedCfg
				}
				
				if (!TestMatchDelay(client))
				{
					return Plugin_Handled;	
				}
				
				#if FULL_VERSION
				if(HunterAllowed == 1)								//if comp_loader_allow_hunters 1 then...
				{
					if(StrEqual(PlayerCfg, "5v5", false))
					{
						GetConVarString(CompLoader5v5Config, LoadCommandConfigToExecuteName, 128);																	
					}
					if(StrEqual(PlayerCfg, "4v4 Classic", false))
					{
						GetConVarString(CompLoader4v4ClassicConfig, LoadCommandConfigToExecuteName, 128);																		
					}
					if(StrEqual(PlayerCfg, "4v4", false))
					{
						GetConVarString(CompLoader4v4Config, LoadCommandConfigToExecuteName, 128);																	
					}
					if(StrEqual(PlayerCfg, "3v3", false))
					{
						GetConVarString(CompLoader3v3Config, LoadCommandConfigToExecuteName, 128);																	
					}
					if(StrEqual(PlayerCfg, "2v2", false))
					{
						GetConVarString(CompLoader2v2Config, LoadCommandConfigToExecuteName, 128);																		
					}
					#if NO_BOOMER_CFG
					if(StrEqual(PlayerCfg, "5v5 No Boomer", false))
					{
						GetConVarString(CompLoader4v4NobConfig, LoadCommandConfigToExecuteName, 128);																	
					}
					if(StrEqual(PlayerCfg, "4v4 No Boomer", false))
					{
						GetConVarString(CompLoader4v4NobConfig, LoadCommandConfigToExecuteName, 128);																		
					}
					if(StrEqual(PlayerCfg, "3v3 No Boomer", false))
					{
						GetConVarString(CompLoader3v3NobConfig, LoadCommandConfigToExecuteName, 128);																	
					}
					if(StrEqual(PlayerCfg, "2v2 No Boomer", false))
					{
						GetConVarString(CompLoader2v2NobConfig, LoadCommandConfigToExecuteName, 128);																		
					}
					#endif
					if(StrEqual(PlayerCfg, "1v1", false))
					{
						GetConVarString(CompLoader1v1HuntersConfig, LoadCommandConfigToExecuteName, 128);																		
					}
					
					if(StrEqual(PlayerCfg, "1v2", false))
					{
						GetConVarString(CompLoader1v2HuntersConfig, LoadCommandConfigToExecuteName, 128);																		
					}
					if(StrEqual(PlayerCfg, "1v3", false))
					{
						GetConVarString(CompLoader1v3HuntersConfig, LoadCommandConfigToExecuteName, 128);																		
					}
					if(StrEqual(PlayerCfg, "1v4", false))
					{
						GetConVarString(CompLoader1v4HuntersConfig, LoadCommandConfigToExecuteName, 128);																		
					}
					if(StrEqual(PlayerCfg, "1v5", false))
					{
						GetConVarString(CompLoader1v5HuntersConfig, LoadCommandConfigToExecuteName, 128);																		
					}
					if(StrEqual(PlayerCfg, "2v3", false))
					{
						GetConVarString(CompLoader2v3HuntersConfig, LoadCommandConfigToExecuteName, 128);																		
					}
					if(StrEqual(PlayerCfg, "2v4", false))
					{
						GetConVarString(CompLoader2v4HuntersConfig, LoadCommandConfigToExecuteName, 128);																		
					}
					if(StrEqual(PlayerCfg, "2v5", false))
					{
						GetConVarString(CompLoader2v5HuntersConfig, LoadCommandConfigToExecuteName, 128);																		
					}
					if(StrEqual(PlayerCfg, "3v4", false))
					{
						GetConVarString(CompLoader3v4HuntersConfig, LoadCommandConfigToExecuteName, 128);																		
					}
					if(StrEqual(PlayerCfg, "3v5", false))
					{
						GetConVarString(CompLoader3v5HuntersConfig, LoadCommandConfigToExecuteName, 128);																		
					}
					if(StrEqual(PlayerCfg, "4v5", false))
					{
						GetConVarString(CompLoader4v5HuntersConfig, LoadCommandConfigToExecuteName, 128);																		
					}
					if(StrEqual(PlayerCfg, "wp", false))
					{
						GetConVarString(CompLoaderWitchPartyConfig, LoadCommandConfigToExecuteName, 128);																		
					}
					if(StrEqual(PlayerCfg, "dc", false))
					{
						GetConVarString(CompLoaderDarkCoopConfig, LoadCommandConfigToExecuteName, 128);																		
					}
					
					if(StrEqual(PlayerCfg, "5v5 Hunter", false))
					{
						GetConVarString(CompLoader5v5HuntersConfig, LoadCommandConfigToExecuteName, 128);																	
					}
					if(StrEqual(PlayerCfg, "4v4 Hunter", false))
					{
						GetConVarString(CompLoader4v4HuntersConfig, LoadCommandConfigToExecuteName, 128);																		
					}
					if(StrEqual(PlayerCfg, "3v3 Hunter", false))
					{
						GetConVarString(CompLoader3v3HuntersConfig, LoadCommandConfigToExecuteName, 128);																		
					}
					if(StrEqual(PlayerCfg, "2v2 Hunter", false))
					{
						GetConVarString(CompLoader2v2HuntersConfig, LoadCommandConfigToExecuteName, 128);																		
					}
					//else LogMessage("[Debug] Hunter is allowed, but failed to calculate config, cfg value %s", PlayerCfg);//debug
				}
				if(HunterAllowed != 1)	//if hunters arent allowed then..
				{
					if(StrEqual(PlayerCfg, "5v5", false))
					{
						GetConVarString(CompLoader5v5Config, LoadCommandConfigToExecuteName, 128);																			
					}
					if(StrEqual(PlayerCfg, "4v4 Classic", false))
					{
						GetConVarString(CompLoader4v4ClassicConfig, LoadCommandConfigToExecuteName, 128);																		
					}
					if(StrEqual(PlayerCfg, "4v4", false))
					{
						GetConVarString(CompLoader4v4Config, LoadCommandConfigToExecuteName, 128);																		
					}
					if(StrEqual(PlayerCfg, "3v3", false))
					{
						GetConVarString(CompLoader3v3Config, LoadCommandConfigToExecuteName, 128);																		
					}
					if(StrEqual(PlayerCfg, "2v2", false))
					{
						GetConVarString(CompLoader2v2Config, LoadCommandConfigToExecuteName, 128);																	
					}
					if(StrEqual(PlayerCfg, "1v1", false))
					{
						CPrintToChatAll("[{olive}TS{default}] %t","mode is disabled.","1v1");
					}
					#if NO_BOOMER_CFG
					if(StrEqual(PlayerCfg, "5v5 No Boomer", false))
					{
						GetConVarString(CompLoader4v4NobConfig, LoadCommandConfigToExecuteName, 128);																			
					}
					if(StrEqual(PlayerCfg, "4v4 No Boomer", false))
					{
						GetConVarString(CompLoader4v4NobConfig, LoadCommandConfigToExecuteName, 128);																	
					}
					if(StrEqual(PlayerCfg, "3v3 No Boomer", false))
					{
						GetConVarString(CompLoader3v3NobConfig, LoadCommandConfigToExecuteName, 128);																		
					}
					if(StrEqual(PlayerCfg, "2v2 No Boomer", false))
					{
						GetConVarString(CompLoader2v2NobConfig, LoadCommandConfigToExecuteName, 128);																	
					}
					#endif
					if(StrEqual(PlayerCfg, "5v5 Hunter", false))
					{
						GetConVarString(CompLoader5v5HuntersConfig, LoadCommandConfigToExecuteName, 128);																			
					}
					if(StrEqual(PlayerCfg, "4v4 Hunter", false))
					{
						GetConVarString(CompLoader4v4HuntersConfig, LoadCommandConfigToExecuteName, 128);																		
					}
					if(StrEqual(PlayerCfg, "3v3 Hunter", false))
					{
						GetConVarString(CompLoader3v3HuntersConfig, LoadCommandConfigToExecuteName, 128);																			
					}
					if(StrEqual(PlayerCfg, "2v2 Hunter", false))
					{
						GetConVarString(CompLoader2v2HuntersConfig, LoadCommandConfigToExecuteName, 128);																	
					}
				}
				#else
				if(StrEqual(PlayerCfg, "5v5", false))			//if PlayerCfg is 4v4 then
				{
					GetConVarString(CompLoader5v5Config, LoadCommandConfigToExecuteName, 128);																		
				}
				if(StrEqual(PlayerCfg, "4v4 Classic", false))
				{
					GetConVarString(CompLoader4v4ClassicConfig, LoadCommandConfigToExecuteName, 128);																			
				}
				if(StrEqual(PlayerCfg, "4v4", false))			//if PlayerCfg is 4v4 then
				{
					GetConVarString(CompLoader4v4Config, LoadCommandConfigToExecuteName, 128);																		
				}
				if(StrEqual(PlayerCfg, "3v3", false))
				{
					GetConVarString(CompLoader3v3Config, LoadCommandConfigToExecuteName, 128);																		
				}
				if(StrEqual(PlayerCfg, "2v2", false))
				{
					GetConVarString(CompLoader2v2Config, LoadCommandConfigToExecuteName, 128);	;																		
				}
				if(StrEqual(PlayerCfg, "1v1", false))
				{
					GetConVarString(CompLoader1v1Config, LoadCommandConfigToExecuteName, 128);																		
				}
				#endif
				
				if(CanStartVotes(client))
				{
				
					decl String:SteamId[35];
					GetClientAuthId(client, AuthId_Steam2,SteamId, sizeof(SteamId));
					new String:curname[128];
					GetClientName(client,curname,128);
					LogMessage("%s(%s) starts a vote: match %s.", curname, SteamId,PlayerCfg);//紀錄在log文件
					CPrintToChatAll("{default}[{olive}TS{default}] %t", "comp_loader4",curname, PlayerCfg);
					
					for(new i=1; i <= MaxClients; i++) ClientVoteMenuSet(i,1);
					
					g_hMatchVote = new Menu(Handler_VoteCallback, MENU_ACTIONS_ALL);
					g_hMatchVote.SetTitle("%T","comp_loader5",LANG_SERVER,PlayerCfg);
					g_hMatchVote.AddItem(VOTE_YES, "Yes");
					g_hMatchVote.AddItem(VOTE_NO, "No");
					g_hMatchVote.ExitButton = false;
					g_hMatchVote.DisplayVoteToAll(20);
					
					EmitSoundToAll("ui/beep_synthtone01.wav");
				}
				else
				{
					return Plugin_Handled;
				}
			}
			else
			{
				CPrintToChat(client, "[{olive}TS{default}] %T","Spectators cannot use command.",client,"!load");		//if client team is non survivor or infected (spectator)
			}
		
		}
		else
		{
			CPrintToChat(client,"[{olive}TS{default}] %T","command is disabled.",client,"!load");
			Config_Requests[TEAM_SURVIVOR] = false;								//resetting the config requests so the function can be run through again
			Config_Requests[TEAM_INFECTED] = false;								//resetting the config requests so the function can be run through again
		}	
	}
	return Plugin_Handled;
}

CampaignchangeDelayed()
{
	if (MapCountdownTimer == INVALID_HANDLE)
	{
		PrintHintTextToAll("%t","comp_loader6",CAMPAIGN_CHANGE_DELAY+1);
		isMapRestartPending = true;
		CampaingChangeDelay = CAMPAIGN_CHANGE_DELAY;
		MapCountdownTimer = CreateTimer(1.0, timerCampaignchange, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
}
public Action:timerCampaignchange(Handle:timer)
{
	if (CampaingChangeDelay == 0)
	{
		MapCountdownTimer = INVALID_HANDLE;
		//EmitSoundToAll("buttons/blip2.wav", _, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.5);
		Map_Change_NOW();
		return Plugin_Stop;
	}
	else
	{
		PrintHintTextToAll("%t","comp_loader6", CampaingChangeDelay);
		EmitSoundToAll("buttons/blip1.wav", _, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.5);
		CampaingChangeDelay--;
	}
	return Plugin_Continue;
}
Map_Change_NOW()
{
	if(adminMapActive)
		ServerCommand("changelevel %s", AdminMapToExecuteName);
	else
		ServerCommand("changelevel %s", MapToExecuteName);
	isMapRestartPending = false;
	adminMapActive = false;
}
public Action:Map_Changer(client, args)
{
	if(isMapRestartPending || adminMapActive) return Plugin_Handled;//正在倒數換圖或是admin已經強制換圖
	new bool:id = IsPlayerGenericAdmin(client);
	if (args < 1)
	{
		new bool:isAdmin = false;
		new bool:isMapAllowed = false;
		
		new allowMapInt = GetConVarInt(CompLoaderAllowMap);
		
		if (id == true) isAdmin = true;
		
		if (allowMapInt == 1) isMapAllowed = true;
	
		if (isAdmin == false && isMapAllowed == false)
		{
			ReplyToCommand(client, "[TS] %T","command is disabled.",client,"!changemap(!cm)");
			return Plugin_Handled;
		}
		
		new mapInfoMaxLen =2048;
		decl String:mapInfo[mapInfoMaxLen];
		decl String:mapInfo2[mapInfoMaxLen];
		#if CUSTOM_CONFIGS
		decl String:mapInfo3[mapInfoMaxLen];
		decl String:mapInfo4[mapInfoMaxLen];
		#endif
		decl String:mapInfo9[mapInfoMaxLen];
		//if(isAdmin == true) Format(mapInfo, mapInfoMaxLen, "| command                     | force changemap(admin)                      |\n");
		//else Format(mapInfo, mapInfoMaxLen, "| command                     | request to changemap                        |\n");
		Format(mapInfo, mapInfoMaxLen, "|-----------------------------|---------------------------------------------|\n");
		Format(mapInfo, mapInfoMaxLen, "%s| !changemap da               | Change the Campaign to Dead Air             |\n",mapInfo);
		Format(mapInfo, mapInfoMaxLen, "%s| !changemap deadair          |                                             |\n",mapInfo);		
		Format(mapInfo, mapInfoMaxLen, "%s|-----------------------------|---------------------------------------------|\n",mapInfo);
		Format(mapInfo, mapInfoMaxLen, "%s| !changemap dt               | Change the Campaign to Death Toll           |\n",mapInfo);
		Format(mapInfo, mapInfoMaxLen, "%s| !changemap deathtoll        |                                             |\n",mapInfo);		
		Format(mapInfo, mapInfoMaxLen, "%s|-----------------------------|---------------------------------------------|\n",mapInfo);
		Format(mapInfo, mapInfoMaxLen, "%s| !changemap bh               | Change the Campaign to Blood Harvest        |\n",mapInfo);
		Format(mapInfo, mapInfoMaxLen, "%s| !changemap bloodharvest     |                                             |",mapInfo);		
		Format(mapInfo2, mapInfoMaxLen, "|-----------------------------|---------------------------------------------|\n");
		Format(mapInfo2, mapInfoMaxLen, "%s| !changemap nm               | Change the Campaign to No Mercy             |\n",mapInfo2);
		Format(mapInfo2, mapInfoMaxLen, "%s| !changemap nomercy          |                                             |\n",mapInfo2);		
		Format(mapInfo2, mapInfoMaxLen, "%s|-----------------------------|---------------------------------------------|\n",mapInfo2);
		Format(mapInfo2, mapInfoMaxLen, "%s| !changemap cc               | Change the Campaign to Crash Course         |\n",mapInfo2);
		Format(mapInfo2, mapInfoMaxLen, "%s| !changemap crashcourse      |                                             |\n",mapInfo2);		
		Format(mapInfo2, mapInfoMaxLen, "%s|-----------------------------|---------------------------------------------|\n",mapInfo2);
		Format(mapInfo2, mapInfoMaxLen, "%s| !changemap ts               |                                             |\n",mapInfo2);
		Format(mapInfo2, mapInfoMaxLen, "%s| !changemap sa               | Change the Campaign to The Sacrifice        |\n",mapInfo2);
		Format(mapInfo2, mapInfoMaxLen, "%s| !changemap thesacrifice     |                                             |",mapInfo2);
		#if CUSTOM_CONFIGS
		Format(mapInfo3, mapInfoMaxLen, "|-----------------------------|---------------------------------------------|\n");
		Format(mapInfo3, mapInfoMaxLen, "%s| !changemap c17              | Change the Campaign to City 17              |\n",mapInfo3);
		Format(mapInfo3, mapInfoMaxLen, "%s| !changemap city17           |                                             |\n",mapInfo3);		
		Format(mapInfo3, mapInfoMaxLen, "%s|-----------------------------|---------------------------------------------|\n",mapInfo3);
		Format(mapInfo3, mapInfoMaxLen, "%s| !changemap sb               | Change the Campaign to Suicide Blitz        |\n",mapInfo3);
		Format(mapInfo3, mapInfoMaxLen, "%s| !changemap suicideblitz     |                                             |\n",mapInfo3);	
		Format(mapInfo3, mapInfoMaxLen, "%s|-----------------------------|---------------------------------------------|\n",mapInfo3);
		Format(mapInfo3, mapInfoMaxLen, "%s| !changemap ihm              |                                             |\n",mapInfo3);
		Format(mapInfo3, mapInfoMaxLen, "%s| !changemap mountain         | Change the Campaign to I hate mountain      |\n",mapInfo3);		
		Format(mapInfo3, mapInfoMaxLen, "%s| !changemap ihatemountain    |                                             |\n",mapInfo3);		
		Format(mapInfo3, mapInfoMaxLen, "%s|-----------------------------|---------------------------------------------|\n",mapInfo3);
		Format(mapInfo3, mapInfoMaxLen, "%s| !changemap dfb              |                                             |\n",mapInfo3);
		Format(mapInfo3, mapInfoMaxLen, "%s| !changemap blue             | Change the Campaign to Dead Flag Blues      |",mapInfo3);	
		Format(mapInfo4, mapInfoMaxLen, "| !changemap deadflagblues    |                                             |\n");	
		Format(mapInfo4, mapInfoMaxLen, "%s|-----------------------------|---------------------------------------------|\n",mapInfo4);
		Format(mapInfo4, mapInfoMaxLen, "%s| !changemap dbd              |                                             |\n",mapInfo4);
		Format(mapInfo4, mapInfoMaxLen, "%s| !changemap dawn             | Change the Campaign to Dead Before Dawn     |\n",mapInfo4);		
		Format(mapInfo4, mapInfoMaxLen, "%s| !changemap deadbeforedawn   |                                             |\n",mapInfo4);		
		Format(mapInfo4, mapInfoMaxLen, "%s|-----------------------------|---------------------------------------------|\n",mapInfo4);
		Format(mapInfo4, mapInfoMaxLen, "%s| !changemap aotd             |                                             |\n",mapInfo4);
		Format(mapInfo4, mapInfoMaxLen, "%s| !changemap arena            | Change the Campaign to The Arena of the Dead|\n",mapInfo4);	
		Format(mapInfo4, mapInfoMaxLen, "%s| !changemap thearenaofthedead|                                             |\n",mapInfo4);
		Format(mapInfo4, mapInfoMaxLen, "%s|-----------------------------|---------------------------------------------|\n",mapInfo4);
		Format(mapInfo4, mapInfoMaxLen, "%s| !changemap dab              |                                             |\n",mapInfo4);
		Format(mapInfo4, mapInfoMaxLen, "%s| !changemap aboard           | Change the Campaign to Death Aboard         |\n",mapInfo4);	
		Format(mapInfo4, mapInfoMaxLen, "%s| !changemap deathaboard      |                                             |",mapInfo4);
		
		#endif		
		Format(mapInfo9, mapInfoMaxLen,    "|-----------------------------|---------------------------------------------|\n");
		if(isAdmin == true) Format(mapInfo9, mapInfoMaxLen, "%s| !changemap cancel           | cancel all requests                         |\n", mapInfo9);
		else Format(mapInfo9, mapInfoMaxLen, "%s| !changemap cancel           | cancel the request                          |\n", mapInfo9);
		Format(mapInfo9, mapInfoMaxLen,    "%s|-----------------------------|---------------------------------------------|", mapInfo9);	
		
		if (client == 0)
		{
			return Plugin_Handled;
		}
		else
		{
			ReplyToCommand(client, "[TS] %T","Check the console for available commands.",client);
			PrintToConsole(client, mapInfo);
			PrintToConsole(client, mapInfo2);
			#if CUSTOM_CONFIGS
			PrintToConsole(client, mapInfo3);
			PrintToConsole(client, mapInfo4);
			#endif
			PrintToConsole(client, mapInfo9);
		}
		return Plugin_Handled;
	}
	if (id == true)		//if client is admin then	
	{
		decl String:Admin_Map[128];			//Admin config is the string contents after "!load ", if sm_load was invoked by an admin
		decl String:AdminName[32];			//Admin name is the name of the admin that invoked sm_load
		
		GetClientName(client, AdminName, sizeof(AdminName));	//getting admin name
		GetCmdArgString(Admin_Map, sizeof(Admin_Map));			//getting the string value
		
		if(StrEqual(Admin_Map, "cancel", false))//checking if config is cancel, if it is, cancel this plugin, and jump to the admin config, stop this plugin
		{
			Admin_Cancel(client);
			return Plugin_Handled;
		}
				
		new AdminValueIsNM = 0;		//is map no mercy integer, on function start set to 0
		new AdminValueIsDT = 0;		//is map death toll integer, on function start set to 0
		new AdminValueIsBH = 0;		//is map blood harvest integer, on function start set to 0
		new AdminValueIsDA = 0;		//is map dead air, on function start set to 0t
		new AdminValueIsSA = 0;		//is map the sacrifice, on function start set to 0
		new AdminValueIsCC = 0;		//is the map crash course integer, on function start set to 0
		#if CUSTOM_CONFIGS
		new AdminValueIsC17 = 0;
		new AdminValueIsSB = 0;
		new AdminValueIsIHateMountain = 0;
		new AdminValueIsDeadFlagBlues = 0;
		new AdminValueIsDeadBeforeDawn = 0;
		new AdminValueIsTheArenaoftheDead = 0;
		new AdminValueIsDeathAboard = 0;
		#endif
		new AdminValueSumOfMaps = 0;	//is the sum of the maps more than 1, then config is invalid, on function start set to 0
				
		if(StrEqual(Admin_Map, "nm", false)) AdminValueIsNM = 1;
		else if((StrEqual(Admin_Map, "nomercy", false))) AdminValueIsNM = 1;
		else if(StrEqual(Admin_Map, "dt", false)) AdminValueIsDT = 1;
		else if((StrEqual(Admin_Map, "deathtoll", false))) AdminValueIsDT = 1;
		else if(StrEqual(Admin_Map, "bh", false)) AdminValueIsBH = 1;
		else if((StrEqual(Admin_Map, "bloodharvest", false))) AdminValueIsBH = 1;
		else if(StrEqual(Admin_Map, "da", false)) AdminValueIsDA = 1;
		else if((StrEqual(Admin_Map, "deadair", false))) AdminValueIsDA = 1;
		else if(StrEqual(Admin_Map, "sa", false)) AdminValueIsSA = 1;
		else if(StrEqual(Admin_Map, "ts", false)) AdminValueIsSA = 1;
		else if(StrEqual(Admin_Map, "thesacrifice", false)) AdminValueIsSA = 1;
		else if(StrEqual(Admin_Map, "cc", false)) AdminValueIsCC = 1;
		else if((StrEqual(Admin_Map, "crashcourse", false))) AdminValueIsCC = 1;
		#if CUSTOM_CONFIGS
		if(StrEqual(Admin_Map, "c17", false)) AdminValueIsC17 = 1;
		else if((StrEqual(Admin_Map, "city17", false))) AdminValueIsC17 = 1;	
		else if(StrEqual(Admin_Map, "sb", false)) AdminValueIsSB = 1;
		else if((StrEqual(Admin_Map, "suicideblitz", false))) AdminValueIsSB = 1;
		else if((StrEqual(Admin_Map, "ihm", false))) AdminValueIsIHateMountain = 1;
		else if((StrEqual(Admin_Map, "mountain", false))) AdminValueIsIHateMountain = 1;
		else if((StrEqual(Admin_Map, "ihatemountain", false))) AdminValueIsIHateMountain = 1;
		else if((StrEqual(Admin_Map, "dfb", false))) AdminValueIsDeadFlagBlues = 1;
		else if((StrEqual(Admin_Map, "blue", false))) AdminValueIsDeadFlagBlues = 1;
		else if((StrEqual(Admin_Map, "deadflagblues", false))) AdminValueIsDeadFlagBlues = 1;
		else if((StrEqual(Admin_Map, "dbd", false))) AdminValueIsDeadBeforeDawn = 1;
		else if((StrEqual(Admin_Map, "dawn", false))) AdminValueIsDeadBeforeDawn = 1;
		else if((StrEqual(Admin_Map, "deadbeforedawn", false))) AdminValueIsDeadBeforeDawn = 1;
		else if((StrEqual(Admin_Map, "aotd", false))) AdminValueIsTheArenaoftheDead = 1;
		else if((StrEqual(Admin_Map, "arena", false))) AdminValueIsTheArenaoftheDead = 1;
		else if((StrEqual(Admin_Map, "thearenaofthedead", false))) AdminValueIsTheArenaoftheDead = 1;
		else if((StrEqual(Admin_Map, "dab", false))) AdminValueIsDeathAboard = 1;
		else if((StrEqual(Admin_Map, "aboard", false))) AdminValueIsDeathAboard = 1;
		else if((StrEqual(Admin_Map, "deathaboard", false))) AdminValueIsDeathAboard = 1;
		#endif

		AdminValueSumOfMaps = AdminValueIsNM + AdminValueIsDT + AdminValueIsBH + AdminValueIsDA + AdminValueIsSA + AdminValueIsCC;
		#if CUSTOM_CONFIGS
		AdminValueSumOfMaps += AdminValueIsC17 + AdminValueIsSB + AdminValueIsIHateMountain + AdminValueIsDeadFlagBlues + AdminValueIsDeadBeforeDawn + AdminValueIsTheArenaoftheDead + AdminValueIsDeathAboard;//calculate the sum of all the config value integers
		#endif
		if(AdminValueSumOfMaps == 1)
		{	
			if(AdminValueIsNM == 1)
			{
				SetConVarInt(FindConVar("comp_loader_load_active"), 0);
				SetConVarInt(FindConVar("comp_loader_map_active"), 0);
				adminMapActive = true;
				AdminMapToExecuteName = "l4d_vs_hospital01_apartment";
				CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader7","No Mercy");
				CampaignchangeDelayed();
				Admin_Cancel_Lite();
				return Plugin_Handled;	
			}
			else if(AdminValueIsDT == 1)
			{
				SetConVarInt(FindConVar("comp_loader_load_active"), 0);
				SetConVarInt(FindConVar("comp_loader_map_active"), 0);
				adminMapActive = true;
				AdminMapToExecuteName = "l4d_vs_smalltown01_caves";
				CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader7","Death Toll");
				CampaignchangeDelayed();
				Admin_Cancel_Lite();
				return Plugin_Handled;
			}
			else if(AdminValueIsBH == 1)
			{
				SetConVarInt(FindConVar("comp_loader_load_active"), 0);
				SetConVarInt(FindConVar("comp_loader_map_active"), 0);
				adminMapActive = true;
				AdminMapToExecuteName = "l4d_vs_farm01_hilltop";
				CPrintToChatAll("[[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader7","Blood Harvest");
				CampaignchangeDelayed();
				Admin_Cancel_Lite();
				return Plugin_Handled;
			}
			else if(AdminValueIsDA == 1)
			{
				SetConVarInt(FindConVar("comp_loader_load_active"), 0);
				SetConVarInt(FindConVar("comp_loader_map_active"), 0);
				adminMapActive = true;
				AdminMapToExecuteName = "l4d_vs_airport01_greenhouse";
				CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader7","Dead Air");
				CampaignchangeDelayed();
				Admin_Cancel_Lite();
				return Plugin_Handled;	
			}
			else if(AdminValueIsSA == 1)
			{
				SetConVarInt(FindConVar("comp_loader_load_active"), 0);
				SetConVarInt(FindConVar("comp_loader_map_active"), 0);
				adminMapActive = true;
				AdminMapToExecuteName = "l4d_river01_docks";
				CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader7","The Sacrifice");
				CampaignchangeDelayed();
				Admin_Cancel_Lite();
				return Plugin_Handled;	
			}
			else if(AdminValueIsCC == 1)
			{
				SetConVarInt(FindConVar("comp_loader_load_active"), 0);
				SetConVarInt(FindConVar("comp_loader_map_active"), 0);
				adminMapActive = true;
				AdminMapToExecuteName = "l4d_garage01_alleys";
				CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader7","Crash Course");
				CampaignchangeDelayed();
				Admin_Cancel_Lite();
				return Plugin_Handled;
			}
			#if CUSTOM_CONFIGS
			if(AdminValueIsC17 == 1)
			{
				SetConVarInt(FindConVar("comp_loader_load_active"), 0);
				SetConVarInt(FindConVar("comp_loader_map_active"), 0);
				adminMapActive = true;
				AdminMapToExecuteName = "l4d_vs_city17_01";
				CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader7","City 17");
				CampaignchangeDelayed();
				Admin_Cancel_Lite();
				return Plugin_Handled;
			}
			else if(AdminValueIsSB == 1)
			{
				SetConVarInt(FindConVar("comp_loader_load_active"), 0);
				SetConVarInt(FindConVar("comp_loader_map_active"), 0);
				adminMapActive = true;
				AdminMapToExecuteName = "l4d_vs_stadium1_apartment";
				CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader7","Suicide Blitz");
				CampaignchangeDelayed();
				Admin_Cancel_Lite();
				return Plugin_Handled;
			}
			else if(AdminValueIsIHateMountain == 1)
			{
				SetConVarInt(FindConVar("comp_loader_load_active"), 0);
				SetConVarInt(FindConVar("comp_loader_map_active"), 0);
				adminMapActive = true;
				AdminMapToExecuteName = "l4d_ihm01_forest";
				CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader7","I hate mountain");
				CampaignchangeDelayed();
				Admin_Cancel_Lite();
				return Plugin_Handled;
			}
			else if(AdminValueIsDeadFlagBlues == 1)
			{
				SetConVarInt(FindConVar("comp_loader_load_active"), 0);
				SetConVarInt(FindConVar("comp_loader_map_active"), 0);
				adminMapActive = true;
				AdminMapToExecuteName = "l4d_vs_deadflagblues01_city";
				CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader7","Dead Flag Blues");
				CampaignchangeDelayed();
				Admin_Cancel_Lite();
				return Plugin_Handled;
			}
			else if(AdminValueIsDeadBeforeDawn == 1)
			{
				SetConVarInt(FindConVar("comp_loader_load_active"), 0);
				SetConVarInt(FindConVar("comp_loader_map_active"), 0);
				adminMapActive = true;
				AdminMapToExecuteName = "l4d_dbd_citylights";
				CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader7","Dead Before Dawn");
				CampaignchangeDelayed();
				Admin_Cancel_Lite();
				return Plugin_Handled;
			}
			else if(AdminValueIsTheArenaoftheDead == 1)
			{
				SetConVarInt(FindConVar("comp_loader_load_active"), 0);
				SetConVarInt(FindConVar("comp_loader_map_active"), 0);
				adminMapActive = true;
				AdminMapToExecuteName = "l4d_jsarena01_town";
				CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader7","The Arena of the Dead");
				CampaignchangeDelayed();
				Admin_Cancel_Lite();
				return Plugin_Handled;
			}
			else if(AdminValueIsDeathAboard == 1)
			{
				SetConVarInt(FindConVar("comp_loader_load_active"), 0);
				SetConVarInt(FindConVar("comp_loader_map_active"), 0);
				adminMapActive = true;
				AdminMapToExecuteName = "l4d_deathaboard01_prison";
				CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader7","Death Aboard");
				CampaignchangeDelayed();
				Admin_Cancel_Lite();
				return Plugin_Handled;
			}
			#endif
		}
		else
		{
			CPrintToChat(client, "[{olive}TS{default}] %T","Invalid Map.",client);	//debug, prints admin name, and the config entered *now prints to admin invalid config
		}
	}
	if (!TestMatchDelay(client))
	{
		return Plugin_Handled;
	}
	if (id == false)	//if client is non admin then...
	{
		new Client_Team		= GetClientTeam(client),
		Opposite_Team	= (Client_Team == TEAM_SURVIVOR) ? TEAM_INFECTED : TEAM_SURVIVOR;	//getting dem client teamz. If client team is survivor, then opposite team is infected, else opposite team is survivorzor
		
		decl String:PlayerMap[128];			//Initial string after !changemap
		decl String:PlayerMapChat[32];		//da or dt or etc etc for the chat print
		decl String:SurvivorMap[128];		//gets string value of PlayerMap when Team A requests !load
		decl String:InfectedMap[128];		//gets string value of PlayerMap when Team B requests !load

		decl String:MapIsAllowed[2];		//Temp string to get the convar value of comp_loader_allow_load 1 / 0
	
		GetConVarString(CompLoaderAllowMap, MapIsAllowed, 2);				//setting the value of the convar to the string
	
		new MapAllowed = StringToInt(MapIsAllowed);		//converting the string value to integer
		
		if(MapAllowed != 0)		//if comp_loader_load_allowed = 1
		{
			//LogMessage("LoadAllowed returned 1");	//debug, log to file that comp_loader_load_allowed = 1
			if(Client_Team == TEAM_SURVIVOR || Client_Team == TEAM_INFECTED)	//if the client using !load is either survivor or infected
			{
				if(adminMapActive == true) return Plugin_Handled;
				if(adminCancel == true)
				{
					CPrintToChat(client, "[{olive}TS{default}] %T","command is not available.",client,"!changemap(!cm)");
					return Plugin_Handled;
				}
				GetCmdArgString(PlayerMap, sizeof(PlayerMap));			//getting the !load arguments to PlayerMap string
				new ValueIsNM = 0;		//is map no mercy integer, on function start set to 0
				new ValueIsDT = 0;		//is map death toll integer, on function start set to 0
				new ValueIsBH = 0;		//is map blood harvest integer, on function start set to 0
				new ValueIsDA = 0;		//is map dead air, on function start set to 0t
				new ValueIsSA = 0;		//is map the sacrifice, on function start set to 0
				new ValueIsTS = 0;		//is map the sacrifice, on function start set to 0
				new ValueIsCC = 0;		//is the map crash course integer, on function start set to 0
				#if CUSTOM_CONFIGS
				new ValueIsC17 = 0;
				new ValueIsSB = 0;
				new ValueIsIHateMountain = 0;
				new ValueIsDeadFlagBlues = 0;
				new ValueIsDeadBeforeDawn = 0;
				new ValueIsTheArenaoftheDead = 0;
				new ValueIsDeathAboard = 0;
				#endif
				
				new ValueSumOfMaps = 0;	//is the sum of the maps more than 1, then config is invalid, on function start set to 0
						
				if(StrEqual(PlayerMap, "nm", false)) ValueIsNM = 1;
				else if((StrEqual(PlayerMap, "nomercy", false))) ValueIsNM = 1;
				else if(StrEqual(PlayerMap, "dt", false)) ValueIsDT = 1;
				else if((StrEqual(PlayerMap, "deathtoll", false))) ValueIsDT = 1;
				else if(StrEqual(PlayerMap, "bh", false)) ValueIsBH = 1;
				else if((StrEqual(PlayerMap, "bloodharvest", false))) ValueIsBH = 1;
				else if(StrEqual(PlayerMap, "da", false)) ValueIsDA = 1;
				else if((StrEqual(PlayerMap, "deadair", false))) ValueIsDA = 1;
				else if(StrEqual(PlayerMap, "sa", false)) ValueIsSA = 1;
				else if(StrEqual(PlayerMap, "ts", false)) ValueIsTS = 1;
				else if((StrEqual(PlayerMap, "sacrifice", false))) ValueIsSA = 1;
				else if(StrEqual(PlayerMap, "cc", false)) ValueIsCC = 1;
				else if((StrEqual(PlayerMap, "crashcourse", false))) ValueIsCC = 1;
				#if CUSTOM_CONFIGS
				if(StrEqual(PlayerMap, "c17", false)) ValueIsC17 = 1;
				else if((StrEqual(PlayerMap, "city17", false))) ValueIsC17 = 1;	
				else if(StrEqual(PlayerMap, "sb", false)) ValueIsSB = 1;
				else if((StrEqual(PlayerMap, "suicideblitz", false))) ValueIsSB = 1;
				else if((StrEqual(PlayerMap, "ihm", false))) ValueIsIHateMountain = 1;
				else if((StrEqual(PlayerMap, "mountain", false))) ValueIsIHateMountain = 1;
				else if((StrEqual(PlayerMap, "ihatemountain", false))) ValueIsIHateMountain = 1;
				else if((StrEqual(PlayerMap, "dfb", false))) ValueIsDeadFlagBlues = 1;
				else if((StrEqual(PlayerMap, "blue", false))) ValueIsDeadFlagBlues = 1;
				else if((StrEqual(PlayerMap, "deadflagblues", false))) ValueIsDeadFlagBlues = 1;
				else if((StrEqual(PlayerMap, "dbd", false))) ValueIsDeadBeforeDawn = 1;
				else if((StrEqual(PlayerMap, "dawn", false))) ValueIsDeadBeforeDawn = 1;
				else if((StrEqual(PlayerMap, "deadbeforedawn", false))) ValueIsDeadBeforeDawn = 1;
				else if((StrEqual(PlayerMap, "aotd", false))) ValueIsTheArenaoftheDead = 1;
				else if((StrEqual(PlayerMap, "arena", false))) ValueIsTheArenaoftheDead = 1;
				else if((StrEqual(PlayerMap, "thearenaofthedead", false))) ValueIsTheArenaoftheDead = 1;
				else if((StrEqual(PlayerMap, "dab", false))) ValueIsDeathAboard = 1;
				else if((StrEqual(PlayerMap, "aboard", false))) ValueIsDeathAboard = 1;
				else if((StrEqual(PlayerMap, "deathaboard", false))) ValueIsDeathAboard = 1;
				#endif

				
				ValueSumOfMaps = ValueIsNM + ValueIsDT + ValueIsBH + ValueIsDA + ValueIsSA	+ ValueIsCC + ValueIsTS;
				#if CUSTOM_CONFIGS
				ValueSumOfMaps += ValueIsC17 + ValueIsSB + ValueIsIHateMountain + ValueIsDeadFlagBlues + ValueIsDeadBeforeDawn + ValueIsTheArenaoftheDead + ValueIsDeathAboard;//calculate the sum of all the config value integers
				#endif
				
				if(StrEqual(PlayerMap, "cancel", false))//cancel configs before validating config, if the args are "cancel"
				{
					if(Map_Requests[Client_Team])
					{
						CPrintToChatAll("[{olive}TS{default}] %t","The team have canceled the command request.", Team_Names[Client_Team],"!changemap(!cm)");
						Map_Requests[TEAM_SURVIVOR] = false;
						Map_Requests[TEAM_INFECTED] = false;
						SetConVarInt(FindConVar("comp_loader_map_active"), 0);
						return Plugin_Handled;						
					}
					if(Map_Requests[Opposite_Team] && !Map_Requests[Client_Team])
					{
						CPrintToChatAll("[{olive}TS{default}] %t","The team have canceled the command request.", Team_Names[Client_Team],"!changemap(!cm)");
						Map_Requests[TEAM_SURVIVOR] = false;
						Map_Requests[TEAM_INFECTED] = false;
						SetConVarInt(FindConVar("comp_loader_map_active"), 0);
						return Plugin_Handled;
					}
					if(!Map_Requests[Opposite_Team])
					{
						CPrintToChat(client, "[{olive}TS{default}] %T","Nothing to cancel.",client);
						return Plugin_Handled;
					}
					return Plugin_Handled;
				}
				
				if(ValueSumOfMaps == 1)
				{	
					if(ValueIsNM == 1)
					{
						PlayerMap = "No Mercy";
						PlayerMapChat = "NM";
					}
					else if(ValueIsDT == 1)
					{
						PlayerMap = "Death Toll";
						PlayerMapChat = "DT";
					}
					else if(ValueIsBH == 1)
					{
						PlayerMap = "Blood Harvest";
						PlayerMapChat = "BH";
					}
					else if(ValueIsDA == 1)
					{
						PlayerMap = "Dead Air";
						PlayerMapChat = "DA";
					}
					else if(ValueIsSA == 1)
					{
						PlayerMap = "The Sacrifice";
						PlayerMapChat = "SA";
					}
					else if(ValueIsTS == 1)
					{
						PlayerMap = "The Sacrifice";
						PlayerMapChat = "TS";
					}
					else if(ValueIsCC == 1)
					{
						PlayerMap = "Crash Course";
						PlayerMapChat = "CC";
					}
					#if CUSTOM_CONFIGS
					if(ValueIsC17 == 1)
					{
						PlayerMap = "City 17";
						PlayerMapChat = "C17";
					}
					else if(ValueIsSB == 1)
					{
						PlayerMap = "Suicide Blitz";
						PlayerMapChat = "SB";
					}
					else if(ValueIsIHateMountain == 1)
					{
						PlayerMap = "I hate mountain";
						PlayerMapChat = "IHM";
					}
					else if(ValueIsDeadFlagBlues == 1)
					{
						PlayerMap = "Dead Flag Blues";
						PlayerMapChat = "DFB";
					}
					else if(ValueIsDeadBeforeDawn == 1)
					{
						PlayerMap = "Dead Before Dawn";
						PlayerMapChat = "DBD";
					}
					else if(ValueIsTheArenaoftheDead == 1)
					{
						PlayerMap = "The Arena of the Dead";
						PlayerMapChat = "AOTD";
					}
					else if(ValueIsDeathAboard == 1)
					{
						PlayerMap = "Death Aboard";
						PlayerMapChat = "DAB";
					}
					#endif
				}
				else
				{
					CPrintToChatAll("[{olive}TS{default}] %t","Invalid Mapname.");
					return Plugin_Handled;
				}								
				if(!Map_Requests[Opposite_Team] == false)
				{
					SurvivorMap = PlayerMap;	//OppositeTeam argument string gets saved to SurvivorMap (which is actually just the first team)
				}			
				else if(!Map_Requests[Client_Team] == true)
				{
					InfectedMap = PlayerMap;	//ClientTeam argument string gets saved to InfectedMap
				}			
				if(!Map_Requests[Client_Team])	//if client team did not ask for !changemap yet then
				{
					Map_Requests[Client_Team] = true;	//if client team asks for !changemap exec, set Config_Requests to true, so they can only ask to exec once
										
					if(!Map_Requests[Opposite_Team])		//if opponent team did not !changemap, then...
					{
						CPrintToChatAll("[{olive}TS{default}] %t.\n%t","comp_loader8", Team_Names[Client_Team], PlayerMap,"The team must agree by typing command", Team_Names[Opposite_Team],"!cm", PlayerMapChat);
						//adminCancel = false;
						SetConVarInt(FindConVar("comp_loader_map_active"), 1);
					}
					else if(Map_Requests[TEAM_SURVIVOR] && Map_Requests[TEAM_INFECTED])	//if both client team have requested, and the opposite team have requested/responded, then...
					{
						if(StrEqual(InfectedMap, SurvivorMap, false))	//if both teams' string have the same value then...
						{
							SetConVarInt(FindConVar("comp_loader_map_active"), 0);	//this disables the timer from printing [TS] Request timed out., even though its function still happens later
							
							CPrintToChatAll("[{olive}TS{default}] %t","comp_loader9", Team_Names[Client_Team], PlayerMap);
							Map_Requests[TEAM_SURVIVOR] = false;		//resetting to false so the function can be run through again
							Map_Requests[TEAM_INFECTED] = false;		//resetting this should also prevent the playing teams to cancel the config, since there are no requests to cancel
							if(StrEqual(PlayerMap, "No Mercy", false))
							{
								MapToExecuteName = "l4d_vs_hospital01_apartment";
								Timer_Map_Change();					
								return Plugin_Handled;															
							}
							else if(StrEqual(PlayerMap, "Death Toll", false))
							{
								MapToExecuteName = "l4d_vs_smalltown01_caves";
								Timer_Map_Change();					
								return Plugin_Handled;														
							}
							else if(StrEqual(PlayerMap, "Blood Harvest", false))
							{
								MapToExecuteName = "l4d_vs_farm01_hilltop";
								Timer_Map_Change();					
								return Plugin_Handled;														
							}
							else if(StrEqual(PlayerMap, "Dead Air", false))
							{
								MapToExecuteName = "l4d_vs_airport01_greenhouse";
								Timer_Map_Change();					
								return Plugin_Handled;														
							}
							else if(StrEqual(PlayerMap, "The Sacrifice", false))
							{
								MapToExecuteName = "l4d_river01_docks";
								Timer_Map_Change();				
								return Plugin_Handled;														
							}
							else if(StrEqual(PlayerMap, "Crash Course", false))
							{
								MapToExecuteName = "l4d_garage01_alleys";
								Timer_Map_Change();			
								return Plugin_Handled;														
							}
							#if CUSTOM_CONFIGS
							if(StrEqual(PlayerMap, "City 17", false))
							{
								MapToExecuteName = "l4d_vs_city17_01";
								Timer_Map_Change();			
								return Plugin_Handled;														
							}
							else if(StrEqual(PlayerMap, "Suicide Blitz", false))
							{
								MapToExecuteName = "l4d_vs_stadium1_apartments";
								Timer_Map_Change();	
								return Plugin_Handled;														
							}
							else if(StrEqual(PlayerMap, "I hate mountain", false))
							{
								MapToExecuteName = "l4d_ihm01_forest";
								Timer_Map_Change();			
								return Plugin_Handled;														
							}
							else if(StrEqual(PlayerMap, "Dead Flag Blues", false))
							{
								MapToExecuteName = "l4d_vs_deadflagblues01_city";
								Timer_Map_Change();	
								return Plugin_Handled;														
							}
							else if(StrEqual(PlayerMap, "Dead Before Dawn", false))
							{
								MapToExecuteName = "l4d_dbd_citylights";
								Timer_Map_Change();	
								return Plugin_Handled;														
							}
							else if(StrEqual(PlayerMap, "The Arena of the Dead", false))
							{
								MapToExecuteName = "l4d_jsarena01_town";
								Timer_Map_Change();	
								return Plugin_Handled;														
							}
							else if(StrEqual(PlayerMap, "Death Aboard", false))
							{
								MapToExecuteName = "l4d_deathaboard01_prison";
								Timer_Map_Change();	
								return Plugin_Handled;														
							}
							#endif
						}
						else
						{
								CPrintToChatAll("[{olive}TS{default}] %t","Map Mismatch.");	//if SurvivorCfg != InfectedCfg, then..
								Map_Requests[Client_Team] = false;
								return Plugin_Handled;
						}
					}
				}
				else CPrintToChat(client, "[{olive}TS{default}] %T","comp_loader10",client);	//if client team has already requested action, but opposite team hasnt
			}
			else
			{
				CPrintToChat(client, "[{olive}TS{default}] %T","Spectators cannot use command.",client,"!cm");		//if client team is non survivor or infected (spectator)
			}
		
		}
		else
		{
			CPrintToChatAll("[{olive}TS{default}] %t","command is disabled.","!cm");					//print to chat, comp loader is disabled by admin
			Map_Requests[TEAM_SURVIVOR] = false;								//resetting the map requests so the function can be run through again
			Map_Requests[TEAM_INFECTED] = false;								//resetting the map requests so the function can be run through again
		}	
	}
	return Plugin_Handled;
}


public Action:Reload_Config(client, args) //implement, get value of l4d_ready_server_cfg, and execute that, with a timer perhaps?
{
	decl String:reloadAdmin[128];
	decl String:reloadAdminCfg[128];
	GetClientName(client, reloadAdmin, sizeof(reloadAdmin));
	GetConVarString(FindConVar("l4d_ready_server_cfg"), reloadAdminCfg, sizeof(reloadAdminCfg));
	ServerCommand("exec %s", reloadAdminCfg);
	LogMessage("Admin '%s' executed '%s'", reloadAdmin, reloadAdminCfg);
	return Plugin_Handled;
}

public OnMapStart()
{
	g_votedelay = 15;
	CreateTimer(1.0, Timer_VoteDelay, _, TIMER_REPEAT| TIMER_FLAG_NO_MAPCHANGE); 
	MapCountdownTimer = INVALID_HANDLE;
	isMapRestartPending = false;
	
	Config_Requests[TEAM_SURVIVOR] = false;
	Config_Requests[TEAM_INFECTED] = false;
	Map_Requests[TEAM_SURVIVOR] = false;
	Map_Requests[TEAM_INFECTED] = false;
	
	adminCancel = false;
	adminLoadActive = false;
	adminMapActive = false;
	
	numberOfLoadTimers = 0;
	SetConVarInt(FindConVar("comp_loader_load_active"), 0);
	
	numberOfMapTimers = 0;										//resets the map timers to 0 active
	SetConVarInt(FindConVar("comp_loader_map_active"), 0);		//sets the convar to 0 on new map
	

	CompLoaderEnabledValue = GetConVarInt(CompLoaderEnabled);
	CheckMapName();
	ExecConfig();	
	MapCountdownTimer = INVALID_HANDLE;
	hasprepareloaded = false;
	
	PrecacheSound("ui/menu_enter05.wav");
	PrecacheSound("ui/beep_synthtone01.wav");
	PrecacheSound("ui/beep_error01.wav");
	
	VoteMenuClose();
}

CheckMapName()
{
	decl String:currentMap[256];
	GetCurrentMap(currentMap, 256);
	
	if(StrContains(currentMap, "01", false) != -1)
	{
		FirstMapVersus = 1;
	}
	if(StrContains(currentMap, "01", false) == -1)
	{
		FirstMapVersus = 0;
		CompLoaderConfigExecuted = 0;
	}
}

ExecConfig()
{	
	if (CompLoaderConfigExecuted == 0 && FirstMapVersus == 1 && CompLoaderEnabledValue == 1)
	{
		CompLoaderConfigExecuted = 1;
		GetConVarString(FindConVar("l4d_ready_server_cfg"), ConfigToExecuteFirstMap, sizeof(ConfigToExecuteFirstMap));
		ReplaceString(ConfigToExecuteFirstMap, 128, "_map.cfg", ".cfg");
		ServerCommand("exec %s", ConfigToExecuteFirstMap);
		LogMessage("Executed %s", ConfigToExecuteFirstMap);
	}
}
public Action:COLD_DOWN(Handle:timer,any:client)
{
	CreateTimer(3.0, Timer_Load_Config, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Timer_VoteDelay(Handle:timer, any:client)
{
	g_votedelay--;
	if(g_votedelay<=0)
	{
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

GetVoteDelay()
{
	return g_votedelay;
}

bool:TestMatchDelay(client)
{
	new delay = GetVoteDelay();
 	if (delay > 0)
 	{
 		CPrintToChat(client, "{default}[{olive}TS{default}] %T","comp_loader11",client, delay);
 		return false;
 	}
	return true;
}

MatchModeMenu(client)
{
	new Handle:hMenu = CreateMenu(MatchModeMenuHandler);
	SetMenuTitle(hMenu,"Select Rotoblin-AZ mode:");
	new String:sBuffer[64];
	KvRewind(g_hModesKV);
	if (KvGotoFirstSubKey(g_hModesKV))
	{
		do
		{
			KvGetSectionName(g_hModesKV, sBuffer, sizeof(sBuffer));
			AddMenuItem(hMenu, sBuffer, sBuffer);
		} while (KvGotoNextKey(g_hModesKV));
	}
	DisplayMenu(hMenu, client, 20);
}

public MatchModeMenuHandler(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		new String:sInfo[64], String:sBuffer[64];
		GetMenuItem(menu, param2, sInfo, sizeof(sInfo));
		KvRewind(g_hModesKV);
		if (KvJumpToKey(g_hModesKV, sInfo) && KvGotoFirstSubKey(g_hModesKV))
		{
			new Handle:hMenu = CreateMenu(ConfigsMenuHandler);
			Format(sBuffer, sizeof(sBuffer), "Select %s config:", sInfo);
			SetMenuTitle(hMenu, sBuffer);
			do
			{
				KvGetSectionName(g_hModesKV, sInfo, sizeof(sInfo));
				KvGetString(g_hModesKV, "name", sBuffer, sizeof(sBuffer));
				AddMenuItem(hMenu, sInfo, sBuffer);
			} while (KvGotoNextKey(g_hModesKV));
			DisplayMenu(hMenu, param1, 20);
		}
		else
		{
			CPrintToChat(param1, "[{olive}TS{default}] %T","comp_loader12",param1);
			MatchModeMenu(param1);
		}
	}
	else if(action == MenuAction_Cancel)
	{
		if (param1>0&&param1<= MaxClients&&IsClientConnected(param1) && IsClientInGame(param1)&& !IsFakeClient(param1))
			ClientVoteMenuSet(param1,2);
	}
	
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
		if (param1>0&&param1<= MaxClients&&IsClientConnected(param1) && IsClientInGame(param1)&& !IsFakeClient(param1))
			ClientVoteMenuSet(param1,2);
	}
}

public ConfigsMenuHandler(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		new String:sInfo[64];
		GetMenuItem(menu, param2, sInfo, sizeof(sInfo), _, PlayerCfg, sizeof(PlayerCfg));
		
		if(CanStartVotes(param1))
		{
			strcopy(g_sCfg, sizeof(g_sCfg), sInfo);
			decl String:SteamId[35];
			GetClientAuthId(param1, AuthId_Steam2,SteamId, sizeof(SteamId));
			new String:curname[128];
			GetClientName(param1,curname,128);
			LogMessage("%s(%s) starts a vote: match %s .",  curname, SteamId,PlayerCfg);//紀錄在log文件
			CPrintToChatAll("{default}[{olive}TS{default}] %t","comp_loader4", curname, PlayerCfg);
			
			for(new i=1; i <= MaxClients; i++) ClientVoteMenuSet(i,1);

			g_hMatchVote = new Menu(Handler_VoteCallback2, MENU_ACTIONS_ALL);
			g_hMatchVote.SetTitle("%T","comp_loader5",LANG_SERVER,PlayerCfg);
			g_hMatchVote.AddItem(VOTE_YES, "Yes");
			g_hMatchVote.AddItem(VOTE_NO, "No");
			g_hMatchVote.ExitButton = false;
			g_hMatchVote.DisplayVoteToAll(20);
			
			EmitSoundToAll("ui/beep_synthtone01.wav");
		}
		else
		{
			MatchModeMenu(param1);
		}
	}
	if (action == MenuAction_End)
	{
		if (param1>0&&param1<= MaxClients&&IsClientConnected(param1) && IsClientInGame(param1)&& !IsFakeClient(param1))
			ClientVoteMenuSet(param1,2);
		CloseHandle(menu);
	}
	if (action == MenuAction_Cancel)
	{
		if (param1>0&&param1<= MaxClients&&IsClientConnected(param1) && IsClientInGame(param1)&& !IsFakeClient(param1))
			ClientVoteMenuSet(param1,2);
	}
}

public Action:COLD_DOWN2(Handle:timer,any:client)
{
	ServerCommand("exec %s", g_sCfg);
}

CheckVotes()
{
	PrintHintTextToAll("%t: \x04%i\n%t: \x04%i","Agree",Votey,"Disagree", Voten);
}
public Action:VoteEndDelay(Handle:timer)
{
	Votey = 0;
	Voten = 0;
	for(new i=1; i <= MaxClients; i++) ClientVoteMenuSet(i,2);
}
VoteMenuClose()
{
	Votey = 0;
	Voten = 0;
	CloseHandle(g_hMatchVote);
	g_hMatchVote = null;
}
Float:GetVotePercent(votes, totalVotes)
{
	return (float(votes) / float(totalVotes));
}

bool:CanStartVotes(client)
{
	
 	if(g_hMatchVote != INVALID_HANDLE || IsVoteInProgress())
	{
		CPrintToChat(client, "{default}[{olive}TS{default}] %T","A vote is already in progress!",client);
		return false;
	}
	new iNumPlayers;
	new playerlimit = GetConVarInt(g_hCvarPlayerLimit);
	//list of players
	for (new i=1; i<=MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || !IsClientConnected(i))
		{
			continue;
		}
		iNumPlayers++;
	}
	if (iNumPlayers < playerlimit)
	{
		CPrintToChat(client, "{default}[{olive}TS{default}] %T %T","comp_loader13",client,"Not enough players.",client,playerlimit);
		return false;
	}
	
	return true;
}

public Handler_VoteCallback(Menu menu, MenuAction action, int param1, int param2)
{
	//==========================
	if(action == MenuAction_Select)
	{
		switch(param2)
		{
			case 0: 
			{
				Votey += 1;
			}
			case 1: 
			{
				Voten += 1;
			}
		}
	}
	else if ( action == MenuAction_Display)
	{
		char buffer[255];
		Format(buffer, sizeof(buffer), "%T", "comp_loader5", param1,PlayerCfg);
		
		Panel panel = view_as<Panel>(param2);
		panel.SetTitle(buffer);
	}
	//==========================
	decl String:item[64], String:display[64];
	new Float:percent, Float:limit, votes, totalVotes;

	GetMenuVoteInfo(param2, votes, totalVotes);
	GetMenuItem(menu, param1, item, sizeof(item), _, display, sizeof(display));
	
	if (strcmp(item, VOTE_NO) == 0 && param1 == 1)
	{
		votes = totalVotes - votes;
	}
	percent = GetVotePercent(votes, totalVotes);

	limit = GetConVarFloat(g_Cvar_Limits);
	
	CheckVotes();
	if (action == MenuAction_End)
	{
		VoteMenuClose();
	}
	else if (action == MenuAction_VoteCancel && param1 == VoteCancel_NoVotes)
	{
		CPrintToChatAll("{default}[{olive}TS{default}] %t","No votes");
		g_votedelay = VOTEDELAY_TIME;
		CreateTimer(1.0, Timer_VoteDelay, _, TIMER_REPEAT| TIMER_FLAG_NO_MAPCHANGE);
		EmitSoundToAll("ui/beep_error01.wav");
		CreateTimer(2.0, VoteEndDelay);
	}	
	else if (action == MenuAction_VoteEnd)
	{
		if ((strcmp(item, VOTE_YES) == 0 && FloatCompare(percent,limit) < 0 && param1 == 0) || (strcmp(item, VOTE_NO) == 0 && param1 == 1))
		{
			g_votedelay = VOTEDELAY_TIME;
			CreateTimer(1.0, Timer_VoteDelay, _, TIMER_REPEAT| TIMER_FLAG_NO_MAPCHANGE);
			EmitSoundToAll("ui/beep_error01.wav");
			CPrintToChatAll("{default}[{olive}TS{default}] %t","Vote fail.", RoundToNearest(100.0*limit), RoundToNearest(100.0*percent), totalVotes);
			CreateTimer(2.0, VoteEndDelay);
			hasprepareloaded = false;
		}
		else
		{
			g_votedelay = VOTEDELAY_TIME;
			CreateTimer(1.0, Timer_VoteDelay, _, TIMER_REPEAT| TIMER_FLAG_NO_MAPCHANGE);
			EmitSoundToAll("ui/menu_enter05.wav");
			CPrintToChatAll("{default}[{olive}TS{default}] %t","Vote pass.", RoundToNearest(100.0*percent), totalVotes);
			CreateTimer(2.0, VoteEndDelay);
			CreateTimer(0.1,COLD_DOWN,_);
		}
	}
	return 0;
}

public Handler_VoteCallback2(Handle:menu, MenuAction:action, param1, param2)
{
	//==========================
	if(action == MenuAction_Select)
	{
		switch(param2)
		{
			case 0: 
			{
				Votey += 1;
			}
			case 1: 
			{
				Voten += 1;
			}
		}
	}
	else if ( action == MenuAction_Display)
	{
		char buffer[255];
		Format(buffer, sizeof(buffer), "%T", "comp_loader5", param1,PlayerCfg);
		
		Panel panel = view_as<Panel>(param2);
		panel.SetTitle(buffer);
	}
	//==========================
	decl String:item[64], String:display[64];
	new Float:percent, Float:limit, votes, totalVotes;

	GetMenuVoteInfo(param2, votes, totalVotes);
	GetMenuItem(menu, param1, item, sizeof(item), _, display, sizeof(display));
	
	if (strcmp(item, VOTE_NO) == 0 && param1 == 1)
	{
		votes = totalVotes - votes;
	}
	percent = GetVotePercent(votes, totalVotes);

	limit = GetConVarFloat(g_Cvar_Limits);
	
	CheckVotes();
	if (action == MenuAction_End)
	{
		VoteMenuClose();
	}
	else if (action == MenuAction_VoteCancel && param1 == VoteCancel_NoVotes)
	{
		CPrintToChatAll("{default}[{olive}TS{default}] %t","No votes");
		g_votedelay = VOTEDELAY_TIME;
		CreateTimer(1.0, Timer_VoteDelay, _, TIMER_REPEAT| TIMER_FLAG_NO_MAPCHANGE);
		EmitSoundToAll("ui/beep_error01.wav");
		CreateTimer(2.0, VoteEndDelay);
	}	
	else if (action == MenuAction_VoteEnd)
	{
		if ((strcmp(item, VOTE_YES) == 0 && FloatCompare(percent,limit) < 0 && param1 == 0) || (strcmp(item, VOTE_NO) == 0 && param1 == 1))
		{
			g_votedelay = VOTEDELAY_TIME;
			CreateTimer(1.0, Timer_VoteDelay, _, TIMER_REPEAT| TIMER_FLAG_NO_MAPCHANGE);
			EmitSoundToAll("ui/beep_error01.wav");
			CPrintToChatAll("{default}[{olive}TS{default}] %t","Vote fail.", RoundToNearest(100.0*limit), RoundToNearest(100.0*percent), totalVotes);
			CreateTimer(2.0, VoteEndDelay);
			hasprepareloaded = false;
		}
		else
		{
			g_votedelay = VOTEDELAY_TIME;
			CreateTimer(1.0, Timer_VoteDelay, _, TIMER_REPEAT| TIMER_FLAG_NO_MAPCHANGE);
			EmitSoundToAll("ui/menu_enter05.wav");
			CPrintToChatAll("{default}[{olive}TS{default}] %t","Vote pass.", RoundToNearest(100.0*percent), totalVotes);
			CreateTimer(2.0, VoteEndDelay);
			CreateTimer(3.0,COLD_DOWN2,_);
		}
	}
	return 0;
}

bool:IsPlayerGenericAdmin(client)
{
    if (CheckCommandAccess(client, "generic_admin", ADMFLAG_GENERIC, false))
    {
        return true;
    }

    return false;
}  