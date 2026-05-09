/*****************************************************************


			G L O B A L   V A R S


*****************************************************************/
ConVar g_CvarShowConnect = null;
ConVar g_CvarShowDisconnect = null;
ConVar g_CvarShowEnhancedToAdmins = null;


/*****************************************************************


			F O R W A R D   P U B L I C S


*****************************************************************/
void SetupCountryShow()
{
	g_CvarShowConnect = CreateConVar("sm_ca_showenhanced", "1", "displays enhanced message when player connects");
	g_CvarShowDisconnect = CreateConVar("sm_ca_showenhanceddisc", "1", "displays enhanced message when player disconnects");
	g_CvarShowEnhancedToAdmins = CreateConVar("sm_ca_showenhancedadmins", "1", "displays a different enhanced message to admin players (ADMFLAG_GENERIC)");
}

void OnPostAdminCheck_CountryShow(int client)
{
	//if enabled, show message
	if( g_CvarShowConnect.BoolValue )
	{
		//if sm_ca_showenhancedadmins - show diff messages to admins
		if( g_CvarShowEnhancedToAdmins.BoolValue )
		{
			PrintFormattedMessageToAdmins( client, true );
			PrintFormattedMsgToNonAdmins( client, true );
			PrintMsgToSourceTV( client, true );
		}
		else
		{
			PrintFormattedMessageToAll( client, true );
			PrintMsgToSourceTV( client, true );
		}
	}	
}


/****************************************************************


			C A L L B A C K   F U N C T I O N S


****************************************************************/
void event_PlayerDisc_CountryShow(Event event)
{
	char sReason[128];
	
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	//if enabled, show message
	if( g_CvarShowDisconnect.BoolValue )
	{
		event.GetString("reason", sReason, sizeof(sReason));
		
		//if sm_ca_showenhancedadmins - show diff messages to admins
		if( g_CvarShowEnhancedToAdmins.BoolValue )
		{
			PrintFormattedMessageToAdmins( client, false, sReason );
			PrintFormattedMsgToNonAdmins( client, false, sReason );
			PrintMsgToSourceTV( client, false );
		}
		else
		{
			PrintFormattedMessageToAll( client, false, sReason );
			PrintMsgToSourceTV( client, false );
		}
	}
}