#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

#define OVERFLOW_SHIELD 5

int g_iCommon[2048];
int g_iTotalCommon;
int g_iLimitCommon;
bool g_bMapStarted;
ConVar g_hCvarLimit;

static const char INFECTED_NAME[]	= "infected";

public Plugin myinfo = 
{
	name = "[L4D & L4D2] Common Limiter",
	author = "SilverShot, HarryPotter",
	description = "Prevents director or map overrides of z_common_limit. Kill common if overflow.",
	version = "1.1",
	url = "http://steamcommunity.com/profiles/76561198026784913"
}

public void OnPluginStart()
{
	g_hCvarLimit = FindConVar("z_common_limit");
	g_hCvarLimit.AddChangeHook(ConVarChanged_Cvars);
	g_iLimitCommon = g_hCvarLimit.IntValue;

	//HookEvent("round_end",		Event_RoundEnd, EventHookMode_PostNoCopy);
	//HookEvent("round_start",	Event_RoundStart, EventHookMode_PostNoCopy);

	LateLoad();
}

void ConVarChanged_Cvars(Handle convar, const char[] oldValue, const char[] newValue)
{
	g_iLimitCommon = g_hCvarLimit.IntValue;
}

public void OnMapStart()
{
	g_bMapStarted = true;
}

public void OnMapEnd()
{
	g_bMapStarted = false;

	ResetPlugin();
}
/*
void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_bMapStarted = true;
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	g_bMapStarted = false;

	ResetPlugin();
}
*/
void LateLoad()
{
	int entity = -1;
	while( (entity = FindEntityByClassname(entity, INFECTED_NAME)) != INVALID_ENT_REFERENCE )
	{
		g_iCommon[entity] = entity;
		g_iTotalCommon++;

		if( g_iTotalCommon > g_iLimitCommon + OVERFLOW_SHIELD )
		{
			RemoveEntity(entity);
		}
	}
}

void ResetPlugin()
{
	for( int i = 0; i < 2048; i++ )
	{
		g_iCommon[i] = 0;
	}

	g_iTotalCommon = 0;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if( entity > 0 && entity < 2048 && strcmp(classname, INFECTED_NAME) == 0 )
	{
		SDKHook(entity, SDKHook_SpawnPost, SpawnPost);
	}
}

public void OnEntityDestroyed(int entity)
{
	if( g_bMapStarted && entity > 0 && entity < 2048 && g_iCommon[entity] == entity )
	{
		g_iCommon[entity] = 0;
		g_iTotalCommon--;
		
		if(g_iTotalCommon < 0) g_iTotalCommon = 0;
	}
}

void SpawnPost(int entity)
{
	// Validate
	if( !IsValidEntity(entity) ) return;

	if( g_bMapStarted )
	{
		g_iCommon[entity] = entity;
		g_iTotalCommon++;

		if( g_iTotalCommon > g_iLimitCommon + OVERFLOW_SHIELD  )
		{
			RemoveEntity(entity);
		}
	}
}
