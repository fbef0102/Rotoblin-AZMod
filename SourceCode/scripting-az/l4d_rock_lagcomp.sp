/**
 * ===============================
 * L4D2 Tank Rock Lag Compensation
 * ===============================
 * 
 * This plugin provides lag compensation as well as cvars for weapon 
 * damage & range values on tank rocks.
 * 
 * -------------------------------
 * Lag compensation for tank rocks
 * -------------------------------
 * 
 * The lag compensation is done by keeping track of the position vector history
 * of the tank rock(s) for each previous n frames (defined by MAX_HISTORY_FRAMES). 
 * When a survivor fires his weapon, the client frame is calculated by this formula:
 * 
 * Command Execution Time = Current Server Time - Packet Latency - Client View Interpolation
 *
 * Once the frame number that the client is running at is known, the plugin
 * draws an abstract sphere about the size of the rock at the origin vector
 * of the rock at client frame time. A line-sphere intersection is then calculated 
 * to detect collision. At that point, the weapon damages and ranges come into play.
 *
 * -------------
 * Weapon Damage
 * -------------
 *
 * For a given weapon damage, the damage is equal to the range at which one bullet
 * will kill the rock. For example, a damage of 200 for a gun will kill a rock
 * in one bullet at or below the range of 200 units. Damage is scaled based on
 * distance with this formula:
 *
 * Final Damage = Damage / Distance 
 *
 * ------------
 * Weapon Range
 * ------------
 *
 * The weapon range is set to prevent all damages above a certain range. For
 * example, a range of 2000 on a gun category will mean that this type of gun
 * will do no damage to the rock above 2000 units.
 *
 * -------
 * Credits
 * -------
 * 
 * Author: Luckylock
 * 
 * Contributors: Lux (Windows support)
 *
 * Testers & Feedback: Adam, Impulse, Ohzy, Presto, Elk, Noc
 */

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <multicolors>

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

#define GAMEDATA "rock_lagcomp"

#define MAX_STR_LEN 100
#define MAX_HISTORY_FRAMES 100
#define ROCK_HEALTH 100
#define CURR_GAME_TIME RoundFloat(GetGameTime() * 1000)

#define ROCK_PRINT GetConVarInt(cvarRockPrint)
#define ROCK_HITBOX_ENABLED GetConVarInt(cvarRockHitbox)
#define LAG_COMP_ENABLED GetConVarInt(cvarRockTankLagComp)
#define ROCK_GODFRAMES_TIME RoundFloat(GetConVarFloat(cvarRockGodframes) * 1000)
#define ROCK_GODFRAMES_RENDER GetConVarInt(cvarRockGodframesRender)
#define SPHERE_HITBOX_RADIUS GetConVarFloat(cvarRockHitboxRadius)

#define DAMAGE_MAX_ALL_ float(10000)
#define DAMAGE_PISTOL GetConVarFloat(cvarDamagePistol)
#define DAMAGE_MAGNUM GetConVarFloat(cvarDamageMagnum)
#define DAMAGE_SHOTGUN GetConVarFloat(cvarDamageShotgun)
#define DAMAGE_SMG GetConVarFloat(cvarDamageSmg)
#define DAMAGE_RIFLE GetConVarFloat(cvarDamageRifle)
#define DAMAGE_MELEE GetConVarFloat(cvarDamageMelee)
#define DAMAGE_SNIPER GetConVarFloat(cvarDamageSniper)
#define DAMAGE_MINIGUN GetConVarFloat(cvarDamageMinigun)
#define DAMAGE_MOUNTED_MACHINEGUN GetConVarFloat(cvarDamageMountedMachineGun)

