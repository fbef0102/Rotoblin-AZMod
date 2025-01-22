#include <sourcemod>
#include <sdktools>

#pragma semicolon 1
#define PLUGIN_VERSION "1.3"

#define		SYMBOL_LEFT		'('
#define		SYMBOL_RIGHT	')'

ConVar g_hHostName;
bool g_bBlockHook;
char sFileHostName[128];

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

	g_hHostName.AddChangeHook(ConVarChanged_HostNameCvars);
	
	ChangeServerName();
}

void ConVarChanged_HostNameCvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if(g_bBlockHook) return;

	ChangeServerName();
}

ChangeServerName()
{
	g_bBlockHook = true;

	decl String:sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath),"configs/hostname/server_hostname.txt");//檔案路徑設定
	
	new Handle:file = OpenFile(sPath, "r");//讀取檔案
	if(file == INVALID_HANDLE)
	{
		LogError("file configs/hostname/server_hostname.txt doesn't exist!");
		CloseHandle(file);
		return;
	}
	
	decl String:readData[256];
	if(!IsEndOfFile(file) && ReadFileLine(file, readData, sizeof(readData)))//讀一行
	{
		decl String:sNewName[128];
		
		Format(sNewName, sizeof(sNewName), "[TS] %s", readData);
		SetConVarString(g_hHostName,sNewName);
		
		Format(sFileHostName,sizeof(sFileHostName),"%s", readData);
	}

	CloseHandle(file);

	g_bBlockHook = false;
}


// native int TS_GetHostName(char[] str, int size)
int Native_GetHostName(Handle plugin, int numParams)
{
	int size;
	size = GetNativeCell(2);
	if (size <= 0) return false;

	SetNativeString(1, sFileHostName, size, false);

	return true;
}