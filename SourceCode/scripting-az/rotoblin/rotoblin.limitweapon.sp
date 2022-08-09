/*
 * ============================================================================
 *
 *  File:			limitweapon
 *  Type:			Module
 *  Description:	Adds a limit to hunting rifles for the survivors.
 *
 *  Copyright (C) 2010  Mr. Zero <mrzerodk@gmail.com
 *  Copyright (C) 2017-2022  Harry <fbef0102@gmail.com>
 *  This file is part of Rotoblin.
 *
 *  Rotoblin is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  Rotoblin is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with Rotoblin.  If not, see <http://www.gnu.org/licenses/>.
 *
 * ============================================================================
 */

/*
 * ==================================================
 *                     Variables
 * ==================================================
 */

/*
 * --------------------
 *       Private
 * --------------------
 */

static	const	String:	WEAPON_HUNTING_RIFLE[]			= "weapon_hunting_rifle";
static	const	String:	WEAPON_AUTOSHOTGUN[]			= "weapon_autoshotgun";
//static	const	String:	WEAPON_AUTOSHOTGUN_SPAWN[]		= "weapon_autoshotgun_spawn";
static	const	String:	WEAPON_RIFLE[]					= "weapon_rifle";
//static	const	String:	WEAPON_RIFLE_SPAWN[]			= "weapon_rifle_spawn";
static	const	String:	WEAPON_PUMPSHOTGUN[]			= "weapon_pumpshotgun";
//static	const	String:	WEAPON_PUMPSHOTGUN_SPAWN[]		= "weapon_pumpshotgun_spawn";
static	const	String:	WEAPON_SMG[]					= "weapon_smg";
//static	const	String:	WEAPON_SMG_SPAWN[]				= "weapon_smg_spawn";

static			Handle:	g_hLimitHuntingRifle_Cvar 		= INVALID_HANDLE;
static			Handle: g_hLimitAutoShotgun_Cvar	    = INVALID_HANDLE;
static			Handle: g_hLimitRifle_Cvar	    		= INVALID_HANDLE;
static			Handle: g_hLimitPumpShotgun_Cvar	    = INVALID_HANDLE;
static			Handle: g_hLimitSmg_Cvar	    		= INVALID_HANDLE;
static					g_iLimitHuntingRifle			= 1;
static					g_iLimitAutoShotgun				= 1;
static					g_iLimitRifle					= 1;
static					g_iLimitPumpShotgun				= 1;
static					g_iLimitSmg						= 1;

static	const	Float:	TIP_TIMEOUT						= 1.0;
static			bool:	g_bHaveTipped[MAXPLAYERS + 1] 	= {false};

/*
 * ==================================================
 *                     Forwards
 * ==================================================
 */

/**
 * Called on plugin start.
 *
 * @noreturn
 */
public _LimitHuntingRifl_OnPluginStart()
{
	g_hLimitHuntingRifle_Cvar = CreateConVarEx("limit_huntingrifle", "1", "Maximum of hunting rifles the survivors can pick up. [-1:No limit]", FCVAR_NOTIFY);
	g_hLimitAutoShotgun_Cvar = CreateConVarEx("limit_autoshotgun", "1", "Maximum of autoshotguns the survivors can pick up. [-1:No limit]", FCVAR_NOTIFY);
	g_hLimitRifle_Cvar = CreateConVarEx("limit_rifle", "1", "Maximum of rifles the survivors can pick up. [-1:No limit]", FCVAR_NOTIFY);
	g_hLimitPumpShotgun_Cvar = CreateConVarEx("limit_pumpshotgun", "4", "Maximum of pumpshotguns the survivors can pick up. [-1:No limit]", FCVAR_NOTIFY);
	g_hLimitSmg_Cvar  = CreateConVarEx("limit_smg", "3", "Maximum of smgs the survivors can pick up. [-1:No limit]", FCVAR_NOTIFY);
	AddConVarToReport(g_hLimitHuntingRifle_Cvar); // Add to report status module
	AddConVarToReport(g_hLimitAutoShotgun_Cvar); // Add to report status module
	AddConVarToReport(g_hLimitRifle_Cvar); // Add to report status module
	AddConVarToReport(g_hLimitPumpShotgun_Cvar); // Add to report status module
	AddConVarToReport(g_hLimitSmg_Cvar); // Add to report status module

	HookPublicEvent(EVENT_ONPLUGINENABLE, _LHR_OnPluginEnabled);
	HookPublicEvent(EVENT_ONPLUGINDISABLE, _LHR_OnPluginDisabled);
}

