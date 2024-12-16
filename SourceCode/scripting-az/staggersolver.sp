#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>
#include <dhooks>

public Plugin myinfo =
{
	name = "Super Stagger Solver",
	author = "CanadaRox, A1m (fix), Sir (rework), Forgetest, Harry",
	description = "Blocks all button presses and fix survivors' animations or stuck on ladder during stumbles by hunters",
	version = "2.4h-2024/10/18",
	url = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    EngineVersion test = GetEngineVersion();

    if( test != Engine_Left4Dead )
    {
        strcopy(error, err_max, "Plugin only supports Left 4 Dead 1.");
        return APLRes_SilentFailure;
    }
    return APLRes_Success;
}

/**
 * 修復以下第一個官方bug
 * 爬梯子時被Hunter控然後解控，如果還黏在梯子上會導致第三人稱卡住，無法恢復第一人稱並無法移動 (任何按鍵均無效)
 * (一代被boomer 瓦斯桶震退到不會有這bug)
 * (二代不會發生)
 */
methodmap GameDataWrapper < GameData {
	public GameDataWrapper(const char[] file) {
		GameData gd = new GameData(file);
		if (!gd) SetFailState("Missing gamedata \"%s\"", file);
		return view_as<GameDataWrapper>(gd);
	}
	property GameData Super {
		public get() { return view_as<GameData>(this); }
	}
	public int GetOffset(const char[] key) {
		int offset = this.Super.GetOffset(key);
		if (offset == -1) SetFailState("Missing offset \"%s\"", key);
		return offset;
	}
	public DynamicDetour CreateDetourOrFail(
			const char[] name,
			DHookCallback preHook = INVALID_FUNCTION,
			DHookCallback postHook = INVALID_FUNCTION) {
		DynamicDetour hSetup = DynamicDetour.FromConf(this, name);
		if (!hSetup)
			SetFailState("Missing detour setup \"%s\"", name);
		if (preHook != INVALID_FUNCTION && !hSetup.Enable(Hook_Pre, preHook))
			SetFailState("Failed to pre-detour \"%s\"", name);
		if (postHook != INVALID_FUNCTION && !hSetup.Enable(Hook_Post, postHook))
			SetFailState("Failed to post-detour \"%s\"", name);
		return hSetup;
	}
}

int g_iOffs_pTerrorPlayer;

public void OnPluginStart()
{
	GameDataWrapper gd = new GameDataWrapper("staggersolver");
	g_iOffs_pTerrorPlayer = gd.GetOffset("CTerrorGameMovement::pTerrorPlayer");
	delete gd.CreateDetourOrFail("CTerrorGameMovement::LadderMove", DTR_LadderMove);
	delete gd.CreateDetourOrFail("CTerrorGameMovement::CheckForLadders", DTR_CheckForLadders);
	delete gd;
}

MRESReturn DTR_LadderMove(DHookReturn hReturn, DHookParam hParams)
{
	int client = hParams.GetObjectVar(1, g_iOffs_pTerrorPlayer, ObjectValueType_CBaseEntityPtr);
	if (client == -1 || !IsClientInGame(client))
		return MRES_Ignored;
	
	if (AllowLadderCheck(client))
		return MRES_Ignored;

	hReturn.Value = 0;
	return MRES_Supercede;
}

MRESReturn DTR_CheckForLadders(DHookParam hParams)
{
	int client = hParams.GetObjectVar(1, g_iOffs_pTerrorPlayer, ObjectValueType_CBaseEntityPtr);
	if (client == -1 || !IsClientInGame(client))
		return MRES_Ignored;
	
	if (AllowLadderCheck(client))
		return MRES_Ignored;
	
	return MRES_Supercede;
}

bool AllowLadderCheck(int client)
{
	static int s_iLeft4Dead1 = -1;
	if (s_iLeft4Dead1 == -1)
		s_iLeft4Dead1 = view_as<int>(L4D_IsEngineLeft4Dead1());
	
	if (s_iLeft4Dead1)
	{
		static int s_iOffs_m_nSequenceActivity = -1;
		if (s_iOffs_m_nSequenceActivity == -1)
			s_iOffs_m_nSequenceActivity = FindSendPropInfo("CTerrorPlayer", "m_survivorCharacter") - 12;
		
		int activity = GetEntData(client, s_iOffs_m_nSequenceActivity, 4);
		switch (activity)
		{
			case L4D1_ACT_TERROR_POUNCED_TO_STAND:
				return false;
		}
	}
	else
	{
		int activity = PlayerAnimState.FromPlayer(client).GetMainActivity();
		switch (activity)
		{
			case L4D2_ACT_TERROR_POUNCED_TO_STAND:
				return false;
		}
	}

	return true;
}

bool g_bInStumble[MAXPLAYERS+1];

// 倖存者被Hunter撲的時候，震開周圍的隊友
// client = 被震的隊友, attacker = hunter
public Action L4D2_OnPounceOrLeapStumble(int client, int attacker)
{
	g_bInStumble[client] = true;
	return Plugin_Continue;
}

// This forward will ONLY trigger if the relative pre-hook forward has been blocked with Plugin_Handled
public void L4D2_OnPounceOrLeapStumble_PostHandled(int client, int attacker)
{
	g_bInStumble[client] = false;
}

// @remarks This forward will not trigger if the relative pre-hook forward has been blocked with Plugin_Handled
public void L4D2_OnPounceOrLeapStumble_Post(int client, int attacker)
{
	// 修復第二個官方bug
	// 在爬梯子時被Hunter震退，如果還黏在梯子上會導致無法移動上下左右 (空白鍵依然可以按)
	// 二代也會發生
	if (GetEntityMoveType(client) == MOVETYPE_LADDER)
	{
		SetEntPropVector(client, Prop_Send, "m_shoveForce", NULL_VECTOR);
		SetEntityMoveType(client, MOVETYPE_WALK);
		SetEntProp(client, Prop_Data, "m_MoveCollide", 0);
	}

	g_bInStumble[client] = false;
}

//修復第三個官方bug: 被震退期間再被震退第二次會導致第二次的震退動畫強制取消並立刻行動
public Action L4D_OnCancelStagger(int client)
{
	return g_bInStumble[client] ? Plugin_Handled : Plugin_Continue;
}

// Block buttons when stumble
public Action OnPlayerRunCmd(int client, int &buttons)
{
	if (IsClientInGame(client) 
	&& IsPlayerAlive(client)
	&& L4D_IsPlayerStaggering(client))
	{
		/*
			* If you shove an SI that's on the ladder, the player won't be able to move at all until killed.
			* This is why we only apply this method when the SI is not on a ladder.
		*/
		if (GetEntityMoveType(client) != MOVETYPE_LADDER) {
			buttons = 0;
			return Plugin_Changed;
		}
	}
	return Plugin_Continue;
}