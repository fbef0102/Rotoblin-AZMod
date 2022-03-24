
/*=======================================================================================
	Change Log:

1.1 (26-03-2019)
	- Initial release.
	- Cleared old code, converted to new syntax and methodmaps.	
1.2 (13-04-2019)
	- fix error, optimize codes, and handle exception
	
1.3 (15-04-2020)
	- 給那些沒有換隊!survivor與!infected指令的傻B對抗插件強制換隊
  
========================================================================================
	Credits:

	KaiN - for request and the original idea	
	ZenServer -[ Mix ]- - for the original plugin
	JOSHE GATITO SPARTANSKII >>> (Ex Aya Supay) - for writing  plugin again and add new commands. 
  Harry - fix error, optimize codes, and handle exception

========================================================================================*/

#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <multicolors>

#define TEAM_SPECTATOR 1
#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3
#define PLUGIN_VERSION		"1.3"
#define G_flTickInterval 0.25

bool g_bTeamRequested[4];
bool g_bPlayerSelectOrder;
ConVar g_hPlayerSelectOrder;
ConVar g_CvarMixStatus;
ConVar g_CvarSurvLimit;
ConVar g_CvarMaxPlayerZombies;
bool g_bSelectToggle;
int g_SelectToggleNum;
bool g_bHasVoted[66];
bool g_bHasOneVoted;
bool g_bHasBeenChosen[66];
bool g_lock;
int g_iSurvivorCaptain;
int g_iInfectedCaptain;
int g_iVotesSurvivorCaptain[66];
int g_iVotesInfectedCaptain[66];
int g_iDesignatedTeam[66];
int g_iSelectedPlayers[66];
int g_iCvar = 262144;
char teamName[64] ;
char oppositeTeamName[64] ;
native bool IsInReady();
native bool Is_Ready_Plugin_On();
native void ClientVoteMenuSet(int client,int true_or_false);//From Votes3

public Plugin myinfo = 
{
	name = "Left 4 Dead Modo Mix",
	author = "Joshe Gatito & ZenServer",
	description = "Modo de juego Mix",
	version = PLUGIN_VERSION,
	url = "https://steamcommunity.com/id/joshegatito/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if (test != Engine_Left4Dead)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("Roto2-AZ_mod.phrases");
	g_CvarMixStatus = CreateConVar("mix_status", "0", "The status of the mix. DO NOT MANUALLY ALTER THIS CVAR U SON OF A FUCK", 262144, false, 0.0, false, 0.0);	

	g_CvarSurvLimit = FindConVar("survivor_limit");
	g_CvarMaxPlayerZombies = FindConVar("z_max_player_zombies");
	
	CaptainVote_OnPluginStart();
	g_hPlayerSelectOrder = CreateConVar("mix_select_order", "1", "0 = ABABAB    |    1 = ABBAABBA", g_iCvar, false, 0.0, false, 0.0);
	g_bPlayerSelectOrder = g_hPlayerSelectOrder.BoolValue;
	g_hPlayerSelectOrder.AddChangeHook(ConVarChange_MixOrder);
	g_CvarMixStatus.AddChangeHook(ConVarChange_MixStatus);
	
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);
}

public void CaptainVote_OnPluginStart()
{
	LoadTranslations("common.phrases");
	RegConsoleCmd("sm_mix", Command_Captainvote, "Initiate a player mix. Only works during readyup");
	RegAdminCmd("sm_forcemix", Command_ForceCaptainvote, ADMFLAG_BAN, "Initiate a player mix. Only works during readyup. Admins only.");
	g_CvarMixStatus.SetInt(0, false, false);
	ResetSelectedPlayers();
	ResetTeams();
	ResetCaptains();
	ResetAllVotes();
	ResetHasVoted();
}

public void OnMapEnd()
{
	CaptainVote_OnMapEnd();
}

public void OnMapStart()
{
	CaptainVote_OnMapStart();
}

