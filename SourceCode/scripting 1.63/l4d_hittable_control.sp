#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

new bool:	bIgnoreOverkill		[MAXPLAYERS + 1];	//for hittable hits

//cvars
new Handle: hLogStandingDamage			= INVALID_HANDLE;
new Handle: hCarStandingDamage			= INVALID_HANDLE;
new Handle: hBumperCarStandingDamage	= INVALID_HANDLE;
new Handle: hHandtruckStandingDamage	= INVALID_HANDLE;
new Handle: hGeneratortrailerStandingDamage = INVALID_HANDLE;
new Handle: hForkliftStandingDamage		= INVALID_HANDLE;
new Handle: hBHLogStandingDamage		= INVALID_HANDLE;
new Handle: hDumpsterStandingDamage		= INVALID_HANDLE;
new Handle: hHaybaleStandingDamage		= INVALID_HANDLE;
new Handle: hBaggageStandingDamage		= INVALID_HANDLE;
new Handle: hStandardIncapDamage		= INVALID_HANDLE;
new Handle: hTankSelfDamage				= INVALID_HANDLE;
new Handle: hOverHitInterval			= INVALID_HANDLE;

//use tries with model names (and damage values?)?

public Plugin:myinfo = 
{
    name = "L4D1 Hittable Control",
    author = "Stabby, Visor, Harry Potter",
    version = "1.4",
    description = "Allows for customisation of hittable damage values."
};

