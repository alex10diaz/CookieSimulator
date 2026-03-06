# Solo AI Mode Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Let players hire up to 5 AI worker NPCs during PreOpen to staff bakery stations, each running at 75% quality and costing 50 coins/shift.

**Architecture:** Single new server script (`StaffManager.server.lua`) manages all workers. Workers bypass MinigameServer and call OrderManager directly with a worker proxy table (has `.Name` field). Workers poll for available work in coroutines and simulate work time before recording scores. No new RemoteEvents needed.

**Tech Stack:** Roblox Luau, OrderManager API, PlayerDataManager, GameStateChanged RemoteEvent (existing), HumanoidDescription for baker uniform.

**Design doc:** `docs/plans/2026-03-07-solo-ai-mode-design.md`

---

## Pre-task: Read these files first

Before touching any code, read:
- `src/ReplicatedStorage/Modules/OrderManager.lua` — understand what `TryStartBatch`, `RecordStationScore`, `RecordOvenScore`, `RecordFrostScore`, `CreateBox`, `TakeFromWarmers`, `GetBatchAtStage`, `PullFromFridge` actually access on the `player` param (UserId? methods? just .Name?)
- `src/ServerScriptService/Core/PlayerDataManager.lua` — confirm `AddCoins(player, amount)` signature (amount can be negative for deductions)
- `src/ServerScriptService/Core/GameStateManager.server.lua` — confirm how `GameStateChanged` fires so we can listen for `"PreOpen"` and `"EndOfDay"`

---

## Task 1: Worker proxy + baker uniform helper

**Files:**
- Create: `src/ServerScriptService/Core/StaffManager.server.lua`

**Step 1: Create the file skeleton**

```lua
-- src/ServerScriptService/Core/StaffManager.server.lua
-- Manages AI worker NPCs that players can hire during PreOpen.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RemoteManager     = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local OrderManager      = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("OrderManager"))
local PlayerDataManager = require(ServerScriptService:WaitForChild("Core"):WaitForChild("PlayerDataManager"))

local GameStateChanged  = RemoteManager.Get("GameStateChanged")

-- ── CONFIG ────────────────────────────────────────────────────────────────────
local HIRE_COST        = 50
local WORKER_QUALITY   = 75
local MAX_WORKERS      = 5
local SHIRT_ID         = "rbxassetid://76531325740097"
local PANTS_ID         = "rbxassetid://98693082132232"

-- ── STATE ─────────────────────────────────────────────────────────────────────
-- workers[stationId] = { rig, workerProxy, active, thread }
local workers = {}
local hirePrompts = {}  -- stationId -> ProximityPrompt

print("[StaffManager] Loaded")
```

**Step 2: Add worker proxy builder**

A "worker proxy" is a plain table with a `.Name` field. OrderManager may use the player object for session tracking or carrier name. After reading OrderManager (pre-task), confirm whether only `.Name` is needed. If OrderManager calls methods on player (e.g., `:FindFirstChild()`), create a minimal stub instead.

```lua
-- Worker proxy — satisfies OrderManager's player.Name reads
local function makeProxy(workerName)
    return { Name = workerName }
end
```

**Step 3: Add baker uniform function**

```lua
local function applyBakerUniform(rig)
    local hum = rig:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local desc = Instance.new("HumanoidDescription")
    -- Extract numeric IDs from asset strings
    desc.Shirt = tonumber(SHIRT_ID:match("%d+")) or 0
    desc.Pants = tonumber(PANTS_ID:match("%d+")) or 0
    hum:ApplyDescription(desc)
end
```

**Step 4: Add worker rig spawner**

The rig is a minimal R15 model (reuse the TestNPCSpawner approach — two parts: HumanoidRootPart + Head). Position it at the given CFrame, slightly in front of the station.

