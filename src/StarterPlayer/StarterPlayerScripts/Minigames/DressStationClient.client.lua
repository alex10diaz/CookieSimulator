-- src/StarterPlayer/StarterPlayerScripts/Minigames/DressStationClient.client.lua
-- KDS display for Dress Station. Player sees top-3 NPC orders and picks one to pack.
-- Replaces the old Keep/Toss card game (DressMinigame.client.lua).

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local kdsUpdate     = RemoteManager.Get("DressKDSUpdate")
local lockOrder     = RemoteManager.Get("DressLockOrder")
local orderLocked   = RemoteManager.Get("DressOrderLocked")
local cancelOrder   = RemoteManager.Get("DressCancelOrder")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ─── Constants ────────────────────────────────────────────────────────────────
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
    chocolate_chip        = Color3.fromRGB(139, 90,  43),
    birthday_cake         = Color3.fromRGB(255, 220, 80),
    cookies_and_cream     = Color3.fromRGB(60,  60,  60),
    snickerdoodle         = Color3.fromRGB(205, 133, 63),
    lemon_blackraspberry  = Color3.fromRGB(160, 40,  100),
}

-- ─── Helpers ──────────────────────────────────────────────────────────────────
local function timerColor(secs)
    if secs < 120 then return Color3.fromRGB(80, 200, 80)
    elseif secs < 240 then return Color3.fromRGB(255, 185, 50)
    else return Color3.fromRGB(210, 70, 70) end
end

local function formatWait(secs)
    local m = math.floor(secs / 60)
    return m > 0 and string.format("%dm %02ds", m, secs % 60) or string.format("%ds", secs)
end

local function setMovement(on)
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    hum.WalkSpeed  = on and 16 or 0
    hum.JumpHeight = on and 7.2 or 0
end

local function closeUI()
    local gui = playerGui:FindFirstChild("DressKDSGui")
    if gui then gui:Destroy() end
    setMovement(true)
end

local function flashMsg(text, success)
    local sg = Instance.new("ScreenGui")
    sg.Name         = "DressFlash"
    sg.ResetOnSpawn = false
    sg.Parent       = playerGui

    local lbl = Instance.new("TextLabel", sg)
    lbl.Size             = UDim2.new(0, 340, 0, 60)
    lbl.Position         = UDim2.new(0.5, -170, 0.5, 80)
    lbl.BackgroundColor3 = success and Color3.fromRGB(50, 175, 75) or Color3.fromRGB(190, 60, 60)
    lbl.TextColor3       = Color3.fromRGB(255, 255, 255)
    lbl.TextScaled       = true
    lbl.Font             = Enum.Font.GothamBold
    lbl.Text             = text
    lbl.BorderSizePixel  = 0
    Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 12)
    game:GetService("Debris"):AddItem(sg, 3)
end

