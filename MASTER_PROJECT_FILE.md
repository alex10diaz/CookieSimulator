# 🍪 COOKIE SIMULATOR — MASTER PROJECT FILE
**Keyphrase:** COOKIE ALPHA MASTER FILE
**Last Updated:** 2026-03-24 (Session 2 end)
**Overall Alpha Readiness:** 🟡 71%
**Source of Truth:** This file. Always update, never rewrite from scratch.

---

## ⚠️ SESSION WORKFLOW (READ FIRST EVERY SESSION)

1. Load this file
2. Check the **Verification Board** for system status
3. Check **Current Task** — work ONLY on that
4. Check **Next Task Queue** for what comes after
5. After completing work: update statuses, log to Completed, advance queue
6. Never restart a finished system. Never invent features outside Future Ideas.

---

## 🚨 REGRESSION / NEW BUG RULE

**When a regression or new bug is reported, follow this protocol EVERY TIME — no exceptions:**

1. **LOG FIRST** — Add the bug to Section 7 (Known Bugs) with ID, severity, system, description, and Status = Open before writing any code
2. **ROOT CAUSE REQUIRED** — Identify the root cause explicitly before patching. Do not patch symptoms.
3. **IMPACT SCOPE** — State which other systems could be affected by the fix before applying it
4. **FIX NARROWLY** — Touch only the files required to fix the root cause. Do not refactor adjacent code.
5. **VERIFY IN STUDIO** — After every fix, confirm the bug is gone via MCP console output or manual test
6. **MARK RESOLVED** — Update the bug Status in Section 7 to "Resolved — [date]" after verification
7. **LOG TO COMPLETED** — Add a row to Section 6 (Completed Tasks) with the fix summary
8. **NEVER SILENT-FIX** — A bug that is patched but not logged is a bug that will reappear

> **Studio Sync Rule:** Every disk change MUST be pushed to Studio via MCP `run_code` in the same session it is made. A disk edit that never reaches Studio is not a fix — it is a pending fix that will create confusion next session.

---

## 📋 SECTION 1 — SYSTEM VERIFICATION BOARD

> Legend: ✅ Verified Implemented | ⚠️ Needs Improvement | 🔶 Partially Implemented | 📋 Planned | ❌ Missing | 🔍 Needs Verification

### CORE SYSTEMS
| System | Verification Status | Notes |
|---|---|---|
| Order System (batch pipeline) | ✅ Verified Implemented | Mix→Dough→Fridge→Oven→[Frost]→Warmers→Dress. Well-architected, event-driven |
| NPC System | ✅ Verified Implemented | Spawning/lifecycle complete. facePosition fixed: task.spawn+0.2s wait, AutoRotate disabled during CFrame snap. |
| Station System (Mix/Dough/Oven/Frost) | ⚠️ Needs Improvement | All 4 stations functional. **Movement not locked during minigames** |
| Box System | ⚠️ Needs Improvement | Physical box welded to HRP, transfers to NPC. Arms fall off (Motor6D bug) |
| Delivery System | ⚠️ Needs Improvement | Payout works. No delivery lock — two players can race same NPC |
| Shift System | ✅ Verified Implemented | PreOpen(3m)→Open(8m)→EndOfDay(30s)→Intermission(3m). Rush Hour at 70% elapsed |
| Round Reset | ✅ Verified Implemented | SessionStats.Reset(), OrderManager clear, NPC cleanup |
| Money System | ✅ Verified Implemented | Server-authoritative. Base×speed×accuracy×combo×VIP, capped 3× |
| XP System | ✅ Verified Implemented | Player XP + Bakery XP (separate tracks). `100 × level^1.35` curve |
| Level System | 🔶 Partially Implemented | Level tracked and displayed. **Nothing is gated by level** |
| Quality Scoring | ⚠️ Needs Improvement | Mix/Dough/Oven/Frost scored correctly. **Dress hardcoded to 85** |
| Combo System | ✅ Verified Implemented | IncrementCombo/ResetCombo, capped at 20, 1.05× per stack, ComboUpdate remote |
| Customer Patience | ⚠️ Needs Improvement | Patience logic complete. HUD shows it. **No in-world indicator above NPC head** |
| Bakery Rating | 🔶 Partially Implemented | Shift grade A–D calculated. No persistent reputation across shifts |

### MULTIPLAYER SYSTEMS
| System | Verification Status | Notes |
|---|---|---|
| Station Locking (movement) | ✅ Verified Implemented | WalkSpeed/JumpPower/JumpHeight=0 on session start; restored in endSession, cleanupPlayerSession, watchdog |
| Item Ownership | ✅ Verified Implemented | doughLock, ovenSession, dressPending all prevent double-grab |
| Delivery Ownership | ⚠️ Needs Improvement | Box welded to player but no lock when two players fire DeliverBox for same NPC |
| Player Leaving Mid-Task | ✅ Verified Implemented | cleanupPlayerSession on PlayerRemoving; 60s watchdog clears orphans |
| Player Joining Mid-Shift | 🔶 Partially Implemented | Data loads, player teleported. **Warmer stock not synced to joining player** |
| Remote Spam Protection | 🔶 Partially Implemented | M-4 debounce on state broadcasts. **PurchaseItem / RequestMixStart have no rate limit** |
| Server Validation | ✅ Verified Implemented | Score range, type, session match, cookieId, menu lock all validated |
| Anti-Exploit Checks | ✅ Verified Implemented | 3s min duration, score is-number, station type match, cookieId validation |
| Session Validation | ✅ Verified Implemented | activeSessions[player] keyed and cross-checked on end |
| Race Condition Protection | ⚠️ Needs Improvement | doughLock / orderLockedBy present. Fridge pull + dress delivery can still race |

