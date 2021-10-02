#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <multicolors>

#define STEAMID_SIZE  32

ConVar hCvarAllowedRateChanges;
ConVar hCvarMinRate;
ConVar hCvarMinUpd;
ConVar hCvarMinCmd;
ConVar hCvarProhibitFakePing;
ConVar hCvarProhibitedAction;

ArrayList hClientSettingsArray;

int iAllowedRateChanges;
int iMinRate;
int iMinUpd;
int iMinCmd;
int iActionUponExceed;

bool IsLateLoad, bProhibitFakePing, bIsMatchLive;

#if SOURCEMOD_V_MINOR > 9
enum struct NetsettingsStruct
{
	char Client_SteamId[STEAMID_SIZE];
	int Client_Rate;
	int Client_Cmdrate;
	int Client_Updaterate;
	int Client_Changes;
}
#else
enum NetsettingsStruct
{
	String:Client_SteamId[STEAMID_SIZE],
	Client_Rate,
	Client_Cmdrate,
	Client_Updaterate,
	Client_Changes
};
#endif

#define L4DTeam_Spectator 1
#define L4DTeam_Survivor 2
#define L4DTeam_Infected 3

public Plugin myinfo =
{
	name = "RateMonitor",
	author = "Visor, Sir, A1m`, HarryPotter",
	description = "Keep track of players' netsettings",
	version = "2.7",
	url = "https://github.com/A1mDev/L4D2-Competitive-Plugins"
};


public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	IsLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
    LoadTranslations("Roto2-AZ_mod.phrases");
    hCvarAllowedRateChanges = CreateConVar("rm_allowed_rate_changes", "-1", "Allowed number of rate changes during a live round(-1: no limit)", FCVAR_NOTIFY);
    hCvarMinRate = CreateConVar("rm_min_rate", "-1", "Minimum allowed value of rate(-1: none)", FCVAR_NOTIFY);
    hCvarMinUpd = CreateConVar("rm_min_upd", "20", "Minimum allowed value of cl_updaterate(-1: none)");
    hCvarMinCmd = CreateConVar("rm_min_cmd", "-1", "Minimum allowed value of cl_cmdrate(-1: none)", FCVAR_NOTIFY);
    hCvarProhibitFakePing = CreateConVar("rm_no_fake_ping", "0", "Allow or disallow the use of + - . in netsettings, which is commonly used to hide true ping in the scoreboard.", FCVAR_NOTIFY);
    hCvarProhibitedAction = CreateConVar("rm_countermeasure", "2", "Countermeasure against illegal actions - change overlimit/forbidden netsettings(1:chat notify,2:move to spec,3:kick)", FCVAR_NOTIFY, true, 1.0, true, 3.0);

    iAllowedRateChanges = GetConVarInt(hCvarAllowedRateChanges);
    iMinRate = GetConVarInt(hCvarMinRate);
    iMinUpd = GetConVarInt(hCvarMinUpd);
    iMinCmd = GetConVarInt(hCvarMinCmd);
    bProhibitFakePing = GetConVarBool(hCvarProhibitFakePing);
    iActionUponExceed = GetConVarInt(hCvarProhibitedAction);

    hCvarAllowedRateChanges.AddChangeHook(cvarChanged_AllowedRateChanges);
    hCvarMinRate.AddChangeHook(cvarChanged_MinRate);
    hCvarMinUpd.AddChangeHook(cvarChanged_MinUpd);
    hCvarMinCmd.AddChangeHook(cvarChanged_MinCmd);
    hCvarProhibitFakePing.AddChangeHook(cvarChanged_ProhibitFakePing);
    hCvarProhibitedAction.AddChangeHook(cvarChanged_ExceedAction);

    RegConsoleCmd("sm_rates", ListRates, "List netsettings of all players in game");

    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
    HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
    HookEvent("player_left_start_area", Event_RoundGoesLive, EventHookMode_PostNoCopy);
    HookEvent("player_team", OnTeamChange);

#if SOURCEMOD_V_MINOR > 9
    hClientSettingsArray = new ArrayList(sizeof(NetsettingsStruct));
#else
    hClientSettingsArray = new ArrayList(view_as<int>(NetsettingsStruct));
