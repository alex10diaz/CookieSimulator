-- src/StarterGui/SummaryGui/SummaryController.client.lua  (M7 Polish)
local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteManager  = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local summaryEvent   = RemoteManager.Get("EndOfDaySummary")
local stateRemote    = RemoteManager.Get("GameStateChanged")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local gui       = playerGui:WaitForChild("SummaryGui")

-- ── Palette ───────────────────────────────────────────────────────────────────
local C = {
    BG       = Color3.fromRGB(16, 16, 28),
    CARD     = Color3.fromRGB(26, 26, 42),
    CARD2    = Color3.fromRGB(32, 32, 52),
    GOLD     = Color3.fromRGB(255, 200, 0),
    GOLD_DIM = Color3.fromRGB(180, 140, 0),
    WHITE    = Color3.fromRGB(255, 255, 255),
    MUTED    = Color3.fromRGB(150, 150, 180),
}

-- ── Build frame ───────────────────────────────────────────────────────────────
local frame = gui:FindFirstChild("SummaryFrame")
if frame then frame:Destroy() end

frame = Instance.new("Frame")
frame.Name             = "SummaryFrame"
frame.Size             = UDim2.new(0, 430, 0, 506)
frame.Position         = UDim2.new(0.5, -215, 0.5, -253)
frame.BackgroundColor3 = C.BG
frame.BackgroundTransparency = 0
frame.BorderSizePixel  = 0
frame.Parent           = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 18)

local outerStroke = Instance.new("UIStroke", frame)
outerStroke.Color = C.GOLD; outerStroke.Thickness = 2.5; outerStroke.Transparency = 0.3

-- Gold gradient header bar
local headerBar = Instance.new("Frame", frame)
headerBar.Size = UDim2.new(1,0,0,52); headerBar.Position = UDim2.new(0,0,0,0)
headerBar.BackgroundColor3 = C.GOLD_DIM; headerBar.BorderSizePixel = 0
Instance.new("UICorner", headerBar).CornerRadius = UDim.new(0, 18)
-- Flatten bottom rounded corners with an overlap strip
local headerFill = Instance.new("Frame", headerBar)
headerFill.Size = UDim2.new(1,0,0.5,0); headerFill.Position = UDim2.new(0,0,0.5,0)
headerFill.BackgroundColor3 = C.GOLD_DIM; headerFill.BorderSizePixel = 0

local grad = Instance.new("UIGradient", headerBar)
grad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255,215,0)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(200,145,0)),
})
grad.Rotation = 90

local title = Instance.new("TextLabel", headerBar)
title.Name = "Title"; title.Size = UDim2.new(1,0,1,0)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(30,20,0); title.Font = Enum.Font.GothamBold
title.TextScaled = true; title.Text = "End of Shift!"

-- ── Stats grid ────────────────────────────────────────────────────────────────
local STAT_DEFS = {
    { icon="📦", key="orders", label="Orders" },
    { icon="★",  key="coins",  label="Coins Earned" },
    { icon="⚡", key="combo",  label="Best Combo" },
    { icon="⭐", key="stars",  label="Avg Rating" },
}

local statsFrame = Instance.new("Frame", frame)
statsFrame.Name = "StatsFrame"
statsFrame.Size = UDim2.new(1,-20,0,100)
statsFrame.Position = UDim2.new(0,10,0,60)
statsFrame.BackgroundTransparency = 1; statsFrame.BorderSizePixel = 0

local statLayout = Instance.new("UIGridLayout", statsFrame)
statLayout.CellSize = UDim2.new(0.5,-6,0,44)
statLayout.CellPadding = UDim2.new(0,6,0,6)
statLayout.FillDirection = Enum.FillDirection.Horizontal
statLayout.SortOrder = Enum.SortOrder.LayoutOrder

