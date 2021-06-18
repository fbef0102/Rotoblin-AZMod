#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <l4d_direct>
#include <l4d_weapon_stocks>
#include <colors>
#include <left4downtown>

#define SPECHUD_DRAW_INTERVAL   0.5
#define CLAMP(%0,%1,%2) (((%0) > (%2)) ? (%2) : (((%0) < (%1)) ? (%1) : (%0)))
#define MAX(%0,%1) (((%0) > (%1)) ? (%0) : (%1))
#define MIN(%0,%1) (((%0) < (%1)) ? (%0) : (%1))

#define ZOMBIECLASS_NAME(%0) (L4DSI_Names[(%0)])

enum L4DGamemode
{
	L4DGamemode_None,
	L4DGamemode_Versus,
};

enum L4DSI 
{
	ZC_None,
	ZC_Smoker,
	ZC_Boomer,
	ZC_Hunter,
	ZC_Witch,
	ZC_Tank
};

static const String:L4DSI_Names[][] = 
{
	"None",
	"Smoker",
	"Boomer",
	"Hunter",
	"Witch",
	"Tank"
};

new Handle:survivor_limit;
new Handle:z_max_player_zombies;
new Handle:g_hVsBossBuffer;

new bool:bSpecHudActive[MAXPLAYERS + 1];

new passCount = 1;
static bool:g_bLeftStartRoom;
new iWitchPercent = 0;
new iTankPercent = 0;
native IsInPause(); //from roto2.smx
native IsInReady(); //from l4dready_scrds
native Is_Ready_Plugin_On();//from l4dready_scrds
native GetTankPercent(); //from l4d_boss_percent
native GetWitchPercent(); //from l4d_boss_percent
native bool:IsClientVoteMenu(client);//From Votes2
native bool:IsClientInfoMenu(client);//From l4d_Harry_Roto2-AZ_mod_info
native Score_GetTeamCampaignScore(team);//From l4dscores
native WhoIsTank();//From l4d_tank_control
static g_hSpawnGhostTimer[MAXPLAYERS + 1];

public Plugin:myinfo = 
{
	name = "Hyper-V HUD Manager [Public Version]",
	author = "Visor, L4D1 port by harry",
	description = "Provides different HUDs for spectators",
	version = "8.0",
	url = "https://github.com/Attano/smplugins"
};

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	CreateNative("IsClientSpecHud", Native_IsClientSpecHud);
	return APLRes_Success;
}
public Native_IsClientSpecHud(Handle:plugin, numParams)
{
   new num1 = GetNativeCell(1);
   return bSpecHudActive[num1];
}
public OnPluginStart() 
{
	LoadTranslations("Roto2-AZ_mod.phrases");
	g_hVsBossBuffer = FindConVar("versus_boss_buffer");
	
	survivor_limit = FindConVar("survivor_limit");
	z_max_player_zombies = FindConVar("z_max_player_zombies");

	RegConsoleCmd("sm_sh", ToggleSpecHudCmd);
	RegConsoleCmd("sm_spechud", ToggleSpecHudCmd);
	
	HookEvent("player_left_start_area", LeftStartAreaEvent, EventHookMode_PostNoCopy);
	HookEvent("round_start", RoundStartEvent, EventHookMode_PostNoCopy);//每回合開始就發生的event
	HookEvent("tank_frustrated", OnTankFrustrated, EventHookMode_Post);
	HookEvent("entity_killed",		PD_ev_EntityKilled);
	HookEvent("ghost_spawn_time", Event_GhostSpawnTime);
	HookEvent("player_team", Event_PlayerTeam);
	HookEvent("player_spawn", Event_PlayerSpawn);
	
	for (new i = 1; i <= MaxClients; i++) 
	{
		bSpecHudActive[i] = false;
		g_hSpawnGhostTimer[i] = -1;
	}
		
	CreateTimer(SPECHUD_DRAW_INTERVAL, HudDrawTimer, _, TIMER_REPEAT);
	
}
public OnMapStart()
{
	passCount = 1;
	g_bLeftStartRoom = false;
}

