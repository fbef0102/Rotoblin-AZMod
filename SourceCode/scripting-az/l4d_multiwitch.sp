#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define MAX(%0,%1) (((%0) > (%1)) ? (%0) : (%1))
#define MIN(%0,%1) (((%0) < (%1)) ? (%0) : (%1))
#define ZOMBIESPAWN_Attempts 5

new Handle:	hEnabled;
new bool:	bEnabled;

new Handle:	hSpawnFreq;
new Float:	fSpawnFreq;

native IsInPause();

new Handle:	hMaxWitchAllowed;
new MaxWitchAllowed;
new Handle:	hWitchSpawnTimer;

new Handle:hw_max_health;
new Handle:hw_cap_health;
new Handle:hw_perm_gain;
new Handle:hw_temp_gain;
new Handle:pain_pills_decay_rate;
ConVar h_WitchKillTime;

public Plugin:myinfo =
{
	name = "L4D1 Multiwitch",
	author = "CanadaRox , l4d1 modify by Harry",
	description = "A plugin designed to support witch party",
	version = "2.6-2026/7/24",
	url = "http://steamcommunity.com/profiles/76561198026784913"
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

#define MAX_ENTITY 2048
int g_iModelIndex[MAX_ENTITY +1];
float WitchvPos[MAX_ENTITY +1][3];
float WitchvAvg[MAX_ENTITY +1][3];

public OnPluginStart()
{
	
	hEnabled = CreateConVar("l4d_multiwitch_enabled", "1", "Enable multiple witch spawning");
	HookConVarChange(hEnabled, Enabled_Changed);
	bEnabled = GetConVarBool(hEnabled);

	hSpawnFreq = CreateConVar("l4d_multiwitch_spawnfreq", "30", "How many seconds before the next witch spawns");
	HookConVarChange(hSpawnFreq, Freq_Changed);
	fSpawnFreq = GetConVarFloat(hSpawnFreq);

	hMaxWitchAllowed = CreateConVar("l4d_multiwitch_maxspawn_limit", "20", "Max Witch Spawn limit, prevent server from too many entity crash");
	HookConVarChange(hMaxWitchAllowed, hMaxWitchAllowed_Changed);
	MaxWitchAllowed = GetConVarInt(hMaxWitchAllowed);
	
	HookEvent("round_end", Event_RoundEnd); //對抗上下回合結束的時候觸發
	HookEvent("map_transition", Event_RoundEnd); //戰役過關到下一關的時候 (之後沒有觸發round_end)
	HookEvent("mission_lost", Event_RoundEnd); //戰役滅團重來該關卡的時候 (之後有觸發round_end)
	HookEvent("finale_win", Event_RoundEnd);
	
	HookEvent("witch_spawn", WitchSpawn_Event);
	HookEvent("witch_harasser_set", OnWitchWokeup);
	HookEvent("witch_killed", Event_WitchKilled);
	
	pain_pills_decay_rate = FindConVar("pain_pills_decay_rate");

	hw_max_health = CreateConVar("l4d_multiwitch_max_health", "150", "Max health that a survivor can have after gaining health", FCVAR_NOTIFY, true, 100.0);
	hw_cap_health = CreateConVar("l4d_multiwitch_cap_health", "1", "Whether to cap the health survivors can gain from this plugin", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	hw_perm_gain = CreateConVar("l4d_multiwitch_perm_gain", "5", "Amount of perm health to gain for killing a witch", FCVAR_NOTIFY, true, 0.0);
	hw_temp_gain = CreateConVar("l4d_multiwitch_temp_gain", "10", "Amount of temp health to gain for killing a witch", FCVAR_NOTIFY, true, 0.0);
	h_WitchKillTime = CreateConVar("l4d_multiwitch_lifespan", "200", "Amount of seconds before a witch is kicked", FCVAR_NOTIFY, true, 1.0);
}

public void L4D_OnFirstSurvivorLeftSafeArea_Post(int client)
{
	delete hWitchSpawnTimer;
	hWitchSpawnTimer = CreateTimer(fSpawnFreq, WitchSpawn_Timer, _, TIMER_REPEAT);
}

public Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	delete hWitchSpawnTimer;
}

public Enabled_Changed(Handle:convar, const String:oldValue[], const String:newValue[])
{
	bEnabled = GetConVarBool(hEnabled);
}

public Freq_Changed(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (hWitchSpawnTimer != null)
	{
		delete hWitchSpawnTimer;
		fSpawnFreq = GetConVarFloat(hSpawnFreq);
		if (fSpawnFreq >= 1.0)
		{
			hWitchSpawnTimer = CreateTimer(fSpawnFreq, WitchSpawn_Timer, _, TIMER_REPEAT);
		}
	}
}

public hMaxWitchAllowed_Changed(Handle:convar, const String:oldValue[], const String:newValue[])
{
	MaxWitchAllowed = GetConVarInt(hMaxWitchAllowed);
}

Action WitchSpawn_Timer(Handle timer)
{
	if(IsInPause())
	{
		return Plugin_Continue;
	}
	
	new iWitch = -1;
	new witchSpawnCount;
	while((iWitch = FindEntityByClassname(iWitch, "witch")) != -1)
	{
		witchSpawnCount++;
	}

	//PrintToChatAll("witchSpawnCount: %d - MaxWitchAllowed: %d",witchSpawnCount,MaxWitchAllowed);
	if (bEnabled  && witchSpawnCount < MaxWitchAllowed)
	{
		float vecPos[3];
		int anyclient = L4D_GetHighestFlowSurvivor();
		if(anyclient <= 0) return Plugin_Continue;

		if(L4D_GetRandomPZSpawnPosition(anyclient,5,ZOMBIESPAWN_Attempts,vecPos) == true)
		{
			L4D2_SpawnWitch(vecPos,NULL_VECTOR);
		}
		else
		{
			PrintToServer("[TS] Couldn't find a Witch Spawn position in %d tries", ZOMBIESPAWN_Attempts);
		}
	}

	return Plugin_Continue;
}

void WitchSpawn_Event(Event event, const char[] name, bool dontBroadcast)
{	
	int witch = GetEventInt(event, "witchid");

	CreateWitchGlowForSurvivor(witch);

	CreateTimer(h_WitchKillTime.FloatValue ,KickWitch_Timer,EntIndexToEntRef(witch),TIMER_FLAG_NO_MAPCHANGE);
}

void OnWitchWokeup(Event event, const char[] name, bool dontBroadcast)
{	
	int witch = GetEventInt(event, "witchid");
	RemoveWitchGlowForSurvivor(witch);
	SDKUnhook(witch, SDKHook_ThinkPost, WitchThink);
}

public Event_WitchKilled(Event event, const char[] name, bool dontBroadcast)
{	
	int witch = GetEventInt(event, "witchid");
	RemoveWitchGlowForSurvivor(witch);
	SDKUnhook(witch, SDKHook_ThinkPost, WitchThink);

	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client) && !IsPlayerIncap(client))
	{
		IncreaseHealth(client);
	}
}

