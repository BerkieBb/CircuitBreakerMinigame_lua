--#region Static Variables

HasCircuitFailed = false
local hasCircuitCompleted = false
local gameBounds = {
    vec2(0.159, 0.153), -- Top Left
    vec2(0.159, 0.848), -- Bottom Left
    vec2(0.841, 0.848), -- Bottom Right
    vec2(0.841, 0.153) -- Top Right
}
local textureDictionaries = {'MPCircuitHack', 'MPCircuitHack2', 'MPCircuitHack3'}
local _gameEndTime
local _gameStartTime
local _initCursorSpeed
local _cursorSpeed
local _illegalAreas
local _genericPorts
local _cursor
local _scaleform
local _currentDifficulty
local _currentLevelNumber
local _isEndScreenActive
local hackingKitVersionNumber
local isHackingKitDisconnected
local isDisconnectedScreenActive
local lastDisconnectCheckTime
local reconnectingTime
local backgroundSoundId
local trailSoundId
local startingHealth
local debugPortHeading = 0

--#endregion Static Variables

--#region Changeable Variables

local defaultDelayStartTimeMs <const> = 300
local minDelayEndGameTimeMs <const> = 5000
local maxDelayEndGameTimeMs <const> = 5000
local defaultMinReconnectTimeMs <const> = 3000
local defaultMaxReconnectTimeMs <const> = 30000
local maxDisconnectChance <const> = 0.9
local minDisconnectCheckRateMs <const> = 500
local minCursorSpeed <const> = 0.00085
local maxCursorSpeed <const> = 0.01
local debuggingMapPosition = false

---Checks if you have the hacking kit item, the item name must have a number in it, ranging from 1 to 3
---@return boolean
local function doesPlayerHaveHackingKit()
    return true
end

---Returns the version number of the hacking kit item, number ranging from 1 to 3
---@return integer
local function getHackingKitVersionNumber()
    --local versionNumber = string.match(itemName, '%d+')
    return math.random(1, 3)
end

--#endregion Changeable Variables

---Gets the cursor maximum points.
---@param cursorCoords vector2
---@param cursorHeadSize number
---@return vector2[]
local function getCursorMaxPoints(cursorCoords, cursorHeadSize)
    cursorHeadSize /= 2
    local headPoint1 = vec2(cursorCoords.x - cursorHeadSize, cursorCoords.y)
    local headPoint2 = vec2(cursorCoords.x - cursorHeadSize, cursorCoords.y)
    local headPoint3 = vec2(cursorCoords.x, cursorCoords.y - cursorHeadSize)
    local headPoint4 = vec2(cursorCoords.x, cursorCoords.y + cursorHeadSize)

    return {headPoint1, headPoint2, headPoint3, headPoint4, cursorCoords}
end

---Determines whether the cursor is out of the specified poly bounds
---@param polyBounds vector2[][]
---@param mapBounds vector2[]
---@return boolean
local function isCursorOutOfBounds(polyBounds, mapBounds)
    local headPts = getCursorMaxPoints(_cursor.position, _cursor.cursorHeadSize + -0.375 * _cursor.cursorHeadSize)

    for i = 1, #headPts do
        for i2 = 1, #polyBounds do
            if IsInPoly(polyBounds[i2], headPts[i]) then
                return true
            end
        end

        if not IsInPoly(mapBounds, headPts[i]) then
            return true
        end
    end

    return false
end

local function disposeScaleform()
    if not _scaleform then return end

    SetScaleformMovieAsNoLongerNeeded(_scaleform)
    _scaleform = nil

    Wait(50)
end

local function disposeTextureDictionaries()
    for i = 1, #textureDictionaries do
        SetStreamedTextureDictAsNoLongerNeeded(textureDictionaries[i])
    end
end

local function disposeSounds()
    StopSound(trailSoundId)
    StopSound(backgroundSoundId)

    if backgroundSoundId > 0 then
        ReleaseSoundId(backgroundSoundId)
    end

    if trailSoundId > 0 then
        ReleaseSoundId(trailSoundId)
    end
end

local function dispose()
    disposeSounds()
    disposeTextureDictionaries()
    disposeScaleform()
end

local function endGame()
    dispose()
end

