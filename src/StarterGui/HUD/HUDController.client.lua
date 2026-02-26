-- src/StarterGui/HUD/HUDController.client.lua
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteManager  = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local stateRemote    = RemoteManager.Get("GameStateChanged")
local acceptedEvent  = RemoteManager.Get("OrderAccepted")
local deliveryEvent  = RemoteManager.Get("DeliveryResult")
local hudUpdateEvent = RemoteManager.Get("HUDUpdate")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local hud       = playerGui:WaitForChild("HUD")
local timerLbl  = hud:WaitForChild("TimerLabel")
local coinsLbl  = hud:WaitForChild("CoinsLabel")
local orderLbl  = hud:WaitForChild("ActiveOrderLabel")

-- ─── Helpers ──────────────────────────────────────────────────────────────────
local STATE_LABELS = {
    PreOpen  = "PRE-OPEN",
    Open     = "OPEN",
    EndOfDay = "END OF DAY",
    Lobby    = "LOBBY",
}

local function formatTime(seconds)
    local m = math.floor(seconds / 60)
    local s = seconds % 60
    return string.format("%d:%02d", m, s)
end

-- ─── State Updates ────────────────────────────────────────────────────────────
stateRemote.OnClientEvent:Connect(function(state, timeRemaining)
    local label = STATE_LABELS[state] or state
    timerLbl.Text = label .. "  " .. formatTime(timeRemaining or 0)
    timerLbl.BackgroundColor3 = state == "Open"
        and Color3.fromRGB(60, 140, 60)
        or  Color3.fromRGB(30, 30, 30)
end)

hudUpdateEvent.OnClientEvent:Connect(function(coins, xp, activeOrderName)
    coinsLbl.Text = "Coins: " .. (coins or 0)
    if activeOrderName then
        orderLbl.Text = "Order: " .. activeOrderName
        orderLbl.BackgroundColor3 = Color3.fromRGB(80, 180, 100)
    else
        orderLbl.Text = "No active order"
        orderLbl.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    end
end)

-- ─── Order Accepted → Update active order label ───────────────────────────────
acceptedEvent.OnClientEvent:Connect(function(orderId, orderData)
    if orderData and orderData.cookieId then
        orderLbl.Text = "Order: " .. orderData.cookieId
        orderLbl.BackgroundColor3 = Color3.fromRGB(80, 180, 100)
    end
end)

-- ─── Delivery Flash ───────────────────────────────────────────────────────────
deliveryEvent.OnClientEvent:Connect(function(stars, coins, xp)
    -- Reset active order label
    orderLbl.Text = "No active order"
    orderLbl.BackgroundColor3 = Color3.fromRGB(100, 100, 100)

    -- Flash delivery result
    local flash = Instance.new("TextLabel")
    flash.Size              = UDim2.new(0, 250, 0, 60)
    flash.Position          = UDim2.new(0.5, -125, 0.4, 0)
    flash.BackgroundColor3  = (stars or 0) >= 4
        and Color3.fromRGB(255, 200, 0)
        or  Color3.fromRGB(200, 100, 100)
    flash.TextColor3        = Color3.fromRGB(255, 255, 255)
    flash.TextScaled        = true
    flash.Font              = Enum.Font.GothamBold
    flash.Text              = string.rep("*", stars or 0) .. " +" .. (coins or 0) .. " coins"
    flash.ZIndex            = 50
    flash.Parent            = hud

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = flash

    game:GetService("Debris"):AddItem(flash, 2.5)
end)

print("[HUDController] Ready.")
