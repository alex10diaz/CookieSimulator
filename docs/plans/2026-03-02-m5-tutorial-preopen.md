# M5 Tutorial + Pre-Open Flow Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Add a 3-step guided tutorial overlay for first-time players, and wire EndOfDay with real session stats instead of hardcoded zeros.

**Architecture:** TutorialController (server Script) tracks tutorial progression per-player and pushes step data via a new `TutorialStep` remote; TutorialUI (client LocalScript) renders the step panel and Skip button; SessionStats (server ModuleScript) accumulates per-cycle delivery data so GameStateManager can fire real EndOfDay numbers. Tutorial state persists via the existing `tutorialCompleted` flag in PlayerDataManager.

**Tech Stack:** Roblox Luau, existing RemoteManager, PlayerDataManager (DataStore), OrderManager

---

## Context (read before coding)

### Existing files — do NOT recreate these
- `src/ReplicatedStorage/Modules/RemoteManager.lua` — add `"TutorialStep"` to `REMOTES` list (line 66, just before the closing brace)
- `src/ServerScriptService/Core/PlayerDataManager.lua` — has `SetTutorialCompleted(player)` and `GetData(player)` already
- `src/ServerScriptService/Core/GameStateManager.server.lua` — has `runCycle(isFirstDay)`, `broadcast()`, `summaryRemote:FireAllClients()` at line 56 with hardcoded zeros
- `src/ServerScriptService/Core/PersistentNPCSpawner.server.lua` — calls `PlayerDataManager.AddCoins/AddXP` and computes `stars`, `payout.coins`, `comboStreak` per delivery (lines ~387–428)
- `TutorialComplete` remote already registered in RemoteManager (line 65) — fires client → server when player skips

### Remote flow for tutorial
```
Server → Client : TutorialStep   (fires step data: {step, msg, total})
Client → Server : TutorialComplete  (fires when Skip pressed — already registered)
```

### Tutorial step progression (server-driven)
| Step | Trigger event (OnServerEvent) | Next instruction |
|------|-------------------------------|-----------------|
| 1 | Player joins with tutorialCompleted=false | "Go to a Mixer and press E to start mixing!" |
| 2 | `MixMinigameResult` fires from that player | "Go to the Dough Table and press E to shape the dough!" |
| 3 | `DoughMinigameResult` fires from that player | "Stock a Fridge with dough — then wait for the store to open!" → auto-complete after 4s |

### Require paths
- `require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))`
- `require(ServerScriptService:WaitForChild("Core"):WaitForChild("PlayerDataManager"))`
- `require(ServerScriptService:WaitForChild("Core"):WaitForChild("SessionStats"))`

### Studio sync rule
Rojo is STOPPED. All Studio changes go through MCP `run_code`. File system changes go through Write/Edit tools. Both must be done for every task.

---

## Task 1: Register `TutorialStep` remote

**Files:**
- Modify: `src/ReplicatedStorage/Modules/RemoteManager.lua` — add `"TutorialStep"` to REMOTES

### Step 1: Edit RemoteManager.lua

Find the line `"TutorialComplete",` (currently the last entry in REMOTES). Add `"TutorialStep"` after it:

```lua
    "TutorialComplete",
    "TutorialStep",
```

### Step 2: Sync to Studio via MCP

```lua
-- run_code in Studio:
local RS = game:GetService("ReplicatedStorage")
local GE = RS:FindFirstChild("GameEvents")
if GE and not GE:FindFirstChild("TutorialStep") then
    local r = Instance.new("RemoteEvent")
    r.Name   = "TutorialStep"
    r.Parent = GE
    print("[M5] TutorialStep RemoteEvent created")
else
    print("[M5] TutorialStep already exists or GameEvents missing")
end
```

### Step 3: Verify

Play in Studio → check Output has no RemoteManager errors → check `ReplicatedStorage/GameEvents` folder contains `TutorialStep`.

### Step 4: Commit

```bash
git add src/ReplicatedStorage/Modules/RemoteManager.lua
git commit -m "feat(m5): register TutorialStep remote"
```

---

## Task 2: TutorialController (server)

**Files:**
- Create: `src/ServerScriptService/Core/TutorialController.server.lua`
- MCP: Create Script in `ServerScriptService.Core`

