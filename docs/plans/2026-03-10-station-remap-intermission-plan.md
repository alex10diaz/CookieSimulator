# Station Remap + Intermission Phase Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** When the menu is confirmed, remap warmers/fridges to the 6 selected cookies; add a 5-minute Intermission phase after EndOfDay where players teleport to the back room.

**Architecture:** Station remap fires server-side when Open starts (MenuLocked moment), updating CookieId attributes + display labels on the 6 warmer and fridge models. Intermission is a new state in GameStateManager's `runCycle()` loop with player teleport in/out. All back room features subscribe to the Intermission state via the existing `OnState` pattern — GameStateManager stays thin.

**Tech Stack:** Roblox Lua, MCP run_code for Studio pushes, existing RemoteManager/MenuManager/CookieData modules.

---

## Context & Key Facts

- Warmers: `workspace.Warmers` folder, 6 models, each has `WarmerId` (1–6) + `CookieId` attributes, `Shell` Part, `DoorPanel` Part, `TextLabel` inside `WarmersDisplay` SurfaceGui
- Fridges: `workspace.Fridges` folder, 6 models with `FridgeId` attribute, `FridgeDisplay` BillboardGui → `CookieName` TextLabel
- GameStateManager: `runCycle()` → PreOpen → Open → EndOfDay (30s) → recurse. Change to add Intermission before recurse.
- HUDController: `STATE_LABELS` table + `stateRemote.OnClientEvent` in `StarterGui/HUD/HUDController`
- Front spawn: `workspace.SpawnLocation` at (55, 0.5, 31)
- Back room center: ~(0, 2, -127), clear of leaderboard (X=-25) and shop wall (X=+25)
- MenuServer: listens to `workspace:GetAttributeChangedSignal("GameState")` — remap fires here on `"Open"`
- All disk changes must be pushed to Studio via MCP `run_code` after writing

---

## Task 1: Add `StationRemapped` remote to RemoteManager

**Files:**
- Modify: `src/ReplicatedStorage/Modules/RemoteManager.lua`

**Step 1: Edit disk file**

In `RemoteManager.lua`, add after the `PurchaseCookieResult` line:
```lua
    -- Station remap
    "StationRemapped",  -- Server→All: {slot→cookieId} map after menu locks
```

**Step 2: Push to Studio + create the remote**

```lua
-- MCP run_code
local src = game:GetService("ReplicatedStorage").Modules.RemoteManager
src.Source = src.Source:gsub(
    '"PurchaseCookieResult", %-%- Server.*\n}',
    '"PurchaseCookieResult", -- Server->Client: ok/fail + newCoins + cookieId\n    "StationRemapped",  -- Server->All: slot->cookieId map after menu locks\n}'
)
-- Also create the remote now
local ge = game:GetService("ReplicatedStorage").GameEvents
if not ge:FindFirstChild("StationRemapped") then
    local r = Instance.new("RemoteEvent")
    r.Name = "StationRemapped"
    r.Parent = ge
end
print("StationRemapped remote created:", ge:FindFirstChild("StationRemapped") ~= nil)
```

**Step 3: Verify**
```lua
print(game:GetService("ReplicatedStorage").GameEvents:FindFirstChild("StationRemapped").ClassName)
-- Expected: RemoteEvent
```

**Step 4: Commit**
```
git add src/ReplicatedStorage/Modules/RemoteManager.lua
git commit -m "feat: add StationRemapped remote"
```

---

## Task 2: Create StationRemapService

**Files:**
- Create: `src/ServerScriptService/Core/StationRemapService.lua`

**Step 1: Write the module to disk**

