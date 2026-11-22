/**
 * code-preview bridge — review pi's `edit` / `write` tool calls as native
 * Neovim diffs, via Cannon07/code-preview.nvim, before they touch disk.
 *
 * Flow:
 *   1. `tool_call` fires for `edit` or `write`
 *   2. we translate pi's payload into code-preview's canonical shape and send
 *      it through bridge.sh -> nvim RPC -> code-preview.pre_tool.handle()
 *   3. Neovim opens the proposed change as a diff tab
 *   4. review.lua adds `<leader>da` (accept) / `<leader>dr` (reject) to that
 *      tab; the decision comes back through a JSON file we poll
 *   5. Accept -> the diff is closed after the write completes (`tool_result`)
 *      Reject -> the diff is closed now and the tool call is blocked
 *
 * If the Neovim-side prompt cannot be installed (plugin too old, no review.lua)
 * the extension falls back to a pi TUI dialog ("pi" gate). Config `gate: false`
 * shows the preview but never waits for a decision.
 *
 * If Neovim is unreachable, code-preview abstains (prints nothing) and we let
 * the tool call run untouched — same fallback the plugin uses for its native
 * agents.
 *
 * Config: ~/.pi/agent/code-preview.json (optional)
 *   {
 *     "enabled": true,
 *     "gate": "nvim",         // "nvim" | "pi" | false
 *     "pluginDir": "...",     // else CODE_PREVIEW_NVIM, else auto-discovery
 *     "timeoutMs": 15000,     // timeout for each nvim RPC call
 *     "reviewTimeoutMs": 1800000
 *   }
 */

