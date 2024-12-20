/**
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
#include <geoip>
#include <multicolors>

#define VERSION "2.0"

/*****************************************************************


			G L O B A L   V A R S


*****************************************************************/
//static g_iSColors[5]             = {1,               3,              4,         6,			5};
//static String:g_sSColors[5][13]  = {"{DEFAULT}",     "{LIGHTGREEN}", "{GREEN}", "{YELLOW}",	"{OLIVE}"};

new String:player[50];
new String:player_ip[16];
new String:player_country[45];
new String:STEAMID[32];
new String:player_city[45];
new String:player_region[45];
new String:player_ccode[3];
new String:player_ccode3[4];
/*****************************************************************


			L I B R A R Y   I N C L U D E S


*****************************************************************/
#include "cannounce/countryshow.sp"
#include "cannounce/joinmsg.sp"
#include "cannounce/geolist.sp"
#include "cannounce/suppress.sp"


/*****************************************************************


			P L U G I N   I N F O


*****************************************************************/
public Plugin:myinfo =
{
	name = "Connect Announce",
	author = "Arg!, modify by harry",
	description = "Replacement of default player connection message, allows for custom connection messages",
	version = VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=77306"
};



/*****************************************************************


			F O R W A R D   P U B L I C S


*****************************************************************/
public OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("cannounce.phrases");
	LoadTranslations("Roto2-AZ_mod.phrases");
	CreateConVar("sm_cannounce_version", VERSION, "Connect announce replacement", FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);

	//event hooks
	HookEvent("player_disconnect", event_PlayerDisconnect, EventHookMode_Pre);
	
	
	//country show
	SetupCountryShow();
	
	//custom join msg
	SetupJoinMsg();
	
	//geographical player list
	SetupGeoList();
	
	//suppress standard connection message
	SetupSuppress();
	
	//create config file if not exists
	AutoExecConfig(true, "cannounce");
}

public OnMapStart()
{
	//precahce and set downloads for sounds files for all players
	LoadSoundFilesAll();
	
	
	OnMapStart_JoinMsg();
}

