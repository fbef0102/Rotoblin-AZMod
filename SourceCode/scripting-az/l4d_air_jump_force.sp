#pragma semicolon 1
#pragma newdecls required //強制1.7以後的新語法
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
#include <readyup>

#define PLUGIN_VERSION			"1.0-2025/1/13"
#define PLUGIN_NAME			    "l4d_air_jump_force"
#define DEBUG 0

public Plugin myinfo = 
{
	name		= "Jump Force",
	author		= "HarryPotter",
	description	= "Allows jump force on air.",
	version		= PLUGIN_VERSION,
	url			= "https://steamcommunity.com/profiles/76561198026784913"
}

#define TEAM_SPECTATOR		1
#define TEAM_SURVIVOR		2
#define TEAM_INFECTED		3

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

#define CVAR_FLAGS                    FCVAR_NOTIFY
#define CVAR_FLAGS_PLUGIN_VERSION     FCVAR_NOTIFY|FCVAR_DONTRECORD|FCVAR_SPONLY

ConVar g_hCvarEnable, g_hCvarBoostVelocityXY, g_hCvarBoostVelocityZ;
bool g_bCvarEnable;
float g_fCvarBoostVelocityXY, g_fCvarBoostVelocityZ;

bool 
	g_bGameStart,
	g_bLanded[MAXPLAYERS+1];

int 
	g_fLastButtons[MAXPLAYERS+1],
	g_iJumps[MAXPLAYERS+1],
	g_bAllowReJump[MAXPLAYERS+1];

public void OnPluginStart()
{
	g_hCvarEnable 			= CreateConVar( PLUGIN_NAME ... "_enable",      "1",    "0=Plugin off, 1=Plugin on.", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_hCvarBoostVelocityXY 	= CreateConVar( PLUGIN_NAME ... "_multi", 		"4.0", 	"Air Rejump velocity force multiply", CVAR_FLAGS, true, 0.1);
	g_hCvarBoostVelocityZ 	= CreateConVar( PLUGIN_NAME ... "_boost", 		"400.0","Air Rejump vertical boost", CVAR_FLAGS, true, 0.1);
	CreateConVar(                       	PLUGIN_NAME ... "_version",       PLUGIN_VERSION, PLUGIN_NAME ... " Plugin Version", CVAR_FLAGS_PLUGIN_VERSION);

	GetCvars();
	g_hCvarEnable.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarBoostVelocityXY.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarBoostVelocityZ.AddChangeHook(ConVarChanged_Cvars);

	HookEvent("round_start",            Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_jump", 			Event_PlayerJump, EventHookMode_Post);
	HookEvent("player_jump_apex",		Event_PlayerJumpApex, EventHookMode_Post);
}


// Cvars-------------------------------

void ConVarChanged_Cvars(ConVar hCvar, const char[] sOldVal, const char[] sNewVal)
{
	GetCvars();
}

void GetCvars()
{
	g_bCvarEnable = g_hCvarEnable.BoolValue;
	g_fCvarBoostVelocityXY = g_hCvarBoostVelocityXY.FloatValue;
	g_fCvarBoostVelocityZ = g_hCvarBoostVelocityZ.FloatValue;
}

//Event-------------------------------

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) 
{
	g_bGameStart = false;
}

void Event_PlayerJump( Event hEvent, const char[] sName, bool bDontBroadcast )
{

	int client = GetClientOfUserId( hEvent.GetInt( "userid" ) );

	g_bAllowReJump[client] = true;
}

void Event_PlayerJumpApex( Event hEvent, const char[] sName, bool bDontBroadcast )
{
	int client = GetClientOfUserId( hEvent.GetInt( "userid" ) );

	g_bAllowReJump[client] = true;
}

// ====================================================================================================
// KEYBINDS
// ====================================================================================================

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if(!g_bCvarEnable || g_bGameStart || !Is_Ready_Plugin_On()) return Plugin_Continue;

	if(!IsClientInGame(client) || IsFakeClient(client) || !IsPlayerAlive(client) || GetClientTeam(client) != TEAM_SURVIVOR) 
		return Plugin_Continue;

	if(L4D_IsPlayerIncapacitated(client)
		|| L4D_IsPlayerStaggering(client)) return Plugin_Continue;

	if (GetEntityFlags(client) & FL_ONGROUND)
	{
		ResetJump(client);
		g_bLanded[client] = true;
	}
	else
	{
		if(!(g_fLastButtons[client] & IN_JUMP) && (buttons & IN_JUMP))
			ReJump(client);
	}

	g_fLastButtons[client] = buttons;

	return Plugin_Continue;
}

// API---------------

public void OnRoundIsLive() 
{
	GameStart();
}

// Function-------------------------------

void GameStart()
{
	g_bGameStart = true;
}

void ReJump(int client)
{
	if ( g_bAllowReJump[client]
		&& g_bLanded[client]) // has jumped at least once but hasn't exceeded max re-jumps
	{	
		float vOrigin[3], vEyeAngles[3];
		GetEntPropVector( client, Prop_Data, "m_vecAbsOrigin", vOrigin );
		GetClientEyeAngles( client, vEyeAngles ); 								// Crosshair angles.
		vOrigin[2] += 5.0; 														// Initial elevation from the ground.
		vEyeAngles[2] = 30.0; 													// Initial elevation angle.
		GetAngleVectors( vEyeAngles, vEyeAngles, NULL_VECTOR, NULL_VECTOR );
		NormalizeVector( vEyeAngles, vEyeAngles );
		ScaleVector( vEyeAngles, 55.0 );
		vEyeAngles[0] *= g_fCvarBoostVelocityXY;
		vEyeAngles[1] *= g_fCvarBoostVelocityXY;
		vEyeAngles[2] = g_fCvarBoostVelocityZ;
		
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vEyeAngles);

		//消除落地傷害，重新計算
		SetEntPropFloat(client, Prop_Send, "m_flFallVelocity", 0.0);
	}

	g_iJumps[client]++;										// increment jump count
}

// Others-------------------------------

void ResetJump(int client) 
{
	g_iJumps[client] = 0;	// reset jumps count
	g_bLanded[client] = false;
}
