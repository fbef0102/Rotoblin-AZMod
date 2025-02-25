/*
* 1.2
	Harry Potter modify
* 1.1.2
*  - Update URL in plugin info.
*  - Cleaned up some more code.
* 1.1.1
*  - Cleaned up some code.
* 1.1
*  - Added admin command sm_givepills.
* 1.0.1
*  - Increased timer so plugin will work on 16 player servers.
* 1.0
*  - Initial release.
*/

#include <sourcemod>
#include <sdktools>
 
public Plugin:myinfo =
{
	name = "[L4D] Pills Here",
	author = "Crimson_Fox,modify by Harry",
	description = "Gives pills to survivors who doesn't have pill",
	version = "1.3",
	url = "http://steamcommunity.com/profiles/76561198026784913"
}

public OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("Roto2-AZ_mod.phrases");
	//RegAdminCmd("sm_give", Command_GivePills, ADMFLAG_BAN, "Give pills to survivors");
	//RegAdminCmd("sm_geiyao", Command_GivePills, ADMFLAG_BAN, "Give pills to survivors");
	RegAdminCmd("sm_geiyaoto", Command_GiveWhoPills, ADMFLAG_BAN, "Give a pill to the specificed survivor");
	RegAdminCmd("sm_giveto", Command_GiveWhoPills, ADMFLAG_BAN, "Give a pill to the specificed survivor");	
}


public Action:Command_GivePills(client, args)
{
	GivePillsAll();
}

public GivePillsAll()
{
	new flags = GetCommandFlags("give");	
	SetCommandFlags("give", flags & ~FCVAR_CHEAT);
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i)==2) 
		{
			new currentWeapon = GetPlayerWeaponSlot(i, 4);
			if (currentWeapon == -1)
			{
				FakeClientCommand(i, "give pain_pills");
			}
		}
	}
	SetCommandFlags("give", flags|FCVAR_CHEAT);
	//PrintToChatAll("如果系統沒有發藥，管理員可輸入!give or !giveto <player>");
}

public Action:Command_GiveWhoPills(client, args)
{
	if (client == 0)
	{
		PrintToServer("[TS] %t","command cannot be used by server.");
		return Plugin_Handled;
	}
	if(args < 1)
    {
		ReplyToCommand(client, "[TS] Usage: sm_giveto <player> - %T","l4d_PillsHere1",client);		
		return Plugin_Handled;
	}


	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	char arg[65];
	GetCmdArg(1, arg, sizeof(arg));
	if ((target_count = ProcessTargetString(
			arg,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_NO_BOTS,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}


	char tclientName[128];
	int tclient;
	for (int i = 0; i < target_count; i++)
	{
		tclient = target_list[i];
		GetClientName(tclient, tclientName,128);
	
	
		if(GetClientTeam(tclient)!=2)
		{
			ReplyToCommand(client, "[TS] Usage: %T","l4d_PillsHere2",client,tclientName);	
			continue;
		}
		
		new currentWeapon = GetPlayerWeaponSlot(tclient, 4);
		if (currentWeapon == -1)
		{
			GiveWhoPillsAll(tclient);
			ReplyToCommand(client, "[TS] Usage: %T","l4d_PillsHere3",client,tclientName);	
		}
		else
		{
			ReplyToCommand(client, "[TS] Usage: %T","l4d_PillsHere4",client,tclientName);	
			continue;
		}	
	}

	return Plugin_Continue;
}

public GiveWhoPillsAll(client)
{
	new flags = GetCommandFlags("give");	
	SetCommandFlags("give", flags & ~FCVAR_CHEAT);
	if (IsClientInGame(client) && GetClientTeam(client)==2) 
	{
		new currentWeapon = GetPlayerWeaponSlot(client, 4);
		if (currentWeapon == -1)
		{
			FakeClientCommand(client, "give pain_pills");
		}
	}
	SetCommandFlags("give", flags|FCVAR_CHEAT);
}
