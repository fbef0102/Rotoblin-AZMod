#define PLUGIN_VERSION 		"1.2h-2024/8/3"
#define DEBUG 		0

/*======================================================================================
	Plugin Info:

*	Name	:	[L4D] Stagger Animation - Gravity Allowed
*	Author	:	SilverShot, Harry
*	Descrp	:	Allows gravity when players are staggering, otherwise they would float in the air until the animation completes. Also allows staggering over a ledge and falling.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=344297
*	Plugins	:	https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

======================================================================================*/


#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>
#include <l4d_queued_stagger>

#define CVAR_FLAGS			FCVAR_NOTIFY
#define BLOCK_TIME			0.3		// How long to block shooting/shoving/moving when staggering
#define L4D1_TANK_STAGGER_TIME 2.9 //tank 被推/震時間 (L4D1 對抗寫死)
#define L4D1_BOOMER_STAGGER_TIME 2.7 //boomer 被推/震時間 (L4D1 對抗寫死)

ConVar survivor_max_tongue_stagger_duration, z_max_stagger_duration;
float g_fCvar_survivor_max_tongue_stagger_duration, g_fCvar_z_max_stagger_duration;

ConVar g_hCvarAllow, g_hCvarMPGameMode, g_hCvarModes, g_hCvarModesOff, g_hCvarModesTog;
bool g_bCvarAllow, g_bMapStarted, g_bRoundStarted;

bool 
	g_bStagger[MAXPLAYERS+1], 
	g_bFrameStagger[MAXPLAYERS+1], 
	g_bBlockXY[MAXPLAYERS+1],
	g_bStaggerSelf[MAXPLAYERS+1],
	g_bHurtByTank[MAXPLAYERS+1],
	g_bStaggerNew[MAXPLAYERS+1];

float 
	g_vStart[MAXPLAYERS+1][3], 
	g_fDist[MAXPLAYERS+1], 
	g_fTtime[MAXPLAYERS+1], 
	g_fTimeBlock[MAXPLAYERS+1];



// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D] Stagger Animation - Gravity Allowed",
	author = "SilverShot, HarryPotter, Forgetest",
	description = "Allows gravity when players are staggering, otherwise they would float in the air until the animation completes. Also allows staggering over a ledge and falling.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=344297"
}

#define ZC_BOOMER 2
#define ZC_HUNTER 3
#define ZC_TANK 5

bool bLate;
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();

	if( test != Engine_Left4Dead)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1.");
		return APLRes_SilentFailure;
	}

	bLate = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	survivor_max_tongue_stagger_duration = FindConVar("survivor_max_tongue_stagger_duration");
	z_max_stagger_duration = FindConVar("z_max_stagger_duration");

	GetCvars();
	survivor_max_tongue_stagger_duration.AddChangeHook(ConVarChanged_Cvars);
	z_max_stagger_duration.AddChangeHook(ConVarChanged_Cvars);

	g_hCvarAllow = CreateConVar(		"l4d_stagger_gravity_allow",		"1",			"0=Plugin off, 1=Plugin on.", CVAR_FLAGS );
	g_hCvarModes = CreateConVar(		"l4d_stagger_gravity_modes",		"",				"Turn on the plugin in these game modes, separate by commas (no spaces). (Empty = all).", CVAR_FLAGS );
	g_hCvarModesOff = CreateConVar(		"l4d_stagger_gravity_modes_off",	"",				"Turn off the plugin in these game modes, separate by commas (no spaces). (Empty = none).", CVAR_FLAGS );
	g_hCvarModesTog = CreateConVar(		"l4d_stagger_gravity_modes_tog",	"0",			"Turn on the plugin in these game modes. 0=All, 1=Coop, 2=Survival, 4=Versus, 8=Scavenge. Add numbers together.", CVAR_FLAGS );
	CreateConVar(						"l4d_stagger_gravity_version",		PLUGIN_VERSION,	"Stagger Animation - Gravity Allowed plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	AutoExecConfig(true,				"l4d_stagger_gravity");

	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	g_hCvarMPGameMode.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModes.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesOff.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesTog.AddChangeHook(ConVarChanged_Allow);
	g_hCvarAllow.AddChangeHook(ConVarChanged_Allow);

	#if DEBUG
	RegAdminCmd("sm_test", CmdTest, ADMFLAG_ROOT);
	#endif

	LoadTranslations("common.phrases");

	if(bLate)
	{
		LateLoad();
	}
}