#define RANGE_MAX_ALL_ float(10000)
#define RANGE_MAX_ALL GetConVarFloat(cvarRangeMaxAll)
#define RANGE_MIN_ALL GetConVarFloat(cvarRangeMinAll)
#define RANGE_PISTOL GetConVarFloat(cvarRangePistol)
#define RANGE_MAGNUM GetConVarFloat(cvarRangeMagnum)
#define RANGE_SHOTGUN GetConVarFloat(cvarRangeShotgun)
#define RANGE_SMG GetConVarFloat(cvarRangeSmg)
#define RANGE_RIFLE GetConVarFloat(cvarRangeRifle)
#define RANGE_MELEE GetConVarFloat(cvarRangeMelee)
#define RANGE_SNIPER GetConVarFloat(cvarRangeSniper)
#define RANGE_MINIGUN GetConVarFloat(cvarRangeMinigun)
#define RANGE_MOUNTED_MACHINEGUN GetConVarFloat(cvarRangeMountedMachineGun)

#define BLOCK_ENT_REF 0
#define BLOCK_POS_HISTORY 1
#define BLOCK_DMG_DEALT 2
#define BLOCK_START_TIME 3

ConVar cvarRockPrint;
ConVar cvarRockHitbox;
ConVar cvarRockTankLagComp;
ConVar cvarRockGodframes;
ConVar cvarRockGodframesRender;
ConVar cvarRockHitboxRadius;

ConVar cvarDamagePistol;
//ConVar cvarDamageMagnum;
ConVar cvarDamageShotgun;
ConVar cvarDamageSmg;
ConVar cvarDamageRifle;
//ConVar cvarDamageMelee;
ConVar cvarDamageSniper;
ConVar cvarDamageMinigun;
ConVar cvarDamageMountedMachineGun;

ConVar cvarRangeMinAll;
ConVar cvarRangeMaxAll;
ConVar cvarRangePistol;
//ConVar cvarRangeMagnum;
ConVar cvarRangeShotgun;
ConVar cvarRangeSmg;
ConVar cvarRangeRifle;
//ConVar cvarRangeMelee;
ConVar cvarRangeSniper;
ConVar cvarRangeMinigun;
ConVar cvarRangeMountedMachineGun;
Handle g_SDKCall;

// riverside: announce rock skeets to other plugins. Same name and signature as
// l4d2_skill_detect's forward, so pug-match's existing OnTankRockSkeeted
// handler counts them. skill_detect's own detection never fires here, because
// PreventDamage below zeroes every hit before the rock's health can drop.
GlobalForward g_hForwardRockSkeeted;
int g_iLastSkeetedRock = INVALID_ENT_REFERENCE;

// tick_count of the usercmd each client is running, for the rewind
int g_iCmdTickCount[MAXPLAYERS+1];
ConVar cvarMaxUnlag;
ConVar cvarLagPushTicks;

/**
 * Block BLOCK_ENT_REF: Entity Index
 * Block BLOCK_POS_HISTORY: Array of x,y,z rock positions history where: 
 * (frame number) % MAX_HISTORY_FRAMES == (array index)
 * Block BLOCK_DMG_DEAL: Damage dealt to rock
 * Block BLOCK_START_TIME: Entry time of the rock (for godframes)
 */
ArrayList rockEntitiesArray;

public Plugin myinfo =
{
    name = "L4D1 Tank Rock Lag Compensation",
    author = "Luckylockm, Silvers, Harry, Riverside",
    description = "Provides lag compensation for tank rock entities",
    version = "1.14-2026/9/30",
    url = "https://github.com/LuckyServ/"
};

