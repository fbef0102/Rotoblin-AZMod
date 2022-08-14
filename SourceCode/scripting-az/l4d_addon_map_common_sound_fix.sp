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
	description = "In some custom maps, fix the wrong .wav sound coming from common infected when been shot",
	version = "1.0",
	url = "http://steamcommunity.com/profiles/76561198026784913"
}

stock const char sDAB_Bug_Bullets_Sound[][] =
{   
    "physics/wood/wood_crate_break1.wav",
    "physics/wood/wood_crate_break2.wav",
    "physics/wood/wood_crate_break3.wav",
    "physics/wood/wood_crate_break4.wav",
    "physics/wood/wood_crate_break5.wav"
};

stock const char sP84_Bug_Bullets_Sound[][] =
{   
    "physics/wood/wood_plank_scrape_rough_loop1.wav",
    "physics/wood/wood_plank_scrape_smooth_loop1.wav",
    "physics/wood/wood_solid_scrape_rough_loop1.wav",
    "physics/wood/wood_crate_scrape_rough_loop1.wav",
    "physics/wood/wood_box_scrape_rough_loop1.wav",
    "physics/wood/wood_box_scrape_smooth_loop1.wav",
    "physics/wood/wood_solid_impact_bullet1.wav",
    "physics/wood/wood_solid_impact_bullet2.wav",
    "physics/wood/wood_solid_impact_bullet3.wav",
    "physics/wood/wood_solid_impact_bullet4.wav",
    "physics/wood/wood_solid_impact_bullet5.wav"
};

stock const char sP84_Bug_BeenShot_Sound[][] =
{   
    "physics/wood/wood_crate_break1.wav",
    "physics/wood/wood_crate_break2.wav",
    "physics/wood/wood_crate_break3.wav",
    "physics/wood/wood_crate_break4.wav",
    "physics/wood/wood_crate_break5.wav"
};

stock const char s149_Bug_Bullets_Sound[][] =
{   
    "physics/wood/wood_solid_impact_hard1.wav",
    "physics/wood/wood_solid_impact_hard2.wav",
    "physics/wood/wood_solid_impact_hard3.wav"
};

stock const char sDBD_Bug_BeenShot_Sound[][] =
{   
    "ambient/weather/thunderstorm/thunder_1.wav",
    "ambient/weather/thunderstorm/thunder_2.wav",
    "ambient/weather/thunderstorm/thunder_3.wav"
};

static const char sFix_Bullets_Sound[][] =
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

static char sFix_BeenShot_Sound[][] =
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

        OnMapStart();
    }
}

bool g_bDeathAboardMap, g_bPrecinct84Map, g_b149Map, g_bDBDMap;
public void OnMapStart()
{
    g_bDeathAboardMap = false;
    g_bPrecinct84Map = false;
    g_b149Map = false;
    g_bDBDMap = false;

    char sMap[64];
    GetCurrentMap(sMap, sizeof(sMap));
    if(strcmp("l4d_deathaboard01_prison", sMap) == 0)
        g_bDeathAboardMap = true;
    else if(strcmp("l4d_deathaboard02_yard", sMap) == 0)
        g_bDeathAboardMap = true;
    else if(strcmp("l4d_deathaboard03_docks", sMap) == 0)
        g_bDeathAboardMap = true;
    else if(strcmp("l4d_deathaboard04_ship", sMap) == 0)
        g_bDeathAboardMap = true;
    else if(strcmp("l4d_deathaboard05_light", sMap) == 0)
        g_bDeathAboardMap = true;

    else if(strcmp("l4d_noprecinct01_crash", sMap) == 0)
        g_bPrecinct84Map = true;
    else if(strcmp("l4d_noprecinct02_train", sMap) == 0)
        g_bPrecinct84Map = true;
    else if(strcmp("l4d_noprecinct03_clubd", sMap) == 0)
        g_bPrecinct84Map = true;
    else if(strcmp("l4d_noprecinct04_precinct", sMap) == 0)
        g_bPrecinct84Map = true;

    else if(strcmp("l4d_149_1", sMap) == 0)
        g_b149Map = true;
    else if(strcmp("l4d_149_2", sMap) == 0)
        g_b149Map = true;    
    else if(strcmp("l4d_149_3", sMap) == 0)
        g_b149Map = true;
    else if(strcmp("l4d_149_4", sMap) == 0)
        g_b149Map = true;
    else if(strcmp("l4d_149_5", sMap) == 0)
        g_b149Map = true;

    else if(strcmp("l4d_dbd_citylights", sMap) == 0)
        g_bDBDMap = true;
    else if(strcmp("l4d_dbd_anna_is_gone", sMap) == 0)
        g_bDBDMap = true;
    else if(strcmp("l4d_dbd_the_mall", sMap) == 0)
        g_bDBDMap = true;
    else if(strcmp("l4d_dbd_clean_up", sMap) == 0)
        g_bDBDMap = true;
    else if(strcmp("l4d_dbd_new_dawn", sMap) == 0)
        g_bDBDMap = true;

    AddNormalSoundHook(SI_DAB_OnSoundEmitted);
    AddNormalSoundHook(SI_P84_OnSoundEmitted);
    AddNormalSoundHook(SI_149_OnSoundEmitted);
    AddNormalSoundHook(SI_DBD_OnSoundEmitted);

    if(g_bDeathAboardMap || g_bPrecinct84Map || g_b149Map || g_bDBDMap)
    {
        int Max = sizeof(sFix_Bullets_Sound);
        for (int i = 0; i < Max; i++)
        {
            PrecacheSound(sFix_Bullets_Sound[i]);
        }

        Max = sizeof(sFix_BeenShot_Sound);
        for (int i = 0; i < Max; i++)
        {
            PrecacheSound(sFix_BeenShot_Sound[i]);
        }
    }

    if(!g_bDeathAboardMap)  RemoveNormalSoundHook(SI_DAB_OnSoundEmitted);
    if(!g_bPrecinct84Map)   RemoveNormalSoundHook(SI_P84_OnSoundEmitted);
    if(!g_b149Map)          RemoveNormalSoundHook(SI_149_OnSoundEmitted);
    if(!g_bDBDMap)          RemoveNormalSoundHook(SI_DBD_OnSoundEmitted);
}

