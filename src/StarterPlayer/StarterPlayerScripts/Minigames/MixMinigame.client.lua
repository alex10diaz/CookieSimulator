-- MixMinigame.client.lua (redesigned + speed cap + M7 polish)
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local SoundService      = game:GetService("SoundService")

local MIXER_SOUND_ID = "rbxassetid://9125678301"
local function stopMixerLoop()
    for _, snd in ipairs(SoundService:GetDescendants()) do
        if snd:IsA("Sound") and snd.SoundId == MIXER_SOUND_ID and snd.IsPlaying then
            snd:Stop()
        end
    end
end

local RemoteManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local startRemote   = RemoteManager.Get("StartMixMinigame")
local resultRemote  = RemoteManager.Get("MixMinigameResult")
local cancelRemote  = RemoteManager.Get("CancelMinigame")
local EffectsModule
task.spawn(function() local ok,m = pcall(require, ReplicatedStorage:WaitForChild("Modules"):WaitForChild("EffectsModule")); if ok then EffectsModule = m end end)

local player = Players.LocalPlayer

local RING_RADIUS     = 120
local NUM_CHECKPOINTS = 6
local TOTAL_TIME      = 15
local MIN_NEXT_DELTA  = 90
local MAX_NEXT_DELTA  = 270
local MAX_ANG_SPEED   = 200   -- degrees/sec cap on cursor rotation

local ACCENT = Color3.fromRGB(255, 200, 0)  -- gold

local function toAngle360(dx, dy)
    return (math.deg(math.atan2(dy, dx)) + 360) % 360
end

