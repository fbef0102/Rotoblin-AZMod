#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

bool g_bIsWeaponEmpty[2048];
bool g_bIgnoreWeaponSwitch[MAXPLAYERS+1];


ConVar ConVar_Huntrifle_EReloadLayer = null;
ConVar ConVar_Huntrifle_EReloadTime = null;
ConVar ConVar_Huntrifle_ReloadLayer = null;
ConVar ConVar_Huntrifle_ReloadTime = null;
ConVar ConVar_Huntrifle_PickupLayer = null;
ConVar ConVar_Huntrifle_PickupTime = null;
ConVar ConVar_Huntrifle_SwtichLayer = null;
ConVar ConVar_Huntrifle_FireLayer = null;
ConVar ConVar_Huntrifle_SwtichTime = null;
ConVar hRateOfFireCvar;

int iConVar_Huntrifle_EReloadLayer;
float fConVar_Huntrifle_EReloadTime;
int iConVar_Huntrifle_ReloadLayer;
float fConVar_Huntrifle_ReloadTime;
int iConVar_Huntrifle_PickupLayer;
float fConVar_Huntrifle_PickupTime;
int iConVar_Huntrifle_SwtichLayer;
float fConVar_Huntrifle_SwtichTime;
int iConVar_Huntrifle_FireLayer;
float fRateOfFireCvar;

float g_fNextPrimaryAttack[MAXPLAYERS + 1]	=	{0.0};		//next gametime client's sniper is allowed to fire;
float g_fFireSpeed							= 	0.27;		//min low input values are 0.05 - 1.5 if you prefer stock speed * modifier, 
bool g_bIsSniperActive[MAXPLAYERS + 1]		= 	{true};		//is client holding a sniper atm
bool g_bFiredSniper[MAXPLAYERS + 1]			=	{false};	//did client just fire his sniper
bool g_Animation[MAXPLAYERS + 1]			=	{true};
int OLD_WEAPON[MAXPLAYERS+1], NEW_WEAPON[MAXPLAYERS+1];

public Plugin myinfo = 
{
	name = "Nerf Huntingrifle",
	author = "Tester:Xeno, Coder:Timocop, archer, L4D1 Huntingrifle modify by Harry",
	description = "Beta Reloading Animations",
	version = "1.5",
	url = "Harry Potter myself,bitch"
};

bool bLate;
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    EngineVersion test = GetEngineVersion();

    if( test != Engine_Left4Dead )
    {
        strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
        return APLRes_SilentFailure;
    }

    bLate = late;
    return APLRes_Success;
}

