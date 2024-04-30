/* Includes */
#pragma semicolon 1
#pragma newdecls required //強制1.7以後的新語法
#include <sourcemod>
#include <sdktools>
#include <sceneprocessor> // https://forums.alliedmods.net/showpost.php?p=2766130&postcount=59
#include <multicolors>

native bool IsInReady();

/* Plugin Information */
public Plugin myinfo = 
{
	name		= "Vocalize Anti-Flood",
	author		= "Buster \"Mr. Zero\" Nielsen & HarryPotter",
	description	= "Stops vocalize flooding when reaching token limit",
	version		= "1.0h-2024/4/28",
	url			= "https://forums.alliedmods.net/showthread.php?t=241588"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) 
{
	EngineVersion test = GetEngineVersion();
	
	if (test != Engine_Left4Dead2 && test != Engine_Left4Dead )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}
	
	return APLRes_Success;
}


ConVar hConVar1, hConVar2, hConVar3, hConVar4, hConVar5, 
	g_hCvarMapTalkDelete, g_hImmueAccess;
int g_iPlayerTokenTime, g_iWorldTokenTime, g_iPlayerTokenLimit, g_iWorldTokenLimit;
char g_sImmueAcclvl[16];
bool g_bCvarMapTalkDelete, g_bMessage;

float g_flLastVocalizeTimeStamp[MAXPLAYERS + 1];
float g_flLastWorldVocalizeTimeStamp[MAXPLAYERS + 1];
int g_VocalizeTokens[MAXPLAYERS + 1];
int g_WorldVocalizeTokens[MAXPLAYERS + 1];
int g_VocalizeFloodCheckTick[MAXPLAYERS + 1];
int iClientFlags[MAXPLAYERS+1];

/* Plugin Functions */
public void OnPluginStart()
{
	LoadTranslations("Roto2-AZ_mod.phrases");

	hConVar1 					= CreateConVar("l4d_vocalize_antiflood_player_token_time", 		"30", "Time interval to decrease a player token. (second)", FCVAR_NOTIFY, true, 1.0);
	hConVar2 					= CreateConVar("l4d_vocalize_antiflood_word_token_time", 		"5", "Time interval to decrease a word token. (second)", FCVAR_NOTIFY, true, 1.0);
	hConVar3 					= CreateConVar("l4d_vocalize_antiflood_player_token_limit", 	"3", "Max Player Token limit. (-1 = No Limit)", FCVAR_NOTIFY, true, -1.0);
	hConVar4 					= CreateConVar("l4d_vocalize_antiflood_world_token_limit",		"-1", "Max World Token limit. (-1 = No Limit)", FCVAR_NOTIFY, true, -1.0);
	hConVar5 					= CreateConVar("l4d_vocalize_antiflood_notify", 				"1", "If 1, notify antiflood message to player.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hCvarMapTalkDelete 		= CreateConVar("l4d_vocalize_antiflood_remove_maptalk", 		"0", "If 1, prevent all vocalizing talk triggered by the map (Remove all instanced_scripted_scene entities)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hImmueAccess			 	= CreateConVar("l4d_vocalize_antiflood_immue_flag", 			"-1", "Players with these flags have immune to token limit. (Empty=Everyone, -1=Nobody)", FCVAR_NOTIFY);
	
	GetCvars();
	hConVar1.AddChangeHook(ConVarChanged_Cvars);
	hConVar2.AddChangeHook(ConVarChanged_Cvars);
	hConVar3.AddChangeHook(ConVarChanged_Cvars);
	hConVar4.AddChangeHook(ConVarChanged_Cvars);
	hConVar5.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarMapTalkDelete.AddChangeHook(ConVarChanged_Cvars);
	g_hImmueAccess.AddChangeHook(ConVarChanged_Cvars);	
}

// Cvars-------------------------------

void ConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_iPlayerTokenTime = hConVar1.IntValue;
	g_iWorldTokenTime = hConVar2.IntValue;
	g_iPlayerTokenLimit = hConVar3.IntValue;
	g_iWorldTokenLimit = hConVar4.IntValue;
	g_bMessage = hConVar5.BoolValue;
	g_bCvarMapTalkDelete = g_hCvarMapTalkDelete.BoolValue;
	g_hImmueAccess.GetString(g_sImmueAcclvl,sizeof(g_sImmueAcclvl));
}

