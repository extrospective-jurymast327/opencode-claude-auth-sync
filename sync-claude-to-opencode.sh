#!/usr/bin/env bash
set -euo pipefail

OPENCODE_AUTH="${OPENCODE_AUTH_PATH:-$HOME/.local/share/opencode/auth.json}"

[[ ! -f "$OPENCODE_AUTH" ]] && exit 0
command -v node >/dev/null 2>&1 || { echo "node not found" >&2; exit 1; }

CLAUDE_JSON=""

if [[ -n "${CLAUDE_CREDENTIALS_PATH:-}" ]] && [[ -f "$CLAUDE_CREDENTIALS_PATH" ]]; then
  CLAUDE_JSON=$(cat "$CLAUDE_CREDENTIALS_PATH")

elif [[ "$(uname)" == "Darwin" ]] && command -v security >/dev/null 2>&1; then
  CLAUDE_JSON=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null || true)

  if [[ -z "$CLAUDE_JSON" ]] && [[ -f "$HOME/.claude/.credentials.json" ]]; then
    CLAUDE_JSON=$(cat "$HOME/.claude/.credentials.json")
  fi

elif [[ -f "$HOME/.claude/.credentials.json" ]]; then
  CLAUDE_JSON=$(cat "$HOME/.claude/.credentials.json")
fi

if [[ -z "$CLAUDE_JSON" ]]; then
  echo "No Claude credentials found" >&2
  exit 0
fi

node --input-type=module -e "
const creds = (() => {
  const raw = JSON.parse(process.argv[1]);
  return raw.claudeAiOauth ?? raw;
})(process.argv[1]);

if (!creds.accessToken || !creds.refreshToken || !creds.expiresAt) {
  console.error('Claude credentials incomplete');
  process.exit(1);
}

import fs from 'node:fs';

const auth = JSON.parse(fs.readFileSync('${OPENCODE_AUTH}', 'utf8'));

const remaining = creds.expiresAt - Date.now();
const hours = Math.floor(remaining / 3600000);
const mins = Math.floor((remaining % 3600000) / 60000);
const status = remaining > 0 ? hours + 'h ' + mins + 'm remaining' : 'EXPIRED';

if (
  auth.anthropic &&
  auth.anthropic.access === creds.accessToken &&
  auth.anthropic.refresh === creds.refreshToken
) {
  console.log(new Date().toISOString() + ' already in sync (' + status + ')');
  process.exit(0);
}

auth.anthropic = {
  type: 'oauth',
  access: creds.accessToken,
  refresh: creds.refreshToken,
  expires: creds.expiresAt,
};

fs.writeFileSync('${OPENCODE_AUTH}', JSON.stringify(auth, null, 2));
console.log(new Date().toISOString() + ' synced (' + status + ')');
" "$CLAUDE_JSON"
