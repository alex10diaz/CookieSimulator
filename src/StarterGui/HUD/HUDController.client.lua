-- HUDController.client.lua  (Redesign v2 — Bakery Theme)
-- Top Bar (coins, level/xp, timer, settings) + Order Card Panel + Coach Bar
local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteManager          = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local stateRemote            = RemoteManager.Get("GameStateChanged")
local acceptedEvent          = RemoteManager.Get("OrderAccepted")
local deliveryEvent          = RemoteManager.Get("DeliveryResult")
local hudUpdateEvent         = RemoteManager.Get("HUDUpdate")
local dataInitEvent          = RemoteManager.Get("PlayerDataInit")
local warmersStockEvent      = RemoteManager.Get("WarmersUpdated")

local EffectsModule
task.spawn(function() local ok,m = pcall(require, ReplicatedStorage:WaitForChild("Modules"):WaitForChild("EffectsModule")); if ok then EffectsModule = m end end)
local npcOrderCancelledEvent = RemoteManager.Get("NPCOrderCancelledClient")
local driveThruArrivedEvent  = RemoteManager.Get("DriveThruCarArrived")
local npcOrderFailedEvent    = RemoteManager.Get("NPCOrderFailed")
local comboUpdateEvent       = RemoteManager.Get("ComboUpdate")
local npcPatienceEvent       = RemoteManager.Get("NPCPatienceUpdate")
local boxCreatedEvent        = RemoteManager.Get("BoxCreated")
local deliveryFeedbackEvent  = RemoteManager.Get("DeliveryFeedback")
local workerFeedbackEvent    = RemoteManager.Get("WorkerFeedback")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local hud       = playerGui:WaitForChild("HUD")

-- Hide HUD during tutorial; restore when InTutorial clears
hud.Enabled = not player:GetAttribute("InTutorial")
player:GetAttributeChangedSignal("InTutorial"):Connect(function()
    hud.Enabled = not player:GetAttribute("InTutorial")
end)

-- Cached player data (initialized by PlayerDataInit, updated by HUDUpdate)
local localLevel = 1
local function xpRequired(lvl) return math.floor(100 * (lvl ^ 1.35)) end

-- Remove legacy elements
for _, name in ipairs({
    "TimerLabel","CoinsLabel","ActiveOrderLabel","CoinPill","TimerPill",
    "OrderPill","StockPill","SkipPreOpenBtn","CoachMark","ComboPill",
}) do
    local old = hud:FindFirstChild(name)
    if old then old:Destroy() end
end

-- ── Palette (baby blue / toothpaste + hot pink + gold) ─────────────────────
local C = {
    BG       = Color3.fromRGB(175, 218, 235),
    PANEL    = Color3.fromRGB(148, 195, 215),
    CARD     = Color3.fromRGB(238, 248, 255),
    WARM_BRN = Color3.fromRGB(220, 50, 120),
    BLUSH    = Color3.fromRGB(255, 140, 195),
    GOLD     = Color3.fromRGB(255, 205, 50),
    WHITE    = Color3.fromRGB(255, 255, 255),
    TEXT_DRK = Color3.fromRGB(15, 38, 70),
    TEXT_LT  = Color3.fromRGB(60, 95, 135),
    GREEN    = Color3.fromRGB(80, 215, 115),
    BLUE     = Color3.fromRGB(80, 175, 255),
    ORANGE   = Color3.fromRGB(235, 150, 55),
    RED      = Color3.fromRGB(220, 65, 65),
    YELLOW   = Color3.fromRGB(255, 225, 70),
}
local TI  = function(t) return TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
local TIB = function(t) return TweenInfo.new(t, Enum.EasingStyle.Back, Enum.EasingDirection.Out) end

-- ── Helpers ───────────────────────────────────────────────────────────────────
local function corner(parent, radius)
    local c = Instance.new("UICorner", parent)
    c.CornerRadius = UDim.new(0, radius or 10)
end
local function addStroke(parent, color, thickness, alpha)
    local s = Instance.new("UIStroke", parent)
    s.Color = color; s.Thickness = thickness or 1.5; s.Transparency = alpha or 0.5
    return s
end
local function formatTime(s)
    return string.format("%d:%02d", math.floor(s/60), s%60)
end
local function spawnFloatingReward(coinsAmt, xpAmt)
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local bb = Instance.new("BillboardGui", hrp)
    bb.Name            = "FloatingReward"
    bb.Size            = UDim2.new(0, 180, 0, 44)
    bb.StudsOffset     = Vector3.new(0, 3.5, 0)
    bb.AlwaysOnTop     = false
    bb.ResetOnSpawn    = false
    bb.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
    local lbl = Instance.new("TextLabel", bb)
    lbl.Size                  = UDim2.fromScale(1, 1)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3            = C.GOLD
    lbl.Font                  = Enum.Font.GothamBold
    lbl.TextScaled            = true
    lbl.TextStrokeTransparency = 0.4
    lbl.TextStrokeColor3      = Color3.fromRGB(0, 0, 0)
    local parts = {}
    if coinsAmt and coinsAmt > 0 then table.insert(parts, "+"..coinsAmt.." coins") end
    if xpAmt    and xpAmt    > 0 then table.insert(parts, "+"..xpAmt.." XP")    end
    lbl.Text = table.concat(parts, "  ")
    TweenService:Create(bb,  TI(1.4), { StudsOffset = Vector3.new(0, 7, 0) }):Play()
    local t = TweenService:Create(lbl, TI(1.4), { TextTransparency = 1 })
    t:Play()
    t.Completed:Connect(function() if bb.Parent then bb:Destroy() end end)
end
local function cookieName(id)
    if not id then return "" end
    return (id:gsub("_"," "):gsub("(%a)([%w]*)", function(a,b) return a:upper()..b end))
end
local function parseQty(s)
    local base, n = s:match("^(.-)%s+[xX×](%d+)$")
    if base and n then return base, tonumber(n) end
    return s, 1
end
local SHORT_NAMES = {
    pink_sugar="Pink Sugar", chocolate_chip="Choc Chip", birthday_cake="Bday Cake",
    cookies_and_cream="C&C", snickerdoodle="Snickerdoodle", lemon_blackraspberry="Lemon Berry",
}
local function buildVarietyLabel(items)
    if not items or #items == 0 then return "Mix" end
    local counts, order = {}, {}
    for _, id in ipairs(items) do
        if not counts[id] then counts[id]=0; table.insert(order,id) end
        counts[id] += 1
    end
    local parts = {}
    for _, id in ipairs(order) do
        local nm = SHORT_NAMES[id] or cookieName(id)
        table.insert(parts, counts[id] > 1 and (nm.." x"..counts[id]) or nm)
    end
    return table.concat(parts, ", ")
end

-- ══════════════════════════════════════════════════════════════════════════════
-- TOP BAR
-- ══════════════════════════════════════════════════════════════════════════════
local topBar = Instance.new("Frame", hud)
topBar.Name = "TopBar"
topBar.Size = UDim2.new(1, 0, 0, 52)
topBar.Position = UDim2.new(0, 0, 0, 0)
topBar.BackgroundColor3 = C.BG
topBar.BackgroundTransparency = 0.06
topBar.BorderSizePixel = 0
topBar.ZIndex = 10

local botLine = Instance.new("Frame", topBar)
botLine.Size = UDim2.new(1,0,0,1); botLine.Position = UDim2.new(0,0,1,-1)
botLine.BackgroundColor3 = C.WARM_BRN; botLine.BackgroundTransparency = 0.5
botLine.BorderSizePixel = 0; botLine.ZIndex = 11

-- COIN BADGE
local coinBadge = Instance.new("Frame", topBar)
coinBadge.Name = "CoinBadge"
coinBadge.Size = UDim2.new(0, 148, 0, 36)
coinBadge.Position = UDim2.new(0, 10, 0.5, -18)
coinBadge.BackgroundColor3 = Color3.fromRGB(125, 172, 198)
coinBadge.BackgroundTransparency = 0.15
coinBadge.BorderSizePixel = 0; coinBadge.ZIndex = 11
corner(coinBadge, 20); addStroke(coinBadge, C.GOLD, 1.5, 0.4)

local coinIconLbl = Instance.new("TextLabel", coinBadge)
coinIconLbl.Size = UDim2.new(0, 26, 1, -4); coinIconLbl.Position = UDim2.new(0, 5, 0, 2)
coinIconLbl.BackgroundTransparency = 1; coinIconLbl.TextColor3 = C.GOLD
coinIconLbl.Font = Enum.Font.GothamBold; coinIconLbl.TextScaled = true
coinIconLbl.Text = "💰"; coinIconLbl.ZIndex = 12

local coinsLbl = Instance.new("TextLabel", coinBadge)
coinsLbl.Name = "CoinsLabel"
coinsLbl.Size = UDim2.new(1, -36, 1, 0); coinsLbl.Position = UDim2.new(0, 34, 0, 0)
coinsLbl.BackgroundTransparency = 1; coinsLbl.TextColor3 = C.GOLD
coinsLbl.Font = Enum.Font.GothamBold; coinsLbl.TextScaled = true
coinsLbl.TextXAlignment = Enum.TextXAlignment.Left
coinsLbl.Text = "0"; coinsLbl.ZIndex = 12

