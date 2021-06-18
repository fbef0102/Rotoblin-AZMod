#pragma semicolon 1

#include <sourcemod>
#include <left4downtown>
#include <l4d_direct>
#include <sdkhooks>

#define MAX(%0,%1) (((%0) > (%1)) ? (%0) : (%1))

#define DEBUG 0

enum L4DSI 
{
    ZC_None,
    ZC_Smoker,
    ZC_Boomer,
    ZC_Hunter,
    ZC_Witch,
    ZC_Tank,
	ZC_InvalidTeam
};

new Handle:hCvarTimerStartDelay;
new Handle:hCvarHordeCountdown;
new Handle:hCvarMinProgressThreshold;

new Float:timerStartDelay;
new hordeCountdown;
new Float:minProgress;
new Float:aliveSince[MAXPLAYERS + 1];
new Float:startingSurvivorCompletion;

new z_max_player_zombies;
//new survivor_limit;
new hordeDelayChecks;

new L4DSI:zombieclass[MAXPLAYERS + 1];
native IsInPause();
native IsInReady();
native Is_Ready_Plugin_On();
static horde_timer_dealy;
static bool:resuce_start,bool:RoundEnd,bool:panic_event,bool:hasleftstartarea,bool:panic_event_colddown,CoutDowning;

public Plugin:myinfo = 
{
	name = "L4D2 Antibaiter",
	author = "Visor,L4D1 modify by Harry",
	description = "Makes you think twice before attempting to bait that shit",
	version = "1.4",
	url = "https://github.com/ConfoglTeam/ProMod"
};

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	CreateNative("antibaiter_clear", Native_Antibaiter_Clear);
	return APLRes_Success;
}

public OnPluginStart()
{
	LoadTranslations("Roto2-AZ_mod.phrases");
	hCvarTimerStartDelay = CreateConVar("l4d_antibaiter_delay", "15", "Delay in seconds before the antibait algorithm kicks in", FCVAR_PLUGIN);
	hCvarHordeCountdown = CreateConVar("l4d_antibaiter_horde_timer", "60", "Countdown in seconds to the panic horde", FCVAR_PLUGIN);
	hCvarMinProgressThreshold = CreateConVar("l4d_antibaiter_progress", "0.03", "Minimum progress the survivors must make to reset the antibaiter timer", FCVAR_PLUGIN);
	
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("player_left_start_area", LeftStartAreaEvent, EventHookMode_PostNoCopy);
	HookEvent("finale_start", Event_Finale_Start);
	HookEvent("create_panic_event", Event_create_panic_event);
	
	RoundEnd = false;
	resuce_start = false;
	panic_event = false;
	panic_event_colddown = false;
	hordeDelayChecks = 0;
	InitiateCountdown();
	CreateTimer(1.0, AntibaiterThink, _, TIMER_REPEAT);
#if DEBUG
	RegConsoleCmd("sm_regsi", RegisterSI);
#endif
}

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{	
	hasleftstartarea = false;
	RoundEnd = false;
	resuce_start = false;
	panic_event = false;
	panic_event_colddown = false;
	hordeDelayChecks = 0;
	InitiateCountdown();
}
public Action:Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{	
	RoundEnd = true;
}
#if DEBUG
public Action:RegisterSI(client, args)
{
	for (new i = 1; i <= MaxClients; i++) 
	{
		if (!IsInfected(i)) continue;
		if (IsPlayerAlive(i))
		{
			zombieclass[i] = GetZombieClass(i);
			aliveSince[i] = GetGameTime();
		}
	}
}
#endif

