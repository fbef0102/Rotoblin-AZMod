#pragma semicolon 1
#pragma newdecls required //強制1.7以後的新語法

#include <sourcemod>
#include <sdkhooks>
#include <left4dhooks>

#define MAX(%0,%1) (((%0) > (%1)) ? (%0) : (%1))

#define DEBUG 0

#define ZC_None 0
#define ZC_Smoker 1
#define ZC_Boomer 2
#define ZC_Hunter 3
#define ZC_Witch 4
#define ZC_Tank 5

ConVar hCvarTimerStartDelay;
ConVar hCvarHordeCountdown;
ConVar hCvarMinProgressThreshold;

float timerStartDelay;
int hordeCountdown;
float minProgress;
float aliveSince[MAXPLAYERS + 1];
float startingSurvivorCompletion;

ConVar z_max_player_zombies, survivor_limit;
int z_max_player_zombies_value, survivor_limit_value;
int hordeDelayChecks;

int zombieclass[MAXPLAYERS + 1];
native bool IsInPause();
native bool IsInReady();
native bool Is_Ready_Plugin_On();
int horde_timer_dealy;
bool resuce_start,RoundEnd,panic_event,hasleftstartarea,CoutDowning;
Handle COLD_DOWN_Timer;

public Plugin myinfo = 
{
	name = "L4D2 Antibaiter",
	author = "Visor,L4D1 modify by Harry",
	description = "Makes you think twice before attempting to bait that shit",
	version = "1.7",
	url = "https://github.com/ConfoglTeam/ProMod"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	
	if( test != Engine_Left4Dead )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1.");
		return APLRes_SilentFailure;
	}

	CreateNative("antibaiter_clear", Native_Antibaiter_Clear);
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("Roto2-AZ_mod.phrases");

	z_max_player_zombies = FindConVar("z_max_player_zombies");
	survivor_limit = FindConVar("survivor_limit");
	hCvarTimerStartDelay = CreateConVar("l4d_antibaiter_delay", "15", "Delay in seconds before the antibait algorithm kicks in", FCVAR_NOTIFY);
	hCvarHordeCountdown = CreateConVar("l4d_antibaiter_horde_timer", "60", "Countdown in seconds to the panic horde", FCVAR_NOTIFY);
	hCvarMinProgressThreshold = CreateConVar("l4d_antibaiter_progress", "0.03", "Minimum progress the survivors must make to reset the antibaiter timer", FCVAR_NOTIFY);
	
	GetCvars();
	z_max_player_zombies.AddChangeHook(ConVarChanged);
	survivor_limit.AddChangeHook(ConVarChanged);
	hCvarTimerStartDelay.AddChangeHook(ConVarChanged);
	hCvarHordeCountdown.AddChangeHook(ConVarChanged);
	hCvarMinProgressThreshold.AddChangeHook(ConVarChanged);

	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("player_left_start_area", LeftStartAreaEvent, EventHookMode_PostNoCopy);
	HookEvent("finale_start", Event_Finale_Start);
	HookEvent("create_panic_event", Event_create_panic_event);
	
	RoundEnd = false;
	resuce_start = false;
	panic_event = false;
	hordeDelayChecks = 0;
	InitiateCountdown();
	CreateTimer(1.0, AntibaiterThink, _, TIMER_REPEAT);
#if DEBUG
	RegConsoleCmd("sm_regsi", RegisterSI);
#endif
}