-- LEVEL / XP BADGE
local lvlBadge = Instance.new("Frame", topBar)
lvlBadge.Name = "LevelBadge"
lvlBadge.Size = UDim2.new(0, 185, 0, 38)
lvlBadge.Position = UDim2.new(0, 166, 0.5, -19)
lvlBadge.BackgroundColor3 = Color3.fromRGB(125, 172, 198)
lvlBadge.BackgroundTransparency = 0.15
lvlBadge.BorderSizePixel = 0; lvlBadge.ZIndex = 11
corner(lvlBadge, 10)
local lvlStroke = addStroke(lvlBadge, C.TEXT_LT, 1.5, 0.5)

local levelLbl = Instance.new("TextLabel", lvlBadge)
levelLbl.Name = "LevelLabel"
levelLbl.Size = UDim2.new(0, 68, 0, 20); levelLbl.Position = UDim2.new(0, 8, 0, 5)
levelLbl.BackgroundTransparency = 1; levelLbl.TextColor3 = C.TEXT_DRK
levelLbl.Font = Enum.Font.GothamBold; levelLbl.TextScaled = true
levelLbl.TextXAlignment = Enum.TextXAlignment.Left
levelLbl.Text = "Lv. 1"; levelLbl.ZIndex = 12

local xpLbl = Instance.new("TextLabel", lvlBadge)
xpLbl.Name = "XPLabel"
xpLbl.Size = UDim2.new(1, -80, 0, 18); xpLbl.Position = UDim2.new(0, 78, 0, 4)
xpLbl.BackgroundTransparency = 1; xpLbl.TextColor3 = C.TEXT_LT
xpLbl.Font = Enum.Font.Gotham; xpLbl.TextScaled = true
xpLbl.TextXAlignment = Enum.TextXAlignment.Right
xpLbl.Text = "0 xp"; xpLbl.ZIndex = 12

local xpTrack = Instance.new("Frame", lvlBadge)
xpTrack.Size = UDim2.new(1, -12, 0, 6); xpTrack.Position = UDim2.new(0, 6, 1, -10)
xpTrack.BackgroundColor3 = Color3.fromRGB(155, 195, 215); xpTrack.BorderSizePixel = 0; xpTrack.ZIndex = 12
corner(xpTrack, 4)

local xpFill = Instance.new("Frame", xpTrack)
xpFill.Name = "XPFill"
xpFill.Size = UDim2.new(0.05, 0, 1, 0)
xpFill.BackgroundColor3 = C.TEXT_DRK; xpFill.BorderSizePixel = 0; xpFill.ZIndex = 13
corner(xpFill, 4)

-- TIMER BADGE (center)
local timerBadge = Instance.new("Frame", topBar)
timerBadge.Name = "TimerBadge"
timerBadge.Size = UDim2.new(0, 200, 0, 38)
timerBadge.Position = UDim2.new(0.5, -100, 0.5, -19)
timerBadge.BackgroundColor3 = C.PANEL
timerBadge.BackgroundTransparency = 0.1
timerBadge.BorderSizePixel = 0; timerBadge.ZIndex = 11
corner(timerBadge, 10)
local timerStroke = addStroke(timerBadge, C.TEXT_LT, 1.5, 0.5)

local timerLbl = Instance.new("TextLabel", timerBadge)
timerLbl.Name = "TimerLabel"
timerLbl.Size = UDim2.new(1, -10, 1, 0); timerLbl.Position = UDim2.new(0, 5, 0, 0)
timerLbl.BackgroundTransparency = 1; timerLbl.TextColor3 = C.WHITE
timerLbl.Font = Enum.Font.GothamBold; timerLbl.TextScaled = true
timerLbl.Text = "LOADING..."; timerLbl.ZIndex = 12

-- SETTINGS BUTTON
local settingsBtn = Instance.new("TextButton", topBar)
settingsBtn.Name = "SettingsBtn"
settingsBtn.Size = UDim2.new(0, 40, 0, 40); settingsBtn.Position = UDim2.new(1, -50, 0.5, -20)
settingsBtn.BackgroundColor3 = C.PANEL; settingsBtn.BackgroundTransparency = 0.3
settingsBtn.BorderSizePixel = 0; settingsBtn.ZIndex = 11
settingsBtn.Text = "⚙"; settingsBtn.TextColor3 = C.TEXT_LT
settingsBtn.Font = Enum.Font.GothamBold; settingsBtn.TextSize = 22
corner(settingsBtn, 10); addStroke(settingsBtn, C.TEXT_LT, 1, 0.65)

-- SKIP BUTTON
local skipBtn = Instance.new("TextButton", hud)
skipBtn.Name = "SkipPreOpenBtn"
skipBtn.Size = UDim2.new(0, 148, 0, 26); skipBtn.Position = UDim2.new(0.5, -74, 0, 60)
skipBtn.ZIndex = 5; skipBtn.BackgroundColor3 = Color3.fromRGB(148, 195, 215)
skipBtn.TextColor3 = Color3.fromRGB(25, 55, 100); skipBtn.Font = Enum.Font.Gotham
skipBtn.TextSize = 13; skipBtn.Text = "Skip to Open  →"; skipBtn.Visible = false
corner(skipBtn, 8); addStroke(skipBtn, Color3.fromRGB(80, 130, 170), 1, 0)

-- ══════════════════════════════════════════════════════════════════════════════
-- ORDERS PANEL (LEFT)
-- ══════════════════════════════════════════════════════════════════════════════
local ordersPanel = Instance.new("Frame", hud)
ordersPanel.Name = "OrdersPanel"
ordersPanel.Size = UDim2.new(0, 176, 1, -322)
ordersPanel.Position = UDim2.new(0, 8, 0, 110)
ordersPanel.BackgroundColor3 = C.BG
ordersPanel.BackgroundTransparency = 0.12
ordersPanel.BorderSizePixel = 0; ordersPanel.ZIndex = 8
corner(ordersPanel, 12); addStroke(ordersPanel, C.WARM_BRN, 1.5, 0.55)

local ordersList = Instance.new("ScrollingFrame", ordersPanel)
ordersList.Name = "OrdersList"
ordersList.Size = UDim2.new(1, -6, 1, -8); ordersList.Position = UDim2.new(0, 3, 0, 4)
ordersList.BackgroundTransparency = 1; ordersList.BorderSizePixel = 0
ordersList.ScrollBarThickness = 0; ordersList.ZIndex = 9
ordersList.CanvasSize = UDim2.new(0,0,0,0)
ordersList.AutomaticCanvasSize = Enum.AutomaticSize.Y

local olLayout = Instance.new("UIListLayout", ordersList)
olLayout.Padding = UDim.new(0, 6)
olLayout.FillDirection = Enum.FillDirection.Vertical
olLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
olLayout.SortOrder = Enum.SortOrder.LayoutOrder

local olPad = Instance.new("UIPadding", ordersList)
olPad.PaddingTop = UDim.new(0,4); olPad.PaddingBottom = UDim.new(0,4)
olPad.PaddingLeft = UDim.new(0,2); olPad.PaddingRight = UDim.new(0,2)

local emptyLbl = Instance.new("TextLabel", ordersList)
emptyLbl.Name = "EmptyLabel"; emptyLbl.Size = UDim2.new(1,0,0,80)
emptyLbl.BackgroundTransparency = 1; emptyLbl.TextColor3 = C.TEXT_LT
emptyLbl.Font = Enum.Font.Gotham; emptyLbl.TextSize = 12
emptyLbl.TextWrapped = true; emptyLbl.ZIndex = 10
emptyLbl.Text = "No orders yet\n\nWait for\ncustomers!"

-- ══════════════════════════════════════════════════════════════════════════════
-- ORDER CARD SYSTEM
-- ══════════════════════════════════════════════════════════════════════════════
local orderCards   = {}  -- key -> Frame
local activeOrders = {}  -- { orderId, display, tempKey }
local patienceMap  = {}  -- orderId -> ratio (0-1)
local flashTweens  = {}  -- key -> Tween (looping red flash)
local tempKeyN     = 0
local showAlert    -- forward declaration (defined later, used in acceptedEvent handler)

local function cardKey(entry)
    return entry.orderId and tostring(entry.orderId) or entry.tempKey
end

-- Cookie-type accent colors for order card borders/dots
local COOKIE_COLORS = {
    pink_sugar           = Color3.fromRGB(255,170,190),
    chocolate_chip       = Color3.fromRGB(160,100,50),
    birthday_cake        = Color3.fromRGB(255,220,100),
    cookies_and_cream    = Color3.fromRGB(160,160,175),
    snickerdoodle        = Color3.fromRGB(210,145,70),
    lemon_blackraspberry = Color3.fromRGB(200,225,60),
}
local function cookieAccent(id)
    return COOKIE_COLORS[id] or Color3.fromRGB(80,150,220)
end

