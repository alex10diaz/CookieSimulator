# Fridge → Oven Carry System Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Players grab a dough tray from a cookie-type fridge, physically carry it (arms raised, pan welded to character), and deposit it at an oven to trigger the oven minigame.

**Architecture:** One server script (`FridgeOvenSystem.server.lua`) manages all state. Two RemoteEvents handle client→server communication. A BindableEvent connects the upstream dough system to fridge stock. Tray carry is implemented via Weld to HumanoidRootPart + Motor6D arm rotation on the server (replicates to all clients automatically).

**Tech Stack:** Roblox Luau, ServerScriptService, RemoteEvents, BindableEvent, Motor6D, Weld, ProximityPrompt, BillboardGui

---

### Task 1: Set Up Studio Assets

These are manual steps in Roblox Studio (not scripted).

**Step 1: Create PanTemplate in ServerStorage**
- In Studio Explorer, find any `Pan` model in Workspace
- Duplicate it, move the duplicate into `ServerStorage`
- Rename it `PanTemplate`
- Select all parts inside it, set `Anchored = false`, `CanCollide = false`
- Set a primary part: select the main flat pan part, right-click → Set as Primary Part

**Step 2: Create DoughBatchComplete BindableEvent**
- In ServerStorage, create a Folder named `Events`
- Inside it, create a `BindableEvent` named `DoughBatchComplete`

**Step 3: Save and verify**
- File → Save to Roblox
- Confirm in Explorer: `ServerStorage/PanTemplate` (Model), `ServerStorage/Events/DoughBatchComplete` (BindableEvent)

---

### Task 2: Create RemoteEvents

**Files:**
- Modify: Studio → ReplicatedStorage (via MCP run_code)

**Step 1: Create the remotes via MCP**

Run in Studio:
```lua
local RS = game:GetService("ReplicatedStorage")
local remotes = RS:FindFirstChild("Remotes") or Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = RS

local grabTray = Instance.new("RemoteEvent")
grabTray.Name = "GrabTray"
grabTray.Parent = remotes

local depositTray = Instance.new("RemoteEvent")
depositTray.Name = "DepositTray"
depositTray.Parent = remotes

print("Remotes created:", grabTray:GetFullName(), depositTray:GetFullName())
```

**Step 2: Verify output shows both paths**
Expected:
```
Remotes created: ReplicatedStorage.Remotes.GrabTray ReplicatedStorage.Remotes.DepositTray
```

**Step 3: Save to Roblox**

---

### Task 3: Create FridgeOvenSystem — Stock Table & Display Updater

**Files:**
- Create: `src/ServerScriptService/FridgeOvenSystem.server.lua`

**Step 1: Write the script skeleton with stock table and display updater**

