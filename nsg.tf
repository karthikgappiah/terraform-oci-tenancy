# The instance's ingress perimeter. Security lists and NSGs are unioned by OCI, so
# a rule in either one admits traffic; keeping the subnet's security list empty of
# ingress (see network.tf) leaves this NSG as the single place that decides what
# reaches the host, and makes anything else placed in the subnet default-deny.
#
# This is also the only firewall Docker cannot route around. Publishing a
# container port writes DNAT rules into iptables ahead of the chains that ufw and
# firewalld manage, so a published port is reachable even when the host firewall
# is configured to refuse it. Nothing opens here without an explicit rule.
resource "oci_core_network_security_group" "instance" {
  compartment_id = oci_identity_compartment.free.id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.name_prefix}-instance-nsg"
  freeform_tags  = local.freeform_tags
}

# Path MTU discovery. Without this, oversized packets are dropped silently rather
# than eliciting a fragmentation-needed response, which presents as connections
# that establish and then stall on the first large transfer.
resource "oci_core_network_security_group_security_rule" "instance_ingress_icmp_pmtu" {
  network_security_group_id = oci_core_network_security_group.instance.id
  direction                 = "INGRESS"
  protocol                  = local.protocol_icmp
  source                    = local.anywhere_cidr
  source_type               = "CIDR_BLOCK"
  description               = "ICMP fragmentation needed, for path MTU discovery."

  icmp_options {
    type = 3
    code = 4
  }
}

resource "oci_core_network_security_group_security_rule" "instance_ingress_icmp_vcn" {
  for_each = toset(var.vcn_cidr_blocks)

  network_security_group_id = oci_core_network_security_group.instance.id
  direction                 = "INGRESS"
  protocol                  = local.protocol_icmp
  source                    = each.value
  source_type               = "CIDR_BLOCK"
  description               = "ICMP destination unreachable from within the VCN."

  icmp_options {
    type = 3
  }
}

# Empty by default, which means no inbound SSH at all. Set ssh_ingress_cidr_blocks
# to the administrator networks that need it; 0.0.0.0/0 is rejected by validation.
resource "oci_core_network_security_group_security_rule" "instance_ingress_ssh" {
  for_each = toset(var.ssh_ingress_cidr_blocks)

  network_security_group_id = oci_core_network_security_group.instance.id
  direction                 = "INGRESS"
  protocol                  = local.protocol_tcp
  source                    = each.value
  source_type               = "CIDR_BLOCK"
  description               = "SSH from approved administrator networks."

  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }
}

# Unrestricted egress is deliberate. The host pulls operating system packages and
# container images from a wide and changing set of endpoints, and narrowing this
# to a port list produces failures that surface far from their cause. The
# perimeter worth enforcing is ingress.
resource "oci_core_network_security_group_security_rule" "instance_egress_all" {
  network_security_group_id = oci_core_network_security_group.instance.id
  direction                 = "EGRESS"
  protocol                  = local.protocol_all
  destination               = local.anywhere_cidr
  destination_type          = "CIDR_BLOCK"
  description               = "All outbound traffic."
}
