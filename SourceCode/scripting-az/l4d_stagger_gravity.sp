#define PLUGIN_VERSION 		"1.0h-2023/12/14"

/*======================================================================================
	Plugin Info:

*	Name	:	[L4D & L4D2] Stagger Animation - Gravity Allowed
*	Author	:	SilverShot, Harry
*	Descrp	:	Allows gravity when players are staggering, otherwise they would float in the air until the animation completes. Also allows staggering over a ledge and falling.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=344297
*	Plugins	:	https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

======================================================================================*/


#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>

#define CVAR_FLAGS			FCVAR_NOTIFY
#define BLOCK_TIME			0.3		// How long to block shooting/shoving/moving when staggering


ConVar g_hCvarAllow, g_hCvarMPGameMode, g_hCvarModes, g_hCvarModesOff, g_hCvarModesTog;
bool g_bCvarAllow, g_bMapStarted, g_bRoundStarted;

bool g_bStagger[MAXPLAYERS+1], g_bFrameStagger[MAXPLAYERS+1], g_bBlockXY[MAXPLAYERS+1];
float g_vStart[MAXPLAYERS+1][3], g_fDist[MAXPLAYERS+1], g_fTtime[MAXPLAYERS+1], g_fTimeBlock[MAXPLAYERS+1];



// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D & L4D2] Stagger Animation - Gravity Allowed",
	author = "SilverShot, HarryPotter",
	description = "Allows gravity when players are staggering, otherwise they would float in the air until the animation completes. Also allows staggering over a ledge and falling.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=344297"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();

	if( test != Engine_Left4Dead && test != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
    if( GetFeatureStatus(FeatureType_Native, "Left4DHooks_Version") != FeatureStatus_Available || Left4DHooks_Version() < 1139 )
		SetFailState("\n==========\nThis plugin requires 'Left 4 DHooks' version 1.139 or newer. Please update that plugin.\n==========");
}

