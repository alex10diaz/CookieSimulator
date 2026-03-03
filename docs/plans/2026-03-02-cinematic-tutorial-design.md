# Cinematic Tutorial Redesign — Design Document
**Date:** 2026-03-02
**Status:** Approved — ready for implementation plan
**Replaces:** `2026-03-02-tutorial-full-design.md` (the text-only 5-step design)

---

## Goal

Replace the current 3-step text-overlay tutorial (M5) with a 9-step cinematic experience:
- Fade-to-black transitions teleport the player to each station
- Camera glides to frame the station ("look here"), then returns control to the player
- Persistent bottom panel tells the player what to do at each step
- Tutorial follows one complete Pink Sugar cookie through the full pipeline
- After delivery: Final Menu with "Start Day" and "Replay Tutorial" options
- Universal GameSpawn: all players (new, skippers, returning) arrive at the same spawn point via a clean fade-in

---

## Design Decisions (from brainstorming session)

| Question | Decision |
|----------|----------|
| Camera after glide | **B — Glide then release.** Camera tweens to station (2s Quart), then returns to `Custom`. Player has full control to interact. |
| Instruction text | **A — Keep bottom panel.** Camera shows WHERE, text tells WHAT. |
| Cookie forcing | **B — Picker shows all 6 but only Pink Sugar is active.** Teaches the picker, guarantees frosting step is always taught. |
| "Start Day" behavior | Tutorial runs as overlay during normal PreOpen. "Start Day" = `completeTutorial()` = dismiss overlay. GameStateManager runs normally. |
| PreOpen timer | **7:30** (bumped from 5:00). Tutorial takes ~2-2.5 min → player has ~5 min of real PreOpen after "Start Day." |
| Step 1 text | "Accept a **customer order**" — no Pink Sugar revealed in tutorial text. |
| Spawn system | Unified GameSpawn: every player arrives at `workspace.GameSpawn` via fade-in (new, skip, returning). |

---

## Architecture

### Files Changed (5 total)

| File | Type | Change |
|------|------|--------|
| `src/ReplicatedStorage/Modules/RemoteManager.lua` | Existing | Add `ReplayTutorial`, `StartGame` to REMOTES |
| `src/ServerScriptService/Core/TutorialController.server.lua` | Existing | Full rewrite — 9-step state machine, advance(), final menu |
| `src/StarterPlayer/StarterPlayerScripts/TutorialUI.client.lua` | Existing | Add `FadeFrame` + Final Menu; keep existing bottom panel |
| `src/StarterPlayer/StarterPlayerScripts/TutorialCamera.client.lua` | **NEW** | Cinematic fade/teleport/glide/release per step |
| `src/StarterPlayer/StarterPlayerScripts/Minigames/MixerController.client.lua` | Existing | Read `TutorialForceCookie` PlayerGui attribute → grey out non-pink-sugar buttons |
| `src/ServerScriptService/Core/GameStateManager.server.lua` | Existing | `PREOPEN_FIRST = 7*60+30` (one constant change) |

### Not touched
- MinigameServer — no changes needed
- OrderManager — no changes needed
- PlayerDataManager — no changes needed (SetTutorialCompleted already exists)

---

## Remote Events

### New remotes (add to RemoteManager REMOTES table)
```lua
"ReplayTutorial",   -- client → server: player wants to redo tutorial from step 1
"StartGame",        -- client → server: player pressed "Start Day" button
```

### Existing remotes used (no changes)
- `TutorialStep` — server → client, fires step payload
- `TutorialComplete` — client → server, Skip button
- `OrderAccepted`, `MixMinigameResult`, `DoughMinigameResult`, `DepositDough`, `PullFromFridgeResult`, `OvenMinigameResult`, `FrostMinigameResult`, `DressMinigameResult`, `DeliveryResult` — all existing, server listens to advance

---

## The 9 Steps

All steps fire via `TutorialStep:FireClient(player, payload)`.

### Payload structure
```lua
{
    step          = number,      -- 1–9 active, 10 = final menu, 0 = dismiss
    total         = 9,
    msg           = string,      -- instruction text for bottom panel
    target        = string,      -- semantic camera target key (see mapping table below)
    forceCookieId = string|nil,  -- only on step 2: "pink_sugar"
    isReturn      = bool|nil,    -- only on step 0: true for returning players
}
```

### Step table

