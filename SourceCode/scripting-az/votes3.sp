#pragma semicolon 1

#include <sourcemod>
#include <multicolors>
#include <sdktools>
#undef REQUIRE_PLUGIN
#define SCORE_DELAY_EMPTY_SERVER 3.0
#define VOTE_NO "no"
#define VOTE_YES "yes"
#define L4D_MAXCLIENTS_PLUS1 (MaxClients+1)
#define MENU_TIME 20
new Votey = 0;
new Voten = 0;
new String:ReadyMode[64];
int kickplayer_userid;
new String:kickplayer_name[MAX_NAME_LENGTH];
new String:kickplayer_SteamId[MAX_NAME_LENGTH];
new String:forcespectateplayername[MAX_NAME_LENGTH];
new String:votesmaps[MAX_NAME_LENGTH];
new String:votesmapsname[64];
Menu g_hVoteMenu = null;

ConVar g_Cvar_Limits;
ConVar VotensHpED;
ConVar VotensAlltalkED;
ConVar VotensAlltalk2ED;
ConVar VotensRestartmapED;
ConVar VotensMapED;
ConVar VotensMap2ED;
ConVar VotensED;
ConVar VotensKickED;
ConVar VotensForceSpectateED;
ConVar g_hCvarPlayerLimit;
ConVar g_hKickImmueAccess;
static bool:ClientVoteMenu[MAXPLAYERS + 1];
#define L4D_TEAM_SPECTATE	1
#define MAX_CAMPAIGN_LIMIT 64
new g_iCount;
new String:g_sMapinfo[MAX_CAMPAIGN_LIMIT][MAX_NAME_LENGTH];
new String:g_sMapname[MAX_CAMPAIGN_LIMIT][64];

enum voteType
{
	hp,
    alltalk,
	alltalk2,
	restartmap,
	kick,
	map,
	map2,
	forcespectate,
}
new voteType:g_voteType = voteType:hp;

new forcespectateid;
static			g_iSpectatePenaltyCounter[MAXPLAYERS + 1];
#define FORCESPECTATE_PENALTY 60
static g_votedelay;
#define VOTEDELAY_TIME 60

public Plugin:myinfo =
{
	name = "Votes Menu",
	author = "fenghf,l4d1 modify by Harry Potter and JJ",
	description = "Votes Commands",
	version = "1.8",
	url = "https://steamcommunity.com/profiles/76561198026784913/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	
	if( test != Engine_Left4Dead )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1.");
		return APLRes_SilentFailure;
	}

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

