// Found by Malevolence, fixed by Forgetest
//發生原因（What it was）： 兩次傷害都發生在同一個伺服器 Tick（伺服器影格）之內。
//倖存者自身的移動碰觸到了零距離（Point-blank）的石塊，這會呼叫 CTankRock::BounceTouch 並造成 24 點傷害。
//倖存者存活下來，因此石塊呼叫了 Detonate()，而 UTIL_Remove 僅將石塊標記為待刪除（EFL_KILLME）。該實體實際上是在該 Tick 結束時才真正移除。
//然而，在同一個 Tick 的稍後時間點，石塊的 ProximityThink 仍然會執行，因為遊戲引擎是在迴圈開始時就對 Think 列表進行快照（Snapshot），且絕不會略過被標記的實體。
//該函式從未檢查刪除旗標（Kill flag）。它發現同一個倖存者依然存活且位於 z_tank_rock_radius 範圍內，於是直接呼叫了 BounceTouch。
//這繞過了引擎的碰撞防護機制（Touch guards，該機制會檢查刪除旗標），因此造成了第二次 24 點傷害。   
//
//為什麼這個 Bug 這麼罕見（Why it's so rare）： 玩家與石塊在一個 Tick 內的執行順序每次 Tick 都在變動，且受害者必須排在前面。
//由於 Bot（電腦玩家）的 usercmd 執行順序在石塊之後，因此 Bot 受害者絕對不可能發生雙倍傷害。
//這就是為什麼我們找到的所有真實雙倍傷害案例都是人類受害者，也解釋了為什麼用 Bot 進行測試始終無法重現。
//此外，這也需要零距離投擲（Point-blank throw）。在我们回放（Replays）大約 1,650 次的石塊命中中，只有 4 次雙倍傷害，全都是零距離，約佔零距離命中的 1.7%。   
//
//Malevolence是如何發現的（How we found it）： 幾個月來的測試環境與即時日誌（Live logging）從未捕捉到它。
//因此，我們將 Linux 的 server.so 載入到 Ghidra 中（它仍然保留著函式名稱），並讀取了 CTankRock::BounceTouch、ProximityThink、Detonate 以及引擎的 Think 迴圈。
//反編譯結果顯示，ProximityThink 直接呼叫了 BounceTouch 且沒有進行刪除旗標檢查，並且在該路徑中繞過了本應阻擋第二次命中的碰撞防護機制

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>

public Plugin myinfo = 
{
	name = "Fix Tank Rock Double Hit",
	author = "Forgetest",
	description = "Stops one tank rock hurting a survivor twice",
	version = "1.0-2026/10/16",
	url = "https://github.com/jensewe"
}

public void OnEntityDestroyed(int entity)
{
	if (entity > MaxClients && entity < 2048 && IsEntityClassname(entity, "tank_rock"))
	{
		AddEntityEFlags(entity, (1<<22)); // EFL_NO_THINK_FUNCTION = (1<<22)
	}
}

void AddEntityEFlags(int entity, int value)
{
	int flags = GetEntProp(entity, Prop_Data, "m_iEFlags");
	SetEntProp(entity, Prop_Data, "m_iEFlags", flags | value);
}

bool IsEntityClassname(int entity, const char[] classname)
{
	int len = strlen(classname);
	if (len == 0)
		return false;

	char buffer[64];
	GetEntityClassname(entity, buffer, sizeof(buffer));
	return classname[len-1] == '*' ? !strncmp(buffer, classname, len-1) : !strcmp(buffer, classname);
}