#include <sourcemod>
#include <sdktools>
#include <multicolors>
#include <left4dhooks>
#include <l4d_lib>

#define SCORE_VERSION "8.3.9"

#define SCORE_DEBUG 0
#define SCORE_DEBUG_LOG 0

#define SCORE_TEAM_A 1
#define SCORE_TEAM_B 2
#define SCORE_TYPE_ROUND false
#define SCORE_TYPE_CAMPAIGN 1

#define SCORE_DELAY_PLACEMENT 0.1
#define SCORE_DELAY_TEAM_SWITCH 0.1
#define SCORE_DELAY_SWITCH_MAP 1.0
#define SCORE_DELAY_EMPTY_SERVER 5.0
#define SCORE_DELAY_SCORE_SWAPPED 0.1

#define SCORE_LIST_PANEL_LIFETIME 10
#define SCORE_SWAPMENU_PANEL_LIFETIME 10
#define SCORE_SWAPMENU_PANEL_REFRESH 0.5

#define L4D_MAXCLIENTS MaxClients
#define L4D_MAXCLIENTS_PLUS1 (L4D_MAXCLIENTS + 1)
#define L4D_TEAM_SURVIVORS 2
#define L4D_TEAM_INFECTED 3
#define L4D_TEAM_SPECTATE 1
#define L4D_TEAM_MAX_CLIENTS 4
#define L4D_TEAM_NAME(%1) (%1 == 2 ? "Survivors" : (%1 == 3 ? "Infected" : (%1 == 1 ? "Spectators" : "Unknown")))
#define CONFIG_MAPINFO		"data/mapinfo.txt" //真正修改遊戲難度的在left4dead\missions

/*
TODO:
0. Check if campaign score reset detection works well. MANUAL? :(

2. Fix people being stuck in spectator when swap fails
  - add overrides for jointeam 2/3 command?
  - sm_swap on spectator put person on the smallest non-full team?
  (DONE: needs testing)
 
3. Detect a restarted round  (finalize old scores//don't overwrite old scores with new?)
   - treat first vs second round separately
   - first round is over when scores is not (X,-1).. if it is when round_start then round was restarted?
    - only write first round once when its finalized, dont overwrite
   - doesnt matter when 2nd round is over, just keep overwriting second round score
   
4. Add sm_swapto <names> <1/2/3> command 
  (DONE: needs testing)
*/

/*
* For testing?
*/
#define SCORE_CAMPAIGN_OVERRIDE 1
#define SCORE_TEAM_PLACEMENT_OVERRIDE 0

/*
* TODO:
* - with RUP and after a !reready the first team's scores 
*   get overriden with default 200*multiplier scores
*/
forward OnReadyRoundRestarted();

public Plugin:myinfo = 
{
	name = "L4D Score/Team Manager",
	author = "Downtown1, L4D1 modify by harry",
	description = "Manage teams and scores in L4D, show health bouns",
	version = SCORE_VERSION,
	url = "http://steamcommunity.com/profiles/76561198026784913"
}

new campaignScores[3]; //store the total campaign score, ignore index 0
new roundScores[3];    //store the round score, ignore index 0
new Handle:mapScores = INVALID_HANDLE;

new mapCounter;
new bool:skippingLevel;
new bool:swapScoreBeginningLevel;

new bool:roundCounterReset = false;

new bool:clearedScores = false;
new bool:roundRestarting = false;

new bool:campaignScoresSwapped;

/* Current Mission */
new bool:pendingNewMission;
new String:nextMap[128];

/* Team Placement */
new Handle:teamPlacementTrie = INVALID_HANDLE; //remember what teams to place after map change
new teamPlacementArray[256];  //after client connects, try to place him to this team
new teamPlacementAttempts[256]; //how many times we attempt and fail to place a person
new Round1Score,Round2Score,Round1SurAlive,Round2SurAlive;
new Float:Round1ScorePercent,Float:Round2ScorePercent;
new bool:Round1WipedOut,bool:Round2WipedOut;
static bool:ClientHasDown[MAXPLAYERS + 1];

static		bool:IsSecondRound,bool:RoundEnding;
static const String:CVAR_TEMP_HEALTH_DECAY[]				= "pain_pills_decay_rate";
static Handle:cvarTempHealthDecay							= INVALID_HANDLE;
static Float:MapVersusDifficulty = 0.0;
static survivor_progress;
static String:previousmap[128];

//convar
new Handle:cvarTeamSwapping = INVALID_HANDLE;
new Handle:g_hPillScore = INVALID_HANDLE;
new Handle:g_hKitScores = INVALID_HANDLE;
new g_iPillScore;
new g_iKitScores;

enum TeamSwappingType
{
	HighestScoreSurvivorFirst, /* same as 1.0.1.0+, default */
	HighestScoreInfectedFirst, /* reverse of the above */
	SwapNever,                 /* classic, never swap teams */
	SwapEveryMap,              /* swap teams every map */
	SwapOnThirdMap,	           /* swap teams on 3, CAL style */
	HighestScoreSurvivorFirstButFin /* valve swap, on finale highest score goes infected first */
};

#if SCORE_DEBUG
new bool:swapTeamsOverride;
#endif
native IsInReady();

Menu hVote = null;
int Votey = 0, Voten = 0;
int score1, score2;
#define VOTE_NO "no"
#define VOTE_YES "yes"
native void ClientVoteMenuSet(client,trueorfalse);//from votes3

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	
	if( test != Engine_Left4Dead )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1.");
		return APLRes_SilentFailure;
	}
	
	CreateNative("Score_GetTeamCampaignScore", Native_GetTeamCampaignScore);
	return APLRes_Success;
}

public OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("Roto2-AZ_mod.phrases");	

	RegConsoleCmd("sm_getscore", Command_GetTeamScore, "sm_getscore <team> <0|1>");
#if SCORE_DEBUG
	RegConsoleCmd("sm_clearscore", Command_ClearTeamScores);
	
	RegConsoleCmd("sm_placement", Command_PrintPlacement);
	RegConsoleCmd("sm_changeteam", Command_ChangeTeam);

	RegAdminCmd("sm_swapnext", Command_SwapNext, ADMFLAG_BAN, "sm_swapnext - swap the players between both teams");
#endif

    /*
	 * Commands
	 */
	RegServerCmd("changelevel", Command_Changelevel);
	RegConsoleCmd("sm_printscores", Command_PrintScores, "sm_printscores - print up a list of round/campaign scores");
	RegConsoleCmd("sm_printscore", Command_PrintScores, "sm_printscore - print up a list of round/campaign scores");
	RegConsoleCmd("sm_ps", Command_PrintScores, "sm_ps");
	RegConsoleCmd("sm_scores", Command_PrintScores, "sm_scores - print up a list of round/campaign scores");
	RegConsoleCmd("sm_score", Command_PrintScores, "sm_score - print up a list of round/campaign scores");
	RegConsoleCmd("sm_bonus", Command_Health, "sm_s - bring up a list of round/campaign scores");
	RegConsoleCmd("sm_health", Command_Health, "sm_s - bring up a list of round/campaign scores");
	
	RegAdminCmd("sm_swap", Command_Swap, ADMFLAG_BAN, "sm_swap <player1> [player2] ... [playerN] - swap all listed players to opposite teams");
	RegAdminCmd("sm_swapto", Command_SwapTo, ADMFLAG_BAN, "sm_swapto <player1> [player2] ... [playerN] <teamnum> - swap all listed players to <teamnum> (1,2, or 3)");
	RegAdminCmd("sm_swapteams", Command_SwapTeams, ADMFLAG_BAN, "sm_swapteams2 - swap the players between both teams");
	RegAdminCmd("sm_swapscores", Command_SwapScores, ADMFLAG_BAN, "sm_swapscores - swap the score between the first and second team");
	RegAdminCmd("sm_resetscores", Command_ResetScores, ADMFLAG_BAN, "sm_resetscores - reset the currently tracked campaign/map scores");
	RegAdminCmd("sm_swapmenu", Command_SwapMenu, ADMFLAG_BAN, "sm_swapmenu - bring up a swap players menu");
	RegConsoleCmd("sm_setscores", Command_SetCampaignScores, "sm_setscores <survs> <inf>");
	
	/*
	* Cvars
	*/
	CreateConVar("l4d_team_manager_ver", SCORE_VERSION, "Version of the score/team manager plugin.", FCVAR_SPONLY|FCVAR_NOTIFY);
	cvarTeamSwapping = CreateConVar("l4d_team_order", "0", 
			"0 - highest score goes survivor first, 1 - highest score goes infected first, 2 - never swap teams, 3 - swap teams every map, 4 - swap teams on the 3rd map, 5 - same as 0 except on finale highest score goes infected first", 
			FCVAR_SPONLY|FCVAR_NOTIFY
	);
	
	g_hPillScore = 	CreateConVar("l4d_score_healthbounus_pill", "15", "Heath bounus each pill. (0=off)", FCVAR_SPONLY|FCVAR_NOTIFY);
	g_iPillScore = GetConVarInt(g_hPillScore);
	HookConVarChange(g_hPillScore, ConVarChange_Cvars);
	
	g_hKitScores = 	CreateConVar("l4d_score_healthbounus_kit", "25", "Heath bounus each kit. (0=off)", FCVAR_SPONLY|FCVAR_NOTIFY);
	g_iKitScores = GetConVarInt(g_hKitScores);
	HookConVarChange(g_hKitScores, ConVarChange_Cvars)
	/*
	 * ADT Handles
	 */
	teamPlacementTrie = CreateTrie();
	if(teamPlacementTrie == INVALID_HANDLE)
	{
		LogError("Could not create the team placement trie! FATAL ERROR");
	}
	
	mapScores = CreateArray(2);
	if(mapScores == INVALID_HANDLE)
	{
		LogError("Could not create the map scores array! FATAL ERROR");
	}
	
	/*
	* Events
	*/
	
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd,EventHookMode_Pre);
	HookEvent("player_team", Event_PlayerTeam);
	HookEvent("heal_success", Event_heal_success);//治療包治療成功
	HookEvent("player_hurt_concise", Event_HurtConcise, EventHookMode_Post);
	HookEvent("player_bot_replace", OnBotSwap);
	HookEvent("bot_player_replace", OnBotSwap);
	HookEvent("player_spawn", OnPlayerSpawn);
	
	DebugPrintToAll("Map counter = %d", mapCounter);
	cvarTempHealthDecay =	FindConVar(CVAR_TEMP_HEALTH_DECAY);
	
	strcopy(previousmap, sizeof(previousmap), "");
	
	CreateTimer(5.0, PROGRESS, _, TIMER_REPEAT);
}

public Native_GetTeamCampaignScore(Handle:plugin, numParams)
{
	new team = GetNativeCell(1);
	return campaignScores[CurrentToLogicalTeam(team)];
}

public Action:PROGRESS(Handle:timer) 
{
	CheckSurvivorProgress();
}

