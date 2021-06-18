#define PLUGIN_VERSION 		"8.8.8"

/*======================================================================================
	Plugin Info:

*	Name	:	[L4D & L4D2] Hats
*	Author	:	SilverShot
*	Descrp	:	Attaches specified models to players above their head.
*	Link	:	http://forums.alliedmods.net/showthread.php?t=153781
*	Plugins	:	http://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:
v.8.8.8 (02-8-2019)
	- off hat when change team to spectator or infected
	
v.7.7.7 (05-May-2018)
	- Converted plugin source to the latest syntax utilizing methodmaps. Requires SourceMod 1.8 or newer.
	- Changed cvar "l4d_hats_modes_tog" now supports L4D1.

1.14.0 (25-Jun-2017)
	- Added "Reset" option to the ang/pos/size menus, requested by "ZBzibing".
	- Fixed depreciated FCVAR_PLUGIN and GetClientAuthString.
	- Increased MAX_HATS value and added many extra L4D2 hats thanks to "Munch".

1.13.0 (29-Mar-2015)
	- Fixed the plugin not working in L4D1 due to a SetEntPropFloat property not found error.

1.12.0 (07-Oct-2012)
	- Fixed hats blocking players +USE by adding a single line of code - Thanks to "Machine".

1.11.0 (02-Jul-2012)
	- Fixed cvar "l4d_hats_random" from not working properly - Thanks to "Don't Fear The Reaper" for reporting.

1.10.0 (20-Jun-2012)
	- Added German translations - Thanks to "Don't Fear The Reaper".
	- Small fixes.

1.9.0 (22-May-2012)
	- Fixed multiple hat changes only showing the first hat to players.
	- Changing hats will no longer return the player to firstperson if thirdperson was already on.

1.8.0 (21-May-2012)
	- Fixed command "sm_hatc" making the client thirdpeson and not the target.

1.7.0 (20-May-2012)
	- Added cvar "l4d_hats_change" to put the player into thirdperson view when they select a hat, requested by "disawar1".

1.6.1 (15-May-2012)
	- Fixed a bug when printing to chat after changing someones hat.
	- Fixed cvar "l4d_hats_menu" not allowing access if it was empty.

1.6.0 (15-May-2012)
	- Fixed the allow cvars not affecting everything.

1.5.0 (10-May-2012)
	- Added translations, required for the commands and menu title.
	- Added optional translations for the hat names as requested by disawar1.
	- Added cvar "l4d_hats_allow" to turn on/off the plugin.
	- Added cvar "l4d_hats_modes" to control which game modes the plugin works in.
	- Added cvar "l4d_hats_modes_off" same as above.
	- Added cvar "l4d_hats_modes_tog" same as above, but only works for L4D2.
	- Added cvar "l4d_hats_save" to save a players hat for next time they spawn or connect.
	- Added command "sm_hatsize" to change the scale/size of hats as suggested by worminater.
	- Fixed "l4d_hats_menu" flags not setting correctly.
	- Optimized the plugin by hooking cvar changes.
	- Selecting a hat from the menu no longer returns to the first page.

1.4.3 (07-May-2011)
	- Added "name" key to the config for reading hat names.

1.4.2 (16-Apr-2011)
	- Changed the way models are checked to exist and precached.

1.4.1 (16-Apr-2011)
	- Added new hat models to the config. Deleted and repositioned models blocking the "use" function.
	- Changed the hat entity from prop_dynamic to prop_dynamic_override (allows physics models to be attached).
	- Fixed command "sm_hatadd" causing crashes due to models not being pre-cached, cannot cache during a round, causes crash.
	- Fixed pre-caching models which are missing (logs an error telling you an incorrect model is specified).

1.4.0 (11-Apr-2011)
	- Added cvar "l4d_hats_opaque" to set hat transparency.
	- Changed cvar "l4d_hats_random" to create a random hat when survivors spawn. 0=Never. 1=On round start. 2=Only first spawn (keeps the same hat next round).
	- Fixed hats changing when returning from idle.
	- Replaced underscores (_) with spaces in the menu.

1.3.4 (09-Apr-2011)
	- Fixed hooking L4D2 events in L4D1.

1.3.3 (07-Apr-2011)
	- Fixed command "sm_hatc" not displaying for admins when they are dead/infected team.
	- Minor bug fixes.

1.3.2 (06-Apr-2011)
	- Fixed command "sm_hatc" displaying invalid player.

1.3.1 (05-Apr-2011)
	- Fixed the fix of command "sm_hat" flags not applying.

1.3.0 (05-Apr-2011)
	- Fixed command "sm_hat" flags not applying.

1.2.0 (03-Apr-2011)
	- Added command "sm_hatoffc" for admins to disable hats on specific clients.
	- Added cvar "l4d_hats_third" to control the previous update's addition.

1.1.1a (03-Apr-2011)
	- Added events to show / hide the hat when in third / first person view.

1.1.1 (02-Apr-2011)
	- Added cvar "l4d_hats_view" to toggle if a players hat is visible by default when they join.
	- Resets variables for clients when they connect.

1.1.0 (01-Apr-2011)
	- Added command "sm_hatoff" - Toggle to turn on or off the ability of wearing hats.
	- Added command "sm_hatadd" - To add models into the config.
	- Added command "sm_hatdel" - To remove a model from the config.
	- Added command "sm_hatlist" - To display a list of all models (for use with sm_hatdel).

1.0.0 (29-Mar-2011)
	- Initial release.

======================================================================================*/

#pragma semicolon 1

#include <colors>
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>

#define CVAR_FLAGS			FCVAR_NOTIFY
#define CHAT_TAG			"\x05[\x03CHAPEUS\x05]\x05 "
#define CONFIG_SPAWNS		"data/l4d_hats.cfg"
#define	MAX_HATS			128


ConVar g_hCvarAllow, g_hCvarChange, g_hCvarMenu, g_hCvarModes, g_hCvarModesOff, g_hCvarModesTog, g_hCvarOpaq, g_hCvarRand, g_hCvarSave, g_hCvarThird, g_hCvarView;

ConVar g_hCvarMPGameMode;
Handle g_hCookie;
Menu g_hMenu, g_hMenus[MAXPLAYERS+1];
bool g_bCvarAllow, g_bCvarView, g_bLeft4Dead2, g_bTranslation, g_bViewHooked;
int g_iCount, g_iCvarFlags, g_iCvarOpaq, g_iCvarRand, g_iCvarSave, g_iCvarThird;
float g_fCvarChange;

float g_fSize[MAX_HATS], g_vAng[MAX_HATS][3], g_vPos[MAX_HATS][3];
char g_sModels[MAX_HATS][64], g_sNames[MAX_HATS][64];
char g_sSteamID[MAXPLAYERS+1][32];		// Stores client user id to determine if the blocked player is the same.
int g_iHatIndex[MAXPLAYERS+1];			// Player hat entity reference
int g_iSelected[MAXPLAYERS+1];			// The selected hat index (0 to MAX_HATS)
int g_iTarget[MAXPLAYERS+1];			// For admins to change clients hats
int g_iType[MAXPLAYERS+1];				// Stores selected hat to give players.
bool g_bHatView[MAXPLAYERS+1];			// Player view of hat on/off
bool g_bHatOff[MAXPLAYERS+1];			// Lets players turn their hats on/off
bool g_bMenuType[MAXPLAYERS+1];			// Admin var for menu
bool g_bBlocked[MAXPLAYERS+1];			// Determines if the player is blocked from hats
Handle g_hTimerView[MAXPLAYERS+1];		// Thirdperson view when selecting hat



// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================
public Plugin myinfo =
{
	name = " ",
	author = " ",
	description = "Adiciona alguns chapeus.",
	version = PLUGIN_VERSION,
	url = ""
}



// ====================================================================================================
//					P L U G I N   S T A R T  /  E N D
// ====================================================================================================
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if( test == Engine_Left4Dead ) g_bLeft4Dead2 = false;
	else if( test == Engine_Left4Dead2 ) g_bLeft4Dead2 = true;
	else
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, PLATFORM_MAX_PATH, "%s", "translations/hatnames.phrases.txt");
	if( FileExists(sPath) )
	{
		g_bTranslation = true;
	}
	else
	{
		g_bTranslation = false;
	}


	// Load config
	int i;
	KeyValues hFile = OpenConfig();
	char sTemp[64];
	for( i = 0; i < MAX_HATS; i++ )
	{
		IntToString(i+1, sTemp, 8);
		if( hFile.JumpToKey(sTemp) )
		{
			hFile.GetString("mod", sTemp, 64);

			TrimString(sTemp);
			if( strlen(sTemp) == 0 )
				break;

			if( FileExists(sTemp, true) )
			{
				hFile.GetVector("ang", g_vAng[i]);
				hFile.GetVector("loc", g_vPos[i]);
				g_fSize[i] = hFile.GetFloat("size", 1.0);
				g_iCount++;

				strcopy(g_sModels[i], 64, sTemp);

				hFile.GetString("name", g_sNames[i], 64);

				if( strlen(g_sNames[i]) == 0 )
					GetHatName(g_sNames[i], i);
			}
			else
				LogError("Cannot find the model '%s'", sTemp);

			hFile.Rewind();
		}
	}
	delete hFile;

	if( g_iCount == 0 )
		SetFailState("No models wtf?!");


	if( g_bTranslation == true )
		LoadTranslations("hatnames.phrases");
	LoadTranslations("hats.phrases");
	LoadTranslations("core.phrases");


	// Hats menu
	if( g_bTranslation == false )
	{
		g_hMenu = new Menu(HatMenuHandler);
		for( i = 0; i < g_iCount; i++ )
			g_hMenu.AddItem(g_sModels[i], g_sNames[i]);
		g_hMenu.SetTitle("%t", "Hat_Menu_Title");
		g_hMenu.ExitButton = true;
	}

	// Cvars
	g_hCvarAllow = CreateConVar(		"l4d_hats_allow",		"1",			"0=Plugin off, 1=Plugin on.", CVAR_FLAGS );
	g_hCvarChange = CreateConVar(		"l4d_hats_change",		"0",			"0=Off. Other value puts the player into thirdperson for this many seconds when selecting a hat.", CVAR_FLAGS );
	g_hCvarModes = CreateConVar(		"l4d_hats_modes",		"",				"Turn on the plugin in these game modes, separate by commas (no spaces). (Empty = all).", CVAR_FLAGS );
	g_hCvarModesOff = CreateConVar(		"l4d_hats_modes_off",	"",				"Turn off the plugin in these game modes, separate by commas (no spaces). (Empty = none).", CVAR_FLAGS );
	g_hCvarModesTog = CreateConVar(		"l4d_hats_modes_tog",	"",				"Turn on the plugin in these game modes. 0=All, 1=Coop, 2=Survival, 4=Versus, 8=Scavenge. Add numbers together.", CVAR_FLAGS );
	g_hCvarMenu = CreateConVar(			"l4d_hats_menu",		"",				"Specify admin flags or blank to allow all players access to the hats menu.", CVAR_FLAGS );
	g_hCvarOpaq = CreateConVar(			"l4d_hats_opaque",		"255", 			"How transparent or solid should the hats appear. 0=Translucent, 255=Opaque.", CVAR_FLAGS, true, 0.0, true, 255.0 );
	g_hCvarRand = CreateConVar(			"l4d_hats_random",		"0", 			"Attach a random hat when survivors spawn. 0=Never. 1=On round start. 2=Only first spawn (keeps the same hat next round).", CVAR_FLAGS, true, 0.0, true, 3.0 );
	g_hCvarSave = CreateConVar(			"l4d_hats_save",		"0", 			"0=Off, 1=Save the players selected hats and attach when they spawn or rejoin the server.", CVAR_FLAGS, true, 0.0, true, 1.0 );
	g_hCvarThird = CreateConVar(		"l4d_hats_third",		"1", 			"0=Off, 1=When a player is in third person view, display their hat. Hide when in first person view.", CVAR_FLAGS, true, 0.0, true, 1.0 );
	g_hCvarView = CreateConVar(			"l4d_hats_view",		"0",			"0=Off, 1=Make a players hat visible by default when they join.", CVAR_FLAGS, true, 0.0, true, 1.0 );
	CreateConVar(						"l4d_hats_version",		PLUGIN_VERSION,	"Hats plugin version.",	CVAR_FLAGS|FCVAR_DONTRECORD);


	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	g_hCvarMPGameMode.AddChangeHook(ConVarChanged_Allow);
	g_hCvarAllow.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModes.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesOff.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesTog.AddChangeHook(ConVarChanged_Allow);
	g_hCvarChange.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarMenu.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarRand.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarSave.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarView.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarOpaq.AddChangeHook(CvarChangeOpac);
	g_hCvarThird.AddChangeHook(CvarChangeThird);


	// Commands
	RegConsoleCmd("sm_hat",		CmdHat,							"Displays a menu of hats allowing players to change what they are wearing." );
	RegConsoleCmd("sm_hatoff",	CmdHatOff,						"Toggle to turn on or off the ability of wearing hats." );
	RegConsoleCmd("sm_hatshow",	CmdHatShow,						"Toggle to see or hide your own hat." );
	RegConsoleCmd("sm_hatview",	CmdHatShow,						"Toggle to see or hide your own hat." );
	RegConsoleCmd("sm_chapeu",		CmdHat,							"Displays a menu of hats allowing players to change what they are wearing." );
	RegConsoleCmd("sm_chapeuoff",	CmdHatOff,						"Toggle to turn on or off the ability of wearing hats." );
	RegConsoleCmd("sm_chapeuon",	CmdHatOff,						"Toggle to turn on or off the ability of wearing hats." );
	RegConsoleCmd("sm_verchapeu",	CmdHatShow,						"Toggle to see or hide your own hat." );
	RegAdminCmd("sm_chapeuoffpara",	CmdHatOffC,		ADMFLAG_ROOT,	"Toggle the ability of wearing hats on specific players." );
	RegAdminCmd("sm_chapeupara",		CmdHatClient,	ADMFLAG_ROOT,	"Displays a menu listing players, select one to change their hat." );
	RegAdminCmd("sm_chapeurandom",	CmdHatRand,		ADMFLAG_ROOT,	"Randomizes all players hats." );
	RegAdminCmd("sm_chapeurand",	CmdHatRand,		ADMFLAG_ROOT,	"Randomizes all players hats." );
	RegAdminCmd("sm_hatadd",	CmdHatAdd,		ADMFLAG_ROOT,	"Adds specified model to the config (must be the full model path)." );
	RegAdminCmd("sm_hatdel",	CmdHatDel,		ADMFLAG_ROOT,	"Removes a model from the config (either by index or partial name matching)." );
	RegAdminCmd("sm_hatlist",	CmdHatList,		ADMFLAG_ROOT,	"Displays a list of all the hat models (for use with sm_hatdel)." );
	RegAdminCmd("sm_hatsave",	CmdHatSave,		ADMFLAG_ROOT,	"Saves the hat position and angels to the hat config." );
	RegAdminCmd("sm_hatload",	CmdHatLoad,		ADMFLAG_ROOT,	"Changes all players hats to the one you have." );
	RegAdminCmd("sm_hatang",	CmdAng,			ADMFLAG_ROOT,	"Shows a menu allowing you to adjust the hat angles (affects all hats/players)." );
	RegAdminCmd("sm_hatpos",	CmdPos,			ADMFLAG_ROOT,	"Shows a menu allowing you to adjust the hat position (affects all hats/players)." );
	RegAdminCmd("sm_hatsize",	CmdHatSize,		ADMFLAG_ROOT,	"Shows a menu allowing you to adjust the hat size (affects all hats/players)." );

	g_hCookie = RegClientCookie("l4d_hats", "Hat Type", CookieAccess_Protected);
}

