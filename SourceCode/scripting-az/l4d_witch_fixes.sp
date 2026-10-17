/**
 * l4d_witch_fixes: the witch's movement fixes in one plugin (replaces l4d_witch_corner_fix,
 * l4d_witch_direct_fix and l4d_witch_fire_fix, and adds the climb fix). Research and rig results:
 * witchfix/ in the Riverside workspace.
 *
 * Every fix checks its own hooks at load and turns only itself off if something does not match
 * (a game update moved a function, say), logging which one: each hooked vtable slot must hold the
 * function the gamedata names (Linux: symbols; Windows: signatures from server.dll), and the climb
 * fix also checks every witch's INextBot table. Each fix has an on/off cvar that works live.
 *
 * Linux / Windows layout (server.so / server.dll): WitchLocomotion Update 37 / 36,
 * IsPotentiallyTraversable 83 / 82, ClimbUpToLedge 42 / 41; INextBot IsAbleToClimbOnto 52 / 51;
 * the witch's INextBot at +2224 / +2204, her locomotion at +0xD8C / +0xD78. Windows has one
 * destructor slot where Linux has two.
 *
 * corner  (l4d_witch_fixes_corner)
 *   ZombieBotLocomotion::ResolveCollision gives up on a move that would shift her less than 1 unit.
 *   The 1 unit was sized for bots updated every 0.1 s; at nb_update_frequency 0.014 her wall slide
 *   is ~0.05 units per step, so every step is thrown away and she freezes on corners. While (and only
 *   while) a witch's locomotion updates, both checks are turned off: Linux fld1 -> fldz at +0x3ED and
 *   +0x491; Windows (shared 1.0f constant) jnp -> jo at +0x1E5+12 and +0x5F6+12. Commons share the
 *   code and never see the change.
 *
 * direct  (l4d_witch_fixes_direct)
 *   WitchAttack::Update drops her nav path and runs straight at the victim whenever
 *   ILocomotion::IsPotentiallyTraversable(feet, victim) is true. That check is a hull trace plus the
 *   180 unit jump limit, with no floor test, so with a survivor on a ledge above a pit she turns off
 *   her path into the open air, drops back, re-paths and paces. Hooked on each witch's locomotion: a
 *   yes for a line >= _direct_minlen long becomes no if the floor anywhere along it falls more than
 *   _direct_drop below both the line and the victim's height (traces every _direct_step units).
 *
 * climb   (l4d_witch_fixes_climb)
 *   The path follower climbs whatever its path runs into, including physics props the nav mesh knows
 *   nothing about (Infected::IsAbleToClimbOnto says yes to any AI-walkable entity), and climb
 *   animations end on a ledge's front lip, which on a rounded top is too steep to stand on. Either
 *   way she slides back and starts the same climb again, forever. A new climb to the same landing
 *   goal from the same spot within 3 s means the last one failed:
 *     - onto an entity: that climb is refused before it starts and the entity is off limits to her
 *       for _climb_ban seconds, so she goes round it;
 *     - onto the world: the next climb to that goal is watched, and when she reaches the lip she is
 *       slid (4 frames) to the first spot she can stand on up to _climb_assist units ahead (floor
 *       normal z >= 0.7, her hull clear). No such spot, no move.
 *   Climbs that work are never touched.
 *
 * fire    (l4d_witch_fixes_fire)
 *   Map fire (fire barrels, burning cars: trigger_hurt that also hurts NPCs) lights her, credited to
 *   nobody, and she drops the survivor she was chasing. Burn damage to a witch is dropped unless a
 *   survivor dealt it or it comes from her own flame (lit by a survivor who has since left).
 */
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <dhooks>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name = "L4D Witch Fixes",
	author = "Malevolence",
	description = "Witch movement fixes: corners, straight-line cuts over gaps, failed climbs, map fire",
	version = "1.1.0",
	url = "https://github.com/Volence/riverside-l4d-plugins"
};

#define BANS 4

bool g_windows;
int g_locoOffset;               // Witch -> WitchLocomotion*
Address g_witchVtable;          // what a WitchLocomotion's vptr holds
bool g_okCorner, g_okDirect, g_okClimb;

