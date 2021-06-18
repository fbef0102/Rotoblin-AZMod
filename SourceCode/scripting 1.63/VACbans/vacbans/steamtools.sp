void SteamToolsConnectToApi(int client, const char[] steamID)
{
#if DEBUG
	LogToFile(g_debugLogPath, "Using SteamTools");
#endif

	DataPack hPack = new DataPack();
	hPack.WriteCell(client);
	hPack.WriteString(steamID);

	char url[128];
	Format(url, sizeof(url), "https://%s%s%s", API_HOST, g_baseUrl, steamID);

	HTTPRequestHandle hRequest = Steam_CreateHTTPRequest(HTTPMethod_GET, url);
	Steam_SendHTTPRequest(hRequest, OnSteamToolsHTTPComplete, hPack);
}

public int OnSteamToolsHTTPComplete(HTTPRequestHandle hRequest, bool bRequestSuccessful, HTTPStatusCode statusCode, DataPack hPack)
{
	hPack.Reset();
	int client = hPack.ReadCell();
	char steamID[18];
	hPack.ReadString(steamID, sizeof(steamID));

	if (bRequestSuccessful && statusCode == HTTPStatusCode_OK)
	{
		char responseData[1024];
		Steam_GetHTTPResponseBodyData(hRequest, responseData, sizeof(responseData));

		UpdateClientStatus(client, responseData);
		HandleClient(client, steamID, false);
	}
	else
	{
		if (bRequestSuccessful)
		{
			LogError("HTTP error: %d (using SteamTools)", statusCode);
		}
		else
		{
			LogError("SteamTools error");
		}

		HandleClient(client, steamID, true);
	}

	Steam_ReleaseHTTPRequest(hRequest);

	delete hPack;
}
