
// Force strict semicolon mode
#pragma semicolon 1

/**
 * Includes
 *
 */
#include <sourcemod>
#include <sdktools>

/**
 * Defines
 *
 */
#define PLUGIN_VERSION	"1.0.0"
#define CVAR_FLAGS			FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY
#define CVAR_FLAGS_NO		FCVAR_PLUGIN|FCVAR_SPONLY
#define MAXENTITIES 2048

#define IS_VALID_CLIENT(%1) (%1 > 0 && %1 <= MaxClients)
#define IS_CONNECTED_INGAME(%1) (IsClientConnected(%1) && IsClientInGame(%1))
#define IS_SURVIVOR(%1) (GetClientTeam(%1) == 2)
#define IS_INFECTED(%1) (GetClientTeam(%1) == 3)

#define IS_VALID_INGAME(%1) (IS_VALID_CLIENT(%1) && IS_CONNECTED_INGAME(%1))

#define IS_VALID_SURVIVOR(%1) (IS_VALID_INGAME(%1) && IS_SURVIVOR(%1))
#define IS_VALID_INFECTED(%1) (IS_VALID_INGAME(%1) && IS_INFECTED(%1))

#define IS_SURVIVOR_ALIVE(%1) (IS_VALID_SURVIVOR(%1) && IsPlayerAlive(%1))
#define IS_INFECTED_ALIVE(%1) (IS_VALID_INFECTED(%1) && IsPlayerAlive(%1))

#define IS_SURVIVOR_DEAD(%1) (IS_VALID_SURVIVOR(%1) && !IsPlayerAlive(%1))
#define IS_INFECTED_DEAD(%1) (IS_VALID_INFECTED(%1) && !IsPlayerAlive(%1))

#define		BILL		0
#define		ZOEY		1
#define		FRANCIS		2
#define		LOUIS		3
#define		SURVIVOR	4 //ExtraCharacterHide



#define MODEL_BILL "models/survivors/survivor_namvet.mdl"
#define MODEL_ZOEY "models/survivors/survivor_teenangst.mdl"
#define MODEL_FRANCIS "models/survivors/survivor_biker.mdl"
#define MODEL_LOUIS "models/survivors/survivor_manager.mdl"

#define FIRE 268435464
#define BOOM 64

static String:SurvivorModel[][] =  {
	MODEL_BILL, 
	MODEL_ZOEY, 
	MODEL_FRANCIS, 
	MODEL_LOUIS
};

static String:SurvivorName[][] =  {
	"Bill", 
	"Zoey", 
	"Francis", 
	"Louis"
	//"Survivor"//XtraPerson
};

/**
 * Handles
 *
 */



new Handle:l4d_witch_fix_enable;
new Handle:l4d_witch_fix_mode;
new Handle:l4d_witch_fix_announce;
new Handle:l4d_witch_fix_announce_type;
new Handle:l4d_witch_fix_announces_message;
new Handle:l4d_witch_fix_announces_message_all;
//new Handle:l4d_witch_fix_changetarget;

/**
 * Global variables
 *
 */





static rager = 0;
//Witch Vars
new RagerWitch[MAXENTITIES + 1];
new RagerWitchPerson[MAXENTITIES + 1];
new RageMode[MAXENTITIES + 1];

// surivors vars
//new SurvivorPlayer[MAXPLAYERS+1];
//new SurvivorPlayerModel[MAXPLAYERS+1];

//new bool:IsRages;
//new bool:IsFakeRage;



//new Handle:RageWitches[MAXPLAYERS+1];
/**
 * Plugin information
 *
 */
public Plugin:myinfo = 
{
	name = "[L4D] Witch Target Fix", 
	author = "zK", 
	description = "Fix temporaly the real target of Witch", 
	version = PLUGIN_VERSION, 
	url = "<- URL ->"
};

/**
 * Setup plugins first run
 *
 */
