#include <sourcemod>
#include <sdktools>
#include <multicolors>

#pragma semicolon 1
#define PLUGIN_VERSION "8.1"
#define Info_PANEL_LIFETIME 5
#define Info_PANEL_LIFETIME_2 20
#define Info_PANEL_LIFETIME_3 30
#define L4D_TEAM_SURVIVORS 2
#define L4D_TEAM_INFECTED 3
#define L4D_TEAM_SPECTATE 1

new String:Config[25];
//new Tank_Speed;
new Tank_Percent,Witch_Percent,Tank_Health,Max_dmg;
new Spawn_Timers;
new bool:Deadstops,Wallkicks;
//new	Float:Smg_Reload_Time;
new survivorlimit;

native GetTankPercent();
native GetWitchPercent();
native GetSurCurrent();
static bool:ClientInfoMenu[MAXPLAYERS + 1];

public Plugin:myinfo = 
{
	name = "l4d_Harry_Roto2-AZ_mod_info",
	author = "Harry Potter",
	description = "Show my Roto2-AZ mod information when round is live or type command",
	version = PLUGIN_VERSION,
	url = "myself"
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	CreateNative("ShowRotoInfo",Native_ShowRotoInfo);
	CreateNative("IsClientInfoMenu", Native_IsClientInfoMenu);
	RegPluginLibrary("l4d_boss_percent");
	return APLRes_Success;
}

public Native_IsClientInfoMenu(Handle:plugin, numParams)
{
   new num1 = GetNativeCell(1);
   return ClientInfoMenu[num1];
}

public OnPluginStart()
{
	LoadTranslations("Roto2-AZ_mod.phrases");
	HookEvent("round_start", RoundStartEvent, EventHookMode_PostNoCopy);
	
	RegConsoleCmd("sm_info", InfoCmd);
	RegConsoleCmd("sm_harry", InfoCmd);
	
	RegConsoleCmd("sm_lang", InfoLanguage);
}

public RoundStartEvent(Handle:event, const String:name[], bool:dontBroadcast)
{
	for(new i=1; i <= MaxClients; i++) ClientInfoMenu[i] = false;
	survivorlimit = GetConVarInt(FindConVar("survivor_limit"));
	CreateTimer(6.0, SetInfo);
}

public Action:SetInfo(Handle:timer)
{
	GetConVarString(FindConVar("l4d_ready_league_notice"), Config, sizeof(Config));
	Tank_Health = GetConVarInt(FindConVar("z_tank_health"));
	Max_dmg = GetConVarInt(FindConVar("pounceuncap_maxdamage"));
	if(GetConVarInt(FindConVar("versus_shove_hunter_fov_pouncing")) == 0) Deadstops = false; else Deadstops = true;
	if(GetConVarInt(FindConVar("stop_wallkicking_enable")) == 0) Wallkicks = true; else Wallkicks = false;
	if(survivorlimit == 4 || survivorlimit == 1 || survivorlimit == 5)
		Spawn_Timers = GetConVarInt(FindConVar("z_ghost_delay_max"));
	else // 3 , 2
		Spawn_Timers = RoundToCeil(float(GetConVarInt(FindConVar("z_ghost_delay_max")) * survivorlimit) / 4);
}

public Native_ShowRotoInfo(Handle:plugin, numParams)
{
	for (new client = 1; client <= MaxClients; client++)
		if (IsClientConnected(client) && IsClientInGame(client)&& !IsFakeClient(client))
				FillRotoInfo1(client);
}

public Action:InfoCmd(client, args)
{
	if(!IsClientConnected(client) || IsFakeClient(client))
		return;
		
	ClientInfoMenu[client] = true;
	FillRotoInfo1(client);
}

public Action:InfoLanguage(client, args)
{
	if (client == 0)
	{
		PrintToServer("[TS] %T","command cannot be used by server.",client);
		return;
	}
	if(!IsClientConnected(client) || IsFakeClient(client)) return;
	PrintToChat(client,"<%T>","Language",client);
}

