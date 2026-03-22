# Cookie Empire: Master Bakery — Codex Context Report
*Generated 2026-03-21 for use with the DEBUG, FIX, AND BREAK TEST Codex prompt*

---

## 1. Game Overview

**Genre:** Multiplayer co-op bakery simulator (Crumbl Cookie-inspired), 2–6 players
**Platform:** Roblox (Lua 5.1 / Luau)
**Studio sync method:** MCP `run_code` only — Rojo is NOT active. Disk files in `src/` are the source of truth but must be pushed to Studio manually via the MCP plugin after every change.
**GitHub repo:** https://github.com/alex10diaz/CookieSimulator (branch: main)

### Session Loop
```
Tutorial (first join) → PreOpen (5 min) → Open (15 min) → EndOfDay (30s summary) → Intermission (3 min) → PreOpen …
```

### Cookie Types (6)
| ID | Display Name | Needs Frost |
|----|-------------|------------|
| pink_sugar | Pink Sugar | Yes |
| chocolate_chip | Chocolate Chip | No |
| birthday_cake | Birthday Cake | Yes |
| cookies_and_cream | Cookies & Cream | No |
| snickerdoodle | Snickerdoodle | No |
| lemon_blackraspberry | Lemon Black Raspberry | Yes |

### Production Pipeline (per batch)
```
Mix station → Dough Table → Fridge (per cookieId) → Oven → [Frost if needsFrost] → Warmers → Dress/Pack → Box → Deliver to NPC
```
Cookies that don't need frost skip the Frost station. Cookie-type awareness is enforced in `OrderManager.lua` via the `CookieData` module.

---

## 2. Architecture Overview

### Authority Model
- **Server is authoritative** for all game state, scoring, economy, data persistence, and session gating.
- **Client** handles visuals, UI, input, and fires RemoteEvents to server; server validates before acting.
- All payout math lives in `EconomyManager` (SSS/Core — server-only, not client-readable).

### State Machine (GameStateManager)
States: `Lobby → Loading → PreOpen → Open → EndOfDay → Intermission → PreOpen …`
`GameState` attribute is written to `Workspace` so all server scripts can read it without a remote.
`GameStateChanged` RemoteEvent broadcasts to all clients on every transition.

### Remote Architecture
All RemoteEvents live in `ReplicatedStorage/GameEvents`.
The single source of truth for remote names is `ReplicatedStorage/Modules/RemoteManager.lua` — a REMOTES string table. Server creates all remotes at startup; clients call `RemoteManager.Get(name)` to wait for them.

**Never create remotes inside loops or dynamically during gameplay.**

### Key Remotes (partial list)
| Remote | Direction | Purpose |
|--------|-----------|---------|
| GameStateChanged | S→All | Phase transitions |
| StartMixMinigame | S→Client | Begin mix UI |
| MixMinigameResult | C→S | Player submits mix |
| StartDoughMinigame | S→Client | Begin dough UI |
| DoughMinigameResult | C→S | Player submits dough |
| StartOvenMinigame | S→Client | Begin oven UI |
| OvenMinigameResult | C→S | Player submits oven |
| StartFrostMinigame | S→Client | Begin frost UI |
| FrostMinigameResult | C→S | Player submits frost |
| NPCOrderAdded | S→All | New NPC order appeared |
| NPCOrderFulfilled | S→All | Order delivered |
| NPCPatienceUpdate | S→All | orderId, current, max patience |
| DeliveryResult | S→Client | Delivery confirmed (triggers cash sound) |
| BoxCreated | S→All | box metadata (for quality flash) |
| EndOfDaySummary | S→Client | Summary payload |
| ComboUpdate | S→Client | Current combo streak |
| StationBillboardUpdate | S→All | Station active/inactive (in-world billboard) |
| DailyChallengesInit | S→Client | Join payload |
| DailyChallengeProgress | S→Client | Per-delivery update |
| LeaderboardUpdate | S→All | Leaderboard scores |
| AddCoins | S→Client | Coin grant (UI feedback) |
| StationRemapped | S→All | After Intermission remap |
| EndOfDaySummary | S→Client | Summary data |

