#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <clientprefs>

#define DEBUG 0
#define FIX_RARE_BUG_METHOD 0

enum
{
	LASER_BIT = 0x20000,
	SILENCER_BIT = 0x40000,
	NIGHT_BIT = 0x400000,
	RELOAD_BIT = 0x20000000
}

public Plugin myinfo =
{
	name = "[L4D] Useful Upgrades",
	description = "Include 4 useful upgrades Laser Sight, Silencer, Night Vision and Fast Reload",
	author = "Figa (Fork by Dragokas)",
	version = "1.6.1",
	url = "http://fiksiki.3dn.ru"
};

/*
Fork by Dragokas

1.6.1 (23-Mar-2019)
 - Removed FakeClient check when we reset upgrades (for safe). Thanks to AlexMy and SilverShot.
 - Added "Bot Replace Player" and "Player Disconnect" events to reset upgrades (for safe).

1.6 (15-Mar-2019)
 - Added laser to the list of upgrades to be reset on round end (if not, it's possibly could cause server crash sometimes).

1.5 (07-Mar-2019)
 - Added additional delay before activation the laser because sometimes player's netprops have no time to init.

1.4 (01-Mar-2019)
 - Converted to a new syntax and methodmaps
 - Added sdk method to enable laser
 - Added more reliable managing the cookies
 - Added "l4d_useful_upgrades" config file.
 - Added "l4d_force_silencer" ConVar to force Silencer Upgrade on spawn
 - Added "l4d_force_laser_sight" ConVar to force Laser Sight Upgrade on spawn
 - Added "l4d_force_night_vision" ConVar to force Night Vision Upgrade on spawn
 - Added "l4d_force_fast_reload" ConVar to force Fast Reload Upgrade on spawn
 - Added checking for game requirements (L4D1 only).

1.3 (private)
 - Removed laser, because it crash my server

1.2 (based on alternate fork branch)
 - Added saving upgrades state to the cookies
 - Added some safe checkings

*/

ConVar g_ConVarSilencerEnable;
ConVar g_ConVarLaserEnable;
ConVar g_ConVarNightVisionEnable;
ConVar g_ConVarFastReloadEnable;
ConVar g_ConVarSilencerForce;
ConVar g_ConVarLaserForce;
ConVar g_ConVarNightVisionForce;
ConVar g_ConVarReloadForce;

ConVar g_ConVarSurvivorUpgrades;

Handle g_hCookie = INVALID_HANDLE;
Handle sdkAddUpgrade = INVALID_HANDLE;
Handle sdkRemoveUpgrade = INVALID_HANDLE;

