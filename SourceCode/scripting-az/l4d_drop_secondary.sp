#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <l4d_weapon_stocks>

#define MAXENTITIES 2048
int g_PlayerSecondaryWeapons[MAXPLAYERS + 1];
int g_PlayerPrimaryWeapons[MAXPLAYERS + 1];
bool g_bPlayerPickUpWeapon;

native bool IsInReady();//From l4dready

public Plugin myinfo =
{
	name        = "L4D Drop Secondary",
	author      = "Jahze, Visor,l4d1 modify by Harry",
	version     = "2.4",
	description = "Survivor players will drop their secondary weapon when they die + Survivor players won't drop their weapons when ready mode",
	url         = "https://github.com/Attano/Equilibrium"
};

public void OnPluginStart() 
{
	HookEvent("round_start", OnRoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_use", OnPlayerUse, EventHookMode_Post);
	HookEvent("player_bot_replace", OnBotSwap);
	HookEvent("bot_player_replace", OnBotSwap);
	HookEvent("player_death", OnPlayerDeath, EventHookMode_Pre);
	HookEvent("player_spawn", OnPlayerSpawn, EventHookMode_Post);
}

public void OnMapStart()
{
	g_bPlayerPickUpWeapon = false;
}

public Action OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 0; i <= MAXPLAYERS; i++) 
	{
		g_PlayerSecondaryWeapons[i] = -1;
		g_PlayerPrimaryWeapons[i] = -1;
	}

	g_bPlayerPickUpWeapon = false;
}

public Action OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(IsSurvivor(client))
	{
		int weapon = GetPlayerWeaponSlot(client, 1);
		if(weapon > 0 && L4D2_GetWeaponId(weapon)!=L4D2WeaponId_None)
			g_PlayerSecondaryWeapons[client] = weapon;
		
		int primaryweapon = GetPlayerWeaponSlot(client, 0);
		if(primaryweapon > 0 && L4D2_GetWeaponId(primaryweapon)!=L4D2WeaponId_None)
			g_PlayerPrimaryWeapons[client] = primaryweapon;
	}
	return Plugin_Continue;
}

public Action OnPlayerUse(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsSurvivor(client)) 
	{
		int entity = event.GetInt("targetid"); // What we're attempting to use/pickup
		if( entity && IsValidEntity(entity) )
		{
			char g_szBuffer[8];
			GetEdictClassname(entity, g_szBuffer, sizeof(g_szBuffer)); // Verify it's a weapon
			//PrintToChatAll("OnPlayerUse: %s", g_szBuffer);
			if( strncmp(g_szBuffer, "weapon_", 7) == 0 )
			{
				int weapon = GetPlayerWeaponSlot(client, 1);
				if(weapon > 0 && L4D2_GetWeaponId(weapon)!=L4D2WeaponId_None)
					g_PlayerSecondaryWeapons[client] = weapon;
				
				int primaryweapon = GetPlayerWeaponSlot(client, 0);
				if(primaryweapon > 0 && L4D2_GetWeaponId(primaryweapon)!=L4D2WeaponId_None)
					g_PlayerPrimaryWeapons[client] = primaryweapon;

				g_bPlayerPickUpWeapon = true;
			}
		}
	}
	return Plugin_Continue;
}

public Action OnBotSwap(Event event, const char[] name, bool dontBroadcast)
{
	int bot = GetClientOfUserId(GetEventInt(event, "bot"));
	int player = GetClientOfUserId(GetEventInt(event, "player"));
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

public Action OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsSurvivor(client)) 
	{
		int weapon = g_PlayerSecondaryWeapons[client];
		int primaryweapon = g_PlayerPrimaryWeapons[client];
		if(IsInReady())
		{
			if(weapon > 0 && L4D2_GetWeaponId(weapon) != L4D2WeaponId_None)
				SafelyRemoveEdict(weapon);
			if(primaryweapon > 0 && L4D2_GetWeaponId(primaryweapon) != L4D2WeaponId_None)
				SafelyRemoveEdict(primaryweapon);
		}
		else
		{
			if(weapon!=-1 && IsValidEntity(weapon))
				SetEntPropEnt(weapon, Prop_Data, "m_hOwner",client);
			if(weapon > 0 && L4D2_GetWeaponId(weapon) != L4D2WeaponId_None && client == GetWeaponOwner(weapon) )
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

public void OnEntityCreated (int entity, const char[] classname)
{	
	if(!IsInReady() || !g_bPlayerPickUpWeapon) return;
	
	//PrintToChatAll("%d classname: %s",entity,classname);
	
	if(StrEqual(classname,"weapon_pistol"))
	{
		CreateTimer(0.1, DelayCheck, EntIndexToEntRef(entity));
	}
}

public Action DelayCheck(Handle timer, int ref)
{
	int entity = EntRefToEntIndex(ref);

	if(entity == INVALID_ENT_REFERENCE)
	{
		return;
	}

	for (int i = 0; i <= MAXPLAYERS; i++) 
	{
		if(IsSurvivor(i) && g_PlayerSecondaryWeapons[i] == entity)
			return;
	}

	SafelyRemoveEdict(entity);
}

int GetWeaponOwner(int weapon)
{
	return GetEntPropEnt(weapon, Prop_Data, "m_hOwner");
}

bool IsClientIndex(int client)
{
	return (client > 0 && client <= MaxClients);
}

bool IsSurvivor(int client)
{
	return (IsClientIndex(client) && IsClientInGame(client) && GetClientTeam(client) == 2);
}

stock bool SafelyRemoveEdict(int entity)
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

public void OnClientPutInServer(int client)
{
	g_PlayerSecondaryWeapons[client] = -1;
	g_PlayerPrimaryWeapons[client] = -1;
}

public void OnClientDisconnect(int client)
{
	g_PlayerSecondaryWeapons[client] = -1;
	g_PlayerPrimaryWeapons[client] = -1;
}