public void OnPluginStart()
{
	ConVar_Huntrifle_EReloadLayer = CreateConVar( "l4dbeta_huntingrifle_empty_reloadlayer", "15", "[-1 = DISABLED] <The Empty Reload Layer Sequence>",  FCVAR_NOTIFY );
	ConVar_Huntrifle_EReloadTime = CreateConVar( "l4dbeta_huntingrifle_empty_reloadtime", "1.25", "[-1 = DISABLED] <Time to Block the Empty Reload Sequence>",  FCVAR_NOTIFY );
	ConVar_Huntrifle_ReloadLayer = CreateConVar( "l4dbeta_huntingrifle_normal_reloadlayer", "-1", "[-1 = DISABLED] <The Normal Reload Layer Sequence>", FCVAR_NOTIFY );
	ConVar_Huntrifle_ReloadTime = CreateConVar( "l4dbeta_huntingrifle_normal_reloadtime", "-1", "[-1 = DISABLED] <Time to Block the Normal Reload Sequence>", FCVAR_NOTIFY );
	ConVar_Huntrifle_PickupLayer = CreateConVar( "l4dbeta_huntingrifle_pickuplayer", "-1", "[-1 = DISABLED] <The Pickup Layer Sequence>", FCVAR_NOTIFY );
	ConVar_Huntrifle_PickupTime = CreateConVar( "l4dbeta_huntingrifle_pickuptime", "-1", "[-1 = DISABLED] <Time to Block the Pickup Reload Sequence>", FCVAR_NOTIFY );
	ConVar_Huntrifle_SwtichLayer = CreateConVar( "l4dbeta_huntingrifle_swtichlayer", "7", "[-1 = DISABLED] <The Swtich Layer Sequence>", FCVAR_NOTIFY );
	ConVar_Huntrifle_SwtichTime = CreateConVar( "l4dbeta_huntingrifle_swtichtime", "1.8", "[-1 = DISABLED] <Time to Block the Swtich Layer Sequence>",  FCVAR_NOTIFY );
	ConVar_Huntrifle_FireLayer = CreateConVar( "l4d_huntingrifle_firelayer", "19", "[-1 = DISABLED] <The Fire Layer Sequence>", FCVAR_NOTIFY );
	hRateOfFireCvar	= CreateConVar("l4d_huntingrifle_fire_rate", "0.20", "[1.0 = Value Default] In percentage, rate of fire (min 0.05; max 1.50).",  FCVAR_NOTIFY);

	GetCvars();
	SetFireSpeed();
	ConVar_Huntrifle_EReloadLayer.AddChangeHook(ConVarChanged_Cvars);
	ConVar_Huntrifle_EReloadTime.AddChangeHook(ConVarChanged_Cvars);
	ConVar_Huntrifle_ReloadLayer.AddChangeHook(ConVarChanged_Cvars);
	ConVar_Huntrifle_ReloadTime.AddChangeHook(ConVarChanged_Cvars);
	ConVar_Huntrifle_PickupLayer.AddChangeHook(ConVarChanged_Cvars);
	ConVar_Huntrifle_PickupTime.AddChangeHook(ConVarChanged_Cvars);
	ConVar_Huntrifle_SwtichLayer.AddChangeHook(ConVarChanged_Cvars);
	ConVar_Huntrifle_SwtichTime.AddChangeHook(ConVarChanged_Cvars);
	ConVar_Huntrifle_FireLayer.AddChangeHook(ConVarChanged_Cvars);
	hRateOfFireCvar.AddChangeHook(ConVarChange_Slow);

	HookEvent("weapon_fire", eWeaponFire, EventHookMode_Pre);
	HookEvent("weapon_reload", eReloadWeapon);
	//HookEvent("spawner_give_item", ePlayerItemPickup);
	HookEvent("item_pickup", ePlayerItemPickup);

	if(bLate)
	{
		int iCurrentWeapon;
		static char sWeaponName[64];
		for (int client = 1; client <= MaxClients; client++)
		{
			if (!IsClientInGame(client)) continue;

			OnClientPutInServer(client);

			if (GetClientTeam(client) == 2 && IsPlayerAlive(client))
			{
				iCurrentWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
				if(iCurrentWeapon <= 0)
					return;

				GetEntityClassname(iCurrentWeapon, sWeaponName, sizeof(sWeaponName));
				if (strcmp(sWeaponName, "weapon_hunting_rifle", false) == 0)
				{
					g_bIsSniperActive[client] = true;
				}
				else
				{
					g_bIsSniperActive[client] = false;
				}
			}

		}
	}
}

public void ConVarChanged_Cvars(ConVar hCvar, const char[] sOldVal, const char[] sNewVal)
{
	GetCvars();
}

public void ConVarChange_Slow(ConVar hCvar, const char[] sOldVal, const char[] sNewVal)
{	
	GetCvars();
	SetFireSpeed();
}

void GetCvars()
{
	iConVar_Huntrifle_EReloadLayer = ConVar_Huntrifle_EReloadLayer.IntValue;
	fConVar_Huntrifle_EReloadTime = ConVar_Huntrifle_EReloadTime.FloatValue;
	iConVar_Huntrifle_ReloadLayer = ConVar_Huntrifle_ReloadLayer.IntValue;
	fConVar_Huntrifle_ReloadTime = ConVar_Huntrifle_ReloadTime.FloatValue;
	iConVar_Huntrifle_PickupLayer = ConVar_Huntrifle_PickupLayer.IntValue;
	fConVar_Huntrifle_PickupTime = ConVar_Huntrifle_PickupTime.FloatValue;
	iConVar_Huntrifle_SwtichLayer = ConVar_Huntrifle_SwtichLayer.IntValue;
	fConVar_Huntrifle_SwtichTime = ConVar_Huntrifle_SwtichTime.FloatValue;
	iConVar_Huntrifle_FireLayer = ConVar_Huntrifle_FireLayer.IntValue;
	fRateOfFireCvar = hRateOfFireCvar.FloatValue;
}

