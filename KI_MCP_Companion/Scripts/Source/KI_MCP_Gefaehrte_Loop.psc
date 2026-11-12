Scriptname KI_MCP_Gefaehrte_Loop extends Quest
{Long polling loop between Skyrim and the companion server (companion_main.py in the Mantella fork).
The game can only ask and the server can only answer. So this script keeps one request open at all times.
The server holds it until the AI has a command. Collecting the game state takes about a second,
so a request only carries it when the server asked for it with the command report_state.}

; ------------------------------------------------------------------- settings

int Property ServerPort = 4998 AutoReadOnly
; Pause before asking again after the server could not be reached (damper)
float Property ErrorPauseSeconds = 1.0 AutoReadOnly
; The server holds a request for 25 seconds. If nothing at all came back after this time, ask again
float Property WatchdogSeconds = 40.0 AutoReadOnly
; The quest of the game itself that keeps track of the player's follower (DialogueFollower in Skyrim.esm)
int Property FollowerQuestFormId = 0x000750BA AutoReadOnly
string Property FollowerQuestFile = "Skyrim.esm" AutoReadOnly
; Distances go to the server in meters. One meter is about 70 game units
float Property GameUnitsPerMeter = 70.0 AutoReadOnly
; Characters within this distance of the player are listed for the server
float Property NearbyRadiusMeters = 50.0 AutoReadOnly
; Outdoors the world is cut into cells, and only the cell the player stands in can be listed completely.
; To also catch characters in the cells next to it, this many random characters in reach are drawn in addition
int Property RandomSampleCount = 12 AutoReadOnly
; Form type of characters for Cell.GetNumRefs and Cell.GetNthRef (kNPC in SKSE)
int Property FormTypeNpc = 43 AutoReadOnly
; How fast the companion walks to a character for move_to: 0.0 = walking pace, 1.0 = running
float Property WalkSpeed = 1.0 AutoReadOnly
; The value "Confidence" decides whether a character fights or runs. 0 is "cowardly": never fights, always runs from enemies
float Property ConfidenceCowardly = 0.0 AutoReadOnly
float Property MinutesPerDay = 1440.0 AutoReadOnly
; Name under which the SKSE plugin of this mod (KI_MCP_Gefaehrte.dll) registers with SKSE. It reads what scripts cannot get at
string Property NativePluginName = "KI_MCP_Gefaehrte" AutoReadOnly
; At most this many open quests go to the server
int Property MaxQuests = 25 AutoReadOnly
; From this interface version on the SKSE plugin can listen to what characters say
int Property NativeVersionWithHearing = 2 AutoReadOnly
; At most this many lines that were heard go to the server with one state
int Property MaxHeardLines = 20 AutoReadOnly
; From this interface version on the SKSE plugin knows where quest targets are and which places are around
int Property NativeVersionWithPlaces = 3 AutoReadOnly
; At most this many targets of tracked quests go to the server
int Property MaxQuestTargets = 8 AutoReadOnly
; Places around the player: how far the plugin looks, and how many map markers and doors go to the server
int Property PlaceRadiusMeters = 300 AutoReadOnly
int Property MaxPlaceMarkers = 6 AutoReadOnly
int Property MaxPlaceDoors = 6 AutoReadOnly
; Gold is an item like any other. This is its form ID in Skyrim.esm
int Property GoldFormId = 0x0000000F AutoReadOnly
string Property GoldFile = "Skyrim.esm" AutoReadOnly
; At most this many kinds of items of one inventory go to the server. Every item costs several questions to the game
int Property MaxInventoryItems = 120 AutoReadOnly
; Numbers per item in the inventory lists: form ID, how many, form type, worn or held (see AddInventoryToState)
int Property ValuesPerItem = 4 AutoReadOnly
; Form types as SKSE numbers them (Form.GetType). Only these kinds can be worn or held
int Property FormTypeArmor = 26 AutoReadOnly
int Property FormTypeLight = 31 AutoReadOnly
int Property FormTypeWeapon = 41 AutoReadOnly
int Property FormTypeAmmo = 42 AutoReadOnly
; Potions, poisons and food
int Property FormTypePotion = 46 AutoReadOnly
; Hands for Actor.GetEquippedObject
int Property HandLeft = 0 AutoReadOnly
int Property HandRight = 1 AutoReadOnly
; Numbers per character in the list "nearby" (see AddNearbyToState)
int Property ValuesPerNearby = 5 AutoReadOnly
; For loot: this close to a body the companion can reach what the body carries
float Property LootReachMeters = 3.0 AutoReadOnly
; Own event that starts the walk of move_to and loot. Walking makes a script wait until the character has arrived,
; and the loop must not wait that long. An event runs next to the loop
string Property EVENT_WALK = "KI_MCP_Gefaehrte_Walk" AutoReadOnly

; ------------------------------------------------------------------- protocol
; These strings have to match src/companion/companion_constants.py in the Mantella fork

