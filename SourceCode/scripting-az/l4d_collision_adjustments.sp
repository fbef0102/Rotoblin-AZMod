#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <left4dhooks>
#include <collisionhook>
public Plugin myinfo = 
{
	name = "[L4D1/L4D2] Collision Adjustments",
	author = "Sir, Harry Potter",
	description = "No collisions to fix a handful of silly collision bugs in l4d",
	version = "1.2h-2026/10/5-riverside2",
	url = "http://steamcommunity.com/profiles/76561198026784913"
}

bool g_bL4D2Version;
bool bLate;
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();

	if( test == Engine_Left4Dead )
	{
		g_bL4D2Version = false;
	}
	else if( test == Engine_Left4Dead2 )
	{
		g_bL4D2Version = true;
	}
	else
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}

	bLate = late;
	return APLRes_Success;
}

#define CLASSNAME_LENGTH 64
#define L4D_TEAM_SPEC 1 
#define L4D_TEAM_SUR 2
#define L4D_TEAM_INF 3

#define ZC_HUNTER	3

ConVar g_hCvarRockFix, g_hCvarPullThrough, g_hCvarRockThroughIncap, g_hCvarHunterThroughInacp, g_hCvarSIThroughWitch,
	g_hCvarClientPushPipeBombFix;
bool g_bCvarRockFix,g_bCvarPullThrough,g_bCvarRockThroughIncap, g_bCvarHunterThroughInacp, g_bCvarSIThroughWitch,
	g_bCvarClientPushPipeBombFix;
// riverside2: a hunter aimed at an incap still lands on him, only incaps he is not aimed at are passed through
ConVar g_hCvarHunterIncapAim;
float g_fCvarHunterIncapAimCos;
int g_iPounceAimTarget[MAXPLAYERS+1];
bool g_bPulled[MAXPLAYERS + 1] = {false, ...};
float g_fPouncingStartTime[MAXPLAYERS+1];


#define MAXENTITIES                   2048

enum EEntity_Type
{
	EEntity_Unknown,

	EEntity_Rock,
	EEntity_Infected,
	EEntity_Witch,
	EEntity_PipeBombProj,
	EEntity_MolotovProj,
}

EEntity_Type 
	g_iEntityType[MAXENTITIES+1];

int 
	g_iZombieClass;

