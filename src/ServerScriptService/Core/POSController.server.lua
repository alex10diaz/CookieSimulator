-- src/ServerScriptService/POSController.server.lua
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RemoteManager  = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local OrderManager   = require(ServerScriptService:WaitForChild("Core"):WaitForChild("OrderManager"))

local acceptRemote   = RemoteManager.Get("AcceptOrder")
local acceptedRemote = RemoteManager.Get("OrderAccepted")
local failedRemote   = RemoteManager.Get("OrderFailed")

-- ─── Constants ────────────────────────────────────────────────────────────────
local LOCK_DURATION = 30  -- seconds an accepted order is locked to one player

-- ─── State ────────────────────────────────────────────────────────────────────
local isOpen     = false
local orderLocks = {}  -- [orderId] = { player = Player, expireTime = number }

-- ─── Lock helpers ─────────────────────────────────────────────────────────────
local function cleanExpiredLocks()
    local now = os.time()
    for id, lock in pairs(orderLocks) do
        if now > lock.expireTime then
            orderLocks[id] = nil
        end
    end
end

local function isLocked(orderId)
    cleanExpiredLocks()
    return orderLocks[orderId] ~= nil
end

local function acquireLock(player, orderId)
    if isLocked(orderId) then return false end
    orderLocks[orderId] = {
        player     = player,
        expireTime = os.time() + LOCK_DURATION,
    }
    return true
end

-- ─── Accept handler ───────────────────────────────────────────────────────────
acceptRemote.OnServerEvent:Connect(function(player, orderId)
    if not isOpen then
        failedRemote:FireClient(player, orderId, "Store is not open")
        return
    end
    if not orderId then
        failedRemote:FireClient(player, orderId, "Invalid order")
        return
    end

    local orders = OrderManager.GetNPCOrders()
    local order
    for _, o in ipairs(orders) do
        if o.orderId == orderId then
            order = o
            break
        end
    end
    if not order then
        failedRemote:FireClient(player, orderId, "Order not found")
        return
    end
    if not acquireLock(player, orderId) then
        failedRemote:FireClient(player, orderId, "Order already taken")
        return
    end

    acceptedRemote:FireClient(player, orderId, order)
    print(string.format("[POSController] %s accepted order %s (%s)", player.Name, tostring(orderId), tostring(order.cookieId)))
end)

-- ─── Cleanup on player leave ──────────────────────────────────────────────────
Players.PlayerRemoving:Connect(function(player)
    for id, lock in pairs(orderLocks) do
        if lock.player == player then
            orderLocks[id] = nil
        end
    end
end)

-- ─── Public API ───────────────────────────────────────────────────────────────
local POSController = {}

function POSController.SetOpen(open)
    isOpen = open
    if not open then
        orderLocks = {}
    end
    print("[POSController] Store " .. (open and "OPEN" or "CLOSED"))
end

function POSController.IsOpen()
    return isOpen
end

function POSController.GetQueue()
    return OrderManager.GetNPCOrders()
end

print("[POSController] Ready.")
return POSController
