# Milestone 1: Skeleton Loop — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Get one Chocolate Chip cookie through the entire pipeline end-to-end (Tutorial skip → PreOpen → Open → Mix → Dough → Fridge → Oven → Dress → Deliver to NPC → Rating → EndOfDay) using placeholder "click to complete" minigames.

**Architecture:** Build on top of existing OrderManager + MinigameServer skeleton. GameStateManager drives all phase transitions. Client minigames are placeholder buttons that immediately fire "Good" results. NPC physically waits in waiting area until box is delivered.

**Tech Stack:** Roblox Luau, MCP Studio automation (run_code, run_script_in_play_mode), Rojo file sync, existing OrderManager/MinigameServer/RemoteManager modules.

**What already exists (DO NOT rebuild):**
- `OrderManager` — full batch lifecycle API
- `MinigameServer` — station session management (all stations)
- `FridgeOvenSystem` — visual pan carry + arm animation
- `RemoteManager` — 22 RemoteEvents already registered
- `CookieData` — 6 cookie types
- `MinigameBase` — connection tracker

---

## Task 1: Add Missing RemoteEvents to GameEvents

**Files:**
- Modify: Studio `ReplicatedStorage/GameEvents` via MCP run_code

**Why first:** Every system depends on remotes. Add them all at once now.

**Step 1: Create new remotes in Studio**

```lua
-- Run via MCP run_code
local ge = game:GetService("ReplicatedStorage"):WaitForChild("GameEvents")
local needed = {
    "GameStateChanged",   -- server → all clients: (stateName, timeRemaining)
    "AcceptOrder",        -- client → server: (orderId)
    "OrderAccepted",      -- server → client: (orderId, orderData)
    "OrderFailed",        -- server → client: (orderId, reason)
    "HUDUpdate",          -- server → client: (coins, xp, activeOrders)
    "DeliverBox",         -- client → server: (boxId, npcId)
    "DeliveryResult",     -- server → client: (stars, coins, xp)
    "EndOfDaySummary",    -- server → all clients: (summaryData)
    "TutorialComplete",   -- client → server: ()
}
for _, name in ipairs(needed) do
    if not ge:FindFirstChild(name) then
        local re = Instance.new("RemoteEvent")
        re.Name = name
        re.Parent = ge
        print("Created: " .. name)
    else
        print("Exists: " .. name)
    end
end
```

**Step 2: Verify all remotes present**

```lua
-- Run via MCP run_code
local ge = game:GetService("ReplicatedStorage"):WaitForChild("GameEvents")
print("Total remotes: " .. #ge:GetChildren())
for _, r in ipairs(ge:GetChildren()) do print(r.Name) end
```

Expected: 31 total remotes, all new ones listed.

**Step 3: Commit**
```bash
git commit -m "feat(m1): add M1 RemoteEvents to GameEvents"
```

---

## Task 2: GameStateManager

**Files:**
- Create: `src/ServerScriptService/Core/GameStateManager.server.lua`

**Responsibilities:** Owns the PreOpen (5 min) → Open (15 min) → EndOfDay (30s) cycle. Broadcasts `GameStateChanged` to all clients. Other systems listen to this — they never control phase themselves.

**Step 1: Create the file**

```lua
-- src/ServerScriptService/Core/GameStateManager.server.lua
local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local RemoteManager    = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))

-- ─── Constants ────────────────────────────────────────────────────────────────
local PREOPEN_DURATION  = 5 * 60   -- 5 minutes
local OPEN_DURATION     = 15 * 60  -- 15 minutes
local SUMMARY_DURATION  = 30       -- 30 seconds

-- ─── State ────────────────────────────────────────────────────────────────────
local currentState   = "Lobby"
local stateListeners = {}          -- { [eventName] = {callbacks} }
local stateChangedRemote = RemoteManager.Get("GameStateChanged")

-- ─── Internal ─────────────────────────────────────────────────────────────────
local function broadcast(state, timeRemaining)
    currentState = state
    stateChangedRemote:FireAllClients(state, timeRemaining or 0)
    print("[GameStateManager] → " .. state)
    -- Fire local listeners
    if stateListeners[state] then
        for _, cb in ipairs(stateListeners[state]) do
            task.spawn(cb)
        end
    end
end

local function runTimer(duration, state, onTick)
    local remaining = duration
    broadcast(state, remaining)
    while remaining > 0 do
        task.wait(1)
        remaining -= 1
        if onTick then onTick(remaining) end
        -- Broadcast every 5s and at key moments
        if remaining % 5 == 0 or remaining <= 10 then
            stateChangedRemote:FireAllClients(state, remaining)
        end
    end
end

-- ─── Public API ───────────────────────────────────────────────────────────────
local GameStateManager = {}

function GameStateManager.GetState()
    return currentState
end

function GameStateManager.OnState(stateName, callback)
    if not stateListeners[stateName] then
        stateListeners[stateName] = {}
    end
    table.insert(stateListeners[stateName], callback)
end

function GameStateManager.StartCycle(isFirstDay)
    local preOpenDuration = isFirstDay and PREOPEN_DURATION or (3 * 60)

    -- PRE-OPEN
    runTimer(preOpenDuration, "PreOpen")

    -- OPEN
    runTimer(OPEN_DURATION, "Open")

    -- END OF DAY
    broadcast("EndOfDay", SUMMARY_DURATION)
    task.wait(SUMMARY_DURATION)

    -- Loop
    GameStateManager.StartCycle(false)
end

-- ─── Init ─────────────────────────────────────────────────────────────────────
-- Wait for at least one player before starting
Players.PlayerAdded:Wait()
task.wait(2) -- brief settle

broadcast("Lobby", 0)
task.spawn(function()
    GameStateManager.StartCycle(true)
end)

print("[GameStateManager] Ready.")
return GameStateManager
```