void LateLoad()
{
    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsClientInGame(client))
            continue;

        OnClientPutInServer(client);
    }
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


void ConVarChanged_Cvars(ConVar hCvar, const char[] sOldVal, const char[] sNewVal)
{
	GetCvars();
}

void GetCvars()
{
    g_fCvar_survivor_max_tongue_stagger_duration = survivor_max_tongue_stagger_duration.FloatValue;
    g_fCvar_z_max_stagger_duration = z_max_stagger_duration.FloatValue;
}

void IsAllowed()
{
	GetCvars();
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

public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_OnTakeDamagePost, SurvivorOnTakeDamagePost);
}

//SDKHOOKS-------------------------------

void SurvivorOnTakeDamagePost(int client, int attacker, int inflictor, float damage, int damagetype)
{
	if( !g_bCvarAllow || !g_bRoundStarted ) return;

	if (!IsClientInGame(client) || GetClientTeam(client) != 2) return;

	if (damagetype & DMG_FALL) //墬樓傷害會突然停止硬質 (不會觸發L4D_OnCancelStagger)
	{
		#if DEBUG
		DebugPrint("SurvivorOnTakeDamagePost DMG_FALL %N ", client);
		#endif
		if( GetGameTime() < g_fTtime[client])
		{
			g_bStagger[client] = false;

			#if DEBUG
			DebugPrint("SurvivorOnTakeDamagePost->OnFrameStagger %N ", client);
			#endif
			g_bFrameStagger[client] = true;
			g_bStaggerNew[client] = false;
			RequestFrame(OnFrameStagger, GetClientUserId(client));
		}

		return;
	}

	if(!IsValidEntity(inflictor)) return;	

	static char sClassName[64];
	GetEntityClassname(inflictor, sClassName, sizeof(sClassName));
	if(strncmp(sClassName, "weapon_tank_claw", 16, false) == 0 || strncmp(sClassName, "tank_rock", 9, false) == 0) //被tank傷害到停止一切運作
	{
		g_bHurtByTank[client] = true;
	}
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
	g_bStaggerSelf[client] = false;
	g_bHurtByTank[client] = false;
	g_bStaggerNew[client] = false;
}



// ====================================================================================================
//					COMMAND
// ====================================================================================================
#if DEBUG
Action CmdTest(int client, int args)
{
	if( !client )
	{
		ReplyToCommand(client, "Command can no be used on server console");
		return Plugin_Handled;
	}

	DebugPrint("g_bFrameStagger: %d, g_bStagger: %d, g_bBlockXY: %d, \ng_vStart: %.1f  %.1f  %.1f, g_fDist: %.1f, g_fTtime: %.1f, g_fTimeBlock: %.1f, now: %.1f", 
		g_bFrameStagger[client], g_bStagger[client], g_bBlockXY[client], g_vStart[client][0], g_vStart[client][1], g_vStart[client][2], g_fDist[client], g_fTtime[client], g_fTimeBlock[client], GetGameTime());

	return Plugin_Handled;
}
#endif

