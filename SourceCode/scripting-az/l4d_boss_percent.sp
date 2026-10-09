#pragma semicolon 1

#include <sourcemod>
#include <left4dhooks>
#include <multicolors>
#include <l4d_lib>
#undef REQUIRE_PLUGIN

public Plugin myinfo =
{
	name = "L4D1 Boss Flow Announce (Back to roots edition)",
	author = "ProdigySim, Jahze, Stabby, CircleSquared, CanadaRox, Visor, L4D1 port by harry",
	version = "1.6.3h-2026/10/10",
	description = "Announce boss flow percents!",
	url = "https://github.com/ConfoglTeam/ProMod"
};

int g_iWitchPercent, g_iTankPercent;
float WitchPercentFloat;

Handle g_forwardUpdateBosses;
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("GetTankPercent",Native_GetTankPercent);
	CreateNative("GetWitchPercent",Native_GetWitchPercent);
	CreateNative("GetWitchPercentFloat",Native_GetWitchPercentFloat);
	CreateNative("PrintBossPercents",Native_PrintBossPercents);
	CreateNative("SaveBossPercents",Native_SaveBossPercents);

	g_forwardUpdateBosses = CreateGlobalForward("OnUpdateBosses", ET_Ignore, Param_Cell, Param_Cell);
	RegPluginLibrary("l4d_boss_percent");
	return APLRes_Success;
}

public Native_GetWitchPercentFloat(Handle:plugin, numParams) {
	return _:WitchPercentFloat;
}
public Native_GetTankPercent(Handle:plugin, numParams) {
  return g_iTankPercent;
}
public Native_GetWitchPercent(Handle:plugin, numParams) {
    return g_iWitchPercent;
}

ConVar g_hBossBuffer;
float g_fBossBuffer;

ConVar hCvarPrintToEveryone, hCvarTankPercent, hCvarWitchPercent, 
	g_hCvarWitchPreNotify, g_hCvarTankPreNotify;
bool g_bCvarPrintToEveryone, g_bCvarTankPercent, g_bCvarWitchPercent;
int g_iCvarWitchPreNotify, g_iCvarTankPreNotify;

Handle g_hTraceBossTimer;

int 
	g_iWitchNotifyPercent,
	g_iTankNotifyPercent;

bool 
	g_bRoundStarted, 
	g_bHasSpawnedTank,
	g_bHasSpawnedWitch;

public OnPluginStart()
{
	LoadTranslations("Roto2-AZ_mod.phrases");

	g_hBossBuffer = FindConVar("versus_boss_buffer");
	GetOfficialCvars();
	g_hBossBuffer.AddChangeHook(ConVarChanged_OfficialCvars);

	hCvarPrintToEveryone 		= CreateConVar("l4d_boss_global_percent", 			"0", 	"If 1, Display boss percentages to entire team when using commands", FCVAR_NOTIFY);
	hCvarTankPercent 			= CreateConVar("l4d_boss_tank_percent", 			"1", 	"If 1, Display Tank flow percentage in chat", FCVAR_NOTIFY);
	hCvarWitchPercent 			= CreateConVar("l4d_boss_witch_percent", 			"1", 	"If 1, Display Witch flow percentage in chat", FCVAR_NOTIFY);

	g_hCvarWitchPreNotify 		= CreateConVar("l4d_boss_witch_ahead_notify", 		"5", 	"Notify players X% ahead of distance when a Witch is going to spawn (0=Off)", FCVAR_NOTIFY, true, 0.0);
	g_hCvarTankPreNotify 		= CreateConVar("l4d_boss_tank_ahead_notify", 		"5", 	"Notify players X% ahead of distance when a Tank is going to spawn (0=Off)", FCVAR_NOTIFY, true, 0.0);

	GetCvars();
	hCvarPrintToEveryone.AddChangeHook(ConVarChanged_Cvars);
	hCvarTankPercent.AddChangeHook(ConVarChanged_Cvars);
	hCvarWitchPercent.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarWitchPreNotify.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarTankPreNotify.AddChangeHook(ConVarChanged_Cvars);

	RegConsoleCmd("sm_boss", BossCmd);
	RegConsoleCmd("sm_tank", BossCmd);
	RegConsoleCmd("sm_witch", BossCmd);
	RegConsoleCmd("sm_t", BossCmd);

	HookEvent("round_start", 			Event_RoundStart);
	HookEvent("mission_lost", 			Event_RoundEnd);
	HookEvent("map_transition", 		Event_RoundEnd);
	HookEvent("round_end", 				Event_RoundEnd);
	HookEvent("finale_win", 			Event_RoundEnd);
	HookEvent("finale_start", 			Event_FinaleStart, EventHookMode_PostNoCopy); //final starts, some of final maps won't trigger
	HookEvent("finale_radio_start", 	Event_FinaleStart, EventHookMode_PostNoCopy); //final starts, all final maps trigger

	HookEvent("tank_spawn",		Event_TankSpawn,		EventHookMode_PostNoCopy);
	HookEvent("witch_spawn",  	Event_WitchSpawn);
}


