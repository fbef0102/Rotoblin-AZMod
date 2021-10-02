#include <sourcemod>

#pragma semicolon 1

#define ZC_SMOKER               1
#define ZC_BOOMER               2
#define ZC_HUNTER               3
#define ZC_TANK                 5
#define HITGROUP_GENERIC 0
#define HITGROUP_HEAD 1
#define HITGROUP_CHEST 2
#define HITGROUP_STOMACH 3
#define HITGROUP_LEFTARM 4
#define HITGROUP_RIGHTARM 5
#define HITGROUP_LEFTLEG 6
#define HITGROUP_RIGHTLEG 7 

public Plugin:myinfo = 
{
	name = "Modify Hunting Rifle Dmg",
	author = "乘風, HarryPotter",
	description = "Modify L4D Hunting Rifle Dmg",
	version = "1.3",
	url = "http://steamcommunity.com/profiles/76561198111085776"
};

ConVar g_hHunterChestMultiplier, g_hHunterStomachMultiplier, g_hTankDamage;
public OnPluginStart()
{
	g_hHunterChestMultiplier = CreateConVar("l4d_huntingrifle_hunter_chest_multi", "2.8", "Multiplier Hunting Rifle Dmg to Hunter chest. (Default=1.0)", FCVAR_NOTIFY);
	g_hHunterStomachMultiplier = CreateConVar("l4d_huntingrifle_hunter_Stomach_multi", "1.5", "Multiplier Hunting Rifle Dmg to Hunter chest. (Default=1.0)", FCVAR_NOTIFY);
	g_hTankDamage = CreateConVar("l4d_huntingrifle_tank_dmg", "125", "Hunting Rifle Dmg to Tank. (Default=90)", FCVAR_NOTIFY);
	AutoExecConfig(true, "l4d_huntingrifle_damagemodify");

	GetCvars();
	g_hHunterChestMultiplier.AddChangeHook(ConVarChange_Cvars);
	g_hHunterStomachMultiplier.AddChangeHook(ConVarChange_Cvars);
	g_hTankDamage.AddChangeHook(ConVarChange_Cvars);
	
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Pre);	
}

public void ConVarChange_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
    GetCvars();
}

float g_fHunterChestMultiplier, g_fHunterStomachMultiplier;
int g_iTankDamage;
GetCvars()
{
	g_fHunterChestMultiplier = g_hHunterChestMultiplier.FloatValue;
	g_fHunterStomachMultiplier = g_hHunterStomachMultiplier.FloatValue;
	g_iTankDamage = g_hTankDamage.IntValue;
}

public Action:Event_PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast) 
{
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));	
	new dmg = GetEventInt(event, "dmg_health");
	new eventhealth = GetEventInt(event, "health");	
	new dehealth = eventhealth + dmg;
	
	if (attacker == 0 || victim == 0 || !IsClientInGame(attacker) || !IsClientInGame(victim)
		|| GetClientTeam(attacker) != 2 || GetClientTeam(victim) != 3 ) {
		return Plugin_Continue;
	}

	decl String:weapon[16];
	GetEventString(event, "weapon", weapon, sizeof(weapon));	
	if (strcmp(weapon, "hunting_rifle") != 0) return Plugin_Continue;

	int zombieClass = GetEntProp(victim, Prop_Send, "m_zombieClass");
	int hitgroup = GetEventInt(event, "hitgroup");
	if(zombieClass == 3)
	{
		switch (hitgroup)
		{
			case HITGROUP_CHEST:
			{
				dmg = RoundToNearest(dmg*g_fHunterChestMultiplier);
			}
			case HITGROUP_STOMACH:
			{
				dmg = RoundToNearest(dmg*g_fHunterStomachMultiplier);
			}
		}
	}	

	if(zombieClass == 5)
	{
		if( 1 <= hitgroup && hitgroup <= 7)
			dmg = g_iTankDamage;
	}	

	eventhealth = dehealth - dmg;
	if (eventhealth < 0)
		eventhealth = 0;

	SetEntProp(victim, Prop_Data, "m_iHealth", eventhealth);
	SetEventInt(event, "dmg_health", dmg);

	return Plugin_Changed;	
}	
	

