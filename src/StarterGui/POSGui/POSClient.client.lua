-- src/StarterGui/POSGui/POSClient.client.lua
-- Handles the POS order cutscene modal.
-- Triggered by StartOrderCutscene (server → client) when player presses E on NPC.
-- Fires ConfirmNPCOrder (client → server) when player dismisses or 5s passes.

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

local AUTO_DISMISS_SECONDS = 15

-- Module-level handles so stateRemote + Escape can reach the active modal's close fns.
-- currentDismiss: fires ConfirmNPCOrder + closes (X button, Escape, auto-dismiss)
-- currentForceClose: closes silently without firing (game-state change)
local currentDismiss    = nil
local currentForceClose = nil

-- ─── BUILD CUTSCENE MODAL ─────────────────────────────────────────────────────
local function showOrderCutscene(payload)
    -- Destroy any existing modal first (also arms the old forceClose → safe)
    if currentForceClose then currentForceClose() end

    posGui.Enabled = true

    -- ── Backdrop ──
    local modal = Instance.new("Frame")
    modal.Name                    = "OrderModal"
    modal.Size                    = UDim2.new(0, 420, 0, 290)
    modal.Position                = UDim2.new(0.5, -210, 0.5, -145)
    modal.BackgroundColor3        = Color3.fromRGB(18, 18, 18)
    modal.BackgroundTransparency  = 0.08
    modal.BorderSizePixel         = 0
    modal.Parent                  = posGui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 14)
    corner.Parent       = modal

    -- ── Speech bubble ──
    local bubble = Instance.new("TextLabel")
    bubble.Name                   = "SpeechBubble"
    bubble.Size                   = UDim2.new(1, -20, 0, 90)
    bubble.Position               = UDim2.new(0, 10, 0, 14)
    bubble.BackgroundColor3       = Color3.fromRGB(255, 255, 255)
    bubble.BackgroundTransparency = 0.05
    bubble.TextColor3             = Color3.fromRGB(20, 20, 20)
    bubble.TextScaled             = true
    bubble.Font                   = Enum.Font.Gotham
    bubble.Text                   = string.format(
        '"%s says: I\'d like %d\xC3\x97 %s, please!"',
        payload.npcName, payload.packSize, payload.cookieName)
    bubble.TextWrapped            = true
    bubble.Parent                 = modal
    local bc = Instance.new("UICorner")
    bc.CornerRadius = UDim.new(0, 8)
    bc.Parent       = bubble

    -- ── Earnings card ──
    local earningsLines = {
        string.format("Base:  %d coins", payload.baseCoins),
    }
    if payload.isVIP then
        table.insert(earningsLines, "VIP Bonus:  \xC3\x97 1.75")
        table.insert(earningsLines, string.format(
            "Potential:  %d coins", math.floor(payload.baseCoins * 1.75)))
    end

    local earnings = Instance.new("TextLabel")
    earnings.Name                   = "EarningsCard"
    earnings.Size                   = UDim2.new(1, -20, 0, 100)
    earnings.Position               = UDim2.new(0, 10, 0, 114)
    earnings.BackgroundColor3       = payload.isVIP
        and Color3.fromRGB(255, 200, 0)
        or  Color3.fromRGB(50, 50, 50)
    earnings.BackgroundTransparency = 0.1
    earnings.TextColor3             = payload.isVIP
        and Color3.fromRGB(20, 20, 20)
        or  Color3.fromRGB(255, 255, 255)
    earnings.TextScaled             = true
    earnings.Font                   = Enum.Font.GothamBold
    earnings.Text                   = table.concat(earningsLines, "\n")
    earnings.TextWrapped            = true
    earnings.Parent                 = modal
    local ec = Instance.new("UICorner")
    ec.CornerRadius = UDim.new(0, 8)
    ec.Parent       = earnings

    -- ── Countdown label ──
    local countdown = Instance.new("TextLabel")
    countdown.Name                   = "Countdown"
    countdown.Size                   = UDim2.new(1, -80, 0, 26)
    countdown.Position               = UDim2.new(0, 10, 1, -34)
    countdown.BackgroundTransparency = 1
    countdown.TextColor3             = Color3.fromRGB(140, 140, 140)
    countdown.TextXAlignment         = Enum.TextXAlignment.Left
    countdown.TextScaled             = true
    countdown.Font                   = Enum.Font.Gotham
    countdown.Text                   = "Auto-dismissing in " .. AUTO_DISMISS_SECONDS .. "..."
    countdown.Parent                 = modal

    -- ── X button ──
    local closeBtn = Instance.new("TextButton")
    closeBtn.Name              = "CloseBtn"
    closeBtn.Size              = UDim2.new(0, 30, 0, 30)
    closeBtn.Position          = UDim2.new(1, -38, 0, 8)
    closeBtn.BackgroundColor3  = Color3.fromRGB(200, 55, 55)
    closeBtn.TextColor3        = Color3.fromRGB(255, 255, 255)
    closeBtn.Font              = Enum.Font.GothamBold
    closeBtn.TextScaled        = true
    closeBtn.Text              = "X"
    closeBtn.BorderSizePixel   = 0
    closeBtn.Parent            = modal
    local cc = Instance.new("UICorner")
    cc.CornerRadius = UDim.new(0, 6)
    cc.Parent       = closeBtn

    -- ── Dismiss helpers ──────────────────────────────────────────────────────
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

    -- ── 5-second auto-dismiss ──
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
    if state ~= "Open" then
        if currentForceClose then currentForceClose() end
        posGui.Enabled = false
    end
end)

-- Escape key: calls dismiss() directly via module-level ref (no :Fire() needed)
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.Escape then
        if currentDismiss then currentDismiss() end
    end
end)

print("[POSClient] Ready.")
