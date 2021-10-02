#pragma semicolon 1

#include <sdktools>
#define DEBUG_HUNTER_AIM 0
#define DEBUG_HUNTER_RNG 0
#define DEBUG_HUNTER_ANGLE 0

#define POSITIVE 0
#define NEGATIVE 1
#define X 0
#define Y 1
#define Z 2

// Vanilla Cvars
new Handle:hCvarHunterCommittedAttackRange;
new Handle:hCvarHunterPounceReadyRange;
new Handle:hCvarHunterLeapAwayGiveUpRange; 
new Handle:hCvarHunterPounceMaxLoftAngle; 
new Handle:hCvarLungeInterval; 
// Gaussian random number generator for pounce angles
new Handle:hCvarPounceAngleMean;
new Handle:hCvarPounceAngleStd; // standard deviation
// Pounce vertical angle
new Handle:hCvarPounceVerticalAngle;
// Distance at which hunter begins pouncing fast
new Handle:hCvarFastPounceProximity; 
// Distance at which hunter considers pouncing straight
new Handle:hCvarStraightPounceProximity;
// Aim offset(degrees) sensitivity
new Handle:hCvarAimOffsetSensitivityHunter;
// Wall detection
new Handle:hCvarWallDetectionDistance;

new bool:bHasQueuedLunge[MAXPLAYERS];
new bool:bCanLunge[MAXPLAYERS];

public Hunter_OnModuleStart() {
	// Set aggressive hunter cvars		
	hCvarHunterCommittedAttackRange = FindConVar("hunter_committed_attack_range"); // range at which hunter is committed to attack	
	hCvarHunterPounceReadyRange = FindConVar("hunter_pounce_ready_range"); // range at which hunter prepares pounce	
	hCvarHunterLeapAwayGiveUpRange = FindConVar("hunter_leap_away_give_up_range"); // range at which shooting a non-committed hunter will cause it to leap away	
	hCvarLungeInterval = FindConVar("z_lunge_interval"); // cooldown on lunges
	hCvarHunterPounceMaxLoftAngle = FindConVar("hunter_pounce_max_loft_angle"); // maximum vertical angle hunters can pounce
	SetConVarInt(hCvarHunterCommittedAttackRange, 10000);
	SetConVarInt(hCvarHunterPounceReadyRange, 500);
	SetConVarInt(hCvarHunterLeapAwayGiveUpRange, 0); 
	SetConVarInt(hCvarHunterPounceMaxLoftAngle, 0);
	
	// proximity to nearest survivor when plugin starts to force hunters to lunge ASAP
	hCvarFastPounceProximity = CreateConVar("ai_fast_pounce_proximity", "1000", "At what distance to start pouncing fast");
	
	// Verticality
	hCvarPounceVerticalAngle = CreateConVar("ai_pounce_vertical_angle", "7", "Vertical angle to which AI hunter pounces will be restricted");
	
	// Pounce angle
	hCvarPounceAngleMean = CreateConVar( "ai_pounce_angle_mean", "10", "Mean angle produced by Gaussian RNG" );
	hCvarPounceAngleStd = CreateConVar( "ai_pounce_angle_std", "20", "One standard deviation from mean as produced by Gaussian RNG" );
	hCvarStraightPounceProximity = CreateConVar( "ai_straight_pounce_proximity", "200", "Distance to nearest survivor at which hunter will consider pouncing straight");
	
	// Aim offset sensitivity
	hCvarAimOffsetSensitivityHunter = CreateConVar("ai_aim_offset_sensitivity_hunter",
									"30",
									"If the hunter has a target, it will not straight pounce if the target's aim on the horizontal axis is within this radius",
									FCVAR_NONE,
									true, 0.0, true, 179.0 );
	// How far in front of hunter to check for a wall
	hCvarWallDetectionDistance = CreateConVar("ai_wall_detection_distance", "-1", "How far in front of himself infected bot will check for a wall. Use '-1' to disable feature");
	
	SetConVarInt(FindConVar("z_pounce_damage_interrupt"), 150);
}

public Hunter_OnModuleEnd() {
	// Reset aggressive hunter cvars
	ResetConVar(hCvarHunterCommittedAttackRange);
	ResetConVar(hCvarHunterPounceReadyRange);
	ResetConVar(hCvarHunterLeapAwayGiveUpRange);
	ResetConVar(hCvarHunterPounceMaxLoftAngle);
	
	ResetConVar(FindConVar("z_pounce_damage_interrupt"));
}

