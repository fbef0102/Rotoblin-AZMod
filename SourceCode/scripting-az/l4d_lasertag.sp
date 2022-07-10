/******************************/
/*     [L4D(2)] Laser Tag     */
/*       By KrX/ Whosat       */
/* -------------------------- */
/* Creates a laser beam from  */
/*  player to bullet impact   */
/*  point.                    */
/* -------------------------- */
/*  Version 0.2 (12 Jan 2011) */
/* -------------------------- */
/******************************/
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "0.2"

#define DEFAULT_FLAGS FCVAR_NONE|FCVAR_NOTIFY

#define WEAPONTYPE_PISTOL   6
#define WEAPONTYPE_RIFLE    5
#define WEAPONTYPE_SNIPER   4
#define WEAPONTYPE_SMG      3
#define WEAPONTYPE_SHOTGUN  2
#define WEAPONTYPE_MELEE    1
#define WEAPONTYPE_UNKNOWN  0

ConVar cvar_vsenable;
ConVar cvar_realismenable;
ConVar cvar_bots;
ConVar cvar_enable;

ConVar cvar_pistols;
ConVar cvar_rifles;
ConVar cvar_snipers;
ConVar cvar_smgs;
ConVar cvar_shotguns;

ConVar cvar_laser_random;
ConVar cvar_laser_red;
ConVar cvar_laser_green;
ConVar cvar_laser_blue;
ConVar cvar_laser_alpha;

ConVar cvar_bots_random;
ConVar cvar_bots_red;
ConVar cvar_bots_green;
ConVar cvar_bots_blue;
ConVar cvar_bots_alpha;

ConVar cvar_laser_life;
ConVar cvar_laser_width;
ConVar cvar_laser_offset;
ConVar h_GameMode;

bool g_LaserTagEnable = true;
bool g_Bots;

bool b_TagWeapon[7];
float g_LaserOffset;
float g_LaserWidth;
float g_LaserLife;
int g_LaserColor[4];
int g_BotsLaserColor[4];
int g_Sprite;

int GameMode;
native bool Is_Ready_Plugin_On();