public void OnPluginStart()
{
	g_iZombieClass = FindSendPropInfo("CTerrorPlayer", "m_zombieClass");

	g_hCvarRockFix 					= CreateConVar("l4d_collision_adjustments_tankrock_common", "1", "If 1, Rocks can go through Common Infected (and also kill them) instead of possibly getting stuck on them", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hCvarPullThrough 				= CreateConVar("l4d_collision_adjustments_smoker_common", 	"1", "If 1, Pulled Survivors can go through Common Infected", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hCvarRockThroughIncap 		= CreateConVar("l4d_collision_adjustments_tankrock_incap", 	"1", "If 1, Rocks can go through Incapacitated Survivors? (Won't go through new incaps caused by the Rock)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hCvarHunterThroughInacp 		= CreateConVar("l4d_collision_adjustments_hunter_incap", 	"1", "If 1, Hunter can go through incapacitated survivor (Prevent hunter stuck inside incapacitated survivor, still can pounce them)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hCvarHunterIncapAim 			= CreateConVar("l4d_collision_adjustments_hunter_incap_aim", "60", "(riverside) With hunter_incap 1, a pounce still lands on the incap closest to the hunter's crosshair at pounce start if he is within this many degrees of it. 0 = always pass through incaps", FCVAR_NOTIFY, true, 0.0, true, 180.0);
	g_hCvarSIThroughWitch 			= CreateConVar("l4d_collision_adjustments_si_witch", 		"1", "If 1, Special infected and Tank can go through witch (Prevent stuck and stagger)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hCvarClientPushPipeBombFix 	= CreateConVar("l4d_collision_adjustments_client_pipebomb", "1", "If 1, Fix the bug where survivor and special infected can push pipebomb projectiles", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	AutoExecConfig(true,            "l4d_collision_adjustments");

	GetCvars();
	g_hCvarRockFix.AddChangeHook(ConVarChanged);
	g_hCvarPullThrough.AddChangeHook(ConVarChanged);
	g_hCvarRockThroughIncap.AddChangeHook(ConVarChanged);
	g_hCvarHunterThroughInacp.AddChangeHook(ConVarChanged);
	g_hCvarHunterIncapAim.AddChangeHook(ConVarChanged);
	g_hCvarSIThroughWitch.AddChangeHook(ConVarChanged);
	g_hCvarClientPushPipeBombFix.AddChangeHook(ConVarChanged);
	
	HookEvent("tongue_grab", Event_SurvivorPulled);
	HookEvent("tongue_release", Event_PullEnd);
	HookEvent("round_start", event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_bot_replace", OnBotSwap);
	HookEvent("bot_player_replace", OnBotSwap);
	HookEvent("ability_use", Event_AbilityUse);
	HookEvent("player_spawn", Event_PlayerSpawn);

	if(bLate)
	{
		LateLoad();
	}
}

void LateLoad()
{
    int entity;
    char classname[36];

    entity = INVALID_ENT_REFERENCE;
    while ((entity = FindEntityByClassname(entity, "*")) != INVALID_ENT_REFERENCE)
    {
        if (entity < 0)
            continue;

        GetEntityClassname(entity, classname, sizeof(classname));
        OnEntityCreated(entity, classname);
    }
}

void ConVarChanged(Handle convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_bCvarRockFix = g_hCvarRockFix.BoolValue;
	g_bCvarPullThrough = g_hCvarPullThrough.BoolValue;
	g_bCvarRockThroughIncap = g_hCvarRockThroughIncap.BoolValue;
	g_bCvarHunterThroughInacp = g_hCvarHunterThroughInacp.BoolValue;
	g_fCvarHunterIncapAimCos = g_hCvarHunterIncapAim.FloatValue > 0.0 ? Cosine(DegToRad(g_hCvarHunterIncapAim.FloatValue)) : 2.0;
	g_bCvarSIThroughWitch = g_hCvarSIThroughWitch.BoolValue;
	g_bCvarClientPushPipeBombFix = g_hCvarClientPushPipeBombFix.BoolValue;
}

public Action CH_PassFilter(int ent1, int ent2, bool &result)
{
	// riverside1: every rule below needs two clients, or a non-client whose g_iEntityType is known.
	// Bail out before any native when neither holds (most commons, props and world traces).
	bool bClient1 = (ent1 > 0 && ent1 <= MaxClients);
	bool bClient2 = (ent2 > 0 && ent2 <= MaxClients);
	if (!(bClient1 && bClient2)
		&& (bClient1 || ent1 < 0 || ent1 > MAXENTITIES || g_iEntityType[ent1] == EEntity_Unknown)
		&& (bClient2 || ent2 < 0 || ent2 > MAXENTITIES || g_iEntityType[ent2] == EEntity_Unknown))
	{
		return Plugin_Continue;
	}

	if ( ent1 > 0 && ent1 <= MaxClients && IsClientInGame(ent1) && IsPlayerAlive(ent1) )
	{
		int team1 = GetClientTeam(ent1);
		if(ent2 > 0 && ent2 <= MaxClients && IsClientInGame(ent2) && IsPlayerAlive(ent2))
		{
			if( g_bCvarHunterThroughInacp && team1 == L4D_TEAM_SUR && L4D_IsPlayerIncapacitated(ent1)
				&& GetClientTeam(ent2) == L4D_TEAM_INF && GetZombieClass(ent2) == ZC_HUNTER && IsStartToPounce(ent2)
				&& g_iPounceAimTarget[ent2] != ent1)
			{
				result = false;
				return Plugin_Handled;
			}
		}
		else if(ent2 > MaxClients && IsValidEntity(ent2))
		{
			if( g_bCvarClientPushPipeBombFix && g_iEntityType[ent2] == EEntity_PipeBombProj )
			{
				result = false;
				return Plugin_Handled;
			}

			if ( g_bCvarPullThrough && g_iEntityType[ent2] == EEntity_Infected 
				&& team1 == L4D_TEAM_SUR && g_bPulled[ent1] )
			{
				result = false;
				return Plugin_Handled;			
			}

			if ( g_bCvarRockThroughIncap && g_iEntityType[ent2] == EEntity_Rock
				&& team1 == L4D_TEAM_SUR && L4D_IsPlayerIncapacitated(ent1) )
			{
				result = false;
				return Plugin_Handled;
			}

			if (g_bCvarSIThroughWitch && g_iEntityType[ent2] == EEntity_Witch
				&& team1 == L4D_TEAM_INF)
			{
				result = false;
				return Plugin_Handled;
			}	
		}
	}

	if ( ent2 > 0 && ent2 <= MaxClients && IsClientInGame(ent2) && IsPlayerAlive(ent2) )
	{
		int team2 = GetClientTeam(ent2);
		if( ent1 > 0 && ent1 <= MaxClients && IsClientInGame(ent1) && IsPlayerAlive(ent1) )
		{
			if( g_bCvarHunterThroughInacp && team2 == L4D_TEAM_SUR && L4D_IsPlayerIncapacitated(ent2)
				&& GetClientTeam(ent1) == L4D_TEAM_INF && GetZombieClass(ent1) == ZC_HUNTER && IsStartToPounce(ent1)
				&& g_iPounceAimTarget[ent1] != ent2 )
			{
				result = false;
				return Plugin_Handled;
			}
		}
		else if(ent1 > MaxClients && IsValidEntity(ent1))
		{
			if( g_bCvarClientPushPipeBombFix && g_iEntityType[ent1] == EEntity_PipeBombProj )
			{
				result = false;
				return Plugin_Handled;
			}

			if ( g_bCvarPullThrough && g_iEntityType[ent1] == EEntity_Infected
				&& team2 == L4D_TEAM_SUR && g_bPulled[ent2] )
			{
				result = false;
				return Plugin_Handled;			
			}

			if ( g_bCvarRockThroughIncap && g_iEntityType[ent1] == EEntity_Rock
				&& team2 == L4D_TEAM_SUR && L4D_IsPlayerIncapacitated(ent2) )
			{
				result = false;
				return Plugin_Handled;
			}

			if (g_bCvarSIThroughWitch && g_iEntityType[ent1] == EEntity_Witch
				&& team2 == L4D_TEAM_INF)
			{
				result = false;
				return Plugin_Handled;
			}	
		}
	}

	if (ent1 > MaxClients && IsValidEntity(ent1) 
		&& ent2 > MaxClients && IsValidEntity(ent2) )
	{
		if (g_iEntityType[ent1] == EEntity_Infected)
		{
			if (g_bCvarRockFix && g_iEntityType[ent2] == EEntity_Rock)
			{
				result = false;
				return Plugin_Handled;
			}
		}
		else if (g_iEntityType[ent2] == EEntity_Infected)
		{
			if (g_bCvarRockFix && g_iEntityType[ent1] == EEntity_Rock)
			{
				result = false;
				return Plugin_Handled;
			}
		}
	}

	return Plugin_Continue;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (!IsValidEntityIndex(entity))
		return;

	g_iEntityType[entity] = EEntity_Unknown;

	switch (classname[0])
	{
		case 'w':
		{
			if (StrEqual(classname, "witch"))
			{
				g_iEntityType[entity] = EEntity_Witch;
			}
		}
		case 'i':
		{
			if (StrEqual(classname, "infected"))
			{
				g_iEntityType[entity] = EEntity_Infected;
			}
		}
		case 't':
		{
			if (StrEqual(classname, "tank_rock"))
			{
				g_iEntityType[entity] = EEntity_Rock;
			}
		}
		case 'p':
		{
			if (StrEqual(classname, "pipe_bomb_projectile"))
			{
				g_iEntityType[entity] = EEntity_PipeBombProj;
			}
		}
		/*case 'm':
		{
			if (StrEqual(classname, "molotov_projectile"))
			{
				g_iEntityType[entity] = EEntity_MolotovProj;
			}
		}*/
	}
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
		g_iPounceAimTarget[client] = FindPounceAimTarget(client);
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
		g_iPounceAimTarget[i] = 0;
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

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{ 
	int client = GetClientOfUserId(event.GetInt("userid"));
	g_bPulled[client] = false;
}

// ----------------------------

// riverside2: the survivor closest to the hunter's crosshair when the pounce starts, if that is an incap
// within the aim cone; 0 otherwise. Standing survivors count too, so aiming at a survivor who stands next
// to an incap still passes through the incap (the original anti suck-in behaviour).
int FindPounceAimTarget(int hunter)
{
	if (g_fCvarHunterIncapAimCos > 1.0)
		return 0;

	float vEye[3], vAng[3], vAim[3];
	GetClientEyePosition(hunter, vEye);
	GetClientEyeAngles(hunter, vAng);
	GetAngleVectors(vAng, vAim, NULL_VECTOR, NULL_VECTOR);

	int best;
	float bestDot = g_fCvarHunterIncapAimCos;
	float vMins[3], vMaxs[3], vTo[3];
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || GetClientTeam(i) != L4D_TEAM_SUR || !IsPlayerAlive(i))
			continue;

		// aim at the middle of the survivor's hull, which is low for an incap
		GetClientAbsOrigin(i, vTo);
		GetClientMins(i, vMins);
		GetClientMaxs(i, vMaxs);
		vTo[2] += (vMins[2] + vMaxs[2]) * 0.5;
		SubtractVectors(vTo, vEye, vTo);
		if (NormalizeVector(vTo, vTo) <= 0.0)
			continue;

		float dot = GetVectorDotProduct(vAim, vTo);
		if (dot > bestDot)
		{
			bestDot = dot;
			best = i;
		}
	}

	return (best && L4D_IsPlayerIncapacitated(best)) ? best : 0;
}

bool IsClientIndex(int client)
{
	return (client > 0 && client <= MaxClients);
}

int GetZombieClass(int client)
{
	return GetEntData(client, g_iZombieClass);
}

bool IsStartToPounce(int client)
{
	if(g_bL4D2Version)
	{
		int Activity = PlayerAnimState.FromPlayer(client).GetMainActivity();
		if(Activity == L4D2_ACT_TERROR_HUNTER_POUNCE 
			&& g_fPouncingStartTime[client] + 0.09 > GetEngineTime())
		{
			return true;
		}
	}
	else
	{
		int Activity = L4D1_GetMainActivity(client);
		if(Activity == L4D1_ACT_TERROR_HUNTER_POUNCE 
			&& g_fPouncingStartTime[client] + 0.09 > GetEngineTime())
		{
			return true;
		}
	}

	return false;
}

bool IsValidEntityIndex(int entity)
{
	return (MaxClients+1 <= entity <= GetMaxEntities());
}