#define PLUGIN_VERSION "1.0"

#pragma semicolon 1
#include <sourcemod>

#define debug 0

public Plugin:myinfo =
{
	name = "Health Expolit Fixes",
	author = "raziEiL [disawar1]",
	description = "Plugin fixes 3 health expolit caused when survivor hanging on a ledge and after it",
	version = PLUGIN_VERSION,
	url = "http://steamcommunity.com/id/raziEiL"
}

static 		Handle:g_hDecayRate, Float:g_fTempHp[MAXPLAYERS+1];

public OnPluginStart()
{
	CreateConVar("healthexpolit_fix_version", PLUGIN_VERSION, "Health Expolit Fixes plugin version", FCVAR_REPLICATED|FCVAR_NOTIFY);

	g_hDecayRate = FindConVar("pain_pills_decay_rate");

	HookEvent("player_ledge_grab", HE_PlayerLedgeGrab);
	HookEvent("revive_success", HE_ReviveSuccess);

	#if debug
		RegAdminCmd("sm_he", CmdHE, ADMFLAG_ROOT);
	#endif
}

#if debug
public Action:CmdHE(client, args)
{
	if (!args){

		ReplyToCommand(client, "g_fTempHp = %f", g_fTempHp[client]);
		return Plugin_Handled;
	}

	decl String:sCmdLine[64];
	GetCmdArg(1, sCmdLine, 64);

	g_fTempHp[client] = StringToFloat(sCmdLine);
	SetSurvivorTempHealth(client);

	ReplyToCommand(client, "input %f", g_fTempHp[client]);
	return Plugin_Handled;
}
#endif

public Action:HE_PlayerLedgeGrab(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if ((g_fTempHp[client] = GetSuvivorTempHealth(client)))
		SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0);

	#if debug
		PrintToChatAll("save %f over heal", g_fTempHp[client]);
	#endif
}

public Action:HE_ReviveSuccess(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!GetEventBool(event, "ledge_hang")) return;
	
	new client = GetClientOfUserId(GetEventInt(event, "subject"));
	if(GetEventBool(event, "lastlife"))
	{
	}
	if (g_fTempHp[client])
		CreateTimer(0.0, HE_t_PreRestoreHealth, client);
	else if (GetClientHealth(client) < 30)
		SetSurvivorTempHealth(client);
}

public Action:HE_t_PreRestoreHealth(Handle:timer, any:client)
{
	SetSurvivorTempHealth(client);
}

Float:GetSuvivorTempHealth(client)
{
	new Float:fHealth = GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
	fHealth -= (GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * GetConVarFloat(g_hDecayRate);
	return fHealth < 0.0 ? 0.0 : fHealth;
}

SetSurvivorTempHealth(client)
{
	SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", g_fTempHp[client]);

	#if debug
		PrintToChatAll("%f restore", g_fTempHp[client]);
	#endif
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	if (!IsDedicatedServer()) 
		return APLRes_Failure;

	decl String:sBuffer[64];
	GetGameFolderName(sBuffer, 64);

	if (strcmp(sBuffer, "left4dead") == 0)
		return APLRes_Success;

	Format(sBuffer, 64, "Plugin not support \"%s\" game", sBuffer);
	strcopy(error, err_max, sBuffer);
	return APLRes_Failure;
}