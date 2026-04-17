import { describe, it, expect, afterAll } from "bun:test";
import { mkdtemp, rm, readFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";

const tmpDir = await mkdtemp(join(tmpdir(), "wf-runner-"));
const logDir = join(tmpDir, "logs");
process.env.PENDING_DIR = tmpDir;
process.env.AUDIT_LOG = join(tmpDir, "audit.log");
process.env.RUNNER_LOG_DIR = logDir;
// Point CLAUDE_BIN at echo so the runner exits cleanly without touching real Claude
process.env.CLAUDE_BIN = "/bin/echo";

const { runMarker, drainPending } = await import("./runner.js");
const { writeMarker, hasMarker, listAllMarkers } = await import("./pending.js");

afterAll(async () => {
  await rm(tmpDir, { recursive: true, force: true });
});

describe("runner", () => {
  it("runs marker with success → deletes marker + writes log", async () => {
    const marker = {
      kind: "classify" as const,
      ticket_id: "PAY-42",
      created_at: "2026-04-17T00:00:00Z",
    };
    await writeMarker(marker);
    expect(await hasMarker(marker)).toBe(true);

    const result = await runMarker(marker);
    expect(result.ok).toBe(true);
    expect(result.exitCode).toBe(0);
    expect(await hasMarker(marker)).toBe(false); // marker consumed

    const log = await readFile(result.logPath, "utf8");
    expect(log).toContain("classify: /wf-classify PAY-42");
    expect(log).toContain("exit=0");
  });

  it("drainPending processes all markers", async () => {
    await writeMarker({ kind: "classify", ticket_id: "PAY-101", created_at: "t" });
    await writeMarker({ kind: "classify", ticket_id: "PAY-102", created_at: "t" });
    await writeMarker({
      kind: "analyze-pr", repo: "owner/repo", pr_number: 1, new_comment_count: 1, created_at: "t",
    });

    const before = await listAllMarkers();
    expect(before.length).toBeGreaterThanOrEqual(3);

    const res = await drainPending();
    expect(res.ran).toBeGreaterThanOrEqual(3);
    expect(res.failed).toBe(0);

    const after = await listAllMarkers();
    expect(after).toHaveLength(0);
  });

  it("non-zero exit leaves marker in place", async () => {
    process.env.CLAUDE_BIN = "/usr/bin/false"; // always exits 1
    const marker = {
      kind: "classify" as const,
      ticket_id: "PAY-999",
      created_at: "t",
    };
    await writeMarker(marker);

    const result = await runMarker(marker);
    expect(result.ok).toBe(false);
    expect(await hasMarker(marker)).toBe(true); // marker preserved for retry

    process.env.CLAUDE_BIN = "/bin/echo"; // restore
  });
});
