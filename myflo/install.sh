#!/usr/bin/env bash
# MyFlo installer for macOS (Apple Silicon or Intel). Safe to rerun; it updates in place.
#
#   curl -fsSL https://raw.githubusercontent.com/BillionaireByram/myflo/myflo/myflo/install.sh | bash
#
# Installs, all under your user account (no admin rights except Apple's own prompts):
#   ~/.myflo/node      private Node.js runtime
#   ~/.myflo/app       MyFlo IDE (pinned bb-app 0.46.1 + MyFlo branding)
#   ~/.myflo/tools     Peekaboo, the computer-control MCP server
#   ~/.myflo/data      your threads, projects and settings
#   ~/Applications/MyFlo.app and the `myflo` command
#   Claude Code (if missing), the mac-computer skill, and the Ego Lite browser
set -euo pipefail

MYFLO_HOME="${MYFLO_HOME:-$HOME/.myflo}"
MYFLO_REPO="${MYFLO_REPO:-BillionaireByram/myflo}"
MYFLO_REF="${MYFLO_REF:-myflo}"
NODE_VERSION="v24.22.1"
PEEKABOO_VERSION="4.9.6"
EGO_INSTALLER="https://raw.githubusercontent.com/citrolabs/ego-lite/main/skills/ego-browser/scripts/install.sh"
KIT_FILES="package.json package-lock.json brand.mjs theme.css myflo setup-workspace.mjs uninstall.sh skills/mac-computer/SKILL.md"

step() { printf '\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }
ask() { # ask "Question?" -> 0 for yes (default yes); no terminal means yes
  local reply=""
  if [[ -r /dev/tty ]]; then read -r -p "$1 [Y/n] " reply </dev/tty || true; fi
  [[ ! $reply =~ ^[Nn] ]]
}

# Everything runs from main so `curl | bash` reads the whole script before any step
# (a step that reads stdin could otherwise swallow the rest of it).
main() {
OS=$(uname)
case "$OS" in
  Darwin) PLATFORM=darwin ;;
  Linux) [[ ${MYFLO_ALLOW_LINUX:-} == 1 ]] || die "this installer is for macOS"; PLATFORM=linux ;;
  *) die "unsupported system: $OS" ;;
esac
case "$(uname -m)" in
  arm64|aarch64) ARCH=arm64 ;;
  x86_64) ARCH=x64 ;;
  *) die "unsupported CPU: $(uname -m)" ;;
esac
MAC=false; [[ $PLATFORM == darwin ]] && MAC=true

export PATH="$MYFLO_HOME/node/bin:$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
export NPM_CONFIG_UPDATE_NOTIFIER=false
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$MYFLO_HOME"/{kit,app,tools,data,logs,bin} "$HOME/.local/bin"

echo "Installing MyFlo into $MYFLO_HOME"

# Stop a running copy so the app can be replaced.
if [[ -x "$MYFLO_HOME/bin/myflo" ]]; then "$MYFLO_HOME/bin/myflo" stop >/dev/null 2>&1 || true; fi

if $MAC && ! xcode-select -p >/dev/null 2>&1; then
  step "Installing Apple Command Line Tools (provides git)"
  echo "A macOS window will ask to install the tools. Click Install and wait for it to finish."
  xcode-select --install >/dev/null 2>&1 || true
  for _ in $(seq 1 360); do xcode-select -p >/dev/null 2>&1 && break; sleep 5; done
  xcode-select -p >/dev/null 2>&1 || die "Command Line Tools are not installed yet; rerun this installer when they are"
fi
command -v git >/dev/null || die "git is required"

