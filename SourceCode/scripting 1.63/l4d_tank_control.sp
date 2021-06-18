#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <colors>
#include <left4downtown>
#include <l4d_direct>
#undef REQUIRE_PLUGIN
#include <l4d_lib>

#define CVAR_FLAGS			FCVAR_PLUGIN|FCVAR_NOTIFY

native Is_Ready_Plugin_On();

static	queuedTank, String:tankSteamId[32], Handle:hTeamTanks, Handle:hTeamFinalTanks, Handle:g_hCvarInfLimit;
static		bool:IsSecondTank,bool:IsFinal,bool:LinuxIsSecondTank,bool:LinuxIsfirstTank;	
static Handle:sdkReplaceWithBot = INVALID_HANDLE;
static const String:GAMEDATA_FILENAME[]             = "l4daddresses";
static Handle:hPreviousMapTeamTanks;
static Float:g_fTankData_origin[3],Float:g_fTankData_angel[3];
public Plugin:myinfo = {
	name = "L4D Tank Control",
	author = "Jahze, vintik, raziEiL [disawar1], Harry Potter",
	version = "2.0",
	description = "Forces each player to play the tank at least once before Map change."
};

static bool:g_bCvartankcontroldisable,Handle:hCvarFlags;
static bool:resuce_start = false;
static String:previousmap[128];

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
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
	Require_L4D();
	g_hCvarInfLimit = FindConVar("z_max_player_zombies");
	
	hCvarFlags = CreateConVar("tank_control_disable", "0", "if set, no Forces each player to play the tank at once,1=disabled", CVAR_FLAGS, true, 0.0, true, 1.0);
	
	HookEvent("player_team", TC_ev_OnTeamChange);
	HookEvent("player_left_start_area", TC_ev_LeftStartAreaEvent, EventHookMode_PostNoCopy);
	HookEvent("round_start", TC_ev_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("finale_start", Event_Finale_Start);
	//for linux
	if(IsWindowsOrLinux() == 2)
	{
		HookEvent("tank_spawn", TC_ev_TankSpawn, EventHookMode_PostNoCopy);
		PrepSDKCalls();
	}
	
	HookConVarChange(hCvarFlags, OnCvarChange_tank_control_disable);
	
	RegConsoleCmd("sm_tank", Command_FindNexTank);
	RegConsoleCmd("sm_t", Command_FindNexTank);
	RegConsoleCmd("sm_boss", Command_FindNexTank);
	RegAdminCmd("sm_settankplayer", Command_SetTank, ADMFLAG_BAN, "sm_settank <player> - force this player will become the tank");
	RegAdminCmd("sm_clearteam", ClearTeam_Cmd, ADMFLAG_BAN, "clear who_has_been_tank_arraylist for both team, useful when map change.");
	
	hTeamTanks = CreateArray(64);
	hTeamFinalTanks = CreateArray(64);
	
	g_bCvartankcontroldisable = GetConVarBool(hCvarFlags);
	
	hPreviousMapTeamTanks = CreateArray(8);
	strcopy(previousmap, sizeof(previousmap), "");
	
	LoadTranslations("common.phrases");
}

stock Require_L4D()
{
    decl String:game[32];
    GetGameFolderName(game, sizeof(game));
    if (!StrEqual(game, "left4dead", false))
    {
        SetFailState("Plugin supports Left 4 Dead 1 only.");
    }
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
	new player_id;
	new String:player[64];
	GetCmdArg(1, player, sizeof(player));
	
	player_id = FindTarget(client, player, true /*nobots*/, false /*immunity*/);
	
	if(player_id == -1)
		return Plugin_Handled;	
	
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
	if(IsNewMission()||Is_First_Stage())
	{
		ClearArray(hTeamTanks);
		ClearArray(hTeamFinalTanks);
		ClearArray(hPreviousMapTeamTanks);
		GetCurrentMap(previousmap, sizeof(previousmap));
		return;
	}
	IsFinal = (IsFinalMap())? true: false;
	
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

public Action:TC_ev_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	queuedTank = 0;
	resuce_start = false;
	IsSecondTank = false;
	LinuxIsSecondTank = false;
	LinuxIsfirstTank = true;
}

