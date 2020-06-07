/*
 * ============================================================================
 *
 *  Rotoblin
 *
 *  File:			rotoblin.specboss.sp
 *  Type:			Module
 *  Description:	Handles the HUD to spectators with info about bosses.
 *
 *  Copyright (C) 2010  Mr. Zero <mrzerodk@gmail.com>
 *  Copyright (C) 2017-2020  Harry <fbef0102@gmail.com>
 *  This file is part of Rotoblin.
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * ============================================================================
 */

// --------------------
//       Private
// --------------------

static	const	String:	TANK_HEALTH_CVAR[]					= "z_tank_health";
static	const	String:	TANK_HEALTH_VS_MODIFIER_CVAR[]		= "versus_tank_bonus_health";
static	const	String:	TANK_FIRE_CVAR[]					= "z_tank_burning_lifetime";

static	const	Float:	HUD_UPDATE_INTERVAL					= 0.5;
static	const	String:	HUD_ITEM_SPACER[]					= "      "; // Spacer used before displaying an item, used for define number of spaces

static	const	String:	SPECHUD_COMMAND[]					= "spechud";

static			Float:	g_fTank_Max_Health					= 6000.0; // These are just default values, however it gets cvar values upon plugin start and cvar changes
static			Float:	g_fTank_Fire_Damage_Per_Second		= 80.0; // Hence no need for changing these, I just kept them for reference

static			Handle:	g_hHUD								= INVALID_HANDLE;
static			bool:	g_bShowHUD[MAXPLAYERS+1]			= {false};
static					g_iLastKnownClient					= 0;
static			String: g_sLastKnownName[MAX_NAME_LENGTH]	= "";
static			bool:	g_bIsTankDead						= false;
static			Handle:	g_hClientSettings					= INVALID_HANDLE;	// Handle to hold client settings trie
static			bool:	g_bHavePrintedTip[MAXPLAYERS+1]		= {false};

// **********************************************
//                   Forwards
// **********************************************

/**
 * Plugin is starting.
 *
 * @noreturn
 */
public _SpectateBoss_OnPluginStart()
{
	HookPublicEvent(EVENT_ONPLUGINENABLE, _SB_OnPluginEnabled);
	HookPublicEvent(EVENT_ONPLUGINDISABLE, _SB_OnPluginDisabled);
}

/**
 * Plugin is now enabled.
 *
 * @noreturn
 */
public _SB_OnPluginEnabled()
{
	ResetHUD(); // Reset vars

	HookEvent("round_start", _SB_RoundStart_Event, EventHookMode_PostNoCopy);
	HookTankEvent(TANK_SPAWNED, _SB_TankSpawn_Event);
	HookPublicEvent(EVENT_ONCLIENTPOSTADMINCHECK, _SB_OnClientPostAdminCheck);

	AddCommandListenerEx(_SB_ShowHud_Command, SPECHUD_COMMAND);

	g_hClientSettings = CreateTrie(); // Create trie to store client settings

	for (new i = FIRST_CLIENT; i < MaxClients; i++)
	{
		g_bShowHUD[i] = false;
	}

	CalculateTankVars(); // Calculate tank max health and fire damage
	HookConVarChange(FindConVar(TANK_HEALTH_CVAR), _SB_Tank_CvarChange);
	HookConVarChange(FindConVar(TANK_FIRE_CVAR), _SB_Tank_CvarChange);
}

/**
 * Plugin is now disabled.
 *
 * @noreturn
 */
public _SB_OnPluginDisabled()
{
	UnhookEvent("round_start", _SB_RoundStart_Event, EventHookMode_PostNoCopy);
	UnhookPublicEvent(EVENT_ONCLIENTPOSTADMINCHECK, _SB_OnClientPostAdminCheck);

	RemoveCommandListenerEx(_SB_ShowHud_Command, SPECHUD_COMMAND);

	CloseHandle(g_hClientSettings); // Close trie

	UnhookConVarChange(FindConVar(TANK_HEALTH_CVAR), _SB_Tank_CvarChange);
	UnhookConVarChange(FindConVar(TANK_FIRE_CVAR), _SB_Tank_CvarChange);
}