public OnPluginStart()
{
	LoadTranslations("Roto2-AZ_mod.phrases");

	RegConsoleCmd("callvote",Callvote_Handler); //block valve vote

	//RegAdminCmd("sm_voter", Command_Vote, ADMFLAG_KICK|ADMFLAG_VOTE|ADMFLAG_GENERIC|ADMFLAG_BAN|ADMFLAG_CHANGEMAP, "投票开启ready插件");S
	RegConsoleCmd("voteshp", Command_VoteHp);
	RegConsoleCmd("votesalltalk", Command_VoteAlltalk);
	RegConsoleCmd("votesalltalk2", Command_VoteAlltalk2);
	RegConsoleCmd("votesrestartmap", Command_VoteRestartmap);
	RegConsoleCmd("votesmapsmenu", Command_VotemapsMenu);
	RegConsoleCmd("votesmaps2menu", Command_Votemaps2Menu);
	RegConsoleCmd("voteskick", Command_VotesKick);
	RegConsoleCmd("sm_votes", Command_Votes, "open vote meun");
	RegConsoleCmd("votes", Command_Votes, "open vote meun");
	RegConsoleCmd("votesforcespectate", Command_Votesforcespectate);
	
	g_Cvar_Limits = CreateConVar("sm_votes_s", "0.60", "Pass vote percentage.", 0, true, 0.05, true, 1.0);
	VotensHpED = CreateConVar("l4d_vote_hpED", "1", "If 1, Enable Give HP Vote.", FCVAR_NOTIFY);
	VotensAlltalkED = CreateConVar("l4d_vote_alltalkED", "1", "If 1, Enable All Talk On Vote.", FCVAR_NOTIFY);
	VotensAlltalk2ED = CreateConVar("l4d_vote_alltalk2ED", "1", "If 1, Enable All Talk Off Vote.", FCVAR_NOTIFY);
	VotensRestartmapED = CreateConVar("l4d_vote_restartmapED", "1", "If 1, Enable Restart Current Map Vote.", FCVAR_NOTIFY);
	VotensMapED = CreateConVar("l4d_vote_mapED", "1", "If 1, Enable Change Value Map Vote.", FCVAR_NOTIFY);
	VotensMap2ED = CreateConVar("l4d_vote_map2ED", "1", "If 1, Enable Change Custom Map Vote.", FCVAR_NOTIFY);
	VotensED = CreateConVar("l4d_vote_enable", "1", "0=Off, 1=On this plugin", FCVAR_NOTIFY);
	VotensKickED = CreateConVar("l4d_vote_KickED", "1", "If 1, Enable Kick Player Vote.", FCVAR_NOTIFY);
	VotensForceSpectateED = CreateConVar("l4d_vote_ForceSpectateED", "1", "If 1, Enable ForceSpectate Player Vote.", FCVAR_NOTIFY);
	g_hCvarPlayerLimit = CreateConVar("sm_vote_player_limit", "2", "Minimum # of players in game to start the vote", FCVAR_NOTIFY);
	g_hKickImmueAccess = CreateConVar("l4d_vote_Kick_immue_access_flag", "z", "Players with these flags have kick immune. (Empty = Everyone, -1: Nobody)", FCVAR_NOTIFY);

	GetCvars();
	g_hKickImmueAccess.AddChangeHook(ConVarChanged_Cvars);

	HookEvent("round_start", event_Round_Start);
}

public void ConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

char g_sKickImmueAccesslvl[16];
GetCvars()
{
	g_hKickImmueAccess.GetString(g_sKickImmueAccesslvl,sizeof(g_sKickImmueAccesslvl));
}

public Action:event_Round_Start(Handle:event, const String:name[], bool:dontBroadcast)
{
	for(new i=1; i <= MaxClients; i++) ClientVoteMenu[i] = false; 
	
}

public OnClientPutInServer(client)
{
	g_iSpectatePenaltyCounter[client] = FORCESPECTATE_PENALTY;
}

public void OnConfigsExecuted()
{
	ConVar currentReadyMode = FindConVar("l4d_ready_enabled");
	if(currentReadyMode != null) {
		GetConVarString(currentReadyMode, ReadyMode, sizeof(ReadyMode));
	}
}

