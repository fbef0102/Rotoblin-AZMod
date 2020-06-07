 /*
 * ============================================================================
 *
 *  File:			rotoblin.HeadsUpDisplay.sp
 *  Type:			Module
 *  Description:	...
 *
 *  Copyright (C) 2012-2015 raziEiL <war4291@mail.ru>
 *  Copyright (C) 2017-2020 Harry <fbef0102@gmail.com>
 *  This file is part of Rotoblin.
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * ============================================================================
 */

#define TIP			"Use !tankhud to toggle the tank HUD"
#define SPEC_TIP		"Use !spechud to toggle the spectator HUD"

static	Handle:g_hCvarAllowSpecHud, Handle:g_hCvarTwoTanks, Handle:g_hTankHealth, Handle:g_hVsBonusHealth, Handle:g_hLotteryTime, Handle:g_hCvarCompactHud, Handle:g_hBurnLifeTime, Float:g_fBurnDmg,
		bool:g_bCvarAllowSpecHud, bool:g_bCvarTwoTanks, bool:g_bCvarCompactHud, Float:g_fTankHealth = 6000.0, bool:g_bShowTankHud[MAXPLAYERS+1], bool:g_bHudEnabled, Handle:g_hDifficulty, Handle:g_hGameMode,
		g_iStasis, Handle:g_hSpecHudTimer, bool:g_bShowSpecHud[MAXPLAYERS+1], g_iSISpawnTime[MAXPLAYERS+1][2], bool:g_bBlockSpecHUD, bool:g_bTips[MAXPLAYERS+1][2], Handle:g_hCvarAllowTankHud, bool:g_bCvarAllowTankHud;

static stock bool:g_bTankKilled;

_HeadsUpDisplay_OnPluginStart()
{
	g_hTankHealth		= FindConVar("z_tank_health");
	g_hVsBonusHealth	= FindConVar("versus_tank_bonus_health");
	g_hLotteryTime		= FindConVar("director_tank_lottery_selection_time");
	g_hBurnLifeTime		= FindConVar("z_tank_burning_lifetime");
	g_hDifficulty		= FindConVar("z_difficulty");
	g_hGameMode			= FindConVar("mp_gamemode");

	g_hCvarAllowSpecHud		= CreateConVarEx("allow_spec_hud", "0", "Enables Rotoblin spectator HUD");
	g_hCvarAllowTankHud		= CreateConVarEx("allow_tank_hud", "0", "Enables Rotoblin Tank HUD");
	g_hCvarTwoTanks				= CreateConVarEx("two_tanks", "0", "Enables support for double tank mods (The Tank Hud)");
	g_hCvarCompactHud			= CreateConVarEx("compact_tankhud", "0", "The style of the Tank HUD. (0: old style, 1: new style)");

	RegConsoleCmd("sm_tankhud", Command_ToogleTankHud, "Toggles the Tank HUD visibility");
	RegConsoleCmd("sm_spechud", Command_ToogleSpecHud, "Toggles the Spectator HUD visibility");

	RegServerCmd("rotoblin_pause_spechud", Command_PauseSpecHUD);
}

public Action:Command_PauseSpecHUD(args)
{
	decl String:sArgs[24];
	GetCmdArg(1, sArgs, 24);

	g_bBlockSpecHUD = StrEqual(sArgs, "true");
}

public Action:Command_ToogleTankHud(client, args)
{
	if (!client) return Plugin_Handled;

	g_bShowTankHud[client] = !g_bShowTankHud[client];
	PrintToChat(client, "%s Tank HUD is now %s.", MAIN_TAG, g_bShowTankHud[client] ? "enabled" : "disabled");

	return Plugin_Handled;
}

public Action:Command_ToogleSpecHud(client, args)
{
	if (!client || !g_bCvarAllowSpecHud) return Plugin_Handled;

	g_bShowSpecHud[client] = !g_bShowSpecHud[client];
	PrintToChat(client, "%s Spec HUD is now %s.", MAIN_TAG, g_bShowSpecHud[client] ? "enabled" : "disabled");

	return Plugin_Handled;
}

