# CookieSimulator — Alpha Readiness Review
**Date:** 2026-03-20
**Reviewer:** Claude (automated deep audit across all server + client systems)
**Files analyzed:** OrderManager, DressStationServer, GameStateManager, MinigameServer,
PlayerDataManager, TutorialController, RemoteManager, PersistentNPCSpawner,
EconomyManager, SessionStats, StaffManager, all StarterGui/StarterPlayerScripts UI files

---

## 1. Overall Verdict

**Not alpha-ready in current state. Block on 4–5 critical issues first.**

The core loop is present and has real identity — six stations, clear flow, M7 polish applied to UI. But two separate debug coin grants are still in the production path (total +50,500 coins per join), there are concurrent race conditions on the warmer/dress systems that can corrupt order state under simultaneous players, and tutorial gates can be trivially spoofed by any client. These are blockers. Fix them, then everything else is manageable polish and hardening.

---

## 2. Critical Issues

### C1 — Debug 50k coins + unlock reset on every join
**File:** `src/ServerScriptService/Core/PlayerDataManager.server.lua` lines 245–248
**Symptom:** Every player joins with 50,000 coins and all unlocks cleared. Economy testing is meaningless. Players cannot retain purchased upgrades across sessions.
**Fix:** Delete lines 245–248. Gate debug mutations behind an explicit `IS_STUDIO` or `DEV_MODE` flag (check `RunService:IsStudio()` and only run in that context).

### C2 — Debug 500 coins on join (second grant)
**File:** `src/ServerScriptService/Core/StaffManager.server.lua` lines 653–660
**Symptom:** Stacks on top of C1. Players start every session with 50,500 coins. With HIRE_COST=50 that's 1,010 free hires.
**Fix:** Remove the `Players.PlayerAdded` handler at the bottom of StaffManager or gate it with `RunService:IsStudio()`.

### C3 — TakeFromWarmers / TakeFromWarmersByType race conditions
**File:** `src/ReplicatedStorage/Modules/OrderManager.lua` lines 242–251, 285–307
**Symptom:** Two concurrent calls (e.g., Frost worker + Dress player simultaneously) iterate and mutate the same warmers array. Second call can remove the wrong entry or find a phantom quantity from a clone. Results in wrong cookies delivered or warmer count going negative.
**Fix:** Introduce a simple mutex/debounce flag per cookieId around the take operation, or use a queue pattern: collect pending takes, resolve in a single-frame loop. At minimum, snapshot the entry before removing and validate it's still present.

### C4 — DressStation lockOrder has no exclusive lock
**File:** `src/ServerScriptService/Minigames/DressStationServer.server.lua` lines 260–339
**Symptom:** Two players fire lockOrder simultaneously with the same orderId. Both pass validation; second player's dressLocked entry overwrites first. First player then walks to warmer with a stale lock and either fails silently or boxes the wrong order.
**Fix:** Add an `orderLocks` table keyed by orderId. On lockOrder entry, check `if orderLocks[orderId] then` fire an error remote and return. Clear `orderLocks[orderId]` on box creation, cancel, or player disconnect.

### C5 — RequestMixStart trusts client cookieId without validation
**File:** `src/ServerScriptService/Minigames/MinigameServer.server.lua` lines 261–265
**Symptom:** Client can send any string as cookieId (e.g., an unowned or non-existent recipe). If OrderManager.TryStartBatch() doesn't reject it, an invalid batch is created.
**Fix:** Before calling TryStartBatch, validate that `cookieId` is in the active menu AND that the player's profile has it unlocked. If MenuServer exposes the current menu, do: `if not table.find(MenuServer.GetActiveMenu(), cookieId) then return end`.

---

## 3. Major Issues

### M1 — Tutorial gates are client-spoofable
**File:** `src/ServerScriptService/Core/TutorialController.server.lua` lines 137–195
**Symptom:** Every step-advance is triggered directly from OnServerEvent handlers. Client can fire `tutorialDoneRemote`, `startGameRemote`, `mixResultRemote`, etc. at any time without actually completing the station. Tutorial can be skipped entirely in seconds.
**Fix:** Tutorial should only advance from server-authoritative completion events (MinigameServer step-complete BindableEvents, FridgePulled, etc.). Client remotes should signal "I pressed skip" — the server decides if skip is permitted, not the client deciding the step is done.

