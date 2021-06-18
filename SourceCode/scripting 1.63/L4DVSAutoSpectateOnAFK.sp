/********************************************************************************************
* Plugin	: L4DVSAutoSpectateOnAFK
* Version	: 1.6
* Game		: Left 4 Dead 
* Author	: djromero (SkyDavid, David) & Harry
* Testers	: Myself
* Website	: www.sky.zebgames.com
* A
* Purpose	: This plugins forces AFK players to spectate, and later it kicks them. Admins 
* 			  are inmune to kick.
*********************************************************************************************/

#include <sourcemod>
#include <sdktools>
#include <sdktools_functions>
#include <colors>
#define PLUGIN_VERSION "1.6"


// For cvars
new Handle:h_AfkWarnSpecTime;
new Handle:h_AfkSpecTime;
new Handle:h_AfkWarnKickTime;
new Handle:h_AfkKickTime;
new Handle:h_AfkCheckInterval;
new Handle:h_AfkKickEnabled;
new Handle:h_AfkSpecOnConnect;
new Handle:h_AfkShowTeamPanel;
new afkWarnSpecTime;
new afkSpecTime;
new afkWarnKickTime;
new afkKickTime;
new afkCheckInterval;
new bool:afkKickEnabled;
new bool:afkSpecOnConnect;
new bool:afkShowTeamPanel;

// work variables
new bool:afkManager_Active = false;
new afkPlayerTimeLeftWarn[MAXPLAYERS + 1];
new afkPlayerTimeLeftAction[MAXPLAYERS + 1];
new afkPlayerTrapped[MAXPLAYERS + 1];
new Float:afkPlayerLastPos[MAXPLAYERS + 1][3];
new Float:afkPlayerLastEyes[MAXPLAYERS + 1][3];
new bool:LeavedSafeRoom;
new bool:PlayerJustConnected[MAXPLAYERS + 1];
native IsInReady();
native IsInPause();
native Is_Ready_Plugin_On();

public Plugin:myinfo = 
{
	name = "[L4D] VS Auto-spectate on AFK",
	author = "djromero (SkyDavid, David Romero) & Harry",
	description = "Auto-spectate for AFK players on VS mode",
	version = PLUGIN_VERSION,
	url = "www.sky.zebgames.com"
}

public OnPluginStart()
{
	LoadTranslations("Roto2-AZ_mod.phrases");
	// We register the spectate command
	RegConsoleCmd("say", Command_Say);
	RegConsoleCmd("say_team", Command_Say);
	
	
	// Changed teams
	HookEvent("player_team", afkChangedTeam);
	
	// Player actions
	HookEvent("entity_shoved", afkPlayerAction);
	HookEvent("player_shoved", afkPlayerAction);
	HookEvent("player_shoot", afkPlayerAction);
	HookEvent("player_jump", afkPlayerAction);
	HookEvent("player_hurt", afkPlayerAction);
	HookEvent("player_hurt_concise", afkPlayerAction);
	
	// incapacitated
	HookEvent("player_incapacitated", afkEventIncap);
	HookEvent("player_ledge_grab", afkEventIncap);
	HookEvent("revive_success", afkEventRevived);
	
	// checkpoints
	HookEvent("player_entered_checkpoint", afkEventStartCheck);
	HookEvent("player_left_checkpoint", afkEventStopCheck);
	
	// tounge & choke
	HookEvent("tongue_grab", afkEventStartGrab);
	HookEvent("choke_start", afkEventStartGrab);
	HookEvent("tongue_release", afkEventStopGrab);
	
	// pounced
	HookEvent("lunge_pounce", afkEventStartGrab);
	HookEvent("pounce_end", afkEventStopGrab);
	HookEvent("pounce_stopped", afkEventStopGrab);
	
	// For roundstart and roundend..
	HookEvent("round_start", Event_RoundStart, EventHookMode_Post);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_Pre);
	HookEvent("player_left_start_area", PlayerLeftStart);
	HookEvent("finale_vehicle_leaving", Event_RoundEnd, EventHookMode_Pre);
	HookEvent("mission_lost", Event_RoundEnd);
	HookEvent("map_transition", Event_RoundEnd, EventHookMode_Pre);

	// Afk manager time limits
	h_AfkWarnSpecTime = CreateConVar("l4d_specafk_warnspectime", "20", "Warn time before spec", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY, false, 0.0, false, 0.0);
	h_AfkSpecTime = CreateConVar("l4d_specafk_spectime", "15", "time before spec (after warn)", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY, false, 0.0, false, 0.0);
	h_AfkWarnKickTime = CreateConVar("l4d_specafk_warnkicktime", "60", "Warn time before kick (while already on spec)", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY, false, 0.0, false, 0.0);
	h_AfkKickTime = CreateConVar("l4d_specafk_kicktime", "30", "time before kick (while already on spec after warn)", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY, false, 0.0, false, 0.0);
	h_AfkCheckInterval = CreateConVar("l4d_specafk_checkinteral", "1", "Check/warn interval", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY, false, 0.0, false, 0.0);
	h_AfkKickEnabled = CreateConVar("l4d_specafk_kickenabled", "0", "If kick enabled on afk while on spec", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY, false, 0.0, false, 0.0);
	h_AfkSpecOnConnect = CreateConVar("l4d_specafk_speconconnect", "0", "If player will be forced to spectate on connect", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY, false, 0.0, false, 0.0);
	h_AfkShowTeamPanel = CreateConVar("l4d_specafk_showteampanel", "0", "If team panel will be showed to connecting players", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY, false, 0.0, false, 0.0);
	
	// Hook cvars changes ...
	HookConVarChange(h_AfkWarnSpecTime, ConVarChanged);
	HookConVarChange(h_AfkSpecTime, ConVarChanged);
	HookConVarChange(h_AfkWarnKickTime, ConVarChanged);
	HookConVarChange(h_AfkKickTime, ConVarChanged);
	HookConVarChange(h_AfkCheckInterval, ConVarChanged);
	HookConVarChange(h_AfkKickEnabled, ConVarChanged);
	HookConVarChange(h_AfkSpecOnConnect, ConVarChanged);
	HookConVarChange(h_AfkShowTeamPanel, ConVarChanged);
	
	// We register the version cvar
	CreateConVar("l4d_specafk_version", PLUGIN_VERSION, "Version of L4D VS Auto spectate on AFK", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	
	// We tweak some settings ..
	SetConVarInt(FindConVar("vs_max_team_switches"), 9999); // so that players can switch multiple times
	
	// We read the cvars
	ReadCvars();
}

