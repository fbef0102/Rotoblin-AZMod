#pragma semicolon 1

#include <sourcemod>
#include <colors>
#include <sdktools>
#undef REQUIRE_PLUGIN
#define SCORE_DELAY_EMPTY_SERVER 3.0
#define ZOMBIECLASS_SMOKER 1
#define ZOMBIECLASS_BOOMER 2
#define ZOMBIECLASS_HUNTER 3
#define ZOMBIECLASS_SPITTER 4
#define ZOMBIECLASS_JOCKEY 5
#define ZOMBIECLASS_CHARGER 6
#define ZOMBIECLASS_TANK 8
#define MaxHealth 100
#define VOTE_NO "no"
#define VOTE_YES "yes"
#define L4D_MAXCLIENTS_PLUS1 (MaxClients+1)
#define MENU_TIME 20
new Votey = 0;
new Voten = 0;
new String:ReadyMode[64];
new String:Label[16];//ready 開啟/關閉
new String:swapplayer[MAX_NAME_LENGTH];
new String:swapplayername[MAX_NAME_LENGTH];
new String:votesmaps[MAX_NAME_LENGTH];
new String:votesmapsname[64];
Menu g_hVoteMenu = null;

new Handle:g_Cvar_Limits;
new Handle:cvarFullResetOnEmpty;
new Handle:VotensReadyED;
new Handle:VotensHpED;
new Handle:VotensAlltalkED;
new Handle:VotensAlltalk2ED;
new Handle:VotensRestartmapED;
new Handle:VotensMapED;
new Handle:VotensMap2ED;
new Handle:VotensED;
new Float:lastDisconnectTime;
static bool:ClientVoteMenu[MAXPLAYERS + 1];
#define L4D_TEAM_SPECTATE	1
new Handle:g_hCvarPlayerLimit;
#define MAX_CAMPAIGN_LIMIT 64
new g_iCount;
new String:g_sMapinfo[MAX_CAMPAIGN_LIMIT][MAX_NAME_LENGTH];
new String:g_sMapname[MAX_CAMPAIGN_LIMIT][64];

enum voteType
{
	ready,
	hp,
    alltalk,
	alltalk2,
	restartmap,
	swap,
	map,
	map2,
	forcespectate,
}
new voteType:g_voteType = voteType:ready;

new forcespectateid;
static			g_iSpectatePenaltyCounter[MAXPLAYERS + 1];
#define FORCESPECTATE_PENALTY 60
static g_votedelay;
#define VOTEDELAY_TIME 60

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	CreateNative("IsClientVoteMenu", Native_IsClientVoteMenu);
	CreateNative("ClientVoteMenuSet", Native_ClientVoteMenuSet);
	return APLRes_Success;
}
public Native_IsClientVoteMenu(Handle:plugin, numParams)
{
   new num1 = GetNativeCell(1);
   return ClientVoteMenu[num1];
}
public Native_ClientVoteMenuSet(Handle:plugin, numParams)
{
   new num1 = GetNativeCell(1);
   new num2 = GetNativeCell(2);
   if(num2 == 1)
	ClientVoteMenu[num1] = true;
   else
	ClientVoteMenu[num1] = false;
}
public Plugin:myinfo =
{
	name = "菜單插件",
	author = "fenghf,l4d1 modify by Harry Potter and JJ",
	description = "Votes Commands",
	version = "1.6",
	url = "http://bbs.3dmgame.com/l4d"
};

public OnPluginStart()
{
	LoadTranslations("Roto2-AZ_mod.phrases");
	decl String: game_name[64];
	GetGameFolderName(game_name, sizeof(game_name));
	if (!StrEqual(game_name, "left4dead", false))
	{
		SetFailState("只能在left4dead1使用.");
	}
	//RegAdminCmd("sm_voter", Command_Vote, ADMFLAG_KICK|ADMFLAG_VOTE|ADMFLAG_GENERIC|ADMFLAG_BAN|ADMFLAG_CHANGEMAP, "投票开启ready插件");S
	RegConsoleCmd("votesready", Command_Voter);
	RegConsoleCmd("voteshp", Command_VoteHp);
	RegConsoleCmd("votesalltalk", Command_VoteAlltalk);
	RegConsoleCmd("votesalltalk2", Command_VoteAlltalk2);
	RegConsoleCmd("votesrestartmap", Command_VoteRestartmap);
	RegConsoleCmd("votesmapsmenu", Command_VotemapsMenu);
	RegConsoleCmd("votesmaps2menu", Command_Votemaps2Menu);
	RegConsoleCmd("votesswap", Command_Votesswap);
	RegConsoleCmd("sm_votes", Command_Votes, "打開菜單 open vote meun");
	RegConsoleCmd("sm_callvote", Command_Votes, "打開菜單 open vote meun");
	RegConsoleCmd("sm_callvotes", Command_Votes, "打開菜單 open vote meun");
	RegConsoleCmd("votes", Command_Votes, "打開菜單");
	RegConsoleCmd("votesforcespectate", Command_Votesforcespectate);
	
	g_Cvar_Limits = CreateConVar("sm_votes_s", "0.60", "百分比.", 0, true, 0.05, true, 1.0);
	cvarFullResetOnEmpty = CreateConVar("l4d_full_reset_on_empty", "1", " 當伺服器没有人的時候關閉ready插件", FCVAR_NOTIFY);
	VotensReadyED = CreateConVar("l4d_VotensreadyED", "1", " 啟用、關閉 ready功能", FCVAR_NOTIFY);
	VotensHpED = CreateConVar("l4d_VotenshpED", "1", " 啟用、關閉 回血功能", FCVAR_NOTIFY);
	VotensAlltalkED = CreateConVar("l4d_VotensalltalkED", "1", " 啟用、關閉 全語音功能", FCVAR_NOTIFY);
	VotensAlltalk2ED = CreateConVar("l4d_Votensalltalk2ED", "1", " 啟用、關閉 關閉全語音功能", FCVAR_NOTIFY);
	VotensRestartmapED = CreateConVar("l4d_VotensrestartmapED", "1", " 啟用、關閉 重新目前地圖", FCVAR_NOTIFY);
	VotensMapED = CreateConVar("l4d_VotensmapED", "1", " 啟用、關閉 換圖功能", FCVAR_NOTIFY);
	VotensMap2ED = CreateConVar("l4d_Votensmap2ED", "1", " 啟用、關閉 換第三方圖功能", FCVAR_NOTIFY);
	VotensED = CreateConVar("l4d_Votens", "1", " 啟用、關閉 插件", FCVAR_NOTIFY);
	
	HookEvent("round_start", event_Round_Start);
	g_hCvarPlayerLimit = CreateConVar("sm_vote_player_limit", "2", "Minimum # of players in game to start the vote", FCVAR_NOTIFY);
}

