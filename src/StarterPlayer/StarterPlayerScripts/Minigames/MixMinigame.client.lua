-- src/StarterPlayer/StarterPlayerScripts/Minigames/MixMinigame.client.lua
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local RemoteManager  = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local startRemote    = RemoteManager.Get("StartMixMinigame")
local resultRemote   = RemoteManager.Get("MixMinigameResult")

local player = Players.LocalPlayer

-- deg/s for each of the 3 rounds
local ROUND_SPEEDS  = {120, 168, 216}
local HIT_THRESHOLD = 22   -- degrees tolerance
local ROUND_TIMEOUT = 4    -- seconds per round
local TOTAL_ROUNDS  = 3
local RING_RADIUS   = 110  -- px from center to marker
local GREEN_ANGLE   = 90   -- degrees; 90 = right side (3 o'clock) in Roblox screen coords

startRemote.OnClientEvent:Connect(function()
    -- Lock movement
    local char = player.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    humanoid.WalkSpeed = 0
    humanoid.JumpPower = 0

    -- Build GUI
    local sg = Instance.new("ScreenGui")
    sg.Name            = "MixGui"
    sg.ResetOnSpawn    = false
    sg.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
    sg.Parent          = player:WaitForChild("PlayerGui")

    local bg = Instance.new("Frame")
    bg.Size                    = UDim2.new(0, 440, 0, 440)
    bg.Position                = UDim2.new(0.5, -220, 0.5, -220)
    bg.BackgroundColor3        = Color3.fromRGB(20, 20, 20)
    bg.BackgroundTransparency  = 0.1
    bg.BorderSizePixel         = 0
    bg.Parent                  = sg
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 16)

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size                  = UDim2.new(1, 0, 0, 40)
    titleLbl.BackgroundTransparency = 1
    titleLbl.TextColor3            = Color3.fromRGB(255, 255, 255)
    titleLbl.TextScaled            = true
    titleLbl.Font                  = Enum.Font.GothamBold
    titleLbl.Text                  = "MIX — Round 1/" .. TOTAL_ROUNDS
    titleLbl.Parent                = bg

    -- Green hit zone (fixed at top of ring: angle=0 in our convention)
    local greenZone = Instance.new("Frame")
    greenZone.Size             = UDim2.new(0, 34, 0, 34)
    greenZone.Position         = UDim2.new(0.5, -17, 0.5, -17 - RING_RADIUS)
    greenZone.BackgroundColor3 = Color3.fromRGB(80, 200, 80)
    greenZone.BorderSizePixel  = 0
    greenZone.Parent           = bg
    Instance.new("UICorner", greenZone).CornerRadius = UDim.new(1, 0)

    -- Orbiting marker
    local marker = Instance.new("Frame")
    marker.Size             = UDim2.new(0, 22, 0, 22)
    marker.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    marker.BorderSizePixel  = 0
    marker.Parent           = bg
    Instance.new("UICorner", marker).CornerRadius = UDim.new(1, 0)

    -- HIT button
    local hitBtn = Instance.new("TextButton")
    hitBtn.Size             = UDim2.new(0, 110, 0, 54)
    hitBtn.Position         = UDim2.new(0.5, -55, 0.5, -27)
    hitBtn.BackgroundColor3 = Color3.fromRGB(80, 180, 100)
    hitBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
    hitBtn.TextScaled       = true
    hitBtn.Font             = Enum.Font.GothamBold
    hitBtn.Text             = "HIT!"
    hitBtn.BorderSizePixel  = 0
    hitBtn.Parent           = bg
    Instance.new("UICorner", hitBtn).CornerRadius = UDim.new(0, 10)

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

    -- State
    local hits         = 0
    local markerAngle  = 0
    local currentRound = 0
    local roundActive  = false
    local roundConn, hitConn

    local function cleanup()
        if roundConn then roundConn:Disconnect() end
        if hitConn   then hitConn:Disconnect()   end
        humanoid.WalkSpeed = 16
        humanoid.JumpPower = 7.2
        sg:Destroy()
        resultRemote:FireServer(math.min(hits * 34, 100))
    end

    local function startRound(roundNum)
        if roundNum > TOTAL_ROUNDS then
            cleanup()
            return
        end
        currentRound = roundNum
        titleLbl.Text = "MIX — Round " .. roundNum .. "/" .. TOTAL_ROUNDS
        markerAngle   = 0
        roundActive   = true
        local speed   = ROUND_SPEEDS[roundNum]
        local elapsed = 0

        if roundConn then roundConn:Disconnect() end
        roundConn = RunService.Heartbeat:Connect(function(dt)
            if not roundActive then return end
            elapsed = elapsed + dt
            timerFill.Size = UDim2.new(math.clamp(1 - elapsed / ROUND_TIMEOUT, 0, 1), 0, 1, 0)

            -- Advance marker angle
            markerAngle = (markerAngle + speed * dt) % 360
            -- angle=0 maps to top: subtract 90° so 0 = up
            local rad = math.rad(markerAngle - 90)
            local mx  = math.cos(rad) * RING_RADIUS
            local my  = math.sin(rad) * RING_RADIUS
            marker.Position = UDim2.new(0.5, mx - 11, 0.5, my - 11)

            if elapsed >= ROUND_TIMEOUT then
                roundActive = false
                roundConn:Disconnect()
                task.delay(0.3, function() startRound(currentRound + 1) end)
            end
        end)

        if hitConn then hitConn:Disconnect() end
        hitConn = hitBtn.MouseButton1Click:Connect(function()
            if not roundActive then return end
            roundActive = false
            roundConn:Disconnect()
            hitConn:Disconnect()

            -- Check if marker is within threshold of green zone (top = 0 degrees)
            local diff = math.abs(((markerAngle - 0 + 180) % 360) - 180)
            if diff <= HIT_THRESHOLD then
                hits = hits + 1
                hitBtn.BackgroundColor3 = Color3.fromRGB(255, 230, 0)
            else
                hitBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
            end
            task.delay(0.4, function()
                hitBtn.BackgroundColor3 = Color3.fromRGB(80, 180, 100)
                startRound(currentRound + 1)
            end)
        end)
    end

    startRound(1)
end)

print("[MixMinigame] Ready.")
