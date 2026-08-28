# AGENTS.md

Explicitly import subdirectory instruction files that must always be in context:
@server/AGENTS.md

## Pull Requests

When creating a pull request, follow `.github/PULL_REQUEST_TEMPLATE.md` exactly:

- Remove all `<!-- -->` comments.
- Omit sections that are not applicable (Ticket Link, Screenshots) — do not write N/A, just remove the header.
- The `#### Release Note` header and its "```release-note" fenced code block **must always be present** (WITHOUT escaping the ``` characters). Write `NONE` if the change has no API, schema, UI, or breaking changes.

## Cursor Cloud Agents

This repository has a checked-in Cloud Agent environment under `.cursor/`. Docker is started by `.cursor/scripts/cloud-agent-start.sh`; if Docker is unavailable in Cloud, treat that as an environment failure rather than falling back to snapshot assumptions.

The environment builds as team edition. `mattermost/enterprise` is not a multi-repo dependency, so no enterprise checkout exists in Cloud and `BUILD_ENTERPRISE_READY` resolves to `false`. Do not assume enterprise-only packages, builds, or tests are available; the install hook never clones or symlinks enterprise.

The install hook skips webapp and Playwright dependencies by default to keep builds fast. If a task needs `webapp/node_modules` or Playwright browsers, set `CLOUD_AGENT_FULL_DEPS=true` on the environment, or install them in-task. Go modules are always hydrated.