public void OnMapEnd()
{
	ResetTimer();
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{	
	hasleftstartarea = false;
	RoundEnd = false;
	resuce_start = false;
	panic_event = false;
	hordeDelayChecks = 0;
	InitiateCountdown();
}
public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{	
	RoundEnd = true;
	ResetTimer();
}
#if DEBUG
public Action RegisterSI(cint lient, int args)
{
	for (int i = 1; i <= MaxClients; i++) 
	{
		if (!IsInfected(i)) continue;
		if (IsPlayerAlive(i))
		{
			zombieclass[i] = GetZombieClass(i);
			aliveSince[i] = GetGameTime();
		}
	}

	return Plugin_Handled;
}
#endif

public void LeftStartAreaEvent(Event event, const char[] name, bool dontBroadcast)
{
	if(!Is_Ready_Plugin_On())
	{
		for (int i = 1; i <= MaxClients; i++) 
		{
			if (!IsInfected(i)) continue;
			if (IsPlayerAlive(i))
			{
				zombieclass[i] = GetZombieClass(i);
				aliveSince[i] = GetGameTime();
			}
		}
		hasleftstartarea = true;
	}
}

public int Native_Antibaiter_Clear(Handle plugin, int numParams)
{
	for (int i = 1; i <= MaxClients; i++) 
	{
		if (!IsInfected(i)) continue;
		if (IsPlayerAlive(i))
		{
			zombieclass[i] = GetZombieClass(i);
			aliveSince[i] = GetGameTime();
		}
	}

	return 0;
}

public void ConVarChanged(Handle convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	z_max_player_zombies_value = z_max_player_zombies.IntValue;
	survivor_limit_value = survivor_limit.IntValue;
	timerStartDelay = hCvarTimerStartDelay.FloatValue;
	hordeCountdown = hCvarHordeCountdown.IntValue;
	minProgress = hCvarMinProgressThreshold.FloatValue;
}

public Action AntibaiterThink(Handle timer) 
{
	int SUsedSlots = GetTeamHumanCount(2);
	if(IsInPause())//中途暫停 暫停倒數
	{
	#if DEBUG
		PrintToChatAll("Is Pause");
	#endif
        return Plugin_Handled;
	}
	if(!Is_Ready_Plugin_On()&&!hasleftstartarea)
	{
	#if DEBUG
		PrintToChatAll("Is in saferoom");
	#endif
        return Plugin_Handled;
	}
	if(RoundEnd)
	{
	#if DEBUG
		PrintToChatAll("Is RoundEnd");
	#endif
       return Plugin_Handled;
	}
	if (IsInReady() || IsPanicEventInProgress() || FindTank() > 0 || SUsedSlots < survivor_limit_value)//準備 屍潮 坦克 人類真人玩家沒達到人類數量上限 初始化倒數
	{
	#if DEBUG
		PrintToChatAll("Is Ready, Panic, Tank, not enough survivors");
	#endif
		hordeDelayChecks = 0;
		InitiateCountdown();
		return Plugin_Handled;
	}
	
	int eligibleZombies = 0;
	for (int i = 1; i <= MaxClients; i++) 
	{
		if (!IsInfected(i) || IsFakeClient(i)) continue;
		if (IsPlayerAlive(i))//全體特感活著(靈魂也算)並超過15秒才開始記錄路程與倒數15秒
		{
			zombieclass[i] = GetZombieClass(i);
			if (zombieclass[i] > ZC_None && zombieclass[i] < ZC_Witch
				&& aliveSince[i] != -1.0 && GetGameTime() - aliveSince[i] >= timerStartDelay)
			{
			#if DEBUG
				PrintToChatAll("\x03[Antibaiter DEBUG] Alive(Ghost) player \x04%N\x01 is a zombieclass \x05%d\x01 alive for \x05%fs\x01", i, _:zombieclass[i], GetGameTime() - aliveSince[i]);
			#endif
				eligibleZombies++;
			}
		}
		else//死掉一隻特感  GG 重來計時
		{
			aliveSince[i] = -1.0;
			hordeDelayChecks = 0;
			InitiateCountdown();
		}
	}

	// 5th SI / spectator bug workaround
	if (eligibleZombies > z_max_player_zombies_value)
	{
	#if DEBUG
		PrintToChatAll("\x03[Antibaiter DEBUG] Spectator bug detected: \x04eligibleZombies\x01=\x05%d\x01, \x04z_max_player_zombies\x01=\x05%d\x01", eligibleZombies, z_max_player_zombies);
	#endif
		return Plugin_Continue;
	}

	if (eligibleZombies == z_max_player_zombies_value)
	{
		float survivorCompletion = GetMaxSurvivorCompletion();//活著能走路的最遠的人類位置為記錄點
		float progress = survivorCompletion - startingSurvivorCompletion;
		if (progress <= minProgress
			&& hordeDelayChecks >= RoundToNearest(timerStartDelay))//全體特感活著並超過15秒,路程小於0.03 並已再超過15秒
		{
		#if DEBUG
			PrintToChatAll("\x03[Antibaiter DEBUG] Minimum progress unsatisfied during \x05%d\x01 checks: \x04initial\x01=\x05%f\x01, \x04current\x01=\x05%f\x01, \x04progress\x01=\x05%f\x01, horde_timer_dealy = %d", hordeDelayChecks, startingSurvivorCompletion, survivorCompletion, progress,horde_timer_dealy);
		#endif
			if (horde_timer_dealy>=0)
			{
			#if DEBUG
				PrintToChatAll("\x03[Antibaiter DEBUG] Countdown is \x05running\x01");
			#endif
				if (horde_timer_dealy==0)//倒數已到 引發屍潮
				{
					for (int i = 1; i <= MaxClients; i++)
					{
						if (IsClientInGame(i) && !IsFakeClient(i))
						{
							PrintHintText(i, "%T","Force Panic Event!!",i);
							CoutDowning = false;
						}
					}
				#if DEBUG
					PrintToChatAll("\x03[Antibaiter DEBUG] Countdown has \x04elapsed\x01! Launching horde and resetting checks counter");
				#endif
					LaunchHorde();
					hordeDelayChecks = 0;
				}
				else
				{
					for (int i = 1; i <= MaxClients; i++)
					{
						if (IsClientInGame(i) && !IsFakeClient(i))
						{
							PrintHintText(i, "%T","Survivors must move forward",i,horde_timer_dealy);
							CoutDowning = true;
						}
					}
				}
				horde_timer_dealy--;//倒數30秒
			}
			else
			{
			#if DEBUG
				PrintToChatAll("\x03[Antibaiter DEBUG] Countdown is \x05not running\x01. Initiating it...");
			#endif
				InitiateCountdown();
			}
		}
		else//超過0.03路程  重來計時
		{
			if (hordeDelayChecks == 0)
			{
				startingSurvivorCompletion = survivorCompletion;
			}
			if (progress > minProgress)
			{
			#if DEBUG
				PrintToChatAll("\x03[Antibaiter DEBUG] Survivor progress has \x05increased\x01 beyond the minimum threshold. Resetting the algorithm...");
			#endif
				startingSurvivorCompletion = survivorCompletion;
				hordeDelayChecks = 0;
			}

			hordeDelayChecks++;
			InitiateCountdown();
		}
	}

	return Plugin_Continue;
}

public void L4D_OnEnterGhostState(int client)
{
	zombieclass[client] = GetZombieClass(client);
	aliveSince[client] = GetGameTime();
}

/*******************************/
/** Horde/countdown functions **/
/*******************************/

void InitiateCountdown()
{
	horde_timer_dealy = hordeCountdown;
	if(CoutDowning)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && !IsFakeClient(i))
			{
				PrintHintText(i, " ");
			}
		}
	}
	CoutDowning = false;
}

