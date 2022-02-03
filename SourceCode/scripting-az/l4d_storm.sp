#define PLUGIN_VERSION		"2.0"

/*======================================================================================
	Plugin Info:

*	Name	:	[l4d] Weather Control
*	Author	:	SilverShot & Harry Potter
*	Descrp	:	Create storms, lightning, fog, rain, wind, changes the skybox, sun and background colors.
*	Link	:	http://forums.alliedmods.net/showthread.php?t=184890

========================================================================================
	Change Log:
1.9 (11-11-2019)
	- Get infected probability (common: 30%, S.I.: 60%, witch: 100%, tank: no)
	- unlocks the shove penalty in coop and survival (code from Silvers: l4d_shove_penalty.smx)
	- shove penalty: 2 times
	- remove survivors M2 automatically reduce 1 HP
	

1.9 (5-3-2019)
	- Add more Dard Coop settings
	- Incap health - > 150
	- Allows incapped survivors to crawl with thirdperson and plays crawling animation
	- Fixes the bug with crawling enabled that allows survivors to crawl while being pounced if incapped
	- survivor who use M2 to shove a common or a si (except for tank) will automatically reduce 1 HP
	
1.8 (21-2-2019)
	- Add Dard Coop Mode
	- survivor who get hurt by common or si (except for tank) will be infected. it would keep hurting player. To cure infected,
	  eat a pill or use a first aid kit
	- Pills heal over time
	- Block player join infected team
	- infected ladder booster by AiMee
	
1.7 (20-2-2019)
	- CreateConVar("sm_envtools_fogdensity", "0.99", "霧濃度", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	- CreateConVar("sm_envtools_fogstart", "180", "離自身中心多少距離才漸層起霧", FCVAR_NOTIFY, true, 0.0, true, 8000.0);
	- CreateConVar("sm_envtools_fogend", "250", "離自身中心多少距離才完全起霧(影響特感能生的距離) 0:disable 500:效果", FCVAR_NOTIFY, true, 0.0, true, 8000.0);
	- Add "Fog" in l4d_storm.cfg
	
--Harry Update Above--	

1.6 (12-Aug-2013)
	- Added snow.
	- Added command "sm_stormconfig" to show which section has loaded from the data config.
	- Added command "sm_snows" to toggle snow on and off.
	- Added data config keys "snow", "snow_idle", "snow_storm", to control when snow is enabled.
	- Fixed duplicate key entry for "fog_idle_start" in the data. Replaced with the correct "fog_storm_start" key.

1.5 (23-May-2012)
	- Missing data config keys "rain_idle" and "rain_storm" will use default values "75" and "250" respectively.
	- Fixed creating entities when the map has not started.

1.4 (21-May-2012)
	- Fixed the fog disappearing when weather is reset during a transition between idle/storm.

1.3 (20-May-2012)
	- Added data config keys "rain_idle" and "rain_storm" to control the visibility of rain, requested by "adrianman".

1.2 (17-May-2012)
	- Fixed a bug with the fog when resetting the map, which caused the bots to not see properly.

1.1 (15-May-2012)
	- Added cvar "l4d_storm_style". Method to refresh map light style: 0=Old (0.2 sec low FPS, does not the whole world). 1=Almost always lights the whole world (0.5 sec low FPS), 2=Lights the whole world (1 sec low FPS).
	- Added command "sm_farz" to set the maps far z-clip. This will make the map stop rendering stuff after the specified distance.
	- Added data config keys "far_z_idle" and "far_z_storm" which control the maps far z-clip when the weather is idle/storm.
	- Added data config key "lightning_time" to control how long fires burn when lightning strikes the ground.

1.0 (10-May-2012)
	- Initial Release.

======================================================================================*/

#pragma semicolon			1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <sdktools_functions> 
#include <l4d_lib>

#define CVAR_FLAGS			FCVAR_NOTIFY
#define CHAT_TAG			"\x03[STORM] \x05"
#define CONFIG_SETTINGS		"data/l4d_storm.cfg"
#define CONFIG_TRIGGERS		"data/l4d_storm_triggers.cfg"

#define MODEL_BOUNDING		"models/props/cs_militia/silo_01.mdl"

#define PARTICLE_FIRE		"fire_medium_base"
#define PARTICLE_FOG		"fog_lowpatch"
#define PARTICLE_GLOW		"railroad_light_glow"
#define PARTICLE_LIGHT1		"railroad_light_explode"
#define PARTICLE_LIGHT2		"railroad_light_explode"

//#define	SOUND_STORM1		"ambient/ambience/rainscapes/Thunder_close01.wav"
//#define	SOUND_STORM2		"ambient/ambience/rainscapes/Thunder_close02.wav"
//#define	SOUND_STORM3		"ambient/ambience/rainscapes/Thunder_close03.wav"
//#define	SOUND_STORM4		"ambient/ambience/rainscapes/Thunder_close04.wav"
//#define	SOUND_STORM5		"ambient/ambience/rainscapes/thunder_distant01.wav"
//#define	SOUND_STORM6		"ambient/ambience/rainscapes/thunder_distant02.wav"
//#define	SOUND_STORM7		"ambient/ambience/rainscapes/thunder_distant03.wav"
#define	SOUND_STORM8		"ambient/weather/thunderstorm/lightning_strike_1.wav"
#define	SOUND_STORM9		"ambient/weather/thunderstorm/lightning_strike_2.wav"
#define	SOUND_STORM10		"ambient/weather/thunderstorm/lightning_strike_3.wav"
#define	SOUND_STORM11		"ambient/weather/thunderstorm/lightning_strike_4.wav"
#define	SOUND_STORM12		"ambient/weather/thunderstorm/thunder_1.wav"
#define	SOUND_STORM13		"ambient/weather/thunderstorm/thunder_2.wav"
#define	SOUND_STORM14		"ambient/weather/thunderstorm/thunder_3.wav"
#define	SOUND_STORM15		"ambient/weather/thunderstorm/thunder_far_away_1.wav"
#define	SOUND_STORM16		"ambient/weather/thunderstorm/thunder_far_away_2.wav"

#define	SOUND_RAIN1			"ambient/weather/crucial_rumble_rain_nowind.wav"
#define	SOUND_RAIN2			"ambient/water/water_flow_loop1.wav"
#define	SOUND_RAIN3			"ambient/weather/crucial_rumble_rain.wav"

#define	SOUND_WIND1			"ambient/wind/crucial_wind_outdoors_1.wav"
#define	SOUND_WIND2			"ambient/ambience/streetwind01_loop.wav"
#define	SOUND_WIND3			"ambient/ambience/crucial_urb4b_topfloorwind_loop.wav"
#define	SOUND_WIND4			"vehicles/helicopter/helicopterwind_loop.wav"

#define MAX_ALLOWED			10
#define MAX_ENTITIES		16
#define MAX_TRIGGERS		7
#define	MAX_RAIN			8
#define	MAX_FOG				16

enum ()
{
	STATE_OFF,
	STATE_IDLE,
	STATE_SURGE,
	STATE_STORM,
	STATE_END
}

static 	Handle:g_hCvarAllow, Handle:g_hCvarModes, Handle:g_hCvarModesOff, Handle:g_hCvarModesTog, Handle:g_hCvarMixer, Handle:g_hCvarPost, Handle:g_hCvarStyle,
		bool:g_bCvarAllow, g_iCvarMixer, Float:g_fCvarPost, g_iCvarStyle,

		Handle:g_hCvarSkyName, Handle:g_hCvarGameMode, Handle:g_hTmrEndStorm, Handle:g_hTmrTimeout, Handle:g_hTmrTrigger,
		g_iLateLoad, bool:g_bLoaded, g_iReset, g_iStarted, g_iPlayerSpawn, g_iRoundStart, g_iStormState, g_iChance, g_iRandom,

		// Menu // Trigger boxes // Light Style
		Handle:g_hMenuMain, Handle:g_hMenuVMaxs, Handle:g_hMenuVMins, Handle:g_hMenuPos, Handle:g_hTmrBeam,
		g_iLaserMaterial, g_iHaloMaterial, g_iTriggerCount, g_iTriggerSelected, g_iTriggerCfgIndex[MAXPLAYERS+1], g_iTriggers[MAX_TRIGGERS], g_iLightStyle[MAXPLAYERS+1],

		// Fog: saved // data settings
		g_iFogOn, g_iFog, g_iParticleFog, String:g_sFogStolen[MAX_FOG][64], Float:g_fFogStolen[MAX_FOG][9], g_iFogStolen[MAX_FOG][5], g_iSunSaved = -1,
		String:g_sCfgFogColor[12], g_iCfgFogBlend, g_iCfgFogIdle, g_iCfgFogStorm, g_iCfgFogIdle2,
		g_iCfgFogStorm2, Float:g_fCfgFogOpaqueIdle, Float:g_fCfgFogOpaqueStorm, g_iCfgFogZIdle, g_iCfgFogZStorm,

		// Other data settings
		String:g_sSkyBox[64], g_iCfgBackground, String:g_sCfgLightStyle[64], g_iCfgClouds, g_iCfgRain, g_iCfgRainIdle, g_iCfgRainStorm,
		g_iCfgSnow, g_iCfgSnowIdle, g_iCfgSnowStorm, g_iCfgWind, g_iCfgLight, g_iCfgLightDmg, g_iCfgLightTime, g_iCfgLightFlash,

		// Storm state triggers
		g_iCfgForever, g_iCfgTimeout, g_iCfgTimeMax, g_iCfgTimeMin, g_iCfgTimer, g_iCfgFinale, g_iCfgHorde, g_iCfgPanic,
		g_iCfgTank, g_iCfgTankDeath, g_iCfgWitch, g_iCfgWitchHead, g_iCfgWitchAlert,

		g_iLight, g_iRains[MAX_RAIN], g_iSnow, g_iWind, g_iStormLayer, g_iVoip, g_iVoipIn, g_iVoipOut, g_iPointCmd, g_iLogicDirector, g_iFogVolume,
		g_iPostProcess, g_iLogicIn, g_iLogicOut, g_iSound, g_iSkyCamera, g_iSkyCam[2];

static	String:g_sConfigSection[64];

new Handle:cvarFogDensity;
new Handle:cvarFogStartDist;
new Handle:cvarFogEndDist;
static Handle:cvarTempHealthDecay							= INVALID_HANDLE;
static bool:ClientIsInfected[MAXPLAYERS + 1];
static ClientIsInfectedTime[MAXPLAYERS + 1];
#define INFECTION_INTERVAL 6.0
#define INFECTION_INTERVAL_DMG 2
#define MAXENTITIES 2048
static laggedMovementOffset = 0;
new bool:Allow[MAXPLAYERS];
#define ANIM_L4D_ZOEY		509
#define ANIM_L4D_LOUIS		546
#define ANIM_L4D_FRANCIS	547
#define ANIM_L4D_BILL		546
new g_iClone[MAXPLAYERS];
#define GAMEDATA			"l4d_shove_penalty"
#define MAX_COUNT			26
new g_ByteCount, g_ByteSaved[MAX_COUNT];
new Address:g_Address;

// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================
public Plugin:myinfo =
{
	name = "[L4D] Weather Control",
	author = "SilverShot & Harry",
	description = "Create storms, lightning, fog, rain, wind, changes the skybox, sun and background colors.",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=184890"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();

	if( test != Engine_Left4Dead )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1.");
		return APLRes_SilentFailure;
	}

	g_iLateLoad = late;
	return APLRes_Success;
}

public OnPluginStart()
{
	LoadTranslations("Roto2-AZ_mod.phrases");
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "gamedata/%s.txt", GAMEDATA);
	if( FileExists(sPath) == false ) SetFailState("\n==========\nMissing required file: \"%s\".\nRead installation instructions again.\n==========", sPath);

	Handle hGameData = LoadGameConfigFile(GAMEDATA);
	if( hGameData == null ) SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	g_Address = GameConfGetAddress(hGameData, "CTerrorWeapon::TrySwing");
	if( !g_Address ) SetFailState("Failed to load \"CTerrorWeapon::TrySwing\" address.");

	int offset = GameConfGetOffset(hGameData, "TrySwing_Offset");
	if( offset == -1 ) SetFailState("Failed to load \"TrySwing_Offset\" offset.");

	g_ByteCount = GameConfGetOffset(hGameData, "TrySwing_Count");
	if( g_ByteCount == -1 ) SetFailState("Failed to load \"TrySwing_Count\" count.");
	if( g_ByteCount > MAX_COUNT ) SetFailState("Error: byte count exceeds scripts defined value (%d/%d).", g_ByteCount, MAX_COUNT);

	g_Address += view_as<Address>(offset);

	for( int i = 0; i < g_ByteCount; i++ )
	{
		g_ByteSaved[i] = LoadFromAddress(g_Address + view_as<Address>(i), NumberType_Int8);
	}

	if( g_ByteSaved[0] != (g_ByteCount == 1 ? 0x0F : 0xE8) ) SetFailState("Failed to load, byte mis-match. %d (0x%02X != 0xE8)", offset, g_ByteSaved[0]);

	delete hGameData;

	PatchAddress(true);
	

	g_hCvarSkyName = FindConVar("sv_skyname");
	if( g_hCvarSkyName == INVALID_HANDLE )
		SetFailState("Cannot find the ConVar handle for 'sv_skyname'");
	HookConVarChange(g_hCvarSkyName,	ConVarChanged_SkyBox);

	g_hCvarAllow = CreateConVar(		"l4d_storm_allow",			"1",			"0=Plugin off, 1=Plugin on.", CVAR_FLAGS);
	g_hCvarModes =	CreateConVar(		"l4d_storm_modes",			"",				"Turn on the plugin in these game modes, separate by commas (no spaces). (Empty = all).", CVAR_FLAGS);
	g_hCvarModesOff =	CreateConVar(	"l4d_storm_modes_off",		"",				"Turn off the plugin in these game modes, separate by commas (no spaces). (Empty = none).", CVAR_FLAGS );
	g_hCvarModesTog = CreateConVar(		"l4d_storm_modes_tog",		"0",			"Turn on the plugin in these game modes. 0=All, 1=Coop, 2=Survival, 4=Versus, 8=Scavenge. Add numbers together.", CVAR_FLAGS );
	g_hCvarMixer =	CreateConVar(		"l4d_storm_mixer",			"0",			"0=Off, 1=Turn down the voip voice transmit volume during the storm state.", CVAR_FLAGS);
	g_hCvarPost =	CreateConVar(		"l4d_storm_post",			"0.0",		"0.0=Off. Applies post process effect during the storm state. Value near 0 will blur, lower values cause other effects.", CVAR_FLAGS);
	g_hCvarStyle =	CreateConVar(		"l4d_storm_style",			"0",			"Method to refresh map light style: 0=Old (0.2 sec low FPS, does not the whole world). 1=Almost always lights the whole world (0.5 sec low FPS), 2=Lights the whole world (1 sec low FPS).", CVAR_FLAGS);
	CreateConVar(						"l4d_storm_version",		PLUGIN_VERSION,	"Weather Control plugin version.", CVAR_FLAGS|FCVAR_REPLICATED|FCVAR_DONTRECORD);

	g_hCvarGameMode = FindConVar("mp_gamemode");
	HookConVarChange(g_hCvarGameMode,		ConVarChanged_Allow);
	HookConVarChange(g_hCvarAllow,			ConVarChanged_Allow);
	HookConVarChange(g_hCvarModes,			ConVarChanged_Allow);
	HookConVarChange(g_hCvarModesOff,		ConVarChanged_Allow);
	HookConVarChange(g_hCvarModesTog,		ConVarChanged_Allow);
	HookConVarChange(g_hCvarMixer,			ConVarChanged_Cvars);
	HookConVarChange(g_hCvarPost,			ConVarChanged_Cvars);
	HookConVarChange(g_hCvarStyle,			ConVarChanged_Cvars);

	RegAdminCmd(	"sm_storm",			CmdStormMenu,		ADMFLAG_ROOT,	"Opens the Storm menu.");
	RegAdminCmd(	"sm_stormstart",	CmdStormStart,		ADMFLAG_ROOT,	"Stats the Storm if possible.");
	RegAdminCmd(	"sm_stormstop",		CmdStormStop,		ADMFLAG_ROOT,	"Stops the Storm if possible.");
	RegAdminCmd(	"sm_stormrefresh",	CmdStormRefresh,	ADMFLAG_ROOT,	"Refresh the plugin, reloading the config and storm.");
	RegAdminCmd(	"sm_stormreset",	CmdStormReset,		ADMFLAG_ROOT,	"Stops the storm and resets the weather to the maps default.");
	RegAdminCmd(	"sm_stormconfig",	CmdStormConfig,		ADMFLAG_ROOT,	"Display the currently loaded section from the data config.");
	RegAdminCmd(	"sm_lightning",		CmdLightning,		ADMFLAG_ROOT,	"Creates a Lightning Strike.");
	RegAdminCmd(	"sm_background",	CmdBackground,		ADMFLAG_ROOT,	"Set the background color. Reset with no args. Set the color with three values between 0-255 separated by spaces: sm_background <r> <g> <b>.");
	RegAdminCmd(	"sm_farz",			CmdFarZ,			ADMFLAG_ROOT,	"Set the maps far z-clip. This will make the map stop rendering stuff after the specified distance. Usage: sm_farz <distance>.");
	RegAdminCmd(	"sm_maplight",		CmdMapLight,		ADMFLAG_ROOT,	"Set the maps lighting. Reset with no args. Usage: sm_maplight: <chars a-z, 1-64 chars allowed. More info: http://developer.valvesoftware.com/wiki/Light#Appearances");
	RegAdminCmd(	"sm_fog",			CmdFog,				ADMFLAG_ROOT,	"No args toggles the fog on/off. Set the color with three values between 0-255 separated by spaces: sm_fog <r> <g> <b>.");
	RegAdminCmd(	"sm_rains",			CmdRain,			ADMFLAG_ROOT,	"Toggles the rain on/off.");
	RegAdminCmd(	"sm_snows",			CmdSnow,			ADMFLAG_ROOT,	"Toggles the snow on/off.");
	RegAdminCmd(	"sm_winds",			CmdWind,			ADMFLAG_ROOT,	"Toggles the wind on/off.");
	RegAdminCmd(	"sm_sun",			CmdSun,				ADMFLAG_ROOT,	"Set the sun color. Reset with no args. Turn off: sm_sun 0. Set the color with three values between 0-255 separated by spaces: sm_sun <r> <g> <b>.");
	RegAdminCmd(	"sm_stormset",		CmdStormSet,		ADMFLAG_ROOT,	"Sets the fog, background and sun color. Reset with no args. Set the color with three values between 0-255 separated by spaces: sm_stormset <r> <g> <b>.");

	g_hMenuMain = CreateMenu(MainMenuHandler);
	AddMenuItem(g_hMenuMain, "", "Start Storm");
	AddMenuItem(g_hMenuMain, "", "Stop Storm");
	AddMenuItem(g_hMenuMain, "", "Reset Weather");
	AddMenuItem(g_hMenuMain, "", "Triggers");
	AddMenuItem(g_hMenuMain, "", "Refresh");
	SetMenuTitle(g_hMenuMain, "Weather Control");
	SetMenuExitButton(g_hMenuMain, true);

	g_hMenuVMaxs = CreateMenu(VMaxsMenuHandler);
	AddMenuItem(g_hMenuVMaxs, "", "10 x 10 x 100");
	AddMenuItem(g_hMenuVMaxs, "", "25 x 25 x 100");
	AddMenuItem(g_hMenuVMaxs, "", "50 x 50 x 100");
	AddMenuItem(g_hMenuVMaxs, "", "100 x 100 x 100");
	AddMenuItem(g_hMenuVMaxs, "", "150 x 150 x 100");
	AddMenuItem(g_hMenuVMaxs, "", "200 x 200 x 100");
	AddMenuItem(g_hMenuVMaxs, "", "250 x 250 x 100");
	SetMenuTitle(g_hMenuVMaxs, "Storm - Trigger VMaxs");
	SetMenuExitBackButton(g_hMenuVMaxs, true);

	g_hMenuVMins = CreateMenu(VMinsMenuHandler);
	AddMenuItem(g_hMenuVMins, "", "-10 x -10 x 0");
	AddMenuItem(g_hMenuVMins, "", "-25 x -25 x 0");
	AddMenuItem(g_hMenuVMins, "", "-50 x -50 x 0");
	AddMenuItem(g_hMenuVMins, "", "-100 x -100 x 0");
	AddMenuItem(g_hMenuVMins, "", "-150 x -150 x 0");
	AddMenuItem(g_hMenuVMins, "", "-200 x -200 x 0");
	AddMenuItem(g_hMenuVMins, "", "-250 x -250 x 0");
	SetMenuTitle(g_hMenuVMins, "Storm - Trigger VMins");
	SetMenuExitBackButton(g_hMenuVMins, true);

	g_hMenuPos = CreateMenu(PosMenuHandler);
	AddMenuItem(g_hMenuPos, "", "X + 1.0");
	AddMenuItem(g_hMenuPos, "", "Y + 1.0");
	AddMenuItem(g_hMenuPos, "", "Z + 1.0");
	AddMenuItem(g_hMenuPos, "", "X - 1.0");
	AddMenuItem(g_hMenuPos, "", "Y - 1.0");
	AddMenuItem(g_hMenuPos, "", "Z - 1.0");
	AddMenuItem(g_hMenuPos, "", "SAVE");
	SetMenuTitle(g_hMenuPos, "Storm - Set Origin");
	SetMenuExitBackButton(g_hMenuPos, true);
	 
	cvarFogDensity = CreateConVar("sm_envtools_fogdensity", "0.99", "霧濃度", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvarFogStartDist = CreateConVar("sm_envtools_fogstart", "0", "離自身中心多少距離才漸層起霧", FCVAR_NOTIFY, true, 0.0, true, 8000.0);
	cvarFogEndDist = CreateConVar("sm_envtools_fogend", "500", "離自身中心多少距離才完全起霧(影響特感能生的距離) 0:disable 500:效果", FCVAR_NOTIFY, true, 0.0, true, 8000.0);

	cvarTempHealthDecay =	FindConVar("pain_pills_decay_rate");
	laggedMovementOffset = FindSendPropInfo("CTerrorPlayer", "m_flLaggedMovementValue");
	for( new i = 0; i < MAXPLAYERS; i++ )
		g_iClone[i] = -1;
}

