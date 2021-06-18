/**
 *
 * VAC Status Checker
 * https://forums.alliedmods.net/showthread.php?t=80942
 *
 * Licensed under the GNU General Public License v3.0
 * Source Repo: https://github.com/stevotvr/sourcemod-vacbans
 *
 */

#include <sourcemod>
#include <vacbans>

#undef REQUIRE_EXTENSIONS
#tryinclude <SteamWorks>
#tryinclude <steamtools>
#tryinclude <socket>

#undef REQUIRE_PLUGIN
#tryinclude <updater>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "2.5.0"
#define DATABASE_VERSION 1

#define DEBUG 0

#if defined _updater_included
#define UPDATE_URL "//dev.stevotvr.com/vacbans/updater/updatefile.txt"
#endif

#define API_HOST "api.steampowered.com"

#define ACTION_LOG 1
#define ACTION_KICK 2
#define ACTION_BAN 4
#define ACTION_NOTIFY_ADMINS 8
#define ACTION_NOTIFY_ALL 16

#define STEAMWORKS_AVAILABLE()	(GetFeatureStatus(FeatureType_Native, "SteamWorks_CreateHTTPRequest") == FeatureStatus_Available)
#define STEAMTOOLS_AVAILABLE()	(GetFeatureStatus(FeatureType_Native, "Steam_CreateHTTPRequest") == FeatureStatus_Available)
#define SOCKET_AVAILABLE()		(GetFeatureStatus(FeatureType_Native, "SocketCreate") == FeatureStatus_Available)

public Plugin myinfo =
{
	name = "VAC Status Checker",
	author = "StevoTVR",
	description = "Checks for VAC, game, Steam Community, and trade bans on the accounts of connecting clients",
	version = PLUGIN_VERSION,
	url = "https://github.com/stevotvr/sourcemod-vacbans"
}

Database g_hDatabase = null;

ConVar g_hCVDB = null;
ConVar g_hCVAPIKey = null;
ConVar g_hCVCacheTime = null;
ConVar g_hCVAction = null;
ConVar g_hCVActions = null;
ConVar g_hCVDetectVACBans = null;
ConVar g_hCVVACExpire = null;
ConVar g_hCVVACEpoch = null;
ConVar g_hCVDetectGameBans = null;
ConVar g_hCVDetectCommunityBans = null;
ConVar g_hCVDetectEconBans = null;

/**
 * The name of the database configuration
 */
char g_dbConfig[64];

/**
 * The date before which VAC bans are ignored (YYYYMMDD)
 */
int g_VACEpoch;

/**
 * The status cache for connected clients
 */
int g_clientStatus[MAXPLAYERS + 1][5];

/**
 * The base URL path for the Steam Web API
 */
char g_baseUrl[128];

#if DEBUG
char g_debugLogPath[PLATFORM_MAX_PATH];
#endif

#if defined _SteamWorks_Included
#include "vacbans/steamworks.sp"
#endif

#if defined _steamtools_included
#include "vacbans/steamtools.sp"
#endif

#if defined _socket_included
#include "vacbans/socket.sp"
#endif

/**
 * Forwards
 */
Handle OnDetectedClient;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	MarkNativeAsOptional("Steam_CreateHTTPRequest");
	MarkNativeAsOptional("Steam_SendHTTPRequest");
	MarkNativeAsOptional("Steam_GetHTTPResponseBodyData");
	MarkNativeAsOptional("Steam_ReleaseHTTPRequest");

	MarkNativeAsOptional("SocketCreate");
	MarkNativeAsOptional("SocketSetArg");
	MarkNativeAsOptional("SocketConnect");
	MarkNativeAsOptional("SocketSend");

	OnDetectedClient = CreateGlobalForward("Vacbans_OnDetectedClient", ET_Ignore, Param_Cell, Param_String, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell);

	return APLRes_Success;
}

