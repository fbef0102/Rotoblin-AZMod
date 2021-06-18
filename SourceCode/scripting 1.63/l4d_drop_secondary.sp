#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <l4d_weapon_stocks>

new g_PlayerSecondaryWeapons[MAXPLAYERS + 1];
new g_PlayerPrimaryWeapons[MAXPLAYERS + 1];
#define MAXENTITIES 2048
native IsInReady();//From l4dready
static playerdeath = false;

public Plugin:myinfo =
{
	name        = "L4D Drop Secondary",
	author      = "Jahze, Visor,l4d1 modify by Harry",
	version     = "2.3",
	description = "Survivor players will drop their secondary weapon when they die + Survivor players won't drop their weapons when ready mode",
	url         = "https://github.com/Attano/Equilibrium"
};

public OnPluginStart() 
{
	HookEvent("round_start", EventHook:OnRoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_use", OnPlayerUse, EventHookMode_Post);
	HookEvent("player_bot_replace", OnBotSwap);
	HookEvent("bot_player_replace", OnBotSwap);
	HookEvent("player_death", OnPlayerDeath, EventHookMode_Post);
	HookEvent("player_spawn", OnPlayerSpawn, EventHookMode_Post);
}

public OnRoundStart() 
{
	playerdeath = false;
	for (new i = 0; i <= MAXPLAYERS; i++) 
	{
		g_PlayerSecondaryWeapons[i] = -1;
		g_PlayerPrimaryWeapons[i] = -1;
	}
}

public Action:OnPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(IsSurvivor(client))
	{
		new weapon = GetPlayerWeaponSlot(client, _:L4DWeaponSlot_Secondary);
		if(IdentifyWeapon(weapon)!=WEPID_NONE)
			g_PlayerSecondaryWeapons[client] = weapon;
		
		new primaryweapon = GetPlayerWeaponSlot(client, _:L4DWeaponSlot_Primary);
		if(IdentifyWeapon(primaryweapon)!=WEPID_NONE)
			g_PlayerPrimaryWeapons[client] = primaryweapon;
	}
	return Plugin_Continue;
}

public Action:OnPlayerUse(Handle:event, const String:name[], bool:dontBroadcast) 
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsSurvivor(client)) 
	{
		new weapon = GetPlayerWeaponSlot(client, _:L4DWeaponSlot_Secondary);
		if(IdentifyWeapon(weapon)!=WEPID_NONE)
			g_PlayerSecondaryWeapons[client] = weapon;
		
		new primaryweapon = GetPlayerWeaponSlot(client, _:L4DWeaponSlot_Primary);
		if(IdentifyWeapon(primaryweapon)!=WEPID_NONE)
			g_PlayerPrimaryWeapons[client] = primaryweapon;
		playerdeath = true;
	}
	return Plugin_Continue;
}

public Action:OnBotSwap(Handle:event, const String:name[], bool:dontBroadcast) 
{
	new bot = GetClientOfUserId(GetEventInt(event, "bot"));
	new player = GetClientOfUserId(GetEventInt(event, "player"));
	if (IsClientIndex(bot) && IsClientIndex(player)) 
	{
		if (StrEqual(name, "player_bot_replace")) 
		{
			g_PlayerSecondaryWeapons[bot] = g_PlayerSecondaryWeapons[player];
			g_PlayerSecondaryWeapons[player] = -1;
			g_PlayerPrimaryWeapons[bot] = g_PlayerPrimaryWeapons[player];
			g_PlayerPrimaryWeapons[player] = -1;
			
		}
		else 
		{
			g_PlayerSecondaryWeapons[player] = g_PlayerSecondaryWeapons[bot];
			g_PlayerSecondaryWeapons[bot] = -1;
			g_PlayerPrimaryWeapons[player] = g_PlayerPrimaryWeapons[bot];
			g_PlayerPrimaryWeapons[bot] = -1;
		}
	}
	return Plugin_Continue;
}

public Action:OnPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast) 
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsSurvivor(client)) 
	{
		new weapon = g_PlayerSecondaryWeapons[client];
		new primaryweapon = g_PlayerPrimaryWeapons[client];
		if(IsInReady())
		{
			if(IdentifyWeapon(weapon) != WEPID_NONE)
				SafelyRemoveEdict(weapon);
			if(IdentifyWeapon(primaryweapon) != WEPID_NONE)
				SafelyRemoveEdict(primaryweapon);
		}
		else
		{
			if(weapon!=-1 && IsValidEntity(weapon))
				SetEntPropEnt(weapon, Prop_Data, "m_hOwner",client);
			if(IdentifyWeapon(weapon) != WEPID_NONE && client == GetWeaponOwner(weapon) )
			{
				SDKHooks_DropWeapon(client, weapon);
			}
		}
		g_PlayerSecondaryWeapons[client] = -1;
		g_PlayerPrimaryWeapons[client] = -1;
		return Plugin_Continue;
		
	}
	return Plugin_Continue;
}

public OnEntityCreated(entity, const String:classname[])
{
	if(!IsInReady()||!playerdeath) return;
	
	//PrintToChatAll("%d classname: %s",entity,classname);
	
	if(StrEqual(classname,"weapon_pistol"))
	{
		CreateTimer(0.1, DelayCheck, entity);
	}
}

public Action:DelayCheck(Handle:timer, any:entity)
{
	for (new i = 0; i <= MAXPLAYERS; i++) 
	{
		if(IsSurvivor(i) && g_PlayerSecondaryWeapons[i] == entity)
			return;
	}
	SafelyRemoveEdict(entity);
}


GetWeaponOwner(weapon)
{
	return GetEntPropEnt(weapon, Prop_Data, "m_hOwner");
}

bool:IsClientIndex(client)
{
	return (client > 0 && client <= MaxClients);
}

bool:IsSurvivor(client)
{
	return (IsClientIndex(client) && IsClientInGame(client) && GetClientTeam(client) == 2);
}

stock bool:SafelyRemoveEdict(entity)
{
	if (entity == INVALID_ENT_REFERENCE || entity < 0 || entity > MAXENTITIES || !IsValidEntity(entity))
	{
		return false;
	}

	// Try and use the entity's kill input first.  If that doesn't work, fall back on SafelyRemoveEdict.
	// AFAIK, we should always try to use Kill, as I've noticed problems when calling SafelyRemoveEdict (ents sticking around after deletion).
	// This could be down to my own idiocy, but ... still.
	if(!AcceptEntityInput(entity, "Kill"))
	{
		SafelyRemoveEdict(entity);
	}

	return true;
}

public OnClientPutInServer(client)
{
	g_PlayerSecondaryWeapons[client] = -1;
	g_PlayerPrimaryWeapons[client] = -1;
}

public OnClientDisconnect(client)
{
	g_PlayerSecondaryWeapons[client] = -1;
	g_PlayerPrimaryWeapons[client] = -1;
}

public OnMapEnd()
{
	playerdeath = false;
}

public OnMapStart()
{
	playerdeath = false;
}