public void OnClientPostAdminCheck(client)
{
	if( !IsFakeClient(client) )
	{
		CreateTimer(5.0, Timer_OnClientPostAdminCheck, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	}
}

Action Timer_OnClientPostAdminCheck(Handle timer, int client)
{
	client = GetClientOfUserId(client);
	if(client && IsClientInGame(client))
	{
		OnPostAdminCheck_CountryShow(client);
		OnPostAdminCheck_Sound();
	}

	return Plugin_Continue;
}


/****************************************************************


			C A L L B A C K   F U N C T I O N S


****************************************************************/
void event_PlayerDisconnect(Event event, char[] name, bool dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if( client && !IsFakeClient(client) && !dontBroadcast )
	{
		event_PlayerDisc_CountryShow(event, client);
		
		if(IsClientInGame(client))
		{
			OnClientDisconnect_Sound();
		}
	}
	
	
	event_PlayerDisconnect_Suppress( event );
}


/*****************************************************************


			P L U G I N   F U N C T I O N S


*****************************************************************/
//Thanks to Darkthrone (https://forums.alliedmods.net/member.php?u=54636)
bool:IsLanIP( String:src[16] )
{
	decl String:ip4[4][4];
	new ipnum;

	if(ExplodeString(src, ".", ip4, 4, 4) == 4)
	{
		ipnum = StringToInt(ip4[0])*65536 + StringToInt(ip4[1])*256 + StringToInt(ip4[2]);
		
		if((ipnum >= 655360 && ipnum < 655360+65535) || (ipnum >= 11276288 && ipnum < 11276288+4095) || (ipnum >= 12625920 && ipnum < 12625920+255))
		{
			return true;
		}
	}

	return false;
}

PrintFormattedMessageToAll( client, playerjoin )//給全部人看的
{
	if(!IsClientInGame(client)) return;
	
	decl String:message[301];
	
	SetFormattedMessage( client );
	
	Format( message, sizeof(message), "%s", player_country );
	if(strcmp(player_region, "an Unknown Region", false) != 0)
		Format( message, sizeof(message), "%s, %s",message, player_region);
	if(strcmp(player_city, "an IP Address", false) != 0 && strncmp(player_city, "Somewhere", false) != 0)
		Format( message, sizeof(message), "%s, %s",message, player_city);
		
	if(playerjoin == 1)//玩家進來
	{
		CPrintToChatAll("{default}[{olive}TS{default}] %t ({green}%s{default})","cannounce1",player,message);
	}
	else//玩家離開
	{
		CPrintToChatAll("{default}[{olive}TS{default}] %t ({green}%s{default})","cannounce2",player,dcreason);
	}
	//player 玩家名稱
	//player_country 玩家國家
	//player_ip 玩家IP
	//STEAMID 玩家steam id
	//dcreason 玩家離開原因
	//player_city 玩家的城市
	//player_region 玩家的地區(省,州)
	//player_ccode 玩家的國家短代號
	//player_ccode3 玩家的國家短代號(多一些代號)
}

PrintFormattedMessageToAdmins( client, playerjoin)//專屬給adm看的
{
	decl String:message[301];
	
	SetFormattedMessage( client );
	
	Format( message, sizeof(message), "%s", player_country );
	if(strcmp(player_region, "an Unknown Region", false) != 0)
		Format( message, sizeof(message), "%s, %s",message, player_region);
	if(strcmp(player_city, "an IP Address", false) != 0 && strncmp(player_city, "Somewhere", false) != 0)
		Format( message, sizeof(message), "%s, %s",message, player_city);

		
	if(IsClientInGame(client))
	{
		for (new i = 1; i <= MaxClients; i++)
		{
			if( IsClientInGame(i) && CheckCommandAccess( i, "", ADMFLAG_ROOT, true ) )
			{
				if(playerjoin == 1) //玩家進來
				{
					//CPrintToChat(i, "{default}[{olive}TS{default}] %T ({green}%s{default}) IP: {green}%s{default} {olive}<%s>","cannounce1",i, player, message, player_ip, STEAMID);
					CPrintToChat(i, "{default}[{olive}TS{default}] %T ({green}%s{default}) {olive}<%s>","cannounce1",i, player, message, STEAMID);
				}
				else //玩家離開
				{
					//CPrintToChat(i, "{default}[{olive}TS{default}] %T ({green}%s{default}) IP: {green}%s{default} {olive}<%s>","cannounce2",i,player,dcreason,player_ip, STEAMID);
					CPrintToChat(i, "{default}[{olive}TS{default}] %T ({green}%s{default}) {olive}<%s>","cannounce2",i,player,dcreason, STEAMID);
				}
			}
		}
	}
	
	if(playerjoin == 1)//玩家進來
	{
		LogMessage("[TS] Player %s conneted. (%s) IP:%s <%s>", player, message, player_ip, STEAMID);
	}
	else//玩家離開
	{
		LogMessage("[TS] Player %s disconneted. (%s)[%s] IP:%s <%s>",player,dcreason,message,player_ip,STEAMID);
	}
}

PrintFormattedMsgToNonAdmins( client, playerjoin )//給不是adm看的
{
	if(!IsClientInGame(client)) return;

	decl String:message[301];
	
	SetFormattedMessage( client );
	
	Format( message, sizeof(message), "%s", player_country );
	if(strcmp(player_region, "an Unknown Region", false) != 0)
		Format( message, sizeof(message), "%s, %s",message, player_region);
	if(strcmp(player_city, "an IP Address", false) != 0 && strncmp(player_city, "Somewhere", false) != 0)
		Format( message, sizeof(message), "%s, %s",message, player_city);
		
	for (new i = 1; i <= MaxClients; i++)
	{
		if( IsClientInGame(i) && !CheckCommandAccess( i, "", ADMFLAG_ROOT, true ) )
		{
			if(playerjoin == 1)//玩家進來
			{
				CPrintToChat(i, "{default}[{olive}TS{default}] %T ({green}%s{default})","cannounce1",i, player, message);
			}
			else//玩家離開
			{
				CPrintToChat(i, "{default}[{olive}TS{default}] %T ({green}%s{default})","cannounce2",i,player,dcreason);
			}
		}
	}
}

SetFormattedMessage(client)
{
	//decl String:sColor[4];
	//decl String:sPlayerAdmin[32];
	//decl String:sPlayerPublic[32];
	decl bool:bIsLanIp;
	//decl AdminId:aid;
	
	if( client > -1 )
	{
		GetClientIP(client, player_ip, sizeof(player_ip)); 
		
		//detect LAN IP
		bIsLanIp = IsLanIP( player_ip );
		
		if( !GeoipCode2(player_ip, player_ccode) )
		{
			if( bIsLanIp )
			{
				Format( player_ccode, sizeof(player_ccode), "%T", "LAN Country Short", LANG_SERVER );
			}
			else
			{
				Format( player_ccode, sizeof(player_ccode), "%T", "Unknown Country Short", LANG_SERVER );
			}
		}
		
		if( !GeoipCountry(player_ip, player_country, sizeof(player_country)) )
		{
			if( bIsLanIp )
			{
				Format( player_country, sizeof(player_country), "%T", "LAN Country Desc", LANG_SERVER );
			}
			else
			{
				Format( player_country, sizeof(player_country), "%T", "Unknown Country Desc", LANG_SERVER );
			}
		}
		
		if(!GeoipCity(player_ip, player_city, sizeof(player_city)))
		{
			if( bIsLanIp )
			{
				Format( player_city, sizeof(player_city), "%T", "LAN City Desc", LANG_SERVER );
			}
			else
			{
				Format( player_city, sizeof(player_city), "%T", "Unknown City Desc", LANG_SERVER );
			}
		}

		if(!GeoipRegion(player_ip, player_region, sizeof(player_region)))
		{
			if( bIsLanIp )
			{
				Format( player_region, sizeof(player_region), "%T", "LAN Region Desc", LANG_SERVER );
			}
			else
			{
				Format( player_region, sizeof(player_region), "%T", "Unknown Region Desc", LANG_SERVER );
			}
		}

		if(!GeoipCode3(player_ip, player_ccode3))
		{
			if( bIsLanIp )
			{
				Format( player_ccode3, sizeof(player_ccode3), "%T", "LAN Country Short 3", LANG_SERVER );
			}
			else
			{
				Format( player_ccode3, sizeof(player_ccode3), "%T", "Unknown Country Short 3", LANG_SERVER );
			}
		}
		
		// Fallback for unknown/empty location strings
		if( StrEqual( player_city, "" ) )
		{
			Format( player_city, sizeof(player_city), "%T", "Unknown City Desc", LANG_SERVER );
		}
		
		if( StrEqual( player_region, "" ) )
		{
			Format( player_region, sizeof(player_region), "%T", "Unknown Region Desc", LANG_SERVER );
		}
		
		if( StrEqual( player_country, "" ) )
		{
			Format( player_country, sizeof(player_country), "%T", "Unknown Country Desc", LANG_SERVER );
		}
		
		if( StrEqual( player_ccode, "" ) )
		{
			Format( player_ccode, sizeof(player_ccode), "%T", "Unknown Country Short", LANG_SERVER );
		}
		
		if( StrEqual( player_ccode3, "" ) )
		{
			Format( player_ccode3, sizeof(player_ccode3), "%T", "Unknown Country Short 3", LANG_SERVER );
		}
		
		// Add "The" in front of certain countries
		if( StrContains( player_country, "United", false ) != -1 || 
			StrContains( player_country, "Republic", false ) != -1 || 
			StrContains( player_country, "Federation", false ) != -1 || 
			StrContains( player_country, "Island", false ) != -1 || 
			StrContains( player_country, "Netherlands", false ) != -1 || 
			StrContains( player_country, "Isle", false ) != -1 || 
			StrContains( player_country, "Bahamas", false ) != -1 || 
			StrContains( player_country, "Maldives", false ) != -1 || 
			StrContains( player_country, "Philippines", false ) != -1 || 
			StrContains( player_country, "Vatican", false ) != -1 )
		{
			Format( player_country, sizeof(player_country), "The %s", player_country );
		}

		GetClientName(client, player, sizeof(player));
		GetClientAuthId(client, AuthId_Steam2,STEAMID, sizeof(STEAMID));
	}
}