/*
 * ============================================================================
 *
 * This file is part of the Rotoblin 2 project.
 *
 *  File:			rotoblin.TrackCvars.sp
 *  Type:			Module
 *  Description:	...
 *
 *  Copyright (C) 2012-2015 raziEiL <war4291@mail.ru>
 *  Copyright (C) 2017-2019 Harry <fbef0102@gmail.com>
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

#define		TC_TAG		"[TrackCvars]"
#define		SILENCE		1

static		Handle:g_hConVarArray, Handle:g_hConVarArrayEx, Handle:g_hSilentMode, bool:g_bCvarSilentMode, bool:g_bLockConVars;

enum CVAR_STRUCTURE
{
	String:sCVar[64],
	iCVar
};

static const g_aStaticVars[][CVAR_STRUCTURE] =
{
	{ "versus_force_start_time",		 9999 },
	{ "director_transition_timeout",		0 },
	{ "sv_hibernate_when_empty",			0 }
};

//-----------------------------------------------------------------------------
// Global functions
//-----------------------------------------------------------------------------
_TrackCvars_OnPluginStart()
{
	g_hSilentMode = CreateConVarEx("cvar_silent_style", "0", "If set, clients will be not notified that a tracked convar has been changed", _, true, 0.0, true, 1.0);
	HookConVarChange(g_hSilentMode, SilentMode_ConVarChange);

	RegServerCmd("rotoblin_track_variable",		CmdTrackVariable,		"Add a convar to track");
	RegServerCmd("rotoblin_track_variable_ex",	CmdTrackVariableEx,	"Add a convar to track but ignore a global lock");
	RegServerCmd("rotoblin_lock_variables",		CmdLockVariable,		"Lock all tracked convar to changes");
	RegServerCmd("rotoblin_unlock_variables",	CmdUnlockVariable,		"Unlock all tracked convar to changes");
	RegServerCmd("rotoblin_reset_variables",		CmdResetVariable,		"Reset all tracked convars to its default value");

	g_hConVarArray = CreateArray(64);
	g_hConVarArrayEx = CreateArray(64);

	// make rotoblin loading when server starts
	new Handle:hCvarHibernate = FindConVar(g_aStaticVars[2][sCVar]);
	SetConVarInt(hCvarHibernate, g_aStaticVars[2][iCVar]);
	HookConVarChange(hCvarHibernate, OnStatic_ConVarChange);
}

_TC_OnPluginStart()
{
	StaticVars(true);
}

_TC_OnPluginDisabled()
{
	StaticVars(false);
	CmdUnlockVariable(0);
	CmdResetVariable(0);
}
_TC_OnPluginEnd()
{
	ResetConVar(g_hSilentMode);
}

// Only for convars that added throught 'rotoblin_track_variable' command
bool:AddConVarToTrack(const String:sConvar[64], const String:sValue[64], bool:bCanBeReseted=true)
{
	new Handle:hConVar = FindConVar(sConvar);
	if (!IsValidConVar(hConVar)){

		DebugLog("%s Warning ConVar \"%s\" not found!", TC_TAG, sConvar);
		DebugLogEx("%s Warning ConVar \"%s\" not found!", TC_TAG, sConvar);
		return false;
	}
	if (IsConVarTracked(g_hConVarArray, sConvar)){

		DebugLog("%s Warning ConVar \"%s\" already tracked!", TC_TAG, sConvar);
		return false;
	}

	DebugLog("%s ConVar \"%s\" \"%s\" is added to track", TC_TAG, sConvar, sValue);

	RemoveConVarNotify(hConVar);
	SetConVarString(hConVar, sValue, true);
	HookConVarChange(hConVar, OnTracked_ConVarChange);

	if (bCanBeReseted)
		PushArrayString(g_hConVarArray, sConvar);

	return true;
}

ReleaseTrackedConVar(const String:sConvar[64])
{
	decl iCvarIndex;
	if ((iCvarIndex = IsConVarTracked(g_hConVarArray, sConvar, _, true)) == -1) return;

	new Handle:hConVar = FindConVar(sConvar);
	RemoveFromArray(g_hConVarArray, iCvarIndex);

	if (!IsValidConVar(hConVar)){

		DebugLog("%s ReleaseCvar: Warning tracked ConVar \"%s\" is no longer valid and skipped", TC_TAG, sConvar);
		return;
	}

	if (!IsPluginEnd())
		UnhookConVarChange(hConVar, OnTracked_ConVarChange);

	ResetConVar(hConVar);
	DebugLog("%s  ReleaseCvar: ResetConVar \"%s\"", TC_TAG, sConvar);
}
//-----------------------------------------------------------------------------

public Action:CmdTrackVariable(args)
{
	if (args != 2 && args != 3){

		PrintToServer("rotoblin_track_variable <can not be reseted? true|emtpy> <convar> <val>");
		return Plugin_Handled;
	}

	decl String:sConvar[64], String:sValue[64];
	GetCmdArg(1, sConvar, 64);

	new bool:bCanBeReseted = true;
	if (StrEqual(sConvar, "true")){

		bCanBeReseted = false;
		GetCmdArg(2, sConvar, 64);
	}

	GetCmdArg(bCanBeReseted ? 2 : 3, sValue, 64);
	AddConVarToTrack(sConvar, sValue, bCanBeReseted);

	return Plugin_Handled;
}

public Action:CmdTrackVariableEx(args)
{
	if (args != 2){

		PrintToServer("rotoblin_track_variable_ex <convar> <val>");
		return Plugin_Handled;
	}

	decl String:sConvar[64];
	GetCmdArg(1, sConvar, 64);

	new Handle:hConVar = FindConVar(sConvar);
	if (!IsValidConVar(hConVar)){

		DebugLog("%s Warning ConVarEx \"%s\" not found!", TC_TAG, sConvar);
		return Plugin_Handled;
	}

	decl String:sValue[64];
	GetCmdArg(2, sValue, 64);

	RemoveConVarNotify(hConVar);
	SetConVarString(hConVar, sValue, true);

	if (IsConVarTracked(g_hConVarArrayEx, sConvar))
		return Plugin_Handled;

	DebugLog("%s ConVarEx \"%s\" \"%s\" is added to track", TC_TAG, sConvar, sValue);

	PushArrayString(g_hConVarArrayEx, sConvar);
	return Plugin_Handled;
}

public Action:CmdLockVariable(args)
{
	if (g_bLockConVars) return;

	g_bLockConVars = true;
	DebugLog("%s Changing of ConVars is Locked!", TC_TAG);
}

public Action:CmdUnlockVariable(args)
{
	if (!g_bLockConVars) return;

	g_bLockConVars = false;
	DebugLog("%s Changing of ConVars is Unlocked!", TC_TAG);
}

public Action:CmdResetVariable(args)
{
	new iArraySize;

	if ((iArraySize = IsConVarTracked(g_hConVarArray, _, true)))
		ResetConVars(g_hConVarArray, iArraySize, false);

	if ((iArraySize = IsConVarTracked(g_hConVarArrayEx, _, true)))
		ResetConVars(g_hConVarArrayEx, iArraySize, true);

	DebugLog("%s Stop tracked all ConVars", TC_TAG);
}

static ResetConVars(Handle:hArray, iArraySize, bool:bConVarEx)
{
	decl String:sArrayConVar[64], Handle:hConVar;

	for (new Index = 0; Index < iArraySize; Index++){

		GetArrayString(hArray, Index, sArrayConVar, 64);
		hConVar = FindConVar(sArrayConVar);

		if (!IsValidConVar(hConVar)){

			DebugLog("%s Warning tracked ConVar \"%s\" is no longer valid and skipped", TC_TAG, sArrayConVar);
			continue;
		}

		if (!bConVarEx && !IsPluginEnd())
			UnhookConVarChange(hConVar, OnTracked_ConVarChange);

		ResetConVar(hConVar);
		DebugLog("%s ResetConVar \"%s\"", TC_TAG, sArrayConVar);
	}

	ClearArray(hArray);
}

static IsConVarTracked(Handle:hArray, const String:sConVar[] = "", bool:bResetConVars = false, bool:bReturnIndex = false)
{
	if (hArray == INVALID_HANDLE){

		DebugLog("%s Array hndl is invalide!", TC_TAG);
		if (bReturnIndex) return -1;
		else return false;
	}

	new iArraySize = GetArraySize(hArray);

	if (!iArraySize){

		if (strlen(sConVar) == 0)
			DebugLog("%s None of the ConVar is not tracked", TC_TAG);
		if (bReturnIndex) return -1;
		else return false;
	}
	if (bResetConVars)
		return iArraySize;

	if (bReturnIndex) return FindStringInArray(hArray, sConVar);
	else return FindStringInArray(hArray, sConVar) != -1;
}

static bool:IsValidConVar(Handle:hConVar)
{
	return hConVar != INVALID_HANDLE;
}

static RemoveConVarNotify(Handle:hCvar)
{
	if (!g_bCvarSilentMode) return;
	new iFlags = GetConVarFlags(hCvar);

	if (iFlags & FCVAR_NOTIFY){

		iFlags &= ~FCVAR_NOTIFY;
		SetConVarFlags(hCvar, iFlags);
	}
}

static StaticVars(bool:bHook)
{
	static bool:bHooked;

	if (bHook){

		if (!bHooked)
			bHooked = true;
		else
			return;
	}
	else if (!bHook)
		bHooked = false;

	new iMaxSize = sizeof(g_aStaticVars);
	decl Handle:hCvar;

	for (new INDEX; INDEX < iMaxSize; INDEX++){

		if (INDEX == 2) continue;
		DebugLog("%s StaticConVar \"%s\" \"%d\" now is %s", TC_TAG, g_aStaticVars[INDEX][sCVar], g_aStaticVars[INDEX][iCVar], bHook ? "blocked" : "reseted");

		hCvar = FindConVar(g_aStaticVars[INDEX][sCVar]);

		if (bHook){

			SetConVarInt(hCvar, g_aStaticVars[INDEX][iCVar]);
			HookConVarChange(hCvar, OnStatic_ConVarChange);
		}
		else {

			if (!IsPluginEnd())
				UnhookConVarChange(hCvar, OnStatic_ConVarChange);

			ResetConVar(hCvar);
		}
	}
}

public SilentMode_ConVarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (!StrEqual(oldValue, newValue))
		g_bCvarSilentMode = GetConVarBool(convar);
}

public OnTracked_ConVarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (!g_bLockConVars || StrEqual(oldValue, newValue)) return;

	decl String:sConvar[128];
	GetConVarName(convar, sConvar, 128);
	#if !SILENCE
		PrintToChatAll("ConVar \"%s\" is tracked. It Cannot be changed from \"%s\" to \"%s\"!", sConvar, oldValue, newValue);
	#endif
	DebugLog("%s ConVar \"%s\" is tracked. It Cannot be changed from \"%s\" to \"%s\"!", TC_TAG, sConvar, oldValue, newValue);

	UnhookConVarChange(convar, OnTracked_ConVarChange);
	SetConVarString(convar, oldValue, true);
	HookConVarChange(convar, OnTracked_ConVarChange);
}

public OnStatic_ConVarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (StrEqual(oldValue, newValue)) return;

	decl String:sConvar[128];
	GetConVarName(convar, sConvar, 128);

	DebugLog("%s StaticConVar \"%s\" is tracked. It Cannot be changed from \"%s\" to \"%s\"!", TC_TAG, sConvar, oldValue, newValue);

	UnhookConVarChange(convar, OnStatic_ConVarChange);
	SetConVarString(convar, oldValue, true);
	HookConVarChange(convar, OnStatic_ConVarChange);
}
