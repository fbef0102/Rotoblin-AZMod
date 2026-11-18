#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define PLUGIN_VERSION "0.4"

/**
 * l4d_tank_pass_fix - a passed tank no longer bounces off its new owner.
 *
 * When a human tank runs out of frustration the director starts a lottery
 * (director_tank_lottery_selection_time, 3 s here) and then hands the tank
 * to the winner. About one pass in ten, a SECOND "Tank offer: Starting the
 * lottery" fires in the same second as that handoff. The winner gets the
 * tank, and when the second lottery finishes 3 s later it is taken off them
 * and given to somebody else. Server logs from all our boxes, 2026-07-27 to
 * 2026-09-27: 1204 human passes on Dallas, 113 bounced, and every bounce
 * (109 of 113; the other 4 had the two offers straddle a second boundary)
 * had that duplicate offer at the handoff. No pass without it bounced.
 *
 * A real second frustration needs the whole frustration bar, far longer than
 * one lottery, so a human-tank offer arriving within one lottery of the last
 * one is the duplicate. Block it. Offers for a freshly spawned tank carry
 * the tank BOT as tank_index and are never blocked.
 *
 * Every offer is logged to logs/tank_pass_fix.log so the fix can be checked
 * against real games. l4d_tank_pass_fix 0 keeps the logging and blocks
 * nothing.
 *
 * 0.2: a passed tank is not left stuck. ZombieManager::ReplaceTank hands the
 * old tank's origin to Spawn, which can bring the new tank up inside a prop:
 * match 949 (NM1, both halves) passed a tank climbing the storage-room box
 * stack (z 80, already inside it) and the new one came up at z 16 inside the
 * boxes, frozen until CGameMovement::CheckStuck warped it onto the nearest
 * teammate 5 s later, 400 to 580 units away. Every alive tank's last clear,
 * on-ground spot is kept (5 Hz). One frame after a pass, a new tank whose hull
 * is blocked goes to the old tank's spot if that is clear, else to the old
 * tank's last clear spot from the past 10 s within 256 u, else the engine's
 * WarpToValidPositionIfStuck gets a try. l4d_tank_pass_fix_unstick 0 only logs.
 *
 * 0.3: any stuck tank, not only a passed one. Replays 09-20 to 11-04: 11
 * tanks frozen 5+ s and then warped by CheckStuck onto a teammate, often one
 * fighting the survivors (match 980 Ria Daed 3: 5.8 s frozen after a roof
 * drop, then 3098 u onto a smoker 32 u from a survivor). A tank the engine
 * has in its stuck state (m_StuckLast > 0) whose origin has not moved for
 * 1 s goes back to its last clear spot (<= 10 s, <= 256 u), else gets the
 * engine warp; nothing found leaves it to the stock 5 s warp. A pass hands
 * the old tank's trail to the new one, so a tank passed while stuck (match
 * 920 DT4) is covered too. l4d_tank_pass_fix_unstick 0 logs these as well.
 *
 * 0.4: the hull test no longer counts players as solid. 0.2/0.3 skipped only
 * the tank itself, so a pass with a survivor, a teammate or the old tank's
 * own body touching the new tank read as "stuck": 34 post-pass stuck lines
 * 11-03..11-15, 27 "STILL STUCK" (24 not moved at all), and none followed by
 * a frozen line (the engine's own stuck counter) within 90 s. The effect was
 * a harmless teleport in place, but the log was noise and a real stuck pass
 * could be sent to the engine warp for the wrong reason. Movement against
 * players is the engine's business; this plugin only cares about the world,
 * props, clips and blockers. The stuck and frozen lines now name what the
 * hull hit (hit=world or the entity's classname) so a stray blocker shows up.
 */

ConVar g_cvEnabled, g_cvLottery, g_cvUnstick;
float g_fLastHumanOffer = -1000.0;
char g_sLog[PLATFORM_MAX_PATH];

