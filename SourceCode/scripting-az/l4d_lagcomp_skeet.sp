/**
 * v1.5: by Forgetest
 * v1.5h: Make a forward when m_isAttemptingToPounce is changed
 */

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>

#include <@Forgetest/gamedatawrapper>

#define DEBUG 1
#define PLUGIN_VERSION "1.5h-2026/10/23"

public Plugin myinfo =
{
	name = "[L4D & 2] Lag-compensated Skeet",
	author = "Forgetest",
	description = "Make hunter skeets more consistent across different pings.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins",
}

methodmap CountdownTimerPtr
{
	public bool HasStarted() {
		return (this.m_timestamp > 0.0);
	}
	property float m_duration {
		public get() { return LoadFromAddress(view_as<Address>(this) + view_as<Address>(4), NumberType_Int32); }
	}
	property float m_timestamp {
		public get() { return LoadFromAddress(view_as<Address>(this) + view_as<Address>(8), NumberType_Int32); }
	}
}

methodmap CUserCmd
{
	property int tick_count {
		public get() { return LoadFromAddress(view_as<Address>(this) + view_as<Address>(8), NumberType_Int32); }
	}
}

int g_iOffs_m_pCurrentPlayer;
int g_iOffs_m_isCurrentlyDoingCompensation;
methodmap CLagCompensationManager
{
	property Address m_pCurrentPlayer {
		public get() { return LoadFromAddress(view_as<Address>(this) + view_as<Address>(g_iOffs_m_pCurrentPlayer), NumberType_Int32); }
	}
	property bool m_isCurrentlyDoingCompensation {
		public get() { return LoadFromAddress(view_as<Address>(this) + view_as<Address>(g_iOffs_m_isCurrentlyDoingCompensation), NumberType_Int8); }
	}
}
CLagCompensationManager g_LagCompensationManager;

enum struct PlayerSave
{
	int client;
	bool m_isAttemptingToPounce;
}
ArrayList g_PlayerSaveStack;


GlobalForward g_fwdPounceRewound;
public void OnPluginStart()
{
	GameDataWrapper gd = new GameDataWrapper("l4d_lagcomp_skeet");
	g_LagCompensationManager = view_as<CLagCompensationManager>(gd.GetAddress("g_LagCompensationManager"));
	g_iOffs_m_pCurrentPlayer = gd.GetOffset("CLagCompensationManager::m_pCurrentPlayer");
	g_iOffs_m_isCurrentlyDoingCompensation = gd.GetOffset("CLagCompensationManager::m_isCurrentlyDoingCompensation");
	delete gd;

	g_PlayerSaveStack = new ArrayList(sizeof(PlayerSave));

	g_fwdPounceRewound = new GlobalForward("L4D_OnLagCompPounce", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
}

public void OnMapStart()
{
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (IsClientInGame(i))
			OnClientPutInServer(i);
	}
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, Player_OnTakeDamage);
	SDKHook(client, SDKHook_OnTakeDamagePost, Player_OnTakeDamagePost);
}

