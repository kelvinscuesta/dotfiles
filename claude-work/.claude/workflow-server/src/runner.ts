import { spawn } from "node:child_process";
import { appendFile, mkdir } from "node:fs/promises";
import { join, dirname } from "node:path";
import { homedir } from "node:os";
import type { Marker } from "./pending.js";
import { deleteMarker, hasMarker, markRunning, markFailed, clearRunState } from "./pending.js";
import { audit } from "./audit.js";
import { readFile, unlink } from "node:fs/promises";
import { readQueue } from "./state.js";

function logDir(): string {
  return process.env.RUNNER_LOG_DIR ?? join(homedir(), ".claude", "workflow-server", "logs");
}
function claudeBin(): string {
  return process.env.CLAUDE_BIN ?? join(homedir(), ".local", "bin", "claude");
}

function promptFor(marker: Marker): string {
  switch (marker.kind) {
    case "classify":
      return `/wf-classify ${marker.ticket_id}`;
    case "implement":
      return `/wf-implement ${marker.ticket_id}`;
    case "analyze-pr":
      return `/wf-analyze-pr ${marker.repo} ${marker.pr_number}`;
  }
}

/**
 * Resolve working directory for the headless Claude spawn so that repo-level
 * CLAUDE.md + .claude/settings.json hierarchy gets loaded at session start.
 *
 * - implement: worktree if it exists, else ~/workspace/<repo> derived from ticket
 * - analyze-pr: ~/workspace/<repo-name> (last segment of owner/repo)
 * - classify: ~/ (no project context needed)
 */
async function cwdFor(marker: Marker): Promise<string> {
  const home = homedir();
  const workspaceRoot = process.env.WORKSPACE_ROOT ?? join(home, "workspace");
  const { existsSync } = await import("node:fs");

  try {
    const q = await readQueue();
    if (marker.kind === "implement") {
      const t = q.tickets.find((x) => x.id === marker.ticket_id);
      if (t?.worktree_path && existsSync(t.worktree_path)) return t.worktree_path;
      const repoSlug = t?.pr_repo ?? "";
      const repoName = repoSlug.includes("/") ? repoSlug.split("/")[1]! : "";
      if (repoName) {
        const p = join(workspaceRoot, repoName);
        if (existsSync(p)) return p;
      }
    } else if (marker.kind === "analyze-pr") {
      const repoName = marker.repo.includes("/") ? marker.repo.split("/")[1]! : marker.repo;
      const p = join(workspaceRoot, repoName);
      if (existsSync(p)) return p;
    }
  } catch { /* fall through to home */ }

  return home;
}

/**
 * If skill wrote a "needs-human" signal for this ticket, open Ghostty at the
 * worktree so the user can investigate. Clears the signal after opening.
 */
async function maybeOpenHumanInspection(ticketId: string): Promise<void> {
  const pendingDir = process.env.PENDING_DIR ?? `${homedir()}/.claude/workflow/pending`;
  const signalPath = `${pendingDir}/implement/${ticketId}.needs-human.json`;
  let reason = "";
  try {
    const raw = await readFile(signalPath, "utf8");
    reason = (JSON.parse(raw) as { reason?: string }).reason ?? "";
  } catch {
    return; // no signal file
  }

  // Look up worktree path from queue
  let worktreePath: string | undefined;
  try {
    const q = await readQueue();
    worktreePath = q.tickets.find((t) => t.id === ticketId)?.worktree_path ?? undefined;
  } catch { /* ignore */ }
  if (!worktreePath) {
    await audit("NEEDS_HUMAN", `${ticketId} flagged but no worktree_path in queue: ${reason}`);
    return;
  }

  await audit("NEEDS_HUMAN", `${ticketId} — opening Ghostty at ${worktreePath}: ${reason}`);

  const title = `⚠️ ${ticketId} needs inspection`;
  const banner = `=== ${title} ===\\nReason: ${reason.replace(/"/g, "'")}\\nBranch status + recent commits:\\n`;
  const cmd = [
    `printf '\\033]0;${title}\\007'`,
    `echo "${banner}"`,
    `git status`,
    `echo`,
    `git log --oneline -5`,
    `echo`,
    `echo "Worktree: ${worktreePath}"`,
    `exec "$SHELL" -l`,
  ].join("; ");

  spawn(
    "/Applications/Ghostty.app/Contents/MacOS/ghostty",
    ["--working-directory", worktreePath, "-e", "bash", "-lc", cmd],
    { stdio: "ignore", detached: true },
  ).unref();

  // Remove the signal file so we don't reopen on every restart
  await unlink(signalPath).catch(() => {});
}

