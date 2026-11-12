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

; The two functions below exist from interface version 3 on

; Where the targets of the tracked quests are (what the compass of the game points to), at most maxTargets.
; One text per target, its parts separated by tabs:
; place of the quest in the list GetOpenQuests(maxQuests) returns (from 0), place of the objective in that quest (from 0),
; where the target is (0 = in the area of the player, 1 = behind a door of this area, 2 = somewhere else),
; distance to the player in meters, angle from where the player faces in degrees (negative = left)
; - for 1 these are the distance and angle of that door, for 2 both are 0 -,
; name of the target (can be empty), and for 1 and 2 the name of the place behind the door or of the place the target is in
string[] Function GetQuestTargets(int maxQuests, int maxTargets) global native

; The places around the player, map markers first, then doors, each nearest first: at most maxMarkers map markers
; within radiusMeters (none indoors), and at most maxDoors doors in the loaded area within radiusMeters that lead
; into another area (a building, a cave, out of town). 0 switches that kind off. One text per place, its parts separated by tabs:
; kind (0 = map marker, 1 = door), distance to the player in meters, angle from where the player faces in degrees
; (negative = left), for a map marker the kind of place as the game numbers it (13 = farm, 21 = stable ...),
; for a map marker 1 if the player has been there, name of the place (for a door: of the place it leads to)
string[] Function GetNearbyPlaces(int radiusMeters, int maxMarkers, int maxDoors) global native