public Event_heal_success(Handle:event, const String:name[], bool:dontBroadcast)
{
	new subject = GetClientOfUserId(GetEventInt(event, "subject"));
	if (subject<=0||!IsClientAndInGame(subject)) { return; } //just in case
	
	if(ClientIsInfected[subject])
	{
		ClientIsInfected[subject] = false;
		ClientIsInfectedTime[subject] = 0;
		PrintHintText(subject,"%T", "l4d_storm1", subject);
	}
}

public Action:Event_Hurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	new attacker = GetEventInt(event, "attacker");
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	if (victim == 0 ||
		!IsClientInGame(victim) || 
		GetClientTeam(victim) != 2
		) return;
	
	if( !attacker && IsCommonInfected(GetEventInt(event, "attackerentid")))//common
	{
		new random = GetRandomInt(1, 100);
		if (random <= 30) //30%被感染
			ClientGetInfected(0,victim);
		return;
	}

	attacker = GetClientOfUserId(attacker);
	if (attacker == 0 && IsWitch(GetEventInt(event, "attackerentid")))//witch
	{
		//100%被感染
		ClientGetInfected(0,victim);
		return;
	}
	
	if(attacker <= MaxClients && attacker >= 1 && IsClientInGame(attacker) && GetClientTeam(attacker) == 3 && GetEntProp(attacker, Prop_Send, "m_zombieClass") != 5)// not tank SI
	{
		new random = GetRandomInt(1, 100);
		if (random <= 60) //60%被感染
			ClientGetInfected(0,victim);
		return;
	}
}

ClientGetInfected(attacker,victim)
{
	
	ClientIsInfectedTime[victim]++;
	PrintHintText(victim,"%T","l4d_storm2", victim, ClientIsInfectedTime[victim]);
	if(ClientIsInfected[victim])
		return;
	ClientIsInfected[victim] = true;
	
	new Handle:dataPack;
	CreateDataTimer(INFECTION_INTERVAL, TimerInfection, dataPack,TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	WritePackCell(dataPack, victim);
	WritePackCell(dataPack, attacker);
}

public Action:TimerInfection(Handle:timer, Handle:dataPack)
{
	ResetPack(dataPack);
	new client = ReadPackCell(dataPack);
	new attacker = ReadPackCell(dataPack);
	
	if(!IsClientInGame(client) || GetClientTeam(client)!=2 || !IsPlayerAlive(client) || !ClientIsInfected[client])
	{
		ClientIsInfected[client] = false;
		return Plugin_Stop;
	}
	PrintHintText(client,"%T","l4d_storm2",client,ClientIsInfectedTime[client]);
	if(GetEntProp(client, Prop_Send, "m_isIncapacitated"))
	{
		return Plugin_Continue;
	}

	decl Float:victimPos[3], String:strDamage[16], String:strDamageTarget[16];
	
	GetClientEyePosition(client, victimPos);
	IntToString(INFECTION_INTERVAL_DMG*ClientIsInfectedTime[client], strDamage, sizeof(strDamage));
	Format(strDamageTarget, sizeof(strDamageTarget), "hurtme%d", client);
	
	new entPointHurt = CreateEntityByName("point_hurt");
	if(!entPointHurt) return Plugin_Stop;

	// Config, create point_hurt
	DispatchKeyValue(client, "targetname", strDamageTarget);
	DispatchKeyValue(entPointHurt, "DamageTarget", strDamageTarget);
	DispatchKeyValue(entPointHurt, "Damage", strDamage);
	DispatchKeyValue(entPointHurt, "DamageType", "0"); // DMG_GENERIC
	DispatchSpawn(entPointHurt);
	
	// Teleport, activate point_hurt
	TeleportEntity(entPointHurt, victimPos, NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(entPointHurt, "Hurt", (attacker && attacker < 32 && IsClientInGame(attacker)) ? attacker : -1);
	
	// Config, delete point_hurt
	DispatchKeyValue(entPointHurt, "classname", "point_hurt");
	DispatchKeyValue(client, "targetname", "null");
	RemoveEdict(entPointHurt);
	
	return Plugin_Continue;
}

public Action:PillsUsed_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	HealEntityOverTime(client, 0.5, 2, 80);
	if(ClientIsInfected[client])
	{
		ClientIsInfectedTime[client] = (ClientIsInfectedTime[client]-3)<=0 ? 0: ClientIsInfectedTime[client]-3;
		if(ClientIsInfectedTime[client] == 0)
		{
			PrintHintText(client,"%T", "l4d_storm1", client);
			ClientIsInfected[client] = false;
		}
		else
			PrintHintText(client,"%T", "l4d_storm3", client);
	}
}

public Action:OnBotSwap(Handle:event, const String:name[], bool:dontBroadcast) 
{	
	new bot = GetClientOfUserId(GetEventInt(event, "bot"));
	new player = GetClientOfUserId(GetEventInt(event, "player"));
	if (IsClientIndex(bot) && IsClientIndex(player)) 
	{
		if (StrEqual(name, "player_bot_replace")) 
		{
			ClientIsInfected[bot] = ClientIsInfected[player];
			ClientIsInfectedTime[bot] = ClientIsInfectedTime[player];
			ClientIsInfected[player] = false;
			ClientIsInfectedTime[player] = 0;
			if(ClientIsInfected[bot])
			{
				new Handle:dataPack;
				CreateDataTimer(INFECTION_INTERVAL, TimerInfection, dataPack,TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
				WritePackCell(dataPack, bot);
				WritePackCell(dataPack, 0);
			}
			
		}
		else 
		{
			ClientIsInfected[player] = ClientIsInfected[bot];
			ClientIsInfectedTime[player] = ClientIsInfectedTime[bot];
			ClientIsInfected[bot] = false;
			ClientIsInfectedTime[bot] = 0;
			if(ClientIsInfected[player])
			{
				new Handle:dataPack;
				CreateDataTimer(INFECTION_INTERVAL, TimerInfection, dataPack,TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
				WritePackCell(dataPack, player);
				WritePackCell(dataPack, 0);
			}
		}
	}
	return Plugin_Continue;
}

public OnPluginEnd()
{
	ResetPlugin();
	PatchAddress(false);
}

public OnMapStart()
{
	if( g_iLateLoad )
	{
		g_iStarted = 2;
		g_iLateLoad = 0;
	}

	if( g_iStarted == 0 && g_iPlayerSpawn == 1 && g_iRoundStart == 1 )
	{
		LoadStorm();
		g_iReset = 0;
	}

	if( g_iStarted == 0 )
		g_iStarted = 1;
	else if( g_iStarted == 1 )
		g_iStarted = 2;

	g_iLaserMaterial = PrecacheModel("materials/sprites/laserbeam.vmt");
	g_iHaloMaterial = PrecacheModel("materials/sprites/halo01.vmt");
	PrecacheModel(MODEL_BOUNDING, true);

	PrecacheSound(SOUND_RAIN1, true);
	PrecacheSound(SOUND_RAIN2, true);
	PrecacheSound(SOUND_RAIN3, true);

	//PrecacheSound(SOUND_STORM1, true);
	//PrecacheSound(SOUND_STORM2, true);
	//PrecacheSound(SOUND_STORM3, true);
	//PrecacheSound(SOUND_STORM4, true);
	//PrecacheSound(SOUND_STORM5, true);
	//PrecacheSound(SOUND_STORM6, true);
	//PrecacheSound(SOUND_STORM7, true);
	PrecacheSound(SOUND_STORM8, true);
	PrecacheSound(SOUND_STORM9, true);
	PrecacheSound(SOUND_STORM10, true);
	PrecacheSound(SOUND_STORM11, true);
	PrecacheSound(SOUND_STORM12, true);
	PrecacheSound(SOUND_STORM13, true);
	PrecacheSound(SOUND_STORM14, true);
	PrecacheSound(SOUND_STORM15, true);
	PrecacheSound(SOUND_STORM16, true);

	PrecacheSound(SOUND_WIND1, true);
	PrecacheSound(SOUND_WIND2, true);
	PrecacheSound(SOUND_WIND3, true);
	PrecacheSound(SOUND_WIND4, true);

	PrecacheParticle(PARTICLE_FIRE);
	PrecacheParticle(PARTICLE_FOG);
	PrecacheParticle(PARTICLE_GLOW);
	PrecacheParticle(PARTICLE_LIGHT1);
	PrecacheParticle(PARTICLE_LIGHT2);
	
	for(new i=1;i<=MaxClients;i++)
	{
		Allow[i] = false;
	}
}

public OnMapEnd()
{
	g_iReset = 0;
	ResetPlugin();
	g_iStarted = 0;
}

ResetPlugin()
{
	ChangeLightStyle("m");
//	SetBackground(true);
	StopAmbientSound();

	for( new i = 1; i <= MAXPLAYERS; i++ )
		g_iLightStyle[i] = 0;

	if( g_iReset == 0 )
	{
		g_iChance = 0;
		g_iRandom = 0;
	}
	else
		g_iReset = 0;

	g_bLoaded = false;
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
	g_iTriggerCount = 0;
	g_iStormState = STATE_OFF;

	if( g_iSunSaved != -1 )
	{
		ToggleEnvSun(g_iSunSaved);
		g_iSunSaved = -1;
	}

	if( IsValidEntRef(g_iLogicIn) )
	{
		AcceptEntityInput(g_iLogicIn, "CancelPending");
		AcceptEntityInput(g_iLogicIn, "Kill");
	}
	g_iLogicIn = 0;

	if( IsValidEntRef(g_iLogicOut) )
	{
		AcceptEntityInput(g_iLogicOut, "CancelPending");
		AcceptEntityInput(g_iLogicOut, "Kill");
	}
	g_iLogicOut = 0;

	ResetFog();
	ResetVars();

	if( g_hTmrEndStorm != INVALID_HANDLE )
	{
		CloseHandle(g_hTmrEndStorm);
		g_hTmrEndStorm = INVALID_HANDLE;
	}

	if( g_hTmrTimeout != INVALID_HANDLE )
	{
		CloseHandle(g_hTmrTimeout);
		g_hTmrTimeout = INVALID_HANDLE;
	}

	if( g_hTmrTrigger != INVALID_HANDLE )
	{
		CloseHandle(g_hTmrTrigger);
		g_hTmrTrigger = INVALID_HANDLE;
	}

	if( g_hTmrBeam != INVALID_HANDLE )
	{
		CloseHandle(g_hTmrBeam);
		g_hTmrBeam = INVALID_HANDLE;
	}

	for( new i = 0; i < MAX_TRIGGERS; i++ )
	{
		if( IsValidEntRef(g_iTriggers[i]) )
		{
			AcceptEntityInput(g_iTriggers[i], "Kill");
			g_iTriggers[i] = 0;
		}
	}

	for( new i = 0; i < MAX_RAIN; i++ )
	{
		if( IsValidEntRef(g_iRains[i]) )
		{
			AcceptEntityInput(g_iRains[i], "Kill");
			g_iRains[i] = 0;
		}
	}

	if( IsValidEntRef(g_iFogVolume) )
		AcceptEntityInput(g_iFogVolume, "Kill");
	g_iFogVolume = 0;

	if( IsValidEntRef(g_iPostProcess) )
		AcceptEntityInput(g_iPostProcess, "Kill");
	g_iPostProcess = 0;

	if( IsValidEntRef(g_iLogicDirector) )
		AcceptEntityInput(g_iLogicDirector, "Kill");
	g_iLogicDirector = 0;

	if( IsValidEntRef(g_iStormLayer) )
		AcceptEntityInput(g_iStormLayer, "Kill");
	g_iStormLayer = 0;

	if( IsValidEntRef(g_iVoip) )
		AcceptEntityInput(g_iVoip, "Kill");
	g_iVoip = 0;

	if( IsValidEntRef(g_iVoipIn) )
		AcceptEntityInput(g_iVoipIn, "Kill");
	g_iVoipIn = 0;

	if( IsValidEntRef(g_iVoipOut) )
		AcceptEntityInput(g_iVoipOut, "Kill");
	g_iVoipOut = 0;

	if( IsValidEntRef(g_iPointCmd) )
		AcceptEntityInput(g_iPointCmd, "Kill");
	g_iPointCmd = 0;

	if( IsValidEntRef(g_iParticleFog) )
		AcceptEntityInput(g_iParticleFog, "Kill");
	g_iParticleFog = 0;

	if( IsValidEntRef(g_iLight) )
		AcceptEntityInput(g_iLight, "Kill");
	g_iLight = 0;

	if( IsValidEntRef(g_iWind) )
		AcceptEntityInput(g_iWind, "Kill");
	g_iWind = 0;
}

ResetVars()
{
	strcopy(g_sSkyBox, sizeof(g_sSkyBox), "");
	strcopy(g_sCfgFogColor, sizeof(g_sCfgFogColor), "");
	strcopy(g_sCfgLightStyle, sizeof(g_sCfgLightStyle), "");
	g_iCfgFogBlend = -1;
	g_iCfgFogIdle =	0;
	g_iCfgFogStorm = 0;
	g_fCfgFogOpaqueIdle = 0.0;
	g_fCfgFogOpaqueStorm = 0.0;
	g_iCfgFogZIdle = 0;
	g_iCfgFogZStorm = 0;
	g_iCfgClouds = 0;
	g_iCfgLight = 0;
	g_iCfgLightDmg = 0;
	g_iCfgLightFlash = 0;
	g_iCfgRain = 0;
	g_iCfgRainIdle = 0;
	g_iCfgRainStorm = 0;
	g_iCfgWind = 0;
	g_iCfgForever = 0;
	g_iCfgTimeout = 0;
	g_iCfgTimeMax = 0;
	g_iCfgTimeMin = 0;
	g_iCfgTimer = 0;
	g_iCfgFinale = 0;
	g_iCfgHorde = 0;
	g_iCfgPanic = 0;
	g_iCfgTank = 0;
	g_iCfgTankDeath = 0;
	g_iCfgWitch = 0;
	g_iCfgWitchHead = 0;
	g_iCfgWitchAlert = 0;
}

ResetFog()
{
	if( g_iFogOn == 0 )
		return;
	g_iFogOn = 0;

	if( IsValidEntRef(g_iFog) )
	{
		AcceptEntityInput(g_iFog, "Kill");
		g_iFog  = 0;
	}

	new entity = -1;
	while( (entity = FindEntityByClassname(entity, "env_fog_controller")) != INVALID_ENT_REFERENCE )
	{
		for( new i = 0; i < MAX_FOG; i++ )
		{
			if( EntIndexToEntRef(entity) == g_iFogStolen[i][0] )
			{
				decl String:temps[64];
				GetEntPropString(entity, Prop_Data,"m_iName", temps, 64);

				if( g_fFogStolen[i][1] == 0 )
					g_fFogStolen[i][1] = 10000.0;

				SetEntProp(entity, Prop_Data, "m_nNextThinkTick", -1);
	
				DispatchKeyValue(entity, "targetname", g_sFogStolen[i]);
				SetEntProp(entity, Prop_Send, "m_fog.colorPrimary", g_iFogStolen[i][1]);
				SetEntProp(entity, Prop_Send, "m_fog.colorSecondary", g_iFogStolen[i][2]);
				SetEntProp(entity, Prop_Send, "m_fog.colorPrimaryLerpTo", g_iFogStolen[i][3]);
				SetEntProp(entity, Prop_Send, "m_fog.colorSecondaryLerpTo", g_iFogStolen[i][4]);
				SetEntPropFloat(entity, Prop_Send, "m_fog.start", g_fFogStolen[i][0]);
				SetEntPropFloat(entity, Prop_Send, "m_fog.end", g_fFogStolen[i][1]);
				SetEntPropFloat(entity, Prop_Send, "m_fog.maxdensity", g_fFogStolen[i][2]);
				//SetEntPropFloat(entity, Prop_Send, "m_fog.farz", g_fFogStolen[i][3]);
				SetEntPropFloat(entity, Prop_Send, "m_fog.startLerpTo", g_fFogStolen[i][4]);
				SetEntPropFloat(entity, Prop_Send, "m_fog.endLerpTo", g_fFogStolen[i][5]);
				SetEntPropFloat(entity, Prop_Send, "m_fog.maxdensityLerpTo", g_fFogStolen[i][6]);
				SetEntPropFloat(entity, Prop_Send, "m_fog.duration", g_fFogStolen[i][7]);
				SetEntPropFloat(entity, Prop_Send, "m_fog.lerptime", 1.0);

				strcopy(g_sFogStolen[i], 64, "");
				g_iFogStolen[i][0] = 0;
				g_iFogStolen[i][1] = 0;
				g_iFogStolen[i][2] = 0;
				g_iFogStolen[i][3] = 0;
				g_iFogStolen[i][4] = 0;
				g_fFogStolen[i][0] = 0.0;
				g_fFogStolen[i][1] = 0.0;
				g_fFogStolen[i][2] = 0.0;
				g_fFogStolen[i][3] = 0.0;
				g_fFogStolen[i][4] = 0.0;
				g_fFogStolen[i][5] = 0.0;
				g_fFogStolen[i][6] = 0.0;
				g_fFogStolen[i][7] = 0.0;
				g_fFogStolen[i][8] = 0.0;
				break;
			}
		}
	}
}



// ====================================================================================================
//					EVENTS
// ====================================================================================================
public OnClientPutInServer(client)
{
	ClientIsInfected[client] = false;
	ClientIsInfectedTime[client] = 0;
	if( g_iCfgWind )
	{
		if( g_iCfgWind == 1 )		EmitSoundToClient(client, SOUND_WIND1);
		else if( g_iCfgWind == 2 )	EmitSoundToClient(client, SOUND_WIND2, _, _, 43);
		else if( g_iCfgWind == 3 )	EmitSoundToClient(client, SOUND_WIND3, _, _, 43);
		else if( g_iCfgWind == 4 )	EmitSoundToClient(client, SOUND_WIND4, _, _, 42);
	}

	if( IsValidEntRef(g_iSound) )
	{
		SetVariantInt(10);
		AcceptEntityInput(g_iSound, "Volume");
		CreateTimer(0.1, TimerPlaySound, GetClientUserId(client));
	}
}

public Action:TimerPlaySound(Handle:timer, any:client)
{
	client = GetClientOfUserId(client);
	if( client )
	{
		if( IsValidEntRef(g_iSound) )
		{
			SetVariantInt(10);
			AcceptEntityInput(g_iSound, "Volume");
		}
	}
}

HookEvents()
{
//	HookEvent("finale_vehicle_incoming",	Event_FinaleIn,			EventHookMode_PostNoCopy);
	HookEvent("create_panic_event",			Event_PanicAlert,		EventHookMode_PostNoCopy);
	HookEvent("tank_spawn",					Event_TankSpawn,		EventHookMode_PostNoCopy);
	HookEvent("player_death",				Event_PlayerDeath);
	HookEvent("witch_killed",				Event_WitchKilled);
	HookEvent("witch_harasser_set",			Event_WitchAlert,		EventHookMode_PostNoCopy);
	HookEvent("round_end",					Event_RoundEnd,			EventHookMode_PostNoCopy);
	HookEvent("round_start",				Event_RoundStart,		EventHookMode_PostNoCopy);
	HookEvent("player_spawn",				Event_PlayerSpawn);
	
	HookEvent("player_hurt", Event_Hurt, EventHookMode_Post);
	HookEvent("heal_success", Event_heal_success);
	HookEvent("player_bot_replace", OnBotSwap);
	HookEvent("bot_player_replace", OnBotSwap);
	HookEvent("pills_used", PillsUsed_Event,EventHookMode_Pre);
	HookEvent("player_incapacitated_start", Incap_Event);
	HookEvent("player_team", TC_ev_OnTeamChange);
	HookEvent("lunge_pounce", PounceStart);
	HookEvent("pounce_end", PounceEnd);
	HookEvent("revive_begin", BRevive);
	HookEvent("revive_end", ERevive);
	HookEvent("revive_success", SRevive);
}

UnhookEvents()
{
	UnhookEvent("finale_vehicle_incoming",	Event_FinaleIn,			EventHookMode_PostNoCopy);
	UnhookEvent("create_panic_event",		Event_PanicAlert,		EventHookMode_PostNoCopy);
	UnhookEvent("tank_spawn",				Event_TankSpawn,		EventHookMode_PostNoCopy);
	UnhookEvent("player_death",				Event_PlayerDeath);
	UnhookEvent("witch_killed",				Event_WitchKilled);
	UnhookEvent("witch_harasser_set",		Event_WitchAlert,		EventHookMode_PostNoCopy);
	UnhookEvent("round_end",				Event_RoundEnd,			EventHookMode_PostNoCopy);
	UnhookEvent("round_start",				Event_RoundStart,		EventHookMode_PostNoCopy);
	UnhookEvent("player_spawn",				Event_PlayerSpawn);
	
	UnhookEvent("player_hurt", Event_Hurt, EventHookMode_Post);
	UnhookEvent("heal_success", Event_heal_success);
	UnhookEvent("player_bot_replace", OnBotSwap);
	UnhookEvent("bot_player_replace", OnBotSwap);
	UnhookEvent("pills_used", PillsUsed_Event,EventHookMode_Pre);
	UnhookEvent("player_incapacitated_start", Incap_Event);
	UnhookEvent("player_team", TC_ev_OnTeamChange);
	UnhookEvent("lunge_pounce", PounceStart);
	UnhookEvent("pounce_end", PounceEnd);
	UnhookEvent("revive_begin", BRevive);
	UnhookEvent("revive_end", ERevive);
	UnhookEvent("revive_success", SRevive);
}

public Event_FinaleIn(Handle:event, const String:name[], bool:dontBroadcast)
{
	if( g_iCfgForever == 0 && g_iCfgFinale )
		if( GetRandomInt(1, 100) <= g_iCfgFinale )
			StartStorm();
}

public Event_PanicAlert(Handle:event, const String:name[], bool:dontBroadcast)
{
	if( g_iCfgForever == 0 && g_iCfgPanic )
		if( GetRandomInt(1, 100) <= g_iCfgPanic )
			StartStorm();
}

public Event_TankSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	if( g_iCfgForever == 0 && g_iCfgTank )
		if( GetRandomInt(1, 100) <= g_iCfgTank )
			StartStorm();
}

public Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if( g_iCfgForever == 0 && g_iCfgTankDeath )
	{
		if( GetRandomInt(1, 100) <= g_iCfgTankDeath )
		{
			if( client >= 1 && client <= MaxClients && GetEntProp(client, Prop_Send, "m_zombieClass") == 5 )
			{
				StartStorm();
			}
		}
	}
	
	if(client && IsClientInGame(client) && GetClientTeam(client) == 2)
		ClientIsInfectedTime[client] = 0;
}

public Event_WitchKilled(Handle:event, const String:name[], bool:dontBroadcast)
{
	if( g_iCfgForever == 0 && g_iCfgWitch )
		if( g_iCfgWitchHead == 0 || (g_iCfgWitchHead == 1 && GetEventBool(event, "oneshot") == true) )
			if( GetRandomInt(1, 100) <= g_iCfgWitch )
				StartStorm();
}

public Event_WitchAlert(Handle:event, const String:name[], bool:dontBroadcast)
{
	if( g_iCfgForever == 0 && g_iCfgWitchAlert )
		if( GetRandomInt(1, 100) <= g_iCfgWitchAlert )
			StartStorm();
}

public Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_iReset = 1;
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
	g_iStarted = 1;
	StopAmbientSound();	
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	for(new i = 1; i <= MaxClients; i++) 
	{
		ClientIsInfected[i] = false;
		ClientIsInfectedTime[i] = 0;
	}
	new bool:bAllowCvar = GetConVarBool(g_hCvarAllow);
	new bool:bAllowMode = IsAllowedGameMode();
	if(bAllowCvar == true && bAllowMode == true)
	{
		if( g_iStarted != 0 && g_iPlayerSpawn == 1 && g_iRoundStart == 0 )
		{
			LoadStorm();
			g_iReset = 0;
		}
		g_iRoundStart = 1;

		if( g_iStarted == 0 )
			g_iStarted = 1;
		else if( g_iStarted == 1 )
			g_iStarted = 2;
	}
}

public Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	if( g_iPlayerSpawn == 0 && g_iRoundStart == 1 )
	{
		LoadStorm();
		g_iReset = 0;
	}
	g_iPlayerSpawn = 1;

	new userid = GetEventInt(event, "userid");
	new client = GetClientOfUserId(userid);

	if( strcmp(g_sCfgLightStyle, "") != 0 && g_iLightStyle[client] != userid && !IsFakeClient(client) )
	{
		CreateTimer(5.5, TimerLightStyle, userid);
		CreateTimer(8.0, TimerLightStyle, userid);
		if( g_iCvarStyle == 0 )
			CreateTimer(10.0, TimerLightStyle, userid);
	}

	g_iLightStyle[client] = userid;
	
	if (IsValidBoomer(client))
	{
		BoomerAbility_BileFeet(client);
	}	
	if(client && IsClientInGame(client) && GetClientTeam(client) == 2)
		ClientIsInfectedTime[client] = 0;
	
}

static Float:GetAccurateTempHealth(client)
{
	new Float:fHealth = GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
	fHealth -= (GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * GetConVarFloat(cvarTempHealthDecay);
	fHealth = (fHealth < 0.0 )? 0.0 : fHealth;
	
	return fHealth;
}


// ====================================================================================================
//					MAP LIGHT STYLE
// ====================================================================================================
public Action:TimerLightStyle(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if( client != 0 && !IsFakeClient(client) )
	{
		g_iLightStyle[client] = userid;
		ChangeLightStyle(g_sCfgLightStyle, client);
	}
}

ChangeLightStyle(String:lightstring[], client = 0)
{
	if( g_iStarted == 2 && strcmp(lightstring, "") != 0 )
	{
		SetLightStyle(0, lightstring);

		// This refreshes and updates the entire map with the new light style.
		new entity = CreateEntityByName("light_dynamic");

		DispatchKeyValue(entity, "_light", "0 0 0 0");
		DispatchKeyValue(entity, "brightness", "0");
		DispatchKeyValue(entity, "style", "13");
		DispatchKeyValue(entity, "distance", "19999");
		DispatchSpawn(entity);

		if( client )
		{
			SetEntProp(entity, Prop_Data, "m_iHammerID", client);
			SDKHook(entity, SDKHook_SetTransmit, Hook_SetTransmitLight);
		}

		if( g_iCvarStyle == 0 )
		{
			decl Float:vPos[3], Float:vMins[3], Float:vMaxs[3];
			GetEntPropVector(0, Prop_Data, "m_WorldMins", vMins);
			GetEntPropVector(0, Prop_Data, "m_WorldMaxs", vMaxs);
			vPos[0] = (vMins[0] + vMaxs[0]) / 2;
			vPos[1] = (vMins[1] + vMaxs[1]) / 2;
			vPos[2] = vMaxs[2] + 2000.0;
			TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);

			AcceptEntityInput(entity, "TurnOn");
			SetVariantString("OnUser1 !self:TurnOff::0.2:-1");
			AcceptEntityInput(entity, "AddOutput");
			SetVariantString("OnUser1 !self:TurnOff::0.3:-1");
			AcceptEntityInput(entity, "AddOutput");
			SetVariantString("OnUser1 !self:TurnOff::0.4:-1");
			AcceptEntityInput(entity, "AddOutput");
			SetVariantString("OnUser1 !self:Kill::0.5:-1");
			AcceptEntityInput(entity, "AddOutput");
			AcceptEntityInput(entity, "FireUser1");
		}
		else
		{
			if( g_iCvarStyle == 1 )
			{
				SetVariantString("OnUser1 !self:TurnOff::0.7:-1");
				AcceptEntityInput(entity, "AddOutput");
				SetVariantString("OnUser1 !self:TurnOff::0.8:-1");
				AcceptEntityInput(entity, "AddOutput");
				SetVariantString("OnUser1 !self:Kill::1.0:-1");
				AcceptEntityInput(entity, "AddOutput");
				AcceptEntityInput(entity, "FireUser1");

				SetVariantString("OnUser3 !self:FireUser2::0.05:-1");
				AcceptEntityInput(entity, "AddOutput");
				SetVariantString("OnUser3 !self:FireUser2::0.10:-1");
				AcceptEntityInput(entity, "AddOutput");
				SetVariantString("OnUser3 !self:FireUser2::0.15:-1");
				AcceptEntityInput(entity, "AddOutput");
				SetVariantString("OnUser3 !self:FireUser2::0.20:-1");
				AcceptEntityInput(entity, "AddOutput");
				SetVariantString("OnUser3 !self:FireUser2::0.25:-1");
				AcceptEntityInput(entity, "AddOutput");
				SetVariantString("OnUser3 !self:FireUser2::0.30:-1");
				AcceptEntityInput(entity, "AddOutput");
				SetVariantString("OnUser3 !self:FireUser2::0.35:-1");
				AcceptEntityInput(entity, "AddOutput");
				SetVariantString("OnUser3 !self:FireUser2::0.40:-1");
				AcceptEntityInput(entity, "AddOutput");
				SetVariantString("OnUser3 !self:FireUser2::0.45:-1");
				AcceptEntityInput(entity, "AddOutput");
			}
			else
			{
				SetVariantString("OnUser1 !self:TurnOff::1.2:-1");
				AcceptEntityInput(entity, "AddOutput");
				SetVariantString("OnUser1 !self:TurnOff::1.3:-1");
				AcceptEntityInput(entity, "AddOutput");
				SetVariantString("OnUser1 !self:Kill::1.5:-1");
				AcceptEntityInput(entity, "AddOutput");
				AcceptEntityInput(entity, "FireUser1");

				SetVariantString("OnUser3 !self:FireUser2::0.1:-1");
				AcceptEntityInput(entity, "AddOutput");
				SetVariantString("OnUser3 !self:FireUser2::0.2:-1");
				AcceptEntityInput(entity, "AddOutput");
				SetVariantString("OnUser3 !self:FireUser2::0.3:-1");
				AcceptEntityInput(entity, "AddOutput");
				SetVariantString("OnUser3 !self:FireUser2::0.4:-1");
				AcceptEntityInput(entity, "AddOutput");
				SetVariantString("OnUser3 !self:FireUser2::0.5:-1");
				AcceptEntityInput(entity, "AddOutput");
				SetVariantString("OnUser3 !self:FireUser2::0.6:-1");
				AcceptEntityInput(entity, "AddOutput");
				SetVariantString("OnUser3 !self:FireUser2::0.7:-1");
				AcceptEntityInput(entity, "AddOutput");
				SetVariantString("OnUser3 !self:FireUser2::0.8:-1");
				AcceptEntityInput(entity, "AddOutput");
				SetVariantString("OnUser3 !self:FireUser2::0.9:-1");
				AcceptEntityInput(entity, "AddOutput");
			}

			SetEntProp(entity, Prop_Data, "m_iHealth", 1);
			HookSingleEntityOutput(entity, "OnUser2", OnUser2);
			AcceptEntityInput(entity, "FireUser3");
		}
	}
}

public Action:Hook_SetTransmitLight(entity, client)
{
	if( GetEntProp(entity, Prop_Data, "m_iHammerID") == client )
		return Plugin_Continue;
	return Plugin_Handled;
}

public OnUser2(const String:output[], entity, activator, Float:delay)
{
	new corner = GetEntProp(entity, Prop_Data, "m_iHealth");
	SetEntProp(entity, Prop_Data, "m_iHealth", corner + 1);


	decl Float:vPos[3], Float:vMins[3], Float:vMaxs[3];
	GetEntPropVector(0, Prop_Data, "m_WorldMins", vMins);
	GetEntPropVector(0, Prop_Data, "m_WorldMaxs", vMaxs);

	if( corner == 1 )
	{
		AcceptEntityInput(entity, "TurnOff");
		vPos[0] = (vMins[0] + vMaxs[0]) / 2;
		vPos[1] = (vMins[1] + vMaxs[1]) / 2;
		vPos[2] = vMaxs[2] += 2000.0;
		TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);
		AcceptEntityInput(entity, "TurnOn");
	}
	else if( corner == 2 )
	{
		AcceptEntityInput(entity, "TurnOff");
		vPos[0] = vMins[0];
		vPos[1] = vMins[1];
		vPos[2] = vMins[2];
		TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);
		AcceptEntityInput(entity, "TurnOn");
	}
	else if( corner == 3 )
	{
		AcceptEntityInput(entity, "TurnOff");
		vPos[0] = vMaxs[0];
		vPos[1] = vMins[1];
		vPos[2] = vMins[2];
		TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);
		AcceptEntityInput(entity, "TurnOn");
	}
	else if( corner == 4 )
	{
		AcceptEntityInput(entity, "TurnOff");
		vPos[0] = vMins[0];
		vPos[1] = vMaxs[1];
		vPos[2] = vMins[2];
		TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);
		AcceptEntityInput(entity, "TurnOn");
	}
	else if( corner == 5 )
	{
		AcceptEntityInput(entity, "TurnOff");
		vPos[0] = vMins[0];
		vPos[1] = vMins[1];
		vPos[2] = vMaxs[2];
		TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);
		AcceptEntityInput(entity, "TurnOn");
	}
	else if( corner == 6 )
	{
		AcceptEntityInput(entity, "TurnOff");
		vPos[0] = vMaxs[0];
		vPos[1] = vMaxs[1];
		vPos[2] = vMins[2];
		TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);
		AcceptEntityInput(entity, "TurnOn");
	}
	else if( corner == 7 )
	{
		AcceptEntityInput(entity, "TurnOff");
		vPos[0] = vMins[0];
		vPos[1] = vMaxs[1];
		vPos[2] = vMaxs[2];
		TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);
		AcceptEntityInput(entity, "TurnOn");
	}
	else if( corner == 8 )
	{
		AcceptEntityInput(entity, "TurnOff");
		vPos[0] = vMaxs[0];
		vPos[1] = vMins[1];
		vPos[2] = vMaxs[2];
		TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);
		AcceptEntityInput(entity, "TurnOn");
	}

	if( corner == 9 )
	{
		AcceptEntityInput(entity, "TurnOff");
		vPos[0] = vMaxs[0];
		vPos[1] = vMaxs[1];
		vPos[2] = vMaxs[2];
		TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);
		AcceptEntityInput(entity, "TurnOn");

		corner = 0;
		SetVariantString("OnUser4 !self:TurnOff::0.2:-1");
		AcceptEntityInput(entity, "AddOutput");
		SetVariantString("OnUser4 !self:TurnOff::0.3:-1");
		AcceptEntityInput(entity, "AddOutput");
		SetVariantString("OnUser4 !self:Kill::0.5:-1");
		AcceptEntityInput(entity, "AddOutput");
		AcceptEntityInput(entity, "FireUser4");
	}
}

CheckDynamicLightStyle()
{
	if( g_bCvarAllow && strcmp(g_sCfgLightStyle, "") != 0 )
	{
		new entity = -1;
		while( (entity = FindEntityByClassname(entity, "light_dynamic")) != INVALID_ENT_REFERENCE )
		{
			if( GetEntProp(entity, Prop_Send, "m_LightStyle") == 0 )
			{
				SetEntProp(entity, Prop_Send, "m_LightStyle", 13); // Style non-defined, appears just like 0.
			}
		}
	}
}

public OnEntityCreated(entity, const String:classname[])
{
	if( g_bCvarAllow && strcmp(g_sCfgLightStyle, "") != 0 )
	{
		if( strcmp(classname, "light_dynamic") == 0 )
		{
			CreateTimer(0.0, TimerLight, EntIndexToEntRef(entity));
		}
	}
}

public Action:TimerLight(Handle:timer, any:entity)
{
	if( EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE )
	{
		if( GetEntProp(entity, Prop_Send, "m_LightStyle") == 0 )
		{
			SetEntProp(entity, Prop_Send, "m_LightStyle", 13); // Style non-defined, appears just like 0.
		}
	}
}



// ====================================================================================================
//					CVARS
// ====================================================================================================
public OnConfigsExecuted()
{
	GetCvars();
	IsAllowed();
}

GetCvars()
{
	g_iCvarMixer =	GetConVarInt(g_hCvarMixer);
	g_fCvarPost =	GetConVarFloat(g_hCvarPost);
	g_iCvarStyle =	GetConVarInt(g_hCvarStyle);
}

public ConVarChanged_Cvars(Handle:convar, const String:oldValue[], const String:newValue[])
	GetCvars();

public ConVarChanged_Allow(Handle:convar, const String:oldValue[], const String:newValue[])
	IsAllowed();

IsAllowed()
{
	new bool:bAllowCvar = GetConVarBool(g_hCvarAllow);
	new bool:bAllowMode = IsAllowedGameMode();
	GetCvars();

	if( g_bCvarAllow == false && bAllowCvar == true && bAllowMode == true )
	{
		g_bCvarAllow = true;
		g_bLoaded = false;
		HookEvents();
		LoadStorm();
	}

	else if( g_bCvarAllow == true && (bAllowCvar == false || bAllowMode == false) )
	{
		g_bCvarAllow = false;
		ResetPlugin();
		UnhookEvents();
	}
}

static g_iCurrentMode;

bool:IsAllowedGameMode()
{
	if( g_hCvarGameMode == INVALID_HANDLE )
		return false;

	new iCvarModesTog = GetConVarInt(g_hCvarModesTog);
	if( iCvarModesTog != 0 )
	{
		g_iCurrentMode = 0;

		new entity = CreateEntityByName("info_gamemode");
		DispatchSpawn(entity);
		HookSingleEntityOutput(entity, "OnCoop", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnSurvival", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnVersus", OnGamemode, true);
		AcceptEntityInput(entity, "PostSpawnActivate");
		AcceptEntityInput(entity, "Kill");

		if( g_iCurrentMode == 0 )
			return false;

		if( !(iCvarModesTog & g_iCurrentMode) )
			return false;
	}

	decl String:sGameModes[64], String:sGameMode[64];
	GetConVarString(g_hCvarGameMode, sGameMode, sizeof(sGameMode));
	Format(sGameMode, sizeof(sGameMode), ",%s,", sGameMode);

	GetConVarString(g_hCvarModes, sGameModes, sizeof(sGameModes));
	if( strcmp(sGameModes, "") )
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if( StrContains(sGameModes, sGameMode, false) == -1 )
			return false;
	}

	GetConVarString(g_hCvarModesOff, sGameModes, sizeof(sGameModes));
	if( strcmp(sGameModes, "") )
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if( StrContains(sGameModes, sGameMode, false) != -1 )
			return false;
	}

	return true;
}

public OnGamemode(const String:output[], caller, activator, Float:delay)
{
	if( strcmp(output, "OnCoop") == 0 )
		g_iCurrentMode = 1;
	else if( strcmp(output, "OnSurvival") == 0 )
		g_iCurrentMode = 2;
	else if( strcmp(output, "OnVersus") == 0 )
		g_iCurrentMode = 4;
	else if( strcmp(output, "OnScavenge") == 0 )
		g_iCurrentMode = 8;
}



// ====================================================================================================
//					SET SKYBOX
// ====================================================================================================
public ConVarChanged_SkyBox(Handle:convar, const String:oldValue[], const String:newValue[])
{
	SetSkyname();
}

SetSkyname()
{
	if( g_bCvarAllow )
	{
		new Handle:hFile = ConfigOpen();

		if( hFile != INVALID_HANDLE )
		{
			decl String:sMap[64];
			GetCurrentMap(sMap, sizeof(sMap));

			new completed_jump = ConfigJumpA(hFile, sMap);
			if( completed_jump )
			{
				if( ConfigChance(0, hFile) == false )
				{
					CloseHandle(hFile);
					return;
				}

				KvGetString(hFile, "skybox", g_sSkyBox, sizeof(g_sSkyBox));

				if( completed_jump == 1 && ConfigJumpB(hFile, sMap) )
				{
					if( ConfigChance(0, hFile) == false )
					{
						CloseHandle(hFile);
						return;
					}

					KvGetString(hFile, "skybox", g_sSkyBox, sizeof(g_sSkyBox), g_sSkyBox);
				}

				if( strcmp(g_sSkyBox, "") != 0 )
				{
					SetConVarString(g_hCvarSkyName, g_sSkyBox);
				}
			}

			CloseHandle(hFile);
		}
	}
}



// ====================================================================================================
//					SET SKYBOX
// ====================================================================================================
SetBackground(bool:resetsky)
{
	if( g_bLoaded == false )
		return;

	if( IsValidEntRef(g_iSkyCamera) == false )
	{
		g_iSkyCamera = FindEntityByClassname(-1, "sky_camera");
		if( g_iSkyCamera == -1 )
			return;

		g_iSkyCam[0] = GetEntProp(g_iSkyCamera, Prop_Data, "m_skyboxData.fog.colorPrimary");
		g_iSkyCam[1] = GetEntProp(g_iSkyCamera, Prop_Data, "m_skyboxData.fog.colorSecondary");
	}

	if( resetsky == true )
	{
//		CreateSkyCamera(g_iSkyCam[0], g_iSkyCam[1]);
	}
	else
	{
		new Handle:hFile = ConfigOpen();

		if( hFile != INVALID_HANDLE )
		{
			decl String:sMap[64];
			GetCurrentMap(sMap, sizeof(sMap));

			new completed_jump = ConfigJumpA(hFile, sMap);
			if( completed_jump )
			{
				if( ConfigChance(0, hFile) == false )
				{
					CloseHandle(hFile);
					return;
				}

				decl String:sBack[12];
				KvGetString(hFile, "background", sBack, sizeof(sBack));

				if( completed_jump == 1 && ConfigJumpB(hFile, sMap) )
				{
					if( ConfigChance(0, hFile) == false )
					{
						CloseHandle(hFile);
						return;
					}

					KvGetString(hFile, "background", sBack, sizeof(sBack), sBack);
				}

				g_iCfgBackground = GetColor(sBack);
				if( g_iCfgBackground != 0 )
				{
					CreateSkyCamera(g_iCfgBackground, g_iCfgBackground);
				}
			}

			CloseHandle(hFile);
		}
	}
}

