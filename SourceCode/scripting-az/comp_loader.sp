#include <sourcemod>
#include <sdktools>
//#include <builtinvotes>
#include <multicolors>

#define PLUGIN_VERSION "2.7-2025/6/9"

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if( test != Engine_Left4Dead )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1.");
		return APLRes_SilentFailure;
	}

	return APLRes_Success;
}

#define L4D_MAXCLIENTS MaxClients
#define L4D_MAXCLIENTS_PLUS1 (L4D_MAXCLIENTS + 1)
#define MAPINFPMAXLEN 2048

#define CAMPAIGN_CHANGE_DELAY 4
new bool:isMapRestartPending;
new CampaingChangeDelay;
Handle CancelLoadTimer, CancelMapTimer, MapCountdownTimer;

//plugin info
public Plugin:myinfo = 
{
	name		= "Comp Loader",
	author		= "archer,l4d1 modify by Harry",
	description	= "Player Swapper, Config Loader. Add Match Vote",
	version		= PLUGIN_VERSION,
}

//plugin setup
ConVar CompLoaderEnabled			= null;
ConVar CompLoaderAllowLoad			= null;
ConVar CompLoaderAllowMap			= null;
ConVar CompLoader4v4ClassicConfig			= null;
ConVar CompLoader4v4PubConfig			= null;
ConVar CompLoader4v4PubHubtersConfig			= null;
ConVar CompLoader5v5Config			= null;
ConVar CompLoader4v4Config			= null;
ConVar CompLoader3v3Config			= null;
ConVar CompLoader2v2Config			= null;
ConVar CompLoader5v5HuntersConfig	= null;
ConVar CompLoader4v4HuntersConfig	= null;
ConVar CompLoader3v3HuntersConfig	= null;
ConVar CompLoader2v2HuntersConfig	= null;
ConVar CompLoader5v5NobConfig	= null;
ConVar CompLoader4v4NobConfig		= null;
ConVar CompLoader3v3NobConfig		= null;
ConVar CompLoader2v2NobConfig		= null;
ConVar CompLoader1v1HuntersConfig	= null;
ConVar CompLoader1v2HuntersConfig	= null;
ConVar CompLoader1v3HuntersConfig	= null;
ConVar CompLoader1v4HuntersConfig	= null;
ConVar CompLoader1v5HuntersConfig	= null;
ConVar CompLoader2v3HuntersConfig	= null;
ConVar CompLoader2v4HuntersConfig	= null;
ConVar CompLoader2v5HuntersConfig	= null;
ConVar CompLoader3v4HuntersConfig	= null;
ConVar CompLoader3v5HuntersConfig	= null;
ConVar CompLoader4v5HuntersConfig	= null;
ConVar CompLoaderWitchPartyConfig   = null;
ConVar CompLoaderDarkCoopConfig		= null;
ConVar CompLoaderLoadActive			= null;
ConVar CompLoaderMapActive			= null;

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
ConVar g_hCvarPlayerLimit;
//new Handle:g_hVote;
#define MATCHMODES_PATH		"configs/matchmodes.txt"
new String:g_sCfg[32];
Menu g_hMatchVote = null;
new Handle:g_hModesKV = null;
native ClientVoteMenuSet(client,trueorfalse);//from votes3
new Votey = 0;
new Voten = 0;
#define VOTE_NO "no"
#define VOTE_YES "yes"
new Handle:g_Cvar_Limits;
new String:PlayerCfg[128];			//Initial string after !load

char cfg5v5[128];
char cfg4v4classic[128];
char cfg4v4Pub[128];
char cfg4v4PubHuters[128];
char cfg4v4[128];
char cfg3v3[128];
char cfg2v2[128];
char cfg5v5hunters[128];
char cfg4v4hunters[128];
char cfg3v3hunters[128];
char cfg2v2hunters[128];
char cfg5v5Nob[128];
char cfg4v4Nob[128];
char cfg3v3Nob[128];
char cfg2v2Nob[128];
char cfg1v1hunters[128];
char cfg1v2hunters[128];
char cfg1v3hunters[128];
char cfg1v4hunters[128];
char cfg1v5hunters[128];
char cfg2v3hunters[128];
char cfg2v4hunters[128];
char cfg2v5hunters[128];
char cfg3v4hunters[128];
char cfg3v5hunters[128];
char cfg4v5hunters[128];
char cfgwitchparty[128];
char cfgdarkcoop[128];
StringMap g_smMapName_ShortToFull;
StringMap g_smMapName_FullToCode;
StringMap g_smMapName_FullToRequest;


public OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("Roto2-AZ_mod.phrases");
	
	CompLoaderEnabled				= CreateConVar("comp_loader_enabled", "0", "Enable comp_loader to exec config on first maps.", FCVAR_NOTIFY);
	CompLoaderAllowLoad				= CreateConVar("comp_loader_allow_load", "1", "Allow players to use the !load command.", FCVAR_NOTIFY);
	CompLoaderAllowMap				= CreateConVar("comp_loader_allow_map", "1", "Allow players to use the !changemap(!cm) command.", FCVAR_NOTIFY);
	CompLoader5v5Config				= CreateConVar("comp_loader_5v5_config", "rotoblin_hardcore_5v5.cfg", "Name of the 5v5 config. (Empty=Disable)");
	CompLoader4v4Config				= CreateConVar("comp_loader_4v4_config", "rotoblin_hardcore_4v4.cfg", "Name of the 4v4 config. (Empty=Disable)");
	CompLoader4v4ClassicConfig		= CreateConVar("comp_loader_4v4_classic_config", "rotoblin_hardcore_4v4_classic.cfg", "Name of the 4v4 classic config. (Empty=Disable)");
	CompLoader4v4PubConfig			= CreateConVar("comp_loader_4v4_pub_config", "rotoblin_pub.cfg", "Name of the 4v4 pub config. (Empty=Disable)");
	CompLoader4v4PubHubtersConfig	= CreateConVar("comp_loader_4v4_pub_hunter_config", "rotoblin_pub_hunters.cfg", "Name of the 4v4 pub hunters config. (Empty=Disable)");
	CompLoader3v3Config				= CreateConVar("comp_loader_3v3_config", "rotoblin_hardcore_3v3.cfg", "Name of the 3v3 config. (Empty=Disable)");
	CompLoader2v2Config				= CreateConVar("comp_loader_2v2_config", "rotoblin_hardcore_2v2.cfg", "Name of the 2v2 config. (Empty=Disable)");
	CompLoader5v5HuntersConfig		= CreateConVar("comp_loader_5v5_hunters_only", "rotoblin_hunters_5v5.cfg", "Name of the 5v5 Hunters only config. (Empty=Disable)");
	CompLoader4v4HuntersConfig		= CreateConVar("comp_loader_4v4_hunters_only", "rotoblin_hunters_4v4.cfg", "Name of the 4v4 Hunters only config. (Empty=Disable)");
	CompLoader3v3HuntersConfig		= CreateConVar("comp_loader_3v3_hunters_only", "rotoblin_hunters_3v3.cfg", "Name of the 3v3 Hunters only config. (Empty=Disable)");
	CompLoader2v2HuntersConfig		= CreateConVar("comp_loader_2v2_hunters_only", "rotoblin_hunters_2v2.cfg", "Name of the 2v2 Hunters only config. (Empty=Disable)");
	CompLoader5v5NobConfig			= CreateConVar("comp_loader_5v5_no_boomer", "rotoblin_nob_5v5.cfg", "Name of the 4v4 No Boomer config. (Empty=Disable)");
	CompLoader4v4NobConfig			= CreateConVar("comp_loader_4v4_no_boomer", "rotoblin_nob_4v4.cfg", "Name of the 4v4 No Boomer config. (Empty=Disable)");
	CompLoader3v3NobConfig			= CreateConVar("comp_loader_3v3_no_boomer", "rotoblin_nob_3v3.cfg", "Name of the 3v3 No Boomer config. (Empty=Disable)");
	CompLoader2v2NobConfig			= CreateConVar("comp_loader_2v2_no_boomer", "rotoblin_nob_2v2.cfg", "Name of the 2v2 No Boomer config. (Empty=Disable)");
	CompLoader1v1HuntersConfig		= CreateConVar("comp_loader_1v1_hunters_only", "rotoblin_hunters_1v1.cfg", "Name of the 1v1 Hunters only config. (Empty=Disable)");
	CompLoader1v2HuntersConfig		= CreateConVar("comp_loader_1v2_hunters_only", "rotoblin_hunters_1v2.cfg", "Name of the 1v2 Hunters only config. (Empty=Disable)");
	CompLoader1v3HuntersConfig		= CreateConVar("comp_loader_1v3_hunters_only", "rotoblin_hunters_1v3.cfg", "Name of the 1v3 Hunters only config. (Empty=Disable)");
	CompLoader1v4HuntersConfig		= CreateConVar("comp_loader_1v4_hunters_only", "rotoblin_hunters_1v4.cfg", "Name of the 1v4 Hunters only config. (Empty=Disable)");
	CompLoader1v5HuntersConfig		= CreateConVar("comp_loader_1v5_hunters_only", "rotoblin_hunters_1v5.cfg", "Name of the 1v5 Hunters only config. (Empty=Disable)");
	CompLoader2v3HuntersConfig		= CreateConVar("comp_loader_2v3_hunters_only", "rotoblin_hunters_2v3.cfg", "Name of the 2v3 Hunters only config. (Empty=Disable)");
	CompLoader2v4HuntersConfig		= CreateConVar("comp_loader_2v4_hunters_only", "rotoblin_hunters_2v4.cfg", "Name of the 2v4 Hunters only config. (Empty=Disable)");
	CompLoader2v5HuntersConfig		= CreateConVar("comp_loader_2v5_hunters_only", "rotoblin_hunters_2v5.cfg", "Name of the 2v5 Hunters only config. (Empty=Disable)");
	CompLoader3v4HuntersConfig		= CreateConVar("comp_loader_3v4_hunters_only", "rotoblin_hunters_3v4.cfg", "Name of the 3v4 Hunters only config. (Empty=Disable)");
	CompLoader3v5HuntersConfig		= CreateConVar("comp_loader_3v5_hunters_only", "rotoblin_hunters_3v5.cfg", "Name of the 3v5 Hunters only config. (Empty=Disable)");
	CompLoader4v5HuntersConfig		= CreateConVar("comp_loader_4v5_hunters_only", "rotoblin_hunters_4v5.cfg", "Name of the 4v5 Hunters only config. (Empty=Disable)");
	CompLoaderWitchPartyConfig		= CreateConVar("comp_loader_witch_Party_config", "rotoblin_witch_party.cfg", "Name of the Witch Party config. (Empty=Disable)");
	CompLoaderDarkCoopConfig		= CreateConVar("comp_loader_Dark_Coop_config", "rotoblin_Dark_Coop.cfg", "Name of the Dark Coop config. (Empty=Disable)");
	CompLoaderLoadActive			= CreateConVar("comp_loader_load_active", "0", "");
	CompLoaderMapActive				= CreateConVar("comp_loader_map_active", "0", "");
		
	HookConVarChange(CompLoaderLoadActive, ConVarChange_CompLoaderLoadActive);
	HookConVarChange(CompLoaderMapActive, ConVarChange_CompLoaderMapActive);

	GetCvars();
	CompLoader5v5Config.AddChangeHook(ChangeVars);
	CompLoader4v4Config.AddChangeHook(ChangeVars);
	CompLoader4v4ClassicConfig.AddChangeHook(ChangeVars);
	CompLoader4v4PubConfig.AddChangeHook(ChangeVars);
	CompLoader4v4PubHubtersConfig.AddChangeHook(ChangeVars);
	CompLoader3v3Config.AddChangeHook(ChangeVars);
	CompLoader2v2Config.AddChangeHook(ChangeVars);
	CompLoader5v5HuntersConfig.AddChangeHook(ChangeVars);
	CompLoader4v4HuntersConfig.AddChangeHook(ChangeVars);
	CompLoader3v3HuntersConfig.AddChangeHook(ChangeVars);
	CompLoader2v2HuntersConfig.AddChangeHook(ChangeVars);
	CompLoader5v5NobConfig.AddChangeHook(ChangeVars);
	CompLoader4v4NobConfig.AddChangeHook(ChangeVars);
	CompLoader3v3NobConfig.AddChangeHook(ChangeVars);
	CompLoader2v2NobConfig.AddChangeHook(ChangeVars);
	CompLoader1v1HuntersConfig.AddChangeHook(ChangeVars);
	CompLoader1v2HuntersConfig.AddChangeHook(ChangeVars);
	CompLoader1v3HuntersConfig.AddChangeHook(ChangeVars);
	CompLoader1v4HuntersConfig.AddChangeHook(ChangeVars);
	CompLoader1v5HuntersConfig.AddChangeHook(ChangeVars);
	CompLoader2v3HuntersConfig.AddChangeHook(ChangeVars);
	CompLoader2v4HuntersConfig.AddChangeHook(ChangeVars);
	CompLoader2v5HuntersConfig.AddChangeHook(ChangeVars);
	CompLoader3v4HuntersConfig.AddChangeHook(ChangeVars);
	CompLoader3v5HuntersConfig.AddChangeHook(ChangeVars);
	CompLoader4v5HuntersConfig.AddChangeHook(ChangeVars);
	CompLoaderWitchPartyConfig.AddChangeHook(ChangeVars);
	CompLoaderDarkCoopConfig.AddChangeHook(ChangeVars);

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


	g_smMapName_ShortToFull = new StringMap();
	g_smMapName_ShortToFull.SetString("nm", "No Mercy")
	g_smMapName_ShortToFull.SetString("nomercy", "No Mercy")
	g_smMapName_ShortToFull.SetString("dt", "Death Toll")
	g_smMapName_ShortToFull.SetString("deathtoll", "Death Toll")
	g_smMapName_ShortToFull.SetString("bh", "Blood Harvest")
	g_smMapName_ShortToFull.SetString("bloodharvest", "Blood Harvest")
	g_smMapName_ShortToFull.SetString("da", "Dead Air")
	g_smMapName_ShortToFull.SetString("deadair", "Dead Air")
	g_smMapName_ShortToFull.SetString("sa", "The Sacrifice")
	g_smMapName_ShortToFull.SetString("ts", "The Sacrifice")
	g_smMapName_ShortToFull.SetString("thesacrifice", "The Sacrifice")
	g_smMapName_ShortToFull.SetString("cc", "Crash Course")
	g_smMapName_ShortToFull.SetString("crashcourse", "Crash Course")
	g_smMapName_ShortToFull.SetString("c17", "City 17")
	g_smMapName_ShortToFull.SetString("city17", "City 17")
	g_smMapName_ShortToFull.SetString("sb", "Suicide Blitz")
	g_smMapName_ShortToFull.SetString("suicideblitz", "Suicide Blitz")
	g_smMapName_ShortToFull.SetString("ihm", "I Hate Mountain")
	g_smMapName_ShortToFull.SetString("ihatemountain", "I Hate Mountain")
	g_smMapName_ShortToFull.SetString("dfb", "Dead Flag Blues")
	g_smMapName_ShortToFull.SetString("deadflagblues", "Dead Flag Blues")
	g_smMapName_ShortToFull.SetString("dbd", "Dead Before Dawn")
	g_smMapName_ShortToFull.SetString("deadbeforedawn", "Dead Before Dawn")
	g_smMapName_ShortToFull.SetString("aotd", "The Arena of the Dead")
	g_smMapName_ShortToFull.SetString("thearenaofthedead", "The Arena of the Dead")
	g_smMapName_ShortToFull.SetString("dab", "Death Aboard")
	g_smMapName_ShortToFull.SetString("deathaboard", "Death Aboard")
	g_smMapName_ShortToFull.SetString("149", "One 4 Nine")
	g_smMapName_ShortToFull.SetString("one4nine", "One 4 Nine")
	g_smMapName_ShortToFull.SetString("db", "Dark Blood")
	g_smMapName_ShortToFull.SetString("darkblood", "Dark Blood")
	g_smMapName_ShortToFull.SetString("bha", "Blood Harvest APOCALYPSE")
	g_smMapName_ShortToFull.SetString("bloodharvestapocalypse", "Blood Harvest APOCALYPSE")
	g_smMapName_ShortToFull.SetString("p84", "Precinct 84")
	g_smMapName_ShortToFull.SetString("precinct84", "Precinct 84")
	g_smMapName_ShortToFull.SetString("cotd", "City Of The Dead")
	g_smMapName_ShortToFull.SetString("cityofthedead", "City Of The Dead")
	g_smMapName_ShortToFull.SetString("dv", "Dead Vacation")
	g_smMapName_ShortToFull.SetString("deadvacation", "Dead Vacation")
	g_smMapName_ShortToFull.SetString("uz", "Undead Zone")
	g_smMapName_ShortToFull.SetString("undeadzone", "Undead Zone")


	g_smMapName_FullToCode = new StringMap();
	g_smMapName_FullToCode.SetString("No Mercy", "l4d_vs_hospital01_apartment")
	g_smMapName_FullToCode.SetString("Death Toll", "l4d_vs_smalltown01_caves")
	g_smMapName_FullToCode.SetString("Blood Harvest", "l4d_vs_farm01_hilltop")
	g_smMapName_FullToCode.SetString("Dead Air", "l4d_vs_airport01_greenhouse")
	g_smMapName_FullToCode.SetString("The Sacrifice", "l4d_river01_docks")
	g_smMapName_FullToCode.SetString("Crash Course", "l4d_garage01_alleys")
	g_smMapName_FullToCode.SetString("City 17", "l4d_vs_city17_01")
	g_smMapName_FullToCode.SetString("Suicide Blitz", "l4d_vs_stadium1_apartment")
	g_smMapName_FullToCode.SetString("I Hate Mountain", "l4d_ihm01_forest")
	g_smMapName_FullToCode.SetString("Dead Flag Blues", "l4d_vs_deadflagblues01_city")
	g_smMapName_FullToCode.SetString("Dead Before Dawn", "l4d_dbd_citylights")
	g_smMapName_FullToCode.SetString("The Arena of the Dead", "l4d_jsarena01_town")
	g_smMapName_FullToCode.SetString("Death Aboard", "l4d_deathaboard01_prison")
	g_smMapName_FullToCode.SetString("One 4 Nine", "l4d_149_1")
	g_smMapName_FullToCode.SetString("Dark Blood", "l4d_darkblood01_tanker")
	g_smMapName_FullToCode.SetString("Blood Harvest APOCALYPSE", "rombu01")
	g_smMapName_FullToCode.SetString("Precinct 84", "l4d_noprecinct01_crash")
	g_smMapName_FullToCode.SetString("City Of The Dead", "cotd01_apartments_redux")
	g_smMapName_FullToCode.SetString("Dead Vacation", "hotel01_market_two")
	g_smMapName_FullToCode.SetString("Undead Zone", "uz_crash")

	g_smMapName_FullToRequest = new StringMap();
	g_smMapName_FullToRequest.SetString("No Mercy", "NM")
	g_smMapName_FullToRequest.SetString("Death Toll", "DT")
	g_smMapName_FullToRequest.SetString("Blood Harvest", "BH")
	g_smMapName_FullToRequest.SetString("Dead Air", "DA")
	g_smMapName_FullToRequest.SetString("The Sacrifice", "TS")
	g_smMapName_FullToRequest.SetString("Crash Course", "CC")
	g_smMapName_FullToRequest.SetString("City 17", "C17")
	g_smMapName_FullToRequest.SetString("Suicide Blitz", "SB")
	g_smMapName_FullToRequest.SetString("I Hate Mountain", "IHM")
	g_smMapName_FullToRequest.SetString("Dead Flag Blues", "DFB")
	g_smMapName_FullToRequest.SetString("Dead Before Dawn", "DBD")
	g_smMapName_FullToRequest.SetString("The Arena of the Dead", "AOTD")
	g_smMapName_FullToRequest.SetString("Death Aboard", "DAB")
	g_smMapName_FullToRequest.SetString("One 4 Nine", "149")
	g_smMapName_FullToRequest.SetString("Dark Blood", "DB")
	g_smMapName_FullToRequest.SetString("Blood Harvest APOCALYPSE", "BHA")
	g_smMapName_FullToRequest.SetString("Precinct 84", "P84")
	g_smMapName_FullToRequest.SetString("City Of The Dead", "COTD")
	g_smMapName_FullToRequest.SetString("Dead Vacation", "DV")
	g_smMapName_FullToRequest.SetString("Undead Zone", "UZ")
}

public void ChangeVars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	GetConVarString(CompLoader5v5Config, cfg5v5, 128);
	GetConVarString(CompLoader4v4Config, cfg4v4, 128);
	GetConVarString(CompLoader4v4ClassicConfig, cfg4v4classic, 128);
	GetConVarString(CompLoader4v4PubConfig, cfg4v4Pub, 128);
	GetConVarString(CompLoader4v4PubHubtersConfig, cfg4v4PubHuters, 128);
	GetConVarString(CompLoader3v3Config, cfg3v3, 128);
	GetConVarString(CompLoader2v2Config, cfg2v2, 128);
	GetConVarString(CompLoader5v5HuntersConfig, cfg5v5hunters, 128);
	GetConVarString(CompLoader4v4HuntersConfig, cfg4v4hunters, 128);
	GetConVarString(CompLoader3v3HuntersConfig, cfg3v3hunters, 128);
	GetConVarString(CompLoader2v2HuntersConfig, cfg2v2hunters, 128);
	GetConVarString(CompLoader5v5NobConfig, cfg5v5Nob, 128);
	GetConVarString(CompLoader4v4NobConfig, cfg4v4Nob, 128);
	GetConVarString(CompLoader3v3NobConfig, cfg3v3Nob, 128);
	GetConVarString(CompLoader2v2NobConfig, cfg2v2Nob, 128);
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

