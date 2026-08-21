output "free_compartment_id" {
  description = "OCID of the free compartment"
  value       = oci_identity_compartment.free.id
}

output "internet_gateway_id" {
  description = "OCID of the internet gateway used by the public subnet"
  value       = oci_core_internet_gateway.main.id
}

output "nat_gateway_id" {
  description = "OCID of the NAT gateway used for outbound traffic from the private subnet"
  value       = oci_core_nat_gateway.main.id
}

output "nat_gateway_public_ip" {
  description = "Public IP address that private subnet traffic is translated to"
  value       = oci_core_nat_gateway.main.nat_ip
}

output "oracle_services_network_cidr_block" {
  description = "Service CIDR label routed to the service gateway"
  value       = local.oracle_services_network.cidr_block
}

output "private_subnet_id" {
  description = "OCID of the private subnet"
  value       = oci_core_subnet.private.id
}

output "public_subnet_id" {
  description = "OCID of the public subnet"
  value       = oci_core_subnet.public.id
}

output "service_gateway_id" {
  description = "OCID of the service gateway to the Oracle Services Network"
  value       = oci_core_service_gateway.main.id
}

output "tenancy_name" {
  description = "Name of the OCI tenancy"
  value       = data.oci_identity_tenancy.this.name
}

output "vcn_id" {
  description = "OCID of the VCN"
  value       = oci_core_vcn.main.id
}
