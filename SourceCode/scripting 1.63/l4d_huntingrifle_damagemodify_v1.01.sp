#include <sourcemod>
//#include <sdktools>

#pragma semicolon 1

#define ZC_SMOKER               1
#define ZC_BOOMER               2
#define ZC_HUNTER               3
#define ZC_TANK                 5

public Plugin:myinfo = 
{
	name = "修改狙击打特感伤害",
	author = "",
	description = "修改L4D狙击打特感伤害",
	version = "1.1",
	url = ""
};

public OnPluginStart()
{
	HookEvent("player_hurt", Event_PlayerHurt);	
}



public Action:Event_PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast) 
{
	decl victim,
	attacker,	
	dehealth,
	eventhealth,	
	dmg;
	
	new zombieClass = 0;
	victim = GetClientOfUserId(GetEventInt(event, "userid"));
	attacker = GetClientOfUserId(GetEventInt(event, "attacker"));	
	dmg = GetEventInt(event, "dmg_health");
	eventhealth = GetEventInt(event, "health");	
	dehealth = eventhealth + dmg;
	
	zombieClass = GetEntProp(victim, Prop_Send, "m_zombieClass");
	
	//Kill everything if...
	if (attacker == 0 || victim == 0 || GetClientTeam(victim) != 3 ) {
		return Plugin_Continue;
	}
	if(zombieClass == 3)
	{
	decl String:weapon[16];
	GetEventString(event, "weapon", weapon, sizeof(weapon));	
	switch (GetEventInt(event, "hitgroup"))
	{
		case 1:
		{
		}
		case 2:
		{
			if (StrEqual(weapon, "hunting_rifle"))
	      {
	         dmg = RoundToNearest(dmg*2.8);
	      }	
		}
		case 3:
		{
			if (StrEqual(weapon, "hunting_rifle"))
	      {
	        dmg = RoundToNearest(dmg*1.8);
	      }				
		}
		case 4:
		{
		}
		case 5:
		{
		}
		case 6:
		{
		}
		case 7:
		{
		}
		default:
		{
		}
	}
	}	

	if(zombieClass == 5)
	{
	decl String:weapon[16];
	GetEventString(event, "weapon", weapon, sizeof(weapon));	
	switch (GetEventInt(event, "hitgroup"))
	{
		case 1:
		{
			if (StrEqual(weapon, "hunting_rifle"))
			{
				dmg = RoundToNearest(dmg*1.5);
			}	
		}
		case 2:
		{
			if (StrEqual(weapon, "hunting_rifle"))
			{
				dmg = RoundToNearest(dmg*1.5);
			}	
		}
		case 3:
		{
			if (StrEqual(weapon, "hunting_rifle"))
			{
				dmg = RoundToNearest(dmg*1.5);
			}	
		}
		case 4:
		{
		  if (StrEqual(weapon, "hunting_rifle"))
			{
				dmg = RoundToNearest(dmg*1.5);
			}	
		}
		case 5:
		{
			if (StrEqual(weapon, "hunting_rifle"))
			{
				dmg = RoundToNearest(dmg*1.5);
			}	
		}
		case 6:
		{
			if (StrEqual(weapon, "hunting_rifle"))
			{
				dmg = RoundToNearest(dmg*1.5);
			}	
		}
		case 7:
		{
		}
		default:
		{
		}
	}
	}	
	eventhealth = dehealth - dmg;
	if (eventhealth < 0)
		eventhealth = 0;
	SetEntProp(victim, Prop_Data, "m_iHealth", eventhealth);
	SetEventInt(event, "dmg_health", dmg);
	//}
	return Plugin_Changed;	
}	
	

