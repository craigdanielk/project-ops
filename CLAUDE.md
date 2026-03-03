# project-ops

Plug-and-play project state management for AI-assisted development. Gives any AI agent (Claude, Cursor, Copilot) instant project awareness through standardized context files. Zero dependencies, pure bash.

## Tech Stack

- Shell (bash)
- Git

## Repository Structure

```
project_operations_system/
├── .github/workflows/
│   ├── ci.yml                  # Shell syntax + JSON validation
│   └── knowledge-loop.yml      # Tracks CLAUDE.md/docs/retro changes
├── init.sh                     # Main initialization script
├── scan.sh                     # Project scanning utility
├── scripts/
│   └── version.sh              # Version bump, sync, and tag utility
├── templates/
│   ├── AGENTS.md.tmpl
│   ├── SESSION.md.tmpl
│   ├── SYSTEM.md.tmpl
│   └── RELEASE_CHECKLIST.md
├── retrospectives/
│   └── 2026-02-16-project-ops-build-success.md
├── CLAUDE.md
└── README.md
```

## How to Run

```bash
# Initialize in any project
./init.sh

# Modes
./init.sh --mode service --system "MySystem"  # Microservice
./init.sh --mode system                        # Orchestrator
./init.sh --from brief.md                      # Non-interactive

# Version management
./scripts/version.sh current
./scripts/version.sh bump minor "Added feature"
```

## Key Files

- `init.sh` -- Creates AGENTS.md, SESSION.md, CLAUDE.md (symlink), .cursorrules (symlink)
- `scan.sh` -- Scans project structure and reports state
- `scripts/version.sh` -- Semantic versioning with git tags
- `templates/` -- Mustache-style templates for generated files

## Known Gotchas

- Local directory is `project_operations_system`, GitHub repo is `project-ops`
- Remote: https://github.com/craigdanielk/project-ops.git
- Published as v1.0.0
- No test suite yet; consider adding shellcheck/bats tests
- **Monday MCP server stderr crash (diagnosed 2026-03-04):** The `@mondaydotcomorg/monday-api-mcp` server emits npm deprecation warnings on stderr during startup (`npm warn deprecated prebuild-install@7.1.3`). Claude Code's MCP client interprets any stderr output as a server crash, causing repeated restart attempts. The server itself starts and runs correctly -- this is a false positive. Workaround: pipe stderr to /dev/null in the MCP server config, or wait for the upstream `prebuild-install` dependency to be updated. See `mcp-configs/servers/monday.json` for the server definition.

## CLI Auto-Permissions

The `.claude/settings.local.json` file configures which tools Claude Code can
run without prompting in this repo. Covers: shell scripts (init.sh, scan.sh,
version.sh), git operations, GitHub CLI, shellcheck, file utilities, and
common CLI tools (curl, jq, python3, npx).

## Current Status

- CI and knowledge-loop workflows deployed
- Production-hardened with .gitignore and GitHub Actions
