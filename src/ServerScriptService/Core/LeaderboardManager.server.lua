-- LeaderboardManager
-- Both boards show: Cookies | Orders | Coins
-- Session: tracked live this Open phase, coins via DeliveryPayout BindableEvent
-- All-time: from PlayerDataManager profiles (online players)
--
-- Set LEADERBOARD_ENABLED = true when the game launches.
local LEADERBOARD_ENABLED = true  -- S-10: enabled for alpha

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage       = game:GetService("ServerStorage")
local Workspace           = game:GetService("Workspace")

local OrderManager      = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("OrderManager"))
local RemoteManager     = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local PlayerDataManager = require(ServerScriptService:WaitForChild("Core"):WaitForChild("PlayerDataManager"))

local leaderboardUpdate = RemoteManager.Get("LeaderboardUpdate")

-- ── SESSION STATE ─────────────────────────────────────────────
-- playerName -> { cookies, orders, coins }
local sessionData = {}

local function getOrCreate(name)
    if not sessionData[name] then
        sessionData[name] = { cookies = 0, orders = 0, coins = 0 }
    end
    return sessionData[name]
end

-- ── SORT + TOP-6 ──────────────────────────────────────────────
local function topSix(list)
    table.sort(list, function(a, b)
        if a.cookies ~= b.cookies then return a.cookies > b.cookies end
        return a.coins > b.coins
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
    if not LEADERBOARD_ENABLED then return end
    -- Session
    local sessionList = {}
    for name, s in pairs(sessionData) do
        table.insert(sessionList, { name = name, cookies = s.cookies, orders = s.orders, coins = s.coins })
    end

    -- All-time (online players only)
    local alltimeList = {}
    for _, player in ipairs(Players:GetPlayers()) do
        local data = PlayerDataManager.GetData(player)
        if data then
            table.insert(alltimeList, {
                name    = player.Name,
                cookies = data.cookiesSold      or 0,
                orders  = data.ordersCompleted  or 0,
                coins   = data.coins            or 0,
            })
        end
    end

    leaderboardUpdate:FireAllClients({
        session = topSix(sessionList),
        alltime = topSix(alltimeList),
    })
end

-- ── HOOKS ─────────────────────────────────────────────────────
-- Cookies + orders from BoxDelivered
OrderManager.On("BoxDelivered", function(data)
    if not LEADERBOARD_ENABLED then return end
    local box      = data and data.box
    local npcOrder = data and data.npcOrder
    if not box or not box.carrier then return end
    local entry = getOrCreate(box.carrier)
    entry.orders  += 1
    entry.cookies += npcOrder and (npcOrder.packSize or 1) or 1
    broadcast()
end)

-- Exact session coins from DeliveryPayout BindableEvent
local ssEvents = ServerStorage:WaitForChild("Events", 10)
if ssEvents then
    local deliveryPayoutBE = ssEvents:WaitForChild("DeliveryPayout", 10)
    if deliveryPayoutBE then
        deliveryPayoutBE.Event:Connect(function(payload)
            if not LEADERBOARD_ENABLED then return end
            if not payload or not payload.playerName then return end
            local entry = getOrCreate(payload.playerName)
            entry.coins += (payload.coins or 0)
            broadcast()
        end)
    end
end

-- ── RESET ON EACH OPEN PHASE ──────────────────────────────────
Workspace:GetAttributeChangedSignal("GameState"):Connect(function()
    if Workspace:GetAttribute("GameState") == "Open" then
        sessionData = {}
        leaderboardUpdate:FireAllClients({ session = {}, alltime = {} })
    end
end)

-- ── INITIAL BROADCAST WHEN PLAYER JOINS ──────────────────────
Players.PlayerAdded:Connect(function()
    task.wait(3)
    broadcast()
end)

-- S-10: Live broadcast every 30s during Open phase
task.spawn(function()
    while true do
        task.wait(30)
        if Workspace:GetAttribute("GameState") == "Open" then
            broadcast()
        end
    end
end)

print("[LeaderboardManager] Ready")
