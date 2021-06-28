#define PLUGIN_VERSION 		"1.3"
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <dhooks>

#define CVAR_FLAGS			FCVAR_NOTIFY
#define GAMEDATA			"l4d_god_frames"

Handle g_hDetour;
bool g_bInvulnerable[MAXPLAYERS+1];
ConVar g_hCvarAllow, g_hCvarMPGameMode, g_hCvarModes, g_hCvarModesOff, g_hCvarModesTog;
bool g_bLateLoad,g_bCvarAllow;
int m_invulnerabilityTimer;
float g_fInvulDurr[MAXPLAYERS+1];
float g_fInvulTime[MAXPLAYERS+1];

/********godframes_control*******/
ConVar hHittable;
ConVar hWitch;
ConVar hFF;
ConVar hCommon;
ConVar hHunter;
ConVar hSmoker;
ConVar hCommonFlags;
ConVar hGodframeGlows;
ConVar hrevive;
ConVar hFFFlags ;

//fake godframes
float fFakeGodframeEnd[MAXPLAYERS + 1];
int iLastSI[MAXPLAYERS + 1];
float lastSavedGodFrameBegin[MAXPLAYERS+1] = 0.0;

public Plugin myinfo =
{
	name = "[L4D] God Frames Patch & Control",
	author = "Stabby, CircleSquared, Tabun, SilverShot, HarryPotter",
	description = "Removes the IsInvulnerable function. Allows for control of what gets godframed and what doesnt.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=320023"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if( test != Engine_Left4Dead)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1");
		return APLRes_SilentFailure;
	}

	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	// ====================================================================================================
	// GAMEDATA
	// ====================================================================================================
	Handle hGameData = LoadGameConfigFile(GAMEDATA);
	if( hGameData == null ) SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	m_invulnerabilityTimer = GameConfGetOffset(hGameData, "m_invulnerabilityTimer");
	if( m_invulnerabilityTimer == -1 )
		SetFailState("Failed to find \"m_invulnerabilityTimer\" signature.");

	g_hDetour = DHookCreateFromConf(hGameData, "CTerrorPlayer::IsInvulnerable");
	delete hGameData;

	if( !g_hDetour )
		SetFailState("Failed to find \"CTerrorPlayer::IsInvulnerable\" signature.");



	// ====================================================================================================
	// CVARS
	// ====================================================================================================
	g_hCvarAllow = CreateConVar(	"l4d_god_frames_allow",			"1",			"0=Plugin off, 1=Plugin on.", CVAR_FLAGS );
	g_hCvarModes = CreateConVar(	"l4d_god_frames_modes",			"",				"Turn on the plugin in these game modes, separate by commas (no spaces). (Empty = all).", CVAR_FLAGS );
	g_hCvarModesOff = CreateConVar(	"l4d_god_frames_modes_off",		"",				"Turn off the plugin in these game modes, separate by commas (no spaces). (Empty = none).", CVAR_FLAGS );
	g_hCvarModesTog = CreateConVar(	"l4d_god_frames_modes_tog",		"0",			"Turn on the plugin in these game modes. 0=All, 1=Coop, 2=Survival, 4=Versus, 8=Scavenge. Add numbers together.", CVAR_FLAGS );
	CreateConVar(					"l4d_god_frames_version",		PLUGIN_VERSION,	"God Frames Patch plugin version.", CVAR_FLAGS|FCVAR_DONTRECORD);

	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	g_hCvarMPGameMode.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesTog.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModes.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesOff.AddChangeHook(ConVarChanged_Allow);
	g_hCvarAllow.AddChangeHook(ConVarChanged_Allow);

	/********godframes_control*******/
	hGodframeGlows = CreateConVar("gfc_godframe_glows", "1",
									"Changes the rendering of survivors while godframed (red/transparent).",
									CVAR_FLAGS, true, 0.0, true, 1.0 );						
	hHittable = CreateConVar(	"gfc_hittable_override", "1",
									"Allow hittables to always ignore godframes.",
									CVAR_FLAGS, true, 0.0, true, 1.0 );
	hWitch = CreateConVar( 		"gfc_witch_override", "1",
									"Allow witches to always ignore godframes.",
									CVAR_FLAGS, true, 0.0, true, 1.0 );						
	hHunter = CreateConVar( 	"gfc_hunter_duration", "1.8",
									"How long should godframes after a pounce last?",
									CVAR_FLAGS, true, 0.0, true, 3.0 );
	hSmoker = CreateConVar( 	"gfc_smoker_duration", "0.0",
									"How long should godframes after a pull or choke last?",
									CVAR_FLAGS, true, 0.0, true, 3.0 );		
	hrevive = CreateConVar( 	"gfc_revive_duration", "0.0",
									"How long should godframes after received from incap(not from ledge)?",
									CVAR_FLAGS, true, 0.0, true, 3.0 );
	//zone:charger+hunter only
	hCommonFlags= CreateConVar( "gfc_common_zc_flags", "2",
									"Which classes will be affected by extra common protection time. 1 - Hunter. 2 - Smoker. 4 - Receive.",
									CVAR_FLAGS, true, 0.0, true, 7.0 );
	hCommon = CreateConVar( 	"gfc_common_extra_time", "1.8",
									"Additional godframe time before common damage is allowed.",
									CVAR_FLAGS, true, 0.0, true, 3.0 );
	hFFFlags= CreateConVar( "gfc_FF_zc_flags", "2",
									"Which classes will be affected by extra FF protection time. 1 - Hunter. 2 - Smoker. 4 - Receive.",
									CVAR_FLAGS, true, 0.0, true, 7.0 );
	hFF = CreateConVar( 		"gfc_ff_min_time", "0.8",
									"Additional godframe time before FF damage is allowed.",
									CVAR_FLAGS, true, 0.0, true, 5.0 );
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

