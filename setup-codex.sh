#!/usr/bin/env bash
set -euo pipefail

NODE_ROOT="/opt/node"
BIN_DIR="/usr/local/bin"

# --- Install Node.js + npm system-wide if missing ---
if ! command -v npm &>/dev/null || [[ "$(readlink -f "$(command -v npm)" 2>/dev/null)" != "$NODE_ROOT"* ]]; then
  echo "📦 Installing Node.js LTS system-wide into $NODE_ROOT ..."
  uvx nodeenv -n lts "$NODE_ROOT"
  for bin in node npm npx; do
    ln -sf "$NODE_ROOT/bin/$bin" "$BIN_DIR/$bin"
  done
  echo "✅ Node $(node --version), npm $(npm --version) installed."
else
  echo "✅ npm already available system-wide ($(npm --version))."
fi

# --- Upgrade @openai/codex to latest ---
echo "⬆️  Upgrading @openai/codex to latest ..."
npm install -g @openai/codex@latest

# --- Fix stale codex binary ---
# If /usr/local/bin/codex is a regular file (old ELF binary) instead of a symlink,
# remove it so the npm-managed symlink takes effect.
CODEX_LINK="$BIN_DIR/codex"
if [[ -e "$CODEX_LINK" && ! -L "$CODEX_LINK" ]]; then
  echo "🗑️  Removing stale codex binary at $CODEX_LINK ..."
  rm -f "$CODEX_LINK"
fi

# Ensure symlink points to npm-managed binary
if [[ ! -L "$CODEX_LINK" || "$(readlink "$CODEX_LINK")" != "$NODE_ROOT/bin/codex" ]]; then
  ln -sf "$NODE_ROOT/bin/codex" "$CODEX_LINK"
fi

# --- Remove any other stale codex on PATH ---
while IFS= read -r other; do
  if [[ "$other" != "$CODEX_LINK" ]]; then
    echo "🗑️  Removing stale codex at $other ..."
    rm -f "$other"
  fi
done < <(which -a codex 2>/dev/null || true)

# --- Verify ---
echo ""
echo "🎉 Done! codex version: $(codex --version 2>&1)"
