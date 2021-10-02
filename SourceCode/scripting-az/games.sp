#include <sourcemod>
#include <sdktools>
#include <multicolors>
#include <l4d_lib>


#define PLUGIN_VERSION "1.2"
#define DEBUG 0
#define L4D_TEAM_SURVIVORS 2
#define L4D_TEAM_INFECTED 3
#define L4D_TEAM_SPECTATE 1

static bool:GameCodeLock;
static GameCode;
static GameCodeClient;
static OriginalTeam[MAXPLAYERS+1];

native Is_Ready_Plugin_On();
native IsInReady();
#define MIX_DELAY 5.0

new result_int;
new String:client_name[32]; // Used to store the client_name of the player who calls coinflip
new previous_timeC = 0; // Used for coinflip
new current_timeC = 0; // Used for coinflip
new previous_timeN = 0; // Used for picknumber
new current_timeN = 0; // Used for picknumber
new Handle:delay_time; // Handle for the coinflip_delay cvar
new number_max = 6; // Default maximum bound for picknumber
public Plugin:myinfo = 
{
	name = "L4D1 Game",
	author = "Harry Potter",
	description = "Let's play a game, Duel 決鬥!!",
	version = PLUGIN_VERSION,
	url = "myself"
}

public OnPluginStart()
{
	LoadTranslations("Roto2-AZ_mod.phrases");
	delay_time = CreateConVar("coinflip_delay","1", "Time delay in seconds between allowed coinflips. Set at -1 if no delay at all is desired.");
	
	RegConsoleCmd("say", Game_Say);
	RegConsoleCmd("say_team", Game_Say);

	RegConsoleCmd("sm_roll", Game_Roll);
	RegConsoleCmd("sm_picknumber", Game_Roll);
	RegConsoleCmd("sm_code", Game_Code);
	RegConsoleCmd("sm_random", Game_RandomTeam);
	HookEvent("round_start", Event_Round_Start);
	RegConsoleCmd("sm_coinflip", Command_Coinflip);
	RegConsoleCmd("sm_coin", Command_Coinflip);
	RegConsoleCmd("sm_cf", Command_Coinflip);
	RegConsoleCmd("sm_flip", Command_Coinflip);
}

public OnMapStart()
{
	GameCodeLock = false;
}

public Event_Round_Start(Handle:event, String:name[], bool:dontBroadcast)
{
	for (new i = 1; i <= MaxClients; i++)
	{
		OriginalTeam[i] = 0;
	}
}

public OnClientPutInServer(client)
{
	OriginalTeam[client] = 0;	
}
public Action:Command_Coinflip(client, args)
{
	current_timeC = GetTime();
	
	if((current_timeC - previous_timeC) > GetConVarInt(delay_time)) // Only perform a coinflip if enough time has passed since the last one. This prevents spamming.
	{
		result_int = GetURandomInt() % 2; // Gets a random integer and checks to see whether it's odd or even
		GetClientName(client, client_name, sizeof(client_name));
		
		if(result_int == 0){
			CPrintToChatAll("[{green}Dual!{default}] %t","game1",client_name);
		}
		else{
			CPrintToChatAll("[{green}Dual!{default}] %t","game2",client_name);
		}
		
		previous_timeC = current_timeC; // Update the previous time
	}
	else
	{
		ReplyToCommand(client, "[Dual!] %T","game12",client, GetConVarInt(delay_time));
	}
	
	return Plugin_Handled;
}

