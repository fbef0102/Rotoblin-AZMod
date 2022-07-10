#define PLUGIN_VERSION	"2.1"

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <multicolors>
#include <sdkhooks>
#undef REQUIRE_PLUGIN
#include <l4d_lib>

#define debug		0

#define PRESENT			"%"

#define NULL					-1
#define BOSSES				2
#define TANK_PASS_TIME		(g_fCvarTankSelectTime + 1.0)

#define CVAR_FLAGS			FCVAR_NOTIFY

enum DATA
{
	INDEX,
	DMG,
	WITCH = 0,
	TANK
}

native bool HasFinalFirstTank(); //from l4d_NoRescueFirstTank.smx
native bool HasEscapeTank(); //from l4d_NoEscapeTank.smx

public Plugin:myinfo =
{
	name = "l4d_tank_witch_damage_announce_spawnAnnouncer",
	author = "raziEiL [disawar1],l4d1 modify by Harry Potter",
	description = "Bosses dealt damage announcer and Announce in chat and via a sound when a Tank/Witch has spawned",
	version = PLUGIN_VERSION,
	url = "http://steamcommunity.com/profiles/76561198026784913"
}

static		Handle:g_hTankHealth, Handle:g_hVsBonusHealth, Handle:g_hDifficulty, Handle:g_hGameMode, bool:g_bCvarSkipBots, g_iCvarHealth[BOSSES],
			g_iDamage[MAXPLAYERS+1][MAXPLAYERS+1][BOSSES], g_iWitchIndex[MAXPLAYERS+1], g_iTotalDamage[MAXPLAYERS+1][BOSSES],
			bool:bTempBlock, g_iLastKnownTank, bool:g_bTankInGame, Handle:g_hTrine, g_iCvarFlags, g_iCvarPrivateFlags,
			bool:g_bNoHrCrown[MAXPLAYERS+1], g_iWitchCount, bool:g_bCvarRunAway, g_iWitchRef[MAXPLAYERS+1];
new control_time;
new                     g_iLastTankHealth           = 0;                // Used to award the killing blow the exact right amount of damage
new bool:g_bIsTankAlive;
new g_TankOtherDamage = 0;
new g_bCvarSurvLimit;
bool resuce_start = false, g_bVehicleIncoming = false, b_IsSecondWitch = false;

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

