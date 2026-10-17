#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

new Handle:tongue_drag_damage_interval;
new Handle:tongue_drag_damage_amount;
new Handle:tongue_drag_first_damage_interval;
new Handle:tongue_drag_first_damage;
new bool:g_bChoking[MAXPLAYERS+1];
// The pending timer of the victim's current drag chain; a chain whose timer is not this one is stale
// (a re-grab inside the first interval used to run two chains, double drag damage)
Handle g_hDragTimer[MAXPLAYERS+1];
new Float:ftongue_drag_damage_amount;
new Float:ftongue_drag_first_damage_interval;
new Float:ftongue_drag_first_damage_amount;
new Float:ftongue_drag_damage_interval;

native bool IsInPause();
public Plugin:myinfo =
{
	name = "L4D1 Smoker Drag Damage Interval",
	author = "Visor, l4d1 port by Harry",
	description = "Implements a native-like cvar that should've been there out of the box",
	version = "1.1",
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

public void OnMapEnd()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		delete g_hDragTimer[i];
	}
}

public void OnClientDisconnect(int client)
{
	delete g_hDragTimer[client];
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	for (new client=1; client<=MaxClients; client++)
	{
		g_bChoking[client] = false;
		delete g_hDragTimer[client];
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
	new userid = GetEventInt(event, "victim");
	new client = GetClientOfUserId(userid);
	//PrintToChatAll("%N Event_ChokeStop",client);
	g_bChoking[client] = false;

	// A ground choke ends mid-drag when a snagged victim breaks free (CTongue::UpdateGroundChoke ->
	// OnStopHangingFromTongue fires choke_end) and the same tongue keeps pulling. The drag chain stopped when it
	// saw the choke and only tongue_grab restarts it, so the rest of that drag did no damage. Resume it.
	if (!IsSurvivor(client)) return;

	int attacker = GetEntPropEnt(client, Prop_Send, "m_tongueOwner");
	if (!(attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker))) return;

	delete g_hDragTimer[client];

	DataPack hPack;
	g_hDragTimer[client] = CreateDataTimer(
			ftongue_drag_damage_interval,
			Timer_DragInterval,
			hPack);

	hPack.WriteCell(client);
	hPack.WriteCell(userid);
}

public OnTongueGrab(Handle:event, const String:name[], bool:dontBroadcast)
{
	int userid = GetEventInt(event, "victim");
	int client = GetClientOfUserId(userid);
	if (!client || !IsClientInGame(client)) return;

	//PrintToChatAll("%N got grab", client);

	delete g_hDragTimer[client];

	DataPack hPack;
	g_hDragTimer[client] = CreateDataTimer(
			ftongue_drag_first_damage_interval, 
			Timer_FirstDrag, 
			hPack);

	hPack.WriteCell(client);
	hPack.WriteCell(userid);
}

Action Timer_FirstDrag(Handle timer, DataPack hPack)
{
	hPack.Reset();
	int index = hPack.ReadCell();
	int userid = hPack.ReadCell();

	int client = GetClientOfUserId(userid);

	if (!IsSurvivor(client))
	{
		g_hDragTimer[index] = null;
		return Plugin_Continue;
	}
	
	int attacker = GetEntPropEnt(client, Prop_Send, "m_tongueOwner");
	if(!(attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker)) || IsSurvivorBeingChoked(client)) 
	{
		g_hDragTimer[client] = null;
		return Plugin_Continue;
	}

	//PrintToChatAll("%N Timer_FirstDrag",client);

	if(!IsInPause())
	{
		HurtEntity(client, attacker, ftongue_drag_first_damage_amount);

		DataPack hPack2;
		g_hDragTimer[client] = CreateDataTimer(
			ftongue_drag_damage_interval,  
			Timer_DragInterval, 
			hPack2);
		hPack2.WriteCell(client);
		hPack2.WriteCell(userid);
	}
	else
	{
		DataPack hPack2;
		g_hDragTimer[client] = CreateDataTimer(
			ftongue_drag_first_damage_interval, 
			Timer_FirstDrag, 
			hPack2);
		hPack2.WriteCell(client);
		hPack2.WriteCell(userid);
	}

	return Plugin_Continue;
}

Action Timer_DragInterval(Handle timer, DataPack hPack)
{
	hPack.Reset();
	int index = hPack.ReadCell();
	int userid = hPack.ReadCell();

	int client = GetClientOfUserId(userid);

	if (!IsSurvivor(client))
	{
		g_hDragTimer[index] = null;
		return Plugin_Continue;
	}

	int attacker = GetEntPropEnt(client, Prop_Send, "m_tongueOwner");
	if(!(attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker)) || IsSurvivorBeingChoked(client)) 
	{
		g_hDragTimer[client] = null;
		return Plugin_Continue;
	}

	//PrintToChatAll("%N Timer_DragInterval",client);

	if(!IsInPause())
	{
		HurtEntity(client, attacker, ftongue_drag_damage_amount);
	}

	DataPack hPack2;
	g_hDragTimer[client] = CreateDataTimer(
			ftongue_drag_damage_interval,  
			Timer_DragInterval, 
			hPack2);

	hPack2.WriteCell(index);
	hPack2.WriteCell(userid);

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