### M2 — Oven session can start with nil batchId
**File:** `src/ServerScriptService/Minigames/MinigameServer.server.lua` lines 324–332
**Symptom:** If `ovenSession[player]` is nil when the oven result remote fires, `batchId=nil` and `activeSessions[player]` gets `{station="oven", batchId=nil}`. endSession() then passes nil batchId to OrderManager, likely causing a silent no-op or warn.
**Fix:** Guard on line 326: `if not batchId then return end` before setting activeSessions.

### M3 — applyBakerUniform crashes if character clone fails
**File:** `src/ServerScriptService/Core/StaffManager.server.lua` lines 48–54
**Symptom:** If the block-rig fallback path is used (or character returns nil), `applyBakerUniform(rig)` tries to parent a Shirt to nil, throwing an error. Worker spawns without uniform and the function errors out.
**Fix:** Wrap `applyBakerUniform` in pcall or add `if not rig then return end` at the top of the function.

### M4 — DressStation warmer validation-to-pickup race window
**File:** `src/ServerScriptService/Minigames/DressStationServer.server.lua` lines 288–414
**Symptom:** Warmer count is validated at line 288 (snapshot), but actual warmer pickup happens ~100ms later at line 414 after teleport and wait(1). Another player can take the cookies in the gap. Player is teleported to dress station for an order that can no longer be fulfilled.
**Fix:** Reserve the warmer entries at validation time (soft-lock them against this order) and release on box completion or cancellation.

### M5 — skipPreOpenRemote has no auth check
**File:** `src/ServerScriptService/Core/GameStateManager.server.lua` lines 89–91
**Symptom:** Any client can fire this remote to skip PreOpen at any time, including before game starts (flag persists until next PreOpen, skipping it immediately when runCycle reaches it).
**Fix:** Add an admin check or restrict to server-only. At minimum: `if not isAdmin(player) then return end`.

### M6 — HUD ScreenGui DisplayOrder not set (defaults 0)
**File:** `src/StarterGui/HUD/HUDController.client.lua` (ScreenGui creation)
**Symptom:** All minigame GUIs have DisplayOrder=15. If HUD defaults to 0, HUD elements (coin counter, timer, order pill) render *behind* the minigame overlay. Players can't see their HUD during a minigame.
**Fix:** Set `HUD.DisplayOrder = 2` (above default, below minigames).

### M7 — Minigame GUIs overflow phones <400px wide
**Files:** All four minigame client scripts (Mix=380px, Dough=380px, Oven=360px, Frost=420px)
**Symptom:** On iPhone SE (375px) or any narrow phone, minigame windows extend off-screen. Players can't see or interact with the right side of the UI.
**Fix:** Replace fixed-pixel width with `math.min(FIXED_WIDTH, ViewportSize.X - 20)` and center accordingly. Or use UISizeConstraint with MaxSize.

### M8 — SummaryGui fixed 520px height overflows short phones
**File:** `src/StarterGui/SummaryGui/SummaryController.client.lua`
**Symptom:** On a 667px-tall phone with system UI insets, visible height may be ~580px. Summary frame is 520px but positioned at vertical center — could clip.
**Fix:** Clamp height like the width: `math.min(520, ViewportSize.Y - 60)`.

### M9 — No player disconnect cleanup cascade
**Files:** GameStateManager, OrderManager, DressStationServer
**Symptom:** When a player disconnects mid-session: their OrderManager batch persists until the batch expires, their DressStation lock persists indefinitely (orderId stays locked — no other player can claim it), their minigame session keeps the station locked. The station may become permanently inaccessible for the rest of the shift.
**Fix:** `Players.PlayerRemoving` should fire cleanup on: `activeSessions[player]`, `dressLocked[player]`, `orderLocks` for any orderId held by that player, and `ovenSession[player]`.

