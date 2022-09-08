#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>
#include <multicolors>

int lastHumanTankId;
native void SetClientDeathCam(int client); // from nodeathcamskip.smx

public Plugin myinfo =
{
	name = "L4D2 Profitless AI Tank",
	author = "Visor, Forgetest, l4d1 modify by Harry",
	description = "Passing control to AI Tank will no longer be rewarded with an instant respawn",
	version = "0.5",
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
}

public void OnMapStart()
{
	lastHumanTankId = 0;
}

void OnTankFrustrated(Event event, const char[] name, bool dontBroadcast)
{
	lastHumanTankId = event.GetInt("userid");
	RequestFrame(OnNextFrame_Reset);
}

void OnNextFrame_Reset()
{
	lastHumanTankId = 0;
}

public Action L4D_OnEnterGhostStatePre(int client)
{
	if (lastHumanTankId && GetClientUserId(client) == lastHumanTankId)
	{
		lastHumanTankId = 0;
		L4D_State_Transition(client, STATE_DEATH_ANIM);
		SetClientDeathCam(client); //Block player skipping death cam

		static char lastHumanTank_Name[128];
		GetClientName(client, lastHumanTank_Name, 128);
		for (int j = 1; j <= MaxClients; j++)
			if (IsClientInGame(j) && IsClientConnected(j) && !IsFakeClient(j) && (GetClientTeam(j) == 1 || GetClientTeam(j) == 3))
				CPrintToChat(j,"{default}[{olive}TS{default}] %T","Give Tank To AI",j,lastHumanTank_Name);
		
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}