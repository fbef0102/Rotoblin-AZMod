#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <readyup>

#define DEBUG 0

#define ZC_SMOKER		1
#define ZC_BOOMER		2
#define ZC_HUNTER		3
#define ZC_TANK			5
#define TEAM_CLASS(%1)		(%1 == 1 ? "Smoker" : (%1 == 2 ? "Boomer" : (%1 == 3 ? "Hunter" :(%1 == 4 ? "Witch" : (%1 == 5 ? "Tank" : "None")))))
#define KeepSITrackingCheckDelay 0.25
#define KEEPSICHECKDELAY 0.1

bool PluginDisable = false;
ConVar HCVAR_Z_VS_SMOKER_LIMIT;
ConVar HCVAR_Z_VS_BOOMER_LIMIT;
ConVar HCVAR_Z_VS_HUNTER_LIMIT;
ConVar z_max_player_zombies;
int CVAR_Z_VS_SMOKER_LIMIT_ORIGINAL, CVAR_Z_VS_BOOMER_LIMIT_ORIGINAL, CVAR_Z_VS_HUNTER_LIMIT_ORIGINAL;

ConVar hCvar3HT1SProbability;
ConVar hCvarDirtyAfterSmoker;
ConVar hCvarNoQuadAfterHunter;
int g_iCvar3HT1SProbability;
bool g_bCvarDirtyAfterSmoker, g_bCvarNoQuadAfterHunter;

int 
	Hunter_Starting_Line,
	Smoker_Starting_Line,
	Boomer_Starting_Line,
	g_iRoundStart, 
	g_iPlayerSpawn;

// riverside6: the smoker's player who is owed the boomer, 0 = none
int g_iDirtyUserid;	

// riverside7 (owner ruling 2026-10-28): hunter dies last = stock classes, but never a quad. Stock can still deal 3 hunters +
// smoker (or 4 hunters) there. Until the next SI death, each new ghost checks the team: once nobody is left waiting to
// respawn and the living team (ghosts included) still has no boomer, that last ghost is switched to boomer.
bool g_bNoQuadPending = false;

public Plugin myinfo = 
{
	name = "L4D Quad Caps Control",
	author = "Harry Potter",
	description = "As the name says, you dumb fuck",
	version = "1.6-2026/10/30",
	url = "http://steamcommunity.com/profiles/76561198026784913"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();

	if( test != Engine_Left4Dead )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1.");
		return APLRes_SilentFailure;
	}

	return APLRes_Success;
}

bool 
	g_bRoundEnd,
	g_bRoundIsLive,
	g_bLimitsOverridden; // riverside2: the boomer/smoker limits hold this plugin's temporary values

int 
	g_iSavedSmokerLimit, 
	g_iSavedBoomerLimit;