public void OnPluginEnd()
{
	for( int i = 1; i <= MaxClients; i++ )
		RemoveHat(i);
}



// ====================================================================================================
//					CVARS
// ====================================================================================================
public void OnConfigsExecuted()
{
	IsAllowed();
}

public void ConVarChanged_Allow(Handle convar, const char[] oldValue, const char[] newValue)
{
	IsAllowed();
}

public void ConVarChanged_Cvars(Handle convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	char sTemp[32];
	g_hCvarMenu.GetString(sTemp, sizeof(sTemp));
	g_iCvarFlags = ReadFlagString(sTemp);
	g_fCvarChange = g_hCvarChange.FloatValue;
	g_iCvarOpaq = g_hCvarOpaq.IntValue;
	g_iCvarRand = g_hCvarRand.IntValue;
	g_iCvarSave = g_hCvarSave.IntValue;
	g_iCvarThird = g_hCvarThird.IntValue;
	g_bCvarView = g_hCvarView.BoolValue;
}

void IsAllowed()
{
	bool bCvarAllow = g_hCvarAllow.BoolValue;
	bool bAllowMode = IsAllowedGameMode();
	GetCvars();

	if( g_bCvarAllow == false && bCvarAllow == true && bAllowMode == true )
	{
		g_bCvarAllow = true;

		if( g_iCvarThird )
			HookViewEvents();
		HookEvents();

		for( int i = 1; i <= MaxClients; i++ )
		{
			g_bHatView[i] = g_bCvarView;
			g_iSelected[i] = GetRandomInt(0, g_iCount -1);
		}

		if( g_iCvarRand || g_iCvarSave )
		{
			for( int i = 1; i <= MaxClients; i++ )
			{
				if( IsClientInGame(i) )
				{
					int clientID = GetClientUserId(i);

					if( g_iCvarSave && !IsFakeClient(i) )
					{
						CreateTimer(0.1, tmrCookies, clientID);
						CreateTimer(0.3, tmrDelayCreate, clientID);
					}
					else if( g_iCvarRand )
					{
						CreateTimer(0.3, tmrDelayCreate, clientID);
					}
				}
			}
		}
	}

	else if( g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false) )
	{
		g_bCvarAllow = false;

		UnhookViewEvents();
		UnhookEvents();

		for( int i = 1; i <= MaxClients; i++ )
		{
			RemoveHat(i);
		}
	}
}

int g_iCurrentMode;
bool IsAllowedGameMode()
{
	if( g_hCvarMPGameMode == null )
		return false;

	int iCvarModesTog = g_hCvarModesTog.IntValue;
	if( iCvarModesTog != 0 )
	{
		g_iCurrentMode = 0;

		int entity = CreateEntityByName("info_gamemode");
		DispatchSpawn(entity);
		HookSingleEntityOutput(entity, "OnCoop", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnSurvival", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnVersus", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnScavenge", OnGamemode, true);
		ActivateEntity(entity);
		AcceptEntityInput(entity, "PostSpawnActivate");
		AcceptEntityInput(entity, "Kill");

		if( g_iCurrentMode == 0 )
			return false;

		if( !(iCvarModesTog & g_iCurrentMode) )
			return false;
	}

	char sGameModes[64], sGameMode[64];
	g_hCvarMPGameMode.GetString(sGameMode, sizeof(sGameMode));
	Format(sGameMode, sizeof(sGameMode), ",%s,", sGameMode);

	g_hCvarModes.GetString(sGameModes, sizeof(sGameModes));
	if( strcmp(sGameModes, "") )
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if( StrContains(sGameModes, sGameMode, false) == -1 )
			return false;
	}

	g_hCvarModesOff.GetString(sGameModes, sizeof(sGameModes));
	if( strcmp(sGameModes, "") )
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if( StrContains(sGameModes, sGameMode, false) != -1 )
			return false;
	}

	return true;
}

public void OnGamemode(const char[] output, int caller, int activator, float delay)
{
	if( strcmp(output, "OnCoop") == 0 )
		g_iCurrentMode = 1;
	else if( strcmp(output, "OnSurvival") == 0 )
		g_iCurrentMode = 2;
	else if( strcmp(output, "OnVersus") == 0 )
		g_iCurrentMode = 4;
	else if( strcmp(output, "OnScavenge") == 0 )
		g_iCurrentMode = 8;
}



// ====================================================================================================
//					O T H E R   B I T S
// ====================================================================================================
public void OnMapStart()
{
	for( int i = 0; i < g_iCount; i++ )
		PrecacheModel(g_sModels[i]);
}

public void OnClientAuthorized(int client, const char[] sSteamID)
{
	if( g_bBlocked[client] )
	{
		if( IsFakeClient(client) )
			g_bBlocked[client] = false;
		else if( strcmp(sSteamID, g_sSteamID[client]) )
		{
			strcopy(g_sSteamID[client], 32, sSteamID);
			g_bBlocked[client] = false;
		}
	}

	g_bMenuType[client] = false;

	if( g_bCvarAllow && g_iCvarSave )
	{
		int clientID = GetClientUserId(client);
		CreateTimer(0.1, tmrCookies, clientID);
	}
}

public Action tmrCookies(Handle timer, any client)
{
	client = GetClientOfUserId(client);

	if( client && !IsFakeClient(client) )
	{
		// Get client cookies, set type if available or default.
		char sCookie[3];
		GetClientCookie(client, g_hCookie, sCookie, sizeof(sCookie));

		if( strcmp(sCookie, "") == 0 )
		{
			g_iType[client] = 0;
		}
		else
		{
			int type = StringToInt(sCookie);
			g_iType[client] = type;
		}
	}
}

