#pragma semicolon 1
#pragma newdecls required

#include <multicolors>
#include <left4dhooks>
#include <sourcemod>
#include <l4d_lib>

public Plugin myinfo =
{
	name        = "L4D1 No Tank Rush",
	author      = "Harry, Malevolence",
	version     = "1.0-2026/10/13",
	description = "Stops distance points accumulating whilst the tank is alive, with the option of unfreezing distance on reaching the Saferoom"
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


#define TEAM_SURVIVOR 	2
#define TEAM_INFECTED 	3

bool
	g_bTankAlive,
	bHooked,
	g_bRoundLive;

ConVar
	cvar_noTankRush,
	cvar_SpawnEnableSound,
	cvar_unfreezeSaferoom,
	cvar_unfreezeAI;

// The patch site is the conditional jump that keeps a survivor's stored
// furthest flow when their current flow is not past it (Linux: jbe in
// ForEachTerrorPlayer<CalcAndSetVersusMaxFlowDistance>; Windows: jne in the
// small store helper it calls). As an unconditional jmp the stored value is
// always kept, so every survivor's distance freezes. The gamedata holds the
// original opcode and the bytes around it for each platform.
#define BYTE_ALWAYS_KEEP	0xEB	// jmp rel8

Address g_pPatch = Address_Null;	// patch site, Address_Null when not found
int g_iKeepByte;					// the site's original opcode (jbe on Linux, jne on Windows)

public void OnPluginStart()
{
	FindPatchSite();
	LoadTranslations("Roto2-AZ_mod.phrases");

	// ConVars
	cvar_noTankRush       = CreateConVar("l4d_no_tank_rush", 					"1", "Prevents survivor team from accumulating points whilst the tank is alive", _, true, 0.0, true, 1.0);
	cvar_unfreezeSaferoom = CreateConVar("l4d_no_tank_rush_unfreeze_saferoom", 	"1", "Unfreezes distance if a Survivor makes it to the end saferoom and close door while the Tank is still up.", _, true, 0.0, true, 1.0);
	cvar_unfreezeAI       = CreateConVar("l4d_no_tank_rush_unfreeze_ai", 		"1", "Unfreeze distance if the Tank goes AI", _, true, 0.0, true, 1.0);
	cvar_SpawnEnableSound = CreateConVar("l4d_no_tank_rush_spawn_sound", 		"0", "Turn on the sound when spawning a tank", _, true, 0.0, true, 1.0);

	// ChangeHook
	cvar_noTankRush.AddChangeHook(NoTankRushChange);

	if(bLate)
	{
		// Loaded mid round (late load, or a reload): the round is already running.
		g_bRoundLive = true;
	}

	if (cvar_noTankRush.BoolValue)
	{
		PluginEnable();
	}

	RegAdminCmd("sm_tankrush_status", Cmd_Status, ADMFLAG_GENERIC, "Print l4d_tank_rush state.");
}

public void OnPluginEnd()
{
	bHooked = false;
	PluginDisable();
}

void PluginEnable()
{
	if (!bHooked)
	{
		HookEvent("round_start", 		Event_RoundStart, EventHookMode_PostNoCopy);
		HookEvent("round_end",			Event_RoundEnd,			EventHookMode_PostNoCopy);
		HookEvent("map_transition",		Event_RoundEnd,			EventHookMode_PostNoCopy);
		HookEvent("mission_lost",		Event_RoundEnd,			EventHookMode_PostNoCopy);
		HookEvent("finale_win",			Event_RoundEnd,			EventHookMode_PostNoCopy);
		HookEvent("tank_spawn", 		TankSpawn, EventHookMode_PostNoCopy);
		HookEvent("player_death", 		PlayerDeath, EventHookMode_Post);
		HookEvent("player_bot_replace", OnTankGoneAI);

		if (IsTankActuallyInPlay())
		{
			ApplyFreeze();
		}
		bHooked = true;
	}
}

void PluginDisable()
{
	if (bHooked)
	{
		UnhookEvent("round_start", 			Event_RoundStart, EventHookMode_PostNoCopy);
		UnhookEvent("round_end",			Event_RoundEnd,			EventHookMode_PostNoCopy);
		UnhookEvent("map_transition",		Event_RoundEnd,			EventHookMode_PostNoCopy);
		UnhookEvent("mission_lost",			Event_RoundEnd,			EventHookMode_PostNoCopy);
		UnhookEvent("finale_win",			Event_RoundEnd,			EventHookMode_PostNoCopy);
		UnhookEvent("tank_spawn", 			TankSpawn, EventHookMode_PostNoCopy);
		UnhookEvent("player_death", 		PlayerDeath, EventHookMode_Post);
		UnhookEvent("player_bot_replace", 	OnTankGoneAI, EventHookMode_Post);

		bHooked = false;
	}

	UnFreezePoints(false);
}

void NoTankRushChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (StringToInt(newValue) == 0)
	{
		PluginDisable();
	}
	else {
		PluginEnable();
	}
}

