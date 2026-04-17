import { readFile, stat } from "node:fs/promises";
import { join, basename } from "node:path";
import * as paths from "./paths.js";
import { audit } from "./audit.js";
import { markFailed, clearRunState, deleteMarker, type Marker, type PendingKind } from "./pending.js";

/**
 * Check if a pid is alive (unix). Returns true if kill -0 succeeds.
 */
function pidAlive(pid: number): boolean {
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
}

type RunningSidecar = {
  pid: number;
  started_at: string;
  log_path: string;
};

/**
 * Scan the pending/*.running.json sidecars. For each:
 *   - if pid alive → watcher attached, leave running
 *   - if pid dead → inspect log tail for "exit=N"; process accordingly
 */
export async function reconcileOrphans(): Promise<{
  stillRunning: number;
  reconciledOk: number;
  reconciledFail: number;
}> {
  const pendingDir = process.env.PENDING_DIR ?? join(paths.WORKFLOW_DIR, "pending");
  const kinds: PendingKind[] = ["classify", "implement", "analyze-pr"];

  let stillRunning = 0;
  let reconciledOk = 0;
  let reconciledFail = 0;

  const { readdir } = await import("node:fs/promises");

  for (const kind of kinds) {
    const dir = join(pendingDir, kind);
    let files: string[];
    try { files = await readdir(dir); } catch { continue; }

    for (const f of files) {
      if (!f.endsWith(".running.json")) continue;
      const sidecarPath = join(dir, f);
      const markerPath = sidecarPath.replace(/\.running\.json$/, ".json");

      // Read sidecar
      let sc: RunningSidecar;
      try {
        sc = JSON.parse(await readFile(sidecarPath, "utf8"));
      } catch { continue; }

      // Read marker (to pass to cleanup helpers)
      let marker: Marker;
      try {
        marker = JSON.parse(await readFile(markerPath, "utf8"));
      } catch {
        // Marker missing but sidecar present — just delete the sidecar
        await audit("RECONCILE", `orphan sidecar ${f} has no marker — cleaning`);
        const { unlink } = await import("node:fs/promises");
        await unlink(sidecarPath).catch(() => {});
        continue;
      }

      if (pidAlive(sc.pid)) {
        stillRunning++;
        await audit("RECONCILE", `${kind} for ${basename(markerPath, ".json")} still running pid=${sc.pid}`);
        // Attach async watcher — polls pid every 10s, handles completion when it dies
        watchOrphan(marker, sc);
        continue;
      }

      // PID dead. Look at log for exit code.
      const result = await inspectLogExit(sc.log_path);
      if (result.exitCode === 0) {
        reconciledOk++;
        await clearRunState(marker);
        await deleteMarker(marker);
        await audit("RECONCILE", `${kind} succeeded while server was down (exit=0 in log)`);
      } else {
        reconciledFail++;
        await markFailed(
          marker,
          result.exitCode ?? -1,
          sc.log_path,
          result.exitCode === null ? "no exit line in log — likely killed" : undefined,
        );
        await audit(
          "RECONCILE",
          `${kind} failed while server was down (exit=${result.exitCode ?? "unknown"})`,
        );
      }
    }
  }

  return { stillRunning, reconciledOk, reconciledFail };
}

async function inspectLogExit(logPath: string): Promise<{ exitCode: number | null }> {
  try {
    const content = await readFile(logPath, "utf8");
    const m = content.match(/# exit=(-?\d+)/);
    if (m) return { exitCode: parseInt(m[1]!, 10) };
  } catch { /* no log */ }
  return { exitCode: null };
}

/**
 * Poll a still-running orphan every 10s. When pid dies, process completion.
 * Lightweight — doesn't hold streams; just checks pid + log tail.
 */
function watchOrphan(marker: Marker, sc: RunningSidecar): void {
  const interval = setInterval(async () => {
    if (pidAlive(sc.pid)) return;
    clearInterval(interval);
    const result = await inspectLogExit(sc.log_path);
    if (result.exitCode === 0) {
      await clearRunState(marker);
      await deleteMarker(marker);
      await audit("RUN:OK", `${marker.kind} (orphan) exit=0 log=${sc.log_path}`);
      // Jira transition is owned by the skill — not runner/reconcile.
    } else {
      await markFailed(
        marker,
        result.exitCode ?? -1,
        sc.log_path,
        result.exitCode === null ? "orphan: no exit line in log" : undefined,
      );
      await audit("RUN:FAIL", `${marker.kind} (orphan) exit=${result.exitCode ?? "unknown"}`);
    }
  }, 10_000);
  // Don't hold the event loop open for this watcher
  interval.unref?.();
}
