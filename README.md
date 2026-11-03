# Terraform team platform

Self-service AWS resources for product teams. Each team describes what it needs
in **one small file**. A shared Terraform module turns it into **one IAM role and
one or more S3 buckets**. A pull request plans the change; merging applies it.

## How a team onboards

1. Create `teams/<team-name>.tfvars`:

   ```hcl
   cost_center = "CC-3001"

   buckets = [
     { name = "receipts", visibility = "private" },
     { name = "assets", visibility = "public" },
   ]
   ```

2. Add `/teams/<team-name>.tfvars  @<your-github-team>` to `.github/CODEOWNERS`.
3. Open a pull request. CI tests the module and plans your team. Merge to apply.

No changes to platform code are needed. The file name is the team name.

## How it works

```
teams/payments.tfvars   the team's settings (data only)
        │
        ▼
live/main.tf            runs Terraform for one team, with that team's own state file
        │
        ▼
modules/team/           creates the buckets and IAM role, and enforces all rules
```

| Path | Owner | Purpose |
|---|---|---|
| `teams/*.tfvars` | each team | What the team needs |
| `modules/team/` | platform | Buckets, IAM role, naming, security rules, tests |
| `live/main.tf` | platform | Provider, state backend, calls the module |
| `.github/workflows/teams.yml` | platform | CI: test, detect changed teams, plan and apply |

## Design decisions

### Module design
- Teams write **data only** (a `.tfvars` file), never Terraform code, so they can't bypass the rules.
- **Naming** is built inside the module: `<prefix>-<team>-<bucket>`, e.g. `acme-payments-invoices`.
- **Visibility has no default.** It is a required field, so a bucket without it is rejected.
  A validation only accepts `public` or `private`.
- Buckets use **`for_each` keyed by name**, so removing one bucket never recreates the others.
  This keeps the module idempotent and safe to re-apply.
- The module has **no provider settings**. `live/` decides region and credentials.

### Scalability (1 to 300+ teams)
- Adding a team is adding one file. No platform code changes.
- CI only runs the teams whose file changed, one parallel job per team.
- If the module itself changes, CI runs every team.

### State isolation
- Every team has its **own state file** in S3: `teams/<team>.tfstate`.
  The key is passed at `terraform init` (backend blocks can't use variables).
- **S3 native locking** (`use_lockfile`) stops two runs changing the same team at once.
- Why not workspaces: a smaller blast radius, faster plans, and no hidden "selected workspace".

### Security
- The IAM role can **only reach its own team's buckets**. Other teams' buckets are
  denied by default, because they are never listed in its policy.
- The role can read and write **files**, but can't change **bucket settings**
  (policies, public access, deleting buckets). Those only change through this repo.
- **Private buckets** block every kind of public access.
- **Public buckets** still block ACLs. Their only public access is a module-written
  policy allowing anonymous **download (`s3:GetObject`) only**: no listing, no uploads.

### CI/CD
- PR = request + plan; review = approval; merge to `main` = apply. Only `main` applies.
- The pipeline finds changed teams with `git diff`: a changed `teams/<team>.tfvars`
  means that team; a changed `modules/` or `live/` means all teams.
- Runs for the same team are queued (`concurrency`); different teams run in parallel.
- **Terraform commands are mocked** (no AWS account). For real use, CI would log in to AWS
  with **GitHub OIDC**: short-lived credentials, no stored keys. A read-only role for PR
  plans, and a separate write role that only `main` can use.

### Testing
- `terraform test` with a **mocked AWS provider**: no AWS account, no credentials, runs on every PR.
- Tests check naming, private vs public handling, and that the role only reaches its own buckets.
- A **negative test** checks that a bad `visibility` is rejected, so a deleted rule fails CI.
- Verified by breaking the module on purpose (IAM `Resource = ["*"]`) and confirming the test fails.

### Tagging (bonus)
Every bucket and role is tagged with `team`, `cost_center` and `managed_by`.
Buckets also get `visibility`. Teams provide the values; the module decides the tag names,
so tags are consistent everywhere and finance can split the bill by team.

### Offboarding (bonus, described)
1. The team deletes its `.tfvars` file in a PR, reviewed by the platform team.
2. On merge, CI runs `terraform destroy` for that team, restoring the file from the
   previous commit so Terraform knows what to remove, then deletes its state file.
3. Buckets that still contain files make the destroy **fail on purpose**.
   Deleting company data should be a deliberate, reviewed step, never a side effect.

## Run the tests locally

```bash
cd modules/team
terraform init -backend=false
terraform test
```

## What I would add for production
- Trust each team's own login role (e.g. SSO) instead of the whole account.
- A security review requirement for new public buckets (ruleset or CI policy check).
- Serve public files through CloudFront and keep account-level public access blocked.
- Per-team KMS encryption keys, and versioning, for compliance (PCI DSS).
- Pin the module by git tag and roll out changes to teams in waves.
- A nightly plan of all teams to detect manual changes (drift).