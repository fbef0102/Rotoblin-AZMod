#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define MAXENTITY 2048
#define SOUND_INTERVAL 0.25
#define DEBUG 0

public Plugin myinfo =
{
	name = "Addon Map Common Sound Fix",
	author = "Harry Potter",
	description = "In some custom maps, fix the wrong .wav sound coming from common infected when been shot or burning (usually happen in custom maps)",
	version = "1.2",
	url = "http://steamcommunity.com/profiles/76561198026784913"
}

stock const char sFix_Bullets_Sound[][] =
{   
    "npc/infected/gore/bullets/bullet_gib_01.wav",
    "npc/infected/gore/bullets/bullet_gib_02.wav",
    "npc/infected/gore/bullets/bullet_gib_03.wav",
    "npc/infected/gore/bullets/bullet_gib_04.wav",
    "npc/infected/gore/bullets/bullet_gib_05.wav",
    "npc/infected/gore/bullets/bullet_gib_06.wav",
    "npc/infected/gore/bullets/bullet_gib_07.wav",
    "npc/infected/gore/bullets/bullet_gib_08.wav",
    "npc/infected/gore/bullets/bullet_gib_09.wav",
    "npc/infected/gore/bullets/bullet_gib_10.wav",
    "npc/infected/gore/bullets/bullet_gib_11.wav",
    "npc/infected/gore/bullets/bullet_gib_12.wav",
    "npc/infected/gore/bullets/bullet_gib_13.wav",
    "npc/infected/gore/bullets/bullet_gib_14.wav",
    "npc/infected/gore/bullets/bullet_gib_15.wav",
    "npc/infected/gore/bullets/bullet_gib_16.wav",
    "npc/infected/gore/bullets/bullet_gib_17.wav"
};

stock char sFix_BeenShot_Sound[][] =
{   
    "npc/infected/action/been_shot/been_shot_01.wav",
    "npc/infected/action/been_shot/been_shot_02.wav",
    "npc/infected/action/been_shot/been_shot_03.wav",
    "npc/infected/action/been_shot/been_shot_04.wav",
    "npc/infected/action/been_shot/been_shot_05.wav",
    "npc/infected/action/been_shot/been_shot_06.wav",
    "npc/infected/action/been_shot/been_shot_07.wav",
    "npc/infected/action/been_shot/been_shot_08.wav",
    "npc/infected/action/been_shot/been_shot_09.wav",
    "npc/infected/action/been_shot/been_shot_10.wav",
    "npc/infected/action/been_shot/been_shot_11.wav",
    "npc/infected/action/been_shot/been_shot_12.wav",
    "npc/infected/action/been_shot/been_shot_13.wav",
    "npc/infected/action/been_shot/been_shot_14.wav",
    "npc/infected/action/been_shot/been_shot_15.wav",
    "npc/infected/action/been_shot/been_shot_16.wav",
    "npc/infected/action/been_shot/been_shot_17.wav",
    "npc/infected/action/been_shot/been_shot_18.wav",
    "npc/infected/action/been_shot/been_shot_19.wav",
    "npc/infected/action/been_shot/been_shot_20.wav",
    "npc/infected/action/been_shot/been_shot_21.wav",
    "npc/infected/action/been_shot/been_shot_22.wav",
    "npc/infected/action/been_shot/been_shot_23.wav",
    "npc/infected/action/been_shot/been_shot_24.wav"
};

stock char sFix_Burning_Sound[][] =
{   
    "npc/headcrab/headcrab_burning_loop2.wav"
};

float g_fCommonShotTime[MAXENTITY + 1];

bool g_bLate;
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    EngineVersion test = GetEngineVersion();

    if( test != Engine_Left4Dead )
    {
        strcopy(error, err_max, "Plugin only supports Left 4 Dead 1.");
        return APLRes_SilentFailure;
    }

    g_bLate = late;
    return APLRes_Success;
}

public void OnPluginStart()
{
    #if DEBUG
        AddNormalSoundHook(SI_OnSoundEmitted);
        AddAmbientSoundHook(SoundHookA);
    #endif

    if(g_bLate)
    {
        char classname[21];
        int entity;

        classname = "infected";
        entity = INVALID_ENT_REFERENCE;
        while ((entity = FindEntityByClassname(entity, classname)) != INVALID_ENT_REFERENCE)
        {
            OnEntityCreated(entity, classname);
        }

        //OnMapStart();
    }

    AddNormalSoundHook(SI_OnSoundEmitted_Fix);
}