public void OnPluginStart()
{
	g_hCvarAllow = CreateConVar(		"l4d_stagger_gravity_allow",		"1",			"0=Plugin off, 1=Plugin on.", CVAR_FLAGS );
	g_hCvarModes = CreateConVar(		"l4d_stagger_gravity_modes",		"",				"Turn on the plugin in these game modes, separate by commas (no spaces). (Empty = all).", CVAR_FLAGS );
	g_hCvarModesOff = CreateConVar(		"l4d_stagger_gravity_modes_off",	"",				"Turn off the plugin in these game modes, separate by commas (no spaces). (Empty = none).", CVAR_FLAGS );
	g_hCvarModesTog = CreateConVar(		"l4d_stagger_gravity_modes_tog",	"0",			"Turn on the plugin in these game modes. 0=All, 1=Coop, 2=Survival, 4=Versus, 8=Scavenge. Add numbers together.", CVAR_FLAGS );
	CreateConVar(						"l4d_stagger_gravity_version",		PLUGIN_VERSION,	"Stagger Animation - Gravity Allowed plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	//AutoExecConfig(true,				"l4d_stagger_gravity");

	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	g_hCvarMPGameMode.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModes.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesOff.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesTog.AddChangeHook(ConVarChanged_Allow);
	g_hCvarAllow.AddChangeHook(ConVarChanged_Allow);

	//RegAdminCmd("sm_test", CmdTest, ADMFLAG_ROOT);

	LoadTranslations("common.phrases");
}



// ====================================================================================================
//					CVARS
// ====================================================================================================
public void OnConfigsExecuted()
{
	IsAllowed();
}

void ConVarChanged_Allow(Handle convar, const char[] oldValue, const char[] newValue)
{
	IsAllowed();
}

void IsAllowed()
{
	bool bCvarAllow = g_hCvarAllow.BoolValue;
	bool bAllowMode = IsAllowedGameMode();

	if( g_bCvarAllow == false && bCvarAllow == true && bAllowMode == true )
	{
		g_bCvarAllow = true;
		HookEvent("round_start",	Event_RoundStart, EventHookMode_PostNoCopy);
		HookEvent("round_end",		Event_RoundEnd, EventHookMode_PostNoCopy);
		HookEvent("player_spawn",	Event_PlayerSpawn);
	}

	else if( g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false) )
	{
		g_bCvarAllow = false;
		UnhookEvent("round_start",	Event_RoundStart, EventHookMode_PostNoCopy);
		UnhookEvent("round_end",	Event_RoundEnd, EventHookMode_PostNoCopy);
		UnhookEvent("player_spawn",	Event_PlayerSpawn);
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
		if( g_bMapStarted == false )
			return false;

		g_iCurrentMode = 0;

		int entity = CreateEntityByName("info_gamemode");
		if( IsValidEntity(entity) )
		{
			DispatchSpawn(entity);
			HookSingleEntityOutput(entity, "OnCoop", OnGamemode, true);
			HookSingleEntityOutput(entity, "OnSurvival", OnGamemode, true);
			HookSingleEntityOutput(entity, "OnVersus", OnGamemode, true);
			HookSingleEntityOutput(entity, "OnScavenge", OnGamemode, true);
			ActivateEntity(entity);
			AcceptEntityInput(entity, "PostSpawnActivate");
			if( IsValidEntity(entity) ) // Because sometimes "PostSpawnActivate" seems to kill the ent.
				RemoveEdict(entity); // Because multiple plugins creating at once, avoid too many duplicate ents in the same frame
		}

		if( g_iCurrentMode == 0 )
			return false;

		if( !(iCvarModesTog & g_iCurrentMode) )
			return false;
	}

	char sGameModes[64], sGameMode[64];
	g_hCvarMPGameMode.GetString(sGameMode, sizeof(sGameMode));
	Format(sGameMode, sizeof(sGameMode), ",%s,", sGameMode);

	g_hCvarModes.GetString(sGameModes, sizeof(sGameModes));
	if( sGameModes[0] )
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if( StrContains(sGameModes, sGameMode, false) == -1 )
			return false;
	}

	g_hCvarModesOff.GetString(sGameModes, sizeof(sGameModes));
	if( sGameModes[0] )
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if( StrContains(sGameModes, sGameMode, false) != -1 )
			return false;
	}

	return true;
}

void OnGamemode(const char[] output, int caller, int activator, float delay)
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



// ====================================================================================================
//					EVENTS
// ====================================================================================================
public void OnMapStart()
{
	g_bMapStarted = true;
	g_bRoundStarted = true;
}

public void OnMapEnd()
{
	g_bMapStarted = false;
	ResetPlugin();
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_bRoundStarted = true;
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	g_bRoundStarted = false;
	ResetPlugin();
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	ResetVars(client);
}

void ResetPlugin()
{
	for( int i = 1; i <= MaxClients; i++ )
	{
		ResetVars(i);
	}
}

void ResetVars(int client)
{
	g_bStagger[client] = false;
	g_bFrameStagger[client] = false;
	g_bBlockXY[client] = false;
	g_vStart[client] = view_as<float>({ 0.0, 0.0, 0.0 });
	g_fDist[client] = 0.0;
	g_fTtime[client] = 0.0;
	g_fTimeBlock[client] = 0.0;
}



// ====================================================================================================
//					COMMAND
// ====================================================================================================
stock Action CmdTest(int client, int args)
{
	if( !client )
	{
		ReplyToCommand(client, "Command can only be used %s", IsDedicatedServer() ? "in game on a dedicated server." : "in chat on a Listen server.");
		return Plugin_Handled;
	}

	PrintToChatAll("g_bFrameStagger[client]: %d, g_bStagger[client]: %d, g_bBlockXY[client]: %d, g_fDist[client]: %.1f, g_fTtime[client]: %.1f, g_fTimeBlock[client]: %.1f", 
		g_bFrameStagger[client], g_bStagger[client], g_bBlockXY[client], g_fDist[client], g_fTtime[client], g_fTimeBlock[client]);

	return Plugin_Handled;
}