### M10 — SessionStats.Reset() must be verified to fire between shifts
**File:** `src/ServerScriptService/Core/SessionStats.lua` + GameStateManager
**Symptom:** If Reset() is not called when transitioning Open→Intermission, the next shift's Employee-of-Shift scores accumulate across multiple shifts, inflating the "best employee" metric.
**Fix:** Verify GameStateManager calls `SessionStats.Reset()` in the EndOfDay→Intermission transition. If not present, add it.

---

## 4. Minor Issues

### m1 — NPC patience timer doesn't tick in `at_counter` state
**File:** `src/ServerScriptService/Core/PersistentNPCSpawner.server.lua` lines 632–643
**Symptom:** Patience only decrements in `waiting_in_queue` and `seated` states. An NPC waiting at the counter (after order taken but before box delivered) never times out from patience logic. They will wait up to COUNTER_TIMEOUT (90s) from the hardcoded task.delay, not from their patience bar.
**Visible impact:** Patience bar UI shows time running out but the NPC doesn't actually leave when it hits zero while `at_counter`.
**Fix:** Either tick patience in all states, or explicitly document that `at_counter` state uses only the hardcoded counter timeout.

### m2 — postOvenScores memory leak
**File:** `src/ReplicatedStorage/Modules/OrderManager.lua` around line 44
**Symptom:** If a batch is created, baked, but never picked up from the oven (player disconnects, or it expires), the entry in postOvenScores persists for the entire session. On busy servers with many batches, this accumulates.
**Fix:** Clear `postOvenScores[batchId]` in the batch cleanup/expiry path.

### m3 — KDS TV full rebuild every 5 seconds
**File:** `src/ServerScriptService/Minigames/DressStationServer.server.lua` lines 207–220
**Symptom:** TV SurfaceGui clears and rebuilds all rows every 5 seconds regardless of whether order state changed. Minor performance concern on servers with many orders.
**Fix:** Track a dirty flag; only rebuild when orders actually change.

### m4 — HUD order tracking uses string display names (not order IDs)
**File:** `src/StarterGui/HUD/HUDController.client.lua`
**Symptom:** If two NPCs order the same cookie type simultaneously, the HUD shows "Chocolate Chip x2" as an aggregate. When one order is cancelled, the string-match FIFO removal may remove the wrong entry if Unicode normalization of the `×` character ever fails.
**Fix:** Track orders by orderId (or npcId) in the HUD, not by display string.

### m5 — CalculatePayout allows negative stars/comboStreak inputs
**File:** `src/ServerScriptService/Core/EconomyManager.server.lua` lines 31–45
**Symptom:** No validation of input parameters. Negative stars produce negative accuracy multipliers. Negative comboStreak subtracts from payout. Won't happen in normal play but any caller bug could silently produce wrong payouts.
**Fix:** Clamp inputs: `stars = math.clamp(stars or 0, 1, 5)`, `comboStreak = math.max(0, comboStreak or 0)`.

### m6 — BakeryName has no length or content validation
**File:** `src/ServerScriptService/Core/PlayerDataManager.server.lua` line 218
**Symptom:** Client can set any string as bakery name — empty, 999 chars, or containing special characters. If displayed in SurfaceGui without TextTruncate, overflows UI.
**Fix:** `name = string.sub(tostring(name), 1, 24)` before assigning. Reject empty strings.

### m7 — No escape path on minigames (mobile critical)
**Files:** All four minigame client scripts
**Symptom:** No "exit" or "give up" button in any minigame. If a player's session hangs (server doesn't fire EndMinigame), player is stuck with WalkSpeed=0 and JumpHeight=0 indefinitely. On mobile, there's no keyboard escape.
**Fix:** Add a small "Exit" TextButton (top-right corner) that fires a `CancelMinigame` remote. Server should cancel the session and restore humanoid values.

