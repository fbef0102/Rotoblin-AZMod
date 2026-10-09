#pragma semicolon 1

#include <sourcemod>
#include <left4dhooks>
#include <multicolors>

#define MAX(%0,%1) (((%0) > (%1)) ? (%0) : (%1))

new Handle:g_hVsBossBuffer;
int g_iSurCurrent = 0;

public Plugin:myinfo =
{
    name = "L4D1 Survivor Progress",
    author = "CanadaRox, Visor, L4D1 port by harry",
    description = "Print survivor progress in flow percents ",
    version = "2.3h-2026/10/10",
    url = "https://github.com/Attano/ProMod"
};

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	CreateNative("GetSurCurrent",Native_SurCurrent);
	CreateNative("GetSurCurrentFloat",Native_SurCurrentFloat);
	return APLRes_Success;
}

public Native_SurCurrentFloat(Handle:plugin, numParams) {
	return _:GetBossProximity();
}
public Native_SurCurrent(Handle:plugin, numParams) {
	g_iSurCurrent = RoundToNearest(GetBossProximity() * 100.0);
	return g_iSurCurrent;
}

bool 
	g_bRoundStarted;

public OnPluginStart()
{
	LoadTranslations("Roto2-AZ_mod.phrases");
	g_hVsBossBuffer = FindConVar("versus_boss_buffer");

	RegConsoleCmd("sm_cur", CurrentCmd);
	RegConsoleCmd("sm_current", CurrentCmd);
	HookEvent("round_start", RoundStartEvent, EventHookMode_PostNoCopy);
}
public RoundStartEvent(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_bRoundStarted = false;
	CreateTimer(5.0, SaveSurCurrent);
}

public Action:SaveSurCurrent(Handle:timer)
{
	g_iSurCurrent = RoundToNearest(GetBossProximity() * 100.0);
}

public Action:CurrentCmd(client, args)
{
	g_iSurCurrent = RoundToNearest(GetBossProximity() * 100.0);
	g_iSurCurrent = g_iSurCurrent>=100 ? 100 : g_iSurCurrent;
	
	if (!client) // riverside: server console / rcon
	{
		ReplyToCommand(client, "[TS] Current: %d%%", g_iSurCurrent);
		return Plugin_Handled;
	}

	CPrintToChat(client, "{default}[{olive}TS{default}] %T","l4d_current_survivor_progress",client, g_iSurCurrent);
}

public void OnRoundIsLive() 
{
	if(g_bRoundStarted) return;
	g_bRoundStarted = true;

	CPrintToChatAll("{default}[{olive}TS{default}] {blue}%t{default}: {green}%d%%","Survivor_Current", g_iSurCurrent);
}

public void L4D_OnFirstSurvivorLeftSafeArea_Post(int client)
{
	if(g_bRoundStarted) return;
	g_bRoundStarted = true;

	CPrintToChatAll("{default}[{olive}TS{default}] {blue}%t{default}: {green}%d%%","Survivor_Current", g_iSurCurrent);
}

stock Float:GetBossProximity()
{
	new Float:proximity = GetMaxSurvivorCompletion() + (GetConVarFloat(g_hVsBossBuffer) / L4D2Direct_GetMapMaxFlowDistance());
	return proximity;
}

float GetMaxSurvivorCompletion()
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

	return (flow / L4D2Direct_GetMapMaxFlowDistance());
}