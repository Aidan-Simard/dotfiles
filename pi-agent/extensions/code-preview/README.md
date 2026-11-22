# code-preview bridge for pi

Review pi's `edit` and `write` tool calls as native Neovim diffs, **before they
touch disk**, using [Cannon07/code-preview.nvim](https://github.com/Cannon07/code-preview.nvim).

```
pi (terminal)                                  Neovim
  edit/write proposed
        |
   tool_call ──→ bridge.sh ──→ nvim RPC ──→ code-preview.pre_tool.handle()
        |                                        | shows diff tab
        |                                        | <leader>da accept
        |                                        | <leader>dr reject
        |←──── decision.json (polled) ────────────|
   Accept ──→ tool runs ──→ tool_result ──→ post_tool.handle()  (closes diff)
   Reject ──→ { block: true } ──────────────→ post_tool.handle()  (closes diff)
```

**You accept or reject in Neovim**, on the diff itself. pi has no built-in
approval step and code-preview has no UI of its own, so `review.lua` adds
buffer-local keys to the diff tab and writes your choice to a file the
extension polls. Closing the preview without deciding counts as a reject.

If no Neovim is reachable, code-preview abstains and the tool call runs
untouched — the same fallback the plugin uses for its native agents.

## Requirements

- [code-preview.nvim](https://github.com/Cannon07/code-preview.nvim) installed in
  Neovim and `require("code-preview").setup()` called
- Neovim >= 0.10 running with its cwd at (or above) the project you run pi in
- `bash`, plus a `nvim` binary. `bridge.sh` uses `nvim` from `PATH` when
  present, then `$CODE_PREVIEW_NVIM_BIN`, then common install locations
  (`/opt/nvim/bin`, `/usr/local/bin`, `/usr/bin`, `~/.local/bin`)
- **No `jq` needed** — this bridge bypasses `bin/hook-entry.sh` (which parses the
  agent payload with `jq`) and calls the plugin's RPC dispatcher directly

## How it maps

| pi | code-preview | notes |
|---|---|---|
| `edit` (`{path, edits:[{oldText,newText}]}`) | `MultiEdit` | pi's multi-edit → one diff per call |
| `write` (`{path, content}`) | `Write` | creates or overwrites |

`bash` is **not** intercepted. code-preview only shows neo-tree indicators for
shell writes anyway, and gating every shell command is usually unwanted.

## Review gate

When code-preview opens a preview (it reports this through its emitter output,
`"permissionDecision":"ask"`), `review.lua` puts these keys on the diff tab:

| Key | Action |
|---|---|
| `<leader>da` | accept — the tool call proceeds, diff closes after the write |
| `<leader>dr` | reject — the call is blocked, diff closes |
| `<leader>dq` | code-preview's own close diff (also counts as reject) |

No prompt appears in pi for the normal path — the decision is entirely in
Neovim. A pi dialog is only used as a fallback when the Neovim side can't be
set up (headless instance, missing `review.lua`). Set `gate: "pi"` to always
use the pi dialog, or `gate: false` to show the preview but never wait.

- If you set `diff.defer_claude_permissions = true` in code-preview's config, no
  gate appears at all — the diff is shown and the edit applies immediately.
- If `diff.visible_only = true` and the file isn't open, the preview is skipped
  but code-preview still emits the gate, so the keys land on whatever tab is
  current. Keep `visible_only` off if you rely on the gate.
- `Reject`, closing the preview, or a review timeout returns `{ block: true }`,
  so pi reports the tool call as rejected rather than writing the file.

## Config

Optional `~/.pi/agent/code-preview.json`:

```json
{
  "enabled": true,
  "gate": "nvim",
  "pluginDir": "/home/you/.local/share/nvim/lazy/code-preview.nvim",
  "timeoutMs": 15000,
  "reviewTimeoutMs": 1800000
}
```

- `gate` — `"nvim"` (default, accept/reject keys on the diff tab), `"pi"`
  (dialog in pi's TUI), or `false` (preview only, applies automatically).
  Legacy booleans work: `true` → `"pi"`, `false` → `false`.
- `reviewTimeoutMs` — how long to wait for a decision before treating the
  review as rejected (default 30 minutes)
- `pluginDir` — defaults to `$CODE_PREVIEW_NVIM`, then lazy.nvim, then
  `site/pack/*/{start,opt}`, then a few common checkout paths

## Caveats

- **Preview vs. actual write can diverge on CRLF/BOM files.** pi applies edits
  to LF-normalized, BOM-stripped content; code-preview's `MultiEdit` does a
  literal substring replace. On CRLF files the preview may differ slightly from
  what lands.
- **Unsaved buffers:** code-preview diffs against the file on disk. Save your
  buffers first (`:wa`) or the left pane is stale.
- **Parallel tool calls:** pi runs sibling calls concurrently. The extension
  serializes its review prompts, and code-preview keys diffs per file, so edits
  to different files queue up one prompt at a time.
- **Non-interactive pi** (`-p`, `--mode json`): `ctx.hasUI` is false, so no
  preview or gate — edits apply directly.
- Rejecting keeps the preview closed; there is no "accept this one, reject the
  rest" bulk mode.

## Install / reload

Source of truth: `pi-agent/extensions/code-preview/` in the dotfiles repo.
`./apply.sh` copies it to `~/.pi/agent/extensions/` (auto-discovered by pi), so
changes are propagated on every apply. In a running pi, `/reload` picks up edits
to the extension without a restart.

Quick check that the bridge can reach Neovim (from the project you have open
in Neovim):

```bash
PAYLOAD=$(mktemp)
printf '{"tool_name":"Write","cwd":"%s","tool_input":{"file_path":"%s/probe.txt","content":"hello\\n"}}' "$PWD" "$PWD" > "$PAYLOAD"
~/.pi/agent/extensions/code-preview/bridge.sh \
  "$HOME/.local/share/nvim/lazy/code-preview.nvim" pre "$PAYLOAD" "$PWD"
rm -f "$PAYLOAD"
# exit 1 = no socket; a permissionDecision JSON line + diff tab = working
# (close the probe tab with :CodePreviewCloseDiff)
```
