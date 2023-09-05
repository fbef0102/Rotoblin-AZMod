/*
 * ============================================================================
 *
 * This file is part of the Rotoblin 2 (R2CompMod) project.
 * See https://github.com/raziEiL/rotoblin2
 *
 *  Language:       SourcePawn.
 *  Description:	Puts players on the right team after map/campaign change and provides API.
 *  Credits:		Scratchy [Царапка] for idea.
 *
 *  Copyright (C) 2012-2015, 2020 raziEiL [disawar1] <mr.raz4291@gmail.com>
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * ============================================================================
 */
#define PLUGIN_VERSION "1.0"

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <multicolors>
#undef REQUIRE_PLUGIN
#include <l4d_lib>

#define UNSCRABBLE_LOG 0
#define MAIN_TAG				"[Unscramble]"

#define VOTE_MISSION_CHANGE "#L4D_vote_passed_mission_change"
#define VOTE_LEVEL_RESTART "#L4D_vote_passed_versus_level_restart"

#if UNSCRABBLE_LOG
static const String:g_LogFile[] = "logs\\rotoblin_unscramble.log";
static String:g_sLogPatch[128];
#endif

static	Handle:g_hTrine, Handle:g_fwdOnUnscrambleEnd, bool:g_bCvarEnabled, bool:g_bCvarNotify, bool:g_bCvarNoVotes, Float:g_fCvarTime, g_iCvarAttempts, bool:g_bCheked[MAXPLAYERS+1], bool:g_bJoinTeamUsed[MAXPLAYERS+1],
		g_iFailureCount[MAXPLAYERS+1], bool:g_bMapTranslition, bool:g_bTeamLock, g_isOldTeamFlipped, g_isNewTeamFlipped, g_iTrineSize, UserMsg:g_iVotePassMessageId;

public Plugin myinfo =
{
	name = "[L4D & L4D2] Unscramble (R2CompMod Standalone)",
	author = "raziEiL [disawar1], HarryPotter",
	description = "Puts players on the right team after map/campaign change and provides API.",
	version = PLUGIN_VERSION,
	url = "http://steamcommunity.com/id/raziEiL"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("r2comp_unscramble");
	CreateNative("R2comp_UnscrambleStart", Native_R2comp_UnscrambleStart);
	CreateNative("R2comp_UnscrambleKeep", Native_R2comp_UnscrambleKeep);
	CreateNative("R2comp_IsUnscrambled", Native_R2comp_IsUnscrambled);
	CreateNative("R2comp_AbortUnscramble", Native_R2comp_AbortUnscramble);
	return APLRes_Success;
}

