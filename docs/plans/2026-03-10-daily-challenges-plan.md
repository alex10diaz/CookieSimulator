# Daily Challenges Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Add 3 daily challenges (reset at midnight UTC) with mixed types, coin rewards, a back room board, and a HUD widget.

**Architecture:** `DailyChallengeManager` (server module) holds the 12-challenge catalog, picks 3 per day via deterministic seed, tracks per-player progress in-memory and stores claimed state in PlayerDataManager profile. `DailyChallengeServer` wires PlayerAdded and delivery hooks. `DailyChallengeClient` renders the back room board (SurfaceGui) and a compact HUD widget during Open phase.

**Tech Stack:** Roblox Lua, MCP run_code for all Studio pushes (Rojo is NOT used — every disk change must also be pushed via MCP).

---

## Context

- **Delivery happens in:** `src/ServerScriptService/Core/PersistentNPCSpawner.server.lua` around line 527 — fires `deliveryResult:FireClient(player, stars, coins, xp)`. Data available at that point: `stars`, `d.order.cookieId`, `payout.coins`, `comboStreak`, `d.order.packSize`.
- **PlayerDataManager** uses raw DataStore (`PlayerData_v1`). `GetData(player)` returns a live profile table reference — mutations persist on PlayerRemoving save. Functions available: `AddCoins(player, amount)`, `GetData(player)`, `RecordOrderComplete`.
- **RemoteManager** is at `src/ReplicatedStorage/Modules/RemoteManager.lua`. All remotes must be added to the `REMOTES` table. Server creates them; clients WaitForChild.
- **Back room board location:** Part at `(25, 8, -157)`, face = Front (toward -Z, into the room). Players see it during Intermission.
- **MCP gotchas:** Never pass booleans directly in `print()` — convert to `"YES"/"NO"` string. Never leave duplicate ModuleScripts with the same name — destroy before recreating.
- **MCP source injection pattern:** Use `table.concat(lines, "\n")` to build source strings for long scripts (avoids `[[...]]` bracket conflicts).

---

## Task 1: Add 2 new remotes to RemoteManager

**Files:**
- Modify: `src/ReplicatedStorage/Modules/RemoteManager.lua`

**Step 1: Edit disk file**

In `RemoteManager.lua`, find the line `"StationRemapped",` and add after it:
```lua
    -- Daily challenges
    "DailyChallengesInit",    -- Server→Client: send today's challenges + progress on join
    "DailyChallengeProgress", -- Server→Client: incremental progress update after each delivery
```

**Step 2: Push to Studio + create the remotes**

```lua
-- MCP run_code
local src = game:GetService("ReplicatedStorage").Modules.RemoteManager
src.Source = src.Source:gsub(
    '"StationRemapped",  %-%- Server%->All: slot%->cookieId map after menu locks',
    '"StationRemapped",  -- Server->All: slot->cookieId map after menu locks\n    -- Daily challenges\n    "DailyChallengesInit",    -- Server->Client: send today\'s challenges + progress on join\n    "DailyChallengeProgress", -- Server->Client: incremental progress update after each delivery'
)
local ge = game:GetService("ReplicatedStorage"):WaitForChild("GameEvents")
for _, name in ipairs({"DailyChallengesInit", "DailyChallengeProgress"}) do
    if not ge:FindFirstChild(name) then
        local r = Instance.new("RemoteEvent")
        r.Name = name
        r.Parent = ge
    end
end
local a = ge:FindFirstChild("DailyChallengesInit") and "YES" or "NO"
local b = ge:FindFirstChild("DailyChallengeProgress") and "YES" or "NO"
print("DailyChallengesInit:", a, "DailyChallengeProgress:", b)
-- Expected: DailyChallengesInit: YES  DailyChallengeProgress: YES
```

**Step 3: Verify disk change**
```
grep -n "DailyChallengesInit" src/ReplicatedStorage/Modules/RemoteManager.lua
-- Expected: line showing the new remote name
```

**Step 4: Commit**
```bash
git add src/ReplicatedStorage/Modules/RemoteManager.lua
git commit -m "feat: add DailyChallengesInit and DailyChallengeProgress remotes"
```

---

## Task 2: Add `dailyChallenges` default field to PlayerDataManager

**Files:**
- Modify: `src/ServerScriptService/Core/PlayerDataManager.lua`

**Step 1: Read the file to find DEFAULT_PROFILE location**

Read `src/ServerScriptService/Core/PlayerDataManager.lua`. Find the `DEFAULT_PROFILE` or `defaultData` table. It ends around the `bakeryLevel = 1` line.

**Step 2: Add dailyChallenges field to DEFAULT_PROFILE on disk**

