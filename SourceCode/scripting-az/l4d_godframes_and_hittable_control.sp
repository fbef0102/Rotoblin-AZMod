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
new Handle: hHittable = INVALID_HANDLE;
new Handle: hWitch = INVALID_HANDLE;
new Handle: hFF = INVALID_HANDLE;
new Handle: hCommon = INVALID_HANDLE;
new Handle: hHunter = INVALID_HANDLE;
new Handle: hSmoker = INVALID_HANDLE;
new Handle: hCommonFlags = INVALID_HANDLE;
new Handle: hGodframeGlows = INVALID_HANDLE;
new Handle: hrevive = INVALID_HANDLE;
new Handle: hFFFlags = INVALID_HANDLE;

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
bool bLateLoad;   // Late load support!

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

public Plugin:myinfo =
{
	name = "L4D2 Godframes Control (starring Austin Powers, Baby Yeah!,l4d1 modify by Harry). Stabby, l4d2_hittable_control (Visor, L4D1 port by Harry)",
	author = "Stabby, CircleSquared, Tabun,AtomicStryker(l4d2_godframesbegone)",
	version = "1.5",
	description = "控制人類無敵狀態的時間並顯示顏色. Allows for customisation of hittable damage values."
};

public APLRes:AskPluginLoad2(Handle:plugin, bool:late, String:error[], errMax) 
{
	bLateLoad = late;
	return APLRes_Success;    
}

static KeyValues g_hMIData = null;

public OnPluginStart()
{
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
	

	hFF = CreateConVar( 		"gfc_ff_min_time", "0.8",
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
									"How long should godframes after received from incap(not from ledge)?",
									FCVAR_NOTIFY, true, 0.0, true, 3.0 );
	//zone:charger+hunter only
	hCommonFlags= CreateConVar( "gfc_common_zc_flags", "2",
									"Which classes will be affected by extra common protection time. 1 - Hunter. 2 - Smoker. 4 - Receive.",
									FCVAR_NOTIFY, true, 0.0, true, 7.0 );
	hFFFlags= CreateConVar( "gfc_FF_zc_flags", "2",
									"Which classes will be affected by extra FF protection time. 1 - Hunter. 2 - Smoker. 4 - Receive.",
									FCVAR_NOTIFY, true, 0.0, true, 7.0 );								

	HookEvent("tongue_release", PostSurvivorRelease);
	HookEvent("pounce_end", PostSurvivorRelease);
	HookEvent("player_death", event_player_death, EventHookMode_Pre);
	HookEvent("revive_success", Event_revive_success);//救起倒地的or 懸掛的
	HookEvent("round_start", event_RoundStart, EventHookMode_PostNoCopy);//每回合開始就發生的event

	MI_KV_Load();

	if (bLateLoad) 
	{
		for (new i = 1; i <= MaxClients; i++) 
		{
			if (IsClientInGame(i)) 
			{
				OnClientPutInServer(i);
			}
		}
	}
}

public void OnPluginEnd()
{
    MI_KV_Close();
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

public Event_revive_success(Handle:event, const String:name[], bool:dontBroadcast)
{
	new subject = GetClientOfUserId(GetEventInt(event, "subject"));//被救的那位
	if (subject<=0||!IsClientAndInGame(subject)) { return; } //just in case

	lastSavedGodFrameBegin[subject] = GetEngineTime();
	fFakeGodframeEnd[subject] = GetGameTime() + GetConVarFloat(hrevive);
	iLastSI[subject] = 4;
	if (fFakeGodframeEnd[subject] > GetGameTime() && GetConVarBool(hGodframeGlows)) {
		SetGodframedGlow(subject);
		CreateTimer(fFakeGodframeEnd[subject] - GetGameTime(), Timed_ResetGlow, subject);
	}
}
public PostSurvivorRelease(Handle:event, const String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event,"victim"));

	if (victim<=0||!IsClientAndInGame(victim)) { return; } //just in case

	//sets fake godframe time based on cvars for each ZC
	if (StrContains(name, "tongue") != -1)
	{
		lastSavedGodFrameBegin[victim] = GetEngineTime();
		fFakeGodframeEnd[victim] = GetGameTime() + GetConVarFloat(hSmoker);
		iLastSI[victim] = 2;
	} else
	if (StrContains(name, "pounce") != -1)
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