---

## 3. File Map

### ServerScriptService/
```
GameController.server.lua          — Player lifecycle, shift data accumulation, EndOfDay trigger
Core/
  GameStateManager.server.lua      — State machine; teleports players on phase change
  RoundManager.server.lua          — (Legacy stub — most logic moved to GameStateManager)
  OrderManager.lua                 — ModuleScript: full batch/order pipeline API
  PlayerDataManager.lua            — ModuleScript: DataStore CRUD, profile schema, deepCopy, mergeDeep
  PlayerStateService.lua           — Tracks per-player carry state (box/pan)
  EconomyManager.lua               — Payout math, coin grants (server-only)
  StaffManager.server.lua          — AI worker loops (Frost AI, Dress AI), hire prompts
  PersistentNPCSpawner.server.lua  — NPC spawning, patience ticking, order delivery, combo/stars
  DriveThruServer.server.lua       — Drive-thru lane: car arrival, window prompt, delivery
  StationRemapService.server.lua   — On Open start: remaps warmers+fridges to active menu
  LeaderboardManager.server.lua    — Periodic leaderboard broadcast (30s during Open)
  WinConditionService.server.lua   — Detects end-of-day trigger conditions
  DailyChallengeServer.server.lua  — Wires DailyChallengeManager to game events
  DailyChallengeManager.lua        — ModuleScript: 12-challenge catalog, 3 tiers, daily seed
  AIBakerSystem.server.lua         — AI baker NPC for solo/low-count play
  TutorialManager.server.lua       — Gated tutorial step logic
Minigames/
  MinigameServer.server.lua        — Session management for all 4 minigame stations
  MixMinigame.server.lua           — Mix scoring logic
  DoughMinigame.server.lua         — Dough scoring logic
  OvenMinigame.server.lua          — Oven scoring logic
  FrostMinigame.server.lua         — Frost checkpoint scoring logic
```

### ReplicatedStorage/Modules/
```
RemoteManager.lua    — REMOTES table + Get(name) factory
OrderManager.lua     — (Mirror) Same module required by both S and C contexts? CHECK: should only be server-required for write ops; clients only read stock displays via remotes
CookieData.lua       — Cookie definitions (NeedsFrost, doughColor, displayName)
MinigameBase.lua     — NewTracker() connection tracker utility
NPCSpawner.lua       — Client-safe NPC helper (MoveTo, pathfinding)
```

### StarterPlayerScripts/
```
UIController.client.lua              — Central UI wiring hub
SoundController.client.lua           — Mixer whir, oven ding, cash register sounds
DailyChallengeClient.client.lua      — HUD widget bottom-left
MasteryClient.client.lua             — Station mastery display
LifetimeChallengeClient.client.lua   — Lifetime challenge progress
WeeklyChallengeClient.client.lua     — Weekly challenge progress
Minigames/
  MixController.client.lua           — Mix minigame UI
  DoughController.client.lua         — Dough minigame UI
  OvenController.client.lua          — Oven minigame UI
  FrostController.client.lua         — Frost checkpoint UI
```

### StarterGui/
```
HUD/HUDController.client.lua         — Timer, coins, order pills, patience bars, coach marks, combo
SummaryGui/SummaryController.client.lua — End-of-day summary panel
MainMenuGui/                         — Lobby/starting screen
TutorialGui/                         — Tutorial overlay
```

---

## 4. OrderManager Pipeline (Critical)

**File:** `src/ReplicatedStorage/Modules/OrderManager.lua` (~430 lines)

### State Tables
```lua
batches       -- [batchId] = { cookieId, stage, quality, scores, status, startedAt, playerId }
fridges       -- [cookieId] = { batchId, ... }[]  (list, FIFO)
ovenBatches   -- [batchId] = { ... }
warmers       -- [warmerId] = { batchId, cookieId, quality }
boxes         -- [boxId]   = { cookieId, quality, carrier, orderId, status }
```

