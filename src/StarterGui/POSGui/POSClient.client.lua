-- src/StarterGui/POSGui/POSClient.client.lua
-- Handles the POS order cutscene modal.
-- Triggered by StartOrderCutscene (server → client) when player presses E on NPC.
-- Fires ConfirmNPCOrder (client → server) when player dismisses or 15s passes.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")

local RemoteManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))

local stateRemote    = RemoteManager.Get("GameStateChanged")
local cutsceneRemote = RemoteManager.Get("StartOrderCutscene")
local confirmRemote  = RemoteManager.Get("ConfirmNPCOrder")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local posGui    = playerGui:WaitForChild("POSGui")
posGui.Enabled  = false

local ACCENT               = Color3.fromRGB(255, 200, 0)   -- gold
local AUTO_DISMISS_SECONDS = 15

-- Module-level handles so stateRemote + Escape can reach the active modal.
-- currentDismiss:    fires ConfirmNPCOrder + closes (X button, Escape, auto-dismiss)
-- currentForceClose: closes silently without firing (game-state change)
local currentDismiss    = nil
local currentForceClose = nil

-- ─── BUILD CUTSCENE MODAL ─────────────────────────────────────────────────────
local function showOrderCutscene(payload)
    if currentForceClose then currentForceClose() end

    posGui.Enabled = true

    -- ── Main card ──
    local modal = Instance.new("Frame")
    modal.Name                   = "OrderModal"
    modal.Size                   = UDim2.new(0, 440, 0, 310)
    modal.Position               = UDim2.new(0.5, -220, 0.5, -155)
    modal.BackgroundColor3       = Color3.fromRGB(14, 14, 26)
    modal.BackgroundTransparency = 0
    modal.BorderSizePixel        = 0
    modal.Parent                 = posGui
    Instance.new("UICorner", modal).CornerRadius = UDim.new(0, 16)
    local ms = Instance.new("UIStroke", modal)
    ms.Color     = ACCENT
    ms.Thickness = 1.5

    -- ── Gold header bar ──
    local headerBar = Instance.new("Frame", modal)
    headerBar.Name             = "HeaderBar"
    headerBar.Size             = UDim2.new(1, 0, 0, 46)
    headerBar.BackgroundColor3 = ACCENT
    headerBar.BorderSizePixel  = 0
    Instance.new("UICorner", headerBar).CornerRadius = UDim.new(0, 16)
    local hFlat = Instance.new("Frame", headerBar)
    hFlat.Size             = UDim2.new(1, 0, 0.5, 0)
    hFlat.Position         = UDim2.new(0, 0, 0.5, 0)
    hFlat.BackgroundColor3 = ACCENT
    hFlat.BorderSizePixel  = 0

    local titleLbl = Instance.new("TextLabel", headerBar)
    titleLbl.Size                   = UDim2.new(1, -56, 1, 0)
    titleLbl.Position               = UDim2.new(0, 14, 0, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.TextColor3             = Color3.fromRGB(20, 14, 4)
    titleLbl.TextScaled             = true
    titleLbl.Font                   = Enum.Font.GothamBold
    titleLbl.Text                   = "New Order"
    titleLbl.TextXAlignment         = Enum.TextXAlignment.Left

    -- ── X close button (sits in header) ──
    local closeBtn = Instance.new("TextButton", modal)
    closeBtn.Name              = "CloseBtn"
    closeBtn.Size              = UDim2.new(0, 30, 0, 30)
    closeBtn.Position          = UDim2.new(1, -38, 0, 8)
    closeBtn.BackgroundColor3  = Color3.fromRGB(200, 55, 55)
    closeBtn.TextColor3        = Color3.fromRGB(255, 255, 255)
    closeBtn.Font              = Enum.Font.GothamBold
    closeBtn.TextScaled        = true
    closeBtn.Text              = "X"
    closeBtn.BorderSizePixel   = 0
    closeBtn.ZIndex            = 5
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(1, 0)

    -- ── Speech bubble ──
    local bubble = Instance.new("TextLabel", modal)
    bubble.Name                   = "SpeechBubble"
    bubble.Size                   = UDim2.new(1, -24, 0, 96)
    bubble.Position               = UDim2.new(0, 12, 0, 54)
    bubble.BackgroundColor3       = Color3.fromRGB(22, 22, 44)
    bubble.BackgroundTransparency = 0
    bubble.TextColor3             = Color3.fromRGB(220, 220, 240)
    bubble.TextScaled             = true
    bubble.Font                   = Enum.Font.Gotham
    bubble.Text                   = string.format(
        '"%s says: I\'d like %d\xC3\x97 %s, please!"',
        payload.npcName, payload.packSize, payload.cookieName)
    bubble.TextWrapped            = true
    Instance.new("UICorner", bubble).CornerRadius = UDim.new(0, 10)
    local bubbleStroke = Instance.new("UIStroke", bubble)
    bubbleStroke.Color     = Color3.fromRGB(50, 50, 80)
    bubbleStroke.Thickness = 1

    -- ── Earnings card ──
    local earningsLines = {
        string.format("Base reward:  %d coins", payload.baseCoins),
    }
    if payload.isVIP then
        table.insert(earningsLines, "VIP Bonus:  \xC3\x971.75")
        table.insert(earningsLines, string.format(
            "Potential:  %d coins  \xe2\x98\x85", math.floor(payload.baseCoins * 1.75)))
    end

    local earnings = Instance.new("TextLabel", modal)
    earnings.Name                   = "EarningsCard"
    earnings.Size                   = UDim2.new(1, -24, 0, 104)
    earnings.Position               = UDim2.new(0, 12, 0, 160)
    earnings.BackgroundColor3       = payload.isVIP
        and Color3.fromRGB(40, 30, 4)
        or  Color3.fromRGB(20, 20, 38)
    earnings.BackgroundTransparency = 0
    earnings.TextColor3             = payload.isVIP
        and Color3.fromRGB(255, 220, 60)
        or  Color3.fromRGB(160, 160, 200)
    earnings.TextScaled             = true
    earnings.Font                   = Enum.Font.GothamBold
    earnings.Text                   = table.concat(earningsLines, "\n")
    earnings.TextWrapped            = true
    Instance.new("UICorner", earnings).CornerRadius = UDim.new(0, 10)
    local earningsStroke = Instance.new("UIStroke", earnings)
    earningsStroke.Color     = payload.isVIP
        and Color3.fromRGB(180, 140, 20)
        or  Color3.fromRGB(40, 40, 70)
    earningsStroke.Thickness = 1

    -- ── Countdown label ──
    local countdown = Instance.new("TextLabel", modal)
    countdown.Name                   = "Countdown"
    countdown.Size                   = UDim2.new(1, -24, 0, 22)
    countdown.Position               = UDim2.new(0, 12, 1, -30)
    countdown.BackgroundTransparency = 1
    countdown.TextColor3             = Color3.fromRGB(80, 80, 100)
    countdown.TextXAlignment         = Enum.TextXAlignment.Left
    countdown.TextScaled             = true
    countdown.Font                   = Enum.Font.Gotham
    countdown.Text                   = "Auto-dismissing in " .. AUTO_DISMISS_SECONDS .. "..."

    -- ── Dismiss helpers ─────────────────────────────────────────────────────
    local dismissed = false

    -- User-initiated close: fires ConfirmNPCOrder so server starts the order.
    local function dismiss()
        if dismissed then return end
        dismissed = true
        currentDismiss    = nil
        currentForceClose = nil
        confirmRemote:FireServer(payload.npcId)
        modal:Destroy()
        posGui.Enabled = false
    end

    -- Game-state-change close: modal goes away but server already knows; no fire.
    local function forceClose()
        if dismissed then return end
        dismissed = true
        currentDismiss    = nil
        currentForceClose = nil
        modal:Destroy()
        posGui.Enabled = false
    end

    currentDismiss    = dismiss
    currentForceClose = forceClose

    closeBtn.MouseButton1Click:Connect(dismiss)

    -- ── Auto-dismiss countdown ──
    task.spawn(function()
        for i = AUTO_DISMISS_SECONDS - 1, 0, -1 do
            task.wait(1)
            if dismissed then return end
            countdown.Text = i > 0
                and ("Auto-dismissing in " .. i .. "...")
                or  "Dismissing..."
        end
        dismiss()
    end)
end

-- ─── REMOTE LISTENERS ─────────────────────────────────────────────────────────
cutsceneRemote.OnClientEvent:Connect(function(payload)
    showOrderCutscene(payload)
end)

stateRemote.OnClientEvent:Connect(function(state)
    if state == "EndOfDay" or state == "Lobby" then
        if currentForceClose then currentForceClose() end
        posGui.Enabled = false
    end
end)

-- Escape key: calls dismiss() via module-level ref
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.Escape then
        if currentDismiss then currentDismiss() end
    end
end)

print("[POSClient] Ready.")