---Shows the display scaleform.
---@param title string
---@param msg string
---@param r integer
---@param g integer
---@param b integer
---@param stagePassed boolean
local function showDisplayScaleform(title, msg, r, g, b, stagePassed)
    if not _scaleform then return end

    BeginScaleformMovieMethod(_scaleform, 'SET_DISPLAY')

    ScaleformMovieMethodAddParamInt(0)
    ScaleformMovieMethodAddParamTextureNameString(title)
    ScaleformMovieMethodAddParamTextureNameString(msg)
    ScaleformMovieMethodAddParamInt(r)
    ScaleformMovieMethodAddParamInt(g)
    ScaleformMovieMethodAddParamInt(b)
    ScaleformMovieMethodAddParamBool(stagePassed)

    EndScaleformMovieMethod()
end

local function setScaleform()
    disposeScaleform()
    _scaleform = RequestScaleformMovie('HACKING_MESSAGE')

    local loadAttempt = 0
    while not HasScaleformMovieLoaded(_scaleform) do
        Wait(5)
        loadAttempt += 1
        if loadAttempt > 50 then
            break
        end
    end
end

local function initializeResources()
    for i = 1, #textureDictionaries do
        RequestStreamedTextureDict(textureDictionaries[i], false)
    end

    RequestScriptAudioBank('DLC_MPHEIST/HEIST_HACK_SNAKE', false)

    local timeout = GetGameTimer() + 5000
    while GetGameTimer() - timeout < 0 do
        local allLoaded = true
        for i = 1, #textureDictionaries do
            if not HasStreamedTextureDictLoaded(textureDictionaries[i]) then
                allLoaded = false
            end
        end
        if allLoaded then
            break
        end

        Wait(100)
    end

    for i = 1, #textureDictionaries do
        if not HasStreamedTextureDictLoaded(textureDictionaries[i]) then
            error(('Failed to load texture dictionary %s'):format(textureDictionaries[i]))
            break
        end
    end

    setScaleform()
    backgroundSoundId = GetSoundId()
    trailSoundId = GetSoundId()
end

local function disableControls()
    DisableControlAction(0, 34, true) -- INPUT_MOVE_LEFT_ONLY
    DisableControlAction(0, 35, true) -- INPUT_MOVE_RIGHT_ONLY
    DisableControlAction(0, 32, true) -- INPUT_MOVE_UP_ONLY
    DisableControlAction(0, 33, true) -- INPUT_MOVE_DOWN_ONLY

    DisableControlAction(0, 24, true) -- INPUT_ATTACK
	DisableControlAction(0, 257, true) -- INPUT_ATTACK2
	DisableControlAction(0, 25, true) -- INPUT_AIM
	DisableControlAction(0, 53, true) -- INPUT_WEAPON_SPECIAL
	DisableControlAction(0, 54, true) -- INPUT_WEAPON_SPECIAL_TWO
	DisableControlAction(0, 58, true) -- INPUT_THROW_GRENADE
	N_0xb885852c39cc265d() -- DISABLE_PLAYER_THROW_GRENADE_WHILE_USING_GUN
	DisableControlAction(0, 143, true) -- INPUT_MELEE_BLOCK
	DisableControlAction(0, 47, true) -- INPUT_DETONATE
	DisableControlAction(0, 38, true) -- INPUT_PICKUP
	DisableControlAction(0, 69, true) -- INPUT_VEH_ATTACK
	DisableControlAction(0, 70, true) -- INPUT_VEH_ATTACK2
	DisableControlAction(0, 68, true) -- INPUT_VEH_AIM
	DisableControlAction(0, 114, true) -- INPUT_VEH_FLY_ATTACK
	DisableControlAction(0, 92, true) -- INPUT_VEH_PASSENGER_ATTACK
	DisableControlAction(0, 99, true) -- INPUT_VEH_SELECT_NEXT_WEAPON
	DisableControlAction(0, 115, true) -- INPUT_VEH_FLY_SELECT_NEXT_WEAPON

    HudWeaponWheelIgnoreSelection()
    HideHudComponentThisFrame(19) -- WEAPON_WHEEL
    DisableControlAction(0, 37, true) -- INPUT_SELECT_WEAPON
    DisableControlAction(0, 199, true) -- INPUT_FRONTEND_PAUSE