public OnPluginStart()
{
	LoadTranslations("Roto2-AZ_mod.phrases");
	g_hTankHealth		= FindConVar("z_tank_health");
	g_hVsBonusHealth	= FindConVar("versus_tank_bonus_health");
	g_hDifficulty		= FindConVar("z_difficulty");
	g_hGameMode			= FindConVar("mp_gamemode");

	new Handle:hCvarWitchHealth			= FindConVar("z_witch_health");
	new Handle:hCvarSurvLimit			= FindConVar("survivor_limit");

	new Handle:hCvarFlags		= CreateConVar("prodmg_announce_flags",		"3", "What stats get printed to chat. Flags: 0=disabled, 1=witch, 2=tank, 3=all", CVAR_FLAGS, true, 0.0, true, 3.0);
	new Handle:hCvarSkipBots	= CreateConVar("prodmg_ignore_bots",			"0", "If set, bots stats won't get printed to chat", CVAR_FLAGS, true, 0.0, true, 1.0);
	new Handle:hCvarPrivate		= CreateConVar("prodmg_announce_private",	"0", "If set, stats wont print to public chat. Flags (add together): 0=disabled, 1=witch, 2=tank, 3=all", CVAR_FLAGS, true, 0.0, true, 3.0);
	new Handle:hCvarRunAway		= CreateConVar("prodmg_failed_crown",		"1", "If set, witch stats at round end won't print if she isn't killed", CVAR_FLAGS, true, 0.0, true, 1.0);

	g_iCvarHealth[TANK]	= RoundFloat(GetConVarFloat(g_hTankHealth) * (IsVersusGameMode() ? GetConVarFloat(g_hVsBonusHealth) : GetCoopMultiplie()));
	g_iCvarHealth[WITCH]	= GetConVarInt(hCvarWitchHealth);
	g_bCvarSurvLimit			= GetConVarInt(hCvarSurvLimit);
	g_iCvarFlags				= GetConVarInt(hCvarFlags);
	g_bCvarSkipBots			= GetConVarBool(hCvarSkipBots);
	g_bCvarRunAway			= GetConVarBool(hCvarRunAway);

	HookConVarChange(g_hDifficulty,			OnConvarChange_TankHealth);
	HookConVarChange(g_hTankHealth,			OnConvarChange_TankHealth);
	HookConVarChange(g_hGameMode,			OnConvarChange_TankHealth);
	HookConVarChange(g_hVsBonusHealth,		OnConvarChange_TankHealth);
	HookConVarChange(hCvarWitchHealth,		OnConvarChange_WitchHealth);
	HookConVarChange(hCvarSurvLimit,		OnConvarChange_SurvLimit);
	HookConVarChange(hCvarFlags,				OnConvarChange_Flags);
	HookConVarChange(hCvarSkipBots,			OnConvarChange_SkipBots);
	HookConVarChange(hCvarPrivate,			OnConvarChange_Private);
	HookConVarChange(hCvarRunAway,			OnConvarChange_RunAway);

	HookEvent("round_start",			PD_ev_RoundStart,		EventHookMode_PostNoCopy);//每回合開始就發生的event
	HookEvent("round_end",			PD_ev_RoundEnd,			EventHookMode_PostNoCopy);
	HookEvent("tank_spawn",			PD_ev_TankSpawn,		EventHookMode_PostNoCopy);
	HookEvent("witch_spawn",			PD_ev_WitchSpawn);
	HookEvent("tank_frustrated",		PD_ev_TankFrustrated);
	HookEvent("witch_killed",			PD_ev_WitchKilled);
	HookEvent("entity_killed",		PD_ev_EntityKilled);
	HookEvent("player_hurt",			PD_ev_PlayerHurt);
	HookEvent("infected_hurt",		PD_ev_InfectedHurt);
	HookEvent("player_bot_replace",	PD_ev_PlayerBotReplace);
	HookEvent("finale_start", PD_ev_Finale_Start);
	HookEvent("finale_escape_start", PD_ev_FinaleEscStart, EventHookMode_PostNoCopy);
	
	g_hTrine = CreateTrie();
	
	control_time=1;
}

ConVar rotoblin_enable_2v2;
public void OnAllPluginsLoaded()
{
	rotoblin_enable_2v2 = FindConVar("rotoblin_enable_2v2");
}

public OnMapStart()
{
	PrecacheSound("ui/pickup_secret01.wav");
}

public Action:PD_ev_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	//LogMessage("Now round_start event");
	b_IsSecondWitch = false;
	resuce_start = false;
	g_bVehicleIncoming = false;
	g_bIsTankAlive = false;
	g_iLastTankHealth = 0;
	g_TankOtherDamage = 0;
	bTempBlock = false;
	g_bTankInGame = false;
	g_iLastKnownTank = 0;
	g_iWitchCount = 0;
	control_time = 1;
	ClearTrie(g_hTrine);

	for (new i; i <= MAXPLAYERS; i++){

		for (new elem; elem <= MAXPLAYERS; elem++){

			g_iDamage[i][elem][TANK] = 0;
			g_iDamage[i][elem][WITCH] = 0;
		}

		g_iTotalDamage[i][TANK] = 0;
		g_iTotalDamage[i][WITCH] = 0;
		g_iWitchRef[i] = INVALID_ENT_REFERENCE;
		g_iWitchIndex[i] = 0;
		g_bNoHrCrown[i] = false;
	}
}