```lua
-- StationRemapService (ModuleScript, ServerScriptService/Core)
-- Remaps the 6 physical warmer and fridge models to match the active menu.
-- Call RemapStations(orderedMenuIds) once per shift at Open start.
-- orderedMenuIds: array of up to 6 cookieId strings, in slot order.

local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local Workspace           = game:GetService("Workspace")

local CookieData    = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CookieData"))
local RemoteManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))

local stationRemappedRemote = RemoteManager.Get("StationRemapped")

local StationRemapService = {}

-- Sort warmer models by WarmerId attribute (1-6)
local function getSortedWarmers()
    local folder = Workspace:FindFirstChild("Warmers")
    if not folder then return {} end
    local list = {}
    for _, model in ipairs(folder:GetChildren()) do
        local id = model:GetAttribute("WarmerId")
        if id then table.insert(list, { model = model, slot = id }) end
    end
    table.sort(list, function(a, b) return a.slot < b.slot end)
    return list
end

-- Sort fridge models by current FridgeId alphabetically for stable ordering
local function getSortedFridges()
    local folder = Workspace:FindFirstChild("Fridges")
    if not folder then return {} end
    local list = {}
    for _, model in ipairs(folder:GetChildren()) do
        local fridgeId = model:GetAttribute("FridgeId")
        if fridgeId and fridgeId ~= "" then
            table.insert(list, { model = model, fridgeId = fridgeId })
        end
    end
    table.sort(list, function(a, b) return a.fridgeId < b.fridgeId end)
    return list
end

function StationRemapService.RemapStations(orderedMenuIds)
    if not orderedMenuIds or #orderedMenuIds == 0 then
        warn("[StationRemapService] No menu ids provided — skipping remap")
        return
    end

    local warmers = getSortedWarmers()
    local fridges = getSortedFridges()
    local slotMap = {}  -- slot index -> cookieId (for remote broadcast)

    for slotIndex, cookieId in ipairs(orderedMenuIds) do
        local cookie = CookieData.GetById(cookieId)
        if not cookie then
            warn("[StationRemapService] Unknown cookieId:", cookieId)
            continue
        end

        slotMap[slotIndex] = cookieId

        -- ── Remap warmer ─────────────────────────────────────────
        local warmerEntry = warmers[slotIndex]
        if warmerEntry then
            local model = warmerEntry.model
            model:SetAttribute("CookieId", cookieId)

            -- Update name label inside WarmersDisplay SurfaceGui on DoorPanel
            local doorPanel = model:FindFirstChild("DoorPanel")
            if doorPanel then
                local sg = doorPanel:FindFirstChild("WarmersDisplay")
                if sg then
                    local lbl = sg:FindFirstChild("TextLabel")
                    if lbl then lbl.Text = cookie.name end
                end
                -- Accent color from cookie's dough color
                doorPanel.Color = cookie.doughColor
            end
        end

        -- ── Remap fridge ─────────────────────────────────────────
        local fridgeEntry = fridges[slotIndex]
        if fridgeEntry then
            local model = fridgeEntry.model
            model:SetAttribute("FridgeId", cookie.fridgeId)

            local display = model:FindFirstChild("FridgeDisplay", true)
            if display then
                local nameLbl = display:FindFirstChild("CookieName")
                if nameLbl then nameLbl.Text = cookie.name end
            end
        end
    end

    -- Broadcast to all clients
    stationRemappedRemote:FireAllClients(slotMap)
    print("[StationRemapService] Remapped", #orderedMenuIds, "stations")
end

return StationRemapService
```

**Step 2: Push to Studio via MCP**

```lua
-- MCP run_code
local core = game:GetService("ServerScriptService"):WaitForChild("Core")
local existing = core:FindFirstChild("StationRemapService")
if existing then existing:Destroy() end
local ms = Instance.new("ModuleScript")
ms.Name = "StationRemapService"
ms.Parent = core
ms.Source = [==[  -- paste full source above  ]==]
print("StationRemapService created:", core:FindFirstChild("StationRemapService") ~= nil)
```

**Step 3: Verify via MCP**

```lua
-- MCP run_code — quick require test (server context)
local ok, result = pcall(function()
    return require(game:GetService("ServerScriptService").Core.StationRemapService)
end)
print("Require ok:", ok, type(result))
-- Expected: Require ok: true  table
```

**Step 4: Commit**
```
git add src/ServerScriptService/Core/StationRemapService.lua
git commit -m "feat: add StationRemapService for warmer/fridge remap"
```

---

## Task 3: Wire remap into MenuServer on Open start

**Files:**
- Modify: `src/ServerScriptService/Core/MenuServer.server.lua`

**Step 1: Add require + remap call to MenuServer disk file**

Add near top requires:
```lua
local StationRemapService = require(ServerScriptService:WaitForChild("Core"):WaitForChild("StationRemapService"))
```

In the `GameState` attribute listener, add remap call inside the `"Open"` branch:
```lua
elseif state == "Open" then
    MenuManager.LockMenu()
    sendMenuLocked()
    -- Remap warmers/fridges to the confirmed active menu
    StationRemapService.RemapStations(MenuManager.GetActiveMenu())
end
```

