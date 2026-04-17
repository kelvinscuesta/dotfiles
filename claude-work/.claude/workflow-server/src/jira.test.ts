import { describe, it, expect, afterAll, beforeEach } from "bun:test";
import { mkdtemp, rm, writeFile, readFile, chmod } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";

const tmp = await mkdtemp(join(tmpdir(), "wf-jira-"));
const fakeAcli = join(tmp, "fake-acli");
const stateFile = join(tmp, "state.json");
const callLog = join(tmp, "calls.log");

process.env.ACLI_BIN = fakeAcli;
process.env.ACLI_STATE = stateFile;
process.env.ACLI_CALLS = callLog;

// Fake acli: reads "state.json" for current status and a "transition_fails" flag.
// Logs each invocation's args to calls.log.
// Commands handled:
//   jira workitem view <KEY> --json   -> prints {"fields":{"status":{"name": <status>}}}
//   jira workitem transition --key <KEY> --status <S> --yes
//     -> if transition_fails: exit 1 with stderr
//     -> else: updates state.json and exits 0
const BUN = process.execPath; // path to the currently-running bun binary
const script = `#!${BUN}
import { readFileSync, writeFileSync, appendFileSync } from "node:fs";
const args = process.argv.slice(2);
const state = JSON.parse(readFileSync(process.env.ACLI_STATE, "utf8"));
appendFileSync(process.env.ACLI_CALLS, JSON.stringify(args) + "\\n");
if (args[0] === "jira" && args[1] === "workitem" && args[2] === "view") {
  const key = args[3];
  const status = state.tickets[key] ?? "To Do";
  process.stdout.write(JSON.stringify({ fields: { status: { name: status } } }));
  process.exit(0);
}
if (args[0] === "jira" && args[1] === "workitem" && args[2] === "transition") {
  const keyIdx = args.indexOf("--key");
  const statusIdx = args.indexOf("--status");
  const key = args[keyIdx + 1];
  const status = args[statusIdx + 1];
  if (state.transition_fails) {
    process.stderr.write("transition not allowed");
    process.exit(1);
  }
  state.tickets[key] = status;
  writeFileSync(process.env.ACLI_STATE, JSON.stringify(state));
  process.exit(0);
}
process.stderr.write("unknown cmd: " + args.join(" "));
process.exit(2);
`;

await writeFile(fakeAcli, script);
await chmod(fakeAcli, 0o755);

const { getCurrentStatus, transitionTicket } = await import("./jira.js");

async function setState(s: { tickets: Record<string, string>; transition_fails?: boolean }) {
  await writeFile(stateFile, JSON.stringify(s));
  await writeFile(callLog, "");
}
async function calls(): Promise<string[][]> {
  const raw = await readFile(callLog, "utf8");
  return raw.trim().split("\n").filter(Boolean).map((l) => JSON.parse(l));
}

beforeEach(async () => {
  await writeFile(callLog, "");
});

afterAll(async () => {
  await rm(tmp, { recursive: true, force: true });
});

describe("jira", () => {
  it("getCurrentStatus parses status from acli view --json", async () => {
    await setState({ tickets: { "PAY-1": "To Do" } });
    const status = await getCurrentStatus("PAY-1");
    expect(status).toBe("To Do");
    const c = await calls();
    expect(c[0]).toEqual(["jira", "workitem", "view", "PAY-1", "--json"]);
  });

  it("transitionTicket issues the right shell call + reports before/after", async () => {
    await setState({ tickets: { "PAY-2": "In Progress" } });
    const r = await transitionTicket("PAY-2", "In Review");
    expect(r.ok).toBe(true);
    expect(r.previous).toBe("In Progress");
    expect(r.current).toBe("In Review");
    const c = await calls();
    const transitionCall = c.find((a) => a[2] === "transition");
    expect(transitionCall).toEqual([
      "jira", "workitem", "transition",
      "--key", "PAY-2", "--status", "In Review", "--yes",
    ]);
  });

  it("transitionTicket no-op when already at target", async () => {
    await setState({ tickets: { "PAY-3": "In Review" } });
    const r = await transitionTicket("PAY-3", "In Review");
    expect(r.ok).toBe(true);
    expect(r.previous).toBe("In Review");
    expect(r.current).toBe("In Review");
    const c = await calls();
    // only view, no transition
    expect(c.some((a) => a[2] === "transition")).toBe(false);
  });

  it("returns ok:false when acli transition fails (not throws)", async () => {
    await setState({ tickets: { "PAY-4": "To Do" }, transition_fails: true });
    const r = await transitionTicket("PAY-4", "In Review");
    expect(r.ok).toBe(false);
    expect(r.previous).toBe("To Do");
    expect(r.current).toBe("To Do");
    expect(r.error).toBeDefined();
  });
});
