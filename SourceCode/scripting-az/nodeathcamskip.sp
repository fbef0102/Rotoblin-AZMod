#pragma semicolon 1

#include <sourcemod>
#include <left4dhooks>

//#define RemoveSpamBlockTimer 10.0
static bool:bBlockButton[MAXPLAYERS + 1];
public Plugin:myinfo = 
{
    name = "Death Cam Skip Fix",
    author = "Jacob, HarryPotter",
    description = "Blocks players skipping their death cam, l4d1 modify by Harry",
    version = "1.3",
    url = "github.com/jacob404/myplugins"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	
	if( test != Engine_Left4Dead )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1.");
		return APLRes_SilentFailure;
	}

	CreateNative("SetClientDeathCam", Native_SetClientDeathCam);
	return APLRes_Success;
}

public int Native_SetClientDeathCam(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	bBlockButton[client] = true;

	return 0;
}

public OnPluginStart()
{
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("round_start", event_RoundStart);//每回合開始就發生的event
	HookEvent("player_spawn", eventSpawnReadyCallback);
	HookEvent("player_team",Event_PlayerChangeTeam);
}

public Event_PlayerChangeTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	new userID = GetClientOfUserId(GetEventInt(event, "userid"));
	if(userID==0)
		return ;

	//PrintToChat(userID,"\x02X02 \x03X03 \x04X04 \x05X05 ");\\ \x02:color:default \x03:lightgreen \x04:orange \x05:darkgreen
	if(!IsFakeClient(userID)&&IsClientConnected(userID)&&IsClientInGame(userID))
		CreateTimer(1.0,PlayerChangeTeamCheck,userID);
}

public Action:PlayerChangeTeamCheck(Handle:timer,any:client)
{
	if(IsClientConnected(client) && IsClientInGame(client)&& !IsFakeClient(client)&&GetClientTeam(client)!=3)
			bBlockButton[client] = false;
}

public Action:event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	new i;
	for(i=0;i<=MAXPLAYERS;++i)
		bBlockButton[i] = false;
}

public Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event,"userid"));
	if(IsValidClient(client) && GetClientTeam(client) == 3)
	{
		bBlockButton[client] = true;
		//CreateTimer(RemoveSpamBlockTimer, RemoveSpamBlock, client);
	}
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)	//should prevent players from moving
{
	if(IsClientInGame(client) && GetClientTeam(client) == 3 && !IsPlayerAlive(client) && bBlockButton[client])//進入靈魂狀態 IsPlayerAlive 為真
	{
		buttons = 0;
	}
	return Plugin_Continue;	
}

public Action:eventSpawnReadyCallback(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event,"userid"));
	if(IsValidClient(client))
	{
		bBlockButton[client] = false;
	}
}

stock bool:IsValidClient(client, bool:nobots = true)
{ 
    if (client <= 0 || client > MaxClients || !IsClientInGame(client) || (nobots && IsFakeClient(client)))
    {
        return false; 
    }
    return true; 
}