**Step 2: Push full MenuServer to Studio via MCP**

Use `run_code` to set `MenuServer.Source` to the updated content (same pattern as prior pushes).

**Step 3: Verify via MCP (simulate)**

```lua
-- MCP run_code — manually trigger remap with a test menu
local srs = require(game:GetService("ServerScriptService").Core.StationRemapService)
srs.RemapStations({"chocolate_chip","snickerdoodle","pink_sugar","birthday_cake","cookies_and_cream","lemon_blackraspberry"})
-- Then check:
local warmers = workspace.Warmers:GetChildren()
for _, w in ipairs(warmers) do
    print(w.Name, "CookieId:", w:GetAttribute("CookieId"))
end
-- Expected: CookieIds match the 6 test cookies in WarmerId order
```

**Step 4: Check fridge labels updated**

```lua
-- MCP run_code
for _, f in ipairs(workspace.Fridges:GetChildren()) do
    local d = f:FindFirstChild("FridgeDisplay", true)
    if d then
        local lbl = d:FindFirstChild("CookieName")
        print(f.Name, "->", lbl and lbl.Text or "no label")
    end
end
```

**Step 5: Commit**
```
git add src/ServerScriptService/Core/MenuServer.server.lua
git commit -m "feat: trigger station remap when Open phase starts"
```

---

## Task 4: Create back room SpawnLocation via MCP

**Step 1: Create SpawnLocation in Studio**

```lua
-- MCP run_code
local existing = workspace:FindFirstChild("BackRoomSpawn")
if existing then existing:Destroy() end

local sp = Instance.new("SpawnLocation")
sp.Name = "BackRoomSpawn"
sp.Size = Vector3.new(6, 1, 6)
sp.CFrame = CFrame.new(0, 2, -127)
sp.BrickColor = BrickColor.new("Bright orange")
sp.Transparency = 0.5
sp.Neutral = true
sp.AllowTeamChangeOnTouch = false
sp.Duration = 0
sp.Parent = workspace
print("BackRoomSpawn created at", sp.Position)
-- Expected: BackRoomSpawn created at  0, 2, -127
```

**Step 2: Verify placement looks correct** — visually confirm it's in the back room center, not blocking leaderboard or right wall.

**Note:** No disk file needed — SpawnLocation is a workspace object. Document its position in MEMORY.md.

---

## Task 5: Add Intermission phase to GameStateManager

**Files:**
- Modify: `src/ServerScriptService/Core/GameStateManager.server.lua`

**Step 1: Edit disk file**

Add constant near top:
```lua
local INTERMISSION_DURATION = 5 * 60  -- 5 minutes break between shifts
```

Add teleport helpers after the `broadcast` function:

```lua
-- Teleport all player characters to a CFrame position
local function teleportAllTo(targetCFrame)
    for _, player in ipairs(Players:GetPlayers()) do
        local char = player.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.CFrame = targetCFrame + Vector3.new(
                    math.random(-3, 3), 0, math.random(-3, 3)
                )
            end
        end
    end
end

local BACK_ROOM_CFrame  = CFrame.new(0, 3, -127)
local FRONT_SPAWN_CFrame = CFrame.new(55, 2, 31)
```

Replace `runCycle()` body to add Intermission:
```lua
local function runCycle()
    SessionStats.Reset()
    if not DEV_SKIP_PREOPEN then
        runPhase(PREOPEN_DURATION, "PreOpen")
    end
    runPhase(OPEN_DURATION, "Open")

    -- End of day summary
    broadcast("EndOfDay", SUMMARY_DURATION)
    summaryRemote:FireAllClients(SessionStats.GetSummary())
    task.wait(SUMMARY_DURATION)

    -- Intermission — teleport to back room
    teleportAllTo(BACK_ROOM_CFrame)
    runPhase(INTERMISSION_DURATION, "Intermission")

    -- Return players to front for next shift
    teleportAllTo(FRONT_SPAWN_CFrame)

    runCycle()
end
```

**Step 2: Push to Studio via MCP**

Full source replacement via `run_code` (same pattern as prior pushes).

**Step 3: Verify constants loaded**

```lua
-- MCP run_code
local gsm = game:GetService("ServerScriptService"):FindFirstChild("GameStateManager", true)
print(gsm.Source:find("INTERMISSION_DURATION", 1, true) ~= nil)  -- true
print(gsm.Source:find("BackRoomSpawn", 1, true) or gsm.Source:find("BACK_ROOM", 1, true))  -- line number
```