public RoundStartEvent(Handle:event, const String:name[], bool:dontBroadcast)
{
	passCount = 1;
	g_bLeftStartRoom = false;
}

public Action:Event_PlayerSpawn(Handle:hEvent, const String:name[], bool:dontBroadcast)
{
	new Client = GetClientOfUserId(GetEventInt(hEvent, "userid"));

	if (Client == 0 || !IsClientInGame(Client) || IsFakeClient(Client) || GetClientTeam(Client) != 3)
		return;

	g_hSpawnGhostTimer[Client] = -1;
}

public Action:Event_PlayerTeam(Handle:hEvent, const String:name[], bool:dontBroadcast)
{
	new Client = GetClientOfUserId(GetEventInt(hEvent, "userid"));

	if (Client == 0 || !IsClientInGame(Client))
		return;

	new OldTeam = GetEventInt(hEvent, "oldteam");

	if (OldTeam == 3)
		g_hSpawnGhostTimer[Client] = -1;
}

public LeftStartAreaEvent(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(!Is_Ready_Plugin_On())
	{
		decl String:Info[50];
		g_bLeftStartRoom = true;
		for (new i = 1; i <= MaxClients; i++) 
			if (IsClientConnected(i) && IsClientInGame(i)&& !IsFakeClient(i) && GetClientTeam(i) == 1)
			{
				Format(Info, sizeof(Info), "%T", (bSpecHudActive[i] ? "Off" : "On"),i);
				CPrintToChat(i, "%T","l4d_versus_spechud1",i,"!spechud",Info);
			}
	}
	
}


public OnClientPutInServer(client)
{
	g_hSpawnGhostTimer[client] = -1;
	CreateTimer(10.0,COLD_DOWN,client);
}

public OnClientDisconnect(Client)
{
	if (IsFakeClient(Client))
		return;
		
	g_hSpawnGhostTimer[Client] = -1;
}
	
public Action:COLD_DOWN(Handle:timer,any:client)
{
	decl String:Info[50];
	if (IsClientConnected(client) && IsClientInGame(client)&& !IsFakeClient(client) && GetClientTeam(client) == 1)
	{
		Format(Info, sizeof(Info), "%T", (bSpecHudActive[client] ? "Off" : "On"),client);
		CPrintToChat(client, "%T","l4d_versus_spechud1",client,"!spechud",Info);
	}
}
	
public Action:Event_GhostSpawnTime(Handle:hEvent, const String:name[], bool:dontBroadcast)
{
	new Client = GetClientOfUserId(GetEventInt(hEvent, "userid"));

	if (Client == 0 || !IsClientInGame(Client) || IsFakeClient(Client))
		return;

	if (IsPlayerAlive(Client))
		return;
		
	new SpawnTime = GetEventInt(hEvent, "spawntime");
	
	g_hSpawnGhostTimer[Client] = SpawnTime - 1;
	CreateTimer(1.0, Timer_SpawnGhostClass, Client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);	
}

public Action:Timer_SpawnGhostClass(Handle:hTimer, any:Client)
{

	if (Client == 0 || !IsClientInGame(Client) || IsFakeClient(Client) || GetClientTeam(Client) != 3 || IsPlayerAlive(Client) || g_hSpawnGhostTimer[Client] == -1)
	{
		g_hSpawnGhostTimer[Client] = -1;
		return Plugin_Stop;
	}
	
	if(g_hSpawnGhostTimer[Client]>0)	
		g_hSpawnGhostTimer[Client] --;
	
	return Plugin_Continue;
}
		
public Action:ToggleSpecHudCmd(client, args) 
{
	if(GetClientTeam(client)!=1)
		return;

	bSpecHudActive[client] = !bSpecHudActive[client];
	
	decl String:Info[50];
	Format(Info, sizeof(Info), "%T", (bSpecHudActive[client] ? "On" : "Off"),client);
	CPrintToChat(client, "%T","l4d_versus_spechud2",client, Info);
}