Action Player_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	PlayerSave save = {-1, false};
	int cursor = g_PlayerSaveStack.PushArray(save);

	if (g_PlayerSaveStack.FindValue(victim, PlayerSave::client) != -1)
		return Plugin_Continue;

	if (attacker <= 0 || attacker > MaxClients || !IsClientInGame(attacker))
		return Plugin_Continue;
	
	if (IsFakeClient(attacker))
		return Plugin_Continue;

	// Player may deal damage while not processing command
	if (!g_LagCompensationManager.m_isCurrentlyDoingCompensation || g_LagCompensationManager.m_pCurrentPlayer != GetEntityAddress(attacker))
	 	return Plugin_Continue;
	
	if (!IsPlayerAlive(victim) || GetClientTeam(victim) != 3)
		return Plugin_Continue;

	int ability = GetEntPropEnt(victim, Prop_Send, "m_customAbility");
	if (ability == -1 || !IsAbilityLunge(ability) || GetEntProp(victim, Prop_Send, "m_zombieClass") != 3)
		return Plugin_Continue;
	
	save.client = victim;
	float flTargetTime = GetLagCompTargetTime(attacker);

	if (GetEntProp(ability, Prop_Send, "m_isLunging"))
	{
		float flLungeStartTime = GetEntPropFloat(ability, Prop_Send, "m_lungeStartTime");

		save.m_isAttemptingToPounce = GetEntProp(victim, Prop_Send, "m_isAttemptingToPounce") == 1;
		SetPounceFlag(victim, attacker, flTargetTime >= flLungeStartTime);
		g_PlayerSaveStack.SetArray(cursor, save);
		DebugPringToChat("[DEBUG] pouncing (%N <- %N) (%d <- %d)",
			victim,
			attacker,
			save.m_isAttemptingToPounce,
			GetEntProp(victim, Prop_Send, "m_isAttemptingToPounce"));
	}
	else
	{
		CountdownTimerPtr lungeCooldownTiemr = GetLungeCooldownTimer(ability);
		if (lungeCooldownTiemr.HasStarted())
		{
			float flLungeEndTime = lungeCooldownTiemr.m_timestamp - lungeCooldownTiemr.m_duration;

			save.m_isAttemptingToPounce = GetEntProp(victim, Prop_Send, "m_isAttemptingToPounce") == 1;
			SetPounceFlag(victim, attacker, flTargetTime < flLungeEndTime);
			g_PlayerSaveStack.SetArray(cursor, save);
			DebugPringToChat("[DEBUG] not pouncing (%N <- %N) (%d <- %d)",
				victim,
				attacker,
				save.m_isAttemptingToPounce,
				GetEntProp(victim, Prop_Send, "m_isAttemptingToPounce"));
		}
	}

	return Plugin_Continue;
}

void Player_OnTakeDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype)
{
	PlayerSave save;
	{
		int i = g_PlayerSaveStack.Length-1;
		g_PlayerSaveStack.GetArray(i, save);
		g_PlayerSaveStack.Resize(i);
	}

	if (save.client == -1)
		return;
	
	Assert(save.client == victim);

	if (!IsPlayerAlive(victim) || GetClientTeam(victim) != 3)
		return;
	
	int ability = GetEntPropEnt(victim, Prop_Send, "m_customAbility");
	if (ability == -1 || !IsAbilityLunge(ability) || GetEntProp(victim, Prop_Send, "m_zombieClass") != 3)
		return;

	SetPounceFlag(victim, attacker, save.m_isAttemptingToPounce);
	DebugPringToChat("[DEBUG] Restore (%N <- %N) (%d)", victim, attacker, save.m_isAttemptingToPounce);
}

