# CLAUDE.md — Instructions for Claude Code

## Project overview

Access To is a hub-and-spokes ecosystem of open-source Claude Skills. This repo is the **hub** — it contains the landing site and the admin system that orchestrates all child repos.

## Repository structure

```
.github/
├── config/repos.json       # Source of truth for all repos (name, pillar, scope, connections)
├── config/labels.json       # Shared label taxonomy synced to all repos
├── schemas/                 # JSON Schemas for config validation
├── scripts/                 # Admin scripts (all source lib-log.sh)
│   ├── lib-log.sh           # Shared logging library (always use this, never raw echo)
│   ├── validate-config.sh   # Config integrity checks
│   ├── sync-repos.sh        # Sync repos → GitHub Project
│   ├── sync-labels.sh       # Push labels → all repos
│   ├── sync-templates.sh    # Push issue templates → child repos
│   ├── health-check.sh      # Ecosystem dashboard
│   └── onboard-repo.sh      # New repo setup
├── workflows/               # GitHub Actions (thin orchestration calling scripts)
└── ISSUE_TEMPLATE/          # Shared issue templates

Root files are the static landing site (HTML/CSS, vanilla JS, no build step).
```

## Commands

```bash
# Validate config files
.github/scripts/validate-config.sh .github/config

# Test validation in JSON log mode
LOG_FORMAT=json .github/scripts/validate-config.sh .github/config

# Onboard a new repo
.github/scripts/onboard-repo.sh <repo-name> <pillar> [scope]

# View the site locally
open index.html
```

## Rules

- **No frameworks.** HTML/CSS/JS only for the site. No npm, no bundlers.
- **Config-driven.** Never hardcode repo lists. Read from `repos.json`.
- **Structured logging.** Source `lib-log.sh` in all scripts. Use `log_info`, `log_warn`, `log_error`, `log_action`.
- **Schema-validated.** Config changes must pass `validate-config.sh`. Run it before committing.
- **Accessible.** All HTML must include ARIA labels, work with keyboard navigation, and support dark mode.
- **Idempotent.** All sync scripts must be safe to re-run.
- **Exit codes matter.** Scripts exit 1 on errors — don't mask failures.
- When editing `repos.json`, valid pillars are: `hub`, `housing`, `jobs`, `health`, `business`, `services`, `education`, `safety`. Valid scopes: `missouri`, `nationwide`, `global`. Valid roles: `hub`, `pillar`, `tool`, `docs`.
- `connects_to` entries must reference repo names that exist in the registry.