After the last field in DEFAULT_PROFILE (e.g., `bakeryLevel = 1,`), add:
```lua
    dailyChallenges = {
        date    = "",            -- "YYYY-DDD" UTC date key, e.g. "2026-069"
        progress = {0, 0, 0},   -- progress values for each of the 3 challenges
        claimed  = {false, false, false},  -- whether reward was claimed
    },
```

**Step 3: Push change to Studio via MCP**

```lua
-- MCP run_code
-- Find the script in SSS
local pdm = game:GetService("ServerScriptService"):FindFirstChild("PlayerDataManager", true)
-- Use gsub to insert after bakeryLevel line
pdm.Source = pdm.Source:gsub(
    '    bakeryLevel%s+= 1,\n}',
    '    bakeryLevel    = 1,\n    dailyChallenges = {\n        date     = "",\n        progress = {0, 0, 0},\n        claimed  = {false, false, false},\n    },\n}'
)
local found = pdm.Source:find("dailyChallenges", 1, true) and "YES" or "NO"
print("dailyChallenges in PlayerDataManager:", found)
-- Expected: YES
```

**Step 4: Commit**
```bash
git add src/ServerScriptService/Core/PlayerDataManager.lua
git commit -m "feat: add dailyChallenges field to PlayerDataManager profile"
```

---

## Task 3: Create DailyChallengeManager.lua

**Files:**
- Create: `src/ServerScriptService/Core/DailyChallengeManager.lua`

**Step 1: Write the module to disk**

