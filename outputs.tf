output "free_compartment_id" {
  description = "OCID of the free compartment"
  value       = oci_identity_compartment.free.id
}

output "tenancy_name" {
  description = "Name of the OCI tenancy"
  value       = data.oci_identity_tenancy.this.name
}