public void OnPluginStart()
{
	HookEvent("round_start", Event_RoundStart);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("mission_lost", Event_RoundEnd);
	HookEvent("finale_win", Event_RoundEnd);
	HookEvent("player_death", Event_PlayerDeath,	EventHookMode_PostNoCopy);
	HookEvent("player_team", Event_PlayerTeam);
	
	z_max_player_zombies = FindConVar("z_max_player_zombies");
	HCVAR_Z_VS_SMOKER_LIMIT = FindConVar("z_versus_smoker_limit");
	HCVAR_Z_VS_BOOMER_LIMIT = FindConVar("z_versus_boomer_limit");
	HCVAR_Z_VS_HUNTER_LIMIT = FindConVar("z_hunter_limit");
	CVAR_Z_VS_SMOKER_LIMIT_ORIGINAL = HCVAR_Z_VS_SMOKER_LIMIT.IntValue;
	CVAR_Z_VS_BOOMER_LIMIT_ORIGINAL = HCVAR_Z_VS_BOOMER_LIMIT.IntValue;
	CVAR_Z_VS_HUNTER_LIMIT_ORIGINAL = HCVAR_Z_VS_HUNTER_LIMIT.IntValue;

	hCvar3HT1SProbability 	= CreateConVar("sm_3ht1s_percent_chance", 	"90",	"X% chance of \"3 hunters + 1 smoker\" and 100-X% remaining chance of \"4 hunters\" after Boomer dies", FCVAR_NOTIFY, true, 0.0,true, 100.0);
	hCvarDirtyAfterSmoker 	= CreateConVar("sm_dirty_after_smoker", 	"1", 	"1 = smoker dies last gives hunters + exactly one boomer (the smoker's player)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	hCvarNoQuadAfterHunter 	= CreateConVar("sm_noquad_after_hunter", 	"1", 	"1 = hunter dies last never gives a quad (the last ghost of the wave becomes the boomer if nobody else is one)", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	GetCvars();
	hCvar3HT1SProbability.AddChangeHook(ConVarChanged_Cvars);
	hCvarDirtyAfterSmoker.AddChangeHook(ConVarChanged_Cvars);
	hCvarNoQuadAfterHunter.AddChangeHook(ConVarChanged_Cvars);
	
	PluginDisable = false;
}

public void OnPluginEnd()
{
	HCVAR_Z_VS_SMOKER_LIMIT.IntValue = CVAR_Z_VS_SMOKER_LIMIT_ORIGINAL;
	HCVAR_Z_VS_BOOMER_LIMIT.IntValue = CVAR_Z_VS_BOOMER_LIMIT_ORIGINAL;

	ResetVariable();
	PluginDisable = false;
}

void ConVarChanged_Cvars(ConVar hCvar, const char[] sOldVal, const char[] sNewVal)
{
	GetCvars();
}

void GetCvars()
{
	g_iCvar3HT1SProbability = hCvar3HT1SProbability.IntValue;
	g_bCvarDirtyAfterSmoker = hCvarDirtyAfterSmoker.BoolValue;
	g_bCvarNoQuadAfterHunter = hCvarNoQuadAfterHunter.BoolValue;
}


public void OnConfigsExecuted()
{
	CVAR_Z_VS_SMOKER_LIMIT_ORIGINAL = HCVAR_Z_VS_SMOKER_LIMIT.IntValue;
	CVAR_Z_VS_BOOMER_LIMIT_ORIGINAL = HCVAR_Z_VS_BOOMER_LIMIT.IntValue;
	CVAR_Z_VS_HUNTER_LIMIT_ORIGINAL = HCVAR_Z_VS_HUNTER_LIMIT.IntValue;
	
	if(CVAR_Z_VS_BOOMER_LIMIT_ORIGINAL == 0  && CVAR_Z_VS_SMOKER_LIMIT_ORIGINAL == 0) 
	{
		//LogMessage("detect \"Hunters Only\" mode, disable Quad Caps");
		PluginDisable = true;
	}
	else if(CVAR_Z_VS_BOOMER_LIMIT_ORIGINAL == 0)
	{
		//LogMessage("detect \"No Boomer\" mode, disable Quad Caps");
		PluginDisable = true;
	}
	else if(CVAR_Z_VS_HUNTER_LIMIT_ORIGINAL < 2)
	{
		//LogMessage("detect \"z_hunter_limit < 2\", disable Quad Caps");
		PluginDisable = true;
	}
}

public void OnMapStart()
{	
	Hunter_Starting_Line = Smoker_Starting_Line = Boomer_Starting_Line = 0;

	g_bRoundEnd = false;
	g_bRoundIsLive = false;
}

public void OnMapEnd()
{
	HCVAR_Z_VS_SMOKER_LIMIT.IntValue = CVAR_Z_VS_SMOKER_LIMIT_ORIGINAL;
	HCVAR_Z_VS_BOOMER_LIMIT.IntValue = CVAR_Z_VS_BOOMER_LIMIT_ORIGINAL;

	g_bLimitsOverridden = false;
	g_iDirtyUserid = 0;
	g_bNoQuadPending = false;
	ResetVariable();
	PluginDisable = false;
}

// riverside6: the owed player left the infected team before his ghost, so let stock deal the boomer instead
public void OnClientDisconnect(int client)
{
	if(IsClientInGame(client)) DirtyPlayerGone(GetClientUserId(client));
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if( g_iPlayerSpawn == 1 && g_iRoundStart == 0 )
		CreateTimer(0.25, PluginStart);
	g_iRoundStart = 1;
	g_bRoundEnd = false;
	g_bRoundIsLive = false;
	if(g_bLimitsOverridden) RestoreLimits();
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{ 
	if( g_iPlayerSpawn == 0 && g_iRoundStart == 1 )
		CreateTimer(0.25, PluginStart);
	g_iPlayerSpawn = 1;
}

void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	DirtyPlayerGone(event.GetInt("userid"));
}

Action PluginStart(Handle timer)
{
	if(!InSecondHalfOfRound())
	{
		Sub_DebugPrint("Round 1");
		return Plugin_Continue;
	}

	Sub_DebugPrint("round start event");
	for(int i=1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == L4D_TEAM_INFECTED && !IsFakeClient(i) && L4D_IsPlayerGhost(i))
		{
			RequestFrame(OnNextFrame_ChangeClass_Round2, GetClientUserId(i));
		}
	}

	return Plugin_Continue;
}

