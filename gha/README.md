# Example GitHub Actions Databricks Deployment

## This folder contains a simple but production grade GitHub Actions workflow for Databricks Asset Bundles that:

*	Installs the latest Databricks CLI (via the official `databricks/setup-cli` action).
*	Authenticates securely with Databricks using [GitHub OIDC workload identity federation](https://docs.databricks.com/aws/en/dev-tools/auth/provider-github) (no long lived secrets).
*	On PRs to any branch except `main`, validates, plans, and deploys the bundle to the target that matches the PR’s base branch (e.g. PR → dev branch → deploy to dev target).
*	On push (merge) to `main`, validates, plans, and deploys to prod.
*	Fails the workflow if validation or deployment fails.

Why OIDC (a.k.a. “token federation”) instead of PATs or M2M client secrets? It’s the current best practice for CI on Databricks: short lived tokens, least privilege, no secrets to rotate, and policy scoping by repo/branch/environment. Databricks documents the GitHub OIDC flow and the exact env vars (DATABRICKS_AUTH_TYPE=github-oidc, DATABRICKS_CLIENT_ID, DATABRICKS_HOST) and the need for `id-token`: write permissions in your job.  ￼

## What each section does (and why)

*	`on.pull_request` with `branches-ignore`: ['main']: runs for PRs not targeting main. We’ll still run full deploys to dev/staging so reviewers can see real resources. ([GitHub’s event filters are documented here](https://docs.github.com/actions/using-workflows/workflow-syntax-for-github-actions).  ￼)
*	`on.push` to `main`: fires after the merge actually lands on `main` (the moment you usually want to deploy to prod).
*	`permissions`: we request only what’s necessary: `id-token`: write (OIDC) and `contents`: read. Databricks’ OIDC for GitHub requires the `id-token` permission.  ￼
*	`prepare` job: centralizes the branch→target mapping and whether the PR is from a fork. It sets:
*	`env_name`: GitHub Environment we’ll bind to (dev/staging/prod).
*	`bundle_target`: the Databricks bundle target (same string as in your databricks.yml).
*	`is_fork`: to avoid deploying code from forks (safe default).
*	deploy job:
*	`environment`: `${{ needs.prepare.outputs.env_name }}` is important for two reasons:
	1.	It selects the `Environment` scoped variables/approvals in GitHub (so you can require reviewers for prod), and
	2.	If you configure your Databricks [federation policy](https://docs.databricks.com/aws/en/dev-tools/auth/env-vars) with subject type = `Environment`, the issued OIDC token’s subject will reflect `environment`:prod (tight scoping recommended by Databricks).  ￼
*	`env` sets Databricks auth for the CLI via unified authentication: `DATABRICKS_AUTH_TYPE`=`github-oidc`, `DATABRICKS_CLIENT_ID`, and `DATABRICKS_HOST` (or you can read host from the bundle target).  ￼
*	`databricks/setup-cli@main` installs the latest CLI (that action is the [Databricks maintained installer](https://github.com/databricks/setup-cli)). If you prefer pinning versions for reproducibility, replace @main with a released tag (e.g. `@v0.272.0`).  ￼
*	`bundle validate` checks config syntax and identity; the [CLI exits non zero on errors](https://docs.databricks.com/aws/en/dev-tools/cli/bundle-commands) so the job fails fast. (By design, validation may print warnings for unknown properties; warnings don’t fail the job on their own.)  ￼
*	`bundle plan` prints a no‑side‑effects diff of actions that would be taken; super useful in PR logs.  ￼
*	`bundle deploy --auto-approve --fail-on-active-runs` does the non‑interactive deploy and fails if jobs/pipelines are currently running in that target (guardrail to avoid mid‑run mutations).  ￼
*	`skip_forks` job: for external forks, we skip deployment (GitHub doesn’t pass OIDC/secrets to forked PRs by default). You can swap this for a “validate‑only” job if you want purely offline checks.

## First time setup you must do

1.	Create/enable a Databricks Service Principal and grant it permissions in each target workspace (e.g. job/pipeline create/update, catalog/schema rights as applicable).
2.	Enable OIDC (workload identity federation) for GitHub in your Databricks account:
	*	Create a federation policy that restricts issuer to https://token.actions.githubusercontent.com and scopes subject to your repo/organd (optionally) Environment (recommended). Databricks provides CLI examples for creating the policy.  ￼
	*	This makes it possible for your workflow to exchange GitHub’s OIDC token for a Databricks OAuth token without any stored secrets.  ￼
3.	In GitHub, define:
	*	Repository variable `DATABRICKS_SP_CLIENT_ID` = your Databricks service principal’s application/client ID (non‑secret).  ￼
	*	Environment variables (under Settings → Environments):
		*	Environment dev: `DATABRICKS_HOST`=https://dbc-dev-123.cloud.databricks.com
		*	Environment staging: `DATABRICKS_HOST`=https://dbc-stg-123.cloud.databricks.com
		*	Environment prod: `DATABRICKS_HOST`=https://dbc-prod-123.cloud.databricks.com
		*	(Optional) Set required reviewers or wait timers on the prod environment for an extra approval gate before the deploy job runs.

> If you cannot use OIDC yet, fall back to OAuth M2M: set DATABRICKS_AUTH_TYPE=oauth-m2m, provide DATABRICKS_CLIENT_ID (variable) and DATABRICKS_CLIENT_SECRET (as a secret), and keep DATABRICKS_HOST. This is supported by the CLI’s unified auth model, but favor OIDC when possible.

## How the branch → target mapping works

*	PR to dev branch → prepare sets `env_name`=dev, `bundle_target`=dev → job runs in the dev GitHub Environment (so it can pick up `DATABRICKS_HOST` for dev), then validates/plans/deploys to dev.
*   PR to staging → same logic for staging.
*  	Merge to `main` (push to `main`) → `env_name`=prod, `bundle_target`=prod → deploy to prod.

It computes the PR base branch with `github.event.pull_request.base.ref` ([that’s the canonical way to discover the PR target branch in Actions](https://stackoverflow.com/questions/62331829/how-to-get-the-target-branch-of-the-github-pull-request-from-an-actions)).

## Why these choices (methodology)

*	*CLI install*: It uses the official `databricks/setup-cli` GitHub Action and `@main` to always grab the latest. Pin to a tag if you want reproducibility.  ￼
*	*Auth*: OIDC federation (`github-oidc`) is documented and recommended by Databricks for GitHub Actions; it requires only `DATABRICKS_CLIENT_ID` and `DATABRICKS_HOST` plus `id-token`: write. No PATs or client secrets in CI.  ￼
*	Validate → Plan → Deploy:
	*	`validate` ensures the bundle files are syntactically correct and the bundle identity resolves. It fails the job on hard errors(warnings remain warnings).  ￼
	*	`plan` produces a diff so reviewers can see intended changes in the job logs before anything mutates.  ￼
*	deploy with `--auto-approve` makes the step non‑interactive; `--fail-on-active-runs` prevents updating a running job/pipeline.  ￼
*	Environments + Concurrency:
	*	Binding to GitHub Environments unlocks approvals for prod and produces more constrained OIDC subjects (recommended by Databricks).  ￼
	*	A per environment concurrency group prevents overlapping prod deploys.
*	*Fork safety*: It skip deploys for forked PRs. If you ever want to allow “validate‑only” for forks, you can, but OIDC and secrets don’t flow to forks by default, so keep deploys on internal branches. (This is a general Actions security best practice.)

## Optional but valuable add-ons

*	Block destructive plans: uncomment the `jq` step to fail if a plan contains a destroy op (plan supports `--output` json).  ￼
*	Branch guards in bundle: add `git.branch`: main under `targets.prod` to make the CLI itself refuse prod deploys from non‑main branches (can be overridden with `--force`).  ￼
*	Resource binding for prod: if you have existing prod resources, use `databricks bundle deployment bind` once so future deploys manage them (no data loss).  ￼
*	Paths filters: scope triggers to relevant folders (e.g. paths: ['databricks.yml','resources/**','src/**']) to skip runs on doc only changes.
*	Artifacts / wheels: if your bundle builds Python wheels or similar, put that in artifacts and run unit tests before deploy. ([Databricks bundle settings support this pattern](https://learn.microsoft.com/en-us/azure/databricks/dev-tools/bundles/settings).)  ￼
*	Timeouts + retries: add `timeout-minutes`: on the job and consider a light retry wrapper on deploy for transient API hiccups.

## Quick FAQ

*Q*: Can I keep workspace hosts only in the GitHub Environments and not in `databricks.yml`?
Yes, `DATABRICKS_HOST` can come entirely from the Environment variable. The CLI’s unified auth takes host from env vars or from the bundle target; both are supported.  ￼

*Q*: What about [M2M](https://docs.databricks.com/aws/en/dev-tools/cli/authentication) (client ID + client secret)?
Supported and easy: set `DATABRICKS_AUTH_TYPE`=oauth-m2m, provide `DATABRICKS_CLIENT_ID` + `DATABRICKS_CLIENT_SECRET` (as a secret), and keep `DATABRICKS_HOST`. Prefer OIDC if possible.  ￼

*Q*: Does validate fail the workflow if the bundle is wrong?
Yes, hard errors return a non‑zero exit code and the job fails. It may also output warnings for unknown fields; warnings alone don’t fail the job.

## End‑to‑end architecture (at a glance)

1.	*Trigger*: PR to a non‑main branch → deploy to that branch’s target (dev/staging). Merge to main → [deploy to prod](https://docs.github.com/actions/using-workflows/workflow-syntax-for-github-actions).  ￼
2.	*Install CLI*: `databricks/setup-cli@main` ensures you’re on the latest Databricks CLI.  ￼
3.	*Auth*: GitHub OIDC → Databricks service principal via federation policy; env + environment control the token subject.  ￼
4.	*Guardrails*: validate → plan → deploy `--fail-on-active-runs`. Optional “no destroy” check + GitHub Environments approvals for prod.  ￼