string Property ROUTE_GAME = "companion" AutoReadOnly
string Property KEY_POLL_ID = "companion_poll_id" AutoReadOnly
string Property KEY_STATE = "companion_state" AutoReadOnly
string Property KEY_RESULTS = "companion_results" AutoReadOnly
string Property KEY_RESULT_OK = "companion_ok" AutoReadOnly
string Property KEY_RESULT_MESSAGE = "companion_message" AutoReadOnly
string Property KEY_REPLY_TYPE = "companion_reply_type" AutoReadOnly
string Property REPLY_TYPE_COMMANDS = "companion_commands" AutoReadOnly
string Property KEY_COMMANDS = "companion_commands" AutoReadOnly
string Property KEY_COMMAND_ID = "companion_command_id" AutoReadOnly
string Property KEY_COMMAND_ACTION = "companion_action" AutoReadOnly
; The ref_id of the target as text, and the same ID as a number cut into its upper and lower 16 bits
string Property KEY_COMMAND_TARGET = "companion_target" AutoReadOnly
string Property KEY_COMMAND_TARGET_HIGH = "companion_target_high" AutoReadOnly
string Property KEY_COMMAND_TARGET_LOW = "companion_target_low" AutoReadOnly
; For report_state: whose inventory the state should carry (see INVENTORY_...), or empty for none
string Property KEY_COMMAND_DETAIL = "companion_detail" AutoReadOnly
; For give and take: how many of the item (0 = all of them)
string Property KEY_COMMAND_COUNT = "companion_count" AutoReadOnly
string Property INVENTORY_OWN = "own" AutoReadOnly
string Property INVENTORY_PLAYER = "player" AutoReadOnly
string Property INVENTORY_BOTH = "both" AutoReadOnly
; What the dead character carries that the target of the report_state command names
string Property INVENTORY_CORPSE = "corpse" AutoReadOnly
; For loot: the ID of the one item to take from the body, cut in two like the target. Both 0 = everything
string Property KEY_COMMAND_ITEM_HIGH = "companion_item_high" AutoReadOnly
string Property KEY_COMMAND_ITEM_LOW = "companion_item_low" AutoReadOnly
string Property ACTION_REPORT_STATE = "report_state" AutoReadOnly
string Property ACTION_FOLLOW = "follow" AutoReadOnly
string Property ACTION_WAIT = "wait" AutoReadOnly
string Property ACTION_ATTACK = "attack" AutoReadOnly
string Property ACTION_STAND_DOWN = "stand_down" AutoReadOnly
string Property ACTION_FLEE = "flee" AutoReadOnly
string Property ACTION_MOVE_TO = "move_to" AutoReadOnly
string Property ACTION_EQUIP = "equip" AutoReadOnly
string Property ACTION_UNEQUIP = "unequip" AutoReadOnly
string Property ACTION_GIVE = "give" AutoReadOnly
string Property ACTION_TAKE = "take" AutoReadOnly
string Property ACTION_LOOT = "loot" AutoReadOnly

; ------------------------------------------------------------------ variables

; Number of the newest request. The server sends it back, so replies to older requests can be told apart
int _pollId = 0
bool _isContactShown = false
; The follower quest of the game, looked up once
DialogueFollowerScript _followerQuest
; Whom the companion is walking to at the moment because of move_to or loot (None = nobody)
Actor _walkTarget
; loot: the walk that is running leads to a body. What to take there (None = everything),
; and whether the companion followed the player before and should do so again afterwards
bool _isLootWalk = false
Form _lootItem
bool _followAfterLoot = false
; What became of commands that take time (loot, move_to), as text for the AI. Goes out with the next state
string _report = ""
; Goes up with every command. A walk that was started under an older number has been replaced and stays silent
int _walkNumber = 0
; Who is retreating at the moment because of flee (None = nobody), and how brave that character was before
Actor _fleeingActor
float _confidenceBeforeFlee = 0.0
; Interface version of the SKSE plugin of this mod (0 = the DLL is not loaded, so its functions must not be called)
int _nativeVersion = 0
; Whether the SKSE plugin listens to what characters say (it could hook into the subtitles of the game)
bool _isHearing = false
; The item "gold", looked up once
Form _gold
; Whose inventory the next state should carry (see INVENTORY_...). Set by a report_state command, used up by BuildState
string _wantedInventory = ""
; For INVENTORY_CORPSE: whose body that is
Actor _wantedCorpse

; --------------------------------------------------------------------- events

Event OnInit()
    StartLoop()
EndEvent

; Called by KI_MCP_Gefaehrte_PlayerAlias. Registrations for mod events do not survive loading a save
Function OnGameLoaded()
    StartLoop()
EndFunction

Function StartLoop()
    RegisterForModEvent("SKSE_HTTP_OnHttpReplyReceived", "OnHttpReplyReceived")
    RegisterForModEvent("SKSE_HTTP_OnHttpErrorReceived", "OnHttpErrorReceived")
    RegisterForModEvent(EVENT_WALK, "OnWalkRequested")
    ; The game does not keep a changed "Confidence" in a save, so a retreat ends with loading. So does a walk
    StopFleeing()
    EndWalk()
    _nativeVersion = 0
    _isHearing = false
    If SKSE.GetPluginVersion(NativePluginName) != -1
        _nativeVersion = KI_MCP_Gefaehrte_Native.GetInterfaceVersion()
        If _nativeVersion >= NativeVersionWithHearing
            _isHearing = KI_MCP_Gefaehrte_Native.IsHearing()
        EndIf
    EndIf
    _isContactShown = false
    _pollId = Utility.RandomInt(1, 1000000)
    int[] noResults
    ; The first request carries the state, so the server has one even before the AI asks for it
    SendPoll(noResults, true)
EndFunction

Event OnHttpReplyReceived(int typedDictionaryHandle)
    string replyType = SKSE_HTTP.getString(typedDictionaryHandle, KEY_REPLY_TYPE, "")
    If replyType == ""
        ; Not for us. SKSE_HTTP sends every reply to all scripts that listen
        Return
    EndIf
    If SKSE_HTTP.getInt(typedDictionaryHandle, KEY_POLL_ID, -1) != _pollId
        ; Reply to an older request (eg one from before a save was loaded). The newest request is still open
        Return
    EndIf

    If !_isContactShown
        _isContactShown = true
        Debug.Notification("AI companion: server connected")
    EndIf

    int[] resultHandles
    bool isStateWanted = false
    If replyType == REPLY_TYPE_COMMANDS
        int[] commandHandles = SKSE_HTTP.getNestedDictionariesArray(typedDictionaryHandle, KEY_COMMANDS)
        resultHandles = RunCommands(commandHandles)
        ; Every command gets a result, except for report_state. So a missing result means: the server wants the state
        isStateWanted = resultHandles.Length < commandHandles.Length
    EndIf
    SendPoll(resultHandles, isStateWanted)
EndEvent

Event OnHttpErrorReceived(int typedDictionaryHandle)
    ; The server is not running or it answered with an error
    If _isContactShown
        _isContactShown = false
        Debug.Notification("AI companion: server lost, trying again")
    EndIf
    RegisterForSingleUpdate(ErrorPauseSeconds)
EndEvent

Event OnUpdate()
    ; Either the pause after an error is over, or the watchdog hit because no reply came for too long
    int[] noResults
    SendPoll(noResults, false)
EndEvent

; -------------------------------------------------------------------- request

