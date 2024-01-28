#pragma semicolon 1
#pragma newdecls required
 
#include <sdktools>
#include <actions>

public Plugin myinfo =
{
    name = "[L4D2] Shove Direction Fix",
    author = "BHaType"
};

public void OnActionCreated( BehaviorAction action, int owner, const char[] name )
{
	if ( strcmp(name, "InfectedShoved") == 0 )
		action.OnShoved = OnShoved;
}

public Action OnShoved( BehaviorAction action, int actor, int shover, ActionDesiredResult result )
{
	if ( IsWitch(actor) ) 
	{
		return Plugin_Continue;
	}
	
	return Plugin_Handled;
}

bool IsWitch(int entity)
{
	char classname[8];
	if (!GetEntityClassname(entity, classname, sizeof(classname)))
		return false;   

	return strcmp(classname, "witch", false) == 0;
} 