void Event_RoundEnd(Event event, char[] name, bool bDontBroadcast)
{
	Sub_DebugPrint("round end event");

	g_bRoundEnd = true;
	ResetVariable();
	if(g_bLimitsOverridden) RestoreLimits();
}

public void OnRoundIsLive() 
{
	if(g_bRoundIsLive) return;
	
	GameStart();
}

public void L4D_OnFirstSurvivorLeftSafeArea_Post(int client)
{
	if(g_bRoundIsLive) return;

	GameStart();
}

void GameStart()
{
	g_bRoundIsLive = true;

	CreateTimer(KEEPSICHECKDELAY, KeepSIStarting); // delay check

	if(g_bLimitsOverridden) RestoreLimits();
}

Action KeepSIStarting(Handle timer)
{
	if(!InSecondHalfOfRound())
	{
		Sub_DebugPrint("Keep it");
		Hunter_Starting_Line = Smoker_Starting_Line = Boomer_Starting_Line = 0;
		int zombieclass;
		for(int i=1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && GetClientTeam(i) == 3 && !IsFakeClient(i) && L4D_IsPlayerGhost(i))
			{
				zombieclass = GetEntProp(i, Prop_Send, "m_zombieClass");
				switch(zombieclass)
				{
					case ZC_SMOKER:  
					{
						Smoker_Starting_Line++;
					}
					case ZC_BOOMER:  
					{
						Boomer_Starting_Line++;
					}
					case ZC_HUNTER:  
					{
						Hunter_Starting_Line++;
					}			
				}
			}
		}
		Sub_DebugPrint("H: %d, S: %d, B: %d",Hunter_Starting_Line,Smoker_Starting_Line,Boomer_Starting_Line);
		if(Smoker_Starting_Line + Boomer_Starting_Line + Hunter_Starting_Line > z_max_player_zombies.IntValue)	
		{
			Sub_DebugPrint("Error! infected players more than z_max_player_zombies");
			CreateTimer(KeepSITrackingCheckDelay, KeepSIStarting); // keep checking
		}
	}

	return Plugin_Continue;
}

void Event_PlayerDeath(Event event, char[] name, bool bDontBroadcast)
{
	if( PluginDisable || !g_bRoundIsLive || g_bRoundEnd ) return ;
	
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!client || !IsClientInGame(client)) return;
	
	if(GetClientTeam(client) == L4D_TEAM_INFECTED)
	{
		g_bNoQuadPending = false;

		int zombieclass = GetEntProp(client, Prop_Send, "m_zombieClass");
		if(zombieclass == ZC_BOOMER)
		{
			if (!g_bLimitsOverridden)
			{
				g_iSavedSmokerLimit = HCVAR_Z_VS_SMOKER_LIMIT.IntValue;
				g_iSavedBoomerLimit = HCVAR_Z_VS_BOOMER_LIMIT.IntValue;
			}

			int random = GetRandomInt(1, 100);
			if (random <= g_iCvar3HT1SProbability)
			{
				HCVAR_Z_VS_SMOKER_LIMIT.IntValue = 1;
				HCVAR_Z_VS_BOOMER_LIMIT.IntValue = 0;
				g_bLimitsOverridden = true;
				Sub_DebugPrint("No Boomer");
			}
			else
			{
				HCVAR_Z_VS_BOOMER_LIMIT.IntValue = 0;
				HCVAR_Z_VS_SMOKER_LIMIT.IntValue = 0;
				g_bLimitsOverridden = true;
				Sub_DebugPrint("No Boomer and Smoker");
			}
			g_iDirtyUserid = 0;
		}
		else //including tank
		{
			if (g_bLimitsOverridden)
			{
				RestoreLimits();
				Sub_DebugPrint("Boomer and Smoker limit reset");
			}

			int infcount;
			bool OtherBoomerAlive;
			// riverside8: a living infected boomer (ghosts included) other than except
			for(int i = 1; i <= MaxClients; i++)
			{
				if(!IsClientInGame(i) || GetClientTeam(i) != L4D_TEAM_INFECTED) continue;
				if(!IsFakeClient(i)) infcount++;

				if(i != client && IsPlayerAlive(i) && GetEntProp(i, Prop_Send, "m_zombieClass") == ZC_BOOMER)
				{
					OtherBoomerAlive = true;
				}
			}

			if(infcount <= 1)
			{
				//PrintToChatAll("last man on infected team");
				return;
			}

			if(OtherBoomerAlive)
			{
				//PrintToChatAll("Other boomer alive on infected team");
				return;
			}

			// riverside6: smoker dies last -> dirty: hunters + exactly one boomer
			if (zombieclass == ZC_SMOKER && g_bCvarDirtyAfterSmoker)
			{
				g_iSavedSmokerLimit = HCVAR_Z_VS_SMOKER_LIMIT.IntValue;
				g_iSavedBoomerLimit = HCVAR_Z_VS_BOOMER_LIMIT.IntValue;
				HCVAR_Z_VS_SMOKER_LIMIT.IntValue = 0;
				HCVAR_Z_VS_BOOMER_LIMIT.IntValue = 0;
				g_bLimitsOverridden = true;
				g_iDirtyUserid = GetClientUserId(client);
				Sub_DebugPrint("Dirty: %N is owed the boomer", client);
			}
			// riverside7: hunter dies last = no quad
			else if (zombieclass == ZC_HUNTER && g_bCvarNoQuadAfterHunter)
			{
				g_bNoQuadPending = true;
				Sub_DebugPrint("No quad: hunter died last");
			}
		}	
	}
}

