#pragma semicolon 1

/*
 * To-do:
 * Add flag cvar to control damage from different SI separately.
 * Add cvar to control whether tanks should reset frustration with hittable hits. Maybe.
 */
/********godframes_control*******/
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>

#define CLASSNAME_LENGTH 64
#define GAMEDATA	"l4d_godframes"
#define CTIMER_TIMESTAMP_OFFSET view_as<Address>(8)

//cvars
ConVar god = null;
ConVar hHittable = null;
ConVar hWitch = null;
ConVar hFF = null;
ConVar hCommon = null;
ConVar hHunter = null;
ConVar hSmoker = null;
ConVar hCommonFlags = null;
ConVar hGodframeGlows = null;
ConVar hrevive = null;
ConVar hFFFlags = null;

//fake godframes
new Float:fFakeGodframeEnd[MAXPLAYERS + 1];
new iLastSI[MAXPLAYERS + 1];

//god frame be gone
static Float:lastSavedGodFrameBegin[MAXPLAYERS+1]			=  {0.0};
//static const		TEMP_HEALTH_ERROR_MARGIN				=    1;

/********l4d2_hittable_control*******/
bool	g_bGauntletFinaleMap;			//for parish bridge cars
float	fOverkill[MAXPLAYERS + 1][2048];	//for hittable hits
float 	fSpecialOverkill[MAXPLAYERS + 1][3]; // Dealing with breakable pieces that will cause multiple hits in a row (unintended behaviour)
bool g_bLateLoad;   // Late load support!

//cvars
ConVar hGauntletFinaleMulti;
ConVar hLogStandingDamage;
ConVar hBHLogStandingDamage;
ConVar hCarStandingDamage;
ConVar hBumperCarStandingDamage;
ConVar hHandtruckStandingDamage;
ConVar hForkliftStandingDamage;
ConVar hBrokenForkliftStandingDamage;
ConVar hDumpsterStandingDamage;
ConVar hHaybaleStandingDamage;
ConVar hBaggageStandingDamage;
ConVar hGeneratorTrailerStandingDamage;
ConVar hMilitiaRockStandingDamage;
ConVar hSofaChairStandingDamage;
ConVar hAtlasBallDamage;
ConVar hIBeamDamage;
ConVar hDiescraperBallDamage;
ConVar hVanDamage;
ConVar hStandardIncapDamage;
ConVar hTankSelfDamage;
ConVar hOverHitInterval;
ConVar hOverHitDebug;
//ConVar hUnbreakableForklifts;

// ff protect
// Macros for easily referencing the Undo Damage array
#define UNDO_PERM 0
#define UNDO_TEMP 1
#define UNDO_SIZE 16

// Flags for different types of Friendly Fire
#define FFTYPE_NOTUNDONE 0
#define FFTYPE_TOOCLOSE 1
#define FFTYPE_STUPIDBOTS 2
#define FFTYPE_MELEEFLAG 0x8000

ConVar
	g_hCvarEnable = null,
	g_hCvarBlockZeroDmg = null,
	g_hCvarPermDamageFraction = null;

int
	g_iEnabledFlags = 0,
	g_iBlockZeroDmg = 0,
	g_iLastHealth[MAXPLAYERS + 1][UNDO_SIZE][2],				// The Undo Damage array, with correlated arrays for holding the last revive count and current undo index
	g_iLastReviveCount[MAXPLAYERS + 1] = {0, ... },
	g_iCurrentUndo[MAXPLAYERS + 1] = {0, ... },
	g_iTargetTempHealth[MAXPLAYERS + 1] = {0, ... },			// Healing is weird, so this keeps track of our target OR the target's temp health
	g_iLastPerm[MAXPLAYERS + 1] = {100, ... },				// The permanent damage fraction requires some coordination between OnTakeDamage and player_hurt
	g_iLastTemp[MAXPLAYERS + 1] = {0, ... };

float
	g_fPermFrac = 0.0;

bool g_bStupidGuiltyBots[MAXPLAYERS + 1] = {false, ...};

public Plugin:myinfo =
{
	name = "L4D2 Godframes Control combined with FF Plugins + L4D2 Hittable Control",
	author = "Stabby, CircleSquared, Tabun, Visor, dcx, Sir, Spoon, A1m`, Derpduck, Harry",
	version = "1.6",
	description = "控制人類無敵狀態的時間並顯示顏色. Allows for customisation of hittable damage values."
};

public APLRes:AskPluginLoad2(Handle:plugin, bool:late, String:error[], errMax) 
{
	g_bLateLoad = late;
	return APLRes_Success;    
}

static KeyValues g_hMIData = null;

