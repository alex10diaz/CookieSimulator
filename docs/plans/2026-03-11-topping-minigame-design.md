# Topping Minigame — Design Doc
**Date:** 2026-03-11
**Feature:** Dress station topping step (pre-playtest scope item #3)

---

## Overview

A short rapid-tap minigame inserted into the Dress station flow after all warmer pickups are complete, for any box containing a cookie with a `dress` field in CookieData. Affects dress quality score. Takes ~2–4 seconds to complete.

---

## Trigger Conditions

- Fires **after all warmer pickups are complete** — never mid-sequence
- Fires if **any** cookie in the collected box has `cookie.dress` (the `dress` field in CookieData)
- Does NOT fire for cookies that only have `needsFrost=true` — frost and toppings are orthogonal
- 43 of 60 cookies currently have a `dress` field; none of the 6 launch cookies (pink_sugar, chocolate_chip, etc.) overlap incorrectly

### Label logic (sent from server)
- Count unique `dress.label` values across all collected cookie types
- **Exactly one unique label** → send that label (e.g., "Cinnamon Sugar")
- **Multiple unique labels** → send `"Add Toppings"`
- Color: `toppingColor` from the first topping cookie found in collected set

---

## Mechanic

- Player taps **E** repeatedly
- Each tap fills the progress bar by **5%** (20 taps = 100%)
- A timer counts up from 0 while the minigame is active
- When bar hits 100%, the minigame completes automatically
- **No cancel button** — once triggered, the player must complete it

---

## Scoring

Score formula (server-side, applied to `dressScore` used in `CreateBox`/`CreateVarietyBox`):

```
score = clamp(100 - max(0, elapsed - 2) * 8, 40, 100)
```

| Elapsed | Score |
|---------|-------|
| ≤ 2s    | 100   |
| 3s      | 92    |
| 4s      | 84    |
| 5s      | 76    |
| 7.5s    | 60    |
| ≥ 10s   | 40    |

---

## Architecture (Option 1 — client-timed, server-validated)

### New remotes (2)
- `StartToppingMinigame` — server → client: `{ label, toppingColor }`
- `ToppingComplete` — client → server: `{ elapsed }`

### Server flow changes (DressStationServer)

Both `hookWarmerPrompt` paths (single-type and variety) currently call `CreateBox`/`CreateVarietyBox` immediately when all pickups are done. Both paths are modified:

```
all pickups done →
  check collected cookies for any cookie.dress
  → YES: fire StartToppingMinigame to client
         set dressLocked[player].awaitingTopping = true
         (preserve collected / lock data — do NOT create box yet)
  → NO:  create box immediately (unchanged behavior)
```

### ToppingComplete handler (new, in DressStationServer)
```
ToppingComplete.OnServerEvent:
  validate dressLocked[player] and dressLocked[player].awaitingTopping
  clamp elapsed: min 0.5s, max 10s (anti-cheat)
  score = clamp(100 - max(0, elapsed - 2) * 8, 40, 100)
  clear awaitingTopping flag
  create box with calculated score
  fire orderLocked {state="done", boxId=...} to client
```

### Disconnect safety
`dressLocked[player]` is already cleared in `PlayerRemoving` — preserved collected data is cleaned up automatically.

---

## UI (DressStationClient)

A centered ScreenGui (`ToppingMinigameGui`) replaces the warmer overlay when `StartToppingMinigame` fires.

```
┌────────────────────────────────────┐
│  ADD TOPPINGS                      │
│  Cinnamon Sugar                    │
│                                    │
│  [████████████░░░░░░░░]  60%       │
│                                    │
│  Tap  E  rapidly to shake!         │
│                                    │
│  ⏱  1.4s                           │
└────────────────────────────────────┘
```

- Progress bar color = `toppingColor` from server
- Timer label updates every frame via `RunService.Heartbeat`
- On bar hit 100%: brief result flash ("Perfect! 2.1s" / "Good! 3.8s" / "OK 5.2s"), GUI closes, `ToppingComplete` fired with elapsed time
- Movement locked (WalkSpeed/JumpHeight = 0) while GUI is open, restored on close
- `UserInputService.InputBegan` listens for `Enum.KeyCode.E` taps

---

## Files Modified

| File | Change |
|------|--------|
| `RemoteManager.lua` | Add `StartToppingMinigame`, `ToppingComplete` to REMOTES registry |
| `DressStationServer.server.lua` | Modify both `hookWarmerPrompt` paths; add `ToppingComplete` handler |
| `DressStationClient.client.lua` | Add `StartToppingMinigame` handler + full minigame UI |

---

## What Doesn't Change

- KDS order selection flow (unchanged)
- Warmer pickup sequence (unchanged)
- Box creation logic in OrderManager (unchanged — just called later with a different score)
- Existing `done` flash path reused for post-topping completion
