/*
 * ============================================================================
 *
 * This file is part of the Rotoblin 2 project.
 *
 *  File:			rotoblin.PluginManager.sp
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

#define		PM_TAG	"[PluginManager]"

#define		ENABLED_DIR		"addons/sourcemod/plugins/optional"
#define		OPTIONAL 			"optional"

_PluginManager_OnPluginStart()
{
	if (!DirExists(ENABLED_DIR)){

		DebugLog("%s Error: directory <%s> not exists!", PM_TAG, ENABLED_DIR);
		ThrowError("%s Error: directory <%s> not exists!", PM_TAG, ENABLED_DIR);
	}

	RegServerCmd("rotoblin_load_plugin", CmdLoadPl, "Load a plugin from optional folder");
	RegServerCmd("rotoblin_unload_plugins", CmdUnloadPls, "Unloads all plugins from optional folder");
}

_PM_OnPluginDisabled()
{
	CmdUnloadPls(0);
}

public Action:CmdLoadPl(args)
{
	if (!args){

		PrintToServer("rotoblin_load_plugin <name>");
		return Plugin_Handled;
	}

	decl String:sPlName[64], String:sExistPl[128];

	GetCmdArg(1, sPlName, 64);
	FormatEx(sExistPl, 128, "%s/%s", ENABLED_DIR, sPlName);

	if (!FileExists(sExistPl)){

		DebugLogEx("%s Warning! plugin \"%s\" not found!", PM_TAG, sPlName);
		return Plugin_Handled;
	}

	ReplaceString(sExistPl, 128, "addons/sourcemod/plugins/", "");
	_PM_Manager(sExistPl, true);

	return Plugin_Handled;
}

public Action:CmdUnloadPls(args)
{
	if (!DirExists(ENABLED_DIR)){

		DebugLogEx("%s -> Warning! Failed to unload plugins! (optional folder is missing)", PM_TAG);
		return Plugin_Handled;
	}

	DebugLog("%s -> Starts to read and unload all available plugins", PM_TAG);

	decl String:sPlName[64];
	new Handle:hIterator = GetPluginIterator();

	while (MorePlugins(hIterator)){

		GetPluginFilename(ReadPlugin(hIterator), sPlName, 64);

		if (StrContains(sPlName, OPTIONAL) != -1)
			_PM_Manager(sPlName, false);
	}

	DebugLog("%s Done", PM_TAG);
	CloseHandle(hIterator);

	return Plugin_Handled;
}

_PM_Manager(const String:sPlugin[], bool:bLoad)
{
	DebugLog("%s %s -> %s", PM_TAG, bLoad ? "load" : "unload", sPlugin);
	ServerCommand("sm plugins %s %s", bLoad ? "load" : "unload", sPlugin);
}