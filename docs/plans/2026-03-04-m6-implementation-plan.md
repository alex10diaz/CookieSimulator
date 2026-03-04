# M6: Meta Systems — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement Rush Hour events, Golden VIP NPCs, session + global leaderboards, 3-slot save system, station/cosmetic unlock shop, and AntiExploit guards.

**Architecture:** All game-critical state is server-authoritative. EventManager ↔ PersistentNPCSpawner communicate via BindableEvents only (no direct require). Leaderboards use Roblox OrderedDataStore (9 stores: 3 stats × 3 timeframes). Save slots use 3 separate DataStore keys per player plus a meta-key for the active slot. Unlock shop validates all purchases server-side.

**Tech Stack:** Roblox DataStoreService (DataStore + OrderedDataStore), RemoteEvents, BindableEvents, SurfaceGui (back room boards), ScreenGui (shop + slot select UI), ProximityPrompts.

---

## Task 1: GameStateManager — Reduce Open phase to 10 minutes

**Files:**
- Modify: `src/ServerScriptService/Core/GameStateManager.server.lua`

**Step 1: Edit file**

Change line 13:
```lua
-- BEFORE
local OPEN_DURATION     = 15 * 60  -- 15 minutes

-- AFTER
local OPEN_DURATION     = 10 * 60  -- 10 minutes (M6)
```

**Step 2: Sync to Studio via MCP**
```lua
-- MCP run_code:
local sss = game:GetService("ServerScriptService")
local s = sss.Core.GameStateManager
local src = s.Source
s.Source = src:gsub("15 %* 60  %-%- 15 minutes", "10 * 60  -- 10 minutes (M6)", 1)
print("Patched OPEN_DURATION: " .. (s.Source:find("10 %* 60") and "OK" or "MISS"))
```

**Step 3: Verify**
Play test. Console should show: `[GameStateManager] → Open (600s)`

**Step 4: Commit**
```bash
git add src/ServerScriptService/Core/GameStateManager.server.lua
git commit -m "feat(m6): reduce Open phase duration to 10 minutes"
```

---

## Task 2: SessionStats — Add cookies-baked counter

**Files:**
- Modify: `src/ServerScriptService/Core/SessionStats.lua`
- Modify: `src/ServerScriptService/Core/PersistentNPCSpawner.server.lua` (update caller)

**Step 1: Edit SessionStats.lua**

Replace the entire file:
```lua
-- ServerScriptService/Core/SessionStats (ModuleScript)
-- Tracks aggregate per-cycle delivery stats for the EndOfDay summary.

local SessionStats = {}

local data = {
    orders       = 0,
    coins        = 0,
    cookiesBaked = 0,
    totalStars   = 0,
    peakCombo    = 0,
}

function SessionStats.RecordDelivery(stars, coins, comboStreak, cookieCount)
    data.orders       += 1
    data.coins        += (coins or 0)
    data.cookiesBaked += (cookieCount or 1)
    data.totalStars   += (stars or 0)
    if (comboStreak or 0) > data.peakCombo then
        data.peakCombo = comboStreak
    end
end

function SessionStats.GetSummary()
    local avgStars = data.orders > 0
        and math.floor((data.totalStars / data.orders) * 10 + 0.5) / 10
        or  0
    return {
        orders       = data.orders,
        coins        = data.coins,
        cookiesBaked = data.cookiesBaked,
        combo        = data.peakCombo,
        avgStars     = avgStars,
    }
end

function SessionStats.Reset()
    data.orders       = 0
    data.coins        = 0
    data.cookiesBaked = 0
    data.totalStars   = 0
    data.peakCombo    = 0
end

return SessionStats
```

**Step 2: Update PersistentNPCSpawner caller**

Find the line (~422): `SessionStats.RecordDelivery(stars, payout.coins, comboStreak)`

