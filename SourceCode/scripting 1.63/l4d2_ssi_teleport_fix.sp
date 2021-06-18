#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <l4d_lib>

#define  MIN(%0,%1) (((%0) < (%1)) ? (%0) : (%1))
#define L4DInfected_Smoker 1
#define L4DInfected_Boomer 2
#define L4DInfected_Hunter 3
#define L4DInfected_Tank   5

new Handle:g_hDiscardRange;
new Handle:g_hCheckinterval;
new Handle:g_hTeleRangeMax;
new Handle:g_hTeleRangeMin;
new Handle:g_hTeleLimit;
new Handle:g_hBoomer2Tank;
new Handle:g_hGodTime;

new bool:GodTime[MAXPLAYERS + 1] = false;
new bool:g_bRoundAlive;
new bool:g_bBoomer2Tank;
new Float:g_fGodTime;
new Float:g_fCheckinterval;

new g_minRange;
new g_maxRange;
new g_DiscardRange;
new g_iSsitpLimit;
new sitele2[3] = {-1, -1, -1};
new si2tele[6] = {-1, -1, -1, -1, -1, -1};

public Plugin:myinfo = 
{
	name = "Super SI Teleport.", 
	author = "AiMee,l4d1 port by Harry", 
	description = "emmm, noob ai", 
	version = "1.1", 
	url = ""
};

public OnPluginStart()
{
	g_hDiscardRange  	= CreateConVar("ssitp_discard_range", 	"800",	"Discard range");
	g_hTeleRangeMax 	= CreateConVar("ssitp_tp_range_max", 	"800", 	"teleport max range");
	g_hTeleRangeMin 	= CreateConVar("ssitp_tp_range_min", 	"180", 	"teleport min range");
	g_hCheckinterval 	= CreateConVar("ssitp_check_interval", 	"1.0",	"time to check noob si", FCVAR_SPONLY, true, 1.0);
	g_hTeleLimit		= CreateConVar("ssitp_tp_limit",   		"2", 	"Limit per teleport.", FCVAR_SPONLY, true, 1.0, true, 6.0);
	g_hBoomer2Tank 		= CreateConVar("ssitp_boomer2tank", 	"0", 	"Teleport boomer to tank?", FCVAR_SPONLY, true, 0.0, true, 1.0);
	g_hGodTime			= CreateConVar("ssitp_god_time",		"0.6",	"SI free of damage for this seconds", FCVAR_SPONLY, true, 0.0);
	
	HookEvent("round_start", 	Event_RoundStart, 	EventHookMode_PostNoCopy);
	HookEvent("round_end", 		Event_RoundEnd, 	EventHookMode_PostNoCopy);
	
	g_bRoundAlive 		= false;
	g_fCheckinterval 	= GetConVarFloat(g_hCheckinterval);
	g_iSsitpLimit		= GetConVarInt(g_hTeleLimit);
	g_bBoomer2Tank		= GetConVarBool(g_hBoomer2Tank);
	g_fGodTime			= GetConVarFloat(g_hGodTime);
	g_minRange 			= GetConVarInt(g_hTeleRangeMin);
	g_maxRange 			= GetConVarInt(g_hTeleRangeMax);
	g_DiscardRange		= GetConVarInt(g_hDiscardRange);
}

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_bRoundAlive = false;
}
public Action:Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_bRoundAlive = false;
}
public Action:L4D_OnFirstSurvivorLeftSafeArea(client) 
{
	g_bRoundAlive 		= true;
	g_fCheckinterval	= GetConVarFloat(g_hCheckinterval);
	g_iSsitpLimit		= GetConVarInt(g_hTeleLimit);
	g_bBoomer2Tank 		= GetConVarBool(g_hBoomer2Tank);
	g_fGodTime			= GetConVarFloat(g_hGodTime);
	g_minRange 			= GetConVarInt(g_hTeleRangeMin);
	g_maxRange 			= GetConVarInt(g_hTeleRangeMax);
	g_DiscardRange		= GetConVarInt(g_hDiscardRange);
	CreateTimer(g_fCheckinterval,Timer_CheckNoobSi, _, TIMER_REPEAT);
}	

