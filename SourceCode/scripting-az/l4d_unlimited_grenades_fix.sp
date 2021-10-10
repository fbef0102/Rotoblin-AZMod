/*
*	Exploit Fix - Unlimited Grenades
*	Copyright (C) 2021 Silvers
*
*	This program is free software: you can redistribute it and/or modify
*	it under the terms of the GNU General Public License as published by
*	the Free Software Foundation, either version 3 of the License, or
*	(at your option) any later version.
*
*	This program is distributed in the hope that it will be useful,
*	but WITHOUT ANY WARRANTY; without even the implied warranty of
*	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*	GNU General Public License for more details.
*
*	You should have received a copy of the GNU General Public License
*	along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/



#define PLUGIN_VERSION 		"1.1"

/*======================================================================================
	Plugin Info:

*	Name	:	[L4D & L4D2] Exploit Fix - Unlimited Grenades
*	Author	:	SilverShot
*	Descrp	:	Fixes an exploit where unlimited grenades could be created.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=334600
*	Plugins	:	https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.1 (10-Oct-2021)
	- Fixed errors being thrown. Thanks to "HarryPotter" for reporting.

1.0 (07-Oct-2021)
	- Initial release.

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define EXPLOIT_TIME	0.5

bool g_bLeft4Dead2;
float g_fTimeThrow[MAXPLAYERS+1];



public Plugin myinfo =
{
	name = "[L4D & L4D2] Exploit Fix - Unlimited Grenades",
	author = "SilverShot",
	description = "Fixes an exploit where unlimited grenades could be created.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=334600"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if( test == Engine_Left4Dead ) g_bLeft4Dead2 = false;
	else if( test == Engine_Left4Dead2 ) g_bLeft4Dead2 = true;
	else
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	CreateConVar("l4d_unlimited_grenades_version", PLUGIN_VERSION, "Exploit Fix - Unlimited Grenades plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);

	HookEvent("round_start",	Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("weapon_fire",	Event_WeaponFire);
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for( int i = 1; i <= MaxClients; i++ )
	{
		g_fTimeThrow[i] = 0.0;
	}
}

public void Event_WeaponFire(Event event, const char[] name, bool dontBroadcast)
{
	char classname[32];
	event.GetString("weapon", classname, sizeof(classname));

	if( strcmp(classname, "pipe_bomb") == 0 || strcmp(classname, "molotov") == 0 || (g_bLeft4Dead2 && strcmp(classname, "vomitjar") == 0) )
	{
		int client = GetClientOfUserId(event.GetInt("userid"));
		g_fTimeThrow[client] = GetGameTime();
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if( strcmp(classname, "pipe_bomb_projectile") == 0 || strcmp(classname, "molotov_projectile") == 0 || (g_bLeft4Dead2 && strcmp(classname, "vomitjar_projectile") == 0) )
	{
		RequestFrame(OnFrameSpawn, EntIndexToEntRef(entity));
	}
}

public void OnFrameSpawn(int entity)
{
	if( EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE )
	{
		int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
		if( client > 0 && client <= MaxClients && GetGameTime() - g_fTimeThrow[client] < EXPLOIT_TIME )
		{
			int weapon = GetPlayerWeaponSlot(client, 2);
			if( weapon != -1 )
			{
				// PrintToChatAll("Exploit Blocked: %N", client);
				RemovePlayerItem(client, weapon);
				RemoveEntity(weapon);
			}
		}
	}
}