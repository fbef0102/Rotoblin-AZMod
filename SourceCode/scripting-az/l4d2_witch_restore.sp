#include <sourcemod>
#include <left4dhooks>
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
	author = "Visor, HarryPotter",
	description = "Witch is restored at the same spot if she gets killed by a Tank, l4d1 modify by Harry",
	version = "1.2",
	url = "https://github.com/Attano/smplugins"
};

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	CreateNative("IsWitchRestore", Native_WitchRestore);
	return APLRes_Success;
}

ConVar g_hCvarEnable;
bool g_bCvarEnable;

public OnPluginStart()
{
	g_hCvarEnable 		= CreateConVar( "l4d2_witch_restore_enable",        "0",   "0=Plugin off, 1=Plugin on.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	GetCvars();
	g_hCvarEnable.AddChangeHook(ConVarChanged_Cvars);

	HookEvent("witch_killed", OnWitchKilled, EventHookMode_Pre);
	HookEvent("witch_harasser_set", OnWitchWokeup);
	HookEvent("round_start", Event_RoundStart);
}

void ConVarChanged_Cvars(ConVar hCvar, const char[] sOldVal, const char[] sNewVal)
{
	GetCvars();
}

void GetCvars()
{
    g_bCvarEnable = g_hCvarEnable.BoolValue;
}

void Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{	
	WitchRestore = false;
	WitchScared = false;
}

void OnWitchKilled(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(!g_bCvarEnable) return;

	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new witch = GetEventInt(event, "witchid");
	if (IsValidTank(client)&&!WitchScared)
	{
		GetEntPropVector(witch, Prop_Send, "m_vecOrigin", originWitch);
		GetEntPropVector(witch, Prop_Send, "m_angRotation", anglesWitch);
		//PrintToChatAll("originWitch %f,anglesWitch %f",originWitch,anglesWitch);
		CreateTimer(3.0, RestoreWitch, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}


void OnWitchWokeup(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	//new witch = GetEventInt(event, "witchid");
	if(client > 0 && client <= MaxClients &&  IsClientInGame(client) && GetClientTeam(client) == 2)
	{
		//PrintToChatAll("%N woke up witch",client);
		WitchScared = true;
	}
	
}

Action RestoreWitch(Handle timer)
{
	L4D2_SpawnWitch(originWitch, anglesWitch);

	return Plugin_Continue;
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
	for (i = 1; i <= MaxClients; i++)
		if (IsClientConnected(i) && IsClientInGame(i) && (!IsFakeClient(i))) 
			return i;
	return 0;
}

public Native_WitchRestore(Handle:plugin, numParams)
{
	return WitchRestore;
}