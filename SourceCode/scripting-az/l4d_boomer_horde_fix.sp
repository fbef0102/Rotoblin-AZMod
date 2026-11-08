#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define PLUGIN_VERSION "0.3-riverside1"

/**
 * l4d_boomer_horde_fix - every boom brings a full horde that actually arrives.
 *
 * Owner report 2026-11-06 (Grma, PUG 1004 and 1037 on Passifice): some booms
 * bring almost no commons, others feel like all 30. Cause, from the source
 * rebuild (NextBotManager::OnSurvivorVomitedUpon): when a survivor is vomited
 * on, every living common within z_notice_it_range (1500, straight line,
 * through floors) is told to attack and counted, and only
 * z_mob_spawn_max_size (28) minus that count is spawned new. With 28 in range
 * nothing new spawns ("(MOB) 30 wanderers grabbed", no "will make" line).
 * Commons a floor away or stuck on a ledge count fully but take 20-40 s to
 * arrive or never do. Dallas logs: zero-new booms on 59% of NM4, 49% of DA2,
 * 48% of bedlam. Rig on bedlam: mid-map about half the grabbed commons
 * arrived within 40 s.
 *
 * Fix: just before the game counts (left4dhooks pre-forward on
 * CTerrorPlayer::OnVomitedUpon), remove each in-range common that cannot get
 * there soon: nav travel distance to the victim over
 * l4d_boomer_horde_fix_travel, or no path at all. Removal only happens at the
 * end of the frame, so the game still counts those commons; the post-forward
 * then raises the pending mob by the number removed through
 * ZombieManager::SpawnITMob, so the fresh mob is 28 minus the commons that
 * really are on their way. A common is never removed if a
 * survivor can see it, if it is within l4d_boomer_horde_fix_guard of any
 * survivor, or if it is under 3 s old (so a boom that covers several
 * survivors does not throw away the mob it just spawned). Commons out of
 * range are left to the engine's own cull, which already removes unseen
 * calm commons while a mob waits for room under z_common_limit.
 *
 * Each vomit with a removal logs a "(BOOMHORDE)" line to the game log, next
 * to the engine's "(MOB)" lines.
 *
 * 0.2 (PUG 1060, farm02): the vomit stream calls OnVomitedUpon on the same
 * victim several times in a row (7 calls in 0.08 s there). The engine only
 * spawns on the first, but 0.1 re-found the same 15 commons each time (still
 * alive, removal pending), and each post-forward raised the pending mob by
 * another 15: one boom became a mob of 117. Now the plugin acts only when the
 * engine itself will count (the victim's m_itTimer has run out, the same test
 * CTerrorPlayer::OnVomitedUpon makes before NextBotManager::
 * OnSurvivorVomitedUpon), and a common already slated for removal is never
 * counted or added again (the BOOMHORDE line reports any still pending).
 *
 * 0.2.1: "already removed" is the engine's EFL_KILLME flag, not a plugin
 * array. RemoveEntity runs UpdateOnRemove at once, so OnEntityDestroyed fires
 * immediately while the common stays in the entity list until the frame ends;
 * 0.2's array was cleared there, and a boomer splash covering several
 * survivors in one frame replaced the same commons once per victim (rig: two
 * victims, 30 replaced twice, pending 60).
 *
 * Also 0.2: NavAreaTravelDistance only finds the goal when it lies over a nav
 * area, so a victim on a car roof, ledge or prop (Double at z 176 on farm02)
 * made every common "no path" and nearly all of them were replaced. When the
 * victim is not over nav, the walk is measured to the centre of the victim's
 * last known nav area instead; if that area is not near the victim either,
 * nothing is replaced.
 *
 * 0.3 (owner 2026-11-07, Suicide Blitz 2, PUG on Dallas): a boom in the start
 * saferoom during a tank run back brought no commons at all. Every nav area a
 * survivor has seen is marked cleared (TerrorNavArea::MarkAreaCleared), and
 * the mob spawn search (ZombieManager::AccumulateSpawnAreaCollection) skips
 * cleared areas through IsSpawningAllowed. Survivors who fall back through
 * ground they already walked leave the game nowhere to spawn: "MOB SPAWN
 * ERROR: Empty spawn area set" every frame, and the mob waits until the
 * boundary creep (z_boundary_clear_type 1) has uncleared areas again: 22 s
 * there, after the tank was dead. Stock on every map (Dallas logs: farm,
 * hospital, airport, cwm1, c1m1), mostly at the start saferoom.
 * z_dont_clear 1 would stop the marking everywhere and let every horde come
 * back behind the survivors, so instead: after a counted vomit, the plugin
 * watches for the failure itself. SpawnITMob only sets the mob up (location
 * IT, no area); ZombieManager::StartFrame calls ChooseMobSpawnAreas on the
 * next frame, and only its empty-set branch drops the location to ANYWHERE
 * (0) with no area chosen. CollectSpawnAreas keeps each result for 2 s, so
 * the first sighting only expires that cache; if the next poll, after a fresh
 * search, still shows the failure while commons are owed,
 * cleared areas no survivor can see, at least l4d_boomer_horde_fix_fallback_min
 * from every survivor and within z_spawn_range of the victim (the engine only
 * draws from survivors' active areas, which end there), are marked uncleared
 * for that one mob. When it is done (or after FALLBACK_TIMEOUT) their bits are
 * put back and TerrorNavMesh::OnAreaCleared re-seeds the boundary creep from
 * them, as a real clear would. Normal spawning, other hordes and wanderers are
 * untouched (wanderers need a culled count that clearing already zeroed).
 * Each fallback logs a "(BOOMHORDE)" line.
 */

