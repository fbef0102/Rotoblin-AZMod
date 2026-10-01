/**
 * l4d_witch_unstuck: hops a startled witch past whatever she is stuck on.
 *
 * A startled witch paths to whoever woke her. On some geometry she can't follow
 * her own path (Blood Harvest 3's fallen bridge: she paces at the lip of the
 * clip brush above her target), and the survivors kill her for free.
 *
 * While she chases, the plugin tracks her best distance to the target. If that
 * hasn't improved by l4d_witch_unstuck_progress units for l4d_witch_unstuck_time
 * seconds, and she has moved less than l4d_witch_unstuck_still in that time (so a
 * witch running a long detour is left alone), she is stuck. She then jumps to the nearest nav spot that is:
 *   - within l4d_witch_unstuck_hop units of her (sideways),
 *   - at least l4d_witch_unstuck_gain units further along her route, by nav
 *     walking distance to the target, so it lies past the obstacle, not beside it
 *     (of those, the one that saves the most walking for the shortest jump),
 *   - no closer than l4d_witch_unstuck_min_dist to the target,
 *   - reachable by a clear jump arc, not blocked, with room for her.
 * With no such spot she is left alone.
 *
 * Mode 2 also NUDGES: a witch frozen in place (a corner snag, common at a low
 * nb_update_frequency) for l4d_witch_unstuck_nudge_after seconds is slid at most
 * l4d_witch_unstuck_nudge units off it, which is barely visible. Each further nudge
 * in the same chase starts further out (8, 16, 24 units).
 *
 * l4d_witch_unstuck_mode 1 (the default) only WATCHES: it logs each stuck episode
 * (START, then END when she moves again, is killed or despawns), every witch that
 * loses her target, and a snapshot whenever a player types !stuckwitch. It never
 * moves a witch. Mode 2 also hops her. The jump is a real arc under gravity so it
 * reads as her leaping over the snag. The engine's movement code ignores a
 * launch velocity, so the plugin flies the arc itself, one step per tick.
 *
 * An infected player can set her off too (a smoker or hunter next to her, a boomer
 * popped on her). The game still sends her after a survivor, but the harasser event
 * names the infected player, so for such a witch the plugin measures progress toward
 * the nearest standing survivor instead, and treats her like any other witch. Her
 * chase ends when she hurts a survivor.
 *
 * Tracking ends when the target is incapped, dies or leaves the survivors, or the
 * witch dies.
 */
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#pragma semicolon 1
#pragma newdecls required

#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3
#define TICK 0.25
#define TRAVEL_CHECKS 24
#define EDGE 16.0           // keep a landing this far inside its nav area
#define MAX_RISE 80.0       // highest she may jump up onto
#define MAX_DROP 400.0      // deepest she may jump down
#define ARC_STEPS 12
#define RETRY 0.5           // seconds until another search after one finds nothing
#define FROZEN_STEP 3.0     // moving less than this per check counts as standing still
#define NUDGE_CHECKS 8      // most walk-distance checks per nudge search

// arc heights tried in turn, above the higher end: a low hop first, a leap over a railing if that is blocked
float g_apexes[] = { 32.0, 64.0, 96.0, 128.0 };

public Plugin myinfo =
{
	name = "L4D Witch Unstuck",
	author = "Riverside",
	description = "Hops a startled witch past whatever she is stuck on",
	version = "2.4.0",
	url = ""
};

ConVar g_cvNudge, g_cvNudgeAfter, g_cvMaxNudges, g_cvMode, g_cvTime, g_cvProgress, g_cvStill, g_cvHop, g_cvGain, g_cvMinDist, g_cvMaxMoves, g_cvLog, g_cvGravity;

// per witch, indexed by entity index; g_ref guards against index reuse
int g_ref[2048] = { INVALID_ENT_REFERENCE, ... };
int g_targetUser[2048];
bool g_nearest[2048];       // set off by an infected player: her target is the nearest standing survivor
int g_setBy[2048];          // userid of that infected player, for the log
float g_best[2048];
float g_bestAt[2048];
float g_anchor[2048][3];    // where she stood when the current window opened
int g_moves[2048];
int g_nudges[2048];
float g_lastPos[2048][3];
float g_frozenFor[2048];    // seconds she has stood still while chasing
bool g_hopping[2048];
bool g_stuck[2048];         // inside a logged stuck episode
float g_stuckAt[2048];
float g_lastReport[MAXPLAYERS + 1];
float g_outApex;
float g_hopFrom[2048][3];
float g_hopVel[2048][3];
float g_hopTo[2048][3];
float g_hopStart[2048];
float g_hopFlight[2048];