### DATA SYSTEMS
| System | Verification Status | Notes |
|---|---|---|
| DataStore Saving | ✅ Verified Implemented | PlayerData_v1, cross-server session lock, UpdateAsync |
| Auto-Save | ✅ Verified Implemented | Per-player coroutine every 300s. No retry on failure |
| Player Data Loading | ✅ Verified Implemented | Deep merge with defaults, migration-safe |
| Cosmetics Saving | ✅ Verified Implemented | equippedCosmetics {hat, apron}, unlockedCosmetics array |
| Upgrades Saving | ✅ Verified Implemented | unlockedStations array in profile |
| Level Saving | ✅ Verified Implemented | xp, level, bakeryXP, bakeryLevel all persisted |
| Daily/Weekly Challenge Saving | 🔶 Partially Implemented | Profile-persisted. **In-memory counters reset on server crash** |

### UI / UX SYSTEMS
| System | Verification Status | Notes |
|---|---|---|
| Orders UI | ⚠️ Needs Improvement | HUD order cards with patience meter exist. No cookie type icon/thumbnail |
| Tray / Inventory UI | ❌ Missing | No UI showing what player is carrying. Physical box is only indicator |
| Top Bar | ⚠️ Needs Improvement | Coins + level/XP + timer exist. Bakery XP not shown separately |
| Station/Minigame UI | ✅ Verified Implemented | Per-station UI, result popup (emoji+%), MinigameBase.ShowResult |
| Tutorial UI | 🔶 Partially Implemented | 5-step panel + skip button. No waypoint arrows to stations |
| Results Screen UI | ⚠️ Needs Improvement | Shift grade + stats grid + Employee of Shift. No animation, no per-station breakdown |
| Shop UI | ⚠️ Needs Improvement | Two tabs, buy/equip buttons, owned states. No cosmetic preview |
| Daily Challenges UI | ✅ Verified Implemented | DailyChallengeClient, WeeklyChallengeClient, LifetimeChallengeClient all exist |
| Settings UI | ❌ Missing | No settings panel (volume sliders, etc.) |
| Mobile UI Scaling | 🔶 Partially Implemented | Relative sizing used (45% viewport). Not tested on portrait/tablet |
| Controller Support | ❌ Missing | No gamepad input for minigames |
| Visual Feedback | ✅ Verified Implemented | Floating reward text, worker score, delivery stars, patience color |
| "What Next?" UI | ❌ Missing | **CRITICAL** — no waypoints, hints, or coach tips after tutorial |

### FEEDBACK / GAME FEEL
| System | Verification Status | Notes |
|---|---|---|
| Sound Effects | ✅ Verified Implemented | 15 sounds covering all key moments |
| Music | ✅ Verified Implemented | Background loop at 0.1 volume |
| Floating Text (+XP, +Money) | ✅ Verified Implemented | DeliveryFeedback + WorkerFeedback remotes, tweened float-up |
| Quality Result Popups | ✅ Verified Implemented | emoji + label + score %, 2.5s duration via MinigameBase |
| Combo Popups | 🔶 Partially Implemented | ComboUpdate fires, HUD updates. No "COMBO BROKEN!" popup |
| Screen Effects | ❌ Missing | No ColorCorrection, no screen flash on level-up |
| Station Progress Bars | ✅ Verified Implemented | Each minigame has its own progress visualization |
| NPC Patience Indicator (in-world) | ❌ Missing | Patience on HUD only. No above-head BillboardGui bar |
| Order Ready Alerts | ❌ Missing | No sound/visual when warmers fill up (ready for Dress station) |
| Level Up Celebration | 🔶 Partially Implemented | MasteryLevelUp remote fires. Client-side celebration not confirmed |

### PROGRESSION
| System | Verification Status | Notes |
|---|---|---|
| Level Unlocks | 🔶 Partially Implemented | Level tracked. **No content gated behind any level** |
| New Recipes | ❌ Missing | All 6 cookies available from day 1. unlockedRecipes=4 not enforced |
| New Stations | ❌ Missing | unlockedStations in profile but nothing gates stations |
| Upgrades | ✅ Verified Implemented | tip_boost×2, patience_boost×2. Only 4 upgrades total |
| Cosmetics | ✅ Verified Implemented | 10+ shop cosmetics + 4 mastery unlocks |
| Achievements (Lifetime Challenges) | ✅ Verified Implemented | 30+ lifetime milestones (orders, cookies sold, bakery level, mastery) |
| Daily Challenges | ✅ Verified Implemented | 3 per day, date-keyed, coin rewards |
| Weekly Challenges | ✅ Verified Implemented | 3 per week, tiered Easy/Med/Hard |
| Shift Grades | ⚠️ Needs Improvement | A–D implemented. **S-rank missing** |
| Rush Hour Mode | ✅ Verified Implemented | Fires at 70% of Open elapsed, faster NPC spawn (60s→20s) |
| VIP Customers | ⚠️ Needs Improvement | 10% spawn chance, 1.75× payout. **No visual distinction on NPC** |
| Events | ❌ Missing | EventManager.server.lua exists as stub. No event logic |
| Daily Login Rewards | ❌ Missing | Not implemented |