if [[ $("$MYFLO_HOME/node/bin/node" --version 2>/dev/null || true) != "$NODE_VERSION" ]]; then
  step "Installing Node.js $NODE_VERSION (private to MyFlo)"
  name="node-$NODE_VERSION-$PLATFORM-$ARCH"
  base="https://nodejs.org/dist/$NODE_VERSION"
  curl -fsSL "$base/$name.tar.gz" -o "$TMP/$name.tar.gz"
  curl -fsSL "$base/SHASUMS256.txt" -o "$TMP/SHASUMS256.txt"
  expected=$(awk -v f="$name.tar.gz" '$2 == f { print $1 }' "$TMP/SHASUMS256.txt")
  actual=$( (shasum -a 256 "$TMP/$name.tar.gz" 2>/dev/null || sha256sum "$TMP/$name.tar.gz") | awk '{print $1}')
  [[ -n $expected && $expected == "$actual" ]] || die "Node.js download failed its checksum"
  tar -xzf "$TMP/$name.tar.gz" -C "$TMP"
  rm -rf "$MYFLO_HOME/node"
  mv "$TMP/$name" "$MYFLO_HOME/node"
fi

step "Fetching the MyFlo kit ($MYFLO_REPO@$MYFLO_REF)"
SOURCE_DIR=""
if [[ -n ${BASH_SOURCE[0]:-} && -f ${BASH_SOURCE[0]} ]]; then
  SOURCE_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
  [[ -f $SOURCE_DIR/brand.mjs ]] || SOURCE_DIR=""
fi
for file in $KIT_FILES; do
  mkdir -p "$MYFLO_HOME/kit/$(dirname "$file")"
  if [[ -n $SOURCE_DIR ]]; then
    cp "$SOURCE_DIR/$file" "$MYFLO_HOME/kit/$file"
  else
    curl -fsSL "https://raw.githubusercontent.com/$MYFLO_REPO/$MYFLO_REF/myflo/$file" -o "$MYFLO_HOME/kit/$file"
  fi
done
chmod 0755 "$MYFLO_HOME/kit/myflo" "$MYFLO_HOME/kit/uninstall.sh"

step "Installing the MyFlo app"
cp "$MYFLO_HOME/kit/package.json" "$MYFLO_HOME/kit/package-lock.json" "$MYFLO_HOME/app/"
# Install scripts must run: they fetch bb's native add-ons (better-sqlite3, node-pty, @parcel/watcher).
(cd "$MYFLO_HOME/app" && npm ci --omit=dev --no-audit --no-fund --loglevel=error)
node "$MYFLO_HOME/kit/brand.mjs" apply --prefix "$MYFLO_HOME/app"
mkdir -p "$MYFLO_HOME/data/theme/myflo"
cp "$MYFLO_HOME/kit/theme.css" "$MYFLO_HOME/data/theme/myflo/theme.css"

step "Installing the myflo command"
cp "$MYFLO_HOME/kit/myflo" "$MYFLO_HOME/bin/myflo"
chmod 0755 "$MYFLO_HOME/bin/myflo"
ln -sf "$MYFLO_HOME/bin/myflo" "$HOME/.local/bin/myflo"
for profile in "$HOME/.zprofile" "$HOME/.bash_profile"; do
  if ! grep -qF '# added by MyFlo' "$profile" 2>/dev/null; then
    printf '\nexport PATH="$HOME/.local/bin:$PATH"  # added by MyFlo\n' >>"$profile"
  fi
done