char g_log[PLATFORM_MAX_PATH];

public void OnPluginStart()
{
	g_cvMode     = CreateConVar("l4d_witch_unstuck_mode", "1", "0 off, 1 watch only (log stuck witches, never move them), 2 also nudge and hop them past the snag", _, true, 0.0, true, 2.0);
	g_cvTime     = CreateConVar("l4d_witch_unstuck_time", "3.0", "Seconds without progress before she counts as stuck", _, true, 1.0);
	g_cvProgress = CreateConVar("l4d_witch_unstuck_progress", "40.0", "Units she must close within that time to count as moving", _, true, 1.0);
	g_cvStill    = CreateConVar("l4d_witch_unstuck_still", "100.0", "She must also have moved less than this over the window; a witch running a long detour is not stuck", _, true, 1.0);
	g_cvNudge      = CreateConVar("l4d_witch_unstuck_nudge", "24.0", "Longest nudge off a corner she is frozen against (mode 2)", _, true, 4.0);
	g_cvNudgeAfter = CreateConVar("l4d_witch_unstuck_nudge_after", "1.0", "Seconds frozen in place before a nudge", _, true, 0.25);
	g_cvMaxNudges  = CreateConVar("l4d_witch_unstuck_max_nudges", "4", "Most nudges per chase", _, true, 0.0);
	g_cvHop      = CreateConVar("l4d_witch_unstuck_hop", "120.0", "Longest sideways hop", _, true, 16.0);
	g_cvGain     = CreateConVar("l4d_witch_unstuck_gain", "60.0", "A landing must be at least this much shorter a walk to the target", _, true, 1.0);
	g_cvMinDist  = CreateConVar("l4d_witch_unstuck_min_dist", "100.0", "Never land her closer than this to her target", _, true, 0.0);
	g_cvMaxMoves = CreateConVar("l4d_witch_unstuck_max_moves", "4", "Most hops per chase", _, true, 0.0);
	g_cvLog      = CreateConVar("l4d_witch_unstuck_log", "1", "Log to logs/witch_unstuck.log (2 = also every search step); never shown to players", _, true, 0.0, true, 2.0);
	AutoExecConfig(true, "l4d_witch_unstuck");
	g_cvGravity = FindConVar("sv_gravity");

	BuildPath(Path_SM, g_log, sizeof(g_log), "logs/witch_unstuck.log");
	HookEvent("witch_harasser_set", Ev_Harasser);
	HookEvent("witch_killed", Ev_WitchKilled);
	HookEvent("player_hurt", Ev_PlayerHurt);
	RegConsoleCmd("sm_stuckwitch", Cmd_StuckWitch, "Report a stuck witch: logs where every witch and survivor is right now");
	HookEvent("round_start", Ev_RoundStart, EventHookMode_PostNoCopy);
	CreateTimer(TICK, T_Tick, _, TIMER_REPEAT);
}

public void OnMapStart()
{
	ResetAll();
}

public void Ev_RoundStart(Event e, const char[] n, bool nb)
{
	ResetAll();
}

void ResetAll()
{
	for (int i = 0; i < sizeof(g_ref); i++) { g_ref[i] = INVALID_ENT_REFERENCE; g_hopping[i] = false; g_stuck[i] = false; }
}

public void Ev_Harasser(Event e, const char[] n, bool nb)
{
	int witch = e.GetInt("witchid");
	int user = e.GetInt("userid");
	if (witch <= MaxClients || witch >= sizeof(g_ref) || !IsValidEntity(witch)) return;
	g_ref[witch] = EntIndexToEntRef(witch);
	int client = GetClientOfUserId(user);
	g_nearest[witch] = !(client > 0 && IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVOR);
	g_setBy[witch] = g_nearest[witch] ? user : 0;
	g_targetUser[witch] = g_nearest[witch] ? 0 : user;
	g_best[witch] = 999999.0;
	g_bestAt[witch] = GetGameTime();
	GetEntPropVector(witch, Prop_Send, "m_vecOrigin", g_anchor[witch]);
	g_moves[witch] = 0;
	g_nudges[witch] = 0;
	g_frozenFor[witch] = 0.0;
	GetEntPropVector(witch, Prop_Send, "m_vecOrigin", g_lastPos[witch]);
	g_hopping[witch] = false;
	g_stuck[witch] = false;
}

