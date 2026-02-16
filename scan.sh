#!/usr/bin/env bash
# scan.sh — Detect project characteristics from filesystem. Outputs JSON.
set -euo pipefail
TARGET_DIR="${1:-.}"; cd "$TARGET_DIR"

has_file() { [ -f "$1" ]; }
has_dir() { [ -d "$1" ]; }
json_str() { printf '"%s"' "$(echo "$1" | sed 's/"/\\"/g')"; }
json_bool() { if $1; then echo "true"; else echo "false"; fi; }
json_arr() { if [ -z "$1" ]; then echo "[]"; else echo "[$(echo "$1" | sed 's/[^,]*/\"&\"/g')]"; fi; }

# Project name
project_name=""
has_file "package.json" && project_name=$(grep -m1 '"name"' package.json 2>/dev/null | sed 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' || true)
[ -z "$project_name" ] && has_file "pyproject.toml" && project_name=$(grep -m1 '^name' pyproject.toml 2>/dev/null | sed 's/^name[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/' || true)
[ -z "$project_name" ] && has_file "setup.py" && project_name=$(grep -m1 'name=' setup.py 2>/dev/null | sed "s/.*name=['\"]\\([^'\"]*\\)['\"].*/\\1/" || true)
[ -z "$project_name" ] && project_name=$(basename "$(pwd)")

# Language
language="unknown"; has_ts=false; has_js=false; has_py=false
find . -maxdepth 4 -name "*.ts" -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/dist/*" -not -path "*/.next/*" 2>/dev/null | head -1 | grep -q . && has_ts=true
find . -maxdepth 4 -name "*.js" -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/dist/*" -not -path "*/.next/*" 2>/dev/null | head -1 | grep -q . && has_js=true
find . -maxdepth 4 -name "*.py" -not -path "*/__pycache__/*" -not -path "*/.git/*" -not -path "*/venv/*" -not -path "*/.venv/*" 2>/dev/null | head -1 | grep -q . && has_py=true
has_file "tsconfig.json" && has_ts=true
if $has_ts && $has_py; then language="mixed"; elif $has_ts; then language="typescript"
elif $has_js && $has_py; then language="mixed"; elif $has_js; then language="javascript"
elif $has_py; then language="python"; fi

# Framework
framework="none"
if has_file "next.config.js" || has_file "next.config.mjs" || has_file "next.config.ts"; then framework="nextjs"
elif has_file "package.json"; then
  deps=$(cat package.json)
  echo "$deps" | grep -q '"react"' && framework="react"
  echo "$deps" | grep -q '"express"' && framework="express"
  echo "$deps" | grep -q '"vue"' && framework="vue"
  echo "$deps" | grep -q '"svelte"' && framework="svelte"
fi
if [ "$framework" = "none" ] && $has_py; then
  find . -maxdepth 3 -name "*.py" -not -path "*/__pycache__/*" -exec grep -ql "fastapi\|FastAPI" {} + 2>/dev/null && framework="fastapi"
  [ "$framework" = "none" ] && find . -maxdepth 3 -name "*.py" -not -path "*/__pycache__/*" -exec grep -ql "flask\|Flask" {} + 2>/dev/null && framework="flask"
  [ "$framework" = "none" ] && has_file "manage.py" && framework="django"
fi

# Package manager
package_manager="none"
if has_file "pnpm-lock.yaml"; then package_manager="pnpm"
elif has_file "yarn.lock"; then package_manager="yarn"
elif has_file "package-lock.json" || has_file "package.json"; then package_manager="npm"
elif has_file "poetry.lock" || (has_file "pyproject.toml" && grep -q '\[tool.poetry\]' pyproject.toml 2>/dev/null); then package_manager="poetry"
elif has_file "requirements.txt" || has_file "setup.py" || has_file "pyproject.toml"; then package_manager="pip"; fi

# Tests
has_tests=false; test_command=""
(has_dir "test" || has_dir "tests" || has_dir "__tests__" || has_dir "spec") && has_tests=true
find . -maxdepth 3 \( -name "*test*.py" -o -name "*.test.ts" -o -name "*.test.js" -o -name "*.spec.ts" -o -name "*.spec.js" \) -not -path "*/__pycache__/*" -not -path "*/node_modules/*" 2>/dev/null | head -1 | grep -q . && has_tests=true
if has_file "package.json"; then
  tc=$(grep -m1 '"test"' package.json 2>/dev/null | sed 's/.*"test"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' || true)
  [ -n "$tc" ] && [ "$tc" != "echo \"Error: no test specified\" && exit 1" ] && test_command="$tc"
fi
[ -z "$test_command" ] && $has_py && { (has_file "pytest.ini" || has_file "pyproject.toml") && test_command="pytest" || test_command="python -m pytest"; }

# Feature flags
has_supabase=false; has_shopify=false; has_docker=false; has_ci=false
(has_dir "supabase" || (has_file "package.json" && grep -q "@supabase" package.json 2>/dev/null)) && has_supabase=true
has_file "requirements.txt" && grep -q "supabase" requirements.txt 2>/dev/null && has_supabase=true
has_file "package.json" && grep -q "@shopify" package.json 2>/dev/null && has_shopify=true
has_file "Dockerfile" && has_docker=true
has_dir ".github/workflows" && has_ci=true

# Entry points
entry_points=""
for f in src/index.ts src/index.js index.ts index.js app.py main.py manage.py src/main.ts src/app.ts server.ts server.js src/server.ts; do
  has_file "$f" && entry_points="${entry_points:+$entry_points,}$f"
done

# Top-level directories
directories=""
for d in $(ls -d */ 2>/dev/null | sed 's|/||' | grep -vE '^(node_modules|\.git|dist|build|__pycache__|\.next|\.vercel|\.cache|coverage|project-ops)$' | head -15); do
  directories="${directories:+$directories,}$d"
