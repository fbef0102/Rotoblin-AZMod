#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <sourcescramble>
#define PLUGIN_VERSION "1.0"
#define DEBUG 0

#define GAMEDATA_FILE "l4d_versus_sb_allow_leading_fix"
#define KEY_PATCH1 "SurvivorLegsMoveOn::Wait__AreHumanZombiesAllowed_skip"
#define KEY_PATCH2 "SurvivorLegsMoveOn::MoveTowardsNextCheckpoint__AreHumanZombiesAllowed_skip"
#define KEY_PATCH3 "SurvivorLegsMoveOn::MoveTowardsNextCheckpoint__AreHumanZombiesAllowed_skip2"

public Plugin myinfo =
{
	name = "Fuck you rushing bots in versus",
	author = "Harry Potter, Forgetest",
	description = "Fixed the problem that survivor bots always take the lead and won't wait behind the lead human player in versus mode",
	version = "1.0",
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

    return APLRes_Success;
}

ConVar sb_allow_leading;
bool bOfficialCvar_sb_allow_leading;

MemoryPatch g_hPatch1, g_hPatch2, g_hPatch3;
bool g_bLinuxOS;

public void OnPluginStart()
{
	sb_allow_leading = FindConVar("sb_allow_leading");
	bOfficialCvar_sb_allow_leading = sb_allow_leading.BoolValue;
	sb_allow_leading.AddChangeHook(ConVarChanged_Cvars);

	GameData hGameData = new GameData(GAMEDATA_FILE);
	if (hGameData == null)
		SetFailState("Missing gamedata file (" ... GAMEDATA_FILE ... ")");

	g_bLinuxOS = hGameData.GetOffset("OS") == 1;

	g_hPatch1 = MemoryPatch.CreateFromConf(hGameData, KEY_PATCH1);
	if(g_bLinuxOS)
	{
		g_hPatch2 = MemoryPatch.CreateFromConf(hGameData, KEY_PATCH2);
		g_hPatch3 = MemoryPatch.CreateFromConf(hGameData, KEY_PATCH3);
	}

	ChechPatch();

	delete hGameData;
}

public void ConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
	ChechPatch();
}

void GetCvars()
{
	bOfficialCvar_sb_allow_leading = sb_allow_leading.BoolValue;
}

void ChechPatch()
{
	if (bOfficialCvar_sb_allow_leading == false)
	{
		if (!g_hPatch1.Enable()) 
			SetFailState("Failed in patching checks for \"" ... KEY_PATCH1 ... "\"");

		if(g_bLinuxOS)
		{
			if (!g_hPatch2.Enable()) 
				SetFailState("Failed in patching checks for \"" ... KEY_PATCH2 ... "\"");

			if (!g_hPatch3.Enable()) 
				SetFailState("Failed in patching checks for \"" ... KEY_PATCH3 ... "\"");
		}
	}
	else
	{
		if (!g_hPatch1.Disable()) 
			SetFailState("Failed in patching checks for \"" ... KEY_PATCH1 ... "\"");

		if(g_bLinuxOS)
		{
			if (!g_hPatch2.Disable()) 
				SetFailState("Failed in patching checks for \"" ... KEY_PATCH2 ... "\"");

			if (!g_hPatch3.Disable()) 
				SetFailState("Failed in patching checks for \"" ... KEY_PATCH3 ... "\"");
		}
	}
}