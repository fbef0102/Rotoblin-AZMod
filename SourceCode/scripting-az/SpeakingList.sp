#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <clientprefs>
#include <basecomm>

int ClientSpeakingList[MAXPLAYERS+1] = {-1, ...};
bool ClientSpeakingTime[MAXPLAYERS+1];

ConVar va_print_speaklist;
ConVar va_alltalk_speaklist;
ConVar va_sv_alltalk;
ConVar va_spectator_speaklist;
ConVar hSV_VoiceEnable;
Handle g_hSpeakingList;
int i_alltalk_speaklist;
int	i_sv_alltalk;
int	i_print_speaklist;
	
char SpeakingPlayers[3][512];
int team;
#define UPDATESPEAKING_TIME_INTERVAL 0.5
native bool IsClientListenMode(int client); //Form l4d_versus_specListener3.0

public Plugin myinfo = 
{
	name = "SpeakingList",
	author = "Accelerator & HarryPotter",
	description = "Voice Announce. Print To Center Message who Speaking. With cookies",
	version = "1.9",
	url = "http://steamcommunity.com/profiles/76561198026784913"
}

public void OnPluginStart()
{	
	LoadTranslations("Roto2-AZ_mod.phrases");
	g_hSpeakingList = RegClientCookie("speaking-list", "SpeakList", CookieAccess_Protected);
	
	va_spectator_speaklist = CreateConVar("va_spectator_speaklist", "1", "Enable speaklist for spectators default? [1-Enable/0-Disable]", 0, true, 0.0, true, 1.0);
	va_alltalk_speaklist = CreateConVar("va_alltalk_speaklist", "1", "Enable speaklist when sv_alltalk on? [1-Enable/0-Disable]", 0, true, 0.0, true, 1.0);
	va_print_speaklist = CreateConVar("va_print_speaklist", "0", "How to show who is speaking? [0-Center/1-Hint]", 0, true, 0.0, true, 1.0);
	va_sv_alltalk = FindConVar("sv_alltalk");
	hSV_VoiceEnable = FindConVar("sv_voiceenable");
	
	RegConsoleCmd("sm_speaklist", Command_SpeakList, "Player Enable or Disable speaklist");
	
	CreateTimer(UPDATESPEAKING_TIME_INTERVAL, UpdateSpeaking, _, TIMER_REPEAT);
}

public void OnClientPutInServer(int client)
{
	if (!IsFakeClient(client))
	{
		if (AreClientCookiesCached(client))
		{
			char cookie[2];
			GetClientCookie(client, g_hSpeakingList, cookie, sizeof(cookie));
			ClientSpeakingList[client] = StringToInt(cookie);
			
			if (ClientSpeakingList[client] == 0)
				ClientSpeakingList[client] = GetConVarInt(va_spectator_speaklist);
		}
	}
}

public void OnClientDisconnect(int client)
{
	ClientSpeakingList[client] = -1;
}

public Action Command_SpeakList(int client, int args)
{
	if (!client || !IsClientInGame(client) || GetClientTeam(client)!=1 )
		return Plugin_Continue;
	
	if (ClientSpeakingList[client] == 1)
	{
		ClientSpeakingList[client] = -1;
		if (AreClientCookiesCached(client))
		{
			SetClientCookie(client, g_hSpeakingList, "-1");
		}
		PrintToChat(client, "%T","SpeakingList1",client);
	}
	else
	{
		ClientSpeakingList[client] = 1;
		if (AreClientCookiesCached(client))
		{
			SetClientCookie(client, g_hSpeakingList, "1");
		}
		PrintToChat(client, "%T","SpeakingList2",client);
	}
	return Plugin_Continue;
}

public void OnClientSpeaking(int client)
{
	if (!IsClientInGame(client)) return;
	
	if (BaseComm_IsClientMuted(client) 
		|| GetClientListeningFlags(client) == 1
		|| hSV_VoiceEnable.BoolValue == false)
	{
		return;
	}

	ClientSpeakingTime[client] = true;
}

public Action UpdateSpeaking(Handle timer)
{
	int iCount = 0;
	for(int i = 0; i < 3; i++)
		SpeakingPlayers[i][0] = '\0';

	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (ClientSpeakingTime[i])
		{
			if (!IsClientInGame(i)) continue;
			
			team = GetClientTeam(i)-1;
			if (team < 0 || team > 2) continue;
			
			Format(SpeakingPlayers[team], sizeof(SpeakingPlayers[]), "%s%N\n", SpeakingPlayers[team], i);
			iCount++;
		}
		ClientSpeakingTime[i] = false;
	}
	
	i_alltalk_speaklist = GetConVarInt(va_alltalk_speaklist);
	i_sv_alltalk = GetConVarInt(va_sv_alltalk);
	i_print_speaklist = GetConVarInt(va_print_speaklist);

	if(SpeakingPlayers[0][0] != '\0')
		Format(SpeakingPlayers[0], sizeof(SpeakingPlayers[]), "%t:\n%s","Spectator MIC", SpeakingPlayers[0]);
	if(SpeakingPlayers[1][0] != '\0')
		Format(SpeakingPlayers[1], sizeof(SpeakingPlayers[]), "%t:\n%s","Survivor MIC", SpeakingPlayers[1]);
	if(SpeakingPlayers[2][0] != '\0')
		Format(SpeakingPlayers[2], sizeof(SpeakingPlayers[]), "%t:\n%s","Infected MIC", SpeakingPlayers[2]);
	
	char ShowSpeakingPlayers[1560];
	Format(ShowSpeakingPlayers, sizeof(ShowSpeakingPlayers), "%s%s%s",SpeakingPlayers[0],SpeakingPlayers[1],SpeakingPlayers[2]);
	
	if (iCount > 0)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i)&&!IsFakeClient(i)&&ClientSpeakingList[i]>0)
			{
				if ( (GetClientTeam(i) == 1 && i_sv_alltalk == 0 && IsClientListenMode(i))//Spectator + alltalk 0 + open listen mode
				|| (i_alltalk_speaklist == 1 && i_sv_alltalk == 1) )//or Enable speaklist when sv_alltalk on
				{		
					SetGlobalTransTarget(i);
					if(i_print_speaklist==0)	PrintCenterText(i, "%s",ShowSpeakingPlayers);
					else	PrintHintText(i, "%s",ShowSpeakingPlayers);
				}
			}
		}
	}
}