**Step 2: Verify Rojo syncs the file**

```lua
-- MCP run_code
local sss = game:GetService("ServerScriptService")
local gsc = sss:FindFirstChild("Core") and sss.Core:FindFirstChild("GameStateManager")
print(gsc and "GameStateManager found: " .. #gsc.Source:split("\n") .. " lines" or "NOT FOUND - check Rojo")
```

Expected: `GameStateManager found: ~80 lines`

**Step 3: Smoke test in play mode**

```lua
-- MCP run_script_in_play_mode
-- Verify state transitions fire within first 10 seconds
-- (we'll use shortened timers for testing - swap back after)
```

Run play mode for 5 seconds and check output log for `[GameStateManager] → PreOpen`

**Step 4: Commit**
```bash
git add src/ServerScriptService/Core/GameStateManager.server.lua
git commit -m "feat(m1): add GameStateManager with PreOpen/Open/EndOfDay cycle"
```

---

## Task 3: PlayerDataManager (In-Memory Skeleton)

**Files:**
- Create: `src/ServerScriptService/Core/PlayerDataManager.server.lua`

**Note:** DataStore persistence comes in Milestone 4. This M1 version is in-memory only — data resets on server restart. API surface is identical so M4 just swaps the backend.

**Step 1: Create the file**

```lua
-- src/ServerScriptService/Core/PlayerDataManager.server.lua
local Players = game:GetService("Players")

-- ─── Default Profile ──────────────────────────────────────────────────────────
local DEFAULT_PROFILE = {
    coins           = 0,
    xp              = 0,
    level           = 1,
    comboStreak     = 0,
    ordersCompleted = 0,
    perfectOrders   = 0,
    failedOrders    = 0,
    tutorialCompleted = false,
    rebirths        = 0,
    unlockedRecipes = {"chocolate_chip"},  -- start with one unlocked
    -- Hooks for future systems:
    ownedMachines   = {},
    ratingScore     = 0,
    stats           = { fastestOrderTime = math.huge },
}

-- ─── State ────────────────────────────────────────────────────────────────────
local profiles = {}  -- [userId] = profileTable

-- ─── Private ──────────────────────────────────────────────────────────────────
local function newProfile()
    local p = {}
    for k, v in pairs(DEFAULT_PROFILE) do
        p[k] = type(v) == "table" and {} or v
        if type(v) == "table" then
            for k2, v2 in pairs(v) do p[k][k2] = v2 end
        end
    end
    return p
end

-- ─── Public API ───────────────────────────────────────────────────────────────
local PlayerDataManager = {}

function PlayerDataManager.GetData(player)
    return profiles[player.UserId]
end

function PlayerDataManager.AddCoins(player, amount)
    local p = profiles[player.UserId]
    if not p then return end
    p.coins = math.max(0, p.coins + amount)
    return p.coins
end

function PlayerDataManager.AddXP(player, amount)
    local p = profiles[player.UserId]
    if not p then return end
    p.xp = p.xp + amount
    -- Simple level up check
    local required = math.floor(100 * (p.level ^ 1.35))
    while p.xp >= required do
        p.xp -= required
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

function PlayerDataManager.SetTutorialCompleted(player)
    local p = profiles[player.UserId]
    if p then p.tutorialCompleted = true end
end

-- ─── Lifecycle ────────────────────────────────────────────────────────────────
Players.PlayerAdded:Connect(function(player)
    profiles[player.UserId] = newProfile()
    print("[PlayerDataManager] Profile created for " .. player.Name)
end)

Players.PlayerRemoving:Connect(function(player)
    -- M4: save to DataStore here
    profiles[player.UserId] = nil
end)

-- Handle players already in server
for _, player in ipairs(Players:GetPlayers()) do
    profiles[player.UserId] = newProfile()
end

print("[PlayerDataManager] Ready (in-memory, M4 adds DataStore).")
return PlayerDataManager
```

**Step 2: Verify in Studio**
```lua
-- MCP run_code
local s = game:GetService("ServerScriptService").Core:FindFirstChild("PlayerDataManager")
print(s and "Found: " .. #s.Source:split("\n") .. " lines" or "NOT FOUND")
```

**Step 3: Commit**
```bash
git add src/ServerScriptService/Core/PlayerDataManager.server.lua
git commit -m "feat(m1): add PlayerDataManager in-memory skeleton (DataStore in M4)"
```

---

## Task 4: EconomyManager (Payout Formulas)

**Files:**
- Create: `src/ServerScriptService/Core/EconomyManager.server.lua`

**Step 1: Create the file**