/**
 * Tank cvars changed.
 *
 * @noreturn
 */
public _SB_Tank_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	CalculateTankVars();
}

/**
 * Client is post admin check.
 *
 * @noreturn
 */
public _SB_OnClientPostAdminCheck(client)
{
	g_bShowHUD[client] = false;
	if (IsFakeClient(client)) return; // Don't bother with bots

	decl String:auth[32], value;
	GetClientAuthString(client, auth, sizeof(auth)); // Get steam id

	if (GetTrieValue(g_hClientSettings, auth, value))
	{
		g_bShowHUD[client] = bool:value;
	}
	else
	{
		SetTrieValue(g_hClientSettings, auth, 1, true);
		g_bShowHUD[client] = true;
	}

	g_bHavePrintedTip[client] = false;
	if (IsTankInPlay())
	{
		PrintToChat(client, "[%s] Use !%s to toggle the spectate HUD", PLUGIN_TAG, SPECHUD_COMMAND);
		g_bHavePrintedTip[client] = true;
	}
}

/**
 * Toggles the spectate HUD command.
 *
 * @return				Plugin Handled.
 */
public Action:_SB_ShowHud_Command(client, const String:command[], argc)
{
	if (client == 0) return Plugin_Handled;

	g_bShowHUD[client] = !g_bShowHUD[client]; // Toggle hud status

	decl String:auth[32];
	GetClientAuthString(client, auth, sizeof(auth)); // Get steam id
	SetTrieValue(g_hClientSettings, auth, int:g_bShowHUD[client], true); // Store settings

	PrintToChat(client, "[%s] Spectator HUD is now %s.", PLUGIN_TAG, (g_bShowHUD[client] ? "enabled" : "disabled"));

	return Plugin_Handled;
}

/**
 * Round start event.
 *
 * @noreturn
 */
public _SB_RoundStart_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	for (new i = FIRST_CLIENT; i <= MaxClients; i++) g_bHavePrintedTip[i] = false;
	ResetHUD();
}

/**
 * Tank spawned.
 *
 * @noreturn
 */
public _SB_TankSpawn_Event()
{
	CreateTimer(HUD_UPDATE_INTERVAL, _SB_HUD_Timer, _, TIMER_REPEAT);

	if (SpectateCount)
	{
		decl client;
		for (new i = 0; i < SpectateCount; i++)
		{
			client = SpectateIndex[i];
			if (IsFakeClient(client)) continue;
			PrintToChat(client, "[%s] Use !%s to toggle the spectate HUD", PLUGIN_TAG, SPECHUD_COMMAND);
			g_bHavePrintedTip[client] = true;
		}
	}
}

/**
 * HUD timer.
 */