// corner
Address g_rc;                   // ZombieBotLocomotion::ResolveCollision
int g_sites[2], g_byteOff, g_byteOn;
bool g_patched;
DynamicHook g_hUpdate;

// direct
DynamicHook g_hTrav;

// climb
int g_botOffset;                // Witch -> its INextBot
Address g_ontoThunk;            // what slot g_ontoSlot of a witch's INextBot vtable must hold
int g_ontoSlot;
DynamicHook g_hOnto, g_hUpPre, g_hUpPost;

ConVar g_cvCorner, g_cvDirect, g_cvClimb, g_cvFire, g_cvLog;
ConVar g_cvDrop, g_cvStep, g_cvMinLen, g_cvBan, g_cvAssist;

// per witch
int g_idUpdPre[2048] = { INVALID_HOOK_ID, ... };
int g_idUpdPost[2048] = { INVALID_HOOK_ID, ... };
int g_idTrav[2048] = { INVALID_HOOK_ID, ... };
int g_idOnto[2048] = { INVALID_HOOK_ID, ... };
int g_idUpPre[2048] = { INVALID_HOOK_ID, ... };
int g_idUpPost[2048] = { INVALID_HOOK_ID, ... };
Address g_loco[2048], g_bot[2048];
int g_ban[2048][BANS];
float g_banUntil[2048][BANS];
float g_lastGoal[2048][3], g_lastStart[2048][3], g_lastT[2048];
float g_failGoal[2048][3], g_failUntil[2048];
float g_watchGoal[2048][3], g_watchDir[2048][2], g_watchUntil[2048];
float g_slideFrom[2048][3], g_slideTo[2048][3];
int g_slideStep[2048];

public void OnPluginStart()
{
	g_cvCorner = CreateConVar("l4d_witch_fixes_corner", "1", "Corner fix: she slides off corners instead of freezing at a low nb_update_frequency", _, true, 0.0, true, 1.0);
	g_cvDirect = CreateConVar("l4d_witch_fixes_direct", "1", "Direct fix: no straight-line run at her victim over a pit or open air", _, true, 0.0, true, 1.0);
	g_cvClimb = CreateConVar("l4d_witch_fixes_climb", "1", "Climb fix: no endless climb-and-slide on props and rounded ledges", _, true, 0.0, true, 1.0);
	g_cvFire = CreateConVar("l4d_witch_fixes_fire", "1", "Fire fix: map fire does not light the witch", _, true, 0.0, true, 1.0);
	g_cvLog = CreateConVar("l4d_witch_fixes_log", "0", "1: log every change a fix makes (refused shortcut, refused climb, slide)", _, true, 0.0, true, 1.0);
	g_cvDrop = CreateConVar("l4d_witch_fixes_direct_drop", "48", "Direct: refuse the shortcut if the floor falls this far below the line and the victim", _, true, 18.0);
	g_cvStep = CreateConVar("l4d_witch_fixes_direct_step", "24", "Direct: spacing of the floor checks along the line", _, true, 8.0);
	g_cvMinLen = CreateConVar("l4d_witch_fixes_direct_minlen", "96", "Direct: only check lines at least this long (shorter ones are path look-ahead probes)", _, true, 0.0);
	g_cvBan = CreateConVar("l4d_witch_fixes_climb_ban", "15", "Climb: seconds an object she failed to climb stays off limits to her", _, true, 1.0);
	g_cvAssist = CreateConVar("l4d_witch_fixes_climb_assist", "48", "Climb: furthest she is slid onto a ledge she keeps sliding off (0 = never)", _, true, 0.0, true, 96.0);
	AutoExecConfig(true, "l4d_witch_fixes");

	GameData gd = new GameData("l4d_witch_fixes");
	if (gd == null)
	{
		LogError("gamedata l4d_witch_fixes.txt missing: only the fire fix runs");
	}
	else
	{
		g_windows = gd.GetOffset("Platform") == 2;
		if (InitShared(gd))
		{
			g_okCorner = InitCorner(gd);
			g_okDirect = InitDirect(gd);
			g_okClimb = InitClimb(gd);
		}
		delete gd;
	}
	LogMessage("ready (%s): corner %s, direct %s, climb %s, fire on", g_windows ? "windows" : "linux",
		g_okCorner ? "on" : "OFF", g_okDirect ? "on" : "OFF", g_okClimb ? "on" : "OFF");

	int w = -1;
	while ((w = FindEntityByClassname(w, "witch")) != -1)
	{
		SDKHook(w, SDKHook_OnTakeDamage, OnWitchDamage);
		HookWitch(w);
	}
}

