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

-- ── Palette (dark navy-blue modal — matches minigame modals) ──────────────────
local C = {
    BG       = Color3.fromRGB(15, 30, 60),    -- dark navy-blue
    CARD     = Color3.fromRGB(22, 42, 80),    -- stat card bg
    CARD2    = Color3.fromRGB(28, 50, 90),    -- employee row bg
    GOLD     = Color3.fromRGB(255, 205, 50),  -- gold
    GOLD_DIM = Color3.fromRGB(180, 140, 0),   -- header gradient dim end
    WHITE    = Color3.fromRGB(240, 240, 255),  -- cool white text
    MUTED    = Color3.fromRGB(110, 140, 190),  -- blue-toned muted text
}

-- ── Build frame ───────────────────────────────────────────────────────────────
local frame = gui:FindFirstChild("SummaryFrame")
if frame then frame:Destroy() end

frame = Instance.new("Frame")
frame.Name             = "SummaryFrame"
-- Use 45% of screen width (min 400px, max 560px) for a fuller panel on all screens
local _vpW = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.X or 800
local _vpH = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.Y or 900
local _fw  = math.clamp(math.floor(_vpW * 0.45), 400, 560)
local _fh  = math.min(630, math.floor(_vpH * 0.90))
frame.Size             = UDim2.new(0, _fw, 0, _fh)
frame.Position         = UDim2.new(0.5, -math.floor(_fw/2), 0.5, -math.floor(_fh/2))
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

-- ── Shift Grade row ───────────────────────────────────────────────────────────
local gradeRow = Instance.new("Frame", frame)
gradeRow.Name = "GradeRow"
gradeRow.Size = UDim2.new(1,-20,0,40); gradeRow.Position = UDim2.new(0,10,0,168)
gradeRow.BackgroundColor3 = C.CARD; gradeRow.BackgroundTransparency = 0; gradeRow.BorderSizePixel = 0
Instance.new("UICorner", gradeRow).CornerRadius = UDim.new(0, 8)

local gradeLabelL = Instance.new("TextLabel", gradeRow)
gradeLabelL.Size = UDim2.new(0.6,0,1,0); gradeLabelL.Position = UDim2.new(0,12,0,0)
gradeLabelL.BackgroundTransparency = 1; gradeLabelL.TextColor3 = C.MUTED
gradeLabelL.Font = Enum.Font.GothamBold; gradeLabelL.TextScaled = true
gradeLabelL.TextXAlignment = Enum.TextXAlignment.Left; gradeLabelL.Text = "SHIFT GRADE"

local gradeValL = Instance.new("TextLabel", gradeRow)
gradeValL.Name = "GradeVal"
gradeValL.Size = UDim2.new(0.38,0,1,0); gradeValL.Position = UDim2.new(0.62,0,0,0)
gradeValL.BackgroundTransparency = 1; gradeValL.TextColor3 = C.GOLD
gradeValL.Font = Enum.Font.GothamBold; gradeValL.TextScaled = true
gradeValL.TextXAlignment = Enum.TextXAlignment.Right; gradeValL.Text = "—"

-- ── Station Breakdown Strip ────────────────────────────────────────────────────
local stationStrip = Instance.new("Frame", frame)
stationStrip.Name = "StationStrip"
stationStrip.Size = UDim2.new(1,-20,0,48); stationStrip.Position = UDim2.new(0,10,0,216)
stationStrip.BackgroundTransparency = 1; stationStrip.BorderSizePixel = 0

local stripLayout = Instance.new("UIListLayout", stationStrip)
stripLayout.FillDirection = Enum.FillDirection.Horizontal
stripLayout.SortOrder = Enum.SortOrder.LayoutOrder
stripLayout.Padding = UDim.new(0, 5)

local STATION_DEFS = {
    { key="mix",   label="Mix",   icon="🥣", fmt="%d%%" },
    { key="dough", label="Dough", icon="🍪", fmt="%dx"  },
    { key="oven",  label="Oven",  icon="🔥", fmt="%d%%" },
    { key="frost", label="Frost", icon="🧁", fmt="%d%%" },
    { key="dress", label="Dress", icon="🎁", fmt="%dx"  },
}

