locals {
  # IPv4 protocol numbers used by security list rules. "all" matches every protocol.
  protocol_all  = "all"
  protocol_icmp = "1"
  protocol_tcp  = "6"

  anywhere_cidr = "0.0.0.0/0"

  # Regional "All <region> Services In Oracle Services Network" service object,
  # used by the service gateway and by the private subnet's routing.
  oracle_services_network = data.oci_core_services.oracle_services_network.services[0]

  freeform_tags = {
    ManagedBy = "Terraform"
    Project   = "terraform-oci-tenancy"
  }
}
