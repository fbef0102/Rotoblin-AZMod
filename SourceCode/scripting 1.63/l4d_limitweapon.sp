#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <colors>

#define TEAM_SURVIVOR 2

static	const	String:	WEAPON_HUNTING_RIFLE[]			= "weapon_hunting_rifle";
static	const	String:	WEAPON_AUTOSHOTGUN[]			= "weapon_autoshotgun";
static	const	String:	WEAPON_RIFLE[]					= "weapon_rifle";
static	const	String:	WEAPON_PUMPSHOTGUN[]			= "weapon_pumpshotgun";
static	const	String:	WEAPON_SMG[]					= "weapon_smg";

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

static	const	Float:	TIP_TIMEOUT						= 8.0;
static			bool:	g_bHaveTipped[MAXPLAYERS + 1] 	= {false};


public Plugin:myinfo = 
{
	name = "l4d_limit_weapon",
	author = "Harry Potter",
	description = "As the name says, you dumb fuck!",
	version = "1.0",
	url = "myself"
}

public OnPluginStart()
{
	LoadTranslations("Roto2-AZ_mod.phrases");
	
	g_hLimitHuntingRifle_Cvar = CreateConVar("limit_huntingrifle", "1", "Maximum of hunting rifles the survivors can pick up. [-1:No limit]", FCVAR_NOTIFY | FCVAR_PLUGIN);
	g_hLimitAutoShotgun_Cvar = CreateConVar("limit_autoshotgun", "1", "Maximum of autoshotguns the survivors can pick up. [-1:No limit]", FCVAR_NOTIFY | FCVAR_PLUGIN);
	g_hLimitRifle_Cvar = CreateConVar("limit_rifle", "1", "Maximum of rifles the survivors can pick up. [-1:No limit]", FCVAR_NOTIFY | FCVAR_PLUGIN);
	g_hLimitPumpShotgun_Cvar = CreateConVar("limit_pumpshotgun", "4", "Maximum of pumpshotguns the survivors can pick up. [-1:No limit]", FCVAR_NOTIFY | FCVAR_PLUGIN);
	g_hLimitSmg_Cvar  = CreateConVar("limit_smg", "3", "Maximum of smgs the survivors can pick up. [-1:No limit]", FCVAR_NOTIFY | FCVAR_PLUGIN);
	
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
	
	for (new client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client)) continue;
		SDKHook(client, SDKHook_WeaponCanUse, _LHR_OnWeaponCanUse);
	}
	
	AutoExecConfig(true,"l4d_limitweapon");
}

public OnPluginEnd()
{
	UnhookConVarChange(g_hLimitHuntingRifle_Cvar, _LHR_Limit_CvarChange);
	UnhookConVarChange(g_hLimitAutoShotgun_Cvar, _LHR_AutoShotgun_CvarChange);
	UnhookConVarChange(g_hLimitRifle_Cvar, _LHR_Rifle_CvarChange);

	for (new client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client)) continue;
		SDKUnhook(client, SDKHook_WeaponCanUse, _LHR_OnWeaponCanUse);
	}
}


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

public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_WeaponCanUse, _LHR_OnWeaponCanUse);
}

public OnClientDisconnect(client)
{
	SDKUnhook(client, SDKHook_WeaponCanUse, _LHR_OnWeaponCanUse);
}

