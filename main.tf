data "oci_identity_tenancy" "this" {
  tenancy_id = var.tenancy_ocid
}

resource "oci_identity_compartment" "free" {
  compartment_id = var.tenancy_ocid
  name           = "free"
  description    = "Compartment for OCI resources that are always free."
}