public void OnPluginStart()
{

	StartPrepSDKCall(SDKCall_Entity);
		
	new Handle:hGamedata = LoadGameConfigFile(GAMEDATA);
	if(hGamedata == INVALID_HANDLE) 
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGamedata, SDKConf_Signature, "CTankRock::Detonate");

	g_SDKCall = EndPrepSDKCall();
	delete hGamedata;

	if (g_SDKCall == INVALID_HANDLE) {
		SetFailState("Could not find signature \"CTankRock::Detonate\".");
	}

	LoadTranslations("Roto2-AZ_mod.phrases");
	g_hForwardRockSkeeted = new GlobalForward("OnTankRockSkeeted", ET_Ignore, Param_Cell, Param_Cell);

	cvarRockPrint = CreateConVar("sm_rock_print", "0", "Toggle printing of rock damage and range values", FCVAR_NONE, true, 0.0, true, 1.0);
	cvarRockHitbox = CreateConVar("sm_rock_hitbox", "1", "Toggle for rock custom hitbox", FCVAR_NONE, true, 0.0, true, 1.0);
	cvarRockTankLagComp = CreateConVar("sm_rock_lagcomp", "1", "Toggle for lag compensation", FCVAR_NONE, true, 0.0, true, 1.0);
	cvarRockGodframes = CreateConVar("sm_rock_godframes", "1.7", "Godframe time for rock (in seconds)", FCVAR_NONE, true, 0.0, true, 10.0);
	cvarRockGodframesRender = CreateConVar("sm_rock_godframes_render", "1", "Toggle visual godframes feedback", FCVAR_NONE, true, 0.0, true, 1.0);
	cvarRockHitboxRadius = CreateConVar("sm_rock_hitbox_radius", "30", "Rock hitbox radius", FCVAR_NONE, true, 0.0, true, 10000.0);

	cvarDamagePistol = CreateConVar("sm_rock_damage_pistol", "75", "Gun category damage", FCVAR_NONE, true, 0.0, true, DAMAGE_MAX_ALL_);
	//cvarDamageMagnum = CreateConVar("sm_rock_damage_magnum", "1000", "Gun category damage", FCVAR_NONE, true, 0.0, true, DAMAGE_MAX_ALL_);
	cvarDamageShotgun = CreateConVar("sm_rock_damage_shotgun", "600", "Gun category damage", FCVAR_NONE, true, 0.0, true, DAMAGE_MAX_ALL_);
	cvarDamageSmg = CreateConVar("sm_rock_damage_smg", "75", "Gun category damage", FCVAR_NONE, true, 0.0, true, DAMAGE_MAX_ALL_);
	cvarDamageRifle = CreateConVar("sm_rock_damage_rifle", "200", "Gun category damage", FCVAR_NONE, true, 0.0, true, DAMAGE_MAX_ALL_);
	//cvarDamageMelee = CreateConVar("sm_rock_damage_melee", "1000", "Gun category damage", FCVAR_NONE, true, 0.0, true, DAMAGE_MAX_ALL_);
	cvarDamageSniper = CreateConVar("sm_rock_damage_sniper", "10000", "Gun category damage", FCVAR_NONE, true, 0.0, true, DAMAGE_MAX_ALL_);
	cvarDamageMinigun = CreateConVar("sm_rock_damage_minigun", "300", "Gun category damage", FCVAR_NONE, true, 0.0, true, DAMAGE_MAX_ALL_);
	cvarDamageMountedMachineGun = CreateConVar("sm_rock_damage_mounted_machinegun", "10000", "Gun category damage", FCVAR_NONE, true, 0.0, true, DAMAGE_MAX_ALL_);

	cvarRangeMinAll = CreateConVar("sm_rock_range_min_all", "1", "Gun category range", FCVAR_NONE, true, 0.0, true, RANGE_MAX_ALL_);
	cvarRangeMaxAll = CreateConVar("sm_rock_range_max_all", "2000", "Gun category range", FCVAR_NONE, true, 0.0, true, RANGE_MAX_ALL_);
	cvarRangePistol = CreateConVar("sm_rock_range_pistol", "2000", "Gun category range", FCVAR_NONE, true, 0.0, true, RANGE_MAX_ALL_);
	//cvarRangeMagnum = CreateConVar("sm_rock_range_magnum", "2000", "Gun category range", FCVAR_NONE, true, 0.0, true, RANGE_MAX_ALL_);
	cvarRangeShotgun = CreateConVar("sm_rock_range_shotgun", "1000", "Gun category range", FCVAR_NONE, true, 0.0, true, RANGE_MAX_ALL_);
	cvarRangeSmg = CreateConVar("sm_rock_range_smg", "2000", "Gun category range", FCVAR_NONE, true, 0.0, true, RANGE_MAX_ALL_);
	cvarRangeRifle = CreateConVar("sm_rock_range_rifle", "2000", "Gun category range", FCVAR_NONE, true, 0.0, true, RANGE_MAX_ALL_);
	//cvarRangeMelee = CreateConVar("sm_rock_range_melee", "200", "Gun category range", FCVAR_NONE, true, 0.0, true, RANGE_MAX_ALL_);
	cvarRangeSniper = CreateConVar("sm_rock_range_sniper", "10000", "Gun category range", FCVAR_NONE, true, 0.0, true, RANGE_MAX_ALL_);
	cvarRangeMinigun = CreateConVar("sm_rock_range_minigun", "2000", "Gun category range", FCVAR_NONE, true, 0.0, true, RANGE_MAX_ALL_);
	cvarRangeMountedMachineGun = CreateConVar("sm_rock_range_mounted_machinegun", "10000", "Gun category range", FCVAR_NONE, true, 0.0, true, RANGE_MAX_ALL_);

	rockEntitiesArray = CreateArray(4);
	HookEvent("weapon_fire", ProcessRockHitboxes);

	cvarMaxUnlag = FindConVar("sv_maxunlag");
	cvarLagPushTicks = FindConVar("sv_lagpushticks");
}