// ====================================================================================================
//					FORWARDS
// ====================================================================================================
public Action L4D_OnMotionControlledXY(int client, int activity)
{
	if( !g_bCvarAllow || !g_bRoundStarted ) return Plugin_Continue;

	//PrintToChatAll("%N L4D_OnMotionControlledXY", client);

	int team = GetClientTeam(client);
	//if(team == 3) return Plugin_Continue;
	
	// Verify air stagger
	if( GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") == -1 && 
		( team == 3 || (team == 2 && L4D_GetPinnedInfected(client) <= 0 && !L4D_IsPlayerHangingFromLedge(client) && !L4D_IsPlayerIncapacitated(client)) )
		//( team == 2 && L4D_GetPinnedInfected(client) <= 0 && !L4D_IsPlayerHangingFromLedge(client) && !L4D_IsPlayerIncapacitated(client) )
		)
	{
		g_bBlockXY[client] = true;

		//SetAttack(client);
		g_bStagger[client] = true;
		return Plugin_Handled;
	}
	else
	{	
		if( g_bStagger[client] )
		{
			float vPos[3];
			GetClientAbsOrigin(client, vPos);
			GetEntPropVector(client, Prop_Send, "m_staggerStart", g_vStart[client]);

			float dist = GetVectorDistance(g_vStart[client], vPos);
			g_fDist[client] = GetEntPropFloat(client, Prop_Send, "m_staggerDist");
			g_fDist[client] -= dist;

			g_fTtime[client] = GetEntPropFloat(client, Prop_Send, "m_staggerTimer", 1);

			//PrintToChatAll("%N L4D_CancelStagger", client);
			L4D_CancelStagger(client);
			g_bStagger[client] = false;

			// Continue stagger after falling

			RequestFrame(OnFrameStagger, GetClientUserId(client));

			//SetAttack(client);
			if(GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") >= 0) return Plugin_Continue;
			return Plugin_Handled;
		}

		if( g_fTimeBlock[client] == 0.0 )
		{
			g_fTimeBlock[client] = GetGameTime() + 0.5;

			//SetAttack(client);
			// To Do: 被震後掉下去不會繼續被震
			if(GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") >= 0)  return Plugin_Continue;
			return Plugin_Handled;
		}

		if( g_fTimeBlock[client] - GetGameTime() > 0.0 )
		{
			//SetAttack(client);
			if(GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") >= 0)  return Plugin_Continue;
			return Plugin_Handled;
		}
	}

	if( g_bBlockXY[client] )
	{
		//SetAttack(client);
		if(GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") >= 0) return Plugin_Continue;
		return Plugin_Handled;
	}

	return Plugin_Continue;
}
/*
public Action L4D2_OnStagger(int client, int source)
{
	if( !g_bCvarAllow || !g_bRoundStarted ) return Plugin_Continue;

	//PrintToChatAll("%N L4D2_OnStagger", client);

	int team = GetClientTeam(client);
	// Verify air stagger
	if( team == 2 )
	{
		if(L4D_GetPinnedInfected(client) > 0) return Plugin_Continue;
		if(L4D_IsPlayerHangingFromLedge(client)) return Plugin_Continue;
		if(L4D_IsPlayerIncapacitated(client)) return Plugin_Continue;
	}
	else if(team == 3) 
	{
		return Plugin_Continue;
	}

	if( GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") == -1)
	{

	}

	return Plugin_Continue;
}
*/

public void L4D2_OnPounceOrLeapStumble_Post(int client, int attacker)
{
	// Verify air stagger
	if( g_bCvarAllow && g_bRoundStarted )
	{
		//PrintToChatAll("%N L4D2_OnPounceOrLeapStumble_Post", client);

		int team = GetClientTeam(client);

		if(GetClientTeam(client) == 2)
		{
			if(L4D_GetPinnedInfected(client) > 0) return;
			if(L4D_IsPlayerHangingFromLedge(client)) return;
			if(L4D_IsPlayerIncapacitated(client)) return;
		}
		else if(team == 3) 
		{
			return;
		}
		
		if( GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") == -1)
		{
			L4D_StaggerPlayer(client, attacker, NULL_VECTOR);
		}
	}
}

public Action L4D_OnCancelStagger(int client)
{
	if( !g_bCvarAllow || !g_bRoundStarted ) return Plugin_Continue;

	//PrintToChatAll("%N L4D_OnCancelStagger", client);

	int team = GetClientTeam(client);
	//if(team == 3) return Plugin_Continue;

	float starttime = GetEntPropFloat(client, Prop_Send, "m_staggerTimer", 1);

	// Maybe fallen off a ledge that wants to cancel the stagger, block the cancel
	if( g_bFrameStagger[client] )
	{
		g_bFrameStagger[client] = false;
		return Plugin_Handled;
	}

	if( GetGameTime() < starttime)
	{
		// We should still be staggering but maybe fell off a ledge, let it cancel and start stagger again nexxt frame
		g_bStagger[client] = false;

		if( team == 2 )
		{
			if(L4D_GetPinnedInfected(client) > 0 
			|| L4D_IsPlayerHangingFromLedge(client)
			|| L4D_IsPlayerIncapacitated(client))
			{
				g_bBlockXY[client] = false;
				return Plugin_Continue;
			}
		}

		// Continue stagger after falling
		g_bFrameStagger[client] = true;
		RequestFrame(OnFrameStagger, GetClientUserId(client));
	}
	else
	{
		g_bBlockXY[client] = false;
	}

	return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int &buttons)
{
	if( g_bCvarAllow && g_bRoundStarted )
	{
		if( GetGameTime() > g_fTimeBlock[client])
		{
			g_fTimeBlock[client] = 0.0;
		}

		if(g_bBlockXY[client] && L4D_IsPlayerStaggering(client) == false)
		{
			g_bBlockXY[client] = false;
			g_fTimeBlock[client] = 0.0;
		}

		if( g_bStagger[client] || g_bFrameStagger[client])
		{
			if(GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") != -1 || IsOnLadder(client))
			{
				//PrintToChatAll("%N OnPlayerRunCmd", client);

				g_bStagger[client] = false;
				g_bFrameStagger[client] = false;
			}
		}

		if (g_bFrameStagger[client] && buttons & (IN_FORWARD|IN_BACK|IN_MOVELEFT|IN_MOVERIGHT))
		{
			buttons &= ~IN_FORWARD;
			buttons &= ~IN_BACK;
			buttons &= ~IN_MOVELEFT;
			buttons &= ~IN_MOVERIGHT;
			return Plugin_Changed;
		}
	}

	return Plugin_Continue;
}
/*
void SetAttack(int client)
{
	int weapon;
	weapon = GetPlayerWeaponSlot(client, 0);
	if( weapon != -1 )
	{
		SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + BLOCK_TIME);
		SetEntPropFloat(weapon, Prop_Send, "m_flNextSecondaryAttack", GetGameTime() + BLOCK_TIME);
	}

	weapon = GetPlayerWeaponSlot(client, 1);
	if( weapon != -1 )
	{
		SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + BLOCK_TIME);
		SetEntPropFloat(weapon, Prop_Send, "m_flNextSecondaryAttack", GetGameTime() + BLOCK_TIME);
	}

	SetEntPropFloat(client, Prop_Send, "m_flNextShoveTime", GetGameTime() + BLOCK_TIME);
	SetEntPropFloat(client, Prop_Send, "m_jumpSupressedUntil", GetGameTime() + BLOCK_TIME);
}*/

void OnFrameStagger(int client)
{
	client = GetClientOfUserId(client);
	if( client && IsClientInGame(client) )
	{
		L4D_StaggerPlayer(client, client, g_vStart[client]);
		SetEntPropFloat(client, Prop_Send, "m_staggerDist", g_fDist[client]);
		SetEntPropFloat(client, Prop_Send, "m_staggerTimer", g_fTtime[client], 1);
	}
}

bool IsOnLadder(int client)
{
	return GetEntityMoveType(client) == MOVETYPE_LADDER;
}