/*
 * ============================================================================
 *
 *  Rotoblin
 *
 *  File:			rotoblin.infectedfrustration.sp
 *  Type:			Module
 *  Description:	Allows infected teammates to see frustration level of the 
 *					tank.
 *
 *  Copyright (C) 2010  Mr. Zero <mrzerodk@gmail.com>
 *  Copyright (C) 2017-2019  Harry <fbef0102@gmail.com>
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

static	const	Float:	HUD_UPDATE_INTERVAL		= 1.0;
static			Handle:	g_hHUD					= INVALID_HANDLE;
static			bool:	g_bIncludeTankClient	= false;

// **********************************************
//                   Forwards
// **********************************************

/**
 * Plugin is starting.
 *
 * @noreturn
 */
public _InfFrustration_OnPluginStart()
{
	HookPublicEvent(EVENT_ONPLUGINENABLE, _IF_OnPluginEnabled);
}

/**
 * Plugin is now enabled.
 *
 * @noreturn
 */
public _IF_OnPluginEnabled()
{
	HookTankEvent(TANK_SPAWNED, _IF_TankSpawn_Event);
	HookTankEvent(TANK_PASSED, _IF_TankPassed_Event);
}

/**
 * Tank spawned.
 *
 * @noreturn
 */
public _IF_TankSpawn_Event()
{
	CreateTimer(HUD_UPDATE_INTERVAL, _IF_HUD_Timer, _, TIMER_REPEAT);
}

/**
 * Tank passed.
 *
 * @noreturn
 */
public _IF_TankPassed_Event()
{
	g_bIncludeTankClient = false;
}

/**
 * Called when the timer interval for the HUD, has elapsed.
 * 
 * @param timer			Handle to the timer object.
 * @return				Plugin_Stop to stop a repeating timer, any other value for
 *						default behavior.
 */
public Action:_IF_HUD_Timer(Handle:timer)
{
	if (!IsTankInPlay()) return Plugin_Stop;

	new tankclient = GetTankClient();
	if (!tankclient || IsFakeClient(tankclient) || IsTankDying() || IsTankOnFire()) return Plugin_Continue;// if tank is a bot, dying or on fire, return continue

	_IF_HUD_Draw();

	if (!InfectedCount) return Plugin_Continue; // No infected players, return continue

	decl client;
	for (new i = 0; i < InfectedCount; i++)
	{
		client = InfectedIndex[i];
		if ((!g_bIncludeTankClient && client == tankclient) || IsFakeClient(client)) continue; // If client is the tank or is a bot, continue
		SendPanelToClient(g_hHUD, client, _IF_HUD_Handler, 1); // Show HUD to client
	}

	return Plugin_Continue;
}

/**
 * Called when a menu action is completed. For infected HUD.
 *
 * @param menu				The menu being acted upon.
 * @param action			The action of the menu.
 * @param param1			First action parameter (usually the client).
 * @param param2			Second action parameter (usually the item).
 * @noreturn
 */
public _IF_HUD_Handler(Handle:menu, MenuAction:action, param1, param2) 
{ 
	/* Empty, as we don't care about what gets pressed in the HUD. */
}

// **********************************************
//                 Public API
// **********************************************

/**
 * Will make the tank client see his own rage in a HUD.
 *
 * @noreturn
 */
stock AddTankClientToInfHUD()
{
	g_bIncludeTankClient = true;
}

/**
 * Hides the rage HUD from tank client.
 *
 * @noreturn
 */
stock RemoveTankClientFromInfHUD()
{
	g_bIncludeTankClient = false;
}


// **********************************************
//                 Private API
// **********************************************

/**
 * Draws HUD with frustration level of the tank
 *
 * @noreturn
 */
static _IF_HUD_Draw()
{
	if (g_hHUD != INVALID_HANDLE) CloseHandle(g_hHUD); // Close handle if used
	g_hHUD = CreatePanel();

	// Draw frustration
	new frustration = GetTankFrustration();
	if (frustration == -1) return; // Tank isn't alive, return

	decl String:sBuffer[512];
	Format(sBuffer, sizeof(sBuffer), "Tank frustration: %d%%", frustration);
	DrawPanelText(g_hHUD, sBuffer);
}