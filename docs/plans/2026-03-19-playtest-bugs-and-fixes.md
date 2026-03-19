# 2026-03-19 Playtest Bug Report & Fix Plan

Captured from first full playthrough after M7 UI polish pass.
Organized by priority — work top to bottom each session.

---

## P0 — Session-Breakers
*Fix these first. Nothing else is worth doing until these are solid.*

### P0-1 · End-of-Shift Summary Never Dismisses
- **Bug:** SummaryGui stays on screen for the entire Intermission phase (5 min). Never auto-closes.
- **Fix:** Add a 15-second auto-dismiss timer inside SummaryController. On `GameStateChanged → Intermission` or `EndOfDay`, start a 15s countdown then force-close. Also add a manual "Continue" button.
- **File:** `src/StarterGui/SummaryGui/SummaryController.client.lua`

### P0-2 · Player Teleports Outside Store on Shift 2
- **Bug:** On the second Open phase, `teleportAllTo(FRONT_SPAWN_CF)` sends players to the wrong location (outside store walls).
- **Fix:** Verify `FRONT_SPAWN_CF = CFrame.new(55, 2, 31)` is inside the store. Adjust CFrame if not. Also confirm the SpawnLocation is inside and correctly sized.
- **File:** `src/ServerScriptService/Core/GameStateManager.server.lua` (or StationRemapService — wherever teleport fires)

### P0-3 · UI Z-Order Overlap Audit
- **Bug (known):** Store timer HUD renders over active minigame UI. Delivery star flash card renders behind other UI.
- **Audit ALL ScreenGuis and assign a clear DisplayOrder stack:**

| GUI | DisplayOrder | Notes |
|-----|-------------|-------|
| HUD | 1 | Always-on layer — must be below everything modal |
| CarryIndicator | 2 | Carry bar, low priority |
| TutorialGui | 10 | Tutorial panel + FadeFrame (ZIndex 20 inside) |
| MixGui / DoughGui / OvenGui / FrostGui | 15 | Minigame UIs — must cover HUD timer |
| MixPickerGui | 15 | Cookie picker |
| POSGui | 20 | Order cutscene modal |
| SummaryGui | 25 | End-of-shift — must cover everything |
| FadeFrame (inside TutorialGui) | ZIndex 20 | Already set |

