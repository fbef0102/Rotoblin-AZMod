#pragma semicolon 1
#pragma newdecls required //強制1.7以後的新語法
#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <left4dhooks>
#define CLASSNAME_LENGTH 	64
#define DEBUG 0

public Plugin myinfo = 
{
	name = "weapon csgo reload",
	author = "Harry Potter",
	description = "reload like csgo weapon",
	version = "2.3",
	url = "https://forums.alliedmods.net/showthread.php?t=318820"
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

#define PISTOL_RELOAD_INCAP_MULTIPLY 1.3

StringMap g_smWeaponNameID;
ConVar g_hAmmoHunting, g_hAmmoRifle, g_hAmmoSmg;
int g_iAmmoHunting, g_iAmmoRifle, g_iAmmoSmg;

int WeaponAmmoOffest[view_as<int>(ID_WEAPON_MAX)];
int WeaponMaxClip[view_as<int>(ID_WEAPON_MAX)];

//cvars
ConVar hEnable, hEnableClipRecoverCvar, hSmgTimeCvar, hRifleTimeCvar, hHuntingRifleTimeCvar, hPistolTimeCvar, hDualPistolTimeCvar;

bool g_bEnable;
bool g_EnableClipRecoverCvar;
float g_SmgTimeCvar;
float g_RifleTimeCvar;
float g_HuntingRifleTimeCvar;
float g_PistolTimeCvar;
float g_DualPistolTimeCvar;

//value
float g_hClientReload_Time[MAXPLAYERS+1]	= {0.0};	

//offest
int ammoOffset;		

public void OnPluginStart()
{
	ammoOffset = FindSendPropInfo("CCSPlayer", "m_iAmmo");

	g_hAmmoRifle =		FindConVar("ammo_assaultrifle_max");
	g_hAmmoSmg =		FindConVar("ammo_smg_max");
	g_hAmmoHunting =	FindConVar("ammo_huntingrifle_max");

	GetAmmoCvars();
	g_hAmmoRifle.AddChangeHook(ConVarChanged_AmmoCvars);
	g_hAmmoSmg.AddChangeHook(ConVarChanged_AmmoCvars);
	g_hAmmoHunting.AddChangeHook(ConVarChanged_AmmoCvars);

	hEnable					= CreateConVar("l4d_weapon_csgo_reload_allow", 			"1", 	"0=off plugin, 1=on plugin"				 , FCVAR_NOTIFY, true, 0.0, true, 1.0);
	hEnableClipRecoverCvar	= CreateConVar("l4d_weapon_csgo_reload_clip_recover", 	"1", 	"enable previous clip recover?"			 , FCVAR_NOTIFY, true, 0.0, true, 1.0);
	hSmgTimeCvar			= CreateConVar("l4d_smg_reload_clip_time", 				"1.65", "reload time for smg clip"				 , FCVAR_NOTIFY, true, 0.0);
	hRifleTimeCvar			= CreateConVar("l4d_rifle_reload_clip_time", 			"1.2",  "reload time for rifle clip"			 , FCVAR_NOTIFY, true, 0.0);
	hHuntingRifleTimeCvar   = CreateConVar("l4d_huntingrifle_reload_clip_time", 	"2.6",  "reload time for hunting rifle clip"	 , FCVAR_NOTIFY, true, 0.0);
	hPistolTimeCvar 		= CreateConVar("l4d_pistol_reload_clip_time", 			"1.5",  "reload time for pistol clip"		     , FCVAR_NOTIFY, true, 0.0);
	hDualPistolTimeCvar 	= CreateConVar("l4d_dualpistol_reload_clip_time", 		"2.1",  "reload time for dual pistol clip"       , FCVAR_NOTIFY, true, 0.0);

	GetCvars();
	hEnable.AddChangeHook(ConVarChange_CvarChanged);
	hEnableClipRecoverCvar.AddChangeHook(ConVarChange_CvarChanged);
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

	WeaponAmmoOffest[ID_NONE] = 0;
	WeaponAmmoOffest[ID_PISTOL] = 0;
	WeaponAmmoOffest[ID_DUAL_PISTOL] = 0;
	WeaponAmmoOffest[ID_SMG] = 5;
	//WeaponAmmoOffest[ID_PUMPSHOTGUN] = 6;
	WeaponAmmoOffest[ID_RIFLE] = 3;
	//WeaponAmmoOffest[ID_AUTOSHOTGUN] = 6;
	WeaponAmmoOffest[ID_HUNTING_RIFLE] = 2;
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

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if(g_bEnable == false || g_EnableClipRecoverCvar == false)	return Plugin_Continue;
	
	if (IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client) && buttons & IN_RELOAD) //If survivor alive player is holding weapon and wants to reload
	{
		int iCurrentWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon"); //抓人類目前裝彈的武器
		if (iCurrentWeapon == -1 || !IsValidEntity(iCurrentWeapon))
		{
			return Plugin_Continue;
		}
		
		if(GetEntProp(iCurrentWeapon, Prop_Send, "m_bInReload") == 0)
		{
			char sWeaponName[32];
			GetClientWeapon(client, sWeaponName, sizeof(sWeaponName));
			int previousclip = GetWeaponClip(iCurrentWeapon);
			#if DEBUG
				PrintToChatAll("%N - %s clip:%d",client,sWeaponName,previousclip);
			#endif
			WeaponID weaponid = GetWeaponID(iCurrentWeapon,sWeaponName);
			int MaxClip = WeaponMaxClip[weaponid];
			
			switch(weaponid)
			{
				case ID_SMG,ID_RIFLE,ID_HUNTING_RIFLE:
				{
					if (0 < previousclip && previousclip < MaxClip)	//If the his current mag equals the maximum allowed, remove reload from buttons
					{
						DataPack data = new DataPack();
						data.WriteCell(GetClientUserId(client));
						data.WriteCell(EntIndexToEntRef(iCurrentWeapon));
						data.WriteCell(previousclip);
						data.WriteCell(weaponid);
						data.Reset();
						RequestFrame(RecoverWeaponClip, data);
					}
				}
				default:
				{
					return Plugin_Continue;
				}
			}
		}
	}

	return Plugin_Continue;
}