// ====================================================================================================
//					FORWARDS
// ====================================================================================================
public Action L4D_OnMotionControlledXY(int client, int activity)
{
	if( !g_bCvarAllow || !g_bRoundStarted ) return Plugin_Continue;
	if( GetEntityMoveType(client) == MOVETYPE_NOCLIP) return Plugin_Continue;

	int team = GetClientTeam(client);

	bool bBusy;
	if(team == 3)
	{
		if(L4D_GetPinnedSurvivor(client) > 0)
		{
			bBusy = true;
		}
	}
	else if( team == 2 )
	{
		if(L4D_GetPinnedInfected(client) > 0 
		|| L4D_IsPlayerHangingFromLedge(client)
		|| L4D_IsPlayerIncapacitated(client)
		|| g_bHurtByTank[client])
		{
			bBusy = true;
		}
	}
	
	int m_hGroundEntity = GetEntPropEnt(client, Prop_Send, "m_hGroundEntity");
	// Verify air stagger
	if(m_hGroundEntity == -1 && !bBusy)
	{
		//DebugPrint("%N L4D_OnMotionControlledXY 1", client);
		g_bBlockXY[client] = true;

		//SetAttack(client);
		g_bStagger[client] = true;

		return Plugin_Handled;
	}
	else
	{	
		//DebugPrint("%N L4D_OnMotionControlledXY 2", client);
		if(bBusy)
		{
			#if DEBUG
			DebugPrint("CancelStagger %N ", client);
			#endif
			L4D_CancelStagger(client);
			return Plugin_Continue;
		}

		//在地上
		if( g_bStagger[client] )
		{
			//float vStart[3];
			//GetEntPropVector(client, Prop_Send, "m_staggerStart", vStart);
			//if(vStart[0] + vStart[1] + vStart[2] != 0.0) g_vStart[client] = vStart;

			//float vPos[3];
			//GetClientAbsOrigin(client, vPos);
			//float dist = GetVectorDistance(g_vStart[client], vPos);
			//g_fDist[client] = GetEntPropFloat(client, Prop_Send, "m_staggerDist");
			//g_fDist[client] -= dist;
			//if(g_fDist[client] < 10.0) g_fDist[client] = 10.0;

			//g_fTtime[client] = GetEntPropFloat(client, Prop_Send, "m_staggerTimer", 1);

			//DebugPrint("CancelStagger %N ", client);
			//L4D_CancelStagger(client);
			g_bStagger[client] = false;

			// Continue stagger after falling
			#if DEBUG
			DebugPrint("L4D_OnMotionControlledXY->OnFrameStagger %N ", client);
			#endif
			g_bFrameStagger[client] = true;
			g_bStaggerNew[client] = false;
			RequestFrame(OnFrameStagger, GetClientUserId(client));

			//SetAttack(client);
			if(m_hGroundEntity >= 0) return Plugin_Continue;
			return Plugin_Handled;
		}

		if( g_fTimeBlock[client] == 0.0 )
		{
			g_fTimeBlock[client] = GetGameTime() + 0.5;

			//SetAttack(client);
			if(m_hGroundEntity >= 0)  return Plugin_Continue;
			return Plugin_Handled;
		}

		if( g_fTimeBlock[client] - GetGameTime() > 0.0 )
		{
			//SetAttack(client);
			if(m_hGroundEntity >= 0)  return Plugin_Continue;
			return Plugin_Handled;
		}
	}

	if( g_bBlockXY[client] )
	{
		//SetAttack(client);
		if(m_hGroundEntity >= 0) return Plugin_Continue;
		return Plugin_Handled;
	}

	return Plugin_Continue;
}
/*
public Action L4D2_OnStagger(int client, int source)
{
	if( !g_bCvarAllow || !g_bRoundStarted ) return Plugin_Continue;

	//DebugPrint("%N L4D2_OnStagger", client);

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


	return Plugin_Continue;
}
*/

public void L4D_OnShovedBySurvivor_Post(int client, int victim, const float vecDir[3])
{
	L4D2_OnStagger_Post(victim, client);
}

