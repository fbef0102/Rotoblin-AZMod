#pragma semicolon 1
#pragma newdecls required //強制1.7以後的新語法
#define TIMER_START 30.0

#include <sourcemod>
ConVar hGlow = null;
ConVar hHideHud = null;
ConVar sv_glowenable = null;
int iHideHudFlags;
bool bGlow;
int g_iRoundStart, g_iPlayerSpawn;

public Plugin myinfo =
{
	name = "L4D1/2 Real Realism Mode",
	author = "JNC & HarryPotter",
	description = "ayyy lmao",
	version = "1.1",
	url = ""
};

bool g_bLateLoad;
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    g_bLateLoad = late;
    return APLRes_Success;
}

public void OnPluginStart()
{
	// Trick
	sv_glowenable = CreateConVar("sv_glowenable", "1", "Turns on and off the terror glow highlight effects (Hidden Value Cvar)", FCVAR_REPLICATED, true, 0.0, true,1.0);
	hGlow = CreateConVar("l4d_survivor_glowenable", "1", "If 1, Enable Server Glows for survivor team.", FCVAR_NOTIFY,true,0.0,true,1.0);
	hHideHud = CreateConVar("l4d_survivor_hidehud", "0", "HUD hidden flag for survivor team. (1=weapon selection, 2=flashlight, 4=all, 8=health, 16=player dead, 32=needssuit, 64=misc, 128=chat, 256=crosshair, 512=vehicle crosshair, 1024=in vehicle)", FCVAR_NOTIFY,true,0.0);
	
	// Optional
	RegAdminCmd( "sm_glowoff", Command_GlowOff, ADMFLAG_BAN, "Hide one client glow");
	RegAdminCmd( "sm_glowon", Command_GlowOn, ADMFLAG_BAN, "Show one client glow");
	RegAdminCmd( "sm_hidehud", Command_HideHud, ADMFLAG_BAN, "Hide your hud flag");
	RegAdminCmd( "sm_hud", Command_HideHud, ADMFLAG_BAN, "Hide your hud flag");

	GetCvars();
	hGlow.AddChangeHook(ConVarChange_GlowCvar);
	hHideHud.AddChangeHook(ConVarChange_HudCvar);
	
	HookEvent("player_death", evtPlayerDeath, EventHookMode_Pre);
	HookEvent("player_team", evtPlayerTeam);
	HookEvent("player_spawn", evtPlayerSpawn);
	HookEvent("round_start", evtRoundStart);
	HookEvent("round_end", evtRoundEnd);

	//AutoExecConfig(true, "l4d_expertrealism");
	
	if( g_bLateLoad )
	{
		for( int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
			{
				SetHideHudClient(i, iHideHudFlags);
				SetGlowClient(i, bGlow);
			}
		}
	}
}

public void OnMapEnd()
{
	g_iRoundStart = g_iPlayerSpawn = 0;
}

public void ConVarChange_HudCvar(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
			SetHideHudClient(i, iHideHudFlags);
	}
}

public void ConVarChange_GlowCvar(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
			SetGlowClient(i, bGlow);
	}
}

void GetCvars()
{
	bGlow = hGlow.BoolValue;
	iHideHudFlags = hHideHud.IntValue;
}

public Action Command_GlowOff(int client, int args)
{
	if (args < 1) {
		ReplyToCommand(client, "[SM] Usage: !glowoff <name/#userid>");
		return Plugin_Handled;
	}
	
	char arg[32];
	GetCmdArg(1, arg, sizeof(arg));
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	
	if ((target_count = ProcessTargetString(
			arg,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_CONNECTED,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	for (int i = 0; i < target_count; i++)
	{
		int victim = target_list[i];
		if (!IsFakeClient(victim))
		{
			SetGlowClient(victim, false);
			PrintToChat(client, "You set %N glow off", victim);
		}
	}
	
	return Plugin_Handled;
}

public Action Command_GlowOn(int client, int args)
{
	if (args < 1) {
		ReplyToCommand(client, "[SM] Usage: !glowon <name/#userid>");
		return Plugin_Handled;
	}
	
	char arg[32];
	GetCmdArg(1, arg, sizeof(arg));
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count; 
	bool tn_is_ml;
	
	if ((target_count = ProcessTargetString(
			arg,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_CONNECTED,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	for (int i = 0; i < target_count; i++)
	{
		int victim = target_list[i];
		if (!IsFakeClient(victim))
		{
			SetGlowClient(victim, true);
			PrintToChat(client, "You set %N glow on", victim);
		}
	}
	
	return Plugin_Handled;
}

public Action Command_HideHud(int client, int args)
{
	if (client == 0) {
		ReplyToCommand(client, "[SM] Can't be used by Server");
		return Plugin_Handled;
	}
	
	char arg[32];
	GetCmdArg(1, arg, sizeof(arg));
	
	int iFlag = StringToInt(arg);
	SetHideHudClient(client, iFlag);
	
	return Plugin_Handled;
}

public Action evtRoundStart(Event event, const char[] name, bool dontBroadcast) 
{
	if( g_iPlayerSpawn == 1 && g_iRoundStart == 0 )
		CreateTimer(TIMER_START, TimerStart, _, TIMER_FLAG_NO_MAPCHANGE);
	g_iRoundStart = 1;
}

public Action evtRoundEnd (Event event, const char[] name, bool dontBroadcast) 
{
	g_iRoundStart = g_iPlayerSpawn = 0;
}

public void evtPlayerSpawn(Event event, const char[] name, bool dontBroadcast) 
{
	if( g_iPlayerSpawn == 0 && g_iRoundStart == 1 )
		CreateTimer(TIMER_START, TimerStart, _, TIMER_FLAG_NO_MAPCHANGE);
	g_iPlayerSpawn = 1;

	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) != 2) return;
	
	SetHideHudClient(client, iHideHudFlags);
	SetGlowClient(client, bGlow);
}

public Action TimerStart(Handle timer)
{
	//PrintToChatAll("TimerStart");
	g_iRoundStart = g_iPlayerSpawn = 0;

	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
		{
			SetHideHudClient(i, iHideHudFlags);
			SetGlowClient(i, bGlow);
		}
	}
}
public void evtPlayerTeam(Event event, const char[] name, bool dontBroadcast) 
{
	CreateTimer(1.0, PlayerChangeTeamCheck, event.GetInt("userid"));//延遲一秒檢查	
}

public Action PlayerChangeTeamCheck(Handle timer,int userid)
{
	int client = GetClientOfUserId(userid);
	if (!client || !IsClientInGame(client) || IsFakeClient(client)) return;
	
	if(GetClientTeam(client) == 2 && IsPlayerAlive(client))
	{
		SetHideHudClient(client, iHideHudFlags);
		SetGlowClient(client, bGlow);
	}
	else
	{
		SetHideHudClient(client, 0);
		SetGlowClient(client, true);	
	}
}

public void	evtPlayerDeath(Event event, const char[] name, bool dontBroadcast) 
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client) || IsFakeClient(client)) return;
	
	SetHideHudClient(client, 0);
	SetGlowClient(client, true);	
}

// Manual Trick, no matter if you server is on sv_glowenable 1 or 0, the client will have a different value, but you already know that
void SetGlowClient(int client, bool enable)
{
	if (enable)
		SendConVarValue(client, sv_glowenable, "1");
	else
		SendConVarValue(client, sv_glowenable, "0");
}

void SetHideHudClient(int client, int flag)
{
	SetEntProp(client, Prop_Send, "m_iHideHUD", flag);
}