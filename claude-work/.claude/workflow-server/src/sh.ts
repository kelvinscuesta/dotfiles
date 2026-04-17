/** Run a shell command, return stdout as string. Throws on non-zero exit. */
export async function sh(cmd: string, args: string[] = []): Promise<string> {
  const proc = Bun.spawn([cmd, ...args], {
    stdout: "pipe",
    stderr: "pipe",
    env: process.env as Record<string, string>,
  });
  const [stdout, stderr, exit] = await Promise.all([
    new Response(proc.stdout).text(),
    new Response(proc.stderr).text(),
    proc.exited,
  ]);
  if (exit !== 0) {
    throw new Error(`${cmd} exited ${exit}: ${stderr.trim()}`);
  }
  return stdout;
}

export async function shJson<T = unknown>(cmd: string, args: string[] = []): Promise<T> {
  const out = await sh(cmd, args);
  return JSON.parse(out);
}
