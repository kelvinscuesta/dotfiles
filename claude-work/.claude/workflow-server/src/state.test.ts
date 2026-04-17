import { describe, it, expect, beforeEach, afterAll } from "bun:test";
import { writeFile, mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";

const tmpDir = await mkdtemp(join(tmpdir(), "wf-state-"));
const tmpQueue = join(tmpDir, "queue.json");
process.env.QUEUE_FILE = tmpQueue;

async function initQueue() {
  await writeFile(tmpQueue, JSON.stringify({
    version: 1,
    last_updated: null,
    workflow_state: "stopped",
    tickets: [],
    backlog: [],
    prs: [],
    completed: [],
  }, null, 2));
}

await initQueue();
const { readQueue, updateQueue } = await import("./state.js");

afterAll(async () => {
  await rm(tmpDir, { recursive: true, force: true });
});

describe("state", () => {
  beforeEach(initQueue);

  it("reads empty queue", async () => {
    const q = await readQueue();
    expect(q.tickets).toEqual([]);
    expect(q.workflow_state).toBe("stopped");
  });

  it("updates and persists", async () => {
    await updateQueue((q) => {
      q.workflow_state = "running";
      q.tickets.push({
        id: "TEST-1",
        title: "test",
        status: "new",
        url: "https://example.com",
      });
      return q;
    });
    const q = await readQueue();
    expect(q.workflow_state).toBe("running");
    expect(q.tickets).toHaveLength(1);
    expect(q.tickets[0]!.id).toBe("TEST-1");
    expect(q.last_updated).toBeTruthy();
  });

  it("serializes concurrent updates", async () => {
    await Promise.all(
      Array.from({ length: 10 }, (_, i) =>
        updateQueue((q) => {
          q.tickets.push({
            id: `TEST-${i}`,
            title: `t${i}`,
            status: "new",
            url: "",
          });
          return q;
        }),
      ),
    );
    const q = await readQueue();
    expect(q.tickets).toHaveLength(10);
    const ids = new Set(q.tickets.map((t) => t.id));
    expect(ids.size).toBe(10);
  });
});
