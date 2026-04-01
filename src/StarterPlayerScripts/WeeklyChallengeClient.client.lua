-- StarterPlayerScripts/WeeklyChallengeClient (LocalScript)
-- HUD widget (above daily widget) + back-room board at WeeklyChallengesBoard Part.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteManager  = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))

local initRemote     = RemoteManager.Get("WeeklyChallengesInit")
local progressRemote = RemoteManager.Get("WeeklyChallengeProgress")
local stateRemote    = RemoteManager.Get("GameStateChanged")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local hud       = playerGui:WaitForChild("HUD")

local state = { challenges={}, progress={0,0,0}, claimed={false,false,false}, resetIn=0 }

local TIER_ICONS  = {"☆", "☆☆", "☆☆☆"}
local TIER_COLORS = {
    Color3.fromRGB(80, 200, 80),
    Color3.fromRGB(80, 150, 220),
    Color3.fromRGB(220, 100, 220),
}

-- ─── HUD Widget ───────────────────────────────────────────────────────────────
local hudWidget

local function makeHudWidget()
    local frame = hud:FindFirstChild("WeeklyChallengesWidget")
    if not frame then
        frame = Instance.new("Frame")
        frame.Name                   = "WeeklyChallengesWidget"
        frame.Size                   = UDim2.new(0, 230, 0, 84)
        frame.Position               = UDim2.new(0, 10, 1, -202)  -- 14px gap above DailyChallengesWidget
        frame.BackgroundColor3       = Color3.fromRGB(10, 10, 30)
        frame.BackgroundTransparency = 0.25
        frame.BorderSizePixel        = 0
        local corner = Instance.new("UICorner", frame)
        corner.CornerRadius = UDim.new(0, 8)

        local accent = Instance.new("Frame", frame)
        accent.Size             = UDim2.new(0, 3, 1, 0)
        accent.BackgroundColor3 = Color3.fromRGB(100, 180, 255)
        accent.BorderSizePixel  = 0

        local title = Instance.new("TextLabel", frame)
        title.Name                   = "Title"
        title.Size                   = UDim2.new(1, -8, 0, 20)
        title.Position               = UDim2.new(0, 8, 0, 0)
        title.BackgroundTransparency = 1
        title.TextColor3             = Color3.fromRGB(100, 200, 255)
        title.TextScaled             = true
        title.Font                   = Enum.Font.GothamBold
        title.Text                   = "Weekly Challenges"
        title.TextXAlignment         = Enum.TextXAlignment.Left

        for i = 1, 3 do
            local row = Instance.new("TextLabel", frame)
            row.Name                   = "Row" .. i
            row.Size                   = UDim2.new(1, -10, 0, 20)
            row.Position               = UDim2.new(0, 5, 0, 18 + (i-1) * 22)
            row.BackgroundTransparency = 1
            row.TextColor3             = Color3.fromRGB(200, 200, 200)
            row.TextScaled             = true
            row.Font                   = Enum.Font.Gotham
            row.TextXAlignment         = Enum.TextXAlignment.Left
            row.Text                   = TIER_ICONS[i] .. "  0 / 0"
        end

        frame.Parent = hud
    end
    frame.Visible = false
    return frame
end

local function updateHudWidget()
    if not hudWidget then return end
    for i = 1, 3 do
        local row = hudWidget:FindFirstChild("Row" .. i)
        local ch  = state.challenges[i]
        if row and ch then
            if state.claimed[i] then
                row.Text       = TIER_ICONS[i] .. "  Done"
                row.TextColor3 = Color3.fromRGB(100, 220, 100)
            else
                row.Text       = TIER_ICONS[i] .. "  " .. (state.progress[i] or 0) .. " / " .. ch.goal
                row.TextColor3 = Color3.fromRGB(200, 200, 200)
            end
        end
    end
end

-- ─── Back-Room Board ──────────────────────────────────────────────────────────
local function getBoardGui()
    local part = workspace:FindFirstChild("WeeklyChallengesBoard")
    return part and part:FindFirstChild("WeeklyBoardGui")
end

