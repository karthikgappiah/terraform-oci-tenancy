output "free_compartment_id" {
  description = "OCID of the free compartment"
  value       = oci_identity_compartment.free.id
}

output "instance_availability_domain" {
  description = "Availability domain the instance was placed in"
  value       = oci_core_instance.free.availability_domain
}

output "instance_boot_volume_size_in_gbs" {
  description = "Boot volume size, which consumes the entire 200 GB Always Free block volume allowance"
  value       = oci_core_instance.free.source_details[0].boot_volume_size_in_gbs
}

output "instance_id" {
  description = "OCID of the always-free compute instance"
  value       = oci_core_instance.free.id
}

output "instance_image_name" {
  description = "Display name of the Ubuntu image the instance was launched from"
  value       = data.oci_core_images.ubuntu_minimal.images[0].display_name
}

output "instance_nsg_id" {
  description = "OCID of the network security group enforcing the instance's ingress rules"
  value       = oci_core_network_security_group.instance.id
}

output "instance_published_ports" {
  description = "Ports open to the instance through its NSG, as \"protocol/port from source\""
  value = sort([
    for rule in local.published_port_rules :
    "${rule.protocol == local.protocol_udp ? "udp" : "tcp"}/${rule.port_min}${rule.port_max != rule.port_min ? "-${rule.port_max}" : ""} from ${rule.source}"
  ])
}

output "instance_private_ip" {
  description = "Private IP address of the instance in the public subnet"
  value       = oci_core_instance.free.private_ip
}

output "instance_public_ip" {
  description = "Ephemeral public IP address of the instance"
  value       = oci_core_instance.free.public_ip
}

output "instance_ssh_command" {
  description = "Command to connect to the instance as the default ubuntu user"
  value       = "ssh ubuntu@${oci_core_instance.free.public_ip}"
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

output "objectstorage_namespace" {
  description = "Object Storage namespace of this tenancy, needed by the remote state backend configuration"
  value       = data.oci_objectstorage_namespace.this.namespace
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

output "state_bucket_name" {
  description = "Object Storage bucket holding Terraform remote state"
  value       = oci_objectstorage_bucket.terraform_state.name
}

output "tenancy_name" {
  description = "Name of the OCI tenancy"
  value       = data.oci_identity_tenancy.this.name
}

output "vcn_id" {
  description = "OCID of the VCN"
  value       = oci_core_vcn.main.id
}