public void OnPluginEnd()
{
	SetPatch(false);
	for (int i = 0; i < 2048; i++) Unhook(i);
}

int Byte(Address base, int off)
{
	return LoadFromAddress(base + view_as<Address>(off), NumberType_Int8) & 0xFF;
}

Address VtableSlot(Address vptr, int slot)
{
	return view_as<Address>(LoadFromAddress(vptr + view_as<Address>(slot * 4), NumberType_Int32));
}

// ---- shared: where a witch keeps her locomotion, and what its vtable is ----

bool InitShared(GameData gd)
{
	Address gli = gd.GetAddress("GetLocomotionInterface");
	Address vt = gd.GetAddress("WitchLocomotionVtable");
	if (gli == Address_Null || vt == Address_Null)
	{
		LogError("witch locomotion symbols not found: corner, direct and climb fixes OFF");
		return false;
	}
	if (g_windows)
	{
		// gli is Witch::CreateComponents: at +0x48, right after the WitchLocomotion is built, it is
		// stored with mov [esi+imm32], edi (89 BE ....)
		if (Byte(gli, 0x48) != 0x89 || Byte(gli, 0x49) != 0xBE)
		{
			LogError("Witch::CreateComponents has an unexpected shape: corner, direct and climb fixes OFF");
			return false;
		}
		g_locoOffset = LoadFromAddress(gli + view_as<Address>(0x4A), NumberType_Int32);
		g_witchVtable = vt;
	}
	else
	{
		// mov eax,[esp+4] (8B 44 24 04); mov eax,[eax+imm32] (8B 80 ....); ret (C3)
		int head[6] = { 0x8B, 0x44, 0x24, 0x04, 0x8B, 0x80 };
		for (int i = 0; i < 6; i++)
			if (Byte(gli, i) != head[i])
			{
				LogError("Witch::GetLocomotionInterface has an unexpected shape: corner, direct and climb fixes OFF");
				return false;
			}
		if (Byte(gli, 10) != 0xC3)
		{
			LogError("Witch::GetLocomotionInterface has an unexpected shape: corner, direct and climb fixes OFF");
			return false;
		}
		g_locoOffset = LoadFromAddress(gli + view_as<Address>(6), NumberType_Int32);
		g_witchVtable = vt + view_as<Address>(8);
	}
	return true;
}

// Check that a WitchLocomotion vtable slot holds the function the gamedata names (a symbol on
// Linux, a signature on Windows).
bool SlotIs(GameData gd, int slot, const char[] addrName)
{
	Address want = gd.GetAddress(addrName);
	return want != Address_Null && VtableSlot(g_witchVtable, slot) == want;
}

// ---- corner ----

