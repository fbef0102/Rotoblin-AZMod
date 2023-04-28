#pragma semicolon 1
#include <sourcemod>
#include <multicolors>
#include <sdkhooks>
#include <sdktools>
#include <left4dhooks>
#include <l4d_lib>
/*
* PROGRAMMING CREDITS:
* Could not do this without Fyren at all, it was his original code chunk 
* 	that got me started (especially turning off directors and freezing players).
* 	Thanks to him for answering all of my silly coding questions too.
* 
* TESTING CREDITS:
* 
* Biggest #1 thanks goes out to Fission for always being there since the beginning
* even when this plugin was barely working.
*/

#define READY_DEBUG 0
#define READY_DEBUG_LOG 0

#define READY_VERSION "8.4.1"
#define READY_LIVE_COUNTDOWN 2
#define READY_UNREADY_HINT_PERIOD 5.0
#define READY_LIST_PANEL_LIFETIME 2
#define READY_RESTART_ROUND_DELAY 5.0
#define READY_RESTART_MAP_DELAY 2
#define PreventSpecBlockInfectedTeamIcon_DELAY 5.0
#define NULL_VELOCITY view_as<float>({0.0, 0.0, 0.0})

#define READY_VERSION_REQUIRED_SOURCEMOD "1.10"
#define READY_VERSION_REQUIRED_SOURCEMOD_NONDEV 1 //1 dont allow -dev version, 0 ignore -dev version

#define L4D_TEAM_SURVIVORS 2
#define L4D_TEAM_INFECTED 3
#define L4D_TEAM_SPECTATE 1
#define STEAMID_SIZE 		32
static const ARRAY_TEAM = 1;

//stuff from rotoblin report status
#define	REPORT_STATUS_MAX_MSG_LENGTH 1024

#define HEALTH_BONUS_FIX 1

#if HEALTH_BONUS_FIX

#define EBLOCK_DEBUG READY_DEBUG

#define EBLOCK_BONUS_UPDATE_DELAY 0.01

#define EBLOCK_VERSION "0.1.2"

#if EBLOCK_DEBUG
#define EBLOCK_BONUS_HEALTH_BUFFER 10.0
#else
#define EBLOCK_BONUS_HEALTH_BUFFER 1.0
#endif

#define EBLOCK_USE_DELAYED_UPDATES 0
#define LEAGUE_ADD_NOTICE 1

new bool:painPillHolders[256];
#endif

/*
* TEST - should be fixed: the "error more than 1 witch spawned in a single round"
*  keeps being printed
* even though there isnt an extra witch being spawned or w/e
*/

new bool:readyMode; //currently waiting for players to ready up?

new goingLive; //0 = not going live, 1 or higher = seconds until match starts

new bool:votesUnblocked;
new insideCampaignRestart; //0=normal play, 1 or 2=programatically restarting round
new bool:isCampaignBeingRestarted;

new forcedStart;
new readyStatus[MAXPLAYERS + 1];

//new bool:menuInterrupted[MAXPLAYERS + 1];
new Handle:menuPanel = INVALID_HANDLE;

new Handle:liveTimer;
new bool:unreadyTimerExists;

new bool:g_bGameTeamSwitchBlock;
ConVar cvarEnforceReady, g_hGameTimeBlock;
new Handle:cvarReadyCompetition = INVALID_HANDLE;
new Handle:cvarReadyHalves = INVALID_HANDLE;
new Handle:cvarReadyServerCfg = INVALID_HANDLE;
new Handle:cvarReadySpectatorRUP = INVALID_HANDLE;
new Handle:cvarReadyRestartRound = INVALID_HANDLE;
new Handle:cvarReadyLeagueNotice = INVALID_HANDLE;
new Handle:cvarReadyLiveCountdown = INVALID_HANDLE;
new Handle:readyCountdownTimer;
new Handle:MapCountdownTimer;

//new way of readying up?
new Handle:cvarReadyUpStyle = INVALID_HANDLE;

new Handle:cvarReadyCommonLimit	= INVALID_HANDLE;
new Handle:cvarReadyMegaMobSize	= INVALID_HANDLE;
new Handle:cvarReadyAllBotTeam	= INVALID_HANDLE;

new Handle:fwdOnReadyRoundRestarted = INVALID_HANDLE;

new hookedPlayerHurt; //if we hooked player_hurt event?

new pauseBetweenHalves; //should we ready up before starting the 2nd round or go live right away
new bool:isSecondRound;

new bool:isMapRestartPending = false;
new bool:inLiveCountdown = false;
new SB_STOP_CONVAR;
new readyDelay;
new MapRestartDelay;

//stuff from zack_netinfo
static			bool:	g_bCooldown[MAXPLAYERS + 1];
//
//fix spec calling !reready
static			bool:	g_bIsSpectating[MAXPLAYERS + 1];

//workaround for the spec/inf bug
static 			bool:infectedSpectator[MAXPLAYERS + 1];
static 			g_iSpectatePenalty 							= 10;
static			g_iSpectatePenaltyCounter[MAXPLAYERS + 1];
static 			Handle:cvarSpectatePenalty					= INVALID_HANDLE;
//stuff from griffins rup edit
static			g_iRespecCooldownTime						= 60;
static			g_iLastRespecced[MAXPLAYERS + 1];
//stuff from rotoblin report status
static	const			MAX_CONVAR_NAME_LENGTH							= 64;
static	const			CVAR_ARRAY_BLOCK								= 2;
static	const			FIRST_CVAR_IN_ARRAY								= 0;
static			Handle:	g_aConVarArray									= INVALID_HANDLE;
static			bool:	g_bIsArraySetup									= false;

static	const	Float:	CACHE_RESULT_TIME								= 5.0;
static			bool:	g_bIsResultCached								= false;
static			String:	g_sResultCache[REPORT_STATUS_MAX_MSG_LENGTH]	= "";
static 			bool:hasdirectorStart = false;

new bool:InSecondHalfOfRound;
#define MAX(%0,%1) (((%0) > (%1)) ? (%0) : (%1))

native GetTankPercent();
native GetWitchPercent();
native GetSurCurrent();
native PrintBossPercents();
native ChoseTankPrintWhoBecome();
native OpenSpectatorsListenMode();
native GiveSurAllPills();
native ShowRotoInfo();
native R2comp_UnscrambleKeep(); //From l4d_team_unscramble.smx
native bool:IsClientVoteMenu(client);//From Votes2
native bool:IsClientInfoMenu(client);//From l4d_Harry_Roto2-AZ_mod_info
native AnnounceSIClasses();//From si_class_announce
native antibaiter_clear();//From l4d_antibaiter
native Score_GetTeamCampaignScore(team);//From l4dscores
native Keep_SI_Starting(); //From l4d_QuadCaps

new String:HostName[256];
new change;
new Handle:g_hDirectorNoDeathCheck = INVALID_HANDLE;
new Handle:g_hCvarGameMode = INVALID_HANDLE;
new String:CurrentGameMode[32];
new bool:blockSecretSpam[MAXPLAYERS + 1];
#define SECRET_EGG_SOUND "ui/pickup_misc42.wav"
new TimeCount;
new Float:g_fButtonTime[MAXPLAYERS + 1];
new g_fPlayerMouse[MAXPLAYERS + 1][2];
new bool:hasleftsaferoom;
static Handle:arrayclientswitchteam;
bool hiddenPanel[MAXPLAYERS+1];
int g_iRoundStart,g_iPlayerSpawn ;
//timer
Handle PlayerLeftStartTimer = null, CountDownTimer = null;
int g_iCountDownTime, g_iCvarGameTimeBlock;
static KeyValues g_hMIData = null;

public Plugin:myinfo =
{
	name = "L4D Ready Up",
	author = "Downtown1, modded by Jackpf,modify by Harry",
	description = "Force Players to Ready Up Before Beginning Match",
	version = READY_VERSION,
	url = "http://steamcommunity.com/profiles/76561198026784913"
};

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	EngineVersion test = GetEngineVersion();
	
	if( test != Engine_Left4Dead )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1.");
		return APLRes_SilentFailure;
	}

	CreateNative("IsInReady", Native_IsInReady);
	CreateNative("Is_Ready_Plugin_On",Native_Is_Ready_Plugin_On);
	CreateNative("ToggleReadyPanel",		Native_ToggleReadyPanel);

	fwdOnReadyRoundRestarted = CreateGlobalForward("L4D_OnRoundIsLive", ET_Ignore);

	return APLRes_Success;
}

public OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("Roto2-AZ_mod.phrases");
	
	//case-insensitive handling of ready,unready,notready
	RegConsoleCmd("say", Command_Say);
	RegConsoleCmd("say_team", Command_Say);

	RegConsoleCmd("sm_hide",			Hide_Cmd, "Hides the ready-up panel so other menus can be seen");
	RegConsoleCmd("sm_show",			Show_Cmd, "Shows a hidden ready-up panel");
	RegConsoleCmd("sm_return", Return_Cmd, "Return to a valid saferoom spawn if you get stuck during an unfrozen ready-up period");
	
	RegConsoleCmd("sm_F", readyUp);
	RegConsoleCmd("sm_unready", readyDown);
	RegConsoleCmd("sm_notready", readyDown); //alias for people who are bad at reading instructions
	
	RegConsoleCmd("sm_rates", ratesCommand);	//Prints net information about players
	RegConsoleCmd("zack_netinfo", ratesCommand);	//Some people...
	
	RegConsoleCmd("sm_jg", Join_Survivor);
	RegConsoleCmd("sm_join", Join_Survivor);
	RegConsoleCmd("sm_bot", Join_Survivor);
	RegConsoleCmd("sm_jointeam", Join_Survivor);
	RegConsoleCmd("sm_survivors", Join_Survivor);
	RegConsoleCmd("sm_survivor", Join_Survivor);
	RegConsoleCmd("sm_sur", Join_Survivor);
	RegConsoleCmd("sm_joinsurvivors", Join_Survivor);
	RegConsoleCmd("sm_joinsurvivor", Join_Survivor);
	RegConsoleCmd("sm_jointeam2", Join_Survivor);
	RegConsoleCmd("sm_takebot", Join_Survivor);
	RegConsoleCmd("sm_takeover", Join_Survivor);

	RegConsoleCmd("sm_infected", Join_Infected);
	RegConsoleCmd("sm_infecteds", Join_Infected);
	RegConsoleCmd("sm_inf", Join_Infected);
	RegConsoleCmd("sm_joininfected", Join_Infected);
	RegConsoleCmd("sm_jointeam3", Join_Infected);
	RegConsoleCmd("sm_zombie", Join_Infected);

	//block all voting if we're enforcing ready mode
	//we only temporarily allow votes to fake restart the campaign
	RegConsoleCmd("callvote", callVote);
	
	RegConsoleCmd("sm_spectate", Command_Spectate);
	RegConsoleCmd("sm_s", Command_Spectate);
	RegConsoleCmd("sm_afk", Command_Spectate);
	RegConsoleCmd("sm_away", Command_Spectate);
	RegConsoleCmd("sm_spec", Command_Spectate);
	RegConsoleCmd("sm_idle", Command_Spectate);
	RegConsoleCmd("sm_joinspectator", Command_Spectate);
	RegConsoleCmd("sm_joinspectators", Command_Spectate);
	RegConsoleCmd("sm_jointeam1 ", Command_Spectate);
	RegConsoleCmd("sm_spectate ", Command_Spectate);
	RegConsoleCmd("sm_spectators", Command_Spectate);          
	RegConsoleCmd("sm_respec", Respec_Client);
	RegConsoleCmd("sm_respectate", Respec_Client);
	RegConsoleCmd("jointeam", WTF); //player press M
	
	#if READY_DEBUG
	RegConsoleCmd("unfreezeme1", Command_Unfreezeme1);	
	RegConsoleCmd("unfreezeme2", Command_Unfreezeme2);	
	RegConsoleCmd("unfreezeme3", Command_Unfreezeme3);	
	RegConsoleCmd("unfreezeme4", Command_Unfreezeme4);
	
	RegConsoleCmd("sm_printclients", printClients);
	
	RegConsoleCmd("sm_votestart", SendVoteRestartStarted);
	RegConsoleCmd("sm_votepass", SendVoteRestartPassed);
	
	RegConsoleCmd("sm_whoready", readyWho);
	
	RegConsoleCmd("sm_drawready", readyDraw);
	
	RegConsoleCmd("sm_dumpentities", Command_DumpEntities);
	RegConsoleCmd("sm_dumpgamerules", Command_DumpGameRules);
	RegConsoleCmd("sm_scanproperties", Command_ScanProperties);
	
	RegAdminCmd("sm_begin", compReady, ADMFLAG_BAN, "sm_begin");
	#endif
	
	RegAdminCmd("sm_restartmap", CommandRestartMap, ADMFLAG_CHANGEMAP, "sm_restartmap - changelevels to the current map");
	RegAdminCmd("sm_rs", CommandRestartMap, ADMFLAG_CHANGEMAP, "sm_restartmap - changelevels to the current map");
	//RegAdminCmd("sm_restartround", FakeRestartVoteCampaign, ADMFLAG_CHANGEMAP, "sm_restartround - executes a restart campaign vote and makes everyone votes yes");
	
	RegAdminCmd("sm_forcestart", compStart, ADMFLAG_BAN, "sm_forcestart");
	RegAdminCmd("sm_fs", compStart, ADMFLAG_BAN, "sm_forcestart");
	//sm_switch
	RegAdminCmd("sm_switch", Switch_Client, ADMFLAG_BAN, "sm_switch <player1> <player2> - switch A to B's team, and B to A's team.");
	
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd); //對抗上下回合結束的時候觸發
	HookEvent("map_transition", Event_RoundEnd); //戰役過關到下一關的時候 (之後沒有觸發round_end)
	HookEvent("mission_lost", Event_RoundEnd); //戰役滅團重來該關卡的時候 (之後有觸發round_end)
	HookEvent("finale_vehicle_leaving", Event_RoundEnd); //救援載具離開之時  (之後沒有觸發round_end)
	
	HookEvent("player_bot_replace", eventPlayerBotReplaceCallback);
	HookEvent("bot_player_replace", eventBotPlayerReplaceCallback);
	HookEvent("player_team", eventPlayerTeamCallback);
	
	HookEvent("player_spawn", Event_PlayerSpawn);

	#if READY_DEBUG
	HookEvent("vote_started", eventVoteStarted);
	HookEvent("vote_passed", eventVotePassed);
	HookEvent("vote_ended", eventVoteEnded);

	new Handle:NoBosses = FindConVar("director_no_bosses");
	HookConVarChange(NoBosses, ConVarChange_DirectorNoBosses);
	#endif
	
	CreateConVar("l4d_ready_version", READY_VERSION, "Version of the ready up plugin.", FCVAR_SPONLY | FCVAR_NOTIFY);
	cvarEnforceReady = CreateConVar("l4d_ready_enabled", "0", "Make players ready up before a match begins", FCVAR_SPONLY | FCVAR_NOTIFY);
	g_hGameTimeBlock = CreateConVar("l4d_teamswitch_during_game_seconds_block", "60", "Player can switch team until players have left start safe area for at least x seconds (0=off).", FCVAR_NOTIFY, true, 0.0);
	cvarReadyCompetition = CreateConVar("l4d_ready_competition", "0", "Disable all plugins but a few competition-allowed ones", FCVAR_SPONLY | FCVAR_NOTIFY);
	cvarReadyHalves = CreateConVar("l4d_ready_both_halves", "0", "Make players ready up both during the first and second rounds of a map", FCVAR_SPONLY | FCVAR_NOTIFY);
	cvarReadyServerCfg = CreateConVar("l4d_ready_server_cfg", "", "Config to execute when the map is changed (to exec after server.cfg).", FCVAR_SPONLY | FCVAR_NOTIFY);
	cvarReadyLeagueNotice = CreateConVar("l4d_ready_league_notice", "", "League notice displayed on RUP panel", FCVAR_SPONLY | FCVAR_NOTIFY);
	cvarReadyLiveCountdown = CreateConVar("l4d_ready_live_countdown", "0", "Countdown timer to begin the round", FCVAR_SPONLY | FCVAR_NOTIFY);
	cvarReadySpectatorRUP = CreateConVar("l4d_ready_spectator_rup", "0", "Whether or not spectators have to ready up", FCVAR_SPONLY | FCVAR_NOTIFY);
	cvarReadyRestartRound = CreateConVar("l4d_ready_restart_round", "1", "Whether or not to restart the campaign after readying up (dev)", FCVAR_SPONLY | FCVAR_NOTIFY);
	cvarReadyCommonLimit = CreateConVar("l4d_ready_common_limit", "30", "z_common_limit value after rup", FCVAR_SPONLY | FCVAR_NOTIFY);
	cvarReadyMegaMobSize = CreateConVar("l4d_ready_mega_mob_size", "30", "z_mega_mob_size value after rup", FCVAR_SPONLY | FCVAR_NOTIFY);
	cvarReadyAllBotTeam = CreateConVar("l4d_ready_all_bot_team", "0", "sb_all_bot_team value after rup", FCVAR_SPONLY | FCVAR_NOTIFY);
	//new way of readying up?
	cvarReadyUpStyle = CreateConVar("l4d_ready_up_style", "0", "0 = old style, 1 = infected can move during rup, players can move after rup", FCVAR_SPONLY | FCVAR_NOTIFY);
	//added to be able to set the !spectate !inf penalty
	cvarSpectatePenalty = CreateConVar("l4d_ready_spectate_penalty", "8", "Time in seconds an infected player can't rejoin the infected team.", FCVAR_SPONLY | FCVAR_NOTIFY);
	HookConVarChange(cvarSpectatePenalty, ConVarChange_cvarSpectatePenalty);
	g_hDirectorNoDeathCheck = FindConVar("director_no_death_check");
	g_iCvarGameTimeBlock = g_hGameTimeBlock.IntValue;
	
	CheckSpectatePenalty();
	
	g_hGameTimeBlock.AddChangeHook(ConVarChanged_GameTimeBlock);
	HookConVarChange(cvarEnforceReady, ConVarChange_ReadyEnabled);
	HookConVarChange(cvarReadyCompetition, ConVarChange_ReadyCompetition);
	
	#if HEALTH_BONUS_FIX
	CreateConVar("l4d_eb_health_bonus", EBLOCK_VERSION, "Version of the Health Bonus Exploit Blocker", FCVAR_SPONLY | FCVAR_NOTIFY|FCVAR_REPLICATED);
	
	HookEvent("item_pickup", Event_ItemPickup);	
	HookEvent("pills_used", Event_PillsUsed);
	HookEvent("heal_success", Event_HealSuccess);
	HookEvent("player_death", eventplayer_death);
	
	#if EBLOCK_DEBUG
	RegConsoleCmd("sm_updatehealth", Command_UpdateHealth);
	
	//RegConsoleCmd("sm_givehealth", Command_GiveHealth);
	#endif
	#endif
	
	AddCommandListener(Version_Command, "l4d_ready_version");
	
	AddConVarToReport(cvarReadyHalves);
	AddConVarToReport(cvarReadyServerCfg);
	AddConVarToReport(cvarReadyUpStyle);
	AddConVarToReport(cvarReadyLeagueNotice);
	AddConVarToReport(cvarReadyLiveCountdown);
	AddConVarToReport(cvarReadySpectatorRUP);
	AddConVarToReport(cvarReadyRestartRound);
	AddConVarToReport(cvarReadyCommonLimit);
	AddConVarToReport(cvarReadyMegaMobSize);
	AddConVarToReport(cvarReadyAllBotTeam);
	AddConVarToReport(cvarSpectatePenalty);
	
	g_hCvarGameMode = FindConVar("mp_gamemode");
	GetConVarString(g_hCvarGameMode, CurrentGameMode, sizeof(CurrentGameMode));
	HookConVarChange(g_hCvarGameMode,		ConVarChanged_GameMode);
	
	RegConsoleCmd("sm_bonesaw", Secret_Cmd, "secret ready up");
	RegConsoleCmd("sm_trophy", Secret_Cmd, "secret ready up");
	RegConsoleCmd("sm_harrypotter", Secret_Cmd, "secret ready up");
	RegConsoleCmd("sm_twnumber1", Secret_Cmd, "secret ready up");
	RegConsoleCmd("sm_twno1", Secret_Cmd, "secret ready up");
	
	arrayclientswitchteam = CreateArray(ByteCountToCells(STEAMID_SIZE));
}

