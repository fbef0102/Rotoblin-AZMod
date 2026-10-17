#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <dhooks>
#include <profiler>

#define PLUGIN_VERSION "0.4.0"
#define GAMEDATA "l4d_tank_fair_punch"

#define TEAM_SURVIVOR	2
#define TEAM_INFECTED	3
#define ZC_TANK			5

#define SEQ_UPPERCUT	38
#define SEQ_RIGHTHOOK	41
#define SEQ_LEFTHOOK	43
#define SEQ_POUND1		44	// ground pound (low attack at an incapped survivor)
#define SEQ_POUND2		45

#define HIST			256		// survivor position history, one entry per server frame
#define MAXSAMP			160		// fist samples per windup (0.5 s at 100 tick is 50)

// Why this exists: a tank punch is decided by where the fist is, except at one moment.
//
// When the 0.5 s windup ends, CTankClaw::OnWindupFinished scans for a survivor within
// tank_swing_range (56, box to box) and inside a cone (eye dot > 0.8). If it finds one,
// the first fist sweep starts at that survivor's centre, which is a near-certain hit no
// matter where the fist is. If it finds nobody, the sweep starts at eye + forward * 56.
// After that, for tank_swing_duration (0.2 s), the fist sweeps from its last position to
// the hand and hits whoever it passes within tank_fist_radius (15) of.
//
// The tank punch audit (2,988 punches in real PUGs, 2026-09-29 to 10-01) found that
// moment wrong both ways:
//   * long arms: 45 hits where the fist never came within 30 units of the victim, all
//     handed out by the scan;
//   * phantom misses: survivors the fist visibly went through at the end of the windup,
//     whom the scan skipped (just outside the cone or the range), and the window sweep
//     then missed because the fist had already passed them.
//
// This plugin changes only the start point of the first sweep, the one the scan seeds,
// so damage, lag compensation and what a punch can hit stay the game's own:
//   * VETO: the scan picked a standing survivor the fist never came within
//     l4d_tank_fair_punch_veto_dist of during the windup: the sweep starts at the fist
//     instead. The fist can still hit him in the 0.2 s window the normal way (0.3.2 note: not
//     on a left hook, whose sweeps still follow the trailing right hand). A survivor
//     within l4d_tank_fair_punch_veto_min_gap of the tank (hugging it) is never vetoed:
//     20 of the first 56 vetoes in the audit data were point blank, and dropping those
//     would make hugging the tank a way not to get punched.
//   * ADD: the scan picked nobody (or was vetoed), and the fist came within the fist radius
//     of a standing survivor in the last l4d_tank_fair_punch_add_time of the windup, in
//     front of the tank and in its line of sight: the sweep starts at his centre, exactly
//     as the scan would have done.
//
// Distances use the tank player's view: the survivor's position rewound to the tick SweepFist's lag
// compensation tests him at (ViewDelay, 0.4.0).
//
// 0.3: l4d_tank_fair_punch_log_all writes one PUNCH line per human punch and nearby
// standing survivor, acted on or not, so any punch can be judged afterwards. The fist is
// sampled on through the 0.2 s hit window for it.
//
// 0.3.1: `window` counts only fist samples inside tank_swing_duration. 0.3 counted the
// 0.25 s the fist is sampled for (hit_d still uses them), so a fist that reached a survivor
// in the last 0.05 s, after the game's last sweep, read as a near pass that missed. Rig
// check 2026-10-15 (versus, 50 bot punches): log window < 15 with the fist within 15 in the
// real window = 47 hits of 48; within 15 only past it = 14 misses of 29. Those late touches
// now go to `post` (closest fist after the window, to 0.25 s) so they can be counted: the
// arm visibly goes through a survivor after the game stopped testing it.
//
// 0.3.2 (2026-10-16, server.so audit, l4d-source docs/annotated/tank-punch/GroundPound.md): a non-punch
// fire sequence clears a recording left over from a punch whose windup never finished, and an
// incapped pick no longer blocks an add (see the add rule below).
//
// 0.4.0 (2026-10-16, owner calls after the audit):
// - Ground pounds are judged too. GroundPound runs inside OnWindupFinished and ends the swing, but
//   CTerrorWeapon::ItemPostFrame keeps calling DoSwing for tank_swing_duration from the scan's seed
//   (m_lastFistPos), which can be a STANDING survivor next to the incapped one. The veto rule applies
//   to that seed; ground pounds never add. The pound's own hits on incapped survivors are untouched.
// - l4d_tank_fair_punch_pick_seed: when the scan picked a standing survivor and nothing vetoed it,
//   the stock seed is his PRESENT centre while SweepFist tests his rewound box (every human punch is
//   rewound since l4d_tank_punch_lagcomp), so at ~150 ms and running speed the two are ~30 units apart
//   and the scan's free hit can miss. 1 logs that gap (seed_gap on the PUNCH line), 2 starts the sweep
//   at his rewound centre instead.
// - The tank's view is now the game's own rewind (CLagCompensationManager::StartLagCompensation): the
//   usercmd's tick_count minus the lerp in ticks, falling back to latency + lerp when they differ by
//   more than 0.2 s, capped by sv_maxunlag, none at all with cl_lagcompensation 0. 0.3 used latency +
//   lerp against the tickbase clock. Survivor history is keyed by simulation time, as the game's records are.
ConVar g_hCvarPickSeed, g_hCvarMaxUnlag;
int g_iCmdTick[MAXPLAYERS + 1];		// tick_count of the usercmd being run
float g_fActSeedGap[MAXPLAYERS + 1];
bool g_bActReseed[MAXPLAYERS + 1];
ConVar g_hCvarMode, g_hCvarVetoDist, g_hCvarVetoGap, g_hCvarAddTime, g_hCvarLog, g_hCvarLogAll, g_hCvarFistRadius, g_hCvarSwingDur;
Handle g_hGetAttachment;
char g_sLogPath[PLATFORM_MAX_PATH];

