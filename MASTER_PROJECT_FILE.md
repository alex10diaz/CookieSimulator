# 🍪 COOKIE SIMULATOR — MASTER PROJECT FILE
**Keyphrase:** COOKIE ALPHA MASTER FILE
**Last Updated:** 2026-04-02 (Session 18 — Pre-release final fix pass. Session 17 completed all 14 BUG-67–80 + FEAT-2/3. Session 18 playtest (2026-04-02) found 12 new bugs BUG-81–92 + 3 features FEAT-4/5/6. Release is tomorrow. Key fixes this session: BUG-84 combo clear, BUG-85 DeductCoins HUDUpdate, BUG-86 drive-thru arm pose, BUG-87 shift label position, BUG-88 station grades, BUG-89 menu unlock "...", BUG-92 ObjectText cleanup.)
**Overall Alpha Readiness:** 🟢 88% — All Session 17 bugs resolved. Core loop verified 3-shift solo. Variety pack, tutorial, combo, carry, warmer prompts all working. 12 new Session 18 bugs — most are cosmetic/polish. Release candidate with known issues documented.
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
| Station System (Mix/Dough/Oven/Frost) | ✅ Verified Implemented | All 4 stations functional. Movement locked (WalkSpeed/JumpPower/JumpHeight=0) on session start — C-1 ✅ |
| Box System | ✅ Verified Implemented | Physical box welded to HRP, transfers to NPC. ManualWeld conflict fixed — BUG-4 ✅ |
| Delivery System | ✅ Verified Implemented | Payout works. deliveryLocked flag prevents race (atomic check+set, 7 sites) — H-3 ✅ |
| Shift System | ✅ Verified Implemented | PreOpen(3m)→Open(8m)→EndOfDay(30s)→Intermission(3m). Rush Hour at 70% elapsed |
| Round Reset | ✅ Verified Implemented | SessionStats.Reset(), OrderManager clear, NPC cleanup |
| Money System | ✅ Verified Implemented | Server-authoritative. Base×speed×accuracy×combo×VIP, capped 3× |
| XP System | ✅ Verified Implemented | Player XP + Bakery XP (separate tracks). `100 × level^1.35` curve |
| Level System | ✅ Verified Implemented | Bakery lvl 3 gates tip_boost_1. Lvl 5 auto-grants C&C. Lvl 10 auto-grants lemon_blackraspberry — H-5 ✅ |
| Quality Scoring | ✅ Verified Implemented | Mix/Dough/Oven/Frost scored correctly. Dress now uses avgSnapshot() from batch — H-2 ✅ |
| Combo System | ✅ Verified Implemented | IncrementCombo/ResetCombo, capped at 20, 1.05× per stack, ComboUpdate remote |
| Customer Patience | ✅ Verified Implemented | Patience logic + HUD bar + in-world color bar above NPC head (green→red) — M-1 ✅ |
| Bakery Rating | 🔶 Post-Alpha | Shift grade S/A/B/C/D calculated and shown. Persistent reputation across shifts is post-Alpha by design. |

### MULTIPLAYER SYSTEMS
| System | Verification Status | Notes |
|---|---|---|
| Station Locking (movement) | ✅ Verified Implemented | WalkSpeed/JumpPower/JumpHeight=0 on session start; restored in endSession, cleanupPlayerSession, watchdog |
| Item Ownership | ✅ Verified Implemented | doughLock, ovenSession, dressPending all prevent double-grab |
| Delivery Ownership | ✅ Verified Implemented | deliveryLocked flag confirmed present (atomic check+set, 7 sites). First delivery wins — H-3 ✅ |
| Player Leaving Mid-Task | ✅ Verified Implemented | cleanupPlayerSession on PlayerRemoving; 60s watchdog clears orphans |
| Player Joining Mid-Shift | ✅ Verified Implemented | task.defer in PlayerAdded fires BatchUpdated + FridgeUpdated + WarmersUpdated snapshot — M-4 ✅ |
| Remote Spam Protection | ✅ Verified Implemented | 1s throttle on PurchaseItem; 0.5s throttle on RequestMixStart (silent drop) — H-7 ✅ |
| Server Validation | ✅ Verified Implemented | Score range, type, session match, cookieId, menu lock all validated |
| Anti-Exploit Checks | ✅ Verified Implemented | 3s min duration, score is-number, station type match, cookieId validation |
| Session Validation | ✅ Verified Implemented | activeSessions[player] keyed and cross-checked on end |
| Race Condition Protection | 🔶 Post-Alpha | doughLock / orderLockedBy / deliveryLocked all present. Fridge pull + dress delivery edge case is a known low-risk gap — post-Alpha. |

### DATA SYSTEMS
| System | Verification Status | Notes |
|---|---|---|
| DataStore Saving | ✅ Verified Implemented | PlayerData_v1, cross-server session lock, UpdateAsync |
| Auto-Save | ✅ Verified Implemented | Per-player coroutine every 300s. No retry on failure |
| Player Data Loading | ✅ Verified Implemented | Deep merge with defaults, migration-safe |
| Cosmetics Saving | ✅ Verified Implemented | equippedCosmetics {hat, apron}, unlockedCosmetics array |
| Upgrades Saving | ✅ Verified Implemented | unlockedStations array in profile |
| Level Saving | ✅ Verified Implemented | xp, level, bakeryXP, bakeryLevel all persisted |
| Daily/Weekly Challenge Saving | 🔶 Post-Alpha | Profile-persisted. In-memory counters reset on server crash — known limitation, acceptable for Alpha. |

### UI / UX SYSTEMS
| System | Verification Status | Notes |
|---|---|---|
| Orders UI | ✅ Verified Implemented | Order cards + patience bar + cookie-type colored border/dot (pink/brown/yellow/gray/cinnamon/lime per type) — Nice-to-have ✅ |
| Tray / Inventory UI | ✅ Verified Implemented | CarryPill shows NPC name when holding box; fires on BoxCreated, clears on delivery |
| Top Bar | 🔶 Post-Alpha | Coins + level/XP + timer implemented. Bakery XP not shown separately — post-Alpha polish. |
| Station/Minigame UI | ✅ Verified Implemented | Per-station UI, result popup (emoji+%), MinigameBase.ShowResult |
| Tutorial UI | ✅ Verified Implemented | 5-step panel + skip button. TutorialCamera cinematic transitions per step. HUD hidden during tutorial (InTutorial attribute). |
| Tutorial Kitchen | ✅ Verified Implemented | Fully isolated workspace area. Standalone TutorialKitchen.lua module. No MinigameServer/OrderManager dependency. DeliverPrompt on customer, FridgeDisplay hidden, 6 spawn markers. |
| Results Screen UI | ✅ Verified Implemented | Slide-up + staggered counters + grade bounce. Per-station strip (Mix/Dough/Oven/Frost/Dress) — Nice-to-have ✅ |
| Shop UI | 🔶 Post-Alpha | Two tabs, buy/equip, owned states, desc tooltips. No cosmetic avatar preview — post-Alpha. |
| Daily Challenges UI | ✅ Verified Implemented | DailyChallengeClient, WeeklyChallengeClient, LifetimeChallengeClient all exist |
| Settings UI | ✅ Verified Implemented | ⚙️ icon top-right opens panel with Music ON/OFF + SFX ON/OFF toggles. Both directly control Sound.Volume. |
| Mobile UI Scaling | ✅ Verified Implemented | All fixed-px frames >360 converted to scale: CoachBar 0.88, CoachTip 0.88, CarryPill 0.82. All station prompts dist=12. |
| Controller Support | ❌ Post-Alpha | No gamepad input for minigames — post-Alpha. ProximityPrompts work by default. |
| Visual Feedback | ✅ Verified Implemented | Floating reward text, worker score, delivery stars, patience color, satisfaction emoji, order-expired X |
| "What Next?" UI | ✅ Verified Implemented | Coach tip bar (bottom-center dark pill). 9 triggers: PreOpen, Open, each station completion, EndOfDay, Intermission — C-2 ✅ |

### FEEDBACK / GAME FEEL
| System | Verification Status | Notes |
|---|---|---|
| Sound Effects | ✅ Verified Implemented | 15 sounds covering all key moments |
| Music | ✅ Verified Implemented | Background loop at 0.1 volume |
| Floating Text (+XP, +Money) | ✅ Verified Implemented | DeliveryFeedback + WorkerFeedback remotes, tweened float-up |
| Quality Result Popups | ✅ Verified Implemented | emoji + label + score %, 2.5s duration via MinigameBase |
| Combo Popups | ✅ Verified Implemented | ComboUpdate: streak≥2 shows pill. On reset from ≥2→0: "STREAK BROKEN!" red showAlert (2s). |
| Screen Effects | ❌ Post-Alpha | No ColorCorrection, no screen flash on level-up — post-Alpha polish. |
| Station Progress Bars | ✅ Verified Implemented | Each minigame has its own progress visualization |
| NPC Patience Indicator (in-world) | ✅ Verified Implemented | BarFill injected into PatienceGui on spawn; green→yellow→red; SetPatienceBar called every patience tick |
| Order Ready Alerts | ✅ Verified Implemented | WarmersUpdated count diff → "Cookie ready to box!" showAlert toast (2.5s) + orderAlertSound chime |
| Level Up Celebration | 🔶 Post-Alpha | MasteryLevelUp remote fires. Full client-side celebration (confetti, sound) is post-Alpha polish. |

### PROGRESSION
| System | Verification Status | Notes |
|---|---|---|
| Level Unlocks | ✅ Verified Implemented | Bakery lvl 3 gates tip_boost_1 purchase. Bakery lvl 5 auto-grants C&C. Bakery lvl 10 auto-grants lemon_blackraspberry. |
| New Recipes | ❌ Missing | All 6 cookies available from day 1. unlockedRecipes=4 not enforced |
| New Stations | ❌ Missing | unlockedStations in profile but nothing gates stations |
| Upgrades | ✅ Verified Implemented | tip_boost×2, patience_boost×2. Only 4 upgrades total |
| Cosmetics | ✅ Verified Implemented | 10+ shop cosmetics + 4 mastery unlocks |
| Achievements (Lifetime Challenges) | ✅ Verified Implemented | 30+ lifetime milestones (orders, cookies sold, bakery level, mastery) |
| Daily Challenges | ✅ Verified Implemented | 3 per day, date-keyed, coin rewards |
| Weekly Challenges | ✅ Verified Implemented | 3 per week, tiered Easy/Med/Hard |
| Shift Grades | ✅ Verified Implemented | S/A/B/C/D — S≥90, A≥75, B≥60, C≥45, D otherwise. Verified in Studio. |
| Rush Hour Mode | ✅ Verified Implemented | Fires at 70% of Open elapsed, faster NPC spawn (60s→20s) |
| VIP Customers | ✅ Verified Implemented | 10% spawn chance, 1.75× payout. Gold "* VIP *" badge above NPC head (AlwaysOnTop, UIStroke glow) — M-5 ✅ |
| Events | ❌ Post-Alpha | EventManager.server.lua stub exists. No event logic — post-Alpha. |
| Daily Login Rewards | ❌ Post-Alpha | Not implemented — post-Alpha retention feature. |

### PERFORMANCE
| System | Verification Status | Notes |
|---|---|---|
| Remote Event Frequency | ✅ Verified Implemented | M-4 debounce on broadcasts |
| Memory Leaks | ✅ Verified | NPCSpawner.Remove + 15s safety Destroy on leave; removeCard() destroys UI cards; sounds created once at init in SoundService — no per-play allocation |
| NPC Cleanup | ✅ Verified | npcs[npcId]=nil + MoveTo exit walk + NPCSpawner.Remove + task.delay(15) safety Destroy |
| Connection Cleanup | ✅ Verified | Minigame clients: all have manual Disconnect(); DriveThruServer: disconnect present; ShopClient preview: clearPreview() disconnects Heartbeat |
| Too Many UI Elements | ✅ Verified | Order cards capped by NPC max (6). removeCard() destroys frame on delivery/expire. No accumulation. |
| Too Many Loops | ✅ Verified | 4 while-true loops confirmed intentional: GameStateManager shift cycle, PersistentNPCSpawner spawn + patience ticker, LeaderboardManager 30s broadcast. All gated on GameState. |
| Server Heavy Operations | 🔍 Needs Live Test | Patterns look clean. Rush Hour + 6 players peak load needs in-game profiler run to confirm. |
| Lag Sources | ✅ Verified | OrderManager.Reset() clears all 7 tables (batches/fridges/ovenBatches/warmers/postOvenScores/npcOrders/boxes) at each shift start. SessionStats.Reset() also called. |

### POLISH
| System | Verification Status | Notes |
|---|---|---|
| End-of-Shift Results Screen | ✅ Verified Implemented | Slide-up + staggered counters + grade bounce + per-station breakdown strip (Mix/Dough/Oven/Frost/Dress, color-coded). |
| Tutorial | ✅ Verified Implemented | 5-step linear flow covers full pipeline incl. fridge→oven (H-6 verified). No waypoint arrows — post-Alpha. |
| Main Menu | ✅ Verified | MainMenuGui with MainMenuController (8209 chars). PlayButton.Activated hides menu. GameStateChanged listener auto-hides on non-Lobby state. ResetOnSpawn=false. Touch-compatible (Activated not MouseButton1Click). |
| Settings Menu | ✅ Verified Implemented | ⚙️ panel with Music + SFX toggles — already live in HUDController |
| Credits | ❌ Post-Alpha | Not found — post-Alpha. |
| Intro / Cutscene | ❌ Post-Alpha | Not found — post-Alpha. |
| Gamepass / Dev Products | ✅ Verified Implemented | GamepassManager.server.lua: SpeedPass + VIPPass + BoostToken stubs. MarketplaceService wired. IDs = 0 (replace before launch). |
| Shop UI Polish | 🔶 Post-Alpha | Two tabs, buy/equip, desc tooltips all working. Cosmetic avatar preview — post-Alpha. |
| Animation Polish | ✅ Verified Implemented | BUG-4 resolved — ManualWeld conflict fixed. Box carry no longer detaches arms. |

---

## 📊 SECTION 2 — SYSTEM STATUS BOARD

