-- LeaderboardManager
-- Tracks session and all-time leaderboard data.
-- Session: cookies sold + orders completed this Open phase, per player.
-- All-time: cookies sold + coins earned lifetime, from PlayerDataManager profiles.
-- Broadcasts both to all clients on every delivery.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace         = game:GetService("Workspace")

local OrderManager      = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("OrderManager"))
local RemoteManager     = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local PlayerDataManager = require(ServerScriptService:WaitForChild("Core"):WaitForChild("PlayerDataManager"))

local leaderboardUpdate = RemoteManager.Get("LeaderboardUpdate")

-- ── SESSION STATE ─────────────────────────────────────────────
-- Per player: { cookies = 0, orders = 0 }
local sessionData = {}

local function getOrCreate(playerName)
    if not sessionData[playerName] then
        sessionData[playerName] = { cookies = 0, orders = 0 }
    end
    return sessionData[playerName]
end

-- ── BUILD TOP-6 LIST ──────────────────────────────────────────
local function buildSorted(list, primaryKey, secondaryKey)
    table.sort(list, function(a, b)
        if a[primaryKey] ~= b[primaryKey] then
            return a[primaryKey] > b[primaryKey]
        end
        return (a[secondaryKey] or 0) > (b[secondaryKey] or 0)
    end)
    local top = {}
    for i = 1, math.min(6, #list) do
        list[i].rank = i
        top[i] = list[i]
    end
    return top
end

-- ── BROADCAST ─────────────────────────────────────────────────
local function broadcast()
    -- SESSION: per-player session stats
    local sessionList = {}
    for name, stats in pairs(sessionData) do
        table.insert(sessionList, {
            name    = name,
            cookies = stats.cookies,
            orders  = stats.orders,
        })
    end
    local topSession = buildSorted(sessionList, "cookies", "orders")

    -- ALL-TIME: from PlayerDataManager profiles (online players only)
    local alltimeList = {}
    for _, player in ipairs(Players:GetPlayers()) do
        local data = PlayerDataManager.GetData(player)
        if data then
            table.insert(alltimeList, {
                name    = player.Name,
                cookies = data.cookiesSold    or 0,
                coins   = data.coins          or 0,
            })
        end
    end
    local topAlltime = buildSorted(alltimeList, "cookies", "coins")

    leaderboardUpdate:FireAllClients({ session = topSession, alltime = topAlltime })
end

-- ── DELIVERY HOOK ─────────────────────────────────────────────
OrderManager.On("BoxDelivered", function(data)
    local box      = data and data.box
    local npcOrder = data and data.npcOrder
    if not box or not box.carrier then return end

    local entry = getOrCreate(box.carrier)
    entry.orders  += 1
    entry.cookies += npcOrder and (npcOrder.packSize or 1) or 1

    broadcast()
end)

-- ── RESET ON EACH OPEN PHASE ──────────────────────────────────
Workspace:GetAttributeChangedSignal("GameState"):Connect(function()
    if Workspace:GetAttribute("GameState") == "Open" then
        sessionData = {}
        leaderboardUpdate:FireAllClients({ session = {}, alltime = {} })
    end
end)

-- ── SEND CURRENT STATE TO NEW PLAYERS ─────────────────────────
Players.PlayerAdded:Connect(function()
    task.wait(3)  -- wait for their profile to load
    broadcast()
end)

print("[LeaderboardManager] Ready")