_HUD_OnPluginEnabled()
{
	HookEvent("round_start", HUD_ev_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("ghost_spawn_time", HUD_ev_GhostSpawnTime);

	HookConVarChange(g_hCvarTwoTanks,		HUD_OnCvarChange_TwoTanks);
	HookConVarChange(g_hCvarCompactHud,	HUD_OnCvarChange_CompactHud);
	HookConVarChange(g_hTankHealth,			HUD_OnCvarChange_TankHealth);
	HookConVarChange(g_hVsBonusHealth,		HUD_OnCvarChange_TankHealth);
	HookConVarChange(g_hBurnLifeTime,		HUD_OnCvarChange_TankHealth);
	HookConVarChange(g_hDifficulty,			HUD_OnCvarChange_TankHealth);
	HookConVarChange(g_hGameMode,			HUD_OnCvarChange_TankHealth);
	HookConVarChange(g_hCvarAllowSpecHud,	HUD_OnCvarChange_SpecHud);
	HookConVarChange(g_hCvarAllowTankHud,	HUD_OnCvarChange_TankHud);

	HUD_GetCvars();

	if (g_bCvarAllowSpecHud)
		g_hSpecHudTimer = CreateTimer(1.0, HUD_t_SpecTimer, _, TIMER_REPEAT);
}

_HUD_OnPluginDisable()
{
	UnhookEvent("round_start", HUD_ev_RoundStart, EventHookMode_PostNoCopy);
	UnhookEvent("ghost_spawn_time", HUD_ev_GhostSpawnTime);

	UnhookConVarChange(g_hCvarTwoTanks,		HUD_OnCvarChange_TwoTanks);
	UnhookConVarChange(g_hCvarCompactHud,		HUD_OnCvarChange_CompactHud);
	UnhookConVarChange(g_hTankHealth,			HUD_OnCvarChange_TankHealth);
	UnhookConVarChange(g_hVsBonusHealth, 		HUD_OnCvarChange_TankHealth);
	UnhookConVarChange(g_hBurnLifeTime, 		HUD_OnCvarChange_TankHealth);
	UnhookConVarChange(g_hDifficulty,			HUD_OnCvarChange_TankHealth);
	UnhookConVarChange(g_hGameMode,				HUD_OnCvarChange_TankHealth);
	UnhookConVarChange(g_hCvarAllowSpecHud,	HUD_OnCvarChange_SpecHud);
	UnhookConVarChange(g_hCvarAllowTankHud,	HUD_OnCvarChange_TankHud);

	CloseSpecHud();
}

static CloseSpecHud()
{
	if (g_hSpecHudTimer != INVALID_HANDLE){
		KillTimer(g_hSpecHudTimer);
		g_hSpecHudTimer = INVALID_HANDLE;
	}
}

_HUD_OnClientPutInServer(client)
{
	g_bShowSpecHud[client] = true;
}

public HUD_ev_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_bTankKilled = false;

	for (new i = 1; i <= MaxClients; i++){

		g_bShowTankHud[i] = false;
		g_bTips[i][0] = false;
		g_bTips[i][1] = false;
	}
}

static _HUD_ShowTankTip(client)
{
	if (g_bTips[client][0]) return;

	PrintToChat(client, "%s %s", MAIN_TAG, TIP);

	g_bTips[client][0] = true;
}

static _HUD_ShowSpecTip(client)
{
	if (g_bTips[client][1]) return;

	PrintToChat(client, "%s %s", MAIN_TAG, SPEC_TIP);

	g_bTips[client][1] = true;
}

_HUD_ev_OnTankSpawn()
{
	if (g_bCvarAllowTankHud && !g_bHudEnabled){

		for (new i = 1; i <= MaxClients; i++){

			g_bShowTankHud[i] = true;

			if (!IsClientInGame(i) || IsFakeClient(i)) continue;

			if (GetClientTeam(i) != 2)
				_HUD_ShowTankTip(i);
		}

		g_bHudEnabled = true;
		g_bTankKilled = false;
		g_iStasis = GetConVarInt(g_hLotteryTime);
		HUD_DrawTankPanel();
		CreateTimer(float(g_iStasis), HUD_t_TankInControl, _, TIMER_FLAG_NO_MAPCHANGE);
		CreateTimer(1.0, HUD_t_Timer, _, TIMER_REPEAT);
	}
}

public Action:HUD_t_TankInControl(Handle:timer)
{
	g_iStasis = 0;
}

