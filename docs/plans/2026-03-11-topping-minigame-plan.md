# Topping Minigame Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Insert a rapid-tap topping minigame into the Dress station flow after all warmer pickups complete, for any box containing a cookie with a `dress` field in CookieData.

**Architecture:** Client-timed, server-validated. Server detects toppings after final pickup, fires `StartToppingMinigame` remote, preserves box-creation data. Client runs the UI, fires `ToppingComplete` with elapsed time. Server clamps score and creates box.

**Tech Stack:** Roblox Lua, RemoteEvents via RemoteManager, UserInputService for E key taps, RunService.Heartbeat for timer. No automated tests — each task verified in Studio play mode via MCP run_code.

**Design doc:** `docs/plans/2026-03-11-topping-minigame-design.md`

**⚠️ Studio sync note:** Every code change must be pushed to Studio via MCP `run_code` after writing to disk. Disk files are git backup only.

---

### Task 1: Register the two new remotes in RemoteManager

**Files:**
- Modify: `src/ReplicatedStorage/Modules/RemoteManager.lua`

**Step 1: Read the current RemoteManager source from Studio**

```lua
-- MCP run_code:
local rm = game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("RemoteManager")
-- Find the REMOTES table region
local pos = rm.Source:find("HUDUpdate", 1, true)
print(rm.Source:sub(math.max(1, pos-50), pos+200))
```

**Step 2: Add the two new remotes to the REMOTES table in the disk file**

In `src/ReplicatedStorage/Modules/RemoteManager.lua`, find the REMOTES list and add after the last existing entry (e.g., after `DailyChallengeProgress`):

```lua
    "StartToppingMinigame",
    "ToppingComplete",
```

**Step 3: Push the change to Studio**

```lua
-- MCP run_code: replace the REMOTES table addition
-- Use plain-string find+replace on rm.Source
-- Find the last remote entry and insert after it
local rm = game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("RemoteManager")
local old = '    "DailyChallengeProgress",'
local new = '    "DailyChallengeProgress",\n    "StartToppingMinigame",\n    "ToppingComplete",'
local s, e = rm.Source:find(old, 1, true)
print("found:", s)
if s then rm.Source = rm.Source:sub(1,s-1)..new..rm.Source:sub(e+1); print("DONE") end
```

**Step 4: Verify remotes exist**

```lua
-- MCP run_code:
local rm = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("RemoteManager"))
local ok1 = pcall(function() return rm.Get("StartToppingMinigame") end)
local ok2 = pcall(function() return rm.Get("ToppingComplete") end)
print("StartToppingMinigame:", ok1 and "OK" or "MISSING")
print("ToppingComplete:", ok2 and "OK" or "MISSING")
```

Expected: both print "OK"

**Step 5: Commit**

```bash
git add src/ReplicatedStorage/Modules/RemoteManager.lua
git commit -m "feat: register StartToppingMinigame and ToppingComplete remotes"
```

---

### Task 2: Add topping detection helper + modify variety warmer path in DressStationServer

**Files:**
- Modify: `src/ServerScriptService/Minigames/DressStationServer.server.lua`

**Context:** The variety pickup path in `hookWarmerPrompt` currently calls `OrderManager.CreateVarietyBox` when `#lock.remaining == 0`. We need to intercept that and check for toppings first. We also need to track collected cookieId strings separately (the `lock.collected` array holds OrderManager entries, not raw cookie IDs).

**Step 1: Add `CookieData` require to DressStationServer (disk)**

At the top of `src/ServerScriptService/Minigames/DressStationServer.server.lua`, after the existing requires, add:

```lua
local CookieData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CookieData"))
```

Also add the two new remotes:
```lua
local startToppingRemote    = RemoteManager.Get("StartToppingMinigame")
local toppingCompleteRemote = RemoteManager.Get("ToppingComplete")
```

**Step 2: Add `getToppingInfo` helper function (disk)**

After the `DRESS_SCORE = 85` constant, add:

