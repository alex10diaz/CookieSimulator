-- src/StarterPlayer/StarterPlayerScripts/Minigames/MixMinigame.client.lua
-- Redesigned: move cursor CLOCKWISE around ring to sweep through checkpoint dots (one at a time)

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")

local RemoteManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local startRemote   = RemoteManager.Get("StartMixMinigame")
local resultRemote  = RemoteManager.Get("MixMinigameResult")

local player = Players.LocalPlayer

local RING_RADIUS     = 120   -- px from ring center to checkpoint dots
local NUM_CHECKPOINTS = 6     -- total dots to sweep through
local TOTAL_TIME      = 15    -- seconds
local MIN_NEXT_DELTA  = 90    -- min CW degrees to next checkpoint
local MAX_NEXT_DELTA  = 270   -- max CW degrees to next checkpoint
local MAX_ANG_SPEED   = 200   -- degrees/sec cap on cursor rotation speed

-- Convert atan2 to 0–360 (0=right, increasing clockwise in screen space)
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
    sg.Name           = "MixGui"
    sg.ResetOnSpawn   = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent         = player:WaitForChild("PlayerGui")

    local bg = Instance.new("Frame")
    bg.Size                   = UDim2.new(0, 380, 0, 440)
    bg.Position               = UDim2.new(0.5, -190, 0.5, -220)
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
    titleLbl.Text                   = "MIX — Move clockwise!"
    titleLbl.Parent                 = bg

    local progressLbl = Instance.new("TextLabel")
    progressLbl.Size                   = UDim2.new(1, 0, 0, 28)
    progressLbl.Position               = UDim2.new(0, 0, 0, 40)
    progressLbl.BackgroundTransparency = 1
    progressLbl.TextColor3             = Color3.fromRGB(200, 200, 200)
    progressLbl.TextScaled             = true
    progressLbl.Font                   = Enum.Font.Gotham
    progressLbl.Text                   = "0 / " .. NUM_CHECKPOINTS
    progressLbl.Parent                 = bg

    -- 300×300 ring area (centered in panel)
    local ringFrame = Instance.new("Frame")
    ringFrame.Size             = UDim2.new(0, 300, 0, 300)
    ringFrame.Position         = UDim2.new(0.5, -150, 0, 72)
    ringFrame.BackgroundTransparency = 1
    ringFrame.BorderSizePixel  = 0
    ringFrame.ClipsDescendants = false
    ringFrame.Parent           = bg

    -- Outer ring fill
    local ringOuter = Instance.new("Frame")
    ringOuter.Size             = UDim2.new(1, 0, 1, 0)
    ringOuter.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    ringOuter.BorderSizePixel  = 0
    ringOuter.Parent           = ringFrame
    Instance.new("UICorner", ringOuter).CornerRadius = UDim.new(1, 0)

    -- Inner cutout (creates the donut ring shape)
    local ringInner = Instance.new("Frame")
    ringInner.Size             = UDim2.new(0, 190, 0, 190)
    ringInner.Position         = UDim2.new(0.5, -95, 0.5, -95)
    ringInner.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    ringInner.BorderSizePixel  = 0
    ringInner.ZIndex           = 2
    ringInner.Parent           = ringFrame
    Instance.new("UICorner", ringInner).CornerRadius = UDim.new(1, 0)

    -- Clockwise arrow label inside ring
    local arrowLbl = Instance.new("TextLabel")
    arrowLbl.Size                   = UDim2.new(1, -20, 1, -20)
    arrowLbl.Position               = UDim2.new(0, 10, 0, 10)
    arrowLbl.BackgroundTransparency = 1
    arrowLbl.TextColor3             = Color3.fromRGB(90, 90, 120)
    arrowLbl.TextScaled             = true
    arrowLbl.Font                   = Enum.Font.GothamBold
    arrowLbl.Text                   = "↻"
    arrowLbl.ZIndex                 = 3
    arrowLbl.Parent                 = ringInner

    -- Cursor indicator (snaps to ring surface at cursor angle)
    local cursorDot = Instance.new("Frame")
    cursorDot.Size                   = UDim2.new(0, 20, 0, 20)
    cursorDot.AnchorPoint            = Vector2.new(0.5, 0.5)
    cursorDot.BackgroundColor3       = Color3.fromRGB(255, 255, 255)
    cursorDot.BackgroundTransparency = 0.35
    cursorDot.BorderSizePixel        = 0
    cursorDot.ZIndex                 = 5
    cursorDot.Parent                 = ringFrame
    Instance.new("UICorner", cursorDot).CornerRadius = UDim.new(1, 0)

    -- Checkpoint dot
    local cpDot = Instance.new("Frame")
    cpDot.Size             = UDim2.new(0, 34, 0, 34)
    cpDot.AnchorPoint      = Vector2.new(0.5, 0.5)
    cpDot.BackgroundColor3 = Color3.fromRGB(255, 220, 0)
    cpDot.BorderSizePixel  = 0
    cpDot.ZIndex           = 4
    cpDot.Parent           = ringFrame
    Instance.new("UICorner", cpDot).CornerRadius = UDim.new(1, 0)

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

    -- STATE
    local numHit          = 0
    local elapsed         = 0
    local finished        = false
    local cursorAngle     = 0       -- speed-capped cursor position on ring
    local prevCursorAngle = nil
    local cpAngle         = math.random(0, 359)
    local hitFlash        = false  -- blocks re-trigger during flash delay
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
        humanoid.WalkSpeed = 16
        humanoid.JumpHeight = 7.2
        sg:Destroy()
        resultRemote:FireServer(math.floor(numHit / NUM_CHECKPOINTS * 100))
    end

    mainConn = RunService.Heartbeat:Connect(function(dt)
        elapsed = elapsed + dt
        timerFill.Size = UDim2.new(math.clamp(1 - elapsed / TOTAL_TIME, 0, 1), 0, 1, 0)
        if elapsed >= TOTAL_TIME then finish() return end

        -- Raw target angle from mouse
        local mousePos  = UserInputService:GetMouseLocation()
        local abs       = ringFrame.AbsolutePosition
        local absSize   = ringFrame.AbsoluteSize
        local cx        = abs.X + absSize.X * 0.5
        local cy        = abs.Y + absSize.Y * 0.5
        local targetAngle = toAngle360(mousePos.X - cx, mousePos.Y - cy)

        -- Advance cursor toward target capped at MAX_ANG_SPEED (shortest path)
        local maxStep  = MAX_ANG_SPEED * dt
        local rawDelta = (targetAngle - cursorAngle + 360) % 360
        if rawDelta > 180 then rawDelta = rawDelta - 360 end
        cursorAngle = (cursorAngle + math.clamp(rawDelta, -maxStep, maxStep) + 360) % 360

        -- Move cursor dot to ring surface
        local crad = math.rad(cursorAngle)
        cursorDot.Position = UDim2.new(
            0, 150 + math.cos(crad) * RING_RADIUS,
            0, 150 + math.sin(crad) * RING_RADIUS
        )

        -- Clockwise sweep detection (uses damped cursorAngle)
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
