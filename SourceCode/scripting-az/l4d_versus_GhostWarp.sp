#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <left4dhooks>
#include <multicolors>

#define PLUGIN_TAG					"[GhostWarp]"
#define PLUGIN_TAG_COLOR			"\x01[\x05TS\x01]"

#if SOURCEMOD_V_MINOR > 9
enum struct eSurvFlow
{
	int eiSurvivorIndex;
	float efSurvivorFlow;
}
#else
enum eSurvFlow
{
	eiSurvivorIndex,
	Float:efSurvivorFlow
};
#endif

enum
{
	eAllowCommand	= (1 << 0),
	eAllowButton	= (1 << 1),

	eAllowAll		= (1 << 0)|(1 << 1)
};

int
	g_iLastTargetSurvivor[MAXPLAYERS + 1] = {0, ...};

float
	g_fGhostWarpDelay[MAXPLAYERS + 1] = {0.0, ...};

StringMap
	g_hNameToCharIDTrie = null;

ConVar
	g_hCvarSurvivorLimit = null,
	g_hCvarGhostWarpDelay = null,
	g_hCvarGhostWarpFlag = null;

bool DisableGhostM2Teleport[MAXPLAYERS+1];
int g_iSurvivorIndex[MAXPLAYERS+1], g_iSurvivorCount;

enum
{
	L4DNameId_Nanvet			= 0, //Bill
	L4DNameId_TeenGirl			= 1, //Zoey
	L4DNameId_Biker				= 2, //Francis
	L4DNameId_Manager			= 3, //Louis
	
	L4DNameId_MaxSize //4 size
};

public Plugin myinfo =
{
	name = "Infected Warp",
	author = "Confogl Team, CanadaRox, A1m`, HarryPotter",
	description = "Allows infected to warp to survivors",
	version = "2.5",
	url = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

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

public void OnPluginStart()
{
	LoadTranslations("Roto2-AZ_mod.phrases");

	InitTrie();

	g_hCvarGhostWarpFlag = CreateConVar( \
		"l4d_ghost_warp_flag", \
		"3", \
		"Enable|Disable ghost warp. 0 - disable, 1 - enable warp via command 'sm_warpto', 2 - enable warp via button 'IN_ATTACK2', 3 - enable all.", \
		_, true, 0.0, true, float(eAllowAll)
	);

	g_hCvarGhostWarpDelay = CreateConVar( \
		"l4d_ghost_warp_delay", \
		"0.35", \
		"After how many seconds can ghost warp be reused. 0.0 - delay disabled (maximum delay 120 seconds).", \
		_, true, 0.0, true, 120.0
	);

	g_hCvarSurvivorLimit = FindConVar("survivor_limit");

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_disconnect", 	Event_PlayerDisconnect);
	HookEvent("player_team", Event_PlayerTeamChange);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);

	RegConsoleCmd("sm_warptosurvivor", Cmd_WarpToSurvivor);
	RegConsoleCmd("sm_warpto", Cmd_WarpToSurvivor);
	RegConsoleCmd("sm_warp", Cmd_WarpToSurvivor);

	RegConsoleCmd("sm_warpm2on",	Enable_Cmd, "Enable the ghost m2 teleport");
	RegConsoleCmd("sm_warpm2off",	Disable_Cmd, "Disable the ghost m2 teleport");
}

void InitTrie()
{
	g_hNameToCharIDTrie = new StringMap();

	g_hNameToCharIDTrie.SetValue("bill", L4DNameId_Nanvet);
	g_hNameToCharIDTrie.SetValue("zoey", L4DNameId_TeenGirl);
	g_hNameToCharIDTrie.SetValue("louis", L4DNameId_Manager);
	g_hNameToCharIDTrie.SetValue("francis", L4DNameId_Biker);
}

public Action Disable_Cmd(int client, int args)
{
	if(client == 0) return Plugin_Handled;

	if(GetClientTeam(client) != L4D_TEAM_INFECTED) return Plugin_Handled;

	DisableGhostM2Teleport[client] = true;

	CPrintToChat(client, "[{olive}TS{default}] Ghost M2 Teleport {green}Disabled.");

	return Plugin_Handled;
}

public Action Enable_Cmd(int client, int args)
{
	if(client == 0) return Plugin_Handled;

	if(GetClientTeam(client) != L4D_TEAM_INFECTED) return Plugin_Handled;

	DisableGhostM2Teleport[client] = false;

	CPrintToChat(client, "[{olive}TS{default}] Ghost M2 Teleport {green}Enabled.");

	return Plugin_Handled;
}

