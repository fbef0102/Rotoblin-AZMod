//Each round tank/Witch spawn same position and angle for both team
//data/mapinfo.txt to ban tank/witch flow
//The Author: Harry Potter
//Only for L4D1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <l4d_lib>
#include <left4dhooks>

#pragma semicolon 1
#define PLUGIN_VERSION "1.6"

#define INTRO		0
#define REGULAR	1
#define FINAL		2
#define TANK		0
#define WITCH		1
#define MIN		0
#define MAX		1

static Handle:g_hCvarVsBossChance[3][2], Handle:g_hCvarVsBossFlow[3][2], Float:g_fCvarVsBossChance[3][2], Float:g_fCvarVsBossFlow[3][2];
static	bool:g_bFixed,Float:g_fTankData_origin[3],Float:g_fTankData_angel[3];
static 	Float:fWitchData_agnel[3],Float:fWitchData_origin[3];
static	bool:Tank_firstround_spawn,bool:Witch_firstround_spawn;
float g_fWitchFlow, g_fTankFlow;
int g_iRoundStart, g_iPlayerSpawn;
ConVar WITCHPARTY, sv_cheats;
ConVar g_hCvarWitchAvoidTank, g_hCvarBossDisable;
ConVar survivor_limit;
int survivor_limit_value;

static KeyValues g_hMIData = null;

ArrayList hValidTankFlows;
ArrayList hValidWitchFlows;

native bool IsWitchRestore(); // from l4d2_witch_restore
native float GetSurCurrentFloat(); // from l4d_current_survivor_progress
native void SaveBossPercents(); // from l4d_boss_percent

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	
	if( test != Engine_Left4Dead )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1.");
		return APLRes_SilentFailure;
	}

	CreateNative("SaveWitchPercent",Native_SaveWitchPercent);
	return APLRes_Success;
}

public Native_SaveWitchPercent(Handle:plugin, numParams) {
	float num1 = GetNativeCell(1);
	g_fWitchFlow = num1;
}

public Plugin:myinfo = 
{
	name = "l4d_versus_same_UnprohibitBosses",
	author = "Harry Potter",
	description = "Force Enable bosses spawning on all maps, and same spawn positions for both team",
	version = PLUGIN_VERSION,
	url = "http://steamcommunity.com/profiles/76561198026784913"
}