public Action:eventplayer_death(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(client<=0||client>MaxClients) return;
	if(GetClientTeam(client) != L4D_TEAM_SURVIVORS) return;
	
	if(readyMode)
	{
		CreateTimer(0.5,RespawnPlayer,client);
		return;
	}

	if(g_iCvarGameTimeBlock != 0 && g_bGameTeamSwitchBlock && IsClientInGame(client) && !IsFakeClient(client))
	{
		decl String:steamID[STEAMID_SIZE];
		GetClientAuthId(client, AuthId_Steam2, steamID, STEAMID_SIZE);
		new index = FindStringInArray(arrayclientswitchteam, steamID);
		if (index == -1) {
			PushArrayString(arrayclientswitchteam, steamID);
			PushArrayCell(arrayclientswitchteam, 4);
		}
		else
		{
			SetArrayCell(arrayclientswitchteam, index + ARRAY_TEAM, 4);
		}			
	}
}

public Action:RespawnPlayer(Handle:timer,any:client)
{
	if(!IsClientInGame(client) || GetClientTeam(client) != L4D_TEAM_SURVIVORS) return;
	
	ReturnPlayerToSaferoom(client);
}
//sm_switch
public Action:Switch_Client(client, args)
{
	if(args < 2)
    {
		ReplyToCommand(client, "[TS] Usage: sm_switch <player1> <player2> - %T","ReplyToCommand1",client);		
		return Plugin_Handled;
	}
	decl String:player1[64];
	decl String:player2[64];
	GetCmdArg(1, player1, sizeof(player1));
	GetCmdArg(2, player2, sizeof(player2));
	
	new target1 = FindTarget(client, player1, true /*nobots*/, false /*immunity*/);
	new target2 = FindTarget(client, player2, true /*nobots*/, false /*immunity*/);
	
	if((target1 == -1) || (target2 == -1)) return Plugin_Handled;
	
	new targetTeamA = GetClientTeam(target1);
	new targetTeamB = GetClientTeam(target2);
	
	if (targetTeamA == targetTeamB)
	{
		if(client != 0)
		CPrintToChat(client, "{default}[{olive}TS{default}] <%T>","ReadyPlugin_1",client);
		return Plugin_Handled;
	}
		
	if((target1 != -1) && (target2 != -1))
	{
		new String:player1Name[64];
		new String:player2Name[64];
		GetClientName(target1, player1Name, sizeof(player1Name));
		GetClientName(target2, player2Name, sizeof(player2Name));

		if (targetTeamA != 1) ChangeClientTeam(target1, 1);
		if (targetTeamB != 1) ChangeClientTeam(target2, 1);
		
		if (targetTeamA == 1) CPrintToChatAll("{default}[{olive}TS{default}] %t", "ReadyPlugin_2",player2Name);
		if (targetTeamB == 1) CPrintToChatAll("{default}[{olive}TS{default}] %T", "ReadyPlugin_2",player1Name);
		if (targetTeamA == 2) CreateTimer(0.1, SwitchTargetSurvivor, target2, TIMER_FLAG_NO_MAPCHANGE);
		if (targetTeamA == 3) CreateTimer(0.1, SwitchTargetInfected, target2, TIMER_FLAG_NO_MAPCHANGE);
		if (targetTeamB == 2) CreateTimer(0.1, SwitchTargetSurvivor, target1, TIMER_FLAG_NO_MAPCHANGE);
		if (targetTeamB == 3) CreateTimer(0.1, SwitchTargetInfected, target1, TIMER_FLAG_NO_MAPCHANGE);
		return Plugin_Handled;
	}
	return Plugin_Handled;
}

public Action:SwitchTargetSurvivor(Handle:timer, any:target)
{
	new String:playerName[64];
	GetClientName(target, playerName, sizeof(playerName));
	FakeClientCommand(target, "sm_survivor");
	CPrintToChatAll("{default}[{olive}TS{default}] %t", "ReadyPlugin_3",playerName);
	//make target go survivor
}

public Action:SwitchTargetInfected(Handle:timer, any:target)
{
	new String:playerName[64];
	GetClientName(target, playerName, sizeof(playerName));
	FakeClientCommand(target, "sm_infected");
	CPrintToChatAll("{default}[{olive}TS{default}] %t", "ReadyPlugin_4",playerName);	
	//make target go inf
}
//previously in comp_loader sm_inf and sm_sur
stock GetTeamHumanCount(team)
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

public Action:Join_Survivor(client, args)	//on !survivor
{	
	if (client == 0) return Plugin_Handled;

	if (GetClientTeam(client) == 2)			//if client is survivor
	{
		CPrintToChat(client, "{default}[{olive}TS{default}] %T","ReadyPlugin_5",client);
		return Plugin_Handled;
	}

	// new maxSurvivorSlots = GetTeamMaxHumans(2);
	// new survivorUsedSlots = GetTeamHumanCount(2);
	// new freeSurvivorSlots = (maxSurvivorSlots - survivorUsedSlots);
	// if (freeSurvivorSlots <= 0)
	// {
	// 	CPrintToChat(client, "{default}[{olive}TS{default}] %T","ReadyPlugin_6",client);
	// 	return Plugin_Handled;
	// }
	//else
	//{
	int bot = FindBotToTakeOver(true);
	if (bot==0)
	{
		bot = FindBotToTakeOver(false);
	}
	if (bot==0)
	{
		CPrintToChat(client, "{default}[{olive}TS{default}] %T","ReadyPlugin_6",client);
		return Plugin_Handled;
	}
	

	L4D_SetHumanSpec(bot, client);
	L4D_TakeOverBot(client);
	//}
	return Plugin_Handled;
}


public Action:Join_Infected(client, args)	//on !infected
{	
	if (client == 0) return Plugin_Handled;
	
	if(StrEqual(CurrentGameMode,"coop", true))
		return Plugin_Handled;
		
	new maxInfectedSlots = GetTeamMaxHumans(3);
	new infectedUsedSlots = GetTeamHumanCount(3);
	new freeInfectedSlots = (maxInfectedSlots - infectedUsedSlots);
	if (GetClientTeam(client) == 3)			//if client is infected
	{
		CPrintToChat(client, "{default}[{olive}TS{default}] %T","ReadyPlugin_7",client);
		return Plugin_Handled;
	}
	if (freeInfectedSlots <= 0)
	{
		CPrintToChat(client, "{default}[{olive}TS{default}] %T","ReadyPlugin_8",client);
		return Plugin_Handled;
	}
	else
	{
		ChangeClientTeam(client, 3);	//ServerCommand("sm_swapto %N 3",client);	//swapping the client to the infected team if he is spectator or survivor
	}
	return Plugin_Handled;
}

/**
 * On report status client command.
 *
 * @param client		Client id that performed the command.
 * @param command		The command performed.
 * @param args			Number of arguments.
 * @return				Plugin_Handled to stop command from being performed, 
 *						Plugin_Continue to allow the command to pass.
 */
public Action:Version_Command(client, const String:command[], argc)
{
	if (client == 0) return Plugin_Continue; // Server already have a cvar named this, return continue

	if (g_bIsResultCached) // If we have a cached result
	{
		PrintToConsole(client, g_sResultCache); // Print cached result
		return Plugin_Handled; // Handled
	}

	decl String:result[REPORT_STATUS_MAX_MSG_LENGTH];

	Format(result, sizeof(result), "version: %s\n", READY_VERSION);
	//Format(result, sizeof(result), "%supdated: %s%s\n", result, (IsPluginUpdated() ? "yes" : "no"));
	Format(result, sizeof(result), "%senabled: %s\n", result, (cvarEnforceReady.BoolValue ? "yes" : "no"));
	Format(result, sizeof(result), "%slisting %i cvars:", result, (GetArraySize(g_aConVarArray) / CVAR_ARRAY_BLOCK));

	decl String:name[MAX_CONVAR_NAME_LENGTH];
	decl String:value[MAX_CONVAR_NAME_LENGTH];
	decl String:defaultValue[MAX_CONVAR_NAME_LENGTH];
	decl Handle:cvar;

	for (new i = FIRST_CVAR_IN_ARRAY; i < GetArraySize(g_aConVarArray); i += CVAR_ARRAY_BLOCK)
	{
		GetArrayString(g_aConVarArray, i, name, MAX_CONVAR_NAME_LENGTH);
		cvar = FindConVar(name);
		if (cvar == INVALID_HANDLE) continue;
		GetConVarString(cvar, value, MAX_CONVAR_NAME_LENGTH);

		GetArrayString(g_aConVarArray, i + 1, defaultValue, MAX_CONVAR_NAME_LENGTH);
		Format(defaultValue, MAX_CONVAR_NAME_LENGTH, "( def. \"%s\" )", defaultValue);

		Format(result, sizeof(result), "%s\n \"%s\" = \"%s\" %s", result, name, value, defaultValue);
	}

	PrintToConsole(client, result);

	// Cache result to prevent clients spamming this command to lag the server
	g_sResultCache = result;
	g_bIsResultCached = true;
	CreateTimer(CACHE_RESULT_TIME, _RS_Cache_Timer);

	return Plugin_Handled;
}

/**
 * Called when the cached timer interval has elapsed.
 * 
 * @param timer			Handle to the timer object.
 * @noreturn
 */
public Action:_RS_Cache_Timer(Handle:timer)
{
	g_bIsResultCached = false;
}