public OnPluginEnd()
{
	CloseHandle(teamPlacementTrie);
	CloseHandle(mapScores);
}
public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	survivor_progress = 25;
	
	for(new i = 1; i <= MaxClients; i++) ClientHasDown[i] = false;	
	RoundEnding = false;
	/* sometimes round_start is invoked before OnMapStart */
	if(!roundCounterReset)
	{
		GetRoundCounter(/*increment*/false, /*reset*/true);
	}
	
	new roundCounter;
	//dont increment the round if round was restarted
	if(roundRestarting)
	{
		roundRestarting = false;
		roundCounter = GetRoundCounter();
	}
	else
	{
		roundCounter = GetRoundCounter(/*increment*/true);
	}
	
	DebugPrintToAll("Round %d started, scores: A: %d, B: %d", roundCounter, GetTeamRoundScore(SCORE_TEAM_A), GetTeamRoundScore(SCORE_TEAM_B));	
	if(roundCounter == 2)
		IsSecondRound = true;
	
	DetectScoresSwappedDelayed();
}

public Action:PrintRoundScore(Handle:timer,any:surdead)
{
	new surplayer = GetTeamMaxHumans(L4D_TEAM_SURVIVORS);
	if(surdead == surplayer)//wiped out 
		if(IsSecondRound)
			Round2WipedOut = true;
		else
			Round1WipedOut = true;
	
	new logical_team = CurrentToLogicalTeam(L4D_TEAM_SURVIVORS);
	if(IsSecondRound)
	{
		Round2Score = GetTeamRoundScore(logical_team);
		Round2ScorePercent = CalculateScorePercent(float(Round2Score));
		Round2SurAlive = surplayer-surdead;
	}
	else
	{
		Round1Score = GetTeamRoundScore(logical_team);
		Round1ScorePercent = CalculateScorePercent(float(Round1Score));
		Round1SurAlive = surplayer-surdead;
	}
		
	PrintGetNowScores(0,true);
}

public Action:Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(RoundEnding) return;
	RoundEnding = true;
	
	new surdead;
	new surplayer = GetTeamMaxHumans(L4D_TEAM_SURVIVORS);
	for(new i=1; i <= MaxClients; i++){
		if(IsSurvivor(i))
			if(!IsPlayerAlive(i)||IsIncapacitated(i)||GetEntProp(i, Prop_Send, "m_isHangingFromLedge"))
				surdead++;
	}
	

	if(surdead == surplayer)//not wiped out 
	{
		CreateTimer(4.0,PrintRoundScore,surdead);
	}
	else
	{
		surdead = 0;
		new HealthB,tempHealthB,pillB,Ent;
		for (new j = 1; j <= MaxClients; j++)
		{
			if (IsSurvivor(j))
			{
				HealthB = tempHealthB = pillB = 0;
				if(IsPlayerAlive(j)){
					if(!IsIncapacitated(j) && !GetEntProp(j, Prop_Send, "m_isHangingFromLedge"))
					{
						HealthB = GetHardHealth(j)/2;
						tempHealthB = RoundToNearest(GetAccurateTempHealth(j)/4);
					}
					Ent = GetPlayerWeaponSlot(j, 4); if (Ent != -1) pillB += g_iPillScore;
					Ent = GetPlayerWeaponSlot(j, 3); if (Ent != -1) pillB += g_iKitScores;
				}
				else
					surdead++;
					
				L4DDirect_SetSurvivorHealthBonus(j,HealthB+tempHealthB+pillB,false);
			}
		}
		L4DDirect_RecomputeTeamScores();//如果全部玩家死亡不會計算此行
		CreateTimer(4.0,PrintRoundScore,surdead);
	}
	

	new roundCounter = GetRoundCounter();
	DebugPrintToAll("Round %d end, scores: A: %d, B: %d", roundCounter, GetTeamRoundScore(SCORE_TEAM_A), GetTeamRoundScore(SCORE_TEAM_B));	

	if(roundRestarting)
		return;

	
	/*
	* Update Round + Campaign Scores
	*/
	
	new logical_team = CurrentToLogicalTeam(L4D_TEAM_SURVIVORS);
	new score = GetTeamRoundScore(logical_team);
	new oldScore = roundScores[logical_team];
	
	//round_end gets called twice, so its ok if its set already
	if(oldScore != -1)
	{
		DebugPrintToAll("Tried to set team score at the end of round %d to %d, but it was already set", roundCounter, score);
	}
	else
	{
		DebugPrintToAll("Updated team campaign/round scores");
		campaignScores[logical_team] += score;
		roundScores[logical_team] = score;
	}
	
	/*
	* when we get 'newer' team scores
	* then update our campaign scores with the newer scores
	*/
	/*
	new scoreA = GetTeamRoundScore(SCORE_TEAM_A);
	new scoreB = GetTeamRoundScore(SCORE_TEAM_B);
	
	new oldScoreA = roundScores[SCORE_TEAM_A];
	new oldScoreB = roundScores[SCORE_TEAM_B];
	
	if(scoreA != -1)
	{
		if(oldScoreA != -1)
		{
			campaignScores[SCORE_TEAM_A] -= oldScoreA;
		}
		campaignScores[SCORE_TEAM_A] += scoreA;
		roundScores[SCORE_TEAM_A] = scoreA;
	}
	
	if(scoreB != -1)
	{
		if(oldScoreB != -1)
		{
			campaignScores[SCORE_TEAM_B] -= oldScoreB;
		}
		campaignScores[SCORE_TEAM_B] += scoreB;
		roundScores[SCORE_TEAM_B] = scoreB;
	}*/
	

	
	//figure out what to put the next map teams with
	//before all the clients are actually disconnected
	
	if(!IsFirstRound())
	{
		#if !SCORE_DEBUG || SCORE_CAMPAIGN_OVERRIDE
			L4D_OnSetCampaignScores(campaignScores[SCORE_TEAM_A], campaignScores[SCORE_TEAM_B]);
		
			DebugPrintToAll("Updated campaign scores, A:%d, B:%d", campaignScores[SCORE_TEAM_A], campaignScores[SCORE_TEAM_B]);
		#endif
		
		#if SCORE_DEBUG
			if(!swapTeamsOverride && !SCORE_TEAM_PLACEMENT_OVERRIDE)
		#endif
			CalculateNextMapTeamPlacement();
		#if SCORE_DEBUG
			DebugPrintToAll("Skipping next map team placement, as its overridden");
		#endif

	}
}

public Action:Command_ResetScores(client, args)
{
	if(!IsInReady())
	{
		ReplyToCommand(client, "ResetScores only allowed during ready-up");
		return Plugin_Handled;
	}
	ResetCampaignScores();
	ResetRoundScores();
	
	CPrintToChatAll("[SM] %t","The scores have been reset.");	
	return Plugin_Handled;
}

public Action:Command_SwapTeams(client, args)
{
	CPrintToChatAll("[SM] %t","ReadyPlugin_33");
	
	new i;
	for(i = 1; i < L4D_MAXCLIENTS_PLUS1; i++)
	{
		if(IsClientInGameHuman(i) && GetClientTeam(i) != L4D_TEAM_SPECTATE)
		{
			teamPlacementArray[i] = GetOppositeClientTeam(i);
		}
	}
	
	TryTeamPlacementDelayed();
	
	return Plugin_Handled;
}


public Action:Command_Swap(client, args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_swap <player1> [player2] ... [playerN] - %T","l4dscores1",client);
		return Plugin_Handled;
	}
	
	new player_id;

	new String:player[64];
	
	for(new i = 0; i < args; i++)
	{
		GetCmdArg(i+1, player, sizeof(player));
		player_id = FindTarget(client, player, true /*nobots*/, false /*immunity*/);
		
		if(player_id == -1)
			continue;
		
		new team = GetOppositeClientTeam(player_id);
		teamPlacementArray[player_id] = team;
		CPrintToChatAll("[SM] %N %t", player_id,"l4dscores2", L4D_TEAM_NAME(team));
	}
	
	TryTeamPlacement();
	
	return Plugin_Handled;
}


public Action:Command_SwapTo(client, args)
{
	if (args < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_swapto <player1> [player2] ... [playerN] <teamnum> - %T","l4dscores3",client);
		return Plugin_Handled;
	}
	
	new team;
	new String:teamStr[64];
	GetCmdArg(args, teamStr, sizeof(teamStr))
	team = StringToInt(teamStr);
	if(0>=team||team>=4)
	{
		ReplyToCommand(client, "[SM] %T","l4dscores4",client, teamStr);
		return Plugin_Handled;
	}
	
	new player_id;

	new String:player[64];
	
	for(new i = 0; i < args - 1; i++)
	{
		GetCmdArg(i+1, player, sizeof(player));
		player_id = FindTarget(client, player, true /*nobots*/, false /*immunity*/);
		
		if(player_id == -1)
			continue;
		
		teamPlacementArray[player_id] = team;
		CPrintToChatAll("[SM] %N %t", player_id,"l4dscores2", L4D_TEAM_NAME(team));
	}
	
	TryTeamPlacement();
	
	return Plugin_Handled;
}

public Action:Command_SwapScores(client, args)
{
	SwapScores();
	
	CPrintToChatAll("[SM] %t","The scores have been swapped.");
	return Plugin_Handled;
}
/*
 * This is called when a new "mission" has started
 * (by us)
 */
OnNewMission()
{
	DebugPrintToAll("New mission detected.");
	
	ResetCampaignScores();
	
	//game treats the scores as unswapped once again
	if(!DetectScoresSwapped())
		campaignScoresSwapped = false;
	
	pendingNewMission = false;
}

/**
 * @brief Called whenever CTerrorGameRules::SetCampaignScores(int,int) is invoked
 * @remarks The campaign scores are updated after the 2nd round is completed
 *
 * @param scoreA		score of logical team A
 * @param scoreB		score of logical team B
 *
 * @return				Plugin_Handled to block campaign scores from being set, Plugin_Continue otherwise.
 */
public Action L4D_OnSetCampaignScores(int &scoreA, int &scoreB)
{
	#if SCORE_DEBUG
		CPrintToChatAll("OnSetCampaignScores(%d,%d)", scoreA, scoreB);
	#endif
	return Plugin_Continue;
}

/**
 * @brief Called whenever CTerrorGameRules::ClearTeamScores(bool) is invoked
 * @remarks 	This resets the map score at the beginning of a map, and by checking
 *			the campaign scores on a small timer you can see if they were reset as well.
 *
 * @param newCampaign	if true then this is a new campaign, if false a new chapter. Not used for L4D1.
 *
 * @return				Plugin_Handled to block scores from being cleared, Plugin_Continue otherwise. Does not block reset in L4D1.
 */
public Action L4D_OnClearTeamScores(bool newCampaign)
{
	//LogMessage("OnClearTeamScores()"); 
	
	/*
	* this function gets called twice at the beginning of each map or restart the same level
	* skip it the second time
	*/
	if(clearedScores)
	{
		clearedScores = false;
	}
	else
	{
		clearedScores = true;
		
		CreateTimer(0.1, Timer_GetCampaignScores, _);
		
		ResetRoundScores();
	}
	
	return Plugin_Continue;
}

