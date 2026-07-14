#pragma semicolon 1
#pragma newdecls required //強制1.7以後的新語法
#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <dhooks>
#include <left4dhooks>
#define DEBUG 0

public Plugin myinfo = 
{
	name = "[L4D1] weapon csgo reload",
	author = "Harry Potter",
	description = "reload like csgo weapon",
	version = "2.4-2026/7/14",
	url = "https://forums.alliedmods.net/showthread.php?t=318820"
};

bool bLate;
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	
	if( test != Engine_Left4Dead )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1.");
		return APLRes_SilentFailure;
	}

	bLate = late;
	return APLRes_Success;
}

#define MAXENTITIES                   2048
#define GAMEDATA_FILE           	 "l4d_weapon_csgo_reload"
#define PISTOL_RELOAD_INCAP_MULTIPLY 1.3

enum WeaponID
{
	ID_NONE,
	ID_PISTOL,
	ID_DUAL_PISTOL,
	ID_SMG,
	//ID_PUMPSHOTGUN,
	ID_RIFLE,
	//ID_AUTOSHOTGUN,
	ID_HUNTING_RIFLE,
	ID_WEAPON_MAX
}

WeaponID
	g_iGlobalWeaponId[MAXENTITIES+1];

StringMap g_smWeaponNameID;
ConVar g_hAmmoHunting, g_hAmmoRifle, g_hAmmoSmg;
int g_iAmmoHunting, g_iAmmoRifle, g_iAmmoSmg;

int WeaponMaxClip[view_as<int>(ID_WEAPON_MAX)];

//cvars
ConVar hEnable, hSmgTimeCvar, hRifleTimeCvar, hHuntingRifleTimeCvar, hPistolTimeCvar, hDualPistolTimeCvar;

bool g_bEnable;
float g_SmgTimeCvar;
float g_RifleTimeCvar;
float g_HuntingRifleTimeCvar;
float g_PistolTimeCvar;
float g_DualPistolTimeCvar;

float 
	g_hClientReload_Time[MAXPLAYERS+1]	= {0.0};	

int
	g_iOffsetActive,
	g_iOffsetClip,
	g_iOffsetPrimaryAmmoType,
	g_iOffsetInReload,
	g_iOffsetAmmo,
	g_iOffset_PistolisDualWielding;	

