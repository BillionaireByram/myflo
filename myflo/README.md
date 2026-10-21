# MyFlo

MyFlo is DigitalFlo's local agent IDE: a renamed build of [bb](https://github.com/get-bb/bb)
(MIT) that runs on your own Mac, drives Claude Code, controls the computer, and uses the
Ego Lite browser for the web.

## Install (macOS, Apple Silicon or Intel)

Open Terminal and paste:

```bash
curl -fsSL https://raw.githubusercontent.com/BillionaireByram/myflo/myflo/myflo/install.sh | bash
```

About 5 minutes. Along the way macOS may ask you to:

1. **Install Command Line Tools** (first time only): click Install and wait.
2. **Sign in to Claude**: a browser tab opens; use your own Claude account.
3. **Finish Ego Lite's setup**: say yes to importing Chrome data so agents get your logins.
4. **Allow computer control**: in System Settings → Privacy & Security, turn on
   *Screen & System Audio Recording* and *Accessibility* for **MyFlo** (and **Terminal**).
   Then run `myflo restart`.

## Use it

- Click **MyFlo** in `~/Applications` (drag it to the Dock), or run `myflo` in Terminal.
  It opens at <http://localhost:38896>.
- Your first project, **MyFlo Workspace**, lives in `~/MyFlo`. Add repos with
  *New project* in the sidebar.
- Ask for things in plain English. The agent uses:
  - the shell and AppleScript for files and apps,
  - **Peekaboo** (the `mac-computer` skill) to see the screen and click and type in any app,
  - **Ego Lite** (the `ego-browser` skill) for websites, in its own Space so your tabs stay yours.

| Command | What it does |
| --- | --- |
| `myflo` | Start MyFlo if needed and open it |
| `myflo stop` / `myflo restart` | Stop or restart the local server |
| `myflo doctor` | Check node, git, Claude sign-in, computer control and Ego Lite |
| `myflo logs` | Follow the server log |
| `myflo update` | Rerun the installer from this branch |
| `myflo <bb command>` | The bundled bb CLI, e.g. `myflo project list` |

Everything stays on the Mac: the server listens only on `127.0.0.1`, telemetry and
in-app updates are off, and Claude Code uses the person's own login.

## What the installer puts where

| Path | Contents |
| --- | --- |
| `~/.myflo/node` | Private Node.js 24 runtime |
| `~/.myflo/app` | Pinned `bb-app` 0.46.1 with MyFlo branding (`brand.mjs`) |
| `~/.myflo/tools` | Peekaboo 4.9.6, registered as the `peekaboo` MCP server for Claude Code |
| `~/.myflo/data` | Threads, projects, settings, MyFlo theme |
| `~/Applications/MyFlo.app` | Launcher app |
| `~/.claude/skills/mac-computer` | Computer-control skill |
| `/Applications/ego lite.app` | Ego Lite, via Ego's own installer |

Remove with `~/.myflo/kit/uninstall.sh` (keeps Claude Code, Ego Lite and `~/MyFlo`).

## This fork

- `main` tracks upstream `get-bb/bb`; the `myflo` branch (default) carries the rename and this kit.
- The source rename covers the web app title and install manifests. The installer brands
  the published npm build of the same version, so no one has to build the monorepo.
- A native MyFlo `.dmg` from this source is a follow-up: the desktop app's name is wired
  into bb's release scripts and tests, which need a matching change.
