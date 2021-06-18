#include <sourcemod>
#include <sdktools>
#include <l4d_direct>
#include <l4d_lib>
#define PLUGIN_VERSION "1.4"
#define WITCH_SPAWN_INTERVAL   0.5
#define DEBUG 0

new bool:g_bIsTankAlive;
new bool:b_KillWitch;
new Float:iWitchPercentFloat = 0.0;
new Float:SurCurrentFloat = 0.0;
static bool:b_SpawnWitchFix;
static bool:RoundEnd;
new Handle:SV_CHEATS;

native Float:GetWitchPercentFloat();//From l4d_boss_percent.smx
native Float:GetSurCurrentFloat();//From l4d_current_survivor_progress.smx
native IsWitchRestore();//From l4d2_witch_restore.smx

public Plugin:myinfo = 
{
	name = "L4D Wtich spawn fix when tank",
	author = "Harry Potter",
	description = "Fix the problem that versus director won't spawn Witch during Tank alive",
	version = PLUGIN_VERSION,
	url = "myself"
}

public OnPluginStart()
{
	SV_CHEATS = FindConVar("sv_cheats");
	HookEvent("round_start", Event_Round_Start);
	HookEvent("tank_spawn", PD_ev_TankSpawn, EventHookMode_PostNoCopy);
	HookEvent("entity_killed",		PD_ev_EntityKilled);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("witch_spawn", WitchSpawn_Event);
}
public OnConfigsExecuted()
{

	new Handle:WITCHPARTY = FindConVar("l4d_multiwitch_enabled");
	if(WITCHPARTY != INVALID_HANDLE)
	{
		if(GetConVarInt(WITCHPARTY) == 1)
		{
			//LogMessage("WITCH PARTY Enable, unload l4d_witchspawnfix_whentank.smx");
			ServerCommand("sm plugins unload l4d_witchspawnfix_whentank.smx");
		}
	}
}
public WitchSpawn_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(GetConVarInt(SV_CHEATS) == 1) return;
	
	#if DEBUG
		PrintToChatAll("[Fix] Spawn Witch Already!!");
	#endif
	
	new witchid = GetEventInt(event, "witchid");
	if(b_SpawnWitchFix && !IsWitchRestore() && b_KillWitch)
	{
		#if DEBUG
			PrintToChatAll("[Fix] Detect Second Witch Spawned already, kill it!!");
		#endif
		CreateTimer(0.1,ColdDown,witchid);//延遲一秒檢查
		b_KillWitch = false;
	}
	b_SpawnWitchFix = true;
}

public Action:ColdDown(Handle:timer,any:witchid)
{
	if(IsValidEntity(witchid))
		RemoveEdict(witchid);
}

public Action:PD_ev_TankSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(GetConVarInt(SV_CHEATS) == 1) return;

	if(!g_bIsTankAlive)
	{
		g_bIsTankAlive = true;
		SurCurrentFloat = 0.0;
		if(!b_SpawnWitchFix)
			CreateTimer(WITCH_SPAWN_INTERVAL,Check_Witch_Spawn,_,TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
}
public Action:Check_Witch_Spawn(Handle:timer)
{
	if(GetConVarInt(SV_CHEATS) == 1) return Plugin_Stop;

	SurCurrentFloat = GetSurCurrentFloat();
	iWitchPercentFloat = GetWitchPercentFloat();
	#if DEBUG
		PrintToChatAll("[Fix] SurCurrentFloat is %f",SurCurrentFloat);
	#endif
	if(b_SpawnWitchFix||!g_bIsTankAlive||RoundEnd || iWitchPercentFloat == 0.0)
	{
		return Plugin_Stop;
	}
	if(SurCurrentFloat>=iWitchPercentFloat && !b_SpawnWitchFix)
	{
		decl String:command[20];
		Format(command, sizeof(command), "witch auto");
		StripAndExecuteClientCommand("z_spawn",command);
		b_KillWitch = true;
	}
	return Plugin_Continue;
}

public Action:PD_ev_EntityKilled(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (g_bIsTankAlive && IsPlayerTank(GetEventInt(event, "entindex_killed")))
	{
		#if DEBUG
			PrintToChatAll("[Fix] Tank Dead1!");
		#endif
		g_bIsTankAlive = false;
	}
}

public Action:Event_Round_Start(Handle:event, String:name[], bool:dontBroadcast)
{
	b_SpawnWitchFix = false;
	g_bIsTankAlive = false;
	RoundEnd = false;
	b_KillWitch = false;
}

public Action:Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{	
	RoundEnd = true;
}

StripAndExecuteClientCommand(String:command[], const String:arguments[]) 
{
	new client;
	for (new i = 1; i <= MaxClients; i++) 
	{ 
		if (IsClientConnected(i) && IsClientInGame(i))
		{
			client = i;    
			break;
		} 
	}
	new flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", command, arguments);
	SetCommandFlags(command, flags);
	#if DEBUG
		PrintToChatAll("[Fix] Try to Spawn witch!!");
	#endif
}