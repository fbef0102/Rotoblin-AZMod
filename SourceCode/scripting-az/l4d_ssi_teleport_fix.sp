#pragma semicolon 1
#pragma newdecls required //強制1.7以後的新語法

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <left4dhooks>

#define  MIN(%0,%1) (((%0) < (%1)) ? (%0) : (%1))
#define L4DInfected_Smoker 1
#define L4DInfected_Boomer 2
#define L4DInfected_Hunter 3
#define L4DInfected_Tank   5

ConVar g_hDiscardRange;
ConVar g_hCheckinterval;
ConVar g_hTeleRangeMax;
ConVar g_hTeleRangeMin;
ConVar g_hTeleLimit;
ConVar g_hBoomer2Tank;
ConVar g_hGodTime;
ConVar g_hTeleCoolDownTime;

bool GodTime[MAXPLAYERS + 1], ge_bInvalidTrace[2048+1];
bool g_bRoundAlive;
bool g_bBoomer2Tank;
float g_fGodTime;
float g_fCheckinterval;
float g_fTeleCoolDownTime;
float g_fClientTeleTime[MAXPLAYERS + 1];

float g_minRange;
float g_maxRange;
float g_DiscardRange;
int g_iSsitpLimit;
int sitele2[MAXPLAYERS + 1] = {-1};
int si2tele[MAXPLAYERS + 1] = {-1};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();

	if( test != Engine_Left4Dead )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1.");
		return APLRes_SilentFailure;
	}

	return APLRes_Success;
}

public Plugin myinfo = 
{
	name = "Super SI Teleport.", 
	author = "AiMee, Harry Potter", 
	description = "Teleport infected player (Not tank) to the teammate who is much nearer to survivors.", 
	version = "1.4", 
	url = "https://steamcommunity.com/id/TIGER_x_DRAGON/"
};

public void OnPluginStart()
{
	g_hDiscardRange  	= CreateConVar("ssitp_tp1_range", 			"600",	"Infected player will be teleported if his distance is outside this range.", FCVAR_NOTIFY, true, 1.0);
	g_hTeleRangeMax 	= CreateConVar("ssitp_tp2_range_max", 		"800", 	"Teleport to the player max range, value must <= 'ssitp_tp1_discard_range'.", FCVAR_NOTIFY, true, 1.0);
	g_hTeleRangeMin 	= CreateConVar("ssitp_tp2_range_min", 		"150", 	"Teleport to the player min range", FCVAR_NOTIFY, true, 0.0);
	g_hCheckinterval 	= CreateConVar("ssitp_check_interval", 		"2.5",	"Time interval to check si.", FCVAR_NOTIFY, true, 1.0);
	g_hTeleLimit		= CreateConVar("ssitp_tp1_limit",   		"2", 	"Limit per teleport.", FCVAR_NOTIFY, true, 1.0);
	g_hBoomer2Tank 		= CreateConVar("ssitp_boomer2tank", 		"0", 	"Teleport boomer to tank?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hGodTime			= CreateConVar("ssitp_tp1_god_time",		"0.6",	"Prevent SI from taking damage for this seconds after being teleported. (0=Disable)", FCVAR_NOTIFY, true, 0.0);
	g_hTeleCoolDownTime	= CreateConVar("ssitp_tp1_cooltime",		"5.0",	"Cold Down Time in seconds an infected can not be teleported again.", FCVAR_NOTIFY, true, 0.0);

	HookEvent("round_start", 	Event_RoundStart, 	EventHookMode_PostNoCopy);
	HookEvent("round_end", 		Event_RoundEnd, 	EventHookMode_PostNoCopy);
	HookEvent("player_spawn", 	Event_PlayerSpawn);
	HookEvent("player_left_start_area", LeftStartAreaEvent, EventHookMode_PostNoCopy);

	GetCvars();
	g_hCheckinterval.AddChangeHook(ConVarChanged_Cvars);
	g_hTeleLimit.AddChangeHook(ConVarChanged_Cvars);
	g_hBoomer2Tank.AddChangeHook(ConVarChanged_Cvars);
	g_hGodTime.AddChangeHook(ConVarChanged_Cvars);
	g_hTeleRangeMin.AddChangeHook(ConVarChanged_Cvars);
	g_hTeleRangeMax.AddChangeHook(ConVarChanged_Cvars);
	g_hDiscardRange.AddChangeHook(ConVarChanged_Cvars);
	g_hTeleCoolDownTime.AddChangeHook(ConVarChanged_Cvars);
}

void ConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_fCheckinterval 	= g_hCheckinterval.FloatValue;
	g_iSsitpLimit		= g_hTeleLimit.IntValue;
	g_bBoomer2Tank		= g_hBoomer2Tank.BoolValue;
	g_fGodTime			= g_hGodTime.FloatValue;
	g_minRange 			= g_hTeleRangeMin.FloatValue;
	g_maxRange 			= g_hTeleRangeMax.FloatValue;
	g_DiscardRange		= g_hDiscardRange.FloatValue;
	g_fTeleCoolDownTime = g_hTeleCoolDownTime.FloatValue;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (!IsValidEntityIndex(entity))
		return;
		
	switch (classname[0])
	{
		case 't':
		{
			if (StrEqual(classname, "tank_rock"))
				ge_bInvalidTrace[entity] = true;
		}
		case 'i':
		{
			if (StrEqual(classname, "infected"))
				ge_bInvalidTrace[entity] = true;
		}
		case 'w':
		{
			if (StrEqual(classname, "witch"))
				ge_bInvalidTrace[entity] = true;
		}
		case 'e':
		{
			if (StrEqual(classname, "env_physics_blocker") 
				|| StrEqual(classname, "env_player_blocker"))
				ge_bInvalidTrace[entity] = true;
		}
	}
}

