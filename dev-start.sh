#!/usr/bin/env bash
#
# Start a local Mattermost development stack: Docker dependencies, the Go
# server, and the webapp bundler.
#
# Usage:
#   ./dev-start.sh            Start everything and seed an admin user
#   ./dev-start.sh stop       Stop the server and the webapp bundler
#   ./dev-start.sh stop --all Also stop the Docker dependency containers
#   ./dev-start.sh status     Report what is currently running
#
# Overridable via environment:
#   MM_ADMIN_EMAIL, MM_ADMIN_USERNAME, MM_ADMIN_PASSWORD, MM_TEAM_NAME
#   SKIP_WEBAPP=true          Start the server only

set -euo pipefail

# Long-lived children outlive this script. Drop any descriptors inherited from
# the caller so a backgrounded server or bundler cannot hold a pipeline open
# and stall commands like `dev-start.sh | tee`.
for fd in 3 4 5 6 7 8 9; do
    eval "exec ${fd}>&-" 2>/dev/null || true
done

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_DIR="$REPO_ROOT/server"
WEBAPP_DIR="$REPO_ROOT/webapp"
LOG_DIR="$SERVER_DIR/logs"
SERVER_LOG="$LOG_DIR/dev-server.log"
WEBAPP_LOG="$LOG_DIR/dev-webapp.log"
WEBAPP_PID="$LOG_DIR/dev-webapp.pid"

SERVER_URL="http://localhost:8065"
PING_URL="$SERVER_URL/api/v4/system/ping"
CLIENT_ENTRYPOINT="$WEBAPP_DIR/channels/dist/root.html"
MMCTL="$SERVER_DIR/bin/mmctl"

MM_ADMIN_EMAIL="${MM_ADMIN_EMAIL:-admin@example.com}"
MM_ADMIN_USERNAME="${MM_ADMIN_USERNAME:-admin}"
MM_ADMIN_PASSWORD="${MM_ADMIN_PASSWORD:-Password123!}"
MM_TEAM_NAME="${MM_TEAM_NAME:-devteam}"
SKIP_WEBAPP="${SKIP_WEBAPP:-false}"

# The webapp declares node ^24 while a newer Node may be the default on PATH.
# Homebrew keeps node@24 keg-only, so prepend it rather than switching the
# system default.
NODE24_BIN="/opt/homebrew/opt/node@24/bin"

say()  { printf '\n==> %s\n' "$1"; }
info() { printf '    %s\n' "$1"; }
die()  { printf '\nERROR: %s\n' "$1" >&2; exit 1; }

require_node24() {
    if [ -x "$NODE24_BIN/node" ]; then
        PATH="$NODE24_BIN:$PATH"
        export PATH
    fi

    command -v node >/dev/null 2>&1 || die "Node is not installed. Try: brew install node@24"

    local major
    major="$(node -p 'process.versions.node.split(".")[0]')"
    if [ "$major" != "24" ]; then
        die "Node $(node -v) is active but the webapp requires Node 24.
       Install it with: brew install node@24"
    fi
}

require_docker() {
    command -v docker >/dev/null 2>&1 || die "Docker is not installed or not on PATH."
    docker info >/dev/null 2>&1 || die "Docker is installed but not running. Start Docker Desktop and retry."
}

# A Homebrew or Postgres.app instance bound to loopback:5432 shadows the
# Docker container, and the server fails with: role "mmuser" does not exist.
require_no_host_postgres() {
    local pids
    pids="$(lsof -nP -iTCP:5432 -sTCP:LISTEN 2>/dev/null | awk 'NR > 1 && $1 ~ /^postgres/ { print $2 }' | sort -u)"
    [ -z "$pids" ] && return 0

    printf '\nERROR: A non-Docker PostgreSQL is listening on port 5432:\n\n' >&2
    local pid
    for pid in $pids; do
        ps -p "$pid" -o pid=,comm=,args= >&2 || true
    done
    cat >&2 <<'EOF'

Mattermost connects to localhost:5432 and would reach that server instead of
the Docker container, which is the only one with the mmuser role.

Stop it first, for example:

    brew services stop postgresql@17

Then re-run this script.
EOF
    exit 1
}

