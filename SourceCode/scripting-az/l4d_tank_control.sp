#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <multicolors>
#include <left4dhooks>
#include <l4d_lib>

#define CVAR_FLAGS			FCVAR_NOTIFY

native Is_Ready_Plugin_On();

static	queuedTank, String:tankSteamId[32], Handle:hTeamTanks, Handle:hTeamFinalTanks;
ConVar g_hCvarInfLimit, g_hCvarSurLimit;
static		bool:IsSecondTank,bool:IsFinal;	
static Handle:hPreviousMapTeamTanks;
public Plugin:myinfo = {
	name = "L4D Tank Control",
	author = "Jahze, vintik, raziEiL [disawar1], Harry Potter",
	version = "2.3",
	description = "Forces each player to play the tank at least once before Map change."
};

static bool:g_bCvartankcontroldisable,Handle:hCvarFlags;
static String:previousmap[128];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();

	if( test != Engine_Left4Dead )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1.");
		return APLRes_SilentFailure;
	}

	CreateNative("ChoseTankPrintWhoBecome", Native_ChoseTankPrintWhoBecome);
	CreateNative("WhoIsTank", Native_WhoIsTank);
	return APLRes_Success;
}

public Native_WhoIsTank(Handle:plugin, numParams)
{
	return queuedTank;
}

public Native_ChoseTankPrintWhoBecome(Handle:plugin, numParams)
{
	if (IsPluginDisabled()) return;
	
	if(queuedTank > 0 && IsClientInGame(queuedTank) && GetClientTeam(queuedTank) == 3)
	{
		decl String:queuedTankName[128];
		GetClientName(queuedTank,queuedTankName,128);
		CPrintToChatAll("%t","player will be the tank", queuedTankName); 
	}
	else
		ChoseTankAndPrintWhoBecome();
}