public void OnClientDisconnect(int client)
{
	if( g_hTimerView[client] != null )
	{
		delete g_hTimerView[client];
		g_hTimerView[client] = null;
	}
}

KeyValues OpenConfig()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "%s", CONFIG_SPAWNS);
	if( !FileExists(sPath) )
		SetFailState("Cannot find the file data/l4d_hats.cfg");

	KeyValues hFile = new KeyValues("models");
	if( !hFile.ImportFromFile(sPath) )
	{
		delete hFile;
		SetFailState("Cannot load the file 'data/l4d_hats.cfg'");
	}
	return hFile;
}

void SaveConfig(KeyValues hFile)
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "%s", CONFIG_SPAWNS);
	hFile.Rewind();
	hFile.ExportToFile(sPath);
}

void GetHatName(char sTemp[64], int i)
{
	strcopy(sTemp, 64, g_sModels[i]);
	ReplaceString(sTemp, 64, "_", " ");
	int pos = FindCharInString(sTemp, '/', true) + 1;
	int len = strlen(sTemp) - pos - 3;
	strcopy(sTemp, len, sTemp[pos]);
}

bool IsValidClient(int client)
{
	if( client && IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client) )
		return true;
	return false;
}



// ====================================================================================================
//					C V A R   C H A N G E S
// ====================================================================================================
public void CvarChangeOpac(Handle convar, const char[] oldValue, const char[] newValue)
{
	g_iCvarOpaq = g_hCvarOpaq.IntValue;

	if( g_bCvarAllow )
	{
		int entity;
		for( int i = 1; i <= MaxClients; i++ )
		{
			entity = g_iHatIndex[i];
			if( IsValidClient(i) && IsValidEntRef(entity) )
			{
				SetEntityRenderMode(entity, RENDER_TRANSCOLOR);
				SetEntityRenderColor(entity, 255, 255, 255, g_iCvarOpaq);
			}
		}
	}
}

public void CvarChangeThird(Handle convar, const char[] oldValue, const char[] newValue)
{
	g_iCvarThird = g_hCvarThird.IntValue;

	if( g_bCvarAllow )
	{
		if( g_iCvarThird )
		{
			HookViewEvents();
		}
		else
		{
			UnhookViewEvents();
		}
	}
}



// ====================================================================================================
//					E V E N T S
// ====================================================================================================
void HookEvents()
{
	HookEvent("round_start",		Event_Start);
	HookEvent("round_end",			Event_RoundEnd);
	HookEvent("player_death",		Event_PlayerDeath);
	HookEvent("player_spawn",		Event_PlayerSpawn);
	HookEvent("player_team",		Event_PlayerTeam);
}

void UnhookEvents()
{
	UnhookEvent("round_start",		Event_Start);
	UnhookEvent("round_end",		Event_RoundEnd);
	UnhookEvent("player_death",		Event_PlayerDeath);
	UnhookEvent("player_spawn",		Event_PlayerSpawn);
	UnhookEvent("player_team",		Event_PlayerTeam);
}

void HookViewEvents()
{
	if( g_bViewHooked == false )
	{
		g_bViewHooked = true;

		HookEvent("player_ledge_grab",		Event_Third1);
		HookEvent("revive_begin",			Event_Third1);
		HookEvent("revive_success",			Event_First1);
		HookEvent("revive_end",				Event_First1);
		HookEvent("lunge_pounce",			Event_Third);
		HookEvent("pounce_end",				Event_First);
		HookEvent("tongue_grab",			Event_Third);
		HookEvent("tongue_release",			Event_First);

		if( g_bLeft4Dead2 )
		{
			HookEvent("charger_pummel_start",		Event_Third);
			HookEvent("charger_carry_start",		Event_Third);
			HookEvent("charger_carry_end",			Event_First);
			HookEvent("charger_pummel_end",			Event_First);
		}
	}
}

void UnhookViewEvents()
{
	if( g_bViewHooked == false )
	{
		g_bViewHooked = true;

		UnhookEvent("player_ledge_grab",	Event_Third1);
		UnhookEvent("revive_begin",			Event_Third1);
		UnhookEvent("revive_success",		Event_First1);
		UnhookEvent("revive_end",			Event_First1);
		UnhookEvent("lunge_pounce",			Event_Third);
		UnhookEvent("pounce_end",			Event_First);
		UnhookEvent("tongue_grab",			Event_Third);
		UnhookEvent("tongue_release",		Event_First);

		if( g_bLeft4Dead2 )
		{
			UnhookEvent("charger_pummel_start",		Event_Third);
			UnhookEvent("charger_carry_start",		Event_Third);
			UnhookEvent("charger_carry_end",		Event_First);
			UnhookEvent("charger_pummel_end",		Event_First);
		}
	}
}