local stationCards = {}
for i, def in ipairs(STATION_DEFS) do
    local card = Instance.new("Frame", stationStrip)
    card.Name = "Station_"..def.key
    card.Size = UDim2.new(0.185, 0, 1, 0)
    card.BackgroundColor3 = C.CARD; card.BackgroundTransparency = 0; card.BorderSizePixel = 0
    card.LayoutOrder = i
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6)

    local iconL = Instance.new("TextLabel", card)
    iconL.Size = UDim2.new(1,0,0.48,0); iconL.Position = UDim2.new(0,0,0,0)
    iconL.BackgroundTransparency = 1; iconL.TextColor3 = C.MUTED
    iconL.Font = Enum.Font.GothamBold; iconL.TextScaled = true
    iconL.Text = def.icon

    local valL = Instance.new("TextLabel", card)
    valL.Name = "Val"; valL.Size = UDim2.new(1,0,0.52,0); valL.Position = UDim2.new(0,0,0.48,0)
    valL.BackgroundTransparency = 1; valL.TextColor3 = C.WHITE
    valL.Font = Enum.Font.GothamBold; valL.TextScaled = true
    valL.Text = "—"

    stationCards[def.key] = { card=card, valL=valL, fmt=def.fmt }
end

-- ── Divider ───────────────────────────────────────────────────────────────────
local div = Instance.new("Frame", frame)
div.Size = UDim2.new(1,-20,0,1); div.Position = UDim2.new(0,10,0,272)
div.BackgroundColor3 = Color3.fromRGB(40, 70, 120); div.BorderSizePixel = 0

-- ── Employee of Shift ─────────────────────────────────────────────────────────
local empHeader = Instance.new("TextLabel", frame)
empHeader.Name = "EmpTitle"; empHeader.Size = UDim2.new(1,-20,0,28)
empHeader.Position = UDim2.new(0,10,0,280)
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
    row.Position = UDim2.new(0,10,0, 314 + (idx-1)*44)
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
countdownLabel.Size = UDim2.new(1, -20, 0, 22)
countdownLabel.Position = UDim2.new(0, 10, 0, 528)
countdownLabel.BackgroundTransparency = 1
countdownLabel.TextColor3 = Color3.fromRGB(110, 140, 190)
countdownLabel.Font = Enum.Font.Gotham
countdownLabel.TextScaled = true
countdownLabel.Text = ""

local continueBtn = Instance.new("TextButton", frame)
continueBtn.Name = "ContinueBtn"
continueBtn.Size = UDim2.new(1, -40, 0, 48)
continueBtn.Position = UDim2.new(0, 20, 0, 554)
continueBtn.BackgroundColor3 = Color3.fromRGB(200, 40, 100)
continueBtn.BorderSizePixel = 0
continueBtn.Font = Enum.Font.GothamBold
continueBtn.TextSize = 15
continueBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
continueBtn.Text = "Continue →"
Instance.new("UICorner", continueBtn).CornerRadius = UDim.new(0, 10)
local btnStroke = Instance.new("UIStroke", continueBtn)
btnStroke.Color = Color3.fromRGB(240, 90, 150); btnStroke.Thickness = 1.5

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
local GRADE_COLORS = {
    S = Color3.fromRGB(255, 205,  50),  -- gold
    A = Color3.fromRGB(  0, 200, 100),  -- green
    B = Color3.fromRGB( 80, 175, 255),  -- blue
    C = Color3.fromRGB(255, 160,  50),  -- orange
    D = Color3.fromRGB(220,  50,  80),  -- red
}