CreateSkyCamera(color1, color2)
{
	if( IsValidEntRef(g_iSkyCamera) == true )
	{
		new iSkyCamData[5], Float:fSkyCamData[5];

		iSkyCamData[0] = GetEntProp(g_iSkyCamera, Prop_Data, "m_bUseAngles");
		iSkyCamData[1] = GetEntProp(g_iSkyCamera, Prop_Data, "m_skyboxData.scale");
		//iSkyCamData[2] = GetEntProp(g_iSkyCamera, Prop_Data, "m_skyboxData.bClip3DSkyBoxNearToWorldFar");
		iSkyCamData[3] = GetEntProp(g_iSkyCamera, Prop_Data, "m_skyboxData.fog.blend");
		iSkyCamData[4] = GetEntProp(g_iSkyCamera, Prop_Data, "m_skyboxData.fog.enable");
		fSkyCamData[0] = GetEntPropFloat(g_iSkyCamera, Prop_Data, "m_skyboxData.fog.start");
		fSkyCamData[1] = GetEntPropFloat(g_iSkyCamera, Prop_Data, "m_skyboxData.fog.end");
		fSkyCamData[2] = GetEntPropFloat(g_iSkyCamera, Prop_Data, "m_skyboxData.fog.maxdensity");
		fSkyCamData[3] = GetEntPropFloat(g_iSkyCamera, Prop_Data, "m_skyboxData.fog.HDRColorScale");
		//fSkyCamData[4] = GetEntPropFloat(g_iSkyCamera, Prop_Data, "m_skyboxData.flClip3DSkyBoxNearToWorldFarOffset");

		decl Float:vAng[3], Float:vPos[3];
		GetEntPropVector(g_iSkyCamera, Prop_Data, "m_vecOrigin", vPos);
		GetEntPropVector(g_iSkyCamera, Prop_Data, "m_angRotation", vAng);
		AcceptEntityInput(g_iSkyCamera, "Kill");


		g_iSkyCamera = CreateEntityByName("sky_camera");

		SetEntProp(g_iSkyCamera, Prop_Data, "m_skyboxData.fog.colorPrimary", color1);
		SetEntProp(g_iSkyCamera, Prop_Data, "m_skyboxData.fog.colorSecondary", color2);
		SetEntProp(g_iSkyCamera, Prop_Data, "m_bUseAngles", iSkyCamData[0]);
		SetEntProp(g_iSkyCamera, Prop_Data, "m_skyboxData.scale", iSkyCamData[1]);
		//SetEntProp(g_iSkyCamera, Prop_Data, "m_skyboxData.bClip3DSkyBoxNearToWorldFar", iSkyCamData[2]);
		SetEntProp(g_iSkyCamera, Prop_Data, "m_skyboxData.fog.blend", iSkyCamData[3]);
		SetEntProp(g_iSkyCamera, Prop_Data, "m_skyboxData.fog.enable", iSkyCamData[4]);
		SetEntPropFloat(g_iSkyCamera, Prop_Data, "m_skyboxData.fog.start", fSkyCamData[0]);
		SetEntPropFloat(g_iSkyCamera, Prop_Data, "m_skyboxData.fog.end", fSkyCamData[1]);
		SetEntPropFloat(g_iSkyCamera, Prop_Data, "m_skyboxData.fog.maxdensity", fSkyCamData[2]);
		SetEntPropFloat(g_iSkyCamera, Prop_Data, "m_skyboxData.fog.HDRColorScale", fSkyCamData[3]);
		//SetEntPropFloat(g_iSkyCamera, Prop_Data, "m_skyboxData.flClip3DSkyBoxNearToWorldFarOffset", fSkyCamData[4]);

		TeleportEntity(g_iSkyCamera, vPos, vAng, NULL_VECTOR);
		DispatchSpawn(g_iSkyCamera);
		AcceptEntityInput(g_iSkyCamera, "ActivateSkybox");
	}
}



// ====================================================================================================
//					COMMANDS
// ====================================================================================================
public Action:CmdStormMenu(client, args)
{
	if( !client )
	{
		ReplyToCommand(client, "[Storm] Commands may only be used in-game on a dedicated server.");
		return Plugin_Handled;
	}

	ShowMenuMain(client);
	return Plugin_Handled;
}

public Action:CmdStormStart(client, args)
{
	StartStorm();
	return Plugin_Handled;
}

public Action:CmdStormStop(client, args)
{
	StopStorm();
	return Plugin_Handled;
}

public Action:CmdStormRefresh(client, args)
{
	ResetPlugin();
	LoadStorm();
	return Plugin_Handled;
}

public Action:CmdStormReset(client, args)
{
	ResetPlugin();
	return Plugin_Handled;
}

public Action:CmdStormConfig(client, args)
{
	PrintToChat(client, "%s Config: {%s}.", CHAT_TAG, g_sConfigSection);
	return Plugin_Handled;
}

public Action:CmdLightning(client, args)
{
	if( !client )
	{
		ReplyToCommand(client, "[Storm] Commands may only be used in-game on a dedicated server.");
		return Plugin_Handled;
	}

	new stormstate = g_iStormState;
	g_iStormState = STATE_OFF;
	DisplayLightning(client);
	g_iStormState = stormstate;
	return Plugin_Handled;
}

public Action:CmdBackground(client, args)
{
	if( !client )
	{
		ReplyToCommand(client, "[Storm] Commands may only be used in-game on a dedicated server.");
	}
	else if( args == 0 )
	{
		if( IsValidEntRef(g_iSkyCamera) == true )
		{
			CreateSkyCamera(g_iSkyCam[0], g_iSkyCam[1]);
			PrintToChat(client, "%sBackground color has been reset.", CHAT_TAG);
		}
		else
		{
			PrintToChat(client, "%sBackground error: Cannot find the \x01sky_camera\x06 entity. Was never created or has been deleted.", CHAT_TAG);
		}
	}
	else if( args == 3 )
	{
		if( IsValidEntRef(g_iSkyCamera) == false )
		{
			g_iSkyCamera = FindEntityByClassname(-1, "sky_camera");
			if( g_iSkyCamera == -1 )
			{
				PrintToChat(client, "%sBackground error: Cannot find the \x01sky_camera\x06 entity. Was never created or has been deleted.", CHAT_TAG);
				return Plugin_Handled;
			}

			g_iSkyCam[0] = GetEntProp(g_iSkyCamera, Prop_Data, "m_skyboxData.fog.colorPrimary");
			g_iSkyCam[1] = GetEntProp(g_iSkyCamera, Prop_Data, "m_skyboxData.fog.colorSecondary");
		}

		decl String:sTemp[12];
		GetCmdArgString(sTemp, sizeof(sTemp));
		new color = GetColor(sTemp);
		CreateSkyCamera(color, color);
	}
	else
	{
		PrintToChat(client, "%sUsage: sm_background <no args = reset, or string from a-z.", CHAT_TAG);
	}
	return Plugin_Handled;
}

public Action:CmdMapLight(client, args)
{
	if( !client )
	{
		ReplyToCommand(client, "[Storm] Commands may only be used in-game on a dedicated server.");
		return Plugin_Handled;
	}

	if( strcmp(g_sCfgLightStyle, "") == 0 )
	{
		strcopy(g_sCfgLightStyle, sizeof(g_sCfgLightStyle), "m");
		CheckDynamicLightStyle();
	}

	if( args == 0 )
	{
		ChangeLightStyle("m");
		PrintToChat(client, "%sMap light style has been reset.", CHAT_TAG);
	}
	else if( args == 1 )
	{
		decl String:sTemp[64];
		GetCmdArg(1, sTemp, sizeof(sTemp));
		PrintToChat(client, "%sMap light style has been set to '\x03%s\x01'.", CHAT_TAG, sTemp);
		ChangeLightStyle(sTemp);
	}
	else
	{
		PrintToChat(client, "%sUsage: sm_maplight <no args = reset, or string from a-z.", CHAT_TAG);
	}
	return Plugin_Handled;
}

public Action:CmdFarZ(client, args)
{
	if( args == 1)
	{
		new entity = -1;
		decl String:sTemp[16];
		GetCmdArg(1, sTemp, sizeof(sTemp));

		while( (entity = FindEntityByClassname(entity, "env_fog_controller")) != INVALID_ENT_REFERENCE )
		{
			g_fFogStolen[0][3] = GetEntPropFloat(entity, Prop_Send, "m_fog.farz");
			SetVariantString(sTemp);
			AcceptEntityInput(entity, "SetFarZ");
		}
	}
	else
	{
		new entity = -1;
		while( (entity = FindEntityByClassname(entity, "env_fog_controller")) != INVALID_ENT_REFERENCE )
		{
			SetEntPropFloat(entity, Prop_Send, "m_fog.farz", g_fFogStolen[0][3]);
		}
		PrintToChat(client, "%sFarz has been reset.", CHAT_TAG);
		PrintToChat(client, "%sUsage: sm_farz <distance in game units>.", CHAT_TAG);
	}
	return Plugin_Handled;
}

public Action:CmdFog(client, args)
{
	if( !client )
	{
		ReplyToCommand(client, "[Storm] Commands may only be used in-game on a dedicated server.");
		return Plugin_Handled;
	}

	if( g_iFogOn == 0 )
	{
		CreateFog();
		PrintToChat(client, "%sFog has been turned '\x03On\x05'", CHAT_TAG);
	}
	else if( args == 0 )
	{
		ResetFog();
		PrintToChat(client, "%sFog has been turned '\x03Off\x05'", CHAT_TAG);
	}

	if( args == 3 )
	{
		decl String:sTemp[12];
		GetCmdArgString(sTemp, sizeof(sTemp));

		new entity = -1;
		while( (entity = FindEntityByClassname(entity, "env_fog_controller")) != INVALID_ENT_REFERENCE )
		{
			DispatchKeyValue(entity, "fogcolor", sTemp);
			DispatchKeyValue(entity, "fogcolor2", sTemp);

			SetVariantString(sTemp);
			AcceptEntityInput(entity, "SetColorLerpTo");
		}
		CreateFog();
	}
	if( args != 3 )
	{
		PrintToChat(client, "%sUsage: sm_fog <r> <g> <b> (values 0-255, eg: sm_fog 255 0 0).", CHAT_TAG);
		return Plugin_Handled;
	}
	return Plugin_Handled;
}

public Action:CmdRain(client, args)
{
	if( !client )
	{
		ReplyToCommand(client, "[Storm] Commands may only be used in-game on a dedicated server.");
		return Plugin_Handled;
	}

	new count;
	for( new i = 0; i < MAX_RAIN; i++ )
		if( IsValidEntRef(g_iRains[i]) )
			count++;

	if( count != 0 )
	{
		for( new i = 0; i < MAX_RAIN; i++ )
		{
			if( IsValidEntRef(g_iRains[i]) )
			{
				AcceptEntityInput(g_iRains[i], "Kill");
				g_iRains[i] = 0;
			}
		}

		if( IsValidEntRef(g_iSnow) )
		{
			AcceptEntityInput(g_iSnow, "Kill");
			g_iSnow = 0;
			CreateSnow();
		}
		StopAmbientSound();
		if(g_iCfgWind)
			PlaySoundWind();
		PrintToChat(client, "%sRain has been turned '\x03Off\x05'", CHAT_TAG);
		g_iCfgRain=0;
	}
	else
	{
		g_iCfgRain = 1;
		if( g_iCfgRain == 0 )
		{
			g_iCfgRain = 1;
			CreateRain();
			PlaySoundRain();
			g_iCfgRain = 0;
		}
		else
		{
			PlaySoundRain();
			CreateRain();
		}
		PrintToChat(client, "%sRain has been turned '\x03On\x05'", CHAT_TAG);
	}
	return Plugin_Handled;
}

public Action:CmdSnow(client, args)
{
	if( !client )
	{
		ReplyToCommand(client, "[Storm] Commands may only be used in-game on a dedicated server.");
		return Plugin_Handled;
	}

	if( IsValidEntRef(g_iSnow) )
	{
		AcceptEntityInput(g_iSnow, "Kill");
		g_iSnow = 0;

		PrintToChat(client, "%sSnow has been turned '\x03Off\x05'", CHAT_TAG);
	}
	else
	{
		if( g_iCfgSnow == 0 )
		{
			g_iCfgSnow = 1;
			CreateSnow();
			g_iCfgSnow = 0;
		}
		else
		{
			CreateSnow();
		}
		PrintToChat(client, "%sSnow has been turned '\x03On\x05'", CHAT_TAG);
	}
	return Plugin_Handled;
}

public Action:CmdWind(client, args)
{
	if( !client )
	{
		ReplyToCommand(client, "[Storm] Commands may only be used in-game on a dedicated server.");
		return Plugin_Handled;
	}

	if( IsValidEntRef(g_iWind) )
	{
		AcceptEntityInput(g_iWind, "Kill");
		StopAmbientSound();
		if(g_iCfgRain)
			PlaySoundRain();
		g_iWind = 0;
		PrintToChat(client, "%sWind has been turned '\x03Off\x05'", CHAT_TAG);
		g_iCfgWind = 0;
	}
	else
	{
		g_iCfgWind = 1;
		PlaySoundWind();
		CreateWind();
		PrintToChat(client, "%sWind has been turned '\x03On\x05'", CHAT_TAG);
	}
	return Plugin_Handled;
}

public Action:CmdSun(client, args)
{
	if( !client )
	{
		ReplyToCommand(client, "[Storm] Commands may only be used in-game on a dedicated server.");
		return Plugin_Handled;
	}

	if( args == 0 )
	{
		ToggleEnvSun(g_iSunSaved);
		return Plugin_Handled;
	}

	if( args == 1 )
	{
		ToggleEnvSun(0);
		return Plugin_Handled;
	}

	if( args != 3 )
	{
		PrintToChat(client, "%sUsage: sm_sun <r> <g> <b> (values 0-255, eg: sm_sun 255 0 0).", CHAT_TAG);
		return Plugin_Handled;
	}

	decl String:sTemp[12];
	GetCmdArgString(sTemp, sizeof(sTemp));
	ToggleEnvSun(GetColor(sTemp));
	return Plugin_Handled;
}

public Action:CmdStormSet(client, args)
{
	if( args == 3 )
	{
		decl String:sTemp[12];
		GetCmdArgString(sTemp, sizeof(sTemp));
		new color = GetColor(sTemp);


		// Background
		if( IsValidEntRef(g_iSkyCamera) == false )
		{
			g_iSkyCamera = FindEntityByClassname(-1, "sky_camera");
			if( g_iSkyCamera == -1 )
			{
				PrintToChat(client, "%sBackground error: Cannot find the \x01sky_camera\x06 entity. Was never created or has been deleted.", CHAT_TAG);
			}

			g_iSkyCam[0] = GetEntProp(g_iSkyCamera, Prop_Data, "m_skyboxData.fog.colorPrimary");
			g_iSkyCam[1] = GetEntProp(g_iSkyCamera, Prop_Data, "m_skyboxData.fog.colorSecondary");
		}

		CreateSkyCamera(color, color);


		// Sun
		ToggleEnvSun(color);


		// Fog
		new entity = -1;
		while( (entity = FindEntityByClassname(entity, "env_fog_controller")) != INVALID_ENT_REFERENCE )
		{
			DispatchKeyValue(entity, "fogcolor", sTemp);
			DispatchKeyValue(entity, "fogcolor2", sTemp);

			SetVariantString(sTemp);
			AcceptEntityInput(entity, "SetColorLerpTo");
		}
	}
	else
	{
		PrintToChat(client, "%sUsage: sm_stormset <r> <g> <b> (values 0-255, eg: sm_stormset 255 0 0).", CHAT_TAG);
	}

	return Plugin_Handled;
}


// ====================================================================================================
//					MENU - MAIN
// ====================================================================================================
ShowMenuMain(client)
{
	DisplayMenu(g_hMenuMain, client, MENU_TIME_FOREVER);
}

public MainMenuHandler(Handle:menu, MenuAction:action, client, index)
{
	if( action == MenuAction_Select )
	{
		if( index == 0 )
		{
			ShowMenuMain(client);

			if( g_iStormState == STATE_OFF )
				LoadStorm(client);
			else
				StartStorm(client);
		}
		else if( index == 1 )
		{
			ShowMenuMain(client);
			StopStorm(client);
		}
		else if( index == 2 )
		{
			ShowMenuMain(client);
			if( IsValidEntRef(g_iLogicOut) )
				AcceptEntityInput(g_iLogicOut, "Trigger");
			ResetPlugin();
		}
		else if( index == 3 )
		{
			ShowMenuTrigger(client);
		}
		else if( index == 4 )
		{
			ShowMenuMain(client);
			ResetPlugin();
			LoadStorm();
		}
	}
}

