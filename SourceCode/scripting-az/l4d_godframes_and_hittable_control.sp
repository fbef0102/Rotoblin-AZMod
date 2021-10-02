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
static Float:lastSavedGodFrameBegin[MAXPLAYERS+1]			=  0.0;
//static const		TEMP_HEALTH_ERROR_MARGIN				=    1;

/********l4d2_hittable_control*******/
new bool:	bIsBridge;			//for parish bridge cars
new bool:	bIgnoreOverkill		[MAXPLAYERS + 1];	//for hittable hits

//cvars
new Handle: hBridgeCarDamage			= INVALID_HANDLE;
new Handle: hLogStandingDamage			= INVALID_HANDLE;
new Handle: hCarStandingDamage			= INVALID_HANDLE;
new Handle: hBumperCarStandingDamage	= INVALID_HANDLE;
new Handle: hHandtruckStandingDamage	= INVALID_HANDLE;
new Handle: hGeneratortrailerStandingDamage = INVALID_HANDLE;
new Handle: hForkliftStandingDamage		= INVALID_HANDLE;
new Handle: hBHLogStandingDamage		= INVALID_HANDLE;
new Handle: hDumpsterStandingDamage		= INVALID_HANDLE;
new Handle: hHaybaleStandingDamage		= INVALID_HANDLE;
new Handle: hBaggageStandingDamage		= INVALID_HANDLE;
new Handle: hStandardIncapDamage		= INVALID_HANDLE;
new Handle: hTankSelfDamage				= INVALID_HANDLE;
new Handle: hOverHitInterval			= INVALID_HANDLE;

public Plugin:myinfo =
{
	name = "L4D2 Godframes Control (starring Austin Powers, Baby Yeah!,l4d1 modify by Harry). Stabby, l4d2_hittable_control (Visor, L4D1 port by Harry)",
	author = "Stabby, CircleSquared, Tabun,AtomicStryker(l4d2_godframesbegone)",
	version = "1.4",
	description = "控制人類無敵狀態的時間並顯示顏色. Allows for customisation of hittable damage values."
};

new bool:lateLoad;

public APLRes:AskPluginLoad2(Handle:plugin, bool:late, String:error[], errMax) 
{
	lateLoad = late;
	return APLRes_Success;    
}