| System | Status | Priority | Alpha? |
|---|---|---|---|
| Order/Batch Pipeline | Complete | — | ✅ Done |
| NPC Lifecycle | Complete | — | ✅ Done |
| NPC Facing Direction | Complete | — | ✅ Done |
| Station Movement Locking | Complete | — | ✅ Done |
| Box Carry (physical) | Complete | — | ✅ Done |
| Delivery Race Lock | Complete | — | ✅ Done |
| Shift Lifecycle | Complete | — | ✅ Done |
| Money/Payout | Complete | — | ✅ Done |
| XP/Level Tracking | Complete | — | ✅ Done |
| Level Unlock Content | Complete | — | ✅ Done |
| Quality Scoring | Complete | — | ✅ Done |
| Combo System | Complete | — | ✅ Done |
| Customer Patience | Complete | — | ✅ Done |
| DataStore/Saving | Complete | — | ✅ Done |
| Station Mastery | Complete | — | ✅ Done |
| Daily/Weekly/Lifetime Challenges | Complete | — | ✅ Done |
| "What Next?" Guidance | Complete | — | ✅ Done |
| Carry Indicator UI | Complete | — | ✅ Done |
| In-World NPC Patience | Complete | — | ✅ Done |
| Order Ready Alert | Complete | — | ✅ Done |
| Rush Hour Announcement | Complete | — | ✅ Done |
| Dress Station Quality Fix | Complete | — | ✅ Done |
| Tutorial Fridge→Oven Step | Complete | — | ✅ Done |
| Tutorial Kitchen (isolated area) | Complete | — | ✅ Done 2026-03-30 |
| Warmer Sync for New Joiners | Complete | — | ✅ Done |
| Dress Order Lock Timeout | Complete | — | ✅ Done |
| Remote Rate Limiting | Complete | — | ✅ Done |
| VIP NPC Visual | Complete | — | ✅ Done |
| S-Rank Grade Tier | Complete | — | ✅ Done |
| Settings UI | Complete | — | ✅ Done |
| Mobile Scaling Pass | Complete | — | ✅ Done |
| Results Screen Polish | Complete | — | ✅ Done |
| Shop Tooltips | Complete | — | ✅ Done |
| Gamepass Integration | Complete | — | ✅ Done |
| NPC Collision (ceiling lift) | Complete | — | ✅ Done |
| Cookie Type Order Card Colors | Complete | — | ✅ Done |
| Customer Satisfaction Emoji | Complete | — | ✅ Done |
| Order Expired Visual | Complete | — | ✅ Done |
| Per-Station Results Breakdown | Complete | — | ✅ Done |
| Shop Cosmetic Preview | Complete | — | ✅ Done |
| Bakery Rating (persistent) | Not Started | LOW | After Alpha |
| Daily Login Rewards | Not Started | LOW | After Alpha |
| Event System | Not Started | LOW | After Alpha |
| Controller Support | Not Started | LOW | After Alpha |
| Screen Effects | Not Started | LOW | After Alpha |
| Rebirth / Prestige | Not Started | LOW | After Alpha |
| Social Actions | Not Started | LOW | After Alpha |
| Rejoin Protection | Not Started | LOW | After Alpha |
| Custom Leaderboard UI | Not Started | LOW | After Alpha |

---

## 🎯 SECTION 3 — PRIORITY BOARD

> All CRITICAL and HIGH items are complete. MEDIUM items are complete. This section is now a historical record + post-Alpha backlog.

### ✅ CRITICAL — All Done
| # | System | Status |
|---|---|---|
| C-1 | Station Movement Locking | ✅ Done 2026-03-24 |
| C-2 | "What Next?" Guidance System | ✅ Done 2026-03-25 |

### ✅ HIGH — All Done
| # | System | Status |
|---|---|---|
| H-1 | NPC Facing Direction Fix | ✅ Done 2026-03-25 |
| H-2 | Dress Station Quality Scoring | ✅ Done 2026-03-25 |
| H-3 | Delivery Race Lock | ✅ Done 2026-03-25 (was already present) |
| H-4 | Dress Order Lock Timeout | ✅ Done 2026-03-25 |
| H-5 | Level Unlock Content | ✅ Done 2026-03-25 |
| H-6 | Tutorial Fridge→Oven Step | ✅ Done 2026-03-25 (was already present) |
| H-7 | Remote Rate Limiting | ✅ Done 2026-03-25 |
| H-8 | Carry Indicator UI | ✅ Done 2026-03-25 |

### ✅ MEDIUM — All Done
| # | System | Status |
|---|---|---|
| M-1 | In-World NPC Patience Indicator | ✅ Done 2026-03-25 |
| M-2 | Order Ready Alert | ✅ Done 2026-03-25 |
| M-3 | Rush Hour Visual Announcement | ✅ Done 2026-03-25 |
| M-4 | Warmer Stock Sync for Joining Players | ✅ Done 2026-03-25 |
| M-5 | VIP NPC Visual Distinction | ✅ Done 2026-03-25 |
| M-6 | S-Rank Shift Grade | ✅ Done 2026-03-25 (was already present) |
| M-7 | Results Screen Animation | ✅ Done 2026-03-25 |
| M-8 | Settings UI | ✅ Done 2026-03-25 (was already present) |
| M-9 | Mobile Scaling Pass | ✅ Done 2026-03-25 |
| M-10 | Combo Break Popup | ✅ Done 2026-03-25 |
| M-11 | Loading Indicator (data load) | ✅ Done 2026-03-25 |
| M-12 | Gamepass Integration Scaffold | ✅ Done 2026-03-25 |

### 🟢 POST-ALPHA BACKLOG
| # | System | Notes |
|---|---|---|
| L-1 | Daily Login Rewards | Retention; balance after live data |
| L-2 | Event System | Seasonal content; post-launch |
| L-3 | Controller Support | ProximityPrompts work by default; minigame gamepad post-Alpha |
| L-4 | Screen Effects (ColorCorrection, shake) | Profile performance first |
| L-5 | Rebirth / Prestige | Late-game loop |
| L-6 | Social Actions (wave, high-five) | Needs player base first |
| L-7 | Rejoin Session Protection | 60s watchdog covers most cases |
| L-8 | Custom Leaderboard UI | Native leaderstats sufficient for Alpha |
| L-9 | Credits Screen | Post-launch |
| L-10 | Intro Cutscene | Narrative not yet defined |
| L-11 | Shop Cosmetic Preview | Avatar preview for hats/aprons |
| L-12 | Persistent Bakery Rating | Reputation across shifts |
| L-13 | Level Up Celebration (client) | Confetti / sound on level-up |
| L-14 | Top Bar Bakery XP | Show bakery XP separately from player XP |
| L-15 | Waypoint Arrows in Tutorial | Guide new players to stations visually |

---

## 🔨 SECTION 4 — CURRENT TASK

**TASK:** `Session 17 — Bug Fix Pass: BUG-67 through BUG-80 + FEAT-1/2/3`
**Status:** 🔴 FIX PASS NEEDED — 14 new bugs from 2026-04-01 solo playtest. P0 variety pack still fully broken (BUG-67). Multiple disk fixes from session 15 not taking effect in Studio (BUG-76/77/80). Friend playtest blocked until critical issues resolved.
**Fix Priority Order:**
1. BUG-67 — variety pack packSize mismatch (P0, blocks a whole order type)
2. BUG-68/69/70/71/80 — tutorial bugs (HUD visible, cookie prompt, oven cam, coin reward, menu board)
3. BUG-73/74/75/79 — carry/UI persistence (pill persists on fail, warmer prompt persists, combo not clearing, timer frozen)
4. BUG-72 — coin counter not updating after purchases
5. BUG-76/77 — re-investigate BUG-58/61 fixes not taking effect in Studio
6. BUG-78 — lifetime milestones not tracking
7. FEAT-1/2/3 — trash dough, shift counter, leaderboard label rename

**Session 16 — Solo Playtest (2026-04-01) findings:** See Section 7 BUG-67 through BUG-80. What's working: delivery to NPC, box → customer transfer, rating system, bakery level-up popup, challenges rewarding, variety orders (non-pack), combo UI, NPC patience timers, end-of-shift summary, 3-shift loop, drive-thru prompt, movement locked during break, cosmetics purchase/equip. What's broken: variety pack delivery (P0), tutorial HUD/UI bleed-through, coin counter stale, carry pill persists, warmer prompt persists, fridge showing all 6 types.

**Resolved this session (Session 10):**
- ✅ BUG-25 — SpeedPass wired into GameStateManager PreOpen skip; VIPPass wired into PersistentNPCSpawner + DriveThruServer delivery payout (1.5× multiply)
- ✅ BUG-32 — Resolved by BUG-36 fix: AIBakerSystem disabled, updateSoloMode() never fires, no silent dismissal possible
- ✅ BUG-36 — AIBakerSystem disabled (do return end + Studio Disabled=true). StaffManager is canonical AI worker system.
- ✅ GamepassManager converted from Script → ModuleScript (was crashing all three callers with "invalid require argument")
- ✅ Zero-error boot confirmed in Studio after all fixes

**Resolved this session (Session 9):**
- ✅ BUG-22/23/24/26/27/28/29/30/31/33/34/35/37 — see Section 6 for details

**What was correctly completed (Sessions 1–10):**
- All C/H/M priority items complete. All 38 bugs resolved. Performance baseline verified. ✅

---

## 📋 SECTION 5 — NEXT TASK QUEUE

> 🔴 Alpha is NOT cleared. Work top-to-bottom. Do not skip. Mark each resolved in Section 7 before advancing.
> ⚠️ Session 11 playtest added BUG-39 through BUG-46. These must all be fixed before RISK-5 load test.

### ✅ SESSION 12 — Tutorial Flow Fixes (ALL RESOLVED 2026-03-29)

| Order | Bug ID | System | Resolution |
|---|---|---|---|
| ~~1~~ | ~~BUG-45~~ | ~~GameStateManager~~ | ✅ Resolved 2026-03-29 — runPhase checks OnMainMenu/InTutorial attrs each second |
| ~~2~~ | ~~BUG-39~~ | ~~MainMenuController~~ | ✅ Resolved 2026-03-27 — hideMenu only fires on Open/EndOfDay/Intermission |
| ~~3~~ | ~~BUG-40~~ | ~~TutorialController~~ | ✅ Resolved 2026-03-29 — teleportPlayer("TutorialSpawn") on new-player join |
| ~~4~~ | ~~BUG-41~~ | ~~TutorialController~~ | ✅ Resolved 2026-03-29 — STEP_SPAWNS table; step 2→Dough, 3→Fridge, 4→Dress |
| ~~5~~ | ~~BUG-44~~ | ~~TutorialController~~ | ✅ Resolved 2026-03-29 — step 3 uses TutorialFridgeSpawn; fallback to nearest fridge |
| ~~6~~ | ~~BUG-46~~ | ~~TutorialController + PersistentNPCSpawner~~ | ✅ Resolved 2026-03-29 — SpawnTutorialNPC BindableEvent; spawner creates tutorial NPC in ordered state |
| ~~7~~ | ~~BUG-42~~ | ~~StaffManager~~ | ✅ Resolved 2026-03-29 — InTutorial guard added to hire Triggered callback |
| ~~8~~ | ~~BUG-43~~ | ~~All Minigame UIs~~ | ✅ Resolved 2026-03-29 — "X" GothamBold; AnchorPoint(1,0), Position(1,20,0,-20) on all 4 |

### ✅ SESSION 13 — Tutorial Kitchen Rebuild (COMPLETE 2026-03-30)

| Order | Task | Resolution |
|---|---|---|
| 1 | Build isolated TutorialKitchen module | ✅ TutorialKitchen.lua — standalone, no MinigameServer/OrderManager dependency |
| 2 | Fix wirePrompt for nested model stations | ✅ Scans descendants for existing ProximityPrompt first |
| 3 | Fix AntiExploit false positives | ✅ InTutorial guard added to MinigameServer result handlers |
| 4 | Hide HUD during tutorial | ✅ hud.Enabled tied to InTutorial attribute in HUDController |
| 5 | Fix menu race condition | ✅ InTutorial=true set immediately on PlayerAdded |
| 6 | Fix FridgeDisplay showing "Empty" | ✅ Disabled at TutorialKitchen startup |
| 7 | Fix PreOpen never starting after tutorial | ✅ OnMainMenu=false cleared in completeTutorial |
| 8 | Add TutorialCamera cinematic transitions | ✅ TutKit TARGET_PARTS + spawn markers in TutorialKitchen folder |
| 9 | Fix apron teleport bug | ✅ CosmeticService unanchors all BaseParts before welding |

### ✅ SESSION 14 — Pre-Alpha Cleanup + Regression Matrix (COMPLETE 2026-03-31)

| Order | Task | System | Notes |
|---|---|---|---|
| ~~1~~ | ~~Delete TEMP_ResetTutorial from SSS~~ | ~~Studio~~ | ✅ Deleted 2026-03-31 via MCP |
| ~~2~~ | ~~Delete TEMP_UnlockAllCosmetics from SSS~~ | ~~Studio~~ | ✅ Deleted 2026-03-31 via MCP |
| ~~3~~ | ~~Review Codex diff (4 files)~~ | ~~All~~ | ✅ All changes already on disk or weaker than existing — nothing applied |
| ~~4~~ | ~~Studio sync (OrderManager packSize gap)~~ | ~~OrderManager~~ | ✅ Synced |
| ~~5~~ | ~~Run regression matrix tests 1–6~~ | ~~All~~ | ✅ 5 passed immediately; Test 6 failed → GAP-2 fixed |
| ~~6~~ | ~~Fix GAP-2 (EndOfDay mid-minigame stuck)~~ | ~~MinigameServer~~ | ✅ GetAttributeChangedSignal("GameState") listener added |
| ~~7~~ | ~~Save retry / backoff~~ | ~~PlayerDataManager~~ | ✅ 3-attempt retry with 2s backoff in saveProfile |

### ✅ SESSION 15 — Solo Playtest + Bug Fix Pass (COMPLETE 2026-03-31 / 2026-04-01)

| Order | Task | System | Notes |
|---|---|---|---|
| ~~1~~ | ~~Run solo playtest as new player~~ | ~~All systems~~ | ✅ Completed 2026-03-31 — logged BUG-53 through BUG-66 |
| ~~2~~ | ~~Fix BUG-57 (challenges not showing first shift)~~ | ~~DailyChallengeServer/WeeklyChallengeServer/Clients~~ | ✅ Resolved 2026-04-01 |
| ~~3~~ | ~~Fix BUG-62 (NPC stuck after delivery rejected)~~ | ~~PersistentNPCSpawner~~ | ✅ Resolved 2026-04-01 |
| ~~4~~ | ~~Fix BUG-63 (stale warmer/fridge during intermission)~~ | ~~GameStateManager~~ | ✅ Resolved 2026-04-01 |
| ~~5~~ | ~~Fix BUG-64 (summary screen no auto-dismiss)~~ | ~~SummaryController~~ | ✅ Resolved 2026-04-01 |
| ~~6~~ | ~~Fix BUG-65 (bakery naming dialog not shown post-tutorial)~~ | ~~BakeryClient~~ | ✅ Resolved 2026-04-01 |
| 7 | Fix BUG-58 (fridge shows all 6 types) | StationRemapService | ⚠️ Disk patch applied — not taking effect in-game. Re-logged as BUG-76 |
| 8 | Fix BUG-60 (menu board not shown after tutorial) | MenuServer | ⚠️ Disk patch applied — not taking effect in-game. Re-logged as BUG-80 |
| 9 | Fix BUG-61 (drive-thru box stays on player) | DriveThruServer | ⚠️ Disk patch applied — not taking effect in-game. Re-logged as BUG-77 |
| 10 | Fix BUG-53/54/55/56/59/66 | Various | Still open — not yet addressed |