local function createCard(key, displayName, isVIP, cookieId)
    if orderCards[key] then orderCards[key]:Destroy() end
    emptyLbl.Visible = false

    local card = Instance.new("Frame", ordersList)
    card.Name = "Card_" .. key
    card.Size = UDim2.new(1, -4, 0, 100)
    card.BackgroundColor3 = C.CARD; card.BackgroundTransparency = 0.04
    card.BorderSizePixel = 0; card.ZIndex = 10
    corner(card, 8)
    local cStroke = addStroke(card, cookieAccent(cookieId), 1.5, 0.3)

    -- Status row
    local dot = Instance.new("Frame", card)
    dot.Name = "StatusDot"; dot.Size = UDim2.new(0,8,0,8); dot.Position = UDim2.new(0,8,0,10)
    dot.BackgroundColor3 = cookieAccent(cookieId); dot.BorderSizePixel = 0; dot.ZIndex = 11
    corner(dot, 4)

    local statusLbl = Instance.new("TextLabel", card)
    statusLbl.Name = "StatusLabel"
    statusLbl.Size = UDim2.new(0,82,0,16); statusLbl.Position = UDim2.new(0,20,0,6)
    statusLbl.BackgroundTransparency = 1; statusLbl.TextColor3 = cookieAccent(cookieId)
    statusLbl.Font = Enum.Font.GothamBold; statusLbl.TextSize = 11
    statusLbl.TextXAlignment = Enum.TextXAlignment.Left
    statusLbl.Text = "NEW"; statusLbl.ZIndex = 11

    if isVIP then
        local vip = Instance.new("TextLabel", card)
        vip.Size = UDim2.new(0,38,0,16); vip.Position = UDim2.new(1,-42,0,6)
        vip.BackgroundColor3 = C.GOLD; vip.BackgroundTransparency = 0.2
        vip.BorderSizePixel = 0; vip.ZIndex = 12
        vip.TextColor3 = Color3.fromRGB(80,60,0); vip.Font = Enum.Font.GothamBold
        vip.TextSize = 10; vip.Text = "VIP ⭐"
        corner(vip, 6)
    end

    -- Divider
    local div = Instance.new("Frame", card)
    div.Size = UDim2.new(1,-16,0,1); div.Position = UDim2.new(0,8,0,26)
    div.BackgroundColor3 = C.WARM_BRN; div.BackgroundTransparency = 0.7
    div.BorderSizePixel = 0; div.ZIndex = 11

    -- Cookie label
    local cookieLbl = Instance.new("TextLabel", card)
    cookieLbl.Name = "CookieLabel"
    cookieLbl.Size = UDim2.new(1,-16,0,40); cookieLbl.Position = UDim2.new(0,8,0,30)
    cookieLbl.BackgroundTransparency = 1; cookieLbl.TextColor3 = C.TEXT_DRK
    cookieLbl.Font = Enum.Font.GothamBold; cookieLbl.TextSize = 13
    cookieLbl.TextWrapped = true; cookieLbl.TextXAlignment = Enum.TextXAlignment.Left
    cookieLbl.TextYAlignment = Enum.TextYAlignment.Top
    cookieLbl.Text = "🍪 " .. displayName; cookieLbl.ZIndex = 11

    -- Patience bar
    local pTrack = Instance.new("Frame", card)
    pTrack.Size = UDim2.new(1,-16,0,5); pTrack.Position = UDim2.new(0,8,1,-13)
    pTrack.BackgroundColor3 = Color3.fromRGB(190, 215, 228); pTrack.BackgroundTransparency = 0.5
    pTrack.BorderSizePixel = 0; pTrack.ZIndex = 11
    corner(pTrack, 3)

    local pFill = Instance.new("Frame", pTrack)
    pFill.Name = "PatienceFill"; pFill.Size = UDim2.new(1,0,1,0)
    pFill.BackgroundColor3 = C.GREEN; pFill.BorderSizePixel = 0; pFill.ZIndex = 12
    corner(pFill, 3)

    -- Flash overlay (red, shown last 15s of patience)
    local flashOverlay = Instance.new("Frame", card)
    flashOverlay.Name = "FlashOverlay"
    flashOverlay.Size = UDim2.new(1, 0, 1, 0)
    flashOverlay.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
    flashOverlay.BackgroundTransparency = 1
    flashOverlay.BorderSizePixel = 0
    flashOverlay.ZIndex = 13
    Instance.new("UICorner", flashOverlay).CornerRadius = UDim.new(0, 8)

    -- Slide-in animation (from left)
    card.Position = UDim2.new(-1.5, 0, 0, 0)
    TweenService:Create(card, TIB(0.35), { Position = UDim2.new(0,0,0,0) }):Play()

    orderCards[key] = card
    return card
end

local function removeCard(key)
    local card = orderCards[key]
    if not card then return end
    orderCards[key] = nil
    if flashTweens[key] then flashTweens[key]:Cancel(); flashTweens[key] = nil end
    local t = TweenService:Create(card, TI(0.22), {
        BackgroundTransparency = 1,
        Position = UDim2.new(1.5, 0, 0, 0),
    })
    t:Play()
    t.Completed:Connect(function() if card.Parent then card:Destroy() end end)
    task.defer(function()
        local any = false
        for _ in pairs(orderCards) do any = true; break end
        emptyLbl.Visible = not any
    end)
end

local function updatePatience(key, ratio, current)
    local card = orderCards[key]
    if not card then return end
    local fill    = card:FindFirstChild("PatienceFill", true)
    local dot     = card:FindFirstChild("StatusDot")
    local slbl    = card:FindFirstChild("StatusLabel")
    local cstk    = card:FindFirstChildOfClass("UIStroke")
    local overlay = card:FindFirstChild("FlashOverlay")
    if not fill then return end
    local col = ratio > 0.5 and C.GREEN or (ratio > 0.25 and C.ORANGE or C.RED)
    local txt = ratio > 0.5 and "NEW" or (ratio > 0.25 and "WAITING" or "LATE!")
    TweenService:Create(fill, TI(0.5), { Size = UDim2.new(ratio,0,1,0), BackgroundColor3 = col }):Play()
    if dot  then dot.BackgroundColor3 = col end
    if slbl then slbl.TextColor3 = col; slbl.Text = txt end
    if cstk then cstk.Color = col end
    -- Flash overlay: pulse last 15 seconds
    if overlay then
        if current and current <= 15 then
            if not flashTweens[key] then
                overlay.BackgroundTransparency = 1
                local ft = TweenService:Create(overlay,
                    TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
                    { BackgroundTransparency = 0.95 })
                ft:Play()
                flashTweens[key] = ft
            end
        else
            if flashTweens[key] then
                flashTweens[key]:Cancel()
                flashTweens[key] = nil
                if overlay then overlay.BackgroundTransparency = 1 end
            end
        end
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- COACH BAR (bottom center)
-- ══════════════════════════════════════════════════════════════════════════════
local coachBar = Instance.new("Frame", hud)
coachBar.Name = "CoachBar"
coachBar.Size = UDim2.new(0.65, 0, 0, 34)
coachBar.Position = UDim2.new(0.20, 0, 1, -50)
coachBar.BackgroundColor3 = Color3.fromRGB(175, 218, 235)
coachBar.BackgroundTransparency = 0.1; coachBar.BorderSizePixel = 0
coachBar.ZIndex = 20; coachBar.Visible = false
corner(coachBar, 20); addStroke(coachBar, C.BLUSH, 1, 0.5)

local coachLbl = Instance.new("TextLabel", coachBar)
coachLbl.Name = "CoachLabel"
coachLbl.Size = UDim2.new(1,-16,1,0); coachLbl.Position = UDim2.new(0,8,0,0)
coachLbl.BackgroundTransparency = 1; coachLbl.TextColor3 = C.WHITE
coachLbl.Font = Enum.Font.Gotham; coachLbl.TextSize = 13; coachLbl.TextScaled = true
coachLbl.ZIndex = 21
coachLbl.Text = "Mix → Dough → Oven → Dress → Deliver"

-- ══════════════════════════════════════════════════════════════════════════════
-- COMBO PILL
-- ══════════════════════════════════════════════════════════════════════════════
local comboPill = Instance.new("Frame", hud)
comboPill.Name = "ComboPill"
comboPill.Size = UDim2.new(0, 138, 0, 34); comboPill.Position = UDim2.new(0.5,-69,1,-90)
comboPill.BackgroundColor3 = Color3.fromRGB(185, 30, 95); comboPill.BackgroundTransparency = 1
comboPill.BorderSizePixel = 0; comboPill.ZIndex = 30
corner(comboPill, 20)

local comboLbl = Instance.new("TextLabel", comboPill)
comboLbl.Name = "ComboLabel"; comboLbl.Size = UDim2.new(1,0,1,0)
comboLbl.BackgroundTransparency = 1; comboLbl.TextColor3 = Color3.fromRGB(255,200,80)
comboLbl.Font = Enum.Font.GothamBold; comboLbl.TextScaled = true; comboLbl.ZIndex = 31
comboLbl.Text = ""  -- prevent default "Label" showing as gold text