public OnPluginStart()
{
	god = FindConVar("god");

	/********l4d2_hittable_control*******/
	//zone cfg set
	hGauntletFinaleMulti	= CreateConVar( "hc_gauntlet_finale_multiplier",		"1.0",
											"Multiplier of damage that hittables deal on gauntlet finales.",
											FCVAR_NONE, true, 0.0, true, 4.0 );
	hLogStandingDamage		= CreateConVar( "hc_sflog_standing_damage",		"100.0",
											"Damage of hittable swamp fever logs to non-incapped survivors.",
											FCVAR_NONE, true, 0.0, true, 300.0 );
	hBHLogStandingDamage	= CreateConVar( "hc_bhlog_standing_damage",		"100.0",
											"Damage of hittable blood harvest logs to non-incapped survivors.",
											FCVAR_NONE, true, 0.0, true, 300.0 );
	hCarStandingDamage		= CreateConVar( "hc_car_standing_damage",		"100.0",
											"Damage of hittable cars to non-incapped survivors.",
											FCVAR_NONE, true, 0.0, true, 300.0 );
	hBumperCarStandingDamage= CreateConVar( "hc_bumpercar_standing_damage",	"100.0",
											"Damage of hittable bumper cars to non-incapped survivors.",
											FCVAR_NONE, true, 0.0, true, 300.0 );
	hHandtruckStandingDamage= CreateConVar( "hc_handtruck_standing_damage",	"8.0",
											"Damage of hittable handtrucks (aka dollies) to non-incapped survivors.",
											FCVAR_NONE, true, 0.0, true, 300.0 );
	hForkliftStandingDamage	= CreateConVar( "hc_forklift_standing_damage",	"100.0",
											"Damage of hittable forklifts to non-incapped survivors.",
											FCVAR_NONE, true, 0.0, true, 300.0 );
	hBrokenForkliftStandingDamage= CreateConVar( "hc_broken_forklift_standing_damage",	"100.0",
											"Damage of hittable broken forklifts to non-incapped survivors.",
											FCVAR_NONE, true, 0.0, true, 300.0 );
	hDumpsterStandingDamage	= CreateConVar( "hc_dumpster_standing_damage",	"100.0",
											"Damage of hittable dumpsters to non-incapped survivors.",
											FCVAR_NONE, true, 0.0, true, 300.0 );
	hHaybaleStandingDamage	= CreateConVar( "hc_haybale_standing_damage",	"100.0",
											"Damage of hittable haybales to non-incapped survivors.",
											FCVAR_NONE, true, 0.0, true, 300.0 );
	hBaggageStandingDamage	= CreateConVar( "hc_baggage_standing_damage",	"100.0",
											"Damage of hittable baggage carts to non-incapped survivors.",
											FCVAR_NONE, true, 0.0, true, 300.0 );
	hGeneratorTrailerStandingDamage	= CreateConVar( "hc_generator_trailer_standing_damage",	"100.0",
											"Damage of hittable generator trailers to non-incapped survivors.",
											FCVAR_NONE, true, 0.0, true, 300.0 );
	hMilitiaRockStandingDamage= CreateConVar( "hc_militia_rock_standing_damage",	"100.0",
											"Damage of hittable militia rocks to non-incapped survivors.",
											FCVAR_NONE, true, 0.0, true, 300.0 );
	hSofaChairStandingDamage= CreateConVar( "hc_sofa_chair_standing_damage",	"100.0",
											"Damage of hittable sofa chair on Blood Harvest finale to non-incapped survivors. Applies only to sofa chair with a targetname of 'hittable_chair_l4d1' to emulate L4D1 behaviour, the hittable chair from TLS update is parented to a bumper car.",
											FCVAR_NONE, true, 0.0, true, 300.0 );
	hAtlasBallDamage		= CreateConVar( "hc_atlas_ball_standing_damage",	"100.0",
											"Damage of hittable atlas balls to non-incapped survivors.",
											FCVAR_NONE, true, 0.0, true, 300.0 );
	hIBeamDamage			= CreateConVar( "hc_ibeam_standing_damage",	"48.0",
											"Damage of ibeams to non-incapped survivors.",
											FCVAR_NONE, true, 0.0, true, 300.0 );
	hDiescraperBallDamage	= CreateConVar( "hc_diescraper_ball_standing_damage",	"100.0",
											"Damage of hittable ball statue on Diescraper finale to non-incapped survivors.",
											FCVAR_NONE, true, 0.0, true, 300.0 );
	hVanDamage				= CreateConVar( "hc_van_standing_damage",	"100.0",
											"Damage of hittable van on Detour Ahead map 2 to non-incapped survivors.",
											FCVAR_NONE, true, 0.0, true, 300.0 );
	hStandardIncapDamage	= CreateConVar( "hc_incap_standard_damage",		"-2",
											"Damage of all hittables to incapped players. -1 will have incap damage default to valve's standard incoherent damages. -2 will have incap damage default to each hittable's corresponding standing damage.",
											FCVAR_NONE, true, -2.0, true, 300.0 );
	hTankSelfDamage			= CreateConVar( "hc_disable_self_damage",		"1",
											"If set, tank will not damage itself with hittables. (0.6.1 simply prevents all damage from Prop_Physics & Alarm Cars to cover for the event a Tank punches a hittable into another and gets hit)",
											FCVAR_NONE, true, 0.0, true, 1.0 );
	hOverHitInterval		= CreateConVar( "hc_overhit_time",				"1.4",
											"The amount of time to wait before allowing consecutive hits from the same hittable to register. Recommended values: 0.0-0.5: instant kill; 0.5-0.7: sizeable overhit; 0.7-1.0: standard overhit; 1.0-1.2: reduced overhit; 1.2+: no overhit unless the car rolls back on top. Set to tank's punch interval (default 1.5) to fully remove all possibility of overhit.",
											FCVAR_NONE, true, 0.0, false );
	hOverHitDebug		    = CreateConVar( "hc_debug",				"0",
											"0: Disable Debug - 1: Enable Debug",
											FCVAR_NONE, true, 0.0, false );
	//hUnbreakableForklifts	= CreateConVar( "hc_unbreakable_forklifts",	"1",
	//										"Prevents forklifts breaking into pieces when hit by a tank.",
	//										FCVAR_NONE, true, 0.0, false );

	/********godframes_control*******/

	hGodframeGlows = CreateConVar("gfc_godframe_glows", "1",
									"Changes the rendering of survivors while godframed (red/transparent).",
									FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	
	hHittable = CreateConVar(	"gfc_hittable_override", "1",
									"Allow hittables to always ignore godframes.",
									FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	hWitch = CreateConVar( 		"gfc_witch_override", "1",
									"Allow witches to always ignore godframes.",
									FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	

	hFF = CreateConVar( 		"gfc_ff_extra_time", "0.8",
									"Additional godframe time before FF damage is allowed.",
									FCVAR_NOTIFY, true, 0.0, true, 5.0 );
								
	hCommon = CreateConVar( 	"gfc_common_extra_time", "0.6",
									"Additional godframe time before common damage is allowed.",
									FCVAR_NOTIFY, true, 0.0, true, 3.0 );
	//官方預設2秒
	hHunter = CreateConVar( 	"gfc_hunter_duration", "1.8",
									"How long should godframes after a pounce last?",
									FCVAR_NOTIFY, true, 0.0, true, 3.0 );
	//官方預設2秒
	hSmoker = CreateConVar( 	"gfc_smoker_duration", "0.0",
									"How long should godframes after a pull or choke last?",
									FCVAR_NOTIFY, true, 0.0, true, 3.0 );
	//官方預設2秒			
	hrevive = CreateConVar( 	"gfc_revive_duration", "0.0",
									"How long should godframes after received from incap? (also from ledge)",
									FCVAR_NOTIFY, true, 0.0, true, 3.0 );
	//zone:charger+hunter only
	hCommonFlags= CreateConVar( "gfc_common_zc_flags", 	"2",
									"Which classes will be affected by extra common protection time. 1 - Hunter. 2 - Smoker. 4 - Receive.",
									FCVAR_NOTIFY, true, 0.0, true, 7.0 );
	hFFFlags= 	CreateConVar( 	"gfc_FF_zc_flags", 		"2",
									"Which classes will be affected by extra FF protection time. 1 - Hunter. 2 - Smoker. 4 - Receive.",
									FCVAR_NOTIFY, true, 0.0, true, 7.0 );	

	HookEvent("tongue_release", PostSurvivorRelease);
	HookEvent("pounce_end", PostSurvivorRelease);
	HookEvent("player_death", event_player_death, EventHookMode_Pre);
	HookEvent("revive_success", Event_revive_success);//救起倒地的or 懸掛的
	HookEvent("round_start", event_RoundStart, EventHookMode_PostNoCopy);//每回合開始就發生的event

	// ff protect
	g_hCvarEnable = 			CreateConVar("l4d2_undoff_enable", 		"3", 
									"Bit flag: Enables plugin features (add together): 1=too close, 2=guilty bots, 3=all, 0=off", 
									FCVAR_NOTIFY, true, 0.0, true, 3.0 );	
	g_hCvarBlockZeroDmg = 		CreateConVar("l4d2_undoff_blockzerodmg","7", 
									"Bit flag: Block 0 damage friendly fire effects like recoil and vocalizations/stats (add together): 4=bot hits human block recoil, 2=block vocals/stats on ALL difficulties, 1=block vocals/stats on everything EXCEPT Easy (flag 2 has precedence), 0=off", 
									FCVAR_NOTIFY, true, 0.0, true, 7.0 );					
	g_hCvarPermDamageFraction = CreateConVar("l4d2_undoff_permdmgfrac", "1.0", 
									"Minimum fraction of damage applied to permanent health", 
									FCVAR_NOTIFY, true, 0.0, true, 1.0);

	GetCvars();
	g_hCvarEnable.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarBlockZeroDmg.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarPermDamageFraction.AddChangeHook(ConVarChanged_Cvars);


	// ff protect
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Post);
	HookEvent("friendly_fire", Event_FriendlyFire, EventHookMode_Pre);
	HookEvent("heal_begin", Event_HealBegin, EventHookMode_Pre);
	HookEvent("heal_end", Event_HealEnd, EventHookMode_Pre);
	HookEvent("heal_success", Event_HealSuccess, EventHookMode_Pre);
	HookEvent("player_incapacitated_start", Event_PlayerIncapStart, EventHookMode_Pre);

	MI_KV_Load();

	if (g_bLateLoad) 
	{
		for (int i = 1; i <= MaxClients; i++) 
		{
			if (IsClientInGame(i)) 
			{
				OnClientPutInServer(i);
			}

			for (int j = 0; j < UNDO_SIZE; j++) {
				g_iLastHealth[i][j][UNDO_PERM] = 0;
				g_iLastHealth[i][j][UNDO_TEMP] = 0;
			}
		}
	}
}

public void OnPluginEnd()
{
    MI_KV_Close();
}

//-------------------------------Cvars-------------------------------

public void ConVarChanged_Cvars(ConVar hCvar, const char[] sOldVal, const char[] sNewVal)
{
	GetCvars();
}

void GetCvars()
{
	g_iEnabledFlags = g_hCvarEnable.IntValue;
	g_iBlockZeroDmg = g_hCvarBlockZeroDmg.IntValue;
	g_fPermFrac = g_hCvarPermDamageFraction.FloatValue;
}

public Action:event_player_death(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));//死掉那位
	ResetGlow(client);
	return Plugin_Continue;
}


