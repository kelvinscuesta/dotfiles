import { shJson } from "./sh.js";
import { POLL_JIRA_SH } from "./paths.js";
import { updateQueue, type Ticket, type BacklogTicket } from "./state.js";
import { audit } from "./audit.js";
import { writeMarker } from "./pending.js";

type PollResult = {
  active: Array<Omit<Ticket, "status">>;
  backlog: Array<Omit<BacklogTicket, "status">>;
};

export async function pollJira(): Promise<{ newActive: number; newBacklog: number; newClassifyMarkers: string[] }> {
  const result = await shJson<PollResult>(POLL_JIRA_SH);

  let newActive = 0;
  let newBacklog = 0;
  const toClassify: string[] = [];

  await updateQueue((q) => {
    const now = new Date().toISOString();
    const known = new Set<string>([
      ...q.tickets.map((t) => t.id),
      ...q.backlog.map((t) => t.id),
      ...q.completed.map((c) => c.id),
    ]);

    for (const t of result.active) {
      if (known.has(t.id)) continue;
      q.tickets.push({ ...t, status: "new", added_at: now, added_via: "poll" });
      toClassify.push(t.id);
      newActive++;
    }
    // Backlog ingestion is OFF by default — focus on current sprint only.
    // Set POLL_BACKLOG=1 to re-enable.
    if (process.env.POLL_BACKLOG === "1") {
      for (const t of result.backlog) {
        if (known.has(t.id)) continue;
        q.backlog.push({ ...t, status: "backlog", added_at: now });
        newBacklog++;
      }
    }
    return q;
  });

  // Write classify markers for each new active ticket
  for (const id of toClassify) {
    await writeMarker({
      kind: "classify",
      ticket_id: id,
      created_at: new Date().toISOString(),
    });
  }

  if (newActive > 0) await audit("POLL:JIRA", `found ${newActive} new active tickets: ${toClassify.join(",")}`);
  if (newBacklog > 0) await audit("POLL:JIRA", `found ${newBacklog} new backlog tickets`);
  if (newActive === 0 && newBacklog === 0) await audit("POLL:JIRA", "no new tickets");

  return { newActive, newBacklog, newClassifyMarkers: toClassify };
}