```lua
local function spawnWorkerRig(workerName, spawnCF)
    local rig = Instance.new("Model")
    rig.Name = workerName

    local hrp = Instance.new("Part")
    hrp.Name       = "HumanoidRootPart"
    hrp.Size       = Vector3.new(2, 2, 1)
    hrp.Anchored   = true
    hrp.BrickColor = BrickColor.new("Pastel brown")
    hrp.CFrame     = spawnCF
    hrp.Parent     = rig

    local head = Instance.new("Part")
    head.Name      = "Head"
    head.Size      = Vector3.new(2, 1, 1)
    head.Anchored  = true
    head.BrickColor = BrickColor.new("Pastel yellow")
    head.CFrame    = spawnCF * CFrame.new(0, 1.5, 0)
    head.Parent    = rig

    local hum = Instance.new("Humanoid")
    hum.Parent = rig
    rig.PrimaryPart = hrp

    -- Name tag
    local bb = Instance.new("BillboardGui")
    bb.Size        = UDim2.new(0, 140, 0, 36)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = true
    bb.Parent      = hrp

    local lbl = Instance.new("TextLabel")
    lbl.Size                  = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3            = Color3.fromRGB(255, 255, 255)
    lbl.TextScaled            = true
    lbl.Font                  = Enum.Font.GothamBold
    lbl.Text                  = workerName
    lbl.Parent                = bb

    -- Status billboard (smaller, below name)
    local sb = Instance.new("BillboardGui")
    sb.Name        = "StatusBillboard"
    sb.Size        = UDim2.new(0, 120, 0, 24)
    sb.StudsOffset = Vector3.new(0, 2.2, 0)
    sb.AlwaysOnTop = true
    sb.Parent      = hrp

    local slbl = Instance.new("TextLabel")
    slbl.Name                  = "StatusLabel"
    slbl.Size                  = UDim2.new(1, 0, 1, 0)
    slbl.BackgroundTransparency = 1
    slbl.TextColor3            = Color3.fromRGB(180, 180, 180)
    slbl.TextScaled            = true
    slbl.Font                  = Enum.Font.Gotham
    slbl.Text                  = "Idle"
    slbl.Parent                = sb

    rig.Parent = workspace
    applyBakerUniform(rig)
    return rig
end

local function setStatus(rig, text, color)
    local sb = rig.PrimaryPart and rig.PrimaryPart:FindFirstChild("StatusBillboard")
    if not sb then return end
    local lbl = sb:FindFirstChild("StatusLabel")
    if lbl then
        lbl.Text = text
        lbl.TextColor3 = color or Color3.fromRGB(180, 180, 180)
    end
end
```

**Step 5: Verify in Studio**

Add a temporary test call at the bottom of the file:
```lua
task.delay(3, function()
    spawnWorkerRig("Baker #1", CFrame.new(18, 5, -20))
end)
```
Run in Studio. Confirm rig appears with name tag and status billboard. Remove test call after verifying.

**Step 6: Commit**
```bash
git add src/ServerScriptService/Core/StaffManager.server.lua
git commit -m "feat: StaffManager skeleton + worker rig spawner"
```

---

## Task 2: Station definitions + worker coroutines

**Files:**
- Modify: `src/ServerScriptService/Core/StaffManager.server.lua`

**Step 1: Define station table**

Add this after the STATE block. Positions come from in-Studio measurements (adjust CFrame.new values if workers clip into geometry):

```lua
-- ── STATION DEFINITIONS ───────────────────────────────────────────────────────
-- spawnOffset: where the worker rig stands (in front of the station)
local STATIONS = {
    mix   = {
        label       = "Mixing",
        spawnCF     = CFrame.new(18, 5, -17),   -- in front of Mixer 1
        duration    = 8,
        work = function(proxy)
            -- Find a cookie to mix based on active NPC orders
            local orders = OrderManager.GetNPCOrders and OrderManager.GetNPCOrders() or {}
            local cookieId = "chocolate_chip"  -- fallback
            for _, o in ipairs(orders) do
                if o.cookieId then cookieId = o.cookieId; break end
            end
            local batchId = OrderManager.TryStartBatch(proxy, cookieId)
            if not batchId then return false end
            task.wait(8)
            OrderManager.RecordStationScore(proxy, "mix", WORKER_QUALITY, batchId)
            return true
        end,
    },
    dough = {
        label       = "Shaping",
        spawnCF     = CFrame.new(-0, 5, -34),   -- in front of DoughPrompt
        duration    = 6,
        work = function(proxy)
            local batch = OrderManager.GetBatchAtStage("dough")
            if not batch then return false end
            task.wait(6)
            OrderManager.RecordStationScore(proxy, "dough", WORKER_QUALITY, batch.batchId)
            return true
        end,
    },
    oven  = {
        label       = "Baking",
        spawnCF     = CFrame.new(-2, 8, -85),   -- in front of Oven1
        duration    = 12,
        work = function(proxy)
            -- Try each fridge to pull a batch
            local fridges = workspace:FindFirstChild("Fridges")
            if not fridges then return false end
            local batchId
            for _, fridge in ipairs(fridges:GetChildren()) do
                local fridgeId = fridge:GetAttribute("FridgeId")
                if fridgeId then
                    batchId = OrderManager.PullFromFridge(proxy, fridgeId)
                    if batchId then break end
                end
            end
            if not batchId then return false end
            task.wait(12)
            OrderManager.RecordOvenScore(proxy, WORKER_QUALITY, batchId)
            return true
        end,
    },
    frost = {
        label       = "Frosting",
        spawnCF     = CFrame.new(20, 6, -36),   -- near FrostPrompt
        duration    = 8,
        work = function(proxy)
            local entry = OrderManager.TakeFromWarmers(true)
            if not entry then return false end
            task.wait(8)
            OrderManager.RecordFrostScore(
                proxy.Name, entry.batchId, WORKER_QUALITY,
                entry.snapshot or 0, entry.cookieId
            )
            return true
        end,
    },
    dress = {
        label       = "Packing",
        spawnCF     = CFrame.new(-27, 5, -32),  -- near Dress Table
        duration    = 6,
        work = function(proxy)
            local entry = OrderManager.TakeFromWarmers(false)
            if not entry then return false end
            task.wait(6)
            OrderManager.CreateBox(proxy, entry.batchId, WORKER_QUALITY, entry)
            return true
        end,
    },
}
```

