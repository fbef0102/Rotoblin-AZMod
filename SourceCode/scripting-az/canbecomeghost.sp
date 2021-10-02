#include <sourcemod>
#include <sourcescramble>

public Plugin myinfo = 
{
	name = "L4D saferoom unlimited ghost spawn",
	author = "Forgetest",
	description = "Infected can not use unlimited ghost spawn if last survivor still not leaves saferoom area in l4d1.",
	version = "1.0",
	url = ""
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	
	if( test != Engine_Left4Dead )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1, you dumb fuck as shit.");
		return APLRes_SilentFailure;
	}
	
	return APLRes_Success;
}

public void OnPluginStart()
{
	Handle conf = LoadGameConfigFile("canbecomeghost");
	if (conf == null)
		SetFailState("gamedata");
	
	MemoryPatch hPatch = MemoryPatch.CreateFromConf(conf, "CanBecomeGhost_LastSurvivorLeftStartArea");
	if (hPatch == null || !hPatch.Validate())
		SetFailState("patch");
	
	if (!hPatch.Enable())
		SetFailState("enable");
	
	delete conf;
}