import { existsSync, mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import { homedir, tmpdir } from "node:os";
import { dirname, join, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import {
	isToolCallEventType,
	type ExtensionAPI,
	type ExtensionContext,
	type ToolCallEvent,
} from "@earendil-works/pi-coding-agent";

const EXT_DIR = dirname(fileURLToPath(import.meta.url));
const BRIDGE = join(EXT_DIR, "bridge.sh");
const CONFIG_PATH = join(homedir(), ".pi", "agent", "code-preview.json");

type GateMode = "nvim" | "pi" | false;

interface BridgeConfig {
	enabled: boolean;
	gate: GateMode;
	pluginDir?: string;
	timeoutMs: number;
	reviewTimeoutMs: number;
}

const DEFAULT_CONFIG: BridgeConfig = {
	enabled: true,
	gate: "nvim",
	timeoutMs: 15_000,
	reviewTimeoutMs: 30 * 60_000,
};

function normalizeGate(value: unknown): GateMode {
	if (value === false) return false;
	if (value === "pi" || value === true) return "pi";
	return "nvim";
}

/** Canonical code-preview proposal shape (the "claudecode" backend is identity). */
interface CanonicalPayload {
	tool_name: "MultiEdit" | "Write";
	cwd: string;
	tool_input: Record<string, unknown>;
}

interface PendingClose {
	pluginDir: string;
	payload: CanonicalPayload;
	timeoutMs: number;
}

type Decision = "accept" | "reject" | "closed";

function expandHome(p: string): string {
	return p.startsWith("~/") ? join(homedir(), p.slice(2)) : p;
}

function loadConfig(): BridgeConfig {
	try {
		const raw = JSON.parse(readFileSync(CONFIG_PATH, "utf8")) as Partial<BridgeConfig> & { gate?: unknown };
		return {
			...DEFAULT_CONFIG,
			...raw,
			gate: normalizeGate(raw.gate ?? DEFAULT_CONFIG.gate),
		};
	} catch {
		return { ...DEFAULT_CONFIG };
	}
}

function isPluginDir(dir: string): boolean {
	return (
		existsSync(join(dir, "lua", "code-preview", "rpc.lua")) &&
		existsSync(join(dir, "bin", "nvim-socket.sh"))
	);
}

function resolvePluginDir(configured?: string): string | undefined {
	const candidates: string[] = [];
	const push = (p: string | undefined) => {
		if (p && p.trim() !== "") candidates.push(expandHome(p.trim()));
	};

	push(configured);
	push(process.env.CODE_PREVIEW_NVIM);

	const dataHomes = [process.env.XDG_DATA_HOME, join(homedir(), ".local", "share")];
	for (const dataHome of dataHomes) {
		if (!dataHome) continue;
		push(join(dataHome, "nvim", "lazy", "code-preview.nvim"));

		// pack/*/start|opt/code-preview.nvim (manual / package-manager installs)
		const packRoot = join(dataHome, "nvim", "site", "pack");
		try {
			for (const pkg of readdirSync(packRoot)) {
				for (const kind of ["start", "opt"]) {
					push(join(packRoot, pkg, kind, "code-preview.nvim"));
				}
			}
		} catch {
			// no pack dir — fine
		}
	}

	push(join(homedir(), "code-preview.nvim"));
	push(join(homedir(), "src", "code-preview.nvim"));
	push(join(homedir(), "projects", "code-preview.nvim"));

	return candidates.find(isPluginDir);
}

/** Translate a pi edit/write call into code-preview's canonical payload. */
function buildPayload(event: ToolCallEvent, cwd: string): CanonicalPayload | undefined {
	if (isToolCallEventType("edit", event)) {
		// pi's canonical shape is { path, edits: [{ oldText, newText }] }, but
		// legacy/single-edit shapes exist; accept both defensively.
		const input = event.input as {
			path?: string;
			edits?: Array<{ oldText?: string; newText?: string }>;
			oldText?: string;
			newText?: string;
		};
		if (!input.path) return undefined;

		const edits = Array.isArray(input.edits) ? [...input.edits] : [];
		if (typeof input.oldText === "string" && typeof input.newText === "string") {
			edits.push({ oldText: input.oldText, newText: input.newText });
		}
		if (edits.length === 0) return undefined;

		return {
			tool_name: "MultiEdit",
			cwd,
			tool_input: {
				file_path: resolve(cwd, input.path),
				edits: edits.map((e) => ({
					old_string: e.oldText ?? "",
					new_string: e.newText ?? "",
				})),
			},
		};
	}

	if (isToolCallEventType("write", event)) {
		const input = event.input as { path?: string; content?: string };
		if (!input.path) return undefined;
		return {
			tool_name: "Write",
			cwd,
			tool_input: {
				file_path: resolve(cwd, input.path),
				content: input.content ?? "",
			},
		};
	}

	return undefined;
}

interface BridgeResult {
	code: number;
	stdout: string;
}

async function callBridge(
	pi: ExtensionAPI,
	pluginDir: string,
	eventName: "pre" | "post" | "review",
	args: unknown,
	cwd: string,
	timeoutMs: number,
): Promise<BridgeResult> {
	const dir = mkdtempSync(join(tmpdir(), "pi-code-preview-"));
	const argsFile = join(dir, "args.json");
	writeFileSync(argsFile, JSON.stringify(args), "utf8");
	try {
		const result = await pi.exec("bash", [BRIDGE, pluginDir, eventName, argsFile, cwd], {
			timeout: timeoutMs,
		});
		return { code: result.code ?? 1, stdout: result.stdout ?? "" };
	} catch {
		return { code: 1, stdout: "" };
	} finally {
		rmSync(dir, { recursive: true, force: true });
	}
}

function reviewablePath(payload: CanonicalPayload): string {
	const file = payload.tool_input.file_path;
	return typeof file === "string" ? relative(payload.cwd, file) || file : "file";
}

const sleep = (ms: number) => new Promise<void>((r) => setTimeout(r, ms));

/**
 * Install accept/reject keys on the open diff tab and wait for the decision.
 * Returns undefined when the Neovim side could not be set up (caller falls
 * back to the pi dialog).
 */
async function reviewInNeovim(opts: {
	pi: ExtensionAPI;
	pluginDir: string;
	payload: CanonicalPayload;
	label: string;
	config: BridgeConfig;
	signal?: AbortSignal;
}): Promise<Decision | undefined> {
	const { pi, pluginDir, payload, label, config, signal } = opts;
	const dir = mkdtempSync(join(tmpdir(), "pi-code-preview-review-"));
	const decisionFile = join(dir, "decision.json");

	try {
		const res = await callBridge(
			pi,
			pluginDir,
			"review",
			{
				decision_file: decisionFile,
				label,
				keys: { accept: "<leader>da", reject: "<leader>dr" },
			},
			payload.cwd,
			config.timeoutMs,
		);
		if (res.code !== 0) return undefined;

		const deadline = Date.now() + config.reviewTimeoutMs;
		while (Date.now() < deadline) {
			if (signal?.aborted) return "closed";

			try {
				const raw = JSON.parse(readFileSync(decisionFile, "utf8")) as { decision?: Decision };
				if (raw?.decision === "accept" || raw?.decision === "reject" || raw?.decision === "closed") {
					return raw.decision;
				}
			} catch {
				// not written yet
			}

			await sleep(150);
		}

		return "closed"; // review timed out: do not apply silently
	} finally {
		rmSync(dir, { recursive: true, force: true });
	}
}

export default function (pi: ExtensionAPI): void {
	const config = loadConfig();
	if (!config.enabled) return;

	const pluginDir = resolvePluginDir(config.pluginDir);
	let warnedMissing = false;

	// pi runs sibling tool calls concurrently; serialize review prompts so two
	// diffs never race for the same dialog.
	let queue: Promise<unknown> = Promise.resolve();
	function serialize<T>(fn: () => Promise<T>): Promise<T> {
		const run = queue.then(fn, fn);
		queue = run.catch(() => undefined);
		return run;
	}

	// Accepted calls keep their preview open until the write lands, matching
	// code-preview's post-tool cleanup.
	const pendingClose = new Map<string, PendingClose>();

	pi.on("tool_call", async (event, ctx: ExtensionContext) => {
		if (event.toolName !== "edit" && event.toolName !== "write") return undefined;
		if (!ctx.hasUI) return undefined; // print/json mode: nothing to approve in

		if (!pluginDir) {
			if (!warnedMissing) {
				warnedMissing = true;
				ctx.ui.notify(
					"code-preview: plugin not found. Set pluginDir in ~/.pi/agent/code-preview.json or CODE_PREVIEW_NVIM.",
					"warning",
				);
			}
			return undefined;
		}

		const payload = buildPayload(event, ctx.cwd);
		if (!payload) return undefined;
		const toolCallId = event.toolCallId;
		const gate = config.gate;

		return serialize(async () => {
			const pre = await callBridge(pi, pluginDir, "pre", payload, ctx.cwd, config.timeoutMs);
			if (pre.code !== 0) return undefined; // Neovim unreachable: abstain

			// code-preview only emits a permission decision for Edit/Write/
			// MultiEdit. No envelope => it abstained (e.g. plugin configured with
			// diff.defer_claude_permissions). Leave the call alone.
			const asked = /"permissionDecision"\s*:\s*"ask"/.test(pre.stdout);
			if (!asked) return undefined;

			const rel = reviewablePath(payload);

			if (gate === false) {
				pendingClose.set(toolCallId, { pluginDir, payload, timeoutMs: config.timeoutMs });
				return undefined;
			}

			let decision: Decision | undefined;

			if (gate === "nvim") {
				decision = await reviewInNeovim({
					pi,
					pluginDir,
					payload,
					label: rel,
					config,
					signal: ctx.signal,
				});
				// No keymaps installed (headless / older copy): fall back to pi.
			}

			if (decision === undefined) {
				const choice = await ctx.ui.select(`Apply ${event.toolName} to ${rel}?`, ["Accept", "Reject"]);
				decision = choice === "Accept" ? "accept" : "reject";
			}

			if (decision === "accept") {
				pendingClose.set(toolCallId, { pluginDir, payload, timeoutMs: config.timeoutMs });
				return undefined;
			}

			// Rejected, preview closed, or review timed out: close and block.
			await callBridge(pi, pluginDir, "post", payload, ctx.cwd, config.timeoutMs);
			ctx.ui.notify(`code-preview: rejected ${event.toolName} on ${rel}`, "info");
			return {
				block: true,
				reason: `User reviewed the diff in Neovim and rejected this ${event.toolName} on ${rel}.`,
			};
		});
	});

	pi.on("tool_result", async (event, ctx: ExtensionContext) => {
		const pending = pendingClose.get(event.toolCallId);
		if (!pending) return undefined;
		pendingClose.delete(event.toolCallId);

		await callBridge(pi, pluginDir!, "post", pending.payload, pending.payload.cwd, pending.timeoutMs);
		if (event.isError) {
			ctx.ui.notify(`code-preview: ${event.toolName} failed after review; preview closed`, "warning");
		}
		return undefined;
	});
}
