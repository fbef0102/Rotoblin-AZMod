/*
	SourcePawn is Copyright (C) 2006-2008 AlliedModders LLC.  All rights reserved.
	SourceMod is Copyright (C) 2006-2008 AlliedModders LLC.	 All rights reserved.
	Pawn and SMALL are Copyright (C) 1997-2008 ITB CompuPhase.
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
	with this program.	If not, see <http://www.gnu.org/licenses/>.
*/

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <multicolors>
#undef REQUIRE_PLUGIN
static Handle:g_hCVarMinAllowedSlots;
static Handle:g_hCVarMaxAllowedSlots;

static Handle:g_hCVarMaxPlayersToolZ;

static bool:g_bL4DToolz;

static g_iMinAllowedSlots;
static g_iMaxAllowedSlots;

static g_iCurrentSlots;
static g_iDesiredSlots;

static Handle:g_cvarSlotsPluginEnabled = INVALID_HANDLE;
static Handle:g_cvarSlotsAutoconf	= INVALID_HANDLE;
static Handle:g_cvarSvVisibleMaxPlayers = INVALID_HANDLE;
new bool:g_bSlotsLocked = false;
static g_slotdelay;
new Handle:g_hCvarPlayerLimit;
native IsInPause();
native ClientVoteMenuSet(client,trueorfalse);//from votes3
#define SlotVoteCommandDelay 2.5
Menu g_hSlotVote = null;
new Votey = 0;
new Voten = 0;
#define VOTE_NO "no"
#define VOTE_YES "yes"
#define SLOTDELAY_TIME 60
new Handle:g_Cvar_Limits;

public Plugin:myinfo =
{
	name = "L4D Slot Vote",
	author = "X-Blaze & Harry Potter",
	description = "Allow players to change server slots by using vote.",
	version = "2.3",
	url = "http://steamcommunity.com/profiles/76561198026784913"
};

public OnPluginStart()
{
	LoadTranslations("Roto2-AZ_mod.phrases");
	g_cvarSlotsPluginEnabled = CreateConVar("sm_slot_vote_enabled", "1", "Enabled?", FCVAR_NOTIFY);
	g_cvarSlotsAutoconf = CreateConVar("sm_slot_autoconf", "1", "Autoconfigure slots vote max|min cvars?", FCVAR_NOTIFY);
	g_hCVarMinAllowedSlots = CreateConVar("sm_slot_vote_min", "10", "Minimum allowed number of server slots (this value must be equal or lesser than sm_slot_vote_max).", FCVAR_NOTIFY, true, 1.0, true, 32.0);
	g_hCVarMaxAllowedSlots = CreateConVar("sm_slot_vote_max", "28", "Maximum allowed number of server slots (this value must be equal or greater than sm_slot_vote_min).", FCVAR_NOTIFY, true, 1.0, true, 32.0);

	g_hCVarMaxPlayersToolZ = FindConVar("sv_maxplayers");
	g_cvarSvVisibleMaxPlayers = FindConVar("sv_visiblemaxplayers");
	g_iMinAllowedSlots = GetConVarInt(g_hCVarMinAllowedSlots);
	g_iMaxAllowedSlots = GetConVarInt(g_hCVarMaxAllowedSlots);

	//PrintToServer("Slots set onload to: %d", GetConVarInt(g_hCVarMaxPlayersToolZ));
	HookConVarChange(g_hCVarMinAllowedSlots, CVarChangeMinAllowedSlots);
	HookConVarChange(g_hCVarMaxAllowedSlots, CVarChangeMaxAllowedSlots);

	if (g_hCVarMaxPlayersToolZ != INVALID_HANDLE)
	{
		g_iCurrentSlots = GetConVarInt(g_hCVarMaxPlayersToolZ);
		HookConVarChange(g_hCVarMaxPlayersToolZ, CVarChangeSlots);
		g_bL4DToolz = true;
	}

	if (!g_bL4DToolz)
	{
		SetFailState("Supported slot patching mods not detected. Slot Vote disabled.");
	}

	if (g_iCurrentSlots == -1)
	{
		g_iCurrentSlots = 8;
	}
	if(GetConVarBool(g_cvarSlotsAutoconf)) {
		new Handle:hSurvivorLimit = FindConVar("survivor_limit");
		//SetConVarInt(g_hCVarMinAllowedSlots, GetConVarInt(hSurvivorLimit) * 2);
		PrintToServer("Min slots automatically configured to %d", GetConVarInt(hSurvivorLimit) * 2);
		CloseHandle(hSurvivorLimit);
	}
	RegConsoleCmd("sm_slots", Cmd_SlotVote);
	RegConsoleCmd("sm_nospec", Cmd_NoSpec);
	RegConsoleCmd("sm_nospecs", Cmd_NoSpec);
	RegConsoleCmd("sm_kickspec", Cmd_NoSpec);
	RegConsoleCmd("sm_kickspecs", Cmd_NoSpec);
	RegConsoleCmd("sm_maxslots", Cmd_SlotVote);
	RegServerCmd("sm_lock_slots", Cmd_LockSlots);
	RegServerCmd("sm_unlock_slots", Cmd_UnLockSlots);
	
	g_hCvarPlayerLimit = CreateConVar("sm_slotvote_player_limit", "3", "Minimum # of players in game to start the vote", FCVAR_NOTIFY);
	g_Cvar_Limits = CreateConVar("sm_matchvotes_s", "0.60", "百分比.", 0, true, 0.05, true, 1.0);
}