public Action:event_Round_Start(Handle:event, const String:name[], bool:dontBroadcast)
{
	for(new i=1; i <= MaxClients; i++) ClientVoteMenu[i] = false; 
	
}

public OnClientPutInServer(client)
{
	g_iSpectatePenaltyCounter[client] = FORCESPECTATE_PENALTY;
}
public OnMapStart()
{
	ParseCampaigns();
	
	g_votedelay = 15;
	CreateTimer(1.0, Timer_VoteDelay, _, TIMER_REPEAT| TIMER_FLAG_NO_MAPCHANGE);
	
	new Handle:currentReadyMode = FindConVar("l4d_ready_enabled");
	GetConVarString(currentReadyMode, ReadyMode, sizeof(ReadyMode));
	
	for(new i = 1; i <= MaxClients; i++)
	{	
		g_iSpectatePenaltyCounter[i] = FORCESPECTATE_PENALTY;
	}
	PrecacheSound("ui/menu_enter05.wav");
	PrecacheSound("ui/beep_synthtone01.wav");
	PrecacheSound("ui/beep_error01.wav");
	
	VoteMenuClose();
}

public Action:Command_Votes(client, args) 
{ 
	if (client == 0)
	{
		PrintToServer("[TS] %t","command cannot be used by server.");
		return Plugin_Handled;
	}
	if(GetClientTeam(client) == 1)
	{
		return Plugin_Handled;
	}
	ClientVoteMenu[client] = true;
	if(GetConVarInt(VotensED) == 1)
	{
		new VotensReadyE_D = GetConVarInt(VotensReadyED); 
		new VotensHpE_D = GetConVarInt(VotensHpED);
		new VotensAlltalkE_D = GetConVarInt(VotensAlltalkED);
		new VotensAlltalk2E_D = GetConVarInt(VotensAlltalk2ED);
		new VotensRestartmapE_D = GetConVarInt(VotensRestartmapED);		
		new VotensMapE_D = GetConVarInt(VotensMapED);
		new VotensMap2E_D = GetConVarInt(VotensMap2ED);

		decl String:Info[256];

		new Handle:menu = CreatePanel();
		Format(Info, sizeof(Info), "%T", "Vote Menu", client);
		SetPanelTitle(menu, Info);
		
		if(VotensReadyE_D == 1)
		{
			if (strcmp(ReadyMode, "0", false) == 0)
			{
				Format(Label, sizeof(Label), "%T", "Turn On",client);
			}
			else if (strcmp(ReadyMode, "1", false) == 0)
			{
				Format(Label, sizeof(Label), "%T", "Turn Off",client);
			}
			Format(Info, sizeof(Info), "%T","votes3_8",client, Label);
			DrawPanelItem(menu, Info);
		}
		if (VotensHpE_D == 1)
		{
			Format(Info, sizeof(Info), "%T", "Give hp", client);
			DrawPanelItem(menu, Info);
		}
		if (VotensAlltalkE_D == 1)
		{
			Format(Info, sizeof(Info), "%T", "All talk", client);
			DrawPanelItem(menu, Info);
		}
		if (VotensAlltalk2E_D == 1)
		{
			Format(Info, sizeof(Info), "%T", "Turn off all talk", client);
			DrawPanelItem(menu, Info);
		}
		if (VotensRestartmapE_D == 1)
		{
			Format(Info, sizeof(Info), "%T", "Restartmap", client);
			DrawPanelItem(menu, Info);
		}
		if (VotensMapE_D == 1)
		{
			Format(Info, sizeof(Info), "%T", "Change map", client);
			DrawPanelItem(menu, Info);
		}
		if (VotensMap2E_D == 1)
		{
			Format(Info, sizeof(Info), "%T", "Change addon map", client);
			DrawPanelItem(menu, Info);
		}
		Format(Info, sizeof(Info), "%T", "Kick player", client);
		DrawPanelItem(menu, Info);
		Format(Info, sizeof(Info), "%T", "Forcespectate player", client);
		DrawPanelItem(menu, Info);
		DrawPanelText(menu, " \n");
		Format(Info, sizeof(Info), "0. %T","exit", client);
		DrawPanelText(menu, Info);
		SendPanelToClient(menu, client,Votes_Menu, MENU_TIME);
		return Plugin_Handled;
	}
	else if(GetConVarInt(VotensED) == 0)
	{}
	return Plugin_Stop;
}
public Votes_Menu(Handle:menu, MenuAction:action, client, itemNum)
{
	if ( action == MenuAction_Select ) 
	{
		new VotensReadyE_D = GetConVarInt(VotensReadyED); 
		new VotensHpE_D = GetConVarInt(VotensHpED); 
		new VotensAlltalkE_D = GetConVarInt(VotensAlltalkED);
		new VotensAlltalk2E_D = GetConVarInt(VotensAlltalk2ED);
		new VotensRestartmapE_D = GetConVarInt(VotensRestartmapED);
		new VotensMapE_D = GetConVarInt(VotensMapED);
		new VotensMap2E_D = GetConVarInt(VotensMap2ED);
		switch (itemNum)
		{
			case 1: 
			{
				if (VotensReadyE_D == 0)
				{
					FakeClientCommand(client,"sm_votes");
					CPrintToChat(client, "{default}[{olive}TS{default}] %T","votes3_1",client);
					return ;
				}
				else if (VotensReadyE_D == 1)
				{
					FakeClientCommand(client,"votesready");
				}
			}
			case 2: 
			{
				if (VotensHpE_D == 0)
				{
					FakeClientCommand(client,"sm_votes");
					CPrintToChat(client, "{default}[{olive}TS{default}] %T","votes3_2",client);
					return;
				}
				else if (VotensHpE_D == 1)
				{
					FakeClientCommand(client,"voteshp");
				}
			}
			case 3: 
			{
				if (VotensAlltalkE_D == 0)
				{
					FakeClientCommand(client,"sm_votes");
					CPrintToChat(client, "{default}[{olive}TS{default}] %T","votes3_3",client);
					return;
				}
				else if (VotensAlltalkE_D == 1)
				{
					FakeClientCommand(client,"votesalltalk");
				}
			}
			case 4: 
			{
				if (VotensAlltalk2E_D == 0)
				{
					FakeClientCommand(client,"sm_votes");
					CPrintToChat(client, "{default}[{olive}TS{default}] %T","votes3_4",client);
					return;
				}
				else if (VotensAlltalk2E_D == 1)
				{
					FakeClientCommand(client,"votesalltalk2");
				}
			}
			case 5: 
			{
				if (VotensRestartmapE_D == 0)
				{
					FakeClientCommand(client,"sm_votes");
					CPrintToChat(client, "{default}[{olive}TS{default}] %T","votes3_5",client);
					return;
				}
				else if (VotensRestartmapE_D == 1)
				{
					FakeClientCommand(client,"votesrestartmap");
				}
			}
			case 6: 
			{
				if (VotensMapE_D == 0)
				{
					FakeClientCommand(client,"sm_votes");
					CPrintToChat(client, "{default}[{olive}TS{default}] %T","votes3_6",client);
					return ;
				}
				else if (VotensMapE_D == 1)
				{
					FakeClientCommand(client,"votesmapsmenu");
				}
			}
			case 7: 
			{
				if (VotensMap2E_D == 0)
				{
					FakeClientCommand(client,"sm_votes");
					CPrintToChat(client, "{default}[{olive}TS{default}] %T","votes3_7",client);
					return ;
				}
				else if (VotensMap2E_D == 1)
				{
					FakeClientCommand(client,"votesmaps2menu");
				}
			}
			case 8: 
			{
				FakeClientCommand(client,"votesswap");
			}
			case 9: 
			{
				FakeClientCommand(client,"votesforcespectate");
			}
			
		}
	}
	else if ( action == MenuAction_Cancel)
	{
		ClientVoteMenu[client] = false;
	}
	else if ( action == MenuAction_End)
			delete menu;
}