public void OnPluginStart()
{
#if DEBUG
	BuildPath(Path_SM, g_debugLogPath, sizeof(g_debugLogPath), "logs/vacbans_debug.log");
#endif

	LoadTranslations("vacbans2.phrases");
	char desc[256];

	if (!STEAMWORKS_AVAILABLE() && !STEAMTOOLS_AVAILABLE() && !SOCKET_AVAILABLE())
	{
		SetFailState("%T", "Error_Extension_Required", LANG_SERVER);
	}

	Format(desc, sizeof(desc), "%T", "ConVar_Version", LANG_SERVER);
	CreateConVar("sm_vacbans_version", PLUGIN_VERSION, desc, FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_DONTRECORD);

	Format(desc, sizeof(desc), "%T", "ConVar_DB", LANG_SERVER);
	g_hCVDB = CreateConVar("sm_vacbans_db", "storage-local", desc);

	Format(desc, sizeof(desc), "%T", "ConVar_APIKey", LANG_SERVER);
	g_hCVAPIKey = CreateConVar("sm_vacbans_apikey", "", desc, FCVAR_PROTECTED);

	Format(desc, sizeof(desc), "%T", "ConVar_CacheTime", LANG_SERVER);
	g_hCVCacheTime = CreateConVar("sm_vacbans_cachetime", "1", desc, _, true, 0.0);

	Format(desc, sizeof(desc), "%T", "ConVar_Action", LANG_SERVER);
	g_hCVAction = CreateConVar("sm_vacbans_action", "-1", desc, FCVAR_DONTRECORD, true, -1.0, true, 3.0);

	Format(desc, sizeof(desc), "%T", "ConVar_Actions", LANG_SERVER);
	g_hCVActions = CreateConVar("sm_vacbans_actions", "3", desc, _, true, 0.0, true, 31.0);

	Format(desc, sizeof(desc), "%T", "ConVar_Detect_VAC", LANG_SERVER);
	g_hCVDetectVACBans = CreateConVar("sm_vacbans_detect_vac_bans", "1", desc, _, true, 0.0, true, 1.0);

	Format(desc, sizeof(desc), "%T", "ConVar_VAC_Expire", LANG_SERVER);
	g_hCVVACExpire = CreateConVar("sm_vacbans_vac_expire", "0", desc, _, true, 0.0);

	Format(desc, sizeof(desc), "%T", "ConVar_VAC_Ignore_Before", LANG_SERVER);
	g_hCVVACEpoch = CreateConVar("sm_vacbans_vac_ignore_before", "", desc);

	Format(desc, sizeof(desc), "%T", "ConVar_Detect_Game", LANG_SERVER);
	g_hCVDetectGameBans = CreateConVar("sm_vacbans_detect_game_bans", "0", desc, _, true, 0.0, true, 1.0);

	Format(desc, sizeof(desc), "%T", "ConVar_Detect_Community", LANG_SERVER);
	g_hCVDetectCommunityBans = CreateConVar("sm_vacbans_detect_community_bans", "0", desc, _, true, 0.0, true, 1.0);

	Format(desc, sizeof(desc), "%T", "ConVar_Detect_Econ", LANG_SERVER);
	g_hCVDetectEconBans = CreateConVar("sm_vacbans_detect_econ_bans", "0", desc, _, true, 0.0, true, 2.0);

	AutoExecConfig(true, "vacbans");

	g_hCVDB.AddChangeHook(OnDBConVarChanged);
	g_hCVAPIKey.AddChangeHook(OnConVarChanged);
	g_hCVAction.AddChangeHook(OnConVarChanged);
	g_hCVActions.AddChangeHook(OnConVarChanged);
	g_hCVDetectVACBans.AddChangeHook(OnConVarChanged);
	g_hCVVACExpire.AddChangeHook(OnConVarChanged);
	g_hCVVACEpoch.AddChangeHook(OnConVarChanged);
	g_hCVDetectGameBans.AddChangeHook(OnConVarChanged);
	g_hCVDetectCommunityBans.AddChangeHook(OnConVarChanged);
	g_hCVDetectEconBans.AddChangeHook(OnConVarChanged);

	Format(desc, sizeof(desc), "%T", "Command_Reset", LANG_SERVER);
	RegAdminCmd("sm_vacbans_reset", Command_Reset, ADMFLAG_RCON, desc);

	Format(desc, sizeof(desc), "%T", "Command_Whitelist", LANG_SERVER);
	RegAdminCmd("sm_vacbans_whitelist", Command_Whitelist, ADMFLAG_RCON, desc);

	Format(desc, sizeof(desc), "%T", "Command_List", LANG_SERVER);
	RegAdminCmd("sm_vacbans_list", Command_List, ADMFLAG_KICK, desc);

#if defined _updater_included
	if (LibraryExists("updater"))
	{
		InitUpdater();
	}
#endif
}