public OnMapStart()
{
	g_slotdelay = 15;
	CreateTimer(1.0, Timer_VoteDelay, _, TIMER_REPEAT| TIMER_FLAG_NO_MAPCHANGE);
	
	PrecacheSound("ui/menu_enter05.wav");
	PrecacheSound("ui/beep_synthtone01.wav");
	PrecacheSound("ui/beep_error01.wav");
}

public Action:Cmd_LockSlots(args) {	
	g_bSlotsLocked = true;
	PrintToServer("[TS] Server slots count locked!");
	PrintToChatAll("[TS] %t","Server slots count locked!");
	return Plugin_Handled;
}

public Action:Cmd_UnLockSlots(args) {
	g_bSlotsLocked = false;
	PrintToServer("[TS] Server slots count unlocked!");
	PrintToChatAll("[TS] %t","Server slots count unlocked!");
	return Plugin_Handled;
}

public CVarChangeMinAllowedSlots(Handle:hCVar, const String:sOldValue[], const String:sNewValue[])
{
	if(!GetConVarBool(g_cvarSlotsPluginEnabled)) return;
	g_iMinAllowedSlots = StringToInt(sNewValue);

	if (g_iMinAllowedSlots > g_iMinAllowedSlots)
	{
		g_iMinAllowedSlots = g_iMaxAllowedSlots;
	}
}

public CVarChangeMaxAllowedSlots(Handle:hCVar, const String:sOldValue[], const String:sNewValue[])
{
	if(!GetConVarBool(g_cvarSlotsPluginEnabled)) return;
	g_iMaxAllowedSlots = StringToInt(sNewValue);

	if (g_iMinAllowedSlots > g_iMaxAllowedSlots)
	{
		g_iMaxAllowedSlots = g_iMinAllowedSlots;
	}
}

