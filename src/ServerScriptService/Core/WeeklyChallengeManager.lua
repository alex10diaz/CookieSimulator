-- ServerScriptService/Core/WeeklyChallengeManager (ModuleScript)
-- Same architecture as DailyChallengeManager, but resets every Monday midnight UTC.
-- 3 challenges per week: Easy / Medium / Hard. Progress persists in profile.

local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RemoteManager     = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local PlayerDataManager = require(ServerScriptService:WaitForChild("Core"):WaitForChild("PlayerDataManager"))

local initRemote     = RemoteManager.Get("WeeklyChallengesInit")
local progressRemote = RemoteManager.Get("WeeklyChallengeProgress")

-- ─── Challenge Catalog ────────────────────────────────────────────────────────
-- type values: "orders" | "fiveStars" | "combo" | "totalCoins" | "totalBaked" | "uniqueTypes"

local EASY = {
    { id="w_orders_25",      type="orders",      label="Complete 25 orders this week",       goal=25,   reward=500,  tier="Easy" },
    { id="w_fivestars_12",   type="fiveStars",   label="Earn 12 five-star orders this week", goal=12,   reward=500,  tier="Easy" },
    { id="w_combo_5",        type="combo",        label="Hit a combo streak of 5",            goal=5,    reward=500,  tier="Easy" },
    { id="w_types_3",        type="uniqueTypes",  label="Bake 3 different cookie types",      goal=3,    reward=500,  tier="Easy" },
}

local MEDIUM = {
    { id="w_orders_50",      type="orders",      label="Complete 50 orders this week",       goal=50,   reward=1000, tier="Medium" },
    { id="w_coins_1500",     type="totalCoins",  label="Earn 1,500 coins this week",         goal=1500, reward=1000, tier="Medium" },
    { id="w_fivestars_20",   type="fiveStars",   label="Earn 20 five-star orders this week", goal=20,   reward=1000, tier="Medium" },
    { id="w_types_5",        type="uniqueTypes",  label="Bake 5 different cookie types",      goal=5,    reward=1000, tier="Medium" },
}

local HARD = {
    { id="w_orders_100",     type="orders",      label="Complete 100 orders this week",      goal=100,  reward=2000, tier="Hard" },
    { id="w_coins_5000",     type="totalCoins",  label="Earn 5,000 coins this week",         goal=5000, reward=2000, tier="Hard" },
    { id="w_baked_60",       type="totalBaked",  label="Bake 60 cookies total this week",    goal=60,   reward=2000, tier="Hard" },
}

-- ─── State ────────────────────────────────────────────────────────────────────
-- In-memory per-player counters. Reset on server restart (same known limitation as daily).
local playerStats = {}

local cachedChallenges = nil
local cachedSeed       = nil

-- ─── Helpers ──────────────────────────────────────────────────────────────────
-- Returns year-YYYY-Www key anchored to Monday.
local function getWeekKey()
    local t = os.date("!*t")
    -- wday: 1=Sun 2=Mon … 7=Sat. Days since last Monday:
    local daysSinceMon = (t.wday - 2) % 7
    local monYday      = t.yday - daysSinceMon
    return t.year .. "-W" .. string.format("%03d", monYday)
end

local function getWeekSeed()
    local t = os.date("!*t")
    local daysSinceMon = (t.wday - 2) % 7
    local monYday      = t.yday - daysSinceMon
    return t.year * 1000 + monYday
end

local function secondsUntilMonday()
    local t = os.date("!*t")
    local daysUntilMon = (9 - t.wday) % 7
    if daysUntilMon == 0 then daysUntilMon = 7 end
    return daysUntilMon * 86400 - (t.hour * 3600 + t.min * 60 + t.sec)
end

local function ensureStats(userId)
    if not playerStats[userId] then
        playerStats[userId] = {
            orders        = 0,
            fiveStars     = 0,
            peakCombo     = 0,
            totalCoins    = 0,
            totalBaked    = 0,
            uniqueTypeSet = {},
        }
    end
    return playerStats[userId]
