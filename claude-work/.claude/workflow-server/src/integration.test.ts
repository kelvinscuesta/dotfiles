import { describe, it, expect, afterAll } from "bun:test";
import { mkdtemp, rm, writeFile, mkdir, copyFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { homedir } from "node:os";

const tmpDir = await mkdtemp(join(tmpdir(), "wf-integ-"));
const tmpQueue = join(tmpDir, "queue.json");
const tmpAudit = join(tmpDir, "audit.log");
const tmpScripts = join(tmpDir, "scripts");

// Point the server at a tmp workflow dir, but reuse real scripts for the subprocess layer.
process.env.QUEUE_FILE = tmpQueue;
process.env.AUDIT_LOG = tmpAudit;
process.env.SCRIPTS_DIR = tmpScripts;

const realScripts = join(homedir(), ".claude", "workflow", "scripts");

// Seed empty queue
await writeFile(
  tmpQueue,
  JSON.stringify(
    { version: 1, last_updated: null, workflow_state: "running", tickets: [], backlog: [], prs: [], completed: [] },
    null,
    2,
  ),
);

// Symlink real scripts into tmp dir
await mkdir(tmpScripts, { recursive: true });
for (const name of ["poll-jira.sh", "poll-prs.sh", "check-ci.sh", "audit.sh", "update-dashboard.sh"]) {
  try {
    await copyFile(join(realScripts, name), join(tmpScripts, name));
    await Bun.$`chmod +x ${join(tmpScripts, name)}`.quiet();
  } catch {
    /* skip if missing */
  }
}

afterAll(async () => {
  await rm(tmpDir, { recursive: true, force: true });
});

describe("integration: real scripts", () => {
  it("poll-jira integrates tickets from acli", async () => {
    const { pollJira } = await import("./poll-jira.js");
    const { readQueue } = await import("./state.js");
    const result = await pollJira();
    const q = await readQueue();
    // Just verify it ran without error and queue was touched
    expect(result.newActive).toBeGreaterThanOrEqual(0);
    expect(q.last_updated).toBeTruthy();
  }, 30000);

  it("poll-prs integrates PRs + CI", async () => {
    const { pollPRs } = await import("./poll-prs.js");
    const { readQueue } = await import("./state.js");
    const result = await pollPRs();
    const q = await readQueue();
    expect(result.openCount).toBeGreaterThanOrEqual(0);
    expect(Array.isArray(q.prs)).toBe(true);
    if (q.prs.length > 0) {
      expect(q.prs[0]!.ci).toBeDefined();
      expect(typeof q.prs[0]!.ci!.status).toBe("string");
    }
  }, 60000);
});
