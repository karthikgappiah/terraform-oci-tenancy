# Always Free ceiling for Arm compute, per Oracle's "Always Free Resources":
# the first 1,500 OCPU hours and 9,000 GB hours per month on VM.Standard.A1.Flex,
# "equivalent to 2 OCPUs and 12 GB of memory" running continuously, plus 200 GB of
# combined boot and block volume storage. This instance is sized to exactly that
# ceiling, so the numbers live in locals.tf rather than in variables — every one of
# them is a billing boundary, not a preference.

data "oci_identity_availability_domains" "this" {
  compartment_id = var.tenancy_ocid
}

# Always Free compute and block volume storage only exist in the home region.
# Anywhere else bills at the normal rate, so the instance asserts on this below.
data "oci_identity_region_subscriptions" "this" {
  tenancy_id = var.tenancy_ocid
}

data "oci_core_images" "ubuntu_minimal" {
  compartment_id           = var.tenancy_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "24.04 Minimal aarch64"
  shape                    = local.free_instance_shape
  state                    = "AVAILABLE"
  # Sorted by name, not TIMECREATED: time_created is when the image was published
  # into this region, and Oracle does not publish Canonical's builds in build order.
  # The build date is in the display name, so the newest name is the newest Ubuntu.
  sort_by    = "DISPLAYNAME"
  sort_order = "DESC"
}

resource "oci_core_instance" "free" {
  compartment_id      = oci_identity_compartment.free.id
  availability_domain = local.availability_domain
  display_name        = "${var.name_prefix}-instance"
  shape               = local.free_instance_shape
  freeform_tags       = local.freeform_tags

  shape_config {
    ocpus         = local.free_instance_ocpus
    memory_in_gbs = local.free_instance_memory_gbs
  }

  source_details {
    source_type = "image"
    source_id   = local.ubuntu_minimal_image_id

    # 200 GB is the entire Always Free block volume allowance, and VPU 10
    # ("Balanced") is the default performance level a new boot volume gets.
    # Raising either is billed.
    boot_volume_size_in_gbs = local.free_boot_volume_gbs
    boot_volume_vpus_per_gb = local.free_boot_volume_vpus_per_gb
  }

  create_vnic_details {
    subnet_id                 = oci_core_subnet.public.id
    display_name              = "${var.name_prefix}-instance-vnic"
    hostname_label            = var.name_prefix
    nsg_ids                   = [oci_core_network_security_group.instance.id]
    assign_public_ip          = true
    assign_private_dns_record = true
    freeform_tags             = local.freeform_tags
  }

  metadata = {
    ssh_authorized_keys = file(pathexpand(var.ssh_public_key_path))
  }

  # Release the 200 GB back to the free allowance when the instance is destroyed.
  # A preserved boot volume keeps consuming it with nothing attached to it.
  preserve_boot_volume = false

  lifecycle {
    # Canonical publishes new 24.04 Minimal images regularly. Without this, the
    # newest image would become the desired source_id and a routine apply would
    # destroy and rebuild the server. Change the image deliberately instead.
    ignore_changes = [source_details[0].source_id]

    precondition {
      condition     = var.region == local.home_region
      error_message = "Always Free compute and block volume storage exist only in the tenancy's home region (${local.home_region}); region is set to ${var.region}, where this instance would be billed."
    }

    precondition {
      condition     = length(data.oci_core_images.ubuntu_minimal.images) > 0
      error_message = "No AVAILABLE Canonical Ubuntu 24.04 Minimal image was found for ${local.free_instance_shape} in ${var.region}."
    }
  }
}
