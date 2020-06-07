/*
 * ============================================================================
 *
 * This file is part of the Rotoblin 2 project.
 *
 *  File:			rotoblin.ExpolitFixes.sp
 *  Type:			Module
 *  Description:	Survivor/Infected expolit fixes.
 *
 *  Copyright (C) 2012-2015 raziEiL <war4291@mail.ru>
 *  Copyright (C) 2017-2020 Harry <fbef0102@gmail.com>
 *  This file is part of Rotoblin.
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * ============================================================================
 */

#define		EF_TAG					"[ExpolitFixes]"

// debug
#define		DEBUG_CHANNEL_NAME		"SurvivorExploitFixes"
static		g_iDebugChannel;

#define		EXPOLIT_TIMER			0.5

enum ()
{
	NoLadderBlock = 1,
	SurvivorDuckBlock,
	GhostDuckBlock,
	ESpawnBlock,
	AmmoPickup,
	IncapacitatedFF
}

static		Handle:g_hCvarExpolitFixes, g_iCvarExpolitFixes;

public EF_GetExpolitFixesCvar() return g_iCvarExpolitFixes;
public EF_GetNumOfESpawnBlock() return ESpawnBlock;

_ExpoliteFixed_OnPluginStart()
{
	g_hCvarExpolitFixes = CreateConVarEx("expolit_fixes_flag", "238", "Enables what kind of exploit should be fixed/blocked. Flag (add together): 0=Disable, 2=No ladder block, 4=Survivor duck block, 8=Ghost duck block, 16=E spawn expolit block, 32=Ammo pickup fix, 64=Incapacitated survivor ff block, 126=all", _, true, 0.0, true, 126.0);

	g_iDebugChannel = DebugAddChannel(DEBUG_CHANNEL_NAME);
}

_EF_OnPluginEnabled()
{
	HookConVarChange(g_hCvarExpolitFixes, _EF_OnCvarChange_ExpolitFixes);
	Update_EF_ExpolitFixesConVar();

	HookEvent("ammo_pickup", EF_ev_AmmoPickup);
	HookEvent("player_use", EF_ev_PlayerUse);

	if (g_bLoadLater)
		_EF_ToogleHook(true);

	CreateTimer(EXPOLIT_TIMER, _EF_t_CheckDuckingExpolit, _, TIMER_REPEAT);
}

_EF_OnPluginDisabled()
{
	UnhookConVarChange(g_hCvarExpolitFixes, _EF_OnCvarChange_ExpolitFixes);

	UnhookEvent("ammo_pickup", EF_ev_AmmoPickup);
	UnhookEvent("player_use", EF_ev_PlayerUse);

	_EF_ToogleHook(false);

	DebugLog("%s _EF_OnPluginDisabled", EF_TAG);
}

// Fixed up the game mechanics bug when the ammo piles use didn't provide a full ammo refill for weapons.
public EF_ev_AmmoPickup(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!(g_iCvarExpolitFixes & (1 << AmmoPickup))) return;

	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	_EF_DoAmmoPilesFix(client);
}

public EF_ev_PlayerUse(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!(g_iCvarExpolitFixes & (1 << AmmoPickup))) return;

	new target = GetEventInt(event, "targetid");
	if (!IsWeaponSpawnEx(target) || GetEntProp(target, Prop_Send, "m_weaponID") != WEAPID_AMMO) return;

	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	_EF_DoAmmoPilesFix(client, true);
}

static _EF_DoAmmoPilesFix(client, bool:bUse = false)
{
	decl iEnt;
	if ((iEnt = GetPlayerWeaponSlot(client, 0)) == INVALID_ENT_REFERENCE) return;

	decl String:sClassName[64], iWeapIndex;
	GetEntityClassname(iEnt, sClassName, 64);

	if ((iWeapIndex = GetWeaponIndexByClass(sClassName)) == NULL) return;

	new iClip = GetWeaponClipSize(iEnt);

	if (g_iWeapAttributes[iWeapIndex][CLIP_SIZE] != iClip){

		if (bUse && (g_iWeapAttributes[iWeapIndex][MAX_AMMO] + g_iWeapAttributes[iWeapIndex][CLIP_SIZE]) == (iClip + GetPrimaryWeaponAmmo(client, iWeapIndex)))
			return;

		SetConVarInt(g_hWeaponCvar[iWeapIndex], g_iWeapAttributes[iWeapIndex][MAX_AMMO] + (g_iWeapAttributes[iWeapIndex][CLIP_SIZE] - iClip));
		CheatCommandEx(client, "give", "ammo");
		SetConVarInt(g_hWeaponCvar[iWeapIndex], g_iWeapAttributes[iWeapIndex][MAX_AMMO]);
	}
}

static g_bTriggerCrouch[MAXPLAYERS+1];


_EF_OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_Touch, _EF_SDKh_Touch);
	SDKHook(client, SDKHook_OnTakeDamage, _IF_SDKh_OnTakeDamage);
}

