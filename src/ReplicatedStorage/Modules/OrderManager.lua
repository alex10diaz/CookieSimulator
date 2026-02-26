-- OrderManager
-- Manages cookie batches through the full pipeline:
-- Mix → Dough → [Fridge per cookie type, max 4 batches] → Oven →
--   needsFrost=true  → Frost → Warmers → Dress
--   needsFrost=false → Warmers → Dress

local CookieData = require(script.Parent:WaitForChild("CookieData"))

local OrderManager = {}

-- ============================================================
-- CONSTANTS
-- ============================================================
local MAX_ACTIVE_BATCHES = 2   -- batches in Mix/Dough stage at once
local MAX_FRIDGE_BATCHES = 4   -- per fridge (per cookie type)

local STATION_WEIGHT = {
    mix   = 0.25,
    dough = 0.15,
    oven  = 0.25,
    frost = 0.15,
    dress = 0.25,
}

-- ============================================================
-- STATE
-- ============================================================
-- Active batches (mix/dough stage only)
local batches    = {}   -- batchId -> batch

-- Fridges: fridgeId -> list of { batchId, cookieId, doughScore, mixScore }
local fridges    = {}

-- Oven slots (batches currently baking): batchId -> { cookieId, scores, needsFrost }
local ovenBatches = {}

-- Warmers: list of { batchId, cookieId, quality, needsFrost=false (already resolved) }
local warmers    = {}

-- Frost pending per player: playerName -> { batchId, cookieId, warmerQuality }
local frostPending = {}

-- Scores for post-warmer stages keyed by batchId
local postOvenScores = {}  -- batchId -> { mix, dough, oven, frost(optional) }

-- NPC order queue
local npcOrders  = {}

-- Boxes ready for delivery
local boxes      = {}

local nextBatch  = 1
local nextOrder  = 1
local nextBox    = 1

-- ============================================================
-- LISTENERS
-- ============================================================
local listeners = {}

local function notify(event, data)
    if not listeners[event] then return end
    for _, cb in ipairs(listeners[event]) do cb(data) end
end

function OrderManager.On(event, callback)
    if not listeners[event] then listeners[event] = {} end
    table.insert(listeners[event], callback)
end

-- ============================================================
-- BATCH CREATION (Mix stage)
-- ============================================================
function OrderManager.TryStartBatch(player, cookieId)
    local count = 0
    for _ in pairs(batches) do count += 1 end
    if count >= MAX_ACTIVE_BATCHES then
        warn("[OrderManager] Max active batches reached")
        return nil
    end

    local id = nextBatch
    nextBatch += 1

    batches[id] = {
        batchId   = id,
        cookieId  = cookieId,
        stage     = "mix",
        scores    = {},
        startedBy = player.Name,
    }

    print(string.format("[OrderManager] Batch #%d started (%s) by %s", id, cookieId or "?", player.Name))
    notify("BatchUpdated", OrderManager.GetBatchState())
    return id
end