void ConVarChanged_OfficialCvars(ConVar hCvar, const char[] sOldVal, const char[] sNewVal)
{
	GetOfficialCvars();
}

void GetOfficialCvars()
{
	g_fBossBuffer = g_hBossBuffer.FloatValue; 
}

void ConVarChanged_Cvars(ConVar hCvar, const char[] sOldVal, const char[] sNewVal)
{
	GetCvars();
}

void GetCvars()
{
	g_bCvarPrintToEveryone = hCvarPrintToEveryone.BoolValue;
	g_bCvarTankPercent = hCvarTankPercent.BoolValue;
	g_bCvarWitchPercent = hCvarWitchPercent.BoolValue;
	g_iCvarWitchPreNotify = g_hCvarWitchPreNotify.IntValue;
	g_iCvarTankPreNotify = g_hCvarTankPreNotify.IntValue;
}

public Native_PrintBossPercents(Handle:plugin, numParams)
{
	for (new client = 1; client <= MaxClients; client++)
		if (IsClientConnected(client) && IsClientInGame(client)&& !IsFakeClient(client))
			PrintBossPercents(client);
}
public Native_SaveBossPercents(Handle:plugin, numParams)
{
	CreateTimer(0.1, SaveBossFlows);
}

public void OnMapEnd()
{
	ResetTimer();
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) 
{
	g_bRoundStarted = false;

	g_bHasSpawnedTank = false;
	g_bHasSpawnedWitch = false;
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) 
{
	ResetTimer();
}

void Event_FinaleStart(Event event, const char[] name, bool dontBroadcast) 
{
	delete g_hTraceBossTimer;
}

void Event_TankSpawn(Event event, const char[] name, bool dontBroadcast) 
{
	g_bHasSpawnedTank = true;
}

void Event_WitchSpawn(Event event, const char[] name, bool dontBroadcast) 
{
	g_bHasSpawnedWitch = true;
}

Action SaveBossFlows(Handle timer)
{
	if (!InSecondHalfOfRound())
	{
		g_iWitchPercent = 0;
		g_iTankPercent = 0;
		WitchPercentFloat = 0.0;
	
		if (L4D2Direct_GetVSWitchToSpawnThisRound(0))
		{
			WitchPercentFloat = GetWitchFlow(0);
			g_iWitchPercent = RoundToNearest(GetWitchFlow(0)*100.0);
		}
		if (L4D2Direct_GetVSTankToSpawnThisRound(0))
		{
			g_iTankPercent = RoundToNearest(GetTankFlow(0)*100.0);
		}
	}
	else
	{
		if (g_iWitchPercent != 0)
		{
			WitchPercentFloat = GetWitchFlow(1);
			g_iWitchPercent = RoundToNearest(GetWitchFlow(1)*100.0);
		}
		if (g_iTankPercent != 0)
		{
			g_iTankPercent = RoundToNearest(GetTankFlow(1)*100.0);
		}
	}

	ConVar l4d_multiwitch_enabled = FindConVar("l4d_multiwitch_enabled");
	if(l4d_multiwitch_enabled != null)
	{
		if(l4d_multiwitch_enabled.IntValue == 1)
			g_iWitchPercent = -2;
	}

	Call_StartForward(g_forwardUpdateBosses);
	Call_PushCell(g_iTankPercent);
	Call_PushCell(g_iWitchPercent);
	Call_Finish();

	g_iTankNotifyPercent = g_iTankPercent - g_iCvarTankPreNotify;
	g_iWitchNotifyPercent = g_iWitchPercent - g_iCvarWitchPreNotify;

	return Plugin_Continue;
}

stock PrintBossPercents(client)
{
	if(g_bCvarTankPercent)
	{
		if (g_iTankPercent > 0)
			CPrintToChat(client, "{default}[{olive}TS{default}] {red}%T{default}:{green} %d%%","Tank",client, g_iTankPercent);
		else
			CPrintToChat(client, "{default}[{olive}TS{default}] {red}%T{default}:{green} None","Tank",client);
	}

	if(g_bCvarWitchPercent)
	{
		if (g_iWitchPercent > 0)
			CPrintToChat(client, "{default}[{olive}TS{default}] {red}%T{default}:{green} %d%%","Witch",client, g_iWitchPercent);
		else if (g_iWitchPercent == -2)
			CPrintToChat(client, "{default}[{olive}TS{default}] {red}%T{default}:{green} Witch Party","Witch",client);
		else
			CPrintToChat(client, "{default}[{olive}TS{default}] {red}%T{default}:{green} None","Witch",client);
			
	}
}

