# Claude Session Starter (Copy/Paste Every Session)

Use this file so you don't need to remember the process.

---

## 1) Paste this first

```md
Read docs/plans/repo-cohesion-audit.md first.
Treat it as authoritative architecture guidance.

Before coding, confirm you read it and list:
1) authority boundaries,
2) source-of-truth system for the flow being changed,
3) top regression risks.

Today scope: [feature/bug]
Allowed files only:
- [path]
- [path]

Hard constraints:
- Do not rename remotes/stage names unless explicitly requested.
- Keep server authoritative for critical state.
- Do not refactor unrelated systems.
- Add concise logs only around modified flow.

Deliverables:
- Root cause
- Patch summary
- Risk notes
- 3-minute manual test plan
```

---

## 2) Paste this after Claude finishes code changes

```md
Now validate against docs/plans/repo-cohesion-audit.md:
- Run the Core Loop Acceptance Checklist relevant to this change.
- Provide explicit pass/fail per item.
- Provide the Daily 3-Minute Smoke Test steps and expected outcomes.
```

---

## 3) Quick rule

If you are in a hurry, do only this:
1. Paste section 1
2. Fill scope + allowed files
3. Do not let Claude start coding until it confirms audit understanding
4. Paste section 2 after patch