public void Event_PlayerTeamChange(Event event, const char[] name, bool dontBroadcast)//有人跳隊到則reset
{
	if(event.GetInt("oldteam") == L4D_TEAM_SURVIVOR || event.GetInt("team") == L4D_TEAM_SURVIVOR) //從survivor隊伍跳隊 或 跳隊到sur
		CreateTimer(0.1, PlayerChangeTeamCheck);//延遲
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(client && IsClientInGame(client) && GetClientTeam(client) == L4D_TEAM_SURVIVOR) 
		CreateTimer(0.1, PlayerChangeTeamCheck);//延遲
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(client && IsClientInGame(client) && GetClientTeam(client) == L4D_TEAM_SURVIVOR) 
		CreateTimer(0.1, PlayerChangeTeamCheck);//延遲
}


public Action PlayerChangeTeamCheck(Handle timer)
{
	RebuildIndex();

	return Plugin_Continue;
}

public void Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	DisableGhostM2Teleport[client] = false;
}

public void Event_RoundStart(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	// GetGameTime (gpGlobals->curtime) starts from scratch every map.
	// Let's clean this up

	for (int iClient = 1; iClient <= MaxClients; iClient++) {
		g_iLastTargetSurvivor[iClient] = 0;
		g_fGhostWarpDelay[iClient] = 0.0;
	}

	RebuildIndex();
}

public void L4D_OnFirstSurvivorLeftSafeArea_Post(int client)
{
	RebuildIndex();
}

public Action Cmd_WarpToSurvivor(int iClient, int iArgs)
{
	if (iClient == 0) {
		ReplyToCommand(iClient, "%s This command is not available for the server!", PLUGIN_TAG);
		return Plugin_Handled;
	}

	if (!(g_hCvarGhostWarpFlag.IntValue & eAllowCommand)) {
		PrintToChat(iClient, "%s This command is \x04disabled\x01 now.", PLUGIN_TAG_COLOR);
		return Plugin_Handled;
	}

	if (GetClientTeam(iClient) != L4D_TEAM_INFECTED
		|| GetEntProp(iClient, Prop_Send, "m_isGhost", 1) < 1
		|| !IsPlayerAlive(iClient)
	) {
		PrintToChat(iClient, "%s This command is only available for \x04infected\x01 ghosts.", PLUGIN_TAG_COLOR);
		return Plugin_Handled;
	}

	if (g_fGhostWarpDelay[iClient] >= GetGameTime()) {
		PrintToChat(iClient, "%s You can't use this command that often, wait another \x04%.01f\x01 sec.", PLUGIN_TAG_COLOR, g_fGhostWarpDelay[iClient] - GetGameTime());
		return Plugin_Handled;
	}

	if (iArgs < 1) {
		if (!WarpToNextSurvivor(iClient)) {
			PrintToChat(iClient, "%s No \x04alive survivors\x01 found!", PLUGIN_TAG_COLOR);
		}

		return Plugin_Handled;
	}

	char sBuffer[9];
	GetCmdArg(1, sBuffer, sizeof(sBuffer));

	if (IsStringNumeric(sBuffer, sizeof(sBuffer))) {
		int iSurvivorFlowRank = StringToInt(sBuffer);

		if (iSurvivorFlowRank > 0 && iSurvivorFlowRank <= g_hCvarSurvivorLimit.IntValue) {
			int iSurvivorIndex = GetSurvivorOfFlowRank(iSurvivorFlowRank);

			if (iSurvivorIndex == 0) {
				PrintToChat(iClient, "%s No \x04alive survivors\x01 found!", PLUGIN_TAG_COLOR);

				return Plugin_Handled;
			}

			TeleportToSurvivor(iClient, iSurvivorIndex);

			return Plugin_Handled;
		}

		//WarpToNextSurvivor(iClient);

		char sCmdName[18];
		GetCmdArg(0, sCmdName, sizeof(sCmdName));

		PrintToChat(iClient, "%s You entered an \x04invalid\x01 alive survivor index!", PLUGIN_TAG_COLOR);
		PrintToChat(iClient, "%s Usage: \x04%s\x01 <1 - %d> - %T", PLUGIN_TAG_COLOR, sCmdName, g_hCvarSurvivorLimit.IntValue, "l4d_versus_GhostWarp", iClient);

		return Plugin_Handled;
	}

	int iId = 0;
	String_ToLower(sBuffer, sizeof(sBuffer));

	if (!g_hNameToCharIDTrie.GetValue(sBuffer, iId)) {
		//WarpToNextSurvivor(iClient);

		char sCmdName[18];
		GetCmdArg(0, sCmdName, sizeof(sCmdName));

		PrintToChat(iClient, "%s You entered the \x04wrong\x01 alive survivor name!", PLUGIN_TAG_COLOR);
		PrintToChat(iClient, "%s Usage: \x04%s\x01 <survivor name> - %T", PLUGIN_TAG_COLOR, sCmdName, "l4d_versus_GhostWarp", iClient);

		return Plugin_Handled;
	}

	int iSurvivorCount = 0;
	int iSurvivorIndex = GetClientOfCharID(iId, iSurvivorCount);

	if (iSurvivorCount == 0) {
		PrintToChat(iClient, "%s No \x04alive survivors\x01 found!", PLUGIN_TAG_COLOR);
		return Plugin_Handled;
	}

	if (iSurvivorIndex == -1) {
		PrintToChat(iClient, "%s The \x04alive survivor\x01 you specified was \x04not found\x01!", PLUGIN_TAG_COLOR);
		return Plugin_Handled;
	}

	TeleportToSurvivor(iClient, iSurvivorIndex);

	return Plugin_Handled;
}