### ✅ SESSION 16 — Second Solo Playtest (COMPLETE 2026-04-01)

| Order | Task | System | Notes |
|---|---|---|---|
| ~~1~~ | ~~Run 3-shift solo playtest (new player run)~~ | ~~All systems~~ | ✅ Completed — 14 new bugs BUG-67 through BUG-80 + FEAT-1/2/3 logged |
| ~~2~~ | ~~Document all findings in MEMORY.md and MASTER_PROJECT_FILE~~ | ~~MASTER_PROJECT_FILE~~ | ✅ Completed 2026-04-01 |

### 🔴 SESSION 17 — Fix Pass: BUG-67 through BUG-80

| Order | Bug ID | System | Priority |
|---|---|---|---|
| 1 | BUG-67 | OrderManager / DressStationServer | P0 — variety pack never delivers |
| 2 | BUG-68 | HUDController / TutorialUI | P1 — HUD visible during tutorial |
| 3 | BUG-69 | HUDController / WarmersSystem | P1 — "cookie ready" alert in tutorial |
| 4 | BUG-70 | TutorialController / TutorialCamera | P1 — oven cam still at fridge |
| 5 | BUG-71 | TutorialController / PlayerDataManager | P1 — tutorial 200-coin reward not awarded |
| 6 | BUG-80 | MenuServer | P1 — menu board not appearing post-tutorial |
| 7 | BUG-73 | HUDController / BoxCarryServer | P1 — carry pill persists on fail + during break |
| 8 | BUG-74 | WarmersSystem | P1 — warmer pickup prompt after EndOfDay |
| 9 | BUG-75 | HUDController / PersistentNPCSpawner | P1 — combo not clearing on patience expiry |
| 10 | BUG-79 | SummaryController | P1 — end of day timer display frozen at :30 |
| 11 | BUG-72 | HUDController / PlayerDataManager | P1 — coin counter stale after purchases |
| 12 | BUG-76 | StationRemapService / FridgeDisplayServer | P1 — fridge shows 6 types (re-investigate BUG-58) |
| 13 | BUG-77 | DriveThruServer / BoxCarryServer | P1 — drive-thru box stays on player (re-investigate BUG-61) |
| 14 | BUG-78 | LifetimeChallengeManager | P1 — lifetime milestones at 0 despite orders |
| 15 | FEAT-1 | DoughTable2 / OrderManager | Trash/discard option at Dough Table 2 |
| 16 | FEAT-2 | GameStateManager / HUDController | Shift counter above PreOpen/Open timer |
| 17 | FEAT-3 | SummaryController / LeaderboardManager | "This Shift" → "This Session" label |

### ✅ Previously Resolved — CRITICAL BLOCKERS

| Order | Bug ID | System | Task | Files to Touch |
|---|---|---|---|---|
| ~~1~~ | ~~BUG-34~~ | ~~PlayerDataManager~~ | ✅ Resolved 2026-03-26 — lockExpiry timestamp added; stale locks (>120s) ignored | — |
| ~~2~~ | ~~BUG-35~~ | ~~MinigameServer~~ | ✅ Resolved 2026-03-26 — unlockedRecipes ownership check in RequestMixStart | — |
| ~~3~~ | ~~BUG-22~~ | ~~MinigameServer~~ | ✅ Resolved 2026-03-26 — ClearOvenBatch in cleanupPlayerSession + watchdog | — |
| ~~4~~ | ~~BUG-23~~ | ~~PlayerDataManager~~ | ✅ Resolved 2026-03-26 — ResetAllCombos() called each shift in runCycle | — |
| ~~5~~ | ~~BUG-24~~ | ~~RemoteManager~~ | ✅ Resolved 2026-03-26 — ShowAlert added to REMOTES table | — |
| ~~1~~ | ~~BUG-25~~ | ~~GamepassManager~~ | ✅ Resolved 2026-03-26 | — |
| ~~7~~ | ~~BUG-26~~ | ~~MinigameServer / UnlockManager~~ | ✅ Resolved 2026-03-26 | — |
| ~~8~~ | ~~BUG-27~~ | ~~MinigameServer~~ | ✅ Resolved 2026-03-26 | — |
| ~~2~~ | ~~BUG-36~~ | ~~AIBakerSystem / StaffManager~~ | ✅ Resolved 2026-03-26 | — |
| ~~10~~ | ~~BUG-28~~ | ~~DriveThruServer / GameStateManager~~ | ✅ Resolved 2026-03-26 | — |
| ~~11~~ | ~~BUG-29~~ | ~~DriveThruServer~~ | ✅ Resolved 2026-03-26 | — |
| ~~12~~ | ~~BUG-30~~ | ~~GameStateManager~~ | ✅ Resolved 2026-03-26 | — |
| ~~13~~ | ~~BUG-31~~ | ~~MinigameServer / GameStateManager~~ | ✅ Resolved 2026-03-26 | — |
| ~~3~~ | ~~BUG-32~~ | ~~AIBakerSystem~~ | ✅ Resolved 2026-03-26 | — |
| ~~15~~ | ~~BUG-33~~ | ~~PlayerDataManager~~ | ✅ Resolved 2026-03-26 | — |
| ~~16~~ | ~~BUG-37~~ | ~~TutorialController~~ | ✅ Resolved 2026-03-26 | — |

### ✅ Post-Alpha Queue (do NOT touch until all above are resolved)

| Order | Task ID | System | Notes |
|---|---|---|---|
| — | Post-Alpha | Shop Cosmetic Preview (L-11) | Show hat/apron on avatar before buying |
| — | Post-Alpha | Persistent Bakery Rating (L-12) | Reputation tracked across shifts |
| — | Post-Alpha | Level Up Celebration (L-13) | Confetti + sound burst on level-up |
| — | Post-Alpha | Top Bar Bakery XP (L-14) | Show bakery XP separately from player XP |
| — | Post-Alpha | Waypoint Arrows in Tutorial (L-15) | Guide new players to stations visually |
| — | Post-Alpha | Daily Login Rewards (L-1) | Retention mechanic; balance after live data |
| — | Post-Alpha | Event System (L-2) | Seasonal content; stub exists |
| — | Post-Alpha | Controller Support (L-3) | Gamepad input for minigames |

---


## ✅ SECTION 6 — COMPLETED TASKS LOG