public OnPluginStart()
{
	// Require Left 4 Dead
	decl String:game_name[64];
	GetGameFolderName(game_name, sizeof(game_name));
	if (!StrEqual(game_name, "left4dead"))
	{
		SetFailState("Use this in Left 4 Dead only.");
	}
	// Create convars
	CreateConVar("l4d_witch_fix_version", PLUGIN_VERSION, "plugin Version", FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_NOTIFY | FCVAR_DONTRECORD);
	l4d_witch_fix_enable = CreateConVar("l4d_witch_fix_enable", "1", "Enable or disable plugin.", CVAR_FLAGS, true, 0.0, true, 1.0);
	l4d_witch_fix_announce = CreateConVar("l4d_witch_fix_announce", "0", "1: Enable all player announcement of Witch Rager, -1: Only player target announcements, 0: Disable ", CVAR_FLAGS, true, -1.0, true, 1.0);
	l4d_witch_fix_announce_type = CreateConVar("l4d_witch_fix_announce_type", "3", "1:ChatText, 2:CenterText, 3,HintText", CVAR_FLAGS, true, -321.0, true, 321.0);
	l4d_witch_fix_announces_message = CreateConVar("l4d_witch_fix_announces_message", " startled the Witch!", "Set alert message for player target of Witch", CVAR_FLAGS);
	l4d_witch_fix_announces_message_all = CreateConVar("l4d_witch_fix_announces_message_all", ", startled the Witch!", "Set alert message for all players", CVAR_FLAGS);
	l4d_witch_fix_mode = CreateConVar("l4d_witch_fix_mode", "0", "Set Fix Type Mode, 1:Enable change model survivor 0: Only Person character (no change model) ", CVAR_FLAGS, true, 0.0, true, 1.0);
	
	AutoExecConfig(true, "l4d_witch_fix_target");
	
	
	// Hook events
	HookEvent("round_start", Round_Reset);
	HookEvent("round_end", Round_Reset);
	HookEvent("witch_harasser_set", Event_WitchRage, EventHookMode_Pre);
	//HookEvent("witch_harasser_set",	Event_WitchHarasserSet); 
	HookEvent("witch_spawn", Event_WitchSpawn);
	HookEvent("witch_killed", Event_WitchKilled);
	HookEvent("infected_hurt", Event_RagerWitch);
	HookEvent("entity_shoved", Event_RagerWitch);
	HookEvent("zombie_ignited", Event_WitchFire);
	HookEvent("player_death", Event_PlayerDead);
	HookEvent("player_spawn", Event_PlayerTeam);
	HookEvent("map_transition", Event_MapNext, EventHookMode_Pre);
	//HookEvent("player_bot_replace",	Event_PlayerRemplace);
	//HookEvent("bot_player_replace",	Event_PlayerRemplace);
	
}

public OnMapStart()
{
	ResetConVars();
	ResetTargets();
	
}

public Round_Reset(Handle:event, const String:name[], bool:dontBroadcast)
{
	ResetTargets();
}

public Event_WitchSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new witch_id = GetEventInt(event, "witchid");
	if (IsWitch(witch_id)) {
		RagerWitch[witch_id] = 0;
		RagerWitchPerson[witch_id] = -1;
		RageMode[witch_id] = 0;
	}
	//if(!IsRages)
	//SaveSurvivorPlayers();
}

/**
 * Handles when a witch is killed
 *
 * @handle: event - The witch_killed event
 * @string: name - Name of the event
 * @bool: dontBroadcast - Enable/disable broadcasting of event triggering
 *
 */
public Event_WitchKilled(Handle:event, const String:name[], bool:dontBroadcast)
{
	// Get event information
	//new attacker 		= GetClientOfUserId(GetEventInt(event, "userid"));
	new witch_id = GetEventInt(event, "witchid");
	//new bool: crowned	= GetEventBool(event, "oneshot");
	RagerWitch[witch_id] = 0;
	RagerWitchPerson[witch_id] = -1;
	RageMode[witch_id] = 0;
	//ResetConVars();
}

/*

public Event_WitchHarasserSet(Handle: event, const String: name[], bool: dontBroadcast)
{
	
	// if(!GetConVarBool(l4d_witch_fix_enable))
	// return;

	new attacker_id	= GetEventInt(event, "userid");
	new witch_id		= GetEventInt(event, "witchid");

	new attacker 		= GetClientOfUserId(attacker_id);

	//PrintToChatAll("%N !!!!!!!",GetWitchTarget(witch_id));
	
}
*/



