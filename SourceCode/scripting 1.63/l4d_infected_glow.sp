#define PLUGIN_VERSION 		"1.4"

/*=======================================================================================
	Plugin Info:

*	Name	:	[L4D & L4D2] Infected Glow
*	Author	:	SilverShot
*	Descrp	:	Creates a dynamic light on common/special infected who are burning.
*	Link	:	http://forums.alliedmods.net/showthread.php?t=187933

========================================================================================
	Change Log:

1.4 (30-Jun-2012)
	- Fixed the plugin not working in L4D1.

1.3 (22-Jun-2012)
	- Fixed water not removing the glow - Thanks to "id5473" for reporting.

1.2 (20-Jun-2012)
	- Added some checks to prevent errors being logged - Thanks to "doritos250" for reporting.

1.1 (20-Jun-2012)
	- Fixed not removing the light from Special Infected ignited by incendiary ammo.

1.0 (20-Jun-2012)
	- Initial release.

======================================================================================*/

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define CVAR_FLAGS			FCVAR_PLUGIN|FCVAR_NOTIFY
#define MAX_LIGHTS			8

static	Handle:g_hMPGameMode, Handle:g_hCvarAllow, Handle:g_hCvarModes, Handle:g_hCvarModesOff, Handle:g_hCvarModesTog,
		Handle:g_hCvarDist, Handle:g_hCvarColor, Float:g_fCvarDist, String:g_sCvarCols[12], Handle:g_hCvarInfected,
		g_iCvarInfected, bool:g_bCvarAllow, bool:g_bStarted, bool:g_bWatch, bool:g_bLeft4Dead2, g_iEntities[MAX_LIGHTS][2];



// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================
public Plugin:myinfo =
{
	name = "[L4D & L4D2] Infected Glow",
	author = "SilverShot",
	description = "Creates a dynamic light on common/special infected who are burning.",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=187933"
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
	g_hCvarAllow =			CreateConVar(	"l4d_infected_glow_allow",			"1",			"0=Plugin off, 1=Plugin on.", CVAR_FLAGS );
	g_hCvarModes =			CreateConVar(	"l4d_infected_glow_modes",			"",				"Turn on the plugin in these game modes, separate by commas (no spaces). (Empty = all).", CVAR_FLAGS );
	g_hCvarModesOff =		CreateConVar(	"l4d_infected_glow_modes_off",		"",				"Turn off the plugin in these game modes, separate by commas (no spaces). (Empty = none).", CVAR_FLAGS );
	if( g_bLeft4Dead2 )
		g_hCvarModesTog =	CreateConVar(	"l4d_infected_glow_modes_tog",		"0",			"Turn on the plugin in these game modes. 0=All, 1=Coop, 2=Survival, 4=Versus, 8=Scavenge. Add numbers together.", CVAR_FLAGS );
	g_hCvarColor =			CreateConVar(	"l4d_infected_glow_color",			"255 50 0"	,	"The light color. Three values between 0-255 separated by spaces. RGB Color255 - Red Green Blue.", CVAR_FLAGS );
	g_hCvarDist =			CreateConVar(	"l4d_infected_glow_distance",		"200.0",		"How far does the dynamic light illuminate the area.", CVAR_FLAGS );
	g_hCvarInfected =		CreateConVar(	"l4d_infected_glow_infected",		"511",			"1=Common, 2=Witch, 4=Smoker, 8=Boomer, 16=Hunter, 32=Spitter, 64=Jockey, 128=Charger, 256=Tank, 511=All.", CVAR_FLAGS );
	CreateConVar(							"l4d_infected_glow_version",		PLUGIN_VERSION,	"Molotov and Gascan Glow plugin version.", CVAR_FLAGS|FCVAR_REPLICATED|FCVAR_DONTRECORD);
	AutoExecConfig(true,					"l4d_infected_glow");

	g_hMPGameMode = FindConVar("mp_gamemode");
	if( g_bLeft4Dead2 )
		HookConVarChange(g_hCvarModesTog,	ConVarChanged_Allow);
	HookConVarChange(g_hCvarModes,			ConVarChanged_Allow);
	HookConVarChange(g_hCvarModesOff,		ConVarChanged_Allow);
	HookConVarChange(g_hCvarAllow,			ConVarChanged_Allow);
	HookConVarChange(g_hCvarDist,			ConVarChanged_Cvars);
	HookConVarChange(g_hCvarColor,			ConVarChanged_Cvars);
	HookConVarChange(g_hCvarInfected,		ConVarChanged_Cvars);
}

public OnMapStart()
{
	g_bStarted = true;
}

public OnMapEnd()
{
	ResetPlugin();
	g_bStarted = false;
}

ResetPlugin()
{
	g_bWatch = false;

	for( new i = 0; i < MAX_LIGHTS; i++ )
	{
		if( IsValidEntRef(g_iEntities[i][0]) == true )
			AcceptEntityInput(g_iEntities[i][0], "Kill");

		g_iEntities[i][0] = 0;
		g_iEntities[i][1] = 0;
	}
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
	GetConVarString(g_hCvarColor, g_sCvarCols, sizeof(g_sCvarCols));
	g_iCvarInfected = GetConVarInt(g_hCvarInfected);
}

