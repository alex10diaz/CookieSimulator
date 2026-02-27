# Repo Cohesion Audit — CookieSimulator

**Status:** Living architecture guide for Claude-assisted development.
**Update this file whenever ownership boundaries or critical flows change.**

---

## A) Authority Model (Server vs Client)

### Server authoritative
- Game phases / timers
- Production state transitions
- Batch lifecycle and station advancement
- Box creation/delivery resolution
- Rewards and player progression

### Client responsibilities
- Render UI from server state
- Run minigame UX interaction
- Send user intents and minigame outcomes

### Client must never be authority for
- Order queue truth
- Reward amounts
- Final production state
- Delivery success decisions

---

## B) Source of Truth Mapping

- **Game phase:** `GameStateManager`
- **Production lifecycle:** `OrderManager`
- **Minigame session orchestration:** `MinigameServer`
- **Delivery + payout:** consolidate into one delivery/economy path
- **POS queue:** server-generated and server-synced snapshots/events

---

## C) Current Known Risks

1. Duplicate ownership in fridge/oven handoff path can cause desync.
2. Duplicate delivery processing paths can cause inconsistent outcomes.
3. POS queue and open-state wiring are not fully integrated to phase/order systems.
4. NPC order generation pipeline is incomplete.
5. Some scripts indicate client/server responsibility confusion.

---

## D) Immediate Priorities (Top 3)

1. Finish and harden core loop (`mix -> ... -> dress`) with strict session/state guards.
2. Remove duplicate ownership in critical flows (fridge/oven and delivery).
3. Define server-driven queue/event contract before POS/NPC expansion.

---

## E) Core Loop Acceptance Checklist

- Picker starts correct cookie mix session.
- Mix transitions only to dough.
- Dough inserts into proper fridge.
- Fridge pull reserves one valid oven batch.
- Oven result applies only to valid server session.
- Frost-required cookies route through frost.
- Non-frost cookies skip frost correctly.
- Dress creates exactly one box and clears pending states.
- No normal-flow session mismatch warnings.

---

## F) Daily 3-Minute Smoke Test

1. Start 1-player test.
2. Run one frost cookie through full loop.
3. Run one non-frost cookie through full loop.
4. Verify no session mismatch warnings.
5. Verify one box per completed dress.

---

## G) Claude Session Contract (Paste each session)

```md
Read docs/plans/repo-cohesion-audit.md first.
Treat it as authoritative architecture guidance.

Today scope: [feature/bug]
Allowed files only: [file list]
Do not rename remotes/stage names.
Keep server authoritative for critical state.
Add concise logs only around modified flow.
Provide: root cause, patch summary, and 3-minute manual test.
```

If you don't want to remember this each time, use:

- `docs/plans/claude-session-starter.md` (copy/paste starter blocks)