public void L4D2_OnStagger_Post(int client, int source)
{
	g_fTimeBlock[client] = 0.0;
	g_bHurtByTank[client] = false;
	if( !g_bCvarAllow || !g_bRoundStarted) return;

	#if DEBUG
	DebugPrint("%N L4D2_OnStagger_Post by %d, g_bStaggerSelf: %d", client, source, g_bStaggerSelf[client]);
	#endif
	if(g_bStaggerSelf[client]) return;
	else
	{
		g_bStaggerNew[client] = true;
	}

	int team = GetClientTeam(client);
	if( team == 2 )
	{
		if(L4D_GetPinnedInfected(client) > 0) return;
		if(L4D_IsPlayerHangingFromLedge(client)) return;
		if(L4D_IsPlayerIncapacitated(client)) return;

		if( source > 0 && source <= MaxClients && IsClientInGame(source) && GetClientTeam(source) == L4D_TEAM_INFECTED && GetZombieClass(source) == ZC_HUNTER)
		{
			//人類被hunter震 1.0秒
			g_fTtime[client] = GetGameTime() + g_fCvar_z_max_stagger_duration+0.1;
			SetEntPropFloat(client, Prop_Send, "m_staggerTimer", g_fTtime[client], 1);
		}
		else
		{
			//人類被boomer炸 1.5秒 (遵守 survivor_max_tongue_stagger_duration)
			//人類被瓦斯桶/氧氣灌炸 1.5秒 (遵守 survivor_max_tongue_stagger_duration)
			//人類被Witch震 1.5秒 (遵守 survivor_max_tongue_stagger_duration)
			g_fTtime[client] = GetGameTime() + g_fCvar_survivor_max_tongue_stagger_duration;
			SetEntPropFloat(client, Prop_Send, "m_staggerTimer", g_fTtime[client], 1);
		}
	}
	else if(team == 3) 
	{
		int class = GetZombieClass(client);
		if(class == ZC_TANK)
		{
			g_fTtime[client] = GetGameTime() + L4D1_TANK_STAGGER_TIME;
			SetEntPropFloat(client, Prop_Send, "m_staggerTimer", L4D1_TANK_STAGGER_TIME, 0);
			SetEntPropFloat(client, Prop_Send, "m_staggerTimer", g_fTtime[client], 1);
		}
		else if(class == ZC_BOOMER)
		{
			g_fTtime[client] = GetEntPropFloat(client, Prop_Send, "m_staggerTimer", 1);
			if(g_fTtime[client] <= GetGameTime()) return; // 在空中被推/震，等落地

			g_fTtime[client] = GetGameTime() + L4D1_BOOMER_STAGGER_TIME;
			SetEntPropFloat(client, Prop_Send, "m_staggerTimer", L4D1_BOOMER_STAGGER_TIME, 0);
			SetEntPropFloat(client, Prop_Send, "m_staggerTimer", g_fTtime[client], 1);
		}
		else
		{
			//hunter/smoker 被推/震 0.9秒 (遵守z_max_stagger_duration)
			g_fTtime[client] = GetEntPropFloat(client, Prop_Send, "m_staggerTimer", 1);
			if(g_fTtime[client] <= GetGameTime()) return; // 在空中被推，等落地
		}
	}
	else
	{
		return;
	}

	//GetEntPropVector(client, Prop_Send, "m_staggerStart", g_vStart[client]);
	GetEntPropVector(source, Prop_Data, "m_vecAbsOrigin", g_vStart[client]);

	//float vPos[3];
	//GetClientAbsOrigin(client, vPos);
	//float dist = GetVectorDistance(g_vStart[client], vPos);
	//g_fDist[client] = GetEntPropFloat(client, Prop_Send, "m_staggerDist");
	//g_fDist[client] -= dist;
	//if(g_fDist[client] < 10.0) g_fDist[client] = 10.0;
}

//API from l4d_queued_stagger
//當在空中被推的特感(tank除外) 落地時真正觸發硬質動畫的時候 
public void L4D_OnQueuedStagger_Post(int client)
{
	if(!g_bCvarAllow) return;

	#if DEBUG
	DebugPrint("%N L4D_OnQueuedStagger_Post", client);
	#endif

	if(GetClientTeam(client) == 3)
	{
		int class = GetZombieClass(client);
		if(class == ZC_TANK)
		{
			return;
		}
		else if(class == ZC_BOOMER)
		{
			g_fTtime[client] = GetGameTime() + L4D1_BOOMER_STAGGER_TIME;
			SetEntPropFloat(client, Prop_Send, "m_staggerTimer", L4D1_BOOMER_STAGGER_TIME, 0);
			SetEntPropFloat(client, Prop_Send, "m_staggerTimer", g_fTtime[client], 1);
		}
		else
		{
			// hunter/smoker 被推 0.9秒 (遵守z_max_stagger_duration)
			g_fTtime[client] = GetGameTime() + g_fCvar_z_max_stagger_duration;
			SetEntPropFloat(client, Prop_Send, "m_staggerTimer", g_fTtime[client], 1);
		}

		GetEntPropVector(client, Prop_Send, "m_staggerStart", g_vStart[client]);

		//float vPos[3];
		//GetClientAbsOrigin(client, vPos);
		//float dist = GetVectorDistance(g_vStart[client], vPos);
		//g_fDist[client] = GetEntPropFloat(client, Prop_Send, "m_staggerDist");
		//g_fDist[client] -= dist;
		//if(g_fDist[client] < 10.0) g_fDist[client] = 10.0;
	}
}
/*
public Action L4D2_OnPounceOrLeapStumble(int client, int attacker)
{
	g_bHurtByTank[client] = false;
	g_bStaggerNew[client] = false;
	// Verify air stagger
	if( g_bCvarAllow && g_bRoundStarted )
	{
		#if DEBUG
		DebugPrint("%N L4D2_OnPounceOrLeapStumble", client);
		#endif

		int team = GetClientTeam(client);

		if(GetClientTeam(client) == 2)
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
			L4D_StaggerPlayer(client, attacker, NULL_VECTOR);
		}
		else
		{
			GetEntPropVector(attacker, Prop_Data, "m_vecAbsOrigin", g_vStart[client]);

			g_fTtime[client] = GetGameTime() + g_fCvar_z_max_stagger_duration+0.1;

			#if DEBUG
			DebugPrint("L4D2_OnPounceOrLeapStumble->OnFrameStagger %N ", client);
			#endif
			//強制震
			OnFrameStagger(GetClientUserId(client));
			return Plugin_Handled;
		}
	}

	return Plugin_Continue;
}
*/

