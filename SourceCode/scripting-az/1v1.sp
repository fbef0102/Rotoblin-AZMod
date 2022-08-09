/*
	SourcePawn is Copyright (C) 2006-2008 AlliedModders LLC.  All rights reserved.
	SourceMod is Copyright (C) 2006-2008 AlliedModders LLC.  All rights reserved.
	Pawn and SMALL are Copyright (C) 1997-2008 ITB CompuPhase.
	Source is Copyright (C) Valve Corporation.
	All trademarks are property of their respective owners.
	This program is free software: you can redistribute it and/or modify it
	under the terms of the GNU General Public License as published by the
	Free Software Foundation, either version 3 of the License, or (at your
	option) any later version.
	This program is distributed in the hope that it will be useful, but
	WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
	General Public License for more details.
	You should have received a copy of the GNU General Public License along
	with this program.  If not, see <http://www.gnu.org/licenses/>.
*/
#pragma semicolon 1
 
#include <sourcemod>
#include <sdktools>
#include <multicolors>

new Handle:hCvarDmgThreshold;
new bool:haspounced;

public Plugin:myinfo =
{
	name = "1v1 TS",
	author = "Blade + Confogl Team, Tabun, Visor, l4d1 port and modify by Harry",
	description = "A plugin designed to support 1v1.",
	version = "0.4",
	url = "https://github.com/Attano/Equilibrium"
};

public OnPluginStart()
{      
	hCvarDmgThreshold = CreateConVar("sm_1v1_dmgthreshold", "24", "Amount of damage done (at once) before SI suicides.", FCVAR_NOTIFY, true, 1.0);

	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Post);
	HookEvent("lunge_pounce", PlayerLunge_Pounce_Event);
	HookEvent("player_spawn",		Event_PlayerSpawn,	EventHookMode_PostNoCopy);
	HookEvent("player_death",		Event_PlayerDeath,	EventHookMode_PostNoCopy);
	HookEvent("tank_spawn",			Event_TankSpawn,		EventHookMode_PostNoCopy);
}

public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	if(!IsClientAndInGame(attacker)||!IsClientAndInGame(client)) return;
	if(GetClientTeam(attacker) == 3 && !IsFakeClient(attacker) && GetZombieClass(attacker) == 3 && IsPlayerAlive(attacker) && GetClientTeam(client) == 2)
	{
		new remaining_health = GetClientHealth(attacker);
		CPrintToChatAll("[{olive}TS 1v1{default}] {red}%N{default} had {green}%d{default} health remaining!", attacker, remaining_health);
		ForcePlayerSuicide(attacker);
		if (remaining_health == 1)
		{
			CPrintToChat(client, "[{olive}TS 1v1{default}] You don't have to be mad...");
		}
	}
}

public Action:Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(IsClientAndInGame(client)&&GetClientTeam(client) == 3 && !IsFakeClient(client) && GetZombieClass(client) == 3)
	{
		haspounced = false;
	}
}

public Action:PlayerLunge_Pounce_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	haspounced = true;
}

public Action:Event_PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));

	if (!IsClientAndInGame(attacker)||!haspounced)
		return;

	new damage = GetEventInt(event, "dmg_health");
	new zombie_class = GetZombieClass(attacker);

	if (GetClientTeam(attacker) == 3 && zombie_class != 5 && damage >= GetConVarInt(hCvarDmgThreshold))//承受設定的傷害
	{
		new remaining_health = GetClientHealth(attacker);
		CPrintToChatAll("[{olive}TS 1v1{default}] {red}%N{default} had {green}%d{default} health remaining!", attacker, remaining_health);

		ForcePlayerSuicide(attacker);    
		haspounced = false;
		
		if (remaining_health == 1)
		{
			CPrintToChat(victim, "[{olive}TS 1v1{default}] You don't have to be mad...");
		}
	}
}

public void Event_TankSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);
	if(client && IsClientInGame(client) && IsFakeClient(client))
	{
		CreateTimer(0.5, Timer_KillTank, userid, TIMER_FLAG_NO_MAPCHANGE);
	}
}

Action Timer_KillTank (Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if(client && IsClientInGame(client) && IsFakeClient(client) && GetClientTeam(client) == 3 && GetZombieClass(client) == 5)
	{
		ForcePlayerSuicide(client);
		CPrintToChatAll("[{olive}TS 1v1{default}] {green}Tank{default} has been killed!");
	}

	return Plugin_Continue;
}

stock GetZombieClass(client) return GetEntProp(client, Prop_Send, "m_zombieClass");

stock bool:IsClientAndInGame(index)
{
	if (index > 0 && index <= MaxClients)
	{
		return IsClientInGame(index);
	}
	return false;
}