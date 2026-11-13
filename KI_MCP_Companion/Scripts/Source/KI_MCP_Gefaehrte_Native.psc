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

; The three functions below exist in this form from interface version 5 on. Versions 3 and 4 had them without
; "origin" and without the ref IDs of places and quest targets, so this script does not fit an older DLL.
; origin is the character from whom everything is seen ("the viewer"): distances, angles, and what counts as
; "this area". None, or a character that is not in the loaded area, means the player

; Where the targets of the tracked quests are (what the compass of the game points to), at most maxTargets.
; One text per target, its parts separated by tabs:
; place of the quest in the list GetOpenQuests(maxQuests) returns (from 0), place of the objective in that quest (from 0),
; where the target is (0 = in the area of the viewer, 1 = behind a door of this area, 2 = somewhere else),
; distance to the viewer in meters, angle from where the viewer faces in degrees (negative = left)
; - for 1 these are the distance and angle of that door, for 2 both are 0 -,
; name of the target (can be empty), for 1 and 2 the name of the place behind the door or of the place the target is in,
; and the ref ID to walk to as eight hex digits: the target for 0, that door for 1, 00000000 for 2
string[] Function GetQuestTargets(int maxQuests, int maxTargets, Actor origin) global native

; The places around the viewer, map markers first, then doors, each nearest first: at most maxMarkers map markers
; within radiusMeters (none indoors), and at most maxDoors doors in the loaded area within radiusMeters that lead
; into another area (a building, a cave, out of town). 0 switches that kind off. One text per place, its parts separated by tabs:
; kind (0 = map marker, 1 = door), ref ID of the marker or the door as eight hex digits,
; distance to the viewer in meters, angle from where the viewer faces in degrees
; (negative = left), for a map marker the kind of place as the game numbers it (13 = farm, 21 = stable ...),
; for a map marker 1 if the player has been there, name of the place (for a door: of the place it leads to)
string[] Function GetNearbyPlaces(int radiusMeters, int maxMarkers, int maxDoors, Actor origin) global native

; The things close to the viewer: furniture first, then containers, then items that lie around, each nearest first,
; at most maxPerKind of each kind within radiusMeters. Things without a name are left out.
; One text per thing, its parts separated by tabs: kind (0 = furniture, 1 = container, 2 = item),
; ref ID as eight hex digits, distance to the viewer in meters, angle from where the viewer faces in degrees
; (negative = left), for furniture 1 if a character can sit on it, for a container 1 if it is locked, name
string[] Function GetNearbyThings(int radiusMeters, int maxPerKind, Actor origin) global native

; The function below exists from interface version 6 on

; The name of the voice of a character as the files of the game know it: the editor ID of its voice type
; (eg FemaleEvenToned). The game looks for the sound of what a character says in a folder of that name.
; Empty if the character has no voice
string Function GetVoiceTypeName(Actor target) global native

; The three functions below exist from interface version 7 on

; The door on the other side of a door that leads into another area (a building, a cave, out of town),
; or None if this is no such door
ObjectReference Function GetDoorDestination(ObjectReference doorRef) global native

; Where someone stands after going through such a door, measured from the door on the other side (GetDoorDestination):
; how far to the east, to the north and upwards in game units, and the direction faced in degrees (0 = north, 90 = east).
; Empty if this is no such door
float[] Function GetDoorArrival(ObjectReference doorRef) global native

; The characters in the building the character "origin" is in while the player is somewhere else, nearest first,
; at most maxCharacters. The game has not loaded such a building, so these are only the ones it keeps in memory:
; as a rule the named characters who live there, not bandits and animals. One text per character, its parts separated
; by tabs: ref ID as eight hex digits, distance to origin in meters, angle from where origin faces in degrees
; (negative = left), dead (1 or 0), name. Empty if origin is not in such a place.
; In the same situation GetQuestTargets, GetNearbyPlaces and GetNearbyThings also work with what the game keeps in memory
string[] Function GetCharactersInCell(Actor origin, int maxCharacters) global native

; The five functions below exist from interface version 9 on

; The traps close to the character "origin" (None or far away outdoors = the player), nearest first, at most maxTraps
; within radiusMeters. One text per trap, built like the lines of GetNearbyThings: kind (always 3), ref ID,
; distance in meters, angle in degrees (negative = left), 0, and the kind of trap as the game files its model
; (tripwire, pressureplate, beartrap, macetrap ...). Every part of a trap is a line of its own
string[] Function GetNearbyTraps(int radiusMeters, int maxTraps, Actor origin) global native

; An arrow that was shot stays in the world as a projectile, which is no item for the game: scripts cannot take it.
; GetNearbyThings lists such arrows among the items. This tells whether the reference with this ID (in its upper
; and lower 16 bits, as the server sends IDs) is one: the name of its ammunition, or an empty text
string Function GetRestingArrowName(int highHalf, int lowHalf) global native

; Gives the taker the ammunition of such an arrow and takes the arrow out of the world. Returns the name of the
; ammunition, or an empty text if the arrow is not there (any more)
string Function TakeRestingArrow(Actor taker, int highHalf, int lowHalf) global native

; say: tells what the speaker really says with its next line. The subtitle of the line of this mod then shows that
; instead of "...". Returns whether the plugin can change subtitles at all (it has to listen to them for that, see IsHearing)
bool Function SetSayText(Actor speaker, string text) global native

; What is around the character within rangeMeters, found by rays: eight directions, the first straight ahead of
; the character and the others clockwise from there, three numbers each: what the ray met (0 = nothing,
; 1 = a wall or another upright obstacle, 2 = ground that rises), how far away in meters (0 if nothing), and after
; how many meters the ground drops away (-1 = it does not). Empty if the game cannot tell
int[] Function GetSurroundings(Actor origin, int rangeMeters) global native

; The function below exists from interface version 10 on

; What in the loaded area around the character "origin" (None or far away outdoors = the player) has a name that holds
; every word of the text, nearest first, at most maxResults. Capitals do not matter. One text per match, built like the
; lines of GetNearbyThings: kind (0 = a character, 1 = a door, 2 = a map marker, 3 = a thing), ref ID, distance in meters,
; angle in degrees (negative = left), for a character 1 if it is dead (0 otherwise), name (for a door: of the place it leads to)
string[] Function FindByName(string text, int maxResults, Actor origin) global native