void CreateWitchGlowForSurvivor(int witch)
{
	if (!IsValidEntity(witch)) return;

	GetEntPropVector(witch, Prop_Data, "m_vecOrigin", WitchvPos[witch]);
	GetEntPropVector(witch, Prop_Send, "m_angRotation", WitchvAvg[witch]);
	
	int entity = CreateEntityByName("prop_glowing_object");
	
	if (entity <= 0)  return;

	//just in case
	RemoveWitchGlowForSurvivor(witch);

	static char sModelName[64];
	GetEntPropString(witch, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName));
	DispatchKeyValue(entity, "model", sModelName);
	DispatchKeyValue(entity, "StartGlowing", "1");

	DispatchKeyValue(entity, "fadescale", "1");
	DispatchKeyValue(entity, "fademindist", "3000");
	DispatchKeyValue(entity, "fademaxdist", "3200");
	
	DispatchKeyValue(entity, "GlowForTeam", "2");

	/* GlowForTeam =  -1:ALL  , 0:NONE , 1:SPECTATOR  , 2:SURVIVOR , 3:INFECTED */
	
	TeleportEntity(entity, WitchvPos[witch], WitchvAvg[witch], NULL_VECTOR);
	DispatchSpawn(entity);
	SetEntityRenderMode( entity, RENDER_TRANSCOLOR );
	SetEntityRenderColor (entity, 0, 0, 0, 0 );
	
	SetVariantString("!activator");
	AcceptEntityInput(entity, "SetParent", witch);
	SetEntPropFloat(entity, Prop_Send, "m_flPlaybackRate" ,1.0); 

	g_iModelIndex[witch] = EntIndexToEntRef(entity);

	SDKHook(witch, SDKHook_ThinkPost, WitchThink);
	SDKHook(entity, SDKHook_SetTransmit, Hook_SetTransmit);
}