#endif

    if (IsLateLoad) {
        for (int i = 1; i <= MaxClients; i++) {
            if (IsClientInGame(i) && !IsFakeClient(i)) {
                RegisterSettings(i);
            }
        }
    }
}

public void Event_RoundStart(Event hEvent, const char[] name, bool dontBroadcast)
{
	int iSize = hClientSettingsArray.Length;
#if SOURCEMOD_V_MINOR > 9
	NetsettingsStruct player;
	for (int i = 0; i < iSize; i++) {
		hClientSettingsArray.GetArray(i, player, sizeof(NetsettingsStruct));
		player.Client_Changes = 0;
		hClientSettingsArray.SetArray(i, player, sizeof(NetsettingsStruct));
	}
#else
	NetsettingsStruct player[NetsettingsStruct];
	for (int i = 0; i < iSize; i++) {
		hClientSettingsArray.GetArray(i, player[0], view_as<int>(NetsettingsStruct));
		player[Client_Changes] = 0;
		hClientSettingsArray.SetArray(i, player[0], view_as<int>(NetsettingsStruct));
	}
#endif
}

public void Event_RoundGoesLive(Event hEvent, const char[] name, bool dontBroadcast)
{
	//This event works great with the plugin readyup.smx (does not conflict)
	//This event works great in different game modes: versus, coop, scavenge and etc
	bIsMatchLive = true;
}

public void Event_RoundEnd(Event hEvent, const char[] name, bool dontBroadcast)
{
	bIsMatchLive = false;
}

public void OnMapEnd()
{
	hClientSettingsArray.Clear();
}