### Key API
- `TryStartBatch(player, cookieId)` — dynamic cap: `math.max(MIN_ACTIVE_BATCHES, #Players:GetPlayers())`
- `RecordStationScore(batchId, stage, score)` — validates stage matches before accepting; advances pipeline
- `PullFromFridge(cookieId)` — removes first entry from fridge[cookieId] list (FIFO)
- `TakeFromWarmersByType(cookieId)` — finds first non-taken warmer slot of that type
- `IsCarryingBox(player)` — checks `box.carrier == player.Name and box.status == "carrying"`

### Stage Progression
```
"mix" → "dough" → "oven" → (needsFrost: "frost") → "warmer" → "dress" → "delivered"
```
If a player submits a score for the wrong stage, `RecordStationScore` silently drops it.

### Known Concern
`RecordStationScore` currently does not verify the calling player actually started the session — any server-side call with a valid batchId and correct stage will succeed. Exploits via RemoteEvent fire-as-server are theoretically possible only if a script on the server calls it with fabricated data, which would require a server-side exploit (RCE). Client-fired exploits go through MinigameServer which checks `activeSessions[player]`.

---

## 5. Session Management (MinigameServer)

**File:** `src/ServerScriptService/Minigames/MinigameServer.server.lua`

### Session Lifecycle
```lua
activeSessions[player] = {
    station    = "mix"|"dough"|"oven"|"frost",
    batchId    = string,
    startedAt  = tick(),
    stationModel = Model,   -- for billboard
}
```

### Anti-Exploit Measures (already implemented)
1. **startedAt timestamp** — server records when session started; result submissions checked against minimum elapsed time.
2. **doughLock[batchId]** — prevents two players grabbing the same dough batch simultaneously.
3. **Session gate** — player must have an active session to submit a result; orphan remotes are dropped.
4. **60-second watchdog** — sessions auto-expire after 60s to prevent players being locked indefinitely.

### Known Gap
The minimum time check (`startedAt`) prevents instant-submit exploits, but the threshold values should be reviewed — if thresholds are too low (e.g., 1s), a speed-hack could still submit unrealistically fast.

---

## 6. Data Persistence (PlayerDataManager)

**File:** `src/ServerScriptService/Core/PlayerDataManager.lua`

### Profile Schema (DEFAULT_PROFILE)
```lua
{
    coins        = 0,
    totalOrders  = 0,
    totalCoins   = 0,
    cookiesEver  = {},     -- [cookieId] = count
    mastery      = {},     -- [station] = { xp, level }
    upgrades     = {},     -- purchased upgrade ids
    dailyChallenges = {},  -- { seed, claimed[], progress{} }
    unlockedCookies = {},
    bakeryName   = "",
    bakeryLevel  = 1,
    bakeryStars  = 0,
}
```

### Reliability Fixes (already applied)
- **C-1 deepCopy**: `newProfile()` deep-copies DEFAULT_PROFILE — prevents shared nested table references across players.
- **C-2 SESSION_ID + UpdateAsync lock**: Each server instance has a unique `SESSION_ID = HttpService:GenerateGUID(false)`. `UpdateAsync` checks if the lock matches before overwriting — detects cross-server save conflicts.
- **M-1 mergeDeep**: `mergeDeep(defaults, saved)` recursively merges sub-tables so new schema fields added in code are populated for existing players without wiping saved data.
- **M-3 Parallel BindToClose**: All player saves run in parallel via `task.spawn` during server shutdown.
- **DataStore key:** `"PlayerData_v1"`

### Remaining Risk
If a player joins two servers simultaneously (rare but possible in Roblox), the SESSION_ID lock reduces but does not eliminate the risk of a save collision — the second `UpdateAsync` will see a mismatch and abort. This could cause coin/progress loss. A retry with backoff is not implemented.

---

## 7. Economy (EconomyManager)

**File:** `src/ServerScriptService/Core/EconomyManager.lua` (server-only)

- **Moved from ReplicatedStorage/Modules to SSS/Core** — clients can no longer require it.
- `CalculatePayout(cookieId, quality, multipliers)` — base payout by cookie tier × quality multiplier.
- Rush hour 1.5× multiplier applied during peak Open time window.
- Tip upgrade lookup from player's `upgrades` table.
- Coins are granted server-side only via `PlayerDataManager.AddCoins(player, amount)` then a `AddCoins` RemoteEvent to update client display.