/**
 * Adds convar to the report status array.
 * 
 * @param convar		Handle to convar.
 * @noreturn
 */
stock AddConVarToReport(Handle:convar)
{
	SetupConVarArray(); // Setup array if needed

	/*
	 * Get name of convar
	 */
	decl String:name[MAX_CONVAR_NAME_LENGTH];
	GetConVarName(convar, name, MAX_CONVAR_NAME_LENGTH);

	if (FindStringInArray(g_aConVarArray, name) != -1) return; // Already in array

	/*
	 * Get default value of convar
	 */
	decl String:value[MAX_CONVAR_NAME_LENGTH], String:defaultvalue[MAX_CONVAR_NAME_LENGTH];
	GetConVarString(convar, value, MAX_CONVAR_NAME_LENGTH);

	new flags = GetConVarFlags(convar);
	if (flags & FCVAR_NOTIFY)
	{
		SetConVarFlags(convar, flags ^ FCVAR_NOTIFY);
	}

	ResetConVar(convar);
	GetConVarString(convar, defaultvalue, MAX_CONVAR_NAME_LENGTH);
	SetConVarString(convar, value);
	SetConVarFlags(convar, flags);

	/*
	 * Push to array
	 */
	PushArrayString(g_aConVarArray, name);
	PushArrayString(g_aConVarArray, defaultvalue);
}

/**
 * Adds convar to the report status array.
 * 
 * @param convar		Handle to convar.
 * @noreturn
 */
static SetupConVarArray()
{
	if (g_bIsArraySetup) return;
	g_aConVarArray = CreateArray(MAX_CONVAR_NAME_LENGTH);

	g_bIsArraySetup = true;
}

/**
 * On net info client command.
 *
 * @param client		Index of the client, or 0 from the server.
 * @param args			Number of arguments that were in the argument string.
 * @return				Plugin_Handled.
 */
public Action:ratesCommand(client, args)
{
	/* Prevent spammage of this command */
	if (g_bCooldown[client]) return Plugin_Handled;
	g_bCooldown[client] = true;

	new const maxLen = 1024;
	decl String:result[maxLen];

	Format(result, maxLen, "\nPrinting net information about players:\n\n");

	Format(result, maxLen, "%s | UID    | NAME                 | STEAMID              | PING  | RATE  | CR  | UR  |  INTERP  | IRATIO |\n", result);
	Format(result, maxLen, "%s |--------|----------------------|----------------------|-------|-------|-----|-----|----------|--------|", result);

	if (client == 0)
	{
		PrintToServer(result);
	}
	else
	{
		PrintToConsole(client, result);
	}

	decl uid, String:name[20], String:auth[20], Float:ping;
	decl String:rawRate[20], String:rawCR[20], String:rawUR[20], String:rawInterp[20], String:rawIRatio[20];
	decl rate, cmdrate, updaterate, /*Float:interp,*/ Float:interpRatio;
	for(new i=1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{
			uid = GetClientUserId(i);
			GetClientName(i, name, 20);
			GetClientAuthId(i, AuthId_Steam2, auth, 20);
			ping = (1000.0 * GetClientAvgLatency(i, NetFlow_Outgoing)) / 2;

			rate = -1;
			if (GetClientInfo(i, "rate", rawRate, 20))
			{
				rate = StringToInt(rawRate);
			}

			cmdrate = -1;
			if (GetClientInfo(i, "cl_cmdrate",rawCR, 20))
			{
				cmdrate = StringToInt(rawCR);
			}

			updaterate = -1;
			if (GetClientInfo(i, "cl_updaterate", rawUR, 20))
			{
				updaterate = StringToInt(rawUR);
			}

			//interp = -1.0;
			if (GetClientInfo(i, "cl_interp", rawInterp, 20))
			{
				Format(rawInterp, 9, rawInterp);
				//interp = StringToFloat(rawInterp);
			}

			interpRatio = -1.0;
			if (GetClientInfo(i, "cl_interp_ratio", rawIRatio, 20))
			{
				interpRatio = StringToFloat(rawIRatio);
			}

			Format(result, maxLen, " | #%-5i | %20s | %20s | %5.0f | %5i | %3i | %3i | %8s | %.4f |",
				uid,
				name,
				auth,
				ping,
				rate,
				cmdrate,
				updaterate,
				rawInterp,
				interpRatio);

			if (client == 0)
			{
				PrintToServer(result);
			}
			else
			{
				PrintToConsole(client, result);
			}
		}
	}

	Format(result, maxLen, "\nLegend:\n");
	Format(result, maxLen, "%s UID     - UserID\n", result);
	Format(result, maxLen, "%s NAME    - Current name of player\n", result);
	Format(result, maxLen, "%s STEAMID - SteamID of player\n", result);
	Format(result, maxLen, "%s PING    - Average ping\n", result);
	Format(result, maxLen, "%s RATE    - Rate\n", result);
	Format(result, maxLen, "%s CR      - Command rate\n", result);
	Format(result, maxLen, "%s UR      - Upload rate\n", result);
	Format(result, maxLen, "%s INTERP  - Interp value\n", result);
	Format(result, maxLen, "%s IRATIO  - Interp ratio value\n", result);

	if (client == 0)
	{
		PrintToServer(result);
	}
	else
	{
		PrintToConsole(client, result);
	}

	CreateTimer(1.0, ratesCooldownTimer, client);
	return Plugin_Handled;
}

public Action:ratesCooldownTimer(Handle:timer, any:client)	//ZACK
{
	g_bCooldown[client] = false;
	return Plugin_Stop;
}

ConVar sv_maxplayers;
public OnAllPluginsLoaded()
{	
	if(FindConVar("l4d_team_manager_ver") != INVALID_HANDLE)
	{
		// l4d scores manager plugin is loaded
		
		// allow reready because it will fix scores when rounds are restarted?
	}
	else
	{
		// l4d scores plugin is NOT loaded
		// supply these commands which would otherwise be done by the team manager
		
		RegAdminCmd("sm_swapplayer", Command_PlayerSwapPlayer, ADMFLAG_BAN, "sm_swap <player1> <player2> - swap player1's and player2's teams");
		RegAdminCmd("sm_swapteams", Command_SwapTeams, ADMFLAG_BAN, "sm_swapteams - swap all the players to the opposite teams");
	}

	sv_maxplayers = FindConVar("sv_maxplayers");
	if(sv_maxplayers == null)
		SetFailState("Could not find ConVar \"sv_maxplayers\".");
}

new bool:insidePluginEnd = false;
public OnPluginEnd()
{
	ResetVariable();
	ResetTimer();
	insidePluginEnd = true;
	
	readyOff();	
}

public OnMapEnd()
{
	isSecondRound = false;	
	g_bGameTeamSwitchBlock = false;
	ResetVariable();
	ResetTimer();
}

bool g_bNoSafeStartAreaMap;
public OnMapStart()
{	
	hasdirectorStart = false;
	g_bNoSafeStartAreaMap = false;

	char sCurMap[64];
	GetCurrentMap(sCurMap, 64);

	MI_KV_Close();
	MI_KV_Load();
	if (!KvJumpToKey(g_hMIData, sCurMap)) {
		//LogError("[MI] MapInfo for %s is missing.", g_sCurMap);
	} else
	{
		if (g_hMIData.GetNum("no_start_area", 0) == 1)
		{
			g_bNoSafeStartAreaMap = true;
		}
	}
	MI_KV_Close();

	PrefetchSound(SECRET_EGG_SOUND);
	PrecacheSound(SECRET_EGG_SOUND,true);
	
	GetConVarString(g_hCvarGameMode, CurrentGameMode, sizeof(CurrentGameMode));
	MapCountdownTimer = INVALID_HANDLE;
	isMapRestartPending = false;
	//LogMessage("this is OnMapStart and InSecondHalfOfRound is false");
	//每一關地圖載入後都會進入OnMapStart()
	InSecondHalfOfRound = false;
		
	DebugPrintToAll("Event map started.");
	//----
	//allowing reready to be used again incase the map changed before timer could reset bool back to false
	//----
	//resetting all spectator status
	decl i;
	for(i = 1; i <= MaxClients; i++)
	{	
		infectedSpectator[i] = false;						//not infected that used !spectate
		g_iSpectatePenaltyCounter[i] = g_iSpectatePenalty;	//counter gets reset to default
		g_iLastRespecced[i] = 0;							//last respecced time was never
		//menuInterrupted[i] = false;
	}

	decl String:cfgFile[128];
	GetConVarString(cvarReadyServerCfg, cfgFile, sizeof(cfgFile));
	
	if(strlen(cfgFile) == 0)
	{
		return;
	}
	
	decl String:cfgPath[1024];
	BuildPath(Path_SM, cfgPath, 1024, "../../cfg/%s", cfgFile);
	
	if(FileExists(cfgPath))
	{
		DebugPrintToAll("Executing server config %s", cfgPath);
		
		ServerCommand("exec %s", cfgFile);
	}
	else
	{
		LogError("[TS] Could not execute server config %s, file not found", cfgPath);
		PrintToServer("[TS] Could not execute server config %s, file not found", cfgFile);
	}
	PrecacheSound("buttons/blip1.wav");
	PrecacheSound("buttons/blip2.wav");
	readyCountdownTimer = INVALID_HANDLE;
	MapCountdownTimer = INVALID_HANDLE;
	
	decl String:sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath),"configs/hostname/server_hostname.txt");//檔案路徑設定
	
	new Handle:file = OpenFile(sPath, "r");//讀取檔案
	if(file == INVALID_HANDLE)
	{
		LogMessage("file configs/hostname/server_hostname.txt doesn't exist!");
		return;
	}
	
	if(!IsEndOfFile(file) && ReadFileLine(file, HostName, sizeof(HostName)))//讀一行
	{
		//LogMessage("Host Name without current mode: %s",HostName);
	}
}

public bool:OnClientConnect()
{
	if(readyMode) 
	{
		checkStatus();
	}
	
	return true;
}

public OnClientDisconnect(client)
{
	hiddenPanel[client] = false;
	g_fButtonTime[client] = 0.0;
	for (new i = 0; i <= 1; i++)
	{
		g_fPlayerMouse[client][i] = 0;
	}
	
	if(readyMode) checkStatus();
	if(IsClientConnected(client)&&!IsClientInGame(client)) return; //連線中尚未進來的玩家離線
	if(client&&!IsFakeClient(client)&&!checkrealplayerinSV(client)) //檢查是否還有玩家以外的人還在伺服器或是連線中
		CreateTimer(25.0,COLD_DOWN,client);
}
public Action:COLD_DOWN(Handle:timer,any:client)
{
	if(checkrealplayerinSV(0)) return;
	
	
	ServerCommand("exec rotoblin_pub.cfg");
}

bool:checkrealplayerinSV(client)
{
	for (new i = 1; i < MaxClients+1; i++)
		if(IsClientConnected(i)&&!IsFakeClient(i)&&i!=client)
			return true;
	return false;
}

public void OnClientPutInServer(int client)
{
	if(IsFakeClient(client)) return;

	readyStatus[client] = 0;

	g_iSpectatePenaltyCounter[client] = g_iSpectatePenalty;
	CreateTimer(PreventSpecBlockInfectedTeamIcon_DELAY, Timer_PreventSpecBlockInfectedTeamIcon, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);

	if(cvarEnforceReady.BoolValue == true && hasdirectorStart == false)
		SDKHook(client, SDKHook_PreThinkPost, OnPreThinkPost);
}

public void OnPreThinkPost(int client)
{
	if (cvarEnforceReady.BoolValue == false||
		hasdirectorStart||
		!IsClientInGame(client) ||
		GetClientTeam(client) != L4D_TEAM_INFECTED ||
		!IsPlayerGhost(client))
	{
		return;
	}
		
	if (GetGhostSpawnState(client) == 0)//can spawn state
	{
		SetEntProp(client, Prop_Send, "m_ghostSpawnState", 2);// unable to spawn: waiting for ready mode start
	}
}

static HookOrUnhookPreThinkPost(bool:bHook)
{
	for (new client = 1; client <= MaxClients; client++){

		if (!IsClientInGame(client) || IsFakeClient(client)) continue;

		if (bHook)
			SDKHook(client, SDKHook_PreThinkPost, OnPreThinkPost);
		else
			SDKUnhook(client, SDKHook_PreThinkPost, OnPreThinkPost);
	}
}