```lua
-- src/ServerScriptService/Core/DailyChallengeManager.lua
-- Manages daily challenge catalog, per-player progress, and reward delivery.
-- Challenges reset at midnight UTC. 3 challenges per day: one Easy, Medium, Hard.

local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RemoteManager     = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))
local CookieData        = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CookieData"))
local MenuManager       = require(ServerScriptService:WaitForChild("Core"):WaitForChild("MenuManager"))
local PlayerDataManager = require(ServerScriptService:WaitForChild("Core"):WaitForChild("PlayerDataManager"))

local initRemote     = RemoteManager.Get("DailyChallengesInit")
local progressRemote = RemoteManager.Get("DailyChallengeProgress")

-- ─── Challenge Catalog ──────────────────────────────────────────────────────
-- type values: "orders" | "fiveStars" | "combo" | "shiftCoins" | "totalBaked" | "cookieType" | "uniqueTypes"
-- cookieType challenges use labelTemplate with %s = cookie name, resolved at runtime from active menu.

local EASY = {
    { id="complete_orders_5",  type="orders",     label="Complete 5 orders today",      goal=5,   reward=150, tier="Easy" },
    { id="five_stars_4",       type="fiveStars",  label="Earn 4 five-star orders",       goal=4,   reward=150, tier="Easy" },
    { id="combo_3",            type="combo",      label="Hit a combo streak of 3",        goal=3,   reward=150, tier="Easy" },
    { id="cookie_type_8",      type="cookieType", labelTemplate="Bake 8 %s cookies",     goal=8,   reward=150, tier="Easy" },
}

local MEDIUM = {
    { id="complete_orders_12", type="orders",      label="Complete 12 orders today",     goal=12,  reward=300, tier="Medium" },
    { id="five_stars_6",       type="fiveStars",   label="Earn 6 five-star orders",      goal=6,   reward=300, tier="Medium" },
    { id="shift_coins_500",    type="shiftCoins",  label="Earn 500 coins in one shift",  goal=500, reward=300, tier="Medium" },
    { id="unique_types_3",     type="uniqueTypes", label="Bake 3 different cookie types", goal=3,  reward=300, tier="Medium" },
}

local HARD = {
    { id="complete_orders_20", type="orders",     label="Complete 20 orders today",      goal=20,  reward=500, tier="Hard" },
    { id="five_stars_10",      type="fiveStars",  label="Earn 10 five-star orders",      goal=10,  reward=500, tier="Hard" },
    { id="combo_6",            type="combo",      label="Hit a combo streak of 6",        goal=6,   reward=500, tier="Hard" },
    { id="total_baked_15",     type="totalBaked", label="Bake 15 cookies total",         goal=15,  reward=500, tier="Hard" },
}

-- ─── State ──────────────────────────────────────────────────────────────────
-- Per-player in-memory counters (non-persistent, reset on server restart).
-- Persistent state (progress, claimed) lives in PlayerDataManager profile.
local playerStats = {}
-- playerStats[userId] = {
--   orders=0, fiveStars=0, peakCombo=0,
--   shiftCoins=0, totalBaked=0,
--   cookieCounts={[cookieId]=count}, uniqueTypeSet={[cookieId]=true}
-- }

local cachedChallenges = nil
local cachedSeed       = nil

-- ─── Helpers ────────────────────────────────────────────────────────────────
local function getTodayKey()
    local t = os.date("!*t")
    return t.year .. "-" .. string.format("%03d", t.yday)
end

local function getTodaySeed()
    local t = os.date("!*t")
    return t.year * 1000 + t.yday
end

local function resolveCookieType(template, seed)
    local menu = MenuManager.GetActiveMenu()
    local cookieId = "chocolate_chip"  -- safe fallback
    if menu and #menu > 0 then
        local idx = (math.floor(seed / 3) % #menu) + 1
        cookieId = menu[idx]
    end
    local ck = CookieData.GetById(cookieId)
    local name = ck and ck.name or cookieId
    return {
        id            = template.id,
        type          = template.type,
        tier          = template.tier,
        label         = string.format(template.labelTemplate, name),
        goal          = template.goal,
        reward        = template.reward,
        param         = cookieId,
    }
end

local function ensureStats(userId)
    if not playerStats[userId] then
        playerStats[userId] = {
            orders        = 0,
            fiveStars     = 0,
            peakCombo     = 0,
            shiftCoins    = 0,
            totalBaked    = 0,
            cookieCounts  = {},
            uniqueTypeSet = {},
        }
    end
    return playerStats[userId]
end

local function countKeys(t)
    local n = 0
    for _ in pairs(t) do n += 1 end
    return n
end

-- ─── Public API ─────────────────────────────────────────────────────────────
local M = {}

-- Returns today's 3 challenges (cached per UTC day). Call after menu locks to
-- ensure cookieType param reflects the active menu.
function M.GetTodayChallenges()
    local seed = getTodaySeed()
    if cachedSeed == seed and cachedChallenges then
        return cachedChallenges
    end
    local eIdx = (seed % #EASY) + 1
    local mIdx = (math.floor(seed / 7)  % #MEDIUM) + 1
    local hIdx = (math.floor(seed / 13) % #HARD)   + 1

    local function resolve(template)
        if template.type == "cookieType" then
            return resolveCookieType(template, seed)
        end
        return template
    end

    cachedChallenges = {
        resolve(EASY[eIdx]),
        resolve(MEDIUM[mIdx]),
        resolve(HARD[hIdx]),
    }
    cachedSeed = seed
    return cachedChallenges
end

-- Call when menu locks (Open phase) so cookieType challenge re-resolves with confirmed menu.
function M.InvalidateChallengeCache()
    cachedChallenges = nil
    cachedSeed       = nil
end

-- Called on player join. Wipes progress if UTC date has changed.
function M.ResetIfNeeded(player)
    local profile = PlayerDataManager.GetData(player)
    if not profile then return end
    if not profile.dailyChallenges then
        profile.dailyChallenges = { date="", progress={0,0,0}, claimed={false,false,false} }
    end
    local dc = profile.dailyChallenges
    if dc.date ~= getTodayKey() then
        dc.date     = getTodayKey()
        dc.progress = {0, 0, 0}
        dc.claimed  = {false, false, false}
    end
    ensureStats(player.UserId)
end

-- Sends today's challenge state to the client.
function M.SendToPlayer(player)
    local profile = PlayerDataManager.GetData(player)
    if not profile or not profile.dailyChallenges then return end
    local dc = profile.dailyChallenges
    local t  = os.date("!*t")
    local resetIn = (23 - t.hour) * 3600 + (59 - t.min) * 60 + (60 - t.sec)
    initRemote:FireClient(player, {
        challenges = M.GetTodayChallenges(),
        progress   = dc.progress,
        claimed    = dc.claimed,
        resetIn    = resetIn,
    })
end

-- Reset per-shift coin counter. Call at the start of each Open phase.
function M.ResetShiftCounters(player)
    local uid = player.UserId
    if playerStats[uid] then
        playerStats[uid].shiftCoins = 0
    end
end

-- Called after each delivery. data = { stars, cookieId, coins, comboStreak, packSize }
function M.RecordDelivery(player, data)
    local profile = PlayerDataManager.GetData(player)
    if not profile or not profile.dailyChallenges then return end
    local dc         = profile.dailyChallenges
    local stats      = ensureStats(player.UserId)
    local challenges = M.GetTodayChallenges()

    -- Update live counters
    stats.orders    += 1
    if (data.stars or 0) >= 5 then stats.fiveStars += 1 end
    stats.peakCombo  = math.max(stats.peakCombo, data.comboStreak or 0)
    stats.shiftCoins += (data.coins or 0)
    stats.totalBaked += (data.packSize or 1)
    if data.cookieId then
        stats.cookieCounts[data.cookieId] = (stats.cookieCounts[data.cookieId] or 0) + (data.packSize or 1)
        stats.uniqueTypeSet[data.cookieId] = true
    end

    -- Evaluate each challenge
    for i, ch in ipairs(challenges) do
        if dc.claimed[i] then continue end

        local current
        if     ch.type == "orders"      then current = stats.orders
        elseif ch.type == "fiveStars"   then current = stats.fiveStars
        elseif ch.type == "combo"       then current = stats.peakCombo
        elseif ch.type == "shiftCoins"  then current = stats.shiftCoins
        elseif ch.type == "totalBaked"  then current = stats.totalBaked
        elseif ch.type == "cookieType"  then current = stats.cookieCounts[ch.param] or 0
        elseif ch.type == "uniqueTypes" then current = countKeys(stats.uniqueTypeSet)
        else current = 0
        end

        current = math.min(current, ch.goal)
        dc.progress[i] = current

        local justCompleted = (current >= ch.goal)
        if justCompleted then
            dc.claimed[i] = true
            PlayerDataManager.AddCoins(player, ch.reward)
        end

        progressRemote:FireClient(player, {
            index         = i,
            progress      = current,
            goal          = ch.goal,
            completed     = dc.claimed[i],
            justCompleted = justCompleted,
            coinsAwarded  = justCompleted and ch.reward or 0,
        })
    end
end

-- Cleanup in-memory state on player leave.
function M.Cleanup(player)
    playerStats[player.UserId] = nil
end

return M
```

