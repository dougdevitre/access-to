# Access To — Admin System Architecture

This document describes how the Access To ecosystem is organized, automated, and monitored from the hub repository.

## System Overview

```mermaid
graph TB
  subgraph Hub["access-to (Hub Repo)"]
    Config["config/"]
    Scripts["scripts/"]
    Workflows["workflows/"]
    Schemas["schemas/"]
    Templates["ISSUE_TEMPLATE/"]
  end

  subgraph Children["Child Repos"]
    Housing["access-to-housing"]
    Jobs["access-to-jobs"]
    Health["access-to-health"]
    Business["access-to-business"]
    Services["access-to-services"]
    Education["access-to-education"]
    Safety["access-to-safety"]
  end

  subgraph GitHub["GitHub Platform"]
    Project["GitHub Project #1"]
    Actions["GitHub Actions"]
    Issues["Issues & PRs"]
  end

  Config -->|drives| Scripts
  Scripts -->|executed by| Workflows
  Schemas -->|validates| Config
  Workflows -->|sync labels| Children
  Workflows -->|sync templates| Children
  Workflows -->|add repos| Project
  Workflows -->|health check| Issues
  Children -->|call reusable workflow| Workflows
  Templates -->|synced to| Children
```

## Data Flow: Sync Lifecycle

Every sync operation follows the same pattern: config drives scripts, workflows orchestrate, and summaries report results.

```mermaid
sequenceDiagram
  participant Trigger as Trigger (Cron/Push/Manual)
  participant Workflow as GitHub Actions Workflow
  participant Script as Admin Script
  participant Config as Config Files
  participant GH as GitHub API
  participant Summary as Job Summary

  Trigger->>Workflow: Event fires
  Workflow->>Script: Execute with config path
  Script->>Config: Read repos.json / labels.json
  Config-->>Script: Parsed data

  loop For each repo
    Script->>GH: gh API call (with retry)
    GH-->>Script: Response / error
    Script->>Script: Log action (structured)
  end

  Script->>Summary: Write markdown summary
  Script->>Script: Exit code (0=pass, 1=fail)
  Script-->>Workflow: Return status
```

## Config Validation Pipeline

Config changes are validated before they can affect the ecosystem.

```mermaid
flowchart LR
  A[Edit config file] --> B[Push / Open PR]
  B --> C{validate-config.yml}
  C --> D[validate-config.sh]
  D --> E{repos.json checks}
  D --> F{labels.json checks}
  D --> G{Cross-file checks}
  E --> H[Required fields\nValid pillars\nValid scopes\nconnects_to refs exist\nNo duplicates\nExactly 1 hub]
  F --> I[Required fields\nHex color format\nNo duplicate names]
  G --> J[Every pillar has\nmatching label]
  H --> K{Errors?}
  I --> K
  J --> K
  K -->|Yes| L[Block merge]
  K -->|No| M[Allow merge]
```

## Repo Onboarding Flow

When a new repository joins the ecosystem:

```mermaid
flowchart TD
  A[Run onboard-repo.sh] --> B{Repo exists on GitHub?}
  B -->|No| C[Print create instructions\nExit 1]
  B -->|Yes| D[Sync shared labels]
  D --> E[Add to GitHub Project]
  E --> F[Create onboarding issue\nwith setup checklist]
  F --> G[Print manual next steps]
  G --> H[Manual: Add to repos.json]
  H --> I[Push triggers validate-config.yml]
  I --> J[Push triggers sync-labels.yml]
  J --> K[Repo fully integrated]

  style C fill:#f66,color:#fff
  style K fill:#6f6,color:#000
```

## Label Taxonomy

Labels follow a namespace convention for consistent triage across all repos:

```mermaid
graph LR
  subgraph Pillar
    P1["pillar:housing"]
    P2["pillar:jobs"]
    P3["pillar:health"]
    P4["pillar:education"]
    P5["pillar:services"]
    P6["pillar:safety"]
    P7["pillar:business"]
  end

  subgraph Type
    T1["type:bug"]
    T2["type:feature"]
    T3["type:docs"]
    T4["type:skill"]
    T5["type:infra"]
  end

  subgraph Priority
    PR1["priority:critical"]
    PR2["priority:high"]
    PR3["priority:medium"]
    PR4["priority:low"]
  end

  subgraph Status
    S1["status:triage"]
    S2["status:in-progress"]
    S3["status:blocked"]
    S4["status:ready"]
  end

  subgraph Special
    X1["cross-repo"]
    X2["good first issue"]
    X3["help wanted"]
  end
```

## Cross-Repo Connection Map

Pillar repos are independent but complementary. Connections represent shared user flows and data dependencies.

```mermaid
graph LR
  housing["Housing"]
  jobs["Jobs"]
  health["Health"]
  business["Business"]
  services["Services"]
  education["Education"]
  safety["Safety"]

  housing --- safety
  housing --- jobs
  housing --- services
  jobs --- education
  jobs --- services
  jobs --- housing
  health --- safety
  health --- services
  business --- jobs
  business --- services
  services --- jobs
  services --- health
  services --- housing
  education --- jobs
  education --- services
  safety --- health
  safety --- housing
  safety --- services
```

## File Structure