startRemote.OnClientEvent:Connect(function(settings, label)
    if player:WaitForChild("PlayerGui"):FindFirstChild("MixGui") then return end
    local char = player.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    humanoid.WalkSpeed = 0
    humanoid.JumpHeight = 0

    local sg = Instance.new("ScreenGui")
    sg.Name = "MixGui"
    sg.ResetOnSpawn          = false
    sg.ZIndexBehavior        = Enum.ZIndexBehavior.Sibling
    sg.DisplayOrder          = 22
    sg.SafeAreaCompatibility = Enum.SafeAreaCompatibility.FullscreenExtension  -- m9
    sg.Parent                = player:WaitForChild("PlayerGui")

    local bg = Instance.new("Frame")
    local _fw = math.min(380, workspace.CurrentCamera.ViewportSize.X - 20)
    bg.Size = UDim2.new(0, _fw, 0, 440)
    bg.Position = UDim2.new(0.5, -_fw/2, 0.5, -220)
    bg.BackgroundColor3 = Color3.fromRGB(15, 30, 60)
    bg.BackgroundTransparency = 0
    bg.BorderSizePixel = 0
    bg.Parent = sg
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 16)
    local bgStroke = Instance.new("UIStroke", bg)
    bgStroke.Color = ACCENT
    bgStroke.Thickness = 1.5

    -- Gold header bar
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
    titleLbl.Size = UDim2.new(1, -14, 1, 0)
    titleLbl.Position = UDim2.new(0, 14, 0, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.TextColor3 = Color3.fromRGB(20, 14, 4)
    titleLbl.TextScaled = true
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.Text = "MIX  — Move clockwise!"
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = headerBar

    local progressLbl = Instance.new("TextLabel")
    progressLbl.Size = UDim2.new(1, 0, 0, 26)
    progressLbl.Position = UDim2.new(0, 0, 0, 48)
    progressLbl.BackgroundTransparency = 1
    progressLbl.TextColor3 = Color3.fromRGB(180, 185, 220)
    progressLbl.TextScaled = true
    progressLbl.Font = Enum.Font.Gotham
    progressLbl.Text = "0 / " .. NUM_CHECKPOINTS
    progressLbl.Parent = bg

    local ringFrame = Instance.new("Frame")
    ringFrame.Size = UDim2.new(0, 300, 0, 300)
    ringFrame.Position = UDim2.new(0.5, -150, 0, 78)
    ringFrame.BackgroundTransparency = 1
    ringFrame.BorderSizePixel = 0
    ringFrame.ClipsDescendants = false
    ringFrame.Parent = bg

    local ringOuter = Instance.new("Frame")
    ringOuter.Size = UDim2.new(1, 0, 1, 0)
    ringOuter.BackgroundColor3 = Color3.fromRGB(22, 22, 42)
    ringOuter.BorderSizePixel = 0
    ringOuter.Parent = ringFrame
    Instance.new("UICorner", ringOuter).CornerRadius = UDim.new(1, 0)
    local ringStroke = Instance.new("UIStroke", ringOuter)
    ringStroke.Color = Color3.fromRGB(50, 50, 90)
    ringStroke.Thickness = 1

    local ringInner = Instance.new("Frame")
    ringInner.Size = UDim2.new(0, 190, 0, 190)
    ringInner.Position = UDim2.new(0.5, -95, 0.5, -95)
    ringInner.BackgroundColor3 = Color3.fromRGB(15, 30, 60)
    ringInner.BorderSizePixel = 0
    ringInner.ZIndex = 2
    ringInner.Parent = ringFrame
    Instance.new("UICorner", ringInner).CornerRadius = UDim.new(1, 0)
    local innerStroke = Instance.new("UIStroke", ringInner)
    innerStroke.Color = Color3.fromRGB(40, 40, 70)
    innerStroke.Thickness = 1

    local arrowLbl = Instance.new("TextLabel")
    arrowLbl.Size = UDim2.new(1, -20, 1, -20)
    arrowLbl.Position = UDim2.new(0, 10, 0, 10)
    arrowLbl.BackgroundTransparency = 1
    arrowLbl.TextColor3 = Color3.fromRGB(55, 55, 95)
    arrowLbl.TextScaled = true
    arrowLbl.Font = Enum.Font.GothamBold
    arrowLbl.Text = "CW"
    arrowLbl.ZIndex = 3
    arrowLbl.Parent = ringInner

    local cursorDot = Instance.new("Frame")
    cursorDot.Size = UDim2.new(0, 20, 0, 20)
    cursorDot.AnchorPoint = Vector2.new(0.5, 0.5)
    cursorDot.BackgroundColor3 = Color3.fromRGB(255, 220, 0)
    cursorDot.BackgroundTransparency = 0
    cursorDot.BorderSizePixel = 0
    cursorDot.ZIndex = 5
    cursorDot.Parent = ringFrame
    Instance.new("UICorner", cursorDot).CornerRadius = UDim.new(1, 0)

    local cpDot = Instance.new("Frame")
    cpDot.Size = UDim2.new(0, 34, 0, 34)
    cpDot.AnchorPoint = Vector2.new(0.5, 0.5)
    cpDot.BackgroundColor3 = Color3.fromRGB(255, 220, 0)
    cpDot.BorderSizePixel = 0
    cpDot.ZIndex = 4
    cpDot.Parent = ringFrame
    Instance.new("UICorner", cpDot).CornerRadius = UDim.new(1, 0)

    local timerBar = Instance.new("Frame")
    timerBar.Size = UDim2.new(1, -20, 0, 8)
    timerBar.Position = UDim2.new(0, 10, 1, -20)
    timerBar.BackgroundColor3 = Color3.fromRGB(25, 25, 45)
    timerBar.BorderSizePixel = 0
    timerBar.Parent = bg
    Instance.new("UICorner", timerBar).CornerRadius = UDim.new(0, 4)
    local timerFill = Instance.new("Frame")
    timerFill.Size = UDim2.new(1, 0, 1, 0)
    timerFill.BackgroundColor3 = ACCENT
    timerFill.BorderSizePixel = 0
    timerFill.Parent = timerBar
    Instance.new("UICorner", timerFill).CornerRadius = UDim.new(0, 4)

    local numHit      = 0
    local elapsed     = 0
    local finished    = false
    local cursorAngle = 0
    local prevCursorAngle = nil
    local cpAngle     = math.random(0, 359)
    local hitFlash    = false
    local mainConn

    local function placeCpDot()
        local rad = math.rad(cpAngle)
        cpDot.Position = UDim2.new(
            0, 150 + math.cos(rad) * RING_RADIUS,
            0, 150 + math.sin(rad) * RING_RADIUS
        )
        cpDot.BackgroundColor3 = Color3.fromRGB(255, 220, 0)
        hitFlash = false
    end
    placeCpDot()

    local function finish()
        if finished then return end
        finished = true
        if mainConn then mainConn:Disconnect() end
        stopMixerLoop()
        humanoid.WalkSpeed = 16
        humanoid.JumpHeight = 7.2
        sg:Destroy()
        resultRemote:FireServer(math.floor(numHit / NUM_CHECKPOINTS * 100))
        do local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart"); if hrp then EffectsModule.Flour(hrp.Position) end end
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
            if mainConn then mainConn:Disconnect() end
            stopMixerLoop()
            humanoid.WalkSpeed  = 16
            humanoid.JumpHeight = 7.2
            sg:Destroy()
            cancelRemote:FireServer()
        end)
    end

    mainConn = RunService.Heartbeat:Connect(function(dt)
        elapsed = elapsed + dt
        timerFill.Size = UDim2.new(math.clamp(1 - elapsed / TOTAL_TIME, 0, 1), 0, 1, 0)
        if elapsed >= TOTAL_TIME then finish() return end

        local mousePos    = UserInputService:GetMouseLocation()
        local abs         = ringFrame.AbsolutePosition
        local absSize     = ringFrame.AbsoluteSize
        local cx          = abs.X + absSize.X * 0.5
        local cy          = abs.Y + absSize.Y * 0.5
        local targetAngle = toAngle360(mousePos.X - cx, mousePos.Y - cy)

        -- Advance cursor toward target at MAX_ANG_SPEED (shortest path)
        local maxStep  = MAX_ANG_SPEED * dt
        local rawDelta = (targetAngle - cursorAngle + 360) % 360
        if rawDelta > 180 then rawDelta = rawDelta - 360 end
        cursorAngle = (cursorAngle + math.clamp(rawDelta, -maxStep, maxStep) + 360) % 360

        local crad = math.rad(cursorAngle)
        cursorDot.Position = UDim2.new(
            0, 150 + math.cos(crad) * RING_RADIUS,
            0, 150 + math.sin(crad) * RING_RADIUS
        )

        if prevCursorAngle and not hitFlash then
            local cwDelta = (cursorAngle - prevCursorAngle + 360) % 360
            if cwDelta > 0 and cwDelta <= 180 then
                local angToCP = (cpAngle - prevCursorAngle + 360) % 360
                if angToCP < cwDelta then
                    hitFlash = true
                    numHit   = numHit + 1
                    progressLbl.Text = numHit .. " / " .. NUM_CHECKPOINTS
                    cpDot.BackgroundColor3 = Color3.fromRGB(80, 200, 80)
                    if numHit >= NUM_CHECKPOINTS then
                        task.delay(0.3, finish)
                    else
                        cpAngle = (cpAngle + math.random(MIN_NEXT_DELTA, MAX_NEXT_DELTA)) % 360
                        task.delay(0.25, placeCpDot)
                    end
                end
            end
        end

        prevCursorAngle = cursorAngle
    end)
end)

print("[MixMinigame] Ready.")