public event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	for (new i = 1; i <= MaxClients; i++) //clear both fake and real just because
	{
		fFakeGodframeEnd[i] = 0.0;
		lastSavedGodFrameBegin[i] = 0.0;
	}
}

// Apply fractional permanent damage here
// Also announce damage, and undo guilty bot damage
public Action Event_PlayerHurt(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	if (!g_iEnabledFlags) {
		return Plugin_Continue;
	}
	
	int iVictim = GetClientOfUserId(hEvent.GetInt("userid"));
	if (!IsClientAndInGame(iVictim) || GetClientTeam(iVictim) != 2) {
		return Plugin_Continue;
	}
	
	int iAttacker = GetClientOfUserId(hEvent.GetInt("attacker"));
	int iDmg = hEvent.GetInt("dmg_health");
	int iCurrentPerm = hEvent.GetInt("health");
	
	/*char sWeaponName[CLASSNAME_LENGTH];
	hEvent.GetString("weapon", sWeaponName, sizeof(sWeaponName));*/
	
	// When incapped you continuously get hurt by the world, so we just ignore incaps altogether
	if (iDmg > 0 && !IsIncapacitated(iVictim)) {
		// Cycle the undo pointer when we have confirmed that the damage was actually taken
		g_iCurrentUndo[iVictim] = (g_iCurrentUndo[iVictim] + 1) % UNDO_SIZE;
		
		// victim values are what OnTakeDamage expected us to have, current values are what the game gave us
		int iVictimPerm = g_iLastPerm[iVictim];
		int iVictimTemp = g_iLastTemp[iVictim];
		int iCurrentTemp = GetSurvivorTemporaryHealth(iVictim);

		// If this feature is enabled, some portion of damage will be applied to the temp health
		if (g_fPermFrac < 1.0 && iVictimPerm != iCurrentPerm) {
			// make sure we don't give extra health
			int iTotalHealthOld = iCurrentPerm + iCurrentTemp;
			int iTotalHealthNew = iVictimPerm + iVictimTemp;
			
			if (iTotalHealthOld == iTotalHealthNew) {
				SetEntityHealth(iVictim, iVictimPerm);

				SetEntPropFloat(iVictim, Prop_Send, "m_healthBuffer", float(iVictimTemp));
				SetEntPropFloat(iVictim, Prop_Send, "m_healthBufferTime", GetGameTime());
			}
		}
	}
	
	// Announce damage, and check for guilty bots that slipped through OnTakeDamage
	if (IsClientAndInGame(iAttacker) && GetClientTeam(iAttacker) == 2) {
		// Unfortunately, the friendly fire event only fires *after* OnTakeDamage has been called so it can't be blocked in time
		// So we must check here to see if the bots are guilty and undo the damage after-the-fact
		if ((g_iEnabledFlags & FFTYPE_STUPIDBOTS) && g_bStupidGuiltyBots[iVictim] && IsFakeClient(iVictim)) {
			UndoDamage(iVictim);
		}
	}

	return Plugin_Continue;
}

