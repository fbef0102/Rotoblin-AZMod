
#include <sourcemod>
#include <sdktools>
#pragma semicolon 1
#define CVAR_FLAGS FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY

new Handle:hVomit_Range;
new gVomit_Range;
new Handle:hVomit_Duration;
new Float:gVomit_Duration;
new Handle:VomitTimer[MAXPLAYERS+1];
new propinfoghost = -1; 

#define GAMEDATA_FILENAME            "l4d_vomit"
#define S_OnVomitedUpon              "CTerrorPlayer_OnVomitedUpon"
new Handle:g_hGameConf = INVALID_HANDLE;
new Handle:sdkVomitSurvivor = INVALID_HANDLE;
static const FullyPullSurvivorSequences[] = {31};


/*
// ====================================================================================================
Change Log:

1.1 (13-6-2019)
    - fix error
	- Fix player whom smoker fully drags back will not be biled by a boomer

1.0 (13-6-2019)
    - Initial release.
    - Fix player whom hunter pounces on will not be biled by a boomer

// ====================================================================================================
*/


public Plugin:myinfo =
{
	name = "[L4D] Vomit Pounce Fix",
	author = "Harry Potter",
	description = "Fixed that player whom hunter pounces on will not be biled by a boomer",
	version = "1.1",
	url = "https://steamcommunity.com/id/fbef0102/"
}

public OnPluginStart()
{
	LoadPluginSignatures();
	
	hVomit_Duration = FindConVar("z_vomit_duration");
	hVomit_Range = FindConVar("z_vomit_range");
	gVomit_Duration = GetConVarFloat(hVomit_Duration);
	gVomit_Range = GetConVarInt(hVomit_Range);
	HookEvent("ability_use", Vomit_Event);
	HookConVarChange(hVomit_Range, Vomit_RangeChanged);
	HookConVarChange(hVomit_Duration, Vomit_DurationChanged);
	propinfoghost = FindSendPropInfo("CTerrorPlayer", "m_isGhost");
	
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
}	
	
LoadPluginSignatures()
{
    g_hGameConf = LoadGameConfigFile(GAMEDATA_FILENAME);

    new String: sPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, sPath, PLATFORM_MAX_PATH, "gamedata/%s.txt", GAMEDATA_FILENAME);
    if (FileExists(sPath))
    {
        if(g_hGameConf == INVALID_HANDLE)
            SetFailState("Couldn't find the offsets and signatures file on \"gamedata/%s.txt\". Please, check that it is installed correctly.", GAMEDATA_FILENAME);

        StartPrepSDKCall(SDKCall_Player);
        PrepSDKCall_SetFromConf(g_hGameConf, SDKConf_Signature, S_OnVomitedUpon);
        PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
        PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
        sdkVomitSurvivor = EndPrepSDKCall();

        if(sdkVomitSurvivor == INVALID_HANDLE)
            SetFailState("Unable to find the \"%s\" signature, check the file version.", S_OnVomitedUpon);
    }
    else
        SetFailState("Missing required gamedata file on \"gamedata/%s.txt\", please re-download.", GAMEDATA_FILENAME);
}			
	
public Vomit_RangeChanged(Handle:convar, const String:oldValue[], const String:newValue[])
	{
		gVomit_Range = GetConVarInt(hVomit_Range);
	}			

public Vomit_DurationChanged(Handle:convar, const String:oldValue[], const String:newValue[])
	{
		gVomit_Duration = GetConVarFloat(hVomit_Duration);
	}			
	
public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
    for (new i=1; i <= MaxClients; i++)
    {
        //IsPlayerBiled[i] = false;
		VomitTimer[i] = INVALID_HANDLE;
    }
}
	