ShowMenuTrigger(client)
{
	new Handle:hMenu = CreateMenu(TrigMenuHandler);

	AddMenuItem(hMenu, "0", "Create");
	if( g_hTmrBeam == INVALID_HANDLE )
		AddMenuItem(hMenu, "1", "Show");
	else
		AddMenuItem(hMenu, "1", "Hide");
	AddMenuItem(hMenu, "2", "Delete");
	AddMenuItem(hMenu, "3", "VMaxs");
	AddMenuItem(hMenu, "4", "VMins");
	AddMenuItem(hMenu, "5", "Origin");
	AddMenuItem(hMenu, "6", "Go To");

	SetMenuTitle(hMenu, "Storm - Trigger:");
	SetMenuExitBackButton(hMenu, true);

	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public TrigMenuHandler(Handle:menu, MenuAction:action, client, index)
{
	if( action == MenuAction_End )
	{
		CloseHandle(menu);
	}
	else if( action == MenuAction_Cancel )
	{
		if( index == MenuCancel_ExitBack )
			ShowMenuMain(client);
	}
	else if( action == MenuAction_Select )
	{
		decl String:sTemp[4];
		GetMenuItem(menu, index, sTemp, sizeof(sTemp));
		index = StringToInt(sTemp);

		if( index == 0 )
		{
			CreateTrigger(client);
			ShowMenuTrigger(client);
		}
		else if( index == 1 )
		{
			if( g_hTmrBeam != INVALID_HANDLE )
			{
				CloseHandle(g_hTmrBeam);
				g_hTmrBeam = INVALID_HANDLE;
				g_iTriggerSelected = 0;
			}
			ShowMenuTrigList(client, index);
		}
		else if( index == 2 )
		{
			ShowMenuTrigList(client, index);
		}
		else if( index == 3 )
		{
			ShowMenuTrigList(client, index);
		}
		else if( index == 4 )
		{
			ShowMenuTrigList(client, index);
		}
		else if( index == 5 )
		{
			ShowMenuTrigList(client, index);
		}
		else if( index == 6 )
		{
			ShowMenuTrigList(client, index);
		}
	}
}

ShowMenuTrigList(client, index)
{
	g_iTriggerCfgIndex[client] = index;

	new count;
	new Handle:hMenu = CreateMenu(TriggerMenuHandler);
	decl String:sIndex[8], String:sTemp[16];

	for( new i = 0; i < MAX_TRIGGERS; i++ )
	{
		if( IsValidEntRef(g_iTriggers[i]) )
		{
			count++;
			Format(sIndex, sizeof(sIndex), "%d", i);
			Format(sTemp, sizeof(sTemp), "Trigger %d", count);
			AddMenuItem(hMenu, sIndex, sTemp);
		}
	}

	if( index == 1 )
		SetMenuTitle(hMenu, "Storm - Select Trigger To Show:");
	else if( index == 2 )
		SetMenuTitle(hMenu, "Storm - Select Trigger To Delete:");
	else if( index == 3 )
		SetMenuTitle(hMenu, "Storm - Select Trigger - Maxs:");
	else if( index == 4 )
		SetMenuTitle(hMenu, "Storm - Select Trigger - Mins:");
	else if( index == 5 )
		SetMenuTitle(hMenu, "Storm - Select Trigger - Origin:");
	else if( index == 6 )
		SetMenuTitle(hMenu, "Storm - Select Trigger - Go To:");

	SetMenuExitBackButton(hMenu, true);
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public TriggerMenuHandler(Handle:menu, MenuAction:action, client, index)
{
	if( action == MenuAction_End )
	{
		CloseHandle(menu);
	}
	else if( action == MenuAction_Cancel )
	{
		if( index == MenuCancel_ExitBack )
			ShowMenuTrigger(client);
	}
	else if( action == MenuAction_Select )
	{
		new type = g_iTriggerCfgIndex[client];
		decl String:sTemp[4];
		GetMenuItem(menu, index, sTemp, sizeof(sTemp));
		index = StringToInt(sTemp);

		if( type == 1 )
		{
			g_iTriggerSelected = g_iTriggers[index];
			if( IsValidEntRef(g_iTriggerSelected) )
			{
				g_hTmrBeam = CreateTimer(0.1, TimerBeam, _, TIMER_REPEAT);
			}
			else
			{
				g_iTriggerSelected = 0;
			}
			ShowMenuTrigger(client);
		}
		else if( type == 2 )
		{
			DeleteTrigger(client, index);
			ShowMenuTrigger(client);
		}
		else if( type == 3 )
		{
			g_iTriggerCfgIndex[client] = index;
			DisplayMenu(g_hMenuVMaxs, client, MENU_TIME_FOREVER);
		}
		else if( type == 4 )
		{
			g_iTriggerCfgIndex[client] = index;
			DisplayMenu(g_hMenuVMins, client, MENU_TIME_FOREVER);
		}
		else if( type == 5 )
		{
			g_iTriggerCfgIndex[client] = index;
			DisplayMenu(g_hMenuPos, client, MENU_TIME_FOREVER);
		}
		else if( type == 6 )
		{
			new trigger = g_iTriggers[index];
			if( IsValidEntRef(trigger) )
			{
				new Float:vPos[3];
				GetEntPropVector(trigger, Prop_Send, "m_vecOrigin", vPos);
				vPos[2] += 10.0;
				TeleportEntity(client, vPos, NULL_VECTOR, NULL_VECTOR);
			}
		}
	}
}

public VMaxsMenuHandler(Handle:menu, MenuAction:action, client, index)
{
	if( action == MenuAction_Cancel )
	{
		if( index == MenuCancel_ExitBack )
			ShowMenuTrigger(client);
	}
	else if( action == MenuAction_Select )
	{
		if( index == 0 )
			SaveMaxMin(client, 1, Float:{ 10.0, 10.0, 100.0 });
		else if( index == 1 )
			SaveMaxMin(client, 1, Float:{ 25.0, 25.0, 100.0 });
		else if( index == 2 )
			SaveMaxMin(client, 1, Float:{ 50.0, 50.0, 100.0 });
		else if( index == 3 )
			SaveMaxMin(client, 1, Float:{ 100.0, 100.0, 100.0 });
		else if( index == 4 )
			SaveMaxMin(client, 1, Float:{ 150.0, 150.0, 100.0 });
		else if( index == 5 )
			SaveMaxMin(client, 1, Float:{ 200.0, 200.0, 100.0 });
		else if( index == 6 )
			SaveMaxMin(client, 1, Float:{ 300.0, 300.0, 100.0 });

		DisplayMenu(g_hMenuVMaxs, client, MENU_TIME_FOREVER);
	}
}

public VMinsMenuHandler(Handle:menu, MenuAction:action, client, index)
{
	if( action == MenuAction_Cancel )
	{
		if( index == MenuCancel_ExitBack )
			ShowMenuTrigger(client);
	}
	else if( action == MenuAction_Select )
	{
		if( index == 0 )
			SaveMaxMin(client, 2, Float:{ -10.0, -10.0, 0.0 });
		else if( index == 1 )
			SaveMaxMin(client, 2, Float:{ -25.0, -25.0, 0.0 });
		else if( index == 2 )
			SaveMaxMin(client, 2, Float:{ -50.0, -50.0, 0.0 });
		else if( index == 3 )
			SaveMaxMin(client, 2, Float:{ -100.0, -100.0, 0.0 });
		else if( index == 4 )
			SaveMaxMin(client, 2, Float:{ -150.0, -150.0, 0.0 });
		else if( index == 5 )
			SaveMaxMin(client, 2, Float:{ -200.0, -200.0, 0.0 });
		else if( index == 6 )
			SaveMaxMin(client, 2, Float:{ -300.0, -300.0, 0.0 });

		DisplayMenu(g_hMenuVMins, client, MENU_TIME_FOREVER);
	}
}

public PosMenuHandler(Handle:menu, MenuAction:action, client, index)
{
	if( action == MenuAction_Cancel )
	{
		if( index == MenuCancel_ExitBack )
			ShowMenuTrigger(client);
	}
	else if( action == MenuAction_Select )
	{
		new cfgindex = g_iTriggerCfgIndex[client];
		new trigger = g_iTriggers[cfgindex];

		decl Float:vPos[3];
		GetEntPropVector(trigger, Prop_Send, "m_vecOrigin", vPos);

		if( index == 0 )
			vPos[0] += 1.0;
		else if( index == 1 )
			vPos[1] += 1.0;
		else if( index == 2 )
			vPos[2] += 1.0;
		else if( index == 3 )
			vPos[0] -= 1.0;
		else if( index == 4 )
			vPos[1] -= 1.0;
		else if( index == 5 )
			vPos[2] -= 1.0;

		if( index != 6 )
			TeleportEntity(trigger, vPos, NULL_VECTOR, NULL_VECTOR);
		else
			SaveTrigger(client, cfgindex+1, "vpos", vPos);

		DisplayMenu(g_hMenuPos, client, MENU_TIME_FOREVER);
	}
}

SaveTrigger(client, index, String:sKey[], Float:vVec[3])
{
	new Handle:hFile = ConfigOpen(2);

	if( hFile != INVALID_HANDLE )
	{
		decl String:sTemp[64];
		GetCurrentMap(sTemp, sizeof(sTemp));

		if( KvJumpToKey(hFile, sTemp, true) )
		{
			Format(sTemp, sizeof(sTemp), "%s_%d", sKey, index);
			KvSetVector(hFile, sTemp, vVec);

			ConfigSave(hFile);
			if( client )
				PrintToChat(client, "%s(\x05%d/%d\x01) - Saved trigger '%s'.", CHAT_TAG, g_iTriggerCount, MAX_TRIGGERS, sKey);
		}
		else if( client )
			PrintToChat(client, "%s(\x05%d/%d\x01) - Failed to save trigger '%s'.", CHAT_TAG, g_iTriggerCount, MAX_TRIGGERS, sKey);

		CloseHandle(hFile);
	}
}

SaveMaxMin(client, type, Float:vVec[3])
{
	new cfgindex = g_iTriggerCfgIndex[client];
	new trigger = g_iTriggers[cfgindex];

	if( IsValidEntRef(trigger) )
	{
		if( type == 1 )
			SetEntPropVector(trigger, Prop_Send, "m_vecMaxs", vVec);
		else
			SetEntPropVector(trigger, Prop_Send, "m_vecMins", vVec);
	}

	new Handle:hFile = ConfigOpen(2);

	if( hFile != INVALID_HANDLE )
	{
		decl String:sTemp[64];
		GetCurrentMap(sTemp, sizeof(sTemp));

		if( KvJumpToKey(hFile, sTemp, true) )
		{
			if( type == 1 )
			{
				Format(sTemp, sizeof(sTemp), "vmax_%d", cfgindex+1);
				KvSetVector(hFile, sTemp, vVec);
			}
			else
			{
				Format(sTemp, sizeof(sTemp), "vmin_%d", cfgindex+1);
				KvSetVector(hFile, sTemp, vVec);
			}

			if( client )
				PrintToChat(client, "%sSaved trigger '%s'.", CHAT_TAG, type == 1 ? "maxs" : "mins");
			ConfigSave(hFile);
		}
		else if( client )
			PrintToChat(client, "%sFailed to save trigger '%s'.", CHAT_TAG, type == 1 ? "maxs" : "mins");

		CloseHandle(hFile);
	}
}

DeleteTrigger(client, cfgindex)
{
	new Handle:hFile = ConfigOpen(1);

	if( hFile != INVALID_HANDLE )
	{
		decl String:sMap[64];
		GetCurrentMap(sMap, sizeof(sMap));

		if( KvJumpToKey(hFile, sMap) )
		{
			decl String:sTemp[16], Float:vTemp[3];
			Format(sTemp, sizeof(sTemp), "vpos_%d", cfgindex+1);
			KvDeleteKey(hFile, sTemp);
			Format(sTemp, sizeof(sTemp), "vmax_%d", cfgindex+1);
			KvDeleteKey(hFile, sTemp);
			Format(sTemp, sizeof(sTemp), "vmin_%d", cfgindex+1);
			KvDeleteKey(hFile, sTemp);

			AcceptEntityInput(g_iTriggers[cfgindex], "Kill");
			g_iTriggers[cfgindex] = 0;

			for( new i = cfgindex+1; i <= g_iTriggerCount; i++ )
			{
				g_iTriggers[i-1] = g_iTriggers[i];
				g_iTriggers[i] = 0;

				Format(sTemp, sizeof(sTemp), "vpos_%d", i);
				KvGetVector(hFile, sTemp, vTemp);
				if( vTemp[0] != 0.0 && vTemp[1] != 0.0 && vTemp[2] != 0.0 )
				{
					KvDeleteKey(hFile, sTemp);
					Format(sTemp, sizeof(sTemp), "vpos_%d", i-1);
					KvSetVector(hFile, sTemp, vTemp);

					Format(sTemp, sizeof(sTemp), "vmax_%d", i);
					KvGetVector(hFile, sTemp, vTemp);
					KvDeleteKey(hFile, sTemp);
					Format(sTemp, sizeof(sTemp), "vmax_%d", i-1);
					KvSetVector(hFile, sTemp, vTemp);

					Format(sTemp, sizeof(sTemp), "vmin_%d", i);
					KvGetVector(hFile, sTemp, vTemp);
					KvDeleteKey(hFile, sTemp);
					Format(sTemp, sizeof(sTemp), "vmin_%d", i-1);
					KvSetVector(hFile, sTemp, vTemp);
				}
			}

			g_iTriggerCount--;
			ConfigSave(hFile);

			PrintToChat(client, "%s(\x05%d/%d\x01) - Storm TriggerBox removed from config.", CHAT_TAG, g_iTriggerCount, MAX_TRIGGERS);
		}

		CloseHandle(hFile);
	}
}

CreateTrigger(client)
{
	decl Float:vPos[3];
	GetClientAbsOrigin(client, vPos);
	CreateTriggerMultiple(vPos, Float:{ 25.0, 25.0, 100.0}, Float:{ -25.0, -25.0, 0.0 });
	g_iTriggerCount++;

	SaveTrigger(client, g_iTriggerCount, "vpos", vPos);
	SaveTrigger(client, g_iTriggerCount, "vmax", Float:{ 25.0, 25.0, 100.0});
	SaveTrigger(client, g_iTriggerCount, "vmin", Float:{ -25.0, -25.0, 0.0 });

	g_iTriggerSelected = g_iTriggers[g_iTriggerCount-1];

	if( g_hTmrBeam == INVALID_HANDLE )
	{
		g_hTmrBeam = CreateTimer(0.1, TimerBeam, _, TIMER_REPEAT);
	}
}

CreateTriggerMultiple(Float:vPos[3], Float:vMaxs[3], Float:vMins[3])
{
	new trigger = CreateEntityByName("trigger_multiple");
	DispatchKeyValue(trigger, "StartDisabled", "1");
	DispatchKeyValue(trigger, "spawnflags", "1");
	DispatchKeyValue(trigger, "entireteam", "0");
	DispatchKeyValue(trigger, "allowincap", "0");
	DispatchKeyValue(trigger, "allowghost", "0");

	DispatchSpawn(trigger);
	SetEntityModel(trigger, MODEL_BOUNDING);

	SetEntPropVector(trigger, Prop_Send, "m_vecMaxs", vMaxs);
	SetEntPropVector(trigger, Prop_Send, "m_vecMins", vMins);
	SetEntProp(trigger, Prop_Send, "m_nSolidType", 2);

	TeleportEntity(trigger, vPos, NULL_VECTOR, NULL_VECTOR);

	SetVariantString("OnUser1 !self:Enable::5.0:-1");
	AcceptEntityInput(trigger, "AddOutput");
	AcceptEntityInput(trigger, "FireUser1");

	HookSingleEntityOutput(trigger, "OnStartTouch", OnStartTouch);
	g_iTriggers[g_iTriggerCount] = EntIndexToEntRef(trigger);
}

public OnStartTouch(const String:output[], caller, activator, Float:delay)
{
	if( IsClientInGame(activator) && GetClientTeam(activator) == 2 )
	{
		StartStorm();
		AcceptEntityInput(caller, "Disable");
	}
}

public Action:TimerBeam(Handle:timer)
{
	if( IsValidEntRef(g_iTriggerSelected) )
	{
		decl Float:vMaxs[3], Float:vMins[3], Float:vPos[3];
		GetEntPropVector(g_iTriggerSelected, Prop_Send, "m_vecOrigin", vPos);
		GetEntPropVector(g_iTriggerSelected, Prop_Send, "m_vecMaxs", vMaxs);
		GetEntPropVector(g_iTriggerSelected, Prop_Send, "m_vecMins", vMins);
		AddVectors(vPos, vMaxs, vMaxs);
		AddVectors(vPos, vMins, vMins);
		TE_SendBox(vMins, vMaxs);
		return Plugin_Continue;
	}

	g_hTmrBeam = INVALID_HANDLE;
	return Plugin_Stop;
}

TE_SendBox(Float:vMins[3], Float:vMaxs[3])
{
	decl Float:vPos1[3], Float:vPos2[3], Float:vPos3[3], Float:vPos4[3], Float:vPos5[3], Float:vPos6[3];
	vPos1 = vMaxs;
	vPos1[0] = vMins[0];
	vPos2 = vMaxs;
	vPos2[1] = vMins[1];
	vPos3 = vMaxs;
	vPos3[2] = vMins[2];
	vPos4 = vMins;
	vPos4[0] = vMaxs[0];
	vPos5 = vMins;
	vPos5[1] = vMaxs[1];
	vPos6 = vMins;
	vPos6[2] = vMaxs[2];
	TE_SendBeam(vMaxs, vPos1);
	TE_SendBeam(vMaxs, vPos2);
	TE_SendBeam(vMaxs, vPos3);
	TE_SendBeam(vPos6, vPos1);
	TE_SendBeam(vPos6, vPos2);
	TE_SendBeam(vPos6, vMins);
	TE_SendBeam(vPos4, vMins);
	TE_SendBeam(vPos5, vMins);
	TE_SendBeam(vPos5, vPos1);
	TE_SendBeam(vPos5, vPos3);
	TE_SendBeam(vPos4, vPos3);
	TE_SendBeam(vPos4, vPos2);
}

TE_SendBeam(const Float:vMins[3], const Float:vMaxs[3])
{
	TE_SetupBeamPoints(vMins, vMaxs, g_iLaserMaterial, g_iHaloMaterial, 0, 0, 0.2, 1.0, 1.0, 1, 0.0, { 0, 150, 255, 255 }, 0);
	TE_SendToAll();
}



// ====================================================================================================
//					CONFIG - OPEN
// ====================================================================================================
Handle:ConfigOpen(configtype = 0)
{
	decl String:sPath[PLATFORM_MAX_PATH];
	if( configtype == 0 )
		BuildPath(Path_SM, sPath, sizeof(sPath), "%s", CONFIG_SETTINGS);
	else
		BuildPath(Path_SM, sPath, sizeof(sPath), "%s", CONFIG_TRIGGERS);

	if( !FileExists(sPath) )
	{
		if( configtype == 2 )
		{
			new Handle:hCfg = OpenFile(sPath, "w");
			WriteFileLine(hCfg, "");
			CloseHandle(hCfg);
		}
		else
		{
			return INVALID_HANDLE;
		}
	}

	new Handle:hFile = CreateKeyValues("storms");
	if( !FileToKeyValues(hFile, sPath) )
	{
		CloseHandle(hFile);
		return INVALID_HANDLE;
	}

	return hFile;
}

// ====================================================================================================
//					CONFIG - SAVE
// ====================================================================================================
ConfigSave(Handle:hFile)
{
	decl String:sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "%s", CONFIG_TRIGGERS);
	if( !FileExists(sPath) )
	{
		return;
	}

	KvRewind(hFile);
	KeyValuesToFile(hFile, sPath);
}

// ====================================================================================================
//					CONFIG JUMP : map, main, use_section, random.
// ====================================================================================================
ConfigJumpA(Handle:hFile, String:sMap[64])
{
	new completed_jump;

	if( KvJumpToKey(hFile, sMap) == true || KvJumpToKey(hFile, "main") == true )
	{
		decl String:sJump[64];
		KvGetString(hFile, "use_section", sJump, sizeof(sJump));

		if( strcmp(sJump, "") )
		{
			KvRewind(hFile);

			if( KvJumpToKey(hFile, sJump) == true )
			{
				new count = KvGetNum(hFile, "count");

				if( count != 0 )
				{
					if( g_iRandom == 0 ) // Pick global random, use this index to load data.
						g_iRandom = GetRandomInt(1, count);
					else if( g_iRandom > count )
						g_iRandom = count;

					decl String:sNum[8];
					IntToString(g_iRandom, sNum, sizeof(sNum));
					KvGetString(hFile, sNum, sJump, sizeof(sJump));
				}

				KvRewind(hFile);
			}

			if( KvJumpToKey(hFile, sJump) == false )
			{
				KvRewind(hFile);
				KvJumpToKey(hFile, sMap);
			}
			else
			{
				strcopy(g_sConfigSection, sizeof(g_sConfigSection), sJump);
				completed_jump = 1;
			}
		}
		else
		{
			completed_jump = 1;
		}
	}

	return completed_jump;
}

// ====================================================================================================
//					CONFIG JUMP
// ====================================================================================================
ConfigJumpB(Handle:hFile, String:sMap[64])
{
	KvRewind(hFile);

	if( KvJumpToKey(hFile, sMap) )
	{
		return true;
	}

	return false;
}

// ====================================================================================================
//					CONFIG - Read chance, allow or disallow spawn.
// ====================================================================================================
bool:ConfigChance(client, Handle:hFile)
{
	if( g_iChance == 0 )
		g_iChance = GetRandomInt(1, 100);

	if( client == 0 )
	{
		new chance = KvGetNum(hFile, "chance", 100);

		if( chance == 0 )
		{
			ResetVars();
			return false;
		}

		if( chance != 100 )
		{
			if( g_iChance > chance )
			{
				ResetVars();
				return false;
			}
		}
	}

	return true;
}



// ====================================================================================================
//					LOAD STORM
// ====================================================================================================
GetColor(String:sTemp[12])
{
	if( strcmp(sTemp, "") == 0 )
	{
		return 0;
	}

	decl String:sColors[3][4];
	ExplodeString(sTemp, " ", sColors, 3, 4);

	new color;
	color = StringToInt(sColors[0]);
	color += 256 * StringToInt(sColors[1]);
	color += 65536 * StringToInt(sColors[2]);
	return color;
}

Clamp(value, max, min = 0)
{
	if( value < min )
		value = min;
	else if( value > max )
		value = max;
	return value;
}

LoadStorm(client = 0)
{
	if( g_iReset == 1 )
		ResetPlugin();

	if( g_bLoaded && client == 0 )
		return;

	strcopy(g_sConfigSection, sizeof(g_sConfigSection), "");

	new Handle:hFile = ConfigOpen();
	new g_iFogOnOn;
	if( hFile != INVALID_HANDLE )
	{
		decl String:sMap[64];
		GetCurrentMap(sMap, sizeof(sMap));

		new completed_jump = ConfigJumpA(hFile, sMap);
		if( completed_jump )
		{
			if( ConfigChance(client, hFile) == false )
			{
				CloseHandle(hFile);
				return;
			}

			KvGetString(hFile, "light_style", g_sCfgLightStyle, sizeof(g_sCfgLightStyle));
			KvGetString(hFile, "fog_color", g_sCfgFogColor, sizeof(g_sCfgFogColor)); 
			g_iFogOnOn		=		KvGetNum(hFile,		"fog",0);
			g_iCfgFogBlend =		KvGetNum(hFile,		"fog_blend", -1);
			g_iCfgFogIdle =			KvGetNum(hFile,		"fog_idle", 0);
			g_iCfgFogStorm =		KvGetNum(hFile,		"fog_storm", 0);
			g_iCfgFogIdle2 =		KvGetNum(hFile,		"fog_idle_start", 0);
			g_iCfgFogStorm2 =		KvGetNum(hFile,		"fog_storm_start", 0);
			g_fCfgFogOpaqueIdle =	KvGetFloat(hFile,	"fog_opaque_idle", 0.0);
			g_fCfgFogOpaqueStorm =	KvGetFloat(hFile,	"fog_opaque_storm", 0.0);
			g_iCfgFogZIdle =		KvGetNum(hFile,		"far_z_idle", 0);
			g_iCfgFogZStorm =		KvGetNum(hFile,		"far_z_storm", 0);
			g_iCfgClouds =			KvGetNum(hFile,		"clouds", 0);
			g_iCfgLight =			KvGetNum(hFile,		"lightning", 0);
			g_iCfgLightDmg =		KvGetNum(hFile,		"lightning_damage", 0);
			g_iCfgLightTime =		KvGetNum(hFile,		"lightning_time", 0);
			g_iCfgLightFlash =		KvGetNum(hFile,		"lightning_flash", 0);
			g_iCfgSnow =			KvGetNum(hFile,		"snow", 0);
			g_iCfgSnowIdle =		KvGetNum(hFile,		"snow_idle", -1);
			g_iCfgSnowStorm =		KvGetNum(hFile,		"snow_storm", -1);
			g_iCfgRain =			KvGetNum(hFile,		"rain", 0);
			g_iCfgRainIdle =		KvGetNum(hFile,		"rain_idle", -1);
			g_iCfgRainStorm =		KvGetNum(hFile,		"rain_storm", -1);
			g_iCfgWind =			KvGetNum(hFile,		"wind", 0);
			g_iCfgForever =			KvGetNum(hFile,		"forever", 0);
			g_iCfgTimeout =			KvGetNum(hFile,		"timeout", 0);
			g_iCfgTimeMax =			KvGetNum(hFile,		"duration_max", 0);
			g_iCfgTimeMin =			KvGetNum(hFile,		"duration_min", 0);
			g_iCfgTimer =			KvGetNum(hFile,		"trigger_timer", 0);
			g_iCfgFinale =			KvGetNum(hFile,		"trigger_finale", 0);
			g_iCfgHorde =			KvGetNum(hFile,		"trigger_horde", 0);
			g_iCfgPanic =			KvGetNum(hFile,		"trigger_panic", 0);
			g_iCfgTank =			KvGetNum(hFile,		"trigger_tank", 0);
			g_iCfgTankDeath =		KvGetNum(hFile,		"trigger_tank_death", 0);
			g_iCfgWitch =			KvGetNum(hFile,		"trigger_witch", 0);
			g_iCfgWitchHead =		KvGetNum(hFile,		"trigger_witch_head", 0);
			g_iCfgWitchAlert =		KvGetNum(hFile,		"trigger_witch_alert", 0);
	
			decl String:sColors[12];
			KvGetString(hFile, "sun", sColors, sizeof(sColors));

			if( completed_jump == 1 && ConfigJumpB(hFile, sMap) )
			{
				if( ConfigChance(client, hFile) == false )
				{
					CloseHandle(hFile);
					return;
				}

				KvGetString(hFile, "fog_color", g_sCfgFogColor, sizeof(g_sCfgFogColor), g_sCfgFogColor);
				KvGetString(hFile, "light_style", g_sCfgLightStyle, sizeof(g_sCfgLightStyle), g_sCfgLightStyle);
				g_iFogOnOn		=		KvGetNum(hFile,		"fog",				g_iFogOnOn);
				g_iCfgFogBlend =		KvGetNum(hFile,		"fog_blend",				g_iCfgFogBlend);
				g_iCfgFogIdle =			KvGetNum(hFile,		"fog_idle",					g_iCfgFogIdle);
				g_iCfgFogStorm =		KvGetNum(hFile,		"fog_storm",				g_iCfgFogStorm);
				g_iCfgFogIdle2 =		KvGetNum(hFile,		"fog_idle_start",			g_iCfgFogIdle2);
				g_iCfgFogStorm2 =		KvGetNum(hFile,		"fog_storm_start",			g_iCfgFogStorm2);
				g_fCfgFogOpaqueIdle =	KvGetFloat(hFile,	"fog_opaque_idle",			g_fCfgFogOpaqueIdle);
				g_fCfgFogOpaqueStorm =	KvGetFloat(hFile,	"fog_opaque_storm",			g_fCfgFogOpaqueStorm);
				g_iCfgFogZIdle =		KvGetNum(hFile,		"far_z_idle",				g_iCfgFogZIdle);
				g_iCfgFogZStorm =		KvGetNum(hFile,		"far_z_storm",				g_iCfgFogZStorm);
				g_iCfgClouds =			KvGetNum(hFile,		"clouds",					g_iCfgClouds);
				g_iCfgLight =			KvGetNum(hFile,		"lightning",				g_iCfgLight);
				g_iCfgLightDmg =		KvGetNum(hFile,		"lightning_damage",			g_iCfgLightDmg);
				g_iCfgLightTime =		KvGetNum(hFile,		"lightning_time",			g_iCfgLightTime);
				g_iCfgLightFlash =		KvGetNum(hFile,		"lightning_flash",			g_iCfgLightFlash);
				g_iCfgSnow =			KvGetNum(hFile,		"snow",						g_iCfgSnow);
				g_iCfgSnowIdle =		KvGetNum(hFile,		"snow_idle",				g_iCfgSnowIdle);
				g_iCfgSnowStorm =		KvGetNum(hFile,		"snow_storm",				g_iCfgSnowStorm);
				g_iCfgRain =			KvGetNum(hFile,		"rain",						g_iCfgRain);
				g_iCfgRain = Clamp(g_iCfgRain, MAX_RAIN);
				g_iCfgRainIdle =		KvGetNum(hFile,		"rain_idle",				g_iCfgRainIdle);
				g_iCfgRainStorm =		KvGetNum(hFile,		"rain_storm",				g_iCfgRainStorm);
				g_iCfgWind =			KvGetNum(hFile,		"wind",						g_iCfgWind);
				g_iCfgTimeout =			KvGetNum(hFile,		"timeout",					g_iCfgTimeout);
				g_iCfgForever =			KvGetNum(hFile,		"forever",					g_iCfgForever);
				g_iCfgTimeMax =			KvGetNum(hFile,		"duration_max",				g_iCfgTimeMax);
				g_iCfgTimeMin =			KvGetNum(hFile,		"duration_min",				g_iCfgTimeMin);
				g_iCfgTimer =			KvGetNum(hFile,		"trigger_timer",			g_iCfgTimer);
				g_iCfgHorde =			KvGetNum(hFile,		"trigger_horde",			g_iCfgHorde);
				g_iCfgPanic =			KvGetNum(hFile,		"trigger_panic",			g_iCfgPanic);
				g_iCfgTank =			KvGetNum(hFile,		"trigger_tank",				g_iCfgTank);
				g_iCfgTankDeath =		KvGetNum(hFile,		"trigger_tank_death",		g_iCfgTankDeath);
				g_iCfgWitch =			KvGetNum(hFile,		"trigger_witch",			g_iCfgWitch);
				g_iCfgWitchHead =		KvGetNum(hFile,		"trigger_witch_head",		g_iCfgWitchHead);
				KvGetString(hFile, "sun", sColors, sizeof(sColors), sColors);
			}


			if( g_iCfgRainIdle == -1 )
				g_iCfgRainIdle = 75;
			if( g_iCfgRainStorm == -1 )
				g_iCfgRainStorm = 250;
			// if( g_iCfgSnowIdle == -1 )
				// g_iCfgSnowIdle = 75;
			// if( g_iCfgSnowStorm == -1 )
				// g_iCfgSnowStorm = 250;


			if( strcmp(sColors, "") )
			{
				ToggleEnvSun(GetColor(sColors));
			}

			g_bLoaded = true;
			g_iStarted = 2;

			CheckDynamicLightStyle();


			if( g_iCfgForever == 0 )
			{
				// TRIGGERS TO START STORM
				if( g_iCfgHorde )
				{
					g_iLogicDirector = CreateEntityByName("logic_director_query");
					DispatchKeyValue(g_iLogicDirector, "minAngerRange", "1");
					DispatchKeyValue(g_iLogicDirector, "maxAngerRange", "10");
					DispatchKeyValue(g_iLogicDirector, "distribution", "3");
					DispatchSpawn(g_iLogicDirector);

					SetVariantString("On20SecondsToMob !self:FireUser1::15:-1");
					AcceptEntityInput(g_iLogicDirector, "AddOutput");

					HookSingleEntityOutput(g_iLogicDirector, "OnUser1", OnDirectorMob);
					g_iLogicDirector = EntIndexToEntRef(g_iLogicDirector);
				}


				if( g_iCfgTimer != 0 )
				{
					g_hTmrTrigger = CreateTimer(float(g_iCfgTimer), TimerTrigger, _, TIMER_REPEAT);
				}


				// TRIGGER BOXES
				new Handle:hTrig = ConfigOpen(1);

				if( hTrig != INVALID_HANDLE )
				{
					if( KvJumpToKey(hTrig, sMap) == true )
					{
						decl String:sTemp[64], Float:vPos[3], Float:vMin[3], Float:vMax[3];

						for( new i = 1; i <= MAX_TRIGGERS; i++ )
						{
							Format(sTemp, sizeof(sTemp), "vpos_%d", i);
							KvGetVector(hTrig, sTemp, vPos);
							if( vPos[0] != 0.0 && vPos[1] != 0.0 && vPos[2] != 0.0 )
							{
								Format(sTemp, sizeof(sTemp), "vmax_%d", i);
								KvGetVector(hTrig, sTemp, vMin);
								Format(sTemp, sizeof(sTemp), "vmin_%d", i);
								KvGetVector(hTrig, sTemp, vMax);

								CreateTriggerMultiple(vPos, vMin, vMax);
								g_iTriggerCount++;
							}
							else
							{
								break;
							}
						}
					}

					CloseHandle(hTrig);
				}
			}

			if( g_iCfgClouds )
				CreateClouds();
			if( g_iCfgLight )
				CreateLightning();
			if( g_iCfgRain )
				CreateRain();
			if( g_iCfgSnow && g_iCfgSnowIdle )
				CreateSnow();
			if( g_iCfgWind )
				CreateWind();
			if( g_iFogOnOn || (g_iCfgFogIdle && g_iCfgFogStorm) )
				CreateFog();

			if( g_iCfgLight != 0 || g_iCfgRain != 0 || g_iCfgWind != 0 || g_iCfgFogIdle != 0 || g_iCfgFogStorm != 0 )
			{
				CreateLogics();

				if( g_iCvarMixer )
					CreateMixer();

				g_iStormState = STATE_IDLE;
				StopAmbientSound();
				PlaySoundRain();
				PlaySoundWind();
			}

			if( g_iCfgForever == 1 )
			{
				StartStorm();
			}

			SetSkyname();
			CreateTimer(0.1, TimerSetSkyCam);
		}

		CloseHandle(hFile);
	}
}

public Action:TimerSetSkyCam(Handle:timer)
{
	SetBackground(false);
	ChangeLightStyle(g_sCfgLightStyle);
}

public OnDirectorMob(const String:output[], caller, activator, Float:delay)
{
	if( g_iStormState == STATE_OFF )
		return;

	if( GetRandomInt(1, 100) <= g_iCfgHorde )
		StartStorm();
}

public Action:TimerTrigger(Handle:timer, any:data)
{
	if( g_bCvarAllow == false  )
	{
		g_hTmrTrigger = INVALID_HANDLE;
		return Plugin_Stop;
	}

	StartStorm();
	return Plugin_Continue;
}

StartStorm(client = 0)
{
	if( g_iStormState == STATE_IDLE )
	{
		if( g_hTmrTimeout != INVALID_HANDLE )
		{
			if( client != 0 )
			{
				CloseHandle(g_hTmrTimeout);
				g_hTmrTimeout = INVALID_HANDLE;
			}
			else
			{
				return;
			}
		}

		g_iStormState = STATE_STORM;

		// END STORM TIMER
		if( g_iCfgForever == 0 && g_hTmrEndStorm == INVALID_HANDLE )
		{
			if( g_iCfgTimeMin != 0 && g_iCfgTimeMax != 0 )
			{
				new time = GetRandomInt(g_iCfgTimeMin, g_iCfgTimeMax);
				g_hTmrEndStorm = CreateTimer(float(time), TimerEndStorm);
			}
		}

		// SOUNDS
		StopAmbientSound();
		PlaySoundRain();
		PlaySoundWind();

		// POST PROCESS
		if( g_fCvarPost != 0.0 )
			CreatePostProcess();

		// TRIGGER STORM IN
		if( IsValidEntRef(g_iLogicIn) )
			AcceptEntityInput(g_iLogicIn, "Trigger");

		if( client )
			PrintToChat(client, "%sStorm started.", CHAT_TAG);
	}
}

public Action:TimerEndStorm(Handle:timer)
{
	g_hTmrEndStorm = INVALID_HANDLE;
	StopStorm();
}

StopStorm(client = 0)
{
	if( g_hTmrEndStorm != INVALID_HANDLE )
	{
		CloseHandle(g_hTmrEndStorm);
		g_hTmrEndStorm = INVALID_HANDLE;
	}

	// TIMEOUT
	if( g_iCfgForever == 0 && g_iCfgTimeout != 0 )
	{
		if( g_hTmrTimeout != INVALID_HANDLE )
		{
			CloseHandle(g_hTmrTimeout);
			g_hTmrTimeout = INVALID_HANDLE;
		}

		g_hTmrTimeout = CreateTimer(float(g_iCfgTimeout), TimerTimeout);
	}

	if( g_iStormState == STATE_STORM )
	{
		g_iStormState = STATE_IDLE;

		// SOUNDS
		StopAmbientSound();
		PlaySoundRain();
		PlaySoundWind();

		// POST PROCESS
		if( IsValidEntRef(g_iFogVolume) )
			AcceptEntityInput(g_iFogVolume, "Kill");
		if( IsValidEntRef(g_iPostProcess) )
			AcceptEntityInput(g_iPostProcess, "Kill");

		// TRIGGER STORM OUT
		if( IsValidEntRef(g_iLogicOut) )
			AcceptEntityInput(g_iLogicOut, "Trigger");

		if( client )
			PrintToChat(client, "%sStorm ended.", CHAT_TAG);
	}
}

public Action:TimerTimeout(Handle:timer)
{
	g_hTmrTimeout = INVALID_HANDLE;
}



// ====================================================================================================
//					POST PROCESS
// ====================================================================================================
CreatePostProcess()
{
	decl Float:vPos[3];
	new client;

	for( new i = 1; i <= MaxClients; i++ )
	{
		if( IsClientInGame(i) && IsPlayerAlive(i) )
		{
			client = i;
			break;
		}
	}

	if( client == 0 )
		return;

	GetClientAbsOrigin(client, vPos);

	g_iPostProcess = CreateEntityByName("postprocess_controller");
	if( g_iPostProcess == -1 )
	{
		LogError("Failed to create 'postprocess_controller'");
		return;
	}
	else
	{
		decl String:sTemp[16];
		DispatchKeyValue(g_iPostProcess, "targetname", "silver_fx_settings_storm");
		DispatchKeyValue(g_iPostProcess, "vignettestart", "1");
		DispatchKeyValue(g_iPostProcess, "vignetteend", "4");
		DispatchKeyValue(g_iPostProcess, "vignetteblurstrength", "0");
		DispatchKeyValue(g_iPostProcess, "topvignettestrength", "1");
		DispatchKeyValue(g_iPostProcess, "spawnflags", "1");
		Format(sTemp, sizeof(sTemp), "%f", g_fCvarPost);
		DispatchKeyValue(g_iPostProcess, "localcontraststrength", sTemp);
		DispatchKeyValue(g_iPostProcess, "localcontrastedgestrength", "-.3");
		DispatchKeyValue(g_iPostProcess, "grainstrength", "1");
		DispatchKeyValue(g_iPostProcess, "fadetime", "3");

		DispatchSpawn(g_iPostProcess);
		ActivateEntity(g_iPostProcess);
		TeleportEntity(g_iPostProcess, vPos, NULL_VECTOR, NULL_VECTOR);
		g_iPostProcess = EntIndexToEntRef(g_iPostProcess);
	}

	ToggleFogVolume(false);

	g_iFogVolume = CreateEntityByName("fog_volume");
	if( g_iFogVolume == -1 )
	{
		LogError("Failed to create 'fog_volume'");
	}
	else
	{
		DispatchKeyValue(g_iFogVolume, "PostProcessName", "silver_fx_settings_storm");
		DispatchKeyValue(g_iFogVolume, "spawnflags", "0");

		DispatchSpawn(g_iFogVolume);
		ActivateEntity(g_iFogVolume);

		new Float:vMins[3] = { -5000.0, -5000.0, -5000.0 };
		new Float:vMaxs[3] = { 5000.0, 5000.0, 5000.0 };
		SetEntPropVector(g_iFogVolume, Prop_Send, "m_vecMins", vMins);
		SetEntPropVector(g_iFogVolume, Prop_Send, "m_vecMaxs", vMaxs);
		TeleportEntity(g_iFogVolume, vPos, NULL_VECTOR, NULL_VECTOR);
	}

	ToggleFogVolume(true);
}

// We have to disable fog_volume when we create ours, so it has priority. Thankfully this works.
// Also saves the enabled/disabled state of fog_volume's we change to prevent visual corruption!
ToggleFogVolume(bool:enable)
{
	if( enable == true )
	{
		if( IsValidEntRef(g_iFogVolume) )
		{
			AcceptEntityInput(g_iFogVolume, "Disable");
			AcceptEntityInput(g_iFogVolume, "Enable");
		}
	}

	new m_bDisabled, entity = -1;

	while( (entity = FindEntityByClassname(entity, "fog_volume")) != INVALID_ENT_REFERENCE )
	{
		if( g_iFogVolume == entity )
		{
			break;
		}

		if( enable == true )
		{
			m_bDisabled = GetEntProp(entity, Prop_Data, "m_bDisabled");
			if( m_bDisabled == 0 )
				AcceptEntityInput(entity, "Enable");
		}
		else if( enable == false )
		{
			m_bDisabled = GetEntProp(entity, Prop_Data, "m_bDisabled");
			SetEntProp(entity, Prop_Data, "m_iHammerID", m_bDisabled);
			AcceptEntityInput(entity, "Disable");
		}
	}
}



// ====================================================================================================
//					LIGHTNING
// ====================================================================================================
CreateLightning()
{
	g_iLight = CreateEntityByName("logic_timer");
	DispatchKeyValue(g_iLight, "targetname", "silver_timer_storm_lightning_strike");
	DispatchKeyValue(g_iLight, "spawnflags", "0");
	DispatchKeyValue(g_iLight, "StartDisabled", "0");
	DispatchKeyValue(g_iLight, "UseRandomTime", "1");
	DispatchKeyValue(g_iLight, "LowerRandomBound", "5");
	DispatchKeyValue(g_iLight, "UpperRandomBound", "25");

	DispatchSpawn(g_iLight);
	ActivateEntity(g_iLight);
	TeleportEntity(g_iLight, Float:{ 1.0, 1.0, 1.0 }, NULL_VECTOR, NULL_VECTOR);
	HookSingleEntityOutput(g_iLight, "OnTimer", OutputOnLightning);
}

public OutputOnLightning(const String:output[], caller, activator, Float:delay)
{
	DisplayLightning();
}

DisplayLightning(client = 0)
{
	// SOUND
	new rand;
	if( client )
		rand = -1;
	else
		rand = GetRandomInt(0, 1);

	if( rand == 0 || rand == -1)
	{
		rand = GetRandomInt(8, 16);

		/*if( rand == 1 )			EmitSoundToAll(SOUND_STORM1);
		else if( rand == 2 )	EmitSoundToAll(SOUND_STORM2);
		else if( rand == 3 )	EmitSoundToAll(SOUND_STORM3);
		else if( rand == 4 )	EmitSoundToAll(SOUND_STORM4);
		else if( rand == 5 )	EmitSoundToAll(SOUND_STORM5);
		else if( rand == 6 )	EmitSoundToAll(SOUND_STORM6);
		else if( rand == 7 )	EmitSoundToAll(SOUND_STORM7);*/
		if( rand == 8 )	EmitSoundToAll(SOUND_STORM8);
		else if( rand == 9 )	EmitSoundToAll(SOUND_STORM9);
		else if( rand == 10 )	EmitSoundToAll(SOUND_STORM10);
		else if( rand == 11 )	EmitSoundToAll(SOUND_STORM11);
		else if( rand == 12 )	EmitSoundToAll(SOUND_STORM12);
		else if( rand == 13 )	EmitSoundToAll(SOUND_STORM13);
		else if( rand == 14 )	EmitSoundToAll(SOUND_STORM14);
		else if( rand == 15 )	EmitSoundToAll(SOUND_STORM15);
		else if( rand == 16 )	EmitSoundToAll(SOUND_STORM16);
	}


	static stormstate;
	if( g_iStormState <= STATE_IDLE )
	{
		if( stormstate != 1 )
		{
			SetVariantInt(5);
			AcceptEntityInput(g_iLight, "LowerRandomBound");
			SetVariantInt(25);
			AcceptEntityInput(g_iLight, "UpperRandomBound");
			stormstate = 1;
		}

		if( client == 0 )
		{
			return;
		}
	}
	else
	{
		if( stormstate != 2 )
		{
			SetVariantInt(1);
			AcceptEntityInput(g_iLight, "LowerRandomBound");
			SetVariantInt(5);
			AcceptEntityInput(g_iLight, "UpperRandomBound");
			stormstate = 2;
		}
	}


	// GET RANDOM CLIENT
	decl Float:vPos[3], Float:vAim[3];
	new player, clients[MAXPLAYERS+1], count;

	for( new i = 1; i <= MaxClients; i++ )
	{
		if( IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) )
		{
			clients[count++] = i;
		}
	}


	// RANDOM CLIENT SELECTED
	if( count )
	{
		player = clients[GetRandomInt(0, count-1)];

		decl Float:vMaxs[3];
		GetEntPropVector(0, Prop_Data, "m_WorldMaxs", vMaxs);
		GetClientAbsOrigin(player, vPos);

		vPos[0] += GetRandomInt(-1200, 1200);
		vPos[1] += GetRandomInt(-1200, 1200);
		vPos[2] = vMaxs[2];
	}
	else // RANDOM PLACE ON MAP
	{
		decl Float:vMins[3], Float:vMaxs[3];
		GetEntPropVector(0, Prop_Data, "m_WorldMins", vMins);
		GetEntPropVector(0, Prop_Data, "m_WorldMaxs", vMaxs);

		vPos[0] = GetRandomFloat(vMins[0], vMaxs[0]);
		vPos[1] = GetRandomFloat(vMins[1], vMaxs[1]);
		vPos[2] = vMaxs[2];
	}


	// TRACE FROM SKYBOX TO GROUND
	client = TraceDown(vPos, vAim);


	// SHAKE
	new Handle:UserMsgShake = StartMessageAll("Shake");
	BfWriteByte(UserMsgShake, 0);
	BfWriteFloat(UserMsgShake, 1.0);
	BfWriteFloat(UserMsgShake, 0.5);
	BfWriteFloat(UserMsgShake, 0.5);
	EndMessage();


	// PARTICLE TARGET
	decl String:sTemp[64];
	new target = CreateEntityByName("info_target");
	DispatchKeyValue(target, "spawnflags", "0");
	DispatchSpawn(target);
	TeleportEntity(target, vAim, NULL_VECTOR, NULL_VECTOR);

	Format(sTemp, sizeof(sTemp), "storm%d%d%d", target, player, GetRandomInt(99,999));
	DispatchKeyValue(target, "targetname", sTemp);

	SetVariantString("OnUser1 !self:Kill::1.0:1");
	AcceptEntityInput(target, "AddOutput");
	AcceptEntityInput(target, "FireUser1");


	// PARTICLE SYSTEM
	new entity = CreateEntityByName("info_particle_system");
	DispatchKeyValue(entity, "cpoint1", sTemp);
	if( GetRandomInt(0, 1) )
		DispatchKeyValue(entity, "effect_name", PARTICLE_LIGHT1);
	else
		DispatchKeyValue(entity, "effect_name", PARTICLE_LIGHT2);
	DispatchSpawn(entity);
	ActivateEntity(entity);
	TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(entity, "Start");

	SetVariantString("OnUser1 !self:Kill::1.0:1");
	AcceptEntityInput(entity, "AddOutput");
	AcceptEntityInput(entity, "FireUser1");


	// FLASH
	if( g_iCfgLightFlash )
	{
		entity = CreateEntityByName("info_particle_system");
		DispatchKeyValue(entity, "targetname", "silver_fx_screen_flash");
		DispatchKeyValue(entity, "effect_name", PARTICLE_GLOW);
		DispatchSpawn(entity);
		ActivateEntity(entity);
		TeleportEntity(entity, vAim, NULL_VECTOR, NULL_VECTOR);
		AcceptEntityInput(entity, "start");
		SetVariantString("OnUser1 !self:Kill::1.0:1");
		AcceptEntityInput(entity, "AddOutput");
		AcceptEntityInput(entity, "FireUser1");
	}


	// LIGHTNING HURT
	if( g_iCfgLightDmg && client == 0 )
	{
		// FIRE PARTICLES
		vAim[2] += 10.0;
		entity = CreateEntityByName("info_particle_system");
		DispatchKeyValue(entity, "effect_name", PARTICLE_FIRE);
		DispatchSpawn(entity);
		ActivateEntity(entity);
		TeleportEntity(entity, vAim, NULL_VECTOR, NULL_VECTOR);
		AcceptEntityInput(entity, "start");

		Format(sTemp, sizeof(sTemp), "OnUser1 !self:Kill::%d:1", g_iCfgLightTime);
		SetVariantString(sTemp);
		AcceptEntityInput(entity, "AddOutput");
		AcceptEntityInput(entity, "FireUser1");

		// HURT
		new trigger = CreateEntityByName("trigger_hurt");
		DispatchKeyValue(trigger, "spawnflags", "3");
		DispatchKeyValue(trigger, "damagetype", "8");
		DispatchKeyValue(trigger, "damage", "2");
		DispatchSpawn(trigger);
		AcceptEntityInput(trigger, "Enable");

		SetEntityModel(trigger, MODEL_BOUNDING);
		SetEntPropVector(trigger, Prop_Send, "m_vecMaxs", Float:{ 20.0, 20.0, 20.0});
		SetEntPropVector(trigger, Prop_Send, "m_vecMins", Float:{ -20.0, -20.0, 20.0 });
		SetEntProp(trigger, Prop_Send, "m_nSolidType", 2);
		TeleportEntity(trigger, vAim, NULL_VECTOR, NULL_VECTOR);

		SetVariantString(sTemp);
		AcceptEntityInput(trigger, "AddOutput");
		AcceptEntityInput(trigger, "FireUser1");
	}
}