-- ══════════════════════════════════════════════════════════════════════════════
-- SETTINGS PANEL
-- ══════════════════════════════════════════════════════════════════════════════
local settingsPanel = Instance.new("Frame", hud)
settingsPanel.Name = "SettingsPanel"
settingsPanel.Size = UDim2.new(0, 220, 0, 148)
settingsPanel.Position = UDim2.new(1, -230, 0, 58)
settingsPanel.BackgroundColor3 = C.CARD
settingsPanel.BackgroundTransparency = 0.06
settingsPanel.BorderSizePixel = 0; settingsPanel.ZIndex = 50
settingsPanel.Visible = false
corner(settingsPanel, 12); addStroke(settingsPanel, C.WARM_BRN, 2, 0.2)
local sHdr = Instance.new("Frame", settingsPanel)
sHdr.Size = UDim2.new(1,0,0,34); sHdr.BackgroundColor3 = C.WARM_BRN
sHdr.BackgroundTransparency = 0.1; sHdr.BorderSizePixel = 0; sHdr.ZIndex = 51
corner(sHdr, 12)
local sHdrFlat = Instance.new("Frame", sHdr)
sHdrFlat.Size = UDim2.new(1,0,0.5,0); sHdrFlat.Position = UDim2.new(0,0,0.5,0)
sHdrFlat.BackgroundColor3 = C.WARM_BRN; sHdrFlat.BackgroundTransparency = 0.1
sHdrFlat.BorderSizePixel = 0; sHdrFlat.ZIndex = 51
local sTitle = Instance.new("TextLabel", sHdr)
sTitle.Size = UDim2.new(1,-40,1,0); sTitle.Position = UDim2.new(0,12,0,0)
sTitle.BackgroundTransparency = 1; sTitle.TextColor3 = C.WHITE
sTitle.Font = Enum.Font.GothamBold; sTitle.TextSize = 14
sTitle.TextXAlignment = Enum.TextXAlignment.Left
sTitle.Text = "\xe2\x9a\x99  Settings"; sTitle.ZIndex = 52
local sClose = Instance.new("TextButton", sHdr)
sClose.Size = UDim2.new(0,30,0,30); sClose.Position = UDim2.new(1,-34,0.5,-15)
sClose.BackgroundTransparency = 1; sClose.TextColor3 = C.WHITE
sClose.Font = Enum.Font.GothamBold; sClose.TextSize = 16
sClose.Text = "\xe2\x9c\x95"; sClose.ZIndex = 52; sClose.BorderSizePixel = 0
local function makeToggle(yPos, icon, label, attrName)
    local row = Instance.new("Frame", settingsPanel)
    row.Size = UDim2.new(1,-16,0,44); row.Position = UDim2.new(0,8,0,yPos)
    row.BackgroundTransparency = 1; row.BorderSizePixel = 0; row.ZIndex = 51
    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(0.7,0,1,0); lbl.BackgroundTransparency = 1
    lbl.TextColor3 = C.TEXT_DRK; lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.ZIndex = 52
    lbl.Text = icon .. "  " .. label
    local btn = Instance.new("TextButton", row)
    btn.Size = UDim2.new(0,64,0,30); btn.Position = UDim2.new(1,-64,0.5,-15)
    btn.BorderSizePixel = 0; btn.ZIndex = 52
    btn.Font = Enum.Font.GothamBold; btn.TextSize = 12
    btn.TextColor3 = C.WHITE; btn.AutoButtonColor = false
    corner(btn, 8)
    player:SetAttribute(attrName, true)
    local function refresh()
        local on = player:GetAttribute(attrName) ~= false
        btn.BackgroundColor3 = on and C.GREEN or C.RED
        btn.Text = on and "ON" or "OFF"
        local ss = game:GetService("SoundService")
        for _, snd in ipairs(ss:GetDescendants()) do
            if snd:IsA("Sound") then
                local isMusic = snd.Name == "BakeryMusic"
                if attrName == "MusicEnabled" and isMusic then
                    snd.Volume = on and 0.10 or 0
                elseif attrName == "SFXEnabled" and not isMusic then
                    snd.Volume = on and (snd.Volume > 0 and snd.Volume or 0.25) or 0
                end
            end
        end
    end
    refresh()
    btn.MouseButton1Click:Connect(function()
        player:SetAttribute(attrName, not (player:GetAttribute(attrName) ~= false))
        refresh()
    end)
end
makeToggle(42, "\xf0\x9f\x8e\xb5", "Music",    "MusicEnabled")
makeToggle(94, "\xf0\x9f\x94\x8a", "Sound FX", "SFXEnabled")
local settingsOpen = false
local function toggleSettings()
    settingsOpen = not settingsOpen
    settingsPanel.Visible = settingsOpen
    if settingsOpen then
        settingsPanel.BackgroundTransparency = 1
        TweenService:Create(settingsPanel, TIB(0.25), { BackgroundTransparency = 0.06 }):Play()
    end
end
sClose.MouseButton1Click:Connect(function() settingsOpen = false; settingsPanel.Visible = false end)

-- ══════════════════════════════════════════════════════════════════════════════
-- TRAY PANEL (right side — what the player is currently carrying)
-- ══════════════════════════════════════════════════════════════════════════════
local trayPanel = Instance.new("Frame", hud)
trayPanel.Name = "TrayPanel"
trayPanel.Size = UDim2.new(0, 160, 0, 92)
trayPanel.Position = UDim2.new(1, 180, 0, 58)
trayPanel.BackgroundColor3 = C.CARD
trayPanel.BackgroundTransparency = 0.06
trayPanel.BorderSizePixel = 0; trayPanel.ZIndex = 8
corner(trayPanel, 10); addStroke(trayPanel, C.WARM_BRN, 1.5, 0.3)

local trayHdr = Instance.new("Frame", trayPanel)
trayHdr.Size = UDim2.new(1, 0, 0, 28); trayHdr.Position = UDim2.new(0, 0, 0, 0)
trayHdr.BackgroundColor3 = C.WARM_BRN; trayHdr.BackgroundTransparency = 0.15
trayHdr.BorderSizePixel = 0; trayHdr.ZIndex = 9
corner(trayHdr, 10)
local trayHdrFlat = Instance.new("Frame", trayHdr)
trayHdrFlat.Size = UDim2.new(1,0,0.5,0); trayHdrFlat.Position = UDim2.new(0,0,0.5,0)
trayHdrFlat.BackgroundColor3 = C.WARM_BRN; trayHdrFlat.BackgroundTransparency = 0.15
trayHdrFlat.BorderSizePixel = 0; trayHdrFlat.ZIndex = 9

local trayHdrLbl = Instance.new("TextLabel", trayHdr)
trayHdrLbl.Size = UDim2.new(1,-8,1,0); trayHdrLbl.Position = UDim2.new(0,8,0,0)
trayHdrLbl.BackgroundTransparency = 1; trayHdrLbl.TextColor3 = C.WHITE
trayHdrLbl.Font = Enum.Font.GothamBold; trayHdrLbl.TextSize = 12
trayHdrLbl.TextXAlignment = Enum.TextXAlignment.Left
trayHdrLbl.Text = "📦  CARRYING"; trayHdrLbl.ZIndex = 10

local trayCookieLbl = Instance.new("TextLabel", trayPanel)
trayCookieLbl.Name = "TrayCookieLabel"
trayCookieLbl.Size = UDim2.new(1,-12,0,36); trayCookieLbl.Position = UDim2.new(0,6,0,32)
trayCookieLbl.BackgroundTransparency = 1; trayCookieLbl.TextColor3 = C.TEXT_DRK
trayCookieLbl.Font = Enum.Font.GothamBold; trayCookieLbl.TextSize = 13
trayCookieLbl.TextWrapped = true; trayCookieLbl.TextXAlignment = Enum.TextXAlignment.Left
trayCookieLbl.TextYAlignment = Enum.TextYAlignment.Center
trayCookieLbl.Text = "🍪 Cookie"; trayCookieLbl.ZIndex = 9

local trayQualityLbl = Instance.new("TextLabel", trayPanel)
trayQualityLbl.Name = "TrayQualityLabel"
trayQualityLbl.Size = UDim2.new(1,-12,0,20); trayQualityLbl.Position = UDim2.new(0,6,0,68)
trayQualityLbl.BackgroundTransparency = 1; trayQualityLbl.TextColor3 = C.GOLD
trayQualityLbl.Font = Enum.Font.GothamBold; trayQualityLbl.TextSize = 12
trayQualityLbl.TextXAlignment = Enum.TextXAlignment.Left
trayQualityLbl.Text = "★★★★☆"; trayQualityLbl.ZIndex = 9

local trayVisible = false
local TRAY_SHOW_X = UDim2.new(1, -168, 0, 58)
local TRAY_HIDE_X = UDim2.new(1, 180, 0, 58)

local function showTray(name, pct)
    local stars = math.clamp(math.round((pct or 0) / 20), 0, 5)
    trayCookieLbl.Text = "🍪 " .. (name or "Cookie")
    trayQualityLbl.Text = string.rep("★", stars) .. string.rep("☆", 5 - stars) .. "  " .. stars .. "/5  (" .. (pct or 0) .. "%)"
    trayQualityLbl.Visible = (pct ~= nil)
    if not trayVisible then
        trayVisible = true
        trayPanel.Position = TRAY_HIDE_X
        TweenService:Create(trayPanel, TIB(0.35), { Position = TRAY_SHOW_X }):Play()
    end
end

local function hideTray()
    if not trayVisible then return end
    trayVisible = false
    TweenService:Create(trayPanel, TI(0.22), { Position = TRAY_HIDE_X }):Play()