#if defined _updater_included
public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "updater"))
	{
		InitUpdater();
	}
	else if (LibraryExists("updater") && (StrEqual(name, "SteamWorks") || StrEqual(name, "SteamTools") || StrEqual(name, "Socket")))
	{
		Updater_RemovePlugin();
		InitUpdater();
	}
}

void InitUpdater()
{
	char url[128];
	if (STEAMWORKS_AVAILABLE() || STEAMTOOLS_AVAILABLE())
	{
		Format(url, sizeof(url), "https:%s", UPDATE_URL);
	}
	else
	{
		Format(url, sizeof(url), "http:%s", UPDATE_URL);
	}

	Updater_AddPlugin(url);
}
#endif

public void OnDBConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	strcopy(g_dbConfig, sizeof(g_dbConfig), newValue);
	Database.Connect(OnDBConnected, newValue);
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (convar == g_hCVAPIKey)
	{
		UpdateBaseUrl();
		return;
	}

	if (convar == g_hCVVACEpoch)
	{
		g_VACEpoch = 0;

		if (g_hCVVACEpoch.BoolValue)
		{
			char dateString[11];
			g_hCVVACEpoch.GetString(dateString, sizeof(dateString));
			char toks[3][5];
			if (ExplodeString(dateString, "-", toks, sizeof(toks), sizeof(toks[])) == 3 && strlen(toks[0]) == 4 && strlen(toks[1]) == 2 && strlen(toks[2]) == 2)
			{
				ImplodeStrings(toks, sizeof(toks), "", dateString, sizeof(dateString));
				g_VACEpoch = StringToInt(dateString);
			}
		}
	}

	if (convar == g_hCVAction)
	{
		switch (g_hCVAction.IntValue)
		{
			case 0:
			{
				g_hCVActions.SetInt(ACTION_LOG + ACTION_BAN);
				return;
			}
			case 1:
			{
				g_hCVActions.SetInt(ACTION_LOG + ACTION_KICK);
				return;
			}
			case 2:
			{
				g_hCVActions.SetInt(ACTION_LOG + ACTION_NOTIFY_ADMINS);
				return;
			}
			case 3:
			{
				g_hCVActions.SetInt(ACTION_LOG);
				return;
			}
		}
	}

	char steamID[18];
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientAuthorized(i) && GetClientAuthId(i, AuthId_SteamID64, steamID, sizeof(steamID)))
		{
			HandleClient(i, steamID, true);
		}
	}
}

public void OnConfigsExecuted()
{
	char db[64];
	g_hCVDB.GetString(db, sizeof(db));
	if (!StrEqual(g_dbConfig, db))
	{
		strcopy(g_dbConfig, sizeof(g_dbConfig), db);
		Database.Connect(OnDBConnected, db);
	}

	UpdateBaseUrl();
}

void UpdateBaseUrl()
{
	char apiKey[64];
	g_hCVAPIKey.GetString(apiKey, sizeof(apiKey));
	if (strlen(apiKey) == 0)
	{
		g_baseUrl = "";
		LogError("%T", "Error_Key_Required", LANG_SERVER);
		return;
	}

	Format(g_baseUrl, sizeof(g_baseUrl), "/ISteamUser/GetPlayerBans/v1/?key=%s&steamids=", apiKey);
}

public void OnClientConnected(int client)
{
	g_clientStatus[client] = {0, 0, 0, 0, 0};
}

public void OnClientPostAdminCheck(int client)
{
	if (!IsFakeClient(client))
	{
		if (CheckCommandAccess(client, "sm_vacbans_immunity", ADMFLAG_RCON, true))
		{
#if DEBUG
			LogToFile(g_debugLogPath, "Skipping check on client %L due to immunity flag", client);
#endif
			return;
		}

		char query[96];
		char steamID[18];

		if (GetClientAuthId(client, AuthId_SteamID64, steamID, sizeof(steamID)))
		{
			DataPack hPack = new DataPack();
			hPack.WriteCell(client);
			hPack.WriteString(steamID);

			Format(query, sizeof(query), "SELECT * FROM `vacbans_cache` WHERE `steam_id` = '%s' LIMIT 1;", steamID);
			g_hDatabase.Query(OnQueryPlayerLookup, query, hPack);
		}
	}
}

