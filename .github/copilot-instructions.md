# Copilot Instructions for Access To

You are working in the **Access To** ecosystem — a collection of open-source Claude Skills that close access gaps in housing, jobs, health, education, services, safety, and business.

## Architecture

This is the **hub repository**. It contains:
- A static landing site (HTML/CSS, no frameworks)
- An admin system that manages 8 interconnected repos
- Config-driven automation (`.github/config/`, `.github/scripts/`, `.github/workflows/`)

Child repos each contain a `SKILL.md` file — a structured prompt system designed to run inside Claude.ai Projects with no code.

## Key conventions

### File structure
- **Config files** live in `.github/config/` (JSON, validated by schemas in `.github/schemas/`)
- **Admin scripts** live in `.github/scripts/` (bash, all source `lib-log.sh` for structured logging)
- **Workflows** live in `.github/workflows/` (thin orchestration that calls scripts)
- **Static site** files are in the repo root (HTML, CSS, no build step)

### Code style
- **HTML**: Semantic elements, ARIA labels, no inline styles
- **CSS**: Use existing CSS variables defined in `styles.css`. No frameworks.
- **JavaScript**: Vanilla JS only. No frameworks, no npm, no dependencies.
- **Bash scripts**: Use `set -euo pipefail`. Source `lib-log.sh`. Use `log_info`, `log_warn`, `log_error`, `log_action` instead of raw `echo`.
- **JSON configs**: Follow the schemas in `.github/schemas/`. Run `validate-config.sh` after changes.

### Cross-repo awareness
- The repo registry is `.github/config/repos.json` — always check it for repo names, pillars, and connections.
- Labels are defined in `.github/config/labels.json` — use the `namespace:value` convention (e.g., `pillar:housing`, `type:bug`, `status:triage`).
- When a change affects multiple repos, use the `cross-repo` label and reference the hub coordination issue.

### What NOT to do
- Do not add npm, bundlers, or build tools to the hub site
- Do not hardcode repo lists — read from `repos.json`
- Do not use `echo` for logging in scripts — use `lib-log.sh` functions
- Do not suppress errors with `2>/dev/null` without capturing the output first
- Do not add inline styles to HTML — use CSS variables

### When reviewing PRs
- Check that config changes pass `validate-config.sh`
- Verify `connects_to` references point to real repos in the registry
- Ensure new labels follow the `namespace:value` naming pattern
- Confirm HTML changes work in dark mode and are responsive
- Look for accessibility issues (missing ARIA labels, low contrast, missing alt text)

### Repo relationships
Each pillar repo is independent but connected. Key cross-pillar flows:
- Safety → Health, Housing, Services (survivors need multiple supports)
- Jobs → Education, Services (job seekers need training and benefits)
- Housing → Safety, Jobs (stable housing enables other access)
- Services → all pillars (social services are the coordination layer)
