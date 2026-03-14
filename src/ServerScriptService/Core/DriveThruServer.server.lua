-- DriveThruServer
-- Drive-thru lane: car animation, NPC order-taking, window delivery.
-- Hidden until workspace.DriveThruUnlocked = true (store upgrade).

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService          = game:GetService("RunService")
local TweenService        = game:GetService("TweenService")
local ServerStorage       = game:GetService("ServerStorage")
local Workspace           = game:GetService("Workspace")

local RemoteManager     = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local OrderManager      = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("OrderManager"))
local CookieData        = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CookieData"))
local EconomyManager    = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("EconomyManager"))
local MenuManager       = require(ServerScriptService:WaitForChild("Core"):WaitForChild("MenuManager"))
local PlayerDataManager = require(ServerScriptService:WaitForChild("Core"):WaitForChild("PlayerDataManager"))
local SessionStats      = require(ServerScriptService:WaitForChild("Core"):WaitForChild("SessionStats"))

-- ── CONSTANTS ────────────────────────────────────────────────────────────────
local CAR_SPAWN_X    = -84    -- left end of road (off-screen)
local CAR_STOP_X     = -43    -- car center when stopped at window
local CAR_EXIT_X     = -2     -- right end of road (off-screen, road ends at X≈-3)
local CAR_ROAD_Z     = -14    -- road/window Z centre
local CAR_Y          = 2.5
local CAR_ARRIVE_SEC = 6
local CAR_EXIT_SEC   = 5
local SPAWN_INTERVAL = 90     -- seconds between cars during Open
local WINDOW_TIMEOUT = 90     -- seconds before car gives up (after order is taken)
local TAKE_TIMEOUT   = 60     -- seconds to take the order before car leaves
local PACK_SIZES     = { 1, 2, 4 }

-- NPC seated position (window side of stopped car)
local NPC_CF = CFrame.new(-38, 3.5, -14)

-- ── STUDIO OBJECTS ────────────────────────────────────────────────────────────
local driveThruFolder = Workspace:WaitForChild("Drive Thru", 10)
local tvModel         = driveThruFolder and driveThruFolder:FindFirstChild("Drive Thru TV")
local tvPart          = tvModel and tvModel:FindFirstChildWhichIsA("BasePart")
local deliveryZone    = nil

-- Window 1 animation
local win1Model      = driveThruFolder
    and driveThruFolder:FindFirstChild("Drive Thru Window")
    and driveThruFolder:FindFirstChild("Drive Thru Window"):FindFirstChild("Window 1")
local WIN_SLIDE_Z    = Vector3.new(0, 0, -3.1)
local WIN_INFO       = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

-- ── STATE ─────────────────────────────────────────────────────────────────────
local currentOrder = nil   -- { cookieId, packSize, coins, xp, car, npc }
local loopRunning  = false

-- ── VISIBILITY ────────────────────────────────────────────────────────────────
local savedT = {}   -- savedTransparency
local savedC = {}   -- savedCanCollide

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
local function moveCarToX(car, targetX, duration, callback)
    local sp = car:GetPivot()
    local tp = CFrame.new(targetX, sp.Y, sp.Z)
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
    -- +90° rotation: car's -Z (front) now faces +X = direction of travel (left→right)
    car:PivotTo(CFrame.new(CAR_SPAWN_X, CAR_Y, CAR_ROAD_Z) * CFrame.Angles(0, math.rad(90), 0))
    return car
end

-- ── NPC IN CAR ────────────────────────────────────────────────────────────────
local function spawnCarNPC(onTakeOrder)
    local template = ServerStorage:FindFirstChild("NPCTemplate")
    if not template then return nil end
    local npc = template:Clone()
    npc.Name   = "DriveThruCustomer"
    npc.Parent = driveThruFolder

    -- Anchor and disable AI
    for _, d in ipairs(npc:GetDescendants()) do
        if d:IsA("BasePart") then d.Anchored = true; d.CanCollide = false end
    end
    local hum = npc:FindFirstChildWhichIsA("Humanoid")
    if hum then hum.WalkSpeed = 0; hum.JumpPower = 0 end

    -- Hide patience/face guis that don't apply
    local head = npc:FindFirstChild("Head")
    if head then
        local pg = head:FindFirstChild("PatienceGui")
        if pg then pg.Enabled = false end
    end

    -- Position NPC seated at window side of car
    local hrp = npc:FindFirstChild("HumanoidRootPart")
    if hrp then hrp.CFrame = NPC_CF end

    -- Set up "Take Order" prompt (reuse existing OrderPrompt)
    if head then
        local pp = head:FindFirstChild("OrderPrompt")
        if not pp then
            pp = Instance.new("ProximityPrompt")
            pp.Name   = "OrderPrompt"
            pp.Parent = head
        end
        pp.ActionText            = "Take Order"
        pp.ObjectText            = "Drive Thru Customer"
        pp.MaxActivationDistance = 12
        pp.HoldDuration          = 0
        pp.RequiresLineOfSight   = false
        pp.Enabled               = true

        pp.Triggered:Connect(function(player)
            pp.Enabled = false
            onTakeOrder(player)
        end)
    end

    return npc