public Action:HudDrawTimer(Handle:hTimer) 
{
	if(IsInReady()||IsInPause()|| (!Is_Ready_Plugin_On()&&!g_bLeftStartRoom)) return Plugin_Continue;
	
	new bool:bSpecsOnServer = false;
	for (new i = 1; i <= MaxClients; i++) 
	{
		if (IsSpectator(i))
		{
			bSpecsOnServer = true;
			break;
		}
	}

	if (bSpecsOnServer) // Only bother if someone's watching us
	{
		new Handle:specHud = CreatePanel();

		FillHeaderInfo(specHud);
		FillSurvivorInfo(specHud);
		FillInfectedInfo(specHud);
		FillTankInfo(specHud);
		FillGameInfo(specHud);

		for (new i = 1; i <= MaxClients; i++) 
		{
			if (!bSpecHudActive[i] || !IsSpectator(i) || IsFakeClient(i) ||IsClientVoteMenu(i)||IsClientInfoMenu(i))
				continue;
			
			SendPanelToClient(specHud, i, DummySpecHudHandler, 3);
		}

		CloseHandle(specHud);
	}
	
	return Plugin_Continue;
}

public DummySpecHudHandler(Handle:hMenu, MenuAction:action, param1, param2) {}

FillHeaderInfo(Handle:hSpecHud) 
{
	decl String:versionInfo[128];
	decl String:Notice[64];
	GetConVarString(FindConVar("l4d_ready_league_notice"), Notice, sizeof(Notice));
	Format(versionInfo, 128, "Spectator HUD (%s)", Notice);
	
	DrawPanelText(hSpecHud, versionInfo);

	decl String:buffer[512];
	Format(buffer, sizeof(buffer), "Slots %i/%i | Tickrate %i", GetRealClientCount(), GetConVarInt(FindConVar("l4d_maxplayers")), RoundToNearest(1.0 / GetTickInterval()));
	//Format(buffer, sizeof(buffer), "Slots %i/%i | Tickrate %i", GetRealClientCount(), 18, RoundToNearest(1.0 / GetTickInterval()));
	DrawPanelText(hSpecHud, buffer);
}

GetMeleePrefix(client, String:prefix[], length) 
{
	new secondary = GetPlayerWeaponSlot(client, _:L4DWeaponSlot_Secondary);
	new WeaponId:secondaryWep = IdentifyWeapon(secondary);

	decl String:buf[4];
	switch (secondaryWep)
	{
		case WEPID_NONE: buf = "N";
		case WEPID_PISTOL: buf = (GetEntProp(secondary, Prop_Send, "m_isDualWielding") ? "DP" : "P");
		case WEPID_MELEE: buf = "M";
		case WEPID_PISTOL_MAGNUM: buf = "DE";
		default: buf = "?";
	}

	strcopy(prefix, length, buf);
}