public Plugin myinfo = 
{
	name = "[L4D(2)] Laser Tag",
	author = "KrX/Whosat, Harry",
	description = "Shows a laser for straight-flying fired projectiles",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?p=1203196"
}

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
	cvar_enable = CreateConVar("l4d_lasertag_enable", "1", "Turnon Lasertagging. 0=disable, 1=enable", FCVAR_NONE, true, 0.0, true, 1.0);
 	cvar_vsenable = CreateConVar("l4d_lasertag_vs", "1", "Enable or Disable Lasertagging in Versus / Scavenge. 0=disable, 1=enable", FCVAR_NONE, true, 0.0, true, 1.0);
	cvar_realismenable = CreateConVar("l4d_lasertag_realism", "1", "Enable or Disable Lasertagging in Realism. 0=disable, 1=enable", FCVAR_NONE, true, 0.0, true, 1.0);
	cvar_bots = CreateConVar("l4d_lasertag_bots", "1", "Enable or Disable lasertagging for bots. 0=disable, 1=enable", FCVAR_NONE, true, 0.0, true, 1.0);
	
	cvar_pistols = CreateConVar("l4d_lasertag_pistols", "1", "LaserTagging for Pistols. 0=disable, 1=enable", FCVAR_NONE, true, 0.0, true, 1.0);
	cvar_rifles = CreateConVar("l4d_lasertag_rifles", "1", "LaserTagging for Rifles. 0=disable, 1=enable", FCVAR_NONE, true, 0.0, true, 1.0);
	cvar_snipers = CreateConVar("l4d_lasertag_snipers", "1", "LaserTagging for Sniper Rifles. 0=disable, 1=enable", FCVAR_NONE, true, 0.0, true, 1.0);
	cvar_smgs = CreateConVar("l4d_lasertag_smgs", "1", "LaserTagging for SMGs. 0=disable, 1=enable", FCVAR_NONE, true, 0.0, true, 1.0);
	cvar_shotguns = CreateConVar("l4d_lasertag_shotguns", "1", "LaserTagging for Shotguns. 0=disable, 1=enable", FCVAR_NONE, true, 0.0, true, 1.0);
		
	cvar_laser_random = CreateConVar("l4d_lasertag_random", "1", "If 1, Enable Random Color.", FCVAR_NONE, true, 0.0, true, 1.0);
	cvar_laser_red = CreateConVar("l4d_lasertag_red", "0", "Amount of Red", FCVAR_NONE, true, 0.0, true, 255.0);
	cvar_laser_green = CreateConVar("l4d_lasertag_green", "125", "Amount of Green", FCVAR_NONE, true, 0.0, true, 255.0);
	cvar_laser_blue = CreateConVar("l4d_lasertag_blue", "255", "Amount of Blue", FCVAR_NONE, true, 0.0, true, 255.0);
	cvar_laser_alpha = CreateConVar("l4d_lasertag_alpha", "100", "Transparency (Alpha) of Laser", FCVAR_NONE, true, 0.0, true, 255.0);
	
	cvar_bots_random = CreateConVar("l4d_lasertag_bots_random", "1", "If 1, Enable Random Color for Bot.", FCVAR_NONE, true, 0.0, true, 1.0);
	cvar_bots_red = CreateConVar("l4d_lasertag_bots_red", "0", "Bots Laser - Amount of Red", FCVAR_NONE, true, 0.0, true, 255.0);
	cvar_bots_green = CreateConVar("l4d_lasertag_bots_green", "255", "Bots Laser - Amount of Green", FCVAR_NONE, true, 0.0, true, 255.0);
	cvar_bots_blue = CreateConVar("l4d_lasertag_bots_blue", "75", "Bots Laser - Amount of Blue", FCVAR_NONE, true, 0.0, true, 255.0);
	cvar_bots_alpha = CreateConVar("l4d_lasertag_bots_alpha", "70", "Bots Laser - Transparency (Alpha) of Laser", FCVAR_NONE, true, 0.0, true, 255.0);
	
	cvar_laser_life = CreateConVar("l4d_lasertag_life", "0.80", "Seconds Laser will remain", FCVAR_NONE, true, 0.1);
	cvar_laser_width = CreateConVar("l4d_lasertag_width", "1.0", "Width of Laser", FCVAR_NONE, true, 1.0);
	cvar_laser_offset = CreateConVar("l4d_lasertag_offset", "36", "Lasertag Offset", FCVAR_NONE);
	
	CreateConVar("l4d_lasertag_version", PLUGIN_VERSION, "Lasertag Version", FCVAR_NONE|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	AutoExecConfig(true, "l4d_lasertag");

	HookEvent("bullet_impact", Event_BulletImpact);
	HookEvent("player_spawn",		Event_PlayerSpawn,	EventHookMode_PostNoCopy);
	HookEvent("round_start",		Event_RoundStart,	EventHookMode_PostNoCopy);
	HookEvent("round_end",			Event_RoundEnd,		EventHookMode_PostNoCopy);

	// ConVars that change whether the plugin is enabled
	h_GameMode = FindConVar("mp_gamemode");
	h_GameMode.AddChangeHook(ConVarGameMode);
	cvar_enable.AddChangeHook(CheckEnabled);
	cvar_vsenable.AddChangeHook(CheckEnabled);
	cvar_realismenable.AddChangeHook(CheckEnabled);
	cvar_bots.AddChangeHook(CheckEnabled);
	
	cvar_pistols.AddChangeHook(CheckWeapons);
	cvar_rifles.AddChangeHook(CheckWeapons);
	cvar_snipers.AddChangeHook(CheckWeapons);
	cvar_smgs.AddChangeHook(CheckWeapons);
	cvar_shotguns.AddChangeHook(CheckWeapons);
	
	cvar_laser_red.AddChangeHook(UselessHooker);
	cvar_laser_blue.AddChangeHook(UselessHooker);
	cvar_laser_green.AddChangeHook(UselessHooker);
	cvar_laser_alpha.AddChangeHook(UselessHooker);
	cvar_bots_red.AddChangeHook(UselessHooker);
	cvar_bots_blue.AddChangeHook(UselessHooker);
	cvar_bots_green.AddChangeHook(UselessHooker);
	cvar_bots_alpha.AddChangeHook(UselessHooker);
	
	cvar_laser_life.AddChangeHook(UselessHooker);
	cvar_laser_width.AddChangeHook(UselessHooker);
	cvar_laser_offset.AddChangeHook(UselessHooker);
	cvar_laser_random.AddChangeHook(UselessHooker);
	cvar_bots_random.AddChangeHook(UselessHooker);
}

