#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <smlib>

#include "includes/hardcoop_util.sp"
#include "modules/AI_Smoker.sp"
#include "modules/AI_Boomer.sp"
#include "modules/AI_Hunter.sp"
#include "modules/AI_Witch.sp"
#include "modules/AI_Tank.sp"

new Handle:hCvarAssaultReminderInterval;

new bool:bHasBeenShoved[MAXPLAYERS]; // shoving resets SI movement 

public Plugin:myinfo = 
{
	name = "AI: Hard SI",
	author = "Breezy,l4d1 modify by Harry",
	description = "Improves the AI behaviour of special infected",
	version = "1.2",
	url = "github.com/breezyplease"
};

public OnPluginStart() { 
	// Cvars
	hCvarAssaultReminderInterval = CreateConVar( "ai_assault_reminder_interval", "2", "Frequency(sec) at which the 'nb_assault' command is fired to make SI attack" );
	// Event hooks
	HookEvent("player_spawn", InitialiseSpecialInfected, EventHookMode_Pre);
	HookEvent("ability_use", OnAbilityUse, EventHookMode_Pre); 
	HookEvent("player_jump", OnPlayerJump, EventHookMode_Pre);
	HookEvent("player_left_start_area", LeftStartAreaEvent, EventHookMode_PostNoCopy);
	// Load modules
	Smoker_OnModuleStart();
	Hunter_OnModuleStart();
	Boomer_OnModuleStart();
	Witch_OnModuleStart();
	Tank_OnModuleStart();
}

public OnPluginEnd() {
	// Unload modules
	Smoker_OnModuleEnd();
	Hunter_OnModuleEnd();
	Boomer_OnModuleEnd();
	Witch_OnModuleEnd();
	Tank_OnModuleEnd();
}

/***********************************************************************************************************************************************************************************

																	KEEP SI AGGRESSIVE
																	
***********************************************************************************************************************************************************************************/

public LeftStartAreaEvent(Handle:event, String:name[], bool:dontBroadcast)
{
	CreateTimer( float(GetConVarInt(hCvarAssaultReminderInterval)), Timer_ForceInfectedAssault, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE );
}

public Action:Timer_ForceInfectedAssault( Handle:timer ) {
	CheatCommand("nb_assault");
}

/***********************************************************************************************************************************************************************************

																		SI MOVEMENT
																	
***********************************************************************************************************************************************************************************/

// Modify SI movement
public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon) {
	if( IsBotInfected(client) && IsPlayerAlive(client) ) { // bots continue to trigger this callback for a few seconds after death
		new botInfected = client;
		switch( L4D_Infected:GetInfectedClass(botInfected) ) {
		
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
public Action:InitialiseSpecialInfected(Handle:event, String:name[], bool:dontBroadcast) {
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if( IsBotInfected(client) ) {
		new botInfected = client;
		bHasBeenShoved[client] = false;
		// Process for SI class
		switch( L4D_Infected:GetInfectedClass(botInfected) ) {
		
			case (L4DInfected_Hunter):{
				return Hunter_OnSpawn(botInfected);
			}
			
			default: {
				return Plugin_Handled;	
			}				
		}
	}
	return Plugin_Handled;
}

// Modify hunter lunges and block smokers/spitters from fleeing after using their ability
public Action:OnAbilityUse(Handle:event, String:name[], bool:dontBroadcast) {
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if( IsBotInfected(client) ) {
		new bot = client;
		bHasBeenShoved[bot] = false; // Reset shove status		
		// Process for different SI
		new String:abilityName[32];
		GetEventString(event, "ability", abilityName, sizeof(abilityName));
		if( StrEqual(abilityName, "ability_lunge") ) {
			return Hunter_OnPounce(bot);
		}
	}
	return Plugin_Handled;
}

public Action:OnTongueRelease(Handle:event, String:name[], bool:dontBroadcast) {
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if( IsBotInfected(client) ) {
		CreateTimer(0.5, Timer_Suicide, any:client, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action:Timer_Suicide(Handle:timer, any:client) {
	ForcePlayerSuicide(client);
	return Plugin_Handled;
}

// Re-enable forced hopping when a shoved jockey leaps again naturally
public Action:OnPlayerJump(Handle:event, String:name[], bool:dontBroadcast) {
	new jumpingPlayer = GetClientOfUserId(GetEventInt(event, "userid"));
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
bool:IsTargetWatchingAttacker( attacker, offsetThreshold ) {
	new bool:isWatching = true;
	if( GetClientTeam(attacker) == 3 && IsPlayerAlive(attacker) ) { // SI continue to hold on to their targets for a few seconds after death
		new target = GetClientAimTarget(attacker);
		if( IsSurvivor(target) ) { 
			new aimOffset = RoundToNearest(GetPlayerAimOffset(target, attacker));
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
Float:GetPlayerAimOffset( attacker, target ) {
	if( !IsClientConnected(attacker) || !IsClientInGame(attacker) || !IsPlayerAlive(attacker) )
		ThrowError("Client is not Alive."); 
	if(!IsClientConnected(target) || !IsClientInGame(target) || !IsPlayerAlive(target) )
		ThrowError("Target is not Alive.");
		
	decl Float:attackerPos[3], Float:targetPos[3];
	decl Float:aimVector[3], Float:directVector[3];
	decl Float:resultAngle;
	
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

