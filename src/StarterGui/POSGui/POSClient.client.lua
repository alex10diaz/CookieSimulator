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

-- ─── Build UI ─────────────────────────────────────────────────────────────────
local bg = posGui:FindFirstChild("Background")
if not bg then
    bg = Instance.new("Frame")
    bg.Name              = "Background"
    bg.Size              = UDim2.new(0, 360, 0, 480)
    bg.Position          = UDim2.new(0.5, -180, 0.5, -240)
    bg.BackgroundColor3  = Color3.fromRGB(20, 20, 20)
    bg.BackgroundTransparency = 0.1
    bg.BorderSizePixel   = 0
    bg.Parent            = posGui
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 12)
    c.Parent = bg

    local title = Instance.new("TextLabel")
    title.Name              = "Title"
    title.Size              = UDim2.new(1, 0, 0, 50)
    title.BackgroundTransparency = 1
    title.TextColor3        = Color3.fromRGB(255, 255, 255)
    title.TextScaled        = true
    title.Font              = Enum.Font.GothamBold
    title.Text              = "POS — Order Queue"
    title.Parent            = bg
end

local orderList = bg:FindFirstChild("OrderList")
if not orderList then
    orderList = Instance.new("ScrollingFrame")
    orderList.Name              = "OrderList"
    orderList.Size              = UDim2.new(1, -20, 1, -60)
    orderList.Position          = UDim2.new(0, 10, 0, 55)
    orderList.BackgroundTransparency = 1
    orderList.ScrollBarThickness = 4
    orderList.CanvasSize        = UDim2.new(0, 0, 0, 0)
    orderList.AutomaticCanvasSize = Enum.AutomaticSize.Y
    orderList.Parent            = bg
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 6)
    layout.Parent  = orderList
end

-- ─── State ────────────────────────────────────────────────────────────────────
local isOpen = false

-- ─── Order Tickets ────────────────────────────────────────────────────────────
local function buildOrderTicket(orderId, orderData, parent)
    local frame = Instance.new("Frame")
    frame.Name              = "Order_" .. orderId
    frame.Size              = UDim2.new(1, -10, 0, 80)
    frame.BackgroundColor3  = orderData.vipFlag
                              and Color3.fromRGB(255, 215, 0)
                              or  Color3.fromRGB(240, 240, 240)
    frame.BorderSizePixel   = 0
    frame.Parent            = parent
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 8)
    c.Parent = frame

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
    local bc = Instance.new("UICorner")
    bc.CornerRadius = UDim.new(0, 6)
    bc.Parent = btn

    btn.MouseButton1Click:Connect(function()
        acceptRemote:FireServer(orderId)
        frame:Destroy()
    end)
end

local function refreshPOS()
    for _, c in ipairs(orderList:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    local orders = OrderManager.GetNPCOrders()
    for _, data in ipairs(orders) do
        buildOrderTicket(data.orderId, data, orderList)
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

-- ─── Interactions ─────────────────────────────────────────────────────────────
ProximityPromptService.PromptTriggered:Connect(function(prompt, triggeringPlayer)
    if triggeringPlayer ~= player then return end
    if prompt.Name ~= "POSPrompt" then return end
    if posGui.Enabled then closePOS() else openPOS() end
end)

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.Escape and posGui.Enabled then
        closePOS()
    end
end)

stateRemote.OnClientEvent:Connect(function(state)
    isOpen = (state == "Open")
    if not isOpen then closePOS() end
end)

acceptedEvent.OnClientEvent:Connect(function(orderId, orderData)
    print("[POSClient] Order accepted: " .. tostring(orderId))
    closePOS()
end)

print("[POSClient] Ready.")