-- ─── KDS UI ───────────────────────────────────────────────────────────────────
local function showKDS(payload)
    if playerGui:FindFirstChild("DressKDSGui") then return end
    setMovement(false)

    local orders  = payload.orders  or {}
    local warmers = payload.warmers or {}

    -- Panel height scales with number of orders
    local panelH = 80 + (#orders * 94) + 16
    if #orders == 0 then panelH = 180 end

    local sg = Instance.new("ScreenGui")
    sg.Name           = "DressKDSGui"
    sg.ResetOnSpawn   = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent         = playerGui

    local bg = Instance.new("Frame", sg)
    bg.Size                   = UDim2.new(0, 430, 0, panelH)
    bg.Position               = UDim2.new(0.5, -215, 0.5, -panelH / 2)
    bg.BackgroundColor3       = Color3.fromRGB(18, 18, 18)
    bg.BackgroundTransparency = 0.05
    bg.BorderSizePixel        = 0
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 14)

    -- Title
    local title = Instance.new("TextLabel", bg)
    title.Size                   = UDim2.new(1, -54, 0, 44)
    title.Position               = UDim2.new(0, 12, 0, 6)
    title.BackgroundTransparency = 1
    title.TextColor3             = Color3.fromRGB(255, 215, 60)
    title.TextScaled             = true
    title.Font                   = Enum.Font.GothamBold
    title.Text                   = "DRESS STATION"
    title.TextXAlignment         = Enum.TextXAlignment.Left

    -- Close button
    local closeBtn = Instance.new("TextButton", bg)
    closeBtn.Size             = UDim2.new(0, 36, 0, 36)
    closeBtn.Position         = UDim2.new(1, -44, 0, 7)
    closeBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
    closeBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
    closeBtn.TextScaled       = true
    closeBtn.Font             = Enum.Font.GothamBold
    closeBtn.Text             = "X"
    closeBtn.BorderSizePixel  = 0
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)
    closeBtn.MouseButton1Click:Connect(function()
        cancelOrder:FireServer()
        closeUI()
    end)

    -- Divider
    local div = Instance.new("Frame", bg)
    div.Size             = UDim2.new(1, -20, 0, 2)
    div.Position         = UDim2.new(0, 10, 0, 54)
    div.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    div.BorderSizePixel  = 0

    -- Empty state
    if #orders == 0 then
        local empty = Instance.new("TextLabel", bg)
        empty.Size                   = UDim2.new(1, 0, 0, 80)
        empty.Position               = UDim2.new(0, 0, 0, 60)
        empty.BackgroundTransparency = 1
        empty.TextColor3             = Color3.fromRGB(120, 120, 120)
        empty.TextScaled             = true
        empty.Font                   = Enum.Font.Gotham
        empty.Text                   = "No orders waiting"
        return
    end

    -- Order rows
    for i, order in ipairs(orders) do
        local yOff    = 62 + (i - 1) * 94
        local cookId  = order.cookieId
        local hasStock = (warmers[cookId] or 0) > 0

        local row = Instance.new("Frame", bg)
        row.Size             = UDim2.new(1, -20, 0, 84)
        row.Position         = UDim2.new(0, 10, 0, yOff)
        row.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
        row.BorderSizePixel  = 0
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 10)

        -- Cookie stripe
        local stripe = Instance.new("Frame", row)
        stripe.Size             = UDim2.new(0, 7, 1, 0)
        stripe.BackgroundColor3 = COOKIE_COLOR[cookId] or Color3.fromRGB(80, 80, 80)
        stripe.BorderSizePixel  = 0
        Instance.new("UICorner", stripe).CornerRadius = UDim.new(0, 10)

        -- NPC name
        local npcLbl = Instance.new("TextLabel", row)
        npcLbl.Size                   = UDim2.new(0, 210, 0, 28)
        npcLbl.Position               = UDim2.new(0, 18, 0, 8)
        npcLbl.BackgroundTransparency = 1
        npcLbl.TextColor3             = Color3.fromRGB(240, 240, 240)
        npcLbl.TextScaled             = true
        npcLbl.Font                   = Enum.Font.GothamBold
        npcLbl.Text                   = (order.isVIP and "⭐ " or "") .. order.npcName
        npcLbl.TextXAlignment         = Enum.TextXAlignment.Left

        -- Cookie name + count
        local cookLbl = Instance.new("TextLabel", row)
        cookLbl.Size                   = UDim2.new(0, 210, 0, 22)
        cookLbl.Position               = UDim2.new(0, 18, 0, 36)
        cookLbl.BackgroundTransparency = 1
        cookLbl.TextColor3             = COOKIE_COLOR[cookId] or Color3.fromRGB(200, 200, 200)
        cookLbl.TextScaled             = true
        cookLbl.Font                   = Enum.Font.Gotham
        cookLbl.Text                   = (COOKIE_DISPLAY[cookId] or cookId) .. "  ×" .. order.packSize
        cookLbl.TextXAlignment         = Enum.TextXAlignment.Left

        -- Wait time
        local waitLbl = Instance.new("TextLabel", row)
        waitLbl.Size                   = UDim2.new(0, 210, 0, 18)
        waitLbl.Position               = UDim2.new(0, 18, 0, 58)
        waitLbl.BackgroundTransparency = 1
        waitLbl.TextColor3             = timerColor(order.waitSeconds)
        waitLbl.TextScaled             = true
        waitLbl.Font                   = Enum.Font.Gotham
        waitLbl.Text                   = "Waiting: " .. formatWait(order.waitSeconds)
        waitLbl.TextXAlignment         = Enum.TextXAlignment.Left

        -- Pack button
        local packBtn = Instance.new("TextButton", row)
        packBtn.Size             = UDim2.new(0, 126, 0, 56)
        packBtn.Position         = UDim2.new(1, -138, 0.5, -28)
        packBtn.BackgroundColor3 = hasStock and Color3.fromRGB(50, 175, 75) or Color3.fromRGB(50, 50, 50)
        packBtn.TextColor3       = hasStock and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(90, 90, 90)
        packBtn.TextScaled       = true
        packBtn.Font             = Enum.Font.GothamBold
        packBtn.Text             = hasStock and "PACK IT" or "NO STOCK"
        packBtn.Active           = hasStock
        packBtn.BorderSizePixel  = 0
        Instance.new("UICorner", packBtn).CornerRadius = UDim.new(0, 10)

        if hasStock then
            packBtn.MouseButton1Click:Connect(function()
                -- Disable all pack buttons immediately to prevent double-firing
                for _, btn in ipairs(bg:GetDescendants()) do
                    if btn:IsA("TextButton") and btn.Text == "PACK IT" then
                        btn.Active           = false
                        btn.BackgroundColor3 = Color3.fromRGB(40, 120, 55)
                        btn.Text             = "Packing..."
                    end
                end
                lockOrder:FireServer(order.orderId)
            end)
        end
    end
end

-- ─── Event Connections ────────────────────────────────────────────────────────
kdsUpdate.OnClientEvent:Connect(showKDS)

orderLocked.OnClientEvent:Connect(function(result)
    closeUI()
    if result.success then
        flashMsg("Box #" .. (result.boxId or "?") .. " ready!  Deliver to the customer.", true)
    else
        flashMsg(result.message or "Could not pack order", false)
    end
end)

print("[DressStationClient] Ready — KDS mode active.")
