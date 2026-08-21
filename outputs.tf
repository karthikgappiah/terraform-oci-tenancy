output "tenancy_name" {
  description = "Name of the OCI tenancy"
  value       = data.oci_identity_tenancy.this.name
}