```lua
-- Returns topping label and color if any cookie in the id list has a dress field.
-- Single unique label → that label; multiple → "Add Toppings"
local function getToppingInfo(cookieIds)
    local labels, firstColor = {}, nil
    for _, id in ipairs(cookieIds) do
        local ck = CookieData.GetById(id)
        if ck and ck.dress then
            if not firstColor then firstColor = ck.dress.toppingColor end
            local lbl = ck.dress.label
            local found = false
            for _, l in ipairs(labels) do if l == lbl then found = true; break end end
            if not found then table.insert(labels, lbl) end
        end
    end
    if #labels == 0 then return nil, nil end
    return (#labels == 1 and labels[1] or "Add Toppings"), firstColor
end
```

**Step 3: Add `collectedTypes` tracking to variety lock setup (disk)**

In `lockOrder.OnServerEvent`, find where `dressLocked[player]` is set for variety orders and add `collectedTypes = {}`:

```lua
dressLocked[player] = {
    orderId        = orderId,
    isVariety      = true,
    npcName        = targetOrder.npcName,
    remaining      = uniqueTypes,
    totalSteps     = #uniqueTypes,
    collected      = {},
    collectedTypes = {},   -- ADD THIS LINE
    typeSlotCounts = typeSlotCounts,
}
```

**Step 4: Append to `collectedTypes` in variety pickup handler (disk)**

In `hookWarmerPrompt`, variety branch, after `table.insert(lock.collected, entry)`, add:

```lua
table.insert(lock.collectedTypes, cookieId)
```

**Step 5: Replace immediate `CreateVarietyBox` call with topping check (disk)**

Find the block that runs when `#lock.remaining == 0` (inside the variety branch of hookWarmerPrompt). Replace:

```lua
local box = OrderManager.CreateVarietyBox(player, lock.collected, DRESS_SCORE)
dressLocked[player] = nil
if box then
    print(string.format("[DressStation] %s completed variety pickup -- box #%d for %s",
        player.Name, box.boxId, lock.npcName))
    orderLocked:FireClient(player, { state = "done", boxId = box.boxId })
    task.defer(updateTV)
else
    orderLocked:FireClient(player, { state = "error", message = "Failed to create box" })
end
```

With:

```lua
-- Check for toppings before creating the box
local toppingLabel, toppingColor = getToppingInfo(lock.collectedTypes)
if toppingLabel then
    lock.awaitingTopping = true
    startToppingRemote:FireClient(player, { label = toppingLabel, toppingColor = toppingColor })
    return
end
-- No toppings — create box immediately
local box = OrderManager.CreateVarietyBox(player, lock.collected, DRESS_SCORE)
dressLocked[player] = nil
if box then
    print(string.format("[DressStation] %s completed variety pickup -- box #%d for %s",
        player.Name, box.boxId, lock.npcName))
    orderLocked:FireClient(player, { state = "done", boxId = box.boxId })
    task.defer(updateTV)
else
    orderLocked:FireClient(player, { state = "error", message = "Failed to create box" })
end
```

**Step 6: Push Task 2 changes to Studio via MCP and verify no errors in output**

Use MCP run_code to set the full updated Source on the DressStationServer script. Confirm `print("[DressStationServer] Ready")` appears in output with no errors.

**Step 7: Commit**

```bash
git add src/ServerScriptService/Minigames/DressStationServer.server.lua
git commit -m "feat: topping detection in variety warmer pickup path"
```

---

### Task 3: Modify single-type warmer path + add ToppingComplete handler

**Files:**
- Modify: `src/ServerScriptService/Minigames/DressStationServer.server.lua`

**Step 1: Replace immediate `CreateBox` call with topping check (disk)**

In `hookWarmerPrompt`, single-type branch, find:

```lua
local box = OrderManager.CreateBox(player, entry.batchId, DRESS_SCORE, entry)
dressLocked[player] = nil
if box then
    print(string.format("[DressStation] %s picked up %s -- box #%d created for %s",
        player.Name, cookieId, box.boxId, lock.npcName))
    orderLocked:FireClient(player, { state = "done", boxId = box.boxId })
    task.defer(updateTV)
else
    orderLocked:FireClient(player, { state = "error", message = "Failed to create box" })
end
```

Replace with:

