#pragma semicolon 1
#pragma newdecls required //強制1.7以後的新語法
#include <socket>

#define HOST_PATH "api.steampowered.com"
#define MAX_STEAMID_LENGTH 21
#define MAX_COMMUNITYID_LENGTH 18 

ConVar g_hCvar_AppId = null ;
ConVar g_hCvar_APIKey = null ;
ConVar g_hCvar_BanMessage = null ;
ConVar g_hCvar_Whitelist = null ;
ConVar g_hCvar_IgnoreAdmins = null ;
ConVar g_hCvar_BanTime = null;

// The maximum returned length of 174 occurs when an unauthorized key is provided
// Header length really shouldn't be 900 characters long. But just in case...
char g_sAPIBuffer[MAXPLAYERS + 1][1024];
Handle g_hAPISocket[MAXPLAYERS + 1];

char g_sWhitelist[PLATFORM_MAX_PATH];
Handle g_hWhitelistTrie = null ;
bool g_bParsed = false;

public Plugin myinfo =
{
    name = "Family Share Manager",
    author = "Sidezz (+bonbon, 11530) & HarryPotter",
    description = "Whitelist or ban family shared accounts",
    version = "1.4.3",
    url = "www.coldcommunity.com"
};

public void OnPluginStart()
{

    g_bParsed = false;
    g_hWhitelistTrie = CreateTrie();
    g_hCvar_AppId = CreateConVar("sm_familyshare_appid", "550", "Application ID of current game. HL2:DM (320), CS:S (240), CS:GO (730), TF2 (440), L4D (500), L4D2, (550)", FCVAR_NOTIFY);
    g_hCvar_APIKey = CreateConVar("sm_familyshare_apikey", "XXXXXXXXXXXXXXXXXXXX", "Steam developer web API key", FCVAR_PROTECTED);
    g_hCvar_BanMessage = CreateConVar("sm_familyshare_banmessage", "Family sharing is disabled on this server.", "Message to display in sourcebans/on ban", FCVAR_NOTIFY);
    g_hCvar_IgnoreAdmins = CreateConVar("sm_familyshare_ignoreadmins", "1", "Check and unblock admins?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_hCvar_Whitelist = CreateConVar("sm_familyshare_whitelist", "familyshare_whitelist.ini", "File to use for whitelist (addons/sourcemod/configs/file)");
    g_hCvar_BanTime = CreateConVar("sm_familyshare_ban_time", "10", "Ban duration (Mins) (0=Permanent)", FCVAR_NOTIFY, true, 0.0);

    char file[PLATFORM_MAX_PATH], filePath[PLATFORM_MAX_PATH];
    g_hCvar_Whitelist.GetString(file, sizeof(file));
    BuildPath(Path_SM, g_sWhitelist, sizeof(g_sWhitelist), "configs/%s", file);
    LogMessage("Built Filepath to: %s", g_sWhitelist);

    BuildPath(Path_SM, filePath, sizeof(filePath), "configs");
    CreateDirectory(filePath, 511);

    //Autoconfig for plugin
    AutoExecConfig(true, "familyshare_manager");

    parseList();

    RegAdminCmd("sm_reloadlist", command_reloadWhiteList, ADMFLAG_ROOT, "Reload the whitelist");
    RegAdminCmd("sm_addtolist", command_addToList, ADMFLAG_ROOT, "Add a player to the whitelist");
    RegAdminCmd("sm_removefromlist", command_removeFromList, ADMFLAG_ROOT, "Remove a player from the whitelist");
    RegAdminCmd("sm_displaylist", command_displayList, ADMFLAG_ROOT, "View current whitelist");
}

public Action command_removeFromList(int client, int args)
{
    Handle hFile = OpenFile(g_sWhitelist, "a+");

    if(hFile == null )
    {
        LogError("[Family Share Manager] Critical Error: hFile is Invalid. --> command_removeFromList");
        PrintToChat(client, "[Family Share Manager] Plugin has encountered a critial error with the list file.");
        delete hFile;
        return Plugin_Handled;
    }

    if(args == 0)
    {
        PrintToChat(client, "[Family Share Manager] Invalid Syntax: sm_removefromlist <steam id>");
        return Plugin_Handled;
    }

    char steamid[32], playerSteam[32];
    GetCmdArgString(playerSteam, sizeof(playerSteam));

    StripQuotes(playerSteam);
    TrimString(playerSteam);
  
    bool found = false;
    Handle fileArray = CreateArray(32);

    while(!IsEndOfFile(hFile) && ReadFileLine(hFile, steamid, sizeof(steamid)))
    {
        if(strlen(steamid) < 1 || IsCharSpace(steamid[0])) continue;

        ReplaceString(steamid, sizeof(steamid), "\n", "", false);

        PrintToChat(client, "%s - %s", steamid, playerSteam);
        //Not found, add to next file.
        if(!StrEqual(steamid, playerSteam, false))
        {
            PushArrayString(fileArray, steamid);
        }

        //Found, remove from file.
        else
        {
            found = true;
        }
    }

    delete hFile;

    //Delete and rewrite list if found..
    if(found)
    {
        DeleteFile(g_sWhitelist); //I hate this, scares the shit out of me.
        Handle newFile = OpenFile(g_sWhitelist, "a+");

        if(newFile == null )
        {
            LogError("[Family Share Manager] Critical Error: newFile is Invalid. --> command_removeFromList");
            PrintToChat(client, "[Family Share Manager] Plugin has encountered a critial error with the list file.");
            return Plugin_Handled;
        }

        PrintToChat(client, "[Family Share Manager] Found Steam ID: %s, removing from list...", playerSteam);
        
        LogMessage("Begin rewrite of list..");

        for(int i = 0; i < GetArraySize(fileArray); i++)
        {
            char writeLine[32];
            GetArrayString(fileArray, i, writeLine, sizeof(writeLine));
            WriteFileLine(newFile, writeLine);
            LogMessage("Wrote %s to list.", writeLine);
        }

        delete newFile;
        delete fileArray;
        parseList();
        return Plugin_Handled;
    }
    else PrintToChat(client, "[Family Share Manager] Steam ID: %s not found, no action taken.", playerSteam);
    return Plugin_Handled;
}

public Action command_addToList(int client, int args)
{
    Handle hFile = OpenFile(g_sWhitelist, "a+");
    
    //Argument Count:
    switch(args)
    {
        //Create Player List:
        case 0:
        {
            Handle playersMenu = CreateMenu(playerMenuHandle);
            for(int i = 1; i <= MaxClients; i++)
            {
                if(IsClientAuthorized(i) && i != client)
                {
                    SetMenuTitle(playersMenu, "Viewing all players...");

                    char formatItem[2][32];
                    Format(formatItem[0], sizeof(formatItem[]), "%i", GetClientUserId(i));
                    Format(formatItem[1], sizeof(formatItem[]), "%N", i);

                    //Adds menu item per player --> Client User ID, Display as Username.
                    AddMenuItem(playersMenu, formatItem[0], formatItem[1]);
                }
            }

            SetMenuExitButton(playersMenu, true);
            SetMenuPagination(playersMenu, 7);
            DisplayMenu(playersMenu, client, MENU_TIME_FOREVER);

            PrintToChat(client, "[Family Share Manager] Displaying players menu...");

            delete hFile;
            return Plugin_Handled;
        }

        //Directly write Steam ID:
        default:
        {
            char steamid[32];
            GetCmdArgString(steamid, sizeof(steamid));

            StripQuotes(steamid);
            TrimString(steamid);

            if(StrContains(steamid, "STEAM_", false) == -1)
            {
                PrintToChat(client, "[Family Share Manager] Invalid Input - Not a Steam 2 ID. (STEAM_0:X:XXXX)");
                delete hFile;
                return Plugin_Handled;
            }

            if(hFile == null )
            {
                LogError("[Family Share Manager] Critical Error: hFile is Invalid. --> command_addToList");
                PrintToChat(client, "[Family Share Manager] Plugin has encountered a critial error with the list file.");
                delete hFile;
                return Plugin_Handled;
            }

            WriteFileLine(hFile, steamid);
            PrintToChat(client, "[Family Share Manager] Successfully added %s to the list.", steamid);
            delete hFile;
            parseList();
            return Plugin_Handled;
        }
    }
    return Plugin_Handled;
}

public int playerMenuHandle(Handle playerMenu, MenuAction action, int client, int menuItem)
{
    if(action == MenuAction_Select) 
    {   
        //Should be our Client's User ID.
        char menuItems[32]; 
        GetMenuItem(playerMenu, menuItem, menuItems, sizeof(menuItems));

        int target = GetClientOfUserId(StringToInt(menuItems));
        
        //Invalid UserID/Client Index:
        if(target == 0)
        {
            LogError("[Family Share Manager] Critical Error: Invalid Client of User Id --> playerMenuHandle");
            delete playerMenu;
            return;
        }

        char steamid[32];
        GetClientAuthId(target, AuthId_Steam2, steamid, sizeof(steamid));

        StripQuotes(steamid);
        TrimString(steamid);

        if(StrContains(steamid, "STEAM_", false) == -1)
        {
            PrintToChat(client, "[Family Share Manager] Invalid Input - Not a Steam 2 ID. (STEAM_0:X:XXXX)");
            return;
        }

        Handle hFile = OpenFile(g_sWhitelist, "a+");
        if(hFile == null )
        {
            LogError("[Family Share Manager] Critical Error: hFile is Invalid. --> playerMenuHandle");
            PrintToChat(client, "[Family Share Manager] Plugin has encountered a critial error with the list file.");
            delete hFile;
            return;
        }

        WriteFileLine(hFile, steamid);
        PrintToChat(client, "[Family Share Manager] Successfully added %s (%N) to the list.", steamid, target);
        delete hFile;
        parseList();
        return;
    }

    else if(action == MenuAction_End)
    {
        delete playerMenu;
    }
}

public Action command_displayList(int client, int args)
{
    char auth[32];
    Handle hFile = OpenFile(g_sWhitelist, "a+");

    while(!IsEndOfFile(hFile) && ReadFileLine(hFile, auth, sizeof(auth)))
    {
        TrimString(auth);
        StripQuotes(auth);

        if(strlen(auth) < 1) continue;
        ReplaceString(auth, sizeof(auth), "\n", "", false);

        if(StrContains(auth, "STEAM_", false) != -1)
        {
            if(!client) return Plugin_Handled;
            PrintToChat(client, "%s", auth); 
        }
    }

    delete hFile;
    return Plugin_Handled;
}

public Action command_reloadWhiteList(int client, int args)
{
    PrintToChat(client, "[Family Share Manager] Rebuilding whitelist...");
    parseList(true, client);
    return Plugin_Handled;
}

void parseList(bool rebuild = false, int client = 0)
{
    char auth[32];
    Handle hFile = OpenFile(g_sWhitelist, "a+");
    LogMessage("Begin parseList()");

    while(!IsEndOfFile(hFile) && ReadFileLine(hFile, auth, sizeof(auth)))
    {
        TrimString(auth);
        StripQuotes(auth);

        if(strlen(auth) < 1) continue;

        if(StrContains(auth, "STEAM_", false) != -1)
        {
            SetTrieString(g_hWhitelistTrie, auth, auth);
            LogMessage("Added %s to whitelist", auth);
        }
    }

    LogMessage("End parseList()");
    if(rebuild && client) PrintToChat(client, "[Family Share Manager] Rebuild complete!");
    g_bParsed = true;
    delete hFile;
}

public void OnClientPostAdminCheck(int client)
{
    bool whiteListed = false;
    if(g_bParsed)
    {
        char auth[2][64];
        GetClientAuthId(client, AuthId_Steam2, auth[0], sizeof(auth[]));
        whiteListed = GetTrieString(g_hWhitelistTrie, auth[0], auth[1], sizeof(auth[]));
        if(whiteListed)
        {
            LogMessage("Whitelist found player: %N", client);
            return;
        }
    }

    if(CheckCommandAccess(client, "sm_admin", ADMFLAG_GENERIC) && g_hCvar_IgnoreAdmins.BoolValue)
    {
        return;
    }

    if(!IsFakeClient(client))
        checkFamilySharing(client);
}

public void OnClientDisconnect(int client)
{
    delete g_hAPISocket[client];
}

public void OnSocketConnected(Handle socket, any userid)
{
    int client = GetClientOfUserId(userid);

    if (!client)
    {
        delete socket;
        return;
    }

    char apikey[64];
    char get[256];
    char request[512];
    char steamid[MAX_STEAMID_LENGTH];
    char steamid64[MAX_COMMUNITYID_LENGTH];

    g_hCvar_APIKey.GetString(apikey, sizeof(apikey));
    GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
    GetCommunityIDString(steamid, steamid64, sizeof(steamid64));

    Format(get, sizeof(get),
           "%s/IPlayerService/IsPlayingSharedGame/v0001/?key=%s&steamid=%s&appid_playing=%d&format=json",
           HOST_PATH, apikey, steamid64, g_hCvar_AppId.IntValue);

    Format(request, sizeof(request),
           "GET http://%s HTTP/1.1\r\nHost: %s\r\nConnection: close\r\nAccept-Encoding: *\r\n\r\n",
           get, HOST_PATH);

    SocketSend(socket, request);
}

public void OnSocketReceive(Handle socket, char[] receiveData, int dataSize, any userid)
{
    int client = GetClientOfUserId(userid);

    if (client > 0)
    {
        StrCat(g_sAPIBuffer[client], 1024, receiveData);
    
        if (StrContains(receiveData, "404 Not Found", false) != -1)
        {
            OnSocketError(socket, 404, 404, userid);
        }

        else if (StrContains(receiveData, "Unauthorized", false) != -1)
        {
            OnSocketError(socket, 403, 403, userid);
        }
    }
}

public void OnSocketError(Handle socket, const int errorType, const int errorNum, any userid)
{
    int client = GetClientOfUserId(userid);
    if (client > 0)
    {
        g_hAPISocket[client] = null ;
        LogError("Error checking family sharing for %L -- error %d (%d)", client, errorType, errorNum);
    }

    delete socket;
}

public void OnSocketDisconnected(Handle socket, any userid)
{
    int client = GetClientOfUserId(userid);

    if (client > 0)
    {
        g_hAPISocket[client] = null ;
        ReplaceString(g_sAPIBuffer[client], 1024, " ", "");
        ReplaceString(g_sAPIBuffer[client], 1024, "\t", "");

        int index = StrContains(g_sAPIBuffer[client], "\"lender_steamid\":", false);

        if (index == -1)
        {
            LogError("unexpected error returned in request - %s", g_sAPIBuffer[client]);
        }

        else
        {
            index += strlen("\"lender_steamid\":");
            char banMessage[128];
            g_hCvar_BanMessage.GetString(banMessage, sizeof(banMessage));
            char auth[20];
            GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
            if (g_sAPIBuffer[client][index + 1] != '0' || g_sAPIBuffer[client][index + 2] != '"')
            {
                LogCustom("Banning (%N) [%s] for %d minutes because of family sharing.", client, auth, g_hCvar_BanTime.IntValue);
                ServerCommand("sm_ban #%i %d \"%s\"", userid, g_hCvar_BanTime.IntValue, banMessage);
            }
        }
    }

    delete socket;
}

Action checkFamilySharing(int client)
{
    Handle socket = SocketCreate(SOCKET_TCP, OnSocketError);

    g_hAPISocket[client] = socket;
    g_sAPIBuffer[client][0] = '\0';

    SocketSetArg(socket, GetClientUserId(client));
    SocketConnect(socket, OnSocketConnected, OnSocketReceive, OnSocketDisconnected, HOST_PATH, 80);
}

// Credit to 11530
// https://forums.alliedmods.net/showthread.php?t=183443&highlight=communityid
stock bool GetCommunityIDString(const char[] SteamID, char[] CommunityID, const int CommunityIDSize)
{
    char SteamIDParts[3][11];
    char Identifier[] = "76561197960265728";
    
    if ((CommunityIDSize < 1) || (ExplodeString(SteamID, ":", SteamIDParts, sizeof(SteamIDParts), sizeof(SteamIDParts[])) != 3))
    {
        CommunityID[0] = '\0';
        return false;
    }

    int Current, CarryOver = (SteamIDParts[1][0] == '1');
    for (int i = (CommunityIDSize - 2), j = (strlen(SteamIDParts[2]) - 1), k = (strlen(Identifier) - 1); i >= 0; i--, j--, k--)
    {
        Current = (j >= 0 ? (2 * (SteamIDParts[2][j] - '0')) : 0) + CarryOver + (k >= 0 ? ((Identifier[k] - '0') * 1) : 0);
        CarryOver = Current / 10;
        CommunityID[i] = (Current % 10) + '0';
    }

    CommunityID[CommunityIDSize - 1] = '\0';
    return true;
}  

void LogCustom(const char[] format, any ...)
{
	char buffer[512];
	VFormat(buffer, sizeof(buffer), format, 2);

	char sPath[PLATFORM_MAX_PATH], sTime[32];
	BuildPath(Path_SM, sPath, sizeof(sPath), "logs/familyshare.log");
	File file = OpenFile(sPath, "a+");
	FormatTime(sTime, sizeof(sTime), "%d-%b-%Y - %H:%M:%S");
	file.WriteLine("%s: %s", sTime, buffer);
	FlushFile(file);
	delete file;
}