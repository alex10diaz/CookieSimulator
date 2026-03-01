# POS Order Cutscene Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** When a player presses E on an NPC at the POS counter, a speech-bubble cutscene plays showing the order and earnings preview; confirming it (or waiting 5s) officially starts the order and moves the NPC to a waiting seat.

**Architecture:** Two-step order flow — Step 1 (NPC prompt) generates order data and fires `StartOrderCutscene` to the client; Step 2 (`ConfirmNPCOrder` remote from client) creates the OrderManager entry, moves NPC to waiting area, and updates the HUD. POSClient is rewritten to show the cutscene modal instead of the broken order list.

**Tech Stack:** Roblox Lua, RemoteEvents (RemoteManager), PersistentNPCSpawner (server), POSClient (client), MCP run_code for Studio sync and remote registration.

---

## Context

- Design doc: `docs/plans/2026-03-01-pos-order-cutscene-design.md`
- `PersistentNPCSpawner` lives at `src/ServerScriptService/Core/PersistentNPCSpawner.server.lua`
- `POSClient` lives at `src/StarterGui/POSGui/POSClient.client.lua`
- All remotes are registered via `RemoteManager.Get("Name")` which auto-creates them in `ReplicatedStorage/GameEvents`
- NPC states flow: `waiting_in_queue` → **`cutscene_pending`** (NEW) → `ordered` → `walking_to_seat` → `seated`
- `CookieData` provides `cookie.name` (display name, e.g. "Pink Sugar") and `cookie.price` (per-cookie base value)
- `calcPrice(cookieId, packSize)` returns `cookie.price × packSize` — this is `baseCoins`
- Patience ticker already starts at spawn and only decrements in `waiting_in_queue` and `seated` states — no change needed there

---

## Task 1: Register new remotes in Studio

**Files:**
- Studio only (MCP `run_code`)

**Step 1: Register both new RemoteEvents**

Run this via MCP `run_code`:

```lua
local ge = game:GetService("ReplicatedStorage"):FindFirstChild("GameEvents")
if not ge then print("ERROR: GameEvents folder not found") return end

local names = { "StartOrderCutscene", "ConfirmNPCOrder" }
for _, name in ipairs(names) do
    if ge:FindFirstChild(name) then
        print(name .. " already exists")
    else
        local re = Instance.new("RemoteEvent")
        re.Name = name
        re.Parent = ge
        print("Created: " .. name)
    end
end
```

Expected output:
```
Created: StartOrderCutscene
Created: ConfirmNPCOrder
```

**Step 2: Verify**

Run via MCP `run_code`:
```lua
local ge = game:GetService("ReplicatedStorage").GameEvents
print("StartOrderCutscene:", ge:FindFirstChild("StartOrderCutscene") ~= nil)
print("ConfirmNPCOrder:", ge:FindFirstChild("ConfirmNPCOrder") ~= nil)
```

Expected: both `true`

**Step 3: Commit**
```bash
git add .
git commit -m "feat: register StartOrderCutscene and ConfirmNPCOrder remotes"
```

---

## Task 2: Update PersistentNPCSpawner — two-step order flow

**Files:**
- Modify: `src/ServerScriptService/Core/PersistentNPCSpawner.server.lua`

**Context:**
- Current `takeOrder` (lines ~177–240) does everything in one step: generate order, create OrderManager entry, move NPC to waiting area
- New `takeOrder` only handles Step 1: generate order data, set state `"cutscene_pending"`, fire `StartOrderCutscene` to player
- New `confirmOrder` handles Step 2: create OrderManager entry, update tablet, fire HUD update, move NPC to seat
- `startPatienceTicker` is called from `spawnNPC` and already handles all states — no change needed

**Step 1: Add new remote variables after existing remote declarations (around line 55–56)**

In `PersistentNPCSpawner.server.lua`, find:
```lua
local deliveryResult = RemoteManager.Get("DeliveryResult")
local hudUpdate      = RemoteManager.Get("HUDUpdate")
```

