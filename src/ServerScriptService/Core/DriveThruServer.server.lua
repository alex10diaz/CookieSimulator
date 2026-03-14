-- DriveThruServer
-- Manages drive-thru lane: car animation, order queue, window delivery.
-- Hidden until workspace.DriveThruUnlocked = true (store upgrade).

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local ServerStorage     = game:GetService("ServerStorage")
local Workspace         = game:GetService("Workspace")

local RemoteManager     = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local OrderManager      = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("OrderManager"))
local CookieData        = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CookieData"))
local EconomyManager    = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("EconomyManager"))
local MenuManager       = require(ServerScriptService:WaitForChild("Core"):WaitForChild("MenuManager"))
local PlayerDataManager = require(ServerScriptService:WaitForChild("Core"):WaitForChild("PlayerDataManager"))
local SessionStats      = require(ServerScriptService:WaitForChild("Core"):WaitForChild("SessionStats"))

-- ── CONSTANTS ────────────────────────────────────────────────────────────────
local CAR_SPAWN_X    = -84    -- spawn point (left, off-screen)
local CAR_STOP_X     = -43    -- stopped at window (front of car ≈ -36, 2 studs from window)
local CAR_EXIT_X     = 20     -- exit point (right, off-screen)
local CAR_ROAD_Z     = -14    -- centre of road, aligned with window
local CAR_Y          = 2.5    -- approximate ride height for the car model
local CAR_ARRIVE_SEC = 6      -- seconds to drive from spawn to stop
local CAR_EXIT_SEC   = 5      -- seconds to drive from stop to exit
local SPAWN_INTERVAL = 90     -- seconds between car arrivals (Open phase)
local WINDOW_TIMEOUT = 60     -- seconds before car gives up waiting
local PACK_SIZES     = { 1, 2, 4 }

-- ── STUDIO OBJECTS ────────────────────────────────────────────────────────────
local driveThruFolder = Workspace:WaitForChild("Drive Thru", 10)
local tvModel         = driveThruFolder and driveThruFolder:FindFirstChild("Drive Thru TV")
local tvPart          = tvModel and tvModel:FindFirstChildWhichIsA("BasePart")
local deliveryZone    = nil   -- created on unlock

-- Window 1 sliding parts (grabbed once at startup)
local win1Model  = driveThruFolder
    and driveThruFolder:FindFirstChild("Drive Thru Window")
    and driveThruFolder:FindFirstChild("Drive Thru Window"):FindFirstChild("Window 1")
local WIN_SLIDE_DELTA = Vector3.new(0, 0, -3.1)  -- slides toward Window 2 to open
local WIN_TWEEN_INFO  = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

-- ── STATE ─────────────────────────────────────────────────────────────────────
local currentOrder    = nil   -- { cookieId, packSize, price, car, timeoutThread }
local loopRunning     = false

-- ── VISIBILITY ────────────────────────────────────────────────────────────────
local savedTransparency = {}
local savedCanCollide   = {}

local function setFolderVisible(visible)
    if not driveThruFolder then return end
    for _, d in ipairs(driveThruFolder:GetDescendants()) do
        if d:IsA("BasePart") then
            if visible then
                d.Transparency = savedTransparency[d] or 0
                d.CanCollide   = savedCanCollide[d]   or (d.Transparency < 0.9)
            else
                if savedTransparency[d] == nil then
                    savedTransparency[d] = d.Transparency
                    savedCanCollide[d]   = d.CanCollide
                end
                d.Transparency = 1
                d.CanCollide   = false
            end
        end
    end
end

-- ── WINDOW ANIMATION ──────────────────────────────────────────────────────────
local windowOpen = false

local function collectWindow1Parts()
    local parts = {}
    if not win1Model then return parts end
    for _, d in ipairs(win1Model:GetDescendants()) do
        if d:IsA("BasePart") then
            table.insert(parts, d)
        end
    end
    return parts
end

local function setWindowOpen(open)
    if open == windowOpen then return end
    windowOpen = open
    local parts  = collectWindow1Parts()
    local delta  = open and WIN_SLIDE_DELTA or -WIN_SLIDE_DELTA
    for _, part in ipairs(parts) do
        part.Anchored = false  -- TweenService needs non-anchored OR we set directly
        local target = part.CFrame * CFrame.new(delta)
        local tween  = TweenService:Create(part, WIN_TWEEN_INFO, { CFrame = target })
        tween:Play()
        tween.Completed:Connect(function()
            part.Anchored = true
        end)
    end
end

-- ── TV DISPLAY ────────────────────────────────────────────────────────────────
local tvGui = nil