public void OnEntityDestroyed(int entity)
{
	if (!IsValidEntityIndex(entity))
		return;

	ge_bInvalidTrace[entity] = false;
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!client || !IsClientInGame(client)) return;
	g_fClientTeleTime[client] = 0.0;
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_bRoundAlive = false;

	for(int i = 1; i<=MaxClients; i++)
	{
		g_fClientTeleTime[i] = 0.0;
	}
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	g_bRoundAlive = false;
}

void LeftStartAreaEvent(Event event, const char[] name, bool dontBroadcast)
{
	g_bRoundAlive 		= true;
	CreateTimer(g_fCheckinterval,Timer_CheckNoobSi, _, TIMER_REPEAT);
}	

Action Timer_CheckNoobSi(Handle timer)
{
	int index = FindSI2Tele();
	int teammate = FindSItele2();
	int tele_count = 0;
	if(index != 0 && teammate != 0)
	{
		for(int i=0 ; i < index ; i++)
		{	
			//PrintToChatAll("%N teleport to %N", si2tele[i], teammate);
			if(TeleOne2One(si2tele[i], teammate))
			{
				if(g_fGodTime > 0)
				{
					SetInGodTime(si2tele[i]);
					CreateTimer(g_fGodTime, Timer_RemoveGod, si2tele[i], TIMER_FLAG_NO_MAPCHANGE);
				}
				tele_count++;

				if(tele_count >= g_iSsitpLimit) break;
			}
		}
	}
	
	if(!g_bRoundAlive)
		return Plugin_Stop;

	return Plugin_Continue;
}