local statLabels = {}
for i, def in ipairs(STAT_DEFS) do
    local card = Instance.new("Frame", statsFrame)
    card.Name = "Stat_"..def.key; card.BackgroundColor3 = C.CARD
    card.BackgroundTransparency = 0; card.BorderSizePixel = 0; card.LayoutOrder = i
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

    local iconL = Instance.new("TextLabel", card)
    iconL.Size = UDim2.new(0,30,1,0); iconL.Position = UDim2.new(0,4,0,0)
    iconL.BackgroundTransparency = 1; iconL.TextColor3 = C.GOLD
    iconL.Font = Enum.Font.GothamBold; iconL.TextScaled = true; iconL.Text = def.icon

    local valL = Instance.new("TextLabel", card)
    valL.Name = "Val"; valL.Size = UDim2.new(1,-40,1,0); valL.Position = UDim2.new(0,36,0,0)
    valL.BackgroundTransparency = 1; valL.TextColor3 = C.WHITE
    valL.Font = Enum.Font.GothamBold; valL.TextScaled = true
    valL.TextXAlignment = Enum.TextXAlignment.Left; valL.Text = "—"

    statLabels[def.key] = valL
end

-- ── Divider ───────────────────────────────────────────────────────────────────
local div = Instance.new("Frame", frame)
div.Size = UDim2.new(1,-20,0,1); div.Position = UDim2.new(0,10,0,168)
div.BackgroundColor3 = Color3.fromRGB(60,60,90); div.BorderSizePixel = 0

-- ── Employee of Shift ─────────────────────────────────────────────────────────
local empHeader = Instance.new("TextLabel", frame)
empHeader.Name = "EmpTitle"; empHeader.Size = UDim2.new(1,-20,0,28)
empHeader.Position = UDim2.new(0,10,0,176)
empHeader.BackgroundTransparency = 1; empHeader.TextColor3 = C.GOLD
empHeader.Font = Enum.Font.GothamBold; empHeader.TextScaled = true
empHeader.TextXAlignment = Enum.TextXAlignment.Left; empHeader.Text = "Employee of the Shift"

local ROLE_DEFS = {
    { role="Mixer",     icon="🥣", fmt="%d%%" },
    { role="Baller",    icon="🍪", fmt="%d batches" },
    { role="Baker",     icon="🔥", fmt="%d%%" },
    { role="Glazer",    icon="🧁", fmt="%d%%" },
    { role="Decorator", icon="🎁", fmt="%d boxes" },
}

for idx, def in ipairs(ROLE_DEFS) do
    local row = Instance.new("Frame", frame)
    row.Name = "Emp_"..def.role
    row.Size = UDim2.new(1,-20,0,40)
    row.Position = UDim2.new(0,10,0, 210 + (idx-1)*44)
    row.BackgroundColor3 = C.CARD2
    row.BackgroundTransparency = 0; row.BorderSizePixel = 0
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

    local iconL = Instance.new("TextLabel", row)
    iconL.Size = UDim2.new(0,34,1,0); iconL.Position = UDim2.new(0,4,0,0)
    iconL.BackgroundTransparency = 1; iconL.TextColor3 = C.GOLD
    iconL.Font = Enum.Font.GothamBold; iconL.TextScaled = true; iconL.Text = def.icon

    local nameL = Instance.new("TextLabel", row)
    nameL.Name = "PlayerName"; nameL.Size = UDim2.new(0.55,0,1,0); nameL.Position = UDim2.new(0,40,0,0)
    nameL.BackgroundTransparency = 1; nameL.TextColor3 = C.MUTED
    nameL.Font = Enum.Font.Gotham; nameL.TextScaled = true
    nameL.TextXAlignment = Enum.TextXAlignment.Left; nameL.Text = def.role .. ":  —"

    local valL = Instance.new("TextLabel", row)
    valL.Name = "Val"; valL.Size = UDim2.new(0.42,0,1,0); valL.Position = UDim2.new(0.58,0,0,0)
    valL.BackgroundTransparency = 1; valL.TextColor3 = C.MUTED
    valL.Font = Enum.Font.GothamBold; valL.TextScaled = true
    valL.TextXAlignment = Enum.TextXAlignment.Right; valL.Text = ""
end

