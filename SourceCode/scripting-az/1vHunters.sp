/*
	SourcePawn is Copyright (C) 2006-2008 AlliedModders LLC.  All rights reserved.
	SourceMod is Copyright (C) 2006-2008 AlliedModders LLC.  All rights reserved.
	Pawn and SMALL are Copyright (C) 1997-2008 ITB CompuPhase.
	Source is Copyright (C) Valve Corporation.
	All trademarks are property of their respective owners.
	This program is free software: you can redistribute it and/or modify it
	under the terms of the GNU General Public License as published by the
	Free Software Foundation, either version 3 of the License, or (at your
	option) any later version.
	This program is distributed in the hope that it will be useful, but
	WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
	General Public License for more details.
	You should have received a copy of the GNU General Public License along
	with this program.  If not, see <http://www.gnu.org/licenses/>.
*/
#pragma semicolon 1
 
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <multicolors>

new Handle:hCvarDmgThreshold;
new Handle:hCvarAnnounce;
new Handle:hCvarHunterClawDamage;
new Handle:hCvarSkipGetUpAnimation;
new Handle:g_hGameMode;
new CvarDmgThreshold;
new CvarAnnounce;
new CvarHunterClawDamage;
new CvarSkipGetUpAnimation;
new String:CvarGameMode[20];
new     bool:           bLateLoad                                               = false;

public APLRes:AskPluginLoad2( Handle:plugin, bool:late, String:error[], errMax)
{
    bLateLoad = late;
    return APLRes_Success;
}

public Plugin:myinfo =
{
	name = "1vHunters",
	author = "Harry Potter",
	description = "Hunter pounce survivors and die ,set hunter scratch damage, no getup animation",
	version = "1.8",
	url = "https://github.com/Attano/Equilibrium"
};

public OnPluginStart()
{     
	g_hGameMode = FindConVar("mp_gamemode");
	GetConVarString(g_hGameMode,CvarGameMode,sizeof(CvarGameMode));

	hCvarDmgThreshold = CreateConVar("sm_1v1_dmgthreshold", "24", "Amount of damage done (at once) before SI suicides. -1:Disable", FCVAR_NOTIFY, true, -1.0);
	hCvarAnnounce = CreateConVar("sm_1v1_dmgannounce", "1", "Announce SI Health Left before SI suicides.", FCVAR_NOTIFY, true, 0.0);
	hCvarHunterClawDamage = CreateConVar("sm_hunter_claw_dmg", "-1", "Hunter claw Dmg. -1:Default value dmg", FCVAR_NOTIFY, true, -1.0);
	hCvarSkipGetUpAnimation = CreateConVar("sm_hunter_skip_getup", "1", "Skip Survivor Get Up Animation", FCVAR_NOTIFY, true, 0.0);
	
	
	CvarDmgThreshold = GetConVarInt(hCvarDmgThreshold);
	CvarAnnounce = GetConVarInt(hCvarAnnounce);
	CvarHunterClawDamage = GetConVarInt(hCvarHunterClawDamage);
	CvarSkipGetUpAnimation = GetConVarInt(hCvarSkipGetUpAnimation);
	
	HookConVarChange(hCvarDmgThreshold, ConVarChange_hCvarDmgThreshold);
	HookConVarChange(hCvarAnnounce, ConVarChange_hCvarAnnounce);
	HookConVarChange(hCvarHunterClawDamage, ConVarChange_hHunterClawDamage);
	HookConVarChange(hCvarSkipGetUpAnimation,ConVarChange_hCvarSkipGetUpAnimation);
	
    // hook when loading late
	if(bLateLoad){
		for (new i = 1; i < MaxClients + 1; i++) {
			if (IsClientAndInGame(i)) {
                SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
            }
        }
    }
}

stock GetZombieClass(client) return GetEntProp(client, Prop_Send, "m_zombieClass");

stock bool:IsClientAndInGame(index)
{
	if (index > 0 && index <= MaxClients)
	{
		return IsClientInGame(index);
	}
	return false;
}

public ConVarChange_hCvarDmgThreshold(Handle:convar, const String:oldValue[], const String:newValue[])
{	
	if (!StrEqual(oldValue, newValue))
		CvarDmgThreshold = StringToInt(newValue);
}

public ConVarChange_hCvarAnnounce(Handle:convar, const String:oldValue[], const String:newValue[])
{	
	if (!StrEqual(oldValue, newValue))
		CvarAnnounce = StringToInt(newValue);
}
public ConVarChange_hHunterClawDamage(Handle:convar, const String:oldValue[], const String:newValue[])
{	
	if (!StrEqual(oldValue, newValue))
		CvarHunterClawDamage = StringToInt(newValue);
}
public ConVarChange_hCvarSkipGetUpAnimation(Handle:convar, const String:oldValue[], const String:newValue[])
{	
	if (!StrEqual(oldValue, newValue))
		CvarSkipGetUpAnimation = StringToInt(newValue);
}


public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
	if(!IsValidEdict(damagetype) || !IsClientAndInGame(victim) || !IsClientAndInGame(attacker) || damage == 0.0) { return Plugin_Continue; }
	
	decl String:sdamagetype[64];
	GetEdictClassname( damagetype, sdamagetype, sizeof( sdamagetype ) ) ;
	//PrintToChatAll("victim: %d,attacker:%d, damage is %f, sdamagetype is %s",victim,attacker,damage,sdamagetype);
	if (GetClientTeam(attacker) == 3 && GetClientTeam(victim) == 2 && GetZombieClass(attacker) == 3)
	{
		if(!StrEqual(sdamagetype, "player"))//高鋪傷害sdamagetype is player
		{
			new hasvictim = GetEntPropEnt(attacker, Prop_Send, "m_pounceVictim");
			if(hasvictim>0 && hasvictim == victim) //已經撲人
			{
				if(damage >= CvarDmgThreshold && CvarDmgThreshold >=0)
				{
					new remaining_health = GetClientHealth(attacker);
					if(CvarAnnounce == 1)
					{
						CPrintToChat(victim,"[{olive}TS 1vHunter{default}] {red}%N{default} had {green}%d{default} health remaining!", attacker, remaining_health);
						if(!IsFakeClient(attacker))
							CPrintToChat(attacker,"[{olive}TS 1vHunter{default}] You have {green}%d{default} health remaining!", remaining_health);
					}
				
					CreateTimer(0.01, ColdDown, attacker,_);
					if(CvarSkipGetUpAnimation == 1)
						CreateTimer(0.1, CancelGetup, victim,_);

					if (remaining_health == 1&&CvarAnnounce == 1)
					{
						CPrintToChat(victim, "[{olive}TS 1vHunter{default}] You don't have to be mad...");
					}	
				}
			}
			else if(CvarHunterClawDamage >= 0)
			{
				damage = float(CvarHunterClawDamage);
				return Plugin_Changed;
			}
		}
	}
	return Plugin_Continue;
}

public Action:ColdDown(Handle:timer, any:attacker) {

	ForcePlayerSuicide(attacker);  
}

public OnClientPutInServer(client)
{
    // hook bots spawning
    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action:CancelGetup(Handle:timer, any:client) {
    if (!IsClientConnected(client) || !IsClientInGame(client) || GetClientTeam(client) != 2) return Plugin_Stop;

    SetEntPropFloat(client, Prop_Send, "m_flCycle", 1000.0); // Jumps to frame 1000 in the animation, effectively skipping it.
    return Plugin_Continue;
}