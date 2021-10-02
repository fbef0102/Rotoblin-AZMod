#pragma semicolon 1
#include <sourcemod>
#include <multicolors>

//#define clamp(%0, %1, %2) ( ((%0) < (%1)) ? (%1) : ( ((%0) > (%2)) ? (%2) : (%0) ) )
#define MAX(%0,%1) (((%0) > (%1)) ? (%0) : (%1))

public Plugin:myinfo = 
{
	name = "LerpTracker",
	author = "ProdigySim (archer edit), Die Teetasse, vintik, Harry Potter",
	description = "Keep track of players' lerp settings",
	version = "1.3",
	url = "https://bitbucket.org/ProdigySim/misc-sourcemod-plugins"
};

/* Global Vars */
new Float:g_fCurrentLerps[MAXPLAYERS+1];

/* My CVars */
new Handle:hLogLerp;
new Handle:hAnnounceLerp;
new Handle:hFixLerpValue;
new Handle:hMaxLerpValue;

/* Valve CVars */
new Handle:hMinUpdateRate;
new Handle:hMaxUpdateRate;
new Handle:hMinInterpRatio;
new Handle:hMaxInterpRatio;
//what even?
new Handle:hPrintLerpStyle;

static Handle:arrayLerps;
static Handle:cVarReadyUpLerpChanges;
static Handle:cVarAllowedLerpChanges;
static Handle:cVarLerpChangeSpec;
static Handle:cVarMinLerp;
static Handle:cVarMaxLerp;

// psychonic made me do it

#define ShouldFixLerp() (GetConVarBool(hFixLerpValue))

#define ShouldAnnounceLerpChanges() (GetConVarBool(hAnnounceLerp))

#define DefaultLerpStyle() (GetConVarBool(hPrintLerpStyle))

#define ShouldLogLerpChanges() (GetConVarBool(hLogLerp))

#define ShouldLogInitialLerp() (GetConVarInt(hLogLerp) == 1)

#define IsCurrentLerpValid(%0) (g_fCurrentLerps[(%0)] >= 0.0)

#define InvalidateCurrentLerp(%0) (g_fCurrentLerps[(%0)] = -1.0)

#define GetCurrentLerp(%0) (g_fCurrentLerps[(%0)])
#define SetCurrentLerp(%0,%1) (g_fCurrentLerps[(%0)] = (%1))
#define COLDDOWN_DELAY 6.0
#define STEAMID_SIZE 		32
static const ARRAY_LERP = 1;
static const ARRAY_CHANGES = 2;
static const ARRAY_COUNT = 3;

static bool:blerpdetect[MAXPLAYERS + 1];
static ClientTeam[MAXPLAYERS + 1];
static bool:roundstart;
static bool:isFirstHalf = true;
native Is_Ready_Plugin_On();
native IsInReady();

