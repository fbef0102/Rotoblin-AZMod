#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <multicolors>
#include <left4dhooks>

#define PLUGIN_VERSION "2.4"
int Tankclient;

public Plugin myinfo = 
{
	name = "l4d 豬隊友提示",
	author = "Harry Potter",
	description = "Show who the god teammate boom the Tank, Tank use which weapon(car,pounch,rock) to kill teammates S.I. and Witch , player open door to stun tank",
	version = PLUGIN_VERSION,
	url = "myself"
}

public void OnPluginStart()
{
	LoadTranslations("Roto2-AZ_mod.phrases");
	
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("door_open", Event_DoorOpen);
	HookEvent("door_close", Event_DoorClose);
}


public void Event_DoorOpen(Event event, const char[] name, bool dontBroadcast)
{
	Tankclient = GetTankClient();
	if(Tankclient == -1)	return;
	
	new Surplayer = GetClientOfUserId(GetEventInt(event, "userid"));
	if(Surplayer<=0 || !IsClientInGame(Surplayer) || GetClientTeam(Surplayer) != 2) return;


	if(IsTooClose(Surplayer, Tankclient))
	{
		CreateTimer(1.0, Timer_TankStumbleByDoorCheck, Surplayer);//tank stumble check
	}
}

public void Event_DoorClose(Event event, const char[] name, bool dontBroadcast)
{
	Tankclient = GetTankClient();
	if(Tankclient == -1)	return;
	
	new Surplayer = GetClientOfUserId(GetEventInt(event, "userid"));
	if(Surplayer<=0 || !IsClientInGame(Surplayer) || GetClientTeam(Surplayer) != 2) return;
	
	if(IsTooClose(Surplayer, Tankclient))
	{
		CreateTimer(1.0, Timer_TankStumbleByDoorCheck, Surplayer);//tank stumble check
	}
}