/**
 * Called on plugin enabled.
 *
 * @noreturn
 */
public _LHR_OnPluginEnabled()
{
	g_iLimitHuntingRifle = GetConVarInt(g_hLimitHuntingRifle_Cvar);
	g_iLimitAutoShotgun = GetConVarInt(g_hLimitAutoShotgun_Cvar);
	g_iLimitRifle = GetConVarInt(g_hLimitRifle_Cvar);
	g_iLimitPumpShotgun = GetConVarInt(g_hLimitPumpShotgun_Cvar);
	g_iLimitSmg = GetConVarInt(g_hLimitSmg_Cvar);
	HookConVarChange(g_hLimitHuntingRifle_Cvar, _LHR_Limit_CvarChange);
	HookConVarChange(g_hLimitAutoShotgun_Cvar, _LHR_AutoShotgun_CvarChange);
	HookConVarChange(g_hLimitRifle_Cvar, _LHR_Rifle_CvarChange);
	HookConVarChange(g_hLimitPumpShotgun_Cvar, _LHR_PumpShotgun_CvarChange);
	HookConVarChange(g_hLimitSmg_Cvar, _LHR_Smg_CvarChange);

	HookPublicEvent(EVENT_ONCLIENTPUTINSERVER, _LHR_OnClientPutInServer);
	HookPublicEvent(EVENT_ONCLIENTDISCONNECT_POST, _LHR_OnClientDisconnect);

	//HookEvent("spawner_give_item", _LHR_SpawnerGiveItem);
	//HookEvent("player_use", _LHR_PlayerUse);

	for (new client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client)) continue;
		SDKHook(client, SDKHook_WeaponCanUse, _LHR_OnWeaponCanUse);
	}
}

/**
 * Called on plugin disabled.
 *
 * @noreturn
 */
public _LHR_OnPluginDisabled()
{
	UnhookConVarChange(g_hLimitHuntingRifle_Cvar, _LHR_Limit_CvarChange);
	UnhookConVarChange(g_hLimitAutoShotgun_Cvar, _LHR_AutoShotgun_CvarChange);
	UnhookConVarChange(g_hLimitRifle_Cvar, _LHR_Rifle_CvarChange);
	
	UnhookPublicEvent(EVENT_ONCLIENTPUTINSERVER, _PS_OnClientPutInServer);
	UnhookPublicEvent(EVENT_ONCLIENTDISCONNECT_POST, _LHR_OnClientDisconnect);

	//UnhookEvent("spawner_give_item", _LHR_SpawnerGiveItem);
	//UnhookEvent("player_use", _LHR_PlayerUse);

	for (new client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client)) continue;
		SDKUnhook(client, SDKHook_WeaponCanUse, _LHR_OnWeaponCanUse);
	}
}

/**
 * Called on limit hunting rifle cvar changed.
 *
 * @param convar		Handle to the convar that was changed.
 * @param oldValue		String containing the value of the convar before it was changed.
 * @param newValue		String containing the new value of the convar.
 * @noreturn
 */
