1. 
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