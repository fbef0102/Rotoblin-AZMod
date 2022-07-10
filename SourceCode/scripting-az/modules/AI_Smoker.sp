#pragma semicolon 1
#define SMOKER_TONGUE_DELAY 0.1

new Handle:hCvarTongueDelay;
new Handle:hCvarSmokerHealth;
new Handle:hCvarChokeDamageInterrupt;

public Smoker_OnModuleStart() {
	 // Smoker health
    hCvarSmokerHealth = FindConVar("z_gas_health");
    HookConVarChange(hCvarSmokerHealth, OnSmokerHealthChanged); 
    
    // Damage required to kill a smoker that is pulling someone
    hCvarChokeDamageInterrupt = FindConVar("tongue_break_from_damage_amount"); 
    SetConVarInt(hCvarChokeDamageInterrupt, GetConVarInt(hCvarSmokerHealth)); // default 50
    HookConVarChange(hCvarChokeDamageInterrupt, OnTongueCvarChange);    
    // Delay before smoker shoots its tongue
    hCvarTongueDelay = FindConVar("smoker_tongue_delay"); 
    SetConVarFloat(hCvarTongueDelay, SMOKER_TONGUE_DELAY); // default 1.5
    HookConVarChange(hCvarTongueDelay, OnTongueCvarChange);
}

public Smoker_OnModuleEnd() {
	ResetConVar(hCvarChokeDamageInterrupt);
	ResetConVar(hCvarTongueDelay);
}

// Game tries to reset these cvars
public void OnTongueCvarChange(ConVar convar, const char[] oldValue, const char[] newValue) {
	SetConVarFloat(hCvarTongueDelay, SMOKER_TONGUE_DELAY);	
	SetConVarInt(hCvarChokeDamageInterrupt, GetConVarInt(hCvarSmokerHealth));
}

// Update choke damage interrupt to match smoker max health
public void OnSmokerHealthChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	SetConVarInt(hCvarChokeDamageInterrupt, GetConVarInt(hCvarSmokerHealth));
}