summaryEvent.OnClientEvent:Connect(function(data)
    if statLabels.orders then statLabels.orders.Text = tostring(data.orders or 0) end
    if statLabels.coins  then statLabels.coins.Text  = tostring(data.coins or 0) end
    if statLabels.combo  then statLabels.combo.Text  = "x" .. tostring(data.combo or 0) end
    if statLabels.stars  then
        local s = math.clamp(math.round(data.avgStars or 3), 1, 5)
        -- UI-7: include numeric so players can read their rating clearly
        statLabels.stars.Text = string.rep("★",s) .. string.rep("☆",5-s) .. "  " .. s .. "/5"
        statLabels.stars.TextColor3 = C.GOLD
    end

    -- Shift grade badge
    local sg = data.shiftGrade
    if sg and gradeValL then
        local g = sg.grade or "D"
        gradeValL.Text       = g .. "  (" .. tostring(sg.score) .. " pts)"
        gradeValL.TextColor3 = GRADE_COLORS[g] or C.WHITE
    end

    -- Station breakdown strip
    local bd = data.stationBreakdown
    if bd then
        local function scoreColor(pct)
            if not pct then return C.MUTED end
            if pct >= 80 then return Color3.fromRGB(80, 220, 80)
            elseif pct >= 60 then return Color3.fromRGB(255, 200, 60)
            elseif pct >= 40 then return Color3.fromRGB(255, 130, 40)
            else return Color3.fromRGB(230, 60, 60) end
        end
        for _, def in ipairs(STATION_DEFS) do
            local sc = stationCards[def.key]
            if sc then
                local v = bd[def.key]
                if v then
                    sc.valL.Text = string.format(def.fmt, v)
                    sc.valL.TextColor3 = (def.key == "dough" or def.key == "dress")
                        and C.WHITE or scoreColor(v)
                    sc.card.BackgroundColor3 = C.CARD
                else
                    sc.valL.Text = "—"
                    sc.valL.TextColor3 = C.MUTED
                    sc.card.BackgroundColor3 = Color3.fromRGB(18, 32, 65)
                end
            end
        end
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

    -- M-7: Animate in — slide up from below + staggered stat counters + grade bounce
    local centreY  = UDim2.new(0.5, -math.floor(_fh/2), 0.5, -math.floor(_fh/2))
    local offscreenY = UDim2.new(frame.Position.X.Scale, frame.Position.X.Offset, 1.15, 0)
    gui.Enabled = true
    frame.BackgroundTransparency = 1
    frame.Position = offscreenY
    outerStroke.Transparency = 1

    -- Slide up + fade in simultaneously
    TweenService:Create(frame,
        TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Position = frame.Position:Lerp(
            UDim2.new(0.5, -math.floor(_fw/2), 0.5, -math.floor(_fh/2)), 1),
          BackgroundTransparency = 0 }):Play()
    TweenService:Create(outerStroke, TweenInfo.new(0.4), { Transparency = 0.3 }):Play()

    -- Staggered stat counter tick-ups
    local rawVals = {
        orders = data.orders or 0,
        coins  = data.coins  or 0,
        combo  = data.combo  or 0,
    }
    local TICKS   = 28
    local TICK_DT = 0.045
    for i, def in ipairs(STAT_DEFS) do
        local key = def.key
        local target = rawVals[key]
        if target and statLabels[key] then
            local lbl = statLabels[key]
            local delay = 0.3 + (i - 1) * 0.12
            task.delay(delay, function()
                local prefix = key == "combo" and "x" or ""
                for tick = 1, TICKS do
                    local v = math.floor(target * (tick / TICKS))
                    lbl.Text = prefix .. tostring(v)
                    task.wait(TICK_DT)
                end
                -- Ensure final value is exact
                lbl.Text = prefix .. tostring(target)
            end)
        end
    end

    -- Grade badge bounce-in
    if gradeValL then
        gradeValL.TextTransparency = 1
        task.delay(0.5, function()
            TweenService:Create(gradeValL,
                TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                { TextTransparency = 0 }):Play()
        end)
    end

    -- 15-second auto-dismiss
    if dismissThread then task.cancel(dismissThread) dismissThread = nil end
    dismissThread = task.spawn(function()
        local t = 15
        while t > 0 do
            countdownLabel.Text = "Auto-closing in " .. t .. "s"
            task.wait(1)
            t -= 1
        end
        dismissThread = nil  -- BUG-64: clear before dismiss() so it doesn't self-cancel
        dismiss()
    end)
end)

stateRemote.OnClientEvent:Connect(function(state)
    if state == "Intermission" or state == "PreOpen" then
        dismiss()
    end
end)

print("[SummaryController] Ready.")
