# Remote state, stored in Object Storage in this tenancy.
#
# The bucket that holds the state is created by the same configuration whose
# state it holds. That bootstrap loop is the reason for two deliberate choices
# below: the bucket lives in the tenancy root rather than in the free
# compartment, so tearing down the compartment never has to delete the bucket
# holding the state that describes it; and prevent_destroy is set, so a
# `terraform destroy` fails loudly instead of deleting the state store halfway
# through and stranding the rest of the tenancy. Removing that one line is all
# it takes to tear this down deliberately.

data "oci_objectstorage_namespace" "this" {
  compartment_id = var.tenancy_ocid
}

resource "oci_objectstorage_bucket" "terraform_state" {
  compartment_id = var.tenancy_ocid
  namespace      = data.oci_objectstorage_namespace.this.namespace
  name           = var.state_bucket_name
  freeform_tags  = local.freeform_tags

  # State is a complete map of the tenancy, including any value a resource
  # returns that Terraform had no way to know was sensitive. It is never public.
  access_type = "NoPublicAccess"

  # Standard is the only tier the backend can read without a restore step;
  # Archive and Infrequent Access would make `terraform plan` fail or bill.
  storage_tier = "Standard"

  # Every apply overwrites the state object in place. Versioning keeps the
  # previous ones, which is the difference between a truncated write being an
  # inconvenience and being the loss of the tenancy's records. State is tens of
  # kilobytes, so the retained versions cost nothing against the 20 GB
  # Always Free Object Storage allowance.
  versioning = "Enabled"

  # Objects are encrypted at rest with an Oracle-managed key by default. A
  # customer-managed key would need an OCI Vault, which is not Always Free.

  lifecycle {
    prevent_destroy = true
  }
}
