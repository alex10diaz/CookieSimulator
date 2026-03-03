# Tutorial Full Design — Cookie Empire: Master Bakery
**Date:** 2026-03-02
**Status:** Design document — not yet fully implemented
**Author:** Captured from session-start reminder

---

## Overview

This document captures the **complete vision** for the first-time player tutorial. It is the authoritative reference for what the tutorial should eventually be. Contrast with what M5 implemented (a minimal 3-step text overlay covering only Mix and Dough) — the full design goes much further and teaches the entire game loop end-to-end.

---

## Goals

1. **Teach the PreOpen prep cycle** — Mix → Dough → Fridge (the production chain before orders come in)
2. **Teach the Open phase** — accept an order at POS, run the full pipeline, physically deliver to an NPC
3. **Introduce the economy** — stars from quality, coins, combo streak multiplier
4. **Be skippable** — returning players (or impatient new players) press Skip at any time; completion flag persists to DataStore so tutorial never repeats
5. **Feel like guidance, not a wall** — the tutorial runs alongside real gameplay. The player is always doing something, never frozen staring at text.

---

## Tutorial Trigger Conditions

- Player joins with `data.tutorialCompleted == false`
- Tutorial runs during the **Lobby → PreOpen transition** (first day)
- If the player's first session starts mid-Open (edge case), tutorial is still shown from step 1 — some steps may auto-skip if their trigger conditions have already passed
- Tutorial is **skippable at any step** via the Skip button

---

## Phase Breakdown

### Phase 1 — Welcome (Lobby / loading)

**When:** Immediately after the player's character loads and data is ready (currently the `task.wait(3)` window in TutorialController).

**What happens:**
- A welcome panel slides in from the bottom-left (same TutorialGui)
- **Title:** "Welcome to Cookie Empire!" (large, warm font)
- **Body:** "You're the newest baker at the hottest cookie shop in town. Customers are counting on you — let's learn the basics before the store opens!"
- **Button:** "Let's Go!" (not just Skip — feels like the player is opting in)

**No progression gate** — pressing "Let's Go!" (or Skip) advances immediately to Step 1.

---

### Phase 2 — Step 1: The Mixer

**When:** After welcome is dismissed. Player is in PreOpen or Lobby.

**Panel content:**
- StepLabel: "Step 1 / 5"
- Message: "Head to a **Mixer** and press **E** to start mixing! This is how every cookie begins."

**Visual aid (future M6+ implementation):**
- A glowing arrow or beacon above the nearest Mixer (BillboardGui on a Part, or a highlight beam)
- The mixer station gets a subtle pulse glow

**Progression gate:** `MixMinigameResult` fires from this player → advance to Step 2

**What the player does:**
1. Walk to Mixer
2. Press E → ShowMixPicker → pick a cookie type
3. Complete the mix minigame (ring/timing mechanic)
4. MixMinigameResult fires on server → tutorial advances

**Tip shown during minigame (future):** Small floating label: "Hit the ring as it passes the target zone!"

---

### Phase 3 — Step 2: The Dough Table

**When:** After MixMinigameResult fires.

**Panel content:**
- StepLabel: "Step 2 / 5"
- Message: "Great mix! Now head to the **Dough Table** and press **E** to shape your cookie dough."

**Visual aid (future):**
- Arrow/glow moves to nearest Dough Table

**Progression gate:** `DoughMinigameResult` fires from this player → advance to Step 3

**What the player does:**
1. Walk to Dough Table (carrying the batch from the mixer)
2. Press E → complete the dough shaping minigame
3. DoughMinigameResult fires → tutorial advances

---

### Phase 4 — Step 3: The Fridge

**When:** After DoughMinigameResult fires.

**Panel content:**
- StepLabel: "Step 3 / 5"
- Message: "Nice work! Take your dough to a **Fridge** and press **E** to stock it. This is where your cookies wait until a customer orders them."

**Visual aid (future):**
- Arrow points to the correct fridge for the cookie type the player just made