#define TEAM_SURVIVOR 2
#define MIN_AGE 3.0
#define EFL_KILLME 1   // UTIL_Remove has run; the entity goes away at the end of the frame
#define GOAL_SNAP 400.0   // furthest the last known area centre may be from the victim
#define WATCH_POLL 0.1         // how often a counted vomit's mob is checked for a failed spawn search
#define WATCH_TIME 15.0        // how long it is watched (the search only runs once there is room under z_common_limit)
#define FALLBACK_POLL 0.5
#define FALLBACK_TIMEOUT 20.0

// Offsets in the L4D1 server.so (from the source rebuild's field tables and disassembly)
#define ZM_MOB_SPAWN_AREA 0x144   // ZombieManager::m_mobSpawnArea, the area ChooseMobSpawnAreas picked
#define ZM_MOB_LOCATION 0x170     // ZombieManager::m_mobLocation: SpawnITMob sets 2, a failed search 0
#define ZM_ANYWHERE_CACHE 0xd8    // CollectSpawnAreas' 2 s cache timer for ANYWHERE: its timestamp
#define AREA_CLEARED_BITS 0x14d   // TerrorNavArea::m_clearedSurvivorBits, one bit per survivor who saw it
#define AREA_POTENTIAL_VIS 0x178  // TerrorNavArea::m_potentialSurvivorVisibility, survivors who may see it
// Areas the mob search rejects anyway (AccumulateSpawnAreaCollection), so never worth opening
#define SPAWN_SKIP (NAV_SPAWN_PLAYER_START | NAV_SPAWN_CHECKPOINT | NAV_SPAWN_NOT_CLEARABLE | NAV_SPAWN_NO_MOBS | NAV_SPAWN_RESCUE_VEHICLE | NAV_SPAWN_RESCUE_CLOSET)
#define AREA_ATTR_SKIP 0x30003

ConVar g_cvEnabled;
ConVar g_cvTravel;
ConVar g_cvGuard;
ConVar g_cvNoticeRange;
ConVar g_cvFallback;
ConVar g_cvFallbackMin;
ConVar g_cvSpawnRange;
float g_fBorn[2049];   // game time each common was created
int g_iRemoved;        // commons removed by the pre-forward of the vomit being handled
bool g_bCounted;       // the vomit being handled is the one the engine counts and spawns for
Handle g_hSpawnITMob;
Handle g_hOnAreaCleared;
ArrayList g_aOpened;   // areas the fallback uncleared: [address, cleared bits before]
Handle g_hWatchTimer;  // watching a counted vomit's mob for a failed search
Handle g_hFallbackTimer; // areas are open, waiting for the mob to finish
float g_fWatchStart;
float g_fFallbackStart;
int g_iWatchVictim;    // userid
int g_iWatchHits;      // polls in a row that saw the failure

public Plugin myinfo =
{
	name = "L4D Boomer Horde Fix",
	author = "Malevolence",
	description = "Boomer hordes replace far or stuck commons with fresh ones so the full horde arrives",
	version = PLUGIN_VERSION,
	url = ""
};

