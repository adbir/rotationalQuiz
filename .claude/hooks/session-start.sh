#!/usr/bin/env bash
# Installs the Flutter SDK in Claude Code cloud sessions so that
# `flutter analyze` / `flutter test` and the Dart MCP server work.
# Local sessions are left alone: use your own Flutter install there.
set -euo pipefail

if [[ "${CLAUDE_CODE_REMOTE:-}" != "true" ]]; then
  exit 0
fi

FLUTTER_HOME="${FLUTTER_HOME:-$HOME/flutter}"

if [[ ! -x "$FLUTTER_HOME/bin/flutter" ]]; then
  base="https://storage.googleapis.com/flutter_infra_release/releases"
  archive=$(curl -fsSL "$base/releases_linux.json" | python3 -c '
import json, sys
d = json.load(sys.stdin)
h = d["current_release"]["stable"]
print(next(r["archive"] for r in d["releases"] if r["hash"] == h))')
  mkdir -p "$(dirname "$FLUTTER_HOME")"
  curl -fsSL "$base/$archive" | tar -xJ -C "$(dirname "$FLUTTER_HOME")"
  git config --global --add safe.directory "$FLUTTER_HOME"
fi

export PATH="$FLUTTER_HOME/bin:$PATH"
if [[ -n "${CLAUDE_ENV_FILE:-}" ]]; then
  echo "export PATH=\"$FLUTTER_HOME/bin:\$PATH\"" >> "$CLAUDE_ENV_FILE"
fi

flutter config --no-analytics >/dev/null 2>&1 || true
cd "$CLAUDE_PROJECT_DIR"
flutter pub get >/dev/null