### Step 1: Write the server script

Create `src/ServerScriptService/Core/TutorialController.server.lua`:

```lua
-- src/ServerScriptService/Core/TutorialController.server.lua
-- Drives the 3-step first-time-player tutorial.
-- Fires TutorialStep to the client; listens for TutorialComplete (skip).
-- Progression: join → step 1 → MixMinigameResult → step 2 → DoughMinigameResult → step 3 (auto-complete after 4s)

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RemoteManager     = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local PlayerDataManager = require(ServerScriptService:WaitForChild("Core"):WaitForChild("PlayerDataManager"))

local tutorialStepRemote = RemoteManager.Get("TutorialStep")
local tutorialDoneRemote = RemoteManager.Get("TutorialComplete")
local mixResultRemote    = RemoteManager.Get("MixMinigameResult")
local doughResultRemote  = RemoteManager.Get("DoughMinigameResult")

-- ─── State ───────────────────────────────────────────────────────────────────
-- Maps userId → current tutorial step (1, 2, or 3). Nil = not in tutorial.
local activeTutorials = {}

local STEPS = {
    [1] = "Go to a Mixer and press E to start mixing!",
    [2] = "Great mix! Go to the Dough Table and press E to shape the dough.",
    [3] = "Perfect! Stock a Fridge with dough — then wait for the store to open!",
}
local TOTAL_STEPS = 3

local function sendStep(player, step)
    tutorialStepRemote:FireClient(player, {
        step  = step,
        total = TOTAL_STEPS,
        msg   = STEPS[step] or "",
    })
    print(string.format("[TutorialController] %s → step %d/%d", player.Name, step, TOTAL_STEPS))
end

local function completeTutorial(player)
    local userId = player.UserId
    if not activeTutorials[userId] then return end
    activeTutorials[userId] = nil
    PlayerDataManager.SetTutorialCompleted(player)
    -- Signal client to dismiss overlay
    tutorialStepRemote:FireClient(player, { step = 0, total = TOTAL_STEPS, msg = "" })
    print("[TutorialController] " .. player.Name .. " tutorial complete.")
end

-- ─── Player join ─────────────────────────────────────────────────────────────
Players.PlayerAdded:Connect(function(player)
    -- Wait for PlayerDataManager to finish loading profile
    task.wait(3)
    local data = PlayerDataManager.GetData(player)
    if not data then return end
    if data.tutorialCompleted then
        print("[TutorialController] " .. player.Name .. " already completed tutorial, skipping.")
        return
    end
    activeTutorials[player.UserId] = 1
    sendStep(player, 1)
end)

Players.PlayerRemoving:Connect(function(player)
    activeTutorials[player.UserId] = nil
end)

-- Handle players already in-game when this script loads
for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(function()
        task.wait(3)
        local data = PlayerDataManager.GetData(player)
        if data and not data.tutorialCompleted and not activeTutorials[player.UserId] then
            activeTutorials[player.UserId] = 1
            sendStep(player, 1)
        end
    end)
end

-- ─── Step progression ────────────────────────────────────────────────────────
mixResultRemote.OnServerEvent:Connect(function(player, ...)
    local userId = player.UserId
    if activeTutorials[userId] == 1 then
        activeTutorials[userId] = 2
        sendStep(player, 2)
    end
end)

doughResultRemote.OnServerEvent:Connect(function(player, ...)
    local userId = player.UserId
    if activeTutorials[userId] == 2 then
        activeTutorials[userId] = 3
        sendStep(player, 3)
        -- Auto-complete after 4 seconds (step 3 is informational, no gate)
        task.delay(4, function()
            if activeTutorials[userId] == 3 then
                completeTutorial(player)
            end
        end)
    end
end)

-- ─── Skip button ─────────────────────────────────────────────────────────────
tutorialDoneRemote.OnServerEvent:Connect(function(player)
    completeTutorial(player)
end)

print("[TutorialController] Ready.")
```

### Step 2: Create in Studio via MCP

```lua
-- run_code in Studio:
local SSS = game:GetService("ServerScriptService")
local core = SSS:FindFirstChild("Core")
if not core then error("Core folder not found") end

local existing = core:FindFirstChild("TutorialController")
if existing then existing:Destroy() end

local s = Instance.new("Script")
s.Name   = "TutorialController"
s.Source = [[ PASTE_FULL_SOURCE_HERE ]]
s.Parent = core
print("[M5] TutorialController created in Studio")
```