public Action:PD_ev_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	control_time = 1;
	if (bTempBlock || !g_iCvarFlags) return;

	bTempBlock = true;
	g_bTankInGame = false;

	decl String:sName[32];

	if (g_iCvarFlags & (1 << _:TANK)){

		new iTank = IsTankInGame();
		if (iTank && !g_iTotalDamage[iTank][TANK]){

			GetClientName(iTank, sName, 32);
			if(g_bIsTankAlive&& IsClientAndInGame(iTank)&& GetClientTeam(iTank) == 3 && IsPlayerTank(iTank) ) 
			{
				CPrintToChatAll("{green}[TS] %t","Tank (player) health remaining", IsFakeClient(iTank) ? "AI" : sName, g_iLastTankHealth);
				g_bIsTankAlive = false;
			}
		}
	}

	for (new i; i <= MaxClients; i++){

		if (g_iTotalDamage[i][TANK]){
			if( g_bIsTankAlive&& IsClientAndInGame(i)&& GetClientTeam(i) == 3 && IsPlayerTank(i) ){
				CPrintToChatAll("{green}[TS] %t","Tank health remaining",  g_iLastTankHealth);
				
				PrintDamage(i, 1, false,0);
			}
		}
		if (g_iTotalDamage[i][WITCH]){

			if (g_bCvarRunAway && g_iWitchRef[i] != INVALID_ENT_REFERENCE && EntRefToEntIndex(g_iWitchRef[i]) == INVALID_ENT_REFERENCE) continue;

			PrintDamage(i, 0, false,5);
		}
	}
	g_iLastTankHealth = 0;
	g_TankOtherDamage = 0;
}
// Tank
public OnClientPutInServer(client)
{
	if (g_bTankInGame && g_iCvarFlags & (1 << _:TANK) && client){

		if (!IsFakeClient(client)){

			decl String:sName[32], String:sIndex[16];
			GetClientName(client, sName, 32);
			IntToString(client, sIndex, 16);
			SetTrieString(g_hTrine, sIndex, sName);
		}
		else
			CreateTimer(0.0, PD_t_CheckIsInf, client);
	}
}

public Action:PD_t_CheckIsInf(Handle:timer, any:client)
{
	if (IsClientInGame(client) && IsFakeClient(client)){

		decl String:sName[32];
		GetClientName(client, sName, 32);

		if (StrContains(sName, "Smoker") != -1 || StrContains(sName, "Boomer") != -1 || StrContains(sName, "Hunter") != -1) return;

		decl String:sIndex[16];
		IntToString(client, sIndex, 16);
		SetTrieString(g_hTrine, sIndex, sName);
	}
}

public Action:PD_ev_TankSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(resuce_start && HasFinalFirstTank() == false)
	{
		resuce_start = false;
		return;
	}

	if(g_bVehicleIncoming && HasEscapeTank() == false)
	{
		resuce_start = false;
		return;
	}

	if (!g_bIsTankAlive)
	{
		g_TankOtherDamage = 0;
		g_bIsTankAlive = true;
		CPrintToChatAll("{default}[{olive}TS{default}] %t","Tank has spawned!");
		EmitSoundToAll("ui/pickup_secret01.wav");
	}
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	control_time = 1;
	if (!g_bTankInGame && g_iCvarFlags & (1 << _:TANK)){

		decl String:sName[32], String:sIndex[16];

		for (new i = 1; i <= MaxClients; i++){

			if (!IsClientInGame(i) || (IsFakeClient(i) && GetClientTeam(i) == 3)) continue;

			IntToString(i, sIndex, 16);
			GetClientName(i, sName, 32);
			SetTrieString(g_hTrine, sIndex, sName);

			#if debug
				LogMessage("push to trine. %s (%s)", sIndex, sName);
			#endif
		}
		g_iLastTankHealth = GetClientHealth(client);
		//LogMessage("g_iLastTankHealth is %d",g_iLastTankHealth);
	}

	g_bTankInGame = true;
}

public Action:PD_ev_PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (bTempBlock || !(g_iCvarFlags & (1 << _:TANK))||!g_bIsTankAlive) return;
	
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

	if (IsClientAndInGame(victim) && IsClientAndInGame(attacker) && GetClientTeam(attacker) == 2  && GetClientTeam(victim) == 3){

		if (!IsPlayerTank(victim) || g_iTotalDamage[victim][TANK] == g_iCvarHealth[TANK]) return;
		
		if (g_iLastKnownTank)
			CloneStats(victim,g_iLastKnownTank);
			
		new iDamage = GetEventInt(event, "dmg_health");
		g_iLastTankHealth = GetEventInt(event,"health");

		g_iDamage[attacker][victim][TANK] += iDamage;
		g_iTotalDamage[victim][TANK] += iDamage;
		
		#if debug
			LogMessage("#1. total %d dmg %d (%N, health %d)", g_iTotalDamage[victim][TANK], iDamage, victim, GetEventInt(event, "health"));
		#endif

		CorrectDmg(attacker, victim, 1);
			
		new type = GetEventInt(event,"type");
		if(type == 131072) g_iLastTankHealth = 0 ;
		return;
	}
	if(IsClientAndInGame(victim)&& GetClientTeam(victim) == 3&&IsPlayerTank(victim))
	{
		new iDamage = GetEventInt(event, "dmg_health");
		new type = GetEventInt(event,"type");
		if(  iDamage<=10 && type != 8 && type != 268435464 ) return;//GetEventInt(event,"type")= 8 被火傷到 268435464:著火 131072:死亡動畫時	iDamage<=10為不明傷害
		if(type == 131072){g_iLastTankHealth = 0 ;return;}
		g_TankOtherDamage += iDamage;
		g_iLastTankHealth = GetEventInt(event,"health");
		if (g_iTotalDamage[victim][1] + g_TankOtherDamage > g_iCvarHealth[1]){
			new iDiff = g_iTotalDamage[victim][1] + g_TankOtherDamage - g_iCvarHealth[1];
			g_TankOtherDamage -= iDiff;
		}
	}
}

