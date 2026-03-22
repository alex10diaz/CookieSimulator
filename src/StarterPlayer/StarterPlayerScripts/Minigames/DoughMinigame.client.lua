-- DoughMinigame.client.lua (redesigned + M7 polish)
-- Three sub-games: Weigh -> Form -> Tray
-- Weigh: 0-34 pts, Form: 0-33 pts, Tray: 0-33 pts

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")

local RemoteManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local startRemote   = RemoteManager.Get("StartDoughMinigame")
local resultRemote  = RemoteManager.Get("DoughMinigameResult")
local cancelRemote  = RemoteManager.Get("CancelMinigame")

local player = Players.LocalPlayer

local WEIGH_MAX_TIME  = 10
local FORM_FILL_TIME  = 4
local TRAY_TIME       = 6
local WEIGH_ZONE_MIN  = 0.55
local WEIGH_ZONE_MAX  = 0.75
local FORM_ZONE_MIN   = 0.45
local FORM_ZONE_MAX   = 0.65
local WEIGH_MAX_PTS   = 34
local FORM_MAX_PTS    = 33
local TRAY_MAX_PTS    = 33

local ACCENT = Color3.fromRGB(255, 170, 40)  -- warm amber (dough)

startRemote.OnClientEvent:Connect(function()
    if player:WaitForChild("PlayerGui"):FindFirstChild("DoughGui") then return end
    local char = player.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    humanoid.WalkSpeed = 0
    humanoid.JumpHeight = 0

    local sg = Instance.new("ScreenGui")
    sg.Name           = "DoughGui"
    sg.ResetOnSpawn          = false
    sg.ZIndexBehavior        = Enum.ZIndexBehavior.Sibling
    sg.DisplayOrder          = 22
    sg.SafeAreaCompatibility = Enum.SafeAreaCompatibility.FullscreenExtension  -- m9
    sg.Parent                = player:WaitForChild("PlayerGui")

    local bg = Instance.new("Frame")
    local _fw = math.min(380, workspace.CurrentCamera.ViewportSize.X - 20)
    bg.Size                   = UDim2.new(0, _fw, 0, 460)
    bg.Position               = UDim2.new(0.5, -_fw/2, 0.5, -230)
    bg.BackgroundColor3       = Color3.fromRGB(15, 30, 60)
    bg.BackgroundTransparency = 0
    bg.BorderSizePixel        = 0
    bg.Parent                 = sg
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 16)
    local bgStroke = Instance.new("UIStroke", bg)
    bgStroke.Color = ACCENT
    bgStroke.Thickness = 1.5

    -- Amber header bar
    local headerBar = Instance.new("Frame", bg)
    headerBar.Size = UDim2.new(1, 0, 0, 44)
    headerBar.BackgroundColor3 = ACCENT
    headerBar.BorderSizePixel = 0
    Instance.new("UICorner", headerBar).CornerRadius = UDim.new(0, 16)
    local headerFlat = Instance.new("Frame", headerBar)
    headerFlat.Size = UDim2.new(1, 0, 0.5, 0)
    headerFlat.Position = UDim2.new(0, 0, 0.5, 0)
    headerFlat.BackgroundColor3 = ACCENT
    headerFlat.BorderSizePixel = 0

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size                   = UDim2.new(1, -14, 1, 0)
    titleLbl.Position               = UDim2.new(0, 14, 0, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.TextColor3             = Color3.fromRGB(30, 18, 4)
    titleLbl.TextScaled             = true
    titleLbl.Font                   = Enum.Font.GothamBold
    titleLbl.Text                   = "DOUGH — Step 1/3: Weigh"
    titleLbl.TextXAlignment         = Enum.TextXAlignment.Left
    titleLbl.Parent                 = headerBar

    local subLbl = Instance.new("TextLabel")
    subLbl.Size                   = UDim2.new(1, -20, 0, 28)
    subLbl.Position               = UDim2.new(0, 10, 0, 48)
    subLbl.BackgroundTransparency = 1
    subLbl.TextColor3             = Color3.fromRGB(165, 168, 210)
    subLbl.TextScaled             = true
    subLbl.Font                   = Enum.Font.Gotham
    subLbl.Text                   = "Hold button — release in the green zone"
    subLbl.Parent                 = bg

    local content = Instance.new("Frame")
    content.Size             = UDim2.new(1, -20, 0, 336)
    content.Position         = UDim2.new(0, 10, 0, 80)
    content.BackgroundTransparency = 1
    content.BorderSizePixel  = 0
    content.Parent           = bg

    local timerBar = Instance.new("Frame")
    timerBar.Size             = UDim2.new(1, -20, 0, 8)
    timerBar.Position         = UDim2.new(0, 10, 1, -20)
    timerBar.BackgroundColor3 = Color3.fromRGB(25, 25, 45)
    timerBar.BorderSizePixel  = 0
    timerBar.Parent           = bg
    Instance.new("UICorner", timerBar).CornerRadius = UDim.new(0, 4)
    local timerFill = Instance.new("Frame")
    timerFill.Size             = UDim2.new(1, 0, 1, 0)
    timerFill.BackgroundColor3 = ACCENT
    timerFill.BorderSizePixel  = 0
    timerFill.Parent           = timerBar
    Instance.new("UICorner", timerFill).CornerRadius = UDim.new(0, 4)

    local totalScore = 0
    local finished   = false
    local phaseConn

    local function endMinigame()
        if finished then return end
        finished = true
        if phaseConn then phaseConn:Disconnect() end
        humanoid.WalkSpeed = 16
        humanoid.JumpHeight = 7.2
        sg:Destroy()
        resultRemote:FireServer(math.clamp(totalScore, 0, 100))
    end

    -- m7: exit button
    do
        local exitBtn = Instance.new("TextButton")
        exitBtn.Size             = UDim2.new(0, 36, 0, 28)
        exitBtn.Position         = UDim2.new(1, -40, 0, 8)
        exitBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
        exitBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
        exitBtn.TextScaled       = true
        exitBtn.Font             = Enum.Font.GothamBold
        exitBtn.Text             = "✕"
        exitBtn.BorderSizePixel  = 0
        exitBtn.ZIndex           = 5
        exitBtn.Parent           = headerBar
        Instance.new("UICorner", exitBtn).CornerRadius = UDim.new(0, 6)
        exitBtn.MouseButton1Click:Connect(function()
            if finished then return end
            finished = true
            if phaseConn then phaseConn:Disconnect() end
            humanoid.WalkSpeed  = 16
            humanoid.JumpHeight = 7.2
            sg:Destroy()
            cancelRemote:FireServer()
        end)
    end

    -- PHASE 3: TRAY
    local function startTray(prevScore)
        totalScore = prevScore
        content:ClearAllChildren()
        titleLbl.Text = "DOUGH — Step 3/3: Tray"
        subLbl.Text   = "Click all 6 spots!"

        local trayFrame = Instance.new("Frame")
        trayFrame.Size             = UDim2.new(0, 280, 0, 200)
        trayFrame.Position         = UDim2.new(0.5, -140, 0.5, -100)
        trayFrame.BackgroundColor3 = Color3.fromRGB(28, 24, 46)
        trayFrame.BorderSizePixel  = 0
        trayFrame.Parent           = content
        Instance.new("UICorner", trayFrame).CornerRadius = UDim.new(0, 12)
        local trayStroke = Instance.new("UIStroke", trayFrame)
        trayStroke.Color = Color3.fromRGB(55, 48, 80)
        trayStroke.Thickness = 1

        local COLS, ROWS = 3, 2
        local SPOT_W, SPOT_H = 60, 60
        local PAD_X = (280 - COLS * SPOT_W) / (COLS + 1)
        local PAD_Y = (200 - ROWS * SPOT_H) / (ROWS + 1)
        local spotsClicked = 0

        for row = 1, ROWS do
            for col = 1, COLS do
                local spot = Instance.new("TextButton")
                spot.Size             = UDim2.new(0, SPOT_W, 0, SPOT_H)
                spot.Position         = UDim2.new(
                    0, PAD_X + (col - 1) * (SPOT_W + PAD_X),
                    0, PAD_Y + (row - 1) * (SPOT_H + PAD_Y)
                )
                spot.BackgroundColor3 = Color3.fromRGB(60, 50, 90)
                spot.TextColor3       = Color3.fromRGB(200, 170, 110)
                spot.TextScaled       = true
                spot.Font             = Enum.Font.GothamBold
                spot.Text             = "+"
                spot.BorderSizePixel  = 0
                spot.AutoButtonColor  = false
                spot.Parent           = trayFrame
                Instance.new("UICorner", spot).CornerRadius = UDim.new(1, 0)
                local spotStroke = Instance.new("UIStroke", spot)
                spotStroke.Color = Color3.fromRGB(100, 85, 140)
                spotStroke.Thickness = 1.5

                local alreadyClicked = false
                spot.MouseButton1Click:Connect(function()
                    if finished or alreadyClicked then return end
                    alreadyClicked = true
                    spot.BackgroundColor3 = Color3.fromRGB(80, 200, 80)
                    spot.TextColor3 = Color3.fromRGB(20, 50, 20)
                    spotStroke.Color = Color3.fromRGB(50, 160, 50)
                    spot.Text = "✓"
                    spotsClicked = spotsClicked + 1
                    if spotsClicked >= COLS * ROWS then
                        totalScore = prevScore + TRAY_MAX_PTS
                        task.delay(0.3, endMinigame)
                    end
                end)
            end
        end

        local elapsed = 0
        if phaseConn then phaseConn:Disconnect() end
        phaseConn = RunService.Heartbeat:Connect(function(dt)
            elapsed = elapsed + dt
            timerFill.Size = UDim2.new(math.clamp(1 - elapsed / TRAY_TIME, 0, 1), 0, 1, 0)
            if elapsed >= TRAY_TIME then
                totalScore = prevScore + math.floor(spotsClicked / (COLS * ROWS) * TRAY_MAX_PTS)
                phaseConn:Disconnect()
                endMinigame()
            end
        end)
    end

    -- PHASE 2: FORM
    local function startForm(prevScore)
        content:ClearAllChildren()
        titleLbl.Text = "DOUGH — Step 2/3: Form"
        subLbl.Text   = "Press STOP when circle is in the green zone!"

        local BAR_SIZE = 200
        local areaFrame = Instance.new("Frame")
        areaFrame.Size             = UDim2.new(0, BAR_SIZE + 60, 0, BAR_SIZE + 60)
        areaFrame.Position         = UDim2.new(0.5, -(BAR_SIZE + 60) / 2, 0.5, -(BAR_SIZE + 60) / 2)
        areaFrame.BackgroundTransparency = 1
        areaFrame.BorderSizePixel  = 0
        areaFrame.Parent           = content

        local zoneMax = math.floor(BAR_SIZE * FORM_ZONE_MAX)
        local zoneMin = math.floor(BAR_SIZE * FORM_ZONE_MIN)

        local zoneOuter = Instance.new("Frame")
        zoneOuter.Size             = UDim2.new(0, zoneMax, 0, zoneMax)
        zoneOuter.Position         = UDim2.new(0.5, -zoneMax/2, 0.5, -zoneMax/2)
        zoneOuter.BackgroundColor3 = Color3.fromRGB(80, 200, 80)
        zoneOuter.BackgroundTransparency = 0.4
        zoneOuter.BorderSizePixel  = 0
        zoneOuter.ZIndex           = 1
        zoneOuter.Parent           = areaFrame
        Instance.new("UICorner", zoneOuter).CornerRadius = UDim.new(1, 0)

        local zoneInner = Instance.new("Frame")
        zoneInner.Size             = UDim2.new(0, zoneMin, 0, zoneMin)
        zoneInner.Position         = UDim2.new(0.5, -zoneMin/2, 0.5, -zoneMin/2)
        zoneInner.BackgroundColor3 = Color3.fromRGB(15, 30, 60)
        zoneInner.BorderSizePixel  = 0
        zoneInner.ZIndex           = 2
        zoneInner.Parent           = areaFrame
        Instance.new("UICorner", zoneInner).CornerRadius = UDim.new(1, 0)

        local growCircle = Instance.new("Frame")
        growCircle.Size             = UDim2.new(0, 0, 0, 0)
        growCircle.AnchorPoint      = Vector2.new(0.5, 0.5)
        growCircle.Position         = UDim2.new(0.5, 0, 0.5, 0)
        growCircle.BackgroundColor3 = ACCENT
        growCircle.BorderSizePixel  = 0
        growCircle.ZIndex           = 3
        growCircle.Parent           = areaFrame
        Instance.new("UICorner", growCircle).CornerRadius = UDim.new(1, 0)

        local stopBtn = Instance.new("TextButton")
        stopBtn.Size             = UDim2.new(0, 120, 0, 44)
        stopBtn.Position         = UDim2.new(0.5, -60, 1, -50)
        stopBtn.BackgroundColor3 = Color3.fromRGB(210, 60, 60)
        stopBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
        stopBtn.TextScaled       = true
        stopBtn.Font             = Enum.Font.GothamBold
        stopBtn.Text             = "STOP"
        stopBtn.BorderSizePixel  = 0
        stopBtn.Parent           = content
        Instance.new("UICorner", stopBtn).CornerRadius = UDim.new(0, 10)

        local elapsed = 0
        local stopped = false

        local function calcFormScore(frac)
            local center   = (FORM_ZONE_MIN + FORM_ZONE_MAX) / 2
            local halfZone = (FORM_ZONE_MAX - FORM_ZONE_MIN) / 2
            local dist     = math.abs(frac - center)
            if dist <= halfZone then
                return math.floor(FORM_MAX_PTS * (1 - dist / halfZone * 0.3))
            elseif dist <= halfZone + 0.15 then
                return math.floor(FORM_MAX_PTS * 0.5 * (1 - (dist - halfZone) / 0.15))
            else
                return 0
            end
        end

        stopBtn.MouseButton1Click:Connect(function()
            if stopped then return end
            stopped = true
            local pts = calcFormScore(math.clamp(elapsed / FORM_FILL_TIME, 0, 1))
            task.delay(0.3, function() startTray(prevScore + pts) end)
        end)

        if phaseConn then phaseConn:Disconnect() end
        phaseConn = RunService.Heartbeat:Connect(function(dt)
            if stopped then phaseConn:Disconnect() return end
            elapsed = elapsed + dt
            local frac = math.clamp(elapsed / FORM_FILL_TIME, 0, 1)
            timerFill.Size = UDim2.new(1 - frac, 0, 1, 0)
            growCircle.Size = UDim2.new(0, math.floor(frac * BAR_SIZE), 0, math.floor(frac * BAR_SIZE))
            if frac >= 1 then
                stopped = true
                phaseConn:Disconnect()
                task.delay(0.3, function() startTray(prevScore + 0) end)
            end
        end)
    end

    -- PHASE 1: WEIGH
    do
        local BAR_H = 260
        local barTrack = Instance.new("Frame")
        barTrack.Size             = UDim2.new(0, 60, 0, BAR_H)
        barTrack.Position         = UDim2.new(0.5, -30, 0.5, -BAR_H / 2)
        barTrack.BackgroundColor3 = Color3.fromRGB(28, 28, 50)
        barTrack.BorderSizePixel  = 0
        barTrack.ClipsDescendants = false
        barTrack.Parent           = content
        Instance.new("UICorner", barTrack).CornerRadius = UDim.new(0, 8)
        local trackStroke = Instance.new("UIStroke", barTrack)
        trackStroke.Color = Color3.fromRGB(50, 50, 80)
        trackStroke.Thickness = 1

        local zoneH = math.floor(BAR_H * (WEIGH_ZONE_MAX - WEIGH_ZONE_MIN))
        local zoneY = math.floor(BAR_H * (1 - WEIGH_ZONE_MAX))
        local zoneFrame = Instance.new("Frame")
        zoneFrame.Size             = UDim2.new(1, 8, 0, zoneH)
        zoneFrame.Position         = UDim2.new(0, -4, 0, zoneY)
        zoneFrame.BackgroundColor3 = Color3.fromRGB(80, 200, 80)
        zoneFrame.BackgroundTransparency = 0.35
        zoneFrame.BorderSizePixel  = 0
        zoneFrame.ZIndex           = 2
        zoneFrame.Parent           = barTrack
        Instance.new("UICorner", zoneFrame).CornerRadius = UDim.new(0, 4)

        local fillFrame = Instance.new("Frame")
        fillFrame.Size             = UDim2.new(1, 0, 0, 0)
        fillFrame.AnchorPoint      = Vector2.new(0, 1)
        fillFrame.Position         = UDim2.new(0, 0, 1, 0)
        fillFrame.BackgroundColor3 = ACCENT
        fillFrame.BorderSizePixel  = 0
        fillFrame.Parent           = barTrack
        Instance.new("UICorner", fillFrame).CornerRadius = UDim.new(0, 8)

        local holdBtn = Instance.new("TextButton")
        holdBtn.Size             = UDim2.new(0, 130, 0, 50)
        holdBtn.Position         = UDim2.new(0.5, -65, 1, -55)
        holdBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 200)
        holdBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
        holdBtn.TextScaled       = true
        holdBtn.Font             = Enum.Font.GothamBold
        holdBtn.Text             = "HOLD"
        holdBtn.BorderSizePixel  = 0
        holdBtn.Parent           = content
        Instance.new("UICorner", holdBtn).CornerRadius = UDim.new(0, 10)

        local lbl1 = Instance.new("TextLabel")
        lbl1.Size = UDim2.new(0, 55, 0, 22)
        lbl1.Position = UDim2.new(0.5, 38, 0.5, -BAR_H/2 + 4)
        lbl1.BackgroundTransparency = 1
        lbl1.TextColor3 = Color3.fromRGB(255, 100, 50)
        lbl1.TextScaled = true
        lbl1.Font = Enum.Font.GothamBold
        lbl1.Text = "HEAVY"
        lbl1.Parent = content

        local lbl2 = Instance.new("TextLabel")
        lbl2.Size = UDim2.new(0, 55, 0, 22)
        lbl2.Position = UDim2.new(0.5, 38, 0.5, BAR_H/2 - 26)
        lbl2.BackgroundTransparency = 1
        lbl2.TextColor3 = Color3.fromRGB(100, 180, 255)
        lbl2.TextScaled = true
        lbl2.Font = Enum.Font.GothamBold
        lbl2.Text = "LIGHT"
        lbl2.Parent = content

        local fillFrac  = 0
        local isHolding = false
        local weighDone = false
        local elapsed   = 0
        local FILL_RATE = 1 / 3

        local function calcWeighScore(frac)
            if frac >= WEIGH_ZONE_MIN and frac <= WEIGH_ZONE_MAX then
                local center = (WEIGH_ZONE_MIN + WEIGH_ZONE_MAX) / 2
                local halfZ  = (WEIGH_ZONE_MAX - WEIGH_ZONE_MIN) / 2
                local dist   = math.abs(frac - center)
                return math.floor(WEIGH_MAX_PTS * (1 - dist / halfZ * 0.25))
            else
                local nearest = frac < WEIGH_ZONE_MIN and WEIGH_ZONE_MIN or WEIGH_ZONE_MAX
                local dist    = math.abs(frac - nearest)
                if dist < 0.15 then
                    return math.floor(WEIGH_MAX_PTS * 0.5 * (1 - dist / 0.15))
                end
                return 0
            end
        end

        holdBtn.MouseButton1Down:Connect(function()
            if weighDone then return end
            isHolding = true
        end)

        UserInputService.InputEnded:Connect(function(input)
            if weighDone or finished then return end
            if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and isHolding then
                isHolding = false
                weighDone = true
                local pts = calcWeighScore(fillFrac)
                holdBtn.BackgroundColor3 = pts >= 17
                    and Color3.fromRGB(80, 200, 80)
                    or  Color3.fromRGB(200, 80, 80)
                task.delay(0.4, function() startForm(pts) end)
            end
        end)

        if phaseConn then phaseConn:Disconnect() end
        phaseConn = RunService.Heartbeat:Connect(function(dt)
            if finished then phaseConn:Disconnect() return end
            elapsed = elapsed + dt
            timerFill.Size = UDim2.new(math.clamp(1 - elapsed / WEIGH_MAX_TIME, 0, 1), 0, 1, 0)

            if isHolding and not weighDone then
                fillFrac = math.clamp(fillFrac + FILL_RATE * dt, 0, 1)
                fillFrame.Size = UDim2.new(1, 0, fillFrac, 0)
                if fillFrac >= 1 then
                    isHolding = false
                    weighDone = true
                    holdBtn.BackgroundColor3 = Color3.fromRGB(200, 80, 80)
                    task.delay(0.4, function() startForm(0) end)
                end
            end

            if elapsed >= WEIGH_MAX_TIME and not weighDone then
                weighDone = true
                phaseConn:Disconnect()
                startForm(calcWeighScore(fillFrac))
            end
        end)
    end
end)

print("[DoughMinigame] Ready.")
