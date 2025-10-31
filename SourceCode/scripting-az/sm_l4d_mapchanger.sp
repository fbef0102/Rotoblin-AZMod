#pragma semicolon 1
#include <sourcemod>
#include <left4dhooks>
#include <multicolors>

#define Version "1.5.1-2025/11/1"
#define MAX_ARRAY_LINE 50
#define MAX_MAPNAME_LEN 64
#define MAX_CREC_LEN 2
#define MAX_REBFl_LEN 8

new Handle:cvarAnnounce = INVALID_HANDLE;
new Handle:Allowed = INVALID_HANDLE;
new Handle:DefM;
new Handle:CheckRoundCounter;
new Handle:ChDelayVS;
new Handle:ChDelayCOOP;
new Handle:TimerRoundEndBlockVS;

new Handle:hKVSettings = INVALID_HANDLE;

new String:FMC_FileSettings[128];
new String:current_map[64];
new String:announce_map[64];
new String:next_mission_def[64];
new String:next_mission_force[64];
new String:force_mission_name[64];
new RoundEndCounter = 0;
new RoundEndCounterValue = 0;
new RoundEndBlock = 0;
new Float:RoundEndBlockValue = 0.0;

new String:MapNameArrayLine[MAX_ARRAY_LINE][MAX_MAPNAME_LEN];
new String:CrecNumArrayLine[MAX_ARRAY_LINE][MAX_CREC_LEN];
new String:reBlkFlArrayLine[MAX_ARRAY_LINE][MAX_REBFl_LEN];
new g_ArrayCount = 0;

public Plugin:myinfo = 
{
	name = "L4D Force Mission Changer",
	author = "Dionys, HarryPotter",
	description = "Force change to next mission when current mission end.",
	version = Version,
	url = "https://github.com/fbef0102/Rotoblin-AZMod"
};

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
	decl String:ModName[50];
	GetGameFolderName(ModName, sizeof(ModName));

	hKVSettings=CreateKeyValues("ForceMissionChangerSettings");

	HookEvent("round_end", Event_RoundEnd);
	HookEvent("finale_win", Event_FinalWin);
	
	CreateConVar("sm_l4d_fmc_version", Version, "Version of L4D Force Mission Changer plugin.", FCVAR_NOTIFY);
	Allowed = CreateConVar("sm_l4d_fmc", "1", "Enables Force changelevel when mission end.");
	DefM = CreateConVar("sm_l4d_fmc_def", "l4d_vs_hospital01_apartment", "Mission for change by default.");
	CheckRoundCounter = CreateConVar("sm_l4d_fmc_crec", "4", "Quantity of events RoundEnd before force of changelevel in versus: 4 for l4d <> 1.0.1.2");
	ChDelayVS = CreateConVar("sm_l4d_fmc_chdelayvs", "0.0", "Delay before versus mission change (float in sec).");
	ChDelayCOOP = CreateConVar("sm_l4d_fmc_chdelaycoop", "0.0", "Delay before coop mission change (float in sec).");
	TimerRoundEndBlockVS = CreateConVar("sm_l4d_fmc_re_timer_block", "0.5", "Time in which current event round_end is not considered (float in sec).");
	cvarAnnounce = CreateConVar("sm_l4d_fmc_announce", "1", "Enables next mission to advertise to players.");
	//AutoExecConfig(true, "sm_l4d_mapchanger");

	//For custom crec
	RegServerCmd("sm_l4d_fmc_crec_add", Command_CrecAdd, "Add custom value sm_l4d_fmc_crec and sm_l4d_fmc_re_timer_block for the specified map. Max 50.");
	RegServerCmd("sm_l4d_fmc_crec_clear", Command_CrecClear, "Clear all custom value sm_l4d_fmc_crec and sm_l4d_fmc_re_timer_block.");
	RegServerCmd("sm_l4d_fmc_crec_list", Command_CrecList, "Show all custom value sm_l4d_fmc_crec and sm_l4d_fmc_re_timer_block.");
}

bool g_bFinalMap;
public OnMapStart()
{
	// Execute the config file

	RoundEndCounter = 0;
	RoundEndBlock = 0;
	g_bFinalMap = L4D_IsMissionFinalMap(true);

	if(GetConVarInt(Allowed) == 1)
	{
		PluginInitialization();
	}
}