public void OnClientConnected(int client)
{
	g_iCmdTickCount[client] = 0;
}

// weapon_fire fires while the engine runs this usercmd, so this is its tick_count
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	g_iCmdTickCount[client] = tickcount;
	return Plugin_Continue;
}

/**
 * Rock is created add it to the array to be tracked.
 */
public void OnEntityCreated(int entity, const char[] classname)
{
	new entityRef;
	
	if (IsRock(entity)) {
		entityRef = EntIndexToEntRef(entity);
		SDKHook(entityRef, SDKHook_OnTakeDamage, PreventDamage);
		SDKHook(entityRef, SDKHook_SpawnPost, SpawnPost);
		Array_AddNewRock(rockEntitiesArray, entityRef);
		
		if (ROCK_GODFRAMES_RENDER) {
			SetEntityRenderMode(entityRef, RenderMode:3);
			SetEntityRenderColor(entityRef, 255, 255, 255, 200);
		}
	}
}

// Add this below outside "OnEntityCreated" function.
void SpawnPost(int entity)
{
	if( GetEntProp(entity, Prop_Data, "m_iHammerID") == 92950 )
	{
		Array_RemoveRock(rockEntitiesArray, EntIndexToEntRef(entity));
	}
}

/*
 * Rock is destroyed, remove it from the array.
 */
public void OnEntityDestroyed(int entity)
{
	if (IsRock(entity)) {
		Array_RemoveRock(rockEntitiesArray, EntIndexToEntRef(entity));
	}
}

/*
 * Turn off all damage dealt to the rock, since we're using a custom hitbox.
 */ 
Action PreventDamage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype) {
	if (ROCK_HITBOX_ENABLED) {
		damage = 0.0;
		return Plugin_Handled;
	} else {
		return Plugin_Continue;
	}
}

/*
 * Tracking origin vector of every rock for every frame (for rollback).
 */
public void OnGameFrame()
{
	new Float:pos[3];
	new rockEntity;
	new index = GetGameTickCount() % MAX_HISTORY_FRAMES; 
	
	for (int i = 0; i < rockEntitiesArray.Length; ++i) {
		rockEntity = rockEntitiesArray.Get(i, BLOCK_ENT_REF); 
		if( !rockEntity || EntRefToEntIndex(rockEntity) == INVALID_ENT_REFERENCE )
		{
			Array_RemoveRock(rockEntitiesArray, rockEntity);
			--i; // the next rock moved into slot i, do not skip its sample
			continue;
		}
		GetEntPropVector(rockEntity, Prop_Send, "m_vecOrigin", pos); 
		new ArrayList:posArray = rockEntitiesArray.Get(i, BLOCK_POS_HISTORY);
		posArray.Set(index, pos[0], 0);
		posArray.Set(index, pos[1], 1);
		posArray.Set(index, pos[2], 2);
		if (ROCK_GODFRAMES_RENDER && Array_IsRockAllowedDmg(i)) {
			SetEntityRenderMode(rockEntity, RenderMode:0);
			SetEntityRenderColor(rockEntity, 255, 255, 255, 255);
		}
	}
}

