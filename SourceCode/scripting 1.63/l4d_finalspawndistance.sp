#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <l4d_direct>
#include <l4d_lib>

static	const			GHOST_SPAWN_STATE_TOO_CLOSE = 256;
static	const			GHOST_SPAWN_STATE_SPAWN_READY = 0;

static	const			MIN_SPAWN_RANGE = 150;

static			bool:	g_bIsFinaleActive = false;
static			Handle:g_hFnalSpawn, bool:g_bCvarFinalSpawn;
new SurvivorIndex[MAXPLAYERS + 1];

public Plugin:myinfo =
{
	name        = "final spawn distance",
	author      = "Harry Potter",
	description = "Reduces the SI spawning range on finales to normal spawning range",
	version     = "1.0",
	url         = ""
};

public OnPluginStart()
{
	g_hFnalSpawn = CreateConVar("finalspawn_range",	"1", "Reduces the SI spawning range on finales to normal spawning range", _, true, 0.0, true, 1.0);
	if (g_hFnalSpawn == INVALID_HANDLE) 
	{
		ThrowError("Unable to create finalspawn_range cvar!");
	}
	
	HookEvent("round_end", OnRoundChange_Event, EventHookMode_PostNoCopy);
	HookEvent("round_start", OnRoundChange_Event, EventHookMode_PostNoCopy);
	HookEvent("finale_start", OnFinaleStart_Event, EventHookMode_PostNoCopy);
	HookConVarChange(g_hFnalSpawn, FinalSpawn_CvarChange);
	Get_Cvars();
}
public OnRoundChange_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (g_bIsFinaleActive)
		HookOrUnhookPreThinkPost(false);

	g_bIsFinaleActive = false;
}

public OnFinaleStart_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!g_bIsFinaleActive)
		HookOrUnhookPreThinkPost(true);

	g_bIsFinaleActive = true;
}


public OnClientPutInServer(client)
{
	if (g_bIsFinaleActive && g_bCvarFinalSpawn && !IsFakeClient(client))
		SDKHook(client, SDKHook_PreThinkPost, SDKh_OnPreThinkPost);
}


public SDKh_OnPreThinkPost(client)
{
	if (!IsClientInGame(client) ||
		GetClientTeam(client) != 3 ||
		!IsPlayerGhost(client))
		return;

	if (GetGhostSpawnState(client) == GHOST_SPAWN_STATE_TOO_CLOSE)
	{
		if (!IsGhostTooCloseToSurvivors(client))
		{
			SetPlayerGhostSpawnState(client, GHOST_SPAWN_STATE_SPAWN_READY);
		}
	}
}


static bool:IsGhostTooCloseToSurvivors(client)
{
	decl Float:survivorOrigin[3];
	decl Float:ghostOrigin[3];
	decl Float:fVector[3];
	GetClientAbsOrigin(client, ghostOrigin);
	
	new SurvivorCount = 0;
	
	for (new i = 1; i <= MaxClients; i++) //clear both fake and real just because
	{
		if(IsClientInGame(i)&&GetClientTeam(i)==2)
		{
			SurvivorIndex[SurvivorCount]=i;
			SurvivorCount++;
		}	
	}
	
	for (new i = 0; i < SurvivorCount; i++)
	{
		if (SurvivorIndex[i] <= 0 || !IsClientInGame(SurvivorIndex[i]) || !IsPlayerAlive(SurvivorIndex[i])) continue;
		GetClientAbsOrigin(SurvivorIndex[i], survivorOrigin);

		MakeVectorFromPoints(ghostOrigin, survivorOrigin, fVector);

		if (GetVectorLength(fVector) <= MIN_SPAWN_RANGE) return true;
	}
	return false;
}


static SetPlayerGhostSpawnState(client, spawnState)
{
	SetEntProp(client, Prop_Send, "m_ghostSpawnState", spawnState);
}

public FinalSpawn_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (StrEqual(oldValue, newValue)) return;
	
	if (g_bIsFinaleActive){

		if (g_bCvarFinalSpawn)
			HookOrUnhookPreThinkPost(false);
		else
			HookOrUnhookPreThinkPost(true);
	}

	Get_Cvars();
}

static HookOrUnhookPreThinkPost(bool:bHook)
{
	if (!g_bCvarFinalSpawn) return;

	for (new client = 1; client <= MaxClients; client++){

		if (!IsClientInGame(client) || IsFakeClient(client)) continue;

		if (bHook)
			SDKHook(client, SDKHook_PreThinkPost, SDKh_OnPreThinkPost);
		else
			SDKUnhook(client, SDKHook_PreThinkPost, SDKh_OnPreThinkPost);
	}
}

static Get_Cvars()
{
	g_bCvarFinalSpawn = GetConVarBool(g_hFnalSpawn);
}