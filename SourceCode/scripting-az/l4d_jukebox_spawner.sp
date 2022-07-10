#define PLUGIN_VERSION 		"1.8"

/*=======================================================================================
	Plugin Info:

*	Name	:	[L4D2] Jukebox Spawner
*	Author	:	SilverShot (idea by 8bit)
*	Descrp	:	Auto-spawn jukeboxes on round start.
*	Link	:	http://forums.alliedmods.net/showthread.php?t=149084

========================================================================================
	Change Log:
1.7 (2018-5-4)
	-L4D1 modify by Harry.
	
1.6 (21-Jul-2013)
	- Removed Sort_Random work-around. This was fixed in SourceMod 1.4.7, all should update or spawning issues will occur.

1.5 (10-May-2012)
	- Added cvar "l4d2_jukebox_allow" to turn the plugin on and off.
	- Added cvar "l4d2_jukebox_modes" to control which game modes the plugin works in.
	- Added cvar "l4d2_jukebox_modes_tog" same as above.
	- Removed max entity check and related error logging.
	- Small changes and fixes.

1.4 (01-Dec-2011)
	- Added Jukeboxes to these maps: Crash Course, Dead Air, Death Toll, Blood Harvest, Cold Stream.
	- Added command "sm_juketracks" to list tracks read from the config and which will play.
	- Changed command "sm_jukelist" to list all Jukebox positions on the current map.
	- Creates Jukeboxes when the plugin is loaded and removes when unloaded.
	- Fixed "l4d2_jukebox_modes_disallow" cvar not working all the time.

1.3 (19-May-2011)
	- Fixed sm_jukestop not working.

1.2 (19-May-2011)
	- Fixed no tracks loading if a "random" section was not specified. Valve default tracks will be loaded into the "main" section.
	- Fixed CPrintToChatAll() error.

1.1 (19-May-2011)
	- Added a "main" section to the keyvalue config which sets a specific track to a specific number for all maps.
	- Added a "random" section to the keyvalue config. Tracks will be randomly be selected from here.
	- Added cvar "l4d2_jukebox_horde_notify" to display a hint when the jukebox triggers a horde.
	- Added command "sm_jukelist" to display a list of randomly selected tracks as well as the override, random and main tracks loaded.
	- Added a check to avoid spawning footlockers when there are too many entities.
	- Added Jukeboxes to saferooms in the the Cold Stream campaign.
	- Changed sm_juke and sm_jukebox to spawn jukeboxes with specified tracks from the "main" and "random" sections and uses overrides for that map if available.
	- Limited sm_jukenext and sm_jukestop to survivor team and admins with 'z' flag only.

1.0 (01-Dec-2011)
	- Initial release.

========================================================================================

	This plugin was made using source code from the following plugins.
	If I have used your code and not credited you, please let me know.

*	Thanks to "Zuko & McFlurry" for "[L4D2] Weapon/Zombie Spawner" - Modified the SetTeleportEndPoint()
	http://forums.alliedmods.net/showthread.php?t=109659

======================================================================================*/

#pragma semicolon 			1

#include <sourcemod>
#include <sdktools>
#include <multicolors>

#define CVAR_FLAGS			FCVAR_PLUGIN|FCVAR_NOTIFY
#define CHAT_TAG			"{green}[Jukebox] {default}"
#define CONFIG_SPAWNS		"data/l4d1_jukebox_spawns.cfg"
#define MAX_JUKEBOXES		2
#define MAX_ENT_STORE		18

#define MODEL_BODY			"models/props_unique/jukebox01_body.mdl"
#define MODEL_JUKE			"models/props_unique/jukebox01.mdl"
#define MODEL_MENU			"models/props_unique/jukebox01_menu.mdl"
#define MUSIC_WAIT_TIME	    5

//static  Handle:g_hVolume;
static	Handle:g_hCvarAllow,
		bool:g_bCvarAllow, bool:g_bSpawned, Float:fMenuPos[3] = { 0.0, -12.0, 12.0 };

static	g_iPlayerSpawn, g_iRoundStart,
		g_music_entity,g_music,g_music_playing_wait_time,
		g_iJukeboxes;

new Float:musicvPos[MAX_JUKEBOXES][3], Float:musicvAng[MAX_JUKEBOXES][3];

// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================
public Plugin:myinfo =
{
	name = "[L4D1] Jukebox",
	author = "SilverShot",
	description = "Auto-spawn jukeboxes on round start.L4D1 modify by Harry",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=149084"
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

public OnPluginStart()
{
	LoadTranslations("Roto2-AZ_mod.phrases");
	g_hCvarAllow = CreateConVar(	"l4d_jukebox_allow",			"1",			"0=Plugin off, 1=Plugin on.", FCVAR_NOTIFY );
	//g_hVolume = CreateConVar("jukebox_volume", "75", "jukebox volume", FCVAR_PLUGIN, true, 0.0, true, 200.0);
	RegConsoleCmd(	"sm_jukestop",		CmdJukeStop, 	"Stops the jukeox playing.");

	HookConVarChange(g_hCvarAllow,		ConVarChanged_Allow);
}
Handle:OpenConfig(bool:create = true)
{
	// Create config if it does not exist
	decl String:sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "%s", CONFIG_SPAWNS);
	if( !FileExists(sPath) )
	{
		if( create == false )
			return INVALID_HANDLE;

		new Handle:hCfg = OpenFile(sPath, "w");
		WriteFileLine(hCfg, "");
		CloseHandle(hCfg);
	}

	// Open the jukebox config
	new Handle:hFile = CreateKeyValues("jukeboxes");
	if( !FileToKeyValues(hFile, sPath) )
	{
		CloseHandle(hFile);
		return INVALID_HANDLE;
	}

	return hFile;
}

public OnPluginEnd()
{
	ResetPlugin();
}
static g_iMapStarted;
public OnMapStart()
{
	g_music_entity = -1, g_music = 0,g_music_playing_wait_time = 0;
	g_iJukeboxes = 0;
	g_iMapStarted = 1;

	PrecacheModel(MODEL_BODY, true);
	PrecacheModel(MODEL_JUKE, true);
	PrecacheModel(MODEL_MENU, true);
}

public OnMapEnd()
{
	g_iMapStarted = 0;
	ResetPlugin();
}



// ====================================================================================================
//					CVARS
// ====================================================================================================
public OnConfigsExecuted()
	IsAllowed();

public ConVarChanged_Allow(Handle:convar, const String:oldValue[], const String:newValue[])
	IsAllowed();

IsAllowed()
{
	new bool:bCvarAllow = GetConVarBool(g_hCvarAllow);

	if( g_bCvarAllow == false && bCvarAllow == true )
	{
		if( g_iMapStarted == 1 )
			LoadJukeboxes();
		g_bCvarAllow = true;

		HookEvent("round_start",		Event_RoundStart,	EventHookMode_PostNoCopy);
		HookEvent("player_spawn",		Event_PlayerSpawn,	EventHookMode_PostNoCopy);
		HookEvent("round_end",			Event_RoundEnd,		EventHookMode_PostNoCopy);
		HookEvent("player_use",			Event_PlayerUse);
	}

	else if( g_bCvarAllow == true && (bCvarAllow == false) )
	{
		ResetPlugin();
		g_bCvarAllow = false;

		UnhookEvent("round_start",		Event_RoundStart,	EventHookMode_PostNoCopy);
		UnhookEvent("player_spawn",		Event_PlayerSpawn,	EventHookMode_PostNoCopy);
		UnhookEvent("round_end",		Event_RoundEnd,		EventHookMode_PostNoCopy);
		UnhookEvent("player_use",		Event_PlayerUse);
	}
}



// ====================================================================================================
//					COMMANDS - JUKEBOX
// ====================================================================================================

public bool:TraceEntityFilterPlayer(entity, contentsMask)
{
	return entity > MaxClients || !entity;
}



// ====================================================================================================
//					COMMANDS - STOP
// ====================================================================================================

public Action:CmdJukeStop(client, args)//any survivor or infected can stop the music
{
	if( !client || GetClientTeam(client) == 1  )
		return Plugin_Handled;

	CPrintToChatAll("%s{olive}%N {default}%t", CHAT_TAG, client,"stopped jukebox playing.");
	StopAllSound();
	return Plugin_Handled;
}



// ====================================================================================================
//					STUFF / CLEAN UP
// ====================================================================================================
ResetPlugin()
{
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
	g_bSpawned = false;

	StopAllSound();
	g_iJukeboxes=0;
}