public Action Timer_TankStumbleByDoorCheck(Handle timer, any client)
{
	if(Tankclient<0 || !IsClientInGame(Tankclient)) return Plugin_Continue;
	if(client<0 || !IsClientInGame(client)) return Plugin_Continue;
	
	if (L4D_IsPlayerStaggering(Tankclient))//tank在暈眩 by door
	{
		static char clientName[128];
		GetClientName(client,clientName,128);
		CPrintToChatAll("{green}[TS] %t","l4d_pig_infected1",clientName);
	}
	
	return Plugin_Continue;
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	Tankclient = GetTankClient();
	
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	if( IsWitch(GetEventInt(event, "attackerentid")) && victim != 0 && IsClientInGame(victim) && GetClientTeam(victim) == 3 )
	{
		if(!IsFakeClient(victim))//真人特感 player
		{
			for (new i = 1; i <= MaxClients; i++)
				if (IsClientInGame(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || GetClientTeam(i) == 3))
					CPrintToChat(i,"{green}[TS]{default} %T","l4d_pig_infected2",i);
		}
		else
		{
			for (new i = 1; i <= MaxClients; i++)
				if (IsClientInGame(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || GetClientTeam(i) == 3))
					CPrintToChat(i,"{green}[TS]{default} %T","l4d_pig_infected3",i);
		}
		return;
	}
	
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	static char weapon[32];
	GetEventString(event, "weapon", weapon, sizeof(weapon));//殺死人的武器名稱
	static char victimname[8];
	GetEventString(event, "victimname", victimname, sizeof(victimname));
	//PrintToChatAll("attacker: %d - victim: %d - weapon:%s - victimname:%s",attacker,victim,weapon,victimname);
	if((attacker == 0 || attacker == victim)
	&& victim != 0 && IsClientInGame(victim) && GetClientTeam(victim) == 3)//特感自殺
	{
		static char kill_weapon[50];

		if(StrEqual(weapon,"entityflame")||StrEqual(weapon,"env_fire"))//地圖的自然火
			Format(kill_weapon, sizeof(kill_weapon), "%s","killed by fire");
		else if(StrEqual(weapon,"trigger_hurt"))//跳樓 跳海 地圖火 都有可能
			Format(kill_weapon, sizeof(kill_weapon), "%s","killed by map");
		else if(StrEqual(weapon,"inferno"))//玩家丟的火
			return;
		else if(StrEqual(weapon,"trigger_hurt_g"))//跳樓 跳海 地圖火 都有可能
			Format(kill_weapon, sizeof(kill_weapon), "%s","killed himself");
		else if(StrEqual(weapon,"prop_physics")||StrEqual(weapon, "prop_car_alarm"))//玩車殺死自己
			Format(kill_weapon, sizeof(kill_weapon), "%s","killed by toy");
		else if(StrEqual(weapon,"pipe_bomb")||StrEqual(weapon,"prop_fuel_barr"))//自然的爆炸(土製炸彈 砲彈 瓦斯罐)
			Format(kill_weapon, sizeof(kill_weapon), "%s","killed by boom");
		else if(StrEqual(weapon,"world"))//玩家使用指令kill 殺死特感
			return;
		else 
			Format(kill_weapon, sizeof(kill_weapon), "%s","killed by server");	//卡住了 由伺服器自動處死特感
			
		if(GetEntProp(victim, Prop_Send, "m_zombieClass") == 5)//Tank suicide
		{
			for (new i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || GetClientTeam(i) == 3))
				{
					SetGlobalTransTarget(i);
					CPrintToChat(i,"{green}[TS] %t","Tank is killed by something",kill_weapon);
				}
			}
		}
		else if(GetEntProp(victim, Prop_Send, "m_zombieClass") == 2)
		{
			CreateTimer(0.1, Timer_BoomerSuicideCheck, victim);//boomer suicide check	
		}
		else
		{

			static char victimName[128];
			GetClientName(victim,victimName,128);			
			for (new i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || GetClientTeam(i) == 3))
				{
					SetGlobalTransTarget(i);
					CPrintToChat(i,"{green}[TS] %t","Player is killed by something",victimName,kill_weapon);
				}	
			}
		}
		return;
	}
	else if (attacker==0 && victim == 0 && StrEqual(victimname,"Witch"))//Witch自己不知怎的自殺了
	{
		for (new i = 1; i <= MaxClients; i++)
			if (IsClientInGame(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || GetClientTeam(i) == 3))
				CPrintToChat(i,"{green}[TS] %T","l4d_pig_infected4",i);
	}
	
	if( StrEqual(victimname,"Witch") && PlayerIsTank(attacker) )
	{
		static char Tank_weapon[50];
		if(StrEqual(weapon,"tank_claw"))
			Format(Tank_weapon, sizeof(Tank_weapon), "One-Punch");
		else if(StrEqual(weapon,"tank_rock"))
			Format(Tank_weapon, sizeof(Tank_weapon), "Rock-Stone");
		else if(StrEqual(weapon,"prop_physics"))
			Format(Tank_weapon, sizeof(Tank_weapon), "Toy");
		else if(StrEqual(weapon,"prop_car_alarm"))
			Format(Tank_weapon, sizeof(Tank_weapon), "Alarm-Car");
			
		for (new i = 1; i <= MaxClients; i++)
			if (IsClientInGame(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || GetClientTeam(i) == 3))
			{
				SetGlobalTransTarget(i);
				CPrintToChat(i,"{green}[TS] %t","Tank Kill Witch",Tank_weapon);
			}

		return;
	}
	
	if ( victim == 0 || !IsClientInGame(victim)) return;
	new victimteam = GetClientTeam(victim);
	new victimzombieclass = GetEntProp(victim, Prop_Send, "m_zombieClass");
		
	if (victimteam == 3)//infected dead
	{	
		if(attacker != 0 && IsClientInGame(attacker))//someone kill infected
		{
			new attackerteam = GetClientTeam(attacker);
			if(attackerteam == 2 && victimzombieclass == 2)//sur kill Boomer
			{
				if(Tankclient > 0 && IsTooClose(victim, Tankclient))
				{
					Handle h_Pack;
					CreateDataTimer(0.1, Timer_SurKillBoomerCheck, h_Pack);//sur kill Boomer check	
					WritePackCell(h_Pack, victim);
					WritePackCell(h_Pack, attacker);
				}
			}
			else if (PlayerIsTank(attacker))//Tank kill infected
			{
				static char Tank_weapon[50];
				//Tank weapon
				if(StrEqual(weapon,"tank_claw"))
					Format(Tank_weapon, sizeof(Tank_weapon), "punches");
				else if(StrEqual(weapon,"tank_rock"))
					Format(Tank_weapon, sizeof(Tank_weapon), "smashes");
				else if(StrEqual(weapon,"prop_physics"))
					Format(Tank_weapon, sizeof(Tank_weapon), "plays toy to kill");
				else if(StrEqual(weapon, "prop_car_alarm"))
					Format(Tank_weapon, sizeof(Tank_weapon), "plays alarm car to kill");
					
				//Tank kill boomer
				if(victimzombieclass == 2)
				{
					Handle h_Pack;
					CreateDataTimer(0.1,Timer_TankKillBoomerCheck,h_Pack);//tank kill Boomer check
					WritePackCell(h_Pack, victim);
					WritePackString(h_Pack, Tank_weapon);
				}
				else if(victimzombieclass == 1||victimzombieclass == 3)//Tank kill teammates S.I. (Hunter,Smoker)	
				{
					if(!IsFakeClient(victim))//真人SI player
					{	for (new i = 1; i <= MaxClients; i++)
							if (IsClientInGame(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || GetClientTeam(i) == 3))
							{
								SetGlobalTransTarget(i);
								CPrintToChat(i,"{green}[TS] %t","Tank kill teammate",Tank_weapon,"");
							}
					}
					else
					{
						for (new i = 1; i <= MaxClients; i++)
							if (IsClientInGame(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || GetClientTeam(i) == 3))
							{
								SetGlobalTransTarget(i);
								CPrintToChat(i,"{green}[TS] %t","Tank kill teammate",Tank_weapon,"AI");
							}
					}
				}
			}
		}
	}
}
public Action Timer_SurKillBoomerCheck(Handle timer, Handle h_Pack)
{
	if(Tankclient<0 || !IsClientInGame(Tankclient)) return Plugin_Continue;
	
	ResetPack(h_Pack);
	int client = ReadPackCell(h_Pack);
	int surclient = ReadPackCell(h_Pack);
	
	if(client<0 || !IsClientInGame(client)) return Plugin_Continue;
	if(surclient<0 || !IsClientInGame(surclient)) return Plugin_Continue;
	
	if(L4D_IsPlayerStaggering(Tankclient))//tank在暈眩 by 人類殺死的Boomer
	{
		static char clientName[128];
		GetClientName(client,clientName,128);
		static char surclientName[128];
		GetClientName(surclient,surclientName,128);
		if(!IsFakeClient(client))//真人boomer player
			CPrintToChatAll("{green}[TS] %t","l4d_pig_infected5",surclientName, clientName);
		else
			CPrintToChatAll("{green}[TS] %t","l4d_pig_infected6",surclientName, clientName);
	}
	
	return Plugin_Continue;
}

