#pragma semicolon 1
#pragma newdecls required

#include <sourcemod> 
#include <sdktools> 
#include <sdkhooks>

ConVar 
	g_hCarAlarmSettings,
	g_hCarTouchCapped,
	g_hCarAI;
int FLAGS[3] = {
	1 << 0, // Trigger Car Alarm on Survivor Touch
	1 << 1, // Trigger Car Alarm disabled when hit by another Hittable.
};
int iFlags;
bool bCarTouchCapped;
bool bAI;
public Plugin myinfo = 
{
	name = "L4D2 Car Alarm Fixes",
	author = "Sir & Silvers (Gamedata and general idea from l4d_car_alarm_bots), l4d1 port by Harry",
	description = "Disables the Car Alarm when a Tank hittable hits the alarmed car and makes sure the Car Alarm triggers whenever a Survivor touches it",
	version = "1.2",
	url = "https://github.com/SirPlease/L4D2-Competitive-Rework"
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

	g_hCarAlarmSettings = CreateConVar("l4d2_car_alarm_settings", "3", "Bitmask: 1-Trigger Alarm on Survivor Touch/ 2-Disable Alarm when a Hittable hits the Alarm Car", FCVAR_NOTIFY);
	g_hCarTouchCapped   = CreateConVar("l4d2_car_alarm_touch_capped", "0", "Only add the additional car alarm trigger when the Survivor is capped by an Infected when touching the car? (Requires bitmask settings)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hCarAI            = CreateConVar("l4d2_car_alarm_touch_ai", "0", "Care about AI Survivors touching the car? (Default vanilla = 0) Requires bitmask settings", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	iFlags          = g_hCarAlarmSettings.IntValue;
	bCarTouchCapped = g_hCarTouchCapped.BoolValue;
	bAI             = g_hCarAI.BoolValue;
	g_hCarAlarmSettings.AddChangeHook(ChangedConVars);
	g_hCarTouchCapped.AddChangeHook(ChangedConVars);
	g_hCarAI.AddChangeHook(ChangedConVars);
}

public void OnEntityCreated(int entity, const char[] classname) 
{
	if(strcmp(classname, "prop_car_alarm") == 0)
	  SDKHook(entity, SDKHook_Touch, OnTouch);
}

public void OnTouch(int car, int other)
{
	// Is the other entity a Survivor?
	if ((iFlags & FLAGS[0]) && other >= 1 && other <= MaxClients && GetClientTeam(other) == 2)
{ 
		// We don't want the AI to trigger the car alarm.
		if (!bAI && IsFakeClient(other))
		  return;
		// We only care about capped players touching the car.
		if (bCarTouchCapped && !IsPlayerCapped(other))
		  return;

		AcceptEntityInput(car, "SurvivorStandingOnCar", other, other);

		// Unhook car, we don't need it anymore.
		SDKUnhook(car, SDKHook_Touch, OnTouch);
	}
	// Is the other entity a Hittable car?
	else if ((iFlags & FLAGS[1]) && IsTankHittable(other))
	{
		// This returns 1 on every hittable at all times.
		if (GetEntProp(other, Prop_Send, "m_hasTankGlow") > 0)
		{
			// Disable the Car Alarm
			SetEntData(car, g_iOffset, 1, 1, false);

			// Fake damage to Car to stop the glass from still blinking, delay it to prevent issues.
			// It seems not working in l4d1
			// CreateTimer(0.3, DisableAlarm, car);

			// Unhook car, we don't need it anymore.
			SDKUnhook(car, SDKHook_Touch, OnTouch);
		}
	}

}
/*
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

	if (Tank != -1) 
	  SDKHooks_TakeDamage(car, Tank, Tank, 0.0);

	return Plugin_Continue;
}
*/
// ====================================================================================================
//					STOCKS
// ====================================================================================================
stock bool IsValidTank(int client) 
{ 
    if (client <= 0 || client > MaxClients || !IsClientConnected(client)) return false;
    return (IsClientInGame(client) && GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == 8); 
}

stock bool IsTankHittable(int iEntity)
{
	if (!IsValidEntity(iEntity)) 
		return false;
	
	char className[64];
	
	GetEdictClassname(iEntity, className, sizeof(className));
	if (strncmp(className, "prop_physics", 12, false) == 0) 
	{
		if (GetEntProp(iEntity, Prop_Send, "m_hasTankGlow", 1)) 
		  return true;
	}
	else if (strncmp(className, "prop_car_alarm", 14, false) == 0) 
	  return true;
	
	return false;
}
stock bool IsPlayerCapped(int client)
{
	if (GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0)
	  return true;

	return false;
}
void ChangedConVars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	iFlags          = g_hCarAlarmSettings.IntValue;
	bCarTouchCapped = g_hCarTouchCapped.BoolValue;
	bAI             = g_hCarAI.BoolValue;
}