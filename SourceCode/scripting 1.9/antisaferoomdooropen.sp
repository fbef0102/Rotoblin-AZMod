#pragma semicolon 1
#pragma newdecls required //強制1.7以後的新語法
#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#define DEBUG 0

#define L4D_TEAM_INFECTED  3
#define L4D_TEAM_SURVIVOR  2
#define L4D_TEAM_SPECTATOR 1
#define SAFEDOOR_MODEL_EXIT_01 "models/props_doors/checkpoint_door_01.mdl"
#define SAFEDOOR_MODEL_EXIT_02 "models/props_doors/checkpoint_door_-01.mdl"
#define SAFEDOOR_CLASS "prop_door_rotating_checkpoint"
#define SOUND_LOCK			"doors/default_locked.wav" // door_lock_1

//convar
ConVar g_hCvarAllow;
ConVar g_hForceStarTime;
ConVar g_hAntiOpenTime;
ConVar g_hFadeFakeDoor;
bool g_bEnable,bCvarAllow;
ConVar g_hSafeAreaLeftTime;
int g_iForceStarTime;
int g_iAntiOpenTime;
bool g_bFadeFakeDoor;
int g_iSafeAreaLeftTime;

//value
int iDoorForceOpenTime;
int iDoorLockTime;
int iSafeAreaLeftTime;
int ent_safedoor; //起始安全門的物件
bool bSafeRoomDoorLock; //起始安全門鎖住
bool bLeftSafeAreaLock; //起始安全區域不讓離開
float g_fLastUse[MAXPLAYERS+1];
int g_iRoundStart,g_iPlayerSpawn ;

public Plugin myinfo = 
{
	name = "start saferoom door anti open by noobs in l4d1",
	author = "Harry Potter",
	description = "as the name says, you dumb fuck",
	version = "1.0",
	url = "https://steamcommunity.com/id/fbef0102/"
}

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

