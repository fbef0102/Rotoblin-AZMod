#include <sourcemod>

#pragma semicolon 1

#define PLUGIN_VERSION "1.5.5"
#define CVAR_FLAGS FCVAR_PLUGIN
#define TEAM_SPECTATOR 1
#define TEAM_INFECTED 3
#define VOTE_DELAY 5.0

public Plugin:myinfo =
{
	name = "L4D Vote Manager 2",
	author = "Madcap",
	description = "Control permissions on voting and make voting respect admin levels.",
	version = PLUGIN_VERSION,
	url = "http://maats.org"
};

// cvar handles
new Handle:lobbyAccess;
new Handle:difficultyAccess;
new Handle:levelAccess;
new Handle:restartAccess;
new Handle:kickAccess;
new Handle:kickImmunity;
new Handle:sendToLog;
new Handle:vetoAccess;
new Handle:passVoteAccess;
new Handle:voteTimeout;
new Handle:voteNoTimeoutAccess;
new Handle:customAccess;
new Handle:voteNotify;
new Handle:survivalMap;
new Handle:survivalLobby;
new Handle:survivalRestart;
new Handle:tankKickImmunity;

new bool:inVoteTimeout[MAXPLAYERS+1];

// custom vote variables
new bool:hasVoted[MAXPLAYERS+1];
new bool:customVoteInProgress = false;  
new String:customVote[128]="";
new customVotesMax;
new customYesVotes;
new customNoVotes;

// exploit fix
new bool:voteInProgress = false;
new bool:postVoteDelay = false;
new bool:playerVoted[MAXPLAYERS+1]; // currently unused, possible future use

public OnPluginStart()
{
	LoadTranslations("Roto2-AZ_mod.phrases");
	RegConsoleCmd("custom_vote",CustomVote_Handler);
	RegConsoleCmd("Vote",Vote_Handler);

	RegConsoleCmd("callvote",Callvote_Handler);
	RegConsoleCmd("veto",Veto_Handler);
	RegConsoleCmd("passvote",PassVote_Handler);
	
	lobbyAccess         = CreateConVar("l4d_vote_lobby_access",           "",  "Access level needed to start a return to lobby vote",CVAR_FLAGS);
	difficultyAccess    = CreateConVar("l4d_vote_difficulty_access",      "",  "Access level needed to start a change difficulty vote",CVAR_FLAGS);
	levelAccess         = CreateConVar("l4d_vote_level_access",           "",  "Access level needed to start a change level vote",CVAR_FLAGS);
	restartAccess       = CreateConVar("l4d_vote_restart_access",         "",  "Access level needed to start a restart level vote",CVAR_FLAGS);
	kickAccess          = CreateConVar("l4d_vote_kick_access",            "",  "Access level needed to start a kick vote",CVAR_FLAGS);
	kickImmunity        = CreateConVar("l4d_vote_kick_immunity",          "1", "Make votekick respect admin immunity",CVAR_FLAGS,true,0.0,true,1.0);
	vetoAccess          = CreateConVar("l4d_vote_veto_access",            "z", "Access level needed to veto a vote",CVAR_FLAGS);
	passVoteAccess      = CreateConVar("l4d_vote_pass_access",            "z", "Access level needed to pass a vote",CVAR_FLAGS);
	voteTimeout         = CreateConVar("l4d_vote_timeout",                "0", "Players must wait (timeout) this many seconds between votes. 0 = no timeout",CVAR_FLAGS,true,0.0);
	voteNoTimeoutAccess = CreateConVar("l4d_vote_no_timeout_access",      "",  "Access level needed to not have vote timeout.",CVAR_FLAGS);
	sendToLog           = CreateConVar("l4d_vote_log",                    "0", "Log voting data",CVAR_FLAGS,true,0.0,true,1.0);
	customAccess        = CreateConVar("l4d_custom_vote_access",          "z", "Access level needed to call custom votes.",CVAR_FLAGS);
	voteNotify          = CreateConVar("l4d_vote_notify_access",          "",  "Who sees certain vote related notices. If blank everyone sees them.", CVAR_FLAGS);
	survivalMap         = CreateConVar("l4d_vote_surv_map_access",        "",  "Access level needed to switch Survival maps.",CVAR_FLAGS);
	survivalRestart     = CreateConVar("l4d_vote_surv_restart_access",    "",  "Access level needed to restart Survival maps.",CVAR_FLAGS);
	survivalLobby       = CreateConVar("l4d_vote_surv_lobby_access",      "",  "Access level needed to return to lobby on Survival maps.",CVAR_FLAGS);
	tankKickImmunity    = CreateConVar("l4d_vote_tank_kick_immunity",     "1", "Make tanks immune to vote kicking.",CVAR_FLAGS,true,0.0,true,1.0);
	
	HookEvent("vote_started", EventVoteStart);
	HookEvent("vote_passed", EventVoteEnd);
	HookEvent("vote_failed", EventVoteEnd);
	
	AutoExecConfig(true, "sm_plugin_votemanager2");

	CreateConVar("l4d_votemanager2", PLUGIN_VERSION, "Version number for Vote Manager 2 Plugin", FCVAR_REPLICATED|FCVAR_NOTIFY);
}