```lua
-- src/ServerScriptService/Core/EconomyManager.server.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CookieData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CookieData"))

-- ─── Recipe Base Values ────────────────────────────────────────────────────────
local RECIPE_VALUES = {
    pink_sugar           = { coins = 10,  time = 90  },
    chocolate_chip       = { coins = 15,  time = 90  },
    snickerdoodle        = { coins = 25,  time = 120 },
    birthday_cake        = { coins = 40,  time = 120 },
    cookies_and_cream    = { coins = 65,  time = 150 },
    lemon_blackraspberry = { coins = 100, time = 150 },
}

local TOTAL_MULTIPLIER_CAP = 3.0

-- ─── Public API ───────────────────────────────────────────────────────────────
local EconomyManager = {}

function EconomyManager.GetRecipeValue(cookieId)
    return RECIPE_VALUES[cookieId] or { coins = 10, time = 90 }
end

--[[
    CalculatePayout
    @param cookieId      string
    @param quantity      number
    @param stars         number (1-5)
    @param timeRemaining number (seconds left when delivered)
    @param totalTime     number (original time limit)
    @param comboStreak   number (0-20)
    @param isVIP         boolean
    @returns { coins: number, xp: number }
]]
function EconomyManager.CalculatePayout(cookieId, quantity, stars, timeRemaining, totalTime, comboStreak, isVIP)
    local recipe = EconomyManager.GetRecipeValue(cookieId)
    local base   = recipe.coins * (quantity or 1)

    -- Multipliers
    local speedMult    = 1 + (math.max(0, timeRemaining) / math.max(1, totalTime)) * 0.5
    local accuracyMult = 0.5 + ((stars - 1) / 4) * 1.0  -- 1★=0.5 to 5★=1.5
    local comboMult    = 1 + (0.05 * math.min(comboStreak or 0, 20))
    local vipMult      = isVIP and 1.75 or 1.0

    local totalMult = math.min(speedMult * accuracyMult * comboMult * vipMult, TOTAL_MULTIPLIER_CAP)
    local coins     = math.floor(base * totalMult)
    local xp        = math.floor(base * 0.6 * accuracyMult * (stars == 5 and 1.2 or 1.0))

    return { coins = coins, xp = xp, multiplier = totalMult }
end

--[[
    CalculateStars — weighted rating formula
    @param correctness   0-1 (recipe + modifiers matched)
    @param speedRatio    0-1 (timeRemaining / totalTime)
    @param doneness      string ("Perfect"|"SlightlyBrown"|"Underbaked"|"Burned")
    @param mixQuality    0-100
    @param decorScore    0-1
    @returns number (1-5)
]]
function EconomyManager.CalculateStars(correctness, speedRatio, doneness, mixQuality, decorScore)
    local donenessScore = ({
        Perfect      = 1.0,
        SlightlyBrown = 0.7,
        Underbaked   = 0.5,
        Burned       = 0.0,
    })[doneness] or 0.5

    local raw = (correctness    * 0.35)
              + (speedRatio     * 0.30)
              + (donenessScore  * 0.20)
              + ((mixQuality / 100) * 0.10)
              + ((decorScore or 1) * 0.05)

    -- Map 0-1 → 1-5 stars
    return math.clamp(math.floor(raw * 5) + 1, 1, 5)
end

print("[EconomyManager] Ready.")
return EconomyManager
```

**Step 2: Commit**
```bash
git add src/ServerScriptService/Core/EconomyManager.server.lua
git commit -m "feat(m1): add EconomyManager with payout and star formulas"
```

---

## Task 5: POSController (Server)

**Files:**
- Create: `src/ServerScriptService/POSController.server.lua`

**Responsibilities:** Manages the NPC order queue shown at POS. Handles order acceptance with 30s lock. Integrates with OrderManager for order data. Only active during Open phase.

**Step 1: Create the file**

```lua
-- src/ServerScriptService/POSController.server.lua
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RemoteManager  = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local OrderManager   = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("OrderManager"))

local acceptRemote   = RemoteManager.Get("AcceptOrder")
local acceptedRemote = RemoteManager.Get("OrderAccepted")
local failedRemote   = RemoteManager.Get("OrderFailed")
local stateRemote    = RemoteManager.Get("GameStateChanged")

-- ─── State ────────────────────────────────────────────────────────────────────
local isOpen         = false
local orderLocks     = {}   -- [orderId] = { player, expireTime }

-- ─── Lock Management ──────────────────────────────────────────────────────────
local LOCK_DURATION  = 30

local function isLocked(orderId)
    local lock = orderLocks[orderId]
    if not lock then return false end
    if os.time() > lock.expireTime then
        orderLocks[orderId] = nil
        return false
    end
    return true, lock.player
end

local function acquireLock(player, orderId)
    if isLocked(orderId) then return false end
    orderLocks[orderId] = {
        player     = player,
        expireTime = os.time() + LOCK_DURATION,
    }
    return true
end

-- ─── Accept Order ─────────────────────────────────────────────────────────────
acceptRemote.OnServerEvent:Connect(function(player, orderId)
    if not isOpen then
        failedRemote:FireClient(player, orderId, "Store is not open")
        return
    end

    local orders = OrderManager.GetNPCOrders()
    local order  = orders[orderId]
    if not order then
        failedRemote:FireClient(player, orderId, "Order not found")
        return
    end

    if not acquireLock(player, orderId) then
        failedRemote:FireClient(player, orderId, "Order already taken")
        return
    end

    acceptedRemote:FireClient(player, orderId, order)
    print(string.format("[POSController] %s accepted order %s (%s)", player.Name, orderId, order.cookieId or "?"))
end)

-- ─── Game State Listener ──────────────────────────────────────────────────────
stateRemote -- NOTE: GameStateManager uses a BindableEvent pattern internally.
-- Wire via the GameStateManager module once it's accessible.
-- For M1, listen to the broadcast remote from server side is not standard.
-- Instead, GameStateManager will call POSController.SetOpen() directly.

local POSController = {}

function POSController.SetOpen(open)
    isOpen = open
    if not open then
        orderLocks = {} -- clear all locks when store closes
    end
    print("[POSController] Store " .. (open and "OPEN" or "CLOSED"))
end

function POSController.GetQueue()
    return OrderManager.GetNPCOrders()
end

print("[POSController] Ready.")
return POSController
```

**Step 2: Commit**
```bash
git add src/ServerScriptService/POSController.server.lua
git commit -m "feat(m1): add POSController with 30s order lock"
```

---

## Task 6: NPC System — Waiting Area Integration

**Files:**
- Modify: Studio `ServerScriptService/Core/PersistentNPCSpawner` via MCP
- Modify: Studio `ReplicatedStorage/Modules/NPCSpawner` via MCP

