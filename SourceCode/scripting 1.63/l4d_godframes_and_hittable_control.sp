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
#include <left4downtown>
#include <l4d_direct>
#define L4D2UTIL_STOCKS_ONLY
#include <l4d2util>

#define CLASSNAME_LENGTH 64


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
static bool:client_lastlife[MAXPLAYERS + 1];
new iLastSI[MAXPLAYERS + 1];

//god frame be gone
static const Float:DAMAGE_CHECK_DELAY						=  0.1;
static const Float:HEAL_CHECKSTOP_RATIO						=  1.2;
static bool:justHealed[MAXPLAYERS+1]						= false;
static const String:CVAR_TEMP_HEALTH_DECAY[]				= "pain_pills_decay_rate";
static const Float:GOD_FRAME_CHECK_DURATION					=  3.0;
static Float:lastSavedGodFrameBegin[MAXPLAYERS+1]			=  0.0;
//static const		TEMP_HEALTH_ERROR_MARGIN				=    1;
static Handle:cvarTempHealthDecay							= INVALID_HANDLE;

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
native IsInReady();

public Plugin:myinfo =
{
	name = "L4D2 Godframes Control (starring Austin Powers, Baby Yeah!,l4d1 modify by Harry). Stabby, l4d2_hittable_control (Visor, L4D1 port by Harry)",
	author = "Stabby, CircleSquared, Tabun,AtomicStryker(l4d2_godframesbegone)",
	version = "1.4",
	description = "控制人類無敵狀態的時間並顯示顏色. Allows for customisation of hittable damage values."
};