public void OnPluginEnd()
{
	ResetPlugin();
}

public void ConVarGameMode(ConVar convar, const char[] oldValue, const char[] newValue)
{
	char GameName[16];
	h_GameMode.GetString(GameName, sizeof(GameName));
	
	if (StrEqual(GameName, "survival", false))
		GameMode = 3;
	else if (StrEqual(GameName, "versus", false) || StrEqual(GameName, "teamversus", false) || StrEqual(GameName, "scavenge", false) || StrEqual(GameName, "teamscavenge", false))
		GameMode = 2;
	else if (StrEqual(GameName, "coop", false))
		GameMode = 1;
	else if (StrEqual(GameName, "realism", false))
		GameMode = 0;
	else
		GameMode = -1;
}

public void OnMapStart()
{
	g_Sprite = PrecacheModel("materials/sprites/laser.vmt");		
}

public void OnMapEnd()
{
	ResetPlugin();
}

public void UselessHooker(ConVar convar, const char[] oldValue, const char[] newValue)
{
	OnConfigsExecuted();
}

bool g_blaser_random, g_bbots_random;
public void OnConfigsExecuted()
{
	CheckEnabled(INVALID_HANDLE, "", "");
	CheckWeapons(INVALID_HANDLE, "", "");
	
	g_LaserColor[0] = cvar_laser_red.IntValue;
	g_LaserColor[1] = cvar_laser_green.IntValue;
	g_LaserColor[2] = cvar_laser_blue.IntValue;
	g_LaserColor[3] = cvar_laser_alpha.IntValue;
	g_BotsLaserColor[0] = cvar_bots_red.IntValue;
	g_BotsLaserColor[1] = cvar_bots_green.IntValue;
	g_BotsLaserColor[2] = cvar_bots_blue.IntValue;
	g_BotsLaserColor[3] = cvar_bots_alpha.IntValue;
	
	g_LaserLife = cvar_laser_life.FloatValue;
	g_LaserWidth = cvar_laser_width.FloatValue;
	g_LaserOffset = cvar_laser_offset.FloatValue;

	g_blaser_random = cvar_laser_random.BoolValue;
	g_bbots_random = cvar_bots_random.BoolValue;
}

public void CheckEnabled(Handle convar, const char[] oldValue, const char[] newValue)
{
	// Bot Laser Tagging?
	g_Bots = cvar_bots.BoolValue;
	
	if(cvar_enable.IntValue == 0)
	{
		// IS GLOBALLY ENABLED?
		g_LaserTagEnable = false;
	}
	else if(GameMode == 2 && cvar_vsenable.IntValue == 0)
	{
		// IS VS Enabled?
		g_LaserTagEnable = false;
	}
	else if(GameMode == 0 && cvar_realismenable.IntValue == 0)
	{
		// IS REALISM ENABLED?
		g_LaserTagEnable = false;
	}
	else
	{
		// None of the above fulfilled, enable plugin.
		g_LaserTagEnable = true;
	}
}

public void CheckWeapons(Handle convar, const char[] oldValue, const char[] newValue)
{
	b_TagWeapon[WEAPONTYPE_PISTOL] = cvar_pistols.BoolValue;
	b_TagWeapon[WEAPONTYPE_RIFLE] = cvar_rifles.BoolValue;
	b_TagWeapon[WEAPONTYPE_SNIPER] = cvar_snipers.BoolValue;
	b_TagWeapon[WEAPONTYPE_SMG] = cvar_smgs.BoolValue;
	b_TagWeapon[WEAPONTYPE_SHOTGUN] = cvar_shotguns.BoolValue;
}

int GetWeaponType(int userid)
{
	// Get current weapon
	char weapon[32];
	GetClientWeapon(userid, weapon, 32);
	
	if(StrEqual(weapon, "weapon_hunting_rifle") || StrContains(weapon, "sniper") >= 0) return WEAPONTYPE_SNIPER;
	if(StrContains(weapon, "weapon_rifle") >= 0) return WEAPONTYPE_RIFLE;
	if(StrContains(weapon, "pistol") >= 0) return WEAPONTYPE_PISTOL;
	if(StrContains(weapon, "smg") >= 0) return WEAPONTYPE_SMG;
	if(StrContains(weapon, "shotgun") >=0) return WEAPONTYPE_SHOTGUN;
	
	return WEAPONTYPE_UNKNOWN;
}

