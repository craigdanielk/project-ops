#!/usr/bin/env bash
# version.sh — Version bump, sync, and tag utility
set -euo pipefail
SESSION_FILE="SESSION.md"; SYSTEM_FILE="SYSTEM.md"

sed_i() { if [[ "$OSTYPE" == "darwin"* ]]; then sed -i '' "$@"; else sed -i "$@"; fi; }

get_version() {
  [ ! -f "$SESSION_FILE" ] && echo "Error: $SESSION_FILE not found" >&2 && exit 1
  grep -m1 '^- Version:' "$SESSION_FILE" | sed 's/- Version:[[:space:]]*//'
}

bump_version() {
  local major minor patch; major=$(echo "$2" | cut -d. -f1); minor=$(echo "$2" | cut -d. -f2); patch=$(echo "$2" | cut -d. -f3)
  case "$1" in
    major) echo "$((major+1)).0.0" ;; minor) echo "${major}.$((minor+1)).0" ;;
    patch) echo "${major}.${minor}.$((patch+1))" ;; *) echo "Error: Level must be major, minor, or patch" >&2; exit 1 ;;
  esac
}

cmd_bump() {
  local level="${1:-}" description="${2:-}"
  [ -z "$level" ] || [ -z "$description" ] && echo "Usage: version.sh bump <major|minor|patch> \"desc\"" >&2 && exit 1
  local current new_version today next_action
  current=$(get_version)
  echo "$current" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$' || { echo "Error: Invalid version '$current'" >&2; exit 1; }
  new_version=$(bump_version "$level" "$current")
  today=$(date +%Y-%m-%d)
  echo "Bumping: v${current} -> v${new_version}"
  next_action=$(awk '/^## Next Action/{f=1;next} f&&/^## /{exit} f{print}' "$SESSION_FILE" | sed '/^$/d' | head -5)
  [ -z "$next_action" ] && next_action="$description"
  sed_i "s/^- Version: .*/- Version: ${new_version}/" "$SESSION_FILE"
  sed_i "s/^- Updated: .*/- Updated: ${today}/" "$SESSION_FILE"
  awk -v new="$next_action" '
    /^## Last Completed/{print;print"";print new;s=1;next} /^## Current State/{s=0} !s{print}
  ' "$SESSION_FILE" > "${SESSION_FILE}.tmp" && mv "${SESSION_FILE}.tmp" "$SESSION_FILE"
  awk -v new="[Update after version bump]" '
    /^## Next Action/{print;print"";print new;s=1;next} /^## /&&s{s=0} s&&/^$/{next} !s{print}
  ' "$SESSION_FILE" > "${SESSION_FILE}.tmp" && mv "${SESSION_FILE}.tmp" "$SESSION_FILE"
  if [ -f "package.json" ]; then sed_i "s/\"version\":[[:space:]]*\"${current}\"/\"version\": \"${new_version}\"/" "package.json"; echo "  Updated package.json"; fi
  if [ -f "pyproject.toml" ]; then sed_i "s/^version[[:space:]]*=[[:space:]]*\"${current}\"/version = \"${new_version}\"/" "pyproject.toml"; echo "  Updated pyproject.toml"; fi
  if [ -f "AGENTS.md" ] && grep -q "$current" "AGENTS.md" 2>/dev/null; then sed_i "s/${current}/${new_version}/g" "AGENTS.md"; echo "  Updated AGENTS.md"; fi
  git add -A 2>/dev/null || true
  git commit -m "release: v${new_version} — ${description}" 2>/dev/null || true
  git tag "v${new_version}" 2>/dev/null || true
  echo "Done: v${new_version} — ${description}"
  echo "Run 'git push && git push --tags' when ready."
}

cmd_sync() {
  [ ! -f "$SYSTEM_FILE" ] && echo "Error: $SYSTEM_FILE not found. sync is for --mode system repos only." >&2 && exit 1
  echo "Syncing system state..."
  local parent_dir; parent_dir=$(dirname "$(pwd)")
  local service_dirs; service_dirs=$(awk '/^\|.*\|.*\|.*\|.*\|$/ && !/Service.*Directory/ && !/---/' "$SYSTEM_FILE" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$3);print $3}')
  local changed=false
  for dir in $service_dirs; do
    local full="${parent_dir}/${dir}"
    if [ -d "$full" ] && [ -f "${full}/SESSION.md" ]; then
      local v; v=$(grep -m1 '^- Version:' "${full}/SESSION.md" | sed 's/- Version:[[:space:]]*//')
      echo "  ${dir}: v${v}"
      changed=true
    fi
  done
  if $changed; then
    sed_i "s/^- Updated: .*/- Updated: $(date +%Y-%m-%d)/" "$SYSTEM_FILE"
    git add "$SYSTEM_FILE" 2>/dev/null && git commit -m "sync: system state $(date +%Y-%m-%d)" 2>/dev/null || true
    echo "System state updated."
  else echo "No changes detected."; fi
}

case "${1:-}" in
  current) echo "v$(get_version)" ;;
  bump) cmd_bump "${2:-}" "${3:-}" ;;
  sync) cmd_sync ;;
  *) echo "Usage: version.sh <current|bump|sync>"; exit 1 ;;
esac
