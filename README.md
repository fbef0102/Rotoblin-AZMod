# Rotoblin-AZMod

> **Developer Comment:** My English is bad, if you guys do not understand the meanings of some paragraphes, add and PM me.

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
      * [Windows Server files](https://drive.google.com/uc?authuser=0&id=1PjFNLkf_HEWzOOSwTN4WAVBMXQhmR1Hc&export=download) or [Linux Server files](https://drive.google.com/uc?authuser=0&id=10VRJzCoe39Oy-4DPZ7fY4Edcs_h3UScW&export=download)(depending on the operating system of your server), this contains Sourcemod, Metamod, Stripper, Left 4 Downtown, Tickrate, and other extensions
      * [Roto-AZMod main files](https://github.com/fbef0102/Rotoblin-AZMod/archive/master.zip), this contains the configs, plugins, gamedate, and other server settings.
      * At this step, you already setup your Server's base for configs, so you can finally start your server.
  * Launch parameters:
    * console -game left4dead -tickrate 100  +log on +map l4d_vs_airport01_greenhouse +exec server +sv_lan 0
  * Optional:
    * [SMAC](https://github.com/fbef0102/L4D1-Server4Dead/tree/master/Sourcemod%20Anti-Cheat) is a server-side sourceMod Anti-Cheat plugin, I modfidy some codes to make them compatible with Roto-AZMod.
    * [L4D Modified Talker](https://www.gamemaps.com/details/3863) is an addon which improves the survivor's conversation. It includes many exclusive dialogues, unused survivor's speeches and every survivor has more than 15 kinds of laughter now!
    
**Warning: If you try to use the plugins which are included in this package in other configs, plugins may not work correctly
as they're designed around Roto-AZMod and are likely to be unstable in other configs or general usage.**

* Admin simplicity:
  * [Be Adm](https://wiki.alliedmods.net/Adding_Admins_(SourceMod)#Quick_Start): -left4dead/addons/sourcemod/configs/admins_simple.ini
  * MatchMod: -left4dead/addons/sourcemod/configs/matchmodes.txt
  * Advertisements: -left4dead/addons/sourcemod/configs/advertisements.txt
  * HostName: -left4dead/addons/sourcemod/configs/hostname/server_hostname.txt
  * Mapcyclelist: -left4dead/addons/sourcemod/data/sm_l4dvs_mapchanger.txt、sm_l4dco_mapchanger.txt
  * Jukebox spawn position: -left4dead/addons/sourcemod/data/l4d1_jukebox_spawns.cfg
  * Save player chat (and team chat) to a file: -left4dead/addons/sourcemod/logs/chat/
  * Server password、rates、maxplayers、tags、group: -left4dead/cfg/server.cfg、server_rates.cfg、server_startup.cfg
  * If you have a prefered edition of a Plugin, you are able to simply replace the file in sourcemod/plugins folder.
    * do not overwrite any plugin that's existed.
  * To make it easy for personal configuration for certain plugins, there's an added "server_custom_convars.cfg" in the left4dead/cfg/Reloadables folder.
    * Keep in mind that this is a shared cfg, server excutes it after every mode loaded and map change, so it'll only contain shared cvars.
    * very useful for Admins wanting to load 1v1~5v5 supported plugins on top of the Configs.

* Admin Tips:
  * bequiet.smx is a very useful plugin to keep chat clean, if you decide to load it in other configs, make sure it's loaded before other plugins or set bequiet's "bq_show_player_team_chat_spec" cvar to 0.
  * l4d_versus_specListener3.0.smx comes with a "Spec-Listening Feature", even if sv_alltalk 0, specators can still see in-game players teamchat and hear their mic voice.
  * TickRateFixes.smx now also fixes Server Gravity and Pistol Scripts.
    * Make sure you're not loading l4dpistoldelay if you're using this Plugin.
  * Specrates.smx is a useful plugin to reduce server load causes by spectators.
    * This will send less updates to Spectators whilst maintaining a pleasant viewing experience.
  * When player connects or disconnected, it would print the message about steamid and ip only adms can see.
  * All4Dead.smx allows administrators to influence what the AI director does without sv_cheats. it's a menu system which is attached   to the sm_admin menu
  * votemanager2.smx make All non-adm players can not call a value vote (esc->vote). Remeber if player wants to call a vote, use !votes instead!!
  * [All Admin commands](https://github.com/fbef0102/Rotoblin-AZMod/blob/master/Rule%26developer/Roto-AZMod%20Adm%20Commands.png)
  
- - - -
### Bug / Exploit Fixes ###
   * Crash Course Unprohibit Bosses.vpk force versus director to spawn tank and witch on "crash cource" each stage
   * Fixed the bug in which doors do not break although the tank is punching at them.
   * Survivors cannot hear ghost footsteps and spawn sound.
   * Fixed silence Hunter produces growl sound when [player MIC on](https://www.youtube.com/watch?v=L7x_x6dc1-Y&t=120s)
   * Stops Shoves slowing the Tank and Charger Down
   * Fixed Players being able to exploit switching team to get earlier SI Spawns.
   * Fixed a Valve Bug where you could see Shadows from Infected (Common and SI) through Walls, Floors and Ceilings.
   * Fixed no Survivor bots issue and more than 4 bots issue.
   * Fixes some survivors [health expolit](https://forums.alliedmods.net/showthread.php?p=1823208)
        * Regeneration - You should have less than 30hp before hang on a ledge, when teammates help you the game give a little health bonus.
        * Increasing of health limit - If you have a temporary health (pills) and you're hanging on a ledge look at health bar.
        * Disappearance of the temporary health - When survivors pulled you from the ledge pills health is disappears if it was.
   * Ensures that survivors that have been incapacitated with a hittable object get their temp health (300hp) set correctly
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
   * Survivor duck fastspeed block & Infected alive duck fastspeed block
   * Survivor who is Incapacitated will not hurt other teammate with pistol
   * Objects which are hit by only tank rocks disappear when tank dies.
   * Blocked an exploit where players can remove textures from their game to see through walls.
   * Blocked an exploit with players using third person shoulder.
   * Hunters don't fall off of walls after being shot.
   * AI special infected deal and take the same damage as players. This makes it possible to skeet AI Hunter.
   * Players cannot skip their deathcam by pressing space or clicking.
   * Block Infected player who use E spawn expolit to teleport to survivor
   * Block pumpshotgunswap quick shoot
   * Players that use an exploit to skip spawn timer will now have few seconds staying spectator team
   * Ammo pickup fix
   * Spectators stay spectator on map change.
   * Forces all players on the right team after map/campaign/match change"
   * Fixed a l4d1 value bug that you can not see the real hittable car hitbox when tank punches them
      > **Developer Comment:** This often happened in l4d1, players can not find the toy to hit it after the first punch .. until after several seconds it reappears in its place. Add Shadow Model color which attaches to the real hittable hitbox so that everyone including survivors can see. If you have played l4d1 versus for a long time, you knew what I am fking talking about.

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
      * [l4d1 Witch Party](https://steamcommunity.com/groups/ibserver#announcements/detail/1720837068961859143)
      * [l4d1 multi Hunters](https://steamcommunity.com/groups/ibserver#announcements/detail/2924417816908996494)
      
- - - -
### Map Changes(!cm) ###

* **General:**
  * Remove restricted block where Infected coudn't go through
  * Pills
     * All pill cabinets in Valve maps will now have a maximum of 2 pills
     * There are few pills on the road
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
  * [City 17](https://www.gamemaps.com/details/2406)
  * [Suicide Blitz](https://www.gamemaps.com/details/2334)
  * [Dead Flag Blues](https://www.gamemaps.com/details/2379)
  * [I Hate Mountains](https://www.gamemaps.com/details/2595)
  * [Dead Before Dawn](https://www.gamemaps.com/details/2661)
  * [The Arena of the Dead](https://www.gamemaps.com/details/2214)
  
- - - -
### Weapon Adjustments ###
* **Uzi** (based on Zonemod 1.9.3)
  * Still Spread: 0.32->0.26
  * Moveing Spread: 0.32->0.26
  * Ammo: 480->800
  * Damage Drop-off: 0.84->0.84 (unchanged)
  * Reload Speed: 2.23->1.74
  * Damage: 20->22
  * Limit: None
      
* **Pumpshotgun**
  * Air Spread: 2.5->1.5
  * Ammo: 128->100
  * Limit: None
      
* **Hunting Rifle**
  * Rate of fire: 1->0.13
  * Tank dmg: 90->135
  * Hunter dmg: Chest, neck *2.8 - abdominal muscles *1.8
  * Limit: 1
  > **Developer Comment:** As we've noticed in L4D1, the Uzis were completely nothing and shotguns were taking over everything. In the release of Roto-AZMod, I want to make the Uzi more attractiv, which result into the Uzi having more advantages. And there can be a sniper in a team, this Hunting Rifle is nerfed a lot as you can see rate of fire is very slow. Peope can choose thier desired weapons. A team can decide who takes uzi and who takes hunting rifle, each performs one's own best part.

- - - -
### Score Calculation(!health/!bonus) ###
  * ( AD + HB + PILLS ) x Alive x Map 
     * AD = Average distance
     * HB = Health Bonus , Floor(PermanentHealth/2)+RoundToNearest(TemporaryHealth/4)
     * PILLS = 20 Health Bonus per pill
     * Alive = Number of players that survived
     * Map = That level's score multiplier
    > **Developer Comment:** This effectively gives you a higher reward for holding onto pills. and restore level's score multiplier as we consider it's unfair that short map and long map have the same maximum score

- - - -
### Gameplay / Balance Changes ###
 
   
