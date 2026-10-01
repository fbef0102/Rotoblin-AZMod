/**
 * l4d_witch_corner_fix: stops the witch freezing on corners at a low nb_update_frequency.
 *
 * ZombieBotLocomotion::ResolveCollision gives up on a move when it would shift her less
 * than 1 unit (Linux: two `fld1; fucomip; fstp; ja` checks, at +0x3ED and +0x491;
 * Windows: two `fcomp [1.0f]; fnstsw; test ah,5; jnp` checks, at +0x1E5 and +0x5F6). The 1 unit
 * was sized for bots updated every 0.1 s. At our 0.014 she updates every tick, and once
 * she is stopped against a wall her next step is ~0.05 units, so every step is thrown
 * away and she stands still for ever with her running animation playing.
 *
 * While, and only while, a witch's locomotion updates, both checks are turned off:
 * on Linux `fld1` (D9 E8) becomes `fldz` (D9 EE); on Windows the 1.0f is a shared
 * constant, so the `jnp` (0F 8B) becomes `jo` (0F 80), never taken after a `test`. Common infected run the same code and
 * are left untouched: the hook is on the WitchLocomotion vtable, per witch, so commons
 * never reach it. Everything is verified against the expected bytes before any change;
 * on any mismatch the plugin refuses to run. Research: witchfix/re/REPORT.md.
 */
#include <sourcemod>
#include <sdktools>
#include <dhooks>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name = "L4D Witch Corner Fix",
	author = "Riverside",
	description = "Stops the witch freezing on corners at a low nb_update_frequency",
	version = "1.1.0",
	url = ""
};

bool g_windows;
int g_sites[2];               // the byte flipped at each check, from ResolveCollision
int g_byteOff, g_byteOn;
Address g_rc;                 // ZombieBotLocomotion::ResolveCollision
int g_locoOffset;             // Witch -> WitchLocomotion*
Address g_witchVtable;        // what a WitchLocomotion's vptr holds
DynamicHook g_update;
int g_hookPre[2048] = { INVALID_HOOK_ID, ... };
int g_hookPost[2048] = { INVALID_HOOK_ID, ... };
bool g_patched;
ConVar g_cvEnable;

public void OnPluginStart()
{
	GameData gd = new GameData("l4d_witch_corner_fix");
	if (gd == null) SetFailState("gamedata l4d_witch_corner_fix.txt missing");
	g_windows = gd.GetOffset("Platform") == 2;
	g_rc = gd.GetAddress("ResolveCollision");
	Address gli = gd.GetAddress("GetLocomotionInterface");
	Address vt = gd.GetAddress("WitchLocomotionVtable");
	int slot = gd.GetOffset("ILocomotion::Update");
	delete gd;
	if (g_rc == Address_Null || gli == Address_Null || vt == Address_Null || slot < 0) SetFailState("a symbol was not found");

	if (g_windows)
	{
		// fcomp dword ptr [1.0f] (D8 1D imm32); fnstsw ax (DF E0); test ah,5 (F6 C4 05); jnp (0F 8B)
		int sites[2] = { 0x1E5, 0x5F6 };
		int expect[13] = { 0xD8, 0x1D, -1, -1, -1, -1, 0xDF, 0xE0, 0xF6, 0xC4, 0x05, 0x0F, 0x8B };
		for (int s = 0; s < 2; s++)
		{
			for (int i = 0; i < 13; i++)
				if (expect[i] != -1 && Byte(g_rc, sites[s] + i) != expect[i])
					SetFailState("ResolveCollision+0x%X+%d is %02X, expected %02X: different game build", sites[s], i, Byte(g_rc, sites[s] + i), expect[i]);
			Address one = view_as<Address>(LoadFromAddress(g_rc + view_as<Address>(sites[s] + 2), NumberType_Int32));
			if (view_as<float>(LoadFromAddress(one, NumberType_Int32)) != 1.0)
				SetFailState("ResolveCollision+0x%X does not compare against 1.0: different game build", sites[s]);
			g_sites[s] = sites[s] + 12;
		}
		g_byteOff = 0x8B;
		g_byteOn = 0x80;

		// no getter to read here: gli is Witch::CreateComponents, and at +0x48, right after the
		// WitchLocomotion is built, it stores it with mov [esi+imm32], edi (89 BE ....)
		if (Byte(gli, 0x48) != 0x89 || Byte(gli, 0x49) != 0xBE) SetFailState("Witch::CreateComponents has an unexpected shape");
		g_locoOffset = LoadFromAddress(gli + view_as<Address>(0x4A), NumberType_Int32);
		g_witchVtable = vt;
	}
	else
	{
		int sites[2] = { 0x3ED, 0x491 };
		int expect[8] = { 0xD9, 0xE8, 0xDF, 0xE9, 0xDD, 0xD8, 0x0F, 0x87 };
		for (int s = 0; s < 2; s++)
		{
			for (int i = 0; i < 8; i++)
				if (Byte(g_rc, sites[s] + i) != expect[i])
					SetFailState("ResolveCollision+0x%X+%d is %02X, expected %02X: different game build", sites[s], i, Byte(g_rc, sites[s] + i), expect[i]);
			g_sites[s] = sites[s] + 1;
		}
		g_byteOff = 0xE8;
		g_byteOn = 0xEE;

		// mov eax,[esp+4] (8B 44 24 04); mov eax,[eax+imm32] (8B 80 ....); ret (C3)
		int head[6] = { 0x8B, 0x44, 0x24, 0x04, 0x8B, 0x80 };
		for (int i = 0; i < 6; i++)
			if (Byte(gli, i) != head[i]) SetFailState("Witch::GetLocomotionInterface has an unexpected shape");
		if (Byte(gli, 10) != 0xC3) SetFailState("Witch::GetLocomotionInterface has an unexpected shape");
		g_locoOffset = LoadFromAddress(gli + view_as<Address>(6), NumberType_Int32);
		g_witchVtable = vt + view_as<Address>(8);
	}

	g_update = new DynamicHook(slot, HookType_Raw, ReturnType_Void, ThisPointer_Address);

	// make the page writable once; the per-update writes below skip that step
	StoreToAddress(g_rc + view_as<Address>(g_sites[0]), g_byteOff, NumberType_Int8, true);
	StoreToAddress(g_rc + view_as<Address>(g_sites[1]), g_byteOff, NumberType_Int8, true);

	g_cvEnable = CreateConVar("l4d_witch_corner_fix_enable", "1", "Let a moving witch slide off corners instead of freezing on them", _, true, 0.0, true, 1.0);
	AutoExecConfig(true, "l4d_witch_corner_fix");
	LogMessage("ready (%s): locomotion at witch+0x%X, Update is vtable slot %d", g_windows ? "windows" : "linux", g_locoOffset, slot);

	int w = -1;
	while ((w = FindEntityByClassname(w, "witch")) != -1) HookWitch(w);
}