public void OnPluginStart()
{
	g_cvEnabled = CreateConVar("l4d_boomer_horde_fix", "1", "Replace far or stuck commons when a survivor is vomited on (0 = off)", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvTravel = CreateConVar("l4d_boomer_horde_fix_travel", "1200.0", "A common with a longer walk than this to the victim (or no path) is replaced", FCVAR_NONE, true, 0.0);
	g_cvGuard = CreateConVar("l4d_boomer_horde_fix_guard", "500.0", "Never replace a common this close to any survivor", FCVAR_NONE, true, 0.0);
	g_cvFallback = CreateConVar("l4d_boomer_horde_fix_fallback", "1", "When a boom's mob finds no spawn area, let it spawn in cleared areas out of sight (0 = off)", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvFallbackMin = CreateConVar("l4d_boomer_horde_fix_fallback_min", "500.0", "Fallback areas are at least this far from every survivor", FCVAR_NONE, true, 0.0);
	CreateConVar("l4d_boomer_horde_fix_version", PLUGIN_VERSION, "l4d_boomer_horde_fix version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	g_cvNoticeRange = FindConVar("z_notice_it_range");
	g_cvSpawnRange = FindConVar("z_spawn_range");

	GameData gd = new GameData("left4dhooks.l4d1");
	if (gd == null)
		SetFailState("left4dhooks.l4d1 gamedata missing");
	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(gd, SDKConf_Signature, "ZombieManager::SpawnITMob"))
		SetFailState("ZombieManager::SpawnITMob signature not found");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	g_hSpawnITMob = EndPrepSDKCall();
	delete gd;
	if (g_hSpawnITMob == null)
		SetFailState("ZombieManager::SpawnITMob call could not be prepared");

	gd = new GameData("l4d_boomer_horde_fix");
	if (gd == null)
		SetFailState("l4d_boomer_horde_fix gamedata missing");
	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(gd, SDKConf_Signature, "TerrorNavMesh::OnAreaCleared"))
		SetFailState("TerrorNavMesh::OnAreaCleared signature not found");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	g_hOnAreaCleared = EndPrepSDKCall();
	delete gd;
	if (g_hOnAreaCleared == null)
		SetFailState("TerrorNavMesh::OnAreaCleared call could not be prepared");

	g_aOpened = new ArrayList(2);
	HookEvent("round_start", Event_RoundChange, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundChange, EventHookMode_PostNoCopy);
}

public void OnPluginEnd()
{
	if (g_aOpened.Length > 0)
		RestoreCleared();
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (entity > 0 && entity < sizeof(g_fBorn) && StrEqual(classname, "infected"))
		g_fBorn[entity] = GetGameTime();
}

public void OnMapEnd()
{
	// the areas are freed with the map: forget them, nothing to restore
	g_aOpened.Clear();
	delete g_hWatchTimer;
	delete g_hFallbackTimer;
}

// a round restart resets every area's cleared bits; restoring old bits after it would be wrong
public void Event_RoundChange(Event event, const char[] name, bool dontBroadcast)
{
	g_aOpened.Clear();
	delete g_hWatchTimer;
	delete g_hFallbackTimer;
}

public Action L4D_OnVomitedUpon(int victim, int &attacker, bool &boomerExplosion)
{
	g_iRemoved = 0;
	g_bCounted = false;
	if (!g_cvEnabled.BoolValue || victim < 1 || victim > MaxClients || !IsClientInGame(victim) || GetClientTeam(victim) != TEAM_SURVIVOR)
		return Plugin_Continue;

	float now = GetGameTime();
	// the engine only counts and spawns while the victim is not yet "it"; the vomit
	// stream calls this several times per boom and every later call must do nothing
	float itEnd = GetEntPropFloat(victim, Prop_Send, "m_itTimer", 1);
	if (itEnd > 0.0 && !(now > itEnd))
		return Plugin_Continue;
	g_bCounted = true;

	float range = g_cvNoticeRange.FloatValue;
	float maxTravel = g_cvTravel.FloatValue;
	float v[3], p[3];
	GetClientAbsOrigin(victim, v);
	float goal[3];
	if (!VictimNavGoal(victim, v, goal))
		return Plugin_Continue;

	int inRange, noPath, far, stale;
	int ent = -1;
	while ((ent = FindEntityByClassname(ent, "infected")) != -1)
	{
		if (GetEntProp(ent, Prop_Data, "m_iHealth") <= 0)
			continue;
		GetEntPropVector(ent, Prop_Send, "m_vecOrigin", p);
		if (GetVectorDistance(v, p) >= range)
			continue;
		if (GetEntProp(ent, Prop_Data, "m_iEFlags") & EFL_KILLME)
		{
			stale++;   // removed by an earlier vomit and still alive: never count it twice
			continue;
		}
		inRange++;
		if (ent < sizeof(g_fBorn) && now - g_fBorn[ent] < MIN_AGE)
			continue;
		if (NearOrSeenBySurvivor(ent, p))
			continue;
		float travel = L4D2_NavAreaTravelDistance(p, goal, false);
		if (travel >= 0.0 && travel <= maxTravel)
			continue;
		if (travel < 0.0)
			noPath++;
		else
			far++;
		RemoveEntity(ent);
	}

	g_iRemoved = noPath + far;
	if (g_iRemoved > 0)
		LogToGame("(BOOMHORDE) %N vomited: %d commons in range, replacing %d (%d no path, %d over %.0f walk, %d still pending removal)",
		          victim, inRange, g_iRemoved, noPath, far, maxTravel, stale);
	return Plugin_Continue;
}

public void L4D_OnVomitedUpon_Post(int victim, int attacker, bool boomerExplosion)
{
	Address zm = L4D_GetPointer(POINTER_ZOMBIEMANAGER);
	if (g_iRemoved > 0)
	{
		// the game has spawned 28 minus everything it counted, removed commons included; add those back
		int want = L4D2Direct_GetPendingMobCount() + g_iRemoved;
		g_iRemoved = 0;
		if (zm != Address_Null)
			SDKCall(g_hSpawnITMob, zm, want);
	}
	// SpawnITMob only sets the mob up; the area search runs from the next frame on
	// one boom at a time: a second counted vomit while areas are open shares that window
	bool counted = g_bCounted;
	g_bCounted = false;
	if (counted && g_cvFallback.BoolValue && g_hWatchTimer == null && g_hFallbackTimer == null)
	{
		g_iWatchVictim = GetClientUserId(victim);
		g_iWatchHits = 0;
		g_fWatchStart = GetGameTime();
		g_hWatchTimer = CreateTimer(WATCH_POLL, Timer_Watch, _, TIMER_REPEAT);
	}
}

// A failed search leaves no area and drops the location to ANYWHERE (0). The first sighting may
// be CollectSpawnAreas' 2 s cache answering with an old empty set (and a director SpawnMob looks
// the same for one frame), so it expires the cache and the failure must still show on the next poll.
public Action Timer_Watch(Handle timer)
{
	Address zm = L4D_GetPointer(POINTER_ZOMBIEMANAGER);
	int victim = GetClientOfUserId(g_iWatchVictim);
	if (zm == Address_Null || victim == 0 || !IsClientInGame(victim) || GetClientTeam(victim) != TEAM_SURVIVOR
	    || L4D2Direct_GetPendingMobCount() <= 0 || GetGameTime() - g_fWatchStart > WATCH_TIME)
	{
		g_hWatchTimer = null;
		return Plugin_Stop;
	}
	bool failed = LoadFromAddress(zm + view_as<Address>(ZM_MOB_SPAWN_AREA), NumberType_Int32) == 0
	           && LoadFromAddress(zm + view_as<Address>(ZM_MOB_LOCATION), NumberType_Int32) == 0;
	g_iWatchHits = failed ? g_iWatchHits + 1 : 0;
	if (g_iWatchHits == 1)
		StoreToAddress(zm + view_as<Address>(ZM_ANYWHERE_CACHE), view_as<int>(-1.0), NumberType_Int32, false);
	if (g_iWatchHits < 2)
		return Plugin_Continue;
	g_hWatchTimer = null;
	OpenClearedAreas(victim, zm);
	return Plugin_Stop;
}

// Mark cleared, unseen areas around the victim uncleared so the pending mob can use them.
void OpenClearedAreas(int victim, Address zm)
{
	float minDist = g_cvFallbackMin.FloatValue;
	float maxDist = g_cvSpawnRange.FloatValue;
	float v[3], c[3], s[3];
	GetClientAbsOrigin(victim, v);

	float survivors[MAXPLAYERS][3];
	int count;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVOR && IsPlayerAlive(i))
		{
			GetClientAbsOrigin(i, s);
			survivors[count++] = s;
		}
	}

	ArrayList areas = new ArrayList();
	L4D_GetAllNavAreas(areas);
	for (int i = 0; i < areas.Length; i++)
	{
		Address area = areas.Get(i);
		int bits = LoadFromAddress(area + view_as<Address>(AREA_CLEARED_BITS), NumberType_Int8);
		if (bits == 0)
			continue;
		if ((L4D_GetNavArea_SpawnAttributes(area) & SPAWN_SKIP) || (L4D_GetNavArea_AttributeFlags(area) & AREA_ATTR_SKIP))
			continue;
		if (LoadFromAddress(area + view_as<Address>(AREA_POTENTIAL_VIS), NumberType_Int32) != 0)
			continue;
		L4D_GetNavAreaCenter(area, c);
		if (GetVectorDistance(c, v) > maxDist)
			continue;
		bool near;
		for (int j = 0; j < count && !near; j++)
			near = GetVectorDistance(c, survivors[j]) < minDist;
		if (near)
			continue;
		int row = g_aOpened.Push(area);
		g_aOpened.Set(row, bits, 1);
		StoreToAddress(area + view_as<Address>(AREA_CLEARED_BITS), 0, NumberType_Int8, false);
	}
	delete areas;

	LogToGame("(BOOMHORDE) %N vomited: no mob spawn area, opened %d cleared areas %.0f-%.0f away for %d commons",
	          victim, g_aOpened.Length, minDist, maxDist, L4D2Direct_GetPendingMobCount());
	if (g_aOpened.Length == 0)
		return;
	// CollectSpawnAreas keeps its last result for 2 s; make the next retry look again
	StoreToAddress(zm + view_as<Address>(ZM_ANYWHERE_CACHE), view_as<int>(-1.0), NumberType_Int32, false);
	g_fFallbackStart = GetGameTime();
	g_hFallbackTimer = CreateTimer(FALLBACK_POLL, Timer_Fallback, _, TIMER_REPEAT);
}