end

---@param delayMs integer
local function playStartSound(delayMs)
    Wait(delayMs)
    PlaySoundFrontend(-1, 'Start', 'DLC_HEIST_HACKING_SNAKE_SOUNDS', true)
    PlaySoundFrontend(trailSoundId, 'Trail_Custom', 'DLC_HEIST_HACKING_SNAKE_SOUNDS', true)
end

local function drawCursorAndPortSprites()
    _cursor:DrawCursor()
    _cursor:DrawTailHistory()

    _genericPorts:DrawPorts()
end

---@param currentMap integer
local function drawMapSprite(currentMap)
    local levelTextureDict = currentMap > 3 and 'MPCircuitHack3' or 'MPCircuitHack2'
    DrawSprite(levelTextureDict, ('CBLevel%s'):format(_currentLevelNumber), 0.5, 0.5, 1, 1, 0, 255, 255, 255, 255)
end

---@param currentDifficulty Difficulty
---@return integer
local function getDisconnectCheckRateMsFromDifficulty(currentDifficulty)
    if currentDifficulty == Difficulty.Beginner then
        return 10000
    elseif currentDifficulty == Difficulty.Easy then
        return 2000
    elseif currentDifficulty == Difficulty.Medium then
        return 1000
    elseif currentDifficulty == Difficulty.Hard then
        return 500
    end

    return 10000
end

---@param currentDifficulty Difficulty
---@return integer
local function getDisconnectChanceFromDifficulty(currentDifficulty)
    if currentDifficulty == Difficulty.Beginner then
        return 0
    elseif currentDifficulty == Difficulty.Easy then
        return 0.15
    elseif currentDifficulty == Difficulty.Medium then
        return 0.30
    elseif currentDifficulty == Difficulty.Hard then
        return 0.45
    end

    return 0
end

---@param currentDifficulty Difficulty
---@return number
local function getCursorSpeedFromDifficulty(currentDifficulty)
    if currentDifficulty == Difficulty.Beginner then
        return 0.00085
    elseif currentDifficulty == Difficulty.Easy then
        return 0.002
    elseif currentDifficulty == Difficulty.Medium then
        return 0.004
    elseif currentDifficulty == Difficulty.Hard then
        return 0.006
    end

    return 0.00085
end

---@param currentDifficulty Difficulty
---@return number
local function getMaxSpeedIncreaseOnReconnect(currentDifficulty)
    if currentDifficulty == Difficulty.Beginner then
        return 0.002
    elseif currentDifficulty == Difficulty.Easy then
        return 0.004
    elseif currentDifficulty == Difficulty.Medium then
        return 0.006
    elseif currentDifficulty == Difficulty.Hard then
        return 0.01
    end

    return 0.002
end

---@param currentDifficulty Difficulty
---@return number
local function getCursorSpeedOnReconnect(currentDifficulty)
    if hackingKitVersionNumber == 3 then return _cursorSpeed end

    local maxSpeed = getMaxSpeedIncreaseOnReconnect(currentDifficulty) * 100000
    local speedDelta = math.random(0, math.round(maxSpeed * 0.25, -1)) / 100000
    if math.random() > 0.75 then
        speedDelta *= -1
    end

    return math.clamp(_cursorSpeed + speedDelta, _initCursorSpeed, maxSpeed)
end

local function finishReconnection()
    PlaySoundFrontend(-1, 'Start', 'DLC_HEIST_HACKING_SNAKE_SOUNDS', true)
    setScaleform()
    isHackingKitDisconnected = false
    lastDisconnectCheckTime = GetGameTimer()
    _cursorSpeed = getCursorSpeedOnReconnect(_currentDifficulty)
end

---@return number
local function applyHackingKitBonusToCursorSpeed()
    return hackingKitVersionNumber == 3 and math.random(0, 2000) / 100000 or  0
end

---@return number
local function applyHackingKitBonusToReconnectTime()
    return hackingKitVersionNumber == 2 and -2000 or 0
end

---@return number
local function applyHackingKitBonusToDisconnectChance()
    return hackingKitVersionNumber == 2 and -0.15 or hackingKitVersionNumber == 3 and -0.2 or 0
