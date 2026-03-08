-- src/StarterPlayer/StarterPlayerScripts/Minigames/DressStationClient.client.lua
-- KDS display for Dress Station — v2
-- After selecting an order the player must physically walk to the matching warmer.

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
    pink_sugar           = "Pink Sugar",
    chocolate_chip       = "Choc Chip",
    birthday_cake        = "Bday Cake",
    cookies_and_cream    = "C&C",
    snickerdoodle        = "Snickerdoodle",
    lemon_blackraspberry = "Lemon Berry",
}

local COOKIE_COLOR = {
    pink_sugar           = Color3.fromRGB(255, 182, 193),
    chocolate_chip       = Color3.fromRGB(139, 90,  43),
    birthday_cake        = Color3.fromRGB(255, 220, 80),
    cookies_and_cream    = Color3.fromRGB(60,  60,  60),
    snickerdoodle        = Color3.fromRGB(205, 133, 63),
    lemon_blackraspberry = Color3.fromRGB(160, 40,  100),
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

local function closeKDS()
    local gui = playerGui:FindFirstChild("DressKDSGui")
    if gui then gui:Destroy() end
    setMovement(true)
end

local function destroyWarmerOverlay()
    local g = playerGui:FindFirstChild("DressWarmerGui")
    if g then g:Destroy() end
end

local function flashMsg(text, success)
    local sg = Instance.new("ScreenGui")
    sg.Name         = "DressFlash"
    sg.ResetOnSpawn = false
    sg.Parent       = playerGui
    local lbl = Instance.new("TextLabel", sg)
    lbl.Size             = UDim2.new(0, 360, 0, 60)
    lbl.Position         = UDim2.new(0.5, -180, 0.5, 80)
    lbl.BackgroundColor3 = success and Color3.fromRGB(50, 175, 75) or Color3.fromRGB(190, 60, 60)
    lbl.TextColor3       = Color3.fromRGB(255, 255, 255)
    lbl.TextScaled       = true
    lbl.Font             = Enum.Font.GothamBold
    lbl.Text             = text
    lbl.BorderSizePixel  = 0
    Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 12)
    game:GetService("Debris"):AddItem(sg, 3)
end

-- Persistent overlay while player walks to warmer
local function showWarmerOverlay(cookieName, cookieId)
    destroyWarmerOverlay()

    local sg = Instance.new("ScreenGui")
    sg.Name         = "DressWarmerGui"
    sg.ResetOnSpawn = false
    sg.Parent       = playerGui

    local bg = Instance.new("Frame", sg)
    bg.Size                   = UDim2.new(0, 360, 0, 70)
    bg.Position               = UDim2.new(0.5, -180, 1, -110)
    bg.BackgroundColor3       = Color3.fromRGB(20, 20, 20)
    bg.BackgroundTransparency = 0.1
    bg.BorderSizePixel        = 0
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 12)

    local arrow = Instance.new("TextLabel", bg)
    arrow.Size                   = UDim2.new(0, 40, 1, 0)
    arrow.BackgroundTransparency = 1
    arrow.TextColor3             = COOKIE_COLOR[cookieId] or Color3.fromRGB(255, 215, 60)
    arrow.TextScaled             = true
    arrow.Font                   = Enum.Font.GothamBold
    arrow.Text                   = "▶"

    local msg = Instance.new("TextLabel", bg)
    msg.Size                   = UDim2.new(1, -90, 1, 0)
    msg.Position               = UDim2.new(0, 40, 0, 0)
    msg.BackgroundTransparency = 1
    msg.TextColor3             = Color3.fromRGB(240, 240, 240)
    msg.TextScaled             = true
    msg.Font                   = Enum.Font.GothamBold
    msg.Text                   = "Pick up  " .. cookieName .. "  from warmer"
    msg.TextXAlignment         = Enum.TextXAlignment.Left

    -- Cancel button
    local cancelBtn = Instance.new("TextButton", bg)
    cancelBtn.Size             = UDim2.new(0, 40, 0, 34)
    cancelBtn.Position         = UDim2.new(1, -46, 0.5, -17)
    cancelBtn.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
    cancelBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
    cancelBtn.TextScaled       = true
    cancelBtn.Font             = Enum.Font.GothamBold
    cancelBtn.Text             = "✕"
    cancelBtn.BorderSizePixel  = 0
    Instance.new("UICorner", cancelBtn).CornerRadius = UDim.new(0, 8)
    cancelBtn.MouseButton1Click:Connect(function()
        cancelOrder:FireServer()
        destroyWarmerOverlay()
    end)
end