**Step 2: Push to Studio via MCP**

```lua
-- MCP run_code
local core = game:GetService("ServerScriptService"):WaitForChild("Core")
local existing = core:FindFirstChild("DailyChallengeManager")
if existing then existing:Destroy() end

local ms = Instance.new("ModuleScript")
ms.Name   = "DailyChallengeManager"
ms.Parent = core

-- Paste the full source using table.concat approach:
local L = {}
-- [Paste each line of the source as a string in the table, then join]
-- See note: use the MCP string injection pattern (table.concat) for long sources.
-- The full source from Step 1 above should be assigned to ms.Source.

local found = core:FindFirstChild("DailyChallengeManager") and "YES" or "NO"
print("DailyChallengeManager created:", found)
-- Expected: YES
```

**Practical MCP injection note:** Because the source is ~120 lines, use the same table.concat pattern used for other large modules (build an array of strings line by line, then `ms.Source = table.concat(lines, "\n")`).

**Step 3: Verify with a quick require**

```lua
-- MCP run_code
local ok, result = pcall(function()
    return require(game:GetService("ServerScriptService").Core.DailyChallengeManager)
end)
local status = ok and "YES" or "NO"
print("Require ok:", status)
-- Expected: YES
```

**Step 4: Commit**
```bash
git add src/ServerScriptService/Core/DailyChallengeManager.lua
git commit -m "feat: add DailyChallengeManager with challenge catalog and progress tracking"
```

---

## Task 4: Hook delivery in PersistentNPCSpawner

**Files:**
- Modify: `src/ServerScriptService/Core/PersistentNPCSpawner.server.lua`

**Context:** The delivery handler is around line 527. After `SessionStats.RecordDelivery(...)` at line 533, we add our hook.

**Step 1: Read PersistentNPCSpawner.server.lua**

Read the file and find:
1. The top require section (to add `DailyChallengeManager` require)
2. The line `SessionStats.RecordDelivery(stars, payout.coins, comboStreak, d.order.packSize or 1)` (around line 533)

**Step 2: Add require at top of disk file**

After the existing `local SessionStats = require(...)` line, add:
```lua
local DailyChallengeManager = require(ServerScriptService:WaitForChild("Core"):WaitForChild("DailyChallengeManager"))
```

**Step 3: Add RecordDelivery call on disk**

After the `SessionStats.RecordDelivery(...)` line, add:
```lua
        DailyChallengeManager.RecordDelivery(player, {
            stars       = stars,
            cookieId    = d.order.cookieId,
            coins       = payout.coins,
            comboStreak = comboStreak,
            packSize    = d.order.packSize or 1,
        })
```

**Step 4: Push both changes to Studio via MCP**

```lua
-- MCP run_code
local sss = game:GetService("ServerScriptService")
local spawner = sss:FindFirstChild("PersistentNPCSpawner", true)

-- First check actual source to find the exact SessionStats require line text:
local requireLine = spawner.Source:match("local SessionStats = require%([^\n]+\n")
print("Found:", requireLine ~= nil and "YES" or "NO")
```

Then add the DailyChallengeManager require:
```lua
-- MCP run_code
local sss = game:GetService("ServerScriptService")
local spawner = sss:FindFirstChild("PersistentNPCSpawner", true)

-- Add require (inspect actual text first, adjust pattern to match)
spawner.Source = spawner.Source:gsub(
    "(local SessionStats = require%([^\n]+\n)",
    "%1local DailyChallengeManager = require(game:GetService(\"ServerScriptService\"):WaitForChild(\"Core\"):WaitForChild(\"DailyChallengeManager\"))\n"
)

-- Add RecordDelivery call after SessionStats.RecordDelivery call
spawner.Source = spawner.Source:gsub(
    "(        SessionStats%.RecordDelivery%([^\n]+\n)",
    '%1        DailyChallengeManager.RecordDelivery(player, {\n            stars       = stars,\n            cookieId    = d.order.cookieId,\n            coins       = payout.coins,\n            comboStreak = comboStreak,\n            packSize    = d.order.packSize or 1,\n        })\n'
)

local a = spawner.Source:find("DailyChallengeManager", 1, true) and "YES" or "NO"
print("DailyChallengeManager hook added:", a)
-- Expected: YES
```

