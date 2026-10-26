// Fix by Forgetest: https://github.com/jensewe
//  1. (Bug 1) When a Witch get stumbled while playing her pre-kill animation on an incapacitated survivor, she gets stuck in an infinite stumble animation loop
//  2. (Bug 2) When a Witch landing and try to play pre-kill animation on an incapacitated survivor, she gets stuck/frozen in runing animation loop.
//  3. (Bug 3) When a Witch landing after staggered off-edge., she gets stuck sliding for about 5 to 6 seconds.
//  4. (Bug 4 L4D2 only) When a non-startled Wandering Witch is set on fire or hit with a bile bomb, she is unable to climb over ladders or obstacles.
//  	* Fix by other plugin: l4d2_witch_climbing_fix
//  5. (Bug 5) Fixed the bug that witch cancels retreat and comes back to chase survivor again if game starts panic event
// 		* Fix by other plugin: https://github.com/fbef0102/L4D1_2-Plugins/tree/master/l4d_witch_retreat_panic_fix
//
// 作者 Forgetest: https://github.com/jensewe
// 修復:
//  1. (Bug 1) witch 對倒地的倖存者 做 pre-kill 動畫時被震開會無限循環被震動畫
//  2. (Bug 2) witch 做 landing 動畫且對倒地的倖存者 做 pre-kill 動畫時, 會持續往前跑
//  3. (Bug 3) witch被震時從高處掉下低處, 會卡住滑行大概五六秒
//  4. (Bug 4 L4D2 only) 燒到或是丟膽汁給沒有被驚嚇的站立witch, witch無法爬梯障礙物
//  	* 已被其他插件修復: l4d2_witch_climbing_fix
//  5. (Bug 5) witch撤退時如果有導演屍潮事件會重新追擊人類
// 		* 已被其他插件修復: https://github.com/fbef0102/L4D1_2-Plugins/tree/master/l4d_witch_retreat_panic_fix


#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks_anim>
#include <actions>

#include <@Forgetest/gamedatawrapper>

#define PLUGIN_VERSION "1.2"

public Plugin myinfo = 
{
	name = "[L4D & 2] Witch Animation Fix",
	author = "Forgetest",
	description = "Fix witch going stuck when interrupted by stagger.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins",
}

methodmap InfectedStandingActivity < BehaviorAction
{
	property bool m_bAnimationFinished
	{
		public get() { return this.Get(72, NumberType_Int8); }
		public set(bool val) { this.Set(72, val, NumberType_Int8); }
	}

	property int m_activity
	{
		public get() { return this.Get(52, NumberType_Int32); }
	}
}

Handle g_call_MyNextBotPointer;
INextBot MyNextBotPointer(int entity)
{
	return SDKCall(g_call_MyNextBotPointer, entity);
}

Handle g_call_GetBodyInterface;
methodmap INextBot
{
	public ZombieBotBody GetBodyInterface()
	{
		return SDKCall(g_call_GetBodyInterface, this);
	}
}

enum ActivityType 
{ 
	MOTION_CONTROLLED_XY	= 0x0001,	// XY position and orientation of the bot is driven by the animation.
	MOTION_CONTROLLED_Z		= 0x0002,	// Z position of the bot is driven by the animation.
	ACTIVITY_UNINTERRUPTIBLE= 0x0004,	// activity can't be changed until animation finishes
	ACTIVITY_TRANSITORY		= 0x0008,	// a short animation that takes over from the underlying animation momentarily, resuming it upon completion
	ENTINDEX_PLAYBACK_RATE	= 0x0010,	// played back at different rates based on entindex
};

methodmap ZombieBotBody
{
	property int m_activity {
		public get() { return LoadFromAddress(view_as<Address>(this) + view_as<Address>(80), NumberType_Int32); }
		public set(int act) { StoreToAddress(view_as<Address>(this) + view_as<Address>(80), act, NumberType_Int32); }
	}
	
	property ActivityType m_activityType {
		public get() { return LoadFromAddress(view_as<Address>(this) + view_as<Address>(84), NumberType_Int32); }
		public set(ActivityType flags) { StoreToAddress(view_as<Address>(this) + view_as<Address>(84), flags, NumberType_Int32); }
	}
}

ConVar g_cvKillSkipAnim;
ConVar g_cvSkipLand;

public void OnPluginStart()
{
	GameDataWrapper gd = new GameDataWrapper("l4d_witch_anim_fix");

	SDKCallParamsWrapper params[] = {
		{SDKType_PlainOldData, SDKPass_Plain},
	};
	g_call_MyNextBotPointer = gd.CreateSDKCallOrFail(SDKCall_Entity, SDKConf_Virtual, "MyNextBotPointer", _, 0, true, params[0]);
	g_call_GetBodyInterface = gd.CreateSDKCallOrFail(SDKCall_Raw, SDKConf_Virtual, "INextBot::GetBodyInterface", _, 0, true, params[0]);

	delete gd;

	// 1=witch pre-kill期间被震, 如果结束硬直后依然离目标很近, 就直接執行杀人动作
	// 0=witch pre-kill期间被震, 结束硬直后, 重新追人執行 pre-kill 动作
	g_cvKillSkipAnim = CreateConVar(
			"witch_instant_kill_post_stagger",
			"0",
			"Allow witch to instantly go for kill without the warm-up animation if before stagger she attempted to kill and after stagger she's still close to her victim.",
			FCVAR_NONE, true, 0.0, true, 1.0);

	// 1=硬直期間落到地上瞬间会直接取消硬直
	// 0=硬直期間落到地上会繼續硬直直到時間結束
	g_cvSkipLand = CreateConVar(
			"witch_land_cancel_stagger",
			"0",
			"Allow witch to move when landing after staggered off-edge.",
			FCVAR_NONE, true, 0.0, true, 1.0);
		
	AutoExecConfig(true, "l4d_witch_anim_fix");
}

