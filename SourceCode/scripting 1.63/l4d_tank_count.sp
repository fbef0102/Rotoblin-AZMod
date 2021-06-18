#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <colors>
#include <l4d_lib>

#pragma semicolon 1
#define PLUGIN_VERSION "1.1"
#define Debug 0
#define TEAM_SPECTATOR 1
#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3

static bool:g_bIsTankAlive;
static TimeCount[MAXPLAYERS+1];
static FirstTankClient = -1;
static String:FirstTankClientName[32];
static SecondTankClient = -1;
static String:SecondTankClientName[32];
static ThirdTankClient = -1;
static String:ThirdTankClientName[32];
static AiTankClient = -1;
static g_isTank[MAXPLAYERS+1];
static PounchSuccessCount[MAXPLAYERS+1], RockSuccessCout[MAXPLAYERS+1], ToySuccessCount[MAXPLAYERS+1];
new bool:	bIgnoreOverkill		[MAXPLAYERS + 1];	//for hittable hits

public Plugin:myinfo = 
{
	name = "L4D tank hud",
	author = "Harry Potter",
	description = "Show how long is tank alive, and tank punch/rock/car statistics",
	version = PLUGIN_VERSION,
	url = "https://steamcommunity.com/id/fbef0102/"
}

public OnPluginStart()
{
	LoadTranslations("Roto2-AZ_mod.phrases");
	HookEvent("round_start", event_RoundStart, EventHookMode_PostNoCopy);//每回合開始就發生的event
	HookEvent("tank_spawn", PD_ev_TankSpawn, EventHookMode_PostNoCopy);
	HookEvent("entity_killed",		PD_ev_EntityKilled);
	HookEvent("round_end",			PD_ev_RoundEnd,			EventHookMode_PostNoCopy);
}

public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3])
{
	if(!g_bIsTankAlive) return;
	if (!IsValidEdict(victim) || !IsValidEdict(attacker) || !IsValidEdict(inflictor) || GetConVarInt(FindConVar("god")) == 1 ) { return; }
	if (!IsClientAndInGame(victim)) return;
	if (!IsClientAndInGame(attacker)) return;
	
	if (IsInfected(attacker) && IsPlayerTank(attacker) && IsSurvivor(victim))
	{	
		decl String:sClassname[64];
		GetEntityClassname(inflictor, sClassname, 64);
		#if Debug
			decl String:sdamagetype[64] ;
			GetEdictClassname( damagetype, sdamagetype, sizeof( sdamagetype ) ) ;
			PrintToChatAll("victim: %d,attacker:%d ,sClassname is %s, damage is %f, damagetype is %s",victim,attacker,sClassname,damage,sdamagetype);
		#endif
		
		if (StrEqual(sClassname, "tank_rock"))
		{
			RockSuccessCout[attacker]++;
		}
		else if (StrEqual(sClassname, "weapon_tank_claw"))
		{
			PounchSuccessCount[attacker]++;
		}
		else if (StrEqual(sClassname,"prop_physics") || StrEqual(sClassname,"prop_car_alarm"))
		{	
			if(bIgnoreOverkill[victim]) return;
			
			ToySuccessCount[attacker]++;
			
			bIgnoreOverkill[victim] = true;	//standardise them bitchin over-hits
			CreateTimer(1.4, Timed_ClearInvulnerability, victim);
		}
	}
}

public Action:Timed_ClearInvulnerability(Handle:thisTimer, any:victim)
{
	bIgnoreOverkill[victim] = false;
}

public Action:Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(!g_bIsTankAlive) return;
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(IsClientAndInGame(client)&&GetClientTeam(client) == TEAM_INFECTED && GetZombieClass(client) == 5)
	{
		#if Debug
			PrintToChatAll("%N is Tank",client);
		#endif
		if(!IsFakeClient(client))
		{
			if(FirstTankClient == -1)
			{
				FirstTankClient = client;
				GetClientName(client,FirstTankClientName, 32);
			}
			else if (SecondTankClient == -1)
			{
				SecondTankClient = client;
				g_isTank[FirstTankClient] = false;
				GetClientName(client,SecondTankClientName, 32);
			}
			else if (ThirdTankClient == -1 && SecondTankClient != client)
			{
				ThirdTankClient = client;
				g_isTank[SecondTankClient] = false;
				GetClientName(client,ThirdTankClientName, 32);
			}
		}
		else
		{
			for (new i = 1; i <= MaxClients; i++)
			{
				g_isTank[i] = false;
			}
			if(GetConVarInt(FindConVar("rotoblin_enable_2v2"))==1)
			{
				CreateTimer(3.0, PrintTankStats, _, TIMER_FLAG_NO_MAPCHANGE);
				return;
			}
			AiTankClient = client;
		}
		TimeCount[client] = 0;
		g_isTank[client] = true;
		CreateTimer(1.0,CountTimer,client,TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
}
	
public Action:PD_ev_TankSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(!g_bIsTankAlive)
	{
		g_bIsTankAlive = true;
		HookEvent("player_spawn",		Event_PlayerSpawn);
		for (new i = 1; i <= MaxClients; i++)
		{
			if(IsClientAndInGame(i) && IsSurvivor(i))
				SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
		}
	}
}