end

---@return number
local function applyHackingKitBonusToDisconnectCheckRate()
    return hackingKitVersionNumber == 3 and 3000 or 0
end

---@param minReconnectTimeMs integer
---@param maxReconnectTimeMs integer
local function startReconnection(minReconnectTimeMs, maxReconnectTimeMs)
    PlaySoundFrontend(-1, 'Power_Down', 'DLC_HEIST_HACKING_SNAKE_SOUNDS', true)

    showDisplayScaleform('CONNECTION LOST', 'Reconnecting...', 188, 49, 43, false)

    local reconnectTime = math.random(minReconnectTimeMs, maxReconnectTimeMs) + applyHackingKitBonusToReconnectTime()
    reconnectingTime = GetGameTimer() + math.clamp(reconnectTime, 0, reconnectTime)
end

---@param disconnectChance number
---@param disconnectCheckRateMs number
local function checkIfHackingDisconnected(disconnectChance, disconnectCheckRateMs)
    if GetGameTimer() - (lastDisconnectCheckTime + disconnectCheckRateMs + applyHackingKitBonusToDisconnectCheckRate()) < 0 then return end

    disconnectChance += applyHackingKitBonusToDisconnectChance()
    isHackingKitDisconnected = math.random() < disconnectChance
    lastDisconnectCheckTime = GetGameTimer()
end

local function showFailureScreenAndPlaySound()
    PlaySoundFrontend(-1, 'Crash', 'DLC_HEIST_HACKING_SNAKE_SOUNDS', true)
    StopSound(trailSoundId)
    showDisplayScaleform('CIRCUIT FAILED', 'Security Tunnel Detected', 188, 49, 43, false)
end

local function showSuccessScreenAndPlaySound()
    PlaySoundFrontend(-1, 'Goal', 'DLC_HEIST_HACKING_SNAKE_SOUNDS', true)
    StopSound(trailSoundId)
    showDisplayScaleform('CIRCUIT COMPLETE', 'Decryption Execution x86 Tunneling', 45, 203, 134, true)
end

---@param cursorSpeed number
local function initializeCursorSpeed(cursorSpeed)
    cursorSpeed = math.clamp(cursorSpeed - applyHackingKitBonusToCursorSpeed(), 0.001, cursorSpeed)
    _initCursorSpeed = cursorSpeed
    _cursorSpeed = cursorSpeed
end

---@param levelNumber integer
---@param difficultyLevel Difficulty
---@param cursorSpeed number
---@param delayStartMs integer
local function initializeLevelVariables(levelNumber, difficultyLevel, cursorSpeed, delayStartMs)
    HasCircuitFailed = false
    hasCircuitCompleted = false
    _isEndScreenActive = false
    isHackingKitDisconnected = false
    hackingKitVersionNumber = getHackingKitVersionNumber()
    _currentLevelNumber = levelNumber
    _illegalAreas = GetBoxBounds(levelNumber)
    _genericPorts = newGeneric(levelNumber)
    _cursor = newCursor(_genericPorts)
    initializeCursorSpeed(cursorSpeed)
    _currentDifficulty = difficultyLevel
    _gameStartTime = GetGameTimer()
    lastDisconnectCheckTime = GetGameTimer() + delayStartMs
    startingHealth = GetEntityHealth(PlayerPedId())
end

---@return boolean
local function isPlayerTakingDamage()
    local health = GetEntityHealth(PlayerPedId())
    if health < startingHealth then
        return true
    end

    if health > startingHealth then
        startingHealth = health
    end

    return false
end

