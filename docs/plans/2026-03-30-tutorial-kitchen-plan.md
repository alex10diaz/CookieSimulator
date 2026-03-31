# Tutorial Kitchen Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Move the tutorial into an isolated workspace area (TutorialKitchen) so new players joining mid-game never touch the live bakery pipeline.

**Architecture:** A new `TutorialKitchen` ModuleScript drives all 5 tutorial steps independently of MinigameServer/OrderManager. `TutorialController` is gutted to a thin router that calls `TutorialKitchen.StartForPlayer()`. `GameStateManager.teleportAllTo()` skips players with `InTutorial=true`.

**Tech Stack:** Roblox Lua, MCP run_code for Studio sync, existing RemoteManager/PlayerDataManager

---

## Pre-Work (User Does This in Studio)

Build the `TutorialKitchen` folder in Workspace with these named children:
- `TutorialMixer` — any Part or Model (ProximityPrompt added by code)
- `TutorialDoughTable` — any Part or Model
- `TutorialFridge` — any Part or Model
- `TutorialOven` — any Part or Model
- `TutorialDressStation` — any Part or Model
- `TutorialCustomer` — any Part or Model (the "customer" to deliver to)
- `TutorialKitchenSpawn` — a BasePart marking where new players spawn

Place it underground or behind the store. Parts can be basic placeholder blocks — functional only.

---

### Task 1: Create TutorialKitchen ModuleScript (disk)

**Files:**
- Create: `src/ServerScriptService/TutorialKitchen.lua`

