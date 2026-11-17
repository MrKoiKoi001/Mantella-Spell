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

; The function below exists from interface version 11 on

; The characters in the loaded area around the character "origin" (None or far away outdoors = the player) within
; radiusMeters, at most maxCharacters: first the living that are hostile to the player, then the other living, then
; the dead, each nearest first. People and animals alike, without the player and without origin.
; For "Nearby" outdoors, where a script only reaches the characters of the one cell it stands in
Actor[] Function GetCharactersAround(Actor origin, int radiusMeters, int maxCharacters) global native

; The function below exists from interface version 12 on

; Mute: from now on the sentences the game lets this character say on its own (idle talk, taunts in a fight,
; greetings) are cut off as they begin, and their subtitles are not shown. None = nobody is muted any more.
; Grunts and cries stay, so do the lines of this mod (say) and what the character answers in the dialogue menu.
; Returns whether the plugin can do that at all (it has to listen to the subtitles for it, see IsHearing)
bool Function SetMutedSpeaker(Actor speaker) global native

; The two functions below exist from interface version 13 on

; Like GetSurroundings, but looking into one direction: the rays fan out over angleDegrees around headingDegrees
; (a point of the compass in degrees, 0 = north, 90 = east), from the left edge of that angle to the right one, with the
; middle ray straight into the direction. Always an odd number of rays, about 15 degrees apart, at least 3 and at most 9.
; An angle of 0 is one single ray. A full circle (360) is eight rays, the first into the direction and the others
; clockwise from there. rangeMeters: 0 = 15, at most 200 (the game only has the physics of the area it has loaded
; around the player, outdoors about 120 meters, and a ray finds nothing beyond that). Three numbers per ray, as
; GetSurroundings gives them. Empty if the game cannot tell
int[] Function GetSurroundingsToward(Actor origin, int rangeMeters, int headingDegrees, int angleDegrees) global native

; How high the ground is at the spot x, y (game units) close to the character "origin", found by a ray downwards:
; the height to put something at that a character is to walk to. -1000000 if the ray finds no ground there
float Function GetGroundHeight(Actor origin, float x, float y) global native

; The function below exists from interface version 14 on

; The horse (or other mount) a character sits on, or None if it rides nothing
Actor Function GetMount(Actor rider) global native

; The function below exists from interface version 15 on

; Like GetNearbyPlaces, but only the places the viewer can see: within halfAngleDegrees to the left and right of where
; it faces, and with no wall between its eyes and the place. The game itself can only tell what a character sees
; for other characters, not for doors
string[] Function GetVisiblePlaces(int radiusMeters, int maxMarkers, int maxDoors, Actor origin, int halfAngleDegrees) global native

; The function below exists from interface version 16 on. From that version on GetNearbyThings also tells with a
; container how many items it holds: its flag is 1 if it is locked, otherwise 2 x (that number + 1)

; How many different items a dead character carries or a container holds that can be taken (-1 = cannot tell)
int Function GetLootCount(ObjectReference holder) global native

; The five functions below exist from interface version 17 on

; The plugin keeps what happens around the player and the companion as short texts with the time it happened: fights,
; deaths, the hits the player and the companion take (counted together, with the health they cost), where the player
; goes, what the player uses, reads, takes, puts on and casts, and whom the player talks to. The companion is "you"
; in these texts. Call this about once a second with the companion of the moment (None = there is none): it tells
; the plugin who the companion is, keeps what has no event of the game (the player begins or stops sneaking or
; fighting) and ends what is counted together
Function TickEvents(Actor companion) global native

; What happened since the last call, oldest first, at most maxLines (then the newest ones). One text per event, its
; parts separated by tabs: how many seconds ago, the time of day in the game in minutes since midnight,
; urgent (1 or 0), what happened. The plugin forgets an event once it has handed it out
string[] Function TakeEvents(int maxLines) global native

; Only the urgent events since the last call (a fight begins, someone dies or goes down, someone is left with little
; health), built like the lines of TakeEvents. They are forgotten as well, the others stay for TakeEvents
string[] Function TakeUrgentEvents() global native

; While this is set, things that change hands between the player and the companion are no event: the script moves
; them itself then (give, take), and the AI knows about it
Function SkipTransferEvents(bool isSkipping) global native

; The text of a book or a note, one page of it (from 1; too high = the last one). book is the book itself or a book
; that lies in the world. The first text tells about the book, its parts separated by tabs: the number of this page,
; how many pages there are (0 = the book has no text), the kind (0 = book, 1 = note, 2 = spell tome), the form ID of
; the book as eight hex digits, its title. Then one text per piece of the page: how it joins what came before
; (1 = it begins a paragraph, 0 = it goes on after a blank, 2 = it goes on right away), a tab, the text.
; Empty if this is no book. Reading it this way does nothing in the game: no skill goes up and no quest starts
string[] Function GetBookText(Form book, int page) global native

; The six functions below exist from interface version 18 on