wait_for_ping() {
    local timeout=${1:-180} elapsed=0
    while [ "$elapsed" -lt "$timeout" ]; do
        if curl -fsS -m 3 "$PING_URL" >/dev/null 2>&1; then
            return 0
        fi
        sleep 2
        elapsed=$((elapsed + 2))
    done
    return 1
}

wait_for_client_bundle() {
    local timeout=${1:-600} elapsed=0
    while [ "$elapsed" -lt "$timeout" ]; do
        if [ -f "$CLIENT_ENTRYPOINT" ]; then
            return 0
        fi
        sleep 3
        elapsed=$((elapsed + 3))
    done
    return 1
}

server_running() { curl -fsS -m 3 "$PING_URL" >/dev/null 2>&1; }

# `npm run run` fans out through concurrently, so the tree has no single stable
# command line. Track the launcher pid and fall back to matching the runner.
webapp_running() {
    if [ -f "$WEBAPP_PID" ] && kill -0 "$(cat "$WEBAPP_PID")" 2>/dev/null; then
        return 0
    fi
    pgrep -f 'scripts/run.mjs' >/dev/null 2>&1
}

start_server() {
    if server_running; then
        say "Server already responding at $SERVER_URL"
        return
    fi

    say "Starting Docker dependencies and the Mattermost server"
    info "log: $SERVER_LOG"
    mkdir -p "$LOG_DIR"

    # run-server depends on start-docker and backgrounds the Go process itself.
    ( cd "$SERVER_DIR" && make run-server ) </dev/null >>"$SERVER_LOG" 2>&1

    info "waiting for $PING_URL"
    if ! wait_for_ping 240; then
        printf '\n--- last 40 lines of %s ---\n' "$SERVER_LOG" >&2
        tail -n 40 "$SERVER_LOG" >&2 || true
        die "Server did not become healthy. See $SERVER_LOG"
    fi
    info "server is up"
}

start_webapp() {
    if [ "$SKIP_WEBAPP" = "true" ]; then
        say "Skipping webapp (SKIP_WEBAPP=true)"
        return
    fi

    if [ ! -d "$WEBAPP_DIR/node_modules" ]; then
        say "Installing webapp dependencies (first run, takes a few minutes)"
        ( cd "$WEBAPP_DIR" && npm install )
    fi

    if webapp_running; then
        say "Webapp bundler already running"
    else
        say "Starting webapp bundler"
        info "log: $WEBAPP_LOG"
        mkdir -p "$LOG_DIR"
        # Detach every descriptor so the bundler never holds the caller's
        # stdout open, which would stall pipelines like `dev-start.sh | tee`.
        ( cd "$WEBAPP_DIR" && nohup npm run run </dev/null >>"$WEBAPP_LOG" 2>&1 & echo $! >"$WEBAPP_PID" )
        sleep 3
        if webapp_running; then
            info "bundler pid $(cat "$WEBAPP_PID")"
        else
            printf '\n--- last 20 lines of %s ---\n' "$WEBAPP_LOG" >&2
            tail -n 20 "$WEBAPP_LOG" >&2 || true
            die "Webapp bundler exited immediately. See $WEBAPP_LOG"
        fi
    fi

    if [ ! -f "$CLIENT_ENTRYPOINT" ]; then
        info "waiting for the first bundle (this takes several minutes)"
        if ! wait_for_client_bundle 900; then
            printf '\n--- last 40 lines of %s ---\n' "$WEBAPP_LOG" >&2
            tail -n 40 "$WEBAPP_LOG" >&2 || true
            die "Webapp bundle was not produced. See $WEBAPP_LOG"
        fi
    fi
    info "client bundle ready"
}