public Action Command_Reset(int client, int args)
{
	g_hDatabase.Query(OnQueryNoOp, "DELETE FROM `vacbans_cache` WHERE `expire` != 0;");
	ReplyToCommand(client, "[SM] %t", "Message_Reset");
	return Plugin_Handled;
}

public Action Command_Whitelist(int client, int args)
{
	char argString[72];
	char action[8];
	char steamIDString[32];
	char steamID[18];

	GetCmdArgString(argString, sizeof(argString));
	int pos = BreakString(argString, action, sizeof(action));
	if (pos > -1)
	{
		strcopy(steamIDString, sizeof(steamIDString), argString[pos]);

		if (GetSteamID64(steamIDString, steamID, sizeof(steamID)))
		{
			char query[128];
			if (StrEqual(action, "add"))
			{
				Format(query, sizeof(query), "REPLACE INTO `vacbans_cache` (`steam_id`, `expire`) VALUES ('%s', 0);", steamID);
				g_hDatabase.Query(OnQueryNoOp, query);

				ReplyToCommand(client, "[SM] %t", "Message_Whitelist_Added", steamIDString);

				return Plugin_Handled;
			}

			if (StrEqual(action, "remove"))
			{
				Format(query, sizeof(query), "DELETE FROM `vacbans_cache` WHERE `steam_id` = '%s';", steamID);
				g_hDatabase.Query(OnQueryNoOp, query);

				ReplyToCommand(client, "[SM] %t", "Message_Whitelist_Removed", steamIDString);

				return Plugin_Handled;
			}
		}
	}
	else
	{
		if (StrEqual(action, "clear"))
		{
			g_hDatabase.Query(OnQueryNoOp, "DELETE FROM `vacbans_cache` WHERE `expire` = 0;");

			ReplyToCommand(client, "[SM] %t", "Message_Whitelist_Cleared");

			return Plugin_Handled;
		}
	}

	ReplyToCommand(client, "%t: sm_vacbans_whitelist <add|remove|clear> [SteamID]", "Message_Usage");
	return Plugin_Handled;
}

public Action Command_List(int client, int args)
{
	ReplyToCommand(client, "[SM] %t", "Message_List");

	int status[5];
	char commStatusText[16];
	char econStatusText[24];
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientAuthorized(i))
		{
			status = g_clientStatus[i];
			if (status[0] > 0 || status[2] > 0 || status[3] > 0 || status[4] > 0)
			{
				if (status[3] > 0)
				{
					commStatusText = "Status_Banned";
				}
				else
				{
					commStatusText = "Status_None";
				}

				switch (status[4])
				{
					case 1:
						econStatusText = "Status_Probation";
					case 2:
						econStatusText = "Status_Banned";
					default:
						econStatusText = "Status_None";
				}

				ReplyToCommand(client, " - %N (%t)", i, "Admin_Message", status[0], status[2], commStatusText, econStatusText);
			}
		}
	}
}

/**
 * Update the client data based on the response data.
 *
 * @param client   The client index
 * @param response The response from the server
 */