public void Event_Start(Event event, const char[] name, bool dontBroadcast)
{
	if( g_iCvarRand == 1 )
		CreateTimer(0.5, tmrRand, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action tmrRand(Handle timer)
{
	RandHat();
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	for( int i = 1; i <= MaxClients; i++ )
		RemoveHat(i);
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if( !client || GetClientTeam(client) != 2 )
		return;

	RemoveHat(client);
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if( g_iCvarRand || g_iCvarSave )
	{
		int clientID = event.GetInt("userid");
		int client = GetClientOfUserId(client);

		RemoveHat(client);
		CreateTimer(0.3, tmrDelayCreate, clientID);
	}
}

public void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	if( g_iCvarRand )
	{
		int clientID = event.GetInt("userid");
		int client = GetClientOfUserId(clientID);

		RemoveHat(client);
		CreateTimer(0.1, tmrDelayCreate, clientID);
	}
	int client2 = GetClientOfUserId(GetEventInt(event, "userid"));
	CreateTimer(1.0,PlayerChangeTeamCheck,client2);//延遲一秒檢查
}

public Action tmrDelayCreate(Handle timer, any client)
{
	client = GetClientOfUserId(client);
	if( IsValidClient(client) )
	{
		if( g_iCvarRand == 2 )
			CreateHat(client, -2);
		else if( g_iCvarSave && !IsFakeClient(client) )
			CreateHat(client, -3);
		else if( g_iCvarRand )
			CreateHat(client, -1);
	}
}

public Action PlayerChangeTeamCheck(Handle timer,int client)
{
	if (client && IsClientInGame(client) && GetClientTeam(client)!=2)
	{
		RemoveHat(client);
	}
}

public void Event_First1(Event event, const char[] name, bool dontBroadcast)
{
	EventView(GetClientOfUserId(event.GetInt("userid")), true);
	EventView(GetClientOfUserId(event.GetInt("subject")), true);
}

public void Event_Third1(Event event, const char[] name, bool dontBroadcast)
{
	EventView(GetClientOfUserId(event.GetInt("userid")), false);
}

public void Event_First(Event event, const char[] name, bool dontBroadcast)
{
	EventView(GetClientOfUserId(event.GetInt("victim")), true);
}

public void Event_Third(Event event, const char[] name, bool dontBroadcast)
{
	EventView(GetClientOfUserId(event.GetInt("victim")), false);
}

void EventView(int client, bool first)
{
	if( IsValidClient(client) )
	{
		if( first == true )
		{

			if( g_bHatView[client] == false )
			{
				int entity = g_iHatIndex[client];
				if( entity && (entity = EntRefToEntIndex(entity)) != INVALID_ENT_REFERENCE )
					SDKHook(entity, SDKHook_SetTransmit, Hook_SetTransmit);
			}
		}
		else if( first == false )
		{
			int entity = g_iHatIndex[client];
			if( entity && (entity = EntRefToEntIndex(entity)) != INVALID_ENT_REFERENCE )
				SDKUnhook(entity, SDKHook_SetTransmit, Hook_SetTransmit);
		}
	}
}



// ====================================================================================================
//					C O M M A N D S
// ====================================================================================================
//					sm_hat
// ====================================================================================================
public Action CmdHat(int client, int args)
{
	if( !g_bCvarAllow || !IsValidClient(client) )
	{
		CPrintToChat(client, "%s%t", CHAT_TAG, "No Access");
		return Plugin_Handled;
	}

	int flagc = GetUserFlagBits(client);

	if( g_iCvarFlags != 0 && !(flagc & ADMFLAG_ROOT) )
	{
		if( g_bBlocked[client] || !(flagc & g_iCvarFlags) )
		{
			CPrintToChat(client, "%s%t", CHAT_TAG, "No Access");
			return Plugin_Handled;
		}
	}

	if( args == 1 )
	{
		char sTemp[64];

		GetCmdArg(1, sTemp, sizeof(sTemp));

		if( strlen(sTemp) < 3 )
		{
			int index = StringToInt(sTemp);
			if( index < 1 || index >= (g_iCount + 1) )
			{
				CPrintToChat(client, "%s%t", CHAT_TAG, "Hat_No_Index", index, g_iCount);
			}
			else
			{
				RemoveHat(client);

				if( CreateHat(client, index - 1) )
				{
					ExternalView(client);
				}
			}
		}
		else
		{
			ReplaceString(sTemp, sizeof(sTemp), " ", "_");

			for( int i = 0; i < g_iCount; i++ )
			{
				if( StrContains(g_sModels[i], sTemp) != -1 || StrContains(g_sNames[i], sTemp) != -1 )
				{
					RemoveHat(client);

					if( CreateHat(client, i) )
					{
						ExternalView(client);
					}
					return Plugin_Handled;
				}
			}

			CPrintToChat(client, "%s%t", CHAT_TAG, "Hat_Not_Found", sTemp);
		}
	}
	else
	{
		ShowMenu(client);
	}

	return Plugin_Handled;
}

public int HatMenuHandler(Menu menu, MenuAction action, int client, int index)
{
	if( action == MenuAction_End && g_bTranslation == true && client != 0 )
	{
		delete menu;
	}
	else if( action == MenuAction_Select )
	{
		int target = g_iTarget[client];
		if( target )
		{
			g_iTarget[client] = 0;
			target = GetClientOfUserId(target);
			if( IsValidClient(target) )
			{
				char name[MAX_NAME_LENGTH];
				GetClientName(target, name, sizeof(name));

				CPrintToChat(client, "%s%t", CHAT_TAG, "Hat_Changed", name);
				RemoveHat(target);

				if( CreateHat(target, index) )
				{
					ExternalView(target);
				}
			}
			else
			{
				CPrintToChat(client, "%s%t", CHAT_TAG, "Hat_Invalid");
			}

			return;
		}
		else
		{
			RemoveHat(client);
			if( CreateHat(client, index) )
			{
				ExternalView(client);
			}
		}

		int menupos = menu.Selection;
		menu.DisplayAt(client, menupos, MENU_TIME_FOREVER);
	}
}

void ShowMenu(int client)
{
	if( g_bTranslation == false )
	{
		g_hMenu.Display(client, MENU_TIME_FOREVER);
	}
	else
	{
		char sTemp[256];
		Menu hTemp = new Menu(HatMenuHandler);
		hTemp.SetTitle("%T", "Hat_Menu_Title", client);

		for( int i = 0; i < g_iCount; i++ )
		{
			Format(sTemp, sizeof(sTemp), "Hat %d", i + 1, client);
			Format(sTemp, sizeof(sTemp), "%T", sTemp, client);
			hTemp.AddItem(g_sModels[i], sTemp);
		}

		hTemp.ExitButton = true;
		hTemp.Display(client, MENU_TIME_FOREVER);

		g_hMenus[client] = hTemp;
	}
}

// ====================================================================================================
//					sm_hatoff
// ====================================================================================================
public Action CmdHatOff(int client, int args)
{
	if( !g_bCvarAllow || g_bBlocked[client] )
	{
		CPrintToChat(client, "%s%t", CHAT_TAG, "No Access");
		return Plugin_Handled;
	}

	g_bHatOff[client] = !g_bHatOff[client];

	if( g_bHatOff[client] )
		RemoveHat(client);

	char sTemp[32];
	Format(sTemp, sizeof(sTemp), "%T", g_bHatOff[client] ? "Hat_Off" : "Hat_On", client);
	CPrintToChat(client, "%s%t", CHAT_TAG, "Hat_Ability", sTemp);

	return Plugin_Handled;
}

// ====================================================================================================
//					sm_hatshow
// ====================================================================================================
public Action CmdHatShow(int client, int args)
{
	if( !g_bCvarAllow || g_bBlocked[client] )
	{
		CPrintToChat(client, "%s%t", CHAT_TAG, "No Access");
		return Plugin_Handled;
	}

	int entity = g_iHatIndex[client];
	if( entity == 0 || (entity = EntRefToEntIndex(entity)) == INVALID_ENT_REFERENCE )
	{
		CPrintToChat(client, "%s%t", CHAT_TAG, "Hat_Missing");
		return Plugin_Handled;
	}

	g_bHatView[client] = !g_bHatView[client];
	if( !g_bHatView[client] )
		SDKHook(entity, SDKHook_SetTransmit, Hook_SetTransmit);
	else
		SDKUnhook(entity, SDKHook_SetTransmit, Hook_SetTransmit);

	char sTemp[32];
	Format(sTemp, sizeof(sTemp), "%T", g_bHatView[client] ? "Hat_On" : "Hat_Off", client);
	CPrintToChat(client, "%s%t", CHAT_TAG, "Hat_View", sTemp);
	return Plugin_Handled;
}



// ====================================================================================================
//					A D M I N   C O M M A N D S
// ====================================================================================================
//					sm_hatrand / sm_ratrandom
// ====================================================================================================
public Action CmdHatRand(int client, int args)
{
	if( g_bCvarAllow )
	{
		for( int i = 1; i <= MaxClients; i++ )
			RemoveHat(i);

		RandHat();
	}
	return Plugin_Handled;
}

void RandHat()
{
	for( int i = 1; i <= MaxClients; i++ )
	{
		if( IsValidClient(i) )
		{
			CreateHat(i);
		}
	}
}

// ====================================================================================================
//					sm_hatc / sm_hatoffc
// ====================================================================================================
public Action CmdHatClient(int client, int args)
{
	if( g_bCvarAllow )
		ShowPlayerList(client);
	return Plugin_Handled;
}

public Action CmdHatOffC(int client, int args)
{
	if( g_bCvarAllow )
	{
		g_bMenuType[client] = true;
		ShowPlayerList(client);
	}
	return Plugin_Handled;
}

void ShowPlayerList(int client)
{
	if( client && IsClientInGame(client) )
	{
		char sTempA[16], sTempB[MAX_NAME_LENGTH];
		Menu menu = new Menu(PlayerListMenur);

		for( int i = 1; i <= MaxClients; i++ )
		{
			if( IsValidClient(i) )
			{
				IntToString(GetClientUserId(i), sTempA, sizeof(sTempA));
				GetClientName(i, sTempB, sizeof(sTempB));
				menu.AddItem(sTempA, sTempB);
			}
		}

		if( g_bMenuType[client] )
			menu.SetTitle("Select player to disable hats:");
		else
			menu.SetTitle("Select player to change hat:");
		menu.ExitButton = true;
		menu.Display(client, MENU_TIME_FOREVER);
	}
}

public int PlayerListMenur(Menu menu, MenuAction action, int client, int index)
{
	if( action == MenuAction_End )
		delete menu;
	else if( action == MenuAction_Select )
	{
		char sTemp[32];
		menu.GetItem(index, sTemp, sizeof(sTemp));
		int target = StringToInt(sTemp);
		target = GetClientOfUserId(target);
		if( g_bMenuType[client] )
		{
			g_bMenuType[client] = false;
			g_bBlocked[target] = !g_bBlocked[target];

			if( g_bBlocked[target] == false )
			{
				if( IsValidClient(target) )
				{
					RemoveHat(target);
					CreateHat(target);

					char name[MAX_NAME_LENGTH];
					GetClientName(target, name, sizeof(name));
					CPrintToChat(client, "%s%t", CHAT_TAG, "Hat_Unblocked", name);
				}
			}
			else
			{
				char name[MAX_NAME_LENGTH];
				GetClientName(target, name, sizeof(name));
				GetClientAuthId(target, AuthId_Steam2, g_sSteamID[target], 32);
				CPrintToChat(client, "%s%t", CHAT_TAG, "Hat_Blocked", name);
				RemoveHat(target);
			}
		}
		else
		{
			if( IsValidClient(target) )
			{
				g_iTarget[client] = GetClientUserId(target);

				ShowMenu(client);
			}
		}
	}
}

// ====================================================================================================
//					sm_hatadd
// ====================================================================================================
public Action CmdHatAdd(int client, int args)
{
	if( !g_bCvarAllow )
		return Plugin_Handled;

	if( args == 1 )
	{
		if( g_iCount < MAX_HATS )
		{
			char sTemp[64], sKey[16];
			GetCmdArg(1, sTemp, 64);

			if( FileExists(g_sModels[g_iCount], true) )
			{
				strcopy(g_sModels[g_iCount], 64, sTemp);
				g_vAng[g_iCount] = view_as<float>({ 0.0, 0.0, 0.0 });
				g_vPos[g_iCount] = view_as<float>({ 0.0, 0.0, 0.0 });
				g_fSize[g_iCount] = 1.0;

				KeyValues hFile = OpenConfig();
				IntToString(g_iCount+1, sKey, 64);
				hFile.JumpToKey(sKey, true);
				hFile.SetString("mod", sTemp);
				SaveConfig(hFile);
				delete hFile;
				g_iCount++;
				ReplyToCommand(client, "%sAdded hat '\05%s\x03' %d/%d", CHAT_TAG, sTemp, g_iCount, MAX_HATS);
			}
			else
				ReplyToCommand(client, "%sCould not find the model '\05%s'. Not adding to config.", CHAT_TAG, sTemp);
		}
		else
		{
			ReplyToCommand(client, "%sReached maximum number of hats (%d)", CHAT_TAG, MAX_HATS);
		}
	}
	return Plugin_Handled;
}

// ====================================================================================================
//					sm_hatdel
// ====================================================================================================
public Action CmdHatDel(int client, int args)
{
	if( !g_bCvarAllow )
		return Plugin_Handled;

	if( args == 1 )
	{
		char sTemp[64], sModel[64], sKey[16];
		int index;
		bool bDeleted;

		GetCmdArg(1, sTemp,64);
		if( strlen(sTemp) < 3 )
		{
			index = StringToInt(sTemp);
			if( index < 1 || index >= (g_iCount + 1) )
			{
				ReplyToCommand(client, "%sCannot find the hat index %d, values between 1 and %d", CHAT_TAG, index, g_iCount);
				return Plugin_Handled;
			}
			index--;
			strcopy(sTemp, 64, g_sModels[index]);
		}
		else
		{
			index = 0;
		}

		KeyValues hFile = OpenConfig();

		for( int i = index; i < MAX_HATS; i++ )
		{
			Format(sKey, sizeof(sKey), "%d", i+1);
			if( hFile.JumpToKey(sKey) )
			{
				if( bDeleted )
				{
					Format(sKey, sizeof(sKey), "%d", i);
					hFile.SetSectionName(sKey);
					strcopy(g_sModels[i-1], 64, g_sModels[i]);
					strcopy(g_sNames[i-1], 64, g_sNames[i]);
					g_vAng[i-1] = g_vAng[i];
					g_vPos[i-1] = g_vPos[i];
					g_fSize[i-1] = g_fSize[i];
				}
				else
				{
					hFile.GetString("mod", sModel, 64);
					if( StrContains(sModel, sTemp) != -1 )
					{
						ReplyToCommand(client, "%sYou have deleted the hat '\x05%s\x03'", CHAT_TAG, sModel);
						hFile.DeleteKey(sTemp);

						g_iCount--;
						bDeleted = true;

						if( g_bTranslation == false )
						{
							g_hMenu.RemoveItem(i);
						}
						else
						{
							for( int x = 0; x <= MAXPLAYERS; x++ )
							{
								if( g_hMenus[x] != null )
								{
									g_hMenus[x].RemoveItem(i);
								}
							}
						}
					}
				}
			}
			hFile.Rewind();
			if( i == 63 )
			{
				if( bDeleted )
					SaveConfig(hFile);
				else
					ReplyToCommand(client, "%sCould not delete hat, did not find model '\x05%s\x03'", CHAT_TAG, sTemp);
			}
		}
		delete hFile;
	}
	else
	{
		int index = g_iSelected[client];

		if( g_bTranslation == false )
		{
			CPrintToChat(client, "%s%t", CHAT_TAG, "Hat_Wearing", g_sNames[index]);
		}
		else
		{
			char sMsg[128];
			Format(sMsg, sizeof(sMsg), "Hat %d", index + 1);
			Format(sMsg, sizeof(sMsg), "%t", sMsg);
			CPrintToChat(client, "%s%t", CHAT_TAG, "Hat_Wearing", sMsg);
		}
	}
	return Plugin_Handled;
}

// ====================================================================================================
//					sm_hatlist
// ====================================================================================================
public Action CmdHatList(int client, int args)
{
	for( int i = 0; i < g_iCount; i++ )
		ReplyToCommand(client, "%d) %s", i+1, g_sModels[i]);
	return Plugin_Handled;
}

// ====================================================================================================
//					sm_hatload
// ====================================================================================================
public Action CmdHatLoad(int client, int args)
{
	if( g_bCvarAllow && IsValidClient(client) )
	{
		int selected = g_iSelected[client];
		PrintToChat(client, "%sLoaded hat '\x05%s\x03' on all players.", CHAT_TAG, g_sModels[selected]);

		for( int i = 1; i <= MaxClients; i++ )
		{
			if( IsValidClient(i) )
			{
				RemoveHat(i);
				CreateHat(i, selected);
			}
		}
	}
	return Plugin_Handled;
}

// ====================================================================================================
//					sm_hatsave
// ====================================================================================================
public Action CmdHatSave(int client, int args)
{
	if( g_bCvarAllow && IsValidClient(client) )
	{
		int entity = g_iHatIndex[client];
		if( IsValidEntRef(entity) )
		{
			KeyValues hFile = OpenConfig();
			int index = g_iSelected[client];

			char sTemp[4];
			IntToString(index+1, sTemp, 4);
			if( hFile.JumpToKey(sTemp) )
			{
				float vAng[3], vPos[3];
				float fSize;

				GetEntPropVector(entity, Prop_Send, "m_angRotation", vAng);
				GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vPos);
				hFile.SetVector("ang", vAng);
				hFile.SetVector("loc", vPos);
				g_vAng[index] = vAng;
				g_vPos[index] = vPos;

				if( g_bLeft4Dead2 )
				{
					fSize = GetEntPropFloat(entity, Prop_Send, "m_flModelScale");
					if( fSize == 1.0 )
					{
						if( hFile.GetFloat("size", 999.9) != 999.9 )
							hFile.DeleteKey("size");
					}
					else
						hFile.SetFloat("size", fSize);

					g_fSize[index] = fSize;
				}

				SaveConfig(hFile);
				PrintToChat(client, "%sSaved '\x05%s\x03' hat origin and angles.", CHAT_TAG, g_sModels[index]);
			}
			else
			{
				PrintToChat(client, "%s\x04Warning: \x03Could not save '\x05%s\x03' hat origin and angles.", CHAT_TAG, g_sModels[index]);
			}
			delete hFile;
		}
	}

	return Plugin_Handled;
}