/** One-liner summary of a tool invocation for the live log. */
function summarizeToolInput(name: string, input: Record<string, unknown> | undefined): string {
  if (!input) return "";
  const str = (k: string): string | null => {
    const v = input[k];
    return typeof v === "string" ? v : null;
  };
  switch (name) {
    case "Bash":
      return (str("command") ?? "").slice(0, 140);
    case "Read":
      return str("file_path") ?? "";
    case "Write":
      return str("file_path") ?? "";
    case "Edit":
      return str("file_path") ?? "";
    case "Glob":
      return str("pattern") ?? "";
    case "Grep":
      return str("pattern") ?? "";
    case "WebFetch":
      return str("url") ?? "";
    case "TodoWrite":
      return "update todos";
    default: {
      // Pick first string-ish value as summary
      for (const [k, v] of Object.entries(input)) {
        if (typeof v === "string") return `${k}=${v.slice(0, 100)}`;
      }
      return "";
    }
  }
}

function logFileFor(marker: Marker): string {
  const ts = new Date().toISOString().replace(/[:.]/g, "-");
  const dir = logDir();
  switch (marker.kind) {
    case "classify":
      return join(dir, `classify-${marker.ticket_id}-${ts}.log`);
    case "implement":
      return join(dir, `implement-${marker.ticket_id}-${ts}.log`);
    case "analyze-pr":
      return join(dir, `analyze-${marker.repo.replace(/\//g, "_")}-${marker.pr_number}-${ts}.log`);
  }
}

export type RunResult = {
  ok: boolean;
  exitCode: number;
  logPath: string;
  stdout: string;
  stderr: string;
};

/**
 * Invoke Claude Code CLI in headless mode for the given marker.
 * Streams stdout/stderr to a log file AND buffers for return.
 * On success, removes the marker.
 */
