import { mkdir, readdir, readFile, writeFile, unlink, rename } from "node:fs/promises";
import { join } from "node:path";
import { homedir } from "node:os";
import { watch } from "node:fs";

export type PendingKind = "classify" | "implement" | "analyze-pr";

function pendingDir(): string {
  return process.env.PENDING_DIR ?? join(process.env.WORKFLOW_DIR ?? join(homedir(), ".claude", "workflow"), "pending");
}

export type ClassifyMarker = {
  kind: "classify";
  ticket_id: string;
  created_at: string;
};

export type ImplementMarker = {
  kind: "implement";
  ticket_id: string;
  plan_path: string;
  approved_at: string;
  created_at: string;
  /** If true, implement skill should proceed even if plan lists blockers. */
  force?: boolean;
};

export type AnalyzePrMarker = {
  kind: "analyze-pr";
  repo: string;
  pr_number: number;
  new_comment_count: number;
  created_at: string;
};

export type Marker = ClassifyMarker | ImplementMarker | AnalyzePrMarker;

function dirFor(kind: PendingKind): string {
  return join(pendingDir(), kind);
}

function filenameFor(marker: Marker): string {
  switch (marker.kind) {
    case "classify":
    case "implement":
      return `${marker.ticket_id}.json`;
    case "analyze-pr":
      return `${marker.repo.replace(/\//g, "_")}-${marker.pr_number}.json`;
  }
}

export async function writeMarker(marker: Marker): Promise<string> {
  const dir = dirFor(marker.kind);
  await mkdir(dir, { recursive: true });
  const path = join(dir, filenameFor(marker));
  const tmp = `${path}.tmp`;
  await writeFile(tmp, JSON.stringify(marker, null, 2));
  await rename(tmp, path);
  return path;
}

export async function deleteMarker(marker: Marker): Promise<void> {
  const path = join(dirFor(marker.kind), filenameFor(marker));
  try { await unlink(path); } catch { /* already gone */ }
}

export async function hasMarker(marker: Marker): Promise<boolean> {
  const path = join(dirFor(marker.kind), filenameFor(marker));
  try {
    await readFile(path);
    return true;
  } catch { return false; }
}

export async function listMarkers(kind: PendingKind): Promise<Marker[]> {
  const dir = dirFor(kind);
  let files: string[] = [];
  try { files = await readdir(dir); } catch { return []; }
  const out: Marker[] = [];
  for (const f of files) {
    if (!f.endsWith(".json") || f.endsWith(".tmp")) continue;
    // Skip sidecar files (.running.json, .failed.json)
    if (f.endsWith(".running.json") || f.endsWith(".failed.json")) continue;
    try {
      const raw = await readFile(join(dir, f), "utf8");
      out.push(JSON.parse(raw));
    } catch { /* skip corrupt */ }
  }
  return out;
}

export async function listAllMarkers(): Promise<Marker[]> {
  const [c, i, a] = await Promise.all([
    listMarkers("classify"),
    listMarkers("implement"),
    listMarkers("analyze-pr"),
  ]);
  return [...c, ...i, ...a];
}

/** Sidecar paths: <marker>.running, <marker>.failed (both JSON). */
function sidecarPath(marker: Marker, suffix: "running" | "failed"): string {
  const base = filenameFor(marker).replace(/\.json$/, "");
  return join(dirFor(marker.kind), `${base}.${suffix}.json`);
}

/** Write a .running sidecar with pid + started_at timestamp. */
export async function markRunning(marker: Marker, pid: number, logPath: string): Promise<void> {
  const path = sidecarPath(marker, "running");
  await writeFile(
    path,
    JSON.stringify({ pid, started_at: new Date().toISOString(), log_path: logPath }, null, 2),
  );
}

/** Clear all run-state sidecars for a marker (called on success). */
export async function clearRunState(marker: Marker): Promise<void> {
  for (const suffix of ["running", "failed"] as const) {
    try { await unlink(sidecarPath(marker, suffix)); } catch { /* may not exist */ }
  }
}

/** Write a .failed sidecar with exit code + log path. */
export async function markFailed(marker: Marker, exitCode: number, logPath: string, reason?: string): Promise<void> {
  // Clear running first
  try { await unlink(sidecarPath(marker, "running")); } catch { /* ok */ }
  const path = sidecarPath(marker, "failed");
  await writeFile(
    path,
    JSON.stringify({
      exit_code: exitCode,
      failed_at: new Date().toISOString(),
      log_path: logPath,
      reason: reason ?? null,
    }, null, 2),
  );
}

/** Read run state for a marker. Returns null if neither sidecar exists. */
export async function readRunState(marker: Marker): Promise<
  | { state: "running"; pid: number; started_at: string; log_path: string }
  | { state: "failed"; exit_code: number; failed_at: string; log_path: string; reason: string | null }
  | null
> {
  try {
    const text = await readFile(sidecarPath(marker, "running"), "utf8");
    return { state: "running", ...JSON.parse(text) };
  } catch { /* not running */ }
  try {
    const text = await readFile(sidecarPath(marker, "failed"), "utf8");
    return { state: "failed", ...JSON.parse(text) };
  } catch { /* not failed */ }
  return null;
}

/** Watch the pending dirs for changes. Callback fires when markers are added OR removed. */
export function watchPending(onChange: (event: "add" | "remove", kind: PendingKind, file: string) => void): () => void {
  const watchers = (["classify", "implement", "analyze-pr"] as const).map((kind) => {
    const dir = dirFor(kind);
    const w = watch(dir, { persistent: false }, (event, filename) => {
      if (!filename || !filename.endsWith(".json") || filename.endsWith(".tmp")) return;
      // fs.watch on macOS reports "rename" for both create and delete.
      // Check file existence to distinguish.
      readFile(join(dir, filename))
        .then(() => onChange("add", kind, filename))
        .catch(() => onChange("remove", kind, filename));
    });
    return w;
  });
  return () => watchers.forEach((w) => w.close());
}
