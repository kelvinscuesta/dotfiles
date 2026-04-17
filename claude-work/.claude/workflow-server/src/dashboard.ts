import { readFile, stat, mkdir, writeFile } from "node:fs/promises";
import { watch } from "node:fs";
import { join } from "node:path";
import * as paths from "./paths.js";
import { sh } from "./sh.js";
import { readQueue, updateQueue } from "./state.js";
import { listAllMarkers, readRunState, writeMarker } from "./pending.js";
import { audit } from "./audit.js";
import { drainPending } from "./runner.js";

const CACHE_TTL_MS = 3000;
let cached: { html: string; ts: number } | null = null;

/**
 * SSE stream of the audit log tail. Sends last 20 lines on connect,
 * then streams new lines as they're appended.
 */
/** SSE stream of a specific log file — follows appends, safe against cancel. */
function streamLogFile(filePath: string): Response {
  const encoder = new TextEncoder();
  let closed = false;
  let heartbeat: ReturnType<typeof setInterval> | null = null;
  let watcher: ReturnType<typeof watch> | null = null;

  const safeEnqueue = (ctl: ReadableStreamDefaultController, data: Uint8Array) => {
    if (closed) return;
    try { ctl.enqueue(data); }
    catch {
      closed = true;
      if (heartbeat) clearInterval(heartbeat);
      if (watcher) watcher.close();
    }
  };

  const stream = new ReadableStream({
    async start(controller) {
      const write = (data: string) =>
        safeEnqueue(controller, encoder.encode(`data: ${data}\n\n`));

      // Initial: send full file content
      let size = 0;
      try {
        const content = await readFile(filePath, "utf8");
        size = content.length;
        const lines = content.split("\n");
        // Cap initial backlog at 200 lines
        const tail = lines.slice(-200);
        for (const line of tail) {
          if (line) write(line);
        }
      } catch {
        write("[no log yet]");
      }

      watcher = watch(filePath, { persistent: false }, async () => {
        if (closed) return;
        try {
          const newSize = (await stat(filePath)).size;
          if (newSize > size) {
            const content = await readFile(filePath, "utf8");
            const newLines = content.slice(size).split("\n").filter(Boolean);
            for (const line of newLines) write(line);
            size = newSize;
          } else if (newSize < size) {
            size = newSize;
          }
        } catch { /* transient */ }
      });

      heartbeat = setInterval(() => {
        safeEnqueue(controller, encoder.encode(": heartbeat\n\n"));
      }, 20000);
    },
    cancel() {
      closed = true;
      if (heartbeat) clearInterval(heartbeat);
      if (watcher) watcher.close();
    },
  });

  return new Response(stream, {
    headers: {
      "Content-Type": "text/event-stream",
      "Cache-Control": "no-cache",
      "Connection": "keep-alive",
    },
  });
}

function streamAuditLog(): Response {
  const encoder = new TextEncoder();
  const auditPath = process.env.AUDIT_LOG ?? paths.AUDIT_LOG;

  let closed = false;
  let heartbeat: ReturnType<typeof setInterval> | null = null;
  let watcher: ReturnType<typeof watch> | null = null;

  const safeEnqueue = (ctl: ReadableStreamDefaultController, data: Uint8Array) => {
    if (closed) return;
    try {
      ctl.enqueue(data);
    } catch {
      // Controller closed — stop sending
      closed = true;
      if (heartbeat) clearInterval(heartbeat);
      if (watcher) watcher.close();
    }
  };

  const stream = new ReadableStream({
    async start(controller) {
      const write = (data: string) =>
        safeEnqueue(controller, encoder.encode(`data: ${data}\n\n`));
      const writeEvent = (event: string, data: string) =>
        safeEnqueue(controller, encoder.encode(`event: ${event}\ndata: ${data}\n\n`));

      // Emit backlog: last 20 lines
      try {
        const content = await readFile(auditPath, "utf8");
        const lines = content.trim().split("\n").slice(-20);
        for (const line of lines) write(line);
      } catch { /* no log yet */ }

      let size = 0;
      try { size = (await stat(auditPath)).size; } catch { /* empty */ }

      watcher = watch(auditPath, { persistent: false }, async () => {
        if (closed) return;
        try {
          const newSize = (await stat(auditPath)).size;
          if (newSize > size) {
            const content = await readFile(auditPath, "utf8");
            const newLines = content.slice(size).split("\n").filter(Boolean);
            for (const line of newLines) write(line);
            size = newSize;
          } else if (newSize < size) {
            size = newSize;
            writeEvent("reset", "log-rotated");
          }
        } catch { /* transient */ }
      });

      heartbeat = setInterval(() => {
        safeEnqueue(controller, encoder.encode(": heartbeat\n\n"));
      }, 20000);
    },
    cancel() {
      closed = true;
      if (heartbeat) clearInterval(heartbeat);
      if (watcher) watcher.close();
    },
  });

  return new Response(stream, {
    headers: {
      "Content-Type": "text/event-stream",
      "Cache-Control": "no-cache",
      "Connection": "keep-alive",
    },
  });
}

