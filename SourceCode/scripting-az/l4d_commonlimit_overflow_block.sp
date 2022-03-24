#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define OVERFLOW_SHIELD 8

int iCommonLimit;

ConVar hCommonLimit;

static const char INFECTED_NAME[]	= "infected";

public Plugin myinfo = 
{
	name = "Overflow common limit blocker",
	author = "HarryPitter",
	description = "Prevents director or map overrides of z_common_limit. Kill common if overflow.",
	version = "1.0",
	url = "http://steamcommunity.com/profiles/76561198026784913"
}

public void OnPluginStart()
{
	hCommonLimit = FindConVar("z_common_limit");

	iCommonLimit = hCommonLimit.IntValue;
	
	HookConVarChange(hCommonLimit, Cvar_CommonLimitChange);
}

bool g_bCheckMap;
public void OnMapStart()
{
    char sMap[64];
    g_bCheckMap = false;
    GetCurrentMap(sMap, 64);

    if( strcmp(sMap, "l4d_dbd_clean_up") == 0 )
    {
        g_bCheckMap = true;
    }
}

public void OnMapEnd()
{
	g_bCheckMap = false;
}

public void Cvar_CommonLimitChange(ConVar hCvar, const char[] oldValue, const char[] newValue)
{
	iCommonLimit = hCommonLimit.IntValue;
}

public void OnEntityCreated(int entity, const char[] classname)
{
    if (!IsValidEntityIndex(entity) || !g_bCheckMap)
        return;

    if (StrEqual(classname, INFECTED_NAME))
        RequestFrame(OnNextFrame, EntIndexToEntRef(entity));
}

public void OnNextFrame(int entityRef)
{
    int entity = EntRefToEntIndex(entityRef);

    if (entity == INVALID_ENT_REFERENCE)
        return;

    int sum = 0, common = MaxClients + 1;
    while ((common = FindEntityByClassname(common, INFECTED_NAME)) != INVALID_ENT_REFERENCE)
    {
        if(GetEntProp(common, Prop_Data, "m_iHealth") < 0) continue;

        sum++;
    }

    if(sum > iCommonLimit + OVERFLOW_SHIELD)
    {
        //PrintToChatAll("commons: %d", sum);
        AcceptEntityInput(entity, "Kill");
    }
}

bool IsValidEntityIndex(int entity)
{
	return (MaxClients+1 <= entity <= GetMaxEntities());
}
