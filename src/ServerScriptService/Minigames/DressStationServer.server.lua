-- src/ServerScriptService/Minigames/DressStationServer.server.lua
-- KDS Dress Station — v2
-- Changes from v1:
--   • Dress TV SurfaceGui shows live order queue, refreshes every 5s
--   • Order lock no longer creates the box immediately;
--     player must physically walk to the matching warmer to pick up cookies

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

local RemoteManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local OrderManager  = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("OrderManager"))

local kdsUpdate   = RemoteManager.Get("DressKDSUpdate")
local lockOrder   = RemoteManager.Get("DressLockOrder")
local orderLocked = RemoteManager.Get("DressOrderLocked")
local cancelOrder = RemoteManager.Get("DressCancelOrder")

-- ─── State ────────────────────────────────────────────────────────────────────
local activeKDS   = {}  -- player -> true  (KDS UI is open)
local dressLocked = {}  -- player -> { orderId, cookieId, npcName }

local DRESS_SCORE = 85

local COOKIE_NAMES = {
    pink_sugar           = "Pink Sugar",
    chocolate_chip       = "Choc Chip",
    birthday_cake        = "Bday Cake",
    cookies_and_cream    = "C&C",
    snickerdoodle        = "Snickerdoodle",
    lemon_blackraspberry = "Lemon Berry",
}

local COOKIE_COLORS = {
    pink_sugar           = Color3.fromRGB(255, 182, 193),
    chocolate_chip       = Color3.fromRGB(139, 90,  43),
    birthday_cake        = Color3.fromRGB(255, 220, 80),
    cookies_and_cream    = Color3.fromRGB(200, 200, 200),
    snickerdoodle        = Color3.fromRGB(205, 133, 63),
    lemon_blackraspberry = Color3.fromRGB(160, 40,  100),
}

-- ─── TV Display ───────────────────────────────────────────────────────────────
local tvSurfaceGui = nil

local function formatWait(secs)
    local m = math.floor(secs / 60)
    return m > 0 and string.format("%dm %02ds", m, secs % 60) or string.format("%ds", secs)
end

local function timerColor(secs)
    if secs < 120 then return Color3.fromRGB(80, 210, 80)
    elseif secs < 240 then return Color3.fromRGB(255, 185, 50)
    else return Color3.fromRGB(210, 70, 70) end
end

local function getOrCreateTVGui()
    if tvSurfaceGui and tvSurfaceGui.Parent then return tvSurfaceGui end
    local dressMdl  = Workspace:FindFirstChild("Dress")
    local tvMdl     = dressMdl and dressMdl:FindFirstChild("Dress TV")
    local tvPart    = tvMdl    and tvMdl:FindFirstChild("Dress TV")
    if not tvPart then warn("[DressStation] Dress TV Part not found"); return nil end

    local old = tvPart:FindFirstChild("KDSDisplay")
    if old then old:Destroy() end

    local sg = Instance.new("SurfaceGui")
    sg.Name          = "KDSDisplay"
    sg.Face          = Enum.NormalId.Right   -- faces toward player area
    sg.PixelsPerStud = 40
    sg.SizingMode    = Enum.SurfaceGuiSizingMode.PixelsPerStud
    sg.AlwaysOnTop   = false
    sg.Parent        = tvPart

    tvSurfaceGui = sg
    return sg
end

