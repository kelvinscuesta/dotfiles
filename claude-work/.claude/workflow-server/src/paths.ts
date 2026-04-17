import { join } from "node:path";
import { homedir } from "node:os";

const defaultDir = join(homedir(), ".claude", "workflow");

export const WORKFLOW_DIR = process.env.WORKFLOW_DIR ?? defaultDir;
export const SCRIPTS_DIR = process.env.SCRIPTS_DIR ?? join(WORKFLOW_DIR, "scripts");
export const QUEUE_FILE = process.env.QUEUE_FILE ?? join(WORKFLOW_DIR, "queue.json");
export const AUDIT_LOG = process.env.AUDIT_LOG ?? join(WORKFLOW_DIR, "audit.log");
export const STATUS_HTML = process.env.STATUS_HTML ?? join(WORKFLOW_DIR, "status.html");
export const PENDING_DIR = process.env.PENDING_DIR ?? join(WORKFLOW_DIR, "pending");
export const PENDING_CLASSIFY = join(PENDING_DIR, "classify");
export const PENDING_IMPLEMENT = join(PENDING_DIR, "implement");
export const PENDING_ANALYZE_PR = join(PENDING_DIR, "analyze-pr");

export const POLL_JIRA_SH = join(SCRIPTS_DIR, "poll-jira.sh");
export const POLL_PRS_SH = join(SCRIPTS_DIR, "poll-prs.sh");
export const CHECK_CI_SH = join(SCRIPTS_DIR, "check-ci.sh");
export const AUDIT_SH = join(SCRIPTS_DIR, "audit.sh");
export const UPDATE_DASHBOARD_SH = join(SCRIPTS_DIR, "update-dashboard.sh");