/**
 * Array Methods
 */

/**
 * Adds a new rock to the array.
 *
 * @param array array of rocks
 * @param entity entity index of the rock
 */
void Array_AddNewRock(ArrayList array, int entity)
{
	new index = array.Push(entity);
	array.Set(index, CreateArray(3, MAX_HISTORY_FRAMES), BLOCK_POS_HISTORY);
	array.Set(index, 0, BLOCK_DMG_DEALT);
	array.Set(index, CURR_GAME_TIME, BLOCK_START_TIME);
}

/**
 * Remove a rock from the array.
 *
 * @param array array of rocks
 * @param entity entity index of the rock
 */
void Array_RemoveRock(ArrayList array, int rockEntity)
{
	new rockIndex = Array_SearchRock(array, rockEntity);
	
	if (rockIndex >= 0) {
		new ArrayList:rockPos = array.Get(rockIndex, BLOCK_POS_HISTORY);
		rockPos.Clear();
		CloseHandle(rockPos);
		RemoveFromArray(array, rockIndex); 
	}
}

/**
 * Searches a rock in the array.
 *
 * @param array array of rocks
 * @param entity entity index to search for
 * @return array index if found, -1 if not found.
 */
int Array_SearchRock(ArrayList array, rockEntity)
{
	for (int i = 0; i < array.Length; ++i) {
		new cRockEntity = array.Get(i, BLOCK_ENT_REF);
		if (rockEntity == cRockEntity) {
			return i;
		} 
	}
	
	return -1;
}

/*
 * Checks if rock is allowed to be dealt damage.
 */
bool Array_IsRockAllowedDmg(rockIndex)
{
	return CURR_GAME_TIME - rockEntitiesArray.Get(rockIndex, BLOCK_START_TIME) >= ROCK_GODFRAMES_TIME;
}

/**
 * Ray Methods
 */

/*
 * Handles the weapon_fire event. Calculates a line-sphere intersection between
 * the shooting survivors and the rock(s). Deals damages accordingly.
 */
Action ProcessRockHitboxes(Event event, const char[] name, 
		bool dontBroadcast)
{
	if (rockEntitiesArray.Length == 0) {
		return Plugin_Handled;
	}
	
	new client = GetClientOfUserId(event.GetInt("userid"));
	
	if (!IsSurvivor(client)) {
		return Plugin_Handled;
	}
	
	new Float:eyeAng[3];
	new Float:eyePos[3];
	
	// Rollback rock position
	new rollBackTick = LAG_COMP_ENABLED && !IsFakeClient(client) ? 
	GetLagCompHistoryTick(client) : GetGameTickCount();
	
	GetClientEyeAngles(client, eyeAng);
	GetClientEyePosition(client, eyePos);
	
	// Abstract sphere hitbox implementation
	// https://en.wikipedia.org/wiki/Line%E2%80%93sphere_intersection
	
	// Get unit vector l
	new Float:l[3];
	GetAngleVectors(eyeAng, l, NULL_VECTOR, NULL_VECTOR);
	
	// Get origin of line o
	new Float:o[3];
	o[0] = eyePos[0];
	o[1] = eyePos[1];
	o[2] = eyePos[2];
	new Float:o_Minus_c[3];
	
	// Sphere vectors
	new Float:radius = SPHERE_HITBOX_RADIUS;
	new Float:c[3];
	
	new ArrayList:rockPositionsArray;
	new entity;
	new index = rollBackTick % MAX_HISTORY_FRAMES;
	new Float:delta;
	
	//PrintToChatAll("%d - %d = %d", GetGameTickCount(), rollBackTick, GetGameTickCount() - rollBackTick);
	
	for (int i = 0; i < rockEntitiesArray.Length; ++i) {
		
		if (Array_IsRockAllowedDmg(i)) {
			entity = rockEntitiesArray.Get(i, BLOCK_ENT_REF); 
			rockPositionsArray = rockEntitiesArray.Get(i, BLOCK_POS_HISTORY);
			
			c[0] = rockPositionsArray.Get(index, 0);
			c[1] = rockPositionsArray.Get(index, 1);
			c[2] = rockPositionsArray.Get(index, 2);
			SubtractVectors(o,c,o_Minus_c);
			
			delta = GetVectorDotProduct(l, o_Minus_c) * GetVectorDotProduct(l, o_Minus_c) 
			- GetVectorLength(o_Minus_c, true) + radius*radius;
			
			// the ray only goes forward. The far intersection
			// -(l.(o-c)) + sqrt(delta) must be >= 0, else the whole sphere is
			// behind the shooter; and a wall between eye and rock blocks it.
			if (delta >= 0.0 
			&& SquareRoot(delta) - GetVectorDotProduct(l, o_Minus_c) >= 0.0 
			&& IsRockVisible(o, c, radius, entity)) {
				ApplyDamageOnRock(i, client, eyePos, c, event, entity);
			}
		}
	}
	
	return Plugin_Handled;
}