(Use the full source from Step 1 as the Source string.)

### Step 3: Verify

Play in Studio with a fresh character:
- Expected Output: `[TutorialController] <name> → step 1/3`
- If profile already has `tutorialCompleted=true` locally (DataStore), temporarily set `TEST_FORCE_TUTORIAL = true` guard by modifying the GetData check for testing:
  - Change `if data.tutorialCompleted then` → `if false and data.tutorialCompleted then` temporarily
- After `MixMinigameResult` fires (complete a mix): `[TutorialController] <name> → step 2/3`
- After `DoughMinigameResult` fires: `[TutorialController] <name> → step 3/3`, then after 4s: `tutorial complete`

### Step 4: Commit

```bash
git add src/ServerScriptService/Core/TutorialController.server.lua
git commit -m "feat(m5): add TutorialController - server-driven 3-step tutorial"
```

---

## Task 3: TutorialUI (client)

**Files:**
- Create: `src/StarterPlayer/StarterPlayerScripts/TutorialUI.client.lua`
- MCP: Create LocalScript in `StarterPlayer.StarterPlayerScripts`

### Step 1: Write the client script

Create `src/StarterPlayer/StarterPlayerScripts/TutorialUI.client.lua`:

```lua
-- src/StarterPlayer/StarterPlayerScripts/TutorialUI.client.lua
-- Shows the tutorial step overlay sent by TutorialController (server).
-- Fires TutorialComplete when player presses Skip.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local RemoteManager      = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local tutorialStepRemote = RemoteManager.Get("TutorialStep")
local tutorialDoneRemote = RemoteManager.Get("TutorialComplete")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ─── Build UI ─────────────────────────────────────────────────────────────────
local sg = Instance.new("ScreenGui")
sg.Name         = "TutorialGui"
sg.ResetOnSpawn = false
sg.Enabled      = false
sg.ZIndex       = 10
sg.Parent       = playerGui

local panel = Instance.new("Frame")
panel.Name             = "TutorialPanel"
panel.Size             = UDim2.new(0, 420, 0, 110)
panel.Position         = UDim2.new(0, 14, 1, -130)
panel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
panel.BackgroundTransparency = 0.1
panel.BorderSizePixel  = 0
panel.Parent           = sg
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)

-- Step indicator (top-left)
local stepLbl = Instance.new("TextLabel")
stepLbl.Name                  = "StepLabel"
stepLbl.Size                  = UDim2.new(0.45, 0, 0, 24)
stepLbl.Position              = UDim2.new(0, 12, 0, 10)
stepLbl.BackgroundTransparency = 1
stepLbl.TextColor3            = Color3.fromRGB(255, 200, 60)
stepLbl.TextScaled            = true
stepLbl.Font                  = Enum.Font.GothamBold
stepLbl.TextXAlignment        = Enum.TextXAlignment.Left
stepLbl.Text                  = "Step 1 / 3"
stepLbl.Parent                = panel

-- Skip button (top-right)
local skipBtn = Instance.new("TextButton")
skipBtn.Name                  = "SkipButton"
skipBtn.Size                  = UDim2.new(0, 80, 0, 28)
skipBtn.Position              = UDim2.new(1, -92, 0, 8)
skipBtn.BackgroundColor3      = Color3.fromRGB(80, 80, 100)
skipBtn.TextColor3            = Color3.fromRGB(200, 200, 200)
skipBtn.TextScaled            = true
skipBtn.Font                  = Enum.Font.Gotham
skipBtn.Text                  = "Skip"
skipBtn.BorderSizePixel       = 0
skipBtn.Parent                = panel
Instance.new("UICorner", skipBtn).CornerRadius = UDim.new(0, 8)

-- Instruction text
local msgLbl = Instance.new("TextLabel")
msgLbl.Name                   = "MessageLabel"
msgLbl.Size                   = UDim2.new(1, -24, 0, 54)
msgLbl.Position               = UDim2.new(0, 12, 0, 44)
msgLbl.BackgroundTransparency = 1
msgLbl.TextColor3             = Color3.fromRGB(240, 240, 240)
msgLbl.TextWrapped            = true
msgLbl.TextScaled             = false
msgLbl.TextSize               = 18
msgLbl.Font                   = Enum.Font.Gotham
msgLbl.TextXAlignment         = Enum.TextXAlignment.Left
msgLbl.Text                   = ""
msgLbl.Parent                 = panel

-- ─── Logic ────────────────────────────────────────────────────────────────────
local function showStep(data)
    if data.step == 0 then
        -- Dismiss overlay
        sg.Enabled = false
        return
    end
    stepLbl.Text = "Step " .. data.step .. " / " .. data.total
    msgLbl.Text  = data.msg or ""
    sg.Enabled   = true
end

tutorialStepRemote.OnClientEvent:Connect(showStep)

skipBtn.MouseButton1Click:Connect(function()
    sg.Enabled = false
    tutorialDoneRemote:FireServer()
end)

print("[TutorialUI] Ready.")
```

