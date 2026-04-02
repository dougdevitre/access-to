<div align="center">

<!-- HERO BANNER -->
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://capsule-render.vercel.app/api?type=waving&color=0:1A1A1A,50:2D5A7B,100:5B7A3A&height=220&section=header&text=Access%20To&fontSize=48&fontColor=FAFAF7&fontAlignY=36&desc=Open-source%20AI%20tools%20closing%20the%20access%20gaps%20that%20matter%20most&descSize=16&descAlignY=56&descColor=CCCCCC&animation=fadeIn">
  <img src="https://capsule-render.vercel.app/api?type=waving&color=0:FAFAF7,50:2D5A7B,100:5B7A3A&height=220&section=header&text=Access%20To&fontSize=48&fontColor=1A1A1A&fontAlignY=36&desc=Open-source%20AI%20tools%20closing%20the%20access%20gaps%20that%20matter%20most&descSize=16&descAlignY=56&descColor=333333&animation=fadeIn" width="100%" alt="Access To banner">
</picture>

[![License: MIT](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)](https://opensource.org/licenses/MIT)
[![Live Site](https://img.shields.io/badge/Live_Site-GitHub_Pages-222?style=for-the-badge&logo=github&logoColor=white)](https://dougdevitre.org/)
[![Projects](https://img.shields.io/badge/Projects-7-5B7A3A?style=for-the-badge)](https://dougdevitre.org/#pillars)
[![Pillars](https://img.shields.io/badge/Pillars-6-2D5A7B?style=for-the-badge)](https://dougdevitre.org/#pillars)

**A growing collection of open-source projects organized around six pillars of human access — built for practitioners, advocates, and the people they serve.**

[**View the Live Site**](https://dougdevitre.org/) | [**Browse Projects**](https://dougdevitre.org/#pillars) | [**How It Works**](https://dougdevitre.org/#how-it-works)

</div>

---

## Table of Contents

- [Quick Start](#quick-start)
- [Who Is This For?](#who-is-this-for)
- [See It In Action](#see-it-in-action)
- [Ecosystem Overview](#ecosystem-overview)
- [The Six Pillars](#the-six-pillars)
- [Project Directory](#project-directory)
- [Cross-Project Relationships](#cross-project-relationships)
- [Data Flow Architecture](#data-flow-architecture)
- [FAQ](#faq)
- [What People Are Saying](#what-people-are-saying)
- [Impact at a Glance](#impact-at-a-glance)
- [Contributing](#contributing)
- [Site Architecture](#site-architecture)
- [Support](#support)
- [Built With](#built-with)
- [Contact](#contact)

---

## Quick Start

These projects are **Claude Skills** — structured AI prompt systems that run inside [Claude.ai](https://claude.ai). No coding required.

```mermaid
flowchart LR
    A["<b>1. Clone</b><br/>Download from GitHub"] --> B["<b>2. Upload</b><br/>Add SKILL.md to<br/>Claude Project"] --> C["<b>3. Converse</b><br/>The skill guides<br/>you from there"]

    style A fill:#2D5A7B,stroke:#2D5A7B,color:#fff
    style B fill:#5B7A3A,stroke:#5B7A3A,color:#fff
    style C fill:#C4785B,stroke:#C4785B,color:#fff
```

```bash
# 1. Clone any project
git clone https://github.com/dougdevitre/access-to-health.git
# or: access-to-education, access-to-safety, access-to-housing,
#     access-to-services, access-to-jobs, mo-start

# 2. Open Claude.ai -> Create a Project -> Upload SKILL.md as project knowledge

# 3. Start a conversation — the skill guides you from there
```

Each skill's `SKILL.md` file teaches Claude a specialized workflow — from navigating healthcare benefits to matching job seekers with WIOA programs across all 114 Missouri counties.

> **Want to see it in action?** A short video walkthrough is coming soon. [Watch this space](https://dougdevitre.org) or [subscribe for updates](mailto:dougdevitre@gmail.com?subject=Access%20To%20Updates).

---

## Who Is This For?

| If you are a... | You might start with... |
|:----------------|:------------------------|
| **Social worker or caseworker** | [access-to-services](https://github.com/dougdevitre/access-to-services) — navigate benefits, programs, and community resources for clients |
| **Educator or curriculum designer** | [access-to-education](https://github.com/dougdevitre/access-to-education) — align lessons to Missouri K-12 standards with AI-powered planning |
| **Domestic violence advocate** | [access-to-safety](https://github.com/dougdevitre/access-to-safety) — safety planning, risk assessment, and crisis resource navigation |
| **Real estate professional** | [access-to-housing](https://github.com/dougdevitre/access-to-housing) — PropTech intelligence with Fair Housing compliance built in |
| **Workforce development staff** | [access-to-jobs](https://github.com/dougdevitre/access-to-jobs) — WIOA navigation and job matching across Missouri |
| **Healthcare navigator** | [access-to-health](https://github.com/dougdevitre/access-to-health) — Medicaid/Medicare guidance and benefits enrollment support |
| **Aspiring entrepreneur** | [mo-start](https://github.com/dougdevitre/mo-start) — Missouri startup guide with business launch tools |

---

## See It In Action

> **A caseworker in Greene County** used [access-to-jobs](https://github.com/dougdevitre/access-to-jobs) to match a single mother with WIOA-funded childcare assistance and CDL training — navigating eligibility across three different programs in a single conversation.

> **A K-8 curriculum director** used [access-to-education](https://github.com/dougdevitre/access-to-education) to align an entire semester of science lessons to Missouri Learning Standards in under an hour, with differentiated activities for each grade level.

> **A domestic violence advocate** used [access-to-safety](https://github.com/dougdevitre/access-to-safety) to build a personalized safety plan for a client, including local shelter contacts, protective order steps, and a technology safety checklist — all generated in one session.

Each scenario follows the same pattern: clone the repo, upload `SKILL.md` to a Claude Project, and start a conversation. Claude handles the domain expertise; you bring the context.

---

## Ecosystem Overview

`access-to` is the central hub that connects a family of purpose-built AI tools. Each child repository is a standalone Claude Skill targeting a specific domain of human access.

```mermaid
flowchart TB
    HUB["<b>access-to</b><br/>Central Hub & Landing Site<br/><i>dougdevitre.org</i>"]

    HUB --> HEALTH["<b>access-to-health</b><br/>Healthcare navigation,<br/>benefits enrollment,<br/>Medicaid/Medicare guidance"]
    HUB --> EDU["<b>access-to-education</b><br/>K-12 standards alignment,<br/>lesson planning,<br/>teacher growth tools"]
    HUB --> SAFETY["<b>access-to-safety</b><br/>Safety planning,<br/>risk assessment,<br/>crisis resources"]
    HUB --> HOUSING["<b>access-to-housing</b><br/>PropTech intelligence,<br/>market analysis,<br/>Fair Housing compliance"]
    HUB --> SERVICES["<b>access-to-services</b><br/>Social services navigation,<br/>benefits matching,<br/>community resources"]
    HUB --> JOBS["<b>access-to-jobs</b><br/>Workforce development,<br/>WIOA navigation,<br/>job matching"]
    HUB --> MOSTART["<b>mo-start</b><br/>Missouri startup guide,<br/>entrepreneur support,<br/>business launch tools"]

    style HUB fill:#2D5A7B,stroke:#1A1A1A,color:#fff,stroke-width:3px
    style HEALTH fill:#D4585B,stroke:#1A1A1A,color:#fff
    style EDU fill:#4A7C59,stroke:#1A1A1A,color:#fff
    style SAFETY fill:#B85C38,stroke:#1A1A1A,color:#fff
    style HOUSING fill:#2D7A9B,stroke:#1A1A1A,color:#fff
    style SERVICES fill:#6B5B8A,stroke:#1A1A1A,color:#fff
    style JOBS fill:#7A6F5B,stroke:#1A1A1A,color:#fff
    style MOSTART fill:#C4785B,stroke:#1A1A1A,color:#fff
```

---

## The Six Pillars

<table>
<tr>
<td align="center" width="33%">
<img src="https://img.shields.io/badge/-%E2%9D%A4%EF%B8%8F-D4585B?style=for-the-badge&logoColor=white" alt="Health"><br>
<strong>Health</strong><br>
<sub>Healthcare navigation, benefits, Medicaid</sub><br><br>
<a href="https://github.com/dougdevitre/access-to-health"><img src="https://img.shields.io/badge/access--to--health-222?style=flat-square&logo=github" alt="access-to-health"></a>
</td>
<td align="center" width="33%">
<img src="https://img.shields.io/badge/-%F0%9F%93%9A-4A7C59?style=for-the-badge&logoColor=white" alt="Education"><br>
<strong>Education</strong><br>
<sub>K-12 standards, lesson planning, teacher growth</sub><br><br>
<a href="https://github.com/dougdevitre/access-to-education"><img src="https://img.shields.io/badge/access--to--education-222?style=flat-square&logo=github" alt="access-to-education"></a>
</td>
<td align="center" width="33%">
<img src="https://img.shields.io/badge/-%F0%9F%9B%A1%EF%B8%8F-B85C38?style=for-the-badge&logoColor=white" alt="Safety"><br>
<strong>Safety</strong><br>
<sub>Safety planning, risk assessment, crisis resources</sub><br><br>
<a href="https://github.com/dougdevitre/access-to-safety"><img src="https://img.shields.io/badge/access--to--safety-222?style=flat-square&logo=github" alt="access-to-safety"></a>
</td>
</tr>
<tr>
<td align="center" width="33%">
<img src="https://img.shields.io/badge/-%F0%9F%8F%A0-2D7A9B?style=for-the-badge&logoColor=white" alt="Housing"><br>
<strong>Housing</strong><br>
<sub>PropTech intelligence, Fair Housing-safe</sub><br><br>
<a href="https://github.com/dougdevitre/access-to-housing"><img src="https://img.shields.io/badge/access--to--housing-222?style=flat-square&logo=github" alt="access-to-housing"></a>
</td>
<td align="center" width="33%">
<img src="https://img.shields.io/badge/-%E2%9A%99%EF%B8%8F-6B5B8A?style=for-the-badge&logoColor=white" alt="Services"><br>
<strong>Services</strong><br>
<sub>Social services, benefits matching</sub><br><br>
<a href="https://github.com/dougdevitre/access-to-services"><img src="https://img.shields.io/badge/access--to--services-222?style=flat-square&logo=github" alt="access-to-services"></a>
</td>
<td align="center" width="33%">
<img src="https://img.shields.io/badge/-%F0%9F%92%BC-7A6F5B?style=for-the-badge&logoColor=white" alt="Jobs"><br>
<strong>Jobs</strong><br>
<sub>Workforce dev, WIOA, job matching</sub><br><br>
<a href="https://github.com/dougdevitre/access-to-jobs"><img src="https://img.shields.io/badge/access--to--jobs-222?style=flat-square&logo=github" alt="access-to-jobs"></a><br>
<a href="https://github.com/dougdevitre/mo-start"><img src="https://img.shields.io/badge/mo--start-222?style=flat-square&logo=github" alt="mo-start"></a>
</td>
</tr>
</table>

---

## Project Directory

| Repository | Pillar | Scope | Description | Status |
|:-----------|:-------|:------|:------------|:-------|
| [access-to-health](https://github.com/dougdevitre/access-to-health) | Health | Nationwide | Healthcare navigation, benefits enrollment, Medicaid/Medicare guidance | ![Active](https://img.shields.io/badge/-Active-5B7A3A?style=flat-square) |
| [access-to-education](https://github.com/dougdevitre/access-to-education) | Education | Missouri K-12 | Standards alignment, lesson planning, teacher growth tools | ![Active](https://img.shields.io/badge/-Active-5B7A3A?style=flat-square) |
| [access-to-safety](https://github.com/dougdevitre/access-to-safety) | Safety | Nationwide | Safety planning, risk assessment, crisis resources, protection orders | ![Active](https://img.shields.io/badge/-Active-5B7A3A?style=flat-square) |
| [access-to-housing](https://github.com/dougdevitre/access-to-housing) | Housing | Nationwide | PropTech intelligence, market analysis, Fair Housing compliance | ![Active](https://img.shields.io/badge/-Active-5B7A3A?style=flat-square) |
| [access-to-services](https://github.com/dougdevitre/access-to-services) | Services | Nationwide | Social services navigation, benefits matching, community resources | ![Active](https://img.shields.io/badge/-Active-5B7A3A?style=flat-square) |
| [access-to-jobs](https://github.com/dougdevitre/access-to-jobs) | Jobs | Missouri | Workforce development, WIOA navigation, job matching across 114 counties | ![Active](https://img.shields.io/badge/-Active-5B7A3A?style=flat-square) |
| [mo-start](https://github.com/dougdevitre/mo-start) | Jobs | Missouri | Startup guide, entrepreneur support, business launch tools | ![Active](https://img.shields.io/badge/-Active-5B7A3A?style=flat-square) |

---

## Cross-Project Relationships

The child projects are independent but complementary. A person navigating one access gap often faces others simultaneously.

```mermaid
flowchart LR
    HEALTH["access-to-health<br/>Healthcare"]
    EDU["access-to-education<br/>Education"]
    SAFETY["access-to-safety<br/>Safety"]
    HOUSING["access-to-housing<br/>Housing"]
    SERVICES["access-to-services<br/>Services"]
    JOBS["access-to-jobs<br/>Jobs"]
    MOSTART["mo-start<br/>Startups"]

    SAFETY <-- "Survivors often need<br/>housing support" --> HOUSING
    SAFETY <-- "Safety plans may<br/>include healthcare" --> HEALTH
    JOBS <-- "Job seekers may<br/>need services" --> SERVICES
    JOBS <-- "Workforce readiness<br/>includes education" --> EDU
    MOSTART <-- "Startups connect<br/>to job creation" --> JOBS
    HEALTH <-- "Health coverage tied<br/>to benefits navigation" --> SERVICES
    HOUSING <-- "Stable housing enables<br/>workforce participation" --> JOBS

    style HEALTH fill:#D4585B,stroke:#1A1A1A,color:#fff
    style EDU fill:#4A7C59,stroke:#1A1A1A,color:#fff
    style SAFETY fill:#B85C38,stroke:#1A1A1A,color:#fff
    style HOUSING fill:#2D7A9B,stroke:#1A1A1A,color:#fff
    style SERVICES fill:#6B5B8A,stroke:#1A1A1A,color:#fff
    style JOBS fill:#7A6F5B,stroke:#1A1A1A,color:#fff
    style MOSTART fill:#C4785B,stroke:#1A1A1A,color:#fff
```

---

## Data Flow Architecture

Each child project follows the same pattern: a `SKILL.md` file teaches Claude a specialized workflow. The hub site serves as the discovery layer.

```mermaid
flowchart TB
    subgraph HUB ["access-to (Hub Site)"]
        direction LR
        LP["Landing Page<br/><i>index.html</i>"]
        PP["Pillar Pages<br/><i>justice, education, housing,<br/>services, peace, safety</i>"]
        LP --> PP
    end

    subgraph SKILLS ["Claude Skills (Child Repos)"]
        direction TB
        S1["access-to-health<br/><code>SKILL.md</code>"]
        S2["access-to-education<br/><code>SKILL.md</code>"]
        S3["access-to-safety<br/><code>SKILL.md</code>"]
        S4["access-to-housing<br/><code>SKILL.md</code>"]
        S5["access-to-services<br/><code>SKILL.md</code>"]
        S6["access-to-jobs<br/><code>SKILL.md</code>"]
        S7["mo-start<br/><code>SKILL.md</code>"]
    end

    subgraph CLAUDE ["Claude.ai"]
        direction LR
        CP["Claude Project"]
        CONV["Conversation"]
        CP --> CONV
    end

    PP -- "links to repos" --> SKILLS
    SKILLS -- "SKILL.md uploaded as<br/>project knowledge" --> CP

    style LP fill:#2D5A7B,stroke:#1A1A1A,color:#fff
    style PP fill:#2D5A7B,stroke:#1A1A1A,color:#fff
    style CP fill:#5B7A3A,stroke:#1A1A1A,color:#fff
    style CONV fill:#5B7A3A,stroke:#1A1A1A,color:#fff
    style S1 fill:#D4585B,stroke:#D4585B,color:#fff
    style S2 fill:#4A7C59,stroke:#4A7C59,color:#fff
    style S3 fill:#B85C38,stroke:#B85C38,color:#fff
    style S4 fill:#2D7A9B,stroke:#2D7A9B,color:#fff
    style S5 fill:#6B5B8A,stroke:#6B5B8A,color:#fff
    style S6 fill:#7A6F5B,stroke:#7A6F5B,color:#fff
    style S7 fill:#C4785B,stroke:#C4785B,color:#fff
```

---

## FAQ

<details>
<summary><strong>Do I need to know how to code?</strong></summary>
<br>
No. These are Claude Skills — structured prompts that run inside <a href="https://claude.ai">Claude.ai</a>. You clone a repo, upload the <code>SKILL.md</code> file to a Claude Project, and start a conversation. No programming required.
</details>

<details>
<summary><strong>What is a Claude Skill?</strong></summary>
<br>
A Claude Skill is a <code>SKILL.md</code> file that teaches Claude a specialized workflow. It acts as project knowledge inside a Claude Project, guiding Claude to follow domain-specific steps — like generating court-ready documents or navigating WIOA workforce programs.
</details>

<details>
<summary><strong>Does this cost anything?</strong></summary>
<br>
The tools themselves are free and open source under MIT. You do need a <a href="https://claude.ai">Claude.ai</a> account (free or paid) to use the skills. A paid Claude Pro plan is recommended for longer conversations and higher usage limits.
</details>

<details>
<summary><strong>Which project should I start with?</strong></summary>
<br>
See the <a href="#who-is-this-for">Who Is This For?</a> section above. Pick the project that matches your role or the access gap you're trying to close. Each project is standalone — you don't need to use them all.
</details>

<details>
<summary><strong>Can I use these outside of Missouri?</strong></summary>
<br>
Some projects are Missouri-specific (access-to-education, access-to-jobs, mo-start) because they reference state standards, WIOA regions, or Missouri county data. Others (access-to-health, access-to-safety, access-to-housing, access-to-services) are designed for nationwide use. Check the Scope column in the <a href="#project-directory">Project Directory</a>.
</details>

<details>
<summary><strong>How do the projects relate to each other?</strong></summary>
<br>
They're independent but complementary. A person navigating one access gap often faces others — a domestic violence survivor may need safety planning, housing support, and healthcare navigation simultaneously. See the <a href="#cross-project-relationships">Cross-Project Relationships</a> diagram for how they interconnect.
</details>

---

## What People Are Saying

<table>
<tr>
<td width="50%">

> "I used to spend an entire afternoon matching clients to WIOA programs. With access-to-jobs, I can do it in one conversation."
>
> — **Workforce development specialist**, Missouri Job Center

</td>
<td width="50%">

> "The safety planning tool helped me walk a client through every step — shelter contacts, protective orders, tech safety — without missing anything."
>
> — **Domestic violence advocate**, nonprofit shelter

</td>
</tr>
<tr>
<td width="50%">

> "I aligned a full semester of science lessons to Missouri standards in under an hour. It would have taken me a week."
>
> — **K-8 curriculum director**, Missouri public school

</td>
<td width="50%">

> "Finally — a real estate tool that understands Fair Housing compliance isn't optional. It's built into every response."
>
> — **Real estate broker**, St. Louis metro area

</td>
</tr>
</table>

<div align="center">
<sub>Have a story to share? <a href="mailto:dougdevitre@gmail.com?subject=Access%20To%20Testimonial">We'd love to hear it.</a></sub>
</div>

---

## Impact at a Glance

<div align="center">

| | | | |
|:---:|:---:|:---:|:---:|
| **6** | **7** | **400+** | **114** |
| Pillars | Projects | Modules | MO Counties Served |

</div>

---

## Contributing

Issues, PRs, and feature ideas are welcome.

```mermaid
flowchart LR
    F["<b>1. Fork</b><br/>Fork the repo"] --> B["<b>2. Branch</b><br/>Create feature branch"] --> C["<b>3. Code</b><br/>Make your changes"] --> PR["<b>4. PR</b><br/>Submit pull request"]

    style F fill:#2D5A7B,stroke:#2D5A7B,color:#fff
    style B fill:#5B7A3A,stroke:#5B7A3A,color:#fff
    style C fill:#5B7A3A,stroke:#5B7A3A,color:#fff
    style PR fill:#C4785B,stroke:#C4785B,color:#fff
```

```bash
git clone https://github.com/dougdevitre/access-to.git
cd access-to
git checkout -b feature/your-idea
# make changes, then...
git push origin feature/your-idea
# open a pull request on GitHub
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines. For individual project contributions, see each child repo's own guidelines.

This project follows our [Code of Conduct](CODE_OF_CONDUCT.md).

---

## Site Architecture

<details>
<summary>Expand to see the hub site's internal architecture (for contributors)</summary>

```mermaid
graph TD
    subgraph Pages
        IDX[index.html<br/><i>Landing page</i>]
        J[justice.html]
        E[education.html]
        HO[housing.html]
        S[services.html]
        P[peace.html]
        SF[safety.html]
        ERR[404.html]
    end

    subgraph Assets
        CSS[styles.css<br/><i>Dark mode, responsive, print</i>]
        OG[og-image.png<br/><i>1200x630 social card</i>]
        MF[manifest.json<br/><i>PWA support</i>]
    end

    subgraph SEO
        SM[sitemap.xml]
        RB[robots.txt]
    end

    IDX --> J & E & HO & S & P & SF
    CSS -.-> IDX & J & E & HO & S & P & SF & ERR

    style IDX fill:#2D5A7B,stroke:#2D5A7B,color:#fff
    style J fill:#C4785B,stroke:#C4785B,color:#fff
    style E fill:#4A7C59,stroke:#4A7C59,color:#fff
    style HO fill:#2D7A9B,stroke:#2D7A9B,color:#fff
    style S fill:#6B5B8A,stroke:#6B5B8A,color:#fff
    style P fill:#7A6F5B,stroke:#7A6F5B,color:#fff
    style SF fill:#B85C38,stroke:#B85C38,color:#fff
    style ERR fill:#888,stroke:#888,color:#fff
    style CSS fill:#333,stroke:#333,color:#fff
    style OG fill:#333,stroke:#333,color:#fff
    style MF fill:#333,stroke:#333,color:#fff
    style SM fill:#333,stroke:#333,color:#fff
    style RB fill:#333,stroke:#333,color:#fff
```

### Tech Stack

| Layer | Technology |
|:------|:-----------|
| **Markup** | Semantic HTML5 |
| **Styling** | Vanilla CSS (variables, Grid, Flexbox) |
| **Interactivity** | Vanilla JavaScript (no dependencies) |
| **Fonts** | [DM Serif Display](https://fonts.google.com/specimen/DM+Serif+Display) + [DM Sans](https://fonts.google.com/specimen/DM+Sans) |
| **Badges** | [Shields.io](https://shields.io) |
| **Hosting** | [GitHub Pages](https://pages.github.com) |
| **SEO** | OpenGraph, Twitter Cards, JSON-LD, XML sitemap |

### Features

<table>
<tr>
<td>

**Dark Mode** — system preference detection + manual toggle with localStorage persistence

</td>
<td>

**Responsive** — mobile-first with breakpoints at 500px, 600px, and 700px

</td>
</tr>
<tr>
<td>

**Accessible** — skip-to-content, ARIA labels, keyboard nav, reduced motion support

</td>
<td>

**Fast** — zero JS dependencies, font preloading, lazy-loaded images

</td>
</tr>
<tr>
<td>

**Print-Ready** — dedicated print styles for all pages

</td>
<td>

**PWA-Ready** — web app manifest for installable experience

</td>
</tr>
</table>

</details>

---

## Support

<div align="center">

**These tools are free and open source. Building them isn't.**

[![Donate Any Amount](https://img.shields.io/badge/Donate_Any_Amount-Stripe-635BFF?style=for-the-badge&logo=stripe&logoColor=white)](https://buy.stripe.com/14AcN5gBJ6rRfm07Kz2cg0c)
[![Fund via Venmo](https://img.shields.io/badge/Venmo-008CFF?style=for-the-badge&logo=venmo&logoColor=white)](https://venmo.com/dougdevitre)

</div>

Your support funds infrastructure, development, and keeping core tools free for families and advocates.

### How funds are used

| Area | What it covers |
|:-----|:---------------|
| **Infrastructure** | Hosting, CI/CD, domains, and services |
| **Development** | New features, security patches, platform stability |
| **Access** | Keeping core tools free for families and advocates |
| **Open Source** | Maintaining the Access To civic tech initiative |

### Sponsor tiers

| Tier | Amount | What you get | |
|:-----|:-------|:-------------|:--|
| **Seed** | $49 | Name in [`SPONSORS.md`](./SPONSORS.md) | [**Sponsor**](https://buy.stripe.com/7sYbJ1719eYngq4d4T2cg03) |
| **Sprout** | $99 | Seed + quarterly project update | [**Sponsor**](https://buy.stripe.com/28EeVdgBJ17x7Ty4yn2cg05) |
| **Supporter** | $149 | Sprout + logo in README | [**Sponsor**](https://buy.stripe.com/bJe5kDbhp3fF2zed4T2cg04) |
| **Advocate** | $250 | Supporter + logo on docs site | [**Sponsor**](https://buy.stripe.com/00wbJ1719cQf7Ty2qf2cg06) |
| **Champion** | $500 | Advocate + early feature access | [**Sponsor**](https://buy.stripe.com/fZu9AT4T1g2rddS7Kz2cg07) |
| **Builder** | $750 | Champion + advisory input | [**Sponsor**](https://buy.stripe.com/28EdR94T19E36Pu9SH2cg08) |
| **Partner** | $1,000 | Builder + dedicated support channel | [**Sponsor**](https://buy.stripe.com/14AeVdfxF8zZfm03uj2cg09) |
| **Sustainer** | $2,500 | Partner + co-branded case study | [**Sponsor**](https://buy.stripe.com/fZu28radleYn3Difd12cg0a) |
| **Visionary** | $5,000 | Sustainer + founding sponsor recognition | [**Sponsor**](https://buy.stripe.com/4gM00jetBeYnddS6Gv2cg0b) |

<div align="center">

*Want to sponsor via invoice, grant, or partnership? Contact [dougdevitre@gmail.com](mailto:dougdevitre@gmail.com).*

See our [current sponsors](./SPONSORS.md).

</div>

---

## Contact

<div align="center">

**Doug Devitre** — product builder, speaker, and founder of [CoTrackPro](https://cotrackpro.com)

Based in the St. Louis metro area. Focused on family law technology, workforce development, and civic access tools for Missouri and beyond.

[![LinkedIn](https://img.shields.io/badge/LinkedIn-0A66C2?style=for-the-badge&logo=linkedin&logoColor=white)](https://linkedin.com/in/dougdevitre)
[![GitHub](https://img.shields.io/badge/GitHub-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/dougdevitre)
[![Email](https://img.shields.io/badge/Email-EA4335?style=for-the-badge&logo=gmail&logoColor=white)](mailto:dougdevitre@gmail.com)

</div>

---

## Built With

<div align="center">

[![Claude](https://img.shields.io/badge/Powered_by-Claude_by_Anthropic-191919?style=for-the-badge&logo=anthropic&logoColor=white)](https://claude.ai)
[![GitHub Pages](https://img.shields.io/badge/Hosted_on-GitHub_Pages-222?style=for-the-badge&logo=github&logoColor=white)](https://pages.github.com)

Every Access To project runs as a [Claude Skill](https://claude.ai) — structured AI prompts that turn Claude into a domain-specific assistant. No API keys, no backends, no infrastructure to maintain.

</div>

---

<div align="center">

Open source under [MIT](https://opensource.org/licenses/MIT) unless otherwise noted in individual project repositories.

&copy; 2026 Doug Devitre

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://capsule-render.vercel.app/api?type=waving&color=0:1A1A1A,50:2D5A7B,100:5B7A3A&height=100&section=footer">
  <img src="https://capsule-render.vercel.app/api?type=waving&color=0:FAFAF7,50:2D5A7B,100:5B7A3A&height=100&section=footer" width="100%" alt="">
</picture>

</div>
