#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <left4dhooks>
#include <collisionhook>

#define CLASSNAME_LENGTH 64
#define L4D_TEAM_SPEC 1 
#define L4D_TEAM_SUR 2
#define L4D_TEAM_INF 3

#define ZC_HUNTER		3

ConVar hRockFix, hPullThrough, hRockThroughIncap ,hCommonThroughWitch, hHunterThroughInacp;
bool bRockFix,bPullThrough,bRockThroughIncap,bCommonThroughWitch, bHunterThroughInacp;
bool g_bPulled[MAXPLAYERS + 1] = {false};
char sEntityCName[20];
char sEntityCNameTwo[20];
float g_fPouncingStartTime[MAXPLAYERS+1];

public Plugin myinfo = 
{
	name = "L4D Collision Adjustments",
	author = "Sir, l4d1 port by Harry Potter",
	description = "mother fucker no collisions to fix a handful of silly collision bugs in l4d1",
	version = "1.2",
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

public void OnPluginStart()
{
	hRockFix 			= CreateConVar("collision_tankrock_common", "1", "Will Rocks go through Common Infected (and also kill them) instead of possibly getting stuck on them?",FCVAR_NOTIFY);
	hPullThrough 		= CreateConVar("collision_smoker_common", 	"1", "Will Pulled Survivors go through Common Infected?",FCVAR_NOTIFY);
	hRockThroughIncap 	= CreateConVar("collision_tankrock_incap", 	"1", "Will Rocks go through Incapacitated Survivors? (Won't go through new incaps caused by the Rock)",FCVAR_NOTIFY);
	hCommonThroughWitch = CreateConVar("collision_common_witch", 	"1", "Will Commons go through Witch? (Prevent commons from pushing witch in l4d1)",FCVAR_NOTIFY);
	hHunterThroughInacp = CreateConVar("collision_common_witch", 	"1", "Hunter go through incapacitated survivor? (Prevent hunter stuck inside incapacitated survivor, still can pounce them)",FCVAR_NOTIFY);
	
	GetCvars();
	
	hRockFix.AddChangeHook(ConVarChanged);
	hPullThrough.AddChangeHook(ConVarChanged);
	hRockThroughIncap.AddChangeHook(ConVarChanged);
	hCommonThroughWitch.AddChangeHook(ConVarChanged);
	hHunterThroughInacp.AddChangeHook(ConVarChanged);
	
	HookEvent("tongue_grab", Event_SurvivorPulled);
	HookEvent("tongue_release", Event_PullEnd);
	HookEvent("round_start", event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_bot_replace", OnBotSwap);
	HookEvent("bot_player_replace", OnBotSwap);
	HookEvent("ability_use", Event_AbilityUse);
}

public Action CH_PassFilter(int ent1, int ent2, bool &result)
{
	if (ent1 > 0 && ent1 < MaxClients && IsClientInGame(ent1) && IsPlayerAlive(ent1) 
		&& ent2 > 0 && ent2 < MaxClients && IsClientInGame(ent2) && IsPlayerAlive(ent2) )
	{
		if(bHunterThroughInacp && GetClientTeam(ent1) == L4D_TEAM_SUR && L4D_IsPlayerIncapacitated(ent1))
		{
			if(GetClientTeam(ent2) == L4D_TEAM_INF && GetZombieClass(ent2) == ZC_HUNTER && IsStartToPounce(ent2))
			{
				result = false;
				return Plugin_Handled;
			}
		}
		else if(bHunterThroughInacp && GetClientTeam(ent2) == L4D_TEAM_SUR && L4D_IsPlayerIncapacitated(ent2))
		{
			if(GetClientTeam(ent1) == L4D_TEAM_INF && GetZombieClass(ent1) == ZC_HUNTER && IsStartToPounce(ent1))
			{
				result = false;
				return Plugin_Handled;
			}
		}
	}

	if (IsValidEdict(ent1) && IsValidEdict(ent2))
	{
		GetEdictClassname(ent1, sEntityCName, 20);
		GetEdictClassname(ent2, sEntityCNameTwo, 20);

		if (StrEqual(sEntityCName, "infected"))
		{
			if (bRockFix && StrEqual(sEntityCNameTwo, "tank_rock"))
			{
				result = false;
				return Plugin_Handled;
			}

			if (bPullThrough && IsSurvivor(ent2) && g_bPulled[ent2])
			{
				result = false;
				return Plugin_Handled;			
			}
			if (bCommonThroughWitch && StrEqual(sEntityCNameTwo, "witch"))
			{
				result = false;
				return Plugin_Handled;			
			}
		}
		else if (StrEqual(sEntityCNameTwo, "infected"))
		{
			if (bRockFix && StrEqual(sEntityCName, "tank_rock"))
			{
				result = false;
				return Plugin_Handled;
			}

			if (bPullThrough && IsSurvivor(ent1) && g_bPulled[ent1])
			{
				result = false;
				return Plugin_Handled;			
			}
			if (bCommonThroughWitch && StrEqual(sEntityCName, "witch"))
			{
				result = false;
				return Plugin_Handled;			
			}
		}
		else if (StrEqual(sEntityCName, "tank_rock"))
		{
			if (bRockThroughIncap && IsSurvivor(ent2) && IsIncapacitatedOrHangingFromLedge(ent2))
			{
				result = false;
				return Plugin_Handled;
			}
		}
		else if (StrEqual(sEntityCNameTwo, "tank_rock"))
		{
			if (bRockThroughIncap && IsSurvivor(ent1) &&  IsIncapacitatedOrHangingFromLedge(ent1))
			{
				result = false;
				return Plugin_Handled;
			}		
		}
	}

	return Plugin_Continue;
}

// hunters pouncing / tracking
void Event_AbilityUse(Event hEvent, const char[] name, bool dontBroadcast)
{
	// track hunters pouncing
	char abilityName[64];
	hEvent.GetString("ability", abilityName, sizeof(abilityName));
	
	if (strcmp(abilityName, "ability_lunge", false) == 0) {
		int client = GetClientOfUserId(hEvent.GetInt("userid"));
		
		if (client <= 0 
		|| client > MaxClients 
		|| !IsClientInGame(client) 
		|| GetClientTeam(client) != L4D_TEAM_INF)
			return;

		// Hunter pounce
		g_fPouncingStartTime[client] = GetEngineTime();
	}
}

void Event_SurvivorPulled(Handle event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(event, "victim"));
	g_bPulled[victim] = true;
}

void Event_PullEnd(Handle event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(event, "victim"));
	g_bPulled[victim] = false;
}