public OnPluginStart()
{
	LoadTranslations("Roto2-AZ_mod.phrases");
	hMinUpdateRate = FindConVar("sv_minupdaterate");
	hMaxUpdateRate = FindConVar("sv_maxupdaterate");
	hMinInterpRatio = FindConVar("sv_client_min_interp_ratio");
	hMaxInterpRatio= FindConVar("sv_client_max_interp_ratio");
	
	cVarAllowedLerpChanges = CreateConVar("sm_allowed_lerp_changes", "3", "Allowed number of lerp changes for a half", FCVAR_NOTIFY);
	cVarLerpChangeSpec = CreateConVar("sm_lerp_change_spec", "1", "Move to spectators on exceeding lerp changes count?", FCVAR_NOTIFY);
	cVarReadyUpLerpChanges = CreateConVar("sm_readyup_lerp_changes", "1", "Allow lerp changes during ready-up", FCVAR_NOTIFY);
	
	hLogLerp = CreateConVar("sm_log_lerp", "1", "Log changes to client lerp. 1=Log initial lerp and changes 2=Log changes only", FCVAR_NOTIFY);
	hAnnounceLerp = CreateConVar("sm_announce_lerp", "1", "Announce changes to client lerp. 1=Announce initial lerp and changes 2=Announce changes only", FCVAR_NOTIFY);
	hFixLerpValue = CreateConVar("sm_fixlerp", "1", "Fix Lerp values clamping incorrectly when interp_ratio 0 is allowed", FCVAR_NOTIFY);
	hMaxLerpValue = CreateConVar("sm_max_interp", "0.1", "Kick players whose settings breach this Hard upper-limit for player lerps.", FCVAR_NOTIFY);
	hPrintLerpStyle = CreateConVar("sm_lerpstyle", "1", "Display Style, 0 = default, 1 = team based", FCVAR_NOTIFY);
	cVarMinLerp = CreateConVar("sm_min_lerp", "0.000", "Minimum allowed lerp value", FCVAR_NOTIFY);
	cVarMaxLerp = CreateConVar("sm_max_lerp", "0.067", "Maximum allowed lerp value, move to spec if exceed", FCVAR_NOTIFY);
	
	RegConsoleCmd("sm_lerps", Lerps_Cmd, "List the Lerps of inf/sur players in game", FCVAR_NOTIFY);
	RegConsoleCmd("sm_lerpss", Lerpss_Cmd, "List the Lerps of spec players in game", FCVAR_NOTIFY);
	
	HookEvent("player_team", OnTeamChange);
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);
	
	// create array
	arrayLerps = CreateArray(ByteCountToCells(STEAMID_SIZE));
	ScanAllPlayersLerp();
}


public OnMapEnd() {
	isFirstHalf = true;
	ClearArray(arrayLerps);
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast) {
	CreateTimer(3.0, roundstart_true,_, _);
	
	if (!IsFirstHalf()) {
		for (new i = 0; i < (GetArraySize(arrayLerps) / ARRAY_COUNT); i++) {
			SetArrayCell(arrayLerps, (i * ARRAY_COUNT) + ARRAY_CHANGES, 0);
		}
	}
}
public Action:roundstart_true(Handle:timer, any:client)
{
	roundstart = true;
}

public Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast) {
	roundstart = false;
	
	CreateTimer(0.5, Timer_RoundEndDelay);
}

public Action:Timer_RoundEndDelay(Handle:timer) {
	isFirstHalf = false;
}

public OnClientDisconnect_Post(client)
{
	InvalidateCurrentLerp(client);
}

/* Lerp calculation adapted from hl2sdk's CGameServerClients::OnClientSettingsChanged */
public OnClientSettingsChanged(client)
{
	if(IsValidEntity(client) &&  !IsFakeClient(client)&& blerpdetect[client])
	{
		ProcessPlayerLerp(client);
	}
}