```lua
-- Check for toppings before creating the box
local toppingLabel, toppingColor = getToppingInfo({ cookieId })
if toppingLabel then
    lock.awaitingTopping = true
    lock.pendingEntry    = entry   -- preserve warmer entry for after topping
    startToppingRemote:FireClient(player, { label = toppingLabel, toppingColor = toppingColor })
    return
end
-- No toppings — create box immediately
local box = OrderManager.CreateBox(player, entry.batchId, DRESS_SCORE, entry)
dressLocked[player] = nil
if box then
    print(string.format("[DressStation] %s picked up %s -- box #%d created for %s",
        player.Name, cookieId, box.boxId, lock.npcName))
    orderLocked:FireClient(player, { state = "done", boxId = box.boxId })
    task.defer(updateTV)
else
    orderLocked:FireClient(player, { state = "error", message = "Failed to create box" })
end
```

**Step 2: Add ToppingComplete handler (disk)**

After the `cancelOrder.OnServerEvent` block, add:

```lua
toppingCompleteRemote.OnServerEvent:Connect(function(player, elapsed)
    local lock = dressLocked[player]
    if not lock or not lock.awaitingTopping then return end
    if type(elapsed) ~= "number" then return end

    -- Anti-cheat: clamp to plausible range
    elapsed = math.clamp(elapsed, 0.5, 10)
    local score = math.clamp(100 - math.max(0, elapsed - 2) * 8, 40, 100)
    lock.awaitingTopping = false

    if lock.isVariety then
        local box = OrderManager.CreateVarietyBox(player, lock.collected, score)
        dressLocked[player] = nil
        if box then
            print(string.format("[DressStation] %s topping done (%.1fs, score=%d) -- variety box #%d",
                player.Name, elapsed, score, box.boxId))
            orderLocked:FireClient(player, { state = "done", boxId = box.boxId })
            task.defer(updateTV)
        else
            orderLocked:FireClient(player, { state = "error", message = "Failed to create box" })
        end
    else
        local entry = lock.pendingEntry
        local box   = OrderManager.CreateBox(player, entry.batchId, score, entry)
        dressLocked[player] = nil
        if box then
            print(string.format("[DressStation] %s topping done (%.1fs, score=%d) -- box #%d",
                player.Name, elapsed, score, box.boxId))
            orderLocked:FireClient(player, { state = "done", boxId = box.boxId })
            task.defer(updateTV)
        else
            orderLocked:FireClient(player, { state = "error", message = "Failed to create box" })
        end
    end
end)
```

**Step 3: Push to Studio and verify**

```lua
-- MCP run_code: confirm handler registered
local sss = game:GetService("ServerScriptService")
local ds = sss:FindFirstChild("Minigames"):FindFirstChild("DressStationServer")
local pos = ds.Source:find("toppingCompleteRemote.OnServerEvent", 1, true)
print("ToppingComplete handler:", pos ~= nil and "FOUND" or "MISSING")
```

**Step 4: Commit**

```bash
git add src/ServerScriptService/Minigames/DressStationServer.server.lua
git commit -m "feat: single-type topping check + ToppingComplete server handler"
```

---

### Task 4: Client UI — StartToppingMinigame handler in DressStationClient

**Files:**
- Modify: `src/StarterPlayer/StarterPlayerScripts/Minigames/DressStationClient.client.lua`

**Step 1: Add new remote references (disk)**

After the existing remote declarations at the top of DressStationClient, add:

```lua
local startToppingRemote    = RemoteManager.Get("StartToppingMinigame")
local toppingCompleteRemote = RemoteManager.Get("ToppingComplete")
```

**Step 2: Add `destroyToppingGui` helper (disk)**

After `destroyWarmerOverlay`, add:

```lua
local function destroyToppingGui()
    local g = playerGui:FindFirstChild("ToppingMinigameGui")
    if g then g:Destroy() end
end
```

**Step 3: Add `showToppingMinigame` function (disk)**

After `destroyToppingGui`, add the full minigame UI function:

