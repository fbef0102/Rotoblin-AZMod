#if defined _gamerules_included
 #endinput
#endif
#define _gamerules_included

enum RoundState {
	// initialize the game, create teams
	RoundState_Init,
	
	//Before players have joined the game. Periodically checks to see if enough players are ready
	//to start a game. Also reverts to this when there are no active players
	RoundState_Pregame,
	
	//The game is about to start, wait a bit and spawn everyone
	RoundState_StartGame,
	
	//All players are respawned, frozen in place
	RoundState_Preround,
	
	//Round is on, playing normally
	RoundState_RoundRunning,
	
	//Someone has won the round
	RoundState_TeamWin,
	
	//Noone has won, manually restart the game, reset scores
	RoundState_Restart,
	
	//Noone has won, restart the game
	RoundState_Stalemate,
	
	//Game is over, showing the scoreboard etc
	RoundState_GameOver,
	
	//Game is over, doing bonus round stuff
	RoundState_Bonus,
};

/*
 * Gets or Sets a GameRules prop.
 * size is auto-detected. paramter is only used if auto-detection fails
 * element is element number in array if prop is array
 * changeState when setting will propagate change over net to clients
 */
native GameRules_GetProp(const String:prop[], size=4, element=0);
native Float:GameRules_GetPropFloat(const String:prop[], element=0);

native GameRules_SetProp(const String:prop[], value, size=4, element=0, bool:changeState=false);
native GameRules_SetPropFloat(const String:prop[], Float:value, element=0, bool:changeState=false);

stock bool:GameRules_GetPropBool(const String:prop[], element=0)
{
	return bool:(GameRules_GetProp(prop, 1, element) & 1);
}

stock GameRules_SetPropBool(const String:prop[], bool:value, element=0, bool:changeState=false)
{
	GameRules_SetProp(prop, _:value, 1, element, changeState);
}

// For 'teamplayroundbased' games (ex. not-CS:S)
stock RoundState:GameRules_GetRoundState()
{
	return RoundState:GameRules_GetProp("m_iRoundState");
}

stock Float:GameRules_GetTimeUntilRndReset()
{
	new Float:flRestartTime = GameRules_GetPropFloat("m_flRestartRoundTime");
	if (flRestartTime == -1.0)
		return flRestartTime;
	
	return flRestartTime - GetGameTime();
}

stock Float:GameRules_GetTimeBetweenSpawns(team)
{
	return GameRules_GetPropFloat("m_TeamRespawnWaveTimes", team);
}

stock Float:GameRules_GetNextSpawnTime(team)
{
	return GameRules_GetPropFloat("m_flNextRespawnWave", team);
}

stock GameRules_SetTimeBetweenSpawns(team, Float:time)
{
	GameRules_SetPropFloat("m_TeamRespawnWaveTimes", time, team, true);
}

stock GameRules_SetNextSpawnTime(team, Float:time)
{
	GameRules_SetPropFloat("m_flNextRespawnWave", time, team, true);
}

public Extension:__ext_gamerules = 
{
	name = "GameRules Tools",
	file = "gamerules.ext",
#if defined REQUIRE_EXTENSIONS
	required = 1,
#else
	required = 0,
#endif
#if defined AUTOLOAD_EXTENSIONS
	autoload = 1,
#else
	autoload = 0,
#endif
};

#if !defined REQUIRE_EXTENSIONS
public __ext_gamerules_SetNTVOptional()
{
	MarkNativeAsOptional("GameRules_GetProp");
	MarkNativeAsOptional("GameRules_GetPropFloat");
	MarkNativeAsOptional("GameRules_SetProp");
	MarkNativeAsOptional("GameRules_SetPropFloat");
}
#endif