public Action:BossCmd(client, args)
{
	new iTeam = GetClientTeam(client);

	// riverside: server console / rcon has no team or chat
	if (!client)
	{
		decl String:sWitch[16];
		if (g_iWitchPercent > 0) Format(sWitch, sizeof(sWitch), "%d%%", g_iWitchPercent);
		else strcopy(sWitch, sizeof(sWitch), (g_iWitchPercent == -2) ? "Witch Party" : "None");
		if (g_iTankPercent > 0) ReplyToCommand(client, "[TS] Tank: %d%%, Witch: %s", g_iTankPercent, sWitch);
		else ReplyToCommand(client, "[TS] Tank: None, Witch: %s", sWitch);
		return Plugin_Handled;
	}

	if (g_bCvarPrintToEveryone)//打這指令的只有自己看到
	{
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsClientConnected(i) && IsClientInGame(i)&& !IsFakeClient(i) && GetClientTeam(i) == iTeam)
				PrintBossPercents(i);
		}
	}
	else
	{
		PrintBossPercents(client);
	}

	return Plugin_Handled;
}

stock Float:GetTankFlow(round)
{
	new Float:tankflow = L4D2Direct_GetVSTankFlowPercent(round); 
	return tankflow;
}

stock Float:GetWitchFlow(round)
{
	new Float:witchflow = L4D2Direct_GetVSWitchFlowPercent(round);
	return witchflow;
}

public void OnRoundIsLive() 
{
	if(g_bRoundStarted) return;
	
	GameStart();
}

public void L4D_OnFirstSurvivorLeftSafeArea_Post(int client)
{
	delete g_hTraceBossTimer;
	g_hTraceBossTimer = CreateTimer(0.3, Timer_TraceSpawnBoss, _, TIMER_REPEAT);
	
	if(g_bRoundStarted) return;

	GameStart();
}

void GameStart()
{
	g_bRoundStarted = true;

	for (int client = 1; client <= MaxClients; client++)
		if (IsClientConnected(client) && IsClientInGame(client)&& !IsFakeClient(client))
			PrintBossPercents(client);
}

Action Timer_TraceSpawnBoss( Handle timer ) 
{
	if(g_bHasSpawnedTank == true && g_bHasSpawnedWitch == true) 
	{
		g_hTraceBossTimer = null;
		return Plugin_Stop;
	}

	if(g_iTankPercent <= 0) g_bHasSpawnedTank = true;
	if(g_iWitchPercent <= 0) g_bHasSpawnedWitch = true;

	int iMaxSurvivorCompletion = GetMaxSurvivorCompletion();

	// ===================== TANK =====================

	if (g_iCvarTankPreNotify > 0 
		&& iMaxSurvivorCompletion < g_iTankPercent 
		&& iMaxSurvivorCompletion >= g_iTankNotifyPercent 
		&& g_bHasSpawnedTank == false)
	{
		CPrintToChatAll("%t", "Tank_spawn_distance", g_iTankPercent - iMaxSurvivorCompletion);
		g_iTankNotifyPercent = iMaxSurvivorCompletion+1;
	}
	
	// ===================== WITCH =====================

	if (g_iCvarWitchPreNotify > 0 
		&& iMaxSurvivorCompletion < g_iWitchPercent 
		&& iMaxSurvivorCompletion >= g_iWitchNotifyPercent 
		&& g_bHasSpawnedWitch == false)
	{
		CPrintToChatAll("%t", "Witch_spawn_distance", g_iWitchPercent - iMaxSurvivorCompletion);
		g_iWitchNotifyPercent = iMaxSurvivorCompletion+1;
	}

	return Plugin_Continue;
}

int GetMaxSurvivorCompletion() 
{
	float flow = 0.0, tmp_flow = 0.0;
	Address pNavArea;
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i)) {
			pNavArea = L4D_GetLastKnownArea(i);
			if (pNavArea != Address_Null) {
				tmp_flow = L4D2Direct_GetTerrorNavAreaFlow(pNavArea);
				flow = (flow > tmp_flow) ? flow : tmp_flow;
			}
		}
	}
	
	flow = (flow / L4D2Direct_GetMapMaxFlowDistance()) + (g_fBossBuffer / L4D2Direct_GetMapMaxFlowDistance());
	flow = flow * 100;
	if (flow <= 1.0) flow = 1.0;
	else if(flow > 100.0) flow = 100.0;

	return RoundToNearest(flow);
}

void ResetTimer()
{
	delete g_hTraceBossTimer;
}