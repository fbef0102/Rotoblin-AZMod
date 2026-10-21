#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.0"
#define GAMEDATA "l4d_physenv_teardown_fix"

// Valve use-after-free at every level change (vphysics.so, found 2026-10-21):
//
// CPhysicsEnvironment::~CPhysicsEnvironment deletes its constraint listener (this+0x6c, freed at
// 0x237ef) BEFORE it deletes the physics objects still in the world. Every static weapon/item
// spawn is pinned to the world by a fixed constraint (CItem::Spawn -> CreateFixedConstraint), and
// those constraints are still alive then, so deleting each object fires
// CPhysicsConstraint::event_object_deleted -> CPhysicsEnvironment::NotifyConstraintDisabled, which,
// while constraint notify is on (this+0x7c), calls through the freed listener. That happens ~100
// times per changelevel on stock and converted maps alike; when the freed memory has been reused the
// call jumps through garbage and srcds dies with SIGSEGV in NotifyConstraintDisabled.
//
// The game turns notify on for a new environment; nothing needs it while the level shuts down. So
// switch it off at map end, before LevelShutdownPostEntity destroys the environment, with the
// engine's own IPhysicsEnvironment::EnableConstraintNotify(false).

Handle g_hEnableConstraintNotify;
Address g_pPhysenv = Address_Null;

public Plugin myinfo =
{
	name = "[L4D1] Physics Teardown Crash Fix",
	author = "Malevolence",
	description = "Stops the vphysics use-after-free that can crash the server at a level change.",
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
	CreateConVar("l4d_physenv_teardown_fix_version", PLUGIN_VERSION, "Physics Teardown Crash Fix version", FCVAR_NOTIFY|FCVAR_DONTRECORD);

	GameData gd = new GameData(GAMEDATA);
	if( gd == null ) SetFailState("Missing gamedata \"%s\"", GAMEDATA);
	g_pPhysenv = gd.GetAddress("physenv");
	if( g_pPhysenv == Address_Null ) SetFailState("Could not find physenv");

	StartPrepSDKCall(SDKCall_Raw);
	if( !PrepSDKCall_SetFromConf(gd, SDKConf_Virtual, "EnableConstraintNotify") ) SetFailState("Missing offset EnableConstraintNotify");
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	g_hEnableConstraintNotify = EndPrepSDKCall();
	delete gd;
	if( g_hEnableConstraintNotify == null ) SetFailState("Could not prepare EnableConstraintNotify");
}

public void OnMapEnd()
{
	Address env = view_as<Address>(LoadFromAddress(g_pPhysenv, NumberType_Int32));
	if( env != Address_Null )
		SDKCall(g_hEnableConstraintNotify, env, false);
}