public OnClientPutInServer(client)
{
	// Make the announcement in 20 seconds unless announcements are turned off
	if(client && !IsFakeClient(client) && GetConVarBool(cvarAnnounce) && g_bFinalMap)
		CreateTimer(20.0, TimerAnnounce, client, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (RoundEndBlock == 0)
	{
		RoundEndCounter += 1;
		RoundEndBlock = 1;
		CreateTimer(GetConVarFloat(TimerRoundEndBlockVS), TimerRoundEndBlock);
	}
	
	if(GetConVarInt(Allowed) == 1 
		&& g_bFinalMap
		&& L4D_GetGameModeType() == GAMEMODE_VERSUS 
		&& StrEqual(next_mission_force, "none") != true 
		&& GetConVarInt(CheckRoundCounter) != 0 
		&& RoundEndCounter >= RoundEndCounterValue)
	{
		CreateTimer(RoundEndBlockValue, TimerChDelayVS);
		RoundEndCounter = 0;
	}
}

public Action:Event_FinalWin(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(GetConVarInt(Allowed) == 1 
		&& g_bFinalMap
		&& L4D_GetGameModeType() == GAMEMODE_COOP 
		&& StrEqual(next_mission_force, "none") != true)
	{
		CreateTimer(GetConVarFloat(ChDelayCOOP), TimerChDelayCOOP);
	}
}

public Action:TimerAnnounce(Handle:timer, any:client)
{
	if(IsClientInGame(client))
	{
		if (StrEqual(next_mission_force, "none") != true)
		{
			CPrintToChat(client, "{default}[{olive}TS{default}] %T","sm_l4d_mapchanger1",client, announce_map);
		}
	}
}

public Action:TimerRoundEndBlock(Handle:timer)
{
	RoundEndBlock = 0;
}

public Action:TimerChDelayVS(Handle:timer)
{
	ServerCommand("changelevel %s", next_mission_force);
}

public Action:TimerChDelayCOOP(Handle:timer)
{
	ServerCommand("changelevel %s", next_mission_force);
}

public Action:Command_CrecClear(args)
{
	g_ArrayCount = 0;
	PrintToServer("[FMC] Custom value sm_l4d_fmc_crec now is clear.");
}

public Action:Command_CrecAdd(args)
{
	if (g_ArrayCount == MAX_ARRAY_LINE)
	{
		PrintToServer("[FMC] Max number of array line for sm_l4d_fmc_crec_add reached.");
		return;
	}

	decl String:cmdarg1[MAX_MAPNAME_LEN];
	GetCmdArg(1, cmdarg1, sizeof(cmdarg1));
	decl String:cmdarg2[MAX_CREC_LEN];
	GetCmdArg(2, cmdarg2, sizeof(cmdarg2));
	decl String:cmdarg3[MAX_REBFl_LEN];
	GetCmdArg(3, cmdarg3, sizeof(cmdarg3));

	// Check for doubles
	new bool:isDouble = false;
	for (new i = 0; i < g_ArrayCount; i++)
	{
		if (StrEqual(cmdarg1, MapNameArrayLine[i]) == true)
		{
			isDouble = true;
			break;
		}
	}

	if (IsMapValid(cmdarg1) && StringToInt(cmdarg2) != 0 && StringToFloat(cmdarg3) != 0.0)
	{
		if (!isDouble)
		{
			strcopy(MapNameArrayLine[g_ArrayCount], MAX_MAPNAME_LEN, cmdarg1);
			strcopy(CrecNumArrayLine[g_ArrayCount], MAX_CREC_LEN, cmdarg2);
			strcopy(reBlkFlArrayLine[g_ArrayCount], MAX_REBFl_LEN, cmdarg3);
			g_ArrayCount++;
		}
	}
	else
		PrintToServer("[FMC] Error command. Use: sm_l4d_fmc_crec_add <existing custom map> <custom sm_l4d_fmc_crec integer value (max 99)> <custom sm_l4d_fmc_re_timer_block float value>.");
}

public Action:Command_CrecList(args)
{
	PrintToServer("[FMC] Custom value sm_l4d_fmc_crec and sm_l4d_fmc_re_timer_block list:");
	for (new i = 0; i < g_ArrayCount; i++)
	{
		PrintToServer("[%d] %s - %s - %s", i, MapNameArrayLine[i], CrecNumArrayLine[i], reBlkFlArrayLine[i]);
	}
	PrintToServer("[FMC] Custom value sm_l4d_fmc_crec and sm_l4d_fmc_re_timer_block list end.");
}

ClearKV(Handle:kvhandle)
{
	KvRewind(kvhandle);
	if (KvGotoFirstSubKey(kvhandle))
	{
		do
		{
			KvDeleteThis(kvhandle);
			KvRewind(kvhandle);
		}
		while (KvGotoFirstSubKey(kvhandle));
		KvRewind(kvhandle);
	}
}

PluginInitialization()
{
	decl String:OldPlugin[128];
	BuildPath(Path_SM, OldPlugin, sizeof(OldPlugin), "plugins/sm_l4dvs_mapchanger.smx");
	if(FileExists(OldPlugin))
	{
		ServerCommand("sm plugins unload sm_l4dvs_mapchanger");
		DeleteFile(OldPlugin);
		PrintToServer("[FMC] Old sm_l4dvs_mapchanger has been unload and deleted.");
	}

	ClearKV(hKVSettings);
	int GameMode = L4D_GetGameModeType();
	if (GameMode == GAMEMODE_COOP)
	{
		BuildPath(Path_SM, FMC_FileSettings, 128, "data/sm_l4dco_mapchanger.txt");
		PrintToServer("[FMC] Discovered coop gamemode. Link to sm_l4dco_mapchanger.");
	}
	else if (GameMode == GAMEMODE_VERSUS)
	{
		BuildPath(Path_SM, FMC_FileSettings, 128, "data/sm_l4dvs_mapchanger.txt");
		PrintToServer("[FMC] Discovered versus gamemode. Link to sm_l4dvs_mapchanger.");
	}
	else if (GameMode == GAMEMODE_SURVIVAL)
	{
		SetConVarInt(Allowed, 0);
		PrintToServer("[FMC] Discovered survival gamemode. Plugin stop activity. Wait for coop or versus.");
		return;
	}
	else
		SetFailState("[FMC] Current gamemode dont checked. Shutdown.");
		
	if(!FileToKeyValues(hKVSettings, FMC_FileSettings))
		SetFailState("Force Mission Changer settings not found! Shutdown.");

	next_mission_force = "none";
	GetCurrentMap(current_map, 64);
	GetConVarString(DefM, next_mission_def, 64);

	KvRewind(hKVSettings);
	if(KvJumpToKey(hKVSettings, current_map))
	{
		KvGetString(hKVSettings, "next mission map", next_mission_force, 64, next_mission_def);
		KvGetString(hKVSettings, "next mission name", force_mission_name, 64, "none");
	}
	KvRewind(hKVSettings);
		
	if (StrEqual(next_mission_force, "none") != true)
	{
		if (!IsMapValid(next_mission_force))
			FormatEx(next_mission_force, sizeof(next_mission_force), "%s", next_mission_def);

		if (StrEqual(force_mission_name, "none") != true)
			FormatEx(announce_map, sizeof(announce_map), "%s", force_mission_name);
		else
			FormatEx(announce_map, sizeof(announce_map), "%s", next_mission_force);
	}
	else
	{
		FormatEx(next_mission_force, sizeof(next_mission_force), "%s", next_mission_def);
		FormatEx(announce_map, sizeof(announce_map), "%s", next_mission_def);
	}
				
	RoundEndCounterValue = 0;
	RoundEndBlockValue = 0.0;
	for (new i = 0; i < g_ArrayCount; i++)
	{
		if (StrEqual(current_map, MapNameArrayLine[i]) == true)
		{
			RoundEndCounterValue = StringToInt(CrecNumArrayLine[g_ArrayCount]);
			RoundEndBlockValue = StringToFloat(reBlkFlArrayLine[g_ArrayCount]);
			break;
		}
	}
	if (RoundEndCounterValue == 0)
		RoundEndCounterValue = GetConVarInt(CheckRoundCounter);
	if (RoundEndBlockValue == 0.0)
		RoundEndBlockValue = GetConVarFloat(ChDelayVS);
}