FillSurvivorInfo(Handle:hSpecHud) 
{
	decl String:info[512];
	decl String:buffer[64];
	decl String:name[MAX_NAME_LENGTH];

	DrawPanelText(hSpecHud, " ");
	Format(buffer, sizeof(buffer), "->1. Survivors. - %d",Score_GetTeamCampaignScore(2));
	DrawPanelText(hSpecHud, buffer);

	new survivorCount;
	for (new client = 1; client <= MaxClients && survivorCount < GetConVarInt(survivor_limit); client++) 
	{
		if (!IsSurvivor(client))
			continue;

		GetClientFixedName(client, name, sizeof(name));
		if (!IsPlayerAlive(client))
		{
			Format(info, sizeof(info), "%s: Dead", name);
		}
		else
		{
			new WeaponId:primaryWep = IdentifyWeapon(GetPlayerWeaponSlot(client, _:L4DWeaponSlot_Primary));
			GetLongWeaponName(primaryWep, info, sizeof(info));
			GetMeleePrefix(client, buffer, sizeof(buffer)); 
			Format(info, sizeof(info), "%s/%s", info, buffer);
		
			if (IsSurvivorHanging(client))
			{
				Format(info, sizeof(info), "%s: %iHP <Hanging> [%s]", name, GetSurvivorHealth(client), info);
			}
			else if (IsIncapacitated(client))
			{
				Format(info, sizeof(info), "%s: %iHP <Incapped(#%i)> [%s]", name, GetSurvivorHealth(client), (GetSurvivorIncapCount(client) + 1), info);
			}
			else
			{
				new health = GetSurvivorHealth(client) + GetSurvivorTemporaryHealth(client);
				new incapCount = GetSurvivorIncapCount(client);
				if (incapCount == 0)
				{
					Format(info, sizeof(info), "%s: %iHP [%s]", name, health, info);
				}
				else
				{
					Format(buffer, sizeof(buffer), "%i incap%s", incapCount, (incapCount > 1 ? "s" : ""));
					Format(info, sizeof(info), "%s: %iHP (%s) [%s]", name, health, buffer, info);
				}
			}
		}

		survivorCount++;
		DrawPanelText(hSpecHud, info);
	}
}

FillInfectedInfo(Handle:hSpecHud) 
{
	decl String:info[512];
	decl String:buffer[64];
	decl String:name[MAX_NAME_LENGTH];

	DrawPanelText(hSpecHud, " ");
	Format(buffer, sizeof(buffer), "->2. Infected. - %d",Score_GetTeamCampaignScore(3));
	DrawPanelText(hSpecHud, buffer);

	new infectedCount;
	for (new client = 1; client <= MaxClients && infectedCount < GetConVarInt(z_max_player_zombies); client++) 
	{
		if (!IsInfected(client))
			continue;

		GetClientFixedName(client, name, sizeof(name));
		if (!IsPlayerAlive(client)) 
		{
			new spawnTimer = g_hSpawnGhostTimer[client];
			if (spawnTimer < 0)
			{
				Format(info, sizeof(info), "%s: Dead", name);
			}
			else
			{
				Format(buffer, sizeof(buffer), "%is", spawnTimer);
				Format(info, sizeof(info), "%s: Dead (%s)", name, (spawnTimer >0) ? buffer : "Spawning...");
			}
		}
		else 
		{
			new L4DSI:zClass = GetInfectedClass(client);
			if (zClass == ZC_Tank)
				continue;

			if (IsInfectedGhost(client))
			{
				// TO-DO: Handle a case of respawning chipped SI, show the ghost's health
				Format(info, sizeof(info), "%s: %s (Ghost)", name, ZOMBIECLASS_NAME(zClass));
			}
			else if (GetEntityFlags(client) & FL_ONFIRE)
			{
				Format(info, sizeof(info), "%s: %s (%iHP) [On Fire]", name, ZOMBIECLASS_NAME(zClass), GetClientHealth(client));
			}
			else
			{
				Format(info, sizeof(info), "%s: %s (%iHP)", name, ZOMBIECLASS_NAME(zClass), GetClientHealth(client));
			}
		}

		infectedCount++;
		DrawPanelText(hSpecHud, info);
	}
	
	if (!infectedCount)
	{
		DrawPanelText(hSpecHud, "There are no SI at this moment.");
	}
}
public OnTankFrustrated(Handle:event, const String:name[], bool:dontBroadcast)
{
	new tank = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsClientInGame(tank)) return;
	passCount++;
}

