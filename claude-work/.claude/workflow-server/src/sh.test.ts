import { describe, it, expect } from "bun:test";
import { sh, shJson } from "./sh.js";

describe("sh", () => {
  it("runs echo", async () => {
    const out = await sh("echo", ["hello"]);
    expect(out.trim()).toBe("hello");
  });

  it("throws on non-zero exit", async () => {
    await expect(sh("false")).rejects.toThrow();
  });

  it("parses JSON output", async () => {
    const obj = await shJson<{ a: number }>("echo", ['{"a":1}']);
    expect(obj.a).toBe(1);
  });
});
