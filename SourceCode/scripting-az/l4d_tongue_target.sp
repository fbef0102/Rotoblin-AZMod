#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <dhooks>

#define PLUGIN_VERSION "0.3"
#define GAMEDATA "l4d_tongue_target"

#define TEAM_SURVIVOR	2
#define TEAM_INFECTED	3
#define ZC_SMOKER		1

#define HIST			256		// survivor position history, one entry per server tick

#define MASK_TONGUE_LOS	0x42006081	// TongueTargetScan<CTerrorPlayer>::IsTargetVisible (MASK_VISIBLE_AND_NPCS | CONTENTS_HITBOX)
#define DEFAULT_FOV		0.766		// CBasePlayer::Spawn sets m_flFieldOfView to this

// Why this exists: the smoker's tongue does not hit the survivor in front.
//
// While the ability is ready, CTongue::UpdateTongueTarget re-picks m_potentialTarget every
// think: each survivor in range and line of sight is scored by the angle between the
// smoker's aim and the nearest point of the survivor's box to the aim line, and the
// highest dot wins. On the click, CTongue::ActivateAbility runs that scan once more and
// enters the extending state, whose OnEnterExtendingState copies m_potentialTarget into
// m_currentTipTarget. The tongue then flies to that survivor wherever he goes.
//
// Two things in that scan pick a survivor the smoker did not aim at:
//   * Ties: when the crosshair passes through two or three survivors' boxes, all of them
//     score a perfect dot and the first in client order wins, so the tongue flies past the
//     survivor in front to one behind him (match 645, Bridge, 2026-10-11). Two survivors
//     a fraction of a degree apart go the same way: the far one can win by 0.1 degrees
//     (match 645, Train Tunnel, the tongue that ruined a quad).
//   * No lag compensation: survivors are scored where the server has them now, not where
//     the smoker saw them (ping + lerp ago).
//
// This plugin re-scores at that moment (a pre-hook on OnEnterExtendingState, so the
// engine still does the latching, sounds and everything after), using survivor positions
// rewound by the smoker's latency + lerp. Every survivor within l4d_tongue_target_tie_deg
// of the best angle counts as on the crosshair, and the NEAREST of them gets the tongue.
// It only ever changes a tongue the game already aimed at someone (a miss stays a miss),
// and the survivor it picks must pass the game's own target filters right now (0.2, from
// the server.so decompile, l4d-source docs/annotated/smoker-tongue/):
//   * TongueTargetScan::IsPotentialTarget: alive, not incapped, falling from a ledge
//     (m_isFallingFromLedge, +0x2712), pinned or tongued, not FL_ONTRAIN or FL_FROZEN.
//   * Range: WorldSpaceCenter within tongue_range of the smoker's eye.
//   * FInViewCone(WorldSpaceCenter): a flat (yaw-only) cone, m_flFieldOfView 0.766, so a
//     survivor more than about 40 degrees to either side of the smoker's facing is out, at
//     any height (0.3: 0.2 kept the height in the length and refused steep picks the game allows).
//   * IsTargetVisible: one ray eye to eye, mask 0x42006081, smoker ignored, common
//     infected, the witch (Witch derives from Infected) and ghosts ignored, but survivors and
//     special infected BLOCK. The flight (OnUpdateExtendingState) re-checks this line and
//     drops the tongue when it stays blocked, so a pick that fails it turns a grab into a miss.
// 0.1 traced world only to chest or eyes, which let it pick survivors the game then dropped.
//
// "seen" is the moment the smoker's screen showed, worked out like the engine's lag
// compensation: the usercmd's tick_count minus his interpolation, against a history stamped
// in server ticks. (0.1 subtracted ping + lerp from GetGameTime, which inside a usercmd is
// the player's tick-base clock, ahead of the frame clock the history used.)
//
// l4d_tongue_target_tie_deg only decides who counts as tied. The rewind can change the pick
// at any margin: the survivor best aimed at as the smoker saw it wins over the server's
// present-time pick even when no tie is involved.