AlertRagerWitch(client, witch_id = 0) {
	
	if (GetConVarInt(l4d_witch_fix_announce) != 0 && IS_VALID_SURVIVOR(client))
	{
		decl String:attacker_name[64];
		decl String:msg_attacker[64];
		decl String:msg_all[64];
		decl String:announce_type[16];
		GetClientName(client, attacker_name, sizeof(attacker_name));
		GetConVarString(l4d_witch_fix_announces_message, msg_attacker, sizeof(msg_attacker));
		GetConVarString(l4d_witch_fix_announces_message_all, msg_all, sizeof(msg_all));
		
		new a_type = GetConVarInt(l4d_witch_fix_announce_type);
		FormatEx(announce_type, sizeof(announce_type), "%i", a_type);
		
		if (GetConVarInt(l4d_witch_fix_announce) == 1)
		{
			if (StrContains(announce_type, "1") != -1)PrintToChatAll("%s%s", attacker_name, msg_all);
			if (StrContains(announce_type, "2") != -1) { PrintCenterTextAll("%s%s", attacker_name, msg_all); PrintCenterText(client, "%s%s", attacker_name, msg_attacker); }
			if (StrContains(announce_type, "3") != -1) { PrintHintTextToAll("%s%s", attacker_name, msg_all); PrintHintText(client, "%s%s", attacker_name, msg_attacker); }
			
		}
		else {
			if (StrContains(announce_type, "1") != -1)PrintToChat(client, "%s%s", attacker_name, msg_attacker);
			if (StrContains(announce_type, "2") != -1)PrintCenterText(client, "%s%s", attacker_name, msg_attacker);
			if (StrContains(announce_type, "3") != -1)PrintHintText(client, "%s%s", attacker_name, msg_attacker);
		}
		
	}
	//Fake event rage witch
	
	//PrintToChatAll("W:::::::::::%i",witch_id);
	new Handle:event = CreateEvent("witch_harasser_set");
	/*
	event.SetInt("userid", GetClientUserId(client));
	event.SetInt("witchid", witch_id);
	event.Fire(); 
	*/
	SetEventInt(event, "userid", GetClientUserId(client));
	SetEventInt(event, "witchid", witch_id);
	FireEvent(event);
}



//reset target id witchs kick
/*
public OnEntityDestroyed(entity)
{
	if(IsWitch(entity))
	RagerWitch[entity] =0;
} 
*/

public Event_WitchFire(Handle:event, const String:name[], bool:dontBroadcast)
{
	
	if (!GetConVarBool(l4d_witch_fix_enable))
		return;
	// Get event information
	new attacker = GetClientOfUserId(GetEventInt(event, "userid"));
	new witch_id = GetEventInt(event, "entityid");
	if (IS_VALID_SURVIVOR(attacker) && IsWitch(witch_id) && RageMode[witch_id] <= 1)
	{
		RagerWitch[witch_id] = attacker;
		RageMode[witch_id] = 2;
		FixAttackTarget(attacker);
		AlertRagerWitch(attacker);
		//AlertRagerWitch(attacker,witch_id);
		//PrintToChatAll("RAGER Fx: %i -->%d! ",attacker, witch_id );
	}
	
}


public Event_RagerWitch(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!GetConVarBool(l4d_witch_fix_enable))
		return;
	
	new witch_id = GetEventInt(event, "entityid");
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	//new damagetype = GetEventInt(event, "type");
	
	//if(IsWitch(witch_id) && IsWitchRage(witch_id) && RagerWitch[witch_id] > 0 && damagetype!= FIRE && damagetype!= BOOM)
	if (IsWitch(witch_id) && IsWitchRage(witch_id) && RagerWitch[witch_id] > 0)
		return;
	
	if (IsWitch(witch_id) && IS_VALID_SURVIVOR(attacker)) //guns and fire /
	{
		RagerWitch[witch_id] = attacker;
		//SetWitchTarget(witch_id,attacker); //testear bugs
		//RagerWitchPerson[witch_id]=GetSurvivor(attacker);
		//PrintToChatAll("RAGER: %i %d! ,RageLevel: %i",attacker, damagetype ,RageMode[witch_id]);
	}
	
	
}

