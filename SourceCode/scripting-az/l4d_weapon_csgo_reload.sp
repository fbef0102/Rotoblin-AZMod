#pragma semicolon 1
#pragma newdecls required //強制1.7以後的新語法
#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#define CLASSNAME_LENGTH 	64
#define DEBUG 0

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
char Weapon_Name[view_as<int>(ID_WEAPON_MAX)][CLASSNAME_LENGTH];
int WeaponAmmoOffest[view_as<int>(ID_WEAPON_MAX)];
int WeaponMaxClip[view_as<int>(ID_WEAPON_MAX)];

//cvars
ConVar hEnable, hEnableClipRecoverCvar, hSmgTimeCvar, hRifleTimeCvar, hHuntingRifleTimeCvar, hPistolTimeCvar, hDualPistolTimeCvar;
ConVar hDualPistolClipCvar, hSmgClipCvar, hPistolClipCvar, hRifleClipCvar, hHuntingRifleClipCvar;

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
											
public Plugin myinfo = 
{
	name = "weapon csgo reload",
	author = "Harry Potter",
	description = "reload like csgo weapon",
	version = "2.1",
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

public void OnPluginStart()
{
	ammoOffset = FindSendPropInfo("CCSPlayer", "m_iAmmo");

	hEnable					= CreateConVar("l4d_weapon_csgo_reload_allow", 		"1", 	"0=off plugin, 1=on plugin"				 , FCVAR_NOTIFY, true, 0.0, true, 1.0);
	hEnableClipRecoverCvar	= CreateConVar("l4d_weapon_csgo_reload_clip_recover", "1", 	"enable previous clip recover?"			 , FCVAR_NOTIFY, true, 0.0, true, 1.0);
	hSmgTimeCvar			= CreateConVar("l4d_smg_reload_clip_time", 			"1.65", "reload time for smg clip"				 , FCVAR_NOTIFY, true, 0.0);
	hRifleTimeCvar			= CreateConVar("l4d_rifle_reload_clip_time", 		"1.2",  "reload time for rifle clip"			 , FCVAR_NOTIFY, true, 0.0);
	hHuntingRifleTimeCvar   = CreateConVar("l4d_huntingrifle_reload_clip_time", "2.6",  "reload time for hunting rifle clip"	 , FCVAR_NOTIFY, true, 0.0);
	hPistolTimeCvar 		= CreateConVar("l4d_pistol_reload_clip_time", 		"1.5",  "reload time for pistol clip"		     , FCVAR_NOTIFY, true, 0.0);
	hDualPistolTimeCvar 	= CreateConVar("l4d_dualpistol_reload_clip_time", 	"2.1",  "reload time for dual pistol clip"       , FCVAR_NOTIFY, true, 0.0);
	hPistolClipCvar			= CreateConVar("l4d_pistol_clip", 					"15", 	"pistol max clip"					  	 , FCVAR_NOTIFY, true, 1.0);
	hDualPistolClipCvar		= CreateConVar("l4d_dualpistol_clip", 				"30", 	"dual pistol max clip"					 , FCVAR_NOTIFY, true, 1.0);
	hSmgClipCvar			= CreateConVar("l4d_smg_clip", 						"50", 	"smg max clip"							 , FCVAR_NOTIFY, true, 1.0);
	hRifleClipCvar			= CreateConVar("l4d_rifle_reload_clip", 			"50", 	"rifle max clip"						 , FCVAR_NOTIFY, true, 1.0);
	hHuntingRifleClipCvar	= CreateConVar("l4d_huntingrifle_reload_clip", 		"15", 	"huntingrifle max clip"					 , FCVAR_NOTIFY, true, 1.0);
	

	GetCvars();
	hEnable.AddChangeHook(ConVarChange_CvarChanged);
	hEnableClipRecoverCvar.AddChangeHook(ConVarChange_CvarChanged);
	hSmgTimeCvar.AddChangeHook(ConVarChange_CvarChanged);
	hRifleTimeCvar.AddChangeHook(ConVarChange_CvarChanged);
	hHuntingRifleTimeCvar.AddChangeHook(ConVarChange_CvarChanged);
	hPistolTimeCvar.AddChangeHook(ConVarChange_CvarChanged);
	hDualPistolTimeCvar.AddChangeHook(ConVarChange_CvarChanged);
	hPistolClipCvar.AddChangeHook(ConVarChange_MaxClipChanged);
	hDualPistolClipCvar.AddChangeHook(ConVarChange_MaxClipChanged);
	hSmgClipCvar.AddChangeHook(ConVarChange_MaxClipChanged);
	hRifleClipCvar.AddChangeHook(ConVarChange_MaxClipChanged);
	hHuntingRifleClipCvar.AddChangeHook(ConVarChange_MaxClipChanged);

	HookEvent("weapon_reload", OnWeaponReload_Event, EventHookMode_Post);
	HookEvent("round_start", RoundStart_Event);
	
	SetWeapon();
	SetWeaponMaxClip();

	//AutoExecConfig(true, "l4d_weapon_csgo_reload");
}

public void RoundStart_Event(Event event, const char[] name, bool dontBroadcast) 
{
	for(int i = 1; i <= MaxClients; i++)
	{
		g_hClientReload_Time[i] = 0.0;
	}
}

public void SetWeapon()
{
	Weapon_Name[ID_NONE] = "";
	Weapon_Name[ID_PISTOL] = "weapon_pistol";
	Weapon_Name[ID_DUAL_PISTOL] = "weapon_pistol";
	Weapon_Name[ID_SMG] = "weapon_smg";
	//Weapon_Name[ID_PUMPSHOTGUN] = "weapon_pumpshotgun";
	Weapon_Name[ID_RIFLE] = "weapon_rifle";
	//Weapon_Name[ID_AUTOSHOTGUN] = "weapon_autoshotgun";
	Weapon_Name[ID_HUNTING_RIFLE] = "weapon_hunting_rifle";

	WeaponAmmoOffest[ID_NONE] = 0;
	WeaponAmmoOffest[ID_PISTOL] = 0;
	WeaponAmmoOffest[ID_DUAL_PISTOL] = 0;
	WeaponAmmoOffest[ID_SMG] = 5;
	//WeaponAmmoOffest[ID_PUMPSHOTGUN] = 6;
	WeaponAmmoOffest[ID_RIFLE] = 3;
	//WeaponAmmoOffest[ID_AUTOSHOTGUN] = 6;
	WeaponAmmoOffest[ID_HUNTING_RIFLE] = 2;
}

public void SetWeaponMaxClip()
{
	WeaponMaxClip[ID_NONE] = 0;
	WeaponMaxClip[ID_PISTOL] = hPistolClipCvar.IntValue;
	WeaponMaxClip[ID_DUAL_PISTOL] = hDualPistolClipCvar.IntValue;
	WeaponMaxClip[ID_SMG] = hSmgClipCvar.IntValue;
	//WeaponMaxClip[ID_PUMPSHOTGUN] = 8;
	WeaponMaxClip[ID_RIFLE] = hRifleClipCvar.IntValue;
	//WeaponMaxClip[ID_AUTOSHOTGUN] = 10;
	WeaponMaxClip[ID_HUNTING_RIFLE] = hHuntingRifleClipCvar.IntValue;
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
					return Plugin_Continue;
			}
		}
	}
	return Plugin_Continue;
}

