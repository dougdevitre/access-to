# Contributing to Access To

Thanks for your interest in contributing! These tools exist to close access gaps — and contributions from the community make them stronger.

## Quick Links

- [Report a Bug](https://github.com/dougdevitre/access-to/issues/new?template=bug_report.md)
- [Request a Feature](https://github.com/dougdevitre/access-to/issues/new?template=feature_request.md)
- [Propose a New Pillar](https://github.com/dougdevitre/access-to/issues/new?template=new_pillar.md)

## How to Contribute

### 1. Fork & Clone

```bash
git clone https://github.com/YOUR-USERNAME/access-to.git
cd access-to
```

### 2. Create a Branch

```bash
git checkout -b feature/your-idea
```

### 3. Make Your Changes

- **Hub site changes** — Edit HTML, CSS, or JS files in the root directory
- **README or docs** — Edit markdown files directly
- **Individual project contributions** — See the contributing guidelines in each child repo
- **Cross-repo work** — See [Working Across Repos](#working-across-repos) below

### 4. Test Locally

Open `index.html` in your browser to verify your changes. Check:
- Dark mode toggle works
- Responsive layout at different screen widths
- All links point to the correct destinations
- No console errors

### 5. Submit a Pull Request

```bash
git push origin feature/your-idea
```

Then open a pull request on GitHub. Include:
- A clear description of what you changed and why
- Screenshots if you changed anything visual
- Which pages/sections are affected

## Contribution Types

| Type | Where | Examples |
|:-----|:------|:--------|
| **Bug fixes** | This repo | Broken links, layout issues, typos |
| **Content updates** | This repo | New project descriptions, updated stats |
| **New pillar pages** | This repo | Adding a new `.html` pillar page |
| **Skill improvements** | Child repos | Enhancing SKILL.md prompts, adding modules |
| **Documentation** | Any repo | README improvements, guides, FAQs |

## Working Across Repos

The Access To ecosystem spans multiple repositories. Some features, bug fixes, or content changes touch more than one repo.

### When does work become cross-repo?

- A user flow starts in one pillar and depends on another (e.g., safety planning that references housing resources)
- A shared data format or label convention changes
- A SKILL.md module references content from another pillar
- A hub site change needs matching updates in child repos

### How to coordinate

1. **Open a cross-repo issue** in the hub repo using the [Cross-Repo Coordination](https://github.com/dougdevitre/access-to/issues/new?template=cross_repo.md) template
2. **Apply the `cross-repo` label** to related issues in each child repo — the weekly health check tracks these
3. **List dependencies** in the coordination issue so reviewers know the merge order
4. **Reference the hub issue** from each child repo PR (e.g., "Part of dougdevitre/access-to#42")

### Shared infrastructure

All repos share a consistent set of labels, issue templates, and project tracking managed from the hub:

| Config | Location | Synced by |
|:-------|:---------|:----------|
| Labels | `.github/config/labels.json` | `sync-labels.yml` |
| Repo registry | `.github/config/repos.json` | `sync-repos-to-project.yml` |
| Issue templates | `.github/ISSUE_TEMPLATE/` | `sync-templates.yml` |
| SKILL.md validation | Reusable workflow | `reusable-skill-check.yml` |

### Adding a new repo to the ecosystem

Run the onboarding script from the hub repo:

```bash
.github/scripts/onboard-repo.sh <repo-name> <pillar> [scope]
```

This syncs labels, adds the repo to the GitHub Project, and creates a setup checklist issue. See the generated issue for remaining manual steps.

## Style Guide

- **HTML** — Semantic elements, ARIA labels, no inline styles
- **CSS** — Use existing CSS variables (defined in `styles.css`)
- **JavaScript** — Vanilla JS only, no frameworks or dependencies
- **Markdown** — Follow existing formatting conventions in README.md
- **Commits** — Write clear, descriptive commit messages

## Code of Conduct

This project follows our [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you agree to uphold a welcoming, inclusive environment.

## Questions?

Open an issue or reach out to [Doug Devitre](mailto:dougdevitre@gmail.com).