### Step 2: Create in Studio via MCP

```lua
-- run_code in Studio:
local SP = game:GetService("StarterPlayer")
local SPS = SP:FindFirstChild("StarterPlayerScripts")
if not SPS then error("StarterPlayerScripts not found") end

local existing = SPS:FindFirstChild("TutorialUI")
if existing then existing:Destroy() end

local s = Instance.new("LocalScript")
s.Name   = "TutorialUI"
s.Source = [[ PASTE_FULL_SOURCE_HERE ]]
s.Parent = SPS
print("[M5] TutorialUI LocalScript created in Studio")
```

### Step 3: Verify

Play in Studio (with tutorial forced active if needed):
- Expected: tutorial panel appears at bottom-left with "Step 1 / 3" and mix instruction
- Complete a mix minigame → panel updates to step 2
- Complete dough minigame → panel updates to step 3
- After 4s → panel disappears
- Test Skip: panel closes immediately when pressed
- Check Output: `[TutorialUI] Ready.`

### Step 4: Commit

```bash
git add src/StarterPlayer/StarterPlayerScripts/TutorialUI.client.lua
git commit -m "feat(m5): add TutorialUI - step overlay with skip button"
```

---

## Task 4: SessionStats + real EndOfDay summary

**Files:**
- Create: `src/ServerScriptService/Core/SessionStats.lua` (ModuleScript)
- Modify: `src/ServerScriptService/Core/PersistentNPCSpawner.server.lua` — require SessionStats, call RecordDelivery
- Modify: `src/ServerScriptService/Core/GameStateManager.server.lua` — require SessionStats, use GetSummary + Reset
- MCP: create ModuleScript, update both Scripts in Studio

### Step 1: Write SessionStats module

Create `src/ServerScriptService/Core/SessionStats.lua`:

```lua
-- ServerScriptService/Core/SessionStats (ModuleScript)
-- Tracks aggregate per-cycle delivery stats for EndOfDay summary.
-- Call RecordDelivery after each delivery, GetSummary for EndOfDay, Reset at new cycle start.

local SessionStats = {}

local data = {
    orders     = 0,
    coins      = 0,
    totalStars = 0,
    peakCombo  = 0,
}

function SessionStats.RecordDelivery(stars, coins, comboStreak)
    data.orders     += 1
    data.coins      += (coins or 0)
    data.totalStars += (stars or 0)
    if (comboStreak or 0) > data.peakCombo then
        data.peakCombo = comboStreak
    end
end

function SessionStats.GetSummary()
    local avgStars = data.orders > 0
        and math.floor((data.totalStars / data.orders) * 10 + 0.5) / 10
        or  0
    return {
        orders   = data.orders,
        coins    = data.coins,
        combo    = data.peakCombo,
        avgStars = avgStars,
    }
end

function SessionStats.Reset()
    data.orders     = 0
    data.coins      = 0
    data.totalStars = 0
    data.peakCombo  = 0
end

return SessionStats
```

### Step 2: Modify PersistentNPCSpawner to call RecordDelivery

Read current file first to find the exact lines. The require block is at the top (lines 16–17 added in M4). Add SessionStats require there.

At the top of the file, add:
```lua
local SessionStats      = require(ServerScriptService:WaitForChild("Core"):WaitForChild("SessionStats"))
```

