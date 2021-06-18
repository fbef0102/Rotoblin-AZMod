#pragma semicolon 1
#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.4"

#define TEST_DEBUG			0
#define TEST_DEBUG_LOG		1

#define DEFAULT_FLAGS FCVAR_PLUGIN|FCVAR_NOTIFY

static const	SMG_OFFSET_IAMMO				= 20;
static const	PUMPSHOTGUN_OFFSET_IAMMO		= 28;

static Handle:SMGAmmoCVAR = INVALID_HANDLE;
static Handle:ShotgunAmmoCVAR = INVALID_HANDLE;

//static bool:buttondelay[MAXPLAYERS+1];

public Plugin:myinfo = 
{
	name = "L4D SMG/PUMPSHOTGUN ammo set",
	author = "Harry Potter",
	description = " custom SMG/PUMPSHOTGUN ammo capacity ",
	version = PLUGIN_VERSION,
	url = ""
}

public OnPluginStart()
{
	// Requires Left 4 Dead 1
	decl String:game_name[64];
	GetGameFolderName(game_name, sizeof(game_name));
	if (!StrEqual(game_name, "left4dead", false))
		SetFailState("Plugin supports Left 4 Dead 1 only.");
	
	CreateConVar("l4d_guncontrol_version", PLUGIN_VERSION, " Version of L4D Gun Control on this server ", DEFAULT_FLAGS|FCVAR_SPONLY|FCVAR_DONTRECORD);
	
	ShotgunAmmoCVAR = CreateConVar("l4d2_guncontrol_shotgunammo", "100", " How much Ammo for Shotgun and Chrome Shotgun ", DEFAULT_FLAGS);
	SMGAmmoCVAR = CreateConVar("l4d_guncontrol_smgammo", "800", " How much Ammo for SMG gun", DEFAULT_FLAGS);

	HookConVarChange(SMGAmmoCVAR, CVARChanged);
	HookConVarChange(ShotgunAmmoCVAR, CVARChanged);
	
	RegConsoleCmd("give_ammo", Cmd_GiveAmmo, "Gives the Player you look at your current ammo clip");

	
	UpdateConVars();
}

public OnMapStart()
{
	UpdateConVars();
}

public CVARChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	UpdateConVars();
}