void UpdateClientStatus(int client, const char[] response)
{
#if DEBUG
	LogToFile(g_debugLogPath, "Updating %L", client);
	LogToFileEx(g_debugLogPath, response);
#endif

	g_clientStatus[client] = {0, 0, 0, 0, 0};

	char responseData[1024];
	strcopy(responseData, sizeof(responseData), response);

	ReplaceString(responseData, sizeof(responseData), " ", "");
	ReplaceString(responseData, sizeof(responseData), "\t", "");
	ReplaceString(responseData, sizeof(responseData), "\n", "");
	ReplaceString(responseData, sizeof(responseData), "\r", "");
	ReplaceString(responseData, sizeof(responseData), "\"", "");
	ReplaceString(responseData, sizeof(responseData), "{players:[{", "");
	ReplaceString(responseData, sizeof(responseData), "}]}", "");

	char parts[16][64];
	int count = ExplodeString(responseData, ",", parts, sizeof(parts), sizeof(parts[]));
	char kv[2][64];
	for (int i = 0; i < count; i++)
	{
		if (ExplodeString(parts[i], ":", kv, sizeof(kv), sizeof(kv[])) < 2)
		{
			continue;
		}

		if (StrEqual(kv[0], "NumberOfVACBans"))
		{
			g_clientStatus[client][0] = StringToInt(kv[1]);
		}
		else if (StrEqual(kv[0], "DaysSinceLastBan"))
		{
			g_clientStatus[client][1] = StringToInt(kv[1]);
		}
		else if (StrEqual(kv[0], "NumberOfGameBans"))
		{
			g_clientStatus[client][2] = StringToInt(kv[1]);
		}
		else if (StrEqual(kv[0], "CommunityBanned"))
		{
			g_clientStatus[client][3] = StrEqual(kv[1], "true", false) ? 1 : 0;
		}
		else if (StrEqual(kv[0], "EconomyBan"))
		{
			if (StrEqual(kv[1], "probation", false))
			{
				g_clientStatus[client][4] = 1;
			}
			else if (StrEqual(kv[1], "banned", false))
			{
				g_clientStatus[client][4] = 2;
			}
		}
	}
}

/**
 * Handle the results of a lookup.
 *
 * @param client    The client index
 * @param steamID   The client's 64 bit SteamID
 * @param fromCache Whether the results came from the cache
 */
void HandleClient(int client, const char[] steamID, bool fromCache)
{
	if (IsClientAuthorized(client))
	{
		// Check to make sure this is the same client that originally connected
		char clientSteamID[18];
		if (!GetClientAuthId(client, AuthId_SteamID64, clientSteamID, sizeof(clientSteamID)) || !StrEqual(steamID, clientSteamID))
		{
			return;
		}

		int numVACBans = g_clientStatus[client][0];
		int daysSinceLastVAC = g_clientStatus[client][1];
		int numGameBans = g_clientStatus[client][2];
		bool communityBanned = g_clientStatus[client][3] == 1;
		int econStatus = g_clientStatus[client][4];

		Call_StartForward(OnDetectedClient);
		Call_PushCell(client);
		Call_PushString(steamID);
		Call_PushCell(numVACBans);
		Call_PushCell(daysSinceLastVAC);
		Call_PushCell(numGameBans);
		Call_PushCell(communityBanned);
		Call_PushCell(econStatus);
		Call_Finish();

		bool vacBanned = numVACBans > 0 && g_hCVDetectVACBans.BoolValue;
		bool gameBanned = numGameBans > 0 && g_hCVDetectGameBans.BoolValue;
		bool commBanned = communityBanned && g_hCVDetectCommunityBans.BoolValue;
		bool econBanned = econStatus > 1 && g_hCVDetectEconBans.BoolValue;
		bool econProbation = econStatus > 0 && g_hCVDetectEconBans.IntValue > 1;

		if (vacBanned && g_hCVVACExpire.BoolValue)
		{
			vacBanned = daysSinceLastVAC < g_hCVVACExpire.IntValue;
		}

		if (vacBanned && g_VACEpoch > 0)
		{
			char banTimeString[9];
			FormatTime(banTimeString, sizeof(banTimeString), "%Y%m%d", GetTime() - (daysSinceLastVAC * 86400));
			int banTime = StringToInt(banTimeString);

			vacBanned = banTime > g_VACEpoch;
		}

		if (vacBanned || gameBanned || commBanned || econBanned || econProbation)
		{
			int actions = g_hCVActions.IntValue;

			char reason[32];
			if (vacBanned && numVACBans > 1)
			{
				reason = "VAC_Ban_Plural";
			}
			else if (vacBanned)
			{
				reason = "VAC_Ban";
			}
			else if (gameBanned && numGameBans > 1)
			{
				reason = "Game_Ban_Plural";
			}
			else if (gameBanned)
			{
				reason = "Game_Ban";
			}
			else if (commBanned)
			{
				reason = "Community_Ban";
			}
			else if (econBanned)
			{
				reason = "Economy_Ban";
			}
			else if (econProbation)
			{
				reason = "Economy_Probation";
			}

			char commStatusText[16];
			if (communityBanned)
			{
				commStatusText = "Status_Banned";
			}
			else
			{
				commStatusText = "Status_None";
			}

			char econStatusText[24];
			switch (econStatus)
			{
				case 1:
					econStatusText = "Status_Probation";
				case 2:
					econStatusText = "Status_Banned";
				default:
					econStatusText = "Status_None";
			}

			if (actions & ACTION_LOG)
			{
				char path[PLATFORM_MAX_PATH];
				BuildPath(Path_SM, path, sizeof(path), "logs/vacbans.log");
				LogToFile(path, "%L %T", client, "Admin_Message", LANG_SERVER, numVACBans, numGameBans, commStatusText, econStatusText);
			}

			if (actions & ACTION_BAN)
			{
				char userformat[64];
				Format(userformat, sizeof(userformat), "%L", client);
				LogAction(0, client, "%T", "Log_Banned", LANG_SERVER, userformat, reason);

				ServerCommand("sm_ban #%d 0 \"[VAC Status Checker] %T\"", GetClientUserId(client), "Player_Message", client, "Banned", reason);
			}
			else if (actions & ACTION_KICK)
			{
				KickClient(client, "[VAC Status Checker] %t", "Player_Message", "Kicked", reason);
			}

			if (actions & ACTION_NOTIFY_ALL || actions & ACTION_NOTIFY_ADMINS)
			{
				for (int i = 1; i <= MaxClients; i++)
				{
					if (!IsClientInGame(i) || IsFakeClient(i))
					{
						continue;
					}

					if (!(actions & ACTION_NOTIFY_ALL) && !CheckCommandAccess(i, "sm_vacbans_list", ADMFLAG_KICK))
					{
						continue;
					}

					PrintToChat(i, "[VAC Status Checker] [%N] %t", client, "Admin_Message", numVACBans, numGameBans, commStatusText, econStatusText);
				}
			}
		}

		if (!fromCache)
		{
			int expire = GetTime() + g_hCVCacheTime.IntValue * 86400;
			char query[256];
			Format(query, sizeof(query), "REPLACE INTO `vacbans_cache` VALUES ('%s', %d, %d, %d, %d, %d, %d);", steamID, numVACBans, GetTime() - daysSinceLastVAC * 86400, numGameBans, communityBanned ? 1 : 0, econStatus, expire);
			g_hDatabase.Query(OnQueryNoOp, query);
		}
	}
}