public Action T_Tick(Handle t)
{
	int mode = g_cvMode.IntValue;
	if (mode == 0) return Plugin_Continue;
	float now = GetGameTime();
	for (int w = MaxClients + 1; w < sizeof(g_ref); w++)
	{
		if (g_ref[w] == INVALID_ENT_REFERENCE) continue;
		if (EntRefToEntIndex(g_ref[w]) != w)
		{
			if (g_stuck[w]) Log("END witch %d gone (despawned) while stuck, after %.1fs", w, now - g_stuckAt[w]);
			g_ref[w] = INVALID_ENT_REFERENCE;
			continue;
		}

		if (g_hopping[w]) continue;
		float wp[3], tp[3];
		GetEntPropVector(w, Prop_Send, "m_vecOrigin", wp);
		// her first blow incaps without a player_hurt from her, so a survivor down beside her means she got someone
		int downed = g_nearest[w] ? DownedNear(wp, 120.0) : 0;
		if (downed > 0)
		{
			if (g_stuck[w]) Log("END witch %d moving again after %.1fs stuck: she reached %N", w, now - g_stuckAt[w], downed);
			Log("REACHED witch %d got %N (set off by an infected player)", w, downed);
			g_stuck[w] = false;
			g_ref[w] = INVALID_ENT_REFERENCE;
			continue;
		}
		int target = g_nearest[w] ? NearestChaseable(wp) : GetClientOfUserId(g_targetUser[w]);
		if (g_nearest[w] && target == 0)
		{
			Log("LOST witch %d at %.0f %.0f %.0f seq %d: set off by an infected player, no survivor left standing%s", w, wp[0], wp[1], wp[2], Seq(w),
				g_stuck[w] ? " (was stuck)" : "");
			g_stuck[w] = false;
			g_ref[w] = INVALID_ENT_REFERENCE;
			continue;
		}
		if (!IsChaseable(target))
		{
			// logged every time: a witch that stops when her target goes down elsewhere may be the "crouch" players see
			char why[32];
			TargetState(target, why, sizeof(why));
			float away = -1.0;
			if (target > 0 && IsClientInGame(target))
			{
				GetClientAbsOrigin(target, tp);
				away = GetVectorDistance(wp, tp);
			}
			if (away >= 0.0 && away < 120.0 && !g_stuck[w])
				Log("REACHED witch %d got her target (%s)", w, why);
			else
				Log("LOST witch %d at %.0f %.0f %.0f seq %d: target %s, %.0f away%s", w, wp[0], wp[1], wp[2], Seq(w), why, away,
					g_stuck[w] ? " (was stuck)" : "");
			g_stuck[w] = false;
			g_ref[w] = INVALID_ENT_REFERENCE;
			continue;
		}
		GetClientAbsOrigin(target, tp);
		float d = GetVectorDistance(wp, tp);

		// standing still: a witch frozen on a corner, running animation and all
		if (GetVectorDistance(wp, g_lastPos[w]) < FROZEN_STEP) g_frozenFor[w] += TICK;
		else g_frozenFor[w] = 0.0;
		g_lastPos[w] = wp;
		if (mode == 2 && g_frozenFor[w] >= g_cvNudgeAfter.FloatValue && d > 80.0 && g_nudges[w] < g_cvMaxNudges.IntValue)
		{
			float spot[3], start[3];
			ClearStart(w, wp, start);
			if (FindNudge(w, start, tp, spot, g_nudges[w]))
			{
				g_nudges[w]++;
				g_frozenFor[w] = 0.0;
				Launch(w, start, spot, 4.0);
				Log("nudge %d: witch %d chasing %N frozen at %.0f %.0f %.0f, moved %.0f to %.0f %.0f %.0f", g_nudges[w], w, target,
					wp[0], wp[1], wp[2], HorizDist(wp, spot), spot[0], spot[1], spot[2]);
				continue;
			}
		}

		// closing in only counts if she moved; the target walking up to a frozen witch is not progress
		bool closed = d < g_best[w] - g_cvProgress.FloatValue && g_frozenFor[w] < 0.5;
		// moving a lot without closing in is a detour, not a snag: open a new window
		bool moved = GetVectorDistance(wp, g_anchor[w]) > g_cvStill.FloatValue;
		if (closed || moved)
		{
			if (g_stuck[w])
			{
				Log("END witch %d moving again after %.1fs stuck, now at %.0f %.0f %.0f, %.0f from %N", w, now - g_stuckAt[w], wp[0], wp[1], wp[2], d, target);
				g_stuck[w] = false;
			}
			g_best[w] = d;
			g_bestAt[w] = now;
			g_anchor[w] = wp;
			continue;
		}
		if (g_stuck[w] && mode == 1) continue;
		if (now - g_bestAt[w] < g_cvTime.FloatValue) continue;
		if (g_moves[w] >= g_cvMaxMoves.IntValue) { g_ref[w] = INVALID_ENT_REFERENCE; continue; }

		float land[3], rise, from[3];
		ClearStart(w, wp, from);
		float t0 = GetEngineTime();
		// within arm's reach the problem is height, not a snag: a hop would only carry her away
		bool canHop = d > 120.0 && FindHop(w, from, tp, land, rise);
		float searchMs = (GetEngineTime() - t0) * 1000.0;
		if (!g_stuck[w])
		{
			g_stuck[w] = true;
			g_stuckAt[w] = now;
			char map[64];
			GetCurrentMap(map, sizeof(map));
			char by[80];
			int setter = GetClientOfUserId(g_setBy[w]);
			if (g_nearest[w] && setter > 0) Format(by, sizeof(by), " (nearest; set off by infected %N)", setter);
			else if (g_nearest[w]) by = " (nearest; set off by an infected player)";
			else by[0] = 0;
			Log("START %s witch %d stuck %.0fs: at %.0f %.0f %.0f seq %d rage %.2f | target %L%s at %.0f %.0f %.0f, %.0f away, nav walk %.0f | hop %s (search %.1f ms)",
				map, w, now - g_bestAt[w], wp[0], wp[1], wp[2], Seq(w), Rage(w), target, by, tp[0], tp[1], tp[2], d, Travel(wp, tp),
				canHop ? "available" : "none", searchMs);
			LogSurvivors();
		}
		if (mode == 1) continue;

		// mode 2: whatever happens next, wait a full window before judging her again
		g_bestAt[w] = now;
		g_best[w] = d;
		g_anchor[w] = wp;
		if (canHop)
		{
			g_moves[w]++;
			Launch(w, from, land, rise);
			Log("hop %d: witch %d chasing %N from %.0f %.0f %.0f to %.0f %.0f %.0f (sideways %.0f, drop %.0f, target %.0f away, was %.0f)",
				g_moves[w], w, target, wp[0], wp[1], wp[2], land[0], land[1], land[2],
				HorizDist(wp, land), wp[2] - land[2], GetVectorDistance(land, tp), d);
			Log("  arc %.0f above the higher end", rise);
		}
		else
		{
			// she is usually pacing, so the next spot she reaches may have a hop: look again soon
			g_bestAt[w] = now - g_cvTime.FloatValue + RETRY;
			if (g_cvLog.IntValue >= 2) Log("witch %d chasing %N stuck at %.0f %.0f %.0f (%.0f away), no hop found", w, target, wp[0], wp[1], wp[2], d);
		}
	}
	return Plugin_Continue;
}