checkStatus()
{
	new humans, ready;
	decl i;
	
	//count number of non-bot players in-game
	for(i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) != L4D_TEAM_SPECTATE)
		{
			humans++;
			if(readyStatus[i]) ready++;
		}
	}
	if(humans == 0 || humans < GetTeamMaxHumans(2)+GetTeamMaxHumans(3))
		return;
	
	if(goingLive && (humans == ready)) return;
	else if(goingLive && (humans != ready))
	{
		goingLive = 0;
		PrintHintTextToAll("%t","ReadyPlugin_9");
		KillTimer(liveTimer);
	}
	else if(!goingLive && (humans == ready))
	{
		if(!insideCampaignRestart)
		{
			goingLive = GetConVarInt(cvarReadyLiveCountdown);
			liveTimer = CreateTimer(1.0, timerLiveCountCallback, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	else if(!goingLive && (humans != ready)) PrintHintTextToAll("%t","ReadyPlugin_10", ready, humans);
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon, &subtype, &cmdnum, &tickcount, &seed, mouse[2]) //should prevent players from moving
{

	if (readyMode)
	{
		if (buttons || impulse)
		{
			SetEngineTime(client);
		}
		
		// Mouse Movement Check
		new bool:hasRecordedMouse = false;
		for (new j = 0; j <= 1; j++)
		{
			if (g_fPlayerMouse[client][j] != 0)
			{
				hasRecordedMouse = true;
				break;
			}
		}
		if (hasRecordedMouse)
		{
			for (new i = 0; i <= 1; i++)
			{
				if (mouse[i] != g_fPlayerMouse[client][i])
				{
					SetEngineTime(client);
					break;
				}
			}
		}
		for (new c = 0; c <= 1; c++)
		{
			g_fPlayerMouse[client][c] = mouse[c];
		}
		
		if(inLiveCountdown)
		{
			if (IsClientInGame(client) && GetClientTeam(client) == L4D_TEAM_SURVIVORS && !(GetEntityMoveType(client) == MOVETYPE_NONE || GetEntityMoveType(client) == MOVETYPE_NOCLIP))
			{
				ToggleFreezePlayer(client, true);
				return Plugin_Continue;
			}
		}	
	}

	return Plugin_Continue;	

}

//repeatedly count down until the match goes live
public Action:timerLiveCountCallback(Handle:timer)
{
	//will go live soon
	if(goingLive)
	{
		if(forcedStart) CPrintToChatAll("{default}[{olive}TS{default}] %t","ReadyPlugin_11", goingLive);
		else CPrintToChatAll("{default}[{olive}TS{default}] %T","ReadyPlugin_12", goingLive);
		goingLive--;
	}
	//actually go live and unfreeze everyone
	else
	{
		//readyOff();
		
		if(GetConVarBool(cvarReadyRestartRound) && !GetConVarBool(cvarReadyUpStyle))
		{
			PrintHintTextToAll("%t","ReadyPlugin_13");
			
			insideCampaignRestart = 2;
			RestartCampaignAny();
		}
		else
		{
			InitiateLiveCountdown();
		}
		
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}

public Action:Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	ResetTimer();
	ResetVariable();

	//LogMessage("this is PD_ev_RoundEnd , InSecondHalfOfRound is true");
	if(!InSecondHalfOfRound)//第一回合結束
		InSecondHalfOfRound = true;
		
	#if READY_DEBUG
	DebugPrintToAll("[DEBUG] Event round has ended");
	#endif
	
	if(!isCampaignBeingRestarted)
	{
		#if READY_DEBUG
		if(!isSecondRound)
			DebugPrintToAll("[DEBUG] Second round detected.");
		else
		DebugPrintToAll("[DEBUG] End of second round detected.");
		#endif
		isSecondRound = true;
	}
	
	//we just ended the last restart, match will be live soon
	if(insideCampaignRestart == 1) 
	{
		//enable the director etc, but dont unfreeze all players just yet
		RoundEndBeforeLive();
	}
	
	isCampaignBeingRestarted = false;
}

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	directorStop();

	ClearArray(arrayclientswitchteam);

	TimeCount = 0;
	
	for(new i = 1; i <= MaxClients; i++)
	{
		painPillHolders[i] = false;
	}
	
	for (new client = 1; client <= MAXPLAYERS; client++)
		blockSecretSpam[client] = false;
	
	change = 0;
	hasdirectorStart = false;
	hasleftsaferoom = false;
	g_bGameTeamSwitchBlock = false;
	inLiveCountdown = false;
	

	if( g_iPlayerSpawn == 1 && g_iRoundStart == 0 )
		CreateTimer(0.25, PluginStart);
	g_iRoundStart = 1;

	return Plugin_Continue;
}

public Action PluginStart(Handle timer)
{
	ResetVariable();

	if(PlayerLeftStartTimer == null) PlayerLeftStartTimer = CreateTimer(1.0, Timer_PlayerLeftStart, _, TIMER_REPEAT);

	//currently automating campaign restart before going live?
	if(insideCampaignRestart > 0) 
	{
		//first restart, do one more
		if(insideCampaignRestart == 1) 
		{
			CreateTimer(READY_RESTART_ROUND_DELAY, timerOneRoundRestart, _, _);
			
		}
		//last restart, match is now live!
		else if(insideCampaignRestart == 0)
		{
			InitiateLiveCountdown();
		}
		else
		{
			LogError("insideCampaignRestart somehow neither 0 nor 1 after decrementing");
		}
		
		return Plugin_Continue;
	}
	
	if(cvarEnforceReady.BoolValue && 
		(!isSecondRound || GetConVarInt(cvarReadyHalves) || pauseBetweenHalves || GetConVarInt(cvarReadyUpStyle))) 
	{
		compReady(0, 0);
		pauseBetweenHalves = 0;
		SetConVarInt(g_hDirectorNoDeathCheck, 1);
		HookOrUnhookPreThinkPost(true);
	}
	else
	{
		directorStart();
	}	

	return Plugin_Continue;
}

public Action:timerOneRoundRestart(Handle:timer)
{
	PrintHintTextToAll("%t","ReadyPlugin_14");
	
	RestartCampaignAny();
	
	return Plugin_Stop;
}

public Action:timerLiveMessageCallback(Handle:timer)
{
	ShowRotoInfo();
	OpenSpectatorsListenMode();
	R2comp_UnscrambleKeep();
	AnnounceSIClasses();
	
	return Plugin_Stop;
}


public Action:timerUnreadyCallback(Handle:timer)
{
	if(!readyMode)
	{
		unreadyTimerExists = false;
		return Plugin_Stop;
	}
	
	if(insideCampaignRestart)
	{
		return Plugin_Continue;
	}
	
	if(!inLiveCountdown&&!isMapRestartPending)
	{
		decl i;
		for(i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGameHuman(i)) 
			{
				//use panel for ready up stuff?
				if(!readyStatus[i])
				{
					PrintHintText(i, "%t","ReadyPlugin_15");
				}
				else
				{
					PrintHintText(i, "%t","ReadyPlugin_16");
				}
			}
			else if(IsClientInGameHumanSpec(i) && GetClientTeam(i) == L4D_TEAM_SPECTATE)
			{
				PrintHintText(i, "%t","ReadyPlugin_17");
			}
		}
	}
	if(change == 9) change = -1;
	++change;DrawReadyPanelList();
	return Plugin_Continue;
}

public Action:Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{ 
	if( g_iPlayerSpawn == 0 && g_iRoundStart == 1 )
		CreateTimer(0.25, PluginStart);
	g_iPlayerSpawn = 1;

	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!readyMode)
	{
		if(client > 0 && client <=MaxClients && IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == L4D_TEAM_SURVIVORS)
		{
			CreateTimer(2.0,checksurvivorspawn,client);		
		}
		
		return Plugin_Handled;
	}

	return Plugin_Handled;
}

public Action:checksurvivorspawn(Handle:timer,any:client)
{
	if(IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == L4D_TEAM_SURVIVORS && IsPlayerAlive(client))
	{
		decl String:steamID[STEAMID_SIZE];
		GetClientAuthId(client, AuthId_Steam2, steamID, STEAMID_SIZE);
		new index = FindStringInArray(arrayclientswitchteam, steamID);
		if (index == -1) {
			PushArrayString(arrayclientswitchteam, steamID);
			PushArrayCell(arrayclientswitchteam, L4D_TEAM_SURVIVORS);
		}
		else
		{
			SetArrayCell(arrayclientswitchteam, index + ARRAY_TEAM, L4D_TEAM_SURVIVORS);
		}			
	}
}

public Action:L4D_OnSpawnTank(const Float:vector[3], const Float:qangle[3])
{
	//PrintToChatAll("OnSpawnTank(vector[%f,%f,%f], qangle[%f,%f,%f]", vector[0], vector[1], vector[2], qangle[0], qangle[1], qangle[2]);
		
	if(cvarEnforceReady.BoolValue == true && hasdirectorStart == false)
	{
		//PrintToChatAll("Blocking tank spawn...");
		return Plugin_Handled;
	}
	else
	{
		return Plugin_Continue;
	}
}

public Action:L4D_OnSpawnWitch(const Float:vector[3], const Float:qangle[3])
{
	//PrintToChatAll("ready L4D_OnSpawnWitch, hasleftsaferoom: %d, hasdirectorStart: %d",hasleftsaferoom,hasdirectorStart);
	if(cvarEnforceReady.BoolValue == true && hasdirectorStart == false)
	{
		//PrintToChatAll("Blocking witch spawn...");
		return Plugin_Handled;
	}
	else
	{
		return Plugin_Continue;
	}
}


//When a player replaces a bot (i.e. player joins survivors team)
public Action:eventBotPlayerReplaceCallback(Handle:event, const String:name[], bool:dontBroadcast)
{
	//	new bot = GetClientOfUserId(GetEventInt(event, "bot"));
	//new player = GetClientOfUserId(GetEventInt(event, "player"));
	
	if(readyMode)
	{
		//called when player joins survivor....?
		#if READY_DEBUG
		new String:curname[128];
		GetClientName(player,curname,128);
		DebugPrintToAll("[DEBUG] Player %s [%d] replacing bot, freezing player.", curname, player);
		#endif
		
		//ToggleFreezePlayer(player, true);
	}
	else
	{
		#if READY_DEBUG
		new String:curname[128];
		GetClientName(player,curname,128);
		DebugPrintToAll("[DEBUG] Player %s [%d] replacing bot, doing nothing.", curname, player);
		#endif	
	}
	
	return Plugin_Handled;
}


//When a bot replaces a player (i.e. player switches to spectate or infected)
public Action:eventPlayerBotReplaceCallback(Handle:event, const String:name[], bool:dontBroadcast)
{
	
	//new player = GetClientOfUserId(GetEventInt(event, "player"));
	//	new bot = GetClientOfUserId(GetEventInt(event, "bot"));
	
	if(readyMode)
	{
		#if READY_DEBUG
		new String:curname[128];
		GetClientName(player,curname,128);
		
		DebugPrintToAll("[DEBUG] Bot replacing player %s [%d], unfreezing player.", curname, player);
		#endif
		
		//ToggleFreezePlayer(player, false);
	}
	else
	{
		#if READY_DEBUG
		new String:curname[128];
		GetClientName(player,curname,128);
		DebugPrintToAll("[DEBUG] Bot replacing player %s [%d], doing nothing.", curname, player);
		#endif	
	}
	
	return Plugin_Handled;
}

//When a player changes team
public Action:eventPlayerTeamCallback(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	#if READY_DEBUG
	new String:curname[128];
	GetClientName(client,curname,128);
	DebugPrintToAll("[DEBUG] client %s changing team.", curname);
	#endif
	
	SetEngineTime(client);
	readyStatus[client] = 0;
	if(readyMode)
	{
		DrawReadyPanelList();
		checkStatus();
	}
	
	CreateTimer(1.0,PlayerChangeTeamCheck,client);//延遲一秒檢查
}

public Action:PlayerChangeTeamCheck(Handle:timer,any:client)
{
	if(client && IsClientInGame(client) && !IsFakeClient(client))
	{
		new newteam = GetClientTeam(client);
		if(newteam != L4D_TEAM_SPECTATE)
		{
			decl String:steamID[STEAMID_SIZE];
			GetClientAuthId(client, AuthId_Steam2, steamID, STEAMID_SIZE);
			new index = FindStringInArray(arrayclientswitchteam, steamID);
			if (index == -1) {
				PushArrayString(arrayclientswitchteam, steamID);
				PushArrayCell(arrayclientswitchteam, newteam);
			}
			else
			{
				if(!hasleftsaferoom || g_iCvarGameTimeBlock == 0 || !g_bGameTeamSwitchBlock)
					SetArrayCell(arrayclientswitchteam, index + ARRAY_TEAM, newteam);
				else
				{
					new oldteam = GetArrayCell(arrayclientswitchteam, index + ARRAY_TEAM);
					if(newteam != oldteam)
					{
						if(oldteam == 4 && !(newteam == L4D_TEAM_SURVIVORS && !IsPlayerAlive(client)) ) //player survivor death
						{
							ChangeClientTeam(client,L4D_TEAM_SPECTATE);
							CPrintToChat(client,"{default}[{olive}TS{default}] %T","ReadyPlugin_18",client);
						}
						else if(oldteam != 4)
						{
							decl String:Info[50];
							if(oldteam == L4D_TEAM_SURVIVORS)
								Format(Info, 50, "%T", "Survivor",client);
							else
								Format(Info, 50, "%T", "Infected",client);
							ChangeClientTeam(client,L4D_TEAM_SPECTATE);
							CPrintToChat(client,"[TS] %T","ReadyPlugin_19",client,Info);
						}
					}
				}
			}		
		}
	}
}

//When a player gets hurt during ready mode, block all damage
public Action:eventPlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	new player = GetClientOfUserId(GetEventInt(event, "userid"));
	new health = GetEventInt(event, "health");
	new dmg_health = GetEventInt(event, "dmg_health");
	
	#if READY_DEBUG
	new String:curname[128];
	GetClientName(player,curname,128);
	
	DebugPrintToAll("[DEBUG] Player hurt %s [%d], health = %d, dmg_health = %d.", curname, player, health, dmg_health);
	#endif
	
	SetEntityHealth(player, health + dmg_health);
}

public Action:eventVotePassed(Handle:event, const String:name[], bool:dontBroadcast)
{
	new String:details[128];
	new String:param1[128];
	new team;
	
	GetEventString(event, "details", details, 128);
	GetEventString(event, "param1", param1, 128);
	team = GetEventInt(event, "team");
	
	//[DEBUG] Vote passed, details=#L4D_vote_passed_restart_game, param1=, team=[-1].
	
	DebugPrintToAll("[DEBUG] Vote passed, details=%s, param1=%s, team=[%d].", details, param1, team);
	
	return Plugin_Handled;
}

public Action:eventVoteStarted(Handle:event, const String:name[], bool:dontBroadcast)
{
	new String:issue[128];
	new String:param1[128];
	new team;
	new initiator;
	
	GetEventString(event, "issue", issue, 128);
	GetEventString(event, "param1", param1, 128);
	team = GetEventInt(event, "team");
	initiator = GetEventInt(event, "initiator");
	
	//[DEBUG] Vote started, issue=#L4D_vote_restart_game, param1=, team=[-1], initiator=[1].
	
	DebugPrintToAll("[DEBUG] Vote started, issue=%s, param1=%s, team=[%d], initiator=[%d].", issue, param1, team, initiator);
}

public Action:eventVoteEnded(Handle:event, const String:name[], bool:dontBroadcast)
{
	DebugPrintToAll("[DEBUG] Vote ended");
}

public ConVarChanged_GameTimeBlock(Handle:convar, const String:oldValue[], const String:newValue[])
{
	g_iCvarGameTimeBlock = g_hGameTimeBlock.IntValue;
}

public ConVarChange_DirectorNoBosses(Handle:convar, const String:oldValue[], const String:newValue[])
{
	DebugPrintToAll("director_no_bosses changed from %s to %s", oldValue, newValue);
	
}

public Action:SendVoteRestartPassed(client, args)
{
	new Handle:event = CreateEvent("vote_passed");	
	if(event == INVALID_HANDLE) 
	{
		return;
	}
	
	SetEventString(event, "details", "#L4D_vote_passed_restart_game");
	SetEventString(event, "param1", "");
	SetEventInt(event, "team", -1);
	
	FireEvent(event);
	
	DebugPrintToAll("[DEBUG] Sent fake vote passed to restart game");
}

public Action:SendVoteRestartStarted(client, args)
{
	new Handle:event = CreateEvent("vote_started");	
	if(event == INVALID_HANDLE) 
	{
		return;
	}
	
	SetEventString(event, "issue", "#L4D_vote_restart_game");
	SetEventString(event, "param1", "");
	SetEventInt(event, "team", -1);
	SetEventInt(event, "initiator", client);
	
	FireEvent(event);
	
	DebugPrintToAll("[DEBUG] Sent fake vote started to restart game");
}

public Action:FakeRestartVoteCampaign(client, args)
{
	//re-enable ready mode after the restart
	pauseBetweenHalves = 1;
	
	RestartCampaignAny();
	CPrintToChatAll("{default}[{olive}TS{default}] %t","ReadyPlugin_20");
	DebugPrintToAll("[TS] %t","ReadyPlugin_20");
}