// When a Survivor is incapped by damage, player_hurt will not fire
// So you may notice that the code here has some similarities to the code for player_hurt
public Action Event_PlayerIncapStart(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	// Cycle the incap pointer, now that the damage has been confirmed
	int iVictim = GetClientOfUserId(hEvent.GetInt("userid"));
	
	// Cycle the undo pointer when we have confirmed that the damage was actually taken
	g_iCurrentUndo[iVictim] = (g_iCurrentUndo[iVictim] + 1) % UNDO_SIZE;
	
	int iAttacker = GetClientOfUserId(hEvent.GetInt("attacker"));
 
	// Announce damage, and check for guilty bots that slipped through OnTakeDamage
	if (IsClientAndInGame(iAttacker) && GetClientTeam(iAttacker) == 2) {
		// Unfortunately, the friendly fire event only fires *after* OnTakeDamage has been called so it can't be blocked in time
		// So we must check here to see if the bots are guilty and undo the damage after-the-fact
		if ((g_iEnabledFlags & FFTYPE_STUPIDBOTS) && g_bStupidGuiltyBots[iVictim] && IsFakeClient(iVictim)) {
			UndoDamage(iVictim);
		}
	}

	return Plugin_Continue;
}

// If a bot is guilty of creating a friendly fire event, undo it
// Also give the human some reaction time to realize the bot ran in front of them
public void Event_FriendlyFire(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	if (!(g_iEnabledFlags & FFTYPE_STUPIDBOTS)) {
		return;
	}
	
	int iClient = GetClientOfUserId(hEvent.GetInt("guilty"));
	if (IsFakeClient(iClient)) {
		g_bStupidGuiltyBots[iClient] = true;
		CreateTimer(0.4, StupidGuiltyBotDelay, iClient);
	}
}

Action StupidGuiltyBotDelay(Handle hTimer, any iClient)
{
	g_bStupidGuiltyBots[iClient] = false;

	return Plugin_Stop;
}

// For health kit undo, we must remember the target in HealBegin
public void Event_HealBegin(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	if (!g_iEnabledFlags) {
		return; // Not enabled?  Done
	}
	
	int iSubject = GetClientOfUserId(hEvent.GetInt("subject"));

	if (!IsClientAndInGame(iSubject) || GetClientTeam(iSubject) != 2 || !IsPlayerAlive(iSubject)) {
		return;
	}
	
	int iClient = GetClientOfUserId(hEvent.GetInt("userid"));
	if (!IsClientAndInGame(iClient) || GetClientTeam(iClient) != 2 || !IsPlayerAlive(iClient)) {
		return;
	}
	
	// Remember the target for HealEnd, since that parameter is a lie for that event
	g_iTargetTempHealth[iClient] = iSubject;
}

// When healing ends, remember how much temp health the target had
// This way it can be restored in UndoDamage
public void Event_HealEnd(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	if (!g_iEnabledFlags) {
		return; // Not enabled?  Done
	}
	
	int iClient = GetClientOfUserId(hEvent.GetInt("userid"));
	int iSubject = g_iTargetTempHealth[iClient]; // this is used first to carry the subject...
	
	if (!IsClientAndInGame(iSubject) || GetClientTeam(iSubject) != 2 || !IsPlayerAlive(iSubject)) {
		PrintToServer("Who did you heal? (%d)", iSubject);
		return;
	}
	
	int iTempHealth =  GetSurvivorTemporaryHealth(iSubject);
	if (iTempHealth < 0) {
		iTempHealth = 0;
	}
	
	// ...and second it is used to store the subject's temp health (since success knows the subject)
	g_iTargetTempHealth[iClient] = iTempHealth;
}

// Save the amount of health restored as negative so it can be undone
public void Event_HealSuccess(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	if (!g_iEnabledFlags) {
		return; // Not enabled?  Done
	}
	
	int iSubject = GetClientOfUserId(hEvent.GetInt("subject"));
	if (!IsClientAndInGame(iSubject) || GetClientTeam(iSubject) != 2  || !IsPlayerAlive(iSubject)) {
		return;
	}
	
	int iClient = GetClientOfUserId(hEvent.GetInt("userid"));
	
	int iNextUndo = (g_iCurrentUndo[iSubject] + 1) % UNDO_SIZE;
	g_iLastHealth[iSubject][iNextUndo][UNDO_PERM] = -hEvent.GetInt("health_restored");
	g_iLastHealth[iSubject][iNextUndo][UNDO_TEMP] = g_iTargetTempHealth[iClient];
	g_iCurrentUndo[iSubject] = iNextUndo;
}