public _LHR_Limit_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	g_iLimitHuntingRifle = StringToInt(newValue);
}
public _LHR_AutoShotgun_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	g_iLimitAutoShotgun = StringToInt(newValue);
}
public _LHR_Rifle_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	g_iLimitRifle = StringToInt(newValue);
}
public _LHR_PumpShotgun_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	g_iLimitPumpShotgun = StringToInt(newValue);
}
public _LHR_Smg_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	g_iLimitSmg = StringToInt(newValue);
}
/**
 * Called on client put in server.
 *
 * @param client		Client index.
 * @noreturn
 */
public _LHR_OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_WeaponCanUse, _LHR_OnWeaponCanUse);
}

/**
 * Called on client disconnect.
 *
 * @param client		Client index.
 * @noreturn
 */
public _LHR_OnClientDisconnect(client)
{
	SDKUnhook(client, SDKHook_WeaponCanUse, _LHR_OnWeaponCanUse);
}

/**
 * Called on weapon can use.
 *
 * @param client		Client index.
 * @param weapon		Weapon entity index.
 * @return				Plugin_Continue to allow weapon usage, Plugin_Handled
 *						to disallow weapon usage.
 */
public Action:_LHR_OnWeaponCanUse(client, weapon)
{
	if (client == 0 || !IsClientInGame(client) || GetClientTeam(client) != TEAM_SURVIVOR) return Plugin_Continue;
	
	static char classname[128];
	GetEdictClassname(weapon, classname, sizeof(classname));
	//LogMessage("%N: %d %s", client, weapon, classname);
	if (!(StrEqual(classname, WEAPON_HUNTING_RIFLE)||
			StrEqual(classname, WEAPON_AUTOSHOTGUN)||
			StrEqual(classname, WEAPON_RIFLE) ||
			StrEqual(classname, WEAPON_PUMPSHOTGUN)||
			StrEqual(classname, WEAPON_SMG))) return Plugin_Continue;

	static char curclassname[128];
	new curWeapon = GetPlayerWeaponSlot(client, 0); // Get current primary weapon
	if (curWeapon > 0 && IsValidEntity(curWeapon))
	{
		GetEdictClassname(curWeapon, curclassname, sizeof(curclassname));
		if (StrEqual(curclassname, classname))
		{
			return Plugin_Continue; // Survivor already got Same Weapons and trying to pick up a ammo refill, allow it
		}
	}
	else
	{
		curclassname[0] = '\0';
	}

	if(StrEqual(classname, WEAPON_HUNTING_RIFLE)){
		if (GetActiveWeapons(WEAPON_HUNTING_RIFLE) >= g_iLimitHuntingRifle && g_iLimitHuntingRifle >=0) // If ammount of active hunting rifles are at the limit
		{
			if (!g_bHaveTipped[client])
			{
				g_bHaveTipped[client] = true;
				if (g_iLimitHuntingRifle > 0)
				{
					CPrintToChat(client, "[{olive}TS{default}] %T","rotoblin20",client,"Hunting Rifle",g_iLimitHuntingRifle);
				}
				else
				{
					CPrintToChat(client, "[{olive}TS{default}] %T","rotoblin21",client,"Hunting Rifle");
				}
				CreateTimer(TIP_TIMEOUT, _LHR_Tip_Timer, client);
			}
			//_EF_DoAmmoPilesFix(client,false);
			return Plugin_Handled; // Dont allow survivor picking up the hunting rifle
		}
	}
	else if(StrEqual(classname, WEAPON_AUTOSHOTGUN)){
		if (GetActiveWeapons(WEAPON_AUTOSHOTGUN) >= g_iLimitAutoShotgun && g_iLimitAutoShotgun >=0)
		{
			if (!g_bHaveTipped[client])
			{
				g_bHaveTipped[client] = true;
				if (g_iLimitAutoShotgun > 0)
				{
					CPrintToChat(client, "[{olive}TS{default}] %T","rotoblin20",client,"Auto Shotgun",g_iLimitAutoShotgun);
					if(!StrEqual(curclassname,"weapon_pumpshotgun"))
					{
						if (g_iLimitPumpShotgun == -1 || g_iLimitPumpShotgun > GetActiveWeapons(WEAPON_PUMPSHOTGUN)) 
						{
							if(!IsFakeClient(client)) CheatCommandEx(client,"give", "pumpshotgun");
							RemoveEntity(weapon);
						}
					}
					else
					{
						_EF_DoAmmoPilesFix(client,false);
					}
				}
				else
				{
					CPrintToChat(client, "[{olive}TS{default}] %T","rotoblin21",client,"Auto Shotgun");
				}
				CreateTimer(TIP_TIMEOUT, _LHR_Tip_Timer, client);
			}
			//_EF_DoAmmoPilesFix(client,false);
			return Plugin_Handled; // Dont allow survivor picking up the hunting rifle
		}
	}
	else if(StrEqual(classname, WEAPON_RIFLE)){
		if (GetActiveWeapons(WEAPON_RIFLE) >= g_iLimitRifle && g_iLimitRifle >=0)
		{
			if (!g_bHaveTipped[client])
			{
				g_bHaveTipped[client] = true;
				if (g_iLimitRifle > 0)
				{
					CPrintToChat(client, "[{olive}TS{default}] %T","rotoblin20",client,"Rifle",g_iLimitRifle);
					if(!StrEqual(curclassname,"weapon_smg"))
					{
						if (g_iLimitSmg == -1 || g_iLimitSmg > GetActiveWeapons(WEAPON_SMG)) 
						{
							if(!IsFakeClient(client)) CheatCommandEx(client,"give", "smg");
							RemoveEntity(weapon);
						}
					}
					else
					{
						_EF_DoAmmoPilesFix(client,false);
					}
				}
				else
				{
					CPrintToChat(client, "[{olive}TS{default}] %T","rotoblin21",client,"Rifle");
				}
				CreateTimer(TIP_TIMEOUT, _LHR_Tip_Timer, client);
			}
			//_EF_DoAmmoPilesFix(client,false);
			return Plugin_Handled; // Dont allow survivor picking up the hunting rifle
		}
	}
	else if(StrEqual(classname, WEAPON_PUMPSHOTGUN)){
		if (GetActiveWeapons(WEAPON_PUMPSHOTGUN) >= g_iLimitPumpShotgun && g_iLimitPumpShotgun >=0) 
		{
			if (!g_bHaveTipped[client])
			{
				g_bHaveTipped[client] = true;
				if (g_iLimitPumpShotgun > 0)
				{
					CPrintToChat(client, "[{olive}TS{default}] %T","rotoblin20",client,"Pump Shotgun",g_iLimitPumpShotgun);
				}
				else
				{
					CPrintToChat(client, "[{olive}TS{default}] %T","rotoblin21",client,"Pump Shotgun");
				}
				CreateTimer(TIP_TIMEOUT, _LHR_Tip_Timer, client);
			}
			//_EF_DoAmmoPilesFix(client,false);
			return Plugin_Handled; // Dont allow survivor picking up the hunting rifle
		}
	}
	else if(StrEqual(classname, WEAPON_SMG)){
		if (GetActiveWeapons(WEAPON_SMG) >= g_iLimitSmg && g_iLimitSmg >=0) 
		{
			if (!g_bHaveTipped[client])
			{
				g_bHaveTipped[client] = true;
				if (g_iLimitSmg > 0)
				{
					CPrintToChat(client, "[{olive}TS{default}] %T","rotoblin20",client,"Smg",g_iLimitSmg);
				}
				else
				{
					CPrintToChat(client, "[{olive}TS{default}] %T","rotoblin21",client,"Smg");
				}
				CreateTimer(TIP_TIMEOUT, _LHR_Tip_Timer, client);
			}
			//_EF_DoAmmoPilesFix(client,false);
			return Plugin_Handled; // Dont allow survivor picking up the hunting rifle
		}
	}
	return Plugin_Continue;
}

