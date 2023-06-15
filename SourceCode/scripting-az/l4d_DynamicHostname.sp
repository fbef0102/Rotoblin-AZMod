#include <sourcemod>
#include <sdktools>

#pragma semicolon 1
#define PLUGIN_VERSION "1.3"

#define		SYMBOL_LEFT		'('
#define		SYMBOL_RIGHT	')'

static		Handle:g_hHostName, String:g_sDefaultN[68];
//static Handle:g_hReadyUp;

public Plugin:myinfo = 
{
	name = "L4D Dynamic中文伺服器名",
	author = "Harry Potter",
	description = "Show what mode is it now on chinese server name with txt file",
	version = PLUGIN_VERSION,
	url = "http://steamcommunity.com/profiles/76561198026784913"
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	EngineVersion test = GetEngineVersion();
	
	if( test != Engine_Left4Dead )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1.");
		return APLRes_SilentFailure;
	}

	CreateNative("TS_GetHostName", Native_GetHostName);

	return APLRes_Success;
}

public OnPluginStart()
{
	g_hHostName	= FindConVar("hostname");
	GetConVarString(g_hHostName, g_sDefaultN, sizeof(g_sDefaultN));
	if (strlen(g_sDefaultN))//strlen():回傳字串的長度
		ChangeServerName();
}

public OnConfigsExecuted()
{
	ChangeServerName();
}

ChangeServerName()
{
	decl String:sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath),"configs/hostname/server_hostname.txt");//檔案路徑設定
	
	new Handle:file = OpenFile(sPath, "r");//讀取檔案
	if(file == INVALID_HANDLE)
	{
		LogMessage("file configs/hostname/server_hostname.txt doesn't exist!");
		CloseHandle(file);
		return;
	}
	
	decl String:readData[256];
	if(!IsEndOfFile(file) && ReadFileLine(file, readData, sizeof(readData)))//讀一行
	{
		decl String:sNewName[128];
		
		Format(sNewName, sizeof(sNewName), "[TS] %s", readData);
		SetConVarString(g_hHostName,sNewName);
		
		Format(g_sDefaultN,sizeof(g_sDefaultN),"%s",sNewName);
	}

	CloseHandle(file);
}


// native int TS_GetHostName(char[] str, int size)
int Native_GetHostName(Handle plugin, int numParams)
{
	int size;
	size = GetNativeCell(2);
	if (size <= 0) return false;

	char[] str = new char[size];

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath),"configs/hostname/server_hostname.txt");//檔案路徑設定
	
	new Handle:file = OpenFile(sPath, "r");//讀取檔案
	if(file == INVALID_HANDLE)
	{
		LogMessage("file configs/hostname/server_hostname.txt doesn't exist!");
		CloseHandle(file);
		return false;
	}

	if(!IsEndOfFile(file) && ReadFileLine(file, str, size))//讀一行
	{
		SetNativeString(1, str, size, false);
		CloseHandle(file);
		return true;
	}
	CloseHandle(file);

	return false;
}