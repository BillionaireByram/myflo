---
name: mac-computer
description: Control this Mac — see the screen, click, type, open and arrange apps, and run macOS automation. Use when the user asks you to do something in a desktop app, look at their screen, or operate the computer outside the browser. For websites, use the ego-browser skill (Ego Lite) instead.
---

# Controlling this Mac

You are running inside MyFlo on the user's own Mac. You have three layers of control; pick the lightest one that does the job.

## 1. Shell and AppleScript (no extra permissions)

- Open apps, files and URLs: `open -a "Notes"`, `open ~/Downloads/report.pdf`, `open https://example.com`
- Ask an app to do something: `osascript -e 'tell application "Finder" to make new folder at desktop with properties {name:"Clients"}'`
- System info and settings: `system_profiler SPHardwareDataType`, `defaults read`, `pmset -g batt`
- Clipboard: `pbpaste`, `echo text | pbcopy`
- Screenshot to a file: `screencapture -x /tmp/screen.png` (needs Screen Recording)

## 2. Peekaboo MCP tools (see and operate any app)

The `peekaboo` MCP server is registered for Claude Code. Its tools observe the screen and act on native UI:

- `see` — capture the screen or an app window and get a map of clickable elements with IDs. Always start here.
- `click`, `type`, `press`, `hotkey`, `scroll`, `drag` — act on an element ID from the latest `see`, or on coordinates.
- `app`, `window`, `menu`, `dock`, `dialog`, `space` — launch/quit/focus apps, move and resize windows, pick menu items, answer dialogs.

Loop: `see` → choose the element → act → `see` again to confirm the result. Prefer a menu or element action over raw coordinates.

The same tools exist as a CLI at `~/.myflo/tools/node_modules/.bin/peekaboo` (`peekaboo see --app Finder --json`, `peekaboo click --on <id>`), useful from Bash.

If a tool reports missing permissions, tell the user to open System Settings → Privacy & Security and enable **Screen & System Audio Recording** and **Accessibility** for the app they launched MyFlo from (MyFlo or Terminal), then restart MyFlo with `myflo restart`. `peekaboo permissions status` shows what is missing.

## 3. Websites → Ego Lite

For anything in a web page (logins, forms, scraping, posting), use the `ego-browser` skill. It drives the Ego Lite browser in its own Space with the user's real logins, without taking over the user's tabs.

## Ask first

Confirm with the user before you: send a message or email, post publicly, buy or pay for anything, delete files or data, change system settings, or type passwords. Never read or copy saved passwords or keychain items.
