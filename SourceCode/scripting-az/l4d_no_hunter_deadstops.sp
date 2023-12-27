#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>

ConVar hCvarFlags;
ConVar hCvarFlags2;
int g_iCvarcontrolvalue;
int g_iCvarcontrolvalue2;
#define DEBUG 0

#define Z_HUNTER 3
#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3

bool bIsPouncing[MAXPLAYERS + 1]; // whether hunter player is currently pouncing/lunging

float 
	bIsPouncingStartTime[MAXPLAYERS + 1],  // Pouncing stop time 
	bIsPouncingStopTime[MAXPLAYERS + 1];  // Pouncing stop time 

ConVar
	cvarHunterGroundM2Godframes;

bool PluginDisable = false;

public Plugin myinfo = 
{
	name = "L4D No Hunter Deadstops",
	author = "Spoon, Luckylock, A1m`, l4d1 port by Harry",
	description = "Self-descriptive",
	version = "1.0.6-2023/12/27",
	url = "https://github.com/luckyserv"
};

public void OnPluginStart()
{
	hCvarFlags = FindConVar("versus_shove_hunter_fov_pouncing");
	hCvarFlags2 = FindConVar("versus_shove_hunter_fov");
	
	GetCvars();
	HookConVarChange(hCvarFlags, OnCvarChange_control);
	HookConVarChange(hCvarFlags2, OnCvarChange_control);

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
	HookEvent("ability_use", Event_AbilityUse, EventHookMode_Post);
	HookEvent("player_team", Event_PlayerTeam);

	cvarHunterGroundM2Godframes = CreateConVar("hunter_ground_m2_godframes", "0.25", "m2 godframes after a hunter lands on the ground", _, true, 0.0, true, 1.0);
}

public Action L4D2_OnEntityShoved(int client, int entity, int weapon, float vecDir[3], bool bIsHighPounce)
{
 	if (!IsSurvivor(client) || !IsHunter(entity) || IsPluginDisable())
 		return Plugin_Continue;

 	#if DEBUG
 		PrintToChatAll("\x01%N Invoked \"L4D2_OnEntityShoved\x01 on \x03%N\x01, bIsHighPounce: %d", client, entity, bIsHighPounce);
 	#endif	 
	
	if( bIsHighPounce || IsPlayingPounceAnimation(entity) || Shove_Handler(entity) )
	{
	#if DEBUG 
		PrintToChatAll("\x04Hunter %N is still pouncing!",entity);
	#endif
		bIsPouncingStopTime[entity] = 0.0;
		bIsPouncing[entity] = true;
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public Action L4D_OnShovedBySurvivor(int shover, int shovee, const float vecDir[3])
{
	if (!IsSurvivor(shover) || !IsHunter(shovee) || IsPluginDisable()) 
		return Plugin_Continue;

	#if DEBUG
		PrintToChatAll("\x01%N Invoked \"L4D_OnShovedBySurvivor\x01 on \x03%N\x01, vecDir: %f, %f, %f", shover, shovee, vecDir[0], vecDir[1], vecDir[2]);
	#endif

	if( IsPlayingPounceAnimation(shovee) || Shove_Handler(shovee))
	{
	#if DEBUG 
		PrintToChatAll("\x04 Hunter %N is still pouncing!", shovee);
	#endif
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

void OnCvarChange_control(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_iCvarcontrolvalue = hCvarFlags.IntValue;
	g_iCvarcontrolvalue2 = hCvarFlags2.IntValue;
	
	if( (g_iCvarcontrolvalue == 0 && g_iCvarcontrolvalue2 == 0) || g_iCvarcontrolvalue != 0 )
	{
		PluginDisable = true;
	}
	else
	{
		PluginDisable = false;
	}
}

bool IsPluginDisable()
{
	return PluginDisable;
}

bool Shove_Handler(int shovee)
{
	// If the hunter is not lunging (pouncing)
	if (bIsPouncing[shovee] == false) {
		return false;
	}

	// If the hunter is on a survivor, allow m2s
	if (HasTarget(shovee)) {
		#if DEBUG
			PrintToChatAll("\x05%N Hunter has target, Not pouncing anymore.", shovee);
		#endif
		bIsPouncing[shovee] = false;
		return false;
	}
	
	return true; // the hunter is lunging (pouncing) block m2s
} 

// check if client is on survivor team
bool IsSurvivor(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVOR);
}

// check if client is on infected team
bool IsInfected(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == TEAM_INFECTED);
}

// check if client is a hunter
bool IsHunter(int client)  
{
	if (!IsInfected(client)) {
		return false;
	}
	
	if (!IsPlayerAlive(client)) {
		return false;
	}
	
	if (GetEntProp(client, Prop_Send, "m_zombieClass") != Z_HUNTER) {
		return false;
	}
	
	return true;
}

// check if the hunter is on a survivor 
bool HasTarget(int hunter)
{
	int target = GetEntPropEnt(hunter, Prop_Send, "m_pounceVictim");

	return (IsSurvivor(target) && IsPlayerAlive(target));
}

void Event_RoundStart(Event hEvent, const char[] name, bool dontBroadcast)
{
	// clear SI tracking stats
	for (int i = 1; i <= MaxClients; i++)
	{
		bIsPouncing[i] = false;
	}
}

void Event_PlayerDeath(Event hEvent, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(hEvent.GetInt("userid"));

	if (victim <= 0 
	|| victim > MaxClients
	|| !IsClientInGame(victim)) 
		return;

	bIsPouncing[victim] = false;
}

// hunters pouncing / tracking
void Event_AbilityUse(Event hEvent, const char[] name, bool dontBroadcast)
{
	// track hunters pouncing
	char abilityName[64];
	hEvent.GetString("ability", abilityName, sizeof(abilityName));
	
	if (strcmp(abilityName, "ability_lunge", false) == 0) {
		int client = GetClientOfUserId(hEvent.GetInt("userid"));
		
		if (client <= 0 
		|| client > MaxClients 
		|| !IsClientInGame(client) 
		|| GetClientTeam(client) != TEAM_INFECTED)
			return;


		// Hunter pounce
		bIsPouncingStopTime[client] = 0.0;
		bIsPouncingStartTime[client] = GetEngineTime();
		bIsPouncing[client] = true;
	}
}

void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast) 
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	bIsPouncing[client] = false;
}

