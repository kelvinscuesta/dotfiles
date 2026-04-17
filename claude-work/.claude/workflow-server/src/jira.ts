import { sh } from "./sh.js";

function acliBin(): string {
  return process.env.ACLI_BIN ?? "acli";
}

/** Read current status of a Jira work item via acli. */
export async function getCurrentStatus(ticketId: string): Promise<string> {
  const out = await sh(acliBin(), ["jira", "workitem", "view", ticketId, "--json"]);
  const data = JSON.parse(out);
  const name = data?.fields?.status?.name;
  if (typeof name !== "string") {
    throw new Error(`could not parse status for ${ticketId}`);
  }
  return name;
}

export type TransitionResult = {
  ok: boolean;
  previous: string;
  current: string;
  error?: string;
};

/**
 * Attempt to transition a ticket to the target status.
 * Returns {ok:false, ...} on failure rather than throwing (transitions
 * can fail if the current workflow doesn't allow the target status).
 */
export async function transitionTicket(
  ticketId: string,
  targetStatus: string,
): Promise<TransitionResult> {
  let previous = "";
  try {
    previous = await getCurrentStatus(ticketId);
  } catch (err) {
    return {
      ok: false,
      previous: "",
      current: "",
      error: err instanceof Error ? err.message : String(err),
    };
  }

  if (previous === targetStatus) {
    return { ok: true, previous, current: previous };
  }

  try {
    await sh(acliBin(), [
      "jira",
      "workitem",
      "transition",
      "--key",
      ticketId,
      "--status",
      targetStatus,
      "--yes",
    ]);
  } catch (err) {
    return {
      ok: false,
      previous,
      current: previous,
      error: err instanceof Error ? err.message : String(err),
    };
  }

  let current = previous;
  try {
    current = await getCurrentStatus(ticketId);
  } catch {
    // transition cmd succeeded but re-read failed; still treat as ok
  }
  return { ok: current === targetStatus, previous, current };
}
