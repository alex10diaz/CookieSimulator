# Daily Challenges System — Design Doc

**Date:** 2026-03-10

---

## Goal

Give players 3 daily challenges that reset at midnight UTC, spanning easy/medium/hard difficulty. Completing a challenge awards coins automatically. Progress persists across sessions via DataStore.

---

## Decisions Made

| Decision | Choice |
|----------|--------|
| Reset cadence | Real-world 24-hour (midnight UTC) |
| Challenge variety | Mix of all types: deliveries, star ratings, cookie-type, combos/coins |
| Rewards | Coins only — Easy: 150, Medium: 300, Hard: 500 |
| Reward delivery | Auto-claimed on completion (no claim button) |
| UI surfaces | Back room board (SurfaceGui) + compact HUD widget during Open phase |
| Challenge selection | Deterministic daily seed (same 3 challenges for all players each day) |
| Cookie-type param | Picked from active menu using day seed — always achievable |

---

## Architecture

### New Files

| File | Type | Location |
|------|------|----------|
| `DailyChallengeManager.lua` | ModuleScript | `SSS/Core` |
| `DailyChallengeServer.server.lua` | Script | `SSS/Core` |
| `DailyChallengeClient.client.lua` | LocalScript | `StarterPlayerScripts` |

### New Remotes (added to RemoteManager)

| Remote | Direction | Payload |
|--------|-----------|---------|
| `DailyChallengesInit` | Server→Client | `{ challenges, progress, claimed, resetIn }` |
| `DailyChallengeProgress` | Server→Client | `{ index, progress, goal, completed, coinsAwarded }` |

### PlayerDataManager Extension

Add to default profile:
```lua
dailyChallenges = {
    date    = "",            -- "2026-069" (UTC year+yday)
    progress = {0, 0, 0},   -- per-challenge progress value
    claimed  = {false, false, false},
}
```

---

## Challenge Catalog

12 entries total. Each day picks one from each tier using `math.floor(dayIndex % tierCount) + 1`.

### Easy (reward: 150 coins)
1. `complete_orders_5` — "Complete 5 orders today" — `orders >= 5`
2. `five_stars_4`      — "Earn 4 five-star orders" — `fiveStars >= 4`
3. `combo_3`           — "Hit a combo streak of 3" — `peakCombo >= 3`
4. `cookie_type_8`     — "Bake 8 [cookie] cookies" — `cookieCount[targetId] >= 8`

### Medium (reward: 300 coins)
1. `complete_orders_12` — "Complete 12 orders today" — `orders >= 12`
2. `five_stars_6`       — "Earn 6 five-star orders" — `fiveStars >= 6`
3. `shift_coins_500`    — "Earn 500 coins in one shift" — `shiftCoins >= 500`
4. `unique_types_3`     — "Bake 6 cookies across 3+ types" — `uniqueTypes >= 3 AND total >= 6`

### Hard (reward: 500 coins)
1. `complete_orders_20` — "Complete 20 orders today" — `orders >= 20`
2. `five_stars_10`      — "Earn 10 five-star orders" — `fiveStars >= 10`
3. `combo_6`            — "Hit a combo streak of 6" — `peakCombo >= 6`
4. `total_baked_15`     — "Bake 15 cookies total" — `totalBaked >= 15`

### Parameterized challenge: `cookie_type`
- Server picks a cookie from today's **active 6-cookie menu** using the day seed
- Stored in challenge def as `{ ..., param = "chocolate_chip", paramLabel = "Chocolate Chip" }`
- Label rendered as `string.format(template, paramLabel)`

---

## Server Logic — DailyChallengeManager

