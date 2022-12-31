#pragma semicolon 1
#pragma newdecls required //強制1.7以後的新語法
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

int g_PlayerPrimaryWeapons[MAXPLAYERS + 1];
int g_PlayerSecondaryWeapons[MAXPLAYERS + 1]; 		/* slot1 entity */

native bool IsInReady();//From l4dready

public Plugin myinfo =
{
	name		= "L4D1 Drop Secondary",
	author		= "Jahze, Visor, NoBody & HarryPotter",
	version		= "2.5",
	description	= "Survivor players will drop their secondary weapon when they die",
	url			= "https://steamcommunity.com/profiles/76561198026784913/"
};

bool bLate;
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) 
{
	EngineVersion test = GetEngineVersion();
	
	if( test != Engine_Left4Dead )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead .");
		return APLRes_SilentFailure;
	}

	bLate = late;
	return APLRes_Success; 
}

public void OnPluginStart()
{
	HookEvent("player_spawn",			Event_PlayerSpawn,	EventHookMode_PostNoCopy);
	HookEvent("player_death", 			OnPlayerDeath, EventHookMode_Pre);

	if (bLate)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				OnClientPutInServer(i);
			}
		}
	}
}

public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_WeaponEquipPost, OnWeaponEquipPost);
}

public void OnClientDisconnect(int client)
{
	if(!IsClientInGame(client)) return;

	clear(client);
}

public void OnWeaponEquipPost(int client, int weapon)
{
	if (client <= 0 || client > MaxClients || !IsClientInGame(client))
		return;

	GetSlots(client);
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) 
{
	CreateTimer(0.1, ColdDown, event.GetInt("userid"));
}

public Action ColdDown(Handle timer, int client)
{
	client = GetClientOfUserId(client);
	if(client && IsClientInGame(client))
	{
		GetSlots(client);
	}

	return Plugin_Continue;
}

public void OnPlayerDeath(Event event, const char[] name, bool dontBroadcast) 
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if(client == 0 || !IsClientInGame(client) || GetClientTeam(client) != 2)
	{
		clear(client);
		return;
	}

	if(IsInReady())
	{
		if(IsValidEntRef(g_PlayerPrimaryWeapons[client]))
		{
			RemovePlayerItem(client, g_PlayerPrimaryWeapons[client]);
			RemoveEntity(g_PlayerPrimaryWeapons[client]);
		}

		if(IsValidEntRef(g_PlayerSecondaryWeapons[client]))
		{
			RemovePlayerItem(client, g_PlayerSecondaryWeapons[client]);
			RemoveEntity(g_PlayerSecondaryWeapons[client]);
		}

		clear(client);
		return;
	}
	
	int weapon = EntRefToEntIndex(g_PlayerSecondaryWeapons[client]);
	
	if(weapon == INVALID_ENT_REFERENCE)
	{
		g_PlayerSecondaryWeapons[client] = -1;
		return;
	}
	
	char sWeapon[32];
	int clip;
	GetEntityClassname(weapon, sWeapon, 32);
	
	int entity; 
	float origin[3];
	float ang[3];
	GetClientEyePosition(client,origin);
	GetClientEyeAngles(client, ang);
	GetAngleVectors(ang, ang, NULL_VECTOR,NULL_VECTOR);
	NormalizeVector(ang,ang);
	ScaleVector(ang, 90.0);

	if (strcmp(sWeapon, "weapon_pistol") == 0)
	{
		entity = CreateEntityByName(sWeapon);
		if(entity == -1)
		{
			clear(client);
			return;
		}

		clip = GetEntProp(weapon, Prop_Send, "m_iClip1");
		
		if (GetEntProp(weapon, Prop_Send, "m_isDualWielding") > 0)
		{
			int entity2 = CreateEntityByName(sWeapon); //second pistol
			if(entity2 == -1)
			{
				clear(client);
				return;
			}
			
			TeleportEntity(entity2, origin, NULL_VECTOR, ang);
			DispatchSpawn(entity2);
			clip = GetEntProp(weapon, Prop_Send, "m_iClip1");
			if(clip - 15 <= 0) SetEntProp(entity2, Prop_Send, "m_iClip1", 0);
			else clip = clip - 15;
		}
	}
	else	//unknow weapon
	{
		clear(client);
		LogError("%N has unknow secondary weapon: %s", client, sWeapon);
		return;
	}

	RemovePlayerItem(client, weapon);
	RemoveEntity(weapon);
	
	TeleportEntity(entity, origin, NULL_VECTOR, ang);
	DispatchSpawn(entity);

	SetEntProp(entity, Prop_Send, "m_iClip1", clip);

	clear(client);
}

stock bool IsIncapacitated(int client)
{
	return view_as<bool>(GetEntProp(client, Prop_Send, "m_isIncapacitated"));
}

void clear(int client)
{
	g_PlayerPrimaryWeapons[client] = -1;
	g_PlayerSecondaryWeapons[client] = -1;
}

void GetSlots(int client)
{
	if(GetClientTeam(client) != 2 || !IsPlayerAlive(client))
	{
		clear(client);
		return;
	}

	//if (IsIncapacitated(client)) //倒地不列入
	//	return;

	int slot0_weapon = GetPlayerWeaponSlot(client, 0);
	if(slot0_weapon == -1)
	{
		g_PlayerPrimaryWeapons[client] = -1;
	}
	else
	{
		g_PlayerPrimaryWeapons[client] = EntIndexToEntRef(slot0_weapon);
	}

	int slot1_weapon = GetPlayerWeaponSlot(client, 1);
	if(slot1_weapon == -1)
	{
		g_PlayerSecondaryWeapons[client] = -1;
	}
	else
	{
		g_PlayerSecondaryWeapons[client] = EntIndexToEntRef(slot1_weapon);
	}

	//PrintToChatAll("%N slot 0 weapon is %d", client, slot0_weapon);
	//PrintToChatAll("%N slot 1 weapon is %d", client, slot1_weapon);
}

bool IsValidEntRef(int entity)
{
	if( entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE)
		return true;
	return false;
}
