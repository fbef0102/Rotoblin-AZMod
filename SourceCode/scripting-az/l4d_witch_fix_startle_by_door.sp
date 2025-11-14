#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
#include <actions>

#define PLUGIN_VERSION			"1.0-2025/11/14"
#define PLUGIN_NAME			    "l4d_witch_fix_startle_by_door"
#define DEBUG 0

public Plugin myinfo =
{
	name = "[L4D1] l4d_witch_fix_startle_by_door",
	author = "HarryPotter",
	description = "Fixed a door can startle the witch, causing her to lose target",
	version = PLUGIN_VERSION,
	url = "https://steamcommunity.com/profiles/76561198026784913/"
};

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

#define CVAR_FLAGS                    FCVAR_NOTIFY
#define CVAR_FLAGS_PLUGIN_VERSION     FCVAR_NOTIFY|FCVAR_DONTRECORD|FCVAR_SPONLY


ConVar g_hCvarEnable;
bool g_bCvarEnable;

public void OnPluginStart()
{
    g_hCvarEnable 		= CreateConVar( PLUGIN_NAME ... "_enable",        "1",   "0=Plugin off, 1=Plugin on.", CVAR_FLAGS, true, 0.0, true, 1.0);
    CreateConVar(                       PLUGIN_NAME ... "_version",       PLUGIN_VERSION, PLUGIN_NAME ... " Plugin Version", CVAR_FLAGS_PLUGIN_VERSION);

    GetCvars();
    g_hCvarEnable.AddChangeHook(ConVarChanged_Cvars);
}

// Cvars-------------------------------

void ConVarChanged_Cvars(ConVar hCvar, const char[] sOldVal, const char[] sNewVal)
{
	GetCvars();
}

void GetCvars()
{
    g_bCvarEnable = g_hCvarEnable.BoolValue;
}

// Actions

public void OnActionCreated(BehaviorAction action, int actor, const char[] name)
{
	if (g_bCvarEnable && name[0] == 'W' && (strcmp(name, "WitchIdle") == 0 || strcmp(name, "WitchAngry") == 0))
	{
		//action.OnContact = WitchAttack__OnContact;
		//action.OnInjured = WitchAttack__OnInjured;
		action.OnShoved = WitchAttack__OnShoved;
	}
}

/*Action WitchAttack__OnContact(any action, int actor, int entity, Address trace, ActionDesiredResult result)
{
	PrintToChatAll("WitchAttack__OnContact actor: %d, entity: %d", actor, entity);
	if (entity <= 0)
	{
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

Action WitchAttack__OnInjured(any action, int actor, any takedamageinfo, ActionDesiredResult result)
{
	PrintToChatAll("WitchAttack__OnInjured actor: %d, takedamageinfo: %d", actor, takedamageinfo);

	return Plugin_Continue;
}*/

Action WitchAttack__OnShoved(any action, int actor, int entity, ActionDesiredResult result)
{
    //PrintToChatAll("WitchAttack__OnShoved actor: %d, entity: %d", actor, entity);
    if(entity > 0 && entity <= MaxClients && IsClientInGame(entity) && GetClientTeam(entity) == 2)
    {
        return Plugin_Continue;
    }

    return Plugin_Handled;
}