// ====================================================================================================
//					sm_hatang
// ====================================================================================================
public Action CmdAng(int client, int args)
{
	if( g_bCvarAllow )
		ShowAngMenu(client);
	return Plugin_Handled;
}

void ShowAngMenu(int client)
{
	if( !IsValidClient(client) )
	{
		CPrintToChat(client, "%s%t", CHAT_TAG, "No Access");
		return;
	}

	Menu menu = new Menu(AngMenuHandler);

	menu.AddItem("", "X + 10.0");
	menu.AddItem("", "Y + 10.0");
	menu.AddItem("", "Z + 10.0");
	menu.AddItem("", "Reset");
	menu.AddItem("", "X - 10.0");
	menu.AddItem("", "Y - 10.0");
	menu.AddItem("", "Z - 10.0");

	menu.SetTitle("Set hat angles.");
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int AngMenuHandler(Menu menu, MenuAction action, int client, int index)
{
	if( action == MenuAction_End )
		delete menu;
	else if( action == MenuAction_Cancel )
	{
		if( index == MenuCancel_ExitBack )
			ShowAngMenu(client);
	}
	else if( action == MenuAction_Select )
	{
		if( IsValidClient(client) )
		{
			ShowAngMenu(client);

			float vAng[3];
			int entity;
			for( int i = 1; i <= MaxClients; i++ )
			{
				if( IsValidClient(i) )
				{
					entity = g_iHatIndex[i];
					if( IsValidEntRef(entity) )
					{
						GetEntPropVector(entity, Prop_Send, "m_angRotation", vAng);
						if( index == 0 ) vAng[0] += 10.0;
						else if( index == 1 ) vAng[1] += 10.0;
						else if( index == 2 ) vAng[2] += 10.0;
						else if( index == 4 ) vAng[0] -= 10.0;
						else if( index == 3 )
						{
							vAng = view_as<float>({0.0,0.0,0.0});
						}
						else if( index == 5 ) vAng[1] -= 10.0;
						else if( index == 6 ) vAng[2] -= 10.0;
						TeleportEntity(entity, NULL_VECTOR, vAng, NULL_VECTOR);
					}
				}
			}

			CPrintToChat(client, "%sNew hat angles: %f %f %f", CHAT_TAG, vAng[0], vAng[1], vAng[2]);
		}
	}
}

// ====================================================================================================
//					sm_hatpos
// ====================================================================================================
public Action CmdPos(int client, int args)
{
	if( g_bCvarAllow )
		ShowPosMenu(client);
	return Plugin_Handled;
}

void ShowPosMenu(int client)
{
	if( !IsValidClient(client) )
	{
		CPrintToChat(client, "%s%t", CHAT_TAG, "No Access");
		return;
	}

	Menu menu = new Menu(PosMenuHandler);

	menu.AddItem("", "X + 0.5");
	menu.AddItem("", "Y + 0.5");
	menu.AddItem("", "Z + 0.5");
	menu.AddItem("", "Reset");
	menu.AddItem("", "X - 0.5");
	menu.AddItem("", "Y - 0.5");
	menu.AddItem("", "Z - 0.5");

	menu.SetTitle("Set hat position.");
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int PosMenuHandler(Menu menu, MenuAction action, int client, int index)
{
	if( action == MenuAction_End )
		delete menu;
	else if( action == MenuAction_Cancel )
	{
		if( index == MenuCancel_ExitBack )
			ShowPosMenu(client);
	}
	else if( action == MenuAction_Select )
	{
		if( IsValidClient(client) )
		{
			ShowPosMenu(client);

			float vPos[3];
			int entity;
			for( int i = 1; i <= MaxClients; i++ )
			{
				if( IsValidClient(i) )
				{
					entity = g_iHatIndex[i];
					if( IsValidEntRef(entity) )
					{
						GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vPos);
						if( index == 0 ) vPos[0] += 0.5;
						else if( index == 1 ) vPos[1] += 0.5;
						else if( index == 2 ) vPos[2] += 0.5;
						else if( index == 3 )
						{
							vPos = view_as<float>({0.0,0.0,0.0});
						}
						else if( index == 4 ) vPos[0] -= 0.5;
						else if( index == 5 ) vPos[1] -= 0.5;
						else if( index == 6 ) vPos[2] -= 0.5;
						TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);
					}
				}
			}

			CPrintToChat(client, "%sNew hat origin: %f %f %f", CHAT_TAG, vPos[0], vPos[1], vPos[2]);
		}
	}
}