Action Timer_RemoveGod(Handle timer, any client)
{
	GodTime[client] = false;
	ResetGlow(client);

	return Plugin_Continue;
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}
public void OnClientDisconnect(int client)
{
    SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if(IsClientInGame(victim) && IsFakeClient(victim) && GodTime[victim])
	{
		damage = 0.0;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

void SetInGodTime(int client)
{
	GodTime[client] = true;
	SetGodTimeGlow(client);
}

void SetGodTimeGlow(int client) 
{
	if (IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == 3) {
		SetEntityRenderMode( client, view_as<RenderMode>(3) );
		SetEntityRenderColor (client, 255,255,255,150 );
	}
}
void ResetGlow(int client) 
{
	if (IsClientInGame(client)) {
		SetEntityRenderMode(client, view_as<RenderMode>(0));
		SetEntityRenderColor(client, 255,255,255,255);
	}
}

bool CanBeTP(int client) //要被傳送的玩家
{
	if (!IsClientInGame(client) || !IsFakeClient(client))return false;
	if (GetClientTeam(client) != 3 || !IsPlayerAlive(client))return false;
	if (GetInfectedClass(client) == L4DInfected_Tank )return false;
	if (L4D_GetSurvivorVictim(client) != -1) return false; //正在控人類
	if (!(GetEntProp(client, Prop_Send, "m_fFlags") & FL_ONGROUND)) return false; //不在地面上
	if (L4D_IsPlayerStaggering(client)) return false; //硬質中
	if (CanBeSeenBySurvivors(client)) return false;
	return true;
}

bool CanTP2(int client) //傳送目的地的玩家
{
	if(!IsClientInGame(client)) return false;
	if(GetClientTeam(client) != 3 || !IsPlayerAlive(client)) return false;
	if(IsPlayerGhost(client)) return false;
	if(L4D_GetSurvivorVictim(client) != -1) return false; //正在控人類
	if(!(GetEntProp(client, Prop_Send, "m_fFlags") & FL_ONGROUND)) return false; //不在地面上
	if(CanBeSeenBySurvivors(client)) return false; //在人類視野範圍內
	
	return true;
}

stock int FindSItele2()
{
	int index = 0;
	
	for(int i = 1; i<=MaxClients; i++)
	{
		if( CanTP2(i) && !Far(i) && !Close(i) )
		{
			sitele2[index++] = i;
		}
	}

	return (index == 0) ? 0 : sitele2[GetRandomInt(0, index - 1)];
}

stock int FindSI2Tele()
{
	int index = 0;
	float Now_Time = GetEngineTime();
	for(int i = 1; i<=MaxClients; i++)
	{
		if(CanBeTP(i) && TooFar(i) && g_fClientTeleTime[i] < Now_Time)
		{
			si2tele[index++] = i;
		}
	}
	return index;
}

bool TooFar(int client)
{
	float fInfLocation[3], fSurvLocation[3], fVector[3];
	GetClientAbsOrigin(client, fInfLocation);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i)==2 && IsPlayerAlive(i))
		{
			GetClientAbsOrigin(i, fSurvLocation);
			MakeVectorFromPoints(fInfLocation, fSurvLocation, fVector);
			if (GetVectorLength(fVector) <= g_DiscardRange) return false;
		}
	}
	return true;
}

bool Far(int client)
{
	float fInfLocation[3], fSurvLocation[3], fVector[3];
	GetClientAbsOrigin(client, fInfLocation);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i)==2 && IsPlayerAlive(i))
		{
			GetClientAbsOrigin(i, fSurvLocation);
			MakeVectorFromPoints(fInfLocation, fSurvLocation, fVector);
			if (GetVectorLength(fVector) < g_maxRange) return false;
		}
	}
	return true;
}

bool Close(int client)
{
	float fInfLocation[3], fSurvLocation[3], fVector[3];
	GetClientAbsOrigin(client, fInfLocation);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i)==2 && IsPlayerAlive(i))
		{
			GetClientAbsOrigin(i, fSurvLocation);
			MakeVectorFromPoints(fInfLocation, fSurvLocation, fVector);
			if (GetVectorLength(fVector) < g_minRange) return true;
		}
	}
	return false;
}

