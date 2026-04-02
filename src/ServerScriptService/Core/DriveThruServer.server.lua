-- DriveThruServer
-- Drive-thru lane: car animation, order-taking via car prompt, window delivery.
-- Hidden until workspace.DriveThruUnlocked = true (store upgrade).

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService          = game:GetService("RunService")
local TweenService        = game:GetService("TweenService")
local ServerStorage       = game:GetService("ServerStorage")
local Workspace           = game:GetService("Workspace")

local RemoteManager     = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local OrderManager      = require(ServerScriptService:WaitForChild("Core"):WaitForChild("OrderManager"))
local hudUpdate                = RemoteManager.Get("HUDUpdate")
local driveThruArrivedRemote   = RemoteManager.Get("DriveThruCarArrived")
local npcOrderCancelledRemote  = RemoteManager.Get("NPCOrderCancelledClient")
local boxCarriedRemote         = RemoteManager.Get("BoxCarried")   -- BUG-61: clear carry pill on delivery
local carryPoseRemote          = RemoteManager.Get("CarryPoseUpdate")  -- BUG-86: clear arm pose on delivery
local CookieData        = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CookieData"))
local EconomyManager    = require(ServerScriptService:WaitForChild("Core"):WaitForChild("EconomyManager"))
local MenuManager       = require(ServerScriptService:WaitForChild("Core"):WaitForChild("MenuManager"))
local PlayerDataManager = require(ServerScriptService:WaitForChild("Core"):WaitForChild("PlayerDataManager"))
local SessionStats      = require(ServerScriptService:WaitForChild("Core"):WaitForChild("SessionStats"))
local GamepassManager   = require(ServerScriptService:WaitForChild("Core"):WaitForChild("GamepassManager"))

-- ── CONSTANTS ────────────────────────────────────────────────────────────────
-- Car travels along Z axis. Window wall is at X≈-33.5, faces -X.
-- Car rotation 180° Y: driver side faces window.
local CAR_LANE_X     = -40    -- driver side ends up at X≈-33.8 (next to window)
local CAR_SPAWN_Z    = -80    -- south, off-screen
local CAR_STOP_Z     = -14    -- stopped at window
local CAR_EXIT_Z     =  40    -- north, past building
local CAR_Y          = 2.5
local CAR_ARRIVE_SEC = 6
local CAR_EXIT_SEC   = 5
local SPAWN_INTERVAL = 45     -- M-6: seconds between cars during Open (was 150)
local WINDOW_TIMEOUT = 90     -- seconds before car leaves after order taken
local TAKE_TIMEOUT   = 60     -- seconds to take the order before car leaves
local PACK_SIZES     = { 1, 2, 4 }

-- ── STUDIO OBJECTS ────────────────────────────────────────────────────────────
local driveThruFolder = Workspace:WaitForChild("Drive Thru", 10)
local tvModel         = driveThruFolder and driveThruFolder:FindFirstChild("Drive Thru TV")
local tvPart          = tvModel and tvModel:FindFirstChildWhichIsA("BasePart")
local deliveryZone    = nil

local win1Model   = driveThruFolder
    and driveThruFolder:FindFirstChild("Drive Thru Window")
    and driveThruFolder:FindFirstChild("Drive Thru Window"):FindFirstChild("Window 1")
local WIN_SLIDE_Z = Vector3.new(0, 0, -3.1)
local WIN_INFO    = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

-- ── STATE ─────────────────────────────────────────────────────────────────────
local currentOrder = nil   -- { cookieId, packSize, coins, xp, car, npcOrderId }
local loopRunning  = false

-- ── VISIBILITY ────────────────────────────────────────────────────────────────
local savedT = {}
local savedC = {}

local function setFolderVisible(visible)
    if not driveThruFolder then return end
    for _, d in ipairs(driveThruFolder:GetDescendants()) do
        if d:IsA("BasePart") then
            if visible then
                d.Transparency = savedT[d] or 0
                d.CanCollide   = savedC[d] ~= nil and savedC[d] or true
            else
                if savedT[d] == nil then
                    savedT[d] = d.Transparency
                    savedC[d] = d.CanCollide
                end
                d.Transparency = 1
                d.CanCollide   = false
            end
        end
    end
end

-- ── WINDOW ANIMATION ──────────────────────────────────────────────────────────
local windowOpen = false

