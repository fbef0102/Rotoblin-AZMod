#pragma semicolon 1 


#include <sourcemod>
#include <sdktools>

#define CONSISTENCY_CHECK	1.0
#define DEBUG		0
#define PLUGIN_VERSION		"1.0"
#define CVAR_FLAGS FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_DONTRECORD

new Handle:SpawnTimer    		= INVALID_HANDLE;
new Handle:KickTimer    		= INVALID_HANDLE;
new Handle:SurvivorLimit 		= INVALID_HANDLE;
new Handle:InfectedLimit 		= INVALID_HANDLE;
new Handle:L4DSurvivorLimit 	= INVALID_HANDLE;
new Handle:L4DInfectedLimit 	= INVALID_HANDLE;
new bool:Useful[MAXPLAYERS+1];

public Plugin:myinfo =
{
	name        = "L4D SuperVersus",
	author      = "DDRKhat, Harry",
	description = "Allow versus to become up to 18vs18",
	version     = PLUGIN_VERSION,
	url         = "http://forums.alliedmods.net/showthread.php?t=92713"
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

public OnPluginStart()
{
	CreateConVar("sm_superversus_version", PLUGIN_VERSION, "L4D Super Versus", CVAR_FLAGS);
	L4DSurvivorLimit = FindConVar("survivor_limit");
	L4DInfectedLimit   = FindConVar("z_max_player_zombies");
	SurvivorLimit = CreateConVar("l4d_survivor_limit","4","Maximum amount of survivors", CVAR_FLAGS,true,1.00,true,18.00);
	InfectedLimit = CreateConVar("l4d_infected_limit","4","Max amount of infected (will not affect bots)", CVAR_FLAGS,true,1.00,true,18.00);
	SetConVarBounds(L4DSurvivorLimit, ConVarBound_Upper, true, 18.0);
	SetConVarBounds(L4DInfectedLimit,   ConVarBound_Upper, true, 18.0);
	HookConVarChange(L4DSurvivorLimit, FSL);
	HookConVarChange(SurvivorLimit, FSL);
	HookConVarChange(L4DInfectedLimit, FIL);
	HookConVarChange(InfectedLimit, FIL);

	HookEvent("round_start",Event_RoundStart);
	HookEvent("heal_begin",Event_UsefulBegin);
	HookEvent("heal_end",Event_UsefulEnd);
	HookEvent("revive_begin",Event_UsefulBegin);
	HookEvent("revive_end",Event_UsefulEnd);
	HookEvent("finale_vehicle_leaving", Event_FinaleVehicleLeaving);
}

#define FORCE_INT_CHANGE(%1,%2,%3) public %1 (Handle:c, const String:o[], const String:n[]) { SetConVarInt(%2,%3); } 
FORCE_INT_CHANGE(FSL,L4DSurvivorLimit,GetConVarInt(SurvivorLimit))
FORCE_INT_CHANGE(FIL,L4DInfectedLimit,GetConVarInt(InfectedLimit))

public OnMapEnd() 
{if (SpawnTimer != INVALID_HANDLE){

SpawnTimer = INVALID_HANDLE;}
}

public OnClientPutInServer(client)
{
	if (SpawnTimer == INVALID_HANDLE&&TeamPlayers(2)<GetConVarInt(SurvivorLimit)) SpawnTimer = CreateTimer(CONSISTENCY_CHECK, SpawnTick, _, TIMER_REPEAT);
	if (KickTimer == INVALID_HANDLE&&TeamPlayers(2)>GetConVarInt(SurvivorLimit)) KickTimer = CreateTimer(CONSISTENCY_CHECK, KickTick, _, TIMER_REPEAT);
}

public int TeamPlayers(any:team)
{
	new k=0;
	for (new i=1; i<=MaxClients; i++)
		{
			if (!IsClientConnected(i)) continue;
			if (!IsClientInGame(i))    continue;
			if (GetClientTeam(i) != team) continue;
			k++;
		}
	return k;
}

bool:RealPlayersInGame ()
{
	for (new i=1;i<=MaxClients;i++)
		if (IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i))
			return true;
	return false;
}