if $MAC; then
  step "Creating ~/Applications/MyFlo.app"
  APP_BUNDLE="$HOME/Applications/MyFlo.app"
  mkdir -p "$HOME/Applications"
  rm -rf "$APP_BUNDLE"
  osacompile -o "$APP_BUNDLE" \
    -e 'do shell script "\"$HOME/.myflo/bin/myflo\" open > /dev/null 2>&1 &"'
  icon="$MYFLO_HOME/app/node_modules/bb-app/app/dist/icon-512.png"
  if [[ -f $icon ]]; then
    iconset="$TMP/MyFlo.iconset"; mkdir -p "$iconset"
    for size in 16 32 128 256 512; do
      sips -z $size $size "$icon" --out "$iconset/icon_${size}x${size}.png" >/dev/null 2>&1 || true
      sips -z $((size * 2)) $((size * 2)) "$icon" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null 2>&1 || true
    done
    iconutil -c icns "$iconset" -o "$APP_BUNDLE/Contents/Resources/applet.icns" 2>/dev/null || true
  fi
  /usr/libexec/PlistBuddy -c "Set :CFBundleName MyFlo" "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || true
  codesign --force --deep -s - "$APP_BUNDLE" >/dev/null 2>&1 || warn "could not re-sign MyFlo.app"

  step "Installing Peekaboo $PEEKABOO_VERSION (computer control)"
  [[ -f $MYFLO_HOME/tools/package.json ]] || echo '{"private": true}' >"$MYFLO_HOME/tools/package.json"
  (cd "$MYFLO_HOME/tools" && npm install "@steipete/peekaboo@$PEEKABOO_VERSION" --no-audit --no-fund --loglevel=error) \
    || warn "Peekaboo did not install (it needs macOS 15+); MyFlo can still use the shell and AppleScript"
  sw_major=$(sw_vers -productVersion | cut -d. -f1)
  [[ $sw_major -ge 15 ]] || warn "macOS $sw_major detected; Peekaboo needs macOS 15 (Sequoia) or later"
fi

if [[ ${MYFLO_SKIP_CLAUDE:-} != 1 ]]; then
  if ! command -v claude >/dev/null; then
    step "Installing Claude Code"
    curl -fsSL https://claude.ai/install.sh | bash
    export PATH="$HOME/.local/bin:$PATH"
  fi
  step "Connecting computer control and the mac-computer skill to Claude Code"
  PEEKABOO="$MYFLO_HOME/tools/node_modules/.bin/peekaboo"
  if [[ -x $PEEKABOO ]] && ! claude mcp get peekaboo >/dev/null 2>&1; then
    claude mcp add --scope user peekaboo -- "$PEEKABOO" mcp
  fi
  mkdir -p "$HOME/.claude/skills/mac-computer"
  cp "$MYFLO_HOME/kit/skills/mac-computer/SKILL.md" "$HOME/.claude/skills/mac-computer/SKILL.md"
fi

if $MAC && [[ ${MYFLO_SKIP_EGO:-} != 1 ]]; then
  step "Installing the Ego Lite browser"
  if curl -fsSL "$EGO_INSTALLER" -o "$TMP/ego-install.sh" && sh "$TMP/ego-install.sh"; then
    echo "Ego Lite opened. Finish its short setup (say yes to importing Chrome data for your logins)."
  else
    warn "Ego Lite did not install; download it from https://lite.ego.app and open it once"
  fi
  npx -y skills add citrolabs/ego-lite --global --agent claude-code --skill ego-browser --yes >/dev/null 2>&1 \
    || warn "the ego-browser skill will be added when Ego Lite finishes its setup"
fi

if [[ ${MYFLO_SKIP_CLAUDE:-} != 1 ]] && ! claude auth status >/dev/null 2>&1; then
  step "Sign in to Claude"
  if ask "Sign in to your Claude account now?"; then claude auth login </dev/tty || warn "run: claude auth login"; fi
fi

step "Starting MyFlo"
"$MYFLO_HOME/bin/myflo" start

if $MAC && [[ -x $MYFLO_HOME/tools/node_modules/.bin/peekaboo ]]; then
  step "Allow computer control"
  cat <<'EOF'
macOS asks before any app can see the screen or click for you. In System Settings →
Privacy & Security, turn on BOTH of these for "MyFlo" (and "Terminal" if you start MyFlo there):
  • Screen & System Audio Recording
  • Accessibility
Opening those settings now. After switching them on, run: myflo restart
EOF
  open "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture" || true
  open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" || true
fi

"$MYFLO_HOME/bin/myflo" open
cat <<EOF

MyFlo is installed.
  • Open it any time: MyFlo in ~/Applications (drag it to the Dock), or run: myflo
  • Check everything: myflo doctor      • Update: myflo update
  • Remove it: $MYFLO_HOME/kit/uninstall.sh
Open a new Terminal window to use the myflo command.
EOF
}

main "$@"