bool:FillTankInfo(Handle:hSpecHud, bool:bTankHUD = false)
{
	new tank = FindTank();
	if (tank == -1)
		return false;

	decl String:info[512];
	decl String:name[MAX_NAME_LENGTH];

	if (bTankHUD)
	{
		Format(info, sizeof(info), "%s :: Tank HUD", info);
		DrawPanelText(hSpecHud, info);
		DrawPanelText(hSpecHud, "___________________");
	}
	else
	{
		DrawPanelText(hSpecHud, " ");
		DrawPanelText(hSpecHud, "->3. Tank");
	}

	// Draw owner & pass counter
	switch (passCount)
	{
		case 0: Format(info, sizeof(info), "native");
		case 1: Format(info, sizeof(info), "%ist", passCount);
		case 2: Format(info, sizeof(info), "%ind", passCount);
		case 3: Format(info, sizeof(info), "%ird", passCount);
		default: Format(info, sizeof(info), "%ith", passCount);
	}

	if (!IsFakeClient(tank))
	{
		GetClientFixedName(tank, name, sizeof(name));
		Format(info, sizeof(info), "Control : %s (%s)", name, info);
	}
	else
	{
		Format(info, sizeof(info), "Control : AI (%s)", info);
	}
	DrawPanelText(hSpecHud, info);

	// Draw health
	new health = GetClientHealth(tank);
	if (health <= 0 || IsIncapacitated(tank) || !IsPlayerAlive(tank))
	{
		info = "Health  : Dead";
	}
	else
	{
		//new healthPercent = RoundFloat((100.0 / (GetConVarFloat(FindConVar("z_tank_health")) * 1.5)) * health);
		new healthPercent = RoundFloat(100.0 * health / (GetConVarFloat(FindConVar("z_tank_health"))));
		Format(info, sizeof(info), "Health  : %i / %i%%", health, ((healthPercent < 1) ? 1 : healthPercent));
	}
	DrawPanelText(hSpecHud, info);

	// Draw frustration
	if (!IsFakeClient(tank))
	{
		Format(info, sizeof(info), "Frustr.  : %d%%", GetTankFrustration(tank));
		DrawPanelText(hSpecHud, info);
		Format(info, sizeof(info), "Ping/Lerp  : %dms [%.1f]", 
									GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iPing", _, tank) ,
									GetLerpTime(tank) * 1000.0);
		DrawPanelText(hSpecHud, info);
	}

	// Draw fire status
	if (GetEntityFlags(tank) & FL_ONFIRE)
	{
		new timeleft = RoundToCeil(health / 80.0);
		Format(info, sizeof(info), "On Fire : %is", timeleft);
		DrawPanelText(hSpecHud, info);
	}

	return true;
}

FillGameInfo(Handle:hSpecHud)
{
	// Turns out too much info actually CAN be bad, funny ikr
	new tank = FindTank();
	if (tank != -1)//坦克存在
	{
		return;
	}

	DrawPanelText(hSpecHud, " ");
	DrawPanelText(hSpecHud, "->3. Game");
	decl String:info[512];

	//GetConVarString(FindConVar("l4d_ready_cfg_name"), info, sizeof(info));

	if (GetCurrentGameMode() == L4DGamemode_Versus)
	{
		//Format(info, sizeof(info), "%s (%s round)", info, (InSecondHalfOfRound() ? "2nd" : "1st"));
		//DrawPanelText(hSpecHud, info);
		Format(info, sizeof(info), "%t (%s round)", "ROTO_AZ_PLUGIN_VERSION", (InSecondHalfOfRound() ? "2nd" : "1st"));
		DrawPanelText(hSpecHud, info);
		
		/*Format(info, sizeof(info), "Natural horde: %is", CTimer_HasStarted(L4DDirect_GetMobSpawnTimer()) ? RoundFloat(CTimer_GetRemainingTime(L4DDirect_GetMobSpawnTimer())) : 0);
		DrawPanelText(hSpecHud, info);
		*/

		new Surcurrent = RoundToNearest(GetHighestSurvivorFlow() * 100.0);
		Surcurrent = Surcurrent>=100 ? 100 : Surcurrent;
		Format(info, sizeof(info), "Current: %i%%", Surcurrent);
		DrawPanelText(hSpecHud, info);

		new itank= WhoIsTank();
		decl String:infotank[56];

		if(itank== -1)
			Format(infotank, sizeof(infotank), " (Random)");
		else if (itank>0 && IsClientConnected(itank) && IsClientInGame(itank) && GetClientTeam(itank) == 3)
			Format(infotank, sizeof(infotank), " (%N)",itank);
		else
			Format(infotank, sizeof(infotank), "");
			
		iTankPercent = GetTankPercent();
		if (iTankPercent)
		{
			Format(info, sizeof(info), "Tank: %i%%%s", iTankPercent,infotank);
			DrawPanelText(hSpecHud, info);
		}
		else
		{
			Format(info, sizeof(info), "Tank: None%s",infotank);
			DrawPanelText(hSpecHud, info);
		}
		iWitchPercent = GetWitchPercent();
		if (iWitchPercent > 0)
		{
			Format(info, sizeof(info), "Witch: %i%%", iWitchPercent);
			DrawPanelText(hSpecHud, info);
		}
		else if (iWitchPercent == -2)
		{
			Format(info, sizeof(info), "Witch: Witch Party");
			DrawPanelText(hSpecHud, info);
		}
	}
}