RestartCampaignAny()
{	
	decl String:currentmap[128];
	GetCurrentMap(currentmap, sizeof(currentmap));
	
	DebugPrintToAll("RestartCampaignAny() - Restarting scenario from vote ...");
	
	L4D_RestartScenarioFromVote(currentmap);
}

public Action:CommandRestartMap(client, args)
{	
	if(!isMapRestartPending)
	{
		CPrintToChatAll("{default}[{olive}TS{default}] %t","ReadyPlugin_21", READY_RESTART_MAP_DELAY+1);
		RestartMapDelayed();
	}
	return Plugin_Handled;
}

RestartMapDelayed()
{
	if (MapCountdownTimer == INVALID_HANDLE)
	{
		PrintHintTextToAll("%t","ReadyPlugin_22",READY_RESTART_MAP_DELAY+1);
		isMapRestartPending = true;
		MapRestartDelay = READY_RESTART_MAP_DELAY;
		MapCountdownTimer = CreateTimer(1.0, timerRestartMap, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		DebugPrintToAll("[TS] Map will restart in %d seconds.", READY_RESTART_MAP_DELAY);
	}
}

public Action:timerRestartMap(Handle:timer)
{
	if (MapRestartDelay == 0)
	{
		MapCountdownTimer = INVALID_HANDLE;
		//EmitSoundToAll("buttons/blip2.wav", _, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.5);
		RestartMapNow();
		return Plugin_Stop;
	}
	else
	{
		PrintHintTextToAll("%t","ReadyPlugin_22", MapRestartDelay);
		EmitSoundToAll("buttons/blip1.wav", _, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.5);
		MapRestartDelay--;
	}
	return Plugin_Continue;
}

RestartMapNow() 
{
	isMapRestartPending = false;
	
	decl String:currentMap[256];
	
	GetCurrentMap(currentMap, 256);
	
	ServerCommand("changelevel %s", currentMap);
	
}

public Action:callVote(client, args)
{
	//only allow voting when are not enforcing ready modes
	if(cvarEnforceReady.BoolValue == false) 
	{
		return Plugin_Continue;
	}
	
	if(!votesUnblocked) 
	{
		#if READY_DEBUG
		DebugPrintToAll("[DEBUG] Voting is blocked");
		#endif
		return Plugin_Handled;
	}
	
	new String:votetype[32];
	GetCmdArg(1,votetype,32);
	
	if(strcmp(votetype,"RestartGame",false) == 0)
	{
		#if READY_DEBUG
		DebugPrintToAll("[DEBUG] Vote on RestartGame called");
		#endif
		votesUnblocked = false;
	}
	
	return Plugin_Continue;
}

public Action:Command_Spectate(client, args)
{
	if(GetClientTeam(client) != L4D_TEAM_SPECTATE)
	{
		if(GetClientTeam(client) == L4D_TEAM_SURVIVORS)	//someone can't swap to survivor team to get reduced spawn timers
		{
			ChangePlayerTeam(client, L4D_TEAM_SPECTATE);
		}
		if(GetClientTeam(client) == L4D_TEAM_INFECTED)
		{
			if(readyMode || infectedSpectator[client])								//if game is in ready up, allow normal spectate, or player is already an inf/spectator
			{
				ChangePlayerTeam(client, L4D_TEAM_SPECTATE);
			}
			else
			{
				if(g_iSpectatePenalty > -1)
				{
					infectedSpectator[client] = true;
					ChangePlayerTeam(client, L4D_TEAM_SPECTATE);
					CreateTimer(1.0, Timer_InfectedSpectate, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE); // Start unpause countdown
				}
				else
				{
					ChangePlayerTeam(client, L4D_TEAM_SPECTATE);
				}
			}
		}		
	}
	//respectate trick to get around spectator camera being stuck
	else
	{
		g_bIsSpectating[client] = true;
		ChangePlayerTeam(client, L4D_TEAM_INFECTED);
		CreateTimer(0.1, Timer_Respectate, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	}
	
	if(readyMode)
	{
		DrawReadyPanelList();
		checkStatus();
	}

	return Plugin_Handled;
}

public Action:Respec_Client(client, args)
{
	if (client == 0)
	{
		PrintToServer("[TS] %T","command cannot be used by server.",client);
		return Plugin_Handled;
	}
	
	if (GetClientTeam(client) != 3 || g_bIsSpectating[client])
	{
		ReplyToCommand(client, "[TS] %T","ReplyToCommand2",client);
		return Plugin_Handled;
	}
	
	if(args < 1)
    {
		ReplyToCommand(client, "[TS] Usage: sm_respec <player> - %T","ReplyToCommand3",client);		
		return Plugin_Handled;
	}
	
	decl String:target[64];
	GetCmdArgString(target, sizeof(target));
	
	new tclient = FindTarget(client, target, true /*nobots*/, false /*immunity*/);
	if (tclient == -1) return Plugin_Handled;
	
	decl String:respecClient[64];
	GetClientName(client, respecClient, sizeof(respecClient));
	
	decl String:respecTarget[64];
	GetClientName(tclient, respecTarget, sizeof(respecTarget));
		
	if (GetClientTeam(tclient) != L4D_TEAM_SPECTATE)
	{
		ReplyToCommand(client, "[TS] %T","ReplyToCommand4",client, respecTarget);
		return Plugin_Handled;
	}
	else if (g_bIsSpectating[tclient])
    {
		ReplyToCommand(client, "[TS] %T","ReplyToCommand5",client, respecTarget);
		return Plugin_Handled;
    }
	
	new curtime = GetTime();
	
	new tdiff = (g_iLastRespecced[tclient] + g_iRespecCooldownTime) - curtime;
	
	if (tdiff > 0)
	{
		ReplyToCommand(client, "[TS] %T","ReplyToCommand6",client, respecTarget, tdiff);
		return Plugin_Handled;
	}
	
	g_iLastRespecced[tclient] = curtime;
	
	g_bIsSpectating[tclient] = true;
	
	ChangePlayerTeam(tclient, 3);
	CreateTimer(0.1, Timer_Respec_A, tclient, TIMER_FLAG_NO_MAPCHANGE); //spec
	CreateTimer(0.6, Timer_Respec_B, tclient, TIMER_FLAG_NO_MAPCHANGE); //inf
	CreateTimer(0.7, Timer_Respec_C, tclient, TIMER_FLAG_NO_MAPCHANGE); //spec + reset spectating[tclient] = false;
	CPrintToChat(tclient, "{default}[{olive}TS{default}] %T","ReadyPlugin_23", tclient,respecClient);
	CPrintToChat(client, "{default}[{olive}TS{default}] %T","ReadyPlugin_24",client, respecTarget);
	
	return Plugin_Handled;
}

public Action:Timer_Respec_A(Handle:timer, any:tclient)
{
	ChangeClientTeam(tclient, 1);
}

public Action:Timer_Respec_B(Handle:timer, any:tclient)
{
	ChangeClientTeam(tclient, 3);
}

public Action:Timer_Respec_C(Handle:timer, any:tclient)
{
	ChangeClientTeam(tclient, 1);
	g_bIsSpectating[tclient] = false;	
}

public Action:Timer_InfectedSpectate(Handle:timer, any:client)
{
	static bClientJoinedInfected = false;		//did the client try to join the infected?
	
	if (!infectedSpectator[client] || !IsClientInGame(client) || IsFakeClient(client)) return Plugin_Stop; //if client disconnected or is fake client
	
	if (g_iSpectatePenaltyCounter[client] != 0)
	{
		if (GetClientTeam(client) == L4D_TEAM_INFECTED)
		{
			ChangePlayerTeam(client, L4D_TEAM_SPECTATE);
			CPrintToChat(client, "{default}[{olive}TS{default}] %T","ReadyPlugin_25",client, g_iSpectatePenaltyCounter[client]);
			bClientJoinedInfected = true;	//client tried to join the infected again when not allowed
		}
		g_iSpectatePenaltyCounter[client]--;
		return Plugin_Continue;
	}
	else if (g_iSpectatePenaltyCounter[client] == 0)
	{
		if (GetClientTeam(client) == L4D_TEAM_INFECTED)
		{
			ChangePlayerTeam(client, L4D_TEAM_SPECTATE);
			bClientJoinedInfected = true;
		}
		if (GetClientTeam(client) == L4D_TEAM_SPECTATE && bClientJoinedInfected)
		{
			CPrintToChat(client, "{default}[{olive}TS{default}] %T","ReadyPlugin_26",client);	//only print this hint text to the spectator if he tried to join the infected team, and got swapped before
		}
		infectedSpectator[client] = false;
		bClientJoinedInfected = false;
		g_iSpectatePenaltyCounter[client] = g_iSpectatePenalty;
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

public Action:Timer_Respectate(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if(client && IsClientInGame(client) && !IsFakeClient(client))
	{
		ChangePlayerTeam(client, L4D_TEAM_SPECTATE);
		g_bIsSpectating[client] = false;
	}
}

public Action Timer_PreventSpecBlockInfectedTeamIcon(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if(client && IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == L4D_TEAM_SPECTATE)
	{
		ChangePlayerTeam(client, L4D_TEAM_INFECTED);
		CreateTimer(0.1, Timer_Respectate, userid, TIMER_FLAG_NO_MAPCHANGE);
	}

	return Plugin_Continue;
}

public Action:WTF(client, args) //player press m
{
	if (client == 0)
	{
		PrintToServer("[TS] %T","command cannot be used by server.",client);
		return Plugin_Handled;
	}
	
	if(g_iCvarGameTimeBlock != 0 && g_bGameTeamSwitchBlock && hasleftsaferoom && GetClientTeam(client) != L4D_TEAM_SPECTATE) 
	{
		CPrintToChat(client, "{default}[{olive}TS{default}] %T","ReadyPlugin_27",client);
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public Action:Command_Unfreezeme1(client, args)
{
	SetEntityMoveType(client, MOVETYPE_NOCLIP);	
	//PrintToChatAll("Unfroze %N with noclip");
	
	return Plugin_Handled;
}

public Action:Command_Unfreezeme2(client, args)
{
	SetEntityMoveType(client, MOVETYPE_OBSERVER);	
	//PrintToChatAll("Unfroze %N with observer");
	
	return Plugin_Handled;
}

public Action:Command_Unfreezeme3(client, args)
{
	SetEntityMoveType(client, MOVETYPE_WALK);	
	//PrintToChatAll("Unfroze %N with WALK");
	
	return Plugin_Handled;
}


public Action:Command_Unfreezeme4(client, args)
{
	SetEntityMoveType(client, MOVETYPE_CUSTOM);	
	//PrintToChatAll("Unfroze %N with customs");
	
	return Plugin_Handled;
}


public Action:printClients(client, args)
{
	
	decl i;
	for(i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i)) 
		{
			new String:curname[128];
			GetClientName(i,curname,128);
			DebugPrintToAll("[DEBUG] Player %s with client id [%d]", curname, i);
		}
	}	
}

public Action:Command_Say(client, args)
{
	SetEngineTime(client);
	
	if(args < 1)
	{
		return Plugin_Continue;
	}
		
	decl String:sayWord[MAX_NAME_LENGTH];
	GetCmdArg(1, sayWord, sizeof(sayWord));
	
	if(StrEqual(sayWord, "!rates", true))
	{
		CPrintToChat(client, "{default}[{olive}TS{default}] %T","ReadyPlugin_28",client);
		return Plugin_Handled;
	}
	if(StrEqual(sayWord, "/rates", true))
	{
		CPrintToChat(client, "{default}[{olive}TS{default}] %T","ReadyPlugin_28",client);
		return Plugin_Handled;
	}
	if(StrEqual(sayWord, "t", true))
	{
		new iTankPercent = GetTankPercent();
		new iWitchPercent = GetWitchPercent();
		
		if (iTankPercent)
			if (iWitchPercent > 0) 
				CPrintToChat(client, "{default}[{olive}TS{default}] {red}%T{default}: {green}%d%%{default}, {red}%T{default}: {green}%d%%","Tank",client, iTankPercent, "Witch",client, iWitchPercent);
			else if (iWitchPercent == -2)
				CPrintToChat(client, "{default}[{olive}TS{default}] {red}%T{default}: {green}%d%%{default}, {red}%T{default}: {green}Witch Party","Tank",client, iTankPercent,"Witch",client);
			else
				CPrintToChat(client, "{default}[{olive}TS{default}] {red}%T{default}: {green}%d%%{default}, {red}%T{default}: {green}None","Tank",client, iTankPercent,"Witch",client);
		else
			if (iWitchPercent>0) 
				CPrintToChat(client, "{default}[{olive}TS{default}] {red}%T{default}: {green}None{default}, {red}%T{default}: {green}%d%%","Tank",client,"Witch",client,iWitchPercent);
			else if (iWitchPercent == -2)
				CPrintToChat(client, "{default}[{olive}TS{default}] {red}%T{default}: {green}None{default}, {red}%T{default}: {green}Witch Party","Tank",client,"Witch",client);
			else
				CPrintToChat(client, "{default}[{olive}TS{default}] {red}%T{default}: {green}None{default}, {red}%T{default}: {green}None","Tank",client,"Witch",client);

		return Plugin_Continue;
	}
	
	if (!readyMode) return Plugin_Continue;
	
	if(StrEqual(sayWord, "!r", true))
	{
		readyUp(client, args);
		return Plugin_Handled;
	}
	else if(StrEqual(sayWord, "!R", true))
	{
		readyUp(client, args);
		return Plugin_Handled;
	}
	else if(StrEqual(sayWord, "/R", true))
	{
		readyUp(client, args);
		return Plugin_Handled;
	}
	else if(StrEqual(sayWord, "/r", true))
	{
		readyUp(client, args);
		return Plugin_Handled;
	}
	
	if(StrEqual(sayWord, "!nr", true))
	{
		readyDown(client, args);
		return Plugin_Handled;
	}
	else if(StrEqual(sayWord, "/nr", true))
	{
		readyDown(client, args);
		return Plugin_Handled;
	}
	else if(StrEqual(sayWord, "/NR", true))
	{
		readyDown(client, args);
		return Plugin_Handled;
	}
	else if(StrEqual(sayWord, "!NR", true))
	{
		readyDown(client, args);
		return Plugin_Handled;
	}
	
	new idx = StrContains(sayWord, "notready", false);	
	if(idx == 1)
	{
		readyDown(client, args);
		return Plugin_Handled;
	}
	
	idx = StrContains(sayWord, "unready", false);
	if(idx == 1)
	{
		readyDown(client, args);
		return Plugin_Handled;
	}
	
	idx = StrContains(sayWord, "ready", false);
	if(idx == 1)
	{
		readyUp(client, args);
		return Plugin_Handled;
	}
	idx = StrContains(sayWord, "Ready", false);
	if(idx == 1)
	{
		readyUp(client, args);
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public Action:readyUp(client, args)
{
	if(!readyMode || readyStatus[client] || GetClientTeam(client) == L4D_TEAM_SPECTATE || g_bIsSpectating[client]) return Plugin_Handled;
	
	SetEngineTime(client);
	readyStatus[client] = 1;
	checkStatus();
	
	DrawReadyPanelList();
	
	return Plugin_Handled;
}

public Action:readyDown(client, args)
{
	if(!readyMode || !readyStatus[client] || GetClientTeam(client) == L4D_TEAM_SPECTATE || g_bIsSpectating[client]) return Plugin_Handled;
	if(isCampaignBeingRestarted || insideCampaignRestart) return Plugin_Handled;
	
	SetEngineTime(client);
	readyStatus[client] = 0;
	checkStatus();
	
	DrawReadyPanelList();
	
	return Plugin_Handled;
}


public Action:readyWho(client, args)
{
	if(!readyMode) return Plugin_Handled;
	
	decl String:readyPlayers[1024];
	decl String:unreadyPlayers[1024];
	
	readyPlayers[0] = 0;
	unreadyPlayers[0] = 0;
	
	new numPlayers = 0;
	new numPlayers2 = 0;
	
	new i;
	for(i = 1; i <= MaxClients; i++) 
	{
		if(IsClientInGameHuman(i)) 
		{
			decl String:name[MAX_NAME_LENGTH];
			GetClientName(i, name, sizeof(name));
			
			if(readyStatus[i]) 
			{
				if(numPlayers > 0 )
					StrCat(readyPlayers, 1024, ", ");
				
				StrCat(readyPlayers, 1024, name);
				
				numPlayers++;
			}
			else
			{
				if(numPlayers2 > 0 )
					StrCat(unreadyPlayers, 1024, ", ");
				
				StrCat(unreadyPlayers, 1024, name);
				
				numPlayers2++;
			}
		}
	}
	
	if(numPlayers == 0) 
	{
		StrCat(readyPlayers, 1024, "NONE");
	}
	if(numPlayers2 == 0) 
	{
		StrCat(unreadyPlayers, 1024, "NONE");
	}
	
	DebugPrintToAll("[TS] Players ready: %s", readyPlayers);
	DebugPrintToAll("[TS] Players NOT ready: %s", unreadyPlayers);
	
	return Plugin_Handled;
}

RealplayerinSV()
{
	new realpeople = 0;
	for (new i = 1; i < MaxClients+1; i++)
		if (IsClientConnected(i) && IsClientInGame(i)&& !IsFakeClient(i))
			realpeople++;
	return realpeople;
}


//draws a menu panel of ready and unready players
DrawReadyPanelList()
{
	if(!readyMode) return;
	
	decl String:readyPlayers[1024];
	decl String:name[MAX_NAME_LENGTH];
	
	readyPlayers[0] = 0;
	
	new numPlayers = 0;
	new numPlayers2 = 0;
	new numPlayers3 = 0;
	
	new Handle:panel = CreatePanel();
	decl String:versionInfo[128];
	decl String:Notice[64];
	GetConVarString(cvarReadyLeagueNotice, Notice, sizeof(Notice));
	Format(versionInfo, 128, "● %t (%s)", "ROTO_AZ_PLUGIN_VERSION",Notice);
	DrawPanelText(panel, versionInfo);
	
#if LEAGUE_ADD_NOTICE
	switch(change)
	{
		case 0: 
		{
			Format(Notice, 64, "● Server: %s", HostName);
		}
		case 1:
		{
			Format(Notice, 64, "● Slots: %d/%d - %s round", RealplayerinSV(), sv_maxplayers.IntValue, (InSecondHalfOfRound)? "2nd": "1st");
		}
		case 2:
		{
			Format(Notice, 64, "● Cmd: !load - change match", HostName);
		}
		case 3:
		{
			Format(Notice, 64, "● Cmd: !votes - vote menu", HostName);
		}
		case 4:
		{
			Format(Notice, 64, "● Cmd: !info - information", HostName);
		}
		case 5:
		{
			Format(Notice, 64, "● Cmd: !slots # - change server slots", HostName);
		}
		case 6:
		{
			Format(Notice, 64, "● Cmd: !show / !hide - Display Panel", HostName);
		}
		case 7:
		{
			Format(Notice, 64, "● Cmd: !setscores <survs> <inf> - Set Team Score", HostName);
		}
		case 8:
		{
			Format(Notice, 64, "● Cmd: !voteboss <tank> <witch> - Change Boss Percents", HostName);
		}
		case 9:
		{
			Format(Notice, 64, "● Cmd: !lerps - Check Players' lerps", HostName);
		}
	}
	DrawPanelText(panel, Notice);
#endif
	
	decl String:spawn[80];
	//new SurCurrent = GetSurCurrent();
	new iTankPercent = GetTankPercent();
	new iWitchPercent = GetWitchPercent();
	if (iTankPercent)
		if (iWitchPercent > 0) 
			Format(spawn, 80, "►Tank: %d%%, Witch: %d%%", iTankPercent, iWitchPercent);
		else if (iWitchPercent == -2)	
			Format(spawn, 80, "►Tank: %d%%, Witch: Witch Party", iTankPercent);
		else
			Format(spawn, 80, "►Tank: %d%%, Witch: None", iTankPercent);
	else
		if (iWitchPercent > 0) 
			Format(spawn, 80, "►Tank: None, Witch: %d%%",iWitchPercent);
		else if (iWitchPercent == -2)	
			Format(spawn, 80, "►Tank: None, Witch: Witch Party");	
		else
			Format(spawn, 80, "►Tank: None, Witch: None");

	DrawPanelText(panel, spawn);
	
	DrawPanelText(panel, " ");
	
	new sur, inf ,specs;
	new i;
	for(i = 1; i <= MaxClients; i++) 
	{
		if(IsClientInGameHuman(i)&& GetClientTeam(i) == L4D_TEAM_SURVIVORS) 
			sur++;
		else if(IsClientInGameHuman(i)&& GetClientTeam(i) == L4D_TEAM_INFECTED)
			inf++;
		else if(IsClientInGameHumanSpec(i) && GetClientTeam(i) == L4D_TEAM_SPECTATE)
			specs++;
	}
	new Float:fTime = GetEngineTime();
	if(sur)
	{
		Format(spawn, 80, "Survivors. - %d",Score_GetTeamCampaignScore(L4D_TEAM_SURVIVORS));
		DrawPanelText(panel, spawn);
		for(i = 1; i <= MaxClients; i++) 
		{
			if(IsClientInGameHuman(i)) 
			{
				GetClientName(i, name, sizeof(name));
				if(GetClientTeam(i) == L4D_TEAM_SURVIVORS)
				{
					if(readyStatus[i]) 
					{
						numPlayers++;
						Format(readyPlayers, 1024, "->%d. ★%s",numPlayers,name);
						DrawPanelText(panel, readyPlayers);
					}
					else
					{
						numPlayers++;
						Format(readyPlayers, 1024, "->%d. ☆%s%s",numPlayers,name,(IsPlayerAfk(i, fTime)) ? " [AFK]" : "");
						DrawPanelText(panel, readyPlayers);
					}
				}
			}
		}
	}
	if(inf)
	{
		Format(spawn, 80, "Infected. - %d",Score_GetTeamCampaignScore(L4D_TEAM_INFECTED));
		DrawPanelText(panel, spawn);
		for(i = 1; i <= MaxClients; i++) 
		{
			if(IsClientInGameHuman(i)) 
			{
				GetClientName(i, name, sizeof(name));
				if(GetClientTeam(i) == L4D_TEAM_INFECTED)
				{
					if(readyStatus[i]) 
					{
						numPlayers2++;
						Format(readyPlayers, 1024, "->%d. ★%s",numPlayers2,name);
						DrawPanelText(panel, readyPlayers);
					}
					else
					{
						numPlayers2++;
						Format(readyPlayers, 1024, "->%d. ☆%s%s",numPlayers2,name,(IsPlayerAfk(i, fTime)) ? " [AFK]" : "");
						DrawPanelText(panel, readyPlayers);
					}
				}
			}
		}
	}
	if(specs)
	{
		DrawPanelText(panel, "SPECTATORS.");
		
		if( specs >=3 && ( RealplayerinSV() >= 14 || (sur == GetTeamMaxHumans(2) && inf == GetTeamMaxHumans(3)) ) )
		{
			Format(readyPlayers, 1024, "Many (%d)", specs);
			DrawPanelText(panel, readyPlayers);
		}
		else
		{
			for(i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGameHumanSpec(i) && GetClientTeam(i) == L4D_TEAM_SPECTATE)
				{
					GetClientName(i, name, sizeof(name));
					
					numPlayers3++;
					Format(readyPlayers, 1024, "->%d. %s", numPlayers3, name);
					DrawPanelText(panel, readyPlayers);
					#if READY_DEBUG
					DrawPanelText(panel, readyPlayers);
					#endif
				}
			}
		}
	}
	
	DrawPanelText(panel, " ");
	FormatTime(Notice, 64, "%m/%d/%Y - %I:%M%p");
	Format(Notice, 64, "%s (%s%d:%s%d)", Notice, (TimeCount/60 < 10) ? "0" : "",TimeCount/60, (TimeCount%60 < 10) ? "0" : "", TimeCount%60);
	DrawPanelText(panel, Notice);
	
	for(i = 1; i <= MaxClients; i++) 
	{
		if(IsClientInGameHumanSpec(i)) 
		{
			if(GetClientMenu(i, INVALID_HANDLE) == MenuSource_None && !hiddenPanel[i]) //client is not watching menu
			{
				SendPanelToClient(panel, i, Menu_ReadyPanel, READY_LIST_PANEL_LIFETIME);
				continue;
			}
			else if(IsClientVoteMenu(i) || IsClientInfoMenu(i) || hiddenPanel[i]){
				continue;
			}
			else
				SendPanelToClient(panel, i, Menu_ReadyPanel, READY_LIST_PANEL_LIFETIME);
		}
	}
	
	if(menuPanel != INVALID_HANDLE)
	{
		CloseHandle(menuPanel);
	}
	menuPanel = panel;
}


public Action:readyDraw(client, args)
{
	DrawReadyPanelList();
}

public Menu_ReadyPanel(Handle:menu, MenuAction:action, param1, param2) 
{ 
	
	if(!readyMode)
	{
		return;
	}
}




//thanks to Liam for helping me figure out from the disassembly what the server's director_stop does
directorStop()
{
	#if READY_DEBUG
	DebugPrintToAll("[DEBUG] Director stopped.");
	#endif		
	//doing director_stop on the server sets the below variables like so
	SetConVarInt(FindConVar("director_no_bosses"), 1);
	if(GetConVarBool(cvarReadyUpStyle))
	{
		SetConVarInt(FindConVar("director_no_specials"), 0);
		SetConVarInt(FindConVar("versus_force_start_time"), 86400); //24hours : D
	}
	else
	{
		SetConVarInt(FindConVar("director_no_specials"), 1);
		SetConVarInt(FindConVar("versus_force_start_time"), 90);	//default
	}
	SetConVarInt(FindConVar("director_no_mobs"), 1);
	SetConVarInt(FindConVar("director_ready_duration"), 0);
	SetConVarInt(FindConVar("z_common_limit"), 0);
	SetConVarInt(FindConVar("z_mega_mob_size"), 1); //why not 0? only Valve knows
	//SetConVarInt(FindConVar("z_health"), 0);											//doest spawn zombies but doesnt stop director
	
	//empty teams of survivors dont cycle the round
	SetConVarInt(FindConVar("sb_all_bot_team"), 1);
	
	//dont accidentally spawn tanks in ready mode
	ResetConVar(FindConVar("director_force_tank"));

	//kill all common
	int common = MaxClients + 1;
	while ((common = FindEntityByClassname(common, "infected")) != INVALID_ENT_REFERENCE)
	{
		if(GetEntProp(common, Prop_Data, "m_iHealth") < 0) continue;

		AcceptEntityInput(common, "Kill");
	}
}

directorStart()
{
	hasdirectorStart = true;
	SetConVarInt(g_hDirectorNoDeathCheck, 0);
	HookOrUnhookPreThinkPost(false);
	//getting values from the convars
	new ready_z_common_limit = GetConVarInt(cvarReadyCommonLimit);
	new ready_z_mega_mob_size = GetConVarInt(cvarReadyMegaMobSize);
	new ready_sb_all_bot_team = GetConVarInt(cvarReadyAllBotTeam);
	ResetConVar(FindConVar("director_no_bosses"));
	ResetConVar(FindConVar("director_no_specials"));
	ResetConVar(FindConVar("director_no_mobs"));
	ResetConVar(FindConVar("director_ready_duration"));
	//support for ?v? cfgs - only reset these cvars if the round isn't being restarted, or there isn't a ?v? cfg
	//if(!GetConVarBool(cvarReadyRestartRound) || !GetConVarBool(cvarReadyServerCfg))
	SetConVarInt(FindConVar("z_common_limit"), ready_z_common_limit);
	SetConVarInt(FindConVar("z_mega_mob_size"), ready_z_mega_mob_size);
	SetConVarInt(FindConVar("sb_all_bot_team"), ready_sb_all_bot_team);		
}

//freeze everyone until they ready up
readyOn()
{
	readyMode = true;
	
	PrintHintTextToAll("%t","ReadyPlugin_29");

	if(!hookedPlayerHurt) 
	{
		HookEvent("player_hurt", eventPlayerHurt);
		hookedPlayerHurt = 1;
	}
		
	if(g_bNoSafeStartAreaMap)
	{
		inLiveCountdown = true;
		FindConVar("sb_stop").IntValue = 1;
	}
	
	if(!unreadyTimerExists)
	{
		unreadyTimerExists = true;
		CreateTimer(READY_UNREADY_HINT_PERIOD, timerUnreadyCallback, _, TIMER_REPEAT);
	}
	CreateTimer(1.0, TimerCountAdd, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action:TimerCountAdd(Handle:timer)
{
	if(readyMode)
	{
		TimeCount++;

		DrawReadyPanelList();
		checkStatus();
		return Plugin_Continue;
	}
	return Plugin_Stop;
}

//allow everyone to move now
readyOff()
{
	DebugPrintToAll("readyOff() called");
	
	readyMode = false;
	
	//events seem to be all unhooked _before_ OnPluginEnd
	//though even if it wasnt, they'd get unhooked after anyway..
	if(hookedPlayerHurt && !insidePluginEnd) 
	{
		UnhookEvent("player_hurt", eventPlayerHurt);
		hookedPlayerHurt = 0;
	}
	
	//used to unfreeze all players here always
	//now we will do it at the beginning of the round when its live
	//so that players cant open the safe room door during the restarts
}

UnfreezeAllPlayers()
{
	decl i;
	for(i = 1; i <= MaxClients; i++) 
	{
		if(IsClientInGame(i) && (GetClientTeam(i) == L4D_TEAM_SURVIVORS)) 
		{
			#if READY_DEBUG
			new String:curname[128];
			GetClientName(i,curname,128);
			DebugPrintToAll("[DEBUG] Unfreezing %s [%d] during UnfreezeAllPlayers().", curname, i);
			#endif
			
			//if(GetClientTeam(i) != L4D_TEAM_SPECTATE)
				ToggleFreezePlayer(i, false);
			/*else
				SetEntityMoveType(i, MOVETYPE_OBSERVER);*/
		}
	}
}

//make everyone un-ready, but don't actually freeze them
compOn()
{
	DebugPrintToAll("compOn() called");
	
	goingLive = 0;
	readyMode = false;
	forcedStart = 0;
	
	decl i;
	for(i = 1; i <= MAXPLAYERS; i++) readyStatus[i] = 0;
}

//begin the ready mode (everyone now needs to ready up before they can move)
public Action:compReady(client, args)
{
	if(goingLive)
	{
		return Plugin_Handled;
	}
	
	compOn();
	readyOn();
	
	return Plugin_Handled;
}

//force start a match using admin
public Action:compStart(client, args)
{
	if(!readyMode)
		return Plugin_Handled;
	
	if(goingLive)
	{
		return Plugin_Handled;
	}
	
	//	compOn();
	/*
	goingLive = GetConVarInt(cvarReadyLiveCountdown);
	forcedStart = 1;
	liveTimer = CreateTimer(1.0, timerLiveCountCallback, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	*/
	
	InitiateLiveCountdown();
	
	return Plugin_Handled;
}

//restart the map when we toggle the cvar
public ConVarChange_ReadyEnabled(Handle:convar, const String:oldValue[], const String:newValue[])
{	
	if(oldValue[0] == newValue[0])
	{
		return;
	}
	else
	{
		new value = StringToInt(newValue);
		
		if(value)
		{
			CPrintToChatAll("{default}[{olive}TS{default}] %t","ReadyPlugin_30");
		}
		else
		{
			CPrintToChatAll("{default}[{olive}TS{default}] %t","ReadyPlugin_31");
			readyOff();
		}
	}
}


//disable most non-competitive plugins
public ConVarChange_ReadyCompetition(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if(oldValue[0] == newValue[0])
	{
		return;
	}
	else
	{
		new value = StringToInt(newValue);
		
		if(value)
		{
			//TODO: use plugin iterators such as GetPluginIterator
			// to unload all plugins BUT the ones below
			
			ServerCommand("sm plugins load_unlock");
			ServerCommand("sm plugins unload_all");
			ServerCommand("sm plugins load basebans.smx");
			ServerCommand("sm plugins load basecommands.smx");
			ServerCommand("sm plugins load admin-flatfile.smx");
			ServerCommand("sm plugins load adminhelp.smx");
			ServerCommand("sm plugins load adminmenu.smx");
			ServerCommand("sm plugins load l4dscores.smx"); //IMPORTANT: load before l4dready!
			ServerCommand("sm plugins load l4dready.smx");
			ServerCommand("sm plugins load_lock");
			
			DebugPrintToAll("Competition mode enabled, plugins unloaded...");
			
			//TODO: also call sm_restartmap and sm_resetscores
			// this removes the dependency from configs to know what to do :)
			
			//Maybe make this command sm_competition_on, sm_competition_off ?
			//that way people will probably not use in server.cfg 
			// and they can exec the command over and over and it will be fine
		}
		else
		{
			ServerCommand("sm plugins load_unlock");
			ServerCommand("sm plugins refresh");

			DebugPrintToAll("Competition mode enabled, plugins reloaded...");
		}
	}
}


public ConVarChange_cvarSpectatePenalty(Handle:convar, const String:oldValue[], const String:newValue[])
{
	CheckSpectatePenalty();
}

static CheckSpectatePenalty()
{
	if(GetConVarInt(cvarSpectatePenalty) < -1) g_iSpectatePenalty = -1;
	else g_iSpectatePenalty = GetConVarInt(cvarSpectatePenalty);
	g_iSpectatePenalty--;
	
	new i;
	for(i = 1; i <= MaxClients; i++)
	{	
		g_iSpectatePenaltyCounter[i] = g_iSpectatePenalty;
	}	
}

public Action:Command_DumpEntities(client, args)
{
	decl String:netClass[128];
	decl String:className[128];
	new i;
	
	DebugPrintToAll("Dumping entities...");
	
	for(i = 1; i < GetMaxEntities(); i++)
	{
		if(IsValidEntity(i))
		{
			if(IsValidEdict(i)) 
			{
				GetEdictClassname(i, className, 128);
				GetEntityNetClass(i, netClass, 128);
				DebugPrintToAll("Edict = %d, class name = %s, net class = %s", i, className, netClass);
			}
			else
			{
				GetEntityNetClass(i, netClass, 128);
				DebugPrintToAll("Entity = %d, net class = %s", i, netClass);
			}
		}
	}
	
	return Plugin_Handled;
}

public Action:Command_DumpGameRules(client,args) 
{
	new getTeamScore = GetTeamScore(2);
	DebugPrintToAll("Get team Score for team 2 = %d", getTeamScore);
	
	new gamerules = FindEntityByClassname(-1, "terror_gamerules");
	
	if(gamerules == -1)
	{
		DebugPrintToAll("Failed to find terror_gamerules edict");
		return Plugin_Handled;
	}
	
	new offset = FindSendPropInfo("CTerrorGameRulesProxy","m_iSurvivorScore");
	if(offset == -1)
	{
		DebugPrintToAll("Failed to find the property when searching for offset");
		return Plugin_Handled;
	}
	
	new entValue = GetEntData(gamerules, offset, 4);
	new entValue2 = GetEntData(gamerules, offset+4, 4);
	//	new distance = GetEntProp(gamerules, Prop_Send, "m_iSurvivorScore");
	
	DebugPrintToAll("Survivor score = %d, %d [offset = %d]", entValue, entValue2, offset);
	
	new c_offset = FindSendPropInfo("CTerrorGameRulesProxy","m_iCampaignScore");
	if(c_offset == -1)
	{
		DebugPrintToAll("Failed to find the property when searching for c_offset");
		return Plugin_Handled;
	}
	
	new centValue = GetEntData(gamerules, c_offset, 2);
	new centValue2 = GetEntData(gamerules, c_offset+4, 2);
	//	new distance = GetEntProp(gamerules, Prop_Send, "m_iSurvivorScore");
	
	DebugPrintToAll("Campaign score = %d, %d [offset = %d]", centValue, centValue2, c_offset);
	
	/*
	* try the 4 cs_team_manager aka CCSTeam edicts
	* 
	*/
	
	decl teamNumber, score;
	decl String:teamName[128];
	decl String:curClassName[128];
	
	new i, teams;
	for(i = 0; i < GetMaxEntities() && teams < 4; i++)
	{
		if(IsValidEdict(i)) 
		{
			GetEdictClassname(i, curClassName, 128);
			if(strcmp(curClassName, "cs_team_manager") == 0) 
			{
				teams++;
				
				teamNumber = GetEntData(i, FindSendPropInfo("CCSTeam", "m_iTeamNum"), 1);
				score = GetEntData(i, FindSendPropInfo("CCSTeam", "m_iScore"), 4);
				
				GetEntPropString(i, Prop_Send, "m_szTeamname", teamName, 128);
				
				DebugPrintToAll("Team #%d, score = %d, name = %s", teamNumber, score, teamName);
			}
		}
		
	}
	
	return Plugin_Handled;
}

public Action:Command_ScanProperties(client, args)
{
	if(GetCmdArgs() != 3)
	{
		PrintToChat(client, "Usage: sm_scanproperties <step> <size> <needle>");
		return Plugin_Handled;
	}
	
	decl String:cmd1[128], String:cmd2[128], String:cmd3[128];
	decl String:curClassName[128];
	
	GetCmdArg(1, cmd1, 128);
	GetCmdArg(2, cmd2, 128);	
	GetCmdArg(3, cmd3, 128);
	
	new step = StringToInt(cmd1);
	new size = StringToInt(cmd2);
	new needle = StringToInt(cmd3);
	
	new gamerules = FindEntityByClassname(-1, "terror_gamerules");
	
	if(gamerules == -1)
	{
		DebugPrintToAll("Failed to find terror_gamerules edict");
		return Plugin_Handled;
	}
	
	
	new i;
	new value = -1;
	for(i = 100; i < 1000; i += step)
	{
		value = GetEntData(gamerules, i, size);
		
		if(value == needle)
		{
			break;
		}
	}
	if(value == needle)
	{
		DebugPrintToAll("Found value at offset = %d in terror_gamesrules", i);
	}
	else
	{
		DebugPrintToAll("Failed to find value in terror_gamesrules");
	}
	
	new teams;
	new j;
	for(j = 0; j < GetMaxEntities() && teams < 4; j++)
	{
		if(IsValidEdict(j)) 
		{
			GetEdictClassname(j, curClassName, 128);
			if(strcmp(curClassName, "cs_team_manager") == 0)
			{
				teams++;
				value = -1;
				
				for(i = 100; i < 1000; i += step)
				{
					value = GetEntData(j, i, size);
					
					if(value == needle)
					{
						break;
					}
				}
				if(value == needle)
				{
					DebugPrintToAll("Found value at offset = %d in cs_team_manager", i);
					break;
				}
				else
				{
					DebugPrintToAll("Failed to find value in cs_team_manager");
				}
			}
		}
		
	}
	
	return Plugin_Handled;
	
}

public Action:Command_PlayerSwapPlayer(client, args)
{
	if(args < 2)
	{
		ReplyToCommand(client, "[TS] Usage: sm_swapplayer <player1> <player2> - %T","ReplyToCommand7",client);
		return Plugin_Handled;
	}
	
	new player1_id, player2_id;

	new String:player1[64];
	GetCmdArg(1, player1, sizeof(player1));

	new String:player2[64];
	GetCmdArg(2, player2, sizeof(player2));
	
	player1_id = FindTarget(client, player1, true /*nobots*/, false /*immunity*/);
	player2_id = FindTarget(client, player2, true /*nobots*/, false /*immunity*/);
	
	if(player1_id == -1 || player2_id == -1)
		return Plugin_Handled;
	
	SwapPlayers(player1_id, player2_id);
	
	decl String:playername1[128],String:playername2[128];
	GetClientName(player1_id,playername1,128);
	GetClientName(player2_id,playername2,128);
	CPrintToChatAll("{default}[{olive}TS{default}] %t","ReadyPlugin_32", playername1, playername2);

	return Plugin_Handled;
}

public Action:Command_SwapTeams(client, args)
{
	new infected[4];
	new survivors[4];
	
	new inf = 0, sur = 0;
	new i;
	
	for(i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGameHuman(i)) 
		{
			new team = GetClientTeam(i);
			if(team == L4D_TEAM_SURVIVORS)
			{
				survivors[sur] = i;
				sur++;
			}
			else if(team == L4D_TEAM_INFECTED)
			{
				infected[inf] = i;
				inf++;
			}
		}
	}
	
	new min = inf > sur ? sur : inf;
	
	//first swap everyone that we can (equal # on both sides)
	for(i = 0; i < min; i++)
	{
		SwapPlayers(infected[i], survivors[i]);
	}
	
	//then move the remainder of the team to the other team
	if(inf > sur)
	{
		for(i = min; i < inf; i++)
		{
			ChangePlayerTeam(infected[i], L4D_TEAM_SURVIVORS);
		}
	}
	else 
	{
		for(i = min; i < sur; i++)
		{
			ChangePlayerTeam(survivors[i], L4D_TEAM_INFECTED);
		}
	}
	
	CPrintToChatAll("{default}[{olive}TS{default}] %t","ReadyPlugin_33");
	
	return Plugin_Handled;
}

//swap the two given players' teams
SwapPlayers(i, j)
{
	if(GetClientTeam(i) == GetClientTeam(j))
		return;
	
	new inf, surv;
	if(GetClientTeam(i) == L4D_TEAM_INFECTED)
	{
		inf = i;
		surv = j;
	}
	else
	{
		inf = j;
		surv = i;
	}

	ChangePlayerTeam(inf,  L4D_TEAM_SPECTATE); 
	ChangePlayerTeam(surv, L4D_TEAM_INFECTED); 
	ChangePlayerTeam(inf,  L4D_TEAM_SURVIVORS); 
}

ChangePlayerTeam(client, team)
{
	if( !IsClientInGame(client) || GetClientTeam(client) == team) return;
	
	if(team != L4D_TEAM_SURVIVORS)
	{
		ChangeClientTeam(client, team);
		return;
	}
	
	//for survivors its more tricky
	
	new String:command[] = "sb_takecontrol";
	new flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	
	new String:botNames[][] = { "zoey", "louis", "bill", "francis" };
	
	new cTeam;
	cTeam = GetClientTeam(client);
	
	new i = 0;
	while(cTeam != L4D_TEAM_SURVIVORS && i < 4)
	{
		FakeClientCommand(client, "sb_takecontrol %s", botNames[i]);
		cTeam = GetClientTeam(client);
		i++;
	}

	SetCommandFlags(command, flags);
}



//when the match goes live, at round_end of the last automatic restart
//just before the round_start
RoundEndBeforeLive()
{
	readyOff();	
}

//round_start just after the last automatic restart
RoundIsLive()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i)) continue;

		if(GetClientTeam(i) != L4D_TEAM_SURVIVOR) continue;

		SetEntProp(i, Prop_Data, "m_idrowndmg", 0.0);
		SetEntProp(i, Prop_Data, "m_idrownrestored", 0.0);
	}

	SetConVarInt(FindConVar("sb_stop"), SB_STOP_CONVAR);
	SetConVarInt(g_hDirectorNoDeathCheck, 0);
	UnfreezeAllPlayers();
	readyOff();
	CPrintToChatAll("{default}[{olive}TS{default}] {blue}%t{default}: {green}%d%%","Survivor_Current", GetSurCurrent());
	GiveSurAllPills();
	Keep_SI_Starting();
	antibaiter_clear();
	PrintBossPercents();
	ChoseTankPrintWhoBecome();
	CreateTimer(1.5, timerLiveMessageCallback, _, _);

	directorStart();

	Call_StartForward(fwdOnReadyRoundRestarted);
	Call_Finish();
}

ToggleFreezePlayer(client, freeze)
{
	SetEntityMoveType(client, freeze ? MOVETYPE_NONE : MOVETYPE_WALK);
}

//client is connected
bool:IsClientInGameHumanSpec(client)
{
	return IsClientInGame(client) && !IsFakeClient(client);
}
//client is in-game and not a bot and not spec
bool:IsClientInGameHuman(client)
{
	return IsClientInGame(client) && !IsFakeClient(client) && ((GetClientTeam(client) == L4D_TEAM_SURVIVORS || GetClientTeam(client) == L4D_TEAM_INFECTED) || GetConVarBool(cvarReadySpectatorRUP));
}

DebugPrintToAll(const String:format[], any:...)
{
#if READY_DEBUG	|| READY_DEBUG_LOG
	decl String:buffer[192];
	
	VFormat(buffer, sizeof(buffer), format, 2);
	
#if READY_DEBUG
	PrintToChatAll("[READY] %s", buffer);
#endif
	LogMessage("%s", buffer);
#else
	//suppress "format" never used warning
	if(format[0])
		return;
	else
		return;
#endif
}


#if HEALTH_BONUS_FIX
public Action:Command_UpdateHealth(client, args)
{
	DelayedUpdateHealthBonus();
	
	return Plugin_Handled;
}

public Action:Event_ItemPickup(Handle:event, const String:name[], bool:dontBroadcast)
{	
	new player = GetClientOfUserId(GetEventInt(event, "userid"));
	
	new String:item[128];
	GetEventString(event, "item", item, sizeof(item));
	
	#if EBLOCK_DEBUG
	new String:curname[128];
	GetClientName(player,curname,128);
	
	if(strcmp(item, "pain_pills") == 0)		
		DebugPrintToAll("EVENT - Item %s picked up by %s [%d]", item, curname, player);
	#endif
	
	if(strcmp(item, "pain_pills") == 0)
	{
		painPillHolders[player] = true;
		DelayedPillUpdate();
	}
	
	return Plugin_Handled;
}

public Action:Event_PillsUsed(Handle:event, const String:name[], bool:dontBroadcast)
{	
	new player = GetClientOfUserId(GetEventInt(event, "userid"));
	
	#if EBLOCK_DEBUG
	new subject = GetClientOfUserId(GetEventInt(event, "subject"));
	
	new String:curname[128];
	GetClientName(player,curname,128);
	
	new String:curname_subject[128];
	GetClientName(subject,curname_subject,128);
	
	DebugPrintToAll("EVENT - %s [%d] used pills on subject %s [%d]", curname, player, curname_subject, subject);
	#endif
	
	painPillHolders[player] = false;
	
	return Plugin_Handled;
}



public Action:Event_HealSuccess(Handle:event, const String:name[], bool:dontBroadcast)
{	
	#if EBLOCK_DEBUG
	new player = GetClientOfUserId(GetEventInt(event, "userid"));
	new subject = GetClientOfUserId(GetEventInt(event, "subject"));
	
	new String:curname[128];
	GetClientName(player,curname,128);
	
	new String:curname_subject[128];
	GetClientName(subject,curname_subject,128);
	
	DebugPrintToAll("EVENT - %s [%d] healed %s [%d] successfully", curname, player, curname_subject, subject);
	#endif

	DelayedUpdateHealthBonus();
	
	return Plugin_Handled;
}

DelayedUpdateHealthBonus()
{
	#if EBLOCK_USE_DELAYED_UPDATES
	CreateTimer(EBLOCK_BONUS_UPDATE_DELAY, Timer_DoUpdateHealthBonus, _, _);
	#else
	UpdateHealthBonus();
	#endif
	
	DebugPrintToAll("Delayed health bonus update");
}

public Action:Timer_DoUpdateHealthBonus(Handle:timer)
{
	UpdateHealthBonus();
}

UpdateHealthBonus()
{
	decl i;
	for(i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == 2) 
		{
			UpdateHealthBonusForClient(i);
		}
	}
}

DelayedPillUpdate()
{
	#if EBLOCK_USE_DELAYED_UPDATES
	CreateTimer(EBLOCK_BONUS_UPDATE_DELAY, Timer_PillUpdate, _, _);
	#else
	UpdateHealthBonusForPillHolders();
	#endif
	
	DebugPrintToAll("Delayed pill bonus update");
}

public Action:Timer_PillUpdate(Handle:timer)
{
	UpdateHealthBonusForPillHolders();
}

UpdateHealthBonusForPillHolders()
{
	decl i;
	for(i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == 2 && painPillHolders[i]) 
		{
			UpdateHealthBonusForClient(i);
		}
	}
}

