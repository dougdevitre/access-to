# GitHub Sponsor Setup — Instructions

## What's in this package

```
.github/FUNDING.yml    → Adds ❤️ Sponsor button to repo(s)
SPONSORS.md            → Recognition file for contributors
SPONSOR-SECTION.md     → Copy/paste block for your README.md
```

---

## Step 1: Org-level Sponsor button (all repos)

Create a `.github` repo under the `cotrackpro` org if it doesn't exist:

```bash
# On github.com:
# Go to https://github.com/organizations/cotrackpro/repositories/new
# Create a repo named exactly: .github
# Set it to Public
```

Then push the FUNDING.yml:

```bash
git clone https://github.com/cotrackpro/.github.git
cp .github/FUNDING.yml .github/FUNDING.yml
cd .github
git add FUNDING.yml
git commit -m "Add org-level sponsor button with Stripe donation link"
git push
```

**Result:** Every repo under `cotrackpro` now shows the ❤️ Sponsor button linking to your Stripe donation page.

---

## Step 2: Add SPONSORS.md to key repos

Copy `SPONSORS.md` into the root of your main repos:

```bash
# For each repo (cotrackpro, access-to-safety, access-to-education, etc.)
cp SPONSORS.md /path/to/repo/SPONSORS.md
cd /path/to/repo
git add SPONSORS.md
git commit -m "Add SPONSORS.md recognition file"
git push
```

---

## Step 3: Add sponsor section to README

Open `SPONSOR-SECTION.md` and copy everything below the HTML comment into your repo's `README.md`.

**Recommended placement:** At the bottom of the README, just above any license section.

---

## Where users see the sponsor request

| Surface | What they see | Visibility |
|---------|--------------|------------|
| **Repo header** | ❤️ Sponsor button (from FUNDING.yml) | Every repo visitor |
| **README.md** | Full tier table + donate badge | Anyone who scrolls the README |
| **SPONSORS.md** | Recognition list | Linked from README |
| **GitHub org profile** | If you add a sponsor link to org README | Org page visitors |

---

## Optional: Add to org profile README

If you have a profile README at `cotrackpro/.github/profile/README.md`, add a short sponsor callout there too:

```markdown
### 💛 Support Our Work

CoTrackPro is open-source and community-funded.
[![Sponsor](https://img.shields.io/badge/Sponsor-CoTrackPro-blue?style=flat-square&logo=stripe)](https://buy.stripe.com/14AcN5gBJ6rRfm07Kz2cg0c)
```
