#pragma semicolon 1

new Handle:hCvarBoomerExposedTimeTolerance;
new Handle:hCvarBoomerVomitDelay;

public Boomer_OnModuleStart() {
	hCvarBoomerExposedTimeTolerance = FindConVar("boomer_exposed_time_tolerance");	
	hCvarBoomerVomitDelay = FindConVar("boomer_vomit_delay");	
	SetConVarFloat(hCvarBoomerExposedTimeTolerance, 10000.0);
	SetConVarFloat(hCvarBoomerVomitDelay, 0.1);
}

public Boomer_OnModuleEnd() {
	ResetConVar(hCvarBoomerExposedTimeTolerance);
	ResetConVar(hCvarBoomerVomitDelay);
}
