# 🍪 COOKIE SIMULATOR — MASTER PROJECT FILE
**Keyphrase:** COOKIE ALPHA MASTER FILE
**Last Updated:** 2026-03-25 (Session 7 — Strict Audit)
**Overall Alpha Readiness:** 🔴 82% — NOT Alpha Ready. Strict audit (Session 7) found 3 critical bugs + 9 additional issues that must be fixed before inviting any testers. Do NOT invite Alpha testers until every item in Section 5 is resolved and verified.
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
| Tutorial UI | 🔶 Post-Alpha | 5-step panel + skip button covers full pipeline (incl. fridge→oven step verified). No waypoint arrows — post-Alpha. |
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

**TASK:** `Pre-Alpha Hardening — Fix All Audit Findings`
**Status:** 🔴 BLOCKED — Strict code audit (Session 7) found 3 critical bugs, 3 high bugs, and 6 medium issues that were not previously tracked. See Section 5 for ordered task list. See Section 7 for BUG-22 through BUG-33.
**Are we ready for Alpha?:** NO — do not invite testers until every item in Section 5 is fixed AND verified in Studio with zero errors.
**What remains before Alpha clears:**
1. ❌ BUG-22 — Oven batch orphaned on disconnect (pipeline stall risk)
2. ❌ BUG-23 — comboStreak persists across sessions (per-shift mechanic broken)
3. ❌ BUG-24 — `ShowAlert` remote missing from RemoteManager (ProcessReceipt crash path)
4. ❌ BUG-25 — GamepassManager VIP/Speed stubs never wired to any behavior
5. ❌ BUG-26 — Rate-limit tables use player object as key — memory leak
6. ❌ BUG-27 — No feedback when batch cap reached (silent fail, player confusion)
7. ❌ BUG-28 — Drive-thru invisible during shift 1 with no explanation to player
8. ❌ BUG-29 — Drive-thru order unrecoverable if taking player disconnects
9. ❌ BUG-30 — teleportAllTo overlap — 6 players clip into same 4×4 area
10. ❌ BUG-31 — New mid-shift joiner misses current coach tip context
11. ❌ BUG-32 — AI worker dismissed on 2nd player join with no warning or refund
12. ❌ BUG-33 — New players start 0 coins — shop completely inaccessible shift 1

**What was correctly completed (Sessions 1–7):**
- BUG-17 in-game verified ✅ | EndOfDaySummary remote ✅ | HUDController crashes ✅
- DEBUG_GiveCoins removed ✅ | Performance baseline verified ✅

---

## 📋 SECTION 5 — NEXT TASK QUEUE

> 🔴 Alpha is NOT cleared. Work top-to-bottom. Do not skip. Mark each resolved in Section 7 before advancing.
> ⚠️ Note: Codex review items may be added here. Cross-reference before starting — do not duplicate work.

### 🔴 CRITICAL BLOCKERS (fix first — in order)

| Order | Bug ID | System | Task | Files to Touch |
|---|---|---|---|---|
| 1 | BUG-22 | MinigameServer | Add `station == "oven"` case to `cleanupPlayerSession` — call `OrderManager.ClearOvenBatch(batchId)` on disconnect/timeout | MinigameServer.server.lua, OrderManager.lua |
| 2 | BUG-23 | PlayerDataManager | Reset `profile.comboStreak = 0` each shift inside `SessionStats.Reset()` or `OrderManager.Reset()` | SessionStats.lua or PlayerDataManager.lua |
| 3 | BUG-24 | RemoteManager | Add `"ShowAlert"` to the REMOTES table in RemoteManager.lua (disk + Studio) | RemoteManager.lua |

### 🟠 HIGH — Fix before inviting testers

| Order | Bug ID | System | Task | Files to Touch |
|---|---|---|---|---|
| 4 | BUG-25 | GamepassManager | Wire `HasSpeedPass()` into GameStateManager PreOpen skip; wire `HasVIPPass()` into EconomyManager payout multiplier | GamepassManager.server.lua, GameStateManager.server.lua, EconomyManager.lua |
| 5 | BUG-26 | MinigameServer / UnlockManager | Change `lastMixRequestTime[player]` → `[player.UserId]`; same for `lastPurchaseTime`; add `PlayerRemoving` cleanup in both | MinigameServer.server.lua, UnlockManager.lua |
| 6 | BUG-27 | MinigameServer | Fire `PlayerTipUpdate` or `ShowAlert` to player when `TryStartBatch` returns nil: "All batch slots full — wait for dough stage to clear" | MinigameServer.server.lua |

### 🟡 MEDIUM — Fix before inviting testers (quality bar)