public Action:Game_RandomTeam(client, args)
{
	if (client == 0)
	{
		PrintToServer("[TS] %t","command cannot be used by server.");
		return Plugin_Handled;
	}
	if(GetClientTeam(client) != 1)
	{
		ReplyToCommand(client, "[TS] %T","You must spec first",client);	
		return Plugin_Handled;
	}
	new SSlots = GetTeamMaxHumans(2);
	new SUsedSlots = GetTeamHumanCount(2);
	new SfreeSlots = (SSlots - SUsedSlots);
	new ISlots = GetTeamMaxHumans(3);
	new IUsedSlots = GetTeamHumanCount(3);
	new IfreeSlots = (ISlots - IUsedSlots);
	if (SfreeSlots <= 0 && IfreeSlots <= 0)
	{
		CPrintToChat(client, "[{olive}TS{default}] %T","All teams are full.",client);
		return Plugin_Handled;
	}
	else if (SfreeSlots <= 0)
	{
		CPrintToChat(client,"[{olive}TS{default}] %T","game3",client);
		return Plugin_Handled;
	}
	else if (IfreeSlots <= 0)
	{
		new bot;
		
		for(bot = 1; 
			bot < (MaxClients + 1) && (!IsClientConnected(bot) || !IsFakeClient(bot) || (GetClientTeam(bot) != 2));
			bot++) {}
		
		if(bot == (MaxClients + 1))
		{			
			new String:command[] = "sb_add";
			new flags = GetCommandFlags(command);
			SetCommandFlags(command, flags & ~FCVAR_CHEAT);
			
			ServerCommand("sb_add");
			
			SetCommandFlags(command, flags);
		}
		CreateTimer(0.1, Survivor_Take_Control, client, TIMER_FLAG_NO_MAPCHANGE);
		CPrintToChat(client,"[{olive}TS{default}] %T","game3",client);
		return Plugin_Handled;
	}
	
	new newteam = GetRandomInt(2, 3);
	if(newteam == 2)
	{
		new bot;
		
		for(bot = 1; 
			bot < (MaxClients + 1) && (!IsClientConnected(bot) || !IsFakeClient(bot) || (GetClientTeam(bot) != 2));
			bot++) {}
		
		if(bot == (MaxClients + 1))
		{			
			new String:command[] = "sb_add";
			new flags = GetCommandFlags(command);
			SetCommandFlags(command, flags & ~FCVAR_CHEAT);
			
			ServerCommand("sb_add");
			
			SetCommandFlags(command, flags);
		}
		CreateTimer(0.1, Survivor_Take_Control, client, TIMER_FLAG_NO_MAPCHANGE);
		CPrintToChat(client,"[{olive}TS{default}] %T","game3",client);
		return Plugin_Handled;
	}
	else
	{
		ChangeClientTeam(client, 3);
		CPrintToChat(client,"[{olive}TS{default}] %T","game3",client);
		return Plugin_Handled;
	}
}

