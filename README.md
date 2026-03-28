# Access Projects

**Open-source, AI-powered tools closing the access gaps that matter most.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![GitHub Pages](https://img.shields.io/badge/Live_Site-GitHub_Pages-222?logo=github)](https://dougdevitre.github.io/access-projects/)
[![Projects](https://img.shields.io/badge/Projects-9-5B7A3A)](https://dougdevitre.github.io/access-projects/#pillars)
[![Pillars](https://img.shields.io/badge/Pillars-5-2D5A7B)](https://dougdevitre.github.io/access-projects/#pillars)

A growing collection of open-source projects organized around five pillars of human access — built for practitioners, advocates, and the people they serve.

[**View the live site →**](https://dougdevitre.github.io/access-projects/)

---

## Pillars

| Pillar | Focus | Projects |
|--------|-------|----------|
| **[Justice](https://dougdevitre.github.io/access-projects/justice.html)** | Court prep, co-parenting docs, expungement | [cotrackpro](https://github.com/dougdevitre/cotrackpro), [expunge-skill](https://github.com/dougdevitre/expunge-skill) |
| **[Education](https://dougdevitre.github.io/access-projects/education.html)** | K-12 standards, lesson planning, teacher growth | [doug](https://github.com/dougdevitre/doug) |
| **[Housing](https://dougdevitre.github.io/access-projects/housing.html)** | PropTech intelligence, Fair Housing-safe | [better-broker](https://github.com/dougdevitre/better-broker) |
| **[Services](https://dougdevitre.github.io/access-projects/services.html)** | Workforce dev, WIOA, startups | [mo-jobs](https://github.com/dougdevitre/mo-jobs), [mostart](https://github.com/dougdevitre/mostart), [jta-platform](https://github.com/dougdevitre/jta-platform) |
| **[Peace](https://dougdevitre.github.io/access-projects/peace.html)** | De-escalation, safety planning | [cotrackpro-skills](https://github.com/dougdevitre/cotrackpro-skills), [lois247](https://github.com/dougdevitre/lois247) |

---

## What are Claude Skills?

These projects are **structured AI prompt systems** that run inside [Claude.ai](https://claude.ai). No coding required — they work entirely through conversation.

### Quick start

```bash
# 1. Clone any project
git clone https://github.com/dougdevitre/expunge-skill.git

# 2. Open Claude.ai → Create a Project → Upload SKILL.md as project knowledge

# 3. Start a conversation — the skill guides you from there
```

Each skill's `SKILL.md` file teaches Claude a specialized workflow — from generating court-ready documents to navigating workforce programs across all 114 Missouri counties.

---

## Site architecture

This is a zero-dependency static site — no build step, no frameworks, no Node modules.

```
├── index.html          # Landing page with all 5 pillars
├── justice.html        # Access to Justice detail page
├── education.html      # Access to Education detail page
├── housing.html        # Access to Housing detail page
├── services.html       # Access to Services detail page
├── peace.html          # Access to Peace detail page
├── 404.html            # Custom error page
├── styles.css          # Shared stylesheet (dark mode, responsive, print)
├── manifest.json       # PWA manifest
├── og-image.png        # Social sharing image (1200×630)
├── sitemap.xml         # XML sitemap for search engines
└── robots.txt          # Crawler configuration
```

### Tech stack

| Layer | Technology |
|-------|-----------|
| **Markup** | Semantic HTML5 |
| **Styling** | Vanilla CSS (variables, Grid, Flexbox) |
| **Interactivity** | Vanilla JavaScript (no dependencies) |
| **Fonts** | [DM Serif Display](https://fonts.google.com/specimen/DM+Serif+Display) + [DM Sans](https://fonts.google.com/specimen/DM+Sans) via Google Fonts |
| **Badges** | [Shields.io](https://shields.io) (live GitHub stats) |
| **Hosting** | [GitHub Pages](https://pages.github.com) |
| **SEO** | OpenGraph, Twitter Cards, JSON-LD structured data, XML sitemap |

### Features

- **Dark mode** — system preference detection + manual toggle with localStorage persistence
- **Responsive** — mobile-first with breakpoints at 500px, 600px, and 700px
- **Accessible** — skip-to-content link, ARIA labels, keyboard navigation, reduced motion support
- **Fast** — zero JavaScript dependencies, font preloading, lazy-loaded images
- **Print-ready** — dedicated print styles for all pages

---

## Contributing

Issues, PRs, and feature ideas are welcome.

1. Fork this repository
2. Create a feature branch (`git checkout -b feature/your-idea`)
3. Make your changes
4. Submit a pull request

For individual project contributions, see each project repo's own guidelines.

---

## Support

These tools are free. Building them isn't.

[**Fund the mission on Venmo →**](https://venmo.com/dougdevitre)

100% goes to development. No overhead. Receipt on request.

---

## Contact

**Doug Devitre** — product builder, speaker, and founder of [CoTrackPro](https://cotrackpro.com). Based in the St. Louis metro area.

Focused on family law technology, workforce development, and civic access tools for Missouri and beyond.

[LinkedIn](https://linkedin.com/in/dougdevitre) · [GitHub](https://github.com/dougdevitre) · [Email](mailto:dougdevitre@gmail.com)

For partnerships or speaking inquiries: [dougdevitre@gmail.com](mailto:dougdevitre@gmail.com)

---

## License

Open source under [MIT](https://opensource.org/licenses/MIT) unless otherwise noted in individual project repositories.

&copy; 2026 Doug Devitre