public Action Event_RoundStart(Event event, char[] name, bool dontBroadcast)
{
	g_lock = false;
	CaptainVote_Event_RoundStart(event, name, dontBroadcast);
	return Plugin_Continue;
}

public Action Event_RoundEnd(Event event, char[] name, bool dontBroadcast)
{
	CaptainVote_Event_RoundEnd(event, name, dontBroadcast);
	return Plugin_Continue;
}

public void ConVarChange_MixOrder(Handle convar, char[] oldValue, char[] newValue)
{
	g_bPlayerSelectOrder = g_hPlayerSelectOrder.BoolValue;
}

public Action Timer_RegisterConVar(Handle timer)
{
	g_CvarMixStatus.AddChangeHook(ConVarChange_MixStatus);
	return Plugin_Continue;
}

public void CaptainVote_ConVarChange_MixStatus(Handle convar, char[] oldValue, char[] newValue)
{
	if (StrEqual(oldValue, newValue, true)) return;
	if (g_CvarMixStatus.IntValue == 0)
	{
		for(int i=1; i <= MaxClients; i++) ClientVoteMenuSet(i,2);
		ResetSelectedPlayers();
		ResetTeams();
		ResetCaptains();
		ResetAllVotes();
		ResetHasVoted();
		g_bTeamRequested[2] = false;
		g_bTeamRequested[3] = false;
	}
	if (g_CvarMixStatus.IntValue == 3)
	{
		for(int i=1; i <= MaxClients; i++) 
			ClientVoteMenuSet(i,2);
		ClientVoteMenuSet(g_iSurvivorCaptain,1);	
		ClientVoteMenuSet(g_iInfectedCaptain,1);
		g_bSelectToggle = false;
		g_SelectToggleNum = 1;
		if(g_bPlayerSelectOrder)
			CPrintToChatAll("{default}[{olive}Mix{default}] %t","l4d_Modo_mix_mm1","A-BB-AA-B");
		else
			CPrintToChatAll("{default}[{olive}Mix{default}] %t","l4d_Modo_mix_mm1","A-B-A-B-A-B");
			
		DisplayVoteMenuPlayerSelect();
	}
	if (g_CvarMixStatus.IntValue == 4)
	{
		CPrintToChatAll("{default}[{olive}Mix{default}] %t","l4d_Modo_mix_mm2");
		SwapPlayersToDesignatedTeams();
		g_CvarMixStatus.SetInt(0, false, false);
	}
	if (g_CvarMixStatus.IntValue == 5)
	{
		g_CvarMixStatus.SetInt(0, false, false);
	}
}