```lua
local TAP_TARGET = 20

local function showToppingMinigame(data)
    destroyWarmerOverlay()
    destroyToppingGui()
    setMovement(false)

    local label    = data.label or "Add Toppings"
    local barColor = data.toppingColor or Color3.fromRGB(220, 180, 80)

    local startTime    = tick()
    local tapCount     = 0
    local fillFraction = 0
    local completed    = false

    local sg = Instance.new("ScreenGui")
    sg.Name           = "ToppingMinigameGui"
    sg.ResetOnSpawn   = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent         = playerGui

    local bg = Instance.new("Frame", sg)
    bg.Size                   = UDim2.new(0, 380, 0, 185)
    bg.Position               = UDim2.new(0.5, -190, 0.5, -92)
    bg.BackgroundColor3       = Color3.fromRGB(18, 18, 18)
    bg.BackgroundTransparency = 0.05
    bg.BorderSizePixel        = 0
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 14)

    local headerLbl = Instance.new("TextLabel", bg)
    headerLbl.Size                   = UDim2.new(1, -20, 0, 32)
    headerLbl.Position               = UDim2.new(0, 10, 0, 10)
    headerLbl.BackgroundTransparency = 1
    headerLbl.TextColor3             = Color3.fromRGB(255, 215, 60)
    headerLbl.Font                   = Enum.Font.GothamBold
    headerLbl.TextSize               = 18
    headerLbl.Text                   = "ADD TOPPINGS"
    headerLbl.TextXAlignment         = Enum.TextXAlignment.Left

    local toppingNameLbl = Instance.new("TextLabel", bg)
    toppingNameLbl.Size                   = UDim2.new(1, -20, 0, 22)
    toppingNameLbl.Position               = UDim2.new(0, 10, 0, 44)
    toppingNameLbl.BackgroundTransparency = 1
    toppingNameLbl.TextColor3             = Color3.fromRGB(200, 200, 220)
    toppingNameLbl.Font                   = Enum.Font.Gotham
    toppingNameLbl.TextSize               = 14
    toppingNameLbl.Text                   = label

    local barBg = Instance.new("Frame", bg)
    barBg.Size             = UDim2.new(1, -20, 0, 26)
    barBg.Position         = UDim2.new(0, 10, 0, 76)
    barBg.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    barBg.BorderSizePixel  = 0
    Instance.new("UICorner", barBg).CornerRadius = UDim.new(0, 6)

    local barFill = Instance.new("Frame", barBg)
    barFill.Size             = UDim2.new(0, 0, 1, 0)
    barFill.BackgroundColor3 = barColor
    barFill.BorderSizePixel  = 0
    Instance.new("UICorner", barFill).CornerRadius = UDim.new(0, 6)

    local pctLbl = Instance.new("TextLabel", bg)
    pctLbl.Size                   = UDim2.new(1, -20, 0, 20)
    pctLbl.Position               = UDim2.new(0, 10, 0, 106)
    pctLbl.BackgroundTransparency = 1
    pctLbl.TextColor3             = Color3.fromRGB(180, 180, 200)
    pctLbl.Font                   = Enum.Font.Gotham
    pctLbl.TextSize               = 12
    pctLbl.Text                   = "0%"
    pctLbl.TextXAlignment         = Enum.TextXAlignment.Right

    local instrLbl = Instance.new("TextLabel", bg)
    instrLbl.Size                   = UDim2.new(1, -20, 0, 22)
    instrLbl.Position               = UDim2.new(0, 10, 0, 128)
    instrLbl.BackgroundTransparency = 1
    instrLbl.TextColor3             = Color3.fromRGB(210, 210, 210)
    instrLbl.Font                   = Enum.Font.GothamBold
    instrLbl.TextSize               = 13
    instrLbl.Text                   = "Tap  E  rapidly to shake!"

    local timerLbl = Instance.new("TextLabel", bg)
    timerLbl.Size                   = UDim2.new(1, -20, 0, 20)
    timerLbl.Position               = UDim2.new(0, 10, 0, 155)
    timerLbl.BackgroundTransparency = 1
    timerLbl.TextColor3             = Color3.fromRGB(140, 200, 140)
    timerLbl.Font                   = Enum.Font.Gotham
    timerLbl.TextSize               = 12
    timerLbl.Text                   = "0.0s"
    timerLbl.TextXAlignment         = Enum.TextXAlignment.Right

    local function complete()
        if completed then return end
        completed = true
        local elapsed = tick() - startTime

        local rating = elapsed <= 2 and "Perfect!" or (elapsed <= 4 and "Good!" or "OK")
        local flashLbl = Instance.new("TextLabel", bg)
        flashLbl.Size                   = UDim2.new(1, 0, 1, 0)
        flashLbl.BackgroundColor3       = Color3.fromRGB(25, 25, 35)
        flashLbl.BackgroundTransparency = 0.05
        flashLbl.TextColor3             = Color3.fromRGB(255, 255, 255)
        flashLbl.Font                   = Enum.Font.GothamBold
        flashLbl.TextSize               = 20
        flashLbl.Text                   = rating .. string.format("  %.1fs", elapsed)
        flashLbl.ZIndex                 = 10
        flashLbl.BorderSizePixel        = 0
        Instance.new("UICorner", flashLbl).CornerRadius = UDim.new(0, 14)

        toppingCompleteRemote:FireServer(elapsed)

        task.delay(1.2, function()
            destroyToppingGui()
            setMovement(true)
        end)
    end

    local UIS = game:GetService("UserInputService")
    local inputConn
    inputConn = UIS.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed or completed then return end
        if input.KeyCode ~= Enum.KeyCode.E then return end
        tapCount      += 1
        fillFraction   = math.min(1, tapCount / TAP_TARGET)
        barFill.Size   = UDim2.new(fillFraction, 0, 1, 0)
        pctLbl.Text    = math.floor(fillFraction * 100) .. "%"
        if fillFraction >= 1 then
            inputConn:Disconnect()
            complete()
        end
    end)

    local RunService = game:GetService("RunService")
    local heartbeatConn
    heartbeatConn = RunService.Heartbeat:Connect(function()
        if completed then heartbeatConn:Disconnect(); return end
        if not sg.Parent then heartbeatConn:Disconnect(); return end
        timerLbl.Text = string.format("%.1fs", tick() - startTime)
    end)
end
```