public void OnPluginStart()
{
	survivor_limit = FindConVar("survivor_limit");
	survivor_limit_value = survivor_limit.IntValue;
	survivor_limit.AddChangeHook(ConVarChanged);

	//強制每一關生出tank與witch
	g_hCvarVsBossChance[INTRO][TANK] = FindConVar("versus_tank_chance_intro");
	g_hCvarVsBossChance[REGULAR][TANK] = FindConVar("versus_tank_chance");
	g_hCvarVsBossChance[FINAL][TANK] = FindConVar("versus_tank_chance_finale");
	g_hCvarVsBossChance[INTRO][WITCH] = FindConVar("versus_witch_chance_intro");
	g_hCvarVsBossChance[REGULAR][WITCH] = FindConVar("versus_witch_chance");
	g_hCvarVsBossChance[FINAL][WITCH] = FindConVar("versus_witch_chance_finale");
	g_hCvarVsBossFlow[INTRO][MIN]  = FindConVar("versus_boss_flow_min_intro");
	g_hCvarVsBossFlow[INTRO][MAX] = FindConVar("versus_boss_flow_max_intro");
	g_hCvarVsBossFlow[REGULAR][MIN] = FindConVar("versus_boss_flow_min");
	g_hCvarVsBossFlow[REGULAR][MAX] = FindConVar("versus_boss_flow_max");
	g_hCvarVsBossFlow[FINAL][MIN] = FindConVar("versus_boss_flow_min_finale");
	g_hCvarVsBossFlow[FINAL][MAX] = FindConVar("versus_boss_flow_max_finale");
	for (new campaign; campaign < 3; campaign++){

		for (new index; index < 2; index++){

			g_fCvarVsBossChance[campaign][index] = GetConVarFloat(g_hCvarVsBossChance[campaign][index]);
			g_fCvarVsBossFlow[campaign][index] = GetConVarFloat(g_hCvarVsBossFlow[campaign][index]);

			HookConVarChange(g_hCvarVsBossChance[campaign][index], _UB_Common_CvarChange);
			HookConVarChange(g_hCvarVsBossFlow[campaign][index], _UB_Common_CvarChange);
		}
	}

	HookEvent("tank_spawn",			TS_ev_TankSpawn,		EventHookMode_PostNoCopy);
	HookEvent("player_spawn", 	Event_PlayerSpawn,	EventHookMode_PostNoCopy);
	HookEvent("round_start", 	Event_RoundStart, 	EventHookMode_PostNoCopy);
	HookEvent("round_end",		Event_RoundEnd,		EventHookMode_PostNoCopy);
	HookEvent("witch_spawn", TS_ev_WitchSpawn);

	g_hCvarWitchAvoidTank = CreateConVar("l4d_boss_avoid_tank_spawn", "0", "Minimum flow amount witches should avoid tank spawns by, by half the value given on either side of the tank spawn (Def: 20)", FCVAR_NOTIFY, true, 0.0, true, 100.0);
	g_hCvarBossDisable = CreateConVar("sm_1_survivor_boss_disable", "1", "If 1, Disable Tank/Witch Spawn when survivor limit is 1.", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	hValidTankFlows = new ArrayList(2);
	hValidWitchFlows = new ArrayList(2);

	MI_KV_Load();
}

public void ConVarChanged(Handle convar, const char[] oldValue, const char[] newValue)
{
	survivor_limit_value = survivor_limit.IntValue;
}

public void OnPluginEnd()
{
	ResetPlugin();

	delete hValidTankFlows;
	delete hValidWitchFlows;
	
	MI_KV_Close();
}

public void OnAllPluginsLoaded()
{
	WITCHPARTY = FindConVar("l4d_multiwitch_enabled");
	sv_cheats = FindConVar("sv_cheats");
}

char g_sCurMap[64];
bool g_bTankVaildMap, g_bWitchValidMap;
public OnMapStart()
{
	g_bTankVaildMap = true;
	g_bWitchValidMap = true;
	GetCurrentMap(g_sCurMap, 64);

	MI_KV_Close();
	MI_KV_Load();
	if (!KvJumpToKey(g_hMIData, g_sCurMap)) {
		//LogError("[MI] MapInfo for %s is missing.", g_sCurMap);
	} else
	{
		if (g_hMIData.GetNum("tank_map_off", 0) == 1)
		{
			g_bTankVaildMap = false;
		}

		if (g_hMIData.GetNum("witch_map_off", 0) == 1)
		{
			g_bWitchValidMap = false;
		}
	}
	KvRewind(g_hMIData);
}

public void OnMapEnd()
{
	ResetPlugin();

	KvRewind(g_hMIData);
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	if( g_iPlayerSpawn == 1 && g_iRoundStart == 0 )
		CreateTimer(2.0, COLD_DOWN, _, TIMER_FLAG_NO_MAPCHANGE);
	g_iRoundStart = 1;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if( g_iPlayerSpawn == 0 && g_iRoundStart == 1 )
		CreateTimer(2.0, COLD_DOWN, _, TIMER_FLAG_NO_MAPCHANGE);
	g_iPlayerSpawn = 1;
}

public Action:COLD_DOWN(Handle:timer)
{
	ResetPlugin();

	if (InSecondHalfOfRound())
	{
		if(g_fTankFlow <= 0.0)
		{
			L4D2Direct_SetVSTankFlowPercent(1, 0.0);
			L4D2Direct_SetVSTankToSpawnThisRound(1, false);
		}

		if(g_fWitchFlow <= 0.0)
		{
			L4D2Direct_SetVSWitchFlowPercent(1, 0.0);
			L4D2Direct_SetVSWitchToSpawnThisRound(1, false);
		}
		else
		{
			L4D2Direct_SetVSWitchFlowPercent(1, 0.2);
			L4D2Direct_SetVSWitchFlowPercent(1, g_fWitchFlow);
			L4D2Direct_SetVSWitchToSpawnThisRound(1, false);
			L4D2Direct_SetVSWitchToSpawnThisRound(1, true);
		}
	}
	else
	{
		KvJumpToKey(g_hMIData, g_sCurMap);

		hValidTankFlows.Clear();
		hValidWitchFlows.Clear();
		g_fTankFlow = g_fWitchFlow = 0.0;
		float fSurvivorflow = GetSurCurrentFloat();

		//強制每一關生出tank與witch
		int iCampaign = (L4D_IsMissionFinalMap())? FINAL : (L4D_IsFirstMapInScenario())? INTRO : REGULAR;
		int iCvarMinFlow = RoundFloat(g_fCvarVsBossFlow[iCampaign][MIN] * 100);
		int iCvarMaxFlow = RoundFloat(g_fCvarVsBossFlow[iCampaign][MAX] * 100);
		iCvarMinFlow = L4D_GetMapValueInt("versus_boss_flow_min", iCvarMinFlow);
		iCvarMaxFlow = L4D_GetMapValueInt("versus_boss_flow_max", iCvarMaxFlow);

		if( !(g_hCvarBossDisable.BoolValue && survivor_limit_value == 1) )
		{
			if (g_bTankVaildMap == true)
			{
				ArrayList hBannedFlows = new ArrayList(2);
				
				int interval[2];
				interval[0] = 0, interval[1] = iCvarMinFlow - 1;
				if (IsValidInterval(interval)) hBannedFlows.PushArray(interval);
				interval[0] = iCvarMaxFlow + 1, interval[1] = 100;
				if (IsValidInterval(interval)) hBannedFlows.PushArray(interval);
			
				KeyValues kv = new KeyValues("tank_ban_flow");
				L4D_CopyMapSubsection(kv, "tank_ban_flow");
				
				if (kv.GotoFirstSubKey()) {
					do {
						interval[0] = kv.GetNum("min", -1);
						interval[1] = kv.GetNum("max", -1);
						if (IsValidInterval(interval)) hBannedFlows.PushArray(interval);
					} while (kv.GotoNextKey());
				}
				delete kv;
				
				MergeIntervals(hBannedFlows);
				MakeComplementaryIntervals(hBannedFlows, hValidTankFlows);
				
				delete hBannedFlows;
				
				// check each array index to see if it is within a ban range
				int iValidSpawnTotal = hValidTankFlows.Length;
				int iTankFlow;
				if (iValidSpawnTotal == 0) {
					iTankFlow = -1;
					//PrintToChatAll("[AdjustBossFlow] Ban range covers entire flow range. Flow tank disabled.");
				}
				else {
					iTankFlow = GetRandomIntervalNum(hValidTankFlows);
				}

				g_fTankFlow = (float(iTankFlow)/100);
				//LogMessage("fSurvivorflow: %.3f - g_fTankFlow: %.3f", fSurvivorflow, g_fTankFlow);
			}
		}

		if (g_fTankFlow > 0.0)
		{
			if ( g_fTankFlow > 0.0 && 0.01 < fSurvivorflow < 1 && g_fTankFlow < fSurvivorflow) g_fTankFlow = fSurvivorflow;
			
			L4D2Direct_SetVSTankFlowPercent(0, g_fTankFlow);
			L4D2Direct_SetVSTankFlowPercent(1, g_fTankFlow);
			L4D2Direct_SetVSTankToSpawnThisRound(0, true);
			L4D2Direct_SetVSTankToSpawnThisRound(1, true);
		}
		else
		{
			L4D2Direct_SetVSTankFlowPercent(0, 0.0);
			L4D2Direct_SetVSTankFlowPercent(1, 0.0);
			L4D2Direct_SetVSTankToSpawnThisRound(0, false);
			L4D2Direct_SetVSTankToSpawnThisRound(1, false);	
		}

		if( !(g_hCvarBossDisable.BoolValue && survivor_limit_value == 1) )
		{
			if (g_bWitchValidMap == true && !IsWitchProhibit())
			{
				ArrayList hBannedFlows = new ArrayList(2);
				
				int interval[2];
				interval[0] = 0, interval[1] = iCvarMinFlow - 1;
				if (IsValidInterval(interval)) hBannedFlows.PushArray(interval);
				interval[0] = iCvarMaxFlow + 1, interval[1] = 100;
				if (IsValidInterval(interval)) hBannedFlows.PushArray(interval);
			
				KeyValues kv = new KeyValues("witch_ban_flow");
				L4D_CopyMapSubsection(kv, "witch_ban_flow");
				
				if (kv.GotoFirstSubKey()) {
					do {
						interval[0] = kv.GetNum("min", -1);
						interval[1] = kv.GetNum("max", -1);
						if (IsValidInterval(interval)) hBannedFlows.PushArray(interval);
					} while (kv.GotoNextKey());
				}
				delete kv;
				
				if (GetTankAvoidInterval(interval))
				{
					//PrintToChatAll("[AdjustBossFlow] tank avoid (%i, %i)", interval[0], interval[1]);
					if (IsValidInterval(interval)) hBannedFlows.PushArray(interval);
				}
				
				MergeIntervals(hBannedFlows);
				MakeComplementaryIntervals(hBannedFlows, hValidWitchFlows);
				
				delete hBannedFlows;
				
				// check each array index to see if it is within a ban range
				int iValidSpawnTotal = hValidWitchFlows.Length;
				int iWitchFlow;
				if (iValidSpawnTotal == 0) {
					iWitchFlow = -1;
					//PrintToChatAll("[AdjustBossFlow] Ban range covers entire flow range. Flow witch disabled.");
				}
				else {
					iWitchFlow = GetRandomIntervalNum(hValidWitchFlows);
				}

				g_fWitchFlow = (float(iWitchFlow)/100);
				//LogMessage("fSurvivorflow: %.3f - g_fWitchFlow: %.3f", fSurvivorflow, g_fWitchFlow);
			}
		}

		if(g_fWitchFlow > 0.0)
		{
			if ( 0.01 < fSurvivorflow < 1 && g_fWitchFlow < fSurvivorflow) g_fWitchFlow = fSurvivorflow;
			
			L4D2Direct_SetVSWitchFlowPercent(0, g_fWitchFlow);
			L4D2Direct_SetVSWitchFlowPercent(1, g_fWitchFlow);
			L4D2Direct_SetVSWitchToSpawnThisRound(0, true);
			L4D2Direct_SetVSWitchToSpawnThisRound(1, true);
		}
		else
		{
			L4D2Direct_SetVSWitchFlowPercent(0, 0.0);
			L4D2Direct_SetVSWitchFlowPercent(1, 0.0);
			L4D2Direct_SetVSWitchToSpawnThisRound(0, false);
			L4D2Direct_SetVSWitchToSpawnThisRound(1, false);	
		}
		
		//強制tank出生在一樣的位置
		g_bFixed = false;
		Tank_firstround_spawn = false;
		ClearVec();
		
		//強制witch出生在一樣的位置
		Witch_firstround_spawn = false;
	}

	SaveBossPercents();
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	ResetPlugin();
}

static bool IsWitchProhibit()
{
	if(WITCHPARTY != null && WITCHPARTY.IntValue == 1)
		return true;

	return false;
}

public _UB_Common_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (StrEqual(oldValue, newValue)) return;

	for (new campaign; campaign < 3; campaign++){

		for (new index; index < 2; index++){

			if (g_hCvarVsBossChance[campaign][index] == convar)
				g_fCvarVsBossChance[campaign][index] = GetConVarFloat(convar);
			else if (g_hCvarVsBossFlow[campaign][index] == convar)
				g_fCvarVsBossFlow[campaign][index] = GetConVarFloat(convar);
		}
	}
}

