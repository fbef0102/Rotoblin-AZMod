/**
 *
 * VAC Status Checker
 * https://forums.alliedmods.net/showthread.php?t=80942
 *
 * Licensed under the GNU General Public License v3.0
 * Source Repo: https://github.com/stevotvr/sourcemod-vacbans
 *
 */

#include <sourcemod>
#include <vacbans>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.0"

public Plugin myinfo =
{
	name = "VAC Status Checker Tester",
	author = "StevoTVR",
	description = "Tests forwards from the VAC Status Checker plugin",
	version = PLUGIN_VERSION,
	url = "https://github.com/stevotvr/sourcemod-vacbans"
}

public Action Vacbans_OnDetectedClient(int client, const char [] steamID, int numVACBans, int daysSinceLastVAC, int numGameBans, Vacbans_CommStatus commStatus, Vacbans_EconStatus econStatus)
{
	char commStatusText[16];
	switch (commStatus)
	{
		case COMMSTATUS_NONE:
			commStatusText = "Status_None";
		case COMMSTATUS_BANNED:
			commStatusText = "Status_Banned";
		default:
			commStatusText = "ERROR";
	}

	char econStatusText[24];
	switch (econStatus)
	{
		case ECONSTATUS_NONE:
			econStatusText = "Status_None";
		case ECONSTATUS_PROBATION:
			econStatusText = "Status_Probation";
		case ECONSTATUS_BANNED:
			econStatusText = "Status_Banned";
		default:
			econStatusText = "ERROR";
	}

	LogMessage("VACBANS TESTER: %N -- steamID:%s numVACBans:%d daysSinceLastVAC:%d numGameBans:%d commStatus:%s econStatus:%s", client, steamID, numVACBans, daysSinceLastVAC, numGameBans, commStatusText, econStatusText);
}
