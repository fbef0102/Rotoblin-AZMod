//you should checkout http://downloadtzz.firewall-gateway.com/ for free programs and basicpawn autocomplete func ect

#include <sourcemod>
#include <sdktools>
#pragma semicolon 1

#define PLUGIN_VERSION "1.0"


new Handle:hCvar_RandomWitchEnable = INVALID_HANDLE;

new bool:g_bRandomWitch = false;

public Plugin:myinfo = 
{
	name = "RandomWitch",
	author = "Ludastar (Armonic)",
	description = "Just Adds the 50% Chance between each witch model",
	version = PLUGIN_VERSION,
	url = "http://steamcommunity.com/id/ArmonicJourney"
}



public OnPluginStart()
{
	CreateConVar("RandomWitch", PLUGIN_VERSION, "Version of RandomWitch", FCVAR_SPONLY|FCVAR_DONTRECORD);

	hCvar_RandomWitchEnable = CreateConVar("RW_Enable", "1", "Should We Enable Random Witch", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	
	HookConVarChange(hCvar_RandomWitchEnable, eConvarsChanged);
	
	CvarsChanged();
	
	HookEvent("witch_spawn", eWitchSpawn);
}

public OnMapStart()
{
	PrecacheModel("models/infected/witch.mdl", true);
	PrecacheModel("models/infected/witch_bride.mdl", true);
	CvarsChanged();
}

public eConvarsChanged(Handle:hCvar, const String:sOldVal[], const String:sNewVal[])
{
	CvarsChanged();
}

CvarsChanged()
{
	g_bRandomWitch = GetConVarInt(hCvar_RandomWitchEnable) > 0;
}

public Action:eWitchSpawn(Handle:hEvent, const String:sName[], bool:dontBroadcast)
{
	if(!g_bRandomWitch)
	return;

	switch(GetRandomInt(1, 10))
	{
		case 10:
		{
			new iWitch = GetEventInt(hEvent, "witchid");
			SetEntityModel(iWitch, "models/infected/witch_bride.mdl");// unless your killing the witch in the same frame she is created which can be bad then you should be fine
		}
	}
}