public Action Timer_Fallback(Handle timer)
{
	if (L4D2Direct_GetPendingMobCount() > 0 && GetGameTime() - g_fFallbackStart < FALLBACK_TIMEOUT)
		return Plugin_Continue;
	g_hFallbackTimer = null;
	RestoreCleared();
	return Plugin_Stop;
}

// Put back the cleared bits, keeping any survivor who has seen the area since, and let the
// boundary creep start from these areas again: while they were open, front areas next to
// them may have dropped off the spread list. All bits go back first, so OnAreaCleared never
// sees a ring area as an uncleared neighbour and pushes it onto the spread list.
void RestoreCleared()
{
	for (int i = 0; i < g_aOpened.Length; i++)
	{
		Address bitsAt = view_as<Address>(g_aOpened.Get(i, 0)) + view_as<Address>(AREA_CLEARED_BITS);
		int now = LoadFromAddress(bitsAt, NumberType_Int8);
		StoreToAddress(bitsAt, now | g_aOpened.Get(i, 1), NumberType_Int8, false);
	}
	Address mesh = L4D_GetPointer(POINTER_NAVMESH);
	if (mesh != Address_Null)
		for (int i = 0; i < g_aOpened.Length; i++)
			SDKCall(g_hOnAreaCleared, mesh, g_aOpened.Get(i, 0));
	g_aOpened.Clear();
}