public Action:Timer_GetCampaignScores(Handle:timer)
{
	if(L4D_IsFirstMapInScenario()) //only new map
	{
		new scoreA, scoreB;
		
		scoreA = L4D2Direct_GetVSCampaignScore(0);
		scoreB = L4D2Direct_GetVSCampaignScore(1);
		DebugPrintToAll("Campaign scores are A=%d, B=%d", scoreA, scoreB);
		
		//a mutual score of 0 can only mean one thing.. the campaign scores got reset
		if(scoreA == 0 && scoreB == 0)
		{
			OnNewMission();
		}
	}
}

public OnReadyRoundRestarted()
{
	DebugPrintToAll("FORWARD: OnReadyRoundRestarted triggered");
	roundRestarting = true;
}

public OnMapStart()
{	
	PrecacheSound("ui/holdout_teamrec.wav");

	if(L4D_IsFirstMapInScenario())
	{
		GetCurrentMap(previousmap, sizeof(previousmap));
	}
	else
	{
		decl String:currentmap[128];
		GetCurrentMap(currentmap, sizeof(currentmap));
		if(StrEqual(currentmap, previousmap))//相同的一關
		{
			mapCounter--;
			if(Round2Score&&IsSecondRound)
			{
				campaignScores[CurrentToLogicalTeam(L4D_TEAM_SURVIVORS)] -= Round1Score;
				campaignScores[CurrentToLogicalTeam(L4D_TEAM_INFECTED)] -= Round2Score;
			}
			else if(Round1Score&&IsSecondRound)
			{
				campaignScores[CurrentToLogicalTeam(L4D_TEAM_SURVIVORS)] -= Round1Score;
			}
			else if(Round1Score)
			{
				campaignScores[CurrentToLogicalTeam(L4D_TEAM_SURVIVORS)] -= Round1Score;
			}
			new size = GetArraySize(mapScores);
			if(size>0)
				RemoveFromArray(mapScores, size-1);
		}
		strcopy(previousmap, sizeof(previousmap),currentmap);
	}
	
	Round1Score = 0;
	Round2Score = 0;
	Round1ScorePercent = 0.0;
	Round2ScorePercent = 0.0;
	Round1WipedOut = false;
	Round2WipedOut = false;
	IsSecondRound = false;
	
	// Load config
	new Handle:hFile = OpenConfig(false);
	if( hFile == INVALID_HANDLE )
		return;
	// Check for current map in the config
	decl String:sMap[64];
	GetCurrentMap(sMap, 64);

	if( !KvJumpToKey(hFile, sMap) )
	{
		CloseHandle(hFile);
		MapVersusDifficulty = 0.0;
		return;
	}
	MapVersusDifficulty = KvGetFloat(hFile, "VersusModifier", 1.0);
	#if SCORE_DEBUG
		LogMessage("%s: %f",sMap,MapVersusDifficulty);
	#endif
	CloseHandle(hFile);
	
	if(!roundCounterReset)
		GetRoundCounter(/*increment*/false, /*reset*/true);
	
	#if SCORE_DEBUG
	swapTeamsOverride = false;
	#endif
	
	new String:mapname[64];
	GetCurrentMap(mapname, sizeof(mapname));
	
	//if we are skipping the level
	//do not skip it if we already ended up on it
	if(skippingLevel && !StrEqual(mapname, nextMap, false))
	{
		//we should be skipping to this map lets get to it
		CreateTimer(SCORE_DELAY_SWITCH_MAP, Timer_SwitchToNextMap, _);
		
		return;
	}
	
	if(pendingNewMission)
	{
		OnNewMission();
	}
	else
	{
		mapCounter++;
	}
	
	skippingLevel = false;
	nextMap[0] = 0;
	
	ResetRoundScores();
	
	if(swapScoreBeginningLevel)
	{
		SwapScores();
	}

	VoteMenuClose();
}

Handle:OpenConfig(bool:create = true)
{
	// Create config if it does not exist
	decl String:sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "%s", CONFIG_MAPINFO);
	if( !FileExists(sPath) )
	{
		if( create == false )
			return INVALID_HANDLE;

		new Handle:hCfg = OpenFile(sPath, "w");
		WriteFileLine(hCfg, "");
		CloseHandle(hCfg);
	}

	// Open the jukebox config
	new Handle:hFile = CreateKeyValues("MapInfo");
	if( !FileToKeyValues(hFile, sPath) )
	{
		CloseHandle(hFile);
		return INVALID_HANDLE;
	}

	return hFile;
}

public Action:Timer_SwitchToNextMap(Handle:timer)
{
	ServerCommand("changelevel %s", nextMap);
}


public OnMapEnd()
{
	roundCounterReset = false;
	
	if(skippingLevel)
	{
		skippingLevel = false;
		return;
	}
	
	/* leaving a map right after the scores were reset */
	if(mapCounter == 1 
		&& roundScores[SCORE_TEAM_A] == -1 && roundScores[SCORE_TEAM_B] == -1)
	{
		return;
	}
		
	/*
	* Update the map scores
	*/
	new scores[2];
	scores[0] = roundScores[SCORE_TEAM_A];
	scores[1] = roundScores[SCORE_TEAM_B];
	PushArrayArray(mapScores, scores);
	
	/*
	* Is the game about to automatically swap teams on us?
	*/
	new bool:pendingSwapScores = false;
	if(GetTeamCampaignScore(L4D_TEAM_SURVIVORS) > GetTeamCampaignScore(L4D_TEAM_INFECTED))
	{
		pendingSwapScores = true;
	}
	
	/*
	* Try to figure out if we should swap scores 
	* at the beginning of the next map
	*/
	new TeamSwappingType:swapKind = TeamSwappingType:GetConVarInt(cvarTeamSwapping);
	switch(swapKind)
	{
		case SwapEveryMap:
		{
			swapScoreBeginningLevel = true;
		}
		case SwapOnThirdMap:
		{
			swapScoreBeginningLevel = mapCounter == 3;
		}
		case HighestScoreSurvivorFirst:
		{
			swapScoreBeginningLevel = pendingSwapScores;
		}
		case HighestScoreInfectedFirst:
		{
			swapScoreBeginningLevel = !pendingSwapScores;
		}
		case HighestScoreSurvivorFirstButFin:
		{
			//last level: highest score goes infected first
			//all previous levels: highest score goes survivor first
			swapScoreBeginningLevel = (mapCounter == 5) ? !pendingSwapScores : pendingSwapScores;
		}
		default:
		{
			swapScoreBeginningLevel = false;
		}
	}

	/*
	* Lastly we make it look internally like we're in classic mode
	* => This makes it so Team A is always Survivors first
	* 		and Team B is always infected first
	*/
	
	if(pendingSwapScores)
	{
		SwapScores();
	}

	campaignScoresSwapped = pendingSwapScores;
	
	//schedule a pending skip level to the next map
	if(strlen(nextMap) > 0 && IsMapValid(nextMap))
	{
		skippingLevel = true;
	}
}

CalculateNextMapTeamPlacement()
{
	/*
	* Is the game about to automatically swap teams on us?
	*/
	new bool:pendingSwapScores = false;
	if(GetTeamCampaignScore(L4D_TEAM_SURVIVORS) > GetTeamCampaignScore(L4D_TEAM_INFECTED))
	{
		pendingSwapScores = true;
	}

	/*
	* We place everyone on whatever team they should be on
	* according to the set swapping type
	*/
	ClearTeamPlacement();
	
	new String:authid[128];
	new i;
	
	new team;
	for(i = 1; i < L4D_MAXCLIENTS_PLUS1; i++) 
	{
		if(IsClientInGameHuman(i)) 
		{
			GetClientAuthId(i, AuthId_Steam2, authid, sizeof(authid));
			team = GetClientTeamForNextMap(i, pendingSwapScores);
			
			DebugPrintToAll("Next map will place %N to %d", i, team);
			SetTrieValue(teamPlacementTrie, authid, team);
		}
	}	
}

/* 
* **************
* TEAM PLACEMENT (beginning of map)
* **************
*/

public OnClientAuthorized(client, const String:authid[])
{
	//DebugPrintToAll("Client %s authorized", authid);
	
	if(skippingLevel)
		return;
	
	new team;
	
	if(GetTrieValue(teamPlacementTrie, authid, team))
	{
		teamPlacementArray[client] = team;
		RemoveFromTrie(teamPlacementTrie, authid);
		
		DebugPrintToAll("Will place %d/%s to team %d", client, authid, team);
		
		TryTeamPlacementDelayed();
	}
}

public OnClientDisconnect(client)
{

	if(skippingLevel)
		return;
	
	TryTeamPlacementDelayed();
}

DetectScoresSwappedDelayed()
{
	CreateTimer(SCORE_DELAY_SCORE_SWAPPED, Timer_DetectScoresSwapped);
}

public Action:Timer_DetectScoresSwapped(Handle:timer)
{
	DetectScoresSwapped();
}
/*
* Try to detect if the campaign scores have been swapped
* by the game itself.
*/
bool:DetectScoresSwapped()
{
	if(IsFirstRound())
	{
		new scoreA = GetTeamRoundScore(SCORE_TEAM_A);
		new scoreB = GetTeamRoundScore(SCORE_TEAM_B);
		
		if(scoreA == -1 || scoreB == -1)
		{
			campaignScoresSwapped = (scoreA == -1);
			
			DebugPrintToAll("DetectCampaignScoresSwapped : success, swap = %d", campaignScoresSwapped);
			return true;
		}		
	}
	
	DebugPrintToAll("DetectCampaignScoresSwapped : failure, not could detect");
	return false;
}

/*
* End of Campaign Scores Swapped? Detection
*/


public Action:Event_PlayerTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	/*
	new userid = GetEventInt(event, "userid");
	new team = GetEventInt(event, "team");
	
	new client = GetClientOfUserId(userid);
	
	if(!client)
		DebugPrintToAll("------Player #%d changed team to %d.", userid, team);
	else
		DebugPrintToAll("------ %N (%d) changed team to %d", client, client, team);
	*/

	TryTeamPlacementDelayed();
}

/*
* Do a delayed "team placement"
* 
* This way all the pending team changes will go through instantly
* and we don't end up in TryTeamPlacement again before then
*/
new bool:pendingTryTeamPlacement;
TryTeamPlacementDelayed()
{
	if(!pendingTryTeamPlacement)
	{
		CreateTimer(SCORE_DELAY_PLACEMENT, Timer_TryTeamPlacement);	
		pendingTryTeamPlacement = true;
	}
}

public Action:Timer_TryTeamPlacement(Handle:timer)
{
	TryTeamPlacement();
	pendingTryTeamPlacement = false;
}