// wrapper for PrintToChatAll
// if client is not 0 then that client will be notified regardless of notify access
public Notify(client, String:format[], any:...)
{
	new String:buffer[512];
	VFormat(buffer,sizeof(buffer),format,3);

	decl String:notify[16];
	GetConVarString(voteNotify, notify, sizeof(notify)); 

	for(new i=1;i<=MaxClients;i++)
	{
		if  (IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i) && i!=client && ((strlen(notify)==0) || (GetUserFlagBits(i)&ReadFlagString(notify)!=0)))
		{
			//if (IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i) && i!=client)
			//{
				PrintToChat(i, buffer);
			//}
		}
	}
	
	if (client>0 && IsClientInGame(client) && IsClientConnected(client) && !IsFakeClient(client))
	{
		PrintToChat(client, buffer);
	}
}


// flip voteInProgress flag when a vote starts
public EventVoteStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	voteInProgress = true;
	for(new i=0;i<sizeof(playerVoted);i++)
	{
		playerVoted[i]=false;
	}
}


// flip voteInProgress flag when a vote ends
public EventVoteEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	voteInProgress = false;
	postVoteDelay = true;
	CreateTimer(VOTE_DELAY, VoteDelay);		
}


// flip voteInProgress after a short while
public Action:VoteDelay(Handle:timer, any:client)
{
	postVoteDelay = false;
}


// reset timeouts every map
public OnMapStart()
{
	for(new i=0;i<sizeof(inVoteTimeout);i++) 
		inVoteTimeout[i]=false;
		
	customVoteInProgress = false;
	voteInProgress = false;
	postVoteDelay = false;
}

// reset client's timeout value when they connect
public OnClientConnected(client)
{
	inVoteTimeout[client]=false;
}

// wrapper logging function with built in checking to see if logging is enabled
public LogVote(client,String:format[], any:...)
{

	// sample usage: LogVote(client,"was prevented from starting a %s vote",voteName)

	if (GetConVarBool(sendToLog))
	{
		new String:buffer[512];
		VFormat(buffer,sizeof(buffer),format,3);
		new String:name[MAX_NAME_LENGTH]="";
		new String:steamid[32]="";
			
		if (client==0)
		{
			name="Server";
			steamid="ServerID";
		}
		else
		{
			GetClientName(client,name,sizeof(name));
			GetClientAuthString(client,steamid,sizeof(steamid));
		}
	
		LogMessage("<%s><%s> %s",name,steamid,buffer);
	
	}
}