public void OnPluginStart()
{
	GameData hGameData = new GameData(GAMEDATA_FILE);
	if( hGameData == null ) SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA_FILE);

	Handle hDetour = DHookCreateDetour(Address_Null, CallConv_THISCALL, ReturnType_Bool, ThisPointer_CBaseEntity);
	if( !hDetour )
		SetFailState("Failed to setup detour handle: CTerrorGun::Reload");

	if( !DHookSetFromConf(hDetour, hGameData, SDKConf_Signature, "CTerrorGun::Reload") )
		SetFailState("Failed to find signature: CTerrorGun::Reload");

	if( !DHookEnableDetour(hDetour, false, L4D1_OnGunReload_Pre) )
		SetFailState("Failed to detour: CTerrorGun::Reload");

	delete hDetour;
	delete hGameData;

	g_iOffsetActive 				= FindSendPropInfo("CBaseCombatCharacter","m_hActiveWeapon");
	g_iOffsetClip					= FindSendPropInfo("CBaseCombatWeapon", "m_iClip1");
	g_iOffsetPrimaryAmmoType 		= FindSendPropInfo("CBaseCombatWeapon", "m_iPrimaryAmmoType");
	g_iOffsetInReload 				= FindSendPropInfo("CBaseCombatWeapon", "m_bInReload");
	g_iOffsetAmmo 					= FindSendPropInfo("CCSPlayer", "m_iAmmo");
	g_iOffset_PistolisDualWielding 	= FindSendPropInfo("CPistol", "m_isDualWielding");

	g_hAmmoRifle =		FindConVar("ammo_assaultrifle_max");
	g_hAmmoSmg =		FindConVar("ammo_smg_max");
	g_hAmmoHunting =	FindConVar("ammo_huntingrifle_max");

	GetAmmoCvars();
	g_hAmmoRifle.AddChangeHook(ConVarChanged_AmmoCvars);
	g_hAmmoSmg.AddChangeHook(ConVarChanged_AmmoCvars);
	g_hAmmoHunting.AddChangeHook(ConVarChanged_AmmoCvars);

	hEnable					= CreateConVar("l4d_weapon_csgo_reload_allow", 			"1", 	"0=off plugin, 1=on plugin"				 , FCVAR_NOTIFY, true, 0.0, true, 1.0);
	hSmgTimeCvar			= CreateConVar("l4d_smg_reload_clip_time", 				"1.65", "reload time for smg clip"				 , FCVAR_NOTIFY, true, 0.0);
	hRifleTimeCvar			= CreateConVar("l4d_rifle_reload_clip_time", 			"1.2",  "reload time for rifle clip"			 , FCVAR_NOTIFY, true, 0.0);
	hHuntingRifleTimeCvar   = CreateConVar("l4d_huntingrifle_reload_clip_time", 	"2.6",  "reload time for hunting rifle clip"	 , FCVAR_NOTIFY, true, 0.0);
	hPistolTimeCvar 		= CreateConVar("l4d_pistol_reload_clip_time", 			"1.5",  "reload time for pistol clip"		     , FCVAR_NOTIFY, true, 0.0);
	hDualPistolTimeCvar 	= CreateConVar("l4d_dualpistol_reload_clip_time", 		"2.1",  "reload time for dual pistol clip"       , FCVAR_NOTIFY, true, 0.0);

	GetCvars();
	hEnable.AddChangeHook(ConVarChange_CvarChanged);
	hSmgTimeCvar.AddChangeHook(ConVarChange_CvarChanged);
	hRifleTimeCvar.AddChangeHook(ConVarChange_CvarChanged);
	hHuntingRifleTimeCvar.AddChangeHook(ConVarChange_CvarChanged);
	hPistolTimeCvar.AddChangeHook(ConVarChange_CvarChanged);
	hDualPistolTimeCvar.AddChangeHook(ConVarChange_CvarChanged);

	HookEvent("weapon_reload", OnWeaponReload_Event, EventHookMode_Post);
	HookEvent("round_start", RoundStart_Event);
	AddCommandListener(CmdListen_weapon_reparse_server, "weapon_reparse_server");
	
	SetWeaponNameId();

	//AutoExecConfig(true, "l4d_weapon_csgo_reload");

	if(bLate)
	{
		LateLoad();
	}
}

void LateLoad()
{
    int entity;
    char classname[36];

    entity = INVALID_ENT_REFERENCE;
    while ((entity = FindEntityByClassname(entity, "weapon_*")) != INVALID_ENT_REFERENCE)
    {
        if (!IsValidEntity(entity))
            continue;

        GetEntityClassname(entity, classname, sizeof(classname));
        OnEntityCreated(entity, classname);
    }
}

void RoundStart_Event(Event event, const char[] name, bool dontBroadcast) 
{
	for(int i = 1; i <= MaxClients; i++)
	{
		g_hClientReload_Time[i] = 0.0;
	}
}

void SetWeaponNameId()
{
	g_smWeaponNameID = new StringMap ();
	g_smWeaponNameID.SetValue("", ID_NONE);
	g_smWeaponNameID.SetValue("weapon_pistol", ID_PISTOL);
	g_smWeaponNameID.SetValue("weapon_smg", ID_SMG);
	//g_smWeaponNameID.SetValue("weapon_pumpshotgun", ID_PUMPSHOTGUN);
	g_smWeaponNameID.SetValue("weapon_rifle", ID_RIFLE);
	//g_smWeaponNameID.SetValue("weapon_autoshotgun", ID_AUTOSHOTGUN);
	g_smWeaponNameID.SetValue("weapon_hunting_rifle", ID_HUNTING_RIFLE);
}