int g_cl_upgrades[MAXPLAYERS+1];
bool g_bLaserCheck[MAXPLAYERS + 1];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if (test != Engine_Left4Dead)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("l4d_luu.phrases");

	HookEvent("player_death", 			Event_PlayerDeath);
	HookEvent("player_spawn", 			Event_PlayerSpawn);
	HookEvent("round_end", 				Event_RoundEnd, EventHookMode_Pre);
	HookEvent("map_transition", 		Event_RoundEnd, EventHookMode_Pre);
	HookEvent("player_bot_replace", 	Event_PlayerBotReplace, EventHookMode_Pre);
	HookEvent("player_disconnect", 		Event_PlayerDisconnect, EventHookMode_Pre);
	
	RegConsoleCmd("sm_silent", CmdSilencer, "sm_silent - Toggle Silencer");
	RegConsoleCmd("sm_silencer", CmdSilencer, "sm_silent - Toggle Silencer");
	RegConsoleCmd("sm_laser", CmdLaser, "sm_laser - Toggle Laser Sight");
	RegConsoleCmd("sm_night", CmdNightVision, "sm_night - Toggle Night Vision");
	RegConsoleCmd("sm_fastreload", CmdFastReload, "sm_fastreload - Toggle Fast Reload");
	
	g_ConVarSilencerEnable = CreateConVar( "l4d_enable_silencer", "1", "1 - Enable Toggle Silencer Upgrade; 0 - Disable This Upgrade", FCVAR_NOTIFY);
	g_ConVarLaserEnable = CreateConVar( "l4d_enable_laser_sight", "1", "1 - Enable Toggle Laser Sight Upgrade; 0 - Disable This Upgrade", FCVAR_NOTIFY);
	g_ConVarNightVisionEnable = CreateConVar( "l4d_enable_night_vision", "1", "1 - Enable Toggle Night Vision Upgrade; 0 - Disable This Upgrade", FCVAR_NOTIFY);
	g_ConVarFastReloadEnable = CreateConVar( "l4d_enable_fast_reload", "0", "1 - Enable Toggle Fast Reload Upgrade; 0 - Disable This Upgrade", FCVAR_NOTIFY);
	
	g_ConVarSilencerForce = CreateConVar( "l4d_force_silencer", "0", "Force Silencer Upgrade on spawn (0 - No, 1 - Yes)", FCVAR_NOTIFY);
	g_ConVarLaserForce = CreateConVar( "l4d_force_laser_sight", "0", "Force Laser Sight Upgrade on spawn (0 - No, 1 - Yes)", FCVAR_NOTIFY);
	g_ConVarNightVisionForce = CreateConVar( "l4d_force_night_vision", "0", "Force Night Vision Upgrade on spawn (0 - No, 1 - Yes)", FCVAR_NOTIFY);
	g_ConVarReloadForce = CreateConVar( "l4d_force_fast_reload", "0", "Force Fast Reload Upgrade on spawn (0 - No, 1 - Yes)", FCVAR_NOTIFY);
	
	//AutoExecConfig(true, "l4d_useful_upgrades");
	
	g_ConVarSurvivorUpgrades = FindConVar("survivor_upgrades");
	
	HookUserMessage(GetUserMessageId("SayText"), SayTextHook, true);

	g_hCookie = RegClientCookie("cookie_useful_upgrades", "0", CookieAccess_Private);
	
	StartPrepSDKCall(SDKCall_Player);
	if (!PrepSDKCall_SetSignature(SDKLibrary_Server, "\xA1****\x83***\x57\x8B\xF9\x0F*****\x8B***\x56\x51\xE8****\x8B\xF0\x83\xC4\x04", 34))
	{
		PrepSDKCall_SetSignature(SDKLibrary_Server, "@_ZN13CTerrorPlayer10AddUpgradeE19SurvivorUpgradeType", 0);
	}
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_ByValue);
	sdkAddUpgrade = EndPrepSDKCall();
	
	StartPrepSDKCall(SDKCall_Player);
	if (!PrepSDKCall_SetSignature(SDKLibrary_Server, "\x51\x53\x55\x8B***\x8B\xD9\x56\x8B\xCD\x83\xE1\x1F\xBE\x01\x00\x00\x00\x57\xD3\xE6\x8B\xFD\xC1\xFF\x05\x89***", 32))
	{
		PrepSDKCall_SetSignature(SDKLibrary_Server, "@_ZN13CTerrorPlayer13RemoveUpgradeE19SurvivorUpgradeType", 0);
	}
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_ByValue);
	sdkRemoveUpgrade = EndPrepSDKCall();
}

public void OnClientPostAdminCheck(int client)
{
	ClientCommand(client, "bind l sm_laser; bind k sm_silent; bind n sm_night; bind j sm_reload");
}

public void OnConfigsExecuted() {
	// Setting of ConVars
	// Use while() loop to ensure convar is set. Hopefully fixes weird rare bug
	
	#if FIX_RARE_BUG_METHOD
		g_ConVarSurvivorUpgrades.SetInt(1, true, false);
		// Add delay of setting survivor_upgrades second time, fixes rare bug of it not activating
		CreateTimer(5.0, Timer_SetSurvivorUpgradesCVar, _, TIMER_FLAG_NO_MAPCHANGE);
	#else
		while(g_ConVarSurvivorUpgrades.IntValue != 1) {
			g_ConVarSurvivorUpgrades.SetInt(1, true, false);
		}
	#endif
}