**Goal:** NPCs spawn during Open phase, walk to a seat in the waiting area, show patience bar, wait until order delivered or patience expires.

**Step 1: Add NPC waiting spots to map**

```lua
-- MCP run_code: Create WaitingSpots folder with Part anchors
local workspace = game:GetService("Workspace")
local waiting = workspace:FindFirstChild("WaitingArea")
if not waiting then
    waiting = Instance.new("Folder")
    waiting.Name = "WaitingArea"
    waiting.Parent = workspace
end

-- Create 6 spot Parts (positions approximate - adjust in Studio after)
local BASE_POS = Vector3.new(0, 0, 10) -- adjust to match your waiting area
for i = 1, 6 do
    local existing = waiting:FindFirstChild("Spot" .. i)
    if not existing then
        local spot = Instance.new("Part")
        spot.Name    = "Spot" .. i
        spot.Size    = Vector3.new(2, 0.1, 2)
        spot.Anchored = true
        spot.CanCollide = false
        spot.Transparency = 0.8
        spot.BrickColor  = BrickColor.new("Bright yellow")
        spot.CFrame = CFrame.new(BASE_POS + Vector3.new((i - 1) * 3, 0, 0))
        spot.Parent  = waiting
    end
end
print("WaitingArea spots: " .. #waiting:GetChildren())
```

**Step 2: Update PersistentNPCSpawner to respond to game state**

Patch PersistentNPCSpawner in Studio to:
- Start spawning NPCs only when `GameStateChanged` fires "Open"
- Stop spawning on "EndOfDay" or "PreOpen"
- Each NPC gets an `OrderId` attribute when assigned
- NPCs pathfind to an open Spot, then wait

```lua
-- MCP run_code: Patch PersistentNPCSpawner
local sss   = game:GetService("ServerScriptService")
local spawner = sss.Core:FindFirstChild("PersistentNPCSpawner")
local ge    = game:GetService("ReplicatedStorage"):WaitForChild("GameEvents")
local stateRemote = ge:WaitForChild("GameStateChanged")

-- Add state listener to spawner
local patch = [[

-- M1 patch: only spawn during Open phase
local _spawning = false
game:GetService("ReplicatedStorage"):WaitForChild("GameEvents"):WaitForChild("GameStateChanged").OnClientEvent:Connect(function(state)
    _spawning = (state == "Open")
end)
]]

if not spawner.Source:find("_spawning") then
    spawner.Source = patch .. spawner.Source
    print("PersistentNPCSpawner patched")
else
    print("Already patched")
end
```

**Step 3: Add patience BillboardGui to NPC template**

```lua
-- MCP run_code
local function addPatienceGui(npcModel)
    if npcModel:FindFirstChild("PatienceGui") then return end
    local bb = Instance.new("BillboardGui")
    bb.Name          = "PatienceGui"
    bb.Size          = UDim2.new(0, 100, 0, 20)
    bb.StudsOffset   = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop   = true

    local bar = Instance.new("Frame")
    bar.Name            = "Bar"
    bar.Size            = UDim2.new(1, 0, 1, 0)
    bar.BackgroundColor3 = Color3.fromRGB(100, 200, 100)
    bar.BorderSizePixel  = 0
    bar.Parent           = bb

    bb.Parent = npcModel
end

-- Apply to existing NPC templates in workspace
for _, npc in ipairs(workspace:GetDescendants()) do
    if npc:IsA("Model") and npc:FindFirstChild("Humanoid") and npc.Name:find("NPC") then
        addPatienceGui(npc)
        print("Added patience gui to: " .. npc.Name)
    end
end
```

**Step 4: Commit**
```bash
git commit -m "feat(m1): add NPC waiting area spots and patience UI"
```

---

## Task 7: Placeholder Minigames (All 5 Stations)

**Files:**
- Create: `src/StarterPlayerScripts/Minigames/PlaceholderMinigame.client.lua`

**Goal:** One universal placeholder client script. When MinigameServer fires `StartXxxMinigame` to the client, show a simple UI: "Station Name — Click to Complete". On click, fire the result event back with `score = 80` (Good result). This wires the full pipeline without building real mechanics yet.

**Step 1: Create universal placeholder**

