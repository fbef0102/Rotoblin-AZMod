#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>
#include <sdktools>
#include <multicolors>

#define Z_TANK 5
#define TEAM_INFECTED 3
#define INFINITE_HORDE 999999

#define ZOMBIEMANAGER_GAMEDATA "l4d2_zombiemanager"
#define LEFT4FRAMEWORK_GAMEDATA "left4dhooks.l4d1"

Address
	pZombieManager = Address_Null;

ConVar
	g_hBypassFlowDistance,
	g_hBypassExtraFlowDistance;

Handle
	g_hFlowCheckTimer;

float
	fFurthestFlow,
	fBypassFlow,
	fProgressFlowPercent,
	fPushWarningPercent;

int
	m_nPendingMobCount;

bool
	announcedTankSpawn,
	announcedHordeResume,
	announcedHordeMax,
	tankInPlay,
	tankInPlayDelay,
	g_bGauntletFinaleMap,
	g_bFinaleEscapeStart,
	g_bGauntletStart;

public Plugin myinfo = 
{
	name = "L4D2 Tank Horde Monitor",
	author = "Derpduck, Visor (l4d2_horde_equaliser), Harry (l4d1 port)",
	description = "Monitors and changes state of infinite hordes during tanks on Gauntlet Finale map",
	version = "1.3.1h-2026/10/26",
	url = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

public void OnPluginStart()
{
	LoadTranslation("l4d2_tank_horde_monitor.phrases");
	InitGameData();
	
	g_hBypassFlowDistance = FindConVar("director_tank_bypass_max_flow_travel");
	g_hBypassExtraFlowDistance = CreateConVar("l4d2_tank_bypass_extra_flow", "1500.0", "Extra allowed flow distance to bypass tanks during infinite events (0 = disabled)", FCVAR_NONE, true, 0.0);
	
	HookEvent("round_start", RoundStartEvent, EventHookMode_PostNoCopy);
	HookEvent("round_end", RoundEndEvent, EventHookMode_PostNoCopy);
	HookEvent("tank_spawn", TankSpawn, EventHookMode_PostNoCopy);
	HookEvent("player_death", TankDeath);
    HookEvent("finale_escape_start", 	Finale_Escape_Start); //最後逃亡上載具，通常發生於逃亡載具開始飛進來的過場動畫，如果逃亡載具已經存在的地圖則不會觸發，譬如 C1M4, C5M5, C13M4
    HookEvent("finale_vehicle_ready",   Finale_Escape_Start); //逃亡載具已準備好，所有救援地圖必觸發

	HookEntityOutput("logic_relay", "OnTrigger", OnRelayTrigger);
}

void InitGameData()
{
	Handle hDamedata = LoadGameConfigFile(LEFT4FRAMEWORK_GAMEDATA);
	if (!hDamedata) {
		SetFailState("%s gamedata missing or corrupt", LEFT4FRAMEWORK_GAMEDATA);
	}

	pZombieManager = GameConfGetAddress(hDamedata, "ZombieManager");
	if (!pZombieManager) {
		SetFailState("Couldn't find the 'ZombieManager' address");
	}
	
	delete hDamedata;

	Handle hDamedata2 = LoadGameConfigFile(ZOMBIEMANAGER_GAMEDATA);
	if (!hDamedata2) {
		SetFailState("%s gamedata missing or corrupt", ZOMBIEMANAGER_GAMEDATA);
	}
	
	m_nPendingMobCount = GameConfGetOffset(hDamedata2, "ZombieManager->m_nPendingMobCount");
	if (m_nPendingMobCount == -1) {
		SetFailState("Failed to get offset 'ZombieManager->m_nPendingMobCount'.");
	}

	delete hDamedata2;
}

void RoundStartEvent(Event hEvent, const char[] name, bool dontBroadcast)
{
	g_bFinaleEscapeStart = false;
	g_bGauntletStart = false;
	ResetWarnings();
	TimerCleanUp();
	fBypassFlow = 0.0;
	fFurthestFlow = 0.0;
	fProgressFlowPercent = 0.0;
}

void RoundEndEvent(Event hEvent, const char[] name, bool dontBroadcast)
{
	ResetWarnings();
	TimerCleanUp();
	fBypassFlow = 0.0;
	fFurthestFlow = 0.0;
	fProgressFlowPercent = 0.0;
}

public void OnMapStart() 
{
	g_bGauntletFinaleMap = false;
	char sMap[64];
	GetCurrentMap(sMap, sizeof(sMap));

	char sNameBuff[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sNameBuff, 256, "data/%s", "mapinfo.txt");

	KeyValues hMIData = new KeyValues("MapInfo");
	if (!hMIData.ImportFromFile(sNameBuff)) 
	{
		delete hMIData;
	}

	if (hMIData.JumpToKey("default")) 
	{
		g_bGauntletFinaleMap = view_as<bool>(hMIData.GetNum("GauntletFinale_map", g_bGauntletFinaleMap));

		hMIData.GoBack();
	}

	if (hMIData.JumpToKey(sMap)) 
	{
		g_bGauntletFinaleMap = view_as<bool>(hMIData.GetNum("GauntletFinale_map", g_bGauntletFinaleMap));

		hMIData.GoBack();
	}

	delete hMIData;
}

public void OnMapEnd()
{
	ResetWarnings();
	TimerCleanUp();
	fBypassFlow = 0.0;
	fFurthestFlow = 0.0;
	fProgressFlowPercent = 0.0;
}

void TankSpawn(Event event, const char[] name, bool dontBroadcast) 
{
	if(g_bFinaleEscapeStart || !g_bGauntletFinaleMap) return;

	if (!tankInPlay)
	{
		tankInPlay = true;
		if (IsInfiniteHordeActive() && !announcedTankSpawn)
		{
			// Find current highest flow, and where the bypass point is
			fFurthestFlow = GetAheadSurvivorFlow();
			fBypassFlow = fFurthestFlow + g_hBypassFlowDistance.FloatValue;
			//PrintToChatAll("fFurthestFlow: %f, fBypassFlow: %f", fFurthestFlow, fBypassFlow);
			AnnounceTankSpawn();

		}
	}
}

void TankDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client > 0 && IsInfected(client) && IsTank(client)) {
		CreateTimer(0.1, Timer_CheckTank, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

void Finale_Escape_Start(Event event, const char[] name, bool dontBroadcast)
{
	g_bFinaleEscapeStart = true;
	ResetWarnings();
	TimerCleanUp();
}

public void OnClientDisconnect(int client)
{
	// Was a bot tank kicked
	if (client > 0 && IsInfected(client) && IsTank(client) && IsFakeClient(client)) {
		CreateTimer(0.1, Timer_CheckTank, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

Action Timer_CheckTank(Handle timer)
{
	int tankclient = FindTankClient();
	if (!tankclient || !IsPlayerAlive(tankclient)) 
	{
		if(!g_bFinaleEscapeStart && tankInPlay && g_bGauntletFinaleMap && IsInfiniteHordeActive())
			CreateTimer(6.0, Timer_CallHorde, _, TIMER_FLAG_NO_MAPCHANGE);

		ResetWarnings();
		TimerCleanUp();
	}

	return Plugin_Continue;
}

Action Timer_CallHorde(Handle timer)
{
	L4D1_ForceDirector_PanicEventControlled(INFINITE_HORDE);

	return Plugin_Continue;
}

void AnnounceTankSpawn()
{
	fProgressFlowPercent = GetFlowUntilBypass(fFurthestFlow, fBypassFlow);
	CPrintToChatAll("%t %t", "Tag", "TankPlay", fProgressFlowPercent);
	announcedTankSpawn = true;

	// Begin repeating flow checker
	g_hFlowCheckTimer = CreateTimer(2.0, FlowCheckTimer, _, TIMER_REPEAT);
}

Action FlowCheckTimer(Handle hTimer)
{
	if (!tankInPlay || announcedHordeResume || announcedHordeMax){
		g_hFlowCheckTimer = null;
		return Plugin_Stop;
	}

	// Extra check to prevent rush warning misfiring if tank spawns on the same frame as a horde spawn
	if (!tankInPlayDelay){
		tankInPlayDelay = true;
	}

	// Return furthest achieved survivor flow
	fFurthestFlow = GetAheadSurvivorFlow();

	// Print warnings if approaching the bypass limit
	float fWarningPercent = GetFlowUntilBypass(fFurthestFlow, fBypassFlow);

	if (fProgressFlowPercent - fWarningPercent >= 1.0){
		fProgressFlowPercent = fWarningPercent;
		CPrintToChatAll("%t %t", "Tag", "UntilHordeStarts", fWarningPercent);
	}

	return Plugin_Continue;
}

//!activator = activator of Trigger input
//!caller = this entity
void OnRelayTrigger(const char[] output, int caller, int activator, float delay)
{
	if(!g_bGauntletFinaleMap) return;

	if (!IsValidEntity(caller))
		return;

	char relay[64];
	GetEntPropString(caller, Prop_Data, "m_iName", relay, sizeof(relay));
	if (StrEqual(relay, "l4d1_gauntletfinale_map"))
	{
		g_bGauntletStart = true;
	}
}

public Action L4D_OnSpawnMob(int &amount)
{
	if(!g_bGauntletFinaleMap) return Plugin_Continue;
	if(g_bFinaleEscapeStart) return Plugin_Continue;

	/////////////////////////////////////
	// - Called on Event Hordes.
	// - Called on Panic Event Hordes.
	// - Called on Natural Hordes.
	// - Called on Onslaught (Mini-finale or finale Scripts)

	// - Not Called on Boomer Hordes.
	// - Not Called on z_spawn mob.
	////////////////////////////////////

	if (tankInPlay && IsInfiniteHordeActive()){
		// If survivors have already pushed past the extra bypass distance we can ignore this
		if (announcedHordeMax){
			return Plugin_Continue;
		} else {
			// Calculate how far survivors have pushed
			fFurthestFlow = GetAheadSurvivorFlow();
			float fPushAmount = (fFurthestFlow - fBypassFlow) / (g_hBypassFlowDistance.FloatValue + g_hBypassExtraFlowDistance.FloatValue);

			// Clamp values
			if (fPushAmount < 0.0){
				fPushAmount = 0.0;
			} else if (fPushAmount > 1.0){
				fPushAmount = 1.0;
			}

			// Have survivors pushed past the bypass point?
			if (!announcedHordeResume && tankInPlayDelay && fPushAmount >= 0.05){
				fPushWarningPercent = fPushAmount;
				int iPushPercent = RoundToNearest(fPushAmount * 100.0);
				CPrintToChatAll("%t %t", "Tag", "HordeResumed", iPushPercent);
				announcedHordeResume = true;
				CreateTimer(1.0, Timer_CallHorde, _, TIMER_FLAG_NO_MAPCHANGE);
			}

			// Horde strength prints
			if (fPushAmount - fPushWarningPercent >= 0.20 && fPushAmount != 1.0 && announcedHordeResume){
				fPushWarningPercent = fPushAmount;
				int iPushPercent = RoundToNearest(fPushAmount * 100.0);
				CPrintToChatAll("%t %t", "Tag", "HordeStrength", iPushPercent);
			}

			// Have survivors have pushed past the extra distance we allow?
			if (fPushAmount == 1.0){
				CPrintToChatAll("%t %t", "Tag", "HordeVeryStrength");
				announcedHordeMax = true;
			}

			// Scale amount of horde per mob with how far survivors have pushed
			int iNewAmount = RoundToNearest(amount * fPushAmount);

			SetPendingMobCount(iNewAmount);
			amount = iNewAmount;
			//PrintToChatAll("amount: %d", amount);

			return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}

bool IsInfiniteHordeActive()
{
	//int countdown = GetHordeCountdown();
	//return (/*GetPendingMobCount() > 0 &&*/ countdown > -1 && countdown <= 10);

	return g_bGauntletStart;
}

/*
int GetPendingMobCount()
{
	return LoadFromAddress(pZombieManager + view_as<Address>(m_nPendingMobCount), NumberType_Int32);
}
*/

void SetPendingMobCount(int count)
{
	StoreToAddress(pZombieManager + view_as<Address>(m_nPendingMobCount), count, NumberType_Int32);
}

//int GetHordeCountdown()
//{
//	return (CTimer_HasStarted(L4D2Direct_GetMobSpawnTimer())) ? RoundFloat(CTimer_GetRemainingTime(L4D2Direct_GetMobSpawnTimer())) : -1;
//}

bool IsInfected(int client)
{
	return (IsClientInGame(client) && GetClientTeam(client) == TEAM_INFECTED);
}

bool IsTank(int client)
{
	return (GetEntProp(client, Prop_Send, "m_zombieClass") == Z_TANK);
}

int FindTankClient()
{
	for (int i = 1; i <= MaxClients; i++) {
		if (!IsInfected(i) || !IsTank(i) || !IsPlayerAlive(i)) {
			continue;
		}
		
		return i; // Found tank, return
	}
	return 0;
}

float GetFlowUntilBypass(float fCurrentFlowValue, float fBypassFlowValue)
{
	float fCurrentFlowPercent = (fCurrentFlowValue / L4D2Direct_GetMapMaxFlowDistance());
	float fBypassFlowPercent = (fBypassFlowValue / L4D2Direct_GetMapMaxFlowDistance());
	float result = (fBypassFlowPercent - fCurrentFlowPercent) * 100;

	if (result < 0){
		result = 0.0;
	}

	return result;
}

void TimerCleanUp()
{
	if (g_hFlowCheckTimer != null){
		delete g_hFlowCheckTimer;
		g_hFlowCheckTimer = null;
	}
}

void ResetWarnings()
{
	tankInPlay = false;
	tankInPlayDelay = false;
	announcedTankSpawn = false;
	announcedHordeResume = false;
	announcedHordeMax = false;
	fPushWarningPercent = 0.0;
}

/**
 * Check if the translation file exists
 *
 * @param translation	Translation name.
 * @noreturn
 */
stock void LoadTranslation(const char[] translation)
{
	char
		sPath[PLATFORM_MAX_PATH],
		sName[64];

	FormatEx(sName, sizeof(sName), "translations/%s.txt", translation);
	BuildPath(Path_SM, sPath, sizeof(sPath), sName);
	if (!FileExists(sPath))
		SetFailState("Missing translation file %s.txt", translation);

	LoadTranslations(translation);
}

float GetAheadSurvivorFlow()
{
	float max_flow = 0.0;
	float tmp_flow, origin[3];
	int iAheadSurvivor = 0, iTemp;
	Address pNavArea;
	for (int client = 1; client <= MaxClients; client++) {
		if(IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client))
		{
			iTemp = client;
			GetClientAbsOrigin(client, origin);
			pNavArea = L4D2Direct_GetTerrorNavArea(origin);
			if (pNavArea == Address_Null) continue;
			
			tmp_flow = L4D2Direct_GetTerrorNavAreaFlow(pNavArea);
			if(tmp_flow >= max_flow)
			{
				max_flow = tmp_flow;
				iAheadSurvivor = iTemp;
			}
		}
	}

	return (iAheadSurvivor == 0) ? 0.0 : max_flow;
}

void L4D1_ForceDirector_PanicEventControlled(int hordes)
{
	//PrintToChatAll("Call infinite horde");

	int entity = FindEntityByClassname(MaxClients+1, "info_director");
	if(entity == -1) return;

	SetVariantInt(hordes);
	AcceptEntityInput(entity, "PanicEventControlled");
}