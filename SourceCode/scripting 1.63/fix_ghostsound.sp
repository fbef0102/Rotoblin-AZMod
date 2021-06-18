//1.fix jumplanding_zombie ghost sound
//2.fix spawn sound from ghost to living 
//3.when an "alive" infected player "respawns" ghost far away from survivors, survivors could hear some infected sounds from "ghost" infected player 

#define PLUGIN_VERSION "1.5"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#undef REQUIRE_PLUGIN
#include <l4d_lib>


#define RESPAWN_SOUND2	"UI/Pickup_GuitarRiff10.wav"

#define RESPAWN_SOUND "player/jumplanding_zombie.wav"

#define POUNCE_TIMER            0.1
#define TEAM_INFECTED           3

public Plugin:myinfo =
{
	name = "Silent SI",
	author = "raziEiL [disawar1],modify by Harry",
	description = "Mute some SI sounds for Survivors.",
	version = PLUGIN_VERSION,
	url = "http://steamcommunity.com/id/raziEiL"
}

public OnPluginStart()
{
	AddNormalSoundHook(SI_sh_OnSoundEmitted);
}

public Action:SI_sh_OnSoundEmitted(clients[64], &numClients, String:sample[PLATFORM_MAX_PATH], &entity, &channel, &Float:volume, &level, &pitch, &flags)
{
	//if(IsClient(entity)&&IsPlayerAlive(entity))
	//	PrintToChatAll("Sound:%s, 1. numClients %d, entity %d",sample, numClients, entity);
		
	if (numClients > 1 && IsClient(entity) ){
		//PrintToChatAll("Sound:%s, 1. numClients %d, entity %d",sample, numClients, entity);
		if( (StrEqual(sample, RESPAWN_SOUND) && IsPlayerGhost(entity)) || (StrEqual(sample, RESPAWN_SOUND2) && IsPlayerAlive(entity)) )
		{
			numClients = 0;
			for (new i = 1; i <= MaxClients; i++)
				if (IsClientInGame(i) && GetClientTeam(i) == 3 && !IsFakeClient(i))
					clients[numClients++] = i;

			return Plugin_Changed;
		}
		
		//fix survivors can hear some infected sounds when an "alive" infected player "respawn" ghost far away from survivors
		if(GetClientTeam(entity) == 3 && IsPlayerGhost(entity))
		{
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}