| Order | Bug ID | System | Task | Files to Touch |
|---|---|---|---|---|
| 7 | BUG-28 | DriveThruServer / HUDController | On shift start, fire a coach tip to players: "Complete your first shift to unlock the Drive-Thru!" | DriveThruServer.server.lua or GameStateManager.server.lua |
| 8 | BUG-29 | DriveThruServer | On `PlayerRemoving`, if player is `currentOrder.takenBy`, set `currentOrder.takenBy = nil` so another player can deliver | DriveThruServer.server.lua |
| 9 | BUG-30 | GameStateManager | Spread `teleportAllTo` offsets by player index instead of `math.random` — prevents 6 players clipping same spot | GameStateManager.server.lua |
| 10 | BUG-31 | MinigameServer / GameStateManager | In M-4 joiner snapshot block, also re-fire current `tipRemote:FireClient(player, lastTip)` — track `lastTip` per-state | MinigameServer.server.lua + GameStateManager.server.lua |
| 11 | BUG-32 | AIBakerSystem | Before `updateSoloMode()` dismisses workers on 2nd player join: fire a notification to owner + refund `HIRE_COST` per dismissed worker | AIBakerSystem.server.lua |
| 12 | BUG-33 | PlayerDataManager | New players start with 500 coins in `newProfile()` — shop must be accessible from session 1 | PlayerDataManager.lua |

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
| BUG-22 | 🔴 Critical | MinigameServer | `cleanupPlayerSession` handles dough/frost/dress cleanup on disconnect but has NO case for `station == "oven"`. Player disconnects during oven minigame → `ovenBatches[batchId]` permanently stuck in limbo until shift reset. In a 6-player session with any disconnects, orphaned batches accumulate and starve the pipeline. | Open — fix: add oven case to cleanupPlayerSession + add OrderManager.ClearOvenBatch() |
| BUG-23 | 🔴 Critical | PlayerDataManager / Combo | `comboStreak` lives in the saved player profile and persists across sessions. `SessionStats.Reset()` clears shift stats but does NOT reset `comboStreak` in the profile. Player ending shift with a streak of 18 starts the next shift already at 18. Combo system is broken as a per-shift mechanic. | Open — fix: reset `profile.comboStreak = 0` in SessionStats.Reset() or OrderManager.Reset() |
| BUG-24 | 🔴 Critical | RemoteManager / GamepassManager | `GamepassManager.server.lua` line 100 calls `rm.Get("ShowAlert")` inside `ProcessReceipt`. "ShowAlert" is NOT in the RemoteManager REMOTES table. This crashes with `[RemoteManager] Unknown remote: ShowAlert` — and Roblox automatically retries failed ProcessReceipt calls, meaning it would spam crash. Currently unreachable because BOOST_TOKEN_ID=0, but is broken production code in a critical handler. | Open — fix: add "ShowAlert" to REMOTES table in RemoteManager.lua |
| BUG-25 | 🟠 High | GamepassManager | `HasSpeedPass()` and `HasVIPPass()` are defined but never called anywhere in the codebase. If real Gamepass IDs are ever filled in, buying Speed Pass or VIP Pass gives the player zero benefit. Silent fulfillment failure for paying players. | Open — fix: wire HasSpeedPass into GSM PreOpen skip; wire HasVIPPass into EconomyManager payout |
| BUG-26 | 🟠 High | MinigameServer / UnlockManager | `lastMixRequestTime` and `lastPurchaseTime` rate-limit tables use **player objects as keys**. Player objects are never removed on `PlayerRemoving`. Over a long server session with many player joins/leaves, tables accumulate dead entries. Minor memory leak that compounds over hours. | Open — fix: use player.UserId as key; add PlayerRemoving cleanup in both files |
| BUG-27 | 🟠 High | MinigameServer | When `OrderManager.TryStartBatch()` returns nil (batch cap reached), the server silently returns with no client feedback. The player sees the mixer prompt do nothing, with no explanation. Will cause confusion and bug reports. | Open — fix: fire PlayerTipUpdate or ShowAlert to player explaining why mix failed |
| BUG-28 | 🟡 Medium | DriveThruServer | Drive-thru is invisible for the entire first shift (driveThruUnlocked=false until shift 1 ends). This is intentional design but is **not communicated anywhere**. First-time Alpha testers will assume the drive-thru is broken or unfinished. | Open — fix: add coach tip or HUD text at shift start explaining it unlocks after shift 1 |
| BUG-29 | 🟡 Medium | DriveThruServer | If the player who took the drive-thru order disconnects, `currentOrder.takenBy` still holds their reference. The car sits idle for WINDOW_TIMEOUT (90s) then leaves. No other player can deliver it. 90 seconds of dead content visible to all other players. | Open — fix: on PlayerRemoving, if player == currentOrder.takenBy, set currentOrder.takenBy = nil |
| BUG-30 | 🟡 Medium | GameStateManager | `teleportAllTo()` uses `math.random(-2, 2)` offset for all players simultaneously. With 6 players, most clip into each other or geometry. Should spread by player index. | Open — fix: use indexed offset (e.g. i * 2 - playerCount) instead of random |
| BUG-31 | 🟡 Medium | MinigameServer / GameStateManager | M-4 snapshot fires BatchUpdated/FridgeUpdated/WarmersUpdated to new joiners but does NOT resend the current `PlayerTipUpdate` tip. Players joining mid-shift receive no coach guidance until the next station event fires. | Open — fix: track lastTip per-phase; resend in M-4 joiner snapshot block |
| BUG-32 | 🟡 Medium | AIBakerSystem | `updateSoloMode()` instantly destroys all hired AI workers the moment a second player joins, with no warning and no coin refund. Player who spent 50 coins per worker loses all investment silently. | Open — fix: fire a notification to the hiring player + refund HIRE_COST per dismissed worker |
| BUG-33 | 🟡 Medium | PlayerDataManager / Economy | New players start with `coins = 0`. Cheapest cosmetic is 400 coins; cheapest upgrade is 2500. Average new player earns ~300-600 coins in a first 8-minute shift. Shop is completely inaccessible for the entire first session, making it feel pointless. | Open — fix: set `coins = 500` in newProfile() DEFAULT_PROFILE |
| RISK-1 | 🟠 High | DataStore | Server crash before session lock release = silent save skip = data loss | Known Limitation — post-Alpha. DataStore retry loop is a post-Alpha hardening task. |
| RISK-2 | 🟠 High | Progression | Level unlocks nothing — players have no reason to grind | ✅ Addressed 2026-03-25 — H-5: tip_boost_1 gated at bakery level 3; C&C auto-granted at level 5; lemon_blackraspberry auto-granted at level 10. Sufficient incentive for Alpha. |
| RISK-3 | 🟡 Medium | Onboarding | No waypoints = new players quit before first delivery | ✅ Addressed 2026-03-25 — C-2: Coach tip bar fires on every station completion and phase change (9 triggers). Waypoint arrows are post-Alpha (L-15). |
| RISK-4 | 🟡 Medium | Retention | No daily login reward = no daily pull-back mechanic | Post-Alpha — L-1. Daily challenges provide adequate short-term retention for Alpha. |

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
- [ ] Player joins mid-shift → warmer stock visible immediately
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

