#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <colors>

#define HUNTER_ZOMBIE_CLASS     3
#define BOOMER_ZOMBIE_CLASS     2
#define SMOKER_ZOMBIE_CLASS     1

new bool:bLateLoad;
new Handle:cvar_bashKillHunter;
new Handle:cvar_bashKillSmoker;
new Handle:cvar_bashKillBoomer;

public Plugin:myinfo =
{
    name        = "L4D Bash Kills",
    author      = "Jahze,Harry Potter",
    version     = "1.2",
    description = "Stop special infected getting bashed to death,L4D1 port by Harry"
}

public APLRes:AskPluginLoad2( Handle:plugin, bool:late, String:error[], errMax) {
    bLateLoad = late;
    return APLRes_Success;
}

public OnPluginStart() {
    LoadTranslations("Roto2-AZ_mod.phrases");
    cvar_bashKillHunter = CreateConVar("l4d_hunter_no_bash_kills", "1", "Prevent hunter from getting bashed to death", FCVAR_PLUGIN);
    cvar_bashKillSmoker = CreateConVar("l4d_smoker_no_bash_kills", "1", "Prevent smoker from getting bashed to death", FCVAR_PLUGIN);
    cvar_bashKillBoomer = CreateConVar("l4d_boomer_no_bash_kills", "0", "Prevent boomerfrom getting bashed to death", FCVAR_PLUGIN);
	
    if ( bLateLoad ) {
        for ( new i = 1; i < MaxClients+1; i++ ) {
            if ( IsClientInGame(i) ) {
                SDKHook(i, SDKHook_OnTakeDamage, Hurt);
            }
        }
    }
}

public OnClientPutInServer( client ) {
    SDKHook(client, SDKHook_OnTakeDamage, Hurt);
}


public Action:Hurt( victim, &attacker, &inflictor, &Float:damage, &damageType, &weapon, Float:damageForce[3], Float:damagePosition[3] ) {
	if (!IsSI(victim) ) {
		return Plugin_Continue;
    }
    //PrintToChatAll("damage is %d ,damageType is %d,weapon is %d",damage, damageType,weapon);
	new zombieclass = GetEntProp(victim, Prop_Send, "m_zombieClass");
	if ( damage == 250.0 && damageType && weapon == -1 && IsSurvivor(attacker) ){
		if(zombieclass == BOOMER_ZOMBIE_CLASS && !GetConVarBool(cvar_bashKillBoomer))
		{
			decl String:victimname[128];
			GetClientName(victim,victimname,128);
			decl String:attackername[128];
			GetClientName(attacker,attackername,128);
			CPrintToChatAll("[{olive}TS{default}] %t","shove boomer and boomer dead",attackername,victimname);
			return Plugin_Continue;
		}
		else if(zombieclass == SMOKER_ZOMBIE_CLASS && !GetConVarBool(cvar_bashKillSmoker))
		{
			return Plugin_Continue;
		}
		else if(zombieclass == HUNTER_ZOMBIE_CLASS && !GetConVarBool(cvar_bashKillHunter))
		{
			return Plugin_Continue;
		}	
		return Plugin_Handled;
		
    }
	return Plugin_Continue;
}


bool:IsSI( client ) {
    if ( !IsClientInGame(client) || GetClientTeam(client) != 3 || !IsPlayerAlive(client) ) {
        return false;
    }
    
    return true;
}

bool:IsSurvivor( client ) {
    if ( client <= 0
    || client > MaxClients
    || !IsClientConnected(client)
    || !IsClientInGame(client)
    || GetClientTeam(client) != 2
    || !IsPlayerAlive(client) ) {
        return false;
    }
    
    return true;
}