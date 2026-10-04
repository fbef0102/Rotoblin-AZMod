#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <dhooks>
#include <sdkhooks>
#include <@Forgetest/gamedatawrapper>

public Plugin myinfo = 
{
	name = "[L4D1/L4D2] Remove UpdateNeighbors on Witch",
	author = "Forgetest",
	description = "Commons can go through Witches without pushing them away",
	version = "1.0-2026/10/5",
	url = "https://github.com/jensewe"
}

#define MAXENTITIES                   2048

DynamicHook g_hook_MyInfectedPointer;
bool g_bIsWitch[MAXENTITIES+1];

public void OnPluginStart()
{
	GameDataWrapper gd = new GameDataWrapper("l4d_witch_collisions");

	g_hook_MyInfectedPointer = gd.CreateDHookOrFail("l4d_witch_collisions::MyInfectedPointer");

	delete gd.CreateDetourOrFail("l4d_witch_collisions::Infected::UpdateNeighbors", DTR_UpdateNeighbors, DTR_UpdateNeighbors_Post);
	delete gd;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (!IsValidEntityIndex(entity))
		return;

	g_bIsWitch[entity] = false;
	if (classname[0] == 'w' && !strcmp(classname, "witch", false))
	{
		g_hook_MyInfectedPointer.HookEntity(Hook_Pre, entity, DTR_MyInfectedPointer);
		g_bIsWitch[entity] = true;
	}
}

bool g_bUpdateNeighbors = false;
MRESReturn DTR_UpdateNeighbors(int entity)
{
	if (g_bIsWitch[entity])
		return MRES_Supercede;
	
	g_bUpdateNeighbors = true;
	return MRES_Ignored;
}

MRESReturn DTR_UpdateNeighbors_Post(int entity)
{
	g_bUpdateNeighbors = false;
	return MRES_Ignored;
}

static bool once = false;

MRESReturn DTR_MyInfectedPointer(int entity, DHookReturn hReturn)
{
	if (g_bUpdateNeighbors)
	{
		if (!once)
		{
			once = true;
		}

		hReturn.Value = Address_Null;
		return MRES_Supercede;
	}
	return MRES_Ignored;
}

/*stock bool IsEntityClassname(int entity, const char[] classname)
{
	int len = strlen(classname);
	if (len == 0)
		return false;

	char buffer[64];
	GetEntityClassname(entity, buffer, sizeof(buffer));
	return classname[len-1] == '*' ? !strncmp(buffer, classname, len-1) : !strcmp(buffer, classname);
}
*/

bool IsValidEntityIndex(int entity)
{
	return (MaxClients+1 <= entity <= GetMaxEntities());
}