public FillRotoInfo1(client)
{
	decl String:Info[256];
	new Handle:InfoHud = CreatePanel();

	decl String:versionInfo[40];
	Format(versionInfo, 40, "%T %T", "ROTO_AZ_PLUGIN_VERSION",client,"Information",client);
	DrawPanelText(InfoHud, versionInfo);
	
	DrawPanelItem(InfoHud, Config);
	
	Tank_Percent = GetTankPercent();
	
	if(Tank_Percent == 0)
		Format(Info, sizeof(Info), "%T: None", "Tank_Spawn", client);
	else
		Format(Info, sizeof(Info), "%T: %d%%", "Tank_Spawn", client, Tank_Percent);
		
	DrawPanelText(InfoHud, Info);
	
	Witch_Percent = GetWitchPercent();
	
	if (Witch_Percent > 0)
		Format(Info, sizeof(Info), "%T: %d%%", "Witch_Spawn", client, Witch_Percent);
	else if (Witch_Percent == -2)
		Format(Info, sizeof(Info), "%T: Witch Party", "Witch_Spawn",client);
	else
		Format(Info, sizeof(Info), "%T: None", "Witch_Spawn",client);
	DrawPanelText(InfoHud, Info);
	
	Format(Info, sizeof(Info), "%T: %d","Tank_Health",client, Tank_Health);
	DrawPanelText(InfoHud, Info);
	
	
	Format(Info, sizeof(Info), "%T: %d", "Max_Pounce_Damage", client, Max_dmg);
	DrawPanelText(InfoHud, Info);
	
	Format(Info, sizeof(Info), "%T: %T", "Wallkicks", client, Wallkicks ? "Yes" : "No", client);
	DrawPanelText(InfoHud, Info);
	
	Format(Info, sizeof(Info), "%T: %T", "Deadstops", client, Deadstops ? "Yes" : "No", client);
	DrawPanelText(InfoHud, Info);
	
	Format(Info, sizeof(Info), "%T: %d", "Spawn_Timer", client, Spawn_Timers);
	DrawPanelText(InfoHud, Info);
	
	Format(Info, sizeof(Info), "%T", "Commands", client);
	DrawPanelItem(InfoHud, Info);
	
	Format(Info, sizeof(Info), "%T", "More", client);
	DrawPanelItem(InfoHud, Info);
	SendPanelToClient(InfoHud, client, PanelHandler1, Info_PANEL_LIFETIME);
	CloseHandle(InfoHud);
}

public FillRotoInfo2(client)
{
	decl String:Info[256];
	new Handle:InfoHud2 = CreatePanel();
	
	Format(Info, sizeof(Info), "%T", "Commands", client);
	DrawPanelItem(InfoHud2, Info);

	Format(Info, sizeof(Info), "!s,!spec,!afk,!away: %T", "Spectator", client);
	DrawPanelText(InfoHud2, Info);
	Format(Info, sizeof(Info), "!sur: %T", "Survivor", client);
	DrawPanelText(InfoHud2, Info);
	Format(Info, sizeof(Info), "!inf: %T", "Infected", client);
	DrawPanelText(InfoHud2, Info);
	Format(Info, sizeof(Info), "!boss: %T", "Boss_Percent", client);
	DrawPanelText(InfoHud2, Info);
	Format(Info, sizeof(Info), "!cur: %T", "Survivor_Current", client);
	DrawPanelText(InfoHud2, Info);
	Format(Info, sizeof(Info), "!votes: %T", "Vote", client);
	DrawPanelText(InfoHud2, Info);
	Format(Info, sizeof(Info), "!score: %T", "Show_Scores", client);
	DrawPanelText(InfoHud2, Info);
	Format(Info, sizeof(Info), "!health: %T", "Round_Scores", client);
	DrawPanelText(InfoHud2, Info);
	
	Format(Info, sizeof(Info), "%T", "next", client);
	DrawPanelItem(InfoHud2, Info);
	DrawPanelText(InfoHud2, "    ");
	Format(Info, sizeof(Info), "%T", "back", client);
	DrawPanelItem(InfoHud2, Info);
	SendPanelToClient(InfoHud2, client, PanelHandler2, Info_PANEL_LIFETIME_2);
	CloseHandle(InfoHud2);
}