/****************************************************************************************************************************
	*****************************************************************************************************************************
	*****************************************************************************************************************************
	WARNING!
		If you're using your own animations, make sure its a LAYER(!!!!!) (ModelViewer > "v_models" and select "_LAYERS" only!) or your animation will mess up!
		Good Luck...
	*****************************************************************************************************************************
	*****************************************************************************************************************************
	*****************************************************************************************************************************/


public void eWeaponFire(Event event, const char[] name, bool dontBroadcast) 
{
	int iClient = GetClientOfUserId(event.GetInt("userid"));
	if (!IsValidClient(iClient) 	
			|| !IsPlayerAlive(iClient) 
			/*|| IsFakeClient(iClient)*/
			|| GetClientTeam(iClient) != 2 
			|| !g_bIsSniperActive[iClient])
		return;
	
	int iCurrentWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (iCurrentWeapon <= 0)
		return;	
	
	/*static char sWeaponName[64];
	GetEntityClassname(iCurrentWeapon, sWeaponName, sizeof(sWeaponName));
	if (strcmp(sWeaponName, "weapon_hunting_rifle", false) != 0)
		return;*/
		
	if (GetEntProp(iCurrentWeapon, Prop_Data, "m_iClip1") == 1)//最後一發射出去不使用拉勾動畫
	{
		g_bIsWeaponEmpty[iCurrentWeapon] = true;
		return;
	}
	else
	{
		g_fNextPrimaryAttack[iClient] = GetGameTime() + g_fFireSpeed;//射速
		g_bFiredSniper[iClient] = true;
		g_Animation[iClient] = true;
		CreateTimer(0.1, COLD_DOWN, GetClientUserId(iClient)); //拉勾動畫
	}
}