; Collecting the state takes about a second, and the results of commands would have to wait for it.
; So a request only carries the state if isStateWanted is set
Function SendPoll(int[] resultHandles, bool isStateWanted)
    _pollId += 1
    int ownPollId = _pollId

    int requestHandle = SKSE_HTTP.createDictionary()
    SKSE_HTTP.setInt(requestHandle, KEY_POLL_ID, ownPollId)
    If isStateWanted
        SKSE_HTTP.setNestedDictionary(requestHandle, KEY_STATE, BuildState())
    EndIf
    If resultHandles.Length > 0
        SKSE_HTTP.setNestedDictionariesArray(requestHandle, KEY_RESULTS, resultHandles)
    EndIf
    SKSE_HTTP.sendLocalhostHttpRequest(requestHandle, ServerPort, ROUTE_GAME)

    RegisterForSingleUpdate(WatchdogSeconds)
EndFunction

; ---------------------------------------------------------------------- state
; Every call into SKSE_HTTP and every question to the game makes this script wait for the next frame.
; So the state goes to the server in few big pieces: a few texts and a few lists of plain numbers,
; instead of one named entry per value. The server gives the numbers their names back
; (src/companion/game_state.py in the Mantella fork). The order of the numbers has to match that file

int Function BuildState()
    float startTime = Utility.GetCurrentRealTime()
    Actor player = Game.GetPlayer()
    Cell playerCell = player.GetParentCell()
    bool isInterior = false
    If playerCell
        isInterior = playerCell.IsInterior()
    EndIf

    int stateHandle = SKSE_HTTP.createDictionary()
    SetStringSafely(stateHandle, "location", GetLocationName(player))
    SetStringSafely(stateHandle, "player_name", player.GetDisplayName())

    ; Health in percent, in combat, position x, y and z in game units,
    ; direction the player faces in degrees (0 = north, 90 = east), indoors
    float playerX = player.GetPositionX()
    float playerY = player.GetPositionY()
    float playerZ = player.GetPositionZ()
    int[] playerValues = new int[7]
    playerValues[0] = GetHealthPercent(player)
    playerValues[1] = ToNumber(player.IsInCombat())
    playerValues[2] = playerX as int
    playerValues[3] = playerY as int
    playerValues[4] = playerZ as int
    playerValues[5] = player.GetAngleZ() as int
    playerValues[6] = ToNumber(isInterior)
    SKSE_HTTP.setIntArray(stateHandle, "player", playerValues)

    ; Weather outside (-1 = unknown, 0 = pleasant, 1 = cloudy, 2 = rainy, 3 = snow), the time of day in minutes since midnight,
    ; the interface version of the SKSE plugin of this mod (0 = not loaded, so there are no quests in this state),
    ; and whether that plugin listens to what characters say
    int[] worldValues = new int[4]
    worldValues[0] = -1
    Weather currentWeather = Weather.GetCurrentWeather()
    If currentWeather
        worldValues[0] = currentWeather.GetClassification()
    EndIf
    ; The game counts time in days since the start of the game. What stands behind the point is the time of day
    float gameDays = Utility.GetCurrentGameTime()
    worldValues[1] = ((gameDays - (gameDays as int)) * MinutesPerDay) as int
    worldValues[2] = _nativeVersion
    worldValues[3] = ToNumber(_isHearing)
    SKSE_HTTP.setIntArray(stateHandle, "world", worldValues)

    ; The open quests of the journal with the texts of their objectives, one text per quest
    ; (see KI_MCP_Gefaehrte_Native.psc). No "quests" entry means: no open quests, or the SKSE plugin is not loaded
    If _nativeVersion > 0
        string[] questLines = KI_MCP_Gefaehrte_Native.GetOpenQuests(MaxQuests)
        If questLines.Length > 0
            SKSE_HTTP.setStringArray(stateHandle, "quests", questLines)
        EndIf
    EndIf

    ; Where the targets of the tracked quests are, and the places around the player (map markers and doors
    ; that lead somewhere), one text per target and per place (see KI_MCP_Gefaehrte_Native.psc).
    ; The targets name their quest by its place in the list above, so both lists are fetched with the same limit
    If _nativeVersion >= NativeVersionWithPlaces
        string[] targetLines = KI_MCP_Gefaehrte_Native.GetQuestTargets(MaxQuests, MaxQuestTargets)
        If targetLines.Length > 0
            SKSE_HTTP.setStringArray(stateHandle, "quest_targets", targetLines)
        EndIf
        string[] placeLines = KI_MCP_Gefaehrte_Native.GetNearbyPlaces(PlaceRadiusMeters, MaxPlaceMarkers, MaxPlaceDoors)
        If placeLines.Length > 0
            SKSE_HTTP.setStringArray(stateHandle, "places", placeLines)
        EndIf
    EndIf

    ; What the characters around the player said since the last state, one text per line
    ; (see KI_MCP_Gefaehrte_Native.psc). The plugin forgets a line once it has handed it out, the server keeps it for the AI
    If _isHearing
        string[] heardLines = KI_MCP_Gefaehrte_Native.TakeHeardLines(MaxHeardLines)
        If heardLines.Length > 0
            SKSE_HTTP.setStringArray(stateHandle, "heard", heardLines)
        EndIf
    EndIf

    ; No "companion" entry means: the player has no follower at the moment
    Actor companion = GetCompanion()
    Actor companionTarget = None
    If companion
        companionTarget = companion.GetCombatTarget()
        SetStringSafely(stateHandle, "companion_name", companion.GetDisplayName())
        SKSE_HTTP.setIntArray(stateHandle, "companion", BuildCompanionValues(companion, player, companionTarget))
    EndIf

    ; Gold of the player and of the companion (0 without a companion)
    int[] goldValues = new int[2]
    Form gold = GetGold()
    If gold
        goldValues[0] = player.GetItemCount(gold)
        If companion
            goldValues[1] = companion.GetItemCount(gold)
        EndIf
    EndIf
    SKSE_HTTP.setIntArray(stateHandle, "gold", goldValues)
    If companion
        AddHandsToState(stateHandle, companion)
    EndIf

    ; A whole inventory costs seconds, so it only goes along when the server asked for it
    string wantedInventory = _wantedInventory
    _wantedInventory = ""
    If wantedInventory == INVENTORY_PLAYER || wantedInventory == INVENTORY_BOTH
        AddInventoryToState(stateHandle, player, "inventory_player")
    EndIf
    If companion && (wantedInventory == INVENTORY_OWN || wantedInventory == INVENTORY_BOTH)
        AddInventoryToState(stateHandle, companion, "inventory_own")
    EndIf
    If wantedInventory == INVENTORY_CORPSE
        AddCorpseToState(stateHandle, _wantedCorpse)
    EndIf
    _wantedCorpse = None

    ; What became of loot and move_to since the last state. The text is taken out first,
    ; because a walk that ends while this script waits for the game adds to it
    string report = _report
    _report = ""
    If report != ""
        SetStringSafely(stateHandle, "report", report)
    EndIf

    float scanStartTime = Utility.GetCurrentRealTime()
    AddNearbyToState(stateHandle, player, playerX, playerY, playerZ, playerCell, isInterior, companion, companionTarget)

    ; How long collecting took in milliseconds: all of it, and the characters nearby alone.
    ; The AI has to wait this long for every state, so these numbers show where time is lost
    float endTime = Utility.GetCurrentRealTime()
    int[] timeValues = new int[2]
    timeValues[0] = ((endTime - startTime) * 1000.0) as int
    timeValues[1] = ((endTime - scanStartTime) * 1000.0) as int
    SKSE_HTTP.setIntArray(stateHandle, "times_ms", timeValues)
    Return stateHandle
