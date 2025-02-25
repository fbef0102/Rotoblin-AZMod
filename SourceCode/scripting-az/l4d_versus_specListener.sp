#include <sourcemod>
#include <sdktools>
#include <multicolors>
#include <basecomm>

#define TEAM_SPEC 1
#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3

static bool:bListionActive[MAXPLAYERS + 1];
native Is_Ready_Plugin_On();
#define PLUGIN_VERSION "3.3"
ConVar hspecListener_enable, hspecListener_access;
char g_sCommandAccesslvl[16];
bool specListener_enable;

public Plugin:myinfo = 
{
	name = "SpecLister",
	author = "waertf & bear modded by bman, l4d1 versus port by harry",
	description = "Allows spectator listen others team voice and see others team chat for l4d",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=95474"
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	CreateNative("IsClientListenMode", Native_IsClientListenMode);
	CreateNative("OpenSpectatorsListenMode", Native_OpenSpectatorsListenMode);
	return APLRes_Success;
}

public Native_IsClientListenMode(Handle:plugin, numParams)
{
   new num1 = GetNativeCell(1);
   return bListionActive[num1];
}


public Native_OpenSpectatorsListenMode(Handle:plugin, numParams) {
  
	if(!specListener_enable) return;
	
	decl String:Info[50];
	for (new client = 1; client <= MaxClients; client++)
	{
		if (IsClientConnected(client) && IsClientInGame(client)&& !IsFakeClient(client) && GetClientTeam(client) == TEAM_SPEC)
		{
			if(bListionActive[client])
			{
				SetClientListeningFlags(client, VOICE_LISTENALL);
			}
			else
			{
				SetClientListeningFlags(client, VOICE_NORMAL);
			}
			Format(Info, sizeof(Info), "%T", (bListionActive[client] ? "Off" : "On"),client);
			CPrintToChat(client,"%T","Listen Mode1",client, Info,"!hear");
		}
	}	
}

 public OnPluginStart()
{
	LoadTranslations("Roto2-AZ_mod.phrases");
	HookEvent("player_team",Event_PlayerChangeTeam);
	HookEvent("player_left_start_area", LeftStartAreaEvent, EventHookMode_PostNoCopy);
	RegConsoleCmd("sm_hear", Command_hear);
	
	hspecListener_enable = CreateConVar("specListener_enable", "1", "If 1, enable Hear Feature for all spectators [0-Disable]", 0, true, 0.0, true, 1.0);
	hspecListener_access = CreateConVar("specListener_command_access_flag", "", "Players with these flags have access to use sm_hear command to enable or disable hear feature. (Empty = Everyone, -1: Nobody)", FCVAR_NOTIFY);
	
	specListener_enable = GetConVarBool(hspecListener_enable);
	HookConVarChange(hspecListener_enable, ConVarChange_hspecListener_enable);

	GetCvars();
	hspecListener_access.AddChangeHook(ConVarChanged_Cvars);
	
	//Spectators see Team_Chat and Team MIC
	RegConsoleCmd("say_team", Command_SayTeam);
	HookEvent("player_disconnect", 		Event_PlayerDisconnect);
	
	if(specListener_enable)
		for (new i = 1; i <= MaxClients; i++) 
			bListionActive[i] = true;
	else
		for (new i = 1; i <= MaxClients; i++) 
			bListionActive[i] = false;
}

public ConVarChange_hspecListener_enable(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if(oldValue[0] == newValue[0])
	{
		return;
	}
	specListener_enable = GetConVarBool(hspecListener_enable);
	
	if(!specListener_enable)
	{
		for (new client = 1; client <= MaxClients; client++)
		{
			bListionActive[client] = false;
			if(IsClientConnected(client) && IsClientInGame(client)&& !IsFakeClient(client))
				SetClientListeningFlags(client, VOICE_NORMAL);
		}
	}
	else
		for (new i = 1; i <= MaxClients; i++) 
			bListionActive[i] = true;
}

public void ConVarChanged_Cvars(Handle convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	hspecListener_access.GetString(g_sCommandAccesslvl,sizeof(g_sCommandAccesslvl));
}

public LeftStartAreaEvent(Handle:event, String:name[], bool:dontBroadcast)
{
	if(!Is_Ready_Plugin_On()&&specListener_enable)
	{
		decl String:Info[50];
		for (new client = 1; client <= MaxClients; client++)
			if (IsClientConnected(client) && IsClientInGame(client)&& !IsFakeClient(client) && GetClientTeam(client) == TEAM_SPEC)
			{
				if(bListionActive[client])
				{
					SetClientListeningFlags(client, VOICE_LISTENALL);
				}
				else
				{
					SetClientListeningFlags(client, VOICE_NORMAL);
				}
				Format(Info, sizeof(Info), "%T", (bListionActive[client] ? "Off" : "On"),client);
				CPrintToChat(client,"%T","Listen Mode1",client, Info,"!hear");
			}
	}
}

