#pragma semicolon 1
#include <sourcemod>
#define PLUGIN_VERSION "1.2"
new Handle:g_ConVarHibernate;
new Handle:g_ConVarSbAllGame;

public Plugin:myinfo = 
{
	name		= "serverLoader",
	author		= "Harry Potter",
	description	= "executes cfg file on server startup",
	version		= PLUGIN_VERSION,
}

new Handle:cvarLoaderCfg = INVALID_HANDLE;

public OnPluginStart()
{	
	g_ConVarHibernate = FindConVar("sv_hibernate_when_empty");
	g_ConVarSbAllGame = FindConVar("sb_all_bot_team");
	cvarLoaderCfg = CreateConVar("server_startup_loader", "server_startup.cfg", "config that gets executed on server start.[-1=Disable]");
	
	SetConVarInt(g_ConVarSbAllGame,1);
	SetConVarInt(g_ConVarHibernate,0);
}

public OnConfigsExecuted()
{
	decl String:loaderCfgString[128];
	GetConVarString(cvarLoaderCfg, loaderCfgString, 128);
	if(!StrEqual(loaderCfgString, "-1", false))
	{
		CreateTimer(5.0, execConfig, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action:execConfig(Handle:timer)
{
	decl String:loaderCfgString[128];
	GetConVarString(cvarLoaderCfg, loaderCfgString, 128);
	if (!StrEqual(loaderCfgString, "-1", false))
	{
		ServerCommand("exec %s", loaderCfgString);
		LogMessage("executed %s", loaderCfgString);
		SetConVarString(cvarLoaderCfg, "-1"); //we disable the convar to prevent second time execute
	}
	else
	{
		LogMessage("no config or invalid config specified, no configs were loaded.");
	}
}

