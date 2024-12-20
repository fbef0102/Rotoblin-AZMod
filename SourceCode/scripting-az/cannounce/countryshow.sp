/*****************************************************************


			G L O B A L   V A R S


*****************************************************************/
new Handle:g_CvarShowConnect = INVALID_HANDLE;
new Handle:g_CvarShowDisconnect = INVALID_HANDLE;
new Handle:g_CvarShowEnhancedToAdmins = INVALID_HANDLE;

new String:dcreason[65];
/*****************************************************************


			F O R W A R D   P U B L I C S


*****************************************************************/
SetupCountryShow()
{
	g_CvarShowConnect = CreateConVar("sm_ca_showenhanced", "1", "displays enhanced message when player connects");
	g_CvarShowDisconnect = CreateConVar("sm_ca_showenhanceddisc", "1", "displays enhanced message when player disconnects");
	g_CvarShowEnhancedToAdmins = CreateConVar("sm_ca_showenhancedadmins", "1", "displays a different enhanced message to admin players (ADMFLAG_GENERIC)");
}

OnPostAdminCheck_CountryShow(client)
{
	//if enabled, show message
	if( GetConVarInt(g_CvarShowConnect) )
	{
		//if sm_ca_showenhancedadmins - show diff messages to admins
		if( GetConVarInt(g_CvarShowEnhancedToAdmins) )
		{
			PrintFormattedMessageToAdmins( client,1 );
			PrintFormattedMsgToNonAdmins( client,1 );
		}
		else
		{
			PrintFormattedMessageToAll( client,1 );
		}
	}	
}


/****************************************************************


			C A L L B A C K   F U N C T I O N S


****************************************************************/
void event_PlayerDisc_CountryShow(Event event, int client)
{
	//if enabled, show message
	if( GetConVarInt(g_CvarShowDisconnect) )
	{
		GetEventString(event, "reason", dcreason, sizeof(dcreason));

		//if sm_ca_showenhancedadmins - show diff messages to admins
		if( GetConVarInt(g_CvarShowEnhancedToAdmins) )
		{
			PrintFormattedMessageToAdmins( client,0 );
			PrintFormattedMsgToNonAdmins( client,0 );
		}
		else
		{
			PrintFormattedMessageToAll( client,0 );
		}
	}
}