public FillRotoInfo2_2(client)
{
	decl String:Info[256];
	new Handle:InfoHud2_2 = CreatePanel();

	Format(Info, sizeof(Info), "%T", "Commands", client);
	DrawPanelItem(InfoHud2_2, Info);
	
	Format(Info, sizeof(Info), "!pause: %T", "Pause", client);
	DrawPanelText(InfoHud2_2, Info);
	Format(Info, sizeof(Info), "!kills: %T", "Stats", client);
	DrawPanelText(InfoHud2_2, Info);
	Format(Info, sizeof(Info), "!mvp: %T", "MVP", client);
	DrawPanelText(InfoHud2_2, Info);
	Format(Info, sizeof(Info), "!tankhud: %T", "Tankhud", client);
	DrawPanelText(InfoHud2_2, Info);
	Format(Info, sizeof(Info), "!spechud: %T", "Spechud", client);
	DrawPanelText(InfoHud2_2, Info);
	Format(Info, sizeof(Info), "!hear: %T", "Listen_Mode", client);
	DrawPanelText(InfoHud2_2, Info);
	Format(Info, sizeof(Info), "!ps: %T", "Print_Scores", client);
	DrawPanelText(InfoHud2_2, Info);
	Format(Info, sizeof(Info), "!warpto <#|name>: %T", "WarpToSurvivor", client);
	DrawPanelText(InfoHud2_2, Info);
	
	Format(Info, sizeof(Info), "%T", "next", client);
	DrawPanelItem(InfoHud2_2, Info);
	Format(Info, sizeof(Info), "%T", "previous", client);
	DrawPanelItem(InfoHud2_2, Info);
	SendPanelToClient(InfoHud2_2, client, PanelHandler2_2, Info_PANEL_LIFETIME_2);
	CloseHandle(InfoHud2_2);
}

public FillRotoInfo2_3(client)
{
	decl String:Info[256];
	new Handle:InfoHud2_3 = CreatePanel();
	
	Format(Info, sizeof(Info), "%T", "Commands", client);
	DrawPanelItem(InfoHud2_3, Info);
	
	Format(Info, sizeof(Info), "!load: %T", "Change_Match", client);
	DrawPanelText(InfoHud2_3, Info);
	Format(Info, sizeof(Info), "!cm: %T", "Change_Map", client);
	DrawPanelText(InfoHud2_3, Info);
	Format(Info, sizeof(Info), "!info(!harry): %T", "Plugin_Information", client);
	DrawPanelText(InfoHud2_3, Info);
	Format(Info, sizeof(Info), "!lerps: %T", "Show_Player_Lerp", client);
	DrawPanelText(InfoHud2_3, Info);
	Format(Info, sizeof(Info), "!respec: %T", "Force_Player_Respectate", client);
	DrawPanelText(InfoHud2_3, Info);
	Format(Info, sizeof(Info), "!jukestop: %T", "Stop_Jukebox", client);
	DrawPanelText(InfoHud2_3, Info);
	Format(Info, sizeof(Info), "!random: %T", "Auto_Choose_Team", client);
	DrawPanelText(InfoHud2_3, Info);
	Format(Info, sizeof(Info), "!roll,!code,!coin: %T", "Game", client);
	DrawPanelText(InfoHud2_3, Info);
	
	Format(Info, sizeof(Info), "%T", "next", client);
	DrawPanelItem(InfoHud2_3, Info);
	Format(Info, sizeof(Info), "%T", "previous", client);
	DrawPanelItem(InfoHud2_3, Info);
	SendPanelToClient(InfoHud2_3, client, PanelHandler2_3, Info_PANEL_LIFETIME_2);
	CloseHandle(InfoHud2_3);
}

