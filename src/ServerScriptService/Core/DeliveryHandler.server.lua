local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteManager     = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local OrderManager      = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("OrderManager"))
local PlayerDataManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("PlayerDataManager")) -- Added this

local deliverRemote  = RemoteManager.Get("DeliverBox")
local deliveryResult = RemoteManager.Get("DeliveryResult")
local hudUpdate      = RemoteManager.Get("HUDUpdate")

local boxReady = {}

OrderManager.On("BoxCreated", function(box)
    boxReady[box.carrier] = box.boxId
    print(string.format("[DeliveryHandler] Box #%d ready for %s", box.boxId, box.carrier))
end)

deliverRemote.OnServerEvent:Connect(function(player, boxId)
    local expectedBoxId = boxReady[player.Name]
    if not expectedBoxId or expectedBoxId ~= boxId then
        warn(string.format("[DeliveryHandler] %s tried to deliver box #%s but has box #%s",
            player.Name, tostring(boxId), tostring(expectedBoxId)))
        return
    end

    local orders = OrderManager.GetNPCOrders()
    local npcOrderId
    if #orders > 0 then
        npcOrderId = orders[1].orderId
    end

    local ok, quality = OrderManager.DeliverBox(player, boxId, npcOrderId) -- Get quality from deliver
    if not ok then
        warn(string.format("[DeliveryHandler] DeliverBox failed for %s box #%d", player.Name, boxId))
        return
    end

    -- M1: Hardcoded reward
    local stars = math.floor(1 + (quality / 100) * 4) -- Calculate stars from quality
    local coins = 15 + math.floor(quality / 10)
    local xp    = 10 + math.floor(quality / 10)

    boxReady[player.Name] = nil

    -- Update player data
    PlayerDataManager.AddCoins(player, coins)
    PlayerDataManager.AddXP(player, xp)
    local profile = PlayerDataManager.GetData(player)

    -- Fire remotes with correct data
    deliveryResult:FireClient(player, stars, coins, xp)
    hudUpdate:FireClient(player, profile and profile.coins or 0, profile and profile.xp or 0, nil)  -- nil clears active order label

    print(string.format("[DeliveryHandler] %s delivered box #%d — %d stars, %d coins",
        player.Name, boxId, stars, coins))
end)

Players.PlayerRemoving:Connect(function(player)
    boxReady[player.Name] = nil
end)

print("[DeliveryHandler] Ready.")