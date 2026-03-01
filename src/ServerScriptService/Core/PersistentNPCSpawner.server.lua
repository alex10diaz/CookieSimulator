-- NPCController (PersistentNPCSpawner)
-- Full NPC customer lifecycle:
--   spawn → walk to queue → wait → player takes order →
--   walk to seat → wait → box ready → walk to counter →
--   player delivers → NPC leaves

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace           = game:GetService("Workspace")

local NPCSpawner        = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("NPCSpawner"))
local OrderManager      = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("OrderManager"))
local CookieData        = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CookieData"))
local RemoteManager     = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local PlayerDataManager = require(ServerScriptService:WaitForChild("Core"):WaitForChild("PlayerDataManager"))

-- ─── CONSTANTS ────────────────────────────────────────────────────────────────
local MAX_NPCS_IN_SCENE    = 6
local MAX_QUEUE_SIZE       = 3
local SPAWN_INTERVAL       = 30      -- seconds between spawn checks
local BASE_PATIENCE        = 120     -- seconds at 1 player
local PATIENCE_PER_PLAYER  = 20      -- extra seconds per additional player
local VIP_CHANCE           = 0.10
local PACK_SIZES           = { 1, 4, 6 }

local NPC_NAMES = {
    "Alex", "Sam", "Jordan", "Riley", "Morgan", "Casey", "Taylor",
    "Jamie", "Quinn", "Drew", "Avery", "Skylar", "Rowan", "Blake",
    "Reese", "Finley", "Dakota", "Sage", "River", "Phoenix",
}

-- ─── STUDIO OBJECTS ───────────────────────────────────────────────────────────
local QUEUE_FOLDER  = Workspace:WaitForChild("NPCQueue",       10)
local SPAWN_PART    = Workspace:WaitForChild("NPCSpawnPoint",  10)
local COUNTER_PART  = Workspace:WaitForChild("NPCCounterSpot", 10)
local WAITING_AREA  = Workspace:WaitForChild("WaitingArea",    10)

local POS_OBJ       = Workspace:WaitForChild("POS",  10)
local TABLET_PART   = POS_OBJ    and POS_OBJ:FindFirstChild("Tablet")
local ORDER_DISPLAY = TABLET_PART and TABLET_PART:FindFirstChild("OrderDisplay")
local DISPLAY_FRAME = ORDER_DISPLAY and ORDER_DISPLAY:FindFirstChildOfClass("Frame")

-- Remotes
local deliveryResult = RemoteManager.Get("DeliveryResult")
local hudUpdate      = RemoteManager.Get("HUDUpdate")

-- ─── STATE ────────────────────────────────────────────────────────────────────
local npcs        = {}  -- npcId -> npc data
local npcQueue    = {}  -- ordered list: npcIds currently in the POS queue
local pendingBoxes = {} -- cookieId -> { boxId, carrier, npcId }
local nextNpcId   = 1

-- ─── HELPERS ──────────────────────────────────────────────────────────────────
local function countNPCs()
    local n = 0
    for _ in pairs(npcs) do n += 1 end
    return n
end

