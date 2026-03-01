-- src/StarterPlayer/StarterPlayerScripts/Minigames/DressMinigame.client.lua
-- Redesigned: rapid-fire quality check — KEEP or TOSS each cookie card

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local RemoteManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local startRemote   = RemoteManager.Get("StartDressMinigame")
local resultRemote  = RemoteManager.Get("DressMinigameResult")

local player = Players.LocalPlayer

local COOKIE_DISPLAY = {
    pink_sugar            = "Pink Sugar",
    chocolate_chip        = "Choc Chip",
    birthday_cake         = "Bday Cake",
    cookies_and_cream     = "C&C",
    snickerdoodle         = "Snickerdoodle",
    lemon_blackraspberry  = "Lemon Berry",
}

local COOKIE_COLOR = {
    pink_sugar            = Color3.fromRGB(255, 182, 193),
    chocolate_chip        = Color3.fromRGB(139, 90, 43),
    birthday_cake         = Color3.fromRGB(255, 220, 80),
    cookies_and_cream     = Color3.fromRGB(60, 60, 60),
    snickerdoodle         = Color3.fromRGB(205, 133, 63),
    lemon_blackraspberry  = Color3.fromRGB(160, 40, 100),
}

local ALL_IDS = {
    "pink_sugar", "chocolate_chip", "birthday_cake",
    "cookies_and_cream", "snickerdoodle", "lemon_blackraspberry",
}

local NUM_COOKIES   = 6
local NUM_CORRECT   = 3
local PER_CARD_TIME = 1.8