public Action:_LHR_Tip_Timer(Handle:timer, any:client)
{
	g_bHaveTipped[client] = false;
	return Plugin_Stop;
}

/*
 * ==================================================
 *                    Private API
 * ==================================================
 */

static GetActiveWeapons(const String:WEAPON_NAME[])
{
	new weapon;
	decl String:classname[128];
	new count;
	for (new client = FIRST_CLIENT; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client) || GetClientTeam(client) != TEAM_SURVIVOR || !IsPlayerAlive(client)) continue;
		weapon = GetPlayerWeaponSlot(client, 0); // Get primary weapon
		if (weapon == -1 || !IsValidEntity(weapon)) continue;

		GetEdictClassname(weapon, classname, sizeof(classname));
		if (!(StrEqual(classname, WEAPON_NAME))) continue;
		count++;
	}
	return count;
}

// public void _LHR_SpawnerGiveItem(Event event, const char[] name, bool dontBroadcast)
// {
// 	int weapon = event.GetInt("spawner");

// 	if(weapon > MaxClients && IsValidEntity(weapon))
// 	{
// 		static char classname[128];
// 		GetEdictClassname(weapon, classname, sizeof(classname));
// 		//LogMessage("%d %s", weapon, classname);
// 		if(StrEqual(classname, WEAPON_RIFLE_SPAWN)){
// 			if (GetActiveWeapons(WEAPON_RIFLE) >= g_iLimitRifle && g_iLimitRifle >=0) // If ammount of active hunting rifles are at the limit
// 			{
// 				ReplaceEntity(weapon, WEAPON_SMG_SPAWN, "models/w_models/weapons/w_smg_uzi.mdl", 5);
// 			}
// 		}
// 		else if(StrEqual(classname, WEAPON_AUTOSHOTGUN_SPAWN)){
// 			if (GetActiveWeapons(WEAPON_AUTOSHOTGUN) >= g_iLimitAutoShotgun && g_iLimitAutoShotgun >=0) // If ammount of active hunting rifles are at the limit
// 			{
// 				ReplaceEntity(weapon, WEAPON_PUMPSHOTGUN_SPAWN, "models/w_models/weapons/w_shotgun.mdl", 5);
// 			}
// 		}
// 	}
// }

