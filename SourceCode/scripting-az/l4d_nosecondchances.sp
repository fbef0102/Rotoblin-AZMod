#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define TEAM_INFECTED 3
#define ZC_TANK 5

static const char L4D1_SI_Victim_NetProps[][] = {
	"",
	"m_tongueVictim",	// Smoker
	"",
	"m_pounceVictim",	// Hunter
	"",
	""
};

ConVar g_hBotKickDelay = null;

public Plugin myinfo = 
{
	name = "L4D1 No Second Chances",
	author = "Visor, Jacob, A1m`, l4d1 port by Harry",
	description = "Previously human-controlled SI bots with a cap won't die",
	version = "1.5",
	url = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

public void OnPluginStart()
{
	HookEvent("player_bot_replace", PlayerBotReplace); // bot replaces player
	
	g_hBotKickDelay = CreateConVar("bot_kick_delay", "0.1", "How long should we wait before kicking infected bots?", _, true, 0.0, true, 30.0);
}

public void PlayerBotReplace(Event hEvent, const char[] eName, bool dontBroadcast)
{
	int iUserID = hEvent.GetInt("bot");
	int iBot = GetClientOfUserId(iUserID);

	if (IsClientInGame(iBot) && GetClientTeam(iBot) == TEAM_INFECTED && IsFakeClient(iBot)) {
		float fDelay = g_hBotKickDelay.FloatValue;
		if (fDelay >= 0.0) {
			CreateTimer(fDelay, Timer_KillBotDelay, iUserID, TIMER_FLAG_NO_MAPCHANGE);
		} else if (ShouldBeKicked(iBot)) {
			ForcePlayerSuicide(iBot);
			//CreateTimer(1.0, _KickInfectedBot, iUserID);
		}
	}
}

bool ShouldBeKicked(int iBot) //When a spawned Infected Player disconnects, changes team or becomes Tank the SI will instantly get killed unless it has someone capped.
{
	int iZombieClassType = GetEntProp(iBot, Prop_Send, "m_zombieClass");
	
	if (iZombieClassType == ZC_TANK) return false;

	if (strlen(L4D1_SI_Victim_NetProps[iZombieClassType]) != 0 && GetEntPropEnt(iBot, Prop_Send, L4D1_SI_Victim_NetProps[iZombieClassType]) != -1) {
		return false;
	}

	return true;
}

public Action Timer_KillBotDelay(Handle hTimer, any iUserID)
{
	int iBot = GetClientOfUserId(iUserID);
	if (iBot > 0 && IsPlayerAlive(iBot) && ShouldBeKicked(iBot)) {
		ForcePlayerSuicide(iBot);
		//CreateTimer(1.0, _KickInfectedBot, iUserID);
	}

	return Plugin_Continue;
}

public Action _KickInfectedBot(Handle timer, any iUserID)
{
	int iBot = GetClientOfUserId(iUserID);
	if (!iBot || !IsClientInGame(iBot) || !IsFakeClient(iBot)) return Plugin_Continue;
	
	KickClient(iBot, "Kicked infected bot");
	
	return Plugin_Continue;
}

