#!/usr/bin/env node
// First-run setup: activate the MyFlo theme and register ~/MyFlo as a project.
// Runs from the `myflo` launcher with BB_SERVER_URL/BB_DATA_DIR already exported.

import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, writeFileSync } from "node:fs";
import { homedir, hostname } from "node:os";
import { join } from "node:path";

const home = process.env.MYFLO_HOME ?? join(homedir(), ".myflo");
const cli = join(home, "app", "node_modules", "bb-app", "dist", "bb.js");
const workspace = process.env.MYFLO_WORKSPACE ?? join(homedir(), "MyFlo");

function bb(args) {
  const result = spawnSync(process.execPath, [cli, ...args, "--json"], {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
    timeout: 30_000,
  });
  if (result.status !== 0) {
    throw new Error(`myflo ${args.join(" ")} failed: ${(result.stderr || result.stdout).trim()}`);
  }
  return result.stdout.trim() ? JSON.parse(result.stdout) : null;
}

const list = (payload, key) => (Array.isArray(payload) ? payload : (payload?.[key] ?? []));
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function localMachineId() {
  const local = hostname().split(".")[0];
  for (let attempt = 0; attempt < 60; attempt += 1) {
    const connected = list(bb(["machine", "list"]), "machines").filter(
      (machine) => machine.status === "connected",
    );
    const match =
      connected.find((machine) => machine.name === local) ??
      (connected.length === 1 ? connected[0] : undefined);
    if (match?.id) return String(match.id);
    await sleep(1000);
  }
  throw new Error("this computer did not connect to MyFlo within a minute");
}

bb(["theme", "set", "myflo"]);

if (!existsSync(workspace)) {
  mkdirSync(workspace, { recursive: true });
  writeFileSync(
    join(workspace, "README.md"),
    "# MyFlo workspace\n\nStart a thread here for anything that isn't tied to a repo.\n",
  );
  spawnSync("git", ["init", "-q"], { cwd: workspace, stdio: "ignore" });
}

const projects = list(bb(["project", "list"]), "projects");
const registered = projects.some((project) =>
  (project.sources ?? []).some((source) => source.path === workspace),
);
if (!registered) {
  const machine = await localMachineId();
  bb(["project", "create", "--name", "MyFlo Workspace", "--root", workspace, "--machine", machine]);
}
console.log(`MyFlo first-run setup: ok (workspace ${workspace})`);
