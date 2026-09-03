#!/usr/bin/env bash
# Publish-path smoke: start the sidecar, send one JSON request, require a JSON array.
set -euo pipefail

SIDECAR="${1:?usage: sidecar-smoke.sh <sidecar-binary>}"

if [[ ! -x "$SIDECAR" && ! -f "$SIDECAR" ]]; then
  echo "sidecar binary not found: $SIDECAR" >&2
  exit 1
fi

if [[ -z "${DOTNET_ROOT:-}" ]]; then
  dotnet_bin="$(command -v dotnet)"
  DOTNET_ROOT="$(dirname "$(readlink -f "$dotnet_bin")")"
  export DOTNET_ROOT
fi

response="$(printf '%s\n' '{"text":"hello","timeZoneOffset":0}' | timeout 15 "$SIDECAR")"
printf '%s\n' "$response"

python3 - "$response" <<'PY'
import json
import sys

data = json.loads(sys.argv[1])
if not isinstance(data, list):
    raise SystemExit(f"expected JSON array, got {type(data).__name__}: {data!r}")
if not data:
    raise SystemExit("expected a non-empty SearchParams array for text=hello")
print("sidecar spawn smoke: ok")
PY
