#include <sourcemod>
#include <sdktools>
#include <l4d_lib>
#include <left4dhooks>
#include <multicolors>

ConVar g_hEnableNoFinalFirstTank;
bool g_bEnableNoFinalFirstTank;

static bool:resuce_start,bool:HasBlockFirstTank;
static bool:g_bFixed,bool:Tank_firstround_spawn,Float:g_fTankData_origin[3],Float:g_fTankData_angel[3];
#define NULL_VELOCITY view_as<float>({0.0, 0.0, 0.0})
static KeyValues g_hMIData = null;
bool g_bNoFinalFirstTankMap;

public Plugin:myinfo = 
{
	name = "L4D Final No First Tank",
	author = "Harry Potter",
	description = "No First Tank Spawn as the final rescue start and second tank spawn same position for both team",
	version = "1.5",
	url = "http://steamcommunity.com/profiles/76561198026784913"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	
	if( test != Engine_Left4Dead )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1.");
		return APLRes_SilentFailure;
	}

	CreateNative("HasFinalFirstTank", Native_HasFinalFirstTank);
	return APLRes_Success;
}

public int Native_HasFinalFirstTank(Handle plugin, int numParams) {
	if(!g_bNoFinalFirstTankMap || !g_bEnableNoFinalFirstTank)  return true;
	else return false;
}

public OnPluginStart()
{
	LoadTranslations("Roto2-AZ_mod.phrases");
	g_hEnableNoFinalFirstTank = CreateConVar("no_final_first_tank", "1", "Removes tanks which spawn as the rescue vehicle arrives on finales.", _, true, 0.0, true, 1.0);
	
	HookEvent("finale_start", Event_Finale_Start);
	HookEvent("round_start", 	Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("tank_spawn", PD_ev_TankSpawn, EventHookMode_PostNoCopy);
	
	g_bEnableNoFinalFirstTank = GetConVarBool(g_hEnableNoFinalFirstTank);
	HookConVarChange(g_hEnableNoFinalFirstTank, Enable_CvarChange);
}

public OnMapStart()
{
	//強制rescue Second tank出生在一樣的位置
	g_bFixed = false;
	Tank_firstround_spawn = false;
	ClearVec();

	g_bNoFinalFirstTankMap = true;
	char sCurMap[64];
	GetCurrentMap(sCurMap, 64);

	MI_KV_Close();
	MI_KV_Load();
	if (!KvJumpToKey(g_hMIData, sCurMap)) {
		//LogError("[MI] MapInfo for %s is missing.", g_sCurMap);
	} else
	{
		if (g_hMIData.GetNum("no_final_first_tank", 1) == 0)
		{
			g_bNoFinalFirstTankMap = false;
		}
	}
	MI_KV_Close();
}

public Action:Event_Finale_Start(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(!g_bNoFinalFirstTankMap || !g_bEnableNoFinalFirstTank)  return;
	
	resuce_start = true;
	CreateTimer(0.1, On_t_Instruction);
}

public Action:On_t_Instruction(Handle:timer)
{
	CPrintToChatAll("%t","Only One Tank after Final Rescue"); 
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	resuce_start = false;
	HasBlockFirstTank = false;
}

public Action:L4D_OnTryOfferingTankBot(tank_index, &bool:enterStatis)
{
	if(!g_bNoFinalFirstTankMap || !g_bEnableNoFinalFirstTank) return Plugin_Continue;

	if(resuce_start)
	{
		if(!HasBlockFirstTank)
		{
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

public void PD_ev_TankSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if(!g_bNoFinalFirstTankMap || !g_bEnableNoFinalFirstTank) return;

	if(resuce_start)
	{
		if(!HasBlockFirstTank)
		{
			int userid = GetEventInt(event, "userid");
			int client = GetClientOfUserId(userid);
			TeleportEntity(client,
			NULL_VELOCITY, // Teleport to map center
			NULL_VECTOR, 
			NULL_VECTOR);
			CreateTimer(1.5, KillFirstTank, userid);
			return;
		}
		else
		{
			//PrintToChatAll("Second Tank Spawn");
			if (!InSecondHalfOfRound())
			{
				if(!Tank_firstround_spawn){
					new iTank = IsTankInGame();
					if (iTank){
						GetEntPropVector(iTank, Prop_Send, "m_angRotation", g_fTankData_angel);
						GetEntPropVector(iTank, Prop_Send, "m_vecOrigin", g_fTankData_origin);
						//PrintToChatAll("round1 tank pos: %.1f %.1f %.1f", vector[0], vector[1], vector[2]);
						Tank_firstround_spawn = true;
					}
				}
			}
			else
			{
				if(g_bFixed || !Tank_firstround_spawn) return;
				
				new iTank = IsTankInGame();
				if (iTank){

					TeleportEntity(iTank, g_fTankData_origin, g_fTankData_angel, NULL_VECTOR);
					//PrintToChatAll("teleport '%N' to round1 pos.", iTank);
					g_bFixed = true;
				}
			}
		}
	}
	
}
public Action KillFirstTank(Handle timer, int userid)
{
	int iTank = GetClientOfUserId(userid);
	if(iTank && IsClientInGame(iTank) && IsFakeClient(iTank) && GetClientTeam(iTank) == 3 && IsPlayerTank(iTank) && IsPlayerAlive(iTank))
	{
		//ForcePlayerSuicide(iTank);
		KickClient(iTank, "Rescue_first_tank");
		CPrintToChatAll("%t","l4d_NoRescueFirstTank");
		HasBlockFirstTank = true;
	}
}
public Enable_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (StrEqual(oldValue, newValue)) return;

	g_bEnableNoFinalFirstTank = GetConVarBool(g_hEnableNoFinalFirstTank);\
}

IsTankInGame(exclude = 0)
{
	for (new i = 1; i <= MaxClients; i++)
		if (exclude != i && IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerTank(i) && IsPlayerAlive(i) && !IsIncapacitated(i))
			return i;

	return 0;
}

bool:InSecondHalfOfRound()
{
	return bool:GameRules_GetProp("m_bInSecondHalfOfRound");
}

static ClearVec()
{
	for (new index; index < 3; index++){
		g_fTankData_origin[index] = 0.0;
		g_fTankData_angel[index] = 0.0;
	}
}

void MI_KV_Load()
{
	char sNameBuff[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sNameBuff, 256, "data/%s", "mapinfo.txt");

	g_hMIData = CreateKeyValues("MapInfo");
	if (!FileToKeyValues(g_hMIData, sNameBuff)) {
		LogError("[MI] Couldn't load MapInfo data!");
		MI_KV_Close();
	}
}

void MI_KV_Close()
{
	if (g_hMIData != null) {
		CloseHandle(g_hMIData);
		g_hMIData = null;
	}
}