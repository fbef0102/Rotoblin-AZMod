// deprecated, use l4d_dissolve_infected

/*
*	Ragdoll Fader
*	Copyright (C) 2022 Silvers
*
*	This program is free software: you can redistribute it and/or modify
*	it under the terms of the GNU General Public License as published by
*	the Free Software Foundation, either version 3 of the License, or
*	(at your option) any later version.
*
*	This program is distributed in the hope that it will be useful,
*	but WITHOUT ANY WARRANTY; without even the implied warranty of
*	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*	GNU General Public License for more details.
*
*	You should have received a copy of the GNU General Public License
*	along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/



#define PLUGIN_VERSION 		"1.3"
#define PLUGIN_NAME		    "l4d_ragdoll_fader"
#define DEBUG 0

/*=======================================================================================
	Plugin Info:

*	Name	:	[L4D & L4D2] Ragdoll Fader
*	Author	:	SilverShot, HarryPotter
*	Descrp	:	Fades common infected ragdolls.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=306789
*	Plugins	:	https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:
1.3 (1-Feb-2022) by Harry
	- Add Map on filter option (data/mapinfo.txt support)
	- Add a cvar to enable/disable

1.2 (12-Dec-2022)
	- Changes to fix compile warnings on SourceMod 1.11.

1.1 (20-Jan-2022)
	- Fixed not working on map change. Thanks to "Cloud talk" for reporting.

1.0 (24-Dec-2019)
	- Initial release.

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

int g_iRagdollFader, g_iPlayerSpawn, g_iRoundStart;



// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D & L4D2] Ragdoll Fader",
	author = "SilverShot, HarryPotter",
	description = "Fades common infected/witch/special infected ragdolls.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=306789"
}

bool bLate;
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if( test != Engine_Left4Dead && test != Engine_Left4Dead2 )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}

	bLate = late;
	return APLRes_Success;
}

#define CVAR_FLAGS                    FCVAR_NOTIFY

ConVar g_hCvarEnable;
bool g_bCvarEnable;

static KeyValues g_hMIData = null;

public void OnPluginStart()
{
	g_hCvarEnable = CreateConVar( "l4d_ragdoll_fader_enable",        "1",   "0=Plugin off, 1=Plugin on.", CVAR_FLAGS, true, 0.0, true, 1.0);
	CreateConVar("l4d_ragdoll_fader", PLUGIN_VERSION, "Ragdoll Fader plugin version.", FCVAR_DONTRECORD);
	//AutoExecConfig(true,                PLUGIN_NAME);

	GetCvars();
	g_hCvarEnable.AddChangeHook(ConVarChanged_Cvars);

	HookEvent("round_end",				Event_RoundEnd,		EventHookMode_PostNoCopy); //trigger twice in versus mode, one when all survivors wipe out or make it to saferom, one when first round ends (second round_start begins).
	HookEvent("map_transition", 		Event_RoundEnd,		EventHookMode_PostNoCopy); //all survivors make it to saferoom, and server is about to change next level in coop mode (does not trigger round_end) 
	HookEvent("mission_lost", 			Event_RoundEnd,		EventHookMode_PostNoCopy); //all survivors wipe out in coop mode (also triggers round_end)
	HookEvent("round_start",		Event_RoundStart,	EventHookMode_PostNoCopy);
	HookEvent("player_spawn",		Event_PlayerSpawn,	EventHookMode_PostNoCopy);

	MI_KV_Load();

	if(bLate)
	{
		LateLoad();
	}
}

void LateLoad()
{
    CreateTimer(2.0, TimerLoad, _, TIMER_FLAG_NO_MAPCHANGE);
}

public void OnPluginEnd()
{
	ResetPlugin();
}

//-------------------------------Cvars-------------------------------

public void ConVarChanged_Cvars(ConVar hCvar, const char[] sOldVal, const char[] sNewVal)
{
	GetCvars();
}

void GetCvars()
{
	g_bCvarEnable = g_hCvarEnable.BoolValue;
	if(g_bCvarEnable)
	{
		CreateFader();
	}
	else
	{
		DeleteFader();
	}
}

// ====================================================================================================
//					LOAD RAGDOLL FADER
// ====================================================================================================
void ResetPlugin()
{
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
	DeleteFader();
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	ResetPlugin();
}

bool g_bCrashMap;
bool g_bMapStart;
public void OnMapStart()
{
	g_bMapStart = true;
	g_bCrashMap = false;
	char sMap[64];
	GetCurrentMap(sMap, sizeof(sMap));

	MI_KV_Close();
	MI_KV_Load();
	if (!KvJumpToKey(g_hMIData, sMap)) {
		//LogError("[MI] MapInfo for %s is missing.", g_sCurMap);
	} else
	{
		if (g_hMIData.GetNum("WaterCrash_map", 0) == 1)
		{
			g_bCrashMap = true;
		}
	}
	KvRewind(g_hMIData);
}


public void OnMapEnd()
{
	g_bMapStart = false;
	ResetPlugin();
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if( g_iPlayerSpawn == 1 && g_iRoundStart == 0 )
		CreateTimer(2.0, TimerLoad, _, TIMER_FLAG_NO_MAPCHANGE);
	g_iRoundStart = 1;
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if( g_iPlayerSpawn == 0 && g_iRoundStart == 1 )
		CreateTimer(2.0, TimerLoad, _, TIMER_FLAG_NO_MAPCHANGE);
	g_iPlayerSpawn = 1;
}

Action TimerLoad(Handle timer)
{
	ResetPlugin();

	CreateFader();
	return Plugin_Continue;
}

void CreateFader()
{
	if( !g_bMapStart || !g_bCvarEnable ) 
		return;

	if( g_iRagdollFader && EntRefToEntIndex(g_iRagdollFader) != INVALID_ENT_REFERENCE )
		return;

	if( !g_bCrashMap ) 
		return;

	g_iRagdollFader = CreateEntityByName("func_ragdoll_fader");
	if( g_iRagdollFader != -1 )
	{
		DispatchSpawn(g_iRagdollFader);
		SetEntPropVector(g_iRagdollFader, Prop_Send, "m_vecMaxs", view_as<float>({ 999999.0, 999999.0, 999999.0 }));
		SetEntPropVector(g_iRagdollFader, Prop_Send, "m_vecMins", view_as<float>({ -999999.0, -999999.0, -999999.0 }));
		SetEntProp(g_iRagdollFader, Prop_Send, "m_nSolidType", 2);
		g_iRagdollFader = EntIndexToEntRef(g_iRagdollFader);
	}
}

void DeleteFader()
{
	if( g_iRagdollFader && EntRefToEntIndex(g_iRagdollFader) != INVALID_ENT_REFERENCE )
	{
		AcceptEntityInput(g_iRagdollFader, "Kill");
		g_iRagdollFader = 0;
	}
}


void MI_KV_Load()
{
	char sNameBuff[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sNameBuff, 256, "data/%s", "mapinfo.txt");

	g_hMIData = CreateKeyValues("MapInfo");
	if (!FileToKeyValues(g_hMIData, sNameBuff)) {
		//LogError("[MI] Couldn't load MapInfo data!");
		MI_KV_Close();
	}
}

void MI_KV_Close()
{
	if (g_hMIData != null) {
		CloseHandle(g_hMIData);
		g_hMIData = null;
	}
}