# Rotoblin-AZMod
v8.5.9
<br/>Developer @ 2017-2024 [Harry](http://steamcommunity.com/profiles/76561198026784913)
<br/><img src="https://i.imgur.com/FGkLDMp.png">
- [Navigation](#rotoblin-azmod)
    - [Server Install | 如何安裝](#server-install)
    - [Server Anti Cheat | 反作弊插件](#server-anti-cheat)
    - [Server Admins | 管理員選項](#server-admins)
    - [Gamemodes | 遊戲模式](#gamemodes)
    - [Votes Menu | 投票介面](#votes-menu)
    - [Map Changes | 地圖路線變更](#map-changes)
    - [Custom Map Support | 支援的三方圖](#custom-map-support)
    - [Weapon Adjustments | 武器調整](#weapon-adjustments)
    - [Score Calculation | 對抗分數計算方式](#score-calculationhealthbonus)
    - [Bug / Exploit Fixes | Bugs修復](#bug--exploit-fixes)
    - [Gameplay / Balance Changes | 遊戲平衡改動](#gameplay--balance-changes)
    - [Miscellaneous | 雜項](#miscellaneous)
    - [Support L4D2onL4D1 maps | 支援二代圖](#roto-az-l4d2onl4d1)
    - [Others | 其他](#others)
    - [Chinese | 繁體中文說明](/Developer%26Commands/繁體說明書.txt)
    - [Developer | 作者介紹](/Developer%26Commands/Roto-AZMod%20Developer.cfg)
    - [Project Source Code | 專案源碼](/SourceCode)

**LINUX/WINDOWS SERVERS WORK**
* This repository only supports Sourcemod 1.11 and up.

A Competitive L4D1 Versus Configuration. Based upon the L4D2 [Acemod V4 Release](http://imgur.com/a/8Ptck)、L4D2 [Zonemod](https://github.com/SirPlease/L4D2-Competitive-Rework)、L4D1 [rotoblin2](https://github.com/raziEiL/rotoblin2). Roto-AZMod's focus is not only to make setting things up a lot easier for Server but also to make more difficult challenges and add some features such as Uzi more powerful, Hunting Rifle avaible, increase max damage pounce, more Tank hp and more map changes. The whole environment is similar to l4d2, but don't worry, the core is still around l4d1 gameplay.

- - - -	
### If you appreciate my work, please [PayPal Donate](https://paypal.me/Harry0215?locale.x=zh_TW) me.

- - - -
### Server Install ###
* Clean Servers:
  * A clean [L4D1 Dedicated Server](https://github.com/fbef0102/L4D1-Server4Dead/blob/master/README.md#how-to-download-l4d1-dedicated-server-files)
  * Make sure your server is stopped.
  * Delete left4dead/addons folder on your server (to make sure you have a clean slate).
  * Go [Releases Page](https://github.com/fbef0102/Rotoblin-AZMod/releases) and download **l4d1_Roto-AZMod.zip**
* Requirements:
  * Install "Windows Server files" or "Linux Server files" (depending on the operating system of your server), this contains Sourcemod v1.11 or above, Metamod v1.11 or above, Stripper, Tickrate, and other extensions
  * Install "Roto-AZMod Main files", this contains the configs, plugins, gamedate, and other server settings.
  * At this step, you already setup Server's base for configs, so you can finally start the server.
* Launch parameters:
  * ```-console -game left4dead +log on +map l4d_vs_airport01_greenhouse +exec server +sv_lan 0 -tickrate 100 -maxplayers 31```
	
- - - -	
### Server Install Optional ###
* [Auto_restart](https://github.com/fbef0102/L4D1_2-Plugins/tree/master/linux_auto_restart) is a useful plugin, restart server as soon as all human players are disconnected. Recommended for **LINUX**
* [L4D Modified Talker](https://www.gamemaps.com/details/3863) is an addon which improves the survivor's conversation. It includes many exclusive dialogues, unused survivor's speeches and every survivor has more than 15 kinds of laughter now!
* [Top 5 Skeet](https://github.com/fbef0102/L4D1_2-Plugins/tree/master/skeet_database) records players' skeets, and save to server-side Database.
* [Top 5 Pounce](https://github.com/fbef0102/L4D1_2-Plugins/tree/master/pounce_database) records players' pounces, and save to server-side Database. 
* [Gag/Mute/Ban Ex](https://github.com/fbef0102/L4D1_2-Plugins/tree/master/GagMuteBanEx) enhances and improves ban/gag/mute for admin.
* [simple-chatcolors](https://github.com/fbef0102/Game-Private_Plugin/tree/main/Plugin_%E6%8F%92%E4%BB%B6/Fun_%E5%A8%9B%E6%A8%82/simple-chatcolors) Changes the colors of players chat based on config file.
* [l4d_flashlight_speconly](https://github.com/fbef0102/Game-Private_Plugin/tree/main/Plugin_%E6%8F%92%E4%BB%B6/Spectator_%E6%97%81%E8%A7%80%E8%80%85/l4d_flashlight_speconly) Attaches an extra flashlight to spectators and dead survivors.
* [Private_Plugin](https://github.com/fbef0102/Game-Private_Plugin#l4d12-plugin-list--l4d1%E5%92%8C2%E6%8F%92%E4%BB%B6%E5%88%97%E8%A1%A8) Harry personal private plugins (Paid)

- - - -	
### Server Anti Cheat ###
* [Sourcemod_Anti-Cheat-SMAC](https://github.com/fbef0102/SMAC): Server-side sourceMod Anti-Cheat plugin, I modfidy some codes to make them compatible with Roto-AZMod.
* [Little-Anti-Cheat](https://github.com/fbef0102/Little-Anti-Cheat): Free and open source anti-cheat for source games. Helpful in dealing with cheaters such as aimbot, bunnyhop, aimlock.
  > **Developer Comment:** I highly recommend to install both, you would be surprised that they are still many cheaters in l4d1 even after 15 years.

- - - -
### Server Admins! ###
**Warning: If you try to use the plugins which are included in this package in other configs, plugins may not work correctly
as they're designed around Roto-AZMod and are likely to be unstable in other configs or general usage.**

* Admin simplicity:
  * [Be Adm](https://wiki.alliedmods.net/Adding_Admins_(SourceMod)#Quick_Start): -left4dead/addons/sourcemod/configs/admins_simple.ini
  * MatchMod: -left4dead/addons/sourcemod/configs/matchmodes.txt
  * Advertisements: -left4dead/addons/sourcemod/configs/advertisements.txt
  * HostName: -left4dead/addons/sourcemod/configs/hostname/server_hostname.txt
  * Mapcyclelist: -left4dead/addons/sourcemod/data/sm_l4dvs_mapchanger.txt、sm_l4dco_mapchanger.txt
  * CustomMapVote: -left4dead/addons/sourcemod/configs/VoteCustomCampaigns.txt
  * Save player chat (and team chat) to a file: -left4dead/addons/sourcemod/logs/chat/
  * Control Map Info: -left4dead/addons/sourcemod/data/mapinfo.txt
  * Rcon passeword、rates、maxplayers、tags、group: -left4dead/cfg/server.cfg、server_rates.cfg、server_startup.cfg
  * [Translations](/Developer%26Commands/Translation%20Language.txt): -left4dead/addons/sourcemod/translations/Roto2-AZ_mod.phrases.txt
  * If you have a prefered edition of a Plugin, you are able to simply replace the file in sourcemod/plugins folder.
    * do not overwrite any plugin that's existed.
  * To make it easy for personal configuration for certain plugins, there's an added "server_custom_convars.cfg" in the left4dead/cfg/Reloadables folder.
    * Keep in mind that this is a shared cfg, server excutes it after every mode loaded and map change, so it'll only contain shared cvars.
    * very useful for Admins wanting to load 1v1~5v5 supported plugins on top of the Configs.
	  - *For people who don't like "extra pills on the map"*: ```rotoblin_health_style 3```
	  - *For people who don't like "Who will be the tank"*: ```tank_control_disable 1```
	  - *For people who don't like "Pill Extra Health Bonus"*: ```l4d_score_healthbounus_pill 0```

* Admin Tips:
  * bequiet.smx is a very useful plugin to keep chat clean, if you decide to load it in other configs, make sure it's loaded before other plugins.
    * Block name change announcement
    * Block server convars change announcement
    * Block chat with '!' or '/'
  * l4d_versus_specListener3.0.smx comes with a "Spec-Listening Feature", even if sv_alltalk 0, spectators can still see in-game players teamchat and hear their mic voice. To close this feature, use ```sm_hear```.
  * TickRateFixes now also fixes Slow Doors and Pistol Scripts, useful for use with other configs.
    * Make sure you're not loading l4dpistoldelay if you're using this Plugin.
    * Make sure you don't have any adjustments to prop_rotating and prop_rotating_checkpoint speeds in your cfg/stripper folder.
    * The cvar controlling the door speed is "tick_door_speed" and is set to 1.3 by default.
  * Specrates.smx is a useful plugin to reduce server load causes by spectators.
    * This will send less updates to Spectators whilst maintaining a pleasant viewing experience.
  * When player connects or disconnected, it would print the message to everyone, only adms can see steamid .
  * All4Dead.smx allows administrators to influence what the AI director does without sv_cheats. it's a menu system which is attached to the sm_admin menu
  * votes3.smx makes All players can not call a valve vote (esc->vote). Remeber if player wants to call a vote, use ```sm_votes``` instead!!
  * Adm type ```sm_slots <#>``` to forcechange server slots
  * [All Admin commands](/Developer%26Commands/Roto-AZMod%20Adm%20Commands.cfg)
  * [Everyone commands](/Developer%26Commands/Roto-AZMod%20Everyone%20Commands.cfg)
  * Sever Startup default Mode is "Pub VS", there are some limits in pub mode
    * forces survivors and infected to spectate if they're AFK after certain time.
    * team Switch is not allowed after game starts for at least 60 seconds. (To close this feature, set l4d_teamswitch_during_game_seconds_block 0)
    * shoot teammate = shoot yourself.
    * anti open saferoom door and prevent players from leaving safe area within some seconds.
    > **Developer Comment:** make some changes to prevent idiots and griefers, so let newbies enjoy and play :D

- - - -
### Gamemodes ###
> __Note__ Type !load, !match, !mode
* 5v5
  * Hunters only
  * No Boomer
  * Hardcore

* 4v4 
  * Hunters only
  * No Boomer
  * Hardcore
  * [Classic](https://steamcommunity.com/groups/ibserver#announcements/detail/1688172020573940161) 
  * 4v4 Pub
  * 4v4 Pub Hunters only

* 3v3
  * Hunters only
  * No Boomer
  * Hardcore

* 2v2
  * Hunters only
  * No Boomer
  * Hardcore

* 1v1
  * Hunters only
  
* Skeet Practice
  * [l4d1 Multi Hunters](https://steamcommunity.com/groups/ibserver#announcements/detail/2924417816908996494)
  <br/><img src="https://i.imgur.com/ycHlIRZ.jpg">
  * [l4d1 Witch Party](https://steamcommunity.com/groups/ibserver#announcements/detail/1720837068961859143)  
  <br/><img src="https://i.imgur.com/72oUS2W.jpg">

  > **Developer Comment:** Add glow effect to items in "Skeet Practice" mode, which helps players quickly get familiar with the maps
  > * Survivor can see pills、kits、weapons、ammo
  > * Infected can see hittable objects、alarm car

* Special
  * Dark Coop (A super difficult, dark, and challenging gamemode, there are many cool things you will nerver see in realism game)
  <br/><img src="https://i.imgur.com/IMVp3NI.jpg">
      
- - - -
### Votes Menu ###
> __Note__ Type !votes
* Turn On/Off Ready Plugin
* Give HP
* Turn On Alltalk
* Turn Off Alltalk
* Restartmap
* Change maps
* Change addon map
* Kick player
* Forcespectate player
   
- - - -
### Map Changes ###
<br/><img src="https://i.imgur.com/JDlwzs7.jpg">
<br/><img src="https://i.imgur.com/cgkKT9S.jpg">
<br/><img src="https://i.imgur.com/h4I6s9c.jpg">
<br/><img src="https://i.imgur.com/nQlwMhT.jpg">
<br/><img src="https://i.imgur.com/mCW8LHK.jpg">
<br/><img src="https://i.imgur.com/4B5MaSD.jpg">
<br/><img src="https://i.imgur.com/gTvOcdd.jpg">
* **General:**
  * Remove restricted invisible wall Infected couldn't go through
  * Remove miniguns and machine guns
  * Extra Pills
    * Limit 2 pill in cabinets, but the pill is not fixed spawn
    * On the road: 1~2 pills
    * Final rescue area: 4 pills
  * Cleaned up the Maps from Junk Props that you could get stuck on, allowing for smoother movement.
  * Added Many obstacles and barriers (Based on [Roto2](https://github.com/raziEiL/rotoblin2/tree/master/left4dead/addons/stripper/maps)、[L4D2 TLS](https://github.com/jacob404/Official-Vscripts-Decompiled/tree/master/update)、[Zonemod](https://github.com/SirPlease/L4D2-Competitive-Rework/tree/master/cfg/stripper/zonemod))
  * Make distance score correspond to final rescue event progress
  * Remove item spawns in bad locations or excessive density in a location
  
* **Nav Remake:**
  * No Mercy Map 1~5
  * Crash Course Map 1~2
  * Death Toll Map 1~5
  * Dead Air Map 1~5
  * Blood Harvest Map 1~5
  * The Sacrifice Map 1~3

- - - -
### Custom Map Support ###
> __Note__ Type !votes -> Change addon map
* [City 17](https://www.gamemaps.com/details/27815)
* [Suicide Blitz](https://www.gamemaps.com/details/28744)
* [Dead Flag Blues](https://www.gamemaps.com/details/28743)
* [I Hate Mountains](https://www.gamemaps.com/details/28748)
* [Dead Before Dawn](https://www.gamemaps.com/details/27816)
* [The Arena of the Dead](https://www.gamemaps.com/details/28749)
* [Death Aboard](https://www.gamemaps.com/details/28747)
* [One 4 Nine](https://www.gamemaps.com/details/28745)
* [Dark Blood](https://www.gamemaps.com/details/28746)
* [Blood Harvest APOCALYPSE](https://www.gamemaps.com/details/27736)
* [Precinct 84](https://www.gamemaps.com/details/27737)
* [City Of The Dead](https://www.gamemaps.com/details/25778)
* [Dead Vacation](https://www.gamemaps.com/details/30523)
* [Undead Zone](https://www.gamemaps.com/details/31513)

- - - -
### Weapon Adjustments ###
* **Uzi** (based on Acemod/Zonemod)
  * Still Spread: 0.32->0.22
  * Moveing Spread: 3.0->2.0
  * Ammo: 480->800
  * Damage Drop-off: 0.84->0.78
  * Reload Speed: 2.23->1.8
  * Damage: 20->22
  * Limit: 3
  * FF Protect Range: 37
      
* **Pumpshotgun**
  * Air Spread: 2.5->1.5
  * Ammo: 128->96
  * Limit: None
  * FF Protect Range: 37

* **Pistol**
  * FF Protect Range: 25

* **Hunting Rifle**
  * Empty Reload Time: 1->1.25
  * Normal Reload Time: 1 (unchanged)
  * Pickup Time: 1 (unchanged)
  * Swtich Time: 1 -> 1.8
  * Rate of fire: 1->0.2
  * Tank dmg: 90->120
  * Hunter dmg: Chest 250, Stomach 168
  * Limit: 1
  * FF Protect Range: 25
  > **Developer Comment:** As we've noticed in L4D1, the Uzis were completely nothing and shotguns were taking over everything. In the release of Roto-AZMod, I want to make the Uzi more attractiv, which result into the Uzi having more advantages. And there can be a sniper in a team, this Hunting Rifle is nerfed a lot as you can see rate of fire is very slow. Peope can choose thier desired weapons. Each performs one's own best part in a team.

- - - -
### Score Calculation(!health/!bonus) ###
* ( AD + HB + PILLS ) x Alive x Map 
   * AD = Average distance
   * HB = Health Bonus, (PermanentHealth/2) + (TemporaryHealth/4)
   * PILLS = 15 Health Bonus per pill
   * Alive = Number of players that survived
   * Map = That level's score multiplier
   > **Developer Comment:** This effectively gives you a higher reward for holding onto pills, we encourage player to search pills. And restore level's score multiplier as we consider it's unfair that short map and long map have the same maximum score

- - - -
### Bug / Exploit Fixes ###
* Blocking a rocket jump exploit (with pipebomb/molotov/tank rock/common head).
* Prevents firework crates, gascans, oxygen and propane tanks being pushed when players walk into them.
* Allows bots to shoot while a PipeBomb projectile is active on the map.
* Survivors cannot hear ghost footsteps and spawn sound.
* Stops Shoves slowing the Tank Down
* Fixed Players being able to exploit switching team to get earlier SI Spawns.
* Fixed a Valve Bug where you could see Shadows from Infected (Common and SI) through Walls, Floors and Ceilings.
* Fixed no Survivor bots issue and more than 4 bots issue.
* Fixes some survivors [health expolit](https://forums.alliedmods.net/showthread.php?t=198915)
     * Regeneration - You should have less than 30hp before hang on a ledge, when teammates help you the game give a little health bonus.
     * Increasing of health limit - If you have a temporary health (pills) and you're hanging on a ledge look at health bar.
     * Disappearance of the temporary health - When survivors pulled you from the ledge pills health is disappears if it was.
* Ensures that survivors that have been incapacitated with a hittable object get their temp health (300hp) set correctly
* Prevents calling votes while others are loading
* Boomer and Smoker Heard Vocalizations are restored. In the original game they are not used most likely due to clustering the constant vocalization of special infected in the area.
* Blocking [exploits by using Engine](https://forums.alliedmods.net/showthread.php?t=182002)
     * no fall damage bug - jump on the incapped survivor while holding USE key
     * health boost glitch - heal yourself while under water.
* Fixes the problem where tank-punches get a survivor stuck in the roof
* Smash nonstaggering Zombies (stuck or no shove off)
* Fixed the problem that versus director won't spawn Witch during Tank alive
* Avoid confusion of the witch, when startled by a player who has the same character as another.
* Kills survivors before the score is calculated so they don't get full distance and health bonus if they are incapped as the rescue vehicle leaves.
* Blocked Survivor duck fastspeed block & Infected alive duck fastspeed block
* Blocked an exploit where players can remove textures from their game to see through walls.
* Blocked an exploit with players using third person shoulder.
* Hunters don't fall off of walls after being shot.
* AI special infected deal and take the same damage as players. This makes it possible to skeet AI Hunter.
* Players cannot skip their deathcam by pressing space or clicking.
* Block Infected player who use E+spawn expolit to teleport to survivor
     * use E+Spawn Glitch twice will be kicked and banned
* Block pumpshotgunswap quick shoot
* Players that use an exploit to skip spawn timer will now have few seconds staying spectator team
* Ammo pickup fix
* Prevents people from blocking players who climb on the ladder including tank.
* Spectators stay spectator on map change.
* Forces all players on the right team after map/campaign/match change"
* Fixed players using bunnyhop to increase their MaxSpeed.
* Fixed second team having different SI spawns on round start.
     * Spawns for the first hit are announced once round starts.
* Blocks all button presses during stumbles
* Disallows special infected from breaching into safe room by preventing them from spawning nearby the safe room door([video](https://www.youtube.com/watch?v=-w1iWOx72LU&t=400s))
* Fixes an exploit where unlimited grenades could be created.
* Mother fucker no collisions to fix a handful of silly collision bugs in l4d1
     * Rocks go through Common Infected (and also kill them) instead of possibly getting stuck on them
     * Pulled Survivors go through Common Infected
     * Rocks go through Incapacitated Survivors (Won't go through new incaps caused by the Rock)
     * Commons go through Witch (prevent commons from pushing witch in l4d1)
* Prevent \"point_deathfall_camera\" and \"point_viewcontrol*\" permanently locking view.
* Fixed server crash when kicking a bot who have been an active target of camera (point_viewcontrol_survivor)
* Fixed Multiple visual spectator bugs after team swap in finale
* Remove restricted time between panic events (90s)
* Prevent forced sliding when landing at head of enemies.
* Dissolves the witch, common, survivor or special infected when killed.
	* Only works in some certain maps that have water
	* Dead bodies splash with water impact, which causes client fps drop and client crash
* Tricky fix for surfaces with wrong attributes on linux dedicated servers. [Details](https://github.com/Target5150/MoYu_Server_Stupid_Plugins/tree/master/The%20Last%20Stand/l4d_fix_linux_surface)
  * e.g. You won't slide on ice surfaces.

- - - -
### Gameplay / Balance Changes ###
* Common Infected
  * Fix common infected blocking the tank punch tracing.
  * In some custom maps, fix the wrong .wav sound coming from common infected when been shot
  * Prevents director or map overrides of z_common_limit. Kill common if overflow.
  * It always takes 5 scratches from an infected player to kill a common infected
  * Prevent common infected from pushing witch away when witch not startled yet
  * Despawn infected commons who is too far behind the survivors.
  * Reduce the possibility that commons jiggle around when close to each other. Credit: [jensewe](https://github.com/Target5150/MoYu_Server_Stupid_Plugins/tree/master/The%20Last%20Stand/l4d_fix_nextbot_collision)
	  * A well-known issue happens when setting ```nb_update_frequency``` to low value. 
  * Fix commons being immune to shoves when crouching, falling and landing. Credit: [jensewe](https://github.com/Target5150/MoYu_Server_Stupid_Plugins/tree/master/The%20Last%20Stand/l4d_fix_common_shove)
  * Remove BattleField Navigation limit when panic horde stage, which means common infected no longer spawns behind when survivor rush forward.
  * Resolves single-directional stumbling for commons

* Special Infected:
  * **General:**
    * Spawntimers:
      - *(5v5)*: **15s**
      - *(4v4)*: **11s**
      - *(3v3)*: **9s**
      - *(2v2)*: **7s**
      - *(1v1)*: **1s**
    * When a spawned Infected Player disconnects or becomes Tank the AI SI will instantly get killed unless it has someone capped.
    * Improvement AI Cvars, make AI Smart
    * Despawning a special infected restores 50% of missing health
    * Allows ghost infected to warp to survivors, Command: ```sm_warpto [#|name]``` or MOUSE2 (```sm_warpm2off``` to disable, say ```sm_warpm2on``` to enable)
      - *1*: **Francis**
      - *2*: **Bill**
      - *3*: **Zoey**
      - *4*: **Louis**
    * No gunfire slowdown and shove slowdown
    * Can't spawn in saferoom or any "this is restricted area" rooms (one of l4d1 original feature)
    * Allow duck fastspeed exploit when infected ghost state (one of l4d1 original feature)
	* Allow water bhop and swim (one of l4d1 original feature)
    * Special infected cannot damage each other.(but still move back) The tank can kill other special infected.
    * Can't M2 scratch when duck (one of l4d1 original feature)
    * Stop special infected getting bashed to death except for Boomer 
    * Players that try to bypass the Death Cam by spectating and switching back will be prevented from joining back for a few seconds.
    * Reduces the SI spawning range on finales to normal spawning range
    * All SI are able to be on fire!!
    * All SI are now able to break doors with 1 scratch instead of 3
    * Hides all weapons and iteams from the infected team or dead survivor until they are (possibly) visible to one of the alive survivors to prevent SI scouting the map
    * Players cannot scratch while in the stumble animation.
    * ```sm_respec``` force the spectator player to respectate, only used by infected.
	* show who the god damn pig S.I like kill teammates, stumble tank, kill witch, etc.
	* Overrides special infected targeting players.
      * ignore player who is pinned by smoker & hunter.
      * change target to nearest survivor no matter anyone gets vomited.
      * AI Tank now ignores player who use minigun.
      * if no target found, infected stops m1 ability.
	* Enable free movement (Left/Right/Crouch) on SI when M2-ing.
	* Fix SI being unable to break props/walls within finale area before finale starts.
	* No more explosion damage to the infected from entity
	* Fixed infected unable to break the rescue door
	* remove restricted area where infected ghost unable to spawn inside the info_survivor_rescue room/area
	* Blocks smoekr, boomer, hunter bacteria sounds.
	* Fix SI getting **shoved by nothing**.
		* The value of ```z_gun_swing_duration``` isn't respected internally, but a constant ```1.0``` instead.
	* Fixed Tank/Witch not spawning consistently for both sides.
	* Prevent ghost infected players from spawning inside checkpoint area
  * Allows gravity when infected players are staggering + allows staggering over a ledge and falling.
    * Infected still gets stumble even in the air

  * **Tanks:**
    * Announce in chat and via a sound when a Tank has spawned
    * Show how long is tank alive, and tank punch/rock/car statistics once tank dead
    * Damage dealt to tank is announced after tank dies, when the survivors wipe, or when the round ends, whichever comes first.
    * Tank won't stuck when punches incapped survivor
    * Stops rocks from passing through soon-to-be-dead Survivors
    * Tanks speed: 210 (survivors speed: 220, vanilla: 210)
    * When a Tank throws a rock, it adds a Glow to the rock which all infected players can see
    <br/><img src="https://i.imgur.com/H6gFGOf.jpg">
    * When a Tank punches a Hittable it adds a Glow to the hittable which all infected players and spectators can see
    <br/><img src="https://i.imgur.com/jtIWewR.jpg">
    * Stop tank props from fading whilst the tank is alive, remove all tank hittable prop once tank dead
    * Show tank hud for Infected team
    * Players cannot shove tanks.
    * Passing control to AI tank will no longer be rewarded with an instant respawn
    * Remove random punches animation, now always right hook.
    * Tanks can use Secondary Attack, Use, and Reload Buttons to throw rocks.
	  - *(MOUSE2)*: **One handed overhand**
	  - *(E)*: **Underhand**
	  - *(R)*: **Two handed overhand**
    * Tank can't use curve rock, this is not l4d2, this is one of l4d1 original feature
    * Refill Tank's frustration whenever a hittable hits a Survivor
    * Show how long is tank alive, and tank punch/rock/car statistics once tank dead
    * Tank will still lose rage while survivors are in saferoom
    * Forces each player to play the tank at least once before Map change.
      * **Decide who will become the tank once round goes live**
      * **If each infected player has been tank at once, random choose!**
      * **Tank player has two control chances, it won't pass!!**
    * Health
      - *(5v5)*: **8500**
      - *(4v4)*: **7000**
      - *(3v3)*: **5025**
      - *(2v2)*: **3480**
      - *(1v1)*: **None**
    * Slay AI Tank in 1v1, 2v2 and 3v3  
    * Lag compensation for tank rocks + custom damage & range values. [details here](https://forums.alliedmods.net/showthread.php?t=315345)
    * Ignites the rock thrown by the Tank when he is on fire.
    * Fixed an issue where tank rock is harder to land on survivors in saferoom area.
    * Disables the Car Alarm when a Tank hittable hits the alarmed car.
    * Make AI Tank be more stupid, think twice if you wanna pass tank to AI.
    * Tank burn life time: 125s (vanilla: **75**)
    * Ghost Tank freezes and being immune to fire for a while.
    * Fix frozen tanks, force tank player suicide when playing death animation.
    * Fix punch get-up varying in length, along with flexible setting to it.
    * Prevent underhand rocks and fix sticking aim after throws for AI Tanks.
    * Fixed passing Tank (going AI) triggering next stage of script finales.
    * Fix tank's punch getting cancelled when they heavily land on ground.
    * Stops the Tanks footsteps causing the screen to shake.

  * **Witch:**
    * Fixes the Witch not dying from a perfectly aligned shotgun blast due to the random nature of the pellet spread
    * Announce in chat when a Which has spawned
    * Damage dealt to witch is announced after witch dies, or when the witch successfully scratches a player.
    * Enlarge witch personal space: 500 (vanilla: 100)
    * Enlarge witch flashlight range: 750 (vanilla: 400)
    * Witch is restored at the same spot if she gets killed by a Tank before someone startles her
    * Glow for Infected Team. Credit: [rahzel ‧ JNC](https://forums.alliedmods.net/showthread.php?t=316965)
	  <br/><img src="https://i.imgur.com/RKAuCjY.jpg">
    * Instantly incapacitate Survivors
    * Allows witches to chase victims into safezones, [video](https://www.youtube.com/watch?v=PU_yx-fzjUU)
    * Prevents the witch from randomly loosing target.
    * Survivor will startle witch if shoot boomer nearby.
	
  * **Smoker:**
    * Tongue will not be released after survivor hanging from a ledge. (one of l4d1 original feature)
    * First Drag Damage: 3, interval: 1s (same as vanilla)
    * Drag Damage: 1, interval: 0.33s (3 dps, same as vanilla)
    * Choke Damage: 1, interval: 0.2s (5 dps, same as vanilla)
    * Fix tongue instant choking survivors.
    * Freeze player who is pulled by smoker when game pauses. (Fixed player teleport when game unpauses)
    * Fix unexpected tongue breaks for \"bending too many times\".
    * Fix infected teammate blocking tongue chasing.
    * Smoker's ability recharge cooldown
      - *After a successful hit*: 15s -> 13s
      - *Smoker get on a quick clear by Tank punch/rock*: 3.0s -> 8.0s
      - *Smoker get on a quick clear by Survivors*: 3.0s -> 4.0s
    * Fix unable to stagger smoker when smoker is shooting tongue
	
  * **Hunter:**
    * Fixed silence Hunter produces growl sound when [player MIC on](https://www.youtube.com/watch?v=L7x_x6dc1-Y&t=120s)
    * Allow Bunny hop pounce (one of l4d1 original feature)
    * Maximum pounce damage: **35**
    * Wallkick/Backjumps
      - *(5v5)*: **✔**
      - *(4v4)*: **✔**
      - *(3v3)*: **✔**
      - *(2v2)*: **✔**
      - *(1v1)*: **✘**
    * DeadStop
      - *(5v5)*: **✘**
      - *(4v4)*: **✘**
      - *(3v3)*: **✘**
      - *(2v2)*: **✘**
      - *(1v1)*: **✘**
    * Pounce Damage: 2, Interval: 0.2 (10 dps, same as vanilla)
    * claw Damage: 6 (vanilla: 6)
    * Fixed Hunters were deadstopped potentially when versus_shove_hunter_fov_pouncing is 0
    * Allow Hunters being shoved when not pouncing. (Shove fov: **50**)
    * Forces silent but [crouched hunters to emitt sounds](https://www.youtube.com/watch?v=L7x_x6dc1-Y&t=48s)
    * Hunter can wallkick if the touched other is a solid non-world entity (stripper entity)
    * M2 godframes after a hunter lands on the ground: 0.25s
	
  * **Boomer:**
    * Boomer can be getting bashed to death
    * Stumble Tank for 3 seconds long (one of l4d1 original feature)
    * Recharge CD: 20s (vanilla: 30s)
    * Amount of zombies boomer vomit on
      - *(5v5)*: **35**
      - *(4v4)*: **28**
      - *(3v3)*: **21**
      - *(2v2)*: **13**
    * If Boomer dies last, then next Special Infected Spawn: 100% Quad Caps
      - *90%*: **3 Hunters + 1 Smoker**
      - *10%*: **4 Hunters**
    * Explode after 3 times shove (original: 5)
    * Make sure Boomers are unable to bile Survivors during a stumble (basically reinforce shoves)
    * Fixes boomer teleport whenever hes close enough to ladder
    * Fix Boomer's vomit being unable to pass through their teammates (ghosts as well).([video](https://youtu.be/GeURlehdoTo))
    * Boomer's vomit is now able to pass through fence and barricade
    <br/><img src="https://i.imgur.com/MV6azfX.gif">
    * Boomer's exploding can trigger alarm car and startle witch
	  
  * **Charger/Spitter/Jockey:**
    * No!!!!!!!!!!!!! This is L4D1, GO AWAY!!
   
* Tank/Witch Spawns:
  * Force Enable bosses spawning on all maps, and same spawn positions for both team
  * ```sm_boss``` will print the distance percentage for the Tank and Witch spawns.
  * *(Intro)*: **20%~90%** (original: 50%~75%)
  * *(Regular)*: **10%~90%** (original: 10%~90%)
  * *(Finale)*: **20%~80%** (original: 25%~60%)
  * **Static Tank maps / flow Tank disabled:**
    * The Sacrifice Stage 1 (c7m1_docks)
    * The Sacrifice Stage 3 (c7m3_port)
  * **Finales with flow + second event Tanks:**
    * No Mercy
    * Crash Cource
    * Death Toll
    * Dead Air
    * Blood Harvest
    * Custom addon maps
    > **Developer Comment:** This means Finale tanks are limited to 2. No First Tank Spawn as the final rescue start. We make these changes to make final more balance and playable, we also encourage players to make a comeback to win.
  * **Finales with 3 event Tanks:**
    * The Sacrifice
  * No Tank Spawn as the rescue vehicle is coming
  * ```sm_voteboss <tank> <witch>``` Boss Percents Vote
    
* Survivors:
  * Anti-baiting Timer: 30s.
  * Anti-baiting Sensitivity Delay: 15s.
    * Survivors Must move forward, no time to stay put long, or the director will force panic event
    * Baiting is a valid tactic, but nobody wants to fall asleep during very lengthy baiting sessions.
  * Water Slowdown outside of Tank fights.
     * *Water speed*: **170** (original: 175)
     * *Deep water speed*: **136** (original: 140)
  * Reduces Water Slowdown during Tank fights.
     * *Water speed*: **220** (original: 175)
     * *Deep water speed*: **176** (original: 140)
  * Maximum amount of Friendly Fire per Shotgun: **10** (unchanged)
  * Allow ladder speed glitch(keyboard shortcuts AS,AW,DS,DW depends on your view.), but can't shoot when climb on the ladder
  * Survivor who is Incapacitated will not hurt other teammate with pistol
  * Survivor players will drop their secondary weapon when they die
  * Fixed if one of survivors didn't leave out saferoom completely, infected players can use endless instant spawn. (one of l4d1 original feature)
  * While selected, pills can be passed with +reload to avoid accidental drops and canceling reload animations.
  * Survivors now get fatigued after **2** Shoves. (vanilla: **5**)
  * Stops Survivors from saying 'Hunter!'
    > **Developer Comment:** sometimets survivors didn't see the silence hunter but their mouth keep saying 'Hunter!'
  * Removes pills from bots if they try to use them and restores them when a human takes over.
  * AI Bots less retarded Convars
  * Blocks the stupid griefers who spam vocalize commands throughout after round is live.
  * show who triggers the horde event like start final rescue, shoot alarm car, etc.
  * show panel message "The Survivors have made it 25%/50%/75% of the way!"
  * Enlarge car alarm distance
  * Survivors bleed out Temp Health every **4.0s** (vanilla: **3.7s**)
  * Fixes shooting/bullet displacement by 1 tick problems so you can accurately hit by moving. [details here](https://forums.alliedmods.net/showthread.php?t=315405)
  * Weapon [Quickswitch Reloading](https://www.youtube.com/watch?v=Ur0uNQTZhbU) in L4D
  * Prevents swapping to secondary weapon on primary weapon pick up when its clip is empty
  * Prevents small push effect between survior players, bots still get pushed.
  * Auto Switch to Weapons/Pills on pick-up/given is now Off, type !secondary to turn On
  * Disables the Car Alarm before survivors leave the safe room.
  * Prevent filling the clip and skipping the reload animation when taking the same weapon.
  * It is legal to adjust hand's FOV in any value, while Common FOV only between 75 and 120. [Tutorial](https://steamcommunity.com/sharedfiles/filedetails/?id=158520677)
  * Block survivors from being able to open/close doors while incapacitated/hanging.
  * Block survivors from being able to open/close doors while immobilized by hunter/smoker.
  * Prevent Sounds from playing
    * Heartbeat
    * Incapacitated Injury
  * Reviving cancels reloading to fix that weapon has jammed and misfired (stupid bug exists for more than 10 years)
  * Precise control over invulnerability (god frames)
  * Hunter: **1.8s**
  * Smoker: **0s**
  * Received:
     * *(Incap)*: **0s**
     * *(Hangledge)*: **0s**
  * Common Infected Extra Time: 
     * *(Hunter)*: **+0s**
     * *(Smoker)*: **+1.8s**
  * FF Extra Time: 
     * *(Hunter)*: **+0s**
     * *(Smoker)*: **+0.8s**
  * Hittables(Cars, dumpsters, etc) and Witches always deal damage with or without god frames
    > **Developer Comment:** Don't even think using god frames to prevent yourself from Witch dmg or hittable car dmg.
  * Fixed the problem that survivor bots always take the lead and won't wait behind the lead human player in versus mode
  * Fixed slowdown which caused by common infected is overridden by other damage.
  * Allows gravity when survivors are staggering + allows staggering over a ledge and falling.
    * Survivor still gets stumble even in the air
  
* Spectators:
  * ```sm_spechud``` toggle On/Off spechud
  * Allows spectators to control their own specspeed and move vertically.
  * Spectators can see the witch glow, hittable prop glow and tank rock glow.
  * Spectators can see in-game players teamchat and hear their mic voice. To close this feature, use ```sm_hear```.
  * Spectators can see in-game players mic speak list. To close this feature, use ```sm_speaklist``` to toggle On/Off.
  * Spectators can't call a vote, start the match, or pause the game. To do these, they must be in-game first.
  * ```sm_s, sm_sm_spectate, sm_sm_afk, sm_away``` will help you respectate again, use these commands if 
     * spectator camera being stuck
     * spectator blocks infected teamicon
  * Added ```sm_kickspec```, this will start a vote to kick all non-adm spectators.
  * when player on spectator team, add name prefix
     * Remove prefix when in-game
	 
- - - -
### Miscellaneous ###
* ```sm_info**/**sm_harry``` will help you to search many useful commands
* ```sm_pause``` will directly pause the game without another team's agreement (No ```!fpause```)
* Lerp is capped between 0ms and 100ms Player in Server. Lerp must be 0.0~67.0 in some mode
* ```sm_current``` to display the survivor's percentage progress through the map.
* ```sm_shuffle, sm_mix``` - shuffle and mix
* Replacement of standard player connected message. Joining players will have their geo-location announced.
* The round does not go live until each player has readied up if ready plugin enable.
* Some player statistics are printed out at end of round.
* ```sm_flip``` to flip a coin, or ```sm_roll #``` to roll a die.
* Announce msg who the fking idiot TK you
* Smash nonstaggering Zombies
* Cleaned up the Chat by blocking useless prints caused by cvar, clients used by Players, etc.
* Added ```sm_slots```, this will allow players to vote for the Maximum amount of slots on the Server during the game.
  * Very useful when playing Home/Away in Tournaments!
* Usage of ```sm_kills``` with ```sm_mvp```.
  * Fully colorized, Rank prints, console info.. Functional!
* Auto change maps when second round ends on final stage
* Addes dynamic lights to handheld throwables
* ```sm_bonesaw、sm_trophy、sm_harrypotter、sm_twnumber1、sm_twno1``` secret easter egg trophy ready up
* Simply block pause commands when the server doesn't even support pausing.
* Fix props not spawning as prop_physics when using 'give' command
* Shows a laser for straight-flying fired projectiles during ready up.
* Free movement after round ends.
* Allows changing of displayed game type in server browser
<br/><img src="https://i.imgur.com/hbJd1Hs.png">

- - - -
### Roto-AZ l4d2onl4d1 ###
> __Note__ Type !votes -> Change addon map
* **[L4D2 on L4D1 Maps](https://www.gamemaps.com/details/32168)**
  1. **C1 - Dead Center**
  2. **C2 - Dark Carnival**
  3. **C3 - Swamp Fever**
  4. **C4 - Hard Rain**
  5. **C5 - The Parish**
  6. **C6 - The Passing**
  7. **C13 - Cold Stream**
  8. **C14 - The Last Stand (New)**

  <br/><img src="https://i.imgur.com/utcIlA8.png">
  <br/><img src="https://i.imgur.com/OXWBfsg.jpg">
  <br/><img src="https://i.imgur.com/cSsbd2o.jpg">
  <br/><img src="https://i.imgur.com/TDPqp4i.jpg">
  <br/><img src="https://i.imgur.com/Iv7Ns0E.jpg">
  <br/><img src="https://i.imgur.com/BpH0wDk.jpg">
  <br/><img src="https://i.imgur.com/XKjIfTF.jpg">

* <details><summary><b>L4D2 Map Modify</b></summary>

  <img src="https://user-images.githubusercontent.com/12229810/216926016-b46037ac-576e-47f8-98b9-7dfec4af94de.png">

  * Add models, materials, objects, infected ladders, invisible blocks in 2019 L4D2 The Last Stand update. ([mapfixes](https://github.com/jacob404/Official-Vscripts-Decompiled/blob/master/update/anv_mapfixes.nut), [versus](https://github.com/jacob404/Official-Vscripts-Decompiled/blob/master/update/anv_versus.nut))
  * Add ammo, weapons, and objects, infected ladders, invisible blocks (Based on [L4D2-Comp-Stripper-Rework by Derpduck](https://github.com/Derpduck/L4D2-Comp-Stripper-Rework))
  * Remove piece of shit l4d2 entities that crash server
  * Fix Fog, Gascan, cola, gnome issue and error
</details>

* <details><summary><b>Plugin Support</b></summary>

  * **(c1m4, c6m3, c14m2) Fix the problem when you take the gascans, the white glow of gascan will disappear and sometimes survivor can not find any gascan on the field**
    ```php
    l4d_random_beam_item.smx
    l4d_random_entity_color.smx
    l4d1_glow_gascan.smx
    ```
  * **(c1m1, c4m1) Put the single smg and shotgun on saferoom because there are no any weapons in the saferoom**
    ```php
    l4d_weapon_spawn.smx
    ```
  * **(c6m1) Spawn "bride witch model" on the wedding scene**
    ```php
    l4d1_random_witch_model.smx
    ```
  * **(c1m4, c6m3, c14m2) give special infected fire immune, so they won't burn**
    ```php
    si_fire_immunity.smx
    ```
</details>

- - - -
### Others ###
* <b>[Our Group](https://steamcommunity.com/groups/ibserver)</b>
* <b>[L4D1_2-Plugins](https://github.com/fbef0102/L4D1_2-Plugins)</b>: L4D1/2 general purpose and freaky-fun plugins.
* <b>[Game-Private_Plugin](https://github.com/fbef0102/Game-Private_Plugin)</b>: Private Plugin List.

