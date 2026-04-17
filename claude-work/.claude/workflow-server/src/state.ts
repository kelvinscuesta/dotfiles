import { readFile, writeFile, rename, mkdir } from "node:fs/promises";
import { dirname } from "node:path";
import * as paths from "./paths.js";

export type Ticket = {
  id: string;
  title: string;
  status: "new" | "classifying" | "ready" | "needs-clarification" | "awaiting-approval" | "in-progress" | "pr-created";
  issue_type?: string;
  priority?: string;
  assignee_email?: string | null;
  reporter_email?: string | null;
  labels?: string[];
  url: string;
  added_at?: string;
  added_via?: "poll" | "manual";
  classification?: string;
  plan_path?: string | null;
  draft_path?: string | null;
  branch?: string | null;
  pr_number?: number | null;
  pr_repo?: string | null;
  worktree_path?: string | null;
  last_action?: string;
  approved_at?: string;
  /** Slack message_ts of the thread root for this ticket's implementation activity. */
  slack_thread_ts?: string;
};

export type BacklogTicket = Omit<Ticket, "status"> & { status: "backlog"; digested_at?: string };

export type PR = {
  repo: string;
  number: number;
  title: string;
  url: string;
  is_draft?: boolean;
  updated_at?: string;
  ticket_id?: string;
  last_seen_comment_id?: number;
  pending_comments?: number;
  draft_path?: string | null;
  last_checked?: string;
  ci?: CIStatus;
};

export type CIStatus = {
  status: "pass" | "fail" | "pending" | "none" | "unknown";
  total: number;
  pass: number;
  fail: number;
  pending: number;
  skipping: number;
  failing: Array<{ name: string; link: string; state: string }>;
  pending_list: Array<{ name: string; link: string }>;
  buildkite: { name: string; state: string; link: string; bucket: string } | null;
};

export type Completed = {
  id: string;
  type: "ticket" | "pr";
  title: string;
  completed_at: string;
  pr_number?: number;
  repo?: string;
  disposition?: "merged" | "closed" | "rejected";
  reason?: string;
  url?: string;
};

export type Queue = {
  version: number;
  last_updated: string | null;
  workflow_state: "running" | "paused" | "stopped";
  tickets: Ticket[];
  backlog: BacklogTicket[];
  prs: PR[];
  completed: Completed[];
};

// Resolve the queue file at call-time so tests can override QUEUE_FILE env per-test.
function queuePath(override?: string): string {
  return override ?? process.env.QUEUE_FILE ?? paths.QUEUE_FILE;
}

const writeLocks = new Map<string, Promise<void>>();

export async function readQueue(override?: string): Promise<Queue> {
  const text = await readFile(queuePath(override), "utf8");
  return JSON.parse(text);
}

/** Atomic read-modify-write, serialized per-file so concurrent mutations don't clobber each other. */
export async function updateQueue(
  mutator: (q: Queue) => Queue | Promise<Queue>,
  override?: string,
): Promise<Queue> {
  const path = queuePath(override);
  const prev = writeLocks.get(path) ?? Promise.resolve();
  const next = prev.then(async () => {
    const current = await readQueue(path);
    const updated = await mutator(current);
    updated.last_updated = new Date().toISOString();
    const tmp = `${path}.tmp`;
    await mkdir(dirname(path), { recursive: true });
    await writeFile(tmp, JSON.stringify(updated, null, 2));
    await rename(tmp, path);
    return updated;
  });
  writeLocks.set(
    path,
    next.then(() => {}, () => {}),
  );
  return next;
}