//人類身旁的隊友被hunter撲導致被震 0.9秒 (遵守z_max_stagger_duration)
public void L4D2_OnPounceOrLeapStumble_Post(int client, int attacker)
{
	g_bHurtByTank[client] = false;
	g_bStaggerNew[client] = false;
	// Verify air stagger
	if( g_bCvarAllow && g_bRoundStarted )
	{
		#if DEBUG
		DebugPrint("%N L4D2_OnPounceOrLeapStumble_Post", client);
		#endif

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
		else
		{
			GetEntPropVector(client, Prop_Send, "m_staggerStart", g_vStart[client]);
			//GetEntPropVector(attacker, Prop_Data, "m_vecAbsOrigin", g_vStart[client]);

			//float vPos[3];
			//GetClientAbsOrigin(client, vPos);
			//float dist = GetVectorDistance(g_vStart[client], vPos);
			//g_fDist[client] = GetEntPropFloat(client, Prop_Send, "m_staggerDist");
			//g_fDist[client] -= dist;
			//if(g_fDist[client] < 10.0) g_fDist[client] = 10.0;

			g_fTtime[client] = GetGameTime() + g_fCvar_z_max_stagger_duration+0.1;
			SetEntPropFloat(client, Prop_Send, "m_staggerTimer", g_fTtime[client], 1);

			//查看是否有被震，沒有則強制震

			DataPack hPack;
			CreateDataTimer(0.02, Timer_OnFrameStagger, hPack, TIMER_FLAG_NO_MAPCHANGE);
			hPack.WriteCell(GetClientUserId(attacker));
			hPack.WriteCell(GetClientUserId(client));
		}
	}
}