void LaunchHorde()
{
	//PrintToChatAll("\x01[\x05TS\x01] \x05倖存者 \x01龜點不前進, 自動引發 \x03屍潮\x01!");
	int anyclient = GetRandomClient();
	if(anyclient > 0)
	{
		char sCommand[16];
		strcopy(sCommand, sizeof(sCommand), "z_spawn");
		int flags = GetCommandFlags(sCommand);
		SetCommandFlags(sCommand, flags & ~FCVAR_CHEAT);
		FakeClientCommand(anyclient, "z_spawn mob auto"); // This won't affect director panic event/map event/alarm car/boomer horde, and can call it multi times to spawn multi hordes
		FakeClientCommand(anyclient, "z_spawn mob auto"); // horde twice
		SetCommandFlags(sCommand, flags);
	}

	panic_event = true;
	delete COLD_DOWN_Timer;
	COLD_DOWN_Timer = CreateTimer(50.0, COLD_DOWN); //給予喘息空間
}

/************/
/** Stocks **/
/************/

float GetMaxSurvivorCompletion()//以人類目前沒有倒地不懸掛還活著站的玩家位置為基底
{
	float flow = 0.0;
	for (int i = 1; i <= MaxClients; i++)
	{
		// Prevent rushers from convoluting the logic
		if (IsSurvivor(i) && IsPlayerAlive(i) && !L4D_IsPlayerIncapacitated(i) && !L4D_IsPlayerHangingFromLedge(i))
		{
			flow = MAX(flow, L4D2Direct_GetFlowDistance(i));
		}
	}
	return (flow / L4D2Direct_GetMapMaxFlowDistance());
}

bool IsSurvivor(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2;
}

bool IsInfected(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3;
}

int GetZombieClass(int client)
{
	return GetEntProp(client, Prop_Send, "m_zombieClass");
}

// director_force_panic_event & car alarms etc.
bool IsPanicEventInProgress()
{
	if (resuce_start)
		return true;
		
	if (panic_event == true)//MobSpawnTimer will be reset after vomit/alarm car/panic event
	{
		if(RoundFloat(CTimer_GetRemainingTime(L4D2Direct_GetMobSpawnTimer())) <= 0)//胖子噴到當下立馬reset,alarm car/panic event 需要等待屍潮冷靜之後才會reset, 所以胖子噴到並不會重新計時
		{
			#if DEBUG
				PrintToChatAll("Panic Event not cool down yet");
			#endif
			return true;
		}
		else //屍潮結束之時
		{
			if(COLD_DOWN_Timer == null)
			{
				delete COLD_DOWN_Timer;
				COLD_DOWN_Timer = CreateTimer(25.0, COLD_DOWN); //給予喘息空間
			}
			return true;
		}
	}
		
	return false;
}


public Action COLD_DOWN(Handle timer)
{
	panic_event = false;

	COLD_DOWN_Timer = null;
	return Plugin_Continue;
}

int FindTank() 
{
	for (int i = 1; i <= MaxClients; i++) 
	{
		if (IsInfected(i) && GetZombieClass(i) == ZC_Tank && IsPlayerAlive(i))
			return i;
	}

	return -1;
}

public void Event_Finale_Start(Event event, const char[] name, bool dontBroadcast)
{
	resuce_start = true;
}

public void Event_create_panic_event(Event event, const char[] name, bool dontBroadcast)
{
	
	#if DEBUG
		int client = GetClientOfUserId( GetEventInt(event, "userid") );
		PrintToChatAll("----------------Panic Event: %N--------------------",client);
	#endif
	
	panic_event = true;
	delete COLD_DOWN_Timer;
}

stock int GetTeamHumanCount(int team)
{
	int humans = 0;
	
	int i;
	for(i = 1; i < MaxClients + 1; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == team)
		{
			humans++;
		}
	}
	
	return humans;
}

void ResetTimer()
{
	delete COLD_DOWN_Timer;
}