void RecoverWeaponClip(DataPack data) { 
	int client = GetClientOfUserId(data.ReadCell());
	int CurrentWeapon = EntRefToEntIndex(data.ReadCell());
	int previousclip = data.ReadCell();
	WeaponID weaponid = data.ReadCell();
	delete data;
	int nowweaponclip;
	
	if (!IsValidAliveSurvivor(client) || //client wrong
		CurrentWeapon == INVALID_ENT_REFERENCE || //weapon entity wrong
		(nowweaponclip = GetWeaponClip(CurrentWeapon)) >= WeaponMaxClip[weaponid] || //CurrentWeapon complete reload finished
		nowweaponclip == previousclip //CurrentWeapon clip has been recovered
	)
	{
		return;
	}
	
	switch(weaponid)
	{
		case ID_SMG:
		{
			if(g_iAmmoSmg == -2) return;
		}
		case ID_RIFLE:
		{
			if(g_iAmmoRifle == -2) return;
		}
		case ID_HUNTING_RIFLE:
		{
			if(g_iAmmoHunting == -2) return;
		}
	}

	int ammo = GetWeaponAmmo(client, WeaponAmmoOffest[weaponid]);
	ammo -= previousclip;
	#if DEBUG
		PrintToChatAll("CurrentWeapon clip recovered");
	#endif
	SetWeaponAmmo(client,WeaponAmmoOffest[weaponid],ammo);
	SetWeaponClip(CurrentWeapon,previousclip);
} 

void OnWeaponReload_Event(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
		
	if (!IsValidAliveSurvivor(client) || g_bEnable == false)
		return;

	int iCurrentWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon"); //抓人類目前裝彈的武器
	if (iCurrentWeapon == -1 || !IsValidEntity(iCurrentWeapon))
	{
		return;
	}
	
	g_hClientReload_Time[client] = GetEngineTime();
	
	char sWeaponName[32];
	GetClientWeapon(client, sWeaponName, sizeof(sWeaponName));
	WeaponID weaponid = GetWeaponID(iCurrentWeapon,sWeaponName);
	#if DEBUG
		PrintToChatAll("%N - %s - weaponid: %d",client,sWeaponName,weaponid);
		for (int i = 0; i < 32; i++)
		{
			PrintToConsole(client, "Offset: %i - Count: %i", i, GetEntData(client, ammoOffset+(i*4)));
		} 
	#endif
	
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
	pack.WriteCell(EntIndexToEntRef(iCurrentWeapon));
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
		HasEntProp(CurrentWeapon, Prop_Send, "m_bInReload") == false || GetEntProp(CurrentWeapon, Prop_Send, "m_bInReload") == 0 || //reload interrupted
		(clip = GetWeaponClip(CurrentWeapon)) >= WeaponMaxClip[weaponid] //CurrentWeapon complete reload finished
	)
	{
		return Plugin_Continue;
	}
		
	bool bIsInfiniteAmmo;
	switch(weaponid)
	{
		case ID_SMG:
		{
			if(g_iAmmoSmg == -2) bIsInfiniteAmmo = true;
		}
		case ID_RIFLE:
		{
			if(g_iAmmoRifle == -2) bIsInfiniteAmmo = true;
		}
		case ID_HUNTING_RIFLE:
		{
			if(g_iAmmoHunting == -2) bIsInfiniteAmmo = true;
		}
		case ID_PISTOL, ID_DUAL_PISTOL:
		{
			bIsInfiniteAmmo = true;
		}
	}
	
	if (bIsInfiniteAmmo == false)
	{
		int ammo = GetWeaponAmmo(client, WeaponAmmoOffest[weaponid]);
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

		SetWeaponAmmo(client, WeaponAmmoOffest[weaponid],ammo);
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
	g_EnableClipRecoverCvar = hEnableClipRecoverCvar.BoolValue;
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

int GetWeaponAmmo(int client, int offest)
{
    return GetEntData(client, ammoOffset+(offest*4));
} 

int GetWeaponClip(int weapon)
{
    return GetEntProp(weapon, Prop_Send, "m_iClip1");
} 

void SetWeaponAmmo(int client, int offest, int ammo)
{
    SetEntData(client, ammoOffset+(offest*4), ammo);
} 
void SetWeaponClip(int weapon, int clip)
{
	SetEntProp(weapon, Prop_Send, "m_iClip1", clip);
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
			if( GetEntProp(weapon, Prop_Send, "m_isDualWielding") > 0) //dual pistol
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