```lua
-- src/StarterPlayerScripts/Minigames/PlaceholderMinigame.client.lua
-- M1: Placeholder for all station minigames.
-- Replace each with real mechanic in Milestone 2.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ─── Config: which events to intercept ────────────────────────────────────────
local STATIONS = {
    { start = "StartMixMinigame",    result = "MixMinigameResult",    label = "🥣 Mixing..."    },
    { start = "StartDoughMinigame",  result = "DoughMinigameResult",  label = "🫳 Dough Table..." },
    { start = "StartOvenMinigame",   result = "OvenMinigameResult",   label = "🔥 Baking..."    },
    { start = "StartFrostMinigame",  result = "FrostMinigameResult",  label = "🍦 Frosting..."  },
    { start = "StartDressMinigame",  result = "DressMinigameResult",  label = "📦 Packing..."   },
}

-- ─── Placeholder UI ───────────────────────────────────────────────────────────
local function showPlaceholder(label, onComplete)
    -- Remove any existing placeholder
    local existing = playerGui:FindFirstChild("PlaceholderMinigame")
    if existing then existing:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name            = "PlaceholderMinigame"
    sg.ResetOnSpawn    = false
    sg.Parent          = playerGui

    local frame = Instance.new("Frame")
    frame.Size              = UDim2.new(0, 300, 0, 120)
    frame.Position          = UDim2.new(0.5, -150, 0.5, -60)
    frame.BackgroundColor3  = Color3.fromRGB(30, 30, 30)
    frame.BorderSizePixel   = 0
    frame.Parent            = sg

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = frame

    local title = Instance.new("TextLabel")
    title.Size              = UDim2.new(1, 0, 0.5, 0)
    title.BackgroundTransparency = 1
    title.TextColor3        = Color3.fromRGB(255, 255, 255)
    title.TextScaled        = true
    title.Font              = Enum.Font.GothamBold
    title.Text              = label
    title.Parent            = frame

    local btn = Instance.new("TextButton")
    btn.Size                = UDim2.new(0.6, 0, 0.35, 0)
    btn.Position            = UDim2.new(0.2, 0, 0.58, 0)
    btn.BackgroundColor3    = Color3.fromRGB(80, 200, 120)
    btn.TextColor3          = Color3.fromRGB(255, 255, 255)
    btn.TextScaled          = true
    btn.Font                = Enum.Font.GothamBold
    btn.Text                = "✓ Complete"
    btn.BorderSizePixel     = 0
    btn.Parent              = frame

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 8)
    btnCorner.Parent = btn

    btn.MouseButton1Click:Connect(function()
        sg:Destroy()
        onComplete()
    end)
end

-- ─── Wire each station ────────────────────────────────────────────────────────
for _, station in ipairs(STATIONS) do
    local startRemote  = RemoteManager.Get(station.start)
    local resultRemote = RemoteManager.Get(station.result)

    startRemote.OnClientEvent:Connect(function(...)
        local args = {...}
        showPlaceholder(station.label, function()
            -- Fire result back with "Good" score (80)
            resultRemote:FireServer(80, table.unpack(args))
        end)
    end)
end

print("[PlaceholderMinigame] All 5 station placeholders active.")
```

**Step 2: Verify in play mode**
```lua
-- run_script_in_play_mode: trigger a mix session and verify placeholder UI appears
-- Check console for "[PlaceholderMinigame] All 5 station placeholders active."
```

**Step 3: Commit**
```bash
git add src/StarterPlayerScripts/Minigames/PlaceholderMinigame.client.lua
git commit -m "feat(m1): add universal placeholder minigame UI for all 5 stations"
```

---

## Task 8: POS Client UI

**Files:**
- Create: `src/StarterGui/POSGui/POSClient.client.lua`
- Create: `src/StarterGui/POSGui` (ScreenGui in Studio)

**Goal:** Player walks up to POS, presses E, sees order tickets. Clicks to accept. Active order shown on screen.

**Step 1: Create POSGui ScreenGui in Studio via MCP**

```lua
-- MCP run_code
local sg = game:GetService("StarterGui")
if not sg:FindFirstChild("POSGui") then
    local gui = Instance.new("ScreenGui")
    gui.Name         = "POSGui"
    gui.ResetOnSpawn = false
    gui.Enabled      = false
    gui.Parent       = sg
    print("Created POSGui")
end
```

**Step 2: Create POSClient.client.lua**

```lua
-- src/StarterGui/POSGui/POSClient.client.lua
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")

local RemoteManager    = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local OrderManager     = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("OrderManager"))

local acceptRemote  = RemoteManager.Get("AcceptOrder")
local acceptedEvent = RemoteManager.Get("OrderAccepted")
local stateRemote   = RemoteManager.Get("GameStateChanged")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local posGui    = playerGui:WaitForChild("POSGui")

-- ─── State ────────────────────────────────────────────────────────────────────
local isOpen       = false
local activeOrders = {}

-- ─── UI Builder ───────────────────────────────────────────────────────────────
local function buildOrderTicket(orderId, orderData, parent)
    local frame = Instance.new("Frame")
    frame.Name              = "Order_" .. orderId
    frame.Size              = UDim2.new(1, -10, 0, 80)
    frame.BackgroundColor3  = orderData.vipFlag
                              and Color3.fromRGB(255, 215, 0)
                              or  Color3.fromRGB(240, 240, 240)
    frame.BorderSizePixel   = 0
    frame.Parent            = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size              = UDim2.new(0.65, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3        = Color3.fromRGB(30, 30, 30)
    label.TextXAlignment    = Enum.TextXAlignment.Left
    label.TextScaled        = true
    label.Font              = Enum.Font.Gotham
    label.Text              = string.format("  🍪 %s  ×%d%s",
        orderData.cookieId or "?",
        orderData.quantity or 1,
        orderData.vipFlag and "  ⭐VIP" or "")
    label.Parent            = frame

    local btn = Instance.new("TextButton")
    btn.Size                = UDim2.new(0.3, -5, 0.6, 0)
    btn.Position            = UDim2.new(0.68, 0, 0.2, 0)
    btn.BackgroundColor3    = Color3.fromRGB(80, 180, 100)
    btn.TextColor3          = Color3.fromRGB(255, 255, 255)
    btn.TextScaled          = true
    btn.Font                = Enum.Font.GothamBold
    btn.Text                = "Accept"
    btn.BorderSizePixel     = 0
    btn.Parent              = frame

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = btn

    btn.MouseButton1Click:Connect(function()
        acceptRemote:FireServer(orderId)
        frame:Destroy()
    end)
end

local function refreshPOS()
    local list = posGui:FindFirstChild("OrderList")
    if not list then return end
    for _, c in ipairs(list:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    local orders = OrderManager.GetNPCOrders()
    for id, data in pairs(orders) do
        buildOrderTicket(id, data, list)
    end
end

local function openPOS()
    posGui.Enabled = true
    refreshPOS()
end

local function closePOS()
    posGui.Enabled = false
end

-- ─── POS ProximityPrompt ──────────────────────────────────────────────────────
-- Wire to POS ProximityPrompt in workspace
-- This runs on the client: LocalScript sees PromptTriggered
local ProximityPromptService = game:GetService("ProximityPromptService")
ProximityPromptService.PromptTriggered:Connect(function(prompt, triggeringPlayer)
    if triggeringPlayer ~= player then return end
    if prompt.Name ~= "POSPrompt" then return end
    if posGui.Enabled then
        closePOS()
    else
        openPOS()
    end
end)

-- Close POS with Escape
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.Escape and posGui.Enabled then
        closePOS()
    end
end)

-- ─── Game State ───────────────────────────────────────────────────────────────
stateRemote.OnClientEvent:Connect(function(state)
    isOpen = (state == "Open")
    if not isOpen then closePOS() end
end)

-- ─── Order Accepted Feedback ──────────────────────────────────────────────────
acceptedEvent.OnClientEvent:Connect(function(orderId, orderData)
    activeOrders[orderId] = orderData
    print("[POSClient] Order accepted: " .. orderId)
    -- Active order ticket shown in HUD (Task 9)
end)

print("[POSClient] Ready.")
```