**Step 5: Commit**
```bash
git add src/ServerScriptService/Core/PersistentNPCSpawner.server.lua
git commit -m "feat: hook DailyChallengeManager.RecordDelivery into delivery handler"
```

---

## Task 5: Create DailyChallengeServer.server.lua

**Files:**
- Create: `src/ServerScriptService/Core/DailyChallengeServer.server.lua`

**Step 1: Write the script to disk**

```lua
-- src/ServerScriptService/Core/DailyChallengeServer.server.lua
-- Wires player lifecycle and game state events into DailyChallengeManager.

local Players             = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local DailyChallengeManager = require(ServerScriptService:WaitForChild("Core"):WaitForChild("DailyChallengeManager"))

-- On join: reset if new day, then send current state to client
Players.PlayerAdded:Connect(function(player)
    task.defer(function()
        DailyChallengeManager.ResetIfNeeded(player)
        -- Brief wait for PlayerDataManager to fully load profile
        task.wait(1)
        DailyChallengeManager.SendToPlayer(player)
    end)
end)

-- On leave: clean up in-memory stats
Players.PlayerRemoving:Connect(function(player)
    DailyChallengeManager.Cleanup(player)
end)

-- On Open phase: invalidate cookieType cache (menu is now locked) + reset shift coins
workspace:GetAttributeChangedSignal("GameState"):Connect(function()
    local state = workspace:GetAttribute("GameState")
    if state == "Open" then
        DailyChallengeManager.InvalidateChallengeCache()
        for _, p in ipairs(Players:GetPlayers()) do
            DailyChallengeManager.ResetShiftCounters(p)
        end
    end
end)

print("[DailyChallengeServer] Ready.")
```

**Step 2: Push to Studio via MCP**

```lua
-- MCP run_code
local core = game:GetService("ServerScriptService"):WaitForChild("Core")
local existing = core:FindFirstChild("DailyChallengeServer")
if existing then existing:Destroy() end

local s = Instance.new("Script")
s.Name   = "DailyChallengeServer"
s.Parent = core
-- Assign full source (use table.concat pattern)
-- s.Source = <full source from Step 1>

local found = core:FindFirstChild("DailyChallengeServer") and "YES" or "NO"
print("DailyChallengeServer created:", found)
```

**Step 3: Commit**
```bash
git add src/ServerScriptService/Core/DailyChallengeServer.server.lua
git commit -m "feat: add DailyChallengeServer to wire player lifecycle and game state"
```

---

## Task 6: Create ChallengesBoard in back room (Studio only)

**No disk file** — this is a workspace Part created via MCP.

**Step 1: Create the Part and SurfaceGui**

