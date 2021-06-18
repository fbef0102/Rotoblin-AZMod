#pragma semicolon 1
#include <sourcemod>
#include <l4d_lib>

public Plugin:myinfo =
{
	name = "[L4D] Remove l4d1 special infected m2 Slowdown",
	author = "Harry Potter",
	description = "Removes the m2 scratch slow down from special infected",
	version = "1.0",
	url = "https://steamcommunity.com/id/AkemiHomuraGoddess/"
};

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon, &subtype, &cmdnum, &tickcount, &seed, mouse[2])
{
	if (IsClientInGame(client) && GetClientTeam(client) == 3 && IsPlayerAlive(client) &&!IsPlayerGhost(client))
	{
		if(buttons & IN_ATTACK2)
		{
			PrintToChatAll("%N fixed move - %f %f %f %f %d %d",client,GetEntPropFloat(client, Prop_Send, "m_vecVelocity[0]"),GetEntPropFloat(client, Prop_Send, "m_vecVelocity[1]"),GetEntPropFloat(client, Prop_Send, "m_vecVelocity[2]"),GetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue"),GetEntProp(client, Prop_Send, "m_bAllowAutoMovement"),GetEntProp(client, Prop_Send, "m_airMovementRestricted"));
		}
	}
	return Plugin_Continue;	
}