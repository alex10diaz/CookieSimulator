-- src/StarterPlayer/StarterPlayerScripts/Minigames/DressMinigame.client.lua
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local RemoteManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local startRemote   = RemoteManager.Get("StartDressMinigame")
local resultRemote  = RemoteManager.Get("DressMinigameResult")

local player = Players.LocalPlayer

local TIMER    = 8
local REQUIRED = 4   -- correct cookies needed

local COOKIE_DISPLAY = {
    pink_sugar            = "Pink Sugar",
    chocolate_chip        = "Choc Chip",
    birthday_cake         = "Bday Cake",
    cookies_and_cream     = "C&C",
    snickerdoodle         = "Snickerdoodle",
    lemon_blackraspberry  = "Lemon Berry",
}

local ALL_IDS = {
    "pink_sugar", "chocolate_chip", "birthday_cake",
    "cookies_and_cream", "snickerdoodle", "lemon_blackraspberry",
}

startRemote.OnClientEvent:Connect(function(cookieId)
    if player.PlayerGui:FindFirstChild("DressGui") then return end
    local char = player.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    humanoid.WalkSpeed = 0
    humanoid.JumpHeight = 0

    local cookieName = COOKIE_DISPLAY[cookieId] or cookieId

    local sg = Instance.new("ScreenGui")
    sg.Name           = "DressGui"
    sg.ResetOnSpawn   = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent         = player.PlayerGui

    local bg = Instance.new("Frame")
    bg.Size                   = UDim2.new(0, 440, 0, 460)
    bg.Position               = UDim2.new(0.5, -220, 0.5, -230)
    bg.BackgroundColor3       = Color3.fromRGB(20, 20, 20)
    bg.BackgroundTransparency = 0.1
    bg.BorderSizePixel        = 0
    bg.Parent                 = sg
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 16)

    -- Order ticket
    local orderLbl = Instance.new("TextLabel")
    orderLbl.Size             = UDim2.new(1, -20, 0, 56)
    orderLbl.Position         = UDim2.new(0, 10, 0, 10)
    orderLbl.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
    orderLbl.TextColor3       = Color3.fromRGB(20, 20, 20)
    orderLbl.TextScaled       = true
    orderLbl.Font             = Enum.Font.GothamBold
    orderLbl.Text             = "Pack: " .. cookieName .. " x" .. REQUIRED
    orderLbl.BorderSizePixel  = 0
    orderLbl.Parent           = bg
    Instance.new("UICorner", orderLbl).CornerRadius = UDim.new(0, 8)

    local instrLbl = Instance.new("TextLabel")
    instrLbl.Size                   = UDim2.new(1, 0, 0, 26)
    instrLbl.Position               = UDim2.new(0, 0, 0, 72)
    instrLbl.BackgroundTransparency = 1
    instrLbl.TextColor3             = Color3.fromRGB(200, 200, 200)
    instrLbl.TextScaled             = true
    instrLbl.Font                   = Enum.Font.Gotham
    instrLbl.Text                   = "Click the correct cookies!"
    instrLbl.Parent                 = bg

    -- Build 6 buttons: 4 correct + 2 wrong, shuffled
    local wrongIds = {}
    for _, id in ipairs(ALL_IDS) do
        if id ~= cookieId then
            table.insert(wrongIds, id)
        end
    end
    -- Shuffle wrong list
    for i = #wrongIds, 2, -1 do
        local j = math.random(1, i)
        wrongIds[i], wrongIds[j] = wrongIds[j], wrongIds[i]
    end

    local buttonData = {}
    for _ = 1, REQUIRED do
        table.insert(buttonData, { id = cookieId, correct = true })
    end
    if wrongIds[1] then table.insert(buttonData, { id = wrongIds[1], correct = false }) end
    if wrongIds[2] then table.insert(buttonData, { id = wrongIds[2], correct = false }) end
    -- Shuffle button list
    for i = #buttonData, 2, -1 do
        local j = math.random(1, i)
        buttonData[i], buttonData[j] = buttonData[j], buttonData[i]
    end

    -- Slot dots showing progress
    local slotsFrame = Instance.new("Frame")
    slotsFrame.Size                   = UDim2.new(1, -20, 0, 24)
    slotsFrame.Position               = UDim2.new(0, 10, 0, 100)
    slotsFrame.BackgroundTransparency = 1
    slotsFrame.Parent                 = bg
    local slotDots = {}
    for i = 1, REQUIRED do
        local slot = Instance.new("Frame")
        slot.Size             = UDim2.new(0, 20, 0, 20)
        slot.Position         = UDim2.new(0, (i - 1) * 28, 0, 0)
        slot.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        slot.BorderSizePixel  = 0
        slot.Parent           = slotsFrame
        Instance.new("UICorner", slot).CornerRadius = UDim.new(1, 0)
        slotDots[i] = slot
    end

    -- 3-column x 2-row manual grid (no UIGridLayout)
    local BTN_W, BTN_H = 126, 108
    local BTN_PAD      = 8
    local GRID_LEFT    = (440 - (3 * BTN_W + 2 * BTN_PAD)) / 2
    local gridPositions = {}
    for row = 0, 1 do
        for col = 0, 2 do
            table.insert(gridPositions, {
                x = GRID_LEFT + col * (BTN_W + BTN_PAD),
                y = 130 + row * (BTN_H + BTN_PAD),
            })
        end
    end

    local correctClicks = 0
    local wrongClicks   = 0
    local done          = false

    local function finalize()
        if done then return end
        done = true
        local score = math.max(0, math.floor(correctClicks / REQUIRED * 100) - wrongClicks * 10)
        humanoid.WalkSpeed = 16
        humanoid.JumpHeight = 7.2
        sg:Destroy()
        resultRemote:FireServer(score)
    end

    for i, data in ipairs(buttonData) do
        local pos = gridPositions[i]
        local btn = Instance.new("TextButton")
        btn.Size             = UDim2.new(0, BTN_W, 0, BTN_H)
        btn.Position         = UDim2.new(0, pos.x, 0, pos.y)
        btn.BackgroundColor3 = data.correct
            and Color3.fromRGB(240, 200, 150)
            or  Color3.fromRGB(160, 160, 160)
        btn.TextColor3       = Color3.fromRGB(20, 20, 20)
        btn.TextScaled       = true
        btn.TextWrapped      = true
        btn.Font             = Enum.Font.GothamBold
        btn.Text             = COOKIE_DISPLAY[data.id] or data.id
        btn.BorderSizePixel  = 0
        btn.Parent           = bg
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

        local clicked = false
        btn.MouseButton1Click:Connect(function()
            if done or clicked then return end
            if data.correct then
                clicked = true
                correctClicks = correctClicks + 1
                btn.BackgroundColor3 = Color3.fromRGB(80, 200, 80)
                if slotDots[correctClicks] then
                    slotDots[correctClicks].BackgroundColor3 = Color3.fromRGB(80, 200, 80)
                end
                if correctClicks >= REQUIRED then
                    task.delay(0.3, finalize)
                end
            else
                wrongClicks = wrongClicks + 1
                btn.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
                task.delay(0.5, function()
                    if btn.Parent then
                        btn.BackgroundColor3 = Color3.fromRGB(160, 160, 160)
                    end
                end)
            end
        end)
    end

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

    local elapsed   = 0
    local timerConn
    timerConn = RunService.Heartbeat:Connect(function(dt)
        if done then timerConn:Disconnect() return end
        elapsed = elapsed + dt
        timerFill.Size = UDim2.new(math.clamp(1 - elapsed / TIMER, 0, 1), 0, 1, 0)
        if elapsed >= TIMER then
            timerConn:Disconnect()
            finalize()
        end
    end)
end)

print("[DressMinigame] Ready.")