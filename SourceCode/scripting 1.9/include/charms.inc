#if defined _charms_included
	#endinput
#endif
#define _charms_included



public SharedPlugin __pl_charms = 
{
	name = "charms",
	file = "charms.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};



/**
 * Creates a charm on the specified client.
 *
 * @param client			Client index.
 * @param index				Charm index, or 0 to attempt using the clients current charm index if available.
 *
 * @noreturn
 */
native void Charms_Create(int client, int index = 0);

/**
 * Removes any charm from the specified client
 *
 * @param client			Client index.
 *
 * @noreturn
 */
native void Charms_Delete(int client);

/**
 * Returns the clients current charm index. The charm might not be invalid and the index for another weapon they were holding.
 *
 * @param client			Client index.
 *
 * @return					Charm index.
 */
native int Charms_GetIndex(int client);

/**
 * Checks if the client has a charm attached.
 *
 * @param client			Client index.
 *
 * @return					True if the client has a charm equipped
 */
native bool Native_GetValid(int client);