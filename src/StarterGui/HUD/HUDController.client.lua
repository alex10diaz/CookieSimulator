-- src/StarterGui/HUD/HUDController.client.lua  (M7 Polish)
local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteManager  = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local stateRemote    = RemoteManager.Get("GameStateChanged")
local acceptedEvent  = RemoteManager.Get("OrderAccepted")
local deliveryEvent  = RemoteManager.Get("DeliveryResult")
local hudUpdateEvent    = RemoteManager.Get("HUDUpdate")
local warmersStockEvent = RemoteManager.Get("WarmersStockUpdate")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local hud       = playerGui:WaitForChild("HUD")

-- Remove legacy flat labels if they exist
for _, name in ipairs({"TimerLabel","CoinsLabel","ActiveOrderLabel"}) do
    local old = hud:FindFirstChild(name)
    if old then old:Destroy() end
end

-- ── Palette ───────────────────────────────────────────────────────────────────
local C = {
    PANEL    = Color3.fromRGB(18, 18, 32),
    GOLD     = Color3.fromRGB(255, 200, 0),
    GOLD_BTN = Color3.fromRGB(200, 155, 0),
    WHITE    = Color3.fromRGB(255, 255, 255),
    MUTED    = Color3.fromRGB(155, 155, 185),
    GREEN    = Color3.fromRGB(50, 185, 75),
    BLUE     = Color3.fromRGB(50, 115, 210),
    RED      = Color3.fromRGB(215, 60, 60),
    ORANGE   = Color3.fromRGB(235, 130, 35),
}
local TI = function(t) return TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end

-- ── Build pill ────────────────────────────────────────────────────────────────
local function pill(name, w, x, y, strokeColor)
    local old = hud:FindFirstChild(name)
    if old then old:Destroy() end
    local f = Instance.new("Frame")
    f.Name = name; f.Size = UDim2.new(0,w,0,42)
    f.Position = UDim2.new(x[1],x[2], y[1],y[2])
    f.BackgroundColor3 = C.PANEL; f.BackgroundTransparency = 0.08
    f.BorderSizePixel = 0; f.Parent = hud
    Instance.new("UICorner", f).CornerRadius = UDim.new(1, 0)
    local s = Instance.new("UIStroke", f)
    s.Color = strokeColor or C.MUTED; s.Thickness = 1.5; s.Transparency = 0.45
    return f, s
end

-- ── COIN PILL ─────────────────────────────────────────────────────────────────
local coinPill, coinStroke = pill("CoinPill", 162, {0,10}, {0,10}, C.GOLD)
coinStroke.Transparency = 0.35

local iconBadge = Instance.new("Frame", coinPill)
iconBadge.Size = UDim2.new(0,34,0,34); iconBadge.Position = UDim2.new(0,4,0.5,-17)
iconBadge.BackgroundColor3 = C.GOLD_BTN; iconBadge.BorderSizePixel = 0
Instance.new("UICorner", iconBadge).CornerRadius = UDim.new(1,0)
local iconLbl = Instance.new("TextLabel", iconBadge)
iconLbl.Size = UDim2.new(1,0,1,0); iconLbl.BackgroundTransparency = 1
iconLbl.TextColor3 = Color3.fromRGB(40,30,0); iconLbl.Font = Enum.Font.GothamBold
iconLbl.TextScaled = true; iconLbl.Text = "★"

local coinsLbl = Instance.new("TextLabel", coinPill)
coinsLbl.Name = "CoinsLabel"
coinsLbl.Size = UDim2.new(1,-46,1,0); coinsLbl.Position = UDim2.new(0,43,0,0)
coinsLbl.BackgroundTransparency = 1; coinsLbl.TextColor3 = C.GOLD
coinsLbl.Font = Enum.Font.GothamBold; coinsLbl.TextScaled = true
coinsLbl.TextXAlignment = Enum.TextXAlignment.Left; coinsLbl.Text = "0"