CloneStats(client,previoustankclient)
{
	if (client && client != previoustankclient){

		#if debug
			LogMessage("clone tank stats %N -> %N", previoustankclient, client);
		#endif

		for (new i; i <= MaxClients; i++){

			if (g_iDamage[i][previoustankclient][TANK]){

				g_iDamage[i][client][TANK] = g_iDamage[i][previoustankclient][TANK];
				g_iDamage[i][previoustankclient][TANK] = 0;
			}
		}

		g_iTotalDamage[client][TANK] = g_iTotalDamage[previoustankclient][TANK];
		g_iTotalDamage[previoustankclient][TANK] = 0;
	}
	#if debug
	else
		LogMessage("don't clone tank stats %N -> %N", previoustankclient, client);
	#endif

	g_iLastKnownTank = 0;
}

public Action:PD_ev_EntityKilled(Handle:event, const String:name[], bool:dontBroadcast)
{
	decl client;
	if (!bTempBlock && g_bTankInGame && g_iCvarFlags & (1 << _:TANK) && IsPlayerTank((client = GetEventInt(event, "entindex_killed"))))
	{
		if (g_iTotalDamage[client][TANK])
		{
			CreateTimer(0.1, PD_t_FindAnyTank2, client, TIMER_FLAG_NO_MAPCHANGE);
		}
		else
		{
			CreateTimer(1.5, PD_t_FindAnyTank, _, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public Action:PD_t_FindAnyTank2(Handle:timer, any:client)
{
	if(!IsTankInGame())
	{
		if(g_bIsTankAlive){
			PrintDamage(client, 1);
			g_bIsTankAlive = false;
			g_TankOtherDamage = 0;
			g_bTankInGame = false;
		}
	}
}

public Action:PD_t_FindAnyTank(Handle:timer, any:client)
{
	if(!IsTankInGame())
	{
		g_bIsTankAlive = false;
		g_TankOtherDamage = 0;
		g_bTankInGame = false;
	}
}

IsTankInGame(exclude = 0)
{
	for (new i = 1; i <= MaxClients; i++)
		if (exclude != i && IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerTank(i) && IsPlayerAlive(i) && !IsIncapacitated(i))
			return i;

	return 0;
}

public Action:PD_ev_PlayerBotReplace(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (bTempBlock || g_bCvarSurvLimit==1 || !(g_iCvarFlags & (1 << _:TANK))) return;

	// tank leave?
	new bot = GetClientOfUserId(GetEventInt(event, "bot"));
	new player = GetClientOfUserId(GetEventInt(event, "player"));
	
	if (StrEqual(name, "player_bot_replace")) // fake client takes over bot
	{
		if(IsClientInGame(bot) && IsFakeClient(bot) && GetClientTeam(bot) == 3 && IsPlayerTank(bot) && g_iTotalDamage[player][TANK])
		{
			CloneStats(bot,player);
		}
	}
}


public Action:PD_ev_TankFrustrated(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (bTempBlock || !(g_iCvarFlags & (1 << _:TANK))) return;

	#if debug
		LogMessage("TankFrustrated fired (pass time %f sec)", TANK_PASS_TIME);
	#endif

	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsClientInGame(client)) return;

	if (g_bCvarSurvLimit!=1){
		if(rotoblin_enable_2v2 != null && rotoblin_enable_2v2.IntValue==1)//rotoblin_enable_2v2=1為AI會被處死
		{
			CreateTimer(1.0, CheckForAITank, client, TIMER_FLAG_NO_MAPCHANGE);
		}

		g_iLastKnownTank = client;
		if(control_time == 2)
		{
			control_time=1;
			return;
		}
		control_time++;
		return;
	}

	// 1v1
	CreateTimer(1.0,CheckForAITank,client);
}

public Action:CheckForAITank(Handle:timer,any:client)//passing to AI
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsValidEdict(i)&&IsPlayerTank(i))
		{
			if (IsInfected(client)&&IsFakeClient(i))//Tank is AI
			{
				g_bTankInGame = false;
					
				CPrintToChatAll("{green}[TS] Tank ({red}%N{default}) %t", client,"Tank got lost and lost control.");
				CPrintToChatAll("{green}[TS] %t","l4d_tank_witch_damage_announce_spawnAnnouncer1", g_iLastTankHealth);
	
				if (g_iTotalDamage[client][TANK])//人類沒有造成任何傷害就不印
					PrintDamage(client, 1, false);
				g_bIsTankAlive = false;
				g_TankOtherDamage = 0;
			}
			return Plugin_Handled;
		}
	}
	return Plugin_Handled;
}

