#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <l4d_lib>

#define TEAM_SURVIVOR 2
#define MAX_DIST_SQUARED 75076 // 274^2

public Plugin:myinfo =
{
	name = "[L4D] Easier Pill Passer",
	author = "CanadaRox, raziEiL [disawar1]",
	description = "Lets players pass pills and adrenaline with +reload when they are holding one of those items",
	version = "1.0",
	url = "https://bitbucket.org/disawar1/l4d-competitive-plugins/src" // original: http://github.com/CanadaRox/sourcemod-plugins/
};

public Action:OnPlayerRunCmd(client, &buttons)
{
	if (buttons & IN_RELOAD && !(buttons & IN_USE))
	{
		decl String:weapon_name[64];
		GetClientWeapon(client, weapon_name, sizeof(weapon_name));

		if (strcmp(weapon_name, "weapon_pain_pills") == 0)
		{
			new target = GetClientAimTarget(client);
			if (target != -1 && GetClientTeam(target) == TEAM_SURVIVOR && GetPlayerWeaponSlot(target, 4) == -1 && !IsIncapacitated(target))
			{
				decl Float:clientOrigin[3], Float:targetOrigin[3];
				GetClientAbsOrigin(client, clientOrigin);
				GetClientAbsOrigin(target, targetOrigin);
				if (GetVectorDistance(clientOrigin, targetOrigin, true) < MAX_DIST_SQUARED)
				{
					new Ent = GetPlayerWeaponSlot(client, 4);

					if (Ent != -1){

						RemovePlayerItem(client, Ent);
						AcceptEntityInput(Ent, "Kill");

						Ent = CreateEntityByName("weapon_pain_pills");
						DispatchSpawn(Ent);
						EquipPlayerWeapon(target, Ent);

						new Handle:hFakeEvent = CreateEvent("weapon_given");
						SetEventInt(hFakeEvent, "userid", GetClientUserId(target));
						SetEventInt(hFakeEvent, "giver", GetClientUserId(client));
						SetEventInt(hFakeEvent, "weapon", 12);
						SetEventInt(hFakeEvent, "weaponentid", Ent);
						FireEvent(hFakeEvent);
					}
				}
			}
		}
	}
}