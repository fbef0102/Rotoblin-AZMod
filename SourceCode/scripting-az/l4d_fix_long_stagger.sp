#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sourcescramble>

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
	name = "[L4D] Queued Stagger",
	author = "Forgetest",
	description = "Fix tank and boomer stagger for 3.0s duration, longer than other special infected when getting stumble",
	version = "1.0-2024/8/3",
	url = "https://github.com/jensewe"
}

MemoryPatch 
	g_hPatch1, 
	g_hPatch2;

methodmap GameDataWrapper < GameData {
	public GameDataWrapper(const char[] file) {
		GameData gd = new GameData(file);
		if (!gd) SetFailState("Missing gamedata \"%s\"", file);
		return view_as<GameDataWrapper>(gd);
	}
	public MemoryPatch CreatePatchOrFail(const char[] name, bool enable = false) {
		MemoryPatch hPatch = MemoryPatch.CreateFromConf(this, name);
		if (!(enable ? hPatch.Enable() : hPatch.Validate()))
			SetFailState("Failed to patch \"%s\"", name);
		return hPatch;
	}
}

ConVar g_hCvarEnable;
bool g_bCvarEnable = true;

public void OnPluginStart()
{
	GameDataWrapper gd = new GameDataWrapper("l4d_fix_long_stagger");
	g_hPatch1 = gd.CreatePatchOrFail("CTerrorPlayer::UpdateStagger__AreHumanZombiesAllowed_ignore", true);
	g_hPatch2 = gd.CreatePatchOrFail("CTerrorPlayer::UpdateStagger__IsA_Hunter_forced_pass", true);
	delete gd;
}

public void OnAllPluginsLoaded()
{
	g_hCvarEnable = FindConVar("l4d_stagger_gravity_allow");
	if(g_hCvarEnable != null)
	{
		GetCvars();
		g_hCvarEnable.AddChangeHook(ConVarChanged_Cvars);
	}
}

void ConVarChanged_Cvars(ConVar hCvar, const char[] sOldVal, const char[] sNewVal)
{
	GetCvars();
}

void GetCvars()
{    
	g_bCvarEnable = g_hCvarEnable.BoolValue;
	if(g_bCvarEnable)
	{
		g_hPatch1.Enable();
		g_hPatch2.Enable();
	}
	else
	{
		g_hPatch1.Disable();
		g_hPatch2.Disable();
	}
}