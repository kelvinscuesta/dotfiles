import { describe, it, expect, afterAll } from "bun:test";
import { readFile, mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";

const tmpDir = await mkdtemp(join(tmpdir(), "wf-audit-"));
const tmpAudit = join(tmpDir, "audit.log");
process.env.AUDIT_LOG = tmpAudit;

const { audit } = await import("./audit.js");

afterAll(async () => {
  await rm(tmpDir, { recursive: true, force: true });
});

describe("audit", () => {
  it("appends timestamped line", async () => {
    await audit("TEST", "hello world");
    const content = await readFile(tmpAudit, "utf8");
    expect(content).toMatch(/\[TEST\] hello world/);
    expect(content).toMatch(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2} /);
  });

  it("appends multiple entries", async () => {
    await audit("A", "one");
    await audit("B", "two");
    const content = await readFile(tmpAudit, "utf8");
    const lines = content.trim().split("\n");
    expect(lines.length).toBeGreaterThanOrEqual(3);
  });
});
