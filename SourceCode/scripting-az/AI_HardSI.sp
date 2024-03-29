#pragma semicolon 1
#pragma newdecls required //強制1.7以後的新語法
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#include "includes/hardcoop_util.sp"
#include "modules/AI_Smoker.sp"
#include "modules/AI_Boomer.sp"
#include "modules/AI_Hunter.sp"
#include "modules/AI_Witch.sp"
#include "modules/AI_Tank.sp"


public Plugin myinfo = 
{
	name = "AI: Hard SI",
	author = "Breezy,l4d1 modify by Harry",
	description = "Improves the AI behaviour of special infected",
	version = "1.3",
	url = "github.com/breezyplease"
};

#define CVAR_FLAGS                    FCVAR_NOTIFY
#define CVAR_FLAGS_PLUGIN_VERSION     FCVAR_NOTIFY|FCVAR_DONTRECORD|FCVAR_SPONLY

ConVar g_hCvarEnable;
bool g_bCvarEnable;

bool bHasBeenShoved[MAXPLAYERS]; // shoving resets SI movement 

public void OnPluginStart() { 
	// Cvars
	g_hCvarEnable 				 	= CreateConVar( "AI_HardSI_enable",        		"1",   	"0=Plugin off, 1=Plugin on.", CVAR_FLAGS, true, 0.0, true, 1.0);

	GetCvars();
	g_hCvarEnable.AddChangeHook(ConVarChanged_Cvars);

	// Event hooks
	HookEvent("player_spawn", InitialiseSpecialInfected);
	HookEvent("ability_use", OnAbilityUse, EventHookMode_Pre); 
	HookEvent("player_jump", OnPlayerJump);
	// Load modules
	Smoker_OnModuleStart();
	Hunter_OnModuleStart();
	Boomer_OnModuleStart();
	Witch_OnModuleStart();
	Tank_OnModuleStart();
}

public void OnPluginEnd() {
	// Unload modules
	Smoker_OnModuleEnd();
	Hunter_OnModuleEnd();
	Boomer_OnModuleEnd();
	Witch_OnModuleEnd();
	Tank_OnModuleEnd();
}

void ConVarChanged_Cvars(ConVar hCvar, const char[] sOldVal, const char[] sNewVal)
{
	GetCvars();
}

void GetCvars()
{
	g_bCvarEnable = g_hCvarEnable.BoolValue;
}

/***********************************************************************************************************************************************************************************

																		SI MOVEMENT
																	
***********************************************************************************************************************************************************************************/

// Modify SI movement
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon) {
	if(!g_bCvarEnable) return Plugin_Continue;
	
	if( IsBotInfected(client) && IsPlayerAlive(client) ) { // bots continue to trigger this callback for a few seconds after death
		int botInfected = client;
		switch( GetInfectedClass(botInfected) ) {
		
			case (L4DInfected_Hunter): {
				if( !bHasBeenShoved[botInfected] ) return Hunter_OnPlayerRunCmd( botInfected, buttons, impulse, vel, angles, weapon );
			}		
				
			case (L4DInfected_Tank): {
				return Tank_OnPlayerRunCmd( botInfected, buttons, impulse, vel, angles, weapon );
			}
				
			default: {
				return Plugin_Continue;
			}		
		}
	}
	return Plugin_Continue;
}

/***********************************************************************************************************************************************************************************

																		EVENT HOOKS

***********************************************************************************************************************************************************************************/

// Initialise relevant module flags for SI when they spawn
void InitialiseSpecialInfected(Event event, char[] name, bool dontBroadcast) 
{
	if(!g_bCvarEnable) return;

	int client = GetClientOfUserId(event.GetInt("userid"));
	if( IsBotInfected(client) ) {
		int botInfected = client;
		bHasBeenShoved[client] = false;
		// Process for SI class
		switch( GetInfectedClass(botInfected) ) {
		
			case (L4DInfected_Hunter):{
				Hunter_OnSpawn(botInfected);
			}
			
			default: {
				return;	
			}				
		}
	}
}