```lua
-- FridgeOvenSystem.server.lua
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- Constants
local MAX_STOCK = 4
local CARRY_OFFSET = CFrame.new(0, 1, -3) -- forward and slightly up from HRP

-- Cookie type → fridge model name mapping
local FRIDGE_NAMES = {
    pink_sugar           = "fridge_pink_sugar",
    chocolate_chip       = "fridge_chocolate_chip",
    birthday_cake        = "fridge_birthday_cake",
    cookies_and_cream    = "fridge_cookies_and_cream",
    snickerdoodle        = "fridge_snickerdoodle",
    lemon_blackraspberry = "fridge_lemon_blackraspberry",
}

-- Stock state
local fridgeStock = {}
for cookieType, _ in pairs(FRIDGE_NAMES) do
    fridgeStock[cookieType] = 0
end

-- Carry state: { [player] = { cookieType, panModel } }
local carryState = {}

-- References
local fridgesFolder = Workspace:WaitForChild("Fridges")
local ovensFolder   = Workspace:WaitForChild("Ovens")
local panTemplate   = ServerStorage:WaitForChild("PanTemplate")

local remotes       = ReplicatedStorage:WaitForChild("Remotes")
local grabTrayEvent    = remotes:WaitForChild("GrabTray")
local depositTrayEvent = remotes:WaitForChild("DepositTray")

local doughBatchComplete = ServerStorage:WaitForChild("Events"):WaitForChild("DoughBatchComplete")

-- Helper: get fridge model by cookieType
local function getFridgeModel(cookieType)
    return fridgesFolder:FindFirstChild(FRIDGE_NAMES[cookieType])
end

-- Helper: update FridgeDisplay BillboardGui
local function updateDisplay(cookieType)
    local fridge = getFridgeModel(cookieType)
    if not fridge then return end
    local stock = fridgeStock[cookieType]
    -- Find the BillboardGui
    for _, part in ipairs(fridge:GetDescendants()) do
        if part:IsA("BillboardGui") and part.Name == "FridgeDisplay" then
            local frame = part:FindFirstChild("Frame")
            if frame then
                local label = frame:FindFirstChildWhichIsA("TextLabel")
                if label then
                    label.Text = tostring(stock) .. "/" .. MAX_STOCK
                end
            end
        end
    end
end

-- Helper: set FridgePrompt enabled state
local function setPromptEnabled(cookieType, enabled)
    local fridge = getFridgeModel(cookieType)
    if not fridge then return end
    for _, desc in ipairs(fridge:GetDescendants()) do
        if desc:IsA("ProximityPrompt") and desc.Name == "FridgePrompt" then
            desc.Enabled = enabled
        end
    end
end

-- Initialize displays
for cookieType, _ in pairs(FRIDGE_NAMES) do
    updateDisplay(cookieType)
    setPromptEnabled(cookieType, false) -- start disabled (stock = 0)
end

print("[FridgeOvenSystem] Initialized. All fridges at 0/" .. MAX_STOCK)
```

**Step 2: Push to Studio via Rojo (ensure rojo serve is running and Studio is connected)**

**Step 3: Play-test — open Output, confirm:**
```
[FridgeOvenSystem] Initialized. All fridges at 0/4
```

**Step 4: Commit**
```bash
git add src/ServerScriptService/FridgeOvenSystem.server.lua
git commit -m "feat: add FridgeOvenSystem with stock table and display init"
```

---

### Task 4: Dough → Fridge Stock Interface

**Files:**
- Modify: `src/ServerScriptService/FridgeOvenSystem.server.lua` (append)

**Step 1: Add AddBatch handler after the init block**

```lua
-- Dough system fires this when a batch is ready for a specific cookie type
doughBatchComplete.Event:Connect(function(cookieType)
    if not fridgeStock[cookieType] then
        warn("[FridgeOvenSystem] Unknown cookieType: " .. tostring(cookieType))
        return
    end
    if fridgeStock[cookieType] >= MAX_STOCK then
        warn("[FridgeOvenSystem] Fridge full for: " .. cookieType)
        return
    end

    fridgeStock[cookieType] += 1
    updateDisplay(cookieType)

    -- Enable prompt now that there's stock
    if fridgeStock[cookieType] == 1 then
        setPromptEnabled(cookieType, true)
    end

    print("[FridgeOvenSystem] Stocked " .. cookieType .. ": " .. fridgeStock[cookieType] .. "/" .. MAX_STOCK)
end)
```

**Step 2: Test via MCP — fire the BindableEvent manually**

Run in Studio:
```lua
local ss = game:GetService("ServerStorage")
ss.Events.DoughBatchComplete:Fire("pink_sugar")
ss.Events.DoughBatchComplete:Fire("pink_sugar")
```

Expected Output:
```
[FridgeOvenSystem] Stocked pink_sugar: 1/4
[FridgeOvenSystem] Stocked pink_sugar: 2/4
```

Expected in game: pink_sugar fridge display shows "2/4", FridgePrompt becomes enabled.

**Step 3: Commit**
```bash
git add src/ServerScriptService/FridgeOvenSystem.server.lua
git commit -m "feat: wire dough→fridge stock via BindableEvent"
```

---

### Task 5: Arm Raise / Lower Helpers

**Files:**
- Modify: `src/ServerScriptService/FridgeOvenSystem.server.lua` (append helpers before event handlers)

**Step 1: Add arm animation helpers**