UpdateHealthBonusForClient(client)
{
	SendHurtMe(client);
}

SendHurtMe(i)
{	/*
	* when a person uses pills the m_healthBuffer gets set to 
	* minimum(50, 100-currentHealth)
	* 
	* it stays at that value until the person heals (or uses pills?)
	* or the round is over
	* 
	* once the m_healthBuffer property is non-0 the health bonus for that player
	* seems to keep updating
	* 
	* The first time we set it ourselves that player gets that much temp hp,
	* setting it afterwards crashes the server, and setting it after we set it
	* for the first time doesn't do anything.
	*/
	new Float:healthBuffer = GetEntPropFloat(i, Prop_Send, "m_healthBuffer");
	
	DebugPrintToAll("Health buffer for player [%d] is %f", i, healthBuffer);	
	if(healthBuffer == 0.0)
	{
		SetEntPropFloat(i, Prop_Send, "m_healthBuffer", EBLOCK_BONUS_HEALTH_BUFFER);
		DebugPrintToAll("Health buffer for player [%d] set to %f", i, EBLOCK_BONUS_HEALTH_BUFFER);
	}
	
	DebugPrintToAll("Sent hurtme to [%d]", i);
}
#endif

public Action Hide_Cmd(int client, int args)
{
	if (readyMode)
	{
		hiddenPanel[client] = true;
		CPrintToChat(client, "%T", "PanelHide", client);
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action Show_Cmd(int client, int args)
{
	if (readyMode)
	{
		hiddenPanel[client] = false;
		CPrintToChat(client, "%T", "PanelShow", client);
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action:Return_Cmd(client, args)
{
	if (client > 0
			&& readyMode
			&& GetClientTeam(client) == L4D_TEAM_SURVIVORS)
	{
		ReturnPlayerToSaferoom(client, false);
	}
	return Plugin_Handled;
}

public Action L4D_OnFirstSurvivorLeftSafeArea(int client)
{
	if(cvarEnforceReady.BoolValue == true && hasdirectorStart == false) {
		if(!g_bNoSafeStartAreaMap) ReturnToSaferoom(client);
		return Plugin_Handled;
	}

	if (readyMode && g_bNoSafeStartAreaMap == false) {
		ReturnToSaferoom(client);
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

ReturnToSaferoom(client)
{
	new warp_flags = GetCommandFlags("warp_to_start_area");
	SetCommandFlags("warp_to_start_area", warp_flags & ~FCVAR_CHEAT);
	new give_flags = GetCommandFlags("give");
	SetCommandFlags("give", give_flags & ~FCVAR_CHEAT);
	if (IsClientInGame(client) && GetClientTeam(client) == L4D_TEAM_SURVIVORS)
	{
		ReturnPlayerToSaferoom(client);
	}
	SetCommandFlags("warp_to_start_area", warp_flags);
	SetCommandFlags("give", give_flags);
}

ReturnPlayerToSaferoom(client,bool:flagsSet = true)
{
	if (!IsPlayerAlive(client)) L4D_RespawnPlayer(client);

	new warp_flags;
	new give_flags;
	if (!flagsSet)
	{
		warp_flags = GetCommandFlags("warp_to_start_area");
		SetCommandFlags("warp_to_start_area", warp_flags & ~FCVAR_CHEAT);
		give_flags = GetCommandFlags("give");
		SetCommandFlags("give", give_flags & ~FCVAR_CHEAT);
	}

	if (GetEntProp(client, Prop_Send, "m_isHangingFromLedge"))//懸掛
	{
		FakeClientCommand(client, "give health");
	}
	else if (IsPlayerAlive(client)||IsIncapacitated(client))//倒地
	{
		FakeClientCommand(client, "give health");
		SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
		SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0);
	}
	else if(GetClientHealth(client)<100) //血量低於100
	{
		FakeClientCommand(client, "give health");
		SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
		SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0);
	}
	
	FakeClientCommand(client, "warp_to_start_area");

	if (!flagsSet)
	{
		SetCommandFlags("warp_to_start_area", warp_flags);
		SetCommandFlags("give", give_flags);
	}

	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, NULL_VELOCITY);
}

ReturnTeamToSaferoom()
{
	new warp_flags = GetCommandFlags("warp_to_start_area");
	SetCommandFlags("warp_to_start_area", warp_flags & ~FCVAR_CHEAT);
	new give_flags = GetCommandFlags("give");
	SetCommandFlags("give", give_flags & ~FCVAR_CHEAT);

	for (new client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && GetClientTeam(client) == L4D_TEAM_SURVIVORS)
		{
			ReturnPlayerToSaferoom(client);
		}
	}

	SetCommandFlags("warp_to_start_area", warp_flags);
	SetCommandFlags("give", give_flags);
}

InitiateLiveCountdown()
{
	if(!readyMode) return;
	if (readyCountdownTimer == INVALID_HANDLE)
	{
		ReturnTeamToSaferoom();
		SetTeamFrozen(true);
		PrintHintTextToAll("%t","ReadyPlugin_34");
		inLiveCountdown = true;
		FindConVar("sb_stop").IntValue = 1;
		readyDelay = READY_LIVE_COUNTDOWN;
		readyCountdownTimer = CreateTimer(1.0, ReadyCountdownDelay_Timer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action:ReadyCountdownDelay_Timer(Handle:timer)
{
	if (readyDelay == 0)
	{
		RoundIsLive();
		PrintHintTextToAll("%t","ReadyPlugin_35");
		inLiveCountdown = false;
		readyCountdownTimer = INVALID_HANDLE;
		EmitSoundToAll("buttons/blip2.wav", _, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.5);
		
		return Plugin_Stop;
	}
	else
	{
		PrintHintTextToAll("%t","ReadyPlugin_36", readyDelay);
		EmitSoundToAll("buttons/blip1.wav", _, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.5);
		readyDelay--;
	}
	return Plugin_Continue;
}

SetTeamFrozen(bool:freezeStatus)
{
	for (new client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && GetClientTeam(client) == L4D_TEAM_SURVIVORS)
		{
			ToggleFreezePlayer(client, freezeStatus);
		}
	}
}

public Native_IsInReady(Handle:plugin, numParams)
{
	return readyMode;
}

public Native_Is_Ready_Plugin_On(Handle:plugin, numParams)
{
	return cvarEnforceReady.BoolValue;
}

public int Native_ToggleReadyPanel(Handle plugin, int numParams)
{
	if (readyMode)
	{
		// TODO: Inform the client(s) that panel is supressed?
		bool hide = !GetNativeCell(1);
		
		int client = GetNativeCell(2);
		if (client && IsClientInGame(client))
		{
			bool temp = !hiddenPanel[client];
			hiddenPanel[client] = hide;
			return temp;
		}
		else
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i))
				{
					hiddenPanel[i] = hide;
				}
			}
			return true;
		}
	}
	return false;
}

