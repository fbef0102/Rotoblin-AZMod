#include <sourcemod>
#include <left4dhooks>

enum /*ZombieManager::*/MobLocationType
{
	SPAWN_NO_PREFERENCE = -1,
	SPAWN_ANYWHERE = 0,
	SPAWN_BEHIND_SURVIVORS,
	SPAWN_NEAR_IT_VICTIM,
	
	SPAWN_SPECIALS_IN_FRONT_OF_SURVIVORS = 3,
	SPAWN_SPECIALS_ANYWHERE,
	
	SPAWN_FAR_AWAY_FROM_SURVIVORS = 5,
	SPAWN_ABOVE_SURVIVORS,
	SPAWN_IN_FRONT_OF_SURVIVORS,
	SPAWN_VERSUS_FINALE_DISTANCE,
	
	// L4D2 only
	SPAWN_LARGE_VOLUME = 9,
	SPAWN_NEAR_POSITION,
};

enum PanicEventStage
{
	STAGE_INITIAL_DELAY,
	STAGE_MEGA_MOB,
	STAGE_WAIT_FOR_COMBAT_TO_END,
	STAGE_PAUSE,
	STAGE_DONE,
};

int g_iOffs_m_mobLocation;
int g_iOffs_m_nPendingMobCount;
int g_iOffs_m_nPanicEventWave;
int g_iOffs_m_bPanicEventActive;
int g_iOffs_m_panicEventStage;

methodmap ZombieManager {
	property MobLocationType m_mobLocation {
		public get() { return LoadFromAddress(view_as<Address>(this) + view_as<Address>(g_iOffs_m_mobLocation), NumberType_Int32); }
		public set(MobLocationType location) { StoreToAddress(view_as<Address>(this) + view_as<Address>(g_iOffs_m_mobLocation), location, NumberType_Int32); }
	}
	
	property int m_nPendingMobCount {
		public get() { return LoadFromAddress(view_as<Address>(this) + view_as<Address>(g_iOffs_m_nPendingMobCount), NumberType_Int32); }
		public set(int count) { StoreToAddress(view_as<Address>(this) + view_as<Address>(g_iOffs_m_nPendingMobCount), count, NumberType_Int32); }
	}
}

methodmap CDirector {
	property bool m_bPanicEventActive {
		public get() { return LoadFromAddress(view_as<Address>(this) + view_as<Address>(g_iOffs_m_bPanicEventActive), NumberType_Int8); }
		public set(bool bActive) { StoreToAddress(view_as<Address>(this) + view_as<Address>(g_iOffs_m_bPanicEventActive), bActive, NumberType_Int8); }
	}
	
	property int m_nPanicEventWave {
		public get() { return LoadFromAddress(view_as<Address>(this) + view_as<Address>(g_iOffs_m_nPanicEventWave), NumberType_Int32); }
		public set(int wave) { StoreToAddress(view_as<Address>(this) + view_as<Address>(g_iOffs_m_nPanicEventWave), wave, NumberType_Int32); }
	}
	
	property PanicEventStage m_panicEventStage {
		public get() { return LoadFromAddress(view_as<Address>(this) + view_as<Address>(g_iOffs_m_panicEventStage), NumberType_Int32); }
		public set(PanicEventStage stage) { StoreToAddress(view_as<Address>(this) + view_as<Address>(g_iOffs_m_panicEventStage), stage, NumberType_Int32); }
	}
}
CDirector TheDirector;

methodmap GameDataWrapper < GameData {
	public GameDataWrapper(const char[] file) {
		GameData gd = new GameData(file);
		if (!gd) SetFailState("Missing gamedata \"%s\"", file);
		return view_as<GameDataWrapper>(gd);
	}
	
	property GameData Super {
		public get() { return view_as<GameData>(this); }
	}
	
	public int GetOffsetOrFail(const char[] key) {
		int offset = this.GetOffset(key);
		if (offset == -1) SetFailState("Missing offset \"%s\"", key);
		return offset;
	}
}
ZombieManager TheZombieManager;

public void OnPluginStart()
{
	GameDataWrapper gd = new GameDataWrapper("l4d_mob_stuff");
	
	g_iOffs_m_mobLocation = gd.GetOffsetOrFail("ZombieManager::m_mobLocation");
	g_iOffs_m_nPendingMobCount = gd.GetOffsetOrFail("ZombieManager::m_nPendingMobCount");
	g_iOffs_m_nPanicEventWave = gd.GetOffsetOrFail("CDirector::m_nPanicEventWave");
	g_iOffs_m_bPanicEventActive = gd.GetOffsetOrFail("CDirector::m_bPanicEventActive");
	g_iOffs_m_panicEventStage = gd.GetOffsetOrFail("CDirector::m_panicEventStage");
	
	delete gd;
	
	HookEvent("create_panic_event", Event_create_panic_event);
}

bool g_bIsMapFinal;
public void OnMapStart()
{
	g_bIsMapFinal = false;
	g_bIsMapFinal = L4D_IsMissionFinalMap();
}

public void OnConfigsExecuted()
{
	TheDirector = view_as<CDirector>(L4D_GetPointer(POINTER_DIRECTOR));
	TheZombieManager = view_as<ZombieManager>(L4D_GetPointer(POINTER_ZOMBIEMANAGER));
}

void Event_create_panic_event(Event event, const char[] name, bool dontBroadcast)
{
	if(g_bIsMapFinal) return;

	ChangeMobLocation(SPAWN_ANYWHERE);
	RemoveBattlefieldLimit();
}

stock void ChangeMobLocation(MobLocationType location)
{
	TheZombieManager.m_mobLocation = location;
}

stock void RemoveBattlefieldLimit()
{
	// 可能有副作用
	TheDirector.m_bPanicEventActive = false;
}

stock void EndPanicEvent()
{
	TheDirector.m_bPanicEventActive = false;
	
	// 看情况用，会直接清零等待生成的小怪数
	// TheZombieManager.m_nPendingMobCount = 0;
	// TheDirector.m_nPanicEventWave = 0;
	
	// 不推荐用，可能没效果
	// TheDirector.m_panicEventStage = STAGE_DONE;
}