/**
 * Get the 64 bit Steam ID from a text format.
 *
 * @param steamIDString The Steam ID as a string
 * @param steamID64     Buffer to store the result
 * @param maxlen        The maximum length of the result buffer
 */
bool GetSteamID64(const char[] steamIDString, char[] steamID64, int maxlen)
{
	char toks[3][18];
	int parts = ExplodeString(steamIDString, ":", toks, sizeof(toks), sizeof(toks[]));
	int iSteamID;
	if (parts == 3)
	{
		if (StrContains(toks[0], "STEAM_", false) >= 0)
		{
			int iServer = StringToInt(toks[1]);
			int iAuthID = StringToInt(toks[2]);
			iSteamID = (iAuthID*2) + 60265728 + iServer;
		}
		else if (StrEqual(toks[0], "[U", false))
		{
			ReplaceString(toks[2], sizeof(toks[]), "]", "");
			int iAuthID = StringToInt(toks[2]);
			iSteamID = iAuthID + 60265728;
		}
		else
		{
			steamID64[0] = '\0';
			return false;
		}
	}
	else if (strlen(toks[0]) == 17 && IsCharNumeric(toks[0][0]))
	{
		strcopy(steamID64, maxlen, steamIDString);
		return true;
	}
	else
	{
		steamID64[0] = '\0';
		return false;
	}

	if (iSteamID >= 100000000)
	{
		int upper = 765611979;
		char temp[12], carry[12];

		Format(temp, sizeof(temp), "%d", iSteamID);
		Format(carry, 2, "%s", temp);
		int icarry = StringToInt(carry[0]);
		upper += icarry;

		Format(temp, sizeof(temp), "%d", iSteamID);
		Format(steamID64, maxlen, "%d%s", upper, temp[1]);
	}
	else
	{
		Format(steamID64, maxlen, "765611979%d", iSteamID);
	}

	return true;
}

