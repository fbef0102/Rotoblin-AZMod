#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

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

ConVar g_hBotReplaceSlayDelay, g_hBotNotSlayCapped, g_hBotDeathKick;
bool g_bBotNotSlayCapped, g_bBotDeathKick;
float g_fBotReplaceSlayDelay;

public Plugin myinfo = 
{
	name = "L4D1 No Second Chances",
	author = "Visor, Jacob, A1m`, l4d1 port by Harry",
	description = "Instantly slay and kick SI bots that were previously controlled by human players.",
	version = "1.6-2026/10/13",
	url = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

public void OnPluginStart()
{
	
	g_hBotReplaceSlayDelay 	= CreateConVar("l4d_nosecondchances_bot_slay_delay", 	"0.1", 	"How long should we wait before slaying the infected bot after bot replaces the real infected player? (-1: Don't slay)", _, true, -1.0, true, 30.0);
	g_hBotNotSlayCapped 	= CreateConVar("l4d_nosecondchances_bot_capped_check", 	"1", 	"If 1, Do not slay infected bots if they already capped the survivor (pounced/pulled)", _, true, 0.0, true, 1.0);
	g_hBotDeathKick 		= CreateConVar("l4d_nosecondchances_bot_death_kick", 	"1", 	"If 1, Kick infected bots upon death (including slay)", _, true, 0.0, true, 1.0);

	GetCvars();
	g_hBotReplaceSlayDelay.AddChangeHook(ConVarChanged_Cvars);
	g_hBotNotSlayCapped.AddChangeHook(ConVarChanged_Cvars);
	g_hBotDeathKick.AddChangeHook(ConVarChanged_Cvars);

	HookEvent("player_bot_replace", PlayerBotReplace); // bot replaces player
	HookEvent("player_death", Event_PlayerDeath);
}

void ConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_fBotReplaceSlayDelay 	= g_hBotReplaceSlayDelay.FloatValue;
	g_bBotNotSlayCapped 	= g_hBotNotSlayCapped.BoolValue;
	g_bBotDeathKick 		= g_hBotDeathKick.BoolValue;
}

void PlayerBotReplace(Event hEvent, const char[] eName, bool dontBroadcast)
{
	int iUserID = hEvent.GetInt("bot");
	int iBot = GetClientOfUserId(iUserID);

	if (IsClientInGame(iBot) && GetClientTeam(iBot) == TEAM_INFECTED && IsFakeClient(iBot)) {
		if (g_fBotReplaceSlayDelay >= 0.0) {
			CreateTimer(g_fBotReplaceSlayDelay, Timer_KillBotDelay, iUserID, TIMER_FLAG_NO_MAPCHANGE);
		} 
		else if (g_fBotReplaceSlayDelay == 0.0) {
			if(ShouldBeKicked(iBot)) {
				ForcePlayerSuicide(iBot);
			}
		}
		else if (g_fBotReplaceSlayDelay < 0.0){
			return;
		}
	}
}

// It's important to kick infected bots upon death, otherwise they will stay in the game and cause issues. Ghost tank unable to spawn because of this.
// All 5 slots are occupied, then tank won't be able to spawn
void Event_PlayerDeath(Event hEvent, const char[] name, bool dontBroadcast)
{
	if(!g_bBotDeathKick) return;

	int userid = hEvent.GetInt("userid");
	int client = GetClientOfUserId(userid);
	if (!client || !IsClientInGame(client) || !IsFakeClient(client) || GetClientTeam(client) != TEAM_INFECTED) return;

	int iZombieClassType = GetEntProp(client, Prop_Send, "m_zombieClass");
	
	if(iZombieClassType == ZC_TANK) CreateTimer(5.0, Timer_KickInfectedBot, userid);
	else CreateTimer(1.0, Timer_KickInfectedBot, userid);
}

 //When a spawned Infected Player disconnects, changes team or becomes Tank the SI will instantly get killed unless it has someone capped.
bool ShouldBeKicked(int iBot)
{
	int iZombieClassType = GetEntProp(iBot, Prop_Send, "m_zombieClass");
	
	if (iZombieClassType == ZC_TANK) return false;

	if(g_bBotNotSlayCapped)
	{
		if (strlen(L4D1_SI_Victim_NetProps[iZombieClassType]) != 0 
			&& GetEntPropEnt(iBot, Prop_Send, L4D1_SI_Victim_NetProps[iZombieClassType]) != -1) {
			return false;
		}
	}

	return true;
}

Action Timer_KillBotDelay(Handle hTimer, any iUserID)
{
	int iBot = GetClientOfUserId(iUserID);
	if (iBot > 0 && IsClientInGame(iBot) && IsFakeClient(iBot) && IsPlayerAlive(iBot) && ShouldBeKicked(iBot)) 
	{
		ForcePlayerSuicide(iBot);
	}

	return Plugin_Continue;
}

Action Timer_KickInfectedBot(Handle timer, any iUserID)
{
	int iBot = GetClientOfUserId(iUserID);
	if (!iBot || !IsClientInGame(iBot) || !IsFakeClient(iBot)) return Plugin_Continue;
	
	KickClient(iBot, "Kicked infected bot");
	
	return Plugin_Continue;
}