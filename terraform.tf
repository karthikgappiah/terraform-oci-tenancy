terraform {
  required_version = ">= 1.14"

  # State lives in Object Storage in this tenancy, not on disk. Empty on
  # purpose: a backend cannot reference variables, so the tenancy-specific
  # values are passed from the gitignored backend.hcl instead.
  #
  #   terraform init -backend-config=backend.hcl
  #
  # The backend takes a lock for every plan, apply, and destroy by writing
  # <key>.lock into the same bucket with If-None-Match, so two concurrent runs
  # cannot both hold it.
  backend "oci" {}

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 8.0"
    }
  }
}
