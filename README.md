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

## How the Pieces Connect

Each repository is independent but shares a common architecture. The hub site links users to the right tool, and each tool follows the same Claude Skill pattern.

```mermaid
flowchart LR
    subgraph USER ["User Journey"]
        direction LR
        U1["Visit dougdevitre.org"] --> U2["Choose a pillar"] --> U3["Clone the repo"] --> U4["Upload SKILL.md<br/>to Claude Project"] --> U5["Start a conversation"]
    end

    subgraph REPOS ["Repository Ecosystem"]
        direction TB
        R1["access-to-health"]
        R2["access-to-education"]
        R3["access-to-safety"]
        R4["access-to-housing"]
        R5["access-to-services"]
        R6["access-to-jobs"]
        R7["mo-start"]
    end

    U2 --> REPOS

    style U1 fill:#2D5A7B,stroke:#2D5A7B,color:#fff
    style U2 fill:#2D5A7B,stroke:#2D5A7B,color:#fff
    style U3 fill:#5B7A3A,stroke:#5B7A3A,color:#fff
    style U4 fill:#5B7A3A,stroke:#5B7A3A,color:#fff
    style U5 fill:#C4785B,stroke:#C4785B,color:#fff
    style R1 fill:#D4585B,stroke:#D4585B,color:#fff
    style R2 fill:#4A7C59,stroke:#4A7C59,color:#fff
    style R3 fill:#B85C38,stroke:#B85C38,color:#fff
    style R4 fill:#2D7A9B,stroke:#2D7A9B,color:#fff
    style R5 fill:#6B5B8A,stroke:#6B5B8A,color:#fff
    style R6 fill:#7A6F5B,stroke:#7A6F5B,color:#fff
    style R7 fill:#C4785B,stroke:#C4785B,color:#fff
```

---

## The Six Pillars

```mermaid
mindmap
  root((Access To))
    Health
      access-to-health
      Healthcare navigation
      Benefits enrollment
      Medicaid & Medicare
    Education
      access-to-education
      K-12 Standards
      Lesson Planning
      Teacher Growth
    Safety
      access-to-safety
      Risk Assessment
      Crisis Resources
      Protection Orders
    Housing
      access-to-housing
      PropTech
      Market Analysis
      Fair Housing
    Services
      access-to-services
      Social Services
      Benefits Matching
      Community Resources
    Jobs & Startups
      access-to-jobs
      WIOA Navigation
      Workforce Dev
      mo-start
      Entrepreneur Support
```

<table>
<tr>
<td align="center" width="16%">
<img src="https://img.shields.io/badge/-%E2%9D%A4%EF%B8%8F-D4585B?style=for-the-badge&logoColor=white" alt="Health"><br>
<strong>Health</strong><br>
<sub>Healthcare navigation,<br>benefits, Medicaid</sub><br><br>
<a href="https://github.com/dougdevitre/access-to-health"><img src="https://img.shields.io/badge/access--to--health-222?style=flat-square&logo=github" alt="access-to-health"></a>
</td>
<td align="center" width="16%">
<img src="https://img.shields.io/badge/-%F0%9F%93%9A-4A7C59?style=for-the-badge&logoColor=white" alt="Education"><br>
<strong>Education</strong><br>
<sub>K-12 standards, lesson<br>planning, teacher growth</sub><br><br>
<a href="https://github.com/dougdevitre/access-to-education"><img src="https://img.shields.io/badge/access--to--education-222?style=flat-square&logo=github" alt="access-to-education"></a>
</td>
<td align="center" width="16%">
<img src="https://img.shields.io/badge/-%F0%9F%9B%A1%EF%B8%8F-B85C38?style=for-the-badge&logoColor=white" alt="Safety"><br>
<strong>Safety</strong><br>
<sub>Safety planning, risk<br>assessment, crisis resources</sub><br><br>
<a href="https://github.com/dougdevitre/access-to-safety"><img src="https://img.shields.io/badge/access--to--safety-222?style=flat-square&logo=github" alt="access-to-safety"></a>
</td>
<td align="center" width="16%">
<img src="https://img.shields.io/badge/-%F0%9F%8F%A0-2D7A9B?style=for-the-badge&logoColor=white" alt="Housing"><br>
<strong>Housing</strong><br>
<sub>PropTech intelligence,<br>Fair Housing-safe</sub><br><br>
<a href="https://github.com/dougdevitre/access-to-housing"><img src="https://img.shields.io/badge/access--to--housing-222?style=flat-square&logo=github" alt="access-to-housing"></a>
</td>
<td align="center" width="16%">
<img src="https://img.shields.io/badge/-%E2%9A%99%EF%B8%8F-6B5B8A?style=for-the-badge&logoColor=white" alt="Services"><br>
<strong>Services</strong><br>
<sub>Social services,<br>benefits matching</sub><br><br>
<a href="https://github.com/dougdevitre/access-to-services"><img src="https://img.shields.io/badge/access--to--services-222?style=flat-square&logo=github" alt="access-to-services"></a>
</td>
<td align="center" width="16%">
<img src="https://img.shields.io/badge/-%F0%9F%92%BC-7A6F5B?style=for-the-badge&logoColor=white" alt="Jobs"><br>
<strong>Jobs</strong><br>
<sub>Workforce dev, WIOA,<br>job matching</sub><br><br>
<a href="https://github.com/dougdevitre/access-to-jobs"><img src="https://img.shields.io/badge/access--to--jobs-222?style=flat-square&logo=github" alt="access-to-jobs"></a><br>
<a href="https://github.com/dougdevitre/mo-start"><img src="https://img.shields.io/badge/mo--start-222?style=flat-square&logo=github" alt="mo-start"></a>
</td>
</tr>
</table>

