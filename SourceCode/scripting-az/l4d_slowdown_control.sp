/*
	SourcePawn is Copyright (C) 2006-2015 AlliedModders LLC.  All rights reserved.
	SourceMod is Copyright (C) 2006-2015 AlliedModders LLC.  All rights reserved.
	Pawn and SMALL are Copyright (C) 1997-2015 ITB CompuPhase.
	Source is Copyright (C) Valve Corporation.
	All trademarks are property of their respective owners.

	This program is free software: you can redistribute it and/or modify it
	under the terms of the GNU General Public License as published by the
	Free Software Foundation, either version 3 of the License, or (at your
	option) any later version.

	This program is distributed in the hope that it will be useful, but
	WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
	General Public License for more details.

	You should have received a copy of the GNU General Public License along
	with this program.  If not, see <http://www.gnu.org/licenses/>.
*/
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <multicolors>

/*survivor_limp_health: 40, survivor_limp_run_speed: 150, survivor_limp_walk_speed: 85*/
/*survivor Run speed: 220, survivor Walk speed: 85, survivor Crouch speed: 75*/
/*z_tank_speed_vs: 210, z_tank_speed: 210, z_tank_walk_speed: 100*/
#define SURVIVOR_RUNSPEED		220.0
#define SURVIVOR_WALKSPEED		85.0
#define SURVIVOR_CROUCHSPEED	75.0

/*In l4d2 official versus mode, water speed: 170, deep water speed: 136*/
#define SURVIVOR_WATERSPEED_VS_L4D2	170.0
#define SURVIVOR_DEEP_WATERSPEED_VS_L4D2 136.0

#define TEAM_SURVIVORS 2
#define TEAM_INFECTED 3
#define Z_TANK 5

ConVar
	hCvarSdPistolMod,
	hCvarSdUziMod,
	hCvarSdM4Mod,
	hCvarSdPumpMod,
	hCvarSdAutoMod,
	hCvarSdRifleMod,
	hCvarSdGunfireSi,
	hCvarSdGunfireTank,
	hCvarSdInwaterTankRun,
	hCvarSdInwaterSurvivorRun,
	hCvarSdInwaterSurvivorRunDuringTank,
	hCvarSurvivorLimpHealth,
	hCvarSurvivorLimpRunSpeed,
	hCvarCrouchSpeedMod,
	hCvarCrouchSpeedModGhost;

float
	fTankWaterRunSpeed,
	fSurvWaterRunSpeed,
	fSurvWaterRunSpeedDuringTank,
	fCrouchSpeedMod,
	fCvarCrouchSpeedModGhost,
	fCvarSurvivorLimpRunSpeed;

int iCvarSurvivorLimpHealth;

bool
	tankInPlay = false,
	g_bWaterSlowDownMap = false,
	g_bIsFirstTank = false,
	bFoundCrouchTrigger = false;

ArrayStack
	g_asPlayerInCrouchTrigger[MAXPLAYERS + 1];

int g_iRoundStart, g_iPlayerSpawn;