StopAllSound()
{
	//stop previous music
	new entity = g_music_entity;
	if(IsValidEntRef(entity))
	{
		SetVariantInt(0);
		AcceptEntityInput(entity , "Volume");
		AcceptEntityInput(entity, "Kill");
	}
}

bool:IsValidEntRef(entity)
{
	if( entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE )
		return true;
	return false;
}


// ====================================================================================================
//					LOAD JUKEBOXES
// ====================================================================================================
public Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
	g_bSpawned = false;
	g_iJukeboxes=0;
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	if( g_iPlayerSpawn == 1 && g_iRoundStart == 0)
		CreateTimer(1.0, tmrMake, TIMER_FLAG_NO_MAPCHANGE);
	g_iRoundStart = 1;
}

public Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	if( g_iPlayerSpawn == 0 && g_iRoundStart == 1)
		CreateTimer(1.0, tmrMake, TIMER_FLAG_NO_MAPCHANGE);
	g_iPlayerSpawn = 1;
}

public Action:tmrMake(Handle:timer)
{
	LoadJukeboxes();
}

LoadJukeboxes()
{
	if( g_bSpawned )
		return;

	// Load config
	new Handle:hFile = OpenConfig(false);
	if( hFile == INVALID_HANDLE )
		return;

	// Check for current map in the config
	decl String:sMap[64];
	GetCurrentMap(sMap, 64);

	if( !KvJumpToKey(hFile, sMap) )
	{
		CloseHandle(hFile);
		return;
	}

	// Retrieve how many jukeboxes to display
	new iCount = KvGetNum(hFile, "num", 0);
	if( iCount == 0 )
	{
		CloseHandle(hFile);
		return;
	}

	if( iCount > MAX_JUKEBOXES )
		iCount = MAX_JUKEBOXES;

	// Get jukebox vectors and tracks
	decl String:sTemp[10],Float:vPos[3], Float:vAng[3];

	for( new i = 1; i <= iCount; i++ )
	{
		Format(sTemp, sizeof(sTemp), "angle%d", i);
		KvGetVector(hFile, sTemp, vAng);
		Format(sTemp, sizeof(sTemp), "origin%d", i);
		KvGetVector(hFile, sTemp, vPos);
		MakeJukebox(vPos, vAng);
		musicvPos[i-1] = vPos;musicvAng[i-1] =vAng;
	}

	CloseHandle(hFile);
	g_bSpawned = true;
}



// ====================================================================================================
//					CREATE JUKEBOX
// ====================================================================================================

