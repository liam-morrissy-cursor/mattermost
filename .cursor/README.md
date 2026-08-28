# Cursor Cloud Agent Environment

This directory defines the checked-in Cloud Agent environment for this repository. Cursor resolves `.cursor/environment.json` before personal or team saved environments, so this replaces the snapshot-dependent `/onboard` flow for agents started from this repo.

The Docker build context is `.cursor/` (omit `context` in `environment.json`; `.` would mean the whole monorepo). The Dockerfile does not copy the repository; Cursor checks out the requested commit at runtime.

This fork does **not** declare `mattermost/enterprise` as a repository dependency. That repo is private and the Cloud Build would fail at clone. Team-edition `make setup-go-work` is enough for most Cloud Agent tasks.

## What Is Baked Into The Image

- Ubuntu 24.04.
- Docker CE 28.5.2 with `fuse-overlayfs` and `iptables-legacy`, matching Cursor's Docker-in-Cloud guidance for complex compose setups.
- Go 1.26.4 from `server/.go-version`, copied from the official `golang:1.26.4-bookworm` image.
- Node 24.11.1/npm 11 matching `.nvmrc` and `webapp/package.json`, copied from the official `node:24.11.1-bookworm` image into nvm's tree so `nvm use` still works.
- Browser runtime libraries for the Playwright e2e suite.
- AWS CLI v2 for S3 uploads, installed **best effort** — nothing here needs it, so a failed download logs a warning instead of failing the build.
- Common Mattermost build/test tools: `make`, `jq`, `xmlsec1`, `pgloader`, Git LFS, GitHub CLI, Python 3, and build essentials.

## Why toolchains come from Docker Hub

The Cloud Build network reaches some upstream hosts and not others. `cli.github.com` failed with `curl` exit 35, while `archive.ubuntu.com` and `download.docker.com` succeeded in the same build. Probing that allowlist shows `go.dev`, `nodejs.org`, and `awscli.amazonaws.com` blocked the same way `cli.github.com` is.

So the build only depends on hosts it must already reach: the registry (for `ubuntu:24.04`), `download.docker.com`, and `github.com` (Cursor clones this repo from there). Go and Node come from official Docker Hub images, which carry the same upstream binaries. `gh` comes from `github.com/cli/cli` releases.

If you bump `GO_VERSION` or `NODE_VERSION`, the matching `-bookworm` tag must exist on Docker Hub. The build self-checks both versions and fails loudly if they drift.

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
