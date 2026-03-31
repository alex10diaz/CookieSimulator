# Tutorial Kitchen — Design Doc
**Date:** 2026-03-30

## Problem
New players joining mid-game trigger the tutorial inside the live bakery. Tutorial cookies bleed into the real pipeline (OrderManager, fridges, ovens, warmers). Game state transitions (EndOfDay, Intermission) sweep tutorial players along. Two simultaneous new players compete for the same real stations.

## Solution
A standalone Tutorial Kitchen — a separate physical area in the same workspace. New players are routed there on join, complete the tutorial in full isolation, then teleport to the main bakery.

---

## Physical Layout (Workspace)
Folder: `TutorialKitchen`
Contents:
- `TutorialMixer` — Mix station with ProximityPrompt
- `TutorialDoughTable` — Dough table with ProximityPrompt
- `TutorialFridge` — Single fridge with ProximityPrompt
- `TutorialOven` — Single oven with ProximityPrompt
- `TutorialDressStation` — Dress/pack station with ProximityPrompt
- `TutorialCustomer` — Static NPC dummy model with delivery ProximityPrompt
- `TutorialKitchenSpawn` — SpawnLocation for new players

Location: underground or behind the store (user builds the room).

---

## Server Architecture

### New: `TutorialKitchen.server.lua` (SSS)
Completely standalone — zero dependency on MinigameServer or OrderManager.

Responsibilities:
- Owns ProximityPrompts on all tutorial stations
- Fires the same `StartMixMinigame` / `StartDoughMinigame` / `StartOvenMinigame` remotes that MinigameServer uses → client minigame UIs work unchanged
- Listens for result remotes back, gated to tutorial players only
- Tracks per-player step progress in a local table
- On completion: grants 200 coins, sets `tutorialCompleted=true`, clears `InTutorial`, teleports to `GameSpawn`
- Handles skip: same result as completion

### Modified: `TutorialController.server.lua` (SSS)
Gutted to a single responsibility:
- On `PlayerAdded`: check `tutorialCompleted`
- If false → set `InTutorial=true`, teleport to `TutorialKitchenSpawn`
- If true → normal `GameSpawn` routing (existing behavior)
- All step logic, warmer hooks, fridge arrow code removed

### Modified: `GameStateManager`
`teleportAllTo()` adds one guard:
```lua
if player:GetAttribute("InTutorial") then continue end
```
Tutorial players are never swept by EndOfDay or Intermission teleports.

### Removed from `TutorialController`
- `setTutorialWarmersEnabled()` — no longer needed (tutorial kitchen has its own stations)
- `showFridgeArrow()` / `hideFridgeArrow()` — moves to TutorialKitchen, points at TutorialFridge
- All station teleport calls to main kitchen spawn parts

### `TutorialUI.client.lua`
Unchanged — step panel, skip button, hire prompt hiding all still work via `InTutorial` attribute.

---

## Player Join Flow

```
PlayerAdded
  └─ tutorialCompleted == false?
       ├─ YES → teleport to TutorialKitchenSpawn, set InTutorial=true
       │         TutorialKitchen.server.lua drives 5 steps
       │         On complete → clear InTutorial, teleport to GameSpawn
       └─ NO  → teleport to GameSpawn (existing behavior)
```

---

## Multi-Player Tutorial
Two new players share the tutorial kitchen. Since steps are sequential (Mix → Dough → Fridge → Oven → Dress → Deliver), they'll naturally be at different stations simultaneously. No locking needed.

---

## Edge Cases Handled
| Scenario | Behavior |
|---|---|
| New player joins during Open | Routes to tutorial kitchen, isolated from live pipeline |
| New player joins during Intermission | Routes to tutorial kitchen, skipped by teleportAllTo |
| New player joins during EndOfDay | Routes to tutorial kitchen, skipped by teleportAllTo |
| Two new players join at once | Share tutorial kitchen, different stations, no conflict |
| Player skips tutorial | Completes same as finish — teleports to GameSpawn |
| Tutorial player disconnects mid-step | InTutorial clears on PlayerRemoving, session cleaned up |

---

## What Changes in the Main Kitchen
| Item | Change |
|---|---|
| Tutorial spawn parts near real stations | Deleted |
| TutorialController step logic | Deleted (moves to TutorialKitchen) |
| `setTutorialWarmersEnabled()` in StaffManager/TutorialController | Deleted |
| Fridge arrow on main `fridge_chocolate_chip` | Deleted (new arrow on TutorialFridge) |
| Tutorial NPC in main kitchen area | Deleted (TutorialCustomer in tutorial kitchen) |
| MinigameServer / OrderManager | Unchanged — cleaner, never touched by tutorial players |

---

## Files Touched
- `src/ServerScriptService/Core/TutorialController.server.lua` — gut to router only
- `src/ServerScriptService/TutorialKitchen.server.lua` — new file
- `src/ServerScriptService/Core/GameStateManager.server.lua` — add InTutorial guard to teleportAllTo
- `src/StarterPlayer/StarterPlayerScripts/TutorialUI.client.lua` — minor: update fridge arrow target if needed
- Workspace: user builds TutorialKitchen room and stations