bool TeleOne2One(int client1, int client2)
{
	if(!g_bBoomer2Tank && GetInfectedClass(client1) == L4DInfected_Boomer && GetInfectedClass(client2) == L4DInfected_Tank)return false;
	if(GetInfectedClass(client1) == L4DInfected_Smoker && GetInfectedClass(client2) == L4DInfected_Tank) return false;
	
	float fOwnerOrigin[3];
	GetEntPropVector(client2, Prop_Send, "m_vecOrigin", fOwnerOrigin);
	TeleportEntity(client1, fOwnerOrigin, NULL_VECTOR, NULL_VECTOR);
	g_fClientTeleTime[client1] = GetEngineTime() + g_fTeleCoolDownTime;
	CreateTimer(0.15, Timer_CheckIfStuck, client1);

	return true;
}

public Action Timer_CheckIfStuck(Handle timer, int client)
{
	if (IsClientInGame(client) && GetClientTeam(client) == 3)
	{
		L4D_WarpToValidPositionIfStuck(client);
	}

	return Plugin_Continue;
}

int GetInfectedClass(int client)
{
	return GetEntProp(client, Prop_Send, "m_zombieClass");
}

stock bool IsPlayerGhost(int client)
{
	return view_as<bool>(GetEntProp(client, Prop_Send, "m_isGhost"));
}

stock int L4D_GetSurvivorVictim(int client)
{
	int victim;
	
    /* Hunter */
	victim = GetEntPropEnt(client, Prop_Send, "m_pounceVictim");
	if (victim > 0)
	{
		return victim;
 	}

    /* Smoker */
 	victim = GetEntPropEnt(client, Prop_Send, "m_tongueVictim");
	if (victim > 0)
	{
		return victim;	
	}

	return -1;
}

bool CanBeSeenBySurvivors(int infected)
{
	if(GetEntProp(infected, Prop_Send, "m_hasVisibleThreats")) return true;

	float vClientEyePos[3];
	GetClientEyePosition(infected, vClientEyePos);
	for (int client = 1; client <= MaxClients; ++client)
	{
		if (IsAliveSurvivor(client) && IsVisibleToPlayer(vClientEyePos, client))
		{
			return true;
		}
	}

	return false;
}

bool IsAliveSurvivor(int client)
{
    return IsClientInGame(client)
        && GetClientTeam(client) == 2
        && IsPlayerAlive(client);
}

float  g_fVPlayerMins[3] = {-16.0, -16.0,  0.0};
float  g_fVPlayerMaxs[3] = { 16.0,  16.0, 71.0};
bool IsVisibleToPlayer(float vClientEyePos[3], int target)
{
    float vTargetPos[3];
    float vLookAt[3];
    float vAng[3];

    GetClientEyePosition(target, vTargetPos);
    MakeVectorFromPoints(vClientEyePos, vTargetPos, vLookAt);
    GetVectorAngles(vLookAt, vAng);

    Handle trace = TR_TraceRayFilterEx(vClientEyePos, vAng, MASK_VISIBLE, RayType_Infinite, TraceFilter_VisibleToPlayer, target);

    bool isVisible;

    if (TR_DidHit(trace))
    {
        isVisible = (TR_GetEntityIndex(trace) == target);

        if (!isVisible)
        {
            vTargetPos[2] -= 62.0; // results the same as GetClientAbsOrigin

            delete trace;
            trace = TR_TraceHullFilterEx(vClientEyePos, vTargetPos, g_fVPlayerMins, g_fVPlayerMaxs, MASK_VISIBLE, TraceFilter_VisibleToPlayer, target);

            if (TR_DidHit(trace))
                isVisible = (TR_GetEntityIndex(trace) == target);
        }
    }

    delete trace;

    return isVisible;
}

bool TraceFilter_VisibleToPlayer(int entity, int contentsMask, int player)
{
    if (entity == player)
        return true;

    if (IsValidClientIndex(entity))
        return false;

    if (!IsValidEntityIndex(entity) )
        return false;

    return ge_bInvalidTrace[entity] ? false : true;
}

bool IsValidClientIndex(int client)
{
    return (1 <= client <= MaxClients);
}

bool IsValidEntityIndex(int entity)
{
	return (MaxClients + 1 <= entity <= GetMaxEntities());
}