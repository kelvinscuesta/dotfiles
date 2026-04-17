import { shJson } from "./sh.js";
import { POLL_PRS_SH } from "./paths.js";
import { updateQueue, type PR, type CIStatus, type Completed } from "./state.js";
import { audit } from "./audit.js";
import { writeMarker } from "./pending.js";

type PollResult = {
  open_prs: Array<PR & { ci: CIStatus }>;
  closed_prs: Array<PR & { merged?: boolean; merged_at?: string | null; closed_at?: string | null; state?: string }>;
  new_comments: Array<{
    type: "review_comment" | "issue_comment" | "review";
    repo: string;
    pr_number: number;
    id: number;
    user: string;
    body: string;
    created_at: string;
    url: string;
    path?: string;
    line?: number;
    state?: string;
  }>;
};

export type PollPRsResult = {
  openCount: number;
  closedMerged: number;
  closedUnmerged: number;
  newCommentCount: number;
  newCommentsByPR: Map<string, number>;
};

export async function pollPRs(): Promise<PollPRsResult> {
  const result = await shJson<PollResult>(POLL_PRS_SH);
  let closedMerged = 0;
  let closedUnmerged = 0;
  const newCommentsByPR = new Map<string, number>();
  for (const c of result.new_comments) {
    const key = `${c.repo}#${c.pr_number}`;
    newCommentsByPR.set(key, (newCommentsByPR.get(key) ?? 0) + 1);
  }

  await updateQueue((q) => {
    const nowIso = new Date().toISOString();

    // Upsert open PRs with CI data
    const openIndex = new Map<string, (typeof q.prs)[number]>();
    for (const p of q.prs) openIndex.set(`${p.repo}#${p.number}`, p);

    const nextPRs: typeof q.prs = [];
    for (const incoming of result.open_prs) {
      const key = `${incoming.repo}#${incoming.number}`;
      const existing = openIndex.get(key);
      const pendingAdd = newCommentsByPR.get(key) ?? 0;
      const merged: typeof q.prs[number] = {
        ...(existing ?? { last_seen_comment_id: 0, pending_comments: 0 }),
        repo: incoming.repo,
        number: incoming.number,
        title: incoming.title,
        url: incoming.url,
        is_draft: incoming.is_draft,
        updated_at: incoming.updated_at,
        ci: incoming.ci,
        pending_comments: (existing?.pending_comments ?? 0) + pendingAdd,
        last_checked: nowIso,
      };
      nextPRs.push(merged);
    }
    q.prs = nextPRs;

    // Handle closed PRs — move associated tickets to completed, cleanup tracked
    for (const closed of result.closed_prs) {
      const wasMerged = closed.merged === true;
      if (wasMerged) closedMerged++;
      else closedUnmerged++;

      // Find associated ticket
      const ticketIdx = q.tickets.findIndex(
        (t) => t.pr_repo === closed.repo && t.pr_number === closed.number,
      );
      if (ticketIdx >= 0) {
        const t = q.tickets[ticketIdx]!;
        if (wasMerged) {
          const completedEntry: Completed = {
            id: t.id,
            type: "ticket",
            title: t.title,
            completed_at: nowIso,
            pr_number: closed.number,
            repo: closed.repo,
            disposition: "merged",
            url: t.url,
          };
          q.completed.unshift(completedEntry);
          q.tickets.splice(ticketIdx, 1);
        } else {
          t.status = "awaiting-approval";
          t.last_action = nowIso;
        }
      }
    }

    // Prune completed older than 7 days
    const cutoff = Date.now() - 7 * 24 * 60 * 60 * 1000;
    q.completed = q.completed.filter((c) => {
      const ts = Date.parse(c.completed_at);
      return Number.isFinite(ts) && ts > cutoff;
    });

    return q;
  });

  // Write analyze-pr markers for each PR with new comments
  for (const [key, count] of newCommentsByPR) {
    const [repo, numStr] = key.split("#");
    await writeMarker({
      kind: "analyze-pr",
      repo: repo!,
      pr_number: Number(numStr),
      new_comment_count: count,
      created_at: new Date().toISOString(),
    });
  }

  if (closedMerged > 0) await audit("CLEANUP", `${closedMerged} PRs merged`);
  if (closedUnmerged > 0) await audit("CLEANUP", `${closedUnmerged} PRs closed without merge`);
  if (newCommentsByPR.size > 0) {
    await audit("POLL:PR", `${result.new_comments.length} new comments across ${newCommentsByPR.size} PRs`);
  }
  if (closedMerged === 0 && closedUnmerged === 0 && newCommentsByPR.size === 0) {
    await audit("POLL:PR", "no changes");
  }

  return {
    openCount: result.open_prs.length,
    closedMerged,
    closedUnmerged,
    newCommentCount: result.new_comments.length,
    newCommentsByPR,
  };
}