public void OnPluginEnd()
{
	SetPatch(false);
	for (int i = 0; i < sizeof(g_hookPre); i++) Unhook(i);
}

int Byte(Address base, int off)
{
	return LoadFromAddress(base + view_as<Address>(off), NumberType_Int8) & 0xFF;
}

void SetPatch(bool on)
{
	if (on == g_patched) return;
	int v = on ? g_byteOn : g_byteOff;
	StoreToAddress(g_rc + view_as<Address>(g_sites[0]), v, NumberType_Int8, false);
	StoreToAddress(g_rc + view_as<Address>(g_sites[1]), v, NumberType_Int8, false);
	g_patched = on;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	// the locomotion object is built in Witch::CreateComponents, after creation: wait a frame
	if (entity > MaxClients && entity < 2048 && StrEqual(classname, "witch"))
		RequestFrame(F_Hook, EntIndexToEntRef(entity));
}

public void F_Hook(int ref)
{
	int w = EntRefToEntIndex(ref);
	if (w != INVALID_ENT_REFERENCE) HookWitch(w);
}

void HookWitch(int w)
{
	if (g_hookPre[w] != INVALID_HOOK_ID) return;
	Address loco = view_as<Address>(LoadFromAddress(GetEntityAddress(w) + view_as<Address>(g_locoOffset), NumberType_Int32));
	if (loco == Address_Null) { LogError("witch %d has no locomotion yet", w); return; }
	Address vt = view_as<Address>(LoadFromAddress(loco, NumberType_Int32));
	if (vt != g_witchVtable) { LogError("witch %d locomotion has vtable %X, expected %X; not hooking", w, vt, g_witchVtable); return; }
	g_hookPre[w] = g_update.HookRaw(Hook_Pre, loco, Update_Pre);
	g_hookPost[w] = g_update.HookRaw(Hook_Post, loco, Update_Post);
}

public void OnEntityDestroyed(int entity)
{
	if (entity > MaxClients && entity < 2048) Unhook(entity);
}

void Unhook(int i)
{
	if (g_hookPre[i] != INVALID_HOOK_ID) { DynamicHook.RemoveHook(g_hookPre[i]); g_hookPre[i] = INVALID_HOOK_ID; }
	if (g_hookPost[i] != INVALID_HOOK_ID) { DynamicHook.RemoveHook(g_hookPost[i]); g_hookPost[i] = INVALID_HOOK_ID; }
}

public MRESReturn Update_Pre(Address loco)
{
	if (g_cvEnable.BoolValue) SetPatch(true);
	return MRES_Ignored;
}

public MRESReturn Update_Post(Address loco)
{
	SetPatch(false);
	return MRES_Ignored;
}