local function getPatienceTime()
    local pc = math.max(1, #Players:GetPlayers())
    return BASE_PATIENCE + (pc - 1) * PATIENCE_PER_PLAYER
end

local function formatTime(secs)
    local s = math.max(0, math.floor(secs))
    return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

local function getQueuePos(slot)
    if not QUEUE_FOLDER then return nil end
    local part = QUEUE_FOLDER:FindFirstChild("QueueSpot" .. slot)
    return part and (part.Position + Vector3.new(0, 2, 0)) or nil
end

local function getSpawnCFrame()
    local p = SPAWN_PART and SPAWN_PART.Position or Vector3.new(-5, 2, 30)
    return CFrame.new(p + Vector3.new(0, 2, 0))
end

local function getCounterPos()
    return COUNTER_PART and (COUNTER_PART.Position + Vector3.new(0, 2, 0)) or Vector3.new(20, 2, 20)
end

local function getFreeWaitSpot()
    if not WAITING_AREA then return nil end
    local used = {}
    for _, data in pairs(npcs) do
        if data.waitSpot then used[data.waitSpot] = true end
    end
    for _, spot in ipairs(WAITING_AREA:GetChildren()) do
        if spot:IsA("Part") and not used[spot.Name] then return spot end
    end
    return nil
end

local function calcPrice(cookieId, packSize)
    local cookie = CookieData.GetById(cookieId)
    return (cookie and cookie.price or 5) * packSize
end

local function pickRandomName()
    return NPC_NAMES[math.random(1, #NPC_NAMES)]
end

-- ─── TABLET DISPLAY ───────────────────────────────────────────────────────────
local function updateTabletDisplay(orderData)
    if not DISPLAY_FRAME then return end
    local header    = DISPLAY_FRAME:FindFirstChild("Header")
    local cookLbl   = DISPLAY_FRAME:FindFirstChild("CookieLabel")
    local priceLbl  = DISPLAY_FRAME:FindFirstChild("PriceLabel")
    local statusLbl = DISPLAY_FRAME:FindFirstChild("StatusLabel")

    if orderData then
        local cookie = CookieData.GetById(orderData.cookieId)
        if header    then header.Text    = orderData.isVIP and "VIP ORDER" or "CURRENT ORDER" end
        if cookLbl   then cookLbl.Text   = (cookie and cookie.name or orderData.cookieId) .. "  x" .. orderData.packSize end
        if priceLbl  then priceLbl.Text  = orderData.price .. " coins potential"            end
        if statusLbl then statusLbl.Text = orderData.status or "In kitchen..."              end
    else
        if header    then header.Text    = "NO ORDERS"                           end
        if cookLbl   then cookLbl.Text   = ""                                    end
        if priceLbl  then priceLbl.Text  = ""                                    end
        if statusLbl then statusLbl.Text = "Press E on customer to take order"   end
    end
end

-- ─── FORWARD DECLARATIONS ─────────────────────────────────────────────────────
local takeOrder, npcLeave, advanceQueue, addDeliverPrompt

-- ─── TAKE ORDER ───────────────────────────────────────────────────────────────
takeOrder = function(player, npcId)
    local data = npcs[npcId]
    if not data then return end
    if data.state ~= "waiting_in_queue" then return end
    if data.queueSlot ~= 1 then return end

    local cookie   = CookieData.GetRandom()
    local packSize = PACK_SIZES[math.random(1, #PACK_SIZES)]
    local price    = calcPrice(cookie.id, packSize)

    data.order = {
        cookieId   = cookie.id,
        cookieName = cookie.name,
        packSize   = packSize,
        price      = price,
        isVIP      = data.isVIP,
        orderId    = nil,
    }
    data.state = "ordered"
    NPCSpawner.SetPromptEnabled(data.model, false)

    -- Register with OrderManager (extras passed through)
    local order = OrderManager.AddNPCOrder(data.name, cookie.id, {
        packSize = packSize,
        price    = price,
        isVIP    = data.isVIP,
        npcId    = npcId,
    })
    data.order.orderId = order.orderId

    updateTabletDisplay({
        cookieId = cookie.id,
        packSize = packSize,
        price    = price,
        isVIP    = data.isVIP,
        status   = "In kitchen...",
    })

    -- Remove from queue then shift others forward
    for i, id in ipairs(npcQueue) do
        if id == npcId then
            table.remove(npcQueue, i)
            break
        end
    end
    advanceQueue()

    -- Walk to a waiting area spot
    local spot = getFreeWaitSpot()
    if spot then
        data.waitSpot = spot.Name
        data.state    = "walking_to_seat"
        data.cancelMove = NPCSpawner.MoveTo(data.model, spot.Position + Vector3.new(0, 2, 0), function()
            if npcs[npcId] then data.state = "seated" end
        end)
    else
        data.state = "seated"
    end

    print(string.format("[NPCController] %s ordered %dx %s | price=%d | orderId=%s",
        data.name, packSize, cookie.id, price, tostring(data.order.orderId)))
end

-- ─── NPC LEAVE ────────────────────────────────────────────────────────────────
npcLeave = function(npcId, reason)
    local data = npcs[npcId]
    if not data then return end
    if data.state == "leaving" then return end

    data.state = "leaving"
    NPCSpawner.SetPromptEnabled(data.model, false)

    if data.cancelMove then
        pcall(data.cancelMove)
        data.cancelMove = nil
    end

    for i, id in ipairs(npcQueue) do
        if id == npcId then
            table.remove(npcQueue, i)
            break
        end
    end

    if data.order and data.order.cookieId then
        local pending = pendingBoxes[data.order.cookieId]
        if pending and pending.npcId == npcId then
            pendingBoxes[data.order.cookieId] = nil
        end
    end

    npcs[npcId] = nil

    task.delay(1.5, function()
        NPCSpawner.Remove(data.model)
    end)

    advanceQueue()
    print(string.format("[NPCController] %s left (%s)", data.name, reason or "unknown"))
end

-- ─── ADVANCE QUEUE ────────────────────────────────────────────────────────────
advanceQueue = function()
    for pos, npcId in ipairs(npcQueue) do
        local data = npcs[npcId]
        if data then
            local wasFirst = (data.queueSlot == 1)
            data.queueSlot = pos

            if data.state == "waiting_in_queue" then
                if pos == 1 and not wasFirst then
                    NPCSpawner.SetPromptEnabled(data.model, true)
                elseif pos ~= 1 then
                    NPCSpawner.SetPromptEnabled(data.model, false)
                end
                local newPos = getQueuePos(pos)
                if newPos then
                    if data.cancelMove then pcall(data.cancelMove) end
                    data.cancelMove = NPCSpawner.MoveTo(data.model, newPos, function() end)
                end
            end
        end
    end
end

-- ─── ADD DELIVER PROMPT ───────────────────────────────────────────────────────
addDeliverPrompt = function(npcId)
    local data = npcs[npcId]
    if not data then return end
    local head = data.model:FindFirstChild("Head")
    if not head then return end

    local existing = head:FindFirstChild("DeliverPrompt")
    if existing then existing:Destroy() end

    local pp = Instance.new("ProximityPrompt")
    pp.Name                  = "DeliverPrompt"
    pp.ActionText            = "Deliver Box"
    pp.ObjectText            = data.name
    pp.MaxActivationDistance = 8
    pp.HoldDuration          = 0
    pp.Parent                = head

    pp.Triggered:Connect(function(player)
        local d = npcs[npcId]
        if not d or d.state ~= "at_counter" then return end

        local pending = pendingBoxes[d.order.cookieId]
        if not pending or pending.npcId ~= npcId then
            warn("[NPCController] No pending box for", d.name)
            return
        end

        if pending.carrier ~= player.Name then
            warn("[NPCController] Wrong carrier:", player.Name, "vs", pending.carrier)
            return
        end

        local ok, quality = OrderManager.DeliverBox(player, pending.boxId, d.order.orderId)
        if not ok then
            warn("[NPCController] DeliverBox failed for", player.Name)
            return
        end

        pendingBoxes[d.order.cookieId] = nil

        local qMult = 0.5 + (quality / 100) * 1.0
        local coins  = math.floor(d.order.price * qMult)
        if d.isVIP then coins = math.floor(coins * 1.5) end
        local stars  = math.floor(1 + (quality / 100) * 4)
        local xp     = math.floor(coins * 0.3)

        PlayerDataManager.AddCoins(player, coins)
        PlayerDataManager.AddXP(player, xp)
        local profile = PlayerDataManager.GetData(player)

        deliveryResult:FireClient(player, stars, coins, xp)
        hudUpdate:FireClient(player,
            profile and profile.coins or 0,
            profile and profile.xp    or 0,
            nil)

        updateTabletDisplay(nil)

        print(string.format("[NPCController] %s delivered to %s | q=%d%% coins=%d stars=%d",
            player.Name, d.name, quality, coins, stars))

        npcLeave(npcId, "delivered")
    end)
end

-- ─── PATIENCE TICKER ──────────────────────────────────────────────────────────
local function startPatienceTicker(npcId)
    task.spawn(function()
        while true do
            task.wait(1)
            local data = npcs[npcId]
            if not data then break end

            if data.state == "waiting_in_queue" or data.state == "seated" then
                data.patience -= 1
                NPCSpawner.SetTimerText(data.model, formatTime(data.patience))
                if data.patience <= 0 then
                    npcLeave(npcId, "patience_expired")
                    break
                end
            else
                NPCSpawner.SetTimerText(data.model, "")
            end
        end
    end)
end

-- ─── SPAWN NPC ────────────────────────────────────────────────────────────────
local function spawnNPC()
    if countNPCs() >= MAX_NPCS_IN_SCENE then return end
    if #npcQueue >= MAX_QUEUE_SIZE then return end

    local slot  = #npcQueue + 1
    local npcId = nextNpcId
    nextNpcId  += 1

    local name  = pickRandomName()
    local isVIP = math.random() < VIP_CHANCE

    local model = NPCSpawner.CreateNPC({
        name        = name,
        isVIP       = isVIP,
        spawnCFrame = getSpawnCFrame(),
    })
    if not model then return end

    local data = {
        id              = npcId,
        name            = name,
        model           = model,
        isVIP           = isVIP,
        state           = "queuing",
        patience        = getPatienceTime(),
        queueSlot       = slot,
        waitSpot        = nil,
        order           = nil,
        cancelMove      = nil,
        promptConnected = false,
        assignedBoxId   = nil,
    }
    npcs[npcId] = data
    table.insert(npcQueue, npcId)

    local queuePos = getQueuePos(slot)
    if queuePos then
        data.cancelMove = NPCSpawner.MoveTo(model, queuePos, function()
            local d = npcs[npcId]
            if not d then return end
            d.state      = "waiting_in_queue"
            d.cancelMove = nil

            -- Connect order prompt once
            if not d.promptConnected then
                d.promptConnected = true
                local pp = NPCSpawner.GetPrompt(model)
                if pp then
                    pp.Triggered:Connect(function(player)
                        local current = npcs[npcId]
                        if current
                            and current.queueSlot == 1
                            and current.state == "waiting_in_queue"
                        then
                            takeOrder(player, npcId)
                        end
                    end)
                end
            end

            if d.queueSlot == 1 then
                NPCSpawner.SetPromptEnabled(model, true)
            end
        end)
    else
        data.state = "waiting_in_queue"
        if slot == 1 then NPCSpawner.SetPromptEnabled(model, true) end
    end

    startPatienceTicker(npcId)
    print(string.format("[NPCController] Spawned %s (id=%d, VIP=%s, slot=%d)", name, npcId, tostring(isVIP), slot))
end

-- ─── BOX READY → CALL NPC TO COUNTER ─────────────────────────────────────────
OrderManager.On("BoxCreated", function(box)
    if not box.cookieId then return end

    -- Find a seated NPC waiting for this cookie type
    for npcId, data in pairs(npcs) do
        if data.state == "seated" and data.order and data.order.cookieId == box.cookieId then
            data.state         = "walking_to_counter"
            data.assignedBoxId = box.boxId
            pendingBoxes[box.cookieId] = {
                boxId   = box.boxId,
                carrier = box.carrier,
                npcId   = npcId,
            }

            data.cancelMove = NPCSpawner.MoveTo(data.model, getCounterPos(), function()
                local d = npcs[npcId]
                if not d then return end
                d.state      = "at_counter"
                d.cancelMove = nil
                addDeliverPrompt(npcId)
                print(string.format("[NPCController] %s at counter, ready for delivery", d.name))
            end)

            print(string.format("[NPCController] Calling %s to counter (box #%d, %s)",
                data.name, box.boxId, box.cookieId))
            break
        end
    end
end)

-- ─── SPAWN LOOP ───────────────────────────────────────────────────────────────
task.spawn(function()
    task.wait(5)  -- wait for map to load
    while true do
        spawnNPC()
        task.wait(SPAWN_INTERVAL)
    end
end)

-- Stagger second NPC so there are usually 2 in queue
task.delay(15, spawnNPC)

-- ─── CLEANUP ON PLAYER REMOVE ─────────────────────────────────────────────────
Players.PlayerRemoving:Connect(function(player)
    for cookieId, pending in pairs(pendingBoxes) do
        if pending.carrier == player.Name then
            pendingBoxes[cookieId] = nil
        end
    end
end)

print("[NPCController] Ready")
