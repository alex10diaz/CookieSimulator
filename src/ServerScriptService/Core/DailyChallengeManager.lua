-- ServerScriptService/Core/DailyChallengeManager (ModuleScript)
-- Manages daily challenge catalog, per-player progress, and reward delivery.
-- Challenges reset at midnight UTC. 3 challenges per day: one Easy, Medium, Hard.

local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RemoteManager     = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local CookieData        = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CookieData"))
local MenuManager       = require(ServerScriptService:WaitForChild("Core"):WaitForChild("MenuManager"))
local PlayerDataManager = require(ServerScriptService:WaitForChild("Core"):WaitForChild("PlayerDataManager"))

local initRemote     = RemoteManager.Get("DailyChallengesInit")
local progressRemote = RemoteManager.Get("DailyChallengeProgress")

-- ─── Challenge Catalog ──────────────────────────────────────────────────────
-- type values: "orders" | "fiveStars" | "combo" | "shiftCoins" | "totalBaked" | "cookieType" | "uniqueTypes"
-- cookieType challenges use labelTemplate with %s = cookie name, resolved at runtime from active menu.

local EASY = {
    { id="complete_orders_5",  type="orders",     label="Complete 5 orders today",      goal=5,   reward=150, tier="Easy" },
    { id="five_stars_4",       type="fiveStars",  label="Earn 4 five-star orders",       goal=4,   reward=150, tier="Easy" },
    { id="combo_3",            type="combo",      label="Hit a combo streak of 3",        goal=3,   reward=150, tier="Easy" },
    { id="cookie_type_8",      type="cookieType", labelTemplate="Bake 8 %s cookies",     goal=8,   reward=150, tier="Easy" },
}

local MEDIUM = {
    { id="complete_orders_12", type="orders",      label="Complete 12 orders today",     goal=12,  reward=300, tier="Medium" },
    { id="five_stars_6",       type="fiveStars",   label="Earn 6 five-star orders",      goal=6,   reward=300, tier="Medium" },
    { id="shift_coins_500",    type="shiftCoins",  label="Earn 500 coins in one shift",  goal=500, reward=300, tier="Medium" },
    { id="unique_types_3",     type="uniqueTypes", label="Bake 3 different cookie types", goal=3,  reward=300, tier="Medium" },
}

local HARD = {
    { id="complete_orders_20", type="orders",     label="Complete 20 orders today",      goal=20,  reward=500, tier="Hard" },
    { id="five_stars_10",      type="fiveStars",  label="Earn 10 five-star orders",      goal=10,  reward=500, tier="Hard" },
    { id="combo_6",            type="combo",      label="Hit a combo streak of 6",        goal=6,   reward=500, tier="Hard" },
    { id="total_baked_15",     type="totalBaked", label="Bake 15 cookies total",         goal=15,  reward=500, tier="Hard" },
}

-- ─── State ──────────────────────────────────────────────────────────────────
-- Per-player in-memory counters (non-persistent, reset on server restart).
-- Persistent state (progress, claimed) lives in PlayerDataManager profile.
local playerStats = {}
-- playerStats[userId] = {
--   orders=0, fiveStars=0, peakCombo=0,
--   shiftCoins=0, totalBaked=0,
--   cookieCounts={[cookieId]=count}, uniqueTypeSet={[cookieId]=true}
-- }

local cachedChallenges = nil
local cachedSeed       = nil

-- ─── Helpers ────────────────────────────────────────────────────────────────
local function getTodayKey()
    local t = os.date("!*t")
    return t.year .. "-" .. string.format("%03d", t.yday)
end

local function getTodaySeed()
    local t = os.date("!*t")
    return t.year * 1000 + t.yday
end

