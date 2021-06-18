#define PLUGIN_VERSION 		"1.2"

/*=======================================================================================
	Plugin Info:

*	Name	:	[L4D & L4D2] Fire Glow
*	Author	:	SilverShot
*	Descrp	:	Creates a dynamic light where Molotovs, Gascans and Firework Crates burn.
*	Link	:	http://forums.alliedmods.net/showthread.php?t=186617

========================================================================================
	Change Log:

1.2 (30-Jun-2012)
	- Fixed the plugin not working in L4D1.

1.1 (20-Jun-2012)
	- Added cvars "l4d_fire_glow_modes", "l4d_fire_glow_modes_off" and "l4d_fire_glow_modes_tog" to control which modes turn on the plugin.

1.0 (02-Jun-2012)
	- Initial release.

======================================================================================*/

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define CVAR_FLAGS			FCVAR_PLUGIN|FCVAR_NOTIFY
#define MAX_LIGHTS			8

static	Handle:g_hMPGameMode, Handle:g_hCvarAllow, Handle:g_hCvarModes, Handle:g_hCvarModesOff, Handle:g_hCvarModesTog,
		Handle:g_hCvarDist, Handle:g_hCvarColor1, Handle:g_hCvarColor2, Float:g_fCvarDist, String:g_sCvarCols1[12], String:g_sCvarCols2[12],
		Handle:g_hInferno, Float:g_fInferno, bool:g_bCvarAllow, bool:g_bLeft4Dead2, bool:g_bStarted, g_iEntities[MAX_LIGHTS][2];



// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================
public Plugin:myinfo =
{
	name = "[L4D & L4D2] Fire Glow",
	author = "SilverShot",
	description = "Creates a dynamic light where Molotovs, Gascans and Firework Crates burn.",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=186617"
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	decl String:sGameName[12];
	GetGameFolderName(sGameName, sizeof(sGameName));
	if( strcmp(sGameName, "left4dead", false) == 0 ) g_bLeft4Dead2 = false;
	else if( strcmp(sGameName, "left4dead2", false) == 0 ) g_bLeft4Dead2 = true;
	else
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public OnPluginStart()
{
	g_hCvarAllow =			CreateConVar(	"l4d_fire_glow_allow",			"1",			"0=Plugin off, 1=Plugin on.", CVAR_FLAGS );
	g_hCvarModes =			CreateConVar(	"l4d_fire_glow_modes",			"",				"Turn on the plugin in these game modes, separate by commas (no spaces). (Empty = all).", CVAR_FLAGS );
	g_hCvarModesOff =		CreateConVar(	"l4d_fire_glow_modes_off",		"",				"Turn off the plugin in these game modes, separate by commas (no spaces). (Empty = none).", CVAR_FLAGS );
	if( g_bLeft4Dead2 )
		g_hCvarModesTog =	CreateConVar(	"l4d_fire_glow_modes_tog",		"0",			"Turn on the plugin in these game modes. 0=All, 1=Coop, 2=Survival, 4=Versus, 8=Scavenge. Add numbers together.", CVAR_FLAGS );
	g_hCvarDist =			CreateConVar(	"l4d_fire_glow_distance",		"250.0",		"How far does the dynamic light illuminate the area.", CVAR_FLAGS );
	if( g_bLeft4Dead2 )
		g_hCvarColor1 =		CreateConVar(	"l4d_fire_glow_fireworks",		"255 100 0",	"The light color for Firework Crate explosions. Three values between 0-255 separated by spaces. RGB Color255 - Red Green Blue.", CVAR_FLAGS );
	g_hCvarColor2 =			CreateConVar(	"l4d_fire_glow_inferno",		"255 25 0",		"The light color for <olotov and Gascan fires. Three values between 0-255 separated by spaces. RGB Color255 - Red Green Blue.", CVAR_FLAGS );
	CreateConVar(							"l4d_fire_glow_version",		PLUGIN_VERSION,	"Molotov and Gascan Glow plugin version.", CVAR_FLAGS|FCVAR_REPLICATED|FCVAR_DONTRECORD);
	AutoExecConfig(true,					"l4d_fire_glow");

	g_hMPGameMode = FindConVar("mp_gamemode");
	HookConVarChange(g_hCvarModes,			ConVarChanged_Allow);
	HookConVarChange(g_hCvarModesOff,		ConVarChanged_Allow);
	if( g_bLeft4Dead2 )
		HookConVarChange(g_hCvarModesTog,		ConVarChanged_Allow);
	HookConVarChange(g_hCvarAllow,			ConVarChanged_Allow);
	g_hInferno = FindConVar("inferno_flame_lifetime");
	HookConVarChange(g_hInferno,			ConVarChanged_Cvars);
	HookConVarChange(g_hCvarDist,			ConVarChanged_Cvars);
	if( g_bLeft4Dead2 )
		HookConVarChange(g_hCvarColor1,		ConVarChanged_Cvars);
	HookConVarChange(g_hCvarColor2,			ConVarChanged_Cvars);
}

public OnMapStart()
{
	g_bStarted = true;
}

public OnMapEnd()
{
	g_bStarted = false;
}



// ====================================================================================================
//					CVARS
// ====================================================================================================
public OnConfigsExecuted()
	IsAllowed();

public ConVarChanged_Cvars(Handle:convar, const String:oldValue[], const String:newValue[])
	GetCvars();

public ConVarChanged_Allow(Handle:convar, const String:oldValue[], const String:newValue[])
	IsAllowed();

GetCvars()
{
	g_fCvarDist = GetConVarFloat(g_hCvarDist);
	if( g_bLeft4Dead2 )
		GetConVarString(g_hCvarColor1, g_sCvarCols1, sizeof(g_sCvarCols1));
	GetConVarString(g_hCvarColor2, g_sCvarCols2, sizeof(g_sCvarCols2));
	g_fInferno = GetConVarFloat(g_hInferno);
}

IsAllowed()
{
	new bool:bCvarAllow = GetConVarBool(g_hCvarAllow);
	new bool:bAllowMode = IsAllowedGameMode();
	GetCvars();

	if( g_bCvarAllow == false && bCvarAllow == true && bAllowMode == true )
	{
		g_bCvarAllow = true;
	}

	else if( g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false) )
	{
		g_bCvarAllow = false;
	}
}