// Hunter/Smoker/被修改stagger time的boomer 硬質時間到時會觸發此涵式 (Boomer/Tank不會)
// Hunter/Smoker/Boomer 硬質期間被推第二次也會觸發此涵式 (Tank不會)
// 人類硬質期間被重新震第二次也會觸發此涵式
public Action L4D_OnCancelStagger(int client)
{
	if( !g_bCvarAllow || !g_bRoundStarted ) return Plugin_Continue;

	#if DEBUG
	DebugPrint("%N L4D_OnCancelStagger - %d", client, g_bFrameStagger[client]);
	#endif

	int team = GetClientTeam(client);

	// Maybe fallen off a ledge that wants to cancel the stagger, block the cancel
	if(team == 3)
	{
		if(IsFakeClient(client))
		{
			g_bStagger[client] = false;
			return Plugin_Continue; //bot無限觸發
		}

		if( g_bFrameStagger[client] )
		{
			g_bFrameStagger[client] = false;
			return Plugin_Handled;
		}
	}
	else if( team == 2 )
	{
		if(IsFakeClient(client))
		{
			g_bStagger[client] = false;
			return Plugin_Continue; //bot無限觸發
		}
		
		if( g_bFrameStagger[client] )
		{
			g_bFrameStagger[client] = false;
			return Plugin_Handled;
		}
	}

	if( GetGameTime() < g_fTtime[client])
	{
		// We should still be staggering but maybe fell off a ledge, let it cancel and start stagger again nexxt frame
		g_bStagger[client] = false;

		// Continue stagger after falling
		#if DEBUG
		DebugPrint("L4D_OnCancelStagger->OnFrameStagger %N ", client);
		#endif
		g_bFrameStagger[client] = true;
		g_bStaggerNew[client] = false;
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
	if( g_bCvarAllow && g_bRoundStarted && GetClientTeam(client) >= 2 && IsPlayerAlive(client) )
	{
		if( (g_fTimeBlock[client] > 0.0 || g_bStaggerSelf[client]) && GetGameTime() > g_fTimeBlock[client])
		{
			g_bStaggerSelf[client] = false;
			g_bFrameStagger[client] = false;
			g_bHurtByTank[client] = false;
			g_fTimeBlock[client] = 0.0;
		}

		if(g_bBlockXY[client] && L4D_IsPlayerStaggering(client) == false)
		{
			g_bBlockXY[client] = false;
			g_fTimeBlock[client] = 0.0;
		}

		if( g_bStagger[client] || g_bFrameStagger[client])
		{
			buttons = 0;
			if(IsOnLadder(client))
			{
				g_bStagger[client] = false;
				g_bFrameStagger[client] = false;
				return Plugin_Changed;
			}

			if( g_bFrameStagger[client] == false && GetGameTime() < g_fTtime[client])
			{
				if(GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") != -1)
				{
					#if DEBUG
					DebugPrint("OnPlayerRunCmd->OnFrameStagger %N ", client);
					#endif

					g_bFrameStagger[client] = true;
					g_bStaggerNew[client] = false;
					RequestFrame(OnFrameStagger, GetClientUserId(client));
				}
				
				return Plugin_Changed;
			}

			g_bFrameStagger[client] = false;
			g_bStagger[client] = false;

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
}
*/

Action Timer_OnFrameStagger(Handle timer, DataPack hPack)
{
	hPack.Reset();
	int attacker = GetClientOfUserId(hPack.ReadCell());
	int userid = hPack.ReadCell();
	int client = GetClientOfUserId(userid);
	if( attacker && IsClientInGame(attacker) && IsPlayerAlive(attacker)
		&& client && IsClientInGame(client) && IsPlayerAlive(client))
	{
		if(IsPlayerStaggeringAnimation(client) == false)
		{
			GetEntPropVector(attacker, Prop_Data, "m_vecAbsOrigin", g_vStart[client]);
			OnFrameStagger(userid);
		}
	}

	return Plugin_Continue;
}

void OnFrameStagger(int client)
{
	client = GetClientOfUserId(client);
	if( client && IsClientInGame(client) && IsPlayerAlive(client))
	{
		int team = GetClientTeam(client);
		if( team == 2 )
		{
			if(L4D_GetPinnedInfected(client) > 0 
			|| L4D_IsPlayerHangingFromLedge(client)
			|| L4D_IsPlayerIncapacitated(client) 
			|| (g_bHurtByTank[client]) )
			{
				g_bFrameStagger[client] = false;
				return;
			}
		}
		else if( team == 3 )
		{
			if(L4D_GetPinnedSurvivor(client) > 0)
			{
				g_bFrameStagger[client] = false;
				return;
			}
		}

		if(g_bStaggerNew[client] == false && g_fTtime[client] > GetGameTime())
		{
			#if DEBUG
			DebugPrint("L4D_StaggerPlayer again %N", client);
			DebugPrint("g_fTtime: %.1f, now: %.1f, g_vStart: %.1f %.1f %.1f, Dist: %.1f", g_fTtime[client], GetGameTime(), g_vStart[client][0], g_vStart[client][1], g_vStart[client][2], g_fDist[client]);
			#endif

			g_bStaggerSelf[client] = true;
			L4D_StaggerPlayer(client, client, g_vStart[client]);
			//SetEntPropFloat(client, Prop_Send, "m_staggerDist", g_fDist[client]);
			SetEntPropFloat(client, Prop_Send, "m_staggerDist", 400.0);
			SetEntPropFloat(client, Prop_Send, "m_staggerTimer", g_fTtime[client], 1);
		}
		else
		{
			g_bFrameStagger[client] = false;
		}
	}
}

bool IsOnLadder(int client)
{
	return GetEntityMoveType(client) == MOVETYPE_LADDER;
}

int GetZombieClass(int client)
{
	return GetEntProp(client, Prop_Send, "m_zombieClass");
}

/* Debug */
stock void DebugPrint(const char[] Message, any ...)
{
	char DebugBuff[128];
	VFormat(DebugBuff, sizeof(DebugBuff), Message, 2);
	PrintToChatAll("%s",DebugBuff);
}

stock bool IsPlayerStaggeringAnimation(int client)
{
	static int Activity;
	Activity = L4D1_GetMainActivity(client);
	#if DEBUG
	DebugPrint("%N %d", client, Activity);
	#endif
	switch (Activity) 
	{
		case L4D1_ACT_TERROR_SHOVED_FORWARD, // 1145, 1146, 1147, 1148: stumble
			L4D1_ACT_TERROR_SHOVED_BACKWARD,
			L4D1_ACT_TERROR_SHOVED_LEFTWARD,
			L4D1_ACT_TERROR_SHOVED_RIGHTWARD: 
				return true;
	}

	return false;
}