public Action Command_Captainvote(int client, int args)
{
	char CommandArgs[128];
	GetCmdArgString(CommandArgs, 128);

	if ( !Is_Ready_Plugin_On() || !IsInReady() )
	{
		if ( client == 0 ) {
			PrintToServer( "{default}[{olive}Mix{default}] %t","l4d_teamshuffle1","Mix");
		} else {
			CPrintToChat( client, "{default}[{olive}Mix{default}] %T","l4d_teamshuffle1",client,"Mix");
		}
		return Plugin_Handled;
    }
	
	int surfreeslots = GetTeamMaxHumans(2);
	int inffreeslots = GetTeamMaxHumans(3);
	int freeslots =  surfreeslots+inffreeslots;
	int real_players = checkrealplayerinSV();
	if(freeslots > real_players)
	{
		CPrintToChat(client,"{default}[{olive}Mix{default}] %T ({red}%d{default}/{green}%d{default}).","Can't start a mix, not enough players",client, real_players,freeslots);
		return Plugin_Handled;
	}
	if(surfreeslots == 1 || inffreeslots == 1)
	{
		CPrintToChat(client,"{default}[{olive}Mix{default}] %T ({green}%d{default}-{green}%d{default})","Can't start a mix, not enough players",client,surfreeslots,inffreeslots);
		return Plugin_Handled;
	}
	
	if (0 < args)
	{
		GetCmdArgString(CommandArgs, 128);
		if (g_CvarMixStatus.IntValue && g_bTeamRequested[2] && g_bTeamRequested[3])
		{
			if (GetClientTeam(client) == TEAM_SURVIVOR || GetClientTeam(client) == TEAM_INFECTED)
			{
				if (StrEqual(CommandArgs, "cancel", true))
				{
					g_CvarMixStatus.SetInt(5, false, false);
				}
				CPrintToChatAll("{default}[{olive}Mix{default}] {lightgreen}%N {olive}%t","canceled the command request.","!mix", client);
			}
			else
			{
				CPrintToChat(client, "{default}[{olive}Mix{default}] %T","Spectators cannot use command.",client,"!mix");
			}
		}
		else
		{
			CPrintToChat(client, "{default}[{olive}Mix{default}] %T","Nothing to cancel.",client);
		}
		return Plugin_Handled;
	}
	if (g_CvarMixStatus.IntValue)
	{
		CPrintToChat(client, "{default}[{olive}Mix{default}] %T","Shuffle is already in progress!",client,"Mix");
		return Plugin_Handled;
	}
	if (GetClientTeam(client) == TEAM_SPECTATOR)
	{
		CPrintToChat(client, "{default}[{olive}Mix{default}] %T","Spectators cannot use command.",client,"!mix");
		return Plugin_Handled;
	}
	
	int TeamID = GetClientTeam(client);
	if(g_lock == false)
	{	
		if (TeamID == 2)
		{
			teamName = "{blue}Survivors{default}";
			oppositeTeamName = "{red}Infected{default}";
		}
		if (TeamID == 3)
		{
			teamName = "{red}Infected{default}";
			oppositeTeamName = "{blue}Survivors{default}";
		}
	}
	if (g_bTeamRequested[TeamID])
	{
		CPrintToChat(client, "{default}[{olive}Mix{default}] %T","l4d_Modo_mix_mm3",client);
		return Plugin_Handled;
	}
	g_bTeamRequested[TeamID] = true;
	if (g_bTeamRequested[2] && g_bTeamRequested[3])
	{
		g_CvarMixStatus.SetInt(1, false, false);
		VoteSurvivorCaptain();
		CPrintToChatAll("{default}[{olive}Mix{default}] %t","l4d_Modo_mix_mm4", oppositeTeamName);
		g_bTeamRequested[2] = false;
		g_bTeamRequested[3] = false;
		return Plugin_Handled;
	}
	CPrintToChatAll("{default}[{olive}Mix{default}] %t","l4d_Modo_mix_mm5", teamName);
	CPrintToChatAll("{default}%t","l4d_Modo_mix_mm6", oppositeTeamName,"!mix");
	g_lock = true;
	CreateTimer(10.0, Timer_LoadMix, view_as<any>(2), 0);
	return Plugin_Handled;
}

public Action Command_ForceCaptainvote (int client, int args)
{
	if ( !Is_Ready_Plugin_On() || !IsInReady() )
	{
        if ( client == 0 ) {
            PrintToServer( "{default}[{olive}Mix{default}] %t","l4d_teamshuffle1","Mix" );
        } else {
            CPrintToChat( client, "{default}[{olive}Mix{default}] %T","l4d_teamshuffle1",client,"Mix" );
        }
        return Plugin_Handled;
	}
	
	int surfreeslots = GetTeamMaxHumans(2);
	int inffreeslots = GetTeamMaxHumans(3);
	int freeslots =  surfreeslots+inffreeslots;
	int real_players = checkrealplayerinSV();
	if(freeslots > real_players)
	{
        CPrintToChat(client,"{default}[{olive}Mix{default}] %T ({red}%d{default}/{green}%d{default}).","Can't start a mix, not enough players",client, real_players,freeslots);
        return Plugin_Handled;
	}
	if(surfreeslots == 1 || inffreeslots == 1)
    {
        CPrintToChat(client,"{default}[{olive}Mix{default}] %T ({green}%d{default}-{green}%d{default})","Can't start a mix, not enough players",client,surfreeslots,inffreeslots);
        return Plugin_Handled;
	}
	
	CPrintToChatAll("[{olive}TS{default}] {lightgreen}%N {default}%t",client,"has forced the team shuffle","Mix");
	g_CvarMixStatus.SetInt(1, false, false);
	VoteSurvivorCaptain();
	g_bTeamRequested[2] = false;
	g_bTeamRequested[3] = false;
	g_lock = false;
	return Plugin_Handled;
}