### m8 — Variety order validation doesn't check stock >= packSize
**File:** `src/ServerScriptService/Core/PersistentNPCSpawner.server.lua` lines 246–298
**Symptom:** Variety pack can be assigned even when each cookie type only has 1 in the warmer. Order is for e.g., 2 of 3 types, but stock per type is only 1. Dress station then fails to fill the order completely.
**Fix:** When building variety order, check `warmer_count[type] >= assigned_qty_per_type`.

### m9 — No SafeAreaInsets on any UI
**All UI files**
**Symptom:** On notched/punched-hole iPhones and Android devices, UI elements at the screen edges/top/bottom may be obscured by the system UI or camera cutout.
**Fix:** Wrap top-positioned UI in `GuiService:GetGuiInset()` offset, or use `ScreenGui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.FullscreenExtension`.

### m10 — Tutorial advance() has no step boundary check
**File:** `src/ServerScriptService/Core/TutorialController.server.lua` lines 76–80
**Symptom:** `session.step` is incremented unconditionally. If step is somehow called when already at 10, it can reach 11, 12, etc. Subsequent step-match guards never fire, leaving tutorial in a hung state.
**Fix:** `if session.step >= 10 then return end` at top of advance().

---

## 5. What is Working Well

1. **RemoteManager centralized registry** — all remotes pre-declared server-side, no dynamic creation in loops, client can only call existing remotes. Solid foundation.
2. **OrderManager immutable state reads** — `GetBatchState()`, `GetFridgeState()`, `GetWarmerCount()` return snapshots, not live references. Prevents accidental mutations from callers.
3. **MinigameServer session anti-spam** — `activeSessions[player]` guard prevents a player starting two concurrent minigame sessions. Dough lock prevents two players grabbing the same batch.
4. **POSClient is the only responsive UI** — uses `math.min(440, ViewportSize.X - 20)` for modal width. This is the correct pattern and should be applied to all other GUIs.
5. **NPC walk-out behavior** — NPCs walk to spawn point before despawning instead of teleporting away. Clean UX.
6. **EconomyManager payout formula** — transparent multiplicative model with hard cap (3.0x). Well-structured for tuning.
7. **M7 visual polish is consistent** — gold palette, 16px UICorner, UIStroke borders, 0.2–0.3s Quad tweens applied uniformly across HUD, summary, toasts, minigames.
8. **Minigame DisplayOrder=15 is consistent** across all four minigame clients. Just needs HUD to be set explicitly to 2.
9. **PlayerDataManager save patterns** — pcall around DataStore operations, BindToClose for server shutdown, PlayerRemoving save on disconnect.
10. **AI frost/dress worker design** — frost worker intentionally disabled on dress orders to not consume warmer entries that players need. Good defensive design.
11. **Connection tracker (MinigameBase.NewTracker)** — prevents connection stacking on repeated minigame starts.

---

## 6. What Should Be Removed or Simplified

1. **PlayerDataManager debug override block** (lines 245–248) — remove entirely or move behind `RunService:IsStudio()` flag
2. **StaffManager debug coin grant** (lines 653–660) — same treatment
3. **`DEV_SKIP_PREOPEN`** in GameStateManager — either delete or gate behind `RunService:IsStudio()` so it can never fire in production. Leaving it as a live code path is risky even if the flag is `false`.
4. **Legacy `scripts/Workspace/*` tree** — per the audit report in the diff, this tree is outside Rojo mapping and contains dead script references to old remotes (`ShowSkillCheck`, `SetMixCamera`). Remove or archive.
5. **Duplicate order locking concepts** — `dressLocked` in DressStationServer and pending box state in OrderManager both track "who has what order." Consolidate into a single `OrderAssignmentManager` (server module) with lifecycle: `Unclaimed → Locked → Fulfilled/Expired`.
6. **`TestNPCSpawner`** (mentioned in CLAUDE.md as still needed for tutorial step 9) — this is a holdover that should be properly replaced with the BindableEvent gate in TutorialController. Audit whether it's still needed and remove the note from CLAUDE.md if not.

---

## 7. Next Coding Priorities

**Do these before inviting any external playtesters:**

1. **Remove both debug coin grants** (PlayerDataManager 245–248, StaffManager 653–660). No economy testing is valid until this is done. ~5 min.

