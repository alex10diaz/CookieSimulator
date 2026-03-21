-- src/StarterGui/HUD/HUDController.client.lua  (M7 Polish)
local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteManager  = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local stateRemote    = RemoteManager.Get("GameStateChanged")
local acceptedEvent  = RemoteManager.Get("OrderAccepted")
local deliveryEvent  = RemoteManager.Get("DeliveryResult")
local hudUpdateEvent          = RemoteManager.Get("HUDUpdate")
local warmersStockEvent       = RemoteManager.Get("WarmersUpdated")  -- P2-1: per-type stock
local npcOrderCancelledEvent  = RemoteManager.Get("NPCOrderCancelledClient")

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

local skipBtn = Instance.new("TextButton", hud)
skipBtn.Name = "SkipPreOpenBtn"; skipBtn.Size = UDim2.new(0,148,0,26)
skipBtn.Position = UDim2.new(0.5,-74,0,60); skipBtn.ZIndex = 5
skipBtn.BackgroundColor3 = Color3.fromRGB(40,40,50)
skipBtn.TextColor3 = Color3.fromRGB(160,160,170)
skipBtn.Font = Enum.Font.Gotham; skipBtn.TextSize = 13
skipBtn.Text = "Skip to Open  →"; skipBtn.Visible = false
Instance.new("UICorner", skipBtn).CornerRadius = UDim.new(0,8)
local _sk = Instance.new("UIStroke", skipBtn); _sk.Color = Color3.fromRGB(70,70,85); _sk.Thickness = 1

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

-- ── WARMER STOCK PILL (P2-1) ──────────────────────────────────────────────────
local stockPill, _ = pill("StockPill", 215, {1,-225}, {1,-60})
stockPill.Size     = UDim2.new(0, 215, 0, 42)
stockPill.Visible  = false  -- shown only during Open

local stockLbl = Instance.new("TextLabel", stockPill)
stockLbl.Name              = "StockLabel"
stockLbl.Size              = UDim2.new(1,-10,1,0)
stockLbl.Position          = UDim2.new(0,5,0,0)
stockLbl.BackgroundTransparency = 1
stockLbl.TextColor3        = C.MUTED
stockLbl.Font              = Enum.Font.Gotham
stockLbl.TextScaled        = false
stockLbl.TextSize          = 11
stockLbl.TextWrapped       = true
stockLbl.TextXAlignment    = Enum.TextXAlignment.Left
stockLbl.Text              = ""

local SHORT = {
    pink_sugar="Pink",chocolate_chip="Choc",birthday_cake="Bday",
    cookies_and_cream="C&C",snickerdoodle="Snick",lemon_blackraspberry="Lemon",
}
local function updateStockPill(stockByType)
    if not stockByType then stockPill.Visible = false; return end
    local parts = {}
    for id, n in pairs(stockByType) do
        if n > 0 then
            table.insert(parts, (SHORT[id] or id) .. ":" .. n)
        end
    end
    if #parts == 0 then
        stockLbl.Text = "Warmers empty"
        stockLbl.TextColor3 = C.MUTED
    else
        table.sort(parts)
        stockLbl.Text = table.concat(parts, "  ·  ")
        stockLbl.TextColor3 = C.WHITE
    end
end

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
-- Strips trailing quantity suffix (" x4", " ×4", " X4") from a display string.
-- Returns baseName, quantity (default qty=1 if no suffix found).
local function parseQty(s)
    local base, n = s:match("^(.-)%s+[xX](%d+)$")
    if base and n then return base, tonumber(n) end
    return s, 1
end

-- Short display names for variety order breakdowns
local SHORT_NAMES = {
    pink_sugar           = "Pink Sugar",
    chocolate_chip       = "Choc Chip",
    birthday_cake        = "Bday Cake",
    cookies_and_cream    = "C&C",
    snickerdoodle        = "Snickerdoodle",
    lemon_blackraspberry = "Lemon Berry",
}
local function buildVarietyLabel(items)
    if not items or #items == 0 then return "Mix" end
    local counts = {}; local order = {}
    for _, id in ipairs(items) do
        if not counts[id] then counts[id] = 0; table.insert(order, id) end
        counts[id] += 1
    end
    local parts = {}
    for _, id in ipairs(order) do
        local name = SHORT_NAMES[id] or cookieName(id)
        local cnt  = counts[id]
        table.insert(parts, cnt > 1 and (name .. " x" .. cnt) or name)
    end
    return table.concat(parts, ", ")
end

