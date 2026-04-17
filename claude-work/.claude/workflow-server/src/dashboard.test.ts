import { describe, it, expect, afterAll } from "bun:test";
import { mkdtemp, rm, writeFile, copyFile, mkdir } from "node:fs/promises";
import { tmpdir, homedir } from "node:os";
import { join } from "node:path";

const tmpDir = await mkdtemp(join(tmpdir(), "wf-dash-"));
const tmpQueue = join(tmpDir, "queue.json");
const tmpAudit = join(tmpDir, "audit.log");
const tmpScripts = join(tmpDir, "scripts");
const tmpStatus = join(tmpDir, "status.html");
const tmpTemplates = join(tmpDir, "templates");

process.env.QUEUE_FILE = tmpQueue;
process.env.AUDIT_LOG = tmpAudit;
process.env.SCRIPTS_DIR = tmpScripts;
process.env.STATUS_HTML = tmpStatus;
process.env.WORKFLOW_DIR = tmpDir;
process.env.DASHBOARD_PORT = "0"; // let Bun pick any free port

await writeFile(tmpQueue, JSON.stringify({
  version: 1, last_updated: null, workflow_state: "running",
  tickets: [{ id: "TEST-1", title: "test ticket", status: "new", url: "https://example.com", issue_type: "Task", priority: "Medium" }],
  backlog: [], prs: [], completed: [],
}, null, 2));

// Copy real scripts + templates so update-dashboard.sh can run
const realWorkflow = join(homedir(), ".claude", "workflow");
await mkdir(tmpScripts, { recursive: true });
await mkdir(tmpTemplates, { recursive: true });
for (const name of ["poll-jira.sh", "poll-prs.sh", "check-ci.sh", "audit.sh", "update-dashboard.sh"]) {
  try {
    await copyFile(join(realWorkflow, "scripts", name), join(tmpScripts, name));
    await Bun.$`chmod +x ${join(tmpScripts, name)}`.quiet();
  } catch { /* skip */ }
}
try {
  await copyFile(join(realWorkflow, "templates", "status.html"), join(tmpTemplates, "status.html"));
} catch { /* skip */ }

const { startDashboard } = await import("./dashboard.js");

afterAll(async () => {
  await rm(tmpDir, { recursive: true, force: true });
});

describe("dashboard http", () => {
  const server = startDashboard(0);
  const base = `http://localhost:${server.port}`;

  it("health endpoint", async () => {
    const res = await fetch(`${base}/health`);
    const json = await res.json() as { ok: boolean };
    expect(res.status).toBe(200);
    expect(json.ok).toBe(true);
  });

  it("status.json returns queue", async () => {
    const res = await fetch(`${base}/status.json`);
    const json = await res.json() as { tickets: Array<{ id: string }> };
    expect(res.status).toBe(200);
    expect(json.tickets).toHaveLength(1);
    expect(json.tickets[0]!.id).toBe("TEST-1");
  });

  it("404 on unknown path", async () => {
    const res = await fetch(`${base}/nope`);
    expect(res.status).toBe(404);
  });

  it("renders HTML at /", async () => {
    const res = await fetch(`${base}/`);
    expect(res.status).toBe(200);
    const html = await res.text();
    expect(html).toContain("Dev Workflow");
  }, 15000);

  // cleanup at end
  it("stop server", () => {
    server.stop();
    expect(true).toBe(true);
  });
});
