-- src/StarterGui/POSGui/POSClient.client.lua
local Players                = game:GetService("Players")
local ReplicatedStorage      = game:GetService("ReplicatedStorage")
local UserInputService       = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local RemoteManager  = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local OrderManager   = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("OrderManager"))

local acceptRemote   = RemoteManager.Get("AcceptOrder")
local acceptedEvent  = RemoteManager.Get("OrderAccepted")
local stateRemote    = RemoteManager.Get("GameStateChanged")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local posGui    = playerGui:WaitForChild("POSGui")

-- ─── State ────────────────────────────────────────────────────────────────────
local isOpen = false

-- ─── UI Builder ───────────────────────────────────────────────────────────────
local function buildOrderTicket(orderId, orderData, parent)
    local frame = Instance.new("Frame")
    frame.Name              = "Order_" .. orderId
    frame.Size              = UDim2.new(1, -10, 0, 80)
    frame.BackgroundColor3  = orderData.vipFlag
                              and Color3.fromRGB(255, 215, 0)
                              or  Color3.fromRGB(240, 240, 240)
    frame.BorderSizePixel   = 0
    frame.Parent            = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size              = UDim2.new(0.65, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3        = Color3.fromRGB(30, 30, 30)
    label.TextXAlignment    = Enum.TextXAlignment.Left
    label.TextScaled        = true
    label.Font              = Enum.Font.Gotham
    label.Text              = string.format("  %s  x%d%s",
        orderData.cookieId or "?",
        orderData.quantity or 1,
        orderData.vipFlag and "  [VIP]" or "")
    label.Parent            = frame

    local btn = Instance.new("TextButton")
    btn.Size                = UDim2.new(0.3, -5, 0.6, 0)
    btn.Position            = UDim2.new(0.68, 0, 0.2, 0)
    btn.BackgroundColor3    = Color3.fromRGB(80, 180, 100)
    btn.TextColor3          = Color3.fromRGB(255, 255, 255)
    btn.TextScaled          = true
    btn.Font                = Enum.Font.GothamBold
    btn.Text                = "Accept"
    btn.BorderSizePixel     = 0
    btn.Parent              = frame

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = btn

    btn.MouseButton1Click:Connect(function()
        acceptRemote:FireServer(orderId)
        frame:Destroy()
    end)
end

local function refreshPOS()
    local list = posGui:FindFirstChild("OrderList")
    if not list then return end
    for _, c in ipairs(list:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    local orders = OrderManager.GetNPCOrders()
    for id, data in pairs(orders) do
        buildOrderTicket(id, data, list)
    end
end

local function openPOS()
    if not isOpen then return end
    posGui.Enabled = true
    refreshPOS()
end

local function closePOS()
    posGui.Enabled = false
end

-- ─── POS ProximityPrompt ──────────────────────────────────────────────────────
ProximityPromptService.PromptTriggered:Connect(function(prompt, triggeringPlayer)
    if triggeringPlayer ~= player then return end
    if prompt.Name ~= "POSPrompt" then return end
    if posGui.Enabled then
        closePOS()
    else
        openPOS()
    end
end)

-- Close POS with Escape
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.Escape and posGui.Enabled then
        closePOS()
    end
end)

-- ─── Game State ───────────────────────────────────────────────────────────────
stateRemote.OnClientEvent:Connect(function(state)
    isOpen = (state == "Open")
    if not isOpen then closePOS() end
end)

-- ─── Order Accepted Feedback ──────────────────────────────────────────────────
acceptedEvent.OnClientEvent:Connect(function(orderId, orderData)
    print("[POSClient] Order accepted: " .. tostring(orderId))
    closePOS()
end)

print("[POSClient] Ready.")
