-- src/StarterPlayer/StarterPlayerScripts/Minigames/DressStationClient.client.lua
-- KDS display for Dress Station — v2 (M7 Polish)

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local kdsUpdate     = RemoteManager.Get("DressKDSUpdate")
local lockOrder     = RemoteManager.Get("DressLockOrder")
local orderLocked   = RemoteManager.Get("DressOrderLocked")
local cancelOrder   = RemoteManager.Get("DressCancelOrder")
local startToppingRemote    = RemoteManager.Get("StartToppingMinigame")
local toppingCompleteRemote = RemoteManager.Get("ToppingComplete")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ─── Constants ────────────────────────────────────────────────────────────────
local ACCENT = Color3.fromRGB(255, 200, 0)   -- gold

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

local function destroyToppingGui()
    local g = playerGui:FindFirstChild("ToppingMinigameGui")
    if g then g:Destroy() end
end

-- ─── Gold header bar helper ────────────────────────────────────────────────────
local function makeHeaderBar(parent, h, titleText)
    local bar = Instance.new("Frame", parent)
    bar.Name             = "HeaderBar"
    bar.Size             = UDim2.new(1, 0, 0, h)
    bar.BackgroundColor3 = ACCENT
    bar.BorderSizePixel  = 0
    Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 14)
    local flat = Instance.new("Frame", bar)
    flat.Size             = UDim2.new(1, 0, 0.5, 0)
    flat.Position         = UDim2.new(0, 0, 0.5, 0)
    flat.BackgroundColor3 = ACCENT
    flat.BorderSizePixel  = 0
    local lbl = Instance.new("TextLabel", bar)
    lbl.Size                   = UDim2.new(1, -56, 1, 0)
    lbl.Position               = UDim2.new(0, 14, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3             = Color3.fromRGB(20, 14, 4)
    lbl.TextScaled             = true
    lbl.Font                   = Enum.Font.GothamBold
    lbl.Text                   = titleText
    lbl.TextXAlignment         = Enum.TextXAlignment.Left
    return bar
end

-- ─── Topping Minigame ─────────────────────────────────────────────────────────
local TAP_TARGET = 20

local function showToppingMinigame(data)
    destroyWarmerOverlay()
    destroyToppingGui()
    setMovement(false)

    local label    = data.label or "Add Toppings"
    local barColor = data.toppingColor or Color3.fromRGB(220, 180, 80)

    local startTime    = tick()
    local tapCount     = 0
    local fillFraction = 0
    local completed    = false

    local sg = Instance.new("ScreenGui")
    sg.Name           = "ToppingMinigameGui"
    sg.ResetOnSpawn   = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.DisplayOrder   = 22
    sg.Parent         = playerGui

    local bg = Instance.new("Frame", sg)
    bg.Size                   = UDim2.new(0, 400, 0, 200)
    bg.Position               = UDim2.new(0.5, -200, 0.5, -100)
    bg.BackgroundColor3       = Color3.fromRGB(15, 30, 60)
    bg.BackgroundTransparency = 0
    bg.BorderSizePixel        = 0
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 16)
    local bgStroke = Instance.new("UIStroke", bg)
    bgStroke.Color     = barColor
    bgStroke.Thickness = 2

    -- Header bar (uses barColor as accent)
    local headerBar = Instance.new("Frame", bg)
    headerBar.Size             = UDim2.new(1, 0, 0, 44)
    headerBar.BackgroundColor3 = barColor
    headerBar.BorderSizePixel  = 0
    Instance.new("UICorner", headerBar).CornerRadius = UDim.new(0, 16)
    local hFlat = Instance.new("Frame", headerBar)
    hFlat.Size             = UDim2.new(1, 0, 0.5, 0)
    hFlat.Position         = UDim2.new(0, 0, 0.5, 0)
    hFlat.BackgroundColor3 = barColor
    hFlat.BorderSizePixel  = 0
    local headerLbl = Instance.new("TextLabel", headerBar)
    headerLbl.Size                   = UDim2.new(1, -14, 1, 0)
    headerLbl.Position               = UDim2.new(0, 14, 0, 0)
    headerLbl.BackgroundTransparency = 1
    headerLbl.TextColor3             = Color3.fromRGB(20, 14, 4)
    headerLbl.TextScaled             = true
    headerLbl.Font                   = Enum.Font.GothamBold
    headerLbl.Text                   = "ADD TOPPINGS  —  " .. label
    headerLbl.TextXAlignment         = Enum.TextXAlignment.Left

    -- Progress bar
    local barBg = Instance.new("Frame", bg)
    barBg.Size             = UDim2.new(1, -24, 0, 22)
    barBg.Position         = UDim2.new(0, 12, 0, 54)
    barBg.BackgroundColor3 = Color3.fromRGB(22, 22, 42)
    barBg.BorderSizePixel  = 0
    Instance.new("UICorner", barBg).CornerRadius = UDim.new(0, 6)
    local barFillStroke = Instance.new("UIStroke", barBg)
    barFillStroke.Color     = Color3.fromRGB(40, 40, 70)
    barFillStroke.Thickness = 1

    local barFill = Instance.new("Frame", barBg)
    barFill.Size             = UDim2.new(0, 0, 1, 0)
    barFill.BackgroundColor3 = barColor
    barFill.BorderSizePixel  = 0
    Instance.new("UICorner", barFill).CornerRadius = UDim.new(0, 6)

    local pctLbl = Instance.new("TextLabel", bg)
    pctLbl.Size                   = UDim2.new(1, -24, 0, 18)
    pctLbl.Position               = UDim2.new(0, 12, 0, 80)
    pctLbl.BackgroundTransparency = 1
    pctLbl.TextColor3             = Color3.fromRGB(160, 160, 190)
    pctLbl.TextScaled             = true
    pctLbl.Font                   = Enum.Font.Gotham
    pctLbl.Text                   = "0%"
    pctLbl.TextXAlignment         = Enum.TextXAlignment.Right

    local timerLbl = Instance.new("TextLabel", bg)
    timerLbl.Size                   = UDim2.new(1, -24, 0, 18)
    timerLbl.Position               = UDim2.new(0, 12, 0, 100)
    timerLbl.BackgroundTransparency = 1
    timerLbl.TextColor3             = Color3.fromRGB(130, 200, 130)
    timerLbl.TextScaled             = true
    timerLbl.Font                   = Enum.Font.Gotham
    timerLbl.Text                   = "0.0s"
    timerLbl.TextXAlignment         = Enum.TextXAlignment.Right

    -- Large tap button
    local tapBtn = Instance.new("TextButton", bg)
    tapBtn.Size                   = UDim2.new(1, -24, 0, 68)
    tapBtn.Position               = UDim2.new(0, 12, 0, 124)
    tapBtn.BackgroundColor3       = Color3.fromRGB(22, 22, 44)
    tapBtn.BackgroundTransparency = 0
    tapBtn.TextColor3             = Color3.fromRGB(255, 215, 80)
    tapBtn.Font                   = Enum.Font.GothamBold
    tapBtn.TextScaled             = true
    tapBtn.Text                   = "TAP!"
    tapBtn.BorderSizePixel        = 0
    tapBtn.ZIndex                 = 5
    Instance.new("UICorner", tapBtn).CornerRadius = UDim.new(0, 10)
    local tapStroke = Instance.new("UIStroke", tapBtn)
    tapStroke.Color     = barColor
    tapStroke.Thickness = 1.5

    local function complete()
        if completed then return end
        completed = true
        tapBtn.Active = false
        local elapsed = tick() - startTime

        local rating = elapsed <= 2 and "Perfect!" or (elapsed <= 4 and "Good!" or "OK")
        local flashLbl = Instance.new("TextLabel", bg)
        flashLbl.Size                   = UDim2.new(1, 0, 1, 0)
        flashLbl.BackgroundColor3       = Color3.fromRGB(15, 30, 60)
        flashLbl.BackgroundTransparency = 0
        flashLbl.TextColor3             = Color3.fromRGB(255, 255, 255)
        flashLbl.Font                   = Enum.Font.GothamBold
        flashLbl.TextScaled             = true
        flashLbl.Text                   = rating .. string.format("  %.1fs", elapsed)
        flashLbl.ZIndex                 = 10
        flashLbl.BorderSizePixel        = 0
        Instance.new("UICorner", flashLbl).CornerRadius = UDim.new(0, 16)

        toppingCompleteRemote:FireServer(elapsed)

        task.delay(1.2, function()
            destroyToppingGui()
            setMovement(true)
        end)
    end

    local function onTap()
        if completed then return end
        tapCount     += 1
        fillFraction  = math.min(1, tapCount / TAP_TARGET)
        barFill.Size  = UDim2.new(fillFraction, 0, 1, 0)
        pctLbl.Text   = math.floor(fillFraction * 100) .. "%"
        if fillFraction >= 1 then complete() end
    end

    tapBtn.MouseButton1Click:Connect(onTap)

    local RunService = game:GetService("RunService")
    local heartbeatConn
    heartbeatConn = RunService.Heartbeat:Connect(function()
        if completed then heartbeatConn:Disconnect(); return end
        if not sg.Parent then heartbeatConn:Disconnect(); return end
        timerLbl.Text = string.format("%.1fs", tick() - startTime)
    end)
