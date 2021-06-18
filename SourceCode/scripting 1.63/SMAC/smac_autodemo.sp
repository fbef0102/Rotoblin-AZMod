#pragma semicolon 1

#include <sourcemod>
#include <smac>


#undef REQUIRE_PLUGIN
#include <updater>
#include <tEasyFTP>

#undef REQUIRE_EXTENSIONS
#include <bzip2>


#define UPDATE_URL			"http://hg.doctormckay.com/public-plugins/raw/default/smac-autodemo.txt"
#define PLUGIN_VERSION		"1.2.0"

public Plugin:myinfo = {
	name        = "[ANY] SMAC AutoDemo",
	author      = "Dr. McKay",
	description = "Automatically records demos of players who are suspected of cheating",
	version     = PLUGIN_VERSION,
	url         = "http://www.doctormckay.com"
};

new Handle:cvarUpdater;
new Handle:cvarCompressionLevel;
new Handle:cvarUploadDemos;
new Handle:hudTimestamp;
new Handle:hudCheaters;
new Handle:lockedConVars;
new String:currentDemoFilename[128];
new Handle:currentDemoClients;

new bool:aimbotDetected[MAXPLAYERS + 1];

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) {
	MarkNativeAsOptional("Updater_AddPlugin");
	MarkNativeAsOptional("EasyFTP_UploadFile");
	return APLRes_Success;
}

public OnPluginStart() {
	cvarUpdater = CreateConVar("smac_autodemo_auto_update", "1", "Enables automatic updating (has no effect if Updater is not installed)");
	cvarCompressionLevel = CreateConVar("smac_autodemo_compression_level", "5", "Compression level for auto demos (only if the bzip2 extension is installed). Use 0 to disable demo compression.", _, true, 0.0, true, 9.0);
	cvarUploadDemos = CreateConVar("smac_autodemo_ftp_upload", "0", "If enabled and tEasyFTP is installed, demos will be uploaded to the location specified in the \"autodemo\" configuration.", _, true, 0.0, true, 1.0);
	hudTimestamp = CreateHudSynchronizer();
	hudCheaters = CreateHudSynchronizer();
	
	decl String:path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "recordings");
	if(!DirExists(path)) {
		CreateDirectory(path, FPERM_U_READ|FPERM_U_WRITE|FPERM_U_EXEC|FPERM_G_READ|FPERM_G_EXEC|FPERM_O_READ|FPERM_O_EXEC);
	}
	
	lockedConVars = CreateTrie();
	SetTrieValue(lockedConVars, "tv_enable", 1);
	SetTrieValue(lockedConVars, "tv_autorecord", 0);
	
	new Handle:convar = FindConVar("tv_enable");
	SetConVarInt(convar, 1);
	HookConVarChange(convar, OnLockedConVarChanged);
	convar = FindConVar("tv_autorecord");
	SetConVarInt(convar, 0);
	HookConVarChange(convar, OnLockedConVarChanged);
}

public OnLockedConVarChanged(Handle:convar, const String:oldValue[], const String:newValue[]) {
	decl String:name[64];
	GetConVarName(convar, name, sizeof(name));
	new requiredValue;
	GetTrieValue(lockedConVars, name, requiredValue);
	if(GetConVarInt(convar) != requiredValue) {
		SMAC_Log("ConVar %s changed from required value of %i. Setting back to %i.", name, requiredValue, requiredValue);
		SetConVarInt(convar, requiredValue);
	}
}

