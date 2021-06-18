#pragma semicolon 1

#include <sourcemod>
#include <sdktools>


new     Handle:g_hHunterSubtitles          = INVALID_HANDLE;

public Plugin:myinfo = 
{
    name = "Hunter Call-out Blocker",
    author = "High Cookie (L4D1 port by Harry)",
    description = "Stops Survivors from saying 'Hunter!' (sometimets survivors didn't see the silence hunter but their mouth keep saying 'Hunter!')",
    version = "1.0",
    url = ""
}

public OnPluginStart()
{
	PrepareSubtitleArray();
	AddNormalSoundHook(NormalSHook:sound_hook);
	HookUserMessage(GetUserMessageId("CloseCaption"), OnCloseCaption, true);
	HookUserMessage(GetUserMessageId("CloseCaptionDirect"), OnCloseCaption, true);
}

public Action:sound_hook(clients[64], &numClients, String:sample[PLATFORM_MAX_PATH], &entity, &channel, &Float:volume, &level, &pitch, &flags)
{
	if (StrContains(sample, "WarnHunter")!=-1)
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action:OnCloseCaption(UserMsg:msg_id, Handle:bf, const players[], playersNum, bool:reliable, bool:init)
{
	new id = BfReadNum(bf);
	if (FindValueInArray(g_hHunterSubtitles, id) != -1)
	{
		return Plugin_Handled;
	}
	//debug
	//CreateTimer(1.0,COLD_DOWN,id);
	return Plugin_Continue;
}
/*
public Action:COLD_DOWN(Handle:timer,any:id)
{
	PrintToChatAll("  %d  ",id);
}
*/	
PrepareSubtitleArray()
{
	g_hHunterSubtitles = CreateArray(23);
	PushArrayCell(g_hHunterSubtitles,-2116245366);
	PushArrayCell(g_hHunterSubtitles,1876085158);
	PushArrayCell(g_hHunterSubtitles,-153380836);
	
	PushArrayCell(g_hHunterSubtitles,1733309612);
	PushArrayCell(g_hHunterSubtitles,-27695850);
	PushArrayCell(g_hHunterSubtitles,-1990306432);
	
	PushArrayCell(g_hHunterSubtitles,1715646612);
	PushArrayCell(g_hHunterSubtitles,-2008231496);
	PushArrayCell(g_hHunterSubtitles,-11804370);
	
	PushArrayCell(g_hHunterSubtitles,1322656796);
	PushArrayCell(g_hHunterSubtitles,970003594);
	PushArrayCell(g_hHunterSubtitles,-673221210);
}
//FRANCIS: -2116245366, 1876085158, -153380836
//LOUIS: 1733309612, -27695850, -1990306432
//ZOEY: 1715646612, -2008231496, -11804370
//BILL: 1322656796, 970003594, -673221210  