public Action:Command_Voter(client, args)
{
	if(GetConVarInt(VotensED) == 1 && GetConVarInt(VotensReadyED) == 1)
	{
		if (!TestVoteDelay(client))
		{
			return Plugin_Handled;
		}
		
		if(CanStartVotes(client))
		{
			if (strcmp(ReadyMode, "0", false) == 0)
			{
				Format(Label, sizeof(Label), "Turn On");
			}
			else if (strcmp(ReadyMode, "1", false) == 0)
			{
				Format(Label, sizeof(Label), "Turn Off");
			}
			CPrintToChatAll("{default}[{olive}TS{default}] {olive}%N{default} %t{default}: {blue}%t", client,"starts a vote", "votes3_9", Label);
			
			for(new i=1; i <= MaxClients; i++) ClientVoteMenu[i] = true;
			
			g_voteType = voteType:ready;
			decl String:SteamId[35];
			GetClientAuthId(client, AuthId_Steam2,SteamId, sizeof(SteamId));
			if (strcmp(ReadyMode, "0", false) == 0)
			{
				Format(Label, sizeof(Label), "Turn On");
			}
			else if (strcmp(ReadyMode, "1", false) == 0)
			{
				Format(Label, sizeof(Label), "Turn Off");
			}
			LogMessage("%N(%s) starts a vote: %s ready plugin!",  client, SteamId, Label);//記錄在log文件
			
			g_hVoteMenu = new Menu(Handler_VoteCallback, MENU_ACTIONS_ALL);
			g_hVoteMenu.SetTitle("%T","votes3_9",LANG_SERVER,Label);
			g_hVoteMenu.AddItem(VOTE_YES, "Yes");
			g_hVoteMenu.AddItem(VOTE_NO, "No");
			g_hVoteMenu.ExitButton = false;
			g_hVoteMenu.DisplayVoteToAll(20);

			EmitSoundToAll("ui/beep_synthtone01.wav");
		}
		return Plugin_Handled;
	}
	else if(GetConVarInt(VotensED) == 0 && GetConVarInt(VotensReadyED) == 0)
	{
		CPrintToChat(client, "{default}[{olive}TS{default}] %T","This vote is prohibited",client);
	}
	return Plugin_Handled;
}
public Action:Command_VoteHp(client, args)
{
	if(GetConVarInt(VotensED) == 1 
	&& GetConVarInt(VotensHpED) == 1)
	{
		if (!TestVoteDelay(client))
		{
			return Plugin_Handled;
		}	
		if(CanStartVotes(client))
		{
			CPrintToChatAll("{default}[{olive}TS{default}] {olive}%N{default} %t: {blue}%t",client,"starts a vote","Give hp");
			
			
			for(new i=1; i <= MaxClients; i++) ClientVoteMenu[i] = true;
			
			g_voteType = voteType:hp;
			decl String:SteamId[35];
			GetClientAuthId(client, AuthId_Steam2,SteamId, sizeof(SteamId));
			LogMessage("%N(%s) starts a vote: give hp!",  client, SteamId);//記錄在log文件
			
			g_hVoteMenu = new Menu(Handler_VoteCallback, MENU_ACTIONS_ALL);
			g_hVoteMenu.SetTitle("%T?","Give hp",LANG_SERVER);
			g_hVoteMenu.AddItem(VOTE_YES, "Yes");
			g_hVoteMenu.AddItem(VOTE_NO, "No");
			g_hVoteMenu.ExitButton = false;
			g_hVoteMenu.DisplayVoteToAll(20);
			
			EmitSoundToAll("ui/beep_synthtone01.wav");
		}
		return Plugin_Handled;	
	}
	else if(GetConVarInt(VotensED) == 0 && GetConVarInt(VotensHpED) == 0)
	{
		CPrintToChat(client, "{default}[{olive}TS{default}] This vote is prohibited");
	}
	return Plugin_Handled;
}
public Action:Command_VoteAlltalk(client, args)
{
	if(GetConVarInt(VotensED) == 1 
	&& GetConVarInt(VotensAlltalkED) == 1)
	{
		if (!TestVoteDelay(client))
		{
			return Plugin_Handled;
		}
		if(CanStartVotes(client))
		{
			CPrintToChatAll("{default}[{olive}TS{default}] {olive}%N{default} %t: {blue}%t",client,"starts a vote","Turn on All talk");
			
			for(new i=1; i <= MaxClients; i++) ClientVoteMenu[i] = true;
			
			g_voteType = voteType:alltalk;
			decl String:SteamId[35];
			GetClientAuthId(client, AuthId_Steam2,SteamId, sizeof(SteamId));
			LogMessage("%N(%s) starts a vote: turn on Alltalk!",  client, SteamId);//紀錄在log文件
			
			g_hVoteMenu = new Menu(Handler_VoteCallback, MENU_ACTIONS_ALL);
			g_hVoteMenu.SetTitle("%T?","Turn on All talk",LANG_SERVER);
			g_hVoteMenu.AddItem(VOTE_YES, "Yes");
			g_hVoteMenu.AddItem(VOTE_NO, "No");
			g_hVoteMenu.ExitButton = false;
			g_hVoteMenu.DisplayVoteToAll(20);
			
			EmitSoundToAll("ui/beep_synthtone01.wav");
		}
		return Plugin_Handled;	
	}
	else if(GetConVarInt(VotensED) == 0 && GetConVarInt(VotensAlltalkED) == 0)
	{
		CPrintToChat(client, "{default}[{olive}TS{default}] %T","This vote is prohibited",client);
	}
	return Plugin_Handled;
}
public Action:Command_VoteAlltalk2(client, args)
{
	if(GetConVarInt(VotensED) == 1 
	&& GetConVarInt(VotensAlltalk2ED) == 1)
	{
		if (!TestVoteDelay(client))
		{
			return Plugin_Handled;
		}	
		
		if(CanStartVotes(client))
		{
			CPrintToChatAll("{default}[{olive}TS{default}] {olive}%N{default} %t: {blue}%t",client,"starts a vote","Turn off all talk");
			
			for(new i=1; i <= MaxClients; i++) ClientVoteMenu[i] = true;
			
			g_voteType = voteType:alltalk2;
			decl String:SteamId[35];
			GetClientAuthId(client, AuthId_Steam2,SteamId, sizeof(SteamId));
			LogMessage("%N(%s) starts a vote: turn off Alltalk!",  client, SteamId);//紀錄在log文件
			
			g_hVoteMenu = new Menu(Handler_VoteCallback, MENU_ACTIONS_ALL);
			g_hVoteMenu.SetTitle("%T?","Turn off all talk",LANG_SERVER);
			g_hVoteMenu.AddItem(VOTE_YES, "Yes");
			g_hVoteMenu.AddItem(VOTE_NO, "No");
			g_hVoteMenu.ExitButton = false;
			g_hVoteMenu.DisplayVoteToAll(20);
			
			EmitSoundToAll("ui/beep_synthtone01.wav");
		}
		return Plugin_Handled;	
	}
	else if(GetConVarInt(VotensED) == 0 && GetConVarInt(VotensAlltalk2ED) == 0)
	{
		CPrintToChat(client, "{default}[{olive}TS{default}] This vote is prohibited");
	}
	return Plugin_Handled;
}
public Action:Command_VoteRestartmap(client, args)
{
	if(GetConVarInt(VotensED) == 1 
	&& GetConVarInt(VotensRestartmapED) == 1)
	{
		if (!TestVoteDelay(client))
		{
			return Plugin_Handled;
		}	

		if(CanStartVotes(client))
		{
			CPrintToChatAll("{default}[{olive}TS{default}]{olive} %N {default}%t: {blue}%t",client,"starts a vote","Restartmap");
			
			for(new i=1; i <= MaxClients; i++) ClientVoteMenu[i] = true;
			
			g_voteType = voteType:restartmap;
			decl String:SteamId[35];
			GetClientAuthId(client, AuthId_Steam2,SteamId, sizeof(SteamId));
			LogMessage("%N(%s) starts a vote: restartmap!",  client, SteamId);//紀錄在log文件
			
			g_hVoteMenu = new Menu(Handler_VoteCallback, MENU_ACTIONS_ALL);
			g_hVoteMenu.SetTitle("%T?","Restartmap",LANG_SERVER);
			g_hVoteMenu.AddItem(VOTE_YES, "Yes");
			g_hVoteMenu.AddItem(VOTE_NO, "No");
			g_hVoteMenu.ExitButton = false;
			g_hVoteMenu.DisplayVoteToAll(20);
			
			EmitSoundToAll("ui/beep_synthtone01.wav");
		}
		
		return Plugin_Handled;	
	}
	else if(GetConVarInt(VotensED) == 0 && GetConVarInt(VotensRestartmapED) == 0)
	{
		CPrintToChat(client, "{default}[{olive}TS{default}] This vote is prohibited");
	}
	return Plugin_Handled;
}
public Action:Command_Votesswap(client, args)
{
	if(client!=0) CreateVoteswapMenu(client);		
	return Plugin_Handled;
}