```lua
-- src/ServerScriptService/TutorialKitchen.lua
-- ModuleScript. Required by TutorialController.
-- Drives the 5-step tutorial in isolation — no MinigameServer/OrderManager dependency.
-- Reuses Start*/Result remotes so existing client minigame UIs work unchanged.

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RemoteManager     = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local PlayerDataManager = require(ServerScriptService:WaitForChild("Core"):WaitForChild("PlayerDataManager"))

local startMixRemote     = RemoteManager.Get("StartMixMinigame")
local mixResultRemote    = RemoteManager.Get("MixMinigameResult")
local startDoughRemote   = RemoteManager.Get("StartDoughMinigame")
local doughResultRemote  = RemoteManager.Get("DoughMinigameResult")
local startOvenRemote    = RemoteManager.Get("StartOvenMinigame")
local ovenResultRemote   = RemoteManager.Get("OvenMinigameResult")
local tutorialStepRemote = RemoteManager.Get("TutorialStep")
local tutorialDoneRemote = RemoteManager.Get("TutorialComplete")
local startGameRemote    = RemoteManager.Get("StartGame")
local replayRemote       = RemoteManager.Get("ReplayTutorial")

local TUTORIAL_COOKIE = "chocolate_chip"
local TUTORIAL_REWARD = 200
local TOTAL_STEPS     = 5
local FINAL_MENU_STEP = TOTAL_STEPS + 1

local STEPS = {
    [1] = { msg = "Go to the Mixer and press E to start mixing!" },
    [2] = { msg = "Shape your dough at the Dough Table!" },
    [3] = { msg = "Pull your dough from the Fridge, then bake it in the Oven!" },
    [4] = { msg = "Pack your cookies at the Dress Station!" },
    [5] = { msg = "Carry the box to the customer and press E to deliver!" },
}

-- sessions[userId] = { step, waitingForMix, waitingForDough, fridgeDone, waitingForOven }
local sessions = {}

-- ─── Kitchen folder ─────────────────────────────────────────────────────────
local kitchenFolder = workspace:WaitForChild("TutorialKitchen", 30)
if not kitchenFolder then
    warn("[TutorialKitchen] 'TutorialKitchen' folder not found in Workspace — tutorial kitchen disabled.")
    return {}
end

-- ─── Helpers ────────────────────────────────────────────────────────────────
local function sendStep(player, step, overrideMsg)
    local payload
    if step == 0 then
        payload = { step = 0, total = TOTAL_STEPS, msg = "", isReturn = false }
    elseif step == FINAL_MENU_STEP then
        payload = { step = FINAL_MENU_STEP, total = TOTAL_STEPS, msg = "", reward = TUTORIAL_REWARD }
    else
        local data = STEPS[step]
        payload = {
            step          = step,
            total         = TOTAL_STEPS,
            msg           = overrideMsg or (data and data.msg) or "",
            forceCookieId = (step == 1) and TUTORIAL_COOKIE or nil,
        }
    end
    tutorialStepRemote:FireClient(player, payload)
end

local function teleportToKitchen(player)
    local char = player.Character
    if not char then
        player.CharacterAdded:Wait()
        char = player.Character
    end
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local sp  = kitchenFolder:FindFirstChild("TutorialKitchenSpawn")
    if hrp and sp and sp:IsA("BasePart") then
        hrp.CFrame = CFrame.new(sp.Position + Vector3.new(0, 3.5, 0))
    end
end

local function teleportToMainBakery(player)
    task.wait(0.5)
    local char = player.Character
    if not char then return end
    local hrp   = char:FindFirstChild("HumanoidRootPart")
    local spawn = workspace:FindFirstChild("GameSpawn")
    if hrp and spawn and spawn:IsA("BasePart") then
        hrp.CFrame = CFrame.new(spawn.Position + Vector3.new(0, 3.5, 0))
    end
end

local function completeTutorial(player, natural)
    sessions[player.UserId] = nil
    player:SetAttribute("InTutorial", false)
    if natural then
        pcall(function() PlayerDataManager.AddCoins(player, TUTORIAL_REWARD) end)
        print("[TutorialKitchen]", player.Name, "tutorial COMPLETE (+$" .. TUTORIAL_REWARD .. ")")
    else
        print("[TutorialKitchen]", player.Name, "tutorial SKIPPED")
    end
    PlayerDataManager.SetTutorialCompleted(player)
    sendStep(player, 0)
    teleportToMainBakery(player)
end

-- ─── Station wiring ──────────────────────────────────────────────────────────
local function wirePrompt(partName, actionText, onTriggered)
    local part = kitchenFolder:FindFirstChild(partName, true)
    if not part then warn("[TutorialKitchen] Part not found:", partName); return end
    -- Use first BasePart if it's a Model
    local base = part:IsA("BasePart") and part or part:FindFirstChildWhichIsA("BasePart")
    if not base then warn("[TutorialKitchen] No BasePart in:", partName); return end
    local prompt = base:FindFirstChildOfClass("ProximityPrompt")
    if not prompt then
        prompt = Instance.new("ProximityPrompt")
        prompt.ActionText      = actionText
        prompt.KeyboardKeyCode = Enum.KeyCode.E
        prompt.Parent          = base
    end
    prompt.Triggered:Connect(onTriggered)
end

wirePrompt("TutorialMixer", "Mix", function(player)
    local s = sessions[player.UserId]
    if not s or s.step ~= 1 or s.waitingForMix then return end
    s.waitingForMix = true
    startMixRemote:FireClient(player, {
        batchId     = "TUT_MIX",
        cookieId    = TUTORIAL_COOKIE,
        stationName = "TutorialMixer",
    })
end)

wirePrompt("TutorialDoughTable", "Shape Dough", function(player)
    local s = sessions[player.UserId]
    if not s or s.step ~= 2 or s.waitingForDough then return end
    s.waitingForDough = true
    startDoughRemote:FireClient(player, {
        batchId  = "TUT_DOUGH",
        cookieId = TUTORIAL_COOKIE,
    })
end)

wirePrompt("TutorialFridge", "Pull Dough", function(player)
    local s = sessions[player.UserId]
    if not s or s.step ~= 3 or s.fridgeDone then return end
    s.fridgeDone = true
    sendStep(player, 3, "Nice! Now bake it in the Oven.")
end)

wirePrompt("TutorialOven", "Bake", function(player)
    local s = sessions[player.UserId]
    if not s or s.step ~= 3 or not s.fridgeDone or s.waitingForOven then return end
    s.waitingForOven = true
    startOvenRemote:FireClient(player, {
        batchId  = "TUT_OVEN",
        cookieId = TUTORIAL_COOKIE,
    })
end)

wirePrompt("TutorialDressStation", "Pack Cookies", function(player)
    local s = sessions[player.UserId]
    if not s or s.step ~= 4 then return end
    s.step = 5
    sendStep(player, 5)
end)

wirePrompt("TutorialCustomer", "Deliver", function(player)
    local s = sessions[player.UserId]
    if not s or s.step ~= 5 then return end
    s.step = FINAL_MENU_STEP
    sendStep(player, FINAL_MENU_STEP)
end)

-- ─── Minigame result listeners (gated to tutorial sessions only) ─────────────
mixResultRemote.OnServerEvent:Connect(function(player)
    local s = sessions[player.UserId]
    if not s or not s.waitingForMix then return end
    s.waitingForMix = nil
    s.step = 2
    sendStep(player, 2)
end)

doughResultRemote.OnServerEvent:Connect(function(player)
    local s = sessions[player.UserId]
    if not s or not s.waitingForDough then return end
    s.waitingForDough = nil
    s.step = 3
    sendStep(player, 3)
end)

ovenResultRemote.OnServerEvent:Connect(function(player)
    local s = sessions[player.UserId]
    if not s or not s.waitingForOven then return end
    s.waitingForOven = nil
    s.step = 4
    sendStep(player, 4)
end)

-- ─── Skip / Complete / Replay ────────────────────────────────────────────────
tutorialDoneRemote.OnServerEvent:Connect(function(player)
    if not sessions[player.UserId] then return end
    completeTutorial(player, false)
end)

startGameRemote.OnServerEvent:Connect(function(player)
    local s = sessions[player.UserId]
    if not s or s.step ~= FINAL_MENU_STEP then return end
    completeTutorial(player, true)
end)

replayRemote.OnServerEvent:Connect(function(player)
    local s = sessions[player.UserId]
    if not s or s.step ~= FINAL_MENU_STEP then return end
    s.step = 1
    s.fridgeDone     = nil
    s.waitingForMix  = nil
    s.waitingForDough = nil
    s.waitingForOven = nil
    sendStep(player, 1)
    teleportToKitchen(player)
end)

Players.PlayerRemoving:Connect(function(player)
    sessions[player.UserId] = nil
end)

print("[TutorialKitchen] Ready.")

-- ─── Public API (called by TutorialController) ───────────────────────────────
local TutorialKitchen = {}

function TutorialKitchen.StartForPlayer(player)
    sessions[player.UserId] = { step = 1 }
    sendStep(player, 1)
    task.spawn(teleportToKitchen, player)
end

return TutorialKitchen
```