| Step | `msg` (bottom panel text) | `target` | Gate (OnServerEvent) |
|------|--------------------------|----------|----------------------|
| 1 | `"Head to the POS and accept a customer order!"` | `"POS"` | `OrderAccepted` |
| 2 | `"Go to a Mixer and press E to start mixing!"` | `"Mixer"` | `MixMinigameResult` |
| 3 | `"Shape your dough at the Dough Table — press E!"` | `"DoughTable"` | `DoughMinigameResult` |
| 4 | `"Stock the dough in the Pink Sugar fridge!"` | `"FridgePinkSugar"` | `DepositDough` |
| 5 | `"Pull the chilled dough out of the fridge!"` | `"FridgePinkSugar"` | `PullFromFridgeResult` |
| 6 | `"Slide it into the Oven — watch the timer!"` | `"Oven"` | `OvenMinigameResult` |
| 7 | `"Apply pink frosting at the Frost Table!"` | `"FrostTable"` | `FrostMinigameResult` |
| 8 | `"Dress and pack your cookie!"` | `"DressTable"` | `DressMinigameResult` |
| 9 | `"Carry the box to the customer and press E!"` | `"WaitingArea"` | `DeliveryResult` |
| 10 | *(Final Menu shown — no bottom panel)* | none | buttons |
| 0 | *(dismiss/spawn)* | `"GameSpawn"` | — |

### Step 10 — Final Menu
Sent after DeliveryResult. Shows a centered modal. No step counter shown.
- **"START DAY (PRE-OPEN)"** button → `StartGame:FireServer()` → server calls `completeTutorial()`
- **"REPLAY TUTORIAL"** button → `ReplayTutorial:FireServer()` → server resets `activeTutorials[userId] = {step=1}` → fires step 1

### Step 0 — Dismiss + Spawn
Always fires after `completeTutorial()`. Payload includes `isReturn`:
- `isReturn = false`: player just finished/skipped tutorial → TutorialCamera fades black → teleports to `GameSpawn` → fades in
- `isReturn = true`: returning player (tutorialCompleted=true on join) → same fade/spawn treatment → clean arrival every session

---

## Workspace Objects Required

### Camera Target Mapping (client-side, `TutorialCamera.client.lua`)

The `target` string from the payload maps to a Part/Model in workspace:

```lua
local TARGET_PARTS = {
    POS           = workspace.POS.Tablet,
    Mixer         = workspace.Mixers["Mixer 1"],
    DoughTable    = workspace.DoughCamera,                          -- existing purpose-built Part at (-3, 9, -28)
    FridgePinkSugar = workspace.Fridges.fridge_pink_sugar,
    Oven          = workspace.Ovens.Oven1,
    FrostTable    = workspace.Store["Frost Table"],
    DressTable    = workspace.Dress["Dress Table"],
    WaitingArea   = workspace.WaitingArea.Spot1,
    GameSpawn     = workspace.GameSpawn,                            -- NEW: must be placed in Studio
}
```

### New Parts to add in Studio (you place these)

| Name | Location | Purpose |
|------|----------|---------|
| `workspace.TutorialSpawn` | Near the entrance/lobby area | Where player's character lands at tutorial start (before first camera glide) |
| `workspace.GameSpawn` | The main bakery starting position | Where ALL players arrive after tutorial/skip/returning |

Both parts should be **invisible** (`Transparency = 1`, `CanCollide = false`) and sized ~4×1×4. They act as anchor positions only.

---

## Camera Mechanics Detail

### Per-step transition (`TutorialCamera.client.lua`)

```
On TutorialStep (step 1–9):
  1. FadeFrame → opaque black  (0.4s TweenService)
  2. Teleport: char.HumanoidRootPart.CFrame = targetPart.CFrame * CFrame.new(0, 0, 6)
  3. Camera: CameraType = Scriptable
             CFrame = CFrame.new(targetPos + Vector3(0,15,20), targetPos)   [wide opening position]
  4. FadeFrame → transparent  (0.4s TweenService)
  5. Camera glides: CFrame → (targetPos + Vector3(0,6,10) looking at targetPos)
                    over 2s, EasingStyle.Quart, EasingDirection.Out
  6. Glide.Completed → camera.CameraType = Enum.CameraType.Custom
     (player now has full camera and movement control at the station)

On TutorialStep (step 0 — any isReturn value):
  1. FadeFrame → opaque black  (0.4s)
  2. Teleport to workspace.GameSpawn.CFrame
  3. Camera: CameraType = Custom (immediately — no glide, just clean handoff)
  4. FadeFrame → transparent  (0.4s)
  (No glide — player arrives normally, game starts)

On TutorialStep (step 10 — final menu):
  No camera transition. Final menu appears over whatever camera the player has.
```

---

## Pink Sugar Forcing (MixerController)

**No MinigameServer changes.** Uses a PlayerGui attribute as shared state.

### TutorialUI sets the attribute when step 2 arrives:
```lua
playerGui:SetAttribute("TutorialForceCookie", data.forceCookieId)  -- "pink_sugar"
```

### TutorialUI clears the attribute when step advances past 2 or tutorial ends:
```lua
playerGui:SetAttribute("TutorialForceCookie", nil)
```

### MixerController reads the attribute in `showPicker()`:
```lua
local forcedCookie = playerGui:GetAttribute("TutorialForceCookie")
-- Per cookie button:
local isForced = forcedCookie ~= nil
local isMatch  = (forcedCookie == cookie.id)
btn.Active              = (not isForced) or isMatch
btn.BackgroundTransparency = (isForced and not isMatch) and 0.6 or 0
-- Picker title text:
title.Text = isForced and "Tutorial: Pink Sugar Only!" or "Choose a Cookie"
```

