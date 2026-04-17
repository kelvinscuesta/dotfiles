import { pollJira } from "./poll-jira.js";
import { pollPRs } from "./poll-prs.js";
import { audit } from "./audit.js";
import { startDashboard } from "./dashboard.js";
import { drainPending } from "./runner.js";
import { listAllMarkers } from "./pending.js";
import { checkStale } from "./stale.js";
import { drainSlack } from "./slack-drain.js";
import { reconcileOrphans } from "./reconcile.js";
import { mkdir } from "node:fs/promises";
import { PENDING_CLASSIFY, PENDING_IMPLEMENT, PENDING_ANALYZE_PR } from "./paths.js";

// Defaults: bias toward quiet. Override via ~/.claude/workflow-server/.env
const JIRA_INTERVAL_MS = parseInt(process.env.JIRA_INTERVAL_MS ?? String(2 * 60 * 60 * 1000), 10); // 2h
const PR_INTERVAL_MS = parseInt(process.env.PR_INTERVAL_MS ?? String(30 * 60 * 1000), 10); // 30min
const STALE_INTERVAL_MS = parseInt(process.env.STALE_INTERVAL_MS ?? String(60 * 60 * 1000), 10); // 1h
const SLACK_DRAIN_INTERVAL_MS = parseInt(process.env.SLACK_DRAIN_INTERVAL_MS ?? String(5 * 60 * 1000), 10); // 5min
const DRAIN_INTERVAL_MS = parseInt(process.env.DRAIN_INTERVAL_MS ?? String(15 * 1000), 10); // 15s

// 9am–6pm Mon–Fri local time
function isWorkHours(): boolean {
  if (process.env.IGNORE_WORK_HOURS === "1") return true;
  const now = new Date();
  const day = now.getDay(); // 0=Sun, 6=Sat
  const hour = now.getHours();
  return day >= 1 && day <= 5 && hour >= 9 && hour < 18;
}

const AUTO_DRAIN = process.env.AUTO_DRAIN !== "0";

let draining = false;
async function maybeDrain() {
  if (!AUTO_DRAIN) return;
  if (draining) return;
  const markers = await listAllMarkers();
  if (markers.length === 0) return;
  draining = true;
  try {
    console.log(`[drain] ${markers.length} pending`);
    const res = await drainPending();
    console.log(`[drain] ran=${res.ran} failed=${res.failed} skipped=${res.skipped}`);
  } catch (err) {
    console.error("[drain] error:", err);
    await audit("ERROR", `drain failed: ${err instanceof Error ? err.message : String(err)}`);
  } finally {
    draining = false;
  }
}

async function safePollJira() {
  if (!isWorkHours()) return;
  try {
    const { newActive, newBacklog } = await pollJira();
    console.log(`[jira] active=${newActive} backlog=${newBacklog}`);
    if (newActive > 0) maybeDrain();
  } catch (err) {
    console.error("[jira] error:", err);
    await audit("ERROR", `Jira poll failed: ${err instanceof Error ? err.message : String(err)}`);
  }
}

async function safePollPRs() {
  if (!isWorkHours()) return;
  try {
    const result = await pollPRs();
    console.log(
      `[prs] open=${result.openCount} merged=${result.closedMerged} unmerged=${result.closedUnmerged} new_comments=${result.newCommentCount}`,
    );
    if (result.newCommentCount > 0) maybeDrain();
  } catch (err) {
    console.error("[prs] error:", err);
    await audit("ERROR", `PR poll failed: ${err instanceof Error ? err.message : String(err)}`);
  }
}

async function ensureDirs() {
  await mkdir(PENDING_CLASSIFY, { recursive: true });
  await mkdir(PENDING_IMPLEMENT, { recursive: true });
  await mkdir(PENDING_ANALYZE_PR, { recursive: true });
}

async function main() {
  // Safety net — log and continue instead of crashing
  process.on("uncaughtException", (err) => {
    console.error("[uncaught]", err);
    audit("ERROR", `uncaught: ${err.message}`).catch(() => {});
  });
  process.on("unhandledRejection", (reason) => {
    console.error("[unhandled-rejection]", reason);
    audit("ERROR", `rejection: ${reason instanceof Error ? reason.message : String(reason)}`).catch(() => {});
  });

  await ensureDirs();
  await audit("START", "workflow server started");
  console.log(`[server] pid=${process.pid} jira=${JIRA_INTERVAL_MS}ms pr=${PR_INTERVAL_MS}ms`);

  // Reconcile orphans from previous server instance
  try {
    const r = await reconcileOrphans();
    if (r.stillRunning + r.reconciledOk + r.reconciledFail > 0) {
      console.log(
        `[reconcile] stillRunning=${r.stillRunning} reconciledOk=${r.reconciledOk} reconciledFail=${r.reconciledFail}`,
      );
    }
  } catch (err) {
    console.error("[reconcile] error:", err);
  }

  startDashboard();

  // Initial poll on startup
  await safePollJira();
  await safePollPRs();

  setInterval(safePollJira, JIRA_INTERVAL_MS);
  setInterval(safePollPRs, PR_INTERVAL_MS);
  setInterval(async () => {
    try {
      const r = await checkStale();
      if (r.warnings.length > 0) {
        console.log(`[stale] ${r.warnings.length} warning(s)`);
      }
    } catch (err) {
      console.error("[stale] error:", err);
    }
  }, STALE_INTERVAL_MS);

  // Slack drain — posts queued audit events to #your-automation-channel every 5 min
  setInterval(async () => {
    try {
      const ran = await drainSlack();
      if (ran) console.log("[slack-drain] invoked");
    } catch (err) {
      console.error("[slack-drain] error:", err);
    }
  }, SLACK_DRAIN_INTERVAL_MS);

  // Pending drain — picks up markers from slash commands (/wf-approve, /wf-feed)
  setInterval(maybeDrain, DRAIN_INTERVAL_MS);

  // Keep alive
  process.on("SIGINT", async () => {
    await audit("STOP", "workflow server received SIGINT");
    console.log("[server] shutting down");
    process.exit(0);
  });
  process.on("SIGTERM", async () => {
    await audit("STOP", "workflow server received SIGTERM");
    console.log("[server] shutting down");
    process.exit(0);
  });
}

main().catch((err) => {
  console.error("[server] fatal:", err);
  process.exit(1);
});
