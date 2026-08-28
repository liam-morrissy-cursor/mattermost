# Cursor Cloud Agent Environment

This directory defines the checked-in Cloud Agent environment for this repository. Cursor resolves `.cursor/environment.json` before personal or team saved environments, so this replaces the snapshot-dependent `/onboard` flow for agents started from this repo.

The Docker build context is `.cursor/` (omit `context` in `environment.json`; `.` would mean the whole monorepo). The Dockerfile does not copy the repository; Cursor checks out the requested commit at runtime.

This fork does **not** declare `mattermost/enterprise` as a repository dependency. That repo is private and the Cloud Build would fail at clone. Team-edition `make setup-go-work` is enough for most Cloud Agent tasks.

## What Is Baked Into The Image

- Ubuntu 24.04.
- Docker CE 28.5.2 with `fuse-overlayfs` and `iptables-legacy`, matching Cursor's Docker-in-Cloud guidance for complex compose setups.
- Go 1.26.4 from `server/.go-version`.
- Node 24.11.1/npm 11 via nvm, matching `.nvmrc` and `webapp/package.json`.
- Browser runtime libraries for the Playwright e2e suite.
- AWS CLI v2 for S3 uploads.
- Common Mattermost build/test tools: `make`, `jq`, `xmlsec1`, `pgloader`, Git LFS, GitHub CLI (from GitHub releases, not `cli.github.com` apt), Python 3, and build essentials.

`gh` is installed from `github.com/cli/cli` releases. The builder used by Cloud Agents fails TLS to `cli.github.com` (`curl` exit 35).

## Runtime Hooks

- `cloud-agent-install.sh` runs after Cursor checks out the repo. It refreshes nvm, hydrates Go modules (`make setup-go-work` + `go mod download`), and continues without enterprise if that checkout is missing. Webapp `node_modules` and Playwright `npm ci` are **skipped by default**.
- `cloud-agent-start.sh` materializes `.cursor/cursor.md` as `.cursor/AGENTS.md`, fixes current-session Docker socket access, starts Docker, waits until `docker info` and `docker compose version` succeed, then logs in to Docker Hub when credentials are configured.

## Useful env vars

Set these in [Cloud Agents → this environment → Secrets](https://cursor.com/dashboard/cloud-agents) if you need to change the defaults. They are not in Settings → Teams.

| Variable | Default | Meaning |
|---|---|---|
| `CLOUD_AGENT_FULL_DEPS` | unset | `true` hydrates webapp + Playwright |
| `CLOUD_AGENT_SKIP_WEBAPP_DEPS` | `true` | Skip webapp unless `CLOUD_AGENT_FULL_DEPS` |
| `CLOUD_AGENT_SKIP_PLAYWRIGHT_DEPS` | `true` | Skip Playwright unless `CLOUD_AGENT_FULL_DEPS` |
| `CLOUD_AGENT_SKIP_GO_DEPS` | `false` | Skip Go module download |
| `CLOUD_AGENT_SKIP_ENTERPRISE` | `false` | Silence the missing-enterprise log (missing EE no longer fails the hook) |

## Expected Secrets

Optional, same Secrets tab:

- AWS: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_S3_BUCKET_NAME`
- Docker Hub: `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN` (mark the token **redacted**). Needed only if the agent runs `make start-docker` and anonymous Hub pulls rate-limit.