local function ensureTVGui()
    if not tvPart then return nil end
    if tvGui and tvGui.Parent then return tvGui end
    tvGui = Instance.new("SurfaceGui")
    tvGui.Name          = "DriveThruDisplay"
    tvGui.Face          = Enum.NormalId.Front
    tvGui.SizingMode    = Enum.SurfaceGuiSizingMode.PixelsPerStud
    tvGui.PixelsPerStud = 50
    tvGui.AlwaysOnTop   = false
    tvGui.Parent        = tvPart

    local bg = Instance.new("Frame", tvGui)
    bg.Name                  = "BG"
    bg.Size                  = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3      = Color3.fromRGB(15, 15, 25)
    bg.BorderSizePixel        = 0

    local title = Instance.new("TextLabel", bg)
    title.Name               = "Title"
    title.Size               = UDim2.new(1, 0, 0.25, 0)
    title.BackgroundTransparency = 1
    title.TextColor3         = Color3.fromRGB(255, 200, 60)
    title.Font               = Enum.Font.GothamBold
    title.TextScaled         = true
    title.Text               = "DRIVE THRU"

    local orderLbl = Instance.new("TextLabel", bg)
    orderLbl.Name            = "Order"
    orderLbl.Size            = UDim2.new(1, 0, 0.45, 0)
    orderLbl.Position        = UDim2.new(0, 0, 0.25, 0)
    orderLbl.BackgroundTransparency = 1
    orderLbl.TextColor3      = Color3.fromRGB(255, 255, 255)
    orderLbl.Font            = Enum.Font.Gotham
    orderLbl.TextScaled      = true
    orderLbl.Text            = "No Orders"

    local subLbl = Instance.new("TextLabel", bg)
    subLbl.Name              = "Sub"
    subLbl.Size              = UDim2.new(1, 0, 0.30, 0)
    subLbl.Position          = UDim2.new(0, 0, 0.70, 0)
    subLbl.BackgroundTransparency = 1
    subLbl.TextColor3        = Color3.fromRGB(130, 230, 130)
    subLbl.Font              = Enum.Font.Gotham
    subLbl.TextScaled        = true
    subLbl.Text              = ""

    return tvGui
end

local function updateTV(orderText, subText)
    local gui = ensureTVGui()
    if not gui then return end
    local bg = gui:FindFirstChild("BG")
    if not bg then return end
    local ol = bg:FindFirstChild("Order")
    local sl = bg:FindFirstChild("Sub")
    if ol then ol.Text = orderText or "No Orders" end
    if sl then sl.Text = subText or "" end
end

-- ── CAR MOVEMENT ─────────────────────────────────────────────────────────────
local function moveCarToX(car, targetX, duration, callback)
    local startPivot = car:GetPivot()
    local targetPivot = CFrame.new(targetX, startPivot.Y, startPivot.Z)
        * CFrame.fromMatrix(Vector3.zero, startPivot.XVector, startPivot.YVector)

    local elapsed = 0
    local conn
    conn = RunService.Heartbeat:Connect(function(dt)
        elapsed += dt
        local t = math.min(1, elapsed / duration)
        local smooth = t * t * (3 - 2 * t)
        car:PivotTo(startPivot:Lerp(targetPivot, smooth))
        if t >= 1 then
            conn:Disconnect()
            if callback then callback() end
        end
    end)
end

-- ── CAR SPAWN ─────────────────────────────────────────────────────────────────
local function spawnCar()
    local template = ServerStorage:FindFirstChild("DriveThruCar")
    if not template then
        warn("[DriveThruServer] DriveThruCar template missing from ServerStorage")
        return nil
    end
    local car = template:Clone()
    car.Name   = "ActiveDriveThruCar"
    car.Parent = driveThruFolder

    -- Disable any scripts
    for _, d in ipairs(car:GetDescendants()) do
        if d:IsA("Script") or d:IsA("LocalScript") then d.Enabled = false end
    end
    -- Ensure anchored
    for _, d in ipairs(car:GetDescendants()) do
        if d:IsA("BasePart") then d.Anchored = true end
    end
    -- Set PrimaryPart if missing
    if not car.PrimaryPart then
        for _, d in ipairs(car:GetDescendants()) do
            if d:IsA("BasePart") then car.PrimaryPart = d; break end
        end
    end

    -- Place at spawn: rotate 90° so car length (Z→X) aligns with road
    car:PivotTo(CFrame.new(CAR_SPAWN_X, CAR_Y, CAR_ROAD_Z) * CFrame.Angles(0, math.rad(-90), 0))
    return car
end

-- ── DELIVERY PROMPT ────────────────────────────────────────────────────────────
local function createDeliveryZone()
    local p = Instance.new("Part")
    p.Name         = "DriveThruDeliveryZone"
    p.Size         = Vector3.new(3, 5, 4)
    p.CFrame       = CFrame.new(-31, 5, CAR_ROAD_Z)  -- inside bakery, reachable from floor
    p.Anchored     = true
    p.CanCollide   = false
    p.Transparency = 1
    p.Parent       = driveThruFolder
    return p
end

local function addDeliveryPrompt(onDeliver)
    if not deliveryZone then
        deliveryZone = createDeliveryZone()
    end
    local existing = deliveryZone:FindFirstChild("DriveThruDeliverPrompt")
    if existing then existing:Destroy() end

    local pp = Instance.new("ProximityPrompt")
    pp.Name                  = "DriveThruDeliverPrompt"
    pp.ActionText            = "Hand Box"
    pp.ObjectText            = "Drive Thru"
    pp.MaxActivationDistance = 15
    pp.HoldDuration          = 0
    pp.RequiresLineOfSight   = false
    pp.Parent                = deliveryZone

    pp.Triggered:Connect(function(player)
        pp:Destroy()
        onDeliver(player)
    end)
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

