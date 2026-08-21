locals {
  # IPv4 protocol numbers used by security list and NSG rules. "all" matches every
  # protocol.
  protocol_all  = "all"
  protocol_icmp = "1"
  protocol_tcp  = "6"
  protocol_udp  = "17"

  anywhere_cidr = "0.0.0.0/0"

  # published_ports expanded into one rule per (service, source CIDR) pair. An NSG
  # rule carries exactly one source, so a service opened to three networks becomes
  # three rules. Keyed by "<service>-<cidr>" so a rule's Terraform address names
  # the entry it came from.
  published_port_rules = merge([
    for name, service in var.published_ports : {
      for cidr in service.source_cidrs :
      "${name}-${cidr}" => {
        protocol    = service.protocol == "udp" ? local.protocol_udp : local.protocol_tcp
        port_min    = service.port
        port_max    = coalesce(service.port_max, service.port)
        source      = cidr
        description = coalesce(service.description, "Published service: ${name}.")
      }
    }
  ]...)

  # Regional "All <region> Services In Oracle Services Network" service object,
  # used by the service gateway and by the private subnet's routing.
  oracle_services_network = data.oci_core_services.oracle_services_network.services[0]

  # Always Free ceilings from Oracle's "Always Free Resources" documentation.
  # These are billing boundaries, not tunables: any value above them is charged.
  free_instance_shape          = "VM.Standard.A1.Flex"
  free_instance_ocpus          = 2
  free_instance_memory_gbs     = 12
  free_boot_volume_gbs         = "200"
  free_boot_volume_vpus_per_gb = "10"

  # Availability domains are named per region and A1 capacity varies between them,
  # so the domain is selected by number to make retrying another one a one-line change.
  availability_domain = data.oci_identity_availability_domains.this.availability_domains[var.availability_domain_number - 1].name

  home_region = one([
    for subscription in data.oci_identity_region_subscriptions.this.region_subscriptions :
    subscription.region_name if subscription.is_home_region
  ])

  ubuntu_minimal_image_id = data.oci_core_images.ubuntu_minimal.images[0].id

  freeform_tags = {
    ManagedBy = "Terraform"
    Project   = "terraform-oci-tenancy"
  }
}
