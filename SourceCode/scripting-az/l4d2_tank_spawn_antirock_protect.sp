#include <sourcemod>
#include <left4dhooks>

/**
 * l4d2_tank_spawn_antirock_protect "1.0.1" 變體插件
 * GetGameTime() 換成 GetEngineTime();
 */

float g_fSpawnTime[MAXPLAYERS + 1];

ConVar g_cvAntiRockProtectTime;

public Plugin myinfo = 
{
	name = "[L4D2] Tank Spawn Anti-Rock Protect",
	author = "B[R]UTUS",
	description = "Protects a Tank player from randomly rock attack at his spawn",
	version = "1.0.1-2024/6/19",
	url = "https://github.com/SirPlease/L4D2-Competitive-Rework"
}

public void OnPluginStart()
{
	HookEvent("tank_spawn", Event_TankSpawn, EventHookMode_Post);
	g_cvAntiRockProtectTime = CreateConVar("l4d2_antirock_protect_time", "1.5", "Protection time to avoid Tank throwing a rock by accident");
}

void Event_TankSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int tank = GetClientOfUserId(event.GetInt("userid"));
	g_fSpawnTime[tank] = GetEngineTime();
}

public Action L4D_OnCThrowActivate(int ability)
{
	int abilityOwner = GetEntPropEnt(ability, Prop_Send, "m_owner");

	if (abilityOwner != -1 && GetEngineTime() - g_fSpawnTime[abilityOwner] < g_cvAntiRockProtectTime.FloatValue)
		return Plugin_Handled;

	return Plugin_Continue;
}