---

## 8. NPC System (PersistentNPCSpawner)

**File:** `src/ServerScriptService/Core/PersistentNPCSpawner.server.lua` (~610 lines)

### NPC Data
```lua
npcs[npcId] = {
    model       = Model,
    state       = "spawning"|"walking_in"|"waiting_in_queue"|"seated"|"at_counter"|"leaving",
    order       = { orderId, cookieId, ... } or nil,
    patience    = number (seconds remaining),
    maxPatience = number (set at creation),
    combo       = tracked in GameController shift data,
}
```

### Patience Ticker
- Runs every 1s per NPC.
- Fires `NPCPatienceUpdate:FireAllClients(orderId, current, maxPatience)` every 5 ticks when NPC is seated/at_counter and has an order.
- On patience = 0: NPC leaves angry, 0 coins, 1-star rating.

### Delivery Path
```
TakeFromWarmersByType → CalculatePayout → AddCoins → RecordDelivery → DailyChallengeManager.RecordDelivery → EndOfDay accumulation
```

### Known Concern (P0-NEW-3 — under review)
NPCAvatarLoader was confirmed to still reference `GetFriendsAsync` to load NPC appearances from friends list. This can fail with rate limits and can cause inappropriate avatar appearances. The fix (force NPCTemplate fallback) was listed as needed but user confirmed "good" in last session — verify current Studio state.

---

## 9. Drive-Thru System

**File:** `src/ServerScriptService/Core/DriveThruServer.server.lua`

- Car arrives at `DriveThruDeliveryZone` part at (-34.66, 2.03, -15).
- `WINDOW_TIMEOUT = 90s`, `TAKE_TIMEOUT = 60s` — already set.
- Requires `DriveThruUnlocked` flag — currently defaults to `true` (always unlocked). Gate behind a real unlock condition before launch.
- NPC position: confirmed inside car mesh, not standing outside — P3-1 is still open.

---

## 10. What Has Already Been Fixed (Do Not Re-Report)

The following issues were identified and resolved in the alpha audit session (2026-03-21):

| Item | Fix |
|------|-----|
| **S-2** | Station billboard (BillboardGui) appears in-world when a minigame session is active; goes dark on end/timeout/cancel |
| **S-5** | SoundController.client.lua created — mixer loop, oven ding, cash register sounds |
| **S-6** | Patience bars on order pills in HUD (green→orange→red tween, NPCPatienceUpdate remote) |
| **S-7** | Coach mark at bottom of screen showing pipeline steps for first 3 orders |
| **S-8** | Quality flash card when player's box is ready (BoxCreated remote) |
| **S-10** | LeaderboardManager enabled, periodic 30s broadcast during Open |
| **C-1** | PlayerDataManager deepCopy on DEFAULT_PROFILE |
| **C-2** | SESSION_ID + UpdateAsync cross-server conflict lock |
| **m-6** | EconomyManager moved to SSS/Core (no longer client-readable) |
| **m-9** | StaffManager HirePrompt duplicate anchor cleanup before creating |
| **m-10** | GameStateManager startup race: polling loop instead of blind task.wait |
| **UI-3** | HUD cookie name abbreviations expanded (Pink Sugar, Choc Chip, etc.) |
| **UI-7** | Summary star display includes numeric "N/5" |
| **UI-10** | Hire prompt MaxActivationDistance increased to 10 |
| **P0-2** | Player teleports outside store on shift 2 — getFrontSpawnCF uses GameSpawn part dynamically |
| **P1-5** | Employee of Shift — GetTopEmployee returns station field, shows "Best Mixer/Baker/etc" |
| **P2-2** | Star display includes numeric N/5 |

---

## 11. Remaining Known Issues (Open at Time of Report)