public Plugin myinfo =
{
	name = "L4D1 Slowdown Control",
	author = "Visor, Sir, darkid, Forgetest, A1m`, Derpduck, HarryPotter",
	version = "2.8.1",
	description = "Manages the water/gunfire slowdown for both teams",
	url = "https://github.com/SirPlease/L4D2-Competitive-Rework"
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

static KeyValues g_hMIData = null;

public void OnPluginStart()
{
	LoadTranslations("Roto2-AZ_mod.phrases");
	
	hCvarSdGunfireSi = CreateConVar("l4d_slowdown_gunfire_si", "0.0", "Maximum slowdown from gunfire for SI (-1: don't modify slowdown; 0.0: No slowdown, 0.01-1.0: 1%%-100%% slowdown)", _, true, -1.0, true, 1.0);
	hCvarSdGunfireTank = CreateConVar("l4d_slowdown_gunfire_tank", "0.0", "Maximum slowdown from gunfire for the Tank (-1: don't modify slowdown; 0.0: No slowdown, 0.01-1.0: 1%%-100%% slowdown)", _, true, -1.0, true, 1.0);
	hCvarSdInwaterTankRun = CreateConVar("l4d_slowdown_water_tank_run", "0", "Maximum tank Run speed in the water (0: don't modify speed; 210: default Tank Speed)", _, true, 0.0);
	hCvarSdInwaterSurvivorRun = CreateConVar("l4d_slowdown_water_survivors_run", "170", "Maximum survivor Run speed in the water outside of Tank fights (0: don't modify speed; 220: default Survivor speed)", _, true, 0.0);
	hCvarSdInwaterSurvivorRunDuringTank = CreateConVar("l4d_slowdown_water_survivors_run_during_tank", "220", "Maximum survivor Run speed in the water during Tank fights (0: don't modify speed; 220: default Survivor speed)", _, true, 0.0);
	hCvarCrouchSpeedMod = CreateConVar("l4d2_slowdown_crouch_speed_mod", "1.4", "Modifier of survivor and infected player crouch speed when inside a designated trigger, 75 is the defualt for everyone (1: default speed)", _, true, 0.0);
	hCvarCrouchSpeedModGhost = CreateConVar("l4d2_slowdown_crouch_speed_mod_ghost", "3.0", "Modifier of ghost infected player crouch speed when inside a designated trigger, 75 is the defualt (1: default speed)", _, true, 0.0);

	hCvarSdPistolMod = CreateConVar("l4d_slowdown_pistol_percent", "0.0", "Pistols cause this much slowdown * l4d_slowdown_gunfire at maximum damage.");
	hCvarSdUziMod = CreateConVar("l4d_slowdown_uzi_percent", "0.8", "Unsilenced uzis cause this much slowdown * l4d_slowdown_gunfire at maximum damage.");
	hCvarSdM4Mod = CreateConVar("l4d_slowdown_m4_percent", "0.8", "M4s cause this much slowdown * l4d_slowdown_gunfire at maximum damage.");
	hCvarSdPumpMod = CreateConVar("l4d_slowdown_pump_percent", "0.5", "Pump Shotguns cause this much slowdown * l4d_slowdown_gunfire at maximum damage.");
	hCvarSdAutoMod = CreateConVar("l4d_slowdown_auto_percent", "0.5", "Auto Shotguns cause this much slowdown * l4d_slowdown_gunfire at maximum damage.");
	hCvarSdRifleMod = CreateConVar("l4d_slowdown_rifle_percent", "0.1", "Hunting Rifles cause this much slowdown * l4d_slowdown_gunfire at maximum damage.");


	hCvarSdInwaterTankRun.AddChangeHook(OnConVarChanged);
	hCvarSdInwaterSurvivorRun.AddChangeHook(OnConVarChanged);
	hCvarSdInwaterSurvivorRunDuringTank.AddChangeHook(OnConVarChanged);
	hCvarCrouchSpeedMod.AddChangeHook(OnConVarChanged);
	hCvarCrouchSpeedModGhost.AddChangeHook(OnConVarChanged);

	hCvarSurvivorLimpHealth = FindConVar("survivor_limp_health");
	hCvarSurvivorLimpRunSpeed = FindConVar("survivor_limp_run_speed");
	hCvarSurvivorLimpHealth.AddChangeHook(OnConVarChanged);
	hCvarSurvivorLimpRunSpeed.AddChangeHook(OnConVarChanged);

	HookEvent("tank_spawn", TankSpawn, EventHookMode_PostNoCopy);
	HookEvent("round_start", RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_hurt", PlayerHurt);
	HookEvent("player_death", TankDeath);

	HookEvent("round_end",				Event_RoundEnd,		EventHookMode_PostNoCopy); //trigger twice in versus mode, one when all survivors wipe out or make it to saferom, one when first round ends (second round_start begins).
	HookEvent("map_transition", 		Event_RoundEnd,		EventHookMode_PostNoCopy); //all survivors make it to saferoom, and server is about to change next level in coop mode (does not trigger round_end) 
	HookEvent("mission_lost", 			Event_RoundEnd,		EventHookMode_PostNoCopy); //all survivors wipe out in coop mode (also triggers round_end)
	HookEvent("finale_vehicle_leaving", Event_RoundEnd,		EventHookMode_PostNoCopy); //final map final rescue vehicle leaving  (does not trigger round_end)


	MI_KV_Load();
}

public void OnPluginEnd()
{
	MI_KV_Close();

	ClearDefault();
}

public void OnMapStart()
{
	g_bWaterSlowDownMap = false;

	char sMap[32];
	GetCurrentMap(sMap, sizeof(sMap));

	MI_KV_Close();
	MI_KV_Load();

	if(g_hMIData.JumpToKey("default"))
	{
		g_bWaterSlowDownMap = view_as<bool>(g_hMIData.GetNum("WaterSlowDown_map", g_bWaterSlowDownMap));

		g_hMIData.GoBack();
	}

	if (g_hMIData.JumpToKey(sMap)) 
	{
		g_bWaterSlowDownMap = view_as<bool>(g_hMIData.GetNum("WaterSlowDown_map", g_bWaterSlowDownMap));

		g_hMIData.GoBack();
	}

	delete g_hMIData;
}

public void OnMapEnd()
{
    ClearDefault();
}

public void OnConfigsExecuted()
{
	CvarsToType();
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	CvarsToType();
}

void CvarsToType()
{
	fTankWaterRunSpeed = hCvarSdInwaterTankRun.FloatValue;
	fSurvWaterRunSpeed = hCvarSdInwaterSurvivorRun.FloatValue;
	fSurvWaterRunSpeedDuringTank = hCvarSdInwaterSurvivorRunDuringTank.FloatValue;
	fCrouchSpeedMod = hCvarCrouchSpeedMod.FloatValue;
	fCvarCrouchSpeedModGhost = hCvarCrouchSpeedModGhost.FloatValue;
	
	iCvarSurvivorLimpHealth = hCvarSurvivorLimpHealth.IntValue;
	fCvarSurvivorLimpRunSpeed = hCvarSurvivorLimpRunSpeed.FloatValue;
}

public void TankSpawn(Event event, const char[] name, bool dontBroadcast) 
{
	if (!tankInPlay && g_bWaterSlowDownMap) {
		tankInPlay = true;
		if (fSurvWaterRunSpeedDuringTank > 0.0 && g_bIsFirstTank) {
			CPrintToChatAll("%t", "l4d_slowdown_control_1");
		}
	}
}

public void TankDeath(Event event, const char[] name, bool dontBroadcast)
{
	if(!g_bWaterSlowDownMap) return;
	
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client > 0 && IsInfected(client) && IsTank(client)) {
		CreateTimer(0.1, Timer_CheckTank);
	}
}

public Action Timer_CheckTank(Handle timer)
{
	int tankclient = FindTankClient();
	if (!tankclient || !IsPlayerAlive(tankclient)) {
		tankInPlay = false;
		if (fSurvWaterRunSpeedDuringTank > 0.0 && g_bIsFirstTank) {
			CPrintToChatAll("%t", "l4d_slowdown_control_2");
			g_bIsFirstTank = false;
		}
	}

	return Plugin_Continue;
}

public void RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_bIsFirstTank = true;
	tankInPlay = false;

	if( g_iPlayerSpawn == 1 && g_iRoundStart == 0 )
		CreateTimer(0.5, Timer_PluginStart);
	g_iRoundStart = 1;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{ 
    if( g_iPlayerSpawn == 0 && g_iRoundStart == 1 )
        CreateTimer(0.5, Timer_PluginStart);
    g_iPlayerSpawn = 1;	
}

Action Timer_PluginStart(Handle timer)
{
	ClearDefault();

	HookCrouchTriggers();

	return Plugin_Continue;
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) 
{
	ClearDefault();
}

void HookCrouchTriggers()
{
	bFoundCrouchTrigger = false;
	
	// Hook trigger_multiple entities that are named "l4d2_slowdown_crouch_speed"
	if (fCrouchSpeedMod != 1.0 || fCvarCrouchSpeedModGhost != 1.0) {
		// Reset array
		for (int i = 1; i <= MaxClients; i++) {
			delete g_asPlayerInCrouchTrigger[i];
			g_asPlayerInCrouchTrigger[i] = new ArrayStack();
		}
		
		int iEntity = -1;
		char targetname[64];
		
		while ((iEntity = FindEntityByClassname(iEntity, "trigger_multiple")) != -1) {
			GetEntPropString(iEntity, Prop_Data, "m_iName", targetname, sizeof(targetname));
			
			if (strncmp(targetname, "l4d_slowdown_crouch_speed", 25, false) == 0) {
				HookSingleEntityOutput(iEntity, "OnStartTouch", CrouchSpeedStartTouch);
				HookSingleEntityOutput(iEntity, "OnEndTouch", CrouchSpeedEndTouch);

				bFoundCrouchTrigger = true;
			}
		}
	}
}

void CrouchSpeedStartTouch(const char[] output, int caller, int activator, float delay)
{
	if (0 < activator <= MaxClients && IsClientInGame(activator)) {
		g_asPlayerInCrouchTrigger[activator].Push(true);
	}
}

void CrouchSpeedEndTouch(const char[] output, int caller, int activator, float delay)
{
	if (0 < activator <= MaxClients && IsClientInGame(activator)) {
		g_asPlayerInCrouchTrigger[activator].Pop();
	}
}

/**
 *
 * Slowdown from gunfire: Tank & SI
 *
**/
public void PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client > 0 && IsInfected(client)) {
		float slowdown = IsTank(client) ? GetActualValue(hCvarSdGunfireTank) : GetActualValue(hCvarSdGunfireSi);
		if (slowdown == 1.0) {
			ApplySlowdown(client, slowdown);
		} else if (slowdown > 0.0) {
			int damage = GetEventInt(event, "dmg_health");
			char weapon[64];
			GetEventString(event, "weapon", weapon, sizeof(weapon));

			float scale;
			float modifier;
			GetScaleAndModifier(scale, modifier, weapon, damage);
			ApplySlowdown(client, 1 - modifier * scale * slowdown);
		}
	}
}