EndFunction

; Ref ID, health in percent, dead, in combat, waiting, in the loaded area, distance to the player in meters,
; angle from where the player faces to the companion in degrees (negative = left, positive = right),
; ref ID of whom the companion fights (0 = nobody), direction the companion faces in degrees (0 = north, 90 = east),
; retreating because of flee, ref ID of whom the companion is walking to because of move_to or loot (0 = nobody)
int[] Function BuildCompanionValues(Actor companion, Actor player, Actor companionTarget)
    int[] companionValues = new int[12]
    companionValues[0] = companion.GetFormID()
    companionValues[1] = GetHealthPercent(companion)
    companionValues[2] = ToNumber(companion.IsDead())
    companionValues[3] = ToNumber(companion.IsInCombat())
    companionValues[4] = ToNumber(IsWaiting(companion))
    ; Far away (eg left behind in another place) the game has no position worth measuring
    If companion.Is3DLoaded()
        companionValues[5] = 1
        companionValues[6] = ToMeters(companion.GetDistance(player))
        companionValues[7] = player.GetHeadingAngle(companion) as int
        companionValues[9] = companion.GetAngleZ() as int
    EndIf
    If companionTarget
        companionValues[8] = companionTarget.GetFormID()
    EndIf
    companionValues[10] = ToNumber(_fleeingActor == companion)
    If _walkTarget
        companionValues[11] = _walkTarget.GetFormID()
    EndIf
    Return companionValues
EndFunction

; ---------------------------------------------------------------- inventory

Form Function GetGold()
    If !_gold
        _gold = Game.GetFormFromFile(GoldFormId, GoldFile)
    EndIf
    Return _gold
EndFunction

; What the companion holds: always two texts, "R:" and "L:" followed by the name of what is in that hand (nothing = empty hand).
; A shield counts as the left hand. A weapon for both hands is only named for the right hand
Function AddHandsToState(int stateHandle, Actor companion)
    Form rightHand = companion.GetEquippedObject(HandRight)
    Form leftHand = companion.GetEquippedObject(HandLeft)
    If !leftHand
        leftHand = companion.GetEquippedShield()
    EndIf
    string[] hands = new string[2]
    hands[0] = "R:"
    hands[1] = "L:"
    If rightHand
        hands[0] = "R:" + rightHand.GetName()
    EndIf
    If leftHand && leftHand != rightHand
        hands[1] = "L:" + leftHand.GetName()
    EndIf
    SKSE_HTTP.setStringArray(stateHandle, "hands", hands)
EndFunction

; The inventory of the player or of the companion as two lists under keyName and keyName + "_names".
; Numbers: first how many kinds of items there are in all (more than MaxInventoryItems are cut off), then per item
; form ID, how many, form type, worn or held (1 or 0). An item without a name (the game hides those) stays all 0.
; Names: one text per item, its place in the list of numbers (from 0), a colon and the name
Function AddInventoryToState(int stateHandle, Actor owner, string keyName)
    int totalCount = owner.GetNumItems()
    int itemCount = totalCount
    If itemCount > MaxInventoryItems
        itemCount = MaxInventoryItems
    EndIf
    int[] itemValues = Utility.CreateIntArray(1 + itemCount * ValuesPerItem)
    itemValues[0] = totalCount
    If itemCount == 0
        SKSE_HTTP.setIntArray(stateHandle, keyName, itemValues)
        Return
    EndIf

    string[] itemNames = Utility.CreateStringArray(itemCount)
    int index = 0
    While index < itemCount
        Form item = owner.GetNthForm(index)
        If item
            string itemName = item.GetName()
            If itemName != ""
                int start = 1 + index * ValuesPerItem
                int itemType = item.GetType()
                itemValues[start] = item.GetFormID()
                itemValues[start + 1] = owner.GetItemCount(item)
                itemValues[start + 2] = itemType
                If itemType == FormTypeWeapon || itemType == FormTypeArmor || itemType == FormTypeAmmo || itemType == FormTypeLight
                    itemValues[start + 3] = ToNumber(owner.IsEquipped(item))
                EndIf
                itemNames[index] = (index as string) + ":" + itemName
            EndIf
        EndIf
        index += 1
    EndWhile
    SKSE_HTTP.setIntArray(stateHandle, keyName, itemValues)
    SKSE_HTTP.setStringArray(stateHandle, keyName + "_names", itemNames)
EndFunction

; What a dead character carries, for loot: its ref ID under "corpse", its name under "corpse_name",
; and its things under "inventory_corpse" like the other inventories.
; Nothing at all if there is no such body in the loaded area
Function AddCorpseToState(int stateHandle, Actor corpse)
    If !corpse || !corpse.IsDead() || !corpse.Is3DLoaded()
        Return
    EndIf
    int[] corpseValues = new int[1]
    corpseValues[0] = corpse.GetFormID()
    SKSE_HTTP.setIntArray(stateHandle, "corpse", corpseValues)
    SetStringSafely(stateHandle, "corpse_name", corpse.GetDisplayName())
    AddInventoryToState(stateHandle, corpse, "inventory_corpse")
EndFunction

