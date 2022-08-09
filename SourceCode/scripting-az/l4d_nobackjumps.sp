/*version 1.4.1: 
- update l4d_nobackjumps.txt
- add convar "stop_wallkicking_enable"
- Print chat
    "left4dead"
    {
        "Offsets"
        {
            "CLunge_ActivateAbility"
            {
                "linux"		"189"
                "windows"	"188"
            }
        }
    }
*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <dhooks>
#include <multicolors>

#define Z_HUNTER 3
#define TEAM_INFECTED 3

#define GAMEDATA "l4d_nobackjumps"

int
	iOffs_BlockBounce,
	LungeActivateAbilityOffset;

DynamicHook
	hCLunge_ActivateAbility;

ConVar 
	z_pounce_crouch_delay;

bool
    g_bWasLunging[MAXPLAYERS+1], 
    g_bNotice[MAXPLAYERS+1];

float 
	g_fFixedNextActivation[MAXPLAYERS+1];

public Plugin myinfo =
{
	name = "L4D2 No Backjump",
	author = "Visor, A1m`, Forgetest, HarryPotter",
	description = "Look at the title",
	version = "1.4.1",
	url = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

ConVar hCvarPluginState;
bool CvarPluginState;
public void OnPluginStart()
{
    LoadTranslations("Roto2-AZ_mod.phrases");

    InitGameData();

    iOffs_BlockBounce = FindSendPropInfo("CLunge", "m_isLunging") + 16;
    hCLunge_ActivateAbility = new DynamicHook(LungeActivateAbilityOffset, HookType_Entity, ReturnType_Void, ThisPointer_CBaseEntity);

    z_pounce_crouch_delay = FindConVar("z_pounce_crouch_delay");

    hCvarPluginState = CreateConVar("stop_wallkicking_enable", "1", "If set, stops hunters from wallkicking", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    CvarPluginState = hCvarPluginState.BoolValue;
    hCvarPluginState.AddChangeHook(OnConvarChange_PluginState);

    HookEvent("round_start", Event_RoundStart);
}

void InitGameData()
{
	Handle hGamedata = LoadGameConfigFile(GAMEDATA);

	if (!hGamedata) {
		SetFailState("Gamedata '%s.txt' missing or corrupt.", GAMEDATA);
	}
	
	LungeActivateAbilityOffset = GameConfGetOffset(hGamedata, "CBaseAbility::ActivateAbility");
	if (LungeActivateAbilityOffset == -1) {
		SetFailState("Failed to get offset 'CBaseAbility::ActivateAbility'.");
	}

	delete hGamedata;
}

public void OnConvarChange_PluginState(Handle convar, const char[] oldValue, const char[] newValue)
{
	CvarPluginState = hCvarPluginState.BoolValue;
}

public void Event_RoundStart(Event event, char[] name, bool dontBroadcast)
{
    for(int i = 0; i <= MaxClients; i++)
    {
        g_bNotice[i] = false;
    }
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (strcmp(classname, "ability_lunge") == 0) {
		SDKHook(entity, SDKHook_SpawnPost, SDK_OnSpawn_Post);
		hCLunge_ActivateAbility.HookEntity(Hook_Pre, entity, CLunge_ActivateAbility);
	}
}

void SDK_OnSpawn_Post(int entity)
{
	int owner = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");
	if (owner != -1) {
		g_bWasLunging[owner] = false;
		g_fFixedNextActivation[owner] = -1.0;
		SDKHook(owner, SDKHook_PostThinkPost, SDK_OnPostThink_Post);
	}
	
	SDKUnhook(entity, SDKHook_SpawnPost, SDK_OnSpawn_Post);
}

// take care ladder case
MRESReturn CLunge_ActivateAbility(int ability)
{
    if(!CvarPluginState) return MRES_Ignored;

    int owner = GetEntPropEnt(ability, Prop_Send, "m_owner");
    if (owner == -1)
        return MRES_Ignored;

    if (GetEntityMoveType(owner) != MOVETYPE_LADDER)
         return MRES_Ignored;

    // only allow if crouched and fully charged
    if (g_fFixedNextActivation[owner] != -1.0 && GetGameTime() >= g_fFixedNextActivation[owner])
        return MRES_Ignored;

    if(g_bNotice[owner] == false)
        CPrintToChat(owner, "{default}[{olive}TS{default}] %T", "No backjumps", owner);
        
    g_bNotice[owner] = true;

    return MRES_Supercede;
}

void SDK_OnPostThink_Post(int client)
{
    if(!CvarPluginState) return;

    if (!IsClientInGame(client))
        return;

    int ability = GetEntPropEnt(client, Prop_Send, "m_customAbility");
    if (ability == -1 || !IsHunter(client)) {
        SDKUnhook(client, SDKHook_PostThinkPost, SDK_OnPostThink_Post);
        return;
    }

    if (IsGhost(client)) {
        g_fFixedNextActivation[client] = -1.0;
        return;
    }

    if (GetEntProp(ability, Prop_Send, "m_isLunging")) {
        g_fFixedNextActivation[client] = -1.0;
        g_bWasLunging[client] = true;
        return;
    }

    // Ducking, set our own timer for next pounce
    if (GetClientButtons(client) & IN_DUCK) {
        if (g_fFixedNextActivation[client] == -1.0) {
            // assumes hunter was bouncing
            float fNow = GetGameTime();
            g_fFixedNextActivation[client] = fNow;
            
            // 1. not bouncing
            // 2. starts on ground, or pounce not landing ladder
            if( !g_bWasLunging[client]
				&& (fNow > GetEntPropFloat(ability, Prop_Send, "m_lungeAgainTimer", 1) || GetEntityMoveType(client) != MOVETYPE_LADDER) )
            {
                g_fFixedNextActivation[client] += z_pounce_crouch_delay.FloatValue;
            }
        }
    } else { // not ducking
        g_fFixedNextActivation[client] = -1.0;
    }

    g_bWasLunging[client] = false;

    // A flag to block hunter back jumping,
    // which is set whenever hunter has touched survivors
    if (GetEntData(ability, iOffs_BlockBounce, 1))
        return;

    SetEntData(ability, iOffs_BlockBounce, 1, 1);

    if(g_bNotice[client] == false)
        CPrintToChat(client, "{default}[{olive}TS{default}] %T", "No backjumps", client);

    g_bNotice[client] = true;
}

bool IsHunter(int client)
{
	return (IsPlayerAlive(client)
		&& GetClientTeam(client) == TEAM_INFECTED
		&& GetEntProp(client, Prop_Send, "m_zombieClass") == Z_HUNTER);
}

bool IsGhost(int client)
{
	return view_as<bool>(GetEntProp(client, Prop_Send, "m_isGhost", 1));
}