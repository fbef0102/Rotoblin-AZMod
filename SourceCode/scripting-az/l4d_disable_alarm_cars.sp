#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.0"

public Plugin myinfo =
{
	name		= "L4D Disable Alarm Cars before SafeRoom",
	author		= "HarryPotter",
	version		= PLUGIN_VERSION,
	description	= "Disables the Car Alarm before survivors leave the safe room in versus"
};

#define GAMEDATA		"l4d_disable_alarm_cars"
bool bHasLeftSafeRoom, bDisableCars;
int g_iRoundStart, g_iPlayerSpawn, g_iOffset;

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
	Handle hGameData = LoadGameConfigFile(GAMEDATA);
	if( hGameData == null ) SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	g_iOffset = GameConfGetOffset(hGameData, "Alarm_Patch_Offset");
	if( g_iOffset == -1 ) SetFailState("\n==========\nMissing required offset: \"Alarm_Patch_Offset\".\nPlease update your GameData file for this plugin.\n==========");

	delete hGameData;

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_PostNoCopy);
	HookEvent("round_end",		Event_RoundEnd,		EventHookMode_PostNoCopy);
	HookEvent("player_left_start_area", PlayerLeftStartArea);
}

public void OnPluginEnd()
{
	ResetPlugin();
}

public void OnMapEnd()
{
	ResetPlugin();
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	bHasLeftSafeRoom = false;
	bDisableCars = false;

	if( g_iPlayerSpawn == 1 && g_iRoundStart == 0 )
		CreateTimer(0.5, RoundStartDelay, _, TIMER_FLAG_NO_MAPCHANGE);
	g_iRoundStart = 1;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    if( g_iPlayerSpawn == 0 && g_iRoundStart == 1 )
        CreateTimer(0.5, RoundStartDelay, _, TIMER_FLAG_NO_MAPCHANGE);
    g_iPlayerSpawn = 1;
}

public Action RoundStartDelay( Handle timer )
{
	ResetPlugin();
	
	if (bHasLeftSafeRoom) return Plugin_Continue;

	int car = MaxClients+1;
	while ( (car = FindEntityByClassname(car, "prop_car_alarm")) != -1 )
	{
		if ( !IsValidEntity(car) ) {
			continue;
		}

		// Disable the Car Alarm
		SetEntData(car, g_iOffset, 1, 1, false);
	}
	bDisableCars = true;

	return Plugin_Continue;
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	ResetPlugin();
}

public void PlayerLeftStartArea( Event event, const char[] name, bool dontBroadcast )
{
	if (!bHasLeftSafeRoom)
	{
		bHasLeftSafeRoom = true;
		if(!bDisableCars) return;

		int car = MaxClients+1;
		while ( (car = FindEntityByClassname(car, "prop_car_alarm")) != -1 )
		{
			if ( !IsValidEntity(car) ) {
				continue;
			}

			//Enable the Car Alarm
			SetEntData(car, g_iOffset, 0, 1, false);
		}
	}
}

void ResetPlugin()
{
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
}