-- ServerScriptService/Core/PlayerDataManager (ModuleScript)
-- Handles in-memory player profiles + DataStore persistence.
-- Load on PlayerAdded, save on PlayerRemoving.

local Players           = game:GetService("Players")
local DataStoreService  = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService       = game:GetService("HttpService")

local playerStore = DataStoreService:GetDataStore("PlayerData_v1")
-- C-2: unique ID for this server instance — used to detect cross-server save conflicts
local SESSION_ID  = HttpService:GenerateGUID(false)

-- Lazy-loaded to avoid require-at-load-time issues
local function getRemoteManager()
    return require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
end

local DEFAULT_PROFILE = {
    coins             = 500,  -- BUG-33: starter coins so shop is accessible shift 1
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
    equippedCosmetics = { hat = nil, apron = nil },  -- currently worn items
    bakeryName        = "",  -- set once on first join
    bakeryXP          = 0,
    bakeryLevel       = 1,
    dailyChallenges = {
        date     = "",            -- "YYYY-DDD" UTC date key, e.g. "2026-069"
        progress = {0, 0, 0},   -- progress values for each of the 3 challenges
        claimed  = {false, false, false},  -- whether reward was claimed
    },
    mastery = {
        MixerLevel=1,     MixerXP=0,
        BallerLevel=1,    BallerXP=0,
        BakerLevel=1,     BakerXP=0,
        GlazerLevel=1,    GlazerXP=0,
        DecoratorLevel=1, DecoratorXP=0,
    },
    weeklyChallenges = {
        weekKey  = "",
        progress = {0, 0, 0},
        claimed  = {false, false, false},
    },
    lifetimeChallenges = {},  -- set of claimed milestone IDs: { [id]=true }
}

local profiles = {}  -- userId -> profile table

-- ── HELPERS ────────────────────────────────────────────────────

-- C-1: deepCopy defined first so newProfile() can reference it
local function deepCopy(t)
    local copy = {}
    for k, v in pairs(t) do
        copy[k] = type(v) == "table" and deepCopy(v) or v
    end
    return copy
end

-- C-1: use deepCopy so nested arrays (dailyChallenges.progress etc.)
-- are never shared with DEFAULT_PROFILE across player instances
local function newProfile()
    return deepCopy(DEFAULT_PROFILE)
end

-- M-1: recursive merge so new sub-table fields added to DEFAULT_PROFILE
-- after a player's first save are not silently lost for existing players
local function mergeDeep(defaults, saved)
    local out = {}
    for k, dv in pairs(defaults) do
        local sv = saved[k]
        if type(dv) == "table" and type(sv) == "table" then
            out[k] = mergeDeep(dv, sv)
        else
            out[k] = sv ~= nil and sv or dv
        end
    end
    return out
end

local function mergeDefaults(saved)
    return mergeDeep(DEFAULT_PROFILE, saved)
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
    local key    = "Player_" .. userId
    local toSave = deepCopy(profile)
    -- math.huge is not JSON-safe; replace with 0
    if toSave.stats and toSave.stats.fastestOrderTime == math.huge then
        toSave.stats.fastestOrderTime = 0
    end
    -- BUG-34: UpdateAsync with session lock + expiry. Lock expires after 120s so a new
    -- server can take ownership instead of skipping saves forever after an abnormal shutdown.
    -- GAP-2b: retry up to 3 times with 2s backoff on DataStore failure (network blip, budget spike).
    local MAX_RETRIES = 3
    local saved = false
    for attempt = 1, MAX_RETRIES do
        local ok, err = pcall(function()
            playerStore:UpdateAsync(key, function(current)
                if current and current._serverLock
                    and current._serverLock ~= SESSION_ID
                    and (not current._lockExpiry or os.time() < current._lockExpiry) then
                    warn("[PlayerDataManager] Save skipped for", userId,
                        "— locked by another server")
                    return nil  -- nil = no change written
                end
                toSave._serverLock = SESSION_ID
                toSave._lockExpiry = os.time() + 120  -- lock expires in 2 minutes
                return toSave
            end)
        end)
        if ok then
            saved = true
            print("[PlayerDataManager] Saved profile for userId", userId)
            break
        end
        warn("[PlayerDataManager] Save attempt", attempt, "failed for", userId, err)
        if attempt < MAX_RETRIES then task.wait(2) end
    end
    if not saved then
        warn("[PlayerDataManager] All", MAX_RETRIES, "save attempts failed for userId", userId)
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
    -- BUG-71/72: push updated coin total to client HUD immediately
    pcall(function() getRemoteManager().Get("HUDUpdate"):FireClient(player, p.coins, p.xp, nil) end)
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
    -- BUG-85: fire HUDUpdate so client coin counter stays in sync after deductions
    pcall(function() getRemoteManager().Get("HUDUpdate"):FireClient(player, p.coins, p.xp, nil) end)
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

