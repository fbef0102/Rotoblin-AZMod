#include <sourcemod>
#include <sdktools>

// Fixed issues:
// - Player that was touching an entity (namely a trigger) on team change would still be touching it

#define GAMEDATA_FILE "remove_touch_links"

Handle g_hPhysicsRemoveTouchedList;

public void Event_player_team(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client == 0 || !IsClientInGame(client)) {
        return;
    }
    
    if (!IsPlayerAlive(client)) {
        // Prevent crash on death of human controlled bot
        return;
    }

    SDKCall(g_hPhysicsRemoveTouchedList, client);
}

void LoadGameConfigOrFail()
{
    Handle gc = LoadGameConfigFile(GAMEDATA_FILE);
    if (gc == null) {
        SetFailState("Failed to load gamedata file \"" ... GAMEDATA_FILE ... "\"");
    }

    StartPrepSDKCall(SDKCall_Static);
    if (PrepSDKCall_SetFromConf(gc, SDKConf_Signature, "CBaseEntity::PhysicsRemoveTouchedList")) {
        PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
        g_hPhysicsRemoveTouchedList = EndPrepSDKCall();
    }

    delete gc;

    if (g_hPhysicsRemoveTouchedList == null) {
        SetFailState("Failed to prepare SDKCall for \"CBaseEntity::PhysicsRemoveTouchedList\" (gamedata file: \"" ... GAMEDATA_FILE ... ".txt\")");
    }
}

public void OnPluginStart()
{
    LoadGameConfigOrFail();

    HookEvent("player_team", Event_player_team, EventHookMode_Post);
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    switch (GetEngineVersion()) {
        case Engine_Left4Dead2, Engine_Left4Dead:
        {
            return APLRes_Success;
        }
    }

    strcopy(error, err_max, "Plugin only supports Left 4 Dead and Left 4 Dead 2.");

    return APLRes_SilentFailure;
}

public Plugin myinfo =
{
    name = "[L4D/2] Reset Touch Links",
    author = "shqke",
    description = "Removes touch links on team change",
    version = "1.3",
    url = "https://github.com/shqke/sp_public"
};