public TS_ev_WitchSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	if( IsWitchProhibit() || sv_cheats.IntValue == 1 ) return;
	
	new iEnt = GetEventInt(event, "witchid");
	if(InSecondHalfOfRound() == false)
	{
		if(Witch_firstround_spawn == false)
		{
			GetEntPropVector(iEnt, Prop_Send, "m_angRotation", fWitchData_agnel);
			GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", fWitchData_origin);
			Witch_firstround_spawn = true;
			
			//PrintToChatAll("Witch first position: %f, %f, %f", fWitchData_origin[0], fWitchData_origin[1], fWitchData_origin[2]);
			//PrintToChatAll("Witch first angel: %f, %f, %f", fWitchData_agnel[0], fWitchData_agnel[1], fWitchData_agnel[2]);
		}
	}
	else
	{
		if(Witch_firstround_spawn)
		{
			Witch_firstround_spawn = false;
			//TeleportEntity(iEnt, fWitchData_origin, fWitchData_agnel, NULL_VECTOR); //not working on sitting witch after 2022 l4d1 update
			RemoveEntity(iEnt);
			L4D2_SpawnWitch(fWitchData_origin, fWitchData_agnel);
			//PrintToChatAll("轉換妹子到第一回合的位置");
		}
	}
}

public Action:ColdDown(Handle:timer,any:witchid)
{
	if(IsValidEntity(witchid))
		RemoveEdict(witchid);
}

