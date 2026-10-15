#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sourcescramble>
#include <@Forgetest/gamedatawrapper>

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

public Plugin myinfo = 
{
	name = "[L4D1] Fix Tank Join Inf Team",
	author = "Forgetest",
	description = "Prevents Tank spawns from being blocked when the Special Infected team is full (z_max_player_zombies +1 slots)",
	version = "1.0-2026/10/15",
	url = "https://github.com/jensewe"
}

public void OnPluginStart()
{
	GameDataWrapper gd = new GameDataWrapper("l4d_fix_tank_jointeam");

	gd.CreatePatchOrFail("jointeam_force_SpawnTank_vector", true);

	if (gd.GetOffset("OS"))
	{
		gd.CreatePatchOrFail("jointeam_force_SpawnTank_navarea", true);
	}

	delete gd;
}