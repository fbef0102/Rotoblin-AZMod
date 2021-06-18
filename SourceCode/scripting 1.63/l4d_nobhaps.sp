#include <sourcemod>
#include <sdktools>
#undef REQUIRE_PLUGIN
#include <l4d_lib>

public Plugin:myinfo =
{
	name = "[L4D] Simple Anti-Bunnyhop",
	author = "CanadaRox, ProdigySim, blodia, raziEiL [disawar1]",
	description = "Stops bunnyhops by restricting speed when a player lands on the ground to their MaxSpeed",
	version = "0.2",
	url = "http://code.google.com/p/rotoblin2/" // L4D2 verison https://bitbucket.org/CanadaRox/random-sourcemod-stuff/
};

#define DEBUG 0

//static Handle:g_hSIExcept;
static Handle:g_hEnable, bool:g_bCvarEnable;
//static g_iSIExpectFlags;

public OnPluginStart()
{
	g_hEnable				=		CreateConVar("simple_antibhop_enable", "1", "Enable or disable the Simple Anti-Bhop plugin", FCVAR_PLUGIN|FCVAR_NOTIFY);
	/*
		g_hSIExcept			=		CreateConVar("bhop_except_si_flags", "110",
		"Bitfield for exempting SI in Anti-Bhop functionality. From least significant: 2=Smoker, 4=Boomer, 8=Hunter, 32=Tank, 64=Survivors, 110=All", FCVAR_PLUGIN|FCVAR_NOTIFY);
	*/
	HookConVarChange(g_hEnable,		OnCvarChange_Enable);
	//HookConVarChange(g_hSIExcept,	OnCvarChange_SIExcept);
	BH_GetCvars();
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if (!g_bCvarEnable) return Plugin_Continue;

	static Float:LeftGroundMaxSpeed[MAXPLAYERS + 1];
	
	//if (IsPlayerAlive(client) && (((team = GetClientTeam(client) == 2) && g_iSIExpectFlags & 64) || (team == 3 && g_iSIExpectFlags & (1 << GetPlayerClass(client)))))
	if(IsPlayerAlive(client))
	{
		if (GetEntityFlags(client) & FL_ONGROUND)
		{
			if (LeftGroundMaxSpeed[client] != -1.0)
			{
				decl Float:CurVelVec[3];
				GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", CurVelVec);

				if (GetVectorLength(CurVelVec) > LeftGroundMaxSpeed[client])
				{
					#if DEBUG
					PrintToChat(client, "Speed: %f {%.02f, %.02f, %.02f}, MaxSpeed: %f", GetVectorLength(CurVelVec), CurVelVec[0], CurVelVec[1], CurVelVec[2], LeftGroundMaxSpeed[client]);
					#endif
					NormalizeVector(CurVelVec, CurVelVec);
					ScaleVector(CurVelVec, LeftGroundMaxSpeed[client]);
					TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, CurVelVec);
				}
				LeftGroundMaxSpeed[client] = -1.0;
			}
		}
		else if(LeftGroundMaxSpeed[client] == -1.0)
		{
			LeftGroundMaxSpeed[client] = GetEntPropFloat(client, Prop_Data, "m_flMaxspeed");
		}
	}

	return Plugin_Continue;
}

public OnCvarChange_Enable(Handle:convar_hndl, const String:oldValue[], const String:newValue[])
{
	if (!StrEqual(oldValue, newValue))
		g_bCvarEnable = GetConVarBool(g_hEnable);

}
/*
public OnCvarChange_SIExcept(Handle:convar_hndl, const String:oldValue[], const String:newValue[])
{
	if (!StrEqual(oldValue, newValue))
		g_iSIExpectFlags = GetConVarInt(g_hSIExcept);
}
*/

BH_GetCvars()
{
	g_bCvarEnable = GetConVarBool(g_hEnable);
	//g_iSIExpectFlags = GetConVarInt(g_hSIExcept);
}