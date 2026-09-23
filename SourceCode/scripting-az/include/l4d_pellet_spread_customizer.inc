#if defined _l4d_pellet_spread_customizer_included_
	#endinput
#endif
#define _l4d_pellet_spread_customizer_included_

forward Action L4D_OnPelletFirstBullet(int weapon);
forward Action L4D_OnPelletSpread(int weapon, float &spread, int nPellet, int nMaxPellets);
forward Action L4D_OnPelletSpreadDir(int weapon, float &angle, int nPellet, int nMaxPellets);

public SharedPlugin __pl_l4d_pellet_spread_customizer = 
{
	name = "l4d_pellet_spread_customizer",
	file = "l4d_pellet_spread_customizer.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};