-- ─── KDS UI ───────────────────────────────────────────────────────────────────
local function showKDS(payload)
    if playerGui:FindFirstChild("DressKDSGui") then return end
    setMovement(false)

    local orders  = payload.orders  or {}
    local warmers = payload.warmers or {}

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

    local title = Instance.new("TextLabel", bg)
    title.Size                   = UDim2.new(1, -54, 0, 44)
    title.Position               = UDim2.new(0, 12, 0, 6)
    title.BackgroundTransparency = 1
    title.TextColor3             = Color3.fromRGB(255, 215, 60)
    title.TextScaled             = true
    title.Font                   = Enum.Font.GothamBold
    title.Text                   = "DRESS STATION"
    title.TextXAlignment         = Enum.TextXAlignment.Left

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
        closeKDS()
    end)

    local div = Instance.new("Frame", bg)
    div.Size             = UDim2.new(1, -20, 0, 2)
    div.Position         = UDim2.new(0, 10, 0, 54)
    div.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    div.BorderSizePixel  = 0

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

    for i, order in ipairs(orders) do
        local yOff     = 62 + (i - 1) * 94
        local cookId   = order.cookieId
        local hasStock = (warmers[cookId] or 0) > 0

        local row = Instance.new("Frame", bg)
        row.Size             = UDim2.new(1, -20, 0, 84)
        row.Position         = UDim2.new(0, 10, 0, yOff)
        row.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
        row.BorderSizePixel  = 0
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 10)

        local stripe = Instance.new("Frame", row)
        stripe.Size             = UDim2.new(0, 7, 1, 0)
        stripe.BackgroundColor3 = COOKIE_COLOR[cookId] or Color3.fromRGB(80, 80, 80)
        stripe.BorderSizePixel  = 0
        Instance.new("UICorner", stripe).CornerRadius = UDim.new(0, 10)

        local nl = Instance.new("TextLabel", row)
        nl.Size                   = UDim2.new(0, 210, 0, 28)
        nl.Position               = UDim2.new(0, 18, 0, 8)
        nl.BackgroundTransparency = 1
        nl.TextColor3             = Color3.fromRGB(240, 240, 240)
        nl.TextScaled             = true
        nl.Font                   = Enum.Font.GothamBold
        nl.Text                   = (order.isVIP and "⭐ " or "") .. order.npcName
        nl.TextXAlignment         = Enum.TextXAlignment.Left

        local cl = Instance.new("TextLabel", row)
        cl.Size                   = UDim2.new(0, 210, 0, 22)
        cl.Position               = UDim2.new(0, 18, 0, 36)
        cl.BackgroundTransparency = 1
        cl.TextColor3             = COOKIE_COLOR[cookId] or Color3.fromRGB(200, 200, 200)
        cl.TextScaled             = true
        cl.Font                   = Enum.Font.Gotham
        cl.Text                   = (COOKIE_DISPLAY[cookId] or cookId) .. "  ×" .. order.packSize
        cl.TextXAlignment         = Enum.TextXAlignment.Left

        local wl = Instance.new("TextLabel", row)
        wl.Size                   = UDim2.new(0, 210, 0, 18)
        wl.Position               = UDim2.new(0, 18, 0, 58)
        wl.BackgroundTransparency = 1
        wl.TextColor3             = timerColor(order.waitSeconds)
        wl.TextScaled             = true
        wl.Font                   = Enum.Font.Gotham
        wl.Text                   = "Waiting: " .. formatWait(order.waitSeconds)
        wl.TextXAlignment         = Enum.TextXAlignment.Left

        local pb = Instance.new("TextButton", row)
        pb.Size             = UDim2.new(0, 126, 0, 56)
        pb.Position         = UDim2.new(1, -138, 0.5, -28)
        pb.BackgroundColor3 = hasStock and Color3.fromRGB(50, 175, 75) or Color3.fromRGB(50, 50, 50)
        pb.TextColor3       = hasStock and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(90, 90, 90)
        pb.TextScaled       = true
        pb.Font             = Enum.Font.GothamBold
        pb.Text             = hasStock and "TAKE ORDER" or "NO STOCK"
        pb.Active           = hasStock
        pb.BorderSizePixel  = 0
        Instance.new("UICorner", pb).CornerRadius = UDim.new(0, 10)

        if hasStock then
            pb.MouseButton1Click:Connect(function()
                for _, btn in ipairs(bg:GetDescendants()) do
                    if btn:IsA("TextButton") and btn.Text == "TAKE ORDER" then
                        btn.Active = false
                        btn.BackgroundColor3 = Color3.fromRGB(40, 120, 55)
                        btn.Text = "Confirmed!"
                    end
                end
                lockOrder:FireServer(order.orderId)
            end)
        end
    end
end

-- ─── Event Handlers ───────────────────────────────────────────────────────────
kdsUpdate.OnClientEvent:Connect(showKDS)

orderLocked.OnClientEvent:Connect(function(result)
    local state = result.state

    if state == "locked" then
        -- Player selected an order — close KDS, show warmer direction overlay
        closeKDS()
        showWarmerOverlay(result.cookieName or "cookie", result.cookieId)

    elseif state == "done" then
        -- Player picked up from warmer — box created
        destroyWarmerOverlay()
        flashMsg("Box #" .. (result.boxId or "?") .. " ready!  Deliver to the customer.", true)

    elseif state == "error" then
        destroyWarmerOverlay()
        closeKDS()
        flashMsg(result.message or "Something went wrong", false)
    end
end)

print("[DressStationClient] Ready — KDS v2.")