**Step 2: Add worker coroutine runner**

```lua
local POLL_INTERVAL = 2  -- seconds between polling when idle

local function runWorkerLoop(stationId, rig, proxy)
    local stationDef = STATIONS[stationId]
    while workers[stationId] and workers[stationId].active do
        setStatus(rig, "Idle", Color3.fromRGB(160, 160, 160))
        local ok = pcall(function()
            local didWork = stationDef.work(proxy)
            if didWork then
                setStatus(rig, stationDef.label .. "...", Color3.fromRGB(255, 200, 50))
                -- work() already waited internally; update status to Done briefly
                setStatus(rig, "Done ✓", Color3.fromRGB(80, 200, 80))
                task.wait(1)
            else
                task.wait(POLL_INTERVAL)
            end
        end)
        if not ok then
            task.wait(POLL_INTERVAL)
        end
    end
    setStatus(rig, "Off duty", Color3.fromRGB(120, 120, 120))
end
```

> **Note:** The `work()` functions above call `task.wait()` internally. That means the coroutine suspends during `work()` and the status won't update mid-work. Refactor: set status to `"label..."` *before* the wait, then `"Done ✓"` after. Update the `runWorkerLoop` to pass status-update callbacks if needed — or restructure `work()` to not wait internally and instead let the loop wait.

**Revised cleaner loop (preferred):**

```lua
local function runWorkerLoop(stationId, rig, proxy)
    local stationDef = STATIONS[stationId]
    while workers[stationId] and workers[stationId].active do
        local didWork = false
        local success = pcall(function()
            -- Check for available work (no wait inside check)
            -- Each station's work() is split: checkWork() returns job or nil, then we wait, then record()
            -- For simplicity in v1: call work() which handles everything internally
            didWork = stationDef.work(proxy)
        end)
        if success and didWork then
            setStatus(rig, "Done ✓", Color3.fromRGB(80, 200, 80))
            task.wait(1)
        else
            setStatus(rig, "Idle", Color3.fromRGB(160, 160, 160))
            task.wait(POLL_INTERVAL)
        end
    end
end
```

The status while actively working (during the internal `task.wait`) won't update — this is acceptable for v1. A full status update during work requires splitting check/execute phases; defer to polish.

**Step 3: Commit**
```bash
git add src/ServerScriptService/Core/StaffManager.server.lua
git commit -m "feat: worker station definitions and coroutine loop"
```

---

## Task 3: Hire + dismiss logic

**Files:**
- Modify: `src/ServerScriptService/Core/StaffManager.server.lua`

**Step 1: Add hire function**

```lua
local workerCount = 0

local function hireWorker(player, stationId)
    -- Guard: station already staffed?
    if workers[stationId] and workers[stationId].active then
        warn("[StaffManager]", stationId, "already staffed")
        return false
    end
    -- Guard: max workers
    if workerCount >= MAX_WORKERS then
        warn("[StaffManager] Max workers reached")
        return false
    end
    -- Guard: coins check
    local profile = PlayerDataManager.GetData(player)
    if not profile or (profile.coins or 0) < HIRE_COST then
        warn("[StaffManager]", player.Name, "can't afford worker")
        return false
    end

    PlayerDataManager.AddCoins(player, -HIRE_COST)
    workerCount += 1

    local workerName = "Baker #" .. workerCount
    local stationDef = STATIONS[stationId]
    local proxy = makeProxy(workerName)
    local rig = spawnWorkerRig(workerName, stationDef.spawnCF)

    workers[stationId] = { rig = rig, proxy = proxy, active = true }

    -- Start coroutine
    task.spawn(runWorkerLoop, stationId, rig, proxy)

    -- Flip prompt text to "Dismiss"
    local prompt = hirePrompts[stationId]
    if prompt then
        prompt.ActionText = "Dismiss " .. workerName
        prompt.ObjectText = "AI Worker"
    end

    print(string.format("[StaffManager] %s hired %s at %s (-%d coins)", player.Name, workerName, stationId, HIRE_COST))
    return true
end
```

