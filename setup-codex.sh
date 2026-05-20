#!/usr/bin/env bash
set -euo pipefail

NODE_ROOT="/opt/node"
BIN_DIR="/usr/local/bin"

# --- Install Node.js + npm system-wide if missing ---
if ! command -v npm &>/dev/null || [[ "$(readlink -f "$(command -v npm)" 2>/dev/null)" != "$NODE_ROOT"* ]]; then
  echo "📦 Installing Node.js LTS system-wide into $NODE_ROOT ..."
  sudo uvx nodeenv -n lts "$NODE_ROOT"
  for bin in node npm npx; do
    sudo ln -sf "$NODE_ROOT/bin/$bin" "$BIN_DIR/$bin"
  done
  echo "✅ Node $(node --version), npm $(npm --version) installed."
else
  echo "✅ npm already available system-wide ($(npm --version))."
fi

# --- Upgrade @openai/codex to latest ---
echo "⬆️  Upgrading @openai/codex to latest ..."
sudo npm install -g @openai/codex@latest

# --- Fix stale codex binary ---
# If /usr/local/bin/codex is a regular file (old ELF binary) instead of a symlink,
# remove it so the npm-managed symlink takes effect.
CODEX_LINK="$BIN_DIR/codex"
if [[ -e "$CODEX_LINK" && ! -L "$CODEX_LINK" ]]; then
  echo "🗑️  Removing stale codex binary at $CODEX_LINK ..."
  sudo rm -f "$CODEX_LINK"
fi

# Ensure symlink points to npm-managed binary
if [[ ! -L "$CODEX_LINK" || "$(readlink "$CODEX_LINK")" != "$NODE_ROOT/bin/codex" ]]; then
  sudo ln -sf "$NODE_ROOT/bin/codex" "$CODEX_LINK"
fi

# --- Remove any other stale codex on PATH ---
while IFS= read -r other; do
  if [[ "$other" != "$CODEX_LINK" ]]; then
    echo "🗑️  Removing stale codex at $other ..."
    sudo rm -f "$other"
  fi
done < <(which -a codex 2>/dev/null || true)

# --- Install and enable direnv if missing ---
if ! command -v direnv &>/dev/null; then
  echo "📦 Installing direnv ..."
  sudo apt-get update -qq && sudo apt-get install -y -qq direnv
fi

# Hook direnv into bashrc if not already there
BASHRC="/home/exedev/.bashrc"
if ! grep -q 'direnv hook bash' "$BASHRC" 2>/dev/null; then
  echo 'eval "$(direnv hook bash)"' >> "$BASHRC"
  echo "✅ direnv hook added to $BASHRC"
else
  echo "✅ direnv already hooked in $BASHRC"
fi

# --- Verify ---
echo ""
echo "🎉 Done! codex version: $(codex --version 2>&1), direnv: $(direnv version 2>&1)"
