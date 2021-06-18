#include <sourcemod>
#include <smac_wallhack>

public OnPluginStart()
{
    RegAdminCmd("sm_wallhack_ignore", Command_WallhackIgnore, ADMFLAG_GENERIC, "sm_wallhack_ignore <player> <0/1> - toggles whether player(s) undergo visibility tests.");
}

public Action:Command_WallhackIgnore(client, args)
{   
    if (args < 2)
    {
        ReplyToCommand(client, "[SM] Usage: sm_wallhack_ignore <player> <0/1>");
        return Plugin_Handled;
    }

    decl String:sBuffer[64];

    GetCmdArg(2, sBuffer, sizeof(sBuffer));
    new bool:bIgnore = bool:StringToInt(sBuffer);

    GetCmdArg(1, sBuffer, sizeof(sBuffer));

    decl String:target_name[MAX_TARGET_LENGTH];
    decl target_list[MAXPLAYERS], target_count, bool:tn_is_ml;

    if ((target_count = ProcessTargetString(
            sBuffer,
            client, 
            target_list, 
            MAXPLAYERS, 
            0,
            target_name,
            sizeof(target_name),
            tn_is_ml)) <= 0)
    {
        ReplyToTargetError(client, target_count);
        return Plugin_Handled;
    }

    for (new i = 0; i < target_count; i++)
    {
        new target = target_list[i];

        if (!IsClientInGame(target))
            continue;

        SMAC_WH_SetClientIgnore(target, bIgnore);
        ReplyToCommand(client, "%N is now being %s.", target, SMAC_WH_GetClientIgnore(target) ? "ignored" : "not ignored");
    }

    return Plugin_Handled;
}