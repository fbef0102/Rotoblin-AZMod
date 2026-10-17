#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <multicolors>
#include <l4d_lib>

#define HUD_5V5_DRAW_INTERVAL   1.0
#define CLAMP(%0,%1,%2) (((%0) > (%2)) ? (%2) : (((%0) < (%1)) ? (%1) : (%0)))
#define MAX(%0,%1) (((%0) > (%1)) ? (%0) : (%1))
#define MIN(%0,%1) (((%0) < (%1)) ? (%0) : (%1))

#define ZOMBIECLASS_NAME(%0) (L4DSI_Names[(%0)])

enum L4DGamemode
{
	L4DGamemode_None,
	L4DGamemode_Versus,
};

enum L4DSI 
{
	ZC_None,
	ZC_Smoker,
	ZC_Boomer,
	ZC_Hunter,
	ZC_Witch,
	ZC_Tank
};

static const String:L4DSI_Names[][] = 
{
	"No",
	"S",
	"B",
	"H",
	"W",
	"T"
};

new Handle:survivor_limit;
new Handle:z_max_player_zombies;

new bool:b5v5HudActive[MAXPLAYERS + 1];
new passCount;
static bool:g_bLeftStartRoom;

native IsInPause();
native IsInReady();

public Plugin:myinfo = 
{
	name = "L4D1 versus 5v5 Hud",
	author = "Harry Potter",
	description = "Provides 5v5 HUDs for infected",
	version = "1.0h-2026/10/16",
	url = "https://github.com/Attano/smplugins"
};

public OnPluginStart() 
{
	LoadTranslations("Roto2-AZ_mod.phrases");
	survivor_limit = FindConVar("survivor_limit");
	z_max_player_zombies = FindConVar("z_max_player_zombies");

	RegConsoleCmd("sm_5v5hud", Toggle5v5HudCmd);
	
	HookEvent("player_left_checkpoint", Event_player_left_checkpoint, EventHookMode_Pre);
	HookEvent("round_start", RoundStartEvent, EventHookMode_PostNoCopy);//每回合開始就發生的event
	HookEvent("tank_frustrated", OnTankFrustrated, EventHookMode_Post);
	HookEvent("entity_killed",		PD_ev_EntityKilled);
	
	for (new i = 1; i <= MaxClients; i++) 
	{
		b5v5HudActive[i] = true;
	}
		
	CreateTimer(HUD_5V5_DRAW_INTERVAL, HudDrawTimer, _, TIMER_REPEAT);
}