public Action:Hunter_OnSpawn(botHunter) {
	bHasQueuedLunge[botHunter] = false;
	bCanLunge[botHunter] = true;
	return Plugin_Handled;
}

/***********************************************************************************************************************************************************************************

																		FAST POUNCING

***********************************************************************************************************************************************************************************/

public Action:Hunter_OnPlayerRunCmd(hunter, &buttons, &impulse, Float:vel[3], Float:eyeAngles[3], &weapon) {	
	buttons &= ~IN_ATTACK2; // block scratches
	new flags = GetEntityFlags(hunter);
	//Proceed if the hunter is in a position to pounce
	if( (flags & FL_DUCKING) && (flags & FL_ONGROUND) ) {		
		new Float:hunterPos[3];
		GetClientAbsOrigin(hunter, hunterPos);	
		if(GetRandomSurvivor() == -1) return Plugin_Continue;	
		new iSurvivorsProximity = GetSurvivorProximity(hunterPos);
		new bool:bHasLOS = bool:GetEntProp(hunter, Prop_Send, "m_hasVisibleThreats"); // Line of sight to survivors		
		// Start fast pouncing if close enough to survivors
		if( bHasLOS ) {
			if( iSurvivorsProximity < GetConVarInt(hCvarFastPounceProximity) ) {
				buttons &= ~IN_ATTACK; // release attack button; precautionary					
				// Queue a pounce/lunge
				if (!bHasQueuedLunge[hunter]) { // check lunge interval timer has not already been initiated
					bCanLunge[hunter] = false;
					bHasQueuedLunge[hunter] = true; // block duplicate lunge interval timers
					CreateTimer(GetConVarFloat(hCvarLungeInterval), Timer_LungeInterval, any:hunter, TIMER_FLAG_NO_MAPCHANGE);
				} else if (bCanLunge[hunter]) { // end of lunge interval; lunge!
					buttons |= IN_ATTACK;
					bHasQueuedLunge[hunter] = false; // unblock lunge interval timer
				} // else lunge queue is being processed
			}
		} 	
	} 	
	return Plugin_Changed;
}

/***********************************************************************************************************************************************************************************

																	POUNCING AT AN ANGLE TO SURVIVORS

***********************************************************************************************************************************************************************************/

public Action:Hunter_OnPounce(botHunter) {

	if(GetRandomSurvivor() == -1) return Plugin_Continue;
	
	new entLunge = GetEntPropEnt(botHunter, Prop_Send, "m_customAbility"); // get the hunter's lunge entity				
	new Float:lungeVector[3]; 
	GetEntPropVector(entLunge, Prop_Send, "m_queuedLunge", lungeVector); // get the vector from the lunge entity
	
	// Avoid pouncing straight forward if there is a wall close in front
	new Float:hunterPos[3];
	new Float:hunterAngle[3];
	GetClientAbsOrigin(botHunter, hunterPos);
	GetClientEyeAngles(botHunter, hunterAngle); 
	// Fire traceray in front of hunter 
	TR_TraceRayFilter( hunterPos, hunterAngle, MASK_PLAYERSOLID, RayType_Infinite, TracerayFilter, botHunter );
	new Float:impactPos[3];
	TR_GetEndPosition( impactPos );
	// Check first object hit
	if( GetVectorDistance(hunterPos, impactPos) < GetConVarInt(hCvarWallDetectionDistance) ) { // wall detected in front
		if( GetRandomInt(0, 1) ) { // 50% chance left or right
			AngleLunge( entLunge, 45.0 );
		} else {
			AngleLunge( entLunge, 315.0 );
		}
		
			#if DEBUG_HUNTER_AIM
				PrintToChatAll("Pouncing sideways to avoid wall");
			#endif
		
	} else {
		// Angle pounce if survivor is watching the hunter approach
		GetClientAbsOrigin(botHunter, hunterPos);		
		if( IsTargetWatchingAttacker(botHunter, GetConVarInt(hCvarAimOffsetSensitivityHunter)) && GetSurvivorProximity(hunterPos) > GetConVarInt(hCvarStraightPounceProximity) ) {			
			new Float:pounceAngle = GaussianRNG( float(GetConVarInt(hCvarPounceAngleMean)), float(GetConVarInt(hCvarPounceAngleStd)) );
			AngleLunge( entLunge, pounceAngle );
			LimitLungeVerticality( entLunge );
			
				#if DEBUG_HUNTER_AIM
					new target = GetClientAimTarget(botHunter);
					if( IsSurvivor(target) ) {
						new String:targetName[32];
						GetClientName(target, targetName, sizeof(targetName));
						PrintToChatAll("The aim of hunter's target(%s) is %f degrees off", targetName, GetPlayerAimOffset(target, botHunter));
						PrintToChatAll("Angling pounce to throw off survivor");
					} 
					
				#endif
	
			return Plugin_Changed;					
		}	
	}
	return Plugin_Continue;
}