**Step 3: Add POSPrompt to POS tablet in Studio**

```lua
-- MCP run_code
local pos = workspace:FindFirstChild("POS")
if pos then
    local tablet = pos:FindFirstChild("Tablet") or pos:FindFirstDescendant("Tablet")
    if tablet and tablet:IsA("BasePart") then
        local prompt = Instance.new("ProximityPrompt")
        prompt.Name         = "POSPrompt"
        prompt.ActionText   = "View Orders"
        prompt.ObjectText   = "POS"
        prompt.MaxActivationDistance = 8
        prompt.Parent       = tablet
        print("POSPrompt added to " .. tablet:GetFullName())
    end
end
```

**Step 4: Commit**
```bash
git add src/StarterGui/POSGui/
git commit -m "feat(m1): add POS client UI with order tickets and accept button"
```

---

## Task 9: Basic HUD

**Files:**
- Create: `src/StarterGui/HUD/HUDController.client.lua`

**Goal:** Always-visible overlay showing: phase timer, coin count, active order name. Updates in real-time.

**Step 1: Create HUD ScreenGui in Studio**

```lua
-- MCP run_code
local sg = game:GetService("StarterGui")
if not sg:FindFirstChild("HUD") then
    local gui = Instance.new("ScreenGui")
    gui.Name         = "HUD"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 10
    gui.Parent       = sg

    -- Timer (top center)
    local timer = Instance.new("TextLabel")
    timer.Name              = "TimerLabel"
    timer.Size              = UDim2.new(0, 200, 0, 40)
    timer.Position          = UDim2.new(0.5, -100, 0, 10)
    timer.BackgroundColor3  = Color3.fromRGB(30, 30, 30)
    timer.BackgroundTransparency = 0.3
    timer.TextColor3        = Color3.fromRGB(255, 255, 255)
    timer.TextScaled        = true
    timer.Font              = Enum.Font.GothamBold
    timer.Text              = "PRE-OPEN  5:00"
    timer.Parent            = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = timer

    -- Coins (top left)
    local coins = Instance.new("TextLabel")
    coins.Name              = "CoinsLabel"
    coins.Size              = UDim2.new(0, 150, 0, 40)
    coins.Position          = UDim2.new(0, 10, 0, 10)
    coins.BackgroundColor3  = Color3.fromRGB(255, 200, 0)
    coins.BackgroundTransparency = 0.2
    coins.TextColor3        = Color3.fromRGB(30, 30, 30)
    coins.TextScaled        = true
    coins.Font              = Enum.Font.GothamBold
    coins.Text              = "🪙 0"
    coins.Parent            = gui

    local corner2 = Instance.new("UICorner")
    corner2.CornerRadius = UDim.new(0, 8)
    corner2.Parent = coins

    -- Active Order (top right)
    local order = Instance.new("TextLabel")
    order.Name              = "ActiveOrderLabel"
    order.Size              = UDim2.new(0, 200, 0, 40)
    order.Position          = UDim2.new(1, -210, 0, 10)
    order.BackgroundColor3  = Color3.fromRGB(80, 180, 100)
    order.BackgroundTransparency = 0.3
    order.TextColor3        = Color3.fromRGB(255, 255, 255)
    order.TextScaled        = true
    order.Font              = Enum.Font.Gotham
    order.Text              = "No active order"
    order.Parent            = gui

    local corner3 = Instance.new("UICorner")
    corner3.CornerRadius = UDim.new(0, 8)
    corner3.Parent = order

    print("HUD created in StarterGui")
end
```

**Step 2: Create HUDController.client.lua**