public Vomit_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid")); //we get client
	if ((!IsValidClient(client))||(GetClientTeam(client)!=3)) return; //must be valid infected
	decl String:model[128];
	GetClientModel(client, model, sizeof(model));
	if (StrContains(model, "boomer", false)!=-1)
	{
		VomitTimer[client] = CreateTimer(0.1, VomitTimerFunction, client, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
		CreateTimer(gVomit_Duration,KillingVomitTimer, client,TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action:VomitTimerFunction(Handle:timer, any:client)
{
	if (!IsValidClient(client)||GetClientTeam(client)!=3 || VomitTimer[client] == INVALID_HANDLE)
		{
			VomitTimer[client] = INVALID_HANDLE;
			return Plugin_Stop;
		}
	new target = GetClientAimTarget(client, true);
	if (target == -1 || target == -2) return Plugin_Continue; //無目標
	if (!IsValidClient(target)) return Plugin_Continue; //目標物非玩家
	
	
	new Float:boomer_position[3];
	new Float:target_position[3];
	GetClientAbsOrigin(client,boomer_position);
	GetClientAbsOrigin(target,target_position);
	new Float:temp1 = boomer_position[2];new Float:temp2 = target_position[2];
	boomer_position[2] = target_position [2] = 0.0;
	new distance = RoundToNearest(GetVectorDistance(boomer_position, target_position));//水平直線距離
	boomer_position[2] = temp1;target_position[2] = temp2;
	new bool:distanceallowedrange = CalculationDistanceAllowedRange(boomer_position[2],target_position[2],distance);//經過計算後的允許距離
	//PrintToChatAll("%N,官方範圍:%d,水平直線距離:%d",target, gVomit_Range,distance);
	if (IsSurvivorGetPounceGetPull(target))//人類被hunter抓 被smoker拉
	{
		if (distanceallowedrange)
			BoomerVomit(target);
	}
	new survivorclient = PlayerHunterAndPouncingSurvivor(target); //hunter撲倒玩家
	if (survivorclient!=-1)
	{
		if (distanceallowedrange)
			BoomerVomit(survivorclient);
	}
	
	survivorclient = PlayerSmokerAndPullSurvivor(target); //smoker拉到玩家
	if (survivorclient!=-1)
	{
		if(distanceallowedrange&&IsPlayingFullyPulledAnimation(target))//smoker完全地拉到玩家
			BoomerVomit(survivorclient);
	}
	
	return Plugin_Continue;
}

stock bool:CalculationDistanceAllowedRange(Float:boomer_height,Float:target_height,verticaldistance)
{
	new heightdifference;
	if(boomer_height>=target_height)
	{
		heightdifference = RoundToNearest(boomer_height - target_height);
		//PrintToChatAll("boomer_height:%f,target_height:%f,高位差:%d", boomer_height,target_height,heightdifference);
		
		if(50>=heightdifference && verticaldistance<=gVomit_Range+150)
			return true;
		if(200>=heightdifference&&heightdifference>50 && verticaldistance<=gVomit_Range+180)
			return true;		
		if(250>=heightdifference&&heightdifference>200 && verticaldistance<=gVomit_Range+160)
			return true;	
		if(400>=heightdifference&&heightdifference>250 && verticaldistance<=gVomit_Range+150)
			return true;	
		if(550>=heightdifference&&heightdifference>400 && verticaldistance<=gVomit_Range+100)
			return true;
		if(600>=heightdifference&&heightdifference>550 && verticaldistance<=gVomit_Range+50)
			return true;		
		if(650>=heightdifference&&heightdifference>600 && verticaldistance<=gVomit_Range)
			return true;	
		if(680>=heightdifference&&heightdifference>650 && verticaldistance<=gVomit_Range-50)
			return true;
		if(700>=heightdifference&&heightdifference>680&& verticaldistance<=gVomit_Range-125)
			return true;	
		if(740>=heightdifference&&heightdifference>700 && verticaldistance<=gVomit_Range-150)
			return true;
			
		if(heightdifference>740)
			return false;	
	}
	else
	{
		heightdifference = RoundToNearest(target_height - boomer_height);
		//PrintToChatAll("高位差:%d,boomer_height:%f,target_height:%f",heightdifference, boomer_height,target_height);
		
		if(50>=heightdifference && verticaldistance<=gVomit_Range+150)
			return true;
		if(200>=heightdifference&&heightdifference>50 && verticaldistance<=gVomit_Range)
			return true;
		if(300>=heightdifference&&heightdifference>200 && verticaldistance<=gVomit_Range-50)
			return true;
		if(350>=heightdifference&&heightdifference>300 && verticaldistance<=gVomit_Range-100)
			return true;
		if(380>=heightdifference&&heightdifference>350 && verticaldistance<=gVomit_Range-150)
			return true;
			
		if(heightdifference>380)
			return false;
	}
	
	return false;
}

public BoomerVomit(client)
{
	 SDKCall(sdkVomitSurvivor, client, client, true);
}

public Action:KillingVomitTimer(Handle:timer, any:client)
{
	if (VomitTimer[client] != INVALID_HANDLE)
		{
			KillTimer(VomitTimer[client]);	
			VomitTimer[client] = INVALID_HANDLE;
		}
}

stock bool:IsSurvivorGetPounceGetPull(client)
{
	if(GetClientTeam(client)!=2) return false; //不是人類
	if(!IsPlayerAlive(client)) return false; //死掉
	
	return GetEntProp(client, Prop_Send, "m_tongueOwner") > 0 || GetEntProp(client, Prop_Send, "m_pounceAttacker") > 0;//被撲到或被拉到
}

PlayerHunterAndPouncingSurvivor(client)
{
	if(GetClientTeam(client)!=3) return -1; //不是特感
	if(!IsPlayerAlive(client)) return -1; //死掉
	if(GetZombieClass(client) != 3) return -1; //不是Hunter
	if(IsGhost(client)) return -1; //鬼魂
	
	new hasvictim = GetEntPropEnt(client, Prop_Send, "m_pounceVictim");//hunter 
	if(IsValidClient(hasvictim) && GetClientTeam(hasvictim)==2 && IsPlayerAlive(hasvictim))
		return hasvictim;
		
	return -1;
}

PlayerSmokerAndPullSurvivor(client)
{
	if(GetClientTeam(client)!=3) return -1; //不是特感
	if(!IsPlayerAlive(client)) return -1; //死掉
	if(GetZombieClass(client) != 1) return -1; //不是smoker
	if(IsGhost(client)) return -1; //鬼魂
	
	new hasvictim = GetEntPropEnt(client, Prop_Send, "m_tongueVictim");//smoker
	if(IsValidClient(hasvictim) && GetClientTeam(hasvictim)==2 && IsPlayerAlive(hasvictim))
		return hasvictim;
		
	return -1;
}

bool:IsGhost(client)
{
	new isghost = GetEntData(client, propinfoghost, 1);
	
	if (isghost == 1) return true;
	else return false;
}

stock bool:IsClient(index)
{
	return index > 0 && index <= MaxClients;
}

stock bool:IsValidClient(client)
{
	if (client == 0)
		return false;
	
	if (!IsClient(client))
		return false;
	
	if (!IsClientConnected(client))
		return false;
	
	if (!IsClientInGame(client))
		return false;
		
	return true;
}

stock GetZombieClass(client) return GetEntProp(client, Prop_Send, "m_zombieClass");

bool:IsPlayingFullyPulledAnimation(smoker)  
{
	new sequence = GetEntProp(smoker, Prop_Send, "m_nSequence");
	
	//PrintToChatAll("\x04%N\x01 playing sequence \x04%d\x01", smoker, sequence);
	
	for (new i = 0; i < sizeof(FullyPullSurvivorSequences); i++)
	{
		if (FullyPullSurvivorSequences[i] == sequence) return true;
	}
		
	return false;
}