#define CLEAR_SPOT_MAX_AGE 10.0
#define CLEAR_SPOT_MAX_DIST 256.0  // a tank teleported since then (a plugin, a warp) has no usable trail
float g_vClearSpot[MAXPLAYERS + 1][3];
float g_fClearSpotAt[MAXPLAYERS + 1];

#define STUCK_TICKS 5  // 5 Hz checks: 1 s frozen in the engine's stuck state
float g_vLastPos[MAXPLAYERS + 1][3];
int g_iStuckTicks[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name = "Tank Pass Fix",
	author = "Malevolence",
	description = "Stops a passed tank being taken off its new owner by a duplicate lottery",
	version = PLUGIN_VERSION,
	url = "https://riversidepug.com"
};

public void OnPluginStart()
{
	g_cvEnabled = CreateConVar("l4d_tank_pass_fix", "1", "1 = block a duplicate human-tank offer inside one lottery of the last, 0 = log only.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvUnstick = CreateConVar("l4d_tank_pass_fix_unstick", "1", "1 = a passed tank that comes up stuck goes to the old tank's spot or the nearest free one, 0 = log only.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvLottery = FindConVar("director_tank_lottery_selection_time");
	BuildPath(Path_SM, g_sLog, sizeof(g_sLog), "logs/tank_pass_fix.log");
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_fLastHumanOffer = -1000.0;
}

public void OnMapStart()
{
	g_fLastHumanOffer = -1000.0;
	for (int i = 1; i <= MaxClients; i++)
	{
		g_fClearSpotAt[i] = -1000.0;
		g_iStuckTicks[i] = 0;
	}
	CreateTimer(0.2, Timer_ClearSpots, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_ClearSpots(Handle timer)
{
	float pos[3];
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || GetClientTeam(i) != 3 || !IsPlayerAlive(i) || GetEntProp(i, Prop_Send, "m_zombieClass") != 5
			|| GetEntProp(i, Prop_Send, "m_isGhost"))
		{
			g_iStuckTicks[i] = 0;
			continue;
		}
		GetClientAbsOrigin(i, pos);
		CheckStuckTank(i, pos);
		if (!(GetEntityFlags(i) & FL_ONGROUND))
			continue;
		if (HullBlocked(i, pos))
			continue;
		g_vClearSpot[i] = pos;
		g_fClearSpotAt[i] = GetGameTime();
	}
	return Plugin_Continue;
}

// The engine's CheckStuck counts m_StuckLast up on every failed nudge and
// zeroes it once the player is free; after 5 s of it the player is warped
// onto the nearest teammate. Act after 1 s with the tank's own trail instead.
void CheckStuckTank(int client, const float pos[3])
{
	bool frozen = GetVectorDistance(pos, g_vLastPos[client]) < 1.0;
	g_vLastPos[client] = pos;
	if (!frozen || GetEntProp(client, Prop_Data, "m_StuckLast") <= 0 || GetEntityMoveType(client) != MOVETYPE_WALK)
	{
		g_iStuckTicks[client] = 0;
		return;
	}
	if (++g_iStuckTicks[client] < STUCK_TICKS)
		return;
	g_iStuckTicks[client] = 0;

	char hit[32] = "none";
	if (HullBlocked(client, pos))
		HitName(hit, sizeof(hit));
	bool haveClear = GetGameTime() - g_fClearSpotAt[client] <= CLEAR_SPOT_MAX_AGE
		&& GetVectorDistance(g_vClearSpot[client], pos) <= CLEAR_SPOT_MAX_DIST
		&& !HullBlocked(client, g_vClearSpot[client]);

	if (!g_cvUnstick.BoolValue)
	{
		LogToFileEx(g_sLog, "frozen \"%N\" at=%.1f %.1f %.1f stucklast=%d clear=%d hit=%s (log only)",
			client, pos[0], pos[1], pos[2], GetEntProp(client, Prop_Data, "m_StuckLast"), haveClear, hit);
		return;
	}

	char via[16];
	float zero[3];
	if (haveClear)
	{
		via = "last clear";
		TeleportEntity(client, g_vClearSpot[client], NULL_VECTOR, zero);
	}
	else
	{
		via = "engine warp";
		L4D_WarpToValidPositionIfStuck(client);
	}

	float to[3];
	GetClientAbsOrigin(client, to);
	g_vLastPos[client] = to;
	LogToFileEx(g_sLog, "frozen \"%N\" at=%.1f %.1f %.1f hit=%s -> %.1f %.1f %.1f via %s%s",
		client, pos[0], pos[1], pos[2], hit, to[0], to[1], to[2], via, HullBlocked(client, to) ? " STILL STUCK" : "");
}

public Action L4D_OnTryOfferingTankBot(int tank_index, bool &enterStasis)
{
	bool human = tank_index > 0 && tank_index <= MaxClients && IsClientInGame(tank_index) && !IsFakeClient(tank_index);
	float now = GetGameTime();
	float since = now - g_fLastHumanOffer;
	float window = (g_cvLottery != null ? g_cvLottery.FloatValue : 3.0) + 1.5;

	if (!human)
	{
		//LogToFileEx(g_sLog, "offer tank_index=%d (bot) stasis=%d t=%.2f", tank_index, enterStasis, now);
		return Plugin_Continue;
	}

	//int frus = 100 - GetEntProp(tank_index, Prop_Send, "m_frustration");
	bool dup = since < window;
	bool block = dup && g_cvEnabled.BoolValue;

	//LogToFileEx(g_sLog, "offer tank_index=%d \"%N\" frus_left=%d stasis=%d t=%.2f since_last=%.2f %s",
	//	tank_index, tank_index, frus, enterStasis, now, since,
	//	block ? "BLOCKED duplicate" : (dup ? "duplicate (log only)" : "allowed"));

	if (block)
		return Plugin_Handled;

	g_fLastHumanOffer = now;
	return Plugin_Continue;
}

public void L4D_OnReplaceTank(int tank, int newtank)
{
	char a[MAX_NAME_LENGTH] = "?", b[MAX_NAME_LENGTH] = "?";
	if (tank > 0 && tank <= MaxClients && IsClientInGame(tank)) GetClientName(tank, a, sizeof(a));
	if (newtank > 0 && newtank <= MaxClients && IsClientInGame(newtank)) GetClientName(newtank, b, sizeof(b));
	//LogToFileEx(g_sLog, "replace %d \"%s\" -> %d \"%s\" t=%.2f", tank, a, newtank, b, GetGameTime());

	// Valve's handoff loop also calls ReplaceTank(winner, winner) right after the
	// real pass; by then the winner already stands on the dropped spot, so only
	// the first call carries the old tank's origin.
	if (tank == newtank || tank < 1 || tank > MaxClients || !IsClientInGame(tank) || !IsPlayerAlive(tank))
		return;
	if (newtank < 1 || newtank > MaxClients || !IsClientInGame(newtank))
		return;

	float from[3];
	GetClientAbsOrigin(tank, from);
	bool haveClear = GetGameTime() - g_fClearSpotAt[tank] <= CLEAR_SPOT_MAX_AGE;
	DataPack dp = new DataPack();
	dp.WriteCell(GetClientUserId(newtank));
	dp.WriteFloat(from[0]);
	dp.WriteFloat(from[1]);
	dp.WriteFloat(from[2]);
	dp.WriteCell(haveClear);
	dp.WriteFloat(g_vClearSpot[tank][0]);
	dp.WriteFloat(g_vClearSpot[tank][1]);
	dp.WriteFloat(g_vClearSpot[tank][2]);
	// the new tank carries on the old one's trail
	g_vClearSpot[newtank] = g_vClearSpot[tank];
	g_fClearSpotAt[newtank] = g_fClearSpotAt[tank];
	g_iStuckTicks[newtank] = 0;
	g_fClearSpotAt[tank] = -1000.0;
	RequestFrame(Frame_Unstick, dp);
}

void Frame_Unstick(DataPack dp)
{
	dp.Reset();
	int client = GetClientOfUserId(dp.ReadCell());
	float from[3], clear[3];
	from[0] = dp.ReadFloat();
	from[1] = dp.ReadFloat();
	from[2] = dp.ReadFloat();
	bool haveClear = dp.ReadCell();
	clear[0] = dp.ReadFloat();
	clear[1] = dp.ReadFloat();
	clear[2] = dp.ReadFloat();
	delete dp;

	if (client == 0 || !IsPlayerAlive(client) || GetClientTeam(client) != 3 || GetEntProp(client, Prop_Send, "m_zombieClass") != 5)
		return;

	float at[3];
	GetClientAbsOrigin(client, at);
	if (!HullBlocked(client, at))
		return;
	char hit[32];
	HitName(hit, sizeof(hit));

	if (!g_cvUnstick.BoolValue)
	{
		LogToFileEx(g_sLog, "stuck \"%N\" at=%.1f %.1f %.1f old=%.1f %.1f %.1f hit=%s (log only)", client, at[0], at[1], at[2], from[0], from[1], from[2], hit);
		return;
	}

	char via[16];
	float zero[3];
	if (!HullBlocked(client, from))
	{
		via = "old spot";
		TeleportEntity(client, from, NULL_VECTOR, zero);
	}
	else if (haveClear && GetVectorDistance(clear, from) <= CLEAR_SPOT_MAX_DIST && !HullBlocked(client, clear))
	{
		via = "last clear";
		TeleportEntity(client, clear, NULL_VECTOR, zero);
	}
	else
	{
		via = "engine warp";
		TeleportEntity(client, from, NULL_VECTOR, zero);
		L4D_WarpToValidPositionIfStuck(client);
	}

	float to[3];
	GetClientAbsOrigin(client, to);
	LogToFileEx(g_sLog, "stuck \"%N\" at=%.1f %.1f %.1f old=%.1f %.1f %.1f hit=%s -> %.1f %.1f %.1f via %s%s",
		client, at[0], at[1], at[2], from[0], from[1], from[2], hit, to[0], to[1], to[2],
		via, HullBlocked(client, to) ? " STILL STUCK" : "");
}

// What a human infected's movement collides with (CTerrorGameMovement::
// PlayerSolidMask for team 3, less the 0x80000000 bit whose meaning is not
// known): no survivor-only PLAYERCLIP, plus MONSTERCLIP and the infected-only
// team blockers.
#define MASK_INFECTED_MOVE 0x0202520B
int g_iLastHit = -1;

bool HullBlocked(int client, const float pos[3])
{
	float mins[3], maxs[3];
	GetClientMins(client, mins);
	GetClientMaxs(client, maxs);
	TR_TraceHullFilter(pos, pos, mins, maxs, MASK_INFECTED_MOVE, TraceFilter_Solid, client);
	bool blocked = TR_DidHit() || TR_StartSolid();
	g_iLastHit = blocked ? TR_GetEntityIndex() : -1;
	return blocked;
}

// What the last blocked HullBlocked hit: "world" or the entity's classname.
void HitName(char[] buf, int len)
{
	if (g_iLastHit <= 0)
		strcopy(buf, len, "world");
	else if (IsValidEntity(g_iLastHit))
		GetEntityClassname(g_iLastHit, buf, len);
	else
		Format(buf, len, "#%d", g_iLastHit);
}

// World, props, clips and blockers only: no players (the tank itself, its
// teammates, survivors, the old tank's body after a pass), which a tank is not
// stuck in, and no weapon spawns, which movement walks through.
bool TraceFilter_Solid(int entity, int mask, int self)
{
	if (entity >= 1 && entity <= MaxClients)
		return false;
	if (entity > MaxClients && IsValidEntity(entity))
	{
		char cls[16];
		GetEntityClassname(entity, cls, sizeof(cls));
		if (strncmp(cls, "weapon_", 7) == 0)
			return false;
	}
	return true;
}
