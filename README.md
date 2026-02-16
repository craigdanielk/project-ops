# project-ops

Plug-and-play project state management for AI-assisted development.

Gives any AI agent (Claude, Cursor, Copilot) instant project awareness
through standardized context files.

## Quick Start

```bash
# Clone into your project root
git clone https://github.com/craigdanielk/project-ops.git
./project-ops/init.sh
```

## What It Creates

| File | Purpose |
|------|---------|
| AGENTS.md | Project identity, stack, conventions (read by all AI agents) |
| SESSION.md | Current version, state, and next action (updated each milestone) |
| CLAUDE.md | Symlink -> AGENTS.md |
| .cursorrules | Symlink -> AGENTS.md |
| scripts/version.sh | Version bump, sync, and tag utility |
| docs/RELEASE_CHECKLIST.md | Copy-paste checklist for integrations |

## Modes

```bash
# Single repo (default)
./project-ops/init.sh

# Part of a microservices system
./project-ops/init.sh --mode service --system "MySystem"

# System orchestrator tracking multiple services
./project-ops/init.sh --mode system

# Non-interactive
./project-ops/init.sh --from brief.md
./project-ops/init.sh --name "My Project" --purpose "Does X"
```

## Daily Usage

```bash
# Check current version
./scripts/version.sh current

# Bump after completing work
./scripts/version.sh bump minor "Added user authentication"

# Sync system state (orchestrator repos only)
./scripts/version.sh sync
```

## Philosophy

Four files. No dependencies. No framework. Clone, init, delete.