public Action:Cmd_SlotVote(iClient, iArgs)
{
	if(g_bSlotsLocked) {
		PrintToChat(iClient, "[TS] %T","locked by config or admin.1",iClient);
		return Plugin_Handled;
	}
	if(!GetConVarBool(g_cvarSlotsPluginEnabled)) return Plugin_Handled;
	
	if (IsInPause())
	{
		return Plugin_Handled;
	}
	
	if(iClient < 1) return Plugin_Handled;

	if(GetAdminFlag(GetUserAdmin(iClient), Admin_Generic))
	{
		if (iArgs == 1)
		{
			decl String:buf[3];
			GetCmdArg(1, buf, sizeof(buf));
			g_iDesiredSlots = StringToInt(buf);
			
			if (g_iDesiredSlots == g_iCurrentSlots)
			{
				CPrintToChat(iClient, "%T", "Same as current", iClient, g_iDesiredSlots);
				return Plugin_Handled;
			}

			if (g_iDesiredSlots >= g_iMinAllowedSlots && g_iDesiredSlots <= g_iMaxAllowedSlots)
			{
				CPrintToChatAll("[{olive}TS{default}] {lightgreen}%N{default} %t: {green}%d{default} - > {green}%d",iClient,"Change_Server_Slots",g_iCurrentSlots,g_iDesiredSlots);
				ChangeSeverSlots();
			}
			else
			{
				CPrintToChat(iClient, "%T", "Usage", iClient, g_iMinAllowedSlots, g_iMaxAllowedSlots, "!slots <number>");
			}
			return Plugin_Handled;
		}
	}
	
	if (GetClientTeam(iClient) == 1)
	{
		PrintToChat(iClient, "%T", "Spectator response",iClient);
		return Plugin_Handled;
	}
	
	if (!TestVoteDelay(iClient))
	{
		return Plugin_Handled;
	}
	
	if (CanStartVotes(iClient))
	{
		if (iArgs == 1)
		{
			decl String:sArgs[4];
			GetCmdArg(1, sArgs, sizeof(sArgs));

			g_iDesiredSlots = StringToInt(sArgs);

			if (g_iDesiredSlots == g_iCurrentSlots)
			{
				CPrintToChat(iClient, "%T", "Same as current", iClient, g_iDesiredSlots);
				return Plugin_Handled;
			}

			if (g_iDesiredSlots >= g_iMinAllowedSlots && g_iDesiredSlots <= g_iMaxAllowedSlots)
			{
				CreateTimer(0.1, Timer_StartSlotVote, iClient, TIMER_FLAG_NO_MAPCHANGE);
			}
			else
			{
				CPrintToChat(iClient, "%T", "Usage", iClient, g_iMinAllowedSlots, g_iMaxAllowedSlots, "!slots <number>");
			}

			return Plugin_Handled;
		}
		ClientVoteMenuSet(iClient,1);
		CreateTimer(0.1, Timer_CreateSlotMenu, iClient, TIMER_FLAG_NO_MAPCHANGE);
	}
	else
	{
		PrintToChat(iClient, "%T", "Vote denied", iClient);
	}

	return Plugin_Handled;
}

public Action:Timer_StartSlotVote(Handle:hTimer, any:iClient)
{
	if (IsClientInGame(iClient) && GetClientTeam(iClient) > 1)
	{
		StartSlotVote(iClient);
	}
}

public Action:Timer_CreateSlotMenu(Handle:hTimer, any:iClient)
{
	if (IsClientInGame(iClient) && GetClientTeam(iClient) > 1)
	{
		CreateSlotMenu(iClient);
	}
}

public Action:Cmd_NoSpec(iClient, iArgs)
{
	if(g_bSlotsLocked) {
		PrintToChat(iClient, "[TS] %T","locked by config or admin.2",iClient);
		return Plugin_Handled;
	}
	if(!GetConVarBool(g_cvarSlotsPluginEnabled)) return Plugin_Handled;

	if (IsInPause())
	{
		return Plugin_Handled;
	}
	
	new iSpecs = 0;

	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i)
		&&	!IsFakeClient(i)
		&&	GetClientTeam(i) == 1)
		{
			iSpecs++;
		}
	}

	if (iSpecs == 0)
	{
		PrintToChat(iClient, "T", "No spectators",iClient);
		return Plugin_Handled;
	}

	if(GetAdminFlag(GetUserAdmin(iClient), Admin_Generic))
	{
		CPrintToChatAll("[{olive}TS{default}] {lightgreen}%N{default} %t.",iClient,"kicks all spectators");
		KickAllSpectators();
		return Plugin_Handled;
	}

	if (GetClientTeam(iClient) == 1)
	{
		PrintToChat(iClient, "%T", "Spectator response,",iClient);
		return Plugin_Handled;
	}
	
	CreateTimer(0.1, Timer_StartNoSpecVote, iClient, TIMER_FLAG_NO_MAPCHANGE);
	
	return Plugin_Handled;
}