public OnClientDisconnect(Client)
{
	if (IsTank(Client))
	{
		CreateTimer(1.5, FindAnyTank, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public RoundStartEvent(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_bLeftStartRoom = false;
	passCount = 1;
}
public OnMapStart()
{
	g_bLeftStartRoom = false;
	passCount = 1;
}

public Event_player_left_checkpoint(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(IsInReady()||g_bLeftStartRoom) return;
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(client && IsClientInGame(client) && IsSurvivor(client))
	{
		decl String:Info[50];
		g_bLeftStartRoom = true;
		for (new i = 1; i <= MaxClients; i++) 
			if (IsInfected(i)&& !IsFakeClient(i) && b5v5HudActive[i])
			{
				Format(Info, sizeof(Info), "%T", (b5v5HudActive[i] ? "Off" : "On"),i);
				CPrintToChat(i, "%T","l4d_versus_5v5_hud1",i,Info,"!5v5hud");
			}
	}	
}

public Action:Toggle5v5HudCmd(client, args) 
{
	if(client == 0 || IsFakeClient(client)) return Plugin_Continue;

	if(!IsInfected(client))
		return;
		
	b5v5HudActive[client] = !b5v5HudActive[client];
	
	decl String:Info[50];
	Format(Info, sizeof(Info), "%T", (b5v5HudActive[client] ? "On" : "Off"),client);
	
	CPrintToChat(client, "%T","l4d_versus_5v5_hud2",client, Info);
}

public Action:HudDrawTimer(Handle:hTimer) 
{
	if(IsInReady()||IsInPause()||!g_bLeftStartRoom) return Plugin_Continue;
	
	new Handle:h5v5Hud = CreatePanel();

	//FillHeaderInfo(h5v5Hud);
	FillSurvivorInfo(h5v5Hud);
	FillInfectedInfo(h5v5Hud);
	FillTankInfo(h5v5Hud);

	for (new i = 1; i <= MaxClients; i++) 
	{
		if (!b5v5HudActive[i] || !IsInfected(i) || IsFakeClient(i) || !g_bLeftStartRoom)
			continue;

		switch (GetClientMenu(i))
		{
			case MenuSource_External, MenuSource_Normal:
			{ 
				continue;
			}
		}
			
		SendPanelToClient(h5v5Hud, i, Dummy5v5HudHandler, 1);
	}
	CloseHandle(h5v5Hud);
	return Plugin_Continue;
}

public Dummy5v5HudHandler(Handle:hMenu, MenuAction:action, param1, param2) {}

FillSurvivorInfo(Handle:h5v5Hud) 
{
	decl String:info[512];
	decl String:name[MAX_NAME_LENGTH];

	DrawPanelText(h5v5Hud, "->1. Survivors");

	new survivorCount;
	for (new client = 1; client <= MaxClients && survivorCount < GetConVarInt(survivor_limit); client++) 
	{
		if (!IsSurvivor(client))
			continue;

		GetClientFixedName(client, name, sizeof(name));
		if (!IsPlayerAlive(client))
		{
			Format(info, sizeof(info), "Dead: %s", name);
		}
		else
		{
			new Ent = GetPlayerWeaponSlot(client, 4);
			
			if (IsSurvivorHanging(client))//Hanging
			{
				Format(info, sizeof(info), "%i <H>%s: %s",GetSurvivorHealth(client),(Ent != -1)?"(P)":"", name);
			}
			else if (IsIncapacitated(client))//Incapped
			{
				Format(info, sizeof(info), "%i <I>%s: %s",GetSurvivorHealth(client),(Ent != -1)?"(P)":"",name);
			}
			else
			{
				new health = GetSurvivorHealth(client);
				new TH = GetSurvivorTemporaryHealth(client);
				if (TH == 0)
				{
					Format(info, sizeof(info), "%i%s: %s",health,(Ent != -1)?" (P)":"",name);
				}
				else
				{
					Format(info, sizeof(info), "%i+%i%s: %s", health, TH,(Ent != -1)?" (P)":"",name);
				}
			}
		}

		survivorCount++;
		DrawPanelText(h5v5Hud, info);
	}
}

FillInfectedInfo(Handle:h5v5Hud) 
{
	DrawPanelText(h5v5Hud, " ");
	DrawPanelText(h5v5Hud, "->2. Infected");

	decl String:info[512];
	decl String:buffer[32];
	decl String:name[MAX_NAME_LENGTH];

	new infectedCount;
	for (new client = 1; client <= MaxClients && infectedCount < GetConVarInt(z_max_player_zombies); client++) 
	{
		if (!IsInfected(client))
			continue;

		GetClientFixedName(client, name, sizeof(name));
		if (!IsPlayerAlive(client)) 
		{
			int timeLeft = RoundToFloor(L4D_GetPlayerSpawnTime(client));
			if (timeLeft < 0)
			{
				Format(info, sizeof(info), "Dead: %s", name);
			}
			else
			{
				Format(buffer, sizeof(buffer), "%is", timeLeft);
				Format(info, sizeof(info), "Dead (%s): %s", (timeLeft > 0 ? buffer : "Sp."), name);
			}
		}
		else 
		{
			new L4DSI:zClass = GetInfectedClass(client);
			if (zClass == ZC_Tank)
				continue;

			if (IsInfectedGhost(client))
			{
				// TO-DO: Handle a case of respawning chipped SI, show the ghost's health
				Format(info, sizeof(info), "%s (Gh): %s", ZOMBIECLASS_NAME(zClass), name);
			}
			else if (GetEntityFlags(client) & FL_ONFIRE)//on Fire
			{
				Format(info, sizeof(info), "%s (%i)<F>: %s", ZOMBIECLASS_NAME(zClass), GetClientHealth(client), name);
			}
			else
			{
				Format(info, sizeof(info), "%s (%i): %s",ZOMBIECLASS_NAME(zClass), GetClientHealth(client), name);
			}
		}

		infectedCount++;
		DrawPanelText(h5v5Hud, info);
	}
	
	if (!infectedCount)
	{
		DrawPanelText(h5v5Hud, "No SI.");
	}
}
public OnTankFrustrated(Handle:event, const String:name[], bool:dontBroadcast)
{
	new tank = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsClientInGame(tank)) return;
	passCount++;
}

bool:FillTankInfo(Handle:h5v5Hud, bool:bTankHUD = false)
{
	new tank = FindTank();
	if (tank == -1)
		return false;

	decl String:info[512];
	decl String:name[MAX_NAME_LENGTH];

	if (bTankHUD)
	{
		Format(info, sizeof(info), "%s :: Tank HUD", info);
		DrawPanelText(h5v5Hud, info);
		DrawPanelText(h5v5Hud, "___________________");
	}
	else
	{
		DrawPanelText(h5v5Hud, " ");
		DrawPanelText(h5v5Hud, "->3. Tank");
	}

	// Draw owner & pass counter
	switch (passCount)
	{
		case 0: Format(info, sizeof(info), "native");
		case 1: Format(info, sizeof(info), "%ist", passCount);
		case 2: Format(info, sizeof(info), "%ind", passCount);
		case 3: Format(info, sizeof(info), "%ird", passCount);
		default: Format(info, sizeof(info), "%ith", passCount);
	}

	if (!IsFakeClient(tank))
	{
		GetClientFixedName(tank, name, sizeof(name));
		Format(info, sizeof(info), "Control : %s (%s)", name, info);
	}
	else
	{
		Format(info, sizeof(info), "Control : AI (%s)", info);
	}
	DrawPanelText(h5v5Hud, info);

	// Draw health
	new health = GetClientHealth(tank);
	if (health <= 0 || IsIncapacitated(tank) || !IsPlayerAlive(tank))
	{
		info = "Health  : Dead";
	}
	else
	{
		new healthPercent = RoundFloat(100.0 * health / (GetConVarFloat(FindConVar("z_tank_health"))));
		Format(info, sizeof(info), "Health  : %i / %i%%", health, ((healthPercent < 1) ? 1 : healthPercent));
	}
	DrawPanelText(h5v5Hud, info);

	// Draw frustration
	if (!IsFakeClient(tank))
	{
		Format(info, sizeof(info), "Frustr.  : %d%%", GetTankFrustration(tank));
		DrawPanelText(h5v5Hud, info);
		Format(info, sizeof(info), "Ping/Lerp  : %dms [%.1f]", 
									GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iPing", _, tank) ,
									GetLerpTime(tank) * 1000.0);
		DrawPanelText(h5v5Hud, info);
	}

	// Draw fire status
	if (GetEntityFlags(tank) & FL_ONFIRE)
	{
		new timeleft = RoundToCeil(health / 80.0);
		Format(info, sizeof(info), "On Fire : %is", timeleft);
		DrawPanelText(h5v5Hud, info);
	}

	return true;
}

/* Stocks */

GetClientFixedName(client, String:name[], length) 
{
	GetClientName(client, name, length);

	if (name[0] == '[') 
	{
		decl String:temp[MAX_NAME_LENGTH];
		strcopy(temp, sizeof(temp), name);
		temp[sizeof(temp)-2] = 0;
		strcopy(name[1], length-1, temp);
		name[0] = ' ';
	}

	if (strlen(name) > 25) 
	{
		name[22] = name[23] = name[24] = '.';
		name[25] = 0;
	}
}
/*
bool:IsSpectator(client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 1;
}*/


bool:IsInfectedGhost(client) 
{
	return bool:GetEntProp(client, Prop_Send, "m_isGhost");
}

L4DSI:GetInfectedClass(client)
{
	return IsInfected(client) ? (L4DSI:GetEntProp(client, Prop_Send, "m_zombieClass")) : ZC_None;
}

FindTank() 
{
	for (new i = 1; i <= MaxClients; i++) 
	{
		if (IsInfected(i) && GetInfectedClass(i) == ZC_Tank && IsPlayerAlive(i))
			return i;
	}

	return -1;
}

GetTankFrustration(tank)
{
	return (100 - GetEntProp(tank, Prop_Send, "m_frustration"));
}

bool:IsSurvivorHanging(client)
{
	return bool:(GetEntProp(client, Prop_Send, "m_isHangingFromLedge") | GetEntProp(client, Prop_Send, "m_isFallingFromLedge"));
}


GetSurvivorTemporaryHealth(client)
{
	new temphp = RoundToCeil(GetEntPropFloat(client, Prop_Send, "m_healthBuffer") - ((GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * GetConVarFloat(FindConVar("pain_pills_decay_rate")))) - 1;
	return (temphp > 0 ? temphp : 0);
}

GetSurvivorHealth(client)
{
	return GetEntProp(client, Prop_Send, "m_iHealth");
}

public Action:PD_ev_EntityKilled(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (IsPlayerTank((GetEventInt(event, "entindex_killed"))))
	{
		CreateTimer(1.5, FindAnyTank, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action:FindAnyTank(Handle:timer)
{
	if(!IsTankInGame()){
		passCount = 1;
	}
}

IsTankInGame(exclude = 0)
{
	for (new i = 1; i <= MaxClients; i++)
		if (exclude != i && IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerTank(i) && IsPlayerAlive(i) && !IsIncapacitated(i))
			return i;

	return 0;
}

/* Stocks */
Float:GetLerpTime(client)
{
	new Handle:cVarMinUpdateRate = FindConVar("sv_minupdaterate");
	new Handle:cVarMaxUpdateRate = FindConVar("sv_maxupdaterate");
	new Handle:cVarMinInterpRatio = FindConVar("sv_client_min_interp_ratio");
	new Handle:cVarMaxInterpRatio = FindConVar("sv_client_max_interp_ratio");

	decl String:buffer[64];
	
	if (!GetClientInfo(client, "cl_updaterate", buffer, sizeof(buffer))) buffer = "";
	new updateRate = StringToInt(buffer);
	updateRate = RoundFloat(CLAMP(float(updateRate), GetConVarFloat(cVarMinUpdateRate), GetConVarFloat(cVarMaxUpdateRate)));
	
	if (!GetClientInfo(client, "cl_interp_ratio", buffer, sizeof(buffer))) buffer = "";
	new Float:flLerpRatio = StringToFloat(buffer);
	
	if (!GetClientInfo(client, "cl_interp", buffer, sizeof(buffer))) buffer = "";
	new Float:flLerpAmount = StringToFloat(buffer);	
	
	if (cVarMinInterpRatio != INVALID_HANDLE && cVarMaxInterpRatio != INVALID_HANDLE && GetConVarFloat(cVarMinInterpRatio) != -1.0 ) {
		flLerpRatio = CLAMP(flLerpRatio, GetConVarFloat(cVarMinInterpRatio), GetConVarFloat(cVarMaxInterpRatio) );
	}
	
	return MAX(flLerpAmount, flLerpRatio / updateRate);
}