```lua
-- Arm carry pose: raise both arms forward (R6 characters)
local function raiseArms(character)
    local torso = character:FindFirstChild("Torso")
    if not torso then return end

    local rightShoulder = torso:FindFirstChild("Right Shoulder")
    local leftShoulder  = torso:FindFirstChild("Left Shoulder")

    if rightShoulder then
        -- Rotate right arm forward/up (carrying position)
        rightShoulder.C0 = CFrame.new(1, 0.5, 0) * CFrame.fromEulerAnglesXYZ(0, math.rad(90), math.rad(-90))
    end
    if leftShoulder then
        -- Mirror for left arm
        leftShoulder.C0 = CFrame.new(-1, 0.5, 0) * CFrame.fromEulerAnglesXYZ(0, math.rad(-90), math.rad(90))
    end
end

-- Reset arms to default R6 pose
local function resetArms(character)
    local torso = character:FindFirstChild("Torso")
    if not torso then return end

    local rightShoulder = torso:FindFirstChild("Right Shoulder")
    local leftShoulder  = torso:FindFirstChild("Left Shoulder")

    if rightShoulder then
        rightShoulder.C0 = CFrame.new(1, 0.5, 0) * CFrame.fromEulerAnglesXYZ(0, math.rad(90), 0)
    end
    if leftShoulder then
        leftShoulder.C0 = CFrame.new(-1, 0.5, 0) * CFrame.fromEulerAnglesXYZ(0, math.rad(-90), 0)
    end
end
```

> **Note:** The exact Motor6D CFrame values may need tuning in play mode. Adjust the euler angle values until the pose looks natural for holding a tray in front of the character.

**Step 2: Test via MCP in play mode**

Run in Studio play mode:
```lua
local Players = game:GetService("Players")
local char = Players:GetPlayers()[1].Character
-- Paste raiseArms logic directly to test
local torso = char:FindFirstChild("Torso")
torso["Right Shoulder"].C0 = CFrame.new(1, 0.5, 0) * CFrame.fromEulerAnglesXYZ(0, math.rad(90), math.rad(-90))
torso["Left Shoulder"].C0 = CFrame.new(-1, 0.5, 0) * CFrame.fromEulerAnglesXYZ(0, math.rad(-90), math.rad(90))
```

Visually confirm arms raise to a carrying position. Adjust angles if needed.

**Step 3: Commit**
```bash
git add src/ServerScriptService/FridgeOvenSystem.server.lua
git commit -m "feat: add raiseArms/resetArms Motor6D helpers"
```

---

### Task 6: Grab Tray — Server Handler

**Files:**
- Modify: `src/ServerScriptService/FridgeOvenSystem.server.lua` (append)

**Step 1: Add GrabTray handler**

```lua
-- Helper: weld pan to player HRP
local function attachPan(player, cookieType)
    local character = player.Character
    if not character then return nil end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local pan = panTemplate:Clone()
    pan.Name = "CarryPan_" .. cookieType
    pan.Parent = Workspace

    local weld = Instance.new("Weld")
    weld.Name = "CarryWeld"
    weld.Part0 = hrp
    weld.Part1 = pan.PrimaryPart
    weld.C0 = CARRY_OFFSET
    weld.Parent = hrp

    return pan
end

-- GrabTray: client fires with cookieType string
grabTrayEvent.OnServerEvent:Connect(function(player, cookieType)
    -- Validate cookieType
    if not FRIDGE_NAMES[cookieType] then
        warn("[FridgeOvenSystem] GrabTray: invalid cookieType from " .. player.Name)
        return
    end

    -- Validate not already carrying
    if carryState[player] then
        warn("[FridgeOvenSystem] GrabTray: " .. player.Name .. " already carrying")
        return
    end

    -- Validate stock
    if fridgeStock[cookieType] <= 0 then
        warn("[FridgeOvenSystem] GrabTray: no stock for " .. cookieType)
        return
    end

    -- Attach pan
    local pan = attachPan(player, cookieType)
    if not pan then return end

    -- Update state
    carryState[player] = { cookieType = cookieType, panModel = pan }
    fridgeStock[cookieType] -= 1
    updateDisplay(cookieType)

    -- Disable fridge prompt if empty
    if fridgeStock[cookieType] == 0 then
        setPromptEnabled(cookieType, false)
    end

    -- Raise arms
    raiseArms(player.Character)

    -- Enable oven prompts
    for _, oven in ipairs(ovensFolder:GetChildren()) do
        local prompt = oven:FindFirstChild("OvenPrompt", true)
        if prompt then prompt.Enabled = true end
    end

    print("[FridgeOvenSystem] " .. player.Name .. " grabbed tray: " .. cookieType)
end)
```