public OnPluginStart()
{
	hLogStandingDamage		= CreateConVar( "hc_sflog_standing_damage",		"100.0",
											"Damage of hittable swamp fever logs to non-incapped survivors.",
											FCVAR_PLUGIN, true, 0.0, true, 300.0 );
	hBHLogStandingDamage	= CreateConVar( "hc_bhlog_standing_damage",		"100.0",
											"Damage of hittable blood harvest logs to non-incapped survivors.",
											FCVAR_PLUGIN, true, 0.0, true, 300.0 );
	hCarStandingDamage		= CreateConVar( "hc_car_standing_damage",		"100.0",
											"Damage of hittable non-parish-bridge cars to non-incapped survivors.",
											FCVAR_PLUGIN, true, 0.0, true, 300.0 );
	hBumperCarStandingDamage= CreateConVar( "hc_bumpercar_standing_damage",	"100.0",
											"Damage of hittable bumper cars to non-incapped survivors.",
											FCVAR_PLUGIN, true, 0.0, true, 300.0 );
	hHandtruckStandingDamage= CreateConVar( "hc_handtruck_standing_damage",	"8.0",
											"Damage of hittable handtrucks (aka dollies) to non-incapped survivors.",
											FCVAR_PLUGIN, true, 0.0, true, 300.0 );
	hGeneratortrailerStandingDamage = CreateConVar( "hc_generatortrailer_standing_damage",	"100.0",
											"Damage of hittable generatortrailer (in NM4) to non-incapped survivors.",
											FCVAR_PLUGIN, true, 0.0, true, 300.0 );
	hForkliftStandingDamage= CreateConVar(  "hc_forklift_standing_damage",	"100.0",
											"Damage of hittable forklifts to non-incapped survivors.",
											FCVAR_PLUGIN, true, 0.0, true, 300.0 );
	hDumpsterStandingDamage	= CreateConVar( "hc_dumpster_standing_damage",	"100.0",
											"Damage of hittable dumpsters to non-incapped survivors.",
											FCVAR_PLUGIN, true, 0.0, true, 300.0 );
	hHaybaleStandingDamage	= CreateConVar( "hc_haybale_standing_damage",	"100.0",
											"Damage of hittable haybales to non-incapped survivors.",
											FCVAR_PLUGIN, true, 0.0, true, 300.0 );
	hBaggageStandingDamage	= CreateConVar( "hc_baggage_standing_damage",	"100.0",
											"Damage of hittable baggage carts to non-incapped survivors.",
											FCVAR_PLUGIN, true, 0.0, true, 300.0 );
	hStandardIncapDamage	= CreateConVar( "hc_incap_standard_damage",		"100",
											"Damage of all hittables to incapped players. -1 will have incap damage default to valve's standard incoherent damages. -2 will have incap damage default to each hittable's corresponding standing damage.",
											FCVAR_PLUGIN, true, -2.0, true, 300.0 );
	hTankSelfDamage			= CreateConVar( "hc_disable_self_damage",		"1",
											"If set, tank will not damage itself with hittables.",
											FCVAR_PLUGIN, true, 0.0, true, 1.0 );
	hOverHitInterval		= CreateConVar( "hc_overhit_time",				"1.4",
											"The amount of time to wait before allowing consecutive hits from the same hittable to register. Recommended values: 0.0-0.5: instant kill; 0.5-0.7: sizeable overhit; 0.7-1.0: standard overhit; 1.0-1.2: reduced overhit; 1.2+: no overhit unless the car rolls back on top. Set to tank's punch interval (default 1.5) to fully remove all possibility of overhit.",
											FCVAR_PLUGIN, true, 0.0, false );
}
public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damageType/*, &weapon, Float:damageForce[3], Float:damagePosition[3]*/)
{
	if (!IsValidEdict(attacker) || !IsValidEdict(victim) || !IsValidEdict(inflictor))	{ return Plugin_Continue; }
	
	decl String:sClass[64];
	GetEdictClassname(inflictor, sClass, sizeof(sClass));
	//PrintToChatAll("%s dealt %f", sClass, damage);
	if (StrEqual(sClass,"prop_physics") || StrEqual(sClass,"prop_car_alarm") || StrEqual(sClass, "prop_physics_multiplayer"))
	{
		if (bIgnoreOverkill[victim]) { return Plugin_Handled; }
				
		if (GetEntProp(victim, Prop_Send, "m_zombieClass") == 5 && GetConVarBool(hTankSelfDamage))	{ return Plugin_Handled; }
		if (GetClientTeam(victim) != 2)	{ return Plugin_Continue; }	
		
		decl String:sModelName[128];
		GetEntPropString(inflictor, Prop_Data, "m_ModelName", sModelName, 128);
		
		new Float:val = GetConVarFloat(hStandardIncapDamage);
		if (GetEntProp(victim, Prop_Send, "m_isIncapacitated") && val != -2)
		{
			if (val >= 0.0)
			{
				damage = val;
			}
			else
			{
				return Plugin_Continue;
			}
		}
		else 
		{
			if (StrContains(sModelName, "cara_") != -1 || StrContains(sModelName, "taxi_") != -1 || StrContains(sModelName, "police_car") != -1)
			{
				damage = GetConVarFloat(hCarStandingDamage);
			}
			else if (StrContains(sModelName, "dumpster") != -1)
			{
				damage = GetConVarFloat(hDumpsterStandingDamage);
			}
			else if (StrEqual(sModelName, "models/props/cs_assault/forklift.mdl"))
			{
				damage = GetConVarFloat(hForkliftStandingDamage);
			}			
			else if (StrEqual(sModelName, "models/props_vehicles/airport_baggage_cart2.mdl"))
			{
				damage = GetConVarFloat(hBaggageStandingDamage);
			}
			else if (StrEqual(sModelName, "models/props_unique/haybails_single.mdl"))
			{
				damage = GetConVarFloat(hHaybaleStandingDamage);
			}
			else if (StrEqual(sModelName, "models/props_foliage/Swamp_FallenTree01_bare.mdl"))
			{
				damage = GetConVarFloat(hLogStandingDamage);
			}
			else if (StrEqual(sModelName, "models/props_foliage/tree_trunk_fallen.mdl"))
			{
				damage = GetConVarFloat(hBHLogStandingDamage);
			}
			else if (StrEqual(sModelName, "models/props_fairgrounds/bumpercar.mdl"))
			{
				damage = GetConVarFloat(hBumperCarStandingDamage);
			}
			else if (StrEqual(sModelName, "models/props/cs_assault/handtruck.mdl"))
			{
				damage = GetConVarFloat(hHandtruckStandingDamage);
			}
			else if (StrEqual(sModelName, "models/props_vehicles/generatortrailer01.mdl"))
			{
				damage = GetConVarFloat(hGeneratortrailerStandingDamage);
			}
			//PrintToChatAll("%s fell on %N, dealing %f dmg", sModelName, victim, damage);
		}
		
		new Float:interval = GetConVarFloat(hOverHitInterval);		
		if (interval >= 0.0)
		{
			bIgnoreOverkill[victim] = true;	//standardise them bitchin over-hits
			CreateTimer(interval, Timed_ClearInvulnerability, victim);
		}
		
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

public Action:Timed_ClearInvulnerability(Handle:thisTimer, any:victim)
{
	bIgnoreOverkill[victim] = false;
}