async function handleAction(action: string, ticketId: string): Promise<Response> {
  const now = new Date().toISOString();
  try {
    switch (action) {
      case "approve":
      case "force-approve": {
        const force = action === "force-approve";
        let planPath: string | null = null;
        await updateQueue((q) => {
          const t = q.tickets.find((x) => x.id === ticketId);
          if (!t) throw new Error(`ticket ${ticketId} not found`);
          if (t.status !== "awaiting-approval") {
            throw new Error(`ticket status is "${t.status}" — can only approve awaiting-approval tickets`);
          }
          planPath = t.plan_path ?? null;
          t.status = "in-progress";
          t.approved_at = now;
          return q;
        });
        if (!planPath) {
          return Response.json({ ok: false, error: "no plan_path on ticket" }, { status: 400 });
        }
        await writeMarker({
          kind: "implement",
          ticket_id: ticketId,
          plan_path: planPath,
          approved_at: now,
          created_at: now,
          force,
        });
        await audit("APPROVE", `${ticketId} approved${force ? " (FORCE — ignoring blockers)" : ""} via dashboard`);
        drainPending().catch((err) => console.error("[drain]", err));
        return Response.json({
          ok: true,
          ticket: ticketId,
          marker: force ? "implement queued (force), drain started" : "implement queued, drain started",
        });
      }
      case "reject": {
        await updateQueue((q) => {
          const idx = q.tickets.findIndex((x) => x.id === ticketId);
          if (idx < 0) throw new Error(`ticket ${ticketId} not found`);
          const t = q.tickets[idx]!;
          q.completed.unshift({
            id: ticketId,
            type: "ticket",
            title: t.title,
            completed_at: now,
            disposition: "rejected",
            url: t.url,
          });
          q.tickets.splice(idx, 1);
          return q;
        });
        await audit("REJECT", `${ticketId} rejected via dashboard`);
        return Response.json({ ok: true, ticket: ticketId });
      }
      case "reclassify": {
        await updateQueue((q) => {
          const t = q.tickets.find((x) => x.id === ticketId);
          if (!t) throw new Error(`ticket ${ticketId} not found`);
          t.status = "new";
          t.plan_path = null;
          t.draft_path = null;
          t.classification = undefined;
          return q;
        });
        await writeMarker({ kind: "classify", ticket_id: ticketId, created_at: now });
        await audit("FEED", `${ticketId} reclassify via dashboard`);
        drainPending().catch((err) => console.error("[drain]", err));
        return Response.json({ ok: true, ticket: ticketId, marker: "classify queued, drain started" });
      }
      default:
        return new Response(`Unknown action: ${action}`, { status: 400 });
    }
  } catch (err) {
    return Response.json(
      { ok: false, error: err instanceof Error ? err.message : String(err) },
      { status: 400 },
    );
  }
}