### PERFORMANCE
| System | Verification Status | Notes |
|---|---|---|
| Remote Event Frequency | ✅ Verified Implemented | M-4 debounce on broadcasts |
| Memory Leaks | 🔍 Needs Verification | NPC models destroyed on leave, MinigameBase tracker prevents stacking |
| NPC Cleanup | ✅ Verified Implemented | AncestryChanged + PlayerRemoving handlers |
| Connection Cleanup | ✅ Verified Implemented | MinigameBase.NewTracker() used across all minigames |
| Too Many UI Elements | 🔍 Needs Verification | Order cards dynamically created; need to verify cap |
| Too Many Loops | 🔍 Needs Verification | No obvious RunService loops seen; needs profiler check |
| Server Heavy Operations | 🔍 Needs Verification | Rush Hour + 6 players is peak load scenario |
| Lag Sources | 🔍 Needs Verification | OrderManager batch table growth not capped; needs shift-reset verification |

### POLISH
| System | Verification Status | Notes |
|---|---|---|
| End-of-Shift Results Screen | ⚠️ Needs Improvement | Exists. No animation, no per-station breakdown |
| Tutorial | 🔶 Partially Implemented | 5-step linear flow. Missing Fridge→Oven step. No camera pans confirmed |
| Main Menu | 🔍 Needs Verification | MainMenuController.client.lua exists; contents not fully verified |
| Settings Menu | ❌ Missing | No settings panel |
| Credits | ❌ Missing | Not found in codebase |
| Intro / Cutscene | ❌ Missing | Not found |
| Gamepass / Dev Products | ❌ Missing | No gamepass validation or IAP integration found |
| Shop UI Polish | ⚠️ Needs Improvement | Functional but no cosmetic preview, no tooltip descriptions |
| Animation Polish | ⚠️ Needs Improvement | Box carry arm animation causes Motor6D detach bug |

---

## 📊 SECTION 2 — SYSTEM STATUS BOARD

| System | Status | Priority | Alpha? |
|---|---|---|---|
| Order/Batch Pipeline | Complete | — | ✅ Done |
| NPC Lifecycle | Needs Improvement | HIGH | Before |
| NPC Facing Direction | In Progress (broken) | HIGH | Before |
| Station Movement Locking | Not Started | **CRITICAL** | Before |
| Box Carry (physical) | Needs Improvement | HIGH | Before |
| Delivery Race Lock | Not Started | HIGH | Before |
| Shift Lifecycle | Complete | — | ✅ Done |
| Money/Payout | Complete | — | ✅ Done |
| XP/Level Tracking | Complete | — | ✅ Done |
| Level Unlock Content | Not Started | HIGH | Before |
| Quality Scoring | Needs Improvement | HIGH | Before |
| Combo System | Complete | — | ✅ Done |
| Customer Patience | Needs Improvement | MEDIUM | Before |
| DataStore/Saving | Complete | — | ✅ Done |
| Station Mastery | Complete | — | ✅ Done |
| Daily/Weekly/Lifetime Challenges | Complete | — | ✅ Done |
| "What Next?" Guidance | Not Started | **CRITICAL** | Before |
| Carry Indicator UI | Not Started | HIGH | Before |
| In-World NPC Patience | Not Started | MEDIUM | Before |
| Order Ready Alert | Not Started | MEDIUM | Before |
| Rush Hour Announcement | Not Started | MEDIUM | Before |
| Dress Station Quality Fix | Not Started | HIGH | Before |
| Tutorial Fridge→Oven Step | Not Started | HIGH | Before |
| Warmer Sync for New Joiners | Not Started | MEDIUM | Before |
| Dress Order Lock Timeout | Not Started | HIGH | Before |
| Remote Rate Limiting | Not Started | HIGH | Before |
| VIP NPC Visual | Not Started | MEDIUM | Before |
| S-Rank Grade Tier | Not Started | MEDIUM | Before |
| Settings UI | Not Started | MEDIUM | Before |
| Mobile Scaling Pass | Not Started | MEDIUM | Before |
| Results Screen Polish | Needs Improvement | MEDIUM | Before |
| Shop Preview / Tooltips | Needs Improvement | MEDIUM | Before |
| Gamepass Integration | Not Started | MEDIUM | Before |
| Daily Login Rewards | Not Started | LOW | After |
| Event System | Not Started | LOW | After |
| Controller Support | Not Started | LOW | After |
| Screen Effects | Not Started | LOW | After |
| Rebirth / Prestige | Not Started | LOW | After |
| Social Actions | Not Started | LOW | After |
| Rejoin Protection | Not Started | LOW | After |
| Custom Leaderboard UI | Not Started | LOW | After |

---

## 🎯 SECTION 3 — PRIORITY BOARD

### 🔴 CRITICAL (Blockers — Must be done before ANY Alpha testing)
| # | System | Why |
|---|---|---|
| C-1 | Station Movement Locking | Players walk away mid-minigame → batch pool starved, session hangs 60s |
| C-2 | "What Next?" Guidance System | New players quit immediately with no waypoints or coach tips |

