# Azure Linux VM Terraform Template

This template creates an Azure resource group, virtual network, subnet, public IP, network security group, network interface, and Ubuntu 22.04 Linux VM.

## Prerequisites

- Terraform >= 1.5
- Azure CLI
- An SSH key pair

Authenticate with Azure CLI and select the subscription:

```powershell
az login
az account set --subscription <subscription-id>
```

Copy the example variables file and replace the placeholder SSH key and subscription ID:

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
```

State is stored in an Azure Blob Storage backend (partial config), so `init`
needs the backend details. Point these at an existing storage account (see
[Remote state backend](#remote-state-backend)):

```powershell
terraform init `
  -backend-config="resource_group_name=tfstate-rg" `
  -backend-config="storage_account_name=<uniquestorageacct>" `
  -backend-config="container_name=tfstate" `
  -backend-config="key=hub-gec.tfstate"
terraform plan
terraform apply
```

Connect using the `ssh_command` output:

```powershell
terraform output -raw ssh_command
```

Destroy the resources when finished:

```powershell
terraform destroy
```

For security, set `allowed_ssh_source` to your own public IP in CIDR format, such as `203.0.113.10/32`, instead of allowing SSH from everywhere.

Do not commit `terraform.tfvars` if it contains private values. It is ignored by the recommended `.gitignore` below if you add one to the project.

## CI/CD (GitHub Actions)

Two workflows in `.github/workflows/` run Terraform in CI:

| Workflow | Trigger | Behaviour |
| --- | --- | --- |
| `tf-plan-gec.yml` | Push to **any** branch | Runs `terraform plan`, publishes it to the run **Summary**, and saves the output as `plan-<sha>`. If the branch has an open PR, updates its sticky comment. |
| `tf-plan-gec.yml` | PR to `main` (opened/reopened) | **Reuses** the saved plan for the PR's head commit if the code is unchanged (no re-plan); otherwise plans fresh. Posts a sticky PR comment. |
| `tf-plan-gec.yml` | Push to `main`, or manual | Runs `terraform plan`, saves the `tfplan` artifact, and opens an approval **issue**. |
| `tf-apply-run-gec.yml` | Comment on the approval issue | On an authorized `/approve` comment, applies the saved plan and closes the issue. `/deny` closes it without applying. |

### Plan reuse (avoid duplicate planning)

The plan workflow identifies "same code" by **commit SHA**:

- Every branch push saves its plan output as an artifact named `plan-<sha>`.
- When a PR is opened for that same commit, a lightweight `check` job finds the
  saved `plan-<sha>` and a `reuse` job posts it as the PR comment — **no second
  `terraform plan`**. If no saved plan is found (e.g. the artifact expired), it
  falls back to planning fresh.
- `synchronize` is intentionally not a PR trigger: pushing to a PR branch is
  handled by the push run (which also updates the PR comment), so the same code
  is never planned twice.

Reused plans are **previews** — a saved plan reflects the Azure state at push
time. The plan that actually gets applied is always regenerated fresh at merge to
`main` (and saved as `tfplan`), so the apply is never based on a reused preview.

Plan runs are scoped with a `paths` filter (only `*.tf` / `.terraform.lock.hcl`
changes) and cache the provider plugins, so non-Terraform commits don't trigger
runs and each run skips re-downloading providers.

### Issue-based approval (ChatOps)

Deployment is gated by an issue-based approval that uses only first-party
actions (works under org policies that block third-party actions):

1. **On a PR to `main`**, the plan runs and is posted as a comment on the PR so
   you can review before merging. No approval issue is created yet.
2. **When code lands on `main`** (a merge/push, or a manual run of the plan
   workflow), the plan runs and opens an issue (labelled `tf-apply-approval`)
   containing the plan.
3. An authorized reviewer reads the plan and comments **`/approve`** on that
   issue. That fires **Terraform Apply (GEC) — Apply on Approval**, which applies
   and closes the issue. Commenting **`/deny`** closes it without applying.

Only users with write access (issue-comment `author_association` of `OWNER`,
`MEMBER`, or `COLLABORATOR`) can approve; comments from anyone else are ignored.

> The apply applies the **exact plan** you reviewed: the plan run uploads the
> `tfplan` as an artifact, records its run id in the issue, and the apply
> downloads that artifact and runs `terraform apply tfplan`. If the state drifted
> since the plan was created, Terraform rejects the stale plan (safe by design) —
> re-run the plan to produce a fresh approval issue.
>
> The approval issue is created from `main` so the reviewed plan and the applied
> state stay aligned (`issue_comment`-triggered runs always use `main`).

### Required secrets

Settings → Secrets and variables → Actions → **Secrets**:

| Secret | Purpose |
| --- | --- |
| `ARM_CLIENT_ID` | Service principal app ID |
| `ARM_CLIENT_SECRET` | Service principal secret |
| `ARM_TENANT_ID` | Azure AD tenant ID |
| `ARM_SUBSCRIPTION_ID` | Target subscription ID |
| `ADMIN_SSH_PUBLIC_KEY` | Contents of your SSH public key (passed as `TF_VAR_admin_ssh_public_key`) |
| `ADMIN_PASSWORD` | Linux admin password, 6-72 chars with 3 of {lower, upper, digit, special} (passed as `TF_VAR_admin_password`) |

### Required variables

Same page → **Variables** tab (these are not sensitive):

| Variable | Purpose |
| --- | --- |
| `TFSTATE_RESOURCE_GROUP` | Resource group holding the state storage account |
| `TFSTATE_STORAGE_ACCOUNT` | Storage account name for remote state |
| `TFSTATE_CONTAINER` | Blob container name for remote state |

## Remote state backend

State is stored in Azure Blob Storage via the `azurerm` backend. The backend
uses partial configuration — details are supplied at `init` time (by the
workflows, or the flags shown above for local use). The storage account must
exist **before** the first run; Terraform cannot bootstrap its own backend:

```bash
az group create -n tfstate-rg -l eastus
az storage account create -n <uniquestorageacct> -g tfstate-rg --sku Standard_LRS
az storage container create -n tfstate --account-name <uniquestorageacct>
```

Grant the service principal **Storage Blob Data Contributor** on that storage
account so it can read and write state.