public Action:HUD_t_Timer(Handle:timer)
{
	if (!HUD_DrawTankPanel()){

		g_bHudEnabled = false;
		g_bTankKilled = true;
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

static bool:HUD_DrawTankPanel()
{
	if (!g_bCvarAllowTankHud) return false;
	if (g_bBlackSpot || (IsNativeAvailable(IsGamePaused) && L4DReady_IsGamePaused())) return true;

	new bool:bTankInGame, iTanksIndex[2];

	for (new i = 1; i <= MaxClients; i++){

		if (!IsClientInGame(i) || !IsPlayerAlive(i) || GetClientTeam(i) != TEAM_INFECTED || !IsPlayerTank(i)) continue;

		if (!bTankInGame)
			iTanksIndex[0] = i;
		else
			iTanksIndex[1] = i;
		bTankInGame = true;
	}
	if (!bTankInGame) return false;


	static Handle:hHUD, String:sNameA[32], String:sNameB[32], iPassCount;

	iPassCount = L4DDirect_GetTankPassedCount();
	if (iPassCount > 2) iPassCount = 2;
	hHUD = CreatePanel();

	decl String:sBuffer[256];
	if (g_bCvarTwoTanks || !g_bCvarCompactHud)
		DrawPanelText(hHUD, "Rotoblin Tank Spec HUD\n\n------------------------------");
	else
		DrawPanelText(hHUD, "Rotoblin Tank Spec HUD\n\n--------------------------------------");

	if (g_bCvarTwoTanks){

		if (IsFakeClient(iTanksIndex[0]))
			sNameA = "AI";
		else {
			GetClientName(iTanksIndex[0], sNameA, 17);
			if (strlen(sNameA) == 16){

				strcopy(sNameA, 13, sNameA);
				Format(sNameA, 32, "%s...", sNameA);
			}
		}
		DrawPanelText(hHUD, " Health :");
		if (IsIncapacitated(iTanksIndex[0]))
			FormatEx(sBuffer, 256, "     Dead (%s)", sNameA);
		else
			FormatEx(sBuffer, 256, "     %d (%s)", GetClientHealth(iTanksIndex[0]), sNameA);
		DrawPanelText(hHUD, sBuffer);

		if (iTanksIndex[1] != 0){

			if (IsFakeClient(iTanksIndex[1]))
				sNameB = "AI";
			else {
				GetClientName(iTanksIndex[1], sNameB, 17);
				if (strlen(sNameB) == 16){

					strcopy(sNameB, 13, sNameB);
					Format(sNameB, 32, "%s...", sNameB);
				}
			}
			if (IsIncapacitated(iTanksIndex[1]))
				FormatEx(sBuffer, 256, "     Dead (%s)", sNameB);
			else
				FormatEx(sBuffer, 256, "     %d (%s)", GetClientHealth(iTanksIndex[1]), sNameB);
			DrawPanelText(hHUD, sBuffer);
		}

		DrawPanelText(hHUD, " Frustration :");
		if (IsClientOnFire(iTanksIndex[0]))
			FormatEx(sBuffer, 256, "     On Fire (%s)", sNameA);
		else
			FormatEx(sBuffer, 256, "     %d%% (%s)", GetPrecentFrustration(iTanksIndex[0]), sNameA);
		DrawPanelText(hHUD, sBuffer);

		if (iTanksIndex[1] != 0){

			if (IsClientOnFire(iTanksIndex[1]))
				FormatEx(sBuffer, 256, "     On Fire (%s)", sNameB);
			else
				FormatEx(sBuffer, 256, "     %d%% (%s)", GetPrecentFrustration(iTanksIndex[1]), sNameB);
			DrawPanelText(hHUD, sBuffer);
		}
	}
	else {

		static bool:bIsAI, bool:bIncap, iHealth, iPercent, String:sName[32];

		bIsAI = IsFakeClient(iTanksIndex[0]);
		bIncap = bool:IsIncapacitated(iTanksIndex[0]);

		if (!g_bCvarCompactHud){

			DrawPanelText(hHUD, " In Control :");

			if (bIsAI)
				sBuffer = "     AI";
			else{

				CheckMaxNameLen(iTanksIndex[0], sName);
				FormatEx(sBuffer, 256, "     %s", sName);
			}
			DrawPanelText(hHUD, sBuffer);

			DrawPanelText(hHUD, " Health :");
			if (bIncap)
				sBuffer = "     Dead";
			else {
				iHealth = GetClientHealth(iTanksIndex[0]);
				iPercent = RoundToFloor(FloatMul(FloatDiv(float(iHealth), g_fTankHealth), 100.0));
				if (iPercent != 100 && iHealth == RoundToFloor(g_fTankHealth))
					iPercent = 100;
				FormatEx(sBuffer, 256, "     %d (%d%%)", iHealth, iPercent ? iPercent : 1);
			}
			DrawPanelText(hHUD, sBuffer);

			if (g_iStasis && bIsAI){

				DrawPanelText(hHUD, " Status :");
				FormatEx(sBuffer, 256, "     Stasis (%d sec)", --g_iStasis);
			}
			else if (IsClientOnFire(iTanksIndex[0])){

				DrawPanelText(hHUD, " Status :");
				FormatEx(sBuffer, 256, "     On Fire (%d sec)", bIncap ? 0 : RoundToCeil(iHealth / g_fBurnDmg));
			}
			else {

				DrawPanelText(hHUD, " Pass Count :");
				FormatEx(sBuffer, 256, "     %d/2", iPassCount);

				if (bIsAI && iPassCount == 2)
					Format(sBuffer, 256, "%s (Lost)", sBuffer);
				else
					Format(sBuffer, 256, "%s (%d%%)", sBuffer, GetPrecentFrustration(iTanksIndex[0]));
			}
			DrawPanelText(hHUD, sBuffer);
		}
		else {

			if (bIsAI)
				FormatEx(sBuffer, 256, " In Control    : AI");
			else {

				CheckMaxNameLen(iTanksIndex[0], sName);
				FormatEx(sBuffer, 256, " In Control    : %s", sName);
			}
			DrawPanelText(hHUD, sBuffer);

			if (bIncap)
				FormatEx(sBuffer, 256, " Health         : Dead");
			else {
				iHealth = GetClientHealth(iTanksIndex[0]);
				iPercent = RoundToFloor(FloatMul(FloatDiv(float(iHealth), g_fTankHealth), 100.0));
				if (iPercent != 100 && iHealth == RoundToFloor(g_fTankHealth))
					iPercent = 100;
				FormatEx(sBuffer, 256, " Health         : %d (%d%%)", iHealth, iPercent ? iPercent : 1);
			}
			DrawPanelText(hHUD, sBuffer);

			if (g_iStasis && bIsAI)
				FormatEx(sBuffer, 256, " Status         : Stasis (%d sec)", --g_iStasis);
			else if (IsClientOnFire(iTanksIndex[0]))
				FormatEx(sBuffer, 256, " Status         : On Fire (%d sec)", bIncap ? 0 : RoundToCeil(iHealth / g_fBurnDmg));
			else {

				FormatEx(sBuffer, 256, " Pass Count  : %d/2", iPassCount);

				if (bIsAI && iPassCount == 2)
					Format(sBuffer, 256, "%s (Lost)", sBuffer);
				else
					Format(sBuffer, 256, "%s (%d%%)", sBuffer, GetPrecentFrustration(iTanksIndex[0]));

			}
			DrawPanelText(hHUD, sBuffer);
		}
	}

	for (new i; i < InfectedCount; i++){

		if (!g_bShowTankHud[InfectedIndex[i]] || InfectedIndex[i] <= 0  || !IsClientInGame(InfectedIndex[i]) || IsFakeClient(InfectedIndex[i]) || GetClientMenu(InfectedIndex[i]) == MenuSource_Normal) continue; // If client is the tank or is a bot, continue

		if (g_bCvarTwoTanks){

			if (InfectedIndex[i] == iTanksIndex[0])
				ExtraTankMod(InfectedIndex[i], iTanksIndex[1], sNameB);
			else if (InfectedIndex[i] == iTanksIndex[1])
				ExtraTankMod(InfectedIndex[i], iTanksIndex[0], sNameA);
			else
				SendPanelToClient(hHUD, InfectedIndex[i], HUD_HUD_Handler, 1);
		}
		else if (InfectedIndex[i] != iTanksIndex[0])
			SendPanelToClient(hHUD, InfectedIndex[i], HUD_HUD_Handler, 1);
	}

	for (new i; i < SpectateCount; i++){

		if (!g_bShowTankHud[SpectateIndex[i]] || SpectateIndex[i] <= 0  || !IsClientInGame(SpectateIndex[i]) || IsFakeClient(SpectateIndex[i]) || GetClientMenu(SpectateIndex[i]) == MenuSource_Normal) continue; // If client is the tank or is a bot, continue

		_HUD_ShowTankTip(SpectateIndex[i]);
		SendPanelToClient(hHUD, SpectateIndex[i], HUD_HUD_Handler, 1);
	}

	CloseHandle(hHUD);
	return true;
}

static ExtraTankMod(client, tank, String:sNameA[])
{
	new Handle:hDTTankHud = CreatePanel();
	decl String:sBuffer[256];
	if (tank){

		if (!IsIncapacitated(tank))
			FormatEx(sBuffer, 256, " Tank: %d (%s)", GetClientHealth(tank), sNameA);
		else
			FormatEx(sBuffer, 256, " Tank: Dead (%s)", sNameA);
		DrawPanelText(hDTTankHud, sBuffer);
	}

	SendPanelToClient(hDTTankHud, client, HUD_HUD_Handler, 1);
	CloseHandle(hDTTankHud);
}

public HUD_HUD_Handler(Handle:menu, MenuAction:action, param1, param2)
{

}

static Float:GetCoopMultiplie()
{
	decl String:sDifficulty[24];
	GetConVarString(g_hDifficulty, sDifficulty, 24);

	if (StrEqual(sDifficulty, "Easy"))
		return 0.75;
	else if (StrEqual(sDifficulty, "Normal"))
		return 1.0;

	return 2.0;
}

public HUD_OnCvarChange_TwoTanks(Handle:hHandle, const String:sOldVal[], const String:sNewVal[])
{
	if (!StrEqual(sOldVal, sNewVal))
		g_bCvarTwoTanks = GetConVarBool(hHandle);
}

public HUD_OnCvarChange_TankHealth(Handle:hHandle, const String:sOldVal[], const String:sNewVal[])
{
	if (StrEqual(sOldVal, sNewVal)) return;

	g_fTankHealth = FloatMul(GetConVarFloat(g_hTankHealth), IsVersusMode() ? GetConVarFloat(g_hVsBonusHealth) : GetCoopMultiplie());
	g_fBurnDmg = g_fTankHealth / GetConVarFloat(g_hBurnLifeTime);
}

public HUD_OnCvarChange_CompactHud(Handle:hHandle, const String:sOldVal[], const String:sNewVal[])
{
	if (!StrEqual(sOldVal, sNewVal))
		g_bCvarCompactHud = GetConVarBool(hHandle);
}

public HUD_OnCvarChange_SpecHud(Handle:hHandle, const String:sOldVal[], const String:sNewVal[])
{
	if (!StrEqual(sOldVal, sNewVal)){

		CloseSpecHud();

		if ((g_bCvarAllowSpecHud = GetConVarBool(hHandle)))
			g_hSpecHudTimer = CreateTimer(1.0, HUD_t_SpecTimer, _, TIMER_REPEAT);
	}
}

public HUD_OnCvarChange_TankHud(Handle:hHandle, const String:sOldVal[], const String:sNewVal[])
{
	if (!StrEqual(sOldVal, sNewVal))
		g_bCvarAllowTankHud = GetConVarBool(hHandle);
}

static HUD_GetCvars()
{
	g_bCvarTwoTanks = GetConVarBool(g_hCvarTwoTanks);
	g_fTankHealth = FloatMul(GetConVarFloat(g_hTankHealth), IsVersusMode() ? GetConVarFloat(g_hVsBonusHealth) : GetCoopMultiplie());
	g_bCvarCompactHud = GetConVarBool(g_hCvarCompactHud);
	g_fBurnDmg = g_fTankHealth / GetConVarFloat(g_hBurnLifeTime);
	g_bCvarAllowSpecHud = GetConVarBool(g_hCvarAllowSpecHud);
	g_bCvarAllowTankHud = GetConVarBool(g_hCvarAllowTankHud);
}

/*--------------------------------------
SURVIVORS: 56 (150)
raziEiL		(100)	[pumpshotgun 6/120]
Alma		(59)	[SMG 43/350]
Scratchy	(250)	[Down 1/2]
Electr0		(Dead)	[N/A]

INFECTED: 244 (N/A)
PlayerOne	(Dead)	[12s]
Tester		(Ghost)	[Hunter]
Hello World	(50)	[Boomer]
Mr.Pink		(6000)	[Tank]

Mob Timer: 54s / Tank: In game
--------------------------------------*/
#define MAX_NAME_LEN 13
static	g_iMaxFixedNameLen = MAX_NAME_LEN - 3,
		g_iMaxBuffLen = MAX_NAME_LEN + 1;

CheckMaxNameLen(client, String:sName[])
{
	GetClientName(client, sName, g_iMaxBuffLen);

	// thanks to confogl
	if (sName[0] == '[')
		sName[0] = ' ';

	if (strlen(sName) == MAX_NAME_LEN){

		strcopy(sName, g_iMaxFixedNameLen, sName);
		Format(sName, 32, "%s...", sName);
	}
}

static const String:g_sSINames[][] =
{
	"",
	"Smoker",
	"Boomer",
	"Hunter",
	"",
	"Tank"
};

public HUD_ev_GhostSpawnTime(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsFakeClient(client)){

		g_iSISpawnTime[client][0] = GetEventInt(event, "spawntime");
		g_iSISpawnTime[client][1] = RoundToFloor(GetEngineTime());
	}
}

public Action:HUD_t_SpecTimer(Handle:timer)
{
	if (g_bHudEnabled || g_bBlackSpot || g_bBlockSpecHUD || !IsNativeAvailable(GetScore) || (IsNativeAvailable(IsReadyMode) && L4DReady_IsReadyMode()))
		return Plugin_Continue;

	static Handle:hSpecHUD, iTempValb, iTempVal, bool:bAreFlipped;

	hSpecHUD = CreatePanel();
	bAreFlipped = bool:GameRules_GetProp("m_bAreTeamsFlipped");
	decl String:sBuffer[256], String:sBufferB[256];

	SetPanelTitle(hSpecHUD, "Rotoblin Spectator HUD\n\n---------------------------------------");
	FormatEx(sBuffer, 256, "SURVIVORS: %d", R2comp_GetScore(bAreFlipped));
	DrawPanelText(hSpecHUD, sBuffer);

	if (SurvivorCount){

		for (new i; i < SurvivorCount; i++){

			if (g_bBlackSpot) return Plugin_Continue;

			if ((iTempValb = IsSurvivorBussy(SurvivorIndex[i])))
				FormatEx(sBufferB, 256, "Caught");

			if (IsHandingFromLedge(SurvivorIndex[i])){

				if (iTempValb)
					Format(sBufferB, 256, "%s | Hang", sBufferB);
				else
					FormatEx(sBufferB, 256, "Hang");
			}
			else if (IsIncapacitated(SurvivorIndex[i])){

				if (iTempValb)
					Format(sBufferB, 256, "%s | %d Down", sBufferB, GetEntProp(SurvivorIndex[i], Prop_Send, "m_currentReviveCount") + 1);
				else
					FormatEx(sBufferB, 256, "%d Down", GetEntProp(SurvivorIndex[i], Prop_Send, "m_currentReviveCount") + 1);
			}
			else if (!iTempValb){

				iTempValb = GetEntPropEnt(SurvivorIndex[i], Prop_Send, "m_hActiveWeapon");

				if (IsValidEntity(iTempValb)){

					GetEntityClassname(iTempValb, sBufferB, 256);
					iTempVal = GetWeaponIndexByClass(sBufferB);

					if (strcmp(sBufferB, "weapon_pistol") == 0 && GetEntProp(iTempValb, Prop_Send, "m_isDualWielding"))
						FormatEx(sBufferB, 256, "dual pistols");
					else {

						ReplaceString(sBufferB, 256, "weapon_", "", false);
						ReplaceString(sBufferB, 256, "_spawn", "", false);
						ReplaceString(sBufferB, 256, "_", " ", false);
					}

					if (iTempVal != NULL)
						Format(sBufferB, 256, "%s %d/%d", sBufferB, GetWeaponClipSize(iTempValb), GetPrimaryWeaponAmmo(SurvivorIndex[i], iTempVal));
				}
				else
					FormatEx(sBufferB, 256, "N/A");
			}

			if (!IsFakeClient(SurvivorIndex[i])){

				CheckMaxNameLen(SurvivorIndex[i], sBuffer);
			}
			else{

				GetCharacterName(SurvivorIndex[i], sBuffer, 256);
				//Format(sBuffer, 256, "%s-AI", sBuffer);
			}
			Format(sBuffer, 256, "%s (%d) [%s]", sBuffer, GetClientHealth(SurvivorIndex[i]) + RoundToFloor(GetTempHealth(SurvivorIndex[i])), sBufferB);
			DrawPanelText(hSpecHUD, sBuffer);
		}
	}
	if (DeadSurvivorCount){

		for (new i; i < DeadSurvivorCount; i++){

			if (g_bBlackSpot) return Plugin_Continue;

			if (!IsFakeClient(DeadSurvivorIndex[i])){

				CheckMaxNameLen(DeadSurvivorIndex[i], sBuffer);
			}
			else {

				GetCharacterName(DeadSurvivorIndex[i], sBuffer, 256);
				//Format(sBuffer, 256, "%s-AI", sBuffer);
			}
			Format(sBuffer, 256, "%s (Dead) [N/A]", sBuffer);
			DrawPanelText(hSpecHUD, sBuffer);
		}
	}

	DrawPanelText(hSpecHUD, " ");
	FormatEx(sBuffer, 256, "INFECTED: %d", R2comp_GetScore(!bAreFlipped));
	DrawPanelText(hSpecHUD, sBuffer);

	if (InfectedCount){

		iTempVal = RoundToFloor(GetEngineTime());

		for (new i; i < InfectedCount; i++){

			if (g_bBlackSpot) return Plugin_Continue;

			iTempValb = IsInfectedAlive(InfectedIndex[i]);

			if (!IsFakeClient(InfectedIndex[i])){

				CheckMaxNameLen(InfectedIndex[i], sBuffer);
			}
			else {

				if (!iTempValb) continue;
				FormatEx(sBuffer, 256, "AI");
			}

			if (iTempValb){

				if (IsPlayerGhost(InfectedIndex[i]))
					sBufferB = "Ghost";
				else
					FormatEx(sBufferB, 256, "%d", GetClientHealth(InfectedIndex[i]));

				Format(sBufferB, 256, "%s (%s) [%s]", sBuffer, sBufferB, g_sSINames[GetPlayerClass(InfectedIndex[i])]);
				DrawPanelText(hSpecHUD, sBufferB);
			}
			else {

				iTempValb = g_iSISpawnTime[InfectedIndex[i]][0] - (iTempVal - g_iSISpawnTime[InfectedIndex[i]][1]);

				if (iTempValb > -1)
					FormatEx(sBufferB, 256, "[%ds]", iTempValb);
				else
					sBufferB = "";

				Format(sBufferB, 256, "%s (Dead) %s", sBuffer, sBufferB);
				DrawPanelText(hSpecHUD, sBufferB);
			}
		}
	}
	/*
	DrawPanelText(hSpecHUD, " ");
	if (MC_GetMobTimer() == -1)
		sBufferB = "N/A";
	else
		FormatEx(sBufferB, 256, "%ds", MC_GetMobTimer());

	FormatEx(sBuffer, 256, "Mob Timer: %s / Tank Status: %s", sBufferB, g_bTankKilled ? "Killed" : "N/A");
	DrawPanelText(hSpecHUD, sBuffer);
	*/
	for (new i; i < SpectateCount; i++){

		if (g_bBlackSpot) return Plugin_Continue;

		if (!g_bShowSpecHud[SpectateIndex[i]] || IsFakeClient(SpectateIndex[i]) || GetClientMenu(SpectateIndex[i]) == MenuSource_Normal) continue;

		_HUD_ShowSpecTip(SpectateIndex[i]);
		SendPanelToClient(hSpecHUD, SpectateIndex[i], HUD_HUD_Handler, 2);
	}

	CloseHandle(hSpecHUD);
	return Plugin_Continue;
}
