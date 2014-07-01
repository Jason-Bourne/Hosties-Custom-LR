#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <hosties>
#include <lastrequest>

#define START_HP 100
#define SERVER 0
#define PRISONER 0
#define GUARD 1

new g_LREntryNum;
new LR_Player_Guard;
new LR_Player_Prisoner;
new String:g_sLR_Name[64];
new bool:IsThisLRInProgress = false;
new g_iHealth;
new dmg[2];
new g_Sprite;
new colours[7][4] =
{
    {255, 0, 0, 255},
    {255, 127, 0, 255},
    {255, 255, 0, 255},
    {0, 255, 0, 255},
    {0, 0, 255, 255},
    {75, 0, 130, 255},
    {143, 0, 255, 255}
};
new Handle:SpriteTimer;
new Float:BeamCenter[3];

public Plugin:myinfo =
{
    name = "Last Request: Max Damage",
    author = "Jason Bourne & Kolapsicle",
    description = "",
    version = "1.0.0",
    url = ""
};

public OnPluginStart()
{
    LoadTranslations("maxdmg.phrases");

    Format(g_sLR_Name, sizeof(g_sLR_Name), "%T", "LR Name", LANG_SERVER);

    HookEvent("player_hurt", EventPlayerHurt, EventHookMode_Pre);

    g_iHealth = FindSendPropOffs("CCSPlayer", "m_iHealth");
    if (g_iHealth == -1)
    {
        SetFailState("Error - Unable to get offset for CSSPlayer::m_iHealth");
    }
}

public OnConfigsExecuted()
{
    static bool:bAddedCustomLR = false;
    if ( ! bAddedCustomLR)
    {
        g_LREntryNum = AddLastRequestToList(LR_Start, LR_Stop, g_sLR_Name);
        bAddedCustomLR = true;
    }
}

public OnPluginEnd()
{
    RemoveLastRequestFromList(LR_Start, LR_Stop, g_sLR_Name);
}

public OnMapStart()
{
    g_Sprite = PrecacheModel("materials/sprites/laser.vmt");
}

public LR_Start(Handle:LR_Array, iIndexInArray)
{
    new This_LR_Type = GetArrayCell(LR_Array, iIndexInArray, _:Block_LRType);
    if (This_LR_Type == g_LREntryNum)
    {
        LR_Player_Prisoner = GetArrayCell(LR_Array, iIndexInArray, _:Block_Prisoner);
        LR_Player_Guard = GetArrayCell(LR_Array, iIndexInArray, _:Block_Guard);

        // check datapack value
        new LR_Pack_Value = GetArrayCell(LR_Array, iIndexInArray, _:Block_Global1);
        switch (LR_Pack_Value)
        {
            case -1:
            {
                PrintToServer("no info included");
            }
        }

        SetEntityHealth(LR_Player_Prisoner, START_HP);
        SetEntityHealth(LR_Player_Guard, START_HP);

        StripAllWeapons(LR_Player_Prisoner);
        StripAllWeapons(LR_Player_Guard);

        dmg[PRISONER] = 0;
        dmg[GUARD] = 0;

        IsThisLRInProgress = true;

        CreateTimer(60.0, Timer_LR);

        PrintToChatAll(CHAT_BANNER, "LR Start", LR_Player_Prisoner, LR_Player_Guard);
        PrintToChatAll(CHAT_BANNER, "LR Explain");
    }
}

public Action:Timer_LR(Handle:timer)
{
    IsThisLRInProgress = false;
    new loser, winner;
    if (dmg[PRISONER] == dmg[GUARD])
    {
        PrintToChatAll(CHAT_BANNER, "LR No Winner", dmg[GUARD]);
        ServerCommand("sm_cancellr");
    } else {
        if (dmg[PRISONER] > dmg[GUARD]) {
            winner = LR_Player_Prisoner;
            loser = LR_Player_Guard;
        } else if(dmg[GUARD] > dmg[PRISONER]) {
            winner = LR_Player_Guard;
            loser = LR_Player_Prisoner;
        }
        SetEntityMoveType(loser, MOVETYPE_NONE);
        StripAllWeapons(loser);
        GetClientAbsOrigin(winner, BeamCenter);
        TeleportEntity(loser, BeamCenter, NULL_VECTOR, NULL_VECTOR);
        SetEntityHealth(winner, 100);
        SetEntityHealth(loser, 1);
        CreateTimer(0.1, Timer_CreateSprite);
        SpriteTimer = CreateTimer(3.0, Timer_CreateSprite, _, TIMER_REPEAT);
        GivePlayerItem(winner, "weapon_knife");
        PrintToChatAll(CHAT_BANNER, "LR Winner", winner);
    }

    return Plugin_Continue;
}
public Action:Timer_CreateSprite(Handle:timer)
{
    for (new i = 0; i < 7; i++)
    {
        BeamCenter[2] += 10;
        TE_SetupBeamRingPoint(BeamCenter, 100.1, 100.0, g_Sprite, 0, 0, 25, 3.0, 7.0, 0.0, colours[i], 1, 0);
        TE_SendToAll();
    }
    BeamCenter[2] -= 70;
}

public LR_Stop(This_LR_Type, Player_Prisoner, Player_Guard)
{
    if (SpriteTimer != INVALID_HANDLE)
    {
        KillTimer(SpriteTimer);
        SpriteTimer = INVALID_HANDLE;
    }
}

public Action:EventPlayerHurt(Handle:event, const String:name[],bool:dontBroadcast)
{
    new victim = GetClientOfUserId(GetEventInt(event, "userid"));
    new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
    new dhealth = GetEventInt(event, "dmg_health");
    new health = GetEventInt(event, "health");

    if (IsThisLRInProgress && IsClientInLastRequest(victim))
    {
        decl String:wname[64];
        GetEventString(event, "weapon", wname, sizeof(wname));

        if (victim == LR_Player_Guard && (attacker == LR_Player_Guard || attacker == SERVER))
        {
            dmg[GUARD] += dhealth;
        }
        if (victim == LR_Player_Prisoner && (attacker == LR_Player_Prisoner || attacker == SERVER))
        {
            dmg[PRISONER] += dhealth;
        }

        SetEntData(victim, g_iHealth, (health + dhealth), 4, true);
    }

    return Plugin_Continue;
}