public ReadCvars()
{
	// first we read all the variables ...
	afkWarnSpecTime = GetConVarInt(h_AfkWarnSpecTime);
	afkSpecTime = GetConVarInt(h_AfkSpecTime);
	afkWarnKickTime = GetConVarInt(h_AfkWarnKickTime);
	afkKickTime = GetConVarInt(h_AfkKickTime);
	afkCheckInterval = GetConVarInt(h_AfkCheckInterval);
	afkKickEnabled = GetConVarBool(h_AfkKickEnabled);
	afkSpecOnConnect = GetConVarBool(h_AfkSpecOnConnect);
	afkShowTeamPanel = GetConVarBool(h_AfkShowTeamPanel);
}

public ConVarChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	ReadCvars();
}

public OnMapStart()
{
	new i;
	for (i=1;i<=MAXPLAYERS;i++)
		PlayerJustConnected[i] = false;
	
	// We read all the cvars
	ReadCvars();
}

public OnMapEnd()
{
	afkManager_Stop();
}

public OnClientPutInServer(client)
{
	// If players already leaved safe room we mark the player as just connected ...
	if (LeavedSafeRoom)
		PlayerJustConnected[client] = true;
	else
	PlayerJustConnected[client] = false; // it just connected, but we don't care right now ...
}

public IsValidClient (client)
{
	if ((client >= 1) && (client <= GetMaxClients()))
		return true;
	else
	return false;
}

public IsValidPlayer (client)
{
	if (client == 0)
		return false;
	
	if (!IsClientConnected(client))
		return false;
	
	if (IsFakeClient(client))
		return false;
	
	if (!IsClientInGame(client))
		return false;
	
	return true;
}

bool:IsClientMember (client)
{
	// Checks valid player
	if (!IsValidPlayer (client))
		return false;
	
	// Gets the admin id
	new AdminId:id = GetUserAdmin(client);
	
	// If player is not admin ...
	if (id == INVALID_ADMIN_ID)
		return false;
	
	// If player has at least reservation ...
	if (GetAdminFlag(id, Admin_Reservation)||GetAdminFlag(id, Admin_Root)||GetAdminFlag(id, Admin_Kick))
		return true;
	else
	return false;
}

public Action:Command_Say(client, args)
{
	if(client && IsClientInGame(client))
		afkResetTimers(client);
}

public Action:Event_RoundStart (Handle:event, const String:name[], bool:dontBroadcast)
{
	// reset some variables
	LeavedSafeRoom = false;
	
	// We start the AFK manager
	if(!afkManager_Active)
	{
		afkManager_Start();
	}
	
	return Plugin_Continue;
}


