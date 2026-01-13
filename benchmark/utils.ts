import { existsSync } from "node:fs";

export function getHyperfineCmd() {
  const mainExe = existsSync("main.exe") ? "main.exe" : "main";
  const hyperfineCmd = `hyperfine --warmup 10 "${mainExe}"`;
  return hyperfineCmd;
}