void SetWeaponMaxClip()
{
	WeaponMaxClip[ID_NONE] = 0;
	WeaponMaxClip[ID_PISTOL] = L4D2_GetIntWeaponAttribute("weapon_pistol", L4D2IWA_ClipSize);
	WeaponMaxClip[ID_DUAL_PISTOL] = L4D2_GetIntWeaponAttribute("weapon_pistol", L4D2IWA_ClipSize)*2;
	WeaponMaxClip[ID_SMG] = L4D2_GetIntWeaponAttribute("weapon_smg", L4D2IWA_ClipSize);
	//WeaponMaxClip[ID_PUMPSHOTGUN] = L4D2_GetIntWeaponAttribute("weapon_pumpshotgun", L4D2IWA_ClipSize);
	WeaponMaxClip[ID_RIFLE] = L4D2_GetIntWeaponAttribute("weapon_rifle", L4D2IWA_ClipSize);
	//WeaponMaxClip[ID_AUTOSHOTGUN] = L4D2_GetIntWeaponAttribute("weapon_autoshotgun", L4D2IWA_ClipSize);
	WeaponMaxClip[ID_HUNTING_RIFLE] = L4D2_GetIntWeaponAttribute("weapon_hunting_rifle", L4D2IWA_ClipSize);
}

public void OnConfigsExecuted()
{
	GetAmmoCvars();
	GetCvars();
	SetWeaponMaxClip();
}

Action CmdListen_weapon_reparse_server(int client, const char[] command, int argc)
{
	RequestFrame(OnNextFrame_weapon_reparse_server);

	return Plugin_Continue;
}

void OnNextFrame_weapon_reparse_server()
{
	SetWeaponMaxClip();
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (!g_bEnable || !IsValidEntityIndex(entity))
		return;
		
	g_iGlobalWeaponId[entity] = ID_NONE;

	switch (classname[0])
	{
		case 'w':
		{
			WeaponID weaponid = GetWeaponID(entity, classname);
			if(weaponid == ID_NONE) return;
			
			g_iGlobalWeaponId[entity] = weaponid;
		}
	}
}

// Dhooks---

MRESReturn L4D1_OnGunReload_Pre(int pThis, Handle hReturn, Handle hParams)
{
	// Validate weapon
	if( pThis > MaxClients )
	{
		int client = GetEntPropEnt(pThis, Prop_Send, "m_hOwnerEntity");

		// Validate weapon owner
		if( client > 0 && client <= MaxClients && !IsFakeClient(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client) )
		{
			// Validate weapon in hand
			int weapon = GetEntDataEnt2(client, g_iOffsetActive);
			if( weapon > MaxClients && pThis == weapon )
			{
				WeaponID weaponid = g_iGlobalWeaponId[weapon];
				if(weaponid == ID_PISTOL)
				{
					if( GetEntData(weapon, g_iOffset_PistolisDualWielding, 1) > 0) //dual pistol
					{
						g_iGlobalWeaponId[weapon] = ID_DUAL_PISTOL;
						weaponid = ID_DUAL_PISTOL;
					}
				}

				int MaxClip = WeaponMaxClip[weaponid];
				int previousclip = GetWeaponClip(weapon);

				// 官方無限子彈時, 不會清除clip
				if(IsInifiniteAmmo(weaponid)) return MRES_Ignored;

				switch(weaponid)
				{
					case ID_SMG,ID_RIFLE,ID_HUNTING_RIFLE:
					{
						if (0 < previousclip && previousclip < MaxClip)	//If his current mag equals the maximum allowed, remove reload from buttons
						{
							//PrintToChatAll("L4D1_OnGunReload_Pre client: %N, weapon: %d, previousclip: %d", client, weapon, previousclip);
							DataPack data = new DataPack();
							data.WriteCell(GetClientUserId(client));
							data.WriteCell(EntIndexToEntRef(weapon));
							data.WriteCell(previousclip);
							data.WriteCell(weaponid);
							RequestFrame(OnNextFrame_RecoverWeaponClip, data);
						}
					}
					default:
					{
						return MRES_Ignored;
					}
				}
			}
		}
	}

	return MRES_Ignored;
}

