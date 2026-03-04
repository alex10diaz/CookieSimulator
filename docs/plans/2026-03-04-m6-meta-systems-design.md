# M6: Meta Systems — Design Document
**Date:** 2026-03-04
**Status:** Approved
**Milestone:** 6 of 7

---

## Scope

| System | Included |
|--------|----------|
| Rush Hour + Golden VIP events | ✅ |
| Session leaderboard (end-of-day) | ✅ |
| Global leaderboard (daily/weekly/all-time) | ✅ |
| Back room display boards | ✅ |
| Station + cosmetic unlock shop | ✅ |
| 3-slot save system + reset | ✅ |
| AntiExploit (session gating + sanity checks) | ✅ |
| Assist mode | ❌ M7 maybe |
| Cookie type unlocks | ❌ all 6 always open |

---

## 1. EventManager — Rush Hour + Golden VIP

### Overview
`ServerScriptService/Core/EventManager.server.lua` — new script. Runs only during the Open phase (10 minutes). Schedules one Rush Hour event per Open phase.

### Timing
- Open phase duration: **10 minutes**
- Rush Hour fires once at a random time between **minute 3 and minute 7**
- Rush Hour lasts **2 minutes**

### Rush Hour
- `PersistentNPCSpawner` spawn interval halved (e.g., 45s → 22s)
- VIP probability bumps from 10% → 20%
- Fires `RushHourStart` BindableEvent → `PersistentNPCSpawner` listens and adjusts its interval
- Fires `RushHourEnd` BindableEvent after 2 minutes → spawner reverts
- Broadcasts `RushHour` RemoteEvent to all clients → HUD shows banner with countdown ("RUSH HOUR — 1:47")

### Golden VIP
- Not a timed event — a rare NPC variant
- 5% chance during Rush Hour, 2% chance outside
- `isGoldenVIP = true` flag passed alongside `isVIP = true` in NPC spawn data
- 2× coin multiplier (vs 1.75× for regular VIP)
- Gold name tag on NPC billboard

### Decoupling
EventManager ↔ PersistentNPCSpawner communicate only through BindableEvents (`RushHourStart`, `RushHourEnd` in `ServerStorage/Events`). No direct require between them.

---

## 2. Leaderboards

### Storage
Roblox `OrderedDataStore` — one store per stat per timeframe, 9 total:
- `LB_Coins_AllTime`, `LB_Coins_Weekly`, `LB_Coins_Daily`
- `LB_Orders_AllTime`, `LB_Orders_Weekly`, `LB_Orders_Daily`
- `LB_Cookies_AllTime`, `LB_Cookies_Weekly`, `LB_Cookies_Daily`

Daily key suffix: `userId .. "_" .. os.date("%Y%m%d")`
Weekly key suffix: `userId .. "_" .. math.floor(os.time() / 604800)`

### Writing
New `LeaderboardManager` ModuleScript (`ServerScriptService/Core/LeaderboardManager.lua`).
Called from `PersistentNPCSpawner` after each delivery with `LeaderboardManager.RecordDelivery(player, coins, cookies, orders)`. Updates all 9 stores in one function call.

### Session Scoreboard
Lives in memory only. `SessionStats` already tracks per-player coins/orders/cookies per cycle. At end-of-day, server sends all players' totals to each client for the summary screen — two views:
- **This shift** — current day's stats
- **Total session** — accumulated since joining

### Back Room Display Boards
Three `SurfaceGui` panels on the back room walls — one per stat (Coins, Orders, Cookies). Each shows top 10 with player name + value. Tabs cycle through Daily / Weekly / All-Time.

`LeaderboardManager` refreshes boards every **60 seconds** by querying OrderedDataStore and firing `LeaderboardUpdate` RemoteEvent to all clients. Client-side script (`LeaderboardClient.client.lua`) updates the SurfaceGui TextLabels.

---

## 3. Unlock System + Save Slots

### Save Slots
Each player has 3 independent save slots stored as separate DataStore keys:
- `PlayerData_v1_{userId}_slot1`
- `PlayerData_v1_{userId}_slot2`
- `PlayerData_v1_{userId}_slot3`

A lightweight meta-key `PlayerSlotMeta_{userId}` stores which slot is currently active (1, 2, or 3). This meta-key is loaded first on join, then the active slot's full profile is loaded.

All existing systems (coins, XP, unlocks, tutorial flag, combo) read from whichever slot is active — no changes to downstream systems.