bool:Is_First_Stage()//非官方圖第一關
{
	decl String:mapbuf[32];
	GetCurrentMap(mapbuf, sizeof(mapbuf));
	if(StrEqual(mapbuf, "l4d_vs_city17_01")||
	StrEqual(mapbuf, "l4d_vs_deadflagblues01_city")||
	StrEqual(mapbuf, "l4d_vs_stadium1_apartment")||
	StrEqual(mapbuf, "l4d_ihm01_forest")||
	StrEqual(mapbuf, "l4d_dbd_citylights")||
	StrEqual(mapbuf, "l4d_jsarena01_town"))
		return true;
	return false;
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

public Action:L4D_OnTryOfferingTankBot(tank_index, &bool:enterStatis)
{
	if (IsPluginDisabled()) 
		return Plugin_Continue;

	if(resuce_start)
	{
		new Handle:BlockFirstTank = FindConVar("no_final_first_tank");
		if(BlockFirstTank != INVALID_HANDLE)
		{
			if(GetConVarInt(BlockFirstTank) == 1)
			{
				resuce_start = false;
				return Plugin_Continue;
			}
		}
	}
	
	
	if(tank_index<=0) return Plugin_Continue;
	if (!IsFakeClient(tank_index)){

		for (new i=1; i <= MaxClients; i++) {
			if (!IsClientInGame(i))
				continue;

			if (GetClientTeam(i) == 2)
				continue;

			if(L4DDirect_GetTankPassedCount() >= 2)
				return Plugin_Continue;	
				
			decl String:tank_indexName[128];
			GetClientName(tank_index,tank_indexName,128);
			CPrintToChat(i, "%T","l4d_tank_control5",i, tank_indexName);
			if (GetClientTeam(i) == 1)
				continue;
			CPrintToChat(i, "%T","l4d_tank_control6",i);
		}
		SetTankFrustration(tank_index, 100);
		L4DDirect_SetTankPassedCount(L4DDirect_GetTankPassedCount() + 1);

		return Plugin_Handled;
	}

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

		GetClientAuthString(queuedTank, tankSteamId, sizeof(tankSteamId));
		
		if(HasBeenTank(tankSteamId) == false)
			PushArrayString(hTeamTanks, tankSteamId);
		if(IsFinal)
			PushArrayString(hTeamFinalTanks, tankSteamId);
			
		PushArrayString(hPreviousMapTeamTanks, tankSteamId);

		queuedTank = 0;
	}
	IsSecondTank = true;//已經第一隻Tank了
	return Plugin_Continue;
}

