---
name: test-guardian
description: >-
  Selects and runs the right Mattermost tests from a git diff. Use for TestGuardian,
  pre-PR checks, or when the user asks to add coverage for frontend, API, or backend
  changes. Maps webapp/channels to Jest, server/channels/api4 to Go API tests, and
  other server/ Go to make test-server. Does not run the full Playwright suite unless
  the change is user-visible UI in webapp.
---

# Test Guardian

Run **diff-scoped** tests for this monorepo. Do not run the universe.

## Choose a surface

From `git diff` (staged + unstaged + compared to the PR base if known):

| Paths in the diff | Surface | Command |
|---|---|---|
| `webapp/channels/**`, `webapp/platform/**` | Frontend | `cd webapp && npm run test --workspace=channels` (or a focused Jest file for the changed component) |
| `server/channels/api4/**` | API | Go tests in the `api4` package only, e.g. `cd server && go test ./channels/api4 -count=1` |
| `server/**/*.go` excluding only docs | Backend | Prefer the smallest package that contains the change. Last resort: `cd server && make test-server` |
| `e2e-tests/playwright/**` or clearly user-visible UI in `webapp/channels/src/components/**` | E2E | One named Playwright spec, Chrome only: `cd e2e-tests/playwright && npm run test -- <name> --project=chrome` |

If the diff spans multiple rows, run each matching surface. If it spans none, say so and stop.

## Hard rules for this repo

- Never run `go mod tidy`. Use `make modules-tidy` from `server/` if modules must change.
- Never run the full Playwright matrix (Firefox, iPad, visual, Percy) in this skill.
- Prefer a single package or a single test file over `make test`.
- If tests fail, report the first failure and the command you ran. Do not silently skip.

## Output

1. Surfaces selected and why (paths).
2. Commands run.
3. Pass / fail.
4. Gaps: behavior you changed that still has no test.
