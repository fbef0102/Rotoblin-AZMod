#include <sourcemod>
#include <sdktools>

#pragma semicolon 1
#define PLUGIN_VERSION "1.1"

#define		DN_TAG		"[DHostName]"
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
	url = "myself"
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
}