; Forces a character that is not the player to enter (true) or to leave (false) the sneaking state and to stay that
; way: what the console command SetForceSneak of the game does. The game makes a follower sneak exactly when the
; player sneaks, and a script that switches the sneaking of such a character is overruled within a moment.
; Returns whether the command could be handed to the game; it runs a moment later
bool Function SetForceSneak(Actor target, bool shouldSneak) global native

; Casting by hand: lets a character cast the spell it holds in its right hand the way the game itself does it, with
; the movement of the hand, out of the hand, and paid for with magicka (a spell cast with Spell.Cast has no movement
; and comes out of the head). aimTarget is what the spell is aimed at (None = nothing in particular). The spell has
; to be in the right hand and the hands have to be raised. Returns whether it could be handed to the game; the cast
; begins a moment later (see GetHandCastState)
bool Function StartHandCast(Actor caster, ObjectReference aimTarget) global native

; Lets go of the spell: one that was charged flies off, one that is held (flames) stops
bool Function EndHandCast(Actor caster) global native

; How far the right hand of a character is with casting, as the game numbers it (0 = it does nothing, 5 = it charges
; the spell, 6 = it casts). -1 = cannot tell
int Function GetHandCastState(Actor caster) global native

; An inventory in one go. filter: 0 = everything, 1 = only the favorites, 2 = only what is worn and held. The
; favorites of the player are what the game has among its favorites; for everybody else they are the items in
; "marked". The first text is how many kinds of items passed the filter, then one text per item, at most maxItems,
; its parts separated by tabs: form ID as eight hex digits, how many, form type as SKSE numbers it,
; flags (1 = worn or held, plus 2 = favorite, plus 16 times the kind of weapon or armor, see ItemKindStep), name
string[] Function GetInventoryLines(ObjectReference owner, int filter, int maxItems, Form[] marked) global native

; The function below exists from interface version 19 on

; Whom a character looks at while it speaks. The game keeps several things a character can look at, and the one of
; a dialogue comes before the one a script sets with Actor.SetLookAt. A line spoken with Actor.Say makes the game put
; the player there. This puts lookTarget there instead (None = nobody: what the script set counts again).
; Returns whether it could be handed to the game; it happens a moment later
bool Function SetTalkTarget(Actor speaker, ObjectReference lookTarget) global native

; The functions below exist from interface version 20 on. From that version on TickEvents also keeps quests that
; begin, go on and end, and the hostile characters and traps the companion spots, among the events

; The spells a character knows that give health back, strongest first. forOther: those that work on somebody else
; (Healing Hands), otherwise those that work on the caster itself (Healing)
Spell[] Function GetHealSpells(Actor caster, bool forOther) global native

; The chest a merchant sells from and pays out of, or None if the character is no merchant
ObjectReference Function GetMerchantChest(Actor merchant) global native

; What a merchant offers and what the buyer could sell to it. The first text, its parts separated by tabs: ref ID of
; the merchant as eight hex digits, status (0 = trades, 1 = no merchant, 2 = does not trade at this hour), gold of
; the merchant, gold of the buyer, the hours it trades from and to, how many kinds of wares it has, how many kinds
; of things the buyer could sell, name. Then one text per thing, at most maxItems per side: side (0 = the merchant
; sells it, 1 = the buyer could sell it), form ID as eight hex digits, how many, form type as SKSE numbers it,
; price of one piece, name
string[] Function GetMerchantLines(Actor merchant, Actor buyer, int maxItems) global native

; One thing the buyer wants to buy from a merchant (isBuying) or sell to it. Four numbers: status (0 = fine,
; 1 = no merchant, 2 = does not trade at this hour, 3 = the merchant does not deal in this kind of thing,
; 4 = none there, 5 = it is worth nothing), price of one piece, how many there are (with the merchant when buying,
; with the buyer when selling), and the gold of the one who pays
int[] Function GetTradeOffer(Actor merchant, Actor buyer, Form item, bool isBuying) global native

; The functions below exist from interface version 21 on. They answer in one go what the script asked the game
; one by one: a script waits for the next picture of the game with nearly every question

; The plain facts about a character. viewer: from whom the distance and the direction count (None = both stay 0).
; The numbers: ref ID, dead, in a fight, position x, y, z, the direction it faces in degrees, weapon drawn, sneaking,
; in the loaded area, distance to the viewer in meters, angle from where the viewer faces in degrees (negative =
; left), ref ID of whom it fights (0 = nobody), told to wait by the player, and from interface version 23 on:
; rides, sits on something (seated or about to get up; a rider counts as seated too)
int[] Function GetActorNumbers(Actor character, Actor viewer) global native

; The characters around the viewer, living and dead, without the player and the companion, at most maxCharacters
; within radiusMeters: whom the companion fights first, then the hostile ones, the other living ones and the dead,
; each nearest first. Five numbers per character: ref ID, distance to the viewer in meters, angle from where the
; viewer faces in degrees (negative = left), hostile to the player (for the dead: how many different items they
; carry, plus 1), dead. A single -1 means: the plugin cannot look around in this game
int[] Function GetNearbyValues(Actor viewer, Actor companion, int radiusMeters, int maxCharacters) global native

; The names of the characters GetNearbyValues listed last: the place in that list, a colon and the name
string[] Function GetNearbyNames() global native

