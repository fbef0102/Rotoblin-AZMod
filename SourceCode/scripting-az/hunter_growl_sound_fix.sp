#define PLUGIN_VERSION "1.2"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#undef REQUIRE_PLUGIN
#include <l4d_lib>

//修正Hunter玩家MIC說話的時候Hunter會發出低吼聲即使Hunter仍然站著不動
//Hunter低吼警示聲
#define Hunter_Growl_SOUND	"player/hunter/voice/idle/Hunter_Stalk_01.wav"
//Hunter低吼警示聲
#define Hunter_Growl_SOUND2 "player/hunter/voice/idle/Hunter_Stalk_04.wav"
//Hunter低吼警示聲
#define Hunter_Growl_SOUND3 "player/hunter/voice/idle/Hunter_Stalk_05.wav"

#define POUNCE_TIMER            0.1
#define TEAM_INFECTED           3
#define DEBUG 0
static					g_iOffsetFallVelocity					= -1;
static	const	String:	CLASSNAME_TERRORPLAYER[] 				= "CTerrorPlayer";
static	const	String:	NETPROP_FALLVELOCITY[]					= "m_flFallVelocity";

public Plugin:myinfo =
{
	name = "Hunter produces growl fix",
	author = "Harry Potter",
	description = "Fix Hunter produces growl sound when MIC on Bug",
	version = PLUGIN_VERSION,
	url = "http://steamcommunity.com/profiles/76561198026784913"
}

public OnPluginStart()
{
	AddNormalSoundHook(SI_sh_OnSoundEmitted);
	g_iOffsetFallVelocity = FindSendPropInfo(CLASSNAME_TERRORPLAYER, NETPROP_FALLVELOCITY);
	if (g_iOffsetFallVelocity <= 0) ThrowError("Unable to find fall velocity offset!");
}

public Action:SI_sh_OnSoundEmitted(clients[64], &numClients, String:sample[PLATFORM_MAX_PATH], &entity, &channel, &Float:volume, &level, &pitch, &flags)
{

	if (numClients >= 1 && IsClient(entity) ){
	
		#if DEBUG
			PrintToChatAll("Sound:%s - numClients %d, entity %d",sample, numClients, entity);
		#endif
		
		//Hunter Stand Still MIC Bug
		if(IsPlayerAlive(entity) &&( (StrEqual(sample, Hunter_Growl_SOUND)) || (StrEqual(sample, Hunter_Growl_SOUND2)) || (StrEqual(sample, Hunter_Growl_SOUND3))) )
		{
			#if DEBUG
				PrintToChatAll("Here");
			#endif
			
			// If they do have the duck button pushed
			if (GetClientButtons(entity) & IN_DUCK){ return Plugin_Continue; }
			
			#if DEBUG
				if(GetEntDataFloat(entity, g_iOffsetFallVelocity) == 0.0) PrintToChatAll("FALL:0");	
				if(GetEntProp(entity, Prop_Data, "m_fFlags") & FL_ONGROUND) PrintToChatAll("On The Ground");
				PrintToChatAll("Block Sound");
			#endif
			
			return Plugin_Stop;
		}
	}
	return Plugin_Continue;
}