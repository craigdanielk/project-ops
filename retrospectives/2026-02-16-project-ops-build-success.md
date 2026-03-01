# Session Retrospective: project-ops Full Build

**Date**: 2026-02-16
**Duration**: ~45 minutes
**Outcome**: Success

---

## Initial Goal

Build a complete `project-ops` repository — a clone-and-run initializer that scans any codebase, asks minimal questions, and generates four context files (AGENTS.md, SESSION.md, CLAUDE.md symlink, .cursorrules symlink) plus a version management script. Then self-deletes.

## Planned Approach

The user provided an extremely detailed build plan with 5 phases:

- Phase 1: `scan.sh` — pure-bash codebase scanner outputting JSON
- Phase 2: `init.sh` — main entry point with multiple modes (standalone, service, system)
- Phase 3: Templates (AGENTS.md, SESSION.md, SYSTEM.md, RELEASE_CHECKLIST.md)
- Phase 4: `scripts/version.sh` — bump, current, sync commands
- Phase 5: README.md

Constraint: Under 500 total lines across all scripts. No external dependencies.

## What Actually Happened

### Execution Timeline

1. **Initial file creation**
   - Created all 9 files in rapid succession: scan.sh, init.sh, version.sh, 4 templates, README.md, .gitignore
   - Wrote first drafts of all scripts based on the spec

2. **First test: scan.sh on current directory**
   - Worked correctly for the empty project-ops directory itself
   - Tested against a real Python project (Aurelix) — detected `language: unknown` instead of `python`

3. **Bug fix: Language detection**
   - Root cause: Used `ls *.py src/*.py` glob patterns which don't recurse into subdirectories
   - Fix: Switched to `find . -maxdepth 4` with proper exclusion paths
   - Also fixed Python framework detection (same glob issue)

4. **First end-to-end test with `--from brief.md`**
   - Succeeded on first try after scan fix
   - All files generated correctly, symlinks created, project-ops self-deleted

5. **Bug fix: json_val boolean parsing**
   - `has_tests` showed "No tests detected" despite `__tests__/` directory existing
   - Root cause: `json_val()` sed pipeline didn't strip trailing commas from boolean values (`true,` instead of `true`)
   - Fix: Added `sed 's/,$//'` and cleaned up the quote-stripping pipeline

6. **Bug fix: Interactive prompts in non-interactive mode**
   - `--name` and `--purpose` flags didn't suppress North Star/Notes prompts
   - Added `--north-star` and `--notes` CLI flags
   - Added `INTERACTIVE` flag to only prompt when no CLI args or brief file provided

7. **Tested all three modes**
   - `--mode standalone` with `--from brief.md`: Pass
   - `--mode service --system "Aurelix"`: Pass (system context + deps sections added)
   - `--mode system`: Pass (SYSTEM.md generated, sibling repos detected with versions)

8. **Line count compression**
   - First pass: 694 lines total (over 500 budget)
   - Compressed all 3 scripts: removed unused `sed_i` from init.sh, collapsed single-line conditionals, removed redundant comments, merged variable assignments
   - Final: 407 lines total (well under budget)

9. **Final smoke test**
   - Full end-to-end: scan → generate → symlinks → version bump → git commit + tag
   - All passing, including Supabase detection in package.json

### Key Iterations

**Iteration 1: Glob-based file detection → find-based**
- **Initial approach**: `ls *.py src/*.py` for language detection
- **Discovery**: Shell globs don't recurse and fail silently when no match
- **Pivot**: Switched to `find . -maxdepth 4` with exclusion paths
- **Learning**: Always use `find` for file detection in scanners, never shell globs

**Iteration 2: JSON parsing without jq**
- **Initial approach**: sed pipeline stripping quotes and commas
- **Discovery**: Boolean values (`true,`) don't have surrounding quotes, so the quote-stripping sed pattern skipped the comma
- **Pivot**: Rewrote `json_val()` to strip all quotes first, then strip trailing comma separately
- **Learning**: When parsing JSON manually, handle string and boolean values with separate patterns