public void L4D_OnEnterGhostState(int iClient)
{
	if (!(g_hCvarGhostWarpFlag.IntValue & eAllowButton)) {
		return;
	}

	g_iLastTargetSurvivor[iClient] = 0;
	g_fGhostWarpDelay[iClient] = 0.0;

	SDKUnhook(iClient, SDKHook_PostThinkPost, Hook_OnPostThinkPost);
	SDKHook(iClient, SDKHook_PostThinkPost, Hook_OnPostThinkPost);
}

public void Hook_OnPostThinkPost(int iClient)
{
	int iPressButtons = GetEntProp(iClient, Prop_Data, "m_afButtonPressed");

	if (DisableGhostM2Teleport[iClient]){
		return;
	}

	// Key 'IN_RELOAD' was used in plugin 'confoglcompmod', do we need it?
	if (!(iPressButtons & IN_ATTACK2)/* && !(iPressButtons & IN_RELOAD)*/) {
		return;
	}

	// For some reason, the game resets button 'IN_ATTACK2' for infected ghosts at some point.
	// So we need spam protection.
	if (g_fGhostWarpDelay[iClient] >= GetGameTime()) {
		//PrintToChat(iClient, "%s You can't use this command that often, wait another \x04%.01f\x01 sec.", PLUGIN_TAG_COLOR, g_fGhostWarpDelay[iClient] - GetGameTime());
		return;
	}

	if (GetClientTeam(iClient) != L4D_TEAM_INFECTED
		|| GetEntProp(iClient, Prop_Send, "m_isGhost", 1) < 1
		|| !IsPlayerAlive(iClient)
	) {
		SDKUnhook(iClient, SDKHook_PostThinkPost, Hook_OnPostThinkPost);
		g_iLastTargetSurvivor[iClient] = 0;

		return;
	}

	// We didn't find any survivors, is the round over?
	if (!WarpToNextSurvivor(iClient)) {
		//SDKUnhook(iClient, SDKHook_PostThinkPost, Hook_OnPostThinkPost);
		g_iLastTargetSurvivor[iClient] = 0;
	}
}

bool WarpToNextSurvivor(int iInfected)
{
	if (!g_iSurvivorCount) return false;

	int target = GetClientOfUserId(g_iSurvivorIndex[g_iLastTargetSurvivor[iInfected]]);

	if (target == 0 || !IsClientInGame(target) || GetClientTeam(target) != L4D_TEAM_SURVIVOR || !IsPlayerAlive(target)) { 
		if(++g_iLastTargetSurvivor[iInfected] == g_iSurvivorCount) g_iLastTargetSurvivor[iInfected] = 0; 
		return false;
	}

	TeleportToSurvivor(iInfected, target);

	if (++g_iLastTargetSurvivor[iInfected] == g_iSurvivorCount)
		g_iLastTargetSurvivor[iInfected] = 0;

	return true;
}

void TeleportToSurvivor(int iInfected, int iSurvivor)
{
	//~Prevent people from spawning and then warp to survivor
	SetEntProp(iInfected, Prop_Send, "m_ghostSpawnState", L4D_SPAWNFLAG_TOOCLOSE);

	float fPosition[3], fAnglestarget[3];
	GetClientAbsOrigin(iSurvivor, fPosition);
	GetClientAbsAngles(iSurvivor, fAnglestarget);

	TeleportEntity(iInfected, fPosition, fAnglestarget, NULL_VECTOR);

	g_fGhostWarpDelay[iInfected] = GetGameTime() + g_hCvarGhostWarpDelay.FloatValue;
}

int GetClientOfCharID(int characterID, int &iSurvivorCount)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && GetClientTeam(client) == L4D_TEAM_SURVIVOR && IsPlayerAlive(client))
		{
			iSurvivorCount ++;
			if (GetEntProp(client, Prop_Send, "m_survivorCharacter") == characterID)
				return client;
		}
	}
	return -1;
}

