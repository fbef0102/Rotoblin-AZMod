#define PLUGIN_VERSION "1.3"

#include <sourcemod>

static Handle:hPounceDmg, Handle:hMaxPounceDist, Handle:hMinPounceDist, Handle:hMaxPounceDmg;

public Plugin:myinfo =
{
	name = "PounceUncap",
	author = "n0limit, raziEiL [disawar1],modify by Harry",
	description = "Makes it easy to properly uncap hunter pounces",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=96546"
}

public OnPluginStart()
{
	// Get relevant cvars
	hMaxPounceDmg = FindConVar("z_hunter_max_pounce_bonus_damage");
	hMaxPounceDist = FindConVar("z_pounce_damage_range_max");
	hMinPounceDist = FindConVar("z_pounce_damage_range_min");

	//Create convar to set
	hPounceDmg = CreateConVar("pounceuncap_maxdamage","25","Sets the new maximum hunter pounce damage.",FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY,true,2.0);
	CreateConVar("pounceuncap_version",PLUGIN_VERSION,"Current version of the plugin",FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY);

	HookConVarChange(hPounceDmg, OnMaxDamageChange);
	HookConVarChange(hMaxPounceDmg, OnMaxDamageChange);
	HookConVarChange(hMaxPounceDist, OnMaxDamageChange);
	ChangeDamage(GetConVarInt(hPounceDmg));
}

public OnMaxDamageChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	if (!StrEqual(oldVal, newVal))
	{
		new MaxPounceDmg = GetConVarInt(hPounceDmg);
		ChangeDamage(MaxPounceDmg);
	}
	
}

ChangeDamage(dmg)
{
	//1 pounce damage per 28 in game units
	//SetConVarInt(hMaxPounceDist, ((28 * dmg) + GetConVarInt(hMinPounceDist)));
	//Always set minus 1, game adds 1 when dist >= range_max
	//SetConVarInt(hMaxPounceDmg, --dmg);
	
	SetConVarInt(FindConVar("z_pounce_damage_range_max"), ((28 * dmg) + GetConVarInt(hMinPounceDist)));
	SetConVarInt(FindConVar("z_hunter_max_pounce_bonus_damage"), --dmg);
}