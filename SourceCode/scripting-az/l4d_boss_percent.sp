#pragma semicolon 1

#include <sourcemod>
#include <left4dhooks>
#include <multicolors>
#undef REQUIRE_PLUGIN
native Is_Ready_Plugin_On();

public Plugin:myinfo =
{
	name = "L4D1 Boss Flow Announce (Back to roots edition)",
	author = "ProdigySim, Jahze, Stabby, CircleSquared, CanadaRox, Visor, L4D1 port by harry",
	version = "1.6.2",
	description = "Announce boss flow percents!",
	url = "https://github.com/ConfoglTeam/ProMod"
};

new iWitchPercent = 0;
new iTankPercent = 0;
new Float:WitchPercentFloat = 0.0;

new Handle:hCvarPrintToEveryone;
new Handle:hCvarTankPercent;
new Handle:hCvarWitchPercent;
new bool:InSecondHalfOfRound;

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{ 
	CreateNative("GetTankPercent",Native_GetTankPercent);
	CreateNative("GetWitchPercent",Native_GetWitchPercent);
	CreateNative("GetWitchPercentFloat",Native_GetWitchPercentFloat);
	CreateNative("PrintBossPercents",Native_PrintBossPercents);
	CreateNative("SaveBossPercents",Native_SaveBossPercents);
	RegPluginLibrary("l4d_boss_percent");
	return APLRes_Success;
}

public Native_GetWitchPercentFloat(Handle:plugin, numParams) {
	return _:WitchPercentFloat;
}
public Native_GetTankPercent(Handle:plugin, numParams) {
  return iTankPercent;
}
public Native_GetWitchPercent(Handle:plugin, numParams) {
    return iWitchPercent;
}

public OnPluginStart()
{
	LoadTranslations("Roto2-AZ_mod.phrases");

	hCvarPrintToEveryone = CreateConVar("l4d_global_percent", "0", "Display boss percentages to entire team when using commands", FCVAR_NOTIFY);
	hCvarTankPercent = CreateConVar("l4d_tank_percent", "1", "Display Tank flow percentage in chat", FCVAR_NOTIFY);
	hCvarWitchPercent = CreateConVar("l4d_witch_percent", "1", "Display Witch flow percentage in chat", FCVAR_NOTIFY);

	RegConsoleCmd("sm_boss", BossCmd);
	RegConsoleCmd("sm_tank", BossCmd);
	RegConsoleCmd("sm_witch", BossCmd);
	RegConsoleCmd("sm_t", BossCmd);

	HookEvent("round_start", RoundStartEvent, EventHookMode_PostNoCopy);	InSecondHalfOfRound = true;
	HookEvent("round_end", PD_ev_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("player_left_start_area", LeftStartAreaEvent, EventHookMode_PostNoCopy);
}
public LeftStartAreaEvent(Handle:event, String:name[], bool:dontBroadcast)
{
	if(!Is_Ready_Plugin_On())
		for (new client = 1; client <= MaxClients; client++)
			if (IsClientConnected(client) && IsClientInGame(client)&& !IsFakeClient(client))
				PrintBossPercents(client);
}
public OnMapStart()
{
	//LogMessage("this is OnMapStart and InSecondHalfOfRound is false");
	//每一關地圖載入後都會進入OnMapStart()
	InSecondHalfOfRound = false;
}
public Native_PrintBossPercents(Handle:plugin, numParams)
{
	for (new client = 1; client <= MaxClients; client++)
		if (IsClientConnected(client) && IsClientInGame(client)&& !IsFakeClient(client))
			PrintBossPercents(client);
}
public Native_SaveBossPercents(Handle:plugin, numParams)
{
	CreateTimer(1.0, SaveBossFlows);
}

public RoundStartEvent(Handle:event, const String:name[], bool:dontBroadcast)
{
	CreateTimer(5.0, SaveBossFlows);
}
public Action:PD_ev_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	//LogMessage("this is PD_ev_RoundEnd , InSecondHalfOfRound is true");
	if(!InSecondHalfOfRound)//第一回合結束
		InSecondHalfOfRound = true;
}

public Action:SaveBossFlows(Handle:timer)
{
	if (!InSecondHalfOfRound)
	{
		iWitchPercent = 0;
		iTankPercent = 0;
		WitchPercentFloat = 0.0;
	
		if (L4D2Direct_GetVSWitchToSpawnThisRound(0))
		{
			WitchPercentFloat = GetWitchFlow(0);
			iWitchPercent = RoundToNearest(GetWitchFlow(0)*100.0);
		}
		if (L4D2Direct_GetVSTankToSpawnThisRound(0))
		{
			iTankPercent = RoundToNearest(GetTankFlow(0)*100.0);
		}
	}
	else
	{
		if (iWitchPercent != 0)
		{
			WitchPercentFloat = GetWitchFlow(1);
			iWitchPercent = RoundToNearest(GetWitchFlow(1)*100.0);
		}
		if (iTankPercent != 0)
		{
			iTankPercent = RoundToNearest(GetTankFlow(1)*100.0);
		}
	}
	new Handle:WITCHPARTY = FindConVar("l4d_multiwitch_enabled");
	if(WITCHPARTY != INVALID_HANDLE)
	{
		if(GetConVarInt(WITCHPARTY) == 1)
			iWitchPercent = -2;
	}
}

stock PrintBossPercents(client)
{
	if(GetConVarBool(hCvarTankPercent))
	{
		if (iTankPercent)
			CPrintToChat(client, "{default}[{olive}TS{default}] {red}%T{default}:{green} %d%%","Tank",client, iTankPercent);
		else
			CPrintToChat(client, "{default}[{olive}TS{default}] {red}%T{default}:{green} None","Tank",client);
	}

	if(GetConVarBool(hCvarWitchPercent))
	{
		if (iWitchPercent > 0)
			CPrintToChat(client, "{default}[{olive}TS{default}] {red}%T{default}:{green} %d%%","Witch",client, iWitchPercent);
		else if (iWitchPercent == -2)
			CPrintToChat(client, "{default}[{olive}TS{default}] {red}%T{default}:{green} Witch Party","Witch",client);
		else
			CPrintToChat(client, "{default}[{olive}TS{default}] {red}%T{default}:{green} None","Witch",client);
			
	}
}

public Action:BossCmd(client, args)
{
	new iTeam = GetClientTeam(client);

	if (GetConVarBool(hCvarPrintToEveryone))//打這指令的只有自己看到
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