public ConVarChanged_GameMode(Handle:convar, const String:oldValue[], const String:newValue[])
{
	GetConVarString(g_hCvarGameMode, CurrentGameMode, sizeof(CurrentGameMode));
}

public OnConfigsExecuted()
{
	SB_STOP_CONVAR = GetConVarInt(FindConVar("sb_stop"));
}

public Action:Secret_Cmd(client, args)
{
	if(!readyMode || readyStatus[client] || GetClientTeam(client) == L4D_TEAM_SPECTATE || g_bIsSpectating[client]) return Plugin_Handled;
	
	DoSecrets(client);	//easter egg
	
	readyStatus[client] = 1;
	checkStatus();
	DrawReadyPanelList();
	
	return Plugin_Continue;
}

stock DoSecrets(client)
{
	if (GetClientTeam(client) == L4D_TEAM_SURVIVORS && !blockSecretSpam[client])
	{
		new particle = CreateEntityByName("info_particle_system");
		decl Float:pos[3];
		GetClientAbsOrigin(client, pos);
		pos[2] += 80;
		TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);
		DispatchKeyValue(particle, "effect_name", "achieved");
		DispatchKeyValue(particle, "targetname", "particle");
		DispatchSpawn(particle);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
		CreateTimer(5.0, killParticle, particle, TIMER_FLAG_NO_MAPCHANGE);
		EmitSoundToAll(SECRET_EGG_SOUND, client, SNDCHAN_VOICE);
		CreateTimer(5.0, SecretSpamDelay, client);
		blockSecretSpam[client] = true;
	}
	PrintHintText(client, "%T","ReadyPlugin_37",client);
}

