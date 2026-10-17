#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <dhooks>

#define PLUGIN_VERSION "1.1"

// Stops hittables (cars, dumpsters, forklifts...) drawing away from where they really are.
//
// Cause (client.dylib, 2026-10-16): the client keeps a physics shadow of every networked
// prop_physics, and OnRenderStart runs PhysicsSimulate after entity interpolation, so the
// prop is DRAWN at that shadow (C_BaseEntity::VPhysicsUpdate -> SetAbsOrigin). Dead commons
// become client-only ragdolls in COLLISION_GROUP_DEBRIS. With the prop in COLLISION_GROUP_NONE
// they collide with the shadow, so a punched car sliding into bodies stops on screen while the
// server car keeps going. Low violence hides it because it retires ragdolls at once.
//
// Fix: hittables (m_hasTankGlow) go to COLLISION_GROUP_NPC_SCRIPTED (19). In the game's ShouldCollide (server
// and client agree) 19 behaves like NONE against every group except DEBRIS (1), DEBRIS_TRIGGER (2),
// DOOR_BLOCKER (14) and DISSOLVING (16), so players, infected, the tank, rocks and other props
// collide with it as before. The one gameplay check that wants NONE is IsPushableEntity, used only
// by the tank's punch target search (HulkSmashableEnumerator); the detour answers it as if the
// prop were still NONE.
//
// The group is only ever set when a hittable spawns (map load, before anyone has died) and is never
// changed back at runtime: the client does not recheck its physics collision filter when a networked
// group changes, and flipping it under a car already resting on ragdolls crashed a client once in
// testing. So the cvar and a late load only affect props spawned afterwards.
//
// 1.1 (2026-10-16, server.so audit, l4d-source docs/annotated/hittables/):
// - prop_physics_override is hooked too. CPhysicsProp::Spawn renames it to prop_physics only after
//   OnEntityCreated, and Rotoblin's stripper turns the forklift, the militia rocks and c13m2's rock2
//   into prop_physics_override, so those hittables were never moved and still desynced.
// - Break pieces: CBreakableProp::Break gives each piece the parent's group (INTERACTIVE if the
//   parent is NONE) before the piece spawns, so a piece of a moved hittable could come out in 19.
//   Any such piece is put in INTERACTIVE, as in stock. Not seen on the No Mercy 2 pillars (rig
//   2026-10-16: their pieces came out INTERACTIVE under 1.0 too), so it is a guard.
// - m_hasTankGlow is only written inside CPhysicsProp::Spawn, so the next-frame recheck could never
//   catch anything and is gone.

#define GROUP_NONE			0
#define GROUP_INTERACTIVE	4	// what the game gives a break piece of a NONE prop
#define GROUP_HITTABLE		19	// COLLISION_GROUP_NPC_SCRIPTED

ConVar g_cvEnable;
ConVar g_cvTurbo;
Handle g_hSetGroup;
bool g_bMoved[2049];	// prop we moved from NONE to GROUP_HITTABLE

public Plugin myinfo =
{
	name = "L4D hittable desync fix",
	author = "Malevolence",
	description = "Stops dead commons' ragdolls dragging hittables out of place on clients",
	version = PLUGIN_VERSION,
	url = ""
};