public void OnGameFrame()
{
	float fNow = GetEngineTime();
	for (int client = 1; client <= MaxClients; client++) {
		bIsPouncing[client] = bIsPouncing[client] && IsClientInGame(client) && IsPlayerAlive(client);

		if (bIsPouncing[client]) {
			if (fNow - bIsPouncingStartTime[client] > 0.04) {

				if (bIsPouncingStopTime[client] == 0.0) {
					if ( (GetEntityFlags(client) & FL_ONGROUND) || GetEntityMoveType(client) == MOVETYPE_LADDER) {
						#if DEBUG
							PrintToChatAll("Hunter %N grounded or ladder (buffer = %f s)", client, cvarHunterGroundM2Godframes.FloatValue);
						#endif
						bIsPouncingStopTime[client] = fNow;    
					}
				} else if (fNow - bIsPouncingStopTime[client] > cvarHunterGroundM2Godframes.FloatValue) {
					#if DEBUG
						PrintToChatAll("\x05%N Not pouncing anymore.", client);
					#endif
					bIsPouncing[client] = false;
				}
			}
		}
	} 
}

bool IsPlayingPounceAnimation(int hunter)  
{
	int Activity = L4D1_GetMainActivity(hunter);
	
	#if DEBUG
		PrintToChatAll("\x04%N\x01 playing Activity \x04%d\x01", hunter, Activity);
	#endif

	switch (Activity) 
	{
		case L4D1_ACT_TERROR_HUNTER_LUNGE_OFF_WALL_SPIN_RIGHT, //1238
		L4D1_ACT_TERROR_HUNTER_LUNGE_OFF_WALL_SPIN_LEFT, //1239
		L4D1_ACT_TERROR_HUNTER_LUNGE_OFF_WALL_BACK, //1240
		L4D1_ACT_TERROR_HUNTER_LUNGE_IDLE,  //1241
		L4D1_ACT_TERROR_HUNTER_LUNGE_ONTO_WALL,  //1242
		L4D1_ACT_TERROR_HUNTER_POUNCE, //1243
		L4D1_ACT_TERROR_HUNTER_POUNCE_IDLE: //1244
			return true;
	}

	return false;
}

int L4D1_GetMainActivity(int client) {
	static int s_iOffs_m_eCurrentMainSequenceActivity = -1;
	if (s_iOffs_m_eCurrentMainSequenceActivity == -1)
		s_iOffs_m_eCurrentMainSequenceActivity = FindSendPropInfo("CTerrorPlayer", "m_iProgressBarDuration") + 476;
	
	return LoadFromAddress(GetEntityAddress(client) + view_as<Address>(s_iOffs_m_eCurrentMainSequenceActivity), NumberType_Int32);
}