### 🟠 HIGH (Must be done before Alpha)
| # | System | Why |
|---|---|---|
| H-1 | NPC Facing Direction Fix | NPCs face wall — first impression is broken |
| H-2 | Dress Station Quality Scoring | Hardcoded 85 breaks entire quality system for frosted cookies |
| H-3 | Delivery Race Lock | Two players can deliver to same NPC simultaneously |
| H-4 | Dress Order Lock Timeout | Disconnected player locks an order slot for entire shift |
| H-5 | Level Unlock Content | Leveling up to nothing destroys long-term retention |
| H-6 | Tutorial Fridge→Oven Step | Tutorial ends before teaching the full pipeline |
| H-7 | Remote Rate Limiting | PurchaseItem and RequestMixStart have no per-client throttle |
| H-8 | Carry Indicator UI | Players don't know they're holding a box or where to deliver it |

### 🟡 MEDIUM (Should be done before Alpha)
| # | System | Why |
|---|---|---|
| M-1 | In-World NPC Patience Indicator | Players at stations go blind to NPC timeouts |
| M-2 | Order Ready Alert | Players don't know when warmers fill up; stand idle |
| M-3 | Rush Hour Visual Announcement | Players miss the Rush Hour event entirely |
| M-4 | Warmer Stock Sync for Joining Players | Mid-shift joiners see empty warmers incorrectly |
| M-5 | VIP NPC Visual Distinction | VIP NPCs look identical to normal NPCs |
| M-6 | S-Rank Shift Grade | A is the current ceiling; S gives high performers a target |
| M-7 | Results Screen Animation | Appears instantly with no celebration; feels like debug screen |
| M-8 | Settings UI (volume slider) | No way to control audio |
| M-9 | Mobile Scaling Pass | Not tested on portrait or tablet ratio |
| M-10 | Combo Break Popup | No "STREAK BROKEN!" feedback |
| M-11 | Loading Indicator (data load) | Blank-state flash while PlayerDataManager loads |
| M-12 | Gamepass Integration Scaffold | Revenue; should at least have Speed Pass before Alpha |

### 🟢 LOW (Polish — After Alpha)
| # | System | Why |
|---|---|---|
| L-1 | Daily Login Rewards | Retention; not needed for first Alpha |
| L-2 | Event System | Seasonal content; post-launch |
| L-3 | Controller Support | Nice to have; ProximityPrompts already work by default |
| L-4 | Screen Effects (ColorCorrection, shake) | Visual polish |
| L-5 | Rebirth / Prestige | Late-game loop |
| L-6 | Social Actions (wave, high-five) | Community feature |
| L-7 | Rejoin Session Protection | QOL; session data restores after 60s disconnect |
| L-8 | Custom Leaderboard UI | Native leaderstats is sufficient for Alpha |
| L-9 | Credits Screen | Nice-to-have polish |
| L-10 | Intro Cutscene | Post-Alpha when narrative is set |

---

## 🔨 SECTION 4 — CURRENT TASK

**TASK:** `H-4 — Dress Order Lock Timeout`
**Status:** Not Started → Ready to begin
**What it is:** If a player disconnects while holding a dress order lock, `dressLocked[player]` and `orderLockedBy[orderId]` are never cleared — that order slot is dead for the entire shift.
**Files affected:**
- `DressStationServer.server.lua` — add Players.PlayerRemoving cleanup + 90s server-side timeout
**Success criteria:** A disconnected player's dress lock clears within 90s; the order reappears on the KDS.

---

## 📋 SECTION 5 — NEXT TASK QUEUE

| Order | Task ID | System | Notes |
|---|---|---|---|
| 1 | **H-4** | Dress Order Lock Timeout | Current task — 90s timeout + PlayerRemoving cleanup in DressStationServer |
| 2 | **H-5** | Level Unlock Content | 3 things: level 3=tip upgrade, level 5=snickerdoodle, level 10=C&C |
| 3 | **H-6** | Tutorial Fridge→Oven Step | Add step 4.5 teaching pull-from-fridge |
| 4 | **H-2** | Dress Quality Scoring | Remove DRESS_SCORE=85, pass actual minigame score |
| 5 | **H-3** | Delivery Race Lock | First delivery wins; second gets "order already claimed" |
| 6 | **H-4** | Dress Order Lock Timeout | 90s timeout; unlock on disconnect or timeout |
| 7 | **H-5** | Level Unlock Content | 3 things: level 3=tip upgrade, level 5=snickerdoodle, level 10=C&C |
| 8 | **H-6** | Tutorial Fridge→Oven Step | Add step 4.5 teaching pull-from-fridge |
| 9 | **H-7** | Remote Rate Limiting | 1 req/s on PurchaseItem; 1/2s on RequestMixStart |
| 10 | **H-8** | Carry Indicator UI | Bottom-center: box icon + "Deliver to: NPC Name" |
| 11 | **M-1** | In-World Patience Bar | BillboardGui above NPC head, updates live |
| 12 | **M-2** | Order Ready Alert | Sound + HUD pill when warmers receive a cookie |
| 13 | **M-3** | Rush Hour Announcement | "🔥 RUSH HOUR!" banner slides in at trigger |
| 14 | **M-4** | Warmer Sync for Joiners | FireClient snapshot on PlayerAdded during Open phase |
| 15 | **M-5** | VIP NPC Visual | Golden crown or gold outline on VIP NPC model |
| 16 | **M-6** | S-Rank Grade | 97+ score threshold in SessionStats.GetShiftGrade |
| 17 | **M-7** | Results Screen Animation | Slide-up tween + staggered stat counters |
| 18 | **M-8** | Settings UI | Minimal: music/SFX sliders, exit button |
| 19 | **M-9** | Mobile Scaling Pass | UIScale test on 375px portrait + 768px tablet |
| 20 | **M-12** | Gamepass Scaffold | Speed Pass + Boost Token stubs |