public Event_revive_success(Handle:event, const String:name[], bool:dontBroadcast)
{
	new subject = GetClientOfUserId(GetEventInt(event, "subject"));//被救的那位
	if (!IsClientAndInGame(subject)) { return; } //just in case

	lastSavedGodFrameBegin[subject] = GetEngineTime();
	fFakeGodframeEnd[subject] = GetGameTime() + hrevive.FloatValue;
	iLastSI[subject] = 4;
	if (fFakeGodframeEnd[subject] > GetGameTime() && hGodframeGlows.BoolValue) {
		SetGodframedGlow(subject);
		CreateTimer(fFakeGodframeEnd[subject] - GetGameTime(), Timed_ResetGlow, subject);
	}
}
public PostSurvivorRelease(Handle:event, const String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event,"victim"));

	if (!IsClientAndInGame(victim)) { return; } //just in case

	//sets fake godframe time based on cvars for each ZC
	if (StrContains(name, "tongue") != -1)
	{
		lastSavedGodFrameBegin[victim] = GetEngineTime();
		fFakeGodframeEnd[victim] = GetGameTime() + hSmoker.FloatValue;
		iLastSI[victim] = 2;
	} else
	if (StrContains(name, "pounce") != -1)
	{
		lastSavedGodFrameBegin[victim] = GetEngineTime();
		fFakeGodframeEnd[victim] = GetGameTime() + hHunter.FloatValue;
		iLastSI[victim] = 1;
	}
	
	if (fFakeGodframeEnd[victim] > GetGameTime() && hGodframeGlows.BoolValue) {
		SetGodframedGlow(victim);
		CreateTimer(fFakeGodframeEnd[victim] - GetGameTime(), Timed_ResetGlow, victim);
	}
	
	return;
}