public void OnMapStart()
{
	PrecacheSound("ui/pickup_secret01.wav");
	g_bTankAlive = false;
}

public void OnMapEnd()
{
	g_bRoundLive = false;
	UnFreezePoints(false);
}

public void OnClientDisconnect(int client)
{
	if (IsTank(client))
	{
		CreateTimer(0.1, CheckForTanksDelay, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action Cmd_Status(int client, int args)
{
	int b = ReadSite();
	ReplyToCommand(client, "[tank_rules] site=%s byte=0x%02X rush=%d round_live=%d tank_alive=%d distance=%d",
		g_pPatch == Address_Null ? "missing" : "ok", b < 0 ? 0 : b,
		cvar_noTankRush.IntValue,
		g_bRoundLive, g_bTankAlive,
		GameRules_GetProp("m_iVersusDistance"));
	return Plugin_Handled;
}

void OnTankGoneAI(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	if (!cvar_unfreezeAI.BoolValue)
	{
		return;
	}

	int iNewTank = GetClientOfUserId(hEvent.GetInt("bot"));
	if (iNewTank && IsClientInGame(iNewTank) && GetClientTeam(iNewTank) == TEAM_INFECTED && GetEntProp(iNewTank, Prop_Send, "m_zombieClass") == ZC_TANK)
	{
		UnFreezePoints(true, false, 0);
	}
}

void Event_RoundStart(Event hEvent, const char[] eName, bool dontBroadcast)
{
	g_bRoundLive = true;
	UnFreezePoints(false);
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	g_bRoundLive = false;
}

void TankSpawn(Event hEvent, const char[] eName, bool dontBroadcast)
{
	ApplyFreeze(true);
}

void PlayerDeath(Event hEvent, const char[] eName, bool dontBroadcast)
{
	int client = GetClientOfUserId(hEvent.GetInt("userid"));
	if (client > 0 && IsTank(client))
	{
		CreateTimer(0.1, CheckForTanksDelay, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

Action CheckForTanksDelay(Handle timer)
{
	if (!IsTankActuallyInPlay())
	{
		UnFreezePoints(true, true, 1);
	}

	return Plugin_Stop;
}

// Called whenever CDirectorVersusMode::EndVersusModeRound(bool) is invoked
// Called before score calculations and the scoreboard display
// This happenes before the round_end event, so we can unfreeze distance before the scoreboard is shown.
public Action L4D2_OnEndVersusModeRound(bool countSurvivors)
{
	if (countSurvivors &&
		cvar_unfreezeSaferoom.IntValue == 1 && IsTankActuallyInPlay())
	{
		UnFreezePoints(true, true, 2);
	}

	return Plugin_Continue;
}

// Frozen while a tank lives in a live round.
void ApplyFreeze(bool show_message = false)
{
	// From round end to the next round start the byte stays as it was. Incapped
	// survivors count as alive to the engine, so one lying past the frozen mark
	// would be paid for it by a score recompute after an unfreeze here.
	if( !g_bRoundLive ) return;
	
	if (!g_bTankAlive)
	{
		SetFrozen(true);
		if (show_message)
		{
			CPrintToChatAll("%t %t", "l4d_tank_rush_Tag", "l4d_tank_rush_freeze");
			if (cvar_SpawnEnableSound.BoolValue)
			{
				EmitSoundToAll("ui/pickup_secret01.wav");
			}
		}

		g_bTankAlive = true;
	}
}

void UnFreezePoints(bool bCheck = true, bool show_message = false, int iMessage = 1)
{
	if(bCheck)
	{
		// From round end to the next round start the byte stays as it was. Incapped
		// survivors count as alive to the engine, so one lying past the frozen mark
		// would be paid for it by a score recompute after an unfreeze here.
		if( !g_bRoundLive ) return;

		// The tank is gone but nobody is standing: the round is being lost, and
		// until round_end the engine still pays incapped survivors their current
		// flow. Keep the freeze until someone stands up or the next round starts.
		if( !IsSurvivorStanding() ) return;

		if (g_bTankAlive)
		{
			if (show_message)
			{
				if (iMessage == 1)
				{
					CPrintToChatAll("%t %t", "l4d_tank_rush_Tag", "l4d_tank_rush_unfreeze");
				}
				else {
					CPrintToChatAll("%t %t", "l4d_tank_rush_Tag", "l4d_tank_rush_saferoom");
				}
			}

			SetFrozen(false);
			g_bTankAlive = false;
		}
	}
	else
	{
		SetFrozen(false);
		g_bTankAlive = false;
	}
}

bool IsSurvivorStanding()
{
	for( int i = 1; i <= MaxClients; i++ )
	{
		if( !IsClientInGame(i) || GetClientTeam(i) != TEAM_SURVIVOR || !IsPlayerAlive(i) ) continue;
		if( GetEntProp(i, Prop_Send, "m_isIncapacitated") ) continue;
		if( GetEntProp(i, Prop_Send, "m_isHangingFromLedge") ) continue;
		return true;
	}

	return false;
}

bool IsTankActuallyInPlay()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsTank(i) && IsPlayerAlive(i))
		{
			return true;
		}
	}

	return false;
}

// ---------------------------------------------------------------------------
// Patch site
// ---------------------------------------------------------------------------

void FindPatchSite()
{
	GameData gd = new GameData("l4d_tank_rush");
	if( gd == null )
	{
		LogError("Missing gamedata l4d_tank_rush.txt; no-rush is off.");
		return;
	}

	Address fn = gd.GetAddress("CalcAndSetVersusMaxFlowDistance");
	int offset = gd.GetOffset("keep_stored_jbe");
	int keep = gd.GetOffset("keep_stored_opcode");
	int rel = gd.GetOffset("keep_stored_rel8");
	int storeAt = gd.GetOffset("keep_stored_store_at");
	int member = gd.GetOffset("keep_stored_member");
	delete gd;

	if( fn == Address_Null || offset == -1 || keep == -1 || rel == -1 || storeAt == -1 || member == -1 )
	{
		LogError("Could not find the CalcAndSetVersusMaxFlowDistance patch site in gamedata; no-rush is off.");
		return;
	}

	Address site = fn + view_as<Address>(offset);
	int b = LoadFromAddress(site, NumberType_Int8) & 0xFF;

	// A copy of this plugin that died without OnPluginEnd can leave the jmp
	// behind. Nothing else writes this byte, so take it back either way. The
	// rest of the site must match too: an unrelated EB elsewhere must never be
	// turned into a jbe.
	if( (b != keep && b != BYTE_ALWAYS_KEEP) || !SiteContextMatches(site, rel, storeAt, member) )
	{
		LogError("Unexpected bytes at CalcAndSetVersusMaxFlowDistance+%d (0x%02X); engine build differs, no-rush is off.", b, offset);
		return;
	}

	g_pPatch = site;
	g_iKeepByte = keep;
	WriteSite(g_iKeepByte);
	LogMessage("No-rush patch site found at CalcAndSetVersusMaxFlowDistance+%d.", offset);
}

// The jump's rel8 (to the keep-stored path) and, storeAt bytes on, the x87
// store it skips: D9 <modrm> <member offset>, e.g. Linux fsts 0x2b74(%ebp) is
// d9 95 74 2b 00 00, Windows fstp [ecx+0x2b60] is d9 99 60 2b 00 00.
bool SiteContextMatches(Address site, int rel, int storeAt, int member)
{
	if( (LoadFromAddress(site + view_as<Address>(1), NumberType_Int8) & 0xFF) != rel ) return false;
	if( (LoadFromAddress(site + view_as<Address>(storeAt), NumberType_Int8) & 0xFF) != 0xD9 ) return false;
	return LoadFromAddress(site + view_as<Address>(storeAt + 2), NumberType_Int32) == member;
}

int ReadSite()
{
	if( g_pPatch == Address_Null ) return -1;
	return LoadFromAddress(g_pPatch, NumberType_Int8) & 0xFF;
}

void WriteSite(int value)
{
	if( g_pPatch == Address_Null ) return;
	if( ReadSite() == value ) return;
	StoreToAddress(g_pPatch, value, NumberType_Int8);
}

void SetFrozen(bool frozen)
{
	WriteSite(frozen ? BYTE_ALWAYS_KEEP : g_iKeepByte);
}