# mmctl --local talks to the server over a unix socket, so this must run after
# the server is healthy. Both commands are no-ops once the records exist.
seed_admin() {
    [ -x "$MMCTL" ] || return 0

    say "Ensuring admin user and team exist"

    if "$MMCTL" --local user search "$MM_ADMIN_USERNAME" >/dev/null 2>&1; then
        info "user $MM_ADMIN_USERNAME already exists"
    else
        "$MMCTL" --local user create \
            --email "$MM_ADMIN_EMAIL" \
            --username "$MM_ADMIN_USERNAME" \
            --password "$MM_ADMIN_PASSWORD" \
            --system-admin \
            --email-verified \
            --disable-welcome-email >/dev/null 2>&1 \
            && info "created user $MM_ADMIN_USERNAME" \
            || info "could not create user (may already exist)"
    fi

    "$MMCTL" --local team create \
        --name "$MM_TEAM_NAME" \
        --display-name "Dev Team" \
        --email "$MM_ADMIN_EMAIL" >/dev/null 2>&1 \
        && info "created team $MM_TEAM_NAME" \
        || info "team $MM_TEAM_NAME already exists"

    "$MMCTL" --local team users add "$MM_TEAM_NAME" "$MM_ADMIN_EMAIL" >/dev/null 2>&1 || true

    unlock_admin
}

# Mattermost locks an account after repeated bad passwords, and neither mmctl
# nor the reset endpoint can clear it without an authenticated session. On a
# throwaway dev database, resetting the counter directly is the way out.
unlock_admin() {
    local locked
    locked="$(docker exec -e PGPASSWORD=mostest mattermost-postgres \
        psql -U mmuser -d mattermost_test -h 127.0.0.1 -tAc \
        "SELECT failedattempts FROM users WHERE username = '$MM_ADMIN_USERNAME';" 2>/dev/null | tr -d '[:space:]')"

    if [ -n "$locked" ] && [ "$locked" != "0" ]; then
        docker exec -e PGPASSWORD=mostest mattermost-postgres \
            psql -U mmuser -d mattermost_test -h 127.0.0.1 -q -c \
            "UPDATE users SET failedattempts = 0 WHERE username = '$MM_ADMIN_USERNAME';" >/dev/null 2>&1 \
            && info "cleared $locked failed login attempt(s) on $MM_ADMIN_USERNAME"
    fi
}

do_start() {
    require_docker
    require_no_host_postgres
    [ "$SKIP_WEBAPP" = "true" ] || require_node24

    start_server
    start_webapp
    seed_admin

    cat <<EOF

==> Mattermost is ready

    URL:      $SERVER_URL
    Login:    $MM_ADMIN_EMAIL
    Password: $MM_ADMIN_PASSWORD

    Server log: $SERVER_LOG
    Webapp log: $WEBAPP_LOG

    Stop with: ./dev-start.sh stop

EOF
}

do_stop() {
    say "Stopping the Mattermost server"
    ( cd "$SERVER_DIR" && make stop-server ) || true

    say "Stopping the webapp bundler"
    if [ -f "$WEBAPP_PID" ]; then
        kill "$(cat "$WEBAPP_PID")" 2>/dev/null || true
        rm -f "$WEBAPP_PID"
    fi
    pkill -f 'scripts/run.mjs' 2>/dev/null || true
    pkill -f 'webpack --progress --watch' 2>/dev/null || true

    local waited=0
    while webapp_running && [ "$waited" -lt 10 ]; do
        sleep 1
        waited=$((waited + 1))
    done
    webapp_running && info "bundler still running" || info "bundler stopped"

    if [ "${1:-}" = "--all" ]; then
        say "Stopping Docker dependencies"
        ( cd "$SERVER_DIR" && make stop-docker ) || true
    else
        info "Docker containers left running (use 'stop --all' to stop them)"
    fi
}

do_status() {
    say "Status"
    server_running && info "server:    up ($SERVER_URL)" || info "server:    down"
    webapp_running && info "bundler:   running" || info "bundler:   not running"
    [ -f "$CLIENT_ENTRYPOINT" ] && info "bundle:    present" || info "bundle:    missing"

    if docker info >/dev/null 2>&1; then
        local containers
        containers="$(docker ps --filter 'name=mattermost-' --format '{{.Names}}' | paste -sd ' ' -)"
        info "containers: ${containers:-none}"
    else
        info "containers: docker not running"
    fi
    printf '\n'
}

case "${1:-start}" in
    start)  do_start ;;
    stop)   do_stop "${2:-}" ;;
    status) do_status ;;
    *)      die "Unknown command: $1 (expected start, stop, or status)" ;;
esac
