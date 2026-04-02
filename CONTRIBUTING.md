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