Add two lines after:
```lua
local deliveryResult          = RemoteManager.Get("DeliveryResult")
local hudUpdate               = RemoteManager.Get("HUDUpdate")
local startOrderCutsceneRemote = RemoteManager.Get("StartOrderCutscene")
local confirmOrderRemote       = RemoteManager.Get("ConfirmNPCOrder")
```

**Step 2: Replace the entire `takeOrder` function body**

Find the current function (starts around line 177, ends around line 240):
```lua
takeOrder = function(player, npcId)
    local data = npcs[npcId]
    if not data then return end
    if data.state ~= "waiting_in_queue" then return end
    if data.queueSlot ~= 1 then return end

    local cookie   = CookieData.GetRandom()
    local packSize = PACK_SIZES[math.random(1, #PACK_SIZES)]
    local price    = calcPrice(cookie.id, packSize)

    data.order = {
        cookieId   = cookie.id,
        cookieName = cookie.name,
        packSize   = packSize,
        price      = price,
        isVIP      = data.isVIP,
        orderId    = nil,
    }
    data.state = "ordered"
    NPCSpawner.SetPromptEnabled(data.model, false)

    -- Register with OrderManager (extras passed through)
    local order = OrderManager.AddNPCOrder(data.name, cookie.id, {
        packSize = packSize,
        price    = price,
        isVIP    = data.isVIP,
        npcId    = npcId,
    })
    data.order.orderId = order.orderId

    updateTabletDisplay({
        cookieId = cookie.id,
        packSize = packSize,
        price    = price,
        isVIP    = data.isVIP,
        status   = "In kitchen...",
    })

    -- Remove from queue then shift others forward
    for i, id in ipairs(npcQueue) do
        if id == npcId then
            table.remove(npcQueue, i)
            break
        end
    end
    advanceQueue()

    -- Walk to a waiting area spot
    local spot = getFreeWaitSpot()
    if spot then
        data.waitSpot = spot.Name
        data.state    = "walking_to_seat"
        data.cancelMove = NPCSpawner.MoveTo(data.model, spot.Position + Vector3.new(0, 2, 0), function()
            if npcs[npcId] then data.state = "seated" end
        end)
    else
        data.state = "seated"
    end

    print(string.format("[NPCController] %s ordered %dx %s | price=%d | orderId=%s",
        data.name, packSize, cookie.id, price, tostring(data.order.orderId)))
end
```

Replace with:
```lua
takeOrder = function(player, npcId)
    local data = npcs[npcId]
    if not data then return end
    if data.state ~= "waiting_in_queue" then return end
    if data.queueSlot ~= 1 then return end

    local cookie   = CookieData.GetRandom()
    local packSize = PACK_SIZES[math.random(1, #PACK_SIZES)]
    local price    = calcPrice(cookie.id, packSize)

    -- Store order data — confirmed in Step 2 (confirmOrder)
    data.order = {
        cookieId   = cookie.id,
        cookieName = cookie.name,
        packSize   = packSize,
        price      = price,
        isVIP      = data.isVIP,
        orderId    = nil,
    }
    data.state = "cutscene_pending"
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
        cookieName = cookie.name,
        packSize   = packSize,
        baseCoins  = price,
        isVIP      = data.isVIP,
    })

    print(string.format("[NPCController] Cutscene fired to %s for NPC %s (%s x%d)",
        player.Name, data.name, cookie.id, packSize))
end
```

**Step 3: Add `confirmOrder` function immediately after `takeOrder`**

After the closing `end` of `takeOrder`, add:
```lua
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

    -- Register with OrderManager
    local order = OrderManager.AddNPCOrder(data.name, data.order.cookieId, {
        packSize = data.order.packSize,
        price    = data.order.price,
        isVIP    = data.order.isVIP,
        npcId    = npcId,
    })
    data.order.orderId = order.orderId
    data.state = "ordered"

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
        hudUpdate:FireClient(player, nil, nil,
            data.order.cookieName .. " ×" .. data.order.packSize)
    end)

    -- Walk to a waiting area spot
    local spot = getFreeWaitSpot()
    if spot then
        data.waitSpot   = spot.Name
        data.state      = "walking_to_seat"
        data.cancelMove = NPCSpawner.MoveTo(data.model, spot.Position + Vector3.new(0, 2, 0), function()
            if npcs[npcId] then data.state = "seated" end
        end)
    else
        data.state = "seated"
    end

    print(string.format("[NPCController] Order confirmed: %s %dx %s | price=%d | orderId=%s",
        data.name, data.order.packSize, data.order.cookieId,
        data.order.price, tostring(data.order.orderId)))
end

confirmOrderRemote.OnServerEvent:Connect(function(player, npcId)
    confirmOrder(player, npcId)
end)
```