public Action:Game_Say(client, args)
{
	if (client == 0)
	{
		return Plugin_Continue;
	}
	if(args < 1 || !GameCodeLock)
	{
		return Plugin_Continue;
	}
	
	new String:arg1[64];
	GetCmdArg(1, arg1, 64);
	if(IsInteger(arg1))
	{
		new result = StringToInt(arg1);
		decl String:clientName[128];
		GetClientName(client,clientName,128);
		decl String:GameCodeClientName[128];
		GetClientName(GameCodeClient,GameCodeClientName,128);
		if(result == GameCode){
			CPrintToChatAll("[{green}Dual!{default}] %t","game4",clientName,GameCodeClientName,result);
			GameCodeLock = false;
		}
		else if(result < GameCode){
			CPrintToChatAll("[{green}Dual!{default}] %t","game5",clientName,result);
		}
		else if(result > GameCode)
		{
			CPrintToChatAll("[{green}Dual!{default}] %t","game6",clientName,result);
		}
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action:Game_Code(client, args)
{
	if (client == 0)
	{
		PrintToServer("[Dual!] %t","command cannot be used by server.");
		return Plugin_Handled;
	}
	if(GameCodeLock)
	{
		ReplyToCommand(client, "[Dual!] %T","game7",client);		
		return Plugin_Handled;
	}
	if(args < 1)
	{
		ReplyToCommand(client, "[Dual!] Usage: sm_code <0-100000> - %T","game8",client);		
		return Plugin_Handled;
	}
	if(args > 1)
	{
		ReplyToCommand(client, "[Dual!] Usage: sm_code <0-100000> - %T","game8",client);	
		return Plugin_Handled;
	}
	
	new String:arg1[64];
	GetCmdArg(1, arg1, 64);
	if(IsInteger(arg1))
	{
		GameCode = StringToInt(arg1);
		decl String:clientName[128];
		GetClientName(client,clientName,128);
		if(GameCode > 100000|| GameCode < 0)
		{
			ReplyToCommand(client, "[Dual!] Usage: sm_code <0-100000> - %T","game8",client);
			return Plugin_Handled;
		}
		
		GameCodeClient = client;
		CPrintToChat(client,"[{green}Dual!{default}] %T","game9",client,GameCode);
		CPrintToChatAll("[{green}Dual!{default}] %t","game10",clientName);
		GameCodeLock = true;
		return Plugin_Handled;
	}
	else
	{
		ReplyToCommand(client, "[Dual!] Usage: sm_code <0-100000> - %T","game8",client);
		return Plugin_Handled;
	}
}

public Action:Game_Roll(client, args)
{
	if (client == 0)
	{
		PrintToServer("[Dual!] %t","command cannot be used by server.");
		return Plugin_Handled;
	}
	if(args < 1)
	{
		current_timeN = GetTime();
		if((current_timeN - previous_timeN) > GetConVarInt(delay_time)) // Only perform a numberpick if enough time has passed since the last one.
		{
			current_timeN = GetTime();
			new result = GetRandomInt(1, number_max);
			decl String:clientName[128];
			GetClientName(client,clientName,128);
			CPrintToChatAll("[{green}Dual!{default}] %t","game11",clientName,number_max,result);
			previous_timeN = current_timeN; // Update the previous time
		}
		else
		{
			ReplyToCommand(client, "[Dual!] %T","game12",client, GetConVarInt(delay_time));
		}	
		return Plugin_Handled;
	}
	if(args > 1)
	{
		ReplyToCommand(client, "[Dual!] Usage: sm_roll/sm_picknumber <Integer> - %T","game13",client);		
		return Plugin_Handled;
	}
	
	new String:arg1[64];
	GetCmdArg(1, arg1, 64);
	if(IsInteger(arg1))
	{
		current_timeN = GetTime();
		
		if((current_timeN - previous_timeN) > GetConVarInt(delay_time)) // Only perform a numberpick if enough time has passed since the last one.
		{
			new side = StringToInt(arg1);
			if(side <= 0)
			{
				ReplyToCommand(client, "[Dual!] Usage: sm_roll/sm_picknumber <Integer> - %T","game13",client);
				return Plugin_Handled;
			}
			
			new result = GetRandomInt(1, side);
			decl String:clientName[128];
			GetClientName(client,clientName,128);
			CPrintToChatAll("[{green}Dual!{default}] %t","game11",clientName,side,result);
			previous_timeN = current_timeN; // Update the previous time
		}
		else
		{
			ReplyToCommand(client, "[Dual!] %T","game12",client, GetConVarInt(delay_time));
		}
		return Plugin_Handled;
	}
	else
	{
		ReplyToCommand(client, "[Dual!] Usage: sm_roll/sm_picknumber <Integer> - %T","game13",client);
		return Plugin_Handled;
	}
}

public bool:IsInteger(String:buffer[])
{
    new len = strlen(buffer);
    for (new i = 0; i < len; i++)
    {
        if ( !IsCharNumeric(buffer[i]) )
            return false;
    }

    return true;    
}

stock GetTeamMaxHumans(team)
{
	if(team == 2)
	{
		return GetConVarInt(FindConVar("survivor_limit"));
	}
	else if(team == 3)
	{
		return GetConVarInt(FindConVar("z_max_player_zombies"));
	}
	
	return -1;
}

stock GetTeamHumanCount(team)
{
	new humans = 0;
	
	new i;
	for(i = 1; i < (MaxClients + 1); i++)
	{
		if(IsClientInGameHuman(i) && GetClientTeam(i) == team)
		{
			humans++;
		}
	}
	
	return humans;
}
bool:IsClientInGameHuman(client)
{
	return IsClientInGame(client) && !IsFakeClient(client) && ((GetClientTeam(client) == L4D_TEAM_SURVIVORS || GetClientTeam(client) == L4D_TEAM_INFECTED));
}

public Action:Survivor_Take_Control(Handle:timer, any:client)
{
		new localClientTeam = GetClientTeam(client);
		new String:command[] = "sb_takecontrol";
		new flags = GetCommandFlags(command);
		SetCommandFlags(command, flags & ~FCVAR_CHEAT);
		new String:botNames[][] = { "teengirl", "manager", "namvet", "biker" };
		
		new i = 0;
		while((localClientTeam != 2) && i < 4)
		{
			FakeClientCommand(client, "sb_takecontrol %s", botNames[i]);
			localClientTeam = GetClientTeam(client);
			i++;
		}
		SetCommandFlags(command, flags);
}