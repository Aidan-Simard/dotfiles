#!/usr/bin/env bash
# bridge.sh — forward a pi tool proposal into code-preview.nvim.
#
# Mirrors code-preview.nvim's own bin/hook-entry.sh, minus the jq dependency
# (hook-entry.sh parses the agent payload with jq; here the payload is already
# JSON produced by the pi extension, so we only need to wrap it in the RPC
# args array).
#
# Usage:
#   bridge.sh <plugin-dir> <pre|post> <payload-file> <cwd>
#
# Exit codes:
#   0  RPC attempted (stdout = handler return value, empty on abstain)
#   1  bad usage, or no reachable Neovim
set -uo pipefail

PLUGIN="${1:-}"
EVENT="${2:-}"
PAYLOAD="${3:-}"
CWD="${4:-}"

[[ -z "$PLUGIN" || -z "$EVENT" || -z "$PAYLOAD" ]] && exit 1
[[ -r "$PAYLOAD" ]] || exit 1

case "$EVENT" in
  pre)
    MOD="code-preview.pre_tool"
    ;;
  post)
    MOD="code-preview.post_tool"
    ;;
  *)
    exit 1
    ;;
esac

# shellcheck source=/dev/null
source "$PLUGIN/bin/nvim-socket.sh" "$CWD" 2>/dev/null || exit 1
[[ -z "${NVIM_SOCKET:-}" ]] && exit 1

ARGS_FILE="$(mktemp "${TMPDIR:-/tmp}/pi-code-preview-args.XXXXXX")" || exit 1
trap 'rm -f "$ARGS_FILE"' EXIT

# Build [<payload>, "claudecode"] without jq. The payload is valid JSON by
# construction (JSON.stringify in index.ts). "claudecode" is the canonical
# backend: its normaliser is identity, so we send the canonical tool shape.
{ printf '['; cat "$PAYLOAD"; printf ',"claudecode"]'; } >"$ARGS_FILE"

OUT="$(nvim --server "$NVIM_SOCKET" --remote-expr \
  "luaeval(\"require('code-preview.rpc').dispatch('$MOD', 'handle', '$ARGS_FILE')\")" 2>/dev/null)"
RC=$?

# post is fire-and-forget; pre prints the emitter's bytes (the permission
# decision envelope) which the extension inspects to decide whether to gate.
if [[ "$EVENT" == "pre" ]]; then
  printf '%s' "$OUT"
fi

exit "$RC"
