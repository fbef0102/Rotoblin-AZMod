#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
#include <multicolors>

Menu hVote = null;

new Float:fTankFlow;
new Float:fWitchFlow;

new String:tank[8];
new String:witch[8];
native SaveBossPercents();
native IsInReady();
new Votey = 0;
new Voten = 0;
#define VOTE_NO "no"
#define VOTE_YES "yes"
native ClientVoteMenuSet(client,trueorfalse);//from votes3
native SaveWitchPercent(Float:fWitchFlow); //from l4d_versus_same_UnprohibitBosses
native float GetSurCurrentFloat(); // from l4d_current_survivor_progress

public Plugin:myinfo =
{
	name = "L4D1 Boss Percents Vote",
	author = "Visor, Harry Potter",
	version = "1.2",
	description = "Vote for percentage",
	url = "http://steamcommunity.com/profiles/76561198026784913"
};

public OnPluginStart()
{
	LoadTranslations("Roto2-AZ_mod.phrases");
	RegConsoleCmd("sm_voteboss", Vote);
}

public OnMapStart()
{
	PrecacheSound("ui/menu_enter05.wav");
	PrecacheSound("ui/beep_synthtone01.wav");
	PrecacheSound("ui/beep_error01.wav");
	
	VoteMenuClose();
}

public Action:Vote(client, args) 
{
	if (args < 1 || args > 2)
	{
		CPrintToChat(client, "%T","l4d_bossvote1",client,"!voteboss");
		CPrintToChat(client, "%T","l4d_bossvote2",client,"!voteboss");
		CPrintToChat(client, "%T","l4d_bossvote3",client);
		return Plugin_Handled;
	}
	if(CanStartVotes(client))
	{
		if (args == 2)
		{
			GetCmdArg(1, tank, sizeof(tank));
			fTankFlow = StringToFloat(tank) / 100.0;
			GetCmdArg(2, witch, sizeof(witch));
			fWitchFlow = StringToFloat(witch) / 100.0;
		}
		else
		{
			GetCmdArg(1, tank, sizeof(tank));
			fTankFlow = StringToFloat(tank) / 100.0;
			IntToString(0,witch,sizeof(witch));
			fWitchFlow = 0.0;
		}
			
		if(fTankFlow>=1 || fTankFlow<0 || fWitchFlow>=1 || fWitchFlow<0)
		{
			CPrintToChat(client, "%T","l4d_bossvote1",client,"!voteboss");
			return Plugin_Handled;
		}
		
		if (IsSpectator(client) || !IsInReady() || InSecondHalfOfRound())
		{
			CPrintToChat(client, "%T","l4d_bossvote4",client);
			return Plugin_Handled;
		}

		new String:printmsg[128];
		Format(printmsg, sizeof(printmsg), "%t","l4d_bossvote5", tank, witch);

		StartVote(printmsg);
		decl String:SteamId[35];
		GetClientAuthId(client, AuthId_Steam2,SteamId, sizeof(SteamId));
		CPrintToChatAll("[{olive}TS{default}] {olive}%N{default} %t: {blue}%t{default} ?", client,"starts a vote","l4d_bossvote5",tank,witch);
		LogMessage("%N(%s) called a vote to change Tank: %s%, Witch: %s%",  client, SteamId, tank, witch);//記錄在log文件
	}

	return Plugin_Handled; 
}

bool:CanStartVotes(client)
{
 	if(hVote  != null || IsVoteInProgress())
	{
		CPrintToChat(client, "{default}[{olive}TS{default}] %T","A vote is already in progress!",client);
		return false;
	}
	return true;
}

StartVote(const String:sVoteHeader[])
{
	hVote = new Menu(Handler_VoteCallback, MENU_ACTIONS_ALL);
	hVote.SetTitle("%s ?",sVoteHeader);
	hVote.AddItem(VOTE_YES, "Yes");
	hVote.AddItem(VOTE_NO, "No");
	hVote.ExitButton = false;

	new iTotal = 0;
	new iPlayers[MaxClients];
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || GetClientTeam(i) == 1)
		{
			continue;
		}
		
		iPlayers[iTotal++] = i;
	}
	
	hVote.DisplayVote(iPlayers, iTotal, 20, 0);
	
	EmitSoundToAll("ui/beep_synthtone01.wav");
	
	for(new i=1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || GetClientTeam(i) == 1)
		{
			continue;
		}
		
		ClientVoteMenuSet(i,1);
	}
}