public OnPluginStart()
{
	/********l4d2_hittable_control*******/
	//zone cfg set
	hBridgeCarDamage		= CreateConVar( "hc_bridge_car_damage",			"25.0",
											"Damage of cars in the parish bridge finale. Overrides standard incap damage on incapacitated players.",
											FCVAR_NOTIFY, true, 0.0, true, 300.0 );
											
	hLogStandingDamage		= CreateConVar( "hc_sflog_standing_damage",		"100.0",
											"Damage of hittable swamp fever logs to non-incapped survivors.",
											FCVAR_NOTIFY, true, 0.0, true, 300.0 );
											
	hBHLogStandingDamage	= CreateConVar( "hc_bhlog_standing_damage",		"100.0",
											"Damage of hittable blood harvest logs to non-incapped survivors.",
											FCVAR_NOTIFY, true, 0.0, true, 300.0 );
											
	hCarStandingDamage		= CreateConVar( "hc_car_standing_damage",		"100.0",
											"Damage of hittable non-parish-bridge cars to non-incapped survivors.",
											FCVAR_NOTIFY, true, 0.0, true, 300.0 );
											
	hBumperCarStandingDamage= CreateConVar( "hc_bumpercar_standing_damage",	"100.0",
											"Damage of hittable bumper cars to non-incapped survivors.",
											FCVAR_NOTIFY, true, 0.0, true, 300.0 );
											
	hHandtruckStandingDamage= CreateConVar( "hc_handtruck_standing_damage",	"8.0",
											"Damage of hittable handtrucks (aka dollies) to non-incapped survivors.",
											FCVAR_NOTIFY, true, 0.0, true, 300.0 );
											
	hGeneratortrailerStandingDamage= CreateConVar( "hc_generatortrailer_standing_damage",	"100.0",
											"Damage of hittable generatortrailer (in NM4) to non-incapped survivors.",
											FCVAR_NOTIFY, true, 0.0, true, 300.0 );
	
	hForkliftStandingDamage= CreateConVar(  "hc_forklift_standing_damage",	"100.0",
											"Damage of hittable forklifts to non-incapped survivors.",
											FCVAR_NOTIFY, true, 0.0, true, 300.0 );
											
	hDumpsterStandingDamage	= CreateConVar( "hc_dumpster_standing_damage",	"100.0",
											"Damage of hittable dumpsters to non-incapped survivors.",
											FCVAR_NOTIFY, true, 0.0, true, 300.0 );
											
	hHaybaleStandingDamage	= CreateConVar( "hc_haybale_standing_damage",	"100.0",
											"Damage of hittable haybales to non-incapped survivors.",
											FCVAR_NOTIFY, true, 0.0, true, 300.0 );
											
	hBaggageStandingDamage	= CreateConVar( "hc_baggage_standing_damage",	"100.0",
											"Damage of hittable baggage carts to non-incapped survivors.",
											FCVAR_NOTIFY, true, 0.0, true, 300.0 );
											
	hStandardIncapDamage	= CreateConVar( "hc_incap_standard_damage",		"-2",
											"Damage of all hittables to incapped players. -1 will have incap damage default to valve's standard incoherent damages. -2 will have incap damage default to each hittable's corresponding standing damage.",
											FCVAR_NOTIFY, true, -2.0, true, 300.0 );
											
	hTankSelfDamage			= CreateConVar( "hc_disable_self_damage",		"1",
											"If set 1, tank will not damage itself with hittables.",
											FCVAR_NOTIFY, true, 0.0, true, 1.0 );
											
	hOverHitInterval		= CreateConVar( "hc_overhit_time",				"1.4",
											"The amount of time to wait before allowing consecutive hits from the same hittable to register. Recommended values: 0.0-0.5: instant kill; 0.5-0.7: sizeable overhit; 0.7-1.0: standard overhit; 1.0-1.2: reduced overhit; 1.2+: no overhit unless the car rolls back on top. Set to tank's punch interval (default 1.5) to fully remove all possibility of overhit.",
											FCVAR_NOTIFY, true, 0.0, false );

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

	if (lateLoad) 
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

public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3])
{
	if (!IsValidEdict(victim) || !IsValidEdict(attacker) || !IsValidEdict(inflictor) || GetConVarInt(FindConVar("god")) == 1 ) { return Plugin_Continue; }
	
	/********l4d2_hittable_control*******/
	if (IsClientAndInGame(attacker)&& !IsFakeClient(attacker) && GetClientTeam(attacker) == 3 && GetEntProp(attacker, Prop_Send, "m_zombieClass") == 5 && victim == attacker && GetConVarBool(hTankSelfDamage))	{ return Plugin_Handled; }
	
	/********godframes_control*******/
	if(GetClientTeam(victim) != 2 || !IsClientAndInGame(victim)) { return Plugin_Continue; }
	new CountdownTimer:cTimerGod = L4D2Direct_GetInvulnerabilityTimer(victim);
	if (cTimerGod != CTimer_Null) { CTimer_Invalidate(cTimerGod); }

	decl String:sClassname[CLASSNAME_LENGTH];
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
	if (StrEqual(sClassname,"prop_physics") || StrEqual(sClassname,"prop_car_alarm"))
	{
		if (bIgnoreOverkill[victim]) { return Plugin_Handled; }
		if (GetClientTeam(victim) != 2)	{ return Plugin_Continue; }	
		
		decl String:sModelName[128];
		GetEntPropString(inflictor, Prop_Data, "m_ModelName", sModelName, 128);
		
		//PrintToChatAll("victim is %N, attacker is %N,damage is %f, damageType is %f, health is %d,inflictor is %s:%s",victim,attacker,damage,damageType,GetClientHealth(victim),sClass,sModelName);
		new Float:val = GetConVarFloat(hStandardIncapDamage);
		if (GetEntProp(victim, Prop_Send, "m_isIncapacitated") && val != -2)
		{
			if (val >= 0.0)
			{
				damage = val;
			}
			//else
			//{
			//	return Plugin_Continue;
			//}
		}
		else 
		{
			if (StrContains(sModelName, "cara_") != -1 || StrContains(sModelName, "taxi_") != -1 || StrContains(sModelName, "police_car") != -1)
			{
				if (bIsBridge)
				{
					damage = 4.0*GetConVarFloat(hBridgeCarDamage);
					inflictor = 0;	//because valve is silly and damage on incapped players would be ignored otherwise
				}
				else
				{
					damage = GetConVarFloat(hCarStandingDamage);
				}
			}
			else if (StrContains(sModelName, "dumpster") != -1)
			{
				damage = GetConVarFloat(hDumpsterStandingDamage);
			}
			else if (StrEqual(sModelName, "models/props/cs_assault/forklift.mdl"))
			{
				damage = GetConVarFloat(hForkliftStandingDamage);
			}			
			else if (StrEqual(sModelName, "models/props_vehicles/airport_baggage_cart2.mdl"))
			{
				damage = GetConVarFloat(hBaggageStandingDamage);
			}
			else if (StrEqual(sModelName, "models/props_unique/haybails_single.mdl"))
			{
				damage = GetConVarFloat(hHaybaleStandingDamage);
			}
			else if (StrEqual(sModelName, "models/props_foliage/Swamp_FallenTree01_bare.mdl"))
			{
				damage = GetConVarFloat(hLogStandingDamage);
			}
			else if (StrEqual(sModelName, "models/props_foliage/tree_trunk_fallen.mdl"))
			{
				damage = GetConVarFloat(hBHLogStandingDamage);
			}
			else if (StrEqual(sModelName, "models/props_fairgrounds/bumpercar.mdl"))
			{
				damage = GetConVarFloat(hBumperCarStandingDamage);
			}
			else if (StrEqual(sModelName, "models/props/cs_assault/handtruck.mdl"))
			{
				damage = GetConVarFloat(hHandtruckStandingDamage);
			}
			else if (StrEqual(sModelName, "models/props_vehicles/generatortrailer01.mdl"))
			{
				damage = GetConVarFloat(hGeneratortrailerStandingDamage);
			}
			//PrintToChatAll("%s fell on %N, dealing %f dmg", sModelName, victim, damage);
		}
		
		new Float:interval = GetConVarFloat(hOverHitInterval);		
		if (interval >= 0.0)
		{
			bIgnoreOverkill[victim] = true;	//standardise them bitchin over-hits
			CreateTimer(interval, Timed_ClearInvulnerability, victim);
		}

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
		if ( ((StrEqual(sClassname,"prop_physics") || StrEqual(sClassname,"prop_car_alarm")) && GetConVarBool(hHittable)) || 
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
	if (0 < client && client < MaxClients)
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
	decl String:buffer[64];
	GetCurrentMap(buffer, sizeof(buffer));
	if (StrContains(buffer, "c5m5") != -1)	//so it works for darkparish. should probably find out what causes the changes to the cars though, this is ugly
	{
		bIsBridge = true;
	}
	else
	{
		bIsBridge = false;	//in case of map changes or something
	}
	
	/********godframes_control*******/
	for (new i = 0; i <= MaxClients; i++) {
		ResetGlow(i);
	}
}

/********l4d2_hittable_control*******/
public Action:Timed_ClearInvulnerability(Handle:thisTimer, any:victim)
{
	bIgnoreOverkill[victim] = false;
}