; ------------------------------------------------------------------- nearby
; The characters around the player, living and dead, without the player and the companion.
; If there are more than fit into the list, the living win over the dead, and among each the closest ones.
; The server sorts the list. If nobody is around, the state gets no "nearby" entries at all

Function AddNearbyToState(int stateHandle, Actor player, float playerX, float playerY, float playerZ, Cell playerCell, bool isInterior, Actor companion, Actor companionTarget)
    ; The length of these two arrays is the highest number of characters that get listed.
    ; Papyrus only takes a plain number as the length of a new array
    Actor[] found = new Actor[10]
    float[] distances = new float[10]
    bool[] deadFlags = new bool[10]
    ; Characters that were looked at and do not belong into the list. Outdoors the same character
    ; is drawn several times, and with this list looking at it again costs no question to the game
    Actor[] rejected = new Actor[20]
    int foundCount = 0
    float radius = NearbyRadiusMeters * GameUnitsPerMeter

    ; Whoever the companion fights belongs into the list first
    foundCount = AddNearbyActor(found, distances, deadFlags, rejected, foundCount, companionTarget, player, companion, radius)

    If playerCell
        int refCount = playerCell.GetNumRefs(FormTypeNpc)
        int refIndex = 0
        While refIndex < refCount
            foundCount = AddNearbyActor(found, distances, deadFlags, rejected, foundCount, playerCell.GetNthRef(refIndex, FormTypeNpc) as Actor, player, companion, radius)
            refIndex += 1
        EndWhile

        If !isInterior
            int sampleIndex = 0
            While sampleIndex < RandomSampleCount
                foundCount = AddNearbyActor(found, distances, deadFlags, rejected, foundCount, Game.FindRandomActor(playerX, playerY, playerZ, radius), player, companion, radius)
                sampleIndex += 1
            EndWhile
        EndIf
    EndIf

    If foundCount == 0
        Return
    EndIf

    ; Five numbers per character: ref ID, distance to the player in meters,
    ; angle from where the player faces to the character in degrees (negative = left, positive = right),
    ; hostile to the player (always 0 for the dead), dead
    int[] nearbyValues = Utility.CreateIntArray(foundCount * ValuesPerNearby)
    ; One text per character: its place in the list, a colon and its name, eg "0:Bandit".
    ; SKSE_HTTP drops every name that is not valid UTF-8 without a word, so the server could not count the places
    string[] nearbyNames = Utility.CreateStringArray(foundCount)
    int index = 0
    While index < foundCount
        Actor nearbyActor = found[index]
        int valueIndex = index * ValuesPerNearby
        nearbyValues[valueIndex] = nearbyActor.GetFormID()
        nearbyValues[valueIndex + 1] = ToMeters(distances[index])
        nearbyValues[valueIndex + 2] = player.GetHeadingAngle(nearbyActor) as int
        If deadFlags[index]
            nearbyValues[valueIndex + 4] = 1
        Else
            nearbyValues[valueIndex + 3] = ToNumber(nearbyActor.IsHostileToActor(player))
        EndIf
        nearbyNames[index] = (index as string) + ":" + nearbyActor.GetDisplayName()
        index += 1
    EndWhile
    SKSE_HTTP.setIntArray(stateHandle, "nearby", nearbyValues)
    SKSE_HTTP.setStringArray(stateHandle, "nearby_names", nearbyNames)
EndFunction

; Puts the candidate into the list if it is a character in reach, living or dead, that is not listed yet.
; Returns the new number of listed characters
int Function AddNearbyActor(Actor[] found, float[] distances, bool[] deadFlags, Actor[] rejected, int foundCount, Actor candidate, Actor player, Actor companion, float radius)
    If !candidate || candidate == player || candidate == companion
        Return foundCount
    EndIf
    If found.Find(candidate) >= 0 || rejected.Find(candidate) >= 0
        Return foundCount
    EndIf
    ; The distance comes first because most characters that do not belong into the list are too far away.
    ; Disabled characters and characters outside the loaded area have no body in the world
    float distance = candidate.GetDistance(player)
    If distance > radius || !candidate.Is3DLoaded()
        RememberRejected(rejected, candidate)
        Return foundCount
    EndIf
    bool isDead = candidate.IsDead()

    If foundCount < found.Length
        found[foundCount] = candidate
        distances[foundCount] = distance
        deadFlags[foundCount] = isDead
        Return foundCount + 1
    EndIf

    ; The list is full. The living come first: a living candidate takes the place of the farthest dead one.
    ; Among its own kind (living or dead) the candidate takes the place of the farthest one if it is closer
    int farthestLiving = -1
    int farthestDead = -1
    int index = 0
    While index < foundCount
        If deadFlags[index]
            If farthestDead < 0 || distances[index] > distances[farthestDead]
                farthestDead = index
            EndIf
        ElseIf farthestLiving < 0 || distances[index] > distances[farthestLiving]
            farthestLiving = index
        EndIf
        index += 1
    EndWhile
    int placeToTake = -1
    If farthestDead >= 0 && (!isDead || distance < distances[farthestDead])
        placeToTake = farthestDead
    ElseIf !isDead && farthestLiving >= 0 && distance < distances[farthestLiving]
        placeToTake = farthestLiving
    EndIf
    If placeToTake >= 0
        RememberRejected(rejected, found[placeToTake])
        found[placeToTake] = candidate
        distances[placeToTake] = distance
        deadFlags[placeToTake] = isDead
    Else
        RememberRejected(rejected, candidate)
    EndIf
    Return foundCount
EndFunction

; If the list of rejected characters is full, the candidate is simply looked at again next time
Function RememberRejected(Actor[] rejected, Actor candidate)
    int freeIndex = rejected.Find(None)
    If freeIndex >= 0
        rejected[freeIndex] = candidate
    EndIf
EndFunction

; ------------------------------------------------------------------- commands