**Step 4: Commit**
```
git add src/ServerScriptService/Core/GameStateManager.server.lua
git commit -m "feat: add Intermission phase with back room teleport"
```

---

## Task 6: Update HUDController for Intermission state

**Files:**
- Modify: `src/StarterGui/HUD/HUDController.client.lua` (disk file path — check exact location)

**Step 1: Add Intermission to STATE_LABELS**

In `HUDController`, find:
```lua
local STATE_LABELS = {
    PreOpen  = "PRE-OPEN",
    Open     = "OPEN",
    EndOfDay = "END OF DAY",
    Lobby    = "LOBBY",
}
```

Add:
```lua
    Intermission = "BREAK TIME",
```

**Step 2: Update timerLbl color for Intermission**

In the `stateRemote.OnClientEvent` handler, the background color line:
```lua
timerLbl.BackgroundColor3 = state == "Open"
    and Color3.fromRGB(60, 140, 60)
    or  Color3.fromRGB(30, 30, 30)
```

Change to:
```lua
timerLbl.BackgroundColor3 = state == "Open"
    and Color3.fromRGB(60, 140, 60)
    or state == "Intermission"
    and Color3.fromRGB(50, 100, 160)  -- blue for break time
    or  Color3.fromRGB(30, 30, 30)
```

**Step 3: Push to Studio via MCP**

```lua
-- MCP run_code
local hud = game:GetService("StarterGui").HUD.HUDController
hud.Source = hud.Source
    :gsub("    Lobby    = \"LOBBY\",", "    Lobby    = \"LOBBY\",\n    Intermission = \"BREAK TIME\",")
    :gsub(
        'timerLbl%.BackgroundColor3 = state == "Open"\n        and Color3%.fromRGB%(60, 140, 60%)\n        or  Color3%.fromRGB%(30, 30, 30%)',
        'timerLbl.BackgroundColor3 = state == "Open" and Color3.fromRGB(60,140,60) or state == "Intermission" and Color3.fromRGB(50,100,160) or Color3.fromRGB(30,30,30)'
    )
print("Intermission label:", hud.Source:find("BREAK TIME", 1, true) ~= nil)
```

**Step 4: Verify in Studio play test**

Start play mode, wait for Intermission state to fire (or manually set `workspace:SetAttribute("GameState","Intermission")` via run_code), confirm:
- Timer shows "BREAK TIME  5:00"
- Timer background turns blue

**Step 5: Commit**
```
git add src/StarterGui/HUD/HUDController.client.lua
git commit -m "feat: show BREAK TIME in HUD during Intermission state"
```

---

## Task 7: End-to-end manual test

**Shorten durations for testing via MCP:**

```lua
local gsm = game:GetService("ServerScriptService"):FindFirstChild("GameStateManager", true)
gsm.Source = gsm.Source
    :gsub("PREOPEN_DURATION = 20", "PREOPEN_DURATION = 10")
    :gsub("OPEN_DURATION     = 10 %* 60", "OPEN_DURATION = 15")
    :gsub("SUMMARY_DURATION  = 30", "SUMMARY_DURATION = 5")
    :gsub("INTERMISSION_DURATION = 5 %* 60", "INTERMISSION_DURATION = 20")
print("Test durations set")
```

**Test checklist:**
1. Start play → PreOpen fires → Menu board opens
2. Select 6 cookies → click "Set Menu" → fade to black → board closes
3. Open fires → `StationRemapped` fires → check warmers have new CookieId attrs + correct label text
4. Check fridge labels updated to match selected menu
5. Open phase ends → EndOfDay shows summary → Intermission fires → player teleports to back room
6. HUD shows "BREAK TIME  0:20" in blue
7. Intermission ends → player teleports back to front → PreOpen fires again
8. Menu board opens with same ownedCookies → player can pick different 6 for next shift

**After testing, restore production durations:**
```lua
-- MCP run_code to restore production values
```

---

## Update MEMORY.md

After all tasks complete, update `MEMORY.md`:
- BackRoomSpawn at (0, 2, -127)
- Intermission state added: EndOfDay → Intermission (5min) → PreOpen
- StationRemapService: remaps warmers/fridges on Open start using active menu order