```lua
-- MCP run_code
local existing = workspace:FindFirstChild("ChallengesBoard")
if existing then existing:Destroy() end

local part = Instance.new("Part")
part.Name         = "ChallengesBoard"
part.Size         = Vector3.new(0.3, 5, 7)
part.CFrame       = CFrame.new(25, 8, -157) * CFrame.Angles(0, math.pi, 0)
part.Anchored     = true
part.CanCollide   = false
part.Material     = Enum.Material.SmoothPlastic
part.BrickColor   = BrickColor.new("Dark stone grey")
part.Parent       = workspace

local sg = Instance.new("SurfaceGui")
sg.Name           = "ChallengesBoardGui"
sg.Face           = Enum.NormalId.Front
sg.SizingMode     = Enum.SurfaceGuiSizingMode.PixelsPerStud
sg.PixelsPerStud  = 40
sg.AlwaysOnTop    = false
sg.Parent         = part

-- Header label
local header = Instance.new("TextLabel")
header.Name               = "Header"
header.Size               = UDim2.new(1, 0, 0, 40)
header.Position           = UDim2.new(0, 0, 0, 0)
header.BackgroundColor3   = Color3.fromRGB(20, 20, 20)
header.BackgroundTransparency = 0
header.TextColor3         = Color3.fromRGB(255, 220, 50)
header.TextScaled         = true
header.Font               = Enum.Font.GothamBold
header.Text               = "Daily Challenges"
header.BorderSizePixel    = 0
header.Parent             = sg

local tierColors = {
    Color3.fromRGB(80, 200, 80),
    Color3.fromRGB(80, 150, 220),
    Color3.fromRGB(220, 100, 220),
}
local tierNames = {"Easy", "Medium", "Hard"}

for i = 1, 3 do
    local row = Instance.new("Frame")
    row.Name              = "Row" .. i
    row.Size              = UDim2.new(1, 0, 0, 60)
    row.Position          = UDim2.new(0, 0, 0, 45 + (i - 1) * 65)
    row.BackgroundColor3  = Color3.fromRGB(30, 30, 30)
    row.BorderSizePixel   = 0
    row.Parent            = sg

    local label = Instance.new("TextLabel")
    label.Name              = "Label"
    label.Size              = UDim2.new(0.74, 0, 0.5, 0)
    label.Position          = UDim2.new(0.01, 0, 0.02, 0)
    label.BackgroundTransparency = 1
    label.TextColor3        = Color3.fromRGB(230, 230, 230)
    label.TextScaled        = true
    label.Font              = Enum.Font.GothamBold
    label.TextXAlignment    = Enum.TextXAlignment.Left
    label.Text              = tierNames[i] .. ": Loading..."
    label.Parent            = row

    local reward = Instance.new("TextLabel")
    reward.Name             = "Reward"
    reward.Size             = UDim2.new(0.24, 0, 0.5, 0)
    reward.Position         = UDim2.new(0.75, 0, 0.02, 0)
    reward.BackgroundTransparency = 1
    reward.TextColor3       = Color3.fromRGB(255, 220, 50)
    reward.TextScaled       = true
    reward.Font             = Enum.Font.GothamBold
    reward.TextXAlignment   = Enum.TextXAlignment.Right
    reward.Text             = "+??? coins"
    reward.Parent           = row

    local pbBg = Instance.new("Frame")
    pbBg.Name             = "ProgressBar"
    pbBg.Size             = UDim2.new(0.98, 0, 0.35, 0)
    pbBg.Position         = UDim2.new(0.01, 0, 0.6, 0)
    pbBg.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
    pbBg.BorderSizePixel  = 0
    pbBg.Parent           = row
    local c1 = Instance.new("UICorner")
    c1.CornerRadius = UDim.new(0, 4)
    c1.Parent = pbBg

    local fill = Instance.new("Frame")
    fill.Name             = "Fill"
    fill.Size             = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = tierColors[i]
    fill.BorderSizePixel  = 0
    fill.Parent           = pbBg
    local c2 = Instance.new("UICorner")
    c2.CornerRadius = UDim.new(0, 4)
    c2.Parent = fill
end

local boardExists = workspace:FindFirstChild("ChallengesBoard") and "YES" or "NO"
print("ChallengesBoard created:", boardExists)
-- Expected: YES
```

**Step 2: Visually verify in Studio** — confirm the board is visible on the right side of the back room wall, facing into the room.

---

## Task 7: Create DailyChallengeClient.client.lua

**Files:**
- Create: `src/StarterPlayerScripts/DailyChallengeClient.client.lua`

**Step 1: Write the script to disk**

