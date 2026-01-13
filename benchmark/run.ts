import { execSync } from "child_process";
import { existsSync } from "node:fs";
import { join } from "node:path";

const benchmarks = ["bun", "go", "zig"];

const commandArgs = benchmarks
  .flatMap((bench) => {
    const exePath = join(
      bench,
      existsSync(join(bench, "main.exe")) ? "main.exe" : "main"
    );
    return ["-n", bench, `"${exePath}"`];
  })
  .join(" ");

const hyperfineCmd = `hyperfine --warmup 10 ${commandArgs}`;
execSync(hyperfineCmd, { stdio: "inherit" });
