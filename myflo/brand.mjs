#!/usr/bin/env node
// Apply and verify the narrow MyFlo branding patch on the pinned bb-app package.
// Node port of flo-agent's services/myflo_ide/branding.py, so a Mac needs no Python.

import { copyFileSync, existsSync, readFileSync, readdirSync, statSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const UPSTREAM_NAME = "bb";
const BRAND_NAME = "MyFlo";
const EXPECTED_VERSION = "0.46.1";

class BrandingError extends Error {}

function appRoot(prefix) {
  const packageRoot = join(prefix, "node_modules", "bb-app");
  let version;
  try {
    version = JSON.parse(readFileSync(join(packageRoot, "package.json"), "utf8")).version;
  } catch {
    throw new BrandingError(`cannot verify pinned bb-app package at ${packageRoot}`);
  }
  if (version !== EXPECTED_VERSION) {
    throw new BrandingError(`refusing to patch bb-app ${version}; expected pinned ${EXPECTED_VERSION}`);
  }
  const root = join(packageRoot, "app", "dist");
  if (!existsSync(root) || !statSync(root).isDirectory()) {
    throw new BrandingError(`bb-app assets are missing at ${root}`);
  }
  return root;
}

const count = (text, needle) => text.split(needle).length - 1;

function htmlState(text) {
  const has = (name) =>
    count(text, `content="${name}"`) === 1 && count(text, `<title>${name}</title>`) === 1;
  const upstream = has(UPSTREAM_NAME);
  const branded = has(BRAND_NAME);
  if (upstream && !branded) return "upstream";
  if (branded && !upstream) return "branded";
  return "unexpected";
}

function manifestState(text) {
  let payload;
  try {
    payload = JSON.parse(text);
  } catch {
    return "unexpected";
  }
  if (payload.name === UPSTREAM_NAME && payload.short_name === UPSTREAM_NAME) return "upstream";
  if (payload.name === BRAND_NAME && payload.short_name === BRAND_NAME) return "branded";
  return "unexpected";
}

function assets(prefix) {
  const root = appRoot(prefix);
  const manifests = readdirSync(root)
    .filter((name) => /^manifest.*\.webmanifest$/.test(name))
    .sort()
    .map((name) => [join(root, name), manifestState]);
  if (manifests.length === 0) {
    throw new BrandingError("bb-app has no manifest*.webmanifest assets to patch");
  }
  return [[join(root, "index.html"), htmlState], ...manifests];
}

function patched(path, text) {
  if (path.endsWith("index.html")) {
    return text
      .replace(`content="${UPSTREAM_NAME}"`, `content="${BRAND_NAME}"`)
      .replace(`<title>${UPSTREAM_NAME}</title>`, `<title>${BRAND_NAME}</title>`);
  }
  const payload = JSON.parse(text);
  payload.name = BRAND_NAME;
  payload.short_name = BRAND_NAME;
  return `${JSON.stringify(payload, null, 2)}\n`;
}

function applyBranding(prefix) {
  for (const [path, stateFn] of assets(prefix)) {
    if (!existsSync(path)) throw new BrandingError(`expected bb-app asset is missing: ${path}`);
    const backup = `${path}.orig`;
    const current = readFileSync(path, "utf8");
    if (existsSync(backup)) {
      const original = readFileSync(backup, "utf8");
      if (stateFn(original) !== "upstream") {
        throw new BrandingError(`original backup no longer matches pinned bb-app: ${backup}`);
      }
      if (stateFn(current) === "branded") continue;
      if (current !== original) {
        throw new BrandingError(`refusing to overwrite unexpectedly changed asset: ${path}`);
      }
    } else {
      if (stateFn(current) !== "upstream") {
        throw new BrandingError(`pinned bb-app branding target changed unexpectedly: ${path}`);
      }
      copyFileSync(path, backup);
    }
    writeFileSync(path, patched(path, current), "utf8");
  }
  verifyBranding(prefix);
}

function verifyBranding(prefix) {
  for (const [path, stateFn] of assets(prefix)) {
    const backup = `${path}.orig`;
    if (!existsSync(backup)) throw new BrandingError(`branding backup is missing: ${backup}`);
    if (stateFn(readFileSync(backup, "utf8")) !== "upstream") {
      throw new BrandingError(`branding backup does not match pinned bb-app: ${backup}`);
    }
    if (stateFn(readFileSync(path, "utf8")) !== "branded") {
      throw new BrandingError(`MyFlo branding verification failed: ${path}`);
    }
  }
}

const [command, flag, prefix] = process.argv.slice(2);
if (!["apply", "verify"].includes(command) || flag !== "--prefix" || !prefix) {
  console.error("usage: brand.mjs apply|verify --prefix <app prefix>");
  process.exit(64);
}
try {
  if (command === "apply") applyBranding(prefix);
  else verifyBranding(prefix);
} catch (error) {
  if (!(error instanceof BrandingError)) throw error;
  console.error(`brand.mjs: ${error.message}`);
  process.exit(1);
}
console.log(`MyFlo branding ${command}: ok`);