void IsAllowed()
{
	bool bCvarAllow = g_hCvarAllow.BoolValue;
	bool bAllowMode = IsAllowedGameMode();

	if( g_bCvarAllow == false && bCvarAllow == true && bAllowMode == true )
	{
		DetourAddress(true);
		g_bCvarAllow = true;

		if( g_bLateLoad ) // Only on lateload, or if re-enabled.
		{
			for( int i = 1; i <= MaxClients; i++ )
			{
				if( IsClientInGame(i) )
				{
					OnClientPutInServer(i);
				}
			}
		}
		
		HookEvent("player_death", event_player_death, EventHookMode_Pre);
		HookEvent("round_start", event_RoundStart, EventHookMode_PostNoCopy);
		HookEvent("tongue_release", PostSurvivorRelease);
		HookEvent("pounce_end", PostSurvivorRelease);
		HookEvent("revive_success", Event_revive_success);
	}

	else if( g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false) )
	{
		DetourAddress(false);
		g_bCvarAllow = false;
		g_bLateLoad = true; // So SDKHooks can re-hook damage if re-enabled.

		for( int i = 1; i <= MaxClients; i++ )
		{
			if( IsClientInGame(i) )
			{
				SDKUnhook(i, SDKHook_OnTakeDamage, OnTakeDamagePre);
				SDKUnhook(i, SDKHook_OnTakeDamageAlive, OnTakeDamage);
			}
		}
		
		UnhookEvent("player_death", event_player_death, EventHookMode_Pre);
		UnhookEvent("round_start", event_RoundStart, EventHookMode_PostNoCopy);
		UnhookEvent("tongue_release", PostSurvivorRelease);
		UnhookEvent("pounce_end", PostSurvivorRelease);
		UnhookEvent("revive_success", Event_revive_success);
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

public void event_player_death(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));//死掉那位
	ResetGlow(client);
}

public void event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++) //clear both fake and real just because
	{
		fFakeGodframeEnd[i] = 0.0;
		lastSavedGodFrameBegin[i] = 0.0;
	}
}

public void PostSurvivorRelease(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(event,"victim"));

	if (victim<=0||!IsClientAndInGame(victim)) { return; } //just in case

	//sets fake godframe time based on cvars for each ZC
	if (StrContains(name, "tongue") != -1)
	{
		lastSavedGodFrameBegin[victim] = GetEngineTime();
		fFakeGodframeEnd[victim] = GetGameTime() + GetConVarFloat(hSmoker);
		iLastSI[victim] = 2;
	} 
	else if (StrContains(name, "pounce") != -1)
	{
		lastSavedGodFrameBegin[victim] = GetEngineTime();
		fFakeGodframeEnd[victim] = GetGameTime() + GetConVarFloat(hHunter);
		iLastSI[victim] = 1;
	}
	
	if (fFakeGodframeEnd[victim] > GetGameTime() && GetConVarBool(hGodframeGlows)) {
		SetGodframedGlow(victim);
		CreateTimer(fFakeGodframeEnd[victim] - GetGameTime(), Timed_ResetGlow, victim);
	}
	
	return;
}

public void Event_revive_success(Event event, const char[] name, bool dontBroadcast)
{
	int subject = GetClientOfUserId(GetEventInt(event, "subject"));//被救的那位
	if (subject<=0||!IsClientAndInGame(subject)) { return; } //just in case
	if (GetEventBool(event,"ledge_hang"))
	{
		return;
	}
	
	lastSavedGodFrameBegin[subject] = GetEngineTime();
	fFakeGodframeEnd[subject] = GetGameTime() + GetConVarFloat(hrevive);
	iLastSI[subject] = 4;
	if (fFakeGodframeEnd[subject] > GetGameTime() && GetConVarBool(hGodframeGlows)) {
		SetGodframedGlow(subject);
		CreateTimer(fFakeGodframeEnd[subject] - GetGameTime(), Timed_ResetGlow, subject);
	}
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamagePre);
	SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamage);
}