end

local function despawnNPC(npc)
    if npc and npc.Parent then npc:Destroy() end
end

-- ── DELIVERY PROMPT ────────────────────────────────────────────────────────────
local function createDeliveryZone()
    local p = Instance.new("Part")
    p.Name = "DriveThruDeliveryZone"; p.Size = Vector3.new(3, 5, 4)
    p.CFrame = CFrame.new(-31, 5, CAR_ROAD_Z)
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
    pp.ObjectText = "Drive Thru"; pp.MaxActivationDistance = 15
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
local function dismissCar(car, npc, reason)
    if not currentOrder or currentOrder.car ~= car then return end
    print("[DriveThruServer] Car dismissed: " .. reason)
    clearDeliveryPrompt()
    despawnNPC(npc)
    currentOrder = nil
    updateTV("No Orders", "")
    setWindowOpen(false)
    moveCarToX(car, CAR_EXIT_X, CAR_EXIT_SEC, function() car:Destroy() end)
end

-- ── CAR ARRIVAL FLOW ──────────────────────────────────────────────────────────
local function handleCarArrival()
    if currentOrder then return end

    local order = generateOrder()
    if not order then return end

    local car = spawnCar()
    if not car then return end

    -- Drive to window
    moveCarToX(car, CAR_STOP_X, CAR_ARRIVE_SEC, function()
        if currentOrder then car:Destroy(); return end

        -- Window slides open
        setWindowOpen(true)
        updateTV("Customer waiting...", "Walk up to take order")

        -- Spawn NPC in car
        local npc = spawnCarNPC(function(player)
            -- Player took the order
            currentOrder = {
                cookieId = order.cookieId,
                packSize = order.packSize,
                coins    = order.coins,
                xp       = order.xp,
                car      = car,
                npc      = npc,
            }

            local cookie = CookieData.GetById(order.cookieId)
            local name   = cookie and cookie.name or order.cookieId
            updateTV(name .. " x" .. order.packSize, order.coins .. " coins")
            print(string.format("[DriveThruServer] %s took drive-thru order | %s x%d",
                player.Name, name, order.packSize))

            -- Timeout after order is taken
            task.delay(WINDOW_TIMEOUT, function()
                if currentOrder and currentOrder.car == car then
                    dismissCar(car, npc, "delivery timeout")
                end
            end)
        end)

        -- Timeout if nobody takes the order
        task.delay(TAKE_TIMEOUT, function()
            if not currentOrder or currentOrder.car ~= car then return end
            -- Order was not taken yet (currentOrder would have car set after take)
            -- Check if currentOrder cookieId is set (means order was taken)
            if currentOrder and currentOrder.cookieId then return end
            dismissCar(car, npc, "take-order timeout")
        end)
    end)
end

-- ── BOX DELIVERY HOOK ─────────────────────────────────────────────────────────
OrderManager.On("BoxCreated", function(box)
    if not currentOrder then return end
    print(string.format("[DriveThruServer] BoxCreated cookieId=%s | need=%s",
        tostring(box.cookieId), tostring(currentOrder.cookieId)))
    if box.cookieId ~= currentOrder.cookieId then return end

    local order = currentOrder

    addDeliveryPrompt(function(player)
        if not currentOrder or currentOrder.car ~= order.car then return end

        currentOrder = nil
        updateTV("No Orders", "")
        clearDeliveryPrompt()

        PlayerDataManager.AddCoins(player, order.coins)
        PlayerDataManager.AddXP(player, order.xp)
        SessionStats.RecordDelivery(player, order.cookieId, order.coins)

        local cookie = CookieData.GetById(order.cookieId)
        print(string.format("[DriveThruServer] %s delivered | %s x%d | +%d coins",
            player.Name, order.cookieId, order.packSize, order.coins))

        local deliveryResult = RemoteManager.Get("DeliveryResult")
        for _, p in ipairs(Players:GetPlayers()) do
            deliveryResult:FireClient(p, {
                playerName  = player.Name,
                cookieId    = order.cookieId,
                reward      = order.coins,
                isDriveThru = true,
            })
        end

        despawnNPC(order.npc)
        setWindowOpen(false)
        moveCarToX(order.car, CAR_EXIT_X, CAR_EXIT_SEC, function()
            order.car:Destroy()
        end)
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
local function onUnlockChanged()
    local unlocked = workspace:GetAttribute("DriveThruUnlocked")
    setFolderVisible(unlocked == true)
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
            local car, npc = currentOrder.car, currentOrder.npc
            currentOrder = nil
            clearDeliveryPrompt()
            despawnNPC(npc)
            setWindowOpen(false)
            updateTV("CLOSED", "")
            if car then car:Destroy() end
        end
        loopRunning = false
    end
end)

-- ── INIT ──────────────────────────────────────────────────────────────────────
ensureTVGui()
onUnlockChanged()
print("[DriveThruServer] Ready")
