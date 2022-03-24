/*
*	No Reload Animation Fix - Picking Up Same Weapon
*	Copyright (C) 2021 Silvers
*
*	This program is free software: you can redistribute it and/or modify
*	it under the terms of the GNU General Public License as published by
*	the Free Software Foundation, either version 3 of the License, or
*	(at your option) any later version.
*
*	This program is distributed in the hope that it will be useful,
*	but WITHOUT ANY WARRANTY; without even the implied warranty of
*	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*	GNU General Public License for more details.
*
*	You should have received a copy of the GNU General Public License
*	along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/



#define PLUGIN_VERSION 		"1.4"

/*======================================================================================
	Plugin Info:

*	Name	:	[L4D2] No Reload Animation Fix
*	Author	:	SilverShot
*	Descrp	:	Prevent filling the clip and skipping the reload animation when taking the same weapon.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=333100
*	Plugins	:	https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:
1.4 (2022-2-28) by Harry
	- L4D1 only, record 5 weapons clip and ammo

1.3 (02-Nov-2021)
	- Fixed including the different weapon skins as the same weapon. Thanks to "tRololo312312" for reporting.

1.2 (06-Jul-2021)
	- Fixed throwing errors about invalid entity. Thanks to "HarryPotter" for reporting.

1.1 (27-Jun-2021)
	- Fixed throwing errors about invalid entity. Thanks to "HarryPotter" for reporting.

1.0 (19-Jun-2021)
	- Initial release.

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define CLASSNAME_LENGTH 	64

enum WeaponID
{
	ID_NONE,
	ID_SMG,
	ID_PUMPSHOTGUN,
	ID_RIFLE,
	ID_AUTOSHOTGUN,
	ID_HUNTING_RIFLE,
	ID_WEAPON_MAX
}

int g_iClipAmmo[MAXPLAYERS+1][view_as<int>(ID_WEAPON_MAX)];
char Weapon_Name[view_as<int>(ID_WEAPON_MAX)][CLASSNAME_LENGTH];
int g_iOffsetAmmo;
int g_iPrimaryAmmoType;
bool g_bLateLoad;

// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D1] No Reload Animation Fix",
	author = "SilverShot, l4d1 port by HarryPotter",
	description = "Prevent filling the clip and skipping the reload animation when taking the same weapon.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=333100"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if( test != Engine_Left4Dead )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1.");
		return APLRes_SilentFailure;
	}

	g_bLateLoad = late;

	return APLRes_Success;
}

public void OnPluginStart()
{
	// Lateload
	if( g_bLateLoad )
	{
		for( int i = 1; i <= MaxClients; i++ )
		{
			if( IsClientInGame(i) )
			{
				SDKHook(i, SDKHook_WeaponCanUsePost, WeaponCanUse);
			}
		}
	}

	// Offsets to setting reserve ammo
	g_iOffsetAmmo = FindSendPropInfo("CTerrorPlayer", "m_iAmmo");
	g_iPrimaryAmmoType = FindSendPropInfo("CBaseCombatWeapon", "m_iPrimaryAmmoType");

	CreateConVar("l4d2_reload_fix_version", PLUGIN_VERSION, "No Reload Animation Fix plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);

	SetWeapon();

	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("round_start", Event_RoundStart);
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_WeaponCanUsePost, WeaponCanUse);

	for(WeaponID i = ID_NONE; i < ID_WEAPON_MAX ; ++i)
	{
		g_iClipAmmo[client][i] = -1;
	}
}

// Fix picking up weapons filling the clip
public void WeaponCanUse(int client, int weapon)
{
	if( weapon == -1 ) return;

	// Validate team
	if( GetClientTeam(client) == 2 )
	{
		// Validate weapon
		int current = GetPlayerWeaponSlot(client, 0);
		if( current == -1 ) return;

		static char class1[32], class2[32];
		GetEdictClassname(current, class1, sizeof(class1));
		GetEdictClassname(weapon, class2, sizeof(class2));
		WeaponID current_weaponid = GetWeaponID(class1);
		WeaponID weapon_weaponid = GetWeaponID(class2);
		if( current_weaponid == ID_NONE || weapon_weaponid == ID_NONE ) return;

		// Store clip size
		g_iClipAmmo[client][current_weaponid] = GetEntProp(current, Prop_Send, "m_iClip1");

		// Modify on next frame so we get new weapons reserve ammo
		DataPack dPack = new DataPack();
		dPack.WriteCell(GetClientUserId(client));
		dPack.WriteCell(EntIndexToEntRef(weapon));
		dPack.WriteCell(weapon_weaponid);
		RequestFrame(OnFrame, dPack);
	}
}

public void OnFrame(DataPack dPack)
{
	dPack.Reset();

	int client = dPack.ReadCell();
	client = GetClientOfUserId(client);
	if( !client || !IsClientInGame(client))
	{
		delete dPack;
		return;
	}
	
	int weapon = dPack.ReadCell();
	weapon = EntRefToEntIndex(weapon);
	if( weapon == INVALID_ENT_REFERENCE )
	{
		delete dPack;
		return;
	}

	WeaponID weapon_weaponid = dPack.ReadCell();
	if( g_iClipAmmo[client][weapon_weaponid] == -1 )
	{
		delete dPack;
		return;
	}

	delete dPack;

	// Validate weapon
	if( weapon == GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon") )
	{
		int clip = GetEntProp(weapon, Prop_Send, "m_iClip1");

		// Restore clip size to previous
		SetEntProp(weapon, Prop_Send, "m_iClip1", g_iClipAmmo[client][weapon_weaponid]);

		// Add new ammo received to reserve ammo
		int ammo = GetOrSetPlayerAmmo(client, weapon);
		GetOrSetPlayerAmmo(client, weapon, ammo + clip - g_iClipAmmo[client][weapon_weaponid]);
	}
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{ 
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	for(WeaponID i = ID_NONE; i < ID_WEAPON_MAX ; ++i)
	{
		g_iClipAmmo[client][i] = -1;
	}
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{ 
	for(int client = 1; client <= MaxClients; client++)
	{
		for(WeaponID i = ID_NONE; i < ID_WEAPON_MAX ; ++i)
		{
			g_iClipAmmo[client][i] = -1;
		}
	}
}

// Reserve ammo
int GetOrSetPlayerAmmo(int client, int iWeapon, int iAmmo = -1)
{
	int offset = GetEntData(iWeapon, g_iPrimaryAmmoType) * 4; // Thanks to "Root" or whoever for this method of not hard-coding offsets: https://github.com/zadroot/AmmoManager/blob/master/scripting/ammo_manager.sp

	if( offset )
	{
		if( iAmmo != -1 ) SetEntData(client, g_iOffsetAmmo + offset, iAmmo);
		else return GetEntData(client, g_iOffsetAmmo + offset);
	}

	return 0;
}


WeaponID GetWeaponID(const char[] weapon_name)
{
	for(WeaponID i = ID_NONE; i < ID_WEAPON_MAX ; ++i)
	{
		if(StrEqual(weapon_name,Weapon_Name[i],false))
		{
			return i;
		}
	}
	return ID_NONE;
}

public void SetWeapon()
{
	Weapon_Name[ID_NONE] = "";
	Weapon_Name[ID_SMG] = "weapon_smg";
	Weapon_Name[ID_PUMPSHOTGUN] = "weapon_pumpshotgun";
	Weapon_Name[ID_RIFLE] = "weapon_rifle";
	Weapon_Name[ID_AUTOSHOTGUN] = "weapon_autoshotgun";
	Weapon_Name[ID_HUNTING_RIFLE] = "weapon_hunting_rifle";
}