public Action:_SB_HUD_Timer(Handle:timer)
{
	DrawHUD();

	new hudTime = 1;
	if (!IsTankInPlay()) hudTime = 4;

	if (SpectateCount)
	{
		decl client;
		for (new i = 0; i < SpectateCount; i++)
		{
			client = SpectateIndex[i];
			if (!g_bShowHUD[client] || IsFakeClient(client)) continue;
			SendPanelToClient(g_hHUD, client, _SB_HUD_Handler, hudTime); // Show HUD to client
		}
	}

	if (!IsTankInPlay())
	{
		ResetHUD();
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

/**
 * HUD handler.
 */
public _SB_HUD_Handler(Handle:menu, MenuAction:action, param1, param2) 
{ 
	/* Empty, as we don't care about what gets pressed in the HUD. */
}

// **********************************************
//                 Private API
// **********************************************

/**
 * Reset variables for the spectate HUD.
 *
 * @noreturn
 */
static ResetHUD()
{
	g_iLastKnownClient = 0;
	g_bIsTankDead = false;
}

/**
 * Calculates max health and fire damage per second for tank.
 *
 * @noreturn
 */
static CalculateTankVars()
{
	new Float:modifier = GetConVarFloat(FindConVar(TANK_HEALTH_VS_MODIFIER_CVAR));
	g_fTank_Max_Health = GetConVarFloat(FindConVar(TANK_HEALTH_CVAR)) * modifier;
	g_fTank_Fire_Damage_Per_Second = g_fTank_Max_Health / GetConVarFloat(FindConVar(TANK_FIRE_CVAR));
}

/**
 * Draws HUD with information about the tank
 *
 * @noreturn
 */
static DrawHUD()
{
	new client = GetTankClient(); // Get current tank client
	if (client < 1 || !IsValidEntity(client)) return;

	if (!g_bIsTankDead && IsTankDying())
	{
		g_bIsTankDead = true; // Tank is in "incap" animation, tank is dead
	}

	if (g_hHUD != INVALID_HANDLE) CloseHandle(g_hHUD); // Close handle if used
	g_hHUD = CreatePanel();

	decl String:sBuffer[512];
	Format(sBuffer, sizeof(sBuffer), "%s Spectate HUD", PLUGIN_TAG);
	SetPanelTitle(g_hHUD, sBuffer);

	/*
	 * Draw control
	 */
	DrawPanelItem(g_hHUD, "Control:");
	if (client == g_iLastKnownClient || g_bIsTankDead)
	{
		Format(sBuffer, sizeof(sBuffer), "%s%s", HUD_ITEM_SPACER, g_sLastKnownName);
	}
	else
	{
		if (!IsFakeClient(client)) // If its a real player
		{
			decl String:name[MAX_NAME_LENGTH];
			GetClientName(client, name, sizeof(name));
			Format(sBuffer, sizeof(sBuffer), "%s%s", HUD_ITEM_SPACER, name);
			g_sLastKnownName = name;
		}
		else // If AI tank
		{
			Format(sBuffer, sizeof(sBuffer), "%sAI", HUD_ITEM_SPACER);
			g_sLastKnownName = "AI";
		}
		g_iLastKnownClient = client;
	}
	DrawPanelText(g_hHUD, sBuffer);

	/*
	 * Draw health
	 */
	decl iHealth;
	DrawPanelItem(g_hHUD, "Health:");
	Format(sBuffer, sizeof(sBuffer), "%s0 / 0%", HUD_ITEM_SPACER);
	if (!g_bIsTankDead)
	{
		iHealth = GetClientHealth(client);
		new iHealthPro = RoundFloat(( 100.0 / g_fTank_Max_Health) * iHealth);

		// @me nitpicking
		if (iHealthPro < 1) iHealthPro = 1; // Health can't go below 1%
		if (iHealthPro == 100 && iHealth < g_fTank_Max_Health) iHealthPro = 99; // Health can't stay at 100% if the tank have lost any kinda of health

		Format(sBuffer, sizeof(sBuffer), "%s%d / %d%%", HUD_ITEM_SPACER, iHealth, iHealthPro);
	}
	DrawPanelText(g_hHUD, sBuffer);

	/*
	 * Draw frustration
	 */
	DrawPanelItem(g_hHUD, "Frustration:");
	if (!g_bIsTankDead)
	{
		Format(sBuffer, sizeof(sBuffer), "%s%d%%", HUD_ITEM_SPACER, GetTankFrustration());
	}
	else
	{
		Format(sBuffer, sizeof(sBuffer), "%s0%", HUD_ITEM_SPACER);
	}
	DrawPanelText(g_hHUD, sBuffer);

	/*
	 * Draw status
	 */
	DrawPanelItem(g_hHUD, "Status:");
	if (!g_bIsTankDead)
	{
		if (IsTankOnFire()) // If the tank is on fire
		{
			Format(sBuffer, sizeof(sBuffer), "%sOn Fire (%d sec)", HUD_ITEM_SPACER, RoundToCeil(iHealth / g_fTank_Fire_Damage_Per_Second));
		}
		else
		{
			Format(sBuffer, sizeof(sBuffer), "%sNormal", HUD_ITEM_SPACER);
		}
	}
	else
	{
		Format(sBuffer, sizeof(sBuffer), "%sDead", HUD_ITEM_SPACER);
	}
	DrawPanelText(g_hHUD, sBuffer);
}