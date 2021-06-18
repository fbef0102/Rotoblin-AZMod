/*******************************************************************************

  SM File/Folder Downloader and Precacher

  Version: 1.5
  Author: SWAT_88,Harry

  1.0 	First version, should work on basically any mod
 
  1.1	Added new features:	
		Added security checks.
		Added map specific downloads.
		Added simple downloads.
  1.2	Added Folder Download Feature.
  1.3	Version for testing.
  1.4	Fixed some bugs.
		Closed all open Handles.
		Added more security checks.
  1.5   Convar : Full path of the configuration file to load
   
  Description:
  
	This Plugin downloads and precaches the Files in downloads.ini.
	There are several categories for Download and Precache in downloads.ini.
	The downloads_simple.ini contains simple downloads (no precache), like the original.
	Folder Download usage:
	Write your folder name in the downloads.ini or downloads_simple.ini.
	Example:
	Correct: sound/misc
	Incorrect: sound/misc/
	
  Commands:
  
	None.

  Cvars:

	sm_downloader_enabled 	"1"		- 0: disables the plugin - 1: enables the plugin
	
	sm_downloader_normal	"1"		- 0: dont use downloads.ini - 1: Use downloads.ini
	
	sm_downloader_simple	"1"		- 0: dont use downloads_simple.ini	- 1: Use downloads_simple.ini

  Setup (SourceMod):

	Install the smx file to addons\sourcemod\plugins.
	Install the downloads.ini to addons\sourcemod\configs.
	Install the downloads_simple.ini to addons\sourcemod\configs.
	(Re)Load Plugin or change Map.
	
  TO DO:
  
	Nothing make a request.
	
  Copyright:
  
	Everybody can edit this plugin and copy this plugin.
	
  Thanks to:
	pRED*
	sfPlayer

  Tester:
	J@y-R
	FunTF2Server
	
  HAVE FUN!!!

*******************************************************************************/

#include <sourcemod>
#include <sdktools>
#include include/sdkhooks.inc

#define SM_DOWNLOADER_VERSION		"1.5"

new Handle:g_version=INVALID_HANDLE;
new Handle:g_enabled=INVALID_HANDLE;
new Handle:g_simple=INVALID_HANDLE;
new Handle:g_normal=INVALID_HANDLE;
new Handle:g_file=INVALID_HANDLE;
new Handle:g_file_simple=INVALID_HANDLE;

new String:map[256];
new bool:downloadfiles=true;
new String:mediatype[256];
new downloadtype;

public Plugin:myinfo = 
{
	name = "SM File/Folder Downloader and Precacher",
	author = "SWAT_88, v1.5 Harry",
	description = "Downloads and Precaches Files",
	version = SM_DOWNLOADER_VERSION,
	url = "http://www.sourcemod.net"
}

public OnPluginStart()
{
	g_simple = CreateConVar("sm_downloader_simple","1");
	g_normal = CreateConVar("sm_downloader_normal","1");
	g_enabled = CreateConVar("sm_downloader_enabled","1");
	g_version = CreateConVar("sm_downloader_version",SM_DOWNLOADER_VERSION,"SM File Downloader and Precacher Version",FCVAR_NOTIFY);
	SetConVarString(g_version,SM_DOWNLOADER_VERSION);
	g_file = CreateConVar("sm_downloader_config", "configs/sm_downloader/downloads.ini", "Full path of the configuration file to load: (IE: configs/simpledownloader.cfg)", FCVAR_NOTIFY);
	g_file_simple = CreateConVar("sm_simpledownloader_config", "configs/sm_downloader/downloads_simple.ini", "Full path of the configuration file to load: (IE: configs/simpledownloader.cfg)", FCVAR_NOTIFY);
	HookConVarChange(g_file, OnCvarFileChange_control);
	HookConVarChange(g_file_simple, OnCvarFileSimpleChange_control);
}

public OnCvarFileChange_control(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (!StrEqual(oldValue, newValue))
	{
		SetConVarString(g_file, newValue);
		if(GetConVarInt(g_enabled) == 1){
			if(GetConVarInt(g_normal) == 1) ReadDownloads();
		}
	}
}

public OnCvarFileSimpleChange_control(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (!StrEqual(oldValue, newValue))
	{
		SetConVarString(g_file_simple, newValue);
		if(GetConVarInt(g_enabled) == 1){
			if(GetConVarInt(g_simple) == 1) ReadDownloadsSimple();
		}
	}
}