-- Equip a cosmetic into its slot (hat or apron), inferred from id prefix
function PlayerDataManager.EquipCosmetic(player, cosmeticId)
    local p = profiles[player.UserId]
    if not p then return end
    if not p.equippedCosmetics then p.equippedCosmetics = { hat = nil, apron = nil } end
    local slot = cosmeticId:sub(1, 5) == "apron" and "apron" or "hat"
    p.equippedCosmetics[slot] = cosmeticId
end

function PlayerDataManager.GetEquipped(player)
    local p = profiles[player.UserId]
    if not p then return { hat = nil, apron = nil } end
    return p.equippedCosmetics or { hat = nil, apron = nil }
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
    name = tostring(name or ""):gsub("%s+", " "):match("^%s*(.-)%s*$")  -- trim
    if #name == 0 then return end                                         -- m6: reject empty
    name = string.sub(name, 1, 24)                                       -- m6: max 24 chars
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
        -- H-5: Auto-grant recipe unlocks at bakery level thresholds
        if p.bakeryLevel >= 5 then
            PlayerDataManager.AddOwnedCookie(player, "cookies_and_cream")
        end
        if p.bakeryLevel >= 10 then
            PlayerDataManager.AddOwnedCookie(player, "lemon_blackraspberry")
        end
        local ok, rm = pcall(getRemoteManager)
        if ok then rm.Get("BakeryLevelUp"):FireClient(player, p.bakeryLevel) end
    end
    return p.bakeryXP, p.bakeryLevel, didLevelUp
end

-- TEMP_DEV: Wipe DataStore + in-memory profile for a player. Remove before launch.
function PlayerDataManager.ResetData(player)
    local userId = player.UserId
    pcall(function() playerStore:RemoveAsync("Player_" .. userId) end)
    profiles[userId] = newProfile()
    local p = profiles[userId]
    local ok, rm = pcall(getRemoteManager)
    if ok then
        rm.Get("PlayerDataInit"):FireClient(player, {
            coins             = p.coins,
            level             = p.level,
            xp                = p.xp,
            unlockedStations  = p.unlockedStations,
            unlockedCosmetics = p.unlockedCosmetics,
            equippedCosmetics = p.equippedCosmetics,
            bakeryName        = p.bakeryName,
            bakeryLevel       = p.bakeryLevel,
        })
    end
    print("[PlayerDataManager] Data reset for " .. player.Name)
end

-- BUG-23: Reset comboStreak for all loaded players at shift start.
-- comboStreak is per-shift; it must not carry over between shifts.
function PlayerDataManager.ResetAllCombos()
    for _, profile in pairs(profiles) do
        profile.comboStreak = 0
    end
end

-- ── LIFECYCLE ──────────────────────────────────────────────────
local AUTO_SAVE_INTERVAL = 300  -- save every 5 minutes

Players.PlayerAdded:Connect(function(player)
    profiles[player.UserId] = loadProfile(player.UserId)

    -- Auto-save loop for this player
    task.spawn(function()
        while player.Parent do
            task.wait(AUTO_SAVE_INTERVAL)
            if player.Parent then
                saveProfile(player.UserId)
            end
        end
    end)
    local p = profiles[player.UserId]

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
            equippedCosmetics = p.equippedCosmetics,
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
-- M-3: spawn saves in parallel so budget exhaustion doesn't drop later players
game:BindToClose(function()
    local threads = {}
    for userId in pairs(profiles) do
        threads[#threads + 1] = task.spawn(saveProfile, userId)
    end
    task.wait(8)  -- give parallel saves time to complete (~30s server window)
end)

-- Handle players already in game when first required
for _, player in ipairs(Players:GetPlayers()) do
    if not profiles[player.UserId] then
        profiles[player.UserId] = loadProfile(player.UserId)
    end
end

-- BUG-54: client-pull remote so HUDController can request data any time after spawn,
-- avoiding the PlayerDataInit race where task.defer fires before LocalScripts connect.
local function getRemoteManagerNow()
    return require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
end
local ok54, rm54 = pcall(getRemoteManagerNow)
if ok54 then
    rm54.Get("RequestPlayerData").OnServerEvent:Connect(function(player)
        local p = profiles[player.UserId]
        if not p then return end
        rm54.Get("PlayerDataInit"):FireClient(player, {
            coins             = p.coins,
            level             = p.level,
            xp                = p.xp,
            unlockedStations  = p.unlockedStations,
            unlockedCosmetics = p.unlockedCosmetics,
            equippedCosmetics = p.equippedCosmetics,
            bakeryName        = p.bakeryName,
            bakeryLevel       = p.bakeryLevel,
        })
    end)
end

print("[PlayerDataManager] Ready (DataStore: PlayerData_v1).")
return PlayerDataManager
