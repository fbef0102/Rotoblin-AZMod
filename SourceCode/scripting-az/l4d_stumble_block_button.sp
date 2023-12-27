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

int L4D1_GetMainActivity(int client) {
	static int s_iOffs_m_eCurrentMainSequenceActivity = -1;
	if (s_iOffs_m_eCurrentMainSequenceActivity == -1)
		s_iOffs_m_eCurrentMainSequenceActivity = FindSendPropInfo("CTerrorPlayer", "m_iProgressBarDuration") + 476;
	
	return LoadFromAddress(GetEntityAddress(client) + view_as<Address>(s_iOffs_m_eCurrentMainSequenceActivity), NumberType_Int32);
}

public void OnPluginStart()
{
	
}

public Action OnPlayerRunCmd(int client, int &buttons)
{
	if (IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) >= 2 && my_IsPlayerStaggering(client)) {
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

stock bool my_IsPlayerStaggering(int client)
{
	static int Activity;
	Activity = L4D1_GetMainActivity(client);

	switch (Activity) 
	{
		case L4D1_ACT_TERROR_SHOVED_FORWARD, // 1145, 1146, 1147, 1148: stumble
			L4D1_ACT_TERROR_SHOVED_BACKWARD,
			L4D1_ACT_TERROR_SHOVED_LEFTWARD,
			L4D1_ACT_TERROR_SHOVED_RIGHTWARD: 
				return true;
	}

	if( L4D_IsPlayerStaggering(client) )
	{
		return true;
	}

	return false;
}