startRemote.OnClientEvent:Connect(function(cookieId)
    if player.PlayerGui:FindFirstChild("DressGui") then return end
    local char = player.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    humanoid.WalkSpeed = 0
    humanoid.JumpHeight = 0

    local wrongIds = {}
    for _, id in ipairs(ALL_IDS) do
        if id ~= cookieId then table.insert(wrongIds, id) end
    end
    for i = #wrongIds, 2, -1 do
        local j = math.random(1, i)
        wrongIds[i], wrongIds[j] = wrongIds[j], wrongIds[i]
    end
    local deck = {}
    for _ = 1, NUM_CORRECT do
        table.insert(deck, { id = cookieId, keep = true })
    end
    for k = 1, NUM_COOKIES - NUM_CORRECT do
        table.insert(deck, { id = wrongIds[k], keep = false })
    end
    for i = #deck, 2, -1 do
        local j = math.random(1, i)
        deck[i], deck[j] = deck[j], deck[i]
    end

    local sg = Instance.new("ScreenGui")
    sg.Name           = "DressGui"
    sg.ResetOnSpawn   = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent         = player.PlayerGui

    local bg = Instance.new("Frame")
    bg.Size                   = UDim2.new(0, 380, 0, 460)
    bg.Position               = UDim2.new(0.5, -190, 0.5, -230)
    bg.BackgroundColor3       = Color3.fromRGB(20, 20, 20)
    bg.BackgroundTransparency = 0.1
    bg.BorderSizePixel        = 0
    bg.Parent                 = sg
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 16)

    local orderLbl = Instance.new("TextLabel")
    orderLbl.Size             = UDim2.new(1, -20, 0, 48)
    orderLbl.Position         = UDim2.new(0, 10, 0, 10)
    orderLbl.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
    orderLbl.TextColor3       = Color3.fromRGB(20, 20, 20)
    orderLbl.TextScaled       = true
    orderLbl.Font             = Enum.Font.GothamBold
    orderLbl.Text             = "Order: " .. (COOKIE_DISPLAY[cookieId] or cookieId)
    orderLbl.BorderSizePixel  = 0
    orderLbl.Parent           = bg
    Instance.new("UICorner", orderLbl).CornerRadius = UDim.new(0, 8)

    local instrLbl = Instance.new("TextLabel")
    instrLbl.Size                   = UDim2.new(1, 0, 0, 22)
    instrLbl.Position               = UDim2.new(0, 0, 0, 64)
    instrLbl.BackgroundTransparency = 1
    instrLbl.TextColor3             = Color3.fromRGB(180, 180, 180)
    instrLbl.TextScaled             = true
    instrLbl.Font                   = Enum.Font.Gotham
    instrLbl.Text                   = "KEEP or TOSS each cookie!"
    instrLbl.Parent                 = bg

    local dotsFrame = Instance.new("Frame")
    dotsFrame.Size                   = UDim2.new(0, NUM_COOKIES * 28, 0, 20)
    dotsFrame.Position               = UDim2.new(0.5, -NUM_COOKIES * 14, 0, 92)
    dotsFrame.BackgroundTransparency = 1
    dotsFrame.Parent                 = bg
    local dots = {}
    for i = 1, NUM_COOKIES do
        local d = Instance.new("Frame")
        d.Size             = UDim2.new(0, 20, 0, 20)
        d.Position         = UDim2.new(0, (i - 1) * 28, 0, 0)
        d.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
        d.BorderSizePixel  = 0
        d.Parent           = dotsFrame
        Instance.new("UICorner", d).CornerRadius = UDim.new(1, 0)
        dots[i] = d
    end

    local card = Instance.new("Frame")
    card.Size             = UDim2.new(0, 240, 0, 180)
    card.Position         = UDim2.new(0.5, -120, 0, 124)
    card.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    card.BorderSizePixel  = 0
    card.Parent           = bg
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 16)

    local cardSwatch = Instance.new("Frame")
    cardSwatch.Size             = UDim2.new(1, 0, 0.38, 0)
    cardSwatch.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    cardSwatch.BorderSizePixel  = 0
    cardSwatch.Parent           = card
    Instance.new("UICorner", cardSwatch).CornerRadius = UDim.new(0, 16)

    local cardLabel = Instance.new("TextLabel")
    cardLabel.Size                   = UDim2.new(1, 0, 0.62, 0)
    cardLabel.Position               = UDim2.new(0, 0, 0.38, 0)
    cardLabel.BackgroundTransparency = 1
    cardLabel.TextColor3             = Color3.fromRGB(255, 255, 255)
    cardLabel.TextScaled             = true
    cardLabel.Font                   = Enum.Font.GothamBold
    cardLabel.Text                   = ""
    cardLabel.Parent                 = card

    local cardTimerBg = Instance.new("Frame")
    cardTimerBg.Size             = UDim2.new(0.85, 0, 0, 5)
    cardTimerBg.Position         = UDim2.new(0.075, 0, 1, -10)
    cardTimerBg.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    cardTimerBg.BorderSizePixel  = 0
    cardTimerBg.Parent           = card
    Instance.new("UICorner", cardTimerBg).CornerRadius = UDim.new(1, 0)
    local cardTimerFill = Instance.new("Frame")
    cardTimerFill.Size             = UDim2.new(1, 0, 1, 0)
    cardTimerFill.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
    cardTimerFill.BorderSizePixel  = 0
    cardTimerFill.Parent           = cardTimerBg
    Instance.new("UICorner", cardTimerFill).CornerRadius = UDim.new(1, 0)

    local keepBtn = Instance.new("TextButton")
    keepBtn.Size             = UDim2.new(0, 155, 0, 60)
    keepBtn.Position         = UDim2.new(0, 14, 0, 318)
    keepBtn.BackgroundColor3 = Color3.fromRGB(50, 170, 70)
    keepBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
    keepBtn.TextScaled       = true
    keepBtn.Font             = Enum.Font.GothamBold
    keepBtn.Text             = "KEEP"
    keepBtn.BorderSizePixel  = 0
    keepBtn.Parent           = bg
    Instance.new("UICorner", keepBtn).CornerRadius = UDim.new(0, 10)

    local tossBtn = Instance.new("TextButton")
    tossBtn.Size             = UDim2.new(0, 155, 0, 60)
    tossBtn.Position         = UDim2.new(1, -169, 0, 318)
    tossBtn.BackgroundColor3 = Color3.fromRGB(190, 50, 50)
    tossBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
    tossBtn.TextScaled       = true
    tossBtn.Font             = Enum.Font.GothamBold
    tossBtn.Text             = "TOSS"
    tossBtn.BorderSizePixel  = 0
    tossBtn.Parent           = bg
    Instance.new("UICorner", tossBtn).CornerRadius = UDim.new(0, 10)

    local progLbl = Instance.new("TextLabel")
    progLbl.Size                   = UDim2.new(1, 0, 0, 22)
    progLbl.Position               = UDim2.new(0, 0, 0, 388)
    progLbl.BackgroundTransparency = 1
    progLbl.TextColor3             = Color3.fromRGB(140, 140, 140)
    progLbl.TextScaled             = true
    progLbl.Font                   = Enum.Font.Gotham
    progLbl.Text                   = "1 / " .. NUM_COOKIES
    progLbl.Parent                 = bg

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

    local cardIndex    = 0
    local correctCount = 0
    local done         = false
    local cardElapsed  = 0
    local answered     = false
    local mainConn

    local function finalize()
        if done then return end
        done = true
        if mainConn then mainConn:Disconnect() end
        humanoid.WalkSpeed  = 16
        humanoid.JumpHeight = 7.2
        sg:Destroy()
        resultRemote:FireServer(math.floor(correctCount / NUM_COOKIES * 100))
    end

    local function showCard(idx)
        if idx > NUM_COOKIES then
            task.delay(0.25, finalize)
            return
        end
        cardIndex   = idx
        cardElapsed = 0
        answered    = false
        local entry = deck[idx]
        cardSwatch.BackgroundColor3 = COOKIE_COLOR[entry.id] or Color3.fromRGB(80, 80, 80)
        cardLabel.Text              = COOKIE_DISPLAY[entry.id] or entry.id
        cardTimerFill.Size          = UDim2.new(1, 0, 1, 0)
        progLbl.Text                = idx .. " / " .. NUM_COOKIES
        keepBtn.BackgroundColor3    = Color3.fromRGB(50, 170, 70)
        tossBtn.BackgroundColor3    = Color3.fromRGB(190, 50, 50)
        dots[idx].BackgroundColor3  = Color3.fromRGB(200, 200, 50)
    end

    local function answer(keepChoice)
        if answered or done then return end
        answered = true
        local entry   = deck[cardIndex]
        local isRight = (keepChoice == entry.keep)
        if isRight then
            correctCount = correctCount + 1
            dots[cardIndex].BackgroundColor3 = Color3.fromRGB(70, 200, 70)
        else
            dots[cardIndex].BackgroundColor3 = Color3.fromRGB(210, 55, 55)
        end
        if keepChoice then
            keepBtn.BackgroundColor3 = isRight
                and Color3.fromRGB(40, 230, 60)
                or  Color3.fromRGB(210, 55, 55)
        else
            tossBtn.BackgroundColor3 = isRight
                and Color3.fromRGB(40, 230, 60)
                or  Color3.fromRGB(210, 55, 55)
        end
        task.delay(0.25, function()
            if not done then showCard(cardIndex + 1) end
        end)
    end

    keepBtn.MouseButton1Click:Connect(function() answer(true) end)
    tossBtn.MouseButton1Click:Connect(function() answer(false) end)

    showCard(1)

    local totalTime    = NUM_COOKIES * (PER_CARD_TIME + 0.4) + 1
    local totalElapsed = 0

    mainConn = RunService.Heartbeat:Connect(function(dt)
        if done then return end
        totalElapsed = totalElapsed + dt
        timerFill.Size = UDim2.new(
            math.clamp(1 - totalElapsed / (NUM_COOKIES * PER_CARD_TIME), 0, 1),
            0, 1, 0
        )
        if not answered then
            cardElapsed = cardElapsed + dt
            cardTimerFill.Size = UDim2.new(
                math.clamp(1 - cardElapsed / PER_CARD_TIME, 0, 1),
                0, 1, 0
            )
            if cardElapsed >= PER_CARD_TIME then
                answer(false)
            end
        end
        if totalElapsed >= totalTime then finalize() end
    end)
end)

print("[DressMinigame] Ready.")
