-- ServerScriptService/Core/LifetimeChallengeManager (ModuleScript)
-- Permanent milestones that never reset. Checked against persisted profile stats.
-- Awards coins on first-time completion. Stored as a set of claimed IDs in the profile.

local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RemoteManager     = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local PlayerDataManager = require(ServerScriptService:WaitForChild("Core"):WaitForChild("PlayerDataManager"))

local initRemote     = RemoteManager.Get("LifetimeChallengesInit")
local completeRemote = RemoteManager.Get("LifetimeChallengeComplete")

-- ─── Milestone Catalog ────────────────────────────────────────────────────────
-- stat: "ordersCompleted" | "cookiesSold" | "bakeryLevel" | "maxMastery"
local MILESTONES = {
    -- Orders
    { id="lt_orders_10",    label="Complete 10 orders",          stat="ordersCompleted", goal=10,    reward=100   },
    { id="lt_orders_50",    label="Complete 50 orders",          stat="ordersCompleted", goal=50,    reward=300   },
    { id="lt_orders_250",   label="Complete 250 orders",         stat="ordersCompleted", goal=250,   reward=800   },
    { id="lt_orders_1000",  label="Complete 1,000 orders",       stat="ordersCompleted", goal=1000,  reward=2000  },
    { id="lt_orders_5000",  label="Complete 5,000 orders",       stat="ordersCompleted", goal=5000,  reward=5000  },
    { id="lt_orders_20000", label="Complete 20,000 orders",      stat="ordersCompleted", goal=20000, reward=15000 },
    -- Cookies sold
    { id="lt_cookies_100",   label="Sell 100 cookies",           stat="cookiesSold",     goal=100,   reward=250   },
    { id="lt_cookies_1000",  label="Sell 1,000 cookies",         stat="cookiesSold",     goal=1000,  reward=750   },
    { id="lt_cookies_10000", label="Sell 10,000 cookies",        stat="cookiesSold",     goal=10000, reward=3000  },
    { id="lt_cookies_100k",  label="Sell 100,000 cookies",       stat="cookiesSold",     goal=100000,reward=20000 },
    -- Bakery level
    { id="lt_level_5",       label="Reach Bakery Level 5",       stat="bakeryLevel",     goal=5,     reward=300   },
    { id="lt_level_15",      label="Reach Bakery Level 15",      stat="bakeryLevel",     goal=15,    reward=750   },
    { id="lt_level_25",      label="Reach Bakery Level 25",      stat="bakeryLevel",     goal=25,    reward=1500  },
    { id="lt_level_40",      label="Reach Bakery Level 40",      stat="bakeryLevel",     goal=40,    reward=4000  },
    { id="lt_level_50",      label="Reach Bakery Level 50",      stat="bakeryLevel",     goal=50,    reward=10000 },
    -- Station mastery
    { id="lt_mastery_3",     label="Reach Level 3 in any role",  stat="maxMastery",      goal=3,     reward=200   },
    { id="lt_mastery_7",     label="Reach Level 7 in any role",  stat="maxMastery",      goal=7,     reward=600   },
    { id="lt_mastery_10",    label="Max out any station role",    stat="maxMastery",      goal=10,    reward=2500  },
}

-- ─── Helpers ──────────────────────────────────────────────────────────────────
local function getStatValue(profile, stat)
    if stat == "ordersCompleted" then
        return profile.ordersCompleted or 0
    elseif stat == "cookiesSold" then
        return profile.cookiesSold or 0
    elseif stat == "bakeryLevel" then
        return profile.bakeryLevel or 1
    elseif stat == "maxMastery" then
        local m = profile.mastery or {}
        local best = 0
        for _, role in ipairs({"Mixer","Baller","Baker","Glazer","Decorator"}) do
            local lv = m[role .. "Level"] or 1
            if lv > best then best = lv end
        end
        return best
    end
    return 0
end

local function ensureProfile(player)
    local profile = PlayerDataManager.GetData(player)
    if not profile then return nil end
    if not profile.lifetimeChallenges then
        profile.lifetimeChallenges = {}
    end
    return profile
end

-- ─── Public API ───────────────────────────────────────────────────────────────
local M = {}

-- Check all milestones for the player; award coins + fire remote for new completions.
function M.CheckAll(player)
    local profile = ensureProfile(player)
    if not profile then return end
    local claimed = profile.lifetimeChallenges

    for _, ms in ipairs(MILESTONES) do
        if not claimed[ms.id] then
            local val = getStatValue(profile, ms.stat)
            if val >= ms.goal then
                claimed[ms.id] = true
                PlayerDataManager.AddCoins(player, ms.reward)
                completeRemote:FireClient(player, {
                    id     = ms.id,
                    label  = ms.label,
                    reward = ms.reward,
                })
            end
        end
    end
end

-- Send full milestone list to the client on join.
function M.SendToPlayer(player)
    local profile = ensureProfile(player)
    if not profile then return end
    local claimed = profile.lifetimeChallenges

    local list = {}
    for _, ms in ipairs(MILESTONES) do
        local val = getStatValue(profile, ms.stat)
        table.insert(list, {
            id       = ms.id,
            label    = ms.label,
            goal     = ms.goal,
            reward   = ms.reward,
            progress = math.min(val, ms.goal),
            claimed  = claimed[ms.id] == true,
        })
    end
    initRemote:FireClient(player, { milestones = list })
end

return M
