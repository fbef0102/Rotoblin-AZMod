#pragma semicolon 1
#include <sourcemod>
#include <sdktools>

public Plugin:myinfo =
{
	name = "[L4D] Minigun survivor launcher fix",
	author = "Accelerator",
	description = "Minigun survivor launcher fix",
	version = "1.0",
	url = "http://core-ss.org"
};

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if ((buttons & IN_USE) && (buttons & IN_JUMP))
	{
		new ent = GetEntPropEnt(client, Prop_Send, "m_hUseEntity");
		if (ent < 1) return Plugin_Continue;
		if (!IsValidEdict(ent)) return Plugin_Continue;
		
		decl String:classname[24];
		GetEdictClassname(ent, classname, sizeof(classname));		
		
		if (StrEqual(classname, "prop_minigun") || 
		StrEqual(classname, "prop_minigun_l4d1") ||
		StrEqual(classname, "prop_mounted_machine_gun"))
		{
			buttons ^= IN_JUMP;
		}
	}
	return Plugin_Continue;
}