// survivor history
float g_fHT[MAXPLAYERS + 1][HIST];
float g_fHP[MAXPLAYERS + 1][HIST][3];
float g_fHTop[MAXPLAYERS + 1][HIST];
int g_iHHead[MAXPLAYERS + 1];
int g_iHCount[MAXPLAYERS + 1];

// one windup per tank
bool g_bRec[MAXPLAYERS + 1];
float g_fLastStart[MAXPLAYERS + 1];
int g_iRecSeq[MAXPLAYERS + 1];
int g_iRecN[MAXPLAYERS + 1];
float g_fST[MAXPLAYERS + 1][MAXSAMP];
float g_fSHand[MAXPLAYERS + 1][MAXSAMP][3];
bool g_bWantSeed[MAXPLAYERS + 1];
// after the windup: the fist is sampled on through the hit window for the PUNCH lines
bool g_bPost[MAXPLAYERS + 1];
float g_fPostUntil[MAXPLAYERS + 1];
int g_iWindN[MAXPLAYERS + 1];		// samples up to and including the fist at the windup's end
float g_fWindEnd[MAXPLAYERS + 1];

int g_iStatPunches, g_iStatScan, g_iStatVeto, g_iStatAdd;
float g_fLastCost, g_fMaxCost;

// the punch an action was taken on, followed to the end of the hit window for the log
bool g_bTrack[MAXPLAYERS + 1];
bool g_bHitBy[MAXPLAYERS + 1][MAXPLAYERS + 1];
int g_iActVeto[MAXPLAYERS + 1], g_iActAdd[MAXPLAYERS + 1];
float g_fActVetoMin[MAXPLAYERS + 1], g_fActAddMin[MAXPLAYERS + 1], g_fActDelay[MAXPLAYERS + 1];
int g_iActMode[MAXPLAYERS + 1], g_iActSeq[MAXPLAYERS + 1], g_iActHug[MAXPLAYERS + 1];
float g_fActGap[MAXPLAYERS + 1];
bool g_bActLine[MAXPLAYERS + 1];		// a veto, add or hug happened: write the WOULD/APPLIED line

// PUNCH lines: every human punch, per standing survivor near the tank at the windup's end
bool g_bPunchLog[MAXPLAYERS + 1];
int g_iPunchId;
int g_iPunchNo[MAXPLAYERS + 1];
int g_iPunchPick[MAXPLAYERS + 1];
bool g_bNear[MAXPLAYERS + 1][MAXPLAYERS + 1];
float g_fNearWind[MAXPLAYERS + 1][MAXPLAYERS + 1], g_fNearLate[MAXPLAYERS + 1][MAXPLAYERS + 1], g_fNearGap[MAXPLAYERS + 1][MAXPLAYERS + 1];
float g_fHitT[MAXPLAYERS + 1][MAXPLAYERS + 1];

// human tank punches this map, for the SUMMARY line at map end
int g_iMapPunches, g_iMapPicks, g_iMapVetoes, g_iMapAdds, g_iMapHugs;