// Witch
public Action:PD_ev_WitchSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(b_IsSecondWitch == false) CPrintToChatAll("[{olive}TS{default}] %t","Witch has spawned!");
	CreateTimer(0.5, PD_t_EnumThisWitch, EntIndexToEntRef(GetEventInt(event, "witchid")), TIMER_FLAG_NO_MAPCHANGE);
	b_IsSecondWitch = true;
}

public Action:PD_t_EnumThisWitch(Handle:timer, any:entity)
{
	new ref = entity;
	if ((entity = EntRefToEntIndex(entity)) != INVALID_ENT_REFERENCE && g_iWitchCount < MAXPLAYERS){

		g_iWitchRef[g_iWitchCount] = ref;

		decl String:sWitchName[8];
		FormatEx(sWitchName, 8, "%d", g_iWitchCount++);
		DispatchKeyValue(entity, "targetname", sWitchName);
	}
}

public Action:PD_ev_InfectedHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (bTempBlock || !(g_iCvarFlags & (1 << _:WITCH))) return;

	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

	decl iWitchEnt;
	if (IsWitch((iWitchEnt = GetEventInt(event, "entityid"))) && IsClientAndInGame(attacker) && GetClientTeam(attacker) == 2){

		new iIndex = GetWitchIndex(iWitchEnt);
		if (iIndex == NULL) return;

		if (!g_bNoHrCrown[iIndex] && GetEventInt(event, "amount") != 90)
			g_bNoHrCrown[iIndex] = true;

		if (g_iTotalDamage[iIndex][WITCH] == g_iCvarHealth[WITCH]) return;

		new iDamage = GetEventInt(event, "amount");

		g_iDamage[attacker][iIndex][WITCH] += iDamage;
		g_iTotalDamage[iIndex][WITCH] += iDamage;

		#if debug
			LogMessage("%d (Witch: indx %d, elem %d)", g_iTotalDamage[iIndex][WITCH], iWitchEnt, iIndex);
		#endif

		CorrectDmg(attacker, iIndex, 0);
	}
}

GetWitchIndex(entity)
{
	decl String:sWitchName[8];
	GetEntPropString(entity, Prop_Data, "m_iName", sWitchName, 8);
	if (strlen(sWitchName) != 1) return -1;

	return StringToInt(sWitchName);
}
// ---

CorrectDmg(attacker, iIndex, int TankorWitch)
{
	if (g_iTotalDamage[iIndex][TankorWitch] + g_TankOtherDamage> g_iCvarHealth[TankorWitch]){
		new iDiff = g_iTotalDamage[iIndex][TankorWitch] + g_TankOtherDamage - g_iCvarHealth[TankorWitch];

		#if debug
			LogMessage("dmg corrected %d. total dmg %d", iDiff, g_iTotalDamage[iIndex][bTankBoss]);
		#endif

		g_iDamage[attacker][iIndex][TankorWitch] -= iDiff;
		g_iTotalDamage[iIndex][TankorWitch] -= iDiff;
	}
}

