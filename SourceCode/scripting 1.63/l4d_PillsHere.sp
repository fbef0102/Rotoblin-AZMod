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
	version = "1.2",
	url = "http://forums.alliedmods.net/showthread.php?p=915033"
}

public OnPluginStart()
{
	LoadTranslations("common.phrases");
	RegAdminCmd("sm_give", Command_GivePills, ADMFLAG_BAN, "给生还者药丸");
	RegAdminCmd("sm_geiyao", Command_GivePills, ADMFLAG_BAN, "给生还者药丸");
	RegAdminCmd("sm_geiyaoto", Command_GiveWhoPills, ADMFLAG_BAN, "给特定生还者药丸");
	RegAdminCmd("sm_giveto", Command_GiveWhoPills, ADMFLAG_BAN, "给特定生还者药丸");	
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
	//PrintToChatAll("\x03系统：\x01如果系统没有自动发药，管理员可以输入获得药丸:\x04!geiyao");
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
	decl String:target[64];
	GetCmdArgString(target, sizeof(target));
	
	new tclient = FindTarget(client, target, false /*include bots*/, false /*immunity*/);
	if (tclient == -1 || !IsClientInGame(tclient)) return Plugin_Handled;
	
	decl String:tclientName[128];
	GetClientName(tclient,tclientName,128);
	if(GetClientTeam(tclient)!=2)
	{
		ReplyToCommand(client, "[TS] Usage: %T","l4d_PillsHere2",client,tclientName);	
		return Plugin_Handled;
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
		return Plugin_Handled;
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