bool InitCorner(GameData gd)
{
	g_rc = gd.GetAddress("ResolveCollision");
	int slot = gd.GetOffset("ILocomotion::Update");
	if (g_rc == Address_Null || slot < 0) { LogError("corner fix OFF: ResolveCollision or the Update slot not found"); return false; }
	if (!SlotIs(gd, slot, "ZombieBotLocomotion::Update")) { LogError("corner fix OFF: WitchLocomotion slot %d is not ZombieBotLocomotion::Update", slot); return false; }
	if (g_windows)
	{
		// fcomp dword ptr [1.0f] (D8 1D imm32); fnstsw ax (DF E0); test ah,5 (F6 C4 05); jnp (0F 8B)
		int sites[2] = { 0x1E5, 0x5F6 };
		int expect[13] = { 0xD8, 0x1D, -1, -1, -1, -1, 0xDF, 0xE0, 0xF6, 0xC4, 0x05, 0x0F, 0x8B };
		for (int s = 0; s < 2; s++)
		{
			for (int i = 0; i < 13; i++)
				if (expect[i] != -1 && Byte(g_rc, sites[s] + i) != expect[i])
				{
					LogError("corner fix OFF: ResolveCollision+0x%X+%d is %02X, expected %02X", sites[s], i, Byte(g_rc, sites[s] + i), expect[i]);
					return false;
				}
			Address one = view_as<Address>(LoadFromAddress(g_rc + view_as<Address>(sites[s] + 2), NumberType_Int32));
			if (view_as<float>(LoadFromAddress(one, NumberType_Int32)) != 1.0)
			{
				LogError("corner fix OFF: ResolveCollision+0x%X does not compare against 1.0", sites[s]);
				return false;
			}
			g_sites[s] = sites[s] + 12;
		}
		g_byteOff = 0x8B;
		g_byteOn = 0x80;
	}
	else
	{
		int sites[2] = { 0x3ED, 0x491 };
		int expect[8] = { 0xD9, 0xE8, 0xDF, 0xE9, 0xDD, 0xD8, 0x0F, 0x87 };
		for (int s = 0; s < 2; s++)
		{
			for (int i = 0; i < 8; i++)
				if (Byte(g_rc, sites[s] + i) != expect[i])
				{
					LogError("corner fix OFF: ResolveCollision+0x%X+%d is %02X, expected %02X", sites[s], i, Byte(g_rc, sites[s] + i), expect[i]);
					return false;
				}
			g_sites[s] = sites[s] + 1;
		}
		g_byteOff = 0xE8;
		g_byteOn = 0xEE;
	}
	g_hUpdate = new DynamicHook(slot, HookType_Raw, ReturnType_Void, ThisPointer_Address);
	// make the page writable once; the per-update writes below skip that step
	StoreToAddress(g_rc + view_as<Address>(g_sites[0]), g_byteOff, NumberType_Int8, true);
	StoreToAddress(g_rc + view_as<Address>(g_sites[1]), g_byteOff, NumberType_Int8, true);
	return true;
}

void SetPatch(bool on)
{
	if (!g_okCorner || on == g_patched) return;
	int v = on ? g_byteOn : g_byteOff;
	StoreToAddress(g_rc + view_as<Address>(g_sites[0]), v, NumberType_Int8, false);
	StoreToAddress(g_rc + view_as<Address>(g_sites[1]), v, NumberType_Int8, false);
	g_patched = on;
}

public MRESReturn Update_Pre(Address loco)
{
	if (g_cvCorner.BoolValue) SetPatch(true);
	return MRES_Ignored;
}

public MRESReturn Update_Post(Address loco)
{
	SetPatch(false);
	return MRES_Ignored;
}

// ---- direct ----

bool InitDirect(GameData gd)
{
	int slot = gd.GetOffset("ILocomotion::IsPotentiallyTraversable");
	if (slot < 0) { LogError("direct fix OFF: IsPotentiallyTraversable slot not found"); return false; }
	if (!SlotIs(gd, slot, "ILocomotion::IsPotentiallyTraversable")) { LogError("direct fix OFF: WitchLocomotion slot %d is not IsPotentiallyTraversable", slot); return false; }
	// bool IsPotentiallyTraversable(const Vector &from, const Vector &to, TraverseWhenType when, float *fraction)
	g_hTrav = new DynamicHook(slot, HookType_Raw, ReturnType_Bool, ThisPointer_Address);
	g_hTrav.AddParam(HookParamType_VectorPtr);
	g_hTrav.AddParam(HookParamType_VectorPtr);
	g_hTrav.AddParam(HookParamType_Int);
	g_hTrav.AddParam(HookParamType_Int);
	return true;
}

public MRESReturn Trav_Post(Address loco, DHookReturn ret, DHookParam params)
{
	if (!g_cvDirect.BoolValue || !ret.Value) return MRES_Ignored;
	float from[3], to[3];
	params.GetVector(1, from);
	params.GetVector(2, to);
	if (!OverGap(from, to)) return MRES_Ignored;
	if (g_cvLog.BoolValue)
		LogMessage("direct: refused shortcut %.0f %.0f %.0f -> %.0f %.0f %.0f", from[0], from[1], from[2], to[0], to[1], to[2]);
	ret.Value = false;
	return MRES_Override;
}