new bool:adminCancelLoad = false;			//reset to false after client requests to load a config
new bool:adminCancelMap = false;			//reset to false after client requests to change map
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
		
		if(status == 1 && adminCancelLoad == false && adminLoadActive == false)
		{
			Config_Requests[TEAM_SURVIVOR] = false;
			Config_Requests[TEAM_INFECTED] = false;
			CPrintToChatAll("[{olive}TS{default}] !load %t","request timed out.");
			numberOfLoadTimers = 0;
			SetConVarInt(CompLoaderLoadActive, 0);
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
		
		if(status == 1 && adminCancelMap == false && adminMapActive == false)
		{
			Map_Requests[TEAM_SURVIVOR] = false;
			Map_Requests[TEAM_INFECTED] = false;
			CPrintToChatAll("[{olive}TS{default}] !changemap(!cm) %t","request timed out.");
			numberOfMapTimers = 0;
			SetConVarInt(CompLoaderMapActive, 0);
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
	adminMapActive = true;
	adminLoadActive = true;
	Config_Requests[TEAM_SURVIVOR] = false;
	Config_Requests[TEAM_INFECTED] = false;
	Map_Requests[TEAM_SURVIVOR] = false;
	Map_Requests[TEAM_INFECTED] = false;
	adminCancelLoad = false;
	adminCancelMap = false;

	delete CancelLoadTimer;
	delete CancelMapTimer;
	delete MapCountdownTimer;

	VoteMenuClose(); // close match vote menu
	CreateTimer(0.1, VoteEndDelay);

	isMapRestartPending = false;
}

void Admin_Cancel(int client, int commandType)
{
	char localAdminName[64];
	GetClientName(client, localAdminName, sizeof(localAdminName));
	
	//implement if both teams agree on config or map, still cancel the load by changing a integer value to 1, that is loaded in the delayed map/config execute command
	
	if (commandType == 0) //load
	{
		Config_Requests[TEAM_SURVIVOR] = false;
		Config_Requests[TEAM_INFECTED] = false;
		adminCancelLoad = true;
		adminMapActive = false;
		adminLoadActive = false;
		isMapRestartPending = false;

		SetConVarInt(CompLoaderLoadActive, 0);
		delete CancelLoadTimer;
		CancelLoadTimer = CreateTimer(10.0, Timer_Admin_Cancel_Load_Cooldown);

		VoteMenuClose(); // close match vote menu
		CreateTimer(0.1, VoteEndDelay);

		CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t", localAdminName,"canceled the command request.","!load");
		
		return;
	}
	else if (commandType == 1) //cm
	{
		Map_Requests[TEAM_SURVIVOR] = false;
		Map_Requests[TEAM_INFECTED] = false;
		adminCancelMap = true;
		adminMapActive = false;
		adminLoadActive = false;
		isMapRestartPending = false;

		SetConVarInt(CompLoaderMapActive, 0);
		delete CancelMapTimer;
		CancelMapTimer = CreateTimer(10.0, Timer_Admin_Cancel_Map_Cooldown, TIMER_FLAG_NO_MAPCHANGE);

		CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t", localAdminName,"canceled the command request.","!cm");
		
		return;
	}

	return;
}

public Action:Timer_Admin_Cancel_Load_Cooldown(Handle:timer)
{
	adminCancelLoad = false;

	CancelLoadTimer = null;
	return Plugin_Continue;
}

public Action:Timer_Admin_Cancel_Map_Cooldown(Handle:timer)
{
	adminCancelMap = false;

	CancelMapTimer = null;
	return Plugin_Continue;
}

public Action:Timer_Load_Config(Handle:timer)
{
	if(adminCancelLoad || adminLoadActive) return Plugin_Continue;

	ServerCommand("exec %s", LoadCommandConfigToExecuteName);
}

public Action:Timer_Admin_Load_Config(Handle:timer)
{
	if(adminCancelLoad) return Plugin_Continue;

	ServerCommand("exec %s", AdminLoadCommandConfigToExecuteName);

	return Plugin_Continue;
}

Action Timer_Map_Change(Handle timer, any data)
{
	if (adminCancelMap || adminMapActive) return Plugin_Continue;

	CampaignchangeDelayed();

	return Plugin_Continue;
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
	if (client == 0) return Plugin_Handled;
	new bool:id = IsPlayerGenericAdmin(client);

	if(id == false && adminCancelLoad == true)
	{
		CPrintToChat(client, "[{olive}TS{default}] %T","command is not available.",client,"!load");
		return Plugin_Handled;
	}

	if (args < 1)
	{
		new bool:isAdmin = false;
		new bool:isLoadAllowed = false;
	
		if (id == true) isAdmin = true;
		
		isLoadAllowed = CompLoaderAllowLoad.BoolValue;
		
		if (isAdmin == false && isLoadAllowed == false)
		{
			ReplyToCommand(client, "[TS] %T","command is disabled.",client,"!load");
			return Plugin_Handled;
		}
		
		decl String:loadInfo[1024];
		loadInfo[0] = '\0'; 
		if(isAdmin == true) Format(loadInfo, 1024, "| command          | force load               | config that gets loaded       |\n");
		else Format(loadInfo, 1024, "| command          | request to load          | config that gets loaded       |\n");
		Format(loadInfo, 1024, "%s|------------------|--------------------------|-------------------------------|\n",loadInfo);

		if(strlen(cfg5v5) > 0) 
		Format(loadInfo, 1024, "%s| !load 5v5        | 5v5 hardcore config      | %30s|\n", loadInfo, cfg5v5);
		if(strlen(cfg4v4) > 0) 
		Format(loadInfo, 1024, "%s| !load 4v4        | 4v4 hardcore config      | %30s|\n", loadInfo, cfg4v4);
		if(strlen(cfg4v4classic) > 0) 
		Format(loadInfo, 1024, "%s| !load 4v4 classic| 4v4 classic config       | %30s|\n", loadInfo, cfg4v4classic);
		if(strlen(cfg4v4Pub) > 0) 
		Format(loadInfo, 1024, "%s| !load 4v4 pub    | 4v4 pub config           | %30s|\n", loadInfo, cfg4v4Pub);
		if(strlen(cfg4v4PubHuters) > 0) 
		Format(loadInfo, 1024, "%s| !load 4v4 pub hu | 4v4 pub hunter config    | %30s|\n", loadInfo, cfg4v4PubHuters);
		if(strlen(cfg3v3) > 0) 
		Format(loadInfo, 1024, "%s| !load 3v3        | 3v3 hardcore config      | %30s|\n", loadInfo, cfg3v3);
		if(strlen(cfg2v2) > 0) 
		Format(loadInfo, 1024, "%s| !load 2v2        | 2v2 hardcore config      | %30s|", loadInfo, cfg2v2);
		if(strlen(loadInfo) > 0) PrintToConsole(client, loadInfo);

		loadInfo[0] = '\0'; 
		if(strlen(cfg5v5hunters) > 0) 
		Format(loadInfo, 1024, "%s| !load 5v5 hu     | 5v5 hunters only config  | %30s|\n", loadInfo, cfg5v5hunters);
		if(strlen(cfg4v4hunters) > 0) 
		Format(loadInfo, 1024, "%s| !load 4v4 hu     | 4v4 hunters only config  | %30s|\n", loadInfo, cfg4v4hunters);
		if(strlen(cfg3v3hunters) > 0) 
		Format(loadInfo, 1024, "%s| !load 3v3 hu     | 3v3 hunters only config  | %30s|\n", loadInfo, cfg3v3hunters);
		if(strlen(cfg2v2hunters) > 0) 
		Format(loadInfo, 1024, "%s| !load 2v2 hu     | 2v2 hunters only config  | %30s|\n", loadInfo, cfg2v2hunters);
		if(strlen(cfg1v1hunters) > 0) 
		Format(loadInfo, 1024, "%s| !load 1v1        | 1v1 hunters only config  | %30s|", loadInfo, cfg1v1hunters);
		if(strlen(loadInfo) > 0) PrintToConsole(client, loadInfo);

		loadInfo[0] = '\0'; 
		Format(loadInfo, 1024, "%s| !load 1v2        | 1v2 hunters only config  | %30s|\n", loadInfo, cfg1v2hunters);
		if(strlen(cfg1v3hunters) > 0) 
		Format(loadInfo, 1024, "%s| !load 1v3        | 1v3 hunters only config  | %30s|\n", loadInfo, cfg1v3hunters);
		if(strlen(cfg1v4hunters) > 0) 
		Format(loadInfo, 1024, "%s| !load 1v4        | 1v4 hunters only config  | %30s|\n", loadInfo, cfg1v4hunters);
		if(strlen(cfg1v5hunters) > 0) 
		Format(loadInfo, 1024, "%s| !load 1v5        | 1v5 hunters only config  | %30s|\n", loadInfo, cfg1v5hunters);
		if(strlen(cfg2v3hunters) > 0) 
		Format(loadInfo, 1024, "%s| !load 2v3        | 2v3 hunters only config  | %30s|\n", loadInfo, cfg2v3hunters);
		if(strlen(cfg2v4hunters) > 0) 
		Format(loadInfo, 1024, "%s| !load 2v4        | 2v4 hunters only config  | %30s|\n", loadInfo, cfg2v4hunters);
		if(strlen(cfg2v5hunters) > 0) 
		Format(loadInfo, 1024, "%s| !load 2v5        | 2v5 hunters only config  | %30s|\n", loadInfo, cfg2v5hunters);
		if(strlen(cfg3v4hunters) > 0) 
		Format(loadInfo, 1024, "%s| !load 3v4        | 3v4 hunters only config  | %30s|\n", loadInfo, cfg3v4hunters);
		if(strlen(cfg3v5hunters) > 0) 
		Format(loadInfo, 1024, "%s| !load 3v5        | 3v5 hunters only config  | %30s|\n", loadInfo, cfg3v5hunters);
		if(strlen(cfg4v5hunters) > 0) 
		Format(loadInfo, 1024, "%s| !load 4v5        | 4v5 hunters only config  | %30s|\n", loadInfo, cfg4v5hunters);

		if(strlen(cfgdarkcoop) > 0) 
		Format(loadInfo, 1024, "%s| !load dc         | Dark Coop config         | %30s|\n", loadInfo, cfgdarkcoop);
		if(strlen(cfgwitchparty) > 0) 
		Format(loadInfo, 1024, "%s| !load wp         | Witch Party config       | %30s|", loadInfo, cfgwitchparty);
		if(strlen(loadInfo) > 0) PrintToConsole(client, loadInfo);

		loadInfo[0] = '\0';
		if(isAdmin == true) Format(loadInfo, 1024, "%s| !load cancel     | cancel all requests      |                               |\n", loadInfo);
		//else Format(loadInfo, 1024, "%s| !load cancel     | cancel the request       |                               |\n", loadInfo);
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
		new AdminValueIsConfigPub = 0 ;
		new AdminValueIsConfigHunters = 0;	//is config hunters integer, on function start set to 0
		new AdminValueIsConfigNoBoomer = 0;

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

		if((StrContains(Admin_Cfg, "dc", false) != -1)) AdminValueIsConfigdc = 1;
		if((StrContains(Admin_Cfg, "dark coop", false) != -1)) AdminValueIsConfigdc = 1;

		if((StrContains(Admin_Cfg, "classic", false) != -1)) AdminValueIsConfigClassic = 1;	//if string contains hu, set value to 1
		
		if((StrContains(Admin_Cfg, "pub", false) != -1)) AdminValueIsConfigPub = 1;
		
		if((StrContains(Admin_Cfg, "hu", false) != -1)) AdminValueIsConfigHunters = 1;	//if string contains hu, set value to 1	
		if((StrContains(Admin_Cfg, "nob", false) != -1)) AdminValueIsConfigNoBoomer = 1;	//if string contains hu, set value to 1
		if((StrContains(Admin_Cfg, "nb", false) != -1)) AdminValueIsConfigNoBoomer = 1;	//if string contains hu, set value to 1	

		if(StrEqual(Admin_Cfg, "cancel", false))//checking if config is cancel, if it is, cancel this plugin, and jump to the admin config, stop this plugin
		{
			Admin_Cancel(client, 0);
			return Plugin_Handled;
		}

		if (adminLoadActive || isMapRestartPending) return Plugin_Handled;
		
		if(AdminValueIsConfig5v5 == 1)	//if the config is 5v5
		{
			if(AdminValueIsConfigNoBoomer == 1)
			{
				if(strlen(cfg5v5Nob) > 0)
				{
					SetConVarInt(CompLoaderLoadActive, 0);
					SetConVarInt(CompLoaderMapActive, 0);
					GetConVarString(CompLoader5v5NobConfig, AdminLoadCommandConfigToExecuteName, 128);
					CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t", AdminName,"comp_loader2","5v5 No Boomer");
					
					Admin_Cancel_Lite();
					
					CreateTimer(3.0, Timer_Admin_Load_Config, TIMER_FLAG_NO_MAPCHANGE);
					return Plugin_Handled;		
				}			
			}
			else if(AdminValueIsConfigHunters == 0)
			{
				if(strlen(cfg5v5) > 0)
				{
					SetConVarInt(CompLoaderLoadActive, 0);
					SetConVarInt(CompLoaderMapActive, 0);
					GetConVarString(CompLoader5v5Config, AdminLoadCommandConfigToExecuteName, 128);
					CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader2","5v5 hardcore");
					
					Admin_Cancel_Lite();
					
					CreateTimer(3.0, Timer_Admin_Load_Config, TIMER_FLAG_NO_MAPCHANGE);
					return Plugin_Handled;	
				}				
			}
			else
			{
				if(strlen(cfg5v5hunters) > 0)
				{
					SetConVarInt(CompLoaderLoadActive, 0);
					SetConVarInt(CompLoaderMapActive, 0);
					GetConVarString(CompLoader5v5HuntersConfig, AdminLoadCommandConfigToExecuteName, 128);
					CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t", AdminName,"comp_loader2","5v5 Hunters Only");	//if hunters allowed 0
					
					Admin_Cancel_Lite();
					
					CreateTimer(3.0, Timer_Admin_Load_Config, TIMER_FLAG_NO_MAPCHANGE);
					return Plugin_Handled;
				}
			}
		}
		else if(AdminValueIsConfig4v4 == 1)	//if the config is 4v4
		{
			if(AdminValueIsConfigNoBoomer == 1)
			{
				if(strlen(cfg4v4Nob) > 0)
				{
					SetConVarInt(CompLoaderLoadActive, 0);
					SetConVarInt(CompLoaderMapActive, 0);
					GetConVarString(CompLoader4v4NobConfig, AdminLoadCommandConfigToExecuteName, 128);
					CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader2","4v4 No Boomer");
				
					Admin_Cancel_Lite();
				
					CreateTimer(3.0, Timer_Admin_Load_Config, TIMER_FLAG_NO_MAPCHANGE);
					return Plugin_Handled;	
				}				
			}
			else if(AdminValueIsConfigHunters == 1)
			{
				if(AdminValueIsConfigPub == 1)
				{
					if(strlen(cfg4v4PubHuters) > 0)
					{
						SetConVarInt(CompLoaderLoadActive, 0);
						SetConVarInt(CompLoaderMapActive, 0);
						GetConVarString(CompLoader4v4PubHubtersConfig, AdminLoadCommandConfigToExecuteName, 128);
						CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader2","4v4 Pub Hunters Only");	//if hunters allowed 0
						
						Admin_Cancel_Lite();
						
						CreateTimer(3.0, Timer_Admin_Load_Config, TIMER_FLAG_NO_MAPCHANGE);
						return Plugin_Handled;
					}	
				}
				else
				{
					if(strlen(cfg4v4hunters) > 0)
					{
						SetConVarInt(CompLoaderLoadActive, 0);
						SetConVarInt(CompLoaderMapActive, 0);
						GetConVarString(CompLoader4v4HuntersConfig, AdminLoadCommandConfigToExecuteName, 128);
						CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader2","4v4 Hunters Only");	//if hunters allowed 0
						
						Admin_Cancel_Lite();
						
						CreateTimer(3.0, Timer_Admin_Load_Config, TIMER_FLAG_NO_MAPCHANGE);
						return Plugin_Handled;
					}	
				}			
			}
			else if(AdminValueIsConfigClassic == 1)
			{
				if(strlen(cfg4v4classic) > 0)
				{
					SetConVarInt(CompLoaderLoadActive, 0);
					SetConVarInt(CompLoaderMapActive, 0);
					GetConVarString(CompLoader4v4ClassicConfig, AdminLoadCommandConfigToExecuteName, 128);
					CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader2","4v4 Classic");
					
					Admin_Cancel_Lite();
					
					CreateTimer(3.0, Timer_Admin_Load_Config, TIMER_FLAG_NO_MAPCHANGE);
					return Plugin_Handled;
				}
			}
			else if(AdminValueIsConfigPub == 1)
			{
				if(strlen(cfg4v4Pub) > 0)
				{
					SetConVarInt(CompLoaderLoadActive, 0);
					SetConVarInt(CompLoaderMapActive, 0);
					GetConVarString(CompLoader4v4PubConfig, AdminLoadCommandConfigToExecuteName, 128);
					CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader2","4v4 Pub");
					
					Admin_Cancel_Lite();
					
					CreateTimer(3.0, Timer_Admin_Load_Config, TIMER_FLAG_NO_MAPCHANGE);
					return Plugin_Handled;
				}
			}
			else
			{
				if(strlen(cfg4v4) > 0)
				{
					SetConVarInt(CompLoaderLoadActive, 0);
					SetConVarInt(CompLoaderMapActive, 0);
					GetConVarString(CompLoader4v4Config, AdminLoadCommandConfigToExecuteName, 128);
					CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader2","4v4 Hardcore");
					
					Admin_Cancel_Lite();
					
					CreateTimer(3.0, Timer_Admin_Load_Config, TIMER_FLAG_NO_MAPCHANGE);
					return Plugin_Handled;
				}
			}
		}
		else if(AdminValueIsConfig3v3 == 1)	//if the config is 3v3
		{
			if(AdminValueIsConfigNoBoomer == 1)
			{
				if(strlen(cfg3v3Nob) > 0)
				{
					SetConVarInt(CompLoaderLoadActive, 0);
					SetConVarInt(CompLoaderMapActive, 0);
					GetConVarString(CompLoader3v3NobConfig, AdminLoadCommandConfigToExecuteName, 128);
					CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader2","3v3 No Boomer");
					
					Admin_Cancel_Lite();
					
					CreateTimer(3.0, Timer_Admin_Load_Config, TIMER_FLAG_NO_MAPCHANGE);
					return Plugin_Handled;	
				}				
			}
			else if(AdminValueIsConfigHunters == 0)	//if hunters allowed 1
			{
				if(strlen(cfg3v3) > 0)
				{
					SetConVarInt(CompLoaderLoadActive, 0);
					SetConVarInt(CompLoaderMapActive, 0);
					GetConVarString(CompLoader3v3Config, AdminLoadCommandConfigToExecuteName, 128);
					CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader2","3v3 hardcore");
					
					Admin_Cancel_Lite();
					
					CreateTimer(3.0, Timer_Admin_Load_Config, TIMER_FLAG_NO_MAPCHANGE);
					return Plugin_Handled;
				}
			}
			else 
			{
				if(strlen(cfg3v3hunters) > 0)
				{
					SetConVarInt(CompLoaderLoadActive, 0);
					SetConVarInt(CompLoaderMapActive, 0);
					GetConVarString(CompLoader3v3HuntersConfig, AdminLoadCommandConfigToExecuteName, 128);
					CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader2","3v3 Hunters Only");	//if hunters allowed 0
					
					Admin_Cancel_Lite();
					
					CreateTimer(3.0, Timer_Admin_Load_Config, TIMER_FLAG_NO_MAPCHANGE);
					return Plugin_Handled;
				}
			}
		}
		else if(AdminValueIsConfig2v2 == 1)	//if the config is 2v2
		{
			if(AdminValueIsConfigNoBoomer == 1)
			{
				if(strlen(cfg2v2Nob) > 0)
				{
					SetConVarInt(CompLoaderLoadActive, 0);
					SetConVarInt(CompLoaderMapActive, 0);
					GetConVarString(CompLoader2v2NobConfig, AdminLoadCommandConfigToExecuteName, 128);
					CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader2","2v2 No Boomer");
					
					Admin_Cancel_Lite();
					
					CreateTimer(3.0, Timer_Admin_Load_Config, TIMER_FLAG_NO_MAPCHANGE);
					return Plugin_Handled;
				}					
			}
			else if(AdminValueIsConfigHunters == 0)	//if hunters allowed 1
			{
				if(strlen(cfg2v2) > 0)
				{
					SetConVarInt(CompLoaderLoadActive, 0);
					SetConVarInt(CompLoaderMapActive, 0);
					GetConVarString(CompLoader2v2Config, AdminLoadCommandConfigToExecuteName, 128);
					CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader2","2v2 hardcore");
					
					Admin_Cancel_Lite();
					
					CreateTimer(3.0, Timer_Admin_Load_Config, TIMER_FLAG_NO_MAPCHANGE);
					return Plugin_Handled;
				}
			}
			else 
			{
				if(strlen(cfg2v2hunters) > 0)
				{
					SetConVarInt(CompLoaderLoadActive, 0);
					SetConVarInt(CompLoaderMapActive, 0);
					GetConVarString(CompLoader2v2HuntersConfig, AdminLoadCommandConfigToExecuteName, 128);
					CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader2","2v2 Hunters Only");	//if hunters allowed 0
					
					Admin_Cancel_Lite();
					
					CreateTimer(3.0, Timer_Admin_Load_Config, TIMER_FLAG_NO_MAPCHANGE);
					return Plugin_Handled;
				}
			}
		}
		else if(AdminValueIsConfig1v1 == 1)	//if the config is 1v1
		{
			if(strlen(cfg1v1hunters) > 0)
			{
				SetConVarInt(CompLoaderLoadActive, 0);
				SetConVarInt(CompLoaderMapActive, 0);
				GetConVarString(CompLoader1v1HuntersConfig, AdminLoadCommandConfigToExecuteName, 128);
				CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader2","1v1 Hunters Only");
				CreateTimer(3.0, Timer_Admin_Load_Config, TIMER_FLAG_NO_MAPCHANGE);
				return Plugin_Handled;
			}
		}

		if(AdminValueIsConfig1v2 == 1)	//if the config is 1v2
		{
			if(strlen(cfg1v2hunters) > 0)
			{
				SetConVarInt(CompLoaderLoadActive, 0);
				SetConVarInt(CompLoaderMapActive, 0);
				GetConVarString(CompLoader1v2HuntersConfig, AdminLoadCommandConfigToExecuteName, 128);
				CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader2","1v2 Hunters Only");
				CreateTimer(3.0, Timer_Admin_Load_Config, TIMER_FLAG_NO_MAPCHANGE);
				return Plugin_Handled;
			}
		}
		else if(AdminValueIsConfig1v3 == 1)	//if the config is 1v3
		{
			if(strlen(cfg1v3hunters) > 0)
			{
				SetConVarInt(CompLoaderLoadActive, 0);
				SetConVarInt(CompLoaderMapActive, 0);
				GetConVarString(CompLoader1v3HuntersConfig, AdminLoadCommandConfigToExecuteName, 128);
				CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader2","1v3 Hunters Only");
				CreateTimer(3.0, Timer_Admin_Load_Config, TIMER_FLAG_NO_MAPCHANGE);
				return Plugin_Handled;
			}
		}
		else if(AdminValueIsConfig1v4 == 1)	//if the config is 1v4
		{
			if(strlen(cfg1v4hunters) > 0)
			{
				SetConVarInt(CompLoaderLoadActive, 0);
				SetConVarInt(CompLoaderMapActive, 0);
				GetConVarString(CompLoader1v4HuntersConfig, AdminLoadCommandConfigToExecuteName, 128);
				CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader2","1v4 Hunters Only");
				CreateTimer(3.0, Timer_Admin_Load_Config, TIMER_FLAG_NO_MAPCHANGE);
				return Plugin_Handled;
			}
		}			
		else if(AdminValueIsConfig1v5 == 1)	//if the config is 1v5
		{
			if(strlen(cfg1v5hunters) > 0)
			{
				SetConVarInt(CompLoaderLoadActive, 0);
				SetConVarInt(CompLoaderMapActive, 0);
				GetConVarString(CompLoader1v5HuntersConfig, AdminLoadCommandConfigToExecuteName, 128);
				CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader2","1v5 Hunters Only");
				CreateTimer(3.0, Timer_Admin_Load_Config, TIMER_FLAG_NO_MAPCHANGE);
				return Plugin_Handled;
			}
		}			
		else if(AdminValueIsConfig2v3 == 1)	//if the config is 2v3
		{
			if(strlen(cfg2v3hunters) > 0)
			{
				SetConVarInt(CompLoaderLoadActive, 0);
				SetConVarInt(CompLoaderMapActive, 0);
				GetConVarString(CompLoader2v3HuntersConfig, AdminLoadCommandConfigToExecuteName, 128);
				CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader2","2v3 Hunters Only");
				CreateTimer(3.0, Timer_Admin_Load_Config, TIMER_FLAG_NO_MAPCHANGE);
				return Plugin_Handled;
			}
		}
		else if(AdminValueIsConfig2v4 == 1)	//if the config is 2v4
		{
			if(strlen(cfg2v4hunters) > 0)
			{
				SetConVarInt(CompLoaderLoadActive, 0);
				SetConVarInt(CompLoaderMapActive, 0);
				GetConVarString(CompLoader2v4HuntersConfig, AdminLoadCommandConfigToExecuteName, 128);
				CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader2","2v4 Hunters Only");
				CreateTimer(3.0, Timer_Admin_Load_Config, TIMER_FLAG_NO_MAPCHANGE);
				return Plugin_Handled;
			}
		}
		else if(AdminValueIsConfig2v5 == 1)	//if the config is 2v5
		{
			if(strlen(cfg2v5hunters) > 0)
			{
				SetConVarInt(CompLoaderLoadActive, 0);
				SetConVarInt(CompLoaderMapActive, 0);
				GetConVarString(CompLoader2v5HuntersConfig, AdminLoadCommandConfigToExecuteName, 128);
				CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader2","2v5 Hunters Only");
				CreateTimer(3.0, Timer_Admin_Load_Config, TIMER_FLAG_NO_MAPCHANGE);
				return Plugin_Handled;
			}
		}
		else if(AdminValueIsConfig3v4 == 1)	//if the config is 3v4
		{
			if(strlen(cfg3v4hunters) > 0)
			{
				SetConVarInt(CompLoaderLoadActive, 0);
				SetConVarInt(CompLoaderMapActive, 0);
				GetConVarString(CompLoader3v4HuntersConfig, AdminLoadCommandConfigToExecuteName, 128);
				CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader2","3v4 Hunters Only");
				CreateTimer(3.0, Timer_Admin_Load_Config, TIMER_FLAG_NO_MAPCHANGE);
				return Plugin_Handled;
			}
		}
		else if(AdminValueIsConfig3v5 == 1)	//if the config is 3v5
		{
			if(strlen(cfg3v5hunters) > 0)
			{
				SetConVarInt(CompLoaderLoadActive, 0);
				SetConVarInt(CompLoaderMapActive, 0);
				GetConVarString(CompLoader3v5HuntersConfig, AdminLoadCommandConfigToExecuteName, 128);
				CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader2","3v5 Hunters Only");
				CreateTimer(3.0, Timer_Admin_Load_Config, TIMER_FLAG_NO_MAPCHANGE);
				return Plugin_Handled;
			}
		}
		else if(AdminValueIsConfig4v5 == 1)	//if the config is 4v5
		{
			if(strlen(cfg4v5hunters) > 0)
			{
				SetConVarInt(CompLoaderLoadActive, 0);
				SetConVarInt(CompLoaderMapActive, 0);
				GetConVarString(CompLoader4v5HuntersConfig, AdminLoadCommandConfigToExecuteName, 128);
				CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader2","4v5 Hunters Only");
				CreateTimer(3.0, Timer_Admin_Load_Config, TIMER_FLAG_NO_MAPCHANGE);
				return Plugin_Handled;
			}
		}
		else if(AdminValueIsConfigwp == 1)	//if the config is witch party
		{
			if(strlen(cfgwitchparty) > 0)
			{
				SetConVarInt(CompLoaderLoadActive, 0);
				SetConVarInt(CompLoaderMapActive, 0);
				GetConVarString(CompLoaderWitchPartyConfig, AdminLoadCommandConfigToExecuteName, 128);
				CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader2","Witch Party");
				CreateTimer(3.0, Timer_Admin_Load_Config, TIMER_FLAG_NO_MAPCHANGE);
				return Plugin_Handled;
			}
		}
		else if(AdminValueIsConfigdc == 1)	//if the config is dark coop
		{
			if(strlen(cfgdarkcoop) > 0)
			{
				SetConVarInt(CompLoaderLoadActive, 0);
				SetConVarInt(CompLoaderMapActive, 0);
				GetConVarString(CompLoaderDarkCoopConfig, AdminLoadCommandConfigToExecuteName, 128);
				CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader2","Dark Coop");
				CreateTimer(3.0, Timer_Admin_Load_Config, TIMER_FLAG_NO_MAPCHANGE);
				return Plugin_Handled;
			}
		}
		
		CPrintToChat(client, "[{olive}TS{default}] %T","Invalid Config.",client);
		adminLoadActive = false;
		return Plugin_Handled;
	}

	if (id == false)	//if client is non admin then...
	{
		if(adminLoadActive || isMapRestartPending) return Plugin_Handled;
		if(g_hMatchVote != null)  return Plugin_Handled;

		new Client_Team		= GetClientTeam(client);
		int Opposite_Team	= (Client_Team == TEAM_SURVIVOR) ? TEAM_INFECTED : TEAM_SURVIVOR;
		
		//decl String:SurvivorCfg[128];		//gets string value of PlayerCfg when Team A requests !load
		//decl String:InfectedCfg[128];		//gets string value of PlayerCfg when Team B requests !load

		bool LoadAllowed = CompLoaderAllowLoad.BoolValue;		//converting the string value to integer
		if(LoadAllowed == true)		//if comp_loader_load_allowed = 1
		{
			//LogMessage("LoadAllowed returned 1");	//debug, log to file that comp_loader_load_allowed = 1
			if(Client_Team == TEAM_SURVIVOR || Client_Team == TEAM_INFECTED)	//if the client using !load is either survivor or infected
			{
				GetCmdArgString(PlayerCfg, sizeof(PlayerCfg));			//getting the !load arguments to PlayerCfg string
				new ValueIsConfig5v5 = 0;		//is config 5v5 integer, on function start set to 0
				new ValueIsConfigClassic = 0;
				new ValueIsConfigPub = 0;
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
				
				new ValueIsConfigHunters = 0;	//is config hunters integer, on function start set to 0
				new ValueIsConfigNoBoomer = 0;

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
				
				if((StrContains(PlayerCfg, "dc", false) != -1)) ValueIsConfigdc = 1;
				if((StrContains(PlayerCfg, "dark coop", false) != -1)) ValueIsConfigdc = 1;
				
				if((StrContains(PlayerCfg, "classic", false) != -1)) ValueIsConfigClassic = 1;	//if string contains hu, set value to 1
				
				if((StrContains(PlayerCfg, "pub", false) != -1)) ValueIsConfigPub = 1;	//if string contains hu, set value to 1
				
				if((StrContains(PlayerCfg, "hu", false) != -1)) ValueIsConfigHunters = 1;	//if string contains hu, set value to 1
				if((StrContains(PlayerCfg, "nob", false) != -1)) ValueIsConfigNoBoomer = 1;	//if string contains hu, set value to 1
				if((StrContains(PlayerCfg, "no", false) != -1)) ValueIsConfigNoBoomer = 1;	//if string contains hu, set value to 1	
				if((StrContains(PlayerCfg, "nb", false) != -1)) ValueIsConfigNoBoomer = 1;	//if string contains hu, set value to 1	

				if(StrEqual(PlayerCfg, "cancel", false))//cancel configs before validating config, if the args are "cancel"
				{
					if(Config_Requests[Opposite_Team] && !Config_Requests[Client_Team])
					{
						CPrintToChatAll("[{olive}TS{default}] %t","The team have canceled the command request.", Team_Names[Client_Team],"!load");
						Config_Requests[TEAM_SURVIVOR] = false;
						Config_Requests[TEAM_INFECTED] = false;
						SetConVarInt(CompLoaderLoadActive, 0);
						return Plugin_Handled;
					}
					
					if(!Config_Requests[Opposite_Team])
					{
						CPrintToChat(client, "[{olive}TS{default}] %T","Nothing to cancel.",client);
						return Plugin_Handled;
					}
					return Plugin_Handled;
				}
				
				bool bIsValidConfig = false;
				if(ValueIsConfig5v5 == 1)	//if the config is 5v5
				{
					if(ValueIsConfigHunters != 1)	//if config is hunters 0
					{
						if(strlen(cfg5v5) > 0)
						{
							PlayerCfg = "5v5";
							bIsValidConfig = true;
						}
					}
					else 
					{
						if(strlen(cfg5v5hunters) > 0)
						{
							PlayerCfg = "5v5 Hunter";	//if config is hunters 1
							bIsValidConfig = true;
						}
					}
					if(ValueIsConfigNoBoomer == 1)
					{
						if(strlen(cfg5v5Nob) > 0)
						{
							PlayerCfg = "5v5 No Boomer"; //if config is no boomer		
							bIsValidConfig = true;
						}	
					}		
				}
				else if(ValueIsConfig4v4 == 1)	//if the config is 4v4
				{
					if(ValueIsConfigHunters != 1)	//if config is hunters 0
					{
						if(ValueIsConfigClassic == 1)
						{
							if(strlen(cfg4v4classic) > 0)
							{
								PlayerCfg = "4v4 Classic";
								bIsValidConfig = true;
							}
						}
						else if(ValueIsConfigPub == 1)
						{
							if(strlen(cfg4v4Pub) > 0)
							{
								PlayerCfg = "4v4 Pub";
								bIsValidConfig = true;
							}
						}
						else
						{
							if(strlen(cfg4v4) > 0)
							{
								PlayerCfg = "4v4";
								bIsValidConfig = true;
							}
						}
					}
					else
					{
						if(ValueIsConfigPub == 1)
						{
							if(strlen(cfg4v4PubHuters) > 0)
							{
								PlayerCfg = "4v4 Pub Hunter";	//if config is hunters 1
								bIsValidConfig = true;
							}
						}
						else
						{
							if(strlen(cfg4v4hunters) > 0)
							{
								PlayerCfg = "4v4 Hunter";	//if config is hunters 1
								bIsValidConfig = true;
							}
						}
					}
					if(ValueIsConfigNoBoomer == 1)
					{
						if(strlen(cfg4v4Nob) > 0)
						{
							PlayerCfg = "4v4 No Boomer"; //if config is no boomer
							bIsValidConfig = true;
						}
					}	
				}
				else if(ValueIsConfig3v3 == 1)	//if the config is 3v3
				{
					if(ValueIsConfigHunters != 1)	//if config is hunters 0
					{
						if(strlen(cfg3v3) > 0)
						{
							PlayerCfg = "3v3";
							bIsValidConfig = true;
						}
					}
					else
					{
						if(strlen(cfg3v3hunters) > 0)
						{
							PlayerCfg = "3v3 Hunter";	//if config is hunters 1
							bIsValidConfig = true;
						}
					}

					if(ValueIsConfigNoBoomer == 1)
					{
						if(strlen(cfg3v3Nob) > 0)
						{
							PlayerCfg = "3v3 No Boomer"; //if config is no boomer	
							bIsValidConfig = true;
						}
					}
				}
				else if(ValueIsConfig2v2 == 1)	//if the config is 2v2
				{
					if(ValueIsConfigHunters != 1)	//if config is hunters 0
					{
						if(strlen(cfg2v2) > 0)
						{
							PlayerCfg = "2v2";
							bIsValidConfig = true;
						}
					}
					else
					{
						if(strlen(cfg2v2hunters) > 0)
						{
							PlayerCfg = "2v2 Hunter";	//if config is hunters 1
							bIsValidConfig = true;
						}
					}
						
					if(ValueIsConfigNoBoomer == 1)
					{
						if(strlen(cfg2v2Nob) > 0)
						{
							PlayerCfg = "2v2 No Boomer"; //if config is no boomer	
							bIsValidConfig = true;
						}	
					}	
				}
				else if(ValueIsConfig1v1 == 1)	//if the config is 1v1
				{
					if(strlen(cfg1v1hunters) > 0)
					{
						PlayerCfg = "1v1";
						bIsValidConfig = true;
					}
				}
				else if(ValueIsConfig1v2 == 1)	//if the config is 1v2, defaults to hunter only because 1v2 is always hunter only
				{
					if(strlen(cfg1v2hunters) > 0)
					{
						PlayerCfg = "1v2";
						bIsValidConfig = true;
					}
				}
				else if(ValueIsConfig1v3 == 1)	//if the config is 1v3, defaults to hunter only because 1v3 is always hunter only
				{
					if(strlen(cfg1v3hunters) > 0)
					{
						PlayerCfg = "1v3";
						bIsValidConfig = true;
					}
				}
				else if(ValueIsConfig1v4 == 1)	//if the config is 1v4, defaults to hunter only because 1v4 is always hunter only
				{
					if(strlen(cfg1v4hunters) > 0)
					{
						PlayerCfg = "1v4";
						bIsValidConfig = true;
					}
				}
				else if(ValueIsConfig1v5 == 1)	//if the config is 1v5, defaults to hunter only because 1v5 is always hunter only
				{
					if(strlen(cfg1v5hunters) > 0)
					{
						PlayerCfg = "1v5";
						bIsValidConfig = true;
					}
				}
				else if(ValueIsConfig2v3 == 1)	//if the config is 2v3, defaults to hunter only because 2v3 is always hunter only
				{
					if(strlen(cfg2v3hunters) > 0)
					{
						PlayerCfg = "2v3";
						bIsValidConfig = true;
					}
				}
				else if(ValueIsConfig2v4 == 1)	//if the config is 2v4, defaults to hunter only because 2v4 is always hunter only
				{
					if(strlen(cfg2v4hunters) > 0)
					{
						PlayerCfg = "2v4";
						bIsValidConfig = true;
					}
				}
				else if(ValueIsConfig2v5 == 1)	//if the config is 2v5, defaults to hunter only because 2v5 is always hunter only
				{
					if(strlen(cfg2v5hunters) > 0)
					{
						PlayerCfg = "2v5";
						bIsValidConfig = true;
					}
				}
				else if(ValueIsConfig3v4 == 1)	//if the config is 3v4, defaults to hunter only because 3v4 is always hunter only
				{
					if(strlen(cfg3v4hunters) > 0)
					{
						PlayerCfg = "3v4";
						bIsValidConfig = true;
					}
				}
				else if(ValueIsConfig3v5 == 1)	//if the config is 3v5, defaults to hunter only because 3v5 is always hunter only
				{
					if(strlen(cfg3v5hunters) > 0)
					{
						PlayerCfg = "3v5";
						bIsValidConfig = true;
					}
				}
				else if(ValueIsConfig4v5 == 1)	//if the config is 4v5, defaults to hunter only because 4v5 is always hunter only
				{
					if(strlen(cfg4v5hunters) > 0)
					{
						PlayerCfg = "4v5";
						bIsValidConfig = true;
					}
				}
				else if(ValueIsConfigwp == 1)
				{
					if(strlen(cfgwitchparty) > 0)
					{
						PlayerCfg = "wp";
						bIsValidConfig = true;
					}
				}
				else if(ValueIsConfigdc == 1)
				{
					if(strlen(cfgdarkcoop) > 0)
					{
						PlayerCfg = "dc";
						bIsValidConfig = true;
					}
				}
				
				if(!bIsValidConfig)
				{
					CPrintToChat(client, "[{olive}TS{default}] %t","Invalid Config.", client); //if sum of configs is less than 1 or more than 2, print invalid config
					return Plugin_Handled;
				}	

				// if(!Config_Requests[Opposite_Team] == false)
				// {
				// 	SurvivorCfg = PlayerCfg;	//OppositeTeam argument string gets saved to SurvivorCfg
				// }			
				// else if(!Config_Requests[Client_Team] == true)
				// {
				// 	InfectedCfg = PlayerCfg;	//ClientTeam argument string gets saved to InfectedCfg
				// }
				
				if (!TestMatchDelay(client))
				{
					return Plugin_Handled;	
				}
				
				if(StrEqual(PlayerCfg, "5v5", false))
				{
					GetConVarString(CompLoader5v5Config, LoadCommandConfigToExecuteName, 128);																	
				}
				else if(StrEqual(PlayerCfg, "4v4 Classic", false))
				{
					GetConVarString(CompLoader4v4ClassicConfig, LoadCommandConfigToExecuteName, 128);																		
				}
				else if(StrEqual(PlayerCfg, "4v4 Pub", false))
				{
					GetConVarString(CompLoader4v4PubConfig, LoadCommandConfigToExecuteName, 128);																		
				}
				else if(StrEqual(PlayerCfg, "4v4 Pub Hunter", false))
				{
					GetConVarString(CompLoader4v4PubHubtersConfig, LoadCommandConfigToExecuteName, 128);																		
				}
				else if(StrEqual(PlayerCfg, "4v4", false))
				{
					GetConVarString(CompLoader4v4Config, LoadCommandConfigToExecuteName, 128);																	
				}
				else if(StrEqual(PlayerCfg, "3v3", false))
				{
					GetConVarString(CompLoader3v3Config, LoadCommandConfigToExecuteName, 128);																	
				}
				else if(StrEqual(PlayerCfg, "2v2", false))
				{
					GetConVarString(CompLoader2v2Config, LoadCommandConfigToExecuteName, 128);																		
				}
			
				if(StrEqual(PlayerCfg, "5v5 No Boomer", false))
				{
					GetConVarString(CompLoader4v4NobConfig, LoadCommandConfigToExecuteName, 128);																	
				}
				else if(StrEqual(PlayerCfg, "4v4 No Boomer", false))
				{
					GetConVarString(CompLoader4v4NobConfig, LoadCommandConfigToExecuteName, 128);																		
				}
				else if(StrEqual(PlayerCfg, "3v3 No Boomer", false))
				{
					GetConVarString(CompLoader3v3NobConfig, LoadCommandConfigToExecuteName, 128);																	
				}
				else if(StrEqual(PlayerCfg, "2v2 No Boomer", false))
				{
					GetConVarString(CompLoader2v2NobConfig, LoadCommandConfigToExecuteName, 128);																		
				}
				else if(StrEqual(PlayerCfg, "1v1", false))
				{
					GetConVarString(CompLoader1v1HuntersConfig, LoadCommandConfigToExecuteName, 128);																		
				}
				else if(StrEqual(PlayerCfg, "1v2", false))
				{
					GetConVarString(CompLoader1v2HuntersConfig, LoadCommandConfigToExecuteName, 128);																		
				}
				else if(StrEqual(PlayerCfg, "1v3", false))
				{
					GetConVarString(CompLoader1v3HuntersConfig, LoadCommandConfigToExecuteName, 128);																		
				}
				else if(StrEqual(PlayerCfg, "1v4", false))
				{
					GetConVarString(CompLoader1v4HuntersConfig, LoadCommandConfigToExecuteName, 128);																		
				}
				else if(StrEqual(PlayerCfg, "1v5", false))
				{
					GetConVarString(CompLoader1v5HuntersConfig, LoadCommandConfigToExecuteName, 128);																		
				}
				else if(StrEqual(PlayerCfg, "2v3", false))
				{
					GetConVarString(CompLoader2v3HuntersConfig, LoadCommandConfigToExecuteName, 128);																		
				}
				else if(StrEqual(PlayerCfg, "2v4", false))
				{
					GetConVarString(CompLoader2v4HuntersConfig, LoadCommandConfigToExecuteName, 128);																		
				}
				else if(StrEqual(PlayerCfg, "2v5", false))
				{
					GetConVarString(CompLoader2v5HuntersConfig, LoadCommandConfigToExecuteName, 128);																		
				}
				else if(StrEqual(PlayerCfg, "3v4", false))
				{
					GetConVarString(CompLoader3v4HuntersConfig, LoadCommandConfigToExecuteName, 128);																		
				}
				else if(StrEqual(PlayerCfg, "3v5", false))
				{
					GetConVarString(CompLoader3v5HuntersConfig, LoadCommandConfigToExecuteName, 128);																		
				}
				else if(StrEqual(PlayerCfg, "4v5", false))
				{
					GetConVarString(CompLoader4v5HuntersConfig, LoadCommandConfigToExecuteName, 128);																		
				}
				else if(StrEqual(PlayerCfg, "wp", false))
				{
					GetConVarString(CompLoaderWitchPartyConfig, LoadCommandConfigToExecuteName, 128);																		
				}
				else if(StrEqual(PlayerCfg, "dc", false))
				{
					GetConVarString(CompLoaderDarkCoopConfig, LoadCommandConfigToExecuteName, 128);																		
				}
				else if(StrEqual(PlayerCfg, "5v5 Hunter", false))
				{
					GetConVarString(CompLoader5v5HuntersConfig, LoadCommandConfigToExecuteName, 128);																	
				}
				else if(StrEqual(PlayerCfg, "4v4 Hunter", false))
				{
					GetConVarString(CompLoader4v4HuntersConfig, LoadCommandConfigToExecuteName, 128);																		
				}
				else if(StrEqual(PlayerCfg, "3v3 Hunter", false))
				{
					GetConVarString(CompLoader3v3HuntersConfig, LoadCommandConfigToExecuteName, 128);																		
				}
				else if(StrEqual(PlayerCfg, "2v2 Hunter", false))
				{
					GetConVarString(CompLoader2v2HuntersConfig, LoadCommandConfigToExecuteName, 128);																		
				}
				
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
	if (adminCancelMap) return;

	PrintHintTextToAll("%t","comp_loader6",CAMPAIGN_CHANGE_DELAY+1);
	isMapRestartPending = true;
	CampaingChangeDelay = CAMPAIGN_CHANGE_DELAY;
	delete MapCountdownTimer;
	MapCountdownTimer = CreateTimer(1.0, timerCampaignchange, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}
public Action:timerCampaignchange(Handle:timer)
{
	if (adminCancelMap)
	{
		MapCountdownTimer = null;
		return Plugin_Stop;
	}

	if (CampaingChangeDelay <= 0)
	{
		//EmitSoundToAll("buttons/blip2.wav", _, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.5);
		Map_Change_NOW();
		MapCountdownTimer = null;
		return Plugin_Stop;
	}
	
	PrintHintTextToAll("%t","comp_loader6", CampaingChangeDelay);
	EmitSoundToAll("buttons/blip1.wav", _, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.5);
	CampaingChangeDelay--;

	return Plugin_Continue;
}

Map_Change_NOW()
{
	if(adminMapActive)
		ServerCommand("changelevel %s", AdminMapToExecuteName);
	else
		ServerCommand("changelevel %s", MapToExecuteName);
}

public Action:Map_Changer(client, args)
{
	if (client == 0) return Plugin_Handled;

	new bool:id = IsPlayerGenericAdmin(client);

	if(id == false && adminCancelMap == true)
	{
		CPrintToChat(client, "[{olive}TS{default}] %T","command is not available.",client,"!changemap(!cm)");
		return Plugin_Handled;
	}

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

		ReplyToCommand(client, "[TS] %T","Check the console for available commands.",client);
		
		static char mapInfo[MAPINFPMAXLEN];
		FormatEx(mapInfo, MAPINFPMAXLEN,    "|----------------------|-----------------------------------|\n");
		Format(mapInfo, MAPINFPMAXLEN,  "%s| !cm da               | Change Map to Dead Air            |\n",mapInfo);
		Format(mapInfo, MAPINFPMAXLEN,  "%s| !cm deadair          |                                   |\n",mapInfo);		
		Format(mapInfo, MAPINFPMAXLEN,  "%s|----------------------|-----------------------------------|\n",mapInfo);
		Format(mapInfo, MAPINFPMAXLEN,  "%s| !cm dt               | Change Map to Death Toll          |\n",mapInfo);
		Format(mapInfo, MAPINFPMAXLEN,  "%s| !cm deathtoll        |                                   |\n",mapInfo);		
		Format(mapInfo, MAPINFPMAXLEN,  "%s|----------------------|-----------------------------------|\n",mapInfo);
		Format(mapInfo, MAPINFPMAXLEN,  "%s| !cm bh               | Change Map to Blood Harvest       |\n",mapInfo);
		Format(mapInfo, MAPINFPMAXLEN,  "%s| !cm bloodharvest     |                                   |",mapInfo);		
		PrintToConsole(client, mapInfo);

		FormatEx(mapInfo, MAPINFPMAXLEN,   "|----------------------|-----------------------------------|\n");
		Format(mapInfo, MAPINFPMAXLEN, "%s| !cm nm               | Change Map to No Mercy            |\n",mapInfo);
		Format(mapInfo, MAPINFPMAXLEN, "%s| !cm nomercy          |                                   |\n",mapInfo);		
		Format(mapInfo, MAPINFPMAXLEN, "%s|----------------------|-----------------------------------|\n",mapInfo);
		Format(mapInfo, MAPINFPMAXLEN, "%s| !cm cc               | Change Map to Crash Course        |\n",mapInfo);
		Format(mapInfo, MAPINFPMAXLEN, "%s| !cm crashcourse      |                                   |\n",mapInfo);		
		Format(mapInfo, MAPINFPMAXLEN, "%s|----------------------|-----------------------------------|\n",mapInfo);
		Format(mapInfo, MAPINFPMAXLEN, "%s| !cm ts               |                                   |\n",mapInfo);
		Format(mapInfo, MAPINFPMAXLEN, "%s| !cm sa               | Change Map to The Sacrifice       |\n",mapInfo);
		Format(mapInfo, MAPINFPMAXLEN, "%s| !cm thesacrifice     |                                   |",mapInfo);
		PrintToConsole(client, mapInfo);

		FormatEx(mapInfo, MAPINFPMAXLEN,   "|----------------------|-----------------------------------|\n");
		Format(mapInfo, MAPINFPMAXLEN, "%s| !cm c17              | Change Map to City 17             |\n",mapInfo);
		Format(mapInfo, MAPINFPMAXLEN, "%s| !cm city17           |                                   |\n",mapInfo);		
		Format(mapInfo, MAPINFPMAXLEN, "%s|----------------------|-----------------------------------|\n",mapInfo);
		Format(mapInfo, MAPINFPMAXLEN, "%s| !cm sb               | Change Map to Suicide Blitz       |\n",mapInfo);
		Format(mapInfo, MAPINFPMAXLEN, "%s| !cm suicideblitz     |                                   |\n",mapInfo);	
		Format(mapInfo, MAPINFPMAXLEN, "%s|----------------------|-----------------------------------|\n",mapInfo);
		Format(mapInfo, MAPINFPMAXLEN, "%s| !cm ihm              | Change Map to I Hate Mountain     |\n",mapInfo);
		Format(mapInfo, MAPINFPMAXLEN, "%s| !cm ihatemountain    |                                   |\n",mapInfo);		
		Format(mapInfo, MAPINFPMAXLEN, "%s|----------------------|-----------------------------------|\n",mapInfo);
		Format(mapInfo, MAPINFPMAXLEN, "%s| !cm dfb              | Change Map to Dead Flag Blue      |\n",mapInfo);
		Format(mapInfo, MAPINFPMAXLEN, "%s| !cm deadflagblues    |                                   |\n",mapInfo);	
		Format(mapInfo, MAPINFPMAXLEN, "%s|----------------------|-----------------------------------|\n",mapInfo);
		Format(mapInfo, MAPINFPMAXLEN, "%s| !cm dbd              | Change Map to Dead Before Dawn    |\n",mapInfo);
		Format(mapInfo, MAPINFPMAXLEN, "%s| !cm deadbeforedawn   |                                   |",mapInfo);		
		PrintToConsole(client, mapInfo);

		FormatEx(mapInfo, MAPINFPMAXLEN,   "|----------------------|-----------------------------------|\n");
		Format(mapInfo, MAPINFPMAXLEN, "%s| !cm aotd             | Change Map to The Area Of The Dead|\n",mapInfo);
		Format(mapInfo, MAPINFPMAXLEN, "%s| !cm thearenaofthedead|                                   |\n",mapInfo);
		Format(mapInfo, MAPINFPMAXLEN, "%s|----------------------|-----------------------------------|\n",mapInfo);
		Format(mapInfo, MAPINFPMAXLEN, "%s| !cm dab              | Change Map to Death Aboard        |\n",mapInfo);
		Format(mapInfo, MAPINFPMAXLEN, "%s| !cm deathaboard      |                                   |\n",mapInfo);
		Format(mapInfo, MAPINFPMAXLEN, "%s|----------------------|-----------------------------------|\n",mapInfo);
		Format(mapInfo, MAPINFPMAXLEN, "%s| !cm 149              | Change Map to One 4 Nine          |\n",mapInfo);
		Format(mapInfo, MAPINFPMAXLEN, "%s| !cm one4nine         |                                   |",mapInfo);
		PrintToConsole(client, mapInfo);

		FormatEx(mapInfo, MAPINFPMAXLEN,   "|----------------------|-----------------------------------|\n");
		Format(mapInfo, MAPINFPMAXLEN, "%s| !cm db               | Change Map to Dark Blood          |\n",mapInfo);
		Format(mapInfo, MAPINFPMAXLEN, "%s| !cm dark blood       |                                   |\n",mapInfo);
		Format(mapInfo, MAPINFPMAXLEN, "%s|----------------------|-----------------------------------|\n",mapInfo)
		Format(mapInfo, MAPINFPMAXLEN, "%s| !cm bha              | Change Map to Blood Harvest APOCALYPSE|\n",mapInfo);
		Format(mapInfo, MAPINFPMAXLEN, "%s| !cm bloodharvestapocalypse|                              |\n",mapInfo);
		Format(mapInfo, MAPINFPMAXLEN, "%s|----------------------|-----------------------------------|\n",mapInfo)
		Format(mapInfo, MAPINFPMAXLEN, "%s| !cm p84              | Change Map to Precinct 84         |\n",mapInfo);
		Format(mapInfo, MAPINFPMAXLEN, "%s| !cm precinct 84      |                                   |",mapInfo);
		PrintToConsole(client, mapInfo);

		FormatEx(mapInfo, MAPINFPMAXLEN,   "|----------------------|-----------------------------------|\n");
		Format(mapInfo, MAPINFPMAXLEN, "%s| !cm cotd             | Change Map to City Of The Dead    |\n",mapInfo);
		Format(mapInfo, MAPINFPMAXLEN, "%s| !cm cityofthedead    |                                   |\n",mapInfo);
		Format(mapInfo, MAPINFPMAXLEN, "%s|----------------------|-----------------------------------|\n",mapInfo);
		Format(mapInfo, MAPINFPMAXLEN, "%s| !cm dv               | Change Map to Dead Vacation       |\n",mapInfo);
		Format(mapInfo, MAPINFPMAXLEN, "%s| !cm deadvacation     |                                   |\n",mapInfo);
		Format(mapInfo, MAPINFPMAXLEN, "%s|----------------------|-----------------------------------|\n",mapInfo);
		Format(mapInfo, MAPINFPMAXLEN, "%s| !cm uz               | Undead Zone                       |\n",mapInfo);
		Format(mapInfo, MAPINFPMAXLEN, "%s| !cm undeadzone       |                                   |",mapInfo);
		PrintToConsole(client, mapInfo);

		FormatEx(mapInfo, MAPINFPMAXLEN,   "|----------------------|-----------------------------------|\n");
		if(isAdmin == true) Format(mapInfo, MAPINFPMAXLEN, "%s| !cm cancel           | cancel all requests               |\n", mapInfo);
		else Format(mapInfo, MAPINFPMAXLEN, "%s| !cm cancel           | cancel the request                |\n", mapInfo);
		Format(mapInfo, MAPINFPMAXLEN,      "%s|----------------------|-----------------------------------|", mapInfo);	
		PrintToConsole(client, mapInfo);

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
			Admin_Cancel(client, 1);
			return Plugin_Handled;
		}

		if (isMapRestartPending || adminMapActive) return Plugin_Handled;//正在倒數換圖或是admin已經強制換圖


		static char sFullMapName[64];
		if(g_smMapName_ShortToFull.GetString(Admin_Map, sFullMapName, sizeof(sFullMapName)))
		{
			Admin_Cancel_Lite();
			SetConVarInt(CompLoaderLoadActive, 0);
			SetConVarInt(CompLoaderMapActive, 0);
			g_smMapName_FullToCode.GetString(sFullMapName, AdminMapToExecuteName, sizeof(AdminMapToExecuteName))
			CPrintToChatAll("[{olive}TS{default}] {lightgreen}%s{default} %t",AdminName,"comp_loader7",sFullMapName);
			CampaignchangeDelayed();
			return Plugin_Handled;	
		}
		else
		{
			CPrintToChat(client, "[{olive}TS{default}] %T","Invalid Map.",client);
		}
	}

	if (id == false)	//if client is non admin then...
	{
		if (isMapRestartPending || adminMapActive) return Plugin_Handled;//正在倒數換圖或是admin已經強制換圖

		if (!TestMatchDelay(client))
		{
			return Plugin_Handled;
		}

		new Client_Team		= GetClientTeam(client),
		Opposite_Team	= (Client_Team == TEAM_SURVIVOR) ? TEAM_INFECTED : TEAM_SURVIVOR;	//getting dem client teamz. If client team is survivor, then opposite team is infected, else opposite team is survivorzor
		
		decl String:PlayerMap[64];			//Initial string after !changemap
		decl String:PlayerMapChat[32];		//da or dt or etc etc for the chat print
		decl String:SurvivorMap[64];		//gets string value of PlayerMap when Team A requests !load
		decl String:InfectedMap[64];		//gets string value of PlayerMap when Team B requests !load

		decl String:MapIsAllowed[2];		//Temp string to get the convar value of comp_loader_allow_load 1 / 0
	
		GetConVarString(CompLoaderAllowMap, MapIsAllowed, 2);				//setting the value of the convar to the string
	
		new MapAllowed = StringToInt(MapIsAllowed);		//converting the string value to integer
		
		if(MapAllowed != 0)		//if comp_loader_load_allowed = 1
		{
			//LogMessage("LoadAllowed returned 1");	//debug, log to file that comp_loader_load_allowed = 1
			if(Client_Team == TEAM_SURVIVOR || Client_Team == TEAM_INFECTED)	//if the client using !load is either survivor or infected
			{
				GetCmdArgString(PlayerMap, sizeof(PlayerMap));			//getting the !load arguments to PlayerMap string

				if(StrEqual(PlayerMap, "cancel", false))//cancel configs before validating config, if the args are "cancel"
				{
					if(Map_Requests[Client_Team])
					{
						CPrintToChatAll("[{olive}TS{default}] %t","The team have canceled the command request.", Team_Names[Client_Team],"!changemap(!cm)");
						Map_Requests[TEAM_SURVIVOR] = false;
						Map_Requests[TEAM_INFECTED] = false;
						SetConVarInt(CompLoaderMapActive, 0);
						return Plugin_Handled;						
					}
					if(Map_Requests[Opposite_Team] && !Map_Requests[Client_Team])
					{
						CPrintToChatAll("[{olive}TS{default}] %t","The team have canceled the command request.", Team_Names[Client_Team],"!changemap(!cm)");
						Map_Requests[TEAM_SURVIVOR] = false;
						Map_Requests[TEAM_INFECTED] = false;
						SetConVarInt(CompLoaderMapActive, 0);
						return Plugin_Handled;
					}
					if(!Map_Requests[Opposite_Team])
					{
						CPrintToChat(client, "[{olive}TS{default}] %T","Nothing to cancel.",client);
						return Plugin_Handled;
					}

					return Plugin_Handled;
				}
				
				static char sFullMapName[64];
				if(g_smMapName_ShortToFull.GetString(PlayerMap, sFullMapName, sizeof(sFullMapName)))
				{
					g_smMapName_FullToRequest.GetString(sFullMapName, PlayerMapChat, sizeof(PlayerMapChat))
					g_smMapName_FullToCode.GetString(sFullMapName, MapToExecuteName, sizeof(MapToExecuteName))
				}
				else
				{
					CPrintToChat(client, "[{olive}TS{default}] %T","Invalid Mapname.", client);
					return Plugin_Handled;
				}

				if(!Map_Requests[Opposite_Team] == false)
				{
					SurvivorMap = sFullMapName;	//OppositeTeam argument string gets saved to SurvivorMap (which is actually just the first team)
				}			
				else if(!Map_Requests[Client_Team] == true)
				{
					InfectedMap = sFullMapName;	//ClientTeam argument string gets saved to InfectedMap
				}			
				if(!Map_Requests[Client_Team])	//if client team did not ask for !changemap yet then
				{
					Map_Requests[Client_Team] = true;	//if client team asks for !changemap exec, set Config_Requests to true, so they can only ask to exec once
										
					if(!Map_Requests[Opposite_Team])		//if opponent team did not !changemap, then...
					{
						CPrintToChatAll("[{olive}TS{default}] %t.\n%t","comp_loader8", Team_Names[Client_Team], sFullMapName,"The team must agree by typing command", Team_Names[Opposite_Team],"!cm", PlayerMapChat);
						SetConVarInt(CompLoaderMapActive, 1);
					}
					else if(Map_Requests[TEAM_SURVIVOR] && Map_Requests[TEAM_INFECTED])	//if both client team have requested, and the opposite team have requested/responded, then...
					{
						if(StrEqual(InfectedMap, SurvivorMap, false))	//if both teams' string have the same value then...
						{
							SetConVarInt(CompLoaderMapActive, 0);	//this disables the timer from printing [TS] Request timed out., even though its function still happens later
							
							CPrintToChatAll("[{olive}TS{default}] %t","comp_loader9", Team_Names[Client_Team], sFullMapName);
							Map_Requests[TEAM_SURVIVOR] = false;		//resetting to false so the function can be run through again
							Map_Requests[TEAM_INFECTED] = false;		//resetting this should also prevent the playing teams to cancel the config, since there are no requests to cancel
							
							CreateTimer(1.0, Timer_Map_Change, _, TIMER_FLAG_NO_MAPCHANGE);					
							return Plugin_Handled;
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
	MapCountdownTimer = null;
	isMapRestartPending = false;
	
	Config_Requests[TEAM_SURVIVOR] = false;
	Config_Requests[TEAM_INFECTED] = false;
	Map_Requests[TEAM_SURVIVOR] = false;
	Map_Requests[TEAM_INFECTED] = false;
	
	adminCancelLoad = false;
	adminCancelMap = false;
	adminLoadActive = false;
	adminMapActive = false;
	
	numberOfLoadTimers = 0;
	SetConVarInt(CompLoaderLoadActive, 0);
	
	numberOfMapTimers = 0;										//resets the map timers to 0 active
	SetConVarInt(CompLoaderMapActive, 0);		//sets the convar to 0 on new map
	

	CompLoaderEnabledValue = GetConVarInt(CompLoaderEnabled);
	CheckMapName();
	ExecConfig();
	
	PrecacheSound("ui/menu_enter05.wav");
	PrecacheSound("ui/beep_synthtone01.wav");
	PrecacheSound("ui/beep_error01.wav");
	
	VoteMenuClose();
}

public void OnMapEnd()
{
	Admin_Cancel_Lite();
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
	if(adminCancelLoad || adminLoadActive) return Plugin_Continue;

	CreateTimer(0.1, Timer_Load_Config, TIMER_FLAG_NO_MAPCHANGE);
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
	if(adminCancelLoad || adminLoadActive) return Plugin_Continue;

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
 	if(g_hMatchVote != null || IsVoteInProgress())
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
		if(adminCancelLoad || adminLoadActive) return 0;

		CPrintToChatAll("{default}[{olive}TS{default}] %t","No votes");
		g_votedelay = VOTEDELAY_TIME;
		CreateTimer(1.0, Timer_VoteDelay, _, TIMER_REPEAT| TIMER_FLAG_NO_MAPCHANGE);
		EmitSoundToAll("ui/beep_error01.wav");
		CreateTimer(2.0, VoteEndDelay);
	}	
	else if (action == MenuAction_VoteEnd)
	{
		if(adminCancelLoad || adminLoadActive) return 0;

		if ((strcmp(item, VOTE_YES) == 0 && FloatCompare(percent,limit) < 0 && param1 == 0) || (strcmp(item, VOTE_NO) == 0 && param1 == 1))
		{
			g_votedelay = VOTEDELAY_TIME;
			CreateTimer(1.0, Timer_VoteDelay, _, TIMER_REPEAT| TIMER_FLAG_NO_MAPCHANGE);
			EmitSoundToAll("ui/beep_error01.wav");
			CPrintToChatAll("{default}[{olive}TS{default}] %t","Vote fail.", RoundToNearest(100.0*limit), RoundToNearest(100.0*percent), totalVotes);
			CreateTimer(2.0, VoteEndDelay);
		}
		else
		{
			g_votedelay = VOTEDELAY_TIME;
			CreateTimer(1.0, Timer_VoteDelay, _, TIMER_REPEAT| TIMER_FLAG_NO_MAPCHANGE);
			EmitSoundToAll("ui/menu_enter05.wav");
			CPrintToChatAll("{default}[{olive}TS{default}] %t","Vote pass.", RoundToNearest(100.0*percent), totalVotes);
			CreateTimer(2.0, VoteEndDelay);
			CreateTimer(6.0,COLD_DOWN,_);

			isMapRestartPending = true;
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
		if(adminCancelLoad || adminLoadActive) return 0;
		
		CPrintToChatAll("{default}[{olive}TS{default}] %t","No votes");
		g_votedelay = VOTEDELAY_TIME;
		CreateTimer(1.0, Timer_VoteDelay, _, TIMER_REPEAT| TIMER_FLAG_NO_MAPCHANGE);
		EmitSoundToAll("ui/beep_error01.wav");
		CreateTimer(2.0, VoteEndDelay);
	}	
	else if (action == MenuAction_VoteEnd)
	{
		if(adminCancelLoad || adminLoadActive) return 0;

		if ((strcmp(item, VOTE_YES) == 0 && FloatCompare(percent,limit) < 0 && param1 == 0) || (strcmp(item, VOTE_NO) == 0 && param1 == 1))
		{
			g_votedelay = VOTEDELAY_TIME;
			CreateTimer(1.0, Timer_VoteDelay, _, TIMER_REPEAT| TIMER_FLAG_NO_MAPCHANGE);
			EmitSoundToAll("ui/beep_error01.wav");
			CPrintToChatAll("{default}[{olive}TS{default}] %t","Vote fail.", RoundToNearest(100.0*limit), RoundToNearest(100.0*percent), totalVotes);
			CreateTimer(2.0, VoteEndDelay);
		}
		else
		{
			g_votedelay = VOTEDELAY_TIME;
			CreateTimer(1.0, Timer_VoteDelay, _, TIMER_REPEAT| TIMER_FLAG_NO_MAPCHANGE);
			EmitSoundToAll("ui/menu_enter05.wav");
			CPrintToChatAll("{default}[{olive}TS{default}] %t","Vote pass.", RoundToNearest(100.0*percent), totalVotes);
			CreateTimer(2.0, VoteEndDelay);
			CreateTimer(6.0, COLD_DOWN2,_);

			isMapRestartPending = true;
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