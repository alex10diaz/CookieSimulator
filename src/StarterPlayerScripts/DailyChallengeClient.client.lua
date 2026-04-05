-- StarterPlayerScripts/DailyChallengeClient (LocalScript)
-- Renders the Daily Challenges back room board and a compact HUD widget.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")

local RemoteManager  = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))

local initRemote     = RemoteManager.Get("DailyChallengesInit")
local progressRemote = RemoteManager.Get("DailyChallengeProgress")
local stateRemote    = RemoteManager.Get("GameStateChanged")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local hud       = playerGui:WaitForChild("HUD")

-- ─── State ──────────────────────────────────────────────────────────────────
local state = {
    challenges = {},
    progress   = {0, 0, 0},
    claimed    = {false, false, false},
    resetIn    = 0,
}

local TIER_ICONS  = {"★", "★★", "★★★"}
local TIER_COLORS = {
    Color3.fromRGB(80, 200, 80),
    Color3.fromRGB(80, 150, 220),
    Color3.fromRGB(220, 100, 220),
}

local function getViewportSize()
    local camera = workspace.CurrentCamera
    return camera and camera.ViewportSize or Vector2.new(1280, 720)
end

local function ensureTextConstraint(label, minSize, maxSize)
    local constraint = label:FindFirstChildOfClass("UITextSizeConstraint")
    if not constraint then
        constraint = Instance.new("UITextSizeConstraint")
        constraint.Parent = label
    end
    constraint.MinTextSize = minSize
    constraint.MaxTextSize = maxSize
end

-- ─── HUD Widget ─────────────────────────────────────────────────────────────
local hudWidget

local function makeHudWidget()
    local frame = hud:FindFirstChild("DailyChallengesWidget")
    if not frame then
        frame = Instance.new("Frame")
        frame.Name              = "DailyChallengesWidget"
        frame.Size              = UDim2.new(0, 230, 0, 84)
        frame.Position          = UDim2.new(0, 20, 1, -104)
        frame.BackgroundColor3  = Color3.fromRGB(15, 15, 15)
        frame.BackgroundTransparency = 0.25
        frame.BorderSizePixel   = 0
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = frame

        local title = Instance.new("TextLabel")
        title.Name              = "Title"
        title.Size              = UDim2.new(1, 0, 0, 20)
        title.BackgroundTransparency = 1
        title.TextColor3        = Color3.fromRGB(255, 220, 50)
        title.TextScaled        = true
        title.Font              = Enum.Font.GothamBold
        title.Text              = "Daily Challenges"
        title.Parent            = frame

        for i = 1, 3 do
            local row = Instance.new("TextLabel")
            row.Name                = "Row" .. i
            row.Size                = UDim2.new(1, -10, 0, 20)
            row.Position            = UDim2.new(0, 5, 0, 18 + (i - 1) * 22)
            row.BackgroundTransparency = 1
            row.TextColor3          = Color3.fromRGB(200, 200, 200)
            row.TextScaled          = true
            row.Font                = Enum.Font.Gotham
            row.TextXAlignment      = Enum.TextXAlignment.Left
            row.Text                = TIER_ICONS[i] .. "  0 / 0"
            row.Parent              = frame
        end

        frame.Parent = hud
    end
    frame.Visible = false
    return frame
end

local dailyViewportConn = nil
local function applyHudWidgetLayout()
    if not hudWidget then return end
    local viewport = getViewportSize()
    local compact = UserInputService.TouchEnabled and (viewport.X <= 900 or viewport.Y <= 560)
    hudWidget.Size = compact and UDim2.new(0, 174, 0, 62) or UDim2.new(0, 230, 0, 84)
    hudWidget.Position = compact and UDim2.new(0, 10, 1, -60) or UDim2.new(0, 20, 1, -104)

    local title = hudWidget:FindFirstChild("Title")
    if title and title:IsA("TextLabel") then
        title.Size = UDim2.new(1, -8, 0, compact and 16 or 20)
        title.Position = UDim2.new(0, 4, 0, 0)
        ensureTextConstraint(title, 8, compact and 13 or 18)
    end

    for i = 1, 3 do
        local row = hudWidget:FindFirstChild("Row" .. i)
        if row and row:IsA("TextLabel") then
            row.Size = UDim2.new(1, -10, 0, compact and 13 or 20)
            row.Position = UDim2.new(0, 5, 0, compact and (14 + (i - 1) * 14) or (18 + (i - 1) * 22))
            ensureTextConstraint(row, 7, compact and 11 or 16)
        end
    end
end

local function connectViewportResize()
    local camera = workspace.CurrentCamera
    if not camera then return end
    if dailyViewportConn then
        dailyViewportConn:Disconnect()
    end
    dailyViewportConn = camera:GetPropertyChangedSignal("ViewportSize"):Connect(applyHudWidgetLayout)
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

-- ─── Back Room Board ─────────────────────────────────────────────────────────
local function getBoardGui()
    local part = workspace:FindFirstChild("ChallengesBoard")
    return part and part:FindFirstChild("ChallengesBoardGui")
end

local function updateBoard()
    local sg = getBoardGui()
    if not sg then return end

    local header = sg:FindFirstChild("Header", true)
    if header then
        local h = math.floor(state.resetIn / 3600)
        local m = math.floor((state.resetIn % 3600) / 60)
        local s = state.resetIn % 60
        header.Text = string.format("Daily Challenges — Resets in %02d:%02d:%02d", h, m, s)
    end

    for i = 1, 3 do
        local row = sg:FindFirstChild("Row" .. i, true)
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

-- ─── Completion Flash ────────────────────────────────────────────────────────
local function showCompletionFlash(coinsAwarded)
    local flash = Instance.new("TextLabel")
    flash.Size              = UDim2.new(0, 300, 0, 60)
    flash.Position          = UDim2.new(0.5, -150, 0.35, 0)
    flash.BackgroundColor3  = Color3.fromRGB(200, 160, 0)
    flash.TextColor3        = Color3.fromRGB(255, 255, 255)
    flash.TextScaled        = true
    flash.Font              = Enum.Font.GothamBold
    flash.Text              = "Challenge Complete!  +" .. coinsAwarded .. " coins"
    flash.ZIndex            = 50
    flash.BorderSizePixel   = 0
    flash.Parent            = hud
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 12)
    c.Parent = flash
    game:GetService("Debris"):AddItem(flash, 2.5)
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
    if data.justCompleted then
        showCompletionFlash(data.coinsAwarded)
    end
    updateHudWidget()
    updateBoard()
end)

stateRemote.OnClientEvent:Connect(function(gameState)
    if hudWidget then
        hudWidget.Visible = (gameState == "Open")
    end
end)

-- ─── Countdown tick ──────────────────────────────────────────────────────────
task.spawn(function()
    while true do
        task.wait(1)
        if state.resetIn > 0 then
            state.resetIn -= 1
        end
        local sg = getBoardGui()
        if sg then
            local header = sg:FindFirstChild("Header", true)
            if header then
                local h = math.floor(state.resetIn / 3600)
                local m = math.floor((state.resetIn % 3600) / 60)
                local s = state.resetIn % 60
                header.Text = string.format("Daily Challenges — Resets in %02d:%02d:%02d", h, m, s)
            end
        end
    end
end)

-- ─── Init ────────────────────────────────────────────────────────────────────
hudWidget = makeHudWidget()
applyHudWidgetLayout()
connectViewportResize()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    applyHudWidgetLayout()
    connectViewportResize()
end)
print("[DailyChallengeClient] Ready.")