// Modify hunter lunges and block smokers/spitters from fleeing after using their ability
Action OnAbilityUse(Event event, char[] name, bool dontBroadcast) {
	if(!g_bCvarEnable) return Plugin_Continue;

	int client = GetClientOfUserId(event.GetInt("userid"));
	if( IsBotInfected(client) ) {
		int bot = client;
		bHasBeenShoved[bot] = false; // Reset shove status		
		// Process for different SI
		char abilityName[32];
		GetEventString(event, "ability", abilityName, sizeof(abilityName));
		if( StrEqual(abilityName, "ability_lunge") ) {
			return Hunter_OnPounce(bot);
		}
	}

	return Plugin_Continue;
}

// Re-enable forced hopping when a shoved jockey leaps again naturally
void OnPlayerJump(Event event, char[] name, bool dontBroadcast) {
	if(!g_bCvarEnable) return;
	
	int jumpingPlayer = GetClientOfUserId(event.GetInt("userid"));
	if( IsBotInfected(jumpingPlayer) )  {
		bHasBeenShoved[jumpingPlayer] = false;
	}
} 

/***********************************************************************************************************************************************************************************

																	TRACKING SURVIVORS' AIM

***********************************************************************************************************************************************************************************/

/**
	Determines whether an attacking SI is being watched by the survivor
	@return: true if the survivor's crosshair is within the specified radius
	@param attacker: the client number of the attacking SI
	@param offsetThreshold: the radius(degrees) of the cone of detection around the straight line from the attacked survivor to the SI
**/
bool IsTargetWatchingAttacker( int attacker, int offsetThreshold ) {
	bool isWatching = true;
	if( GetClientTeam(attacker) == 3 && IsPlayerAlive(attacker) ) { // SI continue to hold on to their targets for a few seconds after death
		int target = GetClientAimTarget(attacker);
		if( IsSurvivor(target) ) { 
			int aimOffset = RoundToNearest(GetPlayerAimOffset(target, attacker));
			if( aimOffset <= offsetThreshold ) {
				isWatching = true;
			} else {
				isWatching = false;
			}		
		} 
	}	
	return isWatching;
}

/**
	Calculates how much a player's aim is off another player
	@return: aim offset in degrees
	@attacker: considers this player's eye angles
	@target: considers this player's position
	Adapted from code written by Guren with help from Javalia
**/
float GetPlayerAimOffset( int attacker, int target ) {
	if( !IsClientConnected(attacker) || !IsClientInGame(attacker) || !IsPlayerAlive(attacker) )
		ThrowError("Client is not Alive."); 
	if(!IsClientConnected(target) || !IsClientInGame(target) || !IsPlayerAlive(target) )
		ThrowError("Target is not Alive.");
		
	float attackerPos[3], targetPos[3];
	float aimVector[3], directVector[3];
	float resultAngle;
	
	// Get the unit vector representing the attacker's aim
	GetClientEyeAngles(attacker, aimVector);
	aimVector[0] = aimVector[2] = 0.0; // Restrict pitch and roll, consider yaw only (angles on horizontal plane)
	GetAngleVectors(aimVector, aimVector, NULL_VECTOR, NULL_VECTOR); // extract the forward vector[3]
	NormalizeVector(aimVector, aimVector); // convert into unit vector
	
	// Get the unit vector representing the vector between target and attacker
	GetClientAbsOrigin(target, targetPos); 
	GetClientAbsOrigin(attacker, attackerPos);
	attackerPos[2] = targetPos[2] = 0.0; // Restrict to XY coordinates
	MakeVectorFromPoints(attackerPos, targetPos, directVector);
	NormalizeVector(directVector, directVector);
	
	// Calculate the angle between the two unit vectors
	resultAngle = RadToDeg(ArcCosine(GetVectorDotProduct(aimVector, directVector)));
	return resultAngle;
}