public Action:TS_ev_TankSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!InSecondHalfOfRound())
	{
		if(!Tank_firstround_spawn){
			new iTank = IsTankInGame();
			if (iTank){
				GetEntPropVector(iTank, Prop_Send, "m_angRotation", g_fTankData_angel);
				GetEntPropVector(iTank, Prop_Send, "m_vecOrigin", g_fTankData_origin);
				//PrintToChatAll("round1 tank pos: %.1f %.1f %.1f", vector[0], vector[1], vector[2]);
				Tank_firstround_spawn = true;
			}
		}
	}
	else
	{
		if(g_bFixed || !Tank_firstround_spawn) return;
		
		new iTank = IsTankInGame();
		if (iTank){

			TeleportEntity(iTank, g_fTankData_origin, g_fTankData_angel, NULL_VECTOR);
			//PrintToChatAll("teleport '%N' to round1 pos.", iTank);
			g_bFixed = true;
		}
	}
}

IsTankInGame(exclude = 0)
{
	for (new i = 1; i <= MaxClients; i++)
		if (exclude != i && IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerTank(i) && IsPlayerAlive(i) && !IsIncapacitated(i))
			return i;

	return 0;
}

static ClearVec()
{
	for (new index; index < 3; index++){
		fWitchData_agnel[index] = 0.0;
		fWitchData_origin[index] = 0.0;
		g_fTankData_origin[index] = 0.0;
		g_fTankData_angel[index] = 0.0;
	}
}

