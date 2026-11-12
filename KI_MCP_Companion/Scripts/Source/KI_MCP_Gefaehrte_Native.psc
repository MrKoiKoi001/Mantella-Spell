Scriptname KI_MCP_Gefaehrte_Native Hidden
{Functions of KI_MCP_Gefaehrte.dll, the SKSE plugin of this mod. It reads what scripts cannot get at.
Its source is in its own repository (the fork of mantella-vanilla-dialogue, file plugin.cpp).
Without the DLL these functions do not exist. So ask SKSE.GetPluginVersion("KI_MCP_Gefaehrte") first,
as KI_MCP_Gefaehrte_Loop does.}

; Goes up whenever the functions below change
int Function GetInterfaceVersion() global native

; The open quests of the journal, tracked ones first, at most maxQuests of them. One text per quest, its parts separated by tabs:
; tracked (1 or 0), type of the quest as the game numbers it (6 = miscellaneous), name of the quest,
; then the text of each objective that is shown and not done
string[] Function GetOpenQuests(int maxQuests) global native

; The two functions below exist from interface version 2 on

; Whether the plugin could hook into the subtitles of the game. If not, there is nothing to fetch
bool Function IsHearing() global native

; What the characters around the player said since the last call (the subtitles of the game), oldest first,
; at most maxLines (then the newest ones). One text per line, its parts separated by tabs:
; how many seconds ago, ref ID of the speaker as eight hex digits, name of the speaker, what was said.
; A line the player picked in a dialogue menu has the player as its speaker
string[] Function TakeHeardLines(int maxLines) global native