bool isCulling = false;
public Action L4D_OnEnterGhostStatePre(int client)
{
	static int s_iOffs_m_bPZAbortedControl = -1;
	if (s_iOffs_m_bPZAbortedControl == -1)
		s_iOffs_m_bPZAbortedControl = FindSendPropInfo("CTerrorPlayer", "m_lookatPlayer") + 4;
	
	isCulling = GetEntData(client, s_iOffs_m_bPZAbortedControl, 1) != 0;
	
	return Plugin_Continue;
}

// this could happen before "round_start" event (right before round starts)
public void L4D_OnEnterGhostState(int client)
{
	if(isCulling || IsFakeClient(client)) return;

	if(InSecondHalfOfRound() && !g_bRoundIsLive)
	{
		//PrintToChatAll("Round 2 Is in saferoom or Is in Ready");
		//PrintToChatAll("%N: OnEnterGhostState %s", client, TEAM_CLASS(GetEntProp(client, Prop_Send, "m_zombieClass")));

		RequestFrame(OnNextFrame_ChangeClass_Round2, GetClientUserId(client));
	
		return;
	}

	if(g_iDirtyUserid && GetClientUserId(client) == g_iDirtyUserid)
		RequestFrame(OnNextFrame_DirtyBoomer, g_iDirtyUserid);

	if(g_bNoQuadPending)
		RequestFrame(OnNextFrame_NoQuadCheck, GetClientUserId(client));
}

void OnNextFrame_ChangeClass_Round2(int userid)
{
	int client = GetClientOfUserId(userid);
	if(!client || !IsClientInGame(client) || GetClientTeam(client) != L4D_TEAM_INFECTED || !L4D_IsPlayerGhost(client))	return;

	int zombieclass;
	int Hunter_Now_Line = 0, Smoker_Now_Line = 0, Boomer_Now_Line = 0, NeedChange = 0;
	for(int i=1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == 3 && !IsFakeClient(i))
		{
			zombieclass = GetEntProp(i, Prop_Send, "m_zombieClass");
			switch(zombieclass)
			{
				case ZC_SMOKER:  
				{
					Smoker_Now_Line++;
				}
				case ZC_BOOMER:  
				{
					Boomer_Now_Line++;
				}
				case ZC_HUNTER:  
				{
					Hunter_Now_Line++;
				}			
			}
		}
	}

	zombieclass = GetEntProp(client, Prop_Send, "m_zombieClass");
	if(Smoker_Now_Line<Smoker_Starting_Line)
	{
		if(zombieclass != ZC_SMOKER)
			NeedChange = ZC_SMOKER;
	}
	else if (Boomer_Now_Line<Boomer_Starting_Line)
	{
		if(zombieclass != ZC_BOOMER)
			NeedChange = ZC_BOOMER;
	}
	else if (Hunter_Now_Line<Hunter_Starting_Line)
	{
		if(zombieclass != ZC_HUNTER)
			NeedChange = ZC_HUNTER;
	}
	
	if(NeedChange > 0)
	{
		ChangeGhostClass(client, NeedChange);
	}
}