; Returns the handles of the results that go to the server with the next request
int[] Function RunCommands(int[] commandHandles)
    int resultCount = 0
    int index = 0
    While index < commandHandles.Length
        If SKSE_HTTP.getString(commandHandles[index], KEY_COMMAND_ACTION, "") != ACTION_REPORT_STATE
            resultCount += 1
        Else
            _wantedInventory = SKSE_HTTP.getString(commandHandles[index], KEY_COMMAND_DETAIL, "")
            If _wantedInventory == INVENTORY_CORPSE
                _wantedCorpse = GetTargetActor(commandHandles[index])
            EndIf
        EndIf
        index += 1
    EndWhile

    int[] resultHandles
    If resultCount == 0
        ; Only report_state: nothing to do, the next request carries the fresh state anyway
        Return resultHandles
    EndIf

    resultHandles = Utility.CreateIntArray(resultCount)
    int resultIndex = 0
    index = 0
    While index < commandHandles.Length
        string actionName = SKSE_HTTP.getString(commandHandles[index], KEY_COMMAND_ACTION, "")
        If actionName != ACTION_REPORT_STATE
            resultHandles[resultIndex] = RunCommand(commandHandles[index], actionName)
            resultIndex += 1
        EndIf
        index += 1
    EndWhile
    Return resultHandles
EndFunction

int Function RunCommand(int commandHandle, string actionName)
    bool isOk = false
    string resultText = ""
    Actor companion = GetCompanion()
    If !IsKnownAction(actionName)
        resultText = "The game mod cannot do '" + actionName + "' yet. So far it can do follow, wait, attack, stand_down, flee, move_to, loot, equip, unequip, give and take."
    ElseIf !companion
        resultText = "You have no character in the game yet. The player has to take a follower along first, then that follower is you."
    ElseIf companion.IsDead()
        resultText = "Your character is dead."
    ElseIf IsItemAction(actionName)
        ; What the companion does with its things changes nothing about where it walks or whom it fights
        Form item = GetTargetForm(commandHandle)
        resultText = GetItemProblem(companion, item, SKSE_HTTP.getString(commandHandle, KEY_COMMAND_TARGET, ""), actionName)
        If resultText == ""
            isOk = true
            resultText = DoItemCommand(companion, actionName, item, SKSE_HTTP.getInt(commandHandle, KEY_COMMAND_COUNT, 1))
        EndIf
    Else
        Actor target = None
        Form lootItem = None
        If actionName == ACTION_ATTACK || actionName == ACTION_MOVE_TO || actionName == ACTION_LOOT
            target = GetTargetActor(commandHandle)
            resultText = GetTargetProblem(companion, target, SKSE_HTTP.getString(commandHandle, KEY_COMMAND_TARGET, ""), actionName == ACTION_ATTACK)
        EndIf
        If resultText == "" && actionName == ACTION_LOOT
            int itemHigh = SKSE_HTTP.getInt(commandHandle, KEY_COMMAND_ITEM_HIGH, 0)
            int itemLow = SKSE_HTTP.getInt(commandHandle, KEY_COMMAND_ITEM_LOW, 0)
            lootItem = GetFormFromHalves(itemHigh, itemLow)
            resultText = GetLootProblem(target, lootItem, itemHigh != 0 || itemLow != 0)
        EndIf
        If resultText == ""
            isOk = true
            ; A loot that gets cut short had made the companion wait, although it was following the player
            bool followAgain = _isLootWalk && _followAfterLoot
            ; A new command ends what the one before started: the walk of move_to and loot, and the retreat of flee
            EndWalk()
            If actionName != ACTION_FLEE
                StopFleeing()
            EndIf
            If actionName == ACTION_LOOT
                resultText = StartLoot(companion, target, lootItem, followAgain)
            Else
                If followAgain && actionName != ACTION_FOLLOW && actionName != ACTION_WAIT && actionName != ACTION_MOVE_TO
                    SetWaiting(companion, false)
                EndIf
                resultText = DoCommand(companion, actionName, target)
            EndIf
        EndIf
    EndIf

    int resultHandle = SKSE_HTTP.createDictionary()
    SKSE_HTTP.setString(resultHandle, KEY_COMMAND_ID, SKSE_HTTP.getString(commandHandle, KEY_COMMAND_ID, ""))
    SKSE_HTTP.setBool(resultHandle, KEY_RESULT_OK, isOk)
    If !SKSE_HTTP.setString(resultHandle, KEY_RESULT_MESSAGE, resultText)
        ; A name in the text was not valid UTF-8, so SKSE_HTTP stored nothing
        SKSE_HTTP.setString(resultHandle, KEY_RESULT_MESSAGE, "The game could not send the text of this result.")
    EndIf
    Return resultHandle
EndFunction

bool Function IsKnownAction(string actionName)
    Return IsItemAction(actionName) || actionName == ACTION_FOLLOW || actionName == ACTION_WAIT || actionName == ACTION_ATTACK || actionName == ACTION_STAND_DOWN || actionName == ACTION_FLEE || actionName == ACTION_MOVE_TO || actionName == ACTION_LOOT
EndFunction

bool Function IsItemAction(string actionName)
    Return actionName == ACTION_EQUIP || actionName == ACTION_UNEQUIP || actionName == ACTION_GIVE || actionName == ACTION_TAKE
EndFunction

; Does what the command says and returns the text for the AI. Only call this after the command was checked
string Function DoCommand(Actor companion, string actionName, Actor target)
    If actionName == ACTION_FOLLOW
        SetWaiting(companion, false)
        Return "You follow the player now."
    EndIf
    If actionName == ACTION_WAIT
        SetWaiting(companion, true)
        Return "You wait here now."
    EndIf
    If actionName == ACTION_ATTACK
        companion.StartCombat(target)
        Return "You attack " + target.GetDisplayName() + " now."
    EndIf
    If actionName == ACTION_MOVE_TO
        ; Waiting comes first. A companion that follows would turn around to the player as soon as it has arrived
        SetWaiting(companion, true)
        _walkTarget = target
        SendModEvent(EVENT_WALK, "", _walkNumber as float)
        Return "You walk to " + target.GetDisplayName() + " and wait there. 'follow' brings you back to the player."
    EndIf
    If actionName == ACTION_FLEE
        StartFleeing(companion)
        ; The game decides between fighting and running when a fight starts, so the running fight is ended
        If companion.IsInCombat()
            companion.StopCombat()
        EndIf
        Return "You retreat: you do not fight and you run from enemies. This holds until your next command."
    EndIf
    ; stand_down
    If companion.IsInCombat()
        companion.StopCombat()
        Return "You stop fighting. Whoever keeps attacking you or the player will pull you back into the fight."
    EndIf
    Return "You were not fighting."
EndFunction

