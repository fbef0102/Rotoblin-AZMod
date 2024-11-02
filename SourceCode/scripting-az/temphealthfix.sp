#include <sourcemod>

public Plugin:myinfo =
{
	name = "Hittable Temp Health Fixer",
	author = "CanadaRox",
	description = "Ensures that survivors that have been incapacitated with a hittable object get their temp health set correctly",
	version = "13.3.7",
	url = "https://bitbucket.org/CanadaRox/random-sourcemod-stuff/"
};

public void OnPluginStart()
{
	HookEvent("player_incapacitated_start", Incap_Event);
}

public Incap_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	decl String:weapon[32];
	GetEventString(event, "weapon", weapon, sizeof(weapon));
	SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0);
	if (StrEqual(weapon, "prop_physics")||StrEqual(weapon, "prop_car_alarm"))
		CreateTimer(0.1,COLD_DOWN,GetClientUserId(client));
}
public Action:COLD_DOWN(Handle:timer,any:client)
{
	client = GetClientOfUserId(client);
	if(client && IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client))
	{
		SetEntityHealth(client,300);
	}
}