public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	SDKHook(client, SDKHook_TraceAttack, TraceAttackUndoFF);

	for (int j = 0; j < UNDO_SIZE; j++) {
		g_iLastHealth[client][j][UNDO_PERM] = 0;
		g_iLastHealth[client][j][UNDO_TEMP] = 0;
	}
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (!IsValidEdict(inflictor) || god.IntValue == 1 ) { return Plugin_Continue; }
	
	/********l4d2_hittable_control*******/
	if (IsClientAndInGame(attacker) && !IsFakeClient(attacker) && GetClientTeam(attacker) == 3 && GetEntProp(attacker, Prop_Send, "m_zombieClass") == 5 && victim == attacker && hTankSelfDamage.BoolValue)	{ return Plugin_Handled; }
	
	/********godframes_control*******/
	if(GetClientTeam(victim) != 2 || !IsClientAndInGame(victim)) { return Plugin_Continue; }
	CountdownTimer cTimerGod = L4D2Direct_GetInvulnerabilityTimer(victim);
	if (cTimerGod != CTimer_Null) { CTimer_Invalidate(cTimerGod); }

	char sClassname[CLASSNAME_LENGTH];
	GetEntityClassname(inflictor, sClassname, CLASSNAME_LENGTH);
	//PrintToChatAll("victim: %d, attacker:%d , sClassname is %s, damage is %f, damagetype is %d, health is %d",victim,attacker,sClassname,damage,damagetype,GetClientHealth(victim));

	new Float:fTimeLeft = fFakeGodframeEnd[victim] - GetGameTime();
	
	if (StrEqual(sClassname, "infected") && (iLastSI[victim] & hCommonFlags.IntValue)) //commons
	{
		fTimeLeft += hCommon.FloatValue;
	}
	if (IsClientAndInGame(attacker) && GetClientTeam(victim) == GetClientTeam(attacker)) //friendly fire
	{
		// ff protect

		//Block FF While Capped
		if (GetInfectedAttacker(victim) > 0) {
			return Plugin_Handled;
		}
		
		//Block AI FF
		if (IsFakeClient(victim) && IsFakeClient(attacker)) {
			return Plugin_Handled;
		}

		if (g_iEnabledFlags) {
			bool bUndone = false;
			int iDmg = RoundToFloor(damage); // Damage to survivors is rounded down

			// Only check damage to survivors
			// - if it is greater than 0, OR
			// - if a human survivor did 0 damage (so we know when the engine forgives our friendly fire for us)
			if (iDmg > 0 && !IsFakeClient(attacker)) {
				// Remember health for undo
				int iVictimPerm = GetClientHealth(victim);
				int iVictimTemp = GetSurvivorTemporaryHealth(victim);

				// if attacker is not ourself, check for undo damage
				if (attacker != victim) {
					char sWeaponName[CLASSNAME_LENGTH];
					GetClientWeapon(attacker, sWeaponName, sizeof(sWeaponName));
					
					float fDistance = GetClientsDistance(victim, attacker);
					float FFDist = GetWeaponFFDist(sWeaponName);
					if ((g_iEnabledFlags & FFTYPE_TOOCLOSE) && (fDistance < FFDist)) {
						bUndone = true;
					} else if ((g_iEnabledFlags & FFTYPE_STUPIDBOTS) && g_bStupidGuiltyBots[victim] && IsFakeClient(victim)) {
						bUndone = true;
					} else if (iDmg == 0) {
						// In order to get here, you must be a human Survivor doing 0 damage to another Survivor
						bUndone = ((g_iBlockZeroDmg & 0x02) || ((g_iBlockZeroDmg & 0x01)));
					}
				}

				// TODO: move to player_hurt?  and check to make sure damage was consistent between the two?
				// We prefer to do this here so we know what the player's state looked like pre-damage
				// Specifically, what portion of the damage was applied to perm and temp health,
				// since we can't tell after-the-fact what the damage was applied to
				// Unfortunately, not all calls to OnTakeDamage result in the player being hurt (e.g. damage during god frames)
				// So we use player_hurt to know when OTD actually happened
				if (!bUndone && iDmg > 0) {
					int iPermDmg = RoundToCeil(g_fPermFrac * iDmg);
					if (iPermDmg >= iVictimPerm)
					{
						// Perm damage won't reduce permanent health below 1 if there is sufficient temp health
						iPermDmg = iVictimPerm - 1;
					}
					
					int iTempDmg = iDmg - iPermDmg;
					if (iTempDmg > iVictimTemp) {
						// If TempDmg exceeds current temp health, transfer the difference to perm damage
						iPermDmg += (iTempDmg - iVictimTemp);
						iTempDmg = iVictimTemp;
					}
				
					// Don't add to undo list if player is incapped
					if (!IsIncapacitated(victim)) {
						// point at next undo cell
						int iNextUndo = (g_iCurrentUndo[victim] + 1) % UNDO_SIZE;
						
						if (iPermDmg < iVictimPerm) {
							// This will call player_hurt, so we should store the damage done so that it can be added back if it is undone
							g_iLastHealth[victim][iNextUndo][UNDO_PERM] = iPermDmg;
							g_iLastHealth[victim][iNextUndo][UNDO_TEMP] = iTempDmg;
							
							// We need some way to tell player_hurt how much perm/temp health we expected the player to have after this attack
							// This is used to implement the fractional damage to perm health
							// We can't just set their health here because this attack might not actually do damage
							g_iLastPerm[victim] = iVictimPerm - iPermDmg;
							g_iLastTemp[victim] = iVictimTemp - iTempDmg;
						} else {
							// This will call player_incap_start, so we should store their exact health and incap count at the time of attack
							// If the incap is undone, we will restore these settings instead of adding them
							g_iLastHealth[victim][iNextUndo][UNDO_PERM] = iVictimPerm;
							g_iLastHealth[victim][iNextUndo][UNDO_TEMP] = iVictimTemp;
							
							// This is used to tell player_incap_start the exact amount of damage that was done by the attack
							g_iLastPerm[victim] = iPermDmg;
							g_iLastTemp[victim] = iTempDmg;
							
							// TODO: can we move to incapstart?
							g_iLastReviveCount[victim] = GetEntProp(victim, Prop_Send, "m_currentReviveCount");
						}
					}
				}
			}

			if (bUndone) {
				return Plugin_Handled;
			}
		}
			

		if(iLastSI[victim] & hFFFlags.IntValue)
		{
			fTimeLeft += hFF.FloatValue;
		}
	}
	
	/********l4d2_hittable_control*******/
	//PrintToChatAll("%s dealt %f", sClassname, damage);
	if (strncmp(sClassname, "prop_physics", 12, false) == 0 || strncmp(sClassname, "prop_car_alarm", 14, false) == 0)
	{
		if (fOverkill[victim][inflictor] - GetGameTime() > 0.0)
			return Plugin_Handled; // Overkill on this Hittable.

		if (GetClientTeam(victim) != 2)
			return Plugin_Continue; // Victim is not a Survivor.
		
		char sModelName[PLATFORM_MAX_PATH];
		GetEntPropString(inflictor, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName));
		ReplaceString(sModelName, sizeof(sModelName), "\\", "/", false);
		float interval = hOverHitInterval.FloatValue;

		// Special Overkill section
		if (StrContains(sModelName, "brickpallets_break", false) != -1) // [0]
		{
			if (fSpecialOverkill[victim][0] - GetGameTime() > 0) return Plugin_Handled;
			fSpecialOverkill[victim][0] = GetGameTime() + interval;
			damage = 13.0;
			attacker = FindTank();
		}
		else if (StrContains(sModelName, "boat_smash_break", false) != -1) // [1]
		{
			if (fSpecialOverkill[victim][1] - GetGameTime() > 0) return Plugin_Handled;
			fSpecialOverkill[victim][1] = GetGameTime() + interval;
			damage = 23.0;
			attacker = FindTank();
		}
		else if (StrContains(sModelName, "concretepiller01_dm01", false) != -1) // [2]
		{
			if (fSpecialOverkill[victim][2] - GetGameTime() > 0) return Plugin_Handled;
			fSpecialOverkill[victim][2] = GetGameTime() + interval;
			damage = 8.0;
			attacker = FindTank();
		}
		
		float val = hStandardIncapDamage.FloatValue;
		float gauntletMulti = hGauntletFinaleMulti.FloatValue;
		if (GetEntProp(victim, Prop_Send, "m_isIncapacitated") 
		&& val != -2) // Survivor is Incapped. (Damage)
		{
			if (val >= 0.0)
			{
				// Use standard damage on gauntlet finales
				if (g_bGauntletFinaleMap)
				{
					//damage = val * 4.0 * gauntletMulti;
					damage = val * gauntletMulti;
				}
				else
				{
					damage = val;
				}
			}

			else return Plugin_Continue;
		}
		else 
		{
			if (StrContains(sModelName, "cara_", false) != -1 
			|| StrContains(sModelName, "taxi_", false) != -1 
			|| StrContains(sModelName, "police_car", false) != -1
			|| StrContains(sModelName, "utility_truck", false) != -1)
			{
				damage = hCarStandingDamage.FloatValue;
			}
			else if (StrContains(sModelName, "dumpster", false) != -1)
			{
				damage = hDumpsterStandingDamage.FloatValue;
			}
			else if (StrEqual(sModelName, "models/props/cs_assault/forklift.mdl", false))
			{
				damage = hForkliftStandingDamage.FloatValue;
			}
			else if (StrContains(sModelName, "forklift_brokenlift", false) != -1)
			{
				damage = hBrokenForkliftStandingDamage.FloatValue;
			}		
			else if (StrEqual(sModelName, "models/props_vehicles/airport_baggage_cart2.mdl", false))
			{
				damage = hBaggageStandingDamage.FloatValue;
			}
			else if (StrEqual(sModelName, "models/props_unique/haybails_single.mdl", false))
			{
				damage = hHaybaleStandingDamage.FloatValue;
			}
			else if (StrEqual(sModelName, "models/props_foliage/swamp_fallentree01_bare.mdl", false))
			{
				damage = hLogStandingDamage.FloatValue;
			}
			else if (StrEqual(sModelName, "models/props_foliage/tree_trunk_fallen.mdl", false))
			{
				damage = hBHLogStandingDamage.FloatValue;
			}
			else if (StrEqual(sModelName, "models/props_fairgrounds/bumpercar.mdl", false))
			{
				damage = hBumperCarStandingDamage.FloatValue;
			}
			else if (StrEqual(sModelName, "models/props/cs_assault/handtruck.mdl", false))
			{
				damage = hHandtruckStandingDamage.FloatValue;
			}
			else if (StrEqual(sModelName, "models/props_vehicles/generatortrailer01.mdl", false))
			{
				damage = hGeneratorTrailerStandingDamage.FloatValue;
			}
			else if (StrEqual(sModelName, "models/props/cs_militia/militiarock01.mdl", false))
			{
				damage = hMilitiaRockStandingDamage.FloatValue;
			}
			else if (StrEqual(sModelName, "models/props_interiors/sofa_chair02.mdl", false))
			{
				char targetname[128];
				GetEntPropString(inflictor, Prop_Data, "m_iName", targetname, 128);
				if (StrEqual(targetname, "hittable_chair_l4d1", false))
				{
					damage = hSofaChairStandingDamage.FloatValue;
				}
			}
			else if (StrEqual(sModelName, "models/props_vehicles/van.mdl", false))
			{
				damage = hVanDamage.FloatValue;
			}
			else if (StrContains(sModelName, "atlas_break_ball.mdl", false) != -1)
			{
				damage = hAtlasBallDamage.FloatValue;
			}
			else if (StrContains(sModelName, "ibeam_breakable01", false) != -1)
			{
				damage = hIBeamDamage.FloatValue;
			}
			else if (StrEqual(sModelName, "models/props_diescraper/statue_break_ball.mdl", false))
			{
				damage = hDiescraperBallDamage.FloatValue;
			}
			else if (StrEqual(sModelName, "models/sblitz/field_equipment_cart.mdl", false))
			{
				damage = hBaggageStandingDamage.FloatValue;
			}
			
			// Use standard damage on gauntlet finales
			if (g_bGauntletFinaleMap)
			{
				//damage = damage * 4.0 * gauntletMulti;
				damage = damage * gauntletMulti;
			}
		}
		
		if (interval >= 0.0)
		{
			fOverkill[victim][inflictor] = GetGameTime() + interval;	//standardise them bitchin over-hits
		}
		inflictor = 0; // We have to set set the inflictor to 0 or else it will sometimes just refuse to apply damage.

		if (hOverHitDebug.BoolValue) PrintToChatAll("[l4d2_hittable_control]: \x03%N \x01was hit by \x04%s \x01for \x03%i \x01damage. Gauntlet: %b", victim, sModelName, RoundToNearest(damage), g_bGauntletFinaleMap);

		return Plugin_Changed;
	}

	/********godframes_control*******/
	if (fTimeLeft<=0)//自己設置的無敵時間已過 1. Smoker拉的 2. 剛倒地起來的 3. Hunter解脫
	{	
		iLastSI[victim] = 0;
	}
	if (fTimeLeft > 0) //means fake god frames are in effect
	{
		if(StrEqual(sClassname, "worldspawn") && attacker==0)//墬樓 官方預設godframe 時間內墜樓照樣有傷害
			return Plugin_Continue;
		
		//hittables, witch
		if ( ((strncmp(sClassname, "prop_physics", 12, false) == 0 || strncmp(sClassname, "prop_car_alarm", 14, false) == 0) && hHittable.BoolValue) || 
			 (StrEqual(sClassname, "witch") && hWitch.BoolValue) )
		{
			return Plugin_Continue;
		}

		//其餘傷害
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

/* //////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//																												   //
//																												   //
//							--------------    JUST UNDO FF STUFF      --------------							   //
//																												   //
//																												   //
////////////////////////////////////////////////////////////////////////////////////////////////////////////////// */

// The sole purpose of this hook is to prevent survivor bots from causing the vision of human survivors to recoil
public Action TraceAttackUndoFF(int iVictim, int &iAttacker, int &iInflictor, float &fDamage, int &iDamagetype, int &iAmmotype, int iHitbox, int iHitgroup)
{
	// If none of the flags are enabled, don't do anything
	if (!g_iEnabledFlags) {
		return Plugin_Continue;
	}
	
	// Only interested in Survivor victims
	if (!IsClientAndInGame(iVictim) || GetClientTeam(iVictim) != 2) {
		return Plugin_Continue;
	}
	
	// If a valid survivor bot shoots a valid survivor human, block it to prevent survivor vision from getting experiencing recoil (it would have done 0 damage anyway)
	if ((g_iBlockZeroDmg & 0x04) && IsClientAndInGame(iAttacker) && GetClientTeam(iAttacker) == 2 && IsFakeClient(iAttacker) && 
		IsClientAndInGame(iVictim) && GetClientTeam(iVictim) == 2 && !IsFakeClient(iVictim)) {
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

stock IsClientAndInGame(client)
{
	if (0 < client && client <= MaxClients)
	{	
		return IsClientInGame(client);
	}
	return false;
}

public Action:Timed_ResetGlow(Handle:timer, any:client) {
	ResetGlow(client);
}

ResetGlow(client) {
	if (IsClientAndInGame(client)) {
		// remove transparency/color
		SetEntityRenderMode(client, RenderMode:0);
		SetEntityRenderColor(client, 255,255,255,255);
	}
}

SetGodframedGlow(client) {	//there might be issues with realism
	if (IsClientAndInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == 2) {
		// make player transparent/red while godframed
		SetEntityRenderMode( client, RenderMode:3 );
		SetEntityRenderColor (client, 255,0,0,200 );
	}
}

public OnMapStart() {

	/********l4d2_hittable_control*******/
	g_bGauntletFinaleMap = false;
	char sMap[64];
	GetCurrentMap(sMap, sizeof(sMap));

	MI_KV_Close();
	MI_KV_Load();
	if (!KvJumpToKey(g_hMIData, sMap)) {
		//LogError("[MI] MapInfo for %s is missing.", g_sCurMap);
	} else
	{
		if (g_hMIData.GetNum("GauntletFinale_map", 0) == 1)
		{
			g_bGauntletFinaleMap = true;
		}
	}
	KvRewind(g_hMIData);

	/********godframes_control*******/
	for (new i = 0; i <= MaxClients; i++) {
		ResetGlow(i);
	}
}

void MI_KV_Load()
{
	char sNameBuff[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sNameBuff, 256, "data/%s", "mapinfo.txt");

	g_hMIData = CreateKeyValues("MapInfo");
	if (!FileToKeyValues(g_hMIData, sNameBuff)) {
		//LogError("[MI] Couldn't load MapInfo data!");
		MI_KV_Close();
	}
}

void MI_KV_Close()
{
	if (g_hMIData != null) {
		CloseHandle(g_hMIData);
		g_hMIData = null;
	}
}

int FindTank()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i)
		&& GetClientTeam(i) == 3
		&& GetEntProp(i, Prop_Send, "m_zombieClass") == 5)
		{
			return i;
		}
	}
	return 0;
}