float GetLagCompTargetTime(int client)
{
	/*

	// correct is the amount of time we have to correct game time
	float correct = 0.0f;

	// Get true latency
	INetChannelInfo *nci = engine->GetPlayerNetInfo( player->entindex() );
	if ( nci )
	{
		// add network latency
		correct+= nci->GetLatency( FLOW_OUTGOING );
	}

	// NOTE:  do these computations in float time, not ticks, to avoid big roundoff error accumulations in the math
	// add view interpolation latency see C_BaseEntity::GetInterpolationAmount()
	correct += player->m_fLerpTime;

	// check bounds [0,sv_maxunlag]
	correct = clamp( correct, 0.0f, sv_maxunlag.GetFloat() );

	// correct tick send by player
	float flTargetTime = TICKS_TO_TIME( cmd->tick_count ) - player->m_fLerpTime;

	// calculate difference between tick sent by player and our latency based tick
	float deltaTime =  correct - ( gpGlobals->curtime - flTargetTime );

	if ( fabs( deltaTime ) > 0.2f )
	{
		// difference between cmd time and latency is too big > 200ms, use time correction based on latency
		// DevMsg("StartLagCompensation: delta too big (%.3f)\n", deltaTime );
		flTargetTime = gpGlobals->curtime - correct;
	}

	flTargetTime += TICKS_TO_TIME( sv_lagpushticks.GetInt() );

	*/

	static bool init = false;
	static ConVar sv_maxunlag = null, sv_lagpushticks = null;
	if (!init)
	{
		init = true;
		sv_maxunlag = FindConVar("sv_maxunlag");
		sv_lagpushticks = FindConVar("sv_lagpushticks");
	}

	// correct is the amount of time we have to correct game time
	float correct = GetClientLatency(client, NetFlow_Outgoing); // Get true latency

	// NOTE:  do these computations in float time, not ticks, to avoid big roundoff error accumulations in the math
	// add view interpolation latency see C_BaseEntity::GetInterpolationAmount()
	correct += GetEntPropFloat(client, Prop_Data, "m_fLerpTime");

	// check bounds [0,sv_maxunlag]
	if (sv_maxunlag) correct = Math_Clamp( correct, 0.0, sv_maxunlag.FloatValue );

	// correct tick send by player
	float flTargetTime = GetTickInterval() * GetPlayerCurrentCommand(client).tick_count - GetEntPropFloat(client, Prop_Data, "m_fLerpTime");

	// calculate difference between tick sent by player and our latency based tick
	float deltaTime =  correct - ( GetGameTime() - flTargetTime );

	if ( FloatAbs(deltaTime) > 0.2 )
	{
		// difference between cmd time and latency is too big > 200ms, use time correction based on latency
		flTargetTime = GetGameTime() - correct;
	}

	if (sv_lagpushticks) flTargetTime += GetTickInterval() * sv_lagpushticks.IntValue;

	return flTargetTime;
}

CountdownTimerPtr GetLungeCooldownTimer(int ability)
{
	static int s_iOffs_m_lungeCooldownTimer = -1;
	if (s_iOffs_m_lungeCooldownTimer == -1)
		s_iOffs_m_lungeCooldownTimer = FindSendPropInfo("CLunge", "m_isLunging") + 4;

	return view_as<CountdownTimerPtr>(GetEntityAddress(ability) + view_as<Address>(s_iOffs_m_lungeCooldownTimer));
}

CUserCmd GetPlayerCurrentCommand(int player)
{
	static int s_iOffs_m_pCurrentCommand = -1;
	if (s_iOffs_m_pCurrentCommand == -1)
		s_iOffs_m_pCurrentCommand = FindDataMapInfo(player, "m_hViewModel")
									+ 4*2 /* CHandle<CBaseViewModel> * MAX_VIEWMODELS */
									+ 88 /* sizeof(m_LastCmd) */;

	return view_as<CUserCmd>(GetEntData(player, s_iOffs_m_pCurrentCommand, 4));
}

bool IsAbilityLunge(int ability)
{
	char cls[64];
	GetEdictClassname(ability, cls, sizeof(cls));
	return strcmp(cls, "ability_lunge") == 0;
}

stock void DebugPringToChat(const char[] format, any ...)
{
#if DEBUG
	char buffer[512];
	VFormat(buffer, sizeof(buffer), format, 2);
	PrintToChatAll("%s", buffer);
#else
	#pragma unused format
#endif
}

stock void Assert(bool cond, const char[] msg = "")
{
#if DEBUG
	if (!cond)
	{
		ThrowError("Assertion failed! (%s)", msg);
	}
#else
	#pragma unused cond
	#pragma unused msg
#endif
}

stock any Math_Clamp(any inc, any low, any high)
{
	return (inc > high) ? high : ((inc < low) ? low : inc);
}


// riverside3: tell skill_detect what we decided. It reads m_isAttemptingToPounce in TraceAttack,
// which runs BEFORE this detour, so on a hunter the server had already landed but the shooter saw
// in the air it read 0, and the killing pellet (the engine clears the flag in OnPounceEnded before
// the death) was not a skeet. 51 of 54 such skeets went uncounted 2026-10-10..12.

void SetPounceFlag(int victim, int attacker, int value)
{
	SetEntProp(victim, Prop_Send, "m_isAttemptingToPounce", value);
	Call_StartForward(g_fwdPounceRewound);
	Call_PushCell(victim);
	Call_PushCell(attacker);
	Call_PushCell(value);
	Call_Finish();
}