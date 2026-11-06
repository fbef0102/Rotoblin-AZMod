/*
 * l4d_nullmodel_guard: a brush entity with no model is made non-solid as it spawns.
 *
 * L4D1's CM_VCollideForModel (engine.so+0xAF6D5) reads model->type at +0x6c with no NULL check (L4D2 has one).
 * A func_* spawned SOLID_VPHYSICS or SOLID_BSP with no "model" key gets model index 0 and a NULL model_t, so the
 * first trace that touches it (a common's path check, a hull trace, a bullet) segfaults the server:
 *   - c6m2_bedlam 2026-09-20: Rotoblin's model-less func_brush LOS blockers (fixed in the stripper cfgs).
 *   - hf03_themansion 2026-11-04, Riverside #4 match 992: the swinging lamp's two func_rotating pivots
 *     (ChaseVictim::Update -> IsPotentiallyTraversable -> TraceRay -> ClipRayToVPhysics -> CM_VCollideForModel).
 * Ported L4D2 maps carry the trap because L4D2 never crashed on it, so this guards every map instead of finding
 * them one by one.
 *
 * At SpawnPost an entity with model index 0 and solid type BSP or VPHYSICS gets the keyvalue "solid" "0", which
 * goes through CBaseEntity::KeyValue -> SetSolid(SOLID_NONE) and takes it out of the solid partition (setting the
 * netprop alone would leave it there, still traced). A later AddOutput "solid 2" (the bedlam blockers' BBOX) still
 * works: a BBOX trace never reads the model. Each one is logged as a NULLMODEL line.
 */
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PLUGIN_VERSION	"1.0"
#define SOLID_BSP		1
#define SOLID_VPHYSICS	6

public Plugin myinfo =
{
	name = "[L4D] Null model guard",
	author = "Malevolence",
	description = "Model-less brush entities spawn non-solid, so a trace cannot crash CM_VCollideForModel",
	version = PLUGIN_VERSION,
	url = ""
};

public void OnPluginStart()
{
	CreateConVar("l4d_nullmodel_guard_version", PLUGIN_VERSION, "l4d_nullmodel_guard version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	// Late load: whatever already spawned on this map.
	int maxEnts = GetMaxEntities();
	for (int ent = MaxClients + 1; ent < maxEnts; ent++)
	{
		if (IsValidEntity(ent)) Guard(ent);
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	// Commons and witches are by far the most created entities and always have a model.
	if (entity <= MaxClients || StrEqual(classname, "infected") || StrEqual(classname, "witch")) return;
	SDKHook(entity, SDKHook_SpawnPost, OnSpawnPost);
}

void OnSpawnPost(int entity)
{
	Guard(entity);
}

void Guard(int entity)
{
	if (!HasEntProp(entity, Prop_Send, "m_nModelIndex") || !HasEntProp(entity, Prop_Send, "m_nSolidType")) return;
	if (GetEntProp(entity, Prop_Send, "m_nModelIndex") != 0) return;
	int solid = GetEntProp(entity, Prop_Send, "m_nSolidType");
	if (solid != SOLID_BSP && solid != SOLID_VPHYSICS) return;

	DispatchKeyValue(entity, "solid", "0");

	char map[64], cls[64], name[64];
	float origin[3];
	GetCurrentMap(map, sizeof(map));
	GetEntityClassname(entity, cls, sizeof(cls));
	GetEntPropString(entity, Prop_Data, "m_iName", name, sizeof(name));
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", origin);
	LogToGame("NULLMODEL map=%s class=%s name=\"%s\" origin=%.0f %.0f %.0f solid=%d now=%d", map, cls, name,
		origin[0], origin[1], origin[2], solid, GetEntProp(entity, Prop_Send, "m_nSolidType"));
}
