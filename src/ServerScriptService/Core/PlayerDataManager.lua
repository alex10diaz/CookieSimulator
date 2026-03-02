-- ServerScriptService/Core/PlayerDataManager (ModuleScript)
-- Handles in-memory player profiles + DataStore persistence.
-- Load on PlayerAdded, save on PlayerRemoving.

local Players           = game:GetService("Players")
local DataStoreService  = game:GetService("DataStoreService")

local playerStore = DataStoreService:GetDataStore("PlayerData_v1")

local DEFAULT_PROFILE = {
    coins             = 0,
    xp                = 0,
    level             = 1,
    comboStreak       = 0,
    ordersCompleted   = 0,
    perfectOrders     = 0,
    failedOrders      = 0,
    tutorialCompleted = false,
    rebirths          = 0,
    unlockedRecipes   = {"chocolate_chip"},
    ownedMachines     = {},
    ratingScore       = 0,
    stats             = { fastestOrderTime = math.huge },
}

local profiles = {}  -- userId -> profile table

-- ── HELPERS ────────────────────────────────────────────────────
local function newProfile()
    local p = {}
    for k, v in pairs(DEFAULT_PROFILE) do
        if type(v) == "table" then
            local copy = {}
            for k2, v2 in pairs(v) do copy[k2] = v2 end
            p[k] = copy
        else
            p[k] = v
        end
    end
    return p
end

local function mergeDefaults(saved)
    -- Fill any missing keys added after a player's first save
    local p = newProfile()
    for k, v in pairs(saved) do
        p[k] = v
    end
    return p
end

-- ── DATASTORE ──────────────────────────────────────────────────
local function loadProfile(userId)
    local key = "Player_" .. userId
    local ok, result = pcall(function()
        return playerStore:GetAsync(key)
    end)
    if ok and result then
        return mergeDefaults(result)
    elseif not ok then
        warn("[PlayerDataManager] Load failed for", userId, result)
    end
    return newProfile()
end

local function saveProfile(userId)
    local profile = profiles[userId]
    if not profile then return end
    local key = "Player_" .. userId
    local toSave = {}
    for k, v in pairs(profile) do
        if type(v) ~= "function" then
            toSave[k] = v
        end
    end
    -- math.huge is not JSON-safe; replace with 0
    if toSave.stats and toSave.stats.fastestOrderTime == math.huge then
        toSave.stats = { fastestOrderTime = 0 }
    end
    local ok, err = pcall(function()
        playerStore:SetAsync(key, toSave)
    end)
    if not ok then
        warn("[PlayerDataManager] Save failed for", userId, err)
    else
        print("[PlayerDataManager] Saved profile for userId", userId)
    end
end

-- ── MODULE API ─────────────────────────────────────────────────
local PlayerDataManager = {}

function PlayerDataManager.GetData(player)
    return profiles[player.UserId]
end

function PlayerDataManager.AddCoins(player, amount)
    local p = profiles[player.UserId]
    if not p then return 0 end
    p.coins = math.max(0, p.coins + amount)
    return p.coins
end

function PlayerDataManager.AddXP(player, amount)
    local p = profiles[player.UserId]
    if not p then return 0, 1 end
    p.xp += amount
    local required = math.floor(100 * (p.level ^ 1.35))
    while p.xp >= required do
        p.xp    -= required
        p.level += 1
        required = math.floor(100 * (p.level ^ 1.35))
        print("[PlayerDataManager] " .. player.Name .. " leveled up to " .. p.level)
    end
    return p.xp, p.level
end

function PlayerDataManager.IncrementCombo(player)
    local p = profiles[player.UserId]
    if not p then return 0 end
    p.comboStreak = math.min(p.comboStreak + 1, 20)
    return p.comboStreak
end

function PlayerDataManager.ResetCombo(player)
    local p = profiles[player.UserId]
    if p then p.comboStreak = 0 end
end

function PlayerDataManager.RecordOrderComplete(player, isPerfect)
    local p = profiles[player.UserId]
    if not p then return end
    p.ordersCompleted += 1
    if isPerfect then p.perfectOrders += 1 end
end

function PlayerDataManager.SetTutorialCompleted(player)
    local p = profiles[player.UserId]
    if p then p.tutorialCompleted = true end
end

-- ── LIFECYCLE ──────────────────────────────────────────────────
Players.PlayerAdded:Connect(function(player)
    profiles[player.UserId] = loadProfile(player.UserId)
    print("[PlayerDataManager] Loaded profile for " .. player.Name
        .. " | coins=" .. profiles[player.UserId].coins
        .. " level=" .. profiles[player.UserId].level)
end)

Players.PlayerRemoving:Connect(function(player)
    saveProfile(player.UserId)
    profiles[player.UserId] = nil
end)

-- Handle players already in game when first required
for _, player in ipairs(Players:GetPlayers()) do
    if not profiles[player.UserId] then
        profiles[player.UserId] = loadProfile(player.UserId)
    end
end

print("[PlayerDataManager] Ready (DataStore: PlayerData_v1).")
return PlayerDataManager
