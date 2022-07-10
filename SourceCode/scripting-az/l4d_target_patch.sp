#define PLUGIN_VERSION 		"1.6"

/*=======================================================================================
	Plugin Info:

*	Name	:	[L4D] Target Patch - Ignore Incapped
*	Author	:	SilverShot & Harry
*	Descrp	:	Overrides special infected targeting incapacitated players.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=320883
*	Plugins	:	https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:
1.6 (20-Jan-2022)
	- Remove ConVar "l4d_target_patch_vomit"
	
1.5 (6-Nov-2021)
	- make Special Infected stop attacking if no target left
	- AI Tank now ignores player who use minigun 

1.4 (23-Feb-2021)
	- fixed m_isIT not found

1.3 (20-Feb-2021)
	- Add more convars

1.2 (21-Jan-2020)
	- ignore player who is pinned by smoker & hunter.
	- change target to nearest survivor no matter anyone gets vomited.
	
1.1 (14-Jan-2020)
	- Fixed invalid entity. Thanks to "Venom1777" for reporting.

1.0 (13-Jan-2020)
	- Initial release.

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <dhooks>
#include <sourcescramble>

#define CVAR_FLAGS			FCVAR_NOTIFY
#define GAMEDATA			"l4d_target_patch"

ConVar g_hCvarAllow, g_hCvarMPGameMode, g_hCvarModes, g_hCvarModesOff, g_hCvarModesTog, g_hCvarTargets;
ConVar g_hCvarTarget_Incap, g_hCvarTarget_Pinned, g_hCvarTarget_Hanging;

int g_iCvarTargets;
bool g_bCvarAllow, g_bCvarTarget_Incap, g_bCvarTarget_Pinned,
	g_bCvarTarget_Hanging;
Handle g_hDetour;
bool g_bBlind[MAXPLAYERS+1];


// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D] Target Patch - Ignore Incapped",
	author = "SilverShot, HarryPotter",
	description = "Overrides special infected targeting players.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=320883"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if( test != Engine_Left4Dead )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	// ====================================================================================================
	// GAMEDATA
	// ====================================================================================================
	Handle hGameData = LoadGameConfigFile(GAMEDATA);
	if( hGameData == null ) SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	// Detour
	g_hDetour = DHookCreateFromConf(hGameData, "BossZombiePlayerBot::ChooseVictim");

	// patch tank targets minigun player
	MemoryPatch hPatch = MemoryPatch.CreateFromConf(hGameData, "ForEachSurvivor<MinigunnerScan>");
	if (!hPatch.Validate() || !hPatch.Enable())
		SetFailState("ForEachSurvivor<MinigunnerScan> patch failed");

	delete hGameData;

	if( !g_hDetour )
		SetFailState("Failed to find \"BossZombiePlayerBot::ChooseVictim\" signature.");



	// ====================================================================================================
	// CVARS
	// ====================================================================================================
	g_hCvarAllow =			CreateConVar(	"l4d_target_patch_allow",			"1",				"0=Plugin off, 1=Plugin on.", CVAR_FLAGS );
	g_hCvarModes =			CreateConVar(	"l4d_target_patch_modes",			"",					"Turn on the plugin in these game modes, separate by commas (no spaces). (Empty = all).", CVAR_FLAGS );
	g_hCvarModesOff =		CreateConVar(	"l4d_target_patch_modes_off",		"",					"Turn off the plugin in these game modes, separate by commas (no spaces). (Empty = none).", CVAR_FLAGS );
	g_hCvarModesTog =		CreateConVar(	"l4d_target_patch_modes_tog",		"0",				"Turn on the plugin in these game modes. 0=All, 1=Coop, 2=Survival, 4=Versus, 8=Scavenge. Add numbers together.", CVAR_FLAGS );
	g_hCvarTargets =		CreateConVar(	"l4d_target_patch_targets",			"12",				"0=Off. these Special Infected affected by this plugin: 1=Smoker, 2=Boomer, 4=Hunter, 8=Tank, 15=All. Add numbers together.", CVAR_FLAGS, true, 0.0, true, 15.0 );
	g_hCvarTarget_Incap =	CreateConVar(	"l4d_target_patch_incap",			"1",				"If 1, Special Infected ignores player who is incapacitated.", CVAR_FLAGS, true, 0.0, true, 1.0 );
	g_hCvarTarget_Pinned =	CreateConVar(	"l4d_target_patch_pinned",			"1",				"If 1, Special Infected ignores player who is pinned by another infected.", CVAR_FLAGS, true, 0.0, true, 1.0 );
	g_hCvarTarget_Hanging =	CreateConVar(	"l4d_target_patch_hanging",			"1",				"If 1, Special Infected ignores player who is hanging from ledge.", CVAR_FLAGS, true, 0.0, true, 1.0 );
	CreateConVar(							"l4d_target_patch_version",			PLUGIN_VERSION,		"Target Patch plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);

	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	g_hCvarMPGameMode.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModes.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesOff.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesTog.AddChangeHook(ConVarChanged_Allow);
	g_hCvarAllow.AddChangeHook(ConVarChanged_Allow);
	g_hCvarTargets.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarTarget_Incap.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarTarget_Pinned.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarTarget_Hanging.AddChangeHook(ConVarChanged_Cvars);
	
	IsAllowed();
}

public void OnPluginEnd()
{
	DetourAddress(false);
}



// ====================================================================================================
//					CVARS
// ====================================================================================================
public void OnConfigsExecuted()
{
	IsAllowed();
}

public void ConVarChanged_Allow(Handle convar, const char[] oldValue, const char[] newValue)
{
	IsAllowed();
}

public void ConVarChanged_Cvars(Handle convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_iCvarTargets = g_hCvarTargets.IntValue;
	g_bCvarTarget_Incap = g_hCvarTarget_Incap.BoolValue;
	g_bCvarTarget_Pinned = g_hCvarTarget_Pinned.BoolValue;
	g_bCvarTarget_Hanging = g_hCvarTarget_Hanging.BoolValue;
}

void IsAllowed()
{
	bool bCvarAllow = g_hCvarAllow.BoolValue;
	bool bAllowMode = IsAllowedGameMode();
	GetCvars();

	if( g_bCvarAllow == false && bCvarAllow == true && bAllowMode == true )
	{
		HookEvent("player_spawn",					Event_PlayerSpawn);
		HookEvent("round_start",					Event_RoundStart);
		DetourAddress(true);
		g_bCvarAllow = true;
	}

	else if( g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false) )
	{
		UnhookEvent("player_spawn",					Event_PlayerSpawn);
		UnhookEvent("round_start",					Event_RoundStart);
		DetourAddress(false);
		g_bCvarAllow = false;
	}
}

int g_iCurrentMode;
bool IsAllowedGameMode()
{
	if( g_hCvarMPGameMode == null )
		return false;

	int iCvarModesTog = g_hCvarModesTog.IntValue;
	if( iCvarModesTog != 0 )
	{
		g_iCurrentMode = 0;

		int entity = CreateEntityByName("info_gamemode");
		DispatchSpawn(entity);
		HookSingleEntityOutput(entity, "OnCoop", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnSurvival", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnVersus", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnScavenge", OnGamemode, true);
		ActivateEntity(entity);
		AcceptEntityInput(entity, "PostSpawnActivate");
		AcceptEntityInput(entity, "Kill");

		if( g_iCurrentMode == 0 )
			return false;

		if( !(iCvarModesTog & g_iCurrentMode) )
			return false;
	}

	char sGameModes[64], sGameMode[64];
	g_hCvarMPGameMode.GetString(sGameMode, sizeof(sGameMode));
	Format(sGameMode, sizeof(sGameMode), ",%s,", sGameMode);

	g_hCvarModes.GetString(sGameModes, sizeof(sGameModes));
	if( strcmp(sGameModes, "") )
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if( StrContains(sGameModes, sGameMode, false) == -1 )
			return false;
	}

	g_hCvarModesOff.GetString(sGameModes, sizeof(sGameModes));
	if( strcmp(sGameModes, "") )
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if( StrContains(sGameModes, sGameMode, false) != -1 )
			return false;
	}

	return true;
}

public void OnGamemode(const char[] output, int caller, int activator, float delay)
{
	if( strcmp(output, "OnCoop") == 0 )
		g_iCurrentMode = 1;
	else if( strcmp(output, "OnSurvival") == 0 )
		g_iCurrentMode = 2;
	else if( strcmp(output, "OnVersus") == 0 )
		g_iCurrentMode = 4;
	else if( strcmp(output, "OnScavenge") == 0 )
		g_iCurrentMode = 8;
}

public void OnClientPutInServer(int client)
{
	g_bBlind[client] = false;
}

// ====================================================================================================
//					EVENT
// ====================================================================================================
public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for( int i = 0; i <= MaxClients; i++ )
	{
		g_bBlind[i] = false;
	}
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	g_bBlind[client] = false;
}

// ====================================================================================================
//					DETOUR
// ====================================================================================================
void DetourAddress(bool patch)
{
	static bool patched;

	if( !patched && patch )
	{
		if( !DHookEnableDetour(g_hDetour, false, ChooseVictimPre) )
			SetFailState("Failed to detour \"BossZombiePlayerBot::ChooseVictim\".");

		if( !DHookEnableDetour(g_hDetour, true, ChooseVictimPost) )
			SetFailState("Failed to detour \"BossZombiePlayerBot::ChooseVictim\".");
	}
	else if( patched && !patch )
	{
		if( !DHookDisableDetour(g_hDetour, false, ChooseVictimPre) )
			SetFailState("Failed to detour \"BossZombiePlayerBot::ChooseVictim\".");

		if( !DHookDisableDetour(g_hDetour, true, ChooseVictimPost) )
			SetFailState("Failed to detour \"BossZombiePlayerBot::ChooseVictim\".");
	}
}

public MRESReturn ChooseVictimPre(int client, Handle hReturn)
{
	// Unused but hook required to prevent crashing.

	return MRES_Ignored;
}

public MRESReturn ChooseVictimPost(int client, Handle hReturn)
{
	// Ignore no target
	int victim = DHookGetReturn(hReturn);
	if( victim <= 0 )
		return MRES_Ignored;
		
	// If client is ghost (example: ghost tank)
	if( IsPlayerGhost(client) ) return MRES_Ignored;
		
	// If has target
	if( L4D_GetSurvivorVictim(client) != -1) return MRES_Ignored;

	// Ignore non-specified special infected
	int class = GetEntProp(client, Prop_Send, "m_zombieClass");
	if( class == 5 ) class = 4;

	if( g_iCvarTargets & (1 << class - 1) == 0 )
		return MRES_Ignored;

	// Find nearest survivor
	float vPos[3], vTarg[3];
	float near = 50000.0;
	float dist;
	int newVictim = 0;
	
	GetClientAbsOrigin(client, vPos);

	for( int i = 1; i <= MaxClients; i++ )
	{
		if( IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 2)
		{
			if(g_bCvarTarget_Pinned && IsPlayerPinned(i) ) //ignore player pinned by hunter&smoker
				continue;
	
			if(g_bCvarTarget_Hanging && IsHandingFromLedge(i))  //ignore player handingFromLedge
				continue;	

			if(g_bCvarTarget_Incap && IsIncapacitated(i))  //ignore player incapped
				continue;

			
			GetClientAbsOrigin(i, vTarg);
			dist = GetVectorDistance(vPos, vTarg);
			if( dist < near )
			{
				near = dist;
				newVictim = i;
			}
		}
	}

	// Override victim
	if( newVictim > 0 )
	{
		if(g_bBlind[client] == true)
		{
			g_bBlind[client] = false;
			//ToggleFreezePlayer(client, false);
		}
		DHookSetReturn(hReturn, newVictim);
		return MRES_Supercede;
	}

	g_bBlind[client] = true;
	//if(GetEntProp(client, Prop_Data, "m_fFlags") & FL_ONGROUND) ToggleFreezePlayer(client, true); // stop attacking if all players are down.
	//else ToggleFreezePlayer(client, false);
	return MRES_Ignored;
}
/*
void ToggleFreezePlayer(int client, int freeze)
{
	SetEntityMoveType(client, freeze ? MOVETYPE_NONE : MOVETYPE_WALK);
}
*/
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if(IsClientInGame(client) && IsFakeClient(client) && g_bBlind[client])
	{
		if(buttons & IN_ATTACK || buttons & IN_ATTACK2)
			return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public bool IsPlayerPinned(int client)
{
	int attacker = -1;
	attacker = GetEntPropEnt(client, Prop_Send, "m_pounceAttacker");
	if (attacker > 0) // player is pinned by hunter
	{
		return true;
	}
	attacker = GetEntPropEnt(client, Prop_Send, "m_tongueOwner");
	if (attacker > 0)  // player is pinned by smoker
	{
		return true;
	}
	return false;
}

public bool IsHandingFromLedge(int client)
{
	return view_as<bool>(GetEntProp(client, Prop_Send, "m_isHangingFromLedge") || GetEntProp(client, Prop_Send, "m_isFallingFromLedge"));
}

public bool IsIncapacitated(int client)
{
	return view_as<bool>(GetEntProp(client, Prop_Send, "m_isIncapacitated"));
}

int L4D_GetSurvivorVictim(int client)
{
	int victim;
	
    /* Hunter */
	victim = GetEntPropEnt(client, Prop_Send, "m_pounceVictim");
	if (victim > 0)
	{
		return victim;
 	}

    /* Smoker */
 	victim = GetEntPropEnt(client, Prop_Send, "m_tongueVictim");
	if (victim > 0)
	{
		return victim;	
	}

	return -1;
}

bool IsPlayerGhost(int client)
{
	return view_as<bool>(GetEntProp(client, Prop_Send, "m_isGhost"));
}