2. **Add exclusive lock to DressStation lockOrder** — `orderLocks[orderId]` table, set on entry, cleared on completion/cancel/disconnect. Prevents two players corrupting the same order. ~30 min.

3. **Add atomic guard to TakeFromWarmers/TakeFromWarmersByType** — simplest fix is a `warmersLocked` boolean that blocks concurrent entry; if locked, retry after `task.wait(0)`. More robust: a queue pattern. ~1 hour.

4. **Validate cookieId in RequestMixStart** against active menu + player ownership. One guard, ~10 min.

5. **Add skipPreOpenRemote auth check** — either admin-only or remove the remote entirely and use a server-side DEV flag only. ~5 min.

6. **Fix HUD DisplayOrder** — set to 2 explicitly so it renders above minigames. One line. ~2 min.

7. **Fix minigame GUI widths** for mobile — apply `math.min(width, ViewportSize.X - 20)` pattern to all four. ~30 min total.

8. **Add player disconnect cleanup cascade** — `Players.PlayerRemoving` should release `dressLocked`, `orderLocks`, `activeSessions`, `ovenSession` for the disconnecting player. ~20 min.

9. **Verify SessionStats.Reset()** is called between shifts in GameStateManager. If not, add it to the EndOfDay→Intermission transition.

10. **Fix applyBakerUniform nil guard** in StaffManager — wrap in pcall or add nil check. ~2 min.

---

## 8. Playtest / QA Checklist

### Economy
- [ ] Join fresh — verify starting coins are 0 (not 50,500)
- [ ] Complete a delivery — verify coins increase by correct formula
- [ ] Hire an AI worker — verify coins are deducted; can't hire with 0 coins
- [ ] Earn coins, quit, rejoin — verify coins persisted

### Order Flow / Concurrency
- [ ] Two players simultaneously lock the same NPC order at Dress station — only one should succeed
- [ ] Two players pull from the same warmer type at the same moment — warmer count must not go negative
- [ ] Variety pack order with only 1 per type in warmers — verify order either prevented or correctly fulfilled
- [ ] Player completes mix while AI baker simultaneously mixes same type — no batch duplication
- [ ] Complete both pending variety orders out of sequence — both NPCs satisfied correctly

### Station Auth / Exploit Prevention
- [ ] Fire `RequestMixStart` with a cookieId not in the active menu — must be rejected
- [ ] Fire tutorial advancement remotes without completing minigames — tutorial must not skip
- [ ] Fire `SkipPreOpen` remote as a regular player — must be rejected or ignored in production
- [ ] Spam warmer pickup prompt — no double-box creation

### Disconnect Handling
- [ ] Player disconnects while carrying a delivery box — NPC must eventually time out (90s), not hang forever
- [ ] Player disconnects while Dress station lock is held — orderId must become reclaimable
- [ ] Player disconnects mid-minigame — station must become available to other players

### Mobile / UI
- [ ] All four minigame UIs on 375px-wide phone — no overflow
- [ ] Summary screen on 375×667 phone — no clipping
- [ ] HUD visible during all minigames (not hidden behind minigame overlay)
- [ ] All minigames have a working exit/escape path on mobile
- [ ] Challenge widgets visible and not overlapping HUD pills
- [ ] Notched iPhone — check top/bottom UI elements not obscured

### Game Loop
- [ ] Full PreOpen → Open → EndOfDay → Intermission → PreOpen cycle completes cleanly
- [ ] Employee of Shift board shows winner with correct station label at EndOfDay
- [ ] SessionStats resets properly for second shift (Employee of Shift not accumulating cross-shift)
- [ ] NPC leaves counter after COUNTER_TIMEOUT (90s) if delivery missed — no indefinite wait
- [ ] AI baker properly assigned to station, standing at correct position and height

### Progression
- [ ] Unlock a cookie via shop — persists after rejoin
- [ ] Daily challenge completes — reward granted once, not repeatedly
- [ ] Bakery name set to long string (>24 chars) — truncated, no UI overflow