export async function runMarker(marker: Marker, opts: { timeoutMs?: number } = {}): Promise<RunResult> {
  const logPath = logFileFor(marker);
  await mkdir(dirname(logPath), { recursive: true });
  const prompt = promptFor(marker);

  await audit("RUN:START", `${marker.kind} → ${prompt}`);
  await appendFile(logPath, `# ${new Date().toISOString()} ${marker.kind}: ${prompt}\n`);

  const timeoutMs = opts.timeoutMs ?? 30 * 60 * 1000; // 30 min default

  const headlessMode = process.env.WORKFLOW_HEADLESS_MODE ?? "permissive";
  const verbose = process.env.WORKFLOW_VERBOSE !== "0";
  // stream-json gives us tool-call visibility; we transform events to
  // human-readable lines before writing to the log.
  const args = [
    "-p", prompt,
    "--output-format", verbose ? "stream-json" : "text",
  ];
  if (verbose) {
    args.push("--include-partial-messages", "--verbose");
  }
  if (headlessMode === "permissive") {
    args.unshift("--dangerously-skip-permissions");
  }

  const cwd = await cwdFor(marker);
  await appendFile(logPath, `# cwd=${cwd}\n`);

  // Env vars consumed by ~/.claude/hooks/workflow-preamble.sh so the SessionStart
  // hook can emit a context block for the headless agent.
  const headlessEnv: Record<string, string> = {
    WF_HEADLESS: "1",
    WF_KIND: marker.kind,
  };
  if (marker.kind === "classify" || marker.kind === "implement") {
    headlessEnv.WF_TICKET_ID = marker.ticket_id;
  }
  if (marker.kind === "implement") {
    try {
      const q = await readQueue();
      const t = q.tickets.find((x) => x.id === marker.ticket_id);
      if (t?.plan_path) headlessEnv.WF_PLAN_PATH = t.plan_path;
      if (t?.worktree_path) headlessEnv.WF_WORKTREE = t.worktree_path;
      if (t?.pr_repo) headlessEnv.WF_REPO = t.pr_repo;
    } catch { /* ignore */ }
  }
  if (marker.kind === "analyze-pr") {
    headlessEnv.WF_REPO = marker.repo;
    headlessEnv.WF_PR_NUMBER = String(marker.pr_number);
  }

  return new Promise((resolve) => {
    const proc = spawn(claudeBin(), args, {
      stdio: ["ignore", "pipe", "pipe"],
      env: { ...process.env, CLAUDE_CODE_NO_FLICKER: "1", ...headlessEnv },
      cwd,
      // Detached: child becomes session leader so SIGTERM to server doesn't cascade.
      // Child keeps running through server restarts.
      detached: true,
    });
    // Don't block event loop on child; server can exit without waiting.
    proc.unref();

    // Mark running (best-effort; sidecar failure shouldn't block the run)
    if (proc.pid) {
      markRunning(marker, proc.pid, logPath).catch(() => {});
    }

    let stdout = "";
    let stderr = "";

    const stamp = () => new Date().toISOString().replace("T", " ").slice(0, 19);

    // Transform stream-json events into human-readable log lines.
    // Falls back to raw output if not valid JSON.
    const formatEvent = (evt: unknown): string | null => {
      if (!evt || typeof evt !== "object") return null;
      const e = evt as Record<string, unknown>;
      const type = e.type as string | undefined;

      // Top-level conversation events
      if (type === "system") {
        const subtype = e.subtype as string | undefined;
        if (subtype === "init") {
          const session = (e as { session_id?: string }).session_id ?? "";
          const model = (e as { model?: string }).model ?? "";
          return `🚀 Session started  model=${model} session=${session.slice(0, 8)}`;
        }
        // Suppress noisy system events (hook lifecycle, status ticks)
        return null;
      }

      if (type === "rate_limit_event" || type === "status") {
        return null;
      }

      if (type === "assistant") {
        const msg = e.message as { content?: Array<Record<string, unknown>> } | undefined;
        if (!msg?.content) return null;
        const lines: string[] = [];
        for (const block of msg.content) {
          const btype = block.type as string | undefined;
          if (btype === "text") {
            const text = (block.text as string | undefined) ?? "";
            const preview = text.trim().split("\n").slice(0, 3).join(" / ").slice(0, 200);
            if (preview) lines.push(`💬 ${preview}${text.length > 200 ? "…" : ""}`);
          } else if (btype === "tool_use") {
            const name = (block.name as string) ?? "?";
            const input = block.input as Record<string, unknown> | undefined;
            const summary = summarizeToolInput(name, input);
            lines.push(`🔧 ${name}${summary ? ` · ${summary}` : ""}`);
          }
        }
        return lines.length ? lines.join("\n") : null;
      }

      if (type === "user") {
        const msg = e.message as { content?: Array<Record<string, unknown>> } | undefined;
        if (!msg?.content) return null;
        const lines: string[] = [];
        for (const block of msg.content) {
          if (block.type === "tool_result") {
            const content = block.content as string | Array<Record<string, unknown>> | undefined;
            const text = typeof content === "string"
              ? content
              : Array.isArray(content) ? content.map((c) => c.text ?? "").join(" ") : "";
            const preview = text.trim().split("\n")[0]?.slice(0, 120) ?? "";
            const isErr = block.is_error === true;
            if (preview) lines.push(`${isErr ? "❌" : "↳"} ${preview}${text.length > 120 ? "…" : ""}`);
          }
        }
        return lines.length ? lines.join("\n") : null;
      }

      if (type === "stream_event") {
        // partial message chunks — usually too noisy; skip
        return null;
      }

      if (type === "result") {
        const status = (e as { subtype?: string }).subtype ?? "done";
        const cost = (e as { total_cost_usd?: number }).total_cost_usd;
        const duration = (e as { duration_ms?: number }).duration_ms;
        const costStr = cost !== undefined ? ` cost=$${cost.toFixed(4)}` : "";
        const durStr = duration !== undefined ? ` duration=${(duration / 1000).toFixed(1)}s` : "";
        return `✅ ${status}${costStr}${durStr}`;
      }

      return `[${type ?? "event"}] ${JSON.stringify(e).slice(0, 200)}`;
    };

    // Line-buffered stdout handler — parses JSON events, formats, timestamps.
    let stdoutBuffer = "";
    proc.stdout!.on("data", (chunk: Buffer) => {
      const s = chunk.toString("utf8");
      stdout += s;
      stdoutBuffer += s;
      const lines = stdoutBuffer.split("\n");
      stdoutBuffer = lines.pop() ?? "";
      const toWrite: string[] = [];
      for (const line of lines) {
        if (!line.trim()) continue;
        let formatted: string | null = null;
        if (verbose && line.startsWith("{")) {
          try {
            formatted = formatEvent(JSON.parse(line));
          } catch {
            formatted = line;
          }
        } else {
          formatted = line;
        }
        if (formatted) {
          const ts = stamp();
          for (const fl of formatted.split("\n")) {
            toWrite.push(`${ts} ${fl}\n`);
          }
        }
      }
      if (toWrite.length) appendFile(logPath, toWrite.join("")).catch(() => {});
    });

    let stderrBuffer = "";
    proc.stderr!.on("data", (chunk: Buffer) => {
      const s = chunk.toString("utf8");
      stderr += s;
      stderrBuffer += s;
      const lines = stderrBuffer.split("\n");
      stderrBuffer = lines.pop() ?? "";
      if (lines.length === 0) return;
      const ts = stamp();
      const stamped = lines.map((l) => `${ts} [err] ${l}\n`).join("");
      appendFile(logPath, stamped).catch(() => {});
    });

    const timer = setTimeout(() => {
      proc.kill("SIGTERM");
    }, timeoutMs);

    proc.on("exit", async (code) => {
      clearTimeout(timer);
      const exitCode = code ?? -1;
      const ok = exitCode === 0;
      await appendFile(logPath, `\n# exit=${exitCode}\n`);
      if (ok) {
        // Consume marker + clear any stale sidecars
        await clearRunState(marker);
        await deleteMarker(marker);
        await audit("RUN:OK", `${marker.kind} exit=${exitCode} log=${logPath}`);
        // Jira transition is the skill's responsibility — only after PR actually created.
        // Runner no longer auto-transitions.

        // If skill signaled "needs-human", open Ghostty at the worktree for inspection
        if (marker.kind === "implement") {
          await maybeOpenHumanInspection(marker.ticket_id);
        }
      } else {
        // Leave marker for retry + write .failed sidecar for visibility
        await markFailed(marker, exitCode, logPath, stderr.slice(-500) || undefined);
        await audit("RUN:FAIL", `${marker.kind} exit=${exitCode} log=${logPath}`);
        if (marker.kind === "implement") {
          await maybeOpenHumanInspection(marker.ticket_id);
        }
      }
      resolve({ ok, exitCode, logPath, stdout, stderr });
    });

    proc.on("error", async (err) => {
      clearTimeout(timer);
      await appendFile(logPath, `\n[spawn error] ${err.message}\n`);
      await markFailed(marker, -1, logPath, `spawn error: ${err.message}`);
      await audit("RUN:ERROR", `${marker.kind}: ${err.message}`);
      resolve({ ok: false, exitCode: -1, logPath, stdout, stderr: err.message });
    });
  });
}

/**
 * Drain all pending markers serially. Returns summary counts.
 * Stops early if any run fails (to let user intervene).
 */
export async function drainPending(): Promise<{ ran: number; failed: number; skipped: number }> {
  const { listAllMarkers } = await import("./pending.js");
  const markers = await listAllMarkers();
  let ran = 0;
  let failed = 0;
  let skipped = 0;

  for (const marker of markers) {
    // Re-check marker still exists (in case another run consumed it)
    const exists = await hasMarker(marker);
    if (!exists) {
      skipped++;
      continue;
    }
    const result = await runMarker(marker);
    if (result.ok) ran++;
    else {
      failed++;
      break; // stop on first failure
    }
  }
  return { ran, failed, skipped };
}
