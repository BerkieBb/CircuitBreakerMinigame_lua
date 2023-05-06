---@enum Difficulty
Difficulty = {
    Beginner = 0,
    Easy = 1,
    Medium = 2,
    Hard = 3
}

---@enum Directions
Directions = {
    Up = 0,
    Down = 1,
    Left = 2,
    Right = 3
}

---@enum GameStatus
GameStatus = {
    Error = -5,
    FailedToStart = -4,
    MissingHackKit = -3,
    TakingDamage = -2,
    Failure = -1,
    PlayerQuit = 0,
    Success = 1
}

---@enum PortPositionType
PortPositionType = {
    Start = 0,
    Finish = 1
}

---Clamp a value to a min and max value
---@param value number
---@param min number
---@param max number
---@return number
function math.clamp(value, min, max)
    return value < min and min or value > max and max or value
end

---Round a number to the specified decimal point
---@param number number
---@param decimalPoint number
---@return number
function math.round(number, decimalPoint)
    local multiplier = 10 ^ (decimalPoint or 0)
    return math.floor(number * multiplier + 0.5) / multiplier
end