/*
* Try to place people on the right teams
* after some kind of event happens that allows someone to be moved.
* 
* Should only be called indirectly by TryTeamPlacementDelayed()
*/
TryTeamPlacement()
{
	/*
	* Calculate how many free slots a team has
	*/
	new free_slots[4];
	
	free_slots[L4D_TEAM_SPECTATE] = GetTeamMaxHumans(L4D_TEAM_SPECTATE);
	free_slots[L4D_TEAM_SURVIVORS] = GetTeamMaxHumans(L4D_TEAM_SURVIVORS);
	free_slots[L4D_TEAM_INFECTED] = GetTeamMaxHumans(L4D_TEAM_INFECTED);	
	
	free_slots[L4D_TEAM_SURVIVORS] -= GetTeamHumanCount(L4D_TEAM_SURVIVORS);
	free_slots[L4D_TEAM_INFECTED] -= GetTeamHumanCount(L4D_TEAM_INFECTED);
	
	DebugPrintToAll("TP: Trying to do team placement (free slots %d/%d)...", free_slots[L4D_TEAM_SURVIVORS], free_slots[L4D_TEAM_INFECTED]);
		
	/*
	* Try to place people on the teams they should be on.
	*/
	new i;
	for(i = 1; i < L4D_MAXCLIENTS_PLUS1; i++) 
	{
		if(IsClientInGameHuman(i)) 
		{
			new team = teamPlacementArray[i];
			
			//client does not need to be placed? then skip
			if(!team)
			{
				continue;
			}
			
			new old_team = GetClientTeam(i);
			
			//client is already on the right team
			if(team == old_team)
			{
				teamPlacementArray[i] = 0;
				teamPlacementAttempts[i] = 0;
				
				DebugPrintToAll("TP: %N is already on correct team (%d)", i, team);
			}
			//there's still room to place him on the right team
			else if (free_slots[team] > 0)
			{
				ChangePlayerTeamDelayed(i, team);
				DebugPrintToAll("TP: Moving %N to %d soon", i, team);
				
				free_slots[team]--;
				free_slots[old_team]++;
			}
			/*
			* no room to place him on the right team,
			* so lets just move this person to spectate
			* in anticipation of being to move him later
			*/
			else
			{
				DebugPrintToAll("TP: %d attempts to move %N to team %d", teamPlacementAttempts[i], i, team);
				
				/*
				* don't keep playing in an infinite join spectator loop,
				* let him join another team if moving him fails
				*/
				if(teamPlacementAttempts[i] > 0)
				{
					DebugPrintToAll("TP: Cannot move %N onto %d, team full", i, team);
					
					//client joined a team after he was moved to spec temporarily
					if(GetClientTeam(i) != L4D_TEAM_SPECTATE)
					{
						DebugPrintToAll("TP: %N has willfully moved onto %d, cancelling placement", i, GetClientTeam(i));
						teamPlacementArray[i] = 0;
						teamPlacementAttempts[i] = 0;
					}
				}
				/*
				* place him to spectator so room on the previous team is available
				*/
				else
				{
					free_slots[L4D_TEAM_SPECTATE]--;
					free_slots[old_team]++;
					
					DebugPrintToAll("TP: Moved %N to spectator, as %d has no room", i, team);
					
					ChangePlayerTeamDelayed(i, L4D_TEAM_SPECTATE);
					
					teamPlacementAttempts[i]++;
				}
			}
		}
		//the player is a bot, or disconnected, etc.
		else 
		{
			if(!IsClientConnected(i) || IsFakeClient(i)) 
			{
				if(teamPlacementArray[i])
					DebugPrintToAll("TP: Defaultly removing %d from placement consideration", i);
				
				teamPlacementArray[i] = 0;
				teamPlacementAttempts[i] = 0;
			}			
		}
	}
	
	/* If somehow all 8 players are connected and on opposite teams
	*  then unfortunately this function will not work.
	*  but of course this should not be called in that case,
	*  instead swapteams can be used
	*/
}

ClearTeamPlacement()
{
	new i;
	for(i = 1; i < L4D_MAXCLIENTS_PLUS1; i++) 
	{
		teamPlacementArray[i] = 0;
		teamPlacementAttempts[i] = 0;
	}
	
	ClearTrie(teamPlacementTrie);
}


/*
* When we are at the end of a map,
* we will need to swap clients around based on the swapping type
* 
* Figure out which team the client will go on next map.
*/
GetClientTeamForNextMap(client, bool:pendingSwapScores = false)
{
	new bool:isThirdMap = mapCounter == 3;
	
	new TeamSwappingType:swapKind = TeamSwappingType:GetConVarInt(cvarTeamSwapping);
	new team;
	
	//same type of logic except on the finale, in which we flip it
	if(swapKind == HighestScoreSurvivorFirstButFin)
	{
		swapKind = HighestScoreInfectedFirst;
		
		if(mapCounter == 5)
		{
			pendingSwapScores = !pendingSwapScores;
		}
	}
	
	switch(GetClientTeam(client))
	{
		case L4D_TEAM_INFECTED:
		{
			//default, dont swap teams
			team = L4D_TEAM_SURVIVORS;
			
			switch(swapKind)
			{
				/*case SwapNever:
				{
					break;
				}*/
				case SwapEveryMap:
				{
					team = L4D_TEAM_INFECTED;
				}
				case SwapOnThirdMap:
				{
					team = isThirdMap ? L4D_TEAM_INFECTED : L4D_TEAM_SURVIVORS;
				}
				case HighestScoreSurvivorFirst:
				{
					team = pendingSwapScores ? L4D_TEAM_INFECTED : L4D_TEAM_SURVIVORS;
				}
				case HighestScoreInfectedFirst:
				{
					team = pendingSwapScores ? L4D_TEAM_SURVIVORS : L4D_TEAM_INFECTED;
				}
			}
		}
		
		case L4D_TEAM_SURVIVORS:
		{
			//default, dont swap teams
			team = L4D_TEAM_INFECTED;
			
			switch(swapKind)
			{
				case SwapNever:
				{
				}
				case SwapEveryMap:
				{
					team = L4D_TEAM_SURVIVORS;
				}
				case SwapOnThirdMap:
				{
					team = isThirdMap ? L4D_TEAM_SURVIVORS : L4D_TEAM_INFECTED;
				}
				case HighestScoreSurvivorFirst:
				{
					team = pendingSwapScores ? L4D_TEAM_SURVIVORS : L4D_TEAM_INFECTED;
				}
				case HighestScoreInfectedFirst:
				{
					team = pendingSwapScores ? L4D_TEAM_INFECTED : L4D_TEAM_SURVIVORS;
				}
			}
		}
		
		default:
		{
			team = L4D_TEAM_SPECTATE;
		}
	}
	
	return team;
}

SwapScores()
{
	new tmp;
	
	tmp = campaignScores[SCORE_TEAM_A];
	campaignScores[SCORE_TEAM_A] = campaignScores[SCORE_TEAM_B];
	campaignScores[SCORE_TEAM_B] = tmp;
	
	tmp = roundScores[SCORE_TEAM_A];
	roundScores[SCORE_TEAM_A] = roundScores[SCORE_TEAM_B];
	roundScores[SCORE_TEAM_B] = tmp;
	
	new i, size = GetArraySize(mapScores);
	for(i = 0; i < size; i++)
	{
		new scores[2];
		GetArrayArray(mapScores, i, scores);
		
		tmp = scores[0];
		scores[0] = scores[1];
		scores[1] = tmp;
		
		SetArrayArray(mapScores, i, scores);
	}
	
	DebugPrintToAll("Swapped campaign scores, now A:%d, B:%d", campaignScores[SCORE_TEAM_A], campaignScores[SCORE_TEAM_B]);
}

ResetCampaignScores()
{
	campaignScores[SCORE_TEAM_A] = 0;
	campaignScores[SCORE_TEAM_B] = 0;

	mapCounter = 1;
	ClearArray(mapScores);
	
	//LogMessage("Campaign scores have been reset.");
}

ResetRoundScores()
{
	roundScores[SCORE_TEAM_A] = -1;
	roundScores[SCORE_TEAM_B] = -1;
}

GetTeamCampaignScore(team)
{
	return campaignScores[CurrentToLogicalTeam(team)];
}

//convert SCORE_TEAM_* 
//to team infected or team survivors
stock LogicalToCurrentTeam(logical_team)
{
	if(logical_team != SCORE_TEAM_A && logical_team != SCORE_TEAM_B)
	{
		return 0;
	}
	
	new team;
	
	//first round survivors are "always" team A
	if(IsFirstRound())
	{
		team = logical_team == SCORE_TEAM_A ? 
			L4D_TEAM_SURVIVORS : L4D_TEAM_INFECTED;
	}
	//second round infected are always "team" A
	else
	{
		team = logical_team == SCORE_TEAM_B ? 
			L4D_TEAM_SURVIVORS : L4D_TEAM_INFECTED;
	}
	
	return campaignScoresSwapped ? OppositeCurrentTeam(team) : team;

}

//convert 2 (sur), or 3 (inf)
//to SCORE_TEAM_* necessary to be able to read the scores
CurrentToLogicalTeam(team)
{
	if(team != L4D_TEAM_INFECTED && team != L4D_TEAM_SURVIVORS)
	{
		return 0;
	}
	
	new l;
	
	//first round survivors are "always" team A
	if(IsFirstRound())
	{
		l = team == L4D_TEAM_SURVIVORS ? 
			SCORE_TEAM_A : SCORE_TEAM_B;
	}
	//second round infected are always "team" A
	else
	{
		l = team == L4D_TEAM_INFECTED ? 
			SCORE_TEAM_A : SCORE_TEAM_B;
	}
	
	return campaignScoresSwapped ? OppositeLogicalTeam(l) : l;
}

/*
* ****************
* STOCK FUNCTIONS
* ****************
*/

stock GetTeamRoundScore(logical_team)
{
	return L4D_GetTeamScore(logical_team, SCORE_TYPE_ROUND);	
}

stock bool:IsFirstRound()
{
	//when one team has not played yet, their score is N/A (-1)
/*	return GetTeamRoundScore(SCORE_TEAM_A) == -1
	    || GetTeamRoundScore(SCORE_TEAM_B) == -1; */	
	return (GetRoundCounter() == 1);
}

stock OppositeLogicalTeam(logical_team)
{
	if(logical_team == SCORE_TEAM_A)
		return SCORE_TEAM_B;
	
	else if(logical_team == SCORE_TEAM_B)
		return SCORE_TEAM_A;
	
	else
		return -1;
}

/*
* Return the opposite team of that the client is on
*/
stock GetOppositeClientTeam(client)
{
	return OppositeCurrentTeam(GetClientTeam(client));	
}

stock OppositeCurrentTeam(team)
{
	if(team == L4D_TEAM_INFECTED)
		return L4D_TEAM_SURVIVORS;
	else if(team == L4D_TEAM_SURVIVORS)
		return L4D_TEAM_INFECTED;
	else if(team == L4D_TEAM_SPECTATE)
		return L4D_TEAM_SPECTATE;
	
	else
		return -1;
}