**Step 2: Wire FridgePrompt to fire GrabTray on client**

The FridgePrompt fires server-side so we can connect directly. Add proximity prompt connections:

```lua
-- Connect all FridgePrompts
for cookieType, fridgeName in pairs(FRIDGE_NAMES) do
    local fridge = fridgesFolder:WaitForChild(fridgeName)
    for _, desc in ipairs(fridge:GetDescendants()) do
        if desc:IsA("ProximityPrompt") and desc.Name == "FridgePrompt" then
            desc.Triggered:Connect(function(player)
                -- Fire as if client sent it (server-side trigger is fine here)
                grabTrayEvent:FireServer(cookieType) -- won't work server-side
                -- Instead, call handler logic directly:
            end)
        end
    end
end
```

> **Note:** `ProximityPrompt.Triggered` fires on the **server** with the player as argument. So we call the grab logic directly rather than going through RemoteEvent. Refactor: extract grab logic into a function `handleGrabTray(player, cookieType)` and call it from both the prompt and the RemoteEvent.

**Step 2 (revised): Refactor to shared function**

```lua
local function handleGrabTray(player, cookieType)
    if not FRIDGE_NAMES[cookieType] then return end
    if carryState[player] then return end
    if fridgeStock[cookieType] <= 0 then return end

    local pan = attachPan(player, cookieType)
    if not pan then return end

    carryState[player] = { cookieType = cookieType, panModel = pan }
    fridgeStock[cookieType] -= 1
    updateDisplay(cookieType)

    if fridgeStock[cookieType] == 0 then
        setPromptEnabled(cookieType, false)
    end

    raiseArms(player.Character)

    for _, oven in ipairs(ovensFolder:GetChildren()) do
        local prompt = oven:FindFirstChild("OvenPrompt", true)
        if prompt then prompt.Enabled = true end
    end

    print("[FridgeOvenSystem] " .. player.Name .. " grabbed: " .. cookieType)
end

-- Connect FridgePrompts (server-side trigger)
for cookieType, fridgeName in pairs(FRIDGE_NAMES) do
    local fridge = fridgesFolder:WaitForChild(fridgeName)
    for _, desc in ipairs(fridge:GetDescendants()) do
        if desc:IsA("ProximityPrompt") and desc.Name == "FridgePrompt" then
            desc.Triggered:Connect(function(player)
                handleGrabTray(player, cookieType)
            end)
        end
    end
end

-- RemoteEvent fallback (if needed by client)
grabTrayEvent.OnServerEvent:Connect(function(player, cookieType)
    handleGrabTray(player, cookieType)
end)
```

**Step 3: Play-test**
1. Fire DoughBatchComplete for "chocolate_chip" via MCP
2. Walk player up to chocolate_chip fridge
3. Confirm: prompt appears, player grabs tray, arms raise, pan appears, display decrements

**Step 4: Commit**
```bash
git add src/ServerScriptService/FridgeOvenSystem.server.lua
git commit -m "feat: implement grab tray flow with arm raise and stock decrement"
```

---

### Task 7: Deposit Tray — Server Handler

**Files:**
- Modify: `src/ServerScriptService/FridgeOvenSystem.server.lua` (append)

**Step 1: Add deposit logic**

