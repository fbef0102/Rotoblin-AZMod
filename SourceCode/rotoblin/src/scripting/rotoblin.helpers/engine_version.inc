/*
 * ============================================================================
 *
 * This file is part of the Rotoblin 2 project.
 *
 *  File:			engine_version.inc
 *  Type:			include
 *  Description:	...
 *  Credits:	 	Thanks mcpan313 and Silver.
 *
 *  Copyright (C) 2012-2015 raziEiL <war4291@mail.ru>
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * ============================================================================
 */

new		bool:g_bLoadLater;

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	if (!IsDedicatedServer()){

		strcopy(error, err_max, "Unable to enable rotoblin, running on a listen server!");
		return APLRes_Failure;
	}

	if (!IsL4DGame()){

		strcopy(error, err_max, "Rotoblin only support L4D engine");
		return APLRes_Failure;
	}

	decl String:line[256], iResult;

	StripQuotes(INF);

	new Handle:hFile = OpenFile(INF, "r");

	if (hFile == INVALID_HANDLE)
		return APLRes_Failure;

	FileSeek(hFile, 0, SEEK_SET);

	while (!IsEndOfFile(hFile) && ReadFileLine(hFile, line, 256))
	{
		TrimString(line);
		if (StrContains(line, PATCH) != -1)
		{
			ReplaceString(line, 256, PATCH, "");
			ReplaceString(line, 256, ".", "");

			iResult = StringToInt(line);

			if (iResult >= GenerateKey(VALID_KEY)){

				CloseHandle(hFile);
				g_bLoadLater = late;
				RegR2Lib();

				return APLRes_Success;
			}
		}
	}

	CloseHandle(hFile);
	FormatEx(error, err_max, "FATAL ERROR 0x%x.", iResult);

	return APLRes_Failure;
}

static RegR2Lib()
{
	RegPluginLibrary("r2compmod");

	CreateNative("R2comp_GetMobTimer", Native_R2comp_GetMobTimer);
	CreateNative("R2comp_IsStartEntity", Native_R2comp_IsStartEntity);
	CreateNative("R2comp_IsEndEntity", Native_R2comp_IsEndEntity);
	CreateNative("R2comp_GetSafeRoomOrigin", Native_R2comp_GetSafeRoomOrigin);
	CreateNative("R2comp_GetMatchName", Native_R2comp_GetMatchName);
	CreateNative("R2comp_GetHighestSurvivorFlow", Native_R2comp_GetHighestSurvivorFlow);
	CreateNative("R2comp_GetHighestSurvivorFlowEx", Native_R2comp_GetHighestSurvivorFlowEx);
	CreateNative("R2comp_IsUnscrambled", Native_R2comp_IsUnscrambled);

	#if SCORES_COMMAND
		CreateNative("R2comp_GetScore", Native_R2comp_GetCampaingScore);
	#endif

	MarkCompNatives();
}

static GenerateKey(String:sValue[12])
{
	decl String:sHex[24], String:sNum[2], String:sVal[2];
	FormatEx(sHex, 24, "0123456789ABCDEF");

	new iNum, iNums, iVal;
	new iLen = strlen(sValue);

	for( new i = 1; i <= iLen; i++ )
	{
		FormatEx(sNum, 2, "%s", sValue[iLen - i]);

		for( new u = 0; u < 16; u++ )
		{
			FormatEx(sVal, 2, "%s", sHex[u]);
			if( strcmp(sNum, sVal) == 0 )
			{
				iNum = u;
				break;
			}
		}

		if( i == 1 )
			iNums = iNum;
		else
			iNums = iNum * RoundFloat(Pow(16.0, float(i-1)));
		iVal += iNums;
	}
	return iVal;
}