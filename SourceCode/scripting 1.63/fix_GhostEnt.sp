#define PLUGIN_VERSION "1.0"

#include <sourcemod>
#include <sdkhooks>

#define debug 1

public Plugin:myinfo =
{
	name = "Ghost ent",
	author = "raziEiL [disawar]",
	description = "blah",
	version = PLUGIN_VERSION,
	url = "http://steamcommunity.com/id/raziEiL"
}

public OnPluginStart()
{
	RegAdminCmd("sm_gent", CmdTeleToEnt, ADMFLAG_ROOT, "Developer cmd");
}

public Action:CmdTeleToEnt(client, agrs)
{
	if (!client) return Plugin_Handled;
	
	if (agrs == 0){

		ReplyToCommand(client, "!gent <index>")
		return Plugin_Handled;
	}

	decl String:sInput[64];
	GetCmdArg(1, sInput, sizeof(sInput));

	new iEnt = StringToInt(sInput);

	if (iEnt && IsValidEntity(iEnt))
		GE_HookEnt(iEnt);

	return Plugin_Handled;
}

public OnEntityDestroyed(entity)
{
	if (!entity || !IsValidEntity(entity)) return;
	
	decl String:sClass[32];
	GetEntityClassname(entity, sClass, sizeof(sClass))
	
	if (IsMinigun(sClass) || IsVendor(entity, sClass))
		GE_HookEnt(entity, false)
}

public OnEntityCreated(entity, const String:classname[])
{
	if (!entity || !IsValidEntity(entity)) return;
	
	if (IsMinigun(classname))
		GE_HookEnt(entity);

	else if (strcmp(classname, "prop_dynamic") == 0)
		CreateTimer(0.1, GE_TimerHook, EntIndexToEntRef(entity))
}

public Action:GE_TimerHook(Handle:timer, any:entity)
{
	if ((entity = EntRefToEntIndex(entity)) == INVALID_ENT_REFERENCE || !IsVendor(entity)) return;

	GE_HookEnt(entity);
}

public Action:GE_HookStartTouch(entity, other)
{
	if (IsTank(other)) return;

	#if debug
		PrintToChatAll("I'am %d touched by %d", entity, other);
	#endif
	
	SetEntProp(entity, Prop_Send, "m_nSolidType", 0);
}

public Action:GE_HookEndTouch(entity, other)
{
	if (GetEntProp(entity, Prop_Send, "m_nSolidType") != 0) return;

	CreateTimer(1.0, GE_TimerSolid, EntIndexToEntRef(entity))
}

public Action:GE_TimerSolid(Handle:timer, any:entity)
{
	if ((entity = EntRefToEntIndex(entity)) == INVALID_ENT_REFERENCE) return;

	SetEntProp(entity, Prop_Send, "m_nSolidType", 2);
	
	#if debug
		PrintToChatAll("End touch %d", entity);
	#endif
}

GE_HookEnt(entity, bool:hook=true)
{
 	SDKUnhook(entity, SDKHook_StartTouch, GE_HookStartTouch);
	SDKUnhook(entity, SDKHook_EndTouch, GE_HookEndTouch);
	
	#if debug
		if (!hook)
			PrintToChatAll("SDKUnhook %d ent", entity);
	#endif
		
	if (hook){

		SDKHook(entity, SDKHook_Touch, GE_HookStartTouch);
		SDKHook(entity, SDKHook_EndTouch, GE_HookEndTouch);
		
		#if debug
			PrintToChatAll("SDKHook %d ent", entity);
		#endif
	}
}

bool:IsTank(tank)
{
	return tank && tank <= MaxClients && IsClientInGame(tank) && GetClientTeam(tank) == 3 && GetEntProp(tank, Prop_Send, "m_zombieClass") == 5;
}

bool:IsMinigun(const String:classname[])
{
	return strcmp(classname, "prop_mounted_machine_gun") == 0 || strcmp(classname, "prop_minigun") == 0;
}

bool:IsVendor(entity, const String:classname[] = "prop_dynamic")
{
	if (strcmp(classname, "prop_dynamic") == 0){

		decl String:sName[24];
		GetEntPropString(entity, Prop_Data, "m_iName", sName, sizeof(sName));

		return StrContains(sName, "-vendor") != -1 // Silver vendor
	}
	return false;
}