void event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++) //clear
	{
		g_bPulled[i] = false;
		g_fPouncingStartTime[i] = 0.0;
	}
}

void OnBotSwap(Handle event, const char[] name, bool dontBroadcast)
{
	int bot = GetClientOfUserId(GetEventInt(event, "bot"));
	int player = GetClientOfUserId(GetEventInt(event, "player"));
	if (IsClientIndex(bot) && IsClientIndex(player)) 
	{
		if (StrEqual(name, "player_bot_replace")) //bot take over
		{
			g_bPulled[bot] = g_bPulled[player];
			g_bPulled[player] = false;
		}
		else //player take over bot
		{
			g_bPulled[player] = g_bPulled[bot];
			g_bPulled[bot] = false;
		}
	}
}

void ConVarChanged(Handle convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	bRockFix = hRockFix.BoolValue;
	bPullThrough = hPullThrough.BoolValue;
	bRockThroughIncap = hRockThroughIncap.BoolValue;
	bCommonThroughWitch = hCommonThroughWitch.BoolValue;
	bHunterThroughInacp = hHunterThroughInacp.BoolValue;
}

// ----------------------------
bool IsClientIndex(int client)
{
	return (client > 0 && client <= MaxClients);
}

bool IsValidClient(int client) { 
    if (client <= 0 || client > MaxClients || !IsClientConnected(client)) return false; 
    return IsClientInGame(client); 
} 

bool IsSurvivor(int client) {
	return IsValidClient(client) && GetClientTeam(client) == L4D_TEAM_SUR;
}

bool IsIncapacitatedOrHangingFromLedge(int client) {
	if (GetEntProp(client, Prop_Send, "m_isHangingFromLedge"))
		return true;
	if (GetEntProp(client, Prop_Send, "m_isIncapacitated") > 0)
		return true;
		
	return false;
}

int GetZombieClass(int client)
{
	return GetEntProp(client, Prop_Send, "m_zombieClass");
}

bool IsStartToPounce(int client)
{
	int Activity = L4D1_GetMainActivity(client);
	if(Activity == L4D1_ACT_TERROR_HUNTER_POUNCE 
		&& g_fPouncingStartTime[client] + 0.09 > GetEngineTime())
	{
		return true;
	}

	return false;
}