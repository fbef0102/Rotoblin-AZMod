//version 1.3: update l4d_nobackjumps.txt + add convar "stop_wallkicking_enable"
//	"left4dead"
//	{
//		"Offsets"
//		{
//			"CLunge_ActivateAbility"
//			{
//				"windows"	"188"
//				"linux"		"189"
//			}
//		}
//	}
#include <sourcemod>
#include <dhooks>
#include <multicolors>

new Handle:hCLunge_ActivateAbility;

new Float:fSuspectedBackjump[MAXPLAYERS + 1];

new Handle:hCvarPluginState;
new CvarPluginState;

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

public Plugin:myinfo =
{
    name        = "L4D No Backjump",
    author      = "Visor, l4d1 windows offest by Harry",
    description = "Prevents players from using the wallkicking trick",
    version     = "1.4",
    url         = "https://github.com/fbef0102/L4D1-Plugins"
}

public OnPluginStart()
{
    LoadTranslations("Roto2-AZ_mod.phrases");
    new Handle:gameConf = LoadGameConfigFile("l4d_nobackjumps"); 
    new LungeActivateAbilityOffset = GameConfGetOffset(gameConf, "CLunge_ActivateAbility");
    
    hCLunge_ActivateAbility = DHookCreate(LungeActivateAbilityOffset, HookType_Entity, ReturnType_Void, ThisPointer_CBaseEntity, CLunge_ActivateAbility);
    DHookAddEntityListener(ListenType_Created, OnEntityCreated);

    HookEvent("round_start", OnRoundStart, EventHookMode_PostNoCopy);
    HookEvent("player_jump", OnPlayerJump);
	
    hCvarPluginState = CreateConVar("stop_wallkicking_enable", "1", "If set, stops hunters from wallkicking", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    CvarPluginState = GetConVarBool(hCvarPluginState);
    HookConVarChange(hCvarPluginState, OnConvarChange_PluginState);
}

public OnEntityCreated(entity, const String:classname[])
{
    if (StrEqual(classname, "ability_lunge"))
        DHookEntity(hCLunge_ActivateAbility, false, entity); 
}

public OnRoundStart(Handle:event, const String:name[], bool:bDontBroadcast)
{
    for (new i = 1; i <= MaxClients; i++)
        fSuspectedBackjump[i] = 0.0;
}

public Action:OnPlayerJump(Handle:event, const String:name[], bool:dontBroadcast)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    
    if (IsHunter(client) && !IsGhost(client) && IsOutwardJump(client))
        fSuspectedBackjump[client] = GetGameTime();
}

public MRESReturn:CLunge_ActivateAbility(ability, Handle:hParams)
{
	if(!CvarPluginState) return MRES_Ignored;
	
	new client = GetEntPropEnt(ability, Prop_Send, "m_owner");
	if (fSuspectedBackjump[client] + 1.5 > GetGameTime())
	{
		CPrintToChat(client, "{default}[{olive}TS{default}] %T","No backjumps",client);
		return MRES_Supercede;
	}
    
	return MRES_Ignored;
}

bool:IsOutwardJump(client) {
    return GetEntProp(client, Prop_Send, "m_isAttemptingToPounce") == 0 && !(GetEntityFlags(client) & FL_ONGROUND);
}

bool:IsHunter(client)  {
    if (client < 1 || client > MaxClients) return false;
    if (!IsClientInGame(client) || !IsPlayerAlive(client)) return false;
    if (GetClientTeam(client) != 3 || GetEntProp(client, Prop_Send, "m_zombieClass") != 3) return false;

    return true;
}

bool:IsGhost(client) {
    return GetEntProp(client, Prop_Send, "m_isGhost") == 1;
}

public OnConvarChange_PluginState(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (!StrEqual(oldValue, newValue))
		CvarPluginState = GetConVarBool(hCvarPluginState);
}