#if SOURCEMOD_V_MINOR > 9
int GetSurvivorOfFlowRank(int iRank)
{
	int iArrayIndex = iRank - 1;

	eSurvFlow strSurvArray;
	ArrayList hFlowArray = new ArrayList(sizeof(strSurvArray));

	for (int iClient = 1; iClient <= MaxClients; iClient++) {
		if (IsClientInGame(iClient) && GetClientTeam(iClient) == L4D_TEAM_SURVIVOR && IsPlayerAlive(iClient)) {
			strSurvArray.eiSurvivorIndex = iClient;
			strSurvArray.efSurvivorFlow = L4D2Direct_GetFlowDistance(iClient);

			hFlowArray.PushArray(strSurvArray, sizeof(strSurvArray));
		}
	}

	int iArraySize = hFlowArray.Length;
	if (iArraySize < 1) {
		return 0;
	}

	hFlowArray.SortCustom(sortFunc);

	if (iArrayIndex >= iArraySize) {
		iArrayIndex = iArraySize - 1;
	}

	hFlowArray.GetArray(iArrayIndex, strSurvArray, sizeof(strSurvArray));

	hFlowArray.Clear();
	delete hFlowArray;

	return strSurvArray.eiSurvivorIndex;
}

public int sortFunc(int iIndex1, int iIndex2, Handle hArray, Handle hndl)
{
	eSurvFlow strSurvArray1;
	eSurvFlow strSurvArray2;

	GetArrayArray(hArray, iIndex1, strSurvArray1, sizeof(strSurvArray1));
	GetArrayArray(hArray, iIndex2, strSurvArray2, sizeof(strSurvArray2));

	if (strSurvArray1.efSurvivorFlow > strSurvArray2.efSurvivorFlow) {
		return -1;
	} else if (strSurvArray1.efSurvivorFlow < strSurvArray2.efSurvivorFlow) {
		return 1;
	} else {
		return 0;
	}
}
#else
int GetSurvivorOfFlowRank(int iRank)
{
	int iArrayIndex = iRank - 1;

	eSurvFlow strSurvArray[eSurvFlow];
	ArrayList hFlowArray = new ArrayList(sizeof(strSurvArray));

	for (int iClient = 1; iClient <= MaxClients; iClient++) {
		if (IsClientInGame(iClient) && GetClientTeam(iClient) == L4D_TEAM_SURVIVOR && IsPlayerAlive(iClient)) {
			strSurvArray[eiSurvivorIndex] = iClient;
			strSurvArray[efSurvivorFlow] = L4D2Direct_GetFlowDistance(iClient);

			hFlowArray.PushArray(strSurvArray[0], sizeof(strSurvArray));
		}
	}

	int iArraySize = hFlowArray.Length;
	if (iArraySize < 1) {
		return 0;
	}

	SortADTArrayCustom(hFlowArray, sortFunc);

	if (iArrayIndex >= iArraySize) {
		iArrayIndex = iArraySize - 1;
	}

	hFlowArray.GetArray(iArrayIndex, strSurvArray[0], sizeof(strSurvArray));

	hFlowArray.Clear();
	delete hFlowArray;

	return strSurvArray[eiSurvivorIndex];
}

public int sortFunc(int iIndex1, int iIndex2, Handle hArray, Handle hndl)
{
	eSurvFlow strSurvArray1[eSurvFlow];
	eSurvFlow strSurvArray2[eSurvFlow];

	GetArrayArray(hArray, iIndex1, strSurvArray1[0], sizeof(strSurvArray1));
	GetArrayArray(hArray, iIndex2, strSurvArray2[0], sizeof(strSurvArray2));

	if (strSurvArray1[efSurvivorFlow] > strSurvArray2[efSurvivorFlow]) {
		return -1;
	} else if (strSurvArray1[efSurvivorFlow] < strSurvArray2[efSurvivorFlow]) {
		return 1;
	} else {
		return 0;
	}
}
#endif

bool IsStringNumeric(const char[] sString, const int MaxSize)
{
	int iSize = strlen(sString); //Сounts string length to zero terminator

	for (int i = 0; i < iSize && i < MaxSize; i++) { //more security, so that the cycle is not endless
		if (sString[i] < '0' || sString[i] > '9') {
			return false;
		}
	}

	return true;
}

void String_ToLower(char[] str, const int MaxSize)
{
	int iSize = strlen(str); //Сounts string length to zero terminator

	for (int i = 0; i < iSize && i < MaxSize; i++) { //more security, so that the cycle is not endless
		if (IsCharUpper(str[i])) {
			str[i] = CharToLower(str[i]);
		}
	}

	str[iSize] = '\0';
}

void RebuildIndex()
{
	g_iSurvivorCount = 0;

	if (!IsServerProcessing()) return;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == L4D_TEAM_SURVIVOR && IsPlayerAlive(i))
		{
			//PrintToChatAll("%d - %N", g_iSurvivorCount, i);
			g_iSurvivorIndex[g_iSurvivorCount] = GetClientUserId(i);
			g_iSurvivorCount++;
		}
	}
}