// ====================================================================================================
//					sm_hatsize
// ====================================================================================================
public Action CmdHatSize(int client, int args)
{
	if( g_bCvarAllow )
		ShowSizeMenu(client);
	return Plugin_Handled;
}

void ShowSizeMenu(int client)
{
	if( !IsValidClient(client) )
	{
		CPrintToChat(client, "%s%t", CHAT_TAG, "No Access");
		return;
	}

	if( !g_bLeft4Dead2 )
	{
		CPrintToChat(client, "%sCannot set hat size in L4D1.", CHAT_TAG);
		return;
	}

	Menu menu = new Menu(SizeMenuHandler);

	menu.AddItem("", "+ 0.1");
	menu.AddItem("", "- 0.1");
	menu.AddItem("", "+ 0.5");
	menu.AddItem("", "- 0.5");
	menu.AddItem("", "+ 1.0");
	menu.AddItem("", "- 1.0");
	menu.AddItem("", "Reset");

	menu.SetTitle("Set hat size.");
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int SizeMenuHandler(Menu menu, MenuAction action, int client, int index)
{
	if( action == MenuAction_End )
		delete menu;
	else if( action == MenuAction_Cancel )
	{
		if( index == MenuCancel_ExitBack )
			ShowSizeMenu(client);
	}
	else if( action == MenuAction_Select )
	{
		if( IsValidClient(client) )
		{
			ShowSizeMenu(client);

			float fSize;
			int entity;
			for( int i = 1; i <= MaxClients; i++ )
			{
				entity = g_iHatIndex[i];
				if( IsValidEntRef(entity) )
				{
					fSize = GetEntPropFloat(entity, Prop_Send, "m_flModelScale");
					if( index == 0 ) fSize += 0.1;
					else if( index == 1 ) fSize -= 0.1;
					else if( index == 2 ) fSize += 0.5;
					else if( index == 3 ) fSize -= 0.5;
					else if( index == 4 ) fSize += 1.0;
					else if( index == 5 ) fSize -= 1.0;
					else if( index == 6 ) fSize = 1.0;
					SetEntPropFloat(entity, Prop_Send, "m_flModelScale", fSize);
				}
			}

			CPrintToChat(client, "%sNew hat scale: %f", CHAT_TAG, fSize);
		}
	}
}



// ====================================================================================================
//					H A T   S T U F F
// ===================================================================================================
void RemoveHat(int client)
{
	int entity = g_iHatIndex[client];
	g_iHatIndex[client] = 0;

	if( IsValidEntRef(entity) )
		AcceptEntityInput(entity, "kill");
}

bool CreateHat(int client, int index = -1)
{
	if( g_bBlocked[client] || g_bHatOff[client] || IsValidEntRef(g_iHatIndex[client]) == true || IsValidClient(client) == false )
		return false;

	if( index == -1 ) // Random hat
	{
		if( g_iCvarRand == 3 && g_iCvarFlags != 0 )
		{
			if( IsFakeClient(client) )
				return false;

			int flagc = GetUserFlagBits(client);
			if( !(flagc & ADMFLAG_ROOT) && !(flagc & g_iCvarFlags) )
				return false;
		}

		index = GetRandomInt(0, g_iCount -1);
		g_iType[client] = index + 1;
	}
	else if( index == -2 ) // Previous random hat
	{
		index = g_iType[client];

		if( index == 0 )
			index = GetRandomInt(1, g_iCount);

		index--;
	}
	else if( index == -3 ) // Saved hats
	{
		index = g_iType[client];

		if( index == 0 )
		{
			if( IsFakeClient(client) == false )
				return false;
			else
				index = GetRandomInt(1, g_iCount);
		}

		index--;
	}
	else // Specified hat
	{
		g_iType[client] = index + 1;
	}

	char sNum[8];
	IntToString(index + 1, sNum, sizeof(sNum));

	if( g_iCvarSave && !IsFakeClient(client) )
	{
		SetClientCookie(client, g_hCookie, sNum);
	}

	int entity = CreateEntityByName("prop_dynamic_override");
	if( entity != -1 )
	{
		SetEntityModel(entity, g_sModels[index]);
		DispatchSpawn(entity);
		if( g_bLeft4Dead2 )
		{
			SetEntPropFloat(entity, Prop_Send, "m_flModelScale", g_fSize[index]);
		}

		SetVariantString("!activator");
		AcceptEntityInput(entity, "SetParent", client);
		SetVariantString("eyes");
		AcceptEntityInput(entity, "SetParentAttachment");

		// Lux
		AcceptEntityInput(entity, "DisableCollision");
		SetEntProp(entity, Prop_Send, "m_noGhostCollision", 1, 1);
		SetEntProp(entity, Prop_Data, "m_CollisionGroup", 0x0004);
		SetEntPropVector(entity, Prop_Send, "m_vecMins", view_as<float>({0.0, 0.0, 0.0}));
		SetEntPropVector(entity, Prop_Send, "m_vecMaxs", view_as<float>({0.0, 0.0, 0.0}));
		// Lux

		TeleportEntity(entity, g_vPos[index], g_vAng[index], NULL_VECTOR);
		SetEntProp(entity, Prop_Data, "m_iEFlags", 0);

		if( g_iCvarOpaq )
		{
			SetEntityRenderMode(entity, RENDER_TRANSCOLOR);
			SetEntityRenderColor(entity, 255, 255, 255, g_iCvarOpaq);
		}

		g_iSelected[client] = index;
		g_iHatIndex[client] = EntIndexToEntRef(entity);

		if( !g_bHatView[client] )
			SDKHook(entity, SDKHook_SetTransmit, Hook_SetTransmit);

		if( g_bTranslation == false )
		{
			CPrintToChat(client, "%s%t", CHAT_TAG, "Hat_Wearing", g_sNames[index]);
		}
		else
		{
			char sMsg[128];
			Format(sMsg, sizeof(sMsg), "Hat %d", index + 1);
			Format(sMsg, sizeof(sMsg), "%T", sMsg, client);
			CPrintToChat(client, "%s%t", CHAT_TAG, "Hat_Wearing", sMsg);
		}

		return true;
	}

	return false;
}

void ExternalView(int client)
{
	if( g_fCvarChange )
	{
		EventView(client, false);

		if( g_hTimerView[client] != null )
			delete g_hTimerView[client];

		if( g_fCvarChange >= 2.0 )
			g_hTimerView[client] = CreateTimer(g_fCvarChange + 0.4, TimerEventView, GetClientUserId(client));
		else
			g_hTimerView[client] = CreateTimer(g_fCvarChange + 0.2, TimerEventView, GetClientUserId(client));

		// Survivor Thirdperson plugin sets 99999.3.
		if( GetEntPropFloat(client, Prop_Send, "m_TimeForceExternalView") == 99999.3 )
			return;

		SetEntPropFloat(client, Prop_Send, "m_TimeForceExternalView", GetGameTime() + g_fCvarChange);
	}
}

public Action TimerEventView(Handle timer, any client)
{
	client = GetClientOfUserId(client);
	if( client )
	{
		EventView(client, true);
		g_hTimerView[client] = null;
	}
}

public Action Hook_SetTransmit(int entity, int client)
{
	if( EntIndexToEntRef(entity) == g_iHatIndex[client] )
		return Plugin_Handled;
	return Plugin_Continue;
}

bool IsValidEntRef(int entity)
{
	if( entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE )
		return true;
	return false;
}