end

-- ══════════════════════════════════════════════════════════════════════════════
-- STATE HANDLERS
-- ══════════════════════════════════════════════════════════════════════════════
local STATE_LABELS = {
    PreOpen="PRE-OPEN", Open="OPEN", EndOfDay="END OF DAY", Lobby="LOBBY", Intermission="BREAK TIME",
}
local STATE_ACCENT = { Open=C.GREEN, Intermission=C.BLUE, EndOfDay=C.ORANGE }

local coachCount = 0

stateRemote.OnClientEvent:Connect(function(state, timeRemaining)
    local bg = STATE_ACCENT[state] and
        (state == "Open" and Color3.fromRGB(160, 218, 175) or
         state == "Intermission" and Color3.fromRGB(148, 195, 215) or
         Color3.fromRGB(235, 200, 155)) or C.PANEL
    TweenService:Create(timerBadge, TI(0.3), { BackgroundColor3 = bg }):Play()
    timerStroke.Color = STATE_ACCENT[state] or C.TEXT_LT
    timerLbl.Text = (STATE_LABELS[state] or state) .. "  " .. formatTime(timeRemaining or 0)

    timerBadge.Visible = not (state == "PreOpen" and player:GetAttribute("InTutorial"))
    skipBtn.Visible = (state == "PreOpen" and not player:GetAttribute("InTutorial"))

    if state == "Intermission" or state == "EndOfDay" then
        for key in pairs(orderCards) do removeCard(key) end
        activeOrders = {}; emptyLbl.Visible = true; coachBar.Visible = false
        hideTray()
        carryPill.Visible = false  -- BUG-73: clear carry pill on state change
    end
    if state == "Open" and coachCount < 3 then coachBar.Visible = true end
end)

player:GetAttributeChangedSignal("InTutorial"):Connect(function()
    if not player:GetAttribute("InTutorial") then timerBadge.Visible = true end
end)

settingsBtn.MouseButton1Click:Connect(function()
    TweenService:Create(settingsBtn, TI(0.1), { BackgroundTransparency = 0.05 }):Play()
    task.delay(0.15, function()
        TweenService:Create(settingsBtn, TI(0.2), { BackgroundTransparency = 0.3 }):Play()
    end)
    toggleSettings()
end)

