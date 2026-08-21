variable "availability_domain_number" {
  description = "Which availability domain in the region to launch the instance in, numbered from 1. Ampere A1 capacity varies between domains, so try another number if a launch reports out-of-capacity."
  type        = number
  default     = 1

  validation {
    condition     = var.availability_domain_number >= 1 && var.availability_domain_number == floor(var.availability_domain_number)
    error_message = "Availability domain number must be a whole number of 1 or greater."
  }
}

variable "fingerprint" {
  description = "Fingerprint of the API signing key uploaded for the OCI user."
  type        = string
}

variable "name_prefix" {
  description = "Prefix applied to the display names of network resources."
  type        = string
  default     = "free"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,20}$", var.name_prefix))
    error_message = "Name prefix must start with a letter and contain only lowercase letters, digits, and hyphens (max 21 characters)."
  }
}

variable "private_key_password" {
  description = "Passphrase for the private key file, if it is encrypted."
  type        = string
  sensitive   = true
  default     = null
}

variable "private_key_path" {
  description = "Path to the private key file used for API authentication."
  type        = string
}

variable "private_subnet_cidr_block" {
  description = "IPv4 CIDR block of the private subnet, which reaches the internet through the NAT gateway."
  type        = string
  default     = "10.0.1.0/24"

  validation {
    condition     = can(cidrhost(var.private_subnet_cidr_block, 0))
    error_message = "Private subnet CIDR block must be valid IPv4 CIDR notation, e.g. 10.0.1.0/24."
  }
}

variable "public_subnet_cidr_block" {
  description = "IPv4 CIDR block of the public subnet, which is reachable from the internet."
  type        = string
  default     = "10.0.0.0/24"

  validation {
    condition     = can(cidrhost(var.public_subnet_cidr_block, 0))
    error_message = "Public subnet CIDR block must be valid IPv4 CIDR notation, e.g. 10.0.0.0/24."
  }
}

variable "published_ports" {
  description = "Ports opened to the instance through its NSG, keyed by service name. Each entry opens one port (or a port range, with port_max) over TCP or UDP to the listed source CIDR blocks. Empty by default: nothing inbound is open until an entry is added."
  type = map(object({
    protocol     = string
    port         = number
    port_max     = optional(number)
    source_cidrs = list(string)
    description  = optional(string)
  }))
  default = {}

  validation {
    condition     = alltrue([for service in var.published_ports : contains(["tcp", "udp"], service.protocol)])
    error_message = "Each published port must set protocol to \"tcp\" or \"udp\"."
  }

  validation {
    condition = alltrue([
      for service in var.published_ports :
      service.port >= 1 && service.port <= 65535 &&
      coalesce(service.port_max, service.port) >= service.port &&
      coalesce(service.port_max, service.port) <= 65535
    ])
    error_message = "Ports must be between 1 and 65535, and port_max must not be below port."
  }

  validation {
    condition = alltrue([
      for service in var.published_ports :
      length(service.source_cidrs) > 0 && alltrue([for cidr in service.source_cidrs : can(cidrhost(cidr, 0))])
    ])
    error_message = "Each published port must list at least one source CIDR block, in valid IPv4 CIDR notation."
  }

  # Without this, an entry spanning port 22 would reopen SSH and skip the
  # 0.0.0.0/0 rejection that ssh_ingress_cidr_blocks enforces.
  validation {
    condition = alltrue([
      for service in var.published_ports :
      !(service.protocol == "tcp" && service.port <= 22 && coalesce(service.port_max, service.port) >= 22)
    ])
    error_message = "Port 22 cannot be opened through published_ports. Use ssh_ingress_cidr_blocks, which rejects 0.0.0.0/0."
  }
}

variable "region" {
  description = "OCI region to target, e.g. us-ashburn-1."
  type        = string
}

variable "ssh_ingress_cidr_blocks" {
  description = "Source CIDR blocks allowed to reach port 22 on the instance. Empty by default, which leaves no inbound SSH; use an Instance Console Connection when this is empty."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for cidr in var.ssh_ingress_cidr_blocks : can(cidrhost(cidr, 0))])
    error_message = "Every SSH ingress entry must be valid IPv4 CIDR notation."
  }

  validation {
    condition     = !contains(var.ssh_ingress_cidr_blocks, "0.0.0.0/0")
    error_message = "SSH must not be open to 0.0.0.0/0. List the specific administrator networks that need it."
  }
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key authorized for the ubuntu user on the instance, e.g. ~/.ssh/id_ed25519.pub."
  type        = string

  validation {
    condition     = can(regex("^(ssh-(rsa|ed25519)|ecdsa-sha2-nistp[0-9]+) ", trimspace(file(pathexpand(var.ssh_public_key_path)))))
    error_message = "SSH public key file must contain an OpenSSH public key (ssh-ed25519, ssh-rsa, or ecdsa-sha2-*). Point this at the .pub file, not the private key."
  }
}

variable "state_bucket_name" {
  description = "Name of the Object Storage bucket holding Terraform remote state. Created in the tenancy root compartment, not in the free compartment, so it outlives whatever the configuration manages."
  type        = string
  default     = "terraform-state"

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9._-]{0,255}$", var.state_bucket_name))
    error_message = "Bucket name must start with a letter or digit and contain only letters, digits, hyphens, underscores, and periods (max 256 characters)."
  }
}

variable "tenancy_ocid" {
  description = "OCID of the OCI tenancy."
  type        = string
}

variable "user_ocid" {
  description = "OCID of the OCI user used for API authentication."
  type        = string
}

variable "vcn_cidr_blocks" {
  description = "IPv4 CIDR blocks assigned to the VCN. Subnet CIDR blocks must fall within these."
  type        = list(string)
  default     = ["10.0.0.0/16"]

  validation {
    condition     = length(var.vcn_cidr_blocks) > 0 && alltrue([for cidr in var.vcn_cidr_blocks : can(cidrhost(cidr, 0))])
    error_message = "VCN CIDR blocks must be a non-empty list of valid IPv4 CIDR notation."
  }
}

variable "vcn_dns_label" {
  description = "DNS label of the VCN, used to build internal hostnames such as <host>.<subnet>.<vcn_dns_label>.oraclevcn.com."
  type        = string
  default     = "freevcn"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{0,14}$", var.vcn_dns_label))
    error_message = "VCN DNS label must start with a letter, be alphanumeric lowercase, and be at most 15 characters."
  }
}