public OnMapStart()
{
	ParseCampaigns();
	
	g_votedelay = 15;
	CreateTimer(1.0, Timer_VoteDelay, _, TIMER_REPEAT| TIMER_FLAG_NO_MAPCHANGE);
	
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
		new VotensHpE_D = GetConVarInt(VotensHpED);
		new VotensAlltalkE_D = GetConVarInt(VotensAlltalkED);
		new VotensAlltalk2E_D = GetConVarInt(VotensAlltalk2ED);
		new VotensRestartmapE_D = GetConVarInt(VotensRestartmapED);		
		new VotensMapE_D = GetConVarInt(VotensMapED);
		new VotensMap2E_D = GetConVarInt(VotensMap2ED);
		bool VotensKickE_D = VotensKickED.BoolValue;
		bool VotensForceSpectateE_D = VotensForceSpectateED.BoolValue;

		decl String:Info[256];

		new Handle:menu = CreatePanel();
		Format(Info, sizeof(Info), "%T", "Vote Menu", client);
		SetPanelTitle(menu, Info);
		
		if (VotensHpE_D == 1)
		{
			Format(Info, sizeof(Info), "%T", "Give hp", client);
			DrawPanelItem(menu, Info);
		}
		else
		{
			Format(Info, sizeof(Info), "%T(%T)", "Give hp", client, "votes3_17", client);
			DrawPanelItem(menu, Info);	
		}
		if (VotensAlltalkE_D == 1)
		{
			Format(Info, sizeof(Info), "%T", "All talk", client);
			DrawPanelItem(menu, Info);
		}
		else
		{
			Format(Info, sizeof(Info), "%T(%T)", "All talk", client, "votes3_17", client);
			DrawPanelItem(menu, Info);	
		}
		if (VotensAlltalk2E_D == 1)
		{
			Format(Info, sizeof(Info), "%T", "Turn off all talk", client);
			DrawPanelItem(menu, Info);
		}
		else
		{
			Format(Info, sizeof(Info), "%T(%T)", "Turn off all talk", client, "votes3_17", client);
			DrawPanelItem(menu, Info);	
		}
		if (VotensRestartmapE_D == 1)
		{
			Format(Info, sizeof(Info), "%T", "Restartmap", client);
			DrawPanelItem(menu, Info);
		}
		else
		{
			Format(Info, sizeof(Info), "%T(%T)", "Restartmap", client, "votes3_17", client);
			DrawPanelItem(menu, Info);	
		}
		if (VotensMapE_D == 1)
		{
			Format(Info, sizeof(Info), "%T", "Change map", client);
			DrawPanelItem(menu, Info);
		}
		else
		{
			Format(Info, sizeof(Info), "%T(%T)", "Change map", client, "votes3_17", client);
			DrawPanelItem(menu, Info);	
		}
		if (VotensMap2E_D == 1)
		{
			Format(Info, sizeof(Info), "%T", "Change addon map", client);
			DrawPanelItem(menu, Info);
		}
		else
		{
			Format(Info, sizeof(Info), "%T(%T)", "Change addon map", client, "votes3_17", client);
			DrawPanelItem(menu, Info);	
		}
		if(VotensKickE_D)
		{
			Format(Info, sizeof(Info), "%T", "Kick player", client);
			DrawPanelItem(menu, Info);
		}
		else
		{
			Format(Info, sizeof(Info), "%T(%T)", "Kick player", client, "votes3_17", client);
			DrawPanelItem(menu, Info);	
		}
		if(VotensForceSpectateE_D)
		{
			Format(Info, sizeof(Info), "%T", "Forcespectate player", client);
			DrawPanelItem(menu, Info);
		}
		else
		{
			Format(Info, sizeof(Info), "%T(%T)", "Forcespectate player", client, "votes3_17", client);
			DrawPanelItem(menu, Info);	
		}
		DrawPanelText(menu, " \n");
		Format(Info, sizeof(Info), "0. %T","exit", client);
		DrawPanelText(menu, Info);
		SendPanelToClient(menu, client,Votes_Menu, MENU_TIME);
		return Plugin_Handled;
	}
	return Plugin_Stop;
}
public Votes_Menu(Handle:menu, MenuAction:action, client, itemNum)
{
	if ( action == MenuAction_Select ) 
	{
		new VotensHpE_D = GetConVarInt(VotensHpED); 
		new VotensAlltalkE_D = GetConVarInt(VotensAlltalkED);
		new VotensAlltalk2E_D = GetConVarInt(VotensAlltalk2ED);
		new VotensRestartmapE_D = GetConVarInt(VotensRestartmapED);
		new VotensMapE_D = GetConVarInt(VotensMapED);
		new VotensMap2E_D = GetConVarInt(VotensMap2ED);
		bool VotensKickE_D = VotensKickED.BoolValue;
		bool VotensForceSpectateE_D = VotensForceSpectateED.BoolValue;

		switch (itemNum)
		{
			case 1: 
			{
				if (VotensHpE_D == 0)
				{
					FakeClientCommand(client,"sm_votes");
					CPrintToChat(client, "{default}[{olive}TS{default}] %T","votes3_2",client);
					return;
				}
				else
				{
					FakeClientCommand(client,"voteshp");
				}
			}
			case 2: 
			{
				if (VotensAlltalkE_D == 0)
				{
					FakeClientCommand(client,"sm_votes");
					CPrintToChat(client, "{default}[{olive}TS{default}] %T","votes3_3",client);
					return;
				}
				else
				{
					FakeClientCommand(client,"votesalltalk");
				}
			}
			case 3: 
			{
				if (VotensAlltalk2E_D == 0)
				{
					FakeClientCommand(client,"sm_votes");
					CPrintToChat(client, "{default}[{olive}TS{default}] %T","votes3_4",client);
					return;
				}
				else
				{
					FakeClientCommand(client,"votesalltalk2");
				}
			}
			case 4: 
			{
				if (VotensRestartmapE_D == 0)
				{
					FakeClientCommand(client,"sm_votes");
					CPrintToChat(client, "{default}[{olive}TS{default}] %T","votes3_5",client);
					return;
				}
				else
				{
					FakeClientCommand(client,"votesrestartmap");
				}
			}
			case 5: 
			{
				if (VotensMapE_D == 0)
				{
					FakeClientCommand(client,"sm_votes");
					CPrintToChat(client, "{default}[{olive}TS{default}] %T","votes3_6",client);
					return ;
				}
				else
				{
					FakeClientCommand(client,"votesmapsmenu");
				}
			}
			case 6: 
			{
				if (VotensMap2E_D == 0)
				{
					FakeClientCommand(client,"sm_votes");
					CPrintToChat(client, "{default}[{olive}TS{default}] %T","votes3_7",client);
					return ;
				}
				else
				{
					FakeClientCommand(client,"votesmaps2menu");
				}
			}
			case 7: 
			{
				if(VotensKickE_D == false)
				{
					FakeClientCommand(client,"sm_votes");
					CPrintToChat(client, "{default}[{olive}TS{default}] %T","votes3_8",client);
					return ;
				}
				else
				{
					FakeClientCommand(client,"voteskick");
				}
			}
			case 8: 
			{
				if(VotensForceSpectateE_D == false)
				{
					FakeClientCommand(client,"sm_votes");
					CPrintToChat(client, "{default}[{olive}TS{default}] %T","votes3_9",client);
					return ;
				}
				else
				{
					FakeClientCommand(client,"votesforcespectate");
				}
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

public Action:Callvote_Handler(client, args)
{
	if(client == 0) return Plugin_Handled;

	CPrintToChat(client, "[TS] Valve Vote is blocked. Use {green}!votes{default} instead");

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
	else if(GetConVarInt(VotensHpED) == 0)
	{
		CPrintToChat(client, "{default}[{olive}TS{default}] %T","This vote is prohibited",client);
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
	else if(GetConVarInt(VotensAlltalkED) == 0)
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
	else if(GetConVarInt(VotensAlltalk2ED) == 0)
	{
		CPrintToChat(client, "{default}[{olive}TS{default}] %T","This vote is prohibited",client);
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
	else if(GetConVarInt(VotensRestartmapED) == 0)
	{
		CPrintToChat(client, "{default}[{olive}TS{default}] %T","This vote is prohibited",client);
	}
	return Plugin_Handled;
}
public Action:Command_VotesKick(client, args)
{
	if(client!=0)
	{
		if(GetConVarInt(VotensED) == 1 && VotensKickED.BoolValue == true)
		{
			CreateVoteKickMenu(client);	
		}
		else if(VotensKickED.BoolValue == false)
		{
			CPrintToChat(client, "{default}[{olive}TS{default}] %T","This vote is prohibited",client);
		}
	}	
	return Plugin_Handled;
}

CreateVoteKickMenu(client)
{	
	new Handle:menu = CreateMenu(Menu_VotesKick);		
	new team = GetClientTeam(client);
	new String:name[MAX_NAME_LENGTH];
	new String:playerid[32];
	decl String:Info[50];
	Format(Info, sizeof(Info), "%T", "Kick player", client);
	SetMenuTitle(menu, Info);
	for(new i = 1;i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && (GetClientTeam(i) == team || GetClientTeam(i) == 1) )
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
public Menu_VotesKick(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		new String:info[32] , String:name[32];
		GetMenuItem(menu, param2, info, sizeof(info), _, name, sizeof(name));
		int player = StringToInt(info);
		player = GetClientOfUserId(player);
		if(player && IsClientInGame(player))
		{
			if (player == param1)
			{
				CPrintToChatAll("{default}[{olive}TS{default}] Kick yourself? choose again");
				CreateVoteKickMenu(param1);
			}
			else 
			{
				if(HasAccess(player, g_sKickImmueAccesslvl))
				{
					CPrintToChat(param1, "{default}[{olive}TS{default}] %T", "votes3_19", param1);
					CPrintToChat(player, "{default}[{olive}TS{default}] %T", "votes3_20", player, param1);
					CreateVoteKickMenu(param1);
				}
				else
				{
					kickplayer_userid = GetClientUserId(player);
					kickplayer_name = name;
					GetClientAuthId(player, AuthId_Steam2,kickplayer_SteamId, sizeof(kickplayer_SteamId));
					DisplayVoteKickMenu(param1);
				}
			}
		}
		else
		{
			CPrintToChatAll("{default}[{olive}TS{default}] %t", "votes3_18");
			CreateVoteKickMenu(param1);
		}

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

public DisplayVoteKickMenu(client)
{
	if (!TestVoteDelay(client))
	{
		return;
	}
	
	if(CanStartVotes(client))
	{
		decl String:SteamId[35];
		GetClientAuthId(client, AuthId_Steam2,SteamId, sizeof(SteamId));
		LogMessage("%N(%s) starts a vote: kick %s(%s)",  client, SteamId, kickplayer_name, kickplayer_SteamId);//紀錄在log文件
		CPrintToChatAll("{default}[{olive}TS{default}]{olive} %N {default}%t: {blue}%t %s", client,"starts a vote", "Kick player", kickplayer_name);
		
		for(new i=1; i <= MaxClients; i++) 
			if (IsClientInGame(i) && !IsFakeClient(i))
				ClientVoteMenu[i] = true;
		
		g_voteType = voteType:kick;
		
		g_hVoteMenu = new Menu(Handler_VoteCallback, MENU_ACTIONS_ALL);
		g_hVoteMenu.SetTitle("%T: %s?","Kick player",LANG_SERVER,kickplayer_name);
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
	if(GetConVarInt(VotensMapED) == 0)
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
	else if(GetConVarInt(VotensMap2ED) == 0)
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
	if(client!=0)
	{
		if(GetConVarInt(VotensED) == 1 && VotensForceSpectateED.BoolValue == true)
		{
			CreateVoteforcespectateMenu(client);
		}
		else if(VotensForceSpectateED.BoolValue == false)
		{
			CPrintToChat(client, "{default}[{olive}TS{default}] %T","This vote is prohibited",client);
		}
	}		
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
		forcespectateplayername = name;
		
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
		LogMessage("%N(%s) starts a vote: forcespectate player %s",  client, SteamId,forcespectateplayername);//紀錄在log文件
		
		new iTeam = GetClientTeam(client);
		CPrintToChatAll("{default}[{olive}TS{default}] {olive}%N{default} %t: {blue}%t %s{default}, %t", client, "starts a vote","Forcespectate player",forcespectateplayername,"only their team can vote");
		
		for(new i=1; i <= MaxClients; i++) 
			if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == iTeam)
				ClientVoteMenu[i] = true;
		
		g_voteType = voteType:forcespectate;
		
		g_hVoteMenu = new Menu(Handler_VoteCallback, MENU_ACTIONS_ALL);
		g_hVoteMenu.SetTitle("%T: %s?","Forcespectate player",LANG_SERVER,forcespectateplayername);
		g_hVoteMenu.AddItem(VOTE_YES, "Yes");
		g_hVoteMenu.AddItem(VOTE_NO, "No");
		g_hVoteMenu.ExitButton = false;
		new iTotal = 0;
		new iPlayers[MaxClients];
		
		for (new i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i) || IsFakeClient(i) || GetClientTeam(i) != iTeam)
			{
				continue;
			}
			
			iPlayers[iTotal++] = i;
			EmitSoundToClient(i,"ui/beep_synthtone01.wav");
		}
		
		g_hVoteMenu.DisplayVote(iPlayers, iTotal, 20, 0);
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
			case (voteType:kick):
			{
				Format(buffer, sizeof(buffer), "%T: %s?","Kick player", param1,kickplayer_name);
			}
			case (voteType:forcespectate):
			{
				Format(buffer, sizeof(buffer), "%T: %s?","Forcespectate player", param1,forcespectateplayername);
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
			if (GetEntProp(i, Prop_Send, "m_isHangingFromLedge"))//懸掛
			{
				FakeClientCommand(i, "give health");
			}
			else if (IsIncapacitated(i))//倒地
			{
				FakeClientCommand(i, "give health");
				SetEntPropFloat(i, Prop_Send, "m_healthBufferTime", GetGameTime());
				SetEntPropFloat(i, Prop_Send, "m_healthBuffer", 0.0);
			}
			else if(GetClientHealth(i)<100) //血量低於100
			{
				FakeClientCommand(i, "give health");
				SetEntPropFloat(i, Prop_Send, "m_healthBufferTime", GetGameTime());
				SetEntPropFloat(i, Prop_Send, "m_healthBuffer", 0.0);
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
	return (float(votes) / float(totalVotes));
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
		if (!IsClientInGame(i) || IsFakeClient(i))
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

public Action:COLD_DOWN(Handle:timer,any:client)
{
	switch (g_voteType)
	{
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
		case (voteType:kick):
		{
			CPrintToChatAll("[{olive}TS{default}] %t","votes3_15", kickplayer_name);
			LogMessage("Vote to kick %s pass",kickplayer_name);

			int player = GetClientOfUserId(kickplayer_userid);
			if(player && IsClientInGame(player)) KickClient(player, "You have been kicked due to vote");				
			ServerCommand("sm_addban 10 \"%s\" \"You have been kicked due to vote\" ", kickplayer_SteamId);
		}
		case (voteType:forcespectate):
		{
			forcespectateid = GetClientOfUserId(forcespectateid);
			if(forcespectateid && IsClientInGame(forcespectateid)) 
			{
				CPrintToChatAll("[{olive}TS{default}] %t","votes3_16", forcespectateplayername);									
				LogMessage("Vote to forcespectate %s pass",forcespectateplayername);
				ChangeClientTeam(forcespectateid, 1);
				CreateTimer(1.0, Timer_forcespectate, forcespectateid, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
			}
			else
			{
				CPrintToChatAll("[{olive}TS{default}] %s player not found", forcespectateplayername);	
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

stock IsIncapacitated(client)
{
	return GetEntProp(client, Prop_Send, "m_isIncapacitated");
}

public bool HasAccess(int client, char[] g_sAcclvl)
{
	// no permissions set
	if (strlen(g_sAcclvl) == 0)
		return true;

	else if (StrEqual(g_sAcclvl, "-1"))
		return false;

	// check permissions
	int iFlag = GetUserFlagBits(client);
	if ( iFlag & ReadFlagString(g_sAcclvl))
	{
		return true;
	}

	return false;
}