// return true if client can make the vote
public hasVoteAccess(client, String:voteName[32])
{

	// rcon always has access
	if (client==0)
		return true;

	new String:acclvl[16];
	decl String:gmode[32];
	
	GetConVarString(FindConVar("mp_gamemode"), gmode, sizeof(gmode));

	new bool:survival = false;
	if (strcmp(gmode, "survival", false) == 0)
		survival=true;
		
	if (strcmp(voteName,"ReturnToLobby",false) == 0) 
	{
		if (survival)
			GetConVarString(survivalLobby,acclvl,sizeof(acclvl));
		else	
			GetConVarString(lobbyAccess,acclvl,sizeof(acclvl));
	}
	else if (strcmp(voteName,"ChangeDifficulty",false) == 0) 
	{
		GetConVarString(difficultyAccess,acclvl,sizeof(acclvl));
	}
	else if (strcmp(voteName,"ChangeMission",false) == 0) 
	{
		GetConVarString(levelAccess,acclvl,sizeof(acclvl));
	}
	else if (strcmp(voteName,"RestartGame",false) == 0) 
	{
		if (survival)
			GetConVarString(survivalRestart,acclvl,sizeof(acclvl));
		else
			GetConVarString(restartAccess,acclvl,sizeof(acclvl));
	}
	else if (strcmp(voteName,"Kick",false) == 0) 
	{
		GetConVarString(kickAccess,acclvl,sizeof(acclvl));
	}
	else if (strcmp(voteName,"Veto",false) == 0) 
	{
		GetConVarString(vetoAccess,acclvl,sizeof(acclvl));
	}
	else if (strcmp(voteName,"PassVote",false) == 0) 
	{
		GetConVarString(passVoteAccess,acclvl,sizeof(acclvl));
	}
	else if (strcmp(voteName,"Custom",false) == 0) 
	{
		GetConVarString(customAccess,acclvl,sizeof(acclvl));
	}
	else if (strcmp(voteName,"ChangeChapter",false) == 0) 
	{
		// can chagnechapter be used outside of survival?
		GetConVarString(survivalMap,acclvl,sizeof(acclvl));	
	}
	// voteName does not match a known vote type
	else return false;

	// no permissions set
	if (strlen(acclvl) == 0)
		return true;

	// check permissions
	if (GetUserFlagBits(client)&ReadFlagString(acclvl) == 0)
		return false;

	return true;

}



//return true if client is in time out right now (considering access)
public isInVoteTimeout(client){

	// check if timeout is even activated
	if (GetConVarBool(voteTimeout))
	{
	
		new String:acclvl[16];
		GetConVarString(voteNoTimeoutAccess,acclvl,sizeof(acclvl));
	
		// if the client is excempt from timeout
		if (GetUserFlagBits(client)&ReadFlagString(acclvl) != 0)
			return false;
			
		return inVoteTimeout[client];	
	}
	
	return false;
}


// check a vote name against the known possible votes
public isValidVote(String:voteName[32]){

	if ((strcmp(voteName,"Kick",false) == 0) ||
		(strcmp(voteName,"ReturnToLobby",false) == 0) ||
		(strcmp(voteName,"ChangeDifficulty",false) == 0) ||
		(strcmp(voteName,"ChangeMission",false) == 0) ||
		(strcmp(voteName,"RestartGame",false) == 0) ||
		(strcmp(voteName,"Custom",false) == 0) ||
		(strcmp(voteName,"ChangeChapter",false) == 0))
		return true;
		
	return false;	
}