local skipRemote = RemoteManager.Get("SkipPreOpen")
skipBtn.MouseButton1Click:Connect(function()
    skipBtn.Visible = false; skipRemote:FireServer()
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- ORDER TRACKING
-- ══════════════════════════════════════════════════════════════════════════════
local function addOrder(orderId, displayName, isVIP, cookieId)
    local key
    if orderId then
        key = tostring(orderId)
    else
        tempKeyN += 1; key = "tmp_" .. tempKeyN
    end
    table.insert(activeOrders, { orderId = orderId, display = displayName, tempKey = key })
    createCard(key, displayName, isVIP, cookieId)
end

local function removeByIndex(i)
    if i < 1 or i > #activeOrders then return end
    local entry = table.remove(activeOrders, i)
    removeCard(cardKey(entry))
end

local function removeById(orderId)
    for i, e in ipairs(activeOrders) do
        if e.orderId == orderId then removeByIndex(i); return true end
    end
    return false
end

hudUpdateEvent.OnClientEvent:Connect(function(coins, xp, activeOrderName)
    if coins then coinsLbl.Text = tostring(coins) end
    if xp then
        xpLbl.Text = xp .. " xp"
        levelLbl.Text = "Lv. " .. localLevel
        local req   = xpRequired(localLevel)
        local ratio = math.clamp((xp % req) / req, 0.03, 1)
        TweenService:Create(xpFill, TI(0.5), { Size = UDim2.new(ratio,0,1,0) }):Play()
    end
    if activeOrderName ~= nil then
        local nm = tostring(activeOrderName):gsub("\195\151","x")
        addOrder(nil, nm, false)
    end
end)

acceptedEvent.OnClientEvent:Connect(function(orderId, orderData)
    if not orderData then return end
    local name
    if orderData.isVariety and orderData.items then
        name = buildVarietyLabel(orderData.items)
    else
        name = cookieName(orderData.cookieId or "")
        if orderData.packSize and orderData.packSize > 1 then
            name = name .. " x" .. orderData.packSize
        end
    end
    addOrder(orderId, name, orderData.isVIP, orderData.isVariety and nil or orderData.cookieId)
    if orderData.isVIP then
        showAlert("⭐ VIP Customer!", Color3.fromRGB(50,40,10), C.GOLD, 4)
    end
end)

deliveryEvent.OnClientEvent:Connect(function(stars, coins, xp, orderId)
    local _qp = hud:FindFirstChild("QualityPreview"); if _qp then _qp:Destroy() end
    if orderId then removeById(orderId) else removeByIndex(1) end
    hideTray()
    coachCount += 1
    if coachCount >= 3 then coachBar.Visible = false end

    local s = math.clamp(stars or 0, 0, 5)
    local isGood = s >= 4
    local bgCol = isGood and Color3.fromRGB(160, 215, 170) or Color3.fromRGB(235, 175, 175)
    local acCol = isGood and C.GOLD or C.RED

    local popup = Instance.new("Frame", hud)
    popup.Name = "DeliveryFlash"
    popup.Size = UDim2.new(0,260,0,76); popup.Position = UDim2.new(0.5,-130,0.35,-38)
    popup.BackgroundColor3 = bgCol; popup.BackgroundTransparency = 1
    popup.BorderSizePixel = 0; popup.ZIndex = 50
    corner(popup, 14)
    local ps = addStroke(popup, acCol, 2, 1)

    local r1 = Instance.new("TextLabel", popup)
    r1.Size = UDim2.new(1,0,0,38); r1.Position = UDim2.new(0,0,0,4)
    r1.BackgroundTransparency = 1; r1.ZIndex = 51
    r1.TextColor3 = C.GOLD; r1.Font = Enum.Font.GothamBold; r1.TextScaled = true
    r1.TextTransparency = 1
    r1.Text = string.rep("★",s) .. string.rep("☆",5-s) .. "  " .. s .. "/5"

    local r2 = Instance.new("TextLabel", popup)
    r2.Size = UDim2.new(1,0,0,28); r2.Position = UDim2.new(0,0,0,44)
    r2.BackgroundTransparency = 1; r2.ZIndex = 51
    r2.TextColor3 = C.WHITE; r2.Font = Enum.Font.Gotham; r2.TextScaled = true
    r2.TextTransparency = 1; r2.Text = "+" .. (coins or 0) .. " coins"

    TweenService:Create(popup, TI(0.2), { BackgroundTransparency = 0.06 }):Play()
    TweenService:Create(ps,    TI(0.2), { Transparency = 0.2 }):Play()
    TweenService:Create(r1,    TI(0.2), { TextTransparency = 0 }):Play()
    TweenService:Create(r2,    TI(0.3), { TextTransparency = 0 }):Play()

    task.delay(2.2, function()
        if not popup.Parent then return end
        TweenService:Create(popup, TI(0.3), { BackgroundTransparency = 1 }):Play()
        TweenService:Create(ps,    TI(0.3), { Transparency = 1 }):Play()
        TweenService:Create(r1,    TI(0.3), { TextTransparency = 1 }):Play()
        local t = TweenService:Create(r2, TI(0.3), { TextTransparency = 1 })
        t:Play(); t.Completed:Connect(function() if popup.Parent then popup:Destroy() end end)
    end)
    spawnFloatingReward(coins, xp)

    do local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart"); if hrp then EffectsModule.Confetti(hrp.Position) end end
end)

npcPatienceEvent.OnClientEvent:Connect(function(orderId, current, maxP)
    if not orderId then return end
    local ratio = math.clamp((current or 0) / math.max(maxP or 1, 1), 0, 1)
    patienceMap[orderId] = ratio
    local key = tostring(orderId)
    if orderCards[key] then
        updatePatience(key, ratio, current)
    elseif #activeOrders > 0 and not activeOrders[1].orderId then
        updatePatience(cardKey(activeOrders[1]), ratio, current)
    end
end)

npcOrderCancelledEvent.OnClientEvent:Connect(function(orderId, cookieId, packSize)
    if orderId and removeById(orderId) then return end
    local nm = cookieName(cookieId or "")
    if packSize and packSize > 1 then nm = nm .. " x" .. packSize end
    for i, e in ipairs(activeOrders) do
        if e.display == nm then removeByIndex(i); return end
    end
    removeByIndex(1)
end)

-- M-2: Order Ready Alert — toast when a cookie enters the warmer
local _prevWarmerCount = 0
warmersStockEvent.OnClientEvent:Connect(function(warmerState)
    local count = 0
    if type(warmerState) == "table" then
        for _ in pairs(warmerState) do count += 1 end
    end
    if count > _prevWarmerCount then
        -- BUG-69: suppress "Cookie ready to box!" during tutorial — player has no warmer interaction
        if not player:GetAttribute("InTutorial") then
            showAlert("Cookie ready to box!", Color3.fromRGB(255, 200, 60), Color3.fromRGB(255, 240, 120), 2.5)
            if orderAlertSound then orderAlertSound:Play() end
        end
    end
    _prevWarmerCount = count
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- ALERT HELPER
-- ══════════════════════════════════════════════════════════════════════════════
showAlert = function(text, bgColor, accentColor, duration)
    local existing = hud:FindFirstChild("AlertPill")
    if existing then existing:Destroy() end
    local alert = Instance.new("Frame", hud)
    alert.Name = "AlertPill"
    alert.Size = UDim2.new(0,220,0,36); alert.Position = UDim2.new(0.5,-110,0,62)
    alert.BackgroundColor3 = bgColor; alert.BackgroundTransparency = 1
    alert.BorderSizePixel = 0; alert.ZIndex = 40
    corner(alert, 20)
    local as = addStroke(alert, accentColor, 1.5, 1)
    local al = Instance.new("TextLabel", alert)
    al.Size = UDim2.new(1,-8,1,0); al.Position = UDim2.new(0,4,0,0)
    al.BackgroundTransparency = 1; al.TextColor3 = accentColor
    al.Font = Enum.Font.GothamBold; al.TextScaled = true
    al.Text = text; al.TextTransparency = 1; al.ZIndex = 41
    local twA1 = TweenService:Create(alert, TI(0.2), { BackgroundTransparency = 0.1 }); if twA1 then twA1:Play() end
    local twS1 = TweenService:Create(as,    TI(0.2), { Transparency = 0.3 });           if twS1 then twS1:Play() end
    local twL1 = TweenService:Create(al,    TI(0.2), { TextTransparency = 0 });         if twL1 then twL1:Play() end
    task.delay(duration or 3, function()
        if not alert.Parent then return end
        local twA2 = TweenService:Create(alert, TI(0.3), { BackgroundTransparency = 1 }); if twA2 then twA2:Play() end
        local twS2 = TweenService:Create(as,    TI(0.3), { Transparency = 1 });           if twS2 then twS2:Play() end
        local twL2 = TweenService:Create(al,    TI(0.3), { TextTransparency = 1 })
        if twL2 then twL2:Play(); twL2.Completed:Connect(function() if alert.Parent then alert:Destroy() end end) end
    end)
end

-- M-3: Rush Hour announcement banner
RemoteManager.Get("RushHour").OnClientEvent:Connect(function(data)
    if data and data.active then
        showAlert("RUSH HOUR!", Color3.fromRGB(220, 60, 30), Color3.fromRGB(255, 200, 60), 4)
    end
end)

driveThruArrivedEvent.OnClientEvent:Connect(function()
    showAlert("🚗 Drive Thru!", Color3.fromRGB(155, 200, 230), C.BLUE, 5)
end)
npcOrderFailedEvent.OnClientEvent:Connect(function(npcName, _orderId, position)
    local txt = (npcName and npcName ~= "") and (npcName .. " left!") or "Order Failed!"
    showAlert("X " .. txt, Color3.fromRGB(235, 180, 180), C.RED, 4)
    -- In-world floating X at NPC position
    if position then
        local xa = Instance.new("Part")
        xa.Anchored=true; xa.CanCollide=false; xa.Transparency=1
        xa.Size=Vector3.new(1,1,1)
        xa.CFrame=CFrame.new(position + Vector3.new(0,1,0))
        xa.Parent=workspace
        local xbb=Instance.new("BillboardGui",xa)
        xbb.Size=UDim2.new(0,80,0,80); xbb.AlwaysOnTop=true; xbb.ResetOnSpawn=false
        local xlbl=Instance.new("TextLabel",xbb)
        xlbl.Size=UDim2.fromScale(1,1)
        xlbl.BackgroundColor3=Color3.fromRGB(200,40,40)
        xlbl.BackgroundTransparency=0.1; xlbl.BorderSizePixel=0
        xlbl.Text="X"; xlbl.TextColor3=Color3.fromRGB(255,255,255)
        xlbl.Font=Enum.Font.GothamBold; xlbl.TextScaled=true
        Instance.new("UICorner",xlbl).CornerRadius=UDim.new(0.5,0)
        TweenService:Create(xa,TweenInfo.new(1.6,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),
            {CFrame=CFrame.new(position+Vector3.new(0,4,0))}):Play()
        local xt=TweenService:Create(xlbl,TweenInfo.new(1.6,Enum.EasingStyle.Quad,Enum.EasingDirection.In),
            {BackgroundTransparency=1,TextTransparency=1})
        xt:Play()
        xt.Completed:Connect(function() if xa.Parent then xa:Destroy() end end)
    end
end)
local _prevComboStreak = 0
comboUpdateEvent.OnClientEvent:Connect(function(streak)
    streak = streak or 0
    if streak >= 2 then
        comboLbl.Text = "x" .. streak .. " COMBO"
        local tw1 = TweenService:Create(comboPill, TI(0.2), { BackgroundTransparency = 0.15 })
        if tw1 then tw1:Play() end
    else
        -- M-10: show STREAK BROKEN alert when combo resets from ≥2
        if _prevComboStreak >= 2 then
            showAlert("STREAK BROKEN!", Color3.fromRGB(180, 30, 60), Color3.fromRGB(255, 100, 130), 2)
        end
        comboLbl.Text = ""
        local tw2 = TweenService:Create(comboPill, TI(0.3), { BackgroundTransparency = 1 })
        if tw2 then tw2:Play() end
    end
    _prevComboStreak = streak
end)

-- ── Carrying Visual (visible to all players) ──────────────────────────────────
local function showCarryingVisual(carrierName, cid)
    local carrier = Players:FindFirstChild(carrierName)
    local char = carrier and carrier.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local existing = hrp:FindFirstChild("CarryingVisual")
    if existing then existing:Destroy() end
    local bb = Instance.new("BillboardGui", hrp)
    bb.Name = "CarryingVisual"
    bb.Size = UDim2.new(0, 180, 0, 32)
    bb.StudsOffset = Vector3.new(0, 4.2, 0)
    bb.AlwaysOnTop = false
    bb.ResetOnSpawn = false
    local bg = Instance.new("Frame", bb)
    bg.Size = UDim2.fromScale(1, 1)
    bg.BackgroundColor3 = Color3.fromRGB(25, 50, 85)
    bg.BackgroundTransparency = 0.2
    bg.BorderSizePixel = 0
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 10)
    local s = Instance.new("UIStroke", bg)
    s.Color = Color3.fromRGB(255, 205, 50); s.Thickness = 1.5; s.Transparency = 0.35
    local lbl = Instance.new("TextLabel", bg)
    lbl.Size = UDim2.fromScale(1, 1)
    lbl.BackgroundTransparency = 1
    lbl.Text = "\xf0\x9f\x93\xa6 " .. cookieName(cid or "")
    lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextScaled = true
    lbl.TextStrokeTransparency = 0.45
    lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
end
local function clearCarryingVisual(carrierName)
    local carrier = Players:FindFirstChild(carrierName)
    local char = carrier and carrier.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local bb = hrp and hrp:FindFirstChild("CarryingVisual")
    if bb then bb:Destroy() end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- BOX QUALITY PREVIEW
-- ══════════════════════════════════════════════════════════════════════════════
boxCreatedEvent.OnClientEvent:Connect(function(box)
    if box and box.carrier then showCarryingVisual(box.carrier, box.cookieId) end
    if not (box and box.carrier == player.Name) then return end
    local pct   = math.clamp(math.round(box.quality or 0), 0, 100)
    showTray(cookieName(box.cookieId or ""), pct)
    local stars = math.clamp(math.round(pct / 20), 1, 5)
    local old = hud:FindFirstChild("QualityPreview")
    if old then old:Destroy() end

    local card = Instance.new("Frame", hud)
    card.Name = "QualityPreview"
    card.Size = UDim2.new(0,220,0,56); card.Position = UDim2.new(0.5,-110,0.5,20)
    card.BackgroundColor3 = Color3.fromRGB(238, 248, 255); card.BackgroundTransparency = 1
    card.BorderSizePixel = 0; card.ZIndex = 45
    corner(card, 12)
    local cs = addStroke(card, C.GOLD, 1.5, 1)

    local r1 = Instance.new("TextLabel", card)
    r1.Size = UDim2.new(1,0,0,28); r1.Position = UDim2.new(0,0,0,4)
    r1.BackgroundTransparency = 1; r1.TextColor3 = C.GOLD
    r1.Font = Enum.Font.GothamBold; r1.TextScaled = true; r1.ZIndex = 46
    r1.Text = string.rep("★",stars)..string.rep("☆",5-stars).."  "..pct.."%"
    r1.TextTransparency = 1

    local r2 = Instance.new("TextLabel", card)
    r2.Size = UDim2.new(1,0,0,20); r2.Position = UDim2.new(0,0,0,32)
    r2.BackgroundTransparency = 1; r2.TextColor3 = C.TEXT_LT
    r2.Font = Enum.Font.Gotham; r2.TextScaled = true; r2.ZIndex = 46
    r2.Text = "Box Ready! Deliver it."; r2.TextTransparency = 1

    TweenService:Create(card, TI(0.2), { BackgroundTransparency = 0.06 }):Play()
    TweenService:Create(cs,   TI(0.2), { Transparency = 0.2 }):Play()
    TweenService:Create(r1,   TI(0.2), { TextTransparency = 0 }):Play()
    TweenService:Create(r2,   TI(0.25),{ TextTransparency = 0 }):Play()

    task.delay(3, function()
        if not card.Parent then return end
        TweenService:Create(card, TI(0.3), { BackgroundTransparency = 1 }):Play()
        TweenService:Create(cs,   TI(0.3), { Transparency = 1 }):Play()
        TweenService:Create(r1,   TI(0.3), { TextTransparency = 1 }):Play()
        local t = TweenService:Create(r2, TI(0.3), { TextTransparency = 1 })
        t:Play(); t.Completed:Connect(function() if card.Parent then card:Destroy() end end)
    end)
end)

-- M-11: Show loading state until PlayerDataInit arrives
coinsLbl.Text  = "..."
levelLbl.Text  = "..."

-- Initialize HUD with actual player data on join
dataInitEvent.OnClientEvent:Connect(function(data)
    if not data then return end
    localLevel = data.level or 1
    coinsLbl.Text  = tostring(data.coins or 0)
    levelLbl.Text  = "Lv. " .. localLevel
    local xp  = data.xp or 0
    xpLbl.Text = xp .. " xp"
    local req   = xpRequired(localLevel)
    local ratio = math.clamp((xp % req) / req, 0.03, 1)
    xpFill.Size = UDim2.new(ratio, 0, 1, 0)
end)

-- BUG-54: Pull current data from server immediately so we don't miss the
-- PlayerDataInit event that fires before this LocalScript connects.
task.defer(function()
    local ok, requestRemote = pcall(function()
        return RemoteManager.Get("RequestPlayerData")
    end)
    if ok and requestRemote then
        requestRemote:FireServer()
    end
end)

-- ── Station Status Dots ──────────────────────────────────────────────────────
local STATUS_GREEN  = Color3.fromRGB(80, 220, 100)
local STATUS_YELLOW = Color3.fromRGB(255, 200, 0)

local function getOrCreateStatusDot(model)
    if not model or not model:IsA("Model") then return nil end
    local part = model:FindFirstChildWhichIsA("BasePart")
    if not part then return nil end
    local existing = part:FindFirstChild("StationStatusDot")
    if existing then return existing end

    local bb = Instance.new("BillboardGui", part)
    bb.Name           = "StationStatusDot"
    bb.Size           = UDim2.new(0, 28, 0, 28)
    bb.StudsOffset    = Vector3.new(0, 5.5, 0)
    bb.AlwaysOnTop    = false
    bb.ResetOnSpawn   = false

    local frame = Instance.new("Frame", bb)
    frame.Name                  = "Dot"
    frame.Size                  = UDim2.fromScale(1, 1)
    frame.BackgroundColor3      = STATUS_GREEN
    frame.BorderSizePixel       = 0
    Instance.new("UICorner", frame).CornerRadius = UDim.new(1, 0)

    local stroke = Instance.new("UIStroke", frame)
    stroke.Color       = Color3.fromRGB(0, 0, 0)
    stroke.Thickness   = 1.5
    stroke.Transparency = 0.5

    return bb
end

local stationStatusRemote = RemoteManager.Get("StationStatusUpdate")
stationStatusRemote.OnClientEvent:Connect(function(model, status, occupantName)
    local bb = getOrCreateStatusDot(model)
    if not bb then return end
    local dot = bb:FindFirstChild("Dot")
    if not dot then return end
    if status == "occupied" then
        dot.BackgroundColor3 = STATUS_YELLOW
    else
        dot.BackgroundColor3 = STATUS_GREEN
    end
end)

-- ── Work-Available Guidance Arrows ───────────────────────────────────────────
local ARROW_COLOR = Color3.fromRGB(255, 215, 0)

local function getOrCreateWorkArrow(model)
    if not model or not model:IsA("Model") then return nil end
    local part = model:FindFirstChildWhichIsA("BasePart")
    if not part then return nil end
    if part:FindFirstChild("WorkArrow") then return part:FindFirstChild("WorkArrow") end
    local bb = Instance.new("BillboardGui", part)
    bb.Name = "WorkArrow"; bb.Size = UDim2.new(0, 60, 0, 28)
    bb.StudsOffset = Vector3.new(0, 6.5, 0); bb.AlwaysOnTop = false
    bb.ResetOnSpawn = false; bb.Enabled = false
    local lbl = Instance.new("TextLabel", bb)
    lbl.Size = UDim2.fromScale(1, 1); lbl.BackgroundTransparency = 1
    lbl.TextColor3 = ARROW_COLOR; lbl.Font = Enum.Font.GothamBold
    lbl.TextScaled = true; lbl.Text = "▶ HERE"
    lbl.TextStrokeTransparency = 0.3; lbl.TextStrokeColor3 = Color3.fromRGB(0,0,0)
    TweenService:Create(lbl, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { TextTransparency = 0.55 }):Play()
    return bb
end

local stationModels = { dough = {}, fridge = {}, frost = nil, dress = nil }

task.spawn(function()
    task.wait(4)
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("ProximityPrompt") then
            local model = d:FindFirstAncestorOfClass("Model")
            if model then
                if d.Name == "DoughPrompt" then
                    table.insert(stationModels.dough, model)
                    getOrCreateWorkArrow(model)
                elseif d.Name == "FrostPrompt" then
                    stationModels.frost = model
                    getOrCreateWorkArrow(model)
                elseif d.Name == "DressPrompt" then
                    stationModels.dress = model
                    getOrCreateWorkArrow(model)
                end
            end
        end
    end
    local fridgesFolder = workspace:FindFirstChild("Fridges")
    if fridgesFolder then
        for _, fridge in ipairs(fridgesFolder:GetChildren()) do
            local fid = fridge:GetAttribute("FridgeId")
            if fid then stationModels.fridge[fid] = fridge; getOrCreateWorkArrow(fridge) end
        end
    end
end)

local function setWorkArrow(model, visible)
    if not model then return end
    local part = model:FindFirstChildWhichIsA("BasePart")
    if not part then return end
    local bb = part:FindFirstChild("WorkArrow")
    if bb then bb.Enabled = visible end
end

local lastBatchState, lastFridgeState = nil, nil
local function refreshWorkArrows()
    local bs, fs = lastBatchState, lastFridgeState
    local hasDough = false
    if bs and bs.batches then
        for _, b in ipairs(bs.batches) do
            if b.stage == "dough" then hasDough = true; break end
        end
    end
    for _, m in ipairs(stationModels.dough) do setWorkArrow(m, hasDough) end
    if fs then
        for fridgeId, count in pairs(fs) do
            setWorkArrow(stationModels.fridge[fridgeId], count > 0)
        end
    end
    setWorkArrow(stationModels.frost, bs and (bs.warmerForFrost or 0) > 0)
    setWorkArrow(stationModels.dress, bs and (bs.warmerForDress or 0) > 0)
end

RemoteManager.Get("BatchUpdated").OnClientEvent:Connect(function(state)
    lastBatchState = state; refreshWorkArrows()
end)
RemoteManager.Get("FridgeUpdated").OnClientEvent:Connect(function(state)
    lastFridgeState = state; refreshWorkArrows()
end)

-- ── New Order Flash ───────────────────────────────────────────────────────────
local orderAlertSound = Instance.new("Sound")
orderAlertSound.SoundId   = "rbxassetid://139488704715914"  -- ORDER_BELL
orderAlertSound.Volume    = 0.65
orderAlertSound.RollOffMaxDistance = 0
orderAlertSound.Parent    = playerGui

local orderFlashFrame = Instance.new("Frame")
orderFlashFrame.Size = UDim2.fromScale(1, 1)
orderFlashFrame.BackgroundColor3 = Color3.fromRGB(255, 180, 40)
orderFlashFrame.BackgroundTransparency = 1
orderFlashFrame.BorderSizePixel = 0
orderFlashFrame.ZIndex = 15
orderFlashFrame.Parent = hud  -- hud is the ScreenGui

local _flashActive = false
local function flashNewOrder()
    if _flashActive then return end
    _flashActive = true
    orderAlertSound:Play()
    orderFlashFrame.BackgroundTransparency = 0.6
    TweenService:Create(orderFlashFrame, TI(0.5), { BackgroundTransparency = 1 }):Play()
    task.delay(0.5, function() _flashActive = false end)
end

RemoteManager.Get("NPCOrderReady").OnClientEvent:Connect(flashNewOrder)

-- ── Floating Delivery Review Text ────────────────────────────────────────────
local STAR_LABELS = { [0]="☆☆☆☆☆ Missed!", [1]="★☆☆☆☆ Oops", [2]="★★☆☆☆ Okay", [3]="★★★☆☆ Good", [4]="★★★★☆ Great!", [5]="★★★★★ Perfect!" }
deliveryFeedbackEvent.OnClientEvent:Connect(function(position, stars, carrierName)
    if carrierName then clearCarryingVisual(carrierName) end
    if not position then return end
    local s = math.clamp(stars or 0, 0, 5)
    local label = STAR_LABELS[s] or "★★★★★ Perfect!"
    local isGood = s >= 4
    local anchor = Instance.new("Part")
    anchor.Anchored = true; anchor.CanCollide = false; anchor.Transparency = 1
    anchor.Size = Vector3.new(1, 1, 1)
    anchor.CFrame = CFrame.new(position + Vector3.new(0, 2.5, 0))
    anchor.Parent = workspace
    local bb = Instance.new("BillboardGui", anchor)
    bb.Size = UDim2.new(0, 220, 0, 54)
    bb.AlwaysOnTop = true
    bb.ResetOnSpawn = false
    local lbl = Instance.new("TextLabel", bb)
    lbl.Size = UDim2.fromScale(1, 1)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = isGood and Color3.fromRGB(255, 215, 50) or Color3.fromRGB(220, 120, 120)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextScaled = true
    lbl.TextStrokeTransparency = 0.3
    lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    TweenService:Create(anchor, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { CFrame = CFrame.new(position + Vector3.new(0, 5.5, 0)) }):Play()
    local t = TweenService:Create(lbl, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        { TextTransparency = 1 })
    t:Play()
    t.Completed:Connect(function() if anchor.Parent then anchor:Destroy() end end)

    -- Satisfaction emoji reaction bubble (floats up from NPC head)
    local FACES = {[5]=":D",[4]=":)",[3]=":|",[2]=":(",[1]=">:("}
    local FACE_COLORS = {
        [5]=Color3.fromRGB(80,220,80),[4]=Color3.fromRGB(140,210,80),
        [3]=Color3.fromRGB(255,200,60),[2]=Color3.fromRGB(255,130,40),
        [1]=Color3.fromRGB(220,60,60),
    }
    local emojiAnchor = Instance.new("Part")
    emojiAnchor.Anchored=true; emojiAnchor.CanCollide=false; emojiAnchor.Transparency=1
    emojiAnchor.Size=Vector3.new(1,1,1)
    emojiAnchor.CFrame=CFrame.new(position + Vector3.new(0,0.5,0))
    emojiAnchor.Parent=workspace
    local ebb=Instance.new("BillboardGui",emojiAnchor)
    ebb.Size=UDim2.new(0,68,0,68); ebb.AlwaysOnTop=true; ebb.ResetOnSpawn=false
    local elbl=Instance.new("TextLabel",ebb)
    elbl.Size=UDim2.fromScale(1,1)
    elbl.BackgroundColor3=FACE_COLORS[s] or Color3.fromRGB(80,220,80)
    elbl.BackgroundTransparency=0.1; elbl.BorderSizePixel=0
    elbl.Text=FACES[s] or ":)"; elbl.TextColor3=Color3.fromRGB(20,20,20)
    elbl.Font=Enum.Font.GothamBold; elbl.TextScaled=true
    Instance.new("UICorner",elbl).CornerRadius=UDim.new(0.5,0)
    TweenService:Create(emojiAnchor,TweenInfo.new(1.8,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),
        {CFrame=CFrame.new(position+Vector3.new(0,3.5,0))}):Play()
    local et=TweenService:Create(elbl,TweenInfo.new(1.8,Enum.EasingStyle.Quad,Enum.EasingDirection.In),
        {BackgroundTransparency=1,TextTransparency=1})
    et:Play()
    et.Completed:Connect(function() if emojiAnchor.Parent then emojiAnchor:Destroy() end end)
end)

-- ── Station Worker Feedback ───────────────────────────────────────────────────
local STATION_LABELS = { mix="Mixed", dough="Shaped", oven="Baked", frost="Frosted", dress="Packed" }
workerFeedbackEvent.OnClientEvent:Connect(function(targetPlayer, stationName, score, pos)
    if not (targetPlayer and pos) then return end
    local pct   = math.clamp(math.round(score or 0), 0, 100)
    local stars = math.clamp(math.round(pct / 20), 0, 5)
    local label = STATION_LABELS[stationName] or stationName
    local txt
    if pct >= 90 then txt = "PERFECT! " .. string.rep("★", stars)
    elseif pct >= 70 then txt = label .. "! " .. string.rep("★", stars) .. string.rep("☆", 5 - stars)
    elseif pct >= 50 then txt = label .. " " .. string.rep("★", stars) .. string.rep("☆", 5 - stars)
    else txt = "Missed..." end
    local anchor = Instance.new("Part")
    anchor.Anchored = true; anchor.CanCollide = false; anchor.Transparency = 1
    anchor.Size = Vector3.new(1,1,1)
    anchor.CFrame = CFrame.new(pos + Vector3.new(0, 0.5, 0))
    anchor.Parent = workspace
    local bb = Instance.new("BillboardGui", anchor)
    bb.Size = UDim2.new(0, 200, 0, 36)
    bb.AlwaysOnTop = false; bb.ResetOnSpawn = false
    local lbl = Instance.new("TextLabel", bb)
    lbl.Size = UDim2.fromScale(1, 1)
    lbl.BackgroundTransparency = 1
    lbl.Text = txt
    lbl.TextColor3 = pct >= 70 and Color3.fromRGB(255, 215, 50) or Color3.fromRGB(220, 130, 80)
    lbl.Font = Enum.Font.GothamBold; lbl.TextScaled = true
    lbl.TextStrokeTransparency = 0.35; lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    TweenService:Create(anchor, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { CFrame = CFrame.new(pos + Vector3.new(0, 4.5, 0)) }):Play()
    local t = TweenService:Create(lbl, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        { TextTransparency = 1 })
    t:Play()
    t.Completed:Connect(function() if anchor.Parent then anchor:Destroy() end end)
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- H-8: CARRY INDICATOR — shows NPC name when player is holding a box
-- ══════════════════════════════════════════════════════════════════════════════
local carryPill = Instance.new("Frame", hud)
carryPill.Name               = "CarryPill"
carryPill.Size               = UDim2.new(0.82, 0, 0, 40)
carryPill.Position           = UDim2.new(0.09, 0, 1, -118)
carryPill.BackgroundColor3   = Color3.fromRGB(255, 130, 60)
carryPill.BackgroundTransparency = 0.1
carryPill.BorderSizePixel    = 0
carryPill.ZIndex             = 24
carryPill.Visible            = false
corner(carryPill, 20)
addStroke(carryPill, C.WHITE, 1.5, 0.5)

local carryLbl = Instance.new("TextLabel", carryPill)
carryLbl.Size               = UDim2.new(1, -16, 1, 0)
carryLbl.Position           = UDim2.new(0, 8, 0, 0)
carryLbl.BackgroundTransparency = 1
carryLbl.TextColor3         = C.WHITE
carryLbl.Font               = Enum.Font.GothamBold
carryLbl.TextScaled         = true
carryLbl.TextXAlignment     = Enum.TextXAlignment.Center
carryLbl.Text               = ""
carryLbl.ZIndex             = 25

RemoteManager.Get("BoxCarried").OnClientEvent:Connect(function(npcName)
    if npcName then
        carryLbl.Text = "\xF0\x9F\x93\xA6  Deliver to: " .. npcName
        carryPill.Visible = true
        TweenService:Create(carryPill, TIB(0.3), { Size = UDim2.new(0.86, 0, 0, 44) }):Play()
    else
        TweenService:Create(carryPill, TI(0.2), { Size = UDim2.new(0.78, 0, 0, 36) }):Play()
        task.delay(0.25, function() carryPill.Visible = false end)
    end
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- C-2: COACH BAR — bottom-center hint strip
-- ══════════════════════════════════════════════════════════════════════════════
local coachBar = Instance.new("Frame", hud)
coachBar.Name               = "CoachTip"
coachBar.Size               = UDim2.new(0.88, 0, 0, 42)
coachBar.Position           = UDim2.new(0.06, 0, 1, -70)
coachBar.BackgroundColor3   = Color3.fromRGB(20, 20, 40)
coachBar.BackgroundTransparency = 0.15
coachBar.BorderSizePixel    = 0
coachBar.ZIndex             = 25
coachBar.Visible            = false
corner(coachBar, 21)
addStroke(coachBar, C.BLUSH, 1.5, 0.3)

local coachLbl = Instance.new("TextLabel", coachBar)
coachLbl.Size               = UDim2.new(1, -20, 1, 0)
coachLbl.Position           = UDim2.new(0, 10, 0, 0)
coachLbl.BackgroundTransparency = 1
coachLbl.TextColor3         = C.WHITE
coachLbl.Font               = Enum.Font.GothamBold
coachLbl.TextScaled         = true
coachLbl.TextXAlignment     = Enum.TextXAlignment.Center
coachLbl.Text               = ""
coachLbl.ZIndex             = 26

local coachDismissThread = nil
local function showCoachTip(msg)
    if coachDismissThread then task.cancel(coachDismissThread) end
    coachLbl.Text = "->  " .. msg
    coachBar.BackgroundTransparency = 0.15
    coachLbl.TextTransparency = 0
    coachBar.Visible = true
    coachDismissThread = task.delay(8, function()
        TweenService:Create(coachBar, TI(0.4), { BackgroundTransparency = 1 }):Play()
        TweenService:Create(coachLbl, TI(0.4), { TextTransparency = 1 }):Play()
        task.wait(0.5)
        coachBar.Visible = false
    end)
end

RemoteManager.Get("PlayerTipUpdate").OnClientEvent:Connect(showCoachTip)

print("[HUDController] Redesign v2 ready.")
