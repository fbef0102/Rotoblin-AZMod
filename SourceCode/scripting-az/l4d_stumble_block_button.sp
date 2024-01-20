#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>

public Plugin myinfo =
{
	name = "l4d_stumble_block_button",
	author = "CanadaRox, A1m (fix), HarryPotter",
	description = "Blocks all button presses during stumbles",
	version = "1.2 - 2023/12/27",
};

public void OnPluginStart()
{
	
}

public Action OnPlayerRunCmd(int client, int &buttons)
{
	if (IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) >= 2 && L4D_IsPlayerStaggering(client)) {
		/*
			* If you shove an SI that's on the ladder, the player won't be able to move at all until killed.
			* This is why we only apply this method when the SI is not on a ladder.
		*/

		if (GetEntityMoveType(client) != MOVETYPE_LADDER) {
			buttons = 0;
			return Plugin_Changed;
		}
	}
	return Plugin_Continue;
}