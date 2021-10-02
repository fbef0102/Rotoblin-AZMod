#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#define WP_PAIN_PILLS 12
#define PILL_INDEX 0

new iBotUsedCount[1][MAXPLAYERS + 1];
static Handle:hCvarFlags;
static g_bCvarcontrolvalue;

public Plugin:myinfo = 
{
	name = "Simplified Bot Pop Stop",
	author = "Stabby & CanadaRox, L4D1 port by Harry",
	description = "Removes pills from bots if they try to use them and restores them when a human takes over.",
	version = "1.4",
	url = "no url"
}

public OnPluginStart()
{
	HookEvent("weapon_fire",Event_WeaponFire);
	HookEvent("bot_player_replace",Event_PlayerJoined);
	HookEvent("round_start",Event_RoundStart,EventHookMode_PostNoCopy);
	
	hCvarFlags = CreateConVar("no_bot_use_pills", "1", "Removes pills from bots if they try to use them and restores them when a human takes over.", _, true, 0.0, true, 1.0);
	g_bCvarcontrolvalue = GetConVarInt(hCvarFlags);
	HookConVarChange(hCvarFlags, OnCvarChange_control);
}

// Take pills from the bot before they get used
public Event_WeaponFire(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(g_bCvarcontrolvalue == 0) return;
	
	new client   = GetClientOfUserId(GetEventInt(event,"userid"));
	new weaponid = GetEventInt(event,"weaponid");
	
	//PrintToChatAll("%N used weaponid:%d",client,weaponid);
	if (IsFakeClient(client))
	{
		if (weaponid == WP_PAIN_PILLS)
		{
			iBotUsedCount[PILL_INDEX][client]++;
			RemovePlayerItem(client, GetPlayerWeaponSlot(client,4));
		}
	}
}

// Give the human player the pills back when they join
public Event_PlayerJoined(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(g_bCvarcontrolvalue == 0) return;
	
	new leavingBot = GetClientOfUserId(GetEventInt(event,"bot"));

	if (iBotUsedCount[PILL_INDEX][leavingBot] > 0)
	{
		RestoreItems(GetClientOfUserId(GetEventInt(event, "player")), leavingBot);
		iBotUsedCount[PILL_INDEX][leavingBot] = 0;
	}
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	for (new j = 0; j < MAXPLAYERS + 1; j++)
	{
		iBotUsedCount[0][j] = 0;
	}
}

RestoreItems(client, leavingBot)
{
	// manually create entity and the equip it since GivePlayerItem() doesn't work in L4D2
	decl entity;
	decl Float:clientOrigin[3];
	new currentWeapon = GetPlayerWeaponSlot(client, 4);
	for (new j = iBotUsedCount[0][leavingBot]; j > 0; j--)
	{
		entity = CreateEntityByName("weapon_pain_pills");
		GetClientAbsOrigin(client, clientOrigin);
		clientOrigin[2] += 10.0;
		TeleportEntity(entity, clientOrigin, NULL_VECTOR, NULL_VECTOR);
		DispatchSpawn(entity);
		if (currentWeapon == -1)
		{
			EquipPlayerWeapon(client, entity);
			currentWeapon = entity;
		}
	}
	
}

public OnCvarChange_control(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (!StrEqual(oldValue, newValue))
	{
		g_bCvarcontrolvalue = StringToInt(newValue);
	}
}