CreateVoteswapMenu(client)
{	
	new Handle:menu = CreateMenu(Menu_Votesswap);		
	new team = GetClientTeam(client);
	new String:name[MAX_NAME_LENGTH];
	new String:playerid[32];
	decl String:Info[50];
	Format(Info, sizeof(Info), "%T", "Kick player", client);
	SetMenuTitle(menu, Info);
	for(new i = 1;i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i)==team)
		{
			Format(playerid,sizeof(playerid),"%i",GetClientUserId(i));
			if(GetClientName(i,name,sizeof(name)))
			{
				AddMenuItem(menu, playerid, name);						
			}
		}		
	}
	SetMenuExitBackButton(menu, true);
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME);	
}
public Menu_Votesswap(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		new String:info[32] , String:name[32];
		GetMenuItem(menu, param2, info, sizeof(info), _, name, sizeof(name));
		swapplayer = info;
		swapplayername = name;
		
		DisplayVoteSwapMenu(param1);		
	}
	else if ( action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack) {
			FakeClientCommand(param1,"votes");
		}
		else
			ClientVoteMenu[param1] = false;
	}
	else if ( action == MenuAction_End)
			delete menu;
}

public DisplayVoteSwapMenu(client)
{
	if (!TestVoteDelay(client))
	{
		return;
	}
	
	if(CanStartVotes(client))
	{
		decl String:SteamId[35];
		GetClientAuthId(client, AuthId_Steam2,SteamId, sizeof(SteamId));
		LogMessage("%N(%s) starts a vote: kick %s",  client, SteamId,swapplayername);//紀錄在log文件
		CPrintToChatAll("{default}[{olive}TS{default}]{olive} %N {default}%t: {blue}%t %s", client,"starts a vote", "Kick player",swapplayername);
		
		for(new i=1; i <= MaxClients; i++) 
			ClientVoteMenu[i] = true;
		
		g_voteType = voteType:swap;
		
		g_hVoteMenu = new Menu(Handler_VoteCallback, MENU_ACTIONS_ALL);
		g_hVoteMenu.SetTitle("%T: %s?","Kick player",LANG_SERVER,swapplayername);
		g_hVoteMenu.AddItem(VOTE_YES, "Yes");
		g_hVoteMenu.AddItem(VOTE_NO, "No");
		g_hVoteMenu.ExitButton = false;
		g_hVoteMenu.DisplayVoteToAll(20);
		
		EmitSoundToAll("ui/beep_synthtone01.wav");
	}
	return;
}

