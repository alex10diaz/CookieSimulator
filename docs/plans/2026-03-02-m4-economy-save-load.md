# M4: Economy + Save/Load Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Wire the full economy pipeline — DataStore persistence for player coins/XP/level, real star/coin/XP formulas using EconomyManager, and combo streak tracking — replacing all M3 stubs.

**Architecture:** EconomyManager (pure math, no server APIs) moves to ReplicatedStorage/Modules as a ModuleScript so any script can require it. PlayerDataManager converts from a Script to a ModuleScript in ServerScriptService/Core and gains DataStore persistence with load-on-join and save-on-leave. PersistentNPCSpawner's delivery handler replaces its inline stub math with requires to both real modules.

**Tech Stack:** Roblox DataStoreService, MCP run_code for Studio changes, Write tool for file system.

---

## Context: Why two scripts need converting

`EconomyManager.server.lua` and `PlayerDataManager.server.lua` both end with `return Module` — they were written as ModuleScripts but given `.server.lua` extensions, which makes Rojo/Studio treat them as Scripts. Scripts cannot be `require()`d. This is why PersistentNPCSpawner uses a stub local table instead of the real PlayerDataManager. M4 fixes this.

Rojo is **stopped**. All Studio changes go through MCP `run_code`. All file-system changes go through the Write tool. Both must be done together for each task.

---

## Task 1: Move EconomyManager to ReplicatedStorage/Modules

EconomyManager is pure math — no DataStore, no server-only APIs. It belongs in ReplicatedStorage alongside CookieData, OrderManager, etc.

**Files:**
- Delete: `src/ServerScriptService/Core/EconomyManager.server.lua`
- Create: `src/ReplicatedStorage/Modules/EconomyManager.lua`

**Step 1: Write the new file**

Create `src/ReplicatedStorage/Modules/EconomyManager.lua` with this exact content (copy from existing, no changes to logic):

```lua
-- ReplicatedStorage/Modules/EconomyManager
-- All payout formulas. Rebalance by changing numbers in this one file.

local RECIPE_VALUES = {
    pink_sugar           = { coins = 10,  timeLimitSecs = 90  },
    chocolate_chip       = { coins = 15,  timeLimitSecs = 90  },
    snickerdoodle        = { coins = 25,  timeLimitSecs = 120 },
    birthday_cake        = { coins = 40,  timeLimitSecs = 120 },
    cookies_and_cream    = { coins = 65,  timeLimitSecs = 150 },
    lemon_blackraspberry = { coins = 100, timeLimitSecs = 150 },
}

local MULTIPLIER_CAP = 3.0

local EconomyManager = {}

function EconomyManager.GetRecipeValue(cookieId)
    return RECIPE_VALUES[cookieId] or { coins = 10, timeLimitSecs = 90 }
end

--[[
    CalculatePayout — returns { coins, xp, multiplier }
    @param cookieId      string
    @param quantity      number
    @param stars         number 1-5
    @param timeRemaining number  (seconds left; pass 0 if not tracked)
    @param totalTime     number  (original limit; pass 1 if not tracked)
    @param comboStreak   number  (0-20, capped)
    @param isVIP         boolean
]]
function EconomyManager.CalculatePayout(cookieId, quantity, stars, timeRemaining, totalTime, comboStreak, isVIP)
    local recipe  = EconomyManager.GetRecipeValue(cookieId)
    local base    = recipe.coins * math.max(1, quantity)

    local speedMult    = 1 + (math.max(0, timeRemaining) / math.max(1, totalTime)) * 0.5
    local accuracyMult = 0.5 + ((stars - 1) / 4)          -- 1★=0.5 … 5★=1.5
    local comboMult    = 1 + 0.05 * math.min(comboStreak or 0, 20)
    local vipMult      = isVIP and 1.75 or 1.0

    local totalMult = math.min(speedMult * accuracyMult * comboMult * vipMult, MULTIPLIER_CAP)
    local coins     = math.max(1, math.floor(base * totalMult))
    local xp        = math.max(1, math.floor(base * 0.6 * accuracyMult * (stars == 5 and 1.2 or 1.0)))

    return { coins = coins, xp = xp, multiplier = totalMult }
end

--[[
    CalculateStars — weighted 1-5 star rating
    @param correctness  0-1   (use quality/100 as proxy)
    @param speedRatio   0-1   (pass 1.0 if not tracked)
    @param doneness     string ("Perfect"|"SlightlyBrown"|"Underbaked"|"Burned")
    @param mixQuality   0-100
    @param decorScore   0-1   (nil → treated as 1.0)
]]
function EconomyManager.CalculateStars(correctness, speedRatio, doneness, mixQuality, decorScore)
    local donenessMap = {
        Perfect       = 1.0,
        SlightlyBrown = 0.7,
        Underbaked    = 0.5,
        Burned        = 0.0,
    }
    local d = donenessMap[doneness] or 0.5

    local raw = (correctness           * 0.35)
              + (speedRatio            * 0.30)
              + (d                     * 0.20)
              + ((mixQuality / 100)    * 0.10)
              + ((decorScore or 1.0)   * 0.05)

    return math.clamp(math.floor(raw * 5) + 1, 1, 5)
end

print("[EconomyManager] Ready.")
return EconomyManager
```

