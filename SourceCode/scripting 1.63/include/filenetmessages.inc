#if defined _filenetmessages_included
	#endinput
#endif

#define _filenetmessages_included



/*
 * The natives work quite pretty.
 * But the forwards are really tricky, no idea when they really fire. 
 */


/**
 * Called when a file was received from a client to the server.
 * Was fired when requesting a file and it doesn't exist and was succesfulled downloaded.
 *
 * @param client          Client index.
 * @param file            File that was received.
 * @param transferID      transfer ID.
 */
forward FNM_OnFileReceived(client, const String:file[], transferID);

/**
 * Called when a client requests a file from the server.
 *
 * @param client          Client index.
 * @param file            File that was requested.
 * @param transferID      transfer ID.
 *
 * @return                Plugin_Stop to deny the request, Plugin_Continue otherwise.
 */
forward Action:FNM_OnFileRequested(client, const String:file[], transferID);

/**
 * Called when a client denies a file request from the server.
 * Was fired when requesting a file, but filed doesn't exist.
 *
 * @param client          Client index.
 * @param file            File that was denied.
 * @param transferID      transfer ID.
 */
forward FNM_OnFileDenied(client, const String:file[], transferID);

/**
 * Called when a file was sent to a client.
 * Was never fired :/
 *
 * @param client          Client index.
 * @param file            File that was sent.
 * @param transferID      transfer ID.
 */
forward FNM_OnFileSent(client, const String:file[], transferID);




/**
 * Sends a file to a client
 *
 * @param client          Client to send file.
 * @param file            File to send.
 * @param ...             Variable number of format parameters.
 *
 * @return                TransferID on success, otherwise 0.
 */
native FNM_SendFile(client, const String:file[], any:...);



/**
 * Requests a file from a client
 *
 * @param client          Client to get file from.
 * @param file            File to request.
 * @param ...             Variable number of format parameters.
 *
 * @return                TransferID of the request.
 */
native FNM_RequestFile(client, const String:file[], any:...);







/** Do Not Edit Below This Line **/
public Extension:__ext_filenetmessages =
{
	name = "filenetmessages",
	file = "filenetmessages.ext",

	#if defined AUTOLOAD_EXTENSIONS
		autoload = 1,
	#else
		autoload = 0,
	#endif

	#if defined REQUIRE_EXTENSIONS
		required = 1,
	#else
		required = 0,
	#endif
};

#if !defined REQUIRE_EXTENSIONS
	public __ext_filenetmessages_SetNTVOptional()
	{
		MarkNativeAsOptional("FNM_SendFile");
		MarkNativeAsOptional("FNM_RequestFile");
	}
#endif