-- ── TIMER PILL ────────────────────────────────────────────────────────────────
local timerPill, timerStroke = pill("TimerPill", 225, {0.5,-112}, {0,10})

local timerLbl = Instance.new("TextLabel", timerPill)
timerLbl.Name = "TimerLabel"
timerLbl.Size = UDim2.new(1,-12,1,0); timerLbl.Position = UDim2.new(0,6,0,0)
timerLbl.BackgroundTransparency = 1; timerLbl.TextColor3 = C.WHITE
timerLbl.Font = Enum.Font.GothamBold; timerLbl.TextScaled = true; timerLbl.Text = "PRE-OPEN  5:00"

-- ── ORDER PILL ────────────────────────────────────────────────────────────────
local orderPill, orderStroke = pill("OrderPill", 215, {1,-225}, {0,10})
orderPill.Size = UDim2.new(0, 215, 0, 94)

local orderLbl = Instance.new("TextLabel", orderPill)
orderLbl.Name = "ActiveOrderLabel"
orderLbl.Size = UDim2.new(1,-14,1,0); orderLbl.Position = UDim2.new(0,7,0,0)
orderLbl.BackgroundTransparency = 1; orderLbl.TextColor3 = C.MUTED
orderLbl.Font = Enum.Font.Gotham; orderLbl.TextScaled = false
orderLbl.TextSize = 12; orderLbl.TextWrapped = true
orderLbl.Text = "No active order"

-- ── State helpers ─────────────────────────────────────────────────────────────
local STATE_COLOR = {
    Open="GREEN", Intermission="BLUE", EndOfDay="ORANGE", PreOpen="", Lobby=""
}
local STATE_LABELS = {
    PreOpen="PRE-OPEN", Open="OPEN", EndOfDay="END OF DAY",
    Lobby="LOBBY", Intermission="BREAK TIME",
}
local function formatTime(s)
    return string.format("%d:%02d", math.floor(s/60), s%60)
end
local function cookieName(id)
    if not id then return "" end
    return (id:gsub("_"," "):gsub("(%a)([%w]*)", function(a,b) return a:upper()..b end))
end

-- ── Event handlers ────────────────────────────────────────────────────────────
stateRemote.OnClientEvent:Connect(function(state, timeRemaining)
    local key = STATE_COLOR[state]
    local col = (key and key ~= "" and C[key]) or C.PANEL
    TweenService:Create(timerPill,  TI(0.25), { BackgroundColor3 = col }):Play()
    timerStroke.Color = (key and key ~= "") and col or C.MUTED
    timerLbl.Text = (STATE_LABELS[state] or state) .. "  " .. formatTime(timeRemaining or 0)
    timerPill.Visible = not (state == "PreOpen" and player:GetAttribute("InTutorial"))
end)

player:GetAttributeChangedSignal("InTutorial"):Connect(function()
    if not player:GetAttribute("InTutorial") then timerPill.Visible = true end
end)

-- ── Active order tracking (supports multiple simultaneous orders) ─────────────
local activeOrders = {}  -- FIFO list of cookieId strings

local function clearOrder()
    orderLbl.Text = "No active order"; orderLbl.TextColor3 = C.MUTED
    TweenService:Create(orderPill, TI(0.2), { BackgroundColor3 = C.PANEL }):Play()
    orderStroke.Color = C.MUTED; orderStroke.Transparency = 0.45
end
local function setOrder(name)
    orderLbl.Text = name; orderLbl.TextColor3 = C.WHITE
    TweenService:Create(orderPill, TI(0.2), { BackgroundColor3 = Color3.fromRGB(30,100,50) }):Play()
    orderStroke.Color = C.GREEN; orderStroke.Transparency = 0.2
end

local function refreshOrderPill()
    if #activeOrders == 0 then clearOrder(); return end
    local counts = {}; local order = {}
    for _, id in ipairs(activeOrders) do
        if not counts[id] then counts[id] = 0; table.insert(order, id) end
        counts[id] += 1
    end
    local lines = {}
    for _, id in ipairs(order) do
        local n = cookieName(id)
        table.insert(lines, counts[id] > 1 and (n .. " \xC3\x97" .. counts[id]) or n)
    end
    setOrder(table.concat(lines, "\n"))