public OnPluginStart()
{
	LoadTranslations("Roto2-AZ_mod.phrases");
	g_hCvarInfLimit = FindConVar("z_max_player_zombies");
	g_hCvarSurLimit = FindConVar("survivor_limit");
	
	hCvarFlags = CreateConVar("tank_control_disable", "0", "if set, no Forces each player to play the tank at once,1=disabled", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_bCvartankcontroldisable = GetConVarBool(hCvarFlags);
	HookConVarChange(hCvarFlags, OnCvarChange_tank_control_disable);

	HookEvent("player_team", TC_ev_OnTeamChange);
	HookEvent("player_left_start_area", TC_ev_LeftStartAreaEvent, EventHookMode_PostNoCopy);
	HookEvent("round_start", TC_ev_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_spawn", TC_ev_PlayerSpawn);
	
	RegConsoleCmd("sm_tank", Command_FindNexTank);
	RegConsoleCmd("sm_t", Command_FindNexTank);
	RegConsoleCmd("sm_boss", Command_FindNexTank);
	RegAdminCmd("sm_settankplayer", Command_SetTank, ADMFLAG_BAN, "sm_settank <player> - force this player will become the tank");
	RegAdminCmd("sm_clearteam", ClearTeam_Cmd, ADMFLAG_BAN, "clear who_has_been_tank_arraylist for both team, useful when map change.");
	
	hTeamTanks = CreateArray(64);
	hTeamFinalTanks = CreateArray(64);
	
	hPreviousMapTeamTanks = CreateArray(8);
	strcopy(previousmap, sizeof(previousmap), "");
	
	LoadTranslations("common.phrases");
}

public TC_ev_LeftStartAreaEvent(Handle:event, String:name[], bool:dontBroadcast)
{
	if(!Is_Ready_Plugin_On())
		ChoseTankAndPrintWhoBecome();
}

public Action:Command_SetTank(client, args)
{
	if (args < 1 || args > 1)
	{
		ReplyToCommand(client, "[TS] Usage: sm_settankplayer <player> - %T","force this player will become the tank",client);
		return Plugin_Handled;
	}
	if(IsPluginDisabled())
	{
		ReplyToCommand(client, "[TS] %T","l4d_tank_control1",client);
		return Plugin_Handled;
	}

	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	char arg[65];
	GetCmdArg(1, arg, sizeof(arg));
	if ((target_count = ProcessTargetString(
			arg,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_NO_BOTS,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	int player_id = target_list[0];
	
	decl String:player_idName[128];
	GetClientName(player_id,player_idName,128);
	if(GetClientTeam(player_id) != 3)
	{
		ReplyToCommand(client, "[TS] %T","target is not in infected team",client,player_idName);
		return Plugin_Handled;
	}
	
	queuedTank = player_id;
	decl String:queuedTankName[128];
	GetClientName(queuedTank,queuedTankName,128);
	CPrintToChatAll("%t","l4d_tank_control2", queuedTankName); 
	
	return Plugin_Handled;	
}

public Action:Command_FindNexTank(client, args)
{
	if (client<=0 || IsPluginDisabled()) return Plugin_Handled;

	new iTeam = GetClientTeam(client);

	if(queuedTank== -2)
		ChooseTank();
	if(queuedTank== -1 && iTeam !=2){
		CPrintToChat(client, "%T","l4d_tank_control3",client); 
	}
	else if (queuedTank>0)
	{
		decl String:queuedTankName[128];
		GetClientName(queuedTank,queuedTankName,128);
		CPrintToChat(client, "%T","player will be the tank",client, queuedTankName); 
	}
	
	
	PrintTankOwners(client);
	return Plugin_Handled;
}

PrintTankOwners(client)//給玩家debug用,查看那些人已經當過tank
{
	new iMaxArray = GetArraySize(hTeamTanks);
	new iMaxArrayFinal = GetArraySize(hTeamFinalTanks);
	decl String:sTankSteamId[64], i;

	PrintToConsole(client, "The tanks were in control of:");
	
	for (new iIndex; iIndex < iMaxArray; iIndex++){

		GetArrayString(hTeamTanks, iIndex, sTankSteamId, sizeof(sTankSteamId));
		if ((i= GetPlayerBySteamId(sTankSteamId))){

			PrintToConsole(client, "0%d. %N [%s]", iIndex + 1, i, sTankSteamId);
		}
		else
			PrintToConsole(client, "0%d. (left the team) [%s]", iIndex + 1, sTankSteamId);
			
	}
	
	if(IsFinal){
		PrintToConsole(client, "The Final tanks were in control of:");
		
		for (new iIndex; iIndex < iMaxArrayFinal; iIndex++){

			GetArrayString(hTeamFinalTanks, iIndex, sTankSteamId, sizeof(sTankSteamId));
			if ((i= GetPlayerBySteamId(sTankSteamId))){

				PrintToConsole(client, "0%d. %N [%s]", iIndex + 1, i, sTankSteamId);
			}
			else
				PrintToConsole(client, "0%d. (left the team) [%s]", iIndex + 1, sTankSteamId);
				
		}
	}
}

public OnMapStart()//每個地圖的第一關載入時清除所有has been tank list
{
	if(L4D_IsFirstMapInScenario())
	{
		ClearArray(hTeamTanks);
		ClearArray(hTeamFinalTanks);
		ClearArray(hPreviousMapTeamTanks);
		GetCurrentMap(previousmap, sizeof(previousmap));
		return;
	}
	IsFinal = (L4D_IsMissionFinalMap())? true: false;
	
	decl String:currentmap[128];
	GetCurrentMap(currentmap, sizeof(currentmap));
	if(StrEqual(currentmap, previousmap))
	{
		new iMaxArray = GetArraySize(hPreviousMapTeamTanks);
		decl String:sTankSteamId[64], i;
		for (new iIndex; iIndex < iMaxArray; iIndex++)
		{
			GetArrayString(hPreviousMapTeamTanks, iIndex, sTankSteamId, sizeof(sTankSteamId));//前地圖當過坦克的玩家
			if( (i = FindStringInArray(hTeamTanks,sTankSteamId)) != -1)
				RemoveFromArray(hTeamTanks,i);
			if(IsFinal)
			{
				if( (i = FindStringInArray(hTeamFinalTanks,sTankSteamId)) != -1)
					RemoveFromArray(hTeamFinalTanks,i);
			}
		}		
	}
	strcopy(previousmap, sizeof(previousmap),currentmap);
	ClearArray(hPreviousMapTeamTanks);
}

public void TC_ev_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client && IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == 3 && IsPlayerAlive(client) && IsPlayerTank(client))
	{
		queuedTank = 0;
	}
}

public Action:TC_ev_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	queuedTank = 0;
	IsSecondTank = false;
}

public TC_ev_OnTeamChange(Handle:event, String:name[], bool:dontBroadcast)
{
	if (IsPluginDisabled()) return;

	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	CreateTimer(1.0,PlayerChangeTeamCheck,client);//延遲一秒檢查
}
public Action:PlayerChangeTeamCheck(Handle:timer,any:client)
{
	if (client && client == queuedTank)
		if(!IsClientInGame(client) || GetClientTeam(client)!=3)
			ChoseTankAndPrintWhoBecome();
}
public OnClientDisconnect(client)
{
	if (IsPluginDisabled()) return;

	if (client && client == queuedTank)
		ChoseTankAndPrintWhoBecome();
}

ChoseTankAndPrintWhoBecome()
{
	if (IsPluginDisabled()) return;
	ChooseTank();
	if (queuedTank>0) {
		decl String:queuedTankName[128];
		GetClientName(queuedTank,queuedTankName,128);
		CPrintToChatAll("%t","player will be the tank", queuedTankName); 
	}
	else if (queuedTank==-1){
		CPrintToChatAll("%t","l4d_tank_control3"); 
	}
	else if (queuedTank==-2){
		CPrintToChatAll("%t","l4d_tank_control4");
	}
}

public Action L4D_OnTryOfferingTankBot(int tank_index, bool &enterStasis)
{
	if(IsPluginDisabled()) return Plugin_Continue;

	if(L4D2Direct_GetTankPassedCount() >= 2)
		return Plugin_Continue;	

	if (tank_index && IsClientInGame(tank_index) && !IsFakeClient(tank_index)){
		for (int i=1; i <= MaxClients; i++) {
			if (!IsClientInGame(i))
				continue;

			if (GetClientTeam(i) == 2)
				continue;
				
			static char tank_indexName[128];
			GetClientName(tank_index,tank_indexName,128);
			CPrintToChat(i, "%T","l4d_tank_control5",i, tank_indexName);
			if (GetClientTeam(i) == 1) continue;

			CPrintToChat(i, "%T","l4d_tank_control6",i);
		}
		SetTankFrustration(tank_index, 100);
		L4D2Direct_SetTankPassedCount(L4D2Direct_GetTankPassedCount() + 1);

		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public void L4D_OnTryOfferingTankBot_Post(int tank_index, bool enterStasis)
{
	if (IsPluginDisabled()) 
		return;

	if(L4D2Direct_GetTankPassedCount() >= 1)
		return;	

	if(IsSecondTank && queuedTank<=0)//第二隻克以後
	{
		ChooseTank();
		if(queuedTank == -1 && IsFinal) //最後一關所有人都當過另外重新輪盤 第二隻以後的克皆是不同的人當
			ChooseFinalTank();
	}
	else if (queuedTank == -2)//本來特感沒有人 現在克復活再選一次人
	{
		ChooseTank();
	}
	else if (queuedTank == -1)//自由搶第一隻克
	{
		CreateTimer(5.0, CheckForAITank, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	if (queuedTank>0){
		ForceTankPlayer(queuedTank);//強制該玩家當tank

		GetClientAuthId(queuedTank, AuthId_Steam2, tankSteamId, sizeof(tankSteamId));
		
		if(HasBeenTank(tankSteamId) == false)
		{
			if(FindStringInArray(hTeamTanks, tankSteamId) == -1)
				PushArrayString(hTeamTanks, tankSteamId);
		}
		if(IsFinal)
		{
			if(FindStringInArray(hTeamFinalTanks, tankSteamId) == -1)
				PushArrayString(hTeamFinalTanks, tankSteamId);
		}
			
		if(FindStringInArray(hPreviousMapTeamTanks, tankSteamId) == -1)
			PushArrayString(hPreviousMapTeamTanks, tankSteamId);
	}
	IsSecondTank = true;//已經第一隻Tank了
}

public Action:KickBot(Handle:timer, any:client)
{
	if ( client && IsClientInGame(client) && IsFakeClient(client))
	{
		KickClient(client);
	}
}

public Action:CheckForAITank(Handle:timer)
{

	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 3 && GetEntProp(i, Prop_Send, "m_zombieClass") == 5)
		{
			if (!IsFakeClient(i))//Tank is not AI
			{
				decl String:SteamId[32];
				GetClientAuthId(i, AuthId_Steam2, SteamId, sizeof(SteamId));

				if(HasBeenTank(SteamId) == false)
				{
					if(FindStringInArray(hTeamTanks, tankSteamId) == -1)
						PushArrayString(hTeamTanks, tankSteamId);
				}
				if(IsFinal)
				{
					if(FindStringInArray(hTeamFinalTanks, SteamId) == -1)
						PushArrayString(hTeamFinalTanks, SteamId);
				}

			}
			return Plugin_Handled;
		}
	}
	return Plugin_Handled;
}

static ChooseFinalTank() {

	decl String:SteamId[32];
	new Handle:SteamIds = CreateArray(32);
	new infectedplayer = 0;

	for (new i = 1; i < MaxClients+1; i++) {
		if (!IsClientConnected(i) || !IsClientInGame(i) ||IsFakeClient(i)) {
			continue;
		}
		if(IsInfected(i))
			infectedplayer++;
		
		if(!IsInfected(i))
			continue;

		GetClientAuthId(i, AuthId_Steam2, SteamId, sizeof(SteamId));

		if (HasBeenFinalTank(SteamId) || i == queuedTank) {
			continue;
		}

		if(FindStringInArray(SteamIds, SteamId) == -1)
			PushArrayString(SteamIds, SteamId);
	}

	if (GetArraySize(SteamIds) == 0) {//沒有人可以成為tank
		if(infectedplayer == 0)//1.SI沒有人
			queuedTank = -2;
		else//2.代表兩邊的隊伍都找過 特感這裡所有人都當過tank
			queuedTank = -1;
		return;
	}

	new idx = GetRandomInt(0, GetArraySize(SteamIds)-1);
	GetArrayString(SteamIds, idx, tankSteamId, sizeof(tankSteamId));
	queuedTank = GetInfectedPlayerBySteamId(tankSteamId);
}

static bool:HasBeenFinalTank(const String:SteamId[])
{
	if(FindStringInArray(hTeamFinalTanks, SteamId) != -1)
		return true;
	else
		return false;
}

static bool:HasBeenTank(const String:SteamId[])
{
	if(FindStringInArray(hTeamTanks, SteamId) != -1)
		return true;
	else
		return false;
}

static ChooseTank() {

	decl String:SteamId[32];
	new Handle:SteamIds = CreateArray(32);
	new infectedplayer = 0;

	for (new i = 1; i < MaxClients+1; i++) {
		if (!IsClientConnected(i) || !IsClientInGame(i) ||IsFakeClient(i)) {
			continue;
		}
		if(IsInfected(i))
			infectedplayer++;
		
		if(!IsInfected(i))
			continue;

		GetClientAuthId(i, AuthId_Steam2, SteamId, sizeof(SteamId));

		if (HasBeenTank(SteamId) || i == queuedTank) {
			continue;
		}

		if(FindStringInArray(SteamIds, SteamId) == -1)
			PushArrayString(SteamIds, SteamId);
	}

	if (GetArraySize(SteamIds) == 0) {//沒有人可以成為tank
		if(infectedplayer == 0)//1.SI沒有人
			queuedTank = -2;
		else//2.代表兩邊的隊伍都找過 特感這裡所有人都當過tank
			queuedTank = -1;
		return;
	}

	new idx = GetRandomInt(0, GetArraySize(SteamIds)-1);
	GetArrayString(SteamIds, idx, tankSteamId, sizeof(tankSteamId));
	queuedTank = GetInfectedPlayerBySteamId(tankSteamId);
}

static ForceTankPlayer(iTank) {
	for (new i = 1; i < MaxClients+1; i++) {
		if (!IsClientConnected(i) || !IsClientInGame(i)) {
			continue;
		}

		if (IsInfected(i)) {
			if (iTank == i) {
				L4D2Direct_SetTankTickets(i, 1000);
			}
			else {
				L4D2Direct_SetTankTickets(i, 0);
			}
		}
	}
}

static GetInfectedPlayerBySteamId(const String:SteamId[]) {
	decl String:cmpSteamId[32];

	for (new i = 1; i < MaxClients+1; i++) {
		if (!IsClientConnected(i)) {
			continue;
		}

		if (!IsInfected(i)) {
			continue;
		}

		GetClientAuthId(i, AuthId_Steam2, cmpSteamId, sizeof(cmpSteamId));

		if (StrEqual(SteamId, cmpSteamId)) {
			return i;
		}
	}

	return 0;
}

static GetPlayerBySteamId(const String:SteamId[]) {
	decl String:cmpSteamId[32];

	for (new i = 1; i < MaxClients+1; i++) {
		if (!IsClientConnected(i)) {
			continue;
		}

		GetClientAuthId(i, AuthId_Steam2, cmpSteamId, sizeof(cmpSteamId));

		if (StrEqual(SteamId, cmpSteamId)) {
			return i;
		}
	}

	return 0;
}

bool:IsPluginDisabled()
{
	if(g_bCvartankcontroldisable)
		return true;
	return (g_hCvarInfLimit.IntValue == 1 || g_hCvarSurLimit.IntValue == 1);
}


public OnCvarChange_tank_control_disable(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (!StrEqual(oldValue, newValue))
		g_bCvartankcontroldisable = GetConVarBool(convar);	
}

public Action:ClearTeam_Cmd(client, args)
{
	if(IsPluginDisabled())
		return;
	ClearArray(hTeamTanks);
	ClearArray(hTeamFinalTanks);
	ClearArray(hPreviousMapTeamTanks);	
	
	ReplyToCommand(client,"[TS] %T","Tank Control has been clear and reset!",client);
}