---

## ✅ SECTION 6 — COMPLETED TASKS LOG

| Date | Task | Notes |
|---|---|---|
| 2026-03-24 | OrderManager moved from ReplicatedStorage → SSS/Core | All 12 require paths updated in disk + Studio |
| 2026-03-24 | DEV_SKIP_PREOPEN set to false | PreOpen (3 min) now runs in live play |
| 2026-03-24 | OPEN_DURATION set to 8 minutes | Agreed pacing after discussion |
| 2026-03-24 | Variety pack (VARIETY_CHANCE) set to 40% | NPCs now order mixed cookie types |
| 2026-03-24 | **C-1 Station Movement Locking** | WalkSpeed/JumpPower/JumpHeight=0 in startSession; unlocked in endSession + cleanupPlayerSession + watchdog (MinigameServer.server.lua) |
| 2026-03-24 | **BUG-14/15/16 GameStateManager Studio sync** | Root cause: stale Studio script required deleted RS/Modules/OrderManager. Fixed: pushed correct source (SSS/Core path, PREOPEN_DURATION=3m, OPEN_DURATION=8m, SSS declared before require). All 3 bugs resolved. |
| 2026-03-24 | **Studio-wide OrderManager path migration** | 9 additional scripts (DressStationServer, FridgeDisplayServer, PersistentNPCSpawner, StaffManager, LeaderboardManager, DriveThruServer, StationRemapService, POSController, BoxCarryServer) still had RS/Modules path in Studio — fixed via targeted string replace. SSS declaration added to 4 that were missing it. |
| 2026-03-24 | **OrderManager CookieData require fix** | OrderManager used `script.Parent:WaitForChild("CookieData")` — CookieData is in RS/Modules not SSS/Core. Fixed to `ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CookieData")` on disk + Studio. |
| 2026-03-24 | **AIBakerSystem Studio sync** | Used aliased vars (RS/SSS) so wasn't caught by first scan. Studio had `RS:WaitForChild("Modules")` for OrderManager — fixed to `SSS:WaitForChild("Core")`. Disk was already correct. |
| 2026-03-24 | **REGRESSION/NEW BUG RULE added** | 8-step protocol section added to MASTER_PROJECT_FILE: log first, root cause required, fix narrowly, verify in Studio, mark resolved. Studio Sync Rule added. |
| 2026-03-25 | **C-2 "What Next?" Guidance System** | PlayerTipUpdate remote added. Coach bar (bottom-center dark pill) in HUDController. 9 tip triggers: PreOpen, Open, mix/dough/oven/frost/dress completions, EndOfDay, Intermission. 8s auto-dismiss with fade tween. |
| 2026-03-25 | **H-1 NPC Facing Direction Fix** | Root cause: task.defer fired before Humanoid AutoRotate physics settled. Fix: task.spawn+task.wait(0.2), AutoRotate=false during CFrame snap, re-enable after 0.1s. Applied to facePosition() in PersistentNPCSpawner. |
| 2026-03-25 | **H-2 Dress Station Quality Scoring** | Root cause: DRESS_SCORE=85 hardcoded in both CreateBox and CreateVarietyBox calls on the no-topping path. Fix: removed constant, added avgSnapshot() helper, no-topping path now uses entry.snapshot (accumulated station quality). Topping-minigame path already used real score — untouched. |
| 2026-03-24 | Dress station ScrollingFrame implemented | Orders list now scrollable for 4+ entries |
| 2026-03-24 | BoxCarryServer.server.lua created | Physical box welded to player HRP, transfers to NPC |
| 2026-03-24 | NPC facePosition() function added | Replaced faceClosestPOS calls in waiting_in_queue state |
| Prior session | Full codebase audit completed (66 scripts) | All systems verified against source |
| Prior session | Mix→Dough batch progression fixed | Session management / server-side race resolved |
| Prior session | Core minigame infrastructure refactored | No global state, no connection stacking, centralized remotes |

---

## 🐛 SECTION 7 — KNOWN BUGS / RISKS