**Step 2: Add dismiss function**

```lua
local function dismissWorker(stationId)
    local entry = workers[stationId]
    if not entry then return end
    entry.active = false
    if entry.rig and entry.rig.Parent then
        entry.rig:Destroy()
    end
    workers[stationId] = nil
    workerCount = math.max(0, workerCount - 1)

    -- Reset prompt
    local prompt = hirePrompts[stationId]
    local stationDef = STATIONS[stationId]
    if prompt and stationDef then
        prompt.ActionText = "Hire Baker (50🪙)"
        prompt.ObjectText  = stationDef.label .. " Station"
    end
end
```

**Step 3: Add dismissAllWorkers (for EndOfDay)**

```lua
local function dismissAllWorkers()
    for stationId in pairs(STATIONS) do
        dismissWorker(stationId)
    end
    workerCount = 0
    print("[StaffManager] All workers dismissed (EndOfDay)")
end
```

**Step 4: Commit**
```bash
git add src/ServerScriptService/Core/StaffManager.server.lua
git commit -m "feat: worker hire/dismiss logic with coin deduction"
```

---

## Task 4: Hire ProximityPrompts + GameState wiring

**Files:**
- Modify: `src/ServerScriptService/Core/StaffManager.server.lua`

**Step 1: Add prompt spawner**

Prompts appear near each station. They're attached to invisible anchor parts created at runtime (so they show up as floating prompts near the station). Alternatively attach to an existing part near each station — confirm in Studio what makes sense positionally.

```lua
local function spawnHirePrompts()
    for stationId, stationDef in pairs(STATIONS) do
        -- Create an invisible anchor part at station position
        local anchor = Instance.new("Part")
        anchor.Name      = "HireAnchor_" .. stationId
        anchor.Anchored  = true
        anchor.CanCollide = false
        anchor.Transparency = 1
        anchor.Size      = Vector3.new(1, 1, 1)
        anchor.CFrame    = stationDef.spawnCF * CFrame.new(0, -1, 0)  -- near floor
        anchor.Parent    = workspace

        local prompt = Instance.new("ProximityPrompt")
        prompt.ActionText            = "Hire Baker (50🪙)"
        prompt.ObjectText            = stationDef.label .. " Station"
        prompt.KeyboardKeyCode       = Enum.KeyCode.H
        prompt.MaxActivationDistance = 8
        prompt.RequiresLineOfSight   = false
        prompt.Parent                = anchor

        hirePrompts[stationId] = prompt

        prompt.Triggered:Connect(function(player)
            local entry = workers[stationId]
            if entry and entry.active then
                -- Dismiss
                dismissWorker(stationId)
            else
                hireWorker(player, stationId)
            end
        end)
    end
    print("[StaffManager] Hire prompts spawned")
end

local function destroyHirePrompts()
    for stationId, prompt in pairs(hirePrompts) do
        local anchor = prompt.Parent
        if anchor and anchor.Parent then anchor:Destroy() end
    end
    hirePrompts = {}
end
```

**Step 2: Wire to GameStateChanged**

```lua
-- Listen for game state transitions
-- GameStateChanged fires to clients via FireAllClients — on server, use BindableEvent or
-- listen to the existing GameStateManager signal. Check GameStateManager for a BindableEvent
-- or just have StaffManager listen to OnClientEvent... wait, this is server-side.
--
-- ACTION: Check GameStateManager.server.lua — does it expose a BindableEvent for state changes?
-- If not, add one: local StateChanged = Instance.new("BindableEvent") in GameStateManager,
-- store in ServerStorage/Events, and fire it alongside the RemoteEvent.
-- Then StaffManager requires it: ServerStorage.Events.StateChanged.Event:Connect(...)
--
-- Alternative (simpler for now): Poll game state via a module or just use task.delay.
-- Preferred: add BindableEvent to GameStateManager.

-- Assuming GameStateManager exposes ServerStorage.Events.StateChanged BindableEvent:
local ServerStorage = game:GetService("ServerStorage")
local events = ServerStorage:WaitForChild("Events", 10)
if events then
    local stateChanged = events:FindFirstChild("StateChanged")
    if stateChanged then
        stateChanged.Event:Connect(function(newState)
            if newState == "PreOpen" then
                spawnHirePrompts()
            elseif newState == "EndOfDay" then
                destroyHirePrompts()
                dismissAllWorkers()
            elseif newState == "Lobby" then
                -- Clean up between sessions
                destroyHirePrompts()
                dismissAllWorkers()
            end
        end)
    else
        warn("[StaffManager] StateChanged BindableEvent not found in ServerStorage/Events")
    end
end
```

