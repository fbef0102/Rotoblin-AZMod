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
  * Mapcyclelist: -left4dead/addons/sourcemod/data/sm_l4dvs_mapchanger.txt
  * Jukebox spawn position: -left4dead/addons/sourcemod/data/l4d1_jukebox_spawns.cfg
  * Save player chat (and team chat) to a file: -left4dead/addons/sourcemod/logs/chat/
  * Server password、rates、maxplayers、tags、group: -left4dead/cfg/server.cfg、server_rates.cfg、server_startup.cfg
  * If you have a prefered edition of a Plugin, you are able to simply replace the file in sourcemod/plugins folder.
    * do not overwrite any plugin that's existed.
  * To make it easy for personal configuration for certain plugins, there's an added "server_custom_convars.cfg" in the left4dead/cfg/Reloadables folder.
    * Keep in mind that this is a shared cfg, server excutes it after every mode loaded and map change, so it'll only contain shared cvars.
    * very useful for Admins wanting to load 1v1~4v4 supported plugins on top of the Configs.

* Admin Tips:
  * Crash Course Unprohibit Bosses.vpk force versus director to spawn tank and witch each stage on "crash cource"
  * bequiet.smx is a very useful plugin to keep chat clean, if you decide to load it in other configs, make sure it's loaded before other plugins or set bequiet's "bq_show_player_team_chat_spec" cvar to 0.
  * l4d_versus_specListener3.0.smx comes with a "Spec-Listening Feature", even if sv_alltalk 0, specators can still see in-game players teamchat and hear their mic voice.
  * TickRateFixes.smx now also fixes Server Gravity and Pistol Scripts.
    * Make sure you're not loading l4dpistoldelay if you're using this Plugin.
  * Specrates.smx is a useful plugin to reduce server load causes by spectators.
    * This will send less updates to Spectators whilst maintaining a pleasant viewing experience.
  * When player connects or disconnected, it would print the message about steamid and ip only adms can see.
  * [All Admin commands](https://github.com/fbef0102/Rotoblin-AZMod/blob/master/Rule%26developer/Roto-AZMod%20Adm%20Commands.png)
 