void OnNextFrame_RecoverWeaponClip(DataPack data) 
{ 
	data.Reset();
	int client = GetClientOfUserId(data.ReadCell());
	int CurrentWeapon = EntRefToEntIndex(data.ReadCell());
	int previousclip = data.ReadCell();
	WeaponID weaponid = data.ReadCell();
	delete data;
	int nowweaponclip;
	
	if (!IsValidAliveSurvivor(client) || //client wrong
		CurrentWeapon == INVALID_ENT_REFERENCE || //weapon entity wrong
		CurrentWeapon != GetEntDataEnt2(client, g_iOffsetActive) ||
		(nowweaponclip = GetWeaponClip(CurrentWeapon)) >= WeaponMaxClip[weaponid] || //CurrentWeapon complete reload finished
		nowweaponclip == previousclip //CurrentWeapon clip has been recovered
	)
	{
		return;
	}

	int ammo = GetOrSetPlayerAmmo(client, CurrentWeapon);
	ammo -= previousclip;
	GetOrSetPlayerAmmo(client, CurrentWeapon, ammo);
	SetWeaponClip(CurrentWeapon, previousclip);
}

void OnWeaponReload_Event(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
		
	if (g_bEnable == false || !IsValidAliveSurvivor(client))
		return;

	int weapon = GetEntDataEnt2(client, g_iOffsetActive); //抓人類目前裝彈的武器
	if (weapon <= 0 || !IsValidEntity(weapon))
	{
		return;
	}
	
	g_hClientReload_Time[client] = GetEngineTime();
	
	WeaponID weaponid = g_iGlobalWeaponId[weapon];
	if(weaponid == ID_PISTOL)
	{
		if( GetEntData(weapon, g_iOffset_PistolisDualWielding, 1) > 0) //dual pistol
		{
			g_iGlobalWeaponId[weapon] = ID_DUAL_PISTOL;
			weaponid = ID_DUAL_PISTOL;
		}
	}
	
	DataPack pack;
	switch(weaponid)
	{
		case ID_SMG: CreateDataTimer(g_SmgTimeCvar, WeaponReloadClip, pack, TIMER_FLAG_NO_MAPCHANGE);
		case ID_RIFLE: CreateDataTimer(g_RifleTimeCvar, WeaponReloadClip, pack, TIMER_FLAG_NO_MAPCHANGE);
		case ID_HUNTING_RIFLE: CreateDataTimer(g_HuntingRifleTimeCvar, WeaponReloadClip, pack,TIMER_FLAG_NO_MAPCHANGE);
		case ID_PISTOL: 
		{
			if(IsIncapacitated(client))
				CreateDataTimer(g_PistolTimeCvar * PISTOL_RELOAD_INCAP_MULTIPLY, WeaponReloadClip, pack, TIMER_FLAG_NO_MAPCHANGE);
			else
				CreateDataTimer(g_PistolTimeCvar, WeaponReloadClip, pack, TIMER_FLAG_NO_MAPCHANGE);
		}
		case ID_DUAL_PISTOL:
		{
			if(IsIncapacitated(client))
			    CreateDataTimer(g_DualPistolTimeCvar * PISTOL_RELOAD_INCAP_MULTIPLY, WeaponReloadClip, pack, TIMER_FLAG_NO_MAPCHANGE);
			else
				CreateDataTimer(g_DualPistolTimeCvar, WeaponReloadClip, pack, TIMER_FLAG_NO_MAPCHANGE);
		}
		default: 
		{
			delete pack;
			return;
		}
	}
	
	pack.WriteCell(GetClientUserId(client));
	pack.WriteCell(EntIndexToEntRef(weapon));
	pack.WriteCell(weaponid);
	pack.WriteCell(g_hClientReload_Time[client]);
}