-- ============================================================
-- STATION SCORE — Mix and Dough
-- After dough, batch auto-moves to the correct fridge.
-- ============================================================
function OrderManager.RecordStationScore(player, station, score, batchId)
    local batch = batches[batchId]
    if not batch then
        warn("[OrderManager] Batch not found:", batchId)
        return false
    end

    if batch.stage ~= station then
        warn(string.format("[OrderManager] Stage mismatch: expected '%s', got '%s'", batch.stage, station))
        return false
    end

    batch.scores[station] = score
    print(string.format("[OrderManager] Batch #%d | %s scored %d%%", batchId, station, score))

    if station == "mix" then
        batch.stage = "dough"
        notify("BatchUpdated", OrderManager.GetBatchState())

    elseif station == "dough" then
        -- Move to fridge
        local cookieId = batch.cookieId
        local fridgeId = cookieId and CookieData.GetFridgeId(cookieId)

        if not fridgeId then
            warn("[OrderManager] No fridgeId for cookie:", cookieId)
            return false
        end

        if not fridges[fridgeId] then fridges[fridgeId] = {} end
        if #fridges[fridgeId] >= MAX_FRIDGE_BATCHES then
            warn("[OrderManager] Fridge full:", fridgeId)
            return false
        end

        table.insert(fridges[fridgeId], {
            batchId  = batchId,
            cookieId = cookieId,
            scores   = { mix = batch.scores.mix, dough = score },
        })

        batches[batchId] = nil
        print(string.format("[OrderManager] Batch #%d → fridge '%s' (%d/4)", batchId, fridgeId, #fridges[fridgeId]))
        notify("FridgeUpdated", OrderManager.GetFridgeState())
        notify("BatchUpdated", OrderManager.GetBatchState())
    end

    return true
end

-- ============================================================
-- FRIDGE → OVEN
-- Player pulls dough from a specific fridge and starts baking.
-- ============================================================
function OrderManager.PullFromFridge(player, fridgeId)
    local fridge = fridges[fridgeId]
    if not fridge or #fridge == 0 then
        warn("[OrderManager] Fridge empty:", fridgeId)
        return nil
    end

    local entry = table.remove(fridge, 1)
    local cookie = CookieData.GetById(entry.cookieId)

    ovenBatches[entry.batchId] = {
        batchId    = entry.batchId,
        cookieId   = entry.cookieId,
        needsFrost = cookie and cookie.needsFrost or false,
        scores     = entry.scores,
        pulledBy   = player.Name,
    }

    print(string.format("[OrderManager] Batch #%d pulled from fridge by %s → oven", entry.batchId, player.Name))
    notify("FridgeUpdated", OrderManager.GetFridgeState())
    return entry.batchId
end

-- ============================================================
-- OVEN SCORE
-- After baking: needsFrost=true → frost queue, false → warmers
-- ============================================================
function OrderManager.RecordOvenScore(player, score, batchId)
    local entry = ovenBatches[batchId]
    if not entry then
        warn("[OrderManager] No oven batch:", batchId)
        return false
    end

    entry.scores.oven = score
    ovenBatches[batchId] = nil

    -- Partial quality snapshot (mix + dough + oven weighted)
    local partialQuality = math.floor(
        (entry.scores.mix   or 0) * STATION_WEIGHT.mix   +
        (entry.scores.dough or 0) * STATION_WEIGHT.dough +
        score                     * STATION_WEIGHT.oven
    )
    -- Scale snapshot to 0-100 based only on weights accounted for so far
    local weightSoFar = STATION_WEIGHT.mix + STATION_WEIGHT.dough + STATION_WEIGHT.oven
    local snapshot = math.floor(partialQuality / weightSoFar)

    -- Store scores for later stages
    postOvenScores[batchId] = {
        mix   = entry.scores.mix   or 0,
        dough = entry.scores.dough or 0,
        oven  = score,
    }

    if entry.needsFrost then
        -- Goes to frost queue (represented as a frost-warmers entry)
        table.insert(warmers, {
            batchId    = batchId,
            cookieId   = entry.cookieId,
            needsFrost = true,
            snapshot   = snapshot,
        })
        print(string.format("[OrderManager] Batch #%d baked → needs frost (snapshot %d%%)", batchId, snapshot))
    else
        -- Goes straight to warmers
        table.insert(warmers, {
            batchId    = batchId,
            cookieId   = entry.cookieId,
            needsFrost = false,
            snapshot   = snapshot,
        })
        print(string.format("[OrderManager] Batch #%d baked → warmers directly (snapshot %d%%)", batchId, snapshot))
    end

    notify("WarmersUpdated", OrderManager.GetWarmerState())
    return true
end

-- ============================================================
-- WARMER ACCESS
-- Players at Frost or Dress pull from warmers.
-- Frost players should only pull needsFrost=true entries.
-- Dress players should only pull needsFrost=false entries.
-- ============================================================
function OrderManager.TakeFromWarmers(wantsForFrost)
    for i, entry in ipairs(warmers) do
        if entry.needsFrost == wantsForFrost then
            table.remove(warmers, i)
            notify("WarmersUpdated", OrderManager.GetWarmerState())
            return entry
        end
    end
    warn("[OrderManager] No suitable cookie in warmers (wantsForFrost=" .. tostring(wantsForFrost) .. ")")
    return nil
end

function OrderManager.GetWarmerCount()
    local forFrost, forDress = 0, 0
    for _, e in ipairs(warmers) do
        if e.needsFrost then forFrost += 1 else forDress += 1 end
    end
    return forFrost, forDress
end

-- ============================================================
-- FROST SCORE
-- ============================================================
function OrderManager.RecordFrostScore(playerName, batchId, score, snapshot)
    frostPending[playerName] = {
        batchId  = batchId,
        score    = score,
        snapshot = snapshot,
    }
    print(string.format("[OrderManager] Batch #%d frosted by %s (%d%%)", batchId, playerName, score))
    -- After frost, cookie moves to warmers for dress (needsFrost=false now)
    table.insert(warmers, {
        batchId    = batchId,
        cookieId   = nil,  -- already tracked in postOvenScores
        needsFrost = false,
        snapshot   = snapshot,
        frostScore = score,
    })
    notify("WarmersUpdated", OrderManager.GetWarmerState())
end

function OrderManager.GetFrostPending(playerName)
    return frostPending[playerName]
end

function OrderManager.ClearFrostPending(playerName)
    frostPending[playerName] = nil
end

-- ============================================================
-- DRESS / BOX CREATION
-- ============================================================
function OrderManager.CreateBox(player, batchId, dressScore, warmerEntry)
    local post = postOvenScores[batchId]
    if not post then
        warn("[OrderManager] No post-oven scores for batch #" .. batchId)
        return nil
    end

    local frostScore = warmerEntry and warmerEntry.frostScore or 0

    local finalQuality = math.floor(
        (post.mix   or 0) * STATION_WEIGHT.mix   +
        (post.dough or 0) * STATION_WEIGHT.dough +
        (post.oven  or 0) * STATION_WEIGHT.oven  +
        frostScore        * STATION_WEIGHT.frost  +
        dressScore        * STATION_WEIGHT.dress
    )
    finalQuality = math.clamp(finalQuality, 0, 100)

    local id = nextBox
    nextBox += 1

    local box = {
        boxId    = id,
        batchId  = batchId,
        quality  = finalQuality,
        carrier  = player.Name,
        status   = "ready",
    }

    boxes[id] = box
    postOvenScores[batchId] = nil

    print(string.format("[OrderManager] Box #%d created by %s | Quality: %d%%", id, player.Name, finalQuality))
    notify("BoxCreated", box)
    return box
end

-- ============================================================
-- BOX CARRY & DELIVER
-- ============================================================
function OrderManager.PickupBox(player, boxId)
    local box = boxes[boxId]
    if not box then return false end
    box.carrier = player.Name
    box.status  = "carrying"
    notify("BoxUpdated", box)
    return true
end

function OrderManager.DeliverBox(player, boxId, npcOrderId)
    local box = boxes[boxId]
    if not box then return false end
    box.status = "delivered"

    local order = nil
    for i, o in ipairs(npcOrders) do
        if o.orderId == npcOrderId then
            order = table.remove(npcOrders, i)
            break
        end
    end

    print(string.format("[OrderManager] Box #%d delivered by %s | Quality: %d%% | NPC: %s",
        boxId, player.Name, box.quality, order and order.npcName or "unknown"))

    notify("BoxDelivered", { box = box, npcOrder = order })
    boxes[boxId] = nil
    return true, box.quality
end

-- ============================================================
-- NPC ORDER QUEUE
-- ============================================================
function OrderManager.AddNPCOrder(npcName, cookieId)
    local id = nextOrder
    nextOrder += 1
    local order = { orderId = id, npcName = npcName, cookieId = cookieId }
    table.insert(npcOrders, order)
    print(string.format("[OrderManager] NPC order #%d: %s wants %s", id, npcName, cookieId))
    notify("NPCOrderAdded", order)
    return order
end

function OrderManager.GetNPCOrders()
    return npcOrders
end

-- ============================================================
-- STATE SNAPSHOTS
-- ============================================================
function OrderManager.GetBatchState()
    local list = {}
    for _, b in pairs(batches) do
        table.insert(list, { batchId = b.batchId, stage = b.stage, cookieId = b.cookieId })
    end
    local frostCount, dressCount = OrderManager.GetWarmerCount()
    return {
        batches       = list,
        activeBatches = (function() local c=0 for _ in pairs(batches) do c+=1 end return c end)(),
        warmerForFrost = frostCount,
        warmerForDress = dressCount,
        npcOrders     = npcOrders,
    }
end

function OrderManager.GetFridgeState()
    local state = {}
    for fridgeId, entries in pairs(fridges) do
        state[fridgeId] = #entries
    end
    return state
end

function OrderManager.GetWarmerState()
    local frostCount, dressCount = OrderManager.GetWarmerCount()
    return { forFrost = frostCount, forDress = dressCount }
end

-- ============================================================
-- LOOKUP HELPERS
-- ============================================================
function OrderManager.GetBatchAtStage(stage)
    for _, b in pairs(batches) do
        if b.stage == stage then return b end
    end
    return nil
end

function OrderManager.GetBatch(batchId)
    return batches[batchId]
end

function OrderManager.GetOvenBatch(batchId)
    return ovenBatches[batchId]
end

return OrderManager
