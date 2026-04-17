import { readQueue } from "./state.js";
import { listAllMarkers, readRunState } from "./pending.js";
import { audit } from "./audit.js";

const HOURS = 60 * 60 * 1000;

function thresholdMs(key: string, defaultH: number): number {
  const raw = process.env[key];
  if (!raw) return defaultH * HOURS;
  const h = parseFloat(raw);
  return Number.isFinite(h) ? h * HOURS : defaultH * HOURS;
}

function ageMs(iso: string | undefined | null): number | null {
  if (!iso) return null;
  const t = Date.parse(iso);
  return Number.isFinite(t) ? Date.now() - t : null;
}

function formatAge(ms: number): string {
  const h = ms / HOURS;
  if (h < 1) return `${Math.round(ms / (60 * 1000))}m`;
  if (h < 24) return `${h.toFixed(1)}h`;
  return `${(h / 24).toFixed(1)}d`;
}

/**
 * Check queue + pending markers for stuck items; emit STALE audit entries
 * which flow through the Slack mirror queue.
 *
 * Thresholds (hours, override via env):
 *   STALE_AWAITING_APPROVAL_H=24  — plans waiting on user
 *   STALE_IN_PROGRESS_H=2         — implementations stuck
 *   STALE_PENDING_H=0.5           — markers queued but not running
 *   STALE_RUNNING_H=1             — subprocess running too long
 */
export async function checkStale(): Promise<{ warnings: string[] }> {
  const warnings: string[] = [];
  const now = Date.now();

  const q = await readQueue();

  const approvalMs = thresholdMs("STALE_AWAITING_APPROVAL_H", 24);
  const inProgressMs = thresholdMs("STALE_IN_PROGRESS_H", 2);

  for (const t of q.tickets) {
    if (t.status === "awaiting-approval" || t.status === "ready") {
      const age = ageMs(t.last_action ?? t.added_at);
      if (age !== null && age > approvalMs) {
        const msg = `${t.id} awaiting approval for ${formatAge(age)}`;
        warnings.push(msg);
        await audit("STALE", msg);
      }
    } else if (t.status === "in-progress") {
      const age = ageMs(t.approved_at ?? t.last_action);
      if (age !== null && age > inProgressMs) {
        const msg = `${t.id} in-progress for ${formatAge(age)} — implementation may be stuck`;
        warnings.push(msg);
        await audit("STALE", msg);
      }
    }
  }

  // Check pending markers
  const pendingMs = thresholdMs("STALE_PENDING_H", 0.5);
  const runningMs = thresholdMs("STALE_RUNNING_H", 1);
  const markers = await listAllMarkers();
  for (const m of markers) {
    const age = ageMs(m.created_at);
    if (age === null) continue;
    const state = await readRunState(m);
    const id = m.kind === "analyze-pr" ? `${m.repo}#${m.pr_number}` : m.ticket_id;

    if (state?.state === "running") {
      const runAge = ageMs(state.started_at) ?? 0;
      if (runAge > runningMs) {
        const msg = `${m.kind} for ${id} running ${formatAge(runAge)} — may be stuck`;
        warnings.push(msg);
        await audit("STALE", msg);
      }
    } else if (state?.state === "failed") {
      // Note failures, but less frequently — only if not already reported
      const failAge = ageMs(state.failed_at) ?? 0;
      if (failAge < 2 * HOURS) {
        const msg = `${m.kind} for ${id} failed ${formatAge(failAge)} ago (exit=${state.exit_code})`;
        warnings.push(msg);
        // No audit here — already audited as RUN:FAIL
      }
    } else if (age > pendingMs) {
      const msg = `${m.kind} for ${id} queued ${formatAge(age)} without runner pickup`;
      warnings.push(msg);
      await audit("STALE", msg);
    }
  }

  return { warnings };
}