public Action:TC_ev_TankSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (IsPluginDisabled() || resuce_start || LinuxIsSecondTank || ThereAreNoInfectedPlayers()) 
		return;

	new tankclient = GetClientOfUserId(GetEventInt(event, "userid"));
	if(IsFakeClient(tankclient))
	{
		if(LinuxIsfirstTank)
		{
			LinuxIsfirstTank = false;
			GetEntPropVector(tankclient, Prop_Send, "m_angRotation", g_fTankData_angel);
			GetEntPropVector(tankclient, Prop_Send, "m_vecOrigin", g_fTankData_origin);
			KickClient(tankclient);

			CreateTimer(0.1,AutoSpawnTank,TIMER_FLAG_NO_MAPCHANGE);
		}
		else
		{
			TeleportEntity(tankclient, g_fTankData_origin, g_fTankData_angel, NULL_VECTOR);
			LinuxIsSecondTank = true;
		
			for (new index; index < 3; index++){
				g_fTankData_origin[index] = 0.0;
				g_fTankData_angel[index] = 0.0;
			}
		}
	}
	
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
				GetClientAuthString(i, SteamId, sizeof(SteamId));

				if(HasBeenTank(SteamId) == false)
					PushArrayString(hTeamTanks, SteamId);
				if(IsFinal)
					PushArrayString(hTeamFinalTanks, SteamId);

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

		GetClientAuthString(i, SteamId, sizeof(SteamId));

		if (HasBeenFinalTank(SteamId) || i == queuedTank) {
			continue;
		}

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

		GetClientAuthString(i, SteamId, sizeof(SteamId));

		if (HasBeenTank(SteamId) || i == queuedTank) {
			continue;
		}

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
				L4DDirect_SetTankTickets(i, 1000);
			}
			else {
				L4DDirect_SetTankTickets(i, 0);
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

		GetClientAuthString(i, cmpSteamId, sizeof(cmpSteamId));

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

		GetClientAuthString(i, cmpSteamId, sizeof(cmpSteamId));

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
	return GetConVarInt(g_hCvarInfLimit) == 1;
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

stock IsWindowsOrLinux()
{
     new Handle:conf = LoadGameConfigFile("windowsorlinux");
     new WindowsOrLinux = GameConfGetOffset(conf, "WindowsOrLinux");
     CloseHandle(conf);
     return WindowsOrLinux; //1 for windows; 2 for linux
}

public Action:Event_Finale_Start(Handle:event, const String:name[], bool:dontBroadcast)
{
	resuce_start = true;
}

PrepSDKCalls()
{
    new Handle:ConfigFile = LoadGameConfigFile(GAMEDATA_FILENAME);
    new Handle:MySDKCall = INVALID_HANDLE;
    
    StartPrepSDKCall(SDKCall_Player);
    PrepSDKCall_SetFromConf(ConfigFile, SDKConf_Signature, "ReplaceWithBot");
    PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
    MySDKCall = EndPrepSDKCall();
    
    if (MySDKCall == INVALID_HANDLE)
    {
        SetFailState("Cant initialize ReplaceWithBot SDKCall");
    }
    
    sdkReplaceWithBot = CloneHandle(MySDKCall, sdkReplaceWithBot);

	
    CloseHandle(ConfigFile);
    CloseHandle(MySDKCall);
}

stock L4DD_ReplaceWithBot(client, boolean)
{
    SDKCall(sdkReplaceWithBot, client, boolean);
}

stock L4DD_ReplaceTank(client, target)
{
    L4DDirect_ReplaceTank(client,target);
}

public Action:AutoSpawnTank(Handle:timer)
{
	if(IsTankInGame()) 
	{
		//LogMessage("there is a tank already");
		return;
	}
	
	//LogMessage("AutoSpawnTank timer event");
	
	new bool:resetGhost[MAXPLAYERS+1];
	new bool:resetLife[MAXPLAYERS+1];
	
	for (new i=1;i<=MaxClients;i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i)) // player is connected and is not fake and it's in game ...
		{
			// If player is on infected's team and ...
			if (GetClientTeam(i) == 3)
			{
				// If player is a ghost ....
				if (IsPlayerGhost(i))
				{
					resetGhost[i] = true;
					SetGhostStatus(i, false);
				}
				else if (!PlayerIsAlive(i)) // if player is just dead
				{
					resetLife[i] = true;
					SetLifeState(i, false);
				}
			}
		}
	}
	new anyclient = GetAnyClient();
	new bool:temp = false;
	if (anyclient == -1)
	{
		// we create a fake client
		anyclient = CreateFakeClient("Bot");
		if (!anyclient)
		{
			LogError("[L4D] Infected Bots: CreateFakeClient returned 0 -- Infected bot was not spawned");
			return;	
		}
		temp = true;
	}

	CheatCommand(anyclient, "z_spawn", "tank auto");
	// We restore the player's status
	for (new i=1;i<=MaxClients;i++)
	{
		if (resetGhost[i] == true)
			SetGhostStatus(i, true);
		if (resetLife[i] == true)
			SetLifeState(i, true);
	}
	// If client was temp, we setup a timer to kick the fake player
	if (temp) CreateTimer(0.1,KickBot,anyclient);
	CreateTimer(0.1, AutoSpawnTank, TIMER_FLAG_NO_MAPCHANGE);
}

stock GetAnyClient() 
{ 
	for (new target = 1; target <= MaxClients; target++) 
	{ 
		if (IsClientInGame(target)&&GetClientTeam(target)==2) return target; 
	} 
	return -1; 
} 

CheatCommand(client, String:command[], String:arguments[] = "")
{
	new flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", command, arguments);
	SetCommandFlags(command, flags);
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

bool:PlayerIsAlive (client)
{
	if (!GetEntProp(client,Prop_Send, "m_lifeState"))
		return true;
	return false;
}

IsTankInGame()
{
	for (new i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerTank(i) && IsInfectedAlive(i) && !IsIncapacitated(i))
			return i;

	return 0;
}

bool:ThereAreNoInfectedPlayers()
{
	for (new i = 1; i < MaxClients+1; i++)
		if(IsClientInGame(i)&&!IsFakeClient(i)&&GetClientTeam(i)==3)
			return false;
	return true;
}