public Action:Timer_StartNoSpecVote(Handle:hTimer, any:iClient)
{
	if (IsClientInGame(iClient) && GetClientTeam(iClient) > 1)
	{
		StartNoSpecVote(iClient);
	}
}

static CreateSlotMenu(iClient)
{
	new Handle:hSlotMenu = CreateMenu(MenuHandler_SlotMenu);

	decl String:sBuffer[256], String:sCycle[4];

	FormatEx(sBuffer, sizeof(sBuffer), "%T", "Slot vote title", iClient, g_iCurrentSlots);
	SetMenuTitle(hSlotMenu, sBuffer);

	for (new i = g_iMinAllowedSlots; i <= g_iMaxAllowedSlots; i++)
	{
		FormatEx(sCycle, sizeof(sCycle), "%i", i);
		FormatEx(sBuffer, sizeof(sBuffer), "%i %T", i, "Slots", iClient);
		AddMenuItem(hSlotMenu, sCycle, sBuffer);
	}

	SetMenuExitButton(hSlotMenu, true);
	DisplayMenu(hSlotMenu, iClient, 30);
}

public MenuHandler_SlotMenu(Handle:hSlotMenu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		new String:sInfo[3];

		if (GetMenuItem(hSlotMenu, param2, sInfo, sizeof(sInfo)))
		{
			g_iDesiredSlots = StringToInt(sInfo);
			
			if (g_hCVarMaxPlayersToolZ != INVALID_HANDLE)
			{
				g_iCurrentSlots = GetConVarInt(g_hCVarMaxPlayersToolZ);
			}
			if (g_iDesiredSlots == g_iCurrentSlots)
			{
				CPrintToChat(param1, "%T", "Same as current", param1, g_iDesiredSlots);
				return;
			}

			StartSlotVote(param1);
		}
	}

	if (action == MenuAction_End)
	{
		CloseHandle(hSlotMenu);
	}
}

static StartSlotVote(iClient)
{
	if (GetClientTeam(iClient) == 1)
	{
		PrintToChat(iClient, "%T", "Spectator response",iClient);
		return;
	}

	if (CanStartVotes(iClient))
	{
		decl String:SteamId[35];
		GetClientAuthId(iClient, AuthId_Steam2,SteamId, sizeof(SteamId));
		LogMessage("%N(%s) starts a vote: Change server slots to %i?",  iClient, SteamId,g_iDesiredSlots);//紀錄在log文件
		CPrintToChatAll("{default}[{olive}TS{default}]{blue} %N {default}%t: %t ->%i?", iClient,"starts a vote","Change_Server_Slots", g_iDesiredSlots);
		
		for(new i=1; i <= MaxClients; i++) ClientVoteMenuSet(i,1);
		
		g_hSlotVote = new Menu(Handler_SlotCallback, MENU_ACTIONS_ALL);
		g_hSlotVote.SetTitle("%T->%i?","Change_Server_Slots",LANG_SERVER,g_iDesiredSlots);
		g_hSlotVote.AddItem(VOTE_YES, "Yes");
		g_hSlotVote.AddItem(VOTE_NO, "No");
		g_hSlotVote.ExitButton = false;
		g_hSlotVote.DisplayVoteToAll(20);
		
		EmitSoundToAll("ui/beep_synthtone01.wav");
	
		
		return;
	}

	PrintToChat(iClient, "%T", "Vote denied",iClient);
}

public Action:TimerChangeMaxPlayers(Handle:timer)
{
	ChangeSeverSlots();
	return Plugin_Stop;
}

