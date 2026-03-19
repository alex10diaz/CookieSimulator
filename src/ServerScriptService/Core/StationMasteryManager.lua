-- StationMasteryManager (ModuleScript, ServerScriptService/Core)
-- Tracks per-station XP and levels for the 5 roles.
-- Roles: Mixer (mix), Baller (dough), Baker (oven), Glazer (frost), Decorator (dress)

local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Lazy-require PlayerDataManager to avoid circular load order issues
local function getPDM()
    return require(ServerScriptService:WaitForChild("Core"):WaitForChild("PlayerDataManager"))
end
local RemoteManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))

-- ── CONSTANTS ──────────────────────────────────────────────────────────────────
-- Cumulative XP needed to advance FROM level N to level N+1 (index = current level)
local THRESHOLDS = { 400, 800, 1500, 3000, 5500, 9000, 14000, 18000, 22000 }
local MAX_LEVEL  = 10

local STATION_TO_ROLE = {
    mix   = "Mixer",
    dough = "Baller",
    oven  = "Baker",
    frost = "Glazer",
    dress = "Decorator",
}

-- Coin rewards granted when a player reaches a given level
local COIN_REWARDS = { [3]=300, [6]=800, [8]=1500, [9]=2500, [10]=5000 }

-- ── MODULE ─────────────────────────────────────────────────────────────────────
local StationMasteryManager = {}

local function getRole(player, role)
    local p = getPDM().GetData(player)
    if not p or not p.mastery then return 1, 0 end
    return p.mastery[role .. "Level"] or 1, p.mastery[role .. "XP"] or 0
end

local function setRole(player, role, level, xp)
    local p = getPDM().GetData(player)
    if not p then return end
    if not p.mastery then p.mastery = {} end
    p.mastery[role .. "Level"] = level
    p.mastery[role .. "XP"]    = xp
end

-- Called by MinigameServer after each station score is recorded.
-- score is 0–100 integer.
function StationMasteryManager.AwardFromScore(player, stationName, score)
    local role = STATION_TO_ROLE[stationName]
    if not role then return end
    local xp = (score >= 95) and 25 or 15
    StationMasteryManager.AddMasteryXP(player, role, xp)
end

function StationMasteryManager.AddMasteryXP(player, role, amount)
    local level, xp = getRole(player, role)
    if level >= MAX_LEVEL then return end
    xp += amount

    while level < MAX_LEVEL do
        local needed = THRESHOLDS[level]
        if needed and xp >= needed then
            xp    -= needed
            level += 1
            local coins = COIN_REWARDS[level]
            if coins then getPDM().AddCoins(player, coins) end
            RemoteManager.Get("MasteryLevelUp"):FireClient(player, {
                role  = role,
                level = level,
                coins = coins or 0,
            })
            print(string.format("[StationMastery] %s %s -> Level %d%s",
                player.Name, role, level,
                coins and (" +" .. coins .. " coins") or ""))
        else
            break
        end
    end

    setRole(player, role, level, xp)
end

-- Returns { Mixer={level,xp,nextXP}, ... } for a player (for summary/HUD use)
function StationMasteryManager.GetMastery(player)
    local result = {}
    for _, role in ipairs({"Mixer","Baller","Baker","Glazer","Decorator"}) do
        local level, xp = getRole(player, role)
        result[role] = {
            level  = level,
            xp     = xp,
            nextXP = (level < MAX_LEVEL) and (THRESHOLDS[level] or 0) or 0,
        }
    end
    return result
end

-- Returns 0 / 0.05 / 0.08 / 0.10 based on level (for mechanical bonus hooks)
function StationMasteryManager.GetBonus(player, role)
    local level = getRole(player, role)
    if level >= MAX_LEVEL then return 0.10
    elseif level >= 7    then return 0.08
    elseif level >= 5    then return 0.05
    else                      return 0
    end
end

return StationMasteryManager
