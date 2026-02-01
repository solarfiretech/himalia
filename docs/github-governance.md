# GitHub Governance (Branch Protection + Environments)

This document describes the recommended GitHub settings for Himalia:
- Branch protection rules for `main` and `beta`
- Environment-based approvals to control GHCR publishing workflows

> Branch protection and environment approvals are configured in GitHub UI (or API), not via repo files.
> The workflows in `.github/workflows/` reference environments named `beta` and `production`.
> Create these environments in **Repo → Settings → Environments** and add required reviewers.

---

## 1) Branch protection rules

Configure in: **Repo → Settings → Branches → Branch protection rules**

### 1.1 Protect `main`
Recommended:
- Require a pull request before merging
  - Require approvals: 1–2
  - Dismiss stale approvals when new commits are pushed
- Require status checks to pass before merging
  - `ci / test`
  - `ci / docker-build`
  - (optional) `ci / integration`
- Require conversation resolution before merging
- Restrict who can push (optional but recommended)
- Include administrators (recommended once stable)

### 1.2 Protect `beta`
Recommended:
- Same as `main`, plus:
- Restrict who can push to `beta` (strongly recommended)

### 1.3 `develop`
Recommended:
- Allow direct pushes if preferred, but keep CI required for PRs into `beta`/`main`.

---

## 2) Environments (approval gates)

Configure in: **Repo → Settings → Environments**

Create:
- `beta`
- `production`

### 2.1 `beta`
- Required reviewers: you (or maintainers)
- Optional wait timer

### 2.2 `production`
- Required reviewers: you (and optionally a second approver)
- Deployment branches: only `main` and/or tags

---

## 3) Workflow mapping

- `publish-beta-image.yml` → environment: `beta`
- `publish-release-image.yml` → environment: `production`

This forces an approval pause before publishing images.

---

## 4) Suggested flow

1. Develop on `develop` (CI runs).
2. PR `develop → beta`, review, merge.
3. Run **Actions → publish-beta-image → Run workflow**, approve `beta`.
4. PR `beta → main`, create Release `vX.Y.Z`, approve `production`.