### Slot Selection Terminal
ProximityPrompt on a terminal in the back room opens `SlotSelectGui`. Shows 3 cards:
- Each card: slot number, level, total coins, unlock count — or "Empty" if never started
- Buttons per card: **Play** (switch to this slot), **Reset** (wipe to defaults, two-step confirmation)
- Slot switching is **between sessions only** — blocked during Open phase with message: *"You can switch stores between shifts."*

### Unlock Shop
New `UnlockManager` ModuleScript (`ServerScriptService/Core/UnlockManager.lua`).

Player data gains two new fields (per slot):
- `unlockedStations` — table of owned station upgrade IDs
- `unlockedCosmetics` — table of owned cosmetic IDs

**API:**
- `UnlockManager.GetCatalog()` — returns full item list (id, price, type, name, description)
- `UnlockManager.CanAfford(player, itemId)` — checks coins
- `UnlockManager.Purchase(player, itemId)` — deducts coins, updates profile, saves via PlayerDataManager
- `UnlockManager.Owns(player, itemId)` — bool check

**Catalog** is a static table inside `UnlockManager` — no DataStore needed for the catalog itself.

**Shop UI:** `ShopGui` in the back room (ProximityPrompt on shop counter). Two tabs: Stations | Cosmetics. Each item shows name, price, description, and Owned/Buy button. Client fires `PurchaseItem` remote → server validates → responds with `PurchaseResult {success, reason, newCoins}`.

**Station hooks** are stubs in M6 — `UnlockManager` fires `StationUnlocked` BindableEvent on purchase; station scripts will wire these in M7.

---

## 4. AntiExploit

No new script. Validation layer added directly to existing result handlers in `MinigameServer`.

### Session Gating
Every result handler (Mix, Dough, Oven, Frost, Dress) gets this guard at the top:
```lua
if not activeSessions[player.UserId] then
    warn("[AntiExploit] " .. player.Name .. " fired result with no active session")
    return
end
```

### Sanity Checks
After the session gate, validate incoming values before passing downstream:
- `quality` → must be number, clamped to `[0, 100]`
- `cookieId` → must match `activeSessions[player.UserId].cookieId` (assigned by server at session start)
- Any timing values → must be positive number, below reasonable ceiling (120s max)
- Wrong type on any parameter → drop silently with warn log

### Delivery Validation
Delivery result in `PersistentNPCSpawner` already validates box ownership. Add:
- Box carrier must match the requesting player
- `boxId` must exist in the active order table
- Stars clamped to `[1, 5]` after quality calculation

### Policy
Silent drop + warn log for violations. No kicks in M6 — logging is sufficient to identify exploit patterns before launch.

---

## New Scripts Summary

| Script | Type | Location |
|--------|------|----------|
| `EventManager.server.lua` | Script | SSS/Core |
| `LeaderboardManager.lua` | ModuleScript | SSS/Core |
| `LeaderboardClient.client.lua` | Script | StarterPlayerScripts |
| `UnlockManager.lua` | ModuleScript | SSS/Core |
| `ShopClient.client.lua` | Script | StarterPlayerScripts |

## Modified Scripts

| Script | Change |
|--------|--------|
| `PlayerDataManager.lua` | Add slot system, `unlockedStations`, `unlockedCosmetics` fields |
| `GameStateManager.server.lua` | Open phase duration 15min → 10min |
| `PersistentNPCSpawner` | Listen to RushHourStart/End, accept isGoldenVIP flag |
| `MinigameServer` | Add AntiExploit session gating + sanity checks to all 5 result handlers |
| `SessionStats.lua` | Add cookies-baked counter alongside coins/orders |

## New RemoteEvents

| Remote | Direction | Purpose |
|--------|-----------|---------|
| `RushHour` | Server→Client | Broadcast Rush Hour start/end + duration |
| `LeaderboardUpdate` | Server→Client | Push top-10 data to back room boards |
| `PurchaseItem` | Client→Server | Player requests item purchase |
| `PurchaseResult` | Server→Client | Confirm/deny purchase, return new coin total |
| `SlotSelect` | Client→Server | Player requests slot switch |
| `SlotSelectResult` | Server→Client | Confirm switch or explain block |

## New BindableEvents (ServerStorage/Events)

| Event | Purpose |
|-------|---------|
| `RushHourStart` | EventManager → PersistentNPCSpawner |
| `RushHourEnd` | EventManager → PersistentNPCSpawner |
| `StationUnlocked` | UnlockManager → station scripts (stub) |