**Step 3: Add BindableEvent to GameStateManager (if it doesn't exist)**

Open `src/ServerScriptService/Core/GameStateManager.server.lua`. Find where `GameStateChanged:FireAllClients(newState)` is called. Add alongside it:

```lua
-- Near top of GameStateManager, after Events folder setup:
local stateChangedBindable = Instance.new("BindableEvent")
stateChangedBindable.Name = "StateChanged"
stateChangedBindable.Parent = ServerStorage:WaitForChild("Events")

-- Wherever GameStateChanged:FireAllClients(state) is called, also fire:
stateChangedBindable:Fire(state)
```

> **Check first:** `ServerStorage/Events` already has BindableEvents (RushHourStart, RushHourEnd, StationUnlocked). Use MCP to check if `StateChanged` BindableEvent already exists. If not, create it via MCP and wire it in GameStateManager.

**Step 4: Verify prompts appear during PreOpen**

In Studio, start Play mode. Trigger PreOpen state (or manually call `spawnHirePrompts()` in command bar). Walk near a station and confirm the "Hire Baker" prompt appears. Press H to hire. Confirm worker rig spawns, coin deducted on server (check output).

**Step 5: Commit**
```bash
git add src/ServerScriptService/Core/StaffManager.server.lua
git add src/ServerScriptService/Core/GameStateManager.server.lua
git commit -m "feat: hire prompts spawn during PreOpen, wire to GameStateChanged"
```

---

## Task 5: End-to-end test + tuning

**Files:**
- Modify: `src/ServerScriptService/Core/StaffManager.server.lua` (tuning only)

**Manual test checklist:**

1. Start Play in Studio with 1 player
2. Trigger PreOpen (or set game state via command bar)
3. Walk to Mix station → hire prompt appears → press H
4. Confirm: 50 coins deducted (check HUD), worker rig spawns at mixer, named "Baker #1"
5. Wait 8–10s → confirm batch appears in BatchUpdated display (client HUD or output)
6. Hire a second worker at Dough station
7. Wait → confirm dough stage processes
8. Trigger EndOfDay → confirm all worker rigs destroyed, prompts removed
9. Rejoin → workers not present (no persistence — expected)
10. Try hiring with <50 coins → confirm blocked with warn in output

**Tune station positions if workers clip:**

Each station's `spawnCF` in the STATIONS table may need adjustment based on actual Studio geometry. Open Studio, use command bar to spawn a test part at each CFrame and verify it's a sensible "standing in front of station" position. Adjust as needed.

**Step: Commit any tuning changes**
```bash
git add src/ServerScriptService/Core/StaffManager.server.lua
git commit -m "fix: tune worker spawn positions and poll timing"
```

---

## Known edge cases to handle at implementation time

1. **Mix station cookieId selection** — If no NPC orders exist, worker defaults to `chocolate_chip`. Confirm `OrderManager.GetNPCOrders()` returns an array (it does per M1 notes — iterate with `ipairs`, `.cookieId` is on each element).

2. **OrderManager player param** — After reading OrderManager source (pre-task), confirm the proxy table `{ Name = "workerName" }` is sufficient. If OrderManager calls `player.UserId` anywhere, add `UserId = 0` to the proxy. If it calls Roblox instance methods (`:IsA()`, `:FindFirstChild()`), you'll need a more complete stub.

3. **Oven worker fridge pull** — `PullFromFridge` may fail if the fridge is empty or the batch isn't ready. The `return false` fallback in the work function handles this (worker goes idle and retries after `POLL_INTERVAL`).

4. **StateChanged BindableEvent** — If `GameStateManager` fires state changes in a way StaffManager can't easily hook, an alternative is to have `GameStateManager` directly `require` StaffManager and call exported functions. Avoid circular requires (StaffManager should not require GameStateManager).

5. **Worker proxy session conflicts** — MinigameServer's `activeSessions` table is keyed by player object. Worker proxies are plain tables, so they won't collide with real player sessions. OrderManager's internal session tracking (if any) uses player as key too — proxy tables are unique references so no collision.