public Action SI_OnSoundEmitted(int clients[MAXPLAYERS], int &numClients, char sample[PLATFORM_MAX_PATH],int &entity, int &channel, float &volume, int &level, int &pitch, int &flags,char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
    if (numClients >= 1){

        if(IsCommonInfected(entity))
        {
            PrintToChatAll("Sound:%s - numClients %d, entity %d", sample, numClients, entity);
        }
    }

    return Plugin_Continue;
}

public Action SoundHookA(char sample[PLATFORM_MAX_PATH], int &entity, float &volume, int &level, int &pitch, float pos[3], int &flags, float &delay)
{
	PrintToChatAll("\x05A_Sample: \x01%s", sample);
	PrintToChatAll("\x0A_Sent: \x01%d \x05vol: \x01%.2f \x05lvl: \x01%d \x05pch: \x01%d \x05flg: \x01%d", entity, volume, level, pitch, flags);

	return Plugin_Continue;
}

public Action SI_DAB_OnSoundEmitted(int clients[MAXPLAYERS], int &numClients, char sample[PLATFORM_MAX_PATH],int &entity, int &channel, float &volume, int &level, int &pitch, int &flags,char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
    if (numClients >= 1){

        if(IsCommonInfected(entity))
        {
            int Max, random;
            if(strncmp(sample, "physics/wood/", 13) == 0)
            {
                //PrintToChatAll("zombie bug bullet sound");

                if(g_fCommonShotTime[entity] < GetEngineTime())
                {
                    Max = sizeof(sFix_Bullets_Sound);
                    random = GetRandomInt(0, Max-1);
                    EmitSoundToAll(sFix_Bullets_Sound[random], entity);
                    g_fCommonShotTime[entity] = GetEngineTime() + SOUND_INTERVAL;
                }
                
                return Plugin_Stop;
            }
        }
    }

    return Plugin_Continue;
}

public Action SI_P84_OnSoundEmitted(int clients[MAXPLAYERS], int &numClients, char sample[PLATFORM_MAX_PATH],int &entity, int &channel, float &volume, int &level, int &pitch, int &flags,char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
    if (numClients >= 1){

        if(IsCommonInfected(entity))
        {
            int Max, random;
            if(strncmp(sample, "physics/wood/", 13) == 0)
            {
                //PrintToChatAll("zombie bug bullet sound");

                if(g_fCommonShotTime[entity] < GetEngineTime())
                {
                    Max = sizeof(sFix_Bullets_Sound);
                    random = GetRandomInt(0, Max-1);
                    EmitSoundToAll(sFix_Bullets_Sound[random], entity);
                    g_fCommonShotTime[entity] = GetEngineTime() + SOUND_INTERVAL;
                }
                
                return Plugin_Stop;
            }

            if(strncmp(sample, "physics/wood/", 13) == 0)
            {
                //PrintToChatAll("zombie bug Been Shot sound");

                Max = sizeof(sFix_BeenShot_Sound);
                random = GetRandomInt(0, Max-1);
                EmitSoundToAll(sFix_BeenShot_Sound[random], entity);
                return Plugin_Stop;
            }
        }
    }

    return Plugin_Continue;
}

public Action SI_149_OnSoundEmitted(int clients[MAXPLAYERS], int &numClients, char sample[PLATFORM_MAX_PATH],int &entity, int &channel, float &volume, int &level, int &pitch, int &flags,char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
    if (numClients >= 1){

        if(IsCommonInfected(entity))
        {
            int Max, random;
            if(strncmp(sample, "physics/wood/", 13) == 0)
            {
                //PrintToChatAll("zombie bug bullet sound");

                if(g_fCommonShotTime[entity] < GetEngineTime())
                {
                    Max = sizeof(sFix_Bullets_Sound);
                    random = GetRandomInt(0, Max-1);
                    EmitSoundToAll(sFix_Bullets_Sound[random], entity);
                    g_fCommonShotTime[entity] = GetEngineTime() + SOUND_INTERVAL;
                }
                
                return Plugin_Stop;
            }
        }
    }

    return Plugin_Continue;
}

public Action SI_DBD_OnSoundEmitted(int clients[MAXPLAYERS], int &numClients, char sample[PLATFORM_MAX_PATH],int &entity, int &channel, float &volume, int &level, int &pitch, int &flags,char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
    if (numClients >= 1){

        if(IsCommonInfected(entity))
        {
            int Max, random;
            if(strncmp(sample, "ambient/weather/", 16) == 0)
            {
                //PrintToChatAll("zombie been shot sound");

                Max = sizeof(sFix_BeenShot_Sound);
                random = GetRandomInt(0, Max-1);
                EmitSoundToAll(sFix_BeenShot_Sound[random], entity);
                
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
	if(entity> MaxClients && IsValidEntity(entity))
	{
		static char classname[32];
		GetEdictClassname(entity, classname, sizeof(classname));
		return strcmp(classname, "infected") == 0;
	}
	return false;
}

bool IsValidEntityIndex(int entity)
{
    return (MaxClients+1 <= entity <= GetMaxEntities());
}