static g_iCurrentMode;

bool:IsAllowedGameMode()
{
	if( g_hMPGameMode == INVALID_HANDLE )
		return false;

	if( g_bLeft4Dead2 )
	{
		new iCvarModesTog = GetConVarInt(g_hCvarModesTog);
		if( iCvarModesTog != 0 )
		{
			g_iCurrentMode = 0;

			new entity = CreateEntityByName("info_gamemode");
			DispatchSpawn(entity);
			HookSingleEntityOutput(entity, "OnCoop", OnGamemode, true);
			HookSingleEntityOutput(entity, "OnSurvival", OnGamemode, true);
			HookSingleEntityOutput(entity, "OnVersus", OnGamemode, true);
			HookSingleEntityOutput(entity, "OnScavenge", OnGamemode, true);
			AcceptEntityInput(entity, "PostSpawnActivate");
			AcceptEntityInput(entity, "Kill");

			if( g_iCurrentMode == 0 )
				return false;

			if( !(iCvarModesTog & g_iCurrentMode) )
				return false;
		}
	}

	decl String:sGameModes[64], String:sGameMode[64];
	GetConVarString(g_hMPGameMode, sGameMode, sizeof(sGameMode));
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
//					LIGHTS
// ====================================================================================================
public OnEntityDestroyed(entity)
{
	if( g_bCvarAllow && g_bStarted && entity > MaxClients )
	{
		entity = EntIndexToEntRef(entity);

		for( new i = 0; i < MAX_LIGHTS; i++ )
		{
			if( entity == g_iEntities[i][1] )
			{
				if( IsValidEntRef(g_iEntities[i][0]) )
				{
					AcceptEntityInput(g_iEntities[i][0], "Kill");
				}

				g_iEntities[i][0] = 0;
				g_iEntities[i][1] = 0;
				break;
			}
		}
	}
}

public OnEntityCreated(entity, const String:classname[])
{
	if( g_bCvarAllow && g_bStarted )
	{
		if( strcmp(classname, "inferno") == 0 )
			CreateTimer(0.1, TimerCreate, EntIndexToEntRef(entity));
		else if( g_bLeft4Dead2 == true && strcmp(classname, "fire_cracker_blast") == 0 )
			CreateTimer(0.1, TimerCreate, EntIndexToEntRef(entity));
	}
}

public Action:TimerCreate(Handle:timer, any:target)
{
	if( (target = EntRefToEntIndex(target)) != INVALID_ENT_REFERENCE )
	{
		new index = -1;

		for( new i = 0; i < MAX_LIGHTS; i++ )
		{
			if( IsValidEntRef(g_iEntities[i][0]) == false )
			{
				index = i;
				break;
			}
		}

		if( index == -1 )
			return;
	
		decl String:sTemp[64];
		GetEdictClassname(target, sTemp, 2);
		new entity = CreateEntityByName("light_dynamic");
		if( entity == -1)
		{
			LogError("Failed to create 'light_dynamic'");
			return;
		}

		g_iEntities[index][0] = EntIndexToEntRef(entity);
		g_iEntities[index][1] = EntIndexToEntRef(target);

		new Float:fInfernoTime = g_fInferno;
		if( sTemp[0] == 'i' )
		{
			Format(sTemp, sizeof(sTemp), "%s 255", g_sCvarCols2);
		}
		else
		{
			fInfernoTime -= 1.5;
			Format(sTemp, sizeof(sTemp), "%s 255", g_sCvarCols1);
		}

		DispatchKeyValue(entity, "_light", sTemp);
		DispatchKeyValue(entity, "brightness", "3");
		DispatchKeyValueFloat(entity, "spotlight_radius", 32.0);
		DispatchKeyValueFloat(entity, "distance", 5.0);
		DispatchKeyValue(entity, "style", "6");
		DispatchSpawn(entity);

		decl Float:vPos[3], Float:vAng[3];
		GetEntPropVector(target, Prop_Data, "m_vecOrigin", vPos);
		GetEntPropVector(target, Prop_Data, "m_angRotation", vAng);
		vPos[2] += 40.0;
		TeleportEntity(entity, vPos, vAng, NULL_VECTOR);
		AcceptEntityInput(entity, "TurnOn");

		// Fade in
		Format(sTemp, sizeof(sTemp), "OnUser1 !self:distance:%f:0.2:-1", g_fCvarDist / 5);
		SetVariantString(sTemp);
		AcceptEntityInput(entity, "AddOutput");
		Format(sTemp, sizeof(sTemp), "OnUser1 !self:distance:%f:0.4:-1", (g_fCvarDist / 5) * 2);
		SetVariantString(sTemp);
		AcceptEntityInput(entity, "AddOutput");
		Format(sTemp, sizeof(sTemp), "OnUser1 !self:distance:%f:0.6:-1", (g_fCvarDist / 5) * 3);
		SetVariantString(sTemp);
		AcceptEntityInput(entity, "AddOutput");
		Format(sTemp, sizeof(sTemp), "OnUser1 !self:distance:%f:0.8:-1", (g_fCvarDist / 5) * 4);
		SetVariantString(sTemp);
		AcceptEntityInput(entity, "AddOutput");
		Format(sTemp, sizeof(sTemp), "OnUser1 !self:distance:%f:1.0:-1", g_fCvarDist);
		SetVariantString(sTemp);
		AcceptEntityInput(entity, "AddOutput");
		AcceptEntityInput(entity, "FireUser1");

		// Fade out
		Format(sTemp, sizeof(sTemp), "OnUser2 !self:distance:%f:%f:-1", (g_fCvarDist / 5) * 4, fInfernoTime - 0.6);
		SetVariantString(sTemp);
		AcceptEntityInput(entity, "AddOutput");
		Format(sTemp, sizeof(sTemp), "OnUser2 !self:distance:%f:%f:-1", (g_fCvarDist / 5) * 3, fInfernoTime - 0.4);
		SetVariantString(sTemp);
		AcceptEntityInput(entity, "AddOutput");
		Format(sTemp, sizeof(sTemp), "OnUser2 !self:distance:%f:%f:-1", (g_fCvarDist / 5) * 2, fInfernoTime - 0.2);
		SetVariantString(sTemp);
		AcceptEntityInput(entity, "AddOutput");
		Format(sTemp, sizeof(sTemp), "OnUser2 !self:distance:%f:%f:-1", g_fCvarDist / 5, fInfernoTime);
		SetVariantString(sTemp);
		AcceptEntityInput(entity, "AddOutput");
		AcceptEntityInput(entity, "FireUser2");

		Format(sTemp, sizeof(sTemp), "OnUser3 !self:Kill::%f:-1", fInfernoTime);
		SetVariantString(sTemp);
		AcceptEntityInput(entity, "AddOutput");
		AcceptEntityInput(entity, "FireUser3");
	}
}

bool:IsValidEntRef(entity)
{
	if( entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE )
		return true;
	return false;
}