_EF_ToogleHook(bool:bHook)
{
	for (new i = 1; i <= MaxClients; i++){

		if (IsClientInGame(i)){

			if (bHook){

				SDKHook(i, SDKHook_Touch, _EF_SDKh_Touch);
				SDKHook(i, SDKHook_OnTakeDamage, _IF_SDKh_OnTakeDamage);
			}
			else{

				SDKUnhook(i, SDKHook_Touch, _EF_SDKh_Touch);
				SDKUnhook(i, SDKHook_OnTakeDamage, _IF_SDKh_OnTakeDamage);
			}
		}
	}
}

public Action:_EF_SDKh_Touch(entity, other)
{
	if (other == 0) return;

	if (other <= MaxClients){

		if (g_iCvarExpolitFixes & (1 << NoLadderBlock) && !IsPlayerTank(other) && IsGuyTroll(entity, other)){

			if (IsOnLadder(other)){

				decl Float:vOrg[3];
				GetClientAbsOrigin(other, vOrg);
				vOrg[2] += 2.5;
				TeleportEntity(other, vOrg, NULL_VECTOR, NULL_VECTOR);
			}
			else
				TeleportEntity(other, NULL_VECTOR, NULL_VECTOR, Float:{0.0, 0.0, 251.0});

			DebugPrintToAllEx("Player %d: \"%N\" blocks the player %d \"%N\" on a ladder.", other, other, entity, entity);
		}
	}
	else {

		decl String:sClassName[64];
		GetEntityClassname(other, sClassName, 64);

		if (StrEqual(sClassName, "trigger_auto_crouch"))
			g_bTriggerCrouch[entity] = true;
		else
			g_bTriggerCrouch[entity] = false;
	}
}

public Action:_EF_t_CheckDuckingExpolit(Handle:timer)
{
	if (!IsServerProcessing() || g_bBlackSpot) return Plugin_Continue;

	if (!IsPluginEnabled()) return Plugin_Stop;

	decl client;

	if (g_iCvarExpolitFixes & (1 << SurvivorDuckBlock)){

		for (new i = 0; i < SurvivorCount; i++){

			client = SurvivorIndex[i];

			if (IsTrueClient(client) && !IsOnLadder(client) && !IsSurvivorBussy(client) && IsUseDuckingExpolit(client)){

				SetEntProp(client, Prop_Send, "m_bDucking", 1);
				DebugPrintToAllEx("Survivor %i: \"%N\" was ducking and were unducked.", client, client);
			}
		}
	}
	for (new i = 0; i < InfectedCount; i++){

		client = InfectedIndex[i];

		if (!IsInfectedBashed(client) && IsTrueClient(client) && IsInfectedAlive(client) && !IsOnLadder(client) && !IsInfectedBussy(client) && IsUseDuckingExpolit(client)){

			if (!(g_iCvarExpolitFixes & (1 << GhostDuckBlock)) && IsPlayerGhost(client)) continue;

			SetEntProp(client, Prop_Send, "m_bDucking", 1);
			DebugPrintToAllEx("Infected %i: \"%N\" was ducking and were unducked.", client, client);
		}
	}

	return Plugin_Continue;
}

bool:IsTrueClient(client)
{
	return !g_bTriggerCrouch[client] && client && IsClientInGame(client);
}

bool:IsUseDuckingExpolit(client)
{
	if (GetEntProp(client, Prop_Send, "m_nDuckTimeMsecs") == 1000)
		return false;

	static iButtons;
	iButtons = GetClientButtons(client);

	if (!(iButtons & IN_DUCK) && !(iButtons & IN_JUMP) && GetEntProp(client, Prop_Send, "m_bDucked") &&
		!GetEntProp(client, Prop_Send, "m_bDucking") && GetEntPropFloat(client, Prop_Send, "m_flFallVelocity") == 0)
		return true;

	return false;
}

bool:IsGuyTroll(victim, troll)
{
	return IsOnLadder(victim) && GetClientTeam(victim) != GetClientTeam(troll) && GetEntPropFloat(victim, Prop_Send, "m_vecOrigin[2]") < GetEntPropFloat(troll, Prop_Send, "m_vecOrigin[2]");
}

public Action:_IF_SDKh_OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3], damagecustom)
{
	if (g_iCvarExpolitFixes & (1 << IncapacitatedFF) && damagetype & DMG_BULLET && IsClientAndInGame(attacker) && IsIncapacitated(attacker) && GetClientTeam(attacker) == 2 &&
		IsClientAndInGame(victim) && GetClientTeam(victim) == 2) return Plugin_Handled;

	return Plugin_Continue;
}

public _EF_OnCvarChange_ExpolitFixes(Handle:convar_hndl, const String:oldValue[], const String:newValue[])
{
	if (StrEqual(oldValue, newValue)) return;

	Update_EF_ExpolitFixesConVar();
}

static Update_EF_ExpolitFixesConVar()
{
	g_iCvarExpolitFixes = GetConVarInt(g_hCvarExpolitFixes);
}

/**
 * Wrapper for printing a debug message without having to define channel index
 * everytime.
 *
 * @param format		Formatting rules.
 * @param ...			Variable number of format parameters.
 * @noreturn
 */
static DebugPrintToAllEx(const String:format[], any:...)
{
	decl String:buffer[DEBUG_MESSAGE_LENGTH];
	VFormat(buffer, sizeof(buffer), format, 2);
	DebugPrintToAll(g_iDebugChannel, buffer);
}