-- ── Event handlers ────────────────────────────────────────────────────────────
stateRemote.OnClientEvent:Connect(function(state, timeRemaining)
    local key = STATE_COLOR[state]
    local col = (key and key ~= "" and C[key]) or C.PANEL
    TweenService:Create(timerPill,  TI(0.25), { BackgroundColor3 = col }):Play()
    timerStroke.Color = (key and key ~= "") and col or C.MUTED
    timerLbl.Text = (STATE_LABELS[state] or state) .. "  " .. formatTime(timeRemaining or 0)
    timerPill.Visible = not (state == "PreOpen" and player:GetAttribute("InTutorial"))
    skipBtn.Visible = (state == "PreOpen" and not player:GetAttribute("InTutorial"))
    stockPill.Visible = (state == "Open")  -- P2-1: only show warmer stock during Open
    -- Clear active order pill when entering break or end-of-day
    if state == "Intermission" or state == "EndOfDay" then
        activeOrders = {}
        clearOrder()
        stockPill.Visible = false
    end
end)

player:GetAttributeChangedSignal("InTutorial"):Connect(function()
    if not player:GetAttribute("InTutorial") then timerPill.Visible = true end
end)

local skipRemote = RemoteManager.Get("SkipPreOpen")
skipBtn.MouseButton1Click:Connect(function()
    skipBtn.Visible = false
    skipRemote:FireServer()
end)

-- ── Active order tracking (supports multiple simultaneous orders) ─────────────
-- m4: entries are {orderId=N|nil, display="..."} so cancellation can match by ID
local activeOrders = {}  -- FIFO list of {orderId, display}

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
    -- Parse each entry into (baseName, qty) then aggregate totals by baseName
    local totals = {}   -- baseName -> total qty
    local order  = {}   -- insertion-order list of baseNames
    for _, entry in ipairs(activeOrders) do
        local base, qty = parseQty(entry.display)  -- m4: read from entry.display
        if not totals[base] then totals[base] = 0; table.insert(order, base) end
        totals[base] += qty
    end
    local lines = {}
    for _, base in ipairs(order) do
        local t = totals[base]
        table.insert(lines, t > 1 and (base .. " x" .. t) or base)
    end
    setOrder(table.concat(lines, "\n"))
end

hudUpdateEvent.OnClientEvent:Connect(function(coins, xp, activeOrderName)
    if coins then coinsLbl.Text = tostring(coins) end
    -- Server sends (nil,nil,name) when new order confirmed via cutscene
    if activeOrderName ~= nil then
        -- Normalize unicode × to ASCII x so parseQty works uniformly
        local normalized = tostring(activeOrderName):gsub("\xC3\x97", "x")
        table.insert(activeOrders, { orderId = nil, display = normalized })  -- m4: no orderId from hudUpdate
        refreshOrderPill()
    end
end)

-- POS tablet accept path: server sends cookieId + packSize (or isVariety + items)
acceptedEvent.OnClientEvent:Connect(function(orderId, orderData)
    if orderData and orderData.cookieId then
        local name
        if orderData.isVariety and orderData.items then
            name = buildVarietyLabel(orderData.items)
        else
            name = cookieName(orderData.cookieId)
            if orderData.packSize and orderData.packSize > 1 then
                name = name .. " x" .. orderData.packSize
            end
        end
        table.insert(activeOrders, { orderId = orderId, display = name })  -- m4: store orderId for cancel matching
        refreshOrderPill()
    end
end)

-- ── Delivery Flash ────────────────────────────────────────────────────────────
deliveryEvent.OnClientEvent:Connect(function(stars, coins, xp)
    -- deliveryEvent is the single source of truth for removal
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
    starRow.Text = string.rep("★",s) .. string.rep("☆",5-s) .. "  " .. s .. "/5"

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

-- P2-1: update per-type warmer stock pill (second arg added by MinigameServer broadcastState)
warmersStockEvent.OnClientEvent:Connect(function(_warmerState, stockByType)
    if stockByType then updateStockPill(stockByType) end
end)

-- NPC order cancelled (patience run out / NPC left before delivery)
npcOrderCancelledEvent.OnClientEvent:Connect(function(orderId, cookieId, packSize)
    if #activeOrders == 0 then return end
    -- m4: match by orderId first (reliable), then fall back to display-string match
    for i, entry in ipairs(activeOrders) do
        if (orderId and entry.orderId == orderId) then
            table.remove(activeOrders, i)
            refreshOrderPill()
            return
        end
    end
    -- Fallback: match by display string (for entries inserted via hudUpdateEvent without orderId)
    local targetName = cookieName(cookieId or "")
    if packSize and packSize > 1 then targetName = targetName .. " x" .. packSize end
    for i, entry in ipairs(activeOrders) do
        if entry.display == targetName then
            table.remove(activeOrders, i)
            refreshOrderPill()
            return
        end
    end
    -- Last resort: remove oldest
    table.remove(activeOrders, 1)
    refreshOrderPill()
end)

print("[HUDController] Ready.")