stock ChangePlayerTeamDelayed(client, team)
{
	new Handle:pack;
	
	CreateDataTimer(SCORE_DELAY_TEAM_SWITCH, Timer_ChangePlayerTeam, pack);	
	
	WritePackCell(pack, client);
	WritePackCell(pack, team);
}

public Action:Timer_ChangePlayerTeam(Handle:timer, Handle:pack)
{
	ResetPack(pack);
	
	new client = ReadPackCell(pack);
	new team = ReadPackCell(pack);
	
	ChangePlayerTeam(client, team);
}

stock bool:ChangePlayerTeam(client, team)
{
	if(client == 0 || !IsClientInGame(client)||GetClientTeam(client) == team) return true;
	
	if(team != L4D_TEAM_SURVIVORS)
	{
		//we can always swap to infected or spectator, it has no actual limit
		ChangeClientTeam(client, team);
		return true;
	}
	
	if(GetTeamHumanCount(team) == GetTeamMaxHumans(team))
	{
		DebugPrintToAll("ChangePlayerTeam() : Cannot switch %N to team %d, as team is full");
		return false;
	}
	
	//for survivors its more tricky
	new bot;
	
	for(bot = 1; 
		bot < L4D_MAXCLIENTS_PLUS1 && (!IsClientConnected(bot) || !IsFakeClient(bot) || (GetClientTeam(bot) != L4D_TEAM_SURVIVORS));
		bot++) {}
	
	if(bot == L4D_MAXCLIENTS_PLUS1)
	{
		DebugPrintToAll("Could not find a survivor bot, adding a bot ourselves");
		
		new String:command[] = "sb_add";
		new flags = GetCommandFlags(command);
		SetCommandFlags(command, flags & ~FCVAR_CHEAT);
		
		ServerCommand("sb_add");
		
		SetCommandFlags(command, flags);
		
		DebugPrintToAll("Added a survivor bot, trying again...");
		return false;
	}

	//have to do this to give control of a survivor bot
	L4D_SetHumanSpec(bot, client);
	L4D_TakeOverBot(client);
	
	return true;
}

//client is in-game and not a bot
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
			humans++
		}
	}
	
	return humans;
}

stock GetTeamMaxHumans(team)
{
	if(team == L4D_TEAM_SURVIVORS)
	{
		return GetConVarInt(FindConVar("survivor_limit"));
	}
	else if(team == L4D_TEAM_INFECTED)
	{
		return GetConVarInt(FindConVar("z_max_player_zombies"));
	}
	else if(team == L4D_TEAM_SPECTATE)
	{
		return L4D_MAXCLIENTS;
	}
	
	return -1;
}


/*
* Detect 'rcon changelevel' and print warning messages
*/
public Action:Command_Changelevel(args)
{
	if(args > 0)
	{
		new String:map[128];
		GetCmdArg(1, map, 128);
		
		if(IsMapValid(map) && !skippingLevel)
		{
			DebugPrintToAll("Changelevel detected");
			
			//PrintToServer("If you are using changelevel via RCON, you should be using sm_changemap instead to change maps!");
		}		
	}
	return Plugin_Continue;
}

public Action:Command_Health(client, args)//打這指令的自己才會看到
{
	if(RoundEnding)
		return;
	PrintGetNowScores(client);
}

public Action:Event_HurtConcise(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(IsInReady()) return;
	
	new attacker = GetEventInt(event, "attackerentid");
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	if(attacker ==0 && IsClientConnected(victim) && IsClientInGame(victim) && GetClientTeam(victim) == 2)
	{
		if(GetEntProp(victim, Prop_Send, "m_isHangingFromLedge"))
			 return;
		if(IsIncapacitated(victim)) 
			ClientHasDown[victim] = true;
	}
}