public Action:PlayerLeftStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	LeavedSafeRoom = true;
	return Plugin_Continue;
}

public Action:Event_RoundEnd (Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToServer("******* ROUND END *********");
	
	afkManager_Stop();
}

public Action:afkEventStartGrab (Handle:event, const String:name[], bool:dontBroadcast)
{
	// gets the id
	new id = GetClientOfUserId(GetEventInt(event, "victim"));
	
	// mark as incapacitated
	if (id > 0)
		afkPlayerTrapped[id] = true;
}

public Action:afkEventStopGrab (Handle:event, const String:name[], bool:dontBroadcast)
{
	// gets the id
	new id = GetClientOfUserId(GetEventInt(event, "victim"));
	
	// mark as incapacitated
	if (id > 0)
		afkPlayerTrapped[id] = false;
}


public Action:afkEventStartCheck (Handle:event, const String:name[], bool:dontBroadcast)
{
	// gets the id
	new id = GetClientOfUserId(GetEventInt(event, "userid"));
	
	// mark as incapacitated
	if (id > 0)
		afkPlayerTrapped[id] = true;
}

public Action:afkEventStopCheck (Handle:event, const String:name[], bool:dontBroadcast)
{
	// gets the id
	new id = GetClientOfUserId(GetEventInt(event, "userid"));
	
	// mark as incapacitated
	if (id > 0)
		afkPlayerTrapped[id] = false;
}

public Action:afkEventIncap (Handle:event, const String:name[], bool:dontBroadcast)
{
	// gets the id
	new id = GetClientOfUserId(GetEventInt(event, "userid"));
	
	// mark as incapacitated
	if (id > 0)
		afkPlayerTrapped[id] = true;
}

public Action:afkEventRevived (Handle:event, const String:name[], bool:dontBroadcast)
{
	// gets the id
	new id = GetClientOfUserId(GetEventInt(event, "subject"));
	
	// mark as incapacitated
	if (id > 0)
		afkPlayerTrapped[id] = false;
}


public Action:afkPlayerAction (Handle:event, const String:name[], bool:dontBroadcast)
{
	new String:propname[200];
	
	// gets the property name
	if (strcmp(name, "entity_shoved", false)==0)
		propname = "attacker";
	else if (strcmp(name, "player_shoved", false)==0)
		propname = "attacker";
	else if (strcmp(name, "player_hurt", false)==0)
		propname = "attacker";
	else if (strcmp(name, "player_hurt_concise", false)==0)
		propname = "attacker";
	else 
	propname = "userid";
	
	// gets the id
	new id = GetClientOfUserId(GetEventInt(event, propname));
	
	// resets his timers
	if (id > 0)
		afkResetTimers(id);
}

public Action:afkChangedTeam (Handle:event, const String:name[], bool:dontBroadcast)
{
	if(Is_Ready_Plugin_On()) return Plugin_Continue;

	// we get the victim
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	if (victim > 0)
	{
		if (IsClientConnected(victim)&&(!IsFakeClient(victim)))
		{	
			// If players left the safe room and this player just connected and we have set spec on connect ...
			if (LeavedSafeRoom && PlayerJustConnected[victim] && afkSpecOnConnect)
			{
				// If player is on survivors and is dead ... we don't force him to spec
				if ((GetClientTeam(victim) == 2) && (!IsPlayerAlive(victim)))
					return Plugin_Continue;
				
				// force him to spectate
				CreateTimer(0.1, afkForceSpectateJoin, victim);
			}
			
			// Mark as already connected
			PlayerJustConnected[victim] = false;
			
			// Reset his afk status
			afkResetTimers(victim);
			afkPlayerTrapped[victim] = false;
		}
	}
	
	return Plugin_Continue;
}

public Action:afkJoinHint (Handle:Timer, any:client)
{
	// If player is valid
	if ((client > 0) && IsClientConnected(client) && IsClientInGame(client))
	{
		// If player is still on spectators ...
		if (GetClientTeam(client) == 1)
		{
			// We send him a hint text ...
			PrintHintText(client, "%T","L4DVSAutoSpectateOnAFK1",client);
			
			// and setup another timer to tell him later ....
			CreateTimer(5.0, afkJoinHint, client);
		}
	}
}