Action COLD_DOWN(Handle timer, int iClient) //拉勾動畫
{
	iClient = GetClientOfUserId(iClient);
	if(!iClient || !IsClientInGame(iClient))
		return Plugin_Continue;
	
	if(GetClientTeam(iClient) != 2 || !IsPlayerAlive(iClient))
		return Plugin_Continue;

	g_bFiredSniper[iClient] = false;	

	if(!g_Animation[iClient])
		return Plugin_Continue;

	g_Animation[iClient] = false;

	if(!g_bIsSniperActive[iClient])
		return Plugin_Continue;
		
	int iViewModel = GetEntPropEnt(iClient, Prop_Send, "m_hViewModel");
	if(!IsValidEntity(iViewModel))
		return Plugin_Continue;

	if(iConVar_Huntrifle_FireLayer <= 0) return Plugin_Continue;
		
	SetEntPropFloat(GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon"), Prop_Send, "m_flNextPrimaryAttack", g_fNextPrimaryAttack[iClient]);
	SetEntProp(iViewModel, Prop_Send, "m_nLayerSequence", iConVar_Huntrifle_FireLayer); //16
	SetEntPropFloat(iViewModel, Prop_Send, "m_flLayerStartTime", GetGameTime()); //Some Animation Glich Fixes
	
	return Plugin_Continue;
}

public Action OnPlayerRunCmd(int iClient, int &iButtons, int &iImpulse, float fVelocity[3], float fAngles[3], int &iWeapon)
{ 
	if(!IsClientInGame(iClient)) return Plugin_Continue;
	if(GetClientTeam(iClient) != 2) return Plugin_Continue;
	//if(IsFakeClient(iClient)) return Plugin_Continue;
	if(!IsPlayerAlive(iClient)) return Plugin_Continue;

	NEW_WEAPON[iClient] = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if(NEW_WEAPON[iClient] <= 0 ) return Plugin_Continue;
	
	if(!g_bIsSniperActive[iClient])
	{
		OLD_WEAPON[iClient] = NEW_WEAPON[iClient];
		return Plugin_Continue;
	}

	if(NEW_WEAPON[iClient] != OLD_WEAPON[iClient])
	{
		if(!g_bIgnoreWeaponSwitch[iClient])
			WeaponChangeAnimation(iClient, NEW_WEAPON[iClient]);
		else
			g_bIgnoreWeaponSwitch[iClient] = false;
		
		g_bIsWeaponEmpty[NEW_WEAPON[iClient]] = (GetEntProp(NEW_WEAPON[iClient], Prop_Data, "m_iClip1") <= 0);
	}
	OLD_WEAPON[iClient] = NEW_WEAPON[iClient];
		
	if (g_bFiredSniper[iClient] && iButtons & IN_ATTACK)	//If player is holding sniper, and he just fired a shot, and he uses +attack
	{
		//SetEntPropFloat(NEW_WEAPON[iClient], Prop_Send, "m_flNextPrimaryAttack", g_fNextPrimaryAttack[iClient]);
		g_bFiredSniper[iClient] = false;
		iButtons ^= IN_ATTACK;
	}
	else if(g_Animation[iClient] && iButtons & IN_ATTACK2)//拉槍動畫前右鍵推
	{
		//PrintToChatAll("This is IN_ATTACK2 event");
		g_Animation[iClient] = false;
	}
	return Plugin_Continue;
}

void WeaponChangeAnimation(int iClient, int hActiveWeapon)
{
	if (GetEntProp(hActiveWeapon, Prop_Data, "m_iClip1") > 0)
	{
		int iViewModel = GetEntPropEnt(iClient, Prop_Send, "m_hViewModel");
		if(!IsValidEntity(iViewModel)) return;
	
		if(iConVar_Huntrifle_SwtichLayer > 0)
		{
			SetEntProp(iViewModel, Prop_Send, "m_nLayerSequence", iConVar_Huntrifle_SwtichLayer); 
			SetEntPropFloat(iViewModel, Prop_Send, "m_flLayerStartTime", GetGameTime());
		}
		else
		{
			return;
		}

		if(fConVar_Huntrifle_SwtichTime > 0)
		{
			Weapon_Speed(iClient, fConVar_Huntrifle_SwtichTime);
		}
	}
}

public void eReloadWeapon(Event event, const char[] name, bool dontBroadcast) 
{
	int iClient = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(iClient) 	
			|| !IsPlayerAlive(iClient) 
			/*|| IsFakeClient(iClient)*/
			|| GetClientTeam(iClient) != 2
			|| !g_bIsSniperActive[iClient])
		return;

	int iCurrentWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	
	if(iCurrentWeapon <= 0)
		return;

	int iViewModel = GetEntPropEnt(iClient, Prop_Send, "m_hViewModel");
	
	if(!IsValidEntity(iViewModel))
		return;
	
	/*static char sWeaponName[64];
	GetEntityClassname(iCurrentWeapon, sWeaponName, sizeof(sWeaponName));
	if (strcmp(sWeaponName, "weapon_hunting_rifle", false) != 0)
		return;*/

	if(g_bIsWeaponEmpty[iCurrentWeapon])
	{
		if(iConVar_Huntrifle_EReloadLayer <= 0) return;

		SetEntProp(iViewModel, Prop_Send, "m_nLayerSequence", ConVar_Huntrifle_EReloadLayer.IntValue); //16
		SetEntPropFloat(iViewModel, Prop_Send, "m_flLayerStartTime", GetGameTime()); //Some Animation Glich Fixes
		if(fConVar_Huntrifle_EReloadTime > 0)
		{
			Weapon_Speed(iClient, fConVar_Huntrifle_EReloadTime);
		}
	}
	else
	{
		if(iConVar_Huntrifle_ReloadLayer <= 0) return;
		
		SetEntProp(iViewModel, Prop_Send, "m_nLayerSequence", iConVar_Huntrifle_ReloadLayer);
		SetEntPropFloat(iViewModel, Prop_Send, "m_flLayerStartTime", GetGameTime());

		if(fConVar_Huntrifle_ReloadTime > 0)
		{
			Weapon_Speed(iClient, fConVar_Huntrifle_ReloadTime);
		}
	}
}