public Action:CountTimer(Handle:hTimer,any:client) 
{
	if(!IsClientAndInGame(client) || GetClientTeam(client)!=TEAM_INFECTED || !IsPlayerTank(client) || !g_isTank[client]) 
	{	
		return Plugin_Stop;
	}
	
	TimeCount[client]++;
	
	#if Debug
		PrintToChatAll("%N: %d",client,TimeCount[client]);
	#endif
	return Plugin_Continue;

}

public Action:PD_ev_EntityKilled(Handle:event, const String:name[], bool:dontBroadcast)
{
	decl client;
	if (g_bIsTankAlive && IsPlayerTank((client = GetEventInt(event, "entindex_killed"))))
	{
		CreateTimer(1.5, FindAnyTank, client, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action:FindAnyTank(Handle:timer, any:client)
{
	if(!IsTankInGame()){
		g_isTank[client] = false;
		CreateTimer(1.0, PrintTankStats, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action:PrintTankStats(Handle:timer, any:client)
{
	Tank_Stats();
	Clear();
}

public Action:event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	Clear();
}

public Action:PD_ev_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(g_bIsTankAlive)
	{
		g_isTank[IsTankInGame()] = false;
		CreateTimer(1.0, PrintTankStats, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public OnClientPutInServer(client)
{
	if(g_bIsTankAlive)
	{
		SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	}
}

Clear()
{
	if(g_bIsTankAlive)
	{
		UnhookEvent("player_spawn",		Event_PlayerSpawn);
		for (new i = 1; i <= MaxClients; i++)
		{
			SDKUnhook(i, SDKHook_OnTakeDamage, OnTakeDamage);
		}
	}
	
	g_bIsTankAlive = false;
	FirstTankClient = -1;
	SecondTankClient = -1;
	ThirdTankClient = -1;
	AiTankClient = -1;
	for (new i = 1; i <= MaxClients; i++)
	{
		TimeCount[i] = 0;
		g_isTank[i] = false;
		PounchSuccessCount[i] = RockSuccessCout[i] = ToySuccessCount[i] = 0;
	}
}

Tank_Stats()
{

	if(FirstTankClient>0)
		if(SecondTankClient>0||AiTankClient>0)
			CPrintToChatAll("{olive}[TS] %t %t","First Tank","l4d_tank_count1",TimeCount[FirstTankClient]/60,TimeCount[FirstTankClient]%60,PounchSuccessCount[FirstTankClient],RockSuccessCout[FirstTankClient],ToySuccessCount[FirstTankClient]);
		else
			CPrintToChatAll("{olive}[TS] %t %t","Tank","l4d_tank_count1",TimeCount[FirstTankClient]/60,TimeCount[FirstTankClient]%60,PounchSuccessCount[FirstTankClient],RockSuccessCout[FirstTankClient],ToySuccessCount[FirstTankClient]);	
	if(SecondTankClient>0)
		CPrintToChatAll("{olive}[TS] %t %t","Second Tank","l4d_tank_count1",TimeCount[SecondTankClient]/60,TimeCount[SecondTankClient]%60,PounchSuccessCount[SecondTankClient],RockSuccessCout[SecondTankClient],ToySuccessCount[SecondTankClient]);
	if(ThirdTankClient>0)
		CPrintToChatAll("{olive}[TS] %t %t","Third Tank","l4d_tank_count1",TimeCount[ThirdTankClient]/60,TimeCount[ThirdTankClient]%60,PounchSuccessCount[ThirdTankClient],RockSuccessCout[ThirdTankClient],ToySuccessCount[ThirdTankClient]);
	if(AiTankClient>0 && TimeCount[AiTankClient]%60 >= 5)//AI
		CPrintToChatAll("{olive}[TS] %t %t","AI Tank","l4d_tank_count1",TimeCount[AiTankClient]/60,TimeCount[AiTankClient]%60,PounchSuccessCount[AiTankClient],RockSuccessCout[AiTankClient],ToySuccessCount[AiTankClient]);
}

stock GetZombieClass(client) return GetEntProp(client, Prop_Send, "m_zombieClass");

IsTankInGame(exclude = 0)
{
	for (new i = 1; i <= MaxClients; i++)
		if (exclude != i && IsClientInGame(i) && GetClientTeam(i) == TEAM_INFECTED && IsPlayerTank(i) && IsInfectedAlive(i) && !IsIncapacitated(i))
			return i;

	return 0;
}