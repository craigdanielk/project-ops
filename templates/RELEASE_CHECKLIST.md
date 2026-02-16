# Release Checklist

Copy this for each milestone integration.

```
Milestone: ___
Version: ___ -> ___

PRE-INTEGRATION
[ ] Current tests pass (baseline)
[ ] Current commit tagged
[ ] Feature branch created

INTEGRATION
[ ] All build phases complete
[ ] Phase-by-phase commits on feature branch

TESTING
[ ] All existing tests pass (regression)
[ ] All new tests pass (validation)
[ ] End-to-end validation succeeds

VERSION & DOCS
[ ] Version bumped: ./scripts/version.sh bump <level> "description"
[ ] AGENTS.md still accurate
[ ] No stale references to old behavior

MERGE & RELEASE
[ ] Feature branch merged to main
[ ] Release tagged
[ ] Pushed to GitHub
[ ] Feature branch deleted

SMOKE TEST
[ ] Tests pass on main
[ ] Real build succeeds from main
```