```lua
-- Helper: place pan in oven InsideRack
local function placePanInOven(pan, oven)
    local rack = oven:FindFirstChild("InsideRack")
    if not rack then
        warn("[FridgeOvenSystem] No InsideRack found in " .. oven.Name)
        pan:Destroy()
        return
    end

    -- Remove carry weld
    pan.PrimaryPart.Parent = pan -- ensure hierarchy intact
    for _, w in ipairs(workspace:GetDescendants()) do
        if w:IsA("Weld") and w.Name == "CarryWeld" and w.Part1 == pan.PrimaryPart then
            w:Destroy()
        end
    end

    -- Anchor in rack
    pan.Parent = rack
    pan:PivotTo(rack:GetPivot())
    for _, part in ipairs(pan:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Anchored = true
        end
    end
end

local function handleDepositTray(player, ovenName)
    local state = carryState[player]
    if not state then
        warn("[FridgeOvenSystem] DepositTray: " .. player.Name .. " not carrying")
        return
    end

    -- Find oven
    local oven = ovensFolder:FindFirstChild(ovenName or "Oven1")
    if not oven then
        warn("[FridgeOvenSystem] DepositTray: oven not found: " .. tostring(ovenName))
        return
    end

    -- Place pan
    placePanInOven(state.panModel, oven)

    -- Reset arms
    resetArms(player.Character)

    -- Clear carry state
    carryState[player] = nil

    -- Disable oven prompts
    for _, o in ipairs(ovensFolder:GetChildren()) do
        local prompt = o:FindFirstChild("OvenPrompt", true)
        if prompt then prompt.Enabled = false end
    end

    -- Re-enable fridge prompt if stock available
    if fridgeStock[state.cookieType] > 0 then
        setPromptEnabled(state.cookieType, true)
    end

    print("[FridgeOvenSystem] " .. player.Name .. " deposited tray in " .. oven.Name)

    -- TODO: trigger oven minigame here
    -- OvenMinigame.Start(player, oven, state.cookieType)
end

-- Connect OvenPrompts
for _, oven in ipairs(ovensFolder:GetChildren()) do
    local prompt = oven:FindFirstChild("OvenPrompt", true)
    if prompt then
        prompt.Enabled = false -- start disabled
        prompt.Triggered:Connect(function(player)
            handleDepositTray(player, oven.Name)
        end)
    end
end

-- RemoteEvent fallback
depositTrayEvent.OnServerEvent:Connect(function(player, ovenName)
    handleDepositTray(player, ovenName)
end)
```

**Step 2: Play-test full flow**
1. Fire DoughBatchComplete → fridge gets stock
2. Walk to fridge → grab tray (arms raise, pan appears)
3. Walk to oven → deposit tray
4. Confirm: arms reset, pan moves to InsideRack, oven prompt disables, fridge prompt re-enables

**Step 3: Commit**
```bash
git add src/ServerScriptService/FridgeOvenSystem.server.lua
git commit -m "feat: implement deposit tray flow with pan placement and arm reset"
```

---

### Task 8: Cleanup on Disconnect

**Files:**
- Modify: `src/ServerScriptService/FridgeOvenSystem.server.lua` (append)

**Step 1: Add PlayerRemoving cleanup**

```lua
Players.PlayerRemoving:Connect(function(player)
    local state = carryState[player]
    if state then
        -- Clean up pan
        if state.panModel and state.panModel.Parent then
            state.panModel:Destroy()
        end
        carryState[player] = nil
        print("[FridgeOvenSystem] Cleaned up carry state for " .. player.Name)
    end
end)
```

**Step 2: Play-test**
- Start carrying a tray, then stop play mode — confirm no orphaned pan models remain in workspace

**Step 3: Commit**
```bash
git add src/ServerScriptService/FridgeOvenSystem.server.lua
git commit -m "feat: clean up carry state on player disconnect"
```

---

### Task 9: Push to GitHub

```bash
git push
```

---

## Testing Checklist

- [ ] All fridges show `0/4` on game start
- [ ] FridgePrompts disabled at start
- [ ] Firing DoughBatchComplete increments stock and enables prompt
- [ ] Fridge at max (4/4) refuses additional stock with warning
- [ ] Grabbing tray: arms raise, pan attaches, stock decrements, display updates
- [ ] Can't grab second tray while carrying
- [ ] Oven prompt only appears while carrying
- [ ] Depositing tray: pan moves to InsideRack, arms reset, carry state cleared
- [ ] Player disconnect: pan removed, state cleaned
- [ ] Two players can carry simultaneously without interfering