//Sourcemod API Forward-------------------------------

public void OnClientPostAdminCheck(int client)
{
	if(!IsFakeClient(client)) iClientFlags[client] = GetUserFlagBits(client);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (!g_bCvarMapTalkDelete || !IsValidEntityIndex(entity))
		return;

	switch (classname[0])
	{
		case 'i':
		{
			if (StrEqual(classname, "instanced_scripted_scene"))
			{
				RemoveEntity(entity);
			}
		}
	}
}

// sceneprocessor-------------------------------

public void OnSceneStageChanged(int scene, SceneStages stage)
{
	if (stage != SceneStage_SpawnedPost)
	{
		return;
	}
	
	int client = GetActorFromScene(scene);
	if (client <= 0 || client > MaxClients || !IsClientInGame(client))
	{
		return;
	}
	
	if (g_VocalizeFloodCheckTick[client] == GetGameTickCount())
	{
		return;
	}
	
	int initiator = GetSceneInitiator(scene);
	if (IsPlayerVocalizeFlooding(client, initiator) == false)
	{
		return;
	}
	
	CancelScene(scene);
}

public Action OnVocalizeCommand(int client, const char[] vocalize, int initiator)
{
	g_VocalizeFloodCheckTick[client] = GetGameTickCount();
	return (IsPlayerVocalizeFlooding(client, initiator) ? Plugin_Stop : Plugin_Continue);
}

// Function-------------------------------

bool IsPlayerVocalizeFlooding(int client, int initiator)
{
	bool fromWorld = initiator == SCENE_INITIATOR_WORLD;
	if (IsInReady() || initiator == SCENE_INITIATOR_PLUGIN || (initiator != client && fromWorld == false))
	{
		return false;
	}

	if (HasAccess(client, g_sImmueAcclvl)) return false;
	
	float curTime = GetEngineTime();
	int dif;
	
	if (fromWorld)
	{
		if (g_iWorldTokenLimit == -1) return false;

		dif = RoundFloat(curTime - g_flLastWorldVocalizeTimeStamp[client]) / g_iWorldTokenTime;
		g_WorldVocalizeTokens[client] -= dif;
		if (g_WorldVocalizeTokens[client] < 0) g_WorldVocalizeTokens[client] = 0;

		if(g_WorldVocalizeTokens[client] >= g_iWorldTokenLimit) return true;

		g_WorldVocalizeTokens[client]++;
		
		g_flLastWorldVocalizeTimeStamp[client] = curTime;
	}
	else
	{
		if (g_iPlayerTokenLimit == -1) return false;
		
		dif = RoundFloat(curTime - g_flLastVocalizeTimeStamp[client]) / g_iPlayerTokenTime;
		g_VocalizeTokens[client] -= dif;
		if (g_VocalizeTokens[client] < 0) g_VocalizeTokens[client]=0;

		if (g_VocalizeTokens[client] >= g_iPlayerTokenLimit) 
		{
			if(g_bMessage) CPrintToChat(client, "%T", "l4d_vocalize_antiflood", client);
			return true;
		}

		g_VocalizeTokens[client]++;
		
		g_flLastVocalizeTimeStamp[client] = curTime;
	}
	
	return false;
}

bool HasAccess(int client, char[] sAcclvl)
{
	// no permissions set
	if (strlen(sAcclvl) == 0)
		return true;

	else if (StrEqual(sAcclvl, "-1"))
		return false;

	// check permissions
	int userFlags = GetUserFlagBits(client);
	if ( userFlags & ReadFlagString(sAcclvl) || (userFlags & ADMFLAG_ROOT))
	{
		return true;
	}

	return false;
}

bool IsValidEntityIndex(int entity)
{
    return (MaxClients+1 <= entity <= GetMaxEntities());
}