public OnTeamChange(Handle:event, String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client > 0 && client < MaxClients+1)
	{
		if (IsClientInGame(client) && !IsFakeClient(client))
		{
			CreateTimer(1.0, OnTeamChangeDelay, client, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public OnClientPutInServer(client)
{
	blerpdetect[client] = false;
	CreateTimer(COLDDOWN_DELAY, COLDOWN,client, TIMER_FLAG_NO_MAPCHANGE);
	ClientTeam[client] = 0;
}

public Action:COLDOWN(Handle:timer, any:client)
{
	blerpdetect[client] = true;
	if (client && IsClientConnected(client) && IsClientInGame(client)&& !IsFakeClient(client) && GetClientTeam(client) != 1 && blerpdetect[client])
	{
		ClientTeam[client] = GetClientTeam(client);
		ProcessPlayerLerp(client,true);
	}
}

public Action:OnTeamChangeDelay(Handle:timer, any:client)
{
	new iTeam;
	if(!(client && IsClientConnected(client) && IsClientInGame(client)&& !IsFakeClient(client)))
		return Plugin_Continue;
	else
		iTeam = GetClientTeam(client);
	if (blerpdetect[client] && ClientTeam[client] != iTeam)
	{
		ClientTeam[client] = iTeam;
		if(iTeam != 1)
			ProcessPlayerLerp(client,true);
		return Plugin_Handled;
	}
	return Plugin_Continue;
}


public Action:Lerps_Cmd(client, args)
{
	if(!DefaultLerpStyle())
	{
		new lerpcnt;
		
		for(new rclient=1; rclient <= MaxClients; rclient++)
		{
			if(IsClientInGame(rclient) && !IsFakeClient(rclient) && GetClientTeam(rclient) != 1)
			{
				ReplyToCommand(client, "%02d. %N Lerp: %.01f", ++lerpcnt, rclient, (GetCurrentLerp(rclient)*1000));
			}
		}
	}
	else
	{
		new survivorCount = 0;
		new infectedCount = 0;
		//new bool:survivorPrinted = false;
		//new bool:infectedPrinted
		
		
		for(new rclient=1; rclient <= MaxClients; rclient++)
		{
			if(IsClientInGame(rclient) && !IsFakeClient(rclient))
			{
				if (GetClientTeam(rclient) == 2) survivorCount = 1;
				if (GetClientTeam(rclient) == 3) infectedCount = 1;
			}
		}
		
		if (survivorCount == 1 || infectedCount == 1) CPrintToChat(client, "{blue}{green}______________________________");
		
		for(new rclient=1; rclient <= MaxClients; rclient++)
		{
			if(IsClientInGame(rclient) && !IsFakeClient(rclient) && GetClientTeam(rclient) == 2)
			{
				CPrintToChat(client, "{blue}%N {default}@ {green}%.01f", rclient, (GetCurrentLerp(rclient)*1000));				
			}			
		}
		//if (survivorCount == 1 && infectedCount == 1) CPrintToChat(client, "{blue}{default} ");
		for(new rclient=1; rclient <= MaxClients; rclient++)
		{
			if(IsClientInGame(rclient) && !IsFakeClient(rclient) && GetClientTeam(rclient) == 3)
			{
				CPrintToChat(client, "{red}%N {default}@ {green}%.01f", rclient, (GetCurrentLerp(rclient)*1000));
				//CPrintToChat(client, "{blue}TEST {green}%i", survivorCount);
			}
		}
		if (survivorCount == 1 || infectedCount == 1) CPrintToChat(client, "{blue}{green}______________________________");
	}
	return Plugin_Handled;
}

public Action:Lerpss_Cmd(client, args)
{
	new rclient;
	if(!DefaultLerpStyle())
	{
		new lerpcnt;
		for(rclient=1; rclient <= MaxClients; rclient++)
		{
			if(IsClientInGame(rclient) && !IsFakeClient(rclient) && GetClientTeam(rclient) == 1)
			{
				ReplyToCommand(client, "%02d. %N Lerp: %.01f", ++lerpcnt, rclient, (GetCurrentLerp(rclient)*1000));
			}
		}
	}
	else
	{
		new bool:specPrinted = false;
		
		
		for(rclient=1; rclient <= MaxClients; rclient++)
		{
			if(IsClientInGame(rclient) && !IsFakeClient(rclient) && GetClientTeam(rclient) == 1)
			{
				specPrinted = true;
				break;
			}
		}
		
		if (specPrinted) CPrintToChat(client, "{blue}{green}______________________________");
		
		for(rclient=1; rclient <= MaxClients; rclient++)
		{
			if(IsClientInGame(rclient) && !IsFakeClient(rclient) && GetClientTeam(rclient) == 1)
			{
				CPrintToChat(client, "{lightgreen}%N {default}@ {green}%.01f", rclient, (GetCurrentLerp(rclient)*1000));				
			}			
		}
		if (specPrinted) CPrintToChat(client, "{blue}{green}______________________________");
	}
	return Plugin_Handled;
}

ScanAllPlayersLerp()
{
	for(new client=1; client <= MaxClients; client++)
	{
		InvalidateCurrentLerp(client);
		if(IsClientInGame(client) && !IsFakeClient(client))
		{
			ProcessPlayerLerp(client);
		}
	}
}

ProcessPlayerLerp(client,bool:teamchange = false)
{	
	new Float:newLerpTime = GetEntPropFloat(client, Prop_Data, "m_fLerpTime");
	new iTeam = GetClientTeam(client);
	if (iTeam == 1) return;

	if(ShouldFixLerp())
	{
		newLerpTime = GetLerpTime(client);
		SetEntPropFloat(client, Prop_Data, "m_fLerpTime", newLerpTime);
	}
	
	new Float:MaxLerpValue=GetConVarFloat(hMaxLerpValue);
	if(newLerpTime > MaxLerpValue)
	{
		KickClient(client, "Lerp %.01f exceeds server max of %.01f", newLerpTime*1000, MaxLerpValue*1000);
		CPrintToChatAll("<{olive}Lerp{default}> %N %t %.01f > %.01f", client,"lerptracker1", newLerpTime*1000, MaxLerpValue*1000);
		if(ShouldLogLerpChanges())
			LogMessage("Kicked %L for having lerp %.01f (max: %.01f)", client, newLerpTime*1000, MaxLerpValue*1000);
		return;
	}
	
	if ( ((FloatCompare(newLerpTime, GetConVarFloat(cVarMinLerp)) == -1) || (FloatCompare(newLerpTime, GetConVarFloat(cVarMaxLerp)) == 1)) && IsMatchLife()) {
		
		if (iTeam == 2)
			CPrintToChatAll("<{olive}Lerp{default}> {blue}%N{default} %t {olive}%.01f{default}", client,"lerptracker2", newLerpTime*1000);
		else if (iTeam == 3)
			CPrintToChatAll("<{olive}Lerp{default}> {red}%N{default} %t {olive}%.01f{default}", client,"lerptracker2", newLerpTime*1000);
			
		ChangeClientTeam(client, 1);
		CPrintToChat(client, "{blue}{default}[{green}TS{default}] %T (%T: {olive}%.01f{default}, %T: {olive}%.01f{default})","Illegal lerp value",client,"Min",client,GetConVarFloat(cVarMinLerp)*1000,"Max",client, GetConVarFloat(cVarMaxLerp)*1000);
		// nothing else to do
		return;
	}
	
	if(IsCurrentLerpValid(client))
	{
		decl String:steamID[STEAMID_SIZE];
		GetClientAuthId(client, AuthId_Steam2, steamID, STEAMID_SIZE);
		decl String:clientName[128];
		GetClientName(client,clientName,128);
		new index = FindStringInArray(arrayLerps, steamID);
		if (index != -1) {
			new Float:currentLerpTime = GetArrayCell(arrayLerps, index + ARRAY_LERP);
		
			// no change?
			if (currentLerpTime != newLerpTime)
			{
				// Midgame?
				if ( (IsMatchLife() && !IsInReady()) || (!GetConVarBool(cVarReadyUpLerpChanges) && IsInReady()) ) {
					new count = GetArrayCell(arrayLerps, index + ARRAY_CHANGES)+1;
					new max = GetConVarInt(cVarAllowedLerpChanges);
					if(ShouldAnnounceLerpChanges())
					{
						if (iTeam == 2)
							CPrintToChatAll("<{olive}Lerp{default}> {blue}%t","lerptracker3", clientName, currentLerpTime*1000, newLerpTime*1000,((count > max)?"{green}":""), count, max);
						else if (iTeam == 3)
							CPrintToChatAll("<{olive}Lerp{default}> {red}%t","lerptracker3", clientName, currentLerpTime*1000, newLerpTime*1000,((count > max)?"{green}":""), count, max);
					}
				
					if (GetConVarBool(cVarLerpChangeSpec) && (count > max)) {
						
						if (iTeam == 2)
							CPrintToChatAll("<{olive}Lerp{default}> {blue}%t","lerptracker4", clientName);
						else if (iTeam == 3)
							CPrintToChatAll("<{olive}Lerp{default}> {red}%t","lerptracker4", clientName);
						ChangeClientTeam(client, 1);
						CPrintToChat(client, "{olive}{blue}{olive}{default}%T","lerptracker5",client, currentLerpTime*1000);
						if(ShouldLogLerpChanges())
							LogMessage("%N was moved to spectators (exceeds lerp change limit)!", client);
						// no lerp update
						return;
					}
					
					// update changes
					SetArrayCell(arrayLerps, index + ARRAY_CHANGES, count);
				}
				else {
					if(ShouldAnnounceLerpChanges())
					{
						if (iTeam == 2)
							CPrintToChatAll("<{olive}Lerp{default}> {blue}%t","lerptracker6", clientName, currentLerpTime*1000, newLerpTime*1000);
						else if (iTeam == 3)
							CPrintToChatAll("<{olive}Lerp{default}> {red}%t","lerptracker6", clientName, currentLerpTime*1000, newLerpTime*1000);
					}
				}
			}
			
			// update lerp
			SetArrayCell(arrayLerps, index + ARRAY_LERP, newLerpTime);
		}
		else {
			if(ShouldAnnounceLerpChanges() && GetCurrentLerp(client) != newLerpTime)
			{
				if (iTeam == 2)
					CPrintToChatAll("<{olive}Lerp{default}> {blue}%t","lerptracker6", clientName, GetCurrentLerp(client)*1000, newLerpTime*1000);
				else if (iTeam == 3)
					CPrintToChatAll("<{olive}Lerp{default}> {red}%t","lerptracker6", clientName, GetCurrentLerp(client)*1000, newLerpTime*1000);
			}
			
			// add to array
			PushArrayString(arrayLerps, steamID);
			PushArrayCell(arrayLerps, newLerpTime);
			PushArrayCell(arrayLerps, 0);
		}
	}
	
	SetCurrentLerp(client, newLerpTime);
	
	if(teamchange&&roundstart)
	{
		if(iTeam == 2)
			CPrintToChatAll("<{olive}Lerp{default}> {blue}%N {default}@{blue} %.01f",client,newLerpTime*1000);
		else if (iTeam == 3)
			CPrintToChatAll("<{olive}Lerp{default}> {red}%N {default}@{red} %.01f",client,newLerpTime*1000);
	}
}



stock Float:GetLerpTime(client)
{
	decl String:buf[64], Float:lerpTime;
	
#define QUICKGETCVARVALUE(%0) (GetClientInfo(client, (%0), buf, sizeof(buf)) ? buf : "")
	
	new updateRate = StringToInt( QUICKGETCVARVALUE("cl_updaterate") );
	updateRate = RoundFloat(clamp(float(updateRate), GetConVarFloat(hMinUpdateRate), GetConVarFloat(hMaxUpdateRate)));
	

	new Float:flLerpRatio = StringToFloat( QUICKGETCVARVALUE("cl_interp_ratio") );
	new Float:flLerpAmount = StringToFloat( QUICKGETCVARVALUE("cl_interp") );

	
	if ( hMinInterpRatio != INVALID_HANDLE && hMaxInterpRatio != INVALID_HANDLE && GetConVarFloat(hMinInterpRatio) != -1.0 )
	{
		flLerpRatio = clamp( flLerpRatio, GetConVarFloat(hMinInterpRatio), GetConVarFloat(hMaxInterpRatio) );
	}

	lerpTime = MAX( flLerpAmount, flLerpRatio / updateRate );
	
#undef QUICKGETCVARVALUE
	return lerpTime;
}

stock Float:clamp(Float:yes, Float:low, Float:high)
{
	return yes > high ? high : (yes < low ? low : yes);
}

stock bool:IsMatchLife() {
	if(Is_Ready_Plugin_On())
		return true;
	else
		return false;
}

stock bool:IsFirstHalf() {
	return isFirstHalf;
}