```lua
-- src/StarterGui/HUD/HUDController.client.lua
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local stateRemote   = RemoteManager.Get("GameStateChanged")
local acceptedEvent = RemoteManager.Get("OrderAccepted")
local deliveryEvent = RemoteManager.Get("DeliveryResult")
local hudUpdateEvent = RemoteManager.Get("HUDUpdate")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local hud       = playerGui:WaitForChild("HUD")
local timerLbl  = hud:WaitForChild("TimerLabel")
local coinsLbl  = hud:WaitForChild("CoinsLabel")
local orderLbl  = hud:WaitForChild("ActiveOrderLabel")

local STATE_LABELS = {
    PreOpen  = "PRE-OPEN",
    Open     = "OPEN",
    EndOfDay = "END OF DAY",
    Lobby    = "LOBBY",
}

local function formatTime(seconds)
    local m = math.floor(seconds / 60)
    local s = seconds % 60
    return string.format("%d:%02d", m, s)
end

stateRemote.OnClientEvent:Connect(function(state, timeRemaining)
    local label = STATE_LABELS[state] or state
    timerLbl.Text = label .. "  " .. formatTime(timeRemaining or 0)
    timerLbl.BackgroundColor3 = state == "Open"
        and Color3.fromRGB(60, 140, 60)
        or  Color3.fromRGB(30, 30, 30)
end)

hudUpdateEvent.OnClientEvent:Connect(function(coins, xp, activeOrderName)
    coinsLbl.Text = "🪙 " .. (coins or 0)
    if activeOrderName then
        orderLbl.Text = "🍪 " .. activeOrderName
        orderLbl.BackgroundColor3 = Color3.fromRGB(80, 180, 100)
    else
        orderLbl.Text = "No active order"
        orderLbl.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    end
end)

deliveryEvent.OnClientEvent:Connect(function(stars, coins, xp)
    -- Flash delivery result
    local flash = Instance.new("TextLabel")
    flash.Size              = UDim2.new(0, 250, 0, 60)
    flash.Position          = UDim2.new(0.5, -125, 0.4, 0)
    flash.BackgroundColor3  = stars >= 4
        and Color3.fromRGB(255, 200, 0)
        or  Color3.fromRGB(200, 100, 100)
    flash.TextColor3        = Color3.fromRGB(255, 255, 255)
    flash.TextScaled        = true
    flash.Font              = Enum.Font.GothamBold
    flash.Text              = string.rep("⭐", stars) .. "\n+" .. coins .. " coins"
    flash.ZIndex            = 50
    flash.Parent            = hud

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = flash

    game:GetService("Debris"):AddItem(flash, 2.5)
end)

print("[HUDController] Ready.")
```

**Step 3: Commit**
```bash
git add src/StarterGui/HUD/
git commit -m "feat(m1): add basic HUD with timer, coins, and active order display"
```

---

## Task 10: Delivery System — Box to NPC

**Files:**
- Modify: Studio `ServerScriptService/FridgeOvenSystem` (extend for box carry)
- Create server-side delivery handler

**Goal:** After Dress station, player receives a box model, carries it to the waiting NPC, triggers delivery via ProximityPrompt on the NPC. Server validates and triggers rating + payout.

**Step 1: Add delivery handler to server**

```lua
-- MCP run_code: patch FridgeOvenSystem or add new script
-- Add box carry + NPC delivery to FridgeOvenSystem

local ss  = game:GetService("ServerScriptService")
local fos = ss:FindFirstChild("FridgeOvenSystem")
local ge  = game:GetService("ReplicatedStorage"):WaitForChild("GameEvents")

local deliverRemote  = ge:WaitForChild("DeliverBox")
local deliveryResult = ge:WaitForChild("DeliveryResult")
local hudUpdate      = ge:WaitForChild("HUDUpdate")

-- Load dependencies
local RS = game:GetService("ReplicatedStorage")
local OrderManager   = require(RS:WaitForChild("Modules"):WaitForChild("OrderManager"))

local boxCarryState = {}  -- [player] = { boxId, boxModel }

-- When DressMinigame completes, OrderManager.CreateBox is called server-side
-- Then FireClient to tell player they have a box
-- (This is wired through MinigameServer's endSession for "dress")

-- Client fires DeliverBox when they walk up to the NPC
deliverRemote.OnServerEvent:Connect(function(player, boxId, npcOrderId)
    local state = boxCarryState[player]
    if not state or state.boxId ~= boxId then
        warn("[Delivery] " .. player.Name .. " invalid box delivery attempt")
        return
    end

    local result = OrderManager.DeliverBox(player, boxId, npcOrderId)
    if result then
        -- Temporary: hardcode Good result until RatingSystem is wired in M4
        local stars  = 4
        local coins  = 30
        local xp     = 20

        deliveryResult:FireClient(player, stars, coins, xp)
        hudUpdate:FireClient(player, coins, xp, nil) -- clear active order

        -- Destroy carried box
        if state.boxModel and state.boxModel.Parent then
            state.boxModel:Destroy()
        end
        boxCarryState[player] = nil

        print(string.format("[Delivery] %s delivered order %s — %d stars", player.Name, npcOrderId, stars))
    end
end)

print("[Delivery] Handler added")
```

**Step 2: Add ProximityPrompt to NPC models for delivery**

```lua
-- MCP run_code: Add DeliveryPrompt to waiting NPCs
for _, npc in ipairs(workspace:GetDescendants()) do
    if npc:IsA("Model") and npc:FindFirstChild("Humanoid") then
        local hrp = npc:FindFirstChild("HumanoidRootPart")
        if hrp and not hrp:FindFirstChild("DeliveryPrompt") then
            local prompt = Instance.new("ProximityPrompt")
            prompt.Name       = "DeliveryPrompt"
            prompt.ActionText = "Deliver"
            prompt.ObjectText = "Customer"
            prompt.MaxActivationDistance = 6
            prompt.Enabled    = true
            prompt.Parent     = hrp
        end
    end
end
print("DeliveryPrompts added to NPCs")
```

**Step 3: Client-side delivery trigger**

```lua
-- Add to HUDController or separate DeliveryClient.client.lua
-- ProximityPromptService.PromptTriggered for "DeliveryPrompt"
-- Fires DeliverBox remote with boxId + npcOrderId
```

**Step 4: Commit**
```bash
git commit -m "feat(m1): add box delivery system with NPC ProximityPrompt"
```

---

## Task 11: End-of-Day Summary Screen

**Files:**
- Create: `src/StarterGui/SummaryGui/SummaryController.client.lua`

**Step 1: Create SummaryGui in Studio**

