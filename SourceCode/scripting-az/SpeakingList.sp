#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <clientprefs>
#include <basecomm>

int ClientSpeakingList[MAXPLAYERS+1] = {-1, ...};
bool ClientSpeakingTime[MAXPLAYERS+1];

ConVar va_sv_alltalk, hSV_VoiceEnable;
ConVar va_spectator_speaklist, va_alltalk_speaklist, va_print_speaklist;

int	g_iCvarSvAlltalk;
bool g_bCvarSVVoiceEnable;
int g_iCvarSpectatorSpeaklist;
int g_iCvarAlltalkSpeaklist;
int	g_iCvarPrintSpeaklist;

Handle g_hSpeakingList;
char SpeakingPlayers[512];
#define UPDATESPEAKING_TIME_INTERVAL 0.5

public Plugin myinfo = 
{
	name = "SpeakingList",
	author = "Accelerator & HarryPotter",
	description = "Voice Announce. Print To Center Message who Speaking. With cookies",
	version = "2.0",
	url = "http://steamcommunity.com/profiles/76561198026784913"
}

public void OnPluginStart()
{	
	LoadTranslations("Roto2-AZ_mod.phrases");
	g_hSpeakingList = RegClientCookie("speaking-list", "SpeakList", CookieAccess_Protected);

	va_sv_alltalk = FindConVar("sv_alltalk");
	hSV_VoiceEnable = FindConVar("sv_voiceenable");
	
	va_spectator_speaklist = CreateConVar("va_spectator_speaklist", "1", "Enable speaklist for spectators default? [1-Enable/0-Disable]", 0, true, 0.0, true, 1.0);
	va_alltalk_speaklist = CreateConVar("va_alltalk_speaklist", "1", "Enable speaklist when sv_alltalk on? [1-Enable/0-Disable]", 0, true, 0.0, true, 1.0);
	va_print_speaklist = CreateConVar("va_print_speaklist", "0", "How to show who is speaking? [0-Center/1-Hint]", 0, true, 0.0, true, 1.0);

	GetCvars();
	va_sv_alltalk.AddChangeHook(ConVarChanged_Cvars);
	hSV_VoiceEnable.AddChangeHook(ConVarChanged_Cvars);
	va_spectator_speaklist.AddChangeHook(ConVarChanged_Cvars);
	va_alltalk_speaklist.AddChangeHook(ConVarChanged_Cvars);
	va_print_speaklist.AddChangeHook(ConVarChanged_Cvars);
	
	RegConsoleCmd("sm_speaklist", Command_SpeakList, "Player Enable or Disable speaklist");
	
	CreateTimer(UPDATESPEAKING_TIME_INTERVAL, UpdateSpeaking, _, TIMER_REPEAT);
}

//Cvars-------------------------------

void ConVarChanged_Cvars(ConVar hCvar, const char[] sOldVal, const char[] sNewVal)
{
	GetCvars();
}

void GetCvars()
{
	g_iCvarSvAlltalk = va_sv_alltalk.IntValue;
	g_bCvarSVVoiceEnable = hSV_VoiceEnable.BoolValue;

	g_iCvarSpectatorSpeaklist = va_spectator_speaklist.IntValue;
	g_iCvarAlltalkSpeaklist = va_alltalk_speaklist.IntValue;
	g_iCvarPrintSpeaklist = va_print_speaklist.IntValue;
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
				ClientSpeakingList[client] = g_iCvarSpectatorSpeaklist;
		}
		else
		{
			ClientSpeakingList[client] = g_iCvarSpectatorSpeaklist;
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
		|| g_bCvarSVVoiceEnable == false)
	{
		return;
	}

	ClientSpeakingTime[client] = true;
}

Action UpdateSpeaking(Handle timer)
{
	int iCount = 0;
	SpeakingPlayers[0] = '\0';
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (ClientSpeakingTime[i] && IsClientInGame(i) && !IsFakeClient(i))
		{
			Format(SpeakingPlayers, sizeof(SpeakingPlayers), "%s%N\n", SpeakingPlayers, i);
			iCount++;
		}

		ClientSpeakingTime[i] = false;
	}

	/*if(SpeakingPlayers[0][0] != '\0')
		Format(SpeakingPlayers[0], sizeof(SpeakingPlayers[]), "%t:\n%s","Spectator MIC", SpeakingPlayers[0]);
	if(SpeakingPlayers[1][0] != '\0')
		Format(SpeakingPlayers[1], sizeof(SpeakingPlayers[]), "%t:\n%s","Survivor MIC", SpeakingPlayers[1]);
	if(SpeakingPlayers[2][0] != '\0')
		Format(SpeakingPlayers[2], sizeof(SpeakingPlayers[]), "%t:\n%s","Infected MIC", SpeakingPlayers[2]);
	
	
	char ShowSpeakingPlayers[1024];
	Format(ShowSpeakingPlayers, sizeof(ShowSpeakingPlayers), "%s%s%s",SpeakingPlayers[0],SpeakingPlayers[1],SpeakingPlayers[2]);
	*/

	if (iCount > 0)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i)&&!IsFakeClient(i)&&ClientSpeakingList[i]>0)
			{
				if ( (GetClientTeam(i) == 1 && g_iCvarSvAlltalk == 0 && GetClientListeningFlags(i) == VOICE_LISTENALL)//Spectator + alltalk 0 + open listen mode
				|| (g_iCvarAlltalkSpeaklist == 1 && g_iCvarSvAlltalk == 1) )//or Enable speaklist when sv_alltalk on
				{		
					if(g_iCvarPrintSpeaklist==0) PrintCenterText(i, "%T\n%s", "Players Speaking:", i, SpeakingPlayers);
					else PrintHintText(i, "%T\n%s", "Players Speaking:", i, SpeakingPlayers);
				}
			}
		}
	}

	return Plugin_Continue;
}