| ID | Priority | Description |
|----|----------|-------------|
| P1-3 | High | Cookie/station mismatch after menu change mid-shift — StationRemapService fires before menu committed |
| P1-6 | Med | Main menu / lobby screen not fully polished |
| P1-7 | Med | Tutorial UI not fully polished |
| P1-8 | Med | 3 in-store screen displays need content + polish |
| P2-1 | Med | Cookie count HUD shows per-type warmer stock (not aggregate) |
| P3-1 | Low | Drive-thru NPC is inside car model, should be visible outside window |
| P3-3 | Low | Players can still jump/climb (JumpHeight=0 not enforced on CharacterAdded) |
| P3-4 | Low | No exterior environment around store |
| P3-5 | Low | Mobile integration not fully audited |
| P3-6 | Low | Drive-thru always unlocked (DriveThruUnlocked defaults true) |
| P4-1 | Low | Lifetime challenge thresholds too low |

---

## 12. Multiplayer Stress Concerns

These are architectural risks that have NOT been load tested:

1. **Batch cap race**: `TryStartBatch` reads `#Players:GetPlayers()` at call time — two players calling simultaneously could both read the same count and both get slots, exceeding the intended cap by 1.

2. **doughLock contention**: `doughLock[batchId]` is set synchronously in a single-threaded Lua context, so it is safe. However, if MinigameServer ever uses `task.spawn` around the lock check, a TOCTOU race becomes possible.

3. **OrderManager state tables**: All tables are module-level globals shared across requires. If two server scripts ever require OrderManager and call write APIs simultaneously, Lua's cooperative multithreading (yields only at task.wait/async calls) prevents true races — but any `task.wait` inside a write path could allow interleaving. Audit all write functions for mid-path yields.

4. **NPC patience ticker**: Runs `task.wait(1)` per NPC in separate coroutines. With 20+ NPCs during rush, this creates 20 concurrent coroutines — manageable but worth monitoring.

5. **RemoteEvent spam**: `NPCPatienceUpdate` fires every 5 ticks per NPC to ALL clients. With 6 players and 10 active NPCs, that's 10 remotes/5s = 2/s. Acceptable, but scale check needed for 20 NPCs.

6. **PlayerDataManager BindToClose**: Parallel saves via `task.spawn` are good, but the 30s Roblox shutdown budget may not be enough if DataStore is backed up. No retry or queue exists.

---

## 13. Client Exploit Surface

The following RemoteEvent handlers on the server accept client input — each should be audited:

| Remote | Handler Location | Input Validated? |
|--------|-----------------|-----------------|
| MixMinigameResult | MinigameServer | ✅ session check + timing |
| DoughMinigameResult | MinigameServer | ✅ session check + doughLock |
| OvenMinigameResult | MinigameServer | ✅ session check + timing |
| FrostMinigameResult | MinigameServer | ✅ session check |
| ConfirmNPCOrder | OrderManager path | ❓ verify player owns the box being delivered |
| TakeFromWarmer (via prompt) | StaffManager? | ❓ verify player is in range server-side |
| CancelMinigame | MinigameServer | ✅ clears own session only |

**Key exploit vector to check:** Can a client fire `ConfirmNPCOrder` or `DeliveryResult` without actually carrying a box? If `IsCarryingBox` is only checked client-side, a remote fire would grant coins without delivering.

---

## 14. Performance Hotspots

1. **Per-frame loops**: Search codebase for `RunService.Heartbeat` / `RunService.RenderStepped` connections — any that do non-trivial work per frame are candidates for polling instead.
2. **Instance creation in loops**: `StaffManager` AI dress worker creates box Parts each iteration — verify these are cleaned up properly.
3. **BillboardGui updates**: `FridgeDisplayServer` refreshes every 5s — acceptable.
4. **Repeated `:FindFirstChild` traversal**: Some station hookup code traverses full descendant trees — cache results where possible.
5. **`GetDescendants()` in hookWarmerModel**: Called once at setup, not per-frame — acceptable.

---

## 15. Architecture Concerns for Codex Review

1. **OrderManager is in ReplicatedStorage**: This means clients can require it and call read functions. While write functions are server-only (they fire no client remotes that grant rewards), clients reading internal tables is a data leak. Consider moving to SSS or using a server-side proxy.

