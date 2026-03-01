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

## Current Status

- CI and knowledge-loop workflows deployed
- Production-hardened with .gitignore and GitHub Actions