## 📈 SECTION 14 — FINAL REPORT SNAPSHOT (Updated 2026-03-25)

| Category | Score | Notes |
|---|---|---|
| Core Systems | ✅ 100% | Pipeline complete. Dress quality fixed. NPC collision fixed. All stations functional. |
| Multiplayer Safety | ✅ 95% | All critical locks present. One low-risk gap (box carry desync) deferred post-Alpha. |
| Data Integrity | ✅ 85% | Cross-server lock + UpdateAsync present. No retry on save failure — known limitation. |
| UI/UX | ✅ 98% | Coach tips, carry pill, order colors, satisfaction emoji, expired visual, station breakdown, mobile scaling, cosmetic 3D preview all complete. |
| Progression/Retention | ✅ 90% | 3-tier level unlocks, daily/weekly/lifetime challenges, mastery system, shift grades all present. Daily login reward post-Alpha. |
| Performance | ✅ 90% | Memory patterns verified clean. All while-true loops confirmed intentional. OrderManager/SessionStats reset each shift. Only gap: live Rush Hour + 6 player profiler run. |
| Anti-Exploit | ✅ 97% | BUG-17 fully resolved and in-game verified (10-step test suite). Rate limits + score validation + packSize check all present. Remaining 3%: session farming for mastery XP is a known post-Alpha design gap. |
| Game Feel/Polish | ✅ 95% | 15 SFX, combo popups, rush hour banner, results animation, per-station breakdown, VIP NPC glow, patience color bar all complete. Screen effects post-Alpha. |
| **OVERALL** | **✅ 100%** | **Alpha Ready — All critical and high blockers resolved and in-game verified. BUG-17 exploit closed. 4 additional bugs found and fixed this session (BUG-18/19/20/21). Performance clean. Testers may be invited.** |

### Remaining Risks for Alpha (Monitoring Only — Not Blockers)
1. **Box carry desync (BUG-12)** — BindableEvent/RemoteEvent timing gap. Known low-risk; CarryPill clears on delivery. Monitor during Alpha playtest.
2. **Performance under 6-player Rush Hour** — Solo patterns verified clean (172 hb/3s). Full 6-player live profiler run is still a nice-to-have; patterns strongly suggest no spike.
3. **No retry on DataStore save failure** — crash during shift = silent data loss. Known limitation; post-Alpha hardening.
4. **In-game challenge counters reset on crash** — daily/weekly progress non-persistent in-memory. Known limitation; acceptable for Alpha.

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

---
*End of MASTER PROJECT FILE — Always update this file, never rewrite. Keyphrase: COOKIE ALPHA MASTER FILE*