```lua
-- Key functions:

GetTodayKey()
-- Returns "YYYY-DDD" UTC string (e.g. "2026-069")
-- Used as the date comparison key in player profiles

GetTodayChallenges()
-- Deterministic: uses os.date("!*t").yday + year as seed
-- Picks 1 challenge from each tier table using modulo
-- Resolves cookie_type param from MenuManager.GetActiveMenu()
-- Returns { easy={...}, medium={...}, hard={...} }

ResetIfNeeded(player, profile)
-- Compares profile.dailyChallenges.date vs GetTodayKey()
-- If different: wipes progress={0,0,0}, claimed={false,false,false}, updates date

RecordDelivery(player, data)
-- data: { stars, cookieId, shiftCoins, peakCombo, totalBaked, uniqueTypes, orders }
-- For each of the 3 active challenges, check if this delivery advances progress
-- If newly completed AND not yet claimed: award coins, mark claimed, fire DailyChallengeProgress

SendToPlayer(player)
-- Fires DailyChallengesInit with today's challenge defs + player's current progress/claimed
-- Called after ResetIfNeeded on join
```

---

## Server Wiring — DailyChallengeServer

```lua
-- On player join:
Players.PlayerAdded → ResetIfNeeded(player) → SendToPlayer(player)

-- On delivery:
deliveryResultRemote.OnServerEvent → RecordDelivery(player, {
    stars       = stars,
    cookieId    = cookieId,   -- from order data
    shiftCoins  = shiftCoins, -- from SessionStats
    peakCombo   = peakCombo,  -- from SessionStats
    totalBaked  = totalBaked, -- from SessionStats
    uniqueTypes = uniqueTypes,-- tracked in DailyChallengeManager per-player
    orders      = orders,     -- from SessionStats
})
```

**Note:** `shiftCoins`, `peakCombo`, `totalBaked`, `orders` come from `SessionStats.GetSummary()`. For per-delivery access, DailyChallengeManager maintains its own per-player session counters (reset each Open phase via `GameState == "Open"` listener).

---

## Client — DailyChallengeClient

### Back room board (SurfaceGui)
- Part placed at `(25, 8, -157)` in workspace, face = Front (-Z direction, facing into room)
- SurfaceGui `ChallengesBoard`, PixelsPerStud = 40
- 3 challenge rows, each showing: tier label, description, progress bar, reward amount
- Completed rows: green background, "✓ COMPLETE" replacing progress bar
- Header shows reset countdown updated every second via `os.time()`

### HUD widget
- Small Frame in `StarterGui/HUD`, bottom-left corner
- Visible only during `Open` game state (hidden otherwise)
- 3 lines: `⭐ 4/5   ⭐⭐ 2/6   ⭐⭐⭐ 0/6`
- Clicking it toggles to show full labels
- Updates on `DailyChallengeProgress` remote

### Completion flash
- Same pattern as delivery coin flash in HUDController
- Text: `"Challenge Complete! +150 coins"`
- Gold background, 2.5s Debris cleanup

### Data flow
```
DailyChallengesInit  → populate board + HUD widget on join
DailyChallengeProgress → update specific challenge row + HUD numbers + fire flash if newly completed
GameStateChanged("Open")  → show HUD widget
GameStateChanged(other)   → hide HUD widget
```

---

## Reset Countdown

```lua
-- Seconds until midnight UTC
local function secondsUntilReset()
    local t = os.date("!*t")
    return (23 - t.hour) * 3600 + (59 - t.min) * 60 + (60 - t.sec)
end
```

Displayed on back room board header, updated every second client-side.

---

## Testing Plan

1. Join game → board shows today's 3 challenges with `0/goal` progress
2. Complete an order → HUD widget updates live
3. Complete a challenge → flash fires, coins added to CoinsLabel, board row turns green
4. Rejoin same session → progress preserved (DataStore persisted)
5. Manually set `profile.dailyChallenges.date = "0000-000"` → on next join, progress resets to 0
6. Verify `GetTodayChallenges()` returns same result across multiple calls in same UTC day

---

## Files to Create / Modify

| Action | File |
|--------|------|
| Create | `src/ServerScriptService/Core/DailyChallengeManager.lua` |
| Create | `src/ServerScriptService/Core/DailyChallengeServer.server.lua` |
| Create | `src/StarterPlayerScripts/DailyChallengeClient.client.lua` |
| Modify | `src/ReplicatedStorage/Modules/RemoteManager.lua` — add 2 remotes |
| Modify | `src/ServerScriptService/Core/PlayerDataManager.lua` — add `dailyChallenges` default field |