void RemoveWitchGlowForSurvivor(int witch)
{
	int entity = g_iModelIndex[witch];
	g_iModelIndex[witch] = 0;

	if( IsValidEntRef(entity) )
		AcceptEntityInput(entity, "kill");
}

void WitchThink(int witch)
{
	int entity = g_iModelIndex[witch];
	int nSequence = GetEntProp(witch, Prop_Send, "m_nSequence");
	if(IsValidEntRef(entity))
	{
		SetEntProp(entity, Prop_Send, "m_nSequence", nSequence);
	}
}

Action Hook_SetTransmit(int entity, int client)
{
	return Plugin_Handled;
}

void IncreaseHealth(int client)
{
	new bool:capped = GetConVarBool(hw_cap_health);
	new targetHealth = GetSurvivorPermHealth(client) + GetConVarInt(hw_perm_gain);	
	new Float:targetTemp = GetSurvivorTempHealth(client) + GetConVarInt(hw_temp_gain);

	if (capped)
	{
		new maxHealth = GetConVarInt(hw_max_health);
		targetHealth = MIN(targetHealth, maxHealth);

		new Float:totalHealth = targetHealth + targetTemp;
		totalHealth = MIN(totalHealth, float(maxHealth));
		targetTemp = totalHealth - targetHealth;
	}

	if(GetSurvivorPermHealth(client) == 1)
	{
		new give_flags = GetCommandFlags("give");
		SetCommandFlags("give", give_flags & ~FCVAR_CHEAT);
		FakeClientCommand(client, "give health");
		SetCommandFlags("give", give_flags);
	}
	SetSurvivorPermHealth(client, targetHealth);
	SetSurvivorTempHealth(client, targetTemp);
}

stock GetSurvivorPermHealth(client)
{
	return GetEntProp(client, Prop_Send, "m_iHealth");
}

stock SetSurvivorPermHealth(client, health)
{
	SetEntProp(client, Prop_Send, "m_iHealth", health);
}

stock Float:GetSurvivorTempHealth(client)
{
	new Float:tmp = GetEntPropFloat(client, Prop_Send, "m_healthBuffer") - ((GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * GetConVarFloat(pain_pills_decay_rate));
	return tmp > 0 ? tmp : 0.0;
}

stock SetSurvivorTempHealth(client, Float:newOverheal)
{
	SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", newOverheal);
}

stock bool:IsPlayerIncap(client)
{
	return bool:GetEntProp(client, Prop_Send, "m_isIncapacitated");
}

Action KickWitch_Timer(Handle timer, int ref)
{
	if( bEnabled == false) return Plugin_Continue;

	if(IsValidEntRef(ref))
	{
		int entity = EntRefToEntIndex(ref);
		bool bKill = true;
		float clientOrigin[3];
		float witchOrigin[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", witchOrigin);
		for (int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
			{
				GetClientAbsOrigin(i, clientOrigin);
				if (GetVectorDistance(clientOrigin, witchOrigin, true) < Pow(1500.0, 2.0))
				{
					bKill = false;
					break;
				}
			}
		}

		if(bKill) AcceptEntityInput(ref, "kill"); //remove witch
		else CreateTimer(h_WitchKillTime.FloatValue, KickWitch_Timer, ref,TIMER_FLAG_NO_MAPCHANGE);
	}

	return Plugin_Continue;
}

bool IsValidEntRef(int entity)
{
	if( entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE )
		return true;
	return false;
}