afkResetTimers (client)
{
	// if client is not valid
	if (!IsValidClient(client))
		return;
	
	// if client is valid ...
	if ((!IsClientConnected(client))||(!IsClientInGame(client))||(IsFakeClient(client)))
		return;
	
	
	// If client is not on spec team
	if (GetClientTeam(client)!=1)
	{
		afkPlayerTimeLeftWarn[client] = afkWarnSpecTime;
		afkPlayerTimeLeftAction[client] = afkSpecTime;
	}
	else // if player is on spectators
	{
		afkPlayerTimeLeftWarn[client] = afkWarnKickTime;
		afkPlayerTimeLeftAction[client] = afkKickTime;
	}
	
	// if player just joined, we double his warn time
	if (PlayerJustConnected[client])
	{
		afkPlayerTimeLeftWarn[client] = afkPlayerTimeLeftWarn[client] * 2;
	}
	
	// if player is already connected ....
	if (IsClientConnected(client) && (!IsFakeClient(client)) && IsClientInGame(client))
	{
		GetClientAbsOrigin(client, afkPlayerLastPos[client]);
		GetClientEyeAngles(client, afkPlayerLastEyes[client]);
	}
}

afkManager_Start()
{
	// mark as active
	afkManager_Active = true; 
	
	// now we reset all the timers ...
	new i;
	for (i=1;i<=MAXPLAYERS;i++)
	{
		afkResetTimers(i);
		afkPlayerTrapped[i] = false; // we mark the player as not trapped
	}
	
	// we start the check thread ....
	CreateTimer(float(afkCheckInterval), afkCheckThread, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action:afkCheckThread(Handle:timer)
{
	// if afkmanager is not active ...
	if (!afkManager_Active || Is_Ready_Plugin_On())
		return Plugin_Stop;
	if(IsInReady() || IsInPause() )
		return Plugin_Continue;
		
	new count = GetMaxClients();
	decl i;
	new Float:pos[3];
	new Float:eyes[3];
	
	// we check all connected (and alive) clients ...
	for (i=1;i<=count;i++)
	{
		if (IsClientConnected(i) && (!IsFakeClient(i)) && IsClientInGame(i))
		{
			// If player is not on spectators team ...
			if (GetClientTeam(i) != 1)
			{
				// If client is alive 
				if (IsPlayerAlive(i))
				{
					// we get his current coordinates and eyes
					GetClientAbsOrigin(i, pos);
					GetClientEyeAngles(i, eyes);
					
					// if he hasn't moved ..
					if ((pos[0] == afkPlayerLastPos[i][0])&&(pos[1] == afkPlayerLastPos[i][1])&&(pos[2] == afkPlayerLastPos[i][2])&&(eyes[0] == afkPlayerLastEyes[i][0])&&(eyes[1] == afkPlayerLastEyes[i][1])&&(eyes[2] == afkPlayerLastEyes[i][2]))
					{
						// if the player is not trapped (incapacitated, pounced, etc)
						if (!afkPlayerTrapped[i])
						{
							// If player has not been warned ...
							if (afkPlayerTimeLeftWarn[i] > 0) // warn time ...
							{
								// we reduce his warn time ...
								afkPlayerTimeLeftWarn[i] = afkPlayerTimeLeftWarn[i] - afkCheckInterval;
								
								// if his warn time reached 0 ....
								if (afkPlayerTimeLeftWarn[i] <= 0)
								{
									// we set his time left to spectate
									afkPlayerTimeLeftAction[i] = afkSpecTime;
									
									// We warn the player ....
									PrintHintText(i, "%T","L4DVSAutoSpectateOnAFK2",i, afkPlayerTimeLeftAction[i]);
								}
							}
							else // player warn timeout reached ...
							{
								// we reduce his action time
								afkPlayerTimeLeftAction[i] = afkPlayerTimeLeftAction[i] - afkCheckInterval;
								
								// if his action time reached 0 ...
								if (afkPlayerTimeLeftAction[i] <= 0)
								{
									// If players leaved safe room we force him to spectate
									if (LeavedSafeRoom)
									{
										// we force the player to spectate
										afkForceSpectate(i, true, false);
										
										// reset the timers
										afkResetTimers(i);
									}
									else // if players haven't leaved safe room ... we warn this player that he will be forced to spectate as soon as a player leaves
									{
										PrintHintText(i, "%T","L4DVSAutoSpectateOnAFK3",i);
									}
								}
								else // we just warn him ...
								PrintHintText(i, "%T","L4DVSAutoSpectateOnAFK2",i, afkPlayerTimeLeftAction[i]);
								
							}
						} // player is not trapped
						else // player is trapped
						{
							afkResetTimers(i);
						}
					} // player hasn't moved ...
					else // player moved ...
					{
						// player is not trapped then ...
						afkPlayerTrapped[i] = false;
						
						// we reset his timers
						afkResetTimers(i);
					}
					
				} // player is alive or is infected
			} // player is not on spectators ...
			else if (afkKickEnabled)  // if player is on spectators and kick on spectators is enabled ...
			{
				// If the player is not registered ...
				if (!IsClientMember(i))
				{
					// If player has not been warned ...
					if (afkPlayerTimeLeftWarn[i] > 0) // warn time ...
					{
						// we reduce his warn time ...
						afkPlayerTimeLeftWarn[i] = afkPlayerTimeLeftWarn[i] - afkCheckInterval;
						
						// if his warn time reached 0 ....
						if (afkPlayerTimeLeftWarn[i] <= 0)
						{
							// We warn the player ....
							PrintHintText(i, "%T","L4DVSAutoSpectateOnAFK4",i, afkPlayerTimeLeftAction[i]);
						}
					}
					else // player warn timeout reached ...
					{
						// we reduce his action time
						afkPlayerTimeLeftAction[i] = afkPlayerTimeLeftAction[i] - afkCheckInterval;
						
						// if his action time reached 0 ...
						if (afkPlayerTimeLeftAction[i] <=  0)
						{
							// If players haven't leaved the safe room ..
							if (!LeavedSafeRoom)
							{
								// we force the player to spectate
								afkKickClient(i);
							}
							else // We warn him that he will be kicked ...
							{
								PrintHintText(i, "%T","L4DVSAutoSpectateOnAFK5",i);
							}
						}
						else // we just warn him ...
						PrintHintText(i, "%T","L4DVSAutoSpectateOnAFK4",i, afkPlayerTimeLeftAction[i]);
						
					}			
				} // player is not admin
			} // player is on spectators
			
		} // player is connected and in-game
	}
	
	// We continue with the timer
	return Plugin_Continue;
}


afkForceSpectate (client, bool:advertise, bool:self)
{
	if (!IsClientConnected(client)||IsFakeClient(client))
	{
		return;
	}
	
	// If player was on infected .... 
	if (GetClientTeam(client) == 3)
	{
		// ... and he wasn't a tank ...
		new String:iClass[100];
		GetClientModel(client, iClass, sizeof(iClass));
		if (StrContains(iClass, "hulk", false) == -1)
		{
			ForcePlayerSuicide(client);	// we kill him
		}
		else // if he was a tank, we can't force him to spectate ... we wait for him to lose the tank
		{
			return;
		}
	}
	
	// We force him to spectate
	ChangeClientTeam(client, 1);
	
	// If team panel is enabled ...
	if (afkShowTeamPanel)
	{
		// we show him the panel ...
		ClientCommand(client, "chooseteam");
	}
	
	// We send him a hint text ...
	PrintHintText(client, "%T","L4DVSAutoSpectateOnAFK1",client);
	
	// We send him a hint message 5 seconds later, in case he hasn't joined any team
	CreateTimer(5.0, afkJoinHint, client);
	
	
	// Print forced info
	if (advertise)
	{
		new String:PlayerName[200];
		GetClientName(client, PlayerName, sizeof(PlayerName));
	}
	else if (self) 	// If player switched itself ...
	{
		new String:PlayerName[200];
		GetClientName(client, PlayerName, sizeof(PlayerName));
	}
	
}

public Action:afkForceSpectateJoin (Handle:timer, any:client)
{
	afkForceSpectate(client, false, false);
}

afkKickClient (client)
{
	if ((!IsClientConnected(client))||IsFakeClient(client))
		return;
	
	// If player was on infected ....
	if (GetClientTeam(client) == 3)
	{
		// ... and he wasn't a tank ...
		new String:iClass[100];
		GetClientModel(client, iClass, sizeof(iClass));
		if (StrContains(iClass, "hulk", false) == -1)
			ForcePlayerSuicide(client);	// we kill him
	}
	
	// We force him to spectate
	ChangeClientTeam(client, 1);
	
	// Then we kick him
	KickClient(client, "Kicked because of AFK status");
	
	// Print forced info
	new String:PlayerName[200];
	GetClientName(client, PlayerName, sizeof(PlayerName));
	
	CPrintToChatAll("{default}[{olive}TS{default}] %t","L4DVSAutoSpectateOnAFK6", PlayerName);
}


afkManager_Stop()
{
	// if it was not active ...
	if (!afkManager_Active) return;
	
	// mark as not active
	afkManager_Active = false;
}

/////////////////
///////////////////
/////