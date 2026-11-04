#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define MAXENTITIES 2048
#define SOUND_INTERVAL 0.25
#define DEBUG 0

public Plugin myinfo =
{
	name = "Addon Map Common Sound Fix",
	author = "Harry Potter",
	description = "In some custom maps, fix the wrong .wav sound coming from common infected when been shot or burning (usually happen in custom maps)",
	version = "1.4-2026/11/4",
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

/*stock char sFix_BeenShot_Sound[][] =
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
};*/

/*stock char sFix_BurningLoop_Sound[][] =
{   
    "npc/headcrab/headcrab_burning_loop2.wav"
};*/

stock const char sFix_Ignite_Sound[][] =
{   
    "npc/infected/action/ignite/ignite01.wav",
    "npc/infected/action/ignite/ignite07.wav",
    "npc/infected/action/ignite/ignite08.wav",
    "npc/infected/action/ignite/ignite09.wav",
};

float g_fCommonShotTime[MAXENTITIES + 1];
bool g_bCommonBeenShot[MAXENTITIES + 1];
bool g_bCommonBeenBurn[MAXENTITIES + 1];

enum EEntity_Type
{
	EEntity_Unknown,

	EEntity_Infected,
	EEntity_Witch,
	EEntity_Flame,
}

EEntity_Type 
	g_iEntityType[MAXENTITIES+1];

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

#if DEBUG
Action SI_OnSoundEmitted(int clients[MAXPLAYERS], int &numClients, char sample[PLATFORM_MAX_PATH],int &entity, int &channel, float &volume, int &level, int &pitch, int &flags,char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
    if(entity > MaxClients)
    {
        static char sClassName[64];
        GetEntityClassname(entity, sClassName, sizeof sClassName);
        PrintToChatAll("Sound:%s - numClients %d, entity %d(%s), tick: %d", sample, numClients, entity, sClassName, GetGameTickCount());
    }

    return Plugin_Continue;
}

Action SoundHookA(char sample[PLATFORM_MAX_PATH], int &entity, float &volume, int &level, int &pitch, float pos[3], int &flags, float &delay)
{
	PrintToChatAll("\x05A_Sample: \x01%s", sample);
	PrintToChatAll("\x0A_Sent: \x01%d \x05vol: \x01%.2f \x05lvl: \x01%d \x05pch: \x01%d \x05flg: \x01%d", entity, volume, level, pitch, flags);

	return Plugin_Continue;
}
#endif

Action SI_OnSoundEmitted_Fix(int clients[MAXPLAYERS], int &numClients, char sample[PLATFORM_MAX_PATH],int &entity, int &channel, float &volume, int &level, int &pitch, int &flags,char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
    if (numClients >= 1 && entity> MaxClients && IsValidEntity(entity)){

        if(g_iEntityType[entity] == EEntity_Infected)
        {
            if(g_bCommonBeenShot[entity])
            {
                if( strncmp(sample, "npc/infected/gore/bullets/", 26, false) != 0
                    && strncmp(sample, "npc/infected/action/been_shot/", 30, false) != 0)
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
            else if(g_bCommonBeenBurn[entity])
            {
                if( strncmp(sample, "npc/infected/action/", 20, false) != 0 //including die sound
                    && strcmp(sample, "common/null.wav", false) != 0)
                {
                    //PrintToChatAll("zombie burning bug sound: %s", sample);

                    if(g_fCommonShotTime[entity] < GetEngineTime())
                    {
                        int random = GetRandomInt(0, sizeof(sFix_Ignite_Sound)-1);
                        EmitSoundToAll(sFix_Ignite_Sound[random], entity);
                        g_fCommonShotTime[entity] = GetEngineTime() + SOUND_INTERVAL;
                    }

                    return Plugin_Stop;
                }
            }
        }
        else if(g_iEntityType[entity] == EEntity_Flame)
        {
            int entity2 = GetEntPropEnt(entity, Prop_Data, "m_hEntAttached");
            if( entity2 <= 0)
                return Plugin_Continue;

            if(entity2 > MaxClients && IsValidEntity(entity2))
            {
                if(g_iEntityType[entity2] != EEntity_Infected && g_iEntityType[entity2] != EEntity_Witch) return Plugin_Continue;

                //PrintToChatAll("BURN, ci: %d, tick: %d", entity2, GetGameTickCount());
                g_bCommonBeenBurn[entity2] = true;

                if(strncmp(sample, "npc/headcrab/", 13, false) == 0) return Plugin_Continue;

                //PrintToChatAll("zombie burning bug sound: %s", sample);
                //int random = GetRandomInt(0, sizeof(sFix_BurningLoop_Sound)-1);
                //EmitSoundToAll(sFix_BurningLoop_Sound[random], entity);
                
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

    g_iEntityType[entity] = EEntity_Unknown;

    switch (classname[0])
    {
        case 'i':
        {
            if (strcmp(classname, "infected") == 0)
            {
                g_iEntityType[entity] = EEntity_Infected;
                g_fCommonShotTime[entity] = 0.0;
                g_bCommonBeenShot[entity] = false;
                g_bCommonBeenBurn[entity] = false;
                RequestFrame(OnNextFrame_Common, EntIndexToEntRef(entity));
            }
        }
		case 'w':
		{
			if (strcmp(classname, "witch") == 0)
			{
				g_iEntityType[entity] = EEntity_Witch;
			}
        }
		case 'e':
		{
			if (strcmp(classname, "entityflame") == 0)
			{
				g_iEntityType[entity] = EEntity_Flame;
			}
        }
    }
}

void OnNextFrame_Common(int entityRef)
{
	int common = EntRefToEntIndex(entityRef);

	if (common == INVALID_ENT_REFERENCE)
		return;

	SDKHook(common, SDKHook_OnTakeDamage, OnTakeDamage_Common);
	SDKHook(common, SDKHook_OnTakeDamagePost, OnTakeDamagePost_Common);
}

Action OnTakeDamage_Common(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
    if(damagetype & DMG_BULLET)
    {
        //PrintToChatAll("OnTakeDamage_Common - DMG_BULLET, ci: %d, tick: %d", victim, GetGameTickCount());
        g_bCommonBeenShot[victim] = true;
    }

    return Plugin_Continue;
}

void OnTakeDamagePost_Common(int victim, int attacker, int inflictor, float damage, int damagetype, int weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
    //PrintToChatAll("OnTakeDamagePost_Common - ci: %d, tick: %d", victim, GetGameTickCount());

    g_bCommonBeenShot[victim] = false;
}

bool IsValidEntityIndex(int entity)
{
    return (MaxClients+1 <= entity <= MAXENTITIES);
}