**Commit:**
```
git add src/ServerScriptService/TutorialKitchen.lua
git commit -m "feat: add TutorialKitchen standalone module"
```

---

### Task 2: Gut TutorialController to router only (disk)

**Files:**
- Modify: `src/ServerScriptService/Core/TutorialController.server.lua`

Replace the entire file with:

```lua
-- src/ServerScriptService/Core/TutorialController.server.lua
-- Routes new players to TutorialKitchen; returning players to GameSpawn.
-- All step logic lives in TutorialKitchen.lua.

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RemoteManager     = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local PlayerDataManager = require(ServerScriptService:WaitForChild("Core"):WaitForChild("PlayerDataManager"))
local TutorialKitchen   = require(ServerScriptService:WaitForChild("TutorialKitchen"))

local tutorialStepRemote = RemoteManager.Get("TutorialStep")
local TOTAL_STEPS = 5

local function handlePlayerJoin(player)
    local data
    local deadline = tick() + 10
    repeat
        task.wait(0.5)
        if not player or not player.Parent then return end
        data = PlayerDataManager.GetData(player)
    until data or tick() >= deadline

    if not player or not player.Parent then return end
    if not data then
        warn("[TutorialController] DataStore timed out for " .. player.Name)
        return
    end

    if data.tutorialCompleted then
        tutorialStepRemote:FireClient(player, {
            step = 0, total = TOTAL_STEPS, msg = "", isReturn = true
        })
        print("[TutorialController] " .. player.Name .. " returning player -> GameSpawn")
        return
    end

    -- New player: hand off to TutorialKitchen
    player:SetAttribute("InTutorial", true)
    TutorialKitchen.StartForPlayer(player)
    print("[TutorialController] " .. player.Name .. " new player -> TutorialKitchen")
end

Players.PlayerAdded:Connect(function(player)
    task.spawn(handlePlayerJoin, player)
end)

Players.PlayerRemoving:Connect(function(player)
    player:SetAttribute("InTutorial", false)
end)

for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(handlePlayerJoin, player)
end

print("[TutorialController] Ready.")
```