; The server sends the ref_id of the target as a number as well, because Papyrus cannot read hex text.
; It comes in two halves of 16 bits, so that both are small positive numbers
Actor Function GetTargetActor(int commandHandle)
    Return GetTargetForm(commandHandle) as Actor
EndFunction

; The same for any target: a character (ref_id) or an item (its ID from the inventory)
Form Function GetTargetForm(int commandHandle)
    int highHalf = SKSE_HTTP.getInt(commandHandle, KEY_COMMAND_TARGET_HIGH, 0)
    int lowHalf = SKSE_HTTP.getInt(commandHandle, KEY_COMMAND_TARGET_LOW, 0)
    Return GetFormFromHalves(highHalf, lowHalf)
EndFunction

; Puts the two halves of an ID together again and looks up what has that ID (None = nothing, or both halves 0)
Form Function GetFormFromHalves(int highHalf, int lowHalf)
    int formId = Math.LogicalOr(Math.LeftShift(highHalf, 16), lowHalf)
    If formId == 0
        Return None
    EndIf
    ; GetFormEx also finds what the game created while running (those IDs start with FF)
    Return Game.GetFormEx(formId)
EndFunction

; ---------------------------------------------------------------------- items
; equip, unequip, give and take. The target is the ID of an item as the inventory in the state lists it

; Returns why the companion cannot do this with the item, or "" if it can
string Function GetItemProblem(Actor companion, Form item, string targetText, string actionName)
    If !item
        Return "There is no item with the ID '" + targetText + "'. Take the ID from the inventory in STATE."
    EndIf
    If item as ObjectReference
        Return "'" + targetText + "' is a character or a thing in the world, not an item. Take the ID from the inventory in STATE."
    EndIf
    If actionName == ACTION_TAKE
        If Game.GetPlayer().GetItemCount(item) <= 0
            Return "The player has no " + item.GetName() + "."
        EndIf
        Return ""
    EndIf
    If companion.GetItemCount(item) <= 0
        Return "You have no " + item.GetName() + "."
    EndIf
    If actionName == ACTION_UNEQUIP && !companion.IsEquipped(item)
        Return "You are not wearing or holding " + item.GetName() + "."
    EndIf
    Return ""
EndFunction

; Does what the command says and returns the text for the AI. Only call this after GetItemProblem found nothing.
; wantedCount is for give and take: how many, 0 = all
string Function DoItemCommand(Actor companion, string actionName, Form item, int wantedCount)
    string itemName = item.GetName()
    If actionName == ACTION_EQUIP
        ; The last "true" keeps the game from showing a message. Equipping a potion or food means using it up
        companion.EquipItem(item, false, true)
        If item.GetType() == FormTypePotion
            Return "You use " + itemName + "."
        EndIf
        Return "You equip " + itemName + "."
    EndIf
    If actionName == ACTION_UNEQUIP
        companion.UnequipItem(item, false, true)
        Return "You put " + itemName + " away."
    EndIf

    Actor player = Game.GetPlayer()
    Actor giver = companion
    Actor receiver = player
    If actionName == ACTION_TAKE
        giver = player
        receiver = companion
    EndIf
    int count = giver.GetItemCount(item)
    If wantedCount > 0 && wantedCount < count
        count = wantedCount
    EndIf
    giver.RemoveItem(item, count, true, receiver)
    If actionName == ACTION_TAKE
        Return "You take " + count + " " + itemName + " from the player."
    EndIf
    Return "You give " + count + " " + itemName + " to the player."
EndFunction

; Returns why the companion cannot attack the target (isAttack) or walk to it, or "" if it can
string Function GetTargetProblem(Actor companion, Actor target, string targetText, bool isAttack)
    If !target
        Return "There is no character with the ref_id '" + targetText + "'. Take the ref_id from 'nearby' in STATE."
    EndIf
    If target == companion
        Return "That is you yourself."
    EndIf
    If isAttack && target == Game.GetPlayer()
        Return "That is the player. You do not attack the player."
    EndIf
    If !target.Is3DLoaded()
        Return target.GetDisplayName() + " is too far away."
    EndIf
    If isAttack && target.IsDead()
        Return target.GetDisplayName() + " is already dead."
    EndIf
    Return ""
EndFunction

; ----------------------------------------------------------------------- loot
; loot: the companion walks to a dead character and takes what it carries: one kind of item or everything.
; The walk takes time, so the command only starts it. What came of it goes out with the next state (_report)

; Returns why the companion cannot loot the target, or "" if it can.
; isItemNamed: the command names one item (None = it named something that is no item), otherwise everything is meant
string Function GetLootProblem(Actor target, Form item, bool isItemNamed)
    If !target.IsDead()
        Return target.GetDisplayName() + " is alive. You can only loot the dead."
    EndIf
    If isItemNamed
        If !item || (item as ObjectReference)
            Return "The ID in 'detail' is not an item. Take it from the list STATE gives you for this body (argument 'corpse')."
        EndIf
        If target.GetItemCount(item) <= 0
            Return "The body of " + target.GetDisplayName() + " has no " + item.GetName() + "."
        EndIf
    ElseIf target.GetNumItems() == 0
        Return "The body of " + target.GetDisplayName() + " carries nothing."
    EndIf
    Return ""
EndFunction

; Sends the companion to the body. Only call this after the command was checked.
; followAgain: a loot that this one replaces had already made a following companion wait
string Function StartLoot(Actor companion, Actor corpse, Form item, bool followAgain)
    ; Afterwards the companion does again what it did before: follow the player or wait
    _followAfterLoot = followAgain || !IsWaiting(companion)
    ; Waiting comes first, as for move_to
    SetWaiting(companion, true)
    _isLootWalk = true
    _lootItem = item
    _walkTarget = corpse
    SendModEvent(EVENT_WALK, "", _walkNumber as float)
    string what = "everything it carries"
    If item
        what = item.GetName()
    EndIf
    Return "You walk to the body of " + corpse.GetDisplayName() + " to take " + what + ". Your next STATE tells you what you got."
EndFunction

