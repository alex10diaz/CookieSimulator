-- src/StarterPlayer/StarterPlayerScripts/Minigames/OvenMinigame.client.lua
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local RemoteManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local startRemote   = RemoteManager.Get("StartOvenMinigame")
local resultRemote  = RemoteManager.Get("OvenMinigameResult")

local player = Players.LocalPlayer

local FILL_TIME      = 6     -- seconds for bar to fill completely
local BAR_HEIGHT     = 260   -- px
local ZONE_HEIGHT_PX = 56    -- px (~21.5% of bar)
local ZONE_MIN       = 0.25  -- zone center drifts within this range (fraction from bottom)
local ZONE_MAX       = 0.75
local BURN_SCORE     = 10    -- score if bar fills completely (burned)

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
    sg.ResetOnSpawn   = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent         = player:WaitForChild("PlayerGui")

    local bg = Instance.new("Frame")
    bg.Size                   = UDim2.new(0, 300, 0, 420)
    bg.Position               = UDim2.new(0.5, -150, 0.5, -210)
    bg.BackgroundColor3       = Color3.fromRGB(20, 20, 20)
    bg.BackgroundTransparency = 0.1
    bg.BorderSizePixel        = 0
    bg.Parent                 = sg
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 16)

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size                   = UDim2.new(1, 0, 0, 44)
    titleLbl.BackgroundTransparency = 1
    titleLbl.TextColor3             = Color3.fromRGB(255, 255, 255)
    titleLbl.TextScaled             = true
    titleLbl.TextWrapped            = true
    titleLbl.Font                   = Enum.Font.GothamBold
    titleLbl.Text                   = "OVEN — Stop at the right temp!"
    titleLbl.Parent                 = bg

    -- Vertical bar track
    local barTrack = Instance.new("Frame")
    barTrack.Size             = UDim2.new(0, 60, 0, BAR_HEIGHT)
    barTrack.Position         = UDim2.new(0.5, -30, 0, 50)
    barTrack.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    barTrack.BorderSizePixel  = 0
    barTrack.ClipsDescendants = false
    barTrack.Parent           = bg
    Instance.new("UICorner", barTrack).CornerRadius = UDim.new(0, 8)

    -- Fill (anchored at bottom, grows upward)
    local fillFrame = Instance.new("Frame")
    fillFrame.Size             = UDim2.new(1, 0, 0, 0)
    fillFrame.AnchorPoint      = Vector2.new(0, 1)
    fillFrame.Position         = UDim2.new(0, 0, 1, 0)
    fillFrame.BackgroundColor3 = Color3.fromRGB(220, 120, 30)
    fillFrame.BorderSizePixel  = 0
    fillFrame.Parent           = barTrack
    Instance.new("UICorner", fillFrame).CornerRadius = UDim.new(0, 8)

    -- Green zone (drifts, rendered in barTrack space)
    local zoneCenter = (ZONE_MIN + ZONE_MAX) / 2
    local zoneFrame  = Instance.new("Frame")
    zoneFrame.Size             = UDim2.new(1, 6, 0, ZONE_HEIGHT_PX)
    zoneFrame.BackgroundColor3 = Color3.fromRGB(80, 200, 80)
    zoneFrame.BackgroundTransparency = 0.3
    zoneFrame.BorderSizePixel  = 0
    zoneFrame.ZIndex           = 2
    zoneFrame.AnchorPoint      = Vector2.new(0.5, 0.5)
    zoneFrame.Position         = UDim2.new(0.5, 0, 1 - zoneCenter, 0)
    zoneFrame.Parent           = barTrack
    Instance.new("UICorner", zoneFrame).CornerRadius = UDim.new(0, 4)

    -- HOT / COLD labels
    local function sideLabel(text, yPos, col)
        local lbl = Instance.new("TextLabel")
        lbl.Size                   = UDim2.new(0, 55, 0, 24)
        lbl.Position               = UDim2.new(0.5, 38, 0, yPos)
        lbl.BackgroundTransparency = 1
        lbl.TextColor3             = col
        lbl.TextScaled             = true
        lbl.Font                   = Enum.Font.GothamBold
        lbl.Text                   = text
        lbl.Parent                 = bg
    end
    sideLabel("HOT",  50,  Color3.fromRGB(255, 100, 50))
    sideLabel("COLD", 310, Color3.fromRGB(100, 180, 255))

    -- STOP button
    local stopBtn = Instance.new("TextButton")
    stopBtn.Size             = UDim2.new(0.6, 0, 0, 50)
    stopBtn.Position         = UDim2.new(0.2, 0, 1, -70)
    stopBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
    stopBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
    stopBtn.TextScaled       = true
    stopBtn.Font             = Enum.Font.GothamBold
    stopBtn.Text             = "STOP"
    stopBtn.BorderSizePixel  = 0
    stopBtn.Parent           = bg
    Instance.new("UICorner", stopBtn).CornerRadius = UDim.new(0, 10)

    local function calcScore(fillFrac)
        local halfZone = (ZONE_HEIGHT_PX / 2) / BAR_HEIGHT
        local dist     = math.abs(fillFrac - zoneCenter)
        if dist <= halfZone then
            return math.floor(70 + 30 * (1 - dist / halfZone))
        elseif dist <= halfZone + 0.10 then
            return math.floor(40 + 30 * (1 - (dist - halfZone) / 0.10))
        else
            return math.floor(math.max(0, 39 * (1 - dist)))
        end
    end

    local elapsed  = 0
    local stopped  = false
    local mainConn

    local function finish(score)
        if mainConn then mainConn:Disconnect() end
        humanoid.WalkSpeed = 16
        humanoid.JumpHeight = 7.2
        sg:Destroy()
        resultRemote:FireServer(math.clamp(score, 0, 100))
    end

    local stopConn
    stopConn = stopBtn.MouseButton1Click:Connect(function()
        if stopped then return end
        stopped = true
        if stopConn then stopConn:Disconnect() end
        finish(calcScore(math.clamp(elapsed / FILL_TIME, 0, 1)))
    end)

    mainConn = RunService.Heartbeat:Connect(function(dt)
        elapsed = elapsed + dt
        local frac = math.clamp(elapsed / FILL_TIME, 0, 1)

        -- Grow fill from bottom
        fillFrame.Size = UDim2.new(1, 0, frac, 0)

        -- Drift zone via sin wave
        local drift  = math.sin(elapsed * 0.8) * 0.18
        zoneCenter   = math.clamp((ZONE_MIN + ZONE_MAX) / 2 + drift, ZONE_MIN, ZONE_MAX)
        zoneFrame.Position = UDim2.new(0.5, 0, 1 - zoneCenter, 0)

        if frac >= 1 and not stopped then
            stopped = true
            finish(BURN_SCORE)
        end
    end)
end)

print("[OvenMinigame] Ready.")
