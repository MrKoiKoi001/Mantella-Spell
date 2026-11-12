Scriptname KI_MCP_Gefaehrte_PlayerAlias extends ReferenceAlias
{Sits on the player alias of the quest, because only the player is told when a save was loaded}

Event OnPlayerLoadGame()
    (GetOwningQuest() as KI_MCP_Gefaehrte_Loop).OnGameLoaded()
EndEvent