public Plugin myinfo =
{
	name = "[L4D1] Tank Fair Punch",
	author = "Malevolence",
	description = "The windup-end punch target follows the fist: no hits the fist never came near, and hits the fist visibly went through.",
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

	StartPrepSDKCall(SDKCall_Entity);
	if( !PrepSDKCall_SetFromConf(gd, SDKConf_Signature, "CBaseAnimating::GetAttachment") ) SetFailState("Missing signature CBaseAnimating::GetAttachment");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef, _, VENCODE_FLAG_COPYBACK);
	PrepSDKCall_AddParameter(SDKType_QAngle, SDKPass_ByRef, _, VENCODE_FLAG_COPYBACK);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hGetAttachment = EndPrepSDKCall();
	if( g_hGetAttachment == null ) SetFailState("Failed to prepare GetAttachment");

	DynamicDetour dw = DynamicDetour.FromConf(gd, "CTankClaw::OnWindupFinished");
	if( dw == null || !dw.Enable(Hook_Pre, Detour_OnWindupFinished) ) SetFailState("Failed to detour CTankClaw::OnWindupFinished");
	DynamicDetour dsf = DynamicDetour.FromConf(gd, "CTankClaw::SweepFist");
	if( dsf == null || !dsf.Enable(Hook_Pre, Detour_SweepFist) ) SetFailState("Failed to detour CTankClaw::SweepFist");
	DynamicDetour dh = DynamicDetour.FromConf(gd, "CTankClaw::OnPlayerHit");
	if( dh == null || !dh.Enable(Hook_Pre, Detour_OnPlayerHit) ) SetFailState("Failed to detour CTankClaw::OnPlayerHit");
	delete gd;

	CreateConVar("l4d_tank_fair_punch_version", PLUGIN_VERSION, "Tank Fair Punch version", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_hCvarMode = CreateConVar("l4d_tank_fair_punch_mode", "1", "0 = off. 1 = log what it would do, change nothing. 2 = on.", FCVAR_NOTIFY, true, 0.0, true, 2.0);
	g_hCvarVetoDist = CreateConVar("l4d_tank_fair_punch_veto_dist", "30", "The windup-end target scan's free hit is dropped when the fist never came this close (units, survivor box to hand) to him during the windup. 0 = never drop.", FCVAR_NOTIFY, true, 0.0);
	g_hCvarVetoGap = CreateConVar("l4d_tank_fair_punch_veto_min_gap", "20", "Never drop the scan's hit on a survivor closer than this to the tank (units, box to box): one hugging the tank stays punchable.", FCVAR_NOTIFY, true, 0.0);
	g_hCvarAddTime = CreateConVar("l4d_tank_fair_punch_add_time", "0.25", "Seconds before the windup ends in which a fist that touched a survivor (within tank_fist_radius) makes him the punch target. 0 = never add.", FCVAR_NOTIFY, true, 0.0, true, 0.5);
	g_hCvarLog = CreateConVar("l4d_tank_fair_punch_log", "1", "Log every veto and add to logs/tank_fair_punch.log.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_hCvarLogAll = CreateConVar("l4d_tank_fair_punch_log_all", "1", "Also log a PUNCH line for every tank punch and each standing survivor within 250 units, acted on or not. 1 = human tanks, 2 = bot tanks too (test rigs).", FCVAR_NONE, true, 0.0, true, 2.0);
	g_hCvarPickSeed = CreateConVar("l4d_tank_fair_punch_pick_seed", "1", "When the scan's pick is kept: 0 = stock seed (his present centre). 1 = stock, log the gap to his rewound centre (seed_gap). 2 = seed at his rewound centre, where the sweep tests him.", FCVAR_NOTIFY, true, 0.0, true, 2.0);
	g_hCvarMaxUnlag = FindConVar("sv_maxunlag");
	g_hCvarFistRadius = FindConVar("tank_fist_radius");
	g_hCvarSwingDur = FindConVar("tank_swing_duration");

	RegAdminCmd("sm_fairpunch_stats", Cmd_Stats, ADMFLAG_ROOT, "Punches seen, scan picks, vetoes and adds since load.");
	BuildPath(Path_SM, g_sLogPath, sizeof(g_sLogPath), "logs/tank_fair_punch.log");
}

public void OnMapEnd()
{
	if( g_iMapPunches > 0 && g_hCvarLog.BoolValue && g_hCvarMode.BoolValue )
	{
		char map[64];
		GetCurrentMap(map, sizeof(map));
		LogToFileEx(g_sLogPath, "SUMMARY map=%s mode=%d human_punches=%d scan_picks=%d vetoes=%d adds=%d hugs_kept=%d",
			map, g_hCvarMode.IntValue, g_iMapPunches, g_iMapPicks, g_iMapVetoes, g_iMapAdds, g_iMapHugs);
	}
	g_iMapPunches = 0; g_iMapPicks = 0; g_iMapVetoes = 0; g_iMapAdds = 0; g_iMapHugs = 0;
}

public void OnMapStart()
{
	for( int i = 1; i <= MaxClients; i++ ) ResetClient(i);
}

public void OnClientDisconnect(int client)
{
	ResetClient(client);
}

void ResetClient(int client)
{
	g_iHCount[client] = 0;
	g_bRec[client] = false;
	g_bWantSeed[client] = false;
	g_fLastStart[client] = 0.0;
	g_bTrack[client] = false;
	g_bPost[client] = false;
	g_bPunchLog[client] = false;
}

bool IsPunch(int seq)
{
	return seq == SEQ_UPPERCUT || seq == SEQ_RIGHTHOOK || seq == SEQ_LEFTHOOK || IsPound(seq);
}

bool IsPound(int seq)
{
	return seq == SEQ_POUND1 || seq == SEQ_POUND2;
}

// server frame clock (OnGameFrame's GetGameTime); inside a usercmd GetGameTime is the tickbase clock
float FrameTime()
{
	return GetGameTickCount() * GetTickInterval();
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	g_iCmdTick[client] = tickcount;
	return Plugin_Continue;
}

bool IsStanding(int client)
{
	return !GetEntProp(client, Prop_Send, "m_isIncapacitated") && !GetEntProp(client, Prop_Send, "m_isHangingFromLedge");
}

// How far back (seconds, on the frame clock) SweepFist's lag compensation puts survivors for this
// tank's current usercmd, as StartLagCompensation picks its target tick. 0 = not rewound.
float ViewDelay(int client)
{
	if( IsFakeClient(client) ) return 0.0;
	char lc[4];
	if( GetClientInfo(client, "cl_lagcompensation", lc, sizeof(lc)) && lc[0] == '0' ) return 0.0;
	float interval = GetTickInterval();
	float lerp = GetEntPropFloat(client, Prop_Data, "m_fLerpTime");
	int lerpTicks = RoundToFloor(0.5 + lerp / interval);
	float correct = GetClientLatency(client, NetFlow_Outgoing) + lerpTicks * interval;
	float maxUnlag = g_hCvarMaxUnlag != null ? g_hCvarMaxUnlag.FloatValue : 1.0;
	if( correct < 0.0 ) correct = 0.0;
	if( correct > maxUnlag ) correct = maxUnlag;
	int target = g_iCmdTick[client] - lerpTicks;
	// gpGlobals->tickcount, not curtime: inside a usercmd curtime is the tickbase clock
	float delta = correct - interval * (GetGameTickCount() - target);
	if( FloatAbs(delta) > 0.2 ) target = GetGameTickCount() - RoundToFloor(0.5 + correct / interval);
	float d = FrameTime() - target * interval;
	if( d < 0.0 ) d = 0.0;
	return d;
}

public void OnGameFrame()
{
	if( !g_hCvarMode.BoolValue ) return;
	float now = GetGameTime();
	for( int i = 1; i <= MaxClients; i++ )
	{
		if( !IsClientInGame(i) || !IsPlayerAlive(i) ) continue;
		int team = GetClientTeam(i);
		if( team == TEAM_SURVIVOR ) RecordSurvivor(i, now);
		else if( team == TEAM_INFECTED ) TankFrame(i, now);
	}
}

void RecordSurvivor(int client, float now)
{
	#pragma unused now
	int h = (g_iHHead[client] + 1) % HIST;
	float pos[3], maxs[3];
	GetClientAbsOrigin(client, pos);
	GetClientMaxs(client, maxs);
	// keyed like the lag compensation records: by the survivor's own simulation time (his tickbase
	// clock, up to sv_clockcorrection_msecs off the frame clock). Rig 2026-10-16: frame-keyed history
	// put the rewound survivor ~0.07 s off; simulation-time keyed matched the game to 0.0 units.
	g_fHT[client][h] = GetEntPropFloat(client, Prop_Data, "m_flSimulationTime");
	g_fHP[client][h] = pos;
	g_fHTop[client][h] = maxs[2];
	g_iHHead[client] = h;
	if( g_iHCount[client] < HIST ) g_iHCount[client]++;
}

// survivor's position at time t (newest recorded frame at or before t); false if not recorded
bool SurvivorAt(int client, float t, float pos[3], float &top)
{
	int n = g_iHCount[client];
	int h = g_iHHead[client];
	for( int k = 0; k < n; k++ )
	{
		int idx = (h - k + HIST) % HIST;
		if( g_fHT[client][idx] <= t + 0.0001 )
		{
			pos = g_fHP[client][idx];
			top = g_fHTop[client][idx];
			return true;
		}
	}
	return false;
}

void FistAttachment(int seq, char[] hand, int len)
{
	// the fist the animation swings (the game itself always sweeps "rhand")
	strcopy(hand, len, seq == SEQ_LEFTHOOK ? "lhand" : "rhand");
}

void TankFrame(int tank, float now)
{
	if( GetEntProp(tank, Prop_Send, "m_zombieClass") != ZC_TANK ) return;
	int seq = GetEntProp(tank, Prop_Send, "m_fireLayerSequence");
	float start = GetEntPropFloat(tank, Prop_Send, "m_fireLayerStartTime");
	// 0.3.2: any other new fire sequence (ground pound 44/45, rock throw) ends a recording whose
	// windup never finished, so a later sweep is not judged on that punch's old fist samples
	if( !IsPunch(seq) && start != g_fLastStart[tank] && start > 0.0 )
	{
		g_fLastStart[tank] = start;
		g_bRec[tank] = false;
		g_bWantSeed[tank] = false;
	}
	if( IsPunch(seq) && start != g_fLastStart[tank] && start > 0.0 )
	{
		g_fLastStart[tank] = start;
		g_bRec[tank] = true;
		g_bWantSeed[tank] = false;
		g_bPost[tank] = false;
		g_iRecSeq[tank] = seq;
		g_iRecN[tank] = 0;
	}
	// sample until the windup ends (OnWindupFinished stops the recording), then through the hit window
	if( g_bRec[tank] && now - start <= 1.0 ) Sample(tank, now);
	else if( g_bPost[tank] )
	{
		if( now <= g_fPostUntil[tank] ) Sample(tank, now);
		else g_bPost[tank] = false;
	}
}

void Sample(int tank, float now)
{
	int n = g_iRecN[tank];
	if( n >= MAXSAMP ) return;
	char hand[8];
	FistAttachment(g_iRecSeq[tank], hand, sizeof(hand));
	float h[3], ang[3];
	if( !SDKCall(g_hGetAttachment, tank, hand, h, ang) ) return;
	g_fST[tank][n] = now;
	g_fSHand[tank][n] = h;
	g_iRecN[tank] = n + 1;
}

int OwnerTank(int claw)
{
	if( claw <= MaxClients || !IsValidEntity(claw) ) return 0;
	int tank = GetEntPropEnt(claw, Prop_Send, "m_hOwner");
	if( tank < 1 || tank > MaxClients || !IsClientInGame(tank) ) return 0;
	return tank;
}

MRESReturn Detour_OnWindupFinished(int claw)
{
	if( !g_hCvarMode.BoolValue ) return MRES_Ignored;
	int tank = OwnerTank(claw);
	if( tank == 0 || !g_bRec[tank] ) return MRES_Ignored;
	// the first SweepFist from here on is the one the scan seeds (OnWindupFinished sweeps itself)
	g_bRec[tank] = false;
	g_bWantSeed[tank] = true;
	return MRES_Ignored;
}

float PointBoxDist(const float p[3], const float o[3], float top)
{
	float d[3];
	float mins[3], maxs[3];
	mins[0] = o[0] - 16.0; mins[1] = o[1] - 16.0; mins[2] = o[2];
	maxs[0] = o[0] + 16.0; maxs[1] = o[1] + 16.0; maxs[2] = o[2] + top;
	for( int k = 0; k < 3; k++ )
	{
		if( p[k] < mins[k] ) d[k] = mins[k] - p[k];
		else if( p[k] > maxs[k] ) d[k] = p[k] - maxs[k];
		else d[k] = 0.0;
	}
	return SquareRoot(d[0] * d[0] + d[1] * d[1] + d[2] * d[2]);
}

// gap between the tank's box and a survivor's (32 x 32 x top), 0 when they touch
float BoxGap(const float to[3], const float tmins[3], const float tmaxs[3], const float so[3], float top)
{
	float g[3];
	float smin[3], smax[3];
	smin[0] = so[0] - 16.0; smin[1] = so[1] - 16.0; smin[2] = so[2];
	smax[0] = so[0] + 16.0; smax[1] = so[1] + 16.0; smax[2] = so[2] + top;
	for( int k = 0; k < 3; k++ )
	{
		float lo = to[k] + tmins[k], hi = to[k] + tmaxs[k];
		if( hi < smin[k] ) g[k] = smin[k] - hi;
		else if( smax[k] < lo ) g[k] = lo - smax[k];
		else g[k] = 0.0;
	}
	return SquareRoot(g[0] * g[0] + g[1] * g[1] + g[2] * g[2]);
}

bool TraceWorldOnly(int entity, int contentsMask)
{
	return entity == 0 || entity > MaxClients;
}

bool CanSee(int tank, const float target[3])
{
	float eye[3];
	GetClientEyePosition(tank, eye);
	Handle tr = TR_TraceRayFilterEx(eye, target, MASK_SOLID_BRUSHONLY, RayType_EndPoint, TraceWorldOnly);
	bool clear = !TR_DidHit(tr);
	delete tr;
	return clear;
}

MRESReturn Detour_SweepFist(int claw, DHookParam hParams)
{
	int tank = OwnerTank(claw);
	if( tank == 0 || !g_bWantSeed[tank] ) return MRES_Ignored;
	g_bWantSeed[tank] = false;
	int mode = g_hCvarMode.IntValue;
	if( mode == 0 ) return MRES_Ignored;
	g_iStatPunches++;
	Profiler prof = new Profiler();
	prof.Start();
	MRESReturn ret = Decide(tank, mode, hParams);
	prof.Stop();
	g_fLastCost = prof.Time * 1000.0;
	if( g_fLastCost > g_fMaxCost ) g_fMaxCost = g_fLastCost;
	delete prof;
	return ret;
}

MRESReturn Decide(int tank, int mode, DHookParam hParams)
{
	float from[3], to[3];
	hParams.GetVector(1, from);
	hParams.GetVector(2, to);
	float now = FrameTime();
	bool pound = IsPound(g_iRecSeq[tank]);
	float tdelay = ViewDelay(tank);
	float radius = g_hCvarFistRadius != null ? g_hCvarFistRadius.FloatValue : 15.0;
	float vetoDist = g_hCvarVetoDist.FloatValue;
	float addTime = g_hCvarAddTime.FloatValue;
	int n = g_iRecN[tank];

	// who the scan picked: the stock seed is his present centre
	int picked = 0;
	for( int s = 1; s <= MaxClients; s++ )
	{
		if( !IsClientInGame(s) || !IsPlayerAlive(s) || GetClientTeam(s) != TEAM_SURVIVOR ) continue;
		float o[3], mx[3];
		GetClientAbsOrigin(s, o);
		GetClientMaxs(s, mx);
		if( FloatAbs(from[0] - o[0]) < 1.0 && FloatAbs(from[1] - o[1]) < 1.0 && FloatAbs(from[2] - (o[2] + mx[2] * 0.5)) < 2.0 )
		{
			picked = s;
			break;
		}
	}
	if( picked ) g_iStatScan++;

	// per standing survivor: closest the fist came over the whole windup, and in its last addTime
	float eyeAng[3], fwd[3], tpos[3];
	GetClientEyeAngles(tank, eyeAng);
	eyeAng[0] = 0.0;
	GetAngleVectors(eyeAng, fwd, NULL_VECTOR, NULL_VECTOR);
	GetClientAbsOrigin(tank, tpos);

	float pickedMin = -1.0, pickedGap = -1.0;
	for( int s = 1; s <= MaxClients; s++ )
	{
		g_bNear[tank][s] = false;
		g_fHitT[tank][s] = -1.0;
	}
	float tmins[3], tmaxs[3];
	GetClientMins(tank, tmins);
	GetClientMaxs(tank, tmaxs);
	int add = 0;
	float addMin = 99999.0, addSeed[3];
	for( int s = 1; s <= MaxClients; s++ )
	{
		if( !IsClientInGame(s) || !IsPlayerAlive(s) || GetClientTeam(s) != TEAM_SURVIVOR || !IsStanding(s) ) continue;
		float o[3], top;
		GetClientAbsOrigin(s, o);
		if( GetVectorDistance(o, tpos) > 250.0 ) continue;

		float all = 99999.0, late = 99999.0;
		for( int i = 0; i < n; i++ )
		{
			if( !SurvivorAt(s, g_fST[tank][i] - tdelay, o, top) ) continue;
			float d = PointBoxDist(g_fSHand[tank][i], o, top);
			if( d < all ) all = d;
			if( now - g_fST[tank][i] <= addTime && d < late ) late = d;
		}
		// and where the fist is now, at the windup's end
		if( SurvivorAt(s, now - tdelay, o, top) )
		{
			float d = PointBoxDist(to, o, top);
			if( d < all ) all = d;
			if( addTime > 0.0 && d < late ) late = d;
		}
		else continue;

		g_bNear[tank][s] = true;
		g_fNearWind[tank][s] = all;
		g_fNearLate[tank][s] = late;
		g_fNearGap[tank][s] = BoxGap(tpos, tmins, tmaxs, o, top);
		if( s == picked )
		{
			pickedMin = all;
			pickedGap = BoxGap(tpos, tmins, tmaxs, o, top);
		}
		if( s != picked && late < radius && late < addMin )
		{
			float c[3], dir[3];
			c = o;
			c[2] += top * 0.5;
			SubtractVectors(c, tpos, dir);
			dir[2] = 0.0;
			if( GetVectorDotProduct(dir, fwd) <= 0.0 || !CanSee(tank, c) ) continue;
			add = s;
			addMin = late;
			addSeed = c;
		}
	}

	bool far = picked && pickedMin >= 0.0 && vetoDist > 0.0 && pickedMin >= vetoDist;
	bool hug = far && pickedGap < g_hCvarVetoGap.FloatValue;
	bool veto = far && !hug;
	// a punch the scan already aimed at someone the fist reached (or who hugs the tank) keeps that
	// target. 0.3.2: only a standing pick: an incapped one can never be vetoed (pickedMin stays -1)
	// and a normal swing does him no damage, so it used to cancel the add of a standing survivor
	// the fist went through
	if( picked && !veto && IsStanding(picked) ) add = 0;
	// a ground pound is only ever narrowed, never pointed at someone new
	if( pound ) add = 0;
	// a kept standing pick: where the sweep will test him (rewound) vs the stock seed (present centre)
	float seedGap = -1.0, pickSeed[3];
	if( picked && !veto && IsStanding(picked) && g_hCvarPickSeed.IntValue >= 1 )
	{
		float po[3], ptop;
		if( SurvivorAt(picked, now - tdelay, po, ptop) )
		{
			pickSeed = po;
			pickSeed[2] += ptop * 0.5;
			seedGap = GetVectorDistance(pickSeed, from);
		}
	}
	// a ground pound is only ever narrowed, so its seed is never moved onto the survivor
	bool reseed = seedGap > 1.0 && g_hCvarPickSeed.IntValue >= 2 && !pound;
	bool human = !IsFakeClient(tank);
	if( human )
	{
		g_iMapPunches++;
		if( picked ) g_iMapPicks++;
		if( veto ) g_iMapVetoes++;
		if( add ) g_iMapAdds++;
		if( hug ) g_iMapHugs++;
	}
	// the fist at the windup's end closes the windup samples; the hit window's follow.
	// Not `to`: the game always passes rhand, which is behind the tank in a left hook.
	char hand[8];
	float fist[3], fang[3];
	FistAttachment(g_iRecSeq[tank], hand, sizeof(hand));
	if( n < MAXSAMP && SDKCall(g_hGetAttachment, tank, hand, fist, fang) )
	{
		g_fST[tank][n] = now;
		g_fSHand[tank][n] = fist;
		g_iRecN[tank] = n + 1;
	}
	g_iWindN[tank] = g_iRecN[tank];
	g_fWindEnd[tank] = now;
	g_bPost[tank] = true;
	g_fPostUntil[tank] = now + 0.25;

	bool action = veto || add || hug || reseed;
	bool punchLog = g_hCvarLog.BoolValue && (human ? g_hCvarLogAll.IntValue >= 1 : g_hCvarLogAll.IntValue >= 2);
	if( !action && !punchLog ) return MRES_Ignored;

	if( veto ) g_iStatVeto++;
	if( add ) g_iStatAdd++;
	if( g_hCvarLog.BoolValue )
	{
		// written when the hit window is over, with who the punch hit
		g_bTrack[tank] = true;
		g_bActLine[tank] = action;
		g_bPunchLog[tank] = punchLog;
		g_iPunchNo[tank] = ++g_iPunchId;
		g_iPunchPick[tank] = picked;
		for( int i = 1; i <= MaxClients; i++ ) g_bHitBy[tank][i] = false;
		g_iActVeto[tank] = veto ? picked : 0;
		g_fActVetoMin[tank] = pickedMin;
		g_iActHug[tank] = hug ? picked : 0;
		g_fActGap[tank] = pickedGap;
		g_iActAdd[tank] = add;
		g_fActAddMin[tank] = addMin;
		g_fActDelay[tank] = tdelay;
		g_iActMode[tank] = mode;
		g_iActSeq[tank] = g_iRecSeq[tank];
		g_fActSeedGap[tank] = seedGap;
		g_bActReseed[tank] = reseed;
		CreateTimer(0.35, T_Outcome, GetClientUserId(tank), TIMER_FLAG_NO_MAPCHANGE);
	}
	if( mode < 2 || (!veto && !add && !reseed) ) return MRES_Ignored;

	if( reseed ) hParams.SetVector(1, pickSeed);
	else if( add ) hParams.SetVector(1, addSeed);
	else hParams.SetVector(1, to);
	return MRES_ChangedHandled;
}

MRESReturn Detour_OnPlayerHit(int claw, DHookParam hParams)
{
	int tank = OwnerTank(claw);
	if( tank == 0 || !g_bTrack[tank] ) return MRES_Ignored;
	int victim = hParams.Get(1);
	if( victim >= 1 && victim <= MaxClients )
	{
		if( !g_bHitBy[tank][victim] ) g_fHitT[tank][victim] = FrameTime();
		g_bHitBy[tank][victim] = true;
	}
	return MRES_Ignored;
}

Action T_Outcome(Handle timer, int userid)
{
	int tank = GetClientOfUserId(userid);
	if( tank == 0 || !g_bTrack[tank] ) return Plugin_Stop;
	g_bTrack[tank] = false;

	char map[64], tname[MAX_NAME_LENGTH], vname[MAX_NAME_LENGTH] = "-", aname[MAX_NAME_LENGTH] = "-", hname[MAX_NAME_LENGTH] = "-", hits[160];
	GetCurrentMap(map, sizeof(map));
	GetClientName(tank, tname, sizeof(tname));
	int veto = g_iActVeto[tank], add = g_iActAdd[tank];
	if( veto && IsClientInGame(veto) ) GetClientName(veto, vname, sizeof(vname));
	if( add && IsClientInGame(add) ) GetClientName(add, aname, sizeof(aname));
	int hug = g_iActHug[tank];
	if( hug && IsClientInGame(hug) ) GetClientName(hug, hname, sizeof(hname));
	for( int i = 1; i <= MaxClients; i++ )
	{
		if( !g_bHitBy[tank][i] || !IsClientInGame(i) ) continue;
		char n[MAX_NAME_LENGTH];
		GetClientName(i, n, sizeof(n));
		Format(hits, sizeof(hits), "%s%s%s", hits, hits[0] ? "," : "", n);
	}
	if( g_bPunchLog[tank] ) LogPunch(tank, map, tname);
	if( !g_bActLine[tank] ) return Plugin_Stop;
	// veto_hit = the vetoed survivor was hit anyway (by the fist in the window, or by stock in log mode).
	// hug = the fist never came near the scan's pick but he was within veto_min_gap of the tank, so he kept the hit.
	LogToFileEx(g_sLogPath, "%s map=%s tank=\"%s\"%s seq=%d tdelay=%.3f veto=\"%s\" veto_min=%.1f veto_hit=%d gap=%.1f hug=\"%s\" add=\"%s\" add_min=%.1f add_hit=%d reseed=%d seed_gap=%.1f hits=\"%s\"",
		g_iActMode[tank] >= 2 ? "APPLIED" : "WOULD", map, tname, IsFakeClient(tank) ? " bot=1" : "", g_iActSeq[tank], g_fActDelay[tank],
		vname, (veto || hug) ? g_fActVetoMin[tank] : -1.0, veto ? view_as<int>(g_bHitBy[tank][veto]) : -1,
		g_fActGap[tank], hname,
		aname, add ? g_fActAddMin[tank] : -1.0, add ? view_as<int>(g_bHitBy[tank][add]) : -1,
		view_as<int>(g_bActReseed[tank]), g_fActSeedGap[tank], hits);
	return Plugin_Stop;
}

// One line per standing survivor near the tank at the windup's end. All distances are survivor box
// to fist in the tank's view (survivor rewound by tdelay), the fist the animation swings:
//   wind = closest over the windup, late = over its last add_time, window = over the hit window,
//   tank_swing_duration (0.2 s) from the windup's end (the only fist the stock sweep tests,
//   apart from the scan's seed),
//   post = closest in the 0.05 s after the hit window (the arm still swinging, no sweep),
//   gap = tank box to survivor box at the windup's end,
//   hit_dt = seconds from the windup's end to the hit (0 = the scan's seed), hit_d = the fist's
//   distance at the sample nearest the hit: a long arm is a hit with a big hit_d.
void LogPunch(int tank, const char[] map, const char[] tname)
{
	float tdelay = g_fActDelay[tank];
	int n = g_iRecN[tank], w = g_iWindN[tank];
	int pick = g_iPunchPick[tank];
	// the game's last sweep is at swing_duration; half a tick of slack for frame timing
	float winEnd = g_fWindEnd[tank] + (g_hCvarSwingDur != null ? g_hCvarSwingDur.FloatValue : 0.2) + 0.005;
	char pname[MAX_NAME_LENGTH] = "-";
	if( pick && IsClientInGame(pick) ) GetClientName(pick, pname, sizeof(pname));
	char act[16];
	if( g_iActVeto[tank] ) strcopy(act, sizeof(act), "veto");
	else if( g_iActAdd[tank] ) strcopy(act, sizeof(act), "add");
	else if( g_iActHug[tank] ) strcopy(act, sizeof(act), "hug");
	else if( g_bActReseed[tank] ) strcopy(act, sizeof(act), "reseed");
	else strcopy(act, sizeof(act), "none");
	for( int s = 1; s <= MaxClients; s++ )
	{
		if( !g_bNear[tank][s] || !IsClientInGame(s) ) continue;
		float o[3], top;
		float window = -1.0, post = -1.0, hitD = -1.0, hitGap = 99999.0;
		float hitT = g_fHitT[tank][s];
		for( int i = (w > 0 ? w - 1 : 0); i < n; i++ )
		{
			if( !SurvivorAt(s, g_fST[tank][i] - tdelay, o, top) ) continue;
			float d = PointBoxDist(g_fSHand[tank][i], o, top);
			if( g_fST[tank][i] <= winEnd ) { if( window < 0.0 || d < window ) window = d; }
			else if( post < 0.0 || d < post ) post = d;
			if( hitT >= 0.0 && FloatAbs(g_fST[tank][i] - hitT) < hitGap )
			{
				hitGap = FloatAbs(g_fST[tank][i] - hitT);
				hitD = d;
			}
		}
		char sname[MAX_NAME_LENGTH];
		GetClientName(s, sname, sizeof(sname));
		bool hit = g_bHitBy[tank][s];
		LogToFileEx(g_sLogPath, "PUNCH id=%d map=%s tank=\"%s\" seq=%d tdelay=%.3f surv=\"%s\" picked=%d pick=\"%s\" act=%s wind=%.1f late=%.1f window=%.1f post=%.1f gap=%.1f hit=%d hit_dt=%.3f hit_d=%.1f seed_gap=%.1f",
			g_iPunchNo[tank], map, tname, g_iActSeq[tank], tdelay, sname, s == pick, pname, act,
			g_fNearWind[tank][s], g_fNearLate[tank][s] > 9999.0 ? -1.0 : g_fNearLate[tank][s], window, post, g_fNearGap[tank][s],
			hit, hit ? hitT - g_fWindEnd[tank] : -1.0, hitD, s == pick ? g_fActSeedGap[tank] : -1.0);
	}
}

Action Cmd_Stats(int client, int args)
{
	ReplyToCommand(client, "[fairpunch] mode %d: punches %d, scan picks %d, vetoes %d, adds %d; decision cost last %.3f ms, max %.3f ms",
		g_hCvarMode.IntValue, g_iStatPunches, g_iStatScan, g_iStatVeto, g_iStatAdd, g_fLastCost, g_fMaxCost);
	return Plugin_Handled;
}