| ID | Severity | System | Description | Status |
|---|---|---|---|---|
| BUG-1 | 🔴 Critical | Minigames | No movement lock — players walk away mid-session | ✅ Resolved 2026-03-24 |
| BUG-2 | 🔴 Critical | NPC System | NPCs face wall during wait_in_queue despite facePosition() call | Open |
| BUG-3 | 🟠 High | Quality Scoring | DRESS_SCORE = 85 hardcoded — dress quality always 85 regardless of performance | ✅ Resolved 2026-03-25 |
| BUG-4 | 🟠 High | Box Carry | Arms detach when carrying box (Motor6D.Enabled = false disconnects joint) | Open |
| BUG-5 | 🟠 High | Delivery | Two players can fire DeliverBox to same NPC simultaneously (no delivery lock) | ✅ Resolved — deliveryLocked flag already present (atomic check+set, 7 sites) |
| BUG-6 | 🟠 High | Dress Station | dressLocked[player] has no timeout — disconnected player locks order slot forever | Open |
| BUG-7 | 🟠 High | Multiplayer | New joiner mid-shift doesn't receive current warmer stock snapshot | Open |
| BUG-8 | 🟡 Medium | Data | In-memory challenge counters reset on server crash (daily/weekly progress loss) | Known Limitation |
| BUG-9 | 🟡 Medium | Exploits | No rate limit on RequestMixStart — can spam server-side batch creation attempts | Open |
| BUG-10 | 🟡 Medium | Exploits | No rate limit on PurchaseItem — UpdateAsync called per spam attempt | Open |
| BUG-11 | 🟡 Medium | Dough | doughLock may not clear in rare race on disconnect during session start | Suspected |
| BUG-12 | 🟡 Medium | Box Carry | Box transfer BindableEvent fires but client NPCCarryPoseUpdate may desync | Open |
| BUG-13 | 🟡 Medium | NPC | NPCs colliding while walking can lift to ceiling and block entry queue | Confirmed by user |
| BUG-14 | 🔴 Critical | GameStateManager | "Could not start minigame" — Studio had stale GameStateManager requiring deleted RS/Modules/OrderManager → WaitForChild hang → runCycle never started | ✅ Resolved 2026-03-24 |
| BUG-15 | 🔴 Critical | GameStateManager | Phase name stuck at "Loading" — same root as BUG-14; GameStateChanged never fired "Open" because runCycle was frozen | ✅ Resolved 2026-03-24 |
| BUG-16 | 🔴 Critical | Challenge UI | Daily/Weekly UI panels hidden — DailyChallengeClient only shows when gameState=="Open"; state never reached Open due to BUG-14 | ✅ Resolved 2026-03-24 |
| RISK-1 | 🟠 High | DataStore | Server crash before session lock release = silent save skip = data loss | Known Risk |
| RISK-2 | 🟠 High | Progression | Level unlocks nothing — players have no reason to grind | Design Gap |
| RISK-3 | 🟡 Medium | Onboarding | No waypoints = new players quit before first delivery | Design Gap |
| RISK-4 | 🟡 Medium | Retention | No daily login reward = no daily pull-back mechanic | Design Gap |

---

## ☑️ SECTION 8 — ALPHA CHECKLIST

### MUST HAVE (Blockers)
- [x] **C-1** Station movement locking during minigames
- [ ] **C-2** "What Next?" guidance (waypoints or coach tip bar)
- [ ] **H-1** NPC facing counter correctly
- [ ] **H-2** Dress station quality scoring (remove hardcode)
- [ ] **H-3** Delivery race lock (first delivery wins)
- [ ] **H-4** Dress order lock timeout on disconnect
- [ ] **H-5** Level unlock content (3 tiers minimum)
- [ ] **H-6** Tutorial fridge→oven step added
- [ ] **H-7** Remote rate limiting on PurchaseItem + RequestMixStart
- [ ] **H-8** Carry indicator UI (box icon + destination)
- [ ] BUG-4 Box carry arms not detaching
- [ ] BUG-13 NPC collision ceiling lift fixed

### SHOULD HAVE (Quality bar)
- [ ] **M-1** In-world NPC patience indicator
- [ ] **M-2** Order ready alert (sound + HUD pill)
- [ ] **M-3** Rush Hour announcement banner
- [ ] **M-4** Warmer stock sync for joining players
- [ ] **M-5** VIP NPC visual distinction
- [ ] **M-6** S-Rank shift grade
- [ ] **M-7** Results screen animation
- [ ] **M-8** Settings UI (volume slider)
- [ ] **M-9** Mobile scaling tested on portrait + tablet
- [ ] **M-10** Combo break popup
- [ ] **M-11** Loading indicator during data load
- [ ] **M-12** Gamepass scaffold (Speed Pass stub)

### NICE TO HAVE (Polish for Alpha)
- [ ] Per-station breakdown in shift results
- [ ] Cosmetic preview in shop
- [ ] Upgrade tooltips in shop
- [ ] Cookie type icon/thumbnail on order cards
- [ ] Customer satisfaction emoji on delivery
- [ ] "Order expired" visual at NPC location

---

## 💡 SECTION 9 — POST-ALPHA / FUTURE IDEAS

> Do NOT build these until after Alpha. Log here to prevent scope creep.