// True if, anywhere along the 2D line from -> to, the floor sits more than the drop limit below both
// the straight line and the victim's height: the shortcut would cross a pit or open air. A clean
// drop down to a victim below her passes (the floor never goes lower than the victim stands).
bool OverGap(const float from[3], const float to[3])
{
	float dx = to[0] - from[0], dy = to[1] - from[1];
	float len = SquareRoot(dx * dx + dy * dy);
	// short look-ahead probes from the path follower (about 45 units, at ledge edges before a drop)
	// are not the victim shortcut; leave them to the game
	if (len < g_cvMinLen.FloatValue) return false;
	float step = g_cvStep.FloatValue, drop = g_cvDrop.FloatValue;
	for (float u = step; u < len - 16.0; u += step)
	{
		float f = u / len;
		float a[3], b[3];
		a[0] = from[0] + dx * f; a[1] = from[1] + dy * f;
		float lineZ = from[2] + (to[2] - from[2]) * f;
		// start at her level or the line, whichever is higher, so a trace never begins under the floor she stands on
		a[2] = (lineZ > from[2] ? lineZ : from[2]) + 32.0;
		b[0] = a[0]; b[1] = a[1]; b[2] = (lineZ < to[2] ? lineZ : to[2]) - drop;
		Handle t = TR_TraceRayFilterEx(a, b, MASK_NPCSOLID_BRUSHONLY, RayType_EndPoint, F_World);
		bool hit = TR_DidHit(t);
		delete t;
		if (!hit) return true;
	}
	return false;
}

public bool F_World(int ent, int mask) { return ent == 0 || ent > MaxClients; }

// ---- climb ----

bool InitClimb(GameData gd)
{
	int slotUp = gd.GetOffset("ILocomotion::ClimbUpToLedge");
	int slotOnto = gd.GetOffset("INextBot::IsAbleToClimbOnto");
	g_botOffset = gd.GetOffset("Witch::INextBot");
	if (slotUp < 0 || slotOnto < 0 || g_botOffset <= 0) { LogError("climb fix OFF: an offset is missing from the gamedata"); return false; }
	if (!SlotIs(gd, slotUp, "ZombieBotLocomotion::ClimbUpToLedge")) { LogError("climb fix OFF: WitchLocomotion slot %d is not ZombieBotLocomotion::ClimbUpToLedge", slotUp); return false; }
	// each witch's INextBot vtable is checked (HookWitch) against the function its slot must hold:
	// the Linux this-adjusting thunk, or on Windows Infected::IsAbleToClimbOnto itself
	g_ontoThunk = gd.GetAddress("Infected::IsAbleToClimbOnto (INextBot)");
	if (g_ontoThunk == Address_Null) { LogError("climb fix OFF: Infected::IsAbleToClimbOnto not found"); return false; }
	g_ontoSlot = slotOnto;
	// bool IsAbleToClimbOnto(const CBaseEntity *object)
	g_hOnto = new DynamicHook(slotOnto, HookType_Raw, ReturnType_Bool, ThisPointer_Address);
	g_hOnto.AddParam(HookParamType_CBaseEntity);
	// bool ClimbUpToLedge(const Vector &landingGoal, const Vector &landingForward, const CBaseEntity *obstacle)
	g_hUpPre = new DynamicHook(slotUp, HookType_Raw, ReturnType_Bool, ThisPointer_Address);
	g_hUpPre.AddParam(HookParamType_VectorPtr);
	g_hUpPre.AddParam(HookParamType_VectorPtr);
	g_hUpPre.AddParam(HookParamType_CBaseEntity);
	g_hUpPost = new DynamicHook(slotUp, HookType_Raw, ReturnType_Bool, ThisPointer_Address);
	g_hUpPost.AddParam(HookParamType_VectorPtr);
	g_hUpPost.AddParam(HookParamType_VectorPtr);
	g_hUpPost.AddParam(HookParamType_CBaseEntity);
	return true;
}

int WitchByLoco(Address a)
{
	for (int w = MaxClients + 1; w < 2048; w++) if (g_loco[w] == a && a != Address_Null) return w;
	return -1;
}

