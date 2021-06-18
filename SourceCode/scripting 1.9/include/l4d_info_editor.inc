#if defined _info_editor_included
  #endinput
#endif
#define _info_editor_included



/**
 * Retrieves the value of a specified key from the games mission info keyvalue system. "N/A" is returned when not found.
 *
 * @param pThis			Enter the pThis value from OnGetMissionInfo/OnGetWeaponsInfo. Can specify 0 when reading Mission data.
 * @param keyname		Key name to check.
 * @param dest			Destination string buffer to copy to.
 * @param destLen		Destination buffer length (includes null terminator).
 *
 * @noreturn
 */
native void InfoEditor_GetString(int pThis, const char[] keyname, char[] dest, int destLen);

/**
 * Sets the value of a specified key from the games mission info keyvalue system.
 *
 * @param pThis			Enter the pThis value from OnGetMissionInfo/OnGetWeaponsInfo. Can specify 0 when writing Mission data.
 * @param keyname		Key name to set.
 * @param value			Value to set.
 * @param create		Optionally create the keyvalue if it doesn't exist.
 *
 * @noreturn
 */
native void InfoEditor_SetString(int pThis, const char[] keyname, const char[] value, bool create = false);

/**
 * Reloads the mission and weapons data configs and forces the game to reload them.
 *
 * @noreturn
 */
native void InfoEditor_ReloadData();



/**
 * @brief Fired multiple times when the mission info data is parsed.
 *
 * @param pThis			This pointer used for InfoEditor_GetString/InfoEditor_SetString.
 */
forward void OnGetMissionInfo(int pThis);

/**
 * Fired multiple times when the weapon info data is parsed for a specific weapon classname.
 *
 * @param pThis			This pointer used for InfoEditor_GetString/InfoEditor_SetString.
 * @param classname		Classname of the weapon being parsed.
 */
forward void OnGetWeaponsInfo(int pThis, const char[] classname);