public OnPluginEnd(){
	CloseHandle(g_version);
	CloseHandle(g_enabled);
	CloseHandle(g_simple);
	CloseHandle(g_normal);
}

public OnMapStart(){	
	if(GetConVarInt(g_enabled) == 1){
		if(GetConVarInt(g_normal) == 1) ReadDownloads();
		if(GetConVarInt(g_simple) == 1) ReadDownloadsSimple();
	}
}

public ReadFileFolder(String:path[]){
	new Handle:dirh = INVALID_HANDLE;
	new String:buffer[256];
	new String:tmp_path[256];
	new FileType:type = FileType_Unknown;
	new len;
	
	len = strlen(path);
	if (path[len-1] == '\n')
		path[--len] = '\0';

	TrimString(path);
	
	if(StrContains(path,"addons\\",true) >= 0)
	{
		if(StrContains(path,"city17.vpk",true) >= 0)
			Format(path, len, "addons\\city17.vpk");
		else if (StrContains(path,"deadbeforedawn.vpk",true) >= 0)
			Format(path, len, "addons\\deadbeforedawn.vpk");
		else if (StrContains(path,"deadflagblues.vpk",true) >= 0)
			Format(path, len, "addons\\deadflagblues.vpk");
		else if (StrContains(path,"ihatemountains.vpk",true) >= 0)
			Format(path, len, "addons\\ihatemountains.vpk");
		else if (StrContains(path,"suicideblitz.vpk",true) >= 0)
			Format(path, len, "addons\\suicideblitz.vpk");
		else if (StrContains(path,"jsarena.vpk",true) >= 0)
			Format(path, len, "addons\\jsarena.vpk");
		AddFileToDownloadsTable(path);
	}
	else
	{
		if(DirExists(path)){
			dirh = OpenDirectory(path);
			while(ReadDirEntry(dirh,buffer,sizeof(buffer),type)){
				len = strlen(buffer);
				if (buffer[len-1] == '\n')
					buffer[--len] = '\0';

				TrimString(buffer);

				if (!StrEqual(buffer,"",false) && !StrEqual(buffer,".",false) && !StrEqual(buffer,"..",false)){
					strcopy(tmp_path,255,path);
					StrCat(tmp_path,255,"/");
					StrCat(tmp_path,255,buffer);
					if(type == FileType_File){
						if(downloadtype == 1){
							ReadItem(tmp_path);
						}
						else{
							ReadItemSimple(tmp_path);
						}
					}
					else{
						ReadFileFolder(tmp_path);
					}
				}
			}
		}
		else{
			if(downloadtype == 1){
				ReadItem(path);
			}
			else{
				ReadItemSimple(path);
			}
		}
	}
	if(dirh != INVALID_HANDLE){
		CloseHandle(dirh);
	}
}

public ReadDownloads(){

	decl String:sConVarPath[PLATFORM_MAX_PATH];
	GetConVarString(g_file, sConVarPath, sizeof(sConVarPath));
	
	decl String:file[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, file, sizeof(file), sConVarPath)
	
	new Handle:fileh = OpenFile(file, "r");
	new String:buffer[256];
	downloadtype = 1;
	new len;
	
	GetCurrentMap(map,255);
	
	if(fileh == INVALID_HANDLE) return;
	while (ReadFileLine(fileh, buffer, sizeof(buffer)))
	{	
		len = strlen(buffer);
		if (buffer[len-1] == '\n')
			buffer[--len] = '\0';

		TrimString(buffer);

		if(!StrEqual(buffer,"",false)){
			ReadFileFolder(buffer);
		}
		
		if (IsEndOfFile(fileh))
			break;
	}
	if(fileh != INVALID_HANDLE){
		CloseHandle(fileh);
	}
}