-- ── Countdown + Continue button ───────────────────────────────────────────────
local countdownLabel = Instance.new("TextLabel", frame)
countdownLabel.Name = "Countdown"
countdownLabel.Size = UDim2.new(1, -20, 0, 20)
countdownLabel.Position = UDim2.new(0, 10, 0, 428)
countdownLabel.BackgroundTransparency = 1
countdownLabel.TextColor3 = Color3.fromRGB(120, 120, 150)
countdownLabel.Font = Enum.Font.Gotham
countdownLabel.TextSize = 13
countdownLabel.TextScaled = false
countdownLabel.Text = ""

local continueBtn = Instance.new("TextButton", frame)
continueBtn.Name = "ContinueBtn"
continueBtn.Size = UDim2.new(1, -40, 0, 38)
continueBtn.Position = UDim2.new(0, 20, 0, 454)
continueBtn.BackgroundColor3 = Color3.fromRGB(30, 100, 40)
continueBtn.BorderSizePixel = 0
continueBtn.Font = Enum.Font.GothamBold
continueBtn.TextSize = 15
continueBtn.TextColor3 = Color3.fromRGB(200, 255, 210)
continueBtn.Text = "Continue"
Instance.new("UICorner", continueBtn).CornerRadius = UDim.new(0, 10)
local btnStroke = Instance.new("UIStroke", continueBtn)
btnStroke.Color = Color3.fromRGB(60, 180, 80); btnStroke.Thickness = 1.5

gui.Enabled = false

-- ── Dismiss logic ─────────────────────────────────────────────────────────────
local dismissThread = nil
local function dismiss()
    if dismissThread then task.cancel(dismissThread) dismissThread = nil end
    countdownLabel.Text = ""
    TweenService:Create(frame, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
    task.delay(0.25, function() gui.Enabled = false end)
end

continueBtn.Activated:Connect(dismiss)

-- ── Events ────────────────────────────────────────────────────────────────────
summaryEvent.OnClientEvent:Connect(function(data)
    if statLabels.orders then statLabels.orders.Text = tostring(data.orders or 0) end
    if statLabels.coins  then statLabels.coins.Text  = tostring(data.coins or 0) end
    if statLabels.combo  then statLabels.combo.Text  = "x" .. tostring(data.combo or 0) end
    if statLabels.stars  then
        local s = math.clamp(math.round(data.avgStars or 3), 1, 5)
        statLabels.stars.Text = string.rep("★",s) .. string.rep("☆",5-s)
        statLabels.stars.TextColor3 = C.GOLD
    end

    local emp = data.employees
    if emp then
        local fmts = { Mixer="%d%%", Baller="%d batches", Baker="%d%%", Glazer="%d%%", Decorator="%d boxes" }
        for _, def in ipairs(ROLE_DEFS) do
            local row   = frame:FindFirstChild("Emp_"..def.role)
            local e     = emp[def.role]
            if not row or not e then continue end
            local nameL = row:FindFirstChild("PlayerName")
            local valL  = row:FindFirstChild("Val")
            local hasWinner = e.value and e.value > 0
            if nameL then
                nameL.Text       = def.role .. ":  " .. (e.name or "—")
                nameL.TextColor3 = hasWinner and C.WHITE or C.MUTED
            end
            if valL then
                valL.Text       = hasWinner and string.format(fmts[def.role] or "%d", e.value) or ""
                valL.TextColor3 = hasWinner and C.GOLD or C.MUTED
            end
        end
    end

    -- Animate in
    gui.Enabled = true
    frame.BackgroundTransparency = 1; outerStroke.Transparency = 1
    TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { BackgroundTransparency = 0 }):Play()
    TweenService:Create(outerStroke, TweenInfo.new(0.3), { Transparency = 0.3 }):Play()
end)

stateRemote.OnClientEvent:Connect(function(state)
    if state == "PreOpen" then
        TweenService:Create(frame, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
        task.delay(0.25, function() gui.Enabled = false end)
    end
end)

print("[SummaryController] Ready.")
