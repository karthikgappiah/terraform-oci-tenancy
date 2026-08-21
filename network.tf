data "oci_core_services" "oracle_services_network" {
  filter {
    name   = "name"
    values = ["All .* Services In Oracle Services Network"]
    regex  = true
  }
}

resource "oci_core_vcn" "main" {
  compartment_id = oci_identity_compartment.free.id
  cidr_blocks    = var.vcn_cidr_blocks
  display_name   = "${var.name_prefix}-vcn"
  dns_label      = var.vcn_dns_label
  freeform_tags  = local.freeform_tags
}

resource "oci_core_internet_gateway" "main" {
  compartment_id = oci_identity_compartment.free.id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.name_prefix}-internet-gateway"
  enabled        = true
  freeform_tags  = local.freeform_tags
}

resource "oci_core_nat_gateway" "main" {
  compartment_id = oci_identity_compartment.free.id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.name_prefix}-nat-gateway"
  block_traffic  = false
  freeform_tags  = local.freeform_tags
}

resource "oci_core_service_gateway" "main" {
  compartment_id = oci_identity_compartment.free.id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.name_prefix}-service-gateway"
  freeform_tags  = local.freeform_tags

  services {
    service_id = local.oracle_services_network.id
  }
}

# The wizard puts the internet gateway route in the VCN's default route table and
# associates the public subnet with it, rather than creating a dedicated one.
resource "oci_core_default_route_table" "main" {
  manage_default_resource_id = oci_core_vcn.main.default_route_table_id
  freeform_tags              = local.freeform_tags

  route_rules {
    description       = "Internet access through the internet gateway."
    destination       = local.anywhere_cidr
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.main.id
  }
}

resource "oci_core_route_table" "private" {
  compartment_id = oci_identity_compartment.free.id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.name_prefix}-private-route-table"
  freeform_tags  = local.freeform_tags

  route_rules {
    description       = "Outbound internet access through the NAT gateway."
    destination       = local.anywhere_cidr
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.main.id
  }

  # More specific than the NAT default route, so Oracle Services Network traffic
  # (Object Storage, Autonomous Database, ...) stays on the Oracle backbone.
  route_rules {
    description       = "Private access to the Oracle Services Network."
    destination       = local.oracle_services_network.cidr_block
    destination_type  = "SERVICE_CIDR_BLOCK"
    network_entity_id = oci_core_service_gateway.main.id
  }
}

# The public subnet keeps using the VCN's default security list, as the wizard
# arranges it, but not the wizard's rule set: that opens SSH to 0.0.0.0/0. Ingress
# is empty here instead, so the subnet is default-deny and every rule that admits
# traffic to the instance lives in its NSG (see nsg.tf). Security lists and NSGs
# are unioned, so a rule left here would apply to everything in the subnet,
# including a future VNIC meant to carry a narrower NSG of its own.
resource "oci_core_default_security_list" "main" {
  manage_default_resource_id = oci_core_vcn.main.default_security_list_id
  freeform_tags              = local.freeform_tags

  egress_security_rules {
    description      = "All outbound traffic."
    protocol         = local.protocol_all
    destination      = local.anywhere_cidr
    destination_type = "CIDR_BLOCK"
  }
}

resource "oci_core_security_list" "private" {
  compartment_id = oci_identity_compartment.free.id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.name_prefix}-private-security-list"
  freeform_tags  = local.freeform_tags

  dynamic "ingress_security_rules" {
    for_each = toset(var.vcn_cidr_blocks)

    content {
      description = "SSH from within the VCN."
      protocol    = local.protocol_tcp
      source      = ingress_security_rules.value
      source_type = "CIDR_BLOCK"

      tcp_options {
        min = 22
        max = 22
      }
    }
  }

  ingress_security_rules {
    description = "ICMP fragmentation needed, for path MTU discovery."
    protocol    = local.protocol_icmp
    source      = local.anywhere_cidr
    source_type = "CIDR_BLOCK"

    icmp_options {
      type = 3
      code = 4
    }
  }

  dynamic "ingress_security_rules" {
    for_each = toset(var.vcn_cidr_blocks)

    content {
      description = "ICMP destination unreachable from within the VCN."
      protocol    = local.protocol_icmp
      source      = ingress_security_rules.value
      source_type = "CIDR_BLOCK"

      icmp_options {
        type = 3
      }
    }
  }

  egress_security_rules {
    description      = "All outbound traffic."
    protocol         = local.protocol_all
    destination      = local.anywhere_cidr
    destination_type = "CIDR_BLOCK"
  }
}

# Regional subnets: no availability_domain, so VNICs can be placed in any AD.
resource "oci_core_subnet" "public" {
  compartment_id             = oci_identity_compartment.free.id
  vcn_id                     = oci_core_vcn.main.id
  cidr_block                 = var.public_subnet_cidr_block
  display_name               = "${var.name_prefix}-public-subnet"
  dns_label                  = "public"
  dhcp_options_id            = oci_core_vcn.main.default_dhcp_options_id
  route_table_id             = oci_core_default_route_table.main.id
  security_list_ids          = [oci_core_default_security_list.main.id]
  prohibit_public_ip_on_vnic = false
  freeform_tags              = local.freeform_tags
}

resource "oci_core_subnet" "private" {
  compartment_id             = oci_identity_compartment.free.id
  vcn_id                     = oci_core_vcn.main.id
  cidr_block                 = var.private_subnet_cidr_block
  display_name               = "${var.name_prefix}-private-subnet"
  dns_label                  = "private"
  dhcp_options_id            = oci_core_vcn.main.default_dhcp_options_id
  route_table_id             = oci_core_route_table.private.id
  security_list_ids          = [oci_core_security_list.private.id]
  prohibit_public_ip_on_vnic = true
  freeform_tags              = local.freeform_tags
}