public OnPluginStart()
{
	#if UNSCRABBLE_LOG
		BuildPath(Path_SM, g_sLogPatch, 128, g_LogFile);
	#endif
	LoadTranslations("Roto2-AZ_mod.phrases");

	g_hTrine = CreateTrie();
	g_fwdOnUnscrambleEnd = CreateGlobalForward("R2comp_OnUnscrambleEnd", ET_Ignore);
	g_iVotePassMessageId = GetUserMessageId("VotePass");

	CreateConVar("rotoblin_unscramble_version", PLUGIN_VERSION, "R2CompMod Unscramble Standalone plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);

	ConVar cVar;
	cVar = CreateConVar("rotoblin_unscramble_notify", "0", "0=Off, 1=Prints a notification to chat when unscramble is completed (lets spectators know when they can join a team).", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_bCvarNotify = GetConVarBool(cVar);
	HookConVarChange(cVar, OnCvarChange_Notify);

	cVar = CreateConVar("rotoblin_unscramble_novotes", "1", "0=Off, 1=Prevents calling votes until unscramble completes.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_bCvarNoVotes = GetConVarBool(cVar);
	HookConVarChange(cVar, OnCvarChange_NoVotes);

	cVar = CreateConVar("rotoblin_unscramble_attempts", "3", "Maximum attempts to try to move player to the team he were.", FCVAR_NOTIFY, true, 1.0, true, 6.0);
	g_iCvarAttempts = GetConVarInt(cVar);
	HookConVarChange(cVar, OnCvarChange_Attempts);

	cVar = CreateConVar("rotoblin_unscramble_time", "45", "Unscramble max processing time after map changed. When the time expires the teams changes will be unlocked.", FCVAR_NOTIFY, true, 15.0);
	g_fCvarTime = GetConVarFloat(cVar);
	HookConVarChange(cVar, OnCvarChange_Time);

	cVar = CreateConVar("rotoblin_allow_unscramble", "1", "0=Off, 1=Enables unscramble feature (Puts players on the right team after map/campaign change).", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_bCvarEnabled = GetConVarBool(cVar);
	UM_OnPluginEnabled();
	HookConVarChange(cVar, OnCvarChange_Enabled);

	RegAdminCmd("sm_keepteams", Command_KeepTeams, ADMFLAG_ROOT, "Force to store players team data.");
	RegAdminCmd("sm_unscramble_start", Command_UnscrambleStart, ADMFLAG_ROOT, "Force to puts players on the right team.");
	RegAdminCmd("sm_unscramble_abort", Command_UnscrambleAbort, ADMFLAG_ROOT, "Aborts unscramble process.");
}

UM_OnPluginEnabled()
{
	if (!g_bCvarEnabled){
	#if UNSCRABBLE_LOG
		LogToFile(g_sLogPatch, "unscramble cvar is disabled");
		PrintToServer("%s unscramble cvar is disabled", MAIN_TAG);
	#endif
		return;
	}
	if (g_bCvarNoVotes){

		AddCommandListener(US_cmdh_Vote, "callvote");
		AddCommandListener(US_cmdh_Vote, "vote");

		if (g_iVotePassMessageId != INVALID_MESSAGE_ID)
			HookUserMessage(g_iVotePassMessageId, US_msg_OnVotePass);
	}
	#if UNSCRABBLE_LOG
		LogToFile(g_sLogPatch, "unscramble is enabled");
		PrintToServer("%s unscramble is enabled", MAIN_TAG);
	#endif

	HookEvent("round_end", US_ev_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("vote_passed", US_ev_VotePassed);
}

UM_OnPluginDisabled()
{
	#if UNSCRABBLE_LOG
		LogToFile(g_sLogPatch, "unscramble is disabled");
		PrintToServer("%s unscramble is disabled", MAIN_TAG);
	#endif

	if (!g_bCvarEnabled) return;

	if (g_bCvarNoVotes){

		RemoveCommandListener(US_cmdh_Vote, "callvote");
		RemoveCommandListener(US_cmdh_Vote, "vote");

		if (g_iVotePassMessageId != INVALID_MESSAGE_ID)
			UnhookUserMessage(g_iVotePassMessageId, US_msg_OnVotePass);
	}

	UnhookEvent("round_end", US_ev_RoundEnd, EventHookMode_PostNoCopy);
	UnhookEvent("vote_passed", US_ev_VotePassed);

	RegServerCmd("changelevel", ServerCmd_changelevel);
}

public Action:Command_KeepTeams(client, args)
{
	US_KeepTeams();
	return Plugin_Handled;
}

public Action:Command_UnscrambleStart(client, args)
{
	US_StartProcess();
	return Plugin_Handled;
}

public Action:Command_UnscrambleAbort(client, args)
{
	US_AbortProcess();
	return Plugin_Handled;
}

public Action:US_cmdh_Vote(client, const String:command[], argc)
{
	if (g_bTeamLock){

		if (GetClientTeam(client) != 1)
			CPrintToChat(client, "{default}[{olive}TS{default}] %T","Voting is not enabled until unscramble is completed",client);
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

Action ServerCmd_changelevel(int args)
{
	if(args > 0)
	{
		US_KeepTeams();
	}

	return Plugin_Continue;
}

public US_ev_VotePassed(Handle:event, const String:sName[], bool:DontBroadCast)
{
	decl String:sDetals[128];
	GetEventString(event, "details", sDetals, 128);

	if (StrEqual(sDetals, VOTE_MISSION_CHANGE))
		US_KeepTeams();
}

public Action US_msg_OnVotePass(UserMsg msg_id, BfRead message, const int[] players, int playersNum, bool reliable, bool init)
{
	char sIssue[40];
	message.ReadByte();
	message.ReadString(SZF(sIssue));

	#if UNSCRABBLE_LOG
		LogToFile(g_sLogPatch, "VotePass Usermessage: issue: %s", sIssue);
	#endif

	if (StrEqual(VOTE_MISSION_CHANGE, sIssue) || StrEqual(VOTE_LEVEL_RESTART, sIssue))
		US_KeepTeams();

	return Plugin_Continue;
}

public Action OnLogAction(Handle source, Identity ident,int client, int target, const char[] message)
{
	if (g_bCvarEnabled && StrContains(message, "changed map to") != -1)
		US_KeepTeams();

	return Plugin_Continue;
}

/*
 * ---------------------------
 *		Forwards
 * ---------------------------
*/
// ---- ;

public OnMapStart()
{
	#if UNSCRABBLE_LOG
		LogToFile(g_sLogPatch, "--------- MapStart ---------");
	#endif
	for (new i = IsL4DGameEx() ? L4D_SURVIVOR_CHARACTER_OFFSET : 0; i < SC_SIZE; i++){
		PrecacheModel(L4D2_LIB_SURVIVOR_MDL[i], true);
	#if UNSCRABBLE_LOG
		LogToFile(g_sLogPatch, "Precache %s", L4D2_LIB_SURVIVOR_MDL[i]);
	#endif
	}
	g_bMapTranslition = false;
	CreateTimer(0.5, US_t_TeamsFlipped);
	US_Start();
}

public Action:US_t_TeamsFlipped(Handle:timer)
{
	US_UpdateTeamFlipped();
}

US_UpdateTeamFlipped()
{
	g_isNewTeamFlipped = GameRules_GetProp("m_bAreTeamsFlipped");
}

bool:US_Start()
{
	if (!g_iTrineSize)
		return false;

	g_bTeamLock = true;

	CreateTimer(5.0, US_t_CheckConnected, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(g_fCvarTime, US_t_AllowTeamChanges, _, TIMER_FLAG_NO_MAPCHANGE);
	return true;
}

US_StartProcess()
{
	if (US_Start()){
		US_UpdateTeamFlipped();

		for (new i = 1; i <= MaxClients; i++){
			if (IsClientInGame(i))
				OnClientPutInServer(i);
		}
	}
}

public US_ev_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (GameRules_GetProp("m_bInSecondHalfOfRound") && !g_bMapTranslition)
		US_KeepTeams();
}

US_KeepTeams()
{
	if (!g_bCvarEnabled) return;
	#if UNSCRABBLE_LOG
		LogToFile(g_sLogPatch, "KeepTeams");
	#endif

	g_bTeamLock = false;
	g_bMapTranslition = true;
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

				#if UNSCRABBLE_LOG
					LogToFile(g_sLogPatch, "team %d. %N (%s)", iTeam, i, sSteamID);
				#endif
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
		CreateTimer(1.0, US_t_UnscrabbleMe, client, TIMER_REPEAT);
	}
}

public Action:US_t_UnscrabbleMe(Handle:timer, any:client)
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

		if (IsTeamSwapped()){

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
			//FakeClientCommand(client, "jointeam %d", iNTeam);
			switch (iNTeam){
				case 2:
					FakeClientCommand(client, "sm_sur");
				case 3:
					FakeClientCommand(client, "sm_inf");
			}
			g_bJoinTeamUsed[client] = false;
		}

		#if UNSCRABBLE_LOG
			LogToFile(g_sLogPatch, "%N (%s). Teams: last %d, current %d. Moved to %d (%s).", client, sSteamID, iLTeam, iCTeam, iNTeam, GetClientTeam(client) == iNTeam ? "Okay" : "Fail");
		#endif

		if (GetClientTeam(client) != iNTeam){

			if (++g_iFailureCount[client] >= g_iCvarAttempts){

				g_bCheked[client] = false;
				return Plugin_Stop;
			}

			return Plugin_Continue;
		}
		else if (--g_iTrineSize == 0){

			#if UNSCRABBLE_LOG
				LogToFile(g_sLogPatch, "Trine is empty. Unlock 'jointeam' cmd");
			#endif

			US_ForceToUnlockTeams();
		}
	}
	else if (iCTeam != 1){

		ChangeClientTeam(client, 1);

		#if UNSCRABBLE_LOG
			LogToFile(g_sLogPatch, "%N (%s). Unknown client. Moved to 1", client, sSteamID);
		#endif
	}

	g_bCheked[client] = false;

	return Plugin_Stop;
}

public Action:US_t_AllowTeamChanges(Handle:timer)
{
	#if UNSCRABBLE_LOG
		LogToFile(g_sLogPatch, "Time is up (%.0f sec). Force to unlock 'jointeam' cmd", g_fCvarTime);
	#endif

	US_ForceToUnlockTeams();
}

public Action:US_t_CheckConnected(Handle:timer)
{
	if (!g_iTrineSize)
		return Plugin_Stop;

	if (IsUnscrabbleComplete()){

		#if UNSCRABBLE_LOG
			LogToFile(g_sLogPatch, "Last client connected. Unlock 'jointeam' cmd");
		#endif

		US_ForceToUnlockTeams();

		return Plugin_Stop;
	}

	return Plugin_Continue;
}

US_ForceToUnlockTeams()
{
	if (!g_bTeamLock) return;

	if (g_bCvarNotify)
	{
		//CPrintToChatAll("{default}[{olive}TS{default}] Unscramble completed.");
	}

	Call_StartForward(g_fwdOnUnscrambleEnd);
	Call_Finish();

	US_ClearVars();
}

US_ClearVars()
{
	ClearTrie(g_hTrine);
	g_bTeamLock = false;
	g_iTrineSize = 0;
}

bool:IsTeamSwapped()
{
	return g_isOldTeamFlipped != g_isNewTeamFlipped;
}

bool:IsUnscrabbleComplete()
{
	for (new i = 1; i <= MaxClients; i++)
		if (g_bCheked[i] || IsClientConnected(i) && !IsClientInGame(i))
			return false;

	return true;
}

US_AbortProcess(bool:fireOnUnscrambleEnd = true)
{
	if (fireOnUnscrambleEnd)
		US_ForceToUnlockTeams();
	else
		US_ClearVars();
}

stock void CheatCommandEx(client, const String:command[], const String:arguments[] = "")
{
	new iFlags = GetCommandFlags(command);
	SetCommandFlags(command, iFlags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", command, arguments);
	SetCommandFlags(command, iFlags);
}

public Native_R2comp_UnscrambleStart(Handle:plugin, numParams)
{
	US_StartProcess();
}

public Native_R2comp_UnscrambleKeep(Handle:plugin, numParams)
{
	US_KeepTeams();
}

public Native_R2comp_IsUnscrambled(Handle:plugin, numParams)
{
	return !g_bTeamLock;
}

public Native_R2comp_AbortUnscramble(Handle:plugin, numParams)
{
	US_AbortProcess(GetNativeCell(1));
}

public void OnCvarChange_Enabled(ConVar cVar, const char[] sOldVal, const char[] sNewVal)
{
	if (!StrEqual(sOldVal, sNewVal)){

		g_bCvarEnabled = GetConVarBool(cVar);
		US_ClearVars();

		if (g_bCvarEnabled)
			UM_OnPluginEnabled();
		else
			UM_OnPluginDisabled();
	}
}

public void OnCvarChange_Notify(ConVar cVar, const char[] sOldVal, const char[] sNewVal)
{
	g_bCvarNotify = GetConVarBool(cVar);
}

public void OnCvarChange_NoVotes(ConVar cVar, const char[] sOldVal, const char[] sNewVal)
{
	g_bCvarNoVotes = GetConVarBool(cVar);
}

public void OnCvarChange_Attempts(ConVar cVar, const char[] sOldVal, const char[] sNewVal)
{
	g_iCvarAttempts = GetConVarInt(cVar);
}

public void OnCvarChange_Time(ConVar cVar, const char[] sOldVal, const char[] sNewVal)
{
	g_fCvarTime = GetConVarFloat(cVar);
}