IsAllowed()
{
	new bool:bCvarAllow = GetConVarBool(g_hCvarAllow);
	new bool:bAllowMode = IsAllowedGameMode();
	GetCvars();

	if( g_bCvarAllow == false && bCvarAllow == true && bAllowMode == true )
	{
		g_bCvarAllow = true;
		HookEvent("player_death", Event_Check);
		HookEvent("player_team", Event_Check);
	}

	else if( g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false) )
	{
		ResetPlugin();
		g_bCvarAllow = false;
		UnhookEvent("player_death", Event_Check);
		UnhookEvent("player_team", Event_Check);
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
//					EVENTS
// ====================================================================================================
public Event_Check(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if( client )
	{
		new entity;

		for( new i = 0; i < MAX_LIGHTS; i++ )
		{
			entity = g_iEntities[i][0];
			if( IsValidEntRef(entity) == true )
			{
				if( GetEntPropEnt(entity, Prop_Data, "m_hMoveParent") == client )
				{
					AcceptEntityInput(entity, "ClearParent");
					AcceptEntityInput(entity, "Kill");
					g_iEntities[i][0] = 0;
					g_iEntities[i][1] = 0;
					break;
				}
			}
		}
	}
}



// ====================================================================================================
//					LIGHTS
// ====================================================================================================
public OnEntityCreated(entity, const String:classname[])
{
	if( g_bCvarAllow && g_bStarted )
	{
		if( strcmp(classname, "entityflame") == 0 )
		{
			CreateTimer(0.1, TimerCreate, EntIndexToEntRef(entity));
		}
	}
}

public OnEntityDestroyed(entity)
{
	if( g_bWatch && g_bCvarAllow && g_bStarted && entity > 0 )
	{
		entity = EntIndexToEntRef(entity);
		new valid;

		for( new i = 0; i < MAX_LIGHTS; i++ )
		{
			if( entity == g_iEntities[i][1] && IsValidEntRef(g_iEntities[i][0]) == true )
			{
				AcceptEntityInput(g_iEntities[i][0], "Kill");
				g_iEntities[i][0] = 0;
				g_iEntities[i][1] = 0;
			}
			else if( IsValidEntRef(g_iEntities[i][1]) == true )
			{
				valid = 1;
			}
		}

		if( valid == 0 )
			g_bWatch = false;
	}
}

public Action:TimerCreate(Handle:timer, any:target)
{
	if( (target = EntRefToEntIndex(target)) != INVALID_ENT_REFERENCE )
	{
		new client = GetEntPropEnt(target, Prop_Data, "m_hEntAttached");
		if( client < 1 )
			return;

		decl String:sTemp[64];

		if( client > MaxClients )
		{
			if( IsValidEntity(client) == false )
				return;

			new infected = g_iCvarInfected & (1<<0);
			new witch = g_iCvarInfected & (1<<1);

			if( infected || witch )
			{
				GetEdictClassname(client, sTemp, sizeof(sTemp));

				if( (!infected || strcmp(sTemp, "infected")) && (!witch || strcmp(sTemp, "witch")) )
					return;
			}
		}
		else
		{
			if( IsClientInGame(client) == false || GetClientTeam(client) != 3 )
				return;

			new class = GetEntProp(client, Prop_Send, "m_zombieClass") + 1;
			if( class == 9 ) class = 8;
			if( !(g_iCvarInfected & (1 << class)) )
				return;
		}

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

		new entity = CreateEntityByName("light_dynamic");
		if( entity == -1)
		{
			LogError("Failed to create 'light_dynamic'");
			return;
		}

		g_bWatch = true;
		g_iEntities[index][0] = EntIndexToEntRef(entity);
		g_iEntities[index][1] = EntIndexToEntRef(target);

		Format(sTemp, sizeof(sTemp), "%s 255", g_sCvarCols);

		DispatchKeyValue(entity, "_light", sTemp);
		DispatchKeyValue(entity, "brightness", "2");
		DispatchKeyValueFloat(entity, "spotlight_radius", 32.0);
		DispatchKeyValueFloat(entity, "distance", 5.0);
		DispatchKeyValue(entity, "style", "6");
		DispatchSpawn(entity);

		SetVariantString("!activator");
		AcceptEntityInput(entity, "SetParent", target);

		new Float:vPos[3];
		vPos[2] = 50.0;
		TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);

		AcceptEntityInput(entity, "TurnOn");

		// Fade in
		Format(sTemp, sizeof(sTemp), "OnUser1 !self:distance:%f:0.1:-1", g_fCvarDist / 6);
		SetVariantString(sTemp);
		AcceptEntityInput(entity, "AddOutput");
		Format(sTemp, sizeof(sTemp), "OnUser1 !self:distance:%f:0.2:-1", (g_fCvarDist / 6) * 2);
		SetVariantString(sTemp);
		AcceptEntityInput(entity, "AddOutput");
		Format(sTemp, sizeof(sTemp), "OnUser1 !self:distance:%f:0.3:-1", (g_fCvarDist / 6) * 3);
		SetVariantString(sTemp);
		AcceptEntityInput(entity, "AddOutput");
		Format(sTemp, sizeof(sTemp), "OnUser1 !self:distance:%f:0.4:-1", (g_fCvarDist / 6) * 4);
		SetVariantString(sTemp);
		AcceptEntityInput(entity, "AddOutput");
		Format(sTemp, sizeof(sTemp), "OnUser1 !self:distance:%f:0.5:-1", (g_fCvarDist / 6) * 5);
		SetVariantString(sTemp);
		AcceptEntityInput(entity, "AddOutput");
		Format(sTemp, sizeof(sTemp), "OnUser1 !self:distance:%f:0.6:-1", g_fCvarDist);
		SetVariantString(sTemp);
		AcceptEntityInput(entity, "AddOutput");
		AcceptEntityInput(entity, "FireUser1");
	}
}

bool:IsValidEntRef(entity)
{
	if( entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE )
		return true;
	return false;
}