public OnPluginStart()
{
	/********l4d2_hittable_control*******/
	//zone 1.8 cfg set
	hBridgeCarDamage		= CreateConVar( "hc_bridge_car_damage",			"25.0",
											"Damage of cars in the parish bridge finale. Overrides standard incap damage on incapacitated players.",
											FCVAR_PLUGIN, true, 0.0, true, 300.0 );
											
	hLogStandingDamage		= CreateConVar( "hc_sflog_standing_damage",		"100.0",
											"Damage of hittable swamp fever logs to non-incapped survivors.",
											FCVAR_PLUGIN, true, 0.0, true, 300.0 );
											
	hBHLogStandingDamage	= CreateConVar( "hc_bhlog_standing_damage",		"100.0",
											"Damage of hittable blood harvest logs to non-incapped survivors.",
											FCVAR_PLUGIN, true, 0.0, true, 300.0 );
											
	hCarStandingDamage		= CreateConVar( "hc_car_standing_damage",		"100.0",
											"Damage of hittable non-parish-bridge cars to non-incapped survivors.",
											FCVAR_PLUGIN, true, 0.0, true, 300.0 );
											
	hBumperCarStandingDamage= CreateConVar( "hc_bumpercar_standing_damage",	"100.0",
											"Damage of hittable bumper cars to non-incapped survivors.",
											FCVAR_PLUGIN, true, 0.0, true, 300.0 );
											
	hHandtruckStandingDamage= CreateConVar( "hc_handtruck_standing_damage",	"8.0",
											"Damage of hittable handtrucks (aka dollies) to non-incapped survivors.",
											FCVAR_PLUGIN, true, 0.0, true, 300.0 );
											
	hGeneratortrailerStandingDamage= CreateConVar( "hc_generatortrailer_standing_damage",	"100.0",
											"Damage of hittable generatortrailer (in NM4) to non-incapped survivors.",
											FCVAR_PLUGIN, true, 0.0, true, 300.0 );
	
	hForkliftStandingDamage= CreateConVar(  "hc_forklift_standing_damage",	"100.0",
											"Damage of hittable forklifts to non-incapped survivors.",
											FCVAR_PLUGIN, true, 0.0, true, 300.0 );
											
	hDumpsterStandingDamage	= CreateConVar( "hc_dumpster_standing_damage",	"100.0",
											"Damage of hittable dumpsters to non-incapped survivors.",
											FCVAR_PLUGIN, true, 0.0, true, 300.0 );
											
	hHaybaleStandingDamage	= CreateConVar( "hc_haybale_standing_damage",	"100.0",
											"Damage of hittable haybales to non-incapped survivors.",
											FCVAR_PLUGIN, true, 0.0, true, 300.0 );
											
	hBaggageStandingDamage	= CreateConVar( "hc_baggage_standing_damage",	"100.0",
											"Damage of hittable baggage carts to non-incapped survivors.",
											FCVAR_PLUGIN, true, 0.0, true, 300.0 );
											
	hStandardIncapDamage	= CreateConVar( "hc_incap_standard_damage",		"-2",
											"Damage of all hittables to incapped players. -1 will have incap damage default to valve's standard incoherent damages. -2 will have incap damage default to each hittable's corresponding standing damage.",
											FCVAR_PLUGIN, true, -2.0, true, 300.0 );
											
	hTankSelfDamage			= CreateConVar( "hc_disable_self_damage",		"1",
											"If set 1, tank will not damage itself with hittables.",
											FCVAR_PLUGIN, true, 0.0, true, 1.0 );
											
	hOverHitInterval		= CreateConVar( "hc_overhit_time",				"1.4",
											"The amount of time to wait before allowing consecutive hits from the same hittable to register. Recommended values: 0.0-0.5: instant kill; 0.5-0.7: sizeable overhit; 0.7-1.0: standard overhit; 1.0-1.2: reduced overhit; 1.2+: no overhit unless the car rolls back on top. Set to tank's punch interval (default 1.5) to fully remove all possibility of overhit.",
											FCVAR_PLUGIN, true, 0.0, false );

	/********godframes_control*******/
	hGodframeGlows = CreateConVar("gfc_godframe_glows", "1",
									"Changes the rendering of survivors while godframed (red/transparent).",
									FCVAR_PLUGIN, true, 0.0, true, 1.0 );
	
	hHittable = CreateConVar(	"gfc_hittable_override", "1",
									"Allow hittables to always ignore godframes.",
									FCVAR_PLUGIN, true, 0.0, true, 1.0 );
	hWitch = CreateConVar( 		"gfc_witch_override", "1",
									"Allow witches to always ignore godframes.",
									FCVAR_PLUGIN, true, 0.0, true, 1.0 );
	

	hFF = CreateConVar( 		"gfc_ff_min_time", "0.8",
									"Additional godframe time before FF damage is allowed.",
									FCVAR_PLUGIN, true, 0.0, true, 5.0 );
								
	hCommon = CreateConVar( 	"gfc_common_extra_time", "1.8",
									"Additional godframe time before common damage is allowed.",
									FCVAR_PLUGIN, true, 0.0, true, 3.0 );
	//官方預設2秒
	hHunter = CreateConVar( 	"gfc_hunter_duration", "1.8",
									"How long should godframes after a pounce last?",
									FCVAR_PLUGIN, true, 0.0, true, 3.0 );
	//官方預設2秒
	hSmoker = CreateConVar( 	"gfc_smoker_duration", "0.0",
									"How long should godframes after a pull or choke last?",
									FCVAR_PLUGIN, true, 0.0, true, 3.0 );
	//官方預設2秒			
	hrevive = CreateConVar( 	"gfc_revive_duration", "0.0",
									"How long should godframes after received from incap(not from ledge)?",
									FCVAR_PLUGIN, true, 0.0, true, 3.0 );
	//zone:charger+hunter only
	hCommonFlags= CreateConVar( "gfc_common_zc_flags", "2",
									"Which classes will be affected by extra common protection time. 1 - Hunter. 2 - Smoker. 4 - Receive.",
									FCVAR_PLUGIN, true, 0.0, true, 7.0 );
	hFFFlags= CreateConVar( "gfc_FF_zc_flags", "2",
									"Which classes will be affected by extra FF protection time. 1 - Hunter. 2 - Smoker. 4 - Receive.",
									FCVAR_PLUGIN, true, 0.0, true, 7.0 );								

	HookEvent("tongue_release", PostSurvivorRelease);
	HookEvent("pounce_end", PostSurvivorRelease);
	HookEvent("player_death", event_player_death, EventHookMode_Pre);
	HookEvent("revive_success", Event_revive_success);//救起倒地的or 懸掛的
	HookEvent("heal_success", Event_heal_success);//治療包治療成功
	HookEvent("round_start", event_RoundStart, EventHookMode_PostNoCopy);//每回合開始就發生的event
	HookEvent("player_incapacitated", 	_GF_IncapEvent); // being incapped 'heals' you from 1 to 300 hard health
	HookEvent("player_spawn",		Event_PlayerSpawn,	EventHookMode_PostNoCopy);
	HookEvent("player_bot_replace", OnBotSwap);
	HookEvent("bot_player_replace", OnBotSwap);
	cvarTempHealthDecay =	FindConVar(CVAR_TEMP_HEALTH_DECAY);
}
public Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));//復活的那位
	client_lastlife[client] = false;
}
public _GF_IncapEvent(Handle:event, const String:name[], bool:dontBroadcast)
{
	new subject = GetClientOfUserId(GetEventInt(event, "subject"));
	justHealed[subject] = true;
	CreateTimer(DAMAGE_CHECK_DELAY * HEAL_CHECKSTOP_RATIO, _GF_timer_ResetHealBool, subject);
}
public Action:_GF_timer_ResetHealBool(Handle:timer, any:subject)
{
	justHealed[subject] = false;
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
		client_lastlife[i] = false;
	}
}

