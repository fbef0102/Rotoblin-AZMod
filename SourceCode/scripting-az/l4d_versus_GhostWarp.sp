#include <sourcemod>
#include <sdktools>
#include <multicolors>
#include <left4dhooks>

#define L4D_TEAM_SURVIVORS 2
#define L4D_TEAM_INFECTED 3
#define L4D_TEAM_SPECTATE 1

static  bool:g_bDelay[MAXPLAYERS+1], g_iLastTarget[MAXPLAYERS+1];
new		SurvivorIndex[MAXPLAYERS+1],SurvivorCount;
bool DisableGhostM2Teleport[MAXPLAYERS+1];
//native	IsInReady();

new Handle:hNameToCharIDTrie;
public Plugin:myinfo = 
{
	name = "l4d_versus_GhostWarp",
	author = "CanadaRox,L4D1 port by Harry",
	description = "Allows infected to warp to survivors based on their flow (MOUSE2 or use command)",
	version = "1.3",
	url = "myself"
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
    CreateNative("RebuildIndex", Native_RebuildIndex);
    return APLRes_Success;
}

public  OnPluginStart()
{
	LoadTranslations("Roto2-AZ_mod.phrases");
	HookEvent("player_death", GW_ev_PlayeDeath);
	HookEvent("round_start", event_round_start);
	HookEvent("player_team", event_player_teamchange,EventHookMode_Pre);
	HookEvent("player_disconnect", 	Event_PlayerDisconnect, EventHookMode_Pre);

	PrepTries();

	RegConsoleCmd("sm_warpto", WarpTo_Cmd, "Warps to the specified survivor");

	RegConsoleCmd("sm_warpm2on",	Enable_Cmd, "Enable the ghost m2 teleport");
	RegConsoleCmd("sm_warpm2off",	Disable_Cmd, "Disable the ghost m2 teleport");
	
}

PrepTries()
{
	hNameToCharIDTrie = CreateTrie();
	SetTrieValue(hNameToCharIDTrie, "bill", 0);
	SetTrieValue(hNameToCharIDTrie, "zoey", 1);
	SetTrieValue(hNameToCharIDTrie, "francis", 2);
	SetTrieValue(hNameToCharIDTrie, "louis", 3);

}

public Action:WarpTo_Cmd(client, args)
{
	if (!IsGhostInfected(client))
	{
		return Plugin_Handled;
	}

	if (args != 1)
	{
		ReplyToCommand(client, "Usage: sm_warpto <#|name> (1|Francis, 2|Bill, 3|Zoey, 4|Louis) - %T","l4d_versus_GhostWarp",client);
		return Plugin_Handled;
	}
	
	decl String:arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	
	if(StrEqual(arg,"3") || StrEqual(arg,"Zoey")||StrEqual(arg,"ZOEY"))	
		arg = "zoey";
	else if(StrEqual(arg,"4") || StrEqual(arg,"Louis")||StrEqual(arg,"LOUIS"))
		arg = "louis";
	else if(StrEqual(arg,"2") || StrEqual(arg,"Bill")||StrEqual(arg,"BILL"))
		arg = "bill";
	else if(StrEqual(arg,"1") || StrEqual(arg,"Francis")||StrEqual(arg,"FRANCIS"))
		arg = "francis";
	
	decl target;
	if (GetTrieValue(hNameToCharIDTrie, arg, target))
	{
		target = GetClientOfCharID(target);
		decl Float:origin[3];
		GetClientAbsOrigin(target, origin);
		TeleportEntity(client, origin, NULL_VECTOR, NULL_VECTOR);
	}

	return Plugin_Handled;
}

public Action Disable_Cmd(int client, int args)
{
	if(client == 0) return Plugin_Handled;

	if(GetClientTeam(client) != 3) return Plugin_Handled;

	DisableGhostM2Teleport[client] = true;

	CPrintToChat(client, "[{olive}TS{default}] Ghost M2 Teleport {green}Disabled.");

	return Plugin_Handled;
}

