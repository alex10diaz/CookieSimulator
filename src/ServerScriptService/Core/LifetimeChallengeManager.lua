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
    { id="lt_orders_10",   label="Complete 10 orders",          stat="ordersCompleted", goal=10,   reward=100  },
    { id="lt_orders_50",   label="Complete 50 orders",          stat="ordersCompleted", goal=50,   reward=300  },
    { id="lt_orders_200",  label="Complete 200 orders",         stat="ordersCompleted", goal=200,  reward=750  },
    { id="lt_cookies_50",  label="Sell 50 cookies",             stat="cookiesSold",     goal=50,   reward=200  },
    { id="lt_cookies_500", label="Sell 500 cookies",            stat="cookiesSold",     goal=500,  reward=500  },
    { id="lt_level_5",     label="Reach Bakery Level 5",        stat="bakeryLevel",     goal=5,    reward=250  },
    { id="lt_level_10",    label="Reach Bakery Level 10",       stat="bakeryLevel",     goal=10,   reward=500  },
    { id="lt_mastery_5",   label="Reach Level 5 in any role",  stat="maxMastery",      goal=5,    reward=400  },
    { id="lt_mastery_10",  label="Max out any station role",    stat="maxMastery",      goal=10,   reward=1000 },
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