2. **No input sanitization on player names/text**: If any player-provided text is rendered in SurfaceGuis or BillboardGuis, it's an XSS-equivalent risk (script injection via TextLabel).

3. **Module-level state in OrderManager**: All batch/order data is in module-level tables. If the server ever hot-reloads a module (unlikely in production Roblox, but possible via admin scripts), all in-flight orders would be lost.

4. **Tutorial gating**: `TestNPCSpawner` was kept alive because it's needed for tutorial step 9 gate — it was supposed to be removed in M7 but deferred. Leaving debug spawners in production is a risk.

5. **AI workers (StaffManager) read GameState from Workspace attribute**: This is correct and consistent, but if any script sets the attribute incorrectly, AI workers could activate during wrong phases.

---

## 16. Test Matrix for Codex

### Unit-Level
- [ ] `OrderManager.TryStartBatch` with exactly `MIN_ACTIVE_BATCHES` players — can excess be triggered?
- [ ] `RecordStationScore` with wrong stage — confirm silent drop, no state corruption
- [ ] `PlayerDataManager.newProfile` — confirm nested tables are independent between two calls
- [ ] `mergeDeep` — new field in DEFAULT_PROFILE appears in loaded profile, existing fields preserved

### Multiplayer
- [ ] 6 players all start Mix simultaneously — confirm cap respected
- [ ] Two players grab same dough batch — confirm doughLock prevents both succeeding
- [ ] Player disconnects mid-session — confirm watchdog clears session within 60s, batch not permanently locked
- [ ] Player rejoins after disconnect — profile loaded correctly, not blank

### Exploit
- [ ] Fire MixMinigameResult without having started a session — confirm dropped server-side
- [ ] Fire MixMinigameResult 0.1s after session start — confirm timing gate blocks it
- [ ] Fire ConfirmNPCOrder without carrying a box — confirm no coins granted
- [ ] Require OrderManager from client — confirm no write function can be called that grants rewards

### State Machine
- [ ] State transitions under load — confirm no double-transitions (EndOfDay fires twice, etc.)
- [ ] Intermission cleanup — confirm all NPC models removed, orders cleared, warmers reset

### Data
- [ ] Join → play → leave before save (disconnect) — data saved?
- [ ] Server shutdown with 6 active players — all profiles saved within 30s budget?
- [ ] Same player joins two servers simultaneously (alt account test) — no coin duplication?

---

## 17. Directory Quick Reference for Codex

```
src/
  ServerScriptService/
    GameController.server.lua
    Core/
      GameStateManager.server.lua
      OrderManager.lua               ← PIPELINE AUTHORITY
      PlayerDataManager.lua          ← DATA AUTHORITY
      EconomyManager.lua             ← PAYOUT AUTHORITY (server-only)
      PersistentNPCSpawner.server.lua
      StaffManager.server.lua
      DriveThruServer.server.lua
      StationRemapService.server.lua
      LeaderboardManager.server.lua
      DailyChallengeManager.lua
      DailyChallengeServer.server.lua
      AIBakerSystem.server.lua
      TutorialManager.server.lua
    Minigames/
      MinigameServer.server.lua      ← SESSION AUTHORITY
      MixMinigame.server.lua
      DoughMinigame.server.lua
      OvenMinigame.server.lua
      FrostMinigame.server.lua
  ReplicatedStorage/
    Modules/
      RemoteManager.lua              ← REMOTE REGISTRY
      OrderManager.lua               ← (accessible to client — review)
      CookieData.lua
      MinigameBase.lua
      NPCSpawner.lua
  StarterPlayerScripts/
    UIController.client.lua
    SoundController.client.lua
    DailyChallengeClient.client.lua
    MasteryClient.client.lua
    LifetimeChallengeClient.client.lua
    WeeklyChallengeClient.client.lua
    Minigames/
      MixController.client.lua
      DoughController.client.lua
      OvenController.client.lua
      FrostController.client.lua
  StarterGui/
    HUD/HUDController.client.lua
    SummaryGui/SummaryController.client.lua
    MainMenuGui/…
    TutorialGui/…
```

---

*End of report. Attach this document to your Codex prompt as pre-context before the 9-task instruction block.*
