import { execSync } from "child_process";
import { existsSync } from "node:fs";
import { join } from "node:path";

const benchmarks = ["bun", "go"];

const commandArgs = benchmarks
  .map((bench) => {
    const exe = existsSync(join(bench, "main.exe")) ? "main.exe" : "main";
    return `-n ${bench} "${join(bench, exe)}"`;
  })
  .join(" ");

const hyperfineCmd = `hyperfine --runs 1 --warmup 0 ${commandArgs}`;
execSync(hyperfineCmd, { stdio: "inherit" });