---@param levelNumber integer
---@param difficultyLevel Difficulty
---@param cursorSpeed number
---@param delayStartMs integer
---@param minFailureDelayTimeMs integer
---@param maxFailureDelayTimeMs integer
---@param disconnectChance number
---@param disconnectCheckRateMs integer
---@param minReconnectTimeMs integer
---@param maxReconnectTimeMs integer
---@return GameStatus
local function runMinigameTask(levelNumber, difficultyLevel, cursorSpeed, delayStartMs, minFailureDelayTimeMs, maxFailureDelayTimeMs, disconnectChance, disconnectCheckRateMs, minReconnectTimeMs, maxReconnectTimeMs)
    if not NetworkIsSessionStarted() then
        Wait(1000)
        endGame()
        return GameStatus.FailedToStart
    end

    if not doesPlayerHaveHackingKit() then return GameStatus.MissingHackKit end

    initializeResources()

    PlaySoundFrontend(backgroundSoundId, 'Background', 'DLC_HEIST_HACKING_SNAKE_SOUNDS', true)
    playStartSound(delayStartMs)

    initializeLevelVariables(levelNumber, difficultyLevel, cursorSpeed, delayStartMs)

    local debugCursorSpeed = 0.0015
    while true do
        if isPlayerTakingDamage() then return GameStatus.TakingDamage end

        if IsControlPressed(0, 44) and not HasCircuitFailed then -- INPUT_COVER
            endGame()
            return GameStatus.PlayerQuit
        end

        drawMapSprite(_currentLevelNumber)
        disableControls()

        if debuggingMapPosition then
            local newDirection = GetDebugCursorDirectionInput()
            debugCursorSpeed += GetDebugCursorSpeedInput()
            if newDirection >= 0 then
                _cursor:DebugCursorPosition(newDirection, debugCursorSpeed)
            end

            debugPortHeading = GetPortDebugHeading(debugPortHeading)
            DebugPortSprite(_cursor.position, debugPortHeading)

            if IsControlJustPressed(0, 38) then -- INPUT_PICKUP
                print(('vec2(%s, %s),'):format(cursor.position.x, cursor.position.y))
            end

            Wait(0)

            goto skipRest
        end

        drawCursorAndPortSprites()
        DrawScaleformMovieFullscreen(_scaleform, 255, 255, 255, 255, 0)

        if not _isEndScreenActive and _genericPorts:IsCursorInGameWinningPosition(_cursor.position) then
            hasCircuitCompleted = true
            _gameEndTime = GetGameTimer() + minDelayEndGameTimeMs

            showSuccessScreenAndPlaySound()
            _isEndScreenActive = true
        elseif not _isEndScreenActive and isCursorOutOfBounds(_illegalAreas, gameBounds) or _genericPorts:IsCollisionWithPort(_cursor.position) or _cursor:CheckTailCollision() then
            HasCircuitFailed = true
            if _cursor.isAlive then
                _cursor.isAlive = false
                _cursor:StartCursorDeathAnimation()
            end

            if not _isEndScreenActive and not _cursor.isVisible then
                showFailureScreenAndPlaySound()
                _gameEndTime = GetGameTimer() + math.random(minFailureDelayTimeMs, maxFailureDelayTimeMs)
                _isEndScreenActive = true
            end
        elseif not _isEndScreenActive and isHackingKitDisconnected then
            if not isDisconnectedScreenActive then
                startReconnection(minReconnectTimeMs, maxReconnectTimeMs)
                isDisconnectedScreenActive = true
            end

            if isDisconnectedScreenActive and GetGameTimer() - reconnectingTime >= 0 then
                finishReconnection()
                isDisconnectedScreenActive = false
            end
        end

        if not isHackingKitDisconnected and disconnectChance > 0 then
            checkIfHackingDisconnected(disconnectChance, disconnectCheckRateMs)
        end

        if GetGameTimer() - _gameStartTime + delayStartMs >= 0 and not _isEndScreenActive and _cursor.isAlive and not isHackingKitDisconnected then
            _cursor:GetCursorInputFromPlayer()
            _cursor:MoveCursor(_cursorSpeed)
        end

        if _isEndScreenActive and (HasCircuitFailed or hasCircuitCompleted) then
            if GetGameTimer() - _gameEndTime >= 0 then
                StopSound(backgroundSoundId)

                if hasCircuitCompleted then
                    PlaySoundFrontend(-1, 'Success', 'DLC_HEIST_HACKING_SNAKE_SOUNDS', true)
                end

                endGame()
                return hasCircuitCompleted and GameStatus.Success or GameStatus.Failure
            end
        end

        :: skipRest ::

        Wait(0)
    end
end

