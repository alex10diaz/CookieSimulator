# Cookie Empire: Master Bakery — Master Design Document
**Date:** 2026-02-25
**Status:** Approved
**Approach:** Pipeline-First (Milestone-based, playtest before launch)

---

## 1. Game Summary

A 2–6 player cooperative Roblox bakery simulator inspired by Crumbl Cookie. Players run a team kitchen, producing cookies through a sequence of station minigames and delivering them to physical NPC customers. Teamwork, timing, and coordination drive performance. Skill increases rewards but the game is accessible to casual players at every level.

---

## 2. Roadmap — 7 Milestones

| Milestone | Name | Goal |
|-----------|------|------|
| 1 | Skeleton Loop | One cookie end-to-end with placeholder "press E" minigames. Playtest target. |
| 2 | Real Minigames | Replace all placeholders with actual mechanics (ring, drag+tap, temp bar, trace, box fill). |
| 3 | Full Order System + All 6 Cookies | All cookie types routed correctly, POS tickets, VIP orders, fridge warnings. |
| 4 | Economy + Save/Load | PlayerDataManager, DataStore, full rating formula, XP curve, combo streaks. |
| 5 | Tutorial + Pre-Open Flow | Guided tutorial, skippable flag, 5-min PreOpen timer, state transitions. |
| 6 | Meta Systems | Events (Rush Hour, Golden VIP), leaderboards, machine unlock hooks, assist mode, AntiExploit. |
| 7 | Polish + Launch Prep | Full UI polish, audio/VFX, performance pass, balance tuning, public playtest → launch. |

**Rule:** Milestones 1–3 use zero polish time. If it works, we move on.

---

## 3. Session Flow

### Phase Timing
- **Tutorial** — First time only (~2 min guided). Skippable after completion.
- **Pre-Open** — 5 min (first day), 3 min (repeat days). Mix and Dough Table only.
- **Open** — 15 min. NPCs spawn, orders flow, full pipeline active.
- **End-of-Day Summary** — 30 seconds. Shows orders completed, avg rating, coins, XP, combo peak. Auto-loops to next Pre-Open.

### Player Journey Each Day
1. Spawn → Tutorial check → Pre-Open timer starts
2. Pre-Open: Stock fridges with dough (Mix → Dough Table → Fridge)
3. Store opens → NPCs walk in, queue in waiting area
4. Player accepts order at POS → ticket locks for 30s
5. Team works pipeline: Mix → Dough Table → Fridge → Oven → (Frosting if needed) → Warmers → Dress/Pack
6. Player carries box across floor → delivers directly to the waiting NPC → rating pops
7. Repeat until Open phase ends
8. End-of-Day summary → new cycle begins

---

## 4. NPC & Order System

### NPC Customer Behavior
- NPCs spawn outside during Open phase, walk in along a set path
- Find a spot in the **waiting area** and wait there visibly
- Patience meter shows above their head
- **Delivery is physical** — a player carries the box to the specific NPC in the waiting area
- On delivery: NPC reacts, leaves with the box, rating appears
- On patience timeout: NPC walks out empty-handed, reputation penalty

### Spawn Rate
- Starts: 1 NPC every 45 seconds
- Ramps up as Open phase progresses
- Rush Hour event: rate doubles for 2 minutes
- Max queue: 6 NPCs in waiting area

### POS System
- Player walks up, interacts with POS tablet
- Sees queue of order tickets (cookie icon, quantity, modifiers, timer bar, VIP badge)
- Accepts one order → 30-second lock (others cannot grab it)
- If not started within 30s → unlocks for any player
- Active order moves to HUD tickets panel (visible to whole team)
- HUD shows which player is at which pipeline stage for each active order

### Order Lifecycle
```
Queued → Accepted → InProgress → Ready → Delivered → Rated
                                              ↓
                                         Failed (timeout / burned)
```

### VIP Orders
- 10% probability during Open phase base rate
- 20% probability during Rush Hour
- Tighter time limit, 1.75× coin payout
- VIP badge on ticket

---

## 5. Station Physical Status

| Station | Physical Status | Notes |
|---------|----------------|-------|
| Mixer | ✅ In world (Mixer 1, Mixer 2) | ProximityPrompts exist |
| Dough Table | ✅ 1 functional, 1 aesthetic | Use functional one |
| Fridge | ✅ All 6 cookie fridges | FridgeId attributes set |
| Oven | ✅ Oven1, Oven2 | InsideRack on both |
| Frosting Station | ✅ Exists (next to ovens) | Needs interaction script |
| Warmers | ❌ Not built yet | Space exists in map |
| Dress/Pack Station | 🔶 Concept started | Needs full implementation |
| POS | 🔶 Partial (tablet + model) | Needs full implementation |
| Waiting Area | ✅ Exists | NPC spots needed |