public ReadItem(String:buffer[]){
	new len = strlen(buffer);
	if (buffer[len-1] == '\n')
		buffer[--len] = '\0';
	
	TrimString(buffer);
	
	if(StrContains(buffer,"//Files (Download Only No Precache)",true) >= 0){
		strcopy(mediatype,255,"File");
		downloadfiles=true;
	}
	else if(StrContains(buffer,"//Decal Files (Download and Precache)",true) >= 0){
		strcopy(mediatype,255,"Decal");
		downloadfiles=true;
	}
	else if(StrContains(buffer,"//Sound Files (Download and Precache)",true) >= 0){
		strcopy(mediatype,255,"Sound");
		downloadfiles=true;
	}
	else if(StrContains(buffer,"//Model Files (Download and Precache)",true) >= 0){
		strcopy(mediatype,255,"Model");
		downloadfiles=true;
	}
	else if(len >= 2 && buffer[0] == '/' && buffer[1] == '/'){
		//Comment
		if(StrContains(buffer,"//") >= 0){
			ReplaceString(buffer,255,"//","");
		}
		if(StrEqual(buffer,map,true)){
			downloadfiles=true;
		}
		else if(StrEqual(buffer,"Any",false)){
			downloadfiles=true;
		}
		else{
			downloadfiles=false;
		}
	}
	else if (!StrEqual(buffer,"",false) && FileExists(buffer))
	{
		if(downloadfiles){
			if(StrContains(mediatype,"Decal",true) >= 0){
				PrecacheDecal(buffer,true);
			}
			else if(StrContains(mediatype,"Sound",true) >= 0){
				PrecacheSound(buffer,true);
			}
			else if(StrContains(mediatype,"Model",true) >= 0){
				PrecacheModel(buffer,true);
			}
			AddFileToDownloadsTable(buffer);
		}
	}
}

public ReadDownloadsSimple(){

	decl String:sConVarPath[PLATFORM_MAX_PATH];
	GetConVarString(g_file_simple, sConVarPath, sizeof(sConVarPath));
	
	decl String:file[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, file, sizeof(file), sConVarPath)
	
	new Handle:fileh = OpenFile(file, "r");
	new String:buffer[256];
	downloadtype = 2;
	new len;
	
	if(fileh == INVALID_HANDLE) return;
	while (ReadFileLine(fileh, buffer, sizeof(buffer)))
	{
		len = strlen(buffer);
		if (buffer[len-1] == '\n')
			buffer[--len] = '\0';

		TrimString(buffer);

		if(!StrEqual(buffer,"",false)){
			ReadFileFolder(buffer);
		}
		
		if (IsEndOfFile(fileh))
			break;
	}
	if(fileh != INVALID_HANDLE){
		CloseHandle(fileh);
	}
}

public ReadItemSimple(String:buffer[]){
	new len = strlen(buffer);
	if (buffer[len-1] == '\n')
		buffer[--len] = '\0';
	
	TrimString(buffer);
	if(len >= 2 && buffer[0] == '/' && buffer[1] == '/'){
		//Comment
	}
	else if (!StrEqual(buffer,"",false) && FileExists(buffer))
	{
		AddFileToDownloadsTable(buffer);
	}
}

public Action:OnFileSend(int client, const char[] sFile)
{
	//LogMessage("hello\nhello\nhello\nOnFileSend %N %s",client, sFile);
	return Plugin_Handled;
}

public Action:OnFileReceive(int client, const char[] sFile)
{
	//LogMessage("hello\nhello\nhello\nOnFileReceive %N %s",client, sFile);
	return Plugin_Handled;
}

public OnClientConnected(client)
{
  
  if(IsClientConnected(client)&&!IsClientInGame(client)&&!IsFakeClient(client))
	CreateTimer(6.0,TimerShowMessage,client);
}

public Action:TimerShowMessage(Handle:timer,any:client)
{
  if((IsClientConnected(client)&&IsClientInGame(client)&&!IsFakeClient(client))||!IsClientConnected(client))
	return Plugin_Handled;
  ReplyToCommand(client,"===========================================");
  ReplyToCommand(client,"=   服务器下载需要的文件，请耐心等待...   =");
  ReplyToCommand(client,"=   Downloading files，please wait...     =");
  ReplyToCommand(client,"===========================================");
  
  CreateTimer(3.0,TimerShowMessage2,client,TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
  return Plugin_Handled;

}

public Action:TimerShowMessage2(Handle:timer,any:client)
{
  if(!IsClientConnected(client))
	return Plugin_Stop;
  if(IsClientConnected(client)&&IsClientInGame(client)&&!IsFakeClient(client))
  {
	ReplyToCommand(client,"===========================================");
	ReplyToCommand(client,"=   服务器下载完成，正在進入伺服器...     =");
	ReplyToCommand(client,"=   Downloading finished，conneting...    =");
	ReplyToCommand(client,"===========================================");
	return Plugin_Stop;
  }

  ReplyToCommand(client,"===========================================");
  ReplyToCommand(client,"=   服务器下载需要的文件，请耐心等待...   =");
  ReplyToCommand(client,"=   Downloading files，please wait...     =");
  ReplyToCommand(client,"===========================================");
  
  return Plugin_Continue;
}