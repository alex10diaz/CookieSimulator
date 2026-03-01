-- src/StarterPlayer/StarterPlayerScripts/Minigames/FrostMinigame.client.lua
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local RemoteManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local startRemote   = RemoteManager.Get("StartFrostMinigame")
local resultRemote  = RemoteManager.Get("FrostMinigameResult")

local player = Players.LocalPlayer

local TIMER           = 10
local NUM_CHECKPOINTS = 8

local CHECKPOINT_OFFSETS = {
    Vector2.new(  0, -150),
    Vector2.new(120,  -90),
    Vector2.new(150,   40),
    Vector2.new( 60,  140),
    Vector2.new(-80,  130),
    Vector2.new(-140,  20),
    Vector2.new(-80,  -70),
    Vector2.new(  0,    0),
}

startRemote.OnClientEvent:Connect(function()
    if player:WaitForChild("PlayerGui"):FindFirstChild("FrostGui") then return end
    local char = player.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    humanoid.WalkSpeed = 0
    humanoid.JumpHeight = 0

    local sg = Instance.new("ScreenGui")
    sg.Name           = "FrostGui"
    sg.ResetOnSpawn   = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent         = player:WaitForChild("PlayerGui")

    local bg = Instance.new("Frame")
    bg.Size                   = UDim2.new(0, 420, 0, 460)
    bg.Position               = UDim2.new(0.5, -210, 0.5, -230)
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
    titleLbl.Text                   = "FROST — Click dots 1 to 8!"
    titleLbl.Parent                 = bg

    local timerBar = Instance.new("Frame")
    timerBar.Size             = UDim2.new(1, -20, 0, 8)
    timerBar.Position         = UDim2.new(0, 10, 1, -20)
    timerBar.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    timerBar.BorderSizePixel  = 0
    timerBar.Parent           = bg
    local timerFill = Instance.new("Frame")
    timerFill.Size             = UDim2.new(1, 0, 1, 0)
    timerFill.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
    timerFill.BorderSizePixel  = 0
    timerFill.Parent           = timerBar
    Instance.new("UICorner", timerFill).CornerRadius = UDim.new(0, 4)

    local playArea = Instance.new("Frame")
    playArea.Size             = UDim2.new(0, 360, 0, 360)
    playArea.Position         = UDim2.new(0.5, -180, 0, 50)
    playArea.BackgroundColor3 = Color3.fromRGB(35, 35, 60)
    playArea.BorderSizePixel  = 0
    playArea.ClipsDescendants = false
    playArea.Parent           = bg
    Instance.new("UICorner", playArea).CornerRadius = UDim.new(0, 8)

    local AREA_CENTER = Vector2.new(180, 180)

    local activeIndex = 1
    local numHit      = 0
    local elapsed     = 0
    local finished    = false
    local mainConn

    local function finish()
        if finished then return end
        finished = true
        if mainConn then mainConn:Disconnect() end
        humanoid.WalkSpeed = 16
        humanoid.JumpHeight = 7.2
        sg:Destroy()
        resultRemote:FireServer(math.floor(numHit / NUM_CHECKPOINTS * 100))
    end

    local dots = {}
    for i, offset in ipairs(CHECKPOINT_OFFSETS) do
        local dot = Instance.new("TextButton")
        dot.Size        = UDim2.new(0, 48, 0, 48)
        dot.AnchorPoint = Vector2.new(0.5, 0.5)
        dot.Position    = UDim2.new(0, AREA_CENTER.X + offset.X,
                                     0, AREA_CENTER.Y + offset.Y)
        dot.BackgroundColor3 = i == 1
            and Color3.fromRGB(255, 220, 0)
            or  Color3.fromRGB(100, 100, 180)
        dot.TextColor3  = Color3.fromRGB(20, 20, 20)
        dot.TextScaled  = true
        dot.Font        = Enum.Font.GothamBold
        dot.Text        = tostring(i)
        dot.BorderSizePixel = 0
        dot.ZIndex      = 3
        dot.AutoButtonColor = false
        dot.Parent      = playArea
        Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
        dots[i] = dot

        local idx = i
        dot.MouseButton1Click:Connect(function()
            if finished then return end
            if idx ~= activeIndex then return end  -- must click in order
            numHit = numHit + 1
            dot.BackgroundColor3 = Color3.fromRGB(80, 200, 80)
            activeIndex = activeIndex + 1
            if activeIndex <= NUM_CHECKPOINTS then
                dots[activeIndex].BackgroundColor3 = Color3.fromRGB(255, 220, 0)
            else
                task.delay(0.3, finish)
            end
        end)
    end

    mainConn = RunService.Heartbeat:Connect(function(dt)
        elapsed = elapsed + dt
        timerFill.Size = UDim2.new(math.clamp(1 - elapsed / TIMER, 0, 1), 0, 1, 0)
        if elapsed >= TIMER then finish() end
    end)
end)

print("[FrostMinigame] Ready.")
