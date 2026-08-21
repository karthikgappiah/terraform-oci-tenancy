data "oci_identity_tenancy" "this" {
  tenancy_id = var.tenancy_ocid
}