/* Stocks */

GetClientFixedName(client, String:name[], length) 
{
	GetClientName(client, name, length);

	if (name[0] == '[') 
	{
		decl String:temp[MAX_NAME_LENGTH];
		strcopy(temp, sizeof(temp), name);
		temp[sizeof(temp)-2] = 0;
		strcopy(name[1], length-1, temp);
		name[0] = ' ';
	}

	if (strlen(name) > 25) 
	{
		name[22] = name[23] = name[24] = '.';
		name[25] = 0;
	}
}

GetRealClientCount() 
{
	new clients = 0;
	for (new i = 1; i <= MaxClients; i++) 
	{
		if (IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i)) clients++;
	}
	return clients;
}

bool:InSecondHalfOfRound()
{
	return bool:GameRules_GetProp("m_bInSecondHalfOfRound");
}

Float:GetHighestSurvivorFlow()
{
	new Float:proximity = GetMaxSurvivorCompletion() + (GetConVarFloat(g_hVsBossBuffer) / L4DDirect_GetMapMaxFlowDistance());
	//LogMessage("L4DDirect_GetMapMaxFlowDistance() is %f and GetConVarFloat(g_hVsBossBuffer) is %f",L4DDirect_GetMapMaxFlowDistance(),GetConVarFloat(g_hVsBossBuffer));
	return proximity;
}
//
stock Float:GetMaxSurvivorCompletion()
{
	new Float:flow = 0.0;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && IsClientInGame(i)&& GetClientTeam(i) == 2)
		{
			flow = MAX(flow, L4DDirect_GetFlowDistance(i));
			//LogMessage("flow is %f",flow);
		}
	}
	return (flow / L4DDirect_GetMapMaxFlowDistance());
}

bool:IsSpectator(client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 1;
}

bool:IsSurvivor(client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2;
}

bool:IsInfected(client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3;
}

bool:IsInfectedGhost(client) 
{
	return bool:GetEntProp(client, Prop_Send, "m_isGhost");
}

L4DSI:GetInfectedClass(client)
{
	return IsInfected(client) ? (L4DSI:GetEntProp(client, Prop_Send, "m_zombieClass")) : ZC_None;
}

FindTank() 
{
	for (new i = 1; i <= MaxClients; i++) 
	{
		if (IsInfected(i) && GetInfectedClass(i) == ZC_Tank && IsPlayerAlive(i))
			return i;
	}

	return -1;
}

GetTankFrustration(tank)
{
	return (100 - GetEntProp(tank, Prop_Send, "m_frustration"));
}

bool:IsIncapacitated(client)
{
	return bool:GetEntProp(client, Prop_Send, "m_isIncapacitated");
}