public void OnActionCreated(BehaviorAction action, int actor, const char[] name, ActionId id)
{
	if (!strcmp(name, "InfectedStandingActivity"))
	{
		if (view_as<InfectedStandingActivity>(action).m_activity == GetWitchStandingActivity())
		{
			action.OnStartPost = InfectedStandingActivity_OnStartPost;
			action.OnResumePost = InfectedStandingActivity_OnResumePost;
		}
	}
	else if (!strcmp(name, "InfectedShoved"))
	{
		if (IsWitch(actor))
		{
			action.OnLandOnGroundPost = InfectedShoved_OnLandOnGroundPost;
			action.OnStart = InfectedShoved_OnStart;
		}
	}
}

Action InfectedShoved_OnLandOnGroundPost(BehaviorAction action, int actor, int entity, ActionDesiredResult result)
{
	if (g_cvSkipLand.BoolValue)
		return action.TryDone();

	// Restart shoved anim when staggered off edge
	ForceActivityInterruptible(actor);
	action.IsStarted = false;
	return Plugin_Continue;
}

Action InfectedShoved_OnStart(BehaviorAction action, int actor, any priorAction, ActionResult result)
{
	ForceActivityInterruptible(actor);
	return Plugin_Continue;
}

Action InfectedStandingActivity_OnStartPost(any action, int actor, any priorAction, ActionResult result)
{
	InfectedStandingActivity thisaction = action;

	// Restart the action if it failed to apply new activity
	if (MyNextBotPointer(actor).GetBodyInterface().m_activity != thisaction.m_activity)
	{
		thisaction.IsStarted = false;
	}
	
	return Plugin_Continue;
}

Action InfectedStandingActivity_OnResumePost(any action, int actor, any priorAction, ActionResult result)
{
	InfectedStandingActivity thisaction = action;

	// Leave if the sequence was changed
	if (MyNextBotPointer(actor).GetBodyInterface().m_activity != thisaction.m_activity)
	{
		// If the victim is still close enough to her victim,
		// she will instantly start killing them in next think
		thisaction.m_bAnimationFinished = true;
	}

	// See if we want the witch to re-chase her victim to avoid instantly started killing
	if (!g_cvKillSkipAnim.BoolValue)
	{
		// BUG: We could've just return DONE, but doing so causes a memory leak.
		thisaction.UpdatePost = InfectedStandingActivity_UpdatePost;
	}

	return Plugin_Continue;
}

Action InfectedStandingActivity_UpdatePost(BehaviorAction action, int actor, float interval, ActionResult result)
{
	if (result.action != INVALID_ACTION)
	{
		//result.action = INVALID_ACTION;
		return action.Done("Forced by plugin (l4d_witch_stagger_fix)");
	}

	return Plugin_Continue;
}

bool ForceActivityInterruptible(int infected)
{
	ZombieBotBody body = MyNextBotPointer(infected).GetBodyInterface();
	
	if (GetEngineVersion() == Engine_Left4Dead) // perhaps unnecessary
	{
		switch (body.m_activity)
		{
			case L4D1_ACT_TERROR_JUMP_LANDING,
				L4D1_ACT_TERROR_JUMP_LANDING_HARD,
				L4D1_ACT_TERROR_JUMP_LANDING_NEUTRAL,
				L4D1_ACT_TERROR_JUMP_LANDING_HARD_NEUTRAL: { }
			default: { return false; }
		}
	}
	else if (GetEngineVersion() == Engine_Left4Dead2)
	{
		switch (body.m_activity)
		{
			case L4D2_ACT_TERROR_JUMP_LANDING,
				L4D2_ACT_TERROR_JUMP_LANDING_HARD,
				L4D2_ACT_TERROR_JUMP_LANDING_NEUTRAL,
				L4D2_ACT_TERROR_JUMP_LANDING_HARD_NEUTRAL: { }
			default: { return false; }
		}
	}
	
	body.m_activityType &= ~ACTIVITY_UNINTERRUPTIBLE;
	return true;
}

int GetWitchStandingActivity()
{
	static int act = -1;

	if (act == -1)
	{
		if (GetEngineVersion() == Engine_Left4Dead)
			act = L4D1_ACT_TERROR_WITCH_KILL_DISPLAY;
		else if (GetEngineVersion() == Engine_Left4Dead2)
			act = L4D2_ACT_TERROR_WITCH_KILL_DISPLAY;
	}

	return act;
}

stock bool IsWitch(int entity)
{
	char buffer[16];
	GetEntityClassname(entity, buffer, sizeof(buffer));
	return !strcmp(buffer, "witch");
}

