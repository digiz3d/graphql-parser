import { execSync } from "child_process";
import { existsSync } from "node:fs";
import { join } from "node:path";

const bench = "zig";
const exe = existsSync(join(bench, "main.exe")) ? "main.exe" : "main";
const commandArgs = `-n ${bench} "${join(bench, exe)}"`;

const hyperfineCmd = `hyperfine --warmup 1 ${commandArgs}`;
execSync(hyperfineCmd, { stdio: "inherit" });
