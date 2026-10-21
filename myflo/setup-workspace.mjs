#!/usr/bin/env node
// Runs on every `myflo start`. First run: activate the MyFlo theme and register ~/MyFlo
// as a project. Every run: make sure Flo (Flo Agent over ACP) is an agent in MyFlo.
// Runs from the `myflo` launcher with BB_SERVER_URL/BB_DATA_DIR already exported.

import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, writeFileSync } from "node:fs";
import { homedir, hostname } from "node:os";
import { join } from "node:path";

const home = process.env.MYFLO_HOME ?? join(homedir(), ".myflo");
const cli = join(home, "app", "node_modules", "bb-app", "dist", "bb.js");
const workspace = process.env.MYFLO_WORKSPACE ?? join(homedir(), "MyFlo");
const marker = join(process.env.BB_DATA_DIR ?? join(home, "data"), ".myflo-setup-done");
// Flo Agent's installer puts `hermes-acp` (its ACP server) in ~/.local/bin.
const FLO_AGENT = {
  id: "flo",
  displayName: "Flo",
  command: join(homedir(), ".local", "bin", "hermes-acp"),
  nativeSkillRoots: { user: [".hermes/skills"] },
};

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

function readCustomAgents() {
  const raw = bb(["plugin", "config", "provider-acp"])?.values?.customAgents;
  const value = raw ? JSON.parse(raw) : [];
  return Array.isArray(value) ? value : [];
}

// The ACP plugin loads a few seconds after the server starts answering, so retry.
async function ensureFloAgent() {
  for (let attempt = 0; attempt < 60; attempt += 1) {
    try {
      const agents = readCustomAgents();
      const existing = agents.find((agent) => agent?.id === FLO_AGENT.id);
      if (JSON.stringify(existing) === JSON.stringify(FLO_AGENT)) return;
      const others = agents.filter((agent) => agent?.id !== FLO_AGENT.id);
      bb(["plugin", "config", "provider-acp", "set", "customAgents", JSON.stringify([...others, FLO_AGENT])]);
      return;
    } catch (error) {
      if (attempt === 59) console.error(`MyFlo: could not add Flo as an agent yet: ${error.message}`);
      await sleep(1000);
    }
  }
}

await ensureFloAgent();
if (existsSync(marker)) process.exit(0);

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
writeFileSync(marker, "");
console.log(`MyFlo first-run setup: ok (workspace ${workspace})`);
