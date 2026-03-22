-- OrderManager
-- Manages cookie batches through the full pipeline:
-- Mix → Dough → [Fridge per cookie type, max 4 batches] → Oven →
--   needsFrost=true  → Frost → Warmers → Dress
--   needsFrost=false → Warmers → Dress

local Players    = game:GetService("Players")
local CookieData = require(script.Parent:WaitForChild("CookieData"))

local OrderManager = {}

-- ============================================================
-- CONSTANTS
-- ============================================================
-- M-5: dynamic cap — 1 active batch per player, minimum 2
-- (computed at call time so it scales as players join/leave)
local MIN_ACTIVE_BATCHES = 2
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
    -- M-5: scale cap with current player count
    local maxBatches = math.max(MIN_ACTIVE_BATCHES, #Players:GetPlayers())
    if count >= maxBatches then
        warn("[OrderManager] Max active batches reached (" .. maxBatches .. ")")
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
            quantity   = 6,
        })
        print(string.format("[OrderManager] Batch #%d baked → needs frost (snapshot %d%%)", batchId, snapshot))
    else
        -- Goes straight to warmers
        table.insert(warmers, {
            batchId    = batchId,
            cookieId   = entry.cookieId,
            needsFrost = false,
            snapshot   = snapshot,
            quantity   = 6,
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
function OrderManager.RecordFrostScore(playerName, batchId, score, snapshot, cookieId)
    frostPending[playerName] = {
        batchId  = batchId,
        score    = score,
        snapshot = snapshot,
    }
    print(string.format("[OrderManager] Batch #%d frosted by %s (%d%%)", batchId, playerName, score))
    -- After frost, cookie moves to warmers for dress (needsFrost=false now)
    table.insert(warmers, {
        batchId    = batchId,
        cookieId   = cookieId,  -- preserved for dress minigame display
        needsFrost = false,
        snapshot   = snapshot,
        frostScore = score,
        quantity   = 6,
    })
    notify("WarmersUpdated", OrderManager.GetWarmerState())
end

-- Takes a specific cookie type from dress-ready warmers (used by DressStationServer)
function OrderManager.TakeFromWarmersByType(cookieId, quantity)
    quantity = quantity or 1
    for i, entry in ipairs(warmers) do
        if not entry.needsFrost and entry.cookieId == cookieId then
            local entryQty = entry.quantity or 1
            if entryQty <= quantity then
                -- Take the whole entry
                table.remove(warmers, i)
                notify("WarmersUpdated", OrderManager.GetWarmerState())
                return entry
            else
                -- Partial take: deduct and return a clone with its own batchId.
                -- Sharing a batchId between clones causes postOvenScores to be
                -- cleared by the first CreateBox, making subsequent CreateBox calls fail.
                entry.quantity -= quantity
                notify("WarmersUpdated", OrderManager.GetWarmerState())
                local clone = {}
                for k, v in pairs(entry) do clone[k] = v end
                clone.quantity = quantity
                -- Give the clone a fresh batchId and copy the post-oven scores to it
                local subId = nextBatch
                nextBatch += 1
                clone.batchId = subId
                local src = postOvenScores[entry.batchId]
                if src then
                    postOvenScores[subId] = { mix = src.mix, dough = src.dough, oven = src.oven }
                end
                return clone
            end
        end
    end
    return nil
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
        boxId           = id,
        batchId         = batchId,
        quality         = finalQuality,
        carrier         = player.Name,
        status          = "ready",
        cookieId        = warmerEntry and warmerEntry.cookieId or nil,
        _warmerEntry    = warmerEntry,
        _postOvenScores = { mix = post.mix, dough = post.dough, oven = post.oven },
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

-- M-8: returns true if the player currently has a box in the "carrying" state
function OrderManager.IsCarryingBox(player)
    for _, box in pairs(boxes) do
        if box.carrier == player.Name and box.status == "carrying" then
            return true
        end
    end
    return false
end

function OrderManager.DeliverBox(player, boxId, npcOrderId)
    local box = boxes[boxId]
    if not box then return false end
    if box.status ~= "carrying" then
        warn(string.format("[AntiExploit] DeliverBox rejected: box #%d not in carrying state (status=%s)", boxId, tostring(box.status)))
        return false
    end
    if box.carrier ~= player.Name then
        warn(string.format("[AntiExploit] DeliverBox rejected: %s tried to deliver box #%d carried by %s",
            player.Name, boxId, tostring(box.carrier)))
        return false
    end

    local order = nil
    for i, o in ipairs(npcOrders) do
        if o.orderId == npcOrderId then
            -- Validate order↔box compatibility before consuming order
            if o.isVariety then
                if not box.isVariety then
                    warn(string.format("[AntiExploit] DeliverBox rejected: box #%d is not variety for variety order #%d", boxId, npcOrderId))
                    return false
                end
            else
                if box.cookieId ~= o.cookieId then
                    warn(string.format("[AntiExploit] DeliverBox rejected: cookie mismatch box=%s order=%s",
                        tostring(box.cookieId), tostring(o.cookieId)))
                    return false
                end
            end
            order = table.remove(npcOrders, i)
            break
        end
    end
    if not order then
        warn(string.format("[AntiExploit] DeliverBox rejected: order #%s not found for box #%d", tostring(npcOrderId), boxId))
        return false
    end
    box.status = "delivered"

    print(string.format("[OrderManager] Box #%d delivered by %s | Quality: %d%% | NPC: %s",
        boxId, player.Name, box.quality, order and order.npcName or "unknown"))

    notify("BoxDelivered", { box = box, npcOrder = order })
    boxes[boxId] = nil
    return true, box.quality
end

-- ============================================================
-- NPC ORDER QUEUE
-- ============================================================
-- extras: optional { packSize, price, isVIP, npcId, items }
-- items = array of cookieId strings for variety packs (e.g. {"pink_sugar","pink_sugar","lemon_blackraspberry"})
function OrderManager.AddNPCOrder(npcName, cookieId, extras)
    local id = nextOrder
    nextOrder += 1
    local order = {
        orderId   = id,
        npcName   = npcName,
        cookieId  = cookieId,
        packSize  = extras and extras.packSize or 1,
        price     = extras and extras.price    or 0,
        isVIP     = extras and extras.isVIP    or false,
        npcId     = extras and extras.npcId    or nil,
        items     = extras and extras.items    or nil,   -- variety pack slot array
        isVariety = not not (extras and extras.items),
        orderedAt = tick(),
    }
    table.insert(npcOrders, order)
    local label = order.isVariety and ("VARIETY ×" .. order.packSize) or (cookieId .. " ×" .. order.packSize)
    print(string.format("[OrderManager] NPC order #%d: %s wants %s (price=%d)", id, npcName, label, order.price))
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

function OrderManager.GetWarmerStockByCookieId()
    local counts = {}
    for _, entry in ipairs(warmers) do
        if not entry.needsFrost and entry.cookieId then
            counts[entry.cookieId] = (counts[entry.cookieId] or 0) + (entry.quantity or 1)
        end
    end
    return counts
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

-- Variety box: averages scores across multiple collected warmer entries
function OrderManager.CreateVarietyBox(player, entries, dressScore)
    if not entries or #entries == 0 then
        warn("[OrderManager] CreateVarietyBox: no entries"); return nil
    end

    local totalMix, totalDough, totalOven, totalFrost, count = 0, 0, 0, 0, 0
    for _, entry in ipairs(entries) do
        local post = postOvenScores[entry.batchId]
        if post then
            totalMix   += post.mix   or 0
            totalDough += post.dough or 0
            totalOven  += post.oven  or 0
            totalFrost += entry.frostScore or 0
            count += 1
        end
    end
    if count == 0 then
        warn("[OrderManager] CreateVarietyBox: no valid post-oven scores"); return nil
    end

    local finalQuality = math.clamp(math.floor(
        (totalMix   / count) * STATION_WEIGHT.mix   +
        (totalDough / count) * STATION_WEIGHT.dough +
        (totalOven  / count) * STATION_WEIGHT.oven  +
        (totalFrost / count) * STATION_WEIGHT.frost +
        dressScore            * STATION_WEIGHT.dress
    ), 0, 100)

    -- Save post-oven scores before clearing, so CancelBox can restore them
    local savedScores = {}
    for _, entry in ipairs(entries) do
        if postOvenScores[entry.batchId] then
            savedScores[entry.batchId] = {
                mix   = postOvenScores[entry.batchId].mix,
                dough = postOvenScores[entry.batchId].dough,
                oven  = postOvenScores[entry.batchId].oven,
            }
        end
    end
    for _, entry in ipairs(entries) do postOvenScores[entry.batchId] = nil end

    local id = nextBox; nextBox += 1
    local box = {
        boxId               = id,
        batchId             = entries[1].batchId,
        quality             = finalQuality,
        carrier             = player.Name,
        status              = "ready",
        cookieId            = "variety",
        isVariety           = true,
        _warmerEntries      = entries,
        _batchPostOvenScores = savedScores,
    }
    boxes[id] = box
    print(string.format("[OrderManager] Variety Box #%d created by %s | Quality: %d%%", id, player.Name, finalQuality))
    notify("BoxCreated", box)
    return box
end

-- Cancel a box and return its cookies to warmers (called when NPC leaves mid-delivery)
function OrderManager.CancelBox(boxId)
    local box = boxes[boxId]
    if not box then return end

    if box._warmerEntry then
        -- Single box: restore the one warmer entry
        table.insert(warmers, 1, box._warmerEntry)
        notify("WarmersUpdated", OrderManager.GetWarmerState())
        if box._postOvenScores and box.batchId then
            postOvenScores[box.batchId] = box._postOvenScores
        end
    elseif box._warmerEntries then
        -- Variety box: restore all warmer entries
        for _, entry in ipairs(box._warmerEntries) do
            table.insert(warmers, 1, entry)
        end
        notify("WarmersUpdated", OrderManager.GetWarmerState())
        if box._batchPostOvenScores then
            for batchId, scores in pairs(box._batchPostOvenScores) do
                postOvenScores[batchId] = scores
            end
        end
    end

    boxes[boxId] = nil
    print(string.format("[OrderManager] Box #%d cancelled — cookies returned to warmer", boxId))
end

-- Remove an NPC order from the queue (called when NPC leaves before delivery)
function OrderManager.CancelNPCOrder(orderId)
    for i, o in ipairs(npcOrders) do
        if o.orderId == orderId then
            table.remove(npcOrders, i)
            print(string.format("[OrderManager] NPC order #%d cancelled", orderId))
            notify("NPCOrderCancelled", orderId)
            return true
        end
    end
    return false
end

-- Per-cookieId counts for dress-ready (needsFrost=false) warmer entries
function OrderManager.GetWarmerCountsByType()
    local counts = {}
    for _, entry in ipairs(warmers) do
        if not entry.needsFrost then
            local id = entry.cookieId or "unknown"
            counts[id] = (counts[id] or 0) + (entry.quantity or 1)
        end
    end
    return counts
end

-- Returns a previously-reserved warmer entry back to the warmers list.
-- Called when a player cancels a locked dress order.
function OrderManager.ReturnToWarmers(entry)
    if not entry then return end
    table.insert(warmers, entry)
    notify("WarmersUpdated", OrderManager.GetWarmerState())
end

-- RemapWarmerCookieIds(oldToNew)
-- Called by StationRemapService after each shift remap.
-- Updates cookieId on every pending warmer entry so TakeFromWarmersByType
-- matches the physical warmer's new CookieId attribute.
function OrderManager.RemapWarmerCookieIds(oldToNew)
    for _, entry in ipairs(warmers) do
        local newId = oldToNew[entry.cookieId]
        if newId then
            entry.cookieId = newId
        end
    end
end

-- m2: clear postOvenScores entry when a session is abandoned (player disconnect mid-frost/dress)
function OrderManager.ClearPostOvenScore(batchId)
    postOvenScores[batchId] = nil
end

-- ============================================================
-- SHIFT RESET
-- Called at the start of each shift cycle (before PreOpen).
-- Wipes all pipeline state so stock does not accumulate across shifts.
-- Listeners, counters (nextBatch/nextOrder/nextBox), and registered
-- callbacks are intentionally preserved.
-- ============================================================
function OrderManager.Reset()
    batches        = {}
    fridges        = {}
    ovenBatches    = {}
    warmers        = {}
    frostPending   = {}
    postOvenScores = {}
    npcOrders      = {}
    boxes          = {}
    -- Push empty state to all display listeners
    notify("FridgeUpdated",  OrderManager.GetFridgeState())
    notify("WarmersUpdated", OrderManager.GetWarmerState())
    notify("BatchUpdated",   OrderManager.GetBatchState())
    print("[OrderManager] Reset — pipeline state cleared for new shift")
end

return OrderManager