public Action Timer_LoadMix(Handle timer)
{
	if (g_CvarMixStatus.IntValue) return Plugin_Handled;
	g_bTeamRequested[2] = false;
	g_bTeamRequested[3] = false;
	if(g_lock)
	{
		CPrintToChatAll("{default}[{olive}Mix{default}] Mix %t","request timed out.");
		g_lock = false;
	}
	return Plugin_Handled;
}

void VoteSurvivorCaptain()
{
    for(int i=1; i <= MaxClients; i++) ClientVoteMenuSet(i,1);
    ResetSelectedPlayers();
    ResetTeams();
    ResetCaptains();
    ResetAllVotes();
    ResetHasVoted();
    DisplayVoteMenuCaptainSurvivor();
}

void DisplayVoteMenuCaptainSurvivor()
{
	if (g_CvarMixStatus.IntValue)
	{
		g_CvarMixStatus.SetInt(2, false, false);
		Menu SurvivorCaptainMenu = new Menu(Handler_SurvivorCaptainCallback, MENU_ACTIONS_DEFAULT);
		SurvivorCaptainMenu.SetTitle("%T","Choose Survivor Captain",LANG_SERVER);
		int players;
		g_bHasOneVoted = false;
		char name[32];
		char number[12];
		for(int i = 1; i <= MaxClients; i++) 
		{
			if (IsClientInGame(i)&&!IsFakeClient(i))
			{
				Format(name, 32, "%N", i);
				Format(number, 10, "%i", i);
				SurvivorCaptainMenu.AddItem(number, name, 0);
				players++;
			}
		}
		SurvivorCaptainMenu.ExitButton = true;
		for(int i = 1; i <= MaxClients; i++) 
			if (IsClientInGame(i)&&!IsFakeClient(i))
				SurvivorCaptainMenu.Display(i, 10);


		CreateTimer(10.1, TimerCheckSurvivorCaptainVote, view_as<any>(2), 0);
	}
}

public Action TimerCheckSurvivorCaptainVote(Handle timer)
{
	if (g_CvarMixStatus.IntValue)
	{
		if (!g_bHasOneVoted)
		{
			VoteSurvivorCaptain();
		}
		else
		{
			CalculateSurvivorCaptain();
			if (!IsValidClient(g_iSurvivorCaptain))
			{
				CPrintToChatAll("{default}[{olive}Mix{default}] %t","l4d_Modo_mix_mm7");
				g_CvarMixStatus.SetInt(5, false, false);
				return Plugin_Handled;
			}
			decl String:g_iSurvivorCaptainName[128];
			GetClientName(g_iSurvivorCaptain,g_iSurvivorCaptainName,128);

			CPrintToChatAll("{default}[{olive}Mix{default}] %t","l4d_Modo_mix_mm8", g_iSurvivorCaptainName, g_iVotesSurvivorCaptain[g_iSurvivorCaptain]);
			ClientVoteMenuSet(g_iSurvivorCaptain,1);	
			DisplayVoteMenuCaptainInfected();
		}
		return Plugin_Handled;
	}
	return Plugin_Handled;
}

