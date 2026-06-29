#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"

usage() {
  cat <<'EOF'
Usage: scripts/list-skills.sh [repo|claude|codex|agents]

repo    List skills in this repository (default).
claude  List skills installed for Claude Code (~/.claude/skills).
codex   List skills installed for Codex (~/.codex/skills).
agents  List skills installed for Agent-Skills-standard harnesses (~/.agents/skills).
EOF
}

list_repo() {
  cd "$REPO"
  find . -name SKILL.md -not -path '*/node_modules/*' | sed 's|^\./||' | sort
}

list_dest() {
  local dest="$1"

  if [ ! -d "$dest" ]; then
    echo "No skills directory found: $dest" >&2
    return 1
  fi

  local entry target
  for entry in "$dest"/*; do
    [ -e "$entry/SKILL.md" ] || continue

    if [ -L "$entry" ]; then
      target="$(readlink "$entry")"
      printf '%s -> %s\n' "$(basename "$entry")" "$target"
    else
      printf '%s\n' "$(basename "$entry")"
    fi
  done | sort
}

case "${1:-repo}" in
  repo)
    list_repo
    ;;
  claude)
    list_dest "$HOME/.claude/skills"
    ;;
  codex)
    list_dest "$HOME/.codex/skills"
    ;;
  agents)
    list_dest "$HOME/.agents/skills"
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac
