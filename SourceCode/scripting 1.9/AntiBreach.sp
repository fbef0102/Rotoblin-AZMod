#include <sourcemod>

new bool:NoSpam[MAXPLAYERS + 1];

public Plugin:myinfo = 
{
	name = "No spawn near safe room door.",
	author = "Eyal282 ( FuckTheSchool ) & Harry Potter",
	description = "To prevent a player breaching safe room door with a bug, prevents him from spawning near safe room door. The minimum distance is proportionate to his speed ",
	version = "1.4",
	url = "https://forums.alliedmods.net/showthread.php?p=2520740"
}

new Handle:hAntiBreachConVar = INVALID_HANDLE;
new AntiBreachConVar;
new bool:SafeRoomDoorClosed = false;

public OnPluginStart()
{
	LoadTranslations("Roto2-AZ_mod.phrases");
	// The cvar to enable the plugin. 0 = Disabled. Other values = Enabled.
	hAntiBreachConVar = CreateConVar("l4d2_anti_breach", "1");
	
	// To prevent waste of resources, hook the change of the console variable AntiBreach
	HookConVarChange(hAntiBreachConVar, AntiBreachConVarChange);
	
	// Save the current value of l4d2_anti_breach in a variable. Main reason is to avoid wasting resources.
	AntiBreachConVar = GetConVarInt(hAntiBreachConVar);
	
	HookEvent("round_start", Event_RoundStart, EventHookMode_Post);
	HookEvent("door_open", Event_DoorOpen, EventHookMode_Post);
	HookEvent("door_close", Event_DoorClose, EventHookMode_Post);
}

public Action:Event_RoundStart (Handle:event, const String:name[], bool:dontBroadcast)
{
	// We mark the safe room door as open
	SafeRoomDoorClosed = false;
	
	return Plugin_Continue;
}

public Action:Event_DoorOpen (Handle:event, const String:name[], bool:dontBroadcast)
{
	// if the door was a checkpoint door ...
	new bool:checkpointdoor  = GetEventBool(event, "checkpoint");
	
	if (checkpointdoor == true)
	{
		SafeRoomDoorClosed = false;
	}
	
	return Plugin_Continue;
}

public Action:Event_DoorClose(Handle:event, const String:name[], bool:dontBroadcast)
{
	// if the door was a checkpoint door ...
	new bool:checkpointdoor  = GetEventBool(event, "checkpoint");
	
	if (checkpointdoor == true)
	{
		SafeRoomDoorClosed = true;
	}
	
	return Plugin_Continue;
}

public OnClientPutInServer(client)
{
	NoSpam[client] = false;
}

public AntiBreachConVarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	AntiBreachConVar = GetConVarInt(convar);
}

public Action:OnPlayerRunCmd(SInfected, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon, &subtype, &cmdnum, &tickcount, &seed, mouse[2])
{
	// Player is not attacking.
	if(!(buttons & IN_ATTACK) || !SafeRoomDoorClosed)
		return Plugin_Continue;
	
	// Cvar is disabled, aborting.
	if(AntiBreachConVar == 0)
		return Plugin_Continue;
	
	// Player is either a bot, not infected or not a ghost.
	else if(GetClientTeam(SInfected) != 3 || IsFakeClient(SInfected) || GetEntProp(SInfected, Prop_Send, "m_isGhost") != 1)
		return Plugin_Continue;

	// Being a ghost, the player can not spawn ( seen / close / blocked etc... )
	else if(GetEntProp(SInfected, Prop_Send, "m_ghostSpawnState") != 0)
		return Plugin_Continue;
	
	new EntityCount = GetEntityCount();

	for (new Door = MaxClients; Door < EntityCount; Door++) // https://forums.alliedmods.net/showpost.php?p=2502446&postcount=2
	{
		if (IsValidEntity(Door) && IsValidEdict(Door))
		{
			new String:Classname[100];

			GetEdictClassname(Door, Classname, sizeof(Classname));
			
			if(strcmp(Classname, "prop_door_rotating_checkpoint") != 0 ) // Found the classname from l4d_loading: https://forums.alliedmods.net/showthread.php?p=836849
				continue;
			
			new Float:SInfectedOrigin[3], Float:DoorOrigin[3], Float:SInfectedVelocity[3];
			GetEntPropVector(SInfected, Prop_Send, "m_vecOrigin", SInfectedOrigin);
			GetEntPropVector(Door, Prop_Send, "m_vecOrigin", DoorOrigin);
			GetEntPropVector(SInfected, Prop_Data, "m_vecVelocity", SInfectedVelocity);
			new Float:Speed = GetVectorLength(SInfectedVelocity);
			new Float:Distance = GetVectorDistance(SInfectedOrigin, DoorOrigin);
			
			// Player has too much speed vs distance from door.
			
			if(Distance < Speed / 1.5 && Distance < 100.0) // Tested and the 1.5 division will not assist the use of the bug.
			{
				if(!NoSpam[SInfected])
				{
					PrintToChat(SInfected, "\x01[\x05TS\x01] %T","You can't spawn near safe room doors.",SInfected);
					NoSpam[SInfected] = true;
					CreateTimer(2.5, AllowMessageAgain, GetClientUserId(SInfected));
				}
				buttons &= ~IN_ATTACK;
				return Plugin_Continue;
			}
		}
	}
	
	return Plugin_Continue;
}

public Action: AllowMessageAgain(Handle Timer, int UserId)
{
	new SInfected = GetClientOfUserId(UserId);
	
	if(!IsClientInGame(SInfected))
		return Plugin_Continue;
	
	NoSpam[SInfected] = false;
	
	return Plugin_Continue;
}