// Threaded DB callbacks
public void OnDBConnected(Database db, const char[] error, any data)
{
	if (db == null)
	{
		SetFailState(error);
	}

	g_hDatabase = db;
	g_hDatabase.Query(OnQueryVersionCheck, "SELECT `version` FROM `vacbans_version`;");
}

public void OnQueryVersionCheck(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null || !results.FetchRow())
	{
		g_hDatabase.Query(OnQueryVersionCreated, "CREATE TABLE `vacbans_version` (`version` INT(11) NOT NULL);");
		g_hDatabase.Query(OnQueryCacheCreated, "CREATE TABLE `vacbans_cache` (`steam_id` VARCHAR(64) NOT NULL, `vac_bans` INT(11), `last_vac_time` INT(11), `game_bans` INT(11), `community_banned` BOOL, `econ_status` INT(11), `expire` INT(11) NOT NULL, PRIMARY KEY (`steam_id`));");
	}
}

public void OnQueryVersionCreated(Database db, DBResultSet results, const char[] error, any data)
{
	char query[64];
	Format(query, sizeof(query), "INSERT INTO `vacbans_version` VALUES (%d);", DATABASE_VERSION);
	g_hDatabase.Query(OnQueryNoOp, query);
}

public void OnQueryCacheCreated(Database db, DBResultSet results, const char[] error, any data)
{
	if (results != null)
	{
		g_hDatabase.Query(OnQueryMigrate, "SELECT `steam_id` FROM `vacbans` WHERE `banned` = 0 AND `expire` = 0;");
	}
}

public void OnQueryMigrate(Database db, DBResultSet results, const char[] error, any data)
{
	if (results != null)
	{
		char steamId[18];
		char query[128];
		while (results.FetchRow())
		{
			results.FetchString(0, steamId, sizeof(steamId));
			Format(query, sizeof(query), "INSERT INTO `vacbans_cache` (`steam_id`, `expire`) VALUES ('%s', 0);", steamId);
			g_hDatabase.Query(OnQueryNoOp, query);
		}
	}
}

public void OnQueryPlayerLookup(Database db, DBResultSet results, const char[] error, DataPack data)
{
	bool checked = false;

	data.Reset();
	int client = data.ReadCell();
	char steamID[18];
	data.ReadString(steamID, sizeof(steamID));
	delete data;

	if (results != null)
	{
		if (results.FetchRow())
		{
			checked = results.FetchInt(6) > GetTime();

			g_clientStatus[client][0] = results.FetchInt(1);
			g_clientStatus[client][1] = (GetTime() - results.FetchInt(2)) / 86400;
			g_clientStatus[client][2] = results.FetchInt(3);
			g_clientStatus[client][3] = results.FetchInt(4);
			g_clientStatus[client][4] = results.FetchInt(5);

			if (results.FetchInt(6) == 0)
			{
				// Player is whitelisted
				return;
			}
		}
	}

	if (checked)
	{
		HandleClient(client, steamID, true);
	}
	else
	{
		ConnectToApi(client, steamID);
	}
}

public

void ConnectToApi(int client, const char[] steamID)
{
	if (strlen(g_baseUrl) == 0)
	{
		return;
	}

#if DEBUG
	LogToFile(g_debugLogPath, "Checking client %L", client);
#endif

#if defined _steamtools_included
	if (STEAMTOOLS_AVAILABLE())
	{
		SteamToolsConnectToApi(client, steamID);
		return;
	}
#endif

#if defined _SteamWorks_Included
	if (STEAMWORKS_AVAILABLE())
	{
		SteamWorksConnectToApi(client, steamID);
		return;
	}
#endif

#if defined _socket_included
	if (SOCKET_AVAILABLE())
	{
		SocketConnectToApi(client, steamID);
	}
#endif
}

public void OnQueryNoOp(Database db, DBResultSet results, const char[] error, any data)
{
	// Nothing to do
}

// You're crazy, man...