public Action:_LHR_OnWeaponCanUse(client, weapon)
{
	if (GetClientTeam(client) != TEAM_SURVIVOR) return Plugin_Continue;
	
	decl String:classname[128];
	GetEdictClassname(weapon, classname, sizeof(classname));
	//LogMessage("%N: %s",client,classname);
	if (!(StrEqual(classname, WEAPON_HUNTING_RIFLE)||
			StrEqual(classname, WEAPON_AUTOSHOTGUN)||
			StrEqual(classname, WEAPON_RIFLE) ||
			StrEqual(classname, WEAPON_PUMPSHOTGUN)||
			StrEqual(classname, WEAPON_SMG))) return Plugin_Continue;

	decl String:curclassname[128];
	new curWeapon = GetPlayerWeaponSlot(client, 0); // Get current primary weapon
	if (curWeapon != -1 && IsValidEntity(curWeapon))
	{
		GetEdictClassname(curWeapon, curclassname, sizeof(curclassname));
		if (StrEqual(curclassname, classname))
		{
			return Plugin_Continue; // Survivor already got Same Weapons and trying to pick up a ammo refill, allow it
		}
	}

	if(StrEqual(classname, WEAPON_HUNTING_RIFLE)){
		if (GetActiveWeapons(WEAPON_HUNTING_RIFLE) >= g_iLimitHuntingRifle && g_iLimitHuntingRifle >=0) // If ammount of active hunting rifles are at the limit
		{
			if (!IsFakeClient(client) && !g_bHaveTipped[client])
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
			CheatCommand(client, "give", "ammo");//_EF_DoAmmoPilesFix(client,false);
			return Plugin_Handled; // Dont allow survivor picking up the hunting rifle
		}
	}
	else if(StrEqual(classname, WEAPON_AUTOSHOTGUN)){
		if (GetActiveWeapons(WEAPON_AUTOSHOTGUN) >= g_iLimitAutoShotgun && g_iLimitAutoShotgun >=0)
		{
			if (!IsFakeClient(client) && !g_bHaveTipped[client])
			{
				g_bHaveTipped[client] = true;
				if (g_iLimitAutoShotgun > 0)
				{
					CPrintToChat(client, "[{olive}TS{default}] %T","rotoblin20",client,"Auto Shotgun",g_iLimitAutoShotgun);
					if(!StrEqual(curclassname,"weapon_pumpshotgun"))
					{
						if (g_iLimitPumpShotgun == -1 || g_iLimitPumpShotgun > GetActiveWeapons(WEAPON_PUMPSHOTGUN)) 
						{
							CheatCommand(client,"give", "pumpshotgun");
						}
					}
				}
				else
				{
					CPrintToChat(client, "[{olive}TS{default}] %T","rotoblin21",client,"Auto Shotgun");
				}
				CreateTimer(TIP_TIMEOUT, _LHR_Tip_Timer, client);
			}
			CheatCommand(client, "give", "ammo");//_EF_DoAmmoPilesFix(client,false);
			return Plugin_Handled; // Dont allow survivor picking up the auto shotgun
		}
	}
	else if(StrEqual(classname, WEAPON_RIFLE)){
		if (GetActiveWeapons(WEAPON_RIFLE) >= g_iLimitRifle && g_iLimitRifle >=0)
		{
			if (!IsFakeClient(client) && !g_bHaveTipped[client])
			{
				g_bHaveTipped[client] = true;
				if (g_iLimitRifle > 0)
				{
					CPrintToChat(client, "[{olive}TS{default}] %T","rotoblin20",client,"Rifle",g_iLimitRifle);
					if(!StrEqual(curclassname,"weapon_smg"))
					{
						if (g_iLimitSmg == -1 || g_iLimitSmg > GetActiveWeapons(WEAPON_SMG)) 
						{
							CheatCommand(client,"give", "smg");
						}
					}
				}
				else
				{
					CPrintToChat(client, "[{olive}TS{default}] %T","rotoblin21",client,"Rifle");
				}
				CreateTimer(TIP_TIMEOUT, _LHR_Tip_Timer, client);
			}
			CheatCommand(client, "give", "ammo");//_EF_DoAmmoPilesFix(client,false);
			return Plugin_Handled; // Dont allow survivor picking up the rifle
		}
	}
	else if(StrEqual(classname, WEAPON_PUMPSHOTGUN)){
		if (GetActiveWeapons(WEAPON_PUMPSHOTGUN) >= g_iLimitPumpShotgun && g_iLimitPumpShotgun >=0) 
		{
			if (!IsFakeClient(client) && !g_bHaveTipped[client])
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
			CheatCommand(client, "give", "ammo");//_EF_DoAmmoPilesFix(client,false);
			return Plugin_Handled; // Dont allow survivor picking up the pumpshotgun
		}
	}
	else if(StrEqual(classname, WEAPON_SMG)){
		if (GetActiveWeapons(WEAPON_SMG) >= g_iLimitSmg && g_iLimitSmg >=0) 
		{
			if (!IsFakeClient(client) && !g_bHaveTipped[client])
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
			CheatCommand(client, "give", "ammo");//_EF_DoAmmoPilesFix(client,false);
			return Plugin_Handled; // Dont allow survivor picking up the smg
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
	for (new client = 1; client <= MaxClients; client++)
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

stock CheatCommand(client, String:command[], String:arguments[] = "")
{
	new userFlags = GetUserFlagBits(client);
	SetUserFlagBits(client, ADMFLAG_ROOT);
	new flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", command, arguments);
	SetCommandFlags(command, flags);
	SetUserFlagBits(client, userFlags);
}