public void RecoverWeaponClip(DataPack data) { 
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
	
	
	if (nowweaponclip < WeaponMaxClip[weaponid] && nowweaponclip == 0)
	{
		int ammo = GetWeaponAmmo(client, WeaponAmmoOffest[weaponid]);
		ammo -= previousclip;
		#if DEBUG
			PrintToChatAll("CurrentWeapon clip recovered");
		#endif
		SetWeaponAmmo(client,WeaponAmmoOffest[weaponid],ammo);
		SetWeaponClip(CurrentWeapon,previousclip);
	}
} 

public void OnWeaponReload_Event(Event event, const char[] name, bool dontBroadcast)
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

public Action WeaponReloadClip(Handle timer, DataPack pack)
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
		
	if (clip < WeaponMaxClip[weaponid])
	{
		switch(weaponid)
		{
			case ID_SMG,ID_RIFLE,ID_HUNTING_RIFLE:
			{
				#if DEBUG
					PrintToChatAll("CurrentWeapon reload clip completed");
				#endif
			
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
				SetWeaponAmmo(client,WeaponAmmoOffest[weaponid],ammo);
				SetWeaponClip(CurrentWeapon,clip);
			}
			case ID_PISTOL,ID_DUAL_PISTOL:
			{
				#if DEBUG
					PrintToChatAll("Pistol reload clip completed");
				#endif
				SetWeaponClip(CurrentWeapon,WeaponMaxClip[weaponid]);
			}
		}
	}
	return Plugin_Continue;
}

public void ConVarChange_CvarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

public void ConVarChange_MaxClipChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	SetWeaponMaxClip();
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

stock int GetWeaponAmmo(int client, int offest)
{
    return GetEntData(client, ammoOffset+(offest*4));
} 

stock int GetWeaponClip(int weapon)
{
    return GetEntProp(weapon, Prop_Send, "m_iClip1");
} 

stock void SetWeaponAmmo(int client, int offest, int ammo)
{
    SetEntData(client, ammoOffset+(offest*4), ammo);
} 
stock void SetWeaponClip(int weapon, int clip)
{
	SetEntProp(weapon, Prop_Send, "m_iClip1", clip);
} 

stock bool IsIncapacitated(int client)
{
	return view_as<bool>(GetEntProp(client, Prop_Send, "m_isIncapacitated"));
}

stock WeaponID GetWeaponID(int weapon,const char[] weapon_name)
{
	if(StrEqual(weapon_name,"weapon_pistol",false))
	{
		if( GetEntProp(weapon, Prop_Send, "m_isDualWielding") > 0) //dual pistol
		{
			return ID_DUAL_PISTOL;
		}
		return ID_PISTOL;
	}

	for(WeaponID i = ID_NONE; i < ID_WEAPON_MAX ; ++i)
	{
		if(StrEqual(weapon_name,Weapon_Name[i],false))
		{
			return i;
		}
	}
	return ID_NONE;
}

bool IsValidAliveSurvivor(int client) 
{
    if ( 1 <= client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client)) 
		return true;      
    return false; 
}