TraceDown(Float:vPos[3], Float:vAim[3])
{
	vAim = vPos;
	vAim[2] -= 10000.0;
	vPos[2] -= 500.0;
	TR_TraceRay(vPos, vAim, MASK_OPAQUE, RayType_EndPoint);
	vPos[2] += 500.0;

	new client;

	if( TR_DidHit() )
	{
		TR_GetEndPosition(vAim);
		client = TR_GetEntityIndex();
		if( client == -1 )
			client = 1;
		else if( client > MaxClients )
			client = 0;
	}

	return client;
}



// ====================================================================================================
//					LOGICS - FADE IN / FADE OUT
// ====================================================================================================
CreateLogics()
{
	decl String:sTemp[64];
	new alpha;

	// ====================================================================================================
	// logic_relay - FADE IN
	// ====================================================================================================
	g_iLogicIn = CreateEntityByName("logic_relay");
	if( g_iLogicIn != -1 )
	{
		DispatchKeyValue(g_iLogicIn, "spawnflags", "2");
		DispatchKeyValue(g_iLogicIn, "targetname", "silver_relay_storm_blendin");

		// SILVER
		if( g_iCfgFogStorm )
		{
			Format(sTemp, sizeof(sTemp), "OnTrigger silver_fog_storm:SetEndDistLerpTo:%d:0:-1", g_iCfgFogStorm);
			SetVariantString(sTemp);
			AcceptEntityInput(g_iLogicIn, "AddOutput");
		}
		if( g_iCfgFogStorm2 )
		{
			Format(sTemp, sizeof(sTemp), "OnTrigger silver_fog_storm:SetStartDistLerpTo:%d:0:-1", g_iCfgFogStorm2);
			SetVariantString(sTemp);
			AcceptEntityInput(g_iLogicIn, "AddOutput");
		}
		if( g_fCfgFogOpaqueStorm )
		{
			Format(sTemp, sizeof(sTemp), "OnTrigger silver_fog_storm:Setmaxdensitylerpto:%f:0:-1", g_fCfgFogOpaqueStorm);
			SetVariantString(sTemp);
			AcceptEntityInput(g_iLogicIn, "AddOutput");
		}
		if( g_iCfgFogZIdle && g_iCfgFogZStorm )
		{
			Format(sTemp, sizeof(sTemp), "OnTrigger silver_fog_storm:SetFarZ:%d:%d:-1", g_iCfgFogZStorm, g_iCfgFogBlend - 1);
			SetVariantString(sTemp);
			AcceptEntityInput(g_iLogicIn, "AddOutput");
		}
		SetVariantString("OnTrigger silver_fog_storm:Set2DSkyboxFogFactorLerpTo:1:0:-1");
		AcceptEntityInput(g_iLogicIn, "AddOutput");
		SetVariantString("OnTrigger silver_fog_storm:StartFogTransition::0.1:-1");
		AcceptEntityInput(g_iLogicIn, "AddOutput");

		// STOLEN
		if( g_iCfgFogStorm )
		{
			Format(sTemp, sizeof(sTemp), "OnTrigger stolen_fog_storm:SetEndDistLerpTo:%d:0:-1", g_iCfgFogStorm);
			SetVariantString(sTemp);
			AcceptEntityInput(g_iLogicIn, "AddOutput");
		}
		if( g_iCfgFogStorm2 )
		{
			Format(sTemp, sizeof(sTemp), "OnTrigger stolen_fog_storm:SetStartDistLerpTo:%d:0:-1", g_iCfgFogStorm2);
			SetVariantString(sTemp);
			AcceptEntityInput(g_iLogicIn, "AddOutput");
		}
		if( g_fCfgFogOpaqueStorm )
		{
			Format(sTemp, sizeof(sTemp), "OnTrigger stolen_fog_storm:Setmaxdensitylerpto:%f:0:-1", g_fCfgFogOpaqueStorm);
			SetVariantString(sTemp);
			AcceptEntityInput(g_iLogicIn, "AddOutput");
		}
		if( g_iCfgFogZIdle && g_iCfgFogZStorm )
		{
			Format(sTemp, sizeof(sTemp), "OnTrigger stolen_fog_storm:SetFarZ:%d:%d:-1", g_iCfgFogZStorm, g_iCfgFogBlend - 1);
			SetVariantString(sTemp);
			AcceptEntityInput(g_iLogicIn, "AddOutput");
		}
		SetVariantString("OnTrigger stolen_fog_storm:Set2DSkyboxFogFactorLerpTo:1:0:-1");
		AcceptEntityInput(g_iLogicIn, "AddOutput");
		SetVariantString("OnTrigger stolen_fog_storm:StartFogTransition::0.1:-1");
		AcceptEntityInput(g_iLogicIn, "AddOutput");

		// RAIN
		alpha = g_iCfgRainStorm - g_iCfgRainIdle;
		Format(sTemp, sizeof(sTemp), "OnTrigger silver_rain:alpha:%d:0.5:-1", g_iCfgRainIdle + (alpha / 4));
		SetVariantString(sTemp);
		AcceptEntityInput(g_iLogicIn, "AddOutput");
		Format(sTemp, sizeof(sTemp), "OnTrigger silver_rain:alpha:%d:1.0:-1", g_iCfgRainIdle + ((alpha / 4) * 2));
		SetVariantString(sTemp);
		AcceptEntityInput(g_iLogicIn, "AddOutput");
		Format(sTemp, sizeof(sTemp), "OnTrigger silver_rain:alpha:%d:1.5:-1", g_iCfgRainIdle + ((alpha / 4) * 3));
		SetVariantString(sTemp);
		AcceptEntityInput(g_iLogicIn, "AddOutput");
		Format(sTemp, sizeof(sTemp), "OnTrigger silver_rain:alpha:%d:2.0:-1", g_iCfgRainStorm);
		SetVariantString(sTemp);
		AcceptEntityInput(g_iLogicIn, "AddOutput");

		// SNOW - Does not work... :/
		// alpha = g_iCfgSnowStorm - g_iCfgSnowIdle;
		// Format(sTemp, sizeof(sTemp), "OnTrigger silver_snow:alpha:%d:0.5:-1", g_iCfgSnowIdle + (alpha / 4));
		// SetVariantString(sTemp);
		// AcceptEntityInput(g_iLogicIn, "AddOutput");
		// Format(sTemp, sizeof(sTemp), "OnTrigger silver_snow:alpha:%d:1.0:-1", g_iCfgSnowIdle + ((alpha / 4) * 2));
		// SetVariantString(sTemp);
		// AcceptEntityInput(g_iLogicIn, "AddOutput");
		// Format(sTemp, sizeof(sTemp), "OnTrigger silver_snow:alpha:%d:1.5:-1", g_iCfgSnowIdle + ((alpha / 4) * 3));
		// SetVariantString(sTemp);
		// AcceptEntityInput(g_iLogicIn, "AddOutput");
		// Format(sTemp, sizeof(sTemp), "OnTrigger silver_snow:alpha:%d:2.0:-1", g_iCfgSnowStorm);
		// SetVariantString(sTemp);
		// AcceptEntityInput(g_iLogicIn, "AddOutput");

		// OUTHER OUTPUTS
		SetVariantString("OnTrigger silver_relay_mix_blendin:Trigger::0:-1");
		AcceptEntityInput(g_iLogicIn, "AddOutput");
		SetVariantString("OnTrigger silver_fx_settings_storm:FireUser1::0:-1");
		AcceptEntityInput(g_iLogicIn, "AddOutput");

		DispatchSpawn(g_iLogicIn);
		ActivateEntity(g_iLogicIn);

		HookSingleEntityOutput(g_iLogicIn, "OnTrigger", OnLogicIn);
	}
	else
		LogError("Failed to create g_iLogicIn 'logic_relay'");


	// ====================================================================================================
	// logic_relay - FADE OUT
	// ====================================================================================================
	g_iLogicOut = CreateEntityByName("logic_relay");
	if( g_iLogicOut != -1 )
	{
		DispatchKeyValue(g_iLogicOut, "spawnflags", "2");
		DispatchKeyValue(g_iLogicOut, "targetname", "silver_relay_storm_blendout");

		// SILVER
		if( g_iCfgFogIdle2 )
		{
			Format(sTemp, sizeof(sTemp), "OnTrigger silver_fog_storm:SetStartDistLerpTo:%d:0:-1", g_iCfgFogIdle2);
			SetVariantString(sTemp);
			AcceptEntityInput(g_iLogicOut, "AddOutput");
		}
		if( g_iCfgFogIdle )
		{
			Format(sTemp, sizeof(sTemp), "OnTrigger silver_fog_storm:SetEndDistLerpTo:%d:0:-1", g_iCfgFogIdle);
			SetVariantString(sTemp);
			AcceptEntityInput(g_iLogicOut, "AddOutput");
		}
		if( g_fCfgFogOpaqueIdle )
		{
			Format(sTemp, sizeof(sTemp), "OnTrigger silver_fog_storm:Setmaxdensitylerpto:%f:0:-1", g_fCfgFogOpaqueIdle);
			SetVariantString(sTemp);
			AcceptEntityInput(g_iLogicOut, "AddOutput");
		}
		if( g_iCfgFogZIdle && g_iCfgFogZStorm )
		{
			Format(sTemp, sizeof(sTemp), "OnTrigger silver_fog_storm:SetFarZ:%d:1:-1", g_iCfgFogZIdle);
			SetVariantString(sTemp);
			AcceptEntityInput(g_iLogicOut, "AddOutput");
		}
		SetVariantString("OnTrigger silver_fog_storm:Set2DSkyboxFogFactorLerpTo:0:0:-1");
		AcceptEntityInput(g_iLogicOut, "AddOutput");
		SetVariantString("OnTrigger silver_fog_storm:StartFogTransition::0.1:-1");
		AcceptEntityInput(g_iLogicOut, "AddOutput");

		// STOLEN
		if( g_iCfgFogIdle2 )
		{
			Format(sTemp, sizeof(sTemp), "OnTrigger stolen_fog_storm:SetStartDistLerpTo:%d:0:-1", g_iCfgFogIdle2);
			SetVariantString(sTemp);
			AcceptEntityInput(g_iLogicOut, "AddOutput");
		}
		if( g_iCfgFogIdle )
		{
			Format(sTemp, sizeof(sTemp), "OnTrigger stolen_fog_storm:SetEndDistLerpTo:%d:0:-1", g_iCfgFogIdle);
			SetVariantString(sTemp);
			AcceptEntityInput(g_iLogicOut, "AddOutput");
		}
		if( g_fCfgFogOpaqueIdle )
		{
			Format(sTemp, sizeof(sTemp), "OnTrigger stolen_fog_storm:Setmaxdensitylerpto:%f:0:-1", g_fCfgFogOpaqueIdle);
			SetVariantString(sTemp);
			AcceptEntityInput(g_iLogicOut, "AddOutput");
		}
		if( g_iCfgFogZIdle && g_iCfgFogZStorm )
		{
			Format(sTemp, sizeof(sTemp), "OnTrigger stolen_fog_storm:SetFarZ:%d:1:-1", g_iCfgFogZIdle);
			SetVariantString(sTemp);
			AcceptEntityInput(g_iLogicOut, "AddOutput");
		}
		SetVariantString("OnTrigger stolen_fog_storm:Set2DSkyboxFogFactorLerpTo:0:0:-1");
		AcceptEntityInput(g_iLogicOut, "AddOutput");
		SetVariantString("OnTrigger stolen_fog_storm:StartFogTransition::0.1:-1");
		AcceptEntityInput(g_iLogicOut, "AddOutput");

		// RAIN
		alpha = g_iCfgRainStorm - g_iCfgRainIdle;
		Format(sTemp, sizeof(sTemp), "OnTrigger silver_rain:alpha:%d:0.5:-1", g_iCfgRainIdle + ((alpha / 4) * 2));
		SetVariantString(sTemp);
		AcceptEntityInput(g_iLogicOut, "AddOutput");
		Format(sTemp, sizeof(sTemp), "OnTrigger silver_rain:alpha:%d:1.0:-1", g_iCfgRainIdle + ((alpha / 4) * 3));
		SetVariantString(sTemp);
		AcceptEntityInput(g_iLogicOut, "AddOutput");
		Format(sTemp, sizeof(sTemp), "OnTrigger silver_rain:alpha:%d:1.5:-1", g_iCfgRainIdle + (alpha / 4));
		SetVariantString(sTemp);
		AcceptEntityInput(g_iLogicOut, "AddOutput");
		Format(sTemp, sizeof(sTemp), "OnTrigger silver_rain:alpha:%d:2.0:-1", g_iCfgRainIdle);
		SetVariantString(sTemp);
		AcceptEntityInput(g_iLogicOut, "AddOutput");

		// OTHER OUTPUTS
		SetVariantString("OnTrigger silver_relay_mix_blendout:Trigger::0:-1");
		AcceptEntityInput(g_iLogicOut, "AddOutput");

		DispatchSpawn(g_iLogicOut);
		ActivateEntity(g_iLogicOut);
		AcceptEntityInput(g_iLogicOut, "Trigger");

		HookSingleEntityOutput(g_iLogicOut, "OnTrigger", OnLogicOut);
	}
	else
		LogError("Failed to create g_iLogicOut 'logic_relay'");
}

