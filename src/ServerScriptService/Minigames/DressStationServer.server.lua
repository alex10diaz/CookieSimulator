-- src/ServerScriptService/Minigames/DressStationServer.server.lua
-- KDS-style Dress Station. Replaces the Keep/Toss card minigame.
-- Flow: DressPrompt → server sends top-3 NPC orders to client →
--       player clicks an order → server validates warmers → CreateBox → done.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

local RemoteManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local OrderManager  = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("OrderManager"))

local kdsUpdate   = RemoteManager.Get("DressKDSUpdate")
local lockOrder   = RemoteManager.Get("DressLockOrder")
local orderLocked = RemoteManager.Get("DressOrderLocked")
local cancelOrder = RemoteManager.Get("DressCancelOrder")

-- Players currently viewing the KDS UI
local activeKDS = {}   -- player -> true

-- Default dress quality (no skill minigame; correct packing earns a solid score)
local DRESS_SCORE = 85

-- ─── Payload builder ─────────────────────────────────────────────────────────
local function buildKDSPayload()
    local orders  = OrderManager.GetNPCOrders()
    local warmers = OrderManager.GetWarmerCountsByType()  -- cookieId -> count (dress-ready)
    local now     = tick()

    local top3 = {}
    for i = 1, math.min(3, #orders) do
        local o = orders[i]
        top3[i] = {
            orderId     = o.orderId,
            npcName     = o.npcName,
            cookieId    = o.cookieId,
            packSize    = o.packSize,
            price       = o.price,
            isVIP       = o.isVIP,
            waitSeconds = math.floor(now - (o.orderedAt or now)),
        }
    end

    return { orders = top3, warmers = warmers }
end

-- ─── Prompt hook ─────────────────────────────────────────────────────────────
local function hookDressPrompt(desc)
    if not (desc:IsA("ProximityPrompt") and desc.Name == "DressPrompt") then return end

    desc.Triggered:Connect(function(player)
        if activeKDS[player] then return end

        local orders = OrderManager.GetNPCOrders()
        if #orders == 0 then
            warn("[DressStation] No NPC orders for " .. player.Name)
            return
        end

        activeKDS[player] = true
        kdsUpdate:FireClient(player, buildKDSPayload())
    end)
end

for _, desc in ipairs(Workspace:GetDescendants()) do hookDressPrompt(desc) end
Workspace.DescendantAdded:Connect(hookDressPrompt)

-- ─── Order selection ─────────────────────────────────────────────────────────
lockOrder.OnServerEvent:Connect(function(player, orderId)
    if not activeKDS[player] then return end
    if type(orderId) ~= "number" then return end

    -- Validate order still exists
    local targetOrder = nil
    for _, o in ipairs(OrderManager.GetNPCOrders()) do
        if o.orderId == orderId then targetOrder = o; break end
    end

    if not targetOrder then
        orderLocked:FireClient(player, { success = false, message = "Order no longer available" })
        activeKDS[player] = nil
        return
    end

    -- Validate warmer has matching cookie type
    local warmerCounts = OrderManager.GetWarmerCountsByType()
    if (warmerCounts[targetOrder.cookieId] or 0) == 0 then
        orderLocked:FireClient(player, { success = false, message = "No " .. (targetOrder.cookieId or "?") .. " in warmers" })
        activeKDS[player] = nil
        return
    end

    -- Take matching cookie from warmers and create box
    local entry = OrderManager.TakeFromWarmersByType(targetOrder.cookieId)
    if not entry then
        orderLocked:FireClient(player, { success = false, message = "Could not retrieve cookie from warmers" })
        activeKDS[player] = nil
        return
    end

    local box = OrderManager.CreateBox(player, entry.batchId, DRESS_SCORE, entry)
    activeKDS[player] = nil

    if box then
        print(string.format("[DressStation] %s packed box #%d for %s (order #%d)",
            player.Name, box.boxId, targetOrder.npcName, orderId))
        orderLocked:FireClient(player, { success = true, boxId = box.boxId, orderId = orderId })
    else
        orderLocked:FireClient(player, { success = false, message = "Failed to create box" })
    end
end)

-- ─── Cancel ──────────────────────────────────────────────────────────────────
cancelOrder.OnServerEvent:Connect(function(player)
    activeKDS[player] = nil
end)

Players.PlayerRemoving:Connect(function(player)
    activeKDS[player] = nil
end)

print("[DressStationServer] Ready — KDS mode active.")