```lua
-- MCP run_code
local sg = game:GetService("StarterGui")
if not sg:FindFirstChild("SummaryGui") then
    local gui = Instance.new("ScreenGui")
    gui.Name         = "SummaryGui"
    gui.ResetOnSpawn = false
    gui.Enabled      = false
    gui.DisplayOrder = 20
    gui.Parent       = sg

    local frame = Instance.new("Frame")
    frame.Name              = "SummaryFrame"
    frame.Size              = UDim2.new(0, 400, 0, 300)
    frame.Position          = UDim2.new(0.5, -200, 0.5, -150)
    frame.BackgroundColor3  = Color3.fromRGB(20, 20, 20)
    frame.Parent            = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 16)
    corner.Parent = frame

    local title = Instance.new("TextLabel")
    title.Name              = "Title"
    title.Size              = UDim2.new(1, 0, 0.2, 0)
    title.BackgroundTransparency = 1
    title.TextColor3        = Color3.fromRGB(255, 200, 0)
    title.TextScaled        = true
    title.Font              = Enum.Font.GothamBold
    title.Text              = "🍪 End of Day!"
    title.Parent            = frame

    local body = Instance.new("TextLabel")
    body.Name               = "Body"
    body.Size               = UDim2.new(1, -20, 0.6, 0)
    body.Position           = UDim2.new(0, 10, 0.22, 0)
    body.BackgroundTransparency = 1
    body.TextColor3         = Color3.fromRGB(220, 220, 220)
    body.TextScaled         = true
    body.Font               = Enum.Font.Gotham
    body.Text               = "Orders: 0\nCoins Earned: 0\nAvg Rating: ★★★★"
    body.Parent             = frame

    print("SummaryGui created")
end
```

**Step 2: Create SummaryController.client.lua**

```lua
-- src/StarterGui/SummaryGui/SummaryController.client.lua
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local summaryEvent  = RemoteManager.Get("EndOfDaySummary")
local stateRemote   = RemoteManager.Get("GameStateChanged")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local gui       = playerGui:WaitForChild("SummaryGui")
local frame     = gui:WaitForChild("SummaryFrame")
local body      = frame:WaitForChild("Body")

summaryEvent.OnClientEvent:Connect(function(data)
    body.Text = string.format(
        "Orders Completed: %d\nCoins Earned: 🪙%d\nBest Combo: 🔥×%d\nAvg Rating: %s",
        data.orders or 0,
        data.coins  or 0,
        data.combo  or 0,
        string.rep("⭐", math.round(data.avgStars or 3))
    )
    gui.Enabled = true
end)

stateRemote.OnClientEvent:Connect(function(state)
    if state == "PreOpen" then
        gui.Enabled = false
    end
end)

print("[SummaryController] Ready.")
```

**Step 3: Wire GameStateManager to fire EndOfDaySummary**

Add to GameStateManager (EndOfDay phase):
```lua
-- In GameStateManager, during EndOfDay broadcast:
local summaryRemote = RemoteManager.Get("EndOfDaySummary")
summaryRemote:FireAllClients({
    orders   = 0,    -- TODO M4: pull from PlayerDataManager session totals
    coins    = 0,
    combo    = 0,
    avgStars = 3,
})
```

**Step 4: Commit**
```bash
git add src/StarterGui/SummaryGui/
git commit -m "feat(m1): add end-of-day summary screen"
```

---

## Task 12: Wire Everything Together + Full Smoke Test

**Goal:** Run the complete loop in play mode. One player completes the full pipeline and gets a delivery rating.

**Step 1: Verify GameStateManager fires and all systems respond**

```lua
-- MCP run_script_in_play_mode (start_play, 15s timeout)
-- Check console for:
-- [GameStateManager] → PreOpen
-- [PlayerDataManager] Ready
-- [POSController] Ready
-- [PlaceholderMinigame] All 5 station placeholders active
-- [HUDController] Ready
```

**Step 2: Manually walk through the loop**

Using MCP run_code while in play mode:
1. Verify fridge has stock (OrderManager.GetFridgeState())
2. Trigger an NPC order (OrderManager.AddNPCOrder)
3. Accept the order via POS
4. Trigger each station placeholder in sequence
5. Verify delivery fires DeliveryResult with stars + coins

**Step 3: Fix any wiring issues found**

Common issues to check:
- MinigameServer's `startSession` called with correct stationName
- OrderManager batch state advancing after each station
- FridgePulled BindableEvent fires correctly
- Box created after Dress station

**Step 4: Final integration commit**
```bash
git add -A
git commit -m "feat(m1): complete skeleton loop wired end-to-end

Full pipeline: PreOpen → Mix → Dough → Fridge → Oven → Dress → Delivery → EndOfDay
All placeholder minigames active. Basic HUD, POS, NPC delivery functional.
Ready for Milestone 2: real minigame mechanics."
```

---

## Acceptance Checklist for M1

- [ ] `[GameStateManager] → PreOpen` appears in console on play
- [ ] HUD timer counts down from 5:00 during PreOpen
- [ ] HUD changes to "OPEN" when PreOpen ends
- [ ] NPC spawns and walks to waiting area during Open
- [ ] POS shows order tickets when player interacts
- [ ] Accepting an order shows it in HUD
- [ ] Walking up to Mix station triggers placeholder UI
- [ ] Clicking "Complete" advances pipeline to Dough
- [ ] Dough → Fridge → Oven → Dress all advance correctly
- [ ] Player carries box to NPC → rating flash appears
- [ ] EndOfDay summary appears at end of Open phase
- [ ] Summary auto-dismisses and PreOpen starts again

---

## What M1 Does NOT Include (build in later milestones)

- Real minigame mechanics (M2)
- All 6 cookie types (M3)
- VIP orders (M3)
- Save/Load DataStore (M4)
- Real rating formula (M4)
- Tutorial (M5)
- Events, leaderboards, AntiExploit (M6)
- Visual polish (M7)