---

## 6. System Architecture

### Existing Systems (Keep & Extend)
| System | Location | Role |
|--------|----------|------|
| `OrderManager` | ReplicatedStorage/Modules | Full batch lifecycle |
| `CookieData` | ReplicatedStorage/Modules | 6 cookie definitions |
| `MinigameServer` | SSS/Minigames | Station session management |
| `FridgeOvenSystem` | SSS | Visual carry layer |
| `RemoteManager` | ReplicatedStorage/Modules | Central remote registry |
| `MinigameBase` | ReplicatedStorage/Modules | Connection tracking |
| `NPCSpawner` | ReplicatedStorage/Modules | NPC spawning |

### New Systems to Build

**Server-side (ServerScriptService):**
| System | Responsibility |
|--------|---------------|
| `GameStateManager` | Tutorial→PreOpen→Open→EndOfDay cycle; broadcasts phase changes |
| `PlayerDataManager` | XP, coins, level, unlocks, combo streak; DataStore persistence |
| `RatingSystem` | 1–5 star calculation from weighted factors |
| `EconomyManager` | Coin/XP formulas, multiplier cap, combo streak management |
| `EventManager` | Rush Hour, Golden VIP; fires during Open phase |
| `AntiExploit` | Server validates all minigame results before awarding anything |
| `POSController` | NPC queue, order acceptance, 30-second assignment lock |
| `TutorialController` | Stepwise tutorial state machine, skip flag |

**Client-side (StarterPlayerScripts):**
| System | Responsibility |
|--------|---------------|
| `UIController` | HUD (coins, XP, timer, active orders, end-of-day screen) |
| `TutorialUI` | Overlay arrows, instruction panels |
| `MixMinigame` | Rotating ring mechanic |
| `DoughMinigame` | Drag slider + tap spots mechanic |
| `OvenMinigame` | Temperature bar + stop mechanic |
| `FrostingMinigame` | Pattern trace mechanic |
| `DressMinigame` | Drag cookies into box mechanic |

### Data Flow (Authoritative Chain)
```
GameStateManager
    │ broadcasts phase
    ├── NPCSpawner (start/stop spawning)
    ├── POSController (enable/disable POS)
    ├── EventManager (schedule events during Open)
    └── UIController (timers, HUD visibility)

Player interacts with station
    └── MinigameServer (validates, starts session)
            └── Client minigame fires result
                    └── OrderManager (advances batch state)
                            └── RatingSystem (on delivery)
                                    └── EconomyManager (payout)
                                            └── PlayerDataManager (saves)
                                                    └── AntiExploit (validates every step)
```

**Rule:** Nothing skips the chain. No client awards itself coins or XP.

---

## 7. Minigame Mechanics

All minigames return a `MiniGameResult`: `Perfect / Good / Ok / Failed / Burned`

### Mix — Rotating Ring
- Spinning ring with a moving marker; green hit zone on the ring
- Player clicks when marker is in the green zone — 3 rounds
- Accuracy across rounds = `mixQuality` (0–100)
- Assist mode: larger zone, slower spin

### Dough Table — Drag + Tap
- Task 1: Drag slider to size marker (small/med/large)
- Task 2: Tap 3–5 highlighted spots before they disappear
- 2 players at table simultaneously = more spots, faster completion (teamwork reward)
- Assist mode: spots stay visible longer

### Oven — Temperature Bar
- Vertical bar fills as cookie bakes; green perfect zone drifts slowly
- Player clicks to stop bake at the right moment
- Multiple trays monitored simultaneously
- Output: Underbaked / Perfect / Slightly Brown / Burned
- Assist mode: wider zone, slower drift

### Frosting — Pattern Trace
- Frosting swirl path appears; player traces it with mouse/touch
- Accuracy % = decoration score; speed bonus
- Only fires for cookies where `NeedsFrost = true`
- Assist mode: thicker path (more forgiving)

### Dress/Pack — Order Match + Box Fill
- Order ticket shown; drag correct cookies into box
- Add modifier icons as shown (sprinkles, extra frosting)
- Intentionally low pressure — player has just run the full pipeline
- Speed bonus for quick completion
- Assist mode: correct slots highlight automatically