public Action:killParticle(Handle:timer, any:particle)
{
	if (particle > 0 && IsValidEntity(particle) && IsValidEdict(particle))
	{
		AcceptEntityInput(particle, "Kill");
	}
}

public Action:SecretSpamDelay(Handle:timer, any:client)
{
	blockSecretSpam[client] = false;
}

stock IsPlayerAfk(client, Float:fTime)
{
	if( fTime - g_fButtonTime[client] > 15.0)
		return true;
	return false;
}

stock SetEngineTime(client)
{
	g_fButtonTime[client] = GetEngineTime();
}

public Action Timer_PlayerLeftStart(Handle Timer)
{
	if (L4D_HasAnySurvivorLeftSafeArea())
	{	
		hasleftsaferoom = true;

		g_iCountDownTime = g_iCvarGameTimeBlock;
		if(g_iCountDownTime > 0)
		{
			if(CountDownTimer == null) CountDownTimer = CreateTimer(1.0, Timer_CountDown, _, TIMER_REPEAT);
		}

		PlayerLeftStartTimer = null;
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

public Action Timer_CountDown(Handle timer)
{
	if(g_iCountDownTime <= 0) 
	{
		g_bGameTeamSwitchBlock = true;
		CountDownTimer = null;
		return Plugin_Stop;
	}
	g_iCountDownTime--;
	return Plugin_Continue;
}

void ResetVariable()
{
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
}

void ResetTimer()
{
	delete PlayerLeftStartTimer;
	delete CountDownTimer;
}

int FindBotToTakeOver(bool alive)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i)==2 && !HasIdlePlayer(i) && IsPlayerAlive(i) == alive)
		{
			return i;
		}
	}
	return 0;
}

bool HasIdlePlayer(int bot)
{
	if(IsClientInGame(bot) && IsFakeClient(bot) && GetClientTeam(bot) == 2 && IsPlayerAlive(bot))
	{
		if(HasEntProp(bot, Prop_Send, "m_humanSpectatorUserID"))
		{
			int client = GetClientOfUserId(GetEntProp(bot, Prop_Send, "m_humanSpectatorUserID"))	;		
			if(client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client) && IsClientObserver(client))
			{
				return true;
			}
		}
	}
	return false;
}

void MI_KV_Load()
{
	char sNameBuff[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sNameBuff, 256, "data/%s", "mapinfo.txt");

	g_hMIData = CreateKeyValues("MapInfo");
	if (!FileToKeyValues(g_hMIData, sNameBuff)) {
		LogError("[MI] Couldn't load MapInfo data!");
		MI_KV_Close();
	}
}

void MI_KV_Close()
{
	if (g_hMIData != null) {
		CloseHandle(g_hMIData);
		g_hMIData = null;
	}
}