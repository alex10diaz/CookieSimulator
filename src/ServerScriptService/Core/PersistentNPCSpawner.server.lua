-- NPCController (PersistentNPCSpawner)
-- Full NPC customer lifecycle:
--   spawn → walk to queue → wait → player takes order →
--   walk to seat → wait → box ready → walk to counter →
--   player delivers → NPC leaves

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace           = game:GetService("Workspace")
local PhysicsService      = game:GetService("PhysicsService")

local NPCSpawner        = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("NPCSpawner"))
local OrderManager      = require(ServerScriptService:WaitForChild("Core"):WaitForChild("OrderManager"))
local CookieData        = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CookieData"))
local RemoteManager     = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local EconomyManager    = require(ServerScriptService:WaitForChild("Core"):WaitForChild("EconomyManager"))
local PlayerDataManager = require(ServerScriptService:WaitForChild("Core"):WaitForChild("PlayerDataManager"))
local SessionStats          = require(ServerScriptService:WaitForChild("Core"):WaitForChild("SessionStats"))
local DailyChallengeManager  = require(ServerScriptService:WaitForChild("Core"):WaitForChild("DailyChallengeManager"))
local WeeklyChallengeManager   = require(ServerScriptService:WaitForChild("Core"):WaitForChild("WeeklyChallengeManager"))
local LifetimeChallengeManager = require(ServerScriptService:WaitForChild("Core"):WaitForChild("LifetimeChallengeManager"))
local MenuManager              = require(ServerScriptService:WaitForChild("Core"):WaitForChild("MenuManager"))
local GamepassManager          = require(ServerScriptService:WaitForChild("Core"):WaitForChild("GamepassManager"))

-- ─── CONSTANTS ────────────────────────────────────────────────────────────────
local MAX_NPCS_IN_SCENE    = 6
local MAX_QUEUE_SIZE       = 3
local SPAWN_INTERVAL       = 60   -- seconds between NPC spawn attempts
local RUSH_SPAWN_INTERVAL  = 20   -- spawn interval during Rush Hour
local BASE_PATIENCE        = 120     -- seconds at 1 player
local PATIENCE_PER_PLAYER  = 20      -- extra seconds per additional player
local VIP_CHANCE           = 0.10
local PACK_SIZES           = { 1, 4, 6 }
local VARIETY_PACK_SIZES   = { 4, 6 }
local VARIETY_CHANCE       = 0.40  -- 40% chance of variety pack when 2+ types in warmer

local SPAWN_STATES = { "Open" }  -- NPCs only arrive when the store is open

math.randomseed(tick())  -- Seed RNG so VIP rolls aren't identical each run
local callNPCToCounter  -- forward-declared; defined later in file

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
local boxCarriedRemote         = RemoteManager.Get("BoxCarried")          -- H-8: carry indicator
local deliveryResult           = RemoteManager.Get("DeliveryResult")
local hudUpdate                = RemoteManager.Get("HUDUpdate")
local startOrderCutsceneRemote = RemoteManager.Get("StartOrderCutscene")
local confirmOrderRemote       = RemoteManager.Get("ConfirmNPCOrder")
local forceDropBoxRemote       = RemoteManager.Get("ForceDropBox")
local npcOrderCancelledRemote  = RemoteManager.Get("NPCOrderCancelledClient")
local comboUpdateRemote        = RemoteManager.Get("ComboUpdate")       -- S-9
local npcOrderFailedRemote     = RemoteManager.Get("NPCOrderFailed")    -- S-4
local npcPatienceRemote        = RemoteManager.Get("NPCPatienceUpdate") -- S-6
local npcOrderReadyRemote      = RemoteManager.Get("NPCOrderReady")
local deliveryFeedbackRemote   = RemoteManager.Get("DeliveryFeedback")

-- ─── STATE ────────────────────────────────────────────────────────────────────
local rushHourActive = false  -- set by RushHourStart/End BindableEvents

local npcs        = {}  -- npcId -> npc data
local npcQueue    = {}  -- ordered list: npcIds currently in the POS queue
local pendingBoxes = {} -- "npc_<id>" -> { boxId, carrier, npcId }
local nextNpcId   = 1

-- BUG-13: Register "NPCs" collision group so NPC HumanoidRootParts do not
-- collide with each other (prevents ceiling-lift when NPCs converge in doorways).
do
    local ok = pcall(function()
        PhysicsService:RegisterCollisionGroup("NPCs")
        PhysicsService:CollisionGroupSetCollidable("NPCs", "NPCs", false)
    end)
    if not ok then
        -- Group may already exist (server restart); ensure non-collidable
        pcall(function()
            PhysicsService:CollisionGroupSetCollidable("NPCs", "NPCs", false)
        end)
    end
end

local function pendingKeyForNpc(npcId)
    return "npc_" .. tostring(npcId)
end

-- ─── HELPERS ──────────────────────────────────────────────────────────────────

