#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define		NET_TAG					"[NoEscTank]"

static 		Handle:g_hEnableNoEscTank, bool:g_bEnableNoEscTank;

new			bool:g_bVehicleIncoming;
#define NULL_VELOCITY view_as<float>({0.0, 0.0, 0.0})

public Plugin:myinfo = 
{
	name = "L4D No Escape Tank",
	author = "Harry Potter",
	description = "No Tank Spawn as the rescue vehicle is coming",
	version = "1.2",
	url = "http://steamcommunity.com/profiles/76561198026784913"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	
	if( test != Engine_Left4Dead )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1.");
		return APLRes_SilentFailure;
	}

	CreateNative("HasEscapeTank", Native_HasEscapeTank);
	return APLRes_Success;
}

public int Native_HasEscapeTank(Handle plugin, int numParams) {
	if(!g_bEnableNoEscTank)  return true;
	else return false;
}

public OnPluginStart()
{
	g_hEnableNoEscTank	= CreateConVar("no_escape_tank", "1", "Removes tanks which spawn as the rescue vehicle arrives on finales.", _, true, 0.0, true, 1.0);
	HookEvent("finale_escape_start", NET_ev_FinaleEscStart, EventHookMode_PostNoCopy);
	HookEvent("finale_vehicle_ready", 	NET_ev_Vehicle_Ready,		EventHookMode_PostNoCopy);
	HookEvent("round_start", 	NET_ev_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("tank_spawn", NET_ev_TankSpawn, EventHookMode_PostNoCopy);
	
	g_bEnableNoEscTank = GetConVarBool(g_hEnableNoEscTank);
	HookConVarChange(g_hEnableNoEscTank, _NET_Enable_CvarChange);
}

public NET_ev_FinaleEscStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_bVehicleIncoming = true;
}

public void NET_ev_Vehicle_Ready(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_bVehicleIncoming = true;
}

public NET_ev_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_bVehicleIncoming = false;
}

// public Action L4D_OnSpawnTank(const float vector[3], const float qangle[3])
// {
// 	if(g_bEnableNoEscTank && g_bVehicleIncoming)
// 	{
// 		PrintToChatAll("Blocking L4D_OnSpawnTank...");
// 		return Plugin_Handled;
// 	}
// 	return Plugin_Continue;
// }

public void NET_ev_TankSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if(g_bEnableNoEscTank && g_bVehicleIncoming)
	{
		int userid = GetEventInt(event, "userid");
		int client = GetClientOfUserId(userid);
		if(client && IsClientInGame(client) && IsFakeClient(client))
		{
			SetEntProp(client, Prop_Send, "m_isGhost", true, 1); // become ghost
			TeleportEntity(client,
			NULL_VELOCITY, // Teleport to map center
			NULL_VECTOR, 
			NULL_VECTOR);
			CreateTimer(0.5, KillEscapeTank, userid);
		}
	}
}

public Action KillEscapeTank(Handle timer, int userid)
{
	int iTank = GetClientOfUserId(userid);
	if(iTank && IsClientInGame(iTank) && IsFakeClient(iTank) && GetClientTeam(iTank) == 3 && IsPlayerTank(iTank) && IsPlayerAlive(iTank))
	{
		//ForcePlayerSuicide(iTank);
		KickClient(iTank, "Escape_tank");
	}

	return Plugin_Continue;
}

public Action L4D_OnTryOfferingTankBot(int tank_index, bool &enterStatis)
{
	if(g_bEnableNoEscTank && g_bVehicleIncoming)
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public _NET_Enable_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	g_bEnableNoEscTank = GetConVarBool(g_hEnableNoEscTank);
}

bool IsPlayerTank(int client)
{
	return GetEntProp(client, Prop_Send, "m_zombieClass") == 5;
}