public OnLogicOut(const String:output[], entity, activator, Float:delay)
{
	if( g_iCfgSnow && g_iCfgSnowIdle == 1 )
	{
		if( IsValidEntRef(g_iSnow) == false )
		{
			CreateSnow();
		}
	} else {
		if( IsValidEntRef(g_iSnow) )
		{
			AcceptEntityInput(g_iSnow, "Kill");
			g_iSnow = 0;
		}
	}
}

public OnLogicIn(const String:output[], entity, activator, Float:delay)
{
	if( g_iCfgSnow && g_iCfgSnowStorm == 1 )
	{
		if( IsValidEntRef(g_iSnow) == false )
		{
			CreateSnow();
		}
	} else {
		if( IsValidEntRef(g_iSnow) )
		{
			AcceptEntityInput(g_iSnow, "Kill");
			g_iSnow = 0;
		}
	}
}



// ====================================================================================================
//					sound_mix_layer
// ====================================================================================================
CreateMixer()
{
	g_iStormLayer = CreateEntityByName("sound_mix_layer");
	if( g_iStormLayer != -1 )
	{
		DispatchKeyValue(g_iStormLayer, "targetname", "silver_rainLayer_voip");
		DispatchKeyValue(g_iStormLayer, "MixLayerName", "stormLayer");
		DispatchKeyValue(g_iStormLayer, "Level", "1");

		DispatchSpawn(g_iStormLayer);
		ActivateEntity(g_iStormLayer);

		g_iStormLayer = EntIndexToEntRef(g_iStormLayer);
	}
	else
		LogError("Failed to create g_iStormLayer 'sound_mix_layer'");


	g_iVoip = CreateEntityByName("sound_mix_layer");
	if( g_iVoip != -1 )
	{
		DispatchKeyValue(g_iVoip, "targetname", "silver_rainLayer_voip");
		DispatchKeyValue(g_iVoip, "MixLayerName", "voipLayer");
		DispatchSpawn(g_iVoip);
		g_iVoip = EntIndexToEntRef(g_iVoip);
	}
	else
		LogError("Failed to create g_iVoip 'sound_mix_layer'");


	g_iVoipIn = CreateEntityByName("logic_relay");
	if( g_iVoipIn != -1 )
	{
		DispatchKeyValue(g_iVoipIn, "targetname", "silver_relay_mix_blendin");

		SetVariantString("OnTrigger silver_rainLayer_voip:Level:.2:0:-1");
		AcceptEntityInput(g_iVoipIn, "AddOutput");
		SetVariantString("OnTrigger silver_rainLayer_voip:Level:.4:1:-1");
		AcceptEntityInput(g_iVoipIn, "AddOutput");
		SetVariantString("OnTrigger silver_rainLayer_voip:Level:.6:2:-1");
		AcceptEntityInput(g_iVoipIn, "AddOutput");
		SetVariantString("OnTrigger silver_rainLayer_voip:Level:.8:3:-1");
		AcceptEntityInput(g_iVoipIn, "AddOutput");
		SetVariantString("OnTrigger silver_rainLayer_voip:Level:1:4:-1");
		AcceptEntityInput(g_iVoipIn, "AddOutput");

		DispatchSpawn(g_iVoipIn);
		ActivateEntity(g_iVoipIn);
	}
	else
		LogError("Failed to create g_iVoipIn 'logic_relay'");


	g_iVoipOut = CreateEntityByName("logic_relay");
	if( g_iVoipOut != -1 )
	{
		DispatchKeyValue(g_iVoipOut, "targetname", "silver_relay_mix_blendout");

		SetVariantString("OnTrigger silver_rainLayer_voip:Level:1:0:-1");
		AcceptEntityInput(g_iVoipOut, "AddOutput");
		SetVariantString("OnTrigger silver_rainLayer_voip:Level:.8:1:-1");
		AcceptEntityInput(g_iVoipOut, "AddOutput");
		SetVariantString("OnTrigger silver_rainLayer_voip:Level:.6:2:-1");
		AcceptEntityInput(g_iVoipOut, "AddOutput");
		SetVariantString("OnTrigger silver_rainLayer_voip:Level:.4:3:-1");
		AcceptEntityInput(g_iVoipOut, "AddOutput");
		SetVariantString("OnTrigger silver_rainLayer_voip:Level:.2:4:-1");
		AcceptEntityInput(g_iVoipOut, "AddOutput");

		DispatchSpawn(g_iVoipOut);
		ActivateEntity(g_iVoipOut);
	}
	else
		LogError("Failed to create g_iVoipOut 'logic_relay'");
}



// ====================================================================================================
//					env_sun
// ====================================================================================================
ToggleEnvSun(color)
{
	new env_sun = -1;
	while( (env_sun = FindEntityByClassname(env_sun, "env_sun")) != INVALID_ENT_REFERENCE )
	{
		if( g_iSunSaved == -1 )
		{
			g_iSunSaved = GetEntProp(env_sun, Prop_Send, "m_clrRender");
		}

		if( color == 0 )
			AcceptEntityInput(env_sun, "TurnOff");
		else
		{
			SetEntProp(env_sun, Prop_Send, "m_clrRender", color);
			AcceptEntityInput(env_sun, "TurnOn");
		}
	}
}



// ====================================================================================================
//					FOG CLOUDS
// ====================================================================================================
CreateClouds()
{
	new entity = FindEntityByClassname(-1, "sky_camera");

	if( entity != -1 )
	{
		decl Float:vPos[3];
		GetEntPropVector(entity, Prop_Data, "m_vecOrigin", vPos);

		g_iParticleFog = CreateEntityByName("info_particle_system");
		DispatchKeyValue(g_iParticleFog, "effect_name", PARTICLE_FOG);
		DispatchKeyValue(g_iParticleFog, "targetname", "silver_fx_skybox_general_lightning");
		DispatchSpawn(g_iParticleFog);
		ActivateEntity(g_iParticleFog);
		AcceptEntityInput(g_iParticleFog, "Start");
		g_iParticleFog = EntIndexToEntRef(g_iParticleFog);
		TeleportEntity(g_iParticleFog, vPos, NULL_VECTOR, NULL_VECTOR);
	}
}



// ====================================================================================================
//					env_fog_controller
// ====================================================================================================
CreateFog()
{

	new Float:FogDensity = GetConVarFloat(cvarFogDensity);
	new FogStartDist = GetConVarInt(cvarFogStartDist);
	new FogEndDist = GetConVarInt(cvarFogEndDist);
	
	if( g_iFogOn == 1 )
		return;
	g_iFogOn = 1;

	decl String:sTemp[8];
	new entity = -1;
	new count;

	entity = -1;
	while( (entity = FindEntityByClassname(entity, "env_fog_controller")) != INVALID_ENT_REFERENCE )
	{
		if( count < MAX_FOG )
		{
			GetEntPropString(entity, Prop_Data, "m_iName", g_sFogStolen[count], 64);
			g_iFogStolen[count][0] = EntIndexToEntRef(entity);
			g_iFogStolen[count][1] = GetEntProp(entity, Prop_Send, "m_fog.colorPrimary");
			g_iFogStolen[count][2] = GetEntProp(entity, Prop_Send, "m_fog.colorSecondary");
			g_iFogStolen[count][3] = GetEntProp(entity, Prop_Send, "m_fog.colorPrimaryLerpTo");
			g_iFogStolen[count][4] = GetEntProp(entity, Prop_Send, "m_fog.colorSecondaryLerpTo");
			g_fFogStolen[count][0] = GetEntPropFloat(entity, Prop_Send, "m_fog.start");
			g_fFogStolen[count][1] = GetEntPropFloat(entity, Prop_Send, "m_fog.end");
			g_fFogStolen[count][2] = GetEntPropFloat(entity, Prop_Send, "m_fog.maxdensity");
			g_fFogStolen[count][3] = GetEntPropFloat(entity, Prop_Send, "m_fog.farz");
			g_fFogStolen[count][4] = GetEntPropFloat(entity, Prop_Send, "m_fog.startLerpTo");
			g_fFogStolen[count][5] = GetEntPropFloat(entity, Prop_Send, "m_fog.endLerpTo");
			g_fFogStolen[count][6] = GetEntPropFloat(entity, Prop_Send, "m_fog.maxdensityLerpTo");
			g_fFogStolen[count][7] = GetEntPropFloat(entity, Prop_Send, "m_fog.duration");
			count++;
		}

		DispatchKeyValue(entity, "targetname", "stolen_fog_storm");
		DispatchKeyValue(entity, "use_angles", "1");
		DispatchKeyValue(entity, "fogstart", "1");
		
		DispatchKeyValueFloat(entity, "fogmaxdensity", FogDensity);
		SetVariantInt(FogStartDist);
		AcceptEntityInput(entity, "SetStartDist");
		if(FogEndDist != 0)
		{
			SetVariantInt(FogEndDist);
			AcceptEntityInput(entity, "SetEndDist");
		}
		
		DispatchKeyValue(entity, "heightFogStart", "0.0");
		DispatchKeyValue(entity, "heightFogMaxDensity", "1.0");
		DispatchKeyValue(entity, "heightFogDensity", "0.0");
		DispatchKeyValue(entity, "fogdir", "1 0 0");
		DispatchKeyValue(entity, "angles", "0 180 0");

		if( g_iCfgFogBlend != -1 )
		{
			IntToString(g_iCfgFogBlend, sTemp, sizeof(sTemp));
			DispatchKeyValue(entity, "foglerptime", sTemp);
		}

		if( strcmp(g_sCfgFogColor, "") )
		{
			DispatchKeyValue(entity, "fogcolor", g_sCfgFogColor);
			DispatchKeyValue(entity, "fogcolor2", g_sCfgFogColor);
			SetVariantString(g_sCfgFogColor);
			AcceptEntityInput(entity, "SetColorLerpTo");
		}
	}

	if( count == 0 )
	{
		g_iFog = CreateEntityByName("env_fog_controller");
		if( g_iFog != -1 )
		{
			DispatchKeyValue(g_iFog, "targetname", "silver_fog_storm");
			DispatchKeyValue(g_iFog, "use_angles", "1");
			DispatchKeyValue(g_iFog, "fogstart", "1");
			DispatchKeyValue(g_iFog, "fogmaxdensity", "1");
			DispatchKeyValue(g_iFog, "heightFogStart", "0.0");
			DispatchKeyValue(g_iFog, "heightFogMaxDensity", "1.0");
			DispatchKeyValue(g_iFog, "heightFogDensity", "0.0");
			DispatchKeyValue(g_iFog, "fogenable", "1");
			DispatchKeyValue(g_iFog, "fogdir", "1 0 0");
			DispatchKeyValue(g_iFog, "angles", "0 180 0");

			if( g_iCfgFogBlend != -1 )
			{
				IntToString(g_iCfgFogBlend, sTemp, sizeof(sTemp));
				DispatchKeyValue(g_iFog, "foglerptime", sTemp);
			}

			if( g_iCfgFogZIdle && g_iCfgFogZStorm )
			{
				IntToString(g_iCfgFogZIdle, sTemp, sizeof(sTemp));
				DispatchKeyValue(g_iFog, "farz", sTemp);
			}

			if( strcmp(g_sCfgFogColor, "") )
			{
				DispatchKeyValue(g_iFog, "fogcolor", g_sCfgFogColor);
				DispatchKeyValue(g_iFog, "fogcolor2", g_sCfgFogColor);
			}

			DispatchSpawn(g_iFog);
			ActivateEntity(g_iFog);

			TeleportEntity(g_iFog, Float:{ 10.0, 15.0, 20.0 }, NULL_VECTOR, NULL_VECTOR);
			g_iFog = EntIndexToEntRef(g_iFog);
		}
	}
}



