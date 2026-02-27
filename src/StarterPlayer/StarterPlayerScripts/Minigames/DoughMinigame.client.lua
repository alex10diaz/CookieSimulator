-- src/StarterPlayer/StarterPlayerScripts/Minigames/DoughMinigame.client.lua
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")

local RemoteManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local startRemote   = RemoteManager.Get("StartDoughMinigame")
local resultRemote  = RemoteManager.Get("DoughMinigameResult")

local player = Players.LocalPlayer

local TOTAL_TIMEOUT  = 10    -- seconds for both tasks combined
local SPOT_FADE_TIME = 2.5   -- seconds before each spot disappears
local SPOT_COUNT     = 4
local TRACK_WIDTH    = 300
local HANDLE_SIZE    = 32

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
    sg.ResetOnSpawn   = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent         = player:WaitForChild("PlayerGui")

    local bg = Instance.new("Frame")
    bg.Size                   = UDim2.new(0, 420, 0, 480)
    bg.Position               = UDim2.new(0.5, -210, 0.5, -240)
    bg.BackgroundColor3       = Color3.fromRGB(20, 20, 20)
    bg.BackgroundTransparency = 0.1
    bg.BorderSizePixel        = 0
    bg.Parent                 = sg
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 16)

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size                   = UDim2.new(1, 0, 0, 40)
    titleLbl.BackgroundTransparency = 1
    titleLbl.TextColor3             = Color3.fromRGB(255, 255, 255)
    titleLbl.TextScaled             = true
    titleLbl.Font                   = Enum.Font.GothamBold
    titleLbl.Text                   = "DOUGH — Knead it!"
    titleLbl.Parent                 = bg

    -- Timer bar
    local timerBar = Instance.new("Frame")
    timerBar.Size             = UDim2.new(1, -20, 0, 8)
    timerBar.Position         = UDim2.new(0, 10, 1, -20)
    timerBar.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    timerBar.BorderSizePixel  = 0
    timerBar.Parent           = bg
    local timerFill = Instance.new("Frame")
    timerFill.Size             = UDim2.new(1, 0, 1, 0)
    timerFill.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
    timerFill.BorderSizePixel  = 0
    timerFill.Parent           = timerBar
    Instance.new("UICorner", timerFill).CornerRadius = UDim.new(0, 4)

    -- SLIDER
    local sliderLabel = Instance.new("TextLabel")
    sliderLabel.Size                   = UDim2.new(1, 0, 0, 28)
    sliderLabel.Position               = UDim2.new(0, 0, 0, 48)
    sliderLabel.BackgroundTransparency = 1
    sliderLabel.TextColor3             = Color3.fromRGB(200, 200, 200)
    sliderLabel.TextScaled             = true
    sliderLabel.Font                   = Enum.Font.Gotham
    sliderLabel.Text                   = "Drag handle into the green zone, then release"
    sliderLabel.Parent                 = bg

    local track = Instance.new("Frame")
    track.Size             = UDim2.new(0, TRACK_WIDTH, 0, 24)
    track.Position         = UDim2.new(0.5, -TRACK_WIDTH / 2, 0, 84)
    track.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    track.BorderSizePixel  = 0
    track.ClipsDescendants = false
    track.Parent           = bg
    Instance.new("UICorner", track).CornerRadius = UDim.new(0, 6)

    local zoneStartFrac = math.random(20, 60) / 100
    local zoneWidthFrac = 0.20
    local zoneFrame = Instance.new("Frame")
    zoneFrame.Size             = UDim2.new(zoneWidthFrac, 0, 1, 0)
    zoneFrame.Position         = UDim2.new(zoneStartFrac, 0, 0, 0)
    zoneFrame.BackgroundColor3 = Color3.fromRGB(80, 200, 80)
    zoneFrame.BorderSizePixel  = 0
    zoneFrame.Parent           = track
    Instance.new("UICorner", zoneFrame).CornerRadius = UDim.new(0, 6)

    local handle = Instance.new("TextButton")
    handle.Size             = UDim2.new(0, HANDLE_SIZE, 1, 10)
    handle.Position         = UDim2.new(0, -HANDLE_SIZE / 2, 0, -5)
    handle.BackgroundColor3 = Color3.fromRGB(220, 180, 80)
    handle.TextColor3       = Color3.fromRGB(30, 30, 30)
    handle.TextScaled       = true
    handle.Font             = Enum.Font.GothamBold
    handle.Text             = "||"
    handle.BorderSizePixel  = 0
    handle.ZIndex           = 2
    handle.Parent           = track
    Instance.new("UICorner", handle).CornerRadius = UDim.new(0, 6)

    -- SPOT TAP AREA
    local tapLabel = Instance.new("TextLabel")
    tapLabel.Size                   = UDim2.new(1, 0, 0, 28)
    tapLabel.Position               = UDim2.new(0, 0, 0, 130)
    tapLabel.BackgroundTransparency = 1
    tapLabel.TextColor3             = Color3.fromRGB(200, 200, 200)
    tapLabel.TextScaled             = true
    tapLabel.Font                   = Enum.Font.Gotham
    tapLabel.Text                   = "Tap the spots before they fade!"
    tapLabel.Parent                 = bg

    local tapArea = Instance.new("Frame")
    tapArea.Size             = UDim2.new(1, -20, 0, 260)
    tapArea.Position         = UDim2.new(0, 10, 0, 164)
    tapArea.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    tapArea.BorderSizePixel  = 0
    tapArea.ClipsDescendants = true
    tapArea.Parent           = bg
    Instance.new("UICorner", tapArea).CornerRadius = UDim.new(0, 8)

    -- STATE
    local sliderScore = 0
    local spotsHit    = 0
    local sliderDone  = false
    local isDragging  = false
    local handleFrac  = 0   -- 0..1 position along track
    local elapsed     = 0
    local finished    = false
    local inputConn   = nil

    local function finalize()
        if finished then return end
        finished = true
        if inputConn then inputConn:Disconnect() end
        local tapScore = math.floor(spotsHit / SPOT_COUNT * 50)
        humanoid.WalkSpeed = 16
        humanoid.JumpHeight = 7.2
        sg:Destroy()
        resultRemote:FireServer(sliderScore + tapScore)
    end

    handle.MouseButton1Down:Connect(function()
        isDragging = true
    end)

    inputConn = UserInputService.InputEnded:Connect(function(input)
        if finished then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 and isDragging then
            isDragging = false
            if not sliderDone then
                sliderDone = true
                local zoneCenter = zoneStartFrac + zoneWidthFrac / 2
                local dist       = math.abs(handleFrac - zoneCenter)
                local halfZone   = zoneWidthFrac / 2
                if handleFrac >= zoneStartFrac and handleFrac <= zoneStartFrac + zoneWidthFrac then
                    sliderScore = 50
                elseif dist < halfZone + 0.12 then
                    sliderScore = math.floor(50 * math.max(0, 1 - (dist - halfZone) / 0.12))
                else
                    sliderScore = 0
                end
                handle.BackgroundColor3 = sliderScore >= 25
                    and Color3.fromRGB(80, 200, 80)
                    or  Color3.fromRGB(200, 80, 80)
            end
        end
    end)

    for i = 1, SPOT_COUNT do
        task.delay(i * 0.15, function()
            if finished then return end
            local spot = Instance.new("TextButton")
            spot.Size             = UDim2.new(0, 52, 0, 52)
            spot.Position         = UDim2.new(0, math.random(10, 320), 0, math.random(10, 195))
            spot.BackgroundColor3 = Color3.fromRGB(255, 160, 40)
            spot.TextColor3       = Color3.fromRGB(255, 255, 255)
            spot.TextScaled       = true
            spot.Font             = Enum.Font.GothamBold
            spot.Text             = "!"
            spot.BorderSizePixel  = 0
            spot.ZIndex           = 3
            spot.Parent           = tapArea
            Instance.new("UICorner", spot).CornerRadius = UDim.new(1, 0)

            local spotHit = false
            spot.MouseButton1Click:Connect(function()
                if spotHit or finished then return end
                spotHit  = true
                spotsHit = spotsHit + 1
                spot:Destroy()
            end)

            local fadeElapsed = 0
            local fadeConn
            fadeConn = RunService.Heartbeat:Connect(function(dt)
                if not spot.Parent then fadeConn:Disconnect() return end
                fadeElapsed = fadeElapsed + dt
                spot.BackgroundTransparency = math.clamp(fadeElapsed / SPOT_FADE_TIME, 0, 1)
                if fadeElapsed >= SPOT_FADE_TIME then
                    fadeConn:Disconnect()
                    if spot.Parent then spot:Destroy() end
                end
            end)
        end)
    end

    local mainConn
    mainConn = RunService.Heartbeat:Connect(function(dt)
        if finished then mainConn:Disconnect() return end
        elapsed = elapsed + dt
        timerFill.Size = UDim2.new(math.clamp(1 - elapsed / TOTAL_TIMEOUT, 0, 1), 0, 1, 0)

        if isDragging then
            local mousePos = UserInputService:GetMouseLocation()
            local trackAbs = track.AbsolutePosition
            handleFrac     = math.clamp((mousePos.X - trackAbs.X) / TRACK_WIDTH, 0, 1)
            handle.Position = UDim2.new(handleFrac, -HANDLE_SIZE / 2, 0, -5)
        end

        if elapsed >= TOTAL_TIMEOUT then
            mainConn:Disconnect()
            finalize()
        end
    end)
end)

print("[DoughMinigame] Ready.")
