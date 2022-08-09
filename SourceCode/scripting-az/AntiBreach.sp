#include <sourcemod>
#include <sdktools>
#include <multicolors>
#include <left4dhooks> 

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.4.3"

#define MAX(%0,%1) (((%0) > (%1)) ? (%0) : (%1))
#define ABS(%0) (((%0) < 0) ? -(%0) : (%0))

bool NoSpam[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "No spawn near safe room door.",
	author = "Eyal282 ( FuckTheSchool ), Forgetest, HarryPotter",
	description = "To prevent a player breaching safe room door with a bug, prevents him from spawning near safe room door. The minimum distance is proportionate to his speed ",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?p=2520740"
}

ConVar	hAntiBreachConVar;
int		AntiBreachConVar;

// ADT Array is used instead of using a single integer.
// In this way, we secures players from being exploit upon if the end saferoom have multiple doors of entrance, exit etc.
ArrayList aSaferoomDoors;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	
	if( test != Engine_Left4Dead && test != Engine_Left4Dead2 )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}

	return APLRes_Success; 
}

public void OnPluginStart()
{
	LoadTranslations("Roto2-AZ_mod.phrases");
	// The cvar to enable the plugin. 0 = Disabled. Other values = Enabled.
	hAntiBreachConVar = CreateConVar("l4d2_anti_breach", "1", "The cvar to enable the plugin. 0 = Disabled. Other values = Enabled.");
	
	// To prevent waste of resources, hook the change of the console variable AntiBreach
	HookConVarChange(hAntiBreachConVar, AntiBreachConVarChange);
	
	// Save the current value of l4d2_anti_breach in a variable. Main reason is to avoid wasting resources.
	AntiBreachConVar = hAntiBreachConVar.IntValue;
	
	aSaferoomDoors = new ArrayList();

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) 
{
	// Use a delay function to prevent issues
	CreateTimer(12.0, DelayRoundStart, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action DelayRoundStart(Handle timer)
{
	aSaferoomDoors.Clear();

	int entity = L4D_GetCheckpointFirst();
	if(entity != -1) aSaferoomDoors.Push(EntIndexToEntRef(entity));

	entity = L4D_GetCheckpointLast();
	if(entity != -1) aSaferoomDoors.Push(EntIndexToEntRef(entity));

	return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	// Cvar is disabled, aborting.
	if(AntiBreachConVar == 0)
		return Plugin_Continue;

	// Player is not attacking and no safe room door closed.
	if(!(buttons & IN_ATTACK))
		return Plugin_Continue;
	
	// Player is either a bot, not infected or not a ghost.
	if(GetClientTeam(client) != 3 || IsFakeClient(client) || GetEntProp(client, Prop_Send, "m_isGhost") != 1)
		return Plugin_Continue;

	// Being a ghost, the player can not spawn ( seen / close / blocked etc... )
	if(GetEntProp(client, Prop_Send, "m_ghostSpawnState") != 0)
		return Plugin_Continue;
	
	// Loops through all checkpoint doors stored in array
	for (int i = 0; i < aSaferoomDoors.Length; ++i)
	{
		int door = EntRefToEntIndex(aSaferoomDoors.Get(i));
		if ( door <= MaxClients || !IsValidEntity(door) || !IsValidEdict(door)) continue; // probably won't happen
		
		
		/**	https://github.com/ValveSoftware/source-sdk-2013/blob/master/mp/src/game/server/BasePropDoor.h#L80
		 *
		 *	enum DoorState_t
		 *	{
		 *		DOOR_STATE_CLOSED = 0,
		 *		DOOR_STATE_OPENING,
		 *		DOOR_STATE_OPEN,
		 *		DOOR_STATE_CLOSING,
		 *		DOOR_STATE_AJAR,
		 *	};
		 */
		if (GetEntProp(door, Prop_Send, "m_eDoorState") == 0) // DOOR_STATE_CLOSED
		{
			float clientOrigin[3], doorOrigin[3];
			GetEntPropVector(client, Prop_Send, "m_vecOrigin", clientOrigin);
			GetEntPropVector(door, Prop_Send, "m_vecOrigin", doorOrigin);
			
			// Calculates the distance between client and the door
			float fDistance = GetVectorDistance(clientOrigin, doorOrigin);
			
			// Player isn't close enough to the door
			// Go next :)
			// PrintToChatAll("%N %d %.2f",client, door, fDistance);
			if (fDistance > 100.0) continue;
			
			float clientVelocity[3];
			// float clientAngles[3];
			GetEntPropVector(client, Prop_Data, "m_vecVelocity", clientVelocity);
			// GetEntPropVector(client, Prop_Data, "m_angRotation", clientAngles);
			
			// // Angles of moving forward(backward) and rightward(leftward)
			// float vecFwd[3], vecRight[3];
			// GetAngleVectors(clientAngles, vecFwd, vecRight, NULL_VECTOR);
			
			// float clientDist[3], vecAngles[3];
			// SubtractVectors(doorOrigin, clientOrigin, clientDist); // Vector starts at client, ends at door
			// GetVectorAngles(clientDist, vecAngles);
			
			// // Normalization to simplify calculations
			// NormalizeVector(vecAngles, vecAngles);
			// NormalizeVector(vecFwd, vecFwd);
			// NormalizeVector(vecRight, vecRight);
			
			// // cos<v1,v2> = DotProduct(v1, v2) / Length(v1) / Length(v2)
			// // Length of any normalized vector is ~1
			// // Calculates cosine of the angle between the velocity direction and the distance direction
			// float cosine = MAX(ABS(GetVectorDotProduct(vecAngles, vecFwd)), ABS(GetVectorDotProduct(vecAngles, vecRight)));
			
			float fSpeed = GetVectorLength(clientVelocity); // Where client will be in the next frame
	
			// Player is close enough and has too much speed vs distance from door.
			// PrintToChatAll("%N %d * %.2f - %.2f = %.2f ",client, door, fDistance, fSpeed, fSpeed / 1.5);
			if(fDistance < fSpeed / 1.5)
			{
				if(!NoSpam[client])
				{
					// CPrintToChatAll("{red}[{default}Exploit{red}] {olive}%N {default}tried to spawn near end saferoom door{default}.", client);
					CPrintToChat(client, "{default}[{olive}TS{default}] %T","You can't spawn near safe room doors.", client);
					NoSpam[client] = true;
					CreateTimer(2.5, AllowMessageAgain, client);
				}
				buttons &= ~IN_ATTACK;
				return Plugin_Changed;
			}
		}
	}
	
	return Plugin_Continue;
}

public Action AllowMessageAgain(Handle timer, int client)
{
    NoSpam[client] = false;

    return Plugin_Continue;
}

public void OnClientPutInServer(int client)
{
	NoSpam[client] = false;
}

public void AntiBreachConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	AntiBreachConVar = GetConVarInt(convar);
}