local function updateTV()
    local sg = getOrCreateTVGui()
    if not sg then return end

    -- Clear
    for _, c in ipairs(sg:GetChildren()) do c:Destroy() end

    local orders = OrderManager.GetNPCOrders()
    local now    = tick()

    -- Root background
    local bg = Instance.new("Frame", sg)
    bg.Size             = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
    bg.BorderSizePixel  = 0

    -- Title bar
    local titleBar = Instance.new("Frame", bg)
    titleBar.Size             = UDim2.new(1, 0, 0, 52)
    titleBar.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    titleBar.BorderSizePixel  = 0

    local titleLbl = Instance.new("TextLabel", titleBar)
    titleLbl.Size                   = UDim2.new(1, -16, 1, 0)
    titleLbl.Position               = UDim2.new(0, 16, 0, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.TextColor3             = Color3.fromRGB(255, 215, 60)
    titleLbl.TextScaled             = true
    titleLbl.Font                   = Enum.Font.GothamBold
    titleLbl.Text                   = "ORDER QUEUE"
    titleLbl.TextXAlignment         = Enum.TextXAlignment.Left

    if #orders == 0 then
        local empty = Instance.new("TextLabel", bg)
        empty.Size                   = UDim2.new(1, 0, 1, -52)
        empty.Position               = UDim2.new(0, 0, 0, 52)
        empty.BackgroundTransparency = 1
        empty.TextColor3             = Color3.fromRGB(60, 60, 70)
        empty.TextScaled             = true
        empty.Font                   = Enum.Font.Gotham
        empty.Text                   = "No orders waiting"
        return
    end

    -- Row height split remaining space across up to 3 orders
    -- TV face: 23.70 * 40 = 948 px wide, 6.44 * 40 = 258 px tall
    local numRows = math.min(3, #orders)
    local rowH    = math.floor((258 - 52) / numRows)

    for i = 1, numRows do
        local o       = orders[i]
        local yOff    = 52 + (i - 1) * rowH
        local wait    = math.floor(now - (o.orderedAt or now))

        local row = Instance.new("Frame", bg)
        row.Size             = UDim2.new(1, -12, 0, rowH - 4)
        row.Position         = UDim2.new(0, 6, 0, yOff + 2)
        row.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
        row.BorderSizePixel  = 0
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

        -- Color stripe
        local stripe = Instance.new("Frame", row)
        stripe.Size             = UDim2.new(0, 6, 1, 0)
        stripe.BackgroundColor3 = COOKIE_COLORS[o.cookieId] or Color3.fromRGB(80, 80, 80)
        stripe.BorderSizePixel  = 0
        Instance.new("UICorner", stripe).CornerRadius = UDim.new(0, 6)

        -- NPC name
        local npcLbl = Instance.new("TextLabel", row)
        npcLbl.Size                   = UDim2.new(0.58, 0, 0.5, 0)
        npcLbl.Position               = UDim2.new(0, 14, 0, 0)
        npcLbl.BackgroundTransparency = 1
        npcLbl.TextColor3             = Color3.fromRGB(230, 230, 230)
        npcLbl.TextScaled             = true
        npcLbl.Font                   = Enum.Font.GothamBold
        npcLbl.Text                   = (o.isVIP and "⭐ " or "") .. o.npcName
        npcLbl.TextXAlignment         = Enum.TextXAlignment.Left

        -- Cookie + pack size
        local cookLbl = Instance.new("TextLabel", row)
        cookLbl.Size                   = UDim2.new(0.58, 0, 0.5, 0)
        cookLbl.Position               = UDim2.new(0, 14, 0.5, 0)
        cookLbl.BackgroundTransparency = 1
        cookLbl.TextColor3             = COOKIE_COLORS[o.cookieId] or Color3.fromRGB(180, 180, 180)
        cookLbl.TextScaled             = true
        cookLbl.Font                   = Enum.Font.Gotham
        cookLbl.Text                   = (COOKIE_NAMES[o.cookieId] or o.cookieId) .. "  ×" .. o.packSize
        cookLbl.TextXAlignment         = Enum.TextXAlignment.Left

        -- Wait time
        local waitLbl = Instance.new("TextLabel", row)
        waitLbl.Size                   = UDim2.new(0.38, -8, 1, 0)
        waitLbl.Position               = UDim2.new(0.62, 0, 0, 0)
        waitLbl.BackgroundTransparency = 1
        waitLbl.TextColor3             = timerColor(wait)
        waitLbl.TextScaled             = true
        waitLbl.Font                   = Enum.Font.GothamBold
        waitLbl.Text                   = formatWait(wait)
        waitLbl.TextXAlignment         = Enum.TextXAlignment.Right
    end
end

-- Refresh TV every 5 seconds (updates timers + new orders)
task.spawn(function()
    task.wait(3)  -- let workspace load
    updateTV()
    while true do
        task.wait(5)
        updateTV()
    end
end)

-- Also refresh immediately on new NPC order
OrderManager.On("NPCOrderAdded", function()
    task.defer(updateTV)
end)

-- ─── KDS Payload ─────────────────────────────────────────────────────────────
local function buildKDSPayload()
    local orders  = OrderManager.GetNPCOrders()
    local warmers = OrderManager.GetWarmerCountsByType()
    local now     = tick()
    local top3    = {}
    for i = 1, math.min(3, #orders) do
        local o = orders[i]
        top3[i] = {
            orderId     = o.orderId,
            npcName     = o.npcName,
            cookieId    = o.cookieId,
            packSize    = o.packSize,
            price       = o.price,
            isVIP       = o.isVIP,
            waitSeconds = math.floor(now - (o.orderedAt or now)),
        }
    end
    return { orders = top3, warmers = warmers }
end

-- ─── DressPrompt ─────────────────────────────────────────────────────────────
local function hookDressPrompt(desc)
    if not (desc:IsA("ProximityPrompt") and desc.Name == "DressPrompt") then return end
    desc.Triggered:Connect(function(player)
        if activeKDS[player] or dressLocked[player] then return end
        if #OrderManager.GetNPCOrders() == 0 then return end
        activeKDS[player] = true
        kdsUpdate:FireClient(player, buildKDSPayload())
    end)
end

for _, desc in ipairs(Workspace:GetDescendants()) do hookDressPrompt(desc) end
Workspace.DescendantAdded:Connect(hookDressPrompt)

-- ─── Order Lock (player selects order from KDS) ───────────────────────────────
lockOrder.OnServerEvent:Connect(function(player, orderId)
    if not activeKDS[player] then return end
    if type(orderId) ~= "number" then return end

    local targetOrder = nil
    for _, o in ipairs(OrderManager.GetNPCOrders()) do
        if o.orderId == orderId then targetOrder = o; break end
    end

    if not targetOrder then
        orderLocked:FireClient(player, { state = "error", message = "Order no longer available" })
        activeKDS[player] = nil
        return
    end

    local warmerCounts = OrderManager.GetWarmerCountsByType()
    if (warmerCounts[targetOrder.cookieId] or 0) == 0 then
        local name = COOKIE_NAMES[targetOrder.cookieId] or targetOrder.cookieId
        orderLocked:FireClient(player, { state = "error", message = "No " .. name .. " in warmers" })
        activeKDS[player] = nil
        return
    end

    -- Lock order — player must now walk to the matching warmer
    activeKDS[player]   = nil
    dressLocked[player] = { orderId = orderId, cookieId = targetOrder.cookieId, npcName = targetOrder.npcName }

    orderLocked:FireClient(player, {
        state      = "locked",
        cookieId   = targetOrder.cookieId,
        cookieName = COOKIE_NAMES[targetOrder.cookieId] or targetOrder.cookieId,
    })

    print(string.format("[DressStation] %s locked order #%d (%s) — awaiting warmer pickup",
        player.Name, orderId, targetOrder.cookieId))
end)

-- ─── Warmer Pickup Prompts ────────────────────────────────────────────────────
local function hookWarmerPrompt(prompt, cookieId)
    prompt.Triggered:Connect(function(player)
        local lock = dressLocked[player]
        if not lock then return end                       -- no order selected
        if lock.cookieId ~= cookieId then return end      -- wrong warmer, silently ignore

        local entry = OrderManager.TakeFromWarmersByType(cookieId)
        if not entry then
            orderLocked:FireClient(player, { state = "error", message = "Warmer is empty" })
            dressLocked[player] = nil
            return
        end

        local box = OrderManager.CreateBox(player, entry.batchId, DRESS_SCORE, entry)
        dressLocked[player] = nil

        if box then
            print(string.format("[DressStation] %s picked up %s — box #%d created for %s",
                player.Name, cookieId, box.boxId, lock.npcName))
            orderLocked:FireClient(player, { state = "done", boxId = box.boxId })
            task.defer(updateTV)
        else
            orderLocked:FireClient(player, { state = "error", message = "Failed to create box" })
        end
    end)
end

local function hookWarmerModel(model)
    local cookieId = model:GetAttribute("CookieId")
    if not cookieId then return end
    for _, child in ipairs(model:GetDescendants()) do
        if child:IsA("ProximityPrompt") and child.Name == "WarmerPickupPrompt" then
            hookWarmerPrompt(child, cookieId)
        end
    end
end

local warmersFolder = Workspace:FindFirstChild("Warmers")
if warmersFolder then
    for _, model in ipairs(warmersFolder:GetChildren()) do hookWarmerModel(model) end
    warmersFolder.ChildAdded:Connect(hookWarmerModel)
    -- Also catch prompts added after startup (e.g. from MCP)
    warmersFolder.DescendantAdded:Connect(function(desc)
        if desc:IsA("ProximityPrompt") and desc.Name == "WarmerPickupPrompt" then
            local model = desc.Parent
            local cookieId = model:GetAttribute("CookieId")
            if cookieId then hookWarmerPrompt(desc, cookieId) end
        end
    end)
else
    warn("[DressStation] Warmers folder not found")
end

-- ─── Cancel / Cleanup ────────────────────────────────────────────────────────
cancelOrder.OnServerEvent:Connect(function(player)
    activeKDS[player]   = nil
    dressLocked[player] = nil
end)

Players.PlayerRemoving:Connect(function(player)
    activeKDS[player]   = nil
    dressLocked[player] = nil
end)

print("[DressStationServer] Ready — KDS v2 (TV display + warmer pickup).")