| Date | Task | Notes |
|---|---|---|
| 2026-04-01 | **Session 16 — Second solo playtest (3 full shifts)** | New-player run (DataStore wiped). Tutorial → PreOpen → Open → EndOfDay → Intermission → Shift 2 → Shift 3. Working: delivery to NPC, box → customer, rating system, bakery level-up popup, daily/weekly challenges, variety orders (non-pack), combo UI, NPC patience timers, end-of-shift summary, cosmetics. Broken: variety pack (BUG-67 P0), tutorial HUD bleed (BUG-68/69), coin counter stale (BUG-72), carry UI persistence (BUG-73/74), fridge still 6 types (BUG-76), drive-thru box visual (BUG-77), lifetime milestones 0 (BUG-78), timer frozen (BUG-79), menu board after tutorial (BUG-80). 14 new bugs + 3 feature requests logged. |
| 2026-04-01 | **Session 15 bug fix pass — BUG-57/62/63/64/65 resolved** | BUG-57: DailyChallengeServer + WeeklyChallengeServer now send data on Open state change; clients check current GameState on init. BUG-62: PersistentNPCSpawner calls npcLeave after delivery rejection. BUG-63: OrderManager.Reset() called before Intermission teleport in GameStateManager. BUG-64: SummaryController auto-dismiss self-cancel bug fixed (nil thread ref before dismiss). BUG-65: BakeryClient defers bakery naming dialog until InTutorial clears. Three other disk patches applied (BUG-58/60/61) but not taking effect in-game — re-logged BUG-76/77/80 for re-investigation. |
| 2026-03-31 | **Session 15 — Solo playtest completed** | Full new-player run: tutorial, PreOpen, Open (5 min), EndOfDay, break, second shift start. 14 bugs logged (BUG-53–66) + 3 feature requests. P0: variety pack delivery broken. P1: coins display, AI at dress, carry UI stale, challenges first shift, fridge/warmer filtering. All items logged in §7. |
| 2026-03-31 | **Session 14 — Full pre-alpha sweep complete** | TEMP scripts deleted. Codex diff reviewed (all already on disk — nothing applied). OrderManager packSize synced to Studio. Regression matrix 6/6 pass after GAP-2 fix. GAP-2 (EndOfDay mid-minigame stuck) fixed: MinigameServer now listens for GameState attribute change and calls cleanupPlayerSession on EndOfDay/Intermission. Save retry added to PlayerDataManager: 3 attempts, 2s backoff. Readiness updated to 92%. |
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
| 2026-03-25 | **H-3 Delivery Race Lock** | Already implemented — deliveryLocked flag in PersistentNPCSpawner, atomic check+set, 7 sites. Verified in Studio. BUG-5 closed. |
| 2026-03-25 | **H-4 Dress Order Lock Timeout** | PlayerRemoving + CharacterRemoving cleanup already present. Added LOCK_TIMEOUT=90 constant + task.delay(90) auto-release on both variety and single-order lock paths in DressStationServer. |
| 2026-03-25 | **H-5 Level Unlock Content** | UnlockManager: bakeryLevelReq=3 on tip_boost_1, enforced in Purchase() before DeductCoins. PlayerDataManager.AwardBakeryXP: auto-grants cookies_and_cream at level 5, lemon_blackraspberry at level 10 via AddOwnedCookie. |
| 2026-03-25 | **H-6 Tutorial Fridge→Oven Step** | Already implemented — step 3 msg covers fridge pull + oven, gates on oven StationCompleted. Verified in code. |
| 2026-03-25 | **H-7 Remote Rate Limiting** | lastPurchaseTime table + 1s throttle in UnlockManager.PurchaseItem handler. lastMixRequestTime table + 0.5s throttle in MinigameServer.RequestMixStart handler. Silent drop (no error sent). |
| 2026-03-25 | **H-8 Carry Indicator UI** | CarryPill (orange, bottom-center) in HUDController. boxCarriedRemote fires from PersistentNPCSpawner on BoxCreated (with NPC name) and after delivery (nil to clear). All 6 checks verified in Studio. |
| 2026-03-25 | **M-1 In-World NPC Patience Indicator** | BarFill injected into existing PatienceGui on NPC spawn (NPCSpawner.CreateNPC). PatienceGui resized 120×52, TimerLabel shrunk to 65%, BarBg+BarFill strip added. SetPatienceBar(model, ratio) fn added. Called every patience tick in PersistentNPCSpawner alongside SetTimerText. Color: green>60%, yellow 30–60%, red<30%. |
| 2026-03-25 | **M-2 Order Ready Alert** | Replaced reserved warmersStockEvent stub in HUDController. _prevWarmerCount tracks warmer total. Count increase → showAlert "Cookie ready to box!" (2.5s, gold) + orderAlertSound chime. Zero-server-change — reuses existing WarmersUpdated broadcast and orderAlertSound. |
| 2026-03-25 | **M-3 Rush Hour Announcement** | Server already fired RushHour remote with {active=true}. Added client listener in HUDController: showAlert "RUSH HOUR!" (4s, red/gold) using existing showAlert helper. No server changes needed. |
| 2026-03-25 | **M-4 Warmer Sync for Joiners** | task.defer in PlayerAdded (MinigameServer): checks GameState=="Open"/"EndOfDay", fires BatchUpdated + FridgeUpdated + WarmersUpdated snapshot directly to joining player. BUG-7 resolved. |
| 2026-03-25 | **M-5 VIP NPC Visual** | Enhanced VIPGui in NPCSpawner: size 60×24→110×32, AlwaysOnTop=false→true, StudsOffset raised to 5.2 (above patience bar), text "⭐ VIP"→"* VIP *", UICorner+UIStroke gold glow added. |
| 2026-03-25 | **M-6 S-Rank Shift Grade** | Already implemented in both disk and Studio (score≥90=S, ≥75=A, ≥60=B, ≥45=C, else D). Verified in SessionStats.GetShiftGrade. No changes needed. |
| 2026-03-25 | **M-7 Results Screen Animation** | SummaryController: frame slides up from Y=1.15→centred (Back ease 0.45s). Stat counters tick from 0→final in 28 steps (staggered 0.12s apart, delayed 0.3s). gradeValL fades in with Back ease after 0.5s. |
| 2026-03-25 | **M-8 Settings UI** | Already implemented — ⚙️ panel with Music ON/OFF + SFX ON/OFF toggles, directly sets Sound.Volume. Verified in Studio. No changes needed. |
| 2026-03-25 | **M-9 Mobile Scaling Pass** | Audited all fixed-px widths >360: CoachBar→0.88 scale, CoachTip (C-2 bar)→0.88 scale + renamed "CoachTip", CarryPill→0.82 scale, tween targets updated. All station ProximityPrompts dist=12 (adequate). |
| 2026-03-25 | **M-10 Combo Break Popup** | Added _prevComboStreak tracking. When streak resets from ≥2 to 0: showAlert "STREAK BROKEN!" (2s, red). Combo pill emoji removed from text (was showing raw emoji bytes on some clients). |
| 2026-03-25 | **M-11 Loading Indicator** | coinsLbl.Text="..." and levelLbl.Text="..." set before dataInitEvent fires. Replaced by real values on PlayerDataInit. Two-line change, zero new UI required. |
| 2026-03-25 | **M-12 Gamepass Scaffold** | New GamepassManager.server.lua: SpeedPass + VIPPass + BoostToken stubs. MarketplaceService.UserOwnsGamePassAsync on PlayerAdded. ProcessReceipt for BoostToken. HasSpeedPass/HasVIPPass/HasBoostActive API for other systems. IDs=0 (replace before launch). |
| 2026-03-25 | **BUG-17 Drive-Thru Box Consumption Exploit** | Root cause: DriveThruServer rewarded delivery through a custom path and never consumed the carried box via OrderManager. Fix: boxes now store `packSize`, `OrderManager.DeliverBox()` validates `packSize`, and drive-thru hand-in now requires the correct carried box and consumes it atomically. Patched on disk + Studio — needs in-game verification. |
| 2026-03-25 | **BUG-17 In-Game Verification (Session 7)** | All 10 delivery tests passed in live play mode: IsCarryingBox carrier check ✅, wrong carrier rejected ✅, wrong packSize rejected ✅, correct delivery rewarded once ✅, IsCarrying=false after delivery ✅, box reuse blocked ✅, status=pending rejected ✅. BUG-17 fully resolved. |
| 2026-03-25 | **BUG-18 orderAlertSound nil crash** | Root cause: `orderAlertSound:Play()` at line 822 referenced variable declared at line 1152; M-4 warmer sync fires on join before Sound init. Fix: `if orderAlertSound then orderAlertSound:Play() end`. Disk + Studio patched. |
| 2026-03-25 | **BUG-19 showAlert TweenService nil guards** | Root cause: all 5 chained `:Play()` calls in showAlert could crash if TweenService:Create returned nil. Fix: all 5 calls converted to local variable + nil guard pattern. Disk + Studio patched. |
| 2026-03-25 | **BUG-20 DEBUG_GiveCoins removed** | Studio-only Script in SSS root granted 10,000 coins to every joining player on PlayerAdded. Source: temporary test script never cleaned up. Destroyed from Studio. |
| 2026-03-25 | **BUG-21 EndOfDaySummary remote fixed** | Root cause: `"EndOfDaySummary"` accidentally on same line as `PlayerTipUpdate` comment in Studio's RemoteManager REMOTES table — remote never created. Fix: moved to its own line. Zero errors on restart. |
| 2026-03-25 | **Performance Smoke Test passed** | 172 Heartbeat fires/3s (target 150-220 ✅). 0 startup errors. No runaway loops. Memory patterns clean. |
| 2026-03-25 | **BUG-4 Box Carry Arms Detach** | Root cause: ManualWeld "Part Terrain Joint" baked into CookieBox template conflicted with WeldConstraint-to-HRP, causing physics solver to tear character Motor6D joints. Fix: `weldAllParts()` in BoxCarryServer now destroys all ManualWelds before welding. |
| 2026-03-25 | **Nice-to-Have: Cookie Type Order Card Colors** | COOKIE_COLORS lookup table added to HUDController. createCard/addOrder signatures extended with cookieId arg. Card border stroke, status dot, and "NEW" label all use cookieAccent(cookieId) — pink/brown/yellow/gray/cinnamon/lime per type. acceptedEvent passes orderData.cookieId (nil for variety orders). Zero server changes. |
| 2026-03-25 | **Nice-to-Have: Upgrade Tooltips** | Already implemented — ShopClient descLabel renders item.desc (72px row, y=32). No changes needed. |
| 2026-03-25 | **Nice-to-Have: Customer Satisfaction Emoji** | HUDController delivery feedback handler: after star-label float, spawns a 68px colored circle with ASCII face (:D / :) / :| / :( / >:() at NPC head position. Color-coded green→red by star rating. Floats up 3 studs and fades over 1.8s. Zero server changes. |
| 2026-03-25 | **Nice-to-Have: Order Expired Visual** | Server: npcOrderFailedRemote now sends NPC head Position as 3rd arg. Client: npcOrderFailedEvent handler spawns 80px red circle billboard with "X" at NPC position, floats up 3 studs, fades over 1.6s. HUD alert text cleaned up (removed raw emoji bytes). |
| 2026-03-25 | **Nice-to-Have: Per-Station Breakdown** | SessionStats.GetPlayerBreakdown(userId) added. GameStateManager switches from FireAllClients to per-player FireClient with stationBreakdown attached. SummaryController: new 48px station strip (Mix/Dough/Oven/Frost/Dress) between grade row and divider; color-coded green/yellow/orange/red by score; frame height 570→630px; all lower elements shifted 56px. |
| 2026-03-25 | **BUG-13 NPC Ceiling Lift** | Root cause: NPC HumanoidRootParts (CanCollide=true) collided with each other in narrow doorways, physics solver launched NPCs upward. Fix: PhysicsService "NPCs" collision group registered at startup (self-non-collidable); every spawned NPC HRP assigned to the group via SetPartCollisionGroup. |
| 2026-03-25 | **BUG-2 NPC facing wall in queue** | Root cause: advanceQueue MoveTo had empty callback — NPC arrived at new queue slot facing wrong direction. Fix: added facePosition(advModel, getCounterPos()) inside MoveTo callback. |
| 2026-03-25 | **BUG-11 doughLock orphan safety** | Added task.delay(SESSION_TIMEOUT+5) watchdog after doughLock is set. If no activeSessions entry claims the batchId after timeout, lock is force-cleared with a warning. Closes the race where player disconnects between doughLock set and startSession. |
| 2026-03-25 | **Cosmetic Preview in Shop** | SS/Cosmetics cloned to RS/Cosmetics (client-accessible). CosmeticService updated to use RS. ShopClient: PreviewPane (162px) added at bottom of Background; ViewportFrame + WorldModel + orbit Camera; click any cosmetic row → 3D preview with orbiting camera; Cosmetics tab resizes ItemList to 186px to make room; clearPreview() disconnects Heartbeat orbit on tab switch. |
| 2026-03-25 | **Performance + Memory Verification** | All while-true loops confirmed intentional (shift cycle, NPC spawn, patience ticker, leaderboard). Order cards have removeCard()+Destroy(). NPC models destroyed via NPCSpawner.Remove + 15s safety. Sounds created once at init. OrderManager.Reset() clears all 7 tables. Main Menu verified (Activated, GameStateChanged, ResetOnSpawn=false). |
| 2026-03-26 | **BUG-34 PlayerDataManager lock expiry** | lockExpiry = os.time()+120 written alongside _serverLock; stale/expired locks silently skipped and ownership taken over. Eliminates permanent silent data loss on server restart. |
| 2026-03-26 | **BUG-33 Starter coins** | DEFAULT_PROFILE coins = 500. New players can buy cheapest cosmetic (400) within first session. |
| 2026-03-26 | **BUG-23 + BUG-26 (UnlockManager) UserId rate-limit keys** | UnlockManager.lastPurchaseTime[player.UserId], PlayerRemoving cleanup added. No more dead player-object keys accumulating over server lifetime. |
| 2026-03-26 | **BUG-24 ShowAlert remote** | "ShowAlert" added to RemoteManager REMOTES table (disk + Studio GameEvents). ProcessReceipt no longer crashes on BoostToken. |
| 2026-03-26 | **BUG-35 Recipe ownership check** | RequestMixStart validates cookieId against profile.unlockedRecipes before TryStartBatch. Prevents day-1 access to C&C and lemon cookies. |
| 2026-03-26 | **BUG-22 Oven batch orphan on disconnect** | ClearOvenBatch(batchId) added to OrderManager. Called in cleanupPlayerSession (oven case) and in SESSION_TIMEOUT watchdog. Pipeline no longer starves from disconnects during oven minigame. |
| 2026-03-26 | **BUG-27 Batch cap feedback** | fireTip fires "All mix slots are full — wait for dough to move to the next stage!" when TryStartBatch returns nil. |
| 2026-03-26 | **BUG-37 Tutorial skip no reward** | completeTutorial(player, natural): skip path passes false, natural completion passes true. AddCoins gated on natural==true. |
| 2026-03-26 | **BUG-29 Drive-thru carrier disconnect** | Players.PlayerRemoving in DriveThruServer: if player == currentOrder.takenBy, set takenBy = nil so another player can deliver. |
| 2026-03-26 | **BUG-28 Drive-thru locked tip** | task.delay(3) in runCycle Open block fires tip "Complete this shift to unlock the Drive-Thru!" when !driveThruUnlocked. |
| 2026-03-26 | **BUG-30 Teleport indexed spread** | teleportAllTo uses angle=(i-1)/count*2π, radius=2.5. 6 players now spread in a circle instead of stacking. |
| 2026-03-26 | **BUG-31 Mid-shift joiner coach tip** | fireTipAll() stores LastCoachTip as workspace attribute. M-4 joiner block reads it and fires to joining player via tipRemote:FireClient. |
| 2026-03-26 | **BUG-23 Combo reset per shift** | PlayerDataManager.ResetAllCombos() zeroes comboStreak in all live profiles. Called in GameStateManager.runCycle() after SessionStats.Reset(). |
| 2026-03-26 | **BUG-26 MinigameServer UserId keys** | lastMixRequestTime[player.UserId] throughout; PlayerRemoving cleanup clears the entry. No dead references. |
| 2026-03-26 | **Studio sync verified — zero errors on boot** | All 3 previously broken files (GameStateManager, MinigameServer, TutorialController) pushed clean to Studio. Play mode boot shows 0 script errors. |
| 2026-03-26 | **BUG-36 Duplicate AI systems resolved** | AIBakerSystem disabled: `do return end` guard added to disk source + `Script.Disabled=true` set in Studio. StaffManager is canonical AI worker system. Documented in source comment. |
| 2026-03-26 | **BUG-32 AI worker dismiss no refund** | Resolved by BUG-36 fix — AIBakerSystem.updateSoloMode() never fires when script is disabled. No dismissal-without-refund possible. |
| 2026-03-26 | **BUG-25 GamepassManager stubs wired** | (1) GamepassManager converted from Script→ModuleScript in Studio so require() works. (2) SpeedPass: GSM runCycle checks HasSpeedPass() for all players; if any owns it, PreOpen is broadcast as 0s and skipped. (3) VIPPass: PersistentNPCSpawner delivery path multiplies payout.coins×1.5 if HasVIPPass(player). (4) VIPPass: DriveThruServer delivery path multiplies deliverCoins×1.5 if HasVIPPass(player). Paying players now receive correct benefits even with ID=0 placeholder. |
| 2026-03-26 | **Zero-error boot confirmed (Session 10)** | All 3 BUG-25/32/36 fixes applied. Play mode boot shows 0 script errors. All [Ready] prints present. |
| 2026-03-27 | **Session 11 — New-player playtest + AI baker fix** | Full playtest as new player (DataStore wiped). AI baker rig fixed: switched to CreateHumanoidModelFromDescription with explicit skin colors; AiNPCPlacement part used as authoritative floor Y reference. 8 new bugs identified (BUG-39 through BUG-46) and logged in master file. No code changes this session — all fixes queued for Session 12. |
| 2026-03-30 | **Session 13 — Tutorial Kitchen fully rebuilt as isolated workspace area** | Designed and implemented complete TutorialKitchen isolation. New players route to separate physical area in workspace; complete 5-step tutorial; teleport to GameSpawn on completion. TutorialKitchen.lua is standalone with no MinigameServer/OrderManager dependency. Fires same Start*/Result remotes so client minigame UIs work unchanged. wirePrompt() fixed to scan descendants for existing ProximityPrompts. DeliverPrompt added to TutorialCustomer.HumanoidRootPart (RequiresLineOfSight=false). FridgeDisplay hidden at startup. 6 spawn marker Parts placed in TutorialKitchen folder. TutorialCamera updated with TutKit TARGET_PARTS. InTutorial guard added to MinigameServer result handlers. HUD hidden via InTutorial attribute. OnMainMenu cleared in completeTutorial so PreOpen timer starts. Apron weld teleport bug fixed (unanchor all parts). Cosmetic offsets confirmed. |
| 2026-03-30 | **Session 13 — Known gaps documented** | 3 P1 gaps logged: (1) Mid-shift returning player join needs catch-up state fire. (2) Stuck minigame GUI when EndOfDay teleports player mid-session. (3) Ghost box when NPC patience expires while player is carrying. 2 P2 gaps: empty menu fallback, all-player disconnect recovery. All documented in Section 7 as BUG-47 through BUG-51. |
| 2026-03-29 | **Session 12 — All tutorial flow bugs resolved (BUG-39/40/41/42/43/44/45/46)** | **BUG-45** GSM runPhase pauses PreOpen timer while any player has OnMainMenu or InTutorial=true. **BUG-39** MainMenuController only hides on Open/EndOfDay/Intermission — not PreOpen. **BUG-40** TutorialController teleports new player to TutorialSpawn on join. **BUG-41/44** STEP_SPAWNS table: step 2→Dough, step 3→TutorialFridgeSpawn (nearest fridge fallback), step 4→Dress. **BUG-46** SpawnTutorialNPC BindableEvent: fired after oven complete; PersistentNPCSpawner spawns tutorial NPC ordered state chocolate_chip ×6. **BUG-42** StaffManager hire Triggered guards on InTutorial=true. **BUG-43** All 4 minigame exit buttons: "X" GothamBold, AnchorPoint(1,0), Position(1,20,0,-20) floating outside panel. All synced to Studio via auto-checkpoint. |
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
| BUG-2 | 🔴 Critical | NPC System | NPCs face wall during wait_in_queue despite facePosition() call | ✅ Resolved 2026-03-25 — Root cause: advanceQueue called MoveTo with empty callback `function() end`. NPC arrived at new queue slot but never re-faced counter. Fix: added `facePosition(advModel, getCounterPos())` inside the MoveTo callback in advanceQueue. |
| BUG-3 | 🟠 High | Quality Scoring | DRESS_SCORE = 85 hardcoded — dress quality always 85 regardless of performance | ✅ Resolved 2026-03-25 |
| BUG-4 | 🟠 High | Box Carry | Arms detach when carrying box (Motor6D.Enabled = false disconnects joint) | ✅ Resolved 2026-03-25 — ManualWeld ("Part Terrain Joint") in CookieBox template conflicted with WeldConstraint-to-HRP. Fixed: destroy all ManualWelds in weldAllParts() before creating character weld. |
| BUG-5 | 🟠 High | Delivery | Two players can fire DeliverBox to same NPC simultaneously (no delivery lock) | ✅ Resolved — deliveryLocked flag already present (atomic check+set, 7 sites) |
| BUG-6 | 🟠 High | Dress Station | dressLocked[player] has no timeout — disconnected player locks order slot forever | ✅ Resolved 2026-03-25 — PlayerRemoving+CharacterRemoving clear lock; 90s task.delay auto-release for AFK |
| BUG-7 | 🟠 High | Multiplayer | New joiner mid-shift doesn't receive current warmer stock snapshot | ✅ Resolved 2026-03-25 |
| BUG-8 | 🟡 Medium | Data | In-memory challenge counters reset on server crash (daily/weekly progress loss) | Known Limitation |
| BUG-9 | 🟡 Medium | Exploits | No rate limit on RequestMixStart — can spam server-side batch creation attempts | ✅ Resolved 2026-03-25 — H-7: 0.5s per-player throttle in MinigameServer.RequestMixStart handler (silent drop) |
| BUG-10 | 🟡 Medium | Exploits | No rate limit on PurchaseItem — UpdateAsync called per spam attempt | ✅ Resolved 2026-03-25 — H-7: 1s per-player throttle in UnlockManager.PurchaseItem handler (silent drop) |
| BUG-11 | 🟡 Medium | Dough | doughLock may not clear in rare race on disconnect during session start | ✅ Resolved 2026-03-25 — Added safety watchdog: task.delay(SESSION_TIMEOUT+5) after doughLock set; force-clears lock if no active session claims the batchId after timeout. |
| BUG-12 | 🟡 Medium | Box Carry | Box transfer BindableEvent fires but client NPCCarryPoseUpdate may desync | Known Low-Risk — Roblox BindableEvent/RemoteEvent timing gap. CarryPill clears correctly on delivery. Monitor during Alpha playtest. |
| BUG-13 | 🟡 Medium | NPC | NPCs colliding while walking can lift to ceiling and block entry queue | ✅ Resolved 2026-03-25 — HRP-HRP collisions caused ceiling lift. Fixed: PhysicsService "NPCs" collision group registered at startup (self-collision disabled); each spawned NPC HRP assigned to the group. |
| BUG-14 | 🔴 Critical | GameStateManager | "Could not start minigame" — Studio had stale GameStateManager requiring deleted RS/Modules/OrderManager → WaitForChild hang → runCycle never started | ✅ Resolved 2026-03-24 |
| BUG-15 | 🔴 Critical | GameStateManager | Phase name stuck at "Loading" — same root as BUG-14; GameStateChanged never fired "Open" because runCycle was frozen | ✅ Resolved 2026-03-24 |
| BUG-16 | 🔴 Critical | Challenge UI | Daily/Weekly UI panels hidden — DailyChallengeClient only shows when gameState=="Open"; state never reached Open due to BUG-14 | ✅ Resolved 2026-03-24 |
| BUG-17 | 🔴 Critical | Drive-Thru / Exploits | Drive-thru reward path bypassed `OrderManager.DeliverBox`, so rewards could be granted without atomically consuming/validating the carried box; pack-size validation was also missing from server-side box delivery. | ✅ Resolved 2026-03-25 — 10-step in-game test suite passed: wrong carrier, wrong packSize, box reuse, AI handoff all rejected; reward fires exactly once; box consumed atomically |
| BUG-18 | 🟠 High | HUDController | `orderAlertSound:Play()` used at line 822 before the sound was declared at line 1152 — nil crash on every join because M-4 warmer sync fires `WarmersUpdated` immediately on join, triggering the handler before Sound was initialized | ✅ Resolved 2026-03-25 — nil guard added: `if orderAlertSound then orderAlertSound:Play() end` |
| BUG-19 | 🟠 High | HUDController | All five `TweenService:Create(...):Play()` calls in `showAlert` were chained without nil guards — crash if TweenService returns nil (e.g. invalid instance) | ✅ Resolved 2026-03-25 — all five calls wrapped in local variable + nil guard pattern |
| BUG-20 | 🟠 High | Studio / Economy | `DEBUG_GiveCoins` Script in SSS root granted 10,000 coins to every joining player — Studio-only, never on disk | ✅ Resolved 2026-03-25 — script destroyed from Studio |
| BUG-21 | 🟡 Medium | RemoteManager | `EndOfDaySummary` remote accidentally placed on the same comment line as `PlayerTipUpdate` in the Studio REMOTES table — remote never created, causing `[RemoteManager] Unknown remote` error at runtime | ✅ Resolved 2026-03-25 — moved to its own line in Studio source |
| BUG-22 | 🔴 Critical | MinigameServer | `cleanupPlayerSession` handles dough/frost/dress cleanup on disconnect but has NO case for `station == "oven"`. Player disconnects during oven minigame → `ovenBatches[batchId]` permanently stuck in limbo until shift reset. In a 6-player session with any disconnects, orphaned batches accumulate and starve the pipeline. | ✅ Resolved 2026-03-26 — Added oven case to cleanupPlayerSession (ClearOvenBatch call) + watchdog timeout path; ClearOvenBatch() added to OrderManager |
| BUG-23 | 🔴 Critical | PlayerDataManager / Combo | `comboStreak` lives in the saved player profile and persists across sessions. `SessionStats.Reset()` clears shift stats but does NOT reset `comboStreak` in the profile. Player ending shift with a streak of 18 starts the next shift already at 18. Combo system is broken as a per-shift mechanic. | ✅ Resolved 2026-03-26 — ResetAllCombos() added to PlayerDataManager; called in runCycle at each shift boundary |
| BUG-24 | 🔴 Critical | RemoteManager / GamepassManager | `GamepassManager.server.lua` line 100 calls `rm.Get("ShowAlert")` inside `ProcessReceipt`. "ShowAlert" is NOT in the RemoteManager REMOTES table. This crashes with `[RemoteManager] Unknown remote: ShowAlert` — and Roblox automatically retries failed ProcessReceipt calls, meaning it would spam crash. Currently unreachable because BOOST_TOKEN_ID=0, but is broken production code in a critical handler. | ✅ Resolved 2026-03-26 — "ShowAlert" added to RemoteManager REMOTES table (disk + Studio) |
| BUG-25 | 🟠 High | GamepassManager | `HasSpeedPass()` and `HasVIPPass()` are defined but never called anywhere in the codebase. If real Gamepass IDs are ever filled in, buying Speed Pass or VIP Pass gives the player zero benefit. Silent fulfillment failure for paying players. | ✅ Resolved 2026-03-26 — GamepassManager converted to ModuleScript; SpeedPass wired in GSM PreOpen skip; VIPPass wired in NPCSpawner + DriveThruServer delivery (1.5× payout). Zero-error boot confirmed. |
| BUG-26 | 🟠 High | MinigameServer / UnlockManager | `lastMixRequestTime` and `lastPurchaseTime` rate-limit tables use **player objects as keys**. Player objects are never removed on `PlayerRemoving`. Over a long server session with many player joins/leaves, tables accumulate dead entries. Minor memory leak that compounds over hours. | ✅ Resolved 2026-03-26 — Both tables changed to UserId keys; PlayerRemoving cleanup added to MinigameServer and UnlockManager |
| BUG-27 | 🟠 High | MinigameServer | When `OrderManager.TryStartBatch()` returns nil (batch cap reached), the server silently returns with no client feedback. The player sees the mixer prompt do nothing, with no explanation. Will cause confusion and bug reports. | ✅ Resolved 2026-03-26 — fireTip fires "All mix slots are full — wait for dough to move to the next stage!" |
| BUG-28 | 🟡 Medium | DriveThruServer | Drive-thru is invisible for the entire first shift (driveThruUnlocked=false until shift 1 ends). This is intentional design but is **not communicated anywhere**. First-time Alpha testers will assume the drive-thru is broken or unfinished. | ✅ Resolved 2026-03-26 — task.delay(3) fires tip "Complete this shift to unlock the Drive-Thru!" at Open phase start when !driveThruUnlocked |
| BUG-29 | 🟡 Medium | DriveThruServer | If the player who took the drive-thru order disconnects, `currentOrder.takenBy` still holds their reference. The car sits idle for WINDOW_TIMEOUT (90s) then leaves. No other player can deliver it. 90 seconds of dead content visible to all other players. | ✅ Resolved 2026-03-26 — PlayerRemoving handler sets currentOrder.takenBy = nil when carrier disconnects |
| BUG-30 | 🟡 Medium | GameStateManager | `teleportAllTo()` uses `math.random(-2, 2)` offset for all players simultaneously. With 6 players, most clip into each other or geometry. Should spread by player index. | ✅ Resolved 2026-03-26 — Indexed radial spread: angle = (i-1)/count * 2π, radius = 2.5 when count>1 |
| BUG-31 | 🟡 Medium | MinigameServer / GameStateManager | M-4 snapshot fires BatchUpdated/FridgeUpdated/WarmersUpdated to new joiners but does NOT resend the current `PlayerTipUpdate` tip. Players joining mid-shift receive no coach guidance until the next station event fires. | ✅ Resolved 2026-03-26 — fireTipAll() stores LastCoachTip in workspace attribute; M-4 joiner block reads it and re-fires to joining player |
| BUG-32 | 🟡 Medium | AIBakerSystem | `updateSoloMode()` instantly destroys all hired AI workers the moment a second player joins, with no warning and no coin refund. Player who spent 50 coins per worker loses all investment silently. | ✅ Resolved 2026-03-26 — Resolved by BUG-36 fix. AIBakerSystem disabled; updateSoloMode() never runs; no dismissal possible. |
| BUG-33 | 🟡 Medium | PlayerDataManager / Economy | New players start with `coins = 0`. Cheapest cosmetic is 400 coins; cheapest upgrade is 2500. Average new player earns ~300-600 coins in a first 8-minute shift. Shop is completely inaccessible for the entire first session, making it feel pointless. | ✅ Resolved 2026-03-26 — DEFAULT_PROFILE coins = 500 |
| BUG-34 | 🔴 Critical | PlayerDataManager | `saveProfile` writes `_serverLock = SESSION_ID` in UpdateAsync but **never clears or expires the lock**. If the server shuts down abnormally, the next server starts with a different `SESSION_ID`. It reads the lock, sees a mismatch, calls `return nil` (skips save), and the profile is never saved again on that server. This is not just a crash edge case — any server restart produces a permanently stuck lock that causes silent data loss for every player on the new server until they rejoin yet again. Root: lock is write-only with no expiry. Fix: on `BindToClose` write `_serverLock = nil`; or add `lockExpiry = os.time() + 120` and ignore locks older than 120s. | ✅ Resolved 2026-03-26 — lockExpiry = os.time()+120 written alongside lock; stale locks (expired or no expiry) ignored, ownership taken over |
| BUG-35 | 🔴 Critical | MenuManager / MinigameServer | `MenuManager.DEFAULT_MENU` contains all 6 cookies including `cookies_and_cream` and `lemon_blackraspberry`. `DEFAULT_PROFILE.unlockedRecipes` only grants `{chocolate_chip, snickerdoodle, pink_sugar, birthday_cake}` — the 2 premium cookies are excluded. However `RequestMixStart.OnServerEvent` validates `cookieId` against `GetActiveMenu()` only, not against the player's `unlockedRecipes`. Any new player can immediately mix C&C and Lemon cookies that are supposed to be earned via bakery levels 5 and 10. Confirmed by reading MenuManager.lua: DEFAULT_MENU has 6, unlockedRecipes has 4. Fix: add `profile.unlockedRecipes` ownership check in RequestMixStart handler before TryStartBatch. | ✅ Resolved 2026-03-26 — Ownership check added in RequestMixStart before TryStartBatch; warns + fires tip on violation |
| BUG-36 | 🟠 High | AIBakerSystem / StaffManager | Both `StaffManager.server.lua` and `AIBakerSystem.server.lua` were active production scripts with overlapping AI worker responsibilities. Decision: StaffManager is canonical (better architecture, proper spawn positions, GameState wiring, dress worker support). AIBakerSystem disabled. | ✅ Resolved 2026-03-26 — AIBakerSystem: `do return end` guard added to disk; Studio Script.Disabled=true + BUG-36 comment prepended. StaffManager unchanged. Zero-error boot confirmed. |
| BUG-37 | 🟡 Medium | TutorialController | `completeTutorial()` is called on both the natural 5-step completion path AND the skip path (when player presses the skip button). The completion function grants a reward (coins/XP) and sets `tutorialCompleted = true`. Skipping should NOT grant the reward — it should only set the flag. A player who skips tutorial gets the same reward as one who completes it, making the reward meaningless and making skipping strictly dominant. Fix: pass a `natural` boolean to `completeTutorial()`; only grant reward when `natural == true`. | ✅ Resolved 2026-03-26 — completeTutorial(player, natural): skip fires false, startGame fires true; reward gated on natural==true |
| BUG-38 | 🟡 Medium | TutorialUI | Tutorial step panel re-appears during Open phase for players who already completed the tutorial. Root cause: (1) Studio DataStore doesn't persist between play sessions so `tutorialCompleted=false` on each play, causing the tutorial to re-run; (2) no client-side guard prevented `panel.Visible=true` if step 1–5 fired after a prior step=0. | ✅ Resolved 2026-03-26 — Added `isTutorialComplete` flag in TutorialUI; set to `true` on step=0; guards `panel.Visible = true` — panel can never re-show after any dismissal or completion. |
| BUG-39 | 🔴 Critical | MainMenuController | Main menu auto-hides immediately for new players because `stateRemote` fires `PreOpen` shortly after join, and the `stateRemote.OnClientEvent` guard `if state ~= "Lobby" then hideMenu()` treats PreOpen as "not Lobby" and dismisses the menu. A task.defer check also reads the current GameState attribute and hides if it's not "Lobby". New players never see the main menu. Fix: only hide on Open/EndOfDay/Intermission — never on PreOpen or Lobby. | ✅ Resolved 2026-03-27 — Menu only hides on Open/EndOfDay/Intermission or Play click. Play fires DismissMainMenu remote. task.defer auto-hide removed. |
| BUG-40 | 🔴 Critical | TutorialController | New players are NOT teleported to the tutorial start area on join. | ✅ Resolved 2026-03-29 — teleportPlayer("TutorialSpawn") called in handlePlayerJoin for new players. Player placed inside bakery near mixers. |
| BUG-41 | 🔴 Critical | TutorialController | No per-step teleports. Players shown messages but not moved between stations. | ✅ Resolved 2026-03-29 — STEP_SPAWNS table added: step 2→TutorialDoughTableSpawn, step 3→TutorialFridgeSpawn, step 4→TutorialDressTableSpawn. Steps 1 and 5 have no teleport. |
| BUG-42 | 🔴 Critical | StaffManager | AI hire prompts visible and functional during tutorial — new player can accidentally spend coins. | ✅ Resolved 2026-03-29 — `if player:GetAttribute("InTutorial") then return end` guard added to hire Triggered callback in StaffManager. |
| BUG-43 | 🟠 High | All Minigame UIs | Exit buttons used ✕ (U+2715) which renders as hollow box on some clients. Button also overlapped panel interior. | ✅ Resolved 2026-03-29 — Text changed to "X" (GothamBold) on all 4 minigames. AnchorPoint=(1,0), Position=(1,20,0,-20) floats button outside top-right panel corner. |
| BUG-44 | 🟠 High | TutorialController | Step 3 message directed player to oven but they need to go to fridge first. | ✅ Resolved 2026-03-29 — Step 3 teleports to TutorialFridgeSpawn (fallback: nearest fridge); message updated to instruct fridge pull first, then oven. |
| BUG-45 | 🔴 Critical | GameStateManager | PreOpen timer counted down while tutorial players were still playing — game advanced to Open mid-tutorial. | ✅ Resolved 2026-03-29 — runPhase checks each second for any player with OnMainMenu=true or InTutorial=true; skips decrement while any are present. |
| BUG-46 | 🔴 Critical | TutorialController / PersistentNPCSpawner | Tutorial dress step had no NPC with an order — DressStation KDS was empty, player couldn't complete tutorial. | ✅ Resolved 2026-03-29 — SpawnTutorialNPC BindableEvent added; TutorialController fires after step 3 complete; PersistentNPCSpawner spawns tutorial NPC in ordered state with chocolate_chip ×6, bypassing GameState guard. |
| RISK-1 | 🟠 High | DataStore | Server crash before session lock release = silent save skip = data loss | Known Limitation — post-Alpha. DataStore retry loop is a post-Alpha hardening task. BUG-34 is the active blocker form of this risk. |
| RISK-2 | 🟠 High | Progression | Level unlocks nothing — players have no reason to grind | ✅ Addressed 2026-03-25 — H-5: tip_boost_1 gated at bakery level 3; C&C auto-granted at level 5; lemon_blackraspberry auto-granted at level 10. Sufficient incentive for Alpha. |
| RISK-3 | 🟡 Medium | Onboarding | No waypoints = new players quit before first delivery | ✅ Addressed 2026-03-25 — C-2: Coach tip bar fires on every station completion and phase change (9 triggers). Waypoint arrows are post-Alpha (L-15). |
| RISK-4 | 🟡 Medium | Retention | No daily login reward = no daily pull-back mechanic | Post-Alpha — L-1. Daily challenges provide adequate short-term retention for Alpha. |
| BUG-47 | 🔴 Critical | TutorialKitchen | `wirePrompt()` used `FindFirstChildWhichIsA("BasePart")` (non-recursive) then checked for ProximityPrompt only on that part. For nested models (TutorialOven, TutorialDressStation, TutorialFridge), the first BasePart found was not the one with the existing prompt — a new prompt was created on a hidden part, so pressing the visible prompt did nothing. | ✅ Resolved 2026-03-30 — wirePrompt now scans all descendants for existing ProximityPrompt first; falls back to creating one on first BasePart only if none exists. |
| BUG-48 | 🟠 High | MinigameServer / AntiExploit | Tutorial players fire MixMinigameResult/DoughMinigameResult/OvenMinigameResult remotes (reusing same remotes as main game). MinigameServer result handlers received these with no active session → logged AntiExploit warnings for every tutorial player. | ✅ Resolved 2026-03-30 — `if player:GetAttribute("InTutorial") then return end` guard added to all MINIGAMES result OnServerEvent handlers. |
| BUG-49 | 🟠 High | HUDController / MenuClient | HUD visible during tutorial (InTutorial=true) — top bar, order cards, and daily menu board all showed to tutorial players. Root cause: neither HUDController nor MenuClient checked InTutorial before rendering. | ✅ Resolved 2026-03-30 — HUDController: `hud.Enabled = not InTutorial`, reactive to GetAttributeChangedSignal. MenuClient: InTutorial guard on OpenMenuBoard handler. |
| BUG-50 | 🔴 Critical | TutorialController / GameStateManager | After tutorial completion, `InTutorial` was cleared but `OnMainMenu` stayed `true` (set on PlayerAdded, never cleared since new players never fire DismissMainMenu). PreOpen timer's per-second check found OnMainMenu=true → timer paused indefinitely. New players who completed tutorial were stuck — PreOpen never started. | ✅ Resolved 2026-03-30 — `player:SetAttribute("OnMainMenu", false)` added in completeTutorial(), both natural completion and skip paths. |
| BUG-51 | 🟠 High | CosmeticService | Apron (and any cosmetic with Anchored=true parts) teleported the player when equipped. Root cause: WeldConstraint from Torso to cosmetic model fought against Anchored=true parts in the model; physics solver moved the character. | ✅ Resolved 2026-03-30 — CosmeticService now unanchors ALL BaseParts in cloned cosmetic model before parenting to character. |
| BUG-52 | 🟡 Medium | TutorialKitchen / FridgeDisplayServer | TutorialFridge has a FridgeDisplay BillboardGui (copied from main fridge model). FridgeDisplayServer only updates fridges in workspace.Fridges folder — TutorialFridge never updated, so it showed "Empty" by default. Players saw "Empty" and thought they needed to put real dough in before baking. | ✅ Resolved 2026-03-30 — TutorialKitchen hides the FridgeDisplay BillboardGui on TutorialFridge at server startup. |
| GAP-1 | 🟠 High | GameStateManager / OrderManager | Returning player joins during Open/Intermission/EndOfDay — sees blank state. `GameStateChanged` fires on join (M-4 pattern) but current orders, warmer stock, and game timer are not sent in a catch-up packet at that moment. Player has no idea what's happening. | Open — P1, fix before stable multiplayer |
| GAP-2 | 🟠 High | MinigameServer / GameStateManager | Player is mid-minigame (oven, mix, etc.) when EndOfDay fires and `teleportAllTo` moves them to the back room. Minigame GUI stays open. Session is stuck until 45s timeout. Player is in back room with a locked minigame overlay. | ✅ Resolved 2026-03-31 — workspace:GetAttributeChangedSignal("GameState") in MinigameServer; iterates activeSessions and calls cleanupPlayerSession on EndOfDay/Intermission |
| GAP-3 | 🟠 High | OrderManager / BoxCarryServer | Player picks up delivery box. NPC patience expires and NPC walks out. Box is still welded to player — they carry a "ghost" box for an orphaned order that no longer exists. No cleanup of carried box on NPC order expiry. | Open — P1, fix before stable multiplayer |
| GAP-4 | 🟡 Medium | MenuManager | PreOpen ends with no player having selected the cookie menu. Open phase starts with an empty active menu. NPCs either order nothing or crash trying to pick from an empty list. | Open — P2 |
| BUG-53 | 🔴 Critical | OrderManager / DressStationServer | `DeliverBox rejected: packSize mismatch box=1 order=6` — variety pack orders (packSize=6) always fail delivery. Box is created with packSize=1 because `warmerEntry.quantity` is nil or not populated for variety pack warmer entries. No variety pack can ever be delivered. Confirmed twice in playtest (02:18 and 02:21). | Open — superseded by BUG-67 (confirmed P0 in April 1 playtest with packSize=4) |
| BUG-54 | 🟠 High | HUDController / StaffManager | Coins display shows wrong value — player saw 247 coins but StaffManager logged `cannot afford worker (need 50 coins)`. In-memory profile coins and displayed coins are out of sync. Possible cause: HUD reads a stale snapshot instead of live profile value. | Open — P1 |
| BUG-55 | 🟠 High | StaffManager | AI worker spawns at Dress Station during Open phase — only Mix, Dough, Oven, and Frost workers are intended. Dress station requires a real player (order-matching logic needs human judgment). | Open — P1 |
| BUG-56 | 🟠 High | HUDController / BoxCarryServer | Carry UI ("Deliver to [NPC]" header + carry pill top-right) does not clear after a failed delivery (packSize mismatch rejection). Player is stuck showing stale carry state indefinitely. Also persists into break/intermission. | Open — P1 |
| BUG-57 | 🟠 High | DailyChallengeClient / WeeklyChallengeClient | Daily and weekly challenge panels pop up on second shift Open but NOT on first shift Open. New players never see them on their first play session. Root cause likely: UI listener fires on GameStateChanged but challenge data not yet loaded on first shift. | ✅ Resolved 2026-04-01 — Server now sends data on Open state change for all players; client initRemote checks current GameState and shows widget if already Open. Verified working in April 1 playtest. |
| BUG-58 | 🟠 High | FridgeDisplayServer / StationRemapService | Fridge UI shows all 6 fridge stock displays during Open regardless of active menu. Should only show the fridges for the cookies currently on the menu (e.g. 4 chosen = 4 visible). Disk patch applied to StationRemapService (display.Enabled on active/inactive fridges) but NOT taking effect in-game as of 2026-04-01 playtest. Re-logged as BUG-76. | ⚠️ Disk patch applied 2026-04-01 — not taking effect in-game. See BUG-76 for re-investigation. |
| BUG-59 | 🟠 High | WarmersSystem | Warmers show all slots spaced across the wall instead of clustering the active 4 near the Dress Station. Should display only the active menu cookie warmers and position them nearest to the Dress Station. NOTE: Attempted move to X=-22 Z=-84→-104 in session — WRONG. Warmers phased through kitchen/backroom wall. REVERTED to original: X=-26, Y=3, Z=-49/-55/-61/-67/-73/-79. Do NOT move warmers without Studio verification. Filtering/hiding of unused warmer slots is a separate issue tracked by BUG-74. | Open — physical clustering post-Alpha; slot hiding tracked in BUG-74 |
| BUG-60 | 🟡 Medium | TutorialController / MenuServer | After tutorial completion, player is teleported to GameSpawn but the cookie menu selection board never opens/prompts. New players enter PreOpen with no idea they should pick today's menu. Disk patch applied to MenuServer (InTutorial watcher → sendOpenMenuBoard) but NOT confirmed working in April 1 playtest. Re-logged as BUG-80. | ⚠️ Disk patch applied 2026-04-01 — not confirmed working. See BUG-80. |
| BUG-61 | 🟡 Medium | DriveThruServer / BoxCarryServer | After delivering a box to the drive-thru customer, the physical box remains welded to the player's character. It is never removed. Player carries it indefinitely until manual drop or shift reset. Disk patch applied to DriveThruServer (boxCarriedRemote:FireClient(player, nil) + destroy CarriedBox_) but NOT taking effect in-game per April 1 playtest. Re-logged as BUG-77. | ⚠️ Disk patch applied 2026-04-01 — not taking effect. See BUG-77. |
| BUG-62 | 🟡 Medium | PersistentNPCSpawner | When DeliverBox fails (e.g. packSize mismatch), the NPC stays at the counter permanently — NPC does not leave or requeue. Combined with BUG-53, this causes a growing pile-up of stuck NPCs at POS slot 1 blocking the entire queue. | ✅ Resolved 2026-04-01 — npcLeave(npcId, "delivery_rejected") added after forceDropBoxRemote:FireClient in DeliverBox fail path. NPC now walks out. deliveryLocked flag cleared. |
| BUG-63 | 🟡 Medium | OrderManager / WarmersSystem / FridgeDisplayServer | Fridges and warmers retain stock from the previous Open shift during Intermission/break time. `OrderManager.Reset()` is called but warmers display and fridge UI are not cleared visually. Players in back room see phantom stock. | ✅ Resolved 2026-04-01 — OrderManager.Reset() added to GameStateManager immediately before Intermission teleport (before existing EndOfDay Reset). Clears all 7 tables and triggers WarmersUpdated + FridgeUpdated broadcasts. |
| BUG-64 | 🟡 Medium | EndOfDaySummary / SummaryController | End-of-shift summary screen does not auto-close after 30 seconds (SUMMARY_DURATION). Stays open indefinitely until player manually dismisses. Design intent: auto-advance to Intermission. | ✅ Resolved 2026-04-01 — Self-cancellation bug fixed: SummaryController now sets dismissThread = nil before calling dismiss() inside the countdown loop, so task.cancel(dismissThread) in dismiss() no longer cancels itself. Confirmed working in April 1 playtest (summary auto-advanced). |
| BUG-65 | 🟡 Medium | TutorialController / BakeryClient | Player is never prompted to name their store after tutorial completion. Bakery naming dialog fires from PlayerDataInit but was showing during tutorial. | ✅ Resolved 2026-04-01 — BakeryClient guards showDialog behind InTutorial check; if InTutorial=true on init, watches GetAttributeChangedSignal("InTutorial") and defers showDialog until tutorial clears (1s delay for teleport to settle). |
| BUG-66 | 🟡 Medium | HUDController / TutorialUI | Some non-tutorial HUD elements remain visible during tutorial (beyond main HUD). Need full audit of all UI scripts to ensure InTutorial=true gates every non-tutorial panel. | Open — P2 |
| FR-1 | 💡 Feature | BoxCarryServer / OrderManager | Trash system — player should be able to discard a carried box (e.g. walk to a trash bin, hold E). Discarded box triggers order failure penalty (1-star) but clears carry state. Needed for stuck/wrong orders. | Post-Alpha candidate — evaluate after playtest feedback |
| FR-2 | 💡 Feature | PersistentNPCSpawner / NPCSpawner | NPC customer appearance needs improvement — better clothing variety, facial expressions, or R15 rigs. Current appearance too plain/identical. | Post-Alpha polish |
| FR-3 | 💡 Design Change | GameStateManager / DriveThruServer | Drive-thru currently unlocks after first completed shift. Design intent is store-level unlock (e.g. Bakery Level 3 or similar progression gate), not time-based. | Post-Alpha design revision |
| GAP-5 | 🟡 Medium | GameStateManager | All players disconnect mid-shift. Server shift cycle continues (timers run out, EndOfDay fires, Intermission runs). On rejoin, state may be mid-Intermission or at start of next PreOpen with no reset having happened for the previous incomplete shift. OrderManager tables may be stale. | Open — P2 |
| RISK-5 | 🟠 High | Performance | Rush Hour + 4–6 player full live load has NEVER been profiler-verified in a real game session. Solo baseline (172 Heartbeat/3s, 0 errors) passes but is not representative. With 6 players simultaneously baking, mixing, and delivering during Rush Hour, server load is 3–6× higher. A crash or severe lag during Alpha would be highly visible. Must do a controlled 4–6 player test session before opening to testers. | Active Risk — elevate from post-Alpha to pre-Alpha verification required. Run the Section 12 Performance Testing checklist with 4+ players before invite. |
| BUG-67 | 🔴 Critical | OrderManager / DressStationServer | `DeliverBox rejected: packSize mismatch box=1 order=4` on EVERY variety pack delivery attempt. Root cause: `OrderManager.CreateBox` sets `packSize = warmerEntry.quantity` — for variety pack entries, quantity=1 per cookie type, but `order.packSize` = total cookies across all types (e.g. 4). Box always has packSize=1, order always has packSize=4. Confirmed 3× in 2026-04-01 playtest. No variety pack can ever be delivered. | Open — P0, blocks all variety pack delivery |
| BUG-68 | 🟠 High | HUDController / TutorialUI | Main HUD (top bar with coins/level, order cards panel) visible during tutorial — InTutorial=true attribute is set but HUD was not fully hidden. Players see production HUD during tutorial flow. Previous fix (BUG-49) may have been incomplete or partially reverted. | Open — P1 |
| BUG-69 | 🟠 High | HUDController / WarmersSystem | "Cookie ready to box!" alert prompt appears during tutorial. WarmersUpdated remote fires to all players and HUDController shows the toast regardless of InTutorial state. InTutorial guard missing in the WarmersUpdated handler. | Open — P1 |
| BUG-70 | 🟠 High | TutorialController / TutorialCamera | Oven TP cutscene camera is still positioned at the fridge, not at the oven. TutorialCamera cinematic for step 3 (oven) was not updated — still using the fridge target part or fridge spawn position. | Open — P1 |
| BUG-71 | 🟠 High | TutorialController / PlayerDataManager | Tutorial 200-coin completion reward is not being awarded. `completeTutorial(player, true)` should call `AddCoins(player, 200)` but either the call is not firing, the natural=true path is not reached, or AddCoins fails silently for new players. | Open — P1 |
| BUG-72 | 🟠 High | HUDController / PlayerDataManager | Coin counter in top-right HUD does not update after any purchase — shop upgrades, cosmetics, or any other deduction. Displayed value stays at the value set during PlayerDataInit and never refreshes until player rejoins. Server fires CoinUpdate but client handler may not be connected or fires before HUD initializes. | Open — P1 |
| BUG-73 | 🟠 High | HUDController / BoxCarryServer | Carry pill ("Deliver to [NPC]" header + carry icon) and box-above-head UI persist after a failed delivery (packSize mismatch rejection). Also persist through break/Intermission phase. No cleanup fires on server-side delivery failure or GameState transition to Intermission. | Open — P1 |
| BUG-74 | 🟠 High | WarmersSystem / StaffManager | Warmer pickup proximity prompt persists after EndOfDay when player was mid-order. `setWarmersEnabled(false)` either not firing or the specific prompt that was active during the order was not re-disabled. Player in back room can still see "Pick up [cookie]" prompt from the pre-EndOfDay warmer. | Open — P1 |
| BUG-75 | 🟠 High | HUDController / PersistentNPCSpawner | Combo counter does not clear (reset to 0) when an NPC leaves due to patience expiry. `npcLeave` fires the order-failed path and NPC walks out, but `ResetCombo` is not called on patience timeout. Player's combo streak survives an expired order. | Open — P1 |
| BUG-76 | 🟠 High | StationRemapService / FridgeDisplayServer | Fridge display UI still shows all 6 cookie type panels instead of only the active menu selection (e.g. 4 chosen = 4 visible). BUG-58 disk patch applied to StationRemapService (added `display.Enabled = true/false` for active/inactive fridges) but change did not reach Studio — confirmed broken in 2026-04-01 playtest. Requires Studio sync verification. | Open — P1 (re-investigation of BUG-58) |
| BUG-77 | 🟠 High | DriveThruServer / BoxCarryServer | Drive-thru box visually stays welded to player after a successful drive-thru delivery. BUG-61 disk patch applied to DriveThruServer (`boxCarriedRemote:FireClient(player, nil)` + destroy `CarriedBox_<name>`) but not taking effect — confirmed broken in 2026-04-01 playtest. Requires Studio sync verification. | Open — P1 (re-investigation of BUG-61) |
| BUG-78 | 🟡 Medium | LifetimeChallengeManager | Lifetime milestone "Complete 10 orders" shows 0/10 despite player completing 4+ deliveries in the April 1 playtest. Either the OrderComplete event is not firing to LifetimeChallengeManager, the counter is not persisting to the player profile, or the display is not reading the live count correctly. | Open — P1 |
| BUG-79 | 🟡 Medium | SummaryController / GameStateManager | End-of-day countdown timer display freezes visually at :30 and does not count down during the 30-second SUMMARY_DURATION window. GameStateManager fires `stateChangedRemote:FireAllClients("EndOfDay", remaining)` each second but SummaryController client handler likely does not update the timer label on each tick — only on the initial broadcast. | Open — P1 |
| BUG-80 | 🟡 Medium | MenuServer / TutorialController | Cookie menu choice board (PreOpen selection screen) did not appear after tutorial ended during 2026-04-01 playtest. BUG-60 disk patch applied to MenuServer (InTutorial attribute watcher → sendOpenMenuBoard) but not confirmed working. Player exited tutorial and was in PreOpen with no menu prompt. | Open — P1 (re-investigation of BUG-60) |
| FEAT-1 | 💡 Feature | DoughTable2 / OrderManager | Trash/discard option at Dough Table 2 — lets players dump stuck or wrong-type dough batches. Interaction: ProximityPrompt on a trash bin near table. On trigger: batch removed from pipeline with 0-star penalty, carry state cleared. Needed for variety pack failures and mis-queued batches. | Session 17 candidate |
| FEAT-2 | 💡 Feature | GameStateManager / HUDController | Shift counter display above the PreOpen/Open timer — shows "Shift 3" etc. so players know their progress in the session. shiftNumber incremented each runCycle loop; broadcast via GameStateChanged or separate remote. | Session 17 candidate |
| FEAT-3 | 💡 Feature | SummaryController / LeaderboardManager / SessionStats | Rename shift leaderboard header from "This Shift" → "This Session" — better reflects that multiple shifts contribute to session stats. Change is a label-only update on the results screen and HUD leaderboard column. | Session 17 candidate |

---

## ☑️ SECTION 8 — ALPHA CHECKLIST

### MUST HAVE (Blockers)
- [x] **C-1** Station movement locking during minigames
- [x] **C-2** "What Next?" guidance (waypoints or coach tip bar)
- [x] **H-1** NPC facing counter correctly
- [x] **H-2** Dress station quality scoring (remove hardcode)
- [x] **H-3** Delivery race lock (first delivery wins)
- [x] **H-4** Dress order lock timeout on disconnect
- [x] **H-5** Level unlock content (3 tiers minimum)
- [x] **H-6** Tutorial fridge→oven step added
- [x] **H-7** Remote rate limiting on PurchaseItem + RequestMixStart
- [x] **H-8** Carry indicator UI (box icon + destination)
- [x] BUG-4 Box carry arms not detaching
- [x] BUG-13 NPC collision ceiling lift fixed
- [x] **BUG-34** PlayerDataManager `_serverLock` cleared on BindToClose / expiry logic added — no more silent save-skip on new server ✅ 2026-03-26
- [x] **BUG-35** RequestMixStart validates player's `unlockedRecipes`, not just menu — locked recipe bypass closed ✅ 2026-03-26
- [x] **BUG-22** Oven batch orphan on disconnect — add oven cleanup to cleanupPlayerSession ✅ 2026-03-26
- [x] **BUG-23** comboStreak resets each shift — fix profile streak persistence ✅ 2026-03-26
- [x] **BUG-24** "ShowAlert" added to RemoteManager REMOTES table ✅ 2026-03-26
- [x] **BUG-25** GamepassManager VIP/Speed actually wired to behavior (even with ID=0) ✅ 2026-03-26
- [x] **BUG-26** Rate-limit tables use UserId not player object + PlayerRemoving cleanup ✅ 2026-03-26
- [x] **BUG-27** Player receives feedback when batch cap is reached (no silent fail) ✅ 2026-03-26
- [x] **BUG-36** Duplicate AI worker systems resolved — one system canonical, other disabled/removed ✅ 2026-03-26
- [x] **BUG-39** Main menu shows correctly for new players — not hidden by PreOpen state ✅ 2026-03-27
- [x] **BUG-40** New player teleported to bakery area on tutorial start ✅ 2026-03-29
- [x] **BUG-41** Per-step teleports in tutorial (step 2→dough, step 3→fridge, step 4→dress) ✅ 2026-03-29
- [x] **BUG-42** AI hire prompts hidden/ignored during tutorial ✅ 2026-03-29
- [x] **BUG-44** Tutorial step 3 directs player to fridge first, not oven ✅ 2026-03-29
- [x] **BUG-45** PreOpen timer pauses while any player is in tutorial ✅ 2026-03-29
- [x] **BUG-46** Tutorial NPC spawned with chocolate_chip ×6 order before dress step ✅ 2026-03-29
- [x] **BUG-43** Minigame exit buttons show bold "X" and float at top-right corner outside panel ✅ 2026-03-29
- [x] **BUG-47** wirePrompt finds existing ProximityPrompts on nested station models ✅ 2026-03-30
- [x] **BUG-48** MinigameServer InTutorial guard — no AntiExploit false positives for tutorial players ✅ 2026-03-30
- [x] **BUG-49** HUD and menu board hidden during tutorial ✅ 2026-03-30
- [x] **BUG-50** OnMainMenu cleared after tutorial completion — PreOpen timer starts correctly ✅ 2026-03-30
- [x] **BUG-51** Cosmetic apron weld teleport bug fixed (unanchor all parts) ✅ 2026-03-30
- [x] **BUG-52** TutorialFridge FridgeDisplay hidden at startup ✅ 2026-03-30
- [x] **CLEANUP** Delete TEMP_ResetTutorial from SSS ✅ 2026-03-31
- [x] **CLEANUP** Delete TEMP_UnlockAllCosmetics from SSS ✅ 2026-03-31
- [ ] **BUG-67** Variety pack packSize mismatch resolved — all variety pack orders deliverable
- [ ] **BUG-68** HUD fully hidden during tutorial (InTutorial=true gates all HUD panels)
- [ ] **BUG-69** "Cookie ready to box" alert blocked during tutorial
- [ ] **BUG-70** Oven TP camera aimed at oven, not fridge
- [ ] **BUG-71** Tutorial 200-coin reward awarded on natural completion
- [ ] **BUG-72** Coin counter updates after every purchase without rejoin
- [ ] **BUG-73** Carry pill clears on delivery failure and on phase transition to Intermission
- [ ] **BUG-74** Warmer pickup prompts disabled on EndOfDay transition
- [ ] **BUG-75** Combo resets when NPC leaves due to patience expiry
- [ ] **BUG-76** Fridge display shows only active menu selections (re-investigate BUG-58)
- [ ] **BUG-77** Drive-thru box removed from player after successful delivery (re-investigate BUG-61)
- [ ] **BUG-78** Lifetime milestones tracking order count correctly
- [ ] **BUG-79** End-of-day timer counts down visually from :30 to :00
- [ ] **BUG-80** Cookie menu selection board opens after tutorial ends (re-investigate BUG-60)

### SHOULD HAVE (Quality bar)
- [x] **M-1** In-world NPC patience indicator
- [x] **M-2** Order ready alert (sound + HUD pill)
- [x] **M-3** Rush Hour announcement banner
- [x] **M-4** Warmer stock sync for joining players
- [x] **M-5** VIP NPC visual distinction
- [x] **M-6** S-Rank shift grade
- [x] **M-7** Results screen animation
- [x] **M-8** Settings UI (volume slider)
- [x] **M-9** Mobile scaling tested on portrait + tablet
- [x] **M-10** Combo break popup
- [x] **M-11** Loading indicator during data load
- [x] **M-12** Gamepass scaffold (Speed Pass stub)
- [x] **BUG-28** Drive-thru locked shift 1 — coach tip explains it unlocks after first shift ✅ 2026-03-26
- [x] **BUG-29** Drive-thru order reassignable when carrier disconnects ✅ 2026-03-26
- [x] **BUG-30** teleportAllTo uses indexed spread — no 6-player clip ✅ 2026-03-26
- [x] **BUG-31** Mid-shift joiner receives current coach tip ✅ 2026-03-26
- [x] **BUG-32** AI worker dismiss — notification + refund fired to owner ✅ 2026-03-26 (resolved by BUG-36 fix)
- [x] **BUG-33** New players start with 500 starter coins ✅ 2026-03-26
- [x] **BUG-37** Tutorial skip path does NOT grant completion reward — only natural completion does ✅ 2026-03-26
- [x] **GAP-2** EndOfDay mid-minigame stuck — MinigameServer cleans up all sessions on state change ✅ 2026-03-31
- [x] **GAP-2b** SaveProfile retry — 3 attempts with 2s backoff on DataStore failure ✅ 2026-03-31
- [x] **Regression matrix** Tests 1–6 all pass in Studio ✅ 2026-03-31
- [x] **BUG-57** Daily/weekly challenges visible on first shift Open ✅ 2026-04-01
- [x] **BUG-62** NPC walks out after delivery rejection — no permanent queue pile-up ✅ 2026-04-01
- [x] **BUG-63** Fridge/warmer displays cleared before Intermission ✅ 2026-04-01
- [x] **BUG-64** Summary screen auto-dismisses after 30s — no infinite hang ✅ 2026-04-01
- [x] **BUG-65** Bakery naming dialog shown after tutorial completion ✅ 2026-04-01
- [ ] **RISK-5** 4–6 player Rush Hour live load test completed with no server crash or severe lag

### NICE TO HAVE (Polish for Alpha)
- [x] Per-station breakdown in shift results
- [x] Cosmetic preview in shop
- [x] Upgrade tooltips in shop
- [x] Cookie type icon/thumbnail on order cards
- [x] Customer satisfaction emoji on delivery
- [x] "Order expired" visual at NPC location

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

## 📊 SECTION 11 — PROBLEMS AND RISKS SUMMARY (Updated 2026-03-25)

> This section was the original pre-Alpha risk register. All critical/high items are resolved. Remaining items are known post-Alpha gaps.

### ✅ Previously Dangerous / Could Break — ALL RESOLVED
1. ~~No movement lock~~ → ✅ **Fixed C-1** — WalkSpeed/JumpPower/JumpHeight=0 on session start
2. ~~Dress hardcoded score~~ → ✅ **Fixed H-2** — avgSnapshot() uses real station quality
3. ~~NPC ceiling lift~~ → ✅ **Fixed BUG-13** — PhysicsService "NPCs" collision group prevents HRP-HRP lift
4. ~~No delivery lock~~ → ✅ **Fixed H-3** — deliveryLocked flag, atomic check+set at 7 sites

### ✅ Previously Not Multiplayer Safe — MOSTLY RESOLVED
1. ~~Warmer stock not synced to mid-shift joiners~~ → ✅ **Fixed M-4** — task.defer snapshot on PlayerAdded
2. ~~Dress order lock has no expiry on disconnect~~ → ✅ **Fixed H-4** — PlayerRemoving cleanup + 90s task.delay auto-release
3. Box carry state can desync (BindableEvent vs RemoteEvent timing) → 🟡 **Known low-risk gap** — post-Alpha
4. Dough lock may orphan on rare disconnect race → 🟡 **Suspected BUG-11** — low frequency; post-Alpha

### ✅ Previously Exploitable — RATE LIMITS ADDED
1. ~~RequestMixStart — no rate limit~~ → ✅ **Fixed H-7** — 0.5s throttle, silent drop
2. ~~PurchaseItem — no rate limit~~ → ✅ **Fixed H-7** — 1s throttle per player
3. Session farming for mastery XP → 🟡 **Known design gap** — post-Alpha mitigation

### Post-Alpha UX Gaps (not blocking Alpha)
- Visible player role labels above head — post-Alpha
- Shared in-world order board visible to all — post-Alpha (Section 9)
- Filler tasks during downtime — post-Alpha
- Social actions between players — post-Alpha (L-6)
- Daily login streak — post-Alpha (L-1)

### ✅ Previously "Will Confuse New Players" — ADDRESSED
- ~~No "what do I press?" prompt before stations~~ → ✅ **Fixed C-2** — Coach tip bar fires on each station completion
- ~~Fridge→Oven step not taught in tutorial~~ → ✅ **Fixed H-6** — Tutorial step 3 covers fridge pull + oven
- Cookie types not mapped to fridge slots visually → 🟡 **Post-Alpha** — station remap shows cookie names on doors
- ~~Dress station: not clear which cookie is being decorated~~ → ✅ KDS shows cookie name per order
- ~~No indicator that a batch is waiting in fridge~~ → ✅ Coach tip + FridgeDisplay BillboardGui

### ✅ Previously "Will Make Players Quit Early" — ADDRESSED
- ~~Nothing unlocked by leveling up~~ → ✅ **Fixed H-5** — tip_boost at lvl 3, C&C at lvl 5, lemon at lvl 10
- 3-minute intermission with nothing to do → 🟡 **Post-Alpha** — spin wheel idea in Section 9
- ~~Rush Hour starts silently~~ → ✅ **Fixed M-3** — "RUSH HOUR!" alert banner (4s, red/gold)
- ~~No "mistake" feedback when session times out~~ → ✅ Order expired X visual at NPC position
- ~~Combo resets with no visual punishment feedback~~ → ✅ **Fixed M-10** — "STREAK BROKEN!" red alert

### 🔴 Codex Repo-Wide Audit Findings (Session 8 — 2026-03-26)

> Codex performed a full repo scan (not just the master file) and found 4 new issues + 1 elevated risk. Cross-reference complete: Codex "BUG-25" = my BUG-24 (already tracked). All others are new.

**Why we are STILL NOT ready for Alpha (Codex findings):**

1. **BUG-34 — Data Save Lock is Permanently Sticky**: `PlayerDataManager` writes `_serverLock = SESSION_ID` but never clears it. On any abnormal server shutdown, the lock stays in DataStore. A new server with a different SESSION_ID reads it, sees a mismatch, and **permanently skips saving** for all affected players. This is not a crash edge case — it's a systematic silent data loss path on every server restart. Players grinding XP and coins all shift would lose everything. Fix: write `_serverLock = nil` in BindToClose, or add a timestamp-based expiry.

2. **BUG-35 — Locked Recipes Are Accessible From Day 1**: The game claims cookies_and_cream unlocks at bakery level 5 and lemon_blackraspberry unlocks at level 10. But `MenuManager.DEFAULT_MENU` includes both, and `RequestMixStart` only validates against the active menu — not the player's `unlockedRecipes` list. Any new player can mix any of the 6 cookies from their first session, making the unlock system pure fiction. Fix: add ownership check in `RequestMixStart`.

3. **BUG-36 — Two AI Worker Systems Running Simultaneously**: `StaffManager.server.lua` and `AIBakerSystem.server.lua` both exist, both run, both access `OrderManager`, and both handle "AI does work" logic with different architectures. This is not a future risk — it's an active regression hazard. If one system completes a batch that the other was working on, results are undefined. Must resolve before any alpha session with real players who will expose timing interactions.

4. **BUG-37 — Tutorial Skip Grants Same Reward as Completion**: Skipping the tutorial calls `completeTutorial()` which grants a coin/XP reward. This makes skipping strictly dominant over playing through it — players lose nothing by skipping. The tutorial reward exists to incentivize learning the game, which is defeated entirely if skip is equally rewarded.

5. **RISK-5 — Peak Load Never Verified**: Solo baseline is clean. But 6-player Rush Hour is a qualitatively different load profile: 6× NPC patience ticks, 6× remote fires per station, batches completing simultaneously, all players potentially delivering at once. No live multi-player test has been run. This must happen before inviting alpha testers — a crash during their first session will end the alpha before it starts.

---

## 🧪 SECTION 12 — TESTING PLAN

> All boxes are unchecked = needs in-game verification. Run these before inviting Alpha testers. Log any failures to Section 7.

### Bug Testing
- [ ] Complete full solo shift Lobby → Intermission without errors
- [ ] Mix + deliver all 6 cookie types in one session
- [ ] Let NPC patience expire; verify order removed cleanly + expired X visual appears
- [ ] Let session time out (60s); verify batch unlocked
- [ ] Complete tutorial as new player (tutorialCompleted=false)
- [ ] Verify tutorial skips for returning player
- [ ] Buy every shop item; verify prerequisites enforced (level gate on tip_boost_1)
- [ ] Equip cosmetic; rejoin; verify cosmetic persists
- [ ] Verify coins save on rejoin
- [ ] Trigger Rush Hour; verify faster spawn rate + "RUSH HOUR!" alert shows
- [ ] Verify End-of-Day summary shows correct per-player station breakdown strip
- [ ] Verify shift grade (S/A/B/C/D) matches expected score formula
- [ ] Complete all 3 daily challenges; verify rewards granted + panel updates
- [ ] Complete a lifetime milestone; verify one-time award

### New Feature Testing (Session 5 additions)
- [ ] Deliver a 5-star order → satisfaction emoji ":D" appears above NPC, floats up, fades
- [ ] Deliver a 1-star order → ":(" emoji appears in red
- [ ] Let NPC order expire → red "X" billboard appears at NPC head position, floats/fades
- [ ] Mix a pink_sugar order → HUD order card shows pink border + pink dot
- [ ] Mix a chocolate_chip order → order card shows brown border + dot
- [ ] Complete mix station → station breakdown strip in shift results shows Mix score
- [ ] Complete only oven station → Oven shows score, Mix shows "—" in breakdown strip
- [ ] Verify combo pill shows streak count; on reset from ≥2: "STREAK BROKEN!" alert fires
- [ ] Verify "Cookie ready to box!" alert fires when a new warmer slot fills
- [ ] Carry a box → CarryPill shows orange "Carrying for [NPC name]"; deliver → pill clears

### Multiplayer Testing
- [ ] 2 players mix same batch simultaneously → only one succeeds
- [ ] 2 players pull same fridge item → only one succeeds
- [ ] 2 players accept same dress order → only one succeeds
- [ ] 2 players deliver to same NPC → no duplicate payout
- [ ] Player disconnects mid-mix → doughLock clears
- [ ] Player disconnects mid-oven → ovenBatch cleared, not orphaned (BUG-22)
- [ ] Player joins mid-shift → warmer stock visible immediately
- [ ] Player joins mid-shift → coach tip fires correctly (BUG-31)
- [ ] Player leaves holding box → box destroyed on server
- [ ] 6-player full session → batch pool not starved
- [ ] Rush Hour + 6 players → NPC cap (6) enforced
- [ ] 2nd player joins solo session → no AI worker dismissal occurs (AIBakerSystem disabled — BUG-32/36 resolved)
- [ ] Drive-thru: carrier disconnects after taking order → another player can deliver (BUG-29)
- [ ] 6 players teleport to intermission → no clipping (BUG-30)

### Exploit Testing
- [ ] Fire ResultMix with score=1000 → clamped to 100
- [ ] Fire ResultMix with score="hack" → rejected
- [ ] Fire ResultMix 0.1s after session start → rejected (< 3s)
- [ ] Fire ResultMix for cookieId not on menu → rejected
- [ ] Fire PurchaseItem without coins → rejected
- [ ] Fire PurchaseItem for owned item → rejected
- [ ] Spam RequestMixStart 50×/1s → no server error, rate-limited silently
- [ ] Spam PurchaseItem 50×/1s → UpdateAsync not called per-spam, throttled
- [ ] Fire DeliverBox with nonexistent NPC → safe nil handling

### Performance Testing
- [ ] Server script activity < 10ms avg during Rush Hour
- [ ] Memory stable after 10+ shifts with 6 players
- [ ] No RunService loops running after shift ends
- [ ] < 30 RemoteEvent fires/sec at peak load
- [ ] OrderManager batch tables cleared between shifts (SessionStats.Reset verified)
- [ ] NPC models fully destroyed (not just unparented) on leave
- [ ] Sounds reused (not recreated per-play)

### UI Testing
- [ ] Shop: buy item → coin display updates immediately
- [ ] Minigame: result popup appears + disappears in 2.5s
- [ ] Patience meter updates in real-time on order card + in-world color bar
- [ ] HUD combo counter updates on each delivery
- [ ] Shift results slide-up animation plays correctly; stat counters tick from 0
- [ ] Shift results show per-station breakdown strip (Mix/Dough/Oven/Frost/Dress)
- [ ] Shift results grade bounces in with Back ease after counters finish
- [ ] Daily challenge panel shows correct progress
- [ ] Test at 1366×768, 1920×1080, 375×812 (mobile portrait)
- [ ] No UI overlap between order cards and combo counter
- [ ] Dress station KDS scrolls with 4+ orders
- [ ] Coach tip bar (C-2) appears on correct triggers; auto-dismisses after 8s
- [ ] Settings panel: Music + SFX toggles actually mute sound

### Alpha Playtest Checklist
- [ ] 5 first-time players complete tutorial without asking how to play
- [ ] Average player makes 2+ deliveries in 8-minute shift
- [ ] No server crash in 30 minutes of play
- [ ] No data loss on rejoin within 5 minutes
- [ ] All 6 cookie types baked in one session
- [ ] Rush Hour event noticed by players (banner visible)
- [ ] Combo system understood within 3 shifts
- [ ] End-of-shift summary read and station breakdown noted (not instantly closed)
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

## 📈 SECTION 14 — FINAL REPORT SNAPSHOT (Updated 2026-03-26 — Post Session 10)

> ⚠️ Session 11 playtest found 8 new bugs (BUG-39 through BUG-46) that break the new-player experience. Fix all 8 in Session 12, then re-run new-player test, then RISK-5 load test.

| Category | Score | Notes |
|---|---|---|
| Core Systems | ✅ 98% | All pipeline bugs resolved. BUG-22/35 closed. BUG-25 SpeedPass/VIPPass now wired. Recipe bypass closed. |
| Multiplayer Safety | ✅ 95% | BUG-22/29/30/32/36 all resolved. Known low-risk gap: box carry desync (BUG-12, monitor during Alpha). |
| Data Integrity | ✅ 95% | BUG-34 lock expiry fixed. BUG-23 combo reset fixed. BUG-33 starter coins fixed. Minor known gap: no retry on save failure (post-Alpha). |
| UI/UX | 🟡 88% | BUG-43 exit buttons broken on some clients. BUG-39 main menu hidden for new players. Other coach tips/carry pill/order colors complete. |
| Onboarding / Tutorial | 🔴 60% | BUG-40/41/44 no teleports. BUG-45 PreOpen races past tutorial. BUG-46 no tutorial NPC for dress step. BUG-42 AI prompts visible during tutorial. |
| Progression/Retention | ✅ 95% | BUG-35 recipe bypass closed. BUG-33 starter coins added. BUG-23 combo reset fixed. Level unlock content present. |
| Performance | 🟡 85% | Solo baseline clean. BUG-26 memory leak fixed. RISK-5: 6-player Rush Hour peak load still unverified. |
| Anti-Exploit | ✅ 95% | BUG-17/24/25/26/35 all closed. Rate limits in place. GamepassManager now a proper ModuleScript. |
| Architecture | ✅ 95% | BUG-36 resolved — AIBakerSystem disabled, StaffManager canonical. Single AI worker system. Clean require graph. |
| Game Feel/Polish | ✅ 95% | 15 SFX, combo popups, rush hour banner, results animation, VIP NPC glow all complete. Screen effects post-Alpha. |
| **OVERALL** | **🟡 94%** | **8 new bugs from Session 11 playtest break new-player onboarding. Fix BUG-39 through BUG-46 in Session 12. After that: re-run new-player test, then RISK-5 (4–6 player Rush Hour) to clear Alpha.** |

### Open Alpha Risks (must be resolved — see Section 5 for tasks)
~~1. BUG-34~~ ✅ Resolved 2026-03-26
~~2. BUG-35~~ ✅ Resolved 2026-03-26
~~3. BUG-22~~ ✅ Resolved 2026-03-26
~~4. BUG-23~~ ✅ Resolved 2026-03-26
~~5. BUG-24~~ ✅ Resolved 2026-03-26
~~6. BUG-25~~ ✅ Resolved 2026-03-26
~~7. BUG-26~~ ✅ Resolved 2026-03-26
~~8. BUG-27~~ ✅ Resolved 2026-03-26
~~9. BUG-36~~ ✅ Resolved 2026-03-26
~~10. BUG-28 through BUG-33~~ ✅ All Resolved 2026-03-26
~~11. BUG-37~~ ✅ Resolved 2026-03-26
**1. 🔴 BUG-39** — Main menu hidden by PreOpen state — new players skip it entirely
**2. 🔴 BUG-40** — New player not teleported to bakery on tutorial start
**3. 🔴 BUG-41** — No per-step teleports during tutorial
**4. 🔴 BUG-42** — AI hire prompts visible/clickable during tutorial
**5. 🔴 BUG-45** — PreOpen timer advances during tutorial → game enters Open mid-tutorial
**6. 🔴 BUG-46** — No tutorial NPC → dress step has empty KDS, uncompletable
**7. 🟠 BUG-43** — Exit buttons render as broken box glyph on many clients
**8. 🟠 BUG-44** — Step 3 teleport drops player at oven instead of fridge
**9. 🟠 RISK-5** — Peak load (4–6 player Rush Hour) never verified — run after BUG-39/46 fixed

### Known Post-Alpha Limitations (acceptable for Alpha once above are fixed)
1. **Box carry desync (BUG-12)** — BindableEvent timing gap. Low-risk; monitor during Alpha.
2. **No retry on DataStore save failure** — crash = silent data loss on top of BUG-34. Post-Alpha hardening after BUG-34 is resolved.
3. **In-game challenge counters reset on crash** — non-persistent in-memory. Acceptable for Alpha.
4. **driveThruUnlocked is in-memory** — resets to false on server restart. Acceptable if server stays up during alpha session.

### What Changed Since Original 69% Assessment
- C-1 Movement lock: prevents batch starvation ✅
- C-2 What Next guidance: prevents new player confusion ✅
- H-1/2/3/4/5/6/7/8: All high-priority fixes applied ✅
- M-1 through M-12: All medium-priority features shipped ✅
- BUG-2: NPC facing wall in queue fixed ✅
- BUG-4/11/13: Arms detach + doughLock orphan + NPC ceiling lift fixed ✅
- BUG-9/10: Rate limits confirmed in place ✅
- 6 Nice-to-Haves: Cookie colors, emoji, expired X, station breakdown, tooltips, cosmetic preview ✅
- Performance + memory: All patterns verified clean ✅
- Main Menu: Verified functional ✅
- BUG-17: Drive-thru exploit fully verified closed (Session 7) ✅
- BUG-18/19: HUDController startup crash + showAlert nil guards fixed ✅
- BUG-20/21: Debug coin script removed + EndOfDaySummary remote restored ✅
- Session 7 strict audit: BUG-22 through BUG-33 found — all resolved in Session 9 ✅
- Session 8 Codex repo-wide audit: BUG-34 through BUG-37 + RISK-5 found — BUG-34/35/36/37 all resolved ✅
- Session 9 bulk fix sprint: 13 bugs resolved. 3 remaining (BUG-25/32/36) ✅
- Session 10: BUG-25/32/36 resolved. GamepassManager Script→ModuleScript fix. Zero-error boot confirmed. Only RISK-5 remains. ✅
- Codex "BUG-25" cross-reference: confirmed = my BUG-24, no duplicate ✅

### ⚠️ ALPHA CLEARANCE RULE
> The OVERALL score in Section 14 must only be changed to ✅ 100% when ALL of the following are true:
> 1. Every bug in Section 7 with Status = Open is marked Resolved with a verification date
> 2. Every `[ ]` checkbox in Section 8 MUST HAVE and SHOULD HAVE blocks is checked `[x]`
> 3. A full clean play session runs from Lobby → Intermission with `errors: []` in the console
> 4. The BUG-22 oven orphan test passes (player disconnects mid-oven → batch not stuck)
> 5. The BUG-23 combo reset test passes (streak = 0 at start of each new shift)
> 6. The BUG-34 data save test passes (server restarts → new server saves profiles correctly, no lock conflict)
> 7. The BUG-35 recipe bypass test passes (new player cannot mix cookies_and_cream or lemon_blackraspberry)
> 8. RISK-5 live load test passes (4–6 players, Rush Hour, no crash, < 10ms avg server activity)
>
> If Codex or any external tool suggests additional fixes — cross-reference against Section 7 before adding to avoid duplicates, then add new bugs with the next sequential BUG-ID. Next available ID: BUG-47.

---
*End of MASTER PROJECT FILE — Always update this file, never rewrite. Keyphrase: COOKIE ALPHA MASTER FILE*

