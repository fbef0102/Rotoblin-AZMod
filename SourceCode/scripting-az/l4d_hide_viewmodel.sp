/*
 * l4d_hide_viewmodel: !noviewmodel hides your own first-person gun and arms.
 *
 * Players were hiding the view model with a client DLL that forces
 * viewmodel_fov_override to 180+; that breaks the view model projection and the
 * weapon half of the HUD (ammo, pills slot) disappears with it. This plugin uses
 * the engine's own switch instead: m_Local.m_bDrawViewmodel, which the client
 * checks before drawing view models and nothing else, so the HUD stays.
 *
 * The game sets the flag back to true on its own (entering ghost state, survivor
 * cameras, bot replacement), so a short timer re-hides it for players who opted
 * in. The choice is saved in a client cookie.
 *
 * Weapons named in l4d_hide_viewmodel_show (pills by default) still draw, so
 * players can see what they are holding; a weapon switch hook updates at once.
 * Infected keep their claws unless l4d_hide_viewmodel_infected is 1.
 * We only ever turn the flag back on if we were the ones who turned it off, so
 * the game's own hides (death fall camera) are left alone.
 */
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <clientprefs>
#include <sdkhooks>

#define PLUGIN_VERSION	"1.2"
#define TEAM_SURVIVOR	2

ConVar g_cvEnable;
ConVar g_cvShow;
ConVar g_cvInfected;
Cookie g_hCookie;
bool g_bHide[MAXPLAYERS + 1];	// the player asked for !noviewmodel
bool g_bWeHid[MAXPLAYERS + 1];	// m_bDrawViewmodel is false because we set it

public Plugin myinfo =
{
	name = "l4d_hide_viewmodel",
	author = "Malevolence",
	description = "!noviewmodel hides your own gun and arms without hiding the HUD",
	version = PLUGIN_VERSION,
	url = "https://github.com/Volence/riverside-l4d-plugins"
};

public void OnPluginStart()
{
	g_cvEnable = CreateConVar("l4d_hide_viewmodel_enable", "1", "1 = players may hide their view model with !noviewmodel", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	// SetString: a reload keeps the old cvar, and its old value with it
	CreateConVar("l4d_hide_viewmodel_version", PLUGIN_VERSION, "l4d_hide_viewmodel version", FCVAR_NOTIFY | FCVAR_DONTRECORD).SetString(PLUGIN_VERSION);
	g_cvShow = CreateConVar("l4d_hide_viewmodel_show", "weapon_pain_pills", "Comma-separated weapon classnames that stay visible with !noviewmodel on", FCVAR_NOTIFY);
	g_cvInfected = CreateConVar("l4d_hide_viewmodel_infected", "0", "1 = !noviewmodel also hides infected claws", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvEnable.AddChangeHook(OnEnableChanged);

	g_hCookie = new Cookie("hide_viewmodel", "1 = hide your first-person gun and arms", CookieAccess_Protected);

	RegConsoleCmd("sm_noviewmodel", Cmd_Toggle, "Toggle hiding your own gun and arms");
	RegConsoleCmd("sm_viewmodel", Cmd_Toggle, "Toggle hiding your own gun and arms");

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;
		SDKHook(i, SDKHook_WeaponSwitchPost, OnWeaponSwitchPost);
		if (AreClientCookiesCached(i))
			OnClientCookiesCached(i);
	}

	CreateTimer(0.2, Timer_Enforce, _, TIMER_REPEAT);
}

public void OnPluginEnd()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
			Restore(i);
	}
}

public void OnClientConnected(int client)
{
	g_bHide[client] = false;
	g_bWeHid[client] = false;
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitchPost);
}

void OnWeaponSwitchPost(int client, int weapon)
{
	if (g_bHide[client] && g_cvEnable.BoolValue)
		Update(client);
}

public void OnClientCookiesCached(int client)
{
	if (IsFakeClient(client))
		return;

	char value[4];
	g_hCookie.Get(client, value, sizeof(value));
	g_bHide[client] = (value[0] == '1');
}

void OnEnableChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (convar.BoolValue)
		return;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
			Restore(i);
	}
}

Action Cmd_Toggle(int client, int args)
{
	if (client == 0)
		return Plugin_Handled;

	if (!g_cvEnable.BoolValue)
	{
		ReplyToCommand(client, "\x04[Viewmodel]\x01 Hiding the view model is turned off on this server.");
		return Plugin_Handled;
	}

	g_bHide[client] = !g_bHide[client];
	if (AreClientCookiesCached(client))
		g_hCookie.Set(client, g_bHide[client] ? "1" : "0");

	if (g_bHide[client])
		Update(client);
	else
		Restore(client);
	ReplyToCommand(client, "\x04[Viewmodel]\x01 Your gun and arms are now %s. Type \x05!noviewmodel\x01 to %s.",
		g_bHide[client] ? "hidden" : "shown", g_bHide[client] ? "show them again" : "hide them");
	return Plugin_Handled;
}

Action Timer_Enforce(Handle timer)
{
	if (!g_cvEnable.BoolValue)
		return Plugin_Continue;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (g_bHide[i] && IsClientInGame(i))
			Update(i);
	}
	return Plugin_Continue;
}

// Hide unless the active weapon is on the show list (or the player is infected
// and infected are not hidden). SetEntProp marks m_Local
// changed, so only write on a real change.
void Update(int client)
{
	bool draw = GetEntProp(client, Prop_Send, "m_bDrawViewmodel") != 0;
	if (IsShownWeapon(client) || (GetClientTeam(client) != TEAM_SURVIVOR && !g_cvInfected.BoolValue))
	{
		Restore(client);
	}
	else if (draw)
	{
		SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 0);
		g_bWeHid[client] = true;
	}
}

// Turn the view model back on, but only if we turned it off.
void Restore(int client)
{
	if (!g_bWeHid[client])
		return;
	g_bWeHid[client] = false;
	if (GetEntProp(client, Prop_Send, "m_bDrawViewmodel") == 0)
		SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 1);
}

bool IsShownWeapon(int client)
{
	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (weapon <= MaxClients || !IsValidEntity(weapon))
		return false;

	char cls[64], list[256];
	GetEntityClassname(weapon, cls, sizeof(cls));
	g_cvShow.GetString(list, sizeof(list));

	char names[16][64];
	int n = ExplodeString(list, ",", names, sizeof(names), sizeof(names[]));
	for (int i = 0; i < n; i++)
	{
		TrimString(names[i]);
		if (names[i][0] != '\0' && StrEqual(cls, names[i], false))
			return true;
	}
	return false;
}