#if FIX_RARE_BUG_METHOD
public Action Timer_SetSurvivorUpgradesCVar(Handle hTimer) {
	if(g_ConVarSurvivorUpgrades.IntValue == 0) {
		g_ConVarSurvivorUpgrades.SetInt(1, true, false);
		for (int i = 0; i <= MaxClients; i++)
			if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == 2)
				LoadCookie(i);
	}
}
#endif

public void Event_PlayerBotReplace(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("player"));
	
	if (client && IsClientInGame(client) && GetClientTeam(client) == 2) {
		DisableAllUpgrades(client);
	}
}

public void Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (client && IsClientInGame(client) && GetClientTeam(client) == 2)
		DisableAllUpgrades(client);
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == 2) DisableAllUpgrades(i);
	}
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(client != 0 && IsClientInGame(client) && GetClientTeam(client) == 2 && !IsFakeClient(client)) DisableAllUpgrades(client);
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int UserId = event.GetInt("userid");
	int client = GetClientOfUserId(UserId);
	if(client != 0 && IsClientInGame(client) && GetClientTeam(client) == 2 && !IsFakeClient(client)) {
		DisableAllUpgrades(client);
		CreateTimer(0.3, Timer_LoadCookie, UserId, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action Timer_LoadCookie(Handle timer, int UserId)
{
	int client = GetClientOfUserId(UserId);

	if(client != 0 && IsClientInGame(client))
	{
		LoadCookie(client);
	}
}

public void OnClientPutInServer(int client)
{
	if (client == 0 || IsFakeClient(client)) return;
	DisableAllUpgrades(client);
	CreateTimer(10.0, TimerAnnounce, client);
}

public Action TimerAnnounce(Handle timer, int client)
{
	if(IsClientInGame(client))
	{
		PrintToChat(client, "%t", "INFO");
	}
}

stock void DisableAllUpgrades(int client)
{
	SetEntProp(client, Prop_Send, "m_upgradeBitVec", 0, 4);
	SetEntProp(client, Prop_Send, "m_bNightVisionOn", 0, 4);
	SetEntProp(client, Prop_Send, "m_bHasNightVision", 0, 4);
	SwitchLaser(client, _, true, true);
	g_bLaserCheck[client] = false;
}

void SaveCookie(int client)
{
	if (client != 0)
	{
		int bits = GetEntProp(client, Prop_Send, "m_upgradeBitVec");

		if (g_bLaserCheck[client])
			bits |= LASER_BIT;
		else
			bits &= ~LASER_BIT;
		
		if (bits == 0) bits = -1;
		
		#if DEBUG
			PrintToChat(client, "Saved bits = %i, Laser: %i, silence: %i, night: %i, reload: %i", bits,
			bits & LASER_BIT, bits & SILENCER_BIT, bits & NIGHT_BIT, bits & RELOAD_BIT);
		#endif

		char sCookie[16];
		IntToString(bits, sCookie, sizeof(sCookie));
		if ( g_hCookie != INVALID_HANDLE)
			SetClientCookie(client, g_hCookie, sCookie);
	}
}

/*
public void OnClientCookiesCached(int client)
{
	if(IsClientInGame(client) && !IsFakeClient(client))
	{
		LoadCookie(client);
	}
}
*/

void LoadCookie(int client)
{
	if (IsClientInGame(client) && !IsFakeClient(client))
	{
		if (g_hCookie != INVALID_HANDLE && AreClientCookiesCached(client))
		{
			char sCookie[12];
			int bits;
			GetClientCookie(client, g_hCookie, sCookie, sizeof(sCookie));
			
			if (strlen(sCookie) != 0 && !StrEqual(sCookie, "0")) {
				bits = StringToInt(sCookie);
			}
			
			if (bits == -1) bits = 0;
			
			if (g_ConVarSilencerForce.BoolValue)
				bits |= SILENCER_BIT;
			
			if (g_ConVarLaserForce.BoolValue)
				bits |= LASER_BIT;
			
			if (g_ConVarNightVisionForce.BoolValue)
				bits |= NIGHT_BIT;
			
			if (g_ConVarReloadForce.BoolValue)
				bits |= RELOAD_BIT;
			
			g_cl_upgrades[client] = bits;
			
			CreateTimer(0.1, Timer_LoadUpgrades, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public Action Timer_LoadUpgrades(Handle timer, int UserId)
{
	int client = GetClientOfUserId(UserId);
	
	if (client != 0 && IsClientInGame(client)) {
		SetUpgradeBit(client);
	}
}

void SetUpgradeBit(int client)
{
	#if DEBUG
		PrintToChat(client, "Loaded bits = %i. Laser: %i, silence: %i, night: %i, reload: %i", g_cl_upgrades[client],
			g_cl_upgrades[client] & LASER_BIT, g_cl_upgrades[client] & SILENCER_BIT, g_cl_upgrades[client] & NIGHT_BIT, g_cl_upgrades[client] & RELOAD_BIT);
	#endif
		
	// removed laser from basic upgrade to prevent crash
	int upgrades = g_cl_upgrades[client] & ~LASER_BIT;
	
	int bits = GetEntProp(client, Prop_Send, "m_upgradeBitVec");
	
	if (bits != upgrades)
	{
		SetEntProp(client, Prop_Send, "m_upgradeBitVec", upgrades, 4);
		
		if (upgrades & NIGHT_BIT)
		{
			SetEntProp(client, Prop_Send, "m_bNightVisionOn", 1, 4);
			SetEntProp(client, Prop_Send, "m_bHasNightVision", 1, 4);
		}
		else {
			SetEntProp(client, Prop_Send, "m_bNightVisionOn", 0, 4);
			SetEntProp(client, Prop_Send, "m_bHasNightVision", 0, 4);
		}
	}
	
	if (IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client))
	{
		if ((bits & RELOAD_BIT) == 0 && g_ConVarReloadForce.BoolValue) {
			bits |= RELOAD_BIT;
			SetEntProp(client, Prop_Send, "m_upgradeBitVec", bits, 4);
		}
		else {
			if(!g_ConVarReloadForce.BoolValue)
			{
				bits &= ~RELOAD_BIT;
				SetEntProp(client, Prop_Send, "m_upgradeBitVec", bits, 4);
			}
		}
	}
	
	CreateTimer(1.0, Timer_SetLaserDelayed, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_SetLaserDelayed(Handle timer, int UserId)
{
	bool bLaser;
	int client = GetClientOfUserId(UserId);
	
	if (client != 0 && IsClientInGame(client)) {

		if (g_cl_upgrades[client] & LASER_BIT)
			bLaser = true;
		
		if (bLaser)
			SwitchLaser(client, true, _, true);
		else
			SwitchLaser(client, _, true, true);
	}
}

public Action CmdSilencer(int client, int args)
{
	SwitchSilencer(client);
	SaveCookie(client);
	return Plugin_Handled;
}
void SwitchSilencer(int client, bool bEnable = false, bool bDisable = false, bool bSilent = false)
{
	if (g_ConVarSilencerEnable.BoolValue && IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client))
	{
		int bits = GetEntProp(client, Prop_Send, "m_upgradeBitVec");

		if (bEnable || ((bits & SILENCER_BIT) == 0 && !bDisable)) {
			bits |= SILENCER_BIT;
			SetEntProp(client, Prop_Send, "m_upgradeBitVec", bits, 4);
			if (!bSilent)
				PrintToChat(client, "%t", "Silencer_On");
		}
		else {
			bits &= ~SILENCER_BIT;
			SetEntProp(client, Prop_Send, "m_upgradeBitVec", bits, 4);
			if (!bSilent)
				PrintToChat(client, "%t", "Silencer_Off");
		}
	}
}

public Action CmdLaser(int client, int args)
{
	SwitchLaser(client);
	SaveCookie(client);
	return Plugin_Handled;
}
void SwitchLaser(int client, bool bEnable = false, bool bDisable = false, bool bSilent = false)
{
	if (g_ConVarLaserEnable.BoolValue && IsClientInGame(client) && GetClientTeam(client) == 2)
	{
		if (bEnable || (!g_bLaserCheck[client] && !bDisable)) {
			SDKCall(sdkAddUpgrade, client, 17);
			g_bLaserCheck[client] = true;
			if (!bSilent)
				PrintToChat(client, "%t", "Laser_On");
		}
		else if (g_bLaserCheck[client]) {
			SDKCall(sdkRemoveUpgrade, client, 17);
			g_bLaserCheck[client] = false;
			if (!bSilent)
				PrintToChat(client, "%t", "Laser_Off");
		}
	}
}

public Action CmdNightVision(int client, int args)
{
	SwitchNightVision(client);
	SaveCookie(client);
	return Plugin_Handled;
}
void SwitchNightVision(int client, bool bEnable = false, bool bDisable = false, bool bSilent = false)
{
	if (g_ConVarNightVisionEnable.BoolValue && IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client))
	{
		int bits = GetEntProp(client, Prop_Send, "m_upgradeBitVec");
		
		if (bEnable || ((bits & NIGHT_BIT) == 0 && !bDisable)) {
			bits |= NIGHT_BIT;
			SetEntProp(client, Prop_Send, "m_upgradeBitVec", bits, 4);
			SetEntProp(client, Prop_Send, "m_bNightVisionOn", 1, 4);
			SetEntProp(client, Prop_Send, "m_bHasNightVision", 1, 4);
			if (!bSilent)
				PrintToChat(client, "%t", "NightVision_On");
		}
		else {
			bits &= ~NIGHT_BIT;
			SetEntProp(client, Prop_Send, "m_upgradeBitVec", bits, 4);
			SetEntProp(client, Prop_Send, "m_bNightVisionOn", 0, 4);
			SetEntProp(client, Prop_Send, "m_bHasNightVision", 0, 4);
			if (!bSilent)
				PrintToChat(client, "%t", "NightVision_Off");
		}
	}
}

public Action CmdFastReload(int client, int args)
{
	SwitchFastReload(client);
	SaveCookie(client);
	return Plugin_Handled;
}

void SwitchFastReload(int client, bool bEnable = false, bool bDisable = false, bool bSilent = false)
{
	if (g_ConVarFastReloadEnable.BoolValue && IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client))
	{
		int bits = GetEntProp(client, Prop_Send, "m_upgradeBitVec");

		if (bEnable || ((bits & RELOAD_BIT) == 0 && !bDisable)) {
			bits |= RELOAD_BIT;
			SetEntProp(client, Prop_Send, "m_upgradeBitVec", bits, 4);
			if (!bSilent)
				PrintToChat(client, "%t", "Reload_On");
		}
		else {
			bits &= ~RELOAD_BIT;
			SetEntProp(client, Prop_Send, "m_upgradeBitVec", bits, 4);
			if (!bSilent)
				PrintToChat(client, "%t", "Reload_Off");
		}
	}
}

public Action SayTextHook(UserMsg msg_id, Handle bf, const int[] players, int playersNum, bool reliable, bool init)
{
	char message[1024];
	BfReadByte(bf);
	BfReadByte(bf);
	BfReadString(bf, message, 1024);

	if(StrContains(message, "prevent_it_expire") != -1)	{
		return Plugin_Handled;
	}			
	if(StrContains(message, "ledge_save_expire") != -1)	{
		return Plugin_Handled;
	}
	if(StrContains(message, "revive_self_expire") != -1) {
		return Plugin_Handled;
	}
	if(StrContains(message, "knife_expire") != -1) {
		return Plugin_Handled;
	}
	
	if(StrContains(message, "laser_sight_expire") != -1) {
		return Plugin_Handled;
	}
	
	if(StrContains(message, "reloader_expire") != -1) {
		return Plugin_Handled;
	}

	if(StrContains(message, "_expire") != -1) {
		return Plugin_Handled;
	}

	if(StrContains(message, "#L4D_Upgrade_") != -1 && StrContains(message, "description") != -1) {
		return Plugin_Handled;
	}
	
	if(StrContains(message, "NOTIFY_VOMIT_ON") != -1) {
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}