public OnMapStart() {
	CreateTimer((hudTimestamp == INVALID_HANDLE) ? 12.0 : 1.0, Timer_UpdateHud, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public OnClientConnected(client) {
	aimbotDetected[client] = false;
}

FindSourceTV() {
	new sourcetv = -1;
	for(new i = 1; i <= MaxClients; i++) {
		if(!IsClientInGame(i)) {
			continue;
		}
		if(IsClientSourceTV(i)) {
			sourcetv = i;
			break;
		}
	}
	return sourcetv;
}

public Action:Timer_UpdateHud(Handle:timer) {
	new client = FindSourceTV();
	if(client == -1) {
		return; // SourceTV not present
	}
	if(hudTimestamp != INVALID_HANDLE) {
		decl String:timestamp[128];
		FormatTime(timestamp, sizeof(timestamp), "%H:%M:%S %m/%d/%Y");
		SetHudTextParams(0.8, 0.91, 1.1, 0, 255, 0, 255);
		ShowSyncHudText(client, hudTimestamp, timestamp);
	}
	if(currentDemoClients == INVALID_HANDLE) {
		return;
	}
	decl String:cheaters[MAX_NAME_LENGTH * 6];
	Format(cheaters, sizeof(cheaters), "Suspected cheater(s): ");
	new bool:first = true;
	for(new i = 0; i < GetArraySize(currentDemoClients); i++) {
		if(IsClientInGame(GetArrayCell(currentDemoClients, i))&&!IsFakeClient(GetArrayCell(currentDemoClients, i))){
			if(first) {
				Format(cheaters, sizeof(cheaters), "%s%N", cheaters, GetArrayCell(currentDemoClients, i));
				first = false;
			} else {
				Format(cheaters, sizeof(cheaters), "%s, %N", cheaters, GetArrayCell(currentDemoClients, i));
			}
		}
	}
	if(hudCheaters != INVALID_HANDLE) {
		SetHudTextParams(-1.0, 0.09, 1.1, 0, 255, 0, 255);
		ShowSyncHudText(client, hudCheaters, cheaters);
	} else {
		PrintToChatAll("\x01\x0B\x04%s", cheaters);
	}
}

public Action:SMAC_OnCheatDetected(client, const String:module[]) {
	if(StrEqual(module, "smac_aimbot.smx", false) && !aimbotDetected[client]) {
		aimbotDetected[client] = true; // first aimbot detection, likely a false positive
		return Plugin_Continue;
	}
	if(FindSourceTV() == -1) {
		SMAC_Log("SourceTV is not present so an AutoDemo could not be recorded.");
		return Plugin_Continue;
	}
	if(currentDemoClients != INVALID_HANDLE && FindValueInArray(currentDemoClients, client) != -1) {
		return Plugin_Continue; // we're already recording this player
	}
	CreateTimer(2.0, Timer_Delay, GetClientUserId(client)); // delay for a couple seconds in case the client gets kicked or banned
	return Plugin_Continue;
}

public Action:Timer_Delay(Handle:timer, any:userid) {
	new client = GetClientOfUserId(userid);
	if(client == 0) {
		return; // client left
	}
	ServerCommand("exec sourcemod/smac_recording.cfg");
	if(currentDemoClients != INVALID_HANDLE) {
		SMAC_Log("Demo recording already in progress. See %s for a recording of %L", currentDemoFilename, client);
		PushArrayCell(currentDemoClients, client);
		return;
	}
	currentDemoClients = CreateArray();
	PushArrayCell(currentDemoClients, client);
	decl String:time[64], String:map[64];
	FormatTime(time, sizeof(time), "%Y-%m-%d_%H-%M-%S");
	GetCurrentMap(map, sizeof(map));
	Format(currentDemoFilename, sizeof(currentDemoFilename), "%s_%s.dem", time, map);
	decl String:path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "recordings/%s", currentDemoFilename);
	SMAC_Log("Recording demo %s for client %L", currentDemoFilename, client);
	ServerCommand("tv_record %s", path);
}

public OnClientDisconnect(client) {
	if(currentDemoClients == INVALID_HANDLE) {
		return;
	}
	new index = FindValueInArray(currentDemoClients, client);
	if(index == -1) {
		return;
	}
	// at this point, we know that this client was being recorded
	RemoveFromArray(currentDemoClients, index);
	if(GetArraySize(currentDemoClients) == 0) {
		CloseHandle(currentDemoClients);
		currentDemoClients = INVALID_HANDLE;
		SMAC_Log("Ending recording of %s", currentDemoFilename);
		ServerCommand("tv_stoprecord");
		if(LibraryExists("bzip2") && GetConVarInt(cvarCompressionLevel) != 0) {
			new Handle:pack = CreateDataPack();
			WritePackString(pack, currentDemoFilename);
			CreateTimer(2.0, Timer_CompressDemo, pack);
		} else if(GetConVarBool(cvarUploadDemos) && LibraryExists("teftp")) {
			decl String:path[PLATFORM_MAX_PATH];
			BuildPath(Path_SM, path, sizeof(path), "recordings/%s", currentDemoFilename);
			EasyFTP_UploadFile("autodemo", path, "/", OnFileUploaded);
		}
	} else {
		SMAC_Log("Recorded client %L has disconnected, but other clients are still being recorded in %s", client, currentDemoFilename);
	}
}

public Action:Timer_CompressDemo(Handle:timer, any:pack) {
	ResetPack(pack);
	decl String:filename[128];
	ReadPackString(pack, filename, sizeof(filename));
	decl String:input[PLATFORM_MAX_PATH], String:output[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, input, sizeof(input), "recordings/%s", filename);
	BuildPath(Path_SM, output, sizeof(output), "recordings/%s.bz2", filename);
	BZ2_CompressFile(input, output, GetConVarInt(cvarCompressionLevel), OnDemoCompressed, pack);
}

public OnDemoCompressed(BZ_Error:iError, String:inFile[], String:outFile[], any:pack) {
	ResetPack(pack);
	decl String:filename[128];
	ReadPackString(pack, filename, sizeof(filename));
	CloseHandle(pack);
	if(_:iError < 0) {
		decl String:suffix[256];
		Format(suffix, sizeof(suffix), "while compressing %s", filename);
		LogBZ2Error(iError, suffix);
		return;
	}
	decl String:path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "recordings/%s", filename);
	DeleteFile(path);
	if(GetConVarBool(cvarUploadDemos) && LibraryExists("teftp")) {
		StrCat(path, sizeof(path), ".bz2");
		EasyFTP_UploadFile("autodemo", path, "/", OnFileUploaded);
	}
}

