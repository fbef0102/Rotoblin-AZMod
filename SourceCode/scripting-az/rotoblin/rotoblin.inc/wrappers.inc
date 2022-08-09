/*
 * ============================================================================
 *
 *  Rotoblin
 *
 *  File:			wrappers.inc
 *  Type:			Helper
 *  Description:	Provides wrapper functions for modules
 *
 *  Copyright (C) 2010  Mr. Zero <mrzerodk@gmail.com>
 *  Copyright (C) 2012-2015, 2021  raziEiL [disawar1] <mr.raz4291@gmail.com>
 *  Copyright (C) 2021  Harry <fbef0102@gmail.com>
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

// Don't let the script be included more than once.
#if defined _helper_wrappers
  #endinput
#endif
#define _helper_wrappers

// --------------------
//       Private
// --------------------

static	const	String:	TEAMNAME_SPECTATOR[]	= "Spectator";
static	const	String:	TEAMNAME_SPECTATORS[]	= "Spectators";
static	const	String:	TEAMNAME_SURVIVOR[]		= "Survivor";
static	const	String:	TEAMNAME_SURVIVORS[]	= "Survivors";
static	const	String:	TEAMNAME_INFECTED[]		= "Infected";

#define						VALID_KEY						"0403"
#define						INF							"steam.inf"
#define						PATCH							"PatchVersion="

// **********************************************
//                 Public API
// **********************************************

/**
 * Wrapper for CreateConVar. Prefixes the cvar with the plugins cvar prefix.
 *
 * @param name			Name of new convar.
 * @param defaultValue	String containing the default value of new convar.
 * @param description	Optional description of the convar.
 * @param flags			Optional bitstring of flags determining how the convar should be handled. See FCVAR_* constants for more details.
 * @param hasMin		Optional boolean that determines if the convar has a minimum value.
 * @param min			Minimum floating point value that the convar can have if hasMin is true.
 * @param hasMax		Optional boolean that determines if the convar has a maximum value.
 * @param max			Maximum floating point value that the convar can have if hasMax is true.
 * @return				A handle to the newly created convar. If the convar already exists, a handle to it will still be returned.
 */
stock Handle:CreateConVarEx(const String:name[], const String:defaultValue[], const String:description[]="", flags=0, bool:hasMin=false, Float:min=0.0, bool:hasMax=false, Float:max=0.0)
{
	decl String:buffer[256];
	FormatEx(buffer, sizeof(buffer), "%s_%s", PLUGIN_CVAR_PREFIX, name);
	return CreateConVar(buffer, defaultValue, description, FCVAR_NOTIFY|flags, hasMin, min, hasMax, max);
}

/**
 * Wrapper for RegAdminCmd. Prefixes the cmd with the plugins cmd prefix.
 *
 * @param cmd			String containing command to register.
 * @param callback		A function to use as a callback for when the command is invoked.
 * @param adminflags	Administrative flags (bitstring) to use for permissions.
 * @param description	Optional description to use for help.
 * @param group			String containing the command group to use.  If empty, the plugin's filename will be used instead.
 * @param flags			Optional console flags.
 * @noreturn
 */
stock RegAdminCmdEx(const String:cmd[], ConCmd:callback, adminflags, const String:description[]="", const String:group[]="", flags=0)
{
	decl String:buffer[256];
	FormatEx(buffer, sizeof(buffer), "%s_%s", PLUGIN_CMD_PREFIX, cmd);
	RegAdminCmd(buffer, callback, adminflags, description, group, flags);
}

/**
 * Wrapper for FindEntityByClassname to fall back on last valid entity.
 * Credits to exvel on AlliedModders.
 *
 * @param startEnt		The entity index after which to begin searching from. Use -1 to start from the first entity.
 * @param classname		Classname of the entity to find.
 * @return				Entity index >= 0 if found, -1 otherwise.
 */
stock FindEntityByClassnameEx(startEnt, const String:classname[])
{
	while (startEnt > -1 && !IsValidEntity(startEnt)) startEnt--;
	return FindEntityByClassname(startEnt, classname);
}

/**
 * Replaces entity index with provided entity classname, with same origin and
 * rotation.
 *
 * @param ent			Entity index to replace.
 * @param classname		Entity replacement classname.
 * @param model			Entity model path.
 * @param count			Item count.
 * @return				Entity index of the new entity, 0 for error.
 */
stock ReplaceEntity(ent, const String:classname[], const String:model[], count)
{
	new oldent;

	decl Float:origin[3], Float:rotation[3];
	oldent = ent;
	GetEntPropVector(ent, Prop_Send, "m_vecOrigin", origin);
	GetEntPropVector(ent, Prop_Send, "m_angRotation", rotation);

	if ((ent = CreateEntityByNameEx(classname, model, origin, rotation, count)) == 0)
	{
		return 0; // Faild to create entity, return
	}

	if (!AcceptEntityInput(oldent, "Kill")) // If we couldn't kill old entity by input
	{
		SafelyRemoveEdict(oldent); // Force removal
	}

	return ent;
}

/**
 * Creates a entity with provided classname, origin and rotation.
 *
 * @param classname		Entity classname.
 * @param model			Entity model path.
 * @param origin		Origin of entity.
 * @param rotation		Rotation of entity.
 * @param count			Item count.
 * @return				Entity index of the new entity, 0 for error.
 */