-- Build a display label for variety orders: "C&C x2, Pink Sugar, Snickerdoodle"
local function buildVarietyLabel(items)
    if not items or #items == 0 then return "Mix" end
    local counts = {}; local order = {}
    for _, id in ipairs(items) do
        if not counts[id] then counts[id] = 0; table.insert(order, id) end
        counts[id] += 1
    end
    local parts = {}
    for _, id in ipairs(order) do
        local cookie = CookieData.GetById(id)
        local name   = cookie and cookie.name or id
        local cnt    = counts[id]
        table.insert(parts, cnt > 1 and (name .. " x" .. cnt) or name)
    end
    return table.concat(parts, ", ")
end

local function countNPCs()
    local n = 0
    for _ in pairs(npcs) do n += 1 end
    return n
end

local function getPatienceTime()
    local pc = math.max(1, #Players:GetPlayers())
    local base = BASE_PATIENCE + (pc - 1) * PATIENCE_PER_PLAYER
    -- Apply patience upgrade from any player in server (co-op benefit)
    local patienceBonus = 0
    for _, p in ipairs(Players:GetPlayers()) do
        local stations, _ = PlayerDataManager.GetUnlocks(p)
        local hasP2, hasP1 = false, false
        for _, id in ipairs(stations) do
            if id == "patience_boost_2" then hasP2 = true end
            if id == "patience_boost_1" then hasP1 = true end
        end
        local bonus = hasP2 and 20 or (hasP1 and 10 or 0)
        if bonus > patienceBonus then patienceBonus = bonus end
    end
    return base + patienceBonus
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

-- Returns true if the current game state allows NPC spawning.
local function isSpawnAllowed()
    local state = Workspace:GetAttribute("GameState") or "Lobby"
    for _, s in ipairs(SPAWN_STATES) do
        if state == s then return true end
    end
    return false
end

-- Rotates the NPC to face the nearest POS station model.
local POS_FOLDER = Workspace:WaitForChild("POS", 10)

-- Face NPC toward a world position (flattened to XZ plane).
-- H-1 fix: wait 0.2s so Humanoid pathfinding fully settles, then disable
-- AutoRotate while snapping CFrame so physics can't override it.
local function facePosition(npcModel, targetPos)
    task.spawn(function()
        task.wait(0.2)
        local hrp = npcModel and npcModel:FindFirstChild("HumanoidRootPart")
        local hum = npcModel and npcModel:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then return end
        local npcPos = hrp.Position
        local dir = Vector3.new(targetPos.X - npcPos.X, 0, targetPos.Z - npcPos.Z)
        if dir.Magnitude > 0.1 then
            hum.AutoRotate = false
            hrp.CFrame = CFrame.new(npcPos, npcPos + dir)
            hrp.AssemblyLinearVelocity  = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
            task.wait(0.1)
            hum.AutoRotate = true
        end
    end)
end

local function faceClosestPOS(npcModel)
    if not POS_FOLDER then return end
    local hrp = npcModel:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local npcPos     = hrp.Position
    local bestTarget = nil
    local bestDist   = math.huge
    for _, child in ipairs(POS_FOLDER:GetChildren()) do
        if child:IsA("Model") and child.Name ~= "DisplayBox" then
            local cf, _ = child:GetBoundingBox()
            local dist  = (cf.Position - npcPos).Magnitude
            if dist < bestDist then
                bestDist   = dist
                bestTarget = cf.Position
            end
        end
    end
    if bestTarget then
        local dir = Vector3.new(bestTarget.X - npcPos.X, 0, bestTarget.Z - npcPos.Z)
        if dir.Magnitude > 0.1 then
            hrp.CFrame = CFrame.new(npcPos, npcPos + dir)
        end
    end
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
        if header  then header.Text  = orderData.isVIP and "VIP ORDER" or "CURRENT ORDER" end
        if cookLbl then
            cookLbl.Text = orderData.items
                and ("Variety Pack  ×" .. orderData.packSize)
                or  ((cookie and cookie.name or orderData.cookieId) .. "  x" .. orderData.packSize)
        end
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

    -- Force pink_sugar during tutorial
    local isTutorial = player:GetAttribute("InTutorial")
    local cookie, packSize, price, varItems

    if isTutorial then
        cookie   = CookieData.GetById("pink_sugar")
        packSize = PACK_SIZES[math.random(1, #PACK_SIZES)]
        price    = calcPrice(cookie.id, packSize)
    else
        -- Check warmer stock for variety eligibility
        local warmerCounts   = OrderManager.GetWarmerCountsByType()
        local availableTypes = {}
        for cId, cnt in pairs(warmerCounts) do
            if cnt > 0 then table.insert(availableTypes, cId) end
        end

        if #availableTypes >= 2 and math.random() < VARIETY_CHANCE then
            -- ── Variety pack ──────────────────────────────────────────────────
            packSize = VARIETY_PACK_SIZES[math.random(1, #VARIETY_PACK_SIZES)]
            local numTypes = math.random(2, math.min(#availableTypes, packSize))

            -- Shuffle available types
            for i = #availableTypes, 2, -1 do
                local j = math.random(i)
                availableTypes[i], availableTypes[j] = availableTypes[j], availableTypes[i]
            end
            local chosenTypes = {}
            for i = 1, numTypes do chosenTypes[i] = availableTypes[i] end

            -- Distribute slots (each type gets ≥1, extras random)
            local slotCounts = {}
            for _, t in ipairs(chosenTypes) do slotCounts[t] = 1 end
            local rem = packSize - numTypes
            while rem > 0 do
                local t = chosenTypes[math.random(1, #chosenTypes)]
                slotCounts[t] += 1
                rem -= 1
            end

            -- m8: validate warmer has enough stock to cover each type's slot count
            local stockOk = true
            for t, need in pairs(slotCounts) do
                if (warmerCounts[t] or 0) < need then stockOk = false; break end
            end
            if not stockOk then
                -- Not enough stock for this variety distribution — fall back to single-type
                cookie   = CookieData.GetRandomFromMenu(MenuManager.GetActiveMenu())
                packSize = PACK_SIZES[math.random(1, #PACK_SIZES)]
                price    = calcPrice(cookie.id, packSize)
            else

            -- Build & shuffle items array
            varItems = {}
            for _, t in ipairs(chosenTypes) do
                for _ = 1, slotCounts[t] do table.insert(varItems, t) end
            end
            for i = #varItems, 2, -1 do
                local j = math.random(i)
                varItems[i], varItems[j] = varItems[j], varItems[i]
            end

            -- Primary cookie = most expensive (for payout calc)
            local maxP = 0
            cookie = CookieData.GetById(chosenTypes[1])
            for _, t in ipairs(chosenTypes) do
                local c = CookieData.GetById(t)
                if c and (c.price or 0) > maxP then maxP = c.price; cookie = c end
            end

            -- Price = sum of each type's price × slot count
            price = 0
            for t, cnt in pairs(slotCounts) do
                local c = CookieData.GetById(t)
                price += (c and c.price or 5) * cnt
            end
            end -- close stockOk else
        else
            -- ── Single-type order ─────────────────────────────────────────────
            cookie   = CookieData.GetRandomFromMenu(MenuManager.GetActiveMenu())
            packSize = PACK_SIZES[math.random(1, #PACK_SIZES)]
            price    = calcPrice(cookie.id, packSize)
        end
    end

    -- Store order data — confirmed in Step 2 (confirmOrder)
    data.order = {
        cookieId   = cookie.id,
        cookieName = varItems and "Variety Pack" or cookie.name,
        packSize   = packSize,
        price      = price,
        isVIP      = data.isVIP,
        orderId    = nil,
        items      = varItems,
        isVariety  = varItems ~= nil,
    }
    data.state            = "cutscene_pending"
    data.triggeringPlayer = player  -- track who triggered so PlayerRemoving confirms the right player
    data.cancelMove       = nil     -- NPC is stationary at slot 1; clear any stale handle
    NPCSpawner.SetPromptEnabled(data.model, false)

    -- Advance queue now so next NPC can move up
    for i, id in ipairs(npcQueue) do
        if id == npcId then
            table.remove(npcQueue, i)
            break
        end
    end
    advanceQueue()

    -- Fire cutscene to this player
    startOrderCutsceneRemote:FireClient(player, {
        npcId      = npcId,
        npcName    = data.name,
        cookieId   = cookie.id,
        cookieName = data.order.cookieName,
        packSize   = packSize,
        baseCoins  = price,
        isVIP      = data.isVIP,
        items      = varItems,
    })

    local logLabel = varItems and ("VARIETY ×" .. packSize) or (cookie.id .. " x" .. packSize)
    print(string.format("[NPCController] Cutscene fired to %s for NPC %s (%s)",
        player.Name, data.name, logLabel))
end

-- ─── CONFIRM ORDER (called when client dismisses cutscene) ────────────────────
local function confirmOrder(player, npcId)
    local data = npcs[npcId]
    if not data then
        warn("[NPCController] confirmOrder: npcId not found:", npcId)
        return
    end
    if data.state ~= "cutscene_pending" then
        warn("[NPCController] confirmOrder: unexpected state:", data.state)
        return
    end
    if data.triggeringPlayer and data.triggeringPlayer ~= player then
        warn("[AntiExploit] " .. player.Name .. " tried to confirm another player's cutscene npcId=" .. tostring(npcId))
        return
    end
    data.triggeringPlayer = nil  -- clear now that cutscene is resolved

    -- Register with OrderManager
    local order = OrderManager.AddNPCOrder(data.name, data.order.cookieId, {
        packSize = data.order.packSize,
        price    = data.order.price,
        isVIP    = data.order.isVIP,
        npcId    = npcId,
        items    = data.order.items,
    })
    data.order.orderId = order.orderId
    data.state = "ordered"
    npcOrderReadyRemote:FireAllClients(order.orderId, data.order.cookieId)

    -- Update 3D tablet display
    updateTabletDisplay({
        cookieId = data.order.cookieId,
        packSize = data.order.packSize,
        price    = data.order.price,
        isVIP    = data.order.isVIP,
        status   = "In kitchen...",
    })

    -- Update player's HUD active order label
    pcall(function()
        local label = data.order.isVariety
            and buildVarietyLabel(data.order.items)
            or  (data.order.cookieName .. " x" .. data.order.packSize)
        hudUpdate:FireClient(player, nil, nil, label, order.orderId)
    end)

    -- Walk to a waiting area spot
    local spot = getFreeWaitSpot()
    if spot then
        data.waitSpot   = spot.Name
        data.state      = "walking_to_seat"
        data.cancelMove = NPCSpawner.MoveTo(data.model, spot.Position + Vector3.new(0, 2, 0), function()
            local d = npcs[npcId]
            if not d then return end
            d.state = "seated"
            if d.pendingCallToCounter then
                d.pendingCallToCounter = nil
                callNPCToCounter(npcId)
            end
        end)
        -- Safety timeout: if still walking_to_seat after 12s (pathfinding stuck),
        -- force to seated so pendingCallToCounter can fire.
        task.delay(12, function()
            local d = npcs[npcId]
            if d and d.state == "walking_to_seat" then
                warn("[NPCController] " .. d.name .. " stuck walking to seat — forcing seated")
                d.state = "seated"
                if d.cancelMove then pcall(d.cancelMove); d.cancelMove = nil end
                if d.pendingCallToCounter then
                    d.pendingCallToCounter = nil
                    callNPCToCounter(npcId)
                end
            end
        end)
    else
        data.state = "seated"
    end

    print(string.format("[NPCController] Order confirmed: %s %dx %s | price=%d | orderId=%s",
        data.name, data.order.packSize,
        data.order.isVariety and "VARIETY" or data.order.cookieId,
        data.order.price, tostring(data.order.orderId)))
end

confirmOrderRemote.OnServerEvent:Connect(function(player, npcId)
    if type(npcId) ~= "number" then return end
    confirmOrder(player, npcId)
end)

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

    -- Cancel any box made for this NPC and return cookies to warmer
    -- Search by npcId so variety boxes (keyed as "variety") are also found
    local pendingKey, pending = nil, nil
    for key, pb in pairs(pendingBoxes) do
        if pb.npcId == npcId then pendingKey = key; pending = pb; break end
    end
    if pending then
        OrderManager.CancelBox(pending.boxId)
        if pending.carrier then
            local carrier = Players:FindFirstChild(pending.carrier)
            if carrier then
                forceDropBoxRemote:FireClient(carrier)
                boxCarriedRemote:FireClient(carrier, nil)  -- BUG-73: clear carryPill
                -- Destroy physical carry model and restore player arms
                local boxModel = workspace:FindFirstChild("CarriedBox_" .. pending.carrier)
                if boxModel then boxModel:Destroy() end
                local char = carrier.Character
                local torso = char and char:FindFirstChild("Torso")
                if torso then
                    local rs = torso:FindFirstChild("Right Shoulder")
                    local ls = torso:FindFirstChild("Left Shoulder")
                    if rs then rs.C0 = CFrame.new(1,  0.5, 0) * CFrame.Angles(0,  math.pi/2, 0) end
                    if ls then ls.C0 = CFrame.new(-1, 0.5, 0) * CFrame.Angles(0, -math.pi/2, 0) end
                end
            end
        end
        pendingBoxes[pendingKey] = nil
    end

    -- Remove this NPC's order from the KDS queue and notify all clients
    if data.order and data.order.orderId then
        OrderManager.CancelNPCOrder(data.order.orderId)
        -- Tell HUDController to remove this order from the active-order pill
        npcOrderCancelledRemote:FireAllClients(data.order.orderId, data.order.cookieId, data.order.packSize)
        -- S-4: if NPC left due to patience expiry, broadcast fail state + apply coin penalty
        if reason == "patience_expired" or reason == "counter_timeout" then
            do
                local _fHead = data.model and data.model:FindFirstChild("Head")
                npcOrderFailedRemote:FireAllClients(data.name, data.order.orderId, _fHead and _fHead.Position or nil)
            end
            SessionStats.RecordFail()
            -- Deduct penalty from all active players
            local FAIL_PENALTY = 75
            for _, p in ipairs(Players:GetPlayers()) do
                PlayerDataManager.AddCoins(p, -FAIL_PENALTY)
            end
            -- BUG-75: reset combo for all players when NPC leaves due to patience
            for _, p in ipairs(Players:GetPlayers()) do
                PlayerDataManager.ResetCombo(p)
                comboUpdateRemote:FireClient(p, 0)
            end
        end
    end

    npcs[npcId] = nil

    local exitModel = data.model
    local exitPos   = SPAWN_PART and (SPAWN_PART.Position + Vector3.new(0, 2, 0)) or Vector3.new(0, 2, 28)
    NPCSpawner.MoveTo(exitModel, exitPos, function() NPCSpawner.Remove(exitModel) end)
    task.delay(15, function() if exitModel and exitModel.Parent then exitModel:Destroy() end end)

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
                    local advModel = data.model
                    data.cancelMove = NPCSpawner.MoveTo(data.model, newPos, function()
                        -- BUG-2: re-face counter after advancing to new queue slot
                        facePosition(advModel, getCounterPos())
                    end)
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
    pp.MaxActivationDistance = 8    -- M-8: tightened from 20 (must be physically close)
    pp.HoldDuration          = 0
    pp.RequiresLineOfSight   = false
    pp.Parent                = head

    pp.Triggered:Connect(function(player)
        local d = npcs[npcId]
        if not d or d.state ~= "at_counter" then return end
        if d.deliveryLocked then return end
        d.deliveryLocked = true

        -- M-8: player must actually be carrying a box
        if not OrderManager.IsCarryingBox(player) then
            warn("[AntiExploit] " .. player.Name .. " triggered DeliverPrompt without a box")
            d.deliveryLocked = false
            return
        end

        -- Search by npcId (works for both single-type and variety boxes)
        local pendingKey, pending = nil, nil
        for key, pb in pairs(pendingBoxes) do
            if pb.npcId == npcId then pendingKey = key; pending = pb; break end
        end
        if not pending then
            warn("[NPCController] No pending box for", d.name)
            d.deliveryLocked = false
            return
        end

        if pending.carrier and pending.carrier ~= player.Name then
            warn("[NPCController] Wrong carrier:", player.Name, "vs", pending.carrier)
            d.deliveryLocked = false
            return
        end

        local ok, quality = OrderManager.DeliverBox(player, pending.boxId, d.order.orderId)
        if not ok then
            warn("[NPCController] DeliverBox failed for", player.Name)
            -- BUG-56: clear carry UI so player isn't stuck holding the box
            forceDropBoxRemote:FireClient(player)
            boxCarriedRemote:FireClient(player, nil)  -- BUG-73: clear carryPill on rejected delivery
            -- BUG-62: walk NPC out so they don't stand at counter forever
            npcLeave(npcId, "delivery_rejected")
            d.deliveryLocked = false
            return
        end

        -- Transfer physical box model to NPC's arm
        local transferEvent = ServerScriptService:FindFirstChild("BoxTransferToNPC")
        if transferEvent then transferEvent:Fire(player.Name, d.model) end

        pendingBoxes[pendingKey] = nil

        -- Stars from quality (0-100 weighted aggregate → 1-5 stars)
        local stars = math.clamp(math.floor(1 + (quality / 100) * 4), 1, 5)

        -- Combo: increment on ≥3 stars, reset below
        local comboStreak
        if stars >= 3 then
            comboStreak = PlayerDataManager.IncrementCombo(player)
        else
            PlayerDataManager.ResetCombo(player)
            comboStreak = 0
        end
        -- S-9: notify client of updated combo streak
        comboUpdateRemote:FireClient(player, comboStreak)

        -- Full payout via EconomyManager
        -- timeRemaining=0, totalTime=1 → speedMult=1.0 (no timer tracking in M4)
        local payout = EconomyManager.CalculatePayout(
            d.order.cookieId,
            d.order.packSize,
            stars,
            0,            -- timeRemaining (not tracked in M4)
            1,            -- totalTime
            comboStreak,
            d.isVIP
        )

        if rushHourActive then
            payout.coins = math.floor(payout.coins * 1.5)
        end
        -- BUG-25: VIPPass gives delivering player 1.5x coin bonus
        if GamepassManager.HasVIPPass(player) then
            payout.coins = math.floor(payout.coins * 1.5)
        end
        -- Apply tip upgrade for the delivering player
        do
            local stations, _ = PlayerDataManager.GetUnlocks(player)
            local hasTip2, hasTip1 = false, false
            for _, id in ipairs(stations) do
                if id == "tip_boost_2" then hasTip2 = true end
                if id == "tip_boost_1" then hasTip1 = true end
            end
            local mult = hasTip2 and 1.20 or (hasTip1 and 1.10 or 1.0)
            if mult > 1 then
                payout.coins = math.floor(payout.coins * mult)
            end
        end

        PlayerDataManager.RecordOrderComplete(player, stars == 5, d.order.packSize or 1)
        PlayerDataManager.AddCoins(player, payout.coins)
        PlayerDataManager.AddXP(player, payout.xp)
        local profile = PlayerDataManager.GetData(player)

        local coins = payout.coins
        local xp    = payout.xp

        deliveryResult:FireClient(player, stars, coins, xp, d.order.orderId)
        boxCarriedRemote:FireClient(player, nil)  -- H-8: clear carry indicator
        local _npcHead = d.model and d.model:FindFirstChild("Head")
        if _npcHead then deliveryFeedbackRemote:FireAllClients(_npcHead.Position, stars, player.Name) end
        do
            local _sse = game:GetService("ServerStorage"):FindFirstChild("Events")
            local _be  = _sse and _sse:FindFirstChild("DeliveryPayout")
            if _be then _be:Fire({ playerName = player.Name, coins = coins }) end
        end
        SessionStats.RecordDelivery(stars, payout.coins, comboStreak, d.order.packSize or 1)
        SessionStats.RecordStationScore(player, "dress", 1)  -- track deliveries for Employee of the Shift
        DailyChallengeManager.RecordDelivery(player, {
            stars       = stars,
            cookieId    = d.order.cookieId,
            coins       = payout.coins,
            comboStreak = comboStreak,
            packSize    = d.order.packSize or 1,
        })
        WeeklyChallengeManager.RecordDelivery(player, {
            stars       = stars,
            cookieId    = d.order.cookieId,
            coins       = payout.coins,
            comboStreak = comboStreak,
            packSize    = d.order.packSize or 1,
        })
        LifetimeChallengeManager.CheckAll(player)
        LifetimeChallengeManager.SendToPlayer(player)  -- BUG-78: refresh progress after each delivery
        -- Advance tutorial step 9 gate (replaces TestNPCSpawner dependency)
        do
            local _evts = game:GetService("ServerStorage"):FindFirstChild("Events")
            local _tde  = _evts and _evts:FindFirstChild("TutorialDelivered")
            if _tde then _tde:Fire(player) end
        end
        PlayerDataManager.AwardBakeryXP(player, 15 + stars * 5)
        hudUpdate:FireClient(player,
            profile and profile.coins or 0,
            profile and profile.xp    or 0,
            nil)

        updateTabletDisplay(nil)

        print(string.format("[NPCController] %s delivered to %s | q=%d%% coins=%d stars=%d",
            player.Name, d.name, quality, coins, stars))

        d.deliveryLocked = false
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

            if data.state == "seated" or data.state == "at_counter" then
                -- Patience only ticks after order is taken (seated/at_counter), not while waiting in queue
                data.patience -= 1
                NPCSpawner.SetTimerText(data.model, formatTime(data.patience))
                -- M-1: update in-world patience bar every tick
                local maxP = data.maxPatience or data.patience
                if maxP > 0 then
                    NPCSpawner.SetPatienceBar(data.model, data.patience / maxP)
                end
                -- S-6: broadcast patience ratio to all clients every 5 ticks
                if data.patience % 5 == 0 and data.order then
                    npcPatienceRemote:FireAllClients(
                        data.order.orderId,
                        data.patience,
                        data.maxPatience or data.patience,
                        data.model
                    )
                end
                -- Impatient head-bob at <=30% patience
                local maxP = data.maxPatience or data.patience
                if maxP > 0 and data.patience == math.floor(maxP * 0.30) then
                    local head = data.model and data.model:FindFirstChild("Head")
                    if head then
                        task.spawn(function()
                            local TW = game:GetService("TweenService")
                            local TI = TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 3, true)
                            local orig = head.CFrame
                            TW:Create(head, TI, { CFrame = orig * CFrame.Angles(0, 0, math.rad(12)) }):Play()
                        end)
                    end
                end
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

    -- BUG-13: Put NPC HRP in "NPCs" group — prevents HRP-HRP collisions between NPCs
    local npcHrp = model:FindFirstChild("HumanoidRootPart")
    if npcHrp then
        pcall(function()
            PhysicsService:SetPartCollisionGroup(npcHrp, "NPCs")
        end)
    end

    local data = {
        id              = npcId,
        name            = name,
        model           = model,
        isVIP           = isVIP,
        state           = "queuing",
        patience        = getPatienceTime(),
        maxPatience     = getPatienceTime(),  -- S-6: store initial value for ratio calc
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

            -- Face counter while waiting to order
            facePosition(model, getCounterPos())

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

    -- Safety: if still queuing after 15s (stuck on rope/barrier en route to queue spot),
    -- teleport directly to the queue position and transition to waiting_in_queue.
    task.delay(15, function()
        local d = npcs[npcId]
        if not d or d.state ~= "queuing" then return end
        warn("[NPCController] " .. d.name .. " stuck queuing — teleporting to queue spot")
        if d.cancelMove then pcall(d.cancelMove); d.cancelMove = nil end
        local qp = getQueuePos(d.queueSlot)
        if qp and d.model and d.model.PrimaryPart then
            d.model:SetPrimaryPartCFrame(CFrame.new(qp))
        end
        d.state = "waiting_in_queue"
        facePosition(d.model, getCounterPos())
        if not d.promptConnected then
            d.promptConnected = true
            local pp = NPCSpawner.GetPrompt(d.model)
            if pp then
                pp.Triggered:Connect(function(player)
                    local current = npcs[npcId]
                    if current and current.queueSlot == 1 and current.state == "waiting_in_queue" then
                        takeOrder(player, npcId)
                    end
                end)
            end
        end
        if d.queueSlot == 1 then
            NPCSpawner.SetPromptEnabled(d.model, true)
        end
    end)

    startPatienceTicker(npcId)
    print(string.format("[NPCController] Spawned %s (id=%d, VIP=%s, slot=%d)", name, npcId, tostring(isVIP), slot))
end

-- ─── BOX READY → CALL NPC TO COUNTER ─────────────────────────────────────────
local COUNTER_TIMEOUT = 90  -- seconds before NPC gives up at counter

callNPCToCounter = function(npcId)
    local data = npcs[npcId]
    if not data then return end
    -- BUG-94: spread multiple counter NPCs laterally to prevent visual pile-up
    local counterSlot = 0
    for id, d in pairs(npcs) do
        if id ~= npcId and (d.state == "at_counter" or d.state == "walking_to_counter") then
            counterSlot += 1
        end
    end
    local counterTarget = getCounterPos() + Vector3.new(counterSlot * 2.5, 0, 0)
    data.state      = "walking_to_counter"
    data.cancelMove = NPCSpawner.MoveTo(data.model, counterTarget, function()
        local d = npcs[npcId]
        if not d then return end
        d.state      = "at_counter"
        d.cancelMove = nil
        addDeliverPrompt(npcId)
        print(string.format("[NPCController] %s at counter, ready for delivery", d.name))
        task.delay(COUNTER_TIMEOUT, function()
            local still = npcs[npcId]
            if still and still.state == "at_counter" then
                npcLeave(npcId, "counter_timeout")
            end
        end)
    end)
end

OrderManager.On("BoxCreated", function(box)
    if not box.cookieId then return end

    -- Find an NPC waiting for this box (seated, walking to seat, or just ordered)
    for npcId, data in pairs(npcs) do
        local cookieMatch  = not box.isVariety and data.order and data.order.cookieId == box.cookieId
        local varietyMatch = box.isVariety and data.order and data.order.isVariety == true
        local stateOk      = data.state == "seated" or data.state == "walking_to_seat" or data.state == "ordered"
        if stateOk and (cookieMatch or varietyMatch) then
            data.assignedBoxId = box.boxId
            -- If box was made by an AI worker (not a real player), any player can deliver
            local isRealPlayer = Players:FindFirstChild(box.carrier) ~= nil
            pendingBoxes[pendingKeyForNpc(npcId)] = {
                boxId   = box.boxId,
                carrier = isRealPlayer and box.carrier or nil,
                npcId   = npcId,
            }
            -- H-8: notify the carrier so the HUD carry pill shows the NPC name
            if isRealPlayer then
                local carrierPlayer = Players:FindFirstChild(box.carrier)
                if carrierPlayer then
                    boxCarriedRemote:FireClient(carrierPlayer, data.name)
                end
            end

            if data.state == "seated" then
                callNPCToCounter(npcId)
            else
                -- NPC is still walking to their seat; flag them to head to counter once seated
                data.pendingCallToCounter = true
            end

            print(string.format("[NPCController] Calling %s to counter (box #%d, %s)",
                data.name, box.boxId, box.cookieId))
            break
        end
    end
end)

-- ─── TUTORIAL NPC (BUG-46) ───────────────────────────────────────────────────
-- Spawns a pre-ordered tutorial NPC with chocolate_chip × 6 directly in
-- "ordered" state, bypassing the queue/GameState check.
-- Fired by TutorialController after the player completes the oven step (step 3→4).
local function spawnTutorialNPC()
    local npcId    = nextNpcId
    nextNpcId     += 1
    local name     = "Tutorial Customer"
    local cookieId = "chocolate_chip"
    local packSize = 6
    local cookie   = CookieData.GetById(cookieId)
    local price    = (cookie and cookie.price or 5) * packSize

    local model = NPCSpawner.CreateNPC({
        name        = name,
        isVIP       = false,
        spawnCFrame = getSpawnCFrame(),
    })
    if not model then
        warn("[NPCController] spawnTutorialNPC: failed to create NPC model")
        return
    end

    -- BUG-13: keep tutorial NPC out of the NPC-NPC collision group
    local npcHrp = model:FindFirstChild("HumanoidRootPart")
    if npcHrp then
        pcall(function() PhysicsService:SetPartCollisionGroup(npcHrp, "NPCs") end)
    end

    -- Register order in OrderManager so the Dress KDS shows it
    local order = OrderManager.AddNPCOrder(name, cookieId, {
        packSize = packSize,
        price    = price,
        isVIP    = false,
        npcId    = npcId,
        items    = nil,
    })

    local maxP = getPatienceTime() * 3  -- generous patience for tutorial
    local data = {
        id              = npcId,
        name            = name,
        model           = model,
        isVIP           = false,
        state           = "ordered",  -- skip queue; order already placed
        patience        = maxP,
        maxPatience     = maxP,
        queueSlot       = nil,
        waitSpot        = nil,
        order           = {
            cookieId   = cookieId,
            cookieName = cookie and cookie.name or cookieId,
            packSize   = packSize,
            price      = price,
            isVIP      = false,
            orderId    = order.orderId,
            isVariety  = false,
            items      = nil,
        },
        cancelMove      = nil,
        promptConnected = false,
        assignedBoxId   = nil,
    }
    npcs[npcId] = data

    npcOrderReadyRemote:FireAllClients(order.orderId, cookieId)

    -- Walk NPC to a free waiting area spot
    local spot = getFreeWaitSpot()
    if spot then
        data.waitSpot   = spot.Name
        data.state      = "walking_to_seat"
        data.cancelMove = NPCSpawner.MoveTo(data.model, spot.Position + Vector3.new(0, 2, 0), function()
            local d = npcs[npcId]
            if not d then return end
            d.state = "seated"
            if d.pendingCallToCounter then
                d.pendingCallToCounter = nil
                callNPCToCounter(npcId)
            end
        end)
        task.delay(12, function()
            local d = npcs[npcId]
            if d and d.state == "walking_to_seat" then
                d.state = "seated"
                if d.cancelMove then pcall(d.cancelMove); d.cancelMove = nil end
                if d.pendingCallToCounter then
                    d.pendingCallToCounter = nil
                    callNPCToCounter(npcId)
                end
            end
        end)
    else
        data.state = "seated"
    end

    startPatienceTicker(npcId)
    print(string.format("[NPCController] Tutorial NPC spawned: %s (id=%d, %s x%d, orderId=%s)",
        name, npcId, cookieId, packSize, tostring(order.orderId)))
end

-- Listen for SpawnTutorialNPC BindableEvent (created by TutorialController's fix)
task.spawn(function()
    local evts = game:GetService("ServerStorage"):WaitForChild("Events", 10)
    if not evts then warn("[NPCController] ServerStorage/Events not found for SpawnTutorialNPC"); return end
    local e = evts:WaitForChild("SpawnTutorialNPC", 15)
    if not e then warn("[NPCController] SpawnTutorialNPC BindableEvent not found"); return end
    e.Event:Connect(function()
        spawnTutorialNPC()
    end)
    print("[NPCController] SpawnTutorialNPC gate wired")
end)

-- ─── SPAWN LOOP ───────────────────────────────────────────────────────────────
task.spawn(function()
    task.wait(2)  -- brief startup buffer before first spawn attempt
    while true do
        if isSpawnAllowed() then spawnNPC() end
        task.wait(rushHourActive and RUSH_SPAWN_INTERVAL or SPAWN_INTERVAL)
    end
end)

-- Stagger a second NPC 25s after game opens
task.delay(25, function()
    if isSpawnAllowed() then spawnNPC() end
end)

-- Empty-lobby fast-spawn: if Open and no NPCs present, spawn after 10s gap
task.spawn(function()
    while true do
        task.wait(10)
        if isSpawnAllowed() and countNPCs() == 0 then
            spawnNPC()
        end
    end
end)

-- Spawn NPCs immediately when Open phase begins (no 60s wait)
workspace:GetAttributeChangedSignal("GameState"):Connect(function()
    local state = workspace:GetAttribute("GameState")
    if state == "Open" then
        task.wait(2)
        spawnNPC()
        task.delay(20, function()
            if isSpawnAllowed() then spawnNPC() end
        end)
    elseif state == "EndOfDay" then
        -- Clear all active NPCs immediately when the shift ends
        local ids = {}
        for id in pairs(npcs) do ids[#ids+1] = id end
        for _, id in ipairs(ids) do
            npcLeave(id, "end_of_day")
        end
    end
end)

-- ─── CLEANUP ON PLAYER REMOVE ─────────────────────────────────────────────────
Players.PlayerRemoving:Connect(function(player)
    -- Collect keys first to avoid undefined behavior when mutating during pairs()
    local boxesToRemove = {}
    for key, pending in pairs(pendingBoxes) do
        if pending.carrier == player.Name then
            table.insert(boxesToRemove, key)
        end
    end
    for _, key in ipairs(boxesToRemove) do
        pendingBoxes[key] = nil
    end

    -- Auto-confirm any NPC this player triggered that is stuck in cutscene_pending
    for npcId, data in pairs(npcs) do
        if data.state == "cutscene_pending" and data.triggeringPlayer == player then
            confirmOrder(player, npcId)
        end
    end
end)

-- (duplicate GameState listener removed — first one at line ~887 handles this)

-- Wire Rush Hour BindableEvents
local ssEvents = game:GetService("ServerStorage"):FindFirstChild("Events")
if ssEvents then
    local rushStartBE = ssEvents:FindFirstChild("RushHourStart")
    local rushEndBE   = ssEvents:FindFirstChild("RushHourEnd")
    if rushStartBE then rushStartBE.Event:Connect(function() rushHourActive = true  end) end
    if rushEndBE   then rushEndBE.Event:Connect(function()   rushHourActive = false end) end
end

print("[NPCController] Ready")