// A witch set off by an infected player has no named target, so her chase ends when she hurts anyone.
public void Ev_PlayerHurt(Event e, const char[] n, bool nb)
{
	int w = e.GetInt("attackerentid");
	if (w <= MaxClients || w >= sizeof(g_ref) || g_ref[w] == INVALID_ENT_REFERENCE || !g_nearest[w]) return;
	if (EntRefToEntIndex(g_ref[w]) != w) return;
	int victim = GetClientOfUserId(e.GetInt("userid"));
	if (g_stuck[w]) Log("END witch %d moving again after %.1fs stuck: she reached %N", w, GetGameTime() - g_stuckAt[w], victim);
	Log("REACHED witch %d got %N (set off by an infected player)", w, victim);
	g_stuck[w] = false;
	g_ref[w] = INVALID_ENT_REFERENCE;
}

public void Ev_WitchKilled(Event e, const char[] n, bool nb)
{
	int w = e.GetInt("witchid");
	if (w <= MaxClients || w >= sizeof(g_ref) || g_ref[w] == INVALID_ENT_REFERENCE) return;
	int killer = GetClientOfUserId(e.GetInt("userid"));
	if (g_stuck[w])
	{
		if (killer > 0) Log("END witch %d killed while stuck, after %.1fs, by %L", w, GetGameTime() - g_stuckAt[w], killer);
		else Log("END witch %d killed while stuck, after %.1fs", w, GetGameTime() - g_stuckAt[w]);
	}
	g_stuck[w] = false;
	g_ref[w] = INVALID_ENT_REFERENCE;
}