public Action:Callvote_Handler(client, args)
{

	// return Plugin_Handled;  - to prevent the vote from going through
	// return Plugin_Continue; - to allow the vote to go like normal

	decl String:voteName[32];
	decl String:initiatorName[MAX_NAME_LENGTH];
	GetClientName(client, initiatorName, sizeof(initiatorName));
	GetCmdArg(1,voteName,sizeof(voteName));

	
	// test code
	//decl String:fullCommand[256];
	//GetCmdArgString(fullCommand, sizeof(fullCommand));
	//PrintToChatAll("%s", fullCommand);

	// vote examples:
	// ChangeDifficulty Easy
	// RestartGame
	// ChangeMission Smalltown
	// ChangeChapter 16
	// callvote Kick <client #>

	
	if (voteInProgress)
	{
		PrintToChat(client, "\x04[VOTE] \x01%T","votemanager21",client);
		LogVote(client, "tried starting a %s vote but a vote is in progress.",voteName);
		return Plugin_Handled;
	}

	if (postVoteDelay)
	{
		PrintToChat(client, "\x04[VOTE] \x01%T","votemanager22",client, VOTE_DELAY);
		LogVote(client, "tried starting a %s vote but it is too soon since the last vote.",voteName);
		return Plugin_Handled;
	}
	
	if (!isValidVote(voteName))
	{
	       	PrintToChat(client,"\x04[VOTE] \x01%T: %s","Invalid vote type",client,voteName);
	       	LogVote(client, "tried to start an invalid vote type: %s", voteName);
	       	return Plugin_Handled;
	}

	if (isInVoteTimeout(client)){
		LogVote(client, "cannot start a %s vote.  Reason: Timeout",voteName);
		PrintToChat(client, "\x04[VOTE] \x01%T","votemanager22",client,GetConVarFloat(voteTimeout));
		return Plugin_Handled;		
	}

	if (hasVoteAccess(client, voteName))
	{

		//  put them in timeout (even if vote won't go through)
		inVoteTimeout[client]=true;
		
		// set a timer to take them out of timeout
		new Float:timeout = GetConVarFloat(voteTimeout);
		if (timeout > 0.0)
			CreateTimer(timeout, TimeOutOver, client);

	
		// confirmed player has access to the vote type, now handle any logic for specific types of vote
		// (currently only defined for kick votes)

		if (strcmp(voteName,"Kick",false) == 0)
		{
			// this function must return either Plugin_Handled or Plugin_Continue
			return Kick_Vote_Logic(client, args);
		}
		
		if (strcmp(voteName,"Custom",false) == 0)
		{
			// this function must return either Plugin_Handled or Plugin_Continue
			return Custom_Vote_Logic(client, args);
		}

		// no more custom logic for votes, continue with normal vote behavior
		LogVote(client, "started a %s vote",voteName);
		PrintToChatAll("\x04[VOTE] \x01%t","votemanager23", initiatorName, voteName);
		//Notify(client, "\x04[VOTE] \x01%s initiated a %s vote.", initiatorName, voteName);
		return Plugin_Continue;
				
	}
	else
	{
		// player does not have access to this vote
		LogVote(client, "was prevented from starting a %s vote.  Reason: Access",voteName);
		PrintToChatAll("\x04[VOTE] \x01%t","votemanager24", initiatorName, voteName);
		//Notify(client, "\x04[VOTE] \x01%s tried to start a %s vote but does not have access.", initiatorName, voteName);
		return Plugin_Handled;
	}

}


public Action:TimeOutOver(Handle:timer, any:client)
{
	inVoteTimeout[client] = false;
}