local function setWindowOpen(open)
    if open == windowOpen then return end
    windowOpen = open
    if not win1Model then return end
    local delta = open and WIN_SLIDE_Z or -WIN_SLIDE_Z
    for _, part in ipairs(win1Model:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Anchored = false
            local t = TweenService:Create(part, WIN_INFO, { CFrame = part.CFrame * CFrame.new(delta) })
            t:Play()
            t.Completed:Connect(function() part.Anchored = true end)
        end
    end
end

-- ── TV DISPLAY ────────────────────────────────────────────────────────────────
local tvGui = nil

local function ensureTVGui()
    if not tvPart then return nil end
    if tvGui and tvGui.Parent then return tvGui end

    tvGui = Instance.new("SurfaceGui")
    tvGui.Name = "DriveThruDisplay"; tvGui.Face = Enum.NormalId.Front
    tvGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    tvGui.PixelsPerStud = 50; tvGui.Parent = tvPart

    local bg = Instance.new("Frame", tvGui)
    bg.Name = "BG"; bg.Size = UDim2.new(1,0,1,0)
    bg.BackgroundColor3 = Color3.fromRGB(15,15,25); bg.BorderSizePixel = 0

    local title = Instance.new("TextLabel", bg)
    title.Name = "Title"; title.Size = UDim2.new(1,0,0.25,0)
    title.BackgroundTransparency = 1; title.TextColor3 = Color3.fromRGB(255,200,60)
    title.Font = Enum.Font.GothamBold; title.TextScaled = true; title.Text = "DRIVE THRU"

    local orderLbl = Instance.new("TextLabel", bg)
    orderLbl.Name = "Order"; orderLbl.Size = UDim2.new(1,0,0.45,0)
    orderLbl.Position = UDim2.new(0,0,0.25,0); orderLbl.BackgroundTransparency = 1
    orderLbl.TextColor3 = Color3.fromRGB(255,255,255); orderLbl.Font = Enum.Font.Gotham
    orderLbl.TextScaled = true; orderLbl.Text = "No Orders"

    local subLbl = Instance.new("TextLabel", bg)
    subLbl.Name = "Sub"; subLbl.Size = UDim2.new(1,0,0.30,0)
    subLbl.Position = UDim2.new(0,0,0.70,0); subLbl.BackgroundTransparency = 1
    subLbl.TextColor3 = Color3.fromRGB(130,230,130); subLbl.Font = Enum.Font.Gotham
    subLbl.TextScaled = true; subLbl.Text = ""

    return tvGui
end

local function updateTV(line1, line2)
    local gui = ensureTVGui()
    if not gui then return end
    local bg = gui:FindFirstChild("BG")
    if not bg then return end
    local ol = bg:FindFirstChild("Order")
    local sl = bg:FindFirstChild("Sub")
    if ol then ol.Text = line1 or "No Orders" end
    if sl then sl.Text = line2 or "" end
end

-- ── CAR MOVEMENT ─────────────────────────────────────────────────────────────
local function moveCarToZ(car, targetZ, duration, callback)
    local sp = car:GetPivot()
    local tp = CFrame.new(sp.X, sp.Y, targetZ)
        * CFrame.fromMatrix(Vector3.zero, sp.XVector, sp.YVector)
    local elapsed = 0
    local conn
    conn = RunService.Heartbeat:Connect(function(dt)
        elapsed += dt
        local t = math.min(1, elapsed / duration)
        car:PivotTo(sp:Lerp(tp, t * t * (3 - 2 * t)))
        if t >= 1 then conn:Disconnect(); if callback then callback() end end
    end)
end

-- ── CAR SPAWN ─────────────────────────────────────────────────────────────────
local function spawnCar()
    local template = ServerStorage:FindFirstChild("DriveThruCar")
    if not template then warn("[DriveThruServer] DriveThruCar missing"); return nil end
    local car = template:Clone()
    car.Name = "ActiveDriveThruCar"; car.Parent = driveThruFolder

    for _, d in ipairs(car:GetDescendants()) do
        if d:IsA("Script") or d:IsA("LocalScript") then d.Enabled = false end
        if d:IsA("BasePart") then d.Anchored = true end
    end
    if not car.PrimaryPart then
        for _, d in ipairs(car:GetDescendants()) do
            if d:IsA("BasePart") then car.PrimaryPart = d; break end
        end
    end
    car:PivotTo(CFrame.new(CAR_LANE_X, CAR_Y, CAR_SPAWN_Z) * CFrame.Angles(0, math.rad(180), 0))
    return car
end

-- ── DELIVERY PROMPT ────────────────────────────────────────────────────────────
local function createDeliveryZone()
    local p = Instance.new("Part")
    p.Name = "DriveThruDeliveryZone"; p.Size = Vector3.new(3, 5, 4)
    p.CFrame = CFrame.new(-31, 5, -14)
    p.Anchored = true; p.CanCollide = false; p.Transparency = 1
    p.Parent = driveThruFolder
    return p
end

local function addDeliveryPrompt(onDeliver)
    if not deliveryZone then deliveryZone = createDeliveryZone() end
    local existing = deliveryZone:FindFirstChild("DriveThruDeliverPrompt")
    if existing then existing:Destroy() end

    local pp = Instance.new("ProximityPrompt")
    pp.Name = "DriveThruDeliverPrompt"; pp.ActionText = "Hand Box"
    pp.ObjectText = "Drive Thru"; pp.MaxActivationDistance = 8
    pp.HoldDuration = 0; pp.RequiresLineOfSight = false
    pp.Parent = deliveryZone
    pp.Triggered:Connect(function(player) pp:Destroy(); onDeliver(player) end)
end

local function clearDeliveryPrompt()
    if deliveryZone then
        local pp = deliveryZone:FindFirstChild("DriveThruDeliverPrompt")
        if pp then pp:Destroy() end
    end
end

-- ── ORDER GENERATION ──────────────────────────────────────────────────────────
local function generateOrder()
    local menu = MenuManager.GetActiveMenu()
    if not menu or #menu == 0 then return nil end
    local cookieId = menu[math.random(1, #menu)]
    local packSize = PACK_SIZES[math.random(1, #PACK_SIZES)]
    local payout   = EconomyManager.CalculatePayout(cookieId, packSize, 5, 0, 1, false)
    return { cookieId = cookieId, packSize = packSize, coins = payout.coins, xp = payout.xp }
end

-- ── DISMISS CAR ───────────────────────────────────────────────────────────────
local function dismissCar(car, _, reason)
    if not currentOrder or currentOrder.car ~= car then return end
    print("[DriveThruServer] Car dismissed: " .. reason)
    clearDeliveryPrompt()
    if currentOrder.npcOrderId then
        local dismissedOrderId  = currentOrder.npcOrderId
        local dismissedCookieId = currentOrder.cookieId
        local dismissedPackSize = currentOrder.packSize
        OrderManager.CancelNPCOrder(dismissedOrderId)
        -- Notify all clients to remove the drive-thru order card from HUD
        npcOrderCancelledRemote:FireAllClients(dismissedOrderId, dismissedCookieId, dismissedPackSize)
    end
    currentOrder = nil
    updateTV("No Orders", "")
    setWindowOpen(false)
    moveCarToZ(car, CAR_EXIT_Z, CAR_EXIT_SEC, function()
        car:Destroy()
    end)
end

-- ── CAR ARRIVAL FLOW ──────────────────────────────────────────────────────────
local function handleCarArrival()
    if currentOrder then return end
    if driveThruFolder and driveThruFolder:FindFirstChild("ActiveDriveThruCar") then return end

    local order = generateOrder()
    if not order then return end

    local car = spawnCar()
    if not car then return end

    moveCarToZ(car, CAR_STOP_Z, CAR_ARRIVE_SEC, function()
        if currentOrder then car:Destroy(); return end

        setWindowOpen(true)
        updateTV("Customer waiting...", "Walk up to take order")
        -- S-3: alert all clients that a drive-thru car is waiting
        driveThruArrivedRemote:FireAllClients()

        local orderTaken = false

        -- Prompt on the car itself — no NPC at window
        local carPrimary = car.PrimaryPart
        if carPrimary then
            local pp = Instance.new("ProximityPrompt")
            pp.Name                  = "DriveThruOrderPrompt"
            pp.ActionText            = "Take Order"
            pp.ObjectText            = "Drive Thru"
            pp.MaxActivationDistance = 14
            pp.HoldDuration          = 0
            pp.RequiresLineOfSight   = false
            pp.Parent                = carPrimary

            pp.Triggered:Connect(function(player)
                if orderTaken then return end
                orderTaken = true
                pp:Destroy()

                local dressEntry = OrderManager.AddNPCOrder("Drive Thru", order.cookieId, {
                    packSize    = order.packSize,
                    price       = order.coins,
                    isDriveThru = true,
                })

                currentOrder = {
                    cookieId   = order.cookieId,
                    packSize   = order.packSize,
                    coins      = order.coins,
                    xp         = order.xp,
                    car        = car,
                    npc        = nil,
                    npcOrderId = dressEntry and dressEntry.orderId,
                    takenBy    = player,  -- C-4: track who took the order
                }

                local cookie = CookieData.GetById(order.cookieId)
                local name   = cookie and cookie.name or order.cookieId
                updateTV(name .. " x" .. order.packSize, order.coins .. " coins")
                hudUpdate:FireClient(player, nil, nil, name .. " x" .. order.packSize)
                print(string.format("[DriveThruServer] %s took drive-thru order | %s x%d",
                    player.Name, name, order.packSize))

                task.delay(WINDOW_TIMEOUT, function()
                    if currentOrder and currentOrder.car == car then
                        dismissCar(car, nil, "delivery timeout")
                    end
                end)
            end)
        end

        -- Timeout if nobody takes the order at all
        task.delay(TAKE_TIMEOUT, function()
            if orderTaken then return end
            if not car or not car.Parent then return end
            setWindowOpen(false)
            updateTV("No Orders", "")
            moveCarToZ(car, CAR_EXIT_Z, CAR_EXIT_SEC, function()
                if car.Parent then car:Destroy() end
            end)
            print("[DriveThruServer] Car dismissed: take-order timeout")
        end)
    end)
end

-- ── BOX DELIVERY HOOK ─────────────────────────────────────────────────────────
OrderManager.On("BoxCreated", function(box)
    if not currentOrder then return end
    if box.cookieId ~= currentOrder.cookieId then return end
    if (tonumber(box.packSize) or 1) ~= (tonumber(currentOrder.packSize) or 1) then
        warn(string.format("[AntiExploit] BoxCreated packSize mismatch: got %d, need %d",
            tonumber(box.packSize) or 1, tonumber(currentOrder.packSize) or 1))
        return
    end
    if currentOrder.takenBy and box.carrier ~= currentOrder.takenBy.Name then
        warn(string.format("[AntiExploit] Ignoring drive-thru box from %s; order belongs to %s",
            tostring(box.carrier), currentOrder.takenBy.Name))
        return
    end

    local order = currentOrder
    order.boxId = box.boxId

    addDeliveryPrompt(function(player)
        if not currentOrder or currentOrder.car ~= order.car then return end
        -- C-4: only the player who took the order may deliver it
        if order.takenBy and player ~= order.takenBy then
            warn(string.format("[AntiExploit] %s tried to deliver drive-thru order taken by %s",
                player.Name, order.takenBy.Name))
            return
        end
        if not OrderManager.IsCarryingBox(player) then
            warn(string.format("[AntiExploit] %s triggered drive-thru delivery without carrying a box", player.Name))
            return
        end

        local deliverCar        = order.car
        local deliverNpcOrderId = order.npcOrderId
        local deliverCoins      = tonumber(order.coins) or 0
        -- BUG-25: VIPPass gives delivering player 1.5x coin bonus
        if GamepassManager.HasVIPPass(player) then
            deliverCoins = math.floor(deliverCoins * 1.5)
        end
        local deliverXp         = tonumber(order.xp) or 0
        local deliverBoxId      = order.boxId

        local ok = deliverBoxId and OrderManager.DeliverBox(player, deliverBoxId, deliverNpcOrderId)
        if not ok then
            warn(string.format("[DriveThruServer] DeliverBox failed for %s on drive-thru order", player.Name))
            return
        end

        currentOrder = nil
        updateTV("No Orders", "")
        clearDeliveryPrompt()

        setWindowOpen(false)
        moveCarToZ(deliverCar, CAR_EXIT_Z, CAR_EXIT_SEC, function()
            deliverCar:Destroy()
        end)

        PlayerDataManager.AddCoins(player, deliverCoins)
        PlayerDataManager.AddXP(player, deliverXp)
        SessionStats.RecordDelivery(5, deliverCoins, 0, order.packSize)

        -- Fetch updated profile totals so HUD shows cumulative coins, not just earned
        local profile = PlayerDataManager.GetData(player)

        local deliveryResult = RemoteManager.Get("DeliveryResult")
        deliveryResult:FireClient(player, 5, deliverCoins, deliverXp)
        hudUpdate:FireClient(player,
            profile and profile.coins or 0,
            profile and profile.xp    or 0,
            nil)
        -- BUG-61/86: clear carry pill, arm pose, and physical box after drive-thru delivery
        boxCarriedRemote:FireClient(player, nil)
        carryPoseRemote:FireClient(player, false)  -- BUG-86: restore arm pose
        local carriedModel = workspace:FindFirstChild("CarriedBox_" .. player.Name)
        if carriedModel then carriedModel:Destroy() end

        print(string.format("[DriveThruServer] %s delivered | %s x%d | +%d coins",
            player.Name, order.cookieId, order.packSize, deliverCoins))
    end)
end)

-- ── OPEN PHASE LOOP ───────────────────────────────────────────────────────────
local function startLoop()
    if loopRunning then return end
    loopRunning = true
    task.spawn(function()
        task.wait(20)
        while workspace:GetAttribute("GameState") == "Open"
            and workspace:GetAttribute("DriveThruUnlocked") do
            if not currentOrder then handleCarArrival() end
            task.wait(SPAWN_INTERVAL)
        end
        loopRunning = false
        print("[DriveThruServer] Loop ended")
    end)
end

-- ── UNLOCK / GAME STATE ───────────────────────────────────────────────────────
-- ── LOCKED SIGN ────────────────────────────────────────────────────────────────
-- A visible sign outside driveThruFolder that shows when locked
local lockedSign = nil

local function ensureLockedSign()
    if lockedSign and lockedSign.Parent then return lockedSign end
    local p = Instance.new("Part")
    p.Name         = "DriveThruLockedSign"
    p.Size         = Vector3.new(10, 5, 0.5)
    p.CFrame       = CFrame.new(-36, 7, -25) * CFrame.Angles(0, math.rad(90), 0)
    p.Anchored     = true
    p.CanCollide   = true
    p.Material     = Enum.Material.SmoothPlastic
    p.BrickColor   = BrickColor.new("Crimson")
    p.Parent       = Workspace

    local sg = Instance.new("SurfaceGui")
    sg.Name        = "LockedSignGui"
    sg.Face        = Enum.NormalId.Front
    sg.SizingMode  = Enum.SurfaceGuiSizingMode.PixelsPerStud
    sg.PixelsPerStud = 40
    sg.Parent      = p

    local bg = Instance.new("Frame", sg)
    bg.Size = UDim2.fromScale(1, 1)
    bg.BackgroundColor3 = Color3.fromRGB(180, 20, 20)
    bg.BorderSizePixel = 0

    local lbl = Instance.new("TextLabel", bg)
    lbl.Size = UDim2.fromScale(1, 1)
    lbl.BackgroundTransparency = 1
    lbl.Text = "🚗 DRIVE THRU\n🔒 Locked\nComplete first shift\nto unlock!"
    lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextScaled = true

    lockedSign = p
    return lockedSign
end

local function setLockedSignVisible(visible)
    local sign = ensureLockedSign()
    if sign then sign.Transparency = visible and 0 or 1; sign.CanCollide = visible end
end

local function onUnlockChanged()
    local unlocked = workspace:GetAttribute("DriveThruUnlocked")
    setFolderVisible(unlocked == true)
    setLockedSignVisible(not unlocked)
    if unlocked then
        updateTV("No Orders", "")
    end
    if unlocked and workspace:GetAttribute("GameState") == "Open" then startLoop() end
    print("[DriveThruServer] DriveThruUnlocked=" .. tostring(unlocked))
end

workspace:GetAttributeChangedSignal("DriveThruUnlocked"):Connect(onUnlockChanged)

workspace:GetAttributeChangedSignal("GameState"):Connect(function()
    local state    = workspace:GetAttribute("GameState")
    local unlocked = workspace:GetAttribute("DriveThruUnlocked")
    if state == "Open" and unlocked then
        startLoop()
    elseif state ~= "Open" then
        if currentOrder then
            local car = currentOrder.car
            currentOrder = nil
            clearDeliveryPrompt()
            setWindowOpen(false)
            updateTV("CLOSED", "")
            if car then car:Destroy() end
        end
        loopRunning = false
    end
end)

-- BUG-29: if the player who took the order disconnects, release takenBy so
-- another player can deliver (otherwise car sits idle for full WINDOW_TIMEOUT)
Players.PlayerRemoving:Connect(function(player)
    if currentOrder and currentOrder.takenBy == player then
        currentOrder.takenBy = nil
        print("[DriveThruServer] Carrier " .. player.Name .. " disconnected — drive-thru order now claimable")
    end
end)

-- ── INIT ──────────────────────────────────────────────────────────────────────
ensureTVGui()
onUnlockChanged()
print("[DriveThruServer] Ready — no NPC, prompt on car")