int GetInfectedAttacker(int client)
{
	int attacker;

	/* Hunter */
	attacker = GetEntPropEnt(client, Prop_Send, "m_pounceAttacker");
	if (attacker > 0)
	{
		return attacker;
	}

	/* Smoker */
	attacker = GetEntPropEnt(client, Prop_Send, "m_tongueOwner");
	if (attacker > 0)
	{
		return attacker;
	}

	return -1;
}

// The magic behind Undo Damage
// Cycles through the array, can also undo incapacitations
void UndoDamage(int iClient)
{
	if (IsClientAndInGame(iClient) || GetClientTeam(iClient) == 2) {
		int iThisUndo = g_iCurrentUndo[iClient];
		int iUndoPerm = g_iLastHealth[iClient][iThisUndo][UNDO_PERM];
		int iUndoTemp = g_iLastHealth[iClient][iThisUndo][UNDO_TEMP];

		int iNewHealth, iNewTemp;
		if (IsIncapacitated(iClient)) {
			// If player is incapped, restore their previous health and incap count
			iNewHealth = iUndoPerm;
			iNewTemp = iUndoTemp;
			
			CheatCommand(iClient, "give", "health");
			SetEntProp(iClient, Prop_Send, "m_currentReviveCount", g_iLastReviveCount[iClient]);
		} else {
			// add perm and temp health back to their existing health
			iNewHealth = GetClientHealth(iClient) + iUndoPerm;
			iNewTemp = iUndoTemp;
			if (iUndoPerm >= 0) {
				// undoing damage, so add current temp health do undoTemp
				iNewTemp += GetSurvivorTemporaryHealth(iClient);
			} else {
				// undoPerm is negative when undoing healing, so don't add current temp health
				// instead, give the health kit that was undone
				CheatCommand(iClient, "give", "weapon_first_aid_kit");
			}
		}
		
		if (iNewHealth > 100) {
			iNewHealth = 100; // prevent going over 100 health
		}
		
		if (iNewHealth + iNewTemp > 100) {
			iNewTemp = 100 - iNewHealth;
		}
		
		SetEntityHealth(iClient, iNewHealth);
		SetEntPropFloat(iClient, Prop_Send, "m_healthBuffer", float(iNewTemp));
		SetEntPropFloat(iClient, Prop_Send, "m_healthBufferTime", GetGameTime());
	
		// clear out the undo so it can't happen again
		g_iLastHealth[iClient][iThisUndo][UNDO_PERM] = 0;
		g_iLastHealth[iClient][iThisUndo][UNDO_TEMP] = 0;
		
		// point to the previous undo
		if (iThisUndo <= 0) {
			iThisUndo = UNDO_SIZE;
		}
		
		iThisUndo = iThisUndo - 1;
		g_iCurrentUndo[iClient] = iThisUndo;
	}
}