done

# Existing docs
existing_docs=""
for f in README.md CLAUDE.md AGENTS.md SESSION.md .cursorrules .cursor/rules; do
  has_file "$f" && existing_docs="${existing_docs:+$existing_docs,}$f"
done

# Version
version_files=""; current_version="0.1.0"
if has_file "package.json"; then
  version_files="${version_files:+$version_files,}package.json"
  v=$(grep -m1 '"version"' package.json 2>/dev/null | sed 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' || true)
  [ -n "$v" ] && current_version="$v"
fi
if has_file "pyproject.toml"; then
  version_files="${version_files:+$version_files,}pyproject.toml"
  [ "$current_version" = "0.1.0" ] && { v=$(grep -m1 '^version' pyproject.toml 2>/dev/null | sed 's/^version[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/' || true); [ -n "$v" ] && current_version="$v"; }
fi

# Monorepo & siblings
is_monorepo=false
(has_dir "packages" || has_dir "apps") && is_monorepo=true
has_file "package.json" && grep -q '"workspaces"' package.json 2>/dev/null && is_monorepo=true
sibling_repos=""; parent_dir=$(dirname "$(pwd)")
for d in "$parent_dir"/*/; do
  dir_name=$(basename "$d"); [ "$dir_name" = "$(basename "$(pwd)")" ] && continue
  [ -d "$d/.git" ] && sibling_repos="${sibling_repos:+$sibling_repos,}$dir_name"
done

cat <<ENDJSON
{
  "project_name": $(json_str "$project_name"),
  "language": $(json_str "$language"),
  "framework": $(json_str "$framework"),
  "package_manager": $(json_str "$package_manager"),
  "has_tests": $(json_bool $has_tests),
  "test_command": $(json_str "$test_command"),
  "has_supabase": $(json_bool $has_supabase),
  "has_shopify": $(json_bool $has_shopify),
  "has_docker": $(json_bool $has_docker),
  "has_ci": $(json_bool $has_ci),
  "entry_points": $(json_arr "$entry_points"),
  "directories": $(json_arr "$directories"),
  "existing_docs": $(json_arr "$existing_docs"),
  "version_files": $(json_arr "$version_files"),
  "current_version": $(json_str "$current_version"),
  "is_monorepo": $(json_bool $is_monorepo),
  "sibling_repos": $(json_arr "$sibling_repos")
}
ENDJSON