int WitchByBot(Address a)
{
	for (int w = MaxClients + 1; w < 2048; w++) if (g_bot[w] == a && a != Address_Null) return w;
	return -1;
}

bool IsBanned(int w, int ent)
{
	float now = GetGameTime();
	for (int i = 0; i < BANS; i++) if (g_ban[w][i] == ent && g_banUntil[w][i] > now) return true;
	return false;
}

void Ban(int w, int ent)
{
	int slot = 0;
	for (int i = 0; i < BANS; i++) if (g_banUntil[w][i] < g_banUntil[w][slot]) slot = i;
	g_ban[w][slot] = ent;
	g_banUntil[w][slot] = GetGameTime() + g_cvBan.FloatValue;
}

bool IsRepeat(int w, const float goal[3], const float start[3])
{
	return GetGameTime() - g_lastT[w] < 3.0 && GetVectorDistance(goal, g_lastGoal[w]) < 32.0 && GetVectorDistance(start, g_lastStart[w]) < 48.0;
}

// an object she failed to climb stays off limits (the path follower asks before every ledge it tries)
public MRESReturn Onto_Post(Address bot, DHookReturn ret, DHookParam params)
{
	if (!g_cvClimb.BoolValue || !ret.Value || params.IsNull(1)) return MRES_Ignored;
	int ent = params.Get(1);
	if (ent <= 0) return MRES_Ignored;
	int w = WitchByBot(bot);
	if (w <= 0 || !IsBanned(w, ent)) return MRES_Ignored;
	ret.Value = false;
	return MRES_Override;
}

// refuse, before it starts, a repeat climb onto an entity (and ban it)
public MRESReturn Up_Pre(Address loco, DHookReturn ret, DHookParam params)
{
	if (!g_cvClimb.BoolValue || params.IsNull(3)) return MRES_Ignored;
	int ent = params.Get(3);
	if (ent <= 0) return MRES_Ignored;
	int w = WitchByLoco(loco);
	if (w <= 0) return MRES_Ignored;
	float p[3]; GetEntPropVector(w, Prop_Send, "m_vecOrigin", p);
	float goal[3]; params.GetVector(1, goal);
	bool banned = IsBanned(w, ent);
	if (!banned && !IsRepeat(w, goal, p)) return MRES_Ignored;
	if (!banned)
	{
		Ban(w, ent);
		if (g_cvLog.BoolValue)
		{
			char cls[64]; GetEntityClassname(ent, cls, sizeof(cls));
			LogMessage("climb: witch %d keeps sliding off %d %s at %.0f %.0f %.0f, off limits for %.0f s", w, ent, cls, p[0], p[1], p[2], g_cvBan.FloatValue);
		}
	}
	ret.Value = false;
	return MRES_Supercede;
}

// remember each climb; a repeat world climb arms the lip assist for the one after it
public MRESReturn Up_Post(Address loco, DHookReturn ret, DHookParam params)
{
	if (!g_cvClimb.BoolValue || !ret.Value) return MRES_Ignored;
	int ent = params.IsNull(3) ? 0 : params.Get(3);
	if (ent < 0) ent = 0;
	int w = WitchByLoco(loco);
	if (w <= 0) return MRES_Ignored;
	float p[3]; GetEntPropVector(w, Prop_Send, "m_vecOrigin", p);
	float goal[3]; params.GetVector(1, goal);
	float fwd[3]; params.GetVector(2, fwd);
	float dx = fwd[0], dy = fwd[1];
	if (dx * dx + dy * dy < 0.0001) { dx = goal[0] - p[0]; dy = goal[1] - p[1]; }
	float dl = SquareRoot(dx * dx + dy * dy);
	if (dl > 0.01) { dx /= dl; dy /= dl; }
	float now = GetGameTime();
	bool repeat = IsRepeat(w, goal, p);
	g_lastGoal[w] = goal; g_lastStart[w] = p; g_lastT[w] = now;
	if (ent != 0) return MRES_Ignored;
	if (repeat && g_failUntil[w] < now)
	{
		g_failGoal[w] = goal;
		g_failUntil[w] = now + 20.0;
	}
	if (g_failUntil[w] > now && GetVectorDistance(goal, g_failGoal[w]) < 32.0 && g_slideStep[w] == 0 && g_cvAssist.FloatValue > 0.0)
	{
		g_watchGoal[w] = goal;
		g_watchDir[w][0] = dx; g_watchDir[w][1] = dy;
		g_watchUntil[w] = now + 1.6;
	}
	return MRES_Ignored;
}

