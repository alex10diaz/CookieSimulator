-- ServerScriptService/Core/PlayerDataManager (ModuleScript)
-- Handles in-memory player profiles + DataStore persistence.
-- Load on PlayerAdded, save on PlayerRemoving.

local Players           = game:GetService("Players")
local DataStoreService  = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local playerStore = DataStoreService:GetDataStore("PlayerData_v1")

-- Lazy-loaded to avoid require-at-load-time issues
local function getRemoteManager()
    return require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
end

local DEFAULT_PROFILE = {
    coins             = 0,
    xp                = 0,
    level             = 1,
    comboStreak       = 0,
    ordersCompleted   = 0,
    perfectOrders     = 0,
    failedOrders      = 0,
    cookiesSold       = 0,   -- lifetime individual cookies sold (sum of packSizes)
    tutorialCompleted = false,
    rebirths          = 0,
    unlockedRecipes   = {"chocolate_chip", "snickerdoodle", "pink_sugar", "birthday_cake"},
    ownedMachines     = {},
    ratingScore       = 0,
    stats             = { fastestOrderTime = math.huge },
    unlockedStations  = {},  -- upgrade IDs owned by this player
    unlockedCosmetics = {},  -- cosmetic IDs owned by this player
    bakeryName        = "",  -- set once on first join
    bakeryXP          = 0,
    bakeryLevel       = 1,
    dailyChallenges = {
        date     = "",            -- "YYYY-DDD" UTC date key, e.g. "2026-069"
        progress = {0, 0, 0},   -- progress values for each of the 3 challenges
        claimed  = {false, false, false},  -- whether reward was claimed
    },
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

local function deepCopy(t)
    local copy = {}
    for k, v in pairs(t) do
        copy[k] = type(v) == "table" and deepCopy(v) or v
    end
    return copy
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
    local toSave = deepCopy(profile)
    -- math.huge is not JSON-safe; replace with 0
    if toSave.stats and toSave.stats.fastestOrderTime == math.huge then
        toSave.stats.fastestOrderTime = 0
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

function PlayerDataManager.RecordOrderComplete(player, isPerfect, cookieCount)
    local p = profiles[player.UserId]
    if not p then return end
    p.ordersCompleted += 1
    p.cookiesSold     += (cookieCount or 1)
    if isPerfect then p.perfectOrders += 1 end
end

function PlayerDataManager.SetTutorialCompleted(player)
    local p = profiles[player.UserId]
    if p then p.tutorialCompleted = true end
end

function PlayerDataManager.DeductCoins(player, amount)
    local p = profiles[player.UserId]
    if not p then return false, 0 end
    if p.coins < amount then return false, p.coins end
    p.coins = p.coins - amount
    return true, p.coins
end

function PlayerDataManager.AddUnlock(player, itemId, itemType)
    -- itemType: "station" or "cosmetic"
    local p = profiles[player.UserId]
    if not p then return end
    local list = itemType == "cosmetic" and p.unlockedCosmetics or p.unlockedStations
    for _, id in ipairs(list) do
        if id == itemId then return end  -- already owned
    end
    table.insert(list, itemId)
end

function PlayerDataManager.GetUnlocks(player)
    local p = profiles[player.UserId]
    if not p then return {}, {} end
    return p.unlockedStations, p.unlockedCosmetics
end

function PlayerDataManager.GetOwnedCookies(player)
    local p = profiles[player.UserId]
    return p and p.unlockedRecipes or {}
end

function PlayerDataManager.AddOwnedCookie(player, cookieId)
    local p = profiles[player.UserId]
    if not p then return end
    for _, id in ipairs(p.unlockedRecipes) do
        if id == cookieId then return end  -- already owned
    end
    table.insert(p.unlockedRecipes, cookieId)
end

function PlayerDataManager.SetBakeryName(player, name)
    local p = profiles[player.UserId]
    if not p then return end
    p.bakeryName = name
end

function PlayerDataManager.AwardBakeryXP(player, amount)
    local p = profiles[player.UserId]
    if not p then return 0, 1, false end
    p.bakeryXP += amount
    local required = math.floor(80 * (p.bakeryLevel ^ 1.4))
    local didLevelUp = false
    while p.bakeryXP >= required do
        p.bakeryXP    -= required
        p.bakeryLevel += 1
        required       = math.floor(80 * (p.bakeryLevel ^ 1.4))
        didLevelUp     = true
        print("[PlayerDataManager]", player.Name, "bakery leveled up to", p.bakeryLevel)
    end
    if didLevelUp then
        local ok, rm = pcall(getRemoteManager)
        if ok then rm.Get("BakeryLevelUp"):FireClient(player, p.bakeryLevel) end
    end
    return p.bakeryXP, p.bakeryLevel, didLevelUp
end

-- ── LIFECYCLE ──────────────────────────────────────────────────
Players.PlayerAdded:Connect(function(player)
    profiles[player.UserId] = loadProfile(player.UserId)
    local p = profiles[player.UserId]
    -- TEMP DEBUG: force 50k coins + clear unlocks every run (remove before launch)
    p.coins             = 50000
    p.unlockedStations  = {}
    p.unlockedCosmetics = {}
    print("[PlayerDataManager] Loaded profile for " .. player.Name
        .. " | coins=" .. p.coins
        .. " level=" .. p.level)
    -- Notify client of their initial data (coins, level, unlocks)
    task.defer(function()
        local ok, rm = pcall(getRemoteManager)
        if not ok then return end
        local initRemote = rm.Get("PlayerDataInit")
        initRemote:FireClient(player, {
            coins             = p.coins,
            level             = p.level,
            xp                = p.xp,
            unlockedStations  = p.unlockedStations,
            unlockedCosmetics = p.unlockedCosmetics,
            bakeryName        = p.bakeryName,
            bakeryLevel       = p.bakeryLevel,
        })
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    saveProfile(player.UserId)
    profiles[player.UserId] = nil
end)

-- Ensure all profiles save before server shuts down
game:BindToClose(function()
    for userId, _ in pairs(profiles) do
        saveProfile(userId)
    end
end)

-- Handle players already in game when first required
for _, player in ipairs(Players:GetPlayers()) do
    if not profiles[player.UserId] then
        profiles[player.UserId] = loadProfile(player.UserId)
    end
end

print("[PlayerDataManager] Ready (DataStore: PlayerData_v1).")
return PlayerDataManager