/*
 * the history tick holding the rock where this client saw it when
 * it fired, computed like CLagCompensationManager::StartLagCompensation:
 *   correct    = clamp(outgoing latency + m_fLerpTime, 0, sv_maxunlag)
 *   targetTime = cmd tick_count * interval - m_fLerpTime
 *   if |correct - (curtime - targetTime)| > 0.2: targetTime = curtime - correct
 *   targetTime += sv_lagpushticks * interval
 * m_fLerpTime is the lerp the engine settled on for the client (cl_interp vs
 * cl_interp_ratio / cl_updaterate, clamped by sv_client_min/max_interp_ratio).
 * OnGameFrame runs before the tick simulates, so history slot N holds the rock
 * as simulated on tick N-1: the rock at targetTime lives in slot targetTick+1.
 */
int GetLagCompHistoryTick(int client)
{
	float interval = GetTickInterval();
	float lerp = GetEntPropFloat(client, Prop_Data, "m_fLerpTime");

	float correct = GetClientLatency(client, NetFlow_Outgoing) + lerp;
	correct = Clamp(correct, 0.0, cvarMaxUnlag != null ? cvarMaxUnlag.FloatValue : 1.0);

	float targetTime = g_iCmdTickCount[client] * interval - lerp;
	if (FloatAbs(correct - (GetGameTime() - targetTime)) > 0.2) {
		targetTime = GetGameTime() - correct;
	}

	if (cvarLagPushTicks != null) {
		targetTime += cvarLagPushTicks.IntValue * interval;
	}

	int historyTick = RoundToNearest(targetTime / interval) + 1;
	if (historyTick > GetGameTickCount()) {
		historyTick = GetGameTickCount();
	}
	return historyTick;
}

/*
 * true unless a wall sits between the eye and the rock. A hit within the hitbox
 * radius of the rock is the rock's own surface, not a wall in front of it.
 * CONTENTS_WINDOW is left out of the mask because bullets go through glass.
 */
bool IsRockVisible(float eyePos[3], float c[3], float radius, int rockEntity)
{
	TR_TraceRayFilter(eyePos, c, MASK_SHOT & ~CONTENTS_WINDOW, RayType_EndPoint, TraceFilter_RockWall, EntRefToEntIndex(rockEntity));
	if (!TR_DidHit()) {
		return true;
	}

	new Float:hitPos[3];
	TR_GetEndPosition(hitPos);
	return GetVectorDistance(hitPos, c) <= radius;
}

/*
 * An allowlist of what blocks the check: the world, and drawn solid entities
 * (props, doors, breakables, func_wall/func_rotating/func_brush). Everything
 * else passes: players, commons, witches, rocks, weapons, ammo piles, glass and
 * invisible entities such as env_player_blocker, which SourceMod traces would
 * otherwise hit although bullets go through them.
 */