; Called when the walk to the body is over. Takes the things if the companion stands close enough
Function FinishLoot(Actor companion, Actor corpse, Form item, int ownWalkNumber)
    string corpseName = corpse.GetDisplayName()
    If !corpse.Is3DLoaded() || companion.GetDistance(corpse) > LootReachMeters * GameUnitsPerMeter
        AddReport("You did not get to the body of " + corpseName + " and took nothing.")
        Debug.Notification("AI companion: did not get to the body of " + corpseName)
    ElseIf item
        int count = corpse.GetItemCount(item)
        If count > 0
            ; The "true" keeps the game from showing a message
            corpse.RemoveItem(item, count, true, companion)
            AddReport("You took " + count + " " + item.GetName() + " from the body of " + corpseName + ".")
        Else
            AddReport("The body of " + corpseName + " had no " + item.GetName() + " any more.")
        EndIf
    Else
        int kindCount = corpse.GetNumItems()
        ; The last "false": things that belong to a quest stay on the body
        corpse.RemoveAllItems(companion, false, false)
        AddReport("You took everything from the body of " + corpseName + ": " + kindCount + " kinds of items.")
    EndIf
    ; A newer command has the last word on following and waiting
    If _followAfterLoot && ownWalkNumber == _walkNumber
        SetWaiting(companion, false)
    EndIf
EndFunction

; Keeps a text for the AI until the next state goes out
Function AddReport(string reportText)
    If _report == ""
        _report = reportText
    Else
        _report = _report + " " + reportText
    EndIf
EndFunction

; ----------------------------------------------------------------------- walk
; move_to: the companion walks to a character and waits there. loot walks the same way, to a body

; Raised by DoCommand. numArg is the number of the command that asked for the walk
Event OnWalkRequested(string eventName, string strArg, float numArg, Form sender)
    int ownWalkNumber = numArg as int
    Actor companion = GetCompanion()
    Actor walkTarget = _walkTarget
    If ownWalkNumber != _walkNumber || !companion || !walkTarget
        Return
    EndIf
    bool isLootWalk = _isLootWalk
    Form lootItem = _lootItem
    ; This call only comes back when the companion has arrived, found no way or was sent somewhere else
    bool hasArrived = companion.PathToReference(walkTarget, WalkSpeed)
    If ownWalkNumber != _walkNumber
        ; A newer command has taken over in the meantime
        Return
    EndIf
    _walkTarget = None
    If isLootWalk
        _isLootWalk = false
        _lootItem = None
        FinishLoot(companion, walkTarget, lootItem, ownWalkNumber)
        Return
    EndIf
    If !hasArrived
        AddReport("You did not get to " + walkTarget.GetDisplayName() + ".")
        Debug.Notification("AI companion: did not get to " + walkTarget.GetDisplayName())
    EndIf
EndEvent

; A walk that is still running finds a new number when it comes back and then stays silent
Function EndWalk()
    _walkNumber += 1
    _walkTarget = None
    _isLootWalk = false
    _lootItem = None
EndFunction

; ----------------------------------------------------------------------- flee
; flee: the companion becomes cowardly, which is how the game makes a character keep out of fights and run from enemies

Function StartFleeing(Actor companion)
    If _fleeingActor == companion
        Return
    EndIf
    StopFleeing()
    _fleeingActor = companion
    _confidenceBeforeFlee = companion.GetBaseActorValue("Confidence")
    companion.SetActorValue("Confidence", ConfidenceCowardly)
EndFunction

; Gives whoever was retreating the old courage back
Function StopFleeing()
    If _fleeingActor
        _fleeingActor.SetActorValue("Confidence", _confidenceBeforeFlee)
        _fleeingActor = None
    EndIf
EndFunction

; ------------------------------------------------------------------ companion
; The AI plays whoever is the player's follower at the moment. The game keeps that follower in the
; "Follower" alias of its own quest DialogueFollower, so no reference ID has to be known here

DialogueFollowerScript Function GetFollowerQuest()
    If !_followerQuest
        _followerQuest = Game.GetFormFromFile(FollowerQuestFormId, FollowerQuestFile) as DialogueFollowerScript
    EndIf
    Return _followerQuest
EndFunction

Actor Function GetCompanion()
    DialogueFollowerScript followerQuest = GetFollowerQuest()
    If !followerQuest || !followerQuest.pFollowerAlias
        Return None
    EndIf
    Return followerQuest.pFollowerAlias.GetActorReference()
EndFunction

bool Function IsWaiting(Actor companion)
    Return companion.GetActorValue("WaitingForPlayer") > 0.0
EndFunction

; Same as choosing "Wait here" or "Follow me" in the follower's dialogue.
; Only call this for the actor returned by GetCompanion()
Function SetWaiting(Actor companion, bool shouldWait)
    DialogueFollowerScript followerQuest = GetFollowerQuest()
    If shouldWait
        followerQuest.FollowerWait()
    Else
        followerQuest.FollowerFollow()
    EndIf
    ; Without this the follower only changes behaviour when the game next rethinks its package
    companion.EvaluatePackage()
EndFunction

; -------------------------------------------------------------------- helpers

string Function GetLocationName(Actor player)
    string locationName = ""
    Location currentLocation = player.GetCurrentLocation()
    If currentLocation
        locationName = currentLocation.GetName()
    EndIf
    If locationName == ""
        Cell currentCell = player.GetParentCell()
        If currentCell
            locationName = currentCell.GetName()
        EndIf
    EndIf
    If locationName == ""
        WorldSpace currentWorld = player.GetWorldSpace()
        If currentWorld
            locationName = currentWorld.GetName()
        EndIf
    EndIf
    If locationName == ""
        locationName = "Unknown"
    EndIf
    Return locationName
EndFunction

; Rounds to whole meters. The cast cuts off the decimals, which is rounding down for the positive numbers here
int Function ToMeters(float gameUnits)
    Return (gameUnits / GameUnitsPerMeter + 0.5) as int
EndFunction

int Function GetHealthPercent(Actor target)
    Return (target.GetActorValuePercentage("Health") * 100.0 + 0.5) as int
EndFunction

; Yes and no travel as 1 and 0 inside the lists of numbers
int Function ToNumber(bool value)
    If value
        Return 1
    EndIf
    Return 0
EndFunction

; SKSE_HTTP refuses text that is not valid UTF-8 and then stores nothing at all
Function SetStringSafely(int handle, string keyName, string value)
    If !SKSE_HTTP.setString(handle, keyName, value)
        SKSE_HTTP.setString(handle, keyName, "unreadable")
    EndIf
EndFunction
