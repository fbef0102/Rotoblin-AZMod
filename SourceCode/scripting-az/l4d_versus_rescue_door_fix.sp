#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <dhooks>
#include <sourcescramble>
#include <left4dhooks>

#define PLUGIN_VERSION "1.0"
#define GAMEDATA_FILE "l4d_versus_rescue_door_fix"
#define FUNCTION_PATCH "CSurvivorRescue::AreaScanThink"
#define KEY_PATCH "CTerrorPlayer::OnPreThinkGhostState__ChangeSpawnAttributes"
#define KEY_PATCH2 "CTerrorPlayer::OnPreThinkGhostState__ChangeSpawnAttributes2"

public Plugin myinfo = 
{
	name = "l4d versus rescue door fix",
	author = "Forgetest, HarryPotter",
	description = "Fixed infected unable to break the rescue door + remove restricted area where infected ghost unable to spawn inside the info_survivor_rescue room/area",
	version = PLUGIN_VERSION,
	url = "https://steamcommunity.com/profiles/76561198026784913/"
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

public void OnPluginStart()
{

	GameData hGameData = new GameData(GAMEDATA_FILE);
	if (hGameData == null)
		SetFailState("Missing gamedata file (" ... GAMEDATA_FILE ... ")");

	/*
	DynamicDetour hDetour = DynamicDetour.FromConf(hGameData, FUNCTION_PATCH);
	if(!hDetour)
		SetFailState("Missing detour setup of \"" ... FUNCTION_PATCH ... "\"");

	if(!hDetour.Enable(Hook_Pre, DTR_OnDetonate_Pre))
		SetFailState("Faild to pre-detour \"" ... FUNCTION_PATCH ... "\"");

	if(!hDetour.Enable(Hook_Post, DTR_OnDetonate_Post))
		SetFailState("Faild to post-detour \"" ... FUNCTION_PATCH ... "\"");
	*/

	MemoryPatch g_hPatcher = MemoryPatch.CreateFromConf(hGameData, KEY_PATCH);
	if (!g_hPatcher.Enable()) //infected ghost is able to spawn inside the info_survivor_rescue room/area when ghost state
		SetFailState("Failed in patching checks for \"" ... KEY_PATCH ... "\"");

	g_hPatcher = MemoryPatch.CreateFromConf(hGameData, KEY_PATCH2);
	if (!g_hPatcher.Enable()) //infected ghost is able to spawn inside the info_survivor_rescue room/area when ghost state
		SetFailState("Failed in patching checks for \"" ... KEY_PATCH2 ... "\"");


	delete hGameData;

	HookEvent("round_start_post_nav", Event_RoundStartPostNav,	EventHookMode_PostNoCopy);
	HookEvent("player_spawn", Event_PlayerSpawn,	EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("mission_lost", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("map_transition", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("finale_vehicle_leaving", Event_RoundEnd, EventHookMode_PostNoCopy);
}
/*
MRESReturn DTR_OnDetonate_Pre(int entity)
{
	//Fixed infected unable to break the rescue door
	//Fixed survivor unable to open/close the rescue door
	return MRES_Supercede;
}

MRESReturn DTR_OnDetonate_Post(int entity)
{
	//Fixed infected unable to break the rescue door
	//Fixed survivor unable to open/close the rescue door
	return MRES_Supercede;
}
*/


public void OnPluginEnd()
{
	ResetPlugin();
}

public void OnMapEnd()
{
	ResetPlugin();
}

int g_iRoundStart, g_iPlayerSpawn;
public void Event_RoundStartPostNav(Event event, const char[] name, bool dontBroadcast)
{
	if( g_iPlayerSpawn == 1 && g_iRoundStart == 0 )
		CreateTimer(0.5, tmrStart, _, TIMER_FLAG_NO_MAPCHANGE);
	g_iRoundStart = 1;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if( g_iPlayerSpawn == 0 && g_iRoundStart == 1 )
		CreateTimer(0.5, tmrStart, _, TIMER_FLAG_NO_MAPCHANGE);
	g_iPlayerSpawn = 1;
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	ResetPlugin();
}

public Action tmrStart(Handle timer)
{
	ResetPlugin();

	if(L4D_IsVersusMode())
	{
		FixRescueDoors(); 
	}

	return Plugin_Continue;
}

void FixRescueDoors()
{
	int entity = MaxClients + 1, m_spawnflags;
	//float vPos[3];
	while ((entity = FindEntityByClassname(entity, "prop_door_rotating")) != -1) {
		if(!IsValidEntity(entity)) continue;

		//GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vPos);
		//LogMessage("rescue door %d, m_takedamage: %d, m_spawnflags: %d, m_bLocked: %d, position: %.2f %.2f %.2f", entity, GetEntProp(entity, Prop_Data, "m_takedamage"), m_spawnflags, GetEntProp(entity, Prop_Data, "m_bLocked"), vPos[0], vPos[1], vPos[2]);
		
		if(GetEntProp(entity, Prop_Data, "m_takedamage") >= 2) continue;
		
		m_spawnflags = GetEntProp(entity, Prop_Data, "m_spawnflags");
		if(m_spawnflags & (39424)) //rescure door m_spawnflags is |= 0x9A00
		{
			//LogMessage("rescue door %d is rescue door", entity);
			SetEntProp(entity, Prop_Data, "m_takedamage", 2); //breakable
			SetEntProp(entity, Prop_Data, "m_spawnflags", m_spawnflags & (~39424)); //normal door
			SetEntProp(entity, Prop_Data, "m_bLocked", 0); //unlock
		}
	}
}

void ResetPlugin()
{
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
}