- **Fix:** Set `.DisplayOrder` on every ScreenGui consistently. Minigame GUIs must be higher than HUD. SummaryGui highest. DeliveryFlash card inside HUD needs `ZIndex = 50` (already set — verify it's not being clipped by a parent with lower ZIndex).
- **Files:** All `.client.lua` files that create ScreenGuis dynamically (MixMinigame, DoughMinigame, OvenMinigame, FrostMinigame, MixerController, DressStationClient, DeliveryClient, POSClient, SummaryController, HUDController, TutorialUI)

---

## P1 — Gameplay Broken

### P1-1 · Drive-Thru NPC Never Leaves Without Order
- **Bug:** Drive-thru NPC has no patience/timeout system. In-store NPCs walk out after timer expires — drive-thru NPCs have a different flow and stay indefinitely.
- **Fix:** Add a drive-thru specific timeout (e.g. 90s from arrival). If order not completed in time, despawn the car and NPC. Fire `ForceDropBox` if player is mid-carry.
- **File:** Drive-thru spawner script (wherever drive-thru NPC lifecycle is managed)

### P1-2 · NPCs Spawn During EndOfDay Phase
- **Bug:** NPC spawner doesn't gate on GameState — NPCs walk in even as the phase is ending.
- **Fix:** In `PersistentNPCSpawner`, check `GameState == "Open"` before spawning any new NPC. Also cancel any queued spawns on `EndOfDay` transition.
- **File:** `src/ServerScriptService/Core/PersistentNPCSpawner.server.lua`

### P1-3 · Cookie / Station Mismatch After Menu Change
- **Bug:** After selecting a new menu in PreOpen, fridges show the wrong cookie name, mix picker shows stale cookies, warmers show wrong type. Likely `StationRemapService` fires before menu is fully committed, or fridge models reference old CookieId attributes.
- **Fix:** Ensure `StationRemapService` fires *after* `MenuManager.GetActiveMenu()` is finalized. Verify all 6 fridge models update their `FridgeDisplay.CookieName` TextLabel and `CookieId` attribute. Verify `WarmersDisplay` TextLabel updates. Verify `ShowMixPicker` re-queries `GetActiveMenu()` fresh each time.
- **Files:** `StationRemapService.server.lua`, `MenuServer.server.lua`, `FridgeDisplayServer.server.lua`

### P1-4 · Patience Timer Visible While NPC Walks In
- **Bug:** The gray patience timer box appears above NPCs while they are still walking into the store or queuing. It should only appear after the NPC is seated and has been served.
- **Note:** This was supposedly fixed previously (hidden during `waiting_in_queue`) but has regressed.
- **Fix:** Confirm the BillboardGui is set `Enabled = false` on spawn and only enabled when NPC state transitions to `waiting_for_order` (after player has confirmed at POS). Check `PersistentNPCSpawner` NPC state machine.
- **File:** `src/ServerScriptService/Core/PersistentNPCSpawner.server.lua`

### P1-5 · Player Not Appearing in Employee of the Shift
- **Bug:** After an Open phase with deliveries made, the player does not appear in the "Employee of the Shift" section of the end-of-shift SummaryGui.
- **Fix:** Check `SessionStats.GetSummary()` — confirm it returns `topPlayer` data. Check `SummaryController` reads and renders the `employeeOfShift` field. Likely a nil-check or field-name mismatch.
- **Files:** `src/ServerScriptService/Core/SessionStats.lua`, `src/StarterGui/SummaryGui/SummaryController.client.lua`

---

## P2 — HUD / UI Fixes

### P2-1 · Cookie Count HUD Shows Last Cookie Only
- **Bug:** The top-right order pill shows only the last active cookie. Should show a count per type currently in warmers / ready to deliver.
- **Fix:** Replace `ActiveOrderLabel` single-line text with a multi-line or scrolling display showing `[CookieName]: N` for each type that has stock. Update via `HUDUpdate` remote whenever warmer stock changes.
- **Files:** `src/StarterGui/HUD/HUDController.client.lua`, warmer stock broadcast in server

### P2-2 · End-of-Shift Star Display Looks Like 6 Stars
- **Bug:** The star row in the summary screen (e.g. ★★★★☆) appears to show 6 stars to the player due to visual spacing or layout.
- **Fix:** Review `SummaryController` star rendering. Stars should be 1–5 only. Check that the `string.rep("★", s) .. string.rep("☆", 5-s)` output renders clearly. Consider using a fixed-width font or spacing between stars. Add a numeric label like "4 / 5" next to stars for clarity.
- **File:** `src/StarterGui/SummaryGui/SummaryController.client.lua`

### P2-3 · Break Time Duration Back to 3 Minutes
- **Change:** Intermission is currently 5 minutes. Reduce to 3 minutes.
- **File:** `src/ServerScriptService/Core/GameStateManager.server.lua` — change `INTERMISSION_DURATION`

### P2-4 · Warmer Models Have No Name Labels
- **Bug:** Warmers only have cookie names on their ProximityPrompt text — no visible label on the physical model itself, making it hard to tell which warmer holds which cookie.
- **Fix:** Add a `BillboardGui` (or `SurfaceGui`) to each Warmer model's `Shell` part showing the cookie name. Update via `StationRemapService` when menu remaps.
- **Studio:** Each `Warmer_*` model in Workspace needs a visible name label part.

### P2-5 · Fridge BillboardGui Not Visible to Players
- **Bug:** Players cannot see fridge display labels (cookie name + stock count) during gameplay.
- **Fix:** Increase `BillboardGui.Size` (try `UDim2.new(0, 200, 0, 60)`) and raise `StudsOffset` so the label floats above the fridge door clearly. Check `AlwaysOnTop = true`. Also check that `FridgeDisplayServer` is actually updating the labels.
- **Files:** Fridge models in Workspace, `src/ServerScriptService/Core/FridgeDisplayServer.server.lua`

### P2-6 · Daily Challenges Board Not Visible in Back Room
- **Bug:** Daily Challenges show correctly in the bottom-left HUD but the physical `ChallengesBoard` in the back room is not visible (possibly occluded, wrong position, or wrong face direction).
- **Fix:** Verify `ChallengesBoard` Part position (currently `(25, 8, -157)`) is on the back wall, facing the room (`Face = Enum.NormalId.Front` or whichever face points into the room). Adjust position and PixelsPerStud if text is too small.
- **Studio:** `ChallengesBoard` Part in Workspace

---

## P3 — Content

### P3-1 · Drive-Thru Car: NPC Outside Car Instead of Inside
- **Bug:** Drive-thru NPC spawns standing beside or outside the car rather than seated inside at the window.
- **Fix:** Adjust NPC spawn `CFrame` to seat position inside the car model. The car parts are already built in Studio — need to find the correct seat position offset.
- **Studio:** Drive-thru car model + NPC spawn CFrame in drive-thru spawner

### P3-2 · Customer Models Not Working — Need Basic R6 NPCs
- **Bug:** Current NPC models are broken/placeholder. Need proper humanoid R6 customer models that do not use the friends list.
- **Fix:** Create generic R6 NPC templates with randomized basic clothing colors (shirt/pants `Color3` random from a preset palette). At minimum: `Humanoid`, `HumanoidRootPart`, standard R6 body parts, a `BillboardGui` for the patience timer above head. No avatar API calls.
- **Files:** NPC template in `ServerStorage`, `PersistentNPCSpawner` spawn logic

### P3-3 · Players Can Jump and Climb on Surfaces
- **Bug:** Players can jump onto counters, shelves, and equipment, breaking immersion.
- **Fix:** Set `JumpHeight = 0` and `JumpPower = 0` on the Humanoid when the player is in the store. Re-enable if needed for tutorial transitions. Alternatively use `ForceField` or `CollisionGroup` on climbable surfaces.
- **Files:** `GameController` or character added handler — set on CharacterAdded

### P3-4 · Store Environment Looks Empty
- **Bug:** Looking out the store windows or through the drive-thru, the exterior is blank/empty baseplate.
- **Fix:** Add basic environmental props to Studio around the store: parking lot lines, a few decorative trees/bushes (free Toolbox models), a road strip for drive-thru lane, some distant buildings (simple colored Parts). Does not need to be detailed — just enough to not feel void.
- **Studio:** Environment folder in Workspace

---

## P4 — Balance

### P4-1 · Lifetime Challenges Too Easy / Too Few
- **Current:** 9 milestones, likely achievable too quickly.
- **Options:**
  - A) Increase milestone thresholds (e.g. 10 → 25 → 75 → 200 → 500 → 1000 → 2500 → 5000 → 10000 deliveries)
  - B) Add more milestone steps (expand from 9 to 15+)
  - C) Both — raise thresholds AND add more steps
- **Recommendation:** Option C. Raise existing thresholds significantly and add 5-6 new milestones at the high end (prestige-level goals). Rewards should scale too.
- **File:** `LifetimeChallengeManager` or wherever lifetime milestone thresholds are defined

---

## Fix Order for Next Session

```
Session 1: P0-1, P0-2, P0-3 (summary dismiss + teleport + full UI z-order audit)
Session 2: P1-2, P1-4, P1-5, P2-3 (spawning + patience timer + employee + break time)
Session 3: P1-3 (station remap / menu change correctness)
Session 4: P1-1 (drive-thru timeout), P3-1 (NPC in car)
Session 5: P2-1, P2-2, P2-4, P2-5, P2-6 (HUD + visual fixes)
Session 6: P3-2 (R6 customer models)
Session 7: P3-3, P3-4, P4-1 (jump block + environment + lifetime balance)
```