public void OnPluginStart()
{
	LoadTranslations("Roto2-AZ_mod.phrases");
	
	g_hCvarAllow = CreateConVar(	"l4d_anti_saferoom_door_enable", "1",
								"Enable anti saferoom door close  plugin. [0-Disable,1-Enable]",
								FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	g_hForceStarTime = CreateConVar("l4d_coop_force_start_time", "60",
								"saferoom door auto open after this amount of time, even if survivors are still inside the safe room.",
								FCVAR_NOTIFY, true, 1.0 );			
	g_hAntiOpenTime = CreateConVar("l4d_anti_saferoom_door_open", "25", 
								"saferoom door anti open by survivor after this amount of time",
								FCVAR_NOTIFY, true, 1.0);
	g_hFadeFakeDoor = CreateConVar("l4d_anti_saferoom_door_fade", "0", 
								"Enable anti saferoom door fade after open drop. [0-Disable,1-Enable]",
								FCVAR_NOTIFY, true, 0.0, true, 1.0 );				
	g_hSafeAreaLeftTime = CreateConVar("l4d_anti_left_start_area_time", "25", 
								"Allow player to leave safe area after this amount of time",
								FCVAR_NOTIFY, true, 1.0);	

	g_hCvarAllow.AddChangeHook(ConVarChanged_Allowed);
	g_hForceStarTime.AddChangeHook(ConVarChanged_Cvars);
	g_hAntiOpenTime.AddChangeHook(ConVarChanged_Cvars);
	g_hFadeFakeDoor.AddChangeHook(ConVarChanged_Cvars);
	g_hSafeAreaLeftTime.AddChangeHook(ConVarChanged_Cvars);

	IsAllowed();
	
	AutoExecConfig(true,				"antisaferoomdooropen");
}
	
public void OnPluginEnd()
{
	ClearDefault();
}

public void OnConfigsExecuted()
{
	IsAllowed();
}

public void OnMapEnd()
{
	ClearDefault();
}

public void ConVarChanged_Cvars(Handle convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

public void ConVarChanged_Allowed(Handle convar, const char[] oldValue, const char[] newValue)
{
	IsAllowed();
}

void IsAllowed()
{
	GetCvars();
	bCvarAllow = g_hCvarAllow.BoolValue;
	if( g_bEnable == false && bCvarAllow == true ) 
	{
		g_bEnable = true;
		
		HookEvents();
		SetDefault();
	}
	else if( g_bEnable == true && bCvarAllow == false )
	{
		g_bEnable = false;
		
		UnHookEvents();
		ClearDefault();
	}
}

void HookEvents()
{
	HookEvent("round_start", 		Event_RoundStart);
	HookEvent("door_open", Event_DoorOpen);
	HookEvent("round_end",			Event_RoundEnd,		EventHookMode_PostNoCopy);
	HookEvent("player_spawn",		Event_PlayerSpawn,	EventHookMode_PostNoCopy);
	HookEvent("player_left_checkpoint", Event_player_left_checkpoint, EventHookMode_Pre);
}

void UnHookEvents()
{
	UnhookEvent("round_start", 		Event_RoundStart);
	UnhookEvent("door_open", Event_DoorOpen);
	UnhookEvent("round_end",			Event_RoundEnd,		EventHookMode_PostNoCopy);
	UnhookEvent("player_spawn",		Event_PlayerSpawn,	EventHookMode_PostNoCopy);
	UnhookEvent("player_left_checkpoint", Event_player_left_checkpoint, EventHookMode_Pre);
}

void GetCvars()
{
	g_iAntiOpenTime = g_hAntiOpenTime.IntValue;
	g_iForceStarTime = g_hForceStarTime.IntValue;
	g_bFadeFakeDoor  = g_hFadeFakeDoor.BoolValue;
	g_iSafeAreaLeftTime = g_hSafeAreaLeftTime.IntValue;
}

void SetDefault()
{
	ent_safedoor = -1;
	iDoorLockTime = g_iAntiOpenTime;
	iDoorForceOpenTime = g_iForceStarTime;
	iSafeAreaLeftTime = g_iSafeAreaLeftTime;
	ent_safedoor = -1;
	bSafeRoomDoorLock = false;
	bLeftSafeAreaLock = false;
	for( int i = 0; i <= MaxClients; i++ )
	{
		g_fLastUse[i] = 0.0;
	}
}

void ClearDefault()
{
	if(ent_safedoor > 0 && IsValidEntity(ent_safedoor)) DispatchKeyValue(ent_safedoor, "spawnflags", "8192");
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
}


public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	ClearDefault();
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	SetDefault();

	if( g_iPlayerSpawn == 1 && g_iRoundStart == 0 )
		CreateTimer(0.5, PluginStart);
	g_iRoundStart = 1;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if( g_iPlayerSpawn == 0 && g_iRoundStart == 1 )
		CreateTimer(0.5, PluginStart);
	g_iPlayerSpawn = 1;
}


public Action PluginStart(Handle timer)
{
	SetDefault();
	InitDoorAndArea();
	CreateTimer(1.0, DoorLockCountDown,_,TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(1.0, LeftAreaUnLock,_, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action Event_DoorOpen(Event event, const char[] name, bool dontBroadcast) 
{
	if (!bSafeRoomDoorLock && ent_safedoor > 0)
	{
		if (GetEventBool(event, "checkpoint"))
		{
			int client = GetClientOfUserId(GetEventInt(event, "userid"));
			
			ReplaceFakeSafeDoor(client);
		}
		
	}
}

public Action Event_player_left_checkpoint(Event event, const char[] name, bool dontBroadcast) 
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(client&&IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == L4D_TEAM_SURVIVOR)
	{
		if (bLeftSafeAreaLock)
		{
			ReturnToSaferoom(client);
			PrintHintText(client,"%T","antisaferoomdooropen2",client,iSafeAreaLeftTime);
			PlaySound(client);
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if( g_bEnable && bSafeRoomDoorLock && IsClientAndInGame(client) && GetClientTeam(client) == L4D_TEAM_SURVIVOR && buttons & IN_USE && GetGameTime() > g_fLastUse[client])
	{
		int entity = GetClientAimTarget(client, false);
		if( entity == ent_safedoor )
		{
			g_fLastUse[client] = GetGameTime() + 1.0; // Avoid spamming resources
			PrintHintText(client,"%T","antisaferoomdooropen1",client,iDoorLockTime);
			PlaySound(entity);
		}
	}
	return Plugin_Continue;
}

void InitDoorAndArea()
{
	ent_safedoor = GetSafeRoomDoor();
	if(ent_safedoor > 0)
	{
		#if DEBUG
			LogMessage("%d door lock",ent_safedoor);
		#endif
		bSafeRoomDoorLock = true;
	}

	bLeftSafeAreaLock = true;
}

public Action DoorLockCountDown(Handle timer)
{
	if(!g_bEnable || (iDoorLockTime<=0 && iDoorForceOpenTime<=0) || ent_safedoor == -1 || !IsValidEntity(ent_safedoor))
		return Plugin_Stop;
		
	iDoorLockTime--;
	iDoorForceOpenTime--;
	if(iDoorLockTime<=0)
	{
		bSafeRoomDoorLock = false;
		DispatchKeyValue(ent_safedoor, "spawnflags", "8192");
	}
	if(iDoorForceOpenTime<=0)
	{
		bSafeRoomDoorLock = false;
		ReplaceFakeSafeDoor();
	}
		
	return Plugin_Continue;
}

public Action LeftAreaUnLock(Handle timer)
{
	iSafeAreaLeftTime--;
	if(iSafeAreaLeftTime<=0)
	{
		bLeftSafeAreaLock = false;
	}
		
	return Plugin_Continue;
}

int GetSafeRoomDoor()
{
	int ent_safedoor_check = -1;
	while ((ent_safedoor_check = FindEntityByClassname(ent_safedoor_check, SAFEDOOR_CLASS)) != -1)
	{
		int spawn_flags;
		char model[255];
		GetEntPropString(ent_safedoor_check, Prop_Data, "m_ModelName", model, sizeof(model));
		spawn_flags = GetEntProp(ent_safedoor_check, Prop_Data, "m_spawnflags");

		#if DEBUG
			LogMessage("entity: %d, Model: %s, spawn_flags: %d",ent_safedoor_check,model,spawn_flags);
		#endif
		if (((strcmp(model, SAFEDOOR_MODEL_EXIT_01) == 0) && ((spawn_flags == 8192) || (spawn_flags == 0))) || ((strcmp(model, SAFEDOOR_MODEL_EXIT_02) == 0) && ((spawn_flags == 8192) || (spawn_flags == 0))))
		{
			DispatchKeyValue(ent_safedoor_check, "spawnflags", "40960");
			return ent_safedoor_check;
		}
	}
	return -1;
}

stock bool IsClientAndInGame(int client)
{
	if (0 < client && client < MaxClients)
	{	
		return IsClientInGame(client);
	}
	return false;
}

void PlaySound(int entity)
{
	EmitSoundToAll(SOUND_LOCK, entity, SNDCHAN_AUTO, SNDLEVEL_AIRCRAFT, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
}


void ReplaceFakeSafeDoor(int client = 0)
{
	int ent_brokendoor = CreateEntityByName("prop_physics");
	char model[255];
	GetEntPropString(ent_safedoor, Prop_Data, "m_ModelName", model, sizeof(model));
	
	float pos[3],ang[3];
	GetEntPropVector(ent_safedoor, Prop_Send, "m_vecOrigin", pos);
	GetEntPropVector(ent_safedoor, Prop_Send, "m_angRotation", ang);

	AcceptEntityInput(ent_safedoor, "Kill");
	
	ent_safedoor = -1;
	
	DispatchKeyValue(ent_brokendoor, "model", model);
	DispatchKeyValue(ent_brokendoor, "spawnflags", "4");

	DispatchSpawn(ent_brokendoor);
	
	float EyeAngles[3];
	float Push[3];
	float ang_fix[3];
			
	ang_fix[0] = (ang[0] - 5.0);
	ang_fix[1] = (ang[1] + 5.0);
	ang_fix[2] = (ang[2]);
	
	if(client)
	{
		GetClientEyeAngles(client, EyeAngles);
		Push[0] = (100.0 * Cosine(DegToRad(EyeAngles[1])));
		Push[1] = (100.0 * Sine(DegToRad(EyeAngles[1])));
		Push[2] = (15.0 * Sine(DegToRad(EyeAngles[0])));
	}

	TeleportEntity(ent_brokendoor, pos, ang_fix, Push);
	if(g_bFadeFakeDoor) CreateTimer(7.0, FadeBrokenDoor, ent_brokendoor,TIMER_FLAG_NO_MAPCHANGE);
}

public Action FadeBrokenDoor(Handle timer, int ent_brokendoor)
{
	if (IsValidEntity(ent_brokendoor))
	{
		SetEntityRenderFx(ent_brokendoor, RENDERFX_FADE_FAST); //RENDERFX_FADE_SLOW 3.5
		CreateTimer(1.5, KillBrokenDoorEntity, ent_brokendoor,TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action KillBrokenDoorEntity(Handle timer, int ent_brokendoor)
{
	if (IsValidEntity(ent_brokendoor))
	{
		AcceptEntityInput(ent_brokendoor, "Kill");
	}
}

void ReturnToSaferoom(int client)
{
	int warp_flags = GetCommandFlags("warp_to_start_area");
	SetCommandFlags("warp_to_start_area", warp_flags & ~FCVAR_CHEAT);
	int give_flags = GetCommandFlags("give");
	SetCommandFlags("give", give_flags & ~FCVAR_CHEAT);
	if (IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client))
	{
		ReturnPlayerToSaferoom(client);
	}
	SetCommandFlags("warp_to_start_area", warp_flags);
	SetCommandFlags("give", give_flags);
}

void ReturnPlayerToSaferoom(int client,bool flagsSet = true)
{
	int warp_flags;
	int give_flags;
	if (!flagsSet)
	{
		warp_flags = GetCommandFlags("warp_to_start_area");
		SetCommandFlags("warp_to_start_area", warp_flags & ~FCVAR_CHEAT);
		give_flags = GetCommandFlags("give");
		SetCommandFlags("give", give_flags & ~FCVAR_CHEAT);
	}
	
	FakeClientCommand(client, "warp_to_start_area");

	if (!flagsSet)
	{
		SetCommandFlags("warp_to_start_area", warp_flags);
		SetCommandFlags("give", give_flags);
	}
}