public int Handler_SurvivorCaptainCallback(Menu menu, MenuAction action, int param1, int param2)
{
	if ( action == MenuAction_Display)
	{
		char buffer[255];
		Format(buffer, sizeof(buffer), "%T", "Choose Survivor Captain", param1);
		Panel panel = view_as<Panel>(param2);
		panel.SetTitle(buffer);
	}
	switch (action)
	{
		case 4:
		{
			char item[16];
			menu.GetItem(param2, item, 16);
			int targetplayer = StringToInt(item, 10);
			if (IsClientInGame(targetplayer) && !IsFakeClient(targetplayer))
			{
				g_iVotesSurvivorCaptain[targetplayer]++;
				g_bHasOneVoted = true;
			}
		}
	}
}

void DisplayVoteMenuPlayerSelect()
{
	if (g_CvarMixStatus.IntValue)
	{
		g_CvarMixStatus.SetInt(3, false, false);
		Menu PlayerSelectMenu = new Menu(Handler_PlayerSelectionCallback, MENU_ACTIONS_DEFAULT);
		PlayerSelectMenu.SetTitle("%T","Choose wisely...",LANG_SERVER);
		char name[32];
		char number[12];
		for(int i = 1; i <= MaxClients; i++) 
		{
			if ( IsValidClient(i) && !IsFakeClient(i) && !g_bHasBeenChosen[i] && i != g_iSurvivorCaptain && i != g_iInfectedCaptain )
			{
				Format(name, 32, "%N", i);
				Format(number, 10, "%i", i);
				PlayerSelectMenu.AddItem(number, name, 0);
			}
		}
		PlayerSelectMenu.ExitButton = true;
		if (!IsValidClient(g_iSurvivorCaptain))
		{
			CPrintToChatAll("{default}[{olive}Mix{default}] %t","l4d_Modo_mix_mm7");
			g_CvarMixStatus.SetInt(5, false, false);
			return;
		}
		if (!IsValidClient(g_iInfectedCaptain))
		{
			CPrintToChatAll("{default}[{olive}Mix{default}] %t","l4d_Modo_mix_mm9");
			g_CvarMixStatus.SetInt(5, false, false);
			return;
		}
		
		if (IsValidClient(g_iSurvivorCaptain) && IsValidClient(g_iInfectedCaptain))
		{
			if (!g_bSelectToggle)
			{
				PlayerSelectMenu.Display(g_iSurvivorCaptain, 1);
			}
			if (g_bSelectToggle)
			{
				PlayerSelectMenu.Display(g_iInfectedCaptain, 1);
			}
		}
		CreateTimer(1.1, Timer_PlayerSelection, view_as<any>(1), 0);
	}
}

public int Handler_PlayerSelectionCallback(Menu menu, MenuAction action, int param1, int param2)
{
	if ( action == MenuAction_Display)
	{
		char buffer[255];
		Format(buffer, sizeof(buffer), "%T", "Choose wisely...", param1);
		Panel panel = view_as<Panel>(param2);
		panel.SetTitle(buffer);
	}
	switch (action)
	{
		case 4:
		{
			char item[16];
			menu.GetItem(param2, item, 16);
			int targetplayer = StringToInt(item, 10);
			if (IsClientInGame(targetplayer) && !IsFakeClient(targetplayer))
			{
				g_bHasBeenChosen[targetplayer] = true;
				if (!g_bSelectToggle)
				{
					g_iDesignatedTeam[targetplayer] = 2;
					CPrintToChatAll("{default}[{olive}Mix{default}] {blue}%N {default}%t: {green}%N", g_iSurvivorCaptain,"selected", targetplayer);
					g_iSelectedPlayers[g_iSurvivorCaptain]++;
				}
				else
				{
					g_iDesignatedTeam[targetplayer] = 3;
					CPrintToChatAll("{default}[{olive}Mix{default}] {red}%N {default}%t: {green}%N", g_iInfectedCaptain,"selected", targetplayer);
					g_iSelectedPlayers[g_iInfectedCaptain]++;
				}
				
				if (!g_bPlayerSelectOrder)//A-B-A-B-A-B
				{
					g_bSelectToggle = !g_bSelectToggle;
				}
				else //A-BB-AA-B
				{
					g_SelectToggleNum++;
					if(g_SelectToggleNum==2)
						g_bSelectToggle = !g_bSelectToggle;
					else if(g_SelectToggleNum%2 == 0)
						g_bSelectToggle = !g_bSelectToggle;
				}
			}
			else
			{
				CPrintToChat(param1,"{default}[{olive}Mix{default}] %T","l4d_Modo_mix_mm10",param1);
			}
		}
		case 16:
		{
			if (menu)
			{
				delete menu;
			}
		}
	}
}