public Action Enable_Cmd(int client, int args)
{
	if(client == 0) return Plugin_Handled;

	if(GetClientTeam(client) != 3) return Plugin_Handled;

	DisableGhostM2Teleport[client] = false;

	CPrintToChat(client, "[{olive}TS{default}] Ghost M2 Teleport {green}Enabled.");

	return Plugin_Handled;
}

stock GetClientOfCharID(characterID)
{
	for (new client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && GetClientTeam(client) == 2)
		{
			if (GetEntProp(client, Prop_Send, "m_survivorCharacter") == characterID)
				return client;
		}
	}
	return 0;
}
public GW_ev_PlayeDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	g_iLastTarget[client] = 0;
}

public Action:OnPlayerRunCmd(client, &buttons)
{
	if( (buttons & IN_ATTACK2) && SurvivorCount && !g_bDelay[client] && !IsFakeClient(client) && IsGhostInfected(client))
	{
		if(DisableGhostM2Teleport[client] == false)
		{
			g_bDelay[client] = true;
			CreateTimer(0.35, GW_t_ResetDelay, client);
			GW_WarpToSurvivor(client);
		}
	}
	return Plugin_Continue;
}
stock IsGhostInfected(client)
{
	return GetClientTeam(client) == L4D_TEAM_INFECTED && IsPlayerAlive(client) && GetEntProp(client, Prop_Send, "m_isGhost");
}
GW_WarpToSurvivor(client)
{
	if (!SurvivorCount) return;

	new target = SurvivorIndex[g_iLastTarget[client]];

	if (!target){

		g_iLastTarget[client] = 0;
		GW_WarpToSurvivor(client);
		return;
	}
	if (!IsClientInGame(target)) return;

	// Prevent people from spawning and then warp to survivor
	SetEntProp(client, Prop_Send, "m_ghostSpawnState", 256);

	decl Float:position[3], Float:anglestarget[3];

	GetClientAbsOrigin(target, position);
	GetClientAbsAngles(target, anglestarget);

	TeleportEntity(client, position, anglestarget, NULL_VECTOR);

	if (++g_iLastTarget[client] == SurvivorCount)
		g_iLastTarget[client] = 0;
}

public Action:GW_t_ResetDelay(Handle:timer, any:client)
{
	g_bDelay[client] = false;
}

/*
stock _GW_CvarDump()
{
	decl bool:iVal;
	if ((iVal = GetConVarBool(g_hWarpEnable)) != g_bWarpEnable)
		DebugLog("%d		|	%d		|	rotoblin_ghost_warp", iVal, g_bWarpEnable);
}
*/
public Native_RebuildIndex(Handle:plugin, numParams)
{
	ResetCounts();

	if (!IsServerProcessing()) return;

	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i)) continue;

		switch (GetClientTeam(i))
		{
			case L4D_TEAM_SURVIVORS:
			{
				if (IsPlayerAlive(i))
					SurvivorIndex[SurvivorCount++] = i;
			}
		}
	}
}

MyPlugin_RebuildIndex()
{
	ResetCounts();

	if (!IsServerProcessing()) return;

	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i)) continue;

		switch (GetClientTeam(i))
		{
			case L4D_TEAM_SURVIVORS:
			{
				if (IsPlayerAlive(i))
					SurvivorIndex[SurvivorCount++] = i;
			}
		}
	}
}

static ResetCounts()
{
	SurvivorCount = 0;
}

public event_round_start(Handle:event, const String:name[], bool:dontBroadcast)//回合開始reset
{
	MyPlugin_RebuildIndex();
}

public event_player_teamchange(Handle:event, String:name[], bool:dontBroadcast)//有人跳隊到則reset
{
		
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(client&&IsClientInGame(client)&& GetClientTeam(client) == L4D_TEAM_SURVIVORS)//從sur 跳隊
		MyPlugin_RebuildIndex();
		
	CreateTimer(1.0,PlayerChangeTeamCheck,client);//延遲一秒檢查
}

public Action:PlayerChangeTeamCheck(Handle:timer,any:client)//跳隊到sur
{
	if (client && IsClientInGame(client)&& GetClientTeam(client) == L4D_TEAM_SURVIVORS)
		MyPlugin_RebuildIndex();
}

public void Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	DisableGhostM2Teleport[client] = false;
}