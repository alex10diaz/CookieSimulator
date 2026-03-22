# Alpha Audit — Cookie Empire: Master Bakery
**Date:** 2026-03-21
**Alpha Readiness:** 65/100
**Branch:** alpha-readiness-fixes → main (PR #2)

> Work top-to-bottom. Mark `[x]` when fixed AND pushed to Studio via MCP run_code.
> Every disk change also needs MCP run_code to sync to Studio.

---

## OVERALL VERDICT
The core pipeline (Mix → Dough → Fridge → Oven → Frost → Warmers → Dress → Deliver) is coherent and functional. Architecture is clean. The killer issues are: a DEFAULT_PROFILE table-reference bug that can corrupt all player data, SetAsync without session locking, and client-authoritative minigame scoring that any player can bypass instantly.

---

## SECTION 1 — CRITICAL ISSUES (fix before ANY playtesting)

### [ ] C-1 — Data Corruption: `newProfile()` shares nested array references
**File:** `src/ServerScriptService/Core/PlayerDataManager.lua:59-71`
**Bug:** `newProfile()` does a shallow copy. `dailyChallenges.progress = {0,0,0}` is the SAME array from `DEFAULT_PROFILE`. Any player's challenge progress increment writes to the DEFAULT_PROFILE array and corrupts all new players on that server.
**Fix:**
```lua
local function newProfile()
    return deepCopy(DEFAULT_PROFILE)  -- deepCopy already exists at line 82
end
```

---

### [ ] C-2 — Data Loss: `SetAsync` without session locking
**File:** `src/ServerScriptService/Core/PlayerDataManager.lua:104-121`
**Bug:** If player disconnects and reconnects quickly, two servers run `PlayerAdded` simultaneously. Last server to save wins — coins, XP, unlocks from the first session are silently overwritten.
**Fix:**
```lua
local HttpService = game:GetService("HttpService")
local SESSION_ID  = HttpService:GenerateGUID(false)

-- In saveProfile(), replace SetAsync with:
playerStore:UpdateAsync(key, function(current)
    if current and current._serverLock and current._serverLock ~= SESSION_ID then
        warn("[PlayerDataManager] Save skipped for " .. userId .. ": locked by another server")
        return nil
    end
    toSave._serverLock = SESSION_ID
    return toSave
end)
```

---

### [ ] C-3 — Exploit: Client can instantly complete any minigame with score=100
**File:** `src/ServerScriptService/Minigames/MinigameServer.server.lua:110-169`
**Bug:** `endSession()` validates session exists and station matches but never checks elapsed time. Any player fires result remote 0.001s after session starts with score=100 — server accepts it.
**Fix:**
```lua
-- When creating session (in hookMixerPrompts / handleSimpleStart):
activeSessions[player] = { station=..., batchId=..., startedAt=tick() }

-- At top of endSession(), after station mismatch check:
local MIN_DURATION = 3  -- minimum seconds before result accepted
local elapsed = tick() - (session.startedAt or 0)
if elapsed < MIN_DURATION then
    warn("[AntiExploit] " .. player.Name .. " submitted result too fast: " .. elapsed .. "s")
    return
end
```

---

### [ ] C-4 — Exploit: Drive-thru delivery ignores pack size and order ownership
**File:** `src/ServerScriptService/Core/DriveThruServer.server.lua:314-352`
**Bug:** Any box with matching cookieId triggers delivery prompt. Problems: 1-cookie box fulfills a 4-cookie order; any player (not just who took the order) can deliver; two players can race to deliver.
**Fix:**
```lua
-- Store who took the order in currentOrder:
currentOrder.takenBy = player  -- in DriveThruOrderPrompt Triggered handler

-- In BoxCreated listener:
if box.cookieId ~= currentOrder.cookieId then return end
-- Pack size (strict): if (box.packSize or 1) < currentOrder.packSize then return end

-- In addDeliveryPrompt onDeliver:
if currentOrder.takenBy and currentOrder.takenBy ~= player then
    warn("[DriveThru] " .. player.Name .. " tried to steal delivery")
    return
end
```

---

## SECTION 2 — MAJOR ISSUES (fix before closed playtest)

### [ ] M-1 — `mergeDefaults` drops new sub-table fields for existing players
**File:** `PlayerDataManager.lua:73-80`
**Bug:** `p[k] = saved[k]` replaces entire sub-tables. New fields added inside `mastery` after a player's first save are silently lost for that player.
**Fix:** Recursive merge:
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
**Bug:** If player's client crashes mid-session and they rejoin, old `activeSessions[oldPlayer]` entry lingers indefinitely. Player can never start another session on return.
**Fix:**
```lua
local SESSION_TIMEOUT = 60
local capturedBatchId = batchId
task.delay(SESSION_TIMEOUT, function()
    local s = activeSessions[player]
    if s and s.batchId == capturedBatchId then
        warn("[MinigameServer] Session timeout: " .. player.Name)
        activeSessions[player] = nil
        if stationName == "dough" then doughLock[capturedBatchId] = nil end
    end
end)
```

---

### [ ] M-3 — `BindToClose` saves profiles sequentially, risks budget exhaustion
**File:** `PlayerDataManager.lua:275-278`
**Bug:** Sequential saves hit DataStore write budget limit. With 6 players, later saves silently fail if budget exhausted.
**Fix:**
```lua
game:BindToClose(function()
    local threads = {}
    for userId in pairs(profiles) do
        threads[#threads+1] = task.spawn(saveProfile, userId)
    end
    task.wait(8)  -- let parallel saves complete
end)
```

---

### [ ] M-4 — `broadcastState()` fires 3×N remotes per event, chained
**File:** `MinigameServer.server.lua:81-96`
**Bug:** BatchUpdated → broadcastState → fires 3 remotes → WarmersUpdated fires broadcastState again. With 6 players, one station completion = up to 18 remote fires in a frame.
**Fix:**
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
**Bug:** With 6 players, only 2 can mix at a time. 4 players idle at Mix — primary multiplayer boredom source.
**Fix:** Dynamic count in `TryStartBatch()`:
```lua
local playerCount = #game:GetService("Players"):GetPlayers()
local dynamicMax  = math.max(2, playerCount)
if count >= dynamicMax then ...
```

---

### [ ] M-6 — Drive-thru car spawn interval is 150 seconds (too infrequent)
**File:** `DriveThruServer.server.lua:33`
**Bug:** `SPAWN_INTERVAL = 150`. In a 10-minute Open phase, only 3–4 cars arrive. Entire drive-thru system barely engages players.
**Fix:** `local SPAWN_INTERVAL = 45`

---

### [ ] M-7 — Open phase is only 10 minutes — too short for a baking cycle
**File:** `GameStateManager.server.lua:14`
**Bug:** Full pipeline (mix 8s + dough 6s + fridge + oven 12s + frost 8s + dress) = ~50–90s per batch. New players can realistically complete only 4–6 deliveries in 10 minutes.
**Fix:** `local OPEN_DURATION = 15 * 60  -- was 10 * 60`

---

### [ ] M-8 — NPC delivery has no box-carrying check; activation distance too generous
**File:** `DeliveryHandler.server.lua` + NPC ProximityPrompts
**Bug:** `MaxActivationDistance=20` lets players trigger delivery from anywhere within 20 studs without walking to NPC. No server-side check that player is actually carrying a box.
**Fix:**
- Reduce delivery prompt `MaxActivationDistance` to 8–10
- Before awarding reward, confirm player has a pending box in `OrderManager.boxes` as carrier

---

### [ ] M-9 — MainMenuGui has no M7 polish (first impression)
**File:** `src/StarterGui/MainMenuGui/MainMenuController.client.lua`
**Bug:** 38-line script that just shows/hides a static Studio-built GUI. No dark panel, no GothamBold, no gold accents. This is the FIRST thing a player sees.
**Fix:** Rebuild GUI programmatically:
- Dark navy panel `Color3.fromRGB(14, 14, 26)`
- Game title in GothamBold with gold `Color3.fromRGB(255, 200, 0)` accent stripe
- Styled Play button with hover state (same pattern as HUDController)

---

### [ ] M-10 — StaffManager worker rig clones hiring player's character
**File:** `StaffManager.server.lua:63-124`
**Bug:** Heavy accessories replicate to all clients on hire. Clone fails visually on complex rigs (pcall fallback spawns jarring block rig). With 5 workers, up to 30-instance broadcasts per clone.
**Fix:** Always use clean NPCTemplate R6 rig + apply baker Shirt/Pants only. Remove character-clone branch.

---

## SECTION 3 — MINOR ISSUES (cleanup before Codex handoff)

### [ ] m-1 — Script name typo: `No Collison.server.lua`
**Fix:** Rename to `NoCollision.server.lua` in Studio

### [ ] m-2 — Dead file: `NPCAvatarLoader.server.lua`
**Fix:** Delete entirely — disabled with `do return end`, serves no purpose

### [ ] m-3 — `POSController.server.lua` in SSS root (should be in Core/)
**Fix:** Move to `SSS/Core/`

### [ ] m-4 — `AIBakerSystem.server.lua` and `ExteriorManager.server.lua` in SSS root
**Fix:** Move to `SSS/Core/`

### [ ] m-5 — Two leaderboard scripts: `Leaderboard.server.lua` AND `LeaderboardManager.server.lua`
**Fix:** Clarify roles or consolidate into one script

### [ ] m-6 — `EconomyManager.lua` in ReplicatedStorage exposes payout math to clients
**Decision needed:** Move to SSS (server-only) OR accept as read-only display logic
If clients never calculate payouts themselves → move it. If HUD needs estimated reward → keep it.

### [ ] m-7 — Drive-thru box check doesn't validate pack size (covered in C-4)
Already fixed by C-4 — mark complete when C-4 is done.

### [ ] m-8 — `WeeklyChallengeManager.lua` / `WeeklyChallengeServer.server.lua` file tree malformed
**Fix:** Minor structural cleanup — verify both files are correctly parented in Studio

### [ ] m-9 — `HireAnchor_*` Parts may leak into Workspace
**File:** `StaffManager.server.lua:576-608`
**Fix:** Add guard before creating anchor:
```lua
local existing = workspace:FindFirstChild("HireAnchor_" .. stationId)
if existing then existing:Destroy() end
```

### [ ] m-10 — `task.wait(2)` hardcoded settle delay before game cycle starts
**File:** `GameStateManager.server.lua:140`
**Bug:** Blind 2-second wait before `runCycle()`. If server is slow to boot, this can be too short.
**Fix:** Poll for a known module-ready signal or use `task.wait(0)` + check attribute

---

## SECTION 4 — ARCHITECTURE PROBLEMS

### [ ] P-1 — `OrderManager` in ReplicatedStorage exposes server game state
**Bug:** `OrderManager` holds `batches`, `warmers`, `fridges`, `boxes`. Clients can require it and read all function signatures to understand server API. Per-VM isolation means client gets an empty instance, but logic is visible.
**Better:** Move to `ServerScriptService/Modules/` — pass state to clients via remotes only.

### [ ] P-2 — `SSS/Core/` mixes Scripts and ModuleScripts in one flat folder
**Bug:** 20+ files with no separation between top-level Scripts (`.server.lua`) and library Modules (`.lua`). Hard to read for Codex handoff.
**Better structure:**
```
ServerScriptService/
  Core/
    Scripts/    ← all .server.lua files
    Modules/    ← all .lua ModuleScript files
  Minigames/
    Scripts/
    Modules/
```

### [ ] P-3 — `DeliveryHandler.server.lua` and `DriveThruServer` duplicate delivery reward logic
**Bug:** NPC delivery validation lives in `DeliveryHandler`; drive-thru delivery lives in `DriveThruServer`. Reward logic is split — one path may validate box quality, the other doesn't.
**Fix:** Extract shared `grantDeliveryReward(player, coins, xp, quality)` into a shared module.

---

## SECTION 5 — WHAT IS WORKING WELL
*(No action needed — reference only)*

1. **RemoteManager** — single registry, server creates all remotes, clients wait. No duplicate remotes.
2. **doughLock** — prevents two players grabbing the same dough batch. Correct concurrency fix.
3. **Session validation in `endSession()`** — checks session exists, station matches, score is a number.
4. **Anti-exploit cookieId** — mix session's cookieId assigned server-side, not client-supplied.
5. **`task.defer` remap debounce (P1-3)** — correct race condition fix for menu remap timing.
6. **`workspace.GameState` attribute** — cross-script state readable without requires.
7. **StationRemapService** — remaps warmer/fridge colors, texts, IDs cleanly on menu change.
8. **AI worker balance heuristic** — picks lowest combined warmer+fridge stock cookie.
9. **`MinigameBase.NewTracker()`** — connection stacking prevention built in.
10. **`BindToClose` data save** — profiles saved on server shutdown.

---

## SECTION 6 — RECOMMENDED REFACTORS
*(All map to C/M tasks above — listed here for cross-reference)*

| Priority | Refactor | Task |
|----------|----------|------|
| HIGH | `newProfile()` → `deepCopy(DEFAULT_PROFILE)` | C-1 |
| HIGH | `SetAsync` → `UpdateAsync` + session lock | C-2 |
| HIGH | Add `startedAt` to sessions, reject fast results | C-3 |
| HIGH | Debounce `broadcastState()` with `task.defer` | M-4 |
| MEDIUM | Scale `MAX_ACTIVE_BATCHES` by player count | M-5 |
| MEDIUM | Add server-side session timeout watchdog | M-2 |
| MEDIUM | Replace character clone with clean NPCTemplate | M-10 |
| LOW | Reorganize SSS/Core into Scripts/ and Modules/ | P-2 |
| LOW | Consolidate Leaderboard scripts | m-5 |

---

## SECTION 7 — WHAT SHOULD BE REMOVED

| Item | Reason | Task |
|------|--------|------|
| `NPCAvatarLoader.server.lua` | `do return end` — completely dead | m-2 |
| Staged box system in StaffManager | AI dress worker disabled — dead code. Remove or mark TODO. | m-2 |
| `EconomyManager.lua` from ReplicatedStorage | Exposes payout logic to clients | m-6 |
| `HireAnchor_*` Parts not properly cleaned up | Potential workspace leak | m-9 |

---

## SECTION 8 — UI / UX ISSUES

### Critical
### [ ] UI-1 — MainMenuGui has no M7 polish
No dark panel, no GothamBold, no gold accent. First thing players see. Must be redesigned. → See M-9

### Major
### [ ] UI-2 — No "What to do next" indicator
New players who finish mix have no arrow/highlight to dough table. Tutorial teaches it once — returning players who skip may forget.
→ See S-7 (Next Step Coach Mark)

### [ ] UI-3 — Warmer StockPill uses abbreviations players won't recognize
"Pink:2 · Choc:1 · Snick:0" — consider cookie icons instead of text abbreviations, or spell out full names.

### [ ] UI-4 — No active station indicator for other players
When a player is at a station, others get no visual feedback it's occupied. Need "Station Busy" billboard. → See S-2

### [ ] UI-5 — Drive-thru has no in-store HUD element
Only the TV shows the order. Players working inside have no indication a car arrived. → See S-3

### Minor
### [ ] UI-6 — "Intermission" truncates on small screens
Timer pill format "Open — 8:32" is fine but "Intermission" is long. Consider "Break 2:45".

### [ ] UI-7 — Star display in summary still small
"★★★☆☆  3/5" improved but too small in the summary screen. Make it larger and more prominent.

### [ ] UI-8 — ShopClient and MenuClient not audited — likely need M7 polish
Neither script was audited. Schedule a polish pass before Codex handoff.

### Mobile-specific
### [ ] UI-9 — Hire prompt uses `Enum.KeyCode.H` — keyboard only
Mobile players can't trigger keybind, but ProximityPrompt default button should show for mobile. **Verify** it renders correctly on phone — test the hire flow on mobile before shipping.

### [ ] UI-10 — StagedBox pickup prompt `MaxActivationDistance = 6` — too short for mobile
Raise to 10 for fat-finger tolerance on mobile screens.

### Suggested UI Improvements (design goals)
```
Order Cards (replace OrderPill text list):
┌──────────────────────┐
│  🍪 Pink Sugar  x1   │
│  ████████░░  8:24    │  ← patience timer
│  [Warmer: Ready ✓]   │
└──────────────────────┘

Station Status Overlay (above each station in 3D):
  ● Alex — Mixing...
  ○ Available

Next Step Helper (bottom of screen, first 3 orders only):
│ ← Walk to Dough Table to shape │
```

---

## SECTION 9 — SYSTEMS TO ADD (post-critical, pre-Codex)

### [ ] S-1 — Rush Hour mechanic (HIGH priority)
At 70% through Open phase (10.5 min into 15min), double NPC spawn rate for final 4.5 minutes. Creates a session climax moment.
**File:** `PersistentNPCSpawner.server.lua` — detect elapsed Open time, halve `SPAWN_INTERVAL`.

### [ ] S-2 — Station Occupied indicator (HIGH priority)
3D BillboardGui above each minigame station showing who is currently using it ("Alex is mixing!").
Server fires remote when session starts/ends → client updates billboard label.

### [ ] S-3 — Drive-thru HUD alert (MEDIUM priority)
When car arrives, fire remote to all clients. HUDController shows "🚗 Drive Thru!" pill for 5 seconds.

### [ ] S-4 — Order fail state (HIGH priority)
When NPC patience expires and they leave without delivery, show visible "Order Failed!" flash on KDS and decrement star rating. Currently NPCs quietly disappear with no feedback.

### [ ] S-5 — Sound effects (MEDIUM priority — critical for game feel)
At minimum 3 sounds: mixer whir during Mix, oven ding on completion, cash register on delivery. Without these the game feels flat in playtester sessions.

### [ ] S-6 — NPC patience bar visible to all players (MEDIUM priority)
Currently only the order-taker sees NPC patience. Replicate bar to all clients so team can coordinate.
Server fires patience % to all clients every few seconds during active order.

### [ ] S-7 — "Next Step" coach mark for first 3 orders (MEDIUM priority)
One-sentence hint at bottom of screen: "Walk to Dough Table →". Show only first 3 orders per session, then auto-hide. Reduces new-player confusion post-tutorial.

### [ ] S-8 — Box quality preview on pickup (MEDIUM priority)
When box is created after dress station, briefly flash quality stars (e.g. "★★★★☆ 82%") to the player before they deliver. Closes the scoring feedback loop.

### [ ] S-9 — Combo streak display in HUD (LOW priority)
`comboStreak` tracked in PlayerDataManager but never shown to player. Add small "🔥 x3" counter to HUD during Open phase.

### [ ] S-10 — Leaderboard live update during Open (LOW priority)
Currently updates end-of-shift only. Update every 30s during Open to drive healthy competition.

---

## SECTION 10 — NEXT CODING TASKS (priority order)

```
[ ] 1.  C-1  — deepCopy in newProfile()                          (~5 min)
[ ] 2.  C-2  — UpdateAsync + session lock in PlayerDataManager   (~30 min)
[ ] 3.  C-3  — Server-side startedAt timer check in endSession() (~20 min)
[ ] 4.  C-4  — Drive-thru pack size + order ownership            (~20 min)
[ ] 5.  M-1  — Recursive mergeDefaults                           (~15 min)
[ ] 6.  M-2  — Session timeout watchdog in MinigameServer        (~15 min)
[ ] 7.  M-3  — Parallel BindToClose saves                        (~10 min)
[ ] 8.  M-4  — Debounce broadcastState                           (~10 min)
[ ] 9.  M-5  — Dynamic MAX_ACTIVE_BATCHES                        (~10 min)
[ ] 10. M-6  — SPAWN_INTERVAL = 45                               (~2 min)
[ ] 11. M-7  — OPEN_DURATION = 15 * 60                           (~2 min)
[ ] 12. M-8  — NPC delivery activation distance + box check      (~20 min)
[ ] 13. M-9  — M7-polish MainMenuGui                             (~2 hrs)
[ ] 14. M-10 — StaffManager worker → NPCTemplate rig             (~30 min)
[ ] 15. m-*  — Minor cleanup (dead files, rename, move scripts)  (~30 min)
[ ] 16. S-1  — Rush hour mechanic                                (~30 min)
[ ] 17. S-2  — Station occupied billboard                        (~30 min)
[ ] 18. S-3  — Drive-thru HUD alert                              (~20 min)
[ ] 19. S-4  — Order fail state feedback                         (~30 min)
[ ] 20. S-5  — Sound effects (3 minimum)                         (~1 hr)
[ ] 21. S-6  — NPC patience bar replication                      (~30 min)
[ ] 22. S-7  — Next-step coach mark                              (~30 min)
[ ] 23. S-8/S-9/S-10 — Quality preview, combo streak, live LB   (~1 hr)
[ ] 24. UI   — ShopClient + MenuClient M7 polish pass            (~1 hr)
[ ] 25. P-*  — Architecture cleanup (P-1/P-2/P-3) for Codex     (~1 hr)
```

---

## SECTION 11 — TOP 10 (ranked by impact on fun + stability + alpha readiness)

```
[ ] 1. Fix deepCopy in newProfile()            — 5 min, prevents data corruption for ALL players
[ ] 2. Add server-side minigame timer check    — most impactful anti-exploit fix
[ ] 3. SetAsync → UpdateAsync session lock     — prevents silent data loss on rejoin
[ ] 4. M7-polish MainMenuGui                   — first impression, transforms perceived quality
[ ] 5. Debounce broadcastState                 — prevents remote spam under 6-player load
[ ] 6. Station Occupied billboard              — #1 multiplayer confusion point eliminated
[ ] 7. OPEN_DURATION=15min, SPAWN_INTERVAL=45s — more time + more drive-thru = more fun
[ ] 8. Rush hour at 70% of Open phase          — climax moment, ~30 lines in NPCSpawner
[ ] 9. Dynamic MAX_ACTIVE_BATCHES              — 4 idle players → all players contributing
[ ] 10. Add sound effects (3 minimum)          — triples game feel quality in playtester sessions
```

---

## SECTION 12 — QA CHECKLIST (run before Codex handoff)

### Data Safety
```
[ ] newProfile() — dailyChallenges.progress is NOT shared across two new players
[ ] SetAsync replaced with UpdateAsync + session lock
[ ] BindToClose — 6-player server shutdown — all profiles saved
[ ] New field added to mastery sub-table — existing player gets default on next load
```

### Exploits
```
[ ] Fire MixMinigameResult immediately after session start → rejected (< 3s)
[ ] Fire result remote with no active session → rejected
[ ] Fire result with station mismatch → rejected (already works)
[ ] Two players trigger dough at same time → second gets "already claimed"
[ ] Player fires drive-thru delivery without being order-taker → blocked
[ ] 1-pack box delivered for 4-pack drive-thru order → blocked or handled
```

### Multiplayer (test with 6 players)
```
[ ] All 6 trigger mix simultaneously → correct MAX_ACTIVE_BATCHES respected
[ ] Player disconnects mid-minigame → session cleared within SESSION_TIMEOUT
[ ] Player joins during Open phase → no tutorial lockout
[ ] State broadcasts don't flood during rapid batch completions
```

### Game Loop
```
[ ] Full cycle: PreOpen → Open → EndOfDay → Intermission → loops correctly
[ ] Skip PreOpen button works in Studio
[ ] Teleport landing is on floor, not above world
[ ] EndOfDay summary shows correct Employee of Shift
[ ] Rush hour fires at 70% of Open phase (after S-1 done)
```

### Drive Thru
```
[ ] Car arrives, window opens, prompt appears on car
[ ] Take order → KDS/TV updates with order details
[ ] Deliver correct box → coins awarded, car leaves
[ ] Timeout (90s) → car leaves, order cancelled
[ ] Drive-thru hidden when DriveThruUnlocked = false
```

### AI Workers
```
[ ] Hire worker → coins deducted, rig spawns at station
[ ] Worker mixes batch → progresses through full pipeline
[ ] Dismiss worker → rig destroyed, hire prompt text resets
[ ] EndOfDay → all workers auto-dismissed
```

### Challenges
```
[ ] Daily challenge progress updates after each delivery
[ ] Reward claimed once only, not twice
[ ] Challenge progress resets at midnight UTC
```

### Mobile
```
[ ] All ProximityPrompts reachable on phone (MaxActivationDistance ≥ 12)
[ ] No UI below bottom safe area
[ ] Minigame GUI touch targets ≥ 44px
[ ] Jump button hidden (JumpHeight=0 working)
[ ] Hire prompt ProximityPrompt button renders correctly on mobile
```

---

## ALREADY DONE (from previous sessions)
```
[x] P0-3: Minigame DisplayOrder bumped to 22 (above HUD at 20)
[x] P3-3: JumpHeight=0 in NoCollision.server.lua (CharacterAdded)
[x] P1-3: MenuServer remap debounce with _remapToken
[x] P2-1: WarmersUpdated sends stockByType; HUD StockPill shows per-type warmer counts
[x] P2-2: Star display shows "★★★☆☆  3/5" format
[x] P0-2: getFrontSpawnCF uses GameSpawn part dynamically
[x] P1-5: GetTopEmployee returns station field; board shows "Best Mixer/Baker/etc" subtitle
[x] NPCAvatarLoader: disabled with do return end (P3-2)
[x] Topping teleport fixed to Tutorial Dress Spawn (-20.09, 5, -33.38)
[x] AI Baker spawn CF updated to Tutorial Spawn X/Z
[x] M7 UI Polish: minigame GUIs, HUD, SummaryGui, TutorialUI
[x] PR #2 open: alpha-readiness-fixes → main on GitHub
```
