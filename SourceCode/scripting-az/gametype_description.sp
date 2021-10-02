#pragma semicolon 1
#include <sourcemod>
#include <sdkhooks>


new bool:g_IsMapLoaded;
new Handle:cvarGameTypeName;

public Plugin:myinfo = 
{
	name = "Change Game type in server list",
	author = "Harry Potter",
	description = "Allows changing of displayed game type in server browser",
	version = "1.0",
	url = "http://steamcommunity.com/profiles/76561198026784913"
}

public OnPluginStart()
{
	cvarGameTypeName = CreateConVar("l4d_game_type_name", "L4D - Harry Potter", "Game Type Name",FCVAR_NOTIFY);
}

public Action:OnGetGameDescription(String:gameDescription[64])
{
	if (g_IsMapLoaded)
	{
		decl String:GameName[64];
		GetConVarString(cvarGameTypeName, GameName, sizeof(GameName));
		strcopy(gameDescription, sizeof(gameDescription), GameName); // edit and compile
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public OnMapStart()
{
	g_IsMapLoaded = true;
}

public OnMapEnd()
{
	g_IsMapLoaded = false;
}