public Action:Command_VotemapsMenu(client, args)
{
	if(GetConVarInt(VotensED) == 1 && GetConVarInt(VotensMapED) == 1)
	{
		if (!TestVoteDelay(client))
		{
			return Plugin_Handled;
		}
		new Handle:menu = CreateMenu(MapMenuHandler);
		decl String:Info[50];
		Format(Info, sizeof(Info), "%T", "Plz choose addon maps", client);
		SetMenuTitle(menu, Info);
		
		Format(Info, sizeof(Info), "%T", "No Mercy", client);
		AddMenuItem(menu, "l4d_vs_hospital01_apartment", Info);
		Format(Info, sizeof(Info), "%T", "Dead Air", client);
		AddMenuItem(menu, "l4d_vs_airport01_greenhouse", Info);
		Format(Info, sizeof(Info), "%T", "Death Toll", client);
		AddMenuItem(menu, "l4d_vs_smalltown01_caves", Info);
		Format(Info, sizeof(Info), "%T", "Blood Harvest", client);
		AddMenuItem(menu, "l4d_vs_farm01_hilltop", Info);
		Format(Info, sizeof(Info), "%T", "Crash Course", client);
		AddMenuItem(menu, "l4d_garage01_alleys", Info);
		Format(Info, sizeof(Info), "%T", "The Sacrifice", client);
		AddMenuItem(menu, "l4d_river01_docks", Info);
		
		SetMenuExitBackButton(menu, true);
		SetMenuExitButton(menu, true);
		DisplayMenu(menu, client, MENU_TIME);
		
		return Plugin_Handled;
	}
	else 
	if(GetConVarInt(VotensED) == 0 && GetConVarInt(VotensMapED) == 0)
	{
		CPrintToChat(client, "{default}[{olive}TS{default}] %T","This vote is prohibited",client);
	}
	return Plugin_Handled;
}

