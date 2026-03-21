# Alpha Audit — Cookie Empire: Master Bakery
**Date:** 2026-03-21
**Alpha Readiness:** 65/100
**Status:** Issues being resolved top-to-bottom. Check off each item when fixed + pushed.

---

## HOW TO USE THIS FILE
- Work through items in order: C → M → m → Systems
- Mark `[x]` when fixed AND pushed to `alpha-readiness-fixes` branch
- Every fix requires MCP run_code push to Studio after disk change

---

## CRITICAL (ship-blockers) — fix before ANY playtesting

### [x] C-1 — Data Corruption: `newProfile()` shares nested array references
**File:** `src/ServerScriptService/Core/PlayerDataManager.lua:59-71`
**Bug:** `newProfile()` does a shallow copy — `dailyChallenges.progress = {0,0,0}` is the SAME array object from `DEFAULT_PROFILE`. Any player incrementing challenge progress corrupts the default for all new players on that server.
**Fix:**
```lua
local function newProfile()
    return deepCopy(DEFAULT_PROFILE)
end
```
`deepCopy` already exists at line 82. Just use it.

---

### [ ] C-2 — Data Loss: `SetAsync` without session locking
**File:** `src/ServerScriptService/Core/PlayerDataManager.lua:104-121`
**Bug:** If player disconnects and rejoins quickly, two servers load the same saved data. Last server to save wins; other server's changes are lost silently.
**Fix:** Replace `SetAsync` with `UpdateAsync` and a server session ID lock:
```lua
local HttpService = game:GetService("HttpService")
local SESSION_ID  = HttpService:GenerateGUID(false)

local function saveProfile(userId)
    local profile = profiles[userId]
    if not profile then return end
    local key     = "Player_" .. userId
    local toSave  = deepCopy(profile)
    if toSave.stats and toSave.stats.fastestOrderTime == math.huge then
        toSave.stats.fastestOrderTime = 0
    end
    local ok, err = pcall(function()
        playerStore:UpdateAsync(key, function(current)
            -- If another server locked this key, abort (return nil = no change)
            if current and current._serverLock and current._serverLock ~= SESSION_ID then
                warn("[PlayerDataManager] Save skipped for " .. userId .. ": locked by another server")
                return nil
            end
            toSave._serverLock = SESSION_ID
            return toSave
        end)
    end)
    if not ok then
        warn("[PlayerDataManager] Save failed for", userId, err)
    end
end
```
Also set `_serverLock = SESSION_ID` in `loadProfile` via `UpdateAsync` to claim the lock on join.

---

### [ ] C-3 — Exploit: Client can instantly complete any minigame with score=100
**File:** `src/ServerScriptService/Minigames/MinigameServer.server.lua:110-169`
**Bug:** `endSession()` validates session exists and station matches but never checks elapsed time. A cheater fires result remote 0.001s after session starts — server accepts it.
**Fix:** Record `startedAt` in session, reject results submitted too early:
```lua
-- When creating session (in hookMixerPrompts / handleSimpleStart):
activeSessions[player] = {
    station   = stationName,
    batchId   = batchId,
    startedAt = tick(),   -- ADD THIS
    ...
}

-- At top of endSession(), after station mismatch check:
local MIN_DURATION = 3  -- seconds
local elapsed = tick() - (session.startedAt or 0)
if elapsed < MIN_DURATION then
    warn(string.format("[AntiExploit] %s submitted %s result in %.2fs (min %ds)",
        player.Name, stationName, elapsed, MIN_DURATION))
    return
end
```

---

### [ ] C-4 — Exploit: Drive-thru delivery ignores pack size and order ownership
**File:** `src/ServerScriptService/Core/DriveThruServer.server.lua:314-352`
**Bug:** Any box with matching cookieId triggers delivery prompt, regardless of who took the order or pack size. A 1-cookie box fulfills a 4-cookie order.
**Fix:**
```lua
-- Store who took the order:
currentOrder = {
    ...
    takenBy = player,  -- set in the Triggered handler for DriveThruOrderPrompt
}

-- In BoxCreated listener:
if box.cookieId ~= currentOrder.cookieId then return end
-- Pack size validation (optional relaxed: at least 1):
-- For strict: if (box.packSize or 1) < currentOrder.packSize then return end

-- In addDeliveryPrompt onDeliver callback:
local function onDeliver(player)
    if currentOrder.takenBy and currentOrder.takenBy ~= player then
        warn("[DriveThru] " .. player.Name .. " tried to steal delivery from " .. tostring(currentOrder.takenBy))
        return
    end
    ...
end
```

---

## MAJOR (fix before closed playtest)