public Action SI_OnSoundEmitted(int clients[MAXPLAYERS], int &numClients, char sample[PLATFORM_MAX_PATH],int &entity, int &channel, float &volume, int &level, int &pitch, int &flags,char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
    PrintToChatAll("Sound:%s - numClients %d, entity %d", sample, numClients, entity);

    return Plugin_Continue;
}


public Action SoundHookA(char sample[PLATFORM_MAX_PATH], int &entity, float &volume, int &level, int &pitch, float pos[3], int &flags, float &delay)
{
	PrintToChatAll("\x05A_Sample: \x01%s", sample);
	PrintToChatAll("\x0A_Sent: \x01%d \x05vol: \x01%.2f \x05lvl: \x01%d \x05pch: \x01%d \x05flg: \x01%d", entity, volume, level, pitch, flags);

	return Plugin_Continue;
}

public Action SI_OnSoundEmitted_Fix(int clients[MAXPLAYERS], int &numClients, char sample[PLATFORM_MAX_PATH],int &entity, int &channel, float &volume, int &level, int &pitch, int &flags,char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
    if (numClients >= 1 && entity> MaxClients && IsValidEntity(entity)){

        if(IsCommonInfected(entity))
        {
            if(strncmp(sample, "ambient/weather/", 16, false) == 0 ||
               strncmp(sample, "physics/wood/", 13, false) == 0)
            {
                //PrintToChatAll("zombie been shot sound or zombie bullet bug sound: %s", sample);

                if(g_fCommonShotTime[entity] < GetEngineTime())
                {
                    int random = GetRandomInt(0, sizeof(sFix_Bullets_Sound)-1);
                    EmitSoundToAll(sFix_Bullets_Sound[random], entity);
                    g_fCommonShotTime[entity] = GetEngineTime() + SOUND_INTERVAL;
                }
                
                return Plugin_Stop;
            }
        }
        else if(IsFireFlame(entity))
        {
            int entity2 = GetEntPropEnt(entity, Prop_Data, "m_hEntAttached");
            if( entity2 <= 0)
                return Plugin_Continue;

            if(entity2 > MaxClients && IsValidEntity(entity2) && IsValidEdict(entity2))
            {
                if(!IsCommonInfected(entity2) && !IsWitch(entity2)) return Plugin_Continue;

                if(strncmp(sample, "npc/headcrab/", 13, false) == 0) return Plugin_Continue;

                //PrintToChatAll("zombie burning bug sound: %s", sample);

                //int random = GetRandomInt(0, sizeof(sFix_Burning_Sound)-1);
                //EmitSoundToAll(sFix_Burning_Sound[random], entity);
                
                return Plugin_Stop;
            }
            else if(entity2 <= MaxClients && IsClientInGame(entity2))
            {
                if(strncmp(sample, "npc/headcrab/", 13, false) == 0) return Plugin_Continue;

                return Plugin_Stop;
            }
        }
    }

    return Plugin_Continue;
}


public void OnEntityCreated(int entity, const char[] classname)
{
    if (!IsValidEntityIndex(entity))
        return;

    switch (classname[0])
    {
        case 'i':
        {
            if (strcmp(classname, "infected") == 0)
                g_fCommonShotTime[entity] = 0.0;
        }
    }
}

bool IsCommonInfected(int entity)
{
    static char classname[32];
    GetEdictClassname(entity, classname, sizeof(classname));
    return strcmp(classname, "infected") == 0;
}

bool IsWitch(int entity)
{
    static char classname[32];
    GetEdictClassname(entity, classname, sizeof(classname));
    return strcmp(classname, "witch") == 0;
}

bool IsFireFlame(int entity)
{
    static char classname[32];
    GetEdictClassname(entity, classname, sizeof(classname));
    return strcmp(classname, "entityflame") == 0;
}

bool IsValidEntityIndex(int entity)
{
    return (MaxClients+1 <= entity <= GetMaxEntities());
}