**Design rule:** Every mechanic learnable in under 10 seconds of watching. No in-minigame tutorial needed.

---

## 8. Economy & Progression

### Coin Payout Formula
```
Base         = RecipeTierValue × Quantity
SpeedBonus   = Base × (TimeRemaining / TotalTime) × 0.5
Accuracy     = 0.5–1.5× (based on star rating)
Combo        = 1 + (0.05 × streak) — capped at streak 20
VIP          = ×1.75 if flagged
FinalCoins   = Base × SpeedBonus × Accuracy × Combo × VIP
              (hard cap: 3× total multiplier, early game)
```

### Recipe Tier Values
| Tier | Cookie | Base Value | Time Limit |
|------|--------|-----------|-----------|
| 1 | Pink Sugar | 10 | 90s |
| 2 | Chocolate Chip | 15 | 90s |
| 3 | Snickerdoodle | 25 | 120s |
| 4 | Birthday Cake | 40 | 120s |
| 5 | Cookies & Cream | 65 | 150s |
| 6 | Lemon Black Raspberry | 100 | 150s |

### XP Formula
```
XP = (Base × 0.6) × AccuracyMultiplier
Perfect order: +20% bonus XP
```

### Leveling Curve
```
XP to next level = 100 × (Level ^ 1.35)
```
Level 1–10: fast | Level 10–25: moderate | Level 25+: meaningful grind

### Rating Formula (1–5 Stars)
| Factor | Weight |
|--------|--------|
| Correctness (recipe + modifiers) | 35% |
| Speed (time remaining) | 30% |
| Doneness (oven result) | 20% |
| Mix/Dough quality | 10% |
| Decoration accuracy | 5% |

### Combo Streaks
- Increments on every ≥3-star delivery
- Resets on 1–2 star or failed order
- Animated counter on HUD
- Hard cap: 20

### Machine Upgrade Cost (hook for future)
```
MachineCost = BaseCost × (1.4 ^ MachineLevel)
```

### Rebirth (hook only — implement later)
- +15% permanent earnings per rebirth
- +10% XP gain per rebirth
- Cosmetics and unlocks never reset

---

## 9. Accessibility

- **Assist Mode toggle** in settings (persistent per player)
- All 5 minigames have defined assist variants (larger windows, slower targets)
- Assist mode awards base XP/coins — never boosted, never penalized
- Role specialization naturally accommodates mixed-skill groups

---

## 10. Future Feature Hooks (Scaffold Only — Don't Implement)

All data shapes and system interfaces must support these without refactor:
- VIP customers (`Order.vipFlag` ✅ included)
- Gamepasses (hooks in `EconomyManager`)
- Rebirth counters (`PlayerProfile.rebirths` ✅ included)
- Machine unlocks + upgrade levels
- Recipe unlocks via level/reputation
- Custom order modifiers
- Random & limited-time events
- Premium currency placeholder
- Achievements + daily/weekly challenges
- Character cosmetics
- Leaderboards
- Expansion floors / new stations
- Easter egg flags

---

## 11. QA Acceptance Checklist

- [ ] PreOpen timer runs 5:00, transitions to Open reliably
- [ ] Tutorial skippable and marks `tutorialCompleted` permanently
- [ ] Fridge caps at 4 per cookie type; race conditions prevented
- [ ] Pulling tray consumes fridge item atomically (two players cannot pull same tray)
- [ ] Orders spawn only during Open phase
- [ ] VIP flag applies at ~10% base probability
- [ ] Order locks for 30s on acceptance; unlocks if not started
- [ ] NPC waits in waiting area until box delivered or patience expires
- [ ] Each station returns `MiniGameResult` object
- [ ] Server validates all minigame results before awarding output
- [ ] Rating formula produces 1–5 stars per delivery
- [ ] Coins and XP saved via DataStore on payout
- [ ] No client can award coins/XP without server validation
- [ ] Burned state reduces rating and does not crash pipeline
- [ ] Assist mode does not award bonus multipliers
- [ ] Combo resets correctly on failed/low-star order
- [ ] End-of-day summary displays correctly and loops to PreOpen

---

## 12. Key Design Rules (Enforced Throughout)

1. **Server authoritative on all state changes** — no exceptions
2. **Milestones 1–3: zero polish** — function over form until Milestone 7
3. **All formulas in EconomyManager** — one file to rebalance
4. **Nothing skips the pipeline chain** — client never self-awards
5. **Changes are expected** — roadmap is a living document, not a contract
