/**
 * l4d_fix_deathfall_cam "1.6.1" 變體插件
 * -支援readup開始之後清除倖存者身上的死亡鏡頭
 */

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools_engine>
#include <left4dhooks>
#include <dhooks>
#include <readyup>

#define PLUGIN_VERSION "1.6.2-2025/6/13"

public Plugin myinfo = 
{
	name = "[L4D1] Fix DeathFall Camera",
	author = "Forgetest",
	description = "Prevent \"point_deathfall_camera\" and \"point_viewcontrol*\" permanently locking view.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if( test != Engine_Left4Dead )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1.");
		return APLRes_SilentFailure;
	}

	CreateNative("L4D_ReleaseFromViewControl", Ntv_ReleaseFromViewControl);
	return APLRes_Success;
}

public any Ntv_ReleaseFromViewControl(Handle plugin, int numParams)
{
	return ReleaseFromViewControl(_, GetNativeCell(1));
}

ArrayList g_aDeathFallClients;
int g_iOffset;

public void OnPluginStart()
{
	CreateConVar("l4d2_fix_deathfall_cam_version", PLUGIN_VERSION, "Fix Deathfall Camera Version", FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_REPLICATED|FCVAR_SPONLY);
	
	g_aDeathFallClients = new ArrayList();
	
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("gameinstructor_nodraw", Event_NoDraw, EventHookMode_PostNoCopy);
	HookEvent("player_team", Event_PlayerTeam);
	HookEvent("player_death", Event_PlayerDeath);

	GameData hGamedata = new GameData("l4d_fix_deathfall_cam");

	if(hGamedata == null)
		SetFailState( "Can't load gamedata \"%s.txt\" or not found", "l4d_fix_deathfall_cam");

	g_iOffset = hGamedata.GetOffset("OS");
	if (g_iOffset == -1) {
		SetFailState("Failed to get offset \"OS\"");
	}

	// linux
	if(g_iOffset == 1)
	{
		DynamicDetour hDetour = DynamicDetour.FromConf(hGamedata, "CDeathFallCamera::InputEnable");
		if(!hDetour)
			SetFailState("Failed to find 'CDeathFallCamera::InputEnable' signature");
		
		if(!hDetour.Enable(Hook_Pre, CDeathFallCamerarInputEnable_Pre))
			SetFailState("Failed to detour 'CDeathFallCamera::InputEnable'");

		delete hDetour;

		delete hGamedata;
	}
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (FindEntityByClassname(MaxClients+1, "point_viewcontrol*") != INVALID_ENT_REFERENCE
		|| FindEntityByClassname(MaxClients+1, "point_deathfall_camera") != INVALID_ENT_REFERENCE)
	{
		UTIL_ReleaseAllExceptSurv();
	}
	
	delete g_aDeathFallClients;
	g_aDeathFallClients = new ArrayList();
}

// Fix intro cameras locking view on L4D1
void Event_NoDraw(Event event, const char[] name, bool dontBroadcast)
{
	UTIL_ReleaseAllExceptSurv();
}

void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_aDeathFallClients.Length) return;
	
	Timer_ReleaseView(null, event.GetInt("userid"));
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_aDeathFallClients.Length) return;
	
	// the player's view locks for approximately 6.0s after died
	CreateTimer(6.0, Timer_ReleaseView, event.GetInt("userid"), TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_ReleaseView(Handle timer, any userid)
{
	int index = g_aDeathFallClients.FindValue(userid);
	if (index == -1)
		return Plugin_Stop;
	
	g_aDeathFallClients.Erase(index);
	ReleaseFromViewControl(userid);
	
	return Plugin_Stop;
}

public void OnRoundIsLivePre()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i)) continue;
		if(GetClientTeam(i) != 2) continue;

		CreateTimer(0.1, Timer_ReleaseView, GetClientUserId(i), TIMER_FLAG_NO_MAPCHANGE);
	}
}

// 一代linux無效，沒有觸發涵式
public Action L4D_OnFatalFalling(int client, int camera)
{
	if (!client)
		return Plugin_Continue;

	if(g_iOffset == 1) // just in case
		return Plugin_Continue;

	if (!AllowDamage())
		return Plugin_Handled;
	
	if (GetClientTeam(client) == 2 && !IsFakeClient(client) && IsPlayerAlive(client))
	{
		// keep deathcam for a period until the player dies
		int userid = GetClientUserId(client);
		if (g_aDeathFallClients.FindValue(userid) == -1)
			g_aDeathFallClients.Push(userid);
		
		return Plugin_Continue;
	}
	
	return Plugin_Handled;
}

