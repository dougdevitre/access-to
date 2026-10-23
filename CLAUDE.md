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
│   ├── health-check.sh      # Ecosystem dashboard (includes the drift report)
│   ├── ecosystem-drift.sh   # Read-only disclaimer-drift + stale .skill + install-zip check across all repos
│   └── onboard-repo.sh      # New repo setup
├── workflows/               # GitHub Actions (thin orchestration calling scripts)
└── ISSUE_TEMPLATE/          # Shared issue templates

Root files are the static site (HTML/CSS, vanilla JS, no build step):
index.html + app.css + app.js   # homepage app: doors, Distribute Virtue builder, BEACON, narration
about.html + styles.css         # the full hub page (project cards, stats, sections)
<pillar>.html                   # per-pillar pages
audio/                          # narration MP3s + manifest.json, written by the Generate Narration workflow
```

## Commands

```bash
# Validate config files
.github/scripts/validate-config.sh .github/config

# Test validation in JSON log mode
LOG_FORMAT=json .github/scripts/validate-config.sh .github/config

# Regenerate generated blocks in about.html, index.html and README.md (or --check for drift)
.github/scripts/render-hub.sh

# Preview narration: which clips would be (re)generated and how many characters
.github/scripts/generate-narration.sh --dry-run

# Stamp the shared disclaimer into a repo checkout (or --check for drift)
.github/scripts/sync-disclaimer.sh <repo-name> <path-to-checkout>

# Check every repo (read-only) for disclaimer drift, stale .skill packages and missing/stale install zips; exit 1 on findings
.github/scripts/ecosystem-drift.sh [--report drift.md]

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
- When editing `repos.json`, valid pillars are: `hub`, `housing`, `jobs`, `health`, `business`, `services`, `education`, `safety`, `justice`, `peace`, `civics`, `community`, `food`, `energy`, `care`, `mobility`. Valid scopes: `missouri`, `nationwide`, `global`. Valid roles: `hub`, `pillar`, `tool`, `docs`. Optional site fields: `title`, `status` (`live`, `beta`, `skill`, `pre-pilot`, `spec`), `visibility` (`public`, `private`), `listed` (default `true`), `live_url`, `page`, `install_zip` (public repos only: the claude.ai install zip, as an asset filename on the repo's `skill-latest` release or a full https URL; `render-hub.sh` turns it into an "Install in Claude" link on the card and in the homepage sheet), `skill_package_sources` (for a repo whose root `*.skill` package is rebuilt from a few repo files: the repo paths its build copies in, e.g. access-to-services' `scripts/build-skill.sh` OWNED list; `ecosystem-drift.sh` dates the package against these instead of mapping package entries to repo paths by name, so a package's own README.md doesn't false-alarm on root README edits).
- **Project listings are generated, not hand-written.** After any `repos.json` or `journey.json` change, run `.github/scripts/render-hub.sh` and commit the updated `about.html`, `index.html` and `README.md` (badges, ecosystem diagram, pillars, project directory, impact numbers). CI runs `render-hub.sh --check` and fails if they drift. Never hand-edit between `<!-- BEGIN GENERATED:* -->` markers.
- **Root `node_modules/` is not committed.** Run `npm ci` before `npx jest`.
- A new pillar needs: an enum value in `repos.schema.json` and `validate-config.sh`, a `pillar:<name>` label in `labels.json`, and an icon in `.github/config/icons.json`.
- Private repos stay `listed` and show exactly one status label and no repo link ("source opening soon" in its place): `status: beta` shows "Private beta" with an invite-only line; any other status shows "Coming soon". The about.html card, the homepage door and the detail sheet all follow this (`tests/card-labels.test.js`). Set `"listed": false` to hide one entirely.
- `connects_to` entries must reference repo names that exist in the registry.
- **Homepage app content is config.** `journey.json` holds the welcome, the Distributed Virtue framework (BEACON, nine virtues, four gates; canonical in `dougdevitre/distributed-virtue` `lib/beacon/`) and one `adoption` entry (adopter + first pilot) per listed project. A new project needs an `adoption` entry or `tests/app.test.js` fails.
- **Narration.** `narration-clips.sh` composes every spoken script from config; the same text is embedded as the on-screen transcript, so they cannot drift. The Generate Narration workflow speaks changed clips in Doug's ElevenLabs voice (`narration.json`) and commits `audio/`. The API key lives only in the `ELEVENLABS_API_KEY` repository secret. Never hand-edit `audio/`.
- **Every app shows the disclaimer** (educational only, 911/988, verify with official sources, no identifying details, no endorsement or warranty).
- **The disclaimer wording lives once, in `.github/disclaimer/`.** `sync-disclaimer.sh <repo> <dir>` stamps it into a checkout: `DISCLAIMER.md`, a notice under the README title, and a once-per-conversation notice in `SKILL.md` (between `BEGIN/END DISCLAIMER` markers; repo-specific disclaimers outside the markers stay). To change the wording, edit the templates, then re-run the script for every repo and open a PR in each. Never edit a synced block in a child repo. Every hub page carries a `.footer-notice` (or `#disclaimer` on the homepage); `tests/disclaimer.test.js` enforces both.
- **Ecosystem drift is checked monthly.** `ecosystem-drift.sh` fetches each repo's disclaimer files through `gh api` and runs `sync-disclaimer.sh --check` on them (a repo whose SKILL.md exists only inside a root `*.skill` package has that copy read out of the package and checked), flags any root `*.skill` package whose last commit is older than the newest commit to the paths it contains (or to its `skill_package_sources`, when set), and, for every repo with `install_zip`, flags a missing `skill-latest` release or asset, or a release whose tagged commit is older than the newest main commit touching `SKILL.md`, `references/`, `templates/`, `modules/`, `skill/`, `locales/` or a root `*.skill` (fix: `gh workflow run skill-package.yml -R dougdevitre/<repo> --ref main`). It never writes to a child repo. `.github/workflows/ecosystem-drift.yml` (monthly + manual, not on PRs) keeps one issue, "Ecosystem drift (monthly check)", open with the fix command per repo and closes it when clean. To cover private repos it needs the `ECOSYSTEM_READ_TOKEN` secret: a fine-grained token with Contents and Metadata read-only on the Access To repos; without it, private repos are skipped with a warning. When you rebuild a `.skill` package or re-stamp the disclaimer, run the script to confirm. `tests/ecosystem-drift.test.js` uses a fake `gh` (`tests/helpers/fake-gh.js`), so it needs no network.
- **CI runs Jest** (`.github/workflows/test.yml`) on every PR.
- **Links are checked** by `.github/workflows/link-check.yml` (lychee over the root `*.html` and `*.md`, not CLAUDE.md, `audio/` or `node_modules`): PRs that touch pages or docs fail on a broken link; the monthly run keeps one "Broken links (monthly check)" issue. Every `.lycheeignore` entry needs a comment saying why. Fix a broken link only with a replacement you have confirmed loads; never delete crisis, legal or benefits information to make it pass.
