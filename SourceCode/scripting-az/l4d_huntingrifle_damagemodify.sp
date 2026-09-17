#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

public Plugin myinfo = 
{
	name = "Modify Hunting Rifle Dmg",
	author = "HarryPotter",
	description = "Modify L4D Hunting Rifle Dmg",
	version = "1.4-2026/9/14",
	url = "http://steamcommunity.com/profiles/76561198111085776"
};

bool bLate;
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();

	if( test != Engine_Left4Dead )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1.");
		return APLRes_SilentFailure;
	}

	bLate = late;
	return APLRes_Success;
}

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

ConVar g_hHunterChest, g_hHunterStomach, g_hTankDamage;
float g_fHunterChest, g_fHunterStomach, g_fTankDamage;

int 
	g_iClientHitGroup[MAXPLAYERS+1];

public void OnPluginStart()
{
	g_hHunterChest = CreateConVar("l4d_huntingrifle_hunter_chest", "130", "Hunting Rifle Dmg to Hunter chest. (Default=90)", FCVAR_NOTIFY);
	g_hHunterStomach = CreateConVar("l4d_huntingrifle_hunter_stomach", "130", "Hunting Rifle Dmg to Hunter stomach. (Default=112.5)", FCVAR_NOTIFY);
	g_hTankDamage = CreateConVar("l4d_huntingrifle_tank_dmg", "110", "Hunting Rifle Dmg to Tank. (Default=90)", FCVAR_NOTIFY);

	GetCvars();
	g_hHunterChest.AddChangeHook(ConVarChange_Cvars);
	g_hHunterStomach.AddChangeHook(ConVarChange_Cvars);
	g_hTankDamage.AddChangeHook(ConVarChange_Cvars);

	if(bLate)
	{
		LateLoad();
	}
}

void LateLoad()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client))
			continue;

		OnClientPutInServer(client);
	}
}

void ConVarChange_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
    GetCvars();
}

void GetCvars()
{
	g_fHunterChest = g_hHunterChest.FloatValue;
	g_fHunterStomach = g_hHunterStomach.FloatValue;
	g_fTankDamage = g_hTankDamage.FloatValue;
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_TraceAttack, TraceAttack);
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage_Client);
}

Action TraceAttack(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
	if ( damage <= 0.0
		|| attacker <= 0 || attacker > MaxClients || !IsClientInGame(attacker) || GetClientTeam(attacker) != 2 
		|| GetClientTeam(victim) != 3 ) 
	{
		return Plugin_Continue;
	}

	//PrintToChatAll("TraceAttack - victim: %d, attacker: %d, inflictor: %d, damage: %.2f, damagetype: %d, ammotype: %d, \n"...
	//	"hitbox: %d, hitgroup: %d", 
	//	victim, attacker, inflictor, damage, damagetype, ammotype,
	//	hitbox, hitgroup);

	g_iClientHitGroup[victim] = hitgroup;

	return Plugin_Continue;
}

Action OnTakeDamage_Client(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if ( damage <= 0.0
		|| attacker <= 0 || attacker > MaxClients || !IsClientInGame(attacker) || GetClientTeam(attacker) != 2 
		|| GetClientTeam(victim) != 3) 
	{
		return Plugin_Continue;
	}

	//PrintToChatAll("OnTakeDamage - victim: %d, attacker: %d, inflictor: %d, damage: %.2f, damagetype: %d, weapon: %d, \n"...
	//	"hitgroup: %d", 
	//	victim, attacker, inflictor, damage, damagetype, weapon, g_iClientHitGroup[victim]);

	//在l4d1中, 玩家使用槍械攻擊時, attacker=inflictor, weapon=-1, damagetype有DMG_BULLET
	//在l4d1中, 玩家推死特感時, attacker=victim, weapon=-1, damagetype=DMG_CLUB
	static char sWeapon[32];
	if(attacker == inflictor && weapon == -1)
	{
		GetClientWeapon(attacker, sWeapon, sizeof sWeapon);
	}
	else
	{
		return Plugin_Continue;
	}

	//PrintToChatAll("OnTakeDamage - sWeapon: %s", sWeapon);

	if (strncmp(sWeapon, "weapon_hunting_rifle", 20, false) != 0) return Plugin_Continue;


	int zombieClass = GetEntProp(victim, Prop_Send, "m_zombieClass");
	if(zombieClass == ZC_HUNTER)
	{
		switch (g_iClientHitGroup[victim])
		{
			case HITGROUP_CHEST:
			{
				damage = g_fHunterChest;

				return Plugin_Changed;
			}
			case HITGROUP_STOMACH:
			{
				damage = g_fHunterStomach;

				return Plugin_Changed;
			}
		}
	}
	else if(zombieClass == ZC_TANK)
	{
		damage = g_fTankDamage;

		return Plugin_Changed;
	}	

	return Plugin_Continue;
}
