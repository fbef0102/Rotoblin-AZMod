### 1
* linux
    ```c
    0	0x3547cf85
    1	server.so!SetEventIndexForSequence(mstudioseqdesc_t&) + 0x7f
    2	server.so!CTerrorPlayer::OnMainActivityInterrupted(Activity, Activity) + 0x2a
    3	server.so!NextBotPlayer<CTerrorPlayer>::OnMainActivityInterrupted(Activity, Activity) + 0x2d
    4	server.so!CBasePlayerAnimState::ComputeMainSequence() + 0xec
    5	server.so!CBasePlayerAnimState::ComputeSequences(CStudioHdr*) + 0x10
    6	server.so!CCSPlayerAnimState::ComputeSequences(CStudioHdr*) + 0x26
    7	server.so!CBasePlayerAnimState::Update(float, float) + 0x11f
    8	server.so!CCSPlayerAnimState::Update(float, float) + 0x33
    9	server.so!CCSPlayer::PostThink() + 0xc3
    10	server.so!CTerrorPlayer::PostThink() + 0x47
    11	server.so!CPlayerMove::RunCommand(CBasePlayer*, CUserCmd*, IMoveHelper*) + 0x2a1
    12	server.so!CBasePlayer::PlayerRunCommand(CUserCmd*, IMoveHelper*) + 0x10c
    13	server.so!CCSPlayer::PlayerRunCommand(CUserCmd*, IMoveHelper*) + 0x173
    14	server.so!CTerrorPlayer::PlayerRunCommand(CUserCmd*, IMoveHelper*) + 0x171
    ```
*  Windows
    ```c
    None
    ```

* Crash reason: 
    * Use detour fucnction such as: L4D2_OnEntityShoved, L4D_OnShovedBySurvivor in linux system sourcemod 1.12, then server crashes
    * Sourcemod 1.12 safetyhook issue

* Fix
    * Already fix in latest sourcemod 1.12
	
### 2
* linux
    ```c
    engine.so!CM_VCollideForModel(int, model_t const*) + 0x19
    engine.so!CEngineTrace::ClipRayToVPhysics(Ray_t const&, unsigned int, ICollideable*, studiohdr_t*, CGameTrace*) + 0x11d
    engine.so!CEngineTrace::ClipRayToCollideable(Ray_t const&, unsigned int, ICollideable*, CGameTrace*) + 0xe9
    ```
*  Windows
    ```c
    engine.dll + 0x1d024
    engine.dll + 0x416f3
    engine.dll + 0x1acbf
    ```

* Crash reason: 
    * c6m2_bedlam.cfg
        ```c
        {
            "classname" "func_brush"
            "origin" "437 1943.5 -16.5"
            "targetname" "losfix_bar_fence1"
        }
        {
            "classname" "logic_auto"
            "OnMapSpawn" "losfix_bar_fence1,AddOutput,mins -5 -0.5 -47.5,0,-1"
            "OnMapSpawn" "losfix_bar_fence1,AddOutput,maxs 5 0.5 47.5,0,-1"
            "OnMapSpawn" "losfix_bar_fence1,AddOutput,solid 2,0,-1"
        }
        ```
    * On L4D1 the server can segfault during map load
        ```c
        segfault at 6c ... in engine.so (+0xAF6D5)
        CM_VCollideForModel(int, model_t const*)
        CEngineTrace::ClipRayToVPhysics
        CEngineTrace::TraceRay
        ZombieManager::IsSpaceForZombieHere
        ZombieManager::OnFlowDistancesInitialized
        TerrorNavMesh::InitializeFlowDistances
        CTerrorGameRules::RestartRound
        Director::OnMapLoaded
        ```
    * The srripper cfg adds LOS blockers as func_brush entities with no model. A logic_auto then sets their size and solidity with AddOutput mins/maxs/solid 2.
    * Until those outputs fire on the first simulated tick, CFuncBrush::Spawn leaves each brush as SOLID_VPHYSICS with a NULL model_t.
    * During load the engine computes flow distances and hull-traces nav spots (IsSpaceForZombieHere).
    * L4D1's CM_VCollideForModel reads pModel->type at offset 0x6c with no NULL check. L4D2 seems to tolerate the NULL model.
    * So any trace that touches one of these brushes before the outputs fire crashes the server.
    * In both core dumps the entity was losfix_bar_fence1, from the "Fix gate by the bar lacking proper collisions" block. That gate has no collision, so the nav mesh runs straight through the brush origin. The tested spot is random, which is why the crash is intermittent.

* Fix
    * Spawn the brushes disabled and enable them only after they have become a real BBOX:
        ```c
        {
            "classname" "func_brush"
            "StartDisabled" "1"
            "origin" "437 1943.5 -16.5"
            "targetname" "losfix_bar_fence1"
        }
        {
            "classname" "logic_auto"
            "OnMapSpawn" "losfix_bar_fence1,AddOutput,mins -5 -0.5 -47.5,0,-1"
            "OnMapSpawn" "losfix_bar_fence1,AddOutput,maxs 5 0.5 47.5,0,-1"
            "OnMapSpawn" "losfix_bar_fence1,AddOutput,solid 2,0,-1"
            "OnMapSpawn" "losfix_bar_fence1,Enable,,0,-1"
        }
        ```
    * StartDisabled makes the brush FSOLID_NOT_SOLID at spawn, so traces skip it.
    * Enable then clears that flag, and the brush ends up as solid 2 with the correct bounds, which is what the cfg intends. I checked this by firing the inputs from a debug plugin.
    * The attached patch applies this to all 10 model-less brushes in the bedlam cfg.