public Action Timer_TankKillBoomerCheck(Handle timer, Handle h_Pack)
{
	if(Tankclient<0 || !IsClientInGame(Tankclient)) return Plugin_Continue;
	
	static char Tank_weapon[128];
	
	ResetPack(h_Pack);
	int client = ReadPackCell(h_Pack);
	ReadPackString(h_Pack, Tank_weapon, sizeof(Tank_weapon));
	
	if(client<0 || !IsClientInGame(client)) return Plugin_Continue;

	static char clientName[128];
	GetClientName(client,clientName,128);
	if(L4D_IsPlayerStaggering(Tankclient) && IsTooClose(client, Tankclient))//tank在暈眩 by tank殺死的Boomer
	{
		if(!IsFakeClient(client))//真人SI player
		{	
			for (new i = 1; i <= MaxClients; i++)
				if (IsClientInGame(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || GetClientTeam(i) == 3))
				{
					SetGlobalTransTarget(i);
					CPrintToChat(i,"{green}[TS] %t","l4d_pig_infected7",Tank_weapon,clientName);
				}
		}
		else	
		{
			for (new i = 1; i <= MaxClients; i++)
				if (IsClientInGame(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || GetClientTeam(i) == 3))
				{
					SetGlobalTransTarget(i);
					CPrintToChat(i,"{green}[TS] %t","l4d_pig_infected8",Tank_weapon);
				}
		}
	}
	else
	{
		if(!IsFakeClient(client))//真人SI player
		{
			for (new i = 1; i <= MaxClients; i++)
				if (IsClientInGame(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || GetClientTeam(i) == 3))
				{
					SetGlobalTransTarget(i);
					CPrintToChat(i,"{green}[TS] %t","l4d_pig_infected9",Tank_weapon,clientName);
				}
		}
		else
		{
			for (new i = 1; i <= MaxClients; i++)
				if (IsClientInGame(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || GetClientTeam(i) == 3))
				{
					SetGlobalTransTarget(i);
					CPrintToChat(i,"{green}[TS] %t","l4d_pig_infected10",Tank_weapon);
				}
		}
	}
	
	return Plugin_Continue;
}


