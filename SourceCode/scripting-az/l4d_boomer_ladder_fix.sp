#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#include <sourcescramble>

public Plugin myinfo =
{
    name = "[L4D] Boomer Ladder Fix",
    author = "BHaType"
};

MemoryPatch gLadderPatch;

public void OnPluginStart()
{
	GameData data = new GameData("l4d_boomer_ladder_fix");
	
	gLadderPatch = MemoryPatch.CreateFromConf(data, "CTerrorGameMovement::CheckForLadders");
	
	delete data;
	
	Patch(true);
	
	RegAdminCmd("sm_boomer_ladder_fix_toggle", sm_boomer_ladder_fix_toggle, ADMFLAG_ROOT);
}

public Action sm_boomer_ladder_fix_toggle( int client, int args )
{
	Patch(3);
	return Plugin_Handled;
}

void Patch( int state )
{
	static bool set;
	
	if ( state == 3 )
	{
		state = !set;
	}
	
	if ( set && !state )
	{
		gLadderPatch.Disable();
		set = false;
	}
	else if ( !set && state )
	{
		gLadderPatch.Enable();
		set = true;
	}
}