public Action:Command_Votemaps2Menu(client, args)
{
	if(GetConVarInt(VotensED) == 1 && GetConVarInt(VotensMap2ED) == 1)
	{
		if (!TestVoteDelay(client))
		{
			return Plugin_Handled;
		}
		new Handle:menu = CreateMenu(MapMenuHandler);
	
		SetMenuTitle(menu, "▲ %T","Vote Custom Maps",client, g_iCount);


		for (new i = 0; i < g_iCount; i++)
		{
			AddMenuItem(menu, g_sMapinfo[i], g_sMapname[i]);
		}
		
		SetMenuExitBackButton(menu, true);
		SetMenuExitButton(menu, true);
		DisplayMenu(menu, client, MENU_TIME);
		
		return Plugin_Handled;
	}
	else 
	if(GetConVarInt(VotensED) == 0 && GetConVarInt(VotensMap2ED) == 0)
	{
		CPrintToChat(client, "{default}[{olive}TS{default}] %T","This vote is prohibited",client);
	}
	return Plugin_Handled;
}

public MapMenuHandler(Handle:menu, MenuAction:action, client, itemNum)
{
	if ( action == MenuAction_Select ) 
	{
		new String:info[32] , String:name[64];
		GetMenuItem(menu, itemNum, info, sizeof(info), _, name, sizeof(name));
		votesmaps = info;
		votesmapsname = name;	
		DisplayVoteMapsMenu(client);		
	}
	else if ( action == MenuAction_Cancel)
	{
		if (itemNum == MenuCancel_ExitBack) {
			FakeClientCommand(client,"votes");
		}
		else
			ClientVoteMenu[client] = false;
	}
	else if ( action == MenuAction_End)
			delete menu;
}
public DisplayVoteMapsMenu(client)
{
	if (!TestVoteDelay(client))
	{
		return;
	}
	if(CanStartVotes(client))
	{
	
		decl String:SteamId[35];
		GetClientAuthId(client, AuthId_Steam2,SteamId, sizeof(SteamId));
		LogMessage("%N(%s) starts a vote: change map %s",  client, SteamId,votesmapsname);//紀錄在log文件
		CPrintToChatAll("{default}[{olive}TS{default}] {olive}%N{default} %t: {blue}%t %s", client,"starts a vote","Change map", votesmapsname);
		
		for(new i=1; i <= MaxClients; i++) ClientVoteMenu[i] = true;
		
		g_voteType = voteType:map;
		
		g_hVoteMenu = new Menu(Handler_VoteCallback, MENU_ACTIONS_ALL);
		g_hVoteMenu.SetTitle("%T: %s?","Change map",LANG_SERVER,votesmapsname);
		g_hVoteMenu.AddItem(VOTE_YES, "Yes");
		g_hVoteMenu.AddItem(VOTE_NO, "No");
		g_hVoteMenu.ExitButton = false;
		g_hVoteMenu.DisplayVoteToAll(20);
		
		EmitSoundToAll("ui/beep_synthtone01.wav");
	}
	return;
}

public Action:Command_Votesforcespectate(client, args)
{
	if(client!=0) CreateVoteforcespectateMenu(client);		
	return Plugin_Handled;
}

CreateVoteforcespectateMenu(client)
{	
	new Handle:menu = CreateMenu(Menu_Votesforcespectate);		
	new team = GetClientTeam(client);
	new String:name[MAX_NAME_LENGTH];
	new String:playerid[32];
	decl String:Info[50];
	Format(Info, sizeof(Info), "%T", "Forcespectate player", client);
	SetMenuTitle(menu, Info);
	for(new i = 1;i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i)==team)
		{
			Format(playerid,sizeof(playerid),"%d",i);
			if(GetClientName(i,name,sizeof(name)))
			{
				AddMenuItem(menu, playerid, name);				
			}
		}		
	}
	SetMenuExitBackButton(menu, true);
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME);	
}
public Menu_Votesforcespectate(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		new String:info[32] , String:name[32];
		GetMenuItem(menu, param2, info, sizeof(info), _, name, sizeof(name));
		forcespectateid = StringToInt(info);
		forcespectateid = GetClientUserId(forcespectateid);
		swapplayername = name;
		
		DisplayVoteforcespectateMenu(param1);		
	}
	else if ( action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack) {
			FakeClientCommand(param1,"votes");
		}
		else
			ClientVoteMenu[param1] = false;
	}
	else if ( action == MenuAction_End)
			delete menu;
}

