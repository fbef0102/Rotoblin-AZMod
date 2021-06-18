#pragma semicolon 1

#define BoostForward 60.0 // Bhop

// Velocity
enum VelocityOverride {
	VelocityOvr_None = 0,
	VelocityOvr_Velocity,
	VelocityOvr_OnlyWhenNegative,
	VelocityOvr_InvertReuseVelocity
};

new Handle:hCvarTankBhop;
new Handle:hCvarTankRock;

// Bibliography: 
// TGMaster, Chanz - Infinite Jumping

public Tank_OnModuleStart() {
	hCvarTankBhop = CreateConVar("ai_tank_bhop", "1", "Flag to enable bhop facsimile on AI tanks");
	hCvarTankRock = CreateConVar("ai_tank_rock", "1", "Flag to enable rocks on AI tanks");
	
}

public Tank_OnModuleEnd() {
}

// Tank bhop and blocking rock throw
public Action:Tank_OnPlayerRunCmd( tank, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon ) {
	// block rock throws
	if( !(bool:GetConVarBool(hCvarTankRock)) ) {
		buttons &= ~IN_ATTACK2;
	}
	
	if( bool:GetConVarBool(hCvarTankBhop) ) {
		new flags = GetEntityFlags(tank);
		
		// Get the player velocity:
		new Float:fVelocity[3];
		GetEntPropVector(tank, Prop_Data, "m_vecVelocity", fVelocity);
		new Float:currentspeed = SquareRoot(Pow(fVelocity[0],2.0)+Pow(fVelocity[1],2.0));
		//PrintCenterTextAll("Tank Speed: %.1f", currentspeed);
		
		// Get Angle of Tank
		decl Float:clientEyeAngles[3];
		GetClientEyeAngles(tank,clientEyeAngles);
		
		// LOS and survivor proximity
		new Float:tankPos[3];
		GetClientAbsOrigin(tank, tankPos);
		
		if(GetRandomSurvivor() == -1) return Plugin_Continue;	
		
		new iSurvivorsProximity = GetSurvivorProximity(tankPos);
		new bool:bHasSight = bool:GetEntProp(tank, Prop_Send, "m_hasVisibleThreats"); //Line of sight to survivors
		
		// Near survivors
		if( bHasSight && (400 > iSurvivorsProximity > 100) && currentspeed > 190.0 ) { // Random number to make bhop?
			if( !GetConVarBool(hCvarTankBhop) ) {
				buttons &= ~IN_ATTACK2;	
			} // Block throwing rock
			if (flags & FL_ONGROUND) {
				buttons |= IN_DUCK;
				buttons |= IN_JUMP;
				
				if(buttons & IN_FORWARD) {
					Client_Push( tank, clientEyeAngles, BoostForward, VelocityOverride:{VelocityOvr_None,VelocityOvr_None,VelocityOvr_None} );
				}	
				
				if(buttons & IN_BACK) {
					clientEyeAngles[1] += 180.0;
					Client_Push( tank, clientEyeAngles, BoostForward, VelocityOverride:{VelocityOvr_None,VelocityOvr_None,VelocityOvr_None} );
				}
						
				if(buttons & IN_MOVELEFT) {
					clientEyeAngles[1] += 90.0;
					Client_Push( tank, clientEyeAngles, BoostForward, VelocityOverride:{VelocityOvr_None,VelocityOvr_None,VelocityOvr_None} );
				}
						
				if(buttons & IN_MOVERIGHT) {
					clientEyeAngles[1] += -90.0;
					Client_Push( tank, clientEyeAngles, BoostForward, VelocityOverride:{VelocityOvr_None,VelocityOvr_None,VelocityOvr_None} );
				}
			}
			//Block Jumping and Crouching when on ladder
			if (GetEntityMoveType(tank) & MOVETYPE_LADDER) {
				buttons &= ~IN_JUMP;
				buttons &= ~IN_DUCK;
			}
		}
	}
	return Plugin_Continue;	
}

stock Client_Push(client, Float:clientEyeAngle[3], Float:power, VelocityOverride:override[3]=VelocityOvr_None) {
	decl Float:forwardVector[3],
	Float:newVel[3];
	
	GetAngleVectors(clientEyeAngle, forwardVector, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(forwardVector, forwardVector);
	ScaleVector(forwardVector, power);
	//PrintToChatAll("Tank velocity: %.2f", forwardVector[1]);
	
	Entity_GetAbsVelocity(client,newVel);
	
	for( new i = 0; i < 3; i++ ) {
		switch( override[i] ) {
			case VelocityOvr_Velocity: {
				newVel[i] = 0.0;
			}
			case VelocityOvr_OnlyWhenNegative: {				
				if( newVel[i] < 0.0 ) {
					newVel[i] = 0.0;
				}
			}
			case VelocityOvr_InvertReuseVelocity: {				
				if( newVel[i] < 0.0 ) {
					newVel[i] *= -1.0;
				}
			}
		}
		
		newVel[i] += forwardVector[i];
	}
	
	Entity_SetAbsVelocity(client,newVel);
}

public Action:L4D2_OnSelectTankAttack(client, &sequence) {
	if (IsFakeClient(client) && sequence == 50) {
		sequence = GetRandomInt(0, 1) ? 49 : 51;
		return Plugin_Handled;
	}
	return Plugin_Changed;
}