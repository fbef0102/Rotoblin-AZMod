#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sourcescramble>

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

public void OnPluginStart()
{
	GameDataWrapper gd = new GameDataWrapper("l4d_fix_long_stagger");
	gd.CreatePatchOrFail("CTerrorPlayer::UpdateStagger__AreHumanZombiesAllowed_ignore", true);
	gd.CreatePatchOrFail("CTerrorPlayer::UpdateStagger__IsA_Hunter_forced_pass", true);
	delete gd;
}