| Idea | Category | Why Later |
|---|---|---|
| Daily login reward streak | Retention | Need live player data to balance rewards |
| Event system (Valentine's, Halloween) | Content | Seasonal; post-launch |
| Controller/gamepad support for minigames | Accessibility | Keyboard only needed for Alpha |
| Screen effects (ColorCorrection, shake) | Polish | Performance profiling first |
| Rebirth / prestige system | Late-game | Needs stable early-game loop first |
| Social actions (wave, high-five, cheer) | Community | Community size needed to justify |
| Rejoin session protection | QOL | Polish; 60s watchdog handles most cases |
| Custom leaderboard UI | Social | Native leaderstats sufficient for Alpha |
| Credits screen | Polish | Post-launch |
| Intro cutscene | Narrative | Story not yet defined |
| Bakery customization (furniture) | Feature | Major scope addition |
| Multiple floor expansion | Feature | Late progression |
| Player-owned AI staff | Feature | Major system |
| Recipe crafting / fusion | Content | Post-launch variety |
| Seasonal tournaments | Events | Need player base first |
| Shared visible order board (in-world TV) | UX | Great feature; Medium scope |
| Player role claiming at shift start | Design | Encourages teamwork |
| Cookie of the Day mechanic | Retention | Post-Alpha daily rotation |
| Shift upgrade spin wheel (intermission) | Game Feel | Fun but not critical |
| "Speedy" badge for sub-5s minigame | Feedback | Minor polish |

---

## 📐 SECTION 10 — ARCHITECTURE REFERENCE

### File Layout
```
ServerScriptService/
  Core/
    GameStateManager.server.lua    ← Shift lifecycle state machine
    OrderManager.lua               ← Batch pipeline (MOVED FROM RS ✅)
    PlayerDataManager.lua          ← DataStore + auto-save
    PersistentNPCSpawner.server.lua ← NPC lifecycle
    SessionStats.lua               ← Per-shift stats + shift grade
    StationMasteryManager.lua      ← Role mastery XP/levels
    UnlockManager.lua              ← Shop purchases + cosmetics
    DailyChallengeManager.lua      ← Daily challenges
    WeeklyChallengeManager.lua     ← Weekly challenges
    LifetimeChallengeManager.lua   ← Milestone achievements
    EconomyManager.lua             ← Payout formulas (in RS)
    BakeryManager.lua              ← Bakery nameplate
    MenuManager.lua                ← Active cookie menu state
    StationRemapService.lua        ← Warmer/fridge remap per shift
    BoxCarryServer.server.lua      ← Physical box carry state
    TutorialController.server.lua  ← Tutorial server authority
    Leaderboard.server.lua         ← Native leaderstats
  Minigames/
    MinigameServer.server.lua      ← Central session orchestrator
    DressStationServer.server.lua  ← KDS + dress order flow

ReplicatedStorage/
  Modules/
    RemoteManager.lua              ← Single source of truth for all remotes
    MinigameBase.lua               ← Connection tracker + result popup
    CookieData.lua                 ← All cookie definitions
    EconomyManager.lua             ← Payout formulas
    NPCSpawner.lua                 ← NPC model instantiation

StarterPlayerScripts/
  TutorialUI.client.lua
  SoundController.client.lua
  ShopClient.client.lua
  CarryPoseClient.client.lua
  Minigames/ (all client minigame handlers)

StarterGui/
  HUD/HUDController.client.lua    ← Top bar + order cards + combo
  SummaryGui/SummaryController.client.lua ← End-of-shift screen
  MainMenuGui/MainMenuController.client.lua
  POSGui/POSClient.client.lua
```

### Hard Constraints (DO NOT VIOLATE)
- Stage names exactly: `mix`, `dough`, `oven`, `frost`, `dress`
- All RemoteEvents created via RemoteManager only
- Server authoritative for all game-critical state
- No business logic in client scripts
- All minigame sessions validated: 3s min duration, score range 0–100, type match
- OrderManager must stay in SSS/Core (moved 2026-03-24)

---

## 📊 SECTION 11 — TASK 2: PROBLEMS AND RISKS SUMMARY

### Dangerous / Could Break
1. No movement lock → batch pool can be starved in high-player scenario
2. Dress hardcoded score → quality system produces false data
3. NPC ceiling lift bug (confirmed collision issue) → NPC queue gets stuck
4. No delivery lock → two players claiming same NPC order

### Not Multiplayer Safe
1. Warmer stock not synced to mid-shift joiners
2. Dress order lock has no expiry on disconnect
3. Box carry state can desync (BindableEvent vs RemoteEvent timing)
4. Dough lock may orphan on rare disconnect race

### Exploitable
1. RequestMixStart — no rate limit; spamming causes server load
2. PurchaseItem — no rate limit; spams UpdateAsync calls
3. Session farming for mastery XP (walk away, wait 60s timeout, repeat)

### Missing That Successful Roblox Games Have
- Waypoint/hint system (Cook Burgers, Work at a Pizza Place)
- Visible player role labels above head
- Shared in-world order board visible to all
- Filler tasks during downtime (passive income)
- Social actions between players
- Daily login streak

### Will Confuse New Players
- No "what do I press?" prompt before stations
- Fridge→Oven step not taught in tutorial
- Cookie types not mapped to fridge slots visually
- Dress station: not clear which cookie is being decorated
- No indicator that a batch is waiting in fridge

### Will Make Players Quit Early
- Nothing unlocked by leveling up
- 3-minute intermission with nothing to do
- Rush Hour starts silently (no fanfare)
- No "mistake" feedback when session times out
- Combo resets with no visual punishment feedback

---

## 🧪 SECTION 12 — TESTING PLAN

### Bug Testing
- [ ] Complete full solo shift Lobby → Intermission without errors
- [ ] Mix + deliver all 6 cookie types in one session
- [ ] Let NPC patience expire; verify order removed cleanly
- [ ] Let session time out (60s); verify batch unlocked
- [ ] Complete tutorial as new player (tutorialCompleted=false)
- [ ] Verify tutorial skips for returning player
- [ ] Buy every shop item; verify prerequisites enforced
- [ ] Equip cosmetic; rejoin; verify cosmetic persists
- [ ] Verify coins save on rejoin
- [ ] Trigger Rush Hour; verify faster spawn rate
- [ ] Verify End-of-Day summary with correct stats
- [ ] Complete all 3 daily challenges; verify rewards
- [ ] Complete a lifetime milestone; verify one-time award

### Multiplayer Testing
- [ ] 2 players mix same batch simultaneously → only one succeeds
- [ ] 2 players pull same fridge item → only one succeeds
- [ ] 2 players accept same dress order → only one succeeds
- [ ] 2 players deliver to same NPC → no duplicate payout
- [ ] Player disconnects mid-mix → doughLock clears
- [ ] Player joins mid-shift → warmer stock visible (after fix)
- [ ] Player leaves holding box → box destroyed on server
- [ ] 6-player full session → batch pool not starved
- [ ] Rush Hour + 6 players → NPC cap (6) enforced

### Exploit Testing
- [ ] Fire ResultMix with score=1000 → clamped to 100
- [ ] Fire ResultMix with score="hack" → rejected
- [ ] Fire ResultMix 0.1s after session start → rejected (< 3s)
- [ ] Fire ResultMix for cookieId not on menu → rejected
- [ ] Fire PurchaseItem without coins → rejected
- [ ] Fire PurchaseItem for owned item → rejected
- [ ] Spam RequestMixStart 50×/1s → no server error, batch blocked
- [ ] Fire DeliverBox with nonexistent NPC → safe nil handling

### Performance Testing
- [ ] Server script activity < 10ms avg during Rush Hour
- [ ] Memory stable after 10+ shifts with 6 players
- [ ] No RunService loops running after shift ends
- [ ] < 30 RemoteEvent fires/sec at peak load
- [ ] OrderManager batch tables cleared between shifts
- [ ] NPC models fully destroyed (not just unparented) on leave
- [ ] Sounds reused (not recreated per-play)

### UI Testing
- [ ] Shop: buy item → coin display updates immediately
- [ ] Minigame: result popup appears + disappears in 2.5s
- [ ] Patience meter updates in real-time on order card
- [ ] HUD combo counter updates on each delivery
- [ ] Shift results show correct player-specific stats
- [ ] Daily challenge panel shows correct progress
- [ ] Test at 1366×768, 1920×1080, 375×812 (mobile portrait)
- [ ] No UI overlap between order cards and combo counter
- [ ] Dress station KDS scrolls with 4+ orders

### Alpha Playtest Checklist
- [ ] 5 first-time players complete tutorial without asking how to play
- [ ] Average player makes 2+ deliveries in 8-minute shift
- [ ] No server crash in 30 minutes of play
- [ ] No data loss on rejoin within 5 minutes
- [ ] All 6 cookie types baked in one session
- [ ] Rush Hour event noticed by players
- [ ] Combo system understood within 3 shifts
- [ ] End-of-shift summary read (not instantly closed)
- [ ] At least 1 player returns voluntarily for second session

---

## 🎮 SECTION 13 — GAME DESIGN IMPROVEMENTS (Future Reference)

### Major Features (Plan post-Alpha or large scope)
- Shared in-world order board TV (all players see same orders)
- Station role claiming at shift start (Mixer/Baker/Decorator)
- Recipe unlock gating by level (snickerdoodle=5, C&C=10, lemon=15)
- Shift Upgrade Spin Wheel during intermission

### Retention Systems
| System | Why It Works |
|---|---|
| Daily challenge streak bonus | Miss one day = lose streak |
| Shift grade personal best | Beat your own A to get S |
| Mastery milestone coin rewards | Already in — needs client celebration |
| Cookie of the Day | Forces daily login |
| Weekly leaderboard by coins | Competitive |

### Monetization (Fair)
- Speed Pass (299 R$) — skip PreOpen phase
- Boost Token (50 R$) — 2× coins for one shift
- Extra Batch Slot (499 R$) — +1 simultaneous mix batch
- Cosmetic Bundles (seasonal, 199–399 R$)
- VIP Server (built-in Roblox)

---

## 📈 SECTION 14 — FINAL REPORT SNAPSHOT

| Category | Score | Notes |
|---|---|---|
| Core Systems | 85% | Pipeline solid, dress score broken |
| Multiplayer Safety | 65% | Missing locks + sync issues |
| Data Integrity | 80% | Cross-server lock present; retry missing |
| UI/UX | 60% | Functional but no guidance or carry UI |
| Progression/Retention | 55% | Level unlocks nothing; no login reward |
| Performance | 75% | Good patterns; needs profiler run |
| Anti-Exploit | 70% | Good validation; missing rate limits |
| Game Feel/Polish | 60% | Sound complete; guidance and feedback gaps |
| **OVERALL** | **🟡 69%** | **Not Alpha Ready — needs ~4 weeks of work** |

### Top 5 Risks Before Alpha
1. No movement locking → game-breaking batch starvation
2. No "What Next?" → new player retention failure
3. Dress quality hardcoded → quality system outputs false data
4. Level unlocks nothing → zero grind incentive
5. Two-player delivery race → potential exploit / NPC state corruption

---
*End of MASTER PROJECT FILE — Always update this file, never rewrite. Keyphrase: COOKIE ALPHA MASTER FILE*