public Action OnTakeDamagePre(int client, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	float timestamp = view_as<float>(LoadFromAddress(GetEntityAddress(client) + view_as<Address>(m_invulnerabilityTimer + 8), NumberType_Int32));
	if( timestamp >= GetGameTime() )
	{
		// Instead of storing the timestamp inside this plugin on first detection which would make it inaccurate if the game ever changed it.
		// We'll remove timer to make vulnerable and...
		g_fInvulDurr[client] = view_as<float>(LoadFromAddress(GetEntityAddress(client) + view_as<Address>(m_invulnerabilityTimer + 4), NumberType_Int32));
		g_fInvulTime[client] = timestamp;
		g_bInvulnerable[client] = true;
		StoreToAddress(GetEntityAddress(client) + view_as<Address>(m_invulnerabilityTimer + 4), view_as<int>(0.0), NumberType_Int32);	// m_duration
		StoreToAddress(GetEntityAddress(client) + view_as<Address>(m_invulnerabilityTimer + 8), view_as<int>(0.0), NumberType_Int32);	// m_timestamp
	}
	else
		g_bInvulnerable[client] = false;
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if( g_bInvulnerable[victim] )
	{
		// ... restore timer to continue tracking invul. Pre/Post.
		StoreToAddress(GetEntityAddress(victim) + view_as<Address>(m_invulnerabilityTimer + 4), view_as<int>(g_fInvulDurr[victim]), NumberType_Int32);	// m_duration
		StoreToAddress(GetEntityAddress(victim) + view_as<Address>(m_invulnerabilityTimer + 8), view_as<int>(g_fInvulTime[victim]), NumberType_Int32);	// m_timestamp
	}

	if (!IsValidEdict(victim) || 
	!IsValidEdict(attacker) || 
	!IsValidEdict(inflictor) ||
	!IsClientAndInGame(victim) ||
	GetClientTeam(victim) != 2)  { return Plugin_Continue; }
	
	char sClassname[64];
	GetEntityClassname(inflictor, sClassname, sizeof(sClassname));
	
	float fTimeLeft = fFakeGodframeEnd[victim] - GetGameTime();
	if (StrEqual(sClassname, "infected") && (iLastSI[victim] & GetConVarInt(hCommonFlags))) //commons
	{
		fTimeLeft += GetConVarFloat(hCommon);
	}
	if (IsClientAndInGame(attacker) && GetClientTeam(victim) == GetClientTeam(attacker) && (iLastSI[victim] & GetConVarInt(hFFFlags))) //friendly fire
	{
		fTimeLeft += GetConVarFloat(hFF);
	}
	
	if (fTimeLeft > 0) //means fake god frames are still in effect
	{
		if(StrEqual(sClassname, "worldspawn") && attacker==0) //survivor falls off ledge
			return Plugin_Continue;
			
		if ( StrEqual(sClassname,"prop_physics") || StrEqual(sClassname,"prop_car_alarm") || StrEqual(sClassname, "prop_physics_multiplayer")) //hittables
		{
			if (GetConVarBool(hHittable)) { return Plugin_Continue; }
		}
		else
		{
			if (StrEqual(sClassname, "witch")) //witches
			{
				if (GetConVarBool(hWitch)) { return Plugin_Continue; }
			}
		}
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

// ====================================================================================================
//					DETOUR
// ====================================================================================================
void DetourAddress(bool patch)
{
	static bool patched;

	if( !patched && patch )
	{
		if( !DHookEnableDetour(g_hDetour, false, IsInvulnerablePre) )
			SetFailState("Failed to detour pre \"CTerrorPlayer::IsInvulnerable\".");

		if( !DHookEnableDetour(g_hDetour, true, IsInvulnerablePost) )
			SetFailState("Failed to detour post \"CTerrorPlayer::IsInvulnerable\".");
	}
	else if( patched && !patch )
	{
		if( !DHookDisableDetour(g_hDetour, false, IsInvulnerablePre) )
			SetFailState("Failed to disable detour pre \"CTerrorPlayer::IsInvulnerable\".");

		if( !DHookDisableDetour(g_hDetour, true, IsInvulnerablePost) )
			SetFailState("Failed to disable detour post \"CTerrorPlayer::IsInvulnerable\".");
	}
}

public MRESReturn IsInvulnerablePre()
{
	// Unused but hook required to prevent crashing.
}

public MRESReturn IsInvulnerablePost(int pThis, Handle hReturn)
{
	bool invul = DHookGetReturn(hReturn);
	g_bInvulnerable[pThis] = invul;

	if( invul )
	{
		DHookSetReturn(hReturn, 0);
		return MRES_Supercede;
	}

	return MRES_Ignored;
}

// ====================================================================================================
//					function support
// ====================================================================================================
stock bool IsClientAndInGame(int client)
{
	if (0 < client && client < MaxClients)
	{	
		return IsClientInGame(client);
	}
	return false;
}

public Action Timed_ResetGlow(Handle timer, int client) {
	ResetGlow(client);
}


void ResetGlow(int client) {
	if (IsClientAndInGame(client)) {
		// remove transparency/color
		SetEntityRenderMode(client, RENDER_NORMAL);
		SetEntityRenderColor(client, 255,255,255,255);
	}
}

void SetGodframedGlow(int client) {	//there might be issues with realism
	if (IsClientAndInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == 2) {
		// make player transparent/red while godframed
		SetEntityRenderMode( client, RENDER_GLOW );
		SetEntityRenderColor (client, 255,0,0,200 );
	}
}