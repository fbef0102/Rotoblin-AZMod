#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>

#define PLUGIN_VERSION "1.0"
#define COUNTDOWNTIMER_OFFS_TIMESTAMP view_as<Address>(8)

public Plugin myinfo = 
{
	name = "l4d remove panic event timer",
	author = "Forgetest, HarryPotter",
	description = "Remove restricted time between panic events (90s)",
	version = PLUGIN_VERSION,
	url = "https://steamcommunity.com/profiles/76561198026784913/"
};

Address CDirector__m_mobCooldownTimer;

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
	if (L4D_GetServerOS()) CDirector__m_mobCooldownTimer = view_as<Address>(1656);
	else CDirector__m_mobCooldownTimer = view_as<Address>(1660);
	
	HookEvent("create_panic_event", Event_CreatePanicEvent);
}

void Event_CreatePanicEvent(Event event, const char[] name, bool dontBroadcast)
{
	StoreToAddress(L4D_GetPointer(POINTER_DIRECTOR) + CDirector__m_mobCooldownTimer + COUNTDOWNTIMER_OFFS_TIMESTAMP, view_as<int>(-1.0), NumberType_Int32);
}