-- ── CAR ARRIVAL FLOW ──────────────────────────────────────────────────────────
local function dismissCar(car, reason)
    if not currentOrder or currentOrder.car ~= car then return end
    print("[DriveThruServer] Car dismissed: " .. reason)
    clearDeliveryPrompt()
    currentOrder = nil
    updateTV("No Orders", "")
    setWindowOpen(false)
    moveCarToX(car, CAR_EXIT_X, CAR_EXIT_SEC, function()
        car:Destroy()
    end)
end

local function handleCarArrival()
    if currentOrder then return end  -- already serving

    local order = generateOrder()
    if not order then return end

    local car = spawnCar()
    if not car then return end

    moveCarToX(car, CAR_STOP_X, CAR_ARRIVE_SEC, function()
        if currentOrder then
            -- Another order snuck in (shouldn't happen, guard anyway)
            car:Destroy()
            return
        end

        currentOrder = {
            cookieId = order.cookieId,
            packSize = order.packSize,
            coins    = order.coins,
            xp       = order.xp,
            car      = car,
        }

        local cookie = CookieData.GetById(order.cookieId)
        local name   = cookie and cookie.name or order.cookieId
        updateTV(name .. " x" .. order.packSize, order.coins .. " coins")
        setWindowOpen(true)
        print(string.format("[DriveThruServer] Car at window | %s x%d | %d coins", name, order.packSize, order.coins))

        -- Timeout: car leaves if nobody delivers in time
        task.delay(WINDOW_TIMEOUT, function()
            if currentOrder and currentOrder.car == car then
                dismissCar(car, "timeout")
            end
        end)
    end)
end

-- ── BOX DELIVERY HOOK ─────────────────────────────────────────────────────────
OrderManager.On("BoxCreated", function(box)
    if not currentOrder then return end
    print(string.format("[DriveThruServer] BoxCreated: box.cookieId=%s order.cookieId=%s",
        tostring(box.cookieId), tostring(currentOrder.cookieId)))
    if box.cookieId ~= currentOrder.cookieId then return end

    local order = currentOrder

    addDeliveryPrompt(function(player)
        if not currentOrder or currentOrder.car ~= order.car then return end

        currentOrder = nil
        updateTV("No Orders", "")

        -- Award coins + XP
        PlayerDataManager.AddCoins(player, order.coins)
        PlayerDataManager.AddXP(player, order.xp)
        SessionStats.RecordDelivery(player, order.cookieId, order.coins)

        local cookie = CookieData.GetById(order.cookieId)
        print(string.format("[DriveThruServer] %s delivered drive-thru | %s x%d | +%d coins",
            player.Name, order.cookieId, order.packSize, order.coins))

        -- Notify HUD (reuse DeliveryResult remote)
        local deliveryResult = RemoteManager.Get("DeliveryResult")
        for _, p in ipairs(Players:GetPlayers()) do
            deliveryResult:FireClient(p, {
                playerName  = player.Name,
                cookieId    = order.cookieId,
                reward      = order.coins,
                isDriveThru = true,
            })
        end

        -- Close window and drive car away
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
        task.wait(20)  -- initial delay before first car
        while workspace:GetAttribute("GameState") == "Open"
            and workspace:GetAttribute("DriveThruUnlocked") do
            if not currentOrder then
                handleCarArrival()
            end
            task.wait(SPAWN_INTERVAL)
        end
        loopRunning = false
        print("[DriveThruServer] Drive-thru loop ended")
    end)
end

-- ── UNLOCK LOGIC ──────────────────────────────────────────────────────────────
local function onUnlockChanged()
    local unlocked = workspace:GetAttribute("DriveThruUnlocked")
    setFolderVisible(unlocked == true)
    if unlocked and workspace:GetAttribute("GameState") == "Open" then
        startLoop()
    end
    print("[DriveThruServer] DriveThruUnlocked = " .. tostring(unlocked))
end

workspace:GetAttributeChangedSignal("DriveThruUnlocked"):Connect(onUnlockChanged)

-- ── GAME STATE WIRING ─────────────────────────────────────────────────────────
workspace:GetAttributeChangedSignal("GameState"):Connect(function()
    local state    = workspace:GetAttribute("GameState")
    local unlocked = workspace:GetAttribute("DriveThruUnlocked")
    if state == "Open" and unlocked then
        startLoop()
    elseif state ~= "Open" then
        -- Clear car if game ends mid-service
        if currentOrder then
            local car = currentOrder.car
            currentOrder = nil
            clearDeliveryPrompt()
            updateTV("CLOSED", "")
            if car then car:Destroy() end
        end
        loopRunning = false
    end
end)

-- ── INIT ──────────────────────────────────────────────────────────────────────
ensureTVGui()
onUnlockChanged()  -- apply initial visibility based on attribute

print("[DriveThruServer] Ready")