// A player saw a stuck witch: record every witch and survivor as they are now.
public Action Cmd_StuckWitch(int client, int args)
{
	float now = GetGameTime();
	if (client > 0 && now - g_lastReport[client] < 10.0 && g_lastReport[client] > 0.0) return Plugin_Handled;
	if (client > 0) g_lastReport[client] = now;
	char map[64];
	GetCurrentMap(map, sizeof(map));
	if (client > 0) Log("REPORT %s by %L", map, client);
	else Log("REPORT %s by console", map);
	int w = -1, n = 0;
	while ((w = FindEntityByClassname(w, "witch")) != -1)
	{
		float p[3];
		GetEntPropVector(w, Prop_Send, "m_vecOrigin", p);
		bool tracked = w < sizeof(g_ref) && g_ref[w] != INVALID_ENT_REFERENCE;
		int target = !tracked ? 0 : (g_nearest[w] ? NearestChaseable(p) : GetClientOfUserId(g_targetUser[w]));
		if (target > 0 && IsClientInGame(target))
		{
			float tp[3];
			GetClientAbsOrigin(target, tp);
			Log("  witch %d at %.0f %.0f %.0f seq %d rage %.2f hp %d%s | chasing %N, %.0f away", w, p[0], p[1], p[2], Seq(w), Rage(w),
				GetEntProp(w, Prop_Data, "m_iHealth"), g_stuck[w] ? " STUCK" : "", target, GetVectorDistance(p, tp));
		}
		else
		{
			Log("  witch %d at %.0f %.0f %.0f seq %d rage %.2f hp %d | not chasing anyone", w, p[0], p[1], p[2], Seq(w), Rage(w),
				GetEntProp(w, Prop_Data, "m_iHealth"));
		}
		n++;
	}
	if (n == 0) Log("  no witch on the map");
	LogSurvivors();
	if (client > 0) PrintToChat(client, "Thanks, witch report saved.");
	return Plugin_Handled;
}

void LogSurvivors()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || GetClientTeam(i) != TEAM_SURVIVOR || !IsPlayerAlive(i)) continue;
		float p[3];
		GetClientAbsOrigin(i, p);
		char st[32];
		TargetState(i, st, sizeof(st));
		Log("  survivor %N at %.0f %.0f %.0f %s", i, p[0], p[1], p[2], st);
	}
}

void TargetState(int client, char[] out, int len)
{
	if (client <= 0 || !IsClientInGame(client)) strcopy(out, len, "left the game");
	else if (GetClientTeam(client) != TEAM_SURVIVOR) strcopy(out, len, "left the survivors");
	else if (!IsPlayerAlive(client)) strcopy(out, len, "dead");
	else if (GetEntProp(client, Prop_Send, "m_isHangingFromLedge")) strcopy(out, len, "hanging from a ledge");
	else if (GetEntProp(client, Prop_Send, "m_isIncapacitated")) strcopy(out, len, "incapped");
	else strcopy(out, len, "standing");
}

int Seq(int w)
{
	return GetEntProp(w, Prop_Send, "m_nSequence");
}

float Rage(int w)
{
	return HasEntProp(w, Prop_Send, "m_rage") ? GetEntPropFloat(w, Prop_Send, "m_rage") : -1.0;
}

int DownedNear(const float from[3], float range)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || GetClientTeam(i) != TEAM_SURVIVOR || !IsPlayerAlive(i)) continue;
		if (!GetEntProp(i, Prop_Send, "m_isIncapacitated") && !GetEntProp(i, Prop_Send, "m_isHangingFromLedge")) continue;
		float p[3];
		GetClientAbsOrigin(i, p);
		if (GetVectorDistance(from, p) < range) return i;
	}
	return 0;
}

int NearestChaseable(const float from[3])
{
	int best = 0;
	float bd = 0.0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsChaseable(i)) continue;
		float p[3];
		GetClientAbsOrigin(i, p);
		float d = GetVectorDistance(from, p);
		if (best == 0 || d < bd) { best = i; bd = d; }
	}
	return best;
}

bool IsChaseable(int client)
{
	return client > 0 && IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVOR && IsPlayerAlive(client)
		&& !GetEntProp(client, Prop_Send, "m_isIncapacitated")
		&& !GetEntProp(client, Prop_Send, "m_isHangingFromLedge");
}

float HorizDist(const float a[3], const float b[3])
{
	float dx = a[0] - b[0], dy = a[1] - b[1];
	return SquareRoot(dx * dx + dy * dy);
}

float Travel(const float a[3], const float b[3])
{
	float from[3], to[3];
	from = a;
	to = b;
	return L4D2_NavAreaTravelDistance(from, to, false);
}

enum struct Candidate
{
	float hop;
	float pos[3];
}