// riverside6: the smoker's player becomes the wave's one boomer. The limits stay at 0 until the next SI death, so nobody
// else can be dealt a boomer meanwhile.
void OnNextFrame_DirtyBoomer(int userid)
{
	if(userid != g_iDirtyUserid) return;
	int client = GetClientOfUserId(userid);
	if(!client || !IsClientInGame(client) || GetClientTeam(client) != L4D_TEAM_INFECTED || !L4D_IsPlayerGhost(client)) return;
	g_iDirtyUserid = 0;

	int zombieclass = GetEntProp(client, Prop_Send, "m_zombieClass");
	if(zombieclass == ZC_BOOMER || zombieclass == ZC_TANK) return;

	// Spawn counted this life as zombieclass; count it as the boomer it is, so stock rotation stays fair
	SetEntProp(client, Prop_Send, "m_classSpawnCount", GetEntProp(client, Prop_Send, "m_classSpawnCount", 4, zombieclass) - 1, 4, zombieclass);
	SetEntProp(client, Prop_Send, "m_classSpawnCount", GetEntProp(client, Prop_Send, "m_classSpawnCount", 4, ZC_BOOMER) + 1, 4, ZC_BOOMER);
	ChangeGhostClass(client, ZC_BOOMER);
	Sub_DebugPrint("Dirty: %N changed to Boomer", client);
}

// riverside7: hunter died last. Waits until this ghost is the last of the wave, then makes sure it holds a boomer.
void OnNextFrame_NoQuadCheck(int userid)
{
	if(!g_bNoQuadPending) return;
	int client = GetClientOfUserId(userid);
	if(!client || !IsClientInGame(client) || GetClientTeam(client) != L4D_TEAM_INFECTED || !L4D_IsPlayerGhost(client)) return;

	bool bBoomer = false;
	int iWaiting = 0;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i) || GetClientTeam(i) != L4D_TEAM_INFECTED) continue;
		if(IsPlayerAlive(i))
		{
			if(GetEntProp(i, Prop_Send, "m_zombieClass") == ZC_BOOMER) bBoomer = true;
		}
		else if(!IsFakeClient(i))
			iWaiting++;	// dead and still to respawn
	}

	if(bBoomer)
	{
		g_bNoQuadPending = false;	// the wave already has its boomer
		return;
	}
	if(iWaiting > 0) return;	// a later ghost may still be dealt one

	g_bNoQuadPending = false;
	int zombieclass = GetEntProp(client, Prop_Send, "m_zombieClass");
	if(zombieclass == ZC_TANK) return;

	SetEntProp(client, Prop_Send, "m_classSpawnCount", GetEntProp(client, Prop_Send, "m_classSpawnCount", 4, zombieclass) - 1, 4, zombieclass);
	SetEntProp(client, Prop_Send, "m_classSpawnCount", GetEntProp(client, Prop_Send, "m_classSpawnCount", 4, ZC_BOOMER) + 1, 4, ZC_BOOMER);
	ChangeGhostClass(client, ZC_BOOMER);
	Sub_DebugPrint("No quad: %N changed to Boomer", client);
}

// riverside6: the owed player left the infected team before his ghost, so let stock deal the boomer instead
void DirtyPlayerGone(int userid)
{
	if(!g_iDirtyUserid || userid != g_iDirtyUserid) return;

	g_iDirtyUserid = 0;
	HCVAR_Z_VS_BOOMER_LIMIT.IntValue = g_iSavedBoomerLimit;
}

void ChangeGhostClass(int client, int NewClass)
{
	L4D_SetClass(client, NewClass);
}

void Sub_DebugPrint(const char[] Message, any ...)
{

#if DEBUG
	decl String:DebugBuff[128];
	VFormat(DebugBuff, sizeof(DebugBuff), Message, 2);
	PrintToChatAll("%s",DebugBuff);
#else
	#pragma unused Message
#endif
}

void RestoreLimits()
{
	HCVAR_Z_VS_SMOKER_LIMIT.IntValue = g_iSavedSmokerLimit;
	HCVAR_Z_VS_BOOMER_LIMIT.IntValue = g_iSavedBoomerLimit;
	g_bLimitsOverridden = false;
	g_iDirtyUserid = 0;
	g_bNoQuadPending = false;
}

bool InSecondHalfOfRound()
{
	return view_as<bool>(GameRules_GetProp("m_bInSecondHalfOfRound"));
}

void ResetVariable()
{
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
}