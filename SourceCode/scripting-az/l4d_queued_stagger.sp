#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <dhooks>
#include <sourcescramble>

GlobalForward g_FwdOnQueuedStagger_Pre, g_FwdOnQueuedStagger_Post, g_FwdOnQueuedStagger_PostHandled;
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();

	if( test != Engine_Left4Dead )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1.");
		return APLRes_SilentFailure;
	}

	g_FwdOnQueuedStagger_Pre = new GlobalForward("L4D_OnQueuedStagger", ET_Event, Param_Cell);
	g_FwdOnQueuedStagger_Post = new GlobalForward("L4D_OnQueuedStagger_Post", ET_Ignore, Param_Cell);
	g_FwdOnQueuedStagger_PostHandled = new GlobalForward("L4D_OnQueuedStagger_PostHandled", ET_Ignore, Param_Cell);

	RegPluginLibrary("l4d_queued_stagger");
	return APLRes_Success;
}

public Plugin myinfo =
{
	name = "[L4D] Queued Stagger",
	author = "Forgetest",
	description = "Create Forward API when special infected is about to do stagger animation on the ground (Get shoved on air)",
	version = "1.0-2024/8/3",
	url = "https://github.com/jensewe"
}

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
	public MemoryPatch CreatePatchOrFail(const char[] name, bool enable = false) {
		MemoryPatch hPatch = MemoryPatch.CreateFromConf(this, name);
		if (!(enable ? hPatch.Enable() : hPatch.Validate()))
			SetFailState("Failed to patch \"%s\"", name);
		return hPatch;
	}
	public DynamicDetour CreateDetourOrFail(
			const char[] name,
			DHookCallback preHook = INVALID_FUNCTION,
			DHookCallback postHook = INVALID_FUNCTION) {
		DynamicDetour hSetup = DynamicDetour.FromConf(this, name);
		if (!hSetup)
			SetFailState("Missing detour setup \"%s\"", name);
		if (preHook != INVALID_FUNCTION && !hSetup.Enable(Hook_Pre, preHook))
			SetFailState("Failed to pre-detour \"%s\"", name);
		if (postHook != INVALID_FUNCTION && !hSetup.Enable(Hook_Post, postHook))
			SetFailState("Failed to post-detour \"%s\"", name);
		return hSetup;
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

Handle g_CallUpdateStagger;
MemoryPatch g_PatchForceExit;
bool g_bManualCall = false;
int g_iManualCallTarget;

public void OnPluginStart()
{
	GameDataWrapper gd = new GameDataWrapper("l4d_queued_stagger");

	g_PatchForceExit = gd.CreatePatchOrFail("CTerrorPlayer::UpdateStagger__GetGroundEntity_force_exit", true);
	g_CallUpdateStagger = gd.CreateSDKCallOrFail(SDKCall_Entity, SDKConf_Signature, "CTerrorPlayer::UpdateStagger");
	
	delete gd.CreateDetourOrFail("CTerrorPlayer::UpdateStagger", .postHook = DTR_UpdateStagger_Post);
	delete gd.CreateDetourOrFail("CTerrorPlayer::UpdatePounce", DTR_UpdatePounce);
	delete gd;
}

ConVar g_hCvarEnable;
bool g_bCvarEnable = true;

public void OnAllPluginsLoaded()
{
	g_hCvarEnable = FindConVar("l4d_stagger_gravity_allow");
	if(g_hCvarEnable != null)
	{
		GetCvars();
		g_hCvarEnable.AddChangeHook(ConVarChanged_Cvars);
	}
}

void ConVarChanged_Cvars(ConVar hCvar, const char[] sOldVal, const char[] sNewVal)
{
	GetCvars();
}

void GetCvars()
{    
	g_bCvarEnable = g_hCvarEnable.BoolValue;
	if(g_bCvarEnable)
	{
		g_PatchForceExit.Enable();
	}
	else
	{
		g_PatchForceExit.Disable();
	}
}

MRESReturn DTR_UpdateStagger_Post(int client, DHookReturn hReturn)
{
	if(!g_bCvarEnable) return MRES_Ignored;

	static int m_iQueuedStaggerType = -1;
	if( m_iQueuedStaggerType == -1 )
		m_iQueuedStaggerType = FindSendPropInfo("CTerrorPlayer", "m_staggerDist") + 4;

	if (!g_bManualCall)
	{
		int ground = GetEntPropEnt(client, Prop_Send, "m_hGroundEntity");
		if (ground == -1)
			return MRES_Ignored;
		
		Address pGround = GetEntityAddress(ground);
		Address ret = hReturn.Value;
		if (pGround != ret)
			return MRES_Ignored;
		
		Action result = Plugin_Continue;
		Call_StartForward(g_FwdOnQueuedStagger_Pre);
		Call_PushCell(client);
		Call_Finish(result);

		if (result == Plugin_Handled)
		{
			SetEntData(client, m_iQueuedStaggerType, -1, 4);
			
			Call_StartForward(g_FwdOnQueuedStagger_PostHandled);
			Call_PushCell(client);
			Call_Finish();
			return MRES_Ignored;
		}
		
		g_PatchForceExit.Disable();
		g_bManualCall = true;
		g_iManualCallTarget = client;
	}
	else
	{
		g_PatchForceExit.Enable();
		g_bManualCall = false;
		g_iManualCallTarget = -1;

		Call_StartForward(g_FwdOnQueuedStagger_Post);
		Call_PushCell(client);
		Call_Finish();
	}

	return MRES_Ignored;
}

MRESReturn DTR_UpdatePounce()
{
	if(!g_bCvarEnable) return MRES_Ignored;

	if (g_bManualCall)
	{
		SDKCall(g_CallUpdateStagger, g_iManualCallTarget);
	}
	return MRES_Ignored;
}

/* test only
public Action L4D_OnQueuedStagger(int client)
{
	PrintToChatAll("L4D_OnQueuedStagger : %N", client);
	return Plugin_Continue;
}

public void L4D_OnQueuedStagger_Post(int client)
{
	PrintToChatAll("L4D_OnQueuedStagger_Post : %N", client);
}

public void L4D_OnQueuedStagger_PostHandled(int client)
{
	PrintToChatAll("L4D_OnQueuedStagger_PostHandled : %N", client);
}
*/