// A frozen witch is usually caught on a corner. Find the shortest move off it, at most
// l4d_witch_unstuck_nudge units, onto floor at her own height, with room for her, a clear
// straight slide there, and a walk to the target that is shorter than from where she is.
bool FindNudge(int witch, const float wp[3], const float tp[3], float out[3], int tries)
{
	float mine = Travel(wp, tp);
	float maxR = g_cvNudge.FloatValue;
	// a nudge that did not free her was too small: each later one in the chase starts further out
	float minR = 8.0 * float(tries + 1);
	if (minR > maxR) minR = maxR;
	float toTarget = ArcTangent2(tp[1] - wp[1], tp[0] - wp[0]);
	ArrayList cands = new ArrayList(sizeof(Candidate));
	Candidate c;
	float mn[3], mx[3];
	GetEntPropVector(witch, Prop_Send, "m_vecMins", mn);
	GetEntPropVector(witch, Prop_Send, "m_vecMaxs", mx);
	mn[2] += 4.0;
	for (float r = minR; r <= maxR + 0.1; r += 8.0)
	{
		for (int k = 0; k < 16; k++)
		{
			float ang = toTarget + float(k) * (FLOAT_PI / 8.0);
			float p[3], down[3];
			p[0] = wp[0] + r * Cosine(ang);
			p[1] = wp[1] + r * Sine(ang);
			p[2] = wp[2] + 24.0;
			down = p;
			down[2] = wp[2] - 24.0;
			Handle tr = TR_TraceRayFilterEx(p, down, MASK_NPCSOLID, RayType_EndPoint, F_NotPlayers, witch);
			bool floor = TR_DidHit(tr) && !TR_StartSolid(tr);
			if (floor) TR_GetEndPosition(p, tr);
			delete tr;
			if (!floor || FloatAbs(p[2] - wp[2]) > 18.0) continue;
			p[2] += 1.0;
			if (!HasRoom(witch, p)) continue;
			tr = TR_TraceHullFilterEx(wp, p, mn, mx, MASK_NPCSOLID, F_NotPlayers, witch);
			bool clear = !TR_DidHit(tr);
			delete tr;
			if (!clear) continue;
			// order: shortest move first, then the direction closest to the target
			float off = float(k > 8 ? 16 - k : k);
			c.hop = r * 100.0 + off;
			c.pos = p;
			cands.PushArray(c);
		}
	}
	cands.SortCustom(ByHop);
	bool found = false;
	for (int i = 0; i < cands.Length && i < NUDGE_CHECKS; i++)
	{
		cands.GetArray(i, c);
		float left = Travel(c.pos, tp);
		// off the mesh (-1) on both ends: take the first clear spot, it is still better than frozen
		if ((mine >= 0.0 && left >= 0.0 && left < mine - 2.0) || (mine < 0.0 && left >= 0.0) || (mine < 0.0 && left < 0.0 && i == 0))
		{
			out = c.pos;
			found = true;
			break;
		}
		if (g_cvLog.IntValue >= 2) Log("  nudge reject %.0f %.0f %.0f: walk %.0f vs hers %.0f", c.pos[0], c.pos[1], c.pos[2], left, mine);
	}
	if (g_cvLog.IntValue >= 2) Log("  nudge search: %d spots with room and a clear slide, hers %.0f, %s", cands.Length, mine, found ? "found" : "none");
	delete cands;
	return found;
}

