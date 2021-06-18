/* ========================================================
 * L4D SuperVersus
 * ========================================================
 * Created by DDRKhat
 * Based upon Damizean's "L4D Spawn Missing Survivors"
 * ========================================================
v1.5.4
-Hooked Round_Start. (Should Improve TankHP and Bot spawning)
 v1.5.3
-Improved setting of TankHP (Should be definite now?)
v1.5.2
-Adjusted Survivor Spawning. (Should be the end of Survivor Spawning issues)
-Changed Finale Vehicle Handling. (Thanks to Damizean for the EntProp value!)
-Bot Booter only boots "Useless Bots" (Bots not directly involved with Useful/incap system)
v1.5.1
-Survivor Spawning moved "player_first_spawn" once more.
v1.5
-Official Left4Dead2 support
-Added client check on bot kicker (No more "Free Slot." disconnections)
-Bot Kicker message changed to "Kicking fake client" to help distinquish.
-XtraHP medpack spawning moved (Possibly fixes crashing on windows servers?)
-Survivor spawning moved to round_start, instant spawns survivors now
-Tank's Health is now using the server CVAR, could cause conflictions with other plugins.
v1.4
-Fixed Cvar forcing on survivor and infected limits
-CVAR Handle code improvements.
-Config file added (l4d_superversus.cfg inside of cfg/Soucemod)
-Tank HP changing now affects HUD
-Improved Tank monitoring
-Improved Left4DownTown checks
v1.3
-Fixed oversight preventing survivor joining
-Join commands now obey vs_max_team_switches
-Added Finale check. Makes saved survivors safe (To protect points)
-Added (If Left4Downtown 0.3.0 or later exists) Lobby Unreserving
-Fixed rare extra survivor
-Added option for Extra medpacks for extra survivors.
v1.2
-Increased Survivor/Infected limit to 18
-Added text-commands to join both teams (for those without console when the GUI fails)
+!jointeam2 / !joinsurvivor - Text equivalent of console command: jointeam 2
+!jointeam3 / !joininfected - Text equivalent of console command: jointeam 3
-Fixed stupid programming sight. Tank spawning fixed as a result.
-Various code cleanup
V1.1
-Adjusts the games built-in variables for handling survivor/infected limit
-Added a text-command people can use to join infected (Where the Switch Team GUI might fail)
-Added a command to increase zombie count.
V1.0
-Initial Release
*/