public OnFileUploaded(const String:target[], const String:localFile[], const String:remoteFile[], errorCode, any:data) {
	if(errorCode != 0) {
		LogError("Problem uploading %s. Error code: %i", localFile, errorCode);
	}
}

public OnMapEnd() {
	ServerCommand("tv_stoprecord");
	if(currentDemoClients != INVALID_HANDLE) {
		CloseHandle(currentDemoClients);
		currentDemoClients = INVALID_HANDLE;
	}
}

public OnPluginEnd() {
	ServerCommand("tv_stoprecord");
}

/////////////////////////////////

public OnAllPluginsLoaded() {
	new Handle:convar;
	if(LibraryExists("updater")) {
		Updater_AddPlugin(UPDATE_URL);
		new String:newVersion[10];
		Format(newVersion, sizeof(newVersion), "%sA", PLUGIN_VERSION);
		convar = CreateConVar("smac_autodemo_version", newVersion, "SMAC AutoDemo Version", FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_CHEAT);
	} else {
		convar = CreateConVar("smac_autodemo_version", PLUGIN_VERSION, "SMAC AutoDemo Version", FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_CHEAT);	
	}
	HookConVarChange(convar, Callback_VersionConVarChanged);
}

public OnLibraryAdded(const String:name[]) {
	if(StrEqual(name, "updater")) {
		Updater_AddPlugin(UPDATE_URL);
	}
}

public Callback_VersionConVarChanged(Handle:convar, const String:oldValue[], const String:newValue[]) {
	ResetConVar(convar);
}

public Action:Updater_OnPluginDownloading() {
	if(!GetConVarBool(cvarUpdater)) {
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Updater_OnPluginUpdated() {
	ReloadPlugin();
}