// special logic for handling kick votes
public Action:Kick_Vote_Logic(client, args)
{

	// return Plugin_Handled;  - to prevent the vote from going through
	// return Plugin_Continue; - to allow the vote to go like normal

	decl String:initiatorName[MAX_NAME_LENGTH];
	GetClientName(client, initiatorName, sizeof(initiatorName));

	decl String:arg2[12];
	GetCmdArg(2, arg2, sizeof(arg2));
	new target = GetClientOfUserId(StringToInt(arg2));

	// check that the person targeted for kicking is actually a client
	if ((target<=0) || (!IsClientInGame(target)))
	{
		LogVote(client, "was prevented from starting a Kick vote on client %s.  Reason: Invalid Target", arg2);
		//Notify(client, "\x04[VOTE] \x01%s tried to start a Kick Vote against %s but that is not a valid target.", initiatorName,arg2);
		PrintToChat(client, "\x04[VOTE] \x01%T","votemanager25",client, initiatorName,arg2);
		//PrintToChat(client, "\x04[VOTE] \x01If you are trying to call a manual kick vote the format is: 'callvote kick <user id>'");
		return Plugin_Handled;
	}

	decl String:targetName[MAX_NAME_LENGTH];
	GetClientName(target, targetName, sizeof(targetName));



	// tanks cannot be kicked if the convar is set to 1
	if (GetConVarBool(tankKickImmunity) && (GetClientTeam(target) == TEAM_INFECTED) && IsPlayerAlive(target))
	{
		new String:model[128];
		GetClientModel(target, model, sizeof(model));
		if (StrContains(model, "hulk", false) > 0)
		{
			LogVote(client, "was prevented from starting a Kick vote on %s.  Reason: Tank", targetName);
			PrintToChatAll("\x04[VOTE] \x01%t","votemanager26",initiatorName,targetName);
			//Notify(client,"\x04[VOTE] \x01%s tried to start a Kick Vote against %s but tanks cannot be kicked.",initiatorName,targetName);
			return Plugin_Handled;
		}
	}
	
	// Forbid Spectator team from kicking
	if (GetClientTeam(client) == TEAM_SPECTATOR)
	{
		LogVote(client, "was prevented from starting a Kick vote on %s.  Reason: Spectator", targetName);
		PrintToChatAll("\x04[VOTE] \x01%t","votemanager27",initiatorName,targetName);
		//Notify(client, "\x04[VOTE] \x01%s tried to start a Kick Vote against %s but spectators are not allowed to kick.",initiatorName,targetName);
		return Plugin_Handled;
	}

	// If the "kickImmunity" flag is set, we have to check admin rights of the client and target
	if (GetConVarBool(kickImmunity))
	{

		new AdminId:clientAdminId = GetUserAdmin(client);
		new AdminId:targetAdminId = GetUserAdmin(target);
	
		// we only care about immunity if the target is admin
		if (isAdmin(targetAdminId)){

			// based on admin access, can client kick the target?
			if (!CanAdminTarget(clientAdminId, targetAdminId))
			{
				// client does not have permisison to kick target
				LogVote(client, "was prevented from starting a Kick vote on %s.  Reason: Target Immunity", targetName);
				PrintToChatAll("\x04[VOTE] \x01%t","votemanager28",initiatorName,targetName);
				//Notify(client, "\x04[VOTE] \x01%s tried to start a Kick Vote against %s but he has immunity.",initiatorName,targetName);
				return Plugin_Handled;
			}
		}
	}
	
	LogVote(client, "started a Kick vote on %s.",targetName);
	PrintToChatAll("\x04[VOTE] \x01%t","votemanager29",initiatorName,targetName);
	//Notify(client, "\x04[VOTE] \x01%s is starting a Kick Vote against %s.",initiatorName,targetName);
	return Plugin_Continue;
}


// this is for clarity only
public bool:isAdmin(AdminId:id){ return !(id==INVALID_ADMIN_ID); }


public Action:Veto_Handler(client, args)
{
	
	if (!voteInProgress || postVoteDelay) 
	{
		LogVote(client, "vetoed but there is no current vote.");
		if (client!=0)
		{
			PrintToChat(client, "\x04[VOTE] \x01%T","No votes",client); 
		}
		
		return Plugin_Handled;
	}
	
	// special case, if someone does `rcon veto` instead of just `veto` then the veto comes from the server
	// anyone with rcon access would have full access to veto?
	if (client==0){

		Veto();
	
		LogVote(client,"has vetoed a vote.");
		PrintToChatAll("\x04[VOTE] \x01%t","votemanager210");
		//Notify(0, "\x04[VOTE] \x01The Server has vetoed this vote.");
		return Plugin_Continue;
	
	}

	decl String:vetoerName[MAX_NAME_LENGTH];	
	GetClientName(client, vetoerName, sizeof(vetoerName));
	
	if (hasVoteAccess(client, "Veto"))
	{	
		Veto();
		
		LogVote(client,"has vetoed a vote.");
		PrintToChatAll("\x04[VOTE] \x01%t","votemanager211",vetoerName);
		//Notify(client, "\x04[VOTE] \x01%s has vetoed this vote.",vetoerName);
		return Plugin_Continue;
		
	}
	LogVote(client,"failed to veto vote. Reason: Access");
	PrintToChatAll("\x04[VOTE] \x01%t","votemanager212",vetoerName);
	//Notify(client, "\x04[VOTE] \x01%s tried to veto a vote but does not have access.",vetoerName);
	return Plugin_Handled;
}