// ====================================================================================================
//					func_precipitation
// ====================================================================================================
//					Create Rain
// ====================================================================================================
CreateRain()
{
	new value, entity = -1;
	while( (entity = FindEntityByClassname(entity, "func_precipitation")) != INVALID_ENT_REFERENCE )
	{
		value = GetEntProp(entity, Prop_Data, "m_nPrecipType");
		if( value < 0 || value == 4 || value > 5 )
			AcceptEntityInput(entity, "Kill");
	}

	for( new i = 0; i < g_iCfgRain; i++ )
	{
		entity = CreateEntityByName("func_precipitation");
		if( entity != -1 )
		{
			decl String:buffer[128];
			GetCurrentMap(buffer, sizeof(buffer));
			Format(buffer, sizeof(buffer), "maps/%s.bsp", buffer);

			DispatchKeyValue(entity, "model", buffer);
			DispatchKeyValue(entity, "targetname", "silver_rain");
			DispatchKeyValue(entity, "preciptype", "0");
			DispatchKeyValue(entity, "minSpeed", "25");
			DispatchKeyValue(entity, "maxSpeed", "35");

			g_iRains[i] = EntIndexToEntRef(entity);

			new Float:vMins[3], Float:vMaxs[3];
			GetEntPropVector(0, Prop_Data, "m_WorldMins", vMins);
			GetEntPropVector(0, Prop_Data, "m_WorldMaxs", vMaxs);
			SetEntPropVector(entity, Prop_Send, "m_vecMins", vMins);
			SetEntPropVector(entity, Prop_Send, "m_vecMaxs", vMaxs);

			decl Float:vBuff[3];
			vBuff[0] = vMins[0] + vMaxs[0];
			vBuff[1] = vMins[1] + vMaxs[1];
			vBuff[2] = vMins[2] + vMaxs[2];

			DispatchSpawn(entity);
			ActivateEntity(entity);
			TeleportEntity(entity, vBuff, NULL_VECTOR, NULL_VECTOR);
		}
		else
			LogError("Failed to create Rain %d 'func_precipitation'", i+1);
	}
}



// ====================================================================================================
//					Create Snow
// ====================================================================================================
CreateSnow()
{
	new value, entity = -1;
	while( (entity = FindEntityByClassname(entity, "func_precipitation")) != INVALID_ENT_REFERENCE )
	{
		value = GetEntProp(entity, Prop_Data, "m_nPrecipType");
		if( value < 0 || value == 4 || value > 5 )
			AcceptEntityInput(entity, "Kill");
	}

	entity = CreateEntityByName("func_precipitation");
	if( entity != -1 )
	{
		decl String:buffer[128];
		GetCurrentMap(buffer, sizeof(buffer));
		Format(buffer, sizeof(buffer), "maps/%s.bsp", buffer);

		DispatchKeyValue(entity, "model", buffer);
		DispatchKeyValue(entity, "targetname", "silver_snow");
		DispatchKeyValue(entity, "preciptype", "3");
		DispatchKeyValue(entity, "renderamt", "100");
		DispatchKeyValue(entity, "rendercolor", "200 200 200");

		g_iSnow = EntIndexToEntRef(entity);

		new Float:vBuff[3], Float:vMins[3], Float:vMaxs[3];
		GetEntPropVector(0, Prop_Data, "m_WorldMins", vMins);
		GetEntPropVector(0, Prop_Data, "m_WorldMaxs", vMaxs);
		SetEntPropVector(g_iSnow, Prop_Send, "m_vecMins", vMins);
		SetEntPropVector(g_iSnow, Prop_Send, "m_vecMaxs", vMaxs);

		new bool:found = false;
		for( new i = 1; i <= MaxClients; i++ )
		{
			if( !found && IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) )
			{
				found = true;
				GetClientAbsOrigin(i, vBuff);
			}
		}

		if( !found )
		{
			vBuff[0] = vMins[0] + vMaxs[0];
			vBuff[1] = vMins[1] + vMaxs[1];
			vBuff[2] = vMins[2] + vMaxs[2];
		}

		DispatchSpawn(g_iSnow);
		ActivateEntity(g_iSnow);
		TeleportEntity(g_iSnow, vBuff, NULL_VECTOR, NULL_VECTOR);
	}
	else
		LogError("Failed to create Snow %d 'func_precipitation'");
}



// ====================================================================================================
//					env_wind
// ====================================================================================================
CreateWind()
{
	g_iWind = CreateEntityByName("env_wind");
	if( g_iWind != -1 )
	{
		DispatchKeyValue(g_iWind, "targetname", "silverwind");
		DispatchKeyValue(g_iWind, "windradius", "-1");
		DispatchKeyValue(g_iWind, "minwind", "75");
		DispatchKeyValue(g_iWind, "mingustdelay", "15");
		DispatchKeyValue(g_iWind, "mingust", "100");
		DispatchKeyValue(g_iWind, "maxwind", "150");
		DispatchKeyValue(g_iWind, "maxgustdelay", "30");
		DispatchKeyValue(g_iWind, "maxgust", "200");
		DispatchKeyValue(g_iWind, "gustduration", "5");
		DispatchKeyValue(g_iWind, "gustdirchange", "20");
		DispatchSpawn(g_iWind);

		ActivateEntity(g_iWind);

		g_iWind = EntIndexToEntRef(g_iWind);
	}
	else
		LogError("Failed to create 'env_wind'");
}



// ====================================================================================================
//					SOUNDS
// ====================================================================================================
PlayAmbientSound(const String:sample[])
{
	if( IsValidEntRef(g_iSound) == false )
	{
		new entity = CreateEntityByName("ambient_generic");
		if( entity != -1 )
		{
			DispatchKeyValue(entity, "spawnflags", "17");
			DispatchKeyValue(entity, "message", sample);
			DispatchKeyValue(entity, "Volume", "10");
			DispatchKeyValue(entity, "health", "0");
			DispatchSpawn(entity);
			ActivateEntity(entity);
			TeleportEntity(entity, Float:{ 10.0, 20.0, 30.0 }, NULL_VECTOR, NULL_VECTOR);

			SetVariantString("OnUser1 !self:Volume:2:0.1:-1");
			AcceptEntityInput(entity, "AddOutput");
			SetVariantString("OnUser1 !self:Volume:4:0.2:-1");
			AcceptEntityInput(entity, "AddOutput");
			SetVariantString("OnUser1 !self:Volume:6:0.3:-1");
			AcceptEntityInput(entity, "AddOutput");
			SetVariantString("OnUser1 !self:Volume:8:0.4:-1");
			AcceptEntityInput(entity, "AddOutput");
			SetVariantString("OnUser1 !self:Volume:10:0.5:-1");
			AcceptEntityInput(entity, "AddOutput");
			AcceptEntityInput(entity, "FireUser1");

			g_iSound = EntIndexToEntRef(entity);
		}
	}
}

StopAmbientSound()
{
	if( g_iCfgRain != 0 || g_iCfgWind != 0 )
	{
		if( IsValidEntRef(g_iSound) == true )
		{
			SetVariantInt(0);
			AcceptEntityInput(g_iSound, "Volume");
			AcceptEntityInput(g_iSound, "Kill");
		}

		g_iSound = 0;
	}

	for( new i = 1; i <= MaxClients; i++ )
	{
		if( IsClientInGame(i) )
		{
			StopSound(i, SNDCHAN_AUTO, SOUND_WIND1);
			StopSound(i, SNDCHAN_AUTO, SOUND_WIND2);
			StopSound(i, SNDCHAN_AUTO, SOUND_WIND3);
			StopSound(i, SNDCHAN_AUTO, SOUND_WIND4);
		}
	}
}

PlaySoundRain()
{
	if( g_iCfgRain )
	{
		new random;
		random = GetRandomInt(1, 3);

		if( random == 1 )			PlayAmbientSound(SOUND_RAIN1);
		else if( random == 2 )		PlayAmbientSound(SOUND_RAIN2);
		else if( random == 3 )		PlayAmbientSound(SOUND_RAIN3);
	}
}

PlaySoundWind()
{
	if( g_iCfgWind )
	{
		if( g_iStormState <= STATE_IDLE )	g_iCfgWind = GetRandomInt(1, 4);
		else								g_iCfgWind = GetRandomInt(5, 8);

		if( g_iCfgWind == 1 )		EmitSoundToAll(SOUND_WIND1);
		else if( g_iCfgWind == 2 )	EmitSoundToAll(SOUND_WIND2, _, _, 42);
		else if( g_iCfgWind == 3 )	EmitSoundToAll(SOUND_WIND3, _, _, 43);
		else if( g_iCfgWind == 4 )	EmitSoundToAll(SOUND_WIND4, _, _, 42);
	}
}



// ====================================================================================================
//					OTHER
// ====================================================================================================
PrecacheParticle(const String:ParticleName[])
{
	new Particle = CreateEntityByName("info_particle_system");
	DispatchKeyValue(Particle, "effect_name", ParticleName);
	DispatchSpawn(Particle);
	ActivateEntity(Particle);
	AcceptEntityInput(Particle, "start");
	Particle = EntIndexToEntRef(Particle);
	SetVariantString("OnUser1 !self:Kill::0.1:-1");
	AcceptEntityInput(Particle, "AddOutput");
	AcceptEntityInput(Particle, "FireUser1");
}

bool:IsValidEntRef(entity)
{
	if( entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE )
		return true;
	return false;
}

stock HealEntityOverTime(client, Float:interval, increment, total)
{
	if (!IsValidClient(client))
		return;

	new maxhp=GetEntProp(client, Prop_Send, "m_iMaxHealth", 2);
	
	new Float:correcttemphealthpre = GetAccurateTempHealth(client) - 50.0;
	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", (correcttemphealthpre>=0) ? correcttemphealthpre : 0.0 );

	if(increment >= total)
	{
		HealTowardsMax(client, total, maxhp);
	}
	else
	{
		HealTowardsMax(client, increment, maxhp);
		new Handle:myDP;
		CreateDataTimer(interval, __HOT_ACTION, myDP,
			TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
		WritePackCell(myDP, client);
		WritePackCell(myDP, increment);
		WritePackCell(myDP, total-increment);
		WritePackCell(myDP, maxhp);
	}
}

IsValidClient(client)
{
	return client && IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == 2;
}

IsValidClientInfected(client)
{
	return client && IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == 3;
}

stock HealTowardsMax(client, amount, max)
{
	new Float:hb = float(amount) + GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
	new Float:overflow = (hb+GetClientHealth(client))-max;
	if(overflow > 0)
	{
		hb -= overflow;
	}
	//PrintToChatAll("hb: %f - overflow: %f - %f %f", hb, overflow,float(amount),GetEntPropFloat(client, Prop_Send, "m_healthBuffer"));
	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", hb);
}

public Action:__HOT_ACTION(Handle:timer, Handle:pack)
{
	ResetPack(pack);
	new client = ReadPackCell(pack);

	if (!IsValidClient(client))
		return Plugin_Stop;

	if (IsIncapacitated(client)){

		return Plugin_Stop;
	}

	new increment = ReadPackCell(pack);
	DataPackPos pos = GetPackPosition(pack);
	new remaining = ReadPackCell(pack);
	new maxhp = ReadPackCell(pack);

	//PrintToChatAll("HOT: %d %d %d %d", client, increment, remaining, maxhp);

	if(increment >= remaining)
	{
		HealTowardsMax(client, remaining, maxhp);
		return Plugin_Stop;
	}
	HealTowardsMax(client, increment, maxhp);
	SetPackPosition(pack, pos);
	WritePackCell(pack, remaining-increment);

	return Plugin_Continue;
}

bool:IsClientIndex(client)
{
	return (client > 0 && client <= MaxClients);
}

bool:IsSuivivorTeamFull() 
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && IsFakeClient(i))
		{
			return false;
		}
	}
	return true;
}

public IsValidBoomer(client)
{
	if (IsValidClientInfected(client))
	{
		new class = GetEntProp(client, Prop_Send, "m_zombieClass");
		
		if (class == 2)
			return true;
	}
	
	return false;
}

public Incap_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	decl String:weapon[16];
	GetEventString(event, "weapon", weapon, sizeof(weapon));
	SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0);
	CreateTimer(1.5,COLD_DOWN,client);
}
public Action:COLD_DOWN(Handle:timer,any:client)
{
	if(!IsClientAndInGame(client) || GetClientTeam(client) != 2) return;
	SetEntityHealth(client,GetConVarInt(FindConVar("survivor_incap_health")));
	
	if(GetConVarInt(FindConVar("survivor_allow_crawling")) == 1)
	{
		PrintHintText(client,"%T","l4d_storm4",client);
	}
}

public TC_ev_OnTeamChange(Handle:event, String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	CreateTimer(5.0,PlayerChangeTeamCheck,client);//延遲一秒檢查
}
public Action:PlayerChangeTeamCheck(Handle:timer,any:client)
{
	if (IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == 3)
	{
		if(!IsSuivivorTeamFull()){
			ClientCommand(client, "jointeam 2");
			return;
		}else{
			ChangeClientTeam(client, 1);
			return;
		}
	}
}
public Action:BoomerAbility_BileFeet(client)
{
	CreateTimer(0.5, Timer_BoomerBileFeet, client);
}

public Action:Timer_BoomerBileFeet(Handle:timer, any:client) 
{
	if (IsValidClientInfected(client))
	{
		SetEntDataFloat(client, laggedMovementOffset, 1.2, true);
	}
}	

public Action:PounceStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "victim"));
	Allow[client] = true;
}	

public Action:PounceEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "victim"));
	Allow[client] = false;
}

public Action:BRevive(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	Allow[client] = true;
}

public Action:ERevive(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	Allow[client] = false;
}

public Action:SRevive(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	Allow[client] = false;
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{

	if (IsClientInGame(client) && GetClientTeam(client) == 3 && IsPlayerAlive(client))
	{
		if(GetEntityMoveType(client) != MOVETYPE_LADDER)
		{
			// To make sure the SI is boosted only by this plugin.
			if(GetClientSpeed(client) == 2.5)
			{ 
				if(IsValidBoomer(client))
					SetEntDataFloat(client, laggedMovementOffset, 1.2, true);
				else
					SetClientSpeed(client, 1.0); 
			}
			return Plugin_Continue;
		}
		
		if(IsPlayerAlive(client)&&!IsInfectedGhost(client))
		{		
			SetClientSpeed(client, 2.5);
			return Plugin_Continue;
		}
	}
	
	if(IsFakeClient(client)||
	GetClientTeam(client) != 2 ||
	GetConVarInt(FindConVar("survivor_allow_crawling")) == 0) 
		return Plugin_Continue;
	
	if(IsIncapacitated(client) && buttons & IN_FORWARD)
	{
	
		if(Allow[client])
		{
			buttons &= ~IN_FORWARD;
			return Plugin_Handled;
		}
		// No clone, create
		if( g_iClone[client] == -1 )		// Animation not playing
		{
			PlayAnim(client);
			//CreateTimer(0.5,COLD22,client,TIMER_REPEAT);
		}
	}		
	else // Not holding forward/round over/not incapped, will restore if animation was playing
	{
		RestoreClient(client);
	}
	
	return Plugin_Continue;
}

public Action:COLD22(Handle:timer, any:client)
{
	if(IsValidClient(client))
		PrintToChatAll("%N - %d",client,GetEntProp(client, Prop_Send, "m_nSequence"));
}

PlayAnim(client)
{
	new iAnim;
	new String:sModel[42];
	GetEntPropString(client, Prop_Data, "m_ModelName", sModel, sizeof(sModel));

	if( sModel[26] == 'c' )
		iAnim = -1;
	else if( sModel[26] == 't' )						// t = Teenangst
		iAnim = ANIM_L4D_ZOEY;
	else if( sModel[26] == 'm' && sModel[27] == 'a')	// ma = Manager
		iAnim = ANIM_L4D_LOUIS;
	else if( sModel[26] == 'b' )						// b = Biker
		iAnim = ANIM_L4D_FRANCIS;
	else if( sModel[26] == 'n' )						// n = Namvet
		iAnim = ANIM_L4D_BILL;
	else
		return;

		
	if( iAnim == -1 )
	{
		g_iClone[client] = 0;
		return;
	}
	
	// Create survivor clone
	new clone = CreateEntityByName("prop_dynamic");
	if( clone == -1 )
	{
		LogError("Failed to create prop_dynamic '%s' (%N)", sModel, client);
		return;
	}

	SetEntityModel(clone, sModel);
	g_iClone[client] = EntIndexToEntRef(clone); // Global clone ID

	// Attach to survivor
	SetVariantString("!activator");
	AcceptEntityInput(clone, "SetParent", client);
	SetVariantString("bleedout");
	AcceptEntityInput(clone, "SetParentAttachment");

	// Correct angles and origin
	new Float:vPos[3],Float:vAng[3];
	vPos[0] = -2.0;
	vPos[1] = -15.0;
	vPos[2] = -10.0;
	vAng[0] = -330.0;
	vAng[1] = -100.0;
	vAng[2] = 70.0;

	// Set angles and origin
	TeleportEntity(clone, vPos, vAng, NULL_VECTOR);

	// Set animation and playback rate
	SetEntProp(clone, Prop_Send, "m_nSequence", iAnim);
	SetEntPropFloat(clone, Prop_Send, "m_flPlaybackRate", 15.0 / 15.0); // Default speed = 15, normal rate = 1.0

	SetEntityRenderMode(client, RENDER_NONE);

	GotoThirdPerson(client);
}

RestoreClient(client)
{
	if( g_iClone[client] == -1 )		// No anim playing
		return;
	else if( g_iClone[client] == 0 )	// Coach
		g_iClone[client] = -1;
	else
		RemoveClone(client);			// Delete clone
}
RemoveClone(client)
{
	new clone = g_iClone[client];
	g_iClone[client] = -1;

	if( clone && EntRefToEntIndex(clone) != INVALID_ENT_REFERENCE )
	{
		SetEntityRenderMode(client, RENDER_NORMAL);

		AcceptEntityInput(clone, "kill");
	}

	GotoFirstPerson(client);
}

GotoThirdPerson(client)
{
	SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", 0);
	SetEntProp(client, Prop_Send, "m_iObserverMode", 1);
	SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 0);
}

GotoFirstPerson(client)
{
	SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", -1);
	SetEntProp(client, Prop_Send, "m_iObserverMode", 0);
	SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 1);
}

stock bool:IsInfectedGhost(client) {
    return bool:GetEntProp(client, Prop_Send, "m_isGhost");
}

stock SetClientSpeed(client, Float:value)
{
	SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", value);
}

stock Float:GetClientSpeed(client)
{
	return Float:GetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue");
}

void PatchAddress(bool patch)
{
	static bool patched;

	if( !patched && patch )
	{
		patched = true;

		// Linux
		if( g_ByteCount == 1 )
		{
			StoreToAddress(g_Address + view_as<Address>(1), 0x89, NumberType_Int8);
		}
		else
		{
			for( int i = 0; i < g_ByteCount; i++ )
				StoreToAddress(g_Address + view_as<Address>(i), 0x90, NumberType_Int8);
		}
	}
	else if( patched && !patch )
	{
		patched = false;
		for( int i = 0; i < g_ByteCount; i++ )
			StoreToAddress(g_Address + view_as<Address>(i), g_ByteSaved[i], NumberType_Int8);
	}
}