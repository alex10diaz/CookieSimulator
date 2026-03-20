-- FridgeDisplayServer
-- Keeps fridge BillboardGuis in sync with OrderManager stock.
-- Runs server-side so all players see correct stock without extra remotes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local OrderManager      = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("OrderManager"))

local MAX_STOCK = 4

-- Raise & center every FridgeDisplay BillboardGui so it floats above the model cleanly.
-- Called once at startup; safe to re-run (idempotent property writes).
local function fixBillboardLayout()
    local fridgesFolder = workspace:FindFirstChild("Fridges")
    if not fridgesFolder then return end
    for _, fridge in ipairs(fridgesFolder:GetChildren()) do
        for _, desc in ipairs(fridge:GetDescendants()) do
            if desc:IsA("BillboardGui") and desc.Name == "FridgeDisplay" then
                desc.StudsOffset    = Vector3.new(0, 5, 0)   -- float well above the top of the model
                desc.Size           = UDim2.new(0, 220, 0, 64)
                desc.AlwaysOnTop    = true
                desc.LightInfluence = 0
            end
        end
    end
end

local function updateBillboards(state)
    local fridgesFolder = workspace:FindFirstChild("Fridges")
    if not fridgesFolder then return end

    for _, fridge in ipairs(fridgesFolder:GetChildren()) do
        local fridgeId = fridge:GetAttribute("FridgeId")
        if not fridgeId then continue end

        local count    = state[fridgeId] or 0
        local ratio    = count / MAX_STOCK

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

-- Hook directly into the OrderManager notify system.
OrderManager.On("FridgeUpdated", function(state)
    updateBillboards(state)
end)

-- Initial state on server start
task.defer(function()
    fixBillboardLayout()
    updateBillboards(OrderManager.GetFridgeState())
end)

print("[FridgeDisplayServer] Ready")
