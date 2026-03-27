-- OvenMinigame.client.lua (redesigned + M7 polish)
-- Two sub-games: Load Trays -> Bake Timing
-- Load: 0-50 pts, Bake: 0-50 pts

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local RemoteManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local startRemote   = RemoteManager.Get("StartOvenMinigame")
local resultRemote  = RemoteManager.Get("OvenMinigameResult")
local cancelRemote  = RemoteManager.Get("CancelMinigame")
local EffectsModule
task.spawn(function() local ok,m = pcall(require, game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("EffectsModule")); if ok then EffectsModule = m end end)

local player = Players.LocalPlayer

local NUM_RACKS   = 3
local LOAD_TIME   = 8
local BAKE_TIME   = 6
local BAR_H       = 240
local ZONE_MIN    = 0.25
local ZONE_MAX    = 0.75
local ZONE_H_FRAC = 0.22

local ACCENT = Color3.fromRGB(255, 120, 30)  -- fire orange (oven)

startRemote.OnClientEvent:Connect(function()
    if player:WaitForChild("PlayerGui"):FindFirstChild("OvenGui") then return end
    local char = player.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    humanoid.WalkSpeed = 0
    humanoid.JumpHeight = 0

    local sg = Instance.new("ScreenGui")
    sg.Name           = "OvenGui"
    sg.ResetOnSpawn          = false
    sg.ZIndexBehavior        = Enum.ZIndexBehavior.Sibling
    sg.DisplayOrder          = 22
    sg.SafeAreaCompatibility = Enum.SafeAreaCompatibility.FullscreenExtension  -- m9
    sg.Parent                = player:WaitForChild("PlayerGui")

    local bg = Instance.new("Frame")
    local _fw = math.min(360, workspace.CurrentCamera.ViewportSize.X - 20)
    bg.Size                   = UDim2.new(0, _fw, 0, 440)
    bg.Position               = UDim2.new(0.5, -_fw/2, 0.5, -220)
    bg.BackgroundColor3       = Color3.fromRGB(15, 30, 60)
    bg.BackgroundTransparency = 0
    bg.BorderSizePixel        = 0
    bg.Parent                 = sg
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 16)
    local bgStroke = Instance.new("UIStroke", bg)
    bgStroke.Color = ACCENT
    bgStroke.Thickness = 1.5

    -- Orange header bar
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
    titleLbl.TextColor3             = Color3.fromRGB(30, 14, 4)
    titleLbl.TextScaled             = true
    titleLbl.Font                   = Enum.Font.GothamBold
    titleLbl.Text                   = "OVEN — Step 1/2: Load Trays"
    titleLbl.TextXAlignment         = Enum.TextXAlignment.Left
    titleLbl.Parent                 = headerBar

    local subLbl = Instance.new("TextLabel")
    subLbl.Size                   = UDim2.new(1, -20, 0, 28)
    subLbl.Position               = UDim2.new(0, 10, 0, 48)
    subLbl.BackgroundTransparency = 1
    subLbl.TextColor3             = Color3.fromRGB(195, 178, 152)
    subLbl.TextScaled             = true
    subLbl.Font                   = Enum.Font.Gotham
    subLbl.Text                   = "Click each rack to slide the tray in!"
    subLbl.Parent                 = bg

    local content = Instance.new("Frame")
    content.Size             = UDim2.new(1, -20, 0, 330)
    content.Position         = UDim2.new(0, 10, 0, 80)
    content.BackgroundTransparency = 1
    content.BorderSizePixel  = 0
    content.Parent           = bg

    local timerBar = Instance.new("Frame")
    timerBar.Size             = UDim2.new(1, -20, 0, 8)
    timerBar.Position         = UDim2.new(0, 10, 1, -20)
    timerBar.BackgroundColor3 = Color3.fromRGB(35, 22, 12)
    timerBar.BorderSizePixel  = 0
    timerBar.Parent           = bg
    Instance.new("UICorner", timerBar).CornerRadius = UDim.new(0, 4)
    local timerFill = Instance.new("Frame")
    timerFill.Size             = UDim2.new(1, 0, 1, 0)
    timerFill.BackgroundColor3 = ACCENT
    timerFill.BorderSizePixel  = 0
    timerFill.Parent           = timerBar
    Instance.new("UICorner", timerFill).CornerRadius = UDim.new(0, 4)

    local finished  = false
    local phaseConn

    local function endMinigame(score)
        if finished then return end
        finished = true
        if phaseConn then phaseConn:Disconnect() end
        humanoid.WalkSpeed = 16
        humanoid.JumpHeight = 7.2
        sg:Destroy()
        resultRemote:FireServer(math.clamp(score, 0, 100))
        do local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart"); if hrp then EffectsModule.Steam(hrp.Position) end end
    end

    -- m7: exit button — BUG-43: plain "X" text, floats outside top-right panel corner
    do
        local exitBtn = Instance.new("TextButton")
        exitBtn.Size             = UDim2.new(0, 44, 0, 44)
        exitBtn.AnchorPoint      = Vector2.new(1, 0)
        exitBtn.Position         = UDim2.new(1, 20, 0, -20)
        exitBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
        exitBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
        exitBtn.TextScaled       = true
        exitBtn.Font             = Enum.Font.GothamBold
        exitBtn.Text             = "X"
        exitBtn.BorderSizePixel  = 0
        exitBtn.ZIndex           = 10
        exitBtn.Parent           = bg
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

    -- PHASE 2: BAKE
    local function startBake(loadScore)
        content:ClearAllChildren()
        titleLbl.Text = "OVEN — Step 2/2: Bake!"
        subLbl.Text   = "Press STOP at the right temperature!"

        local barTrack = Instance.new("Frame")
        barTrack.Size             = UDim2.new(0, 60, 0, BAR_H)
        barTrack.Position         = UDim2.new(0.5, -30, 0.5, -BAR_H / 2)
        barTrack.BackgroundColor3 = Color3.fromRGB(38, 28, 18)
        barTrack.BorderSizePixel  = 0
        barTrack.ClipsDescendants = false
        barTrack.Parent           = content
        Instance.new("UICorner", barTrack).CornerRadius = UDim.new(0, 8)
        local trackStroke = Instance.new("UIStroke", barTrack)
        trackStroke.Color = Color3.fromRGB(75, 55, 35)
        trackStroke.Thickness = 1

        local fillFrame = Instance.new("Frame")
        fillFrame.Size             = UDim2.new(1, 0, 0, 0)
        fillFrame.AnchorPoint      = Vector2.new(0, 1)
        fillFrame.Position         = UDim2.new(0, 0, 1, 0)
        fillFrame.BackgroundColor3 = Color3.fromRGB(220, 120, 30)
        fillFrame.BorderSizePixel  = 0
        fillFrame.Parent           = barTrack
        Instance.new("UICorner", fillFrame).CornerRadius = UDim.new(0, 8)

        local zoneCenter = (ZONE_MIN + ZONE_MAX) / 2
        local zoneFrameH = math.floor(BAR_H * ZONE_H_FRAC)
        local zoneFrame  = Instance.new("Frame")
        zoneFrame.Size             = UDim2.new(1, 6, 0, zoneFrameH)
        zoneFrame.BackgroundColor3 = Color3.fromRGB(80, 200, 80)
        zoneFrame.BackgroundTransparency = 0.3
        zoneFrame.BorderSizePixel  = 0
        zoneFrame.ZIndex           = 2
        zoneFrame.AnchorPoint      = Vector2.new(0.5, 0.5)
        zoneFrame.Position         = UDim2.new(0.5, 0, 1 - zoneCenter, 0)
        zoneFrame.Parent           = barTrack
        Instance.new("UICorner", zoneFrame).CornerRadius = UDim.new(0, 4)

        local hotLbl = Instance.new("TextLabel")
        hotLbl.Size = UDim2.new(0, 50, 0, 22)
        hotLbl.Position = UDim2.new(0.5, 38, 0.5, -BAR_H/2)
        hotLbl.BackgroundTransparency = 1
        hotLbl.TextColor3 = Color3.fromRGB(255, 100, 50)
        hotLbl.TextScaled = true
        hotLbl.Font = Enum.Font.GothamBold
        hotLbl.Text = "HOT"
        hotLbl.Parent = content

        local coldLbl = Instance.new("TextLabel")
        coldLbl.Size = UDim2.new(0, 50, 0, 22)
        coldLbl.Position = UDim2.new(0.5, 38, 0.5, BAR_H/2 - 22)
        coldLbl.BackgroundTransparency = 1
        coldLbl.TextColor3 = Color3.fromRGB(100, 180, 255)
        coldLbl.TextScaled = true
        coldLbl.Font = Enum.Font.GothamBold
        coldLbl.Text = "COLD"
        coldLbl.Parent = content

        local stopBtn = Instance.new("TextButton")
        stopBtn.Size             = UDim2.new(0, 120, 0, 60)
        stopBtn.Position         = UDim2.new(0.5, -60, 1, -66)
        stopBtn.BackgroundColor3 = Color3.fromRGB(210, 60, 60)
        stopBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
        stopBtn.TextScaled       = true
        stopBtn.Font             = Enum.Font.GothamBold
        stopBtn.Text             = "STOP"
        stopBtn.BorderSizePixel  = 0
        stopBtn.Parent           = content
        Instance.new("UICorner", stopBtn).CornerRadius = UDim.new(0, 10)

        local function calcBakeScore(fillFrac)
            local halfZone = ZONE_H_FRAC / 2
            local dist     = math.abs(fillFrac - zoneCenter)
            if dist <= halfZone then
                return math.floor(50 * (1 - dist / halfZone * 0.3))
            elseif dist <= halfZone + 0.12 then
                return math.floor(25 * (1 - (dist - halfZone) / 0.12))
            else
                return math.floor(math.max(0, 20 * (1 - dist)))
            end
        end

        local elapsed = 0
        local stopped = false

        stopBtn.MouseButton1Click:Connect(function()
            if stopped then return end
            stopped = true
            endMinigame(loadScore + calcBakeScore(math.clamp(elapsed / BAKE_TIME, 0, 1)))
        end)

        if phaseConn then phaseConn:Disconnect() end
        phaseConn = RunService.Heartbeat:Connect(function(dt)
            if stopped then phaseConn:Disconnect() return end
            elapsed = elapsed + dt
            local frac = math.clamp(elapsed / BAKE_TIME, 0, 1)

            fillFrame.Size = UDim2.new(1, 0, frac, 0)
            timerFill.Size = UDim2.new(1 - frac, 0, 1, 0)

            local drift = math.sin(elapsed * 0.8) * 0.18
            zoneCenter  = math.clamp((ZONE_MIN + ZONE_MAX) / 2 + drift, ZONE_MIN, ZONE_MAX)
            zoneFrame.Position = UDim2.new(0.5, 0, 1 - zoneCenter, 0)

            if frac >= 1 then
                stopped = true
                phaseConn:Disconnect()
                endMinigame(loadScore + 5)
            end
        end)
    end

    -- PHASE 1: LOAD
    do
        local ovenBody = Instance.new("Frame")
        ovenBody.Size             = UDim2.new(0, 260, 0, 280)
        ovenBody.Position         = UDim2.new(0.5, -130, 0.5, -140)
        ovenBody.BackgroundColor3 = Color3.fromRGB(42, 36, 30)
        ovenBody.BorderSizePixel  = 0
        ovenBody.Parent           = content
        Instance.new("UICorner", ovenBody).CornerRadius = UDim.new(0, 10)
        local ovenStroke = Instance.new("UIStroke", ovenBody)
        ovenStroke.Color = Color3.fromRGB(80, 65, 50)
        ovenStroke.Thickness = 1.5

        local rackLoaded = 0
        local loadDone   = false

        for i = 1, NUM_RACKS do
            local rackBtn = Instance.new("TextButton")
            local rowH = 60
            rackBtn.Size             = UDim2.new(1, -20, 0, rowH - 8)
            rackBtn.Position         = UDim2.new(0, 10, 0, 20 + (i - 1) * (rowH + 8))
            rackBtn.BackgroundColor3 = Color3.fromRGB(58, 50, 40)
            rackBtn.TextColor3       = Color3.fromRGB(210, 190, 160)
            rackBtn.TextScaled       = true
            rackBtn.Font             = Enum.Font.Gotham
            rackBtn.Text             = "→  Rack " .. i
            rackBtn.BorderSizePixel  = 0
            rackBtn.AutoButtonColor  = false
            rackBtn.Parent           = ovenBody
            Instance.new("UICorner", rackBtn).CornerRadius = UDim.new(0, 6)
            local rackStroke = Instance.new("UIStroke", rackBtn)
            rackStroke.Color = Color3.fromRGB(95, 80, 62)
            rackStroke.Thickness = 1

            local traySlide = Instance.new("Frame")
            traySlide.Size             = UDim2.new(0, 0, 0.7, 0)
            traySlide.Position         = UDim2.new(0, 4, 0.15, 0)
            traySlide.BackgroundColor3 = Color3.fromRGB(190, 150, 80)
            traySlide.BorderSizePixel  = 0
            traySlide.ZIndex           = 2
            traySlide.Parent           = rackBtn
            Instance.new("UICorner", traySlide).CornerRadius = UDim.new(0, 4)

            local clicked = false
            rackBtn.MouseButton1Click:Connect(function()
                if clicked or loadDone then return end
                clicked = true
                rackBtn.BackgroundColor3 = Color3.fromRGB(80, 200, 80)
                rackBtn.TextColor3       = Color3.fromRGB(20, 50, 20)
                rackBtn.Text             = "✓  Rack " .. i .. " loaded"
                rackStroke.Color = Color3.fromRGB(50, 160, 50)
                traySlide.Size = UDim2.new(0.85, 0, 0.7, 0)
                rackLoaded = rackLoaded + 1
                if rackLoaded >= NUM_RACKS then
                    loadDone = true
                    task.delay(0.4, function() startBake(50) end)
                end
            end)
        end

        local elapsed = 0
        if phaseConn then phaseConn:Disconnect() end
        phaseConn = RunService.Heartbeat:Connect(function(dt)
            if finished then phaseConn:Disconnect() return end
            elapsed = elapsed + dt
            timerFill.Size = UDim2.new(math.clamp(1 - elapsed / LOAD_TIME, 0, 1), 0, 1, 0)
            if elapsed >= LOAD_TIME and not loadDone then
                loadDone = true
                phaseConn:Disconnect()
                startBake(math.floor(rackLoaded / NUM_RACKS * 50))
            end
        end)
    end
end)

print("[OvenMinigame] Ready.")
