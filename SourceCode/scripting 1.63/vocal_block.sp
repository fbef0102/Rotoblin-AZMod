/*
 * vim: set ts=4 :
 * =============================================================================
 * Left 4 Dead Vocalize Guard
 * Guards against Player's Abusing the Vocalize System
 * Variation of the 'Left 4 Dead Vote Gaurd Plugin by CrimsonGT
 * SourceMod (C)2004-2007 AlliedModders LLC.  All rights reserved.
 * =============================================================================
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * As a special exception, AlliedModders LLC gives you permission to link the
 * code of this program (as well as its derivative works) to "Half-Life 2," the
 * "Source Engine," the "SourcePawn JIT," and any Game MODs that run on software
 * by the Valve Corporation.  You must obey the GNU General Public License in
 * all respects for all other code used.  Additionally, AlliedModders LLC grants
 * this exception to all derivative works.  AlliedModders LLC defines further
 * exceptions, found in LICENSE.txt (as of this writing, version JULY-31-2007),
 * or <http://www.sourcemod.net/license.php>.
 *
 */

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <colors>

#define PLUGIN_VERSION "1.0.0"

new g_VocalCalled[MAXPLAYERS+1];
new Float:g_LastVocalTime[MAXPLAYERS+1];

/* CVARS */
new Handle:cEnabled = INVALID_HANDLE;
new Handle:cAdminsImmune = INVALID_HANDLE;
new Handle:cVocalLimit = INVALID_HANDLE;
new Handle:cVocalDelay = INVALID_HANDLE;
new Handle:cBanTime = INVALID_HANDLE;

public Plugin:myinfo = 
{
	name = "L4D Vocalize Guard",
	author = "Crimson - TeddyRuxpin",
	description = "Left 4 Dead Vocalize Spam Blocker",
	version = PLUGIN_VERSION,
	url = "http://www.sourcemod.net/"
}

public OnPluginStart()
{
	LoadTranslations("Roto2-AZ_mod.phrases");
	RegConsoleCmd("vocalize", Command_CallVocal);

	CreateConVar("sm_vocalize_guard_version", PLUGIN_VERSION, "L4D Vocalize Guard Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);

	cEnabled = CreateConVar("sm_vocalize_guard_enabled", "1", "Enable/Disable L4D Vocalize Guardian [0 = FALSE, 1 = TRUE]", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	cAdminsImmune = CreateConVar("sm_vocalize_guard_adminimmune", "1", "Enable/Disable Admin Immunity to Penalties [0 = FALSE, 1 = TRUE]", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	cVocalLimit = CreateConVar("sm_vocalize_guard_vlimit", "100", "Max Vocalize Spam Calls Allowed [0 = NO LIMIT]", FCVAR_PLUGIN, true, 0.0);
	cVocalDelay = CreateConVar("sm_vocalize_guard_vdelay", "100", "Delay before a player can call another Vocalize command [0 = DISABLED]", FCVAR_PLUGIN, true, 0.0);
	cBanTime = CreateConVar("sm_vocalize_guard_bantime", "0", "Duration of Ban [0 = KICKS PLAYER]", FCVAR_PLUGIN, true, 0.0);
	
	HookEvent("player_disconnect", Event_PlayerDisconnect);
}

public OnMapStart()
{
	new iMaxPlayers = GetMaxClients();
	
	for(new i=1;i<=iMaxPlayers;i++)
	{
		g_VocalCalled[i] = 0;
		g_LastVocalTime[i] = 0.0;
	}
}

public Action:Event_PlayerDisconnect(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	g_VocalCalled[client] = 0;
	g_LastVocalTime[client] = 0.0;
}

public Action:Command_CallVocal(client, args)
{
	/* If the plugin is enabled */
	if(GetConVarBool(cEnabled))
	{
		new iMaxVotes = GetConVarInt(cVocalLimit);
		new flTimeDelay = GetConVarInt(cVocalDelay);
		
		decl String:sVoteType[32], String:sTarget[12];
		GetCmdArg(1, sVoteType, sizeof(sVoteType));
		GetCmdArg(2, sTarget, sizeof(sTarget));
		
		new target = GetClientOfUserId(StringToInt(sTarget));
		
		/* If the Callvote is a Kick, Check Immunity */
		if(strcmp(sVoteType, "kick")==0)
		{
			if(IsAdmin(target))
			{
				decl String:sKickerName[32];
				GetClientName(client, sKickerName, sizeof(sKickerName));
				
				/* Tell client they cant kick the admin */
				CPrintToChat(client, "{green}[SM] {default}%T","vocal_block1",client);
				/* Tell admin whose trying to kick them */
				CPrintToChat(target, "{green}[SM] {default}%T","vocal_block2",target, sKickerName);

				return Plugin_Handled;
			}
		}
		
		/* If this player hasnt called any votes */
		if(g_VocalCalled[client] == 0)
		{
			g_LastVocalTime[client] = GetEngineTime();
			g_VocalCalled[client]++;
		}
		else if(g_LastVocalTime[client] < (GetEngineTime() - flTimeDelay))
		{
			g_LastVocalTime[client] = GetEngineTime();

			/*If Client Has Exceeded Max Call Votes */
			if((g_VocalCalled[client] == iMaxVotes) && (iMaxVotes != 0))
			{
				/* If the players not an admin */
				if(!IsAdmin(client))
				{
					RemovePlayer(client);
				}
			}
			/*Warns Client upon reaching the Max Call Votes */
			else if(g_VocalCalled[client] == (iMaxVotes-1))
			{
				CPrintToChat(client, "{green}[SM] {default}%T","vocal_block2",client);
				
				g_VocalCalled[client]++;
			}
			else
			{
				g_VocalCalled[client]++;
			}
		}
		else
		{
			new iTimeLeft = RoundToNearest(flTimeDelay - (GetEngineTime() - g_LastVocalTime[client]));
			CPrintToChat(client, "{default}[{olive}TS{default}] {default}%T","vocal_block3",client, iTimeLeft);
			
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

/* Is Player Admin Check */
bool:IsAdmin(client)
{
	if(GetConVarInt(cAdminsImmune) == 0)
	{
		return false;
	}

	new AdminId:admin = GetUserAdmin(client);
	
	if(admin == INVALID_ADMIN_ID)
	{
		return false;
	}

	return true;
}

/* Kick OR Ban Player Based on CVAR Value */
RemovePlayer(client)
{
	new iBanTime = GetConVarInt(cBanTime);

	if(IsClientConnected(client))
	{
		if(iBanTime == 0)
		{

			if(IsClientInGame(client))
			{
				decl String:sName[MAX_NAME_LENGTH];
				GetClientName(client, sName, sizeof(sName));
				CPrintToChatAll("{green}[SM] {default}%t","vocal_block4", sName);

				KickClient(client, "Kicked for Vocalize Abuse");
			}
		}
		else if(iBanTime > 0)
		{
			if(IsClientInGame(client))
			{
				decl String:sName[MAX_NAME_LENGTH];
				GetClientName(client, sName, sizeof(sName));
				CPrintToChatAll("{green}[SM] {default}%t","vocal_block4", sName, iBanTime);

				BanClient(client, iBanTime, BANFLAG_AUTO, "Banned", "Banned", _, client);
			}
		}
	}
}