public Action:OnBotSwap(Handle:event, const String:name[], bool:dontBroadcast) 
{
	if(IsInReady()) return Plugin_Continue;
	
	new bot = GetClientOfUserId(GetEventInt(event, "bot"));
	new player = GetClientOfUserId(GetEventInt(event, "player"));
	if (IsClientIndex(bot) && IsClientIndex(player)) 
	{
		if (StrEqual(name, "player_bot_replace")) 
		{
			
			client_lastlife[bot] = client_lastlife[player];
			client_lastlife[player] = false;
			justHealed[bot] = justHealed[player];
			justHealed[player] = false;
			
		}
		else 
		{
			client_lastlife[player] = client_lastlife[bot];
			client_lastlife[bot] = false;
			justHealed[player] = justHealed[bot];
			justHealed[bot] = false;
		}
	}
	return Plugin_Continue;
}

public Event_heal_success(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(IsInReady()) return;
	
	new subject = GetClientOfUserId(GetEventInt(event, "subject"));//被治療的那位
	if (subject<=0||!IsClientAndInGame(subject)) { return; } //just in case
	
	client_lastlife[subject] = false;
}

public Event_revive_success(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(IsInReady()) return;
	
	new subject = GetClientOfUserId(GetEventInt(event, "subject"));//被救的那位
	if (subject<=0||!IsClientAndInGame(subject)) { return; } //just in case
	if (GetEventBool(event,"ledge_hang"))
	{
		return;
	}
	if(GetEventBool(event, "lastlife"))
	{
		client_lastlife[subject] = true;
	}
	else
	{
		client_lastlife[subject] = false;
	}
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
	if (IsClientAndInGame(attacker)&&GetClientTeam(attacker) == 3 && GetEntProp(attacker, Prop_Send, "m_zombieClass") == 5 && victim == attacker && GetConVarBool(hTankSelfDamage))	{ return Plugin_Handled; }
	
	/********godframes_control*******/
	if(GetClientTeam(victim) != 2 || !IsClientAndInGame(victim)) { return Plugin_Continue; }
	//new CountdownTimer:cTimerGod = L4DDirect_GetInvulnerabilityTimer(victim);
	//if (cTimerGod != CTimer_Null) { CTimer_Invalidate(cTimerGod); }
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
	if (StrEqual(sClassname,"prop_physics") || StrEqual(sClassname,"prop_car_alarm")||StrEqual(sClassname, "prop_physics_multiplayer"))
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
		
		if(IsClientAndInGame(attacker) && GetClientTeam(attacker) == 3 && GetEntProp(attacker, Prop_Send, "m_zombieClass") == 5)
			SetTankFrustration(attacker, 100);
	}
	new hardhealth = GetHardHealth(victim);
	if(hardhealth>1) client_lastlife[victim] = false;
	/********godframes_control*******/
	if (fTimeLeft<=0)//自己設置的無敵時間已過 1. Smoker拉的 2. 剛倒地起來的 3. Hunter解脫
	{	
		if (lastSavedGodFrameBegin[victim] == 0.0											// case no god frames on record
		|| GetEngineTime() - lastSavedGodFrameBegin[victim] > GOD_FRAME_CHECK_DURATION)		// 被攻擊時已超過官方預設無敵時間
		{
			return Plugin_Changed;
		}
	
		//在官方預設無敵時間兩秒內
		CheckForGodMode(victim,damage); //利用插件手動給玩家扣血
	
		return Plugin_Continue;
	}
	if (fTimeLeft > 0) //means fake god frames are in effect
	{
		if(StrEqual(sClassname, "worldspawn") && attacker==0)//墬樓 官方預設godframe 時間內墜樓照樣有傷害
			return Plugin_Continue;
		
		//hittables,witch,rock
		if ( ((StrEqual(sClassname,"prop_physics") || StrEqual(sClassname,"prop_car_alarm") || StrEqual(sClassname, "prop_physics_multiplayer"))&&GetConVarBool(hHittable)) || 
			 (StrEqual(sClassname, "witch")&&GetConVarBool(hWitch)) )
		{
			if (lastSavedGodFrameBegin[victim] == 0.0											// case no god frames on record
			|| GetEngineTime() - lastSavedGodFrameBegin[victim] > GOD_FRAME_CHECK_DURATION)		// 被攻擊時已超過官方預設無敵時間
			{
				return Plugin_Changed;
			}
		
			//在官方預設無敵時間兩秒內
			CheckForGodMode(victim,damage); //利用插件手動給玩家扣血
		
			return Plugin_Continue;
		}
		//其餘傷害
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}
/*
public Action:Reincap_Timer(Handle:timer, any:client)
{
	SetEntProp(client, Prop_Send, "m_isIncapacitated", 1);
	SetEntityHealth(client, 300);
}
*/
public Action:_GF_timer_CheckForGodMode(Handle:timer, Handle:data)
{
	ResetPack(data);
	new victim = ReadPackCell(data);
	new targethardhealth = ReadPackCell(data);
	new Float:targettemphealth = ReadPackFloat(data);
	CloseHandle(data);
	
	if (justHealed[victim] || !IsClientInGame(victim)) return;
	if (IsIncapacitated(victim)) return;
	new hardhealth = GetHardHealth(victim);
	new Float:temphealth = GetAccurateTempHealth(victim);
	
	if (hardhealth > targethardhealth||temphealth > targettemphealth)
	{
		//PrintToChatAll("HAAAX! God Frames detected, hard health of %N is %d, supposed to be %d", victim, hardhealth, targethardhealth);
		//PrintToChatAll("HAAAX! God Frames detected, temp health of %N is %f, supposed to be %f", victim, temphealth, targettemphealth);
		if(targethardhealth==0&&targettemphealth==0.0)
		{
			//PrintToChatAll("incap or die");
			if( client_lastlife[victim] == true || IsIncapacitated(victim))//dead
				ForcePlayerSuicide(victim);
			else//incap
			{
				SetEntProp(victim, Prop_Send, "m_isIncapacitated", 0);
				SetEntityHealth(victim, 1);
				SetEntProp(victim, Prop_Send, "m_isIncapacitated", 1);
				SetEntityHealth(victim, 300);
			}
		}
		else
		{
			SetEntityHealth(victim, targethardhealth);
			SetEntPropFloat(victim, Prop_Send, "m_healthBuffer", targettemphealth);
		}
	}

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
static GetHardHealth(client)
{
	return GetEntProp(client, Prop_Send, "m_iHealth");
}
static Float:GetAccurateTempHealth(client)
{
	new Float:fHealth = GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
	fHealth -= (GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * GetConVarFloat(cvarTempHealthDecay);
	fHealth = (fHealth < 0.0 )? 0.0 : fHealth;
	
	return fHealth;
}

/********l4d2_hittable_control*******/
public Action:Timed_ClearInvulnerability(Handle:thisTimer, any:victim)
{
	bIgnoreOverkill[victim] = false;
}

CheckForGodMode(victim,Float:damage)
{
	new hardhealth = GetHardHealth(victim);
	new supposeddamage = RoundToNearest(damage);

	new resulthardhealth = hardhealth - supposeddamage;			// damage formula: subtract damage from hard health
	new Float:resulttemphealth = GetAccurateTempHealth(victim);

	if (resulthardhealth < 1)									// if negative hard health would result
	{
		if(hardhealth==1)//虛血之類的
		{
			resulthardhealth = 1;
			resulttemphealth -= supposeddamage;
		}
		else
		{
			supposeddamage = resulthardhealth * -1;					// the negative hard health equals whatever should transition to temp health
			resulthardhealth = 1;									// set expected hard health 1 for now
	
			resulttemphealth -= supposeddamage;						// try to pull the damage from temp health
		}
		if (resulttemphealth < 0)								// if that results in negative too
		{
			resulthardhealth = 0;
			resulttemphealth = 0.0;								// mark the victim as 'to be killed'
		}
	}

	new Handle:data = CreateDataPack();
	WritePackCell(data, victim);
	WritePackCell(data, resulthardhealth);
	WritePackFloat(data, resulttemphealth);

	CreateTimer(DAMAGE_CHECK_DELAY, _GF_timer_CheckForGodMode, data);
}

bool:IsClientIndex(client)
{
	return (client > 0 && client <= MaxClients);
}