### [ ] M-1 — `mergeDefaults` drops new sub-table fields for existing players
**File:** `PlayerDataManager.lua:73-80`
**Bug:** `p[k] = saved[k]` replaces entire sub-tables. New fields added inside `mastery` or `dailyChallenges` after a player's first save are silently lost for that player.
**Fix:** Use recursive merge:
```lua
local function mergeDeep(defaults, saved)
    local out = {}
    for k, dv in pairs(defaults) do
        local sv = saved[k]
        if type(dv) == "table" and type(sv) == "table" then
            out[k] = mergeDeep(dv, sv)
        else
            out[k] = sv ~= nil and sv or dv
        end
    end
    return out
end

local function mergeDefaults(saved)
    return mergeDeep(DEFAULT_PROFILE, saved)
end
```

---

### [ ] M-2 — No server-side minigame session timeout
**File:** `MinigameServer.server.lua`
**Bug:** If player client freezes mid-minigame and rejoins, old `activeSessions[oldPlayer]` entry lingers forever.
**Fix:** Add watchdog per session:
```lua
local SESSION_TIMEOUT = 60  -- seconds

-- After setting activeSessions[player]:
local capturedBatchId = batchId
task.delay(SESSION_TIMEOUT, function()
    local s = activeSessions[player]
    if s and s.batchId == capturedBatchId then
        warn("[MinigameServer] Session timeout: " .. player.Name .. " @ " .. stationName)
        activeSessions[player] = nil
        if stationName == "dough" then doughLock[capturedBatchId] = nil end
    end
end)
```

---

### [ ] M-3 — `BindToClose` saves profiles sequentially
**File:** `PlayerDataManager.lua:275-278`
**Bug:** Sequential `SetAsync` calls can exhaust DataStore budget; server may shut down before all complete.
**Fix:**
```lua
game:BindToClose(function()
    local threads = {}
    for userId in pairs(profiles) do
        threads[#threads+1] = task.spawn(saveProfile, userId)
    end
    task.wait(8)  -- give saves time to complete
end)
```

---

### [ ] M-4 — `broadcastState()` fires 3×N remotes per event, chained
**File:** `MinigameServer.server.lua:81-96`
**Bug:** BatchUpdated → broadcastState → fires all 3 remotes → WarmersUpdated → broadcastState again. Up to 18 remote fires per batch step with 6 players.
**Fix:** Debounce with `task.defer`:
```lua
local _broadcastPending = false
local function broadcastState()
    if _broadcastPending then return end
    _broadcastPending = true
    task.defer(function()
        _broadcastPending = false
        local batchState  = OrderManager.GetBatchState()
        local fridgeState = OrderManager.GetFridgeState()
        local warmerState = OrderManager.GetWarmerState()
        local stockByType = OrderManager.GetWarmerStockByCookieId()
        for _, p in ipairs(Players:GetPlayers()) do
            BatchUpdated:FireClient(p, batchState)
            FridgeUpdated:FireClient(p, fridgeState)
            WarmersUpdated:FireClient(p, warmerState, stockByType)
        end
        updateWarmerCountLabels()
    end)
end
```

---

### [ ] M-5 — `MAX_ACTIVE_BATCHES = 2` regardless of player count
**File:** `OrderManager.lua:14`
**Bug:** With 6 players, 4 have nothing to do while 2 mix. Primary cause of multiplayer boredom.
**Fix:** Make dynamic. Options:
- `math.max(2, Players.NumPlayers)` — one slot per player
- `math.max(2, math.ceil(Players.NumPlayers / 2))` — one slot per 2 players
- Server sets it at Open phase start via a setter function

Simplest: in `TryStartBatch()`, count active players dynamically:
```lua
local playerCount = #game:GetService("Players"):GetPlayers()
local dynamicMax  = math.max(2, playerCount)
if count >= dynamicMax then ...
```

---

### [ ] M-7 — Open phase too short; drive-thru spawn interval too long
**Files:** `GameStateManager.server.lua:14`, `DriveThruServer.server.lua:33`
**Fix:**
```lua
-- GameStateManager:
local OPEN_DURATION = 15 * 60  -- was 10 min

-- DriveThruServer:
local SPAWN_INTERVAL = 45  -- was 150s
```

---

### [ ] M-9 — MainMenuGui has no M7 polish (first impression)
**File:** `src/StarterGui/MainMenuGui/MainMenuController.client.lua`
**Current state:** 38-line script that just shows/hides a static Studio-built GUI. No dark panel, no GothamBold, no gold accents.
**Required:** Dark navy `Color3.fromRGB(14,14,26)` panel, game title in GothamBold, gold `Color3.fromRGB(255,200,0)` accent stripe, styled Play button with hover state.
**Approach:** Rebuild GUI programmatically in the controller (same pattern as HUDController).