public void OnPluginStart()
{
	GameData gd = new GameData("l4d_hittable_desync_fix");
	if (!gd) SetFailState("gamedata l4d_hittable_desync_fix");

	StartPrepSDKCall(SDKCall_Entity);
	if (!PrepSDKCall_SetFromConf(gd, SDKConf_Signature, "CBaseEntity::SetCollisionGroup")) SetFailState("SetCollisionGroup signature");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	g_hSetGroup = EndPrepSDKCall();
	if (!g_hSetGroup) SetFailState("SetCollisionGroup call");

	DynamicDetour d = DynamicDetour.FromConf(gd, "HD_IsPushableEntity");
	if (!d || !d.Enable(Hook_Pre, IsPushable_Pre)) SetFailState("IsPushableEntity detour");
	delete gd;

	g_cvTurbo = FindConVar("sv_turbophysics");
	g_cvEnable = CreateConVar("l4d_hittable_desync_fix", "1", "1 = hittables spawned from now on ignore client-side corpses (takes effect on the next map)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	CreateConVar("l4d_hittable_desync_fix_version", PLUGIN_VERSION, "Plugin version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	RegAdminCmd("sm_hittable_fix_status", Cmd_Status, ADMFLAG_GENERIC, "List hittables and their collision group");
}

bool IsHittableClass(const char[] cls)
{
	return StrEqual(cls, "prop_physics") || StrEqual(cls, "prop_physics_override") || StrEqual(cls, "prop_physics_multiplayer") || StrEqual(cls, "prop_car_alarm");
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (entity > 0 && entity < sizeof(g_bMoved) && IsHittableClass(classname))
		SDKHook(entity, SDKHook_SpawnPost, OnSpawnPost);
}

public void OnEntityDestroyed(int entity)
{
	if (entity > 0 && entity < sizeof(g_bMoved)) g_bMoved[entity] = false;
}

void OnSpawnPost(int entity)
{
	// a break piece inherited GROUP_HITTABLE from a hittable we moved: stock would give it INTERACTIVE
	if (!g_bMoved[entity] && GetEntProp(entity, Prop_Send, "m_CollisionGroup") == GROUP_HITTABLE)
	{
		SDKCall(g_hSetGroup, entity, GROUP_INTERACTIVE);
		return;
	}
	// set it before the prop is ever networked, so no client sees it in NONE first
	if (!g_cvEnable.BoolValue) return;
	Apply(entity);
}

void Apply(int entity)
{
	if (g_bMoved[entity]) return;
	if (GetEntProp(entity, Prop_Send, "m_CollisionGroup") != GROUP_NONE) return;
	if (GetEntityMoveType(entity) != MOVETYPE_VPHYSICS) return;
	// the game's own hittable flag (the props that glow for the tank)
	if (!HasEntProp(entity, Prop_Send, "m_hasTankGlow") || !GetEntProp(entity, Prop_Send, "m_hasTankGlow", 1)) return;
	SDKCall(g_hSetGroup, entity, GROUP_HITTABLE);
	g_bMoved[entity] = true;
}

// Stock: sv_turbophysics && group == NONE && class is prop_physics / prop_physics_multiplayer.
// For a prop we moved, answer with its group read as NONE.
MRESReturn IsPushable_Pre(DHookReturn ret, DHookParam params)
{
	if (params.IsNull(1)) return MRES_Ignored;
	int entity = params.Get(1);
	if (entity <= 0 || entity >= sizeof(g_bMoved) || !g_bMoved[entity]) return MRES_Ignored;
	if (GetEntProp(entity, Prop_Send, "m_CollisionGroup") != GROUP_HITTABLE) return MRES_Ignored;

	char cls[64];
	GetEntityClassname(entity, cls, sizeof(cls));
	ret.Value = g_cvTurbo.BoolValue && (StrEqual(cls, "prop_physics") || StrEqual(cls, "prop_physics_multiplayer"));
	return MRES_Supercede;
}

Action Cmd_Status(int client, int args)
{
	char cls[64], model[PLATFORM_MAX_PATH];
	int moved, total;
	for (int i = MaxClients + 1; i < sizeof(g_bMoved); i++)
	{
		if (!IsValidEntity(i)) continue;
		GetEntityClassname(i, cls, sizeof(cls));
		if (!IsHittableClass(cls)) continue;
		total++;
		if (g_bMoved[i]) moved++;
		if (args > 0)
		{
			GetEntPropString(i, Prop_Data, "m_ModelName", model, sizeof(model));
			ReplyToCommand(client, "%d %s %s group %d%s", i, cls, model, GetEntProp(i, Prop_Send, "m_CollisionGroup"), g_bMoved[i] ? " (moved)" : "");
		}
	}
	ReplyToCommand(client, "[hittable_fix] %s, %d of %d physics props moved to group %d", g_cvEnable.BoolValue ? "on" : "off", moved, total, GROUP_HITTABLE);
	return Plugin_Handled;
}