UpdateConVars()
{
	SetConVarInt(FindConVar("ammo_smg_max"), GetConVarInt(SMGAmmoCVAR));
	SetConVarInt(FindConVar("ammo_buckshot_max"), GetConVarInt(ShotgunAmmoCVAR));
}
/*
public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if (buttons & IN_USE && !buttondelay[client])
	{
		CreateTimer(2.0, ResetDelay, client); //add a button delay to prevent multiple firings
		
		new gun = GetClientAimTarget(client, false); //get the entity player is looking at
		if (gun < 32) return Plugin_Continue; //below 32 is a player or null, invalid
		if (!IsValidEdict(gun)) return Plugin_Continue; //lets check for validity anyhow
		
		decl String:ent_name[64];
		GetEdictClassname(gun, ent_name, sizeof(ent_name)); //get the entities name
		
		new oldgun = GetPlayerWeaponSlot(client, 0); //get the players primary weapon
		if (!IsValidEdict(oldgun)) return Plugin_Continue; //check for validity
		
		decl String:currentgunname[64];
		GetEdictClassname(oldgun, currentgunname, sizeof(currentgunname)); //get the primary weapon name
		
		
		if (!StrEqual(ent_name, currentgunname)) return Plugin_Continue; //if entity and primary weapon dont have the same name theyre incompatible
		
		new iAmmoOffset = FindDataMapOffs(client, "m_iAmmo"); //get the iAmmo Offset
		decl offsettoadd, maxammo;
		
		if (StrEqual(ent_name, "weapon_smg", false))
		{ //case: SMGS
			offsettoadd = SMG_OFFSET_IAMMO; //gun type specific offset
			maxammo = GetConVarInt(SMGAmmoCVAR); //get max ammo as set
		}
		else if (StrEqual(ent_name, "weapon_pumpshotgun", false) || StrEqual(ent_name, "weapon_shotgun_chrome", false))
		{ //case: Pump Shotguns
			offsettoadd = PUMPSHOTGUN_OFFSET_IAMMO; //gun type specific offset
			maxammo = GetConVarInt(ShotgunAmmoCVAR); //get max ammo as set
		}		
		else
		{ //case: no gun this plugin recognizes
			return Plugin_Continue;
		}
		
		new currentammo = GetEntData(client, (iAmmoOffset + offsettoadd)); //get current ammo
		
		if (currentammo >= maxammo) return Plugin_Continue; //if youre full, do nothing
		
		new foundgunammo = GetEntProp(gun, Prop_Send, "m_iExtraPrimaryAmmo", 4); //get the lying around guns contained ammo
		if (!foundgunammo) //if its zero
		{
			//PrintHintText(client, "That gun is empty"); //the gun is empty, bug out
			return Plugin_Continue;
		}
		
		if ((currentammo + foundgunammo) <= maxammo) //if contained ammo is less than youd need to be full
		{
			SetEntData(client, (iAmmoOffset + offsettoadd), (currentammo + foundgunammo), 4, true); //add bullets to your supply
			SetEntProp(gun, Prop_Send, "m_iExtraPrimaryAmmo",0 ,4); //empty the gun
			//PrintHintText(client, "You scavenged %i bullets off that gun", foundgunammo); //imform the client
		}
		else //if contained ammo exceeds your needs
		{
			new neededammo = (maxammo - currentammo); //find out how much exactly you need
			SetEntData(client, (iAmmoOffset + offsettoadd), maxammo, 4, true); //fill you up
			SetEntProp(gun, Prop_Send, "m_iExtraPrimaryAmmo",(foundgunammo - neededammo) ,4); //take needed ammo from gun
			//PrintHintText(client, "You scavenged %i bullets off that gun", neededammo); //inform the client
		}
	}
	
	return Plugin_Continue;
}

public Action:ResetDelay(Handle:timer, any:client)
{
	buttondelay[client] = false;
}
*/
public Action:Cmd_GiveAmmo(client, args)
{
	if (!client) client=1;
	new target = GetClientAimTarget(client, true); //get the player our client is looking at
	if (!target || !IsClientInGame(target)) return Plugin_Handled; //invalid
	
	new targetgun = GetPlayerWeaponSlot(target, 0); //get the players primary weapon
	if (!IsValidEdict(targetgun)) return Plugin_Handled; //check for validity
	
	decl String:targetgunname[64];
	GetEdictClassname(targetgun, targetgunname, sizeof(targetgunname));
	
	new oldgun = GetPlayerWeaponSlot(client, 0); //get the players primary weapon
	if (!IsValidEdict(oldgun)) return Plugin_Handled; //check for validity
	
	decl String:currentgunname[64];
	GetEdictClassname(oldgun, currentgunname, sizeof(currentgunname)); //get the primary weapon name
	
	if (!StrEqual(targetgunname, currentgunname))
	{
		PrintToChat(client, "\x01You can only give \x04%N\x01 ammo if you got \x04the same weapon", target);
		return Plugin_Handled; //if targets and your weapon dont have the same name theyre incompatible
	}
	
	if (GetEntProp(oldgun, Prop_Send, "m_iClip1", 1)<2) 
	{
		PrintToChat(client, "\x01You can only give \x04%N\x01 ammo if you got \x04a clip with bullets in your gun", target);
		return Plugin_Handled;
	}
	
	new iAmmoOffset = FindDataMapOffs(target, "m_iAmmo"); //get the iAmmo Offset
	decl offsettoadd, maxammo;
	
	if (StrEqual(currentgunname, "weapon_smg", false))
	{ //case: SMGS
		offsettoadd = SMG_OFFSET_IAMMO; //gun type specific offset
		maxammo = GetConVarInt(SMGAmmoCVAR); //get max ammo as set
	}
	else if (StrEqual(currentgunname, "weapon_pumpshotgun", false) || StrEqual(currentgunname, "weapon_shotgun_chrome", false))
	{ //case: Pump Shotguns
		offsettoadd = PUMPSHOTGUN_OFFSET_IAMMO; //gun type specific offset
		maxammo = GetConVarInt(ShotgunAmmoCVAR); //get max ammo as set
	}	
	else
	{ //case: no gun this plugin recognizes
		PrintToChat(client, "Error: WTF what gun is that");
		return Plugin_Handled;
	}
	
	new currentammo = GetEntData(target, (iAmmoOffset + offsettoadd)); //get targets current ammo
	
	if (currentammo >= maxammo) //if hes full, do nothing
	{
		PrintToChat(client, "\x01That guy \x04has full\x01 ammo");
		return Plugin_Handled;
	}
	
	new donateammo = GetEntProp(oldgun, Prop_Send, "m_iClip1", 1)-1; //you give your current gun clip minus the bullet thats in the barrel
	
	if ((currentammo + donateammo) <= maxammo) //if clips ammo is less than hed need to be full
	{
		SetEntData(target, (iAmmoOffset + offsettoadd), (currentammo + donateammo), 4, true); //add bullets to his supply
		SetEntProp(oldgun, Prop_Send, "m_iClip1",1 ,1); //empty your gun
		PrintToChat(client, "\x01You gave your clip of \x04%i bullets\x01 to \x04%N\x01", donateammo, target);
	}
	else //if given ammo exceeds his needs
	{
		new neededammo = (maxammo - currentammo); //find out how much exactly he needs
		SetEntData(target, (iAmmoOffset + offsettoadd), maxammo, 4, true); //fill him up
		SetEntProp(oldgun, Prop_Send, "m_iClip1",(donateammo - neededammo) ,1); //take needed ammo from your clip
		PrintToChat(client, "\x01You gave \x04%i bullets\x01 off your clip to \x04%N\x01", neededammo, target);
	}	
	return Plugin_Handled;
}

stock DebugPrintToAll(const String:format[], any:...)
{
	#if (TEST_DEBUG || TEST_DEBUG_LOG)
	decl String:buffer[256];
	
	VFormat(buffer, sizeof(buffer), format, 2);
	
	#if TEST_DEBUG
	PrintToChatAll("[GUNCONTROL] %s", buffer);
	PrintToConsole(0, "[GUNCONTROL] %s", buffer);
	#endif
	
	LogMessage("%s", buffer);
	#else
	//suppress "format" never used warning
	if(format[0])
		return;
	else
		return;
	#endif
}