/**
 *
 * Slowdown from water: Tank & Survivors
 *
**/
public Action L4D_OnGetRunTopSpeed(int client, float &retVal)
{
	if (!IsClientInGame(client) || !g_bWaterSlowDownMap) { 
		return Plugin_Continue;
	}
	
	switch (GetClientTeam(client)) {
		case TEAM_SURVIVORS: {
			// Tongue victim, simulates game logics here.
			if (GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0) {
				return Plugin_Continue;
			}
			
			// Only bother if survivor is in water
			if (GetEntityFlags(client) & FL_INWATER) {
				//int iWaterLevel = GetEntProp(client, Prop_Send, "m_nWaterLevel"); // 0: no water, 1: a little, 2: half body, 3: full body under water ( when iWaterLevel >=2, water speed = movement speed * 0.8)
				//PrintToChatAll("iWaterLevel: %d, retVal: %.2f", iWaterLevel, retVal); // 0: no water, 1: a little, 2: half body, 3: full body under water
				if (tankInPlay) { // speed of survivors in water during Tank fights
					if (fSurvWaterRunSpeedDuringTank == 0.0) {
						return Plugin_Continue; // Vanilla YEEEEEEEEEEEEEEEs
					} else {
						if(IsLimping(client) && fCvarSurvivorLimpRunSpeed < fSurvWaterRunSpeedDuringTank) { // not healthy
							return Plugin_Continue;
						}
 
						retVal = fSurvWaterRunSpeedDuringTank;
						
						return Plugin_Handled;
					}
				} else { // speed of survivors in water outside of Tank fights
					if (fSurvWaterRunSpeed == 0.0) {
						return Plugin_Continue; // Vanilla YEEEEEEEEEEEEEEEs
					} else { // specific speed
						if(IsLimping(client) && fCvarSurvivorLimpRunSpeed < fSurvWaterRunSpeed) { // not healthy
							return Plugin_Continue;
						}
					
						retVal = fSurvWaterRunSpeed - 5.0; // water speed = movement speed + 5.0

						return Plugin_Handled;
					}
				}
			}
		}
		case TEAM_INFECTED: {
			if (IsTank(client)) {
				// Only bother the actual speed if player is a tank moving in water
				if (GetEntityFlags(client) & FL_INWATER && fTankWaterRunSpeed > 0.0) {
					retVal = fTankWaterRunSpeed;
					return Plugin_Handled;
				}
			}
		}
	}
	
	return Plugin_Continue;
}

