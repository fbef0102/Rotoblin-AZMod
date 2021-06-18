#include <sourcemod>
#include <left4downtown>
#include <sdktools>
#include <sdkhooks>

new Float:originWitch[3];
new Float:anglesWitch[3];
new bool:WitchRestore;
new bool:WitchScared;
#define NULL					-1

public Plugin:myinfo =
{
	name = "L4D2 Witch Restore",
	author = "Visor",
	description = "Witch is restored at the same spot if she gets killed by a Tank, l4d1 modify by Harry",
	version = "1.1",
	url = "https://github.com/Attano/smplugins"
};

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	CreateNative("IsWitchRestore", Native_WitchRestore);
	return APLRes_Success;
}

public OnPluginStart()
{
	HookEvent("witch_killed", OnWitchKilled, EventHookMode_Pre);
	HookEvent("witch_harasser_set", OnWitchWokeup);
	HookEvent("round_start", Event_RoundStart);
	HookEvent("witch_spawn", WitchSpawn_Event);
}

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{	
	WitchRestore = false;
	WitchScared = false;
}

public Action:OnWitchKilled(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new witch = GetEventInt(event, "witchid");
	if (IsValidTank(client)&&!WitchScared)
	{
		GetEntPropVector(witch, Prop_Send, "m_vecOrigin", originWitch);
		GetEntPropVector(witch, Prop_Send, "m_angRotation", anglesWitch);
		//PrintToChatAll("originWitch %f,anglesWitch %f",originWitch,anglesWitch);
		WitchRestore = true;
		CreateTimer(3.0, RestoreWitch, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}


public Action:OnWitchWokeup(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	//new witch = GetEventInt(event, "witchid");
	if(client > 0 && client <= MaxClients &&  IsClientInGame(client) && GetClientTeam(client) == 2)
	{
		//PrintToChatAll("%N woke up witch",client);
		WitchScared = true;
	}
	
}

public Action:RestoreWitch(Handle:timer)
{
	new anyclient = GetAnyClient()
	SpawnCommand(anyclient, "z_spawn", "witch auto");
}

stock SpawnCommand(client, String:command[], String:arguments[] = "") // version 1.1
{
	if (client)
	{		
		new flags = GetCommandFlags(command);
		SetCommandFlags(command, flags & ~FCVAR_CHEAT);
		FakeClientCommand(client, "%s %s", command, arguments);
		SetCommandFlags(command, flags);
	}
}

public WitchSpawn_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(WitchRestore){
		new WitchID = GetEventInt(event, "witchid");
		if (WitchID == NULL || !IsValidEntity(WitchID)) return;
		TeleportEntity(WitchID, originWitch, anglesWitch, NULL_VECTOR);
		CreateTimer(0.5, ColdDown, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action:ColdDown(Handle:timer)
{
	WitchRestore = false;
}

bool:IsValidTank(client)
{
	return (client > 0
		&& client <= MaxClients
		&& IsClientInGame(client)
		&& GetClientTeam(client) == 3
		&& GetEntProp(client, Prop_Send, "m_zombieClass") == 5);
}

stock GetAnyClient()
{
	new i;
	for (i = 1; i <= GetMaxClients(); i++)
		if (IsClientConnected(i) && IsClientInGame(i) && (!IsFakeClient(i))) 
			return i;
	return 0;
}

public Native_WitchRestore(Handle:plugin, numParams)
{
	return WitchRestore;
}