// *********************************************************************************
// PREPROCESSOR
// *********************************************************************************
// *********************************************************************************
#pragma semicolon 1                 // Force strict semicolon mode.
// INCLUDES
// *********************************************************************************
#include <sourcemod>
#include <sdktools>
#include <sdktools_functions>
// *********************************************************************************
// OPTIONALS - If these exist, we use them. If not, we do nothing.
// *********************************************************************************
native L4D_LobbyUnreserve();
native L4D_LobbyIsReserved();
// *********************************************************************************
// CONSTANTS
// *********************************************************************************
#define CONSISTENCY_CHECK	1.0
#define DEBUG		0
#define PLUGIN_VERSION		"1.5.4"
#define CVAR_FLAGS FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_DONTRECORD
// *********************************************************************************
// VARS
// *********************************************************************************
new Handle:SpawnTimer    		= INVALID_HANDLE;
new Handle:KickTimer    		= INVALID_HANDLE;
new Handle:SurvivorLimit 		= INVALID_HANDLE;
new Handle:InfectedLimit 		= INVALID_HANDLE;
new Handle:L4DSurvivorLimit 	= INVALID_HANDLE;
new Handle:L4DInfectedLimit 	= INVALID_HANDLE;
//new Handle:SuperTank			= INVALID_HANDLE;
//new Handle:hpMulti				= INVALID_HANDLE;
//new Handle:XtraHP				= INVALID_HANDLE;
//new Handle:KillRes				= INVALID_HANDLE;
//new Handle:CvarTankHP			= INVALID_HANDLE;
//new TankHP;
new bool:Useful[MAXPLAYERS+1];
#if DEBUG
new String:KhatID[] = "STEAM_1:1:2038252";
#endif
// *********************************************************************************
// PLUGIN
// *********************************************************************************
public Plugin:myinfo =
{
	name        = "L4D SuperVersus",
	author      = "DDRKhat",
	description = "Allow versus to become up to 18vs18",
	version     = PLUGIN_VERSION,
	url         = "http://forums.alliedmods.net/showthread.php?t=92713"
};
// *********************************************************************************
// METHODS
// *********************************************************************************
// ------------------------------------------------------------------------
// OnPluginStart()
// ------------------------------------------------------------------------
public OnPluginStart()
{
	//////////
	// Left4Dead Dependant
	//////////
	decl String:ModName[50];
	GetGameFolderName(ModName, sizeof(ModName));
	if(!StrEqual(ModName, "left4dead", false)&&!StrEqual(ModName, "left4dead2", false)) SetFailState("Use this in Left 4 Dead (2) only.");
	//////////
	// Convars
	//////////
	CreateConVar("sm_superversus_version", PLUGIN_VERSION, "L4D Super Versus", CVAR_FLAGS);
	//CvarTankHP = FindConVar("z_tank_health");
	L4DSurvivorLimit = FindConVar("survivor_limit");
	L4DInfectedLimit   = FindConVar("z_max_player_zombies");
	SurvivorLimit = CreateConVar("l4d_survivor_limit","4","Maximum amount of survivors", CVAR_FLAGS,true,1.00,true,18.00);
	InfectedLimit = CreateConVar("l4d_infected_limit","4","Max amount of infected (will not affect bots)", CVAR_FLAGS,true,1.00,true,18.00);
	//SuperTank = CreateConVar("l4d_supertank","0","Set tanks HP based on Survivor Count", CVAR_FLAGS,true,0.0,true,1.0);
	//XtraHP = CreateConVar("l4d_XtraHP","0","Give extra survivors HP packs? (1 for extra medpacks)", CVAR_FLAGS,true,0.0,true,1.0);
	//hpMulti = CreateConVar("l4d_tank_hpmulti","0.25","Tanks HP Multiplier (multi*(survivors-4))", CVAR_FLAGS,true,0.01,true,1.00);
	//KillRes = CreateConVar("l4d_killreservation","0","Should we clear Lobby reservaton? (For use with Left4DownTown extension ONLY)", CVAR_FLAGS,true,0.0,true,1.0);
	//////////
	// Convar handling
	//////////
	SetConVarBounds(L4DSurvivorLimit, ConVarBound_Upper, true, 18.0);
	SetConVarBounds(L4DInfectedLimit,   ConVarBound_Upper, true, 18.0);
	HookConVarChange(L4DSurvivorLimit, FSL);
	HookConVarChange(SurvivorLimit, FSL);
	HookConVarChange(L4DInfectedLimit, FIL);
	HookConVarChange(InfectedLimit, FIL);
	//HookConVarChange(CvarTankHP, TankHPCvar);
	//HookConVarChange(hpMulti, TankHPCvar);
	//////////
	// Commands
	//////////
	#if DEBUG
	RegConsoleCmd("sm_ddr", KhatCommand, "You know what you doing, take off every zig!!");
	#endif
	RegAdminCmd("sm_hardzombies", HardZombies, ADMFLAG_KICK, "How many zombies you want. (In multiples of 30. Recommended: 3 Max: 6)");
	RegConsoleCmd("sm_jointeam3", JoinTeam, "Jointeam 3 - Without dev console");
	RegConsoleCmd("sm_joininfected", JoinTeam, "Jointeam 3 - Without dev console");
	RegConsoleCmd("sm_jointeam2", JoinTeam2, "Jointeam 2 - Without dev console");
	RegConsoleCmd("sm_joinsurvivor", JoinTeam2, "Jointeam 2 - Without dev console");
	//////////
	// Events
	//////////
	HookEvent("round_start",Event_RoundStart);
	HookEvent("heal_begin",Event_UsefulBegin);
	HookEvent("heal_end",Event_UsefulEnd);
	HookEvent("revive_begin",Event_UsefulBegin);
	HookEvent("revive_end",Event_UsefulEnd);
	HookEvent("finale_vehicle_leaving", Event_FinaleVehicleLeaving);
	//////////
	// Load our config
	//////////
	//AutoExecConfig(true, "l4d_superversus");
}
// ------------------------------------------------------------------------
// OnAskPluginLoad() && OnLibraryRemoved && l4dt
// ------------------------------------------------------------------------
public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) {MarkNativeAsOptional("L4D_LobbyUnreserve");MarkNativeAsOptional("L4D_LobbyIsReserved");}
public bool:l4dt()
{
	if(GetConVarFloat(FindConVar("left4downtown_version"))>0.00) return true;
	else return false;
}
//public OnLibraryRemoved(const String:name[]) {if(StrEqual(name,"Left 4 Downtown Extension")) SetConVarInt(KillRes,0);}
// ------------------------------------------------------------------------
// OnConvarChange()
// ------------------------------------------------------------------------
#define FORCE_INT_CHANGE(%1,%2,%3) public %1 (Handle:c, const String:o[], const String:n[]) { SetConVarInt(%2,%3); } 
FORCE_INT_CHANGE(FSL,L4DSurvivorLimit,GetConVarInt(SurvivorLimit))
FORCE_INT_CHANGE(FIL,L4DInfectedLimit,GetConVarInt(InfectedLimit))
// ------------------------------------------------------------------------
// OnMapEnd()
// ------------------------------------------------------------------------
public OnMapEnd() {if (SpawnTimer != INVALID_HANDLE){
//KillTimer(SpawnTimer);
SpawnTimer = INVALID_HANDLE;}}
// ------------------------------------------------------------------------
// jointeam2 && jointeam3
// ------------------------------------------------------------------------
public Action:JoinTeam(client, args) {FakeClientCommand(client,"jointeam 3");return Plugin_Handled;}
public Action:JoinTeam2(client, args) {FakeClientCommand(client,"jointeam 2");return Plugin_Handled;}
// ------------------------------------------------------------------------
// OnClientPutInServer - We have to use this because AIDirector Puts bots in, doesn't connect them.
// ------------------------------------------------------------------------
public OnClientPutInServer(client)
{
	if (SpawnTimer == INVALID_HANDLE&&TeamPlayers(2)<GetConVarInt(SurvivorLimit)) SpawnTimer = CreateTimer(CONSISTENCY_CHECK, SpawnTick, _, TIMER_REPEAT);
	if (KickTimer == INVALID_HANDLE&&TeamPlayers(2)>GetConVarInt(SurvivorLimit)) KickTimer = CreateTimer(CONSISTENCY_CHECK, KickTick, _, TIMER_REPEAT);
	//SetTankHP();
	/*
	if(GetConVarInt(KillRes))
	{
		if(l4dt())	if(L4D_LobbyIsReserved()) L4D_LobbyUnreserve();
	}*/
}
// ------------------------------------------------------------------------
// TeamPlayers() arg = teamnum
// ------------------------------------------------------------------------
public TeamPlayers(any:team)
{
	new int=0;
	for (new i=1; i<=MaxClients; i++)
		{
			if (!IsClientConnected(i)) continue;
			if (!IsClientInGame(i))    continue;
			if (GetClientTeam(i) != team) continue;
			int++;
		}
	return int;
}
// ------------------------------------------------------------------------
// RealPlayersInGame()
// ------------------------------------------------------------------------
bool:RealPlayersInGame ()
{
	for (new i=1;i<=GetMaxClients();i++)
		if (IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i))
			return true;
	return false;
}
// ------------------------------------------------------------------------
// OnClientDisconnect()
// ------------------------------------------------------------------------
public OnClientDisconnect(client)
{
	if (IsFakeClient(client)) return;
	if (!RealPlayersInGame()) { new i; for (i=1;i<=GetMaxClients();i++) CreateTimer(0.1, KickFakeClient, i); }
}
// ------------------------------------------------------------------------
// SpawnFakeClient()
// ------------------------------------------------------------------------
SpawnFakeClient()
{
	// Spawn bot survivor.
	new Bot = CreateFakeClient("SurvivorBot");
	if (Bot == 0) return;

	ChangeClientTeam(Bot, 2);
	DispatchKeyValue(Bot, "classname", "SurvivorBot");
	/*
	if(GetConVarInt(XtraHP))
	{
		new med = GivePlayerItem(Bot,"weapon_first_aid_kit");
		if(med) EquipPlayerWeapon(Bot,med);
	}
	*/
	CreateTimer(0.1, KickFakeClient, Bot);
}
// ------------------------------------------------------------------------
// SpawnTick() 
// ------------------------------------------------------------------------
public Action:SpawnTick(Handle:hTimer, any:Junk)
{    
	#if DEBUG
	LogMessage("SpawnTick> Init");
	#endif
	// Determine the number of survivors and fill the empty
	// slots.
	new NumSurvivors = TeamPlayers(2);
	new MaxSurvivors = GetConVarInt(SurvivorLimit);
	#if DEBUG
	LogMessage("SpawnTick> Survivors: [%i/%i]",NumSurvivors,MaxSurvivors);
	#endif
	if (NumSurvivors < 4)
	{
		#if DEBUG
		LogMessage("SpawnTick> Less than 4 Survivors, Ending!");
		#endif
		//KillTimer(SpawnTimer);
		SpawnTimer = INVALID_HANDLE;
		return Plugin_Stop;
	}
	// Create missing bots
	for (;NumSurvivors < MaxSurvivors; NumSurvivors++)
	{
		#if DEBUG
		LogMessage("SpawnTick> Spawning Surivvor. Survivors: [%i/%i]",NumSurvivors,MaxSurvivors);
		#endif
		SpawnFakeClient();
	}
	// Once the missing bots are made, dispose of the timer
	#if DEBUG
	LogMessage("SpawnTick> Ending");
	#endif
	//KillTimer(SpawnTimer);
	SpawnTimer = INVALID_HANDLE;
	return Plugin_Stop;
}
// ------------------------------------------------------------------------
// KickTick()
// ------------------------------------------------------------------------
public Action:KickTick(Handle:hTimer, any:Junk)
{
	#if DEBUG
	LogMessage("KickTick> Init");
	#endif
	new NumSurvivors = TeamPlayers(2);
	new MaxSurvivors = GetConVarInt(SurvivorLimit);
	#if DEBUG
	LogMessage("KickTick> Survivors: [%i/%i]",NumSurvivors,MaxSurvivors);
	#endif
	if (NumSurvivors < 4)
	{
		#if DEBUG
		LogMessage("KickTick> Less than 4 Survivors, Ending!");
		#endif
		//KillTimer(SpawnTimer);
		SpawnTimer = INVALID_HANDLE;
		return Plugin_Stop;
	}
	for (new i=1;i<=GetMaxClients();i++)
	{
		if(IsClientConnected(i)&&IsFakeClient(i)&&IsUseless(i)&&NumSurvivors>MaxSurvivors)
			#if DEBUG
			LogMessage("KickTick> Found Useless Bot Survivors: [%i/%i]",NumSurvivors,MaxSurvivors);
			#endif
			CreateTimer(0.0, KickFakeClient, i);
			NumSurvivors--;
	}
	#if DEBUG
	LogMessage("KickTick> Ending");
	#endif
	//KillTimer(KickTimer);
	KickTimer = INVALID_HANDLE;
	return Plugin_Stop;
}
// ------------------------------------------------------------------------
// KickFakeClient()
// ------------------------------------------------------------------------
public Action:KickFakeClient(Handle:hTimer, any:Client)
{
	if(IsClientConnected(Client) && IsFakeClient(Client))
	{
		KickClient(Client, "Kicking Fake Client.");
	}
	return Plugin_Handled;
}
// ------------------------------------------------------------------------
// IsUseless() // Are we helping/being helped?
// ------------------------------------------------------------------------
bool:IsUseless(client)
{
	if(Useful[client] == false) return true;
	return false;
}
// ------------------------------------------------------------------------
// SetTankHP()
// ------------------------------------------------------------------------
/*
bool:SetTankHP() // this delay is necassary or it fails.
{
	if(GetConVarInt(SuperTank))
	{
		new Float:extrasurvivors=(float(TeamPlayers(2))-4.0);
		if(RoundFloat(extrasurvivors)>0.0)
		{
			TankHP = RoundFloat((4000*(1.0+(GetConVarFloat(hpMulti)*extrasurvivors))));
			if(TankHP>65535) TankHP=65535;
		}
		else TankHP=4000;
	}
}*/
// ------------------------------------------------------------------------
// TankHPCvar()
// ------------------------------------------------------------------------
/*
public TankHPCvar(Handle:c, const String:o[], const String:n[])
{
	SetTankHP();
	SetConVarInt(CvarTankHP,TankHP);
}*/
// ------------------------------------------------------------------------
// KhatCommand()
// ------------------------------------------------------------------------
#if DEBUG
public Action:KhatCommand(client, args) 
{
	new String:SteamID[64];
	GetClientAuthString(client, SteamID, sizeof(SteamID));
	if(StrEqual(SteamID,KhatID,true))
	{
		ReplyToCommand(client,"Hello DDRKhat. Command Executed.");
		if(IsUseless(client)) ReplyToCommand(client,"You are considered Useless!");
		if(!IsUseless(client)) ReplyToCommand(client,"You are considered not Useless!");
		if (SpawnTimer == INVALID_HANDLE&&TeamPlayers(2)<GetConVarInt(SurvivorLimit)) SpawnTimer = CreateTimer(CONSISTENCY_CHECK, SpawnTick, _, TIMER_REPEAT);
		if (KickTimer == INVALID_HANDLE&&TeamPlayers(2)>GetConVarInt(SurvivorLimit)) KickTimer = CreateTimer(CONSISTENCY_CHECK, KickTick, _, TIMER_REPEAT);
	}
	else
	{
		ReplyToCommand(client,"Sorry, only DDRKhat may execute this command.");
		PrintToChatAll("Someone attempted to activate the DDRKhat Command.!");
	}
}
#endif
// ------------------------------------------------------------------------
// HardZombies()
// ------------------------------------------------------------------------
public Action:HardZombies(client, args) 
{
	new String:arg[8];
	GetCmdArg(1,arg,8);
	new Input=StringToInt(arg[0]);
	if(Input==1)
	{
		SetConVarInt(FindConVar("z_common_limit"), 30); // Default
		SetConVarInt(FindConVar("z_mob_spawn_min_size"), 10); // Default
		SetConVarInt(FindConVar("z_mob_spawn_max_size"), 30); // Default
		SetConVarInt(FindConVar("z_mob_spawn_finale_size"), 20); // Default
		SetConVarInt(FindConVar("z_mega_mob_size"), 45); // Default
	}		
	else if(Input>1&&Input<7)
	{
		SetConVarInt(FindConVar("z_common_limit"), 30*Input); // Default 30
		SetConVarInt(FindConVar("z_mob_spawn_min_size"), 30*Input); // Default 10
		SetConVarInt(FindConVar("z_mob_spawn_max_size"), 30*Input); // Default 30
		SetConVarInt(FindConVar("z_mob_spawn_finale_size"), 30*Input); // Default 20
		SetConVarInt(FindConVar("z_mega_mob_size"), 30*Input); // Default 45
	}
	else {ReplyToCommand(client, "\x01[SM] Usage: How many zombies you want. (In multiples of 30. Recommended: 3 Max: 6)");ReplyToCommand(client, "\x01          : Anything above 3 may cause moments of lag 1 resets the defaults");}
	return Plugin_Handled;
}
// ------------------------------------------------------------------------
// FinaleEnd() Thanks to Damizean for smarter method of detecting safe survivors.
// ------------------------------------------------------------------------
public Event_FinaleVehicleLeaving(Handle:event, const String:name[], bool:dontBroadcast)
{
	new edict_index = FindEntityByClassname(-1, "info_survivor_position");
	if (edict_index != -1)
	{
		new Float:pos[3];
		GetEntPropVector(edict_index, Prop_Send, "m_vecOrigin", pos);
		for(new i=1; i <= MaxClients; i++)
		{
			if (!IsClientConnected(i)) continue;
			if (!IsClientInGame(i)) continue;
			if (GetClientTeam(i) != 2) continue;
			if (!IsPlayerAlive(i)) continue;
			if (GetEntProp(i, Prop_Send, "m_isIncapacitated", 1) == 1) continue;
			TeleportEntity(i, pos, NULL_VECTOR, NULL_VECTOR);
		}
	}
}
// ------------------------------------------------------------------------
// Event_UsefulBegin()
// ------------------------------------------------------------------------
public Event_UsefulBegin(Handle:event, const String:name[], bool:dontBroadcast)
{
	Useful[GetClientOfUserId(GetEventInt(event, "userid"))] = true; //Healer
	Useful[GetClientOfUserId(GetEventInt(event, "subject"))] = true; //Target
}
// ------------------------------------------------------------------------
// Event_UsefulEnd()
// ------------------------------------------------------------------------
public Event_UsefulEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	Useful[GetClientOfUserId(GetEventInt(event, "userid"))] = false; //Healer
	Useful[GetClientOfUserId(GetEventInt(event, "subject"))] = false; //Target
}
// ------------------------------------------------------------------------
// Event_RoundStart()
// ------------------------------------------------------------------------
public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	//SetTankHP();
	if (SpawnTimer == INVALID_HANDLE&&TeamPlayers(2)<GetConVarInt(SurvivorLimit)) SpawnTimer = CreateTimer(CONSISTENCY_CHECK, SpawnTick, _, TIMER_REPEAT);
	if (KickTimer == INVALID_HANDLE&&TeamPlayers(2)>GetConVarInt(SurvivorLimit)) KickTimer = CreateTimer(CONSISTENCY_CHECK, KickTick, _, TIMER_REPEAT);
}