```lua
-- src/StarterPlayerScripts/DailyChallengeClient.client.lua
-- Renders the Daily Challenges back room board and a compact HUD widget.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteManager  = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteManager"))

local initRemote     = RemoteManager.Get("DailyChallengesInit")
local progressRemote = RemoteManager.Get("DailyChallengeProgress")
local stateRemote    = RemoteManager.Get("GameStateChanged")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local hud       = playerGui:WaitForChild("HUD")

-- ─── State ──────────────────────────────────────────────────────────────────
local state = {
    challenges = {},
    progress   = {0, 0, 0},
    claimed    = {false, false, false},
    resetIn    = 0,
}

local TIER_ICONS   = {"★", "★★", "★★★"}
local TIER_COLORS  = {
    Color3.fromRGB(80, 200, 80),
    Color3.fromRGB(80, 150, 220),
    Color3.fromRGB(220, 100, 220),
}

-- ─── HUD Widget ─────────────────────────────────────────────────────────────
local hudWidget

local function makeHudWidget()
    local frame = hud:FindFirstChild("DailyChallengesWidget")
    if not frame then
        frame = Instance.new("Frame")
        frame.Name              = "DailyChallengesWidget"
        frame.Size              = UDim2.new(0, 230, 0, 84)
        frame.Position          = UDim2.new(0, 10, 1, -94)
        frame.BackgroundColor3  = Color3.fromRGB(15, 15, 15)
        frame.BackgroundTransparency = 0.25
        frame.BorderSizePixel   = 0
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = frame

        local title = Instance.new("TextLabel")
        title.Name              = "Title"
        title.Size              = UDim2.new(1, 0, 0, 20)
        title.BackgroundTransparency = 1
        title.TextColor3        = Color3.fromRGB(255, 220, 50)
        title.TextScaled        = true
        title.Font              = Enum.Font.GothamBold
        title.Text              = "Daily Challenges"
        title.Parent            = frame

        for i = 1, 3 do
            local row = Instance.new("TextLabel")
            row.Name                = "Row" .. i
            row.Size                = UDim2.new(1, -10, 0, 20)
            row.Position            = UDim2.new(0, 5, 0, 18 + (i - 1) * 22)
            row.BackgroundTransparency = 1
            row.TextColor3          = Color3.fromRGB(200, 200, 200)
            row.TextScaled          = true
            row.Font                = Enum.Font.Gotham
            row.TextXAlignment      = Enum.TextXAlignment.Left
            row.Text                = TIER_ICONS[i] .. "  0 / 0"
            row.Parent              = frame
        end

        frame.Parent = hud
    end
    frame.Visible = false
    return frame
end

local function updateHudWidget()
    if not hudWidget then return end
    for i = 1, 3 do
        local row = hudWidget:FindFirstChild("Row" .. i)
        local ch  = state.challenges[i]
        if row and ch then
            if state.claimed[i] then
                row.Text       = TIER_ICONS[i] .. "  ✓ Done"
                row.TextColor3 = Color3.fromRGB(100, 220, 100)
            else
                row.Text       = TIER_ICONS[i] .. "  " .. (state.progress[i] or 0) .. " / " .. ch.goal
                row.TextColor3 = Color3.fromRGB(200, 200, 200)
            end
        end
    end
end

-- ─── Back Room Board ─────────────────────────────────────────────────────────
local function getBoardGui()
    local part = workspace:FindFirstChild("ChallengesBoard")
    return part and part:FindFirstChild("ChallengesBoardGui")
end

local function updateBoard()
    local sg = getBoardGui()
    if not sg then return end

    local header = sg:FindFirstChild("Header")
    if header then
        local h  = math.floor(state.resetIn / 3600)
        local m  = math.floor((state.resetIn % 3600) / 60)
        local s  = state.resetIn % 60
        header.Text = string.format("Daily Challenges — Resets in %02d:%02d:%02d", h, m, s)
    end

    for i = 1, 3 do
        local row = sg:FindFirstChild("Row" .. i)
        local ch  = state.challenges[i]
        if not row or not ch then continue end

        local label  = row:FindFirstChild("Label")
        local reward = row:FindFirstChild("Reward")
        local pbBg   = row:FindFirstChild("ProgressBar")
        local fill   = pbBg and pbBg:FindFirstChild("Fill")

        if label then
            if state.claimed[i] then
                label.Text       = "✓ " .. ch.tier .. ": " .. ch.label
                label.TextColor3 = Color3.fromRGB(100, 220, 100)
            else
                label.Text       = ch.tier .. ": " .. ch.label
                label.TextColor3 = Color3.fromRGB(230, 230, 230)
            end
        end
        if reward then
            reward.Text = state.claimed[i] and "CLAIMED" or ("+" .. ch.reward .. " coins")
            reward.TextColor3 = state.claimed[i]
                and Color3.fromRGB(100, 220, 100)
                or  Color3.fromRGB(255, 220, 50)
        end
        if fill then
            local ratio = ch.goal > 0 and ((state.progress[i] or 0) / ch.goal) or 0
            fill.Size             = UDim2.new(state.claimed[i] and 1 or ratio, 0, 1, 0)
            fill.BackgroundColor3 = state.claimed[i]
                and Color3.fromRGB(80, 200, 80)
                or  TIER_COLORS[i]
        end
    end
end

-- ─── Completion Flash ────────────────────────────────────────────────────────
local function showCompletionFlash(coinsAwarded)
    local flash = Instance.new("TextLabel")
    flash.Size              = UDim2.new(0, 300, 0, 60)
    flash.Position          = UDim2.new(0.5, -150, 0.35, 0)
    flash.BackgroundColor3  = Color3.fromRGB(200, 160, 0)
    flash.TextColor3        = Color3.fromRGB(255, 255, 255)
    flash.TextScaled        = true
    flash.Font              = Enum.Font.GothamBold
    flash.Text              = "Challenge Complete!  +" .. coinsAwarded .. " coins"
    flash.ZIndex            = 50
    flash.BorderSizePixel   = 0
    flash.Parent            = hud
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 12)
    c.Parent = flash
    game:GetService("Debris"):AddItem(flash, 2.5)
end

-- ─── Remote Handlers ─────────────────────────────────────────────────────────
initRemote.OnClientEvent:Connect(function(data)
    state.challenges = data.challenges or {}
    state.progress   = data.progress   or {0, 0, 0}
    state.claimed    = data.claimed    or {false, false, false}
    state.resetIn    = data.resetIn    or 0
    updateHudWidget()
    updateBoard()
end)

progressRemote.OnClientEvent:Connect(function(data)
    state.progress[data.index] = data.progress
    state.claimed[data.index]  = data.completed
    if data.justCompleted then
        showCompletionFlash(data.coinsAwarded)
    end
    updateHudWidget()
    updateBoard()
end)

stateRemote.OnClientEvent:Connect(function(gameState)
    if hudWidget then
        hudWidget.Visible = (gameState == "Open")
    end
end)

-- ─── Countdown tick ──────────────────────────────────────────────────────────
task.spawn(function()
    while true do
        task.wait(1)
        if state.resetIn > 0 then
            state.resetIn -= 1
        end
        local sg = getBoardGui()
        if sg then
            local header = sg:FindFirstChild("Header")
            if header then
                local h = math.floor(state.resetIn / 3600)
                local m = math.floor((state.resetIn % 3600) / 60)
                local s = state.resetIn % 60
                header.Text = string.format("Daily Challenges — Resets in %02d:%02d:%02d", h, m, s)
            end
        end
    end
end)

-- ─── Init ────────────────────────────────────────────────────────────────────
hudWidget = makeHudWidget()
print("[DailyChallengeClient] Ready.")
```