bool TraceFilter_RockWall(int entity, int contentsMask, int rock)
{
	if (entity == 0) {
		return true;
	}
	if (entity == rock || entity <= MaxClients || !IsValidEntity(entity)) {
		return false;
	}

	new String:classname[MAX_STR_LEN];
	GetEntityClassname(entity, classname, MAX_STR_LEN);
	if (StrEqual(classname, "func_breakable_surf")) {
		return false;
	}
	return StrContains(classname, "prop_") == 0
		|| StrContains(classname, "func_door") == 0
		|| StrContains(classname, "func_breakable") == 0
		|| StrContains(classname, "func_wall") == 0
		|| StrContains(classname, "func_rotating") == 0
		|| StrEqual(classname, "func_brush");
}

/*
 * Apply damage on rock depending on weapon and distance.
 */
void ApplyDamageOnRock(rockIndex, client, float eyePos[3], float c[3], Event event,
		rockEntity)
{
	new String:weaponName[MAX_STR_LEN]; 
	event.GetString("weapon", weaponName, MAX_STR_LEN);
	new Float:range = GetVectorDistance(eyePos, c);
	
	if (ROCK_PRINT) {
		PrintToChatAll("Weapon: %s | Range: %.2f", weaponName, range);
	}
	
	if ((!ROCK_HITBOX_ENABLED) || range > RANGE_MAX_ALL || (range < RANGE_MIN_ALL && !IsMelee(weaponName))) {
		return;
		
	} else if (IsSmg(weaponName)) {
		if (range > RANGE_SMG) return;
		ApplyBulletToRock(client, rockIndex, rockEntity, DAMAGE_SMG, range);
		
	} else if (IsPistol(weaponName)) {
		if (range > RANGE_PISTOL) return;
		ApplyBulletToRock(client, rockIndex, rockEntity, DAMAGE_PISTOL, range);
		
	} 
	/*else if (IsMagnum(weaponName)) 
	{
		if (range > RANGE_MAGNUM) return;
		ApplyBulletToRock(client, rockIndex, rockEntity, DAMAGE_MAGNUM, range);
		
	} */
	else if (IsShotgun(weaponName)) 
	{
		if (range > RANGE_SHOTGUN) return;
		ApplyBulletToRock(client, rockIndex, rockEntity, DAMAGE_SHOTGUN, range);
		
	} 
	else if (IsRifle(weaponName)) 
	{
		if (range > RANGE_RIFLE) return;
		ApplyBulletToRock(client, rockIndex, rockEntity, DAMAGE_RIFLE, range);
		
	} 
	/*else if (IsMelee(weaponName)) {
		if (range > RANGE_MELEE) return;
		ApplyBulletToRock(client, rockIndex, rockEntity, DAMAGE_MELEE, range);
		
	} */
	else if (IsSniper(weaponName)) 
	{
		if (range > RANGE_SNIPER) return;
		ApplyBulletToRock(client, rockIndex, rockEntity, DAMAGE_SNIPER, range);
		
	} 
	else if (IsMiniGun(weaponName)) {
		if (range > RANGE_MINIGUN) return;
		ApplyBulletToRock(client, rockIndex, rockEntity, DAMAGE_MINIGUN, range);
		
	} else if (IsMountedMachineGun(weaponName)){
		if (range > RANGE_MOUNTED_MACHINEGUN) return;
		ApplyBulletToRock(client, rockIndex, rockEntity, DAMAGE_MOUNTED_MACHINEGUN, range);
    }
}

/*
 * Applies a single bullet damage to a single rock.
 */
void ApplyBulletToRock(int client, int rockIndex, int rockEntity, float damage, float range)
{
	new Float:rockDamage = float(rockEntitiesArray.Get(rockIndex, BLOCK_DMG_DEALT));
	rockDamage += damage / range * 100;
	
	if (RoundFloat(rockDamage) > ROCK_HEALTH) {
		DataPack hData = new DataPack();
		hData.WriteCell(GetClientUserId(client));
		hData.WriteCell(rockEntity);
		hData.Reset();
		RequestFrame(CTankRock__Detonate, hData);
	} else {
		rockEntitiesArray.Set(rockIndex, RoundFloat(rockDamage), BLOCK_DMG_DEALT);
	}
	
	if (ROCK_PRINT) {
		PrintToChatAll("Rock health: %d\%", RoundFloat(ROCK_HEALTH - rockDamage));
	}
}