public Action:Command_hear(client,args)
{
	if (client == 0)
	{
		PrintToServer("[TS] %t","command cannot be used by server.");
		return Plugin_Handled;
	}
	
	if(GetClientTeam(client)!=TEAM_SPEC || !specListener_enable)
		return Plugin_Handled;

	if(HasAccess(client, g_sCommandAccesslvl) == false)
	{
		PrintHintText(client, "[TS] You don't have access");
		return Plugin_Handled;
	}
	
	bListionActive[client] = !bListionActive[client];
	decl String:Info[50];
	Format(Info, sizeof(Info), "%T", (bListionActive[client] ? "On" : "Off"),client);
	CPrintToChat(client,"%T","Listen Mode2",client, Info);	
	
	if(bListionActive[client])
	{
		SetClientListeningFlags(client, VOICE_LISTENALL);
		CPrintToChat(client,"%T","Listen Mode3",client );
	}
	else
	{
		SetClientListeningFlags(client, VOICE_NORMAL);
	}
 
	return Plugin_Continue;

}

public Action:Command_SayTeam(client, args)
{
	if (client == 0 || !IsClientInGame(client) || BaseComm_IsClientGagged(client))
		return Plugin_Continue;
		
	new String:buffermsg[256];
	new String:text[192];
	GetCmdArgString(text, sizeof(text));
	new senderteam = GetClientTeam(client);
	
	if(FindCharInString(text, '@') == 0)	//Check for admin messages
		return Plugin_Continue;
	
	new startidx = trim_quotes(text);  //Not sure why this function is needed.(bman)
	
	new String:name[32];
	GetClientName(client,name,31);
	
	new String:senderTeamName[10];
	switch (senderteam)
	{
		case 3:
			senderTeamName = "INFECTED"
		case 2:
			senderTeamName = "SURVIVORS"
		case 1:
			senderTeamName = "SPEC"
	}
	
	//Is not console, Sender is not on Spectators, and there are players on the spectator team
	if (client > 0 && senderteam != TEAM_SPEC && GetTeamClientCount(TEAM_SPEC) > 0)
	{
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && GetClientTeam(i) == TEAM_SPEC && bListionActive[i])
			{
				switch (senderteam)	//Format the color different depending on team
				{
					case 3:
						Format(buffermsg, 256, "\x01(%s) \x04%s\x05: %s", senderTeamName, name, text[startidx]);
					case 2:
						Format(buffermsg, 256, "\x01(%s) \x03%s\x05: %s", senderTeamName, name, text[startidx]);
				}
				SayText2(i, client, buffermsg);	//Send the message to spectators
			}
		}
	}
	return Plugin_Continue;
}

stock SayText2(client_index, author_index, const String:message[] ) 
{
    new Handle:buffer = StartMessageOne("SayText2", client_index)
    if (buffer != INVALID_HANDLE) 
	{
        BfWriteByte(buffer, author_index)
        BfWriteByte(buffer, true)
        BfWriteString(buffer, message)
        EndMessage()
    }
} 

public trim_quotes(String:text[])
{
	new startidx = 0
	if (text[0] == '"')
	{
		startidx = 1
		/* Strip the ending quote, if there is one */
		new len = strlen(text);
		if (text[len-1] == '"')
		{
			text[len-1] = '\0'
		}
	}
	
	return startidx
}

public Event_PlayerChangeTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	new userID = GetClientOfUserId(GetEventInt(event, "userid"));
	if(userID==0 || !specListener_enable)
		return ;

	if(!IsFakeClient(userID)&&IsClientConnected(userID)&&IsClientInGame(userID))
		CreateTimer(1.0,PlayerChangeTeamCheck,userID);
}
public Action:PlayerChangeTeamCheck(Handle:timer,any:client)
{
	if(IsClientConnected(client) && IsClientInGame(client)&& !IsFakeClient(client))
		if(GetClientTeam(client)==TEAM_SPEC)
		{
			if(bListionActive[client])
			{
				SetClientListeningFlags(client, VOICE_LISTENALL);
			}
			else
			{
				SetClientListeningFlags(client, VOICE_NORMAL);
			}
		}
		else
		{
			SetClientListeningFlags(client, VOICE_NORMAL);
		}
}

public IsValidClient (client)
{
    if (client == 0)
        return false;
    
    if (!IsClientConnected(client))
        return false;
    
    if (IsFakeClient(client))
        return false;
    
    if (!IsClientInGame(client))
        return false;	
		
    return true;
}  

public bool HasAccess(int client, char[] g_sAcclvl)
{
	// no permissions set
	if (strlen(g_sAcclvl) == 0)
		return true;

	else if (StrEqual(g_sAcclvl, "-1"))
		return false;

	// check permissions
	if ( GetUserFlagBits(client) & ReadFlagString(g_sAcclvl) )
	{
		return true;
	}

	return false;
}

void Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(client && !IsFakeClient(client))
	{
		bListionActive[client] = specListener_enable;
	}
}