SetPositionInfront(Float:vPos[3], const Float:vAng[3], Float:fDist)
{
	decl Float:vAngles[3], Float:vBuffer[3];

	vAngles = vAng;
	vAngles[1] += 90.0;

	GetAngleVectors(vAngles, vBuffer, NULL_VECTOR, NULL_VECTOR);

	vPos[0] += ( vBuffer[0] * fDist);
	vPos[1] += ( vBuffer[1] * fDist);
	vPos[2] += 32.0;
}
GetJukeboxID()
{
	return g_iJukeboxes++;
}
MakeJukebox(const Float:vOrigin[3], const Float:vAngles[3])
{
	decl String:sTemp[64], Float:vPos[3], Float:vAng[3];
	new entity, iDJukebox = GetJukeboxID();

	if( iDJukebox == -1 ) // This should never happen
		return;

	vPos = vOrigin;
	vAng = vAngles;
	// Prop - Jukebox player
	new player;
	entity = CreateEntityByName("prop_dynamic");
	if( entity != -1 )
	{
		SetEntityModel(entity, MODEL_JUKE);
		Format(sTemp, sizeof(sTemp), "jb%d-jukebox_body_model", iDJukebox);
		DispatchKeyValue(entity, "targetname", sTemp);
		DispatchKeyValue(entity, "spawnflags", "0");
		DispatchKeyValue(entity, "solid", "6");
		DispatchKeyValue(entity, "disableshadows", "1");
		DispatchKeyValue(entity, "DefaultAnim", "idle");
		DispatchKeyValue(entity, "fademaxdist", "850");
		DispatchKeyValue(entity, "fademindist", "700");

		Format(sTemp, sizeof(sTemp), "OnUser1 jb0-jukebox_script:runscriptcode:PlaySong():0:-1");
		SetVariantString(sTemp);
		AcceptEntityInput(entity, "AddOutput");
		Format(sTemp, sizeof(sTemp), "OnUser1 jb0-jukebox_button:Unlock::0.2:-1");
		SetVariantString(sTemp);
		AcceptEntityInput(entity, "AddOutput");

		DispatchSpawn(entity);
		TeleportEntity(entity, vPos, vAng, NULL_VECTOR);
		player = entity;
	}


	// Prop - Jukebox body (prop_static)
	entity = CreateEntityByName("prop_dynamic");
	if( entity != -1 )
	{
		SetEntityModel(entity, MODEL_BODY);
		DispatchKeyValue(entity, "solid", "6");
		DispatchSpawn(entity);
		TeleportEntity(entity, vPos, vAng, NULL_VECTOR);

		// Attach menu to jukebox
		SetVariantString("!activator"); 
		AcceptEntityInput(entity, "SetParent", player);

	}


	// Prop - Jukebox menu
	entity = CreateEntityByName("prop_dynamic");
	if( entity != -1 )
	{
		SetEntityModel(entity, MODEL_MENU);
		Format(sTemp, sizeof(sTemp), "jb%d-jukebox_menu_model", iDJukebox);
		DispatchKeyValue(entity, "targetname", sTemp);
		DispatchKeyValue(entity, "spawnflags", "0");
		DispatchKeyValue(entity, "solid", "6");
		DispatchKeyValue(entity, "disableshadows", "1");
		DispatchSpawn(entity);

		// Attach menu to jukebox
		SetVariantString("!activator"); 
		AcceptEntityInput(entity, "SetParent", player);

		TeleportEntity(entity, fMenuPos, Float:{ 0.0, 0.0, 0.0 }, NULL_VECTOR);
	}


	// Func_Button to trigger music
	entity = CreateEntityByName("func_button");
	if( entity != -1 )
	{
		Format(sTemp, sizeof(sTemp), "jb%d-jukebox_button", iDJukebox);
		DispatchKeyValue(entity, "targetname", sTemp);
		DispatchKeyValue(entity, "solid", "0");
		DispatchKeyValue(entity, "spawnflags", "1057");
		DispatchKeyValue(entity, "wait", "-1");
		DispatchKeyValue(entity, "speed", "0");
		DispatchKeyValue(entity, "movedir", "0");

		//Format(sTemp, sizeof(sTemp), "OnPressed jb0-jukebox_script:runscriptcode:SwitchRecords():0:-1");
		//SetVariantString(sTemp);
		//AcceptEntityInput(entity, "AddOutput");
		//SetVariantString("OnPressed !self:Lock::0:-1");
		//AcceptEntityInput(entity, "AddOutput");
		SetPositionInfront(vPos, vAng, -15.0);
		vPos[2] -= 10.0;
		vAng[1] += 90.0;
		TeleportEntity(entity, vPos, vAng, NULL_VECTOR);
		vPos = vOrigin;
		vAng = vAngles;
		DispatchSpawn(entity);
	}


	// Create Light_Dynamic
	entity = CreateEntityByName("light_dynamic");
	if( entity != -1)
	{
		DispatchKeyValue(entity, "_light", "241 207 143 100");
		DispatchKeyValue(entity, "brightness", "0");
		DispatchKeyValueFloat(entity, "spotlight_radius", 72.0);
		DispatchKeyValueFloat(entity, "distance", 128.0);
		DispatchKeyValue(entity, "_cone", "75");
		DispatchKeyValue(entity, "_inner_cone", "75");
		DispatchKeyValue(entity, "pitch", "0");
		DispatchKeyValue(entity, "style", "0");
		DispatchSpawn(entity);
		AcceptEntityInput(entity, "TurnOn");

		SetPositionInfront(vPos, vAng, -20.0);
		vAng[1] -= 90.0; // Correct rotation
		vAng[0] = 85.0; // Point down
		TeleportEntity(entity, vPos, vAng, NULL_VECTOR);
		vPos = vOrigin;
		vAng = vAngles;
	}
}

