/*
	Checkpoint Rage Control (C) 2014 Michael Busby
	All trademarks are property of their respective owners.

	This program is free software: you can redistribute it and/or modify it
	under the terms of the GNU General Public License as published by the
	Free Software Foundation, either version 3 of the License, or (at your
	option) any later version.

	This program is distributed in the hope that it will be useful, but
	WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
	General Public License for more details.

	You should have received a copy of the GNU General Public License along
	with this program.  If not, see <http://www.gnu.org/licenses/>.
*/
#pragma semicolon 1

#include <sourcemod>
#include <colors>

#define CALL_OPCODE 0xE8

// xor eax,eax; NOP_3;
new PATCH_REPLACEMENT[5] = {0x31, 0xC0, 0x0f,0x1f,0x00};
new ORIGINAL_BYTES[5];
new Address:g_pPatchTarget;
new bool:g_bIsPatched;

new Handle:hAllMaps;
new Handle:hSaferoomFrustrationTickdownMaps;
static bool:g_bIsTankAlive;

public Plugin:myinfo =
{
	name = "Checkpoint Rage Control",
	author = "ProdigySim, Visor",
	description = "Enable tank to lose rage while survivors are in saferoom,L4D1 windows signature by Harry",
	version = "0.3",
	url = "https://github.com/Attano/L4D2-Competitive-Framework"
}

public OnPluginStart()
{
	LoadTranslations("Roto2-AZ_mod.phrases");
	new Handle:hGamedata = LoadGameConfigFile("checkpoint-rage-control");
	if (!hGamedata)
		SetFailState("Gamedata 'checkpoint-rage-control.txt' missing or corrupt");

	g_pPatchTarget = FindPatchTarget(hGamedata);
	CloseHandle(hGamedata);

	hSaferoomFrustrationTickdownMaps = CreateTrie();

	hAllMaps = CreateConVar("crc_global", "1", "Remove saferoom frustration preservation mechanic on all maps by default");

	HookEvent("tank_spawn", OnTankSpawn, EventHookMode_PostNoCopy);
	HookEvent("round_start", OnRoundStart, EventHookMode_PostNoCopy);
	
	RegServerCmd("saferoom_frustration_tickdown", SetSaferoomFrustrationTickdown);
}

public Action:SetSaferoomFrustrationTickdown(args)
{
	decl String:mapname[64];
	GetCmdArg(1, mapname, sizeof(mapname));
	SetTrieValue(hSaferoomFrustrationTickdownMaps, mapname, true);
}

public OnPluginEnd()
{
	Unpatch();
}

public OnMapStart()
{
	if (GetConVarBool(hAllMaps))
	{
		Patch();
		return;
	}
	
	decl String:mapname[64];
	GetCurrentMap(mapname, sizeof(mapname));

	decl dummy;
	if (GetTrieValue(hSaferoomFrustrationTickdownMaps, mapname, dummy))
	{
		Patch();
	}
	else
	{
		Unpatch();
	}
}

public Action:OnTankSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!g_bIsTankAlive)
	{
		CreateTimer(0.1, On_t_Instruction);
		g_bIsTankAlive = true;
	}
}

public Action:OnRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_bIsTankAlive = false;
}

public Action:On_t_Instruction(Handle:timer)
{
	if (IsPatched())
	{
		CPrintToChatAll("%t","Survivors are in saferoom, Tank still loses rage!!!");
	}
}

bool:IsPatched()
{
	return g_bIsPatched;
}

Patch()
{
	if(!IsPatched())
	{
		for(new i =0; i < sizeof(PATCH_REPLACEMENT); i++)
		{
			StoreToAddress(g_pPatchTarget + Address:i, PATCH_REPLACEMENT[i], NumberType_Int8);
		}
		g_bIsPatched = true;
	}
}

Unpatch()
{
	if(IsPatched())
	{
		for(new i =0; i < sizeof(ORIGINAL_BYTES); i++)
		{
			StoreToAddress(g_pPatchTarget + Address:i, ORIGINAL_BYTES[i], NumberType_Int8);
		}
		g_bIsPatched = false;
	}
}

Address:FindPatchTarget(Handle:hGamedata)
{
	new Address:pTarget = GameConfGetAddress(hGamedata, "SaferoomCheck_Sig");
	if (!pTarget)
		SetFailState("Couldn't find the 'SaferoomCheck_Sig' address");
	
	new iOffset = GameConfGetOffset(hGamedata, "UpdateZombieFrustration_SaferoomCheck");
	
	pTarget = pTarget + (Address:iOffset);
	
	if(LoadFromAddress(pTarget, NumberType_Int8) != CALL_OPCODE)
		SetFailState("Saferoom Check Offset or signature seems incorrect");
	
	ORIGINAL_BYTES[0] = CALL_OPCODE;
	
	for(new i =1; i < sizeof(ORIGINAL_BYTES); i++)
	{
		ORIGINAL_BYTES[i] = LoadFromAddress(pTarget + Address:i, NumberType_Int8);
	}
	
	return pTarget;
}