public Action Timer_PlayerSelection(Handle timer)
{
	if (g_CvarMixStatus.IntValue)
	{
		int SurvivorLimit = g_CvarSurvLimit.IntValue;
		int InfectedLimit = g_CvarMaxPlayerZombies.IntValue;
		if (g_iSelectedPlayers[g_iSurvivorCaptain] >= SurvivorLimit -1 && g_iSelectedPlayers[g_iInfectedCaptain] >= InfectedLimit -1)
		{
			g_CvarMixStatus.SetInt(4, false, false);
			return Plugin_Stop;//4
		}
		
		int freeslots =  SurvivorLimit + InfectedLimit;
		int real_players = checkrealplayerinSV();
		if(freeslots > real_players)
		{
			CPrintToChatAll("{default}[{olive}Mix{default}] %t","l4d_Modo_mix_mm11", real_players,freeslots);
			g_CvarMixStatus.SetInt(5, false, false);
			return Plugin_Handled;
		}
	
		DisplayVoteMenuPlayerSelect();
		return Plugin_Continue;
	}
	return Plugin_Stop;
}

void DisplayVoteMenuCaptainInfected()
{
	Menu InfectedCaptainMenu = new Menu(Handler_InfectedCaptainCallback, MENU_ACTIONS_DEFAULT);
	InfectedCaptainMenu.SetTitle("%T","Choose Infected Captain",LANG_SERVER);
	int players;
	g_bHasOneVoted = false;
	char name[32];
	char number[12];
	for(int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i) && g_iSurvivorCaptain != i)
		{
			Format(name, 32, "%N", i);
			Format(number, 10, "%i", i);
			InfectedCaptainMenu.AddItem(number, name, 0);
			players++;
		}
	}
	InfectedCaptainMenu.ExitButton = true;
	
	for(int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && !IsFakeClient(i) && g_iSurvivorCaptain != i)
			InfectedCaptainMenu.Display(i, 10);
			
	CreateTimer(10.1, TimerCheckInfectedCaptainVote, view_as<any>(2), 0);
}

public Action TimerCheckInfectedCaptainVote(Handle timer)
{
	if (g_CvarMixStatus.IntValue)
	{
		if (!g_bHasOneVoted)
		{
			DisplayVoteMenuCaptainInfected();
		}
		else
		{
			CalculateInfectedCaptain();
			if (!IsValidClient(g_iInfectedCaptain))
			{
				CPrintToChatAll("{default}[{olive}Mix{default}] %t","l4d_Modo_mix_mm9");
				g_CvarMixStatus.SetInt(5, false, false);
				return Plugin_Handled;
			}
			
			decl String:g_iInfectedCaptainName[128];
			GetClientName(g_iInfectedCaptain,g_iInfectedCaptainName,128);
			
			CPrintToChatAll("{default}[{olive}Mix{default}] %t","l4d_Modo_mix_mm12", g_iInfectedCaptainName, g_iVotesInfectedCaptain[g_iInfectedCaptain]);
			ClientVoteMenuSet(g_iInfectedCaptain,1);
			g_CvarMixStatus.SetInt(3, false, false);
		}
		return Plugin_Handled;
	}
	return Plugin_Handled;
}