**Step 4: Wire the remote (disk)**

After the `orderLocked.OnClientEvent` handler block, add:

```lua
startToppingRemote.OnClientEvent:Connect(function(data)
    showToppingMinigame(data)
end)
```

**Step 5: Push the full updated DressStationClient to Studio via MCP**

Set the script's Source to the full updated content. Verify with:

```lua
-- MCP run_code:
local sps = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local dc = sps:FindFirstChild("Minigames"):FindFirstChild("DressStationClient")
local pos = dc.Source:find("showToppingMinigame", 1, true)
print("showToppingMinigame:", pos ~= nil and "FOUND" or "MISSING")
```

**Step 6: Manual play-mode test**

Start play mode. Take an order for a cookie with toppings (e.g., Birthday Cake = Sprinkles):
1. Open KDS → select order → warmer overlay appears
2. Walk to warmer → trigger WarmerPickupPrompt
3. Topping minigame UI should appear ("ADD TOPPINGS / Sprinkles")
4. Tap E 20 times → bar fills → "Perfect!" flash → GUI closes
5. Check output: `[DressStation] <name> topping done (Xs, score=Y) -- box #N`
6. "Box #N ready! Deliver to the customer" flash should appear
7. Deliver to NPC — order completes

Also verify: a cookie WITHOUT toppings (e.g., Chocolate Chip) skips the minigame entirely and creates the box immediately as before.

**Step 7: Commit**

```bash
git add src/StarterPlayer/StarterPlayerScripts/Minigames/DressStationClient.client.lua
git commit -m "feat: topping minigame UI — tap E to fill bar, fires ToppingComplete"
```

---

### Task 5: Final verification + scope doc update

**Step 1: Verify variety pack path in play mode**

Start play mode. If the active menu has 2+ topping cookies and a variety order comes in:
1. Complete all warmer pickups (e.g., 2 types)
2. After FINAL pickup, topping minigame fires once
3. Label should say "Add Toppings" (if both cookies have toppings)
4. Complete minigame → box created → deliver successfully

**Step 2: Update pre-playtest scope doc**

In `docs/plans/2026-03-10-pre-playtest-scope.md`, mark item #3 as done:
```
| 3 | Topping minigame | Medium | ✅ Done |
```

**Step 3: Final commit**

```bash
git add docs/plans/2026-03-10-pre-playtest-scope.md
git commit -m "docs: mark topping minigame complete in pre-playtest scope"
```
