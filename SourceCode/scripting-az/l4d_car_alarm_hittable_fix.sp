#pragma semicolon 1
#pragma newdecls required

#include <sourcemod> 
#include <sdkhooks> 
#include <sdktools> 

public Plugin myinfo = 
{
	name = "L4D1 Car Alarm Hittable Fix",
	author = "Sir, l4d1 port by Harry",
	description = "Disables the Car Alarm when a Tank hittable hits the alarmed car.",
	version = "1.1",
	url = "nah"
};

#define GAMEDATA		"l4d_car_alarm_hittable_fix"
int g_iOffset;

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
}

public void OnEntityCreated(int entity, const char[] classname) 
{
	// Hook Alarmed Cars.
	if(!StrEqual(classname, "prop_car_alarm")) return; 
	SDKHook(entity, SDKHook_Touch, OnAlarmCarTouch); 
}

public Action OnAlarmCarTouch(int car, int entity) 
{ 
	// Speaks for itself
	if (IsTankHittable(entity))
	{
		// This returns 1 on every hittable at all times.
		if (GetEntProp(entity, Prop_Send, "m_hasTankGlow") > 0)
		{
			// Disable the Car Alarm
			SetEntData(car, g_iOffset, 1, 1, false);

			// Fake damage to Car to stop the glass from still blinking, delay it to prevent issues.
			// It seems not working in l4d1
			// CreateTimer(0.3, DisableAlarm, car);

			// Unhook car, we don't need it anymore.
			SDKUnhook(car, SDKHook_Touch, OnAlarmCarTouch);
		}
	}

	return Plugin_Continue;
}

public Action DisableAlarm(Handle timer, any car)
{
	int Tank = -1;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidTank(i))
		{
			Tank = i;
			break;
		}
	}

	if (Tank != -1) SDKHooks_TakeDamage(car, Tank, Tank, 0.0);

	return Plugin_Continue;
}

stock bool IsValidTank(int client) 
{ 
    if (client <= 0 || client > MaxClients || !IsClientConnected(client)) return false;
    return (IsClientInGame(client) && GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == 8); 
}

stock bool IsTankHittable(int iEntity)
{
	if (!IsValidEntity(iEntity)) 
	{
		return false;
	}
	
	char className[64];
	
	GetEdictClassname(iEntity, className, sizeof(className));
	if (StrEqual(className, "prop_physics")) 
	{
		if (GetEntProp(iEntity, Prop_Send, "m_hasTankGlow", 1)) return true;
	}
	else if (StrEqual(className, "prop_car_alarm")) return true;
	
	return false;
}