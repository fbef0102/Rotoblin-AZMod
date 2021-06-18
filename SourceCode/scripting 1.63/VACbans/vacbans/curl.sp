void cURLConnectToApi(int client, const char[] steamID)
{
#if DEBUG
	LogToFile(g_debugLogPath, "Using cURL");
#endif

	DataPack hPack = new DataPack();
	DataPack hData = new DataPack();
	hPack.WriteCell(client);
	hPack.WriteCell(hData);
	hPack.WriteString(steamID);

	char url[128];
	Format(url, sizeof(url), "https://%s%s%s", API_HOST, g_baseUrl, steamID);

	Handle curl = curl_easy_init();
	curl_easy_setopt_string(curl, CURLOPT_URL, url);
	curl_easy_setopt_function(curl, CURLOPT_WRITEFUNCTION, OnCurlWrite, hData);
	curl_easy_perform_thread(curl, OnCurlComplete, hPack);
}

public int OnCurlWrite(Handle hndl, const char[] buffer, const int bytes, const int nmemb, DataPack hData)
{
	hData.WriteString(buffer);
}

public int OnCurlComplete(Handle hndl, CURLcode code, DataPack hPack)
{
	hPack.Reset();
	int client = hPack.ReadCell();
	DataPack hData = hPack.ReadCell();
	char steamID[18];
	hPack.ReadString(steamID, sizeof(steamID));

	if (code == CURLE_OK)
	{
		int statusCode;
		curl_easy_getinfo_int(hndl, CURLINFO_RESPONSE_CODE, statusCode);
		if (statusCode != 200)
		{
			LogError("HTTP error: %d (using cURL)", statusCode);
			HandleClient(client, steamID, true);
		}
		else
		{
			hData.Reset();

			char responseData[1024];
			char buffer[1024];
			while (hData.IsReadable(1)) {
				hData.ReadString(buffer, sizeof(buffer));
				StrCat(responseData, sizeof(responseData), buffer);
			}

			UpdateClientStatus(client, responseData);
			HandleClient(client, steamID, false);
		}
	}
	else
	{
		char message[128];
		curl_easy_strerror(code, message, sizeof(message));
		LogError("cURL error %d (%s)", code, message);

		HandleClient(client, steamID, true);
	}

	delete hPack;
}
