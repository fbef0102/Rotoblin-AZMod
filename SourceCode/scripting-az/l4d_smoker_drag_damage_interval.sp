#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

new Handle:tongue_drag_damage_interval;
new Handle:tongue_drag_damage_amount;
new Handle:tongue_drag_first_damage_interval;
new Handle:tongue_drag_first_damage;
new bool:g_bChoking[MAXPLAYERS+1];
new Float:ftongue_drag_damage_amount;
new Float:ftongue_drag_first_damage_interval;
new Float:ftongue_drag_first_damage_amount;
new Float:ftongue_drag_damage_interval;

public Plugin:myinfo =
{
	name = "L4D1 Smoker Drag Damage Interval",
	author = "Visor, l4d1 port by Harry",
	description = "Implements a native-like cvar that should've been there out of the box",
	version = "1.0",
	url = "https://github.com/Attano/Equilibrium"
};

public OnPluginStart()
{
	HookEvent("round_start", Event_RoundStart);
	HookEvent("choke_start",		Event_ChokeStart);
	HookEvent("choke_end",			Event_ChokeStop);
	HookEvent("tongue_grab", OnTongueGrab);

	tongue_drag_damage_amount = FindConVar("tongue_drag_damage_amount");
	tongue_drag_damage_interval = CreateConVar("tongue_drag_damage_interval", "1.0", "How often the drag does damage.");
	tongue_drag_first_damage_interval = CreateConVar("tongue_drag_first_damage_interval", "1.0", "First drag damage interval.");
	tongue_drag_first_damage = CreateConVar("tongue_drag_first_damage", "3.0", "First drag damage.");
	
	ftongue_drag_damage_amount = GetConVarFloat(tongue_drag_damage_amount);
	ftongue_drag_damage_interval = GetConVarFloat(tongue_drag_damage_interval);
	ftongue_drag_first_damage_interval = GetConVarFloat(tongue_drag_first_damage_interval);
	ftongue_drag_first_damage_amount = GetConVarFloat(tongue_drag_first_damage);

	HookConVarChange(tongue_drag_damage_interval, tongue_drag_damage_interval_ValueChanged);
	HookConVarChange(tongue_drag_first_damage_interval, tongue_drag_first_damage_interval_ValueChanged);
	HookConVarChange(tongue_drag_first_damage, tongue_drag_first_damageValueChanged);
	SetConVarInt(tongue_drag_damage_amount, 0);
}

public OnConfigsExecuted()
{
	ftongue_drag_damage_amount = GetConVarFloat(tongue_drag_damage_amount);
	SetConVarInt(tongue_drag_damage_amount, 0);
}

public tongue_drag_damage_interval_ValueChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	ftongue_drag_damage_interval = GetConVarFloat(tongue_drag_damage_interval);
}

public tongue_drag_first_damage_interval_ValueChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	ftongue_drag_first_damage_interval = GetConVarFloat(tongue_drag_first_damage_interval);
}

public tongue_drag_first_damageValueChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	ftongue_drag_first_damage_amount = GetConVarFloat(tongue_drag_first_damage);
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
    for (new client=1; client<=MaxClients; client++)
	{
		g_bChoking[client] = false;
	}
}

public Event_ChokeStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "victim"));
	//PrintToChatAll("%N Event_ChokeStart",client);
	g_bChoking[client] = true;
}

public Event_ChokeStop(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "victim"));
	//PrintToChatAll("%N Event_ChokeStop",client);
	g_bChoking[client] = false;
}

public OnTongueGrab(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "victim"));
	
	//PrintToChatAll("%N got grab",client);

	CreateTimer(
			ftongue_drag_first_damage_interval, 
			Timer_FirstDrag, 
			client, 
			TIMER_FLAG_NO_MAPCHANGE
	);
}

public Action:Timer_FirstDrag(Handle:timer, any:client)
{
	if (!IsSurvivor(client))
	{
		return Plugin_Stop;
	}
	new attacker = GetEntPropEnt(client, Prop_Send, "m_tongueOwner");
	if(!(attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker)) || IsSurvivorBeingChoked(client)) 
	{
		return Plugin_Stop;
	}

	//PrintToChatAll("%N Timer_FirstDrag",client);

	CreateTimer(
			ftongue_drag_damage_interval,  
			Timer_DragInterval, 
			client, 
			TIMER_FLAG_NO_MAPCHANGE
	);

	HurtEntity(client, attacker, ftongue_drag_first_damage_amount);

	return Plugin_Continue;
}

public Action:Timer_DragInterval(Handle:timer, any:client)
{
	if (!IsSurvivor(client))
	{
		return Plugin_Stop;
	}
	new attacker = GetEntPropEnt(client, Prop_Send, "m_tongueOwner");
	if(!(attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker)) || IsSurvivorBeingChoked(client)) 
	{
		return Plugin_Stop;
	}

	//PrintToChatAll("%N Timer_DragInterval",client);

	CreateTimer(
			ftongue_drag_damage_interval,  
			Timer_DragInterval, 
			client, 
			TIMER_FLAG_NO_MAPCHANGE
	);

	HurtEntity(client, attacker, ftongue_drag_damage_amount);

	return Plugin_Continue;
}

bool:IsSurvivorBeingChoked(client)
{
	return g_bChoking[client];
}

bool:IsSurvivor(client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2);
}

HurtEntity(victim, client, Float:damage)
{
	SDKHooks_TakeDamage(victim, client, client, damage, DMG_SLASH);
}