#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <multicolors>

new Handle:si_restore_ratio;
static bool:allow_gain_health[MAXPLAYERS + 1];

public Plugin:myinfo = 
{
    name = "Despawn Health",
    author = "Jacob",
    description = "Gives Special Infected health back when they despawn.",
    version = "1.3",
    url = "github.com/jacob404/myplugins"
}

public OnMapStart()
{
	LoadTranslations("Roto2-AZ_mod.phrases");
	for(new i = 1;i<=MaxClients;++i)
		allow_gain_health[i]=true;
}

public OnPluginStart()
{
    si_restore_ratio = CreateConVar("si_restore_ratio", "0.5", "How much of the clients missing HP should be restored? 1.0 = Full HP", FCVAR_NOTIFY, true, 0.0, true, 1.0);
}

public L4D_OnEnterGhostState(client)
{
	if(allow_gain_health[client]==false)
	{
		CPrintToChat(client,"{default}[{olive}TS{default}] %T","l4d_versus_despawn_health1",client);
		return;
	}
	new CurrentHealth = GetClientHealth(client);
	new MaxHealth = GetEntProp(client, Prop_Send, "m_iMaxHealth");
	if (CurrentHealth != MaxHealth)
    {
		new NewHP=0;
		new MissingHealth = MaxHealth - CurrentHealth;
		NewHP = RoundFloat(MissingHealth * GetConVarFloat(si_restore_ratio)) + CurrentHealth;
		CPrintToChat(client,"{default}[{olive}TS{default}] %T","l4d_versus_despawn_health2",client,NewHP-CurrentHealth);
		SetEntityHealth(client, NewHP);
		allow_gain_health[client]=false;
    }
	CreateTimer(20.0,COLD_DOWN,client);
}
public Action:COLD_DOWN(Handle:timer,any:client)
{
	allow_gain_health[client]=true;
}