public DisplayVoteforcespectateMenu(client)
{
	if (!TestVoteDelay(client))
	{
		return;
	}
	
	if(CanStartVotes(client))
	{
		decl String:SteamId[35];
		GetClientAuthId(client, AuthId_Steam2,SteamId, sizeof(SteamId));
		LogMessage("%N(%s) starts a vote: forcespectate player %s",  client, SteamId,swapplayername);//紀錄在log文件
		
		new iTeam = GetClientTeam(client);
		CPrintToChatAll("{default}[{olive}TS{default}] {olive}%N{default} %t: {blue}%t %s{default}, %t", client, "starts a vote","Forcespectate player",swapplayername,"only their team can vote");
		
		for(new i=1; i <= MaxClients; i++) 
			if (IsClientConnected(i) && IsClientInGame(i) && GetClientTeam(i) == iTeam)
				ClientVoteMenu[i] = true;
		
		g_voteType = voteType:forcespectate;
		
		g_hVoteMenu = new Menu(Handler_VoteCallback, MENU_ACTIONS_ALL);
		g_hVoteMenu.SetTitle("%T: %s?","Forcespectate player",LANG_SERVER,swapplayername);
		g_hVoteMenu.AddItem(VOTE_YES, "Yes");
		g_hVoteMenu.AddItem(VOTE_NO, "No");
		g_hVoteMenu.ExitButton = false;
		new iTotal = 0;
		new iPlayers[MaxClients];
		
		for (new i = 1; i <= MaxClients; i++)
		{
			if (!IsClientConnected(i) || !IsClientInGame(i) || IsFakeClient(i) || GetClientTeam(i) != iTeam)
			{
				continue;
			}
			
			iPlayers[iTotal++] = i;
		}
		
		g_hVoteMenu.DisplayVote(iPlayers, iTotal, 20, 0);
		
		for (new i=1; i<=MaxClients; i++)
			if(IsClientConnected(i)&&IsClientInGame(i)&&!IsFakeClient(i)&&GetClientTeam(i) == iTeam)
				EmitSoundToClient(i,"ui/beep_synthtone01.wav");
	}
	return;
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
		switch (g_voteType)
		{
			case (voteType:ready):
			{
				if (strcmp(ReadyMode, "0", false) == 0)
				{
					Format(Label, sizeof(Label), "%T", "Turn On",param1);
				}
				else if (strcmp(ReadyMode, "1", false) == 0)
				{
					Format(Label, sizeof(Label), "%T", "Turn Off",param1);
				}
				Format(buffer, sizeof(buffer), "%T?", "votes3_8", param1,Label);
			}
			case (voteType:hp):
			{
				Format(buffer, sizeof(buffer), "%T?", "Give hp", param1);
			}
			case (voteType:alltalk):
			{
				Format(buffer, sizeof(buffer), "%T?", "Turn on All talk", param1);
			}
			case (voteType:alltalk2):
			{
				Format(buffer, sizeof(buffer), "%T?", "Turn off all talk", param1);
			}
			case (voteType:restartmap):
			{
				Format(buffer, sizeof(buffer), "%T?", "Restartmap", param1);
			}
			case (voteType:map):
			{
				Format(buffer, sizeof(buffer), "%T: %s?", "Change map", param1,votesmapsname);
			}
			case (voteType:swap):
			{
				Format(buffer, sizeof(buffer), "%T: %s?","Kick player", param1,swapplayername);
			}
			case (voteType:forcespectate):
			{
				Format(buffer, sizeof(buffer), "%T: %s?","Forcespectate player", param1,swapplayername);
			}
		}
		
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
		EmitSoundToAll("ui/beep_error01.wav");
		CreateTimer(2.0, VoteEndDelay);
		CreateTimer(1.0, Timer_VoteDelay, _, TIMER_REPEAT| TIMER_FLAG_NO_MAPCHANGE);
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
		}
		else
		{
			g_votedelay = VOTEDELAY_TIME;
			CreateTimer(1.0, Timer_VoteDelay, _, TIMER_REPEAT| TIMER_FLAG_NO_MAPCHANGE);
			EmitSoundToAll("ui/menu_enter05.wav");
			CPrintToChatAll("{default}[{olive}TS{default}] %t","Vote pass.", RoundToNearest(100.0*percent), totalVotes);
			CreateTimer(2.0, VoteEndDelay);
			CreateTimer(3.0,COLD_DOWN,_);
		}
	}
	return 0;
}

public Action:Timer_forcespectate(Handle:timer, any:client)
{
	static bClientJoinedTeam = false;		//did the client try to join the infected?
	
	if (!IsClientInGame(client) || IsFakeClient(client)) return Plugin_Stop; //if client disconnected or is fake client
	
	if (g_iSpectatePenaltyCounter[client] != 0)
	{
		if (GetClientTeam(client) == 3||GetClientTeam(client) == 2)
		{
			ChangeClientTeam(client, 1);
			CPrintToChat(client, "{default}[{olive}TS{default}] %T","votes3_10",client, g_iSpectatePenaltyCounter[client]);
			bClientJoinedTeam = true;	//client tried to join the infected again when not allowed
		}
		g_iSpectatePenaltyCounter[client]--;
		return Plugin_Continue;
	}
	else if (g_iSpectatePenaltyCounter[client] == 0)
	{
		if (GetClientTeam(client) == 3||GetClientTeam(client) == 2)
		{
			ChangeClientTeam(client, 1);
			bClientJoinedTeam = true;
		}
		if (GetClientTeam(client) == 1 && bClientJoinedTeam)
		{
			CPrintToChat(client, "{default}[{olive}TS{default}] %T","votes3_11" ,client);	//only print this hint text to the spectator if he tried to join the infected team, and got swapped before
		}
		bClientJoinedTeam = false;
		g_iSpectatePenaltyCounter[client] = FORCESPECTATE_PENALTY;
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

//====================================================
public AnyHp()
{
	new flags = GetCommandFlags("give");	
	SetCommandFlags("give", flags & ~FCVAR_CHEAT);
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
		{
			FakeClientCommand(i, "give health");
			SetEntityHealth(i, MaxHealth);
		}
		else
		if (IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i)) 
		{
			new class = GetEntProp(i, Prop_Send, "m_zombieClass");
			if (class == ZOMBIECLASS_SMOKER)
			{
				SetEntityHealth(i, 250);
			}
			else
			if (class == ZOMBIECLASS_BOOMER)
			{
				SetEntityHealth(i, 50);
			}
			else
			if (class == ZOMBIECLASS_HUNTER)
			{
				SetEntityHealth(i, 250);
			}
			else
            if (class == ZOMBIECLASS_SPITTER)
			{
				SetEntityHealth(i, 100);
			}
			else
			if (class == ZOMBIECLASS_JOCKEY)
			{
				decl String:game_name[64];
				GetGameFolderName(game_name, sizeof(game_name));
				if (!StrEqual(game_name, "left4dead2", false))
				{
					SetEntityHealth(i, 6000);
				}
				else
				{
					SetEntityHealth(i, 325);
				}
			}
			else
			if (class == ZOMBIECLASS_CHARGER)
			{
				SetEntityHealth(i, 600);
			}
			else
			if (class == ZOMBIECLASS_TANK)
			{
				SetEntityHealth(i, 6000);
			}
		}
	}
	SetCommandFlags("give", flags|FCVAR_CHEAT);
}
//================================
CheckVotes()
{
	PrintHintTextToAll("%t: %i\n%t: %i","Agree", Votey,"Disagree", Voten);
}
public Action:VoteEndDelay(Handle:timer)
{
	Votey = 0;
	Voten = 0;
	for(new i=1; i <= MaxClients; i++) ClientVoteMenu[i] = false;
}
public Action:Changelevel_Map(Handle:timer)
{
	ServerCommand("changelevel %s", votesmaps);
}
//===============================
VoteMenuClose()
{
	Votey = 0;
	Voten = 0;
	CloseHandle(g_hVoteMenu);
	g_hVoteMenu = null;
}
Float:GetVotePercent(votes, totalVotes)
{
	return FloatDiv(float(votes),float(totalVotes));
}
bool:TestVoteDelay(client)
{
	new delay = GetVoteDelay();
 	if (delay > 0)
 	{
 		CPrintToChat(client, "{default}[{olive}TS{default}] %T","votes3_12",client, delay);
 		return false;
 	}
	return true;
}