static GetHardHealth(client)
{
	if(GetEntProp(client, Prop_Send, "m_isHangingFromLedge"))
		return 0;
	else if(ClientHasDown[client]==true)
		return 0;
	else
		return GetEntProp(client, Prop_Send, "m_iHealth");
}
static Float:GetAccurateTempHealth(client)
{
	new Float:fHealth = GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
	fHealth -= (GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * GetConVarFloat(cvarTempHealthDecay);
	fHealth = (fHealth < 0.0 )? 0.0 : fHealth;
	
	return fHealth;
}
PrintGetNowScores(client,roundend = false)
{
	new Scores,P,N,HB=0,round,PILLS=0;
	new Float:MD;
	new HealthB,tempHealthB,pillB,Ent;
	if(!roundend){
		for (new j = 1; j <= MaxClients; j++)
		{
			if (IsClientConnected(j) && IsClientInGame(j)&& GetClientTeam(j) == L4D_TEAM_SURVIVORS)
			{
				HealthB = tempHealthB = pillB = 0;
				if(IsPlayerAlive(j)){
					if(!IsIncapacitated(j) && !GetEntProp(j, Prop_Send, "m_isHangingFromLedge"))
					{
						HealthB = GetHardHealth(j)/2;
						tempHealthB = RoundToNearest(GetAccurateTempHealth(j)/4);
					}
					Ent = GetPlayerWeaponSlot(j, 4);if (Ent != -1) pillB += g_iPillScore;
					Ent = GetPlayerWeaponSlot(j, 3);if (Ent != -1) pillB += g_iKitScores;
				}
				#if SCORE_DEBUG
					CPrintToChatAll("%N Pill: %d, Real HB: %d, Fake HB: %d",j,pillB,HealthB,tempHealthB);
				#endif
				HB+=HealthB+tempHealthB;
				PILLS+=pillB;
			}
		}
		P = L4D_GetTeamScore(6, false);
		MD = MapVersusDifficulty;
		N = GetNumberSurvived();
		Scores = RoundToNearest((P+HB+PILLS)*N*MD);//L4D1 對抗分數計算方式 (平均距離+生命加值+藥分)*存活數*地圖難度,(P+HB)*N*MD
		//生命加值計算:floor(實血/4)+floor(虛血/2)
	}
	round = IsSecondRound ? 2 : 1;
	new surplayer = GetTeamMaxHumans(L4D_TEAM_SURVIVORS);
	if(round == 1)
	{
		if(client)
		{
			if(roundend){
				if(Round1WipedOut)
					CPrintToChat(client,"%T %T","l4dscores5",client,round,Round1Score,"wiped out",client);
				else
					CPrintToChat(client,"%T \x01<\x03%.1f%%\x01> [\x05%d\x01/\x05%d\x01]","l4dscores5",client,round,Round1Score,Round1ScorePercent,Round1SurAlive,surplayer);
			}
			else{
				CPrintToChat(client,"%T \x01<\x03%.1f%%\x01>\n\x01[%T: \x03%d%%\x01 | %T: \x03%.0f%%\x01 | %T: \x03%.0f%%\x01 | %T: \x03%d\x01 | %T: \x03%.1f\x01]","l4dscores5",client,round,Scores,CalculateScorePercent((P+HB+PILLS)*N*MD),"AD",client,P,"HB",client,CalculateHBPercent(HB),"Pills",client,CalculatePillsPercent(PILLS),"Alive",client,N,"Map",client,MD+0.005);		
			}
		}
		else
		{
			if(roundend){
				if(Round1WipedOut)
					CPrintToChatAll("%t %t","l4dscores5",round,Round1Score,"wiped out");
				else
					CPrintToChatAll("%t \x01<\x03%.1f%%\x01> [\x05%d\x01/\x05%d\x01]","l4dscores5",round,Round1Score,Round1ScorePercent,Round1SurAlive,surplayer);
			}
			else
			{
				CPrintToChatAll("%t \x01<\x03%.1f%%\x01>\n\x01[%t: \x03%d%%\x01 | %t: \x03%.0f%%\x01 | %t: \x03%.0f%%\x01 | %t: \x03%d\x01 | %t: \x03%.1f\x01]","l4dscores5",round,Scores,CalculateScorePercent((P+HB+PILLS)*N*MD),"AD",P,"HB",CalculateHBPercent(HB),"Pills",CalculatePillsPercent(PILLS),"Alive",N,"Map",MD+0.005);
			}				
		}
	}
	else
	{
		if(client)
		{
			if(Round1WipedOut)
				CPrintToChat(client,"%T %T","l4dscores6",client,Round1Score,"wiped out",client);
			else
				CPrintToChat(client,"%T \x01<\x03%.1f%%\x01> [\x05%d\x01/\x05%d\x01]","l4dscores6",client,Round1Score,Round1ScorePercent,Round1SurAlive,surplayer);
			
			if(roundend){
				if(Round2WipedOut)
					CPrintToChat(client,"\x01R\x04#%d\x01 Scores: \x05%d %T",round,Round2Score,"wiped out",client);
				else
					CPrintToChat(client,"%T \x01<\x03%.1f%%\x01> [\x05%d\x01/\x05%d\x01]","l4dscores5",client,round,Round2Score,Round2ScorePercent,Round2SurAlive,surplayer);
			}
			else
			{
				CPrintToChat(client,"%T \x01<\x03%.1f%%\x01>\n\x01[%T: \x03%d%%\x01 | %T: \x03%.0f%%\x01 | %T: \x03%.0f%%\x01 | %T: \x03%d\x01 | %T: \x03%.1f\x01]","l4dscores5",client,round,Scores,CalculateScorePercent((P+HB+PILLS)*N*MD),"AD",client,P,"HB",client,CalculateHBPercent(HB),"Pills",client,CalculatePillsPercent(PILLS),"Alive",client,N,"Map",client,MD+0.005);		
			}				
		}
		else
		{
			if(Round1WipedOut)
				CPrintToChatAll("%t %t","l4dscores6",Round1Score,"wiped out");
			else
				CPrintToChatAll("%t \x01<\x03%.1f%%\x01> [\x05%d\x01/\x05%d\x01]","l4dscores6",Round1Score,Round1ScorePercent,Round1SurAlive,surplayer);
			
			if(roundend){
				if(Round2WipedOut)
					CPrintToChatAll("%t %t","l4dscores5",round,Round2Score,"wiped out");
				else
					CPrintToChatAll("%t \x01<\x03%.1f%%\x01> [\x05%d\x01/\x05%d\x01]","l4dscores5",round,Round2Score,Round2ScorePercent,Round2SurAlive,surplayer);
			}
			else
			{
				CPrintToChatAll("%t \x01<\x03%.1f%%\x01>\n\x01[%t: \x03%d%%\x01 | %t: \x03%.0f%%\x01 | %t: \x03%.0f%%\x01 | %t: \x03%d\x01 | %t: \x03%.1f\x01]","l4dscores5",round,Scores,CalculateScorePercent((P+HB+PILLS)*N*MD),"AD",P,"HB",CalculateHBPercent(HB),"Pills",CalculatePillsPercent(PILLS),"Alive",N,"Map",MD+0.005);
			}	
		}			
	}
}

Float:CalculateScorePercent(Float:score, Float:maxbonus = -1.0)
{
	if(maxbonus == -1.0)
	{
		new sur = GetTeamMaxHumans(L4D_TEAM_SURVIVORS);
		maxbonus = (100+50*sur+g_iPillScore*sur)*GetTeamMaxHumans(L4D_TEAM_SURVIVORS)*MapVersusDifficulty ;
	}
	return (score / maxbonus) * 100;
}

public GetNumberSurvived()
{
	new N = 0;
	for (new j = 1; j <= MaxClients; j++)\
	{
		if (IsSurvivor(j) && IsPlayerAlive(j))
		{
			N++;
		}
	}
	return N;
}

public Action:Command_PrintScores(client, args)//打這指令的只有自己看到
{
	DebugPrintToAll("Command_PrintScores, mapCounter = %d", mapCounter);
	new i, scores[2], surscore, infscore, scoresSize = GetArraySize(mapScores),surtotalscore,inftotalscore;
	CPrintToChat(client,"\x01[\x05TS\x01] %T","l4dscores7",client);
			
	surtotalscore = inftotalscore = 0;
	for(i = 0; i < scoresSize; i++)
	{
		GetArrayArray(mapScores, i, scores);
		
		surscore = scores[CurrentToLogicalTeam(L4D_TEAM_SURVIVORS)-1];
		infscore = scores[CurrentToLogicalTeam(L4D_TEAM_INFECTED)-1];
		surtotalscore += scores[CurrentToLogicalTeam(L4D_TEAM_SURVIVORS)-1];
		inftotalscore += scores[CurrentToLogicalTeam(L4D_TEAM_INFECTED)-1];
		CPrintToChat(client,"%T\x01: \x05%d\x01/\x04%d","l4dscores8",client, i+1, surscore,infscore);
	}
	/*
	if(surtotalscore == GetTeamCampaignScore(L4D_TEAM_SURVIVORS))
	{
		if(inftotalscore == GetTeamCampaignScore(L4D_TEAM_INFECTED))
		{
			CPrintToChat(client,"%T\x01: \x05None/\x04None","l4dscores8",client,i+1);
		}
		else
		{
			CPrintToChat(client,"%T\x01: \x05None/\x04%d","l4dscores8",client,i+1,GetTeamCampaignScore(L4D_TEAM_INFECTED) - inftotalscore);	
		}	
	}
	else
	{
		if(inftotalscore == GetTeamCampaignScore(L4D_TEAM_INFECTED))
		{
			CPrintToChat(client,"%T\x01: \x05%d/\x04None","l4dscores8",client,i+1,GetTeamCampaignScore(L4D_TEAM_SURVIVORS) - surtotalscore);
		}
		else
		{
			CPrintToChat(client,"%T\x01: \x05%d/\x04%d","l4dscores8",client,i+1,GetTeamCampaignScore(L4D_TEAM_SURVIVORS) - surtotalscore,GetTeamCampaignScore(L4D_TEAM_INFECTED) - inftotalscore);	
		}
	}
	*/
	
	if(roundScores[CurrentToLogicalTeam(L4D_TEAM_SURVIVORS)] == -1)
	{
		if(roundScores[CurrentToLogicalTeam(L4D_TEAM_INFECTED)] == -1)
		{
			CPrintToChat(client,"%T\x01: \x05None/\x04None","l4dscores8",client,i+1);
		}
		else
		{
			inftotalscore += roundScores[CurrentToLogicalTeam(L4D_TEAM_INFECTED)];
			CPrintToChat(client,"%T\x01: \x05None/\x04%d","l4dscores8",client,i+1,roundScores[CurrentToLogicalTeam(L4D_TEAM_INFECTED)]);	
		}	
	}
	else
	{
		if(roundScores[CurrentToLogicalTeam(L4D_TEAM_INFECTED)] == -1)
		{
			surtotalscore += roundScores[CurrentToLogicalTeam(L4D_TEAM_SURVIVORS)];
			CPrintToChat(client,"%T\x01: \x05%d/\x04None","l4dscores8",client,i+1,roundScores[CurrentToLogicalTeam(L4D_TEAM_SURVIVORS)]);
		}
		else
		{
			surtotalscore += roundScores[CurrentToLogicalTeam(L4D_TEAM_SURVIVORS)];
			inftotalscore += roundScores[CurrentToLogicalTeam(L4D_TEAM_INFECTED)];
			CPrintToChat(client,"%T\x01: \x05%d/\x04%d","l4dscores8",client,i+1,roundScores[CurrentToLogicalTeam(L4D_TEAM_SURVIVORS)],roundScores[CurrentToLogicalTeam(L4D_TEAM_INFECTED)]);	
		}
	}
	
	if(surtotalscore != GetTeamCampaignScore(L4D_TEAM_SURVIVORS) || inftotalscore != GetTeamCampaignScore(L4D_TEAM_INFECTED))
		CPrintToChat(client,"Others\x04#附加\x01: \x05%d/\x04%d",GetTeamCampaignScore(L4D_TEAM_SURVIVORS) - surtotalscore,GetTeamCampaignScore(L4D_TEAM_INFECTED) - inftotalscore);	
	
	CPrintToChat(client,"%T\x01: \x05%d\x01/\x04%d","l4dscores9",client,GetTeamCampaignScore(L4D_TEAM_SURVIVORS),GetTeamCampaignScore(L4D_TEAM_INFECTED));
			
	DebugPrintToAll("Campaign scores - A:%d, B:%d", campaignScores[SCORE_TEAM_A], campaignScores[SCORE_TEAM_B]);

	return Plugin_Handled;
}
/*
//show a menu of round and total scores
public Action:Command_Scores(client, args)
{
	DebugPrintToAll("Command_Scores, mapCounter = %d", mapCounter);
	
	new Handle:panel = CreatePanel();
	decl String:panelLine[1024];
	
	new i, scores[2], curscore, scoresSize = GetArraySize(mapScores),totalscore;
	
	Format(panelLine, sizeof(panelLine), "SURVIVORS (%d)", GetTeamCampaignScore(L4D_TEAM_SURVIVORS));
	DrawPanelText(panel, panelLine);
	totalscore=0;
	for(i = 0; i < scoresSize; i++)
	{
		GetArrayArray(mapScores, i, scores);
		
		curscore = scores[CurrentToLogicalTeam(L4D_TEAM_SURVIVORS)-1];
		totalscore += scores[CurrentToLogicalTeam(L4D_TEAM_SURVIVORS)-1];
		Format(panelLine, sizeof(panelLine), "->%d. %d", i+1, curscore);
		DrawPanelText(panel, panelLine);
	}
	if(totalscore == GetTeamCampaignScore(L4D_TEAM_SURVIVORS))
		Format(panelLine, sizeof(panelLine), "->%d. None", i+1);
	else
		Format(panelLine, sizeof(panelLine), "->%d. %d", i+1, GetTeamCampaignScore(L4D_TEAM_SURVIVORS)-totalscore);
	DrawPanelText(panel, panelLine);
	
	Format(panelLine, sizeof(panelLine), "INFECTED (%d)", GetTeamCampaignScore(L4D_TEAM_INFECTED));
	DrawPanelText(panel, panelLine);
	totalscore=0;
	for(i = 0; i < scoresSize; i++)
	{
		GetArrayArray(mapScores, i, scores);
		
		curscore = scores[CurrentToLogicalTeam(L4D_TEAM_INFECTED)-1];
		totalscore += scores[CurrentToLogicalTeam(L4D_TEAM_INFECTED)-1];
		Format(panelLine, sizeof(panelLine), "->%d. %d", i+1, curscore);
		DrawPanelText(panel, panelLine);
	}
	if(totalscore == GetTeamCampaignScore(L4D_TEAM_INFECTED))
		Format(panelLine, sizeof(panelLine), "->%d. None", i+1);
	else
		Format(panelLine, sizeof(panelLine), "->%d. %d", i+1, GetTeamCampaignScore(L4D_TEAM_INFECTED)-totalscore);
	DrawPanelText(panel, panelLine);
	
	DebugPrintToAll("Campaign scores - A:%d, B:%d", campaignScores[SCORE_TEAM_A], campaignScores[SCORE_TEAM_B]);

	SendPanelToClient(panel, client, Menu_ScorePanel, SCORE_LIST_PANEL_LIFETIME);	
	
	CloseHandle(panel);
	
	return Plugin_Handled;
}
public Menu_ScorePanel(Handle:menu, MenuAction:action, param1, param2) { return; }
*/

/*
* SWAP MENU FUNCTIONALITY
*/

new swapClients[256];
public Action:Command_SwapMenu(client, args)
{
	DebugPrintToAll("Command_Scores, mapCounter = %d", mapCounter);
	
	//new Handle:panel = CreatePanel();
	decl String:panelLine[1024];
	decl String:itemValue[32];
	
	//new i, numPlayers = 0;
	//->%d. %s makes the text yellow
	// otherwise the text is white
	
#if SCORE_DEBUG
	new teamIdx[] = {2, 3, 1, 3};
	new String:teamNames[][] = {"SURVIVORS","INFECTED","SPECTATORS","INFECTED"};
#else
	new teamIdx[] = {2, 3, 1};
	new String:teamNames[][] = {"SURVIVORS","INFECTED","SPECTATORS"};
#endif
	
	/*
	for(new j = 0; j < sizeof(teamIdx); j++)
	{
		new team = teamIdx[j];
		DebugPrintToAll("Iterating team %d", team);
		
		if(GetTeamHumanCount(team) > 0)
		{
			DrawPanelText(panel, teamNames[j]);
			for(i = 1; i < L4D_MAXCLIENTS_PLUS1; i++) 
			{
				if(IsClientInGameHuman(i) && GetClientTeam(i) == team) 
				{					
					numPlayers++;
					//Format(panelLine, 1024, "->%d. %N", numPlayers, i);
					Format(panelLine, 1024, "%N", i);
					//DrawPanelText(panel, panelLine);
					DrawPanelItem(panel, panelLine);
					
					#if SCORE_DEBUG
					//DrawPanelItem(panel, panelLine);
					#endif
					
					swapClients[numPlayers] = i;
				}
			}
		}
	}
	
	SendPanelToClient(panel, client, Menu_SwapPanel, SCORE_LIST_PANEL_LIFETIME);	
	
	CloseHandle(panel);*/
	
	new Handle:menu = CreateMenu(Menu_SwapPanel);
	SetMenuPagination(menu, MENU_NO_PAGINATION);
	
	new i = Helper_GetNonEmptyTeam(teamIdx, sizeof(teamIdx), 0);
	new itemIdx = 0;
	
	if (i != -1)
	{
		SetMenuTitle(menu, teamNames[i]);
	}
	while(i != -1)
	{
		new idxNext = Helper_GetNonEmptyTeam(teamIdx, sizeof(teamIdx), i+1);
		
		new team = teamIdx[i];
		new teamCount = GetTeamHumanCount(team);
		
		new numPlayers = 0;
		for(new j = 1; j < L4D_MAXCLIENTS_PLUS1; j++)
		{
			if(IsClientInGameHuman(j) && GetClientTeam(j) == team)
			{
				numPlayers++;
				
				if(numPlayers != teamCount || idxNext == -1)
				{
					Format(panelLine, 1024, "%N", j);
				}
				else
				{
					Format(panelLine, 1024, "%N\n%s", j, teamNames[idxNext]);
				}
				Format(itemValue, sizeof(itemValue), "%d", j);
				DebugPrintToAll("Added item with value = %s", itemValue);
				
				AddMenuItem(menu, itemValue, panelLine);
				
				swapClients[itemIdx] = j;
				itemIdx++;
			}
		}
	
		i = idxNext;
	}
	
	DisplayMenu(menu, client, SCORE_SWAPMENU_PANEL_LIFETIME);
	
	return Plugin_Handled;
}

//iterate through all teamIdx and find first non-empty team, return that team idx
Helper_GetNonEmptyTeam(const teamIdx[], size, startIdx)
{
	if(startIdx >= size || startIdx < 0)
	{
		return -1;
	}
	
	for(new i = startIdx; i < size; i++)
	{
		new team = teamIdx[i];
		
		new humans = GetTeamHumanCount(team);
		if(humans > 0)
		{
			return i;
		}
	}
	
	return -1;
}

public Menu_SwapPanel(Handle:menu, MenuAction:action, param1, param2) { 
	if (action == MenuAction_Select)
	{
		new client = param1;
		new itemPosition = param2;
		
		DebugPrintToAll("MENUSWAP: Action %d You selected item: %d", action, param2)
		
		new String:infobuf[16];
		GetMenuItem(menu, itemPosition, infobuf, sizeof(infobuf));
		
		DebugPrintToAll("MENUSWAP: Menu item was %s", infobuf);
		
		new player_id = swapClients[itemPosition];
		
		//swap and redraw menu
		new team = GetOppositeClientTeam(player_id);
		teamPlacementArray[player_id] = team;
		CPrintToChatAll("[SM] %N %t", player_id,"l4dscores2", L4D_TEAM_NAME(team));
		TryTeamPlacementDelayed();
		
		//redraw in like 0.5 seconds or so
		Delayed_DisplaySwapMenu(client);
		
	} else if (action == MenuAction_Cancel) {
		new reason = param2;
		new client = param1;
		
		DebugPrintToAll("MENUSWAP: Action %d Client %d's menu was cancelled.  Reason: %d", action, client, reason)
	
		//display swap menu till exit is pressed
		if(reason == MenuCancel_Timeout)
		{
			//Command_SwapMenu(client, 0);
		}
	}
	/* If the menu has ended, destroy it */
	else if (action == MenuAction_End)
	{
		CloseHandle(menu)
	}
}


Delayed_DisplaySwapMenu(client)
{
	CreateTimer(SCORE_SWAPMENU_PANEL_REFRESH, Timer_DisplaySwapMenu, client, _);
	
	DebugPrintToAll("Delayed display swap menu on %N", client);
}

public Action:Timer_DisplaySwapMenu(Handle:timer, any:client)
{
	Command_SwapMenu(client, 0);
}

/*
* 
* DEBUG TESTING FUNCTIONS
* 
*/


#if SCORE_DEBUG

public Action:Command_PrintPlacement(client, args)
{
	for(new i = 1; i < L4D_MAXCLIENTS_PLUS1; i++)
	{
		if(teamPlacementArray[i])
		{
			DebugPrintToAll("Placement for %N to %d", i, teamPlacementArray[i]);
		}
	}
	
	return Plugin_Handled;
}

public Action:Command_SwapNext(client, args)
{
	DebugPrintToAll("Will swap teams on map restart...");
	
	/*
	* We place everyone on whatever team they should be on
	* according to the set swapping type
	*/
	ClearTeamPlacement();
	
	if(args > 0)
	{
		DebugPrintToAll("Will simply override team swapping");
		swapTeamsOverride = true;
		return Plugin_Handled;
	}
	
	new String:authid[128];
	new i;
	
	new team;
	for(i = 1; i < L4D_MAXCLIENTS_PLUS1; i++) 
	{
		if(IsClientInGameHuman(i)) 
		{
			GetClientAuthString(i, authid, sizeof(authid));
			team = GetOppositeClientTeam(i);
			
			DebugPrintToAll("Next map will place %N to %d", i, team);
			SetTrieValue(teamPlacementTrie, authid, team);
		}
	}	
	
	swapTeamsOverride = true;
	
	DebugPrintToAll("Overriding built-in swap teams mechanism");
	
	return Plugin_Handled;
}

public Action:Command_ChangeTeam(client, args)
{
	new String:arg1[128];
	
	GetCmdArg(1, arg1, 128);
	
	new team = StringToInt(arg1);
	
	ChangePlayerTeamDelayed(client, team);
	
	return Plugin_Handled;
}
#endif

public Action:Command_SetCampaignScores(client, args)
{
	if(client == 0 || !IsClientInGame(client)) return Plugin_Handled;

	if(!IsInReady())
	{
		ReplyToCommand(client, "[SM] sm_setscores <survs> <inf> only allowed during ready-up.");
		return Plugin_Handled;
	}

	if(GetClientTeam(client) == L4D_TEAM_SPECTATE)
	{
		ReplyToCommand(client, "%T", "You are not in-game!", client);
		return Plugin_Handled;
	}

	if (args < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_setscores <survs> <inf>");
		return Plugin_Handled;
	}

	if(CanStartVotes(client) == false)
	{
		return Plugin_Handled;
	}
	
	new String:arg1[64], String:arg2[64];
	GetCmdArg(1, arg1, 64);
	GetCmdArg(2, arg2, 64);
	
	score1 = StringToInt(arg1);
	if (score1 < 0)
	{
		ReplyToCommand(client, "[SM] Usage: sm_setscores <survs> <inf>");
		return Plugin_Handled;
	}
	score2 = StringToInt(arg2);
	if (score2 < 0)
	{
		ReplyToCommand(client, "[SM] Usage: sm_setscores <survs> <inf>");
		return Plugin_Handled;
	}
	
	//L4D_OnSetCampaignScores(score1, score2);//這個只能set score / score
	//L4D2Direct_SetVSCampaignScore(team, score2); //設置一個隊伍前面關卡的全部分數
	
	if (GetUserAdmin(client) != INVALID_ADMIN_ID)
	{
		mapCounter = 1;
		ClearArray(mapScores);
		campaignScores[CurrentToLogicalTeam(L4D_TEAM_SURVIVORS)] = score1;
		campaignScores[CurrentToLogicalTeam(L4D_TEAM_INFECTED)] = score2;
		CPrintToChatAll("{green}[{default}Score{green}] Adm({lightgreen}%N{default}) %t",client,"l4dscores10", "Survivor", score1);
		CPrintToChatAll("{green}[{default}Score{green}] Adm({lightgreen}%N{default}) %t",client,"l4dscores10", "Infected", score2);
	}
	else
	{
		int iNumPlayers = 0;
		for (int i=1; i<=MaxClients; i++)
		{
			if (!IsClientInGame(i) || IsFakeClient(i))
			{
				continue;
			}
			iNumPlayers++;
		}
		if (iNumPlayers < 2)
		{
			CPrintToChat(client, "{green}[{default}Score{green}]{default} %T %T","votes3_13",client,"Not enough players.",client, 2);
			return Plugin_Handled;
		}

		new String:printmsg[128];
		Format(printmsg, sizeof(printmsg), "%t","l4dscores12", score1, score2);

		StartVote(printmsg);
	}

	return Plugin_Handled;
}

public Action:Command_GetTeamScore(client, args)
{
	if (args < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_getscore <team> <0|1>");
		return Plugin_Handled;
	}
	new String:arg1[64], String:arg2[64];
	GetCmdArg(1, arg1, 64);
	GetCmdArg(2, arg2, 64);
	
	new team = StringToInt(arg1);
	new b1 = StringToInt(arg2);
	
	/*
	* b1 = 0 then get the round score
	* b1 = 1 then get the campaign score
	* 
	* 
	* 2 0 returns -1 when score is not set for round?
	* 
	* 
	* your team 1 , enemy team 2
	* 
	* sm_getscore 3 1 seems to return survivor completition percentage <:D>
	* sm_getscore 4 1 seems to read the health bonus
	* 
	* sm_getscore 5 0 - completition %?
	* sm_getscore 6 0 - Average Distance %
	* 
	* --------------------------------
	* 
	* sm_getscore 1 0 gets the map score (end of round was 1540)
	* sm_getscore 1 1 gets the campaign score 
	* 	(might might be valid only after end of 2nd round?)
	* 
	* sm_getscore 0 1 gets the score for the map I think
	* sm_getscore 0 0 probably campaign too, crazy values when not end of map
	* 
	* score of -1 mean the team hasnt played yet
	* 
	* -------
	* TEAM ORDER? 0 or 1 for the team # but is it constant or not across map changes
	* 
	* FIRST MAP (team A = survivors first, B = survivors second)
	* sm_getscore 1 0 gets you the map score for team A
	*   - you can keep doing this after the round is over during that map 
	* 
	* SECOND MAP (teams swapped due to team B having higher score)
	* 
	* sm_getscore 0 1 gets you the map score for team B
	* 
	* ****************************************
	* 
	* 
	* FIRST MAP
	* (first round)
	* sm_getscore 1 0 - team A 199
	* sm_getscore 1 1 - 0
	* sm_getscore 2 0 - team B -1
	* sm_getscore 2 1 - 0
	* (second round)
	* sm_getscore 1 0 - team A 9
	* sm_getscore 1 1 - 0
	* sm_getscore 2 0 - team B 200 (剛開始)
	* sm_getscore 2 1 - 0
	* (end of map)
	* sm_getscore 1 1 - 9
	* sm_getscore 2 1 - 1100 (走完到終點)
	* 
	* SECOND MAP (AB swapped due to scoreB > scoreA)
	* (first round)
	* - campaign scores are "0"
	* sm_getscore 1 0 - team A -1
	* sm_getscore 2 0 - team B 16
	* 
	* (second round)
	* - same as first round except
	* sm_getscore 1 0 - team A 0
	* 
	* (end of map)
	* - campaign scores are set to what they shuld be
	* 
	* THIRD MAP (B first, A second)
	* sm_getscore 1 0 - team A -1
	* sm_getscore 2 0 - team B 0 (in safe room)
	* 
	* VERDICT:
	* 
	* the "first" team is the one that starts survivor on 1st map
	* the "second" team is the one that starts infected on 1st map
	* 
	* if teams are swapped then it doesnt matter
	* 
	* AUTO SWAP DETECTION:
	* if 1 was -1 last map and now team 2 is -1 then teams were swapped
	* 
	* **********************************
	* 
	* FOURTH MAP: sm_setscore 1337 0
	* - Team A magically is winning the campaign now
	* - Team B is magically losing
	* 
	* Team A starts first (could SetCampaignScore update the real campaign score?)
	* Team B starts second
	* 
	* FIFTH MAP
	* campaign scores are back to 1118 (B) - 9 A 
	* so SetCampaignScore does NOT update real score
	* 
	* --- Maybe SetCampaignScore does determine who goes first however?
	* YES IT DOES
	* made team A win, team B lose, then setcampaignscores(0,1337)
	* 
	* Team B then went first with sm_getscore 2 0 returning the real score
	* Team A had sm_getscore 1 0 like it should have
	* ---
	* 
	* 
	* TEAMS TIED ? THEN TEAMS ARE NOT SWITCHED
	*/
	
	new score = L4D_GetTeamScore(team, (b1 > 0) ? true: false);
	
	CPrintToChat(client,"%T","l4dscores11",client, score);
	
	return Plugin_Handled;
}

#if SCORE_DEBUG
public Action:Command_ClearTeamScores(client, args)
{	
	new String:arg1[64];
	GetCmdArg(1, arg1, 64);
	
	L4D_OnClearTeamScores(true);
	
	DebugPrintToAll("Team scores have been cleared");
	
	return Plugin_Handled;
}

#endif

DebugPrintToAll(const String:format[], any:...)
{
	#if SCORE_DEBUG	|| SCORE_DEBUG_LOG
	decl String:buffer[192];
	
	VFormat(buffer, sizeof(buffer), format, 2);
	
	#if SCORE_DEBUG
	CPrintToChatAll("%s", buffer);
	//PrintToConsole(0, "%s", buffer);
	#endif
	
	LogMessage("[SCORE] %s", buffer);
	#else
	//suppress "format" never used warning
	if(format[0])
		return;
	else
		return;
	#endif
}

GetRoundCounter(bool:increment_counter=false, bool:reset_counter=false)
{
#define DEBUG_ROUND_COUNTER 0
	
	static counter = 0;
	if(reset_counter)
	{
		roundCounterReset = true;
		counter = 0;
		#if DEBUG_ROUND_COUNTER
		DebugPrintToAll("RoundCounter -- reset to 0");
		#endif
	}
	else if(increment_counter)
	{
		counter++;
		#if DEBUG_ROUND_COUNTER
		DebugPrintToAll("RoundCounter -- incremented to %d", counter);
		#endif
	}
	else
	{
		#if DEBUG_ROUND_COUNTER
		DebugPrintToAll("RoundCounter -- returned %d", counter);
		#endif
	}
	
	return counter;
}


public Action:L4D_OnRecalculateVersusScore(client)//對抗模式只要人類隊伍有真人玩家還活著一直都在算health bouns部分
{
	if(RoundEnding) return Plugin_Continue;
	
	new surdead;
	for(new i=1; i <= MaxClients; i++){
		if(IsSurvivor(i))
			if(!IsPlayerAlive(i)||IsIncapacitated(i)||GetEntProp(i, Prop_Send, "m_isHangingFromLedge"))
				surdead++;
	}
	if(surdead == GetTeamMaxHumans(L4D_TEAM_SURVIVORS))//wiped out 
	{
		return Plugin_Continue;
	}
	new HealthB, tempHealthB, pillB, Ent;
	
	for (new j = 1; j <= MaxClients; j++)
	{
		if (IsSurvivor(j))
		{
			HealthB = tempHealthB = pillB = 0;
			if(IsPlayerAlive(j)){
				if(!IsIncapacitated(j) && !GetEntProp(j, Prop_Send, "m_isHangingFromLedge"))
				{
					HealthB = GetHardHealth(j)/2;
					tempHealthB = RoundToNearest(GetAccurateTempHealth(j)/4);
				}
				Ent = GetPlayerWeaponSlot(j, 4); if (Ent != -1) pillB += g_iPillScore;
				Ent = GetPlayerWeaponSlot(j, 3); if (Ent != -1) pillB += g_iKitScores;
			}
			L4DDirect_SetSurvivorHealthBonus(j,HealthB+tempHealthB+pillB,false);
		}
	}
	L4DDirect_RecomputeTeamScores();///如果全部玩家死亡不會計算此行

	return Plugin_Handled;
}

public Event_heal_success(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(IsInReady()) return;
	
	new subject = GetClientOfUserId(GetEventInt(event, "subject"));//被治療的那位
	if (subject<=0||!IsClientAndInGame(subject)) { return; } //just in case
	
	ClientHasDown[subject] = false;
}

public Action:OnBotSwap(Handle:event, const String:name[], bool:dontBroadcast) 
{
	if(IsInReady()) return Plugin_Continue;
	
	new bot = GetClientOfUserId(GetEventInt(event, "bot"));
	new player = GetClientOfUserId(GetEventInt(event, "player"));
	if (IsClientIndex(bot) && IsClientIndex(player)) 
	{
		if (StrEqual(name, "player_bot_replace")) 
		{
			ClientHasDown[bot] = ClientHasDown[player];
			ClientHasDown[player] = false;
			
		}
		else 
		{
			ClientHasDown[player] = ClientHasDown[bot];
			ClientHasDown[bot] = false;
		}
	}
	return Plugin_Continue;
}

public Action:OnPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(IsInReady()) return;
	
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(IsClientIndex(client)&&IsClientConnected(client)&&IsClientInGame(client)&&GetClientTeam(client)==2)
	{
		ClientHasDown[client] = false;
	}
}