// public void _LHR_PlayerUse(Event event, const char[] name, bool dontBroadcast)
// {
// 	int weapon = GetEventInt(event, "targetid");
// 	if (!IsWeaponSpawnEx(weapon)) return;

// 	if(GetEntProp(weapon, Prop_Send, "m_weaponID") == WEAPID_RIFLE){
// 		//LogMessage("%d %d", GetEntProp(weapon, Prop_Send, "m_weaponID"), g_iLimitRifle);
// 		if (GetActiveWeapons(WEAPON_RIFLE) >= g_iLimitRifle && g_iLimitRifle >=0) // If ammount of active hunting rifles are at the limit
// 		{
// 			ReplaceEntity(weapon, WEAPON_SMG_SPAWN, "models/w_models/weapons/w_smg_uzi.mdl", 5);
// 		}
// 	}
// 	else if(GetEntProp(weapon, Prop_Send, "m_weaponID") == WEAPID_AUTOSHOTGUN){
// 		//LogMessage("%d %d", GetEntProp(weapon, Prop_Send, "m_weaponID"), g_iLimitAutoShotgun);
// 		if (GetActiveWeapons(WEAPON_AUTOSHOTGUN) >= g_iLimitAutoShotgun && g_iLimitAutoShotgun >=0) // If ammount of active hunting rifles are at the limit
// 		{
// 			ReplaceEntity(weapon, WEAPON_PUMPSHOTGUN_SPAWN, "models/w_models/weapons/w_shotgun.mdl", 5);
// 		}
// 	}
// }