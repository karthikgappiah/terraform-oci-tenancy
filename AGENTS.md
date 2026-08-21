# AGENTS.md

This file provides guidance to AI agents when working with code in this repository.

## What this is

A single root Terraform configuration (no modules, no workspaces, local state) that
manages the whole of one OCI tenancy: a compartment, a VCN built to match the OCI
"VCN with Internet Connectivity" wizard, and one compute instance sized to consume
exactly the entire Always Free allowance. See [README.md](README.md) for the topology
tables and the Always Free arithmetic.

## Commands

```bash
terraform init
terraform plan
terraform apply
terraform fmt -recursive   # before committing
terraform validate         # before committing
```

There are no tests. `terraform validate` and a clean `terraform plan` are the check.
Credentials come from [terraform.tfvars](terraform.tfvars) (gitignored; copy from
[terraform.tfvars.example](terraform.tfvars.example)).

## Architecture

File layout follows the `terraform-style-guide` skill (see below):
[terraform.tf](terraform.tf) versions, [providers.tf](providers.tf) provider,
[main.tf](main.tf) tenancy data source + compartment, [network.tf](network.tf),
[compute.tf](compute.tf), [locals.tf](locals.tf), [variables.tf](variables.tf) and
[outputs.tf](outputs.tf) both alphabetized.

Everything hangs off `oci_identity_compartment.free` in [main.tf](main.tf) — new
resources belong in that compartment, not in the tenancy root.

Network specifics that are easy to get wrong:

- The public subnet deliberately uses the VCN's **default** route table and **default**
  security list, adopted via `oci_core_default_route_table` /
  `oci_core_default_security_list` with `manage_default_resource_id`. That mirrors what
  the wizard does. The private subnet gets its own dedicated pair.
- Subnets are regional (no `availability_domain` argument).
- Security list rules that scope to the VCN iterate `var.vcn_cidr_blocks` with `dynamic`
  blocks, since that variable is a list.

## The Always Free budget is a hard constraint

The instance in [compute.tf](compute.tf) is sized to the exact ceiling: 2 OCPUs, 12 GB,
200 GB boot volume at 10 VPU/GB on `VM.Standard.A1.Flex`. There is no headroom left in
the tenancy — anything additional is billed.

Consequences for changes:

- Those five numbers live in `locals.tf`, **not** `variables.tf`, on purpose: they are
  billing boundaries, not preferences. Do not promote them to variables or raise them.
- `lifecycle.precondition` asserts `var.region == local.home_region`; Always Free compute
  and storage exist only in the home region. Do not weaken this.
- `ignore_changes = [source_details[0].source_id]` stops a routine apply from destroying
  and rebuilding the instance when Canonical publishes a new image. Changing the image is
  a deliberate act.
- `preserve_boot_volume = false` so a destroy returns the 200 GB to the allowance.
- The `oci_core_images` lookup sorts by `DISPLAYNAME`, not `TIMECREATED` — OCI does not
  publish Canonical's builds in build order, but the build date is in the name.

"Out of host capacity" on apply is an Ampere A1 capacity problem, not a config error:
set `availability_domain_number` to 2 or 3 and retry.

## Conventions

The `terraform-style-guide` skill (HashiCorp's official style guide, vendored under
[.agents/skills/](.agents/skills/) and symlinked into `.claude/skills/`, pinned in
[skills-lock.json](skills-lock.json)) governs HCL in this repo — invoke it when writing
or reviewing configuration. Beyond it, as practiced here:

- Every resource carries `freeform_tags = local.freeform_tags`.
- Network resource `display_name`s are `"${var.name_prefix}-<thing>"`; the Terraform
  resource name is `main` for the single instance of a network resource type, or a
  descriptive noun (`private`, `public`, `free`).
- Comments explain *why* a non-obvious choice was made (wizard parity, billing ceiling,
  sort order), not what the resource is.
- Variables get validation blocks where a bad value would otherwise fail late at the API.
- Commit messages are Conventional Commits, subject in the imperative describing the
  resource being created, e.g. `feat: create server 'free-vps'`.