ConVar g_hCvarMode, g_hCvarTie, g_hCvarLog, g_hCvarRange, g_hCvarBots;
char g_sLogPath[PLATFORM_MAX_PATH];

int g_iHT[MAXPLAYERS + 1][HIST];		// server tick the entry describes the state after
float g_fHP[MAXPLAYERS + 1][HIST][3];
float g_fHTop[MAXPLAYERS + 1][HIST];
int g_iHHead[MAXPLAYERS + 1];
int g_iHCount[MAXPLAYERS + 1];

int g_iCmdTick[MAXPLAYERS + 1];			// tick_count of the usercmd running for this client

int g_iPendingPick[MAXPLAYERS + 1];		// smoker -> userid of the survivor his tongue was sent to
float g_fPendingAt[MAXPLAYERS + 1];
bool g_bPendingChanged[MAXPLAYERS + 1];	// that target was ours, not the game's

// outcome counts, [0] = the game's own target, [1] = a target we changed it to
int g_iStatTongues, g_iStatTies, g_iStatChanged, g_iStatMiss, g_iStatGrabbed[2], g_iStatDropped[2];
int g_iMapTongues, g_iMapTies, g_iMapChanged, g_iMapMiss, g_iMapGrabbed[2], g_iMapDropped[2];

public Plugin myinfo =
{
	name = "[L4D1] Tongue Target",
	author = "Malevolence",
	description = "A tongue aimed through several survivors goes to the nearest one, judged on what the smoker saw.",
	version = PLUGIN_VERSION,
	url = ""
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if( GetEngineVersion() != Engine_Left4Dead )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	GameData gd = new GameData(GAMEDATA);
	if( gd == null ) SetFailState("Missing gamedata \"%s\"", GAMEDATA);
	DynamicDetour d = DynamicDetour.FromConf(gd, "CTongue::OnEnterExtendingState");
	if( d == null || !d.Enable(Hook_Pre, Detour_OnEnterExtendingState) ) SetFailState("Failed to detour CTongue::OnEnterExtendingState");
	delete gd;

	CreateConVar("l4d_tongue_target_version", PLUGIN_VERSION, "Tongue Target version", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_hCvarMode = CreateConVar("l4d_tongue_target_mode", "1", "0 = off. 1 = log what it would do, change nothing. 2 = on.", FCVAR_NOTIFY, true, 0.0, true, 2.0);
	g_hCvarTie = CreateConVar("l4d_tongue_target_tie_deg", "1.0", "Survivors within this many degrees of the best-aimed one count as on the crosshair; the nearest of them gets the tongue.", FCVAR_NOTIFY, true, 0.0, true, 10.0);
	g_hCvarLog = CreateConVar("l4d_tongue_target_log", "1", "Log every human tongue to logs/tongue_target.log.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_hCvarRange = FindConVar("tongue_range");
	if( g_hCvarRange == null ) SetFailState("Missing cvar tongue_range");

	g_hCvarBots = CreateConVar("l4d_tongue_target_bots", "0", "Also judge AI smokers' tongues (testing only).", FCVAR_NONE, true, 0.0, true, 1.0);

	HookEvent("tongue_grab", Event_TongueGrab);

	RegAdminCmd("sm_tonguetarget_stats", Cmd_Stats, ADMFLAG_ROOT, "Human tongues seen, ties and changes since load.");
	BuildPath(Path_SM, g_sLogPath, sizeof(g_sLogPath), "logs/tongue_target.log");
}

public void OnMapEnd()
{
	if( g_iMapTongues > 0 && g_hCvarLog.BoolValue && g_hCvarMode.BoolValue )
	{
		char map[64];
		GetCurrentMap(map, sizeof(map));
		LogToFileEx(g_sLogPath, "SUMMARY map=%s mode=%d human_tongues=%d ties=%d changed=%d misses=%d game_target grabbed=%d dropped=%d our_target grabbed=%d dropped=%d",
			map, g_hCvarMode.IntValue, g_iMapTongues, g_iMapTies, g_iMapChanged, g_iMapMiss,
			g_iMapGrabbed[0], g_iMapDropped[0], g_iMapGrabbed[1], g_iMapDropped[1]);
	}
	g_iMapTongues = 0; g_iMapTies = 0; g_iMapChanged = 0; g_iMapMiss = 0;
	g_iMapGrabbed[0] = 0; g_iMapGrabbed[1] = 0; g_iMapDropped[0] = 0; g_iMapDropped[1] = 0;
}

public void OnMapStart()
{
	for( int i = 1; i <= MaxClients; i++ ) { g_iHCount[i] = 0; g_iPendingPick[i] = 0; }
}

public void OnClientDisconnect(int client)
{
	g_iHCount[client] = 0;
	g_iPendingPick[client] = 0;
}

Action Cmd_Stats(int client, int args)
{
	ReplyToCommand(client, "[tongue_target] mode=%d tie_deg=%.2f human_tongues=%d ties=%d changed=%d misses=%d | game target grabbed %d dropped %d | our target grabbed %d dropped %d",
		g_hCvarMode.IntValue, g_hCvarTie.FloatValue, g_iStatTongues, g_iStatTies, g_iStatChanged, g_iStatMiss,
		g_iStatGrabbed[0], g_iStatDropped[0], g_iStatGrabbed[1], g_iStatDropped[1]);
	return Plugin_Handled;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	g_iCmdTick[client] = tickcount;
	return Plugin_Continue;
}

// The server tick whose state the smoker's screen showed when he clicked: the usercmd's
// tick_count minus his interpolation, clamped to a second back like sv_maxunlag.
int SeenTick(int client)
{
	int now = GetGameTickCount();
	if( IsFakeClient(client) ) return now;
	float interval = GetTickInterval();
	int seen = g_iCmdTick[client] - RoundToNearest(GetEntPropFloat(client, Prop_Data, "m_fLerpTime") / interval);
	int oldest = now - RoundToNearest(1.0 / interval);
	if( seen > now ) seen = now;
	if( seen < oldest ) seen = oldest;
	return seen;
}

public void OnGameFrame()
{
	if( !g_hCvarMode.BoolValue ) return;
	// OnGameFrame runs at the start of the tick, before any usercmd: what it reads is the
	// state after the previous tick, which is what clients were sent for that tick.
	int tick = GetGameTickCount() - 1;
	for( int i = 1; i <= MaxClients; i++ )
	{
		if( !IsClientInGame(i) || GetClientTeam(i) != TEAM_SURVIVOR || !IsPlayerAlive(i) )
		{
			g_iHCount[i] = 0;		// no history carried over from an earlier life or team
			continue;
		}
		int h = (g_iHHead[i] + 1) % HIST;
		float pos[3], maxs[3];
		GetClientAbsOrigin(i, pos);
		GetClientMaxs(i, maxs);
		g_iHT[i][h] = tick;
		g_fHP[i][h] = pos;
		g_fHTop[i][h] = maxs[2];
		g_iHHead[i] = h;
		if( g_iHCount[i] < HIST ) g_iHCount[i]++;
	}
}

// survivor's position after tick t (newest entry at or before t); false if not recorded
bool SurvivorAt(int client, int t, float pos[3], float &top)
{
	int n = g_iHCount[client];
	int h = g_iHHead[client];
	for( int k = 0; k < n; k++ )
	{
		int idx = (h - k + HIST) % HIST;
		if( g_iHT[client][idx] <= t )
		{
			pos = g_fHP[client][idx];
			top = g_fHTop[client][idx];
			return true;
		}
	}
	return false;
}

// The game's score, as an angle: the aim line's closest point to the box centre, clamped
// into the survivor's box (32 x 32 x top), then the angle from the aim to that point.
// 0 means the crosshair passes through the box.
float AimAngle(const float eye[3], const float fwd[3], const float o[3], float top)
{
	float c[3], d[3], q[3], n[3];
	c[0] = o[0]; c[1] = o[1]; c[2] = o[2] + top * 0.5;
	SubtractVectors(c, eye, d);
	float t = GetVectorDotProduct(d, fwd);
	if( t < 0.0 ) t = 0.0;
	for( int k = 0; k < 3; k++ ) q[k] = eye[k] + fwd[k] * t;
	n[0] = Clamp(q[0], o[0] - 16.0, o[0] + 16.0);
	n[1] = Clamp(q[1], o[1] - 16.0, o[1] + 16.0);
	n[2] = Clamp(q[2], o[2], o[2] + top);
	float v[3];
	SubtractVectors(n, eye, v);
	float len = GetVectorLength(v);
	if( len < 1.0 ) return 0.0;
	float dot = GetVectorDotProduct(v, fwd) / len;
	if( dot > 1.0 ) dot = 1.0;
	if( dot < -1.0 ) dot = -1.0;
	return RadToDeg(ArcCosine(dot));
}

float Clamp(float x, float lo, float hi)
{
	return x < lo ? lo : (x > hi ? hi : x);
}

// TongueTargetScan<CTerrorPlayer>::IsTargetVisible in versus: CTraceFilterSimpleListNoInfectedOrGhosts
// with the smoker on the ignore list. Commons and the witch never block, ghosts never block,
// every other player does.
bool TraceTongueFilter(int entity, int contentsMask, int smoker)
{
	if( entity == smoker ) return false;
	if( entity >= 1 && entity <= MaxClients ) return !GetEntProp(entity, Prop_Send, "m_isGhost");
	if( entity > MaxClients && IsValidEdict(entity) )
	{
		char cls[16];
		GetEdictClassname(entity, cls, sizeof(cls));
		if( StrEqual(cls, "infected") || StrEqual(cls, "witch") ) return false;
	}
	return true;
}

// the game's line of sight: smoker's eye to the survivor's eye, clear or the survivor himself
bool CanSee(int smoker, const float eye[3], int survivor)
{
	float head[3];
	GetClientEyePosition(survivor, head);
	Handle tr = TR_TraceRayFilterEx(eye, head, MASK_TONGUE_LOS, RayType_EndPoint, TraceTongueFilter, smoker);
	bool clear = !TR_DidHit(tr) || TR_GetEntityIndex(tr) == survivor;
	delete tr;
	return clear;
}

// CBaseCombatCharacter::FInViewCone: flat facing (yaw only) and a flat line to the spot: Valve sets the
// eye height to the spot's (server.so 0x3a5d4c / 0x3a5d7b), an infinitely tall cone as in the SDK
bool InViewCone(int smoker, const float eye[3], const float ang[3], const float spot[3])
{
	float fov = DEFAULT_FOV;
	if( HasEntProp(smoker, Prop_Data, "m_flFieldOfView") ) fov = GetEntPropFloat(smoker, Prop_Data, "m_flFieldOfView");
	float yaw[3], facing[3], los[3];
	yaw[1] = ang[1];
	GetAngleVectors(yaw, facing, NULL_VECTOR, NULL_VECTOR);
	SubtractVectors(spot, eye, los);
	los[2] = 0.0;
	float dot = GetVectorDotProduct(facing, los);
	if( fov > 0.0 )
	{
		if( dot < 0.0 ) return false;
		return fov * fov * GetVectorDotProduct(los, los) <= dot * dot;
	}
	return dot > 0.0 || dot * dot <= fov * fov * GetVectorDotProduct(los, los);
}

// TongueTargetScan::IsPotentialTarget: standing, free, not already somebody's victim
bool Grabbable(int s)
{
	if( !IsClientInGame(s) || GetClientTeam(s) != TEAM_SURVIVOR || !IsPlayerAlive(s) ) return false;
	if( GetEntProp(s, Prop_Send, "m_isIncapacitated") || GetEntProp(s, Prop_Send, "m_isFallingFromLedge") ) return false;	// +0x2712, as the game tests it (a hanging survivor is incapped)
	if( GetEntPropEnt(s, Prop_Send, "m_tongueOwner") > 0 || GetEntPropEnt(s, Prop_Send, "m_pounceAttacker") > 0 ) return false;
	if( GetEntityFlags(s) & (FL_ONTRAIN | FL_FROZEN) ) return false;	// 0x28, as the game tests it
	return true;
}

// why a survivor other than the game's pick may not get the tongue, "" if he may
char[] Reject(int smoker, const float eye[3], const float ang[3], int s, const float center[3], float range)
{
	char why[8];
	if( !Grabbable(s) ) why = "state";
	else if( GetVectorDistance(eye, center) > range ) why = "range";
	else if( !InViewCone(smoker, eye, ang, center) ) why = "cone";
	else if( !CanSee(smoker, eye, s) ) why = "los";
	return why;
}

MRESReturn Detour_OnEnterExtendingState(int tongue)
{
	int mode = g_hCvarMode.IntValue;
	if( mode == 0 || tongue <= MaxClients || !IsValidEntity(tongue) ) return MRES_Ignored;
	int smoker = GetEntPropEnt(tongue, Prop_Send, "m_owner");
	if( smoker < 1 || smoker > MaxClients || !IsClientInGame(smoker) || (IsFakeClient(smoker) && !g_hCvarBots.BoolValue) ) return MRES_Ignored;
	if( GetClientTeam(smoker) != TEAM_INFECTED || GetEntProp(smoker, Prop_Send, "m_zombieClass") != ZC_SMOKER ) return MRES_Ignored;

	g_iStatTongues++; g_iMapTongues++;
	int engine = GetEntPropEnt(tongue, Prop_Send, "m_potentialTarget");
	bool log = g_hCvarLog.BoolValue;
	if( engine < 1 || engine > MaxClients )
	{
		g_iStatMiss++; g_iMapMiss++;
		if( log ) LogToFileEx(g_sLogPath, "MISS smoker=%L", smoker);
		return MRES_Ignored;
	}

	float eye[3], ang[3], fwd[3];
	GetClientEyePosition(smoker, eye);
	GetClientEyeAngles(smoker, ang);
	GetAngleVectors(ang, fwd, NULL_VECTOR, NULL_VECTOR);
	int seen = SeenTick(smoker);
	int back = GetGameTickCount() - seen;
	float range = g_hCvarRange.FloatValue;

	int cand[MAXPLAYERS + 1], nc;
	float candAng[MAXPLAYERS + 1], candDist[MAXPLAYERS + 1], candNowAng[MAXPLAYERS + 1];
	bool candOk[MAXPLAYERS + 1];
	char candWhy[MAXPLAYERS + 1][8];
	float best = 999.0;
	for( int s = 1; s <= MaxClients; s++ )
	{
		if( !IsClientInGame(s) || GetClientTeam(s) != TEAM_SURVIVOR || !IsPlayerAlive(s) ) continue;
		float now[3], then[3], top, maxs[3];
		GetClientAbsOrigin(s, now);
		GetClientMaxs(s, maxs);
		if( !SurvivorAt(s, seen, then, top) ) { then = now; top = maxs[2]; }
		float c[3];
		c[0] = now[0]; c[1] = now[1]; c[2] = now[2] + maxs[2] * 0.5;
		float dist = GetVectorDistance(eye, c);
		// the engine's own pick is always a candidate; anyone else must pass the game's filters
		candWhy[nc] = "";
		if( s != engine ) strcopy(candWhy[nc], sizeof(candWhy[]), Reject(smoker, eye, ang, s, c, range));
		bool ok = candWhy[nc][0] == '\0';
		cand[nc] = s;
		candAng[nc] = AimAngle(eye, fwd, then, top);
		candNowAng[nc] = AimAngle(eye, fwd, now, maxs[2]);
		candDist[nc] = dist;
		candOk[nc] = ok;
		if( ok && candAng[nc] < best ) best = candAng[nc];
		nc++;
	}

	// nearest survivor on the crosshair as the smoker saw it
	float tie = g_hCvarTie.FloatValue;
	int pick = 0, ties = 0;
	float pickDist = 99999.0;
	for( int k = 0; k < nc; k++ )
	{
		if( !candOk[k] || candAng[k] > best + tie ) continue;
		ties++;
		if( candDist[k] < pickDist ) { pickDist = candDist[k]; pick = cand[k]; }
	}
	if( ties > 1 ) { g_iStatTies++; g_iMapTies++; }

	bool change = pick > 0 && pick != engine;
	if( change ) { g_iStatChanged++; g_iMapChanged++; }
	bool ours = change && mode == 2;
	if( ours ) SetEntPropEnt(tongue, Prop_Send, "m_potentialTarget", pick);
	// watch where the tongue lands, ours or the game's
	g_iPendingPick[smoker] = GetClientUserId(ours ? pick : engine);
	g_fPendingAt[smoker] = GetGameTime();
	g_bPendingChanged[smoker] = ours;
	CreateTimer(2.5, Timer_PickOutcome, GetClientUserId(smoker), TIMER_FLAG_NO_MAPCHANGE);

	if( log )
	{
		char line[512];
		for( int k = 0; k < nc; k++ )
		{
			Format(line, sizeof(line), "%s %s%N seen=%.2f now=%.2f d=%.0f%s%s", line,
				cand[k] == engine ? "game:" : (cand[k] == pick ? "pick:" : ""), cand[k],
				candAng[k], candNowAng[k], candDist[k], candOk[k] ? "" : " (no:", candOk[k] ? "" : candWhy[k]);
			if( !candOk[k] ) StrCat(line, sizeof(line), ")");
		}
		LogToFileEx(g_sLogPath, "%s smoker=%L back=%dt ties=%d |%s",
			change ? (mode == 2 ? "CHANGED" : "WOULD_CHANGE") : (ties > 1 ? "TIE_KEPT" : "SAME"), smoker, back, ties, line);
	}
	return MRES_Ignored;
}

// Did the tongue grab the survivor it was sent to? A drop means a check the game makes in
// flight failed (line of sight blocked for over a second, geometry in the tip's path) or the
// smoker was interrupted. Counted separately for the game's targets and ours, so ours can be
// held against the game's own drop rate.
void Event_TongueGrab(Event event, const char[] name, bool dontBroadcast)
{
	int smoker = GetClientOfUserId(event.GetInt("userid"));
	if( smoker < 1 || g_iPendingPick[smoker] == 0 ) return;
	int victim = GetClientOfUserId(event.GetInt("victim"));
	int want = GetClientOfUserId(g_iPendingPick[smoker]);
	int k = g_bPendingChanged[smoker] ? 1 : 0;
	g_iPendingPick[smoker] = 0;
	if( victim == want ) { g_iStatGrabbed[k]++; g_iMapGrabbed[k]++; }
	else { g_iStatDropped[k]++; g_iMapDropped[k]++; }
	if( k == 1 && g_hCvarLog.BoolValue )
		LogToFileEx(g_sLogPath, "%s smoker=%N victim=%N picked=%N after=%.2fs", victim == want ? "GRABBED" : "GRABBED_OTHER",
			smoker, victim, want > 0 ? want : smoker, GetGameTime() - g_fPendingAt[smoker]);
}

Action Timer_PickOutcome(Handle timer, int userid)
{
	int smoker = GetClientOfUserId(userid);
	if( smoker < 1 || g_iPendingPick[smoker] == 0 ) return Plugin_Stop;
	if( GetGameTime() - g_fPendingAt[smoker] < 2.4 ) return Plugin_Stop;	// a newer tongue owns the slot
	int want = GetClientOfUserId(g_iPendingPick[smoker]);
	int k = g_bPendingChanged[smoker] ? 1 : 0;
	g_iPendingPick[smoker] = 0;
	g_iStatDropped[k]++; g_iMapDropped[k]++;
	if( g_hCvarLog.BoolValue && want > 0 )
		LogToFileEx(g_sLogPath, "DROPPED smoker=%N target=%N (%s, no grab within 2.5 s)", smoker, want, k ? "ours" : "the game's");
	return Plugin_Stop;
}