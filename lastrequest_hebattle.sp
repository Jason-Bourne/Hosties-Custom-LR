#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <hosties>
#include <lastrequest>

#define START_HP 250

new g_LREntryNum;
new LR_Player_Guard;
new LR_Player_Prisoner;
new String:g_sLR_Name[64];
new bool:IsThisLRInProgress = false;
new g_iHealth;

public Plugin:myinfo =
{
    name = "Last Request: HE Battle",
    author = "Jason Bourne & Kolapsicle",
    description = "",
    version = "1.0.0",
    url = ""
};

public OnPluginStart()
{
    Format(g_sLR_Name, sizeof(g_sLR_Name), "HE Battle");

    HookEvent("player_hurt", EventPlayerHurt, EventHookMode_Pre);
    HookEvent("hegrenade_detonate", GrenadeDetonate);

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

        GivePlayerItem(LR_Player_Prisoner, "weapon_hegrenade");
        GivePlayerItem(LR_Player_Guard, "weapon_hegrenade");

        IsThisLRInProgress = true;

        PrintToChatAll("%N has challenged %N to a HE Battle", LR_Player_Prisoner, LR_Player_Guard);
    }
}

public LR_Stop(This_LR_Type, Player_Prisoner, Player_Guard)
{
    if (IsThisLRInProgress && This_LR_Type == g_LREntryNum)
    {
        LR_Player_Prisoner = Player_Prisoner;
        LR_Player_Guard = Player_Guard;

        if (IsPlayerAlive(LR_Player_Prisoner) && IsPlayerAlive(LR_Player_Guard))
        {
            SetEntityHealth(LR_Player_Prisoner, 100);
            GivePlayerItem(LR_Player_Prisoner, "weapon_knife");
            SetEntityHealth(LR_Player_Guard, 100);
            GivePlayerItem(LR_Player_Guard, "weapon_knife");
            PrintToChatAll("HE Battle Last Request was aborted :(", LR_Player_Prisoner);
        } else if (IsPlayerAlive(LR_Player_Prisoner)) {
            SetEntityHealth(LR_Player_Prisoner, 100);
            GivePlayerItem(LR_Player_Prisoner, "weapon_knife");
            PrintToChatAll("%N is the winner of HE Battle", LR_Player_Prisoner);
        } else if (IsPlayerAlive(LR_Player_Guard)) {
            SetEntityHealth(LR_Player_Guard, 100);
            GivePlayerItem(LR_Player_Guard, "weapon_knife");
            PrintToChatAll("%N is the winner of HE Battle", LR_Player_Guard);
        }
    }

    IsThisLRInProgress = false;
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

        if (victim == LR_Player_Guard || victim == LR_Player_Prisoner)
        {
            if ( ! StrEqual(wname, "hegrenade", false) || (attacker != LR_Player_Prisoner && attacker != LR_Player_Guard))
            {
                SetEntData(victim, g_iHealth, (health + dhealth), 4, true);
            }
        }
    }
    return Plugin_Continue;
}

public Action:GrenadeDetonate(Handle:event, const String:name[], bool:dontBroadcast)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));

    if(StrEqual(name, "hegrenade_detonate"))
    {
        if (IsThisLRInProgress && (client == LR_Player_Guard || client == LR_Player_Prisoner))
        {
            GivePlayerItem(client, "weapon_hegrenade");
        }
    }
    return Plugin_Handled;
}