bool FindHop(int witch, const float wp[3], const float tp[3], float out[3], float &rise)
{
	float hopMax = g_cvHop.FloatValue;
	float minD = g_cvMinDist.FloatValue;

	// how far she still has to walk; off the mesh, start from the nearest area
	float mine = Travel(wp, tp);
	if (mine < 0.0)
	{
		Address near = view_as<Address>(L4D_GetNearestNavArea(wp, 200.0, true, false, false, TEAM_INFECTED));
		if (near != Address_Null)
		{
			float c[3];
			L4D_GetNavAreaCenter(near, c);
			mine = Travel(c, tp);
		}
	}
	if (mine < 0.0) { Log("  no nav walk from %.0f %.0f %.0f to the target", wp[0], wp[1], wp[2]); return false; }

	ArrayList areas = new ArrayList();
	L4D_GetAllNavAreas(areas);
	ArrayList cands = new ArrayList(sizeof(Candidate));
	Candidate c;
	for (int i = 0; i < areas.Length; i++)
	{
		Address a = view_as<Address>(areas.Get(i));
		float p[3];
		if (!NearestPoint(a, wp, hopMax, p)) continue;
		float hop = HorizDist(p, wp);
		if (hop > hopMax || hop < 16.0) continue;
		if (p[2] - wp[2] > MAX_RISE || wp[2] - p[2] > MAX_DROP) continue;
		if (GetVectorDistance(p, tp) < minD) continue;
		// never clearly away from the target: a shorter nav walk that lands her far off reads as
		// fleeing. A little farther is allowed, e.g. up onto a railing she then drops down from.
		if (GetVectorDistance(p, tp) > GetVectorDistance(wp, tp) + 60.0) continue;
		if (L4D_NavArea_IsBlocked(a, TEAM_INFECTED, false)) continue;
		c.hop = hop;
		c.pos = p;
		cands.PushArray(c);
	}
	delete areas;

	// Of the spots within reach, take the one that saves the most walking, less a
	// little for a longer jump: the landing past the obstacle, not just beside it.
	cands.SortCustom(ByHop);
	bool found = false;
	float bestScore = -999999.0;
	int checks = 0, noRoom = 0, noArc = 0;
	for (int i = 0; i < cands.Length && checks < TRAVEL_CHECKS; i++)
	{
		cands.GetArray(i, c);
		if (!HasRoom(witch, c.pos)) { noRoom++; continue; }
		checks++;
		float left = Travel(c.pos, tp);
		float gain = mine - left;
		if (left < 0.0 || gain < g_cvGain.FloatValue)
		{
			if (g_cvLog.IntValue >= 2) Log("  reject %.0f %.0f %.0f: walk %.0f vs hers %.0f", c.pos[0], c.pos[1], c.pos[2], left, mine);
			continue;
		}
		float score = gain - 0.5 * c.hop;
		if (score <= bestScore) continue;
		if (!ArcClear(witch, wp, c.pos))
		{
			noArc++;
			if (g_cvLog.IntValue >= 2) Log("  no clear arc to %.0f %.0f %.0f (hop %.0f, saves %.0f)", c.pos[0], c.pos[1], c.pos[2], c.hop, gain);
			continue;
		}
		if (g_cvLog.IntValue >= 2) Log("  option %.0f %.0f %.0f: hop %.0f, saves %.0f, arc %.0f", c.pos[0], c.pos[1], c.pos[2], c.hop, gain, g_outApex);
		bestScore = score;
		rise = g_outApex;
		out = c.pos;
		out[2] += 2.0;
		found = true;
	}
	if (g_cvLog.IntValue >= 2) Log("  hers %.0f, %d candidates, %d without room, %d blocked arcs, %d path checks", mine, cands.Length, noRoom, noArc, checks);
	delete cands;
	return found;
}

// The point of the area nearest to pos, kept EDGE inside it, with the area's floor height.
bool NearestPoint(Address a, const float pos[3], float reach, float out[3])
{
	float c[3], sz[3];
	L4D_GetNavAreaCenter(a, c);
	L4D_GetNavAreaSize(a, sz);
	float hx = sz[0] * 0.5, hy = sz[1] * 0.5;
	if (FloatAbs(c[0] - pos[0]) > reach + hx || FloatAbs(c[1] - pos[1]) > reach + hy) return false;
	out[0] = Clamp(pos[0], c[0] - hx + EDGE, c[0] + hx - EDGE, c[0]);
	out[1] = Clamp(pos[1], c[1] - hy + EDGE, c[1] + hy - EDGE, c[1]);
	out[2] = c[2];
	out[2] = L4D_NavArea_GetZ(a, out);
	return true;
}

float Clamp(float v, float lo, float hi, float mid)
{
	if (lo > hi) return mid;
	return v < lo ? lo : (v > hi ? hi : v);
}

public int ByHop(int i1, int i2, Handle array, Handle hndl)
{
	ArrayList l = view_as<ArrayList>(array);
	float a = l.Get(i1, 0), b = l.Get(i2, 0);
	return a < b ? -1 : (a > b ? 1 : 0);
}

// Ballistic launch that rises `rise` above the higher end and lands on the spot.
void ArcVelocity(const float from[3], const float to[3], float rise, float vel[3], float &flight)
{
	float g = g_cvGravity.FloatValue;
	float apex = (from[2] > to[2] ? from[2] : to[2]) + rise;
	float up = SquareRoot(2.0 * g * (apex - from[2]));
	flight = up / g + SquareRoot(2.0 * (apex - to[2]) / g);
	vel[0] = (to[0] - from[0]) / flight;
	vel[1] = (to[1] - from[1]) / flight;
	vel[2] = up;
}