public Action Timer_BoomerSuicideCheck(Handle timer, any client)
{	
	if(client<0 || !IsClientInGame(client)) return Plugin_Continue;
	
	static char clientName[128];
	GetClientName(client,clientName,128);
	Tankclient = GetTankClient();
	if(Tankclient<0 || !IsClientInGame(Tankclient))
	{
		if(!IsFakeClient(client))//真人boomer player
		{	for (new i = 1; i <= MaxClients; i++)
				if (IsClientInGame(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || GetClientTeam(i) == 3))
					CPrintToChat(i,"{green}[TS] %T","l4d_pig_infected11",i,clientName);
		}
		else
		{
			for (new i = 1; i <= MaxClients; i++)
				if (IsClientInGame(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || GetClientTeam(i) == 3))
					CPrintToChat(i,"{green}[TS] %T","l4d_pig_infected12",i);
		}
		return Plugin_Continue;
	}
	
	if (L4D_IsPlayerStaggering(Tankclient) && IsTooClose(client, Tankclient))//tank在暈眩 by 自殺的boomer
	{
		if(!IsFakeClient(client))//真人boomer player
		{	for (new i = 1; i <= MaxClients; i++)
				if (IsClientInGame(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || GetClientTeam(i) == 3))
					CPrintToChat(i,"{green}[TS] %T","l4d_pig_infected13",i,clientName);
		}
		else
		{
			for (new i = 1; i <= MaxClients; i++)
				if (IsClientInGame(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || GetClientTeam(i) == 3))
					CPrintToChat(i,"{green}[TS] %T","l4d_pig_infected14",i);
		}
	}
	else
	{
		if(!IsFakeClient(client))//真人boomer player
		{	for (new i = 1; i <= MaxClients; i++)
				if (IsClientInGame(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || GetClientTeam(i) == 3))
					CPrintToChat(i,"{green}[TS] %T","l4d_pig_infected11",i,clientName);
		}
		else
		{
			for (new i = 1; i <= MaxClients; i++)
				if (IsClientInGame(i) && !IsFakeClient(i) && (GetClientTeam(i) == 1 || GetClientTeam(i) == 3))
					CPrintToChat(i,"{green}[TS] %T","l4d_pig_infected12",i);
		}
	}
	
	return Plugin_Continue;
}

int GetTankClient()
{
	for (new client = 1; client <= MaxClients; client++)
		if(	PlayerIsTank(client) )//Tank player
			return  client;
	return -1;
}

bool PlayerIsTank(int client)
{
	if(client != 0 && IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == 5) 
		return true;
	return false;
}

bool IsTooClose(int client, int tank)
{
	float fClientLocation[3], fTankLocation[3];
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", fClientLocation);
	GetEntPropVector(tank, Prop_Send, "m_vecOrigin", fTankLocation);

	if(GetVectorDistance(fClientLocation, fTankLocation, true) <= 400*400)
	{
		return true;
	}

	return false;
}

bool IsWitch(int entity)
{
    if (entity > 0 && IsValidEntity(entity) && IsValidEdict(entity))
    {
        static char strClassName[64];
        GetEdictClassname(entity, strClassName, sizeof(strClassName));
        return strcmp(strClassName, "witch", false) == 0;
    }
    return false;
}