public void OnTeamChange(Event hEvent, const char[] name, bool dontBroadcast)
{
	if (hEvent.GetInt("team") != L4DTeam_Spectator) {
		int userid = hEvent.GetInt("userid");
		int client = GetClientOfUserId(userid);
		if (client > 0 && !IsFakeClient(client)) {
			CreateTimer(0.1, OnTeamChangeDelay, userid, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public Action OnTeamChangeDelay(Handle hTimer, any userid)
{
	int client = GetClientOfUserId(userid);
	if (client > 0) {
		RegisterSettings(client);
	}
}

public void OnClientSettingsChanged(int client) 
{
	if (IsValidEntity(client) && !IsFakeClient(client)) {
		RegisterSettings(client);
	}
}

public Action ListRates(int client, int args)
{
	ReplyToCommand(client, "\x01[RateMonitor] List of player netsettings(\x03cmd\x01/\x04upd\x01/\x05rate\x01):");
	
	int iSize = hClientSettingsArray.Length;

#if SOURCEMOD_V_MINOR > 9
	NetsettingsStruct player;
	for (int i = 0; i < iSize; i++) {
		hClientSettingsArray.GetArray(i, player, sizeof(NetsettingsStruct));

		int iClient = GetClientBySteamId(player.Client_SteamId);
		if (iClient > 0 && GetClientTeam(client) > L4DTeam_Spectator) {
			ReplyToCommand(client, "\x03%N\x01 : %d/%d/%d", iClient, player.Client_Cmdrate, player.Client_Updaterate, player.Client_Rate);
		}
	}
#else
	NetsettingsStruct player[NetsettingsStruct];
	for (int i = 0; i < iSize; i++) {
		hClientSettingsArray.GetArray(i, player[0], view_as<int>(NetsettingsStruct));

		int iClient = GetClientBySteamId(player[Client_SteamId]);
		if (iClient > 0 && GetClientTeam(iClient) > L4DTeam_Spectator) {
			ReplyToCommand(client, "\x03%N\x01 : %d/%d/%d", iClient, player[Client_Cmdrate], player[Client_Updaterate], player[Client_Rate]);
		}
	}
#endif

	return Plugin_Handled;
}

void RegisterSettings(int client)
{
    if (GetClientTeam(client) < L4DTeam_Survivor) {
        return;
    }

    char 
        sCmdRate[32],
        sUpdateRate[32],
        sRate[32],
        sSteamId[STEAMID_SIZE],
        sCounter[32] = "";

    GetClientAuthId(client, AuthId_Steam2, sSteamId, STEAMID_SIZE);

    int iIndex = hClientSettingsArray.FindString(sSteamId);

    // rate
    int iRate = GetClientDataRate(client);
    // cl_cmdrate
    GetClientInfo(client, "cl_cmdrate", sCmdRate, sizeof(sCmdRate));
    int iCmdRate = StringToInt(sCmdRate);
    // cl_updaterate
    GetClientInfo(client, "cl_updaterate", sUpdateRate, sizeof(sUpdateRate));
    int iUpdateRate = StringToInt(sUpdateRate);

    // Punish for fake ping or other unallowed symbols in rate settings
    if (bProhibitFakePing) {
        bool bIsCmdRateClean, bIsUpdateRateClean;
        
        bIsCmdRateClean = IsNatural(sCmdRate);
        bIsUpdateRateClean = IsNatural(sUpdateRate);

        if (!bIsCmdRateClean || !bIsUpdateRateClean) {
            sCounter = "[bad cmd/upd]";
            Format(sCmdRate, sizeof(sCmdRate), "%s", sCmdRate);
            Format(sUpdateRate, sizeof(sUpdateRate), "%s", sUpdateRate);
            Format(sRate, sizeof(sRate), "%d", iRate);
            
            PunishPlayer(client, sCmdRate, sUpdateRate, sRate, sCounter, iIndex);
            return;
        }
    }

        // Punish for low rate settings(if we're good on previous check)
    if ((iCmdRate < iMinCmd && iMinCmd > -1) || (iRate < iMinRate && iMinRate > -1) || (iUpdateRate < iMinUpd && iMinUpd > -1)) {
        sCounter = "[low cmd/update/rate]";
        Format(sCmdRate, sizeof(sCmdRate), "%s%d%s", iCmdRate < iMinCmd ? ">" : "", iCmdRate, iCmdRate < iMinCmd ? "<" : "");
        Format(sUpdateRate, sizeof(sCmdRate), "%s%d%s", iUpdateRate < iMinUpd ? ">" : "", iUpdateRate, iUpdateRate < iMinUpd ? "<" : "");
        Format(sRate, sizeof(sRate), "%s%d%s", iRate < iMinRate ? ">" : "", iRate, iRate < iMinRate ? "<" : "");
        
        PunishPlayer(client, sCmdRate, sUpdateRate, sRate, sCounter, iIndex);
        return;
    }

#if SOURCEMOD_V_MINOR > 9
    NetsettingsStruct player;
    if (iIndex > -1) {
        hClientSettingsArray.GetArray(iIndex, player, sizeof(NetsettingsStruct));
        
        if (iRate == player.Client_Rate && iCmdRate == player.Client_Cmdrate && iUpdateRate == player.Client_Updaterate) {
            return; // No change
        }
        
        if (bIsMatchLive && iAllowedRateChanges > -1) {
            player.Client_Changes += 1;
            Format(sCounter, sizeof(sCounter), "[%d/%d]", player.Client_Changes, iAllowedRateChanges);
            
            // If not punished for bad rate settings yet, punish for overlimit rate change(if any)
            if (player.Client_Changes > iAllowedRateChanges) {
                Format(sCmdRate, sizeof(sCmdRate), "%s%d", iCmdRate != player.Client_Cmdrate ? "*" : "", iCmdRate);
                Format(sUpdateRate, sizeof(sUpdateRate), "%s%d\x01", iUpdateRate != player.Client_Updaterate ? "*" : "", iUpdateRate);
                Format(sRate, sizeof(sRate), "%s%d\x01", iRate != player.Client_Rate ? "*" : "", iRate);
            
                PunishPlayer(client, sCmdRate, sUpdateRate, sRate, sCounter, iIndex);
                return;
            }
        }
        
        CPrintToChat(client,"%T","ratemonitor1",client, 
                player.Client_Cmdrate, player.Client_Updaterate, player.Client_Rate, 
                iCmdRate, iUpdateRate, iRate, sCounter);
        
        player.Client_Cmdrate = iCmdRate;
        player.Client_Updaterate = iUpdateRate;
        player.Client_Rate = iRate;
        
        hClientSettingsArray.SetArray(iIndex, player, sizeof(NetsettingsStruct));
    } else {
        strcopy(player.Client_SteamId, STEAMID_SIZE, sSteamId);
        player.Client_Cmdrate = iCmdRate;
        player.Client_Updaterate = iUpdateRate;
        player.Client_Rate = iRate;
        player.Client_Changes = 0;
        
        hClientSettingsArray.PushArray(player, sizeof(NetsettingsStruct));
        CPrintToChat(client,"%T","ratemonitor2",client,player.Client_Cmdrate, player.Client_Updaterate, player.Client_Rate);
    }
#else
    NetsettingsStruct player[NetsettingsStruct];
    if (iIndex > -1) {
        hClientSettingsArray.GetArray(iIndex, player[0], view_as<int>(NetsettingsStruct));
        
        if (iRate == player[Client_Rate] && iCmdRate == player[Client_Cmdrate] && iUpdateRate == player[Client_Updaterate]) {
            return; // No change
        }
        
        if (bIsMatchLive && iAllowedRateChanges > -1) {
            player[Client_Changes] += 1;
            Format(sCounter, sizeof(sCounter), "[%d/%d]", player[Client_Changes], iAllowedRateChanges);
            
            // If not punished for bad rate settings yet, punish for overlimit rate change(if any)
            if (player[Client_Changes] > iAllowedRateChanges) {
                Format(sCmdRate, sizeof(sCmdRate), "%s%d", iCmdRate != player[Client_Cmdrate] ? "*" : "", iCmdRate);
                Format(sUpdateRate, sizeof(sUpdateRate), "%s%d\x01", iUpdateRate != player[Client_Updaterate] ? "*" : "", iUpdateRate);
                Format(sRate, sizeof(sRate), "%s%d\x01", iRate != player[Client_Rate] ? "*" : "", iRate);
            
                PunishPlayer(client, sCmdRate, sUpdateRate, sRate, sCounter, iIndex);
                return;
            }
        }
        
        CPrintToChat(client,"%T","ratemonitor1",client, 
                        player[Client_Cmdrate], player[Client_Updaterate], player[Client_Rate], 
                        iCmdRate, iUpdateRate, iRate, sCounter);
        
        player[Client_Cmdrate] = iCmdRate;
        player[Client_Updaterate] = iUpdateRate;
        player[Client_Rate] = iRate;
        
        hClientSettingsArray.SetArray(iIndex, player[0], view_as<int>(NetsettingsStruct));
    } else {
        strcopy(player[Client_SteamId], STEAMID_SIZE, sSteamId);
        player[Client_Cmdrate] = iCmdRate;
        player[Client_Updaterate] = iUpdateRate;
        player[Client_Rate] = iRate;
        player[Client_Changes] = 0;
        
        hClientSettingsArray.PushArray(player[0], view_as<int>(NetsettingsStruct));
        CPrintToChat(client,"%T","ratemonitor2",client,player[Client_Cmdrate], player[Client_Updaterate], player[Client_Rate]);
    }
#endif
}

void PunishPlayer(int client, const char[] sCmdRate, const char[] sUpdateRate, const char[] sRate, const char[] sCounter, int iIndex)
{
    new bool:bInitialRegister = iIndex > -1 ? false : true;

    decl String:clientName[128];
    GetClientName(client,clientName,128);
    decl String:Info[100];
    switch (iActionUponExceed)
    {
        case 1:	// Just notify all players(zero punishment)
        {
            if (bInitialRegister) {
                CPrintToChatAll("%t: %s/%s/%s%s","ratemonitor3",
                                clientName, 
                                sCmdRate, sUpdateRate, sRate, 
                                sCounter);
            }
            else {
                CPrintToChatAll("%t: %s/%s/%s%s", "ratemonitor4",
                                clientName, 
                                sCmdRate, sUpdateRate, sRate, 
                                sCounter);
            }
        }
        case 2:	// Move to spec
        {
            ChangeClientTeam(client, L4DTeam_Spectator);
            
            if (bInitialRegister) {
                CPrintToChatAll("%t: %s/%s/%s%s","ratemonitor5", 
                            clientName, 
                            sCmdRate, sUpdateRate, sRate, 
                            sCounter);
                Format(Info, sizeof(Info), "%T","ratemonitor7",client);			
                CPrintToChat(client, "%T","ratemonitor6",client, iMinCmd, iMinRate, bProhibitFakePing ? Info : "");
            } else {
                #if SOURCEMOD_V_MINOR > 9
                    NetsettingsStruct player;
                    hClientSettingsArray.GetArray(iIndex, player, sizeof(NetsettingsStruct));
        
                    CPrintToChatAll("%t: %s/%s/%s%s","ratemonitor8", 
                            clientName, sCmdRate, sUpdateRate, sRate, sCounter);
                    CPrintToChat(client, "%T","ratemonitor9",client, player.Client_Cmdrate, player.Client_Updaterate, player.Client_Rate);
                #else
                    NetsettingsStruct player[NetsettingsStruct];
                    hClientSettingsArray.GetArray(iIndex, player[0], view_as<int>(NetsettingsStruct));
        
                    CPrintToChatAll("%t: %s/%s/%s%s","ratemonitor8", 
                            clientName, sCmdRate, sUpdateRate, sRate, sCounter);
                    CPrintToChat(client, "%T","ratemonitor9",client, player[Client_Cmdrate], player[Client_Updaterate], player[Client_Rate]);
                #endif
            }
        }
        case 3:	// Kick
        {
            
            if (bInitialRegister) {
                Format(Info, sizeof(Info), " %T","ratemonitor7",client);
                KickClient(client, "%T","ratemonitor6",client, iMinCmd, iMinRate, bProhibitFakePing ? Info : "");
                CPrintToChatAll("%t: %s/%s/%s%s","ratemonitor10", 
                            clientName, 
                            sCmdRate, sUpdateRate, sRate, 
                            sCounter);
            }
            else {
                #if SOURCEMOD_V_MINOR > 9
                    NetsettingsStruct player;
                    hClientSettingsArray.GetArray(iIndex, player, sizeof(NetsettingsStruct));

                    KickClient(client, "%T","ratemonitor9",client, player.Client_Cmdrate, player.Client_Updaterate, player.Client_Rate);
                    CPrintToChatAll("%t: %s/%s/%s%s","ratemonitor11", clientName, sCmdRate, sUpdateRate, sRate, sCounter);
                #else
                    NetsettingsStruct player[NetsettingsStruct];
                    hClientSettingsArray.GetArray(iIndex, player[0], view_as<int>(NetsettingsStruct));

                    KickClient(client, "%T","ratemonitor9",client, player[Client_Cmdrate], player[Client_Updaterate], player[Client_Rate]);
                    CPrintToChatAll("%t: %s/%s/%s%s","ratemonitor11", clientName,sCmdRate, sUpdateRate, sRate, sCounter);
                #endif
            }
        }
    }
    return;
}

int GetClientBySteamId(const char[] steamID)
{
	char tempSteamID[STEAMID_SIZE];

	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i)) {
			GetClientAuthId(i, AuthId_Steam2, tempSteamID, sizeof(tempSteamID));

			if (strcmp(steamID, tempSteamID) == 0) {
				return i;
			}
		}
	}

	return -1;
}

bool IsNatural(const char[] str)
{
	int x = 0;
	while (str[x] != '\0') 
	{
		if (!IsCharNumeric(str[x])) {
			return false;
		}
	
		x++;
	}

	return true;
}

public void cvarChanged_AllowedRateChanges(ConVar convar, const char[] oldValue, const char[] newValue)
{
	iAllowedRateChanges = hCvarAllowedRateChanges.IntValue;
}

public void cvarChanged_MinRate(ConVar convar, const char[] oldValue, const char[] newValue)
{
	iMinRate = hCvarMinRate.IntValue;
}

public void cvarChanged_MinUpd(ConVar convar, const char[] oldValue, const char[] newValue)
{
	iMinUpd = GetConVarInt(hCvarMinUpd);
}

public void cvarChanged_MinCmd(ConVar convar, const char[] oldValue, const char[] newValue)
{
	iMinCmd = hCvarMinCmd.IntValue;
}

public void cvarChanged_ProhibitFakePing(ConVar convar, const char[] oldValue, const char[] newValue)
{
	bProhibitFakePing = hCvarProhibitFakePing.BoolValue;
}

public void cvarChanged_ExceedAction(ConVar convar, const char[] oldValue, const char[] newValue)
{
	iActionUponExceed = hCvarProhibitedAction.IntValue;
}