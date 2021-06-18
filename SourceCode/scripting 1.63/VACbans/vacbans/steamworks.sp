void SteamWorksConnectToApi(int client, const char[] steamID)
{
#if DEBUG
	LogToFile(g_debugLogPath, "Using SteamWorks");
#endif

	DataPack hPack = new DataPack();
	hPack.WriteCell(client);
	hPack.WriteString(steamID);

	char url[128];
	Format(url, sizeof(url), "https://%s%s%s", API_HOST, g_baseUrl, steamID);

	Handle hRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, url);
	SteamWorks_SetHTTPCallbacks(hRequest, OnSteamWorksHTTPComplete);
	SteamWorks_SetHTTPRequestContextValue(hRequest, hPack);
	SteamWorks_SendHTTPRequest(hRequest);
}

public int OnSteamWorksHTTPComplete(Handle hRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, DataPack hPack)
{
	if (bRequestSuccessful && eStatusCode == k_EHTTPStatusCode200OK)
	{
		SteamWorks_GetHTTPResponseBodyCallback(hRequest, OnSteamWorksHTTPBodyCallback, hPack);
	}
	else
	{
		if (bRequestSuccessful)
		{
			LogError("HTTP error: %d (using SteamWorks)", eStatusCode);
		}
		else
		{
			LogError("SteamWorks error", LANG_SERVER);
		}

		hPack.Reset();
		int client = hPack.ReadCell();
		char steamID[18];
		hPack.ReadString(steamID, sizeof(steamID));

		HandleClient(client, steamID, true);

		delete hPack;
	}
}

public int OnSteamWorksHTTPBodyCallback(const char[] sData, DataPack hPack)
{
	hPack.Reset();
	int client = hPack.ReadCell();
	char steamID[18];
	hPack.ReadString(steamID, sizeof(steamID));

	UpdateClientStatus(client, sData);
	HandleClient(client, steamID, false);

	delete hPack;
}
