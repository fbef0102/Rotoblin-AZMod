/*
 ----------------------------------------------------------------
 Plugin      : SaveChat 
 Author      : citkabuto
 Game        : Any Source game
 Description : Will record all player messages to a file
 ================================================================
 Date       Version  Description
 ================================================================
 23/Feb/10  1.2.1    - Fixed bug with player team id
 15/Feb/10  1.2.0    - Now records team name when using cvar
                            sm_record_detail 
 01/Feb/10  1.1.1    - Fixed bug to prevent errors when using 
                       HLSW (client index 0 is invalid)
 31/Jan/10  1.1.0    - Fixed date format on filename
                       Added ability to record player info
                       when connecting using cvar:
                            sm_record_detail (0=none,1=all:def:1)
 28/Jan/10  1.0.0    - Initial Version 
 ----------------------------------------------------------------
*/

#include <sourcemod>
#include <sdktools>
#include <geoip.inc>
#include <string.inc>

#define PLUGIN_VERSION "SaveChat_1.3"

static String:chatFile[128]
new Handle:fileHandle       = INVALID_HANDLE
new Handle:sc_record_detail = INVALID_HANDLE

public Plugin:myinfo = 
{
	name = "SaveChat",
	author = "citkabuto & Harry Potter",
	description = "Records player chat messages to a file",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=117116"
}

public OnPluginStart()
{
	new String:date[21]
	new String:logFile[100]

	/* Register CVars */
	CreateConVar("sm_savechat_version", PLUGIN_VERSION, "Save Player Chat Messages Plugin", 
		FCVAR_PLUGIN|FCVAR_DONTRECORD|FCVAR_REPLICATED)

	sc_record_detail = CreateConVar("sc_record_detail", "1", 
		"Record player Steam ID and IP address",
		FCVAR_PLUGIN)

	/* Say commands */
	RegConsoleCmd("say", Command_Say)
	RegConsoleCmd("say_team", Command_SayTeam)

	/* Format date for log filename */
	FormatTime(date, sizeof(date), "%d%m%y", -1)

	/* Create name of logfile to use */
	Format(logFile, sizeof(logFile), "/logs/chat%s.log", date)
	BuildPath(Path_SM, chatFile, PLATFORM_MAX_PATH, logFile)
	
	HookEvent("player_disconnect", event_PlayerDisconnect, EventHookMode_Pre);
}

/*
 * Capture player chat and record to file
 */
public Action:Command_Say(client, args)
{
	LogChat(client, args, false)
	return Plugin_Continue
}

/*
 * Capture player team chat and record to file
 */
public Action:Command_SayTeam(client, args)
{
	LogChat(client, args, true)
	return Plugin_Continue
}

public OnClientPostAdminCheck(client)
{
	/* Only record player detail if CVAR set */
	if(GetConVarInt(sc_record_detail) != 1)
		return

	if(IsFakeClient(client)) 
		return

	new String:msg[2048]
	new String:time[21]
	//new String:country[3]
	new String:steamID[128]
	new String:playerIP[50]
	
	GetClientAuthString(client, steamID, sizeof(steamID))

	/* Get 2 digit country code for current player */
	
	if(GetClientIP(client, playerIP, sizeof(playerIP), true) == false) {
		//country   = "  "
	} else {
		//if(GeoipCode2(playerIP, country) == false) {
			//country = "  "
		//}
	}
	
	
	FormatTime(time, sizeof(time), "%H:%M:%S", -1)
	Format(msg, sizeof(msg), "[%s] (%s | %s) %-25N has joined",
		time,
		steamID,
		playerIP,
		client)

	SaveMessage(msg)
}

public Action:event_PlayerDisconnect(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if( client && !IsFakeClient(client) && !dontBroadcast )
	{
		new String:msg[2048]
		new String:time[21]
		//new String:country[3]
		new String:steamID[128]
		new String:playerIP[50]
		
		GetClientAuthString(client, steamID, sizeof(steamID))

		/* Get 2 digit country code for current player */
		
		if(GetClientIP(client, playerIP, sizeof(playerIP), true) == false) {
			//country   = "  "
		} else {
			//if(GeoipCode2(playerIP, country) == false) {
				//country = "  "
			//}
		}
		
		FormatTime(time, sizeof(time), "%H:%M:%S", -1)
		Format(msg, sizeof(msg), "[%s] (%s | %s) %-25N has left",
			time,
			steamID,
			playerIP,
			client)

		SaveMessage(msg)
	}
}

/*
 * Extract all relevant information and format 
 */
public LogChat(client, args, bool:teamchat)
{
	new String:msg[2048]
	new String:time[21]
	new String:text[1024]
	new String:country[3]
	new String:playerIP[50]
	new String:teamName[20]

	GetCmdArgString(text, sizeof(text))
	StripQuotes(text)

	new String:steamID[128]
	
	if (client == 0 || !IsClientInGame(client)) {
		/* Don't try and obtain client country/team if this is a console message */
		Format(country, sizeof(country), "  ")
		Format(teamName, sizeof(teamName), "")
	} else {
		/* Get 2 digit country code for current player */
		if(GetClientIP(client, playerIP, sizeof(playerIP), true) == false) {
			country   = "  "
		} else {
			if(GeoipCode2(playerIP, country) == false) {
				country = "  "
			}
		}
		GetTeamName(GetClientTeam(client), teamName, sizeof(teamName))
		GetClientAuthString(client, steamID, sizeof(steamID))
	}
	FormatTime(time, sizeof(time), "%H:%M:%S", -1)

	if(GetConVarInt(sc_record_detail) == 1) {
		Format(msg, sizeof(msg), "[%s] [%s] [%-9s] %-25N :%s %s",
			time,
			steamID,
			teamName,
			client,
			teamchat == true ? " (TEAM)" : "",
			text)
	} else {
		Format(msg, sizeof(msg), "[%s] [%s] %-25N :%s %s",
			time,
			steamID,
			client,
			teamchat == true ? " (TEAM)" : "",
			text)
	}

	SaveMessage(msg)
}

/*
 * Log a map transition
 */
public OnMapStart(){
	new String:map[128]
	new String:msg[1024]
	new String:date[21]
	new String:time[21]
	new String:logFile[100]

	GetCurrentMap(map, sizeof(map))

	/* The date may have rolled over, so update the logfile name here */
	FormatTime(date, sizeof(date), "%y_%m_%d", -1)
	Format(logFile, sizeof(logFile), "/logs/chat/chat_%s.log", date)
	BuildPath(Path_SM, chatFile, PLATFORM_MAX_PATH, logFile)

	FormatTime(time, sizeof(time), "%d/%m/%Y %H:%M:%S", -1)
	Format(msg, sizeof(msg), "[%s] --- Map: %s ---", time, map)

	SaveMessage("--=================================================================--")
	SaveMessage(msg)
	SaveMessage("--=================================================================--")
}

/*
 * Log the message to file
 */
public SaveMessage(const String:message[])
{
	fileHandle = OpenFile(chatFile, "a")  /* Append */
	if(fileHandle == INVALID_HANDLE)
	{
		CreateDirectory("/addons/sourcemod/logs/chat", 0);
		fileHandle = OpenFile(chatFile, "a") //open again
	}
	WriteFileLine(fileHandle, message)
	CloseHandle(fileHandle)
}