// 限定一代linux觸發
MRESReturn CDeathFallCamerarInputEnable_Pre(int pThis, DHookParam hParams)
{
	//"inputdata_t &"
	//{
	//	"type"	"objectptr"
	//}

	/*struct inputdata_t
	{
		CBaseEntity *pActivator;		// The entity that initially caused this chain of output events.
		CBaseEntity *pCaller;			// The entity that fired this particular output.
		class value;					// The data parameter for this output.
		int nOutputID;					// The unique ID of the output that was fired.
	};*/
	int client = hParams.GetObjectVar(1, 0, ObjectValueType_CBaseEntityPtr);

	if (client <= 0) // 空指针会返回-1
		return MRES_Ignored;

	if (!AllowDamage())
		return MRES_Ignored;

	if (GetClientTeam(client) == 2 && !IsFakeClient(client) && IsPlayerAlive(client))
	{
		// keep deathcam for a period until the player dies
		int userid = GetClientUserId(client);
		if (g_aDeathFallClients.FindValue(userid) == -1)
			g_aDeathFallClients.Push(userid);

		return MRES_Ignored;
	}
	
	return MRES_Supercede;
}

void SetViewEntity(int client, int view)
{
	SetEntPropEnt(client, Prop_Send, "m_hViewEntity", view);
	SetClientViewEntity(client, IsValidEdict(view) ? view : client);
}

// Hud Element hiding flags
#define HIDEHUD_WEAPONSELECTION     (1 << 0)	// Hide ammo count & weapon selection
#define HIDEHUD_FLASHLIGHT          (1 << 1)
#define HIDEHUD_ALL                 (1 << 2)
#define HIDEHUD_HEALTH              (1 << 3)	// Hide health & armor / suit battery
#define HIDEHUD_PLAYERDEAD          (1 << 4)	// Hide when local player's dead
#define HIDEHUD_NEEDSUIT            (1 << 5)	// Hide when the local player doesn't have the HEV suit
#define HIDEHUD_MISCSTATUS          (1 << 6)	// Hide miscellaneous status elements (trains, pickup history, death notices, etc)
#define HIDEHUD_CHAT                (1 << 7)	// Hide all communication elements (saytext, voice icon, etc)
#define HIDEHUD_CROSSHAIR           (1 << 8)	// Hide crosshairs
#define HIDEHUD_VEHICLE_CROSSHAIR   (1 << 9)	// Hide vehicle crosshair
#define HIDEHUD_INVEHICLE           (1 << 10)
#define HIDEHUD_BONUS_PROGRESS      (1 << 11)	// Hide bonus progress display (for bonus map challenges)
stock void ReleaseFromViewControl(int userid = 0, int client = 0)
{
	if (userid) client = GetClientOfUserId(userid);
	if (!client) return;
	
	SetEntityFlags(client, GetEntityFlags(client) & ~FL_FROZEN);
	SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 1, 1);
	SetViewEntity(client, -1);
	
	if (GetClientTeam(client) == 1)
		SetEntProp(client, Prop_Send, "m_iHideHUD", HIDEHUD_BONUS_PROGRESS | HIDEHUD_HEALTH);
	else
		SetEntProp(client, Prop_Send, "m_iHideHUD", HIDEHUD_BONUS_PROGRESS);
			
	SetEntPropEnt(client, Prop_Send, "m_hZoomOwner", -1);
	
	// Fix for custom FOV setting
	SetEntProp(client, Prop_Send, "m_iFOV", 0);
	SetEntProp(client, Prop_Send, "m_iFOVStart", 0);
	SetEntPropFloat(client, Prop_Send, "m_flFOVRate", 0.0);
}

void UTIL_ReleaseAllExceptSurv()
{
	for (int i = 1; i <= MaxClients; ++i)
		if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) != 2)
			ReleaseFromViewControl(_, i);
}

bool AllowDamage()
{
	static ConVar god = null;
	if (god == null)
		god = FindConVar("god");
	
	if (god.BoolValue)
		return false;
	
	return true;
}