**Step 4: Add disconnect cleanup for `cutscene_pending` in `Players.PlayerRemoving`**

Find the existing `PlayerRemoving` block near the bottom of the file:
```lua
Players.PlayerRemoving:Connect(function(player)
    for cookieId, pending in pairs(pendingBoxes) do
        if pending.carrier == player.Name then
            pendingBoxes[cookieId] = nil
        end
    end
end)
```

Replace with:
```lua
Players.PlayerRemoving:Connect(function(player)
    for cookieId, pending in pairs(pendingBoxes) do
        if pending.carrier == player.Name then
            pendingBoxes[cookieId] = nil
        end
    end
    -- Auto-confirm any NPC stuck in cutscene_pending if player disconnects
    for npcId, data in pairs(npcs) do
        if data.state == "cutscene_pending" then
            confirmOrder(player, npcId)
        end
    end
end)
```

**Step 5: Sync to Studio via MCP `run_code`**

```lua
local fs = require(game:GetService("ServerScriptService"))
-- Read the file from disk and push to Studio script
-- (Use the standard MCP sync pattern: set script.Source = [file contents])
```

Use MCP `run_code` to set `ServerScriptService.Core.PersistentNPCSpawner.Source` to the full updated file contents.

**Step 6: Verify in Studio output (play test)**

Run the game. Check console for:
- `[NPCController] Ready` — script loaded
- No errors about `StartOrderCutscene` or `ConfirmNPCOrder`

**Step 7: Commit**
```bash
git add src/ServerScriptService/Core/PersistentNPCSpawner.server.lua
git commit -m "feat: split takeOrder into cutscene-fire + confirmOrder steps"
```

---

## Task 3: Rewrite POSClient — cutscene modal

**Files:**
- Modify: `src/StarterGui/POSGui/POSClient.client.lua`

**Context:**
- Current file builds a scrolling order list that calls `OrderManager.GetNPCOrders()` on the client — this always returns empty (client has no NPC order state)
- New file listens to `StartOrderCutscene`, builds a modal with speech bubble + earnings, auto-dismisses in 5s, fires `ConfirmNPCOrder` on dismiss
- Keep: `stateRemote` (GameStateChanged), `acceptedEvent` (OrderAccepted) — HUDController already handles `OrderAccepted` so no change needed there
- Remove: `acceptRemote` (AcceptOrder), `OrderManager` require, `refreshPOS`, `buildOrderTicket`, broken ProximityPromptService handler

**Step 1: Replace entire file contents**

Write `src/StarterGui/POSGui/POSClient.client.lua`:

