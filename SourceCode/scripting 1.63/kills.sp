#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <colors>
#undef REQUIRE_PLUGIN

#define L4D_TEAM_INFECTED 3
#define L4D_TEAM_SURVIVOR 2
#define L4D_TEAM_SPECTATOR 1
new killif[MAXPLAYERS+1];
new killifs[MAXPLAYERS+1];
new damageff[MAXPLAYERS+1];
new iheadshot[MAXPLAYERS+1];
new sheadshot[MAXPLAYERS+1];
new PouncesEaten[MAXPLAYERS+1];
new Boomed[MAXPLAYERS+1];
new Smoked[MAXPLAYERS+1];

new bool:HasRoundEnded= false;
static bool:HasRoundEndedPrinted;

#define ZC_SMOKER               1
#define ZC_BOOMER               2
#define ZC_HUNTER               3
native IsInReady();
public Plugin:myinfo = 
{
	name = "杀特殊感染者统计",
	author = "fenghf,l4d1 modify by Harry Potter",
	description = "杀特殊感染者统计",
	version = "1.2",
	url = "www.google.com"
}
public OnPluginStart()   
{   
	LoadTranslations("Roto2-AZ_mod.phrases");
	RegConsoleCmd("kills", Command_kill);
	
	HookEvent("player_death", event_kill_infected);
	HookEvent("infected_death", event_kill_infecteds);
	HookEvent("round_end", event_RoundEnd);
	HookEvent("round_start", event_RoundStart);
	HookEvent("player_hurt", event_PlayerHurt);
	HookEvent("lunge_pounce", Event_LungePounce);//撲到人
	HookEvent("tongue_grab", Event_TongueGrab);//拉到人
	HookEvent("player_now_it", Event_PlayerBoomed);//噴到人
	
	//IF = FindSendPropInfo("CTerrorPlayer", "m_zombieClass");
}
public OnMapStart() 
{ 
	HasRoundEndedPrinted = false;
	HasRoundEnded = false;  
	kill_infected();
}

public Action:Event_Maptransition(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!HasRoundEnded)
	{
		displaykillinfected(0);
		return;
	}	
}

public event_PlayerHurt(Handle:event, String:name[], bool:dontBroadcast)
{
	new victimId = GetEventInt(event, "userid");
	new victim = GetClientOfUserId(victimId);
	new attackerId = GetEventInt(event, "attacker");
	new attackersid = GetClientOfUserId(attackerId);
	new damageDone = GetEventInt(event, "dmg_health");
	
	if (attackerId && victimId && IsClientInGame(attackersid) && GetClientTeam(attackersid) == L4D_TEAM_SURVIVOR && GetClientTeam(victim) == L4D_TEAM_SURVIVOR)
    {
       	if(IsInReady())
			return;
        damageff[attackersid] += damageDone;
    }
    
}



public Action:event_kill_infecteds(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new killer = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	if (!killer)
        return;

	if(GetClientTeam(killer) == L4D_TEAM_SURVIVOR)
	{
	  new bool:headshot=GetEventBool(event, "headshot");
	  if(headshot)
	  {
	       iheadshot[killer] += 1;
	  }
	  killifs[killer] += 1;
	}
}



public Action:event_kill_infected(Handle:event, const String:name[], bool:dontBroadcast)
{
	new zombieClass = 0;
	new killer = GetClientOfUserId(GetEventInt(event, "attacker"));
	new deadbody = GetClientOfUserId(GetEventInt(event, "userid"));
	if (0 < killer <= MaxClients && deadbody != 0)
	{
		if(GetClientTeam(deadbody) == L4D_TEAM_SURVIVOR) return;
		
		if(GetClientTeam(killer) == L4D_TEAM_SURVIVOR)
		{
			zombieClass = GetEntProp(deadbody, Prop_Send, "m_zombieClass");
			if(zombieClass == 1 ||zombieClass == 2||zombieClass == 3)
			{
				new bool:headshot=GetEventBool(event, "headshot");
				if(headshot)
				{
					sheadshot[killer] += 1;
				}	
				killif[killer] += 1;
				
			}
		}
	}
}

public event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(!HasRoundEndedPrinted)
	{
		CreateTimer(1.5, KillPinfected_dis);
		HasRoundEndedPrinted = true;
	}
}
public Action:KillPinfected_dis(Handle:timer)
{
	displaykillinfected(2);
	displaykillinfected(1);
}

public event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	HasRoundEndedPrinted = false;
	kill_infected();
}

public Action:Command_kill(client, args)
{
	new iTeam = GetClientTeam(client);
	displaykillinfected(iTeam);
}

displaykillinfected(team)
{	
	HasRoundEnded = true;
	new client;
	new players = -1;
	new players_clients[5];
	decl killss, killsss, killssss,damageffss,killssssss;
	for (client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client) || GetClientTeam(client) != L4D_TEAM_SURVIVOR) continue;
		players++;
		if(players>4) //有6位以上玩家在人類隊伍
			return;
		players_clients[players] = client;
		killss = killif[client];
		killsss = killifs[client];
		killssss = iheadshot[client];
		killssssss = sheadshot[client];
		damageffss = damageff[client];
	}
	SortCustom1D(players_clients, 5, SortByDamageDesc);
	decl String:clientName[128];
	for (new i; i <= players; i++)
	{
		client = players_clients[i];
		killss = killif[client];
		killsss = killifs[client];
		killssss = iheadshot[client];
		killssssss = sheadshot[client];
		damageffss = damageff[client];
		GetClientName(client,clientName,128);
		
		if(team == 0){
			CPrintToChatAll("%t","kills1", killss, killssssss, killsss, killssss, damageffss,clientName);
			//CPrintToChatAll("%t","kills2",PouncesEaten[client]+Smoked[client]+Boomed[client],PouncesEaten[client],Smoked[client],Boomed[client],clientName);
		}
		else
		{
			for (new j = 1; j <= MaxClients; j++)
			{
				if (IsClientConnected(j) && IsClientInGame(j)&& !IsFakeClient(j) && GetClientTeam(j) == team)
				{
				CPrintToChat(j,"%T","kills1",j, killss, killssssss, killsss, killssss, damageffss,clientName);
				//CPrintToChat(j,"%T","kills2",j,PouncesEaten[client]+Smoked[client]+Boomed[client],PouncesEaten[client],Smoked[client],Boomed[client],clientName);
		
				}
			}
		}
	}
}	
	

public SortByDamageDesc(elem1, elem2, const array[], Handle:hndl)
{
	if (killif[elem1] > killif[elem2]) return -1;
	else if (killif[elem2] > killif[elem1]) return 1;
	else if (elem1 > elem2) return -1;
	else if (elem2 > elem1) return 1;
	return 0;
}


kill_infected()
{
	for (new i = 1; i <= MaxClients; i++)
	{ 
		 killif[i] = 0; 
		 killifs[i] = 0; 
		 iheadshot[i] = 0;
		 sheadshot[i] = 0;
		 damageff[i] = 0;
		 PouncesEaten[i] = 0;
		 Boomed[i] = 0;
		 Smoked[i] = 0;
	}
}

public Event_LungePounce(Handle:event, const String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "victim"));
	PouncesEaten[victim] +=1;
}

public Event_TongueGrab(Handle:event, const String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "victim"));
	Smoked[victim] +=1;
}

public Event_PlayerBoomed(Handle:event, const String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	Boomed[victim] +=1;
}