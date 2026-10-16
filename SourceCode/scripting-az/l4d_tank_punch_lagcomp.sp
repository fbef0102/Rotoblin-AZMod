// Found by Malevolence, fixed by Forgetest
// 在 L4D 中，只有當你按住攻擊鍵不放時，Tank 的揮拳（Punch）才會享有延遲補償（Lag compensation）。
// 遊戲只會在你有按住攻擊鍵時，將倖存者回溯（Rewind）到你畫面上看到的位置。
// 但是，Tank 揮拳在點擊滑鼠左鍵（M1）後，要過 0.5 秒才會真正進行命中判定（蓄力期間）。
// 因此，如果你像幾乎所有人一樣只是點擊一下（Tap M1）就鬆手，遊戲就會拿你的拳頭去比對伺服器上倖存者此時此刻的實際位置，而不是你在畫面上有看到的那個位置。
//
// 這是 Valve 的原版程式碼（Stock Valve code）。Source 引擎「只在開火時回溯玩家」的規則對於槍枝來說很合理，但沒有人針對揮拳這種「點擊後半秒才命中」的攻擊進行調整。
// 奔跑中的倖存者可能跟你在畫面上看到的相差大約 20 個單位（如果有延遲會更大），而拳頭的判定範圍只有 15 個單位寬。
//
// 經由Malevolence實測：揮拳過程中一直按住 M1，360 次判定全部都有吃到延遲補償；如果用點擊的：360 次中 0 次。

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <left4dhooks>

public Plugin myinfo = 
{
	name = "Tank Punch Lag Compensation",
	author = "Forgetest",
	description = "A human tank's punch is lag compensated whether he taps or holds attack.",
	version = "1.0-2026/10/16",
	url = "https://github.com/jensewe"
}

public void L4D_TankClaw_DoSwing_Pre(int tank, int claw)
{
	CUserCmd cmd = GetPlayerCurrentCommand(tank);
	if (cmd)
	{
		SetPlayerLastWeaponFireUsercmd(tank, cmd.command_number);
	}
}

public void L4D_TankClaw_GroundPound_Pre(int tank, int claw)
{
	L4D_TankClaw_DoSwing_Pre(tank, claw);
}

void SetPlayerLastWeaponFireUsercmd(int client, int value)
{
	static int offs_m_iLastWeaponFireUsercmd = -1;
	if (offs_m_iLastWeaponFireUsercmd == -1)
		offs_m_iLastWeaponFireUsercmd = FindSendPropInfo("CCSPlayer", "m_angEyeAngles[0]") - 4;
	
	SetEntData(client, offs_m_iLastWeaponFireUsercmd, value, 4);
}

methodmap Address {}

methodmap CUserCmd < Address
{
    property int command_number {
        public get() { return LoadFromAddress(view_as<Address>(this) + view_as<Address>(4), NumberType_Int32); }
    }
}

CUserCmd GetPlayerCurrentCommand(int player)
{
	static int s_iOffs_m_pCurrentCommand = -1;
	if (s_iOffs_m_pCurrentCommand == -1)
		s_iOffs_m_pCurrentCommand = FindDataMapInfo(player, "m_hViewModel")
									+ 4*2 /* CHandle<CBaseViewModel> * MAX_VIEWMODELS */
									+ 88 /* sizeof(m_LastCmd) */;

	return view_as<CUserCmd>(GetEntData(player, s_iOffs_m_pCurrentCommand, 4));
}
