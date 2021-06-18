#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <l4d_lib>

#define HUNTER       3
#define MAX_HUNTERSOUND         2
#define IS_VALID_CLIENT(%1)     (%1 > 0 && %1 <= MaxClients)
#define IS_INFECTED(%1)         (GetClientTeam(%1) == 3)
#define IS_VALID_INGAME(%1)     (IS_VALID_CLIENT(%1) && IsClientInGame(%1))
#define IS_VALID_INFECTED(%1)   (IS_VALID_INGAME(%1) && IS_INFECTED(%1))
#define DEBUG 0
#define HUNTERCROUCHTRACKING_TIMER 1.8

new const String: sHunterSound[MAX_HUNTERSOUND + 1][] =
{
    "player/hunter/voice/idle/hunter_stalk_01.wav",
	"player/hunter/voice/idle/hunter_stalk_04.wav",
	"player/hunter/voice/idle/hunter_stalk_05.wav"
};

new bool:isHunter[MAXPLAYERS+1];
static					g_iOffsetFallVelocity					= -1;
static	const	String:	CLASSNAME_TERRORPLAYER[] 				= "CTerrorPlayer";
static	const	String:	NETPROP_FALLVELOCITY[]					= "m_flFallVelocity";

public Plugin:myinfo = 
{
    name = "Hunter Crouch Sounds",
    author = "High Cookie,l4d1 port by Harry",
    description = "Forces silent but crouched hunters to emitt sounds",
    version = "1.3",
    url = ""
};

public OnPluginStart()
{
   HookEvent("player_spawn",Event_PlayerSpawn,              EventHookMode_Post);
   HookEvent("player_death", Event_PlayerDeath);
   HookEvent("round_start", event_RoundStart);//每回合開始就發生的event
   g_iOffsetFallVelocity = FindSendPropInfo(CLASSNAME_TERRORPLAYER, NETPROP_FALLVELOCITY);
   if (g_iOffsetFallVelocity <= 0) ThrowError("Unable to find fall velocity offset!");
}

public OnMapStart()
{
    for (new i = 0; i <= MAX_HUNTERSOUND; i++)
    {
        PrefetchSound(sHunterSound[i]);
        PrecacheSound(sHunterSound[i], true);
    }
}

public Action:event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	new i;
	for(i=0;i<=MAXPLAYERS;++i)
	{
		isHunter[i] = false;
	}
}

public Action: Event_PlayerSpawn( Handle:event, const String:name[], bool:dontBroadcast )
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    if ( !IS_VALID_INFECTED(client) ) { return; }
    
    new zClass = GetEntProp(client, Prop_Send, "m_zombieClass");
    if (zClass == HUNTER)
	{
		isHunter[client] = true;
		CreateTimer(HUNTERCROUCHTRACKING_TIMER, HunterCrouchTracking, client, TIMER_REPEAT);
	}
}

public Action:HunterCrouchTracking(Handle:timer, any:client) 
{
	if (!isHunter[client]) {return Plugin_Stop;}

	if ( !IsClientAndInGame(client) || GetClientTeam(client) != 3 || GetEntProp(client, Prop_Send, "m_zombieClass") != HUNTER || !IsPlayerAlive(client)) //離線,跳隊,非Hunter,已死亡
	{
		isHunter[client] = false;
		return Plugin_Stop;
	}
	
	if (HasTarget(client))
	{
		return Plugin_Continue;
	}
	
	if (GetClientButtons(client) & IN_DUCK){ return Plugin_Continue; }
	new ducked = GetEntProp(client, Prop_Send, "m_bDucked");
	if (ducked && GetEntDataFloat(client, g_iOffsetFallVelocity) == 0.0)
	{
		#if DEBUG
			PrintToChatAll("0.2s later check again");
		#endif
		CreateTimer(0.2, HunterCrouchReallyCheck, client, _);
	}
	return Plugin_Continue;
}

public Action:HunterCrouchReallyCheck(Handle:timer, any:client) 
{
	if ( !IsClientAndInGame(client) || GetClientTeam(client) != 3 || GetEntProp(client, Prop_Send, "m_zombieClass") != HUNTER || !IsPlayerAlive(client))
	{
		return Plugin_Continue;
	}
	if (GetClientButtons(client) & IN_DUCK){ return Plugin_Continue; }
	new ducked = GetEntProp(client, Prop_Send, "m_bDucked");
	if (ducked && GetEntDataFloat(client, g_iOffsetFallVelocity) == 0.0)
	{
		new rndPick = GetRandomInt(0, MAX_HUNTERSOUND);
		EmitSoundToAll(sHunterSound[rndPick], client, SNDCHAN_VOICE);
		#if DEBUG
			PrintToChatAll("Spawn Sound");
		#endif
	}
	return Plugin_Continue;
}

public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast) 
{
	new victim = GetEventInt(event, "userid");
	new client = GetClientOfUserId(victim);
	isHunter[client] = false;
}

bool:HasTarget(hunter)
{
	new hasvictim = GetEntPropEnt(hunter, Prop_Send, "m_pounceVictim");
	if(IsSurvivors(hasvictim)) //已經撲人
	{
		return true;
	}
	return false;
}

stock bool:IsSurvivors(client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2;
}