bool:CanStartVotes(client)
{
	
 	if(g_hVoteMenu  != INVALID_HANDLE || IsVoteInProgress())
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
		CPrintToChat(client, "{default}[{olive}TS{default}] %T %T","votes3_13",client,"Not enough players.",client,playerlimit);
		return false;
	}
	return true;
}
//=======================================
public OnClientDisconnect(client)
{
	if (IsClientInGame(client) && IsFakeClient(client)) return;

	new Float:currenttime = GetGameTime();
	
	if (lastDisconnectTime == currenttime) return;
	
	CreateTimer(SCORE_DELAY_EMPTY_SERVER, IsNobodyConnected, currenttime);
	lastDisconnectTime = currenttime;
}

public Action:IsNobodyConnected(Handle:timer, any:timerDisconnectTime)
{
	if (timerDisconnectTime != lastDisconnectTime) return Plugin_Stop;

	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && !IsFakeClient(i))
			return  Plugin_Stop;
	}	
	SetConVarInt(FindConVar("l4d_ready_enabled"), 0);		
	if (GetConVarBool(cvarFullResetOnEmpty))
	{
		SetConVarInt(FindConVar("l4d_ready_enabled"), 0);
	}
	
	return  Plugin_Stop;
}

public Action:COLD_DOWN(Handle:timer,any:client)
{
	switch (g_voteType)
	{
		case (voteType:ready):
		{
			if (strcmp(ReadyMode, "0", false) == 0)
			{
				SetConVarInt(FindConVar("l4d_ready_enabled"), 1);
			}
			if (strcmp(ReadyMode, "1", false) == 0)
			{
				ServerCommand("sv_search_key 1");
				SetConVarInt(FindConVar("l4d_ready_enabled"), 0);
			}
			LogMessage("vote %s ready pass",Label);
		}
		case (voteType:hp):
		{
			AnyHp();
			LogMessage("vote to give hp pass");	
		}
		case (voteType:alltalk):
		{
			ServerCommand("sv_alltalk 1");
			LogMessage("vote to turn on alltalk pass");
		}
		case (voteType:alltalk2):
		{
			ServerCommand("sv_alltalk 0");
			LogMessage("vote to turn off alltalk pass");
		}
		case (voteType:restartmap):
		{
			ServerCommand("sm_restartmap");
			LogMessage("vote to restartmap pass");
		}
		case (voteType:map):
		{
			CreateTimer(5.0, Changelevel_Map);
			CPrintToChatAll("[{olive}TS{default}] %t","votes3_14",votesmapsname);
			LogMessage("Vote to change map %s %s pass",votesmaps,votesmapsname);
		}
		case (voteType:swap):
		{
			CPrintToChatAll("[{olive}TS{default}] %t","votes3_15", swapplayername);
			ServerCommand("sm_kick \"%s\" ", swapplayername);				
			LogMessage(" Vote to kick %s pass",swapplayername);
		}
		case (voteType:forcespectate):
		{
			forcespectateid = GetClientOfUserId(forcespectateid);
			if(forcespectateid && IsClientInGame(forcespectateid)) 
			{
				CPrintToChatAll("[{olive}TS{default}] %t","votes3_16", swapplayername);									
				LogMessage(" Vote to forcespectate %s pass",swapplayername);
				ChangeClientTeam(forcespectateid, 1);
				CreateTimer(1.0, Timer_forcespectate, forcespectateid, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
			}
			else
			{
				CPrintToChatAll("[{olive}TS{default}] %s player not found", swapplayername);	
			}
		}
	}
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

ParseCampaigns()
{
	new Handle: g_kvCampaigns = CreateKeyValues("VoteCustomCampaigns");

	new String:sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/VoteCustomCampaigns.txt");

	if ( !FileToKeyValues(g_kvCampaigns, sPath) ) 
	{
		SetFailState("<VCC> File not found: %s", sPath);
		CloseHandle(g_kvCampaigns);
		return;
	}
	
	if (!KvGotoFirstSubKey(g_kvCampaigns))
	{
		SetFailState("<VCC> File can't read: you dumb noob!");
		CloseHandle(g_kvCampaigns);
		return;
	}
	
	for (new i = 0; i < MAX_CAMPAIGN_LIMIT; i++)
	{
		KvGetString(g_kvCampaigns,"mapinfo", g_sMapinfo[i], sizeof(g_sMapinfo));
		KvGetString(g_kvCampaigns,"mapname", g_sMapname[i], sizeof(g_sMapname));
		
		if ( !KvGotoNextKey(g_kvCampaigns) )
		{
			g_iCount = ++i;
			break;
		}
	}
}