In the delivery handler (after `deliveryResult:FireClient(player, stars, payout.coins, payout.xp)`, around line 419), add:
```lua
SessionStats.RecordDelivery(stars, payout.coins, comboStreak)
```

### Step 3: Modify GameStateManager to use real summary

In `src/ServerScriptService/Core/GameStateManager.server.lua`:

**Top of file** — add requires (after the RemoteManager require):
```lua
local ServerScriptService = game:GetService("ServerScriptService")
local SessionStats = require(ServerScriptService:WaitForChild("Core"):WaitForChild("SessionStats"))
```

**In `runCycle` function** — replace:
```lua
local function runCycle(isFirstDay)
    runPhase(isFirstDay and PREOPEN_FIRST or PREOPEN_REPEAT, "PreOpen")
```
with:
```lua
local function runCycle(isFirstDay)
    SessionStats.Reset()
    runPhase(isFirstDay and PREOPEN_FIRST or PREOPEN_REPEAT, "PreOpen")
```

**In `runCycle`** — replace the hardcoded summary:
```lua
    summaryRemote:FireAllClients({
        orders   = 0,
        coins    = 0,
        combo    = 0,
        avgStars = 3,
    })
```
with:
```lua
    summaryRemote:FireAllClients(SessionStats.GetSummary())
```

### Step 4: Create SessionStats ModuleScript in Studio via MCP

```lua
-- run_code in Studio:
local SSS = game:GetService("ServerScriptService")
local core = SSS:FindFirstChild("Core")

local existing = core:FindFirstChild("SessionStats")
if existing then existing:Destroy() end

local m = Instance.new("ModuleScript")
m.Name   = "SessionStats"
m.Source = [[ PASTE_FULL_SOURCE_HERE ]]
m.Parent = core
print("[M5] SessionStats ModuleScript created")
```

### Step 5: Update PersistentNPCSpawner and GameStateManager in Studio via MCP

For PersistentNPCSpawner: use targeted string patching (find the require block + delivery line, splice in the new code).

For GameStateManager: read the current Source, use string.find to locate `runCycle` and the `summaryRemote:FireAllClients` call, splice in the new code.

Verify after each MCP run_code that the print confirms success.

### Step 6: Verify

Play in Studio:
- Complete several deliveries
- Wait for EndOfDay (or temporarily shorten `OPEN_DURATION` to 10 seconds for testing by editing GameStateManager)
- Expected: SummaryGui shows real order count, real coin total, real avg stars
- Output: `[GameStateManager] → EndOfDay (30s)`
- SummaryGui body text should reflect actual deliveries made

### Step 7: Commit

```bash
git add src/ServerScriptService/Core/SessionStats.lua
git add src/ServerScriptService/Core/PersistentNPCSpawner.server.lua
git add src/ServerScriptService/Core/GameStateManager.server.lua
git commit -m "feat(m5): SessionStats module + real EndOfDay summary data"
```

---

## Testing the Full M5 Flow

1. Play in Studio with a fresh/test profile (or force `tutorialCompleted = false`)
2. Tutorial panel appears at bottom-left: "Step 1/3 — Go to a Mixer..."
3. Complete a mix → panel advances to step 2
4. Complete dough → panel advances to step 3 → auto-dismisses after 4s
5. `tutorialCompleted` is now true in DataStore (verify: leave and rejoin → no tutorial shown)
6. Deliver some cookies (using TestNPCSpawner)
7. Wait for EndOfDay (shorten OPEN_DURATION to ~30s for test)
8. SummaryGui shows real delivery count, coins, stars — not hardcoded zeros

## Files Changed Summary

| File | Change |
|------|--------|
| `src/ReplicatedStorage/Modules/RemoteManager.lua` | +`"TutorialStep"` remote |
| `src/ServerScriptService/Core/TutorialController.server.lua` | NEW — server tutorial state machine |
| `src/StarterPlayer/StarterPlayerScripts/TutorialUI.client.lua` | NEW — step panel overlay |
| `src/ServerScriptService/Core/SessionStats.lua` | NEW — per-cycle stat accumulator |
| `src/ServerScriptService/Core/PersistentNPCSpawner.server.lua` | +SessionStats.RecordDelivery call |
| `src/ServerScriptService/Core/GameStateManager.server.lua` | +SessionStats.Reset/GetSummary wired |