public Veto(){
	new count=MaxClients;
	for(new i=1;i<=count;i++)
	{
		if (IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i))
		{
			FakeClientCommandEx(i,"Vote No");
		}
	}
}


public Action:PassVote_Handler(client, args)
{

	if (!voteInProgress || postVoteDelay) 
	{
		LogVote(client, "passed the vote but there is no current vote.");
		if (client!=0)
		{
			PrintToChat(client, "\x04[VOTE] \x01%T","No Votes",client); 
		}
		return Plugin_Handled;
	}
	
	// special case, if someone does `rcon passvote` instead of just `passvote` then the veto comes from the server
	// anyone with rcon access would have full access to veto?
	if (client==0){

		PassVote();
	
		LogVote(client,"has passed a vote.");
		PrintToChatAll("\x04[VOTE] \x01%t","votemanager213");
		//Notify(0, "\x04[VOTE] \x01The Server has passed this vote.");
		return Plugin_Continue;
	
	}

	decl String:passerName[MAX_NAME_LENGTH];	
	GetClientName(client, passerName, sizeof(passerName));
	
	if (hasVoteAccess(client, "PassVote"))
	{	
		PassVote();
		
		LogVote(client,"has passed a vote.");
		PrintToChatAll("\x04[VOTE] \x01%t","votemanager214",passerName);
		//Notify(client, "\x04[VOTE] \x01%s has passed this vote.",passerName);
		return Plugin_Continue;
		
	}
	LogVote(client,"failed to veto vote. Reason: Access");
	PrintToChatAll("\x04[VOTE] \x01%s %t","votemanager215",passerName);
	//Notify(client, "\x04[VOTE] \x01%s tried to pass a vote but does not have access.",passerName);
	return Plugin_Handled;
}


public PassVote(){
	new count=MaxClients;
	for(new i=1;i<=count;i++)
	{
		if (IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i))
		{
			FakeClientCommandEx(i,"Vote Yes");
		}
	}
}

public Action:CustomVote_Handler(client, args)
{
	// no checking needed here, everything will be checked in due time
	
	decl String:initiatorName[MAX_NAME_LENGTH];
	GetClientName(client, initiatorName, sizeof(initiatorName));
	
	// can't start a new vote while we're in one already
	if (!voteInProgress){

		new leng1=GetCmdArg(1, customVote, sizeof(customVote));
		
		if (leng1==0){
			PrintToConsole(client, "Usage: custom_vote \"<question to vote on>\" ");
			return Plugin_Handled;
		}
		
		// determine who can vote on this
		new i;
		customVotesMax=0;
		for(i=1;i<sizeof(hasVoted);i++)
		{
			hasVoted[i]=true;
			
			if (i<=MaxClients && IsClientConnected(i) && !IsFakeClient(i))
			{
				customVotesMax++;
				hasVoted[i]=false;
			}
		}
		
		customNoVotes=0;
		customYesVotes=0;

		LogVote(client,"attempting custom vote. Issue: %s ", customVote);
		
		FakeClientCommandEx(client, "callvote Custom"); 

	}
	else
	{
		LogVote(client, "tried to start a Custom vote but one is already in progress.");
		PrintToChatAll("\x04[VOTE] \x01%t","votemanager216",initiatorName);
		//Notify(client, "\x04[VOTE] \x01%s tried starting a Custom vote but one is already in progress.",initiatorName);
	}
	
	return Plugin_Handled;
}