---@param levelNumber integer 1 - 6
---@param difficultyLevel Difficulty 0 - 3, take a look at globals.lua
---@param cursorSpeed number 0.0085 - 0.01, the limits of this can be redefined at the top of circuit.lua
---@param delayStartMs integer How long to delay the start in milliseconds
---@param minFailureDelayTimeMs integer How long to delay the failure screen at minimal in milliseconds
---@param maxFailureDelayTimeMs integer How long to delay the failure screen at the max in milliseconds
---@param disconnectChance number A decimal number between 0 and 1, the chance that it disconnects
---@param disconnectCheckRateMs integer The amount of time in milliseconds to check if it should disconnect using the disconnectChance
---@param minReconnectTimeMs integer The time in milliseconds it takes at minimal to reconnect after disconnecting by chance
---@param maxReconnectTimeMs integer The time in milliseconds it takes at the max to reconnect after disconnecting by chance
---@return GameStatus
local function runMiniGame(levelNumber, difficultyLevel, cursorSpeed, delayStartMs, minFailureDelayTimeMs, maxFailureDelayTimeMs, disconnectChance, disconnectCheckRateMs, minReconnectTimeMs, maxReconnectTimeMs)
    levelNumber = math.clamp(levelNumber, 1, 6)
    difficultyLevel = math.clamp(difficultyLevel, 0, 3)
    cursorSpeed = math.clamp(cursorSpeed, minCursorSpeed, maxCursorSpeed)
    delayStartMs = math.clamp(delayStartMs, 1000, 60000)
    minFailureDelayTimeMs = math.clamp(minFailureDelayTimeMs, minDelayEndGameTimeMs, maxFailureDelayTimeMs)
    maxFailureDelayTimeMs = math.clamp(maxFailureDelayTimeMs, minDelayEndGameTimeMs, maxFailureDelayTimeMs > minFailureDelayTimeMs and maxFailureDelayTimeMs or minFailureDelayTimeMs + 1)
    disconnectChance = math.clamp(disconnectChance, 0, maxDisconnectChance)
    disconnectCheckRateMs = math.clamp(disconnectCheckRateMs, minDisconnectCheckRateMs, disconnectCheckRateMs)
    minReconnectTimeMs = math.clamp(minReconnectTimeMs, defaultMinReconnectTimeMs, maxReconnectTimeMs)
    maxReconnectTimeMs = math.clamp(maxReconnectTimeMs, minReconnectTimeMs + 1, defaultMaxReconnectTimeMs)
    return runMinigameTask(levelNumber, difficultyLevel, cursorSpeed, delayStartMs, minFailureDelayTimeMs, maxFailureDelayTimeMs, disconnectChance, disconnectCheckRateMs, minReconnectTimeMs, maxReconnectTimeMs)
end

exports('run', runMiniGame)

---@param levelNumber integer 1 - 6
---@param difficultyLevel Difficulty 0 - 3, take a look at globals.lua
---@return GameStatus
local function runDefaultMiniGameFromDifficulty(levelNumber, difficultyLevel)
    levelNumber = math.clamp(levelNumber, 1, 6)
    difficultyLevel = math.clamp(difficultyLevel, 0, 3)
    return runMiniGame(levelNumber, difficultyLevel, getCursorSpeedFromDifficulty(difficultyLevel), defaultDelayStartTimeMs, minDelayEndGameTimeMs, maxDelayEndGameTimeMs, getDisconnectChanceFromDifficulty(difficultyLevel), getDisconnectCheckRateMsFromDifficulty(difficultyLevel), defaultMinReconnectTimeMs, defaultMaxReconnectTimeMs)
end

exports('runDefaultWithDifficulty', runDefaultMiniGameFromDifficulty)

---@return GameStatus
local function runDefaultMiniGame()
    local levelNumber = math.random(1, 6)
    local difficultyLevel = math.random(0, 3)
    return runMiniGame(levelNumber, difficultyLevel, getCursorSpeedFromDifficulty(difficultyLevel), defaultDelayStartTimeMs, minDelayEndGameTimeMs, maxDelayEndGameTimeMs, getDisconnectChanceFromDifficulty(difficultyLevel), getDisconnectCheckRateMsFromDifficulty(difficultyLevel), defaultMinReconnectTimeMs, defaultMaxReconnectTimeMs)
end

exports('runDefaultRandom', runDefaultMiniGame)