#include <sourcemod>
#include <adminmenu>
#include <sdktools>
#include <multicolors>
#define PLUGIN_VERSION    "2.5"

enum
{
	L4D_TEAM_SPECTATE = 1,
	L4D_TEAM_SURVIVOR = 2,
	L4D_TEAM_INFECTED = 3,
}

public Plugin:myinfo =
{
	name = "Adm Give full health",
	author = "Harry Potter",
	description = "Adm type !givehp to set survivor team full health",
	version = PLUGIN_VERSION,
	url = "http://steamcommunity.com/profiles/76561198026784913"
}

public OnPluginStart(){
	LoadTranslations("Roto2-AZ_mod.phrases");
	RegAdminCmd("sm_hp", restore_hp, ADMFLAG_ROOT, "Restore all survivors full hp");
	RegAdminCmd("sm_givehp", restore_hp, ADMFLAG_ROOT, "Restore all survivors full hp");
}

public Action:restore_hp(client, args){
	if (client == 0)
	{
		PrintToServer("[TS] %t","command cannot be used by server.");
		return Plugin_Handled;
	}
	
	for( new i = 1; i <= MaxClients; i++ ) {
		if (IsClientInGame(i) && IsClientConnected(i) && GetClientTeam(i)==L4D_TEAM_SURVIVOR && IsPlayerAlive(i))
			CheatCommand(i);
	}
	
	decl String:clientName[128];
	GetClientName(client,clientName,128);
	CPrintToChatAll("{default}[{olive}TS{default}] %t","admin_hp", clientName);
	LogMessage("[TS] Adm %N restores all survivors FULL HP", client);
	
	return Plugin_Handled;
}

CheatCommand(client)
{
	new give_flags = GetCommandFlags("give");
	SetCommandFlags("give", give_flags & ~FCVAR_CHEAT);
	if (GetEntProp(client, Prop_Send, "m_isHangingFromLedge"))//懸掛
	{
		FakeClientCommand(client, "give health");
	}
	else if (IsIncapacitated(client))//倒地
	{
		FakeClientCommand(client, "give health");
		SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
		SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0);
	}
	else if(GetClientHealth(client)<100) //血量低於100
	{
		FakeClientCommand(client, "give health");
		SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
		SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0);
	}
	
	SetCommandFlags("give", give_flags);
}

stock IsIncapacitated(client)
{
	return GetEntProp(client, Prop_Send, "m_isIncapacitated");
}