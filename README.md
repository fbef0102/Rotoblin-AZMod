# Rotoblin-AZMod
v8.1.5
* [繁體中文說明版](https://docs.google.com/document/d/1zcMSAVZeMTIrwW8bgyl2Y97bRqAiKBOXP8CxZmfSBwI/edit)
* [简体中文说明版](https://pan.baidu.com/s/1v4X80Hx6F8vxZMUp8dgi8g)
* [Developer](https://github.com/fbef0102/Rotoblin-AZMod/blob/master/Developer%26commands/developer.cfg)
> **Developer Comment:** Report any bug? Ask any question? Our English bad, add us via steam.

**LINUX/WINDOWS SERVERS WORK**


A Competitive L4D1 Versus Configuration. Based upon the L4D2 [Acemod V4 Release](http://imgur.com/a/8Ptck)、[Zonemod](https://github.com/SirPlease/ZoneMod)、L4D1 [rotoblin2](https://github.com/raziEiL/rotoblin2). Roto-AZMod's focus is not only to make setting things up a lot easier for Server but also to make more balance changes and more difficult challenges. The whole environment is similar to l4d2, but don't worry, the core is still around l4d1 gameplay.
- - - -
### Server Admins! ###

* Install:
  * Clean Servers:
      * A clean [L4D1 Dedicated Server](https://github.com/fbef0102/L4D1-Server4Dead/blob/master/README.md#how-to-download-l4d1-dedicated-server-files)
      * Make sure your server is stopped.
      * Delete left4dead/addons folder on your server (to make sure you have a clean slate).
  * Requirements:
      * [Windows Server files](https://github.com/fbef0102/L4D1-Server4Dead/releases/download/v2.0/Windows_Server_files.zip) or [Linux Server files](https://github.com/fbef0102/L4D1-Server4Dead/releases/download/v2.0/Linux_Server_files.zip)(depending on the operating system of your server), this contains Sourcemod, Metamod, Stripper, Left 4 Downtown, Tickrate, and other extensions
      * [Roto-AZMod main files](https://github.com/fbef0102/Rotoblin-AZMod/archive/master.zip), this contains the configs, plugins, gamedate, and other server settings.
      * At this step, you already setup your Server's base for configs, so you can finally start your server.
  * Launch parameters:
    * console -game left4dead -tickrate 100  +log on +map l4d_vs_airport01_greenhouse +exec server +sv_lan 0
  * Optional:
    * [SMAC](https://github.com/fbef0102/L4D1-Server4Dead/releases/download/v2.0/Sourcemod_Anti-Cheat.zip) is a server-side sourceMod Anti-Cheat plugin, I modfidy some codes to make them compatible with Roto-AZMod.
    * [L4D Modified Talker](https://www.gamemaps.com/details/3863) is an addon which improves the survivor's conversation. It includes many exclusive dialogues, unused survivor's speeches and every survivor has more than 15 kinds of laughter now!
    
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
  * Rcon passeword、rates、maxplayers、tags、group: -left4dead/cfg/server.cfg、server_rates.cfg、server_startup.cfg
  * If you have a prefered edition of a Plugin, you are able to simply replace the file in sourcemod/plugins folder.
    * do not overwrite any plugin that's existed.
  * To make it easy for personal configuration for certain plugins, there's an added "server_custom_convars.cfg" in the left4dead/cfg/Reloadables folder.
    * Keep in mind that this is a shared cfg, server excutes it after every mode loaded and map change, so it'll only contain shared cvars.
    * very useful for Admins wanting to load 1v1~5v5 supported plugins on top of the Configs.

* Admin Tips:
  * bequiet.smx is a very useful plugin to keep chat clean, if you decide to load it in other configs, make sure it's loaded before other plugins or set bequiet's "bq_show_player_team_chat_spec" cvar to 0.
  * l4d_versus_specListener3.0.smx comes with a "Spec-Listening Feature", even if sv_alltalk 0, spectators can still see in-game players teamchat and hear their mic voice. To close this feature, use **sm_hear**.
  * TickRateFixes now also fixes Slow Doors and Pistol Scripts, useful for use with other configs.
    * Make sure you're not loading l4dpistoldelay if you're using this Plugin.
    * Make sure you don't have any adjustments to prop_rotating and prop_rotating_checkpoint speeds in your cfg/stripper folder.
    * The cvar controlling the door speed is "tick_door_speed" and is set to 2.0 by default, 128 Tick requires this to be set to 2.5 in your server_rates.cfg
	  - *tickrate 128*: **tick_door_speed 2.5**
	  - *tickrate 100*: **tick_door_speed 2.0**
	  - *tickrate 60*: **tick_door_speed 1.5**
	  - *tickrate 30*: **tick_door_speed 1.0**
  * Specrates.smx is a useful plugin to reduce server load causes by spectators.
    * This will send less updates to Spectators whilst maintaining a pleasant viewing experience.
  * When player connects or disconnected, it would print the message about steamid and ip only adms can see.
  * All4Dead.smx allows administrators to influence what the AI director does without sv_cheats. it's a menu system which is attached   to the sm_admin menu
  * votemanager2.smx make All non-adm players can not call a value vote (esc->vote). Remeber if player wants to call a vote, use **!votes** instead!!
  * Adm type **!slots <#>** to forcechange server slots
  * [All Admin commands](https://github.com/fbef0102/Rotoblin-AZMod/blob/master/Developer%26commands/Roto-AZMod%20Adm%20Commands.png)
  * [Everyone commands](https://github.com/fbef0102/Rotoblin-AZMod/blob/master/Developer%26commands/Roto-AZMod%20Everyone%20Commands.png)

- - - -
### Gamemodes(!load, !match, !mode) ###
   * 5v5
      * Hunters only
      * No Boomer
      * Hardcore
   * 4v4 
      * Hunters only
      * No Boomer
      * Hardcore
      * [Classic](https://steamcommunity.com/groups/ibserver#announcements/detail/1688172020573940161) 
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
   * Special
      * Dark Coop
      * [l4d1 Witch Party](https://steamcommunity.com/groups/ibserver#announcements/detail/1720837068961859143)
      * [l4d1 multi Hunters](https://steamcommunity.com/groups/ibserver#announcements/detail/2924417816908996494)
      
- - - -
### Map Changes(!cm) ###

* **General:**
  * Remove restricted invisible wall Infected couldn't go through
  * Kill all ambience sounds in order to let survivor focus on S.I./common
  * Pills
     * All pill cabinets in Valve maps will now have a maximum of 2 pills
     * There are few pills on the road (pain_pill_density: 1.5)
     * Final Rescue: No any extra pills on the road, only pills on Final Rescue area
  * Cleaned up the Maps from Junk Props that you could get stuck on, allowing for smoother movement.
  * Spawn jukebox
  * Block "this is restricted area" room where infected ghost can not even spawn
  * Fixed many map tricks and glitches
  * Many obstacles and barriers (Based on [Roto2](https://github.com/raziEiL/rotoblin2/tree/master/left4dead/addons/stripper/maps) + [Zonemod](https://github.com/SirPlease/ZoneMod/tree/master/cfg/stripper/zonemod/maps))
  * make distance score correspond to final rescue event progress
  
* **The Sacrifice:**
 	* reduce pills on the road
  
* **Support Custom maps:**
  * [City 17](https://drive.google.com/file/d/18BOrQUifaT7_8z5xPsa4ugppIygPf9dD/view?usp=sharing)
  * [Suicide Blitz](https://drive.google.com/file/d/17dWmDEv72Vb7zCgdWyDRg6RERaXCNpAi/view?usp=sharing)
  * [Dead Flag Blues](https://drive.google.com/file/d/1cca3Pj99A7K8UnHHd6wgpeUD1jn87JuM/view?usp=sharing)
  * [I Hate Mountains](https://drive.google.com/file/d/188UqXYB7BKFMMduIs7w5CbST2lMJ2-5S/view?usp=sharing)
  * [Dead Before Dawn](https://drive.google.com/file/d/1_r9HJBdqN8ziejW7Y486TioJwPOIsC6i/view?usp=sharing)
  * [The Arena of the Dead](https://drive.google.com/file/d/1dv8kkhzV0E2c2usfyANNzCDKs4cG4ARD/view?usp=sharing)
  
- - - -
### Weapon Adjustments ###
* **Uzi** (based on Acemod/Zonemod)
  * Still Spread: 0.32->0.26 (Acemod: 0.20 - **Zonemod 1.9.4: 0.26**)
  * Moveing Spread: 3.0->1.85 (Acemod: 1.65 - **Zonemod 1.9.4: 1.85**)
  * Ammo: 480->750 (Acemod: 800 - **Zonemod 1.9.4: 750**) 
  * Damage Drop-off: 0.84->0.84 (unchanged)
  * Reload Speed: 2.23->1.88 (Acemod: 1.75 - **Zonemod 1.9.4: 1.88**) 
  * Damage: 20->22 (Acemod: 20 - **Zonemod 1.9.4: 22**)
  * Limit: None
      
* **Pumpshotgun**
  * Air Spread: 2.5->1.5
  * Ammo: 128->96 (**Acemod: 96** - Zonemod 1.9.4: 80) 
  * Limit: None
      
* **Hunting Rifle**
  * Rate of fire: 1->0.13
  * Tank dmg: 90->135
  * Hunter dmg: Chest, neck *2.8 - abdominal muscles *1.8
  * Limit: 1
  > **Developer Comment:** As we've noticed in L4D1, the Uzis were completely nothing and shotguns were taking over everything. In the release of Roto-AZMod, I want to make the Uzi more attractiv, which result into the Uzi having more advantages. And there can be a sniper in a team, this Hunting Rifle is nerfed a lot as you can see rate of fire is very slow. Peope can choose thier desired weapons. Each performs one's own best part in a team.

- - - -
### Score Calculation(!health/!bonus) ###
  * ( AD + HB + PILLS ) x Alive x Map 
     * AD = Average distance
     * HB = Health Bonus , Floor(PermanentHealth/2)+RoundToNearest(TemporaryHealth/4)
     * PILLS = 20 Health Bonus per pill
     * Alive = Number of players that survived
     * Map = That level's score multiplier
    > **Developer Comment:** This effectively gives you a higher reward for holding onto pills, we encourage player to search pills. And restore level's score multiplier as we consider it's unfair that short map and long map have the same maximum score

- - - -
### Bug / Exploit Fixes ###
   * Crash Course Unprohibit Bosses.vpk force versus director to spawn tank and witch on "crash cource" each stage
   * Fixed the bug in which doors do not break although the tank is punching at them.
   * Survivors cannot hear ghost footsteps and spawn sound.
   * Stops Shoves slowing the Tank and Charger Down
   * Fixed Players being able to exploit switching team to get earlier SI Spawns.
   * Fixed a Valve Bug where you could see Shadows from Infected (Common and SI) through Walls, Floors and Ceilings.
   * Fixed no Survivor bots issue and more than 4 bots issue.
   * Fixes some survivors [health expolit](https://forums.alliedmods.net/showthread.php?p=1823208)
        * Regeneration - You should have less than 30hp before hang on a ledge, when teammates help you the game give a little health bonus.
        * Increasing of health limit - If you have a temporary health (pills) and you're hanging on a ledge look at health bar.
        * Disappearance of the temporary health - When survivors pulled you from the ledge pills health is disappears if it was.
   * Ensures that survivors that have been incapacitated with a hittable object get their temp health (300hp) set correctly
   * Prevents calling votes while others are loading
   * Boomer and Smoker Heard Vocalizations are restored. In the original game they are not used most likely due to clustering the constant vocalization of special infected in the area.
   * Blocking [exploits by using Engine](https://forums.alliedmods.net/showthread.php?t=182002)
        * no fall damage bug - jump on the incapped survivor while holding USE key
        * health boost glitch - heal yourself while under water.
   * Fixes the Witch not dying from a perfectly aligned shotgun blast due to the random nature of the pellet spread
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
   * Fixed a l4d1 value bug that you can not see the real hittable car hitbox when tank punches them
      > **Developer Comment:** This often happened in l4d1, players can not find the toy to hit it after the first punch .. until after several seconds it reappears in its place. Add Shadow Model color which attaches to the real hittable hitbox so that everyone including survivors can see. If you have played l4d1 versus for a long time, you knew what I am fking talking about.
   * Fixed players using bunnyhop to increase their MaxSpeed.
   * Fixed second team having different SI spawns on round start.
        * Spawns for the first hit are announced once round starts.
   * Blocks all button presses during stumbles
   * Fixed silence Hunter produces growl sound when [player MIC on](https://www.youtube.com/watch?v=L7x_x6dc1-Y&t=120s)
   * Fixed that player whom hunter pounces on will not be biled by a boomer([video](https://www.youtube.com/watch?v=z8wPy9mWLQI))
   * Disallows special infected from breaching into safe room by preventing them from spawning nearby the safe room door([video](https://www.youtube.com/watch?v=-w1iWOx72LU&t=400s))
   
- - - -
### Gameplay / Balance Changes ###
* Anti-baiting Timer: 40s.
* Anti-baiting Sensitivity Delay: 15s.
  * Survivors Must move forward, no time to stay put long, or the director will force panic event
  * Baiting is a valid tactic, but nobody wants to fall asleep during very lengthy baiting sessions.
  
* Special Infected(!inf):
  * **General:**
    * Spawntimers:
	  - *(5v5)*: **15s**
	  - *(4v4)*: **12s**
	  - *(3v3)*: **10s**
	  - *(2v2)*: **7s**
	  - *(1v1)*: **1s**
    * When a spawned Infected Player disconnects or becomes Tank the AI SI will instantly get kicked unless it's a Boomer or has someone capped.
    * Improvement AI Cvars, make AI Smart
    * Despawning a special infected restores 50% of missing health
    * Allows infected to warp to survivors (MOUSE2 or use command: **sm_warpto [#|name]**)
	  - *1*: **Francis**
	  - *2*: **Bill**
	  - *3*: **Zoey**
	  - *4*: **Louis**
    * No gunfire slowdown and shove slowdown
    * Can't spawn in saferoom or any "this is restricted area" rooms (one of l4d1 original feature)
    * Allow duck fastspeed exploit when infected ghost state (one of l4d1 original feature)
    * NSpecial infected cannot damage each other.(but still move back) The tank can damage other special infected.
    * Can't M2 scratch when duck (one of l4d1 original feature)
    * Stop special infected getting bashed to death except for Boomer 
    * Players that try to bypass the Death Cam by spectating and switching back will be prevented from joining back for a few seconds.
      * **These players will NOT be moved back onto the team automatically.**
    * Reduces the SI spawning range on finales to normal spawning range
    * All SI are able to be on fire!!
    * All SI are now able to break doors with 2 scratches instead of 3
    * Hides all weapons and iteams from the infected team or dead survivor until they are (possibly) visible to one of the alive survivors to prevent SI scouting the map
    * It always takes 5 scratches from an infected player to kill a common infected
    * Players cannot scratch while in the stumble animation.
    * **sm_respec** force the spectator player to respectate, only used by infected.
	* show who the god damn pig S.I like kill teammates, stumble tank, kill witch, etc.
    
  * **Tanks:**
    * Announce in chat and via a sound when a Tank has spawned
    * Show how long is tank alive, and tank punch/rock/car statistics once tank dead
    * Damage dealt to tank is announced after tank dies, when the survivors wipe, or when the round ends, whichever comes first.
    * Tank won't stuck when punches incapped survivor
    * Stops rocks from passing through soon-to-be-dead Survivors
    * Tanks speed decreased to 205 (survivors speed: 220, default: 210 - zonemod: 205)
    * When a Tank punches a Hittable it adds a Glow to the hittable which all infected players can see, and add Shadow Model color which attaches to the real hittable hitbox so that everyone including survivors can see. 
    * Stop tank props from fading whilst the tank is alive, remove all tank hittable prop once tank dead
    * Show tank hud for Infected team
    * Players cannot shove tanks.
    * Passing control to AI tank will no longer be rewarded with an instant respawn
    * Tanks can use Secondary Attack, Use, and Reload to rocks.
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
	  - *(1v1)*: **2000**
    * Slay AI Tank in 1v1, 2v2 and 3v3  
    * Lag compensation for tank rocks + custom damage & range values.
    > **Developer Comment:** This plugin provides lag compensation as well as cvars for weapon damage & range values on tank rocks. It's very helpful for high ping players shooting the tank rock. Click [AlliedModders](https://forums.alliedmods.net/showthread.php?p=2646073) and see more detals on how it works.
  * **Witch:**
    * Announce in chat when a Which has spawned
    * Damage dealt to witch is announced after witch dies, or when the witch successfully scratches a player.
    * Enlarge witch personal space
    * Witch is restored at the same spot if she gets killed by a Tank before someone startles her
    * Glow for Infected Team
    * Instantly incapacitate Survivors
    * Allows witches to chase victims into safezones, [video](https://www.youtube.com/watch?v=PU_yx-fzjUU)
  * **Smoker:**
    * Smoker's ability will now recharge within **13** seconds after a successful hit (default: **15**)
  * **Hunter:**
    * Allow Bunny hop pounce (one of l4d1 original feature)
    * Maximum pounce damage: **60**
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
    * Hunters can't be shoved off when pouncing (fov_pouncing: 0)
    * Hunters can be shoved off when duck or stand still (Shove fov: 30)
    * Forces silent but [crouched hunters to emitt sounds](https://www.youtube.com/watch?v=L7x_x6dc1-Y&t=48s)
    
  * **Boomer:**
    * Boomer can be getting bashed to death
    * Stumble Tank for 3 seconds long (one of l4d1 original feature)
    * Recharge CD: 20s (Default: 30s)
    * Boom Horde limit
	  - *(5v5)*: **30**
	  - *(4v4)*: **24**
	  - *(3v3)*: **21**
	  - *(2v2)*: **13**
    * If Boomer dies last, then next Special Infected Spawn: 100% Quad Caps
	  - *90%*: **3 Hunters + 1 Smoker**
	  - *10%*: **4 Hunters**
  * **Charger/Spitter/Jockey:**
    * No!!!!!!!!!!!!! This is L4D1, GO AWAY!!
   
* Tank/Witch Spawns:
  * Force Enable bosses spawning on all maps, and same spawn positions for both team
  * **sm_boss** will print the distance percentage for the Tank and Witch spawns.
  * *(Intro)*: **20%~85%**
  * *(Regular)*: **10%~90%** (possible tank when leave out saferoom)
  * *(Finale)*: **20%~85%**
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
  * Second tank spawns same position for both team
  * No Tank Spawn as the rescue vehicle is coming
    
* Survivors(!sur):
  * Still Water Slowdown with or without Tank Fights.
  * Maximum amount of Friendly Fire per Shotgun: **10** (unchanged)
  * Allow ladder speed glitch(keyboard shortcuts AS,AW,DS,DW depends on your view.), but can't shoot when climb on the ladder
  * Survivor who is Incapacitated will not hurt other teammate with pistol
  * Survivor players will drop their secondary weapon when they die
  * If one of survivors didn't come out saferoom completely, infected players can use endless instant spawn glitch (one of l4d1 original feature)
  * While selected, pills can be passed with +reload to avoid accidental drops and canceling reload animations.
  * Survivors now get fatigued after **2** Shoves. (default: **5** Zonemod: **3**)
  * Stops Survivors from saying 'Hunter!'
   > **Developer Comment:** sometimets survivors didn't see the silence hunter but their mouth keep saying 'Hunter!'
  * Removes pills from bots if they try to use them and restores them when a human takes over.
  * AI Bots less retarded Convars
  * Blocks the stupid griefers who spam vocalize commands throughout after round is live.
  * show who triggers the horde event like start final rescue, shoot alarm car, etc.
  * show panel message "The Survivors have made it 25%/50%/75% of the way!"
  
* Precise control over invulnerability (god frames)
  * Hunter: **1.8s**
  * Smoker: **0s**
  * Received:
     * *(Incap)*: **0s**
     * *(Hangledge)*: **0s**
  * Common Extra Time: 
     * *(Hunter)*: **+0s**
     * *(Smoker)*: **+1.8s**
  * FF Extra Time: 
     * *(Hunter)*: **+0s**
     * *(Smoker)*: **+0.8s**
  * Hittables(Cars, dumpsters, etc) and Witches always deal damage with or without god frames
   > **Developer Comment:** Don't even think using god frames to prevent yourself from Witch dmg or hittable car dmg.

* Spectators(!s):
  * **sm_spechud** toggle On/Off spechud
  * Allows spectators to control their own specspeed and move vertically.
  * Spectators can see the witch glow and hittable prop glow.
  * Spectators can see in-game players teamchat and hear their mic voice. To close this feature, use **!hear**.
  * Spectators can see in-game players mic speak list. To close this feature, use **!speaklist** to toggle On/Off.
  * Spectators can't call a vote, start the match, or pause the game. To do these, they must be in-game first.
  * **!s,!spectate,!afk,!away** will help you respectate again, use these commands if 
     * spectator camera being stuck
     * spectator blocks infected teamicon
  * Added **!kickspec**, this will start a vote to kick all non-adm spectators.
  * when player on spectator team, add name prefix
     * Remove prefix when in-game
	 
- - - -
### Miscellaneous ###
* **sm_info**/**sm_harry** will help you to find many useful commands
* **sm_votes** call a vote to kick、alltalk、change map、restartmap
* **!pause** will directly pause the game without another team's agreement (No !fpause)
* Lerp is capped between 0ms and 100ms Player in Server. Lerp must be 0.0~67.0 in some mode
* **sm_current** to display the survivor's percentage progress through the map.
* **!shuffle, !mixteam** - shuffle and mix
* Replacement of standard player connected message. Joining players will have their geo-location announced.
* The round does not go live until each player has readied up if ready plugin enable.
* Some player statistics are printed out at end of round.
* **sm_flip** to flip a coin, or **sm_roll #** to roll a die.
* Announce msg who the fking idiot TK you
* Smash nonstaggering Zombies
* Cleaned up the Chat by blocking useless prints caused by cvar, clients used by Players, etc.
* Added **!slots**, this will allow players to vote for the Maximum amount of slots on the Server during the game.
  * Very useful when playing Home/Away in Tournaments!
* Usage of **sm_kills** with **sm_mvp**.
  * Fully colorized, Rank prints, console info.. Functional!
* Auto change maps when second round ends on final stage
* Addes dynamic lights to handheld throwables
* Allows changing of [displayed game type](https://github.com/fbef0102/L4D1_2-Plugins/blob/master/gametype_description/l4d1%20game%20type%20name.png) in server browser
* Voice Announce. Print To Center Message who is Speaking. With cookies
* **sm_bonesaw、sm_trophy、sm_harrypotter、sm_twnumber1、sm_twno1** secret easter egg trophy ready up
* Fixes shooting/bullet displacement by 1 tick problems so you can accurately hit by moving. [details here](https://forums.alliedmods.net/showthread.php?t=315405)

- - - -
### Others ###
* [Our Group](https://steamcommunity.com/groups/ibserver)