// Gets the distance between two survivors
// Accounting for any difference in height
float GetClientsDistance(int iVictim, int iAttacker)
{
	float fMins[3], fMaxs[3];
	GetClientMins(iVictim, fMins);
	GetClientMaxs(iVictim, fMaxs);
	
	float fHalfHeight = fMaxs[2] - fMins[2] + 10;
	
	float fAttackerPos[3], fVictimPos[3];
	GetClientAbsOrigin(iVictim, fVictimPos);
	GetClientAbsOrigin(iAttacker, fAttackerPos);
	
	float fPosHeightDiff = fAttackerPos[2] - fVictimPos[2];
	
	if (fPosHeightDiff > fHalfHeight) {
		fAttackerPos[2] -= fHalfHeight;
	} else if (fPosHeightDiff < (-1.0 * fHalfHeight)) {
		fVictimPos[2] -= fHalfHeight;
	} else {
		fAttackerPos[2] = fVictimPos[2];
	}
	
	return GetVectorDistance(fVictimPos, fAttackerPos, false);
}

// Gets per-weapon friendly fire undo distances
float GetWeaponFFDist(char[] sWeaponName)
{
	if (strcmp(sWeaponName, "weapon_pistol") == 0
	) {
		return 25.0;
	} else if (strcmp(sWeaponName, "weapon_smg") == 0
		|| strcmp(sWeaponName, "weapon_rifle") == 0
	) {
		return 37.0; // zonemode: 30
	} else if (strcmp(sWeaponName, "weapon_pumpshotgun") == 0
		|| strcmp(sWeaponName, "weapon_autoshotgun") == 0
		|| strcmp(sWeaponName, "weapon_hunting_rifle") == 0
	) {
		return 37.0;
	}

	return 0.0;
}

stock int GetSurvivorTemporaryHealth(int client)
{
	static ConVar pain_pills_decay_rate = null;
	if (pain_pills_decay_rate == null)
	{
		pain_pills_decay_rate = FindConVar("pain_pills_decay_rate");
	}
	
	float fDecayRate = pain_pills_decay_rate.FloatValue;

	float fHealthBuffer = GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
	float fHealthBufferTimeStamp = GetEntPropFloat(client, Prop_Send, "m_healthBufferTime");
	
	float fHealthBufferDuration = GetGameTime() - fHealthBufferTimeStamp;

	int iTempHp = RoundToCeil(fHealthBuffer - (fHealthBufferDuration * fDecayRate)) - 1;

	return (iTempHp > 0) ? iTempHp : 0;
}

stock bool IsIncapacitated(int client)
{
	return view_as<bool>(GetEntProp(client, Prop_Send, "m_isIncapacitated", 1));
}

void CheatCommand(int iClient, const char[] sCommand, const char[] sArguments)
{
	int flags = GetCommandFlags(sCommand);
	SetCommandFlags(sCommand, flags & ~FCVAR_CHEAT);
	FakeClientCommand(iClient, "%s %s", sCommand, sArguments);
	SetCommandFlags(sCommand, flags);
}