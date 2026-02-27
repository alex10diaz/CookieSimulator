# Claude Quick Prompts (Ready to Paste)

Use these with `docs/plans/repo-cohesion-audit.md` as the architecture authority.

---

## 1) Start any coding session

```md
Read docs/plans/repo-cohesion-audit.md first.
Treat it as authoritative architecture guidance.

Before coding, confirm:
1) authority boundaries,
2) source-of-truth system for this change,
3) top regression risks.

Today scope: [feature/bug]
Allowed files only:
- [path]
- [path]

Constraints:
- Keep server authoritative for critical state.
- Do not rename remotes/stage names unless requested.
- Do not refactor unrelated systems.

Deliverables:
- Root cause
- Patch summary
- Risk notes
- 3-minute manual test plan
```

---

## 2) Feature implementation prompt

```md
Implement ONLY: [feature]

Allowed files:
- [path]
- [path]

Acceptance criteria:
- [criterion 1]
- [criterion 2]

Output:
- files changed
- end-to-end flow explanation
- regressions to watch
- manual validation steps
```

---

## 3) Bugfix prompt

```md
Fix ONLY this bug: [bug]

Expected:
[expected behavior]

Actual:
[actual behavior]

Constraints:
- minimal patch
- no unrelated edits
- preserve API/remotes/stage names

Output:
- root cause
- patch summary
- risk notes
- reproducible test steps
```

---

## 4) Post-change validation prompt

```md
Validate against docs/plans/repo-cohesion-audit.md:
- Run the relevant Core Loop Acceptance Checklist items.
- Provide explicit pass/fail for each item.
- Provide the Daily 3-Minute Smoke Test and expected outcomes.
```