**Iteration 3: Non-interactive mode**
- **Initial approach**: Only check if individual values are empty before prompting
- **Discovery**: `--name "X" --purpose "Y"` still prompted for North Star and Notes
- **Pivot**: Added `INTERACTIVE` flag based on whether any CLI args or brief file was provided; added `--north-star` and `--notes` flags
- **Learning**: Non-interactive CLI tools need explicit "am I in interactive mode?" logic, not per-field checks

## Learnings & Discoveries

### Technical Discoveries

- macOS `sed -i` requires an empty string argument (`sed -i ''`), Linux doesn't — detect with `$OSTYPE`
- `git rev-parse --abbrev-ref HEAD` returns literal `HEAD` on repos with no commits
- Shell `ls *.ext` doesn't recurse and errors silently when no matches (with `2>/dev/null`)
- Bash JSON parsing without jq is doable with grep/sed but requires careful handling of types (strings vs booleans vs arrays)
- `find -exec grep -ql` is the reliable way to search file contents in bash scanners

### Process Discoveries

- Writing all files first, then iterating on bugs is faster than perfecting each file sequentially
- Testing against real projects (not just synthetic ones) catches real-world edge cases early
- The 500-line budget forced good compression habits — many verbose patterns had simpler equivalents
- Detailed specs (like the one provided) eliminate most back-and-forth, enabling near-autonomous execution

## Blockers Encountered

### Blocker 1: Glob-based file detection failing on real projects

- **Impact**: Python language detection returned "unknown" on Aurelix project
- **Root Cause**: `ls *.py src/*.py` doesn't recurse into nested directories
- **Resolution**: Replaced with `find . -maxdepth 4` with exclusion filters
- **Time Lost**: ~5 minutes
- **Prevention**: Always use `find` for recursive file detection in shell scripts

### Blocker 2: Interactive prompts firing in non-interactive mode

- **Impact**: `init.sh` hung waiting for stdin when called with `--name`/`--purpose` flags
- **Root Cause**: No concept of "interactive mode" — each field was individually checked
- **Resolution**: Added `INTERACTIVE` flag and `--north-star`/`--notes` CLI flags
- **Time Lost**: ~5 minutes
- **Prevention**: Design non-interactive modes explicitly from the start

## Final Outcome

### What Was Delivered

- `scan.sh` (131 lines) — Pure bash codebase scanner, outputs JSON, detects 17 project attributes
- `init.sh` (200 lines) — Main entry point with 3 modes (standalone, service, system), interactive and non-interactive
- `scripts/version.sh` (76 lines) — Version bump with semver, git commit + tag, system sync
- 4 templates (AGENTS.md, SESSION.md, SYSTEM.md, RELEASE_CHECKLIST.md)
- README.md with usage docs
- .gitignore
- **Total: 407 lines across scripts (under 500 budget)**

### What Wasn't Completed