; The function below exists from interface version 22 on

; Why a character or a thing is not really there, as the end of a sentence ("is hidden: the game does not draw it"),
; or "" if it is there. The game keeps characters it does not show: disabled ones, ones without a body, hidden ones,
; ones in another place than the viewer. For a thing only "disabled" and "being deleted" count. What the plugin
; found also goes into its log file
string Function GetAbsenceReason(ObjectReference target, Actor viewer) global native

; The four functions below exist from interface version 23 on

; Which menus were opened and closed again since the last call, oldest first: the name the game gives the menu, a tab
; and how long it was open in milliseconds. What the game shows all the time (the HUD, the cursor) is left out.
; The plugin forgets them once it has handed them out
string[] Function TakeMenuLines() global native

; What a character holds: always two texts, "R:" and "L:" followed by the name of what is in that hand (nothing =
; empty hand). A shield counts as the left hand. A weapon for both hands is only named for the right hand
string[] Function GetHandNames(Actor holder) global native

; The loose things a companion may collect within radiusMeters around the center (None = around the companion), the
; ones nearest to the companion first, at most maxItems. filterName: "" for everything, "no_clutter" for everything
; but plates, tankards and the like, or one kind: potions, food, ingredients, weapons, armor, ammo, books, scrolls,
; keys, gold, misc. Left out: what belongs to someone, what has no name, lights that cannot be carried, arrows that
; were shot, and what lies on another floor
ObjectReference[] Function FindLooseItems(Actor companion, ObjectReference center, int radiusMeters, string filterName, int maxItems) global native

; What the last FindLooseItems left out: how many things that belong to someone (-1 = it could not look at all), and
; how many more it found than it was allowed to return
int[] Function GetLooseItemNumbers() global native

; The two functions below exist from interface version 24 on

; What goes along with every state, collected in one go, because a script waits for the next picture of the game with
; nearly every question it asks. Returns a list of numbers: first a few for the script (see StateHead... in
; KI_MCP_Gefaehrte_Loop.psc), then one block per list of the state: which list, how many numbers, the numbers
; (the two times, player, world, companion, gold, the horses, the characters around). The texts that belong to it
; come from GetWholeStateTexts. The companion server unpacks both (expand_quick_state in game_state.py).
; viewer: from whom the lists are seen. ownForms and options: what only the script knows, at the places
; StateForm... and StateOption... name. namedHorses and horseNames: the horses the script gave a name, and the names.
; An empty list means: the plugin cannot build this state, and it has not touched anything.
; From interface version 25 on: with 'visible' in the options (the companion as the viewer) the characters are only
; those the viewer sees, has close by or hears, and a further block tells for each of them which it is (1 = seen,
; 2 = close by, 3 = heard). The second of the two times is how long the plugin took, in tenths of a millisecond
int[] Function GetWholeState(Actor player, Actor companion, Actor viewer, Form[] ownForms, int[] options, Form[] namedHorses, string[] horseNames) global native

; The texts that belong to the numbers GetWholeState returned last: the name of the entry of the state, a tab, the
; text. A list of texts (quests, places, what was heard ...) has one line per text
string[] Function GetWholeStateTexts() global native

; The three functions below exist from interface version 27 on

; cover: starts a search for a spot within radiusMeters around the companion that none of its enemies can see, on
; ground a character can walk on (the navmesh of the game), at least enemyMeters away from every enemy. mustMove: the
; spot the companion stands on does not count. The search runs a moment later on the main thread of the game, and
; TakeCoverResult hands out what it found. Returns whether the search could be started
bool Function RequestCover(Actor companion, int radiusMeters, int enemyMeters, bool mustMove) global native

; What the search of RequestCover found, or an empty list while it is still running. Five numbers: what came of it
; (1 = a spot, 2 = the companion is covered where it stands, 0 = no such spot, -1 = no enemy around, -2 = the plugin
; cannot look), x, y and z of the spot, and how many enemies it hid from
float[] Function TakeCoverResult() global native

; Why the companion should leave the cover it stands in, as the start of a sentence ("you were hit", "Bandit got too
; close"), or "" if there is no reason: it lost health since the last call, or an enemy that sees it is closer than
; nearMeters. isFirst: the first call for this cover, so there is no health from before to compare with
string Function GetCoverThreat(Actor companion, int nearMeters, bool isFirst) global native

; The two functions below exist from interface version 28 on

; view: what lies in front of the companion as a grid of cells, columns wide and rows high, over degrees from left to
; right. One ray per cell tells the ground, wall or ceiling it meets, and the characters and things the plugin knows
; are put into the cells their outline covers. Returns numbers only: the format, columns, rows, degrees, how many
; meters the rays reach, how many entries the legend has, how many numbers each entry and each cell has, then the
; legend and the cells. The companion server makes the lines from them (describe_view in state_text.py).
; An empty list if the plugin cannot look
int[] Function GetView(Actor companion, int columns, int rows, int degrees) global native

; The names that belong to the legend GetView returned last, in its order
string[] Function GetViewNames() global native