public FillRotoInfo2_4(client)
{
	decl String:Info[256];
	new Handle:InfoHud2_4 = CreatePanel();
	
	Format(Info, sizeof(Info), "%T", "Commands", client);
	DrawPanelItem(InfoHud2_4, Info);
	
	Format(Info, sizeof(Info), "!mix: %T", "Mix", client);
	DrawPanelText(InfoHud2_4, Info);
	Format(Info, sizeof(Info), "!shuffle: %T", "Team_Shuffle", client);
	DrawPanelText(InfoHud2_4, Info);
	Format(Info, sizeof(Info), "!slots: %T", "Change_Server_Slots", client);
	DrawPanelText(InfoHud2_4, Info);
	Format(Info, sizeof(Info), "!kickspec: %T", "Kick_All_Spectators", client);
	DrawPanelText(InfoHud2_4, Info);
	Format(Info, sizeof(Info), "!ht: %T(witch party、multi Hunters)", "HunterBot_Limit", client);
	DrawPanelText(InfoHud2_4, Info);
	Format(Info, sizeof(Info), "!timer: %T(witch party、multi Hunters)", "Bot_Spawn_Timer", client);
	DrawPanelText(InfoHud2_4, Info);
	Format(Info, sizeof(Info), "!speaklist: %T", "Close_Speaklist", client);
	DrawPanelText(InfoHud2_4, Info);
	Format(Info, sizeof(Info), "!voteboss: %T", "Vote_Boss_Percent", client);
	DrawPanelText(InfoHud2_4, Info);
	
	Format(Info, sizeof(Info), "%T", "next", client);
	DrawPanelItem(InfoHud2_4, Info);
	Format(Info, sizeof(Info), "%T", "previous", client);
	DrawPanelItem(InfoHud2_4, Info);
	SendPanelToClient(InfoHud2_4, client, PanelHandler2_4, Info_PANEL_LIFETIME_2);
	CloseHandle(InfoHud2_4);
}

public FillRotoInfo2_5(client)
{
	decl String:Info[256];
	new Handle:InfoHud2_5 = CreatePanel();
	
	Format(Info, sizeof(Info), "%T", "Commands", client);
	DrawPanelItem(InfoHud2_5, Info);
	
	Format(Info, sizeof(Info), "!top5: %T", "Top_5_Skeeter", client);
	DrawPanelText(InfoHud2_5, Info);
	Format(Info, sizeof(Info), "!rank: %T", "Show_Your_Skeet_Rank",client);
	DrawPanelText(InfoHud2_5, Info);
	Format(Info, sizeof(Info), "!skeets: %T", "Show_Your_Skeets", client);
	DrawPanelText(InfoHud2_5, Info);
	Format(Info, sizeof(Info), "!pounce5: %T", "Top_5_Pouncer", client);
	DrawPanelText(InfoHud2_5, Info);
	Format(Info, sizeof(Info), "!pounces: %T", "Show_Your_Pounce_Stats",client);
	DrawPanelText(InfoHud2_5, Info);
	
	Format(Info, sizeof(Info), "%T", "previous", client);
	DrawPanelItem(InfoHud2_5, Info);
	SendPanelToClient(InfoHud2_5, client, PanelHandler2_5, Info_PANEL_LIFETIME_2);
	CloseHandle(InfoHud2_5);
}

public FillRotoInfo3(client)
{
	decl String:Info[256];
	new Handle:InfoHud3 = CreatePanel();
	
	Format(Info, sizeof(Info), "%T %T: !info", "About", client,"ROTO_AZ_PLUGIN_VERSION", client);
	DrawPanelItem(InfoHud3, Info);
	Format(Info, sizeof(Info), "+%T L4D2 Acemod、Zonemod、Nextmod、L4D1 rotoblin2", "Based_on", client);
	DrawPanelText(InfoHud3, Info);
	Format(Info, sizeof(Info), "+%T: 5v5、multi Hunters、Witch Party、Dark Coop", "New_Mode", client);
	DrawPanelText(InfoHud3, Info);
	Format(Info, sizeof(Info), "+%T", "Nerf_Hunting_Rifle", client);
	DrawPanelText(InfoHud3, Info);
	Format(Info, sizeof(Info), "+%T", "Extra_Pills", client);
	DrawPanelText(InfoHud3, Info);
	Format(Info, sizeof(Info), "+%T", "UZI_more_powerful", client);
	DrawPanelText(InfoHud3, Info);
	Format(Info, sizeof(Info), "+%T", "More_Map_barriers", client);
	DrawPanelText(InfoHud3, Info);
	Format(Info, sizeof(Info), "+%T", "Final_Stage_balance", client);
	DrawPanelText(InfoHud3, Info);
	Format(Info, sizeof(Info), "+%T Harry、乘風", "Developed_by", client);
	DrawPanelText(InfoHud3, Info);
	
	Format(Info, sizeof(Info), "%T", "Scores_calculation",client);
	DrawPanelItem(InfoHud3, Info);
	DrawPanelText(InfoHud3, "    ");
	Format(Info, sizeof(Info), "%T", "back", client);
	DrawPanelItem(InfoHud3, Info);
	SendPanelToClient(InfoHud3, client, PanelHandler3, Info_PANEL_LIFETIME_3);
	CloseHandle(InfoHud3);
}