static StartNoSpecVote(iClient)
{
	if (GetClientTeam(iClient) == 1)
	{
		PrintToChat(iClient, "%T", "Spectator response",iClient);
		return;
	}
	
	if (!TestVoteDelay(iClient))
	{
		return;
	}
	
	if(CanStartVotes(iClient))
	{
		decl String:SteamId[35];
		GetClientAuthId(iClient, AuthId_Steam2,SteamId, sizeof(SteamId));
		LogMessage("%N(%s) starts a vote: kick spectators?",  iClient, SteamId);//紀錄在log文件
		CPrintToChatAll("{default}[{olive}TS{default}]{blue} %N {default}%t: %t?", iClient,"starts a vote","kicks all spectators");
		
		for(new i=1; i <= MaxClients; i++) ClientVoteMenuSet(i,1);
		

		g_hSlotVote = new Menu(Handler_SlotCallback2, MENU_ACTIONS_ALL);
		g_hSlotVote.SetTitle("%T?","kicks all spectators",LANG_SERVER);
		g_hSlotVote.AddItem(VOTE_YES, "Yes");
		g_hSlotVote.AddItem(VOTE_NO, "No");
		g_hSlotVote.ExitButton = false;
		g_hSlotVote.DisplayVoteToAll(20);
		
		EmitSoundToAll("ui/beep_synthtone01.wav");
		return;
	}
	
	PrintToChat(iClient, "%T", "Vote denied",iClient);
}

public Action:TimerKickAllSpectators(Handle:hTimer)
{
	KickAllSpectators();
	return Plugin_Stop;
}

static KickAllSpectators()
{
	new iSpecs;
	decl String:reason[255];
	Format(reason, sizeof(reason), "%t", "Spectator kick reason");
	decl String:iName[128];
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == 1)
		{
			if(IsPlayerGenericAdmin(i)) { 
				GetClientName(i,iName,128);
				CPrintToChatAll("[{olive}TS{default}] %t","ADM IMMUNE", iName);
				continue;
			}
			BanClient(i, 5, BANFLAG_AUTHID, reason, reason, "nospec");
			iSpecs++;
		}
	}

	if (iSpecs)
	{
		PrintToChatAll("%t", "All spectators kicked");
	}
}

stock GetHumanCount()
{
	new iHumanCount = 0;

	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			iHumanCount++;
		}
	}

	return iHumanCount;
}

bool:TestVoteDelay(client)
{

	new delay = GetVoteDelay();
 	if (delay > 0)
 	{
 		CPrintToChat(client, "{default}[{olive}TS{default}] %T","votes3_12",client, delay);
 		return false;
 	}
	return true;
}

