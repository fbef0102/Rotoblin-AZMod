/*
 * ============================================================================
 *
 * This file is part of the Rotoblin 2 project.
 *
 *  Copyright (C) 2012-2015 raziEiL <war4291@mail.ru>
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

#if defined _weapon_attributes_
  #endinput
#endif
#define _weapon_attributes_

#define		WA_TAG					"[WeaponAttributes]"

#define NULL						-1

#define WEAPID_PISTOL			1
#define WEAPID_SMG				2
#define WEAPID_PUMPSHOTGUN		3
#define WEAPID_AUTOSHOTGUN		4
#define WEAPID_RIFLE				5
#define WEAPID_HUNTINGRIFLE	6
#define WEAPID_FIRSTAIDKIT		8
#define WEAPID_MOLOTOV			9
#define WEAPID_PIPEBOMB			10
#define WEAPID_PAINPILLS		12
#define WEAPID_AMMO				29

#define WEAPID_LIMIT				13
/*
enum INFO
{
	String:sClass[64],
	String:sModel[64]
};

new const String:g_sWeapSpawns[WEAPID_LIMIT][INFO][] =
{
	// Empty
	{
		"",
		""
	},
	{
		"weapon_pistol_spawn",
		"models/w_models/Weapons/w_pistol_1911.mdl"
	},
	{
		"weapon_smg_spawn",
		"models/w_models/Weapons/w_smg_uzi.mdl"
	},
	{
		"weapon_pumpshotgun_spawn",
		"models/w_models/Weapons/w_shotgun.mdl"
	},
	{
		"weapon_autoshotgun_spawn",
		"models/w_models/Weapons/w_autoshot_m4super.mdl"
	},
	{
		"weapon_rifle_spawn",
		"models/w_models/Weapons/w_rifle_m16a2.mdl"
	},
	{
		"weapon_hunting_rifle_spawn",
		"models/w_models/Weapons/w_sniper_mini14.mdl"
	},
	{
		"",
		""
	},
	{
		"weapon_first_aid_kit_spawn",
		"models/w_models/weapons/w_eq_Medkit.mdl"
	},
	{
		"weapon_molotov_spawn",
		"models/w_models/weapons/w_eq_molotov.mdl"
	},
	{
		"weapon_pipe_bomb_spawn",
		"models/w_models/weapons/w_eq_pipebomb.mdl"
	},
	{
		"",
		""
	},
	{
		"weapon_pain_pills_spawn",
		"models/w_models/weapons/w_eq_painpills.mdl"
	}
};
*/

#define WEAPONS_LIMIT			5

enum ATTRIBUTES
{
	CLIP_SIZE,
	MAX_AMMO
};

new g_iWeapAttributes[WEAPONS_LIMIT][ATTRIBUTES] =
{
	// SMG				(Index = 0)
	{
		50,				// max clip size
		NULL,			// max ammo
	},
	// Pump shotgun
	{
		8,
		NULL,
	},
	// Auto shotgun
	{
		10,
		NULL,
	},
	// Rifle M16
	{
		50,
		NULL,
	},
	// Huntinh rifle
	{
		15,
		NULL,
	}
};

enum INFO
{
	CLASS, // classname
	NAME,	// printname
	CVAR	// convarname
};

#define WEAPINDEX_SMG		0
#define WEAPINDEX_PUMP		1
#define WEAPINDEX_AUTO		2
#define WEAPINDEX_RIFLE		3
#define WEAPINDEX_SNIPER	4

new const String:g_sWeapon_Names[WEAPONS_LIMIT][INFO][] =
{
	{ "weapon_smg", "SMG", "submachinegun" },
	{ "weapon_pumpshotgun", "Pump Shotgun", "pumpshotgun" },
	{ "weapon_autoshotgun", "Auto Shotgun", "autoshotgun" },
	{ "weapon_rifle", "Assault Rifle", "assaultrifle" },
	{ "weapon_hunting_rifle", "Hunting Rifle", "huntingrifle" }
};

new Handle:g_hWeaponCvar[WEAPONS_LIMIT];

static g_iWeapOffset[WEAPONS_LIMIT];

_Weapon_Attributes_OnPluginStart()
{
	g_hWeaponCvar[0] = FindConVar("ammo_smg_max");
	g_hWeaponCvar[1] = FindConVar("ammo_buckshot_max");
	g_hWeaponCvar[2] = g_hWeaponCvar[1];
	g_hWeaponCvar[3] = FindConVar("ammo_assaultrifle_max");
	g_hWeaponCvar[4] = FindConVar("ammo_huntingrifle_max");

	new iAmmoOffset = FindSendPropInfo("CTerrorPlayer", "m_iAmmo");
	g_iWeapOffset[0] = iAmmoOffset + (5 * 4);
	g_iWeapOffset[1] = iAmmoOffset + (6 * 4);
	g_iWeapOffset[2] = g_iWeapOffset[1];
	g_iWeapOffset[3] = iAmmoOffset + (3 * 4);
	g_iWeapOffset[4] = iAmmoOffset + (2 * 4);
}

_WA_OnConfigsExecuted()
{
	CreateTimer(0.5, WA_t_ReadCvars, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:WA_t_ReadCvars(Handle:timer)
{
	// fix me
	//for (new WEAPON_INDEX; WEAPON_INDEX < WEAPID_LIMIT; WEAPON_INDEX++)
	//	DebugLog("%d. %s %s", WEAPON_INDEX, g_sWeapSpawns[WEAPON_INDEX][sClass], g_sWeapSpawns[WEAPON_INDEX][sModel]);

	//DebugLog("%s Index	|	Clip/Ammo	| Name", WA_TAG);
	//DebugLog("%s ------------------------------------", WA_TAG);

	// Rebuild ammo attributes
	for (new WEAPON_INDEX = 0; WEAPON_INDEX < WEAPONS_LIMIT; WEAPON_INDEX++){

		g_iWeapAttributes[WEAPON_INDEX][MAX_AMMO] = GetConVarInt(g_hWeaponCvar[WEAPON_INDEX]);
		//DebugLog("%s %d.		|	%d/%d		| %s", WA_TAG, WEAPON_INDEX, g_iWeapAttributes[WEAPON_INDEX][CLIP_SIZE], g_iWeapAttributes[WEAPON_INDEX][MAX_AMMO], g_sWeapon_Names[WEAPON_INDEX][CLASS]);
	}
}

// @return Weapon index in g_iWeapAttributes array
GetWeaponIndexByClass(const String:sClassName[])
{
	for (new WEAPON_INDEX; WEAPON_INDEX < WEAPONS_LIMIT; WEAPON_INDEX++)
		if (StrEqual(g_sWeapon_Names[WEAPON_INDEX][CLASS], sClassName))
			return WEAPON_INDEX;

	return NULL;
}
/*
GetWeaponIndexByClassEx(entity)
{
	decl String:sClassName[64];
	GetEntityClassname(entity, sClassName, 64);
	return GetWeaponIndexByClass(sClassName);
}
*/
stock GetPrimaryWeaponAmmo(client, weapon_index)
{
	return GetEntData(client, g_iWeapOffset[weapon_index]);
}

stock SetPrimaryWeaponAmmo(client, weapon_index, ammo)
{
	SetEntData(client, g_iWeapOffset[weapon_index], ammo);
}

// weap spawn entity to check
stock bool:IsPrimaryWeapon(entity, &weapid)
{
	weapid = GetEntProp(entity, Prop_Send, "m_weaponID");

	return weapid > 1 && weapid < 7;
}
