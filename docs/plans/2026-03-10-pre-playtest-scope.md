# Pre-Playtest Scope — Cookie Empire: Master Bakery
**Date:** 2026-03-10
**Target:** 80% of end result ready before closed playtest
**Reference:** `2026-03-09-game-vision-replayability-design.md`

---

## Already Done ✅
- Named Bakery + Bakery Level
- 60-cookie catalog + Cookie Unlock/Ownership
- Menu Selection (PreOpen phase)
- Station Remap (warmers/fridges update to match active menu)
- Intermission phase (back room teleport between shifts)
- 3 Daily Challenges (Easy/Medium/Hard, midnight UTC reset)
- NPC spawning, Tutorial, Economy/DataStore, Leaderboard
- StaffManager AI (solo mode workers)

---

## To Build Before Playtest

| # | System | Size | Status |
|---|--------|------|--------|
| 1 | Fix ShopClient/ShopServer | Small | ✅ Done |
| 2 | Station upgrade effects | Small | ✅ Done |
| 3 | Topping minigame | Medium | ❌ Not done |
| 4 | Lobby TV (Today's Menu display) | Small | ❌ Not done |
| 5 | Station Mastery / Roles | Large | ❌ Not done |
| 6 | Employee of the Shift | Small | ❌ Not done |
| 7 | Weekly Challenges | Small | ❌ Not done |
| 8 | Lifetime / All-Time Challenges | Small | ❌ Not done |
| 9 | M7 UI Polish (all screens + Badge Book, Cookie Collection Book) | Large | ❌ Not done |
| 10 | Patch 7 (delete TestNPCSpawner) | Tiny | ❌ Deferred |

---

## System Details

### 1. Fix ShopClient/ShopServer
- `ShopClient.client.lua` exists (Upgrades + Cosmetics tabs) but has no matching server handler
- Need `ShopServer.server.lua` to wire purchases through `UnlockManager`
- Need a back room terminal prop (proximity prompt) that opens the shop during Intermission
- Back room boards needed: upgrade board placeholder at (+25, 8, -157) is reserved

### 2. Station Upgrade Effects
- `UnlockManager` catalogs 10 upgrades and accepts purchases, but effects don't apply at runtime
- Need to read purchased upgrades from PlayerDataManager and apply:
  - Tip Boost I/II → multiply NPC payout
  - NPC Patience I/II → add seconds to NPC patience timer
  - Fridge Expansion I/II → increase fridge capacity
  - Extra Warmer I/II → unlock 7th/8th warmer slot + menu slot
  - Oven Speed → reduce bake cycle time

### 3. Topping Minigame
- Part of the Dress station, triggered after boxing cookies
- Only fires if any cookie in the box has toppings (`NeedsToppings` flag in CookieData)
- Mechanic: shake/pour — player holds a key to pour toppings, filling a progress bar
- Not cookie-specific: same shake interaction for all toppings (no matching puzzle)
- Affects dress quality score

### 4. Lobby TV (Today's Menu)
- Physical TV Part in lobby/front area of bakery
- SurfaceGui showing: "TODAY'S MENU" header + 6 cookie name/icon slots
- Updates when `StationRemapped` remote fires (menu locked at Open start)
- Shows placeholder slots during PreOpen/Intermission

### 5. Station Mastery / Roles
- 5 roles: Mixer, Baller, Baker, Glazer, Decorator
- Auto-grows from station use — no manual role selection
- XP per station use: ~15 avg, ~25 for perfect quality
- 10 levels per role, cumulative XP thresholds from vision doc
- Level 5 unlocks mechanical bonus (5% improvement per role)
- Level 10 maxes bonus at 10%
- Persisted in PlayerDataManager profile (`mastery` table, 5 keys)
- Displayed on HUD and summary screen
- Rewards at every level: coins + titles (see vision doc for full reward table)

### 6. Employee of the Shift
- End-of-shift spotlight shown on summary screen
- 5 winners (one per station), awarded simultaneously
- Stats tracked: mix quality avg, dough batches, oven speed, frost streak, boxes delivered
- Simple addition to SessionStats + SummaryController

### 7. Weekly Challenges
- Same architecture as daily challenges (DailyChallengeManager pattern)
- Resets every Monday midnight UTC
- 3 challenges: Easy / Medium / Hard, bigger goals and rewards than dailies
- Examples from vision doc:
  - "Bake 50 Tier 2 cookies this week" → rare cosmetic or coins
  - "Earn 2,000 coins in a single shift" → upgrade voucher or 500 coins
  - "Complete 5 shifts with 3+ players" → badge + coins
- Progress persists in PlayerDataManager profile (`weeklyChallenges` field)

### 8. Lifetime / All-Time Challenges
- Permanent milestones, never reset
- Check against existing PlayerDataManager stats (ordersCompleted, cookiesSold, etc.)
- Examples:
  - "Bake 1,000 total cookies" → badge + title
  - "Complete 100 daily challenges" → rare uniform
  - "Max out any Station Mastery" → exclusive cosmetic
  - "Earn 10,000 coins lifetime" → badge
- No progress bar needed — binary complete/incomplete
- Shown in a Challenges screen (accessible from HUD or back room)

### 9. M7 UI Polish
- Polish all existing screens: HUD, summary, minigame UIs, menu board, daily challenges board
- New screens to add:
  - **Badge Book** — organized badge display (Milestone, Station, NPC, Challenge, Secret categories)
  - **Cookie Collection Book** — all 60 cookies, greyed until baked, tracks times baked + first baked date
  - **Player Profile screen** — coins, level, mastery levels, badges earned, lifetime stats
- Consistent visual theme across all UI: font, colors, corner radii, animations (0.2–0.4s tweens)
- All minigame UIs: progress bars, countdowns, result flashes should feel polished

### 10. Patch 7
- Delete `src/ServerScriptService/Core/TestNPCSpawner.server.lua`
- Verify tutorial step 9 gate still works without it (re-check tutorial flow)

---

## Post-Playtest (intentionally deferred)
- NPC Rarity — requires 3D art for 47 unique NPCs
- Prestige — nobody hits Bakery Level 50 during playtest
- Drive-Thru — gated at Bakery Level 30, requires building construction
- Customer Book — only valuable once NPCs have unique visuals
- Character Closet — polish layer, Phase 5
- Game Passes — don't monetize a playtest

---

## Suggested Build Order
1. Patch 7 (tiny, get it out of the way)
2. Fix ShopClient/ShopServer (broken system, fix first)
3. Station upgrade effects (completes the shop system)
4. Lobby TV (small, visual win)
5. Topping minigame (new gameplay, medium)
6. Employee of the Shift (small, enhances summary screen)
7. Weekly Challenges (small, builds on daily challenges)
8. Lifetime Challenges (small, builds on weekly)
9. Station Mastery / Roles (large, save for when other systems are stable)
10. M7 UI Polish (last — polish everything once all features exist)