**Commit:**
```
git add src/ServerScriptService/Core/TutorialController.server.lua
git commit -m "refactor: gut TutorialController to router; tutorial logic moves to TutorialKitchen"
```

---

### Task 3: Guard teleportAllTo in GameStateManager (disk)

**Files:**
- Modify: `src/ServerScriptService/Core/GameStateManager.server.lua`

Find `teleportAllTo` (around line 103). Add the `InTutorial` guard inside the player loop:

**Old:**
```lua
local function teleportAllTo(targetCF)
    local playerList = Players:GetPlayers()
    local count = #playerList
    for i, player in ipairs(playerList) do
        local char = player.Character
        if char then
```

**New:**
```lua
local function teleportAllTo(targetCF)
    local playerList = Players:GetPlayers()
    local count = #playerList
    for i, player in ipairs(playerList) do
        if player:GetAttribute("InTutorial") then continue end  -- skip tutorial players
        local char = player.Character
        if char then
```

**Commit:**
```
git add src/ServerScriptService/Core/GameStateManager.server.lua
git commit -m "fix: skip InTutorial players in teleportAllTo (EndOfDay/Intermission)"
```

---

### Task 4: Push TutorialKitchen ModuleScript to Studio

```lua
-- MCP run_code:
local SSS = game:GetService("ServerScriptService")
-- Remove old if exists
local old = SSS:FindFirstChild("TutorialKitchen")
if old then old:Destroy() end

local m = Instance.new("ModuleScript")
m.Name = "TutorialKitchen"
-- paste full source from Task 1
m.Source = [[ ... full source ... ]]
m.Parent = SSS
print("TutorialKitchen ModuleScript created")
```

Note: paste the full source from Task 1 into the `[[ ]]` block.

---

### Task 5: Push gutted TutorialController to Studio

```lua
-- MCP run_code: update TutorialController source
local SSS = game:GetService("ServerScriptService")
local tc = SSS:FindFirstChild("Core"):FindFirstChild("TutorialController")
tc.Source = [[ ... full source from Task 2 ... ]]
print("TutorialController updated")
```

---

### Task 6: Push GameStateManager guard to Studio

```lua
-- MCP run_code:
local GSM = game:GetService("ServerScriptService"):FindFirstChild("Core"):FindFirstChild("GameStateManager")
local src = GSM.Source
local old = [[        for i, player in ipairs(playerList) do
        local char = player.Character
        if char then]]
local new = [[        for i, player in ipairs(playerList) do
        if player:GetAttribute("InTutorial") then continue end
        local char = player.Character
        if char then]]
local i = string.find(src, old, 1, true)
if i then
    GSM.Source = string.sub(src, 1, i-1) .. new .. string.sub(src, i + #old)
    print("GameStateManager: InTutorial guard added")
else
    print("Pattern not found")
end
```

---

### Task 7: Test in Play Mode

1. Hit **Play** in Studio
2. Check console — should see `[TutorialKitchen] Ready.` and `[TutorialController] Ready.`
3. As a new player: verify you teleport to `TutorialKitchenSpawn` (not the main bakery)
4. Complete each step: Mix → Dough → Fridge (E) → Oven → Dress (E) → Deliver (E) → Final Menu → Start Day
5. After "Start Day": verify you teleport to `GameSpawn` in main bakery
6. Run through an Open → EndOfDay → Intermission cycle while a tutorial player is mid-tutorial — verify they are NOT swept to the back room

**Expected console output:**
```
[TutorialKitchen] Ready.
[TutorialController] Ready.
[TutorialController] <PlayerName> new player -> TutorialKitchen
[TutorialKitchen] <PlayerName> tutorial COMPLETE (+$200)
```

---

### Task 8: Cleanup — remove old tutorial hooks from Studio

Once the above is verified working, clean up via MCP:
- Verify `TutorialController` in Studio no longer has `setTutorialWarmersEnabled`, `showFridgeArrow`, or `STEP_SPAWNS` (should be gone after Task 5)
- Delete the `TutorialFridgeSpawn`, `TutorialMixSpawn`, `TutorialDoughTableSpawn`, `TutorialDressTableSpawn` Parts from workspace (they were near the real stations for the old tutorial)
- Verify no `StationCompleted` listener remains in TutorialController (MinigameServer still uses it — only TutorialController's listener is removed)
