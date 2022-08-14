#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>

#define PLUGIN_VERSION "1.1"
#define COUNTDOWNTIMER_OFFS_TIMESTAMP view_as<Address>(8)

#define GAMEDATA_FILE "l4d_panic_event_timer_remove"
#define KEY "mob_CooldownTimer"

public Plugin myinfo = 
{
	name = "l4d remove panic event timer",
	author = "Forgetest, HarryPotter",
	description = "Remove restricted time between panic events (90s)",
	version = PLUGIN_VERSION,
	url = "https://steamcommunity.com/profiles/76561198026784913/"
};

Address CDirector__m_mobCooldownTimer;
int g_iOffset;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	
	if( test != Engine_Left4Dead )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1");
		return APLRes_SilentFailure;
	}

	return APLRes_Success; 
}

public void OnPluginStart()
{
	GameData hGameData = new GameData(GAMEDATA_FILE);
	if (hGameData == null)
		SetFailState("Missing gamedata file (" ... GAMEDATA_FILE ... ")");

	g_iOffset = GameConfGetOffset(hGameData, KEY);
	if (g_iOffset == -1) {
		SetFailState("Failed to get offset \"" ... KEY ... "\"");
	}

	delete hGameData;

	CDirector__m_mobCooldownTimer = view_as<Address>(g_iOffset);
	
	HookEvent("create_panic_event", Event_CreatePanicEvent);
}

void Event_CreatePanicEvent(Event event, const char[] name, bool dontBroadcast)
{
	StoreToAddress(L4D_GetPointer(POINTER_DIRECTOR) + CDirector__m_mobCooldownTimer + COUNTDOWNTIMER_OFFS_TIMESTAMP, view_as<int>(-1.0), NumberType_Int32);
}
