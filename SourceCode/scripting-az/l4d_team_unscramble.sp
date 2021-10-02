#include <sourcemod>
#include <sdktools>
#include <multicolors>

#pragma semicolon 1
#define PLUGIN_VERSION "1.3"

#define AS_TAG				"[Unscramble]"

#define MAX_UNSRAMBLE_TIME 40.0
#define UNSCRABBLE_MAX_FAILURE		3
static	Handle:g_hTrine,Handle:g_hCvarEnable, Handle:g_fwdOnUnscrambleEnd, bool:g_bCvarASEnable, bool:g_bCheked[MAXPLAYERS+1], bool:g_bJoinTeamUsed[MAXPLAYERS+1],
		g_iFailureCount[MAXPLAYERS+1], bool:g_bTeamLock, g_isOldTeamFlipped, g_isNewTeamFlipped, g_iTrineSize, Handle:g_hCvarNoVotes;
static String:previousmap[128];
static bool:previoussecondround;
static bool:b_needswapteam;

public Plugin:myinfo = 
{
	name = "l4d_team_unscramble",
	author = "Harry Potter",
	description = "forces all players on the right team after map/campaign/match change",
	version = PLUGIN_VERSION,
	url = "myself"
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	CreateNative("UnScramble_KeepTeams", Native_UnScramble_KeepTeams);
	return APLRes_Success;
}
public OnPluginStart()
{
	LoadTranslations("Roto2-AZ_mod.phrases");
	g_hTrine = CreateTrie();
	g_fwdOnUnscrambleEnd = CreateGlobalForward("R2comp_OnUnscrambleEnd", ET_Ignore);

	g_hCvarEnable = CreateConVar("allow_unscramble", "1", "Enables unscramble feature (Puts all players on the right team after map/campaign/match change)", _, true, 0.0, true, 1.0);
	g_hCvarNoVotes = CreateConVar("unscramble_novotes", "1", "Prevents calling votes until unscramble completes", _, true, 0.0, true, 1.0);

	RegAdminCmd("sm_keepteams", Command_KeepTeams, ADMFLAG_ROOT, "Force teams to be the same each round.");


	if (!(g_bCvarASEnable = GetConVarBool(g_hCvarEnable))){

		return;
	}
	if (GetConVarBool(g_hCvarNoVotes)){

		AddCommandListener(AS_cmdh_Vote, "callvote");
		AddCommandListener(AS_cmdh_Vote, "vote");
	}

	HookEvent("round_end", AS_ev_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("vote_passed", AS_ev_VotePassed);
	
	strcopy(previousmap, sizeof(previousmap), "");
}

public Action:AS_cmdh_Vote(client, const String:command[], argc)
{
	if (g_bTeamLock){

		if (GetClientTeam(client) != 1)
			CPrintToChat(client, "{default}[{olive}TS{default}] %T","Voting is not enabled until unscramble is completed",client);
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public Action:Command_KeepTeams(client, args)
{
	AS_KeepTeams();

	return Plugin_Handled;
}

public AS_ev_VotePassed(Handle:event, const String:sName[], bool:DontBroadCast)
{
	decl String:sDetals[128];
	GetEventString(event, "details", sDetals, 128);

	if (StrEqual(sDetals, "#L4D_vote_passed_mission_change"))
		AS_KeepTeams();
}

public OnMapStart()
{
	b_needswapteam = false;
	
	PrecacheModel("models/survivors/survivor_manager.mdl", true);
	PrecacheModel("models/survivors/survivor_biker.mdl", true);
	PrecacheModel("models/survivors/survivor_teenangst.mdl", true);
	PrecacheModel("models/survivors/survivor_namvet.mdl", true);
	
	decl String:currentmap[128];
	GetCurrentMap(currentmap, sizeof(currentmap));
	if(StrEqual(currentmap, previousmap) && previoussecondround)
	{
		b_needswapteam = true;
	}
	strcopy(previousmap, sizeof(previousmap),currentmap);
	previoussecondround = false;
	
	CreateTimer(0.5, AS_t_TeamsFlipped);

	if (!g_iTrineSize) return;

	g_bTeamLock = true;

	CreateTimer(5.0, AS_t_CheckConnected, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(MAX_UNSRAMBLE_TIME, AS_t_AllowTeamChanges, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:AS_t_TeamsFlipped(Handle:timer)
{
	g_isNewTeamFlipped = GameRules_GetProp("m_bAreTeamsFlipped");
}

public AS_ev_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (GameRules_GetProp("m_bInSecondHalfOfRound"))
	{
		AS_KeepTeams();
	}
}

static AS_KeepTeams()
{
	if (!g_bCvarASEnable) return;
	
	if(InSecondHalfOfRound())
	{
		previoussecondround = true;
	}
	
	g_bTeamLock = false;
	g_isOldTeamFlipped = GameRules_GetProp("m_bAreTeamsFlipped");
	ClearTrie(g_hTrine);

	decl bool:bInGame, String:sSteamID[32], iTeam;
	new bool:bConnectedOnly = true;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (((!(bInGame = IsClientInGame(i)) && IsClientConnected(i)) || bInGame) && !IsFakeClient(i))
		{
			if (GetClientAuthId(i, AuthId_Steam2, sSteamID, 32))
			{
				iTeam = 1;

				if (bInGame){

					iTeam = GetClientTeam(i);

					if (!iTeam)
						iTeam = 1;
				}

				if (iTeam != 1) // disable unscramble if both team is empty
					bConnectedOnly = false;

				SetTrieValue(g_hTrine, sSteamID, iTeam);
			}
		}
	}

	if (bConnectedOnly)
		ClearTrie(g_hTrine);

	g_iTrineSize = GetTrieSize(g_hTrine);
}
public OnClientPutInServer(client)
{
	if (g_bTeamLock && !IsFakeClient(client)){
	
		g_bCheked[client] = true;
		g_iFailureCount[client] = 0;
		CreateTimer(1.0, AS_t_UnscrabbleMe, client, TIMER_REPEAT);
	}
}

public Action:AS_t_UnscrabbleMe(Handle:timer, any:client)
{
	if (!g_bTeamLock || !IsClientInGame(client)){

		g_bCheked[client] = false;
		return Plugin_Stop;
	}

	new iCTeam = GetClientTeam(client);

	if (!iCTeam)
		return Plugin_Continue;

	decl String:sSteamID[32], iLTeam;
	GetClientAuthId(client, AuthId_Steam2, sSteamID, 32);

	if (GetTrieValue(g_hTrine, sSteamID, iLTeam)){

		new iNTeam = iLTeam;

		if (IsTeamSwapped() || b_needswapteam){

			switch (iLTeam){

				case 2:
					iNTeam = 3;
				case 3:
					iNTeam = 2;
			}
		}

		if (iCTeam != iNTeam)
		{
			if (iCTeam != 1)
				ChangeClientTeam(client, 1);

			// we dont use sdk call's
			g_bJoinTeamUsed[client] = true;
			FakeClientCommand(client, "jointeam %d", iNTeam);
			g_bJoinTeamUsed[client] = false;
		}
		if (GetClientTeam(client) != iNTeam && g_iFailureCount[client] == 0){
			switch (iNTeam){

				case 2:
					FakeClientCommand(client, "sm_sur");
				case 3:
					FakeClientCommand(client, "sm_inf");
			}
		}
		
		if (GetClientTeam(client) != iNTeam){

			if (++g_iFailureCount[client] >= UNSCRABBLE_MAX_FAILURE){

				g_bCheked[client] = false;
				return Plugin_Stop;
			}

			return Plugin_Continue;
		}
		else if (--g_iTrineSize == 0){

			ForceToUnlockTeams();
		}
	}
	else if (iCTeam != 1){

		ChangeClientTeam(client, 1);
	}

	g_bCheked[client] = false;

	return Plugin_Stop;
}

public Action:AS_t_AllowTeamChanges(Handle:timer)
{
	ForceToUnlockTeams();
}

public Action:AS_t_CheckConnected(Handle:timer)
{
	if (!g_iTrineSize)
		return Plugin_Stop;

	if (IsUnscrabbleComplete()){
		ForceToUnlockTeams();

		return Plugin_Stop;
	}

	return Plugin_Continue;
}

static ForceToUnlockTeams()
{
	if (!g_bTeamLock) return;

	if(g_bCvarASEnable)
	{
		//CPrintToChatAll("{default}[{olive}TS{default}] Unscramble completed.");
	}

	Call_StartForward(g_fwdOnUnscrambleEnd);
	Call_Finish();

	g_bTeamLock = false;
	g_iTrineSize = 0;
}

static bool:IsTeamSwapped()
{
	return g_isOldTeamFlipped != g_isNewTeamFlipped;
}

static bool:IsUnscrabbleComplete()
{
	for (new i = 1; i <= MaxClients; i++)
		if (g_bCheked[i] || IsClientConnected(i) && !IsClientInGame(i))
			return false;

	return true;
}

public Native_R2comp_IsUnscrambled(Handle:plugin, numParams)
{
	return !g_bTeamLock;
}

public Native_UnScramble_KeepTeams(Handle:plugin, numParams)
{
	AS_KeepTeams();
	
	return;
}

bool:InSecondHalfOfRound()
{
	return bool:GameRules_GetProp("m_bInSecondHalfOfRound");
}