import { describe, it, expect, afterAll } from "bun:test";
import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";

const tmpDir = await mkdtemp(join(tmpdir(), "wf-pending-"));
process.env.PENDING_DIR = tmpDir;

const { writeMarker, deleteMarker, hasMarker, listMarkers, listAllMarkers } = await import("./pending.js");

afterAll(async () => {
  await rm(tmpDir, { recursive: true, force: true });
});

describe("pending markers", () => {
  it("writes + reads classify marker", async () => {
    const marker = {
      kind: "classify" as const,
      ticket_id: "PAY-1",
      created_at: "2026-04-17T00:00:00Z",
    };
    await writeMarker(marker);
    expect(await hasMarker(marker)).toBe(true);
    const list = await listMarkers("classify");
    expect(list).toHaveLength(1);
    expect(list[0]!.kind).toBe("classify");
    expect((list[0] as typeof marker).ticket_id).toBe("PAY-1");
  });

  it("deletes marker", async () => {
    const marker = {
      kind: "classify" as const,
      ticket_id: "PAY-2",
      created_at: "2026-04-17T00:00:00Z",
    };
    await writeMarker(marker);
    expect(await hasMarker(marker)).toBe(true);
    await deleteMarker(marker);
    expect(await hasMarker(marker)).toBe(false);
  });

  it("analyze-pr marker has repo+number filename", async () => {
    const marker = {
      kind: "analyze-pr" as const,
      repo: "Gusto/web",
      pr_number: 12345,
      new_comment_count: 3,
      created_at: "2026-04-17T00:00:00Z",
    };
    await writeMarker(marker);
    expect(await hasMarker(marker)).toBe(true);
    const list = await listMarkers("analyze-pr");
    expect(list.some((m) => m.kind === "analyze-pr" && m.pr_number === 12345)).toBe(true);
  });

  it("listAllMarkers across kinds", async () => {
    await writeMarker({ kind: "implement", ticket_id: "PAY-3", plan_path: "/p", approved_at: "t", created_at: "t" });
    const all = await listAllMarkers();
    const ids = new Set(all.map((m) => `${m.kind}`));
    expect(ids.has("classify")).toBe(true);
    expect(ids.has("implement")).toBe(true);
    expect(ids.has("analyze-pr")).toBe(true);
  });
});
