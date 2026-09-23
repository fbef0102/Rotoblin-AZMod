#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>
#include <multicolors>

int lastHumanTankId;

public Plugin myinfo =
{
	name = "L4D2 Profitless Tank Pass",
	author = "Visor, Forgetest, l4d1 modify by Harry",
	description = "Passing control to AI Tank or another player will no longer be rewarded with an instant respawn",
	version = "0.4h-2026/9/23",
	url = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

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

	HookEvent("tank_frustrated", OnTankFrustrated, EventHookMode_Post);
	HookEvent("player_bot_replace", Event_BotReplacePlayer);
}

public void OnMapStart()
{
	lastHumanTankId = 0;
}

// lost tank control
void OnTankFrustrated(Event event, const char[] name, bool dontBroadcast)
{
	lastHumanTankId = event.GetInt("userid");
	RequestFrame(OnNextFrame_Reset);
	//PrintToChatAll("OnTankFrustrated %d, tick: %d", GetClientOfUserId(lastHumanTankId), GetGameTickCount());
}

// Check if AI replaces tank player
void Event_BotReplacePlayer(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("player");
	if(userid != lastHumanTankId) return;

	int bot = GetClientOfUserId(event.GetInt("bot"));
	int player = GetClientOfUserId(userid);
	if(bot > 0 && IsClientInGame(bot) && player > 0 && IsClientInGame(player)
		&& GetClientTeam(player) == 3)
	{
		static char lastHumanTank_Name[128];
		GetClientName(player, lastHumanTank_Name, 128);
		for (int j = 1; j <= MaxClients; j++)
			if (IsClientInGame(j) && IsClientConnected(j) && !IsFakeClient(j) && (GetClientTeam(j) == 1 || GetClientTeam(j) == 3))
				CPrintToChat(j,"{default}[{olive}TS{default}] %T","Give Tank To AI",j,lastHumanTank_Name);
	}
}

// pass tank to another real player
public void L4D_OnReplaceTank(int tank, int newtank)
{
	if(tank == newtank) return;

	//PrintToChatAll("L4D_OnReplaceTank %d, tick: %d", tank, GetGameTickCount());
	lastHumanTankId = GetClientUserId(tank);

	RequestFrame(OnNextFrame_Reset);
}

void OnNextFrame_Reset()
{
	lastHumanTankId = 0;
}

public Action L4D_OnEnterGhostStatePre(int client)
{
	//PrintToChatAll("L4D_OnEnterGhostStatePre %d, tick: %d", client, GetGameTickCount());
	if (lastHumanTankId && GetClientUserId(client) == lastHumanTankId)
	{
		lastHumanTankId = 0;
		L4D_State_Transition(client, STATE_DEATH_ANIM);
		
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}