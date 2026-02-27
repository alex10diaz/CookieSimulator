# Claude Implementation Guide for CookieSimulator

**Purpose:** Give Claude a stable, repeatable way to help on this repo without causing architecture drift.

This guide is designed to be used together with your existing planning docs and milestone flow.

---

## 1) What to Implement in Claude (Recommended Setup)

Use a **3-layer guidance stack**:

1. **Master Architecture Guide (primary source)**
   - Repository-level rules (authority boundaries, source of truth, event ownership).
   - Prevents Claude from making isolated fixes that break cross-system behavior.

2. **Core Loop Done Definition (execution gate)**
   - Concrete pass criteria for `mix -> dough -> fridge -> oven -> (frost?) -> dress`.
   - Used to determine whether a change is accepted.

3. **Daily Smoke Test (stability loop)**
   - Fast manual regression routine after each Claude edit.
   - Catches session, state, and branching regressions immediately.

---

## 2) Claude Rules to Paste Into Your Session Context

Paste this at the top of Claude sessions for this project:

```md
You are working on CookieSimulator (Roblox/Luau).

Hard constraints:
- Preserve stage names: mix, dough, oven, frost, dress.
- Do not rename existing remote names unless explicitly requested.
- Keep server authoritative for game-critical state.
- Do not move business logic into client scripts.
- Change only requested scope; do not refactor unrelated systems.
- Add concise debug logs around changed logic.

Architecture rules:
- Game phase state is server-owned.
- Production lifecycle state is server-owned.
- Delivery resolution and reward payout are server-owned.
- Client UI must render server-provided state (no client-authoritative queue logic).

Output rules:
- Explain what changed, why, and what could break.
- Provide a short manual test checklist for the modified flow.
```

---

## 3) Claude Prompt Templates (Copy/Paste)

### A) Single-Feature Prompt (Best default)

```md
Task: Implement ONLY [feature name] in CookieSimulator.

Scope:
- Touch only: [list files]
- Do not edit unrelated systems.

Requirements:
- Preserve existing remotes and stage names.
- Keep server authoritative.
- Add debug prints only around new/modified flow.

Acceptance:
- [bullet criteria]

After changes:
1) Show exactly what files changed.
2) Explain end-to-end flow.
3) Provide a 2-3 minute manual test plan.
```

### B) Bugfix Prompt (Regression-focused)

```md
Fix this bug only: [bug statement]

Context:
- Expected behavior: [expected]
- Actual behavior: [actual]

Constraints:
- Minimal patch.
- No broad refactors.
- Preserve current API/remotes/stage names.

Deliverables:
- Root cause.
- Patch summary.
- Risk notes.
- Fast repro + validation steps.
```

### C) Refactor Prompt (When you intentionally refactor)

```md
Refactor [system] for cohesion.

Goals:
- Remove duplicate logic.
- Keep behavior unchanged.
- Improve separation of concerns.

Constraints:
- Do not change external behavior without listing migration impact.
- Keep remotes backward-compatible in this patch.

Deliverables:
- Before/after architecture summary.
- List of moved responsibilities.
- Regression checklist.
```

---

## 4) How to Integrate This Into Claude Code in Practice

Use this operating sequence every dev session:

1. **Start Session Context**
   - Paste Section 2 rules.
   - Paste current milestone and exact objective for this session.

2. **Give Narrow Scope**
   - Explicitly list allowed files.
   - Tell Claude to avoid unrelated edits.

3. **Require Validation Output**
   - Ask for manual test steps and edge cases.
   - Ask Claude to identify likely regressions before you run.

4. **Run Smoke Test Immediately**
   - Do not batch many Claude patches before testing.
   - Validate one loop (frost cookie + non-frost cookie).

5. **Log Decision**
   - Save accepted changes + known follow-ups in your planning doc.

### Make this "forget-proof" (recommended)

If you know you'll forget the sequence, keep a single copy/paste starter file and use it every session.

1. Open `docs/plans/claude-session-starter.md`
2. Copy the full block into Claude at the start of the session
3. Fill in today's scope and allowed files
4. Do not start coding until Claude confirms it read `repo-cohesion-audit.md`

This removes memory overhead and makes your process consistent even on quick sessions.

For extra reliability, keep a root `CLAUDE-COOKIESIM.md` file in the repo that points Claude to the audit + starter docs at session start.

---

## 5) Suggested “Definition of Done” for Core Mechanic Phase

A change is done only when all pass:

- Picker reliably starts mix with selected cookie.
- Mix result transitions only to dough.
- Dough result inserts into correct fridge.
- Fridge pull reserves exactly one batch for oven.
- Oven score applies only to valid session.
- Frost-required cookies route through frost.
- Non-frost cookies skip frost and remain dress-ready.
- Dress creates one deliverable box and clears pending state.
- No session mismatch warnings in normal flow.
- Player-leave cleanup does not leave stale reserved sessions.

---

## 6) Recommended File to Keep as Claude’s “North Star”

Create/maintain a single file in the repo for Claude to always reference first:

- `docs/plans/repo-cohesion-audit.md`

Put in it:
- Authority model (server vs client)
- Source-of-truth mapping per system
- Active known risks
- Immediate next 3 priorities
- Smoke test checklist

Then start Claude sessions with:

```md
Read docs/plans/repo-cohesion-audit.md first.
Use it as authoritative architecture guidance for all changes in this session.
```

---

## 7) Anti-Drift Rules (High Value)

Tell Claude these rules each session:

- “If you detect duplicated ownership (same flow handled by two systems), stop and report before coding.”
- “If a client can forge a game-critical result, mark as authority risk.”
- “If you need to rename remotes or stage names, ask for explicit approval first.”
- “Prefer additive migration over breaking replacement unless requested.”

---

## 8) Session Example You Can Use Today

```md
Read docs/plans/repo-cohesion-audit.md first.

Today’s task: stabilize Mix -> Dough handoff only.

Allowed files:
- src/ServerScriptService/Minigames/MinigameServer.server.lua
- src/ReplicatedStorage/Modules/OrderManager.lua
- src/StarterPlayer/StarterPlayerScripts/Minigames/MixMinigame.client.lua

Constraints:
- Preserve remote names and stage names.
- No POS/NPC changes.
- Add minimal logs for startSession/endSession mix+dough path.

Deliver:
- Root cause(s) found
- Exact patch summary
- Manual test steps (3 minutes)
- Possible regressions
```

---

## 9) Why This Setup Works

- Prevents broad, risky edits from ambiguous prompts.
- Keeps Claude focused on one vertical slice at a time.
- Protects multiplayer correctness via server authority boundaries.
- Makes every session measurable (pass/fail via done definition + smoke test).