public void OnGameFrame()
{
	if (!g_okClimb) return;
	float now = GetGameTime();
	for (int w = MaxClients + 1; w < 2048; w++)
	{
		if (g_loco[w] == Address_Null) continue;
		if (g_slideStep[w] > 0)
		{
			// fly the slide over 4 frames
			float f = g_slideStep[w] / 4.0, q[3];
			for (int i = 0; i < 3; i++) q[i] = g_slideFrom[w][i] + (g_slideTo[w][i] - g_slideFrom[w][i]) * f;
			TeleportEntity(w, q, NULL_VECTOR, view_as<float>({ 0.0, 0.0, 0.0 }));
			if (++g_slideStep[w] > 4) g_slideStep[w] = 0;
			continue;
		}
		if (g_watchUntil[w] < now) continue;
		float p[3]; GetEntPropVector(w, Prop_Send, "m_vecOrigin", p);
		if (p[2] < g_watchGoal[w][2] - 20.0) continue; // not up at the lip yet
		g_watchUntil[w] = 0.0;
		float to[3];
		if (FindStandable(w, p, g_watchDir[w], to))
		{
			g_slideFrom[w] = p; g_slideTo[w] = to; g_slideStep[w] = 1;
			if (g_cvLog.BoolValue)
				LogMessage("climb: witch %d slid %.0f units off the lip at %.0f %.0f %.0f to %.0f %.0f %.0f", w, GetVectorDistance(p, to), p[0], p[1], p[2], to[0], to[1], to[2]);
		}
		else if (g_cvLog.BoolValue)
			LogMessage("climb: witch %d at the lip %.0f %.0f %.0f, no spot to stand on ahead", w, p[0], p[1], p[2]);
	}
}

// First spot 8.._climb_assist units along dir from p where the floor (found within +40/-24 of her
// height) is gentle enough to stand on (normal z >= 0.7) and her hull fits one step height up.
bool FindStandable(int w, const float p[3], const float dir[2], float out[3])
{
	float mins[3] = { -13.0, -13.0, 0.0 }, maxs[3] = { 13.0, 13.0, 72.0 };
	float maxd = g_cvAssist.FloatValue;
	for (float u = 8.0; u <= maxd; u += 4.0)
	{
		float a[3], b[3];
		a[0] = p[0] + dir[0] * u; a[1] = p[1] + dir[1] * u; a[2] = p[2] + 40.0;
		b[0] = a[0]; b[1] = a[1]; b[2] = p[2] - 24.0;
		Handle t = TR_TraceRayFilterEx(a, b, MASK_NPCSOLID, RayType_EndPoint, F_NotWitch, w);
		bool hit = TR_DidHit(t);
		float hp[3], n[3];
		if (hit) { TR_GetEndPosition(hp, t); TR_GetPlaneNormal(t, n); }
		delete t;
		if (!hit || n[2] < 0.7) continue;
		// test her hull one step height up (a rounded top rises inside her 26 unit footprint), then
		// drop it onto the floor so she lands standing, as the game's ground constraint would
		float c[3]; c = hp; c[2] += 18.0;
		Handle h = TR_TraceHullFilterEx(c, c, mins, maxs, MASK_NPCSOLID, F_NotWitch, w);
		bool blocked = TR_DidHit(h);
		delete h;
		if (blocked) continue;
		float down[3]; down = c; down[2] -= 36.0;
		Handle h2 = TR_TraceHullFilterEx(c, down, mins, maxs, MASK_NPCSOLID, F_NotWitch, w);
		TR_GetEndPosition(out, h2);
		delete h2;
		out[2] += 0.5;
		return true;
	}
	return false;
}

public bool F_NotWitch(int ent, int mask, int w) { return ent != w && (ent == 0 || ent > MaxClients); }