public OnClientDisconnect(client)
{
	if (IsFakeClient(client)) return;
	if (!RealPlayersInGame()) { new i; for (i=1;i<=MaxClients;i++) CreateTimer(0.1, KickFakeClient, i); }
}

SpawnFakeClient()
{
	new Bot = CreateFakeClient("SurvivorBot");
	if (Bot == 0) return;

	ChangeClientTeam(Bot, 2);
	DispatchKeyValue(Bot, "classname", "SurvivorBot");
	CreateTimer(0.1, KickFakeClient, Bot);
}
public Action:SpawnTick(Handle:hTimer, any:Junk)
{    
	new NumSurvivors = TeamPlayers(2);
	new MaxSurvivors = GetConVarInt(SurvivorLimit);

	if (NumSurvivors < 4)
	{

		SpawnTimer = INVALID_HANDLE;
		return Plugin_Stop;
	}

	for (;NumSurvivors < MaxSurvivors; NumSurvivors++)
	{
		SpawnFakeClient();
	}
	SpawnTimer = INVALID_HANDLE;
	return Plugin_Stop;
}

public Action:KickTick(Handle:hTimer, any:Junk)
{
	new NumSurvivors = TeamPlayers(2);
	new MaxSurvivors = GetConVarInt(SurvivorLimit);

	if (NumSurvivors < 4)
	{
		SpawnTimer = INVALID_HANDLE;
		return Plugin_Stop;
	}
	for (new i=1;i<=MaxClients;i++)
	{
		if(IsClientConnected(i)&&IsFakeClient(i)&&IsUseless(i)&&NumSurvivors>MaxSurvivors)
		{
			CreateTimer(0.1, KickFakeClient, i);
			NumSurvivors--;
		}
	}

	KickTimer = INVALID_HANDLE;
	return Plugin_Stop;
}

public Action:KickFakeClient(Handle:hTimer, any:Client)
{
	if(IsClientConnected(Client) && IsFakeClient(Client))
	{
		KickClient(Client, "Kicking Fake Bot by l4d_superversus");
	}
	return Plugin_Handled;
}

bool:IsUseless(client)
{
	if(Useful[client] == false) return true;
	return false;
}

public Event_FinaleVehicleLeaving(Handle:event, const String:name[], bool:dontBroadcast)
{
	new edict_index = FindEntityByClassname(-1, "info_survivor_position");
	if (edict_index != -1)
	{
		new Float:pos[3];
		GetEntPropVector(edict_index, Prop_Send, "m_vecOrigin", pos);
		for(new i=1; i <= MaxClients; i++)
		{
			if (!IsClientConnected(i)) continue;
			if (!IsClientInGame(i)) continue;
			if (GetClientTeam(i) != 2) continue;
			if (!IsPlayerAlive(i)) continue;
			if (GetEntProp(i, Prop_Send, "m_isIncapacitated", 1) == 1) continue;
			TeleportEntity(i, pos, NULL_VECTOR, NULL_VECTOR);
		}
	}
}

public Event_UsefulBegin(Handle:event, const String:name[], bool:dontBroadcast)
{
	Useful[GetClientOfUserId(GetEventInt(event, "userid"))] = true; //Healer
	Useful[GetClientOfUserId(GetEventInt(event, "subject"))] = true; //Target
}

public Event_UsefulEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	Useful[GetClientOfUserId(GetEventInt(event, "userid"))] = false; //Healer
	Useful[GetClientOfUserId(GetEventInt(event, "subject"))] = false; //Target
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (SpawnTimer == INVALID_HANDLE&&TeamPlayers(2)<GetConVarInt(SurvivorLimit)) SpawnTimer = CreateTimer(CONSISTENCY_CHECK, SpawnTick, _, TIMER_REPEAT);
	if (KickTimer == INVALID_HANDLE&&TeamPlayers(2)>GetConVarInt(SurvivorLimit)) KickTimer = CreateTimer(CONSISTENCY_CHECK, KickTick, _, TIMER_REPEAT);
}