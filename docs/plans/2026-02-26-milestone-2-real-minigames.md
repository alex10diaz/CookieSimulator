# Milestone 2: Real Minigames — Design Document
**Date:** 2026-02-26
**Status:** Approved
**Milestone goal:** Replace all 5 placeholder "click to complete" minigames with functional mechanics. Pipeline remains the same; only the client scripts change.

---

## Decisions

- **All 5 minigames in one milestone** — tweak difficulty after playtesting
- **One script per minigame** (Option A) — self-contained, easy to debug individually
- **Movement locking included** — WalkSpeed/JumpPower = 0 on start, restored on end
- **No new remotes needed** — M1 already registered all 10 (StartXxx + XxxResult)
- **PlaceholderMinigame.client.lua deleted** — replaced by 5 new scripts

---

## Architecture

Every minigame script follows this exact pattern:

```
StartXxxMinigame fires from server
  → Lock player movement
  → Build ScreenGui overlay (self-contained, no pre-built Studio UI)
  → Run mechanic, accumulate score (0–100)
  → Destroy UI, restore movement
  → Fire XxxMinigameResult to server with score
```

### File Locations
```
src/StarterPlayer/StarterPlayerScripts/Minigames/
  MixMinigame.client.lua       (replaces PlaceholderMinigame)
  DoughMinigame.client.lua
  OvenMinigame.client.lua
  FrostMinigame.client.lua
  DressMinigame.client.lua
```

### Movement Locking
```lua
-- On session start (client-side)
local char = player.Character
char.Humanoid.WalkSpeed = 0
char.Humanoid.JumpPower = 0

-- On session end
char.Humanoid.WalkSpeed = 16
char.Humanoid.JumpPower = 7.2
```

---

## Minigame Mechanics

### 1. Mix — Rotating Ring
**File:** `MixMinigame.client.lua`
**Remote:** `StartMixMinigame` → `MixMinigameResult`

- A ring (Frame rotated via RunService.Heartbeat) spins on screen
- A fixed green hit zone sits at the top of the ring
- A white marker orbits the ring at increasing speed each round
- Player clicks a central "HIT" button when the marker overlaps the green zone
- **3 rounds** — speed increases each round (1×, 1.4×, 1.8×)
- **Timeout per round:** 4 seconds — auto-miss if no click
- **Scoring:** each hit scores 33 points; score = hits × 33 (capped at 100 on 3/3)
- Hit detection: marker angle vs green zone angle, within ±20° threshold

---

### 2. Dough — Drag + Tap
**File:** `DoughMinigame.client.lua`
**Remote:** `StartDoughMinigame` → `DoughMinigameResult`

Two sequential tasks:

**Task 1 — Slider (50% of score)**
- Horizontal slider track; a draggable handle starts at left
- A target zone (highlighted section) is randomly placed in the middle 60% of the track
- Player drags handle into the zone and releases
- Score contribution: 50 if center of handle lands inside zone, scaled down by distance if near edge, 0 if outside

**Task 2 — Spot Tap (50% of score)**
- 4 circular spots appear at random positions on screen
- Each fades out over 2.5 seconds independently
- Player clicks each spot before it disappears
- Score contribution: spots hit / 4 × 50

**Total score** = slider score + tap score (0–100)
**Timeout:** 10 seconds total for both tasks combined

---

### 3. Oven — Temperature Bar
**File:** `OvenMinigame.client.lua`
**Remote:** `StartOvenMinigame` → `OvenMinigameResult`

- A tall vertical bar fills upward over 6 seconds (fill driven by RunService)
- A green zone (20% of bar height) floats and drifts slowly up/down
- Player clicks a "STOP" button to freeze the fill level
- **Scoring:** based on where the fill level stopped relative to the green zone:
  - Center of green zone: 100
  - Inside green zone: 70–99 (linear by distance from center)
  - Just outside zone (within 10%): 40–69
  - Far outside: 0–39
- If player doesn't click before bar fills: score = 10 (burned)
- Score maps to oven result label server-side: 80+ = Perfect, 60–79 = SlightlyBrown, 40–59 = Underbaked, <40 = Burned

---

### 4. Frost — Checkpoint Trace
**File:** `FrostMinigame.client.lua`
**Remote:** `StartFrostMinigame` → `FrostMinigameResult`
**Note:** Only fires for cookies where `NeedsFrost = true`

- 8 circular checkpoint markers appear arranged in a spiral pattern on screen
- They are numbered 1–8 and glow to indicate the active next target
- Player moves their mouse/cursor through the active checkpoint to trigger it (no clicking required — proximity detection via MouseMoved)
- Each hit checkpoint turns green; the next one activates
- **Scoring:** checkpoints hit / 8 × 100
- **Timer:** 7 seconds — any remaining checkpoints at timeout score 0
- Checkpoints must be hit in order; skipping is not counted

---

### 5. Dress — Cookie Click Match
**File:** `DressMinigame.client.lua`
**Remote:** `StartDressMinigame` → `DressMinigameResult`

- The order ticket is shown (cookie type name + quantity, e.g. "Chocolate Chip ×2")
- A grid of 6 cookie icon buttons appears: correct type fills most slots, 1–2 wrong types mixed in
- Player clicks correct cookies to fill box slots (slots shown as empty squares at top)
- Clicking wrong cookie: -10 penalty to score, wrong button flashes red briefly
- **Scoring:** correct clicks / required × 100, minus 10 per wrong click (floor 0)
- **Timer:** 8 seconds
- Intentionally low pressure — reward for reaching this stage

---

## Score Flow

```
Client fires XxxMinigameResult(score: 0–100)
  → MinigameServer.endSession validates session
  → OrderManager.RecordStationScore / RecordOvenScore
  → Batch state advances to next stage
  → Server broadcasts BatchUpdated to all clients
```

Score is never awarded directly by the client. Server validates the session exists before recording anything.

---

## Acceptance Checklist

- [ ] PlaceholderMinigame deleted; no placeholder UI appears during play
- [ ] Player cannot move during any active minigame
- [ ] Mix: ring spins, 3 rounds, score 0–100 fires to server
- [ ] Dough: slider + 4 spots, score 0–100 fires to server
- [ ] Oven: bar fills, stop button works, score 0–100 fires to server
- [ ] Frost: 8 checkpoints in order, score 0–100 fires to server
- [ ] Dress: correct cookie selection, score 0–100 fires to server
- [ ] All 5 scores flow through MinigameServer into OrderManager without error
- [ ] Full pipeline still completes end-to-end after M2

---

## What M2 Does NOT Include

- Assist mode variants (M6)
- Sound effects or particle VFX (M7)
- Difficulty scaling by player level (M6)
- Multiplayer co-op bonuses on Dough (M3+)
- Real oven doneness label shown to player mid-bake (M7 polish)