public Handler_VoteCallback(Menu menu, MenuAction action, int param1, int param2)
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
		Format(buffer, sizeof(buffer), "%T ?", "l4d_bossvote5",param1, tank, witch);
		
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

	limit = 0.6;
	
	CheckVotes();
	if (action == MenuAction_End)
	{
		VoteMenuClose();
	}
	else if (action == MenuAction_VoteCancel && param1 == VoteCancel_NoVotes)
	{
		CPrintToChatAll("{default}[{olive}TS{default}] %t","No votes");
		EmitSoundToAll("ui/beep_error01.wav");
		CreateTimer(2.0, VoteEndDelay);
	}	
	else if (action == MenuAction_VoteEnd)
	{
		if ((strcmp(item, VOTE_YES) == 0 && FloatCompare(percent,limit) < 0 && param1 == 0) || (strcmp(item, VOTE_NO) == 0 && param1 == 1))
		{
			EmitSoundToAll("ui/beep_error01.wav");
			CPrintToChatAll("{default}[{olive}TS{default}] %t","Vote fail.", RoundToNearest(100.0*limit), RoundToNearest(100.0*percent), totalVotes);
			CreateTimer(2.0, VoteEndDelay);
		}
		else
		{
			CreateTimer(2.0, RewriteBossFlows);
			CreateTimer(4.0, PrintMessage);
			EmitSoundToAll("ui/menu_enter05.wav");
			CPrintToChatAll("{default}[{olive}TS{default}] %t","l4d_bossvote6");
			CreateTimer(2.0, VoteEndDelay);
		}
	}
	return 0;
}

public Action:RewriteBossFlows(Handle:timer)
{
	if (!InSecondHalfOfRound())
	{
		float fSurvivorflow = GetSurCurrentFloat();

		if ( 0.0 < fTankFlow && 0.01 < fSurvivorflow < 1 && fTankFlow < fSurvivorflow) fTankFlow = fSurvivorflow;
		SetTankSpawn(fTankFlow);

		if ( 0.0 < fWitchFlow && 0.01 < fSurvivorflow < 1 && fWitchFlow < fSurvivorflow) fWitchFlow = fSurvivorflow;
		SetWitchSpawn(fWitchFlow);

		SaveBossPercents();
		SaveWitchPercent(fWitchFlow);
	}
}

public Action:PrintMessage(Handle:timer)
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
			if(!IsFakeClient(i))
				FakeClientCommand(i, "sm_boss");
	}
}

SetTankSpawn(Float:flow)
{
	for (new i = 0; i <= 1; i++)
	{
		if (flow != 0)
		{
			L4D2Direct_SetVSTankToSpawnThisRound(i, true);
			L4D2Direct_SetVSTankFlowPercent(i, flow);
		}
		else
		{
			L4D2Direct_SetVSTankToSpawnThisRound(i, false);
			L4D2Direct_SetVSTankFlowPercent(i, 0.0);
		}
	}
}

SetWitchSpawn(Float:flow)
{
	for (new i = 0; i <= 1; i++)
	{
		if (flow != 0)
		{
			L4D2Direct_SetVSWitchToSpawnThisRound(i, true);
			L4D2Direct_SetVSWitchFlowPercent(i, flow);
		}
		else
		{
			L4D2Direct_SetVSWitchToSpawnThisRound(i, false);
			L4D2Direct_SetVSWitchFlowPercent(i, 0.0);
		}
	}
}

stock bool:IsSpectator(client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 1;
}

bool:InSecondHalfOfRound()
{
	return bool:GameRules_GetProp("m_bInSecondHalfOfRound");
}

CheckVotes()
{
	PrintHintTextToAll("%t: %i\n%t: %i","Agree", Votey,"Disagree", Voten);
}
public Action:VoteEndDelay(Handle:timer)
{
	Votey = 0;
	Voten = 0;
	for(new i=1; i <= MaxClients; i++) ClientVoteMenuSet(i,0);
}
VoteMenuClose()
{
	Votey = 0;
	Voten = 0;
	CloseHandle(hVote);
	hVote = null;
}
Float:GetVotePercent(votes, totalVotes)
{
	return (float(votes) / float(totalVotes));
}