public LeftStartAreaEvent(Handle:event, String:name[], bool:dontBroadcast)
{
	if(!Is_Ready_Plugin_On())
	{
		for (new i = 1; i <= MaxClients; i++) 
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

public Native_Antibaiter_Clear(Handle:plugin, numParams)
{
	for (new i = 1; i <= MaxClients; i++) 
	{
		if (!IsInfected(i)) continue;
		if (IsPlayerAlive(i))
		{
			zombieclass[i] = GetZombieClass(i);
			aliveSince[i] = GetGameTime();
		}
	}
}

public OnConfigsExecuted()
{
	z_max_player_zombies = GetConVarInt(FindConVar("z_max_player_zombies"));
	//survivor_limit = GetConVarInt(FindConVar("survivor_limit"));
	timerStartDelay = GetConVarFloat(hCvarTimerStartDelay);
	hordeCountdown = GetConVarInt(hCvarHordeCountdown);
	minProgress = GetConVarFloat(hCvarMinProgressThreshold);
}
	
public Action:AntibaiterThink(Handle:timer) 
{
	//new SUsedSlots = GetTeamHumanCount(2);
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
	if (IsInReady() || IsPanicEventInProgress() || FindTank() > 0 )//|| SUsedSlots != survivor_limit)//準備 屍潮 坦克 人類真人玩家沒達到人類數量上限 初始化倒數
	{
	#if DEBUG
		PrintToChatAll("Is Ready,Panic,Tank");
	#endif
		hordeDelayChecks = 0;
		InitiateCountdown();
		return Plugin_Handled;
	}
	
	new eligibleZombies = 0;
	for (new i = 1; i <= MaxClients; i++) 
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
	if (eligibleZombies > z_max_player_zombies)
	{
	#if DEBUG
		PrintToChatAll("\x03[Antibaiter DEBUG] Spectator bug detected: \x04eligibleZombies\x01=\x05%d\x01, \x04z_max_player_zombies\x01=\x05%d\x01", eligibleZombies, z_max_player_zombies);
	#endif
		return Plugin_Continue;
	}

	if (eligibleZombies == z_max_player_zombies)
	{
		new Float:survivorCompletion = GetMaxSurvivorCompletion();//活著能走路的最遠的人類位置為記錄點
		new Float:progress = Float:survivorCompletion - Float:startingSurvivorCompletion;
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
				for (new i = 1; i <= MaxClients; i++)
				{
					if (IsClientInGame(i) && !IsFakeClient(i))
					{
						PrintHintText(i, "%T","Survivors must move forward",i,horde_timer_dealy);
						CoutDowning = true;
					}
				}
				horde_timer_dealy--;//倒數30秒
				if (horde_timer_dealy==0)//倒數已到 引發屍潮
				{
					for (new i = 1; i <= MaxClients; i++)
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
	return Plugin_Handled;
}

public L4D_OnEnterGhostState(client)
{
	zombieclass[client] = GetZombieClass(client);
	aliveSince[client] = GetGameTime();
}

/*******************************/
/** Horde/countdown functions **/
/*******************************/

InitiateCountdown()
{
	horde_timer_dealy = hordeCountdown;
	if(CoutDowning)
	{
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && !IsFakeClient(i))
			{
				PrintHintText(i, " ");
			}
		}
	}
	CoutDowning = false;
}

LaunchHorde()
{
	//PrintToChatAll("\x01[\x05TS\x01] \x05倖存者 \x01龜點不前進, 自動引發 \x03屍潮\x01!");
	new client = -1;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			client = i;
			break;
		}
	}
	if (client != -1)
	{
		new String:command[] = "director_force_panic_event";
		new flags = GetCommandFlags(command);
		SetCommandFlags(command, flags & ~FCVAR_CHEAT);
		FakeClientCommand(client, command);
		SetCommandFlags(command, flags);
	}
}

/************/
/** Stocks **/
/************/

Float:GetMaxSurvivorCompletion()//以人類目前沒有倒地不懸掛還活著站的玩家位置為基底
{
	new Float:flow = 0.0;
	for (new i = 1; i <= MaxClients; i++)
	{
		// Prevent rushers from convoluting the logic
		if (IsSurvivor(i) && IsPlayerAlive(i) && !IsIncapped(i)&& !GetEntProp(i, Prop_Send, "m_isHangingFromLedge"))
		{
			flow = MAX(flow, L4DDirect_GetFlowDistance(i));
		}
	}
	return (flow / L4DDirect_GetMapMaxFlowDistance());
}

bool:IsSurvivor(client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2;
}

bool:IsInfected(client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3;
}

L4DSI:GetZombieClass(client)
{
	return L4DSI:GetEntProp(client, Prop_Send, "m_zombieClass");
}

bool:IsIncapped(client)
{
	return bool:GetEntProp(client, Prop_Send, "m_isIncapacitated");
}

// director_force_panic_event & car alarms etc.
bool:IsPanicEventInProgress()
{
	#if DEBUG
		PrintToChatAll("L4DDirect_GetMobSpawnTimer: %f",RoundFloat(CTimer_GetRemainingTime(L4DDirect_GetMobSpawnTimer())));
	#endif
	
	if(resuce_start)
		return true;
		
	if (panic_event == true)//MobSpawnTimer will be reset after vomit/alarm car/panic event
	{
		if(RoundFloat(CTimer_GetRemainingTime(L4DDirect_GetMobSpawnTimer())) <= 0)//胖子噴到當下立馬reset,alarm car/panic event 需要等待屍潮冷靜之後才會reset, 所以胖子噴到並不會重新計時
			return true;
		else //屍潮結束之時
		{
			if(!panic_event_colddown)
			{
				CreateTimer(15.0,COLD_DOWN,_); //給予喘息空間
				panic_event_colddown = true;
			}
			return true;
		}
	}
		
	return false;
}


public Action:COLD_DOWN(Handle:timer,any:client)
{
	panic_event = false;
	panic_event_colddown = false;
}

stock Address:L4DD_GetCDirectorScriptedEventManager()
{
	static Address:pScriptedEventManager = Address_Null;
	if (pScriptedEventManager == Address_Null)
	{
		new offs = GameConfGetOffset(L4DDirect_GetGameConf(), "CDirectorScriptedEventManager");
		if(offs == -1) return Address_Null;
		pScriptedEventManager = L4DDirect_GetCDirector() + Address:offs;
		pScriptedEventManager = Address:LoadFromAddress(pScriptedEventManager , NumberType_Int32);
	}
	return pScriptedEventManager;
}

FindTank() 
{
	for (new i = 1; i <= MaxClients; i++) 
	{
		if (IsInfected(i) && GetZombieClass(i) == ZC_Tank && IsPlayerAlive(i))
			return i;
	}

	return -1;
}

public Action:Event_Finale_Start(Handle:event, const String:name[], bool:dontBroadcast)
{
	resuce_start = true;
}

public Event_create_panic_event(Handle:event, String:name[], bool:dontBroadcast)
{
	
	#if DEBUG
		new client = GetClientOfUserId( GetEventInt(event, "userid") );
		PrintToChatAll("----------------Panic Event: %N--------------------",client);
	#endif
	
	panic_event = true;
	panic_event_colddown = false;
}