// ---- fire ----

public Action OnWitchDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (!g_cvFire.BoolValue || !(damagetype & DMG_BURN)) return Plugin_Continue;
	if (attacker >= 1 && attacker <= MaxClients && IsClientInGame(attacker) && GetClientTeam(attacker) == 2)
		return Plugin_Continue;
	// a burn tick from her own flame: map fire never gets to light her, so a survivor started it
	int flame = GetEntPropEnt(victim, Prop_Send, "m_hEffectEntity");
	if (flame > MaxClients && inflictor == flame)
		return Plugin_Continue;
	return Plugin_Handled;
}

// ---- per witch ----

public void OnEntityCreated(int entity, const char[] classname)
{
	if (entity <= MaxClients || entity >= 2048 || !StrEqual(classname, "witch")) return;
	SDKHook(entity, SDKHook_OnTakeDamage, OnWitchDamage);
	// the locomotion object is built in Witch::CreateComponents, after creation: wait a frame
	RequestFrame(F_Hook, EntIndexToEntRef(entity));
}

public void F_Hook(int ref)
{
	int w = EntRefToEntIndex(ref);
	if (w != INVALID_ENT_REFERENCE) HookWitch(w);
}

void HookWitch(int w)
{
	if (!g_okCorner && !g_okDirect && !g_okClimb) return;
	if (g_loco[w] != Address_Null) return;
	Address loco = view_as<Address>(LoadFromAddress(GetEntityAddress(w) + view_as<Address>(g_locoOffset), NumberType_Int32));
	if (loco == Address_Null) { LogError("witch %d has no locomotion yet", w); return; }
	Address vt = view_as<Address>(LoadFromAddress(loco, NumberType_Int32));
	if (vt != g_witchVtable) { LogError("witch %d locomotion has vtable %X, expected %X; not hooking", w, vt, g_witchVtable); return; }
	g_loco[w] = loco;
	if (g_okCorner)
	{
		g_idUpdPre[w] = g_hUpdate.HookRaw(Hook_Pre, loco, Update_Pre);
		g_idUpdPost[w] = g_hUpdate.HookRaw(Hook_Post, loco, Update_Post);
	}
	if (g_okDirect) g_idTrav[w] = g_hTrav.HookRaw(Hook_Post, loco, Trav_Post);
	if (g_okClimb)
	{
		Address bot = GetEntityAddress(w) + view_as<Address>(g_botOffset);
		Address bvt = view_as<Address>(LoadFromAddress(bot, NumberType_Int32));
		if (VtableSlot(bvt, g_ontoSlot) != g_ontoThunk)
		{
			LogError("witch %d INextBot slot %d is not Infected::IsAbleToClimbOnto; climb fix not hooked on her", w, g_ontoSlot);
		}
		else
		{
			g_bot[w] = bot;
			g_idOnto[w] = g_hOnto.HookRaw(Hook_Post, bot, Onto_Post);
			g_idUpPre[w] = g_hUpPre.HookRaw(Hook_Pre, loco, Up_Pre);
			g_idUpPost[w] = g_hUpPost.HookRaw(Hook_Post, loco, Up_Post);
		}
	}
	for (int i = 0; i < BANS; i++) { g_ban[w][i] = 0; g_banUntil[w][i] = 0.0; }
	g_lastT[w] = g_failUntil[w] = g_watchUntil[w] = 0.0;
	g_slideStep[w] = 0;
}

public void OnEntityDestroyed(int entity)
{
	if (entity > MaxClients && entity < 2048) Unhook(entity);
}

void RemoveId(int &id)
{
	if (id != INVALID_HOOK_ID) { DynamicHook.RemoveHook(id); id = INVALID_HOOK_ID; }
}

void Unhook(int i)
{
	RemoveId(g_idUpdPre[i]);
	RemoveId(g_idUpdPost[i]);
	RemoveId(g_idTrav[i]);
	RemoveId(g_idOnto[i]);
	RemoveId(g_idUpPre[i]);
	RemoveId(g_idUpPost[i]);
	g_loco[i] = g_bot[i] = Address_Null;
	g_slideStep[i] = 0;
	g_watchUntil[i] = 0.0;
}