public FillRotoInfo3_2(client)
{
	decl String:Info[256];
	new Handle:InfoHud3_2 = CreatePanel();
	
	Format(Info, sizeof(Info), "%T: !health", "Round_Scores", client);
	DrawPanelItem(InfoHud3_2, Info);
	DrawPanelText(InfoHud3_2, "(AD + HB + PILLS) * Alive * Map");
	Format(Info, sizeof(Info), "-AD = %T", "Average_Distance", client);
	DrawPanelText(InfoHud3_2, Info);
	Format(Info, sizeof(Info), "-HB = %T , (%T/2) + (%T/4)", "Health_Bonus", client, "PermanentHealth", client,"TemporaryHealth", client);
	DrawPanelText(InfoHud3_2, Info);
	Format(Info, sizeof(Info), "-PILLS = %T", "Bonus_per_pill", client);
	DrawPanelText(InfoHud3_2, Info);
	Format(Info, sizeof(Info), "-Alive = %T", "Number_of_players_that_survived", client);
	DrawPanelText(InfoHud3_2, Info);
	Format(Info, sizeof(Info), "-Map = %T", "level_score_multiplier", client);
	DrawPanelText(InfoHud3_2, Info);

	Format(Info, sizeof(Info), "%T", "previous", client);
	DrawPanelItem(InfoHud3_2, Info);
	SendPanelToClient(InfoHud3_2, client, PanelHandler3_2, Info_PANEL_LIFETIME_3);
	CloseHandle(InfoHud3_2);
}

public PanelHandler1(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		if(param2==1)
			FillRotoInfo1(param1);
		else if(param2==2)
		{
			FillRotoInfo2(param1);
		}
		else if(param2==3)
		{
			FillRotoInfo3(param1);
		}
		
	} else if (action == MenuAction_Cancel) {
		ClientInfoMenu[param1] = false;
	}
}

public PanelHandler2(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		if(param2==1)
		{
			FillRotoInfo2(param1);
		}
		else if(param2==2)
		{
			FillRotoInfo2_2(param1);
		}
		else if(param2==3)
		{
			FillRotoInfo1(param1);
		}	
		
	} else if (action == MenuAction_Cancel) {
		ClientInfoMenu[param1] = false;
	}
}

public PanelHandler2_2(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		if(param2==1)
		{
			FillRotoInfo2_2(param1);
		}
		else if(param2==2)
			FillRotoInfo2_3(param1);
		else if(param2==3)
			FillRotoInfo2(param1);
		
	} else if (action == MenuAction_Cancel) {
		ClientInfoMenu[param1] = false;
	}
}

public PanelHandler2_3(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		if(param2==1)
		{
			FillRotoInfo2_3(param1);
		}
		else if(param2==2)
			FillRotoInfo2_4(param1);
		else if(param2==3)
			FillRotoInfo2_2(param1);
		
	} else if (action == MenuAction_Cancel) {
		ClientInfoMenu[param1] = false;
	}
}

public PanelHandler2_4(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		if(param2==1)
		{
			FillRotoInfo2_4(param1);
		}
		else if(param2==2)
			FillRotoInfo2_5(param1);
		else if(param2==3)
			FillRotoInfo2_3(param1);
		
	} else if (action == MenuAction_Cancel) {
		ClientInfoMenu[param1] = false;
	}
}

public PanelHandler2_5(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		if(param2==1)
		{
			FillRotoInfo2_5(param1);
		}
		else if(param2==2)
			FillRotoInfo2_4(param1);
		
	} else if (action == MenuAction_Cancel) {
		ClientInfoMenu[param1] = false;
	}
}

public PanelHandler3(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		if(param2==1)
		{
			FillRotoInfo3(param1);
		}
		else if(param2==2)
			FillRotoInfo3_2(param1);
		else if(param2==3)
			FillRotoInfo1(param1);
		
	} else if (action == MenuAction_Cancel) {
		ClientInfoMenu[param1] = false;
	}
}

public PanelHandler3_2(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		if(param2==1)
		{
			FillRotoInfo3_2(param1);
		}
		else if(param2==2)
			FillRotoInfo3(param1);
		
	} else if (action == MenuAction_Cancel) {
		ClientInfoMenu[param1] = false;
	}
}