```mermaid
graph TD
  subgraph ".github/"
    subgraph config["config/"]
      R["repos.json\n(registry)"]
      L["labels.json\n(taxonomy)"]
    end

    subgraph schemas["schemas/"]
      RS["repos.schema.json"]
      LS["labels.schema.json"]
    end

    subgraph scripts["scripts/"]
      LIB["lib-log.sh\n(shared logging)"]
      SR["sync-repos.sh"]
      SL["sync-labels.sh"]
      ST["sync-templates.sh"]
      HC["health-check.sh"]
      OB["onboard-repo.sh"]
      VC["validate-config.sh"]
    end

    subgraph workflows["workflows/"]
      W1["sync-repos-to-project.yml\n(daily 9 AM)"]
      W2["sync-labels.yml\n(on config change)"]
      W3["sync-templates.yml\n(on template change)"]
      W4["health-check.yml\n(weekly Monday 8 AM)"]
      W5["validate-config.yml\n(on PR/push)"]
      W6["reusable-skill-check.yml\n(called by children)"]
    end

    subgraph templates["ISSUE_TEMPLATE/"]
      I1["bug_report.md"]
      I2["feature_request.md"]
      I3["new_pillar.md"]
      I4["cross_repo.md"]
    end
  end

  schemas -.->|validates| config
  config -->|drives| scripts
  scripts -->|executed by| workflows
  LIB -->|sourced by| VC
  templates -->|synced by| ST
```

## Workflow Schedule

| Workflow | Trigger | Schedule | What it does |
|:---------|:--------|:---------|:-------------|
| sync-repos-to-project | Cron / Manual | Daily 9 AM UTC | Adds repos to GitHub Project #1 |
| sync-labels | Push / Manual | On `labels.json` change | Pushes label taxonomy to all repos |
| sync-templates | Push / Manual | On template change | Pushes issue templates to child repos |
| health-check | Cron / Manual | Monday 8 AM UTC | Dashboard: issues, PRs, staleness, connections |
| validate-config | PR / Push / Manual | On config/schema change | Validates repos.json and labels.json |
| reusable-skill-check | Called by children | On child repo events | Validates SKILL.md structure |
| copilot-triage | Issue opened | On new issue | Auto-labels by pillar/type keywords |

## AI Tooling Integration

The ecosystem uses two AI systems — Claude for end users, and Copilot + Claude Code for developers.

```mermaid
flowchart TB
  subgraph Users["End Users"]
    U1["Practitioner / Advocate"]
  end

  subgraph Claude["Claude.ai"]
    CP["Claude Project"]
    SK["SKILL.md\n(knowledge file)"]
    CP --- SK
  end

  subgraph Developers["Developer Tooling"]
    CC["Claude Code\n(CLAUDE.md)"]
    GC["GitHub Copilot\n(copilot-instructions.md)"]
    DB["Dependabot\n(dependabot.yml)"]
  end

  subgraph Automation["CI / CD"]
    TR["copilot-triage.yml\n(auto-label issues)"]
    VC["validate-config.yml\n(schema checks)"]
    SC["reusable-skill-check.yml\n(SKILL.md validation)"]
  end

  subgraph Repo["Hub Repository"]
    SG["SKILL-GUIDE.md"]
    CF["Config + Schemas"]
  end

  U1 -->|uses| CP
  SK -->|uploaded from| Repo
  CC -->|reads| Repo
  GC -->|reads| Repo
  DB -->|updates| Repo
  TR -->|triages| Repo
  VC -->|validates| CF
  SC -->|validates| SK
  SG -->|guides creation of| SK
```

### How each AI tool contributes

```mermaid
graph LR
  subgraph "Claude.ai (End Users)"
    A1["SKILL.md → Domain expertise"]
    A2["Claude Projects → Persistent context"]
    A3["Guardrails → Safe, bounded answers"]
  end

  subgraph "Claude Code (Developers)"
    B1["CLAUDE.md → Repo conventions"]
    B2["Config awareness → repos.json, labels.json"]
    B3["Script standards → lib-log.sh, exit codes"]
  end

  subgraph "GitHub Copilot (IDE + PRs)"
    C1["copilot-instructions.md → Code style"]
    C2["PR review → Accessibility, dark mode"]
    C3["Autocomplete → Schema-aware suggestions"]
  end

  subgraph "Automated (CI)"
    D1["copilot-triage → Issue labeling"]
    D2["Dependabot → Actions version updates"]
    D3["validate-config → Schema enforcement"]
    D4["skill-check → SKILL.md quality gate"]
  end
```

## Logging Protocol

All scripts use `lib-log.sh` for structured logging:

```
# Text mode (default):
[2026-04-06T09:00:00Z] [INFO] sync-labels: Starting sync-labels (run: 20260406090000-12345)
[2026-04-06T09:00:01Z] [ACTION] sync-labels: sync-label pillar:housing -> success (created)
[2026-04-06T09:00:05Z] [SUMMARY] sync-labels: Done in 5s | actions=28 warnings=0 errors=0

# JSON mode (LOG_FORMAT=json):
{"ts":"2026-04-06T09:00:01Z","level":"info","script":"sync-labels","run":"20260406090000-12345","msg":"sync-label pillar:housing: success","action":"sync-label","target":"pillar:housing","status":"success"}
```

Set `AUDIT_LOG=/path/to/file.jsonl` to persist an append-only audit trail of all sync operations.