/**
 *
 * Slowdown from crouching: All players
 *
**/
public Action L4D_OnGetCrouchTopSpeed(int client, float &retVal)
{
	if ( (fCrouchSpeedMod == 1.0 && fCvarCrouchSpeedModGhost == 1.0) || !bFoundCrouchTrigger || !IsClientInGame(client)) {
		return Plugin_Continue;
	}
	
	if (IsPlayerInCrouchTrigger(client)) 
	{
		bool bCrouched = (GetEntityFlags(client) & FL_DUCKING && GetEntityFlags(client) & FL_ONGROUND) ? true : false;
		
		if (bCrouched) 
		{
			if(L4D_IsPlayerGhost(client)) retVal = retVal * fCvarCrouchSpeedModGhost; // 75 * modifier
			retVal = retVal * fCrouchSpeedMod; // 75 * modifier
			return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}

// The old slowdown plugin's cvars weren't quite intuitive, so I'll try to fix it this time
float GetActualValue(ConVar cvar)
{
	float value = GetConVarFloat(cvar);
	if (value == -1.0) { // native slowdown
		return -1.0;
	}
	
	if (value == 0.0) { // slowdown off
		return 1.0;
	}
	
	return L4D2Util_ClampFloat(value, 0.01, 2.0); // slowdown multiplier
}

void ApplySlowdown(int client, float value)
{
	if (value == -1.0) {
		return;
	}
	
	SetEntPropFloat(client, Prop_Send, "m_flVelocityModifier", value);
}

void GetScaleAndModifier(float &scale, float &modifier, const char[] weapon, int damage)
{
	float fDamage = float(damage);
	if (strcmp(weapon, "melee") == 0) {
		// Melee damage scales with tank health, so don't bother handling it here.
		scale = 1.0;
		modifier = 0.0;
	} else if (strcmp(weapon, "pistol") == 0) {
		scale = fScaleFloat(fDamage, 9.0, 32.0);
		modifier = GetConVarFloat(hCvarSdPistolMod);
	} else if (strcmp(weapon, "smg") == 0) {
		scale = fScaleFloat2(fDamage, 9.0, 19.0);
		modifier = GetConVarFloat(hCvarSdUziMod);
	} else if (strcmp(weapon, "rifle") == 0) {
		scale = fScaleFloat2(fDamage, 0.0, 32.0);
		modifier = GetConVarFloat(hCvarSdM4Mod);
	} else if (strcmp(weapon, "pumpshotgun") == 0) {
		scale = fScaleFloat2(fDamage, 2.0, 13.0);
		modifier = GetConVarFloat(hCvarSdPumpMod);
	} else if (strcmp(weapon, "autoshotgun") == 0) {
		scale = fScaleFloat2(fDamage, 2.0, 19.0);
		modifier = GetConVarFloat(hCvarSdAutoMod);
	} else if (strcmp(weapon, "hunting_rifle") == 0) {
		scale = fScaleFloat(fDamage, 90.0, 90.0);
		modifier = GetConVarFloat(hCvarSdRifleMod);
	} else {
		scale = 1.0;
		modifier = 0.0;
	}
}

int FindTankClient()
{
	for (int i = 1; i <= MaxClients; i++) {
		if (!IsInfected(i) || !IsTank(i) || !IsPlayerAlive(i)) {
			continue;
		}
		
		return i; // Found tank, return
	}
	return 0;
}

bool IsInfected(int client)
{
	return (IsClientInGame(client) && GetClientTeam(client) == TEAM_INFECTED);
}

bool IsTank(int client)
{
	return (GetEntProp(client, Prop_Send, "m_zombieClass") == Z_TANK);
}

bool IsLimping(int client)
{
	// Assume Clientchecks and the like have been done already
	int PermHealth = GetClientHealth(client);

	float buffer = GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
	float bleedTime = GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime");
	float decay = GetConVarFloat(FindConVar("pain_pills_decay_rate"));
	
	float fCalculations = buffer - (bleedTime * decay);
	float TempHealth = L4D2Util_ClampFloat(fCalculations, 0.0, 100.0); // buffer may be negative, also if pills bleed out then bleedTime may be too large.

	return RoundToFloor(PermHealth + TempHealth) < iCvarSurvivorLimpHealth;
}

float fScaleFloat(float inc, float low, float high)
{
	/* @A1m:
	 * This macros has been removed because it is considered unsafe.
	 * Besides, there are problems when assembling in sourcemod 1.11.
	 * The compiler ignores the data type when assembling.
	 *
	 * Linear scale %0 between %1 and %2.
	 * #define SCALE(%0,%1,%2) CLAMP((%0-%1)/(%2-%1), 0.0, 1.0)
	*/
	float fCalculations = ((inc - low) / (high - low));
	return L4D2Util_ClampFloat(fCalculations, 0.0, 1.0);
}

float fScaleFloat2(float inc, float low, float high)
{
	/* @A1m:
	 * This macros has been removed because it is considered unsafe.
	 * Besides, there are problems when assembling in sourcemod 1.11.
	 * The compiler ignores the data type when assembling.
	 *
	 * Quadratic scale %0 between %1 and %2
	* #define SCALE2(%0,%1,%2) SCALE(%0*%0, %1*%1, %2*%2)
	*/
	return fScaleFloat((inc * inc), (low * low), (high * high));
}

stock float L4D2Util_ClampFloat(float inc, float low, float high)
{
	return (inc > high) ? high : ((inc < low) ? low : inc);
}

bool IsPlayerInCrouchTrigger(int client)
{
	if (0 < client <= MaxClients && IsClientInGame(client) && IsPlayerAlive(client)){
		return !g_asPlayerInCrouchTrigger[client].Empty;
	}
	
	return false;
}

void MI_KV_Load()
{
	char sNameBuff[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sNameBuff, 256, "data/%s", "mapinfo.txt");

	g_hMIData = CreateKeyValues("MapInfo");
	if (!FileToKeyValues(g_hMIData, sNameBuff)) {
		//LogError("[MI] Couldn't load MapInfo data!");
		MI_KV_Close();
	}
}

void MI_KV_Close()
{
	if (g_hMIData != null) {
		CloseHandle(g_hMIData);
		g_hMIData = null;
	}
}

void ClearDefault()
{
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
}