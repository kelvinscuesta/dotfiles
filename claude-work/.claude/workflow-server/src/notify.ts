import { spawn } from "node:child_process";

/**
 * High-value event → macOS notification. Non-blocking.
 *
 * Uses `terminal-notifier` if installed (supports URL click + app identity),
 * falls back to `osascript` (built-in).
 *
 * Filter via env MAC_NOTIFY_ACTIONS (comma-separated prefixes, same shape as
 * SLACK_MIRROR_ACTIONS). Default tuned for high-value events only.
 */

const DEFAULT_FILTER = [
  "RUN:START",   // Claude spawned
  "RUN:OK",      // implementation / classify succeeded
  "RUN:FAIL",    // something broke
  "CLASSIFY",    // plan written, awaiting approval
  "STALE",       // stuck item
  "CLEANUP",     // PR merged / closed
  "JIRA:TRANSITION",
  "DRAFT",       // PR comment drafts ready
];

function filters(): string[] {
  const raw = process.env.MAC_NOTIFY_ACTIONS;
  if (!raw) return DEFAULT_FILTER;
  return raw.split(",").map((s) => s.trim()).filter(Boolean);
}

export function shouldNotify(action: string): boolean {
  if (process.env.MAC_NOTIFY_ENABLED === "0") return false;
  return filters().some((p) => action.startsWith(p));
}

function classify(action: string, message: string): {
  title: string;
  subtitle: string;
  body: string;
  sound: string;
} {
  // Extract ticket/PR id from message head for use as subtitle
  const idMatch = message.match(/\b(PAY-\d+|#\d+|\S+#\d+)\b/);
  const id = idMatch?.[0] ?? "";

  let title = "Workflow";
  let sound = "Glass";

  if (action === "RUN:START") {
    const kind = message.split(" ")[0] ?? "run";
    title = `⚙ ${kind} started`;
    sound = "Pop";
  } else if (action === "RUN:OK") {
    title = "✅ Run complete";
    sound = "Glass";
  } else if (action === "RUN:FAIL" || action === "RUN:ERROR") {
    title = "❌ Run failed";
    sound = "Basso";
  } else if (action === "CLASSIFY") {
    if (message.includes("ready")) {
      title = "📋 Plan ready";
      sound = "Glass";
    } else if (message.includes("needs-clarification")) {
      title = "🔍 Needs clarification";
      sound = "Ping";
    } else {
      title = "Classified";
    }
  } else if (action === "STALE") {
    title = "⏰ Stale in queue";
    sound = "Ping";
  } else if (action === "CLEANUP") {
    title = "🎉 PR closed";
    sound = "Glass";
  } else if (action.startsWith("JIRA:TRANSITION")) {
    title = "🎫 Jira updated";
  } else if (action === "DRAFT") {
    title = "💬 Draft ready";
    sound = "Ping";
  }

  return {
    title,
    subtitle: id,
    body: message,
    sound,
  };
}

function escapeAppleScriptStr(s: string): string {
  return s.replace(/\\/g, "\\\\").replace(/"/g, '\\"');
}

/** Send macOS notification. Fire-and-forget. */
export function macNotify(action: string, message: string): void {
  if (!shouldNotify(action)) return;
  const { title, subtitle, body, sound } = classify(action, message);

  // Clamp body length — macOS truncates but long strings waste space
  const clampedBody = body.length > 140 ? body.slice(0, 137) + "…" : body;

  const t = escapeAppleScriptStr(title);
  const s = escapeAppleScriptStr(subtitle);
  const b = escapeAppleScriptStr(clampedBody);

  let script: string;
  if (subtitle) {
    script = `display notification "${b}" with title "${t}" subtitle "${s}" sound name "${sound}"`;
  } else {
    script = `display notification "${b}" with title "${t}" sound name "${sound}"`;
  }

  const proc = spawn("/usr/bin/osascript", ["-e", script], {
    stdio: "ignore",
    detached: true,
  });
  proc.on("error", () => { /* ignore — best-effort */ });
  proc.unref();
}