public Action:Timer_VoteDelay(Handle:timer, any:client)
{
	g_slotdelay--;
	if(g_slotdelay<=0)
	{
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

GetVoteDelay()
{
	return g_slotdelay;
}
CheckVotes()
{
	PrintHintTextToAll("%t: %i\n%t: %i","Agree", Votey,"Disagree", Voten);
}
public Action:VoteEndDelay(Handle:timer)
{
	Votey = 0;
	Voten = 0;
	for(new i=1; i <= MaxClients; i++) ClientVoteMenuSet(i,2);
}
VoteMenuClose()
{
	Votey = 0;
	Voten = 0;
	CloseHandle(g_hSlotVote);
	g_hSlotVote = null;
}
Float:GetVotePercent(votes, totalVotes)
{
	return float(votes) / float(totalVotes);
}

bool:CanStartVotes(client)
{
	
 	if(g_hSlotVote != INVALID_HANDLE || IsVoteInProgress())
	{
		CPrintToChat(client, "{default}[{olive}TS{default}] %T","A vote is already in progress!",client);
		return false;
	}
	new iNumPlayers;
	new playerlimit = GetConVarInt(g_hCvarPlayerLimit);
	//list of players
	for (new i=1; i<=MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || !IsClientConnected(i))
		{
			continue;
		}
		iNumPlayers++;
	}
	if (iNumPlayers < playerlimit)
	{
		CPrintToChat(client, "{default}[{olive}TS{default}] %T %T","votes3_13",client,"Not enough players.",client,playerlimit);
		return false;
	}
	
	return true;
}

public Handler_SlotCallback(Menu menu, MenuAction action, int param1, int param2)
{
	//==========================
	if(action == MenuAction_Select)
	{
		switch(param2)
		{
			case 0: 
			{
				Votey += 1;
			}
			case 1: 
			{
				Voten += 1;
			}
		}
	}
	else if ( action == MenuAction_Display)
	{
		char buffer[255];
		Format(buffer, sizeof(buffer), "%T->%i?","Change_Server_Slots",param1,g_iDesiredSlots);
		
		Panel panel = view_as<Panel>(param2);
		panel.SetTitle(buffer);
	}
	//==========================
	decl String:item[64], String:display[64];
	new Float:percent, Float:limit, votes, totalVotes;

	GetMenuVoteInfo(param2, votes, totalVotes);
	GetMenuItem(menu, param1, item, sizeof(item), _, display, sizeof(display));
	
	if (strcmp(item, VOTE_NO) == 0 && param1 == 1)
	{
		votes = totalVotes - votes;
	}
	percent = GetVotePercent(votes, totalVotes);

	limit = GetConVarFloat(g_Cvar_Limits);
	
	CheckVotes();
	if (action == MenuAction_End)
	{
		VoteMenuClose();
	}
	else if (action == MenuAction_VoteCancel && param1 == VoteCancel_NoVotes)
	{
		CPrintToChatAll("{default}[{olive}TS{default}] %t","No votes");
		g_slotdelay = SLOTDELAY_TIME;
		CreateTimer(1.0, Timer_VoteDelay, _, TIMER_REPEAT| TIMER_FLAG_NO_MAPCHANGE);
		EmitSoundToAll("ui/beep_error01.wav");
		CreateTimer(2.0, VoteEndDelay);
	}	
	else if (action == MenuAction_VoteEnd)
	{
		if ((strcmp(item, VOTE_YES) == 0 && FloatCompare(percent,limit) < 0 && param1 == 0) || (strcmp(item, VOTE_NO) == 0 && param1 == 1))
		{
			g_slotdelay = SLOTDELAY_TIME;
			CreateTimer(1.0, Timer_VoteDelay, _, TIMER_REPEAT| TIMER_FLAG_NO_MAPCHANGE);
			EmitSoundToAll("ui/beep_error01.wav");
			CPrintToChatAll("{default}[{olive}TS{default}] %t","Vote fail.", RoundToNearest(100.0*limit), RoundToNearest(100.0*percent), totalVotes);
			CreateTimer(2.0, VoteEndDelay);
		}
		else
		{
			g_slotdelay = SLOTDELAY_TIME;
			CreateTimer(1.0, Timer_VoteDelay, _, TIMER_REPEAT| TIMER_FLAG_NO_MAPCHANGE);
			EmitSoundToAll("ui/menu_enter05.wav");
			CPrintToChatAll("{default}[{olive}TS{default}] %t","Vote pass.", RoundToNearest(100.0*percent), totalVotes);
			CreateTimer(2.0, VoteEndDelay);
			CreateTimer(SlotVoteCommandDelay, TimerChangeMaxPlayers, _, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	return 0;
}

public Handler_SlotCallback2(Menu menu, MenuAction action, int param1, int param2)
{
	//==========================
	if(action == MenuAction_Select)
	{
		switch(param2)
		{
			case 0: 
			{
				Votey += 1;
			}
			case 1: 
			{
				Voten += 1;
			}
		}
	}
	else if ( action == MenuAction_Display)
	{
		char buffer[255];
		Format(buffer, sizeof(buffer), "%T?","kicks all spectators",param1);
		
		Panel panel = view_as<Panel>(param2);
		panel.SetTitle(buffer);
	}
	//==========================
	decl String:item[64], String:display[64];
	new Float:percent, Float:limit, votes, totalVotes;

	GetMenuVoteInfo(param2, votes, totalVotes);
	GetMenuItem(menu, param1, item, sizeof(item), _, display, sizeof(display));
	
	if (strcmp(item, VOTE_NO) == 0 && param1 == 1)
	{
		votes = totalVotes - votes;
	}
	percent = GetVotePercent(votes, totalVotes);

	limit = GetConVarFloat(g_Cvar_Limits);
	
	CheckVotes();
	if (action == MenuAction_End)
	{
		VoteMenuClose();
	}
	else if (action == MenuAction_VoteCancel && param1 == VoteCancel_NoVotes)
	{
		CPrintToChatAll("{default}[{olive}TS{default}] %t","No votes");
		g_slotdelay = SLOTDELAY_TIME;
		CreateTimer(1.0, Timer_VoteDelay, _, TIMER_REPEAT| TIMER_FLAG_NO_MAPCHANGE);
		EmitSoundToAll("ui/beep_error01.wav");
		CreateTimer(2.0, VoteEndDelay);
	}	
	else if (action == MenuAction_VoteEnd)
	{
		if ((strcmp(item, VOTE_YES) == 0 && FloatCompare(percent,limit) < 0 && param1 == 0) || (strcmp(item, VOTE_NO) == 0 && param1 == 1))
		{
			g_slotdelay = SLOTDELAY_TIME;
			CreateTimer(1.0, Timer_VoteDelay, _, TIMER_REPEAT| TIMER_FLAG_NO_MAPCHANGE);
			EmitSoundToAll("ui/beep_error01.wav");
			CPrintToChatAll("{default}[{olive}TS{default}] %t","Vote fail.", RoundToNearest(100.0*limit), RoundToNearest(100.0*percent), totalVotes);
			CreateTimer(2.0, VoteEndDelay);
		}
		else
		{
			g_slotdelay = SLOTDELAY_TIME;
			CreateTimer(1.0, Timer_VoteDelay, _, TIMER_REPEAT| TIMER_FLAG_NO_MAPCHANGE);
			EmitSoundToAll("ui/menu_enter05.wav");
			CPrintToChatAll("{default}[{olive}TS{default}] %t","Vote pass.", RoundToNearest(100.0*percent), totalVotes);
			CreateTimer(2.0, VoteEndDelay);
			CreateTimer(0.1, TimerKickAllSpectators, _, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	return 0;
}

bool:IsPlayerGenericAdmin(client)
{
    if (CheckCommandAccess(client, "generic_admin", ADMFLAG_GENERIC, false))
    {
        return true;
    }

    return false;
}  

stock bool:DisplayVoteMenuToNoSpecators(Handle:hMenu,iTime)
{
    new iTotal = 0;
    new iPlayers[MaxClients];
    
    for (new i = 1; i <= MaxClients; i++)
    {
        if (!IsClientConnected(i) || !IsClientInGame(i) || IsFakeClient(i) || GetClientTeam(i) == 1)
        {
            continue;
        }
        
        iPlayers[iTotal++] = i;
    }
    
    return VoteMenu(hMenu, iPlayers, iTotal, iTime, 0);
}

ChangeSeverSlots()
{
	if (g_bL4DToolz)
	{
		SetConVarInt(g_hCVarMaxPlayersToolZ, g_iDesiredSlots);	
		SetConVarInt(g_cvarSvVisibleMaxPlayers, g_iDesiredSlots);
		g_iCurrentSlots = GetConVarInt(g_hCVarMaxPlayersToolZ);
	}
}

public CVarChangeSlots(Handle:hCVar, const String:sOldValue[], const String:sNewValue[])
{
	g_iCurrentSlots = GetConVarInt(g_hCVarMaxPlayersToolZ);
}