public Action:PD_ev_WitchKilled(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!(g_iCvarFlags & (1 << _:WITCH))) return;

	new iIndex = GetWitchIndex(GetEventInt(event, "witchid"));
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (iIndex == NULL || !g_iTotalDamage[iIndex][WITCH]) return;

	PrintDamage(iIndex, 0, _, GetEventInt(event, "oneshot"), client);
	g_bNoHrCrown[iIndex] = false;
}

void PrintDamage(int iIndex, int TankorWitch, bool bLoose = false, int iCrownTech = 0, int killer = 0)
{
	decl String:tankplayerName[32];
	new bool:istankAI = false;
	if(TankorWitch == _:TANK)
	{
		GetClientName(iIndex,tankplayerName, 32);
		if(StrEqual(tankplayerName,"Tank"))
			istankAI =true;
	}
	
	decl iClient[MAXPLAYERS+1][BOSSES];
	new iSurvivors;
		
	for (new i = 1; i <= MaxClients; i++){

		if (!g_iDamage[i][iIndex][TankorWitch]) continue;

		if (TankorWitch == _:WITCH && IsClientInGame(i) || TankorWitch == _:TANK){

			if ((g_bCvarSkipBots && IsClientInGame(i) && !IsFakeClient(i)) || !g_bCvarSkipBots){

				iClient[iSurvivors][INDEX] = i;
				iClient[iSurvivors][DMG] = g_iDamage[i][iIndex][TankorWitch];
				iSurvivors++;
			}
		}
		// reset var
		g_iDamage[i][iIndex][TankorWitch] = 0;
	}
	if (!iSurvivors) return;

	if (iSurvivors == 1 && !bLoose){
	
		decl String:sName[48];
		new client = iClient[0][INDEX],bool:bInGame;
		if ((bInGame = IsSurvivor(client)))
			GetClientName(client, sName, 48);
		else {

			IntToString(client, sName, 48);

			if (GetTrieString(g_hTrine, sName, sName, 48))
				Format(sName, 48, "%s (left the team)", sName);
			else
				sName = "unknown";
		}

		if (TankorWitch == _:TANK){
			CPrintToChatAll("{default}[{olive}TS{default}] {blue}%s {default}%t", sName,"l4d_tank_witch_damage_announce_spawnAnnouncer2",iClient[0][DMG]);
			g_bIsTankAlive = false;
		}
		else
		{
			if(killer && IsClientInGame(killer) && GetClientTeam(killer) == 2)
			{
				if( iCrownTech==1)
					CPrintToChatAll("{default}[{olive}TS{default}] %t","l4d_tank_witch_damage_announce_spawnAnnouncer3", sName);	
				else if (!iCrownTech && bInGame)
				{
					new gun = GetPlayerWeaponSlot(client, 0); //get the players primary weapon
					if (!IsValidEdict(gun)) return; //check for validity
					
					decl String:currentgunname[64];
					GetEdictClassname(gun, currentgunname, sizeof(currentgunname)); //get the primary weapon name
			
					if (StrEqual(currentgunname, "weapon_pumpshotgun")&&!IsIncapacitated(client))
						CPrintToChatAll("{default}[{olive}TS{default}] %t","l4d_tank_witch_damage_announce_spawnAnnouncer4", sName);	
				}
			}
		}
	}
	else {

		new Float:fTotalDamage = float(g_iCvarHealth[TankorWitch]);

		SortCustom2D(iClient, iSurvivors, SortFuncByDamageDesc);
		
		if (!bLoose && !(g_iCvarPrivateFlags & (1 << (TankorWitch == _:TANK ? 1 : 0))))
			if(TankorWitch == _:TANK){
				CPrintToChatAll("{olive}[TS] %t","Damage dealt to Tank", ( istankAI ? "AI":tankplayerName));
				g_bIsTankAlive = false;
			}
			else
				CPrintToChatAll("{olive}[TS] %t","Damage dealt to Witch");

		if (TankorWitch == _:TANK){

			decl String:sName[48], client, bool:bInGame;

			for (new i; i < iSurvivors; i++){

				client = iClient[i][INDEX];

				if ((bInGame = IsSurvivor(client)))
					GetClientName(client, sName, 48);
				else {

					IntToString(client, sName, 48);

					if (GetTrieString(g_hTrine, sName, sName, 48))
						Format(sName, 48, "%s (left the team)", sName);
					else
						sName = "unknown";
				}
					// private
				if (g_iCvarPrivateFlags & (1 << _:TANK)){

					if (bInGame)
						CPrintToChat(client, "{olive}[TS] %T","l4d_tank_witch_damage_announce_spawnAnnouncer5",client, g_iTotalDamage[iIndex][TankorWitch], iClient[i][DMG], RoundToNearest((float(iClient[i][DMG]) / fTotalDamage) * 100.0));
				}
				else{ // public
					CPrintToChatAll(" {olive}%d{default} [{green}%.0f%%{default}] - {blue}%s", iClient[i][DMG], (float(iClient[i][DMG]) / fTotalDamage) * 100.0,sName);
				}
			}
			if (!(g_iCvarPrivateFlags & (1 << _:TANK))&&g_TankOtherDamage){
				CPrintToChatAll(" {olive}%d{default} [{green}%.0f%%{default}] - {lightgreen}%t",g_TankOtherDamage, (float(g_TankOtherDamage) / fTotalDamage) * 100.0,"Other damage");
				g_TankOtherDamage = 0;
			}
		}
		else 
		{
			for (new i; i < iSurvivors; i++){
				if (g_iCvarPrivateFlags & (1 << _:WITCH))
				{
					CPrintToChat(iClient[i][INDEX], "{olive}[TS] %T","l4d_tank_witch_damage_announce_spawnAnnouncer6", iClient[i][INDEX],g_iTotalDamage[iIndex][TankorWitch], i + 1, iClient[i][DMG], RoundToNearest((float(iClient[i][DMG]) / fTotalDamage) * 100.0));
				}
				else
				{
					CPrintToChatAll(" {olive}%d{default} [{green}%.0f%%{default}] - {blue}%N", iClient[i][DMG], (float(iClient[i][DMG]) / fTotalDamage) * 100.0,iClient[i][INDEX]);
				}
			}
		}
	}

	// reset var
	g_iTotalDamage[iIndex][TankorWitch] = 0;
}

