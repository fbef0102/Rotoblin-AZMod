/*
	SourcePawn is Copyright (C) 2006-2015 AlliedModders LLC.  All rights reserved.
	SourceMod is Copyright (C) 2006-2015 AlliedModders LLC.  All rights reserved.
	Pawn and SMALL are Copyright (C) 1997-2015 ITB CompuPhase.
	Source is Copyright (C) Valve Corporation.
	All trademarks are property of their respective owners.
	This program is free software: you can redistribute it and/or modify it
	under the terms of the GNU General Public License as published by the
	Free Software Foundation, either version 3 of the License, or (at your
	option) any later version.
	This program is distributed in the hope that it will be useful, but
	WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
	General Public License for more details.
	You should have received a copy of the GNU General Public License along
	with this program.  If not, see <http://www.gnu.org/licenses/>.
*/
#include <sourcemod>

public Plugin:myinfo =
{
	name = "Block Trolls",
	description = "Prevents calling votes while others are loading,L4D1 port by Harry",
	author = "ProdigySim, CanadaRox, darkid",
	version = "2.0.1.0",
	url = "https://github.com/jacob404/Pro-Mod-4.0/releases/latest"
};
new bool:g_bBlockCallvote;
new loadedPlayers = 0;

enum L4DTeam
{
	L4DTeam_None = 0,
	L4DTeam_Spectator,
	L4DTeam_Survivor,
	L4DTeam_Infected
}

public OnPluginStart()
{
	AddCommandListener(Vote_Listener, "callvote");
	AddCommandListener(Vote_Listener, "vote");
	AddCommandListener(Vote_Listener, "votes");
	HookEvent("player_team", OnPlayerJoin);
}

public OnMapStart()
{
	g_bBlockCallvote = true;
	loadedPlayers = 0;
	CreateTimer(40.0, EnableCallvoteTimer);
}

public OnPlayerJoin(Handle:event, String:name[], bool:dontBroadcast)
{
	if (GetEventInt(event, "oldteam") == 0) {
		loadedPlayers++;
		if (loadedPlayers == 6) g_bBlockCallvote = false;
	}
}

public Action:Vote_Listener(client, const String:command[], argc)
{
	if (g_bBlockCallvote)
	{
		ReplyToCommand(client,
				"[SM] Voting is not enabled until 60s into the round");
		return Plugin_Handled;
	}
	new L4DTeam:team;
	if (client && IsClientInGame(client))
	{	
		team = L4DTeam:GetClientTeam(client);
		if(team == L4DTeam_Survivor || team == L4DTeam_Infected)
			return Plugin_Continue;
	}
	ReplyToCommand(client,
			"[SM] You must be ingame and not a spectator to vote");
	return Plugin_Handled;
}

public Action:CallvoteCallback(client, args)
{
	if (g_bBlockCallvote)
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action:EnableCallvoteTimer(Handle:timer)
{
	g_bBlockCallvote = false;
	return Plugin_Stop;
}