```lua
-- src/StarterGui/POSGui/POSClient.client.lua
-- Handles the POS order cutscene modal.
-- Triggered by StartOrderCutscene (server → client) when player presses E on NPC.
-- Fires ConfirmNPCOrder (client → server) when player dismisses or 5s passes.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")

local RemoteManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))

local stateRemote    = RemoteManager.Get("GameStateChanged")
local cutsceneRemote = RemoteManager.Get("StartOrderCutscene")
local confirmRemote  = RemoteManager.Get("ConfirmNPCOrder")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local posGui    = playerGui:WaitForChild("POSGui")
posGui.Enabled  = false

-- ─── BUILD CUTSCENE MODAL ─────────────────────────────────────────────────────
local function showOrderCutscene(payload)
    -- Destroy any existing modal first
    local existing = posGui:FindFirstChild("OrderModal")
    if existing then existing:Destroy() end

    posGui.Enabled = true

    -- ── Backdrop ──
    local modal = Instance.new("Frame")
    modal.Name                    = "OrderModal"
    modal.Size                    = UDim2.new(0, 420, 0, 290)
    modal.Position                = UDim2.new(0.5, -210, 0.5, -145)
    modal.BackgroundColor3        = Color3.fromRGB(18, 18, 18)
    modal.BackgroundTransparency  = 0.08
    modal.BorderSizePixel         = 0
    modal.Parent                  = posGui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 14)
    corner.Parent       = modal

    -- ── Speech bubble ──
    local bubble = Instance.new("TextLabel")
    bubble.Name                   = "SpeechBubble"
    bubble.Size                   = UDim2.new(1, -20, 0, 90)
    bubble.Position               = UDim2.new(0, 10, 0, 14)
    bubble.BackgroundColor3       = Color3.fromRGB(255, 255, 255)
    bubble.BackgroundTransparency = 0.05
    bubble.TextColor3             = Color3.fromRGB(20, 20, 20)
    bubble.TextScaled             = true
    bubble.Font                   = Enum.Font.Gotham
    bubble.Text                   = string.format(
        '"%s says: I\'d like %d× %s, please!"',
        payload.npcName, payload.packSize, payload.cookieName)
    bubble.TextWrapped            = true
    bubble.Parent                 = modal
    local bc = Instance.new("UICorner")
    bc.CornerRadius = UDim.new(0, 8)
    bc.Parent       = bubble

    -- ── Earnings card ──
    local earningsLines = {
        string.format("Base:  %d coins", payload.baseCoins),
    }
    if payload.isVIP then
        table.insert(earningsLines, "VIP Bonus:  × 1.75")
        table.insert(earningsLines, string.format(
            "Potential:  %d coins", math.floor(payload.baseCoins * 1.75)))
    end

    local earnings = Instance.new("TextLabel")
    earnings.Name                   = "EarningsCard"
    earnings.Size                   = UDim2.new(1, -20, 0, 100)
    earnings.Position               = UDim2.new(0, 10, 0, 114)
    earnings.BackgroundColor3       = payload.isVIP
        and Color3.fromRGB(255, 200, 0)
        or  Color3.fromRGB(50, 50, 50)
    earnings.BackgroundTransparency = 0.1
    earnings.TextColor3             = payload.isVIP
        and Color3.fromRGB(20, 20, 20)
        or  Color3.fromRGB(255, 255, 255)
    earnings.TextScaled             = true
    earnings.Font                   = Enum.Font.GothamBold
    earnings.Text                   = table.concat(earningsLines, "\n")
    earnings.TextWrapped            = true
    earnings.Parent                 = modal
    local ec = Instance.new("UICorner")
    ec.CornerRadius = UDim.new(0, 8)
    ec.Parent       = earnings

    -- ── Countdown label ──
    local countdown = Instance.new("TextLabel")
    countdown.Name                   = "Countdown"
    countdown.Size                   = UDim2.new(1, -80, 0, 26)
    countdown.Position               = UDim2.new(0, 10, 1, -34)
    countdown.BackgroundTransparency = 1
    countdown.TextColor3             = Color3.fromRGB(140, 140, 140)
    countdown.TextXAlignment         = Enum.TextXAlignment.Left
    countdown.TextScaled             = true
    countdown.Font                   = Enum.Font.Gotham
    countdown.Text                   = "Auto-dismissing in 5..."
    countdown.Parent                 = modal

    -- ── X button ──
    local closeBtn = Instance.new("TextButton")
    closeBtn.Name              = "CloseBtn"
    closeBtn.Size              = UDim2.new(0, 30, 0, 30)
    closeBtn.Position          = UDim2.new(1, -38, 0, 8)
    closeBtn.BackgroundColor3  = Color3.fromRGB(200, 55, 55)
    closeBtn.TextColor3        = Color3.fromRGB(255, 255, 255)
    closeBtn.Font              = Enum.Font.GothamBold
    closeBtn.TextScaled        = true
    closeBtn.Text              = "✕"
    closeBtn.BorderSizePixel   = 0
    closeBtn.Parent            = modal
    local cc = Instance.new("UICorner")
    cc.CornerRadius = UDim.new(0, 6)
    cc.Parent       = closeBtn

    -- ── Dismiss (fires once only) ──
    local dismissed = false
    local function dismiss()
        if dismissed then return end
        dismissed = true
        confirmRemote:FireServer(payload.npcId)
        modal:Destroy()
        posGui.Enabled = false
    end

    closeBtn.MouseButton1Click:Connect(dismiss)

    -- ── 5-second auto-dismiss ──
    task.spawn(function()
        for i = 4, 0, -1 do
            task.wait(1)
            if dismissed then return end
            countdown.Text = i > 0
                and ("Auto-dismissing in " .. i .. "...")
                or  "Dismissing..."
        end
        dismiss()
    end)
end

-- ─── REMOTE LISTENERS ─────────────────────────────────────────────────────────
cutsceneRemote.OnClientEvent:Connect(function(payload)
    showOrderCutscene(payload)
end)

stateRemote.OnClientEvent:Connect(function(state)
    if state ~= "Open" then
        local modal = posGui:FindFirstChild("OrderModal")
        if modal then modal:Destroy() end
        posGui.Enabled = false
    end
end)

-- Escape key closes modal
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.Escape then
        local modal = posGui:FindFirstChild("OrderModal")
        if modal then
            -- Find and trigger dismiss via CloseBtn
            local btn = modal:FindFirstChild("CloseBtn")
            if btn then btn.MouseButton1Click:Fire() end
        end
    end
end)

print("[POSClient] Ready.")
```

