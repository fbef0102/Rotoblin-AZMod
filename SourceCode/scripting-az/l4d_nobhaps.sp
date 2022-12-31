#include <sourcemod>
#include <sdktools>

#define DEBUG 0

#define ZC_TANK 5

#define LEFT4FRAMEWORK_GAMEDATA "left4dhooks.l4d1"
#define SECTION_NAME "CTerrorPlayer::GetRunTopSpeed"

public Plugin:myinfo =
{
	name = "Simple Anti-Bunnyhop",
	author = "CanadaRox, ProdigySim, blodia, CircleSquared, robex, HarryPotter",
	description = "Stops bunnyhops by restricting speed when a player lands on the ground to their MaxSpeed",
	version = "0.4",
	url = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

new Handle:hCvarEnable;
new Handle:hCvarSIExcept;
new Handle:hCvarSurvivorExcept;
new Handle:g_hGetRunTopSpeed;

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

public OnPluginStart()
{
	LoadSDK();
	hCvarEnable = CreateConVar("simple_antibhop_enable", "1", "Enable or disable the Simple Anti-Bhop plugin");
	hCvarSIExcept = CreateConVar("bhop_except_si_flags", "4", "Bitfield for exempting SI in anti-bhop functionality. From least significant: 1=Smoker, 2=Boomer, 4=Hunter, 8=Tank, 15=All");
	hCvarSurvivorExcept = CreateConVar("bhop_allow_survivor", "0", "Allow Survivors to bhop while plugin is enabled");
}

void LoadSDK()
{
	Handle hGameData = LoadGameConfigFile(LEFT4FRAMEWORK_GAMEDATA);
	if (hGameData == null) {
		SetFailState("Could not load gamedata/%s.txt", LEFT4FRAMEWORK_GAMEDATA);
	}

	StartPrepSDKCall(SDKCall_Player);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, SECTION_NAME)) {
		SetFailState("Function '%s' not found", SECTION_NAME);
	}
	
	PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_Plain);
	
	g_hGetRunTopSpeed = EndPrepSDKCall();
	if (g_hGetRunTopSpeed == null) {
		SetFailState("Function '%s' found, but something went wrong", SECTION_NAME);
	}
	
	delete hGameData;
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if (!IsValidClient(client))
		return Plugin_Continue;

	static Float:LeftGroundMaxSpeed[MAXPLAYERS + 1];

	if(!GetConVarBool(hCvarEnable))
		return Plugin_Continue;

	if (IsPlayerAlive(client)) {
		if (GetClientTeam(client) == 3) {
			new class = GetEntProp(client, Prop_Send, "m_zombieClass");
			// tank
			if (class == ZC_TANK) {
				--class;
			}
			class--;
			new except = GetConVarInt(hCvarSIExcept);
			if (class >= 0 && class <= 3 && ((1 << class) & except)) {
				// Skipping calculation for This SI based on exception rules
				return Plugin_Continue;
			}
		}
		if (GetClientTeam(client) == 2) {
			if (GetConVarBool(hCvarSurvivorExcept)) {
				return Plugin_Continue;
			}
		}

		new ClientFlags = GetEntityFlags(client);
		if (ClientFlags & FL_ONGROUND) {
			if (LeftGroundMaxSpeed[client] != -1.0) {

				new Float:CurVelVec[3];
				GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", CurVelVec);

				if (GetVectorLength(CurVelVec) > LeftGroundMaxSpeed[client]) {
#if DEBUG
					PrintToChat(client, "Speed: %f {%.02f, %.02f, %.02f}, MaxSpeed: %f", GetVectorLength(CurVelVec), CurVelVec[0], CurVelVec[1], CurVelVec[2], LeftGroundMaxSpeed[client]);
#endif
					NormalizeVector(CurVelVec, CurVelVec);
					ScaleVector(CurVelVec, LeftGroundMaxSpeed[client]);
					TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, CurVelVec);
				}
				LeftGroundMaxSpeed[client] = -1.0;
			}
		} else if (LeftGroundMaxSpeed[client] == -1.0) {
			LeftGroundMaxSpeed[client] = SDKCall(g_hGetRunTopSpeed, client);
		}
	}

	return Plugin_Continue;
} 

stock bool:IsValidClient(client)
{ 
	if (client <= 0 || client > MaxClients || !IsClientConnected(client)) {
		return false; 
	}
	return IsClientInGame(client); 
}