public Action:Custom_Vote_Logic(client, args)
{

	decl String:initiatorName[MAX_NAME_LENGTH];
	GetClientName(client, initiatorName, sizeof(initiatorName));

	if (!customVoteInProgress)
	{
		new Handle:voteEvent = CreateEvent("vote_started");
		SetEventString(voteEvent,"issue","#L4D_TargetID_Player");
		SetEventString(voteEvent,"param1",customVote);
		SetEventInt(voteEvent,"team",-1);
		SetEventInt(voteEvent,"initiator",GetClientUserId(client));
		FireEvent(voteEvent);
		
		new Handle:voteChangeEvent = CreateEvent("vote_changed");
		SetEventInt(voteChangeEvent,"yesVotes",0);
		SetEventInt(voteChangeEvent,"noVotes",0);
		SetEventInt(voteChangeEvent,"potentialVotes",customVotesMax);
		FireEvent(voteChangeEvent);

		// just like the built in behavior, the initiator votes yes
		FakeClientCommandEx(client,"Vote Yes");
		
		LogVote(client, "started a Custom vote.");
		PrintToChatAll("\x04[VOTE] \x01%t","votemanager217",initiatorName);
		//Notify(client, "\x04[VOTE] \x01%s is starting a Custom vote.",initiatorName);
		
		CreateTimer(30.0, EndCustomVote, client);
		
		customVoteInProgress=true;
		
	}	
	
	return Plugin_Handled;
}



public Action:Vote_Handler(client, args)
{

	decl String:voterName[MAX_NAME_LENGTH];
	GetClientName(client, voterName, sizeof(voterName));
	

	decl String:vote[8];
	GetCmdArg(1,vote,sizeof(vote));
	
	//PrintToChatAll("\x04[VOTE] \x01%s voted %s.",voterName,vote);	

	// if it's a custom vote handle it specially
	if ( customVoteInProgress && !hasVoted[client] )
	{
		
		if (strcmp(vote,"Yes",true) == 0)
		{
			customYesVotes++;
		}
		else if (strcmp(vote,"No",true) == 0)
		{
			customNoVotes++;
		}
		
		hasVoted[client]=true;

		new Handle:voteChangeEvent = CreateEvent("vote_changed");
		SetEventInt(voteChangeEvent,"yesVotes",customYesVotes);
		SetEventInt(voteChangeEvent,"noVotes",customNoVotes);
		SetEventInt(voteChangeEvent,"potentialVotes",customVotesMax);
		FireEvent(voteChangeEvent);

		if ((customYesVotes+customNoVotes)==customVotesMax)
		{
			CreateTimer(2.0, EndCustomVote, client);
		}
	
		return Plugin_Handled;
		
	}

	// otherwise do normal behavior
	return Plugin_Continue;
}


// after a certain amount of time just end the vote regardless
public Action:EndCustomVote(Handle:timer, any:client){

	if (customVoteInProgress){

		new Handle:voteEndEvent = CreateEvent("vote_ended");
		FireEvent(voteEndEvent);
	
		if (customYesVotes > customNoVotes)
		{
			new String:param1[128];
			Format(param1, sizeof(param1), "Vote succeeds: %s", customVote);
		
			new Handle:votePassEvent = CreateEvent("vote_passed");
			SetEventString(votePassEvent,"details","#L4D_TargetID_Player");
			SetEventString(votePassEvent,"param1",param1);
			SetEventInt(votePassEvent,"team",-1);
			FireEvent(votePassEvent);
		
			LogVote(client, "Custom vote passed. Vote:%s ",customVote);
				
		}
		else
		{				
			new Handle:voteFailEvent = CreateEvent("vote_failed");
			SetEventInt(voteFailEvent,"team",0);
			FireEvent(voteFailEvent);
		
			LogVote(client, "Custom vote failed. Vote:%s ",customVote);
		}
	
	}
	customVoteInProgress=false;
}