bool IsPistol(const char[] weaponName)
{
	return StrEqual(weaponName, "pistol");
}

/*bool IsMagnum(const char[] weaponName)
{
	return StrEqual("pistol_magnum", weaponName);
}*/

bool IsShotgun(const char[] weaponName)
{
	return StrEqual(weaponName, "autoshotgun")
		|| StrEqual(weaponName, "pumpshotgun");
		// || StrEqual(weaponName, "shotgun_chrome")
		//|| StrEqual(weaponName, "shotgun_spas")

}

bool IsSmg(const char[] weaponName)
{
	return StrEqual(weaponName, "smg")
		//|| StrEqual(weaponName, "smg_silenced")
		//|| StrEqual(weaponName, "smg_mp5");
}

bool IsRifle(const char[] weaponName)
{
	return StrEqual(weaponName, "rifle")
		//|| StrEqual(weaponName, "rifle_ak47")
		//|| StrEqual(weaponName, "rifle_desert")
		//|| StrEqual(weaponName, "rifle_m60")
		//|| StrEqual(weaponName, "rifle_sg552");
}

bool IsMelee(const char[] weaponName)
{
	return StrEqual(weaponName, "chainsaw")
		|| StrEqual(weaponName, "melee");
}

bool IsSniper(const char[] weaponName)
{
	return StrEqual(weaponName, "hunting_rifle");
		//|| StrEqual(weaponName, "sniper_awp")
		//|| StrEqual(weaponName, "sniper_military")
		//|| StrEqual(weaponName, "sniper_scout")
}

bool IsMiniGun(const char[] weaponName)
{
	return StrEqual(weaponName, "prop_minigun");
		//|| StrEqual(weaponName, "prop_minigun_l4d1")
	
}

bool IsMountedMachineGun(const char[] weaponName)
{
    return StrEqual(weaponName, "prop_mounted_machine_gun");
}

/**
 * Print Methods
 */

bool IsRock(int entity)
{
	if (IsValidEntity(entity)) {
		new String:classname[MAX_STR_LEN];
		GetEntityClassname(entity, classname, MAX_STR_LEN);
		return StrEqual(classname, "tank_rock");
	}
	return false;
}

// Credits to Visor
CTankRock__Detonate(DataPack pack)
{
	int attacker = GetClientOfUserId(pack.ReadCell());
	int rock = EntRefToEntIndex(pack.ReadCell());
	delete pack;

	if (rock == INVALID_ENT_REFERENCE || !attacker || !IsClientInGame(attacker))
		return;

	// Every pellet past ROCK_HEALTH queues its own detonate for the same frame,
	// so count the rock once however many requests it gathered.
	int rockRef = EntIndexToEntRef(rock);
	if (rockRef != g_iLastSkeetedRock) {
		g_iLastSkeetedRock = rockRef;
		int tank = GetEntPropEnt(rock, Prop_Data, "m_hOwnerEntity");
		if ((tank <= 0 || tank > MaxClients) && HasEntProp(rock, Prop_Data, "m_hThrower"))
			tank = GetEntPropEnt(rock, Prop_Data, "m_hThrower");
		if (tank <= 0 || tank > MaxClients)
			tank = -1;
		Call_StartForward(g_hForwardRockSkeeted);
		Call_PushCell(attacker);
		Call_PushCell(tank);
		Call_Finish();
	}

	SDKCall(g_SDKCall, rock);

	CPrintToChatAll("[{olive}TS{default}] {olive}%N{default} %t", attacker, "skeeted a tank rock.");
}

/**
 * Stocks
 */

bool:IsSurvivor(client)														 
{																			   
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2);
}

float Clamp(float value, float valueMin, float valueMax)
{
	if (value < valueMin) {
		return valueMin;
	} else if (value > valueMax) {
		return valueMax;
	} else {
		return value;
	}
}