public Event_PlayerUse (Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId( GetEventInt(event, "userid") );
	if(!client|| client<0||GetClientTeam(client) != 2) return;
	new iEntid=GetEventInt(event,"targetid");
	//debug
	//new String:st_entname[32];
	//GetEdictClassname(iEntid,st_entname,32);
	//CPrintToChatAll("client = %N, iEntid = %i",client,iEntid);
	//CPrintToChatAll("edict classname = %s",st_entname);
	decl String:targetname[128];
	GetEntPropString(iEntid, Prop_Data, "m_iName", targetname, sizeof(targetname));
	//CPrintToChatAll("targetname = %s",targetname);
	new number=-1;
	if (StrEqual(targetname,"jb0-jukebox_button")) number=0;
	else if (StrEqual(targetname,"jb1-jukebox_button")) number=1;
	if (number+1)
	{
		if(g_music_playing_wait_time>0)
		{
			CPrintToChat(client,"%s{default} %T", CHAT_TAG,"Wait seconds to play a song again.",client,g_music_playing_wait_time);
			return;
		}
		//stop previous music
		new entity = g_music_entity;
		if(IsValidEntRef(entity))
		{
			SetVariantInt(0);
			AcceptEntityInput(entity , "Volume");
			AcceptEntityInput(entity, "Kill");
		}
		// new Music
		// 
		entity = CreateEntityByName("ambient_generic");
		if( IsValidEntRef(entity) )
		{
			new random;
			random = GetRandomInt(1, 7);
			while(random)
			{
				if(random!=g_music){g_music = random;break;}
				random = GetRandomInt(1, 7); //The jukebox plays a max of 7 tracks, the last 2 rarely play.
			}
			switch(random)
			{
				case 1: {
					DispatchKeyValue(entity, "targetname", "music_track1");
					DispatchKeyValue(entity, "message", "Jukebox.BadMan1");
				}
				case 2: {
					DispatchKeyValue(entity, "targetname", "music_track2");
					DispatchKeyValue(entity, "message", "Jukebox.Ridin1");
				}
				case 3: {
					DispatchKeyValue(entity, "targetname", "music_track3");
					DispatchKeyValue(entity, "message", "Jukebox.AllIWantForXmas");
				}
				case 4: {
					DispatchKeyValue(entity, "targetname", "music_track4");
					DispatchKeyValue(entity, "message", "Jukebox.saints_will_never_come");
				}
				case 5: {
					DispatchKeyValue(entity, "targetname", "music_track6");
					DispatchKeyValue(entity, "message", "Jukebox.still_alive");
				}
				case 6: {
					DispatchKeyValue(entity, "targetname", "music_track8");
					DispatchKeyValue(entity, "message", "Jukebox.SaveMeSomeSugar");
				}
				case 7: {
					DispatchKeyValue(entity, "targetname", "music_track10");
					DispatchKeyValue(entity, "message", "Jukebox.re_your_brains");
				}
			}
			DispatchKeyValue(entity, "spawnflags", "48");
			DispatchKeyValue(entity, "radius", "1250");
			//decl String:Volume[3];
			//GetConVarString(g_hVolume, Volume, sizeof(Volume));
			//DispatchKeyValue(entity, "volume", Volume);
			DispatchKeyValue(entity, "volume", "75");
			DispatchKeyValue(entity, "pitchstart", "100");
			DispatchKeyValue(entity, "pitch", "100");
			DispatchSpawn(entity);
			ActivateEntity(entity);
			if(number)
				TeleportEntity(entity, musicvPos[1], musicvAng[1], NULL_VECTOR);
			else
				TeleportEntity(entity, musicvPos[0], musicvAng[0], NULL_VECTOR);
			AcceptEntityInput(entity, "PlaySound");
			g_music_entity = EntIndexToEntRef(entity);
			g_music_playing_wait_time = MUSIC_WAIT_TIME;
			CreateTimer(1.0, g_music_playing_false,_, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		}	
	}
}
public Action:g_music_playing_false(Handle:timer)
{
	if(g_music_playing_wait_time> 0)
	{
		g_music_playing_wait_time--;
	}
	if(g_music_playing_wait_time <= 0)
		return Plugin_Stop;
	return Plugin_Continue;
	
}
/*
IsJukeBoxMusiclist(const String:name[])
{
	if(StrEqual(name,"music_track1")||StrEqual(name,"music_track2")||StrEqual(name,"music_track3")||StrEqual(name,"music_track4")||StrEqual(name,"music_track6")||StrEqual(name,"music_track8"))
		return true;
	else
		return false;
}
*/