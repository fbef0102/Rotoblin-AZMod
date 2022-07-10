#define PLUGIN_VERSION "1.2"

#include <sourcemod>


#define ADD_BOT		"sb_add"
#define DELAY_BOT_CLIENT_Check		1.0

public Plugin:myinfo =
{
	name = "Spec Kick Bots Fix",
	author = "raziEiL [disawar1],modify by Harry",
	description = "Fixed no Survivor bots issue. Fix more Survivor bots issue.",
	version = PLUGIN_VERSION,
	url = "http://steamcommunity.com/id/raziEiL"
}

static	Handle:g_hSurvivorLimit, g_iCvarSurvLimit;
static bool:bTempBlock;

public OnPluginStart()
{
	g_hSurvivorLimit = FindConVar("survivor_limit");

	HookConVarChange(g_hSurvivorLimit, OnCvarChange_SurvivorLimit);
	g_iCvarSurvLimit = GetConVarInt(g_hSurvivorLimit);

	HookEvent("player_team", SF_ev_PlayerTeam);
	HookEvent("round_start", event_RoundStart, EventHookMode_PostNoCopy);//每回合開始就發生的event
	
	RegAdminCmd("sm_botfix", CmdBotFix, ADMFLAG_ROOT);
}

public Action:CmdBotFix(client, args)
{
	SF_Fix();
	ReplyToCommand(client, "Checking complete.");
	return Plugin_Handled;
}

public event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	for (new i = 1; i <= MaxClients; i++)
		if(IsClientConnected(i)&&IsClientInGame(i)&&!IsFakeClient(i))
		{
			CreateTimer(DELAY_BOT_CLIENT_Check, SF_t_CheckBots);
			break;
		}
}


public OnMapStart()
{
	bTempBlock = false;
}


public Action:SF_ev_PlayerTeam(Handle:event, String:event_name[], bool:dontBroadcast)
{
	if (bTempBlock) return;

	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (client && !IsFakeClient(client)){

		if (!GetEventBool(event, "disconnect") && GetEventInt(event, "team") == 1){

			bTempBlock = true;
			CreateTimer(1.0, SF_t_CheckBots);
		}
	}
}


public Action:SF_t_CheckBots(Handle:timer)
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if( IsClientInGame(i) &&!IsFakeClient(i))
		{
			SF_Fix();
			break;
		}
	}
}

SF_Fix()
{
	new iSurvivorCount;
	new bool:SurFakeClient; 

	for (new i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && GetClientTeam(i) == 2)
			iSurvivorCount++;
	if(iSurvivorCount == g_iCvarSurvLimit)
		return;
		
	if (iSurvivorCount < g_iCvarSurvLimit){

		static iFlag;

		if (!iFlag)
			iFlag = GetCommandFlags(ADD_BOT);

		SetCommandFlags(ADD_BOT, iFlag & ~FCVAR_CHEAT)

		while (iSurvivorCount != g_iCvarSurvLimit){
			LogMessage("Bug detected. Trying to add a bot %d/%d", iSurvivorCount, g_iCvarSurvLimit);
			ServerCommand(ADD_BOT);
			iSurvivorCount++;
		}

		SetCommandFlags(ADD_BOT, iFlag);
	}
	
	if (iSurvivorCount > g_iCvarSurvLimit){
		while (iSurvivorCount != g_iCvarSurvLimit){
			LogMessage("Bug detected. Trying to kick a bot %d/%d", iSurvivorCount, g_iCvarSurvLimit);
			SurFakeClient = false;
			for (new i = 1; i <= MaxClients; i++)
				if(IsClientInGame(i) && GetClientTeam(i) == 2 && IsFakeClient(i))
				{
					KickClient(i, "client_is_1vHunters_fakeclient");
					iSurvivorCount--;
					SurFakeClient = true;
					break;
				}
			if(!SurFakeClient)
				for (new i = 1; i <= MaxClients; i++)
					if (IsClientInGame(i) && GetClientTeam(i) == 2 && !IsFakeClient(i))
					{
						ChangeClientTeam(i, 3);
						break;
					}
		}
		CreateTimer(DELAY_BOT_CLIENT_Check, SF_t_CheckBots);
	}
}

public OnCvarChange_SurvivorLimit(Handle:hHandle, const String:sOldVal[], const String:sNewVal[])
{
	if (!StrEqual(sOldVal, sNewVal))
		g_iCvarSurvLimit = StringToInt(sNewVal);
}