---

## Server State Machine (`TutorialController.server.lua`)

```lua
activeTutorials = {}
-- activeTutorials[userId] = { step = N }   (nil = not in tutorial)

STEPS = {
    [1]  = { msg = "...", target = "POS" },
    ...
    [9]  = { msg = "...", target = "WaitingArea" },
}

advance(player):
    session.step += 1
    if session.step == 10 → sendStep(player, 10)
    else → sendStep(player, session.step)

completeTutorial(player):
    activeTutorials[userId] = nil
    PlayerDataManager.SetTutorialCompleted(player)
    tutorialStepRemote:FireClient(player, { step=0, isReturn=false })

-- StartGame remote:
startGameRemote.OnServerEvent → completeTutorial(player)

-- ReplayTutorial remote:
replayRemote.OnServerEvent → activeTutorials[userId] = {step=1} → sendStep(player, 1)

-- Skip (TutorialComplete remote):
tutorialDoneRemote.OnServerEvent → completeTutorial(player)

-- Returning player on join (tutorialCompleted=true):
tutorialStepRemote:FireClient(player, { step=0, isReturn=true })
-- (no activeTutorials entry — they bypass the whole system)

-- Station advance connections (all OnServerEvent):
OrderAccepted       → if step==1 → advance
MixMinigameResult   → if step==2 → advance
DoughMinigameResult → if step==3 → advance
DepositDough        → if step==4 → advance
PullFromFridgeResult→ if step==5 → advance
OvenMinigameResult  → if step==6 → advance
FrostMinigameResult → if step==7 → advance
DressMinigameResult → if step==8 → advance
DeliveryResult      → if step==9 → advance (→ step 10)
```

---

## UI Layout

### Bottom Panel (unchanged from M5, just step count updated to /9)
```
┌─────────────────────────────────────────────┐
│ Step 2 / 9                        [  Skip  ] │
│                                              │
│  Go to a Mixer and press E to start mixing!  │
└─────────────────────────────────────────────┘
     bottom-left, 420×110px
```

### FadeFrame (new child of TutorialGui)
- Full screen black Frame, `ZIndex = 20` (above all other UI)
- `BackgroundTransparency = 1` at start (invisible)
- TutorialCamera drives its transparency

### Final Menu (new Frame, step 10 only)
```
┌────────────────────────────────┐
│    You're ready to bake! 🍪    │
│                                │
│  [ START DAY (PRE-OPEN)    ]   │  ← green
│  [    REPLAY TUTORIAL      ]   │  ← dark grey
└────────────────────────────────┘
   centered modal, 320×160px
   shown only on step == 10
   hidden on step == 0 or step < 10
```

---

## GameStateManager Change

One constant edit only:
```lua
-- Before:
local PREOPEN_FIRST = 5 * 60   -- 5 minutes

-- After:
local PREOPEN_FIRST = 7 * 60 + 30   -- 7:30 — gives tutorial players ~5 min of real PreOpen
```

---

## Testing Checklist

1. **Returning player join** — OutputL no tutorial panel, fade-in to GameSpawn, camera Custom
2. **First-time player join** — step 1 panel, camera glides to POS, player accepts order → step 2
3. **Step 2 picker** — all 6 cookies visible, only Pink Sugar clickable, title says "Tutorial: Pink Sugar Only!"
4. **Step 3** — after MixMinigameResult, camera glides to DoughCamera position
5. **Steps 4–9** — each station gate fires correctly, camera glides to correct target
6. **Step 10** — Final Menu appears after delivery
7. **"Start Day"** — overlay dismisses, player fades to GameSpawn, PreOpen continuing
8. **"Replay Tutorial"** — returns to step 1, camera glides to POS again
9. **Skip at any step** — overlay dismisses, player fades to GameSpawn
10. **TutorialForceCookie attribute cleared** — after step 2 advances, picker shows all cookies normally

---

## Files Changed Summary

| File | Status |
|------|--------|
| `src/ReplicatedStorage/Modules/RemoteManager.lua` | +2 remotes |
| `src/ServerScriptService/Core/TutorialController.server.lua` | Full rewrite |
| `src/ServerScriptService/Core/GameStateManager.server.lua` | 1 constant change |
| `src/StarterPlayer/StarterPlayerScripts/TutorialUI.client.lua` | +FadeFrame + Final Menu |
| `src/StarterPlayer/StarterPlayerScripts/TutorialCamera.client.lua` | NEW |
| `src/StarterPlayer/StarterPlayerScripts/Minigames/MixerController.client.lua` | +forceCookie logic |
| `workspace.TutorialSpawn` *(Studio only)* | Place in Studio |
| `workspace.GameSpawn` *(Studio only)* | Place in Studio |