public int Handler_InfectedCaptainCallback(Menu menu, MenuAction action, int param1, int param2)
{
	if ( action == MenuAction_Display)
	{
		char buffer[255];
		Format(buffer, sizeof(buffer), "%T", "Choose Infected Captain", param1);
		Panel panel = view_as<Panel>(param2);
		panel.SetTitle(buffer);
	}
	switch (action)
	{
		case 4:
		{
			char item[16];
			menu.GetItem(param2, item, 16);
			int targetplayer = StringToInt(item, 10);
			if (IsClientInGame(targetplayer) && !IsFakeClient(targetplayer))
			{
				g_iVotesInfectedCaptain[targetplayer]++;
				g_bHasOneVoted = true;
			}
		}
	}
}

void ResetCaptains()
{
	g_iSurvivorCaptain = 0;
	g_iInfectedCaptain = 0;
}

void ResetAllVotes()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		g_iVotesSurvivorCaptain[i] = 0;
		g_iVotesInfectedCaptain[i] = 0;
	}
}

void ResetTeams()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		g_iDesignatedTeam[i] = 1;
	}
}

void ResetSelectedPlayers()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		g_iSelectedPlayers[i] = 0;
		g_bHasBeenChosen[i] = false;
	}
}

void CalculateSurvivorCaptain()
{
	int highestvotes;
	for(int i = 1; i <= MaxClients; i++)
	{
		if (g_iVotesSurvivorCaptain[i] > highestvotes)
		{
			highestvotes = g_iVotesSurvivorCaptain[i];
			g_iSurvivorCaptain = i;
			g_iDesignatedTeam[i] = 2;
		}
	}
}

void CalculateInfectedCaptain()
{
	int highestvotes;
	for(int i = 1; i <= MaxClients; i++)
	{
		if (g_iVotesInfectedCaptain[i] > highestvotes)
		{
			highestvotes = g_iVotesInfectedCaptain[i];
			g_iInfectedCaptain = i;
			g_iDesignatedTeam[i] = 3;
		}
	}
}

void ResetHasVoted()
{
	g_bHasOneVoted = false;
	for(int i = 1; i <= MaxClients; i++) 
	{
		g_bHasVoted[i] = false;
	}
}

public void CaptainVote_OnMapStart()
{
	g_CvarMixStatus.SetInt(0, false, false);
	ResetSelectedPlayers();
	ResetTeams();
	ResetCaptains();
	ResetAllVotes();
	ResetHasVoted();
}

public void CaptainVote_OnMapEnd()
{
	g_CvarMixStatus.SetInt(0, false, false);
	ResetSelectedPlayers();
	ResetTeams();
	ResetCaptains();
	ResetAllVotes();
	ResetHasVoted();
}

public Action CaptainVote_Event_RoundStart(Event event, char[] name, bool dontBroadcast)
{
	g_CvarMixStatus.SetInt(0, false, false);
}

public Action CaptainVote_Event_RoundEnd(Event event, char[] name, bool dontBroadcast)
{
	g_CvarMixStatus.SetInt(0, false, false);
}

public int CaptainVote_OnClientDisconnect_Post(int client)
{
	g_iVotesSurvivorCaptain[client] = 0;
	g_iVotesInfectedCaptain[client] = 0;
	g_bHasVoted[client] = false;
}

void SwapPlayersToDesignatedTeams()
{
	g_iDesignatedTeam[g_iSurvivorCaptain] = TEAM_SURVIVOR;
	g_iDesignatedTeam[g_iInfectedCaptain] = TEAM_INFECTED;
	for(int i = 1; i <= MaxClients; i++) 
		if (IsValidClient(i) && !IsFakeClient(i) && GetClientTeam(i) != TEAM_SPECTATOR)
			ChangeClientTeam(i, 1);
	
	
	for(int i = 1; i <= MaxClients; i++) 
	{
		if (IsValidClient(i) && !IsFakeClient(i))
		{
			if (g_iDesignatedTeam[i] == TEAM_SURVIVOR)
			{
				CreateTimer(G_flTickInterval, MoveToSurvivor, i, 2);
			}
			if (g_iDesignatedTeam[i] == TEAM_INFECTED)
			{
				CreateTimer(G_flTickInterval, MoveToInfected, i, 2);
			}
		}
	}
	g_CvarMixStatus.SetInt(0, false, false);
}