public Event_WitchRage(Handle:event, const String:name[], bool:dontBroadcast) //agregar timer para guardar personajes.agregar cvar para desactivar temporaly !csm y cerrar el menu si ya staba open
{
	if (!GetConVarBool(l4d_witch_fix_enable))
		return;
	
	new witch_id = GetEventInt(event, "witchid");
	new witch_target = GetClientOfUserId(GetEventInt(event, "userid")); //fake target
	
	if (witch_id == 0)
		return;
	
	if (!IS_VALID_SURVIVOR(witch_target))
		return;
	RagerWitchPerson[witch_id] = GetSurvivor(witch_target);
	new person = GetSurvivor(witch_target);
	
	
	
	if (RagerWitch[witch_id] == 0 || RageMode[witch_id] > 0) //testear bugs cn ragemode
		SetEventInt(event, "userid", 0);
	else if (witch_target != RagerWitch[witch_id]) //set real target annonce hud! fixear con secon rage por fire
		SetEventInt(event, "userid", GetClientUserId(RagerWitch[witch_id]));
	
	if (RagerWitch[witch_id] == 0)
	{
		witch_target = GetWitchTarget(witch_id);
		new Handle:pack;
		CreateDataTimer(0.1, WitchRage, pack);
		WritePackCell(pack, witch_id);
		WritePackCell(pack, witch_target);
		WritePackCell(pack, person);
		//pack.WriteCell(witch_id);
		//pack.WriteCell(witch_target);
	}
	else if (RageMode[witch_id] == 0) //detect second rage by fire
	{
		if (person != GetSurvivor(RagerWitch[witch_id]))
			SetSurvivor(RagerWitch[witch_id], person);
		WitchOnRage(witch_id, witch_target, person);
	}
	return;
	
}

WitchOnRage(witch_id, witch_target, person) //testar cn m_clientTarget 
{
	if (RageMode[witch_id] > 0)
		return;
	
	new target;
	if (witch_target == RagerWitch[witch_id]) //Verificacion de Rager(Attacker) Witch 
		target = RagerWitch[witch_id]; //testear para fixear cn evil witch
	else if (RagerWitch[witch_id] > 0) // probar cn fixtarget para la evil witch
		target = RagerWitch[witch_id];
	FixAttackTarget(target, person);
	//PrintToChatAll("%d !!!!!!!!!W", witch_id);
	rager++;
	RageMode[witch_id]++;
	AlertRagerWitch(target);
	//AlertRagerWitch(target,witch_id);
	
}

public Action:WitchRage(Handle:timer, Handle:pack)
{
	
	
	ResetPack(pack);
	new witch_id = ReadPackCell(pack);
	new witch_target = ReadPackCell(pack);
	new person = ReadPackCell(pack);
	
	if (RageMode[witch_id] > 0 && RagerWitch[witch_id] > 0)
		return;
	
	
	//Verificacion de Asustador Witch
	//new person = GetSurvivor(witch_target);
	//new person = RagerWitchPerson[witch_id]
	new target;
	target = witch_target;
	if (target <= 0)
		target = FindRealTarget(witch_id, person);
	
	RagerWitch[witch_id] = target; //-
	
	FixAttackTarget(target, person);
	
	//PrintToChatAll("%d !!!!!!!!!W", witch_id);
	rager++;
	RageMode[witch_id]++;
	AlertRagerWitch(target);
	//AlertRagerWitch(target,witch_id);
	
}

public Event_PlayerDead(Handle:event, const String:name[], bool:dontBroadcast)
{
	new player = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IS_VALID_SURVIVOR(player)) //Fix witch confuse by player dead
		CreateTimer(0.5, FixTargetDead, player);
	
}

public Event_PlayerTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	new player = GetClientOfUserId(GetEventInt(event, "userid"));
	
	//PrintToChatAll("%N __________",player);
	if (IS_VALID_SURVIVOR(player)) //Fix witch confuse by player dead
		CreateTimer(0.5, FixTargetDead, player);
	
}

/*

public Event_PlayerRemplace(Handle: event, const String: name[], bool: dontBroadcast)
{
	
	 new player = GetClientOfUserId(GetEventInt(event, "player"));
	new bot = GetClientOfUserId(GetEventInt(event, "bot"));
	if(IS_VALID_SURVIVOR(player) )//Fix witch confuse by player dead
	CreateTimer(0.1,FixTargetDead,player);
	if(IS_VALID_SURVIVOR(bot) )//Fix witch confuse by player dead
	CreateTimer(0.1,FixTargetDead,bot); 

}
*/

public Event_MapNext(Handle:event, const String:name[], bool:dontBroadcast)
{
	FixCrashModel();
}

public Action:FixTargetDead(Handle:timer, any:id)
{
	if (IS_SURVIVOR_DEAD(id))
		SetSurvivor(id, SURVIVOR);
}

FixCrashModel()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IS_VALID_SURVIVOR(i) && GetSurvivor(i) == SURVIVOR)
		{
			SetSurvivor(i, GetRandomInt(0, 3));
		}
	}
}

