-- FridgeDisplayServer
-- Keeps fridge BillboardGuis in sync with OrderManager stock.
-- Runs server-side so all players see correct stock without extra remotes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteManager     = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))

local FridgeUpdated = RemoteManager.Get("FridgeUpdated")
local MAX_STOCK     = 4

local function updateBillboards(state)
    local fridgesFolder = workspace:FindFirstChild("Fridges")
    if not fridgesFolder then return end

    for _, fridge in ipairs(fridgesFolder:GetChildren()) do
        local fridgeId = fridge:GetAttribute("FridgeId")
        if not fridgeId then continue end

        local count    = state[fridgeId] or 0
        local ratio    = count / MAX_STOCK

        -- Color: green when stocked, amber at half, red when empty
        local fillColor = ratio > 0.5  and Color3.fromRGB(80, 210, 120)
                       or ratio > 0    and Color3.fromRGB(255, 185, 50)
                       or                  Color3.fromRGB(200, 70, 70)

        for _, desc in ipairs(fridge:GetDescendants()) do
            if desc:IsA("BillboardGui") and desc.Name == "FridgeDisplay" then
                local bg       = desc:FindFirstChild("Frame")
                if not bg then continue end
                local barBg    = bg:FindFirstChild("BarBg")
                local barFill  = barBg and barBg:FindFirstChild("BarFill")
                local countLbl = bg:FindFirstChild("StockCount")

                if barFill then
                    barFill.Size             = UDim2.new(ratio, 0, 1, 0)
                    barFill.BackgroundColor3 = fillColor
                end
                if countLbl then
                    countLbl.Text      = count == 0 and "Empty"
                                      or count .. " / " .. MAX_STOCK .. " batches"
                    countLbl.TextColor3 = fillColor
                end
            end
        end
    end
end

-- FridgeUpdated fires with state table whenever fridge changes
FridgeUpdated.OnServerEvent:Connect(function(_, state)
    -- This remote fires client→server only for testing; actual updates come from OrderManager
    -- We hook into the remote that fires TO clients and intercept from there
end)

-- Better: hook directly into the OrderManager notify system via a server script approach
-- The MinigameServer already fires FridgeUpdated to all clients via broadcastAll()
-- We need to update billboards whenever FridgeUpdated would fire
-- Solution: listen to the same OrderManager event that triggers broadcastAll

local OrderManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("OrderManager"))

OrderManager.On("FridgeUpdated", function(state)
    updateBillboards(state)
end)

-- Initial state on server start
task.defer(function()
    updateBillboards(OrderManager.GetFridgeState())
end)

print("[FridgeDisplayServer] Ready")