end

-- ─── Flash message ────────────────────────────────────────────────────────────
local function flashMsg(text, success)
    local sg = Instance.new("ScreenGui")
    sg.Name         = "DressFlash"
    sg.ResetOnSpawn = false
    sg.DisplayOrder = 22
    sg.Parent       = playerGui
    local lbl = Instance.new("TextLabel", sg)
    lbl.Size             = UDim2.new(0, 380, 0, 60)
    lbl.Position         = UDim2.new(0.5, -190, 0.5, 80)
    lbl.BackgroundColor3 = success and Color3.fromRGB(20, 60, 24) or Color3.fromRGB(60, 14, 14)
    lbl.TextColor3       = Color3.fromRGB(255, 255, 255)
    lbl.TextScaled       = true
    lbl.Font             = Enum.Font.GothamBold
    lbl.Text             = text
    lbl.BorderSizePixel  = 0
    Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 12)
    local s = Instance.new("UIStroke", lbl)
    s.Color     = success and Color3.fromRGB(50, 185, 75) or Color3.fromRGB(200, 55, 55)
    s.Thickness = 1.5
    game:GetService("Debris"):AddItem(sg, 3)
end

-- ─── Warmer Overlay ───────────────────────────────────────────────────────────
local function showWarmerOverlay(cookieName, cookieId, step, total)
    destroyWarmerOverlay()

    local cookColor = COOKIE_COLOR[cookieId] or ACCENT

    local sg = Instance.new("ScreenGui")
    sg.Name         = "DressWarmerGui"
    sg.ResetOnSpawn = false
    sg.DisplayOrder = 22
    sg.Parent       = playerGui

    local bg = Instance.new("Frame", sg)
    bg.Size                   = UDim2.new(0, 420, 0, 70)
    bg.Position               = UDim2.new(0.5, -210, 1, -110)
    bg.BackgroundColor3       = Color3.fromRGB(15, 30, 60)
    bg.BackgroundTransparency = 0
    bg.BorderSizePixel        = 0
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 12)
    local bgStroke = Instance.new("UIStroke", bg)
    bgStroke.Color     = cookColor
    bgStroke.Thickness = 1.5

    -- Left cookie color stripe
    local stripe = Instance.new("Frame", bg)
    stripe.Size             = UDim2.new(0, 5, 1, -10)
    stripe.Position         = UDim2.new(0, 6, 0, 5)
    stripe.BackgroundColor3 = cookColor
    stripe.BorderSizePixel  = 0
    Instance.new("UICorner", stripe).CornerRadius = UDim.new(0, 3)

    local prefix = (step and total and total > 1) and (step .. " of " .. total .. " — ") or ""
    local msg = Instance.new("TextLabel", bg)
    msg.Size                   = UDim2.new(1, -66, 1, 0)
    msg.Position               = UDim2.new(0, 18, 0, 0)
    msg.BackgroundTransparency = 1
    msg.TextColor3             = Color3.fromRGB(230, 230, 245)
    msg.TextScaled             = true
    msg.Font                   = Enum.Font.GothamBold
    msg.Text                   = prefix .. "Pick up  " .. cookieName .. "  from warmer"
    msg.TextXAlignment         = Enum.TextXAlignment.Left

    local cancelBtn = Instance.new("TextButton", bg)
    cancelBtn.Size             = UDim2.new(0, 40, 0, 34)
    cancelBtn.Position         = UDim2.new(1, -46, 0.5, -17)
    cancelBtn.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
    cancelBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
    cancelBtn.TextScaled       = true
    cancelBtn.Font             = Enum.Font.GothamBold
    cancelBtn.Text             = "X"
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

    local panelH = 70 + (#orders * 94) + 16
    if #orders == 0 then panelH = 180 end

    local sg = Instance.new("ScreenGui")
    sg.Name           = "DressKDSGui"
    sg.ResetOnSpawn   = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.DisplayOrder   = 22
    sg.Parent         = playerGui

    local bg = Instance.new("Frame", sg)
    bg.Size                   = UDim2.new(0, 450, 0, panelH)
    bg.Position               = UDim2.new(0.5, -225, 0.5, -panelH / 2)
    bg.BackgroundColor3       = Color3.fromRGB(15, 30, 60)
    bg.BackgroundTransparency = 0
    bg.BorderSizePixel        = 0
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 16)
    local bgStroke = Instance.new("UIStroke", bg)
    bgStroke.Color     = ACCENT
    bgStroke.Thickness = 1.5

    -- Gold header bar
    local headerBar = makeHeaderBar(bg, 46, "DRESS STATION")

    -- X close button
    local closeBtn = Instance.new("TextButton", bg)
    closeBtn.Size             = UDim2.new(0, 30, 0, 30)
    closeBtn.Position         = UDim2.new(1, -38, 0, 8)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 55, 55)
    closeBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
    closeBtn.TextScaled       = true
    closeBtn.Font             = Enum.Font.GothamBold
    closeBtn.Text             = "X"
    closeBtn.BorderSizePixel  = 0
    closeBtn.ZIndex           = 5
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(1, 0)
    closeBtn.MouseButton1Click:Connect(function()
        cancelOrder:FireServer()
        closeKDS()
    end)

    if #orders == 0 then
        local empty = Instance.new("TextLabel", bg)
        empty.Size                   = UDim2.new(1, 0, 0, 80)
        empty.Position               = UDim2.new(0, 0, 0, 52)
        empty.BackgroundTransparency = 1
        empty.TextColor3             = Color3.fromRGB(80, 80, 110)
        empty.TextScaled             = true
        empty.Font                   = Enum.Font.Gotham
        empty.Text                   = "No orders waiting"
        return
    end

    for i, order in ipairs(orders) do
        local yOff   = 54 + (i - 1) * 94
        local cookId = order.cookieId
        local hasStock
        if order.isVariety and order.items then
            hasStock = true
            local seen = {}
            for _, id in ipairs(order.items) do
                if not seen[id] then
                    seen[id] = true
                    if (warmers[id] or 0) == 0 then hasStock = false; break end
                end
            end
        else
            hasStock = (warmers[cookId] or 0) > 0
        end

        local row = Instance.new("Frame", bg)
        row.Size             = UDim2.new(1, -20, 0, 84)
        row.Position         = UDim2.new(0, 10, 0, yOff)
        row.BackgroundColor3 = Color3.fromRGB(20, 20, 40)
        row.BorderSizePixel  = 0
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 10)
        local rowStroke = Instance.new("UIStroke", row)
        rowStroke.Color     = Color3.fromRGB(40, 40, 70)
        rowStroke.Thickness = 1

        local stripe = Instance.new("Frame", row)
        stripe.Size             = UDim2.new(0, 6, 1, 0)
        stripe.BackgroundColor3 = COOKIE_COLOR[cookId] or Color3.fromRGB(80, 80, 80)
        stripe.BorderSizePixel  = 0
        Instance.new("UICorner", stripe).CornerRadius = UDim.new(0, 10)

        local nl = Instance.new("TextLabel", row)
        nl.Size                   = UDim2.new(0, 220, 0, 28)
        nl.Position               = UDim2.new(0, 18, 0, 8)
        nl.BackgroundTransparency = 1
        nl.TextColor3             = Color3.fromRGB(230, 230, 245)
        nl.TextScaled             = true
        nl.Font                   = Enum.Font.GothamBold
        nl.Text                   = (order.isVIP and "★ " or "") .. order.npcName
        nl.TextXAlignment         = Enum.TextXAlignment.Left

        local cl = Instance.new("TextLabel", row)
        cl.Size                   = UDim2.new(0, 220, 0, 22)
        cl.Position               = UDim2.new(0, 18, 0, 36)
        cl.BackgroundTransparency = 1
        cl.TextColor3             = COOKIE_COLOR[cookId] or Color3.fromRGB(190, 190, 200)
        cl.TextScaled             = true
        cl.Font                   = Enum.Font.Gotham
        cl.TextXAlignment         = Enum.TextXAlignment.Left
        if order.isVariety and order.items then
            local grouped, typeOrder = {}, {}
            for _, id in ipairs(order.items) do
                if not grouped[id] then grouped[id] = 0; table.insert(typeOrder, id) end
                grouped[id] += 1
            end
            local parts = {}
            for _, id in ipairs(typeOrder) do
                local d = COOKIE_DISPLAY[id] or id
                table.insert(parts, grouped[id] > 1 and (d .. "x" .. grouped[id]) or d)
            end
            cl.Text      = table.concat(parts, " · ")
            cl.TextColor3 = Color3.fromRGB(170, 170, 200)
        else
            cl.Text = (COOKIE_DISPLAY[cookId] or cookId) .. "  x" .. order.packSize
        end

        local wl = Instance.new("TextLabel", row)
        wl.Size                   = UDim2.new(0, 220, 0, 18)
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
        pb.BackgroundColor3 = hasStock and Color3.fromRGB(30, 100, 40) or Color3.fromRGB(22, 22, 40)
        pb.TextColor3       = hasStock and Color3.fromRGB(200, 255, 200) or Color3.fromRGB(60, 60, 80)
        pb.TextScaled       = true
        pb.Font             = Enum.Font.GothamBold
        pb.Text             = hasStock and "TAKE ORDER" or "NO STOCK"
        pb.Active           = hasStock
        pb.BorderSizePixel  = 0
        Instance.new("UICorner", pb).CornerRadius = UDim.new(0, 10)
        local pbStroke = Instance.new("UIStroke", pb)
        pbStroke.Color     = hasStock and Color3.fromRGB(50, 185, 75) or Color3.fromRGB(40, 40, 65)
        pbStroke.Thickness = 1.5

        if hasStock then
            pb.MouseButton1Click:Connect(function()
                for _, btn in ipairs(bg:GetDescendants()) do
                    if btn:IsA("TextButton") and btn.Text == "TAKE ORDER" then
                        btn.Active           = false
                        btn.BackgroundColor3 = Color3.fromRGB(25, 70, 30)
                        btn.Text             = "Confirmed!"
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
        closeKDS()
        showWarmerOverlay(result.cookieName or "cookie", result.cookieId, result.step, result.total)

    elseif state == "progress" then
        showWarmerOverlay(result.cookieName or "cookie", result.cookieId, result.step, result.total)

    elseif state == "done" then
        destroyWarmerOverlay()
        flashMsg("Box #" .. (result.boxId or "?") .. " ready!  Deliver to the customer.", true)

    elseif state == "error" then
        destroyWarmerOverlay()
        closeKDS()
        flashMsg(result.message or "Something went wrong", false)
    end
end)

startToppingRemote.OnClientEvent:Connect(function(data)
    showToppingMinigame(data)
end)

print("[DressStationClient] Ready — KDS v2.")
