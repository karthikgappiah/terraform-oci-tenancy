# AGENTS.md

This file provides guidance to AI agents when working with code in this repository.

## What this is

A single root Terraform configuration (no modules, no workspaces) that manages the
whole of one OCI tenancy: a compartment, a VCN built to match the OCI "VCN with
Internet Connectivity" wizard, one compute instance sized to consume exactly the
entire Always Free allowance, and the Object Storage bucket holding this
configuration's own remote state. See [README.md](README.md) for the topology
tables and the Always Free arithmetic.

Terraform manages the tenancy, not what runs on the instance. There is no
`user_data`, no provisioner, and no configuration management step — the box comes
up as stock Ubuntu and everything after that is done by hand on it. The one thing
this repository decides about the workloads is which packets may reach them.

The host runs four workloads: **Dokploy** (a self-hosted PaaS fronted by Traefik),
**Tailscale**, **Minecraft**, and **Hermes** (Nous Research). Only two of them need
inbound ports. When asked to "open a port for X", check the README's *What Runs On
It* section first — for most of these the correct answer is a Traefik domain or an
SSH tunnel, not a new NSG rule.

## Commands

```bash
terraform init -backend-config=backend.hcl   # first init only
terraform plan
terraform apply
terraform fmt -recursive   # before committing
terraform validate         # before committing
```

There are no tests. `terraform validate` and a clean `terraform plan` are the check.
Credentials come from [terraform.tfvars](terraform.tfvars) (gitignored; copy from
[terraform.tfvars.example](terraform.tfvars.example)).

`terraform.tfvars` and `backend.hcl` contain real secrets. Do not echo their
contents, and do not write scripts that copy values out of them into other files.

Note that `terraform fmt` refuses any path not ending in `.tf`, `.tfvars`, or
`.tftest.hcl`, so `terraform.tfvars.example` cannot be checked in place. Copy it
to a scratch `.tfvars` and format-check that.

## Architecture

File layout follows the `terraform-style-guide` skill (see below):
[terraform.tf](terraform.tf) versions + backend, [providers.tf](providers.tf)
provider, [main.tf](main.tf) tenancy data source + compartment,
[network.tf](network.tf), [nsg.tf](nsg.tf), [compute.tf](compute.tf),
[state.tf](state.tf), [locals.tf](locals.tf), [variables.tf](variables.tf) and
[outputs.tf](outputs.tf) both alphabetized.

Everything hangs off `oci_identity_compartment.free` in [main.tf](main.tf) — new
resources belong in that compartment, not in the tenancy root. The state bucket in
[state.tf](state.tf) is the deliberate exception, explained below.

Network specifics that are easy to get wrong:

- The public subnet deliberately uses the VCN's **default** route table and **default**
  security list, adopted via `oci_core_default_route_table` /
  `oci_core_default_security_list` with `manage_default_resource_id`. That mirrors what
  the wizard does. The private subnet gets its own dedicated pair.
- Subnets are regional (no `availability_domain` argument).
- Security list rules that scope to the VCN iterate `var.vcn_cidr_blocks` with `dynamic`
  blocks, since that variable is a list.

## Ingress rules are the security surface

Everything else in this configuration is reversible. An ingress rule is not: while
it is live, it is live to whoever is on the other side of it. The NSG in
[nsg.tf](nsg.tf) is also the only firewall Docker cannot route around — publishing
a container port writes DNAT rules into iptables ahead of the chains `ufw` and
`firewalld` manage — so with Dokploy on the box this is *the* perimeter, not one
layer of several.

Non-negotiable, and none of these should be relaxed without the user saying so
explicitly:

- **SSH is never open to `0.0.0.0/0`.** Enforced twice: `ssh_ingress_cidr_blocks`
  rejects it outright, and `published_ports` rejects any TCP entry whose range
  spans port 22 — otherwise `port = 1, port_max = 1024` would reopen SSH and skip
  the first check entirely.
- **Minecraft RCON (25575/tcp) is never published.** Plaintext password over an
  unencrypted socket. `127.0.0.1` plus a tunnel.
- **The Dokploy dashboard (3000/tcp) is never `0.0.0.0/0`.** It is unauthenticated
  until the first account exists; whoever reaches it first on a fresh install owns
  the server. The rule is a bootstrap step and should be deleted once Dokploy has
  a domain on 443 — an SSH tunnel to `localhost:3000` is the fallback, since
  Dokploy publishes the port with `mode=host` and Docker keeps listening either way.
- **Hermes gets no inbound rule** and keeps `API_SERVER_HOST` on localhost. It runs
  with `network_mode: host`, so a `0.0.0.0` bind lands straight on the host stack
  behind whatever the NSG admits.
- **Nothing mounts `/var/run/docker.sock` with write access** except Dokploy
  itself, which requires it. Write access to that socket is root on the host.

Egress is unrestricted on purpose. The host pulls packages and images from a wide
and changing set of endpoints, and narrowing it produces failures that surface far
from their cause. The perimeter worth enforcing is ingress.

Two habits worth keeping when changing rules:

- Prefer removing a rule to adding one. Most requests that sound like "open a
  port" are served by a Traefik domain on 443 or an SSH tunnel.
- Allowlisted residential addresses age into liabilities. They are DHCP leases;
  when the ISP rotates one, the rule starts admitting the next customer.

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

The four workloads share 12 GB and two cores with no swap headroom to spare. A
local LLM does not fit; Hermes should point at a hosted API. See the memory table
in the README before suggesting anything else be added to the box.

## Remote state and its bootstrap loop

State lives in the Object Storage bucket created by [state.tf](state.tf) — the same
configuration whose state it holds. That loop explains two choices that otherwise
look wrong:

- The bucket is in the **tenancy root**, not `free-compartment`, so tearing down the
  compartment never has to delete the bucket describing it.
- `prevent_destroy = true`, so `terraform destroy` fails loudly instead of deleting
  the state store partway through and stranding the rest of the tenancy. Removing
  that line is the deliberate act that enables a teardown; do not remove it to make
  an unrelated destroy succeed.

A backend block cannot reference variables, so the literals live in gitignored
`backend.hcl` ([backend.hcl.example](backend.hcl.example)) and are passed with
`terraform init -backend-config=backend.hcl`. Terraform caches them in `.terraform/`
afterwards. Backend credentials come from the `DEFAULT` profile in `~/.oci/config`,
not from the file, so no key material sits in the repository directory.

Locking is automatic — `<key>.lock` written into the same bucket with
`If-None-Match` — so no DynamoDB-equivalent resource is needed or missing.

On a fresh clone the bucket does not exist yet, so the first apply is targeted
(`-target=oci_objectstorage_bucket.terraform_state`) with state still local, then
migrated with `-migrate-state`. Migration copies state byte-for-byte; `moved` blocks
have no role here, since no resource address changes.

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
  sort order), not what the resource is. This extends to `terraform.tfvars` and its
  example: a port that is deliberately *not* opened gets a comment saying so, because
  an absent rule and an overlooked one look identical.
- Variables get validation blocks where a bad value would otherwise fail late at the API.
- Commit messages are Conventional Commits, subject in the imperative describing the
  resource being created, e.g. `feat: create server 'free-vps'`.
