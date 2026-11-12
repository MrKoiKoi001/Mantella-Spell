Scriptname KI_MCP_Gefaehrte_Loop extends Quest
{Long polling loop between Skyrim and the companion server (companion_main.py in the Mantella fork).
The game can only ask and the server can only answer. So this script keeps one request open at all times.
The server holds it until the AI has a command, and every request carries the current game state.}

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
string Property ACTION_REPORT_STATE = "report_state" AutoReadOnly
string Property ACTION_FOLLOW = "follow" AutoReadOnly
string Property ACTION_WAIT = "wait" AutoReadOnly

; ------------------------------------------------------------------ variables

; Number of the newest request. The server sends it back, so replies to older requests can be told apart
int _pollId = 0
bool _isContactShown = false

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
    _isContactShown = false
    _pollId = Utility.RandomInt(1, 1000000)
    int[] noResults
    SendPoll(noResults)
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
    If replyType == REPLY_TYPE_COMMANDS
        resultHandles = RunCommands(SKSE_HTTP.getNestedDictionariesArray(typedDictionaryHandle, KEY_COMMANDS))
    EndIf
    SendPoll(resultHandles)
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
    SendPoll(noResults)
EndEvent

; -------------------------------------------------------------------- request

Function SendPoll(int[] resultHandles)
    _pollId += 1
    int ownPollId = _pollId

    int requestHandle = SKSE_HTTP.createDictionary()
    SKSE_HTTP.setInt(requestHandle, KEY_POLL_ID, ownPollId)
    SKSE_HTTP.setNestedDictionary(requestHandle, KEY_STATE, BuildState())
    If resultHandles.Length > 0
        SKSE_HTTP.setNestedDictionariesArray(requestHandle, KEY_RESULTS, resultHandles)
    EndIf
    SKSE_HTTP.sendLocalhostHttpRequest(requestHandle, ServerPort, ROUTE_GAME)

    RegisterForSingleUpdate(WatchdogSeconds)
EndFunction

int Function BuildState()
    Actor player = Game.GetPlayer()

    int stateHandle = SKSE_HTTP.createDictionary()
    SetStringSafely(stateHandle, "location", GetLocationName(player))
    SKSE_HTTP.setBool(stateHandle, "in_combat", player.IsInCombat())

    int playerHandle = SKSE_HTTP.createDictionary()
    SetStringSafely(playerHandle, "name", player.GetDisplayName())
    SKSE_HTTP.setString(playerHandle, "ref_id", FormIdToHex(player.GetFormID()))
    SKSE_HTTP.setInt(playerHandle, "health_percent", GetHealthPercent(player))
    SKSE_HTTP.setNestedDictionary(stateHandle, "player", playerHandle)

    ; No "companion" entry means: the player has no follower at the moment
    Actor companion = GetCompanion()
    If companion
        SKSE_HTTP.setNestedDictionary(stateHandle, "companion", BuildCompanionState(companion, player))
    EndIf

    Return stateHandle
EndFunction

int Function BuildCompanionState(Actor companion, Actor player)
    int companionHandle = SKSE_HTTP.createDictionary()
    SetStringSafely(companionHandle, "name", companion.GetDisplayName())
    SKSE_HTTP.setString(companionHandle, "ref_id", FormIdToHex(companion.GetFormID()))
    SKSE_HTTP.setInt(companionHandle, "health_percent", GetHealthPercent(companion))
    SKSE_HTTP.setBool(companionHandle, "dead", companion.IsDead())
    SKSE_HTTP.setBool(companionHandle, "in_combat", companion.IsInCombat())
    SKSE_HTTP.setBool(companionHandle, "waiting", IsWaiting(companion))
    ; Far away (eg left behind in another place) the game has no position worth measuring
    bool isNearby = companion.Is3DLoaded()
    SKSE_HTTP.setBool(companionHandle, "nearby", isNearby)
    If isNearby
        SKSE_HTTP.setInt(companionHandle, "distance_meters", Math.Floor(companion.GetDistance(player) / GameUnitsPerMeter + 0.5))
    EndIf
    Return companionHandle
EndFunction

; ------------------------------------------------------------------- commands

; Returns the handles of the results that go to the server with the next request
int[] Function RunCommands(int[] commandHandles)
    int resultCount = 0
    int index = 0
    While index < commandHandles.Length
        If SKSE_HTTP.getString(commandHandles[index], KEY_COMMAND_ACTION, "") != ACTION_REPORT_STATE
            resultCount += 1
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
    If actionName == ACTION_FOLLOW || actionName == ACTION_WAIT
        Actor companion = GetCompanion()
        If !companion
            resultText = "You have no character in the game yet. The player has to take a follower along first, then that follower is you."
        ElseIf companion.IsDead()
            resultText = "Your character is dead."
        ElseIf actionName == ACTION_FOLLOW
            SetWaiting(companion, false)
            isOk = true
            resultText = "You follow the player now."
        Else
            SetWaiting(companion, true)
            isOk = true
            resultText = "You wait here now."
        EndIf
    Else
        resultText = "The game mod cannot do '" + actionName + "' yet. So far it can do follow and wait."
    EndIf

    int resultHandle = SKSE_HTTP.createDictionary()
    SKSE_HTTP.setString(resultHandle, KEY_COMMAND_ID, SKSE_HTTP.getString(commandHandle, KEY_COMMAND_ID, ""))
    SKSE_HTTP.setBool(resultHandle, KEY_RESULT_OK, isOk)
    SKSE_HTTP.setString(resultHandle, KEY_RESULT_MESSAGE, resultText)
    Return resultHandle
EndFunction

; ------------------------------------------------------------------ companion
; The AI plays whoever is the player's follower at the moment. The game keeps that follower in the
; "Follower" alias of its own quest DialogueFollower, so no reference ID has to be known here

DialogueFollowerScript Function GetFollowerQuest()
    Return Game.GetFormFromFile(FollowerQuestFormId, FollowerQuestFile) as DialogueFollowerScript
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

int Function GetHealthPercent(Actor target)
    Return Math.Floor(target.GetActorValuePercentage("Health") * 100.0 + 0.5)
EndFunction

; SKSE_HTTP refuses text that is not valid UTF-8 and then stores nothing at all
Function SetStringSafely(int handle, string keyName, string value)
    If !SKSE_HTTP.setString(handle, keyName, value)
        SKSE_HTTP.setString(handle, keyName, "unreadable")
    EndIf
EndFunction

; Form IDs go to the server as eight hex digits, eg 00000014 for the player
string Function FormIdToHex(int formId)
    string hexDigits = "0123456789ABCDEF"
    string result = ""
    int shift = 28
    While shift >= 0
        int nibble = Math.LogicalAnd(Math.RightShift(formId, shift), 15)
        result += StringUtil.Substring(hexDigits, nibble, 1)
        shift -= 4
    EndWhile
    Return result
EndFunction
