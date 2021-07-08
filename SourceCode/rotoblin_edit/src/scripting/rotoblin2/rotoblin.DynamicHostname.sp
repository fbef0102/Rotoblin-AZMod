/*
 * ============================================================================
 *
 * This file is part of the Rotoblin 2 project.
 *
 *  File:			rotoblin.DynamicHostname.sp
 *  Type:			Module
 *  Description:	...
 *
 *  Copyright (C) 2012-2015 raziEiL <war4291@mail.ru>
 *  Copyright (C) 2017-2021 Harry <fbef0102@gmail.com>
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

#define		DN_TAG		"[DHostName]"

static		Handle:g_hAllowDN,  Handle:g_hHostName, Handle:g_hReadyUp, String:g_sDefaultN[68], String:g_sCvarDNSymbol[32];

_DHostName_OnPluginStart()
{
	g_hHostName	= FindConVar("hostname");

	g_hAllowDN	=	CreateConVarEx("allow_dynamic_hostname", "", "Adds the name of the current config in the l4dready RUP Menu (\"l4d_ready_cfg_name\" cvar) to the servers hostname and separate it by this symbol");

	HookConVarChange(g_hAllowDN, _DH_Allow_CvarChange);
}

_DN_OnPluginEnd()
{
	ResetConVar(g_hAllowDN);
}

_DN_OnPluginDisabled()
{
	if (strlen(g_sCvarDNSymbol))
		ChangeServerName(g_sDefaultN);
}

_DN_OnConfigsExecuted()
{
	if (!strlen(g_sCvarDNSymbol)) return;

	if (!strlen(g_sDefaultN))
		GetConVarString(g_hHostName, g_sDefaultN, 68);

	if ((g_hReadyUp = FindConVar("l4d_ready_cfg_name")) == INVALID_HANDLE){

		ChangeServerName(g_sDefaultN);
		DebugLog("%s RUP ConVar l4d_ready_cfg_name no found! Change hostname to \"%s\"", DN_TAG, g_sDefaultN);
	}
	else {

		decl String:sReadyUpCfgName[128];
		GetConVarString(g_hReadyUp, sReadyUpCfgName, 128);

		if (!strlen(sReadyUpCfgName)) return;

		Format(sReadyUpCfgName, 128, "%s%s%s", g_sDefaultN, g_sCvarDNSymbol, sReadyUpCfgName);
		ChangeServerName(sReadyUpCfgName);
	}
}

static ChangeServerName(const String:sNewName[])
{
	SetConVarString(g_hHostName, sNewName);
	DebugLog("%s New server name \"%s\"", DN_TAG, sNewName);
}

public _DH_Allow_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (StrEqual(oldValue, newValue)) return;

	strcopy(g_sCvarDNSymbol, 32, newValue);

	DebugLog("%s Dynamic host name is %s", DN_TAG, strlen(g_sCvarDNSymbol) ? "enabled" : "disabled");
}