end

local function countKeys(t)
    local n = 0; for _ in pairs(t) do n += 1 end; return n
end

local function ensureProfile(player)
    local profile = PlayerDataManager.GetData(player)
    if not profile then return nil end
    if not profile.weeklyChallenges then
        profile.weeklyChallenges = { weekKey="", progress={0,0,0}, claimed={false,false,false} }
    end
    return profile
end

-- ─── Public API ───────────────────────────────────────────────────────────────
local M = {}

function M.GetWeekChallenges()
    local seed = getWeekSeed()
    if cachedSeed == seed and cachedChallenges then return cachedChallenges end
    local eIdx = (seed % #EASY)   + 1
    local mIdx = (math.floor(seed / 7)  % #MEDIUM) + 1
    local hIdx = (math.floor(seed / 13) % #HARD)   + 1
    cachedChallenges = { EASY[eIdx], MEDIUM[mIdx], HARD[hIdx] }
    cachedSeed = seed
    return cachedChallenges
end

function M.ResetIfNeeded(player)
    local profile = ensureProfile(player)
    if not profile then return end
    local wc = profile.weeklyChallenges
    if wc.weekKey ~= getWeekKey() then
        wc.weekKey  = getWeekKey()
        wc.progress = {0, 0, 0}
        wc.claimed  = {false, false, false}
    end
    ensureStats(player.UserId)
end

function M.SendToPlayer(player)
    local profile = ensureProfile(player)
    if not profile then return end
    local wc = profile.weeklyChallenges
    initRemote:FireClient(player, {
        challenges = M.GetWeekChallenges(),
        progress   = wc.progress,
        claimed    = wc.claimed,
        resetIn    = secondsUntilMonday(),
    })
end

-- data = { stars, cookieId, coins, comboStreak, packSize }
function M.RecordDelivery(player, data)
    local profile = ensureProfile(player)
    if not profile then return end
    local wc         = profile.weeklyChallenges
    local stats      = ensureStats(player.UserId)
    local challenges = M.GetWeekChallenges()

    -- Update in-session counters
    stats.orders      += 1
    if (data.stars or 0) >= 5 then stats.fiveStars += 1 end
    stats.peakCombo    = math.max(stats.peakCombo, data.comboStreak or 0)
    stats.totalCoins  += (data.coins or 0)
    stats.totalBaked  += (data.packSize or 1)
    if data.cookieId then stats.uniqueTypeSet[data.cookieId] = true end

    for i, ch in ipairs(challenges) do
        if wc.claimed[i] then continue end

        local current
        if     ch.type == "orders"      then current = wc.progress[i] + stats.orders
        elseif ch.type == "fiveStars"   then current = wc.progress[i] + stats.fiveStars
        elseif ch.type == "combo"       then current = math.max(wc.progress[i], stats.peakCombo)
        elseif ch.type == "totalCoins"  then current = wc.progress[i] + stats.totalCoins
        elseif ch.type == "totalBaked"  then current = wc.progress[i] + stats.totalBaked
        elseif ch.type == "uniqueTypes" then current = math.max(wc.progress[i], countKeys(stats.uniqueTypeSet))
        else current = wc.progress[i]
        end

        current = math.min(current, ch.goal)
        wc.progress[i] = current

        local justCompleted = (current >= ch.goal)
        if justCompleted then
            wc.claimed[i] = true
            PlayerDataManager.AddCoins(player, ch.reward)
        end

        progressRemote:FireClient(player, {
            index         = i,
            progress      = current,
            goal          = ch.goal,
            completed     = wc.claimed[i],
            justCompleted = justCompleted,
            coinsAwarded  = justCompleted and ch.reward or 0,
        })
    end
end

function M.Cleanup(player)
    playerStats[player.UserId] = nil
end

return M