FindRealTarget(witch, person) //testar cn m_clientTarget 
{
	
	new Float:witchPos[3];
	GetEntPropVector(witch, Prop_Send, "m_vecOrigin", witchPos);
	new Float:minDis;
	new selectedPlayer = 0;
	decl Float:playerPos[3];
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && GetSurvivor(i) == person)
		{
			GetClientAbsOrigin(i, playerPos);
			new Float:dis = GetVectorDistance(playerPos, witchPos);
			if (dis <= minDis || i == 1)
			{
				selectedPlayer = i;
				minDis = dis;
			}
		}
	}
	//PrintToChatAll("%d !))))))))",selectedPlayer);
	return selectedPlayer;
	
}

FixAttackTarget(client, ragerperson = -1) // 
{
	new bool:Mode = GetConVarBool(l4d_witch_fix_mode);
	if (ragerperson < 0)
		ragerperson = GetEntProp(client, Prop_Send, "m_survivorCharacter");
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IS_SURVIVOR_ALIVE(i) && i != client && GetSurvivor(i) == ragerperson)
		{
			if ((ragerperson) < LOUIS)
				SetSurvivor(i, (ragerperson + 1), Mode);
			else
				SetSurvivor(i, BILL, Mode);
		}
		else if (IS_VALID_SURVIVOR(i) && !IsPlayerAlive(i) && i != client) //FixPlayersDEADS
		{
			SetSurvivor(i, SURVIVOR);
		}
	}
}

IsWitch(witch, bool:alive = false)
{
	if (witch > 0 && IsValidEdict(witch) && IsValidEntity(witch))
	{
		decl String:classname[32];
		GetEdictClassname(witch, classname, sizeof(classname));
		if (StrEqual(classname, "witch"))
		{
			if (alive)
			{
			}
			return true;
		}
	}
	return false;
}

bool:IsWitchRage(id) {
	if (GetEntPropFloat(id, Prop_Send, "m_rage") < 1.0)
		return false;
	else return true;
}
/*
SaveSurvivorPlayers()
{
	
	for(new i=1; i<=MaxClients; i++)
	{
		if(IS_SURVIVOR_ALIVE(i))
		{
			SurvivorPlayer[i]=GetSurvivor(i);
		}
	}
}

LoadSurvivorPlayers()
{
	//agregar cvar cargar person cn model
	new bool:Mode=GetConVarBool(l4d_witch_fix_mode);
	for(new i=1; i<=MaxClients; i++)
	{
		if(IS_SURVIVOR_ALIVE(i))
		{
			SetSurvivor(i,SurvivorPlayer[i],Mode);
		}
	}
}
*/

SetSurvivor(client, person, bool:setmodel = false)
{
	SetEntProp(client, Prop_Send, "m_survivorCharacter", person);
	if (person < SURVIVOR)
	{
		if (setmodel)SetEntityModel(client, SurvivorModel[person]);
		if (IsFakeClient(client))
		{
			SetClientInfo(client, "name", SurvivorName[person]);
		}
	}
}

GetSurvivor(client) {
	return GetEntProp(client, Prop_Send, "m_survivorCharacter");
}
/*
GetSurvivorModel(client){
	return GetEntProp(client, Prop_Send, "m_survivorCharacter");
}
*/


GetWitchTarget(id) {
	
	new witch_id = EntRefToEntIndex(id);
	if (0 > witch_id > 2048 || !IsValidEntity(witch_id)) // 2048 is the highest entity number a common can be assigned to in L4D & L4D2
	{
		return 0;
	}
	
	if (!IsWitch(witch_id))
		return 0;
	
	//new targetInt = GetEntProp(witch_id, Prop_Send, "m_clientLookatTarget");
	new target = GetEntPropEnt(witch_id, Prop_Send, "m_clientLookatTarget");
	if (IS_VALID_SURVIVOR(target)) {
		//PrintToChatAll("!!!!!!!!!!!!");
		return target;
	}
	
	else return 0;
	
}

/**
 * Resets any changed convars
 *
 */

ResetTargets() {
	
	for (new i; i < sizeof(RagerWitch); i++)
	{
		RagerWitch[i] = 0;
		RagerWitchPerson[i] = -1;
		RageMode[i] = 0;
	}
	
}

ResetConVars()
{
	ResetConVar(l4d_witch_fix_enable);
	ResetConVar(l4d_witch_fix_announce);
	
} 