**Step 2: Apply to Studio via MCP**

```lua
-- MCP run_code
local RS = game:GetService("ReplicatedStorage")
local modules = RS:WaitForChild("Modules")

-- Remove old Script (if exists in wrong location)
local old = game:GetService("ServerScriptService"):FindFirstChild("Core")
if old then
    local oldEM = old:FindFirstChild("EconomyManager")
    if oldEM then oldEM:Destroy() end
end

-- Create new ModuleScript in correct location
local em = Instance.new("ModuleScript")
em.Name = "EconomyManager"
em.Parent = modules
-- Source will be set in next step
print("EconomyManager ModuleScript created in ReplicatedStorage.Modules")
```

Then set the Source:
```lua
-- MCP run_code (set source — paste full source string)
local em = game:GetService("ReplicatedStorage").Modules.EconomyManager
em.Source = [[ ...paste full file content... ]]
print("EconomyManager source set, length:", #em.Source)
```

**Step 3: Delete the old server script file**

Delete `src/ServerScriptService/Core/EconomyManager.server.lua` from the file system (the Write tool can't delete, so just note it — the MCP already removed it from Studio; the dead file on disk is harmless since Rojo is stopped).

**Step 4: Verify**

In Studio Output after a playtest start, confirm:
```
[EconomyManager] Ready.
```
does NOT appear (it only prints when required, not on its own). No errors in Output.

**Step 5: Commit**
```bash
git add src/ReplicatedStorage/Modules/EconomyManager.lua
git commit -m "feat(m4): move EconomyManager to ReplicatedStorage as ModuleScript"
```

---

## Task 2: Convert PlayerDataManager to ModuleScript + Add DataStore

PlayerDataManager has DataStore (server-only) so it stays in ServerScriptService/Core, but becomes a ModuleScript so other server scripts can `require()` it.

**Files:**
- Create: `src/ServerScriptService/Core/PlayerDataManager.lua` (replaces `.server.lua`)

**Step 1: Write the new file**

Create `src/ServerScriptService/Core/PlayerDataManager.lua`:

```lua
-- ServerScriptService/Core/PlayerDataManager (ModuleScript)
-- Handles in-memory player profiles + DataStore persistence.
-- Load on PlayerAdded, save on PlayerRemoving.

local Players           = game:GetService("Players")
local DataStoreService  = game:GetService("DataStoreService")

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
}

local profiles = {}  -- userId -> profile table

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
    -- Fill any missing keys that were added after the player's first save
    local p = newProfile()
    for k, v in pairs(saved) do
        p[k] = v
    end
    return p
end

-- ── DATASTORE ──────────────────────────────────────────────────
local function loadProfile(userId)
    local key = "Player_" .. userId
    local ok, result = pcall(function()
        return playerStore:GetAsync(key)
    end)
    if ok and result then
        return mergeDefaults(result)
    elseif not ok then
        warn("[PlayerDataManager] Load failed for", userId, result)
    end
    return newProfile()
end

local function saveProfile(userId)
    local profile = profiles[userId]
    if not profile then return end
    local key = "Player_" .. userId
    -- Remove non-serialisable fields before saving
    local toSave = {}
    for k, v in pairs(profile) do
        if type(v) ~= "function" then
            toSave[k] = v
        end
    end
    -- stats.fastestOrderTime = math.huge is not JSON-safe; clamp it
    if toSave.stats and toSave.stats.fastestOrderTime == math.huge then
        toSave.stats = { fastestOrderTime = 0 }
    end
    local ok, err = pcall(function()
        playerStore:SetAsync(key, toSave)
    end)
    if not ok then
        warn("[PlayerDataManager] Save failed for", userId, err)
    else
        print("[PlayerDataManager] Saved profile for userId", userId)
    end
end

-- ── MODULE API ─────────────────────────────────────────────────
local PlayerDataManager = {}

function PlayerDataManager.GetData(player)
    return profiles[player.UserId]
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

-- ── LIFECYCLE (runs when first required by any server script) ──
Players.PlayerAdded:Connect(function(player)
    profiles[player.UserId] = loadProfile(player.UserId)
    print("[PlayerDataManager] Loaded profile for " .. player.Name
        .. " | coins=" .. profiles[player.UserId].coins
        .. " level=" .. profiles[player.UserId].level)
end)

Players.PlayerRemoving:Connect(function(player)
    saveProfile(player.UserId)
    profiles[player.UserId] = nil
end)

-- Handle players already in game when this module is first required
for _, player in ipairs(Players:GetPlayers()) do
    if not profiles[player.UserId] then
        profiles[player.UserId] = loadProfile(player.UserId)
    end
end

print("[PlayerDataManager] Ready (DataStore: PlayerData_v1).")
return PlayerDataManager
```

**Step 2: Apply to Studio via MCP**

```lua
-- MCP run_code
local SSS  = game:GetService("ServerScriptService")
local core = SSS:WaitForChild("Core")

-- Remove old Script
local oldPDM = core:FindFirstChild("PlayerDataManager")
if oldPDM then
    oldPDM:Destroy()
    print("Removed old PlayerDataManager Script")
end

-- Create new ModuleScript
local pdm = Instance.new("ModuleScript")
pdm.Name   = "PlayerDataManager"
pdm.Parent = core
print("Created PlayerDataManager ModuleScript in ServerScriptService.Core")
```

Then set the Source in a second MCP call (to keep within MCP source length limits).

**Step 3: Verify Studio console output on playtest**

After playtesting, Output should show:
```
[PlayerDataManager] Ready (DataStore: PlayerData_v1).
[PlayerDataManager] Loaded profile for [YourName] | coins=0 level=1
```
No DataStore errors. (DataStore may print a "DataStore is not accessible" error in Studio in offline mode — this is expected and harmless. It falls back to a fresh profile.)

**Step 4: Commit**
```bash
git add src/ServerScriptService/Core/PlayerDataManager.lua
git commit -m "feat(m4): convert PlayerDataManager to ModuleScript with DataStore persistence"
```

---

## Task 3: Wire EconomyManager + PlayerDataManager into Delivery

Replace the stub economy code in PersistentNPCSpawner with real requires and formulas.

**Files:**
- Modify: `src/ServerScriptService/Core/PersistentNPCSpawner.server.lua`

**Step 1: Add requires at the top of PersistentNPCSpawner**

The current file has this stub at the top (around line 16):
```lua
-- PlayerDataManager is a Script (not a ModuleScript) — cannot be required.
-- Coin/XP persistence wired in M4. Stubs used here for M3.
local PlayerDataManager = {
    AddCoins = function() end,
    AddXP    = function() end,
    GetData  = function() return nil end,
}
```

Replace that entire block with:
```lua
local EconomyManager    = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("EconomyManager"))
local PlayerDataManager = require(game:GetService("ServerScriptService"):WaitForChild("Core"):WaitForChild("PlayerDataManager"))
```

Note: `ReplicatedStorage` is already declared at line 8 of the file. `ServerScriptService` needs to be added to the top service declarations if not already present (check line 9 — it uses `ServerScriptService` for something else already, so it should be there).

**Step 2: Replace the inline delivery payout block**

Find this block (around lines 392–407):
```lua
local qMult = 0.5 + (quality / 100) * 1.0
local coins  = math.floor(d.order.price * qMult)
if d.isVIP then coins = math.floor(coins * 1.75) end
local stars  = math.floor(1 + (quality / 100) * 4)
local xp     = math.floor(coins * 0.3)

PlayerDataManager.AddCoins(player, coins)
PlayerDataManager.AddXP(player, xp)
local profile = PlayerDataManager.GetData(player)
```

Replace with:
```lua
-- Stars from quality (0-100 weighted aggregate → 1-5 stars)
local stars = math.clamp(math.floor(1 + (quality / 100) * 4), 1, 5)

-- Combo: increment on ≥3 stars, reset below
local comboStreak
if stars >= 3 then
    comboStreak = PlayerDataManager.IncrementCombo(player)
else
    PlayerDataManager.ResetCombo(player)
    comboStreak = 0
end

-- Full payout via EconomyManager
-- timeRemaining=0, totalTime=1 → speedMult=1.0 (no timer tracking in M4)
local payout = EconomyManager.CalculatePayout(
    d.order.cookieId,
    d.order.packSize,
    stars,
    0,            -- timeRemaining (not tracked in M4)
    1,            -- totalTime
    comboStreak,
    d.isVIP
)

PlayerDataManager.RecordOrderComplete(player, stars == 5)
PlayerDataManager.AddCoins(player, payout.coins)
PlayerDataManager.AddXP(player, payout.xp)
local profile = PlayerDataManager.GetData(player)

-- Use payout values (not the old inline vars)
local coins = payout.coins
local xp    = payout.xp
```

The lines after this that fire `deliveryResult` and `hudUpdate` stay the same — they already use `stars`, `coins`, `xp`, and `profile`.

**Step 3: Apply to Studio via MCP**

Use MCP run_code to update PersistentNPCSpawner's Source in Studio to match the edited file. (Set Source directly — do not use gsub patterns as they fail on special characters.)

**Step 4: Verify with playtest**

Start playtest. Walk to mixer, mix a cookie, take it through the full pipeline to delivery. Check Output for:
```
[PlayerDataManager] Loaded profile for [Name] | coins=0 level=1
[NPCController] [Name] delivered to [NPC] | q=XX% coins=XX stars=X
[PlayerDataManager] Saved profile for userId XXXXXXXXX
```
After leaving playtest, re-enter. Coins should persist (in Studio, DataStore may not persist between playtests — this is normal Studio behavior; it works in published games).

**Step 5: Commit**
```bash
git add src/ServerScriptService/Core/PersistentNPCSpawner.server.lua
git commit -m "feat(m4): wire EconomyManager + PlayerDataManager into delivery, add combo tracking"
```

---

## Task 4: Remove Dead EconomyManager.server.lua from File System

The old `src/ServerScriptService/Core/EconomyManager.server.lua` is dead code on disk (already removed from Studio in Task 1). Clean it up.

**Step 1: Overwrite with a redirect comment to prevent confusion**

Since the Write tool can't delete files, overwrite it with a tombstone:
```lua
-- MOVED: This file has been superseded by ReplicatedStorage/Modules/EconomyManager.lua
-- This Script is no longer parented in Studio. Safe to delete from file system.
```

**Step 2: Commit**
```bash
git add src/ServerScriptService/Core/EconomyManager.server.lua
git commit -m "chore(m4): tombstone dead EconomyManager.server.lua (moved to ReplicatedStorage)"
```

---

## Quick Verification Checklist

After all tasks complete, start a playtest and confirm:

| Check | Expected |
|-------|----------|
| Output: PlayerDataManager Ready | ✅ `[PlayerDataManager] Ready (DataStore: PlayerData_v1).` |
| Output: Profile loaded | ✅ `Loaded profile for [Name] | coins=0 level=1` |
| Output: Delivery fires | ✅ `delivered to [NPC] | q=XX% coins=XX stars=X` |
| Coins/XP in HUD update after delivery | ✅ HUD shows real coins |
| Low-quality delivery gives fewer coins | ✅ Compare low quality vs high quality delivery |
| VIP order gives 1.75× | ✅ Enable TEST_IS_VIP=true in TestNPCSpawner to verify |
| Combo increments on ≥3 stars | ✅ Check `profile.comboStreak` via print |
| No errors in Output | ✅ No red warnings |

---

## Notes

- **DataStore in Studio**: DataStore saves may not persist between Studio playtests (Roblox limitation). They work correctly in a published/live game. Don't worry if data resets between playtests.
- **TestNPCSpawner**: The test NPC (npcId=9999) still works and is useful for testing delivery. Leave it in until M5.
- **Time tracking**: `timeRemaining=0, totalTime=1` means `speedMult = 1.0` — players get no speed bonus in M4. Real time tracking is M5+ scope.
- **Stars formula**: Quality 0-100 → stars 1-5 via `floor(1 + quality/100 * 4)`. This feeds the full EconomyManager formula for coins/XP.
