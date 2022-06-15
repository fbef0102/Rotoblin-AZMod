#pragma newdecls required
#include <sourcemod>
#include <sdktools>

ConVar cvarSoundFlags;
int iSoundFlags;

int SOUNDFLAGS[2] = {
    1 << 0, // Heartbeat
    1 << 1, // Incapacitated screams (Commmon/FF/Bleeding out)
};

public Plugin myinfo = 
{
	name = "Sound Manipulation: REWORK",
	author = "Sir, HarryPotter",
	description = "Allows control over certain sounds",
	version = "1.1",
	url = "http://steamcommunity.com/profiles/76561198026784913"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	
	if( test != Engine_Left4Dead )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1.");
		return APLRes_SilentFailure;
	}

	return APLRes_Success;
}

public void OnPluginStart()
{
	cvarSoundFlags = CreateConVar("sound_flags", "3", "Prevent Sounds from playing - Bitmask: 0-Nothing | 1-Heartbeat | 2- Incapacitated Injury");
	iSoundFlags = cvarSoundFlags.IntValue;
	HookConVarChange(cvarSoundFlags, FlagsChanged);
	
	// Sound Hook
	AddNormalSoundHook(SoundHook);
}

public Action SoundHook(int clients[MAXPLAYERS], int &numClients, char sample[PLATFORM_MAX_PATH],int &entity, int &channel, float &volume, int &level, int &pitch, int &flags,char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
	if (!iSoundFlags) // Are we even blocking sounds?
	  return Plugin_Continue;

	if (StrEqual(sample, "player/heartbeatloop.wav", false) && iSoundFlags & SOUNDFLAGS[0]) // Are we blocking Heartbeat sounds?
	  return Plugin_Stop;

	if (StrContains(sample, "incapacitatedinjury", false) != -1 && iSoundFlags & SOUNDFLAGS[1]) // Are we blocking Incapacitated Injury noises?
	  return Plugin_Stop;

	// That'll be all.
	return Plugin_Continue;
}

public void FlagsChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    iSoundFlags = cvarSoundFlags.IntValue;
}