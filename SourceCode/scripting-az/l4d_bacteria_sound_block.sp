#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <sourcescramble>
#define PLUGIN_VERSION "1.0"
#define DEBUG 0

#define GAMEDATA_FILE "l4d_bacteria_sound_block"
#define SMOKER_PATCH "Music::OnSmokerAlert__skip_patch"
#define HUNTER_PATCH "Music::OnHunterAlert__skip_patch"
#define BOOMER_PATCH "Music::OnBoomerAlert__skip_patch"

#define MAXENTITY 2048
#define SOUND_INTERVAL 0.25

public Plugin myinfo =
{
	name = "Block bacteria sounds in versus",
	author = "Harry Potter, Forgetest",
	description = "In l4d1 versus mode, survivors can hear the music of the infected even they are ghost. This plugin blocks bacteria sounds",
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

public void OnPluginStart()
{
	GameData hGameData = new GameData(GAMEDATA_FILE);
	if (hGameData == null)
		SetFailState("Missing gamedata file (" ... GAMEDATA_FILE ... ")");

	if (!MemoryPatch.CreateFromConf(hGameData, SMOKER_PATCH).Enable()) 
		SetFailState("Failed in patching checks for \"" ... SMOKER_PATCH ... "\"");

	if (!MemoryPatch.CreateFromConf(hGameData, HUNTER_PATCH).Enable())
		SetFailState("Failed in patching checks for \"" ... HUNTER_PATCH ... "\"");

	if (!MemoryPatch.CreateFromConf(hGameData, BOOMER_PATCH).Enable())
		SetFailState("Failed in patching checks for \"" ... BOOMER_PATCH ... "\"");

	delete hGameData;
}