local function resolveCookieType(template, seed)
    local menu = MenuManager.GetActiveMenu()
    local cookieId = "chocolate_chip"  -- safe fallback
    if menu and #menu > 0 then
        local idx = (math.floor(seed / 3) % #menu) + 1
        cookieId = menu[idx]
    end
    local ck = CookieData.GetById(cookieId)
    local name = ck and ck.name or cookieId
    return {
        id            = template.id,
        type          = template.type,
        tier          = template.tier,
        label         = string.format(template.labelTemplate, name),
        goal          = template.goal,
        reward        = template.reward,
        param         = cookieId,
    }
end

local function ensureStats(userId)
    if not playerStats[userId] then
        playerStats[userId] = {
            orders        = 0,
            fiveStars     = 0,
            peakCombo     = 0,
            shiftCoins    = 0,
            totalBaked    = 0,
            cookieCounts  = {},
            uniqueTypeSet = {},
        }
    end
    return playerStats[userId]
end

local function countKeys(t)
    local n = 0
    for _ in pairs(t) do n += 1 end
    return n
end

-- ─── Public API ─────────────────────────────────────────────────────────────
local M = {}

-- Returns today's 3 challenges (cached per UTC day). Call after menu locks to
-- ensure cookieType param reflects the active menu.
function M.GetTodayChallenges()
    local seed = getTodaySeed()
    if cachedSeed == seed and cachedChallenges then
        return cachedChallenges
    end
    local eIdx = (seed % #EASY) + 1
    local mIdx = (math.floor(seed / 7)  % #MEDIUM) + 1
    local hIdx = (math.floor(seed / 13) % #HARD)   + 1

    local function resolve(template)
        if template.type == "cookieType" then
            return resolveCookieType(template, seed)
        end
        return template
    end

    cachedChallenges = {
        resolve(EASY[eIdx]),
        resolve(MEDIUM[mIdx]),
        resolve(HARD[hIdx]),
    }
    cachedSeed = seed
    return cachedChallenges
end

-- Call when menu locks (Open phase) so cookieType challenge re-resolves with confirmed menu.
function M.InvalidateChallengeCache()
    cachedChallenges = nil
    cachedSeed       = nil
end

-- Called on player join. Wipes progress if UTC date has changed.
function M.ResetIfNeeded(player)
    local profile = PlayerDataManager.GetData(player)
    if not profile then return end
    if not profile.dailyChallenges then
        profile.dailyChallenges = { date="", progress={0,0,0}, claimed={false,false,false} }
    end
    local dc = profile.dailyChallenges
    if dc.date ~= getTodayKey() then
        dc.date     = getTodayKey()
        dc.progress = {0, 0, 0}
        dc.claimed  = {false, false, false}
    end
    ensureStats(player.UserId)
end

-- Sends today's challenge state to the client.
function M.SendToPlayer(player)
    local profile = PlayerDataManager.GetData(player)
    if not profile or not profile.dailyChallenges then return end
    local dc = profile.dailyChallenges
    local t  = os.date("!*t")
    local resetIn = (23 - t.hour) * 3600 + (59 - t.min) * 60 + (60 - t.sec)
    initRemote:FireClient(player, {
        challenges = M.GetTodayChallenges(),
        progress   = dc.progress,
        claimed    = dc.claimed,
        resetIn    = resetIn,
    })
end

-- Reset per-shift coin counter. Call at the start of each Open phase.
function M.ResetShiftCounters(player)
    local uid = player.UserId
    if playerStats[uid] then
        playerStats[uid].shiftCoins = 0
    end
end

-- Called after each delivery. data = { stars, cookieId, coins, comboStreak, packSize }
function M.RecordDelivery(player, data)
    local profile = PlayerDataManager.GetData(player)
    if not profile or not profile.dailyChallenges then return end
    local dc         = profile.dailyChallenges
    local stats      = ensureStats(player.UserId)
    local challenges = M.GetTodayChallenges()

    -- Update live counters
    stats.orders    += 1
    if (data.stars or 0) >= 5 then stats.fiveStars += 1 end
    stats.peakCombo  = math.max(stats.peakCombo, data.comboStreak or 0)
    stats.shiftCoins += (data.coins or 0)
    stats.totalBaked += (data.packSize or 1)
    if data.cookieId then
        stats.cookieCounts[data.cookieId] = (stats.cookieCounts[data.cookieId] or 0) + (data.packSize or 1)
        stats.uniqueTypeSet[data.cookieId] = true
    end

    -- Evaluate each challenge
    for i, ch in ipairs(challenges) do
        if dc.claimed[i] then continue end

        local current
        if     ch.type == "orders"      then current = stats.orders
        elseif ch.type == "fiveStars"   then current = stats.fiveStars
        elseif ch.type == "combo"       then current = stats.peakCombo
        elseif ch.type == "shiftCoins"  then current = stats.shiftCoins
        elseif ch.type == "totalBaked"  then current = stats.totalBaked
        elseif ch.type == "cookieType"  then current = stats.cookieCounts[ch.param] or 0
        elseif ch.type == "uniqueTypes" then current = countKeys(stats.uniqueTypeSet)
        else current = 0
        end

        current = math.min(current, ch.goal)
        dc.progress[i] = current

        local justCompleted = (current >= ch.goal)
        if justCompleted then
            dc.claimed[i] = true
            PlayerDataManager.AddCoins(player, ch.reward)
        end

        progressRemote:FireClient(player, {
            index         = i,
            progress      = current,
            goal          = ch.goal,
            completed     = dc.claimed[i],
            justCompleted = justCompleted,
            coinsAwarded  = justCompleted and ch.reward or 0,
        })
    end
end

-- Cleanup in-memory state on player leave.
function M.Cleanup(player)
    playerStats[player.UserId] = nil
end

return M
