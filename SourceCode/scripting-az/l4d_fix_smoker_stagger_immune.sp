/**
 * Smoker伸出舌頭拉人時不會被震或被推
 * 此插件就是修復這種情況
 */

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

enum struct SDKCallParamsWrapper {
	SDKType type;
	SDKPassMethod pass;
	int decflags;
	int encflags;
}

methodmap GameDataWrapper < GameData {
	public GameDataWrapper(const char[] file) {
		GameData gd = new GameData(file);
		if (!gd) SetFailState("Missing gamedata \"%s\"", file);
		return view_as<GameDataWrapper>(gd);
	}
	public Handle CreateSDKCallOrFail(
			SDKCallType type,
			SDKFuncConfSource src,
			const char[] name,
			const SDKCallParamsWrapper[] params = {},
			int numParams = 0,
			bool hasReturnValue = false,
			const SDKCallParamsWrapper ret = {}) {
		static const char k_sSDKFuncConfSource[SDKFuncConfSource][] = { "offset", "signature", "address" };
		Handle result;
		StartPrepSDKCall(type);
		if (!PrepSDKCall_SetFromConf(this, src, name))
			SetFailState("Missing %s \"%s\"", k_sSDKFuncConfSource[src], name);
		for (int i = 0; i < numParams; ++i)
			PrepSDKCall_AddParameter(params[i].type, params[i].pass, params[i].decflags, params[i].encflags);
		if (hasReturnValue)
			PrepSDKCall_SetReturnInfo(ret.type, ret.pass, ret.decflags, ret.encflags);
		if (!(result = EndPrepSDKCall()))
			SetFailState("Failed to prep sdkcall \"%s\"", name);
		return result;
	}
}

Handle g_CallTongueStateTransition;

enum TongueState
{
	STATE_TONGUE_IN_MOUTH,
	STATE_TONGUE_MISFIRE,
	STATE_TONGUE_EXTENDING,
	STATE_TONGUE_ATTACHED_TO_TARGET,
	STATE_TONGUE_DROPPING_TO_GROUND,

	NUM_TONGUE_STATES
};

// methodmap CTongueStateInfo
// {
// 	property Address m_pStateName {
// 		public get() { return LoadFromAddress(view_as<Address>(this) + view_as<Address>(0), NumberType_Int32); }
// 	}
// 	property Address pfnEnterState {
// 		public get() { return LoadFromAddress(view_as<Address>(this) + view_as<Address>(4), NumberType_Int32); }
// 	}
// 	property Address pfnLeaveState {
// 		public get() { return LoadFromAddress(view_as<Address>(this) + view_as<Address>(12), NumberType_Int32); }
// 	}
// 	property Address pfnPreThink {
// 		public get() { return LoadFromAddress(view_as<Address>(this) + view_as<Address>(20), NumberType_Int32); }
// 	}
// }

methodmap CTongue
{
	public static CTongue FromPlayer(int client) {
		int ability = GetEntPropEnt(client, Prop_Send, "m_customAbility");
		if (ability == -1 || !CTongue.IsAbilityTongue(ability)) return view_as<CTongue>(0);
		return view_as<CTongue>(ability);
	}

	public static bool IsAbilityTongue(int ability) {
		char cls[64];
		return GetEdictClassname(ability, cls, sizeof(cls)) && !strcmp(cls, "ability_tongue");
	}

	public void State_Transition(TongueState newState) {
		SDKCall(g_CallTongueStateTransition, this, newState);
	}

	property TongueState m_tongueState {
		public get() {
			return view_as<TongueState>(GetEntProp(view_as<int>(this), Prop_Send, "m_tongueState"));
		}
	}

	// property CTongueStateInfo m_pTongueStateInfo {
	// 	public get() {
	// 		static int s_iOffs_m_tongueState = -1;
	// 		if (s_iOffs_m_tongueState == -1) s_iOffs_m_tongueState = FindSendPropInfo("CTongue", "m_tongueState") + 4;
	// 		return view_as<CTongueStateInfo>(GetEntData(view_as<int>(this), s_iOffs_m_tongueState, 4));
	// 	}
	// }
}

public void OnPluginStart()
{
	GameDataWrapper gd = new GameDataWrapper("l4d_fix_smoker_stagger_immune");

	SDKCallParamsWrapper params[] = {
		{SDKType_PlainOldData, SDKPass_Plain}
	};
	g_CallTongueStateTransition = gd.CreateSDKCallOrFail(SDKCall_Entity, SDKConf_Signature, "CTongue::State_Transition", params, sizeof(params));

	delete gd;

	// RegConsoleCmd("sm_uei", uei);
}

// Action uei(int a, int b)
// {
// 	for (int i = 1; i <= MaxClients; ++i)
// 	{
// 		if (IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i))
// 			L4D_StaggerPlayer(i, i, NULL_VECTOR);
// 	}
// }

public void L4D2_OnStagger_Post(int client, int source)
{
	CTongue ability = CTongue.FromPlayer(client);
	if (!ability)
		return;

	if (ability.m_tongueState != STATE_TONGUE_EXTENDING)
		return;

	// PrintToChatAll("L4D2_OnStagger_Post : %N <- %d", client, source);

	// char name[64];
	// L4D_ReadMemoryString(ability.m_pTongueStateInfo.m_pStateName, name, sizeof(name));
	// PrintToChatAll("ability : %s", name);
	ability.State_Transition(STATE_TONGUE_DROPPING_TO_GROUND);
}

public void L4D_OnShovedBySurvivor_Post(int client, int victim, const float vecDir[3])
{
	CTongue ability = CTongue.FromPlayer(victim);
	if (!ability)
		return;

	if (ability.m_tongueState != STATE_TONGUE_EXTENDING)
		return;

	// PrintToChatAll("L4D_OnShovedBySurvivor_Post : %N <- %N", client, client);

	// char name[64];
	// L4D_ReadMemoryString(ability.m_pTongueStateInfo.m_pStateName, name, sizeof(name));
	// PrintToChatAll("ability : %s", name);
	ability.State_Transition(STATE_TONGUE_DROPPING_TO_GROUND);
}