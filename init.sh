#!/usr/bin/env bash
# init.sh — Scans codebase, generates context files, cleans up.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="$(pwd)"

MODE="standalone"; SYSTEM_NAME=""; BRIEF_FILE=""
ARG_NAME=""; ARG_PURPOSE=""; ARG_NORTH_STAR=""; ARG_NOTES=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) MODE="$2"; shift 2 ;; --system) SYSTEM_NAME="$2"; shift 2 ;;
    --from) BRIEF_FILE="$2"; shift 2 ;; --name) ARG_NAME="$2"; shift 2 ;;
    --purpose) ARG_PURPOSE="$2"; shift 2 ;; --north-star) ARG_NORTH_STAR="$2"; shift 2 ;;
    --notes) ARG_NOTES="$2"; shift 2 ;; *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

echo "Scanning project..."
SCAN_JSON=$("$SCRIPT_DIR/scan.sh" "$TARGET_DIR")

json_val() { echo "$SCAN_JSON" | grep "\"$1\"" | head -1 | sed 's/.*:[[:space:]]*//' | sed 's/"//g' | sed 's/,$//' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//'; }
json_array() { echo "$SCAN_JSON" | grep "\"$1\"" | head -1 | sed 's/.*\[//' | sed 's/\].*//' | sed 's/"//g' | sed 's/,/ /g' | sed 's/^[[:space:]]*//'; }

PROJECT_NAME=$(json_val "project_name"); LANGUAGE=$(json_val "language")
FRAMEWORK=$(json_val "framework"); PACKAGE_MANAGER=$(json_val "package_manager")
HAS_TESTS=$(json_val "has_tests"); TEST_COMMAND=$(json_val "test_command")
HAS_SUPABASE=$(json_val "has_supabase"); HAS_SHOPIFY=$(json_val "has_shopify")
HAS_DOCKER=$(json_val "has_docker"); CURRENT_VERSION=$(json_val "current_version")
ENTRY_POINTS=$(json_array "entry_points"); DIRECTORIES=$(json_array "directories")

PURPOSE=""; NORTH_STAR=""; NOTES=""
if [ -n "$BRIEF_FILE" ]; then
  [ ! -f "$BRIEF_FILE" ] && echo "Error: Brief file '$BRIEF_FILE' not found" >&2 && exit 1
  ARG_NAME=$(grep -i '^name:' "$BRIEF_FILE" | head -1 | sed 's/^[Nn]ame:[[:space:]]*//')
  PURPOSE=$(grep -i '^purpose:' "$BRIEF_FILE" | head -1 | sed 's/^[Pp]urpose:[[:space:]]*//')
  NORTH_STAR=$(grep -i '^north star:' "$BRIEF_FILE" | head -1 | sed 's/^[Nn]orth [Ss]tar:[[:space:]]*//')
  NOTES=$(grep -i '^notes:' "$BRIEF_FILE" | head -1 | sed 's/^[Nn]otes:[[:space:]]*//')
fi
[ -n "$ARG_NAME" ] && PROJECT_NAME="$ARG_NAME"
[ -n "$ARG_PURPOSE" ] && PURPOSE="$ARG_PURPOSE"
[ -n "$ARG_NORTH_STAR" ] && NORTH_STAR="$ARG_NORTH_STAR"
[ -n "$ARG_NOTES" ] && NOTES="$ARG_NOTES"

INTERACTIVE=false
[ -z "$BRIEF_FILE" ] && [ -z "$ARG_NAME" ] && [ -z "$ARG_PURPOSE" ] && INTERACTIVE=true
if [ -z "$PURPOSE" ]; then printf "Project purpose (one sentence): "; read -r PURPOSE; fi
if [ -z "$NORTH_STAR" ]; then
  if $INTERACTIVE; then printf "North Star — what does DONE look like? "; read -r NORTH_STAR
  else NORTH_STAR="[Define north star]"; fi
fi
if [ -z "$NOTES" ] && $INTERACTIVE; then printf "Anything else an agent should know? (enter to skip): "; read -r NOTES; fi

TODAY=$(date +%Y-%m-%d)
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
SUPABASE_LINE=""; [ "$HAS_SUPABASE" = "true" ] && SUPABASE_LINE="- Database: Supabase"
SHOPIFY_LINE=""; [ "$HAS_SHOPIFY" = "true" ] && SHOPIFY_LINE="- Commerce: Shopify Storefront API"
DOCKER_LINE=""; [ "$HAS_DOCKER" = "true" ] && DOCKER_LINE="- Containerized: Yes"
TEST_LINE=""; [ -n "$TEST_COMMAND" ] && TEST_LINE="- Run tests: \`${TEST_COMMAND}\`"
DIRS_SECTION=""; [ -n "$DIRECTORIES" ] && DIRS_SECTION="Key directories: ${DIRECTORIES}"
ENTRY_SECTION=""; [ -n "$ENTRY_POINTS" ] && ENTRY_SECTION="Entry points: ${ENTRY_POINTS}"
NOTES_SECTION=""; [ -n "$NOTES" ] && NOTES_SECTION="## Notes
${NOTES}"
SYSTEM_CONTEXT=""
[ "$MODE" = "service" ] && [ -n "$SYSTEM_NAME" ] && SYSTEM_CONTEXT="## System Context
This service is part of the **${SYSTEM_NAME}** system."
TEST_SUMMARY="No tests detected"; [ "$HAS_TESTS" = "true" ] && TEST_SUMMARY="Tests present"
SCAN_SUMMARY="Detected: ${LANGUAGE} ${FRAMEWORK} project. ${TEST_SUMMARY}."
SYSTEM_DEPS=""
[ "$MODE" = "service" ] && [ -n "$SYSTEM_NAME" ] && SYSTEM_DEPS="## System Dependencies
- Part of: ${SYSTEM_NAME}
- Receives input from: [define]
- Produces output for: [define]"

echo "Generating AGENTS.md..."
cat > "$TARGET_DIR/AGENTS.md" <<EOF
# ${PROJECT_NAME}

> ${PURPOSE}

## North Star

${NORTH_STAR}

## Stack

- Language: ${LANGUAGE}
- Framework: ${FRAMEWORK}
- Package Manager: ${PACKAGE_MANAGER}
${SUPABASE_LINE}
${SHOPIFY_LINE}
${DOCKER_LINE}

## Architecture

${DIRS_SECTION}
${ENTRY_SECTION}

## Conventions

- For current project state, see SESSION.md
- Version bumps: \`./scripts/version.sh bump <major|minor|patch> "description"\`
- Release process: see docs/RELEASE_CHECKLIST.md
${TEST_LINE}

${NOTES_SECTION}

${SYSTEM_CONTEXT}
EOF
awk 'NF{b=0} !NF{b++} b<=1' "$TARGET_DIR/AGENTS.md" > "$TARGET_DIR/AGENTS.md.tmp" && mv "$TARGET_DIR/AGENTS.md.tmp" "$TARGET_DIR/AGENTS.md"

if [ "$MODE" = "system" ]; then
  echo "Generating SYSTEM.md..."
  SERVICE_ROWS=""; PARENT_DIR=$(dirname "$TARGET_DIR")
  for d in "$PARENT_DIR"/*/; do
    DIR_NAME=$(basename "$d"); [ "$DIR_NAME" = "$(basename "$TARGET_DIR")" ] && continue
    if [ -d "$d/.git" ]; then
      SVC_VERSION="0.1.0"; SVC_STATUS="Detected"
      if [ -f "$d/SESSION.md" ]; then
        SVC_VERSION=$(grep -m1 '^- Version:' "$d/SESSION.md" | sed 's/- Version:[[:space:]]*//' || echo "0.1.0")
        SVC_STATUS=$(awk '/^## Current State/{f=1;next} f&&/^## /{exit} f&&NF{print;exit}' "$d/SESSION.md" || echo "Unknown")
      fi
      SERVICE_ROWS="${SERVICE_ROWS}| ${DIR_NAME} | ${DIR_NAME} | ${SVC_VERSION} | ${SVC_STATUS} |
"
    fi
  done
  [ -z "$SERVICE_ROWS" ] && SERVICE_ROWS="| (no services detected) | — | — | — |
"
  [ -z "$SYSTEM_NAME" ] && SYSTEM_NAME="$PROJECT_NAME"
  cat > "$TARGET_DIR/SYSTEM.md" <<EOF
# System State

- System: ${SYSTEM_NAME}
- Updated: ${TODAY}

## Services

| Service | Directory | Version | Status |
|---------|-----------|---------|--------|
${SERVICE_ROWS}
## Integration Map

[Define service dependencies here]

## Current System Priority

[Define current focus]
EOF
else
  echo "Generating SESSION.md..."
  cat > "$TARGET_DIR/SESSION.md" <<EOF
# Session State

- Version: ${CURRENT_VERSION}
- Updated: ${TODAY}
- Branch: ${CURRENT_BRANCH}

## Last Completed

Project initialized.

## Current State

${PURPOSE}
${SCAN_SUMMARY}

## Next Action

Define North Star milestones and begin first build phase.

${SYSTEM_DEPS}
EOF
  awk 'NF{b=0} !NF{b++} b<=1' "$TARGET_DIR/SESSION.md" > "$TARGET_DIR/SESSION.md.tmp" && mv "$TARGET_DIR/SESSION.md.tmp" "$TARGET_DIR/SESSION.md"
fi

echo "Creating symlinks..."
ln -sf AGENTS.md "$TARGET_DIR/CLAUDE.md"
ln -sf AGENTS.md "$TARGET_DIR/.cursorrules"
echo "Installing scripts..."
mkdir -p "$TARGET_DIR/scripts" "$TARGET_DIR/docs"
cp "$SCRIPT_DIR/scripts/version.sh" "$TARGET_DIR/scripts/version.sh"
chmod +x "$TARGET_DIR/scripts/version.sh"
cp "$SCRIPT_DIR/templates/RELEASE_CHECKLIST.md" "$TARGET_DIR/docs/RELEASE_CHECKLIST.md"
if [ -f "$TARGET_DIR/.gitignore" ] && ! grep -q "project-ops" "$TARGET_DIR/.gitignore" 2>/dev/null; then
  echo "project-ops/" >> "$TARGET_DIR/.gitignore"
fi
echo "Cleaning up project-ops/..."
rm -rf "$SCRIPT_DIR"
echo ""
echo "=== project-ops complete ==="
echo ""
echo "Created:"
echo "  AGENTS.md           — Project identity & stack"
if [ "$MODE" = "system" ]; then echo "  SYSTEM.md           — System service state"
else echo "  SESSION.md          — Version & session state"; fi
echo "  CLAUDE.md           — Symlink -> AGENTS.md"
echo "  .cursorrules        — Symlink -> AGENTS.md"
echo "  scripts/version.sh  — Version management"
echo "  docs/RELEASE_CHECKLIST.md"
echo ""
echo "Next: Review AGENTS.md, then start building."
