-- src/ServerScriptService/Core/DeliveryHandler.server.lua
-- M1: Server-side box delivery validation and reward payout.
-- Tracks which player has which box ready, validates delivery, fires result.
-- M4: Replace hardcoded rewards with EconomyManager + RatingSystem formulas.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteManager  = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local OrderManager   = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("OrderManager"))

local deliverRemote  = RemoteManager.Get("DeliverBox")
local deliveryResult = RemoteManager.Get("DeliveryResult")
local hudUpdate      = RemoteManager.Get("HUDUpdate")

-- ─── State ────────────────────────────────────────────────────────────────────
-- boxReady[playerName] = boxId (set when OrderManager fires "BoxCreated")
local boxReady = {}

-- ─── Track boxes when they're created ────────────────────────────────────────
OrderManager.On("BoxCreated", function(box)
    boxReady[box.carrier] = box.boxId
    print(string.format("[DeliveryHandler] Box #%d ready for %s", box.boxId, box.carrier))
end)

-- ─── Delivery remote ──────────────────────────────────────────────────────────
deliverRemote.OnServerEvent:Connect(function(player, boxId)
    local expectedBoxId = boxReady[player.Name]
    if not expectedBoxId or expectedBoxId ~= boxId then
        warn(string.format("[DeliveryHandler] %s tried to deliver box #%s but has box #%s",
            player.Name, tostring(boxId), tostring(expectedBoxId)))
        return
    end

    -- Find the first available NPC order to fulfill
    local orders = OrderManager.GetNPCOrders()
    local npcOrderId
    if #orders > 0 then
        npcOrderId = orders[1].orderId
    end

    local ok = OrderManager.DeliverBox(player, boxId, npcOrderId)
    if not ok then
        warn(string.format("[DeliveryHandler] DeliverBox failed for %s box #%d", player.Name, boxId))
        return
    end

    -- M1: Hardcoded reward — replace in M4 with EconomyManager.CalculatePayout
    local stars = 4
    local coins = 30
    local xp    = 20

    boxReady[player.Name] = nil

    deliveryResult:FireClient(player, stars, coins, xp)
    hudUpdate:FireClient(player, coins, xp, nil)  -- nil clears active order label

    print(string.format("[DeliveryHandler] %s delivered box #%d — %d stars, %d coins",
        player.Name, boxId, stars, coins))
end)

-- ─── Cleanup on player leave ──────────────────────────────────────────────────
Players.PlayerRemoving:Connect(function(player)
    boxReady[player.Name] = nil
end)

print("[DeliveryHandler] Ready.")