public void ePlayerItemPickup(Event event, const char[] name, bool dontBroadcast) 
{
	int iClient = GetClientOfUserId(event.GetInt("userid"));
	
	if(!IsValidClient(iClient) 	
			|| !IsPlayerAlive(iClient) 
			/*|| IsFakeClient(iClient)*/
			|| GetClientTeam(iClient) != 2)
		return;
	
	static char sPickupName[64];
	event.GetString("item", sPickupName, sizeof(sPickupName)); 
	if (strcmp(sPickupName, "hunting_rifle", false) != 0)
		return;

	int iViewModel = GetEntPropEnt(iClient, Prop_Send, "m_hViewModel");
	if (!IsValidEntity(iViewModel))
		return;
	
	g_bIgnoreWeaponSwitch[iClient] = true;
	
	if(iConVar_Huntrifle_PickupLayer <= 0) return;
	
	SetEntProp(iViewModel, Prop_Send, "m_nLayerSequence", iConVar_Huntrifle_PickupLayer);
	SetEntPropFloat(iViewModel, Prop_Send, "m_flLayerStartTime", GetGameTime());

	if(fConVar_Huntrifle_PickupTime > 0)
	{
		Weapon_Speed(iClient, fConVar_Huntrifle_PickupTime);
	}

}

void Weapon_Speed(int iClient, float fValue) //WITHOUT ANIMATION SPEED CHANGE!
{
	if(fValue < 0) return;

	int iCurrentWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	
	if(IsValidEntity(iCurrentWeapon))
	{
		float fNextPrimaryAttack  = GetEntPropFloat(iCurrentWeapon, Prop_Send, "m_flNextPrimaryAttack");
		float fGameTime = GetGameTime();
		float fNextPrimaryAttack_Mod = (fNextPrimaryAttack - fGameTime ) * fValue;

		fNextPrimaryAttack_Mod += fGameTime;
		
		SetEntPropFloat(iCurrentWeapon, Prop_Send, "m_flNextPrimaryAttack", fNextPrimaryAttack_Mod);
		SetEntPropFloat(iCurrentWeapon, Prop_Send, "m_flTimeWeaponIdle", fNextPrimaryAttack_Mod);
		SetEntPropFloat(iClient, Prop_Send, "m_flNextAttack", fNextPrimaryAttack_Mod);
	}
}

bool IsValidClient(int iClient)
{
	if(iClient < 1 || iClient > MaxClients)
	return false;

	return IsClientInGame(iClient);
}

void SetFireSpeed()
{
	float fPercentage = fRateOfFireCvar;
	if (FloatAbs(fPercentage) <= 1.5)
	{
		fPercentage = fPercentage * 100.0;
	}
	if (fPercentage < 5.0) fPercentage = 5.0;
	if (fPercentage > 150.0) fPercentage = 150.0;
	fPercentage = 100.0 / fPercentage;
	g_fFireSpeed = 0.25 * fPercentage;	
}
public void OnClientDisconnect(int client)
{
	if(!IsClientInGame(client)) return;

	ResetClientSniperData(client);
}

public void OnClientPutInServer(int client)
{
	//SDKHook(client, SDKHook_WeaponEquipPost, OnWeaponEquipPost);
	SDKHook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitchPost);
	ResetClientSniperData(client);
}

void OnWeaponSwitchPost(int client, int weapon)
{
	if (GetClientTeam(client) != 2) return;

	if (weapon <= 0)
	{
		g_bIsSniperActive[client] = false;
		return;
	}
	
	static char classname[64];
	GetEntityClassname(weapon, classname, sizeof(classname));
	if (strcmp(classname, "weapon_hunting_rifle", false) == 0)
	{
		g_bIsSniperActive[client] = true;
	}
	else
	{
		g_bIsSniperActive[client] = false;
	}
}
/*
Action OnWeaponEquipPost(int client, int weapon)
{
	if (weapon <= 0) return;
	if (GetClientTeam(client) != 2);

	static char classname[64];
	GetEntityClassname(weapon, classname, sizeof(classname));
	if (strcmp(classname, "weapon_hunting_rifle", false) != 0) return;
	
	g_bIsSniperActive[client] = true;	//client is carrying sniper now (OnWeaponSwitch actually takes care of this)
}
*/

void ResetClientSniperData(int client)
{
	g_bFiredSniper[client] = false;
	g_Animation[client] = true;
	g_fNextPrimaryAttack[client] = 0.0;
}