int g_iPlayerSpawn, g_iRoundStart;
public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if( g_iPlayerSpawn == 1 && g_iRoundStart == 0 )
		CreateTimer(0.5, TimerStart, _, TIMER_FLAG_NO_MAPCHANGE);
	g_iRoundStart = 1;
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	ResetPlugin();
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if( g_iPlayerSpawn == 0 && g_iRoundStart == 1 )
		CreateTimer(0.5, TimerStart, _, TIMER_FLAG_NO_MAPCHANGE);
	g_iPlayerSpawn = 1;
}

public Action TimerStart(Handle timer)
{
	ResetPlugin();
	if(Is_Ready_Plugin_On()) cvar_enable.SetBool(true);
	else cvar_enable.SetBool(false);

	return Plugin_Continue;
}

public void L4D_OnRoundIsLive()
{
	cvar_enable.SetBool(false);
}

public Action Event_BulletImpact(Event event, const char[] name, bool dontBroadcast)
{
	if(!g_LaserTagEnable) return Plugin_Continue;
	
	// Get Shooter's Userid
	int userid = GetClientOfUserId(GetEventInt(event, "userid"));
	// Check if is Survivor
 	if(GetClientTeam(userid) != 2) return Plugin_Continue;
	// Check if is Bot and enabled
	int bot = 0;
	if(IsFakeClient(userid)) { if(!g_Bots) return Plugin_Continue; bot = 1; }
	
	// Check if the weapon is an enabled weapon type to tag
	if(b_TagWeapon[GetWeaponType(userid)])
	{
		// Bullet impact location
		float x = GetEventFloat(event, "x");
		float y = GetEventFloat(event, "y");
		float z = GetEventFloat(event, "z");
		
		float startPos[3];
		startPos[0] = x;
		startPos[1] = y;
		startPos[2] = z;
		
		/*float bulletPos[3];
		bulletPos[0] = x;
		bulletPos[1] = y;
		bulletPos[2] = z;*/
		
		float bulletPos[3];
		bulletPos = startPos;
		
		// Current player's EYE position
		float playerPos[3];
		GetClientEyePosition(userid, playerPos);
		
		float lineVector[3];
		SubtractVectors(playerPos, startPos, lineVector);
		NormalizeVector(lineVector, lineVector);
		
		// Offset
		ScaleVector(lineVector, g_LaserOffset);
		// Find starting point to draw line from
		SubtractVectors(playerPos, lineVector, startPos);
		

		// Draw the line
		int LaserColor[4];
		int BotsLaserColor[4];
		if(!bot){
			if(g_blaser_random)
			{
				LaserColor[0] = GetRandomInt(0, 255);
				LaserColor[1] = GetRandomInt(0, 255);
				LaserColor[2] = GetRandomInt(0, 255);
				LaserColor[3] = cvar_laser_alpha.IntValue;
				TE_SetupBeamPoints(startPos, bulletPos, g_Sprite, 0, 0, 0, g_LaserLife, g_LaserWidth, g_LaserWidth, 1, 0.0, LaserColor, 0);
			}
			else
				TE_SetupBeamPoints(startPos, bulletPos, g_Sprite, 0, 0, 0, g_LaserLife, g_LaserWidth, g_LaserWidth, 1, 0.0, g_LaserColor, 0);
		}
		else {
			if(g_bbots_random)
			{
				BotsLaserColor[0] = GetRandomInt(0, 255);
				BotsLaserColor[1] = GetRandomInt(0, 255);
				BotsLaserColor[2] = GetRandomInt(0, 255);
				BotsLaserColor[3] = cvar_bots_alpha.IntValue;
				TE_SetupBeamPoints(startPos, bulletPos, g_Sprite, 0, 0, 0, g_LaserLife, g_LaserWidth, g_LaserWidth, 1, 0.0, BotsLaserColor, 0);
			}
			else
				TE_SetupBeamPoints(startPos, bulletPos, g_Sprite, 0, 0, 0, g_LaserLife, g_LaserWidth, g_LaserWidth, 1, 0.0, g_BotsLaserColor, 0);
		}
		TE_SendToAll();
	}
	
 	return Plugin_Continue;
}

void ResetPlugin()
{
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
}