void SocketConnectToApi(int client, const char[] steamID)
{
#if DEBUG
	LogToFile(g_debugLogPath, "Using Socket");
#endif

	DataPack hPack = new DataPack();
	DataPack hData = new DataPack();
	Handle hSock = SocketCreate(SOCKET_TCP, OnSocketError);

	hPack.WriteCell(client);
	hPack.WriteCell(hData);
	hPack.WriteString(steamID);

	SocketSetArg(hSock, hPack);
	SocketConnect(hSock, OnSocketConnected, OnSocketReceive, OnSocketDisconnected, API_HOST, 80);
}

public int OnSocketConnected(Handle hSock, DataPack hPack)
{
	char steamID[18];
	char requestStr[256];

	hPack.Reset();
	hPack.ReadCell();
	hPack.ReadCell();
	hPack.ReadString(steamID, sizeof(steamID));

	Format(requestStr, sizeof(requestStr), "GET %s%s HTTP/1.0\r\nHost: %s\r\nConnection: close\r\n\r\n", g_baseUrl, steamID, API_HOST);
	SocketSend(hSock, requestStr);
}

public int OnSocketReceive(Handle hSock, const char[] receiveData, const int dataSize, DataPack hPack)
{
	hPack.Reset();
	hPack.ReadCell();
	DataPack hData = hPack.ReadCell();

	hData.WriteString(receiveData);
}

public int OnSocketDisconnected(Handle hSock, DataPack hPack)
{
	hPack.Reset();
	int client = hPack.ReadCell();
	DataPack hData = hPack.ReadCell();
	char steamID[18];
	hPack.ReadString(steamID, sizeof(steamID));

	hData.Reset();

	char responseData[1024];
	char buffer[1024];
	while (hData.IsReadable(1)) {
		hData.ReadString(buffer, sizeof(buffer));
		StrCat(responseData, sizeof(responseData), buffer);
	}

	HandleClient(client, steamID, !SocketParseResponse(client, responseData));

	delete hData;
	delete hPack;

	delete hSock;
}

public int OnSocketError(Handle hSock, const int errorType, const int errorNum, DataPack hPack)
{
	LogError("Socket error: %d (errno %d)", errorType, errorNum);

	hPack.Reset();
	int client = hPack.ReadCell();
	hPack.ReadCell();
	char steamID[18];
	hPack.ReadString(steamID, sizeof(steamID));

	HandleClient(client, steamID, true);

	delete hPack;
	delete hSock;
}

/**
 * Parse the HTTP response from the server.
 *
 * @param client   The client index
 * @param response The response from the server
 * @return Whether the response was successfully parsed
 */
bool SocketParseResponse(int client, const char[] response)
{
	int pos = FindCharInString(response, ' ');
	if (pos == -1)
	{
		return false;
	}

	char status[4];
	if (SplitString(response[pos + 1], " ", status, sizeof(status)) == -1)
	{
		return false;
	}

	int code = StringToInt(status);
	if (code != 200)
	{
		char message[64];
		SplitString(response[pos + 5], "\n", message, sizeof(message));
		TrimString(message);
		LogError("HTTP error: %d %s (using Socket)", code, message);

		return false;
	}

	char parts[2][1024];
	if (ExplodeString(response, "\r\n\r\n", parts, sizeof(parts), sizeof(parts[])) < 2)
	{
		return false;
	}

	TrimString(parts[1]);
	UpdateClientStatus(client, parts[1]);

	return true;
}
