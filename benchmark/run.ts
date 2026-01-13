import { execSync } from "child_process";
import { existsSync } from "node:fs";
import { join } from "node:path";

const benchmarks = ["bun", "go", "zig"];

const commandArgs = benchmarks
  .map((bench) => {
    const exe = existsSync(join(bench, "main.exe")) ? "main.exe" : "main";
    return `-n ${bench} "${join(bench, exe)}"`;
  })
  .join(" ");

const hyperfineCmd = `hyperfine --warmup 1 ${commandArgs}`;
execSync(hyperfineCmd, { stdio: "inherit" });