public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (!IsValidEdict(inflictor) || GetConVarInt(FindConVar("god")) == 1 ) { return Plugin_Continue; }
	
	/********l4d2_hittable_control*******/
	if (IsClientAndInGame(attacker) && !IsFakeClient(attacker) && GetClientTeam(attacker) == 3 && GetEntProp(attacker, Prop_Send, "m_zombieClass") == 5 && victim == attacker && GetConVarBool(hTankSelfDamage))	{ return Plugin_Handled; }
	
	/********godframes_control*******/
	if(GetClientTeam(victim) != 2 || !IsClientAndInGame(victim)) { return Plugin_Continue; }
	CountdownTimer cTimerGod = L4D2Direct_GetInvulnerabilityTimer(victim);
	if (cTimerGod != CTimer_Null) { CTimer_Invalidate(cTimerGod); }

	char sClassname[CLASSNAME_LENGTH];
	GetEntityClassname(inflictor, sClassname, CLASSNAME_LENGTH);
	//decl String:sdamagetype[64] ;
    //GetEdictClassname( damagetype, sdamagetype, sizeof( sdamagetype ) ) ;
	//PrintToChatAll("victim: %d,attacker:%d ,sClassname is %s, damage is %f, damagetype is %s, health is %d",victim,attacker,sClassname,damage,sdamagetype,GetClientHealth(victim));
	
	new Float:fTimeLeft = fFakeGodframeEnd[victim] - GetGameTime();
	
	if (StrEqual(sClassname, "infected") && (iLastSI[victim] & GetConVarInt(hCommonFlags))) //commons
	{
		fTimeLeft += GetConVarFloat(hCommon);
	}
	if (IsClientAndInGame(attacker) && GetClientTeam(victim) == GetClientTeam(attacker) && (iLastSI[victim] & GetConVarInt(hFFFlags))) //friendly fire
	{
		fTimeLeft += GetConVarFloat(hFF);
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
		float interval = GetConVarFloat(hOverHitInterval);

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
		
		float val = GetConVarFloat(hStandardIncapDamage);
		float gauntletMulti = GetConVarFloat(hGauntletFinaleMulti);
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
				damage = GetConVarFloat(hCarStandingDamage);
			}
			else if (StrContains(sModelName, "dumpster", false) != -1)
			{
				damage = GetConVarFloat(hDumpsterStandingDamage);
			}
			else if (StrEqual(sModelName, "models/props/cs_assault/forklift.mdl", false))
			{
				damage = GetConVarFloat(hForkliftStandingDamage);
			}
			else if (StrContains(sModelName, "forklift_brokenlift", false) != -1)
			{
				damage = GetConVarFloat(hBrokenForkliftStandingDamage);
			}		
			else if (StrEqual(sModelName, "models/props_vehicles/airport_baggage_cart2.mdl", false))
			{
				damage = GetConVarFloat(hBaggageStandingDamage);
			}
			else if (StrEqual(sModelName, "models/props_unique/haybails_single.mdl", false))
			{
				damage = GetConVarFloat(hHaybaleStandingDamage);
			}
			else if (StrEqual(sModelName, "models/props_foliage/swamp_fallentree01_bare.mdl", false))
			{
				damage = GetConVarFloat(hLogStandingDamage);
			}
			else if (StrEqual(sModelName, "models/props_foliage/tree_trunk_fallen.mdl", false))
			{
				damage = GetConVarFloat(hBHLogStandingDamage);
			}
			else if (StrEqual(sModelName, "models/props_fairgrounds/bumpercar.mdl", false))
			{
				damage = GetConVarFloat(hBumperCarStandingDamage);
			}
			else if (StrEqual(sModelName, "models/props/cs_assault/handtruck.mdl", false))
			{
				damage = GetConVarFloat(hHandtruckStandingDamage);
			}
			else if (StrEqual(sModelName, "models/props_vehicles/generatortrailer01.mdl", false))
			{
				damage = GetConVarFloat(hGeneratorTrailerStandingDamage);
			}
			else if (StrEqual(sModelName, "models/props/cs_militia/militiarock01.mdl", false))
			{
				damage = GetConVarFloat(hMilitiaRockStandingDamage);
			}
			else if (StrEqual(sModelName, "models/props_interiors/sofa_chair02.mdl", false))
			{
				char targetname[128];
				GetEntPropString(inflictor, Prop_Data, "m_iName", targetname, 128);
				if (StrEqual(targetname, "hittable_chair_l4d1", false))
				{
					damage = GetConVarFloat(hSofaChairStandingDamage);
				}
			}
			else if (StrEqual(sModelName, "models/props_vehicles/van.mdl", false))
			{
				damage = GetConVarFloat(hVanDamage);
			}
			else if (StrContains(sModelName, "atlas_break_ball.mdl", false) != -1)
			{
				damage = GetConVarFloat(hAtlasBallDamage);
			}
			else if (StrContains(sModelName, "ibeam_breakable01", false) != -1)
			{
				damage = GetConVarFloat(hIBeamDamage);
			}
			else if (StrEqual(sModelName, "models/props_diescraper/statue_break_ball.mdl", false))
			{
				damage = GetConVarFloat(hDiescraperBallDamage);
			}
			else if (StrEqual(sModelName, "models/sblitz/field_equipment_cart.mdl", false))
			{
				damage = GetConVarFloat(hBaggageStandingDamage);
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

		if (GetConVarBool(hOverHitDebug)) PrintToChatAll("[l4d2_hittable_control]: \x03%N \x01was hit by \x04%s \x01for \x03%i \x01damage. Gauntlet: %b", victim, sModelName, RoundToNearest(damage), g_bGauntletFinaleMap);

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
		if ( ((strncmp(sClassname, "prop_physics", 12, false) == 0 || strncmp(sClassname, "prop_car_alarm", 14, false) == 0) && GetConVarBool(hHittable)) || 
			 (StrEqual(sClassname, "witch") && GetConVarBool(hWitch)) )
		{
			return Plugin_Continue;
		}

		//其餘傷害
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