# Solo AI Mode — Design Doc
_2026-03-07_

## Overview

Players can hire up to 5 AI worker NPCs during PreOpen to staff the bakery solo. Workers are stationary — they don't walk around. The player assigns them to stations via ProximityPrompts. Workers autonomously process available work (batches/boxes) at their assigned station using a fixed 75% quality score. Delivery always stays with the human player. Workers are dismissed automatically at EndOfDay. Cost: 50 coins per worker per shift, deducted at hire time.

---

## Visuals

Workers are R15 rigs placed at the station they are assigned to.

- **Clothes:** Baker uniform (Shirt `rbxassetid://76531325740097`, Pants `rbxassetid://98693082132232`), applied via `HumanoidDescription`
- **Name tag:** BillboardGui above head showing a generated name (e.g. "Worker #1")
- **Status billboard:** Smaller BillboardGui showing current state:
  - `Idle` (grey) — waiting for work
  - `Mixing...` / `Baking...` / etc. (yellow) — working
  - `Done ✓` (green) — finished, waiting for player to collect result
- **Glow:** A green `SelectionBox` or `PointLight` while actively working
- **Animation:** Looped idle animation while waiting; the station's own visuals handle the "working" appearance

---

## Architecture

### New file: `src/ServerScriptService/Core/StaffManager.server.lua`

Responsible for:
1. Spawning hire ProximityPrompts at each station during PreOpen
2. Handling hire/dismiss logic and coin deduction
3. Running worker coroutines that poll for available work and call OrderManager directly
4. Cleaning up all workers at EndOfDay

### Key design choices

- **Bypasses MinigameServer entirely** — workers call `OrderManager` API directly with a hardcoded 75% score
- **No client remotes for workers** — all state is server-side; HUD/batch displays update via existing `BatchUpdated`/`WarmersUpdated` broadcasts which workers trigger naturally through OrderManager
- **One worker per station** — hiring a second worker at the same station replaces the first (or is blocked; TBD at impl)
- **Stations workers can staff:** `mix`, `dough`, `oven`, `frost`, `dress` (all 5 pipeline stations)

### Worker coroutine loop (pseudocode)
```lua
while workerActive do
    local work = pollForWork(station)  -- checks OrderManager for available batch/entry
    if work then
        showStatus("Working...")
        task.wait(stationDuration[station])  -- simulated work time
        callOrderManagerForStation(station, work, WORKER_QUALITY)
        showStatus("Idle")
    else
        task.wait(2)  -- poll interval
    end
end
```

### Hire flow
1. ProximityPrompts appear at each station during PreOpen (`GameStateChanged → "PreOpen"`)
2. Player walks up, presses E → server checks: player has enough coins, station not already staffed
3. Deduct 50 coins, spawn R15 rig at station with baker uniform, start worker coroutine
4. Prompt changes to "Dismiss [Name]" so player can fire a worker

### Dismiss / EndOfDay cleanup
- Player can dismiss any worker manually (refund: 0 coins — no partial refunds)
- All workers destroyed on `GameStateChanged → "EndOfDay"` signal

---

## Data flow

```
Player presses "Hire" at Mixer
  → StaffManager deducts 50 coins (PlayerDataManager.AddCoins)
  → Spawns worker rig at Mixer position
  → Coroutine: polls OrderManager.GetBatchAtStage("mix")
  → Calls OrderManager.TryStartBatch / RecordStationScore(75)
  → BatchUpdated fires → all clients see updated batch display
```

---

## Constraints

- Solo AI mode is available in **any** server size (1–6 players) — it's an option, not a game mode
- Workers do not compete with real players for batches — OrderManager's existing locking (session state) handles concurrency since workers call the same API
- No UI screen for "Staff Overview" at launch — workers are visible in-world; that's enough
- No persistence — workers don't carry over between sessions

---

## Station work durations (simulated)

| Station | Simulated duration |
|---------|--------------------|
| mix     | 8s                 |
| dough   | 6s                 |
| oven    | 12s                |
| frost   | 8s                 |
| dress   | 6s                 |

These mirror the minigame durations loosely so workers don't feel instant.

---

## Open questions (resolve at implementation)

1. Should hiring be blocked during a Rush Hour event? (Suggested: yes — no new hires mid-rush)
2. One worker per station or allow stacking? (Suggested: one per station, simpler)
3. Should oven workers auto-pull from fridge? (Suggested: yes, otherwise oven is unjammable)
