-- LeaderboardManager
-- Tracks per-session cookies-delivered count per player.
-- Broadcasts a sorted top-6 list to all clients on every delivery.
-- Resets when GameState transitions to Open (new round start).

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

local OrderManager  = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("OrderManager"))
local RemoteManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))

local leaderboardUpdate = RemoteManager.Get("LeaderboardUpdate")

-- ── STATE ──────────────────────────────────────────────────────
local sessionData = {}  -- playerName -> cookiesDelivered (int)

-- ── BROADCAST ─────────────────────────────────────────────────
local function broadcast()
    local list = {}
    for name, cookies in pairs(sessionData) do
        table.insert(list, { name = name, cookies = cookies })
    end
    table.sort(list, function(a, b) return a.cookies > b.cookies end)
    local top = {}
    for i = 1, math.min(6, #list) do
        top[i] = { rank = i, name = list[i].name, cookies = list[i].cookies }
    end
    leaderboardUpdate:FireAllClients(top)
end

-- ── DELIVERY HOOK ─────────────────────────────────────────────
OrderManager.On("BoxDelivered", function(data)
    local box = data and data.box
    if not box or not box.carrier then return end
    local name = box.carrier
    sessionData[name] = (sessionData[name] or 0) + 1
    broadcast()
end)

-- ── RESET ON EACH OPEN PHASE ──────────────────────────────────
Workspace:GetAttributeChangedSignal("GameState"):Connect(function()
    if Workspace:GetAttribute("GameState") == "Open" then
        sessionData = {}
        leaderboardUpdate:FireAllClients({})
    end
end)

-- ── PLAYER LEAVE: keep stats displayed for rest of round ──────
-- (no cleanup needed — display is name-keyed, not player-ref-keyed)

print("[LeaderboardManager] Ready")
