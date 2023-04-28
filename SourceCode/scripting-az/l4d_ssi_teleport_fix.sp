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
ConVar g_hTeleVisibleThreats;

bool GodTime[MAXPLAYERS + 1] = {false};
bool g_bRoundAlive;
bool g_bBoomer2Tank;
bool g_bTeleVisibleThreats;
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
	g_hTeleVisibleThreats= CreateConVar("ssitp_tp2_visiblethreats",	"0",	"If 1, infected players can be teleported to the player thats about to be seen by the survivors.", FCVAR_NOTIFY, true, 0.0, true, 1.0);

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
	g_hTeleVisibleThreats.AddChangeHook(ConVarChanged_Cvars);
}

public void ConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
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
	g_bTeleVisibleThreats = g_hTeleVisibleThreats.BoolValue;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!client || !IsClientInGame(client)) return;
	g_fClientTeleTime[client] = 0.0;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_bRoundAlive = false;

	for(int i = 1; i<=MaxClients; i++)
	{
		g_fClientTeleTime[i] = 0.0;
	}
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	g_bRoundAlive = false;
}

public void LeftStartAreaEvent(Event event, const char[] name, bool dontBroadcast)
{
	g_bRoundAlive 		= true;
	CreateTimer(g_fCheckinterval,Timer_CheckNoobSi, _, TIMER_REPEAT);
}	

public Action Timer_CheckNoobSi(Handle timer)
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

public Action Timer_RemoveGod(Handle timer, any client)
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

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if(IsClientInGame(victim) && IsFakeClient(victim) && GodTime[victim])
	{
		damage = 0.0;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

/**********************************************************
stocks
**********************************************************/

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
	if (CanBeSeenBySurvivors(client)) return false;
	return true;
}

bool CanTP2(int client) //傳送目的地的玩家
{
	if(!IsClientInGame(client)) return false;
	if(GetClientTeam(client) != 3 || !IsPlayerAlive(client)) return false;
	if(IsPlayerGhost(client)) return false;
	//if(L4D_GetSurvivorVictim(client) != -1) return false; //正在控人類
	if(!g_bTeleVisibleThreats && CanBeSeenBySurvivors(client)) return false; //在人類視野範圍內
	
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

static bool IsVisibleTo(int player1, int player2)
{
	// check FOV first
	// if his origin is not within a 60 degree cone in front of us, no need to raytracing.
	float pos1_eye[3], pos2_eye[3], eye_angle[3], vec_diff[3], vec_forward[3];
	GetClientEyePosition(player1, pos1_eye);
	GetClientEyeAngles(player1, eye_angle);
	GetClientEyePosition(player2, pos2_eye);
	MakeVectorFromPoints(pos1_eye, pos2_eye, vec_diff);
	NormalizeVector(vec_diff, vec_diff);
	GetAngleVectors(eye_angle, vec_forward, NULL_VECTOR, NULL_VECTOR);
	if (GetVectorDotProduct(vec_forward, vec_diff) < 0.5) // cos 60
	{
		return false;
	}

	// in FOV
	Handle hTrace;
	bool ret = false;
	float pos2_feet[3], pos2_chest[3];
	GetClientAbsOrigin(player2, pos2_feet);
	pos2_chest[0] = pos2_feet[0];
	pos2_chest[1] = pos2_feet[1];
	pos2_chest[2] = pos2_feet[2] + 45.0;

	hTrace = TR_TraceRayFilterEx(pos1_eye, pos2_eye, MASK_VISIBLE, RayType_EndPoint, TraceFilter, player1);
	if (!TR_DidHit(hTrace) || TR_GetEntityIndex(hTrace) == player2)
	{
		CloseHandle(hTrace);
		return true;
	}
	CloseHandle(hTrace);

	hTrace = TR_TraceRayFilterEx(pos1_eye, pos2_feet, MASK_VISIBLE, RayType_EndPoint, TraceFilter, player1);
	if (!TR_DidHit(hTrace) || TR_GetEntityIndex(hTrace) == player2)
	{
		CloseHandle(hTrace);
		return true;
	}
	CloseHandle(hTrace);

	hTrace = TR_TraceRayFilterEx(pos1_eye, pos2_chest, MASK_VISIBLE, RayType_EndPoint, TraceFilter, player1);
	if (!TR_DidHit(hTrace) || TR_GetEntityIndex(hTrace) == player2)
	{
		CloseHandle(hTrace);
		return true;
	}
	CloseHandle(hTrace);

	return ret;
}

static bool TraceFilter(int entity, int mask, int self)
{
	return entity != self;
}

bool CanBeSeenBySurvivors(int infected)
{
	for (int client = 1; client <= MaxClients; ++client)
	{
		if (IsAliveSurvivor(client) && IsVisibleTo(client, infected))
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