public Action:Timer_CheckNoobSi(Handle:timer)
{
	new index1 = FindSItele2();
	new index2 = FindSI2Tele();
	if(index1 != 0 && index2 != 0)
	{
		index2 = MIN(index2, index1*g_iSsitpLimit);
		for(new i=0; i<index2; i++)
		{	
			if(TeleOne2One(si2tele[i],sitele2[i%index1]) && g_fGodTime > 0)
			{
				SetInGodTime(si2tele[i]);
				CreateTimer(g_fGodTime, Timer_RemoveGod, si2tele[i], TIMER_FLAG_NO_MAPCHANGE);
			}
		}
	}
	
	if(!g_bRoundAlive)
		return Plugin_Stop;
	return Plugin_Continue;
}

public Action:Timer_RemoveGod(Handle:timer, any:client)
{
	GodTime[client] = false;
	ResetGlow(client);
}

public OnClientPostAdminCheck(client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}
public OnClientDisconnect(client)
{
    SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
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

SetInGodTime(client)
{
	GodTime[client] = true;
	SetGodTimeGlow(client);
}

SetGodTimeGlow(client) 
{
	if (IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == 3) {
		SetEntityRenderMode( client, RenderMode:3 );
		SetEntityRenderColor (client, 255,255,255,150 );
	}
}
ResetGlow(client) 
{
	if (IsClientInGame(client)) {
		SetEntityRenderMode(client, RenderMode:0);
		SetEntityRenderColor(client, 255,255,255,255);
	}
}

bool: CanBeTP(client)
{
	if (!IsClientInGame(client) || !IsFakeClient(client))return false;
	if (GetClientTeam(client) != 3 || !IsPlayerAlive(client))return false;
	if (GetInfectedClass(client) ==  L4DInfected_Tank )return false;
	return true;
}

bool: CanTP2(client)
{
	if(!IsClientInGame(client))return false;
	if(GetClientTeam(client) != 3 || !IsPlayerAlive(client))return false;
	if(IsPlayerGhost(client))return false;
	
	return true;
}

stock FindSItele2()
{
	new index = 0;
	for(new i = 1; i<=MaxClients; i++)
	{
		if( index < 3 && CanTP2(i) && !Far(i) && !Close(i))
			sitele2[index++] = i;
	}
	return index;
}

stock FindSI2Tele()
{
	new index = 0;
	for(new i = 1; i<=MaxClients; i++)
	{
		if(index < 6 && CanBeTP(i) && TooFar(i))
			si2tele[index++] = i;
	}
	return index;
}

bool:TooFar(client)
{
	decl Float:fInfLocation[3], Float:fSurvLocation[3], Float:fVector[3];
	GetClientAbsOrigin(client, fInfLocation);
	
	for (new i = 1; i <= MaxClients; i++)
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

bool:Far(client)
{
	decl Float:fInfLocation[3], Float:fSurvLocation[3], Float:fVector[3];
	GetClientAbsOrigin(client, fInfLocation);
	
	for (new i = 1; i <= MaxClients; i++)
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

bool:Close(client)
{
	decl Float:fInfLocation[3], Float:fSurvLocation[3], Float:fVector[3];
	GetClientAbsOrigin(client, fInfLocation);
	
	for (new i = 1; i <= MaxClients; i++)
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

bool: TeleOne2One(client1, client2)
{
	if(!g_bBoomer2Tank && GetInfectedClass(client1) == L4DInfected_Boomer && GetInfectedClass(client2) == L4DInfected_Tank)return false;
	if(GetInfectedClass(client1) == L4DInfected_Smoker && GetInfectedClass(client2) == L4DInfected_Tank)return false;
	
	decl Float:fOwnerOrigin[3];
	GetEntPropVector(client2, Prop_Send, "m_vecOrigin", fOwnerOrigin);
	TeleportEntity(client1, fOwnerOrigin, NULL_VECTOR, NULL_VECTOR);
	//PrintToServer("[ssitp]Teleport %N to %N", client1, client2);
	return true;
}

GetInfectedClass(client)
{
	return GetEntProp(client, Prop_Send, "m_zombieClass");
}