bool:IsClientIndex(client)
{
	return (client > 0 && client <= MaxClients);
}

Float:CalculateHBPercent(HB)
{
	new maxbonus = GetTeamMaxHumans(L4D_TEAM_SURVIVORS) * 50;
	return (float(HB) / maxbonus ) * 100;
}

Float:CalculatePillsPercent(Pills)
{
	new maxbonus = GetTeamMaxHumans(L4D_TEAM_SURVIVORS) * g_iPillScore;
	return (float(Pills) / maxbonus ) * 100;
}

CheckSurvivorProgress()
{
	new P = L4D_GetTeamScore(6, false);
	
	if(P>=survivor_progress)
	{
		new Handle:PANEL = CreatePanel();
		
		EmitSoundToAll("ui/holdout_teamrec.wav",_,_,_,_,0.25);
		decl String:panel_message[128];
		Format(panel_message, sizeof(panel_message), "The Survivors have made it %d%% of the way!",survivor_progress);
		DrawPanelText(PANEL, panel_message);
		
		for (new i = 1; i <= MaxClients; i++)
		{
			if(!IsClientInGame(i) || IsFakeClient(i)) continue;

			if(GetClientMenu(i, INVALID_HANDLE) == MenuSource_None)
				SendPanelToClient(PANEL, i, DummyPANELHudHandler, 3);
		}
		
		CloseHandle(PANEL);
		
		if(survivor_progress == 75)
			survivor_progress = 10000;
		else
			survivor_progress += 25;
	}
}

