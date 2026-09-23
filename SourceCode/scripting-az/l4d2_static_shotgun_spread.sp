#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <l4d_pellet_spread_customizer>

// You can use the visualise_impacts.smx plugin to test the resulting spread.
// It will render small purple boxes where the server-side pellets land.

ConVar g_hCvarRing1Bullets = null;
ConVar g_hCvarRing1Factor = null;
ConVar g_hCvarCenterPellet = null;

public Plugin myinfo =
{
	name = "L4D2 Static Shotgun Spread",
	author = "Jahze, Visor, A1m`, Rena, Forgetest",
	version = "2.0",
	description = "Apply circular pattern to shotgun spreads",
	url = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

public void OnPluginStart()
{
	g_hCvarRing1Bullets = CreateConVar("sgspread_ring1_bullets", "5", "Number of bullets for the first ring, the remaining bullets will be in the second ring.");
	g_hCvarRing1Factor = CreateConVar("sgspread_ring1_factor", "2", "Determines how far or closer the bullets will be from the center for the first ring.");
	g_hCvarCenterPellet = CreateConVar("sgspread_center_pellet", "1", "Center pellet: 0 - off, 1 - on.", _, true, 0.0, true, 1.0);
}

public Action L4D_OnPelletFirstBullet(int weapon)
{
	return g_hCvarCenterPellet.BoolValue ? Plugin_Continue : Plugin_Handled;
}

public Action L4D_OnPelletSpread(int weapon, float &spread, int nPellet, int nMaxPellets)
{
	if (nPellet <= g_hCvarRing1Bullets.IntValue)
	{
		spread = spread / g_hCvarRing1Factor.FloatValue;
	}

	return Plugin_Changed;
}

public Action L4D_OnPelletSpreadDir(int weapon, float &angle, int nPellet, int nMaxPellets)
{
	int numSlices = 0;
	if (nPellet <= g_hCvarRing1Bullets.IntValue)
	{
		numSlices = g_hCvarRing1Bullets.IntValue;
	}
	else
	{
		numSlices = nMaxPellets - g_hCvarRing1Bullets.IntValue;
	}
	
	angle = 180.0 / numSlices * ((nPellet - 1) % numSlices);
	return Plugin_Changed;
}