---

### [ ] M-10 — StaffManager clones hiring player's character for worker rig
**File:** `StaffManager.server.lua:63-124`
**Bug:** If player has heavy accessories, clone replicates all of it to all clients. Fails visually on complex rigs.
**Fix:** Always use clean NPCTemplate R6 (same rig used for NPCs), apply baker Shirt/Pants only.
Remove the character-clone branch; keep only the block-rig fallback and upgrade it to use `NPCTemplate`.

---

## MINOR (cleanup before Codex handoff)

### [ ] m-1 — Delete dead files
- `NPCAvatarLoader.server.lua` — disabled with `do return end`, completely dead
- Remove or clearly comment staged-box dead code in StaffManager (AI dress worker disabled)

### [ ] m-2 — Consolidate leaderboard scripts
- `Leaderboard.server.lua` AND `LeaderboardManager.server.lua` both exist in SSS/Core
- Clarify or merge roles

### [ ] m-3 — Move misplaced scripts to Core/
- `POSController.server.lua` → `SSS/Core/`
- `AIBakerSystem.server.lua` → `SSS/Core/`
- `ExteriorManager.server.lua` → `SSS/Core/`

### [ ] m-4 — Fix script name typo
- `No Collison.server.lua` → `NoCollision.server.lua`

---

## SYSTEMS TO ADD (post-critical, pre-Codex)

### [ ] S-1 — Rush hour mechanic
At 70% through Open phase (10.5 min into 15min), double NPC spawn rate for final 4.5 minutes. Creates a climax.
**File:** `PersistentNPCSpawner.server.lua` — detect elapsed Open time, halve SPAWN_INTERVAL.

### [ ] S-2 — Station Occupied indicator
3D BillboardGui above each station showing who is currently using it.
Fire a remote to clients when session starts/ends; client updates the billboard.

### [ ] S-3 — Drive-thru HUD alert
When a car arrives, fire a remote to all clients. HUDController shows a "🚗 Drive Thru!" pill for 5 seconds.

---

## ALREADY DONE (from previous sessions)
- [x] P0-3: Minigame DisplayOrder bumped to 22 (above HUD at 20)
- [x] P3-3: JumpHeight=0 in NoCollision.server.lua
- [x] P1-3: MenuServer remap debounce with _remapToken
- [x] P2-1: WarmersUpdated sends stockByType; HUD shows StockPill per-type
- [x] P2-2: Star display shows "★★★☆☆  3/5"
- [x] P0-2: getFrontSpawnCF uses GameSpawn part dynamically
- [x] P1-5: GetTopEmployee returns station field; board shows subtitle
- [x] NPCAvatarLoader disabled (do return end)
- [x] Topping teleport fixed to Tutorial Dress Spawn
- [x] AI Baker spawn CF fixed
- [x] M7 UI Polish (minigame GUIs, HUD, SummaryGui)
- [x] PR #2 open: alpha-readiness-fixes → main

---

## QA CHECKLIST (run before Codex handoff)

### Data Safety
- [ ] newProfile() — verify `dailyChallenges.progress` is NOT shared across two new players
- [ ] Rejoin test — disconnect and rejoin within 5s — coins not lost
- [ ] BindToClose — 6-player server shutdown — all profiles saved
- [ ] New field added to mastery sub-table — existing player gets default on next load

### Exploits
- [ ] Fire MixMinigameResult immediately after session start → rejected (< 3s)
- [ ] Fire result with no active session → rejected
- [ ] Two players trigger dough simultaneously → second gets "already claimed"
- [ ] Drive-thru: player who didn't take order tries to deliver → blocked
- [ ] 1-pack box for 4-pack drive-thru order → handled correctly

### Multiplayer (6 players)
- [ ] All 6 trigger mix simultaneously → correct MAX_ACTIVE_BATCHES
- [ ] Player disconnects mid-minigame → session cleared within SESSION_TIMEOUT
- [ ] State broadcasts don't flood during rapid batch completions
- [ ] Drive-thru visible only when DriveThruUnlocked = true

### Game Loop
- [ ] Full cycle: PreOpen → Open → EndOfDay → Intermission → repeat
- [ ] Rush hour fires at 70% of Open phase
- [ ] Summary shows correct Employee of Shift

### UI
- [ ] MainMenuGui has dark panel + GothamBold + gold accent
- [ ] Station occupied billboard shows correct player name
- [ ] Drive-thru HUD alert appears on car arrival
- [ ] Mobile: all prompts reachable, no UI below safe area