- Not yet pushed to GitHub as `craigdanielk/project-ops` (user didn't request push)
- Git repo not initialized in the project directory itself

### Success Criteria

From the spec's 15 validation criteria:

- [x] `init.sh` runs without errors on an empty directory
- [x] `init.sh` runs on a Node.js project (tested with synthetic React/TS project)
- [x] `init.sh` runs on a Python project (tested against Aurelix)
- [x] `--mode service --system "Test"` adds system context section
- [x] `--mode system` generates SYSTEM.md and detects sibling dirs
- [x] `--from brief.md` works non-interactively
- [x] Generated AGENTS.md contains real detected stack info
- [x] Generated SESSION.md has correct version from package.json
- [x] CLAUDE.md is a symlink to AGENTS.md
- [x] .cursorrules is a symlink to AGENTS.md
- [x] version.sh bump correctly increments, updates SESSION.md, commits, tags
- [x] version.sh sync reads sibling SESSION.md files (tested in system mode)
- [x] project-ops/ directory removed after init
- [x] All scripts work on macOS (sed -i '' compatibility)
- [x] No external dependencies (no node, no python, no jq)

## Reusable Patterns

### Code Snippets to Save

```bash
# OS-compatible sed in-place (macOS vs Linux)
sed_i() {
  if [[ "$OSTYPE" == "darwin"* ]]; then sed -i '' "$@"; else sed -i "$@"; fi
}
```

```bash
# Parse JSON values without jq
json_val() {
  echo "$JSON" | grep "\"$1\"" | head -1 | \
    sed 's/.*:[[:space:]]*//' | sed 's/"//g' | \
    sed 's/,$//' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//'
}
```

```bash
# Detect language by file existence (reliable)
find . -maxdepth 4 -name "*.py" \
  -not -path "*/__pycache__/*" -not -path "*/.git/*" \
  -not -path "*/venv/*" 2>/dev/null | head -1 | grep -q . && has_py=true
```

### Approaches to Reuse

**Pattern: Clone-init-delete bootstrapper**
- **When to use**: Any reusable project scaffolding that should leave no trace of itself
- **How it works**: Clone repo into target, run init script, script copies needed files to target root, then `rm -rf` its own directory
- **Watch out for**: Self-deletion must be the LAST step; use `$SCRIPT_DIR` captured at start before any `cd`

**Pattern: Brief file for non-interactive init**
- **When to use**: CI/CD pipelines, batch project setup, scripted workflows
- **How it works**: Simple `Key: value` format parsed with `grep -i` + `sed`, no YAML/JSON parser needed
- **Watch out for**: Multi-line values won't work with this simple parser

## Recommendations for Next Time

### Do This

- Write all files first, test iteratively — faster than perfecting one file at a time
- Test against real projects early (not just synthetic ones)
- Set a line budget upfront and compress at the end
- Use `find` not globs for file detection in bash
- Design non-interactive mode explicitly from day 1

### Avoid This

- Shell glob patterns (`ls *.ext`) for recursive file detection
- Assuming sed patterns that work for strings will work for booleans in JSON
- Per-field empty checks as a proxy for "interactive mode"
- Writing verbose bash first and hoping it's under budget

### If Starting Over

Would design the `json_val()` parser more carefully upfront with explicit type handling (string vs boolean vs array). Would also add `--north-star` and `--notes` flags from the start rather than discovering the need during testing. The overall approach of "write everything, then test and iterate" was correct and efficient.

---

## Next Steps

**Immediate actions:**
- [ ] Initialize git repo in project_operations_system
- [ ] Push to GitHub as `craigdanielk/project-ops`
- [ ] Test on a real Next.js project to validate nextjs framework detection

**Future work:**
- [ ] Add `--quiet` flag to suppress all output except errors
- [ ] Consider adding `.windsurfrules` symlink for Windsurf IDE users
- [ ] Test on Linux to verify sed/find compatibility

**Questions to resolve:**
- [ ] Should `scan.sh` detect Go/Rust projects? (currently only JS/TS/Python)
- [ ] Should `version.sh sync` actually rewrite the SYSTEM.md table rows, or just report?

## Attachments

- `init.sh` — Main entry point (200 lines)
- `scan.sh` — Codebase scanner (131 lines)
- `scripts/version.sh` — Version management (76 lines)
- `templates/AGENTS.md.tmpl` — Agent context template
- `templates/SESSION.md.tmpl` — Session state template
- `templates/SYSTEM.md.tmpl` — System orchestrator template
- `templates/RELEASE_CHECKLIST.md` — Static release checklist

---

## Metadata

```yaml
date: 2026-02-16
duration_minutes: 45
outcome: success
tags: [project-ops, bash, scaffolding, cli-tool, codebase-scanner, version-management]
project: project-ops
phase: initial-build
related_checkpoints: []
rag_deployed: false
rag_session_id: retro-2026-02-16-2010
```