// The lowest clear arc, in g_outApex; false if none of them is clear.
bool ArcClear(int witch, const float from[3], const float to[3])
{
	for (int i = 0; i < sizeof(g_apexes); i++)
	{
		if (ArcClearAt(witch, from, to, g_apexes[i])) { g_outApex = g_apexes[i]; return true; }
	}
	return false;
}

bool ArcClearAt(int witch, const float from[3], const float to[3], float rise)
{
	float vel[3], flight;
	ArcVelocity(from, to, rise, vel, flight);
	float mn[3], mx[3];
	GetEntPropVector(witch, Prop_Send, "m_vecMins", mn);
	GetEntPropVector(witch, Prop_Send, "m_vecMaxs", mx);
	mn[2] += 8.0;    // keep the ends clear of the ground they start and finish on
	float g = g_cvGravity.FloatValue;
	float prev[3];
	prev = from;
	for (int k = 1; k <= ARC_STEPS; k++)
	{
		float t = flight * float(k) / float(ARC_STEPS);
		float p[3];
		p[0] = from[0] + vel[0] * t;
		p[1] = from[1] + vel[1] * t;
		p[2] = from[2] + vel[2] * t - 0.5 * g * t * t;
		if (k == ARC_STEPS) p = to;
		Handle tr = TR_TraceHullFilterEx(prev, p, mn, mx, MASK_NPCSOLID, F_NotPlayers, witch);
		bool hit = TR_DidHit(tr);
		delete tr;
		if (hit) return false;
		prev = p;
	}
	return true;
}

void Launch(int witch, const float from[3], const float to[3], float rise)
{
	float vel[3], flight;
	ArcVelocity(from, to, rise, vel, flight);
	g_hopFrom[witch] = from;
	g_hopVel[witch] = vel;
	g_hopTo[witch] = to;
	g_hopFlight[witch] = flight;
	g_hopStart[witch] = GetGameTime();
	g_hopping[witch] = true;
}

// The engine's own movement overrides any velocity a plugin gives her, so the
// arc is flown by hand: one small move per tick, which clients interpolate.
public void OnGameFrame()
{
	float now = GetGameTime();
	float g = g_cvGravity.FloatValue;
	float zero[3];
	for (int w = MaxClients + 1; w < sizeof(g_ref); w++)
	{
		if (!g_hopping[w]) continue;
		if (g_ref[w] == INVALID_ENT_REFERENCE || EntRefToEntIndex(g_ref[w]) != w) { g_hopping[w] = false; continue; }
		float t = now - g_hopStart[w];
		if (t >= g_hopFlight[w])
		{
			TeleportEntity(w, g_hopTo[w], NULL_VECTOR, zero);
			g_hopping[w] = false;
			g_bestAt[w] = now;
			g_anchor[w] = g_hopTo[w];
			continue;
		}
		float p[3];
		p[0] = g_hopFrom[w][0] + g_hopVel[w][0] * t;
		p[1] = g_hopFrom[w][1] + g_hopVel[w][1] * t;
		p[2] = g_hopFrom[w][2] + g_hopVel[w][2] * t - 0.5 * g * t * t;
		TeleportEntity(w, p, NULL_VECTOR, zero);
	}
}

// Where the arc starts: her position, or up to 32 units above it when she is
// wedged into geometry there, since every arc from inside a wall "hits" at once.
void ClearStart(int witch, const float wp[3], float out[3])
{
	out = wp;
	for (float up = 0.0; up <= 32.0; up += 8.0)
	{
		float p[3];
		p = wp;
		p[2] += up - 4.0;    // HasRoom adds 4
		if (HasRoom(witch, p)) { out[2] = wp[2] + up; return; }
	}
}

bool HasRoom(int witch, const float pos[3])
{
	float mn[3], mx[3], a[3];
	GetEntPropVector(witch, Prop_Send, "m_vecMins", mn);
	GetEntPropVector(witch, Prop_Send, "m_vecMaxs", mx);
	a = pos;
	a[2] += 4.0;
	Handle tr = TR_TraceHullFilterEx(a, a, mn, mx, MASK_NPCSOLID, F_NotPlayers, witch);
	bool clear = !TR_DidHit(tr);
	delete tr;
	return clear;
}

public bool F_NotPlayers(int ent, int mask, any witch)
{
	return ent != witch && (ent == 0 || ent > MaxClients);
}

void Log(const char[] fmt, any ...)
{
	if (!g_cvLog.BoolValue) return;
	char buf[512];
	VFormat(buf, sizeof(buf), fmt, 2);
	LogToFileEx(g_log, "%s", buf);
}
