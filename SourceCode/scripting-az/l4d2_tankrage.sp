#include <sourcemod>
#include <left4dhooks>
#include <multicolors>
//#undef REQUIRE_PLUGIN
//#include <l4d2_boss_percents>
native int GetTankPercent(); // from l4d_boss_percent
native int GetSurCurrent(); // from l4d_current_survivor_progress

ConVar convarRageFlowPercent;
ConVar convarRageFreezeTime;
ConVar convarDebug;
ConVar g_hVsBossBuffer;

Handle hTankTimer;

bool 
	bHaveHadFlowOrStaticTank,
	libraryBossPercentAvailable = false,
	g_bFinalStart;

int tankSpawnedSurvivorFlow = 0;

public Plugin myinfo =
{
    name = "L4D1 Tank Rage",
    author = "Sir, l4d1 port by Harry",
    description = "Manage Tank Rage when Survivors are running back.",
    version = "1.0.2-2026/1/19",
    url = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

public void OnPluginStart()
{
	LoadTranslation("l4d2_tankrage.phrases");
	g_hVsBossBuffer = FindConVar("versus_boss_buffer");
	convarRageFlowPercent = CreateConVar("l4d2_tankrage_flowpercent", "7", "The percentage in flow the survival have to run back to grant frustration freeze (Furthest Survivor)");
	convarRageFreezeTime  = CreateConVar("l4d2_tankrage_freezetime", "4.0", "Time in seconds to freeze the Tank's frustration when survivors have ran back per <flowpercent>.");
	convarDebug = CreateConVar("l4d2_tankrage_debug", "0", "Are we debugging?");
	HookEvent("tank_spawn", Event_TankSpawn);
	HookEvent("round_start", Event_ResetTank, EventHookMode_PostNoCopy);
	HookEvent("finale_start", 			OnFinaleStart_Event, EventHookMode_PostNoCopy); //final starts, some of final maps won't trigger
	HookEvent("finale_radio_start", 	OnFinaleStart_Event, EventHookMode_PostNoCopy); //final starts, all final maps trigger
}

public void OnAllPluginsLoaded()
{
    libraryBossPercentAvailable = LibraryExists("l4d_boss_percent");
}

public void OnLibraryRemoved(const char[] name)
{
    if (strcmp(name, "l4d_boss_percent") == 0) libraryBossPercentAvailable = false;
}

public void OnLibraryAdded(const char[] name)
{
    if (strcmp(name, "l4d_boss_percent") == 0) libraryBossPercentAvailable = true;
}

public void L4D_OnFirstSurvivorLeftSafeArea_Post()
{
    if (libraryBossPercentAvailable)
        tankSpawnedSurvivorFlow = GetTankPercent();
    else
        tankSpawnedSurvivorFlow = L4D2Direct_GetVSTankFlowPercent(InSecondHalfOfRound()) ? RoundToNearest(L4D2Direct_GetVSTankFlowPercent(InSecondHalfOfRound()) * 100.0) : 0;
}

public void OnUpdateBosses(int iTankFlow, int iWitchFlow)
{
	tankSpawnedSurvivorFlow = iTankFlow;
}

void Event_TankSpawn(Event hEvent, char[] sEventName, bool dontBroadcast)
{
	int tank = GetClientOfUserId(hEvent.GetInt("userid"));

	if (convarDebug.BoolValue) 
		PrintToChatAll("[%s]: %N is Tank", sEventName, tank);

	if (bHaveHadFlowOrStaticTank || g_bFinalStart)
		return;

	/*
		This is needed for maps that do not have a flow tank.
		We will however be checking if the map is the last map in the campaign as we don't want to mess with finale tanks
		tankSpawnedSuvivorFlow will always be 0 for static tanks, so we need to rely on another method in this check.
	*/
	if (tankSpawnedSurvivorFlow == 0)
	{
		if (L4D_IsMissionFinalMap())
			return;

		tankSpawnedSurvivorFlow = min(GetSurCurrent(), 100);
	}

	if (!IsFakeClient(tank))
	{
		CPrintToChatAll("%t %t", "Tag", "SurvivorsRunBack", convarRageFlowPercent.IntValue, convarRageFreezeTime.FloatValue);
		delete hTankTimer;
		hTankTimer = CreateTimer(0.3, timerTank, GetClientUserId(tank), TIMER_REPEAT)
		bHaveHadFlowOrStaticTank = true;
	}
}

void Event_ResetTank(Event hEvent, char[] sEventName, bool dontBroadcast)
{
	bHaveHadFlowOrStaticTank = false;
	tankSpawnedSurvivorFlow = 0;
	g_bFinalStart = false;

	if (convarDebug.BoolValue) 
		PrintToChatAll("[%s]: Everything is reset!", sEventName);

	delete hTankTimer;
}

void OnFinaleStart_Event(Event hEvent, char[] sEventName, bool dontBroadcast)
{
	g_bFinalStart = true;
}

public void L4D_OnReplaceTank(int tank, int newtank)
{
	if(tank == newtank) return;

	DataPack dp = new DataPack();
	dp.WriteCell(GetClientUserId(newtank));
	dp.WriteCell(GetClientUserId(tank));
	RequestFrame(NextFrame_ReplaceTank, dp);
}

void NextFrame_ReplaceTank(any data)
{
	DataPack dp = view_as<DataPack>(data);
	dp.Reset();

	int userid = dp.ReadCell();
	int replaced_id = dp.ReadCell();

	delete dp;

	int newtank = GetClientOfUserId(userid);
	int tank = GetClientOfUserId(replaced_id);

	// if the replaced player still owns an alive tank, this replacement should be considered failed.
	if (tank && IsClientInGame(tank) && IsPlayerAlive(tank) && GetClientTeam(tank) == 3 && GetEntProp(tank, Prop_Send, "m_zombieClass") == 5)
		return;

	// double check
	if (!newtank || !IsClientInGame(newtank) || !IsPlayerAlive(newtank) || GetClientTeam(newtank) != 3 || GetEntProp(newtank, Prop_Send, "m_zombieClass") != 5)
		return;

	//PrintToChatAll("L4D_OnReplaceTank - tank: %d, newtank: %d", tank, newtank);
	delete hTankTimer;
	hTankTimer = CreateTimer(0.3, timerTank, GetClientUserId(tank), TIMER_REPEAT)
	bHaveHadFlowOrStaticTank = true;
}

Action timerTank(Handle timer, int iTank)
{
	iTank = GetClientOfUserId(iTank);
	if (iTank && IsClientInGame(iTank) && GetClientTeam(iTank) == 3 && IsPlayerAlive(iTank) && GetEntProp(iTank, Prop_Send, "m_zombieClass") == 5)
	{
		int current = GetBossProximity();

		if (current == 0) 
			return Plugin_Continue;

		int diff = tankSpawnedSurvivorFlow - current;
		int flowPercent = convarRageFlowPercent.IntValue;

		if (diff >= flowPercent)
		{
			float fTimeToAdd = 0.0;

			for (int i = diff; i >= flowPercent; i -= flowPercent)
			{
				tankSpawnedSurvivorFlow -= flowPercent;
				fTimeToAdd += convarRageFreezeTime.FloatValue;
			}

			int tankFrustration = 100 - L4D_GetTankFrustration(iTank);
			float fTankGrace = CTimer_GetRemainingTime(GetFrustrationTimer(iTank));

			if (fTankGrace < 0.0) fTankGrace = 0.0;

			if (convarDebug.BoolValue)
			{
				PrintToChatAll("\x04[\x03%N\x04]\x01: Flow Difference since last check: %i", iTank, diff);
				PrintToChatAll("\x04[\x03%N\x04]\x01: Frus: \x03%i \x01- Grace: \x03%f\x04s", iTank, tankFrustration, fTankGrace);
				PrintToChatAll("\x04[\x03%N\x04]\x01: Set Grace To: \x03%f\x04s", iTank, fTankGrace + fTimeToAdd);
			}

			fTankGrace += fTimeToAdd;
			CTimer_Start(GetFrustrationTimer(iTank), fTankGrace);
		}

		return Plugin_Continue;
	}
	else
	{	
		hTankTimer = null;
		return Plugin_Stop;
	}
}

int GetBossProximity()
{
    float fSurvivorCompletion = GetMaxSurvivorCompletion();

    if (fSurvivorCompletion == 0.0) 
        return 0;

    float proximity = fSurvivorCompletion + g_hVsBossBuffer.FloatValue / L4D2Direct_GetMapMaxFlowDistance();

    return RoundToNearest(((proximity > 1.0) ? 1.0 : proximity) * 100.0);
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
            else return 0.0;
        }
    }

    return (flow / L4D2Direct_GetMapMaxFlowDistance());
}

CountdownTimer GetFrustrationTimer(int client)
{
    static int s_iOffs_m_frustrationTimer = -1;
    if (s_iOffs_m_frustrationTimer == -1)
        s_iOffs_m_frustrationTimer = FindSendPropInfo("CTerrorPlayer", "m_frustration") + 4;
    
    return view_as<CountdownTimer>(GetEntityAddress(client) + view_as<Address>(s_iOffs_m_frustrationTimer));
}

InSecondHalfOfRound()
{
    return GameRules_GetProp("m_bInSecondHalfOfRound");
}

int min(int a, int b) 
{
    return a < b ? a : b;
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

	Format(sName, sizeof(sName), "translations/%s.txt", translation);
	BuildPath(Path_SM, sPath, sizeof(sPath), sName);
	if (!FileExists(sPath))
		SetFailState("Missing translation file %s.txt", translation);

	LoadTranslations(translation);
}