stock CreateEntityByNameEx(const String:classname[], const String:model[], const Float:origin[3], const Float:rotation[3], count)
{
	new ent;

	ent = CreateEntityByName(classname);

	if (!IsModelPrecached(model) && !PrecacheModel(model)) // If model isn't precached and we couldn't precache model
	{
		SafelyRemoveEdict(ent); // Kill the new entity
		return 0;
	}

	SetEntityModel(ent, model);
	TeleportEntity(ent, origin, rotation, NULL_VECTOR);

	decl String:buffer[4];
	IntToString(count, buffer, sizeof(buffer));

	if (!DispatchKeyValue(ent, "count", buffer)) // If we couldn't set item count
	{
		SafelyRemoveEdict(ent); // Kill the new entity
		return 0;
	}

	if (!DispatchSpawn(ent)) // Couldn't dispatch entity
	{
		SafelyRemoveEdict(ent); // Kill the new entity
		return 0;
	}

	ActivateEntity(ent);
	SetEntityMoveType(ent,MOVETYPE_NONE);
	return ent;
}

/**
 * Retrieves the team name based on a team index.
 *
 * @param index			Team index.
 * @param plural		Team name in plural.
 * @param name			Buffer to store string in.
 * @param maxlength		Maximum length of string buffer.
 * @noreturn
 */
stock GetTeamNameEx(index, bool:plural, String:name[], maxLength)
{
	switch(index)
	{
		case TEAM_SPECTATOR:
		{
			if (plural)
			{
				Format(name, maxLength, TEAMNAME_SPECTATORS);
			}
			else
			{
				Format(name, maxLength, TEAMNAME_SPECTATOR);
			}
		}

		case TEAM_SURVIVOR:
		{
			if (plural)
			{
				Format(name, maxLength, TEAMNAME_SURVIVORS);
			}
			else
			{
				Format(name, maxLength, TEAMNAME_SURVIVOR);
			}
		}

		case TEAM_INFECTED:
		{
			Format(name, maxLength, TEAMNAME_INFECTED);
		}
	}
}

/**
 * Retrieve the opposite team index for provided index.
 *
 * @param index			Team index.
 * @return				Team index of the opposite team, -1 for no team found.
 */
stock GetOppositeTeamIndex(index)
{
	switch(index)
	{
		case TEAM_SPECTATOR:
		{
			return TEAM_SPECTATOR;
		}

		case TEAM_SURVIVOR:
		{
			return TEAM_INFECTED;
		}

		case TEAM_INFECTED:
		{
			return TEAM_SURVIVOR;
		}
	}
	return -1;
}

/**
 * Returns the client count put in the server.
 *
 * @param inGameOnly	If false connecting players are also counted.
 * @param fliterBots	If false bots are also counted.
 * @return				Client count in the server.
 */
stock GetClientCountEx(bool:inGameOnly, bool:filterBots)
{
	new clients;
	for (new i; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) &&
			(inGameOnly && IsClientInGame(i)) &&
			(filterBots && !IsFakeClient(i)))
		{
			clients++;
		}
	}
	return clients;
}

/**
 * Performs a cheat command on given client.
 *
 * @param client		Client performing the command. If server index is given as client
 *						a random client will be selected to perform the command.
 * @param command		The command to perform.
 * @param arguments		Optional arguments for the command.
 * @noreturn
 */
stock CheatCommand(client = 0, const String:command[], const String:arguments[] = "")
{
	if (!client || !IsClientInGame(client))
	{
		client = GetAnyClient(true);
		if (!client) return; // Unable to find any clients, return
	}
	new userFlags, flags;

	userFlags = GetUserFlagBits(client);
	SetUserFlagBits(client, ADMFLAG_ROOT);
	flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", command, arguments);
	SetCommandFlags(command, flags);
	SetUserFlagBits(client, userFlags);
}

stock CheatCommandEx(client, const String:command[], const String:arguments[] = "")
{
	new iFlags = GetCommandFlags(command);
	SetCommandFlags(command, iFlags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", command, arguments);
	SetCommandFlags(command, iFlags);
}

/**
 * Return any ingame client.
 *
 * @param filterBots	If false bots are also returned.
 * @return				Client index of an ingame client.
 */
stock GetAnyClient(bool:filterBots)
{
	for (new client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) &&
			(filterBots && !IsFakeClient(client)))
			return client;
	}
	return 0;
}

/**
 * Returns absoulte origin of an entity.
 *
 * @param entity		Entity index to get origin of.
 * @param origin		Buffer to store vector in.
 * @noreturn
 */
stock GetEntityAbsOrigin(entity, Float:origin[3])
{
	if (entity < 1 || !IsValidEntity(entity)) return;

	decl Float:mins[3], Float:maxs[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", origin);
	GetEntPropVector(entity, Prop_Send, "m_vecMins", mins);
	GetEntPropVector(entity, Prop_Send, "m_vecMaxs", maxs);
	for (new i = 0; i < sizeof(mins); i++)
	{
		origin[i] += (mins[i] + maxs[i]) * 0.5;
	}
}

/**
 * Sets ghost state of player.
 *
 * @param client		Client index.
 * @param isGhost		Sets ghost status.
 * @noreturn
 */
stock SetPlayerGhostState(client, bool:isGhost)
{
	SetEntProp(client, Prop_Send, "m_isGhost", isGhost, 1);
}

/**
 * Removes an edict.  Checks the index for validity and then tries to remove via kill, then if that doesn't work, SafelyRemoveEdict.
 *
 * @param entity		The edict to try and remove
 * @return				Whether the removal was successful or not.
 */
stock bool:SafelyRemoveEdict(entity)
{
	if (entity == INVALID_ENT_REFERENCE || entity > MAX_EDICTS || !IsValidEntity(entity))
	{
		return false;
	}
	RemoveEntity(entity);
	return true;
}