// another plugin blocked the vomit: our post-forward will not run, drop the count
public void L4D_OnVomitedUpon_PostHandled(int victim, int attacker, bool boomerExplosion)
{
	g_iRemoved = 0;
	g_bCounted = false;
}

// NavAreaTravelDistance only reaches a goal that lies over a nav area; off the mesh
// (car roof, ledge, prop) use the centre of the victim's last known area. False when
// that area is missing or too far away to stand in for the victim.
bool VictimNavGoal(int victim, const float v[3], float goal[3])
{
	goal = v;
	float probe[3];
	probe = v;
	if (L4D2Direct_GetTerrorNavArea(probe) != Address_Null)
		return true;
	Address area = L4D_GetLastKnownArea(victim);
	if (area == Address_Null)
		return false;
	L4D_GetNavAreaCenter(area, goal);
	return GetVectorDistance(v, goal) <= GOAL_SNAP;
}

bool NearOrSeenBySurvivor(int common, const float pos[3])
{
	float guard = g_cvGuard.FloatValue;
	float eye[3], s[3], head[3];
	head = pos;
	head[2] += 56.0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || GetClientTeam(i) != TEAM_SURVIVOR || !IsPlayerAlive(i))
			continue;
		GetClientAbsOrigin(i, s);
		if (GetVectorDistance(s, pos) < guard)
			return true;
		GetClientEyePosition(i, eye);
		Handle tr = TR_TraceRayFilterEx(eye, head, MASK_VISIBLE, RayType_EndPoint, Filter_WorldOnly, common);
		bool seen = !TR_DidHit(tr) || TR_GetEntityIndex(tr) == common;
		delete tr;
		if (seen)
			return true;
	}
	return false;
}

public bool Filter_WorldOnly(int entity, int contentsMask, any common)
{
	if (entity == common)
		return true;
	if (entity >= 1 && entity <= MaxClients)
		return false;
	char cls[16];
	GetEntityClassname(entity, cls, sizeof(cls));
	return !StrEqual(cls, "infected");
}