**Step 2: Push to Studio via MCP**

```lua
-- MCP run_code
local sps = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local existing = sps:FindFirstChild("DailyChallengeClient")
if existing then existing:Destroy() end

local ls = Instance.new("LocalScript")
ls.Name   = "DailyChallengeClient"
ls.Parent = sps
-- ls.Source = <full source from Step 1, via table.concat>

local found = sps:FindFirstChild("DailyChallengeClient") and "YES" or "NO"
print("DailyChallengeClient created:", found)
-- Expected: YES
```

**Step 3: Commit**
```bash
git add src/StarterPlayerScripts/DailyChallengeClient.client.lua
git commit -m "feat: add DailyChallengeClient with HUD widget, board, and completion flash"
```

---

## Task 8: End-to-end test

**Step 1: Verify Studio has all pieces**

```lua
-- MCP run_code
local sss  = game:GetService("ServerScriptService")
local sps  = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local ge   = game:GetService("ReplicatedStorage"):WaitForChild("GameEvents")

local a = sss:FindFirstChild("DailyChallengeManager", true) and "YES" or "NO"
local b = sss:FindFirstChild("DailyChallengeServer", true) and "YES" or "NO"
local c = sps:FindFirstChild("DailyChallengeClient") and "YES" or "NO"
local d = ge:FindFirstChild("DailyChallengesInit") and "YES" or "NO"
local e = ge:FindFirstChild("DailyChallengeProgress") and "YES" or "NO"
local f = workspace:FindFirstChild("ChallengesBoard") and "YES" or "NO"
print("Manager:", a, "Server:", b, "Client:", c, "Init:", d, "Progress:", e, "Board:", f)
-- Expected: all YES
```

**Step 2: Start play mode and check output**

Start play mode. In Studio Output, look for:
```
[DailyChallengeServer] Ready.
[DailyChallengeClient] Ready.
```

No errors should appear.

**Step 3: Verify client received challenges**

```lua
-- MCP run_code (in play mode)
-- Manually trigger SendToPlayer for the test player
local Players = game:GetService("Players")
local sss     = game:GetService("ServerScriptService")
local DCM     = require(sss.Core.DailyChallengeManager)
local p       = Players:GetPlayers()[1]
if p then
    DCM.SendToPlayer(p)
    print("SendToPlayer fired for:", p.Name)
end
```

Check that the HUD widget appears (during Open phase) and the back room board shows 3 challenges with 0/goal progress.

**Step 4: Simulate a delivery**

```lua
-- MCP run_code (in play mode)
local Players = game:GetService("Players")
local sss     = game:GetService("ServerScriptService")
local DCM     = require(sss.Core.DailyChallengeManager)
local p       = Players:GetPlayers()[1]
if p then
    DCM.RecordDelivery(p, {
        stars       = 5,
        cookieId    = "chocolate_chip",
        coins       = 50,
        comboStreak = 3,
        packSize    = 2,
    })
    print("Simulated delivery for:", p.Name)
end
```

Expected: HUD widget updates progress. No Lua errors. Check Output for any warnings.

**Step 5: Test challenge completion flash**

Simulate enough deliveries to complete the Easy challenge (e.g., call RecordDelivery 5 times for `complete_orders_5`). The gold flash should appear with "Challenge Complete! +150 coins". Coins label in HUD should increase by 150.

**Step 6: Stop play mode**

Confirm no errors. Done.

---

## Update MEMORY.md after completion

Add to MEMORY.md:
- Daily Challenges system complete: DailyChallengeManager + Server + Client
- Resets at midnight UTC, 3 tiers, coins-only rewards (150/300/500)
- ChallengesBoard Part at (25, 8, -157) in workspace
- Hook: PersistentNPCSpawner → DailyChallengeManager.RecordDelivery after SessionStats.RecordDelivery