**Step 2: Sync to Studio via MCP `run_code`**

Use MCP `run_code` to set `StarterGui.POSGui.POSClient.Source` to the new file contents.

**Step 3: Verify script loaded cleanly**

Play the game. Check console for:
- `[POSClient] Ready.` — no errors

**Step 4: Commit**
```bash
git add src/StarterGui/POSGui/POSClient.client.lua
git commit -m "feat: POSClient rewritten as order cutscene modal"
```

---

## Task 4: Full playtest + sync

**Step 1: Sync both scripts to Studio**

For each script, use MCP `run_code` to push the file contents to the Studio Script's `.Source` property:

```lua
-- PersistentNPCSpawner sync
local script = game:GetService("ServerScriptService").Core:FindFirstChild("PersistentNPCSpawner")
-- set script.Source = [full file contents]

-- POSClient sync
local posClient = game:GetService("StarterGui").POSGui:FindFirstChild("POSClient")
-- set posClient.Source = [full file contents]
```

**Step 2: Manual playtest checklist**

Play the game. Wait for game state = PreOpen or set SPAWN_STATES to `{"Lobby"}` temporarily.

| # | Action | Expected |
|---|--------|----------|
| 1 | NPC walks to POS, waits | NPC has E-prompt on head |
| 2 | Player presses E on NPC | Modal appears: speech bubble + cookie + earnings |
| 3 | Check VIP NPC modal | Shows "VIP Bonus: × 1.75" row + gold background |
| 4 | Click X button | Modal closes, NPC walks to waiting area |
| 5 | Wait 5 seconds without clicking | Countdown ticks, auto-dismisses |
| 6 | After dismiss | HUD ActiveOrderLabel shows "Cookie Name ×N" |
| 7 | Press Escape with modal open | Modal closes |
| 8 | Player disconnects mid-cutscene | NPC auto-confirms and moves to seat (check console) |

**Step 3: Final commit**
```bash
git add .
git commit -m "feat: M3 Step 2 - POS order cutscene complete"
```

---

## Notes for Implementer

- `hudUpdate:FireClient(player, coins, xp, activeOrderName)` — pass `nil` for coins/xp to skip those updates, only third arg (activeOrderName) updates the order label
- `calcPrice` is already defined in PersistentNPCSpawner — no import needed
- `data.isVIP` is set at NPC spawn time (boolean) — use it directly in the payload
- The `posGui` ScreenGui was created via MCP in a previous session — it exists in `StarterGui/POSGui`
- Do NOT touch `HUDController.client.lua` — it already handles `HUDUpdate` events correctly
- Do NOT touch `OrderManager.lua` — `AddNPCOrder` API is unchanged, just called from `confirmOrder` instead of `takeOrder`