public DummyPANELHudHandler(Handle:hMenu, MenuAction:action, param1, param2) {}

public ConVarChange_Cvars(Handle:convar, const String:oldValue[], const String:newValue[])
{
	g_iPillScore = GetConVarInt(g_hPillScore);
	g_iKitScores = GetConVarInt(g_hKitScores);
}

StartVote(const String:sVoteHeader[])
{
	hVote = new Menu(Handler_VoteCallback, MENU_ACTIONS_ALL);
	hVote.SetTitle("%s ?",sVoteHeader);
	hVote.AddItem(VOTE_YES, "Yes");
	hVote.AddItem(VOTE_NO, "No");
	hVote.ExitButton = false;

	new iTotal = 0;
	new iPlayers[MaxClients];
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || GetClientTeam(i) == 1)
		{
			continue;
		}
		
		iPlayers[iTotal++] = i;
	}
	
	hVote.DisplayVote(iPlayers, iTotal, 20, 0);
	
	EmitSoundToAll("ui/beep_synthtone01.wav");
	
	for(new i=1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || GetClientTeam(i) == 1)
		{
			continue;
		}
		
		ClientVoteMenuSet(i,1);
	}
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
		Format(buffer, sizeof(buffer), "%T ?", "l4dscores12",param1, score1, score2);
		
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

	limit = 0.6;
	
	CheckVotes();
	if (action == MenuAction_End)
	{
		VoteMenuClose();
	}
	else if (action == MenuAction_VoteCancel && param1 == VoteCancel_NoVotes)
	{
		CPrintToChatAll("{default}[{olive}TS{default}] %t","No votes");
		EmitSoundToAll("ui/beep_error01.wav");
		CreateTimer(2.0, VoteEndDelay);
	}	
	else if (action == MenuAction_VoteEnd)
	{
		if ((strcmp(item, VOTE_YES) == 0 && FloatCompare(percent,limit) < 0 && param1 == 0) || (strcmp(item, VOTE_NO) == 0 && param1 == 1))
		{
			EmitSoundToAll("ui/beep_error01.wav");
			CPrintToChatAll("{default}[{olive}TS{default}] %t","Vote fail.", RoundToNearest(100.0*limit), RoundToNearest(100.0*percent), totalVotes);
			CreateTimer(2.0, VoteEndDelay);
		}
		else
		{
			CreateTimer(2.0, Timer_SetTeamScore);
			EmitSoundToAll("ui/menu_enter05.wav");
			CPrintToChatAll("{default}[{olive}TS{default}] %t","Vote pass.");
			CreateTimer(2.0, VoteEndDelay);
		}
	}
	return 0;
}

bool:CanStartVotes(client)
{
 	if(hVote  != null || IsVoteInProgress())
	{
		CPrintToChat(client, "{default}[{olive}TS{default}] %T","A vote is already in progress!",client);
		return false;
	}
	return true;
}

CheckVotes()
{
	PrintHintTextToAll("%t: %i\n%t: %i","Agree", Votey,"Disagree", Voten);
}

public Action:VoteEndDelay(Handle:timer)
{
	Votey = 0;
	Voten = 0;
	for(new i=1; i <= MaxClients; i++) ClientVoteMenuSet(i,0);

	return Plugin_Continue;
}

public Action Timer_SetTeamScore(Handle:timer)
{
	mapCounter = 1;
	ClearArray(mapScores);
	campaignScores[CurrentToLogicalTeam(L4D_TEAM_SURVIVORS)] = score1;
	campaignScores[CurrentToLogicalTeam(L4D_TEAM_INFECTED)] = score2;
	CPrintToChatAll("{green}[{default}Score{green}] %t", "l4dscores10", "Survivor", score1);
	CPrintToChatAll("{green}[{default}Score{green}] %t", "l4dscores10", "Infected", score2);

	score1 = score2 = 0;
	return Plugin_Continue;
}

VoteMenuClose()
{
	Votey = 0;
	Voten = 0;
	CloseHandle(hVote);
	hVote = null;
}

Float:GetVotePercent(votes, totalVotes)
{
	return (float(votes) / float(totalVotes));
}