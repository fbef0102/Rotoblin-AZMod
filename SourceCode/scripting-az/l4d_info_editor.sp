/*
*	Mission and Weapons - Info Editor
*	Copyright (C) 2020 Silvers
*
*	This program is free software: you can redistribute it and/or modify
*	it under the terms of the GNU General Public License as published by
*	the Free Software Foundation, either version 3 of the License, or
*	(at your option) any later version.
*
*	This program is distributed in the hope that it will be useful,
*	but WITHOUT ANY WARRANTY; without even the implied warranty of
*	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*	GNU General Public License for more details.
*
*	You should have received a copy of the GNU General Public License
*	along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/



#define PLUGIN_VERSION		"1.12"

/*======================================================================================
	Plugin Info:

*	Name	:	[L4D & L4D2] Mission and Weapons - Info Editor
*	Author	:	SilverShot
*	Descrp	:	Modify gamemodes.txt and weapons.txt values by config instead of conflicting VPK files.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=310586
*	Plugins	:	https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.12 (01-Oct-2020)
	- Fixed not properly adding both melee weapons causing potential issues.

1.11 (24-Sep-2020)
	- Compatibility update for L4D2's "The Last Stand" update.
	- Added support for the 2 new melee weapons.
	- GameData .txt file updated.

1.10 (02-Jul-2020)
	- Fixed not always loading the correct map section data in the config for the current map.
	- Fixed not adding 3rd party melee weapons on all 3rd party maps. Thanks to "Shao" for reporting.

1.9 (10-May-2020)
	- Added better error log message when gamedata file is missing.
	- Now supports setting strings to "" when using the "InfoEditor_SetString" native.
	- Various changes to tidy up code.
	- Various optimizations and fixes.

1.8 (30-Apr-2020)
	- Changed "InfoEditor_GetString" and "InfoEditor_SetString" natives to not require the mission pointer.
	- Specifying 0 when calling will make Info Editor use the last known mission pointer value.
	- A valid pointer will still be required to read weapons data.

1.7 (12-Apr-2020)
	- Fixed breaking some melee entries when adding 3rd party melee names containing similar classnames.
	- Thanks to "Marttt" for reporting.

1.6 (10-Apr-2020)
	- Added support to match multiple map names using comma separation in the data configs, as requested by "Lux".
	- Added "clip_size", "ReloadDuration", "CycleTime", "Damage", "Range" and "RangeModifier" to "l4d_info_editor_weapons.cfg" config.
	- Values shown are default from L4D2 weapon scripts.
	- Fixed not creating keys for weapons and accidentally creating them on the mission file instead.

1.5 (01-Apr-2020)
	- Changed command block to allow listen servers to operate the reload command.
	- Changed .inc file to remove args from copy paste error of "InfoEditor_ReloadData" native.

1.4 (18-Mar-2020)
	- Added native "InfoEditor_ReloadData" for external plugins to reload the mission and weapon configs.
	- Fixed crashing with "CTerrorWeaponInfo::Reload" error. Finally!

1.3 (25-Feb-2020)
	- Now dynamically generates "meleeweapons" string for any map using custom melee weapons.
	- Set the string to the default game weapons you want to include, and the custom ones will be added.
	- Mission config "l4d_info_editor_mission.cfg" updated with changes for "Helms Deep" map.

1.2 (17-Sep-2019)
	- No longer removing cheat flags from "sb_all_bot_game" command, was never deleted from testing.

1.1.1a (25-Aug-2019) re-upload
	- Added "helms_deep" section in the mission config to enable all melee weapons on that map.

1.1.1 (09-Jun-2019)
	- Added FORCE_VALUES define to force create missing keys.
	- Slightly optimized fixing single line mistake.
	- Slight code cleaning.

1.1 (01-Jun-2019)
	- Fixed reading incorrect data for map specific sections.
	- Added support to load map specific weapon and melee data.
	- Added commands to display mission and weapon changes applied to the current map.
	- Added a command to get and set keyname values from the mission info.
	- Added a command to reload the mission and weapons configs. Live changes can be made!
	- Added natives to read and write mission and weapon data from third party plugins.
	- Added test plugin to demonstrate natives and forwards for developers.
	- Gamedata .txt changed.

1.0 (10-Sep-2018)
	- Initial release.

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <dhooks>

#define GAMEDATA				"l4d_info_editor"
#define CONFIG_MISSION			"data/l4d_info_editor_mission.cfg"
#define CONFIG_WEAPONS			"data/l4d_info_editor_weapons.cfg"
#define MAX_STRING_LENGTH		4096
#define DEBUG_VALUES			0
#define FORCE_VALUES			1 // Force create keyvalues when not found.

Handle g_hForwardOnGetMission;
Handle g_hForwardOnGetWeapons;
Handle SDK_KV_GetString;
Handle SDK_KV_SetString;
Handle SDK_KV_FindKey;
ArrayList g_alMissionData;
ArrayList g_alWeaponsData;
int g_PointerMission;
bool g_bLeft4Dead2;
bool g_bLoadNewMap;
char g_sLastMap[PLATFORM_MAX_PATH];



// ====================================================================================================
//					PLUGIN INFO / NATIVES
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D & L4D2] Mission and Weapons - Info Editor",
	author = "SilverShot",
	description = "Modify gamemodes.txt and weapons.txt values by config instead of conflicting VPK files.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=310586"
}

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

	// Natives
	RegPluginLibrary("info_editor");
	CreateNative("InfoEditor_GetString",		Native_GetString);
	CreateNative("InfoEditor_SetString",		Native_SetString);
	CreateNative("InfoEditor_ReloadData",		Native_ReloadData);

	return APLRes_Success;
}

public int Native_GetString(Handle plugin, int numParams)
{
	// Pointer to keyvalue for modifying
	int pThis = GetNativeCell(1);
	if( pThis == 0 ) pThis = g_PointerMission;
	if( pThis == 0 ) return; // Some maps maybe invalid (due to invalid gamemode).

	// Validate string
	int len;
	GetNativeStringLength(2, len);
	if( len <= 0 ) return;

	// Key name to get
	char key[MAX_STRING_LENGTH];
	GetNativeString(2, key, sizeof(key));

	// Get key value
	char value[MAX_STRING_LENGTH];
	SDKCall(SDK_KV_GetString, pThis, value, sizeof(value), key, "N/A");

	// Return string
	int maxlength = GetNativeCell(4);
	SetNativeString(3, value, maxlength);
}

public int Native_SetString(Handle plugin, int numParams)
{
	// Pointer to keyvalue for modifying
	int pThis = GetNativeCell(1);
	if( pThis == 0 ) pThis = g_PointerMission;
	if( pThis == 0 ) return; // Some maps maybe invalid (due to invalid gamemode).

	// Validate string
	int len;
	GetNativeStringLength(2, len);
	if( len <= 0 ) return;
	GetNativeStringLength(3, len);

	// Key name and value to set
	char key[MAX_STRING_LENGTH];
	char[] value = new char[len+1];
	GetNativeString(2, key, sizeof(key));
	GetNativeString(3, value, len+1);

	// Create
	bool bCreate = GetNativeCell(4);
	if( bCreate && SDK_KV_FindKey != null )
	{
		char sCheck[MAX_STRING_LENGTH];
		SDKCall(SDK_KV_GetString, pThis, sCheck, sizeof(sCheck), key, "N/A");
		if( strcmp(sCheck, "N/A") == 0 )
		{
			SDKCall(SDK_KV_FindKey, pThis, key, true);
		}
	}

	// Set key value
	SDKCall(SDK_KV_SetString, pThis, key, value);
}



// ====================================================================================================
//					PLUGIN START / END
// ====================================================================================================
public void OnPluginStart()
{
	CreateConVar("l4d_info_editor_version", PLUGIN_VERSION, "Mission and Weapons - Info Editor plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);

	// ====================================================================================================
	// SDKCalls
	// ====================================================================================================
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "gamedata/%s.txt", GAMEDATA);
	if( FileExists(sPath) == false ) SetFailState("\n==========\nMissing required file: \"%s\".\nRead installation instructions again.\n==========", sPath);

	Handle hGameData = LoadGameConfigFile(GAMEDATA);
	if( hGameData == null ) SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	StartPrepSDKCall(SDKCall_Raw);
	if( PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "KeyValues::GetString") == false )
		SetFailState("Could not load the \"KeyValues::GetString\" gamedata signature.");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_String, SDKPass_Pointer);
	SDK_KV_GetString = EndPrepSDKCall();
	if( SDK_KV_GetString == null )
		SetFailState("Could not prep the \"KeyValues::GetString\" function.");

	StartPrepSDKCall(SDKCall_Raw);
	if( PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "KeyValues::SetString") == false )
		SetFailState("Could not load the \"KeyValues::SetString\" gamedata signature.");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	SDK_KV_SetString = EndPrepSDKCall();
	if( SDK_KV_SetString == null )
		SetFailState("Could not prep the \"KeyValues::SetString\" function.");

	// Optional, not required.
	StartPrepSDKCall(SDKCall_Raw);
	if( PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "KeyValues::FindKey") == false )
	{
		LogError("Could not load the \"KeyValues::FindKey\" gamedata signature.");
	} else {
		PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
		PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Pointer);
		SDK_KV_FindKey = EndPrepSDKCall();
		if( SDK_KV_FindKey == null )
			LogError("Could not prep the \"KeyValues::FindKey\" function.");
	}

	// ====================================================================================================
	// Detours
	// ====================================================================================================
	Handle hDetour;

	// Mission Info
	hDetour = DHookCreateFromConf(hGameData, "CTerrorGameRules::GetMissionInfo");
	if( !hDetour )
		SetFailState("Failed to find \"CTerrorGameRules::GetMissionInfo\" signature.");
	if( !DHookEnableDetour(hDetour, true, GetMissionInfo) )
		SetFailState("Failed to detour \"CTerrorGameRules::GetMissionInfo\".");
	delete hDetour;

	// Weapon Info
	hDetour = DHookCreateFromConf(hGameData, "CTerrorWeaponInfo::Parse");
	if( !hDetour )
		SetFailState("Failed to find \"CTerrorWeaponInfo::Parse\" signature.");
	if( !DHookEnableDetour(hDetour, false, GetWeaponInfo) )
		SetFailState("Failed to detour \"CTerrorWeaponInfo::Parse\".");
	delete hDetour;

	if( g_bLeft4Dead2 )
	{
		// Melee Weapons
		hDetour = DHookCreateFromConf(hGameData, "CMeleeWeaponInfo::Parse");
		if( !hDetour )
			SetFailState("Failed to find \"CMeleeWeaponInfo::Parse\" signature.");
		if( !DHookEnableDetour(hDetour, false, GetMeleeWeaponInfo) )
			SetFailState("Failed to detour \"CMeleeWeaponInfo::Parse\".");
		delete hDetour;

		// Allow all Melee weapon types
		hDetour = DHookCreateFromConf(hGameData, "CDirectorItemManager::IsMeleeWeaponAllowedToExist");
		if( !hDetour )
			SetFailState("Failed to find \"CDirectorItemManager::IsMeleeWeaponAllowedToExist\" signature.");
		if( !DHookEnableDetour(hDetour, true, MeleeWeaponAllowedToExist) )
			SetFailState("Failed to detour \"CDirectorItemManager::IsMeleeWeaponAllowedToExist\".");
		delete hDetour;
	}

	delete hGameData;

	// Strip cheat flags here, because executing when required with a CheatCommand() function to strip/add the cheat flag denies with the error:
	// "Can't use cheat command weapon_reparse_server in multiplayer, unless the server has sv_cheats set to 1."
	// We'll also block clients from executing the commands to prevent any potential exploit or command spam.
	SetCommandFlags("weapon_reparse_server", GetCommandFlags("weapon_reparse_server") & ~FCVAR_CHEAT);
	AddCommandListener(CmdListenBlock, "weapon_reparse_server");
	if( g_bLeft4Dead2 )
	{
		SetCommandFlags("melee_reload_info_server", GetCommandFlags("melee_reload_info_server") & ~FCVAR_CHEAT);
		AddCommandListener(CmdListenBlock, "melee_reload_info_server");
	}

	// Forwards
	g_hForwardOnGetMission = CreateGlobalForward("OnGetMissionInfo", ET_Ignore, Param_Cell);
	g_hForwardOnGetWeapons = CreateGlobalForward("OnGetWeaponsInfo", ET_Ignore, Param_Cell, Param_String);

	// Load config
	ResetPlugin();

	// Commands
	RegAdminCmd("sm_info_weapons_list",	CmdInfoWeaponsList,	ADMFLAG_ROOT, "Show weapons config tree of modified data for this map.");
	RegAdminCmd("sm_info_mission_list",	CmdInfoMissionList,	ADMFLAG_ROOT, "Show mission config tree of modified data for this map.");
	RegAdminCmd("sm_info_mission",		CmdInfoMission,		ADMFLAG_ROOT, "Get or set the value of a mission keyname. Usage: sm_info_mission <keyname> [value].");
	RegAdminCmd("sm_info_reload",		CmdInfoReload,		ADMFLAG_ROOT, "Reloads the mission and weapons configs. Weapons info data is re-parsed allowing changes to be made live without changing level.");
}

public Action CmdListenBlock(int client, const char[] command, int argc)
{
	client = IsDedicatedServer() ? client : (client > 1 ? client : 0);

	if( client )
		return Plugin_Handled;
	return Plugin_Continue;
}

public void OnMapEnd()
{
	GetCurrentMap(g_sLastMap, sizeof(g_sLastMap));
	g_bLoadNewMap = true;
}



// ====================================================================================================
//					COMMANDS
// ====================================================================================================
public Action CmdInfoReload(int client, int args)
{
	g_sLastMap[0] = 0;
	ReloadData();
	ReplyToCommand(client, "[Info Editor] Reloaded configs and weapon attributes.");
	return Plugin_Handled;
}

public int Native_ReloadData(Handle plugin, int numParams)
{
	ReloadData();
}

void ReloadData()
{
	// Weapons Info is re-parsed via command in this function.
	ResetPlugin();

	// Mission Info has no command, but we can manually set changes with ease.
	char key[MAX_STRING_LENGTH];
	char value[MAX_STRING_LENGTH];
	for( int i = 0; i < g_alMissionData.Length; i += 2 )
	{
		g_alMissionData.GetString(i, key, sizeof(key));
		g_alMissionData.GetString(i + 1, value, sizeof(value));

		char check[MAX_STRING_LENGTH];
		SDKCall(SDK_KV_GetString, g_PointerMission, check, sizeof(check), key, "N/A");

		// Dynamic Melee Weapons:
		if( g_bLeft4Dead2 && strcmp(check, "N/A") && strcmp(key, "meleeweapons") == 0 )
		{
			Format(check, sizeof(check), ";%s;", check);
			ReplaceStringEx(check, sizeof(check), ";riot_shield;", ";");
			ReplaceStringEx(check, sizeof(check), ";baseball_bat;", ";");
			ReplaceStringEx(check, sizeof(check), ";cricket_bat;", ";");
			ReplaceStringEx(check, sizeof(check), ";crowbar;", ";");
			ReplaceStringEx(check, sizeof(check), ";electric_guitar;", ";");
			ReplaceStringEx(check, sizeof(check), ";fireaxe;", ";");
			ReplaceStringEx(check, sizeof(check), ";frying_pan;", ";");
			ReplaceStringEx(check, sizeof(check), ";golfclub;", ";");
			ReplaceStringEx(check, sizeof(check), ";katana;", ";");
			ReplaceStringEx(check, sizeof(check), ";knife;", ";");
			ReplaceStringEx(check, sizeof(check), ";machete;", ";");
			ReplaceStringEx(check, sizeof(check), ";tonfa;", ";");
			ReplaceStringEx(check, sizeof(check), ";pitchfork;", ";");
			ReplaceStringEx(check, sizeof(check), ";shovel;", ";");

			int pos = strlen(check);
			if( pos > 0 )
			{
				if( check[pos - 1] == ';' ) check[pos - 1] = 0;
				StrCat(value, sizeof(value), ";");
				StrCat(value, sizeof(value), check[1]);
				pos = strlen(value);
				if( pos > 0 )
				{
					if( value[pos - 1] == ';' ) value[pos - 1] = 0;
				}
			}
		}

		if( strcmp(check, value) )
		{
			#if DEBUG_VALUES || FORCE_VALUES
			if( strcmp(check, "N/A") == 0 )
			{
				#if FORCE_VALUES
					if( SDK_KV_FindKey != null )
					{
						SDKCall(SDK_KV_FindKey, g_PointerMission, key, true);
						#if DEBUG_VALUES
							PrintToServer("MissionInfo: Attempted to create \"%s\".", key);
						#endif
					}
				#endif

				#if DEBUG_VALUES
					PrintToServer("MissionInfo: \"%s\" not found.", key);
				#endif
			} else {
				#if DEBUG_VALUES
					PrintToServer("MissionInfo: Set \"%s\" to \"%s\". Was \"%s\".", key, value, check);
				#endif
			}
			#endif

			SDKCall(SDK_KV_SetString, g_PointerMission, key, value);
		}
	}
}

public Action CmdInfoMission(int client, int args)
{
	if( args == 1 )
	{
		char key[MAX_STRING_LENGTH];
		char value[MAX_STRING_LENGTH];
		GetCmdArg(1, key, sizeof(key));

		SDKCall(SDK_KV_GetString, g_PointerMission, value, sizeof(value), key, "N/A");
		ReplyToCommand(client, "[Info] Key \"%s\" = \"%s\".", key, value);
	}

	else if( args == 2 )
	{
		char key[MAX_STRING_LENGTH];
		char value[MAX_STRING_LENGTH];
		char check[MAX_STRING_LENGTH];
		GetCmdArg(1, key, sizeof(key));
		GetCmdArg(2, value, sizeof(value));

		// Check value
		SDKCall(SDK_KV_GetString, g_PointerMission, check, sizeof(check), key, "N/A");

		// Create if not found.
		bool existed = true;
		if( SDK_KV_FindKey != null && strcmp(check, "N/A") == 0 )
		{
			SDKCall(SDK_KV_FindKey, g_PointerMission, key, true);
			existed = false;
		}

		SDKCall(SDK_KV_SetString, g_PointerMission, key, value);

		if( existed )
			ReplyToCommand(client, "[Info] Set \"%s\" to \"%s\".", key, value);
		else
			ReplyToCommand(client, "[Info] Created \"%s\" set \"%s\".", key, value);
	}

	else
	{
		ReplyToCommand(client, "Usage: sm_info_mission <keyname> [value]");
		return Plugin_Handled;
	}

	return Plugin_Handled;
}

public Action CmdInfoMissionList(int client, int args)
{
	char key[MAX_STRING_LENGTH];
	char value[MAX_STRING_LENGTH];

	ReplyToCommand(client, "=============================");
	ReplyToCommand(client, "===== MISSION INFO DATA =====");
	ReplyToCommand(client, "=============================");

	for( int i = 0; i < g_alMissionData.Length; i += 2 )
	{
		g_alMissionData.GetString(i, key, sizeof(key));
		g_alMissionData.GetString(i + 1, value, sizeof(value));

		ReplyToCommand(client, "%s %s", key, value);
	}

	ReplyToCommand(client, "=============================");
	return Plugin_Handled;
}

public Action CmdInfoWeaponsList(int client, int args)
{
	ArrayList aHand;
	int size;
	char key[MAX_STRING_LENGTH];
	char value[MAX_STRING_LENGTH];
	char check[MAX_STRING_LENGTH];

	ReplyToCommand(client, "=============================");
	ReplyToCommand(client, "===== WEAPONS INFO DATA =====");
	ReplyToCommand(client, "=============================");

	for( int x = 0; x < g_alWeaponsData.Length; x++ )
	{
		// Weapon classname
		aHand = g_alWeaponsData.Get(x);
		aHand.GetString(0, check, sizeof(check));

		ReplyToCommand(client, check);

		// Weapon keys and values
		size = aHand.Length;
		for( int i = 1; i < size; i+=2 )
		{
			aHand.GetString(i, key, sizeof(key));
			aHand.GetString(i+1, value, sizeof(value));
			ReplyToCommand(client, "... %s %s", key, value);
		}

		ReplyToCommand(client, "");
	}

	ReplyToCommand(client, "=============================");
	return Plugin_Handled;
}



// ====================================================================================================
//					DETOURS
// ====================================================================================================
public MRESReturn GetMissionInfo(Handle hReturn, Handle hParams)
{
	// Load new map data
	if( g_bLoadNewMap ) ResetPlugin();

	// Pointer
	int pThis = DHookGetReturn(hReturn);
	g_PointerMission = pThis;
	if( pThis == 0 ) return MRES_Ignored; // Some maps the mission file does not load (most likely due to gamemode not being supported).

	// Set data
	char key[MAX_STRING_LENGTH];
	char value[MAX_STRING_LENGTH];
	char check[MAX_STRING_LENGTH];

	for( int i = 0; i < g_alMissionData.Length; i += 2 )
	{
		g_alMissionData.GetString(i, key, sizeof(key));
		g_alMissionData.GetString(i + 1, value, sizeof(value));

		SDKCall(SDK_KV_GetString, pThis, check, sizeof(check), key, "N/A");

		// Dynamic Melee Weapons:
		if( g_bLeft4Dead2 && strcmp(check, "N/A") && strcmp(key, "meleeweapons") == 0 )
		{
			Format(check, sizeof(check), ";%s;", check);
			ReplaceStringEx(check, sizeof(check), ";riot_shield;", ";");
			ReplaceStringEx(check, sizeof(check), ";baseball_bat;", ";");
			ReplaceStringEx(check, sizeof(check), ";cricket_bat;", ";");
			ReplaceStringEx(check, sizeof(check), ";crowbar;", ";");
			ReplaceStringEx(check, sizeof(check), ";electric_guitar;", ";");
			ReplaceStringEx(check, sizeof(check), ";fireaxe;", ";");
			ReplaceStringEx(check, sizeof(check), ";frying_pan;", ";");
			ReplaceStringEx(check, sizeof(check), ";golfclub;", ";");
			ReplaceStringEx(check, sizeof(check), ";katana;", ";");
			ReplaceStringEx(check, sizeof(check), ";knife;", ";");
			ReplaceStringEx(check, sizeof(check), ";machete;", ";");
			ReplaceStringEx(check, sizeof(check), ";tonfa;", ";");
			ReplaceStringEx(check, sizeof(check), ";pitchfork;", ";");
			ReplaceStringEx(check, sizeof(check), ";shovel;", ";");

			int pos = strlen(check);
			if( pos > 0 )
			{
				if( check[pos - 1] == ';' ) check[pos - 1] = 0;
				StrCat(value, sizeof(value), ";");
				StrCat(value, sizeof(value), check[1]);
				pos = strlen(value);
				if( pos > 0 )
				{
					if( value[pos - 1] == ';' ) value[pos - 1] = 0;
				}
			}
		}

		if( strcmp(check, value) )
		{
			#if DEBUG_VALUES || FORCE_VALUES
			if( strcmp(check, "N/A") == 0 )
			{
				#if FORCE_VALUES
					if( SDK_KV_FindKey != null )
					{
						SDKCall(SDK_KV_FindKey, g_PointerMission, key, true);
						#if DEBUG_VALUES
							PrintToServer("MissionInfo: Attempted to create \"%s\".", key);
						#endif
					}
				#endif

				#if DEBUG_VALUES
					PrintToServer("MissionInfo: \"%s\" not found.", key);
				#endif
			} else {
				#if DEBUG_VALUES
					PrintToServer("MissionInfo: Set \"%s\" to \"%s\". Was \"%s\".", key, value, check);
				#endif
			}
			#endif

			SDKCall(SDK_KV_SetString, pThis, key, value);
		}
	}

	// Forward
	Call_StartForward(g_hForwardOnGetMission);
	Call_PushCell(pThis);
	Call_Finish();

	return MRES_Ignored;
}

public MRESReturn MeleeWeaponAllowedToExist(Handle hReturn, Handle hParams)
{
	DHookSetReturn(hReturn, true);
	return MRES_Override;
}

public MRESReturn GetMeleeWeaponInfo(Handle hReturn, Handle hParams)
{
	WeaponInfoFunction(1, hParams);
	return MRES_Ignored;
}

public MRESReturn GetWeaponInfo(Handle hReturn, Handle hParams)
{
	WeaponInfoFunction(0, hParams);
	return MRES_Ignored;
}

void WeaponInfoFunction(int funk, Handle hParams)
{
	// Load new map data
	if( g_bLoadNewMap ) ResetPlugin();

	// Pointer
	int pThis = DHookGetParam(hParams, 1 + funk);

	// Weapon name
	char class[64];
	DHookGetParamString(hParams, 2 - funk, class, sizeof(class));

	// Set data
	ArrayList aHand;
	char key[MAX_STRING_LENGTH];
	char value[MAX_STRING_LENGTH];
	char check[MAX_STRING_LENGTH];

	// Loop editor_weapons classnames
	for( int x = 0; x < g_alWeaponsData.Length; x++ )
	{
		aHand = g_alWeaponsData.Get(x);
		aHand.GetString(0, key, sizeof(key));

		// Matches weapon from detour
		if( strcmp(class, key) == 0 )
		{
			// Loop editor_weapons properties
			for( int i = 1; i < aHand.Length; i += 2 )
			{
				aHand.GetString(i, key, sizeof(key));
				aHand.GetString(i + 1, value, sizeof(value));

				SDKCall(SDK_KV_GetString, pThis, check, sizeof(check), key, "N/A");

				if( strcmp(check, value) )
				{
					#if DEBUG_VALUES || FORCE_VALUES
					if( strcmp(check, "N/A") == 0 )
					{
						#if FORCE_VALUES
							if( SDK_KV_FindKey != null )
							{
								SDKCall(SDK_KV_FindKey, pThis, key, true);
								#if DEBUG_VALUES
									PrintToServer("WeaponInfo: Attempted to create \"%s\".", key);
								#endif
							}
						#endif

						#if DEBUG_VALUES
							PrintToServer("WeaponInfo: \"%s/%s\" not found.", class, key);
						#endif
					} else {
						#if DEBUG_VALUES
							PrintToServer("WeaponInfo: Set \"%s/%s\" to \"%s\". Was \"%s\".", class, key, value, check);
						#endif
					}
					#endif

					SDKCall(SDK_KV_SetString, pThis, key, value);
				}
			}
		}
	}

	// Forward
	Call_StartForward(g_hForwardOnGetWeapons);
	Call_PushCell(pThis);
	Call_PushString(class);
	Call_Finish();
}



// ====================================================================================================
//					LOAD CONFIG
// ====================================================================================================
bool g_bAllowSection;
int g_iSectionMission; // 0 = weapons cfg. 1 = mission cfg.
int g_iSectionLevel;
int g_iValueIndex;

void ResetPlugin()
{
	char sMap[PLATFORM_MAX_PATH];
	GetCurrentMap(sMap, sizeof(sMap));

	if( strcmp(sMap, g_sLastMap) == 0 )
		return;

	strcopy(g_sLastMap, sizeof(g_sLastMap), sMap);

	g_bLoadNewMap = false;

	// Clear strings
	if( g_alMissionData != null )
	{
		g_alMissionData.Clear();
		delete g_alMissionData;
	}

	// Delete handles
	if( g_alWeaponsData != null )
	{
		ArrayList aHand;
		int size = g_alWeaponsData.Length;
		for( int i = 0; i < size; i++ )
		{
			aHand = g_alWeaponsData.Get(i);
			delete aHand;
		}
		g_alWeaponsData.Clear();
		delete g_alWeaponsData;
	}

	// Load again
	LoadConfig();

	RequestFrame(OnStart);
}

void OnStart()
{
	// Reparse weapon and melee configs each map
	ServerCommand("weapon_reparse_server; %s", g_bLeft4Dead2 ? "melee_reload_info_server" : "");
}

void LoadConfig()
{
	g_alMissionData = new ArrayList(ByteCountToCells(MAX_STRING_LENGTH));
	g_alWeaponsData = new ArrayList();

	char sPath[PLATFORM_MAX_PATH];

	g_iSectionMission = 1;
	BuildPath(Path_SM, sPath, sizeof(sPath), CONFIG_MISSION);
	if( FileExists(sPath) )
		ParseConfigFile(sPath);

	g_iSectionMission = 0;
	BuildPath(Path_SM, sPath, sizeof(sPath), CONFIG_WEAPONS);
	if( FileExists(sPath) )
		ParseConfigFile(sPath);
}

bool ParseConfigFile(const char[] file)
{
	// Load parser and set hook functions
	SMCParser parser = new SMCParser();
	SMC_SetReaders(parser, Config_NewSection, Config_KeyValue, Config_EndSection);
	parser.OnEnd = Config_End;

	// Log errors detected in config
	char error[128];
	int line, col;
	SMCError result = parser.ParseFile(file, line, col);

	if( result != SMCError_Okay )
	{
		if( parser.GetErrorString(result, error, sizeof(error)) )
		{
			SetFailState("%s on line %d, col %d of %s [%d]", error, line, col, file, result);
		}
		else
		{
			SetFailState("Unable to load config. Bad format? Check for missing { } etc.");
		}
	}

	delete parser;
	return (result == SMCError_Okay);
}

public SMCResult Config_NewSection(Handle parser, const char[] section, bool quotes)
{
	g_iSectionLevel++;

	if( g_iSectionLevel == 2 )
	{
		g_bAllowSection = false;

		if( strcmp(section, "all") == 0 )
		{
			g_bAllowSection = true;
		} else {
			char sMap[PLATFORM_MAX_PATH];
			GetCurrentMap(sMap, sizeof(sMap));

			if( StrContains(section, ",") != -1 )
			{
				int index, last;
				int len = strlen(section) + 2;
				char[] newSection = new char [len];
				StrCat(newSection, len, section);
				StrCat(newSection, len, ",");

				while( (index = StrContains(newSection[last], ",")) != -1 )
				{
					newSection[last + index] = 0;
					if( StrContains(sMap, newSection[last], false) != -1 )
					{
						g_bAllowSection = true;
						break;
					}
					newSection[last + index] = ',';
					last += index + 1;
				}
			}
			else if( StrContains(sMap, section, false) != -1 )
			{
				g_bAllowSection = true;
			}
		}
	}

	if( g_bAllowSection && g_iSectionMission == 0 && g_iSectionLevel == 3 )
	{
		int lens = g_alWeaponsData.Length;

		bool pushData = true;
		ArrayList aHand;
		char value[64];

		g_iValueIndex = 1;

		// Loop through sections
		for( int x = 0; x < lens; x++ )
		{
			aHand = g_alWeaponsData.Get(x);
			aHand.GetString(0, value, sizeof(value));

			// Already exists
			if( strcmp(value, section) == 0 )
			{
				pushData = false;
				break;
			}

			g_iValueIndex++;
		}

		// Doesn't exist, push into weapons array
		if( pushData )
		{
			aHand = new ArrayList(ByteCountToCells(MAX_STRING_LENGTH));
			aHand.PushString(section);
			g_alWeaponsData.Push(aHand);
		}
	}

	return SMCParse_Continue;
}

public SMCResult Config_KeyValue(Handle parser, const char[] key, const char[] value, bool key_quotes, bool value_quotes)
{
	// 2 = Mission
	// 3 = Weapons
	if( g_bAllowSection )
	{
		if( (g_iSectionMission && g_iSectionLevel == 2) || g_iSectionLevel == 3 )
		{
			ArrayList aHand;

			// Mission Data
			if( g_iSectionMission )
			{
				aHand = g_alMissionData;

				// Remove duplicates (map specific overriding 'all' section)
				int index = aHand.FindString(key);
				if( index != -1 )
				{
					aHand.Erase(index);
					aHand.Erase(index);
				}

				aHand.PushString(key);
				aHand.PushString(value);

			// Weapon Data
			} else {
				aHand = g_alWeaponsData.Get(g_iValueIndex - 1);

				int index = aHand.FindString(key);
				if( index == -1 )
				{
					aHand.PushString(key);
					aHand.PushString(value);
				} else {
					aHand.SetString(index + 1, value);
				}
			}
		}
	}
	return SMCParse_Continue;
}

public SMCResult Config_EndSection(Handle parser)
{
	g_iSectionLevel--;
	return SMCParse_Continue;
}

public void Config_End(Handle parser, bool halted, bool failed)
{
	if( failed )
		SetFailState("Error: Cannot load the Info Editor config.");
}