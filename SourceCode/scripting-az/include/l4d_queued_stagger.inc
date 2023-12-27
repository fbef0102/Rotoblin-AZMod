#if defined _l4d_queued_stagger_included
 #endinput
#endif
#define _l4d_queued_stagger_included

/**
 * @brief Called whenever a Special Infected has landed and about to start staggering.
 * 
 * @param client		the client that is about to get staggered
 * 
 * @return				Plugin_Handled to block, Plugin_Continue otherwise
 */
forward Action L4D_OnQueuedStagger(int client);

/**
 * @brief Called whenever a Special Infected has landed and about to start staggering.
 * @remarks This forward will not trigger if the relative pre-hook forward has been blocked with Plugin_Handled
 * 
 * @param client		the client that got staggered
 * 
 * @noreturn
 */
forward void L4D_OnQueuedStagger_Post(int client);

/**
 * @brief Called whenever a Special Infected has landed and about to start staggering.
 * @remarks This forward will ONLY trigger if the relative pre-hook forward has been blocked with Plugin_Handled
 * 
 * @param client		the client that should've been staggered
 * 
 * @noreturn
 */
forward void L4D_OnQueuedStagger_PostHandled(int client);

public SharedPlugin __pl_l4d_queued_stagger =
{
	name = "l4d_queued_stagger",
	file = "l4d_queued_stagger.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};