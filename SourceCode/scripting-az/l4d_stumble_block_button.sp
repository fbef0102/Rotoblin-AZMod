#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>

public Plugin myinfo =
{
	name = "l4d_stumble_block_button",
	author = "CanadaRox, A1m (fix), HarryPotter",
	description = "Blocks all button presses during stumbles",
	version = "1.2",
};

public void OnPluginStart()
{
	//nothing
}

public Action OnPlayerRunCmd(int client, int &buttons)
{
	if (IsClientInGame(client) && IsPlayerAlive(client) && L4D_IsPlayerStaggering(client)) {
		/*
			* if you shoved the infected player with the butt while moving on the ladder, 
			* he will not be able to move until he is killed
		*/
		if (GetEntityMoveType(client) != MOVETYPE_LADDER) {
			buttons = 0;
			return Plugin_Changed;
		}
	}
	return Plugin_Continue;
}