---

## Project Directory

| Repository | Pillar | Scope | Description | Type |
|:-----------|:-------|:------|:------------|:-----|
| [access-to-health](https://github.com/dougdevitre/access-to-health) | Health | Nationwide | Healthcare navigation, benefits enrollment, Medicaid/Medicare guidance | Claude Skill |
| [access-to-education](https://github.com/dougdevitre/access-to-education) | Education | Missouri K-12 | Standards alignment, lesson planning, teacher growth tools | Claude Skill |
| [access-to-safety](https://github.com/dougdevitre/access-to-safety) | Safety | Nationwide | Safety planning, risk assessment, crisis resources, protection orders | Claude Skill |
| [access-to-housing](https://github.com/dougdevitre/access-to-housing) | Housing | Nationwide | PropTech intelligence, market analysis, Fair Housing compliance | Claude Skill |
| [access-to-services](https://github.com/dougdevitre/access-to-services) | Services | Nationwide | Social services navigation, benefits matching, community resources | Claude Skill |
| [access-to-jobs](https://github.com/dougdevitre/access-to-jobs) | Jobs | Missouri | Workforce development, WIOA navigation, job matching across 114 counties | Claude Skill |
| [mo-start](https://github.com/dougdevitre/mo-start) | Jobs | Missouri | Startup guide, entrepreneur support, business launch tools | Claude Skill |

---

## Data Flow Architecture

Each child project follows the same pattern: a `SKILL.md` file teaches Claude a specialized workflow. The hub site serves as the discovery layer.

```mermaid
flowchart TB
    subgraph HUB ["access-to (Hub Site)"]
        direction LR
        LP["Landing Page<br/><i>index.html</i>"]
        PP["Pillar Pages<br/><i>health, education, safety,<br/>housing, services, jobs</i>"]
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
    style SERVICES fill:#6B5B8A,stroke:#6B5B8A,color:#fff
    style JOBS fill:#7A6F5B,stroke:#1A1A1A,color:#fff
    style MOSTART fill:#C4785B,stroke:#1A1A1A,color:#fff
```

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

---

## Site Architecture

```mermaid
graph TD
    subgraph Pages
        IDX[index.html<br/><i>Landing page</i>]
        H[health.html]
        E[education.html]
        SF[safety.html]
        HO[housing.html]
        S[services.html]
        J[jobs.html]
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

    IDX --> H & E & SF & HO & S & J
    CSS -.-> IDX & H & E & SF & HO & S & J & ERR

    style IDX fill:#2D5A7B,stroke:#2D5A7B,color:#fff
    style H fill:#D4585B,stroke:#D4585B,color:#fff
    style E fill:#4A7C59,stroke:#4A7C59,color:#fff
    style SF fill:#B85C38,stroke:#B85C38,color:#fff
    style HO fill:#2D7A9B,stroke:#2D7A9B,color:#fff
    style S fill:#6B5B8A,stroke:#6B5B8A,color:#fff
    style J fill:#7A6F5B,stroke:#7A6F5B,color:#fff
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

For individual project contributions, see each project repo's own guidelines.

---

## Support

<div align="center">

**These tools are free. Building them isn't.**

[![Fund the Mission](https://img.shields.io/badge/Fund_the_Mission-Venmo-008CFF?style=for-the-badge&logo=venmo&logoColor=white)](https://venmo.com/dougdevitre)

100% goes to development. No overhead. Receipt on request.

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

<div align="center">

Open source under [MIT](https://opensource.org/licenses/MIT) unless otherwise noted in individual project repositories.

&copy; 2026 Doug Devitre

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://capsule-render.vercel.app/api?type=waving&color=0:1A1A1A,50:2D5A7B,100:5B7A3A&height=100&section=footer">
  <img src="https://capsule-render.vercel.app/api?type=waving&color=0:FAFAF7,50:2D5A7B,100:5B7A3A&height=100&section=footer" width="100%" alt="">
</picture>

</div>