**Progression gate:** `DepositDough` remote fires (player successfully stocks fridge) → advance to Step 4

**What the player does:**
1. Walk to the matching fridge (e.g., pink_sugar fridge for Pink Sugar dough)
2. Press E to deposit → `DepositDough` fires on server
3. Tutorial advances

**Note:** This is the main step M5 skipped (it had "Stock a Fridge" as step 3 but auto-completed after 4s without waiting for actual fridge interaction). Full design waits for real fridge deposit.

---

### Phase 5 — Step 4: The Order System (Open Phase)

**When:** After fridge deposit, OR when the Open phase begins (whichever is later — the tutorial waits if PreOpen hasn't ended yet).

**Transition message (bridge between PreOpen and Open):**
- If still in PreOpen after Step 3: panel shows "The store opens soon — keep stocking fridges while you wait!" with no step number. This is a soft idle hint, not a gated step.
- When GameStateChanged fires "Open" → panel updates to the actual Step 4 content:

**Panel content:**
- StepLabel: "Step 4 / 5"
- Message: "The store is open — customers are arriving! Go to the **POS tablet** and press **E** to accept an order."

**Visual aid (future):**
- Arrow/glow points to POS tablet

**Progression gate:** `OrderAccepted` remote fires for this player → advance to Step 5

**What the player does:**
1. Walk to POS
2. Press E → see order queue in POSGui
3. Click "Accept" on an order
4. `OrderAccepted` fires → tutorial advances

---

### Phase 6 — Step 5: Deliver

**When:** After order is accepted.

**Panel content:**
- StepLabel: "Step 5 / 5"
- Message: "Your order is in progress! Run the full pipeline — the team will help. When the box is ready, **carry it to the customer** in the waiting area and press **E** to deliver!"

**This step is informational.** No tight gate — the tutorial doesn't try to micromanage each pipeline station at this point. The player has already learned Mix + Dough + Fridge. The rest (Oven, Frost, Dress) will have contextual station hints in M6+ (not part of this tutorial overlay, but part of in-world station tooltips).

**Progression gate:** `DeliveryResult` fires for this player (any successful delivery during tutorial) → complete tutorial

**What the player does:**
1. Follow the pipeline as needed (Fridge pull → Oven → optional Frost → Dress → Box ready)
2. Carry the box to the waiting NPC
3. Press E to deliver
4. `DeliveryResult` fires → tutorial completes

**Auto-complete fallback:** If the player has been in Step 5 for more than 3 minutes with no delivery, tutorial auto-completes (they can figure it out on their own or it was a learning-by-doing moment). This prevents players being stuck in tutorial forever.

---

### Phase 7 — Tutorial Complete

**When:** DeliveryResult fires (or auto-complete fallback, or Skip pressed).

**What happens:**
1. Server calls `PlayerDataManager.SetTutorialCompleted(player)` → saved to DataStore
2. Server fires `TutorialStep` with `step = 0` → client dismisses panel
3. A **completion flash** shows for 2 seconds (future M7 polish):
   - Small banner: "Tutorial Complete! You're a real baker now 🍪"
   - Maybe a small coin/XP reward for finishing without skipping

**Economy reward for completion (design intent, implement in M6):**
- 50 bonus coins for completing all 5 steps without Skip
- 10 coins for skipping (small consolation)
- These rewards fire through the existing `EconomyManager.CalculatePayout` or a direct `PlayerDataManager.AddCoins` call

---

## Economy Introduction (Where + How)

The tutorial currently says nothing about coins, stars, or combos. Full design introduces these at natural moments:

| Moment | Economy concept introduced |
|--------|---------------------------|
| After first Mix result | "Better timing = more stars ⭐ on delivery!" (tooltip near result bar) |
| After first delivery | Full delivery result popup: stars earned, coins earned, shown via `DeliveryResult` UI — already exists, player just sees it naturally |
| After second delivery in a row | "Combo x2! Consecutive great deliveries earn bonus coins!" — HUD combo indicator pulses |

The tutorial does NOT lecture about the formula. It lets the delivery result popup do the teaching naturally.

---

## Visual Aid System (Future Implementation)

The current tutorial is text-only. The full design includes:

### Arrow Beacons
- A bright Part (or Attachment + Beam) with a pulsing color (yellow/orange)
- Positioned above the target station
- Shows only for the active tutorial step
- Disappears when player gets within ~8 studs of the target
- Server creates/destroys via `workspace:FindFirstChild()` + Instance manipulation
- Or: client-side billboard on the station Part using its known name/tag

### Station Glow
- Use `SelectionBox` or `Highlight` instance parented to the target station Part
- Subtle gold outline around the Mixer/DoughTable/Fridge during their respective steps
- Remove after step advances

### Implementation note
Both of these are M6 polish features. The text overlay (current M5 implementation) is sufficient for launch testing. Beacons and glows are added in M6 or M7.

---

## UI Design Details

### TutorialGui Layout (current M5)

```
┌─────────────────────────────────────────────┐
│ Step 1 / 5                        [  Skip  ] │
│                                              │
│  Head to a Mixer and press E to start        │
│  mixing! This is how every cookie begins.    │
└─────────────────────────────────────────────┘
         ← bottom-left, 420×110px
```

- Background: dark navy `Color3.fromRGB(20, 20, 30)` at 10% transparency
- StepLabel: yellow `Color3.fromRGB(255, 200, 60)`, GothamBold
- MessageLabel: white, Gotham size 18, TextWrapped
- Skip button: grey, top-right corner of panel
- UICorner radius 12

### What needs to change for full 5-step tutorial

1. **Panel height** — with 5 steps instead of 3, same 110px is fine (same message lengths)
2. **"Let's Go!" button** — on Step 0 (welcome), replace Skip with a positive CTA button
3. **Step count** — currently hardcoded `TOTAL_STEPS = 3` in TutorialController; change to 5
4. **Step text** — update `STEPS` table with 5 entries

---

## Server-Side State Machine Changes

### What M5 implemented (3 steps)

```
join → step 1 → MixMinigameResult → step 2 → DoughMinigameResult → step 3 (4s auto) → done
```

### Full 5-step state machine

```
join → step 1 → MixMinigameResult → step 2 → DoughMinigameResult → step 3 → DepositDough → (wait for Open) → step 4 → OrderAccepted → step 5 → DeliveryResult (or 3min timeout) → done
```

### New remotes needed

All already exist in RemoteManager:
- `DepositDough` — already registered ✅
- `OrderAccepted` — already registered ✅
- `DeliveryResult` — already registered ✅

No new remotes needed. TutorialController just needs to connect to two more existing remotes.

### Open Phase gating

Between Step 3 and Step 4, the tutorial must wait for the Open phase. Two approaches:

**Option A (simpler):** After DepositDough fires, TutorialController calls `GameStateManager.OnState("Open", callback)` to defer Step 4 until the store opens. Shows a soft message in the meantime.

**Option B:** After DepositDough, set a flag `pendingStep4[userId] = true`. When `GameStateChanged → "Open"` fires (server broadcasts), loop through pendingStep4 and send step 4 to those players.

Option B is cleaner — no dependency on GameStateManager's OnState API being callable from TutorialController. But Option A already exists and works. Use A.

---

## Skip Behavior

Skip can be pressed at any step. When pressed:
- Client hides panel immediately
- Client fires `TutorialComplete → server`
- Server calls `completeTutorial(player)` which:
  - Marks `data.tutorialCompleted = true` in PlayerDataManager
  - Fires step=0 back to client (redundant but safe)
  - Awards the 10-coin "skip consolation" (M6 feature)

If player leaves mid-tutorial, `activeTutorials[userId]` is cleaned on `PlayerRemoving`. Next session: tutorial restarts from step 1 (since `tutorialCompleted` was never saved — they skipped before completing OR they left before step 5 completed). This is intentional.

**Exception:** If player made it to step 3+ and left, should we save partial progress? Decision: **No.** Tutorial is short enough to redo. Keeping it simple (binary: done or not done) matches the current `tutorialCompleted` flag design.

---

## Multi-Player Considerations

In a multi-player session, each player runs their own independent tutorial. This is correct — each player needs to learn the flow personally.

- Player A completing a mix does NOT advance Player B's tutorial
- The `activeTutorials` table is keyed by userId — already correct
- One player's delivery can complete their own tutorial without affecting others

**Team situation:** If a veteran (tutorialCompleted=true) is playing with a new player, the veteran can just play normally. The new player follows the tutorial at their own pace. No tutorial nag for the veteran.

---

## Known Limitations in Current M5 Implementation

| Limitation | Impact | Fix in |
|-----------|--------|--------|
| `task.wait(3)` blind delay for DataStore load | If DataStore is slow, step 1 might fire before data loads → wrong check | M6: use PlayerDataManager profile-ready signal instead |
| TutorialController connects to MixMinigameResult directly (dual listener with MinigameServer) | Architectural coupling — two listeners on same remote | M6: use BindableEvent bridge from MinigameServer |
| Only 3 steps — skips Fridge deposit + Open phase + Delivery | Tutorial is incomplete, player exits tutorial without knowing how to serve customers | This document — implement full 5-step version |
| Step 3 auto-completes after 4s without real Fridge deposit | Player may never actually stock a fridge during tutorial | Full design waits for DepositDough event |
| No visual aids (arrows, glows) | Hard for new players to find stations | M6/M7 polish |
| No economy introduction in tutorial text | Player doesn't know about stars/coins/combo until they stumble on them | M6: contextual tooltips at delivery result |

---

## Implementation Priority

| Step | Status | When to implement |
|------|--------|------------------|
| Current 3-step text overlay | ✅ M5 DONE | |
| Expand to 5 steps (DepositDough + OrderAccepted + DeliveryResult gates) | ⬜ | M6 |
| Welcome "Let's Go!" first step | ⬜ | M6 |
| Open phase gating between step 3 and 4 | ⬜ | M6 |
| Economy intro tooltips at delivery result | ⬜ | M6 |
| Arrow beacons / station glow | ⬜ | M6/M7 |
| Completion reward (50 coins no-skip / 10 coins skip) | ⬜ | M6 |
| Fix DataStore timing (profile-ready signal) | ⬜ | M6 |
| Fix dual-listener coupling via BindableEvent | ⬜ | M6 |

---

## Files to Change for Full Implementation

| File | Change |
|------|--------|
| `TutorialController.server.lua` | Expand STEPS table to 5; add DepositDough + OrderAccepted + DeliveryResult listeners; add Open phase gating; add auto-complete fallback at step 5 |
| `TutorialUI.client.lua` | Update TOTAL_STEPS to 5; add welcome screen variant for step 0; add completion flash |
| `GameStateManager.server.lua` | Expose OnState("Open") subscription for TutorialController (already exists) |
| `PlayerDataManager.lua` | Consider adding `AddCoins` in tutorial completion callback (or call EconomyManager) |
| *(new)* `TutorialBeacons.client.lua` | Client-side station arrow/glow manager — receives beacon target from TutorialStep payload |

---

## Summary

The full tutorial teaches the **complete game loop** across 5 steps:

1. **Mix** — learn the first station
2. **Dough Table** — learn the second station
3. **Fridge** — learn how to stock (connect production to orders)
4. **Accept an Order** — learn the customer-facing side
5. **Deliver** — learn the reward moment

It runs seamlessly across the PreOpen and Open phases, doesn't freeze or block the player, and completes naturally through doing rather than watching. The Skip button is always available for players who already know what they're doing.

Current M5 is a working foundation (steps 1 + 2 + a stub for step 3). The full 5-step version is the M6 upgrade target.