public Action MoveToSurvivor(Handle timer, any targetplayer)
{
	if(!targetplayer || !IsClientInGame(targetplayer)) return Plugin_Continue;

	FakeClientCommand(targetplayer, "sm_survivor");
	
	CreateTimer(0.1, CheckClientInSurvivorTeam, targetplayer, _);
	return Plugin_Continue;
}

public Action MoveToInfected(Handle timer, any targetplayer)
{
	if(!targetplayer || !IsClientInGame(targetplayer)) return Plugin_Continue;

	FakeClientCommand(targetplayer, "sm_infected");
	
	CreateTimer(0.1, CheckClientInInfectedTeam, targetplayer, _);
	return Plugin_Continue;
}

public Action:CheckClientInSurvivorTeam(Handle:timer, any:client)
{
	if(!client || !IsClientInGame(client)) return;
	
	if (GetClientTeam(client) != 2)
		CreateTimer(0.1, Survivor_Take_Control, client, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:CheckClientInInfectedTeam(Handle:timer, any:client)
{
	if(!client || !IsClientInGame(client)) return;
	
	if (GetClientTeam(client) != 3)
		ChangeClientTeam(client, 3);
}

public Action:Survivor_Take_Control(Handle:timer, any:client)
{
		new localClientTeam = GetClientTeam(client);
		new String:command[] = "sb_takecontrol";
		new flags = GetCommandFlags(command);
		SetCommandFlags(command, flags & ~FCVAR_CHEAT);
		new String:botNames[][] = { "teengirl", "manager", "namvet", "biker" ,"coach","gambler","mechanic","producer"};
		
		new i = 0;
		while((localClientTeam != 2) && i < 8)
		{
			FakeClientCommand(client, "sb_takecontrol %s", botNames[i]);
			localClientTeam = GetClientTeam(client);
			i++;
		}
		SetCommandFlags(command, flags);
}

/*
bool IsSurvivorTeamFull()
{
	int g_iSurvivorTeamSize;
	for(int i = 1; i <= MaxClients; i++) 
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || GetClientTeam(i) == TEAM_SURVIVOR)
		{
		}
	}
	g_iSurvivorTeamSize++;
	int SurvivorLimit = g_CvarSurvLimit.IntValue;
	if (SurvivorLimit == g_iSurvivorTeamSize) return true;
	return false;
}

bool IsInfectedTeamFull()
{
	int g_iInfectedTeamSize;
	for(int i = 1; i <= MaxClients; i++) 
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || GetClientTeam(i) == TEAM_INFECTED)
		{
		}
	}
	g_iInfectedTeamSize++;
	int InfectedLimit = g_CvarMaxPlayerZombies.IntValue;
	if (InfectedLimit == g_iInfectedTeamSize) return true;
	return false;
}

bool IsClientInTeam(int client)
{
	if (!IsClientInGame(client) || IsFakeClient(client)) return false;
	if (GetClientTeam(client) == TEAM_SURVIVOR || GetClientTeam(client) == TEAM_INFECTED) return true;
	return false;
}
*/
public void ConVarChange_MixStatus(Handle convar, char[] oldValue, char[] newValue)
{
	CaptainVote_ConVarChange_MixStatus(convar, oldValue, newValue);
}

bool IsValidClient(int client)
{
	if (client < 1 || client > MaxClients) return false;
	return IsClientInGame(client);
}

int GetTeamMaxHumans(int team)
{
	if(team == 2)
	{
		return g_CvarSurvLimit.IntValue;
	}
	else if(team == 3)
	{
		return g_CvarMaxPlayerZombies.IntValue;
	}
	
	return -1;
}

int checkrealplayerinSV()
{
	int players = 0;
	for (int i = 1; i < MaxClients+1; i++)
		if(IsClientConnected(i)&&IsClientInGame(i)&&!IsFakeClient(i))
			players++;
		
	return players;
}