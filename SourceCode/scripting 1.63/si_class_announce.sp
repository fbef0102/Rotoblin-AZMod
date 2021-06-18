#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <left4downtown>

#define IS_VALID_CLIENT(%1)     (%1 > 0 && %1 <= MaxClients)
#define IS_SURVIVOR(%1)         (GetClientTeam(%1) == 2)
#define IS_INFECTED(%1)         (GetClientTeam(%1) == 3)
#define IS_VALID_INGAME(%1)     (IS_VALID_CLIENT(%1) && IsClientInGame(%1))
#define IS_VALID_SURVIVOR(%1)   (IS_VALID_INGAME(%1) && IS_SURVIVOR(%1))
#define IS_VALID_INFECTED(%1)   (IS_VALID_INGAME(%1) && IS_INFECTED(%1))
#define IS_SURVIVOR_ALIVE(%1)   (IS_VALID_SURVIVOR(%1) && IsPlayerAlive(%1))
#define IS_INFECTED_ALIVE(%1)   (IS_VALID_INFECTED(%1) && IsPlayerAlive(%1))

#define ZC_SMOKER               1
#define ZC_BOOMER               2
#define ZC_HUNTER               3
#define ZC_WITCH                4
#define ZC_TANK                 5

#define MAXSPAWNS               5


new const String: g_csSIClassName[][] =
{
    "",
    "Smoker",
    "Boomer",
    "Hunter",
    "Witch",
    "Tank"
};

native Is_Ready_Plugin_On();
public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	CreateNative("AnnounceSIClasses", Native_AnnounceSIClasses);
	return APLRes_Success;
}

public Plugin:myinfo = 
{
    name = "Special Infected Class Announce",
    author = "Tabun",
    description = "Report what SI classes are up when the round starts.L4D1 port by Harry",
    version = "0.9.2",
    url = "none"
}

public OnPluginStart()
{
	LoadTranslations("Roto2-AZ_mod.phrases");
	HookEvent("player_left_start_area", LeftStartAreaEvent, EventHookMode_PostNoCopy);
}

public Native_AnnounceSIClasses(Handle:plugin, numParams)
{
    // announce SI classes up now
	AnnounceSIClasses();
}

public LeftStartAreaEvent(Handle:event, String:name[], bool:dontBroadcast)
{
	if(!Is_Ready_Plugin_On())
		AnnounceSIClasses();
}

stock AnnounceSIClasses()
{
    // get currently active SI classes
    new iSpawns;
    new iSpawnClass[MAXSPAWNS+1];
    
    for (new i = 1; i <= MaxClients && iSpawns < MAXSPAWNS; i++) {
        if (!IS_INFECTED_ALIVE(i)) { continue; }

        iSpawnClass[iSpawns] = GetEntProp(i, Prop_Send, "m_zombieClass");
        iSpawns++;
    }

    // print classes, according to amount of spawns found
    switch (iSpawns) {
	    case 5: {
			for (new i = 1; i <= MaxClients; i++) {
				if (!IS_VALID_SURVIVOR(i))  continue;
				
				PrintToChat(i, "\x01[\x05TS\x01] %T: \x04%s\x01, \x04%s\x01, \x04%s\x01, \x04%s\x01, \x04%s\x01.",
					"si_class_announce",i,                  
					g_csSIClassName[iSpawnClass[0]],
                    g_csSIClassName[iSpawnClass[1]],
                    g_csSIClassName[iSpawnClass[2]],
                    g_csSIClassName[iSpawnClass[3]],
					g_csSIClassName[iSpawnClass[4]]);
			}
        }
        case 4: {
			for (new i = 1; i <= MaxClients; i++) {
				if (!IS_VALID_SURVIVOR(i)) continue;
				
				PrintToChat(i, "\x01[\x05TS\x01] %T: \x04%s\x01, \x04%s\x01, \x04%s\x01, \x04%s\x01",
					"si_class_announce",i,                  
					g_csSIClassName[iSpawnClass[0]],
                    g_csSIClassName[iSpawnClass[1]],
                    g_csSIClassName[iSpawnClass[2]],
                    g_csSIClassName[iSpawnClass[3]]);
			}
        }
        case 3: {
			for (new i = 1; i <= MaxClients; i++) {
				if (!IS_VALID_SURVIVOR(i)) continue;
				
				PrintToChat(i, "\x01[\x05TS\x01] %T: \x04%s\x01, \x04%s\x01, \x04%s\x01",
					"si_class_announce",i,                  
					g_csSIClassName[iSpawnClass[0]],
                    g_csSIClassName[iSpawnClass[1]],
                    g_csSIClassName[iSpawnClass[2]]);
			}
        }
        case 2: {
			for (new i = 1; i <= MaxClients; i++) {
				if (!IS_VALID_SURVIVOR(i)) continue;

				PrintToChat(i, "\x01[\x05TS\x01] %T: \x04%s\x01, \x04%s\x01",
					"si_class_announce",i,                  
					g_csSIClassName[iSpawnClass[0]],
                    g_csSIClassName[iSpawnClass[1]]);
			}
		}   
    }
}