/** Wrap raw markdown in an HTML page with client-side marked.js rendering. */
function renderMarkdownPage(title: string, markdown: string, rawUrl: string): string {
  const esc = (s: string) =>
    s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
  return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>${esc(title)}</title>
<style>
  :root { --bg:#0d1117; --bg2:#161b22; --border:#30363d; --text:#c9d1d9; --muted:#8b949e; --accent:#58a6ff; --success:#3fb950; --warning:#d29922; --danger:#f85149; }
  * { box-sizing:border-box; }
  body { font-family:-apple-system,BlinkMacSystemFont,"SF Pro Text",sans-serif; background:var(--bg); color:var(--text); max-width:820px; margin:0 auto; padding:32px 24px; line-height:1.55; }
  header { display:flex; justify-content:space-between; align-items:center; padding-bottom:16px; border-bottom:1px solid var(--border); margin-bottom:24px; }
  header a { color:var(--muted); font-size:12px; text-decoration:none; }
  header a:hover { color:var(--accent); }
  h1 { font-size:24px; font-weight:600; margin:0 0 16px; border-bottom:1px solid var(--border); padding-bottom:8px; }
  h2 { font-size:20px; font-weight:600; margin:32px 0 12px; }
  h3 { font-size:16px; font-weight:600; margin:24px 0 8px; color:var(--muted); text-transform:uppercase; letter-spacing:0.05em; }
  h4 { font-size:14px; font-weight:600; margin:16px 0 8px; }
  p { margin:12px 0; }
  a { color:var(--accent); text-decoration:none; }
  a:hover { text-decoration:underline; }
  code { background:var(--bg2); padding:2px 6px; border-radius:4px; font-size:13px; font-family:"SF Mono",Menlo,monospace; }
  pre { background:var(--bg2); border:1px solid var(--border); border-radius:6px; padding:12px 16px; overflow-x:auto; font-size:13px; }
  pre code { background:transparent; padding:0; }
  ul, ol { margin:12px 0; padding-left:24px; }
  li { margin:4px 0; }
  blockquote { border-left:3px solid var(--accent); padding-left:16px; margin:16px 0; color:var(--muted); }
  table { border-collapse:collapse; margin:16px 0; width:100%; }
  th, td { border:1px solid var(--border); padding:8px 12px; text-align:left; }
  th { background:var(--bg2); font-weight:600; }
  hr { border:none; border-top:1px solid var(--border); margin:24px 0; }
  input[type="checkbox"] { margin-right:6px; }
  strong { color:var(--text); }
  em { color:var(--warning); }
  .warn { color:var(--warning); }
</style>
</head>
<body>
<header>
  <a href="/">← back to dashboard</a>
  <a href="${esc(rawUrl)}" target="_blank">raw markdown</a>
</header>
<article id="content">Loading…</article>
<script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
<script id="md" type="text/markdown">${esc(markdown)}</script>
<script>
  (function() {
    const raw = document.getElementById('md').textContent;
    marked.setOptions({ breaks: true, gfm: true });
    document.getElementById('content').innerHTML = marked.parse(raw);
  })();
</script>
</body>
</html>`;
}

async function renderHtml(): Promise<string> {
  if (cached && Date.now() - cached.ts < CACHE_TTL_MS) {
    return cached.html;
  }
  await sh(paths.UPDATE_DASHBOARD_SH);
  const html = await readFile(paths.STATUS_HTML, "utf8");
  cached = { html, ts: Date.now() };
  return html;
}

export function startDashboard(port = parseInt(process.env.DASHBOARD_PORT ?? "3000", 10)) {
  const server = Bun.serve({
    port,
    idleTimeout: 255, // max; SSE connections are idle between events
    async fetch(req) {
      const url = new URL(req.url);

      // Action endpoints: POST /action/<action>/<ticket-id>
      if (req.method === "POST" && url.pathname.startsWith("/action/")) {
        const parts = url.pathname.split("/").filter(Boolean);
        const action = parts[1];
        const ticketId = parts[2];
        if (action === "drain") {
          // No id required
          drainPending().catch((err) => console.error("[drain]", err));
          return Response.json({ ok: true, message: "drain started" });
        }
        if (!action || !ticketId || ticketId.includes("..") || ticketId.includes("/")) {
          return new Response("Invalid action or id", { status: 400 });
        }
        return handleAction(action, ticketId);
      }

      if (url.pathname === "/health") {
        return Response.json({ ok: true, pid: process.pid, uptime_s: Math.floor(process.uptime()) });
      }

      if (url.pathname === "/status.json") {
        const q = await readQueue();
        // Enrich with pending markers + run state
        const markers = await listAllMarkers();
        const pending = await Promise.all(
          markers.map(async (m) => ({ marker: m, state: await readRunState(m) })),
        );
        return Response.json({ ...q, pending });
      }

      if (url.pathname === "/activity") {
        // SSE stream of audit.log tail — streams new lines as they append
        return streamAuditLog();
      }

      if (url.pathname.startsWith("/log-stream/")) {
        // SSE stream of a specific run log file
        const filename = decodeURIComponent(url.pathname.slice(12));
        if (filename.includes("..") || filename.includes("/")) {
          return new Response("Invalid log path", { status: 400 });
        }
        const logDir = process.env.RUNNER_LOG_DIR ?? `${paths.WORKFLOW_DIR}/../workflow-server/logs`;
        return streamLogFile(`${logDir}/${filename}`);
      }

      if (url.pathname.startsWith("/plan/")) {
        const id = decodeURIComponent(url.pathname.slice(6));
        if (id.includes("..") || id.includes("/")) return new Response("Invalid id", { status: 400 });
        const planPath = `${paths.WORKFLOW_DIR}/plans/${id}.md`;
        const asRaw = url.searchParams.get("raw") === "1";
        try {
          const content = await readFile(planPath, "utf8");
          if (asRaw) {
            return new Response(content, {
              headers: { "Content-Type": "text/plain; charset=utf-8" },
            });
          }
          return new Response(renderMarkdownPage(`Plan: ${id}`, content, `/plan/${id}?raw=1`), {
            headers: { "Content-Type": "text/html; charset=utf-8" },
          });
        } catch {
          return new Response(`Plan not found: ${id}`, { status: 404 });
        }
      }

      if (url.pathname.startsWith("/research/")) {
        const id = decodeURIComponent(url.pathname.slice(10));
        if (id.includes("..") || id.includes("/")) return new Response("Invalid id", { status: 400 });
        const path = `${paths.WORKFLOW_DIR}/research/${id}.md`;
        const asRaw = url.searchParams.get("raw") === "1";
        try {
          const content = await readFile(path, "utf8");
          if (asRaw) {
            return new Response(content, { headers: { "Content-Type": "text/plain; charset=utf-8" } });
          }
          return new Response(renderMarkdownPage(`Research: ${id}`, content, `/research/${id}?raw=1`), {
            headers: { "Content-Type": "text/html; charset=utf-8" },
          });
        } catch {
          return new Response(`Research not found: ${id}`, { status: 404 });
        }
      }

      if (url.pathname.startsWith("/draft/")) {
        const rest = decodeURIComponent(url.pathname.slice(7));
        if (rest.includes("..")) return new Response("Invalid path", { status: 400 });
        const filePath = `${paths.WORKFLOW_DIR}/drafts/${rest}`;
        const asRaw = url.searchParams.get("raw") === "1";
        try {
          const content = await readFile(filePath, "utf8");
          const isMarkdown = rest.endsWith(".md") || rest.endsWith(".markdown");
          if (asRaw || !isMarkdown) {
            return new Response(content, {
              headers: { "Content-Type": "text/plain; charset=utf-8" },
            });
          }
          return new Response(renderMarkdownPage(`Draft: ${rest}`, content, `/draft/${rest}?raw=1`), {
            headers: { "Content-Type": "text/html; charset=utf-8" },
          });
        } catch {
          return new Response(`Draft not found: ${rest}`, { status: 404 });
        }
      }

      if (url.pathname.startsWith("/log/")) {
        // Serve a single run log file (read-only). Path format: /log/<filename>
        const filename = decodeURIComponent(url.pathname.slice(5));
        // Guard: only allow files in the logs dir, no path traversal
        if (filename.includes("..") || filename.includes("/")) {
          return new Response("Invalid log path", { status: 400 });
        }
        const logDir = process.env.RUNNER_LOG_DIR ?? `${paths.WORKFLOW_DIR}/../workflow-server/logs`;
        try {
          const content = await readFile(`${logDir}/${filename}`, "utf8");
          return new Response(content, {
            headers: { "Content-Type": "text/plain; charset=utf-8" },
          });
        } catch {
          return new Response("Log not found", { status: 404 });
        }
      }

      if (url.pathname === "/" || url.pathname === "/status.html") {
        try {
          const html = await renderHtml();
          return new Response(html, {
            headers: { "Content-Type": "text/html; charset=utf-8" },
          });
        } catch (err) {
          return new Response(
            `<pre>Dashboard render failed: ${err instanceof Error ? err.message : String(err)}</pre>`,
            { status: 500, headers: { "Content-Type": "text/html" } },
          );
        }
      }

      return new Response("Not Found", { status: 404 });
    },
  });

  console.log(`[dashboard] listening on http://localhost:${server.port}`);
  return server;
}
