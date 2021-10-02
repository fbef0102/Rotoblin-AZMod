#pragma semicolon 1

#include <sourcemod>
#include <multicolors>
#include <l4d_lib>

new Handle:cvarSmallRefill;

public Plugin:myinfo = {
	name = "L4D2 Tank Hittable Refill",
	author = "Sir",
	version = "1",
	description = "Refill Tank's frustration whenever a hittable hits a Survivor"
};

public OnPluginStart() 
{
	cvarSmallRefill = CreateConVar("l4d_tank_hittable_small", "0", "Do we allow Small hittables such as Garbage Bins and Tables to refill frustration?");
	HookEvent("player_hurt", PlayerHurt);
	HookEvent("player_incapacitated", PlayerIncap);
}


public PlayerHurt(Handle:event, String:name[], bool:dontBroadcast) 
{
	new Victim = GetClientOfUserId(GetEventInt(event, "userid"));
	new Attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	new dmg = GetEventInt(event, "dmg_health");

	//Is player actually a Tank?
	if (!CheckForTank(Attacker, Victim)) return;

	//Do we allow small hittables?
	if (dmg < 5 && GetConVarInt(cvarSmallRefill) == 0) return;

	//Refill that Frustration!
	SetTankFrustration(Attacker, 100);
}

public PlayerIncap(Handle:event, String:name[], bool:dontBroadcast) 
{
	new Victim = GetClientOfUserId(GetEventInt(event, "userid"));
	new Attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

	//Is player actually a Tank?
	if (!CheckForTank(Attacker, Victim)) return;

	//Do we allow small hittables? -- prop_physics always does 100 dmg to incapped, even small hittables.
	//if (dmg < 5 && GetConVarInt(cvarSmallRefill) == 0) return;

	//Refill that Frustration!
	SetTankFrustration(Attacker, 100);
}

bool:IsLegitClient(client) 
{
    if (client&&IsClientConnected(client)&& IsClientInGame(client))
    {
        return true;
    }
    
    return false;
}

bool:CheckForTank(Attacker, Victim)
{
	if (!IsLegitClient(Victim) || !IsLegitClient(Attacker)) return false;
	if (GetClientTeam(Victim) != 2 || GetClientTeam(Attacker) != 3) return false;
	if (GetEntProp(Attacker, Prop_Send, "m_zombieClass") != 5) return false;
	return true;
}