bool:IsSurvivorHanging(client)
{
	return bool:(GetEntProp(client, Prop_Send, "m_isHangingFromLedge") | GetEntProp(client, Prop_Send, "m_isFallingFromLedge"));
}

GetSurvivorIncapCount(client)
{
	return GetEntProp(client, Prop_Send, "m_currentReviveCount");
}

GetSurvivorTemporaryHealth(client)
{
	new temphp = RoundToCeil(GetEntPropFloat(client, Prop_Send, "m_healthBuffer") - ((GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * GetConVarFloat(FindConVar("pain_pills_decay_rate")))) - 1;
	return (temphp > 0 ? temphp : 0);
}

GetSurvivorHealth(client)
{
	return GetEntProp(client, Prop_Send, "m_iHealth");
}

L4DGamemode:GetCurrentGameMode()
{
	static String:sGameMode[32];
	if (sGameMode[0] == EOS)
	{
		GetConVarString(FindConVar("mp_gamemode"), sGameMode, sizeof(sGameMode));
	}
	if (StrContains(sGameMode, "versus") > -1
		|| StrEqual(sGameMode, "mutation12")) // realism versus
	{
		return L4DGamemode_Versus;
	}
	else
	{
		return L4DGamemode_None; // Unsupported
	}
}

public Action:PD_ev_EntityKilled(Handle:event, const String:name[], bool:dontBroadcast)
{
	decl client;
	if (IsPlayerTank((client = GetEventInt(event, "entindex_killed"))))
	{
		CreateTimer(1.5, FindAnyTank, client, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action:FindAnyTank(Handle:timer, any:client)
{
	if(!IsTankInGame()){
		passCount = 1;
	}
}
IsTankInGame(exclude = 0)
{
	for (new i = 1; i <= MaxClients; i++)
		if (exclude != i && IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerTank(i) && IsInfectedAlive(i) && !IsIncapacitated(i))
			return i;

	return 0;
}
stock bool:IsPlayerTank(tank_index)
{
	return GetEntProp(tank_index, Prop_Send, "m_zombieClass") == 5;
}
stock bool:IsInfectedAlive(client)
{
	return GetEntProp(client, Prop_Send, "m_iHealth") > 1;
}

/* Stocks */
Float:GetLerpTime(client)
{
	new Handle:cVarMinUpdateRate = FindConVar("sv_minupdaterate");
	new Handle:cVarMaxUpdateRate = FindConVar("sv_maxupdaterate");
	new Handle:cVarMinInterpRatio = FindConVar("sv_client_min_interp_ratio");
	new Handle:cVarMaxInterpRatio = FindConVar("sv_client_max_interp_ratio");

	decl String:buffer[64];
	
	if (!GetClientInfo(client, "cl_updaterate", buffer, sizeof(buffer))) buffer = "";
	new updateRate = StringToInt(buffer);
	updateRate = RoundFloat(CLAMP(float(updateRate), GetConVarFloat(cVarMinUpdateRate), GetConVarFloat(cVarMaxUpdateRate)));
	
	if (!GetClientInfo(client, "cl_interp_ratio", buffer, sizeof(buffer))) buffer = "";
	new Float:flLerpRatio = StringToFloat(buffer);
	
	if (!GetClientInfo(client, "cl_interp", buffer, sizeof(buffer))) buffer = "";
	new Float:flLerpAmount = StringToFloat(buffer);	
	
	if (cVarMinInterpRatio != INVALID_HANDLE && cVarMaxInterpRatio != INVALID_HANDLE && GetConVarFloat(cVarMinInterpRatio) != -1.0 ) {
		flLerpRatio = CLAMP(flLerpRatio, GetConVarFloat(cVarMinInterpRatio), GetConVarFloat(cVarMaxInterpRatio) );
	}
	
	return MAX(flLerpAmount, flLerpRatio / updateRate);
}