local function updateBoard()
    local sg = getBoardGui()
    if not sg then return end
    local bg = sg:FindFirstChild("Bg")
    if not bg then return end

    local header = bg:FindFirstChild("Header")
    if header then
        local h = math.floor(state.resetIn / 3600)
        local m = math.floor((state.resetIn % 3600) / 60)
        local s = state.resetIn % 60
        header.Text = string.format("Weekly Challenges — Resets in %02d:%02d:%02d", h, m, s)
    end

    for i = 1, 3 do
        local row = bg:FindFirstChild("Row" .. i)
        local ch  = state.challenges[i]
        if not row or not ch then continue end

        local label  = row:FindFirstChild("Label")
        local reward = row:FindFirstChild("Reward")
        local pbBg   = row:FindFirstChild("ProgressBar")
        local fill   = pbBg and pbBg:FindFirstChild("Fill")

        if label then
            if state.claimed[i] then
                label.Text       = "Done - " .. ch.tier .. ": " .. ch.label
                label.TextColor3 = Color3.fromRGB(100, 220, 100)
            else
                label.Text       = ch.tier .. ": " .. ch.label
                label.TextColor3 = Color3.fromRGB(230, 230, 230)
            end
        end
        if reward then
            reward.Text = state.claimed[i] and "CLAIMED" or ("+" .. ch.reward .. " coins")
            reward.TextColor3 = state.claimed[i]
                and Color3.fromRGB(100, 220, 100)
                or  Color3.fromRGB(255, 220, 50)
        end
        if fill then
            local ratio = ch.goal > 0 and math.min(1, (state.progress[i] or 0) / ch.goal) or 0
            fill.Size             = UDim2.new(state.claimed[i] and 1 or ratio, 0, 1, 0)
            fill.BackgroundColor3 = state.claimed[i]
                and Color3.fromRGB(80, 200, 80)
                or  TIER_COLORS[i]
        end
    end
end

-- ─── Completion Flash ─────────────────────────────────────────────────────────
local function showCompletionFlash(coinsAwarded)
    local flash = Instance.new("TextLabel")
    flash.Size             = UDim2.new(0, 340, 0, 60)
    flash.Position         = UDim2.new(0.5, -170, 0.3, 0)
    flash.BackgroundColor3 = Color3.fromRGB(30, 80, 180)
    flash.TextColor3       = Color3.fromRGB(255, 255, 255)
    flash.TextScaled       = true
    flash.Font             = Enum.Font.GothamBold
    flash.Text             = "Weekly Challenge Complete!  +" .. coinsAwarded .. " coins"
    flash.ZIndex           = 50
    flash.BorderSizePixel  = 0
    flash.Parent           = hud
    local c = Instance.new("UICorner", flash)
    c.CornerRadius = UDim.new(0, 12)
    game:GetService("Debris"):AddItem(flash, 3)
end

-- ─── Remote Handlers ─────────────────────────────────────────────────────────
initRemote.OnClientEvent:Connect(function(data)
    state.challenges = data.challenges or {}
    state.progress   = data.progress   or {0, 0, 0}
    state.claimed    = data.claimed    or {false, false, false}
    state.resetIn    = data.resetIn    or 0
    updateHudWidget()
    updateBoard()
    -- BUG-57: show widget immediately if game is already Open when init data arrives
    if hudWidget then
        local currentState = workspace:GetAttribute("GameState")
        hudWidget.Visible = (currentState == "Open")
    end
end)

progressRemote.OnClientEvent:Connect(function(data)
    state.progress[data.index] = data.progress
    state.claimed[data.index]  = data.completed
    if data.justCompleted then showCompletionFlash(data.coinsAwarded) end
    updateHudWidget()
    updateBoard()
end)

stateRemote.OnClientEvent:Connect(function(gameState)
    if hudWidget then
        hudWidget.Visible = (gameState == "Open")
    end
end)

-- ─── Countdown Tick ───────────────────────────────────────────────────────────
task.spawn(function()
    while true do
        task.wait(1)
        if state.resetIn > 0 then state.resetIn -= 1 end
        local sg = getBoardGui()
        if sg then
            local bg     = sg:FindFirstChild("Bg")
            local header = bg and bg:FindFirstChild("Header")
            if header and #state.challenges > 0 then
                local h = math.floor(state.resetIn / 3600)
                local m = math.floor((state.resetIn % 3600) / 60)
                local s = state.resetIn % 60
                header.Text = string.format("Weekly Challenges — Resets in %02d:%02d:%02d", h, m, s)
            end
        end
    end
end)

-- ─── Init ─────────────────────────────────────────────────────────────────────
hudWidget = makeHudWidget()
print("[WeeklyChallengeClient] Ready.")