bool:InSecondHalfOfRound()
{
	return bool:GameRules_GetProp("m_bInSecondHalfOfRound");
}

void ResetPlugin()
{
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
}

public int L4D_GetMapValueInt(const char[] sKey, int iDefVal)
{
	return KvGetNum(g_hMIData, sKey, iDefVal);
}

public void L4D_CopyMapSubsection(KeyValues hKv, const char[] sKey)
{
	if (KvJumpToKey(g_hMIData, sKey, false)) {
		KvCopySubkeys(g_hMIData, hKv);
		KvGoBack(g_hMIData);
	}
}

void MI_KV_Load()
{
	char sNameBuff[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sNameBuff, 256, "data/%s", "mapinfo.txt");

	g_hMIData = CreateKeyValues("MapInfo");
	if (!FileToKeyValues(g_hMIData, sNameBuff)) {
		LogError("[MI] Couldn't load MapInfo data!");
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

bool IsValidInterval(int interval[2]) {
	return interval[0] > -1 && interval[1] >= interval[0];
}

void MergeIntervals(ArrayList merged) {
	if (merged.Length < 2) return;
	
	ArrayList intervals = merged.Clone();
	SortADTArray(intervals, Sort_Ascending, Sort_Integer);

	merged.Clear();
	
	int current[2];
	intervals.GetArray(0, current);
	merged.PushArray(current);
	
	int intv_size = intervals.Length;
	for (int i = 1; i < intv_size; ++i) {
		intervals.GetArray(i, current);
		
		int back_index = merged.Length - 1;
		int back_R = merged.Get(back_index, 1);
		
		if (back_R < current[0]) { // not coincide
			merged.PushArray(current);
		} else {
			back_R = (back_R > current[1] ? back_R : current[1]); // override the right value with maximum
			merged.Set(back_index, back_R, 1);
		}
	}
	
	delete intervals;
}

void MakeComplementaryIntervals(ArrayList intervals, ArrayList dest) {
	int intv_size = intervals.Length;
	if (intv_size < 2) return;
	
	int intv[2];
	for (int i = 1; i < intv_size; ++i) {
		intv[0] = intervals.Get(i-1, 1) + 1;
		intv[1] = intervals.Get(i, 0) - 1;
		if (IsValidInterval(intv)) dest.PushArray(intv);
	}
}

int GetRandomIntervalNum(ArrayList aList) {
	int total_length = 0, size = aList.Length;
	int[] arrLength = new int[size];
	for (int i = 0; i < size; ++i) {
		arrLength[i] = aList.Get(i, 1) - aList.Get(i, 0) + 1;
		total_length += arrLength[i];
	}
	
	int random = Math_GetRandomInt(0, total_length-1);

	for (int i = 0; i < size; ++i) {
		if (random < arrLength[i]) {
			return aList.Get(i, 0) + random;
		} else {
			random -= arrLength[i];
		}
	}
	return 0;
}

bool GetTankAvoidInterval(int interval[2]) {
	if (g_hCvarWitchAvoidTank.FloatValue == 0.0) {
		return false;
	}
	
	float flow = L4D2Direct_GetVSTankFlowPercent(0);
	if (flow == 0.0) {
		return false;
	}
	
	interval[0] = RoundToFloor((flow * 100) - (g_hCvarWitchAvoidTank.FloatValue / 2));
	interval[1] = RoundToCeil((flow * 100) + (g_hCvarWitchAvoidTank.FloatValue / 2));
	
	return true;
}

#define SIZE_OF_INT		 2147483647 // without 0
stock int Math_GetRandomInt(int min, int max)
{
	int random = GetURandomInt();

	if (random == 0) {
		random++;
	}

	return RoundToCeil(float(random) / (float(SIZE_OF_INT) / float(max - min + 1))) + min - 1;
}