Action WeaponReloadClip(Handle timer, DataPack pack)
{
	pack.Reset();
	int client = GetClientOfUserId(pack.ReadCell());
	int CurrentWeapon = EntRefToEntIndex(pack.ReadCell());
	WeaponID weaponid = pack.ReadCell();
	float reloadtime = pack.ReadCell();
	int clip;
	
	if ( reloadtime != g_hClientReload_Time[client] || //裝彈時間被刷新
		!IsValidAliveSurvivor(client) || //client wrong
		CurrentWeapon == INVALID_ENT_REFERENCE || //weapon entity wrong
		HasEntProp(CurrentWeapon, Prop_Send, "m_bInReload") == false || GetEntData(CurrentWeapon, g_iOffsetInReload, 1) == 0 || //reload interrupted
		(clip = GetWeaponClip(CurrentWeapon)) >= WeaponMaxClip[weaponid] //CurrentWeapon complete reload finished
	)
	{
		return Plugin_Continue;
	}
		
	bool bIsInfiniteAmmo = IsInifiniteAmmo(weaponid);
	
	if (bIsInfiniteAmmo == false)
	{
		int ammo = GetOrSetPlayerAmmo(client, CurrentWeapon);
		if( (ammo - (WeaponMaxClip[weaponid] - clip)) <= 0)
		{
			clip = clip + ammo;
			ammo = 0;
		}
		else
		{
			ammo = ammo - (WeaponMaxClip[weaponid] - clip);
			clip = WeaponMaxClip[weaponid];
		}

		#if DEBUG
			PrintToChatAll("WeaponReloadClip, client: %N, ammo: %d, clip: %d", client, ammo, clip);
		#endif

		GetOrSetPlayerAmmo(client, CurrentWeapon, ammo);
		SetWeaponClip(CurrentWeapon, clip);
	}
	else
	{
		SetWeaponClip(CurrentWeapon, WeaponMaxClip[weaponid]);
	}

	return Plugin_Continue;
}

void ConVarChange_CvarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_bEnable  = hEnable.BoolValue;
	g_SmgTimeCvar = hSmgTimeCvar.FloatValue;
	g_RifleTimeCvar = hRifleTimeCvar.FloatValue;
	g_HuntingRifleTimeCvar = hHuntingRifleTimeCvar.FloatValue;
	g_PistolTimeCvar = hPistolTimeCvar.FloatValue;
	g_DualPistolTimeCvar = hDualPistolTimeCvar.FloatValue;
}

void ConVarChanged_AmmoCvars(Handle convar, const char[] oldValue, const char[] newValue)
{
	GetAmmoCvars();
}

void GetAmmoCvars()
{
	g_iAmmoRifle		= g_hAmmoRifle.IntValue;
	g_iAmmoSmg			= g_hAmmoSmg.IntValue;
	g_iAmmoHunting		= g_hAmmoHunting.IntValue;
}

int GetOrSetPlayerAmmo(int client, int iWeapon, int iAmmo = -1)
{
	int offset = GetEntData(iWeapon, g_iOffsetPrimaryAmmoType) * 4; // Thanks to "Root" or whoever for this method of not hard-coding offsets: https://github.com/zadroot/AmmoManager/blob/master/scripting/ammo_manager.sp

	if( offset )
	{
		if( iAmmo != -1 ) SetEntData(client, g_iOffsetAmmo + offset, iAmmo);
		else
		{
			int ammo = GetEntData(client, g_iOffsetAmmo + offset);
			return ammo;
		}
	}

	return 0;
}

int GetWeaponClip(int weapon)
{
    return GetEntData(weapon, g_iOffsetClip);
} 

void SetWeaponClip(int weapon, int clip)
{
	SetEntData(weapon, g_iOffsetClip, clip);
} 

bool IsIncapacitated(int client)
{
	return view_as<bool>(GetEntProp(client, Prop_Send, "m_isIncapacitated"));
}

WeaponID GetWeaponID(int weapon,const char[] weapon_name)
{
	WeaponID index = ID_NONE;

	if ( g_smWeaponNameID.GetValue(weapon_name, index) )
	{
		if(index == ID_PISTOL)
		{
			if( GetEntData(weapon, g_iOffset_PistolisDualWielding, 1) > 0) //dual pistol
			{
				return ID_DUAL_PISTOL;
			}

			return ID_PISTOL;
		}

		return index;
	}

	return index;
}

bool IsValidAliveSurvivor(int client) 
{
	if ( 1 <= client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client)) 
		return true;  
			
	return false; 
}

bool IsValidEntityIndex(int entity)
{
    return (MaxClients+1 <= entity <= GetMaxEntities());
}

bool IsInifiniteAmmo(WeaponID weaponid)
{
	switch(weaponid)
	{
		case ID_SMG:
		{
			if(g_iAmmoSmg == -2) return true;
		}
		case ID_RIFLE:
		{
			if(g_iAmmoRifle == -2) return true;
		}
		case ID_HUNTING_RIFLE:
		{
			if(g_iAmmoHunting == -2) return true;
		}
		case ID_PISTOL, ID_DUAL_PISTOL:
		{
			return true;
		}
	}

	return false;
}