You need the pack size at that point. Look for the local variable holding pack size (likely `npcData.packSize` or similar). Update:
```lua
-- BEFORE
SessionStats.RecordDelivery(stars, payout.coins, comboStreak)

-- AFTER
SessionStats.RecordDelivery(stars, payout.coins, comboStreak, npcData.packSize or 1)
```
(Replace `npcData.packSize` with whatever variable name holds the order's pack size at that line — search above it for the pack size variable.)

**Step 3: Sync both to Studio via MCP**
Patch SessionStats source and PersistentNPCSpawner source via MCP run_code.

**Step 4: Verify**
Complete a delivery. Trigger EndOfDay. Summary console output should include `cookiesBaked`.

**Step 5: Commit**
```bash
git add src/ServerScriptService/Core/SessionStats.lua src/ServerScriptService/Core/PersistentNPCSpawner.server.lua
git commit -m "feat(m6): add cookiesBaked counter to SessionStats"
```

---

## Task 3: MinigameServer — AntiExploit session gating + sanity checks

**Files:**
- Modify: `src/ServerScriptService/Minigames/MinigameServer.server.lua`

**Step 1: Patch `endSession` function**

Find `endSession` (line ~103). Replace the top of the function (before the `local batchId` line) with:
```lua
local function endSession(player, stationName, score)
    local session = activeSessions[player]
    if not session then
        warn("[AntiExploit] " .. player.Name .. " fired " .. stationName .. " result with no active session")
        return
    end
    if session.station ~= stationName then
        warn("[AntiExploit] " .. player.Name .. " station mismatch (expected " .. session.station .. ", got " .. stationName .. ")")
        return
    end
    if type(score) ~= "number" then
        warn("[AntiExploit] " .. player.Name .. " sent non-number score: " .. tostring(score))
        return
    end

    local batchId = session.batchId
    activeSessions[player] = nil
    score = math.clamp(score, 0, 100)
    -- rest of function unchanged below
```

**Step 2: Add cookieId cross-reference for mix results**

In `endSession`, inside the `if stationName == "mix" then` block, add before `OrderManager.RecordStationScore`:
```lua
    if stationName == "mix" then
        -- Validate cookieId was assigned by server (not spoofable)
        if not session.cookieId then
            warn("[AntiExploit] " .. player.Name .. " mix session missing cookieId")
            activeSessions[player] = nil
            return
        end
        OrderManager.RecordStationScore(player, "mix", score, batchId)
```

**Step 3: Add delivery validation to PersistentNPCSpawner**

In PersistentNPCSpawner, find the delivery result handler (the section where a player triggers the DeliverPrompt). Add at the top of that handler:
```lua
-- Validate box carrier matches player
if not pendingBoxes[someKey] or pendingBoxes[someKey].carrier ~= player.Name then
    warn("[AntiExploit] " .. player.Name .. " delivery carrier mismatch")
    return
end
```
(The exact variable name depends on how the pending box lookup works — read that section first to find the right check. The design calls for: box carrier must match requesting player + boxId must exist in active order table + stars clamped to [1,5].)

Also ensure wherever stars are computed: `stars = math.clamp(stars, 1, 5)`

**Step 4: Sync to Studio via MCP**

**Step 5: Verify**
Play test — complete a minigame normally. Verify no AntiExploit warns appear. Check console is clean.
Then attempt to fire a result remote without a session (via Studio command bar) and confirm the warn fires and nothing breaks.

**Step 6: Commit**
```bash
git add src/ServerScriptService/Minigames/MinigameServer.server.lua src/ServerScriptService/Core/PersistentNPCSpawner.server.lua
git commit -m "feat(m6): add AntiExploit session gating and sanity checks"
```

---

## Task 4: PlayerDataManager — 3-slot save system

**Files:**
- Modify: `src/ServerScriptService/Core/PlayerDataManager.lua`

**Step 1: Understand current layout**

Current: store name `PlayerData_v1`, key `"Player_" .. userId`.
New: same store, keys `"Slot_" .. userId .. "_1/2/3"` + meta-key `"SlotMeta_" .. userId`.

**Step 2: Rewrite PlayerDataManager.lua**

Replace entire file:
```lua
-- ServerScriptService/Core/PlayerDataManager (ModuleScript)
-- 3-slot save system. Each slot is independent. Meta-key tracks active slot.
-- Slot switching only allowed between sessions (not during Open phase).

local Players          = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local Workspace        = game:GetService("Workspace")

local playerStore = DataStoreService:GetDataStore("PlayerData_v1")

local DEFAULT_PROFILE = {
    coins             = 0,
    xp                = 0,
    level             = 1,
    comboStreak       = 0,
    ordersCompleted   = 0,
    perfectOrders     = 0,
    failedOrders      = 0,
    tutorialCompleted = false,
    rebirths          = 0,
    unlockedRecipes   = {"chocolate_chip"},
    ownedMachines     = {},
    ratingScore       = 0,
    stats             = { fastestOrderTime = math.huge },
    unlockedStations  = {},
    unlockedCosmetics = {},
}

local profiles    = {}  -- userId -> active slot profile (in memory)
local activeSlots = {}  -- userId -> slot number (1, 2, or 3)

-- ── HELPERS ────────────────────────────────────────────────────
local function newProfile()
    local p = {}
    for k, v in pairs(DEFAULT_PROFILE) do
        if type(v) == "table" then
            local copy = {}
            for k2, v2 in pairs(v) do copy[k2] = v2 end
            p[k] = copy
        else
            p[k] = v
        end
    end
    return p
end

local function mergeDefaults(saved)
    local p = newProfile()
    for k, v in pairs(saved) do p[k] = v end
    return p
end

local function deepCopy(t)
    local copy = {}
    for k, v in pairs(t) do
        copy[k] = type(v) == "table" and deepCopy(v) or v
    end
    return copy
end

local function slotKey(userId, slot)
    return "Slot_" .. userId .. "_" .. slot
end

local function metaKey(userId)
    return "SlotMeta_" .. userId
end

-- ── DATASTORE ──────────────────────────────────────────────────
local function loadMeta(userId)
    local ok, result = pcall(function()
        return playerStore:GetAsync(metaKey(userId))
    end)
    if ok and result and result.activeSlot then
        return result.activeSlot
    end
    return 1  -- default to slot 1
end

local function saveMeta(userId, slot)
    pcall(function()
        playerStore:SetAsync(metaKey(userId), { activeSlot = slot })
    end)
end

local function loadSlot(userId, slot)
    local ok, result = pcall(function()
        return playerStore:GetAsync(slotKey(userId, slot))
    end)
    if ok and result then
        return mergeDefaults(result)
    elseif not ok then
        warn("[PlayerDataManager] Load failed for slot " .. slot .. " userId=" .. userId)
    end
    return newProfile()
end

local function saveSlot(userId, slot, profile)
    local toSave = deepCopy(profile)
    if toSave.stats and toSave.stats.fastestOrderTime == math.huge then
        toSave.stats.fastestOrderTime = 0
    end
    local ok, err = pcall(function()
        playerStore:SetAsync(slotKey(userId, slot), toSave)
    end)
    if not ok then
        warn("[PlayerDataManager] Save failed slot=" .. slot .. " userId=" .. userId .. " " .. tostring(err))
    else
        print("[PlayerDataManager] Saved slot " .. slot .. " for userId " .. userId)
    end
end

-- ── MODULE API ─────────────────────────────────────────────────
local PlayerDataManager = {}

function PlayerDataManager.GetData(player)
    return profiles[player.UserId]
end

function PlayerDataManager.GetActiveSlot(player)
    return activeSlots[player.UserId] or 1
end

-- Returns a preview of all 3 slots (level, coins, unlock count, isEmpty).
-- Used by SlotSelectGui. Makes 3 DataStore reads — call sparingly.
function PlayerDataManager.GetSlotPreviews(player)
    local userId = player.UserId
    local previews = {}
    for slot = 1, 3 do
        local ok, data = pcall(function()
            return playerStore:GetAsync(slotKey(userId, slot))
        end)
        if ok and data then
            previews[slot] = {
                isEmpty      = false,
                level        = data.level or 1,
                coins        = data.coins or 0,
                unlockCount  = (#(data.unlockedStations or {})) + (#(data.unlockedCosmetics or {})),
            }
        else
            previews[slot] = { isEmpty = true }
        end
    end
    return previews
end

-- Switch to a different slot. Only allowed when NOT in Open phase.
function PlayerDataManager.SwitchSlot(player, newSlot)
    local state = Workspace:GetAttribute("GameState") or "Lobby"
    if state == "Open" then
        return false, "You can switch stores between shifts."
    end
    if newSlot < 1 or newSlot > 3 then
        return false, "Invalid slot."
    end
    local userId = player.UserId
    -- Save current slot first
    local currentSlot = activeSlots[userId] or 1
    saveSlot(userId, currentSlot, profiles[userId])
    -- Load new slot
    profiles[userId]    = loadSlot(userId, newSlot)
    activeSlots[userId] = newSlot
    saveMeta(userId, newSlot)
    print("[PlayerDataManager] " .. player.Name .. " switched to slot " .. newSlot)
    return true, nil
end

-- Reset a slot to defaults. Only allowed when NOT in Open phase.
function PlayerDataManager.ResetSlot(player, slot)
    local state = Workspace:GetAttribute("GameState") or "Lobby"
    if state == "Open" then
        return false, "You can reset slots between shifts."
    end
    local userId = player.UserId
    local fresh  = newProfile()
    saveSlot(userId, slot, fresh)
    -- If resetting the active slot, reload it into memory
    if (activeSlots[userId] or 1) == slot then
        profiles[userId] = fresh
    end
    print("[PlayerDataManager] " .. player.Name .. " reset slot " .. slot)
    return true, nil
end

function PlayerDataManager.AddCoins(player, amount)
    local p = profiles[player.UserId]
    if not p then return 0 end
    p.coins = math.max(0, p.coins + amount)
    return p.coins
end

function PlayerDataManager.AddXP(player, amount)
    local p = profiles[player.UserId]
    if not p then return 0, 1 end
    p.xp += amount
    local required = math.floor(100 * (p.level ^ 1.35))
    while p.xp >= required do
        p.xp    -= required
        p.level += 1
        required = math.floor(100 * (p.level ^ 1.35))
        print("[PlayerDataManager] " .. player.Name .. " leveled up to " .. p.level)
    end
    return p.xp, p.level
end

function PlayerDataManager.IncrementCombo(player)
    local p = profiles[player.UserId]
    if not p then return 0 end
    p.comboStreak = math.min(p.comboStreak + 1, 20)
    return p.comboStreak
end

function PlayerDataManager.ResetCombo(player)
    local p = profiles[player.UserId]
    if p then p.comboStreak = 0 end
end

function PlayerDataManager.RecordOrderComplete(player, isPerfect)
    local p = profiles[player.UserId]
    if not p then return end
    p.ordersCompleted += 1
    if isPerfect then p.perfectOrders += 1 end
end

function PlayerDataManager.SetTutorialCompleted(player)
    local p = profiles[player.UserId]
    if p then p.tutorialCompleted = true end
end

-- ── LIFECYCLE ──────────────────────────────────────────────────
Players.PlayerAdded:Connect(function(player)
    local userId = player.UserId
    local slot   = loadMeta(userId)
    activeSlots[userId] = slot
    profiles[userId]    = loadSlot(userId, slot)
    print("[PlayerDataManager] " .. player.Name .. " loaded slot " .. slot
        .. " | coins=" .. profiles[userId].coins
        .. " level=" .. profiles[userId].level)
end)

Players.PlayerRemoving:Connect(function(player)
    local userId = player.UserId
    local slot   = activeSlots[userId] or 1
    if profiles[userId] then
        saveSlot(userId, slot, profiles[userId])
    end
    profiles[userId]    = nil
    activeSlots[userId] = nil
end)

for _, player in ipairs(Players:GetPlayers()) do
    if not profiles[player.UserId] then
        local slot = loadMeta(player.UserId)
        activeSlots[player.UserId] = slot
        profiles[player.UserId]    = loadSlot(player.UserId, slot)
    end
end

print("[PlayerDataManager] Ready (3-slot system, DataStore: PlayerData_v1).")
return PlayerDataManager
```

**Step 3: Sync to Studio via MCP**
Replace the entire ModuleScript source via MCP run_code.

**Step 4: Verify**
Play test. Console: `[PlayerDataManager] [Name] loaded slot 1 | coins=0 level=1`.
Leave game → rejoin → same coins/level loads. ✓

**Step 5: Commit**
```bash
git add src/ServerScriptService/Core/PlayerDataManager.lua
git commit -m "feat(m6): implement 3-slot save system in PlayerDataManager"
```

---

## Task 5: Studio — Register new RemoteEvents + BindableEvents

**Files:** Studio-only (MCP run_code)

**Step 1: Register new RemoteEvents via MCP**
```lua
-- MCP run_code:
local RemoteManager = require(game:GetService("ReplicatedStorage").Modules.RemoteManager)
-- Force-create all M6 remotes
local remotes = {"RushHour", "LeaderboardUpdate", "PurchaseItem", "PurchaseResult", "SlotSelect", "SlotSelectResult"}
for _, name in ipairs(remotes) do
    local r = RemoteManager.Get(name)
    print("Remote OK: " .. name .. " (" .. r.ClassName .. ")")
end
```
Expected: 6 lines of "Remote OK: ..." printed.

**Step 2: Create BindableEvents in ServerStorage/Events via MCP**
```lua
-- MCP run_code:
local evts = game:GetService("ServerStorage"):WaitForChild("Events")
local toCreate = {"RushHourStart", "RushHourEnd", "StationUnlocked"}
for _, name in ipairs(toCreate) do
    if not evts:FindFirstChild(name) then
        local b = Instance.new("BindableEvent")
        b.Name = name
        b.Parent = evts
        print("Created BindableEvent: " .. name)
    else
        print("Already exists: " .. name)
    end
end
```

**Step 3: Verify**
MCP query: `print(#game:GetService("ServerStorage").Events:GetChildren())` — should include the new events.

---

## Task 6: EventManager — Rush Hour + Golden VIP

**Files:**
- Create: `src/ServerScriptService/Core/EventManager.server.lua`

**Step 1: Create the file**
```lua
-- src/ServerScriptService/Core/EventManager.server.lua
-- Fires Rush Hour once per Open phase at a random time between minute 3 and 7.
-- Communicates with PersistentNPCSpawner via BindableEvents only.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")

local RemoteManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))

local rushHourRemote = RemoteManager.Get("RushHour")  -- Server → Client (HUD banner)

local RUSH_HOUR_DURATION  = 2 * 60   -- 2 minutes
local RUSH_START_MIN      = 3 * 60   -- earliest: 3 min into Open phase
local RUSH_START_MAX      = 7 * 60   -- latest:   7 min into Open phase (leaves 3 min before end)

math.randomseed(tick())

local function getBindable(name)
    local evts = ServerStorage:FindFirstChild("Events")
    return evts and evts:FindFirstChild(name)
end

local function runRushHour()
    local startEvt = getBindable("RushHourStart")
    local endEvt   = getBindable("RushHourEnd")
    if not startEvt or not endEvt then
        warn("[EventManager] RushHourStart/End BindableEvents not found in ServerStorage/Events")
        return
    end

    print("[EventManager] Rush Hour START — lasts " .. RUSH_HOUR_DURATION .. "s")
    startEvt:Fire()
    rushHourRemote:FireAllClients("start", RUSH_HOUR_DURATION)

    task.wait(RUSH_HOUR_DURATION)

    print("[EventManager] Rush Hour END")
    endEvt:Fire()
    rushHourRemote:FireAllClients("end", 0)
end

local function runOpenPhaseEvents()
    -- Wait a random time between minute 3 and 7, then fire Rush Hour
    local delay = math.random(RUSH_START_MIN, RUSH_START_MAX)
    print(string.format("[EventManager] Rush Hour scheduled in %ds (%.1f min)", delay, delay / 60))
    task.wait(delay)
    runRushHour()
end

-- Listen for Open phase to start
local stateChangedRemote = RemoteManager.Get("GameStateChanged")

-- Use workspace attribute to detect Open phase (polled from server-side)
-- GameStateManager sets Workspace GameState attribute on each phase change.
local function waitForOpenPhase()
    while true do
        local state = game:GetService("Workspace"):GetAttribute("GameState") or "Lobby"
        if state == "Open" then
            task.spawn(runOpenPhaseEvents)
            -- Wait until Open phase ends before listening again
            repeat task.wait(5) until game:GetService("Workspace"):GetAttribute("GameState") ~= "Open"
        end
        task.wait(2)
    end
end

task.spawn(waitForOpenPhase)
print("[EventManager] Ready — Rush Hour scheduler active.")
```

**Step 2: Sync to Studio via MCP**
```lua
-- MCP run_code:
local s = Instance.new("Script")
s.Name = "EventManager"
s.Parent = game:GetService("ServerScriptService").Core
-- Then paste source via s.Source = [the full script above]
print("EventManager created")
```

**Step 3: Update PersistentNPCSpawner for Rush Hour + Golden VIP**

In `PersistentNPCSpawner.server.lua`, add after the constants block (after `local VIP_CHANCE = 0.10`):

```lua
-- Rush Hour state (toggled by EventManager via BindableEvents)
local rushHourActive = false
local BASE_SPAWN_INTERVAL = SPAWN_INTERVAL  -- save original (30s)
local GOLDEN_VIP_CHANCE_RUSH    = 0.05
local GOLDEN_VIP_CHANCE_NORMAL  = 0.02
```

Add at the bottom of the file (before `print("[NPCController] Ready")`), a function to wire Rush Hour events:
```lua
-- Wire Rush Hour BindableEvents
task.spawn(function()
    local evts = game:GetService("ServerStorage"):WaitForChild("Events", 10)
    local startEvt = evts and evts:WaitForChild("RushHourStart", 10)
    local endEvt   = evts and evts:WaitForChild("RushHourEnd",   10)
    if not startEvt or not endEvt then
        warn("[PersistentNPCSpawner] Rush Hour events not found")
        return
    end
    startEvt.Event:Connect(function()
        rushHourActive = true
        SPAWN_INTERVAL = math.floor(BASE_SPAWN_INTERVAL / 2)  -- halve spawn interval
        VIP_CHANCE = 0.20  -- bump VIP to 20%
        print("[PersistentNPCSpawner] Rush Hour ON — spawn interval=" .. SPAWN_INTERVAL .. "s, VIP=20%")
    end)
    endEvt.Event:Connect(function()
        rushHourActive = false
        SPAWN_INTERVAL = BASE_SPAWN_INTERVAL
        VIP_CHANCE = 0.10
        print("[PersistentNPCSpawner] Rush Hour OFF — spawn interval=" .. SPAWN_INTERVAL .. "s, VIP=10%")
    end)
    print("[PersistentNPCSpawner] Rush Hour events wired.")
end)
```

Also update wherever VIP is rolled and the NPC is created to include Golden VIP:
Find the section where `isVIP` is determined (search for `VIP_CHANCE`). Add Golden VIP roll:
```lua
local isVIP = math.random() < VIP_CHANCE
local isGoldenVIP = false
if isVIP then
    local goldenChance = rushHourActive and GOLDEN_VIP_CHANCE_RUSH or GOLDEN_VIP_CHANCE_NORMAL
    isGoldenVIP = math.random() < goldenChance
end
```

Then wherever the VIP coin multiplier is applied (search for `1.75`), update:
```lua
-- BEFORE
if npcData.isVIP then mult = mult * 1.75 end

-- AFTER
if npcData.isGoldenVIP then
    mult = mult * 2.0
elseif npcData.isVIP then
    mult = mult * 1.75
end
```

**Step 4: Sync to Studio via MCP** (patch PersistentNPCSpawner source)

**Step 5: Verify**
Start a test server. Wait for Open phase. Console should show `[EventManager] Rush Hour scheduled in Xs`. When it fires: `[PersistentNPCSpawner] Rush Hour ON — spawn interval=15s, VIP=20%`.

**Step 6: Commit**
```bash
git add src/ServerScriptService/Core/EventManager.server.lua src/ServerScriptService/Core/PersistentNPCSpawner.server.lua
git commit -m "feat(m6): EventManager Rush Hour + Golden VIP NPCs"
```

---

## Task 7: LeaderboardManager — Global leaderboards

**Files:**
- Create: `src/ServerScriptService/Core/LeaderboardManager.lua`

**Step 1: Create the file**
```lua
-- ServerScriptService/Core/LeaderboardManager (ModuleScript)
-- Manages 9 OrderedDataStores (3 stats × 3 timeframes).
-- Call RecordDelivery after each delivery.
-- Refreshes back-room boards every 60 seconds.

local DataStoreService  = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))

local leaderboardUpdate = RemoteManager.Get("LeaderboardUpdate")

-- ── STORES ─────────────────────────────────────────────────────
local STATS = { "Coins", "Orders", "Cookies" }
local TIMES = { "Daily", "Weekly", "AllTime" }

local stores = {}
for _, stat in ipairs(STATS) do
    stores[stat] = {}
    for _, time in ipairs(TIMES) do
        stores[stat][time] = DataStoreService:GetOrderedDataStore("LB_" .. stat .. "_" .. time)
    end
end

-- ── KEY HELPERS ────────────────────────────────────────────────
local function dailySuffix(userId)
    return userId .. "_" .. os.date("%Y%m%d")
end

local function weeklySuffix(userId)
    return userId .. "_" .. math.floor(os.time() / 604800)
end

local function allTimeSuffix(userId)
    return tostring(userId)
end

-- ── WRITE ──────────────────────────────────────────────────────
local LeaderboardManager = {}

function LeaderboardManager.RecordDelivery(player, coins, cookies, orders)
    local userId = player.UserId
    orders  = orders  or 1
    coins   = coins   or 0
    cookies = cookies or 1

    -- Update each timeframe for each stat (9 total writes)
    local function update(store, suffix, amount)
        pcall(function()
            local current = store:GetAsync(suffix) or 0
            store:SetAsync(suffix, current + amount)
        end)
    end

    task.spawn(function()
        update(stores.Coins.Daily,   dailySuffix(userId),  coins)
        update(stores.Coins.Weekly,  weeklySuffix(userId), coins)
        update(stores.Coins.AllTime, allTimeSuffix(userId), coins)
    end)
    task.spawn(function()
        update(stores.Orders.Daily,   dailySuffix(userId),  orders)
        update(stores.Orders.Weekly,  weeklySuffix(userId), orders)
        update(stores.Orders.AllTime, allTimeSuffix(userId), orders)
    end)
    task.spawn(function()
        update(stores.Cookies.Daily,   dailySuffix(userId),  cookies)
        update(stores.Cookies.Weekly,  weeklySuffix(userId), cookies)
        update(stores.Cookies.AllTime, allTimeSuffix(userId), cookies)
    end)
end

-- ── READ TOP 10 ────────────────────────────────────────────────
local function getTop10(store)
    local ok, pages = pcall(function()
        return store:GetSortedAsync(false, 10)
    end)
    if not ok or not pages then return {} end
    local results = {}
    local ok2, page = pcall(function() return pages:GetCurrentPage() end)
    if not ok2 then return {} end
    for _, entry in ipairs(page) do
        local name = "[unknown]"
        pcall(function()
            name = game:GetService("Players"):GetNameFromUserIdAsync(tonumber(entry.key) or 0)
        end)
        table.insert(results, { name = name, value = entry.value })
    end
    return results
end

-- ── BROADCAST ──────────────────────────────────────────────────
function LeaderboardManager.RefreshAndBroadcast()
    -- Gather all 9 top-10 lists and send to clients
    local payload = {}
    for _, stat in ipairs(STATS) do
        payload[stat] = {}
        for _, time in ipairs(TIMES) do
            payload[stat][time] = getTop10(stores[stat][time])
        end
    end
    leaderboardUpdate:FireAllClients(payload)
    print("[LeaderboardManager] Boards refreshed and broadcast.")
end

-- ── AUTO-REFRESH LOOP ──────────────────────────────────────────
task.spawn(function()
    while true do
        task.wait(60)
        LeaderboardManager.RefreshAndBroadcast()
    end
end)

print("[LeaderboardManager] Ready (9 OrderedDataStores).")
return LeaderboardManager
```

**Step 2: Wire RecordDelivery in PersistentNPCSpawner**

At the top of PersistentNPCSpawner, add:
```lua
local ServerScriptService = game:GetService("ServerScriptService")
local LeaderboardManager  = require(ServerScriptService:WaitForChild("Core"):WaitForChild("LeaderboardManager"))
```

After the `SessionStats.RecordDelivery(...)` call (~line 422), add:
```lua
LeaderboardManager.RecordDelivery(player, payout.coins, npcData.packSize or 1, 1)
```

**Step 3: Sync LeaderboardManager to Studio**
Create as ModuleScript in SSS/Core via MCP run_code.

**Step 4: Verify**
Complete a delivery. Check console: no errors. After 60s: `[LeaderboardManager] Boards refreshed and broadcast.`

**Step 5: Commit**
```bash
git add src/ServerScriptService/Core/LeaderboardManager.lua src/ServerScriptService/Core/PersistentNPCSpawner.server.lua
git commit -m "feat(m6): LeaderboardManager with 9 OrderedDataStores"
```

---

## Task 8: LeaderboardClient — Back room display boards

**Files:**
- Create: `src/StarterPlayer/StarterPlayerScripts/LeaderboardClient.client.lua`

**Step 1: Create back room SurfaceGui boards in Studio first (MCP)**
```lua
-- MCP run_code: Create 3 SurfaceGui display boards on back room walls
-- Replace "BackRoomWall_Coins" etc. with your actual Part names in Studio
-- This creates placeholder parts if they don't exist yet
local workspace = game:GetService("Workspace")

local boards = {
    { partName = "LeaderboardBoard_Coins",   stat = "Coins"   },
    { partName = "LeaderboardBoard_Orders",  stat = "Orders"  },
    { partName = "LeaderboardBoard_Cookies", stat = "Cookies" },
}

for _, board in ipairs(boards) do
    local part = workspace:FindFirstChild(board.partName)
    if not part then
        part = Instance.new("Part")
        part.Name    = board.partName
        part.Size    = Vector3.new(6, 8, 0.2)
        part.Anchored = true
        part.Position = Vector3.new(0, 5, -20)  -- ADJUST in Studio after creation
        part.BrickColor = BrickColor.new("Dark grey")
        part.Parent  = workspace
    end

    -- Create SurfaceGui if missing
    local sg = part:FindFirstChild("LeaderboardGui")
    if not sg then
        sg = Instance.new("SurfaceGui")
        sg.Name = "LeaderboardGui"
        sg.Attribute = board.stat  -- tag which stat this board shows
        sg.Face = Enum.NormalId.Front
        sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
        sg.PixelsPerStud = 50
        sg.Parent = part

        -- Tab label
        local tabLabel = Instance.new("TextLabel")
        tabLabel.Name = "TabLabel"
        tabLabel.Size = UDim2.new(1, 0, 0.1, 0)
        tabLabel.Position = UDim2.new(0, 0, 0, 0)
        tabLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        tabLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
        tabLabel.Text = board.stat .. " — Daily"
        tabLabel.TextScaled = true
        tabLabel.Font = Enum.Font.GothamBold
        tabLabel.Parent = sg

        -- 10 entry rows
        for i = 1, 10 do
            local row = Instance.new("TextLabel")
            row.Name = "Row" .. i
            row.Size = UDim2.new(1, 0, 0.08, 0)
            row.Position = UDim2.new(0, 0, 0.1 + (i-1) * 0.08, 0)
            row.BackgroundTransparency = 1
            row.TextColor3 = Color3.fromRGB(220, 220, 220)
            row.Text = i .. ". —"
            row.TextScaled = true
            row.Font = Enum.Font.Gotham
            row.Parent = sg
        end
        print("Created LeaderboardGui on " .. board.partName)
    end
end
```

**Step 2: Create LeaderboardClient.client.lua**
```lua
-- src/StarterPlayer/StarterPlayerScripts/LeaderboardClient.client.lua
-- Receives LeaderboardUpdate from server, cycles boards Daily → Weekly → AllTime.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

local RemoteManager     = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local leaderboardUpdate = RemoteManager.Get("LeaderboardUpdate")

local BOARD_NAMES = {
    Coins   = "LeaderboardBoard_Coins",
    Orders  = "LeaderboardBoard_Orders",
    Cookies = "LeaderboardBoard_Cookies",
}
local TIMEFRAMES = { "Daily", "Weekly", "AllTime" }
local TAB_LABELS = { Daily = "Daily", Weekly = "Weekly", AllTime = "All Time" }
local CYCLE_INTERVAL = 10  -- seconds per tab

local latestData = nil
local currentTabIndex = 1

local function updateBoard(stat, timeframe, entries)
    local part = Workspace:FindFirstChild(BOARD_NAMES[stat])
    if not part then return end
    local sg = part:FindFirstChild("LeaderboardGui")
    if not sg then return end

    local tabLabel = sg:FindFirstChild("TabLabel")
    if tabLabel then
        tabLabel.Text = stat .. " — " .. (TAB_LABELS[timeframe] or timeframe)
    end

    for i = 1, 10 do
        local row = sg:FindFirstChild("Row" .. i)
        if row then
            local entry = entries and entries[i]
            if entry then
                row.Text = string.format("%d. %s   %s", i, entry.name, tostring(entry.value))
            else
                row.Text = i .. ". —"
            end
        end
    end
end

local function refreshAllBoards(timeframe)
    if not latestData then return end
    for stat, _ in pairs(BOARD_NAMES) do
        local entries = latestData[stat] and latestData[stat][timeframe]
        updateBoard(stat, timeframe, entries)
    end
end

-- Cycle tabs every CYCLE_INTERVAL seconds
task.spawn(function()
    while true do
        task.wait(CYCLE_INTERVAL)
        currentTabIndex = (currentTabIndex % #TIMEFRAMES) + 1
        refreshAllBoards(TIMEFRAMES[currentTabIndex])
    end
end)

leaderboardUpdate.OnClientEvent:Connect(function(data)
    latestData = data
    refreshAllBoards(TIMEFRAMES[currentTabIndex])
end)

print("[LeaderboardClient] Ready.")
```

**Step 3: Sync to Studio via MCP**

**Step 4: Verify**
Play test → join → after 60s server broadcasts data → boards in back room update. Cycle changes tab every 10s.

**Step 5: Commit**
```bash
git add src/StarterPlayer/StarterPlayerScripts/LeaderboardClient.client.lua
git commit -m "feat(m6): leaderboard display boards + client cycling"
```

---

## Task 9: UnlockManager — Station + cosmetic unlock shop

**Files:**
- Create: `src/ServerScriptService/Core/UnlockManager.lua`

**Step 1: Create the file**
```lua
-- ServerScriptService/Core/UnlockManager (ModuleScript)
-- Station and cosmetic unlock shop. Catalog is static (no DataStore needed).
-- Purchase validated server-side. Fires StationUnlocked BindableEvent for M7 hooks.

local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage       = game:GetService("ServerStorage")

local PlayerDataManager = require(ServerScriptService:WaitForChild("Core"):WaitForChild("PlayerDataManager"))

-- ── CATALOG ────────────────────────────────────────────────────
-- type: "station" or "cosmetic"
local CATALOG = {
    -- Stations
    { id = "station_extra_mixer",   type = "station",   price = 500,  name = "Extra Mixer",        description = "Unlock a third Mixer station." },
    { id = "station_speed_oven",    type = "station",   price = 750,  name = "Speed Oven",          description = "Bake 20% faster in all ovens." },
    { id = "station_auto_warmer",   type = "station",   price = 1000, name = "Auto Warmer",         description = "Cookies move to warmers automatically." },
    -- Cosmetics
    { id = "cosmetic_golden_hat",   type = "cosmetic",  price = 200,  name = "Golden Chef Hat",     description = "A shiny golden hat for your character." },
    { id = "cosmetic_pink_apron",   type = "cosmetic",  price = 150,  name = "Pink Apron",          description = "A stylish pink apron." },
    { id = "cosmetic_star_badge",   type = "cosmetic",  price = 300,  name = "Star Baker Badge",    description = "Show off your baking excellence." },
}

local catalogById = {}
for _, item in ipairs(CATALOG) do
    catalogById[item.id] = item
end

-- ── MODULE API ─────────────────────────────────────────────────
local UnlockManager = {}

function UnlockManager.GetCatalog()
    return CATALOG
end

function UnlockManager.CanAfford(player, itemId)
    local data = PlayerDataManager.GetData(player)
    if not data then return false end
    local item = catalogById[itemId]
    if not item then return false end
    return data.coins >= item.price
end

function UnlockManager.Owns(player, itemId)
    local data = PlayerDataManager.GetData(player)
    if not data then return false end
    local item = catalogById[itemId]
    if not item then return false end
    if item.type == "station" then
        for _, id in ipairs(data.unlockedStations or {}) do
            if id == itemId then return true end
        end
    elseif item.type == "cosmetic" then
        for _, id in ipairs(data.unlockedCosmetics or {}) do
            if id == itemId then return true end
        end
    end
    return false
end

function UnlockManager.Purchase(player, itemId)
    local item = catalogById[itemId]
    if not item then
        return false, "Item not found."
    end
    if UnlockManager.Owns(player, itemId) then
        return false, "Already owned."
    end
    if not UnlockManager.CanAfford(player, itemId) then
        return false, "Not enough coins."
    end

    -- Deduct coins
    local newCoins = PlayerDataManager.AddCoins(player, -item.price)

    -- Add to unlocked list
    local data = PlayerDataManager.GetData(player)
    if item.type == "station" then
        data.unlockedStations = data.unlockedStations or {}
        table.insert(data.unlockedStations, itemId)
        -- Fire BindableEvent for M7 station hooks (stub)
        local evts = ServerStorage:FindFirstChild("Events")
        local evt  = evts and evts:FindFirstChild("StationUnlocked")
        if evt then evt:Fire(player, itemId) end
    elseif item.type == "cosmetic" then
        data.unlockedCosmetics = data.unlockedCosmetics or {}
        table.insert(data.unlockedCosmetics, itemId)
    end

    print(string.format("[UnlockManager] %s purchased %s for %d coins (remaining: %d)",
        player.Name, itemId, item.price, newCoins))

    return true, newCoins
end

print("[UnlockManager] Ready — " .. #CATALOG .. " items in catalog.")
return UnlockManager
```

**Step 2: Create server handler for PurchaseItem remote**

Add to the bottom of UnlockManager.lua (before the final `return`):
```lua
-- ── REMOTE HANDLER ─────────────────────────────────────────────
-- Wire up after ReplicatedStorage is available
task.spawn(function()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local RemoteManager     = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
    local purchaseRemote = RemoteManager.Get("PurchaseItem")
    local resultRemote   = RemoteManager.Get("PurchaseResult")

    purchaseRemote.OnServerEvent:Connect(function(player, itemId)
        if type(itemId) ~= "string" then return end
        local success, coinsOrReason = UnlockManager.Purchase(player, itemId)
        if success then
            resultRemote:FireClient(player, { success = true, newCoins = coinsOrReason })
        else
            resultRemote:FireClient(player, { success = false, reason = coinsOrReason })
        end
    end)
    print("[UnlockManager] PurchaseItem remote wired.")
end)
```

**Step 3: Sync to Studio via MCP**

**Step 4: Verify**
Play test. Console: `[UnlockManager] Ready — 6 items in catalog.` + `[UnlockManager] PurchaseItem remote wired.`
Give yourself coins via Studio command bar and fire PurchaseItem to test a purchase.

**Step 5: Commit**
```bash
git add src/ServerScriptService/Core/UnlockManager.lua
git commit -m "feat(m6): UnlockManager with station + cosmetic catalog"
```

---

## Task 10: ShopClient + SlotSelect UI

**Files:**
- Create: `src/StarterPlayer/StarterPlayerScripts/ShopClient.client.lua`

**Step 1: Create ShopGui in Studio via MCP**
```lua
-- MCP run_code: Create ShopGui ScreenGui
local starterGui = game:GetService("StarterGui")
local sg = starterGui:FindFirstChild("ShopGui")
if not sg then
    sg = Instance.new("ScreenGui")
    sg.Name = "ShopGui"
    sg.Enabled = false
    sg.ResetOnSpawn = false
    sg.Parent = starterGui
end

-- Main frame
local frame = sg:FindFirstChild("ShopFrame") or Instance.new("Frame", sg)
frame.Name = "ShopFrame"
frame.Size = UDim2.new(0, 500, 0, 400)
frame.Position = UDim2.new(0.5, -250, 0.5, -200)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
frame.BorderSizePixel = 0

-- Title
local title = frame:FindFirstChild("Title") or Instance.new("TextLabel", frame)
title.Name = "Title"
title.Size = UDim2.new(1, 0, 0.1, 0)
title.Position = UDim2.new(0, 0, 0, 0)
title.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
title.TextColor3 = Color3.fromRGB(255, 200, 50)
title.Text = "Shop"
title.TextScaled = true
title.Font = Enum.Font.GothamBold

-- Tabs
local tabFrame = frame:FindFirstChild("Tabs") or Instance.new("Frame", frame)
tabFrame.Name = "Tabs"
tabFrame.Size = UDim2.new(1, 0, 0.1, 0)
tabFrame.Position = UDim2.new(0, 0, 0.1, 0)
tabFrame.BackgroundTransparency = 1

for _, tabName in ipairs({"Stations", "Cosmetics"}) do
    local btn = tabFrame:FindFirstChild(tabName) or Instance.new("TextButton", tabFrame)
    btn.Name = tabName
    btn.Size = UDim2.new(0.5, 0, 1, 0)
    btn.Position = tabName == "Stations" and UDim2.new(0, 0, 0, 0) or UDim2.new(0.5, 0, 0, 0)
    btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Text = tabName
    btn.Font = Enum.Font.Gotham
    btn.TextScaled = true
end

-- Item list scroll
local scroll = frame:FindFirstChild("ItemList") or Instance.new("ScrollingFrame", frame)
scroll.Name = "ItemList"
scroll.Size = UDim2.new(1, 0, 0.7, 0)
scroll.Position = UDim2.new(0, 0, 0.2, 0)
scroll.BackgroundTransparency = 1
scroll.ScrollBarThickness = 6

Instance.new("UIListLayout", scroll).SortOrder = Enum.SortOrder.LayoutOrder

-- Close button
local close = frame:FindFirstChild("CloseBtn") or Instance.new("TextButton", frame)
close.Name = "CloseBtn"
close.Size = UDim2.new(0.3, 0, 0.1, 0)
close.Position = UDim2.new(0.35, 0, 0.9, 0)
close.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
close.TextColor3 = Color3.fromRGB(255, 255, 255)
close.Text = "Close"
close.Font = Enum.Font.GothamBold
close.TextScaled = true

print("ShopGui created")
```

**Step 2: Create ShopClient.client.lua**
```lua
-- src/StarterPlayer/StarterPlayerScripts/ShopClient.client.lua
-- Handles shop UI: opens via ProximityPrompt, displays catalog, processes purchases.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteManager   = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local purchaseRemote  = RemoteManager.Get("PurchaseItem")
local resultRemote    = RemoteManager.Get("PurchaseResult")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local shopGui     = playerGui:WaitForChild("ShopGui",   20)
local shopFrame   = shopGui   and shopGui:WaitForChild("ShopFrame",  5)
local itemList    = shopFrame  and shopFrame:WaitForChild("ItemList", 5)
local tabFrame    = shopFrame  and shopFrame:WaitForChild("Tabs",     5)
local closeBtn    = shopFrame  and shopFrame:WaitForChild("CloseBtn", 5)

if not shopFrame then
    warn("[ShopClient] ShopGui not found — check StarterGui")
    return
end

local currentTab = "Stations"
local catalogData = nil  -- populated by server on open

-- Item template builder
local function buildItem(item, owned)
    local row = Instance.new("Frame")
    row.Name = item.id
    row.Size = UDim2.new(1, 0, 0, 60)
    row.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    row.BorderSizePixel = 0

    local nameLbl = Instance.new("TextLabel", row)
    nameLbl.Size = UDim2.new(0.6, 0, 0.5, 0)
    nameLbl.Position = UDim2.new(0.02, 0, 0, 0)
    nameLbl.BackgroundTransparency = 1
    nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLbl.Text = item.name
    nameLbl.TextScaled = true
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left

    local descLbl = Instance.new("TextLabel", row)
    descLbl.Size = UDim2.new(0.6, 0, 0.5, 0)
    descLbl.Position = UDim2.new(0.02, 0, 0.5, 0)
    descLbl.BackgroundTransparency = 1
    descLbl.TextColor3 = Color3.fromRGB(180, 180, 180)
    descLbl.Text = item.description
    descLbl.TextScaled = true
    descLbl.Font = Enum.Font.Gotham
    descLbl.TextXAlignment = Enum.TextXAlignment.Left

    local btn = Instance.new("TextButton", row)
    btn.Size = UDim2.new(0.3, 0, 0.7, 0)
    btn.Position = UDim2.new(0.68, 0, 0.15, 0)
    btn.Font = Enum.Font.GothamBold
    btn.TextScaled = true
    btn.BorderSizePixel = 0

    if owned then
        btn.Text = "Owned"
        btn.BackgroundColor3 = Color3.fromRGB(60, 120, 60)
        btn.TextColor3 = Color3.fromRGB(200, 255, 200)
        btn.Active = false
    else
        btn.Text = "Buy  " .. item.price .. "¢"
        btn.BackgroundColor3 = Color3.fromRGB(255, 165, 0)
        btn.TextColor3 = Color3.fromRGB(0, 0, 0)
        btn.MouseButton1Click:Connect(function()
            purchaseRemote:FireServer(item.id)
        end)
    end

    return row
end

local function refreshItemList()
    if not catalogData then return end
    for _, child in ipairs(itemList:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    for _, item in ipairs(catalogData) do
        if item.type == (currentTab == "Stations" and "station" or "cosmetic") then
            local owned = false  -- TODO: pass owned list from server on open
            local row = buildItem(item, owned)
            row.Parent = itemList
        end
    end
end

-- Tab switching
if tabFrame then
    for _, btn in ipairs(tabFrame:GetChildren()) do
        if btn:IsA("TextButton") then
            btn.MouseButton1Click:Connect(function()
                currentTab = btn.Name
                refreshItemList()
            end)
        end
    end
end

-- Close button
if closeBtn then
    closeBtn.MouseButton1Click:Connect(function()
        shopGui.Enabled = false
    end)
end

-- Purchase result handler
resultRemote.OnClientEvent:Connect(function(result)
    if result.success then
        print("[ShopClient] Purchase successful! New coins: " .. tostring(result.newCoins))
        refreshItemList()  -- refresh to show "Owned"
    else
        warn("[ShopClient] Purchase failed: " .. tostring(result.reason))
    end
end)

-- Open shop via a ProximityPrompt (set up ProximityPrompt in Studio on shop counter)
-- The server fires a remote or a ProximityPrompt triggers this client directly.
-- For M6: use a LocalScript ProximityPrompt listener pattern.
local function hookShopPrompt()
    local backRoom = workspace:FindFirstChild("BackRoom") or workspace
    for _, obj in ipairs(backRoom:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.Name == "ShopPrompt" then
            obj.Triggered:Connect(function()
                -- Fetch catalog from server (or use cached)
                -- For M6: hardcode catalog on client side matching server
                catalogData = {
                    { id = "station_extra_mixer",  type = "station",  price = 500,  name = "Extra Mixer",     description = "Unlock a third Mixer station." },
                    { id = "station_speed_oven",   type = "station",  price = 750,  name = "Speed Oven",       description = "Bake 20% faster in all ovens." },
                    { id = "station_auto_warmer",  type = "station",  price = 1000, name = "Auto Warmer",      description = "Cookies move to warmers automatically." },
                    { id = "cosmetic_golden_hat",  type = "cosmetic", price = 200,  name = "Golden Chef Hat",  description = "A shiny golden hat for your character." },
                    { id = "cosmetic_pink_apron",  type = "cosmetic", price = 150,  name = "Pink Apron",       description = "A stylish pink apron." },
                    { id = "cosmetic_star_badge",  type = "cosmetic", price = 300,  name = "Star Baker Badge", description = "Show off your baking excellence." },
                }
                refreshItemList()
                shopGui.Enabled = true
            end)
        end
    end
end

workspace.DescendantAdded:Connect(function(obj)
    if obj:IsA("ProximityPrompt") and obj.Name == "ShopPrompt" then
        hookShopPrompt()
    end
end)
hookShopPrompt()

print("[ShopClient] Ready.")
```

**Step 3: Add ShopPrompt ProximityPrompt to back room in Studio**
```lua
-- MCP run_code: Add ProximityPrompt to a counter part in back room
-- Replace "ShopCounter" with your actual part name
local part = workspace:FindFirstChild("ShopCounter", true)
if not part then
    -- Create a placeholder counter
    part = Instance.new("Part")
    part.Name = "ShopCounter"
    part.Size = Vector3.new(4, 1, 2)
    part.Anchored = true
    part.Position = Vector3.new(10, 1, -15)  -- ADJUST in Studio
    part.BrickColor = BrickColor.new("Reddish brown")
    part.Parent = workspace
end
local pp = part:FindFirstChild("ShopPrompt") or Instance.new("ProximityPrompt", part)
pp.Name = "ShopPrompt"
pp.ActionText = "Open Shop"
pp.ObjectText = "Shop Counter"
pp.MaxActivationDistance = 8
pp.RequiresLineOfSight = false
print("ShopPrompt added to " .. part.Name)
```

**Step 4: Create SlotSelectGui and handler (minimal for M6)**
```lua
-- MCP run_code: Create SlotSelectGui
local starterGui = game:GetService("StarterGui")
local sg = starterGui:FindFirstChild("SlotSelectGui") or Instance.new("ScreenGui", starterGui)
sg.Name = "SlotSelectGui"
sg.Enabled = false
sg.ResetOnSpawn = false

local frame = sg:FindFirstChild("SlotFrame") or Instance.new("Frame", sg)
frame.Name = "SlotFrame"
frame.Size = UDim2.new(0, 500, 0, 300)
frame.Position = UDim2.new(0.5, -250, 0.5, -150)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)

local title = frame:FindFirstChild("Title") or Instance.new("TextLabel", frame)
title.Name = "Title"
title.Size = UDim2.new(1, 0, 0.15, 0)
title.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
title.TextColor3 = Color3.fromRGB(255, 200, 50)
title.Text = "Choose Your Bakery"
title.TextScaled = true
title.Font = Enum.Font.GothamBold

-- 3 slot cards
for i = 1, 3 do
    local card = frame:FindFirstChild("Slot" .. i) or Instance.new("Frame", frame)
    card.Name = "Slot" .. i
    card.Size = UDim2.new(0.3, -5, 0.6, 0)
    card.Position = UDim2.new((i-1) * 0.333, 3, 0.2, 0)
    card.BackgroundColor3 = Color3.fromRGB(50, 50, 50)

    local info = card:FindFirstChild("Info") or Instance.new("TextLabel", card)
    info.Name = "Info"
    info.Size = UDim2.new(1, 0, 0.6, 0)
    info.BackgroundTransparency = 1
    info.TextColor3 = Color3.fromRGB(200, 200, 200)
    info.Text = "Slot " .. i .. "\n(Loading...)"
    info.TextScaled = true
    info.Font = Enum.Font.Gotham

    local playBtn = card:FindFirstChild("PlayBtn") or Instance.new("TextButton", card)
    playBtn.Name = "PlayBtn"
    playBtn.Size = UDim2.new(0.8, 0, 0.18, 0)
    playBtn.Position = UDim2.new(0.1, 0, 0.62, 0)
    playBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 80)
    playBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    playBtn.Text = "Play"
    playBtn.Font = Enum.Font.GothamBold
    playBtn.TextScaled = true

    local resetBtn = card:FindFirstChild("ResetBtn") or Instance.new("TextButton", card)
    resetBtn.Name = "ResetBtn"
    resetBtn.Size = UDim2.new(0.8, 0, 0.15, 0)
    resetBtn.Position = UDim2.new(0.1, 0, 0.82, 0)
    resetBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
    resetBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    resetBtn.Text = "Reset"
    resetBtn.Font = Enum.Font.GothamBold
    resetBtn.TextScaled = true
end

print("SlotSelectGui created")
```

**Step 5: Wire SlotSelect remotes on server**

Add to bottom of `PlayerDataManager.lua` (inside the `task.spawn` after RemoteManager loads), or create a thin handler script. Add to PlayerDataManager.lua:
```lua
-- Add inside PlayerDataManager.lua, at the bottom before return:
task.spawn(function()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local RemoteManager     = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
    local slotSelectRemote  = RemoteManager.Get("SlotSelect")
    local slotResultRemote  = RemoteManager.Get("SlotSelectResult")

    slotSelectRemote.OnServerEvent:Connect(function(player, action, slot)
        if action == "switch" then
            local ok, reason = PlayerDataManager.SwitchSlot(player, slot)
            slotResultRemote:FireClient(player, { success = ok, reason = reason, activeSlot = slot })
        elseif action == "reset" then
            local ok, reason = PlayerDataManager.ResetSlot(player, slot)
            slotResultRemote:FireClient(player, { success = ok, reason = reason })
        elseif action == "preview" then
            local previews = PlayerDataManager.GetSlotPreviews(player)
            slotResultRemote:FireClient(player, { success = true, previews = previews })
        end
    end)
    print("[PlayerDataManager] SlotSelect remote wired.")
end)
```

**Step 6: Sync all to Studio via MCP**

**Step 7: Verify**
- Open shop via ShopPrompt — ShopGui appears, items listed
- Buy an item — console shows `[UnlockManager] [Name] purchased...`
- Open slot terminal — SlotSelectGui shows 3 cards
- Try switching slot mid-Open phase — blocked with message

**Step 8: Commit**
```bash
git add src/StarterPlayer/StarterPlayerScripts/ShopClient.client.lua src/ServerScriptService/Core/PlayerDataManager.lua src/ServerScriptService/Core/UnlockManager.lua
git commit -m "feat(m6): unlock shop + slot select UI wired end-to-end"
```

---

## Task 11: Final wiring and end-to-end M6 test

**Step 1: Verify all RemoteEvents exist**
```lua
-- MCP run_code:
local RemoteManager = require(game:GetService("ReplicatedStorage").Modules.RemoteManager)
local required = {"RushHour","LeaderboardUpdate","PurchaseItem","PurchaseResult","SlotSelect","SlotSelectResult"}
for _, name in ipairs(required) do
    local r = RemoteManager.Get(name)
    print(name .. ": " .. r.ClassName)
end
```

**Step 2: Verify all BindableEvents exist**
```lua
-- MCP run_code:
local evts = game:GetService("ServerStorage").Events
for _, name in ipairs({"RushHourStart","RushHourEnd","StationUnlocked"}) do
    print(name .. ": " .. (evts:FindFirstChild(name) and "OK" or "MISSING"))
end
```

**Step 3: Full manual play test checklist**
- [ ] Join → tutorial auto-loads (M5 system unchanged)
- [ ] Open phase starts → EventManager schedules Rush Hour
- [ ] Rush Hour fires → console shows interval change, HUD client receives "start" event
- [ ] Rush Hour ends → interval reverts
- [ ] Complete a delivery → LeaderboardManager.RecordDelivery called, SessionStats includes cookies
- [ ] Wait 60s → leaderboard boards in back room update
- [ ] Open shop → buy station item → console shows purchase logged, PurchaseResult fires to client
- [ ] Open slot terminal → 3 slot cards shown
- [ ] Switch slot mid-Open → blocked message
- [ ] Leave game → rejoin → same slot/coins restored from DataStore
- [ ] Check console for any warns — should be clean

**Step 4: Final commit**
```bash
git add -A
git commit -m "feat(m6): M6 Meta Systems complete — events, leaderboards, shop, slots, AntiExploit"
```

---

## Notes for Implementer

- **Studio sync pattern**: For each file edit, use MCP `run_code` to patch the Studio script source. Do NOT rely on Rojo for this project — Rojo is stopped. Patch Studio first, then save the file on disk.
- **DataStore in Studio**: OrderedDataStore writes work in Studio when "Enable Studio Access to API Services" is enabled in Game Settings → Security. Check this before testing leaderboards.
- **SPAWN_INTERVAL mutable**: PersistentNPCSpawner uses `SPAWN_INTERVAL` as a local variable that Rush Hour modifies. Confirm it's declared as `local SPAWN_INTERVAL = 30` (not `local`, reassignable) — if it's typed as a constant somewhere, make it mutable.
- **Back room parts**: After MCP creates the leaderboard boards and shop counter, position them in Studio using the Move tool to fit your back room layout.
- **Slot switching UI**: The SlotSelectGui needs a ProximityPrompt too. Add one to a "SlotTerminal" Part in the back room, similar to the ShopPrompt pattern.