public SortFuncByDamageDesc(x[], y[], const array[][], Handle:hndl)
{
	if (x[1] < y[1])
		return 1;
	else if (x[1] == y[1])
		return 0;

	return NULL;
}

Float:GetCoopMultiplie()
{
	decl String:sDifficulty[24];
	GetConVarString(g_hDifficulty, sDifficulty, 24);

	if (StrEqual(sDifficulty, "Easy"))
		return 0.75;
	else if (StrEqual(sDifficulty, "Normal"))
		return 1.0;

	return 2.0;
}

bool:IsVersusGameMode()
{
	decl String:sGameMode[12];
	GetConVarString(g_hGameMode, sGameMode, 12);
	return StrEqual(sGameMode, "versus");
}

public OnConvarChange_TankHealth(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (!StrEqual(oldValue, newValue))
		g_iCvarHealth[TANK] = RoundFloat(GetConVarFloat(g_hTankHealth) * (IsVersusGameMode() ? GetConVarFloat(g_hVsBonusHealth) : GetCoopMultiplie()));
}

public OnConvarChange_WitchHealth(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (!StrEqual(oldValue, newValue))
		g_iCvarHealth[WITCH] = GetConVarInt(convar);
}

public OnConvarChange_SkipBots(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (!StrEqual(oldValue, newValue))
		g_bCvarSkipBots = GetConVarBool(convar);
}

public OnConvarChange_SurvLimit(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (!StrEqual(oldValue, newValue))
		g_bCvarSurvLimit = GetConVarInt(convar);
}

public OnConvarChange_Flags(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (!StrEqual(oldValue, newValue))
		g_iCvarFlags = GetConVarInt(convar);
}

public OnConvarChange_Private(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (!StrEqual(oldValue, newValue))
		g_iCvarPrivateFlags = GetConVarInt(convar);
}

public OnConvarChange_RunAway(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (!StrEqual(oldValue, newValue))
		g_bCvarRunAway = GetConVarBool(convar);
}

public Action:PD_ev_Finale_Start(Handle:event, const String:name[], bool:dontBroadcast)
{
	resuce_start = true;
}

public void PD_ev_FinaleEscStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_bVehicleIncoming = true;
}