#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <dhooks>
#include <sourcescramble>
#include <left4dhooks_stocks>
#include <@Forgetest/gamedatawrapper>

#define PLUGIN_VERSION "2.6"
#define DEBUG_PROF 0

#if DEBUG_PROF
#include <profiler>
#endif

public Plugin myinfo =
{
	name = "[L4D & 2] Vomit Trace Patch",
	author = "Forgetest",
	description = "Fix vomit stuck on Infected teammates & allow stricter collision test.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
}

Handle g_call_AddEntityToIgnore;
methodmap CTraceFilterSimpleList
{
	public void AddEntityToIgnore(int entity) {
		SDKCall(g_call_AddEntityToIgnore, this, entity);
	}
}

#define OP_CALL_SIZE 5

bool g_bLeft4Dead2;

MemoryPatch g_hPatch;
DynamicHook g_hDHook_UpdateAbility;
int g_iPatchOffs, g_iFuncOffs;

DynamicHook g_hDHook_PhysicsSolidMaskForEntity;

ConVar g_cvStrictCollide;
ConVar g_cvUnblockIncap;

float g_flNextBileAllowTime[MAXPLAYERS+1][MAXPLAYERS+1];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	switch (GetEngineVersion())
	{
		case Engine_Left4Dead: { g_bLeft4Dead2 = false; }
		case Engine_Left4Dead2: { g_bLeft4Dead2 = true; }
		default: { strcopy(error, err_max, "Plugin supports L4D & 2 only."); return APLRes_SilentFailure; }
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	GameDataWrapper conf = new GameDataWrapper("l4d_vomit_trace_patch");

	g_hDHook_PhysicsSolidMaskForEntity = conf.CreateDHookOrFail("CBaseEntity::PhysicsSolidMaskForEntity");
	g_hDHook_UpdateAbility = conf.CreateDHookOrFail("CBaseAbility::UpdateAbility");

	if (!g_bLeft4Dead2)
	{
		g_hPatch = conf.CreatePatchOrFail("ShouldHitEntity_MyInfectedPointer", false);
		
		Address pGetTeamNumberFuncAddr = conf.GetAddress("CBaseEntity_GetTeamNumber");
		g_iPatchOffs = conf.GetOffset("PatchOffset");
		g_iFuncOffs =
			view_as<int>(pGetTeamNumberFuncAddr) - (view_as<int>(g_hPatch.Address) + (g_iPatchOffs - 1) + OP_CALL_SIZE);
		
		conf.CreatePatchOrFail("OnVomitCollide__TraceRayMask_patch", true);
		conf.CreatePatchOrFail("OnVomitCollide__ClipRayMask_patch", true);
	}

	SDKCallParamsWrapper params[] = {
		{SDKType_CBaseEntity, SDKPass_Pointer},
	};
	g_call_AddEntityToIgnore = conf.CreateSDKCallOrFail(SDKCall_Raw, SDKConf_Signature, "CTraceFilterSimpleList::AddEntityToIgnore", params, 1, false);

	delete conf.CreateDetourOrFail("l4d_vomit_trace_patch::CTraceFilterSimpleList", _, DTR_CTraceFilterSimpleList_Post);
	delete conf.CreateDetourOrFail("l4d_vomit_trace_patch::OnVomitCollide", _, DTR_OnVomitCollide_Post);
	delete conf;

	g_cvStrictCollide = CreateConVar("vomit_collide_strict", "0", "Stricter vomit collision against hitbox instead of bounding box.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvUnblockIncap = CreateConVar("vomit_incap_unblock", "1", "Allow traces going through incapped survivors that's already biled.", FCVAR_NONE, true, 0.0, true, 1.0);

	HookEvent("ability_use", Event_ability_use);
	HookEvent("bot_player_replace", Event_bot_player_replace);
	HookEvent("player_bot_replace", Event_player_bot_replace);
}

public void OnMapStart()
{
	int entity = INVALID_ENT_REFERENCE;
	while ((entity = FindEntityByClassname(entity, "ability_vomit")) != INVALID_ENT_REFERENCE)
	{
		OnEntityCreated(entity, "ability_vomit");
	}
	while ((entity = FindEntityByClassname(entity, "vomit_particle")) != INVALID_ENT_REFERENCE)
	{
		OnEntityCreated(entity, "vomit_particle");
	}
}

void ApplyPatch(bool patch)
{
	static bool patched = false;
	if (patch && !patched)
	{
		if (!g_hPatch.Enable())
			SetFailState("Failed to enable patch \"ShouldHitEntity_MyInfectedPointer\"");
		
		StoreToAddress(g_hPatch.Address + view_as<Address>(g_iPatchOffs), g_iFuncOffs, NumberType_Int32);
		patched = true;
	}
	else if (!patch && patched)
	{
		g_hPatch.Disable();
		patched = false;
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (classname[0] == 'a')
	{
		if (!strcmp(classname, "ability_vomit"))
		{
			if (g_bLeft4Dead2)
			{
				g_hDHook_UpdateAbility.HookEntity(Hook_Pre, entity, L4D2_CVomit_UpdateAbility);
				g_hDHook_UpdateAbility.HookEntity(Hook_Post, entity, L4D2_CVomit_UpdateAbility_Post);
			}
			else
			{
				g_hDHook_UpdateAbility.HookEntity(Hook_Pre, entity, L4D1_CVomit_UpdateAbility);
				g_hDHook_UpdateAbility.HookEntity(Hook_Post, entity, L4D1_CVomit_UpdateAbility_Post);
			}

			g_hDHook_PhysicsSolidMaskForEntity.HookEntity(Hook_Post, entity, CVomit_PhysicsSolidMaskForEntity_Post);
		}
	}
	else if (classname[0] == 'v')
	{
		if (!strcmp(classname, "vomit_particle"))
		{
			g_hDHook_PhysicsSolidMaskForEntity.HookEntity(Hook_Post, entity, CVomit_PhysicsSolidMaskForEntity_Post);
		}
	}
}

int g_iVomitSprayer = -1;
MRESReturn L4D1_CVomit_UpdateAbility(int pThis)
{
	if (GetEntProp(pThis, Prop_Send, "m_isSpraying"))
	{
			g_iVomitSprayer = GetEntPropEnt(pThis, Prop_Send, "m_owner");
			ApplyPatch(true);
	}
	return MRES_Ignored;
}

MRESReturn L4D1_CVomit_UpdateAbility_Post(int pThis)
{
	ApplyPatch(false);
	g_iVomitSprayer = -1;
	return MRES_Ignored;
}

MRESReturn CVomit_PhysicsSolidMaskForEntity_Post(DHookReturn hReturn)
{
	// (L4D1) 0x200400B -> MASK_SOLID
	// (L4D2) 0x2004003 -> MASK_SOLID & ~CONTENTS_GRATE

	int flags = hReturn.Value;
	
	flags &= (~CONTENTS_GRATE);		// Unnecessary for L4D2 though

	if (g_cvStrictCollide.BoolValue)
	{
		flags |= CONTENTS_HITBOX;
	}

	hReturn.Value = flags;
	return MRES_Override;
}

#if DEBUG_PROF
bool g_bInProf;
Profiler g_Profiler = null;
ArrayList g_ExecTimes = null;
#endif
stock void BeginProfiler()
{
#if DEBUG_PROF
	if (g_Profiler == null)
		g_Profiler = new Profiler();
	
	if (g_ExecTimes == null)
		g_ExecTimes = new ArrayList();
	
	g_bInProf = true;
	g_Profiler.Start();
#endif
}

stock void EndProfiler()
{
#if DEBUG_PROF
	if (g_bInProf)
	{
		g_Profiler.Stop();
		g_bInProf = false;
		g_ExecTimes.Push(g_Profiler.Time);
	}
#endif
}

stock bool SwapProfilerResults(float &avgTime=0.0, float &medTime=0.0)
{
#if DEBUG_PROF
	if (g_ExecTimes == null)
		return false;
		
	int size = g_ExecTimes.Length;
	if (size == 0)
		return false;
	
	g_ExecTimes.Sort(Sort_Ascending, Sort_Float);

	if (size & 1)
		medTime = (g_ExecTimes.Get(size/2) + g_ExecTimes.Get(size/2+1)) * 0.5;
	else
		medTime = g_ExecTimes.Get(size/2);
	
	avgTime = 0.0;
	for (int i = size-1; i >= 0; --i)
		avgTime = avgTime + view_as<float>(g_ExecTimes.Get(i));
	
	avgTime /= size;

	g_ExecTimes.Clear();
	return true;
#else
	return false;
#endif
}

MRESReturn L4D2_CVomit_UpdateAbility(int pThis)
{
	if (GetEntProp(pThis, Prop_Send, "m_isSpraying"))
	{
		g_iVomitSprayer = GetEntPropEnt(pThis, Prop_Send, "m_owner");
		BeginProfiler();
	}
	
	return MRES_Ignored;
}

MRESReturn L4D2_CVomit_UpdateAbility_Post(int pThis)
{
	EndProfiler();

	g_iVomitSprayer = -1;
	
#if DEBUG_PROF
	if (!GetEntProp(pThis, Prop_Send, "m_isSpraying"))
	{
		float avgTime, medTime;
		if (SwapProfilerResults(avgTime, medTime))
		{
			PrintToChatAll("[Profiler] avgTime %f medTime %f", avgTime, medTime);
		}
	}
#endif

	return MRES_Ignored;
}

MRESReturn DTR_CTraceFilterSimpleList_Post(Address pThis, DHookParam hParams)
{
	if (g_iVomitSprayer == -1)
		return MRES_Ignored;

	CTraceFilterSimpleList pFilterList = view_as<CTraceFilterSimpleList>(pThis);

	float now = GetGameTime();
	if (now >= g_flNextBileAllowTime[g_iVomitSprayer][0])
		return MRES_Ignored;

	for (int i = 1; i <= MaxClients; ++i)
	{
		if (g_flNextBileAllowTime[g_iVomitSprayer][i] >= now && IsClientInGame(i))
		{
			pFilterList.AddEntityToIgnore(i);
		}
	}

	return MRES_Ignored;
}

MRESReturn DTR_OnVomitCollide_Post(DHookParam hParams)
{
	if (!g_cvUnblockIncap.BoolValue)
		return MRES_Ignored;
	
	int attacker = hParams.Get(1);
	if (attacker != g_iVomitSprayer)
		return MRES_Ignored;

	int victim = hParams.Get(2);
	if (victim <= 0 || victim > MaxClients)
		return MRES_Ignored;

	if (GetClientTeam(victim) == 2 && L4D_IsPlayerIncapacitated(victim))
	{
		g_flNextBileAllowTime[attacker][0] = g_flNextBileAllowTime[attacker][victim] = GetGameTime() + 1.0;
	}

	return MRES_Ignored;
}

void Event_ability_use(Event event, const char[] name, bool dontBroadcast)
{
	char abilityname[32];
	event.GetString("ability", abilityname, sizeof(abilityname));
	if (strcmp(abilityname, "ability_vomit"))
		return;
	
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client))
		return;
	
	for (int i = 0; i <= MaxClients; ++i)
	{
		g_flNextBileAllowTime[client][i] = -1.0;
	}
}

void Event_bot_player_replace(Event event, const char[] name, bool dontBroadcast)
{
	HandlePlayerReplace(GetClientOfUserId(event.GetInt("player")), GetClientOfUserId(event.GetInt("bot")));
}

void Event_player_bot_replace(Event event, const char[] name, bool dontBroadcast)
{
	HandlePlayerReplace(GetClientOfUserId(event.GetInt("bot")), GetClientOfUserId(event.GetInt("player")));
}

void HandlePlayerReplace(int client, int replaced)
{
	for (int i = 0; i <= MaxClients; ++i)
	{
		g_flNextBileAllowTime[client][i] = g_flNextBileAllowTime[replaced][i];
		g_flNextBileAllowTime[i][client] = g_flNextBileAllowTime[i][replaced];
	}
}