end

hudUpdateEvent.OnClientEvent:Connect(function(coins, xp, activeOrderName)
    coinsLbl.Text = tostring(coins or 0)
    -- If server explicitly clears (nil name after delivery), sync by removing one entry
    if activeOrderName == nil and #activeOrders > 0 then
        table.remove(activeOrders, 1)
    end
    refreshOrderPill()
end)

acceptedEvent.OnClientEvent:Connect(function(orderId, orderData)
    if orderData and orderData.cookieId then
        table.insert(activeOrders, orderData.cookieId)
        refreshOrderPill()
    end
end)

-- ── Delivery Flash ────────────────────────────────────────────────────────────
deliveryEvent.OnClientEvent:Connect(function(stars, coins, xp)
    if #activeOrders > 0 then table.remove(activeOrders, 1) end
    refreshOrderPill()
    local s      = math.clamp(stars or 0, 0, 5)
    local isGood = s >= 4
    local bgCol  = isGood and Color3.fromRGB(28,85,35) or Color3.fromRGB(90,28,28)
    local acCol  = isGood and C.GOLD or C.RED

    local card = Instance.new("Frame", hud)
    card.Name = "DeliveryFlash"
    card.Size = UDim2.new(0,270,0,80); card.Position = UDim2.new(0.5,-135,0.37,-40)
    card.BackgroundColor3 = bgCol; card.BackgroundTransparency = 1
    card.BorderSizePixel = 0; card.ZIndex = 50
    Instance.new("UICorner", card).CornerRadius = UDim.new(0,14)

    local cs = Instance.new("UIStroke", card)
    cs.Color = acCol; cs.Thickness = 2.5; cs.Transparency = 1

    local starRow = Instance.new("TextLabel", card)
    starRow.Size = UDim2.new(1,0,0,40); starRow.Position = UDim2.new(0,0,0,4)
    starRow.BackgroundTransparency = 1; starRow.ZIndex = 51
    starRow.TextColor3 = C.GOLD; starRow.Font = Enum.Font.GothamBold
    starRow.TextScaled = true; starRow.TextTransparency = 1
    starRow.Text = string.rep("★",s) .. string.rep("☆",5-s)

    local coinRow = Instance.new("TextLabel", card)
    coinRow.Size = UDim2.new(1,0,0,30); coinRow.Position = UDim2.new(0,0,0,46)
    coinRow.BackgroundTransparency = 1; coinRow.ZIndex = 51
    coinRow.TextColor3 = C.WHITE; coinRow.Font = Enum.Font.Gotham
    coinRow.TextScaled = true; coinRow.TextTransparency = 1
    coinRow.Text = "+" .. (coins or 0) .. " coins"

    TweenService:Create(card,    TI(0.22), { BackgroundTransparency = 0 }):Play()
    TweenService:Create(cs,      TI(0.22), { Transparency = 0 }):Play()
    TweenService:Create(starRow, TI(0.22), { TextTransparency = 0 }):Play()
    TweenService:Create(coinRow, TI(0.3),  { TextTransparency = 0 }):Play()

    task.delay(2.2, function()
        if not card.Parent then return end
        local t = TweenService:Create(card, TI(0.35), { BackgroundTransparency=1 })
        TweenService:Create(cs,      TI(0.35), { Transparency=1 }):Play()
        TweenService:Create(starRow, TI(0.35), { TextTransparency=1 }):Play()
        TweenService:Create(coinRow, TI(0.35), { TextTransparency=1 }):Play()
        t:Play(); t.Completed:Connect(function() if card.Parent then card:Destroy() end end)
    end)
end)

-- warmersStockEvent kept for compatibility but display removed (names shown on warmer models)
warmersStockEvent.OnClientEvent:Connect(function() end)

print("[HUDController] Ready.")
