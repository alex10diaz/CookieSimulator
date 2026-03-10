# Station Remap + Intermission Phase — Design Doc
**Date:** 2026-03-10
**Scope:** Approach C (Phase 1 of 2)

---

## Overview

Two coupled features:
1. **Station Remap** — When the menu is confirmed at Open start, physically remap warmers and fridges to reflect the player-selected 6 cookies (labels, colors, CookieId attributes).
2. **Intermission Phase** — New game state after EndOfDay where players teleport to the back room for 5 minutes to review results and plan next shift. Cookie shop and upgrades plug in here later.

---

## Feature 1: Station Remap

### Trigger
`MenuLocked` fires when the game transitions to `Open`. At this exact moment, the server performs the remap using the confirmed active menu from `MenuManager.GetActiveMenu()`.

### Slot Assignment
The active menu is an ordered array (order cookies were checked in the MenuBoard — first checked = slot 1). Warmers and fridges are sorted by their `WarmerId` attribute (1–6). Slot 1 cookie → Warmer/Fridge with WarmerId=1, etc.

### Server-side Remap (`StationRemapService` or inside `MenuServer`)
For each warmer model in `workspace.Warmers`:
- Read `WarmerId` attribute → look up cookie at that slot index in the menu
- Set `CookieId` attribute to the new cookieId
- Update `TextLabel` (name display) to `cookie.name`
- Update `DoorPanel.Color` to `Color3.fromRGB(cookie.doughColor)` as an accent

For each fridge model in `workspace.Fridges` (with a `FridgeId` attribute):
- Same slot mapping: WarmerId-equivalent = fridge sort order (1–6 by existing FridgeId sort)
- Set `FridgeId` attribute to `cookie.fridgeId`
- Update `FridgeDisplay.CookieName.Text` to `cookie.name`

Fire `StationRemapped` remote → all clients receive `{slot → cookieId}` mapping for any client-side UI that needs it.

### Timing / Safety
- Remap happens AFTER `MenuLocked` fires (warmers are always empty at shift start — no in-flight cookies to corrupt)
- OrderManager's warmer tracking reads `CookieId` attribute at runtime, so it automatically follows the remap
- FridgeDisplayServer reads `FridgeId` attribute, so fridge stock billboards auto-update

### What doesn't change
- Physical positions of warmers/fridges in the world
- Warmer/fridge model names (still `Warmer_pink_sugar` etc. — just attribute/label/color changes)
- All downstream logic (MinigameServer, DressStationServer, FridgeOvenSystem) already reads `CookieId` from attributes

### Fade Coverage
The MenuClient fade-to-black fires on "Set Menu" click and fades back after `MenuSelectionResult` success. The server-side remap fires on `MenuLocked` (Open start). If the board is already closed by then, the remap just happens without a cutaway. To ensure the visual swap is hidden, the remap should fire during or just after the fade window — the existing fade on menu confirm covers this naturally since Open fires shortly after.

---

## Feature 2: Intermission Phase

### State Flow
```
PreOpen (5min) → Open (10min) → EndOfDay (30s) → Intermission (5min) → PreOpen ...
```

### Constants (GameStateManager)
```lua
local INTERMISSION_DURATION = 5 * 60  -- 5 minutes, tunable
```

### Teleport
On `Intermission` start:
- Server teleports all players' `HumanoidRootPart` (or uses `Character:SetPrimaryPartCFrame`) to the back room SpawnLocation at ~`(0, 2, -127)` (center of back room)
- A `SpawnLocation` Part is created in the back room (placed via MCP, `Neutral=true`, `AllowTeamChangeOnTouch=false`)

On `Intermission` end (transition to `PreOpen`):
- Server teleports all players back to the main bakery spawn area (existing `SpawnLocation` at front of store)

### Client HUD
`UIController` listens for `GameStateChanged` with state `"Intermission"` and shows a "Break Time — X:XX" countdown banner (same style as existing TimerLabel).

### Architecture / Future-proofing
`GameStateManager` only handles:
- Timer
- Broadcasting state
- Player teleport in/out

All back room features subscribe to `"Intermission"` state via `GameStateManager.OnState("Intermission", cb)` — same pattern used everywhere else. Nothing back-room-specific lives in GameStateManager. Future additions (upgrade shop, cosmetics, daily challenges) just add their own listener with zero changes to core state management.

### SpawnLocation placement
- Back room center: `(0, 2, -127)` — clear of the leaderboard (left wall at X=-25) and the reserved shop wall (right wall at X=+25)
- Does not block future shop board placement on right wall

---

## Files Changed

| File | Change |
|------|--------|
| `GameStateManager.server.lua` | Add `INTERMISSION_DURATION`, add Intermission phase to `runCycle()`, add teleport calls |
| `MenuServer.server.lua` | On `MenuLocked`: trigger station remap |
| `RemoteManager.lua` | Add `StationRemapped` remote |
| `UIController.client.lua` | Handle `"Intermission"` state in HUD timer |
| Studio (MCP) | Create back room `SpawnLocation`, update warmer/fridge attributes at runtime |

**New file (optional):** `StationRemapService.lua` (SSS/Core) — if remap logic is >50 lines, extract it. Otherwise inline in MenuServer.

---

## Out of Scope (Phase 2)
- Cookie shop terminal UI in back room
- Upgrade shop
- Cosmetics browser
- Daily challenges board