public bool:TracerayFilter( impactEntity, contentMask, any:rayOriginEntity ) {
	return impactEntity != rayOriginEntity;
}
// Credits to High Cookie and Standalone for working out the math behind hunter lunges
AngleLunge( lungeEntity, Float:turnAngle ) {	
	// Get the original lunge's vector
	new Float:lungeVector[3];
	GetEntPropVector(lungeEntity, Prop_Send, "m_queuedLunge", lungeVector);
	new Float:x = lungeVector[X];
	new Float:y = lungeVector[Y];
	new Float:z = lungeVector[Z];
    
    // Create a new vector of the desired angle from the original
	turnAngle = DegToRad(turnAngle); // convert angle to radian form
	new Float:forcedLunge[3];
	forcedLunge[X] = x * Cosine(turnAngle) - y * Sine(turnAngle); 
	forcedLunge[Y] = x * Sine(turnAngle)   + y * Cosine(turnAngle);
	forcedLunge[Z] = z;
	
	SetEntPropVector(lungeEntity, Prop_Send, "m_queuedLunge", forcedLunge);	
}

// Stop pounces being too high
LimitLungeVerticality( lungeEntity ) {
	// Get vertical angle restriction
	new Float:vertAngle = float(GetConVarInt(hCvarPounceVerticalAngle));
	// Get the original lunge's vector
	new Float:lungeVector[3];
	GetEntPropVector(lungeEntity, Prop_Send, "m_queuedLunge", lungeVector);
	new Float:x = lungeVector[X];
	new Float:y = lungeVector[Y];
	new Float:z = lungeVector[Z];
	
	vertAngle = DegToRad(vertAngle);	
	new Float:flatLunge[3];
	// First rotation
	flatLunge[Y] = y * Cosine(vertAngle) - z * Sine(vertAngle);
	flatLunge[Z] = y * Sine(vertAngle) + z * Cosine(vertAngle);
	// Second rotation
	flatLunge[X] = x * Cosine(vertAngle) + z * Sine(vertAngle);
	flatLunge[Z] = x * -Sine(vertAngle) + z * Cosine(vertAngle);
	
	SetEntPropVector(lungeEntity, Prop_Send, "m_queuedLunge", flatLunge);
}

/** 
 * Thanks to Newteee:
 * Random number generator fit to a bellcurve. Function to generate Gaussian Random Number fit to a bellcurve with a specified mean and std
 * Uses Polar Form of the Box-Muller transformation
*/
Float:GaussianRNG( Float:mean, Float:std ) {	 	
	// Randomising positive/negative
	new Float:chanceToken = GetRandomFloat( 0.0, 1.0 );
	new signBit;	
	if( chanceToken >= 0.5 ) {
		signBit = POSITIVE;
	} else {
		signBit = NEGATIVE;
	}	   
	
	new Float:x1;
	new Float:x2;
	new Float:w;
	// Box-Muller algorithm
	do {
	    // Generate random number
	    new Float:random1 = GetRandomFloat( 0.0, 1.0 );	// Random number between 0 and 1
	    new Float:random2 = GetRandomFloat( 0.0, 1.0 );	// Random number between 0 and 1
	 
	    x1 = (2.0 * random1) - 1.0;
	    x2 = (2.0 * random2) - 1.0;
	    w = (x1 * x1) + (x2 * x2);
	 
	} while( w >= 1.0 );	 
	static Float:e = 2.71828;
	w = SquareRoot( ( -2.0 * (Logarithm(w, e) / w ) )  ); 

	// Random normal variable
	new Float:y1 = (x1 * w);
	new Float:y2 = (x2 * w);
	 
	// Random gaussian variable with std and mean
	new Float:z1 = (y1 * std) + mean;
	new Float:z2 = (y2 * std) - mean;
	
	#if DEBUG_HUNTER_RNG	
		if( signBit == NEGATIVE )PrintToChatAll("Angle: %f", z1);
		else PrintToChatAll("Angle: %f", z2);
	#endif
	
	// Output z1 or z2 depending on sign
	if( signBit == NEGATIVE )return z1;
	else return z2;
}

// After the given interval, hunter is allowed to pounce/lunge
public Action:Timer_LungeInterval(Handle:timer, any:client) {
	bCanLunge[client] = true;
}